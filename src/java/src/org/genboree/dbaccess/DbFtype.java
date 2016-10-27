package org.genboree.dbaccess;

import java.sql.*;
import java.util.*;
import org.genboree.util.* ;
import org.genboree.dbaccess.util.* ;

public class DbFtype implements Comparable, Cloneable
{
    protected int ftypeid;
    protected String fmethod;
    protected String fsource;
    protected String trackName;
    protected String gclass = "";
    protected String[] belongToAllThisGclasses;
    protected String databaseName = "#";
    protected String uploadId = "#";
    protected int sortOrder = -1;
    protected String url;
    protected boolean highDensityFlag = false;
    protected String urlDescription;
    protected String urlLabel;
    protected String display = "1";
    protected Vector linkIds = null;
    protected static final String createUrlTableStatement =
            "CREATE TABLE `featureurl` (\n"+
            "`ftypeid` int(10) unsigned NOT NULL default '0',\n"+
            "`url` varchar(255) default NULL,\n"+
            "`description` text,\n"+
            "`label` varchar(255) default NULL,\n"+
            "KEY `ftypeid` (`ftypeid`)\n"+
            ") ENGINE=MyISAM";

    /*
    Finish Variable declaration start Setters and getters
    */
  public DbFtype()
  {
      ftypeid = -1;
  }

  public DbFtype( String dbName, String method, String source )
  {
      this(dbName, -1, method, source);
  }

  public DbFtype( String dbName, int ftypeId, String method, String source )
  {
    if(ftypeId == -1)
    {
      ftypeid = fetchFtypeIdFromFmethodFsource(dbName, fmethod, fsource);
    }
    else
    {
      ftypeid = ftypeId;
    }
      databaseName = dbName;
      fmethod = method;
      fsource = source;
      trackName = fmethod + ":" + fsource ;
      setHighDensityFlag();
  }

  public int getFtypeid()
  {
      return ftypeid;
  }

  public boolean isHighDensityTrack()
  {
    return highDensityFlag;
  }

  public void setBelongToAllThisGclasses(String[] gclasses)
  {
      belongToAllThisGclasses = gclasses;
     if(belongToAllThisGclasses != null && belongToAllThisGclasses.length > 0) this.setGclass(belongToAllThisGclasses[0]);
  }

  public String[] getBelongToAllThisGclasses()
  {
    return belongToAllThisGclasses;
  }

  public void setFtypeid( int ftypeid )
  {
    this.ftypeid = ftypeid;
  }

  public String getFmethod()
  {
    return fmethod;
  }

  public void setFmethod( String fmethod )
  {
    this.fmethod = fmethod;
  }

  public String getFsource()
  {
    return fsource;
  }

  public String getTrackName()
  {
    return trackName;
  }

  public void setTrackName( String trackName )
  {
    this.trackName = trackName;
  }

  public void setFsource( String fsource )
    {
        this.fsource = fsource;
    }

  public String getGclass()
  {
    return gclass;
  }

  public void setGclass( String gclass )
  {
    this.gclass = ( ( gclass == null ) ? "" : gclass );
  }

  public String getDatabaseName()
  {
    return databaseName;
  }

  public void setDatabaseName( String databaseName )
  {
    this.databaseName = databaseName;
  }

  public String getUploadId()
  {
    return uploadId;
  }

  public void setUploadId( String uploadId )
  {
    this.uploadId = ( uploadId == null ) ? "#" : uploadId;
  }

  public int getSortOrder()
  {
    return sortOrder;
  }

  public void setSortOrder( int sortOrder )
  {
    this.sortOrder = sortOrder;
  }

  public String getUrl()
  {
    return url;
  }

  public void setUrl( String url )
  {
    this.url = url;
  }

  public String getUrlDescription()
  {
    return urlDescription;
  }

  public void setUrlDescription( String urlDescription )
  {
    this.urlDescription = urlDescription;
  }

  public String getUrlLabel()
  {
    return urlLabel;
  }

  public void setUrlLabel( String urlLabel )
  {
    this.urlLabel = urlLabel;
  }

  public void setAllUrl( String myUrl, String myDescription, String myLabel )
  {
    this.url = myUrl;
    this.urlDescription = myDescription;
    this.urlLabel = myLabel;
  }

  public String getDisplay()
  {
    return display;
  }

  public void setDisplay( String display )
  {
    this.display = Util.isEmpty( display ) ? "1" : display;
  }

    /*
    Finish Setters and getters
    */

