package org.genboree.downloader;

import org.genboree.util.Util;
import org.genboree.util.TimingUtil;
import org.genboree.util.DirectoryUtils;
import org.genboree.util.GenboreeUtils;
import org.genboree.dbaccess.DBAgent;
import org.genboree.dbaccess.DbFref;
import org.genboree.dbaccess.DbFtype;
import org.genboree.dbaccess.GenboreeUpload;
import org.genboree.dbaccess.util.Fdata2Binning;

import java.io.*;
import java.sql.*;
import java.util.*;
import java.util.regex.Pattern;
import java.util.regex.Matcher;
import javax.servlet.http.HttpServletResponse;


public class AnnotationDownloader
{
    private static int NUM_RECS_BEFORE_PAUSE = 10000 ;
    private static int MS_TO_PAUSE = 2100 ;
    private static int MAX_NUM_FIDS = 2000;
    protected static final String[] HDRS = { "class", "name", "type", "subtype", "ref", "start", "stop", "strand", "phase", "score", "tstart", "tend", "attibuteComments", "sequence", "freeStyleComments" } ;
    protected static String HDRS_STR = null;
    protected static final String HDRS_STR_NEW = "#class\tname\ttype\tsubtype\tref\tstart\tstop\tstrand\tphase\tscore\ttstart\ttend\tattribute Comments\tsequence\tfreestyle comments" ;
    protected static final String HDRS_STR_OLD = "#class\tname\ttype\tsubtype\tref\tstart\tstop\tstrand\tphase\tscore\ttstart\ttend\tcomments\tsequence" ;
    private String from;
    private String to;
    private String entryPointName;
    private String filter;
    private String refseqId;
    private String databaseName;
    private String fileName = null;
    private int genboreeUserId = -1;
    private String[] frTables;
    private String[] trackNames;
    private String[] databaseNames;
    private HashMap databaseName2Idx = new HashMap();
    private PrintWriter printerOutStream;
    private HttpServletResponse response;
    private DBAgent db;
    private HashMap allFrefs ;
    private HashMap attNamesHash = new HashMap();
    private TimingUtil timer;
    private int flushCounter = 0;
    private Connection[] databaseConnections;
    private HashMap frefCache = new HashMap();             // WAS: ArrayList allEntryPointsInfo ; NOW: rid=>DbFref
    private HashMap frefNameCache = new HashMap() ;         // WAS: ArrayList allEntryPointNames ; NOW: refname=>DbFref
    private HashMap[] frefCacheByDbIdx ;
    private HashMap[] frefNameCacheByDbIdx ;
    private HashMap ftypeCache = new HashMap() ;            // ftypeid=>DbFtype
    private HashMap[] ftypeCacheByDbIdx ;
    private HashMap[] ftypeTrackNameCacheByDbIdx ;
    private HashMap[] attNames ;
    private HashMap ftypeTrackNameCache = new HashMap() ;   // type:subtype=>DbFtype
    private ArrayList[] frTrackFilter;
    private HashMap ftypeIdStatements;
    private HashMap featureTypeToGclasses;
    private boolean timmingMode = false ;
    private boolean printAssemblySectionAlso = false;
    protected static int limit = 10000;
    private HashMap bigListFids = null;
    protected boolean useVP = false;
    protected boolean fullAnnotationsOnly = false;
    protected boolean printAnnotationBracket = true;
    protected boolean printHeader = true;
    protected String fdata2MainQuery =  "SELECT ? databaseName, ? tableName,  gname, ftypeid, rid, " +
                "fstart, fstop, fstrand, " +
                "fphase, fscore,  ftarget_start, ftarget_stop, fid, displayCode, " +
                "LPAD(hex(displayColor), 6, '0') displayColor FROM fdata2 USE INDEX (primary)  WHERE ";
    protected String valuePairQuery = "SELECT fid2attribute.fid theKey, " +
            "fid2attribute.attNameId nameId, attValues.value theValue " +
            "FROM attValues, fid2attribute WHERE " +
            "attValues.attValueId = fid2attribute.attValueId AND " +
            "fid2attribute.fid in ( ";
    protected String fdata2MainQueryUsingFids = "SELECT ? databaseName, ? tableName,  gname, ftypeid, rid, " +
                                              "fstart, fstop, fstrand, " +
                "fphase, fscore,  ftarget_start, ftarget_stop, fid, displayCode, " +
                "LPAD(hex(displayColor), 6, '0') displayColor FROM fdata2 WHERE fid in (";

    protected String fidTextQuery ="SELECT fid, textType, text from fidText where fid in (";
    protected static int bufferSize = 4 * 1024 * 1024 ;
//    protected String verifyFidList = "^(?:\\d+\\s*,\\s*)*\\d+$"; //Does not work on java craches StackOverflow
    protected String verifyFidList = "^[0-9, \t]+$";
    protected Pattern compiledVerifyCommaSeparated = Pattern.compile(verifyFidList, 8); // 40 is 8 (Multiline) + 32(DOTALL)
    protected Matcher matchCommaSeparated = compiledVerifyCommaSeparated.matcher("empty");

    // ARJ: now uses fref and ftype caches
    // ARJ: now has less redundancy in methods and uses caches instead
    // ARJ: caches initialized here and anywhere they may be accessed
    //      but cache initialization is lazy: if already initialized, don't re-init
    public AnnotationDownloader( DBAgent myDb, int genboreeUserId,
                                 String myEntryPointName, String myFilter,
                                 String myRefseqId, String[] myTrackNames,
                                 String myFrom, String myTo, boolean toTime)
    {
        response = null;
        // Let's just set this timing on/off in one place, not 4: setTimmingMode(toTime);
        String[] userInfo = new String[3] ;
        userInfo[0] = "empty";
        userInfo[1] = "empty";
        userInfo[2] = "empty";
        long tempStart = 0;
        long tempEnd = 0;
        timer = new TimingUtil(userInfo);
        setDb(myDb);
        setRefseqId(myRefseqId);
        setGenboreeUserId( genboreeUserId );
        boolean useVP = GenboreeUtils.isRefSeqIdUsingNewFormat(myRefseqId);
        setUseVP(useVP);

        setNameShareDatabases();  // Also adds the main anno database to the list of db names

        setDatabaseConnections();
        allFrefs = new HashMap();

        // INIT CACHES:
        if(myEntryPointName == null)  // Do all the entrypoints
        { 
          initFrefCache();
        }
        // If there are multiple entrypoints seperated by commas
        else if(myEntryPointName.indexOf(",") > 0)
        {
          String[] epArr = myEntryPointName.split(",") ;
          
          for(int ii=0; ii<epArr.length; ii++) {
            setEntryPointName(epArr[ii]); // Set EP name under consideration
            initFrefCache(epArr[ii]);
          }
        }
        else
        {
            setEntryPointName(myEntryPointName); // Set EP name under consideration
            initFrefCache(myEntryPointName);
        }
        setFilter(myFilter);
        initFtypeCache() ;

        if(myEntryPointName != null && (myFrom == null || myTo == null))
        {
            if(myFrom == null)
                myFrom = "1";
            if(myTo == null)
                myTo = findMaxSize(myEntryPointName);
        }

        if(myFrom != null && myTo != null)
        {
            tempStart = Util.parseLong(myFrom, -1);
            tempEnd = Util.parseLong(myTo, -1);
            if(tempStart < 1)
            {
                tempStart = 1;
                myFrom = "" + tempStart;
            }

            if(myEntryPointName != null)
            {
                String entryPointSize = findMaxSize(myEntryPointName);
                long sizeEP = Util.parseLong(entryPointSize, -1L);
                if(tempEnd > sizeEP)
                {
                    myTo = entryPointSize;
                    tempEnd = sizeEP;
                }
            }
            // if entryPointName is empty I need to check limits for each entryPoint

            if(tempStart > tempEnd)
            {
                tempStart = tempEnd;
                tempEnd = tempStart;
                myFrom = "" + tempStart;
                myTo = "" + tempEnd;
            }
        }

        if(myFrom == null) myFrom = "1";

        setFrom(myFrom);
        setTo(myTo);
        setFrTables();
        setFtypeIdStatements();
        setAttNamesHash();
        setTrackNames(myTrackNames);  // Custom set of tracks, instead of all of them?
        setFrTrackFilter();
        setFeatureTypeToGclasses(db, refseqId);
        setFileName();
    }




    public AnnotationDownloader( DBAgent myDb,  String myRefseqId, int genboreeUserId, String[] myTrackNames, PrintWriter myPrinterOutStream)
    {
        response = null;
        String[] userInfo = new String[3] ;
        userInfo[0] = "empty";
        userInfo[1] = "empty";
        userInfo[2] = "empty";
        timer = new TimingUtil(userInfo);
        setDb(myDb);

        setRefseqId(myRefseqId);
        setGenboreeUserId( genboreeUserId );
        boolean useVP = GenboreeUtils.isRefSeqIdUsingNewFormat(myRefseqId);
        setUseVP(useVP);

        setNameShareDatabases();  // Also adds the main anno database to the list of db names

        setDatabaseConnections();
        allFrefs = new HashMap();
        initFrefCache() ;
        setFilter("b");
        setFrTables();
        initFtypeCache() ;
        setFtypeIdStatements();
        setAttNamesHash();
        setTrackNames(myTrackNames);
        setFrTrackFilter();
        setFeatureTypeToGclasses(db, refseqId);
        setFileName();
        printerOutStream = myPrinterOutStream;
    }


