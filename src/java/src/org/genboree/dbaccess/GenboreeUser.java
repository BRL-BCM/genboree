package org.genboree.dbaccess;

import org.genboree.util.Util;
import java.sql.*;
import java.util.Hashtable;
import java.util.Vector;

public class GenboreeUser
{
    protected String userId;
    protected String name;
    protected String password;
    protected String firstName;
    protected String lastName;
    protected String institution;
    protected String email;
    protected String phone;
    protected String[] groups;
    protected Hashtable htGrpAcs = new Hashtable();
    protected String[] groupAccess = {"ADMINISTRATOR", "AUTHOR", "SUBSCRIBER"};
    protected String[] databaseAccess = {"o", "w", "r"};

    public GenboreeUser()
    {
        clear();
    }
    public String getUserId()
    {
        return userId;
    }
    public void setUserId( String userId )
    {
        if( userId == null ) userId = "#";
        this.userId = userId;
    }
    public String getName()
    {
        return name;
    }
    public void setName( String name )
    {
        this.name = name;
    }
    public String getPassword()
    {
        return password;
    }
    public void setPassword( String password )
    {
        this.password = password;
    }
    public String getFirstName()
    {
        return firstName;
    }
    public void setFirstName( String firstName )
    {
        this.firstName = firstName;
    }
    public String getLastName()
    {
        return lastName;
    }
    public void setLastName( String lastName )
    {
        this.lastName = lastName;
    }
    public String getInstitution()
    {
        return institution;
    }
    public void setInstitution( String institution )
    {
        this.institution = institution;
    }
    public String getEmail()
    {
        return email;
    }
    public void setEmail( String email )
    {
        this.email = email;
    }
    public String getPhone()
    {
        return phone;
    }
    public void setPhone( String phone )
    {
        this.phone = phone;
    }
    public String[] getGroups()
    {
        return groups;
    }
    public void setGroups( String[] groups )
    {
        if( groups == null ) groups = new String[0];
        this.groups = groups;
    }
    public boolean belongsTo( String groupId )
    {
        for( int i=0; i<groups.length; i++ )
            if( groupId.equals(groups[i]) ) return true;
        return false;
    }
    public boolean isGroupOwner( String grpId )
    {
        String grpAcs = (String) htGrpAcs.get( grpId );
        if( grpAcs == null ) return false;
        return grpAcs.equals("o");
    }
    public boolean isReadOnlyGroup( String grpId )
    {
        String grpAcs = (String) htGrpAcs.get( grpId );
        if( grpAcs == null ) return false;
        return grpAcs.equals("r");
    }
    public boolean isAnyGroupOwner()
    {
        if( groups == null ) return false;
        for( int i=0; i<groups.length; i++ )
            if( isGroupOwner(groups[i]) ) return true;
        return false;
    }
    public void clear()
    {
        userId = "#";
        name = password = firstName = lastName = institution = email = phone = "";
        groups = new String[0];
    }
    public String getFullName()
    {
        String fn = getFirstName();
        if( fn == null ) fn = "";
        String ln = getLastName();
        if( ln == null ) ln = "";
        String rc = (fn + " " + ln).trim();
        if( rc.length() == 0 ) return getName();
        return rc;
    }
    public String getScreenName()
    {
        String fn = getFullName();
        if( fn.equals(getName()) ) return fn;
        return getName() + " (" + fn + ")";
    }
    public static GenboreeUser[] fetchAll( DBAgent db ) throws SQLException
    {
        Connection conn = db.getConnection();
        if( conn == null ) return null;
        try
        {
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery(
                    "SELECT userId, name, password, firstName, lastName, institution, email, phone FROM genboreeuser ORDER BY name" ) ;
            Vector v = new Vector();
            while( rs.next() )
            {
                GenboreeUser u = new GenboreeUser();
                u.setUserId( rs.getString(1) );
                u.setName( rs.getString(2) );
                u.setPassword( rs.getString(3) );
                u.setFirstName( rs.getString(4) );
                u.setLastName( rs.getString(5) );
                u.setInstitution( rs.getString(6) );
                u.setEmail( rs.getString(7) );
                u.setPhone( rs.getString(8) );
                v.addElement( u );
            }
            stmt.close();
            GenboreeUser[] rc = new GenboreeUser[ v.size() ];
            v.copyInto( rc );
            return rc;
        } catch( Exception ex ) {
            db.reportError( ex, "GenboreeUser.fetchAll()" );
        }
        return null;
    }

