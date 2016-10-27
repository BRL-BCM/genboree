package org.genboree.dbaccess ;

import java.lang.* ;
import java.lang.reflect.* ;
import java.io.* ;
import java.sql.* ;
import java.util.* ;

public class Dbrc
{
  // Instance variables
  protected String dbrcFile = null ;
  protected String key = null ;
  protected String userId = null ;
  protected String gbInstanceKey = null ;
  protected HashMap dbrcRecs = new HashMap() ;

  //public Dbrc(String dbrcFile, String key, String userId, String gbInstanceKey)
  public Dbrc(String dbrcFile)
  {
    setDbrcFile(dbrcFile) ;
    this.key = key ;
    this.userId = userId ;
    this.gbInstanceKey = gbInstanceKey ;
    load(this.dbrcFile) ;
  }

  // If dbrc file is not provided try to set it from the env
  public void setDbrcFile(String dbrcFile)
  {
    if(dbrcFile == null)
    {
      String tmpDbrc = null ;
      tmpDbrc = System.getenv("DBRC_FILE") ;
      if(tmpDbrc == null)
      {
        tmpDbrc = System.getenv("DB_ACCESS_FILE") ;
        if(tmpDbrc == null)
        {
          tmpDbrc = "~./dbrc" ;
        }
      }
      this.dbrcFile = tmpDbrc ;
    }
    else
    {
      this.dbrcFile = dbrcFile ;
    }
    if(this.dbrcFile == null)
    {
      System.err.println("Error: Dbrc file could not be found. ") ;
    }
  }

  // Loads up the dbrc file as a hash map
  public void load(String dbrcFile)
  {
    try
    {
      FileInputStream fstream = new FileInputStream(dbrcFile) ;
      String dbrcLine ;
      DataInputStream in = new DataInputStream(fstream);
      BufferedReader br = new BufferedReader(new InputStreamReader(in));
      java.util.regex.Pattern commentLine = java.util.regex.Pattern.compile("^#.*$") ;
      boolean clMatches ;
      java.util.regex.Matcher cl ;
      while( (dbrcLine = br.readLine()) != null)
      {
        //System.err.println(dbrcLine) ;
        if(dbrcLine.trim().length() != 0) // Not an empty line
        {
          cl = commentLine.matcher(dbrcLine) ;
          clMatches = cl.matches() ;
          if(clMatches == false) // Not a comment line
          {
            String[] fields = dbrcLine.split("\\s+") ;
            HashMap rec = new HashMap() ;
            rec.put("hostType", "internal") ;
            String key = fields[0] ;
            rec.put(key, fields[0]) ;
            rec.put("user", fields[1]) ;
            rec.put("password", fields[2]) ;
            rec.put("driver", fields[3]) ;
            String hostField = fields[3].split(":")[2] ;
            if(hostField.indexOf("host=") >= 0)
            {
              rec.put("host", hostField.split("host=")[1].split(";")[0]) ;
            }
            else // either not options based or no host= ... we'll try saving the whole thing hoping it's a JDBC-suitable host string
            {
              rec.put("host", hostField) ;
            }
            rec.put("timeout", fields[4]) ;
            rec.put("max_reconn", fields[5]) ;
            rec.put("interval", fields[6]) ;
            rec.put("dsn", fields[3] + ":" + key) ;
            this.dbrcRecs.put(key, rec) ;
          }
        }
      }
      br.close() ;
      fstream.close() ;
      in.close() ;
    }
    catch(Exception ex)
    {
      System.err.println("Error: " + ex.getMessage()) ;
      ex.printStackTrace(System.err) ;
    }
  }

  public HashMap getRecordByHost(String host, String type)
  {
    String key = type + ":" + host ;
    return (HashMap)this.dbrcRecs.get(key) ;
  }
}
