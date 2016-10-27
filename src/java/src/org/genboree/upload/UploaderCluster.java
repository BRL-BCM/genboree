package org.genboree.upload ;

import org.genboree.util.* ;
import java.util.* ;
import java.io.* ;
import java.sql.Connection ;
import org.genboree.dbaccess.util.* ;
import org.genboree.dbaccess.* ;

public class UploaderCluster
{
  // Genboree DB, Config, etc
  protected DBAgent db = null ;
  protected String databaseHost = null;
  protected String propFile = Constants.LFFMERGER_MULTILEVEL ;
  protected int sleepTime = LffConstants.uploaderSleepTime ;
  protected int maxInsertSize = LffConstants.defaultNumberOfInserts ;
  // Default upload config (what to do, what not to do)
  protected String fileFormat = "lff" ;
  protected String genboreeUserId = null ;
  protected String genboreeGroupId = null ;
  protected String databaseName = null ;
  protected String refName = null ;
  protected String refseqId ;
  protected boolean toMerge = true ;
  protected boolean ignoreEntryPoints = false ;
  protected boolean deleteAnnotations = false ;
  protected boolean deleteEntryPoints = false ;
  protected boolean deleteAnnotationsAndFtypes = false ;
  protected boolean cleanOldTables = false ;
  protected HashMap extraOptions = null ;
  // Default state of uploader
  protected int errorLevel ;
  protected String lineNumber = "1" ;
  protected String gmtStartDate = null ;
  protected String gmtEndDate = null ;
  protected int numberOfRecords = -1 ;
  protected int numberOfParsedRecords = -1 ;
  protected int numberOfInsertions = -1 ;
  protected int numberOfUpdates = -1 ;
  protected long approxNumberRecords = -1 ;
  protected boolean missingInfo = false ;
  protected String[] listOfForbiddenTracks = null ;
  protected boolean debug = false ;
  protected StringBuffer debugInfo = null ;
  protected String timingInfo = null ;
  // File locations, out/err buffers, etc
  protected String inputFile = null ;
  protected String refseqFile = null ;
  protected StringBuffer stderr ;
  protected StringBuffer stdout ;
  protected File formattedFile = null;
  protected File origFileName = null;

  // This Uploader does NOT do:
  // - File decompression
  // - Lockfile permission
  // - Email sending
  // - Validate LFF etc
  // - Compress results/intermediaries
// - Task table updates
  public UploaderCluster(String refseqId, String inputFile, String userId, String inputFormat)
  {
		System.err.println("Starting UploaderCluster()...one userId") ;
    setInputFile( inputFile ) ;
    // Database sql name, user's db name etc:
		setRefSeqId( refseqId ) ;
		setDatabaseName( refseqId ) ;
		setDatabaseHost( getDatabaseName(), false) ;
    this.refName = RefSeqTable.getRefSeqNameByRefSeqId(refseqId, this.db) ;
    // User & group ids:
    setGenboreeUserId( userId );
    setGenboreeGroupId( GenboreeUtils.fetchGroupId( getRefSeqId(), getGenboreeUserId(), false ) );

    // Initialize:
    initializeStringBuffers() ;
    setFileFormat(inputFormat) ;

    // Make sure we have all we need to proceed:
    if(getGenboreeUserId() == null || getRefSeqId() == null)
    {
      missingInfo = true ;
    }
  }

  public void initializeStringBuffers()
  {
    stderr = new StringBuffer( 200 );
    stdout = new StringBuffer( 200 );
  }

  // ------------------------------------------------------------------
  // GETTERS & SETTERS
  // ------------------------------------------------------------------
  public String getDatabaseHost()
  {
    return databaseHost;
  }

  public void setDatabaseHost( String databaseName)
  {
    setDatabaseHost(databaseName, true);
  }

  public void setDatabaseHost(String databaseName, boolean doCache)
  {
    Connection conn = null;
    DBAgent db = null;
    try
    {
      db = DBAgent.getInstance();
      this.db = db ;
      if(doCache)
      {
        conn = db.getConnection() ;
      }
      else
      {
        conn = db.getNoCacheConnection(null) ;
      }

      this.databaseHost = Database2HostTable.getHostForDbName( databaseName, conn ) ;
    }
    catch( Exception ex )
    {
      System.err.println("ERROR: Exception, unable to generate a connection in Uploader#setDatabaseHost." ) ;
      ex.printStackTrace(System.err) ;
    }
    finally
    {
      db.safelyCleanup( null, null, conn ) ;
    }
  }