  public static GenboreeUser fetch( String userIdStr )
  {
    DBAgent db = DBAgent.getInstance() ;
    GenboreeUser usr = null ;
    Connection conn = null ;
    ResultSet rs = null ;
    Statement stmt = null ;

    if(userIdStr != null || userIdStr.length() >= 1) // then given a maybe valid userIdStr
    {
      if( userIdStr.equals( "0" ) )
      {
        usr = new GenboreeUser() ;
        usr.setUserId( "0" ) ;
        usr.setName( "Public" ) ;
        usr.setPassword( "" ) ;
        usr.setFirstName( "Guest" ) ;
        return usr ;
      }

      try
      {
        conn = db.getConnection() ;
        stmt = conn.createStatement() ;
        rs = stmt.executeQuery( "SELECT userId, name, password, firstName, lastName, institution, email, phone " +
                "FROM genboreeuser WHERE userId=" + userIdStr ) ;
        if( rs.next() )
        {
          usr = new GenboreeUser() ;
          usr.setUserId( rs.getString( 1 ) ) ;
          usr.setName( rs.getString( 2 ) ) ;
          usr.setPassword( rs.getString( 3 ) ) ;
          usr.setFirstName( rs.getString( 4 ) ) ;
          usr.setLastName( rs.getString( 5 ) ) ;
          usr.setInstitution( rs.getString( 6 ) ) ;
          usr.setEmail( rs.getString( 7 ) ) ;
          usr.setPhone( rs.getString( 8 ) ) ;
        }
      }
      catch( Exception ex )
      {
        System.err.println( "Exception on GenboreeUser static method fetch the userId is " + userIdStr ) ;
        ex.printStackTrace( System.err ) ;
      }
      finally
      {
        db.safelyCleanup( rs, stmt, conn ) ;
        return usr ;
      }
    }
    return usr ;
  }

  // There is a lighter weight version that reuses an existing Connection below.
    // Use it as much as possible, to avoid unnecessary calls to db.getConnection()
    // especially in loops.
    public boolean fetch( DBAgent db ) throws SQLException
    {
      boolean retVal = false ;
      String userIdStr = getUserId() ;
      if(userIdStr != null && userIdStr.length() >= 1 && !getUserId().equals("#"))
      {
        if(getUserId().equals("0"))
        {
          clear() ;
          setUserId( "0" ) ;
          setName( "Public" ) ;
          setPassword( "" ) ;
          setFirstName( "Guest" ) ;
        }
        Connection conn = db.getConnection() ;
        ResultSet rs = null ;
        Statement stmt = null ;
        if(conn != null)
        {
          try
          {
            stmt = conn.createStatement() ;
            rs = stmt.executeQuery( "SELECT userId, name, password, firstName, lastName, institution, email, phone " +
                                    "FROM genboreeuser WHERE userId=" + userIdStr ) ;
            if(rs.next())
            {
              setUserId( rs.getString(1) ) ;
              setName( rs.getString(2) ) ;
              setPassword( rs.getString(3) ) ;
              setFirstName( rs.getString(4) ) ;
              setLastName( rs.getString(5) ) ;
              setInstitution( rs.getString(6) ) ;
              setEmail( rs.getString(7) ) ;
              setPhone( rs.getString(8) ) ;
              retVal = true ;
            }
          }
          catch(Exception ex)
          {
            db.reportError( ex, "GenboreeUser.fetch()" );
            retVal = false ;
          }
          finally
          {
            db.safelyCleanup(rs, stmt, conn) ;
          }
        }
      }
      return retVal ;
    }

