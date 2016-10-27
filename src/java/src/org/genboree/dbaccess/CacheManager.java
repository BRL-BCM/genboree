package org.genboree.dbaccess ;

import java.io.* ;
import java.security.MessageDigest ;
import java.sql.* ;
import java.util.* ;
import org.genboree.util.* ;
import org.genboree.dbaccess.util.* ;

public class CacheManager
{
  protected static final String genboreeRoot = Constants.GENBOREE_HTDOCS ;
  public static final File baseCacheDir = new File( genboreeRoot, "cache" ) ;
  static
  {
    try
    {
      if( !baseCacheDir.exists() )
      {
        baseCacheDir.mkdir() ;
      }
    }
    catch( Exception ex )
    {
      System.err.println("Unable to create directory " + baseCacheDir.getAbsolutePath() + ". Error message: " + ex.getMessage()) ;
    }
  }

  // Publicly accessible instance variables.
  public String refSeqId ;
  public String userDbName ;
  public String[] sharedDBNames ;
  public ArrayList<String> trackNames ;
  public HashMap<String, String> uiViewableTracks ;
  public static final String[][] trackSettingsColumns = {
    { "color", "#000000" },
    { "style", "simple_draw" },
    { "sortkey", "0" },
    { "display", "1" },
    { "url", "" },
    { "description", "" },
    { "label", "" },
    { "linkmd5", "" }
  } ;
  // Track settings hash. { "track:name" => "color" => "#000000" } etc
  public HashMap<String, HashMap<String, String>> trackSettings ;

  // Private instance variables.
  protected DBAgent db;
  protected Refseq rseq;
  protected String userId;
  protected DbFref fref;
  protected long from;
  protected long to;
  protected int iWidth;
  protected int iHid;
  protected int drawInMargin;
  protected int displayTrackDesc;
  protected String cacheKey;
  protected File cacheDir;
  protected String fileName;
  protected String serverName;
  protected String characteristicStr ;

  protected Vector vTimeLabs ;
  protected Vector vTimes ;

  public Vector setVTimeLabs(Vector vTimeLabs, Vector vTimes)
  {
    this.vTimeLabs = vTimeLabs ;
    this.vTimes = vTimes ;
    return this.vTimeLabs ;
  }

  public CacheManager( DBAgent db, Refseq rseq, String userId, String myServerName, HashMap<String, String> uiViewableTracks) throws SQLException
  {
    this.db = db ;
    this.rseq = rseq ;
    this.userId = userId ;
    this.serverName = myServerName ;
    this.rseq.setNameShareDatabases(db) ;
    this.uiViewableTracks = uiViewableTracks ;
    this.refSeqId = rseq.getRefSeqId() ;
    this.userDbName = null ;
    this.sharedDBNames = null ;
    this.trackSettings = null ;
    this.characteristicStr = null ;
    this.trackNames = new ArrayList<String>() ;

    cacheDir = new File( baseCacheDir, rseq.getDatabaseName() ) ;
    try
    {
      if( !cacheDir.exists() )
      {
        cacheDir.mkdir() ;
      }
    }
    catch( Exception ex )
    {
      System.err.println("Unable to create directory " + cacheDir.getAbsolutePath() + ". Error mesage: " + ex.getMessage()) ;
    }
    this.vTimeLabs = new Vector() ;

    init() ;
  }

  public String getCacheKey()
  {
    return cacheKey ;
  }

  public String getFileName()
  {
    return fileName ;
  }

