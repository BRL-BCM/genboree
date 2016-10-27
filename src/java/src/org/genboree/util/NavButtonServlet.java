package org.genboree.util;

import java.util.*;
import java.io.*;
import javax.servlet.*;
import javax.servlet.http.*;

public class NavButtonServlet extends HttpServlet
{
    protected static Hashtable imgCache = new Hashtable();

    public void doGet(HttpServletRequest request, HttpServletResponse response)
        throws IOException, ServletException
    {
        String sid = request.getParameter( "id" );
        if( sid == null ) sid = "base";
        String sTheme = request.getParameter( "bg" );

        boolean down = false;
        boolean flat = false;
        String sState = request.getParameter( "s" );
        if( sState != null )
        {
            sState = sState.toLowerCase();
            if( sState.startsWith("d") ) down = true;
            else if( sState.startsWith("f") ) flat = true;
        }

        String fnam = sid;
        if( sTheme != null ) fnam = fnam+"_"+sTheme;
        if( down ) fnam = fnam+"_down";
        if( flat ) fnam = fnam+"_flat";

        byte[] imgData = (byte []) imgCache.get( fnam );
        if( imgData == null )
        {
            ByteArrayOutputStream bOut = new ByteArrayOutputStream();
            ButtonGenerator g = new ButtonGenerator( bOut );
            g.generate( sid, sTheme, down, flat );
            imgData = bOut.toByteArray();
            imgCache.put( fnam, imgData );
        }

        response.setContentType( "image/gif" );
        response.setHeader( "Content-Disposition", "inline; filename=\""+fnam+".gif\"" );
        ServletOutputStream out = response.getOutputStream();

        out.write( imgData );
//        ButtonGenerator g = new ButtonGenerator( out );
//        g.generate( sid, sTheme, down, flat );
    }

}
