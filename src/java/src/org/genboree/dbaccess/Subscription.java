package org.genboree.dbaccess;

import java.io.*;
import java.util.*;
import java.sql.*;

public class Subscription
{

    public static final String createStatement = "CREATE TABLE `subscription` (\n"+
    "`subscriptionId` int(10) unsigned NOT NULL auto_increment,\n"+
    "`email` varchar(80) NOT NULL default '',\n"+
    "`news` int(1) NOT NULL default '0',\n"+
    "PRIMARY KEY (`subscriptionId`),\n"+
    "KEY `key_email` (`email`)\n"+
    ") ENGINE=MyISAM";

	protected int subscriptionId;
	public int getSubscriptionId() { return subscriptionId; }
	public void setSubscriptionId( int subscriptionId ) { this.subscriptionId = subscriptionId; }
	protected String email;
	public String getEmail() { return email; }
	public void setEmail( String email ) { this.email = email; }
	protected int news;
	public int getNews() { return news; }
	public void setNews( int news ) { this.news = news; }

	public Subscription() {}

	public static void createTables( DBAgent db ) throws SQLException {
		Connection conn = db.getConnection();
		if( conn != null ) try
		{
		    Statement stmt = conn.createStatement();
		    stmt.executeUpdate( createStatement );
		    stmt.close();
		} catch( Exception ex ) {}
	}

	public static Subscription[] fetchAll( DBAgent db ) throws SQLException {
		Vector v = new Vector();
		Connection conn = db.getConnection();
		if( conn != null ) try
		{
			String qs = "SELECT subscriptionId, email, news FROM subscription";
			PreparedStatement pstmt = conn.prepareStatement( qs );
			ResultSet rs = pstmt.executeQuery();
			while( rs.next() )
			{
				Subscription p = new Subscription();
				p.setSubscriptionId( rs.getInt(1) );
				p.setEmail( rs.getString(2) );
				p.setNews( rs.getInt(3) );
				v.addElement( p );
			}
			pstmt.close();
		} catch( Exception ex )
		{
		    if( ex instanceof SQLException && ((SQLException)ex).getErrorCode()==1146 )
		    {
		        createTables( db );
		    }
		    else
		    {
		        db.reportError( ex, "Subscription.fetchAll()" );
		    }
		}
		Subscription[] rc = new Subscription[ v.size() ];
		v.copyInto( rc );
		return rc;
	}

	public static Subscription fetchSubscription( DBAgent db, String _email ) throws SQLException {
	    Subscription rc = null;
		Connection conn = db.getConnection();
		if( conn != null ) try
		{
			String qs = "SELECT subscriptionId, email, news FROM subscription WHERE email=?";
			PreparedStatement pstmt = conn.prepareStatement( qs );
			pstmt.setString( 1, _email );
			ResultSet rs = pstmt.executeQuery();
			if( rs.next() )
			{
			    rc = new Subscription();
				rc.setSubscriptionId( rs.getInt(1) );
				rc.setEmail( rs.getString(2) );
				rc.setNews( rs.getInt(3) );
			}
			pstmt.close();
		} catch( Exception ex )
		{
		    if( ex instanceof SQLException && ((SQLException)ex).getErrorCode()==1146 )
		    {
		        createTables( db );
		    }
		    else
		    {
		        db.reportError( ex, "Subscription.fetchSubscription()" );
		    }
		}
		return rc;
	}

	public boolean fetch( DBAgent db ) throws SQLException {
		Connection conn = db.getConnection();
		if( conn != null ) try
		{
			String qs = "SELECT email, news FROM subscription "+
			    "WHERE subscriptionId="+getSubscriptionId();
			PreparedStatement pstmt = conn.prepareStatement( qs );
			ResultSet rs = pstmt.executeQuery();
			boolean rc = false;
			if( rs.next() )
			{
				setEmail( rs.getString(1) );
				setNews( rs.getInt(2) );
				rc = true;
			}
			pstmt.close();
			return rc;
		} catch( Exception ex )
		{
		    if( ex instanceof SQLException && ((SQLException)ex).getErrorCode()==1146 )
		    {
		        createTables( db );
		    }
		    else
		    {
		        db.reportError( ex, "Subscription.fetch()" );
		    }
		}
		return false;
	}

	public boolean insert( DBAgent db ) throws SQLException {
		Connection conn = db.getConnection(null, false);
		if( conn != null ) try
		{
			String qs = "INSERT INTO subscription (email, news) VALUES (?, ?)";
			PreparedStatement pstmt = conn.prepareStatement( qs );
			pstmt.setString( 1, getEmail() );
			pstmt.setInt( 2, getNews() );
			boolean rc = (pstmt.executeUpdate() > 0);
			if( rc ) setSubscriptionId( db.getLastInsertId(conn) );
			pstmt.close();
			conn.close();
			return rc;
		} catch( Exception ex )
		{
			db.reportError( ex, "Subscription.insert()" );
		}
		return false;
	}

	public boolean update( DBAgent db ) throws SQLException {
		Connection conn = db.getConnection();
		if( conn != null ) try
		{
			String qs = "UPDATE subscription SET email=?, news=? "+
				"WHERE subscriptionId="+getSubscriptionId();
			PreparedStatement pstmt = conn.prepareStatement( qs );
			pstmt.setString( 1, getEmail() );
			pstmt.setInt( 2, getNews() );
			boolean rc = (pstmt.executeUpdate() > 0);
			pstmt.close();
			return rc;
		} catch( Exception ex )
		{
			db.reportError( ex, "Subscription.update()" );
		}
		return false;
	}

	public boolean delete( DBAgent db ) throws SQLException {
		Connection conn = db.getConnection();
		if( conn != null ) try
		{
			String qs = "DELETE FROM subscription WHERE subscriptionId="+getSubscriptionId();
			Statement stmt = conn.createStatement();
			boolean rc = (stmt.executeUpdate(qs) > 0);
			stmt.close();
			return rc;
		} catch( Exception ex )
		{
			db.reportError( ex, "Subscription.delete()" );
		}
		return false;
	}
}
