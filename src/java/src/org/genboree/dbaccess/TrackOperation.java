package org.genboree.dbaccess ;

import java.io.* ;
import java.util.* ;
import java.sql.* ;
import org.genboree.util.* ;
import org.genboree.downloader.* ;
import org.genboree.upload.Uploader ;

public class TrackOperation extends Thread
{
  //------------------------------------------------------------------
  // mode IDs
  protected static String[] modeIds =
  {
    "Combine", "Intersect", "Non-Intersect"
  } ;

  protected static final int MODE_DEFAULT = -1 ;
  protected static final int MODE_COMBINE = 0 ;
  protected static final int MODE_INTERSECT = 1 ;
  protected static final int MODE_NONINTERSECT = 2 ;

  protected int mode ;
  protected static String[] modeLinks =
  {
    "lffBrowser.jsp?mode=Combine",
    "lffBrowser.jsp?mode=Intersect",
    "lffBrowser.jsp?mode=Non-Intersect"
  } ;

  public void setMode(int mode)
  {
    this.mode = mode ;
  }

  //------------------------------------------------------------------
  // condition IDs
  protected static String[] conditionIds =
  {
    "Any", "All"
  } ;

  protected static final int CONDITION_ANY = 0 ;
  protected static final int CONDITION_ALL = 1 ;
  protected HashMap resultsUploader = null ;

  protected int condition ;

  public void setCondition(int condition)
  {
    this.condition = condition ;
  }

  //------------------------------------------------------------------
  // path names to the LFF operation commands
  protected static final String rubyCmdPath = Constants.RUBY ; // ARJ: <-- Shouldn't need this, if servers confs are correct!!
  protected static final String lffCombineCmdPath = Constants.LFFCOMBINECMDPATH ;
  protected static final String lffIntersectCmdPath = Constants.LFFINTERSECTCMDPATH ;
  protected static final String lffNonIntersectCmdPath = Constants.LFFNONINTERSECTCMDPATH ;
  protected AnnotationDownloader downloader ;
  protected Uploader uploader ;
  protected int genboreeUserId = -1 ;

  //------------------------------------------------------------------
  // e-mail addresses
  protected Vector toEmails = new Vector() ;
  protected Vector bccEmails = new Vector() ;

  protected boolean addEmail(String eml, Vector emails)
  {
    if(!emails.contains(eml))
    {
      emails.addElement(eml) ;
      return true ;
    }
    return false ;
  }

  protected String getEmailList(Vector emails)
  {
    String sep = "," ;
    StringBuffer rc = new StringBuffer(100) ;
    for(int i = 0 ; i < emails.size() ; i++)
    {
      String s = (String) emails.elementAt(i) ;
      if(i > 0) rc.append(sep) ;
      rc.append(s) ;
    }
    return Util.isEmpty(rc.toString()) ? "." : rc.toString() ;
  }

  public boolean addToEmail(String eml)
  {
    return addEmail(eml, toEmails) ;
  }

  public String getToEmailList()
  {
    return getEmailList(toEmails) ;
  }

  public boolean addBccEmail(String eml)
  {
    return addEmail(eml, bccEmails) ;
  }

  public String getBccEmailList()
  {
    return getEmailList(bccEmails) ;
  }

  public boolean removeEmail(String eml)
  {
    boolean rc1 = toEmails.removeElement(eml) ;
    boolean rc2 = toEmails.removeElement(eml) ;
    return rc1 || rc2 ;
  }

  public void removeAllEmails()
  {
    toEmails.clear() ;
    bccEmails.clear() ;
  }

  protected String fromAddress ;
  public void setFromAddress(String fromAddress)
  {
    this.fromAddress = fromAddress ;
  }

  protected String smtpHost ;
  public void setSmtpHost(String smtpHost)
  {
    this.smtpHost = smtpHost ;
  }

  public int getGenboreeUserId()
  {
    return genboreeUserId ;
  }

  public void setGenboreeUserId( int genboreeUserId )
  {
    this.genboreeUserId = genboreeUserId ;
  }

  //------------------------------------------------------------------
  // reference sequence and genboree information
  protected GenboreeUser myself ;
  public void setMyself(GenboreeUser myself)
  {
    this.myself = myself ;
  }