  // Init.
  // When called, retrieves all the track settings info for the user and track list for
  // later use when computing cache key. Also populates some other basic variables too.
  public boolean init()
  {
    boolean retVal = false ;
    try
    {
      Connection conn = db.getConnection() ;
      // - get user database name
      this.userDbName = RefSeqTable.getDatabaseNameByRefSeqId(this.refSeqId, conn) ;
      // - get shared database name(s)
      this.sharedDBNames = RefSeqTable.getDatabaseNamesArray(this.refSeqId, true, conn) ;
      Iterator<String> iter = this.uiViewableTracks.keySet().iterator() ;
      while( iter.hasNext() )
      {
        String tn = iter.next() ;
        this.trackNames.add(tn) ;
      }
      // - sort list by track name so we have invocation independence:
      Collections.sort(this.trackNames, new Comparator()
      {
        public int compare(Object aa, Object bb)
        {
          return ( ((String)aa).toLowerCase().compareTo(((String)bb).toLowerCase()) ) ;
        }
      }) ;
      // All done with connection to main Genboree database:
      db.safelyCleanup(null, null, conn) ;
      // Get track settings for this user
      getTrackSettings() ;
      retVal = true ;
    }
    catch( Exception ex )
    {
      System.err.println("ERROR: Couldn't init info needed for cache-lookup. Error mesage: " + ex.getMessage() + " ; Trace:") ;
      ex.printStackTrace(System.err) ;
      retVal = false ;
    }
    return retVal ;
  }

  // Populates trackSettings, which is a Hash of Hashes of String settings values:
  // {"Track:Name"} => {"color"} => "FFAA99"
  // etc for styles, url, description, display sortkey, linkId, etc.
  //
  // User database settings will override shared settings. Thus, this method proceeds like this:
  // 1. Initialize all settings for all tracks to default values.
  // 2. Get settings for each shared database, where settings are present.
  //    . Get settings for "default" user (userId 0)
  //    . Then get settings for real userId
  // 3. Get settings for the user database, where present.
  //    . Get settings for "default" user (userId 0)
  //    . Then get settings for real userId
  protected boolean getTrackSettings()
  {
    boolean retVal = false ;
    // 1. Initialize all settings for all tracks to default values.
    this.trackSettings = new HashMap<String, HashMap<String, String>>() ;
    for(String trkName : this.trackNames)
    {
      HashMap<String, String> trkSetting = new HashMap<String, String>() ;
      for(int ii=0; ii<trackSettingsColumns.length; ii++)
      {
        trkSetting.put(trackSettingsColumns[ii][0], trackSettingsColumns[ii][1]) ;
      }
      this.trackSettings.put(trkName, trkSetting) ;
    }
    try
    {
      //System.err.println("DEBUG:    * going to loop over sharedDBNames for refSeqId " + this.refSeqId + " (unless null for some reason). sharedDBNames => " +  (this == null ? "fatal: 'this' is null!" : this.sharedDBNames)) ;
      if(this.sharedDBNames != null)
      {
        // 2. Get settings for each shared database, where settings are present.
        for(String sharedDbName : this.sharedDBNames)
        {
          //System.err.println("DEBUG:       - try get conn for sharedDbName => " + sharedDbName) ;
          Connection conn = db.getConnection(sharedDbName) ;
          //System.err.println("DEBUG:       - try get settings for default user (0) ") ;
          // Get settings for "default" user (userId 0).
          getSettingsFromDbForUser(conn, "0") ;
          //System.err.println("DEBUG:       - try get settings for actual user with userId => " + (this == null ? "fatal: 'this' is null!" : this.userId)) ;
          // Get settings for actual user.
          getSettingsFromDbForUser(conn, this.userId) ;
          //System.err.println("DEBUG:       - done with sharedDbName => " + sharedDbName) ;
        }
      }

      // 3. Get settings for the user database, where present.
      Connection conn = db.getConnection(this.userDbName) ;
      // Get settings for "default" user (userId 0).
      getSettingsFromDbForUser(conn, "0") ;
      // Get settings for actual user.
      getSettingsFromDbForUser(conn, this.userId) ;

      // 4. Finally, the display settings from the UI override anything from the database
      Iterator<Map.Entry<String, String>> iter = this.uiViewableTracks.entrySet().iterator() ;
      while(iter.hasNext())
      {
        Map.Entry<String, String> entry = iter.next() ;
        String tn = entry.getKey() ;
        String display = entry.getValue() ;
        this.trackSettings.get(tn).put("display", display) ;
      }
      retVal = true ;
    }
    catch(Exception ex)
    {
      System.err.println("ERROR: CacheManager#getTrackSettings() => " + ex.getMessage() + " ; Trace: ") ;
      ex.printStackTrace(System.err) ;
    }
    return retVal ;
  }