  public String getDatabaseName()
  {
    return databaseName ;
  }

  public void setDatabaseName( String refSeqId )
  {
    this.databaseName = GenboreeUtils.fetchMainDatabaseName( refSeqId, false );
  }

  public int getSleepTime()
  {
    return sleepTime;
  }

  public void setSleepTime( int sleepTime )
  {
    this.sleepTime = sleepTime;
  }

  public long getApproxNumberRecords()
  {
    return approxNumberRecords;
  }

  public void setApproxNumberRecords( String inputFile )
  {
    this.approxNumberRecords = BigDBOpsLockFile.estimateNumLFFRecsInFile( inputFile );
  }

  public String getTimingInfo()
  {
    return timingInfo;
  }

  public HashMap getExtraOptions()
  {
    return extraOptions;
  }

  public void setExtraOptions( HashMap extraOptions )
  {
    this.extraOptions = extraOptions;
  }

  public void setMaxInsertSize( int maxInsertSize )
  {
    this.maxInsertSize = maxInsertSize;
  }

  public int getMaxInsertSize()
  {
    return maxInsertSize;
  }

  public int getNumberOfRecords()
  {
    return numberOfRecords;
  }

  public void setNumberOfRecords( int numberOfRecords )
  {
    this.numberOfRecords = numberOfRecords;
  }

  public boolean isCleanOldTables()
  {
    return cleanOldTables;
  }

  public void setCleanOldTables( boolean cleanOldTables )
  {
    this.cleanOldTables = cleanOldTables;
  }

  public int getNumberOfParsedRecords()
  {
    return numberOfParsedRecords;
  }

  public void setNumberOfParsedRecords( int numberOfParsedRecords )
  {
    this.numberOfParsedRecords = numberOfParsedRecords;
  }

  public int getNumberOfInsertions()
  {
    return numberOfInsertions;
  }

  public void setNumberOfInsertions( int numberOfInsertions )
  {
    this.numberOfInsertions = numberOfInsertions;
  }

  public int getNumberOfUpdates()
  {
    return numberOfUpdates;
  }

  public void setNumberOfUpdates( int numberOfUpdates )
  {
    this.numberOfUpdates = numberOfUpdates;
  }

  public boolean isDeleteAnnotationsAndFtypes()
  {
    return deleteAnnotationsAndFtypes;
  }

  public void setDeleteAnnotationsAndFtypes( boolean deleteAnnotationsAndFtypes )
  {
    this.deleteAnnotationsAndFtypes = deleteAnnotationsAndFtypes;
  }

  public boolean isDeleteEntryPoints()
  {
    return deleteEntryPoints;
  }

  public void setDeleteEntryPoints( boolean deleteEntryPoints )
  {
    this.deleteEntryPoints = deleteEntryPoints;
  }

  public boolean isDeleteAnnotations()
  {
    return deleteAnnotations;
  }

  public void setDeleteAnnotations( boolean deleteAnnotations )
  {
    this.deleteAnnotations = deleteAnnotations;
  }

  public boolean isIgnoreEntryPoints()
  {
    return ignoreEntryPoints;
  }

  public void setIgnoreEntryPoints( boolean ignoreEntryPoints )
  {
    this.ignoreEntryPoints = ignoreEntryPoints;
  }

  public boolean isDebug()
  {
    return debug;
  }

  public void setDebug( boolean debug )
  {
    this.debug = debug;
  }

  public StringBuffer getDebugInfo()
  {
    return debugInfo;
  }

  public void setDebugInfo( StringBuffer debugInfo )
  {
    this.debugInfo = debugInfo;
  }

  public String getGmtStartDate()
  {
    return gmtStartDate;
  }

  public void setGmtStartDate( String gmtStartDate )
  {
    this.gmtStartDate = gmtStartDate;
  }

  public String getGmtEndDate()
  {
    return gmtEndDate;
  }

  public void setGmtEndDate( String gmtEndDate )
  {
    this.gmtEndDate = gmtEndDate;
  }

  public File getFormattedFile()
  {
    return formattedFile;
  }

  public void setFormattedFile( File formattedFile )
  {
    this.formattedFile = formattedFile;
  }

  public boolean isMissingInfo()
  {
    return missingInfo;
  }

  public void setMissingInfo( boolean missingInfo )
  {
    this.missingInfo = missingInfo;
  }