    public AnnotationDownloader( DBAgent myDb,  String myRefseqId, int genboreeUserId, PrintWriter myPrinterOutStream)
    {
        response = null;
        String[] userInfo = new String[3] ;
        userInfo[0] = "empty";
        userInfo[1] = "empty";
        userInfo[2] = "empty";
        timer = new TimingUtil(userInfo);
        setDb(myDb);

        setRefseqId(myRefseqId);
        setGenboreeUserId( genboreeUserId );
        boolean useVP = GenboreeUtils.isRefSeqIdUsingNewFormat(myRefseqId);
        setUseVP(useVP);

        setOnlyMainDatabase();

        setDatabaseConnections();
        allFrefs = new HashMap();
        initFrefCache() ;
        setFilter("b");
        setFrTables();
        initFtypeCache() ;
        setFtypeIdStatements();
        setAttNamesHash();
        setTrackNames("");
        setFrTrackFilter();
        setFeatureTypeToGclasses(db, refseqId);
        setFileName();
        printerOutStream = myPrinterOutStream;
    }


    public AnnotationDownloader( DBAgent myDb,  String myRefseqId, int genboreeUserId)
    {
        response = null;
        String[] userInfo = new String[3];
        userInfo[0] = "empty";
        userInfo[1] = "empty";
        userInfo[2] = "empty";
        timer = new TimingUtil(userInfo);
        setDb(myDb);
        setRefseqId(myRefseqId);
        setGenboreeUserId( genboreeUserId );
        boolean useVP = GenboreeUtils.isRefSeqIdUsingNewFormat(myRefseqId);
        setUseVP(useVP);

        setNameShareDatabases();

        setDatabaseConnections();
        allFrefs = new HashMap();
        // INIT CACHES:
        initFrefCache() ;
        initFtypeCache() ;
        setFilter(null);
        setFrTables();
        setFtypeIdStatements();
        setAttNamesHash();
        setTrackNames("");
        setFrTrackFilter();
        setFeatureTypeToGclasses(db, refseqId);
        setFileName();
    }

    public AnnotationDownloader( DBAgent myDb,  String databaseName, int genboreeUserId, String[] myTrackNames)
    {
        response = null;
        String[] userInfo = new String[3] ;
        userInfo[0] = "empty";
        userInfo[1] = "empty";
        userInfo[2] = "empty";
        timer = new TimingUtil(userInfo);
        setDb(myDb);

        setGenboreeUserId( genboreeUserId );
        boolean useVP = GenboreeUtils.isDatabaseUsingNewFormat(databaseName);
        setUseVP(useVP);
        setDatabaseName(databaseName);
        databaseNames = new String[1];
        databaseNames[0] = databaseName;
        for(int ii=0; ii<databaseNames.length; ii++)
        {
                databaseName2Idx.put(databaseNames[ii], new Integer(ii)) ;
        }
        setDatabaseConnections();
        allFrefs = new HashMap();
        initFrefCache();
        setFilter("b");
        initFtypeCache() ;
        setFrom("1");
        setTo(null);
        setFrTables();
        setFtypeIdStatements();
        setAttNamesHash();
        setTrackNames(myTrackNames);  // Custom set of tracks, instead of all of them?
        setFrTrackFilter();
        setFeatureTypeToGclasses( db );
        setFileName();
    }


    public static void setNUM_RECS_BEFORE_PAUSE(int NUM_RECS_BEFORE_PAUSE)
    {
        AnnotationDownloader.NUM_RECS_BEFORE_PAUSE = NUM_RECS_BEFORE_PAUSE;
    }
    public static void setMS_TO_PAUSE(int MS_TO_PAUSE)
    {
        AnnotationDownloader.MS_TO_PAUSE = MS_TO_PAUSE;
    }
    public static void setLimit(int limit)
    {
        AnnotationDownloader.limit = limit;
    }
    public boolean isPrintAssemblySectionAlso()
    {
        return printAssemblySectionAlso;
    }

  public int getGenboreeUserId()
  {
    return genboreeUserId;
  }

  public boolean isFullAnnotationsOnly()
  {
    return fullAnnotationsOnly;
  }

  public void setFullAnnotationsOnly( boolean fullAnnotationsOnly )
  {
    this.fullAnnotationsOnly = fullAnnotationsOnly;
  }

  public void setGenboreeUserId( int genboreeUserId )
  {
    this.genboreeUserId = genboreeUserId;
  }

  public void setPrintAnnotationBracket(boolean printAnnotationBracket)
    {
        this.printAnnotationBracket = printAnnotationBracket;
    }

  public void setPrintHeader(boolean printHeader)
  {
    this.printHeader = printHeader;
  }

    public void setPrintAssemblySectionAlso(boolean printAssemblySectionAlso)
    {
        this.printAssemblySectionAlso = printAssemblySectionAlso;
    }
    public boolean isTimmingMode()
    {
        return timmingMode;
    }
    public void setTimmingMode(boolean timmingMode)
    {
        this.timmingMode = timmingMode;
    }
    public boolean isUseVP() {
        return useVP;
    }
    public void setUseVP(boolean useVP) {
        this.useVP = useVP;
    }

    private void setFtypeIdStatements()
    {
        String ftypeIdQuery = "SELECT ftypeid FROM ftype where fmethod = ? and fsource = ? ";
        PreparedStatement ftypeIdQueryStatements;
        Connection currentConnection = null;
        String currentDatabase = null;

        ftypeIdStatements = new HashMap();

        for(int i = 0; i <databaseConnections.length; i++ )
        {
            currentConnection = databaseConnections[i];
            currentDatabase = databaseNames[i];
            try {
                ftypeIdQueryStatements = currentConnection.prepareStatement( ftypeIdQuery );
                ftypeIdStatements.put(currentDatabase, ftypeIdQueryStatements);
            } catch (SQLException ex) {
                System.err.println("An exception has been caught in the setFidTextStatments()");
                System.err.flush();
                db.reportError( ex, "SetFidTextStatements()" );
            }
        }
    }

   private void setAttNamesHash()
   {
        Connection currentConnection = null;
        for(int i = 0; i <databaseConnections.length; i++ )
        {
            currentConnection = databaseConnections[i];
            HashMap attName = GenboreeUpload.getAttNames( currentConnection );
            attNamesHash.put(i, attName);
        }
   }


    private void setFileName()
    {
        String nameToUse = GenboreeUtils.getFileName(refseqId) + ".lff" ;
        this.fileName = nameToUse;
    }
    
    private void setServletOutStream()
    {
        response.addDateHeader( "Expires", 0L );
        response.addHeader( "Cache-Control", "no-cache, no-store" );
        response.setContentType( "text/fasta" );
        response.setHeader( "Content-Disposition", "inline; filename=\"" + fileName + "\"" );
        response.setHeader("Accept-Ranges", "bytes");
        response.addHeader("status", "200");
        try
        {
          if(printerOutStream == null && response != null)
          {
            printerOutStream = response.getWriter() ;
          }
        }
        catch(IOException e)
        {
            System.err.println("Fail getting the printerOutStream");
            System.err.flush();
            return;
        }
    }
    private void setFrTrackFilter()
    {
        ArrayList[] myLocalTracks = null;

        if(databaseNames == null || databaseNames.length < 1)
            return;

        if(trackNames == null || trackNames.length < 1)
            return;

        myLocalTracks = new ArrayList[databaseNames.length];

        for(int ii = 0; ii < databaseNames.length; ii++)
        {
            myLocalTracks[ii] = fetchArrayListOfTypeIds(ii);
        }
        this.frTrackFilter = myLocalTracks;
        return ;
    }
    private void setDatabaseName( String databaseName )
    {
        this.databaseName = databaseName;
    }
    private String fetchMainDatabaseName( Connection conn ) // Main *anno* db name, not main Genboree database name...
    {
        String qs = null;
        String mainDatabase = null;
        Statement stmt = null;
        ResultSet rs = null;

        if( getRefseqId().equals("#") ) return null;

        qs = "SELECT databaseName FROM refseq where refSeqId = " +getRefseqId();
        try
        {
            stmt = conn.createStatement();
            rs = stmt.executeQuery( qs );
            if( rs.next() )
                mainDatabase = rs.getString("databaseName");
          stmt.close();
          rs.close();
        } catch( Exception ex )
        {
            System.err.println("Exception trying to find database for refseqId = " + getRefseqId());
            System.err.flush();
        }
        finally{
            return mainDatabase;
        }
    }
    private void setNameShareDatabases()
    {
        String mainDatabase = null;
        ArrayList listOfDatabases = null;
        Statement stmt = null;
        ResultSet rs = null;
        String qs = null;
        Connection conn = null;
        String[] rc = null;


        if(refseqId == null || refseqId.equals("#") )
        {
            databaseNames = null;
            return;
        }

        // This query is designed to get the name of  share databases
        qs = "SELECT u.databaseName databaseName "+
                "FROM upload u, refseq2upload ru, refseq r "+
                "WHERE u.uploadId=ru.uploadId AND r.refSeqId=ru.refSeqId AND "+
                "r.databaseName<>u.databaseName AND ru.refSeqId="+getRefseqId();

        try
        {
            conn = db.getConnection();
            mainDatabase = fetchMainDatabaseName(conn);
            setDatabaseName(mainDatabase);
            listOfDatabases = new ArrayList();
            if(mainDatabase == null )
            {
                databaseNames = null;
                return;
            }
            listOfDatabases.add( mainDatabase );
            stmt = conn.createStatement();
            rs = stmt.executeQuery( qs );
            while( rs.next() )
            {
                listOfDatabases.add( rs.getString("databaseName") );
            }
            stmt.close();
            rs.close();
            rc = (String[])listOfDatabases.toArray(new String[listOfDatabases.size()]);

        } catch( Exception ex )
        {
            db.reportError( ex, "Refseq.fetchDatabaseNames()" );
        }
        finally
        {
            databaseNames = rc;
            for(int ii=0; ii<databaseNames.length; ii++)
            {
                databaseName2Idx.put(databaseNames[ii], new Integer(ii)) ;
            }
        }

    }

  public String[] getDatabaseNames()
  {
    return databaseNames;
  }