  protected String generateCacheKey()
  {
    StringBuffer buff = new StringBuffer() ;

    vTimeLabs.addElement("          - BEFORE sort tracks") ;
    vTimes.addElement( new java.util.Date() ) ;

    buff.append(serverName).append("\t").append(iWidth).append("\t").append(iHid).append("\t") ;
    buff.append(drawInMargin).append("\t").append(displayTrackDesc).append("\n") ;

    vTimeLabs.addElement("          - AFTER sort tracks") ;
    vTimes.addElement( new java.util.Date() ) ;

    // Go through sorted list of track names
    for(int ii=0; ii<this.trackNames.size(); ii++)
    {
      String trkName = this.trackNames.get(ii) ;
      buff.append(trkName).append("\t") ;
      HashMap<String, String> trkSetting = this.trackSettings.get(trkName) ;
      System.err.println("DEBUG: TRACK = " + trkName) ;
      System.err.println("       style = " + trkSetting.get("style")) ;
      buff.append(trkSetting.get("display")).append("\t") ;
      buff.append(trkSetting.get("color")).append("\t") ;
      buff.append(trkSetting.get("style")).append("\t") ;
      buff.append(trkSetting.get("sortkey")).append("\t") ;
      buff.append(trkSetting.get("url")).append("\t") ;
      buff.append(trkSetting.get("label")).append("\t") ;
      buff.append(trkSetting.get("description")).append("\t") ;
      buff.append(trkSetting.get("linkmd5")).append("\t") ;
      buff.append("\n") ;
    }

    vTimeLabs.addElement("          - AFTER fetching track setting info") ;
    vTimes.addElement( new java.util.Date() ) ;

    try
    {
      MessageDigest md = MessageDigest.getInstance( "MD5" ) ;
      this.characteristicStr = buff.toString() ;
      md.update( this.characteristicStr.getBytes() ) ;
      byte[] dg = md.digest() ;
      String outc = "" ;
      for( int i=0; i<dg.length; i++ )
      {
        String hc = Integer.toHexString( (int)dg[i] & 0xFF ) ;
        while( hc.length() < 2 )
        {
          hc = "0" + hc ;
        }
        outc = outc + hc ;
      }
      this.cacheKey = outc ;
    }
    catch( Exception ex )
    {
      ex.printStackTrace(System.err) ;
    }
    vTimeLabs.addElement("          - AFTER digest computation") ;
    vTimes.addElement( new java.util.Date() ) ;
    return this.cacheKey ;
  }

