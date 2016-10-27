package org.genboree.upload;

import java.util.*;

public class LFFContainer
{
  public static final String UPLOAD_FASTA_CONTROL_NAME = "upload_fasta";

  protected String cn;
  protected String fn;
  protected String ptId, ptClass;
  protected int ptLen;
  protected Vector ents;
  protected Hashtable ht;

  public LFFContainer()
  {
    cn = "";
    ents = new Vector();
    ht = new Hashtable();
    ptId = null;
    ptLen = 0;
  }

  public int getNumEntries()
  {
    return ents.size();
  }

  protected String padString( String s, int l )
  {
    while( s.length() < l ) s = s + " ";
    return s;
  }

  public String getEntryAt( int idx, int pos, int l )
  {
    String[] rc = (String []) ents.elementAt(idx);
    return padString( rc[pos], l );
  }

  public void flush()
  {
    if( ptId != null )
    {
      String[] ent = new String[3];
      ent[0] = ptId;
      ent[1] = ptClass;
      ent[2] = ""+ptLen;
      ents.addElement( ent );
      ptId = null;
      ptLen = 0;
    }
  }

  public void setNames( String cn, String fn )
  {
    if( cn == null ) cn = "";
    this.cn = cn;
    if( cn.equals(UPLOAD_FASTA_CONTROL_NAME) ) this.fn = fn;
  }

  public String getFileName() { return fn; }

  public String getAttrib( String aName ) { return (String) ht.get(aName); }

  public void addLine( String s )
  {
    s = s.trim();
    if( cn.equals(UPLOAD_FASTA_CONTROL_NAME) )
    {
      if( s.startsWith(">") )
      {
        flush();
        ptLen = 0;
        ptId = s.substring(1).trim().replace('\t',' ');
        ptClass = "Chromosome";
        int idx = ptId.indexOf( ' ' );
        if( idx > 0 )
        {
          ptClass = ptId.substring(idx+1).trim();
          ptId = ptId.substring(0,idx).trim();
        }
      }
      else ptLen += s.length();
    }
    else
    {
      ht.put( cn, s );
    }
  }

}