  private void setOnlyMainDatabase()
  {
        String mainDatabase = null;
        Statement stmt = null;
        ResultSet rs = null;
        Connection conn = null;
        String[] rc = null;


        if(refseqId == null || refseqId.equals("#") )
        {
            databaseNames = null;
            return;
        }

        try
        {
            conn = db.getConnection();
            mainDatabase = fetchMainDatabaseName(conn);
            setDatabaseName(mainDatabase);
            if(mainDatabase == null )
            {
                databaseNames = null;
                return;
            }

        } catch( Exception ex )
        {
            db.reportError( ex, "Refseq.fetchDatabaseNames()" );
        }
        finally
        {
            databaseNames = new String[1];
            databaseNames[0] = mainDatabase;
            for(int ii=0; ii<databaseNames.length; ii++)
            {
                databaseName2Idx.put(databaseNames[ii], new Integer(ii)) ;
            }
        }

    }



    private void setDatabaseConnections()
    {
        int numberDatabases = 0;

        numberDatabases = databaseNames.length;
        databaseConnections = new Connection[numberDatabases];

        try
        {
            for(int i = 0; i < numberDatabases; i++)
            {
                databaseConnections[i] = db.getConnection( databaseNames[i]);
            }

        } catch( Exception ex ) {
            System.err.println("An Exception has been found during the generation of Connections");
            System.err.flush();
        }
    }
    private void initFrefCache()
    {
        Integer ridTmp ;
        String refnameTmp ;

        if( (frefCache.size() <= 0) || (frefNameCache.size() <= 0) ) // Only init if necessary.
        {
            if(databaseConnections == null || databaseConnections.length < 1)
                return; // No DB connection, can't do anything
    
            if(frefCacheByDbIdx == null)
            {
              frefCacheByDbIdx = new HashMap[databaseConnections.length] ;     // We know the # DBs at this point
            }
            if(frefNameCacheByDbIdx == null)
            {
              frefNameCacheByDbIdx = new HashMap[databaseConnections.length] ;
            }
            
            for(int ii = 0; ii < databaseConnections.length; ii++)
            {
                DbFref[] dbFrefs = DbFref.fetchAll(databaseConnections[ii]) ;
                allFrefs.put(ii, dbFrefs);
                for(int jj = 0; jj < dbFrefs.length; jj++)
                {
                    ridTmp = new Integer(dbFrefs[jj].getRid()) ;
                    refnameTmp = dbFrefs[jj].getRefname() ;
                    if( ! frefNameCache.containsKey(refnameTmp)) // Only add the fref if it's not already in there (local > shared)
                    {
                        frefCache.put( ridTmp, dbFrefs[jj]) ;
                        frefNameCache.put( dbFrefs[jj].getRefname(), dbFrefs[jj]) ;
                    }
                    // Per-db frefs
                    if(frefCacheByDbIdx[ii] == null)
                    {
                        frefCacheByDbIdx[ii] = new HashMap() ;
                    }
                    if(frefNameCacheByDbIdx[ii] == null)
                    {
                        frefNameCacheByDbIdx[ii] = new HashMap() ;
                    }
                    frefCacheByDbIdx[ii].put(ridTmp, dbFrefs[jj]) ;
                    frefNameCacheByDbIdx[ii].put(dbFrefs[jj].getRefname(), dbFrefs[jj]) ;
                }
            }
        }
        return ;
    }
    private void initFrefCache(String myEntryPointName)
    {
        Integer ridTmp ;
        String refnameTmp ;



        // In this case, we will update the cache for this EP name no matter what (i.e. not lazy init)
        if(databaseConnections == null || databaseConnections.length < 1)
            return; // No DB connection, can't do anything

        if(frefCacheByDbIdx == null)
        {
          frefCacheByDbIdx = new HashMap[databaseConnections.length] ;     // We know the # DBs at this point
        }
        if(frefNameCacheByDbIdx == null)
        {
          frefNameCacheByDbIdx = new HashMap[databaseConnections.length] ;
        }
        for(int ii = 0; ii < databaseConnections.length; ii++)
        {
            DbFref[] dbFrefs = DbFref.fetchAll(databaseConnections[ii]) ;
            allFrefs.put(ii, dbFrefs);
            DbFref dbFrefRec = DbFref.fetchByName( databaseConnections[ii], myEntryPointName ) ;
            if(dbFrefRec != null) // NOTE: the user can ADD eps to their database that aren't in the shared!! So MUST test this.
            {
              ridTmp = new Integer(dbFrefRec.getRid()) ;
              refnameTmp = dbFrefRec.getRefname() ;
              if( ! frefNameCache.containsKey(refnameTmp)) // Only add the fref if it's not already in there (local > shared)
              {
                  frefCache.put( ridTmp, dbFrefRec) ;
                  frefNameCache.put( dbFrefRec.getRefname(), dbFrefRec) ;
              }
              // Per-db frefs
              if(frefCacheByDbIdx[ii] == null)
              {
                  frefCacheByDbIdx[ii] = new HashMap() ;
              }
              if(frefNameCacheByDbIdx[ii] == null)
              {
                  frefNameCacheByDbIdx[ii] = new HashMap() ;
              }
              frefCacheByDbIdx[ii].put(ridTmp, dbFrefRec) ;
              frefNameCacheByDbIdx[ii].put(dbFrefRec.getRefname(), dbFrefRec) ;
            }
        }
        return ;
    }
    private void initFtypeCache()
    {
        Integer ftypeidTmp;
        if( (ftypeCache.size() <= 0) || (ftypeTrackNameCache.size() <= 0) ) // Only init if necessary.
        {
            if(databaseConnections == null || databaseConnections.length < 1)
                return; // No DB connections, can't do anything

            ftypeCacheByDbIdx = new HashMap[databaseConnections.length] ;     // We know the # DBs at this point
            ftypeTrackNameCacheByDbIdx = new HashMap[databaseConnections.length] ;

            for(int ii = 0; ii < databaseConnections.length; ii++)
            {


                DbFtype[] dbFtypes = DbFtype.fetchAll(databaseConnections[ii], databaseNames[ii], genboreeUserId) ;

                if(ftypeCacheByDbIdx[ii] == null)
                {
                    ftypeCacheByDbIdx[ii] = new HashMap() ;
                }
                if(ftypeTrackNameCacheByDbIdx[ii] == null)
                {
                    ftypeTrackNameCacheByDbIdx[ii] = new HashMap() ;
                }
                for(int jj = 0; jj < dbFtypes.length; jj++)
                {
                    ftypeidTmp = new Integer(dbFtypes[jj].getFtypeid()) ;
                    ftypeCache.put(ftypeidTmp, dbFtypes[jj]) ;
                    ftypeCacheByDbIdx[ii].put(ftypeidTmp, dbFtypes[jj]) ;
                    ftypeTrackNameCache.put(dbFtypes[jj].toString(), dbFtypes[jj]) ;
                    ftypeTrackNameCacheByDbIdx[ii].put(dbFtypes[jj].toString(), dbFtypes[jj]);
                }
            }
        }
        return ;
    }
    private void setFrTables()
    {
        Vector v = null;
        String[] tables = null;

        if( filter == null )
            setFilter("b");
        else
            filter = filter.toLowerCase();

        v = new Vector();
        if( filter.indexOf('b')>=0 ) v.addElement( "fdata2" );
        if( filter.indexOf('c')>=0 ) v.addElement( "fdata2_cv" );
        if( filter.indexOf('g')>=0 ) v.addElement( "fdata2_gv" );
        if( v.size() < 1 )
        {
            this.frTables = null;
            return;
        }

        tables = new String[ v.size() ];
        v.copyInto( tables );

        this.frTables = tables;
    }
    public void setResponse(HttpServletResponse response)
    {
        this.response = response;
    }
    public void setDb(DBAgent db)
    {
        this.db = db;
    }
    public String getRefseqId()
    {
        return refseqId;
    }
    public void setRefseqId(String myRefseqId)
    {
        this.refseqId = myRefseqId;
    }
    public void setTrackNames(String[] trackNames)
    {
        this.trackNames = trackNames;
    }
    public void setTrackNames(String allTracksTogether)
    {
        String[] myTracks = allTracksTogether.split(",");
        Arrays.sort( myTracks );
        this.trackNames = myTracks;
    }
    public void setFilter(String filter)
    {
        this.filter = filter;
    }
    private void setEntryPointName(String entryPointName)
    {
        this.entryPointName = entryPointName;
    }
    private String getTo()
    {
        return to;
    }
    private void setTo(String to)
    {
        this.to = to;
    }
    private String getFrom()
    {
        return from;
    }
    private void setFrom(String from)
    {
        this.from = from;
    }

    private void setFeatureTypeToGclasses(DBAgent db )
    {
        String[] ftypes = null;
        String[] uploads = null;
        String[]fmethodfsource = null;
        String[] classNames = null;

        ftypes = this.trackNames;
        uploads = databaseNames;
        featureTypeToGclasses = new HashMap();

        for(int i = 0; i < ftypes.length; i++)
        {
            String ftype = ftypes[i];
            if(ftype == null) continue;
            fmethodfsource = ftype.split(":");
            if(fmethodfsource == null || fmethodfsource.length < 2)
                continue;
            String fmethod = fmethodfsource[0];
            String fsource = fmethodfsource[1];
            if(fmethod != null && fsource != null)
                classNames = GenboreeUpload.fetchClassesInFtypeId(db, uploads, fmethod, fsource);
            if(classNames != null)
                featureTypeToGclasses.put( ftypes[i], classNames );
        }
        return;
    }