  public String cacheSearch(DbFref fref, long from, long to, int iWidth, int iHid, int drawInMargin, int displayTrackDesc)
  {
    String retVal = null ;
    this.fref = fref ;
    this.from = from ;
    this.to = to ;
    this.iWidth = iWidth ;
    this.iHid = iHid ;
    this.drawInMargin = drawInMargin ;
    this.displayTrackDesc = displayTrackDesc ;
    int currentId = 0 ;
    int currentCount = 0 ;

    this.cacheKey = null ;
    this.fileName = null ;

    if(checkIfTableExist("image_cache", db, rseq)) // then image_cache table exists
    {
      vTimeLabs.addElement("        - AFTER check table exists") ;
      vTimes.addElement( new java.util.Date() ) ;

      try
      {
        String rid = "" + fref.getRid() ;
        Connection conn = db.getConnection(this.userDbName) ;
        Statement stmt = conn.createStatement() ;
        ResultSet rs = null ;
        vTimeLabs.addElement("        - BEFORE generateCacheKey()") ;
        vTimes.addElement( new java.util.Date() ) ;

        if( generateCacheKey() != null )
        {
          vTimeLabs.addElement("        - AFTER generateCacheKey()") ;
          vTimes.addElement( new java.util.Date() ) ;

          String sql =  "SELECT fileName, imageCacheId, hitCount FROM image_cache " +
                        "WHERE rid = " + rid + " AND fstart = " + from + " AND fstop = " + to +
                        "  AND cacheKey = '" + this.cacheKey + "'" ;
          rs = stmt.executeQuery(sql) ;

          vTimeLabs.addElement("        - AFTER query image_cache using cacheKey AND rid, fstart, fstop (um, key has to be unique...so why those too?)") ;
          vTimes.addElement( new java.util.Date() ) ;

          if( rs.next() )
          {
            fileName = rs.getString(1) ;
            currentId = rs.getInt(2) ;
            currentCount = rs.getInt(3) ;
            if(fileName != null)
            {
              updateHitCount(currentId, currentCount) ;

              vTimeLabs.addElement("        - AFTER [found cache file] updating hit count for cache file") ;
              vTimes.addElement( new java.util.Date() ) ;
            }
          }
          stmt.close() ;
          retVal = fileName ;
        }
        this.db.safelyCleanup(rs, stmt, conn) ;
      }
      catch( Exception ex )
      {
        if( ex instanceof SQLException && ((SQLException)ex).getErrorCode() == 1054 )
        {
          dropTable() ;
          createTable(db, rseq) ;
          vTimeLabs.addElement("        - AFTER SQLException and doing dropTable() + createTbale() !!") ;
          vTimes.addElement( new java.util.Date() ) ;
        }
        else if( ex instanceof SQLException && ((SQLException)ex).getErrorCode()==1146 )
        {
          createTable(db, rseq) ;
          vTimeLabs.addElement("        - AFTER SQLException and doing just createTbale() !!") ;
          vTimes.addElement( new java.util.Date() ) ;
        }
        else
        {
          db.reportError( ex, "CacheManager.cacheSearch()" ) ;
        }
        ex.printStackTrace(System.err);
      }
    }
    return retVal ;
  }

  public boolean updateHitCount(int imageCacheId, int hits)
  {
    int nextHit = hits + 1 ;
    try
    {
      Connection conn = db.getConnection(rseq.getDatabaseName()) ;
      Statement stmt = conn.createStatement() ;
      stmt.executeUpdate(
        "UPDATE image_cache SET hitCount = " + nextHit + ", currentDate = now()" +
        "  WHERE imageCacheId = " + imageCacheId) ;
      stmt.close() ;
      return true ;
    }
    catch(SQLException e)
    {
      e.printStackTrace(System.err) ;
      System.err.println("SQL statement fail for imagecacheId = " + imageCacheId + " with hits = " + hits) ;
      System.err.println("and database name = " + rseq.getDatabaseName()) ;
      System.err.print("UPDATE image_cache SET hitCount = nextHit, currentDate = now() ") ;
      System.err.println(" WHERE imageCacheId = " + imageCacheId) ;
      return false ;
    }
  }

  protected static void createTable(DBAgent db, String databaseName)
  {
    String createTableImageCache =
      "CREATE TABLE `image_cache` (\n" +
      "  `imageCacheId` int(10) unsigned NOT NULL auto_increment,\n" +
      "  `rid` int(10) unsigned NOT NULL,\n" +
      "  `fstart` bigint(20) unsigned NOT NULL,\n" +
      "  `fstop` bigint(20) unsigned NOT NULL,\n" +
      "  `cacheKey` varchar(32) NOT NULL,\n" +
      "  `fileName` varchar(64) NOT NULL,\n" +
      "  `currentDate` datetime NOT NULL,\n" +
      "  `hitCount` int(10) unsigned NOT NULL default 0,\n" +
      "  PRIMARY KEY (`imageCacheId`),\n" +
      "  UNIQUE KEY `segment` (`rid`,fstart,fstop,`cacheKey`),\n" +
      "  KEY `currentDate` (`currentDate`)\n" +
      ") ENGINE=MyISAM" ;

    Connection conn = null ;
    Statement stmt = null ;

    try
    {
      conn = db.getConnection( databaseName ) ;
      if(conn != null)
      {
        stmt = conn.createStatement() ;
        stmt.executeUpdate( createTableImageCache ) ;
        stmt.close() ;
      }
    }
    catch( Exception ex )
    {
      ex.printStackTrace(System.err) ;
      db.reportError( ex, "CacheManager.createTable()" ) ;
    }
  }

