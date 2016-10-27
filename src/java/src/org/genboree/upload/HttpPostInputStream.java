package org.genboree.upload;

import java.io.*;
import java.util.*;
import javax.servlet.*;
import javax.servlet.http.*;

public class HttpPostInputStream
  extends InputStream
{
  protected ServletInputStream in;
  protected byte rdBuf[];

  protected long bytesRead;
  protected int navl;
  protected int cpos;

  protected Hashtable partInfo;
  protected boolean in_body;

  protected String nextp;
  protected String lastp;
  protected String bytesReadStr ;
  protected HttpSession mys;

  public HttpPostInputStream( ServletInputStream in, HttpSession mys )
  {
    this.in = in;
    this.mys = mys;
    rdBuf = new byte[ 0x1000 ];
    navl = cpos = 0;
    nextp = lastp = null;
    in_body = false;
    bytesRead = 0L;
    this.bytesReadStr = "bytesRead" ;
    synchronized(mys) { mys.setAttribute( this.bytesReadStr, new Long(bytesRead) ); }
    partInfo = new Hashtable();
  }

  public String setIdStr(String idStr)
  {
    this.bytesReadStr = idStr + "bytesRead" ;
    bytesRead = 0L;
    synchronized(mys) { mys.setAttribute( this.bytesReadStr, new Long(bytesRead) ); }
    return idStr ;
  }

  protected String readLine()
    throws IOException
  {
    navl = in.readLine( rdBuf, 0, rdBuf.length );
    if( navl < 0 ) return null;
    bytesRead += navl;
    synchronized(mys) { mys.setAttribute( this.bytesReadStr, new Long(bytesRead) ); }
    return (new String(rdBuf,0,navl)).trim();
  }

  protected boolean readData()
    throws IOException
  {
    if( !in_body ) return false;
    navl = in.readLine( rdBuf, 0, rdBuf.length );
    if( navl < 0 ) return (in_body = false);
    bytesRead += navl;
    synchronized(mys) { mys.setAttribute( this.bytesReadStr, new Long(bytesRead) ); }
    String s = (new String(rdBuf,0,navl)).trim();
    if( s.startsWith(nextp) ) return (in_body = false);
    cpos = 0;
    return true;
  }

  public int available()
    throws IOException
  {
    if( in_body && cpos >= navl ) readData();
    return in_body ? 1 : 0;
  }

  public int read()
    throws IOException
  {
    return (available() > 0) ? (int)(rdBuf[cpos++] & 0xFF) : -1;
  }

  public boolean nextPart()
    throws IOException
  {
    in_body = false;
    String s = null;
    if( nextp == null )
    {
      nextp = readLine();
      if( nextp == null ) return false;
      lastp = nextp + "--";
    }
    else
    {
      s = (new String(rdBuf,0,navl)).trim();
      while( !s.startsWith(nextp) )
      {
        s = readLine();
        if( s == null ) return false;
        if( s.startsWith(lastp) ) return false;
      }
    }

    partInfo.clear();
    partInfo.put( "Content-Type", "text/plain" );

    while( (s=readLine()) != null )
    {
      if( s.length() == 0 )
      {
        navl = cpos = 0;
        return (in_body = true);
      }
      int idx = s.indexOf( ':' );
      if( idx > 0 )
      {
        String ckey = s.substring(0,idx).trim();
        String cval = s.substring(idx+1).trim();
        if( ckey.equals("Content-Disposition") ) breakBy( cval, ';' );
        else partInfo.put( ckey, cval );
      }
    }
    return false;
  }

  public void breakBy( String src, char sep )
  {
    char[] s = (src + sep).toCharArray();
    int l = s.length;
    boolean in_quote = false;
    int idx0 = 0;
    for( int i=0; i<l; i++ )
    {
      char c = s[i];
      if( c == '\"' ) in_quote = !in_quote;
      else if( c == sep && !in_quote )
      {
        String knam = (new String(s,idx0,i-idx0)).trim();
        String kval = "";
        int idx = knam.indexOf('=');
        if( idx > 0 )
        {
          kval = knam.substring(idx+1).trim();
          knam = knam.substring(0,idx);
          if( kval.startsWith("\"") ) kval = kval.substring( 1, kval.length()-1 );
        }
        partInfo.put( knam, kval );
        idx0 = i+1;
      }
    }
  }

  public String getPartAttrib( String ckey )
  {
    return (String) partInfo.get( ckey );
  }

  public long getBytesRead() { return bytesRead; }

  public void close()
     throws IOException
  {
    synchronized(mys) { mys.removeAttribute( this.bytesReadStr ); }
    // in.close();
  }

}
