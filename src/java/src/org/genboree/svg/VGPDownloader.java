package org.genboree.svg;

import java.io.*;
import javax.servlet.*;
import javax.servlet.http.*;
import java.util.*;
import java.util.zip.*;

public class VGPDownloader extends HttpServlet
{

    public void doGet(HttpServletRequest request, HttpServletResponse response)
        throws IOException, ServletException
    {
        HttpSession mys = request.getSession();

        String src = request.getParameter( "src" );
        File svgFile = (src==null) ? (File)null : (File)mys.getAttribute( src );

        String fmt = request.getParameter( "fmt" );
        if( fmt == null ) fmt = "gif";

        String disp = request.getParameter( "d" );
        if( disp != null ) disp = disp.startsWith("i") ? "inline" : "attachment";
        else disp = "attachment";

        response.setContentType( "application/octet-stream" );
        ServletOutputStream out = response.getOutputStream();
        if( svgFile == null )
        {
            out.println( "Resource not found." );
            return;
        }

        File cdir = svgFile;

        String tnam = src + "." + fmt;
        if( svgFile.isDirectory() )
        {
            tnam = src + ".zip";
        }
        else
        {
            cdir = svgFile.getParentFile();
        }
        response.setHeader( "Content-Disposition", disp+"; filename=\""+tnam+"\"" );

        String sScale = request.getParameter( "scale" );
        double sc = 1.;
        if( sScale != null ) try
        {
            sc = Double.parseDouble( sScale );
        } catch( Exception ex00 ) {}

        try
        {
            if( svgFile.isDirectory() )
            {
                ZipOutputStream zout = new MyZipOutputStream( out );
                File[] lst = svgFile.listFiles();
                for( int i=0; i<lst.length; i++ )
                {
                    File f = lst[i];
                    String fnam = f.getName();
                    int idx = fnam.indexOf( ".svg" );
                    if( idx < 0 ) continue;
                    fnam = fnam.substring(0,idx);
                    ZipEntry ze = new ZipEntry( fnam + "." + fmt );
                    zout.putNextEntry( ze );


                    SVGDocument svgDoc = new SVGDocument( f );
                    svgDoc.export( zout, fmt, sc, null );
                    zout.closeEntry();

                    ze = new ZipEntry( fnam + ".map" );
                    zout.putNextEntry( ze );
                    String sss = "<map name=\"vgpimgmap\">\r\n";
                    zout.write( sss.getBytes("ISO-8859-1") );
	                SVGDocument.MapElement[] mes = svgDoc.getImageMap();
	                for( int j=0; j<mes.length; j++ )
	                {
		                SVGDocument.MapElement mel = mes[j];
		                int x0 = mel.rect.x;
		                int y0 = mel.rect.y;
		                int x1 = x0 + mel.rect.width - 1;
		                int y1 = y0 + mel.rect.height - 1;
                        sss = "<area href=\""+mel.href+"\" SHAPE=\"rect\" coords=\""+
                            x0 +","+ y0 +","+ x1 +","+ y1 +"\">\r\n";
                        zout.write( sss.getBytes("ISO-8859-1") );
	                }
                    sss = "</map>\r\n";
                    zout.write( sss.getBytes("ISO-8859-1") );

                    svgDoc = null;
                    System.gc();
                    zout.closeEntry();

                }
                zout.finish();
            }
            else
            {
                SVGDocument svgDoc = new SVGDocument( svgFile );
                svgDoc.export( out, fmt, sc, null );
            }
        } catch( Exception ex01 )
        {
            try
            {
                File ferr = new File( cdir, "err.txt" );
                PrintStream err = new PrintStream( new FileOutputStream(ferr) );
                ex01.printStackTrace( err );
                err.flush();
                err.close();
            } catch( Exception ex02 ) {}
        }

    }

    protected static class MyZipOutputStream extends ZipOutputStream
    {
        public MyZipOutputStream( OutputStream out )
        {
            super( out );
        }
        public void close() throws IOException
        {
        }
    }

}
