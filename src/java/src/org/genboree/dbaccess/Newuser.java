package org.genboree.dbaccess;


import java.util.Vector;
import java.sql.Statement;
import java.sql.Connection;
import java.sql.SQLException;
import java.sql.ResultSet;
import java.sql.PreparedStatement;
import java.security.MessageDigest;
import org.genboree.util.* ;

public class Newuser
{
	protected static final String create_statement =
"CREATE TABLE `newuser` (\n"+
"`newUserId` int(10) unsigned NOT NULL auto_increment,\n"+
"`name` varchar(40) default NULL,\n"+
"`regno` varchar(40) default NULL,\n"+
"`firstName` varchar(40) default NULL,\n"+
"`lastName` varchar(40) default NULL,\n"+
"`institution` varchar(40) default NULL,\n"+
"`email` varchar(80) default NULL,\n"+
"`phone` varchar(40) default NULL,\n"+
"`regDate` datetime NOT NULL default '0000-00-00 00:00:00',\n"+
"PRIMARY KEY (`newUserId`)\n"+
") ENGINE=MyISAM";

// insert into newuser (regDate) values ( date_add(now(),interval 7 day) )
// 1146 = table doesnot exist

    public static void checkExpired( DBAgent db )
    {
        boolean need_create = false;
        try
        {
            Connection conn = db.getConnection();
            Statement stmt = conn.createStatement();
            stmt.executeUpdate( "DELETE FROM newuser WHERE regDate<NOW()" );
            stmt.close();
        } catch( Exception ex )
        {
            if( ex instanceof SQLException && ((SQLException)ex).getErrorCode()==1146 )
                need_create = true;
            else db.reportError( ex, "Newuser.checkExpired()" );
        }
        if( need_create ) try
        {
            Connection conn = db.getConnection();
            Statement stmt = conn.createStatement();
            stmt.executeUpdate( create_statement );
            stmt.close();
        } catch( Exception ex01 )
        {
            db.reportError( ex01, "Newuser.checkExpired() - create table newuser" );
        }
    }

    public static Vector fetchUserNames( DBAgent db ) throws SQLException
    {
      Vector rc = new Vector();
      Connection conn = db.getConnection();
      if( conn == null ) return rc;
      try
      {
          Statement stmt = conn.createStatement();
          ResultSet rs = stmt.executeQuery( "SELECT name, email FROM newuser" );
          while( rs.next() )
          {
              String name = rs.getString(1);
              if( name != null ) rc.addElement( name.toLowerCase() );
              String email = rs.getString(2);
              if( email != null ) rc.addElement( email.toLowerCase() );
          }
          stmt.close();
      } catch( Exception ex01 ) { }
      try
      {
          Statement stmt = conn.createStatement();
          ResultSet rs = stmt.executeQuery( "SELECT name, email FROM genboreeuser" );
          while( rs.next() )
          {
              String name = rs.getString(1);
              if( name != null ) rc.addElement( name.toLowerCase() );
              String email = rs.getString(2);
              if( email != null ) rc.addElement( email.toLowerCase() );
          }
          stmt.close();
      } catch( Exception ex )
      {
          db.reportError( ex, "Newuser.fetchUserNames()" );
      }
      return rc;
  }

  protected static String generateRegno( String userName )
  {
    return Util.generateUniqueString(userName) ;
  }