  protected GenboreeGroup grp ;
  public void setGroup(GenboreeGroup grp)
  {
    this.grp = grp ;
  }

  protected RefseqSynch refSeq ;
  public void setRefSeq(Refseq refSeq)
  {
    this.refSeq = new RefseqSynch(refSeq) ;
  }

  protected String refSeqId ;
  public void setRefSeqId(String refSeqId)
  {
    this.refSeqId = refSeqId ;
  }

  //------------------------------------------------------------------
  // track class, type, and sub-type names
  protected String firstTrack ;
  protected String firstTrackClassName, firstTrackTypeName, firstTrackSubTypeName ;
  public void setFirstTrack(String firstTrack)
  {
    //System.err.println("first track"+firstTrack);
    this.firstTrack = firstTrack ;
    String[] stringBuffer = this.firstTrack.split(" : ") ;
    firstTrackTypeName = stringBuffer[0] ;
    firstTrackSubTypeName = stringBuffer[1] ;
  }

  protected String[] secondTrack ;
  protected String[] secondTrackClassName, secondTrackTypeName, secondTrackSubTypeName ;
  public void setSecondTrack(String[] secondTrack)
  {
    this.secondTrack = secondTrack ;
    secondTrackClassName = new String[secondTrack.length] ;
    secondTrackTypeName = new String[secondTrack.length] ;
    secondTrackSubTypeName = new String[secondTrack.length] ;

    for(int i = 0 ; i < secondTrack.length ; i++)
    {
      String[] stringBuffer = this.secondTrack[i].split(" : ") ;
      //System.err.println("second track"+secondTrack[i]);
      secondTrackTypeName[i] = stringBuffer[0] ;
      secondTrackSubTypeName[i] = stringBuffer[1] ;
    }
  }

  protected String[] combineTrack ;
  protected String[] combineTrackClassName, combineTrackTypeName, combineTrackSubTypeName ;
  public void setCombineTrack(String[] combineTrack)
  {
    this.combineTrack = combineTrack ;

    combineTrackClassName = new String[combineTrack.length] ;
    combineTrackTypeName = new String[combineTrack.length] ;
    combineTrackSubTypeName = new String[combineTrack.length] ;

    for(int i = 0 ; i < combineTrack.length ; i++)
    {
      String[] stringBuffer = this.combineTrack[i].split(" : ") ;
      combineTrackTypeName[i] = stringBuffer[0] ;
      combineTrackSubTypeName[i] = stringBuffer[1] ;
    }
  }

  protected String newTrackClassName, newTrackTypeName, newTrackSubTypeName ;
  public void setNewTrackClassName(String newTrackClassName)
  {
    this.newTrackClassName = newTrackClassName ;
  }

  public void setNewTrackTypeName(String newTrackTypeName)
  {
    this.newTrackTypeName = newTrackTypeName ;
  }

  public void setNewTrackSubTypeName(String newTrackSubTypeName)
  {
    this.newTrackSubTypeName = newTrackSubTypeName ;
  }

  public String getNewTrackClassName()
  {
    return newTrackClassName ;
  }

  //------------------------------------------------------------------
  // date and time
  protected java.util.Date startDate, endDate ;
  protected long queryStart, queryEnd, queryTime ;
  protected long conversionStart, conversionEnd, conversionTime ;
  protected long execRBStart, execRBEnd, execRBTime ;
  protected long uploadStart, uploadEnd, uploadTime ;

  //------------------------------------------------------------------
  // radius
  protected int radius ;
  public int getRadius()
  {
    return radius ;
  }

  public void setRadius(int radius)
  {
    this.radius = radius ;
  }

  //--------------------------------------------------------------------------
  // Minimum number of overlaps (intersections) annotation must have with
  // at least one track (or in -each- track if All is selected).
  protected int minNumOverlaps = 1 ;
  public int setMinNumOverlaps(int minNumOverlaps)
  {
    this.minNumOverlaps = minNumOverlaps ;
    return this.minNumOverlaps ;
  }

