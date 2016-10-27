package org.genboree.svg;

import java.io.*;
import java.util.*;
import java.awt.image.*;

public class GIFEncoder
{
    protected OutputStream out;
    public GIFEncoder( OutputStream out )
    {
        this.out = out;
    }

    public void encode( BufferedImage img )
        throws IOException
    {
        int imageType = img.getType();
        IndexColorModel icm = null;
        int bpix = 8;
        boolean is_rgb = false;
        switch( imageType )
        {
            case BufferedImage.TYPE_BYTE_BINARY:
                icm = (IndexColorModel) img.getColorModel();
                bpix = icm.getPixelSize();
                break;
            case BufferedImage.TYPE_BYTE_INDEXED:
                icm = (IndexColorModel) img.getColorModel();
                break;
            case BufferedImage.TYPE_BYTE_GRAY:
                break;
            case BufferedImage.TYPE_INT_RGB:
                icm = SyntenyColorMap.getColorModel();
                is_rgb = true;
                break;
            default:
                throw new IOException( "Not supported image type" );
        }
        int w = img.getWidth();
        int h = img.getHeight();

        emitHeader( bpix, w, h, icm );

        Raster r = img.getRaster();
        int nbs = r.getNumBands();
        int iArray[] = new int[ w * nbs ];
        for( int row=0; row<h; row++ )
        {
            int col = 0;
            r.getPixels( 0, row, w, 1, iArray );
            if( is_rgb )
            {
                for( col=0; col<w; col++ )
                {
                    int idx = col * nbs;
                    compressByte( (byte) SyntenyColorMap.rgbToIndex(
                        iArray[idx], iArray[idx+1], iArray[idx+2]) );
                }
            }
            else
            {
                for( col=0; col<w; col++ )
                    compressByte( (byte)(iArray[col]) );
            }
        }

        compressTerm();
        out.write( 0 );
        out.write( ';' );
        out.flush();
    }

    static final int MAX_LZW_BITS = 12;
    static final int LZW_TABLE_SIZE = 1 << MAX_LZW_BITS;
    static final int HSIZE = 5003;

    static final int MAXCODE( int n_bits )
    {
        return (1 << n_bits) - 1;
    }
    static final int HASH_ENTRY( int prefix, int suffix )
    {
        return (prefix << 8) | suffix;
    }

    int n_bits;
    int maxcode;
    int init_bits;
    long cur_accum;
    int cur_bits;
    int waiting_code;
    boolean first_byte;
    int clearCode;
    int eofCode;
    int freeCode;
    int hash_code[] = new int[ HSIZE ];
    int hash_value[] = new int[ HSIZE ];
    int bytesinpkt;
    byte packetbuf[] = new byte[ 256 ];

    void flushPacket() throws IOException
    {
        if( bytesinpkt > 0 )
        {
            packetbuf[0] = (byte)bytesinpkt;
            out.write( packetbuf, 0, bytesinpkt+1 );
            bytesinpkt = 0;
        }
    }

    void byteOut( byte c ) throws IOException
    {
        packetbuf[ ++bytesinpkt ] = c;
        if( bytesinpkt >= 255 ) flushPacket();
    }

    void codeOut( int c ) throws IOException
    {
        cur_accum |= (((long)c) << cur_bits);
        cur_bits += n_bits;
        while( cur_bits >= 8 )
        {
            byteOut( (byte)(cur_accum & 0xFF) );
            cur_accum >>= 8;
            cur_bits -= 8;
        }

        if( freeCode > maxcode )
        {
            n_bits++;
            maxcode = (n_bits == MAX_LZW_BITS) ? LZW_TABLE_SIZE : MAXCODE(n_bits);
        }
    }

    void clearHash()
    {
        Arrays.fill( hash_code, 0 );
    }

    void clearBlock() throws IOException
    {
        clearHash();
        freeCode = clearCode + 2;
        codeOut( clearCode );
        n_bits = init_bits;
        maxcode = MAXCODE(n_bits);
    }

