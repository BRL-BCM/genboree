package org.genboree.util ;

import java.io.* ;
import java.nio.channels.* ;
import java.util.* ;
import org.genboree.util.* ;

public class BigDBOpsLockFile
{
  //--------------------------------------------------------------------------
  // CONSTANTS
  //--------------------------------------------------------------------------
  public static final int LOCK_SLEEP_TIME = 5000 ; // min time between retrying to get lock on file
  public static final int MAX_LOCK_RETRIES = 1280 ; // max number of times to try to get lock on file before failing
  public static final int SLEEPTIME = 6000 ; //default sleep time
  public static final int MINSLEEPTIME = 10000 ; //minimum sleep time
  public static final int MAXSLEEPTIME = 600000 ; //maximum sleep time
  public static final int BAD_NUM_RECS = -1 ;
  public static final int SMALL_NUM_RECS = 0 ;
  public static final int MED_NUM_RECS = 1 ;
  public static final int LARGE_NUM_RECS = 2 ;

  //--------------------------------------------------------------------------
  // PUBLIC CLASS METHODS
  //--------------------------------------------------------------------------
  // Get permission for a big db operation
  public static boolean getPermissionForBigDbOperation(String databaseName, String databaseHost, long numRecs)
  {
    System.err.println("====================================================") ;
    System.err.println((new java.util.Date()).toString() + " ASK PERMISSION for " + databaseName + " on " + databaseHost + " for " + numRecs + " records. ") ;
    System.err.println("====================================================") ;
    boolean retVal = false ;
    try
    {
      // Try to get permission to do a big Db Operation
      while(true)
      {
        // Call this *synchronized* method (1 thread at a time, only) to do file ops for us:
        boolean lockFileResult = BigDBOpsLockFile.updateBigDbOpsLockFile(databaseName, databaseHost, numRecs, true) ;
        if(lockFileResult) // Then we got permission and incremented the count for this dbName and dbHost in the lock file
        {
          retVal = true ;
          break ;
        }
        else // No permission yet. Maybe file locked in another process or maybe theMaxCount is exceeded. Wait and try again.
        {
          Util.sleep(BigDBOpsLockFile.returnSleepTimeScaledBySize(numRecs)) ;
        }
      }
    }
    catch(Throwable ex) // something bad happened
    {
      System.err.println("ERROR: BigDBOpsLockFile#getPermissionForBigDbOperation: Caught exception (bug!) trying to increments.") ;
      ex.printStackTrace(System.err) ;
      retVal = false ;
    }
    if(retVal)
    {
      System.err.println("====================================================") ;
      System.err.println((new java.util.Date()).toString() + " GRANTED PERMISSION for " + databaseName + " on " + databaseHost + " for " + numRecs + " records. ") ;
      System.err.println("====================================================") ;
    }
    else
    {
      System.err.println("====================================================") ;
      System.err.println((new java.util.Date()).toString() + " FAILED PERMISSION for " + databaseName + " on " + databaseHost + " for " + numRecs + " records. ") ;
      System.err.println("====================================================") ;
    }
    return retVal ;
  }

  // Release permission for a big db operation
  public static boolean releasePermissionForBigDbOperation(String databaseName, String databaseHost)
  {
    System.err.println("====================================================") ;
    System.err.println((new java.util.Date()).toString() + " RELEASE PERMISSION for " + databaseName + " on " + databaseHost + ".") ;
    System.err.println("====================================================") ;
    boolean retVal = false ;
    try
    {
      // Try to release permission to do a big Db Operation
      // Call this *synchronized* method (1 thread at a time, only) to do file ops for us:
      boolean lockFileResult = BigDBOpsLockFile.updateBigDbOpsLockFile(databaseName, databaseHost, false) ;
      if(!lockFileResult) // Then we had problems releasing a previously-granted permission. That's an error.
      {
        retVal = false ;
        throw new Exception("FAILED TO RELEASE BIG DB-OP PERMISSION FOR " + databaseName + " on host " + databaseHost) ;
      }
      else
      {
        retVal = true ;
      }
    }
    catch(Throwable ex) // something bad happened
    {
      System.err.println("ERROR: BigDBOpsLockFile#getPermissionForBigDbOperation(S,S): Caught exception (bug!) trying to increment.") ;
      ex.printStackTrace(System.err) ;
    }
    return retVal ;
  }

