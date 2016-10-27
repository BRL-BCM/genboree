package org.genboree.dbaccess;

import org.genboree.message.GenboreeMessage;
import org.genboree.util.*;

import javax.servlet.http.HttpSession;
import javax.servlet.jsp.JspWriter;
import java.net.InetAddress;
import java.net.UnknownHostException;
import java.sql.*;
import java.util.* ;
import java.io.* ;

public class GenboreeGroup
{
    protected String groupId;
    protected String groupName;
    protected String[] refseqs;
    protected String description;
    protected int student;
    protected String[] usrIds = null;
    protected Hashtable htGrpAcs = new Hashtable();
    protected GenboreeUser[] usrs = null;
    protected String possibleAcsValues = "#owr";
    public static String[] acsCodes = { "o", "w", "r", "#" };
    public static String[] acsNames = { "ADMINISTRATOR", "AUTHOR (R/W)", "SUBSCRIBER (R)", "-- Revoke --" };

    public static String[] modeIds =
            {
                "Create", "Delete", "Update", "AddUser", "SetRoles", "CopyUsers"
            };
    public static String[] modeLabs =
            {
                "Create", "Delete", "Update", "Add&nbsp;User", "Update&nbsp;Roles", "Copy&nbsp;Users"
            };
    public static final int MODE_DEFAULT = -1;
    public static final int MODE_CREATE = 0;
    public static final int MODE_DELETE = 1;
    public static final int MODE_UPDATE = 2;
    public static final int MODE_ADDUSER = 3;
    public static final int MODE_SETROLES = 4;
    public static final int MODE_COPYUSERS = 5;
    public static String adrFrom = "\"Genboree Team\" <" + GenboreeConfig.getConfigParam("gbFromAddress") + ">";


    public String getGroupId()
    {
        return groupId;
    }
    public void setGroupId( String groupId )
    {
        if( groupId == null ) groupId = "#";
        this.groupId = groupId;
    }
    public String getGroupName()
    {
        return groupName;
    }
    public void setGroupName( String groupName )
    {
        this.groupName = groupName;
    }
    public String getDescription()
    {
        return description;
    }
    public void setDescription( String description )
    {
        this.description = description;
    }
    public int getStudent()
    {
        return student;
    }
    public void setStudent( int student )
    {
        this.student = student;
    }
    public String[] getRefseqs()
    {
        return refseqs;
    }
    public void setRefseqs( String[] refseqs )
    {
        if( refseqs == null ) refseqs = new String[0];
        this.refseqs = refseqs;
    }
    public boolean belongsTo( String refSeqId )
    {
        if(refSeqId == null || refseqs == null) return false;

        for( int i=0; i<refseqs.length; i++ )
            if( refSeqId.equals(refseqs[i]) ) return true;
        return false;
    }
    public void clear()
    {
        groupId = "#";
        groupName = description = "";
        student = 0;
        refseqs = new String[0];
    }
    public GenboreeGroup()
    {
        clear();
    }
    public String getScreenName()
    {
        return getGroupName();
    }
    public boolean fetch( DBAgent db ) throws SQLException
    {
        if( getGroupId().equals("#") ) return false;
        Connection conn = db.getConnection();
        if( conn == null ) return false;
        try
        {
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery(
                    "SELECT groupId, groupName, description, student "+
                    "FROM genboreegroup WHERE groupId=" + getGroupId() );
            if( rs.next() )
            {
                setGroupId( rs.getString(1) );
                setGroupName( rs.getString(2) );
                setDescription( rs.getString(3) );
                setStudent( rs.getInt(4) );
                stmt.close();
                return true;
            }
            stmt.close();
        } catch( Exception ex ) {
            db.reportError( ex, "GenboreeGroup.fetch()" );
        }
        return false;
    }
    public String[] getUserIds()
    {
        return usrIds;
    }
    public GenboreeUser[] getUsers()
    {
        return usrs;
    }
    public String[] getUserIds( DBAgent db ) throws SQLException
    {
        if( usrIds == null ) fetchUsers( db );
        return usrIds;
    }
    public GenboreeUser[] getUsers( DBAgent db ) throws SQLException
    {
        if( usrIds == null ) fetchUsers( db );
        return usrs;
    }
    public boolean isOwner( String userId )
    {
        String acs = (String) htGrpAcs.get( userId );
        if( acs == null ) return false;
        return acs.equals("o");
    }
    public boolean isReadOnly( String userId )
    {
        String acs = (String) htGrpAcs.get( userId );
        if( acs == null ) return false;
        return acs.equals("r");
    }
    public boolean hasAccess( String userId )
    {
        String acs = (String) htGrpAcs.get( userId );
        return (acs != null);
    }

