package org.genboree.dbaccess.util ;

import java.sql.* ;
import java.util.* ;
import org.genboree.dbaccess.* ;

public class FtypeTable
{
  public static DbResourceSet getRecords(Connection conn)
  {
    PreparedStatement stmt = null ;
    ResultSet rs = null ;
    DbResourceSet dbSet = null ;
    if(conn != null)
    {
      try
      {
        String sql = "select * from ftype " ;
        stmt = conn.prepareStatement(sql) ;
        rs = stmt.executeQuery() ;
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: FtypeTable#getRecords(C) => exception getting all track records from db") ;
        ex.printStackTrace(System.err) ;
      }
    }
    dbSet = new DbResourceSet(rs, stmt, conn, null) ;
    return dbSet ;
  }

  public static DbResourceSet getRecordByTypeSubtype(String type, String subtype, Connection conn)
  {
    PreparedStatement stmt = null ;
    ResultSet rs = null ;
    DbResourceSet dbSet = null ;
    String sql = "select * from ftype where fmethod = ? and fsource = ? " ;
    if(conn != null)
    {
      try
      {
        stmt = conn.prepareStatement(sql) ;
        stmt.setString(1, type) ;
        stmt.setString(2, subtype) ;
        rs = stmt.executeQuery() ;
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: FtypeTable#getRecordByTypeSubtype(S,S, C) => exception getting track record via type (" + type + ") and subtype (" + subtype + ")") ;
        ex.printStackTrace(System.err) ;
      }
    }
    dbSet = new DbResourceSet(rs, stmt, conn, null) ;
    return dbSet ;
  }

  public static ArrayList<String> getFtypeids(Connection conn)
  {
    return FtypeTable.getFtypeids(false, conn) ;
  }

  public static ArrayList<String> getFtypeidsForNonEmptyTracks(Connection conn)
  {
    return FtypeTable.getFtypeids(true, conn) ;
  }

  public static ArrayList<String> getFtypeids(boolean onlyForNonEmptyTracks, Connection conn)
  {
    ArrayList<String> retVal = new ArrayList<String>() ;
    PreparedStatement stmt = null ;
    ResultSet rs = null ;
    String sql =  "select ftype.* from ftype " ;
    if(conn != null)
    {
      try
      {
        if(onlyForNonEmptyTracks)
        {
          sql += ", ftypeCount where ftype.ftypeid = ftypeCount.ftypeid and ftypeCount.numberOfAnnotations >= 0 " ;
        }
        stmt = conn.prepareStatement(sql) ;
        rs = stmt.executeQuery() ;
        while(rs.next())
        {
          retVal.add(rs.getString("ftypeid")) ;
        }
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: FtypeTable#getFtypeidsForNonEmptyTracks(C) => exception getting ftypeids for non-empty tracks.") ;
        ex.printStackTrace(System.err) ;
      }
      finally
      {
        DBAgent.safelyCleanup(rs, stmt) ;
      }
    }
    return retVal ;
  }

  public static HashMap<Integer, String[]> getFtypeid2TrackNameMap(Connection conn)
  {
    HashMap<Integer, String[]> retVal = new HashMap<Integer,String[]>() ;
    PreparedStatement stmt = null ;
    ResultSet rs = null ;
    DbResourceSet dbSet = null ;
    if(conn != null)
    {
      try
      {
        // Get all the ftype records
        dbSet = FtypeTable.getRecords(conn) ;
        // Populate HashMap of ftypeid -> [type, subtype]
        if(dbSet != null && dbSet.resultSet != null)
        {
          while(dbSet.resultSet.next())
          {
            String[] trackName = new String[] {dbSet.resultSet.getString("fmethod"), dbSet.resultSet.getString("fsource")} ;
            retVal.put(dbSet.resultSet.getInt("ftypeid"), trackName) ;
          }
        }
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: FtypeTable#getFtypeid2TrackNameMap(C) => exception getting map of ftypeid -> [type, subtype]") ;
        ex.printStackTrace(System.err) ;
      }
      finally
      {
        if(dbSet != null)
        {
          dbSet.close() ;
        }
      }
    }
    return retVal ;
  }