    // Use this version as much as possible, since it reuses an existing connection
    // and saves on method calls to db.getConnection()
    public boolean fetch(Connection conn) throws SQLException
    {
      if(getUserId().equals("#"))
      {
        return false ;
      }
      if(getUserId().equals("0"))
      {
        clear() ;
        setUserId( "0" ) ;
        setName( "Public" ) ;
        setPassword( "" ) ;
        setFirstName( "Guest" ) ;
      }
      if(conn == null)
      {
        return false ;
      }
      try
      {
        Statement stmt = conn.createStatement() ;
        ResultSet rs =  stmt.executeQuery(
                        "SELECT userId, name, password, firstName, "+
                        "lastName, institution, email, phone "+
                        "FROM genboreeuser WHERE userId=" + getUserId() ) ;
        if(rs.next())
        {
          setUserId(rs.getString(1)) ;
          setName(rs.getString(2)) ;
          setPassword(rs.getString(3)) ;
          setFirstName(rs.getString(4)) ;
          setLastName(rs.getString(5)) ;
          setInstitution(rs.getString(6)) ;
          setEmail(rs.getString(7)) ;
          setPhone(rs.getString(8)) ;
          stmt.close() ;
          return true ;
        }
        stmt.close() ;
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: GenboreeUser.fetch(Connection) => exception thrown. Details:\n" + ex.getMessage()) ;
        ex.printStackTrace(System.err) ;
      }
      return false ;
    }

