package org.genboree.util ;

import java.util.* ;

public class MemoryUtil
{
  public static long usedMemory()
  {
    Runtime runTime = Runtime.getRuntime() ;
    return runTime.totalMemory() - runTime.freeMemory() ;
  }

  public static void forceGC()
  {
    MemoryUtil.forceGC(2, 3) ;
    return ;
  }

  public static void forceGC(int numRepeats, int numInternalLoops)
  {
    Calendar nowCal = Calendar.getInstance() ;
    long nowMillis = nowCal.getTimeInMillis() ;
    // Call Runtime.gc() a few times, via a returning method call
    for(int ii=0; ii<numRepeats; ii+=1)
    {
      _forceGC(numInternalLoops) ;
    }
    nowCal = Calendar.getInstance() ;
    System.err.println("    STATUS: ForceGC() took total: " + ((nowCal.getTimeInMillis() - nowMillis)/1000) + " seconds.") ;
    return ;
  }

  private static void _forceGC(int numInternalLoops)
  {
    long prevMemory = Long.MAX_VALUE  ;
    long currMemory = MemoryUtil.usedMemory() ;
    int ii = 0 ;
    try
    {
      Runtime runTime = Runtime.getRuntime() ;
      for(ii = 0; (prevMemory > currMemory) && (ii < numInternalLoops); ii+=1)
      {
        //System.err.print("      - mem diff: [" + (prevMemory - currMemory) );
        runTime.runFinalization() ;
        runTime.gc() ;
        Thread.currentThread().yield() ;
        prevMemory = currMemory ;
        currMemory = MemoryUtil.usedMemory() ;
        //System.err.println(" =>" + (prevMemory - currMemory) + "]" );
      }
    }
    catch(Exception ex)
    {
      System.err.println("ERROR: MemoryUtil.java => problem trying to force-gc of memory.") ;
      ex.printStackTrace(System.err) ;
    }
    System.err.println("    STATUS: repetitive GC repeated " + ii + " times") ;
    return ;
  }
}