  public static HashMap<String, Integer> getTrackName2FtypeidMap(Connection conn)
  {
    HashMap<String, Integer> retVal = new HashMap<String, Integer>() ;
    PreparedStatement stmt = null ;
    ResultSet rs = null ;
    DbResourceSet dbSet = null ;
    if(conn != null)
    {
      try
      {
        // Get all the ftype records
        dbSet = FtypeTable.getRecords(conn) ;
        // Populate HashMap of ftypeid -> [type, subtype]
        if(dbSet != null && dbSet.resultSet != null)
        {
          while(dbSet.resultSet.next())
          {
            String trackName = dbSet.resultSet.getString("fmethod") + ":" + dbSet.resultSet.getString("fsource") ;
            retVal.put(trackName, dbSet.resultSet.getInt("ftypeid")) ;
          }
        }
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: FtypeTable#getTrackName2Ftypeid2Map(C) => exception getting map of 'type:subtype' -> ftypeid") ;
        ex.printStackTrace(System.err) ;
      }
      finally
      {
        if(dbSet != null)
        {
          dbSet.close() ;
        }
      }
    }
    return retVal ;
  }

  // Using LEFT JOIN to put NULL for any track setting column that is not set, retrieve the
  // complete track settings configuration for a particular user. Other variations of this method
  // will get the settings for a specific ArrayList of track names.
  // - Because tracks can have multiple links associated with them, each track can be present
  //   more than once. If this occurs, ONLY the "linkmd5" will be different between the multiple rows.
  //
  // The result set returned has these columns:
  //   ftypeid | trackName | display | color | style | sortkey | url | description | label | linkmd5
  // Any column whose value hasn't been set is NULL.
  public static DbResourceSet getTrackSettings(Connection conn, int userId)
  {
    return getTrackSettings(conn, "" + userId, null) ;
  }
  public static DbResourceSet getTrackSettings(Connection conn, String userId)
  {
    return getTrackSettings(conn, userId, null) ;
  }
  public static DbResourceSet getTrackSettings(Connection conn, String userId, ArrayList<String> trackNames)
  {
    PreparedStatement stmt = null ;
    ResultSet rs = null ;
    DbResourceSet dbSet = null ;
    if(conn != null)
    {
      try
      {
        String sql =  "SELECT DISTINCT ftype.ftypeid, CONCAT(ftype.fmethod, \":\",  ftype.fsource) AS trackName, display, color.value AS color, style.name AS style, sortkey, url, featureurl.description, featureurl.label, linkId AS linkmd5 " +
                      "FROM ftype LEFT JOIN featuretocolor ON (ftype.ftypeid = featuretocolor.ftypeid) " +
                      "           LEFT JOIN featuretostyle on (ftype.ftypeid = featuretostyle.ftypeid) " +
                      "           LEFT JOIN featureurl on (ftype.ftypeid = featureurl.ftypeid) " +
                      "           LEFT JOIN featuredisplay on (ftype.ftypeid = featuredisplay.ftypeid) " +
                      "           LEFT JOIN featuresort on (ftype.ftypeid = featuresort.ftypeid) " +
                      "           LEFT JOIN featuretolink on (ftype.ftypeid = featuretolink.ftypeid) " +
                      "           LEFT JOIN color on (featuretocolor.colorId = color.colorId) " +
                      "           LEFT JOIN style on (featuretostyle.styleId = style.styleId) " +
                      "WHERE featuretocolor.userId = ? " ;
        if(trackNames != null)
        {
          sql += " AND CONCAT(ftype.fmethod, \":\", ftype.fsource) IN ( " ;
          for(String trackName : trackNames)
          {
            sql += " ?," ;
          }
          sql = sql.substring(0, sql.length() - 1) ;
          sql += ") " ;
        }
        // prepare the SQL
        stmt = conn.prepareStatement(sql) ;
        // bind variables
        stmt.setString(1, userId) ;
        if(trackNames != null)
        {
          for(int ii=0; ii<trackNames.size(); ii++)
          {
            stmt.setString(2 + ii, trackNames.get(ii)) ;
          }
        }
        // execute
        rs = stmt.executeQuery() ;
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: FtypeTable#getTrackSettings(C,S,A) => exception getting track user settings for user " + userId + ". Error mesage: " + ex.getMessage() + " ; Trace: " ) ;
        ex.printStackTrace(System.err) ;
      }
    }
    dbSet = new DbResourceSet(rs, stmt, conn, null) ;
    return dbSet ;
  }

