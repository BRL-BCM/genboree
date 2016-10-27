package org.genboree.util;

import org.genboree.dbaccess.DBAgent;
import org.genboree.downloader.AnnotationDownloader;
import org.genboree.dbaccess.DbFref;
import org.genboree.dbaccess.DbGclass;
import org.genboree.dbaccess.DbFtype;
import org.genboree.upload.LffConstants;
import org.genboree.upload.HttpPostInputStream;
import org.genboree.upload.GroupAssigner;

import java.io.*;
import java.util.zip.*;
import java.util.*;
import java.util.Date;
import java.sql.*;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.net.InetAddress;
import java.text.SimpleDateFormat;


/*************************************************************************
 * HELPER CLASSES 
*************************************************************************/
/* ARJ: Sub-process output/error stream handler class *asynchronously*. 
 * This avoids the blocked-read that can occur in a non-threaded approach
 * to reading a sub-class' stdout and stder.
 * See: 
 *   http://hacks.oreilly.com/pub/h/1092 
 * Changes:
 *   - uses 8K buffer to read, not char-by-char
 */
class InputStreamHandler extends Thread
{
  protected InputStream inStream ; // stream we will read	
  protected StringBuffer captureBuffer ; // buffer to hold captured output
  
  /**
   * Constructon
   * You provide the buffer to store the stream contents into and the stream
   */
  InputStreamHandler( StringBuffer captureBuffer, InputStream inStream )
  {
    this.inStream = inStream ;
    this.captureBuffer = captureBuffer ;
    start() ;
  }
  
  /* Gobble the stream (out-of-sync with other streams, yay!) */
  public void run()
  {
    try
    {
      byte[] buf1 = new byte[8192] ;
      int len = 0 ;
      while((len = this.inStream.read(buf1)) != -1)
      {
        captureBuffer.append(new String(buf1,0,len)) ;
      }
    }
    catch( IOException ioe )
    {
      System.err.println("\n\nFATAL ERROR: DirectoryUtils.java#InputStreadHandler#run() died while trying to read the IS:\n" + ioe.toString() + "\n");
      ioe.printStackTrace(System.err) ;
    }
  }
}

