package org.genboree.upload;

import java.io.*;
import java.util.*;
import java.util.Date;
import java.text.SimpleDateFormat;
import java.sql.Connection;

import org.genboree.util.*;
import org.genboree.dbaccess.*;
import org.genboree.dbaccess.util.TasksTable;
import org.genboree.dbaccess.util.Database2HostTable;

public class FastaEntrypointUploader implements Runnable
{
  protected String binary = Constants.GB_RUBY + " " + Constants.GB_FASTA_UPLOADER;
  protected String fastaFile = null;
  protected String dataDBName = null;
  protected Thread thr = null;
  protected String origFileName = null;
  protected String maxSeqFileSize = "1_500_000_000";
  /* Email related attributes and methods */
  protected Vector toEmails = new Vector();
  protected Vector bccEmails = new Vector();
  protected String fromAddress = Constants.GB_FROM_ADDRESS;
  protected String smtpHost = Constants.GB_SMTP_HOST;
  /* Genboree info that may be provided for tracking/logging/feedback purposes */
  protected GenboreeUser user = null;
  protected String refseqId = null;
  protected boolean insertTask = true;
  protected boolean suppressEmail = false;
	protected long taskId = -1;
  protected int errorLevel = 0;
  protected String databaseHost = null;
  protected long approxNumberRecords = 1000;
  protected StringBuffer debugInfo = null;


  public FastaEntrypointUploader( String refseqId, String fastaFile, String userId )
  {
    setRefSeqId( refseqId );
    setFastaFile( fastaFile );
    user = GenboreeUser.fetch( userId );
    dataDBName = GenboreeUtils.fetchMainDatabaseName( refseqId );
    setDatabaseHost();
    addToEmail( user.getEmail() );
    addBccEmail( Constants.GB_BCC_ADDRESS );
    debugInfo = new StringBuffer(100);
  }


  public FastaEntrypointUploader( String dataDBName, String fastaFile, GenboreeUser user, String refseqId )
  {
    setDataDBName( dataDBName );
    setFastaFile( fastaFile );
    setUser( user );
    setRefSeqId( refseqId );
    setDatabaseHost();
    addToEmail( user.getEmail() );
    addBccEmail( Constants.GB_BCC_ADDRESS );
    debugInfo = new StringBuffer(100);
  }

  public FastaEntrypointUploader( String dataDBName, String fastaFileLocation )
  {
    this.dataDBName = dataDBName;
    this.fastaFile = fastaFileLocation;
    setDatabaseHost();
    debugInfo = new StringBuffer(100);
  }


  public String getBinary()
  {
    return binary;
  }

  public void setBinary( String binary )
  {
    this.binary = binary;
  }

  public String getFastaFile()
  {
    return this.fastaFile;
  }

  public void setFastaFile( String fastaFile )
  {
    this.fastaFile = fastaFile;
  }

  public String getDataDBName()
  {
    return this.dataDBName;
  }

  public void setDataDBName( String dataDBName )
  {
    this.dataDBName = dataDBName;
  }

  public String getOrigFileName()
  {
    return origFileName;
  }

  public void setOrigFileName( String origFileName )
  {
    this.origFileName = origFileName;
  }

  public StringBuffer getDebugInfo()
  {
    return debugInfo;
  }

  public void setDebugInfo( StringBuffer debugInfo )
  {
    this.debugInfo = debugInfo;
  }

  public String getMaxSeqFileSize()
  {
    return maxSeqFileSize;
  }

  public void setMaxSeqFileSize( String maxSeqFileSize )
  {
    this.maxSeqFileSize = maxSeqFileSize;
  }

  protected boolean addEmail( String eml, Vector emails )
  {
    if( !emails.contains( eml ) )
    {
      emails.addElement( eml );
      return true;
    }
    return false;
  }

  protected String getEmailList( Vector emails )
  {
    String rc = "";
    for( int i = 0; i < emails.size(); i++ )
    {
      String s = ( String )emails.elementAt( i );
      if( i > 0 ) rc = rc + ',';
      rc = rc + s;
    }
    return Util.isEmpty( rc ) ? "." : rc;
  }

  public boolean addToEmail( String eml )
  {
    return addEmail( eml, toEmails );
  }

  public boolean addBccEmail( String eml )
  {
    return addEmail( eml, bccEmails );
  }

  public boolean removeEmail( String eml )
  {
    boolean rc1 = toEmails.removeElement( eml );
    boolean rc2 = toEmails.removeElement( eml );
    return rc1 || rc2;
  }

  public boolean isInsertTask()
  {
    return insertTask;
  }