  //------------------------------------------------------------------
  // error level
  protected int errorLevel = -1 ;
  //------------------------------------------------------------------
  // number of records
  protected int numRecs = -1 ;
  //------------------------------------------------------------------
  // standard output and error string buffers
  protected StringBuffer stdout = new StringBuffer(50) ;
  protected StringBuffer stderr = new StringBuffer(50) ;
  //------------------------------------------------------------------
  // result set
  protected ResultSet resSet = null ;
  //------------------------------------------------------------------
  // file killer objects
  protected FileKiller fk = null ;
  protected FileKiller fkOutput = null ;
  //------------------------------------------------------------------
  // filter
  protected String filter ;
  public void setFilter(String filter)
  {
    this.filter = filter ;
  }

  //------------------------------------------------------------------
  // database
  protected DBAgent db ;
  public void setDB(DBAgent db)
  {
    this.db = db ;
  }

  //------------------------------------------------------------------
  // executable command string
  protected StringBuffer execCommand ;

  //------------------------------------------------------------------
  // work and output file
  protected File workFile ;
  protected File outputFile ;
  protected String workFileName ;
  protected String outputFileName ;

  public void setWorkFile(File workFile)
  {
    this.workFile = workFile ;
  }

  public void setOutputFile(File outputFile)
  {
    this.outputFile = outputFile ;
  }

  public void setWorkFileName(String workFileName)
  {
    this.workFileName = workFileName ;
  }

  public void setOutputFileName(String outputFileName)
  {
    this.outputFileName = outputFileName ;
  }

  //-----------------------------------------------------------------
  // "semaphores" (NOT in J2SE1.4, but will be in J2SE1.5)
  protected boolean trackOpThreadAvailable = true ;
  protected boolean queryAvailable = true ;
  protected boolean convertAvailable = true ;
  protected boolean executeAvailable = true ;
  protected boolean uploadAvailable = true ;

  //------------------------------------------------------------------
  // new tracks actively being operated on
  protected static List activeTracks = Collections.synchronizedList(new ArrayList()) ;
  public static boolean isNewTrackActive(String[] requestTrackName)
  {
    for(int i = 0 ; i < activeTracks.size() ; i++)
    {
      if( requestTrackName[0].equals(((String[]) activeTracks.get(i))[0]) &&
          requestTrackName[1].equals(((String[]) activeTracks.get(i))[1]) &&
          requestTrackName[2].equals(((String[]) activeTracks.get(i))[2]))
          return true ;
    }
    return false ;
  }

  //------------------------------------------------------------------
  // public methods and thread
  public TrackOperation()
  {
    queryStart = queryEnd = queryTime = 0 ;
    conversionStart = conversionEnd = conversionTime = 0 ;
    execRBStart = execRBEnd = execRBTime = 0 ;
    uploadStart = uploadEnd = uploadTime = 0 ;
    firstTrack = firstTrackClassName = firstTrackTypeName = firstTrackSubTypeName = null ;
    secondTrack = secondTrackClassName = secondTrackTypeName = secondTrackSubTypeName = null ;
    combineTrack = combineTrackClassName = combineTrackTypeName = combineTrackSubTypeName = null ;
    newTrackClassName = newTrackTypeName = newTrackSubTypeName = null ;
    execCommand = null ;
    workFile = null ;
    outputFile = null ;
    workFileName = null ;
    outputFileName = null ;
    filter = "bgc" ;
    radius = 0 ;
  }

  protected static Thread[] threadList = new Thread[10] ;
  protected static int currentIndex = 0 ;

  public void run()
  {
    try
    {
      runTrackOperation() ;
    }
    catch(SQLException e)
    {
      e.printStackTrace() ;  //To change body of catch statement use File | Settings | File Templates.
    }
  }

