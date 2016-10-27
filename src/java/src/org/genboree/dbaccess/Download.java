package org.genboree.dbaccess;

import java.io.*;
import java.util.*;
import java.sql.*;
import java.security.MessageDigest;
import org.genboree.util.* ;

public class Download
{
	protected static final String create_statement =
    "CREATE TABLE `download` (\n"+
    "`regno` varchar(40) NOT NULL default '',\n"+
    "`email` varchar(80) default NULL,\n"+
    "`file` varchar(255) default NULL,\n"+
    "`regDate` datetime NOT NULL default '0000-00-00 00:00:00',\n"+
    "PRIMARY KEY (`regno`)\n"+
    ") ENGINE=MyISAM";

    public static void checkExpired( DBAgent db )
    {
        boolean need_create = false;
        try
        {
            Connection conn = db.getConnection();
            Statement stmt = conn.createStatement();
            stmt.executeUpdate( "DELETE FROM download WHERE regDate<NOW()" );
            stmt.close();
        } catch( Exception ex )
        {
            if( ex instanceof SQLException && ((SQLException)ex).getErrorCode()==1146 )
                need_create = true;
            else db.reportError( ex, "Download.checkExpired()" );
        }
        if( need_create ) try
        {
            Connection conn = db.getConnection();
            Statement stmt = conn.createStatement();
            stmt.executeUpdate( create_statement );
            stmt.close();
        } catch( Exception ex01 )
        {
            db.reportError( ex01, "Download.checkExpired() - create table newuser" );
        }
    }

  protected static String generateRegno(String email)
  {
    return Util.generateUniqueString(email) ;
  }

	protected String regno;
	public String getRegno() { return regno; }
	public void setRegno( String regno ) { this.regno = regno; }
	protected String email;
	public String getEmail() { return email; }
	public void setEmail( String email ) { this.email = email; }
	protected String file;
	public String getFile() { return file; }
	public void setFile( String file ) { this.file = file; }
	protected java.sql.Date regDate;
	public java.sql.Date getRegDate() { return regDate; }
	public void setRegDate( java.sql.Date regDate ) { this.regDate = regDate; }

	public Download() {}

	public boolean fetch( DBAgent db ) throws SQLException {
	    checkExpired( db );
		Connection conn = db.getConnection();
		if( conn != null ) try
		{
			String qs = "SELECT email, file, regDate FROM download WHERE regno=?";
			PreparedStatement pstmt = conn.prepareStatement( qs );
			pstmt.setString( 1, getRegno() );
			ResultSet rs = pstmt.executeQuery();
			boolean rc = false;
			if( rs.next() )
			{
				setEmail( rs.getString(1) );
				setFile( rs.getString(2) );
				setRegDate( rs.getDate(3) );
				rc = true;
			}
			pstmt.close();
			return rc;
		} catch( Exception ex )
		{
			db.reportError( ex, "Download.fetch()" );
		}
		return false;
	}

	public boolean insert( DBAgent db ) throws SQLException {
	    checkExpired( db );
		Connection conn = db.getConnection();
		if( conn != null ) try
		{
		    setRegno( generateRegno(getEmail()) );
			String qs = "INSERT INTO download (regno, email, file, regDate) "+
			"VALUES (?, ?, ?, date_add(now(),interval 1 day))";
			PreparedStatement pstmt = conn.prepareStatement( qs );
			pstmt.setString( 1, getRegno() );
			pstmt.setString( 2, getEmail() );
			pstmt.setString( 3, getFile() );
			boolean rc = (pstmt.executeUpdate() > 0);
			pstmt.close();
			conn.close();
			return rc;
		} catch( Exception ex )
		{
			db.reportError( ex, "Download.insert()" );
		}
		return false;
	}

	public boolean update( DBAgent db ) throws SQLException {
		Connection conn = db.getConnection();
		if( conn != null ) try
		{
			String qs = "UPDATE download SET email=?, file=?, regDate=? "+
				"WHERE regno="+getRegno();
			PreparedStatement pstmt = conn.prepareStatement( qs );
			pstmt.setString( 1, getEmail() );
			pstmt.setString( 2, getFile() );
			pstmt.setDate( 3, getRegDate() );
			boolean rc = (pstmt.executeUpdate() > 0);
			pstmt.close();
			return rc;
		} catch( Exception ex )
		{
			db.reportError( ex, "Download.update()" );
		}
		return false;
	}

	public boolean delete( DBAgent db ) throws SQLException {
		Connection conn = db.getConnection();
		if( conn != null ) try
		{
			String qs = "DELETE FROM download WHERE regno="+getRegno();
			Statement stmt = conn.createStatement();
			boolean rc = (stmt.executeUpdate(qs) > 0);
			stmt.close();
			return rc;
		} catch( Exception ex )
		{
			db.reportError( ex, "Download.delete()" );
		}
		return false;
	}
}
