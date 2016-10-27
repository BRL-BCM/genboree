package org.genboree.util;

import java.sql.* ;
import java.util.* ;
import org.genboree.dbaccess.util.* ;
import org.genboree.dbaccess.DBAgent ;


public class TrackDeleter implements Runnable
{
  protected Thread thr = null;
  protected StringBuffer debugInfo = null;
  protected String databaseName = null;
  protected String databaseHost = null;
  protected boolean insertTask = true;
  protected long taskId = -1;
  protected String refseqId;
  protected int deleteSleepTime = 30000;  // 30 seconds
  protected int delLimit = 6000 ;
  protected int delPause = 2000;
  protected DBAgent db = null;
  protected Connection databaseConnection = null;
  protected String[] ftypeIds = null;
  protected long approxNumberRecords = -1;
  protected String tracksStr = null;
  protected int errorLevel = 0;
  protected boolean suppressEmail = false;
  protected String gmtStartDate = null;
  protected boolean cheapDelete = true;
  protected String gmtEndDate = null;
  protected long quickNumberDeletes = -1;
  protected long slowNumberDeletes = -1;
  protected String emailSubject = "";
  protected String emailBody = "";
  protected String fromAddress = "\"Genboree Team\" <" + GenboreeConfig.getConfigParam("gbFromAddress") + ">";
  protected String smtpHost = Util.smtpHost;
  protected static String bccAddress = GenboreeConfig.getConfigParam("gbBccAddress");
  protected String[] userIds = null;
  protected String userStr = null;
  protected String trackNamesStr = null;

  public TrackDeleter( String refSeqId, String[] ftypeIds, String[] usersIds )
  {
    gmtStartDate = DirectoryUtils.returnFormatedGMTTime();
    boolean permissionToUseDb = GenericDBOpsLockFile.getPermissionForDbOperation(GenericDBOpsLockFile.MAIN_GENB_DB);
    setDatabaseName( refSeqId );
    setDatabaseHost();
    permissionToUseDb = GenericDBOpsLockFile.releasePermissionForDbOperation(GenericDBOpsLockFile.MAIN_GENB_DB);
    setFtypeIds( ftypeIds );
    setUserIds( usersIds );
    permissionToUseDb = GenericDBOpsLockFile.getPermissionForDbOperation(GenericDBOpsLockFile.USER_GENB_DB);
    setTrackNamesStr();
    setApproxNumberRecords();
    permissionToUseDb = GenericDBOpsLockFile.releasePermissionForDbOperation(GenericDBOpsLockFile.USER_GENB_DB);
  }

  // ARJ: this code seems to be pasted multiple times in various methods in this class.
  //      I will just write this generic method and use it from here, rather than more copy/paste.
  public static final String makeCSVstring(ArrayList<String> items)
  {
    StringBuffer retVal = new StringBuffer() ;
    if(items != null && items.size() > 0)
    {
      Iterator<String> iter = items.iterator() ;
      while(iter.hasNext())
      {
        String item = iter.next() ;
        retVal.append(item) ;
        if(iter.hasNext()) // if not last one, add a ','
        {
          retVal.append(",") ;
        }
      }
    }
    return retVal.toString() ;
  }

  public void setUserIds( String[] userIds )
  {
    this.userIds = userIds;
    StringBuffer usersBuff = new StringBuffer();
    if( userIds != null && userIds.length > 0 )
    {
      for( int ii = 0; ii < userIds.length; ii++ )
      {
        usersBuff.append( userIds[ ii ] );
        if( ii < ( userIds.length - 1 ) ) // then not the last one, add a ','
        {
          usersBuff.append( "," );
        }
      }
      userStr = usersBuff.toString();
    }
  }

  public boolean isSuppressEmail()
  {
    return suppressEmail;
  }

  public void setSuppressEmail( boolean suppressEmail )
  {
    this.suppressEmail = suppressEmail;
  }

  public boolean isCheapDelete()
  {
    return cheapDelete;
  }

  public void setCheapDelete( boolean cheapDelete )
  {
    this.cheapDelete = cheapDelete;
  }

  public boolean isInsertTask()
  {
    return insertTask;
  }

  public void setInsertTask( boolean insertTask )
  {
    this.insertTask = insertTask;
  }

  public long getTaskId()
  {
    return taskId;
  }

  public void setTaskId( long taskId )
  {
    this.taskId = taskId;
  }