  public synchronized void runTrackOperation() throws SQLException
  {
    while(trackOpThreadAvailable == false)
    {
      try
      {
          wait() ;
      }
      catch(InterruptedException e)
      {
      }
    }

    trackOpThreadAvailable = false ;

    if(activeTracks == null)
    {
      activeTracks = new ArrayList() ;
    }

    String[] newTrack = new String[3] ;
    newTrack[0] = newTrackClassName ;
    newTrack[1] = newTrackTypeName ;
    newTrack[2] = newTrackSubTypeName ;
    activeTracks.add(newTrack) ;
    errorLevel = -1 ;
    numRecs = -1 ;
    startDate = new java.util.Date() ;

    // create temporary source LFF file for selected operation
    if(fk == null)
    {
      switch(mode)
      {
        case MODE_COMBINE:
          fk = new FileKiller("tempLffCombine", ".lff") ;
          break ;
        case MODE_INTERSECT:
          fk = new FileKiller("tempLffIntersect", ".lff") ;
          break ;
        case MODE_NONINTERSECT:
          fk = new FileKiller("tempLffNonIntersect", ".lff") ;
          break ;
      } ;
    }

    fk.put(workFileName, workFile) ;

    // create query of selected tracks
    queryStart = System.currentTimeMillis() ;
    queryTracks() ;
    queryEnd = System.currentTimeMillis() ;
    queryTime += (queryEnd - queryStart) ;

    // convert selected tracks to *.lff format
    conversionStart = System.currentTimeMillis() ;
    convertTracks() ;
    conversionEnd = System.currentTimeMillis() ;
    
    conversionTime += (conversionEnd - conversionStart) ;

    // create and execute command
    execRBStart = System.currentTimeMillis() ;
    executeOperation() ;
    if(errorLevel == 0)
    {
      execRBEnd = System.currentTimeMillis() ;
      execRBTime = execRBEnd - execRBStart ;

      // upload new lff file into database
      uploadStart = System.currentTimeMillis() ;
      uploadNewTrack() ;

      uploadEnd = System.currentTimeMillis() ;
      uploadTime = uploadEnd - uploadStart ;

      System.err.println("---------------TIMES IN MILLISECONDS---------------") ;
      System.err.println("Query time: " + queryTime) ;
      System.err.println("Conversion to temporary *.lff file time: " + conversionTime) ;
      System.err.println("Execution of operation via Ruby time: " + execRBTime) ;
      System.err.println("Upload new track into database time: " + uploadTime) ;
      System.err.println("----------------------------------------") ;

      endDate = new java.util.Date() ;
      activeTracks.remove(activeTracks.lastIndexOf(newTrack)) ;
    }
    else // op had problem
    {
      endDate = new java.util.Date() ;

      stdout.append("\nTrack operation issued the above error code.") ;
      stdout.append("\n\nPlease contact genboree_admin@genboree.org with that error code\nand the following information:") ;
      stdout.append("\n\nJob details:\n").append("Login Name: ").append(myself.getName()).append("\nGroup: ") ;
      stdout.append(grp.getGroupName()).append("\nDatabase ID: ").append(refSeqId).append("\nStarted at: ") ;
      stdout.append(startDate.toString()).append("\nFinished at: ").append(endDate.toString()) ;
      stdout.append("\n") ;
      stderr.setLength(0) ;
      sendEMailReply() ;
      errorLevel = -1 ;
    }
    System.err.println("###################################################") ;
    trackOpThreadAvailable = true ;
    notifyAll() ;
  }