  // Ask if number recs is too big, for applications that know what to do with that.
  public static boolean isTooManyRecords(long numRecs)
  {
    boolean retVal = true ;
    try
    {
      long maxNumRecs = GenboreeConfig.getLongConfigParam("maxNumRecs", -1) ;
      if(maxNumRecs == -1)
      {
        throw new Exception("Couldn't get 'maxNumRecs' value from config file!") ;
      }
      else if(numRecs <= maxNumRecs)
      {
        retVal = false ;
      }
    }
    catch(Exception ex)
    {
      System.err.println("ERROR: BigDBOpsLockFile#isTooManyRecords(l): Caught exception trying to find maximum number of records in operation.") ;
      ex.printStackTrace(System.err) ;
    }
    return retVal ;
  }

  // Get a quick, rough estimate of the number of LFF records in a file.
  // - Generally, this is for feeding to BigDBOpsLockFile.getPermissionForBigDbOperation(S,S,l)
  public static long estimateNumLFFRecsInFile(String fileName)
  {
    long retVal = -1L ;
    if(fileName != null)
    {
      File originalFile = new File(fileName) ;
      if(originalFile.exists())
      {
        long fileSize = originalFile.length() ;
        retVal = fileSize / 150L ;
      }
    }
    return retVal ;
  }

