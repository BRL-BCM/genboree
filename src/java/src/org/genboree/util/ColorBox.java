package org.genboree.util;

import java.io.*;
import javax.servlet.*;
import javax.servlet.http.*;
  
public class ColorBox extends HttpServlet
{

  private static final byte imgBuf[] =
  {
    (byte)0x47, (byte)0x49, (byte)0x46, (byte)0x38,
    (byte)0x39, (byte)0x61, (byte)0x12, (byte)0x00,
    (byte)0x12, (byte)0x00, (byte)0x80, (byte)0x00,
    (byte)0x00, (byte)0xFF, (byte)0xCC, (byte)0xAA,
    (byte)0x00, (byte)0x00, (byte)0x00, (byte)0x2C,
    (byte)0x00, (byte)0x00, (byte)0x00, (byte)0x00,
    (byte)0x12, (byte)0x00, (byte)0x12, (byte)0x00,
    (byte)0x00, (byte)0x02, (byte)0x23, (byte)0x8C,
    (byte)0x8F, (byte)0x89, (byte)0xC0, (byte)0xED,
    (byte)0x0F, (byte)0x0C, (byte)0x9C, (byte)0x4D,
    (byte)0xD2, (byte)0x69, (byte)0xEF, (byte)0xCB,
    (byte)0xBA, (byte)0x86, (byte)0xBE, (byte)0x7D,
    (byte)0xA0, (byte)0x37, (byte)0x92, (byte)0x65,
    (byte)0x24, (byte)0x96, (byte)0x1C, (byte)0xB8,
    (byte)0x76, (byte)0xAD, (byte)0xF6, (byte)0x5E,
    (byte)0x31, (byte)0x35, (byte)0x63, (byte)0xCA,
    (byte)0x9D, (byte)0x14, (byte)0x00, (byte)0x3B
  };

    public static byte[] returnImage(String requested)
    {
        byte[] buf = new byte[ imgBuf.length ];
        System.arraycopy( imgBuf, 0, buf, 0, buf.length );

        if(requested == null) return null;
        

        try
        {
            if( requested.startsWith("#") ) requested = requested.substring(1);
            int v = Integer.parseInt( requested, 16 );
            buf[13] = (byte)( (v>>16)&0xFF );
            buf[14] = (byte)( (v>>8)&0xFF );
            buf[15] = (byte)( v&0xFF );
        } catch( Exception ex ) {}

        return buf;
    }


    public void doGet(HttpServletRequest request, HttpServletResponse response)
        throws IOException, ServletException
    {
        String str = request.getParameter( "c" );
        byte[] buf = new byte[ imgBuf.length ];
        System.arraycopy( imgBuf, 0, buf, 0, buf.length );

        try
        {
            if( str.startsWith("#") ) str = str.substring(1);
            int v = Integer.parseInt( str, 16 );
            buf[13] = (byte)( (v>>16)&0xFF );
            buf[14] = (byte)( (v>>8)&0xFF );
            buf[15] = (byte)( v&0xFF );
        } catch( Exception ex ) {}

        response.setContentType( "image/gif" );
        ServletOutputStream out = response.getOutputStream();

        response.setHeader( "Content-Disposition", "inline; filename=\"colorbox.gif\"" );
        out.write( buf );
    }

}