  public String getGenboreeGroupId()
  {
    return genboreeGroupId;
  }

  public void setGenboreeGroupId( String genboreeGroupId )
  {
    this.genboreeGroupId = genboreeGroupId;
  }

  public String getGenboreeUserId()
  {
    return genboreeUserId;
  }

  public int getUserId()
  {
    int userId = Util.parseInt(genboreeUserId, -1);
    return userId;
  }

  public void setGenboreeUserId( String genboreeUserId )
  {
    this.genboreeUserId = genboreeUserId;
  }

  public String getStderr()
  {
    return stderr.toString();
  }

  public void setStderr( String stderr )
  {
    this.stderr.append( stderr );
  }

  public String getStdout()
  {
    return stdout.toString();
  }

  public void setStdout( String stdout )
  {
    this.stdout.append( stdout );
  }

  public int getErrorLevel()
  {
    return errorLevel;
  }

  public void setErrorLevel( int errorLevel )
  {
    this.errorLevel = errorLevel;
  }

  public String getFileFormat()
  {
    return fileFormat;
  }

  public void setFileFormat( String fileFormat )
  {
    if( fileFormat != null )
      this.fileFormat = fileFormat;
    else
      this.fileFormat = "lff";
  }

  public String getLineNumber()
  {
    return lineNumber;
  }

  public void setLineNumber( String lineNumber )
  {
    this.lineNumber = lineNumber;
  }

  public String getPropFile()
  {
    return propFile;
  }

  public void setPropFile( String propFile )
  {
    this.propFile = propFile;
  }

  public String getInputFile()
  {
    return inputFile;
  }

  public void setInputFile( String inputFile )
  {
    this.inputFile = inputFile;
  }

  public File getOrigFileName()
  {
    return origFileName;
  }

  public void setOrigFileName( File origFileName )
  {
    this.origFileName = origFileName;
  }

  public String getRefseqFile()
  {
    return refseqFile;
  }

  public void setRefseqFile( String refseqFile )
  {
    this.refseqFile = refseqFile;
  }

  public void setToMerge( boolean mergeBool )
  {
    toMerge = mergeBool;
  }

  public boolean getToMerge()
  {
    return toMerge;
  }

  public String getRefSeqId()
  {
    return refseqId;
  }

  public void setRefSeqId( String refseqId )
  {
    this.refseqId = refseqId ;
  }