  // ARJ: Use this version to get the high-denisty flag properly, by checking all databases
  // for the gbTrackRecordType track attribute setting. If ANY database tags the track
  // as high density, then it is considered high density.
  // - note that by current design just the ASSOCIATION of 'gbTrackRecordType' with a track
  //   tags it as high density, REGARDLESS of the value of that attribute (as from Sameer)
  // - so currently, there's no need to check the value, just the association
  // @dbNames@ - a list of dbNames with the user database at the end
  // @trackName@ - the name of the track to check for the high-density flag
  // @returns@ - true if it is a high-density track, false if not.
  public static boolean fetchHighDensityFlag(String[] dbNames, String trackName)
  {
    boolean isHighDT = false ;
    for(int ii = 0; ii < dbNames.length; ii++)
    {
      boolean checkHighDT = FtypeTable.fetchHighDensityFlag(dbNames[ii], trackName) ;
      if(checkHighDT)
      {
        isHighDT = checkHighDT ; // we found a db that has this track tagged as HD
        break ;
      }
    }
    return isHighDT ;
  }
  public static boolean fetchHighDensityFlag(String dbName, String trackName)
  {
    boolean isHighDT = false ;
    PreparedStatement stmt = null ;
    ResultSet rs = null ;
    Connection conn = null ;
    DBAgent db = DBAgent.getInstance() ;

    try
    {
      conn = db.getConnection(dbName) ;
      String qs = "SELECT ftype_id FROM ftype, ftype2attributes, ftypeAttrNames " +
                  "WHERE ftype2attributes.ftypeAttrName_id = ftypeAttrNames.id " +
                  "  AND ftypeAttrNames.name = 'gbTrackRecordType' " +
                  "  AND ftype2attributes.ftype_id = ftype.ftypeid " +
                  "  AND CONCAT(ftype.fmethod, ':', ftype.fsource) = ? " ;
      stmt = conn.prepareStatement(qs) ;
      stmt.setString(1, trackName) ;
      rs = stmt.executeQuery() ;
      if( rs.next() )
      {
        int ftype_id = rs.getInt("ftype_id") ;
        if(ftype_id > 0)
        {
          isHighDT = true ;
        }
      }
    }
    catch( Exception ex )
    {
      System.err.println( "ERROR: Exception in FtypeTable::fetchHighDensityFlag(S, S) => exception thrown. Details:\n" + ex.getMessage() ) ;
      ex.printStackTrace( System.err ) ;
    }
    finally
    {
      db.safelyCleanup( rs, stmt, conn) ;
      return isHighDT ;
    }
  }
  public static boolean fetchHighDensityFlag(String dbName, int ftypeId)
  {
    boolean retVal = false ;
    Connection conn = null ;
    DBAgent db = DBAgent.getInstance() ;
    try
    {
      conn = db.getConnection(dbName) ;
      retVal = FtypeTable.fetchHighDensityFlag(conn, ftypeId) ;
      db.safelyCleanup(null, null, conn) ;
    }
    catch(Exception ex)
    {
      System.err.println( "ERROR: Exception in FtypeTable::fetchHighDensityFlag(S, i) => exception thrown. Details:\n" + ex.getMessage() ) ;
      ex.printStackTrace( System.err ) ;
    }
    return retVal ;
  }
  public static boolean fetchHighDensityFlag(Connection conn, int ftypeId)
  {
    boolean isHighDT = false ;
    PreparedStatement stmt = null ;
    ResultSet rs = null ;
    DBAgent db = DBAgent.getInstance() ;

    try
    {
      // - note that by current design just the ASSOCIATION of 'gbTrackRecordType' with a track
      //   tags it as high density, REGARDLESS of the value of that attribute (as from Sameer)
      String qs = "SELECT ftype_id FROM ftype2attributes, ftypeAttrNames " +
                  "WHERE ftype2attributes.ftypeAttrName_id = ftypeAttrNames.id " +
                  "  AND ftypeAttrNames.name = 'gbTrackRecordType' " +
                  "  AND ftype2attributes.ftype_id = ?" ;
      stmt = conn.prepareStatement(qs) ;
      stmt.setInt(1, ftypeId) ;
      rs = stmt.executeQuery() ;
      if( rs.next() )
      {
        int ftype_Id = rs.getInt("ftype_id") ;
        if(ftype_Id > 0)
        {
          isHighDT = true ;
        }
      }
    }
    catch( Exception ex )
    {
      System.err.println( "ERROR: Exception in FtypeTable::fetchHighDensityFlag(C, i) => exception thrown. Details:\n" + ex.getMessage() ) ;
      ex.printStackTrace( System.err ) ;
    }
    finally
    {
      db.safelyCleanup( rs, stmt, null) ;
      return isHighDT ;
    }
  }

