package org.genboree.dbaccess;

import java.sql.*;
import java.util.Vector;

public class DbFdata
{
	protected int fid;
	public int getFid() { return fid; }
	public void setFid( int fid ) { this.fid = fid; }
	protected String fref;
	public String getFref() { return fref; }
	public void setFref( String fref ) { this.fref = fref; }
	protected int fstart;
	public int getFstart() { return fstart; }
	public void setFstart( int fstart ) { this.fstart = fstart; }
	protected int fstop;
	public int getFstop() { return fstop; }
	public void setFstop( int fstop ) { this.fstop = fstop; }
	protected String fbin;
	public String getFbin() { return fbin; }
	public void setFbin( String fbin ) { this.fbin = fbin; }
	protected int ftypeid;
	public int getFtypeid() { return ftypeid; }
	public void setFtypeid( int ftypeid ) { this.ftypeid = ftypeid; }
	protected String fscore;
	public String getFscore() { return fscore; }
	public void setFscore( String fscore ) { this.fscore = fscore; }
	protected String fstrand;
	public String getFstrand() { return fstrand; }
	public void setFstrand( String fstrand ) { this.fstrand = fstrand; }
	protected String fphase;
	public String getFphase() { return fphase; }
	public void setFphase( String fphase ) { this.fphase = fphase; }
	protected int gid;
	public int getGid() { return gid; }
	public void setGid( int gid ) { this.gid = gid; }
	protected int ftarget_start;
	public int getFtargetStart() { return ftarget_start; }
	public void setFtargetStart( int ftarget_start ) { this.ftarget_start = ftarget_start; }
	protected int ftarget_stop;
	public int getFtargetStop() { return ftarget_stop; }
	public void setFtargetStop( int ftarget_stop ) { this.ftarget_stop = ftarget_stop; }

	public DbFdata() {}
	
	public static DbFdata[] fetchAll( DBAgent db ) throws SQLException {
		Vector v = new Vector();
		Connection conn = db.getConnection();
		if( conn != null ) try
		{
			String qs = "SELECT fid, fref, fstart, fstop, fbin, ftypeid, fscore, fstrand, fphase, gid, ftarget_start, ftarget_stop FROM fdata";
			PreparedStatement pstmt = conn.prepareStatement( qs );
			ResultSet rs = pstmt.executeQuery();
			while( rs.next() )
			{
				DbFdata p = new DbFdata();
				p.setFid( rs.getInt(1) );
				p.setFref( rs.getString(2) );
				p.setFstart( rs.getInt(3) );
				p.setFstop( rs.getInt(4) );
				p.setFbin( rs.getString(5) );
				p.setFtypeid( rs.getInt(6) );
				p.setFscore( rs.getString(7) );
				p.setFstrand( rs.getString(8) );
				p.setFphase( rs.getString(9) );
				p.setGid( rs.getInt(10) );
				p.setFtargetStart( rs.getInt(11) );
				p.setFtargetStop( rs.getInt(12) );
				v.addElement( p );
			}
			pstmt.close();
		} catch( Exception ex )
		{
			db.reportError( ex, "DbFdata.fetchAll()" );
		}
		DbFdata[] rc = new DbFdata[ v.size() ];
		v.copyInto( rc );
		return rc;
	}

	public boolean fetch( DBAgent db ) throws SQLException {
		Connection conn = db.getConnection();
		if( conn != null ) try
		{
			String qs = "SELECT fid, fref, fstart, fstop, fbin, ftypeid, fscore, fstrand, fphase, gid, ftarget_start, ftarget_stop FROM fdata";
			PreparedStatement pstmt = conn.prepareStatement( qs );
			ResultSet rs = pstmt.executeQuery();
			boolean rc = false;
			if( rs.next() )
			{

				setFid( rs.getInt(1) );
				setFref( rs.getString(2) );
				setFstart( rs.getInt(3) );
				setFstop( rs.getInt(4) );
				setFbin( rs.getString(5) );
				setFtypeid( rs.getInt(6) );
				setFscore( rs.getString(7) );
				setFstrand( rs.getString(8) );
				setFphase( rs.getString(9) );
				setGid( rs.getInt(10) );
				setFtargetStart( rs.getInt(11) );
				setFtargetStop( rs.getInt(12) );
				rc = true;
			}
			pstmt.close();
			return rc;
		} catch( Exception ex )
		{
			db.reportError( ex, "DbFdata.fetch()" );
		}
		return false;
	}


    // gid are not inserted 
	public boolean insert( DBAgent db ) throws SQLException {
		Connection conn = db.getConnection(null, false);
		if( conn != null ) try
		{
			String qs = "INSERT INTO fdata (fid, fref, fstart, fstop, fbin, ftypeid, fscore, fstrand, fphase, ftarget_start, ftarget_stop) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
			PreparedStatement pstmt = conn.prepareStatement( qs );
			pstmt.setInt( 1, getFid() );
			pstmt.setString( 2, getFref() );
			pstmt.setInt( 3, getFstart() );
			pstmt.setInt( 4, getFstop() );
			pstmt.setString( 5, getFbin() );
			pstmt.setInt( 6, getFtypeid() );
			pstmt.setString( 7, getFscore() );
			pstmt.setString( 8, getFstrand() );
			pstmt.setString( 9, getFphase() );
			//pstmt.setInt( 10, getGid() );
			pstmt.setInt( 10, getFtargetStart() );
			pstmt.setInt( 11, getFtargetStop() );
			boolean rc = (pstmt.executeUpdate() > 0);
			if( rc ) setFid( db.getLastInsertId(conn) );
			pstmt.close();
			return rc;
		} catch( Exception ex )
		{
			db.reportError( ex, "DbFdata.insert()" );
		}
		return false;
	}

	public boolean update( DBAgent db ) throws SQLException {
		Connection conn = db.getConnection();
		if( conn != null ) try
		{
			String qs = "UPDATE fdata SET fref=?, fstart=?, fstop=?, fbin=?, ftypeid=?, fscore=?, fstrand=?, fphase=?, gid=?, ftarget_start=?, ftarget_stop=? "+
				"WHERE fid="+getFid();
			PreparedStatement pstmt = conn.prepareStatement( qs );
			pstmt.setString( 1, getFref() );
			pstmt.setInt( 2, getFstart() );
			pstmt.setInt( 3, getFstop() );
			pstmt.setString( 4, getFbin() );
			pstmt.setInt( 5, getFtypeid() );
			pstmt.setString( 6, getFscore() );
			pstmt.setString( 7, getFstrand() );
			pstmt.setString( 8, getFphase() );
			pstmt.setInt( 9, getGid() );
			pstmt.setInt( 10, getFtargetStart() );
			pstmt.setInt( 11, getFtargetStop() );
			boolean rc = (pstmt.executeUpdate() > 0);
			pstmt.close();
			return rc;
		} catch( Exception ex )
		{
			db.reportError( ex, "DbFdata.update()" );
		}
		return false;
	}

	public boolean delete( DBAgent db ) throws SQLException {
		Connection conn = db.getConnection();
		if( conn != null ) try
		{
			String qs = "DELETE FROM fdata WHERE fid="+getFid();
			Statement stmt = conn.createStatement();
			boolean rc = (stmt.executeUpdate(qs) > 0);
			stmt.close();
			return rc;
		} catch( Exception ex )
		{
			db.reportError( ex, "DbFdata.delete()" );
		}
		return false;
	}
}