  // ------------------------------------------------------------------
  // CLASS METHODS
  // ------------------------------------------------------------------
  // Do the actual upload using AnnotationUploader class:
  public static HashMap uploadData( int errorLevel, String refSeqId, String userId, String groupId,
                                    String fileToUpload, boolean ignoreRefSeq, boolean truncateTables,
                                    boolean deleteEntryPoints, boolean deleteAnnotationsAndFtypes,
                                    int maxInsertSize, int timeSleep, boolean cleanOldTables, PrintStream fullLogStream )
  {
    fullLogStream.println("STATUS: Starting the uploadData() method" ) ;
    TimingUtil uploadDataTimer = null ;
    uploadDataTimer = new TimingUtil() ;
    uploadDataTimer.addMsg( "Inside the upoadData method" );
    // Init:
    int numRecs = -1;
    StringBuffer info = null ;
    HashMap results = new HashMap() ;
    AnnotationUploader currentUpload = null ;

    // Are we good to go?
    if(errorLevel == 0 || errorLevel == 10)
    {
      String databaseNameInUse = GenboreeUtils.fetchMainDatabaseName( refSeqId, false ) ;
      boolean validRefseqId = DatabaseCreator.checkIfRefSeqExist( refSeqId, databaseNameInUse, false ) ;
      uploadDataTimer.addMsg("Done validating database") ;
      // Does refSeqId look good? If so, make an AnnotationUploader object and fire off upload:
      if(validRefseqId)
      {
        currentUpload = new AnnotationUploader(refSeqId, userId, groupId, databaseNameInUse, fullLogStream) ;
        if(cleanOldTables)
        {
          currentUpload.cleanOldTables() ;
        }
        currentUpload.setFullLogFile(fullLogStream) ;
        info = currentUpload.getDebugInfo() ; // This gets us a *pointer* (reference) to the debugInfo property of currentUpload
        // Debug: check that we are using the right settings:
        info.append("\n\nSTATE: AnnotationUploader#uploadData(): maxInsertSize = " ).append( currentUpload.getMaxNumberOfInserts() ).append( "\n" ) ;
        info.append("STATE: AnnotationUploader#uploadData(): maxSizeOfBufferInBytes = " ).append( currentUpload.getMaxSizeOfBufferInBytes() ).append( "\n" ) ;
        // Start timing the whole upload using currentUpload's timer object
        currentUpload.timer.addMsg("BEGIN: AnnotationUploader#uploadData()");
        // Are we ignoring the entrypoint section (maybe) or the assembly section (always) of LFF ?
        currentUpload.setIgnore_refseq(ignoreRefSeq) ;
        currentUpload.setIgnore_assembly(true) ;

        // Perform any db or track clearing that was requested (i.e. to do a db-contents replace)
        if(truncateTables)
        {
          currentUpload.truncateTables() ;
        }
        if(deleteEntryPoints)
        {
          currentUpload.deleteRefseqs() ;
        }
        if(deleteAnnotationsAndFtypes)
        {
          currentUpload.truncateAllTables() ;
        }

        currentUpload.setSleepTime(timeSleep) ;
        currentUpload.setMaxNumberOfInserts(maxInsertSize);
        currentUpload.setLffFile(fileToUpload) ;
        currentUpload.timer.addMsg("DONE: set ignores, truncate/delete tables where needed, insertion size & rate, etc" );

        // Load LFF into database!
        uploadDataTimer.addMsg("Before uploading lff file") ;
        boolean fileLoaded = currentUpload.loadLffFile() ;
        uploadDataTimer.addMsg("After uploading lff file") ;

        currentUpload.timer.addMsg("DONE: loadLffFile") ;
        // Record some statistics from the upload:
        numRecs = currentUpload.getCurrentLffLineNumber();
        results.put( "uploaderTimeInfo", currentUpload.getTimmingInfo() );
        results.put( "groupAssignerTimeInfo", currentUpload.getGroupAssignerTimmerInfo() );
        results.put( "numberOfLines", "" + numRecs );
        results.put( "numberOfParsedRecords", "" + currentUpload.getAnnotationsSuccessfullyParsed() );
        results.put( "numberOfInsertedRecords", "" + currentUpload.getAnnotationsForInsertion() );
        results.put( "numberOfUpdatedRecords", "" + currentUpload.getAnnotationsForUpdate() );
        info.append( "\n\n" ).append( "NUMBER OF LINES =" ).append( numRecs ).append( "\n" );
        info.append( "\n\n" ).append( "NUMBER OF PARSED RECORDS=" ).append( currentUpload.getAnnotationsSuccessfullyParsed() ).append( "\n" );
        info.append( "\n\n" ).append( "NUMBER OF INSERTED RECORDS=" ).append( currentUpload.getAnnotationsForInsertion() ).append( "\n" );
        info.append( "\n\n" ).append( "NUMBER OF UPDATED RECORDS=" ).append( currentUpload.getAnnotationsForUpdate() ).append( "\n" );
      }

      // Stop timing the whole upload & have the AnnotationUploader generate its timing report:
      if(currentUpload != null)
      {
        currentUpload.timer.addMsg("DONE: AnnotationUploader#uploadData()");
        // Append the timing report now that we are all done
        if(info != null)
        {
          info.append( "\n---------------------\n" ).append( currentUpload.timer.generateStringWithReport() ).append( "\n------------------------\n" );
        }
      }
      results.put( "info", info ) ;
    }
    // Have this class stop its timing and generate a report.
    uploadDataTimer.addMsg("DONE: Ending uploadData() method") ;
    results.put( "uploadDataTimeInfo", uploadDataTimer.generateStringWithReport() );
    return results ;
  } // END: public static HashMap uploadData()