  //--------------------------------------------------------------------------
  // PROTECTED CLASS MEHTODS
  // Not to be called directly. But inheritable if necessary.
  //--------------------------------------------------------------------------
  // Try to get lock on big Db ops lock file, try to increment value in file for this dbName and dbHost if we're allowed.
  // RULES:
  // 1) SMALL NUM RECS:
  //    - allow now or as soon as allowed
  //    - don't check host limit (allow multiple ops involving small number of recs)
  //    - op allowed if configured values for:
  //      . maxBigDbOpsGlobally not exceeded
  //      . maxBigDbOpsPerDB not exceeded
  // 2) MEDIUM NUM RECS:
  //    - allow now or as soon as allowed
  //    - op allowed only if configured values for:
  //      . maxBigDbOpsGlobally not exceeded
  //      . maxBigDbOpsPerDB not exceeded
  //      . maxBigDbOpsPerDBHost not exceeded
  // 3) LARGE NUM RECS:
  //    - allow only during a spcecific time period per day, if allowed
  //    - op allowed only if configured values for:
  //      . bigDbOpsTimePeriod contains the current time
  //      . maxBigDbOpsGlobally not exceeded
  //      . maxBigDbOpsPerDB not exceeded
  //      . maxBigDbOpsPerDBHost not exceeded
  protected synchronized static boolean updateBigDbOpsLockFile(String databaseName, String databaseHost, boolean incrementCount)
  {
    return updateBigDbOpsLockFile(databaseName, databaseHost, -1, incrementCount) ;
  }
  protected synchronized static boolean updateBigDbOpsLockFile(String databaseName, String databaseHost, long numRecs, boolean incrementCount)
  {
    boolean retVal = false ;
    try
    {
      // VALIDATE ARGUMENTS:
      // We noted some weird cases where databaseName and such is 'null'. What's with that? Not sure
      // but it is *wrong*. So we'll thrown an error when databaseName or databaseHost is null or 'null'.
      if(databaseName == null || databaseName.equalsIgnoreCase("null") || databaseHost == null || databaseHost.equalsIgnoreCase("null"))
      {
        System.err.println("ERROR: BigDBOpsLockFile.updateBigDbOpsLockFile(S,S,l,b) => called with nul or 'null' databaseName and/or databaseHost. " +
                           "That means some bad code is calling BigDBOpsLockFile.getPermissionForBigDbOperation() with some bad parameters and needs to be debugged. " +
                           "Throwing an error so this fatal situation is dealt with...hopefully stack trace will help track down the bad code.") ;
        throw new Exception("ERROR: BAD CODE is calling BigDBOpsLockFile.getPermissionForBigDbOperation() with null or 'null' arguments! use stack trace below to help track & fix.") ;
      }
      else // basic validation passed.
      {
        // FIRST: Get name of lock file, plus maxDbOps/dbHost and maxDbOps/dbName from config
        String dbOpsLockFile = GenboreeConfig.getConfigParam("bigDbOpsLockFile") ;
        int maxDbOpsGlobally = GenboreeConfig.getIntConfigParam("maxBigDbOpsGlobally", -1) ;
        int maxDbOpsPerHost = GenboreeConfig.getIntConfigParam("maxBigDbOpsPerDBHost", -1) ;
        int maxDbOpsPerDB = GenboreeConfig.getIntConfigParam("maxBigDbOpsPerDB", -1) ;
        int mediumNumRecs = GenboreeConfig.getIntConfigParam("mediumNumRecs", -1) ;
        int largeNumRecs = GenboreeConfig.getIntConfigParam("largeNumRecs", -1) ;
        Calendar[] bigDbOpTimePeriod = GenboreeConfig.getTimePeriodParam("bigDbOpTimePeriod") ;
        // SECOND: Get file lock on the lock file
        LockResourceSet lockResourceSet = new LockResourceSet() ;
        boolean gotFileLock = BigDBOpsLockFile.getFileLock(dbOpsLockFile, lockResourceSet) ;
        if(!gotFileLock) // We didn't get a file lock
        {
          System.err.println("ERROR: BigDBOpsLockFile.incrementBigDbOpsLockFile => couldn't get file lock on " + dbOpsLockFile + "! Does this user have write permission? Or was the file left locked by a killed process or something? Locks on this file should be very short (<1 sec)!") ;
          retVal = false ;
        }
        else // We got a file lock
        {
          // THRID: Read lock file lines
          // . while going through the file, keep track of:
          //   -- total number of large DB ops overall
          //   -- count number large DB ops for databaseName
          //   -- count number large DB ops for databaseHost
          BufferedReader reader = new BufferedReader(new FileReader(dbOpsLockFile)) ;
          HashMap<String,HashMap<String,Integer>> dbName2host = new HashMap<String,HashMap<String,Integer>>() ;
          String line ;
          int totalCount = 0 ;
          int countPerDatabaseHost = 0 ;
          int countPerDatabaseName = 0 ;
          // Each line in file is number of big DB ops per database per host count. No blanks, etc.
          while((line = reader.readLine()) != null)
          {
            // Parse line: 1st = databaseName, 2nd = databaseHost, 3rd = count
            String[] fields = line.split("\t") ;
            int count = Integer.parseInt(fields[2]) ;
            totalCount += count ;
            if(fields[0].equals(databaseName))
            {
              countPerDatabaseName += count ;
            }
            if(fields[1].equals(databaseHost))
            {
              countPerDatabaseHost += count ;
            }
            // . read whole file into HashMap of [databaseName] => [databaseHost] => count
            //   (we need this to be able to rewrite the file later)
            if(!dbName2host.containsKey(fields[0]))
            {
              dbName2host.put(fields[0], new HashMap<String,Integer>()) ;
            }
            HashMap<String,Integer> dbHostSubMap = dbName2host.get(fields[0]) ;
            if(!dbHostSubMap.containsKey(fields[1]))
            {
              dbHostSubMap.put(fields[1], count) ;
            }
            else // currently, the file should NOT have -multiple- rows with the same dbName,dbHost pair, but if it does just add them up
            {
              dbHostSubMap.put(fields[1], dbHostSubMap.get(fields[1]) + count) ;
            }
          }
          reader.close() ;

          // FOURTH: try to update count appropriately
          if(incrementCount)
          {
            // Do we have a small, medium, or large number of records?
            int numRecCategory =  ( (numRecs < mediumNumRecs) ? SMALL_NUM_RECS :
                                    (numRecs < largeNumRecs) ? MED_NUM_RECS :
                                    LARGE_NUM_RECS
                                  ) ;
            // Determine if we are allowed to do the big DB op or not:
            switch(numRecCategory)
            {
              case SMALL_NUM_RECS:
                retVal = ( (totalCount < maxDbOpsGlobally) && (countPerDatabaseName < maxDbOpsPerDB) ) ;
                break ;
              case MED_NUM_RECS:
                retVal = ( (totalCount < maxDbOpsGlobally) && (countPerDatabaseName < maxDbOpsPerDB) && (countPerDatabaseHost < maxDbOpsPerHost) ) ;
                break ;
              case LARGE_NUM_RECS:
                retVal =  ( (totalCount < maxDbOpsGlobally) &&
                            (countPerDatabaseName < maxDbOpsPerDB) &&
                            (countPerDatabaseHost < maxDbOpsPerHost) &&
                            (Util.isCurrTimeWithinTimePeriod(bigDbOpTimePeriod))
                          ) ;
                break ;
              default: // This is error situation
                // Release lock & release resources
                lockResourceSet.close() ;
                throw new Exception("ERROR: BigDBOpsLockFile.updateBigDbOpsLockFile(S,S.lb) => Must provide numRecs argument when incrementing a big DB op count. (Fatal code error).") ;
            }
            if(retVal) // Then allowed to do big Db Op, alter HaspMap and write out to lockFile
            {
              // Update HashMap of lock file contents
              HashMap<String,Integer> dbHostSubMap = dbName2host.get(databaseName) ;
              if(dbHostSubMap == null) // then this databaseName not even listed in the lock file yet
              {
                dbName2host.put(databaseName, new HashMap<String,Integer>()) ;
                dbName2host.get(databaseName).put(databaseHost, 1) ;
              }
              else // this databaseName is in there...
              {
                if(dbHostSubMap.containsKey(databaseHost)) // ...then this databaseHost is in there too, update it
                {
                  int currCount = dbHostSubMap.get(databaseHost) ;
                  dbHostSubMap.put(databaseHost,  currCount + 1) ;
                }
                else // ...this databaseHost is not in there, set count for it to be 1
                {
                  dbHostSubMap.put(databaseHost, 1) ;
                }
              }
            }
            // else not allowed to do a big Db op...will have to try again later or something
          }
          else // releasing permission, decrement the count
          {
            retVal = true ; // always allowed to try to release permission
            // Update HashMap of lock file contents
            HashMap<String,Integer> dbHostSubMap = dbName2host.get(databaseName) ;
            if(dbHostSubMap != null) // then this databaseName is in the file and may need updating
            {
              if(dbHostSubMap.containsKey(databaseHost)) // ...then this databaseHost is in there too, update it
              {
                int currCount = dbHostSubMap.get(databaseHost) ;
                dbHostSubMap.put(databaseHost, currCount - 1) ;
              }
            }
          }
          // FIFTH: Now write out the updated lock file contents if we got permission to do what we wanted.
          if(retVal)
          {
            PrintWriter writer = new PrintWriter(new BufferedWriter(new FileWriter(dbOpsLockFile))) ;
            for(Map.Entry<String,HashMap<String,Integer>> dbNameEntry : dbName2host.entrySet() )
            {
              String dbName = dbNameEntry.getKey() ;
              HashMap<String,Integer> dbHostMap = dbNameEntry.getValue() ;
              for(Map.Entry<String,Integer> dbHostEntry : dbHostMap.entrySet() )
              {
                // Only write the line if the count is > 0
                int currCount = dbHostEntry.getValue() ;
                if( currCount > 0)
                {
                  writer.println(dbName + "\t" + dbHostEntry.getKey() + "\t" + currCount ) ;
                }
              }
            }
            writer.close() ;
          }
          // SIXTH: Release lock & release resources
          lockResourceSet.close() ;
        }
      }
    }
    catch(Exception ex)
    {
      System.err.println("ERROR: BigDBOpsLockFile.incrementBigDbOpsLockFile => couldn't read bigDbOp lock file and check for permission to do a big DB Op. Check lock file looks correctly formatted, etc. Exception details: " + ex.getMessage()) ;
      ex.printStackTrace(System.err) ;
      retVal = false ;
    }
    return retVal ;
  }