  public synchronized void sendEMailReply()
  {
    if(errorLevel == 0 || errorLevel == 1 || errorLevel == 2 || errorLevel == -1)
    {
      SendMail m = new SendMail() ;
      m.setHost(smtpHost) ;
      m.setFrom(fromAddress) ;
      m.setReplyTo(fromAddress) ;
      m.addTo(getToEmailList()) ;
      m.addBcc(getBccEmailList()) ;

      StringBuffer subj = new StringBuffer("Your Genboree LFF operation job") ;
      StringBuffer body = new StringBuffer(100) ;
      if(errorLevel == -1)
      {
          subj = subj.append(" FAILED.") ;
          body = body.append( stdout.toString() + "\n" +
                              stderr.toString() + "\n\n" +
                              "We apologize for any inconvenience,\nThe Genboree Team\n") ;
      }
      else if(errorLevel == 1 || numRecs < 0)
      {
        subj = subj.append(" FAILED.") ;
        if(errorLevel != 1)
        {
          body = body.append( "There was a database problem while attempting to " +
                              "upload your new data.\n" +
                              "Please Contact administrator before attempting to repeat your upload.\n\n" +
                              "Meanwhile you can take a look at your data by following\n" +
                              "the link provided below.\n\n" + stdout.toString() + "\n\n") ;
        }
        body = body.append( "Job details:\n" +
                            "Login Name: " + myself.getName() + "\n" +
                            "Group: " + grp.getGroupName() + "\n" +
                            "Database ID: " + refSeqId + "\n" +
                            "Temporary work *.lff File: " + workFile.getName() + "\n" +
                            "Output *.lff File: " + outputFile.getName() + "\n" +
                            "Started at: " + startDate.toString() + "\n" +
                            "Finished at: " + endDate.toString() + "\n\n") ;
        if(errorLevel == 1)
        {
          body = body.append(stdout.toString() + "\n\n") ;
        }

        body = body.append("We apologize for any inconvenience,\nThe Genboree Team\n") ;
      }
      else
      {
        if(errorLevel == 0)
        {
          subj = subj.append(" is complete (no errors.)") ;
        }
        else
        {
          subj = subj.append(" is complete but with some errors.") ;
        }

        body = body.append( "Congratulations, " + myself.getFullName() + "!\n\n" +
                            "The process of using the " + modeIds[mode] +
                            " track operation and uploading your data has successfully finished.\n\n" +
                            stdout.toString() + numRecs + " record(s) were added.\n\n" +
                            "Thank you for using Genboree,\nThe Genboree Team\n") ;
      }
      m.setSubj(subj.toString()) ;
      m.setBody(body.toString()) ;
      m.go() ;
    }
  }

  public synchronized void queryTracks()
  {
    while(queryAvailable == false)
    {
      try
      {
          wait() ;
      }
      catch(InterruptedException e)
      {
      }
    }

    queryAvailable = false ;
    String[] processedTracks ;

    try
    {
      switch(mode)
      {
        case MODE_COMBINE:
          processedTracks = new String[combineTrack.length] ;
          for(int e = 0 ; e < combineTrack.length ; e++)
          {
            processedTracks[e] = combineTrack[e].replaceAll(" : ", ":") ;
          }
          downloader = new AnnotationDownloader(db, genboreeUserId, null, null, refSeqId, processedTracks, null, null, false) ;
          break ;
        case MODE_INTERSECT:
        case MODE_NONINTERSECT:
          // combine obtained parameters from first and second track fields
          processedTracks = new String[secondTrack.length + 1] ;
          processedTracks[0] = firstTrack.replaceAll(" : ", ":") ;
          for(int i = 0 ; i < secondTrack.length ; i++)
          {
            processedTracks[i + 1] = secondTrack[i].replaceAll(" : ", ":") ;
            //System.err.println("proce track "+processedTracks[i]);
          }
          downloader = new AnnotationDownloader(db, genboreeUserId,null, null, refSeqId, processedTracks, null, null, false) ;
          break ;
      }
    }
    catch(Exception ex)
    {
      // print out error stack via standard output
      System.err.println("----------------------------------------") ;
      System.err.println("EXCEPTION CAUGHT IN trackOps.jsp (query)") ;
      ex.printStackTrace() ;
      System.err.println("----------------------------------------") ;
    }
    queryAvailable = true ;
    notifyAll() ;
  }

  public synchronized void convertTracks()
  {
    while(convertAvailable == false)
    {
      try
      {
          wait() ;
      }
      catch(InterruptedException e)
      {
      }
    }

    convertAvailable = false ;
    PrintWriter fout = null ;

    try
    {
      fout = new PrintWriter(new FileWriter(workFileName)) ;
      downloader.downloadAnnotations(fout) ;
      if(fout != null)
      {
        fout.flush() ;
        fout.close() ;
      }
    }
    catch(Exception ex)
    {
      // print out error stack via standard output
      System.err.println("----------------------------------------") ;
      System.err.println("EXCEPTION CAUGHT IN trackOps.jsp (conversion)") ;
      ex.printStackTrace() ;
      System.err.println("----------------------------------------") ;
    }
    convertAvailable = true ;
    notifyAll() ;
  }

