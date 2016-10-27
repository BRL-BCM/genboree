package org.genboree.dbaccess.util ;

import java.sql.* ;
import java.util.* ;
import org.genboree.dbaccess.* ;

public class User2AccountTable
{
  public static int countUsers(int accountId, Connection conn)
  {
    int count = 0 ;
    PreparedStatement stmt = null ;
    ResultSet rs = null ;
    if(conn != null)
    {
      try
      {
        String sql = "select count(*) from user2account where account_id = ? " ;
        stmt = conn.prepareStatement(sql) ;
        stmt.setInt(1, accountId) ;
        rs = stmt.executeQuery() ;
        while(rs.next())
        {
          count = rs.getInt(1) ;
        }
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: User2AccountTable#count(i,C) => exception counting number of users in account") ;
        ex.printStackTrace(System.err) ;
      }
      finally
      {
        DBAgent.safelyCleanup(rs, stmt) ;
      }
    }
    return count ;
  }

  public static int associateUserWithAccount(int userId, int accountId, Connection conn)
  {
    PreparedStatement stmt = null ;
    int rowCount = 0 ;
    if(conn != null)
    {
      try
      {
        String sql =  "insert into user2account (genboreeUser_id, account_id) values (?, ?) " +
                      "on duplicate key update genboreeUser_id=VALUES(genboreeUser_id), account_id=VALUES(account_id)" ;
        stmt = conn.prepareStatement(sql) ;
        stmt.setInt(1, userId) ;
        stmt.setInt(2, accountId) ;
        rowCount = stmt.executeUpdate() ;
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: User2AccountTable#associateUserWithAccount(i, i, C) => exception associating user with account") ;
        ex.printStackTrace(System.err) ;
      }
      finally
      {
        DBAgent.safelyCleanup(null, stmt) ;
      }
    }
    return rowCount ;
  }
}
