package org.genboree.dbaccess;

import java.io.*;
import java.util.*;
import java.sql.*;
import org.genboree.upload.*;

public class DbFref  implements Comparable , RefSeqParams {

  // CONSTANTS
  public static final int NO_LIMIT = -1 ;

  protected int rid;
  protected String refname;
  protected String rlength;
  long length;
  protected String rbin;
  protected int ftypeid;
  protected String rstrand;
  protected int gid;
  protected String gname;
  protected String gclass;


  public DbFref (String[] data)
  {
    init(data);
  }

  private void init(String[] data)
  {
    if (data != null && data.length >= 3)
    {
      gname = data[REF_GNAME];
      refname = data[REF_NAME];
      rlength = data[REF_LENGTH];
      length = Long.parseLong(data[REF_LENGTH]);
    }
  }

  public int compareTo( Object o )
  {
    return getRefname().compareTo( ((DbFref)o).getRefname() );
  }

  public DbFref()
  { rid = -1; }

  public static int countAll(DBAgent db, String databaseName)
  {
    int retVal = -1 ;
    Connection conn = null;

    try
    {
      conn =   db.getConnection(databaseName);
      String frefCountSQL = "SELECT count(*) FROM fref" ;
      Statement stmt = conn.createStatement() ;
      ResultSet rs = stmt.executeQuery(frefCountSQL) ;
      if(rs.next())
      {
        retVal = rs.getInt(1) ;
      }
      else
      {
        retVal = 0 ;
      }
      stmt.close() ;
    }
    catch( Exception ex )
    {
      // ARJ: should log this error somewhere (even catalina.out is fine) but error reporting seems spotty?
      System.err.println("EXCEPTION: DbRef.countAll() failed to count the EPs. On Database = " + databaseName);
      System.err.println("Details: " + ex.toString());
      ex.printStackTrace(System.err) ;
    }
    return retVal ;
  }



  /* ARJ: 8/29/2005 3:46PM
   * Added for quickly checking how many entrypoints are in the database.
   */
  public static int countAll(Connection conn)
  {
    int retVal = -1 ;
    try
    {
      String frefCountSQL = "SELECT count(*) FROM fref" ;
      Statement stmt = conn.createStatement() ;
      ResultSet rs = stmt.executeQuery(frefCountSQL) ;
      if(rs.next())
      {
        retVal = rs.getInt(1) ;
      }
      else
      {
        retVal = 0 ;
      }
      stmt.close() ;
    }
    catch( Exception ex )
    {
      // ARJ: should log this error somewhere (even catalina.out is fine) but error reporting seems spotty?
      System.err.println("EXCEPTION: DbRef.countAll() failed to count the EPs. Details: " + ex.toString());
      ex.printStackTrace(System.err) ;
    }
    finally
    {
        return retVal ;
    }
  }

  /* ARJ: 8/30/2005 3:44PM
   * Fetches a *limited* number of fref records in a entrypoint-format array.
   * i.e. a String[][] where each record has 3 columns:
   *    - fref name (refname)
   *    - fref class (gname)
   *    - fref length (rlength)
   * As elsewhere, if recordLimit < 0 (eg DbFref.NO_LIMIT), then *all* record will be fetched.
   */
  public static String[][] fetchAsEntrypointArray(Connection conn, int recordLimit)
  {
    Vector vv = new Vector() ;
    String limitStr = (recordLimit >= 0) ? ( " LIMIT " + recordLimit ) : "" ;
    try
    {
      String qs = "SELECT f.refname, f.rlength, f.gname " +
                  "FROM fref f ORDER BY refname " + limitStr ;
      Statement stmt = conn.createStatement() ;
      ResultSet rs = stmt.executeQuery(qs) ;
      while( rs.next() )
      {
        String[] rec = new String[3];
        rec[0] = rs.getString(1) ;
        rec[1] = rs.getString(2) ;
        rec[2] = rs.getString(3) ;
        vv.addElement( rec );
      }
      stmt.close() ;
    }
    catch( Exception ex )
    {
      // ARJ: should log this error somewhere (even catalina.out is fine) but error reporting seems spotty?
      System.err.println("EXCEPTION: DbRef.fetchAsEntrypointArray(Connection, int) failed to get the EP records. Error msg: " + ex.toString()) ;
    }
    String[][] frefRecords = new String[vv.size()][] ;
    vv.copyInto(frefRecords) ;
    return frefRecords ;
  }