  public void setDatabaseName( String refSeqId )
  {
    this.refseqId = refSeqId;
    this.databaseName = GenboreeUtils.fetchMainDatabaseName( refSeqId, false );
  }

  public void setDatabaseHost()
  {
    Connection mainGenboreeConnection = null;
    try
    {
      db =  DBAgent.getInstance();
      mainGenboreeConnection = db.getNoCacheConnection(null);
      databaseHost = Database2HostTable.getHostForDbName( databaseName, mainGenboreeConnection );
    }
    catch( Exception ex )
    {
      ex.printStackTrace( System.err );
      System.err.println( "Exception unable to generate a connection in Uploader#setDatabaseHost" );
    }
    finally{
      db.safelyCleanup( null, null, mainGenboreeConnection );
    }
  }

  private void setDatabaseConnection()
  {
    try
    {
      databaseConnection = db.getConnection( databaseName, false );
    }
    catch( SQLException e )
    {
      e.printStackTrace( System.err );
    }
  }

  public void setApproxNumberRecords()
  {
    // Next need to estimate number of records to delete.
    // - count number of annotations falling in tracks
    // - estimate: pretend there are 10 AVP per anno (we could get more accurate number with
    //   a little more counting of attributes per track and number annos in each track, later)
    this.approxNumberRecords = countAnnosInTracks();
    // TODO: ***ARJ*** Put this to 100 not 10 before deploy to encourage evening clean up
    //       unless very few annos.
    this.approxNumberRecords *= 10;
  }

  public void setFtypeIds( String[] ftypeIds )
  {
    StringBuffer tracksBuff = new StringBuffer();
    this.ftypeIds = ftypeIds;

    if( ftypeIds != null && ftypeIds.length > 0 )
    {
      for( int ii = 0; ii < ftypeIds.length; ii++ )
      {
        tracksBuff.append( ftypeIds[ ii ] );
        if( ii < ( ftypeIds.length - 1 ) ) // then not the last one, add a ','
        {
          tracksBuff.append( "," );
        }
      }
      tracksStr = tracksBuff.toString();

    }
  }

  public void setTrackNamesStr()
  {

    Connection userDbConnection = null;
    ResultSet rs = null;
    Statement stmt = null;
    StringBuffer tracksBuff = new StringBuffer();
    String sql = null;
    trackNamesStr = null;

    try
    {
      userDbConnection = db.getNoCacheConnection(databaseName);
      sql = "select concat(fmethod, ':', fsource) trackName from ftype where ftypeid in (" + tracksStr + " )";
      stmt =  userDbConnection.createStatement();
      rs = stmt.executeQuery( sql );

      while( rs.next() )
      {
        tracksBuff.append( rs.getString( "trackName" ) );
        if( !rs.isLast() )
          tracksBuff.append( ", " );
      }
    }
    catch( Exception ex )
    {
      ex.printStackTrace( System.err );
      System.err.println( "Exception unable to generate a connection in TrackDeleter setTrackNamesStr" );
    }
    finally{
      db.safelyCleanup( null, null, userDbConnection );
    }
  }

  public int getErrorLevel()
  {
    return errorLevel;
  }

  public void setErrorLevel( int errorLevel )
  {
    this.errorLevel = errorLevel;
  }

