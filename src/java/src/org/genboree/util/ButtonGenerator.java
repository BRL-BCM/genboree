package org.genboree.util;

import java.io.*;
import java.awt.Color;
import java.awt.image.IndexColorModel;

import org.genboree.svg.GIFEncoder;

public class ButtonGenerator extends GIFEncoder
{

protected static final byte[] RASTER_DATA =
{
(byte)0x00, (byte)0x00, (byte)0x00, (byte)0x00, (byte)0x00, (byte)0x00, (byte)0x33, (byte)0x00, (byte)0x00, (byte)0x00,
(byte)0x00, (byte)0x00, (byte)0x00, (byte)0x00, (byte)0x00, (byte)0x00, (byte)0x00, (byte)0x00, (byte)0x00, (byte)0x00,
(byte)0x00, (byte)0x00, (byte)0x00, (byte)0x00, (byte)0x00, (byte)0x00, (byte)0x00, (byte)0x00, (byte)0x00, (byte)0x00,
(byte)0x00, (byte)0x00, (byte)0x00, (byte)0x00, (byte)0x00, (byte)0x00, (byte)0x00, (byte)0x00, (byte)0x0C, (byte)0x00,

(byte)0x7C, (byte)0x00, (byte)0x00, (byte)0x00, (byte)0x7F, (byte)0x00, (byte)0x33, (byte)0x0C, (byte)0x0F, (byte)0xC0,
(byte)0x03, (byte)0xE0, (byte)0x00, (byte)0xF8, (byte)0x00, (byte)0x7E, (byte)0x00, (byte)0x06, (byte)0x1F, (byte)0x00,
(byte)0x00, (byte)0x8D, (byte)0x9B, (byte)0x10, (byte)0x30, (byte)0x42, (byte)0x04, (byte)0x10, (byte)0x02, (byte)0x40,
(byte)0x08, (byte)0x20, (byte)0x42, (byte)0x0C, (byte)0x7C, (byte)0x00, (byte)0x00, (byte)0x00, (byte)0x0C, (byte)0x00,

(byte)0x66, (byte)0x00, (byte)0x00, (byte)0x00, (byte)0x60, (byte)0x00, (byte)0x33, (byte)0x3C, (byte)0x0C, (byte)0x18,
(byte)0x66, (byte)0x36, (byte)0x19, (byte)0x8D, (byte)0x86, (byte)0x60, (byte)0x61, (byte)0x9E, (byte)0x31, (byte)0xB0,
(byte)0xC1, (byte)0x8D, (byte)0x9B, (byte)0x18, (byte)0x30, (byte)0xC6, (byte)0x0C, (byte)0x30, (byte)0x0E, (byte)0x70,
(byte)0x0C, (byte)0x30, (byte)0x63, (byte)0x0C, (byte)0xC6, (byte)0x00, (byte)0x00, (byte)0x00, (byte)0x0C, (byte)0x00,

(byte)0x66, (byte)0x3E, (byte)0x3E, (byte)0x7C, (byte)0x60, (byte)0x63, (byte)0x33, (byte)0x0C, (byte)0x0C, (byte)0x0C,
(byte)0xC6, (byte)0x33, (byte)0x30, (byte)0x0C, (byte)0xCC, (byte)0x60, (byte)0x33, (byte)0x06, (byte)0x31, (byte)0x99,
(byte)0x83, (byte)0x8D, (byte)0x9B, (byte)0x1C, (byte)0x31, (byte)0xCE, (byte)0x1C, (byte)0x70, (byte)0x3E, (byte)0x7C,
(byte)0x0E, (byte)0x38, (byte)0x73, (byte)0x8C, (byte)0xC0, (byte)0x78, (byte)0xF1, (byte)0xB3, (byte)0xCF, (byte)0x80,

(byte)0x66, (byte)0x03, (byte)0x60, (byte)0xC6, (byte)0x60, (byte)0x63, (byte)0x33, (byte)0x0C, (byte)0x0F, (byte)0x87,
(byte)0x80, (byte)0x31, (byte)0xE0, (byte)0x0C, (byte)0x78, (byte)0x7E, (byte)0x1E, (byte)0x06, (byte)0x31, (byte)0x8F,
(byte)0x07, (byte)0x8D, (byte)0x9B, (byte)0x1E, (byte)0x33, (byte)0xDE, (byte)0x3C, (byte)0xF0, (byte)0xFE, (byte)0x7F,
(byte)0x0F, (byte)0x3C, (byte)0x7B, (byte)0xCC, (byte)0xE0, (byte)0xCC, (byte)0x19, (byte)0xF6, (byte)0x6C, (byte)0xC0,

(byte)0x7C, (byte)0x03, (byte)0x60, (byte)0xC6, (byte)0x7E, (byte)0x63, (byte)0x33, (byte)0x0C, (byte)0x00, (byte)0xC3,
(byte)0x00, (byte)0xE0, (byte)0xC0, (byte)0x78, (byte)0x30, (byte)0x03, (byte)0x0C, (byte)0x06, (byte)0x31, (byte)0x86,
(byte)0x0F, (byte)0xFD, (byte)0x9B, (byte)0xFF, (byte)0x37, (byte)0xFE, (byte)0x7D, (byte)0xF3, (byte)0xFE, (byte)0x7F,
(byte)0xCF, (byte)0xBE, (byte)0x7F, (byte)0xEC, (byte)0x7C, (byte)0xCC, (byte)0xF9, (byte)0x86, (byte)0x0C, (byte)0xC0,

(byte)0x63, (byte)0x3F, (byte)0x3C, (byte)0xFE, (byte)0x60, (byte)0x63, (byte)0x33, (byte)0x0C, (byte)0x00, (byte)0xC7,
(byte)0x81, (byte)0x81, (byte)0xE0, (byte)0x0C, (byte)0x78, (byte)0x03, (byte)0x1E, (byte)0x06, (byte)0x31, (byte)0x8F,
(byte)0x07, (byte)0x8D, (byte)0x9B, (byte)0x1E, (byte)0x33, (byte)0xDE, (byte)0x3C, (byte)0xF0, (byte)0xFE, (byte)0x7F,
(byte)0x0F, (byte)0x3C, (byte)0x7B, (byte)0xCC, (byte)0x0E, (byte)0xFD, (byte)0x99, (byte)0x86, (byte)0x0C, (byte)0xC0,

(byte)0x63, (byte)0x63, (byte)0x06, (byte)0xC0, (byte)0x60, (byte)0x63, (byte)0x33, (byte)0x0C, (byte)0x00, (byte)0xCC,
(byte)0xC3, (byte)0x03, (byte)0x30, (byte)0x0C, (byte)0xCC, (byte)0x03, (byte)0x33, (byte)0x06, (byte)0x31, (byte)0x99,
(byte)0x83, (byte)0x8D, (byte)0x9B, (byte)0x1C, (byte)0x31, (byte)0xCE, (byte)0x1C, (byte)0x70, (byte)0x3E, (byte)0x7C,
(byte)0x0E, (byte)0x38, (byte)0x73, (byte)0x8C, (byte)0x06, (byte)0xC1, (byte)0x99, (byte)0x86, (byte)0x0C, (byte)0xC0,

(byte)0x63, (byte)0x63, (byte)0x06, (byte)0xC6, (byte)0x60, (byte)0x67, (byte)0x33, (byte)0x0C, (byte)0x6C, (byte)0xD8,
(byte)0x66, (byte)0x06, (byte)0x19, (byte)0x8D, (byte)0x86, (byte)0x63, (byte)0x61, (byte)0x86, (byte)0x31, (byte)0xB0,
(byte)0xC1, (byte)0x8D, (byte)0x9B, (byte)0x18, (byte)0x30, (byte)0xC6, (byte)0x0C, (byte)0x30, (byte)0x0E, (byte)0x70,
(byte)0x0C, (byte)0x30, (byte)0x63, (byte)0x0C, (byte)0xC6, (byte)0xCD, (byte)0x99, (byte)0x86, (byte)0x6C, (byte)0xC0,

(byte)0x7E, (byte)0x3F, (byte)0x7C, (byte)0x7C, (byte)0x60, (byte)0x3B, (byte)0x33, (byte)0x3F, (byte)0x67, (byte)0x80,
(byte)0x07, (byte)0xF0, (byte)0x00, (byte)0xF8, (byte)0x00, (byte)0x3E, (byte)0x00, (byte)0x1F, (byte)0x9F, (byte)0x00,
(byte)0x00, (byte)0x8D, (byte)0x9B, (byte)0x10, (byte)0x30, (byte)0x42, (byte)0x04, (byte)0x10, (byte)0x02, (byte)0x40,
(byte)0x08, (byte)0x20, (byte)0x42, (byte)0x0C, (byte)0x7C, (byte)0x78, (byte)0xF9, (byte)0x83, (byte)0xCC, (byte)0xC0
};

protected static final int RASTER_HEIGHT = 10;
protected static final int RASTER_WIDTH = 320;
protected static final int RASTER_BPLIN = 40;

protected static final int[] ICON_OFFSETS =
{
    0, 32, 57, 84, 102, 120, 138, 163, 178, 193, 208, 221, 232, 243, 256, 271, 315
};
protected static final String[] ICON_IDS =
{
    "base", "full",
    "1.5x", "2x", "3x", "5x", "10x",
    "xl", "xr",
    "start", "frw", "rw", "fw", "ffw", "end",
    "search"
};
protected static int DEFAULT_THEME = 0xD3CFE6;