    private void setFeatureTypeToGclasses(DBAgent db, String myRefseqId )
    {
        String[] ftypes = null;
        String[] uploads = null;
        String[]fmethodfsource = null;
        String[] classNames = null;

        ftypes = GenboreeUpload.fetchAllTracksFromUploads(db, myRefseqId , genboreeUserId);
        uploads = GenboreeUpload.returnDatabaseNames(db, myRefseqId );
        featureTypeToGclasses = new HashMap();

        for(int i = 0; i < ftypes.length; i++)
        {
            String ftype = ftypes[i];
            if(ftype == null) continue;
            fmethodfsource = ftype.split(":");
            if(fmethodfsource == null || fmethodfsource.length < 2)
                continue;
            String fmethod = fmethodfsource[0];
            String fsource = fmethodfsource[1];
            if(fmethod != null && fsource != null)
                classNames = GenboreeUpload.fetchClassesInFtypeId(db, uploads, fmethod, fsource);
            if(classNames != null)
                featureTypeToGclasses.put( ftypes[i], classNames );
        }
        return;
    }
    // ARJ: cleaned up
    private String findMaxSize(String myEntryPointName)
    {
        // Make sure frefCache is initialized
        initFrefCache() ; // not wasteful, does 'lazy' initialization
        String retVal = null ;

        if(frefNameCache.containsKey(myEntryPointName))
        {
            DbFref frefRec = (DbFref) frefNameCache.get(myEntryPointName) ;
            retVal = frefRec.getRlength() ;
        }
        return retVal ;
    }
    // ARJ: cleaned up
    private ArrayList fetchArrayListOfTypeIds(int currDbIdx)
    {
        ArrayList listOfTypeIds = new ArrayList();
        DbFtype ftypeRec ;

        // Make sure ftypeCache is initialized
        initFtypeCache() ; // not wasteful, does 'lazy' initialization

        // Make sure we have ftypeTrackNameCache for this db index, and grab them accordingly if so
        if( (ftypeTrackNameCacheByDbIdx != null) &&
                (ftypeTrackNameCacheByDbIdx.length > currDbIdx) &&
                (ftypeTrackNameCacheByDbIdx[currDbIdx] != null) )
        {
            // Go through each track in trackNames (the ones the user wants) and
            // grab it's record from the ftype cache for this db, if it is there.
            // If it's not there, skip to next because it's probably from the other databases.
            for(int ii=0; ii<trackNames.length; ii++)
            {
                ftypeRec = (DbFtype)ftypeTrackNameCacheByDbIdx[currDbIdx].get(trackNames[ii]) ;
                if(ftypeRec != null)
                {
                    listOfTypeIds.add(new Integer(ftypeRec.getFtypeid())) ;
                }
            }
        }
        return listOfTypeIds;
    }
    private String[] retrieveClassesName(DBAgent db, String ftype, String fsubtype)
    {
        String ftypeKey = null;
        String[] gclasses = null;

        if(ftype == null|| fsubtype == null)
            return null;

        if(featureTypeToGclasses == null)
            return null ;

        ftypeKey = ftype + ":" + fsubtype;
        gclasses = (String[])featureTypeToGclasses.get(ftypeKey);

        return gclasses;
    }
    private String retrieveClassName(DBAgent db, String ftype, String fsubtype)
    {
        String gclass = null;
        String[] gclasses = null;

        if(ftype == null || fsubtype == null)
            return null;

        gclasses = retrieveClassesName(db, ftype, fsubtype);

        if(gclasses == null || gclasses.length == 0)
            return null;
        gclass = gclasses[0];

        return gclass;
    }
    private String retrieveExtraClassName(DBAgent db, String fmethod, String fsource)
    {
        String[] gclasses = null;
        int sizeOfClasses = 0;
        StringBuffer gclassBuffer = null;

        if(fmethod == null|| fsource == null) return null;

        gclasses = retrieveClassesName(db, fmethod, fsource);

        if(gclasses == null)
            return null;

        sizeOfClasses = gclasses.length;

        if(sizeOfClasses < 2)
            return null;

        gclassBuffer = new StringBuffer( 200 );
        gclassBuffer.append(" aHClasses=");
        for(int ii = 1; ii < sizeOfClasses; ii++)
        {
            gclassBuffer.append(gclasses[ii]);
            if(ii < (sizeOfClasses -1))
                gclassBuffer.append(",");
        }
        gclassBuffer.append("; ");
        return gclassBuffer.toString();
    }
    // ARJ: bit more efficient, but not too clean yet
    private int transformAnnotations(ResultSet currentMainResultSet, HashMap fidTextResultsHash, HashMap fidValuePairHash, boolean printHeader )
    {
        String freeStyleComments = null;

        String comments = null;
        String sequence = null;
        String fidStr = null;
        String[] gClasses ;
        String gClassName = null;
        String gname = null;
        String ftype = null;
        String strand = null;
        String ftypeidStr;
        int ftypeid ;
        String fsubtype = null;
        String phase = null;
        String databaseToUse = null;
        String score = null;
        String fstart = null;
        String fstop = null;
        String qstart = null;
        String qend = null;
        String ridStr = null ;
        int rid ;
        String ref = null;
        String theCurrentTableName = null;
        String extraClasses = null;
        DbFtype currFtype = null ;
        DbFref currFref = null ;
        boolean needPrintComments = false;
        boolean needPrintSequence = false;
        boolean needPrintQstart = false;
        boolean needPrintQend = false;
        boolean needPrintSeqEnds = false;
        String retrieveFidTextCommentsKey = null;
        String retrieveFidTextSequenceKey = null;
        int localCounter = 0;
        int displayCode = -1;
        int displayColor = -1;
        String color = null;
        String disCode = null;

        if(currentMainResultSet == null)
        {
            System.err.println((new java.util.Date()).toString() + "ERROR: AnnotationDownloader#transformAnnotations() => Error on function Refseq.tansformAnnotations the result set is null");
            System.err.flush();
            return -1;
        }

        if(isUseVP())
            HDRS_STR = HDRS_STR_NEW;

        else
            HDRS_STR = HDRS_STR_OLD;



        if(printHeader)
        {
          if(printAnnotationBracket)
          {
              printerOutStream.println( "[annotations]" );
          }
          if(this.printHeader)
          {
            printerOutStream.println( HDRS_STR );
          }
        }

        try
        {

            // ResultSet rs: databaseName, tableName, gname, ftypeid, rid, fstart, fstop, fstrand, fphase, fscore, ftarget_start, ftarget_stop, fid
            while( currentMainResultSet.next() )
            {
                needPrintComments = false;
                needPrintSequence = false;
                needPrintQstart = false;
                needPrintQend = false;
                needPrintSeqEnds = false;
                databaseToUse = currentMainResultSet.getString("databaseName");
                int databaseIdx = ((Integer)databaseName2Idx.get(databaseToUse)).intValue() ;
                // theCurrentTable name is to know the table name because
                // fdata2_gv and fdata2_cv should not retrieve FidText table
                theCurrentTableName = currentMainResultSet.getString("tableName");

                // ------------------------------------------------------------
                // PHASE 1 - collect data for columns
                // ------------------------------------------------------------
                // STEP 1 - get type and subtype
                ftypeidStr = currentMainResultSet.getString("ftypeid");
                if( Util.isEmpty(ftypeidStr) )
                    continue;
                ftypeid = Util.parseInt(ftypeidStr, -1) ;
                if( (ftypeid == 1) || (ftypeid == 2) || (ftypeid == -1)) // SKIP: "Component:Chromsome" and "Supercomponent:Sequence" and ERROR
                {
                    continue;
                }
                else // ftypeid probably ok
                {
                    currFtype = (DbFtype)ftypeCacheByDbIdx[databaseIdx].get(new Integer(ftypeid)) ;
                    if(currFtype != null)
                    {
                        ftype = currFtype.getFmethod() ;
                        fsubtype = currFtype.getFsource() ;
                    }
                    else // error, but how to see it?
                    {
                        ftype = "UNKNOWN" ;
                        fsubtype = "UNKNOWN" ;
                    }
                }

                // STEP 2 - get gname
                gname = currentMainResultSet.getString("gname");
                if( Util.isEmpty(gname) )
                    continue;

                // STEP 3 - get class (too many method calls before...now gets directly from variable)
                gClasses = (String[])featureTypeToGclasses.get(currFtype.toString()) ;
                if( (gClasses == null) || (gClasses.length < 1) )  // error, but how to see it?
                {
                    gClassName = "UNKNOWN";
                }
                else
                {
                    gClassName = gClasses[0] ;
                }

                // STEP 4 - get extra classes
                extraClasses = retrieveExtraClassName(db, ftype, fsubtype);

                // STEP 5 - get fstart
                fstart = currentMainResultSet.getString("fstart");
                if( Util.isEmpty(fstart) )
                    continue;

                // STEP 6 - get fstop
                fstop = currentMainResultSet.getString("fstop");
                if( Util.isEmpty(fstop) )
                    continue;

                // STEP 7 - get entrypoint name
                ridStr = currentMainResultSet.getString("rid") ;
                if( Util.isEmpty(ridStr) )
                    continue;
                rid = Util.parseInt(ridStr, -1) ;
                currFref = (DbFref)frefCacheByDbIdx[databaseIdx].get(new Integer(rid)) ;
                if(currFref != null)
                {
                    ref = currFref.getRefname() ;
                }
                else // error, but how to see it?
                {
                    ref = "UNKNOWN" ;
                }

                // STEP 8 - get strand
                strand = currentMainResultSet.getString("fstrand");
                if( Util.isEmpty(strand) )
                    strand = "+"; // Default is now +, not .

                // STEP 9 - get phase
                phase = currentMainResultSet.getString("fphase");
                if( Util.isEmpty(phase) )
                    phase = ".";

                // STEP 10 - get score
                // ARJ: this should be FIXED to give something sensible in text output...
                score = currentMainResultSet.getString("fscore");
                if( Util.isEmpty(score) )
                    score = "1.0";

                // STEP 11 - get qstart
                qstart = currentMainResultSet.getString("ftarget_start");
                if( Util.isEmpty(qstart) )
                    qstart = ".";
                else
                    needPrintQstart = true;

                // STEP 12 - get qend
                qend = currentMainResultSet.getString("ftarget_stop");
                if( Util.isEmpty(qend) )
                    qend = ".";
                else
                    needPrintQend = true;

                if(qstart.equalsIgnoreCase("0") && qend.equalsIgnoreCase("0") )
                    qstart = qend = ".";

                String temp05 = currentMainResultSet.getString("displayColor");
                if(temp05 != null)
                    color = "annotationColor=#" + temp05.toUpperCase() + "; ";

// TODO         displayCode = currentMainResultSet.getInt("displayCode");

                if(needPrintQstart || needPrintQend)
                    needPrintSeqEnds = true;

                // STEP 13 - get comments and sequence, if appropriate and if any
                fidStr = currentMainResultSet.getString("fid");
                comments = null;
                sequence = null;
                freeStyleComments = null;
                if( ! (theCurrentTableName.equalsIgnoreCase("fdata2_gv") ||
                        theCurrentTableName.equalsIgnoreCase("fdata2_cv")) )
                {
                    retrieveFidTextCommentsKey = fidStr + "-t";
                    retrieveFidTextSequenceKey = fidStr + "-s";
                    sequence = (String)fidTextResultsHash.get(retrieveFidTextSequenceKey);

                    if(isUseVP())
                    {
                        freeStyleComments = (String)fidTextResultsHash.get(retrieveFidTextCommentsKey);
                        comments = (String)fidValuePairHash.get(fidStr);
                    }
                    else
                    {
                        comments =  (String)fidTextResultsHash.get(retrieveFidTextCommentsKey);
                        freeStyleComments = null;
                    }

                }
                if(color != null)
                {
                    if(comments == null)
                        comments = color;
                    else
                        comments = comments + color;

                }

                if(comments != null)
                {
                    needPrintComments = true;
                    if(extraClasses != null)
                    {
                        comments = comments + extraClasses;
                    }
                }
                else
                {
                    if(extraClasses != null)
                    {
                        needPrintComments = true;
                        comments = extraClasses;
                    }
                    else
                    {
                        comments = ".";
                    }
                }

                if(sequence != null)
                    needPrintSequence = true;
                else
                    sequence = ".";

                if(freeStyleComments != null)
                {
                    if(!needPrintComments)
                    {
                        needPrintComments = true;
                    }
                    if(!needPrintSequence)
                        needPrintSequence = true;
                }

                if(needPrintComments || needPrintSequence)
                    needPrintSeqEnds = true;

                // ------------------------------------------------------------
                // PHASE 2 - print data directly to stream, flush when done with record
                // ------------------------------------------------------------
                printerOutStream.print(gClassName);
                printerOutStream.print( "\t" );
                printerOutStream.print(gname);
                printerOutStream.print( "\t" );
                printerOutStream.print(ftype);
                printerOutStream.print( "\t" );
                printerOutStream.print(fsubtype);
                printerOutStream.print( "\t" );
                printerOutStream.print(ref);
                printerOutStream.print( "\t" );
                printerOutStream.print(fstart);
                printerOutStream.print( "\t" );
                printerOutStream.print(fstop);
                printerOutStream.print( "\t" );
                printerOutStream.print(strand);
                printerOutStream.print( "\t" );
                printerOutStream.print(phase);
                printerOutStream.print( "\t" );
                printerOutStream.print(score);
                if(needPrintSeqEnds)
                {
                    printerOutStream.print( "\t" );
                    printerOutStream.print(qstart);
                    printerOutStream.print( "\t" );
                    printerOutStream.print(qend);
                    if(needPrintComments || needPrintSequence)
                    {
                        printerOutStream.print( "\t" );
                        printerOutStream.print(comments);
                    }
                    if(needPrintSequence)
                    {
                        printerOutStream.print( "\t" );
                        printerOutStream.print(sequence);
                    }
                    if(freeStyleComments != null)
                    {
                        printerOutStream.print( "\t" );
                        printerOutStream.print(freeStyleComments);
                    }
                }
                printerOutStream.println();
                if(flushCounter > NUM_RECS_BEFORE_PAUSE)
                {
                    printerOutStream.flush();
                    try { Util.sleep(MS_TO_PAUSE) ; } catch(Exception ex) { }
                    flushCounter = 0;
                }
                flushCounter++;
                localCounter++;
            }

        } catch (SQLException e) {
          System.err.println("Exception during the printing of records");
            e.printStackTrace();  //To change body of catch statement use File | Settings | File Templates.
        }

        return localCounter;
    }
    public void printChromosomes(HttpServletResponse myResponse)
    {
        setResponse(myResponse);
        setServletOutStream();
        printChromosomes();
    }

