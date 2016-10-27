package org.genboree.upload;

import org.genboree.util.ProgressIndicator;
import org.genboree.svg.GIFEncoder;
import java.io.*;
import javax.servlet.*;
import javax.servlet.http.*;

public class ProgressServlet extends HttpServlet
{

    static {
      System.setProperty( "java.awt.headless", "true" );
    }

    protected ProgressIndicator pi = new ProgressIndicator();

    public void doGet(HttpServletRequest request, HttpServletResponse response)
        throws IOException, ServletException
    {
        response.setContentType("image/gif");
        ServletOutputStream out = response.getOutputStream();
        HttpSession mys = request.getSession();
        String idStr = request.getParameter( "id" ) ;
        if(idStr == null)
        {
          idStr = "" ;
        }
        long totalBytes, bytesRead;

        GIFEncoder gEnc = new GIFEncoder( out );
        synchronized(mys)
        {
            Long lnum = (Long) mys.getAttribute( "totalBytes" );
            totalBytes = (lnum == null) ? 100 : lnum.longValue();
            lnum = (Long) mys.getAttribute( idStr + "bytesRead" );
            bytesRead = (lnum == null) ? 0 : lnum.longValue();
        }
        int perc10 = (int)((bytesRead * 4000.00) / ((double)totalBytes));


        synchronized(pi) { gEnc.encode( pi.createImage(perc10) ); }
    }

}
