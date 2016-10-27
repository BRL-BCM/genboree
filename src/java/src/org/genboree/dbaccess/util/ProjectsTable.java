package org.genboree.dbaccess.util ;

import java.sql.* ;
import java.util.* ;
import org.genboree.dbaccess.* ;

public class ProjectsTable
{
  public static int getProjectIdByName(String projName, Connection conn)
  {
    int retVal = -1 ;
    PreparedStatement stmt = null ;
    ResultSet rs = null ;
    if(conn != null)
    {
      try
      {
        String sql = "select id from projects where name = ?" ;
        stmt = conn.prepareStatement(sql) ;
        stmt.setString(1, projName) ;
        rs = stmt.executeQuery() ;
        while(rs.next())
        {
          retVal = rs.getInt(1) ;
        }
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: ProjectsTable#getProjectIdByName() => exception getting project id by project name.") ;
        ex.printStackTrace(System.err) ;
      }
      finally
      {
        DBAgent.safelyCleanup(rs, stmt) ;
      }
    }
    return retVal ;
  }

  public static DbResourceSet getProjectById(int projId, Connection conn)
  {
    DbResourceSet retVal = null ;
    PreparedStatement stmt = null ;
    ResultSet rs = null ;
    if(conn != null)
    {
      try
      {
        String sql = "select * from projects where id = ?" ;
        stmt = conn.prepareStatement(sql) ;
        stmt.setInt(1, projId) ;
        rs = stmt.executeQuery() ;
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: ProjectsTable#getProjectById() => exception getting project by project id.") ;
        ex.printStackTrace(System.err) ;
      }
    }
    retVal = new DbResourceSet(rs, stmt, conn, null) ;
    return retVal ;
  }

  public static DbResourceSet getProjectsByGroupId(int groupId, Connection conn)
  {
    DbResourceSet retVal = null ;
    PreparedStatement stmt = null ;
    ResultSet rs = null ;
    if(conn != null)
    {
      try
      {
        String sql = "select * from projects where groupId = ?" ;
        stmt = conn.prepareStatement(sql) ;
        stmt.setInt(1, groupId) ;
        rs = stmt.executeQuery() ;
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: ProjectsTable#getProjectsByGroupId() => exception getting projects by group id.") ;
        ex.printStackTrace(System.err) ;
      }
    }
    retVal = new DbResourceSet(rs, stmt, conn, null) ;
    return retVal ;
  }

  public static String getGroupIdByProjectId(int projId, Connection conn)
  {
    String retVal = null ;
    PreparedStatement stmt = null ;
    ResultSet rs = null ;
    if(conn != null)
    {
      try
      {
        String sql = "select groupId from projects where id = ?" ;
        stmt = conn.prepareStatement(sql) ;
        stmt.setInt(1, projId) ;
        rs =stmt.executeQuery() ;
        while(rs.next())
        {
          retVal = rs.getString(1) ;
        }
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: ProjectsTable#getGroupIdByProjectId() => exception getting project id by project name.") ;
        ex.printStackTrace(System.err) ;
      }
      finally
      {
        DBAgent.safelyCleanup(rs, stmt) ;
      }
    }
    return retVal ;
  }
}