  public int compareTo( Object o )
  {
    int s1 = ( ( DbFtype )o ).getSortOrder();
    if( getSortOrder() < s1 ) return -1;
    if( getSortOrder() > s1 ) return 1;
    return toString().compareTo( o.toString() );
  }

  public Object clone() throws java.lang.CloneNotSupportedException
  {
    return super.clone();
  }

  public String toString()
  {
    return getFmethod() + ":" + getFsource();
  }

  public int fetchFtypeIdFromFmethodFsource(String dbName, String fmethod, String fsource)
  {
    Connection conn = null;
    DBAgent db = null;
    PreparedStatement pstmt = null;
    ResultSet rs = null;
    int ftypeId = -1;
    String qs = "select ftypeId from ftype where fmethod = ? and fsource = ?";

    try
    {
      db = DBAgent.getInstance();
      conn = db.getConnection(dbName) ;
      pstmt = conn.prepareStatement( qs );
      pstmt.setString( 1, fmethod );
      pstmt.setString(2, fsource);
      rs = pstmt.executeQuery();
      if( rs.next() )
      {
        ftypeId = rs.getInt( "ftypeId" );
      }
    } catch( Exception ex )
    {
      System.err.println( "Exception on DbFtype::fetchFtypeIdFromFmethodFsource(dbName, ftypeId) => exception thrown. Details:\n" + ex.getMessage() );
      ex.printStackTrace( System.err );
    }
    finally{
      db.safelyCleanup( rs, pstmt, conn );
      return ftypeId;
    }
  }

  public void setHighDensityFlag()
  {
    this.highDensityFlag = FtypeTable.fetchHighDensityFlag(databaseName, ftypeid) ;
  }


  public static DbFtype[] fetchAll( Connection conn, String databaseName, int genboreeUserId )
  {
    Vector vectorOfDbFtypes = new Vector();
    if( conn != null )
    {
      try
      {
        String qs = "SELECT ftypeid, fmethod, fsource FROM ftype";
        PreparedStatement pstmt = conn.prepareStatement( qs );
        ResultSet rs = pstmt.executeQuery() ;

        while( rs.next() )
        {
          int ftypeId = rs.getInt( "ftypeid" );
          String fmethod = rs.getString( "fmethod" );
          String fsource = rs.getString( "fsource" );

          if( ( fmethod.compareToIgnoreCase( "Component" ) == 0 || fmethod.compareToIgnoreCase( "Supercomponent" ) == 0 ) )
          {
            continue;
          }

          if( TrackPermission.isTrackAllowed( databaseName, fmethod, fsource, genboreeUserId, true ) )
          {
            DbFtype currentFtype = new DbFtype(databaseName, ftypeId, fmethod, fsource);
            vectorOfDbFtypes.addElement( currentFtype );
          }
        }
        pstmt.close();
        rs.close();
      }
      catch( Exception ex )
      {
        System.err.println( "Exception on DbFtype::fetchAll => exception thrown. Details:\n" + ex.getMessage() );
        ex.printStackTrace( System.err );
      }
    }
    DbFtype[] arrayOfDbFtypes = new DbFtype[vectorOfDbFtypes.size()];
    vectorOfDbFtypes.copyInto( arrayOfDbFtypes );
    return arrayOfDbFtypes;
  }

