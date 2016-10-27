package org.genboree.dbaccess.util ;

import java.sql.* ;
import java.util.* ;
import org.genboree.dbaccess.* ;

public class UsergroupTable
{
  public static boolean isUserInGroup(int userId, int groupId, DBAgent db)
  {
    return UsergroupTable.isUserInGroup(userId, groupId, db) ;
  }
  public static boolean isUserInGroup(String userId, String groupId, DBAgent db)
  {
    boolean retVal = false ;
    try
    {
      Connection conn = db.getConnection() ;
      retVal = UsergroupTable.isUserInGroup(userId, groupId, conn) ;
    }
    catch( Exception ex )
    {
      ex.printStackTrace(System.err);
      System.err.println("ERROR: UsergroupTable#isUserInGroup(S,S, D): exception checking if user is in group") ;
      retVal = false ;
    }
    finally
    {
      return retVal ;
    }
  }
  public static boolean isUserInGroup(int userId, int groupId, Connection conn)
  {
    return UsergroupTable.isUserInGroup("" + userId, "" + groupId, conn) ;
  }
  public static boolean isUserInGroup(String userId, String groupId, Connection conn)
  {
    PreparedStatement stmt = null ;
    boolean retVal = false ;
    ResultSet rs = null ;
    if(conn != null)
    {
      try
      {
        String sql =  "select userId from usergroup where groupId = ? and userId = ?" ;
        stmt = conn.prepareStatement(sql) ;
        stmt.setString(1, groupId) ;
        stmt.setString(2, userId) ;
        rs = stmt.executeQuery() ;
        while(rs.next())
        {
          retVal = true ;
          break ;
        }
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: UsergroupTable#isUserInGroup(S, S, C) => exception checking if user is in group") ;
        ex.printStackTrace(System.err) ;
        retVal = false ;
      }
      finally
      {
        DBAgent.safelyCleanup(rs, stmt) ;
      }
    }
    return retVal ;
  }
}