	protected int newUserId;
	public int getNewUserId() { return newUserId; }
	public void setNewUserId( int newUserId ) { this.newUserId = newUserId; }
	protected String name;
	public String getName() { return name; }
	public void setName( String name ) { this.name = name; }
	protected String regno;
	public String getRegno() { return regno; }
	public void setRegno( String regno ) { this.regno = regno; }
	protected String firstName;
	public String getFirstName() { return firstName; }
	public void setFirstName( String firstName ) { this.firstName = firstName; }
	protected String lastName;
	public String getLastName() { return lastName; }
	public void setLastName( String lastName ) { this.lastName = lastName; }
	protected String institution;
	public String getInstitution() { return institution; }
	public void setInstitution( String institution ) { this.institution = institution; }
	protected String email;
	public String getEmail() { return email; }
	public void setEmail( String email ) { this.email = email; }
	protected String phone;
	public String getPhone() { return phone; }
	public void setPhone( String phone ) { this.phone = phone; }
	protected java.sql.Date regDate;
	public java.sql.Date getRegDate() { return regDate; }
	public void setRegDate( java.sql.Date regDate ) { this.regDate = regDate; }
  protected String accountCode = null ;
  public String getAccountCode()
  {
    return accountCode ;
  }
  public String setAccountCode(String accountCode)
  {
    return this.accountCode = accountCode ;
  }

	public Newuser() {}

	public boolean fetch( DBAgent db, String regno ) throws SQLException {
		Connection conn = db.getConnection();
		if(conn != null) try
		{
			String qs = "SELECT newUserId, name, regno, firstName, lastName, institution, " +
                  "email, phone, regDate, accountCode FROM newuser WHERE regno=? " ;
			PreparedStatement pstmt = conn.prepareStatement( qs ) ;
      pstmt.setString(1, regno) ;
			ResultSet rs = pstmt.executeQuery();
			boolean rc = false;
			if( rs.next() )
			{
				setNewUserId( rs.getInt(1) );
				setName( rs.getString(2) );
				setRegno( rs.getString(3) );
				setFirstName( rs.getString(4) );
				setLastName( rs.getString(5) );
				setInstitution( rs.getString(6) );
				setEmail( rs.getString(7) );
				setPhone( rs.getString(8) );
				setRegDate( rs.getDate(9) );
        this.setAccountCode(rs.getString(10)) ;
				rc = true;
			}
			pstmt.close();
			return rc;
		}
    catch( Exception ex )
		{
			db.reportError( ex, "Newuser.fetch()" );
		}
		return false;
	}

	public boolean insert( DBAgent db ) throws SQLException
  {
		Connection conn = db.getConnection(null, false) ;
    PreparedStatement pstmt = null ;
		if(conn != null)
    {
      try
      {
        setRegno( generateRegno(getName()) ) ;
        String qs = "INSERT INTO newuser (newUserId, name, regno, firstName, lastName, " +
                    "institution, email, phone, regDate, accountCode) " +
                    "VALUES (?, ?, ?, ?, ?, ?, ?, ?, date_add(now(),interval 7 day), ?)" ;
        pstmt = conn.prepareStatement(qs) ;
        pstmt.setInt(1, getNewUserId()) ;
        pstmt.setString(2, getName()) ;
        pstmt.setString(3, getRegno()) ;
        pstmt.setString(4, getFirstName()) ;
        pstmt.setString(5, getLastName()) ;
        pstmt.setString(6, getInstitution()) ;
        pstmt.setString(7, getEmail()) ;
        pstmt.setString(8, getPhone()) ;
        pstmt.setString(9, getAccountCode()) ;
        // Execute and get rows updated count
        boolean rc = (pstmt.executeUpdate() > 0) ;
        // Set the ID of the new user that was just inserted
        if(rc)
        {
          this.setNewUserId(db.getLastInsertId(conn)) ;
        }
        return rc ;
      }
      catch( Exception ex )
      {
        db.reportError( ex, "Newuser.insert()" ) ;
      }
      finally
      {
        pstmt.close() ;
        conn.close() ;
      }
    }
		return false ;
	}

	public boolean delete( DBAgent db ) throws SQLException {
		Connection conn = db.getConnection();
		if( conn != null ) try
		{
			String qs = "DELETE FROM newuser WHERE newUserId="+getNewUserId();
			Statement stmt = conn.createStatement();
			boolean rc = (stmt.executeUpdate(qs) > 0);
			stmt.close();
			return rc;
		} catch( Exception ex )
		{
			db.reportError( ex, "Newuser.delete()" );
		}
		return false;
	}
}