    public static Hashtable breakByDatabase( DbFtype[] ftypes )
    {
        Hashtable ht = new Hashtable();
        if( ftypes != null )
            for( int i=0; i<ftypes.length; i++ )
            {
                DbFtype ft = ftypes[i];
                Vector v = (Vector) ht.get( ft.getDatabaseName() );
                if( v == null )
                {
                    v = new Vector();
                    ht.put( ft.getDatabaseName(), v );
                }
                if(!v.contains(ft))
                    v.addElement( ft );
            }

        for( Enumeration en=ht.keys(); en.hasMoreElements(); )
        {
                Vector v = (Vector) ht.get( en.nextElement() );
                v = noDupVector(v);
        }

        return ht;
    }
    public static Vector noDupVector( Vector in )
    {
        HashSet NoDupVector = new HashSet( );
        ArrayList notMe = new ArrayList( );

        for( int i = 0; i < in.size( ); i++ )
        {
            DbFtype one = ((DbFtype)in.elementAt(i));

            for( int j = 0; j < in.size( ); j++ )
            {
                DbFtype two = ((DbFtype)in.elementAt(j));

                if( (i != j) && (!notMe.contains( new Integer( j ))) ) {
                    if( one.getFtypeid() == two.getFtypeid() &&
                            one.getDatabaseName().equalsIgnoreCase(two.getDatabaseName()) ) {

                        NoDupVector.add( new Integer( j ) );
                        // now make sure this one not deleted!
                        notMe.add( new Integer( i ) );
                    }
                }
            }
        }

        Iterator iterator = NoDupVector.iterator();
        Vector objs = new Vector( NoDupVector.size() );
        for( int i = 0; i < NoDupVector.size( ); i++ ) {
            Integer x = (Integer)iterator.next( );
            int y = x.intValue( );

            objs.add( in.elementAt( y ) );
            //in.remove( in.elementAt( y ) );
        }

        // finally remove them!
        for( int i = 0; i < objs.size( ); i++ ) {
            in.remove( (DbFtype) objs.elementAt(i) );
        }
        return in;
    }
    protected static void createUrlTable( Connection conn )
    {
        try
        {
            Statement stmt = conn.createStatement();
            stmt.executeUpdate( createUrlTableStatement );
            stmt.close();
        } catch( Exception ex ) {}
    }
    public static boolean fetchUrls( Connection conn, DbFtype[] ftypes )
    {
        if( ftypes == null ) return false;
        if( conn != null ) try
        {
            PreparedStatement pstmt = conn.prepareStatement(
                    "SELECT url, description, label FROM featureurl WHERE ftypeid=?" );
            for( int i=0; i<ftypes.length; i++ )
            {
                DbFtype ft = ftypes[i];
                ft.setUrl( null );
                ft.setUrlDescription( null );
                pstmt.setInt( 1, ft.getFtypeid() );
                ResultSet rs = pstmt.executeQuery();
                if( rs.next() )
                {
                    ft.setUrl( rs.getString(1) );
                    ft.setUrlDescription( rs.getString(2) );
                    ft.setUrlLabel( rs.getString(3) );
                }
            }
            pstmt.close();
            return true;
        } catch( Exception ex )
        {
            if( ex instanceof SQLException && ((SQLException)ex).getErrorCode()==1146 )
                createUrlTable( conn );
        }

        return false;
    }
    public static boolean updateUrls( Connection conn, DbFtype[] ftypes )
    {
        if( ftypes == null ) return false;
        if( conn != null ) try
        {
            PreparedStatement delStmt = conn.prepareStatement(
                    "DELETE FROM featureurl WHERE ftypeid=?" );
            PreparedStatement insStmt = conn.prepareStatement(
                    "INSERT INTO featureurl (ftypeid, url, description, label) VALUES (?, ?, ?, ?)" );
            for( int i=0; i<ftypes.length; i++ )
            {
                DbFtype ft = ftypes[i];
                delStmt.setInt( 1, ft.getFtypeid() );
                delStmt.executeUpdate();
                if( Util.isEmpty(ft.getUrl()) ) continue;
                insStmt.setInt( 1, ft.getFtypeid() );
                insStmt.setString( 2, ft.getUrl() );
                insStmt.setString( 3, ft.getUrlDescription() );
                insStmt.setString( 4, ft.getUrlLabel() );
                insStmt.executeUpdate();
            }
            delStmt.close();
            insStmt.close();
            return true;
        } catch( Exception ex )
        {
            if( ex instanceof SQLException && ((SQLException)ex).getErrorCode()==1146 )
                createUrlTable( conn );
        }
        return false;
    }
    public boolean updateUrl( Connection conn )
    {
        if( getFtypeid() <= 0 ) return false;
        if( conn != null ) try
        {
            PreparedStatement delStmt = conn.prepareStatement(
                    "DELETE FROM featureurl WHERE ftypeid=?" );
            delStmt.setInt( 1, getFtypeid() );
            delStmt.executeUpdate();
            if( !Util.isEmpty(getUrlDescription()) )
            {
                PreparedStatement insStmt = conn.prepareStatement(
                        "INSERT INTO featureurl (ftypeid, url, description, label) "+
                        "VALUES (?, ?, ?, ?)" );
                insStmt.setInt( 1, getFtypeid() );
                insStmt.setString( 2, getUrl() );
                insStmt.setString( 3, getUrlDescription() );
                insStmt.setString( 4, getUrlLabel() );
                insStmt.executeUpdate();
                insStmt.close();
            }
            delStmt.close();
            return true;
        } catch( Exception ex )
        {
            if( ex instanceof SQLException && ((SQLException)ex).getErrorCode()==1146 )
                createUrlTable( conn );
        }
        return false;
    }
    public boolean fetch( Connection conn )
    {
        if( conn != null ) try
        {
            String qs = "SELECT fmethod, fsource FROM ftype WHERE ftypeid="+getFtypeid();
            PreparedStatement pstmt = conn.prepareStatement( qs );
            ResultSet rs = pstmt.executeQuery();
            boolean rc = false;
            if( rs.next() )
            {

                setFmethod( rs.getString(1) );
                setFsource( rs.getString(2) );
                setTrackName( fmethod + ":" + fsource );
                rc = true;
            }
            pstmt.close();
            return rc;
        } catch( Exception ex ) {}
        return false;
    }
    public boolean insert( Connection conn )
    {
        if( conn != null ) try
        {
            String qs = "INSERT IGNORE INTO ftype (fmethod, fsource) VALUES (?, ?)";
            PreparedStatement pstmt = conn.prepareStatement( qs );
            pstmt.setString( 1, getFmethod() );
            pstmt.setString( 2, getFsource() );
            boolean rc = (pstmt.executeUpdate() > 0);
            if( rc )
            {
                Statement stmt = conn.createStatement();
                ResultSet rs = stmt.executeQuery( "SELECT LAST_INSERT_ID()" );
                if( rs.next() ) setFtypeid( rs.getInt(1) );
                stmt.close();
            }
            pstmt.close();
            return rc;
        } catch( Exception ex ) {
            ex.printStackTrace();
        }
        return false;
    }
    public boolean update( Connection conn )
    {
        if( conn != null ) try
        {
            String qs = "UPDATE ftype SET fmethod=?, fsource=? "+
                    "WHERE ftypeid="+getFtypeid();
            PreparedStatement pstmt = conn.prepareStatement( qs );
            pstmt.setString( 1, getFmethod() );
            pstmt.setString( 2, getFsource() );
            boolean rc = (pstmt.executeUpdate() > 0);
            pstmt.close();
            return rc;
        } catch( Exception ex ) {}
        return false;
    }
    public boolean delete( Connection conn )
    {
        if( conn != null ) try
        {
            String qs = "DELETE FROM ftype WHERE ftypeid="+getFtypeid();
            Statement stmt = conn.createStatement();
            boolean rc = (stmt.executeUpdate(qs) > 0);
            stmt.close();
            return rc;
        } catch( Exception ex ) {}
        return false;
    }