    public void printChromosomes(String fileName)
    {
        PrintWriter fout = null;
        try
        {
            if(fileName != null)
                fout = new PrintWriter( new FileWriter(fileName) );
        } catch (IOException e)
        {
            e.printStackTrace(System.err);
        }
        printerOutStream = new PrintWriter(fout);
        printChromosomes();
    }

    public void printChromosomes(PrintWriter myPrinterOutStream)
    {
        printerOutStream = myPrinterOutStream;
        printChromosomes();
    }


    public void printChromosomes(Writer writer)
    {
        printerOutStream = new PrintWriter(writer) ;
        printChromosomes();
    }


    public void printChromosomes(PrintStream ios)
    {
        printerOutStream = new PrintWriter(ios);
        printChromosomes();
    }


    public static HashMap fetchHashMapWithEPINFO(String myRefSeqId, int genboreeUserId)
    {
        HashMap entryPointInfo = null;

        if(myRefSeqId == null)
            return null;

        String tempDatabaseName = GenboreeUtils.fetchMainDatabaseName( myRefSeqId );
        if(tempDatabaseName != null)
        {
            AnnotationDownloader currentDownload = new AnnotationDownloader( DBAgent.getInstance(),  myRefSeqId, genboreeUserId);
            currentDownload.setPrintAssemblySectionAlso(false);
            entryPointInfo = currentDownload.fetchAllEntryPointNameSizes();
        }
        else
        {
            System.err.println("unable to find a database for RefseqId = " + myRefSeqId);
            System.err.flush();
        }
        return entryPointInfo;
    }
    // ARJ: cleaned up a bit
    private HashMap fetchAllEntryPointNameSizes() // this is used by external classes, unfortunately ARJ: cleaned up a bit --Manuel -> Where ??
    {
        // Init cache (it won't waste time--does nothing if not already initialized)
        initFrefCache() ;

        HashMap allEntryPointNameSizes = new HashMap();

        // Iterate over the frefCache and fill this in.
        Iterator frefIter = frefCache.entrySet().iterator() ;
        while(frefIter.hasNext())
        {
            String[] sizeAry = new String[2] ;
            Map.Entry frefPair = (Map.Entry) frefIter.next() ;
            DbFref frefRec = (DbFref)frefPair.getValue() ;
            sizeAry[0] = frefRec.getRlength() ;
            sizeAry[1] = frefRec.getGname() ;
            allEntryPointNameSizes.put(frefRec.getRefname(), sizeAry) ;
        }
        return allEntryPointNameSizes;
    }
    // ARJ: cleaned up a bit
    private void printChromosomes()
    {
        // Init frefCache (not wasteful, it does 'lazy' initialization)
        initFrefCache() ;


        try
        {
            printerOutStream.println( "[reference_points]" );

            printerOutStream.println( "#id\tclass\tlength" );
            printerOutStream.flush();

            Iterator frefIter = frefCache.keySet().iterator() ;
            while(frefIter.hasNext())
            {
                DbFref frefRec = (DbFref) frefCache.get(frefIter.next()) ;
                printerOutStream.println( frefRec.getRefname() + "\t" + frefRec.getGname() + "\t" + frefRec.getRlength() );
            }
            printerOutStream.println();
            printerOutStream.flush();

            if(isPrintAssemblySectionAlso())
            {
                printerOutStream.println( "[assembly]" );
                printerOutStream.println( "#id\tstart\tend\tclass\tname\ttstart\ttend" );

                frefIter = frefCache.keySet().iterator() ;
                while(frefIter.hasNext())
                {
                    DbFref frefRec = (DbFref) frefCache.get(frefIter.next()) ;
                    printerOutStream.println( frefRec.getRefname() + "\t1\t" + frefRec.getRlength() + "\t" + frefRec.getGname() + "\t" + frefRec.getRlength() + "\t1\t" + frefRec.getGname() );
                }
                printerOutStream.println();
                printerOutStream.flush();
            }
        }
        finally
        {
        }

        return;
    }

    private HashMap returnFidValuePairInfo(String databaseName, ArrayList fids )
    {
        HashMap attNames= null;
        HashMap fidValuePairHash = null;
        String theInStatement = null;
        Connection currentConnection = null;
        fidValuePairHash = new HashMap();
        Statement currentFidTextStatement = null;
        ResultSet currentFidTextResultSet = null;
        String fidTextKey = null;
        int attNameId = -1;
        String attValue =  null;
        String attName = null;
        Integer databaseIdx = null;
        int index = 0;
        StringBuffer fidTextValue = new StringBuffer();
        String previousValue = null;
        StringBuffer localValuePairQuery = new StringBuffer();


        if(fids == null || fids.size() < 1) return null;

        databaseIdx = (Integer)databaseName2Idx.get(databaseName) ;
        index = databaseIdx.intValue();
        currentConnection = databaseConnections[index];
        attNames = (HashMap)attNamesHash.get( index );

        theInStatement = DirectoryUtils.join(fids, ",");

        localValuePairQuery.append(valuePairQuery).append(theInStatement).append( ")");

        try //This loop will fill up the Hash table with the fidText vaules for the
                // rid ftypeid  I set it own try-catch to distinguish between this action and the
                // query for fdata2
        {
            attNameId = -1;
            currentFidTextStatement = currentConnection.createStatement();
            currentFidTextResultSet = currentFidTextStatement.executeQuery(localValuePairQuery.toString());

            while( currentFidTextResultSet.next() )
            {
                fidTextValue.setLength( 0 );
                fidTextKey = currentFidTextResultSet.getString("theKey");
                attNameId = currentFidTextResultSet.getInt("nameId");
                attValue = currentFidTextResultSet.getString("theValue");
                attName = (String)attNames.get( attNameId );

                fidTextValue.append(attName).append("=").append( attValue).append(";");

                if(fidValuePairHash.containsKey(fidTextKey))
                {
                    previousValue = (String)fidValuePairHash.get(fidTextKey);
                    fidTextValue.append(" ").append( previousValue );
                }
                fidValuePairHash.put(fidTextKey, fidTextValue.toString());
            }
            currentFidTextStatement.close();
            currentFidTextResultSet.close();

        } catch (SQLException e3) {
            e3.printStackTrace(System.err);
        }
        finally
        {
            return fidValuePairHash;
        }
    }