  // Get a file lock, Java style.
  // - hand back the FileLock, FileChannel, and RandomAccessFile so the calling function can clean them up when done with file lock.
  protected static boolean getFileLock(String fileName, LockResourceSet out)
  {
    int retryCount = 0 ;
    boolean retVal = false ;
    Random rng = new Random() ;

    // Get File and RAF objects and a channel on which we'll try to get a lock
    File file = new File(fileName) ;
    try
    {
      out.raf = new RandomAccessFile(file, "rw") ;
    }
    catch(Exception ex)
    {
      System.err.println("ERROR: BigDBOpsLockFile.getFileLock(S,L) => couldn't open the file for writing (even if doesn't exist, should have been able to auto-create it, but that failed too.) Details: " + ex.getMessage()) ;
      ex.printStackTrace(System.err) ;
      return retVal ;
    }
    out.channel = out.raf.getChannel() ;

    // Try to get a file-lock so we can assess the contents for permission.
    while(true)
    {
      if(retryCount > MAX_LOCK_RETRIES)
      {
        retVal = false ;
        break ;
      }
      else
      {
        retryCount += 1 ;
        try
        {
          out.lock = out.channel.tryLock() ;
          retVal = true ;
          break ;
        }
        catch(OverlappingFileLockException ofle) // Someone else is using the file, try again soon.
        {
          try
          {
            int randExtra = (rng.nextInt(LOCK_SLEEP_TIME) + 1) ;
            Util.sleep( (LOCK_SLEEP_TIME * retryCount) + randExtra ) ;
          }
          catch(Exception ex)
          {
          }
        }
        catch(IOException ioe) // Some serious IO problem occurred
        {
          System.err.println("ERROR: BigDBOpsLockFile.getFileLock(S,L) => fatal problem trying for lock on file. Details: " + ioe.getMessage()) ;
          ioe.printStackTrace(System.err) ;
          retVal = false ;
          break ;
        }
      }
    }
    return retVal ;
  }

