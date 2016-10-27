package org.genboree.dbaccess;

import java.sql.*;
import java.util.*;

public class Fdata
{
    protected String id;
    public String getId() { return id; }
    public void setId( String id )
    {
        if( id == null ) id = "#";
        this.id = id;
    }
    protected int start;
    public int getStart() { return start; }
    public void setStart( int start ) { this.start = start; }
    protected int stop;
    public int getStop() { return stop; }
    public void setStop( int stop ) { this.stop = stop; }
    protected String bin;
    public String getBin() { return bin; }
    public void setBin( String bin ) { this.bin = bin; }
    protected String phase;
    public String getPhase() { return phase; }
    public void setPhase( String phase ) { this.phase = phase; }
    protected String score;
    public String getScore() { return score; }
    public void setScore( String score ) { this.score = score; }
    protected String strand;
    public String getStrand() { return strand; }
    public void setStrand( String strand ) { this.strand = strand; }
    protected int target_start;
    public int getTarget_start() { return target_start; }
    public void setTarget_start( int target_start ) { this.target_start = target_start; }
    protected int target_stop;
    public int getTarget_stop() { return target_stop; }
    public void setTarget_stop( int target_stop ) { this.target_stop = target_stop; }
    protected String upload_id;
    public String getUpload_id() { return upload_id; }
    public void setUpload_id( String upload_id ) { this.upload_id = upload_id; }
    protected String ftype_id;
    public String getFtype_id() { return ftype_id; }
    public void setFtype_id( String ftype_id ) { this.ftype_id = ftype_id; }
    protected String fentrypoint_id;
    public String getFentrypoint_id() { return fentrypoint_id; }
    public void setFentrypoint_id( String fentrypoint_id ) { this.fentrypoint_id = fentrypoint_id; }
    protected String fname_id;
    public String getFname_id() { return fname_id; }
    public void setFname_id( String fname_id ) { this.fname_id = fname_id; }

    public void clear()
    {
        id = "#";
        start = stop = target_start = target_stop = 0;
        bin = phase = score = strand = upload_id = ftype_id = fentrypoint_id = fname_id = "";
    }

    public Fdata()
    {
        clear();
    }

    protected boolean fetch( Connection conn, String tbName )
        throws SQLException
    {
        if( getId().equals("#") ) return false;
        Statement stmt = conn.createStatement();
        ResultSet rs = stmt.executeQuery( "SELECT fdata_id, fdata_start, fdata_stop, "+
            "fdata_bin, fdata_phase, fdata_score, fdata_strand, fdata_target_start, "+
            "fdata_target_stop, G_upload_id, FK_ftype_id, FK_fname_id, FK_fentrypoint_id "+
            "FROM "+tbName+" WHERE fdata_id="+getId() );
        boolean rc = rs.next();
        if( rc )
        {
            setId( rs.getString(1) );
            setStart( rs.getInt(2) );
            setStop( rs.getInt(3) );
            setBin( rs.getString(4) );
            setPhase( rs.getString(5) );
            setScore( rs.getString(6) );
            setStrand( rs.getString(7) );
            setTarget_start( rs.getInt(8) );
            setTarget_stop( rs.getInt(9) );
            setUpload_id( rs.getString(10) );
            setFtype_id( rs.getString(11) );
            setFname_id( rs.getString(12) );
            setFentrypoint_id( rs.getString(13) );
        }
        else setId( "#" );
        stmt.close();
        return rc;
    }

    protected boolean insert( Connection conn, String tbName, int min_fbin )
        throws SQLException
    {
        setBin( computeBin(getStart(), getStop(), min_fbin) );
        PreparedStatement pstmt = conn.prepareStatement( "INSERT INTO "+tbName+" "+
            "(fdata_start, fdata_stop, fdata_bin, fdata_phase, fdata_score, "+
            "fdata_strand, fdata_target_start, fdata_target_stop, G_upload_id, "+
            "FK_ftype_id, FK_fname_id, FK_fentrypoint_id) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)" );
        pstmt.setInt( 1, getStart() );
        pstmt.setInt( 2, getStop() );
        pstmt.setString( 3, getBin() );
        pstmt.setString( 4, getPhase() );
        pstmt.setString( 5, getScore() );
        pstmt.setString( 6, getStrand() );
        pstmt.setInt( 7, getTarget_start() );
        pstmt.setInt( 8, getTarget_stop() );
        pstmt.setString( 9, getUpload_id() );
        pstmt.setString( 10, getFtype_id() );
        pstmt.setString( 11, getFname_id() );
        pstmt.setString( 12, getFentrypoint_id() );
        boolean rc = (pstmt.executeUpdate() > 0);
        if( rc )
        {
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery( "SELECT LAST_INSERT_ID()" );
            if( rs.next() ) setId( rs.getString(1) );
            else rc = false;
            stmt.close();
        }
        pstmt.close();
        return rc;
    }

    protected boolean update( Connection conn, String tbName, int min_fbin )
        throws SQLException
    {
        if( getId().equals("#") ) return insert( conn, tbName, min_fbin );
        setBin( computeBin(getStart(), getStop(), min_fbin) );
        PreparedStatement pstmt = conn.prepareStatement( "UPDATE "+tbName+" "+
            "SET fdata_start=?, fdata_stop=?, fdata_bin=?, fdata_phase=?, "+
            "fdata_score=?, fdata_strand=?, fdata_target_start=?, fdata_target_stop=? "+
            "WHERE fdata_id="+getId() );
        pstmt.setInt( 1, getStart() );
        pstmt.setInt( 2, getStop() );
        pstmt.setString( 3, getBin() );
        pstmt.setString( 4, getPhase() );
        pstmt.setString( 5, getScore() );
        pstmt.setString( 6, getStrand() );
        pstmt.setInt( 7, getTarget_start() );
        pstmt.setInt( 8, getTarget_stop() );
        boolean rc = (pstmt.executeUpdate() > 0);
        pstmt.close();
        return rc;
    }

    protected boolean delete( Connection conn, String tbName )
        throws SQLException
    {
        if( getId().equals("#") ) return false;
        Statement stmt = conn.createStatement();
        boolean rc = stmt.executeUpdate( "DELETE FROM "+tbName+" WHERE fdata_id="+getId() ) > 0;
        stmt.close();
        return rc;
    }

    public static String computeBin( int start, int stop, int min )
    {
        int tier = min;
        int bin_start, bin_end;
        while( true )
        {
            bin_start = start / tier;
            bin_end = stop / tier;
            if( bin_start == bin_end ) break;
            tier *= 10;
        }
        String fract = "" + bin_start;
        while( fract.length() < 6 ) fract = "0" + fract;
        return ""+tier+"."+fract;
    }

}