  protected static void createTable(DBAgent db, Refseq rseq)
  {
    if(rseq != null) // rseq often null when user hasn't selected a database yet (db==null is an error we want to see in log)
    {
      try
      {
        db.executeUpdate( rseq.getDatabaseName(), Refseq.createTableImageCache ) ;
      }
      catch( Exception ex )
      {
        ex.printStackTrace(System.err) ;
        db.reportError( ex, "CacheManager.createTable()" ) ;
      }
    }
  }

  protected void dropTable()
  {
    try
    {
      db.executeUpdate( rseq.getDatabaseName(), "DROP TABLE `image_cache`" ) ;
    }
    catch( Exception ex )
    {
      ex.printStackTrace(System.err);
      db.reportError( ex, "CacheManager.dropTable()" );
    }
  }

  public static boolean copyFile( File fsrc, File ftgt )
  {
    boolean retVal = false ;
    try
    {
      if(fsrc.exists())
      {
        FileInputStream fin = new FileInputStream( fsrc ) ;
        FileOutputStream fout = new FileOutputStream( ftgt ) ;
        byte[] buf = new byte[0x10000] ;
        int cnt = 0 ;
        while( (cnt = fin.read(buf)) > 0 )
        {
          fout.write( buf, 0, cnt ) ;
        }
        fin.close() ;
        fout.close() ;
        retVal = true ;
      }
    }
    catch( Exception ex )
    {
      ex.printStackTrace(System.err) ;
    }
    return retVal ;
  }

  public boolean retrieveFiles( File fgif, File fmap, File processedMap, File links, String typeOfImage)
  {
    boolean retVal = false ;
    if(fileName != null)
    {
      try
      {
        File cGif = new File( cacheDir, fileName + typeOfImage ) ;
        File cMap = new File( cacheDir, fileName + ".map" ) ;
        File finalMap = new File(cacheDir, fileName + "_final.map") ;
        File linkFile = new File(cacheDir, fileName + ".links") ;
        if( copyFile(cGif, fgif))
        {
          if(copyFile(cMap, fmap) )
          {
            if(copyFile(finalMap, processedMap))
            {
              if(copyFile(linkFile, links))
              {
                retVal = true ;
              }
            }
          }
        }
      }
      catch( Exception ex )
      {
        ex.printStackTrace(System.err) ;
        db.reportError( ex, "CacheManager.retrieveFiles()" ) ;
      }
    }
    return retVal ;
  }