  // Delete track from cheap tables user database
  // ** Track delettion is meant to be done in two steps: (a) a fast delete step that
  //    happens immediately and (b) a slower delete on big tables that happens when
  //    conditions allow.
  // ** This method works with expensiveDeleteTracks(...)
  // - this MUST be followed by a call to delete the expensive tables
  // - tracks are deleted by quickly removing them from ftype and the various feature* tables immediately
  //   and then in a thread cleaning up the fdata2 and fid2attribute tables when locks/constraints allow.
  // - After this method is called, the user can be told that the track is "deleted" (even though thorough
  //   cleaning is not done yet)
  // - returns number of TRACKS deleted
  public long cheapDeleteTracks()
  {
    long rowCount = -1;
    Statement stmt = null;
    Connection userDbConnection = null;

    try
    {
      userDbConnection = db.getNoCacheConnection(databaseName);
      stmt = userDbConnection.createStatement();

      rowCount = stmt.executeUpdate( "DELETE FROM ftype WHERE ftypeid IN (" + tracksStr + ")" );
      stmt.executeUpdate( "DELETE FROM featuredisplay WHERE ftypeid IN (" + tracksStr + ")" );
      stmt.executeUpdate( "DELETE FROM featuretocolor WHERE ftypeid IN (" + tracksStr + ")" );
      stmt.executeUpdate( "DELETE FROM featuretostyle WHERE ftypeid IN (" + tracksStr + ")" );
      stmt.executeUpdate( "DELETE FROM featuretolink WHERE ftypeid IN (" + tracksStr + ")" );
      stmt.executeUpdate( "DELETE FROM ftype2gclass WHERE ftypeid IN (" + tracksStr + ")" );
      stmt.executeUpdate( "DELETE FROM featureurl WHERE ftypeid IN (" + tracksStr + ")" );
      stmt.executeUpdate( "DELETE FROM featuresort WHERE  ftypeid IN (" + tracksStr + ")" );
      stmt.executeUpdate( "DELETE FROM ftype2attributeName WHERE ftypeid IN (" + tracksStr + ")" );
      stmt.executeUpdate( "DELETE FROM ftypeCount WHERE ftypeid IN (" + tracksStr + ")" );
    }
    catch( SQLException ex )
    {
      System.err.print( "Exception on TrackDeleter::cheapDeleteTracks details:" );
      ex.printStackTrace( System.err );
      System.err.flush();
    }
    finally
    {
      db.safelyCleanup( null, stmt, userDbConnection );
      return rowCount;
    }
  }

  // Delete tracks from expensive tables in user database (currently the fdata2 tables and fid2attribute tables)
  // - needs connection to the user database
  // - should be called from a Thread which first gets permission to delete from BigDBOpsLockFile before
  //   calling this function.
  // - returns number of ANNOTATIONS deleted.
  public long expensiveDeleteTracks()
  {
    long rowCount = -1;

    if( databaseConnection == null )
    {
      System.err.println( "Error in TrackDeleter::expensiveDelete databaseConnection is null" );
      return rowCount;
    }

    try
    {

      // ARJ: First do the existing process on the other tables where synchronous deletes aren't needed
      //      Use existing way of deleting rows from these tables in blocks rather than all at once.
      //      These are generally empty or under-used tables.
      String sql = "DELETE FROM fdata2_cv WHERE ftypeid IN (" + tracksStr + ") LIMIT " + delLimit;
      rowCount = doLimitedSQLDelete( sql, delLimit, delPause );
      sql = "DELETE FROM fdata2_gv WHERE ftypeid IN (" + tracksStr + ") LIMIT " + delLimit;
      rowCount = doLimitedSQLDelete( sql, delLimit, delPause );
      sql = "DELETE FROM fidText WHERE ftypeid IN (" + tracksStr + ") LIMIT " + delLimit;
      rowCount = doLimitedSQLDelete( sql, delLimit, delPause );
      System.err.println( "Deleting records from blockLevelDataInfo..." );
      sql = "DELETE FROM blockLevelDataInfo WHERE ftypeid IN (" + tracksStr + ") LIMIT " + delLimit;
      rowCount = doLimitedSQLDelete( sql, delLimit, delPause );
      System.err.println( "Deleting records from zoomLevels...." );
      sql = "DELETE FROM zoomLevels WHERE ftypeid IN (" + tracksStr + ") LIMIT " + delLimit;
      rowCount = doLimitedSQLDelete(sql, delLimit, delPause);
			sql = "DELETE FROM ftype2attributes WHERE ftype_id IN (" + tracksStr + ") LIMIT " + delLimit ;
			rowCount = doLimitedSQLDelete(sql, delLimit, delPause) ;
      // ARJ: Next, use specific method (by ARJ) to delete records from fdata2 and fid2attribute
      //      in synchrony (since there is some dependency for the deletes)
      rowCount = this.deleteFdata2_fid2Attribute() ;
    }
    catch( Exception ex )
    {
      System.err.println( "ERROR: TrackManager#expensiveDeleteTracks(C,S[],J) => error deleting tracks." );
      ex.printStackTrace( System.err );
      System.err.flush();
    }
    finally
    {
      return rowCount;
    }
  }

