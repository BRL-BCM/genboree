package org.genboree.dbaccess;

import org.genboree.util.Constants;

import java.io.*;
import java.util.*;
import java.io.*;
import java.sql.SQLException;
import javax.servlet.*;
import javax.servlet.http.*;

public class FileBroker extends HttpServlet
{
	static final File downloadDir =
		new File( Constants.GENBOREE_HTDOCS, "download" );

    public void doGet(HttpServletRequest request, HttpServletResponse response)
        throws IOException, ServletException
    {
        response.setContentType( "application/octet-stream" );

        HttpSession mys = request.getSession();
        String dId = request.getParameter( "i" );
        String dName = request.getParameter( "f" );

        File dFile = null;
        String err = null;
        DBAgent db = DBAgent.getInstance();

        if( dId != null )
        {
            Download dnld = new Download();
            dnld.setRegno( dId );
            try {
                if( dnld.fetch(db) )
                {
                    dFile = new File( dnld.getFile() );
                    Subscription s = Subscription.fetchSubscription( db, dnld.getEmail() );
                    if( s == null )
                    {
                        s = new Subscription();
                        s.setEmail( dnld.getEmail() );
                        s.setNews( 1 );
                        s.insert( db );
                    }
                }
                else err = "The download URL is invalid or expired.";
            } catch (SQLException e) {
                e.printStackTrace();  //To change body of catch statement use File | Settings | File Templates.
            }
        }
        else if( dName != null )
        {
            int idx = dName.lastIndexOf( '/' );
            if( idx >= 0 ) dName = dName.substring(idx+1);
            idx = dName.lastIndexOf( '\\' );
            if( idx >= 0 ) dName = dName.substring(idx+1);
            GenboreeUser myself = null;
            String uId = (String) mys.getAttribute( "userid" );
            if( uId != null && !uId.equals("0") )
            {
                myself = new GenboreeUser();
                myself.setUserId( uId );
                try {
                    if( !myself.fetch(db) ) myself = null;
                } catch (SQLException e) {
                    e.printStackTrace();  //To change body of catch statement use File | Settings | File Templates.
                }
            }
            String eml = null;
            if( myself != null ) eml = myself.getEmail();
            if( eml == null ) err = "Permission denied.";
            else dFile = new File( downloadDir, dName );
        }
        else
        {
            err = "Nothing to download.";
        }

        FileInputStream fin = null;
        if( err == null && dFile != null )
        try
        {
            fin = new FileInputStream( dFile );
        } catch( Exception ex01 )
        {
            err = "Error accessing file "+dFile.getName();
            dFile = null;
        }

        if( fin == null )
        {
            response.setContentType( "text/plain" );
            response.setHeader( "Content-Disposition", "inline" );
            ServletOutputStream out = response.getOutputStream();
            out.println( err );
        }
        else try
        {
            response.setHeader( "Content-Disposition", "attachment; filename=\""+
                dFile.getName()+"\"" );
            ServletOutputStream out = response.getOutputStream();
            byte[] buf = new byte[0x10000];
            int cnt = fin.read( buf );
            while( cnt > 0 )
            {
                out.write( buf, 0, cnt );
                cnt = fin.read( buf );
            }
            fin.close();
        } catch( Exception ex02 ) {}
    }
}
