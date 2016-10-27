package org.genboree.dbaccess.util;

import java.sql.* ;
import java.util.* ;
import org.genboree.dbaccess.*;

// Class to query the refseq table
public class RefSeqTable
{
  // Get databaseName for this refSeqId from main Genboree database
  public static String getDatabaseNameByRefSeqId(int refSeqId, Connection conn)
  {
    return RefSeqTable.getDatabaseNameByRefSeqId("" + refSeqId, conn) ;
  }
  public static String getDatabaseNameByRefSeqId(String refSeqId, Connection conn)
  {
    String dbName = null ;
    String sql =  "SELECT databaseName from refseq where refSeqId = ? " ;
    PreparedStatement pstmt = null ;
    ResultSet resultSet = null ;
    if(refSeqId != null)
    {
      try
      {
        pstmt = conn.prepareStatement(sql) ;
        pstmt.setString(1, refSeqId) ;
        resultSet = pstmt.executeQuery() ;
        if(resultSet != null)
        {
          if(resultSet.next())
          {
            dbName = resultSet.getString("databaseName") ;
          }
        }
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: RefSeqTable#getDatabaseNameByRefSeqId(S,C) => Exception getting database name for refSeqId (" + refSeqId + ") ; sql was: " + sql) ;
        ex.printStackTrace(System.err) ;
      }
      finally
      {
        DBAgent.safelyCleanup(resultSet, pstmt) ;
      }
    }
    return dbName ;
  }

  // Get user refSeqid for this refSeqName from main Genboree database
  public static int getRefSeqIdByRefSeqName(int groupId, String refSeqName, DBAgent db)
  {
    return RefSeqTable.getRefSeqIdByRefSeqName("" + groupId, refSeqName, db) ;
  }
  public static int getRefSeqIdByRefSeqName(String groupId, String refSeqName, DBAgent db)
  {
    int retVal = -1 ;
    try
    {
      Connection conn = db.getConnection() ;
      retVal = RefSeqTable.getRefSeqIdByRefSeqName(groupId, refSeqName, conn) ;
    }
    catch( Exception ex )
    {
      ex.printStackTrace(System.err) ;
      System.err.println("ERROR: RefSeqTable#getRefSeqIdByRefSeqName(S,D) => Exception trying to find refSeqId using refSeqName " + refSeqName) ;
      retVal = -1 ;
    }
    finally
    {
      return retVal ;
    }
  }
  public static int getRefSeqIdByRefSeqName(int groupId, String refSeqName, Connection conn)
  {
    return RefSeqTable.getRefSeqIdByRefSeqName("" + groupId, refSeqName, conn) ;
  }
  public static int getRefSeqIdByRefSeqName(String groupId, String refSeqName, Connection conn)
  {
    int retVal = -1 ;
    String sql =  "SELECT refseq.refSeqId FROM refseq, grouprefseq WHERE refseqName = ? AND grouprefseq.groupId = ? AND refseq.refSeqId = grouprefseq.refSeqId" ;
    PreparedStatement pstmt = null ;
    ResultSet resultSet = null ;
    if(refSeqName != null && refSeqName.length() > 0)
    {
      try
      {
        pstmt = conn.prepareStatement(sql) ;
        pstmt.setString(1, refSeqName) ;
        pstmt.setString(2, groupId) ;
        resultSet = pstmt.executeQuery() ;
        if(resultSet != null)
        {
          if(resultSet.next())
          {
            retVal = resultSet.getInt("refseq.refSeqId") ;
          }
        }
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: RefSeqTable#getRefSeqIdByRefSeqName(S,C) => Exception getting refSeqId for refSeqName (" + refSeqName + ") in group with id " + groupId + " ; sql was: " + sql) ;
        ex.printStackTrace(System.err) ;
        retVal = -1 ;
      }
      finally
      {
        DBAgent.safelyCleanup(resultSet, pstmt) ;
      }
    }
    return retVal ;
  }

  // Get user databaseName for this refSeqId from main Genboree database
  public static String getRefSeqNameByRefSeqId(int refSeqId, DBAgent db)
  {
    return RefSeqTable.getRefSeqNameByRefSeqId("" + refSeqId, db) ;
  }
  public static String getRefSeqNameByRefSeqId(String refSeqId, DBAgent db)
  {
    String refSeqName = null;
    try
    {
      Connection conn = db.getConnection();
      refSeqName = RefSeqTable.getRefSeqNameByRefSeqId(refSeqId, conn) ;
    }
    catch( Exception ex )
    {
      ex.printStackTrace(System.err);
      System.err.println("Exception trying to find refSeqName From refSeqId using refSeqId " + refSeqId);
    }
    finally
    {
      return refSeqName;
    }
  }
  public static String getRefSeqNameByRefSeqId(int refSeqId, Connection conn)
  {
    return RefSeqTable.getRefSeqNameByRefSeqId("" + refSeqId, conn) ;
  }
  public static String getRefSeqNameByRefSeqId(String refSeqId, Connection conn)
  {
    String dbName = null ;
    String sql =  "SELECT refSeqName from refseq where refSeqId = ? " ;
    PreparedStatement pstmt = null ;
    ResultSet resultSet = null ;
    if(refSeqId != null)
    {
      try
      {
        pstmt = conn.prepareStatement(sql) ;
        pstmt.setString(1, refSeqId) ;
        resultSet = pstmt.executeQuery() ;
        if(resultSet != null)
        {
          if(resultSet.next())
          {
            dbName = resultSet.getString("refSeqName") ;
          }
        }
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: RefSeqTable#getRefSeqNameByRefSeqId(S,C) => Exception getting database name for refSeqId (" + refSeqId + ") ; sql was: " + sql) ;
        ex.printStackTrace(System.err) ;
      }
      finally
      {
        DBAgent.safelyCleanup(resultSet, pstmt) ;
      }
    }
    return dbName ;
  }

