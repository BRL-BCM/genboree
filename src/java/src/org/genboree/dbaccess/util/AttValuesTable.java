package org.genboree.dbaccess.util ;

import java.sql.* ;
import java.util.* ;
import org.genboree.dbaccess.* ;

public class AttValuesTable
{
  public static long count(Connection conn)
  {
    long count = 0 ;
    PreparedStatement stmt = null ;
    ResultSet rs = null ;
    if(conn != null)
    {
      try
      {
        String sql = "select count(*) from attValues " ;
        stmt = conn.prepareStatement(sql) ;
        rs = stmt.executeQuery() ;
        while(rs.next())
        {
          count = rs.getLong(1) ;
        }
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: DbFdata#count() => exception counting attValues records.") ;
        ex.printStackTrace(System.err) ;
      }
      finally
      {
        DBAgent.safelyCleanup(rs, stmt) ;
      }
    }
    return count ;
  }
}