    public boolean fetchByNameOrEmail( DBAgent db ) throws SQLException
    {
        boolean rc = false;
        Connection conn = db.getConnection();
        if( conn == null ) return false;
        try
        {
            String name = getName();
            String email = getEmail();
            String qs0 = "SELECT userId, name, password, firstName, "+
                    "lastName, institution, email, phone "+
                    "FROM genboreeuser WHERE ";
            PreparedStatement pstmt = null;
            ResultSet rs = null;
            if( !Util.isEmpty(name) )
            {
                pstmt = conn.prepareStatement( qs0+"name=?" );
                pstmt.setString( 1, name );
                ResultSet rs1 = pstmt.executeQuery();
                if( rs1.next() ) rs = rs1;
            }
            if( rs==null && !Util.isEmpty(email) )
            {
                pstmt = conn.prepareStatement( qs0+"email=?" );
                pstmt.setString( 1, email );
                ResultSet rs2 = pstmt.executeQuery();
                if( rs2.next() ) rs = rs2;
            }
            if( rs != null )
            {
                setUserId( rs.getString(1) );
                setName( rs.getString(2) );
                setPassword( rs.getString(3) );
                setFirstName( rs.getString(4) );
                setLastName( rs.getString(5) );
                setInstitution( rs.getString(6) );
                setEmail( rs.getString(7) );
                setPhone( rs.getString(8) );
                rc = true;
            }
            if( pstmt != null ) pstmt.close();
            return rc;
        } catch( Exception ex ) {
            db.reportError( ex, "GenboreeUser.fetchByNameOrEmail()" );
        }
        return false;
    }
    public static String fetchPublicUserId( DBAgent db ) throws SQLException
    {
        Connection conn = db.getConnection();
        if( conn == null ) return "#";
        try
        {
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery(
                    "SELECT userId FROM genboreeuser WHERE name='public' OR name='Public'" );
            if( rs.next() )
            {
                String rc = rs.getString(1);
                stmt.close();
                return rc;
            }
            stmt.close();
        } catch( Exception ex ) {
            db.reportError( ex, "GenboreeUser.fetchPublicUserId()" );
        }
        return "#";
    }
    public String getDatabaseAccessFromGroupAccess(String myGroupAccess)
    {
        for(int i = 0; i < databaseAccess.length; i++)
        {
            if(myGroupAccess.equalsIgnoreCase(groupAccess[i]))
                return databaseAccess[i];
        }
        return null;
    }
    public String getGroupAccessFromDatabaseAccess(String myDatabaseAccess)
    {
        for(int i = 0; i < groupAccess.length; i++)
        {
            if(myDatabaseAccess.equalsIgnoreCase(databaseAccess[i]))
                return groupAccess[i];
        }
        return null;
    }
    public String getGroupAccess( DBAgent db, String groupId ) throws SQLException
    {
        String access = null;
        String groupAccess = null;
        if( getUserId().equals("#") ) return null;
        Connection conn = db.getConnection();
        if( conn == null ) return null;
        try
        {
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery(
                    "SELECT userGroupAccess FROM usergroup WHERE userId=" + getUserId() + " AND groupId = " + groupId);

            if( rs.next() )
                access = rs.getString(1);
            stmt.close();
            if(access != null)
                groupAccess = getGroupAccessFromDatabaseAccess(access);

        } catch( Exception ex ) {
            db.reportError( ex, "GenboreeUser.getGroupAccess" );
        }
        return groupAccess;
    }
    public String[] fetchGroupsWithSpecificGroupAccess( DBAgent db, String myGroupAccess ) throws SQLException
    {
        String myDatabaseAccess = null;
        String[] groupsWithSpecificAccess = null;
        if( getUserId().equals("#") ) return null;
        Connection conn = db.getConnection();
        if( conn == null ) return null;
        if(myGroupAccess == null) return null;

        myDatabaseAccess = getDatabaseAccessFromGroupAccess(myGroupAccess);
        if(myDatabaseAccess == null) return null;
        try
        {
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery(
                    "SELECT groupId FROM usergroup WHERE userId = " + getUserId() + " and userGroupAccess = '" +
                    myDatabaseAccess + "'");
            Vector v = new Vector();
            while( rs.next() )
            {
                String grpId = rs.getString(1);
                if( grpId != null)
                    v.addElement( grpId );
            }
            stmt.close();
            groupsWithSpecificAccess = new String[ v.size() ];
            v.copyInto( groupsWithSpecificAccess );

        } catch( Exception ex ) {
            db.reportError( ex, "fetchGroupsWithSpecificGroupAccess" );
        }
        return groupsWithSpecificAccess;
    }
    public boolean fetchGroups( DBAgent db ) throws SQLException
    {
        if( getUserId().equals("#") ) return false;
        Connection conn = db.getConnection();
        if( conn == null ) return false;
        try
        {
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery(
                    "SELECT groupId, userGroupAccess FROM usergroup WHERE userId=" + getUserId() );
            Vector v = new Vector();
            htGrpAcs.clear();
            while( rs.next() )
            {
                String grpId = rs.getString(1);
                String grpAcs = rs.getString(2);
                v.addElement( grpId );
                if( grpId != null && grpAcs != null ) htGrpAcs.put( grpId, grpAcs );
            }
            stmt.close();
            groups = new String[ v.size() ];
            v.copyInto( groups );
            return true;
        } catch( Exception ex ) {
            db.reportError( ex, "GenboreeUser.fetchGroups()" );
        }
        return false;
    }
    public boolean update( DBAgent db ) throws SQLException
    {
        if( getUserId().equals("#") ) return false;
        Connection conn = db.getConnection();
        if( conn == null ) return false;
        int nrows = 0;
        try
        {
            PreparedStatement pstmt = conn.prepareStatement(
                    "UPDATE genboreeuser SET name=?, password=?, "+
                    "firstName=?, lastName=?, institution=?, email=?, "+
                    "phone=? WHERE userId="+getUserId() );
            pstmt.setString( 1, getName() );
            pstmt.setString( 2, getPassword() );
            pstmt.setString( 3, getFirstName() );
            pstmt.setString( 4, getLastName() );
            pstmt.setString( 5, getInstitution() );
            pstmt.setString( 6, getEmail() );
            pstmt.setString( 7, getPhone() );
            nrows = pstmt.executeUpdate();
            pstmt.close();
        } catch( Exception ex ) {
            db.reportError( ex, "GenboreeUser.update()" );
        }
        return (nrows > 0);
    }
    public boolean delete( DBAgent db ) throws SQLException
    {
        if( getUserId().equals("#") ) return false;
        Connection conn = db.getConnection();
        if( conn == null ) return false;
        int nrows = 0;
        try
        {
            Statement stmt = conn.createStatement();
            stmt.executeUpdate( "DELETE FROM usergroup WHERE userId=" + getUserId() );
            nrows = stmt.executeUpdate( "DELETE FROM genboreeuser WHERE userId=" + getUserId() );
            stmt.close();
            if( nrows > 0 ) clear();
        } catch( Exception ex ) {
            db.reportError( ex, "GenboreeUser.delete()" );
        }
        return (nrows > 0);
    }
    public String checkLoginName( DBAgent db ) throws SQLException
    {
        Connection conn = db.getConnection();
        if( conn == null ) return "No DB connection available";
        String myId = getUserId();
        String loginName = getName();
        if( loginName == null ) loginName = "";
        if( loginName.trim().length() == 0 ) return "Login name must not be empty";
        try
        {
            PreparedStatement pstmt = conn.prepareStatement(
                    "SELECT userId FROM genboreeuser WHERE name=?" );
            pstmt.setString( 1, loginName );
            ResultSet rs = pstmt.executeQuery();
            String rc = null;
            if( rs.next() )
            {
                String herId = rs.getString(1);
                if( !herId.equals(myId) )
                    rc = "Another user with the same login name ("+loginName+
                            ") exists. Please enter a different name and try again.";
            }
            pstmt.close();
            return rc;
        } catch( Exception ex ) {
            db.reportError( ex, "GenboreeUser.checkLoginName()" );
        }
        return "Database error";
    }
    public boolean insert( DBAgent db ) throws SQLException
    {
        if( !getUserId().equals("#") ) return false;
        Connection conn = db.getConnection();
        if( conn == null ) return false;
        int nrows = 0;
        try
        {
            PreparedStatement pstmt = conn.prepareStatement(
                    "INSERT INTO genboreeuser (name, password, firstName, "+
                    "lastName, institution, email, phone) VALUES (?,?,?,?,?,?,?)" );
            pstmt.setString( 1, getName() );
            pstmt.setString( 2, getPassword() );
            pstmt.setString( 3, getFirstName() );
            pstmt.setString( 4, getLastName() );
            pstmt.setString( 5, getInstitution() );
            pstmt.setString( 6, getEmail() );
            pstmt.setString( 7, getPhone() );
            nrows = pstmt.executeUpdate();
            if( nrows > 0 )
            {
                pstmt.close();
                pstmt = conn.prepareStatement(
                        "SELECT userId FROM genboreeuser WHERE name=?" );
                pstmt.setString( 1, getName() );
                ResultSet rs = pstmt.executeQuery();
                if( rs.next() )
                {
                    setUserId( rs.getString(1) );
                }
                else nrows = 0;
            }
            pstmt.close();
        } catch( Exception ex ) {
            db.reportError( ex, "GenboreeUser.insert()" );
        }
        return (nrows > 0);
    }
    public boolean updateGroups( DBAgent db ) throws SQLException
    {
        if( getUserId().equals("#") ) return false;
        Connection conn = db.getConnection();
        if( conn == null ) return false;
        try
        {
            Statement stmt = conn.createStatement();
            stmt.executeUpdate( "DELETE FROM usergroup WHERE userId=" + getUserId() );
            stmt.close();
            PreparedStatement pstmt = conn.prepareStatement(
                    "INSERT INTO usergroup (userId, groupId, userGroupAccess) "+
                    "VALUES ("+getUserId()+", ?, ?)" );
            for( int i=0; i<groups.length; i++ )
            {
                String grpId = groups[i];
                String grpAcs = (String) htGrpAcs.get( grpId );
                if( grpAcs == null ) grpAcs = "w";
                pstmt.setString( 1, grpId );
                pstmt.setString( 2, grpAcs );
                pstmt.executeUpdate();
            }
            pstmt.close();
            return true;
        } catch( Exception ex ) {
            db.reportError( ex, "GenboreeUser.updateGroups()" );
        }
        return false;
    }
}