    // This version calls db.getConnection(). If called many many times (in a loop)
    // it's a waste. Use fetchUsers(Connection) is better.
    public boolean fetchUsers( DBAgent db ) throws SQLException
    {
        boolean rc = false;
        Vector v = new Vector();
        Connection conn = db.getConnection();
        if( conn != null && !getGroupId().equals("#") )
            try
            {
                Statement stmt = conn.createStatement();
                ResultSet rs = stmt.executeQuery(
                        "SELECT userId, userGroupAccess FROM usergroup WHERE groupId=" + getGroupId() );
                htGrpAcs.clear();
                while( rs.next() )
                {
                    String userId = rs.getString(1);
                    String acs = rs.getString(2);
                    v.addElement( userId );
                    if( acs == null ) acs = "w";
                    htGrpAcs.put( userId, acs );
                }
                stmt.close();
                rc = true;
            } catch( Exception ex ) {
                db.reportError( ex, "GenboreeGroup.fetch()" );
            }
        usrIds = new String[ v.size() ];
        v.copyInto( usrIds );
        if( rc )
        {
            usrs = new GenboreeUser[ usrIds.length ];
            for( int i=0; i<usrIds.length; i++ )
            {
                GenboreeUser usr = new GenboreeUser();
                usr.setUserId( usrIds[i] );
                usr.fetch( db );
                usrs[i] = usr;
            }
            db.clearLastError();
        }
        return rc;
    }

    // This version reuses an existing Connection. It's thus lighter weight
    // than the version about that uses DBAgent, especially if called many many times (in a loop).
    public boolean fetchUsers( Connection conn ) throws SQLException
    {
      boolean rc = false ;
      ArrayList vv = new ArrayList() ;
      if(conn != null && !getGroupId().equals("#"))
      {
        try
        {
          Statement stmt = conn.createStatement() ;
          ResultSet rs = stmt.executeQuery("SELECT userId, userGroupAccess FROM usergroup WHERE groupId = " + getGroupId() ) ;
          htGrpAcs.clear() ;
          while(rs.next())
          {
            String userId = rs.getString(1) ;
            String acs = rs.getString(2) ;
            vv.add(userId) ;
            if(acs == null)
            {
              acs = "w" ;
            }
            htGrpAcs.put(userId, acs) ;
          }
          stmt.close() ;
          rc = true ;
        }
        catch(Exception ex)
        {
          System.err.println("ERROR: GenboreeGroup.fetchUsers(Connection) => exception thrown. Details:\n" + ex.getMessage()) ;
          ex.printStackTrace(System.err) ;
        }
      }
      usrIds = new String[ vv.size() ] ;
      vv.toArray(usrIds) ;
      if(rc)
      {
        usrs = new GenboreeUser[ usrIds.length ] ;
        for( int i=0; i<usrIds.length; i++ )
        {
            GenboreeUser usr = new GenboreeUser() ;
            usr.setUserId( usrIds[i] ) ;
            usr.fetch( conn ) ;
            usrs[i] = usr ;
        }
      }
      return rc ;
    }

    public boolean grantAccess( DBAgent db, String userId, String acs ) throws SQLException
    {
        if( acs == null ) acs = "#";
        if( possibleAcsValues.indexOf(acs)<0 || acs.length()>1 ) return false;
        Connection conn = db.getConnection();
        if( userId==null || conn==null ) return false;
        try
        {
            Statement stmt = conn.createStatement();
            stmt.executeUpdate( "DELETE FROM usergroup "+
                    "WHERE userId="+userId+" AND groupId="+getGroupId() );
            htGrpAcs.remove( userId );
            if( !acs.equals("#") )
            {
                stmt.executeUpdate( "INSERT INTO usergroup (userId, groupId, userGroupAccess) "+
                        "VALUES ("+userId+", "+getGroupId()+", '"+acs+"')" );
                htGrpAcs.put( userId, acs );
            }
            stmt.close();
            return true;
        } catch( Exception ex ) {
            db.reportError( ex, "GenboreeGroup.grantAccess()" );
        }
        return false;
    }

  // There is a static lighter weight version MLGG
    public static GenboreeGroup fetchByGroupId( String groupIdStr )
    {
        DBAgent db = null;
        Connection conn = null;
      ResultSet rs = null;
      PreparedStatement pstmt = null;
        GenboreeGroup  group = new GenboreeGroup();
          if( groupIdStr == null || groupIdStr.length() < 1 )
            return null;

        try
        {
           db = DBAgent.getInstance();
           conn = db.getConnection();
           pstmt = conn.prepareStatement(
                    "SELECT groupId, groupName, description, student "+
                    "FROM genboreegroup WHERE groupId = ?" );
            pstmt.setString( 1,  groupIdStr);
            rs = pstmt.executeQuery();
            if( rs.next() )
            {
                group.setGroupId( rs.getString(1) );
                group.setGroupName( rs.getString(2) );
                group.setDescription( rs.getString(3) );
                group.setStudent( rs.getInt(4) );
            }
            group.fetchRefseqs( db );
            //group.fetchUsers( db );
        }
        catch( Exception ex )
        {
          System.err.println( "Exception on GenboreeUser static method fetch the userId is " + groupIdStr );
          ex.printStackTrace( System.err );
        }
        finally
        {
          db.safelyCleanup(rs, pstmt, conn );
          return group;
        }

    }