  // Ask if the refseqName is already present in the database.
  public static int hasRefSeqName(String refSeqName)
  {
    int found = -1 ;
    DBAgent db = null ;
    PreparedStatement stmt = null ;
    ResultSet rs = null ;
    Connection conn = null ;
    String sql = "select count(refSeqId) from refseq where refseqName = ? " ;

    try
    {
      db = DBAgent.getInstance() ;
      conn = db.getConnection() ;
      stmt = conn.prepareStatement(sql) ;
      stmt.setString(1, refSeqName) ;
      rs = stmt.executeQuery() ;
      if(rs.next())
      {
        found = rs.getInt(1) ;
      }
    }
    catch(Exception ex)
    {
      System.err.println("ERROR:QueryRefSeq#hasRefSeqName() => exception during query of refseqName ( " + refSeqName + ").");
      System.err.println(ex.getMessage()) ;
      ex.printStackTrace(System.err) ;
    }
    finally
    {
      db.safelyCleanup(rs, stmt, conn) ;
    }
    return found ;
  }

  // Ask if the databaseName is present in the database.
  public static boolean hasDatabaseName(String databaseName)
  {
    int found = -1 ;
    DBAgent db = null ;
    PreparedStatement stmt = null ;
    ResultSet rs = null ;
    Connection conn = null ;
    String sql = "select count(databaseName) from refseq where databaseName = ? " ;

    try
    {
      db = DBAgent.getInstance() ;
      conn = db.getConnection() ;
      stmt = conn.prepareStatement(sql) ;
      stmt.setString(1, databaseName) ;
      rs = stmt.executeQuery() ;
      if(rs.next())
      {
        found = rs.getInt(1) ;
      }
    }
    catch(Exception ex)
    {
      System.err.println("ERROR:RefSeqTable#hasDatabaseName() => exception during query for databaseName ( " + databaseName + ").");
      System.err.println(ex.getMessage()) ;
      ex.printStackTrace(System.err) ;
    }
    finally
    {
      db.safelyCleanup(rs, stmt, conn) ;
    }
    return (found > 0) ;
  }

  // This set of methods gets the database names associated with refSeqId.
  // Variations allow you to only get the shared database.
  public static String[] getDatabaseNamesArray(int refSeqId, Connection conn)
  {
    return getDatabaseNamesArray("" + refSeqId, false, conn) ;
  }
  public static String[] getDatabaseNamesArray(int refSeqId, boolean sharedDbsOnly, Connection conn)
  {
    return getDatabaseNamesArray("" + refSeqId, sharedDbsOnly, conn) ;
  }
  public static String[] getDatabaseNamesArray(String refSeqId, Connection conn)
  {
    return getDatabaseNamesArray(refSeqId, false, conn) ;
  }
  public static String[] getDatabaseNamesArray(String refSeqId, boolean sharedDbsOnly, Connection conn)
  {
    String dbNames[] = null ;
    ArrayList<String> dbNamesList = new ArrayList<String>() ;
    String sql =  "SELECT upload.databaseName FROM upload, refseq, refseq2upload " +
                  "WHERE refseq.refSeqId = ? " +
                  "AND refseq.refSeqId = refseq2upload.refSeqId " +
                  "AND upload.uploadId = refseq2upload.uploadId " ;
    PreparedStatement pstmt = null ;
    ResultSet resultSet = null ;

    if(refSeqId != null)
    {
      if(sharedDbsOnly) // Don't get the local database (the one matching refSeqId itself)
      {
        sql += "AND refseq.databaseName != upload.databaseName" ;
      }
      try
      {
        pstmt = conn.prepareStatement(sql) ;
        pstmt.setString(1, refSeqId) ;
        resultSet = pstmt.executeQuery() ;
        // For each row retrieved, save the database name
        while(resultSet.next())
        {
          String databaseName = resultSet.getString(1) ;
          dbNamesList.add(databaseName) ;
        }

        if(dbNamesList.size() > 0)
        {
          dbNames = new String[dbNamesList.size()] ;
          dbNamesList.toArray(dbNames) ;
        }
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: RefSeqTable#getDatabaseNamesArray(S,b, C) => Exception getting database names; sql was: " + sql) ;
        ex.printStackTrace(System.err) ;
      }
      finally
      {
        DBAgent.safelyCleanup(resultSet, pstmt) ;
      }
    }
    return dbNames ;
  }
}
