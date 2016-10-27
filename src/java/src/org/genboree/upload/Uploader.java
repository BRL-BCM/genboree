package org.genboree.upload;

import org.genboree.util.*;

import java.util.*;
import java.io.File;
import java.io.IOException;

import org.genboree.dbaccess.util.* ;
import org.genboree.dbaccess.* ;

import java.io.*;
import java.sql.Connection;

public class Uploader implements Runnable
{
  protected DBAgent db = null ;
  protected boolean toMerge = true;
  protected boolean decompressFile = false;
  protected boolean missingInfo = false;
  protected boolean debug = false;
  protected boolean individualEmails = false;
  protected int errorLevel;
  protected static String bccAddress = GenboreeConfig.getConfigParam("gbAdminEmail") ;
  protected String binary = Constants.RUBY + " " + Constants.LFFVALIDATOR;
  protected String propFile = Constants.LFFMERGER_MULTILEVEL;
  protected String inputFile = null;
  protected String maxRecords = "3000000";
  protected String refseqFile = null;
  protected String fromAddress = "\"Genboree Team\" <" + GenboreeConfig.getConfigParam("gbFromAddress") + ">";
  protected String smtpHost = Util.smtpHost;
  protected String refseqId;
  protected String lineNumber = "1";
  protected String fileFormat = "lff";
  protected StringBuffer stderr;
  protected StringBuffer stdout;
  protected int sleepTime = LffConstants.uploaderSleepTime;
  protected Vector toEmails = new Vector();
  protected Vector bccEmails = new Vector();
  protected Thread thr = null;
  protected String genboreeUserId = null;
  protected String[] additionalUsers = null;
  protected String genboreeGroupId = null;
  protected String emailSubject = null;
  protected String emailBody = null;
  protected String gmtStartDate = null;
  protected String gmtEndDate = null;
  protected StringBuffer debugInfo = null;
  protected File formattedFile = null;
  protected File origFileName = null;
  protected boolean ignoreEntryPoints = false;
  protected boolean deleteAnnotations = false;
  protected boolean deleteEntryPoints = false;
  protected boolean deleteAnnotationsAndFtypes = false;
  protected boolean compressContent = true;
  protected boolean validateFile = true;
  protected boolean suppressEmail = false;
  protected int maxNumberOfInserts = LffConstants.defaultNumberOfInserts;
  protected int numberOfRecords = -1;
  protected int numberOfParsedRecords = -1;
  protected int numberOfInsertions = -1;
  protected int numberOfUpdates = -1;
  protected String timmingInfo = null;
  protected boolean cleanOldTables = false;
  protected boolean commandLine = false;
  protected HashMap extraOptions = null;
  protected int rubyBlockSize = 10000;
  protected String databaseName = null;
  protected String refName = null ;
  protected String databaseHost = null;
  protected long approxNumberRecords = -1;
  protected boolean insertTask = true;
  protected long taskId = -1;
  protected String[] listOfForbiddenTracks = null;
  protected boolean permissionToUseDb = false;


  public Uploader()
  {
    missingInfo = true;
  }

  public Uploader( String refseqId, String inputFile, String[] usersId, String inputFormat, boolean suppressEmail )
  {
    permissionToUseDb = GenericDBOpsLockFile.getPermissionForDbOperation(GenericDBOpsLockFile.MAIN_GENB_DB);
    setSuppressEmail( suppressEmail );
    setInputFile( inputFile );
    setRefSeqId( refseqId );
    setDatabaseName( refseqId );
    setDatabaseHost( getDatabaseName(), false );
    this.refName = RefSeqTable.getRefSeqNameByRefSeqId(refseqId, this.db) ;

    setRubyBlockSize();
    setFileFormat( inputFormat );
    setDecompressFile( true );
    initializeStringBuffers();
    if( !isSuppressEmail() )
    {
      setAdditionalUsers( usersId );
      if( getGenboreeUserId() != null && getRefSeqId() != null )
        setGenboreeGroupId( GenboreeUtils.fetchGroupId( getRefSeqId(), getGenboreeUserId(), false ) );
      else
        missingInfo = true;

      addToEmail( GenboreeUtils.fetchUserEmail( getGenboreeUserId(), false ) );
      String[] remainingUsers = getAdditionalUsers();
      if( remainingUsers != null && remainingUsers.length > 0 )
      {
        for( int i = 0; i < remainingUsers.length; i++ )
          addToEmail( GenboreeUtils.fetchUserEmail( remainingUsers[ i ], false) );
      }

      addBccEmail( bccAddress );
      setSmtpHost( Util.smtpHost );
      setFromAddress( fromAddress );
    }
    permissionToUseDb = GenericDBOpsLockFile.releasePermissionForDbOperation(GenericDBOpsLockFile.MAIN_GENB_DB);

  }

  public Uploader( String refseqId, String inputFile, String userId, String groupId, String inputFormat )
  {
    permissionToUseDb = GenericDBOpsLockFile.getPermissionForDbOperation(GenericDBOpsLockFile.MAIN_GENB_DB);
    setInputFile( inputFile );
    setRefSeqId( refseqId ) ;
    setDatabaseName( refseqId ) ;
    setDatabaseHost( getDatabaseName(), false) ;
    this.refName = RefSeqTable.getRefSeqNameByRefSeqId(refseqId, this.db) ;

    setGenboreeUserId( userId );
    setRubyBlockSize();
    if( groupId != null )
      setGenboreeGroupId( groupId );
    else
      setGenboreeGroupId( GenboreeUtils.fetchGroupId( getRefSeqId(), getGenboreeUserId(), false ) );
    initializeStringBuffers();
    setFileFormat( inputFormat );

    addToEmail( GenboreeUtils.fetchUserEmail( getGenboreeUserId(), false ) );

    addBccEmail( bccAddress );
    setSmtpHost( Util.smtpHost );
    setFromAddress( fromAddress );

    if( getGenboreeUserId() == null || getRefSeqId() == null )
      missingInfo = true;
    permissionToUseDb = GenericDBOpsLockFile.releasePermissionForDbOperation(GenericDBOpsLockFile.MAIN_GENB_DB);
  }