  public synchronized void executeOperation()
  {
    while(executeAvailable == false)
    {
      try
      {
          wait() ;
      }
      catch(InterruptedException e)
      {
      }
    }

    executeAvailable = false ;
    String trackNameWithEscapedSpaces ;
    execCommand = new StringBuffer() ;
    String[] args = new String[20] ;
    for(int ii=0; ii<args.length; ii++)
    {
      args[ii] = "" ;
    }
    // ARJ: can I say that this kind of code for arguments is retarded?
    args[2] = "-V" ;
    args[7] = "-l" ;
    args[9] = "-o" ;
    args[11] = "-n" ;
    try
    {
      StringBuffer tempBuff = new StringBuffer() ;
      switch(mode)
      {
        case MODE_COMBINE:
          args[0] = lffCombineCmdPath ;
          args[2] = "-V" ;
          args[3] = "-t" ;
          if(fkOutput == null)
          {
            fkOutput = new FileKiller("lffCombine", ".lff") ;
          }
          fkOutput.put(outputFileName, outputFile) ;

          // For greatest safety: The argument will be a URL encoded list of URL encoded track names.
          // This ensures that the track list delimiter (,) is double-escaped when
          // used in track names and that any raw %XX that are actually part of the
          // track name are doubly encoded as well (so they don't get unescaped during processing)
          for(int i = 0 ; i <= combineTrack.length - 1 ; i++)
          {
            // Create escape(type):escape(subtype)
            tempBuff.setLength(0) ;
            tempBuff.append(Util.urlEncode(combineTrackTypeName[i])).append(":").append(Util.urlEncode(combineTrackSubTypeName[i])) ;
            // Add escape(escape(type):escape(subtype)) to the list of track names argument
            execCommand.append(tempBuff.toString()) ;
            if(combineTrack.length != 1 && i != combineTrack.length - 1)
            {
              execCommand.append(",") ;
            }
          }
          // Now escape the whole CSV list
          args[4] = Util.urlEncode(execCommand.toString()) ;
          args[5] = "-l" ;
          args[6] = Util.urlEncode(workFileName) ;
          args[7] = "-o" ;
          args[8] = Util.urlEncode(outputFileName) ;
          args[9] = "-n" ;
          tempBuff.setLength(0) ;
          tempBuff.append(Util.urlEncode(newTrackTypeName)).append(":").append(Util.urlEncode(newTrackSubTypeName)) ;
          // Add escape(type):escape(subtype) as the -n arg value.
          args[10] = tempBuff.toString() ;
          for(int j = 11 ; j <= 17 ; j++)
          {
            args[j] = "" ;
          }
          break ;
        case MODE_INTERSECT:
          args[0] = lffIntersectCmdPath ;
          args[3] = "-f" ;
          tempBuff.setLength(0) ;
          tempBuff.append(Util.urlEncode(firstTrackTypeName)).append(":").append(Util.urlEncode(firstTrackSubTypeName)) ;
          // Add escape(type):escape(subtype) as -f arg value
          args[4] = tempBuff.toString() ;
          args[5] = "-s" ;

          if(fkOutput == null)
          {
            fkOutput = new FileKiller("lffIntersect", ".lff") ;
          }
          fkOutput.put(outputFileName, outputFile) ;

          // For greatest safety: The secondary tracks argument will be a URL encoded list of URL encoded track names.
          // This ensures that the track list delimiter (,) is double-escaped when
          // used in track names and that any raw %XX that are actually part of the
          // track name are doubly encoded as well (so they don't get unescaped during processing and thus retain their
          // real values in the track name)
          for(int i = 0 ; i <= secondTrack.length - 1 ; i++)
          {
            tempBuff.setLength(0) ;
            tempBuff.append(Util.urlEncode(secondTrackTypeName[i])).append(":").append(Util.urlEncode(secondTrackSubTypeName[i])) ;
            // Add escape(escape(type):escape(subtype)) to the list of track names argument
            execCommand.append(tempBuff.toString()) ;
            if(secondTrack.length != 1 && i != secondTrack.length - 1)
            {
              execCommand.append(",") ;
            }
          }
          // Now escape the whole CSV list
          args[6] = Util.urlEncode(execCommand.toString()) ;
          args[8] = Util.urlEncode(workFileName) ;
          args[10] = Util.urlEncode(outputFileName) ;
          tempBuff.setLength(0) ;
          tempBuff.append(Util.urlEncode(newTrackTypeName)).append(":").append(Util.urlEncode(newTrackSubTypeName)) ;
          // Add escape(type):escape(subtype) as the -n arg value
          args[12] = tempBuff.toString() ;
          if(radius != 0)
          {
            args[13] = "-r" ;
            args[14] = "" + radius ;
          }
          if(minNumOverlaps > 1)
          {
            args[18] = "-m" ;
            args[19] = "" + minNumOverlaps ;
          }
          break ;
        case MODE_NONINTERSECT:
          args[0] = lffNonIntersectCmdPath ;
          args[3] = "-f" ;
          tempBuff.setLength(0) ;
          tempBuff.append(Util.urlEncode(firstTrackTypeName)).append(":").append(Util.urlEncode(firstTrackSubTypeName)) ;
          // Add escape(type):escape(subtype) as -f arg value
          args[4] = tempBuff.toString() ;
          args[5] = "-s" ;

          if(fkOutput == null)
          {
            fkOutput = new FileKiller("lffNonIntersect", ".lff") ;
          }
          fkOutput.put(outputFileName, outputFile) ;

          // For greatest safety: The secondary tracks argument will be a URL encoded list of URL encoded track names.
          // This ensures that the track list delimiter (,) is double-escaped when
          // used in track names and that any raw %XX that are actually part of the
          // track name are doubly encoded as well (so they don't get unescaped during processing and thus retain their
          // real values in the track name)
          for(int i = 0 ; i <= secondTrack.length - 1 ; i++)
          {
            tempBuff.setLength(0) ;
            tempBuff.append(Util.urlEncode(secondTrackTypeName[i])).append(":").append(Util.urlEncode(secondTrackSubTypeName[i])) ;
            // Add escape(escape(type):escape(subtype)) to the list of track names argument
            execCommand.append(tempBuff.toString()) ;
            if(secondTrack.length != 1 && i != secondTrack.length - 1)
            {
              execCommand.append(",") ;
            }
          }
          // Now escape the whole CSV list
          args[6] = Util.urlEncode(execCommand.toString()) ;
          args[8] = Util.urlEncode(workFileName) ;
          args[10] = Util.urlEncode(outputFileName) ;
          tempBuff.setLength(0) ;
          tempBuff.append(Util.urlEncode(newTrackTypeName)).append(":").append(Util.urlEncode(newTrackSubTypeName)) ;
          // Add escape(type):escape(subtype) as the -n arg value
          args[12] = tempBuff.toString() ;
          if(radius != 0)
          {
            args[13] = "-r" ;
            args[14] = "" + radius ;
          }
          if(minNumOverlaps > 1)
          {
            args[18] = "-m" ;
            args[19] = "" + minNumOverlaps ;
          }
          break ;
      } ;
      if(getNewTrackClassName() != null && getNewTrackClassName().length() > 0)
      {
        args[15] = "-c" ;
        args[16] = Util.urlEncode(getNewTrackClassName()) ;
      }
      if((mode == MODE_INTERSECT || mode == MODE_NONINTERSECT) && condition == CONDITION_ALL)
      {
        args[17] = "-a" ;
      }
      else
      {
        args[17] = "" ;
      }
    }
    catch(Exception ex)
    {
      // print out error stack via standard output
      System.err.println("----------------------------------------") ;
      System.err.println("EXCEPTION CAUGHT IN trackOps.jsp (execution commmand creation)") ;
      ex.printStackTrace() ;
      System.err.println("----------------------------------------") ;
    }

    try
    {
      // ARJ: WTF is this kind of code?
      System.err.print("\n####################################\nTRACK OP (not-plugin). About to execute this command:\n  ") ;
      for(int ii = 0; ii<args.length; ii++)
      {
        System.err.print(" " + args[ii]) ;
      }

      File filePtr = new File(outputFileName) ;
      File parentDir = new File(filePtr.getParent()) ;
      StringBuffer cmdBuff = new StringBuffer() ;
      for(int ii=0; ii<args.length; ii++)
      {
        cmdBuff.append(args[ii]).append(" ") ;
      }
      String cmdStr = cmdBuff.toString() ;
      HashMap cmdOutputs = CommandsUtils.runCommandaCollectInfo(cmdStr, parentDir.getAbsolutePath()) ;
      errorLevel = ((Integer)(cmdOutputs.get("errorLevel"))).intValue() ;
      System.err.println("TRACK OP. Finished executing command. Exit status = " + errorLevel + "") ;
      System.err.println("\n---------------\nSTDERR:\n---------------\n" + (String)cmdOutputs.get("stderr") + "\n---------------") ;
      System.err.println("\n---------------\nSTDOUT:\n---------------\n" + (String)cmdOutputs.get("stdout") + "\n---------------") ;
    }
    catch(Exception ex)
    {
      // print out error stack via standard output
      System.err.println("----------------------------------------") ;
      System.err.println("EXCEPTION CAUGHT IN trackOps.jsp (lff operation)") ;
      ex.printStackTrace() ;
      System.err.println("----------------------------------------") ;
      fk.remove(workFileName) ;
      workFile.delete() ;
      outputFile.delete() ;
      return ;
    }

    if(errorLevel < 0 || errorLevel > 3)
    {
      stdout.append("TRACK OP reports a FATAL ERROR " + errorLevel) ;
      System.err.println(stdout.toString() + "\n") ;
      errorLevel = -1 ;
    }
    executeAvailable = true ;
    notifyAll() ;
  }

