package org.genboree.util ;

import java.io.* ;
import java.nio.channels.* ;
import java.util.* ;
import org.genboree.util.* ;

public class GenericDBOpsLockFile
{
  //--------------------------------------------------------------------------
  // CONSTANTS
  //--------------------------------------------------------------------------
  // Tags for different sorts of databases, which each have a lock file.
  public static final int MAIN_GENB_DB = 1 ;
  public static final int USER_GENB_DB = 2 ;
  public static final int OTHER_GENB_DB = 4 ;

  //--------------------------------------------------------------------------
  // PUBLIC CLASS METHODS
  //--------------------------------------------------------------------------
  // Get permission for a db operation
  public static boolean getPermissionForDbOperation(int dbTypeCode)
  {
    String lockFile = GenericDBOpsLockFile.getLockFileByDBType(dbTypeCode) ;
    int sleepTime = GenboreeConfig.getIntConfigParam("genericDbOpSleepSecs", 30) ;
    System.err.println((new java.util.Date()).toString() + " ASK PERMISSION for DB operation via the lock file '" + lockFile + "'. ") ;
    boolean retVal = false ;
    try
    {
      // Try to get permission to do a Db Operation
      while(true)
      {
        // Call this *synchronized* method (1 thread at a time, only) to do file ops for us:
        boolean lockFileResult = GenericDBOpsLockFile.incrementDbOpsLockFile(dbTypeCode) ;
        if(lockFileResult) // Then we got permission and incremented the count in the appropriate file
        {
          retVal = true ;
          break ;
        }
        else // No permission yet. Maybe file locked in another process or maybe theMaxCount is exceeded. Wait and try again later.
        {
          Util.sleep(sleepTime * 1000) ;
        }
      }
    }
    catch(Throwable ex) // something bad happened
    {
      System.err.println("ERROR: GenericDBOpsLockFile#getPermissionForDbOperation: Caught exception (bug!) trying to increment.") ;
      ex.printStackTrace(System.err) ;
      retVal = false ;
    }
    if(retVal)
    {
      System.err.println((new java.util.Date()).toString() + " GRANTED PERMISSION for DB operation via the lock file '" + lockFile + "'. ") ;
    }
    else
    {
      System.err.println((new java.util.Date()).toString() + " FAILED PERMISSION for DB operation via the lock file '" + lockFile + "'. ") ;
    }
    return retVal ;
  }

  // Release permission for a db operation
  public static boolean releasePermissionForDbOperation(int dbTypeCode)
  {
    String lockFile = GenericDBOpsLockFile.getLockFileByDBType(dbTypeCode) ;
    System.err.println((new java.util.Date()).toString() + " RELEASE PERMISSION for operation via the lock file '" + lockFile + "'. ") ;
    boolean retVal = false ;
    try
    {
      // Try to release permission to do a Db Operation
      // Call this *synchronized* method (1 thread at a time, only) to do file ops for us:
      boolean lockFileResult = GenericDBOpsLockFile.decrementDbOpsLockFile(dbTypeCode) ;
      if(!lockFileResult) // Then we had problems releasing a previously-granted permission. That's an error.
      {
        retVal = false ;
        throw new Exception("FAILED TO RELEASE BIG DB-OP PERMISSION FOR lock file '" + lockFile + "'. ") ;
      }
      else
      {
        retVal = true ;
      }
    }
    catch(Throwable ex) // something really bad happened
    {
      System.err.println("ERROR: GenericDBOpsLockFile#updateDbOpsLockFile(i): Caught exception (bug!) trying to decrement.") ;
      ex.printStackTrace(System.err) ;
    }
    return retVal ;
  }