  public String getDatabaseHost()
  {
    return databaseHost;
  }

  public void setDatabaseHost( String databaseName)
  {
    setDatabaseHost(databaseName, true);
  }

  public void setDatabaseHost( String databaseName, boolean doCache)
  {
    Connection conn = null;
    DBAgent db = null;
    try
    {
        db = DBAgent.getInstance();
        this.db = db ;
        if(doCache)
        {
          conn = db.getConnection();
        }
        else
        {
          conn = db.getNoCacheConnection(null);
        }

      this.databaseHost = Database2HostTable.getHostForDbName( databaseName, conn );
    }
    catch( Exception ex )
    {
      ex.printStackTrace( System.err );
      System.err.println( "Exception unable to generate a connection in Uploader#setDatabaseHost" );
    }
    finally{
      db.safelyCleanup( null, null, conn );
    }
  }

  public String getDatabaseName()
  {
    return databaseName;
  }

  public void setDatabaseName( String refSeqId )
  {
    this.databaseName = GenboreeUtils.fetchMainDatabaseName( refSeqId, false );
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

  public long getApproxNumberRecords()
  {
    return approxNumberRecords;
  }

  public void setApproxNumberRecords( String inputFile )
  {
    this.approxNumberRecords = BigDBOpsLockFile.estimateNumLFFRecsInFile( inputFile );
  }

  public int getSleepTime()
  {
    return sleepTime;
  }

  public void setSleepTime( int sleepTime )
  {
    this.sleepTime = sleepTime;
  }

  public void initializeStringBuffers()
  {
    stderr = new StringBuffer( 200 );
    stdout = new StringBuffer( 200 );
  }

  public int getRubyBlockSize()
  {
    return rubyBlockSize;
  }

  public void setRubyBlockSize()
  {
    this.rubyBlockSize = Util.parseInt( DirectoryUtils.getValueFromPropertyFile( "rubyBlockSize" ), 9000 );
  }

  public String getTimmingInfo()
  {
    return timmingInfo;
  }

  public HashMap getExtraOptions()
  {
    return extraOptions;
  }

  public void setExtraOptions( HashMap extraOptions )
  {
    this.extraOptions = extraOptions;
  }

  public void setMaxNumberOfInserts( int maxNumberOfInserts )
  {
    this.maxNumberOfInserts = maxNumberOfInserts;
  }

  public int getMaxNumberOfInserts()
  {
    return maxNumberOfInserts;
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

  public boolean isCommandLine()
  {
    return commandLine;
  }

  public void setCommandLine( boolean commandLine )
  {
    this.commandLine = commandLine;
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

  public boolean isSuppressEmail()
  {
    return suppressEmail;
  }

  public void setSuppressEmail( boolean suppressEmail )
  {
    this.suppressEmail = suppressEmail;
  }

  public boolean isValidateFile()
  {
    return validateFile;
  }

  public void setValidateFile( boolean validateFile )
  {
    this.validateFile = validateFile;
  }


  public boolean isCompressContent()
  {
    return compressContent;
  }

  public void setCompressContent( boolean compressContent )
  {
    this.compressContent = compressContent;
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


  public boolean isIndividualEmails()
  {
    return individualEmails;
  }

  public void setIndividualEmails( boolean individualEmails )
  {
    this.individualEmails = individualEmails;
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

  public Vector getToEmails()
  {
    return toEmails;
  }

  public void setToEmails( Vector toEmails )
  {
    this.toEmails = toEmails;
  }

  public String getEmailSubject()
  {
    return emailSubject;
  }

  public void setEmailSubject( String emailSubject )
  {
    this.emailSubject = emailSubject;
  }

  public String getEmailBody()
  {
    return emailBody;
  }

  public void setEmailBody( String emailBody )
  {
    this.emailBody = emailBody;
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

  public String[] getAdditionalUsers()
  {
    return additionalUsers;
  }

  public void setAdditionalUsers( String[] allUsers )
  {
    if( allUsers == null || allUsers.length < 1 )
      return;
    int numberOfUsers = allUsers.length;
    boolean thereAreExtraUsers = ( numberOfUsers > 1 );
    setGenboreeUserId( allUsers[ 0 ] );

    if( thereAreExtraUsers )
    {
      String[] additionalUsers = new String[numberOfUsers - 1];
      int a = 0;
      for( int i = 1; i < allUsers.length; i++, a++ )
      {
        additionalUsers[ a ] = allUsers[ i ];
      }
      this.additionalUsers = additionalUsers;
    }
  }

  public boolean isDecompressFile()
  {
    return decompressFile;
  }

  public void setDecompressFile( boolean decompressFile )
  {
    this.decompressFile = decompressFile;
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

  public String getBinary()
  {
    return binary;
  }

  public void setBinary( String binary )
  {
    this.binary = binary;
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

  public String getMaxRecords()
  {
    return maxRecords;
  }

  public void setMaxRecords( String maxRecords )
  {
    this.maxRecords = maxRecords;
  }

  public String getRefseqFile()
  {
    return refseqFile;
  }

  public void setRefseqFile( String refseqFile )
  {
    this.refseqFile = refseqFile;
  }

  protected String getEmailList( Vector emails )
  {
    String sep = ",";
    String rc = "";
    for( int i = 0; i < emails.size(); i++ )
    {
      String s = ( String )emails.elementAt( i );
      if( i > 0 ) rc = rc + sep;
      rc = rc + s;
    }
    return Util.isEmpty( rc ) ? "." : rc;
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

  protected boolean addEmail( String eml, Vector emails )
  {
    if( !emails.contains( eml ) )
    {
      emails.addElement( eml );
      return true;
    }
    return false;
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

  public void removeAllEmails()
  {
    toEmails.clear();
    bccEmails.clear();
  }


  private void sendEmailToAllUsers( String mainUser, String[] remainingUsers )
  {
    boolean congrats = ( getErrorLevel() == 0 );
    String newBody = null;
    int numberOfUsers = 0;

    if( remainingUsers == null )
    {
      if( mainUser != null )
        numberOfUsers = 1;
    } else
      numberOfUsers = remainingUsers.length + 1;

    if( congrats )
    {
      newBody = "\n\n" + getEmailBody() ;
    }
    else
    {
      if( numberOfUsers > 1 )
        newBody = "Hello,\n\n" + getEmailBody();
      else
      {
        if(mainUser == null || mainUser.length() == 0)
        {
          newBody = "Hello,\n\n" ;
        }
        else
        {
          newBody = "Hello " + GenboreeUtils.fetchUserFullName( mainUser ) + ",\n\n" ;
        }
        newBody += getEmailBody() ;
      }
    }

    SendMail sendMailObject = new SendMail();
    sendMailObject.init();
    sendMailObject.setHost( getSmtpHost() );
    sendMailObject.setFrom( getFromAddress() );
    sendMailObject.setReplyTo( getFromAddress() );
    sendMailObject.addTo( getToEmailList() );
    sendMailObject.addBcc( getBccEmailList() );
    sendMailObject.setSubj( getEmailSubject() );
    sendMailObject.setBody( newBody );
    sendMailObject.go();
  }

  private void sendEmailToEachUser( String mainUser, String[] remainingUsers )
  {
    String[] allUsers = null;
    int numberOfUsers = 0;
    boolean congrats = ( getErrorLevel() == 0 );
    String newBody = null;

    numberOfUsers = remainingUsers.length + 1;

    allUsers = new String[numberOfUsers];
    allUsers[ 0 ] = mainUser;
    for( int i = 0; i < remainingUsers.length; i++ )
      allUsers[ i + 1 ] = remainingUsers[ i ];

    for( int i = 0; i < allUsers.length; i++ )
    {
      newBody = "Hello" + GenboreeUtils.fetchUserFullName( allUsers[ i ] ) + ",\n\n" +  getEmailBody() ;

      SendMail sendMailObject = new SendMail();
      sendMailObject.setHost( getSmtpHost() );
      sendMailObject.setFrom( getFromAddress() );
      sendMailObject.setReplyTo( getFromAddress() );
      sendMailObject.addTo( GenboreeUtils.fetchUserEmail( allUsers[ i ], false ) );
      sendMailObject.addBcc( getBccEmailList() );
      sendMailObject.setSubj( getEmailSubject() );
      sendMailObject.setBody( newBody );
      sendMailObject.go();
    }

  }

  // T O DO add the step where the error occurred
  protected void constructBodySubject( String numRecs, String numberOfLines,
                                       String numberOfParsedRecords, String numberOfInsertedRecords,
                                       String numberOfUpdatedRecords )
  {
    String subj = "Your Genboree upload ";
    String body = "";
    String grpName = GenboreeUtils.fetchGroupName( getGenboreeGroupId() ) ;

    // The errors to handle are  errorLevel==0 (No errors)|| errorLevel==10 (Some errors)
    // || errorLevel==20 (Too many errors)|| errorLevel==30 (Fatal error)
    if( errorLevel == 30 )
    {
      subj = subj + "HAD A FATAL ERROR, the upload FAILED.";
      body = "There was a FATAL error uploading your data.\n" +
              "Please contact " + GenboreeConfig.getConfigParam("gbAdminEmail") + " with the following information:\n\n";
      body += "Job details:\n" ;
      if(grpName != null)
      {
        body += "Group: " + GenboreeUtils.fetchGroupName( getGenboreeGroupId() ) + "\n" ;
      }
      body += "Database ID: " + getRefSeqId() + "\n" +
              "Database Name: " + this.refName + "\n" +
              "File Name: " + getOrigFileName().getName() + "\n" +
              "Started at: " + getGmtStartDate() + "\n" +
              "Finished at: " + getGmtEndDate() + "\n\n";

      body += stdout + "\n" + stderr + "\n\n" +
              "We apologize for any inconvenience,\n" +
              "Genboree Team\n";
    }
    else if( errorLevel == 20 )
    {
      subj = subj + "HAD TOO MANY ERRORS.";
      body = "There were too many errors uploading your data.\n" +
              "Please fix the following errors before reattempting your upload.\n\n";

      body += "Job details:\n" ;
      if(grpName != null)
      {
        body += "Group: " + GenboreeUtils.fetchGroupName( getGenboreeGroupId() ) + "\n" ;
      }
      body += "Database ID: " + getRefSeqId() + "\n" +
              "Database Name: " + this.refName + "\n" +
              "File Name: " + getOrigFileName().getName() + "\n" +
              "Started at: " + getGmtStartDate() + "\n" +
              "Finished at: " + getGmtEndDate() + "\n\n";

      body += stderr + "\n\n";

      body = body + "We apologize for any inconvenience,\nGenboree Team\n";
    }
    else if( errorLevel == 10 )
    {
      subj = subj + "is complete but with some errors..";
      body = "We encountered serveral errors during the upload process; however, " +
              "we were able to upload most of the annotations.\n\n";

      body += "Job details:\n" ;
      if(grpName != null)
      {
        body += "Group: " + GenboreeUtils.fetchGroupName( getGenboreeGroupId() ) + "\n" ;
      }
      body += "Database ID: " + getRefSeqId() + "\n" +
              "Database Name: " + this.refName + "\n" +
              "File Name: " + getOrigFileName().getName() + "\n" +
              "Number of Lines: " + numberOfLines.trim() + "\n" +
              "Number of Records parsed: " + numberOfParsedRecords.trim() + "\n" +
              "Number of Records inserted: " + numberOfInsertedRecords.trim() + "\n" +
              "Number of Records updated: " + numberOfUpdatedRecords.trim() + "\n" +
              "Started at: " + getGmtStartDate() + "\n" +
              "Finished at: " + getGmtEndDate() + "\n\n";

      body += stderr + "\n\n";

      body += "We apologize for any inconvenience,\n" +
              "Genboree Team\n";
    }
    else if( errorLevel == 0 )
    {
      subj += " is complete (no errors)";
      body = "The process of validating and uploading your data (from file " +
              getOrigFileName().getName() + ") was successful.\n\n" +
              "Your file contained " + numberOfLines.trim() + " lines from which " + numberOfParsedRecords.trim() +
              " were parsed successfully.\n" + numberOfInsertedRecords.trim() + " records were inserted and " +
              numberOfUpdatedRecords.trim() + " were updated to your database named '" + this.refName + "') \n\n" +
              "Began at: " + getGmtStartDate() + "\nEnding at " +
              getGmtEndDate() + ".\n\n" +
              "You can now login to Genboree and visualize your data.\n\n\n" +
              "The Genboree Team\n";
    }
    else if( errorLevel == 34 )
    {
      subj += " was rejected because the file is too big to upload";

      body += "ERROR: the file " + getOrigFileName().getName() + " is too big to upload in one big chunk.\n" +
              "Please consider splitting the huge file into smaller, more manageable \n" +
              "files, or even consider culling the data. Your file contains " + getApproxNumberRecords() +
              " and the maximum number of recores allowed is " + GenboreeConfig.getLongConfigParam( "maxNumRecs", -1 )
              + " .\n\n\n";

      body += "Job details:\n" ;
      if(grpName != null)
      {
        body += "Group: " + GenboreeUtils.fetchGroupName( getGenboreeGroupId() ) + "\n" ;
      }
      body += "Database ID: " + getRefSeqId() + "\n" +
              "Database Name: " + this.refName + "\n" +
              "File Name: " + getOrigFileName().getName() + "\n" +
              "Started at: " + getGmtStartDate() + "\n" +
              "Finished at: " + getGmtEndDate() + "\n\n";


      body += "\nThe Genboree Team\n";
    }
    else if( errorLevel == 41 )
    {
      subj += " was rejected because you do not have access to some of the tracks";
      StringBuffer tempSB = null;


    if( listOfForbiddenTracks  != null && listOfForbiddenTracks.length > 0 )
    {
      tempSB = new StringBuffer(200);
      for( int i = 0; i < listOfForbiddenTracks.length; i++ )
        tempSB.append("\t").append(listOfForbiddenTracks[ i ]).append( "\n" );
    }


      body += "ERROR: the file " + getOrigFileName().getName() + " contains the following unauthorized tracks:\n\n" +
              tempSB.toString() + "\n" +
              "Please consider requesting access to the tracks to your group administrator or replace the name of the tracks. \n" +
              "\n\n\n";

      body += "Job details:\n" ;
      if(grpName != null)
      {
        body += "Group: " + GenboreeUtils.fetchGroupName( getGenboreeGroupId() ) + "\n" ;
      }
      body += "Database ID: " + getRefSeqId() + "\n" +
              "Database Name: " + this.refName + "\n" +
              "File Name: " + getOrigFileName().getName() + "\n" +
              "Started at: " + getGmtStartDate() + "\n" +
              "Finished at: " + getGmtEndDate() + "\n\n";


      body += "\nGenboree Team\n";
    }

    setEmailSubject( subj );
    setEmailBody( body );
    return;
  }


  public static HashMap uploadData( int errorLevel, String refSeqId, String userId, String groupId,
                                    String fileToUpload, boolean ignoreRefSeq, boolean truncateTables,
                                    boolean deleteEntryPoints, boolean deleteAnnotationsAndFtypes,
                                    int maxNumberOfInserts, int timeSleep, boolean cleanOldTables )
  {
    return uploadData( errorLevel, refSeqId, userId, groupId,
            fileToUpload, ignoreRefSeq, truncateTables,
            deleteEntryPoints, deleteAnnotationsAndFtypes,
            maxNumberOfInserts, timeSleep, cleanOldTables, System.err );
  }


  public static HashMap uploadData( int errorLevel, String refSeqId, String userId, String groupId,
                                    String fileToUpload, boolean ignoreRefSeq, boolean truncateTables,
                                    boolean deleteEntryPoints, boolean deleteAnnotationsAndFtypes,
                                    int maxNumberOfInserts, int timeSleep, boolean cleanOldTables, PrintStream fullLogStream )
  {
    int numRecs = -1;
    StringBuffer info = null;
    HashMap results = new HashMap();
    AnnotationUploader currentUpload = null;
    fullLogStream.println( "Inside the uploadData method" );
    fullLogStream.flush();
    TimingUtil uploadDataTimer = null;
    uploadDataTimer = new TimingUtil();
    uploadDataTimer.addMsg( "Inside the upoadData method" );

    if( errorLevel == 0 || errorLevel == 10 )
    {
      String databaseNameInUse = GenboreeUtils.fetchMainDatabaseName( refSeqId, false );
      boolean validRefseqId = DatabaseCreator.checkIfRefSeqExist( refSeqId, databaseNameInUse, false );
      uploadDataTimer.addMsg( "after validating database" );
      if( validRefseqId )
      {
        currentUpload = new AnnotationUploader( refSeqId, userId, groupId, databaseNameInUse, fullLogStream );
        if( cleanOldTables )
          currentUpload.cleanOldTables();

        currentUpload.setFullLogFile( fullLogStream );

        info = currentUpload.getDebugInfo(); // This gets us a *pointer* (reference) to the debugInfo property of currentUpload
        // Debug: check that we are using the right settings:
        info.append( "\n\nAnnotationUploader#uploadData(): maxNumberOfInserts = " ).append( currentUpload.getMaxNumberOfInserts() ).append( "\n" );
        info.append( "AnnotationUploader#uploadData(): maxSizeOfBufferInBytes = " ).append( currentUpload.getMaxSizeOfBufferInBytes() ).append( "\n" );
        // Start timing the whole upload
        currentUpload.timer.addMsg( "BEGIN: AnnotationUploader#uploadData()" );
        currentUpload.setIgnore_refseq( ignoreRefSeq );
        currentUpload.setIgnore_assembly( true );


        if( truncateTables )
          currentUpload.truncateTables();
        if( deleteEntryPoints )
          currentUpload.deleteRefseqs();
        if( deleteAnnotationsAndFtypes )
          currentUpload.truncateAllTables();


        currentUpload.setSleepTime( timeSleep );
//                currentUpload.setSleepTime(0);
        currentUpload.setMaxNumberOfInserts( maxNumberOfInserts );

        currentUpload.setLffFile( fileToUpload );
        currentUpload.timer.addMsg( "DONE: set ignores, truncate/delete tables where needed" );

        uploadDataTimer.addMsg( "before uploading lff file" );
        boolean fileLoaded = currentUpload.loadLffFile();
        uploadDataTimer.addMsg( "after uploading lff file" );

        currentUpload.timer.addMsg( "DONE: loadLffFile" );
        results.put( "uploaderTimeInfo", currentUpload.getTimmingInfo() );
        results.put( "groupAssignerTimeInfo", currentUpload.getGroupAssignerTimmerInfo() );
        numRecs = currentUpload.getCurrentLffLineNumber();
        info.append( "\n\n" ).append( "NUMBER OF LINES =" ).append( numRecs ).append( "\n" );
        info.append( "\n\n" ).append( "NUMBER OF PARSED RECORDS=" ).append( currentUpload.getAnnotationsSuccessfullyParsed() ).append( "\n" );
        info.append( "\n\n" ).append( "NUMBER OF INSERTED RECORDS=" ).append( currentUpload.getAnnotationsForInsertion() ).append( "\n" );
        info.append( "\n\n" ).append( "NUMBER OF UPDATED RECORDS=" ).append( currentUpload.getAnnotationsForUpdate() ).append( "\n" );


      }
      // Stop timing the whole upload
      if( currentUpload != null )
      {
        currentUpload.timer.addMsg( "DONE: AnnotationUploader#uploadData()" );
        // Append the timing report now that we are all done
        if( info != null )
        {
          info.append( "\n---------------------\n" ).append( currentUpload.timer.generateStringWithReport() ).append( "\n------------------------\n" );
        }
      }
      results.put( "info", info );
      results.put( "numberOfLines", "" + numRecs );
      results.put( "numberOfParsedRecords", "" + currentUpload.getAnnotationsSuccessfullyParsed() );
      results.put( "numberOfInsertedRecords", "" + currentUpload.getAnnotationsForInsertion() );
      results.put( "numberOfUpdatedRecords", "" + currentUpload.getAnnotationsForUpdate() );
    }

    uploadDataTimer.addMsg( "Ending uploadData method" );
    results.put( "uploadDataTimeInfo", uploadDataTimer.generateStringWithReport() );
    return results;
  }


  public boolean startIt()
  {
    try
    {
      thr = new Thread( this );
      thr.setDaemon( true );
      thr.start();
      return thr.isDaemon();
    } catch( Exception ex )
    {
    }
    return false;
  }


  public void run()
  {
    File localOriginalFile = null;
    File parentDir = null;
    String newFile = null;
    String nameOfExtractedFile = null;
    String fileWithEntryPoints = null;
    boolean permissionToUpload = false;
    TimingUtil timer = new TimingUtil();
    int numRecs = -1;
    HashMap outPut = null;
    Integer tempErrorLevel = null;
    String validatorMode = null;
    StringBuffer infoFromUploader = null;
    HashMap resultsUploader = null;
    String numberOfLines = null;
    String numberOfParsedRecords = null;
    String numberOfInsertedRecords = null;
    String numberOfUpdatedRecords = null;
    boolean failAtSomePoint = false;
    PrintStream pout = null;


    File fullLog = new File( getInputFile() + ".full.log" );

    timer.addMsg( "Uploader begins" );

    debugInfo = new StringBuffer( 100 );
    setGmtStartDate( DirectoryUtils.returnFormatedGMTTime() );
    debugInfo.append( "Starting the run at " ).append( getGmtStartDate() ).append( "\n" );

    try
    {
      fullLog.createNewFile();
      pout = new PrintStream( new FileOutputStream( fullLog.getAbsolutePath() ) );
    } catch( FileNotFoundException e )
    {
      e.printStackTrace( System.err );
    } catch( IOException e )
    {
      e.printStackTrace( System.err );
    }

    permissionToUseDb = GenericDBOpsLockFile.getPermissionForDbOperation(GenericDBOpsLockFile.MAIN_GENB_DB);
    pout.println( "Starting upload for file " + getInputFile() );
    pout.flush();


    try
    {
      localOriginalFile = new File( getInputFile() );
      setOrigFileName( localOriginalFile );
      parentDir = new File( localOriginalFile.getParent() );
    }
    catch( NullPointerException ex )
    {
      System.err.println( "Uploader#run(): Unable to localize the fileName, please use full path and verify permissions" );
      System.exit( 30 );
    }

    debugInfo.append( "the original file is " ).append( getInputFile() ).append( "\n" );
    if( isDecompressFile() )
    {
      outPut = CommandsUtils.extractUnknownCompressedFile( getInputFile(), false );
      if( outPut != null && !outPut.isEmpty() )
      {
        setStdout( ( String )outPut.get( "stdout" ) );
        setStderr( ( String )outPut.get( "stderr" ) );
        tempErrorLevel = ( Integer )outPut.get( "errorLevel" );
        setErrorLevel( tempErrorLevel.intValue() );
        nameOfExtractedFile = ( String )outPut.get( "uncompressedFile" );
        if( nameOfExtractedFile != null )
          setInputFile( nameOfExtractedFile );
      } else
      {
        setErrorLevel( 30 );
        setStdout( "" );
        setStderr( "Error: Empty file" );
      }
    } else
    {
      setErrorLevel( 0 );
      setStdout( "" );
      setStderr( "" );
    }

    setApproxNumberRecords( getInputFile() );
    if( isInsertTask() && getTaskId() < 1 )
    {

      StringBuffer uploaderCmdLine = new StringBuffer();
      uploaderCmdLine.append( Constants.JAVAEXEC ).append( " " ).append( Constants.UPLOADERCLASSPATH ).append( Constants.UPLOADERCLASS );
      uploaderCmdLine.append( " -u " ).append( getGenboreeUserId() ).append( " -r " ).append( this.getRefSeqId() ).append( " -f " ).append( inputFile ).append( " -t " ).append( fileFormat );

      if( extraOptions != null && extraOptions.size() > 0 )
      {
        for( Object key : extraOptions.keySet() )
        {
          String value = ( String )extraOptions.get( ( String )key );
          uploaderCmdLine.append( " --" ).append( key );
          if( value != null && value.length() > 0 )
            uploaderCmdLine.append( "=" ).append( value ).append( " " );
        }
      }
      long local_taskId = TasksTable.insertNewTask( uploaderCmdLine.toString(), Constants.PENDING_STATE , false);
      System.err.println( "Inside the uploader The id in the TaskTable is " + local_taskId + "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%\n\n\n" );
      System.err.println( uploaderCmdLine.toString() );
      setTaskId( local_taskId );
      setInsertTask( false );
    }


    debugInfo.append( "after compression the file name is  " ).append( getInputFile() ).append( "\n" );
    System.err.println( "The database name is " + getDatabaseName() + " the databaseHost is " + getDatabaseHost() +
            " the approximate number of records in file are " + getApproxNumberRecords() + " the file name is " + getInputFile() );
    System.err.flush();
    boolean tooManyRecords = BigDBOpsLockFile.isTooManyRecords( getApproxNumberRecords() );
    if( tooManyRecords ) // So I have too many records so I need to get an accurate number of records
    {
      long linesInLffFile = -1;

      linesInLffFile = DirectoryUtils.getNumberLinesUsingWc( getInputFile() );
      this.approxNumberRecords = linesInLffFile;
      tooManyRecords = BigDBOpsLockFile.isTooManyRecords( getApproxNumberRecords() );
    }

    if( tooManyRecords )
    {
      setErrorLevel( 34 );
      constructBodySubject( "", "", "", "", "" );

      if( isIndividualEmails() )
        sendEmailToEachUser( getGenboreeUserId(), getAdditionalUsers() ); // send one message per user
      else
        sendEmailToAllUsers( getGenboreeUserId(), getAdditionalUsers() ); // send a single message to all user
      if( isCommandLine() )
        System.exit( getErrorLevel() );
      else
        return;
    }

    if( getApproxNumberRecords() < 1 ) this.approxNumberRecords = 1;
    // NOTE: must have ALL this in try-catch for Throwable so we can attempt to decrease the lock counter
    try
    {
      if( getTaskId() > 0 && !isInsertTask() )
        TasksTable.setStateBits( getTaskId(), Constants.RUNNING_STATE | Constants.PENDING_STATE, false );

      permissionToUseDb = GenericDBOpsLockFile.releasePermissionForDbOperation(GenericDBOpsLockFile.MAIN_GENB_DB);

      permissionToUpload = BigDBOpsLockFile.getPermissionForBigDbOperation( getDatabaseName(), getDatabaseHost(), getApproxNumberRecords() );
      if( getTaskId() > 0 && !isInsertTask() )
        TasksTable.clearStateBits( getTaskId(), Constants.PENDING_STATE, false );
      debugInfo.append( "permission to upload is " ).append( permissionToUpload ).append( "\n" );
      debugInfo.append( "here1\n");
      timer.addMsg( "Starting the Merger permission to upload = " + permissionToUpload );

      if( getErrorLevel() == 0 )
      {
        debugInfo.append( "here2\n");
        fileWithEntryPoints = getInputFile() + ".entrypoints.lff";
        debugInfo.append( "here3\n");
        if( isDeleteEntryPoints() )
        {debugInfo.append( "here4\n");
          try
          {
            debugInfo.append( "here5\n");
            File entryPointsFile = new File( fileWithEntryPoints );
            entryPointsFile.createNewFile();
            debugInfo.append( "here6\n");
          } catch( IOException e )
          {
            debugInfo.append( "here7\n");
            e.printStackTrace( System.err );
          }
        }
debugInfo.append( "here8\n");
        debugInfo.append( "file with entryPoints is " ).append( getRefseqFile() ).append( "\n" );
debugInfo.append( "here9\n");
        outPut = CommandsUtils.transformToLff( getInputFile(), getFileFormat(), getExtraOptions() );
        setStdout( ( String )outPut.get( "stdout" ) );
        setStderr( ( String )outPut.get( "stderr" ) );
        tempErrorLevel = ( Integer )outPut.get( "errorLevel" );
        setErrorLevel( tempErrorLevel.intValue() );
        newFile = ( String )outPut.get( "formatedFile" );

        debugInfo.append( "file format is " ).append( getFileFormat() )
                .append( " and the new file is " ).append( newFile ).append( "\n" );

        debugInfo.append( "After running the transformer the stderr is " ).append( stderr ).append( "\n" );
        debugInfo.append( "After running the transformer the stdout is " ).append( stdout ).append( "\n" );
        debugInfo.append( "After running the transformer the errorLevel is " ).append( errorLevel ).append( "\n" );

        if( newFile != null )
          setFormattedFile( new File( newFile ) );
      }


      if( getFormattedFile() != null && ( getErrorLevel() == 0 || getErrorLevel() == 10 ) ) // then process resulting file
      {
        if( isValidateFile() )
        {
          // errorLevel:
          // 0  - no errors found! Upload and send confirmation email.
          // 10 - the data had some errors but not many  Upload and send confirmation email.
          // 30 - a fatal error occured. Send a fatal error email.
          // 20 - user data error. Send an error email

          GenboreeUtils.generateFileWithLffHeaders( fileWithEntryPoints, getRefSeqId(), getUserId());
          setRefseqFile( fileWithEntryPoints );

          if( isIgnoreEntryPoints() )
            validatorMode = " annos ";
          else
            validatorMode = " full ";


          String typeOfFormat = "";

          if( !GenboreeUtils.isRefSeqIdUsingNewFormat( getRefSeqId() ) )
            typeOfFormat = " -o ";


          String cmd = getBinary() + " -f " + Util.urlEncode(  getFormattedFile().getAbsolutePath() ) + " -t " +
                  validatorMode + " -n " + getLineNumber() + " -r " + getRubyBlockSize() +
                  " -e " + Util.urlEncode( getRefseqFile())  + typeOfFormat;

          debugInfo.append( "the command is " ).append( cmd ).append( "\n" );

          System.err.println( "The lff validator command is " + cmd );

          outPut = CommandsUtils.runCommandaCollectInfo( cmd, parentDir.getAbsolutePath() );
          setStdout( ( String )outPut.get( "stdout" ) );
          setStderr( ( String )outPut.get( "stderr" ) );
          tempErrorLevel = ( Integer )outPut.get( "errorLevel" );

          // MLGG modified on Feb 6 to support error on the converter
          int valError = tempErrorLevel.intValue();
          if( valError == 0 && errorLevel == 10 )
            setErrorLevel( errorLevel );
          else
            setErrorLevel( valError );
          // End of Feb 6 modification
          debugInfo.append( "After running the validator the stderr is " ).
                  append( stderr ).append( "\n" );
          debugInfo.append( "After running the validator the stdout is " ).
                  append( stdout ).append( "\n" );
          debugInfo.append( "After running the validator the errorLevel is " ).
                  append( errorLevel ).append( "\n" );

					// Sameer: We need to set failAtSomePoint=true even if the error level is 10 so that it
					// is consistent with the zoom level creater script. 
          //if( getErrorLevel() != 0 && getErrorLevel() != 10 )
					if(getErrorLevel() != 0)
          {
            failAtSomePoint = true;
          }
        }

        timer.addMsg( "Calling the uploadData" );

    ForbiddenTracksDetector forbiddenTracks = new ForbiddenTracksDetector(getInputFile(), getUserId(), refseqId);
    boolean hasForbiddenTracks = forbiddenTracks.hasForbiddenTracks();
    listOfForbiddenTracks = forbiddenTracks.getArrayWithForbiddenTracks();


    if(hasForbiddenTracks)
    {
      // new feature MLGG 04/30/08 send an email to the user telling him/her about the forbidden tracks
      failAtSomePoint = true;
      setErrorLevel( 41 );
      constructBodySubject( "", "", "", "", "" );

      if( isIndividualEmails() )
        sendEmailToEachUser( getGenboreeUserId(), getAdditionalUsers() ); // send one message per user
      else
        sendEmailToAllUsers( getGenboreeUserId(), getAdditionalUsers() ); // send a single message to all user

      permissionToUpload = BigDBOpsLockFile.releasePermissionForBigDbOperation( getDatabaseName(), getDatabaseHost() );
      setGmtEndDate( DirectoryUtils.returnFormatedGMTTime() );
      if( isCommandLine() )
        System.exit( getErrorLevel() );
      else
        return;
    }




        if( !failAtSomePoint )
        {
          resultsUploader = Uploader.uploadData( errorLevel, getRefSeqId(),
                  getGenboreeUserId(), getGenboreeGroupId(),
                  getFormattedFile().getAbsolutePath(), isIgnoreEntryPoints(),
                  isDeleteAnnotations(), isDeleteEntryPoints(), isDeleteAnnotationsAndFtypes(),
                  getMaxNumberOfInserts(), getSleepTime(), isCleanOldTables(), pout );
        }

        timer.addMsg( "finish uploadData" );
        if( !failAtSomePoint )
        {
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
          if( getTaskId() > 0 && !isInsertTask() )
              TasksTable.clearStateBits( getTaskId(), Constants.RUNNING_STATE | Constants.PENDING_STATE);
        }
      }
    }
    catch( Throwable th )
    {
      // record the error to Stderr
      debugInfo.append( "After running the uploader number of records in file = " ).append( stdout ).append( "\n" );
      if( getTaskId() > 0 && !isInsertTask() )
          TasksTable.setStateBits( getTaskId(), Constants.FAIL_STATE );
      System.err.println( "ERROR: Uploader#run(): " + th.toString() );
      th.printStackTrace( System.err );
      System.err.flush();
    }
    finally
    {
      permissionToUpload = BigDBOpsLockFile.releasePermissionForBigDbOperation( getDatabaseName(), getDatabaseHost() );
    }

    debugInfo.append( "After unlocking the file " ).append( "\n" );


    if( errorLevel != 0 && errorLevel != 10 && errorLevel != 20 && errorLevel != 30 )
    {
      stdout.append( "FATAL ERROR " + errorLevel );
      errorLevel = 30;
    }

    debugInfo.append( timer.generateStringWithReport() );
    timer = new TimingUtil();
    timer.addMsg( "Starting to send message" );

    setGmtEndDate( DirectoryUtils.returnFormatedGMTTime() );
    debugInfo.append( "End the run at " ).append( getGmtEndDate() ).append( "\n" );

    if( !isSuppressEmail() )
    {
      constructBodySubject( stdout.toString(), numberOfLines, numberOfParsedRecords, numberOfInsertedRecords, numberOfUpdatedRecords );

      if( isIndividualEmails() )
        sendEmailToEachUser( getGenboreeUserId(), getAdditionalUsers() ); // send one message per user
      else
        sendEmailToAllUsers( getGenboreeUserId(), getAdditionalUsers() ); // send a single message to all user
    }


    DirectoryUtils.printErrorMessagesToAFile( getInputFile() + ".log",
            isDebug(), getDebugInfo() );
    if( isCompressContent() )
      DirectoryUtils.compressContentOfDirectory( parentDir.getAbsolutePath() );

    timer.addMsg( "Uploader Ends" );
    timmingInfo = timer.generateStringWithReport();
    debugInfo.append( timmingInfo );
    if( !failAtSomePoint )
    {
      if( resultsUploader != null && !resultsUploader.isEmpty() )
      {
        String tempString = ( String )resultsUploader.get( "uploadDataTimeInfo" );
        if( tempString != null )
          debugInfo.append( tempString ).append( "\n" );

        tempString = ( String )resultsUploader.get( "uploaderTimeInfo" );
        if( tempString != null )
          debugInfo.append( tempString ).append( "\n" );

        tempString = ( String )resultsUploader.get( "groupAssignerTimeInfo" );
        if( tempString != null )
          debugInfo.append( tempString ).append( "\n" );

      }
    }


    if( isCommandLine() )
      System.exit( getErrorLevel() );

  }

  public static void printUsage()
  {
    System.out.print( "usage: Uploader " );
    System.out.println(
            "-f fileName -r refseqId \n " +
                    "Optional [\n" +
                    "\t-u genboreeUserIds (comma delimited eg: 1,2,3)\n" +
                    "\t-t typeOfFile ( lff, blat, blast, or agilent) \n" +  //, or gff ) ] ");
                    "\t-x { delete Entry Points} \n" +
                    "\t-s { suppress email } \n" +
                    "\t-o { delete Annotations } \n" +
                    "\t-d { delete data tables and ftype tables } \n" +
                    "\t-n { ignore entryPoints default update/insert entryPoints } \n" +
                    "\t-b { set the debugging off } \n" +
                    "\t-p sleep time between inserts \n" +
                    "\t-i { send individual emails } \n" +
                    "\t-w numberOfInserts (default Number of Inserts = " + LffConstants.defaultNumberOfInserts + ")\n" +
                    "\t-z { turn compression off default on } \n" +
                    "\t-v { turn validation off default on } \n" +
                    "]\n" );
    return;
  }


  public static void main( String[] args )
  {
    String fileName = null;
    String usersId = null;
    String refseqId = null;
    String inputFormat = null;
    String[] genboreeIds = null;
    String bufferString = null;
    boolean debugging = false;
    boolean individualizedEmails = false;
    boolean ignoreEntryPoints = false;
    boolean deleteAnnotations = false;
    boolean deleteEntryPoints = false;
    boolean compression = true;
    boolean validate = true;
    boolean suppressEmail = false;
    boolean deleteAnnotationsAndFtypes = false;
    int bufferSize = 0;
    boolean setBufferSize = false;
    int sleepTime = LffConstants.uploaderSleepTime;
    boolean modifySleepTime = false;

    int exitError = 0;

    if( args.length < 4 )
    {
      printUsage();
      System.exit( -1 );
    }


    if( args.length >= 1 )
    {

      for( int i = 0; i < args.length; i++ )
      {
        if( args[ i ].compareToIgnoreCase( "-f" ) == 0 )
        {
          i++;
          if( args[ i ] != null )
          {
            fileName = args[ i ];
          }
        } else if( args[ i ].compareToIgnoreCase( "-u" ) == 0 )
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
        } else if( args[ i ].compareToIgnoreCase( "-b" ) == 0 )
        {
          debugging = false;
        } else if( args[ i ].compareToIgnoreCase( "-n" ) == 0 )
        {
          ignoreEntryPoints = true;
        } else if( args[ i ].compareToIgnoreCase( "-z" ) == 0 )
        {
          compression = false;
        } else if( args[ i ].compareToIgnoreCase( "-v" ) == 0 )
        {
          validate = false;
        } else if( args[ i ].compareToIgnoreCase( "-x" ) == 0 )
        {
          deleteEntryPoints = true;
          deleteAnnotationsAndFtypes = true;
        } else if( args[ i ].compareToIgnoreCase( "-i" ) == 0 )
        {
          individualizedEmails = true;
        } else if( args[ i ].compareToIgnoreCase( "-o" ) == 0 )
        {
          deleteAnnotations = true;
        } else if( args[ i ].compareToIgnoreCase( "-d" ) == 0 )
        {
          deleteAnnotationsAndFtypes = true;
        } else if( args[ i ].compareToIgnoreCase( "-w" ) == 0 )
        {
          i++;
          if( args[ i ] != null )
          {
            bufferString = args[ i ];
            bufferSize = Util.parseInt( bufferString, -1 );
            if( bufferSize > 0 ) setBufferSize = true;
          }
        } else if( args[ i ].compareToIgnoreCase( "-s" ) == 0 )
        {
          suppressEmail = true;
          usersId = null;
          genboreeIds = null;
        } else if( args[ i ].compareToIgnoreCase( "-p" ) == 0 )
        {
          i++;
          if( args[ i ] != null )
          {
            bufferString = args[ i ];
            sleepTime = Util.parseInt( bufferString, -1 );
            if( sleepTime > -1 )
              modifySleepTime = true;
          }
        } else if( args[ i ].compareToIgnoreCase( "-r" ) == 0 )
        {
          i++;
          if( args[ i ] != null )
          {
            refseqId = args[ i ];
          }
        } else if( args[ i ].compareToIgnoreCase( "-t" ) == 0 )
        {
          i++;
          if( args[ i ] != null )
          {
            inputFormat = args[ i ];
          }
        }
      }

    } else
    {
      printUsage();
      System.exit( -1 );
    }

    if( usersId == null || genboreeIds == null )
      suppressEmail = true;


    org.genboree.upload.Uploader uploader = new Uploader( refseqId, fileName, genboreeIds, inputFormat, suppressEmail );
    if( uploader.isMissingInfo() )
    {
      printUsage();
      System.exit( -1 );
    }

    uploader.setDebug( debugging );
    uploader.setIgnoreEntryPoints( ignoreEntryPoints );
    uploader.setDeleteAnnotations( deleteAnnotations );
    uploader.setDeleteAnnotationsAndFtypes( deleteAnnotationsAndFtypes );
    uploader.setDeleteEntryPoints( deleteEntryPoints );
    uploader.setCompressContent( compression );
    uploader.setSleepTime( sleepTime );
    uploader.setValidateFile( validate );
    if( setBufferSize )
      uploader.setMaxNumberOfInserts( bufferSize );

    uploader.setIndividualEmails( individualizedEmails );
    Thread thr2 = new Thread( uploader );
    thr2.start();

    System.out.println( "Dear " + GenboreeUtils.fetchUserFullName( uploader.getGenboreeUserId() ) +
            " your file " + fileName );
    System.out.println( "will be submitted for uploading into the database " +
            "corresponding to refseqid = " + refseqId + " = " +
            GenboreeUtils.fetchMainDatabaseName( refseqId, false ) );
    System.out.println( "After the file finish uploading you will" +
            " receive and email to the following address "
            + GenboreeUtils.fetchUserEmail( uploader.getGenboreeUserId(), false ) );


    try
    {
      thr2.join();
    }
    catch( InterruptedException e )
    {
      e.printStackTrace( System.err );
    }
    exitError = uploader.getErrorLevel();
    System.err.println( uploader.getStderr() );

    System.exit( exitError );

  }
}
