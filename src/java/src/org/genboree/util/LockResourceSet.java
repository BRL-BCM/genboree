package org.genboree.util ;

import java.io.* ;
import java.nio.channels.* ;

// STRUCT! (not Class; instance variables available to all)
// - For passing around all the resources used in getting a file lock in Java.
// - Calling function that gets a lock can release and close these resources
//   as needed or via LockResourceSet.close()
public class LockResourceSet
{
  public FileLock lock ;
  public FileChannel channel ;
  public RandomAccessFile raf ;

  public LockResourceSet()
  {
    lock = null ;
    channel = null ;
    raf = null ;
  }

  public void close()
  {
    // Try to release each resource. If one fails, try to release others.
    // FIRST: the FileLock
    try
    {
      if(this.lock != null)
      {
        this.lock.release() ;
      }
    }
    catch(Exception ex)
    {
      System.err.println("WARNING: LockResourceSet.close() => Couldn't release FileLock for some reason. Details: " + ex.getMessage()) ;
      ex.printStackTrace(System.err) ;
    }
    // SECOND: the FileChannel
    try
    {
      if(this.channel != null)
      {
        this.channel.close() ;
      }
    }
    catch(Exception ex)
    {
      System.err.println("WARNING: LockResourceSet.close() => Couldn't close the FileChannel for some reason. Details: " + ex.getMessage()) ;
      ex.printStackTrace(System.err) ;
    }
    // THIRD: the RandomAccessFile
    try
    {
      if(this.raf != null)
      {
        this.raf.close() ;
      }
    }
    catch(Exception ex)
    {
      System.err.println("WARNING: LockResourceSet.close() => Couldn't close the RandomAccessFile for some reason. Details: " + ex.getMessage()) ;
      ex.printStackTrace(System.err) ;
    }
    return ;
  }
}