  // Select some fids to delete from fdata2, get their fids,
  // delete those fids from fid2attribute, then delete those fids from fdata2 and repeat until
  // select returns nothing.
  public long deleteFdata2_fid2Attribute()
  {
    long totalRowCount = 0 ;
    long numRowsDeleted = 0 ;
    ResultSet rs = null ;
    PreparedStatement selectFidsStmt = null ;
    Statement deleteFromFid2AttributeStmt = null ;
    Statement deleteFromFdata2Stmt = null ;
    Statement removeCounts = null;
    ArrayList<String> fidList = new ArrayList<String>() ;
    String selectFidsSql = "SELECT fid FROM fdata2 WHERE ftypeid IN (" + tracksStr + ") LIMIT " + delLimit ;
    String deleteFidsFromFid2AttributeSql = "DELETE FROM fid2attribute WHERE fid2attribute.fid IN (%FIDLIST%)" ;
    String deleteFidsFromFdata2Sql = "DELETE FROM fdata2 WHERE fdata2.fid IN (%FIDLIST%)" ;
    boolean haveFidsToDelete = true ;
    if(databaseConnection != null)
    {
      try
      {
        // Prepare the selectFids stmt once and run over and over

        removeCounts = databaseConnection.createStatement();
        removeCounts.executeUpdate( "DELETE FROM ftypeCount WHERE ftypeid IN (" + tracksStr + ")" );
        removeCounts.close();

        selectFidsStmt = databaseConnection.prepareStatement(selectFidsSql) ;
        do
        {
          // 1. Select some fids to delete
          rs = selectFidsStmt.executeQuery() ;
          if(rs.next()) // then not empty yet
          {
            haveFidsToDelete = true ;
            fidList.add(rs.getString("fid")) ;
            while(rs.next())
            {
              fidList.add(rs.getString("fid")) ;
            }
            String fidCSVstr = TrackDeleter.makeCSVstring(fidList) ;
            // Delete those fids from fid2attribute
            String sql = deleteFidsFromFid2AttributeSql.replaceAll("%FIDLIST%", fidCSVstr) ;
            deleteFromFid2AttributeStmt = databaseConnection.createStatement() ;
            numRowsDeleted = deleteFromFid2AttributeStmt.executeUpdate(sql) ;
            // Delete those fids from fdata2
            sql = deleteFidsFromFdata2Sql.replaceAll("%FIDLIST%", fidCSVstr) ;
            deleteFromFdata2Stmt = databaseConnection.createStatement() ;
            numRowsDeleted = deleteFromFdata2Stmt.executeUpdate(sql) ;
            totalRowCount += numRowsDeleted ;
            // Clean up
            fidList.clear() ;
            DBAgent.safelyCleanup(rs, deleteFromFid2AttributeStmt) ;
            DBAgent.safelyCleanup(null, deleteFromFdata2Stmt) ;
          }
          else // no more fdata2 annos to delete, done this phase
          {
            haveFidsToDelete = false ;
          }
          Util.sleep( delPause ) ; // Pause to let other stuff do db work.
        } while(haveFidsToDelete) ;
      }
      catch(Exception ex)
      {
        System.err.println( "ERROR: TrackDeleter#deleteFdata2_fid2Attribute() => exception deleting from fdata2 and fid2attribute in synchrony. " );
        ex.printStackTrace( System.err );
      }
      finally
      {
        try
        {
          fidList.clear() ;
          DBAgent.safelyCleanup(rs, deleteFromFid2AttributeStmt) ;
          DBAgent.safelyCleanup(null, deleteFromFdata2Stmt) ;
        }
        catch(Exception ex2)
        {} // Nothing can be done
      }
    }
    System.err.println("DEBUG: deleted " + totalRowCount + " fdata2/fid2attribute records in track by synchronized block delete\n\n") ;
    return totalRowCount ;
  }

  // Count all annotations in given tracks.
  public long countAnnosInTracks()
  {
    Connection userDbConnection = null;
    long count = 0;
    ResultSet rs = null;
    PreparedStatement stmt = null;

      try
      {
        userDbConnection = db.getNoCacheConnection(databaseName);
        StringBuffer tracksBuff = new StringBuffer();
        if( ftypeIds != null )
        {
          for( int ii = 0; ii < ftypeIds.length; ii++ )
          {
            tracksBuff.append( ftypeIds[ ii ] );
            if( ii < ( ftypeIds.length - 1 ) ) // then not the last one, add a ','
            {
              tracksBuff.append( "," );
            }
          }
        }
        if( tracksBuff != null && tracksBuff.length() > 0 )
        {
          String sql = "select count(*) from fdata2 where ftypeid in ( " + tracksBuff.toString() + " )";
          stmt = userDbConnection.prepareStatement( sql );
          rs = stmt.executeQuery();
          if( rs.next() )
          {
            count = rs.getLong( 1 );
          }
        }
      }
      catch( Exception ex )
      {
        System.err.println( "ERROR: Fdata2Table#countAnnosInTracks() => exception counting annos in tracks. " );
        ex.printStackTrace( System.err );
      }
      finally
      {
        db.safelyCleanup( rs, stmt, userDbConnection );
        DBAgent.safelyCleanup( rs, stmt );
      }

    return count;
  }