  public synchronized void uploadNewTrack() throws SQLException
  {
    boolean permissionToUpload = false ;
    String databaseName = GenboreeUtils.fetchMainDatabaseName(refSeqId) ;
    String databaseHost = GenboreeUtils.fetchDatabaseHost(databaseName) ;
    long approxNumberRecords = BigDBOpsLockFile.estimateNumLFFRecsInFile(outputFileName) ;
    System.err.println("---------------\nTrackOperation.java => Entering the uploader\n---------------") ;

    while(uploadAvailable == false)
    {
      try
      {
          wait() ;
      }
      catch(InterruptedException e)
      {
      }
    }
    uploadAvailable = false ;
    try
    {
      StringBuffer taskWrapper = new StringBuffer() ;
      taskWrapper.append(Constants.JAVAEXEC).append(" ").append(Constants.UPLOADERCLASSPATH) ;
      taskWrapper.append("-Xmx1800M org.genboree.util.TaskWrapper") ;
      taskWrapper.append(" -a -c ") ;
      StringBuffer uploaderCmdLine = new StringBuffer() ;
      uploaderCmdLine.append(Constants.JAVAEXEC).append(" ").append(Constants.UPLOADERCLASSPATH).append(Constants.UPLOADERCLASS) ;
      uploaderCmdLine.append(" -u ").append(myself.getUserId()).append(" -r ").append(refSeqId).append(" -f ").append(outputFileName).append(" -t ").append("lff").append(" -z ") ;
      File filePtr = new File(outputFileName) ;
      File parentDir = new File(filePtr.getParent()) ;
      String appendToEndOfTaskWrapper = "" ;
      if(DirectoryUtils.isDirectoryWrittable(parentDir.getAbsolutePath()))
      {
        appendToEndOfTaskWrapper = " > " + parentDir.getAbsolutePath() + "/errors.out 2>&1 &" ;
        appendToEndOfTaskWrapper = Util.urlEncode(appendToEndOfTaskWrapper) ;
      }

      taskWrapper.append(Util.urlEncode(uploaderCmdLine.toString())).append(" -e ").append(appendToEndOfTaskWrapper) ;
      RunExternalProcess rn = new RunExternalProcess(taskWrapper.toString()) ;
    }
    catch(Throwable th)
    {
      System.err.println("ERROR: TrackOpperation#uploadNewTrack(): " + th.toString()) ;
      th.printStackTrace(System.err) ;
      System.err.flush() ;
    }
    finally
    {
      uploadAvailable = true ;
      notifyAll() ;
    }
    uploadAvailable = true ;
    notifyAll() ;
  }
}
