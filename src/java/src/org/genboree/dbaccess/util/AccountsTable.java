package org.genboree.dbaccess.util ;

import java.sql.* ;
import java.util.* ;
import org.genboree.dbaccess.* ;

public class AccountsTable
{
  public static DbResourceSet getRecordByCode(String code, Connection conn)
  {
    PreparedStatement stmt = null ;
    ResultSet rs = null ;
    DbResourceSet dbSet = null ;
    if(conn != null)
    {
      try
      {
        String sql = "select * from accounts where code = ?" ;
        stmt = conn.prepareStatement(sql) ;
        stmt.setString(1, code) ;
        rs = stmt.executeQuery() ;
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: AccountsTable#getRecordsByCode(S,C) => exception getting accounts by registration code.") ;
        ex.printStackTrace(System.err) ;
      }
    }
    dbSet = new DbResourceSet(rs, stmt, conn, null) ;
    return dbSet ;
  }

  public static String getAccountAttributeValue(int accntId, String attributeName, Connection conn)
  {
    String retVal = null ;
    PreparedStatement stmt = null ;
    ResultSet rs = null ;
    if(conn != null)
    {
      try
      {
        String sql =  "select accountValues.value from accounts, accountValues, accountAttributes, accounts2attributeValues " +
                      "where accounts.id = ? and accounts2attributeValues.account_id = accounts.id and accountAttributes.name = ? and " +
                      "accounts2attributeValues.accountAttribute_id = accountAttributes.id and " +
                      "accountValues.id = accounts2attributeValues.accountValue_id" ;
        stmt = conn.prepareStatement(sql) ;
        stmt.setInt(1, accntId) ;
        stmt.setString(2, attributeName) ;
        rs = stmt.executeQuery() ;
        while(rs.next())
        {
          retVal = rs.getString(1) ;
        }
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: AccountsTable#getAccountAttributeValue(i,S,C) => exception getting accounts by account id and attribute name.") ;
        ex.printStackTrace(System.err) ;
      }
      finally
      {
        DBAgent.safelyCleanup(rs, stmt) ;
      }
    }
    return retVal ;
  }

  public static boolean isMaxNumUsersExceeded(int accountId, Connection conn)
  {
    // 1 check if num users for account not exceeded
    boolean retVal = false ;
    // 1a. Get maximum number of users for this account.
    int numUsers = -1 ;
    String numUsersStr = AccountsTable.getAccountAttributeValue(accountId, "maxNumUsers", conn) ;
    try
    {
      numUsers = Integer.parseInt(numUsersStr) ;
    }
    catch(Exception ex)
    {
      System.err.println("ERROR: AccountsTable.isMaxNumUsersExceeded(i,C) => exception converting maxNumUsers value to an integer.") ;
      ex.printStackTrace(System.err) ;
    }
    // 1b. Get current number of users for this account.
    int currNumUsersInAccount = User2AccountTable.countUsers(accountId, conn) ;
    retVal = (currNumUsersInAccount >= numUsers) ;
    return retVal ;
  }

  public static boolean isMaxNumDatabasesExceeded(int accountId, Connection conn)
  {
    // 1 check if num users for account not exceeded
    boolean retVal = false ;
    // 1a. Get maximum number of users for this account.
    int numDatabases = -1 ;
    String numDatabasesStr = AccountsTable.getAccountAttributeValue(accountId, "maxNumDatabases", conn) ;
    try
    {
      numDatabases = Integer.parseInt(numDatabasesStr) ;
    }
    catch(Exception ex)
    {
      System.err.println("ERROR: AccountsTable.isMaxNumDatabasesExceeded(i,C) => exception converting maxNumDatabases value to an integer.") ;
      ex.printStackTrace(System.err) ;
    }
    // 1b. Get current number of users for this account.
    int currNumDatabasesInAccount = Refseq2AccountTable.countDatabases(accountId, conn) ;
    retVal = (currNumDatabasesInAccount >= numDatabases) ;
    return retVal ;
  }
}
