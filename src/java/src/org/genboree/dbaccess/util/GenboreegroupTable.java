package org.genboree.dbaccess.util ;

import java.sql.* ;
import java.util.* ;
import org.genboree.dbaccess.* ;

public class GenboreegroupTable
{
  public static String getGroupNameById(int groupId, Connection conn)
  {
    return getGroupNameById("" + groupId, conn) ;
  }
  public static String getGroupNameById(String groupId, Connection conn)
  {
    String retVal = null ;
    PreparedStatement stmt = null ;
    ResultSet rs = null ;
    if(conn != null)
    {
      try
      {
        String sql = "select groupName from genboreegroup where groupId = ?" ;
        stmt = conn.prepareStatement(sql) ;
        stmt.setString(1, groupId) ;
        rs = stmt.executeQuery() ;
        while(rs.next())
        {
          retVal = rs.getString(1) ;
        }
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: GenboreegroupTable#getGroupNameById() => exception getting group name by group id.") ;
        ex.printStackTrace(System.err) ;
      }
      finally
      {
        DBAgent.safelyCleanup(rs, stmt) ;
      }
    }
    return retVal ;
  }

  // Get user refSeqid for this refSeqName from main Genboree database
  public static int getGroupIdByName(String groupName, DBAgent db)
  {
    int retVal = -1 ;
    try
    {
      Connection conn = db.getConnection() ;
      retVal = GenboreegroupTable.getGroupIdByName(groupName, conn) ;
    }
    catch( Exception ex )
    {
      ex.printStackTrace(System.err);
      System.err.println("ERROR: GenboreegroupTable#getGroupIdByName(S,D): Exception trying to find refSeqName From refSeqId using refSeqId " + groupName) ;
      retVal = -1 ;
    }
    finally
    {
      return retVal ;
    }
  }
  public static int getGroupIdByName(String groupName, Connection conn)
  {
    int retVal = -1 ;
    PreparedStatement stmt = null ;
    ResultSet rs = null ;
    if(conn != null)
    {
      try
      {
        String sql = "select groupId from genboreegroup where groupName = ?" ;
        stmt = conn.prepareStatement(sql) ;
        stmt.setString(1, groupName) ;
        rs = stmt.executeQuery() ;
        while(rs.next())
        {
          retVal = rs.getInt(1) ;
        }
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: GenboreegroupTable#getGroupIdByName(S,C) => exception getting group id by group name.") ;
        ex.printStackTrace(System.err) ;
        retVal = -1 ;
      }
      finally
      {
        DBAgent.safelyCleanup(rs, stmt) ;
      }
    }
    return retVal ;
  }
}