    public boolean fetchByName( DBAgent db ) throws SQLException
    {
        Connection conn = db.getConnection();
        if( conn == null ) return false;
        try
        {
            PreparedStatement pstmt = conn.prepareStatement(
                    "SELECT groupId, groupName, description, student "+
                    "FROM genboreegroup WHERE groupName=?" );
            pstmt.setString( 1, getGroupName() );
            ResultSet rs = pstmt.executeQuery();
            if( rs.next() )
            {
                setGroupId( rs.getString(1) );
                setGroupName( rs.getString(2) );
                setDescription( rs.getString(3) );
                setStudent( rs.getInt(4) );
                pstmt.close();
                return true;
            }
            pstmt.close();
        } catch( Exception ex ) {
            db.reportError( ex, "GenboreeGroup.fetchByName()" );
        }
        return false;
    }

    // This version calls db.getConnection(). If called many many times (in a loop)
    // it's a waste. Use fetchRefseqs(Connection) is better.
    public boolean fetchRefseqs( DBAgent db ) throws SQLException
    {
        if( getGroupId().equals("#") ) return false;
        Connection conn = db.getConnection();
        if( conn == null ) return false;
        try
        {
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery(
                    "SELECT refSeqId FROM grouprefseq WHERE groupId=" + getGroupId() );
            Vector v = new Vector();
            while( rs.next() )
            {
                v.addElement( rs.getString(1) );
            }
            stmt.close();
            refseqs = new String[ v.size() ];
            v.copyInto( refseqs );
            return true;
        } catch( Exception ex ) {
            db.reportError( ex, "GenboreeGroup.fetchRefseqs()" );
        }
        return false;
    }

    // This version reuses an existing Connection. It's thus lighter weight
    // than the version about that uses DBAgent, especially if called many many times (in a loop).
    public boolean fetchRefseqs( Connection conn ) throws SQLException
    {
      if( getGroupId().equals("#") )
      {
        return false ;
      }
      if(conn == null)
      {
        return false ;
      }
      try
      {
        Statement stmt = conn.createStatement() ;
        ResultSet rs = stmt.executeQuery("SELECT refSeqId FROM grouprefseq WHERE groupId=" + getGroupId()) ;
        ArrayList vv = new ArrayList() ;
        while(rs.next())
        {
          vv.add(rs.getString(1)) ;
        }
        stmt.close() ;
        refseqs = new String[ vv.size() ] ;
        vv.toArray(refseqs) ;
        return true ;
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: GenboreeGroup.fetchRefseqs(Connection) => exception thrown. Details:\n" + ex.getMessage()) ;
        ex.printStackTrace(System.err) ;
      }
      return false ;
    }

    public boolean update( DBAgent db ) throws SQLException
    {
        if( getGroupId().equals("#") ) return false;
        Connection conn = db.getConnection();
        if( conn == null ) return false;
        int nrows = 0;
        try
        {
            PreparedStatement pstmt = conn.prepareStatement(
                    "UPDATE genboreegroup SET groupName=?, description=?, student=? "+
                    "WHERE groupId="+getGroupId() );
            pstmt.setString( 1, getGroupName() );
            pstmt.setString( 2, getDescription() );
            pstmt.setInt( 3, getStudent() );
            nrows = pstmt.executeUpdate();
            pstmt.close();
        } catch( Exception ex ) {
            db.reportError( ex, "GenboreeGroup.update()" );
        }
        return (nrows > 0);
    }
    public boolean delete( DBAgent db ) throws SQLException
    {
        if( getGroupId().equals("#") ) return false;
        Connection conn = db.getConnection();
        if( conn == null ) return false;
        int nrows = 0;
        try
        {
            // Delete annotationDataFiles
            deleteAnnotationDataFilesDir() ;

            Statement stmt = conn.createStatement();

            // Delete gbKeys
            stmt.executeUpdate( "DELETE unlockedGroupResources.*, unlockedGroupResourceParents.* " +
                                "FROM unlockedGroupResources " +
                                "LEFT JOIN unlockedGroupResourceParents "+
                                "ON unlockedGroupResources.id = unlockedGroupResourceParents.unlockedGroupResource_id "+
                                "WHERE unlockedGroupResources.group_id=" + getGroupId() ) ;

            stmt.executeUpdate( "DELETE FROM usergroup WHERE groupId=" + getGroupId() );
            stmt.executeUpdate( "DELETE FROM grouprefseq WHERE groupId=" + getGroupId() );
            nrows = stmt.executeUpdate( "DELETE FROM genboreegroup WHERE groupId=" + getGroupId() );
            stmt.close();
            if( nrows > 0 ) clear();
        } catch( Exception ex ) {
            db.reportError( ex, "GenboreeGroup.delete()" );
        }
        return (nrows > 0);
    }
    public boolean insert( DBAgent db ) throws SQLException
    {
        if( !getGroupId().equals("#") ) return false;
        Connection conn = db.getConnection();
        if( conn == null ) return false;
        int nrows = 0;
        try
        {
            PreparedStatement pstmt = conn.prepareStatement(
                    "INSERT INTO genboreegroup (groupName, description, student) VALUES (?,?,?)" );
            pstmt.setString( 1, getGroupName() );
            pstmt.setString( 2, getDescription() );
            pstmt.setInt( 3, getStudent() );
            nrows = pstmt.executeUpdate();
            if( nrows > 0 )
            {
                pstmt.close();
                pstmt = conn.prepareStatement(
                        "SELECT MAX(groupId) FROM genboreegroup "+
                        "WHERE groupName=? AND description=?" );
                pstmt.setString( 1, getGroupName() );
                pstmt.setString( 2, getDescription() );
                ResultSet rs = pstmt.executeQuery();
                if( rs.next() )
                {
                    setGroupId( rs.getString(1) );
                }
                else nrows = 0;
            }
            pstmt.close();
        } catch( Exception ex ) {
            db.reportError( ex, "GenboreeGroup.insert()" );
        }
        return (nrows > 0);
    }
    public boolean updateRefseqs( DBAgent db ) throws SQLException
    {
        if( getGroupId().equals("#") ) return false;
        Connection conn = db.getConnection();
        if( conn == null ) return false;
        try
        {
            Statement stmt = conn.createStatement();
            stmt.executeUpdate( "DELETE FROM grouprefseq WHERE groupId=" + getGroupId() );
            stmt.close();
            PreparedStatement pstmt = conn.prepareStatement(
                    "INSERT INTO grouprefseq(groupId,refSeqId) VALUES("+getGroupId()+",?)" );
            for( int i=0; i<refseqs.length; i++ )
            {
                pstmt.setString( 1, refseqs[i] );
                pstmt.executeUpdate();
            }
            pstmt.close();
            return true;
        } catch( Exception ex ) {
            db.reportError( ex, "GenboreeGroup.updateRefseqs()" );
        }
        return false;
    }