  public boolean storeFiles( File fgif, File fmap, File processedMap, File links, String typeOfImage)
  {
    boolean retVal = false ;
    PreparedStatement pstmt = null ;
    String insertQueryStart =
      "INSERT IGNORE INTO image_cache " +
      "(rid, fstart, fstop, cacheKey, fileName, currentDate, hitCount) " +
      "VALUES (" ;
    String queryVariables = "?, ?, ?, ?, ?, " ;
    String queryEnd = "now(), 1)" ;
    String insertQuery =  insertQueryStart + queryVariables + queryEnd ;
    Connection conn = null ;
    String databaseName = null ;
    File cGif = null ;
    String fn = null ;
    File cMap = null ;
    File finalMap = null ;
    File linkFile = null ;
    File cInf = null ;

    if( cacheKey == null )
    {
      generateCacheKey() ;
    }

    if( cacheKey != null )
    {
      try
      {
        cGif = File.createTempFile("cache", typeOfImage, cacheDir) ;
        fn = cGif.getName() ;
        fileName = fn.substring(0, fn.length() - 4) ;
        cMap = new File(cacheDir, fileName + ".map") ;
        finalMap = new File(cacheDir, fileName + "_final.map") ;
        linkFile = new File(cacheDir, fileName + ".links") ;
        if(copyFile(fgif, cGif))
        {
          if(copyFile(fmap, cMap))
          {
            if(copyFile(processedMap, finalMap))
            {
              if(copyFile(links, linkFile))
              {
                cInf = new File(cacheDir, fileName + ".inf") ;
                FileOutputStream fos = new FileOutputStream(cInf) ;
                PrintStream out = new PrintStream(fos) ;
                out.println(this.characteristicStr) ;
                out.flush() ;
                fos.close() ;
                if(!checkIfTableExist("image_cache", db, rseq))
                {
                  createTable(db, rseq) ;
                }
                databaseName = rseq.getDatabaseName() ;
                conn = db.getConnection(databaseName) ;
                pstmt = conn.prepareStatement(insertQuery) ;
                pstmt.setInt(1, fref.getRid()) ;
                pstmt.setLong(2, from) ;
                pstmt.setLong(3, to) ;
                pstmt.setString(4, cacheKey) ;
                pstmt.setString(5, fileName) ;
                pstmt.executeUpdate() ;
                pstmt.close() ;
                retVal = true ;
              }
            }
          }
        }
      }
      catch(SQLException e)
      {
        System.err.println("Exception during cacheManager.storeFiles image insertion in database " + databaseName) ;
        System.err.println("The insert statement is ") ;
        System.err.println(new StringBuffer().append(insertQueryStart)
                .append(fref.getRid()).append(", ").append(from).append(", ")
                .append(", ").append(to).append(", '").append(cacheKey)
                .append("', '").append(fileName).append("', ").append(queryEnd).toString()) ;
        e.printStackTrace(System.err) ;
      }
      catch (FileNotFoundException e)
      {
        System.err.println("error during CacheManager.storeFiles file not found") ;
        e.printStackTrace(System.err) ;
      }
      catch (IOException e)
      {
        System.err.println("error during CacheManager.storeFiles IOException") ;
        e.printStackTrace(System.err) ;
      }
      catch( Exception ex )
      {
        System.err.println("error during CacheManager.storeFiles Generic Error") ;
        ex.printStackTrace(System.err) ;
      }
    }
    return retVal ;
  }

  public static boolean clearCache( DBAgent db, String dbName)
  {
    String query =  "SELECT DISTINCT(rs.databaseName) dbName FROM refseq rs, upload u, refseq2upload ru " +
                    "WHERE rs.refSeqId=ru.refSeqId AND u.uploadId=ru.uploadId " +
                    "AND u.databaseName = ? ";
    PreparedStatement pstmt = null;
    ResultSet rs = null;
    Connection mainGbConn = null;
    Connection conn = null;
    Statement stmt = null;

    try
    {
      if(!checkIfTableExist("image_cache", db, dbName, false))
      {
        createTable(db, dbName) ;
      }
      // Get Connection to main Genboree database
      mainGbConn = db.getNoCacheConnection(null) ;
      // Get affected database(s):
      pstmt = mainGbConn.prepareStatement(query) ;
      pstmt.setString(1, dbName) ;
      rs = pstmt.executeQuery() ;
      ArrayList dbNames = new ArrayList() ;
      while(rs.next())
      {
        dbNames.add(rs.getString("dbName")) ;
      }
      // Go through each anno database
      Iterator iter = dbNames.iterator() ;
      while(iter.hasNext())
      {
        // Get connection to that database
        String locDbName = (String)iter.next() ;
        conn = db.getNoCacheConnection( locDbName ) ;
        // Clear cache info
        stmt = conn.createStatement() ;
        stmt.executeUpdate( "DELETE FROM image_cache" ) ;
        File cacheDir = new File( baseCacheDir, dbName ) ;
        if(cacheDir.exists())
        {
          FileKiller.clearDirectory(cacheDir) ;
        }
      }
      return true ;
    }
    catch(Exception ex)
    {
      System.err.println("ERROR: CacheManager#clearCache(DBAgent, String). Query => " + query) ;
      System.err.println("       Exception detatils:\n" + ex.getMessage()) ;
      ex.printStackTrace(System.err) ;
    }
    finally
    {
      db.safelyCleanup(rs, pstmt, mainGbConn);
      db.safelyCleanup(null, stmt, conn);
    }
    return false ;
  }

