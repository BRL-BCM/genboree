package org.genboree.util;

import org.genboree.util.Util;
import java.io.*;
import java.sql.*;
import java.util.*;

public class TimingUtil
{
  // OBJECT VARIABLES
  protected ArrayList vTimes ;
  protected ArrayList vMsgs ;
  protected String[] userInfo ;
  protected boolean forced ;
  
  public TimingUtil()
  {
    this(null) ;
    this.forced = true ;
  }
  
  public TimingUtil(String[] userInfo)
  {
    this.vTimes = new ArrayList() ;
    this.vMsgs = new ArrayList() ;
    this.userInfo = userInfo ;
    this.forced = false ;
    
    java.util.Date now = new java.util.Date() ;
    this.vTimes.add( now );
    this.vMsgs.add( "TIMING STARTED AT: " + now.toString() ) ;
  }
  
  public void addMsg(String msg)
  {
    this.vTimes.add(new java.util.Date()) ;
    this.vMsgs.add(msg) ;
    return ;
  }
  
  public void writeTimingReport(PrintStream ios)
  {
    this.writeTimingReport(new PrintWriter(ios)) ;
    return ;
  }
  
  public void writeTimingReport(Writer writer)
  {
    PrintWriter ios = new PrintWriter(writer) ;

    if(this.forced || (this.userInfo != null) || this.userInfo[0].equals("andrewj"))
    {
      java.util.Date currDate = (java.util.Date) this.vTimes.get(0) ;
      String currMsg = (String) this.vMsgs.get(0) ;
      ios.println( currMsg ) ;
      ios.println();

      java.util.Date nextDate = null ;
      for( int ii=1; ii<this.vTimes.size(); ii++ )
      {
        nextDate = (java.util.Date) this.vTimes.get(ii) ;
        currMsg = (String) this.vMsgs.get(ii) ;
        long elapsedTime = (nextDate.getTime() - currDate.getTime()) / 100L ;
        ios.println( "    " + currMsg + ": " + (elapsedTime/10L) + "." + (elapsedTime % 10) + " sec" );
        currDate = nextDate ;
      }

      ios.println() ;
      ios.println( "TIMING REPORTED AT: " + nextDate.toString() );
    }
    ios.flush() ;
    return ;
  }

    public String generateStringWithReport()
    {
        StringBuffer report = new StringBuffer(100);

        if(this.forced || (this.userInfo != null && (this.userInfo[0].equals("andrewj"))))
        {
            java.util.Date currDate = (java.util.Date) this.vTimes.get(0) ;
            String currMsg = (String) this.vMsgs.get(0) ;
            report.append(currMsg).append("\n");

            java.util.Date nextDate = null ;
            for( int ii=1; ii<this.vTimes.size(); ii++ )
            {
                nextDate = (java.util.Date) this.vTimes.get(ii) ;
                currMsg = (String) this.vMsgs.get(ii) ;
                long elapsedTime = (nextDate.getTime() - currDate.getTime()) / 100L ;
                report.append("    ").append(currMsg).append(": ");
                report.append(elapsedTime/10L).append(".");
                report.append(elapsedTime % 10).append(" sec").append("\n");
                currDate = nextDate ;
            }
//            report.append("\n");
            report.append("TIMING REPORTED AT: ").append(nextDate.toString()).append("\n");
        }
        return report.toString();

    }

}