    // Versions reusing Connection rather than continuously asking db to getConnection()
    // are available below for loops, etc.
    public static GenboreeGroup[] fetchAll( DBAgent db ) throws SQLException
    {
        return fetchAll( db, null );
    }
    public static GenboreeGroup[] fetchAll( DBAgent db, String userId ) throws SQLException
    {
        Connection conn = db.getConnection();
        if( conn == null ) return null;
        try
        {
            String qs = "SELECT groupId, groupName, description, student FROM genboreegroup "+
                    "ORDER BY groupName";
            if( userId != null )
            {
                qs = userId.equals("0") ?
                        "SELECT groupId, groupName, description, student FROM genboreegroup "+
                        "WHERE groupName='Public'" :
                        "SELECT gr.groupId, gr.groupName, gr.description, gr.student "+
                        "FROM genboreegroup gr, usergroup ug "+
                        "WHERE gr.groupId=ug.groupId AND ug.userId="+userId+" "+
                        "ORDER BY groupName";
            }
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery( qs );
            Vector v = new Vector();
            while( rs.next() )
            {
                GenboreeGroup gr = new GenboreeGroup();
                gr.setGroupId( rs.getString(1) );
                gr.setGroupName( rs.getString(2) );
                gr.setDescription( rs.getString(3) );
                gr.setStudent( rs.getInt(4) );
                v.addElement( gr );
            }
            stmt.close();
            GenboreeGroup[] rc = new GenboreeGroup[ v.size() ];
            v.copyInto( rc );
            return rc;
        } catch( Exception ex ) {
            db.reportError( ex, "GenboreeGroup.fetchAll()" );
        }
        return null;
    }

    // Lighter weight versions that reuse a provided Connection.
    public static GenboreeGroup[] fetchAll( Connection conn ) throws SQLException
    {
      return fetchAll( conn, null ) ;
    }
    public static GenboreeGroup[] fetchAll( Connection conn, String userId ) throws SQLException
    {
      if(conn == null)
      {
        return null ;
      }
      try
      {
        String qs = "SELECT groupId, groupName, description, student FROM genboreegroup ORDER BY groupName" ;
        if(userId != null)
        {
          qs =  userId.equals("0") ?
                "SELECT groupId, groupName, description, student FROM genboreegroup " +
                "WHERE groupName='Public'" :
                "SELECT gr.groupId, gr.groupName, gr.description, gr.student " +
                "FROM genboreegroup gr, usergroup ug " +
                "WHERE gr.groupId=ug.groupId AND ug.userId=" + userId + " " +
                "ORDER BY groupName" ;
        }
        Statement stmt = conn.createStatement() ;
        ResultSet rs = stmt.executeQuery( qs ) ;
        ArrayList vv = new ArrayList() ;
        while(rs.next())
        {
          GenboreeGroup gr = new GenboreeGroup() ;
          gr.setGroupId( rs.getString(1) ) ;
          gr.setGroupName( rs.getString(2) ) ;
          gr.setDescription( rs.getString(3) ) ;
          gr.setStudent( rs.getInt(4) ) ;
          vv.add(gr) ;
        }
        stmt.close() ;
        GenboreeGroup[] rc = new GenboreeGroup[ vv.size() ] ;
        vv.toArray(rc) ;
        return rc ;
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: GenboreeUser.fetchAll(Connection, String) => exception thrown. Details:\n" + ex.getMessage()) ;
        ex.printStackTrace(System.err) ;
      }
      return null ;
    }


