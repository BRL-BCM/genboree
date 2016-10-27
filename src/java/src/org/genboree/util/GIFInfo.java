package org.genboree.util;

import java.io.*;
import java.util.*;

public class GIFInfo
{
    protected int width;
    public int getWidth() { return width; }
    protected int height;
    public int getHeight() { return height; }
    protected int numColors;
    public int getNumColors() { return numColors; }
    protected byte[] colorMap;
    public byte[] getColorMap() { return colorMap; }

    public void clear()
    {
        width = height = numColors = 0;
        colorMap = null;
    }
    public GIFInfo() { clear(); }

    protected static int readWord( InputStream in )
        throws IOException
    {
        int b1 = in.read();
        int b2 = in.read();
        if( b1==-1 || b2==-1 ) return -1;
        return (b1&0xFF) | ((b2&0xFF)<<8);
    }

    public static GIFInfo getGIFInfo( File f )
    {
        try
        {
            int i;
            FileInputStream in = new FileInputStream( f );
            byte[] hdr = new byte[6];
            if( in.read(hdr) != 6 ) return null;
            String sHdr = new String(hdr);
            if( !sHdr.startsWith("GIF") ) return null;
            int w = readWord(in);
            int h = readWord(in);
            int flagByte = in.read();
            in.read();
            in.read();
            if( w==-1 || h==-1 || flagByte==-1 ) return null;
            int bpix = (flagByte&0xF) + 1;
            int cmapSize = 1 << bpix;
            byte[] cmap = new byte[cmapSize*3];
            in.read( cmap );
            int c = in.read();
            while( c!=',' )
            {
                if( c == '!' )
                {
                    in.read();
                    int l = in.read();
                    for( i=0; i<l; i++ ) in.read();
                    c = in.read();
                }
                else return null;
            }
            in.read();
            in.read();
            in.read();
            in.read();
            w = readWord( in );
            h = readWord( in );
            in.close();
            if( w==-1 || h==-1 ) return null;

            GIFInfo rc = new GIFInfo();
            rc.width = w;
            rc.height = h;
            rc.numColors = cmapSize;
            rc.colorMap = cmap;
            return rc;

        } catch( Exception ex ) { ex.printStackTrace(); }
        return null;
    }

    public static GIFInfo getGIFInfo( String fname )
    {
        return getGIFInfo( new File(fname) );
    }

    public static void main( String[] args )
    {
        if( args.length < 1 ) System.exit(0);

        GIFInfo gi = GIFInfo.getGIFInfo( args[0] );
        if( gi != null )
        {
            System.out.println( "width="+gi.getWidth()+", height="+gi.getHeight()+
            ", numColors="+gi.getNumColors() );
        }
        System.exit(0);
    }
}