  public void setDatabaseHost()
  {
    try
    {
      DBAgent db = DBAgent.getInstance();
      Connection mainGenboreeConnection = db.getConnection();
      databaseHost = Database2HostTable.getHostForDbName( dataDBName, mainGenboreeConnection );
      db.closeConnection( mainGenboreeConnection );
    }
    catch( Exception ex )
    {
      ex.printStackTrace( System.err );
      System.err.println( "Exception unable to generate a connection in Uploader#setDatabaseHost" );
    }
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

	public void setSuppressEmail( boolean suppressEmail )
  {
    this.suppressEmail = suppressEmail;
  }

  public void removeAllEmails()
  {
    toEmails.clear();
    bccEmails.clear();
  }

  public String getToEmailList()
  {
    return getEmailList( toEmails );
  }

  public String getBccEmailList()
  {
    return getEmailList( bccEmails );
  }

  public String getFromAddress()
  {
    return fromAddress;
  }

  public void setFromAddress( String fromAddress )
  {
    this.fromAddress = fromAddress;
  }

  public String getSmtpHost()
  {
    return smtpHost;
  }

  public void setSmtpHost( String smtpHost )
  {
    this.smtpHost = smtpHost;
  }

  public GenboreeUser getUser()
  {
    return user;
  }

  public void setUser( GenboreeUser user )
  {
    this.user = user;
  }

  public String getRefSeqId()
  {
    return refseqId;
  }

  public void setRefSeqId( String refseqId )
  {
    this.refseqId = refseqId;
  }

  public int getErrorLevel()
  {
    return errorLevel;
  }

  public void setErrorLevel( int errorLevel )
  {
    this.errorLevel = errorLevel;
  }

  public boolean gzipFastaFile()
  {
    boolean retVal = true;
    int exitValue = -10;
    if( fastaFile == null || fastaFile.length() < 1 )
    {
      retVal = false;
    } else
    {
      String cmd = Constants.GB_GZIP + " -q " + fastaFile;
      try
      {
        Process pr = Runtime.getRuntime().exec( cmd );
        // Let's try pretty well ignoring whether this succeeds or not
        exitValue = pr.waitFor();
        retVal = ( exitValue == 0 );
      }
      catch( Exception ex )
      {
        System.err.println( "ERROR: FastaEntrypointUploader.java: Launching daemon process failed. Details:\n" );
        ex.printStackTrace( System.err );
      }
    }
    return retVal;
  }
  /* ------------------------------------------------------------------------
* PUBLIC METHODS
* --------------------------------------------------------------------- */

  public boolean startIt()
  {
    /* We will run the uploader as a daemon thread. */
    try
    {
      thr = new Thread( this );
      thr.setDaemon( true );
      thr.start();
      return thr.isDaemon();
    } catch( Exception ex )
    {
      System.err.println( "EXCEPTION: FastaEntrypointUploader.java: Could not start daemon thread. Details:\n" );
      ex.printStackTrace( System.err );
      debugInfo.append( "EXCEPTION: FastaEntrypointUploader.java: Could not start daemon thread. Details:\n" );
      debugInfo.append(ex.getMessage()).append( "\n" );
    }
    finally
    {
      DirectoryUtils.printErrorMessagesToAFile( getFastaFile() + ".log", true, getDebugInfo() );
    }
    return false;
  }

  public void run()
  {
    Exception ex = null;
    boolean permissionToUpload = false;

    try
    {
      Date startDate = new Date();
      SimpleDateFormat dfmt = new SimpleDateFormat( "EEE MMM d HH:mm:ss z yyyy" );
      dfmt.setTimeZone( TimeZone.getTimeZone( "GMT" ) );
      String gmtStartDate = dfmt.format( startDate );

      String cmd = binary + " -d " + dataDBName + " -f " + fastaFile;
      debugInfo.append( "LOG: FastaEntrypointUploader.java: upload command is:\n  " + cmd  + "\n");
      Process pr = null;
      String stderr = "";
      String stdout = "";

      // Get permission for delete.
      if( isInsertTask() && getTaskId() < 1 )
      {
        StringBuffer fastaUploaderCmdLine = new StringBuffer();
        fastaUploaderCmdLine.append( Constants.JAVAEXEC ).append( " " ).append( Constants.UPLOADERCLASSPATH );
        fastaUploaderCmdLine.append( Constants.FASTAFILEUPLOADERCLASS );
        fastaUploaderCmdLine.append( " -u " ).append( user.getUserId() ).append( " -r " ).append( refseqId );
        fastaUploaderCmdLine.append( " -f " ).append( fastaFile );


        long local_taskId = TasksTable.insertNewTask( fastaUploaderCmdLine.toString(), Constants.PENDING_STATE );
        debugInfo.append( "Inside the deleter The id in the TaskTable is " + local_taskId + "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%\n\n\n" );
        debugInfo.append( fastaUploaderCmdLine.toString() + "\n");
        setTaskId( local_taskId );
        setInsertTask( false );
        debugInfo.append( "After the task is inserted the state is " + TasksTable.getStateFromId( getTaskId() ) + "\n");

      }
      if( getTaskId() > 0 && !isInsertTask() )
        TasksTable.setStateBits( getTaskId(), Constants.RUNNING_STATE | Constants.PENDING_STATE );


      debugInfo.append( "After the setStateBit the state is " + TasksTable.getStateFromId( getTaskId() ) + " and the isInsertTassk is " + isInsertTask()  + "\n");

      permissionToUpload = BigDBOpsLockFile.getPermissionForBigDbOperation( dataDBName, databaseHost, approxNumberRecords );

      if( getTaskId() > 0 && !isInsertTask() )
        TasksTable.clearStateBits( getTaskId(), Constants.PENDING_STATE );
      debugInfo.append( "After the clearStateBit the state is " + TasksTable.getStateFromId( getTaskId() ) + " and the isInsertTassk is " + isInsertTask() + "\n");

      // (A) Try to run the uploader command as a Process.
      try
      {
        pr = Runtime.getRuntime().exec( cmd );
        InputStream p_in = pr.getInputStream();
        InputStream p_err = pr.getErrorStream();
        StringBuffer sb = new StringBuffer();
        int c;
        int cnt = 0;
        while( ( c = p_in.read() ) != -1 )
        {
          sb.append( ( char )c );
          if( ++cnt > 2048 ) break;
        }
        stdout = sb.toString();
        sb.setLength( 0 );
        cnt = 0;
        while( ( c = p_err.read() ) != -1 )
        {
          sb.append( ( char )c );
          if( ++cnt > 2048 ) break;
        }
        stderr = sb.toString();
        errorLevel = pr.waitFor();
      }
      catch( Exception ex01 )
      {
        ex = ex01;
      }

      debugInfo.append( "LOG: FastaEntrypointUploader.java: fasta uploader STDERR:\n" + stderr + "\n\n" );
      debugInfo.append( "LOG: FastaEntrypointUploader.java: fasta uploader STDOUT:\n" + stdout + "\n" );

      if( errorLevel != 0 )
      {
        stdout = "FATAL ERROR: FastaEntrypointUploader.java: fasta uploader cmd gave errorLevel =" + errorLevel;
      }

      int numRecs = -1;

      // (B) Try gzipping the fasta file now that we are done with it.
      boolean gzipOk = gzipFastaFile();
      if( !gzipOk )
      {
        debugInfo.append( "ERROR: FastaEntrypointUploader.java: gzipping fasta file failed. (fasta file: " + fastaFile + ")\n" );
      }

      Date endDate = new Date();
      String gmtEndDate = dfmt.format( endDate );

			if(!this.suppressEmail)
      {
			// (C) Try to send email to the user with results.
				if( !this.toEmails.isEmpty() ) // Make sure we have someone to send email to first.
				{
					File ff = new File( fastaFile );
					SendMail m = new SendMail();
					m.setHost( this.smtpHost );
					m.setFrom( this.fromAddress );
					m.setReplyTo( this.fromAddress );
					m.addTo( getToEmailList() );
					m.addBcc( getBccEmailList() );

					String subj = "Genboree: Fasta 'entrypoint' upload";
					StringBuffer bodyBuff = new StringBuffer();
					bodyBuff.append( "Hello" + ( user != null ? ( " " + user.getName() ) : "" ) + "," );
					bodyBuff.append( "\nYour 'entrypoint' fasta upload " +  "from file "  + fastaFile + " has completed.\n\n" );

					if( errorLevel != 0 ) // then something bad happened.
					{
						subj += " FAILED.";
						bodyBuff.append( "However, it was NOT successfully completed.\n" );
						bodyBuff.append( "Please contact the Genboree admin (" + GenboreeConfig.getConfigParam( "gbAdminEmail" ) + ") with the following information for assistance:\n\n" );
						bodyBuff.append( "\nStarted at:  " + ( gmtStartDate != null ? gmtStartDate : "unknown" ) );
						bodyBuff.append( "\nFinished at: " + ( gmtEndDate != null ? gmtEndDate : "unknown" ) );
						bodyBuff.append( "\nError Code:  " + errorLevel );
						bodyBuff.append( "\nLocal file:  " + ff.getName() );
						bodyBuff.append( "\nLogin Name:  " + ( user != null ? user.getName() : "not needed" ) );
						bodyBuff.append( "\nDB id:       " + ( this.refseqId != null ? this.refseqId : this.dataDBName ) );
						bodyBuff.append( "\n\nWe apologize for any inconvenience,\nThe Genboree Team\n" );
					} else // everything should have gone ok.
					{
						subj += " completed successfully";
						bodyBuff.append( "The fasta record(s) you uploaded were used as 'entrypoint' (e.g. chromosome) definitions and the sequence(s) made available within the browser." );
						bodyBuff.append( "\n\nThank you for using Genboree,\nThe Genboree Team\n" );
					}

					m.setSubj( subj );
					m.setBody( bodyBuff.toString() );
					m.go();
				}
			}
      if( getTaskId() > 0 && !isInsertTask() )
        TasksTable.clearStateBits( getTaskId(), Constants.RUNNING_STATE );
      debugInfo.append(  "After the clearStateBit the state is " + TasksTable.getStateFromId( getTaskId() ) + " and the isInsertTassk is " + isInsertTask() + "\n");

    }
    catch( Exception __ex )
    {
      if( getTaskId() > 0 && !isInsertTask() )
        TasksTable.setStateBits( getTaskId(), Constants.FAIL_STATE );
      ex = __ex;
      System.err.println(  "ERROR: FastaEntrypointUploader.java: problem uploading fasta file and sending email. Details:\n\n" );
      ex.printStackTrace( System.err );
      debugInfo.append(  "ERROR: FastaEntrypointUploader.java: problem uploading fasta file and sending email. Details:\n\n" );
      debugInfo.append( ex.getMessage() + "\n");
    }
    finally
    {
          DirectoryUtils.printErrorMessagesToAFile( getFastaFile() + ".log", true, getDebugInfo() );
      // Must release lock!
      BigDBOpsLockFile.releasePermissionForBigDbOperation( dataDBName, databaseHost );
    }
  } // END: public void run()

  public static void printUsage()
  {
    System.out.print( "usage: FastaEntrypointUploader " );
    System.out.println( "-r refSeqId  -f fastaFileName -u userId \n" +
            "Optional [\n" +
            "\t-k { turn task insertion off default on } \n" +
            "\t-s { turn email off default on } \n" +
            "\t-y { taskId, if taskId is not present and taskid is provided error would be generated } \n" +
            "\t-h fullDatabaseName\n"
    );
  }

  public static void main( String[] args )
  {
    String refseqId = null;
    String userId = null;
    String fastaFile = null;
    boolean insertTask = true;
    long taskId = -1;
    String bufferString = null;
    boolean suppressEmail = false;
    String dataDBName = null;
    FastaEntrypointUploader fastaUploader = null;


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
        } else if( args[ i ].compareToIgnoreCase( "-u" ) == 0 )
        {
          i++;
          if( args[ i ] != null )
          {
            userId = args[ i ];
          }
        } else if( args[ i ].compareToIgnoreCase( "-h" ) == 0 )
        {
          i++;
          if( args[ i ] != null )
          {
            dataDBName = args[ i ];
          }
        } else if( args[ i ].compareToIgnoreCase( "-y" ) == 0 )
        {
          i++;
          if( args[ i ] != null )
          {
            bufferString = args[ i ];
            taskId = Util.parseLong( bufferString, -1 );
            if( taskId > 0 )
              insertTask = false;
          }
        } else if( args[ i ].compareToIgnoreCase( "-f" ) == 0 )
        {
          i++;
          if( args[ i ] != null )
          {
            fastaFile = args[ i ];
          }
        } else if( args[ i ].compareToIgnoreCase( "-k" ) == 0 )
        {
          insertTask = false;
        } else if( args[ i ].compareToIgnoreCase( "-s" ) == 0 )
        {
          suppressEmail = true;
        }

      }

    } else
    {
      printUsage();
      System.exit( -1 );
    }

    if( refseqId == null || fastaFile == null )
    {
      printUsage();
      System.exit( -1 );
    }
    fastaUploader = new FastaEntrypointUploader( refseqId, fastaFile, userId );
    fastaUploader.setTaskId( taskId );
    fastaUploader.setInsertTask( insertTask );
		fastaUploader.setSuppressEmail( suppressEmail );
    Thread thr2 = new Thread( fastaUploader );
    thr2.start();


    try
    {
      thr2.join();
    }
    catch( InterruptedException e )
    {
      e.printStackTrace( System.err );
    }
    exitError = fastaUploader.getErrorLevel();
    //  System.err.println(uploader.getStderr());
    if( exitError == 0 )
    {
      System.out.println( "Fasta File was uploaded successfully!" );
      System.out.flush();
    } else
    {
      System.err.println( "Fasta file failed to upload!" );
    }
    System.exit( exitError );

  }


} // END: public class FastaEntrypointUploader
