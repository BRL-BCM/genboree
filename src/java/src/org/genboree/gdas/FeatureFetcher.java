package org.genboree.gdas;

import java.sql.*;
import java.util.*;
import java.io.*;
import java.text.DecimalFormat;

import org.genboree.dbaccess.*;
import org.genboree.util.Util;

public class FeatureFetcher
    implements Comparable
{
    protected DecimalFormat myFormat;
    protected long f_min_bin, f_max_bin;
    protected String dbName;
    protected String _fref, from, to;
    protected long _fstart, _fstop;
    protected DBAgent db;
    protected Connection conn;
    protected Statement stmt;
    protected ResultSet rs;
    protected String fbinFilter;
    protected String fbinFilterN;
    protected String sqlQuery;

    public String getFbinFilter() { return fbinFilter; }
    public long getMinBin() { return f_min_bin; }
    public long getMaxBin() { return f_max_bin; }
    public long getFstart() { return _fstart; }
    public long getFstop() { return _fstop; }
    public String getSqlQuery() { return sqlQuery; }

    protected Vector vFilt;
    public void setFilters( Vector vFilt ) { this.vFilt = vFilt; }

    public FeatureFetcher( DBAgent db, String dbName, String _fref, String from, String to ) throws SQLException {
        rs = null;

        this.db = db;
        this.dbName = dbName;
        this._fref = _fref;
        this.from = from;
        this.to = to;
        try
        {
            _fstart = Long.parseLong( from );
            _fstop = Long.parseLong( to );
        } catch( Exception ex01 ) { return; }
        myFormat = new DecimalFormat("000000");
        myFormat.getNumberInstance().setParseIntegerOnly(true);
        f_min_bin = -1L;
        f_max_bin = -1L;
        conn = db.getConnection( this.dbName );

        fbinFilter = "";
        fbinFilterN = "";
        vFilt = new Vector();
        if( conn != null ) try
        {
            String qs = "SELECT fvalue FROM fmeta WHERE fname=?";
            PreparedStatement pstmt = conn.prepareStatement( qs );
            pstmt.setString( 1, "MIN_BIN" );
            ResultSet rs1 = pstmt.executeQuery();
            if( rs1.next() ) f_min_bin = Long.parseLong( rs1.getString(1) );
            pstmt.setString( 1, "MAX_BIN" );
            rs1 = pstmt.executeQuery();
            if( rs1.next() ) f_max_bin = Long.parseLong( rs1.getString(1) );

            long tier = f_max_bin;
            boolean first = true;
            while( tier >= f_min_bin )
            {
                if( !first )
                {
                    fbinFilter = fbinFilter + " OR ";
                    fbinFilterN = fbinFilterN + " OR ";
                }
                else first = false;

                String firstArg  = "" + tier + "." + myFormat.format(_fstart/tier);
                String secondArg = "" + tier + "." + myFormat.format(_fstop/tier);
                if( firstArg.equals(secondArg) )
                {
                    fbinFilter = fbinFilter + "f.fbin=" + firstArg;
                    fbinFilterN = fbinFilterN + "fbin=" + firstArg;
                }
                else
                {
                    fbinFilter = fbinFilter + "f.fbin BETWEEN " + firstArg + " AND " + secondArg;
                    fbinFilterN = fbinFilterN + "fbin BETWEEN " + firstArg + " AND " + secondArg;
                }

                tier /= 10;
            }
        } catch( Exception ex ) { db.reportError(ex, "FeatureFetcher()"); }
    }

    public void addFilter( String filt )
    {
        vFilt.addElement( filt );
    }

    protected Hashtable htGclass = null;
    protected Hashtable htFtype = null;
    protected Hashtable htLink = null;
    public Hashtable getLinkHash() { return htLink; }
    protected String frefId = null;

    public boolean fetch()
    {
        try
        {
            stmt = conn.createStatement();
            rs = stmt.executeQuery( "SELECT rid FROM fref WHERE refname='"+_fref+"'" );
            frefId = null;
            if( rs.next() )
            {
                frefId = rs.getString(1);
            }
            else return false;

            rs = stmt.executeQuery( "SELECT gid, gclass FROM gclass" );
            htGclass = new Hashtable();
            while( rs.next() )
            {
                String gid = rs.getString(1);
                String gclass = rs.getString(2);
                htGclass.put( gid, gclass );
            }

            rs = stmt.executeQuery( "SELECT ftypeid, fmethod, fsource FROM ftype" );
            htFtype = new Hashtable();
            while( rs.next() )
            {
                String ftypeid = rs.getString(1);
                String[] ft = new String[2];
                ft[0] = rs.getString(2);
                ft[1] = rs.getString(3);
                htFtype.put( ftypeid, ft );
            }

            rs = stmt.executeQuery( "SELECT fl.ftypeid, l.name, l.description "+
                "FROM featuretolink fl, link l "+
                "WHERE fl.linkId=l.linkId AND fl.userId=0" );
            htLink = new Hashtable();
            while( rs.next() )
            {
                String ftypeid = rs.getString(1);
                String[] lnk = new String[2];
                lnk[0] = rs.getString(2);
                lnk[1] = rs.getString(3);
                Vector v = (Vector) htLink.get( ftypeid );
                if( v == null )
                {
                    v = new Vector();
                    htLink.put( ftypeid, v );
                }
                v.addElement( lnk );
            }

            sqlQuery = "SELECT "+
            "fid, fstart, fstop, ftypeid, fscore, fstrand, "+
            "fphase, gid, ftarget_start, ftarget_stop, gname "+
            "FROM fdata2 "+
            "WHERE rid="+frefId;
            if( fbinFilterN.length()>0 ) sqlQuery = sqlQuery + " AND ("+fbinFilterN+")";
            sqlQuery = sqlQuery + " AND (fstop >= "+_fstart+" AND fstart <= "+_fstop+")";
            sqlQuery = sqlQuery + " ORDER BY ftypeid, gid, fstart";

System.err.println( "---DAS database name: "+dbName );
System.err.println( "---DAS SQL: "+sqlQuery );
java.util.Date startDate = new java.util.Date();

            rs = stmt.executeQuery( sqlQuery );

java.util.Date stopDate = new java.util.Date();
long timeDiff = (stopDate.getTime() - startDate.getTime()) / 100;
System.err.println( "---DAS time after executeQuery(): " + stopDate + "; " +
    (timeDiff/10) + "." + (timeDiff%10) + "sec" );
System.err.flush();

            return true;
        } catch( Exception ex )
        {
		    if( ex instanceof SQLException && ((SQLException)ex).getErrorCode()==1146 )
		        return fetchS();

ex.printStackTrace( System.err );
System.err.flush();

            db.reportError(ex, "FeatureFetcher.fetch()");
        }
        rs = null;
        return false;
    }

    public boolean fetchS()
    {
        int i;

/*
        sqlQuery = "SELECT f.fid, fref, fstart, fstop, fscore, fstrand, fphase, "+
        "ftarget_start, ftarget_stop, f.ftypeid, ft.fmethod, ft.fsource, f.gid, "+
        "fg.gclass, fg.gname, fat.fattribute_id, fat.fattribute_value "+
        "FROM fdata f LEFT JOIN fattribute_to_feature fat USING (fid), fgroup fg, ftype ft "+
        "WHERE fg.gid = f.gid AND ft.ftypeid = f.ftypeid";
*/

        sqlQuery = "SELECT f.fid, fref, fstart, fstop, fscore, fstrand, fphase, "+
        "ftarget_start, ftarget_stop, f.ftypeid, ft.fmethod, ft.fsource, f.gid, "+
        "fg.gclass, fg.gname "+
        "FROM fdata f, fgroup fg, ftype ft "+
        "WHERE fg.gid = f.gid AND ft.ftypeid = f.ftypeid";

        if( fbinFilter.length()>0 ) sqlQuery = sqlQuery + " AND ("+fbinFilter+")";
        sqlQuery = sqlQuery + " AND (fstop >= "+_fstart+" AND fstart <= "+_fstop+")";
        sqlQuery = sqlQuery + " AND fref = '"+_fref+"'";
        for( i=0; i<vFilt.size(); i++ )
        {
            String filt = (String)vFilt.elementAt(i);
            sqlQuery = sqlQuery + " AND (" + filt + ")";
        }
        sqlQuery = sqlQuery + " ORDER BY ft.fmethod, ft.fsource, fg.gid, f.fstart";

System.err.println( "NEW DAS database name: "+dbName );
System.err.println( "NEW DAS SQL: "+sqlQuery );

        try
        {

java.util.Date startDate = new java.util.Date();
System.err.println( "NEW DAS time before createStatement(): " + startDate );
            stmt = conn.createStatement();
System.err.println( "NEW DAS time after createStatement(): " + (new java.util.Date())  );

            rs = stmt.executeQuery( sqlQuery );

java.util.Date stopDate = new java.util.Date();
long timeDiff = (stopDate.getTime() - startDate.getTime()) / 100;
System.err.println( "NEW DAS time after executeQuery(): " + stopDate + "; " +
    (timeDiff/10) + "." + (timeDiff%10) + "sec" );
System.err.flush();

            return true;
        } catch( Exception ex ) { db.reportError(ex, "FeatureFetcher.fetch()"); }

System.err.flush();

        rs = null;
        return false;
    }

    public long l_fstart, l_gid, l_ftarget_start, l_ftarget_stop;
    public String fid, fref = null, fstart, fstop, fstrand, fphase;
    public String ftarget_start, ftarget_stop, ftypeid, fmethod, fsource, gid;
    public String gclass, gname, fattribute_id=null, fattribute_value=null;
    public double fscore;

    public int compareTo( Object o )
    {
        FeatureFetcher ff = (FeatureFetcher) o;
        int rc = fmethod.compareTo( ff.fmethod );
        if( rc != 0 ) return rc;
        rc = fsource.compareTo( ff.fsource );
        if( rc != 0 ) return rc;
        long lrc = l_gid - ff.l_gid;
        if( lrc == 0L ) lrc = l_fstart - ff.l_fstart;
        if( lrc < 0L ) return -1;
        return (lrc == 0L) ? 0 : 1;
    }

    public boolean next()
    {
        if( rs == null ) return false;
        if( frefId == null ) return nextS();
        try
        {
            if( rs.next() )
            {
/*
    fid 1, fstart 2, fstop 3, ftypeid 4, fscore 5, fstrand 6,
    fphase 7, gid 8, ftarget_start 9, ftarget_stop 10, gname 11
*/
                fid = rs.getString(1);
                fref = _fref;
                l_fstart = rs.getLong(2);
                fstart = ""+l_fstart;
                fstop = rs.getString(3);

                ftypeid = rs.getString(4);
                String[] ft = (String[]) htFtype.get( ftypeid );
                if( ft != null )
                {
                    fmethod = ft[0];
                    fsource = ft[1];
                }

                fscore = rs.getDouble(5);
                fstrand = rs.getString(6);
                fphase = rs.getString(7);

                l_gid = rs.getLong(8);
                gid = ""+l_gid;
                gclass = (String)htGclass.get( gid );

                l_ftarget_start = rs.getLong(9);
                ftarget_start = "" + l_ftarget_start;
                l_ftarget_stop = rs.getLong(10);
                ftarget_stop = "" + l_ftarget_stop;

                gname = rs.getString(11);

                return true;
            }
        } catch( Exception ex )
        {
            db.reportError(ex, "FeatureFetcher.next()");

// ex.printStackTrace( System.err );
// System.err.flush();
        }
        rs = null;
        return false;
    }

    public boolean nextS()
    {
        if( rs == null ) return false;
        try
        {
            if( rs.next() )
            {
                fid = rs.getString(1);
                fref = rs.getString(2);
                l_fstart = rs.getLong(3);
                fstart = ""+l_fstart;
                fstop = rs.getString(4);
                fscore = rs.getDouble(5);
                fstrand = rs.getString(6);
                fphase = rs.getString(7);
                l_ftarget_start = rs.getLong(8);
                ftarget_start = "" + l_ftarget_start;
                l_ftarget_stop = rs.getLong(9);
                ftarget_stop = "" + l_ftarget_stop;
                ftypeid = rs.getString(10);
                fmethod = rs.getString(11);
                fsource = rs.getString(12);
                l_gid = rs.getLong(13);
                gid = ""+l_gid;
                gclass = rs.getString(14);
                gname = rs.getString(15);
//                fattribute_id = rs.getString(16);
//                fattribute_value = rs.getString(17);
                return true;
            }
        } catch( Exception ex ) { db.reportError(ex, "FeatureFetcher.next()"); }
        rs = null;
        return false;
    }
}