package org.genboree.gdas;

import java.sql.*;
import java.util.*;
import java.io.*;

import javax.servlet.ServletOutputStream;

import org.genboree.dbaccess.*;
import org.genboree.util.Util;

public class MultiFeatureFetcher
{
    protected String[] dbNames;
    protected String _fref, from, to;

    protected FeatureFetcher[] fFetchers;

    protected DBAgent db;
    protected Vector vFilt;
    protected Hashtable linkHash;

    public MultiFeatureFetcher( String[] dbNames, String _fref, String from, String to ) throws SQLException {
        DbResourceSet dbRes = null;
        ResultSet rs1 = null;
        this.dbNames = dbNames;
        this._fref = _fref;
        this.from = from;
        this.to = to;

        db = DBAgent.getInstance();
        vFilt = new Vector();
        int i;

        fFetchers = new FeatureFetcher[ dbNames.length ];
        for( i=0; i<dbNames.length; i++ )
        {
            fFetchers[i] = new FeatureFetcher( db, dbNames[i], _fref, from, to );
            fFetchers[i].setFilters( vFilt );
        }

        linkHash = new Hashtable();
        try
        {
            dbRes = db.executeQuery(
            "SELECT ft.name, l.name, l.description "+
            "FROM defaultlink dl, link l, featuretype ft "+
            "WHERE dl.linkid = l.linkid AND ft.featuretypeid=dl.featuretypeid" );
            rs1 = dbRes.resultSet;

            if( rs1 != null )
            {
                while( rs1.next() )
                {
                    String fid = rs1.getString(1);
                    String lName = rs1.getString(2);
                    String lUrl = rs1.getString(3);

                    Vector v = (Vector) linkHash.get( fid );
                    if( v == null )
                    {
                        v = new Vector();
                        linkHash.put( fid, v );
                    }
                    String[] lnk = new String[2];
                    lnk[0] = lName;
                    lnk[1] = lUrl;
                    v.addElement( lnk );
                }
                dbRes.close();
            }
        } catch( Exception ex ) { db.reportError( ex, "MultiFeatureFetcher()" ); }
    }

    public void addFilter( String filt )
    {
        vFilt.addElement( filt );
    }

    protected int nextGroupId = 0;
    protected Hashtable grpMap = new Hashtable();
    public String defineGroupId( String grpName )
    {
        String rc = (String) grpMap.get( grpName );
        if( rc == null )
        {
            rc = "" + (++nextGroupId);
            grpMap.put( grpName, rc );
        }
        return rc;
    }

    public boolean fetch()
    {
        int i;
        int cnt = 0;
        for( i=0; i<fFetchers.length; i++ )
        {
            if( !fFetchers[i].fetch() ) fFetchers[i] = null;
            else if( !fFetchers[i].next() ) fFetchers[i] = null;
            else cnt++;
        }
        return (cnt > 0);
    }

    public long l_fstart, l_gid, l_ftarget_start, l_ftarget_stop;
    public String fid, fref, fstart, fstop, fstrand, fphase;
    public String ftarget_start, ftarget_stop, ftypeid, fmethod, fsource, gid;
    public String gclass, gname, fattribute_id, fattribute_value;
    public double fscore;

    public String groupId;

    public String[] linkNames = new String[ 64 ];
    public String[] linkUrls = new String[ 64 ];
    public int numLinks = 0;

    protected String fixLink( String src )
    {
        int idx = src.indexOf( "=$" );
        if( idx < 0 ) return src;

        StringBuffer sb = new StringBuffer();
        int lastIdx = 0;

        while( idx >= 0 )
        {
            sb.append( src.substring(lastIdx, idx+1) );
            int idx0 = idx + 2;
            lastIdx = src.indexOf( '&', idx0 );
            if( lastIdx < 0 ) lastIdx = src.indexOf( ';', idx0 );
            if( lastIdx < 0 ) lastIdx = src.length();
            String varName = src.substring( idx0, lastIdx );

            if( varName.equals("name") ) sb.append( gname );
            else if( varName.compareToIgnoreCase("stripName") == 0)
            {
                int gidx = gname.lastIndexOf('.');
                sb.append( Util.urlEncode( (gidx>=0) ? gname.substring(0,gidx) : gname ) );
            }
            else if( varName.equals("class") ) sb.append( Util.urlEncode(gclass) );
            else if( varName.equals("type") ) sb.append( Util.urlEncode(fmethod) );
            else if( varName.equals("subtype") ) sb.append( Util.urlEncode(fsource) );
            else if( varName.equals("reference") ) sb.append( Util.urlEncode(fref) );
            else if( varName.equals("start") ) sb.append( fstart );
            else if( varName.equals("end") ) sb.append( fstop );
            else if( varName.equals("stop") ) sb.append( fstop );
            else if( varName.equals("strand") ) sb.append( fstrand );
            else if( varName.equals("phase") ) sb.append( fphase );
            else if( varName.equals("score") ) sb.append( fscore );
            else if( varName.equals("targetstart") ) sb.append( ftarget_start );
            else if( varName.equals("targetstop") ) sb.append( ftarget_stop );

            idx = src.indexOf( "=$", lastIdx );
        }
        sb.append( src.substring(lastIdx) );
        return sb.toString();
    }