  /* ARJ: 8/30/2005 4:01PM
   * Convenience method. Fetch *all* the fref records in an entrypoint-format array.
   */
  public static String[][] fetchAsEntrypointArray(Connection conn)
  {
    return DbFref.fetchAsEntrypointArray(conn, DbFref.NO_LIMIT) ;
  }
//Andrew wrote --> 9/1/2005 4:12PM

  /* ARJ: 8/30/2005 3:46PM
   * Added to retrieve a *limited* number of fref records...includes all columns.
   * If recordLimit is < 0 (eg DbFref.NO_LIMIT), then *all* records will be retrieved.
   */
  public static DbFref[] fetchAll( Connection conn, int recordLimit )
  {
    Vector v = new Vector();
    String limitStr = (recordLimit >= 0)? ( " LIMIT " + recordLimit ) : "" ;
    try
    {
      String qs = "SELECT f.rid, f.refname, f.rlength, f.rbin, f.ftypeid, f.rstrand, f.gname " +
                  "FROM fref f ORDER BY refname " + limitStr ;
      Statement stmt = conn.createStatement();
      ResultSet rs = stmt.executeQuery(qs);
      while( rs.next() )
      {
        DbFref p = new DbFref();
        p.setRid( rs.getInt(1) );
        p.setRefname( rs.getString(2) );
        p.setRlength( rs.getString(3) );
        p.setLength( rs.getLong(3));
        p.setRbin( rs.getString(4) );
        p.setFtypeid( rs.getInt(5) );
        p.setRstrand( rs.getString(6) );
        p.setGname( rs.getString(7) );
        v.addElement( p );
      }
      stmt.close();
    }
    catch( Exception ex )
    {
      // ARJ: should log this error somewhere (even catalina.out is fine) but error reporting seems spotty?
      System.err.println("EXCEPTION: DbRef.fetchAll(Connection, int) failed to get the EPs. Error msg: " + ex.toString()) ;
      ex.printStackTrace(System.err) ;
    }
    DbFref[] rc = new DbFref[ v.size() ];
    v.copyInto( rc );
    return rc;
  }

  /* ARJ 8/30/2005 3:41PM
   * I think we need to remove/change this. It uses the old gid stuff?
   * It can be turned into a single line convenience method by having this body:
   *    return DbFref.fetchAll(conn, -1) ;
   * Is the gid stuff needed for fref objects?? It slows everything down...
   */
  public static DbFref[] fetchAll( Connection conn )
  {
    return DbFref.fetchAll(conn, -1) ;
  }

  public static DbFref[] fetchAll( DBAgent db, String[] dbNames )
  {
    Hashtable ht = new Hashtable();
    int i;
    try
    {
        for( int j=0; j<dbNames.length; j++ )
        {
            DbFref[] eps = DbFref.fetchAll( db.getConnection(dbNames[j]) );
            for( i=0; i<eps.length; i++ )
            {
                String fName = eps[i].getRefname();
                if( ht.get(fName) == null )
                    ht.put( fName, eps[i] );
            }
        }
    } catch( Exception ex )
    {
      db.reportError( ex, "DbFref.fetchAll()" );
    }
    DbFref[] rc = new DbFref[ ht.size() ];
    i = 0;
    for( Enumeration en = ht.keys(); en.hasMoreElements(); )
    {
      rc[i++] = (DbFref) ht.get( en.nextElement() );
    }
    Arrays.sort( rc );
    return rc;

  }

  /* ARJ 8/31/2005 12:48PM
   * Added this to look up a single fref record in the db by its refname.
   * This should work for databases with both small and huge numbers of EP.
   * This should be pretty darn fast, as written.
   */
  public static DbFref fetchByName( Connection conn, String frefName )
  {
    DbFref retVal = null ;
    try
    {
      String qs = "SELECT f.rid, f.refname, f.rlength, f.rbin, f.ftypeid, f.rstrand, f.gname " +
                  "FROM fref f " +
                  "WHERE f.refname = '" + frefName + "'" ;
      Statement stmt = conn.createStatement();
      ResultSet rs = stmt.executeQuery( qs );
      if( rs.next() )
      {
        retVal = new DbFref() ;
        retVal.setRid( rs.getInt(1) );
        retVal.setRefname( rs.getString(2) );
        retVal.setRlength( rs.getString(3) );
        retVal.setLength( rs.getLong(3));
        retVal.setRbin( rs.getString(4) );
        retVal.setFtypeid( rs.getInt(5) );
        retVal.setRstrand( rs.getString(6) );
        retVal.setGname( rs.getString(7) );
      }
      stmt.close();
    }
    catch( Exception ex )
    {
      System.err.println("EXCEPTION: DbFref.fetchByName(Connection, String) failed to look up fref by its name (" + frefName + ") because of:\n   ");
      ex.printStackTrace(System.err) ;
      retVal = null ;
    }
    return retVal;
  }

