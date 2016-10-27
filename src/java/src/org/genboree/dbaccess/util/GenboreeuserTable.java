package org.genboree.dbaccess.util ;

import java.sql.* ;
import java.util.* ;
import org.genboree.dbaccess.* ;

public class GenboreeuserTable
{
  public static boolean loginExists(String login, Connection conn)
  {
    boolean retVal = false ;
    PreparedStatement stmt = null ;
    ResultSet rs = null ;

    if(conn != null && login != null && login.length() >= 1)
    {
      try
      {
        String sql = "select count(*) from genboreeuser where name = ?" ;
        stmt = conn.prepareStatement(sql) ;
        stmt.setString(1, login) ;
        rs = stmt.executeQuery() ;
        while(rs.next())
        {
          int count = rs.getInt(1) ;
          retVal = (count > 0) ;
          break ;
        }
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: GenboreeuserTable#loginExists() => exception determining if login exists or not.") ;
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