  public boolean belongsTo(String linkId)
  {
    if(linkIds == null) return false ;
    return linkIds.contains(linkId) ;
  }

  public boolean isEmpty(DBAgent db)
  {
    try
    {
      Connection conn = db.getConnection(databaseName) ;
      if(conn != null)
      {
        String query = "SELECT COUNT(ftypeid) FROM fdata2 WHERE ftypeid=" + ftypeid ;
        Statement st = conn.createStatement() ;
        ResultSet rs = st.executeQuery(query) ;
        boolean hasData = false ;
        if(rs.next()) hasData = (rs.getInt(1) > 0) ;
        st.close() ;
        return !hasData ;
      }

      // Couldn't find any entries
      return true ;
    }
    catch (SQLException e)
    {
      return true ;
    }
  }

    public boolean fetchLinkIds( Connection conn, int _userId )
    {
        try
        {
            linkIds = new Vector();
            PreparedStatement pstmt = conn.prepareStatement(
                    "SELECT distinct linkId FROM featuretolink WHERE userId=? AND ftypeid=?" );
            pstmt.setInt( 1, _userId );
            pstmt.setInt( 2, getFtypeid() );
            ResultSet rs = pstmt.executeQuery();
            while( rs.next() )
            {
                linkIds.addElement( rs.getString(1) );
            }
            pstmt.close();
            return true;
        } catch( Exception ex ) {}
        return false;
    }
    public boolean updateLinkIds( Connection conn, String[] _linkIds, int _userId )
    {
        try
        {
            PreparedStatement pstmt = conn.prepareStatement(
                    "DELETE FROM featuretolink WHERE userId=? AND ftypeid=?" );
            pstmt.setInt( 1, _userId );
            pstmt.setInt( 2, getFtypeid() );
            pstmt.executeUpdate();
            //pstmt.close();
            if( _linkIds == null ) return true;
            pstmt = conn.prepareStatement(
                    "INSERT INTO featuretolink (linkId, userId, ftypeid) VALUES (?, ?, ?)" );
            linkIds = new Vector();
            for( int i=0; i<_linkIds.length; i++ )
            {
                String lid = _linkIds[i];
                linkIds.addElement( lid );
                pstmt.setString( 1, lid );
                pstmt.setInt( 2, _userId );
                pstmt.setInt( 3, getFtypeid() );
                pstmt.executeUpdate();
            }
            pstmt.close();
            return true;
        } catch( Exception ex ) {}
        return false;
    }

}