    public boolean deleteAnnotationDataFilesDir()
    {
        boolean rc = false ;
        File annoDir = fetchAnnotationDataFilesDir() ;
        FileKiller.clearDirectory(annoDir) ;
        rc = annoDir.delete() ;
        return rc ;
    }

    public File fetchAnnotationDataFilesDir()
    {
        File rc = null ;
        // Get dir path from config file
        String dirPathName = GenboreeConfig.getConfigParam("gbAnnoDataFilesDir") ;
        String grpNameEsc = Util.urlEncode(groupName) ;
        String grpDirPathName = dirPathName + "grp/" + grpNameEsc ;
        rc = new File( grpDirPathName ) ;
        return rc;
    }


// generate a pass word of 8 digit, containing 6 low case letter and 2 digit
    public static  String passwdGen() {
        String s = "";
        char [] arr = new char [] {'a', 'b','c', 'd','e', 'f','g', 'h','i', 'j','k', 'l','m', 'n','o', 'p','q', 'r','s', 't','u', 'v','w', 'x','y', 'z'};
        int d = 0;
        for (int i=0; i<6; i++) {
            d = (int)(Math.random()*100)%26;
            s = s + arr[d];
        }

        for (int i=0; i<2; i++) {
            s = s + (int)(Math.random()*100)%10;
        }
        return s;
    }

    public static  String nameGen(String s ) {
        for (int i=0; i<2; i++) {
            s = s + (int)(Math.random()*100)%10;
        }
        return s;
    }


    public static String [] sendEmail(String email, String userName, String loginName, String password, String adder, String groupName, String serverName)
    {
        SendMail m = new SendMail() ;
        m.setHost( Util.smtpHost ) ;
        m.setFrom( adrFrom ) ;
        m.setReplyTo( adrFrom ) ;
        String newEmail = email ;
        m.addTo(newEmail) ;
        m.setSubj( "New Genboree registration for " + userName ) ;
        String message =
          "Dear " +  userName + ",\n\n" +
          "You have been added to the Genboree group \""  + groupName + "\"\nat http://" + serverName + " by " + adder +
          ".\n\nYour Genboree login name which was\nadded to the group is \"" + loginName +
          "\".\n\nIf you do not know your password, please use the\n\"Forgot your password?\" feature to obtain it.\n\n" +
          "Once logged into http://" + serverName + ", you can change\nyour password by clicking \"My Profile\" -> \"Change Password\".\n\nRegards,\nThe Genboree Team\n" ;
        m.setBody(message) ;
        m.go() ;
        return m.getErrors() ;
    }

  /**
    USE GenboreeUtil.validateEmailHost() INSTEAD
    - this one make INCORRECT assumptions about domain always having IPs.
    * validates if a host name is valid
    * @param hostName  String
    * @return isValidaHost boolean
  */
  public static boolean validateHostName(String hostName)
  {
    System.err.println("ARJ_DEBUG: GenboreeGroup.java#validateHostName(S) => SHOULD NOT BE HERE") ;
    boolean isValidHost = true;
    String[] parts = hostName.split("\\.") ;
    String newHost ;
    if(parts.length < 2)
    {
      System.err.println("GenboreeGroup#validateHostName_Safe(): bad argument '" + hostName + "'. Doesn't look like a real host name.") ;
      return false ;
    }
    else // Rebuild with last part of domain only. As long as it is good, should be fine.
    {
      newHost = parts[parts.length-2] + "." + parts[parts.length-1] ;
    }
    try
    {
      InetAddress.getByName(hostName);
    }
    catch(UnknownHostException e)
    {
      System.err.println(" GenboreeGroup.validateHostName: host name from exception:"  +  hostName );
      isValidHost = false;
    }
    return isValidHost;
  }