  public static boolean isAnnoDownloadBlocked(String dbName, int fid)
  {
    return FtypeTable.isAnnoDownloadBlocked(dbName, "" + fid) ;
  }
  public static boolean isAnnoDownloadBlocked(String dbName, String fid)
  {
    boolean retVal = false ;
    Connection conn = null ;
    DBAgent db = DBAgent.getInstance() ;

    try
    {
      conn = db.getConnection(dbName) ;
      retVal = FtypeTable.isAnnoDownloadBlocked(conn, fid) ;
    }
    catch( Exception ex )
    {
      System.err.println( "ERROR: Exception in FtypeTable::isAnnoDownloadBlocked(S, S) => exception thrown. Details:\n" + ex.getMessage() ) ;
      ex.printStackTrace( System.err ) ;
    }
    return retVal ;
  }
  public static boolean isAnnoDownloadBlocked(Connection conn, String fid)
  {
    boolean isBlocked = false ;
    PreparedStatement stmt = null ;
    ResultSet rs = null ;
    DBAgent db = DBAgent.getInstance() ;

    try
    {
      String qs = "SELECT ftypeAttrValues.value FROM fdata2, ftype, ftype2attributes, ftypeAttrNames, ftypeAttrValues " +
                  "WHERE ftype2attributes.ftypeAttrName_id = ftypeAttrNames.id " +
                  "  AND ftypeAttrNames.name = 'gbNotDownloadable' " +
                  "  AND ftype2attributes.ftype_id = ftype.ftypeid " +
                  "  AND ftype2attributes.ftypeAttrValue_id = ftypeAttrValues.id " +
                  "  AND ftype.ftypeid = fdata2.ftypeid " +
                  "  AND fdata2.fid = ? " ;
      stmt = conn.prepareStatement(qs) ;
      stmt.setString(1, fid) ;
      rs = stmt.executeQuery() ;

      if( rs.next() )
      {
        String value = rs.getString("value") ;
        System.err.println("DEBUG isAnnoDownloadBlocked: gbNotDownloadable value = " + value ) ;
        if(value.equalsIgnoreCase("true") || value.equalsIgnoreCase("yes"))
        {
          isBlocked = true ;
        }
      }
    }
    catch( Exception ex )
    {
      System.err.println( "ERROR: Exception in FtypeTable::isTrackDownloadBlocked(S, S) => exception thrown. Details:\n" + ex.getMessage() ) ;
      ex.printStackTrace( System.err ) ;
    }
    finally
    {
      db.safelyCleanup( rs, stmt, conn) ;
      return isBlocked ;
    }
  }

  public static boolean isTrackDownloadBlocked(String dbName, String trackName)
  {
    boolean retVal = false ;
    Connection conn = null ;
    DBAgent db = DBAgent.getInstance() ;

    System.err.println("DEBUG: trackName 1 = " + trackName ) ;
    try
    {
      conn = db.getConnection(dbName) ;
      retVal = isTrackDownloadBlocked(conn, trackName) ;
    }
    catch( Exception ex )
    {
      System.err.println( "ERROR: Exception in FtypeTable::isTrackDownloadBlocked(S, S) => exception thrown. Details:\n" + ex.getMessage() ) ;
      ex.printStackTrace( System.err ) ;
    }
    return retVal ;
  }