  public static boolean clearCache( DBAgent db, Refseq rseq )
  {
    return clearCache( db, rseq.getDatabaseName(), rseq ) ;
  }
  public static boolean clearCache( DBAgent db, String dbName, Refseq rseq)
  {
    String qs =
      "SELECT distinct(rs.databaseName) databaseName FROM refseq rs, upload u, refseq2upload ru " +
      "WHERE rs.refSEqId=ru.refSeqId AND u.uploadId=ru.uploadId " +
      "AND u.databaseName = ? " ;
    try
    {
      if(!checkIfTableExist("image_cache", db, rseq))
      {
        createTable(db, rseq) ;
      }
      // Get Connection to main Genboree database
      Connection mainGbConn = db.getConnection() ;
      // Get affected database(s):
      PreparedStatement pstmt = mainGbConn.prepareStatement(qs) ;
      pstmt.setString(1,  dbName) ;
      ResultSet rs = pstmt.executeQuery() ;
      ArrayList dbNames = new ArrayList() ;
      while(rs.next())
      {
        dbNames.add(rs.getString("databaseName")) ;
      }
      rs.close() ;
      pstmt.close() ;
      db.closeConnection(mainGbConn) ;
      // Go through each anno database
      Iterator iter = dbNames.iterator() ;
      while(iter.hasNext())
      {
        // Get connection to that database
        String locDbName = (String)iter.next() ;
        Connection conn = db.getNoCacheConnection(locDbName) ;
        if(conn == null)
        {
          System.err.println("ERROR: CacheManager.clearCache(D,S,R) => can't get connection to user database that uses this template (which is being changed).\n" +
                             "       Trying to clear user database's image_cache but cant. Where did this database go or was it not deleted properly? Database name:\n" +
                             "       " + locDbName) ;
        }
        else
        {
          Statement stmt = conn.createStatement() ;
          stmt.executeUpdate( "DELETE FROM image_cache" ) ;
          stmt.close() ;
          db.closeConnection(conn) ;
          File cacheDir = new File( baseCacheDir, locDbName );
          if(cacheDir.exists())
          {
            FileKiller.clearDirectory(cacheDir) ;
          }
        }
      }
      return true ;
    }
    catch(Exception ex)
    {
      System.err.println("ERROR: CacheManager#clearCache(DBAgent, String, Refseq). Query => " + qs) ;
      System.err.println("       Exception detatils:\n" + ex.getMessage()) ;
      ex.printStackTrace(System.err) ;
    }
    return false ;
  }

  public static boolean removeCacheDir( Refseq rseq )
  {
    return removeCacheDir( rseq.getDatabaseName() ) ;
  }
  public static boolean removeCacheDir( String dbName )
  {
    boolean retVal = false ;
    try
    {
      File cacheDir = new File( baseCacheDir, dbName ) ;
      FileKiller.clearDirectory( cacheDir ) ;
      cacheDir.delete() ;
      retVal = true ;
    }
    catch( Exception ex )
    {
      ex.printStackTrace(System.err) ;
    }
    return retVal ;
  }

  // ------------------------------------------------------------------
  // Internal Helpers
  // ------------------------------------------------------------------
  protected boolean getSettingsFromDbForUser(Connection conn, String userId)
  {
    boolean retVal = false ;
    try
    {
      // - get full settings result table
      DbResourceSet dbSet = FtypeTable.getTrackSettings(conn, userId, this.trackNames) ;
      if(dbSet != null && dbSet.resultSet != null)
      {
        // - process ResultSet and extract settings into the this.trackSettings HashMap
        processSettingsResultSet(dbSet.resultSet) ;
      }
      // - clean up
      this.db.safelyCleanup(dbSet.resultSet, dbSet.stmt, null) ;
      retVal = true ;
    }
    catch(Exception ex)
    {
      System.err.println("ERROR: Couldn't get track settings from speciifc database for specific user. Message: " + ex.getMessage() + " ; Trace:") ;
      ex.printStackTrace(System.err) ;
      retVal = false ;
    }
    return retVal ;
  }