    private HashMap returnFidTextInfo(String databaseName, ArrayList fids )
    {
        HashMap fidTextResultsHash = null;
        String theInStatement = null;
        Connection currentConnection = null;
        fidTextResultsHash = new HashMap();
        Statement currentFidTextStatement = null;
        ResultSet currentFidTextResultSet = null;
        StringBuffer fidTextQueryLocal = new StringBuffer();
        Integer databaseIdx = null;
        int index = 0;
        String textType = null;
        String fidTextValue = null;
        int fid = -1;
        StringBuffer fidTextKey = new StringBuffer();


        if(fids == null || fids.size() < 1) return null;

        databaseIdx = (Integer)databaseName2Idx.get(databaseName) ;
        index = databaseIdx.intValue();
        currentConnection = databaseConnections[index];

        theInStatement = DirectoryUtils.join(fids, ",");

        fidTextQueryLocal.append(fidTextQuery).append(theInStatement).append( ")");

        try //This loop will fill up the Hash table with the fidText vaules for the
                // rid ftypeid  I set it own try-catch to distinguish between this action and the
                // query for fdata2
        {
            currentFidTextStatement = currentConnection.createStatement();
            currentFidTextResultSet = currentFidTextStatement.executeQuery(fidTextQueryLocal.toString());

            while( currentFidTextResultSet.next() )
            {
                fidTextKey.setLength( 0 );
                fid = currentFidTextResultSet.getInt("fid");
                textType = currentFidTextResultSet.getString( "textType" );
                fidTextValue =  currentFidTextResultSet.getString("text");
                fidTextKey.append( fid ).append( "-" ).append( textType );

                if(fidTextValue != null && !fidTextValue.equals("null"))
                {
                    fidTextResultsHash.put(fidTextKey.toString(), fidTextValue);
                }
            }
            currentFidTextStatement.close();
            currentFidTextResultSet.close();
        }
        catch (SQLException e3)
        {
            e3.printStackTrace(System.err);
        }
        finally
        {
            return fidTextResultsHash;
        }
    }

    public void downloadAnnotations(HttpServletResponse myResponse)
    {
        setResponse(myResponse);
        setServletOutStream();
        downloadAnnotations();
    }

    public void downloadAnnotations(PrintWriter myPrinterOutStream)
    {
        printerOutStream = myPrinterOutStream;
        downloadAnnotations();
    }

    public void downloadAnnotations(String fileName)
    {
        PrintWriter fout = null;
        try
        {
            if(fileName != null)
                fout = new PrintWriter( new FileWriter(fileName) );
        } catch (IOException e)
        {
            e.printStackTrace(System.err);
        }
        printerOutStream = new PrintWriter(fout);
        downloadAnnotations();
    }

    public void downloadAnnotations(Writer writer)
    {
        printerOutStream = new PrintWriter(writer) ;
        downloadAnnotations();
    }
    public void downloadAnnotations(PrintStream ios)
    {
        printerOutStream = new PrintWriter(ios);
        downloadAnnotations();
    }
    private void downloadAnnotations()
    {
        boolean firstDatabase = true;
        ResultSet currentMainResultSet = null;
        ArrayList trackIds = null;
        PreparedStatement currentMainQuery = null;
        String currentTable = null;
        String currentDatabase = null;
        DbFref[] currentrefs = null;
        Connection currentConnection = null;
        int currentRid = -1 ;
        int currentFtypeid = -1;
        HashMap fidTextsHash = null;
        HashMap fidValuePairHash = null;
        ArrayList fids = null;
        String currentFid = null;

        fids = new ArrayList();
        // Init frefCache (not wasteful, it does 'lazy' initialization)
        initFrefCache() ;
        // Init ftypeCache (not wasteful, it does 'lazy' initialization)
        initFtypeCache() ;

        if( printerOutStream == null )
        {
            System.err.println((new java.util.Date()).toString() + ": AnnotationDownloader#downloadAnnotations(): Fail getting the printerOutStream line 1628");
            System.err.flush();
            return;
        }

        // In here I have to test if the rid has bin set and if the start and stop are null then start = 1 and stop = chrSize
        //otherwhise the start and stop are used


        // LOOP 1: each database
        for(int i = 0; i < databaseNames.length; i++ )
        {
            currentDatabase = databaseNames[i];
            currentConnection = databaseConnections[i];
            currentrefs = (DbFref[])allFrefs.get( i );
            useVP = GenboreeUtils.isDatabaseUsingNewFormat(currentDatabase);
            trackIds =  frTrackFilter[i];  // Get the trackIds specific to this database
            for(int a = 0; a < frTables.length; a++)
            {
                currentTable = frTables[a];
                // LOOP 3: each Ftypeid for this database (from the list of ones we want)
                for(int bb=0; bb < trackIds.size(); bb++)
                {
                    // If annotations are HDHV
                    // Need to use the hdhv library.
                  
                  
                    // LOOP 4: each Rid (keeps all data for current track together, at least)
                    currentFtypeid = ((Integer)trackIds.get(bb)).intValue();
//                    System.err.println("currentFtypeId = "+ currentFtypeid + " Used Memory: " + Util.commify(MemoryUtil.usedMemory()/1024/1024) + "MB<br>") ;
                    Iterator ridIter = frefCacheByDbIdx[i].keySet().iterator() ;
                    while(ridIter.hasNext())
                    {
                        currentRid = ((Integer)ridIter.next()).intValue();
                        DbFref tempFref = (DbFref)frefCacheByDbIdx[i].get(new Integer(currentRid));

                        int annotationCounter = 0;
                        int numberOfLoops = 0;
                        int annotationsProcessed = -1;
                        long tempEnd = -1;
                        long end = -1;
                        String start = null;
                        long start_long = -1;
                        String stop = null;
                        long stop_long = -1;
                        StringBuffer fdata2Query = new StringBuffer();
                        String minMaxStatement = null;

                        start = getFrom();
                        stop = getTo();
                        if(stop == null)
                        {
                            stop = tempFref.getRlength();
                        }
                        else
                        {
                            end = Util.parseLong(stop, -1);
                            tempEnd = Util.parseLong(tempFref.getRlength(), -1);
                            if(end == -1)
                            {
                                stop = tempFref.getRlength();
                            }
                            else if(end > tempEnd)
                            {
                                stop = tempFref.getRlength();
                            }
                        }
                        start_long = Util.parseLong(start, -1);
                        stop_long = Util.parseLong(stop, -1);
                        do {
                            try
                            {
                                fdata2Query.setLength( 0 );
                                fdata2Query.append(fdata2MainQuery);

                                if(isFullAnnotationsOnly())
                                  fdata2Query.append(" rid = ").append( currentRid ).append( " AND ( fstart >= " ).append( start_long ).append( " AND fstop <= " ).append( stop_long ).append( " ) AND " );
                                else
                                {
                                  minMaxStatement = Fdata2Binning.generateBinningClause( currentConnection, currentrefs, start_long, stop_long, null, currentRid );
                                  fdata2Query.append( minMaxStatement ).append(" AND ");
//                                  System.err.println("the minMaxStatement is \n" + minMaxStatement + " AND ");
                                }
                                fdata2Query.append( "ftypeId = ? limit ?, ?");
//                                System.err.println( "the query is " + fdata2Query.toString() );
                                currentMainQuery = currentConnection.prepareStatement( fdata2Query.toString() );
                                currentMainQuery.setString(1, currentDatabase);
                                currentMainQuery.setString(2, currentTable);
                                currentMainQuery.setInt(3, currentFtypeid );
                                currentMainQuery.setInt(4, annotationCounter);
                                currentMainQuery.setInt(5, limit);
                                // ResultSet: databaseName, tablename, gname, ftypeid, rid, fstart, fstop, fstrand, fphase, fscore, ftarget_start, ftarget_stop, fid
                                currentMainResultSet = currentMainQuery.executeQuery();
                            }
                            catch(Exception ex)
                            {
                                System.err.println((new java.util.Date()).toString() + "ERROR: AnnotationDownloader#downloadAnnotations(): setting up the main Query failed with exception: " + ex.toString() ) ;
                            }

                            try
                            {
                                fids.clear();
                                while( currentMainResultSet.next() )
                                {
                                    currentFid = currentMainResultSet.getString("fid");
                                    fids.add(currentFid);
                                }
                                currentMainResultSet.beforeFirst();
                            } catch (SQLException e)
                            {
                                System.err.println((new java.util.Date()).toString() + "ERROR: AnnotationDownloader#downloadAnnotations(): making fids failed with exception: " + e.toString() ) ;
                            }

                            fidTextsHash = returnFidTextInfo(currentDatabase, fids);
                            fidValuePairHash = returnFidValuePairInfo(currentDatabase, fids);
                            annotationsProcessed = transformAnnotations(currentMainResultSet, fidTextsHash, fidValuePairHash, firstDatabase);
                            try
                            {
                            currentMainResultSet.close();
                            }
                            catch(SQLException e)
                            {
                                System.err.println((new java.util.Date()).toString() + "ERROR: AnnotationDownloader#downloadAnnotations(): closing the connection: " + e.toString() ) ;
                            }

                            numberOfLoops ++;
                            if(annotationsProcessed >= limit)
                                annotationCounter = limit * numberOfLoops;
                            else
                                annotationCounter = 0;

                            // May be a good time to add a pause
                            //  try { Util.sleep(MS_TO_PAUSE) ; } catch(Exception ex) { }
                        }
                        while(annotationCounter > 0 );


                        firstDatabase = false;
                    }
                }
            }
        }

        // timer.writeTimingReport(System.err);
        if( printerOutStream != null )
        {
            printerOutStream.flush();
            printerOutStream.close();
            printerOutStream = null;
        }
//        System.err.println("Ending of downloadAnnotations Used Memory: " + Util.commify( MemoryUtil.usedMemory()/1024/1024) + "MB<br>") ; 


      for(int i = 0; i < this.databaseConnections.length; i++ )
      {
        try
        {
          databaseConnections[i].close();
        } catch( SQLException e )
        {
          System.err.println("Exception -->The end of the downloadAnnotations closing the connection");
          e.printStackTrace(System.err);
        }

      }
      
        return  ;
    }