  public static boolean  adduser(HttpSession mys, GenboreeGroup grp, GenboreeUser usr, String fullName, String serverName, DBAgent db, String acs)
  {
    String [] errMsgs =  null;
    String email = usr.getEmail();
    String  hostName =  null;
    if(email != null && email.indexOf("@") >0 )
    {
      hostName = email.substring(email.indexOf("@") +1);
      if( !GenboreeUtils.validateEmailHost(hostName))
      {
        String message =  "The email address for this user is not correct.\n<br>";
        String message2 =   "-- The host domain '" + hostName + "' is invalid.";
        message2 = Util.htmlQuote(message2);
        message = message + message2;
        GenboreeMessage.setErrMsg(mys, message );
        return false;
      }
    }
    else
    {
      String message =  "The email address for this user is not correct.\n<br>";
      String message2 =   "-- The host domain '" + hostName + "' is invalid.";
      message2 = Util.htmlQuote(message2);
      message = message + message2;
      GenboreeMessage.setErrMsg(mys, message );
      return false;
    }
    String name = "";
    String userId = null;
    String password  = usr.getPassword();
    try
    {
      if(password == null || password.length()<1)
      {
        password = passwdGen();
        usr.setPassword(password);
        userId =  insert( db, usr);
      }
      name = "";
      if(usr.getFirstName() != null && usr.getLastName() != null)
      {
        name = usr.getFirstName()  + " " + usr.getLastName();
      }
      else
      {
        name = usr.getFullName();
      }
      sendEmail(usr.getEmail(), name, usr.getName(),  usr.getPassword(), fullName, grp.getGroupName(), serverName);
      if(usr.getUserId()== null)
      {
        usr.setUserId(userId);
      }
      else // (usr.getUserId()!= null)
      {
        grp.grantAccess( db, usr.getUserId(), acs );
      }
      grp.fetchUsers( db );
    }
    catch(SQLException e)
    {
      e.printStackTrace();
      e.printStackTrace(System.err) ;
      return false ;
    }

    errMsgs =  sendEmail (usr.getEmail(), name, usr.getName(),  usr.getPassword(), fullName, grp.getGroupName(), serverName);
    if(errMsgs != null)
    {
      ArrayList errlist = new ArrayList();
      String be = "address";
      for(int i=0; i<errMsgs.length; i++)
      {
        errlist.add(errMsgs[i]);
      }

      if(errlist.size() == 0 || errlist.size() >1)
      {
        be = be + "es";
      }
      GenboreeMessage.setErrMsg(mys, "Please check the following email address"  + be, errlist);
      if(errMsgs.length>0)
      {
        return false;
      }
    }
    return true;
  }

    public static  boolean grantAccess( DBAgent db, String userId, String acs , String  groupId, JspWriter out) throws SQLException
    {
        if( acs == null ) acs = "#";

        Connection conn = db.getConnection("genboree");

        try
        {

            if( userId==null || conn==null ) {

                return false; }


            Statement stmt = conn.createStatement();
            stmt.executeUpdate( "DELETE FROM usergroup "+
                    "WHERE userId="+userId+" AND groupId="+ groupId );
            String sql =    "INSERT INTO usergroup (userId, groupId, userGroupAccess) "+
                    "VALUES ("+userId+", "+ groupId +", '"+acs+"')" ;
            if( !acs.equals("#") )
            {
                stmt.executeUpdate( sql);

            }
            stmt.close();
            return true;
        } catch( Exception ex ) {
            db.reportError( ex, "GenboreeGroup.grantAccess()" );
        }
        return false;
    }


  /**
   *  a simple function checking the presence of user by full name and by email address
    @param db
   * @param fname
   * @param lname
   * @param email
   * @param out
   * @return GenboreeUser ; value could be null if no matching record is find
   * @throws SQLException
   */
     public static GenboreeUser findUserInfo(DBAgent db, String fname, String lname, String email, JspWriter out) throws SQLException {
        GenboreeUser user =null;
        Connection conn = db.getConnection();
        ResultSet rs = null;
        if (conn == null || conn.isClosed()) {
            throw new SQLException ("Connection to database failed.") ;
        }
        try {
           String qs0 = "SELECT userId, name, password, firstName, " +
                    "lastName, institution, email, phone " +
                    "FROM genboreeuser WHERE ";
            PreparedStatement pstmt = null;
           // step 1: check firstName and last Name
            if (fname != null && lname != null) {
                pstmt = conn.prepareStatement(qs0 + " firstName='" + fname + "' and lastName = '" + lname + "'");
               // pstmt.setString(1, fname);
                //pstmt.setString(1, lname);
                rs = pstmt.executeQuery();

                if (rs.next()) {
                    user=new GenboreeUser();
                    user.setUserId(rs.getString(1));
                    user.setName(rs.getString(2));
                    user.setPassword(rs.getString(3));
                    user.setFirstName(rs.getString(4));
                    user.setLastName(rs.getString(5));
                    user.setInstitution(rs.getString(6));
                    user.setEmail(rs.getString(7));
                    user.setPhone(rs.getString(8));
                }
            }

            if (user != null) {
                rs.close();
                pstmt.close();
                return user;
            }
            // check email
            if (email != null && email.length()>0) {
                 pstmt = conn.prepareStatement(qs0 + "email=?");
                pstmt.setString(1, email);
                rs = pstmt.executeQuery();
                if (rs.next()) {
                    user=new GenboreeUser();
                    user.setUserId(rs.getString(1));
                    user.setName(rs.getString(2));
                    user.setPassword(rs.getString(3));
                    user.setFirstName(rs.getString(4));
                    user.setLastName(rs.getString(5));
                    user.setInstitution(rs.getString(6));
                    user.setEmail(rs.getString(7));
                    user.setPhone(rs.getString(8));
                }
            }

            if (rs!= null)
                rs.close();
            if (pstmt != null) pstmt.close();

        } catch (Exception ex) {
            db.reportError(ex, "GenboreeUser.fetchByNameOrEmail()");
        }
        return user;
    }