  //--------------------------------------------------------------------------
  // PROTECTED CLASS MEHTODS
  // Not to be called directly. But inheritable if necessary.
  //--------------------------------------------------------------------------
  protected synchronized static boolean incrementDbOpsLockFile(int dbTypeCode)
  {
    return updateDbOpsLockFile(dbTypeCode, true) ;
  }
  protected synchronized static boolean decrementDbOpsLockFile(int dbTypeCode)
  {
    return updateDbOpsLockFile(dbTypeCode, false) ;
  }
  protected synchronized static boolean updateDbOpsLockFile(int dbTypeCode, boolean incrementCount)
  {
    boolean retVal = false ;
    try
    {
      // FIRST: Get key lock-file parameters from config (although have some fall back defaults):
      int maxNumDbOps = GenericDBOpsLockFile.getMaxNumDbOpsByDBType(dbTypeCode) ;
      String lockFile = GenericDBOpsLockFile.getLockFileByDBType(dbTypeCode) ;

      // SECOND: Get file lock on the lock file (blocks for a long time if lots of others trying & getting lock)
      LockResourceSet lockResourceSet = new LockResourceSet() ;
      boolean gotFileLock = GenericDBOpsLockFile.getFileLock(lockFile, lockResourceSet) ;

      if(!gotFileLock) // We didn't get a file lock after a really long time...
      {
        System.err.println("ERROR: GenericDBOpsLockFile.updateDbOpsLockFile => couldn't get file lock on " + lockFile + "! Does this user have write permission? Or was the file left locked by a killed process or something? Locks on this file should be very short (<1 sec)!") ;
        retVal = false ;
      }
      else // We got a file lock
      {
        // THIRD: Read lock file line
         BufferedReader reader = new BufferedReader(new FileReader(lockFile)) ;
         String line ;
         int currCount = 0 ;
         // First line in file is number of DB ops. No blanks, etc.
        while((line = reader.readLine()) != null)
        {
          line = line.trim() ;
          currCount = Util.parseInt(line, 0) ;
        }
        reader.close() ;

        // FOURTH: try to update count appropriately
        if(incrementCount)  // asking permision, increment count if ok
        {
          boolean allowed = false ;
          if(currCount < maxNumDbOps) // ok to increment count
          {
            currCount += 1 ;
            retVal = true ;
          }
          else // no ok to increment count
          {
            retVal = false ;
          }
        }
        else // releasing permission, decrement the count
        {
          currCount = ((currCount >= 1) ? currCount - 1 : 0) ;
          retVal = true ; // always allowed to try to release permission
        }

        // FIFTH: Now write out the updated lock file contents if we got permission to do what we wanted.
        if(retVal)
        {
          PrintWriter writer = new PrintWriter(new BufferedWriter(new FileWriter(lockFile))) ;
          writer.println(currCount) ;
          writer.close() ;
        }
        // SIXTH: Release lock & release resources
        lockResourceSet.close() ;
      }
    }
    catch(Exception ex)
    {
      System.err.println("ERROR: GenericDBOpsLockFile.updateDbOpsLockFile => couldn't read lock file and check for permission to do a DB Op. Check lock file looks correctly formatted, etc. Exception details: " + ex.getMessage()) ;
      ex.printStackTrace(System.err) ;
      retVal = false ;
    }
    return retVal ;
  }

  // Get a file lock, Java style.
  // - hand back the FileLock, FileChannel, and RandomAccessFile so the calling function can clean them up when done with file lock.
  protected static boolean getFileLock(String fileName, LockResourceSet out)
  {
    int maxDbOpsLockRetries = GenboreeConfig.getIntConfigParam("maxDbOpsLockRetries", 1280) ;
    int lockRetrySleepSecs = GenboreeConfig.getIntConfigParam("lockRetrySleepSecs", 50) ;
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
      System.err.println("ERROR: GenericDBOpsLockFile.getFileLock(S,L) => couldn't open the file for writing (even if doesn't exist, should have been able to auto-create it, but that failed too.) Details: " + ex.getMessage()) ;
      ex.printStackTrace(System.err) ;
      return retVal ;
    }
    out.channel = out.raf.getChannel() ;

    // Try to get a file-lock so we can assess the contents for permission.
    while(true)
    {
      if(retryCount > maxDbOpsLockRetries)
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
            int randExtra = (rng.nextInt((int)lockRetrySleepSecs * 1000) + 1) ;
            Util.sleep( (lockRetrySleepSecs * retryCount) + randExtra ) ;
          }
          catch(Exception ex)
          {
          }
        }
        catch(IOException ioe) // Some serious IO problem occurred
        {
          System.err.println("ERROR: GenericDBOpsLockFile.getFileLock(S,L) => fatal problem trying for lock on file. Details: " + ioe.getMessage()) ;
          ioe.printStackTrace(System.err) ;
          retVal = false ;
          break ;
        }
      }
    }
    return retVal ;
  }

  public static String getLockFileByDBType(int dbTypeCode)
  {
    String retVal = null ;
    String lockDir = GenboreeConfig.getConfigParam("gbLockFileDir") ;
    switch (dbTypeCode) {
      case MAIN_GENB_DB :
        retVal = GenboreeConfig.getConfigParam("mainGenbDbOpsLockFile") ;
        break ;
      case USER_GENB_DB :
        retVal = GenboreeConfig.getConfigParam("userGenbDbOpsLockFile") ;
        break ;
      case OTHER_GENB_DB :
        retVal = GenboreeConfig.getConfigParam("otherGenbDbOpsLockFile") ;
        break ;
      default :
        throw new AssertionError("ERROR: GenericDBOpsLockFile.getLockFileForDBTypeCode(i) called with a bad dbTypeCode argument (" + dbTypeCode + ")") ;
    }
    return lockDir + "/" + retVal ;
  }

  public static int getMaxNumDbOpsByDBType(int dbTypeCode)
  {
    int retVal = 1 ;
    switch (dbTypeCode) {
      case MAIN_GENB_DB :
        retVal = GenboreeConfig.getIntConfigParam("maxMainGenbDbOps", 1) ;
        break ;
      case USER_GENB_DB :
        retVal = GenboreeConfig.getIntConfigParam("maxUserGenbDbOps", 1) ;
        break ;
      case OTHER_GENB_DB :
        retVal = GenboreeConfig.getIntConfigParam("maxOtherGenbDbOps", 1) ;
        break ;
      default :
        throw new AssertionError("ERROR: GenericDBOpsLockFile.getMaxNumDbOpsForDBType(i) called with a bad dbTypeCode argument (" + dbTypeCode + ")") ;
    }
    return retVal ;
  }
}