  private HashMap getFidsFromGnames( String gnames, int databaseIndex )
  {
    String defaultQuery = "select fid from fdata2 where ftypeid in (";
    StringBuffer fidQuery = new StringBuffer();
    String querySecondPart = ") AND gname in ";
    HashMap fidHash = null;
    String[] myGnames = null;
    HashMap gnameHash = new HashMap();
    String typeids = null;
    PreparedStatement pstmt = null;
    ResultSet rs = null;
    Connection conn = null;
    HashMap tracksHash = new HashMap();

    if((frTrackFilter[databaseIndex]).size() < 1) return null;

    fidQuery.append( defaultQuery );
    for(int i = 0; i < (frTrackFilter[databaseIndex]).size(); i++)
    {
      String currentFtypeId = "" + ((Integer)(frTrackFilter[databaseIndex]).get(i)).intValue();
      tracksHash.put( currentFtypeId, null );
    }
    typeids = GenboreeUtils.getCommaSeparatedKeys( tracksHash );
    tracksHash.clear();
    fidQuery.append( typeids ).append( querySecondPart );

    if( gnames != null )
    {
      myGnames = gnames.split( "," );
      for( int a = 0; a < myGnames.length; a++ )
      {
        String temp = Util.urlDecode( myGnames[ a ] ) ;
        gnameHash.put( temp, null );
      }
    }

    fidQuery.append( GenboreeUtils.makeSqlSetString( gnameHash.size()));

    int maxSize = fidQuery.length() + (gnameHash.size() * 3) + gnames.length();

    if( maxSize >= bufferSize )
    {
      System.err.println( "Error detected when reading the gnames the string is too big " + maxSize + " the limit is " + bufferSize );
      System.exit( 66 );
    }

    try
    {
      fidHash = new HashMap();
      conn = databaseConnections[ databaseIndex ];
      pstmt = conn.prepareStatement(fidQuery.toString());

      int counter = 1;
      for( Object key : gnameHash.keySet() )
      {
        pstmt.setString( counter, (String)key);
        counter++;
      }
      rs = pstmt.executeQuery();
      while( rs.next() )
      {
        fidHash.put( rs.getString( "fid" ), null );
      }
      rs.close();
      pstmt.close();

    } catch( Exception ex )
    {
      System.err.println( "Exception on method AnnotationDownloader#getFidsFromGnames" );
      ex.printStackTrace( System.err );
    }

    return fidHash;
  }




  private void downloadAnnotationsUsingFids(HashMap fidHash)
  {
    String fidString = GenboreeUtils.getCommaSeparatedKeys( fidHash );
    downloadAnnotationsUsingFids(fidString);
  }

  private HashMap validateFids( String fidString)
  {
    HashMap fidsValidated = null;
    String[] fidList = null;

    if(fidString == null || fidString.length() < 1) return null;

    fidsValidated = new HashMap();
    fidList = fidString.split( "," );

    for(int i = 0; i < fidList.length; i++)
    {
      int valueFid = Util.parseInt( fidList[i], -1 );
      if(valueFid > 0)
      {
        fidsValidated.put("" + valueFid, null);
      }
    }

    return fidsValidated;
  }


  private String getCommaSeparatedKeys( HashMap hashWithKeys )
    {
      StringBuffer ftypeIdsBuffer = null;
      int counterT = 0;

      if(hashWithKeys == null || hashWithKeys.size() < 1)
        return null;

      ftypeIdsBuffer = new StringBuffer( 200 );
      for( Object key : hashWithKeys.keySet() )
      {
        ftypeIdsBuffer.append( key );
        counterT += 1;
        if( counterT < hashWithKeys.size() )
          ftypeIdsBuffer.append( "," );
      }
      return ftypeIdsBuffer.toString();
    }

  private void downloadAnnotationsUsingFids( String fidString )
  {
    boolean firstDatabase = true;
    ResultSet currentMainResultSet = null;
    PreparedStatement currentMainQuery = null;
    String currentTable = "fdata2";
    HashMap fidTextsHash = null;
    HashMap fidValuePairHash = null;
    ArrayList fids = null;
    String currentDatabase = null;
    Connection currentConnection = null;


    matchCommaSeparated.reset( fidString );

    if( !matchCommaSeparated.matches() )
    {
      System.err.println( "Error detected when reading the fidString the string should be a comma separated list" +
              "of fids, no extra characters are allowed" );
      System.exit( 45 );
    }

    if( fidString.length() >= bufferSize )
    {
      System.err.println( "Error detected when reading the fidString the string is too big " + fidString.length() + " the limit is " + bufferSize );
      System.exit( 65 );
    }

    fids = new ArrayList();


    if( printerOutStream == null )
    {
      System.err.println( ( new java.util.Date() ).toString() + ": AnnotationDownloader#downloadAnnotationsUsingFids(): Fail getting the printerOutStream lime 1874" );
      System.err.flush();
      return;
    }

      // In here I have to test if the rid has bin set and if the start and stop are null then start = 1 and stop = chrSize
      //otherwhise the start and stop are used

        // LOOP 1: each database
        for(int i = 0; i < databaseNames.length; i++ )
        {

          currentDatabase = databaseNames[i];
          currentConnection = databaseConnections[i];
          int annotationCounter = 0;
          int numberOfLoops = 0;
          int annotationsProcessed = -1;

          StringBuffer fdata2Query = new StringBuffer();
          String minMaxStatement = null;


          do {
              try
              {
                fdata2Query.setLength( 0 );
                fdata2Query.append(fdata2MainQueryUsingFids);

                fdata2Query.append( fidString ).append(") ").append(" limit ?, ?");

                  currentMainQuery = currentConnection.prepareStatement( fdata2Query.toString() );
                  currentMainQuery.setString(1, currentDatabase);
                  currentMainQuery.setString(2, currentTable);
                  currentMainQuery.setInt(3, annotationCounter);
                  currentMainQuery.setInt(4, limit);
                  // ResultSet: databaseName, tablename, gname, ftypeid, rid, fstart, fstop, fstrand, fphase, fscore, ftarget_start, ftarget_stop, fid
                  currentMainResultSet = currentMainQuery.executeQuery();
              }
              catch(Exception ex)
              {
                  System.err.println((new java.util.Date()).toString() + "ERROR: AnnotationDownloader#downloadAnnotations(): setting up the main Query failed with exception: " + ex.toString() ) ;
              }

              try
              {
                  fids.clear();
                  while( currentMainResultSet.next() )
                  {
                        String currentFid = currentMainResultSet.getString("fid");
                        fids.add(currentFid);
                  }
                  currentMainResultSet.beforeFirst();
                } catch (SQLException e)
                {
                    System.err.println((new java.util.Date()).toString() + "ERROR: AnnotationDownloader#downloadAnnotations(): making fids failed with exception: " + e.toString() ) ;
                }

                fidTextsHash = returnFidTextInfo(currentDatabase, fids);
                fidValuePairHash = returnFidValuePairInfo(currentDatabase, fids);
                annotationsProcessed = transformAnnotations(currentMainResultSet, fidTextsHash, fidValuePairHash, firstDatabase);
                try
                {
                currentMainResultSet.close();
                }
                catch(SQLException e)
                {
                    System.err.println((new java.util.Date()).toString() + "ERROR: AnnotationDownloader#downloadAnnotations(): closing the connection: " + e.toString() ) ;
                }
                numberOfLoops ++;
                if(annotationsProcessed >= limit)
                    annotationCounter = limit * numberOfLoops;
                else
                    annotationCounter = 0;

                // May be a good time to add a pause
                //  try { Util.sleep(MS_TO_PAUSE) ; } catch(Exception ex) { }
          }
          while(annotationCounter > 0 );
          firstDatabase = false;

        }

      return  ;
  }