    public ButtonGenerator( OutputStream out )
    {
        super( out );
    }

    public boolean generate( String sIconId, String theme, boolean down, boolean flat )
        throws IOException
    {
        if( sIconId == null ) return false;
        int i, j;

        sIconId = sIconId.toLowerCase();
        int iid = -1;
        for( i=0; i<ICON_IDS.length; i++ )
        if( sIconId.equals(ICON_IDS[i]) )
        {
            iid = i;
            break;
        }
        if( iid == -1 ) return false;

        int iconOff = ICON_OFFSETS[iid];
        int iconWidth = ICON_OFFSETS[i+1] - iconOff;
        int byteOff = iconOff / 8;
        int mask0 = 0x80 >> (iconOff%8);

        int rgb = DEFAULT_THEME;
        if( theme != null ) try
        {
            rgb = Integer.parseInt( theme, 16 );
        } catch( Exception ex00 ) {}

        Color bkg = new Color( rgb );
        Color fgd = Color.black;
        Color lbord = bkg.brighter();
        Color dbord = bkg.darker();

        byte[] reds = new byte[ 4 ];
        byte[] greens = new byte[ 4 ];
        byte[] blues = new byte[ 4 ];
        reds[0] = (byte) bkg.getRed();
        reds[1] = (byte) fgd.getRed();
        reds[2] = (byte) lbord.getRed();
        reds[3] = (byte) dbord.getRed();
        greens[0] = (byte) bkg.getGreen();
        greens[1] = (byte) fgd.getGreen();
        greens[2] = (byte) lbord.getGreen();
        greens[3] = (byte) dbord.getGreen();
        blues[0] = (byte) bkg.getBlue();
        blues[1] = (byte) fgd.getBlue();
        blues[2] = (byte) lbord.getBlue();
        blues[3] = (byte) dbord.getBlue();

        IndexColorModel icm = new IndexColorModel( 8, 4, reds, greens, blues );

        int w = (iconWidth + 8 + 3) & 0xFFFFFFFC;
        int x0 = (w - iconWidth) / 2;
        int h = RASTER_HEIGHT + 8;
        int y0 = 3;

        int idxTop1 = 2;
        int idxTop2 = 0;
        int idxBot1 = 1;
        int idxBot2 = 3;
        int idxIco = 1;

        if( flat )
        {
            idxTop1 = idxBot1 = idxIco = 3;
            idxTop2 = idxBot2 = 0;
        }
        else if( down )
        {
            x0++;
            y0++;
            idxTop1 = 1;
            idxTop2 = 3;
            idxBot2 = 2;
        }

        byte[] buf = new byte[ w*h ];
        int idx;

        // Draw top-left border
        for( i=0; i<w; i++ ) buf[i] = (byte) idxTop1;
        for( i=0,idx=0; i<h; i++,idx+=w ) buf[idx] = (byte) idxTop1;
        // Draw top-left border - 1
        for( i=1,idx=w+1; i<w-1; i++,idx++ ) buf[idx] = (byte) idxTop2;
        for( i=1,idx=w+1; i<h-1; i++,idx+=w ) buf[idx] = (byte) idxTop2;

        // Draw bottom-right border
        for( i=0,idx=w*(h-1); i<w; i++,idx++ ) buf[idx] = (byte) idxBot1;
        for( i=0,idx=(w-1); i<h; i++,idx+=w ) buf[idx] = (byte) idxBot1;
        // Draw bottom-right border - 1
        for( i=1,idx=w*(h-2)+1; i<w-1; i++,idx++ ) buf[idx] = (byte) idxBot2;
        for( i=1,idx=(w+w-2); i<h-1; i++,idx+=w ) buf[idx] = (byte) idxBot2;

        // Draw icon
        for( j=0; j<RASTER_HEIGHT; j++ )
        {
            int boff = byteOff + j*RASTER_BPLIN;
            int msk = mask0;
            idx = (y0 + j)*w + x0;
            for( i=0; i<iconWidth; i++,idx++ )
            {
                if( ((int)RASTER_DATA[boff] & msk) != 0 ) buf[idx] = (byte) idxIco;
                msk >>= 1;
                if( msk == 0 )
                {
                    boff++;
                    msk = 0x80;
                }
            }
        }

        emitHeader( 2, w, h, icm );

        for( i=0; i<buf.length; i++ ) compressByte( buf[i] );

        compressTerm();
        out.write( 0 );
        out.write( ';' );
        out.flush();

        return true;
    }

/*
    public static void main( String[] args )
        throws Exception
    {
        String sIconId = "FFW";
        if( args.length > 0 ) sIconId = args[0];
        String sTheme = null;
        if( args.length > 1 ) sTheme = args[1];
        boolean down = false;
        if( args.length > 2 && args[2].toLowerCase().equals("down") ) down = true;

        String fnam = sIconId.toLowerCase();
        if( sTheme != null ) fnam = fnam + "_" + sTheme.toUpperCase();
        if( down ) fnam = fnam + "_down";

        FileOutputStream fos = new FileOutputStream( fnam+".gif" );
        ButtonGenerator g = new ButtonGenerator( fos );
        g.generate( sIconId, sTheme, down, false );
        fos.close();

        System.exit(0);
    }
*/
}