  // Executes the SQL in deleteSql argument which already has the limit clause
  // using conn until the number of records deleted is less than the limit argument.
  // - pauses for pauseMillisec in between deletes.
  public long doLimitedSQLDelete( String deleteSql, long limit, int pauseMillis )
  {
    long totalRowCount = 0 ;
    long numRowsDeleted = 0 ;
    Statement stmt = null;
    if( databaseConnection == null )
    {
      System.err.println( "Error in TrackDeleter::doLimitedSQLDelete databaseConnection is null" );
      return totalRowCount;
    }
    try
    {
      // Create statement
      stmt = databaseConnection.createStatement();
      // Execute delete statement until all done, pausing between each.

      do
      {
        numRowsDeleted = stmt.executeUpdate( deleteSql );
        System.err.println("DEBUG: deleting via: " + deleteSql + "\n\n") ;
        totalRowCount += numRowsDeleted;
        Util.sleep( pauseMillis );
      }
      while( numRowsDeleted >= limit );
      stmt.close();
    }
    catch( Exception ex )
    {
      System.err.println( "ERROR: TrackDeleter#doLimitedSQLDelete(S,l,i,C) => error doing limited delete." );
      ex.printStackTrace( System.err );
    }
    finally
    {
      return totalRowCount;
    }

  }


  private void sendEmailToEachUser()
  {

    boolean congrats = ( getErrorLevel() == 0 );
    String newBody = null;

    constructBodySubject();


    for( int i = 0; i < userIds.length; i++ )
    {
      if( congrats )
        newBody = "Congratulations, " + GenboreeUtils.fetchUserFullName( userIds[ i ] ) + "!\n\n" +
                this.emailBody;
      else
        newBody = "Dear, " + GenboreeUtils.fetchUserFullName( userIds[ i ] ) + "\n\n" +
                this.emailBody;

      SendMail sendMailObject = new SendMail();
      sendMailObject.setHost( smtpHost );
      sendMailObject.setFrom( fromAddress );
      sendMailObject.setReplyTo( fromAddress );
      sendMailObject.addTo( GenboreeUtils.fetchUserEmail( userIds[ i ] ) );
      sendMailObject.addBcc( bccAddress );
      sendMailObject.setSubj( emailSubject );
      sendMailObject.setBody( newBody );
      sendMailObject.go();
    }

  }


  protected void constructBodySubject()
  {
    String subj = "Your Genboree track(s) deletion";
    String body = "";

    // The errors to handle are  errorLevel==0 (No errors)|| errorLevel==10 (Errors at the cheap delete)
    // || errorLevel==20 (Errors at the expensive delete)
    if( errorLevel == 10 || errorLevel == 20 )
    {
      subj = subj + "HAD An ERROR, the deletion FAILED.";
      body = "There was an error deleting your data.\n" +
              "Please contact " + GenboreeConfig.getConfigParam("gbAdminEmail") + " with the following information:\n\n";

      body += "Job details:\n" +
              "Database ID: " + refseqId + "\n" +
              "Track Ids: " + tracksStr + "\n" +
              "Error level " + errorLevel + "\n" +
              "Started at: " + gmtStartDate + "\n" +
              "Finished at: " + gmtEndDate + "\n\n";

      body += "We apologize for any inconvenience,\n" +
              "Genboree Team\n";
    } else if( errorLevel == 0 )
    {
      subj += " was complete (no errors.)";
      body = "The process of deleting the tracks ";
      if( this.isCheapDelete() )
        body += trackNamesStr + " ";
      body = body + " was successful.\n\n" +
              slowNumberDeletes + " records were deleted from your database (ID="
              + refseqId +
              ") \n the deletion began at: " + gmtStartDate + "\n and Ended at " +
              gmtEndDate + ".\n\n" +
              "Thank you for using Genboree,\n" +
              "Genboree Team\n";
    }
    emailSubject = subj;
    emailBody = body;


    return;
  }


