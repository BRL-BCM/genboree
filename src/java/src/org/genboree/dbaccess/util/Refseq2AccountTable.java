package org.genboree.dbaccess.util ;

import java.sql.* ;
import java.util.* ;
import org.genboree.dbaccess.* ;

public class Refseq2AccountTable
{
  public static int countDatabases(int accountId, Connection conn)
  {
    int count = 0 ;
    PreparedStatement stmt = null ;
    ResultSet rs = null ;
    if(conn != null)
    {
      try
      {
        String sql = "select count(*) from refseq2account where account_id = ? " ;
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
        System.err.println("ERROR: Refseq2AccountTable#count(i,C) => exception counting number of users in account") ;
        ex.printStackTrace(System.err) ;
      }
      finally
      {
        DBAgent.safelyCleanup(rs, stmt) ;
      }
    }
    return count ;
  }

  public static int associateDatabaseWithAccount(int refseqId, int accountId, Connection conn)
  {
    PreparedStatement stmt = null ;
    int rowCount = 0 ;
    if(conn != null)
    {
      try
      {
        String sql =  "insert into refseq2account (refseq_id, account_id) values (?, ?) " +
                      "on duplicate key update refseq_id=VALUES(refseq_id), account_id=VALUES(account_id)" ;
        stmt = conn.prepareStatement(sql) ;
        stmt.setInt(1, refseqId) ;
        stmt.setInt(2, accountId) ;
        rowCount = stmt.executeUpdate() ;
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: Refseq2AccountTable#associateUserWithAccount(i, i, C) => exception associating database with account") ;
        ex.printStackTrace(System.err) ;
      }
      finally
      {
        DBAgent.safelyCleanup(null, stmt) ;
      }
    }
    return rowCount ;
  }

  public static int unassociateDatabaseWithAccount(int refseqId, Connection conn)
  {
    PreparedStatement stmt = null ;
    int rowCount = 0 ;
    if(conn != null)
    {
      try
      {
        String sql =  "delete from refseq2account where refseq_id = ? " ;
        stmt = conn.prepareStatement(sql) ;
        stmt.setInt(1, refseqId) ;
        rowCount = stmt.executeUpdate() ;
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: Refseq2AccountTable#unassociateUserWithAccount(i, C) => exception unassociating database from account") ;
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