  private void closeOpenConnection()
  {
          // timer.writeTimingReport(System.err);
      if( printerOutStream != null )
      {
          printerOutStream.flush();
         printerOutStream.close();
          printerOutStream = null;
      }

    for(int i = 0; i < this.databaseConnections.length; i++ )
    {
      try
      {
        databaseConnections[i].close();
      } catch( SQLException e )
      {
        System.err.println("Exception -->The end of the downloadAnnotations closing the connection");
        e.printStackTrace(System.err);
      }

    }
  }


  
    public static void printUsage(){
        System.err.println("usage: AnnotationDownloader ");
        System.err.println("" +
                "-r refSeqId\n" +
                "-u genboreeUserId\n" +
                "-m TrackNames(comma separated or if you need all the tracks use the 'all' as an special keyword)\n" +
                "Optional [\n" +
                "\t-z { print all the track names and quit}\n" +
                "\t-i { entryPoints only }\n" +
                "\t-h { print chromosome header section }\n" +
                "\t-f fileName\n" +
                "\t-n EntryPointName\n" +
                "\t-l limit queries (default value = " + AnnotationDownloader.limit + ")\n" +
                "\t-t tableNames(b=fdata2, c=fdata2_cv, g=fdata2_gv)\n" +
                "\t-s start\n" +
                "\t-e end\n" +
                "\t-x { full annotations only mode (no binning on query) }\n" +
                "\t-b do not print annotation bracket\n" +
                "\t-c do not print annotation's header\n" +
                "\t-a list of fids(comma separated)\n" +
                "\t-A name of the file with the list of fids(comma separated)\n" +
                "\t-g list of gnames(comma separated)\n" +
                "\t-G name of the file with the list of gnames(comma separated)\n" +
                "\t-w wait time or sleep in milliseconds (default value = " + AnnotationDownloader.MS_TO_PAUSE + ")\n" +
                "\t-p number of records to pause (default value = " + AnnotationDownloader.NUM_RECS_BEFORE_PAUSE + ")\n" +
                "]\n");
        return;
    }
    public static void main(String[] args) throws Exception
    {
        String myEntryPointName = null;
        String myFilter = null;
        String myRefSeqId = null;
        String myTrackNames = null;
        String myFrom = null;
        String myTo = null;
        String myFile = null;
        String[] myTracks = null;
        DBAgent myDb = null;
        AnnotationDownloader currentDownload = null;
        PrintWriter fout = null;
        boolean printTracksAndQuit = false;
        boolean wantTime = false;
        boolean entryPointysOnly = false;
        boolean printHeaders = false;
        int limits = -1;
        boolean modifyLimits = false;
        int msToPause = -1;
        boolean modifymsToPause = false;
        int numberRecordsToSleep = -1;
        boolean modifyNumberRecordsToSleep = false;
        String bufferString = null;
        boolean diseablePrintingAnnBracket = false;
        boolean fullAnnotationOnlyMode = false;
        boolean diseablePrintHeader = false;
        int genboreeUserId = -1;
        String listFids = null;
        String listOfGnames = null;
        String fileWithFids = null;
        String fileWithGnames = null;



        if(args.length <= 3 )
        {
            printUsage();
            System.exit(-1);
        }

        if(args.length >= 4)
        {

            for(int i = 0; i < args.length; i++ )
            {

                if(args[i].compareToIgnoreCase("-n") == 0){
                    i++;
                    if(args[i] != null){
                        myEntryPointName = args[i];
                    }
                }
                else if(args[i].compareToIgnoreCase("-t") == 0)
                {
                    i++;
                    if(args[i] != null){
                        myFilter = args[i];
                    }
                }
                else if(args[i].compareTo("-a") == 0)
                {
                    i++;
                    if(args[i] != null){
                        listFids = args[i];
                    }
                }
                else if(args[i].compareTo("-A") == 0)
                {
                    i++;
                    if(args[i] != null)
                    {
                        fileWithFids = args[i];
                    }
                  if(fileWithFids != null)
                  {
                    listFids = GenboreeUtils.readFileIntoMemory(fileWithFids);
                  }
                }
                else if(args[i].compareTo("-g") == 0)
                {
                  i++;
                  if(args[i] != null){
                    listOfGnames = args[i];
                  }
                }
                else if(args[i].compareTo("-G") == 0)
                {
                  i++;
                  if(args[i] != null)
                  {
                    fileWithGnames = args[i];
                  }
                  if(fileWithGnames != null)
                  {
                    listOfGnames = GenboreeUtils.readFileIntoMemory(fileWithGnames);
                  }
                }
                else if( args[ i ].compareToIgnoreCase( "-u" ) == 0 )
                {
                  i++;
                  if( args[ i ] != null )
                    genboreeUserId = Util.parseInt( args[ i ], -1 );
                }
                else if( args[ i ].compareToIgnoreCase( "-i" ) == 0 )
                {
                  entryPointysOnly = true;
                }
                else if(args[i].compareToIgnoreCase("-h") == 0)
                {
                    printHeaders = true;
                }
                else if(args[i].compareToIgnoreCase("-z") == 0){
                    printTracksAndQuit = true;
                    myTrackNames = "all";
                }
                else if(args[i].compareToIgnoreCase("-d") == 0){
                    wantTime = true;
                }
                else if(args[i].compareToIgnoreCase("-b") == 0){
                    diseablePrintingAnnBracket = true;
                }
                else if(args[i].compareToIgnoreCase("-x") == 0){
                  fullAnnotationOnlyMode = true;
                }
                else if(args[i].compareToIgnoreCase("-c") == 0){
                  diseablePrintHeader = true;

                }
                else if(args[i].compareToIgnoreCase("-r") == 0){
                    i++;
                    if(args[i] != null){
                        myRefSeqId =args[i];
                    }
                }
                else if(args[i].compareToIgnoreCase("-l") == 0)
                {
                    i++;
                    if(args[i] != null)
                    {
                        bufferString = args[i];
                        limits = Util.parseInt(bufferString , -1);
                        if(limits > -1)
                            modifyLimits = true;
                    }
                }
                else if(args[i].compareToIgnoreCase("-w") == 0)
                {
                    i++;
                    if(args[i] != null)
                    {
                        bufferString = args[i];
                        msToPause = Util.parseInt(bufferString , -1);
                        if(msToPause > -1)
                            modifymsToPause = true;
                    }
                }
                else if(args[i].compareToIgnoreCase("-p") == 0)
                {
                    i++;
                    if(args[i] != null)
                    {
                        bufferString = args[i];
                        numberRecordsToSleep = Util.parseInt(bufferString , -1);
                        if(numberRecordsToSleep > -1)
                            modifyNumberRecordsToSleep = true;
                    }
                }
                else if(args[i].compareToIgnoreCase("-m") == 0){
                    i++;
                    if(args[i] != null){
                        myTrackNames = args[i];
                    }
                }
                else if(args[i].compareToIgnoreCase("-s") == 0){
                    i++;
                    if(args[i] != null){
                        myFrom = args[i];
                    }
                }
                else if(args[i].compareToIgnoreCase("-e") == 0){
                    i++;
                    if(args[i] != null){
                        myTo = args[i];
                    }
                }
                else if(args[i].compareToIgnoreCase("-f") == 0){
                    i++;
                    if(args[i] != null){
                        myFile = args[i];
                    }
                }

            }

        }
        else
        {
            printUsage();
            System.exit(-1);
        }


        if(myRefSeqId == null)
        {
          printUsage();
          System.exit(-1);
        }

        if(myTrackNames == null && !printTracksAndQuit  && listFids == null)
        {
            printUsage();
            System.exit(-1);
        }

        myDb = DBAgent.getInstance();

        if(myTrackNames != null)
        {
            if(myTrackNames.equalsIgnoreCase("all"))
            {
                myTracks = GenboreeUpload.fetchAllTracksFromUploads(myDb, myRefSeqId, genboreeUserId );
            }
            else
            {
                myTracks = myTrackNames.split(",");
                for(int a = 0; a < myTracks.length; a++)
                {
                     myTracks[a] = Util.urlDecode( myTracks[a]);
                }
            }
        }
        else
        {
            myTracks = GenboreeUpload.fetchAllTracksFromUploads(myDb, myRefSeqId, genboreeUserId );
        }


      if( printTracksAndQuit )
      {
        HashMap tracksWithCount = GenboreeUpload.fetchAllTracksFromUploadsWithCounts( myDb, myRefSeqId, genboreeUserId, false );
        for( Object key : tracksWithCount.keySet() )
        {
          String myTrack = ( String )key;
          System.out.println( myTrack + "\t" + Util.urlEncode( myTrack ) + "\t" + tracksWithCount.get( key ) );
        }
        System.exit(0);
        }

      if(myFile != null)
        fout = new PrintWriter( new FileWriter(myFile) );
      else
        fout = new PrintWriter(System.out);


        if(entryPointysOnly)
        {
            currentDownload = new AnnotationDownloader( myDb, myRefSeqId, genboreeUserId);
            currentDownload.printChromosomes(fout);
            fout.close();
            System.exit(0);
        }



        if(listFids != null)
        {
          currentDownload = new AnnotationDownloader( myDb,  myRefSeqId, genboreeUserId, fout);
          currentDownload.downloadAnnotationsUsingFids(listFids);
          currentDownload.closeOpenConnection();
          fout.close();
          System.exit(0);
        }

      if(listOfGnames != null)
        {

          currentDownload = new AnnotationDownloader( myDb,  myRefSeqId, genboreeUserId, myTracks, fout);
          String[] databaseNames = currentDownload.getDatabaseNames();
          for(int z = 0; z < databaseNames.length; z++)
          {
            HashMap hashOfFids = currentDownload.getFidsFromGnames( listOfGnames, z );
            if(hashOfFids != null && hashOfFids.size() > 0)
            currentDownload.downloadAnnotationsUsingFids(hashOfFids);
          }
          currentDownload.closeOpenConnection();
          fout.close();
          System.exit(0);
        }

        currentDownload = new AnnotationDownloader(myDb, genboreeUserId, myEntryPointName,
                myFilter, myRefSeqId, myTracks, myFrom, myTo, wantTime);



         if(diseablePrintingAnnBracket)
            currentDownload.setPrintAnnotationBracket(false);

        if(fullAnnotationOnlyMode)
            currentDownload.setFullAnnotationsOnly( true );

        if(diseablePrintHeader)
          currentDownload.setPrintHeader( false );


        if(modifyLimits)
            AnnotationDownloader.setLimit(limits);

        if(modifymsToPause)
            AnnotationDownloader.setMS_TO_PAUSE(msToPause);

        if(modifyNumberRecordsToSleep)
            AnnotationDownloader.setNUM_RECS_BEFORE_PAUSE(numberRecordsToSleep);

        if(printHeaders)
          currentDownload.printChromosomes(fout);
//      System.err.println("Before the method of downloadAnnotations Used Memory: " + Util.commify( MemoryUtil.usedMemory()/1024/1024) + "MB<br>") ;
        currentDownload.downloadAnnotations(fout);
//      System.err.println("After the method of downloadAnnotations Used Memory: " + Util.commify( MemoryUtil.usedMemory()/1024/1024) + "MB<br>") ;

        fout.close();

        System.exit(0);
    }
}