  public boolean startIt()
  {
    try
    {
      thr = new Thread( this );
      thr.setDaemon( true );
      thr.start();
      return thr.isDaemon();
    }
    catch( Exception ex )
    {
    }
    return false;
  }

  public void run()
  {
    // Need a non-cached connection to user database (must close when done!) in order
    // to benefit from LOW_PRIORITY in delete.

    boolean permissionToUpload = false;
    boolean permissionToUseDb = false;





    //System.err.println("DELETE DEBUG: big delete thread started") ;
    try
    {
      if( isCheapDelete() )
      {
        permissionToUseDb = GenericDBOpsLockFile.getPermissionForDbOperation(GenericDBOpsLockFile.USER_GENB_DB);
        quickNumberDeletes = cheapDeleteTracks();
        if( quickNumberDeletes < 1 ) errorLevel = 10;
        permissionToUseDb = GenericDBOpsLockFile.releasePermissionForDbOperation(GenericDBOpsLockFile.USER_GENB_DB);
      }
      // FIRST: sleep a short while. This allows the main thread (in theory)
      //        to return to the user and possibly do a couple db ops on the database
      //        before we start in on it.
      // TODO: ***ARJ*** Put this back to ~30 seconds before deploy.
      Util.sleep( deleteSleepTime ); // 30 seconds
      //System.err.println("DELETE DEBUG: done waiting before starting big delete phase") ;
      // SECOND: get that non-cached connection:

      // Get permission for delete.
      permissionToUseDb = GenericDBOpsLockFile.getPermissionForDbOperation(GenericDBOpsLockFile.MAIN_GENB_DB);
      if( isInsertTask() && getTaskId() < 1 )
      {
        StringBuffer deleteCmdLine = new StringBuffer();
        deleteCmdLine.append( Constants.JAVAEXEC ).append( " " ).append( Constants.UPLOADERCLASSPATH ).append( Constants.TRACKDELETERCLASS );
        deleteCmdLine.append( " -u " ).append( userStr ).append( " -r " ).append( refseqId ).append( " -t " ).append( tracksStr );


        long local_taskId = TasksTable.insertNewTask( deleteCmdLine.toString(), Constants.PENDING_STATE );
        System.err.println( "Inside the deleter The id in the TaskTable is " + local_taskId + "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%\n\n\n" );
        System.err.println( deleteCmdLine.toString() );
        setTaskId( local_taskId );
        setInsertTask( false );
        System.err.println("After the task is inserted the state is "  + TasksTable.getStateFromId(getTaskId()));

      }
      if( getTaskId() > 0 && !isInsertTask() )
        TasksTable.setStateBits( getTaskId(), Constants.RUNNING_STATE | Constants.PENDING_STATE );

      permissionToUseDb = GenericDBOpsLockFile.releasePermissionForDbOperation(GenericDBOpsLockFile.MAIN_GENB_DB);

      System.err.println("After the setStateBit the state is "  + TasksTable.getStateFromId(getTaskId())   + " and the isInsertTassk is " + isInsertTask() );

      permissionToUpload = BigDBOpsLockFile.getPermissionForBigDbOperation( databaseName, databaseHost, approxNumberRecords );


      if( getTaskId() > 0 && !isInsertTask() )
        TasksTable.clearStateBits( getTaskId(), Constants.PENDING_STATE );
      System.err.println("After the clearStateBit the state is "  + TasksTable.getStateFromId(getTaskId())   + " and the isInsertTassk is " + isInsertTask() );
      setDatabaseConnection();
      // Do delete:
      slowNumberDeletes = expensiveDeleteTracks();
      if( slowNumberDeletes > 0 )
      {
        System.err.println( "DEBUG DELETE TRACK: annotations in tracks deleted = " + slowNumberDeletes );
      } else
      {
        errorLevel = 20;
      }
      gmtEndDate = DirectoryUtils.returnFormatedGMTTime();

      if( !isSuppressEmail() )
      {
        sendEmailToEachUser(); // send one message per user
      }
      if( getTaskId() > 0 && !isInsertTask() )
        TasksTable.clearStateBits( getTaskId(), Constants.RUNNING_STATE );
      System.err.println("After the clearStateBit the state is "  + TasksTable.getStateFromId(getTaskId())   + " and the isInsertTassk is " + isInsertTask() );

    }
    catch( Exception ex )
    {
      if( getTaskId() > 0 && !isInsertTask() )
        TasksTable.setStateBits( getTaskId(), Constants.FAIL_STATE );
      // Log error.
      System.err.println( "trackmgr.incl => ERROR In Delete Thread trying to delete tracks. " );
      ex.printStackTrace( System.err );
    }
    finally
    {
      // Release userDbConn
      db.closeConnection( databaseConnection );

      // Must release lock!
      BigDBOpsLockFile.releasePermissionForBigDbOperation( databaseName, databaseHost );
    }
  }