    void compressInit( int i_bits ) throws IOException
    {
        init_bits = n_bits = i_bits;
        maxcode = MAXCODE(n_bits);
        clearCode = 1 << (init_bits - 1);
        eofCode = clearCode + 1;
        freeCode = clearCode + 2;
        first_byte = true;
        bytesinpkt = 0;
        cur_accum = 0L;
        cur_bits = 0;
        clearHash();
        codeOut( clearCode );
    }

    protected void compressByte( byte b ) throws IOException
    {
        int c = ((int)b) & 0xFF;
        int i, disp, probe_value;

        if( first_byte )
        {
            waiting_code = c;
            first_byte = false;
            return;
        }

        i = (c << (MAX_LZW_BITS-8)) + waiting_code;
        if( i >= HSIZE ) i -= HSIZE;

        probe_value = HASH_ENTRY(waiting_code, c);
        if( hash_code[i] != 0 )
        {
            if( hash_value[i] == probe_value )
            {
                waiting_code = hash_code[i];
                return;
            }
            disp = (i == 0) ? 1 : HSIZE - i;
            for( ;; )
            {
                i -= disp;
                if( i < 0 ) i += HSIZE;
                if( hash_code[i] == 0 ) break;
                if( hash_value[i] == probe_value )
                {
                    waiting_code = hash_code[i];
                    return;
                }
            }
        }

        codeOut( waiting_code );
        if( freeCode < LZW_TABLE_SIZE )
        {
            hash_code[i] = freeCode++;
            hash_value[i] = probe_value;
        }
        else
        {
            clearBlock();
        }
        waiting_code = c;
    }

    protected void compressTerm() throws IOException
    {
        if( !first_byte ) codeOut( waiting_code );
        codeOut( eofCode );
        if( cur_bits > 0 ) byteOut( (byte)cur_accum );
        flushPacket();
    }

    void putWord( int w ) throws IOException
    {
        out.write( w & 0xFF );
        out.write( (w >> 8) & 0xFF );
    }

    void put3Bytes( int c ) throws IOException
    {
        // int c = ((int)b) & 0xFF;
        out.write( c );
        out.write( c );
        out.write( c );
    }

    protected void emitHeader( int bpix, int w, int h, IndexColorModel icm )
         throws IOException
    {
        int cmapSize = 1 << bpix;
        int initCodeSize = (bpix <= 1) ? 2 : bpix;

        // Signature
        out.write( 'G' );
        out.write( 'I' );
        out.write( 'F' );
        out.write( '8' );
        out.write( '7' );
        out.write( 'a' );

        // Logical screen descriptor
        putWord( w );
        putWord( h );
        int flagByte = 0x80;    // global color table
        flagByte |= ((bpix-1) << 4);    // color resolution
        flagByte |= (bpix - 1); // size of global color table
        out.write( flagByte );
        out.write( 0 );         // background color index
        out.write( 0 );         // reserved (aspect ratio in GIF89a)

        int i;
        // Color map table
        if( icm == null )
        {
            // Grayscale
            for( i=0; i<cmapSize; i++ ) put3Bytes( i );
        }
        else
        {
            int nc = icm.getMapSize();
            for( i=0; i<nc; i++ )
            {
                out.write( icm.getRed(i) );
                out.write( icm.getGreen(i) );
                out.write( icm.getBlue(i) );
            }
            for( ; i<cmapSize; i++ ) put3Bytes( 0xFF );
        }

        // Image separator and image descriptor
        out.write( ',' );
        putWord( 0 );       // top left offset
        putWord( 0 );
        putWord( w );       // Image dimensions
        putWord( h );
        out.write( 0 );     // flag byte: No local colormap, not interlaced
        out.write( initCodeSize );      // Initial codesize byte

        compressInit( initCodeSize+1 );
    }

}