  public static boolean isTrackDownloadBlocked(Connection conn, String trackName)
  {
    boolean isBlocked = false ;
    PreparedStatement stmt = null ;
    ResultSet rs = null ;
    DBAgent db = DBAgent.getInstance() ;

    try
    {
      String qs = "SELECT ftypeAttrValues.value FROM ftype, ftype2attributes, ftypeAttrNames, ftypeAttrValues " +
                  "WHERE ftype2attributes.ftypeAttrName_id = ftypeAttrNames.id " +
                  "  AND ftypeAttrNames.name = 'gbNotDownloadable' " +
                  "  AND ftype2attributes.ftype_id = ftype.ftypeid " +
                  "  AND ftype2attributes.ftypeAttrValue_id = ftypeAttrValues.id " +
                  "  AND CONCAT(ftype.fmethod, ':', ftype.fsource) = ? " ;
      stmt = conn.prepareStatement(qs) ;
      stmt.setString(1, trackName) ;
      rs = stmt.executeQuery() ;
      System.err.println("DEBUG: trackName 2 = " + trackName ) ;

      if( rs.next() )
      {
        String value = rs.getString("value") ;
        System.err.println("DEBUG: gbNotDownloadable value = " + value ) ;
        if(value.equalsIgnoreCase("true") || value.equalsIgnoreCase("yes"))
        {
          isBlocked = true ;
        }
      }
    }
    catch( Exception ex )
    {
      System.err.println( "ERROR: Exception in FtypeTable::isTrackDownloadBlocked(S, S) => exception thrown. Details:\n" + ex.getMessage() ) ;
      ex.printStackTrace( System.err ) ;
    }
    finally
    {
      db.safelyCleanup( rs, stmt, conn) ;
      return isBlocked ;
    }
  }

  public static int insertTrack(String type, String subtype, Connection conn)
  {
    int retVal = -1 ;
    PreparedStatement stmt = null ;
    int numInserted = 0 ;
    ResultSet rs = null ;
    DbResourceSet dbSet = null ;
    if(conn != null)
    {
      try
      {
        // Insert the new track record, ignoring insert if it's actually already there
        String sql = "insert ignore into ftype values (null, ?, ?) " ;
        stmt = conn.prepareStatement(sql) ;
        stmt.setString(1, type) ;
        stmt.setString(2, subtype) ;
        numInserted = stmt.executeUpdate() ;
        // Retrieve the 'new' track record and get the ftypeid for it.
        dbSet = FtypeTable.getRecordByTypeSubtype(type, subtype, conn) ;
        if(dbSet != null && dbSet.resultSet != null)
        {
          while(dbSet.resultSet.next())
          {
            retVal = dbSet.resultSet.getInt("ftypeid") ;
            break ;
          }
        }
        else // oh oh, couldn't get a matching record? something very bad happened.
        {
          System.err.println("ERROR: FtypeTable#insertTrack(S,S,C) => got empty result set getting track record via type (" + type + ") and subtype (" + subtype + ") while trying to get ftypeid of inserted track" ) ;
        }
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: FtypeTable#insertTrack(S,S,C) => exception getting track record via type and subtype") ;
        ex.printStackTrace(System.err) ;
      }
      finally
      {
        if(dbSet != null)
        {
          dbSet.close() ;
        }
      }
    }
    return retVal ;
  }