  protected boolean processSettingsResultSet(ResultSet rs)
  {
    boolean retVal = false ;
    try
    {
      //  Settings ResultSet columns: ftypeid | trackName | display | color | style | sortkey | url | description | label | linkmd5
      while(rs.next())
      {
        String trkName = rs.getString("trackName") ;
        HashMap<String, String> trkSettings = this.trackSettings.get(trkName) ;
        for(int ii=0; ii<trackSettingsColumns.length; ii++)
        {
          String colName = trackSettingsColumns[ii][0] ;
          String colValue = rs.getString(colName) ;
          if(colValue != null && colValue.length() > 0)
          {
            if(colName.equals("linkmd5"))
            {
              trkSettings.put(colName, trkSettings.get(colName) + " ; " + colValue) ; // accumulate all links found (well their md5 columns)
            }
            else
            {
              trkSettings.put(colName, colValue) ;
            }
          }
        }
      }
      retVal = true ;
    }
    catch(Exception ex)
    {
      System.err.println("ERROR: Couldn't process track settings result set. Error mesage: " + ex.getMessage() + " ; Trace:") ;
      ex.printStackTrace(System.err) ;
      retVal = false ;
    }
    return retVal ;
  }

  public static boolean checkIfTableExist(String tableName, DBAgent db, Refseq rseq)
  {
    return checkIfTableExist(tableName, db, rseq, true) ;
  }
  public static boolean checkIfTableExist(String tableName, DBAgent db, String databaseName)
  {
    return checkIfTableExist(tableName, db, databaseName, true);
  }
  public static boolean checkIfTableExist(String tableName, DBAgent db, Refseq rseq, boolean doCache)
  {
    boolean answer = false ;
    Connection conn = null ;
    Statement stmt = null ;
    ResultSet rs = null ;
    String databaseName = rseq.getDatabaseName() ;
    try
    {
      if( doCache )
      {
        conn = db.getConnection(databaseName) ;
      }
      else
      {
        conn = db.getNoCacheConnection(databaseName) ;
      }
      stmt = conn.createStatement() ;
      rs = stmt.executeQuery( "Show tables" ) ;
      String descripTable ;
      while( rs.next() && answer == false )
      {
        descripTable = rs.getString(1) ;
        if(descripTable.equalsIgnoreCase(tableName))
        {
          answer = true ;
        }
      }
      stmt.close() ;
    }
    catch( Exception ex )
    {
      ex.printStackTrace(System.err) ;
      System.err.println("Exception trying to check if cache table exist = " + databaseName) ;
    }
    finally
    {
      db.safelyCleanup( rs, stmt, conn ) ;
      return answer ;
    }
  }

  public static boolean checkIfTableExist(String tableName, DBAgent db, String databaseName, boolean doCache)
  {
    boolean answer = false ;
    Connection conn = null ;
    Statement stmt = null ;
    ResultSet rs = null ;
    try
    {
      if( doCache )
      {
        conn = db.getConnection(databaseName ) ;
      }
      else
      {
        conn = db.getNoCacheConnection( databaseName ) ;
      }

      stmt = conn.createStatement() ;
      rs = stmt.executeQuery( "Show tables" ) ;
      String descripTable ;
      while( rs.next() && answer == false )
      {
        descripTable = rs.getString(1) ;
        if(descripTable.equalsIgnoreCase(tableName))
        {
          answer = true ;
        }
      }
    }
    catch( Exception ex )
    {
      ex.printStackTrace(System.err) ;
      System.err.println("Exception trying to check if cache table exist = " + databaseName) ;
    }
    finally
    {
      db.safelyCleanup( rs, stmt, conn ) ;
      return answer ;
    }
  }
}
