package org.genboree.util;

import java.io.*;
import javax.servlet.*;
import javax.servlet.http.*;

public class FileRetriever extends HttpServlet
{
    public void doGet(HttpServletRequest request, HttpServletResponse response)
        throws IOException, ServletException
    {
        response.setContentType( "application/octet-stream" ); // octet-stream
        HttpSession mys = request.getSession();
        ServletOutputStream out = response.getOutputStream();

        String fName = request.getParameter( "f" );
        String fDisp = request.getParameter( "d" );
        if( fDisp == null || fDisp.length()==0 ) fDisp = "attachment";
        else
        {
            if( fDisp.substring(0,1).toLowerCase().equals("a") ) fDisp = "attachment";
            else fDisp = "inline";
        }
        response.setHeader( "Content-Disposition", fDisp+"; filename=\""+fName+"\"" );

        String fSource = request.getParameter("s");
        if( fSource != null ) fSource = (String) mys.getAttribute(fSource);
        if( fSource != null )
        {
            out.print( fSource );
            return;
        }

        String temporaryDir =  Constants.GENBOREE_ROOT  + "/htdocs/temp";
        File f = null;
        FileKiller fk = (FileKiller) mys.getAttribute( "FileKiller" );
        if(fk == null && fName != null)
        {
            boolean existFile = false;
            existFile = fileExist(fName, temporaryDir);
            if(existFile)
            {
                f = new File(temporaryDir + "/" + fName);

            }
        }
        else if( fName != null && fk != null )
        {
            f = fk.getFile( fName );
        }

        if( f == null )
        {
            if( fName == null )
            {
                fName = "invalid_request.lff";
                out.println( "Invalid request parameter(s)" );
            }
            else out.println( "Unknown file: "+fName );
        }
        if( f != null )
        try
        {
            BufferedReader in = new BufferedReader( new FileReader( f ) );
            String s;
            while( (s=in.readLine()) != null ) out.println( s );
            in.close();
        } catch( IOException ex ) {}
    }

   private boolean fileExist(String myFile, String temporaryDir) {
        boolean exists = false;
        if(new File(temporaryDir + "/" + myFile).exists()){
            exists = true;
        } else {
            exists = false;
        }

        return exists;
    }
}
