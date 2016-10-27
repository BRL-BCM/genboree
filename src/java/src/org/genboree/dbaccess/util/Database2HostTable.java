package org.genboree.dbaccess.util ;

import java.sql.* ;
import java.util.* ;
import org.genboree.dbaccess.* ;

// Class for -selected- useful actions on the database2host table
public class Database2HostTable
{
  // Count all the databases mapped to hosts
  public static long count(Connection conn)
  {
    long count = 0 ;
    PreparedStatement stmt = null ;
    ResultSet rs = null ;
    if(conn != null)
    {
      try
      {
        String sql = "select count(*) from database2host " ;
        stmt = conn.prepareStatement(sql) ;
        rs = stmt.executeQuery() ;
        if(rs.next())
        {
          count = rs.getLong(1) ;
        }
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: Database2HostTable#count() => exception counting database2host records.") ;
        System.err.println(ex.getMessage()) ;
        ex.printStackTrace(System.err) ;
      }
      finally
      {
        DBAgent.safelyCleanup(rs, stmt) ;
      }
    }
    return count ;
  }

  // Get the hostname for a given Genboree user database. Connection to main genboree database required.
  public static String getHostForDbName(String dbName, Connection conn)
  {
    String hostName = null ;
    PreparedStatement stmt = null ;
    ResultSet rs = null ;
    if(conn != null)
    {
      try
      {
        String sql = "select databaseHost from database2host where databaseName = ? " ;
        stmt = conn.prepareStatement(sql) ;
        stmt.setString(1, dbName) ;
        rs = stmt.executeQuery() ;
        if(rs.next())
        {
          hostName = rs.getString(1) ;
        }
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: Database2HostTable#getHostForDbName() => exception getting host name.") ;
        System.err.println(ex.getMessage()) ;
        ex.printStackTrace(System.err) ;
      }
      finally
      {
        DBAgent.safelyCleanup(rs, stmt) ;
      }
    }
    return hostName ;
  }

  public static boolean deleteHostMappingForDatabase(String dbName, Connection conn)
  {
    boolean retVal = false ;
    PreparedStatement stmt = null ;
    ResultSet rs = null ;
    if(dbName != null && (dbName.length() > 0))
    {
      try
      {
        String sql = "delete from database2host where databaseName = ? " ;
        stmt = conn.prepareStatement(sql) ;
        stmt.setString(1, dbName) ;
        int rowsDeleted = stmt.executeUpdate() ;
        if(rowsDeleted == 1)
        {
          retVal = true ;
        }
        else
        {
          System.err.println("ERROR: Database2HostTable.deleteHostMappingForDatabase(S,C) => deleting the database2host mapping for dbName '" +
                             dbName + "' didn't delete exactly 1 row (deleted " + rowsDeleted + " rows). This is not right, why?") ;
          retVal = false ;
        }
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: Database2HostTable.deleteHostMappingForDatabase(S,C) => exception deleting the database2host mapping for dbName '" +
                           dbName + "'. Details: " + ex.getMessage()) ;
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

  // Insert new record into database2host table (generally when creating a new user database).
  // NOTE: At this time, we don't allow even *trying* to insert a new record for a database that
  // is ALREADY in the table. We check explicitly for this case, since it would be an error.
  // Connection to main genboree database required.
  public static boolean insertNewDbname2HostPair(String dbName, String dbHost, Connection conn)
  {
    boolean retVal = false ;
    // Are params sensible?
    if(dbName != null && (dbName.length() != 0) && dbHost != null && (dbHost.length() != 0)) // Yes.
    {
      // Check if dbName is already in the table. This is illegal.
      String currHost = Database2HostTable.getHostForDbName(dbName, conn) ;
      if(currHost != null) // Oh oh, Already in the table!
      {
        // Already in the table. This is a logic bug; cannot use this to change database hosts or such things.
        // Only for new databases that don't have a host assigned yet.
        System.err.println("ERROR: Database2HostTable.insertNewDbname2HostPair(S,S) => genboree.database2host already has a host for the db '" + dbName + "' which is currently mapped to => '" + currHost +
                           "'. That is not allowed, this can only be used for NEW databases not yet assigned to hoss. Logic bug in code.") ;
        retVal = false ;
      }
      else // Not in there, do insertion.
      {
        try
        {
          String sql = "insert into database2host values (null, ?, ?)" ;
          PreparedStatement stmt = conn.prepareStatement(sql) ;
          stmt.setString(1, dbName) ;
          stmt.setString(2, dbHost) ;
          int numRowsInserted = stmt.executeUpdate() ;
          // Insertion ok?
          if(numRowsInserted == 1)
          {
            retVal = true ;
          }
          else
          {
            System.err.println("ERROR: Database2HostTable.insertNewDbname2HostPair(S,S) => insertion of dbName, dbHost pair didn't insert 1 row as expected." +
                               ". dbName => '" + dbName + "' ; dbHost => '" + dbHost + "'.") ;
            retVal = false ;
          }
        }
        catch(Exception ex)
        {
          System.err.println("ERROR: Database2HostTable.insertNewDbname2HostPair(S,S) => SQL insert of dbName, dbHost pair threw exception and failed. Details: " + ex.getMessage()) ;
          ex.printStackTrace(System.err) ;
          retVal = false ;
        }
      }
    }
    else // No.
    {
      System.err.println("ERROR: Database2HostTable.insertNewDbname2HostPair(S,S) called with bad arguments...neither dbName nor dbHost can be null" +
                         "dbName => " + dbName + " ; dbHost => " + dbHost) ;
      retVal = false ;
    }
    return retVal ;
  }
}
