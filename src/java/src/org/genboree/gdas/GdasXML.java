package org.genboree.gdas;

import java.net.URLDecoder;
import java.util.*;
import java.io.*;
import java.sql.SQLException;

import javax.servlet.*;
import javax.servlet.http.*;

import org.genboree.dbaccess.*;
import org.genboree.util.Util;

public class GdasXML extends HttpServlet
{
    private static final String[] str0 = new String[0];

    public void doGet(HttpServletRequest request, HttpServletResponse response)
        throws IOException, ServletException
    {
        response.setContentType("text/plain");
        response.addHeader("X-das-capabilities",
                "error-segment/1.0; unknown-segment/1.0; unknown-feature/1.0; feature-by-id/1.0; group-by-id/1.0; component/1.0; supercomponent/1.0; dna/1.0; feature/1.0; stylesheet/1.0; types/1.0; entry_points/1.0; dsn/1.0; sequence/1.0");
        response.addHeader("X-das-status", "200");
        response.addHeader("X-das-version", "DAS/1.50");

        ServletOutputStream out = response.getOutputStream();

        String myUrl = request.getRequestURL().toString();

        int i;
        String op = null;
        String[] dbNames = str0;

        String pathInfo = request.getPathInfo();
        if( pathInfo == null ) pathInfo = "";
        if( pathInfo.startsWith("/") ) pathInfo = pathInfo.substring(1);
        int idx = pathInfo.indexOf('/');
        if( idx > 0 )
        {
            dbNames = Util.parseString( pathInfo.substring(0,idx), '&' );
            op = pathInfo.substring( idx + 1 );

// out.println( "op: "+op );
// for( i=0; i<dbNames.length; i++ ) out.println( "DB: "+dbNames[i] );
        }
        else op = pathInfo;

        String queryString = request.getQueryString();

        String myQs = Util.isEmpty(queryString) ? "" : "?"+queryString;
        myUrl = myUrl + myQs;

System.err.println( "DAS URL: "+myUrl );
System.err.flush();

        queryString = (queryString==null) ? "" : Util.urlDecode(queryString);

        if( op == null )
        {
        }
        else if( op.equals("styles") && dbNames.length>0 )
        {
            int userId = 0;
            idx = queryString.indexOf( "userId=" );
            if( idx >= 0 )
            {
                String uid = queryString.substring( 7 );
                for( idx=0; idx<uid.length(); idx++ )
                    if( !Character.isDigit(uid.charAt(idx)) ) break;
                userId = Util.parseInt( uid.substring(0,idx), 0 );
            }

            out.println( "<?xml version=\"1.0\" standalone=\"yes\"?>" );
            out.println( "<!DOCTYPE DASSTYLES SYSTEM \"http://www.genboree.org/dtd/dasstyles.dtd\">" );
            out.println( "<DASSTYLES>" );
            out.println( "<GFF version=\"1.2\" summary=\"yes\" href=\""+Util.htmlQuote(myUrl)+"\">" );
            Style[] ss = Style.fetchAll( DBAgent.getInstance(), dbNames, userId );
            for( i=0; i<ss.length; i++ )
            {
                Style s = ss[i];
                out.println( "<STYLE id=\""+
                    s.styleId+"\" featureType=\""+
                    Util.getXMLCompliantString(s.featureType)+"\" name=\""+
                    Util.getXMLCompliantString(s.name)+"\" description=\""+
                    Util.getXMLCompliantString(s.description)+"\" color=\""+
                    s.color+"\"/>" );
            }
            out.println( "</GFF>" );
            out.println( "</DASSTYLES>" );
        }
        else if( op.equals("entry_points") && dbNames.length>0 )
        {
            EntryPoint[] eps = EntryPoint.fetchAll(DBAgent.getInstance(), dbNames );
            out.println( "<?xml version=\"1.0\" standalone=\"yes\"?>" );
            out.println( "<!DOCTYPE DASEP SYSTEM \"http://www.genboree.org/dtd/dasep.dtd\">" );
            out.println( "<DASEP>" );
            out.println( "\t<ENTRY_POINTS href=\""+Util.htmlQuote(myUrl)+"\" version=\"1.0\">" );
            for( i=0; i<eps.length; i++ )
            {
                EntryPoint ep = eps[i];
                String fref = Util.getXMLCompliantString( ep.fref );
                out.println( "\t\t<SEGMENT id=\""+fref+"\" size=\""+ep.fstop+
                "\" start=\"1\" stop=\""+ep.fstop+"\" class=\"Sequence\" orientation=\"+\" subparts=\"no\">"+fref+"</SEGMENT>" );
            }
            out.println( "\t</ENTRY_POINTS>" );
            out.println( "</DASEP>" );
        }
        else if( op.equals("features") && dbNames.length>0 )
        {
            String[] parms = Util.parseString( queryString, ';' );
            Vector vfilts = new Vector();
            String segm = "";
            for( i=0; i<parms.length; i++ )
            {
                String key = parms[i];
                String val = null;
                idx = key.indexOf('=');
                if( idx >= 0 )
                {
                    val = key.substring( idx+1 );
                    key = key.substring( 0, idx );
                }
                if( val == null ) continue;
                if( key.equals("segment") )
                {
                    segm = val;
                }
                else if( key.equals("filtergname") )
                {
                    vfilts.addElement( "NOT (fg.gname like '%"+val+"')" );
                }
            }

            String fref = segm;
            String from = "0";
            String to = "0";
            idx = fref.lastIndexOf(':');
            if( idx > 0 )
            {
                from = fref.substring( idx + 1 );
                fref = fref.substring( 0, idx );
            }
            idx = from.indexOf(',');
            if( idx > 0 )
            {
                to = from.substring( idx + 1 );
                from = from.substring( 0, idx );
            }

    out.println( "<?xml version=\"1.0\" standalone=\"yes\"?>" );
    out.println( "<!DOCTYPE DASGFF SYSTEM \"http://www.genboree.org/dtd/dasgff.dtd\">" );
    out.println( "<DASGFF>" );
    out.println( "<GFF version=\"1.01\" href=\""+Util.htmlQuote(myUrl)+"\">" );
    out.println( "<SEGMENT id=\""+fref+"\" start=\""+from+"\" stop=\""+to+"\" version=\"1.0\">" );

	java.util.Date startDate0 = new java.util.Date();

            MultiFeatureFetcher ff = null;
            try {
                ff = new MultiFeatureFetcher( dbNames, fref, from, to );
            } catch (SQLException e) {
                e.printStackTrace();  //To change body of catch statement use File | Settings | File Templates.
            }
            for( i=0; i<vfilts.size(); i++ ) ff.addFilter( (String)vfilts.elementAt(i) );
	ff.fetch();

	java.util.Date stopDate0 = new java.util.Date();
	long timeDiff0 = (stopDate0.getTime() - startDate0.getTime()) / 100;
System.err.println( op+" Query: "+(timeDiff0/10)+"."+(timeDiff0%10)+"s" );
System.err.flush();

	long cnt = 0L;
	java.util.Date startDate = new java.util.Date();

	while( ff.next() )
	{
		cnt++;
		ff.printXML( out );
	}

    out.println( "</SEGMENT>" );
    out.println( "<UNKNOWNSEGMENT id=\""+ff.groupId+"\">" );
    out.println( "</UNKNOWNSEGMENT>" );
    out.println( "</GFF>" );
    out.println( "</DASGFF>" );

	java.util.Date stopDate = new java.util.Date();
	long timeDiff = (stopDate.getTime() - startDate.getTime()) / 100;

System.err.println( op+" XML: "+cnt+" recs in "+(timeDiff/10)+"."+(timeDiff%10)+"s" );
System.err.flush();


// out.println( "fref: "+fref );
// out.println( "from: "+from );
// out.println( "to: "+to );
// for( i=0; i<vfilts.size(); i++ ) out.println( "FILTER: " + (String)vfilts.elementAt(i) );
        }

/*
        out.println( "Request attributes: SERVLET PATH: " + request.getServletPath() );
        out.println( "context path: " + request.getContextPath() );
        out.println( "path info: "+ request.getPathInfo() );
        out.println( "path translated: " + request.getPathTranslated() );
        out.println ( "query string: " + request.getQueryString() );
        out.println (" request URI: " + request.getRequestURI() );
        out.println (" URL: " + request.getRequestURL().toString() );
*/
/*
Request attributes: SERVLET PATH: /newdas
context path: /java-bin
path info: /genboree_r_3e71f3fa87b41a668f194fd7df513712&genboree_r_2508cce3183b21c68621a84c72e50f76/features
path translated: /www/htdocs/webapps/java-bin/genboree_r_3e71f3fa87b41a668f194fd7df513712&genboree_r_2508cce3183b21c68621a84c72e50f76/features
query string: filtergname=_GV;filtergname=_CV;segment=chr3:1,199411731
request URI: /java-bin/newdas/genboree_r_3e71f3fa87b41a668f194fd7df513712&genboree_r_2508cce3183b21c68621a84c72e50f76/features
URL: http://128.249.153.235/java-bin/newdas/genboree_r_3e71f3fa87b41a668f194fd7df513712&genboree_r_2508cce3183b21c68621a84c72e50f76/features
*/

    }
}