  public static void printUsage()
  {
    System.out.print( "usage: AutoDelete " );
    System.out.println( "-r refseqId \n" +
            "\t-t trackIds (comma delimited eg: 1,2,3)\n" +
            "\t-u userIds (comma delimited eg: 1,2,3) \n" +
            "\t-c { turn cheap delete off default on } \n" +
            "\t-k { turn task insertion off default on } \n" +
            "\t-s { turn email off default on } \n" +
            "\t-y { taskId, if taskId is not present and taskid is provided error would be generated } \n"
    );
  }


  public static void main( String[] args )
  {
    String refseqId = null;
    String[] trackIds = null;
    String trackId = null;
    String usersId = null;
    String[] genboreeIds = null;
    boolean insertTask = true;
    long taskId = -1;
    String bufferString = null;
    boolean cheapDelete = true;
    boolean suppressEmail = false;

    int exitError = 0;

    if( args.length < 6 )
    {
      printUsage();
      System.exit( -1 );
    }

    if( args.length >= 1 )
    {

      for( int i = 0; i < args.length; i++ )
      {
        if( args[ i ].compareToIgnoreCase( "-r" ) == 0 )
        {
          i++;
          if( args[ i ] != null )
          {
            refseqId = args[ i ];
          }
        }
        else if( args[ i ].compareToIgnoreCase( "-t" ) == 0 )
        {
          i++;
          if( args[ i ] != null )
          {
            trackId = args[ i ];
            if( trackId.indexOf( "," ) > -1 )
              trackIds = trackId.split( "," );
            else
            {
              trackIds = new String[1];
              trackIds[ 0 ] = trackId;
            }
          }
        }
        else if( args[ i ].compareToIgnoreCase( "-u" ) == 0 )
        {
          i++;
          if( args[ i ] != null )
          {
            usersId = args[ i ];
            if( usersId.indexOf( "," ) > -1 )
              genboreeIds = usersId.split( "," );
            else
            {
              genboreeIds = new String[1];
              genboreeIds[ 0 ] = usersId;
            }
          }
        }
        else if( args[ i ].compareToIgnoreCase( "-y" ) == 0 )
        {
          i++;
          if( args[ i ] != null )
          {
            bufferString = args[ i ];
            taskId = Util.parseLong( bufferString, -1 );
            if( taskId > 0 )
              insertTask = false;
          }
        }
        else if( args[ i ].compareToIgnoreCase( "-c" ) == 0 )
        {
          cheapDelete = false;
        }
        else if( args[ i ].compareToIgnoreCase( "-k" ) == 0 )
        {
          insertTask = false;
        }
        else if( args[ i ].compareToIgnoreCase( "-s" ) == 0 )
        {
          suppressEmail = true;
        }

      }

    } else
    {
      printUsage();
      System.exit( -1 );
    }

    if( refseqId == null || trackIds == null )
    {
      printUsage();
      System.exit( -1 );
    }

    org.genboree.util.TrackDeleter deleter = new TrackDeleter( refseqId, trackIds, genboreeIds );
    deleter.setCheapDelete( cheapDelete );
    deleter.setTaskId( taskId );
    deleter.setInsertTask( insertTask );
    deleter.setSuppressEmail( suppressEmail );

    Thread thr2 = new Thread( deleter );
    thr2.start();

    try
    {
      thr2.join();
    }
    catch( InterruptedException e )
    {
      e.printStackTrace( System.err );
    }
    exitError = deleter.getErrorLevel();
    //  System.err.println(uploader.getStderr());
    if( exitError == 0 )
    {
      System.out.println( "Tracks were deleted successfully!" );
      System.out.flush();
    } else
    {
      System.err.println( "Tracks were not deleted!" );
    }
    System.exit( exitError );

  }


}