  // ------------------------------------------------------------------
  // INSTANCE METHODS
  // ------------------------------------------------------------------
  public void run()
  {
    // Init:
    File localOriginalFile = null ;
    File parentDir = null ;
    String newFile = null ;
    String nameOfExtractedFile = null ;
    String fileWithEntryPoints = null ;
    TimingUtil timer = new TimingUtil() ;
    int numRecs = -1 ;
    HashMap outPut = null ;
    Integer tempErrorLevel = null ;
    String validatorMode = null ;
    StringBuffer infoFromUploader = null ;
    HashMap resultsUploader = null ;
    String numberOfLines = null ;
    String numberOfParsedRecords = null ;
    String numberOfInsertedRecords = null ;
    String numberOfUpdatedRecords = null ;
    boolean failAtSomePoint = false ;
    PrintStream pout = null ;

    timer.addMsg("BEGIN: UploaderCluster#run()") ;
    debugInfo = new StringBuffer( 100 );
    setGmtStartDate( DirectoryUtils.returnFormatedGMTTime() );
    debugInfo.append("Starting the run at ").append( getGmtStartDate() ).append( "\n" );
    File fullLog = new File(getInputFile() + ".full.log") ;

    // Set up log file & a writer
    try
    {
      fullLog.createNewFile() ;
      pout = new PrintStream( new FileOutputStream( fullLog.getAbsolutePath() ) ) ;
    }
    catch( FileNotFoundException e )
    {
      e.printStackTrace( System.err ) ;
      errorLevel = 70 ;
    }
    catch( IOException e )
    {
      e.printStackTrace( System.err );
      errorLevel = 71 ;
    }

    if(errorLevel == 0) // have log file
    {
      pout.println( "Starting upload for file " + getInputFile() ) ;
      pout.flush() ;

      try
      {
        localOriginalFile = new File( getInputFile() );
        setOrigFileName( localOriginalFile ) ;
        parentDir = new File(localOriginalFile.getParent()) ;
      }
      catch( NullPointerException ex )
      {

        System.err.println( "UploaderCluster#run(): Unable to localize the fileName, please use full path and verify permissions for: localOriginalFile: " + localOriginalFile + "; parentDir: " + parentDir );
        ex.printStackTrace(System.err) ;
				errorLevel = 72 ;
      }

      if(errorLevel == 0) // found local file and its parent dir
      {
        setStdout( "" );
        setStderr( "" );

        setApproxNumberRecords(getInputFile()) ;

        debugInfo.append( "The original file is " ).append( getInputFile() ).append( "\n" );
        System.err.println( "The database name is " + getDatabaseName() + " the databaseHost is " + getDatabaseHost() +
                            " the approximate number of records in file are " + getApproxNumberRecords() + " the file name is " + getInputFile() );

        if(getApproxNumberRecords() < 1)
        {
          this.approxNumberRecords = 1 ;
        }

        try
        {
          if(getErrorLevel() == 0)
          {
            System.err.println("Error level: 0") ;
            fileWithEntryPoints = getInputFile() + ".entrypoints.lff";
            if(isDeleteEntryPoints())
            {
              try
              {
                File entryPointsFile = new File(fileWithEntryPoints) ;
                entryPointsFile.createNewFile() ;
              }
              catch( IOException e )
              {
                e.printStackTrace( System.err );
                errorLevel = 73 ;
              }
            }

            if(errorLevel == 0) // Then making entrypoint file OK (if asked to redefine entrypoints)
            {
              // Transform/covert data file if needed:
              debugInfo.append( "file with entryPoints is " ).append( getRefseqFile() ).append( "\n" ) ;
              System.err.println("Going to transform...") ;
              // Call transform, get new file name if any:
              outPut = CommandsUtils.transformToLff( getInputFile(), getFileFormat(), getExtraOptions() ) ;
              newFile = (String)outPut.get( "formatedFile" ) ;
              if(newFile != null)
              {
                setFormattedFile(new File(newFile)) ;
              }
              // Record status
              setStdout((String)outPut.get( "stdout" ) ) ;
              setStderr((String)outPut.get( "stderr" ) ) ;
              tempErrorLevel = (Integer)outPut.get( "errorLevel" ) ;
              setErrorLevel(tempErrorLevel.intValue()) ;
              debugInfo.append("file format is " ).append( getFileFormat() )
                      .append(" and the new file is " ).append( newFile ).append( "\n" ) ;
              debugInfo.append("After running the transformer the stderr is ").append(stderr).append("\n") ;
              debugInfo.append("After running the transformer the stdout is ").append(stdout).append("\n") ;
              debugInfo.append("After running the transformer the errorLevel is " ).append( errorLevel ).append("\n") ;
            }
            setErrorLevel(errorLevel) ;
          }

          // Check for forbidden tracks in the data file and if none, do actual upload -> database!
          if(getFormattedFile() != null && (getErrorLevel() == 0 || getErrorLevel() == 10)) // then process resulting file
          {
            // Check for forbidden tracks (private tracks which userId doesn't have access to)
            ForbiddenTracksDetector forbiddenTracks = new ForbiddenTracksDetector(getInputFile(), getUserId(), refseqId) ;
            boolean hasForbiddenTracks = forbiddenTracks.hasForbiddenTracks() ;
            listOfForbiddenTracks = forbiddenTracks.getArrayWithForbiddenTracks() ;

            if(hasForbiddenTracks)
            {
              failAtSomePoint = true ;
              setErrorLevel(41) ;
              setGmtEndDate(DirectoryUtils.returnFormatedGMTTime()) ;
              return ;
            }

            // DO THE UPLOAD!
            if(!failAtSomePoint)
            {
              System.err.println("STATUS: about to start AnnotationUploader") ;
              resultsUploader = UploaderCluster.uploadData( errorLevel, getRefSeqId(),
                      getGenboreeUserId(), getGenboreeGroupId(),
                      getFormattedFile().getAbsolutePath(), isIgnoreEntryPoints(),
                      isDeleteAnnotations(), isDeleteEntryPoints(), isDeleteAnnotationsAndFtypes(),
                      getMaxInsertSize(), getSleepTime(), isCleanOldTables(), pout ) ;
              System.err.println("STATUS: DONE with AnnotationUploader") ;
              // Statistics, timing, etc:
              timer.addMsg( "Finished actual upload of data" );
              infoFromUploader = ( StringBuffer )resultsUploader.get( "info" );
              numberOfLines = ( String )resultsUploader.get( "numberOfLines" );
              numberOfParsedRecords = ( String )resultsUploader.get( "numberOfParsedRecords" );
              numberOfInsertedRecords = ( String )resultsUploader.get( "numberOfInsertedRecords" );
              numberOfUpdatedRecords = ( String )resultsUploader.get( "numberOfUpdatedRecords" );
              this.numberOfRecords = Util.parseInt( numberOfLines, -1 );
              this.numberOfParsedRecords = Util.parseInt( numberOfParsedRecords, -1 );
              this.numberOfInsertions = Util.parseInt( numberOfInsertedRecords, -1 );
              this.numberOfUpdates = Util.parseInt( numberOfUpdatedRecords, -1 );
              debugInfo.append( "Debuggin infor from AnnotationUploader:" ).append( infoFromUploader ).append( "\n" );
              debugInfo.append( "After running the uploader number of records in file = " ).append( stdout ).append( "\n" );
              errorLevel = 0 ;
            }
          }
        }
        catch( Throwable th )
        {
          // record the error to Stderr
          debugInfo.append( "After running the uploader number of records in file = " ).append( stdout ).append( "\n" );
          System.err.println( "ERROR: UploaderCluster#run(): " + th.toString() );
          th.printStackTrace( System.err ) ;
          errorLevel = 74 ;
        }
        setErrorLevel(errorLevel) ;
        debugInfo.append("After unlocking the file ").append("\n") ;

        if(errorLevel != 0 && errorLevel != 10 && errorLevel != 20 && errorLevel != 30)
        {
          stdout.append("FATAL ERROR " + errorLevel) ;
          errorLevel = 30 ;
        }
        setErrorLevel(errorLevel) ;

        // Clean up activities:
        debugInfo.append( timer.generateStringWithReport() );
        timer = new TimingUtil();
        timer.addMsg( "Starting to send message" );

        setGmtEndDate( DirectoryUtils.returnFormatedGMTTime() );
        debugInfo.append( "End the run at " ).append( getGmtEndDate() ).append( "\n" );

        DirectoryUtils.printErrorMessagesToAFile( getInputFile() + ".log", isDebug(), getDebugInfo() );

        timer.addMsg( "Uploader END" ) ;
        timingInfo = timer.generateStringWithReport() ;
        debugInfo.append( timingInfo );

        if(!failAtSomePoint)
        {
          if( resultsUploader != null && !resultsUploader.isEmpty() )
          {
            String tempString = ( String )resultsUploader.get( "uploadDataTimeInfo" );
            if( tempString != null )
            {
              debugInfo.append( tempString ).append( "\n" );
            }
            tempString = ( String )resultsUploader.get( "uploaderTimeInfo" );
            if( tempString != null )
            {
              debugInfo.append( tempString ).append( "\n" );
            }
            tempString = ( String )resultsUploader.get( "groupAssignerTimeInfo" );
            if( tempString != null )
            {
              debugInfo.append( tempString ).append( "\n" );
            }
          }
        }
      }
    }
    System.err.println("STATUS: ALL DONE. (errorLevel: " + errorLevel + "") ;
    setErrorLevel(errorLevel) ;
  } // END: run()