    public static GenboreeUser [] findUserInfoByName(DBAgent db, String fname, String lname,  JspWriter out) throws SQLException {
        GenboreeUser user = null;
        GenboreeUser [] users = null;
        Connection conn = db.getConnection();
       ArrayList list = new ArrayList();
        ResultSet rs = null;

        if (conn == null || conn.isClosed()) {
            throw new SQLException("Connection to database failed.");
        }
        try {
            String qs0 = "SELECT userId, name, password, firstName, " +
                    "lastName, institution, email, phone " +
                    "FROM genboreeuser WHERE ";
            PreparedStatement pstmt = null;
            if (fname != null && lname != null) {
                pstmt = conn.prepareStatement(qs0 + " firstName='" + fname + "' and lastName = '" + lname + "'");

                // pstmt.setString(1, fname);
                //pstmt.setString(1, lname);
                rs = pstmt.executeQuery();
            }

            while (rs.next()) {
                user = new GenboreeUser();
                user.setUserId(rs.getString(1));
                user.setName(rs.getString(2));
                user.setPassword(rs.getString(3));
                user.setFirstName(rs.getString(4));
                user.setLastName(rs.getString(5));
                user.setInstitution(rs.getString(6));
                user.setEmail(rs.getString(7));
                user.setPhone(rs.getString(8));
                list.add(user);

            }

            if (rs != null)
                rs.close();

            if (pstmt != null) pstmt.close();

        } catch (Exception ex) {
            db.reportError(ex, "GenboreeUser.fetchByNameOrEmail()");
        }

        if (list.size() >0)
        users = (GenboreeUser [])list.toArray(new GenboreeUser [list.size()]);


        return users;
    }


    public static GenboreeUser[] findUserInfoByLoginName(DBAgent db, String loginName,JspWriter out) throws SQLException {
        GenboreeUser user = null;
        GenboreeUser[] users = null;
        Connection conn = db.getConnection();
        ArrayList list = new ArrayList();
        ResultSet rs = null;

        if (conn == null || conn.isClosed()) {
            throw new SQLException("Connection to database failed.");
        }
        try {


            String qs0 = "SELECT userId, name, password, firstName, " +
                    "lastName, institution, email, phone " +
                    "FROM genboreeuser WHERE ";
            PreparedStatement pstmt = null;
            if (loginName != null) {
                pstmt = conn.prepareStatement(qs0 + " name='" + loginName + "'");


                // pstmt.setString(1, fname);
                //pstmt.setString(1, lname);
                rs = pstmt.executeQuery();
            }

            while (rs.next()) {
                user = new GenboreeUser();
                user.setUserId(rs.getString(1));
                user.setName(rs.getString(2));
                user.setPassword(rs.getString(3));
                user.setFirstName(rs.getString(4));
                user.setLastName(rs.getString(5));
                user.setInstitution(rs.getString(6));
                user.setEmail(rs.getString(7));
                user.setPhone(rs.getString(8));
                list.add(user);

            }

            if (rs != null)
                rs.close();

            if (pstmt != null) pstmt.close();

        } catch (Exception ex) {
            db.reportError(ex, "GenboreeUser.fetchByNameOrEmail()");
        }

        if (list.size() > 0)
            users = (GenboreeUser[]) list.toArray(new GenboreeUser[list.size()]);


        return users;
    }




    public static GenboreeUser[] findUserInfoByEmail(DBAgent db, String email, JspWriter out) throws SQLException {
        GenboreeUser[] users = null;
        Connection conn = db.getConnection();
          ArrayList list = new ArrayList();
        ResultSet rs = null;
        if (conn == null || conn.isClosed()) {
            throw new SQLException("Connection to database failed.");
        }
        try {
           String qs0 = "SELECT userId, name, password, firstName, " +
                    "lastName, institution, email, phone " +
                    "FROM genboreeuser WHERE ";
            PreparedStatement pstmt = null;
              pstmt = conn.prepareStatement(qs0 + "email=?");
                pstmt.setString(1, email);
                rs = pstmt.executeQuery();
                while (rs.next()) {
                    GenboreeUser auser  = new GenboreeUser();
                    auser.setUserId(rs.getString(1));
                    auser.setName(rs.getString(2));
                    auser.setPassword(rs.getString(3));
                    auser.setFirstName(rs.getString(4));
                    auser.setLastName(rs.getString(5));
                    auser.setInstitution(rs.getString(6));
                    auser.setEmail(rs.getString(7));
                    auser.setPhone(rs.getString(8));
                    list.add(auser);
                }

            if (list.size() >0)
               users =(GenboreeUser[]) list.toArray(new GenboreeUser[list.size()])  ;
            if (rs != null)
                rs.close();
            if (pstmt != null) pstmt.close();

        } catch (Exception ex) {
            db.reportError(ex, "GenboreeUser.fetchByNameOrEmail()");
        }
        return users;
    }