  // Returns a time to sleep that is big for large number of records and small for small number of records.
  protected static long returnSleepTimeScaledBySize(long numRecs)
  {
    /*
      Does a kind of bounded exponential time based on file size.
      Time to sleep ranges from ~MINSLEEPTIME to ~MAXSLEEPTIME.
      Log-based scaling in the calculation results in:
      - 1,000 estimated records means sleep ~2 sec
      - 10,000 estimated records means sleep ~3 sec
      - 100,000 estimated records means sleep ~12 sec
      - 1,000,000 estimated records means sleep ~102 sec
    */
    long time = BigDBOpsLockFile.MINSLEEPTIME ;
    double orderFactor = Math.log10(numRecs) ;
    double adjOrderFactor = ((orderFactor > 3.7) ? (orderFactor - 3.7) : (0.0)) ;
    double adjTime = 100 * Math.pow(10.0, adjOrderFactor) ;

    time = (long)(adjTime + BigDBOpsLockFile.MINSLEEPTIME) ;
    if(time > BigDBOpsLockFile.MAXSLEEPTIME)
    {
      time = BigDBOpsLockFile.MAXSLEEPTIME ;
    }
    else if(time < BigDBOpsLockFile.MINSLEEPTIME)
    {
      time = BigDBOpsLockFile.MINSLEEPTIME ;
    }
    return time ;
  }
}