  // Better alternative for poorly written and sometimes not working fetchTracksFromRefSeqIdEntryPoint in GenboreeUpload.java
  // Note that the local database will always be added at the end. Things that use this array seem to assume that as they build
  // HashMaps and such, wanting local (last things in array processed) to override shared (first things in array processed).
  // - Note: uses old Genboree db classes (DbFtype and DbGclass) either for backward compatibility in calling code or for some features;
  //         don't write new code that uses this.
  public static DbFtype[] fetchDbFtypeArray(DBAgent db, String refSeqId, int genboreeUserId)
  {
    return FtypeTable.fetchDbFtypeArray(db, refSeqId, "" + genboreeUserId) ;
  }
  public static DbFtype[] fetchDbFtypeArray(DBAgent db, String refSeqId, String genboreeUserId)
  {
    long startTime = System.currentTimeMillis() ;
    DbFtype[] retVal = null ;
    ArrayList<DbFtype> list = new ArrayList<DbFtype>() ;
    Connection mainConn = null ;
    Connection conn = null ;
    Statement stmt = null ;
    String currDbName = null ;
    if(refSeqId == null)
    {
      retVal = null ;
    }
    else
    {
      try
      {

        // Get list of shared database names associated with refSeqId from main genboree database
        mainConn = db.getConnection() ;
        String[] sharedDbNames = RefSeqTable.getDatabaseNamesArray(refSeqId, true, mainConn) ;
        if(sharedDbNames == null) // No shared DBs, looks like.
        {
          sharedDbNames = new String[0] ;
        }
        // Get local database name for this refSeqId
        String localDbName = RefSeqTable.getDatabaseNameByRefSeqId(refSeqId, mainConn) ;
        System.err.println("    TIMING fetchDbFtypeArray: got shared and local database names = " + (System.currentTimeMillis() - startTime)) ;
        startTime = System.currentTimeMillis() ;
        // Append localDbName to end of sharedDbNames so we have total list with shared first then local
        ArrayList<String> dbNames = new ArrayList<String>(sharedDbNames.length + 1) ;
        dbNames.addAll(Arrays.asList(sharedDbNames)) ;
        dbNames.add(localDbName) ;
        String[] dbNamesArray = new String[dbNames.size()] ;
        dbNames.toArray(dbNamesArray) ;
        System.err.println("    TIMING fetchDbFtypeArray: got dbNames ArrayList = " + (System.currentTimeMillis() - startTime)) ;
        startTime = System.currentTimeMillis() ;
        // Iterate over each dbName at get the tracks
        Iterator<String> iter = dbNames.iterator() ;
        while(iter.hasNext())
        {
          currDbName = iter.next() ;
          conn = db.getConnection(currDbName) ;
          // Get ftype records for this this database (even for empty ones)
          DbResourceSet dbSet = FtypeTable.getRecords(conn) ;
          if(dbSet != null && dbSet.resultSet != null)
          {
            while(dbSet.resultSet.next())
            {
              int ftypeId = dbSet.resultSet.getInt("ftypeid") ;
              String fmethod = dbSet.resultSet.getString("fmethod") ;
              String fsource = dbSet.resultSet.getString("fsource") ;
              DbFtype dbFtype = new DbFtype(currDbName, ftypeId, fmethod, fsource) ;
              // Get all the classes associated with this track, even from shared tracks of this database AND local database
              String[] gclasses = DbGclass.fetchGClasses(db, dbNamesArray, fmethod, fsource) ;
              dbFtype.setBelongToAllThisGclasses(gclasses) ;
              // Get uploadId from main genboree database
              String uploadId = UploadTable.getUploadIdByRefSeqIdAndDbName(refSeqId, currDbName, mainConn) ;
              // Get all urls associated with this track, even from shared tracks of this database
              String[] allUrls = FeatureUrlTable.getTrackUrlArrayByTypeAndSubtype(fmethod, fsource, conn) ;
              if(allUrls != null)
              {
                dbFtype.setAllUrl(allUrls[0], allUrls[1], allUrls[2]) ;
              }
              list.add(dbFtype) ;
            }
          }
        }
        System.err.println("    TIMING fetchDbFtypeArray: created and added stupid heavy-weight DbFtype instances = " + (System.currentTimeMillis() - startTime)) ;
        startTime = System.currentTimeMillis() ;
        if(list.size() > 0)
        {
          retVal = new DbFtype[list.size()] ;
          list.toArray(retVal) ;
        }
      }
      catch(Exception ex)
      {
        System.err.println( "ERROR:  FtypeTable#fetchDbFtypeArray => exception getting ftype (and DbFtype instance) for databaseName = " + currDbName) ;
        ex.printStackTrace(System.err) ;
      }
    }
    System.err.println("    TIMING fetchDbFtypeArray: turned ArrayList of DbFtypes into regular DbFtype[] = " + (System.currentTimeMillis() - startTime)) ;
    startTime = System.currentTimeMillis() ;
    return retVal ;
  }
}