    // Inserts a NEW user into a group
    public static  String insert( DBAgent db, GenboreeUser usr) throws SQLException
    {
      Connection conn = db.getConnection("genboree") ;
      int nrows = 0 ;
      try
      {
        if(conn == null || conn.isClosed())
        {
          return null ;
        }
        else
        {
          PreparedStatement stms = null ;
          ResultSet rs1 = null ;
          String loginName = null ;
          String sql = " select userId from genboreeuser where name = ? " ;
          String emailName = null ;
          String firstName = usr.getFirstName() ;
          if(firstName != null)
          {
            firstName = firstName.trim() ;
            firstName = firstName.replaceAll(" ", "_") ;
          }
          String lastName = usr.getLastName();
          if(lastName != null)
          {
            lastName = lastName.trim();
            lastName = lastName.replaceAll(" ", "_");
          }
          // All set to try to find user login we can use
          boolean  b = false;
          // - try login based on email address first
          if(usr.getEmail() != null)
          {
            emailName = usr.getEmail() ;
            // extract account name from email
            emailName = emailName.substring(0, emailName.indexOf("@")) ;
            if(emailName != null)
            {
              // Check user table for a record using emailName as the Genboree login
              stms = conn.prepareStatement(sql) ;
              stms.setString(1, emailName) ;
              rs1 = stms.executeQuery() ;
              if(!rs1.next())
              {
                // login based on email name is free! use that
                loginName = emailName ;
                b = true ;
              }
            }
          }

          // - emailname taken as login...
          if (!b && loginName == null  && firstName != null  && lastName != null )
          {
            firstName = firstName.trim() ;
            lastName = lastName.trim() ;
            // 2nd, let's try a name based on concantenation of first and last name?
            stms.setString(1, firstName + "_" + lastName) ;
            rs1 = stms.executeQuery() ;
            if(!rs1.next())
            {
              // login based on first_last is free! use that
              loginName = firstName + "_" + lastName ;
              b = true;
            }
          }

          // - still first_last aslo taken as login
          if(!b && loginName == null && usr.getEmail() != null )
          {
            // - try emailName_X where X from 1 to 100
            //emailName = usr.getEmail() ;
            //emailName = emailName.substring(0, emailName.indexOf("@")) ;
            loginName = emailName ;

            String tempName = loginName ;
            for(int k =1; k<100; k++)
            {
              tempName = loginName + "_" + k ;
              stms.setString(1, tempName) ;
              rs1 = stms.executeQuery() ;
              if(!rs1.next())
              {
                // login based on email_#{ii} name is free! use that
                loginName = tempName ;
                b = true ;
                break ;
              }
            }
          }

          if(!b && loginName == null)
          {
            loginName = passwdGen() ;
          }

          PreparedStatement pstmt = conn.prepareStatement(
            "INSERT INTO genboreeuser (name, password, firstName, " +
            "lastName, institution, email, phone) VALUES (?,?,?,?,?,?,?)" ) ;
          usr.setName(loginName);

          pstmt.setString( 1, loginName) ;
          pstmt.setString( 2, usr.getPassword()) ;
          pstmt.setString( 3, usr.getFirstName()) ;
          pstmt.setString( 4, usr.getLastName()) ;
          pstmt.setString( 5, usr.getInstitution()) ;
          pstmt.setString( 6, usr.getEmail()) ;
          pstmt.setString( 7, usr.getPhone()) ;
          nrows = pstmt.executeUpdate() ;

          if( nrows > 0 )
          {
            pstmt.close() ;
            pstmt = conn.prepareStatement(
                    "SELECT userId FROM genboreeuser WHERE name=?" ) ;
            pstmt.setString(1, usr.getName()) ;
            ResultSet rs = pstmt.executeQuery() ;
            if(rs.next())
            {
              usr.setUserId( rs.getString(1) ) ;
            }
            else nrows = 0 ;
            rs.close() ;
          }

          rs1.close() ;
          stms.close() ;
          pstmt.close() ;
        }
      }
      catch(SQLException ex )
      {
        db.reportError( ex, "GenboreeUser.insert()" ) ;
        ex.printStackTrace() ;
      }
      return usr.getUserId() ;
    }

    public static GenboreeGroup[] recreateteGroupList( DBAgent mydb,  String currentUserId)
    {
      GenboreeGroup[] grps = null ;
      try
      {
        // Get connection to main Genboree database for use in fetching group/user info
        Connection conn = mydb.getConnection() ;
        if(currentUserId != null)
        {
          grps = fetchAll(conn, currentUserId) ;
        }
        if(grps == null)
        {
          grps = new GenboreeGroup[0] ;
        }
        for(int ii=0; ii<grps.length; ii++)
        {
          //grps[ii].fetchUsers( conn ) ;
          grps[ii].fetchRefseqs( conn ) ;
        }
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: GenboreeGroup#recreateteGroupList(DBA,S) => Exception in the recreateGroupList fetching refseqs. Details:\n" + ex.getMessage()) ;
        ex.printStackTrace(System.err) ;
        grps = null ;
      }
      return grps ;
    }
}
