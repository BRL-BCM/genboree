package org.genboree.dbaccess;

import java.io.*;
import java.util.*;
import java.sql.*;

public class DbFgroup
{
	protected int gid;
	public int getGid() { return gid; }
	public void setGid( int gid ) { this.gid = gid; }
	protected String gclass;
	public String getGclass() { return gclass; }
	public void setGclass( String gclass ) { this.gclass = gclass; }
	protected String gname;
	public String getGname() { return gname; }
	public void setGname( String gname ) { this.gname = gname; }

	public DbFgroup() {}

	public static DbFgroup[] fetchAll( Connection conn )
	{
		Vector v = new Vector();
		if( conn != null ) try
		{
			String qs = "SELECT gid, gclass, gname FROM fgroup";
			PreparedStatement pstmt = conn.prepareStatement( qs );
			ResultSet rs = pstmt.executeQuery();
			while( rs.next() )
			{
				DbFgroup p = new DbFgroup();
				p.setGid( rs.getInt(1) );
				p.setGclass( rs.getString(2) );
				p.setGname( rs.getString(3) );
				v.addElement( p );
			}
			pstmt.close();
		} catch( Exception ex ) { }
		DbFgroup[] rc = new DbFgroup[ v.size() ];
		v.copyInto( rc );
		return rc;
	}

	public boolean fetch( Connection conn )
	{
		if( conn != null ) try
		{
			String qs = "SELECT gclass, gname FROM fgroup WHERE gid="+getGid();
			PreparedStatement pstmt = conn.prepareStatement( qs );
			ResultSet rs = pstmt.executeQuery();
			boolean rc = false;
			if( rs.next() )
			{

				setGclass( rs.getString(1) );
				setGname( rs.getString(2) );
				rc = true;
			}
			pstmt.close();
			return rc;
		} catch( Exception ex ) { }
		return false;
	}

	public boolean insert( Connection conn )
	{
		if( conn != null ) try
		{
			String qs = "INSERT INTO fgroup (gclass, gname) VALUES (?, ?)";
			PreparedStatement pstmt = conn.prepareStatement( qs );
			pstmt.setString( 1, getGclass() );
			pstmt.setString( 2, getGname() );
			boolean rc = (pstmt.executeUpdate() > 0);

            if( rc )
            {
                Statement stmt = conn.createStatement();
                ResultSet rs = stmt.executeQuery( "SELECT LAST_INSERT_ID()" );
                if( rs.next() ) setGid( rs.getInt(1) );
                stmt.close();
            }
			pstmt.close();
			return rc;
		} catch( Exception ex ) { }
		return false;
	}

	public boolean update( Connection conn )
	{
		if( conn != null ) try
		{
			String qs = "UPDATE fgroup SET gclass=?, gname=? "+
				"WHERE gid="+getGid();
			PreparedStatement pstmt = conn.prepareStatement( qs );
			pstmt.setString( 1, getGclass() );
			pstmt.setString( 2, getGname() );
			boolean rc = (pstmt.executeUpdate() > 0);
			pstmt.close();
			return rc;
		} catch( Exception ex ) { }
		return false;
	}

	public boolean delete( Connection conn )
	{
		if( conn != null ) try
		{
			String qs = "DELETE FROM fgroup WHERE gid="+getGid();
			Statement stmt = conn.createStatement();
			boolean rc = (stmt.executeUpdate(qs) > 0);
			stmt.close();
			return rc;
		} catch( Exception ex ) { }
		return false;
	}
}