    protected Hashtable newLinkHash = null;

    protected void copyData( FeatureFetcher f )
    {
        if( f.fref == null ) return;

        newLinkHash = f.getLinkHash();

        l_fstart = f.l_fstart;
        l_gid = f.l_gid;
        l_ftarget_start = f.l_ftarget_start;
        l_ftarget_stop = f.l_ftarget_stop;

        fid = f.fid;
        fref = Util.getXMLCompliantString( f.fref );
        fstart = f.fstart;
        fstop = f.fstop;
        fscore = f.fscore;
        fstrand = Util.getXMLCompliantString( f.fstrand );
        fphase = Util.getXMLCompliantString( f.fphase );
        ftarget_start = f.ftarget_start;
        ftarget_stop = f.ftarget_stop;
        ftypeid = f.ftypeid;
        fmethod = Util.getXMLCompliantString( f.fmethod );
        fsource = Util.getXMLCompliantString( f.fsource );
        gid = f.gid;
        gclass = Util.getXMLCompliantString( f.gclass );
        gname = Util.getXMLCompliantString( f.gname );
        fattribute_id = f.fattribute_id;
        fattribute_value = f.fattribute_value;

        if( l_gid > 0 ) groupId = defineGroupId( fmethod+":"+fsource+":"+gname );

        numLinks = 0;

        Vector v = null;
        if( newLinkHash != null ) v = (Vector) newLinkHash.get( ftypeid );
        else v = (Vector) linkHash.get( fmethod+":"+fsource );

        if( v != null )
        {
            numLinks = v.size();
            if( numLinks > 64 ) numLinks = 64;
            for( int i=0; i<numLinks; i++ )
            {
                String[] lnk = (String[]) v.elementAt(i);
                linkNames[i] = lnk[0];
                linkUrls[i] = fixLink( lnk[1] );
            }
        }
    }

    public boolean next()
    {
        FeatureFetcher rc = null;
        int c = -1;
        int i;
        for( i=0; i<fFetchers.length; i++ )
        {
            FeatureFetcher ff = fFetchers[i];
            if( ff == null ) continue;
            if( rc == null || rc.compareTo(ff) > 0 )
            {
                rc = ff;
                c = i;
            }
        }
        if( rc != null )
        {
            copyData( fFetchers[c] );
            if( !fFetchers[c].next() ) fFetchers[c] = null;
            return true;
        }
        return false;
    }

    public void printXML( javax.servlet.ServletOutputStream out )
        throws IOException
    {
        out.println( "<FEATURE id=\""+gclass+":"+gname+"/"+fid+"\" label=\""+gclass+"\">" );
        out.println( "<TYPE id=\""+fmethod+":"+fsource+"\" category=\"miscellaneous\">"+fmethod+":"+fsource+"</TYPE>" );
        out.println( "<METHOD id=\""+fmethod+"\">  "+fmethod+"</METHOD>" );
        out.println( "<START>"+fstart+"</START>" );
        out.println( "<END>"+fstop+"</END>" );
        out.println( "<SCORE>"+fscore+"</SCORE>" );
        out.println( "<ORIENTATION>"+fstrand+"</ORIENTATION>" );
        String sPhase = (fphase.trim().length()>0) ? fphase : "0";
        out.println( "<PHASE>"+sPhase+"</PHASE>" );
        if( l_ftarget_start > 0 && l_ftarget_stop > 0 )
        {
            out.println( "<TARGET id=\""+fref+"\" start=\""+ftarget_start+"\" stop=\""+ftarget_stop+"\" />" );
        }
        for( int i=0; i<numLinks; i++ )
        {
            out.println( "<LINK href=\""+linkUrls[i]+"\">"+linkNames[i]+"</LINK>" );
        }
        if( l_gid > 0 )
        {
            out.println( "<GROUP id=\""+groupId+"\" type=\""+gname+"\"></GROUP>" );
        }
        out.println( "</FEATURE>" );
    }

}