  public boolean fetch( Connection conn )
  {
    try
    {
      String qs = "SELECT f.refname, f.rlength, f.rbin, "+
                  "f.ftypeid, f.rstrand, f.gid, f.gname, g.gclass "+
                  "FROM fref f, gclass g "+
                  "WHERE f.gid=g.gid AND rid="+getRid();
      PreparedStatement pstmt = conn.prepareStatement( qs );
      ResultSet rs = pstmt.executeQuery();
      boolean rc = false;
      if( rs.next() )
      {
        setRefname( rs.getString(1) );
        setRlength( rs.getString(2) );
        setLength(rs.getLong(2));
        setRbin( rs.getString(3) );
        setFtypeid( rs.getInt(4) );
        setRstrand( rs.getString(5) );
        setGid( rs.getInt(6) );
        setGname( rs.getString(7) );
        setGclass( rs.getString(8) );
        rc = true;
      }
      pstmt.close();
      return rc;
    } catch( Exception ex ) {}
    return false;
  }

  public boolean insert( Connection conn )  throws SQLException
  {
    try
    {
      String qs = "INSERT ignore INTO fref (refname, rlength, rbin, ftypeid, rstrand, gid, gname) "+
          "VALUES (?, ?, ?, ?, ?, ?, ?)";
      PreparedStatement pstmt = conn.prepareStatement( qs );
      pstmt.setString( 1, getRefname() );
      pstmt.setString( 2, getRlength() );
      pstmt.setString( 3, getRbin() );
      pstmt.setInt( 4, getFtypeid() );
      pstmt.setString( 5, getRstrand() );
      pstmt.setInt( 6, getGid() );
      pstmt.setString( 7, getGname() );
      boolean rc = (pstmt.executeUpdate() > 0);
         /*   if( rc )
            {
                Statement stmt = conn.createStatement();
                ResultSet rs = stmt.executeQuery( "SELECT LAST_INSERT_ID()" );
                if( rs.next() ) setRid( rs.getInt(1) );
                stmt.close();
                rs.close();
            } */
      pstmt.close();
      return rc;
    } catch( SQLException e ) {
          throw e;
       }
  //return false;
  }

  public boolean update( Connection conn )
  {
    try
    {
      String qs = "UPDATE fref SET refname=?, rlength=?, rbin=?, ftypeid=?, "+
          "rstrand=?, gid=?, gname=? WHERE rid="+getRid();
      PreparedStatement pstmt = conn.prepareStatement( qs );
      pstmt.setString( 1, getRefname() );
      pstmt.setString( 2, getRlength() );
      pstmt.setString( 3, getRbin() );
      pstmt.setInt( 4, getFtypeid() );
      pstmt.setString( 5, getRstrand() );
      pstmt.setInt( 6, getGid() );
      pstmt.setString( 7, getGname() );
      boolean rc = (pstmt.executeUpdate() > 0);
      pstmt.close();
      return rc;
    } catch( Exception ex ) {}
    return false;
  }

  public boolean delete( Connection conn )
  {
    try
    {
      String qs = "DELETE FROM fref WHERE rid="+getRid();
      Statement stmt = conn.createStatement();
      boolean rc = (stmt.executeUpdate(qs) > 0);
      stmt.close();
      return rc;
    } catch( Exception ex ) {}
    return false;
  }

      public long getLength() {
        return length;
    }

    public void setLength(long length) {
        this.length = length;
    }

    public String getRstrand() { return rstrand; }

       public void setRstrand(String rstrand) { this.rstrand = rstrand; }


  public String getGclass() { return gclass; }
  public void setGclass( String gclass ) { this.gclass = gclass; }

    public int getRid() { return rid; }
    public void setRid( int rid ) { this.rid = rid; }

    public String getRefname() { return refname; }
    public void setRefname( String refname ) { this.refname = refname; }
    public String getRlength() { return rlength; }
    public void setRlength( String rlength ) { this.rlength = rlength; }
    public String getRbin() { return rbin; }
        public void setRbin( String rbin ) { this.rbin = rbin; }
    public int getFtypeid() { return ftypeid; }
        public void setFtypeid( int ftypeid ) { this.ftypeid = ftypeid; }

    public int getGid() { return gid; }
    public void setGid( int gid ) { this.gid = gid; }
    public String getGname() { return gname; }
        public void setGname( String gname ) { this.gname = gname; }
}
