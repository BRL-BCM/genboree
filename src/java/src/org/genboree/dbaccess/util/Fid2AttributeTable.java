package org.genboree.dbaccess.util ;

import java.sql.*;
import java.util.* ;
import org.genboree.dbaccess.* ;

public class Fid2AttributeTable
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
        String sql = "select count(*) from fid2attribute " ;
        stmt = conn.prepareStatement(sql) ;
        rs =stmt.executeQuery() ;
        while(rs.next())
        {
          count = rs.getLong(1) ;
        }
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: Fid2AttributeTable#count() => exception counting fid2attribute records.") ;
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