  // ------------------------------------------------------------------
  // HELPER METHODS
  // ------------------------------------------------------------------
  // - Was called "constructBodySubject()"
  protected String constructFeedback()
  {
    return constructFeedback(stdout.toString(), ""+numberOfRecords, ""+numberOfParsedRecords, ""+numberOfInsertions, ""+numberOfUpdates) ;
  }
  protected String constructFeedback( String numRecs, String numberOfLines,
                                    String numberOfParsedRecords, String numberOfInsertedRecords,
                                    String numberOfUpdatedRecords )
  {
    String grpName = GenboreeUtils.fetchGroupName( getGenboreeGroupId() ) ;
    String body = "" ;
    // Build job details:
    String jobDetails = "Job details:\n" ;
    if(grpName != null)
    {
      jobDetails += "  Group: " + grpName + "\n" ;
    }
    jobDetails += "  Database ID: " + getRefSeqId() + "\n" +
            "  Database Name: " + this.refName + "\n" +
            "  File Name: " + getOrigFileName().getName() + "\n" +
            "  Started At: " + getGmtStartDate() + "\n" +
            "  Finished At: " + getGmtEndDate() + "\n" ;

    // The errors to handle are  errorLevel==0 (No errors)|| errorLevel==10 (Some errors)
    // || errorLevel==20 (Too many errors)|| errorLevel==30 (Fatal error)
    if(errorLevel == 30)
    {
      body =  "FATAL ERROR: There was an error uploading your annotations.\n" +
              "Please contact " + GenboreeConfig.getConfigParam("gbAdminEmail") + " with the following information:\n\n";
      body += jobDetails ;
    }
    else if(errorLevel == 20)
    {
      body = "BADLY FORMATTED FILE: There were too many errors uploading your annotations.\n" +
              "Please fix the following errors before reattempting your upload.\n\n" ;
      body += jobDetails ;
    }
    else if( errorLevel == 10 )
    {
      body = "SOME ERRORS: We encountered several errors during the upload process; however, " +
              "we were able to upload most of the annotations.\n\n";
      body += jobDetails ;
      body += "  Number of Lines: " + numberOfLines.trim() + "\n" +
              "  Number of Records Parsed: " + numberOfParsedRecords.trim() + "\n" +
              "  Number of Records Inserted: " + numberOfInsertedRecords.trim() + "\n" +
              "  Number of Records Updated: " + numberOfUpdatedRecords.trim() + "\n" ;
    }
    else if(errorLevel == 0)
    {
      body = "COMPLETE: The process of validating and uploading your annotations is complete. " ;
      body += jobDetails ;
      body += "  Number of Lines: " + numberOfLines.trim() + "\n" +
              "  Number of Records Parsed: " + numberOfParsedRecords.trim() + "\n" +
              "  Number of Records Inserted: " + numberOfInsertedRecords.trim() + "\n" +
              "  Number of Records Updated: " + numberOfUpdatedRecords.trim() + "\n" ;
    }
    else if( errorLevel == 34 )
    {
      body += "TOO BIG: your annotations file is too big to upload in one big chunk.\n" +
              "Please consider splitting the huge file into smaller, more manageable \n" +
              "files, or even consider culling the data.\n" ;
      body += jobDetails ;
      body += " Approx. # Records: " + getApproxNumberRecords() +
              " Max. # Records Allowed: " + GenboreeConfig.getLongConfigParam( "maxNumRecs", -1 ) + ".\n" ;
    }
    else if(errorLevel == 41)
    {
      body = "UPLOADS REJECTED: your annotation upload was rejected because you do not have access to some of the tracks" ;
      StringBuffer tempSB = null ;
      if( listOfForbiddenTracks  != null && listOfForbiddenTracks.length > 0 )
      {
        tempSB = new StringBuffer(200) ;
        for(int i = 0; i < listOfForbiddenTracks.length; i++)
        {
          tempSB.append("    ").append(listOfForbiddenTracks[ i ]).append( "\n" ) ;
        }
      }
      body += jobDetails ;
      body += "  Unauthorized Tracks:\n" + tempSB.toString() + "\n\n" +
              "Please consider requesting access to the tracks to your group administrator or replace the name of the tracks.\n" ;
    }
    return body ;
  } // END: protected void constructFeedback()
} // END: public class UploaderCluster
