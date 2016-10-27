package org.genboree.dbaccess;

import org.genboree.util.Util;
import org.genboree.util.GenboreeUtils;

import java.util.*;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

public class GenboreeUpload
{
  protected int uploadId = -1;
  protected DbFtype[] tracks = null;
  protected int userId = -1;
  protected int refSeqId = -1;
  protected String created = null;
  protected String userDbName = null;
  protected String databaseName = null;
  protected String configFileName = null;

  /* Setters and Getters */
  public int getUploadId()
  {
    return uploadId;
  }

  public void setUploadId( int uploadId )
  {
    this.uploadId = uploadId;
  }

  public int getUserId()
  {
    return userId;
  }

  public void setUserId( int userId )
  {
    this.userId = userId;
  }

  public int getRefSeqId()
  {
    return refSeqId;
  }

  public void setRefSeqId( int refSeqId )
  {
    this.refSeqId = refSeqId;
  }

  public String getCreated()
  {
    return created;
  }

  public void setCreated( String created )
  {
    this.created = created;
  }

  public String getUserDbName()
  {
    return userDbName;
  }

  public void setUserDbName( String userDbName )
  {
    this.userDbName = userDbName;
  }

  public String getDatabaseName()
  {
    return databaseName;
  }

  public void setDatabaseName( String databaseName )
  {
    this.databaseName = databaseName;
  }

  public String getConfigFileName()
  {
    return configFileName;
  }

  public void setConfigFileName( String configFileName )
  {
    this.configFileName = configFileName;
  }

  public DbFtype[] getTracks()
  {
    return tracks;
  }

  /* End of setters and getters */
  /* TODO Why is the initialization method empty? I need to go back and initialize appropiately*/
  public GenboreeUpload()
  {
  }

  public static String fetchUploadIdFromRefSeqIdDbName( DBAgent db, String _refSeqId, String myDbName )
  {
    Connection conn = null;
    String qs = null;
    String upload = null;
    ResultSet rs = null;
    Statement stmt = null;

    if( _refSeqId == null || myDbName == null ) return null;

    try
    {
      conn = db.getConnection();
      if( conn == null ) return null;
      qs = "SELECT upload.uploadId FROM upload, refseq, refseq2upload " +
              "WHERE refseq.refseqId = refseq2upload.refseqId AND " +
              "upload.uploadId = refseq2upload.uploadId AND upload.databaseName = '" +
              myDbName + "' and upload.refSeqId = " + _refSeqId;

      /* TODO upload table has duplicated data need to fix for now I using this dumb query
SELECT upload.uploadId FROM upload, refseq, refseq2upload WHERE refseq.refseqId =
refseq2upload.refseqId AND upload.uploadId = refseq2upload.uploadId AND
upload.databaseName = '$databaseName' and upload.refSeqId = $refseqId;
the upload.refSeqId needs to be removed right now when quering for a template
database return all the uploadIds of databases sharing the refseqId */

      stmt = conn.createStatement();
      rs = stmt.executeQuery( qs );
      if( rs.next() ) upload = rs.getString( 1 );

      stmt.close();
    } catch( Exception ex )
    {
      System.err.println( "Exception on fetchUploadIdFromRefSeqIdDbName database genboree and query = " + qs );
      System.err.flush();
    }
    finally
    {
      return upload;
    }
  }


  public static String[] getUrlsFromFtype( DBAgent db, String[] uploads, String fmethod, String fsource )
  {
    String[] allUrls = new String[3];
    String url = null;
    String description = null;
    String label = null;
    Connection conn = null;
    String qs = "SELECT featureurl.url, featureurl.description, featureurl.label " +
            "FROM ftype, featureurl WHERE featureurl.ftypeid = ftype.ftypeid AND " +
            "ftype.fmethod = ? AND ftype.fsource = ?";
    ResultSet rs = null;
    PreparedStatement pstmt = null;

    if( uploads == null || fmethod == null || fsource == null ) return null;

    try
    {
      for( int i = 0; i < uploads.length; i++ )
      {
        conn = db.getConnection( uploads[ i ] );
        pstmt = conn.prepareStatement( qs );
        pstmt.setString( 1, fmethod );
        pstmt.setString( 2, fsource );
        rs = pstmt.executeQuery();
        url = description = label = null;
        if( rs.next() )
        {
          url = rs.getString( 1 );
          description = rs.getString( 2 );
          label = rs.getString( 3 );
        }
        if( url != null || description != null || label != null )
        {
          allUrls[ 0 ] = url;
          allUrls[ 1 ] = description;
          allUrls[ 2 ] = label;
          break;
        }
      }
    } catch( Exception ex )
    {
      System.err.println( "Exception on GenboreeUpload.getUrlsFromFtype() where query is " + qs );
      System.err.flush();
    }
    finally
    {
      return allUrls;
    }
  }

  /* TODO Manuel wrote on 08/05/05: Should I replace this function for something better? */
  // Don't use this ; at least not in gbrowser.jsp ; Reimplemented new version in GBrowserUtils.java
  public static String[] fetchClassNames( DbFtype[] allTracks )
  {
    Hashtable allClasses = null;
    String className = null;
    String allClassesInAllTracks[] = null;
    int i = 0;

    if( allTracks == null ) return null;

    allClasses = new Hashtable();

    for( i = 0; i < allTracks.length; i++ )
    {
      String[] myClasses = null;

      myClasses = allTracks[ i ].getBelongToAllThisGclasses();
      for( int a = 0; a < myClasses.length; a++ )
      {
        className = myClasses[ a ];
        allClasses.put( className, className );
      }
    }
    allClassesInAllTracks = new String[allClasses.size()];

    i = 0;
    for( Enumeration en = allClasses.keys(); en.hasMoreElements(); )
    {
      String key = ( String )en.nextElement();
      className = ( String )allClasses.get( key );
      allClassesInAllTracks[ i ] = className;
      i++;
    }

    return allClassesInAllTracks;
  }

  // Don't use this, at least not in gbrowser.jsp ; Reimplemented new version in GBrowserUtils.java
  public static String[] fetchTrackNames( DbFtype[] allTracks )
  {
    if( allTracks == null ) return null;

    String[] arrayWithTrackNames = null;
    arrayWithTrackNames = new String[allTracks.length];

    for( int i = 0; i < allTracks.length; i++ )
      arrayWithTrackNames[ i ] = allTracks[ i ].toString();

    return arrayWithTrackNames;
  }

  /* if I already have the class why not used! */
  // Don't use this ; at least not in gbrowser.jsp ; Reimplemented new version in GBrowserUtils.java
  // Ideally, even gbrowser.jsp should use the HashMap->ArrayList version not the old, slow, cumbersome Hashtable->Vector version.
  public static Hashtable fetchHashWithVectorsOfFtypesPerClass( DbFtype[] myTrackArray, String[] classes )
  {
    Hashtable classesHash = null;

    if( myTrackArray == null || classes == null ) return null;

    classesHash = new Hashtable();


    for( int i = 0; i < classes.length; i++ )
    {
      Vector temporary = GenboreeUpload.extractDbFtypesInClass( myTrackArray, classes[ i ] );
      classesHash.put( classes[ i ], temporary );
    }
    return classesHash;
  }

  public static Hashtable fetchHashWithVectorsOfFtypesPerClass( DbFtype[] myTrackArray )
  {
    Hashtable classesHash = null;
    String[] classes = null;

    if( myTrackArray == null ) return null;
    classes = GenboreeUpload.fetchClassNames( myTrackArray );
    if( classes == null ) return null;

    classesHash = fetchHashWithVectorsOfFtypesPerClass( myTrackArray, classes );

    return classesHash;
  }

  public static Vector extractDbFtypesInClass( DbFtype[] allTracksUsed, String className )
  {
    Vector classesInTracks = null;
    DbFtype currentTrack = null;
    String[] allClassesUsed = null;
    int i = 0;
    int a = 0;
    boolean addedTrack = false;

    if( allTracksUsed == null || className == null ) return null;
    classesInTracks = new Vector();
    for( i = 0; i < allTracksUsed.length; i++ )
    {
      currentTrack = allTracksUsed[ i ];
      allClassesUsed = currentTrack.getBelongToAllThisGclasses();
      addedTrack = false;
      if( allClassesUsed != null && allClassesUsed.length > 0 && !addedTrack )
      {
        for( a = 0; a < allClassesUsed.length && !addedTrack; a++ )
        {
          if( allClassesUsed[ a ].equals( className ) )
          {
            if( !classesInTracks.contains( allTracksUsed[ i ] ) )
              classesInTracks.addElement( allTracksUsed[ i ] );
            addedTrack = true;
          }
        }
      }
    }
    return classesInTracks;
  }

  public static String[] fetchClassesInFtypeId( DBAgent db, String[] uploads, String fmethod, String fsource )
  {
    Connection conn = null;
    ResultSet rs = null;
    String qs = "SELECT distinct gclass.gclass from gclass, ftype2gclass, ftype where gclass.gid = " +
            "ftype2gclass.gid AND ftype.ftypeid = ftype2gclass.ftypeid AND ftype.fmethod = ? " +
            "AND ftype.fsource = ?";
    Hashtable htGclass = new Hashtable();
    int i = 0;
    int a = 0;
    int ftypeId = -1;
    String listOfGclasses[] = null;
    PreparedStatement pstmt = null;
    boolean goNextDb = true;

    if( uploads == null || fmethod == null || fsource == null ) return null;

    try
    {


      for( i = 0; i < uploads.length && goNextDb; i++ )
      {
        ftypeId = GenboreeUtils.fetchFtypeId( db, uploads[ i ], fmethod, fsource );
        if( ftypeId > 0 )
        {
          conn = db.getConnection( uploads[ i ] );
          pstmt = conn.prepareStatement( qs );
          pstmt.setString( 1, fmethod );
          pstmt.setString( 2, fsource );
          rs = pstmt.executeQuery();
          while( rs.next() )
            htGclass.put( rs.getString( 1 ), rs.getString( 1 ) );
        }
      }
      listOfGclasses = new String[htGclass.size()];
      a = 0;
      for( Enumeration en = htGclass.keys(); en.hasMoreElements(); )
      {
        listOfGclasses[ a ] = ( String )htGclass.get( en.nextElement() );
        a++;
      }
    } catch( Exception ex )
    {
      System.err.println( "There has been an exception on fetchClassesInFtypeId using databaseName = " + uploads[ i ] );
      System.err.println( "and the query is " + qs );
      System.err.flush();
    }
    finally
    {
      return listOfGclasses;
    }
  }


  /* Modified by Manuel 080505 */
  public static GenboreeUpload[] fetchAll( DBAgent db, String _refSeqId, String _entryPointId, int genboreeUserId )
  {
    Connection conn = null;
    String qs = null;
    ResultSet rs = null;
    Statement stmt = null;
    GenboreeUpload p = null;
    Vector v = null;
    GenboreeUpload[] rc = null;
    try
    {
      conn = db.getConnection();
      qs = "SELECT uploadId, userId, refSeqId, created, userDbName, " +
              "databaseName, configFileName FROM upload";

      if( _refSeqId != null )
      {
        qs = "SELECT u.uploadId, u.userId, u.refSeqId, u.created, u.userDbName, " +
                "u.databaseName, u.configFileName FROM upload u, refseq2upload ru " +
                "WHERE u.uploadId=ru.uploadId AND ru.refSeqId=" + _refSeqId;
      }


      stmt = conn.createStatement();
      rs = stmt.executeQuery( qs );
      v = new Vector();

      while( rs.next() )
      {
        p = new GenboreeUpload();
        p.setUploadId( rs.getInt( 1 ) );
        p.setUserId( rs.getInt( 2 ) );
        p.setRefSeqId( rs.getInt( 3 ) );
        p.setCreated( rs.getString( 4 ) );
        p.setUserDbName( rs.getString( 5 ) );
        p.setDatabaseName( rs.getString( 6 ) );
        p.setConfigFileName( rs.getString( 7 ) );

/* replaced by fetchTracksFromRefSeqIdEntryPoint 080505 Manuel
				p.fetchTracks( db, _entryPointId );
*/
        p.fetchTracksFromRefSeqIdEntryPoint( db, _refSeqId, _entryPointId, genboreeUserId );

        v.addElement( p );
      }
      rc = new GenboreeUpload[v.size()];
      v.copyInto( rc );

      stmt.close();
    } catch( Exception ex )
    {
      System.err.println( "GenboreeUpload.fetchAll() where query is " + qs );
      System.err.flush();
    }
    finally
    {
      return rc;
    }
  }

  public boolean fetch( DBAgent db ) throws SQLException
  {
    Connection conn = null;
    String qs = null;
    ResultSet rs = null;
    Statement stmt = null;
    boolean rc = false;

    try
    {
      conn = db.getConnection();
      qs = "SELECT userId, refSeqId, created, userDbName, " +
              "databaseName, configFileName FROM upload WHERE uploadId=" + getUploadId();
      stmt = conn.createStatement();
      rs = stmt.executeQuery( qs );
      if( rs.next() )
      {
        setUserId( rs.getInt( 1 ) );
        setRefSeqId( rs.getInt( 2 ) );
        setCreated( rs.getString( 3 ) );
        setUserDbName( rs.getString( 4 ) );
        setDatabaseName( rs.getString( 5 ) );
        setConfigFileName( rs.getString( 6 ) );
        rc = true;
      }
      stmt.close();
    } catch( Exception ex )
    {
      System.err.println( "Exception on GenboreeUpload.fetch() where query is " + qs );
      System.err.flush();
    }
    finally
    {
      return rc;
    }
  }

  public boolean fetchByDatabase( DBAgent db ) throws SQLException
  {
    Connection conn = null;
    String qs = null;
    PreparedStatement pstmt = null;
    ResultSet rs = null;
    boolean rc = false;
    try
    {
      conn = db.getConnection();
      qs = "SELECT uploadId, userId, created, userDbName, " +
              "configFileName FROM upload " +
              "WHERE refSeqId=" + getRefSeqId() + " AND databaseName='" + getDatabaseName() + "'";
      pstmt = conn.prepareStatement( qs );
      rs = pstmt.executeQuery();
      if( rs.next() )
      {

        setUploadId( rs.getInt( 1 ) );
        setUserId( rs.getInt( 2 ) );
        setCreated( rs.getString( 3 ) );
        setUserDbName( rs.getString( 4 ) );
        setConfigFileName( rs.getString( 5 ) );
        rc = true;
      }
      pstmt.close();
    } catch( Exception ex )
    {
      System.err.println( "Exception on GenboreeUpload.fetchByDatabase() where query is " + qs );
      System.err.flush();
    }
    finally
    {
      return rc;
    }
  }

  public boolean insert( DBAgent db ) throws SQLException
  {
    Connection conn = null;
    String qs = null;
    boolean rc = false;
    PreparedStatement pstmt = null;
    try
    {
      conn = db.getConnection( null, false );
      qs = "INSERT INTO upload (userId, refSeqId, created, userDbName, " +
              "databaseName, configFileName) VALUES (?, ?, sysdate(), ?, ?, ?)";
      pstmt = conn.prepareStatement( qs );
      pstmt.setInt( 1, getUserId() );
      pstmt.setInt( 2, getRefSeqId() );
      pstmt.setString( 3, getUserDbName() );
      pstmt.setString( 4, getDatabaseName() );
      pstmt.setString( 5, getConfigFileName() );
      rc = ( pstmt.executeUpdate() > 0 );
      if( rc ) setUploadId( db.getLastInsertId( conn ) );
      pstmt.close();
    } catch( Exception ex )
    {
      System.err.println( "Exception on GenboreeUpload.insert() where query is " + qs );
      System.err.flush();
    }
    finally
    {
      return rc;
    }
  }

  public static ArrayList returnDatabaseNames(DBAgent db, boolean useAVPs)
  {
    Connection conn = null ;
    String query = null ;
    ArrayList databases = null ;
    DbResourceSet dbRes = null ;

    if(useAVPs)
    {
      query = "SELECT databaseName FROM refseq WHERE useValuePairs= 'y'" ;
    }
    else
    {
      query = "SELECT databaseName FROM refseq WHERE useValuePairs= 'n'" ;
    }

    try
    {
      conn = db.getConnection("genboree") ;
      databases = new ArrayList(200) ;
      dbRes = db.executeQuery(null, query) ;
      ResultSet rs = dbRes.resultSet ;

      while(rs.next())
      {
        databases.add(rs.getString("databaseName")) ;
      }
      dbRes.close() ;
    }
    catch( Exception ex )
    {
      db.reportError(ex, "returnDatabaseNames") ;
    }
    return databases ;
  }

  // Original method. Calls other poorly written method. Has replacement in RefSeqTable class (wow! makes sense)
  // which is used in new code and that makes gbrowser.jsp work properly.
  public static String[] returnDatabaseNames(DBAgent db, String refSeqId)
  {
    return returnDatabaseNames(db, refSeqId, true) ;
  }

  // Original method. Poorly written. Has replacement in RefSeqTable class (wow! makes sense)
  // which is used in new code and that makes gbrowser.jsp work properly.
  public static String[] returnDatabaseNames( DBAgent db, String _refSeqId, boolean doCache )
  {
    Vector v = new Vector();
    Connection conn = null;
    String qs = null;
    String uploads[] = null;
    String query1 = null;
    String mainDatabase = null;
    ResultSet rs = null;
    Statement stmt = null;

    if( _refSeqId == null ) return null;

    try
    {
      if( doCache )
        conn = db.getConnection();
      else
        conn = db.getNoCacheConnection( null );

      query1 = "select databaseName from refseq where refseqId = " + _refSeqId;
      qs = "SELECT u.databaseName FROM upload u, refseq2upload ru, refseq r " +
              "WHERE u.uploadId=ru.uploadId AND r.refSeqId=ru.refSeqId AND " +
              "r.databaseName!=u.databaseName AND ru.refSeqId = " + _refSeqId;

      stmt = conn.createStatement();
      rs = stmt.executeQuery( query1 );
      if( rs.next() )
      {
        mainDatabase = rs.getString( 1 );
        v.addElement( mainDatabase );
      } else
        return null;

      stmt = conn.createStatement();
      rs = stmt.executeQuery( qs );
      while( rs.next() )
      {
        String d = rs.getString( 1 );
        v.addElement( d );
      }
      uploads = new String[v.size()];
      v.copyInto( uploads );

    } catch( Exception ex )
    {
      System.err.println( "Exception on returnDatabaseNames and query is " + qs );
      System.err.flush();
    }
    finally
    {
      db.safelyCleanup(rs, stmt, conn);
      return uploads;
    }
  }

  public static int fetchRidFromRefName( DBAgent db, String databaseName, String _entryPointId )
  {
    Connection conn = null;
    int rid = -1;
    Statement stmt = null;
    ResultSet rs = null;
    if( databaseName == null || _entryPointId == null ) return -1;

    try
    {
      conn = db.getConnection( databaseName );

      if( _entryPointId != null )
      {
        stmt = conn.createStatement();
        rs = stmt.executeQuery( "SELECT rid FROM fref WHERE refname='" + _entryPointId + "'" );
        if( rs.next() ) rid = rs.getInt( 1 );
        stmt.close();
      }
    } catch( SQLException e )
    {
      System.err.println( "There has been an exception using databaseName = " + databaseName );
      System.err.println( "and the query is SELECT rid FROM fref WHERE refname= '" + _entryPointId + "'" );
      System.err.flush();
    }
    finally
    {
      return rid;
    }
  }

  public static HashMap getFtypeCounts( Connection conn )
  {
    String ftypeCountQuery = null;
    HashMap hashWithKeys = new HashMap();

    ftypeCountQuery = "SELECT ftypeid, numberOfAnnotations FROM ftypeCount";
    try
    {
      Statement stmt = conn.createStatement();
      ResultSet rs = stmt.executeQuery( ftypeCountQuery );
      while( rs.next() )
      {
        hashWithKeys.put( rs.getInt( "ftypeid" ), rs.getString( "numberOfAnnotations" ) );
      }
      stmt.close();
      rs.close();
    }
    catch( Exception ex )
    {
      ex.printStackTrace( System.err );
      System.err.println( "Exception quering ftypeCount in method GenboreeUploads::getFtypeCounts" );
      System.err.flush();
    }


    return hashWithKeys;
  }


  public static HashMap getAttNames( Connection conn )
  {
    String ftypeCountQuery = null;
    HashMap hashWithKeys = new HashMap();

    ftypeCountQuery = "SELECT attNameId, name FROM attNames";
    try
    {
      Statement stmt = conn.createStatement();
      ResultSet rs = stmt.executeQuery( ftypeCountQuery );
      while( rs.next() )
      {
        hashWithKeys.put( rs.getInt( "attNameId" ), rs.getString( "name" ) );
      }
      stmt.close();
      rs.close();
    }
    catch( Exception ex )
    {
      ex.printStackTrace( System.err );
      System.err.println( "Exception quering attNames in method GenboreeUploads::getAttNames" );
      System.err.flush();
    }

    return hashWithKeys;
  }


  public static HashMap getFtypeHash( Connection conn, boolean trackNameAsKey, boolean urlEncode )
  {
    String ftypeQuery = null;
    HashMap hashWithKeys = new HashMap();

    ftypeQuery = "SELECT ftypeid, CONCAT(fmethod, ':', fsource) trackName FROM ftype";
    try
    {
      Statement stmt = conn.createStatement();
      ResultSet rs = stmt.executeQuery( ftypeQuery );
      while( rs.next() )
      {
        String trackName = rs.getString( "trackName" );
        if( urlEncode )
          trackName = Util.urlEncode( trackName );

        if( trackNameAsKey )
          hashWithKeys.put( trackName, rs.getInt( "ftypeid" ) );
        else
          hashWithKeys.put( rs.getInt( "ftypeid" ), trackName );
      }
      stmt.close();
      rs.close();
    }
    catch( Exception ex )
    {
      ex.printStackTrace( System.err );
      System.err.println( "Exception quering ftype in method GenboreeUploads::getFtypeHash" );
      System.err.flush();
    }


    return hashWithKeys;
  }


  public static HashMap fetchAllTracksFromUploadsWithCounts( DBAgent db, String myRefseqId, int genboreeUserId, boolean urlEncode )
  {
    String uploads[] = null;
    Connection conn = null;
    ResultSet rs;
    String qs = null;
    PreparedStatement pstmt = null;
    String ftypes[] = null;
    int i = 0;
    Enumeration en;
    int size = 0;
    HashMap hashWithKeys = new HashMap();


    if( myRefseqId == null ) return null;

    qs = "SELECT ftype.fmethod, ftype.fsource, ftypeCount.numberOfAnnotations FROM ftypeCount, ftype WHERE ftype.ftypeid = ftypeCount.ftypeid";

    uploads = GenboreeUpload.returnDatabaseNames( db, myRefseqId );

    if( uploads == null ) return null;

    try
    {
      for( i = 0; i < uploads.length; i++ )
      {
        conn = db.getConnection( uploads[ i ] );
        pstmt = conn.prepareStatement( qs );
        rs = pstmt.executeQuery();

        while( rs.next() )
        {
          String fmethod = rs.getString( 1 );
          String fsource = rs.getString( 2 );
          String ftypeKey = fmethod + ":" + fsource;
          if( TrackPermission.isTrackAllowed( uploads[ i ], fmethod, fsource, genboreeUserId ) )
          {
            if( urlEncode )
              ftypeKey = Util.urlEncode( ftypeKey );

            hashWithKeys.put( ftypeKey, rs.getInt( 3 ) );
          }
        }
      }

      pstmt.close();
    } catch( SQLException e )
    {
      System.err.println( "There has been an exception using databaseName = " + uploads[ i ] );
      System.err.println( "and the query is " + qs );
      System.err.flush();
    }
    finally
    {
      return hashWithKeys;
    }
  }


  public static String[] fetchAllTracksFromUploads( DBAgent db, String myRefseqId, int genboreeUserId )
  {
    String uploads[] = null;
    Connection conn = null;
    ResultSet rs;
    String qs = null;
    Hashtable tempFtypeHash = null;
    PreparedStatement pstmt = null;
    String ftypes[] = null;
    int i = 0;
    Enumeration en;
    int size = 0;


    if( myRefseqId == null ) return null;

    qs = "SELECT fmethod, fsource FROM ftype";

    uploads = GenboreeUpload.returnDatabaseNames( db, myRefseqId );
    
    if( uploads == null ) return null;
    tempFtypeHash = new Hashtable();

    try
    {
      for( i = 0; i < uploads.length; i++ )
      {
        conn = db.getConnection( uploads[ i ] );
        pstmt = conn.prepareStatement( qs );
        rs = pstmt.executeQuery();

        while( rs.next() )
        {
          String fmethod = rs.getString( 1 );
          String fsource = rs.getString( 2 );
          String ftypeKey = fmethod + ":" + fsource;
          if( TrackPermission.isTrackAllowed( uploads[ i ], fmethod, fsource, genboreeUserId ) )
            tempFtypeHash.put( ftypeKey, ftypeKey );
        }
      }
      size = tempFtypeHash.size();
      ftypes = new String[size];
      i = 0;
      for( en = tempFtypeHash.keys(); en.hasMoreElements(); )
      {
        if( i < size )
          ftypes[ i ] = ( String )en.nextElement();
        i++;
      }
      pstmt.close();
    } catch( SQLException e )
    {
      System.err.println( "There has been an exception using databaseName = " + uploads[ i ] );
      System.err.println( "and the query is " + qs );
      System.err.flush();
    }
    finally
    {
      return ftypes;
    }
  }

  public static ArrayList fetchTrackIdsFromFtype( Connection conn )
  {
    ResultSet rs;
    ArrayList listOfIds = null;
    Statement stmt = null;
    String query = "SELECT ftypeid FROM ftype";

    try
    {
      listOfIds = new ArrayList( 200 );
      stmt = conn.createStatement();
      rs = stmt.executeQuery( query );
      while( rs.next() )
        listOfIds.add( rs.getString( "ftypeid" ) );
      stmt.close();
    } catch( SQLException e )
    {
      System.err.println( "Hey!, what is wrong with you! You need to pass me an open connection to the database so I can" +
              " do my job and performe the following query: " + query );
      System.err.flush();
    }
    finally
    {
      return listOfIds;
    }
  }


  public static HashMap fetchTrackIdsLinkIds( Connection conn )
  {
    ResultSet rs;
    HashMap listOfFtyepeIds = new HashMap();
    Statement stmt = null;
    String query = "SELECT featuretolink.ftypeid ftypeid, featuretolink.linkId FROM featuretolink, link WHERE link.linkId = featuretolink.linkId " +
            " AND link.description like '%comments%'";
    try
    {
      stmt = conn.createStatement();
      rs = stmt.executeQuery( query );
      while( rs.next() )
        listOfFtyepeIds.put( rs.getString( "ftypeid" ), rs.getString( "linkId" ) );
      stmt.close();
    } catch( SQLException e )
    {
      System.err.println( "Hey!, what is wrong with you! You need to pass me an open connection to the database so I can" +
              " do my job and performe the following query: " + query );
      System.err.flush();
    }
    finally
    {
      return listOfFtyepeIds;
    }
  }


  public static String[] fetchFtypeInfoFromId( Connection conn, String ftypeId )
  {
    ResultSet rs;
    Statement stmt = null;
    String query = null;
    String[] results = null;

    if( ftypeId == null || ftypeId.length() < 1 )
      return null;

    results = new String[3];

    query = "SELECT ftypeid, fmethod, fsource FROM ftype WHERE ftypeId = '" + ftypeId + "'";

    try
    {
      stmt = conn.createStatement();
      rs = stmt.executeQuery( query );
      while( rs.next() )
      {
        results[ 0 ] = rs.getString( "ftypeId" );
        results[ 1 ] = rs.getString( "fmethod" );
        results[ 2 ] = rs.getString( "fsource" );
      }
      stmt.close();
    } catch( SQLException e )
    {
      results = null;
      System.err.println( "Hey!, what is wrong with you! You need to pass me an open connection to the database so I can" +
              " do my job and performe the following query: " + query );
      System.err.flush();
    }
    finally
    {
      return results;
    }
  }


  public static String[] fetchLinkInfoFromId( Connection conn, String linkId )
  {
    ResultSet rs;
    Statement stmt = null;
    String query = null;
    String[] results = null;

    if( linkId == null || linkId.length() < 1 )
      return null;

    results = new String[3];

    query = "SELECT linkId, name, description FROM link WHERE linkId = '" + linkId + "'";

    try
    {
      stmt = conn.createStatement();
      rs = stmt.executeQuery( query );
      while( rs.next() )
      {
        results[ 0 ] = rs.getString( "linkId" );
        results[ 1 ] = rs.getString( "name" );
        results[ 2 ] = rs.getString( "description" );
      }
      stmt.close();
    } catch( SQLException e )
    {
      results = null;
      System.err.println( "Hey!, what is wrong with you! You need to pass me an open connection to the database so I can" +
              " do my job and performe the following query: " + query );
      System.err.flush();
    }
    finally
    {
      return results;
    }
  }

  public static HashMap detectLinks( boolean useVP )
  {
    String databaseName = null;
    String tempTrackId = null;
    String tempLinkId = null;
    String[] tempTrackDescription = null;
    String[] tempLinkDescription = null;
    HashMap tracksIds = null;
    ArrayList databaseNames = null;
    DBAgent myDb = null;
    Connection conn = null;
    int activeLinks = 0;
    HashMap results = null;
    String tempKey = null;
    HashMap tempResults = null;


    myDb = DBAgent.getInstance();
    databaseNames = GenboreeUpload.returnDatabaseNames( myDb, useVP );
    results = new HashMap();
    for( int a = 0; a < databaseNames.size(); a++ )
    {
      databaseName = ( String )databaseNames.get( a );

      try
      {
        conn = myDb.getNoCacheConnection( databaseName );
      } catch( SQLException e )
      {
        System.err.println( "Unable to generate connection for databaseName = " + databaseName );
        System.err.flush();
      }

      activeLinks = GenboreeUpload.fetchNumberActiveLinks( conn );
      if( activeLinks >= 0 )
        tracksIds = GenboreeUpload.fetchTrackIdsLinkIds( conn );

      Iterator tracksLinksIterator = tracksIds.entrySet().iterator();
      while( tracksLinksIterator.hasNext() )
      {
        Map.Entry tracksLinksMap = ( Map.Entry )tracksLinksIterator.next();
        tempTrackId = ( String )tracksLinksMap.getKey();
        tempLinkId = ( String )tracksLinksMap.getValue();
        if( tempTrackId == null || tempLinkId == null ) continue;

        tempLinkDescription = GenboreeUpload.fetchLinkInfoFromId( conn, tempLinkId );
        tempTrackDescription = GenboreeUpload.fetchFtypeInfoFromId( conn, tempTrackId );

        tempKey = databaseName + "-" + tempTrackId;
        tempResults = new HashMap();
        tempResults.put( "databaseName", databaseName );
        tempResults.put( "ftypeid", tempTrackDescription[ 0 ] );
        tempResults.put( "fmethod", tempTrackDescription[ 1 ] );
        tempResults.put( "fsource", tempTrackDescription[ 2 ] );
        tempResults.put( "linkId", tempLinkDescription[ 0 ] );
        tempResults.put( "name", tempLinkDescription[ 1 ] );
        tempResults.put( "description", tempLinkDescription[ 2 ] );
        results.put( tempKey, tempResults );

      }


      try
      {
        conn.close();
      } catch( SQLException e )
      {
        System.err.println( "Unable to close connection for databaseName = " + databaseName );
        System.err.flush();
      }


    }
    return results;
  }

  public static ArrayList fetchTrackIdsWithLinks( Connection conn )
  {
    ResultSet rs;
    ArrayList listOfFtyepeIds = null;
    Statement stmt = null;
    String query = "SELECT featuretolink.ftypeid ftypeid FROM featuretolink, link WHERE link.linkId = featuretolink.linkId " +
            " AND link.description like '%comments%'";
    try
    {
      listOfFtyepeIds = new ArrayList( 200 );
      stmt = conn.createStatement();
      rs = stmt.executeQuery( query );
      while( rs.next() )
        listOfFtyepeIds.add( rs.getString( "ftypeid" ) );
      stmt.close();
    } catch( SQLException e )
    {
      System.err.println( "Hey!, what is wrong with you! You need to pass me an open connection to the database so I can" +
              " do my job and performe the following query: " + query );
      System.err.flush();
    }
    finally
    {
      return listOfFtyepeIds;
    }
  }




  public static ArrayList fetchTrackIdsFromDatabase( Connection conn )
  {
    ResultSet rs;
    ArrayList listOfIds = null;
    Statement stmt = null;
    String query = "SELECT distinct(ftypeid) typeid from fdata2";

    try
    {
      listOfIds = new ArrayList( 200 );
      stmt = conn.createStatement();
      rs = stmt.executeQuery( query );
      while( rs.next() )
        listOfIds.add( rs.getString( "typeid" ) );
      stmt.close();
    } catch( SQLException e )
    {
      System.err.println( "Hey!, what is wrong with you! You need to pass me an open connection to the database so I can" +
              " do my job and performe the following query: " + query );
      System.err.flush();
    }
    finally
    {
      return listOfIds;
    }
  }

  public static int fetchMinTrackIdsFromFdata2( Connection conn )
  {
    ResultSet rs;
    int minId = 0;
    Statement stmt = null;
    String query = "SELECT min( ftypeid ) minimum  FROM fdata2";

    try
    {
      stmt = conn.createStatement();
      rs = stmt.executeQuery( query );
      if( rs.next() )
        minId = rs.getInt( "minimum" );
      stmt.close();
    } catch( SQLException e )
    {
      System.err.println( "Hey pay attention! the database " );
      System.err.println( "has exploted due to your sloppy query:" + query );
      System.err.flush();
    }
    finally
    {
      return minId;
    }
  }

  public static int fetchMinTrackIdsFromFidText( Connection conn )
  {
    ResultSet rs;
    int minId = 0;
    Statement stmt = null;
    String query = "SELECT min( ftypeid ) minimum  FROM fidText";

    try
    {
      stmt = conn.createStatement();
      rs = stmt.executeQuery( query );
      if( rs.next() )
        minId = rs.getInt( "minimum" );
      stmt.close();
    } catch( SQLException e )
    {
      System.err.println( "Hey pay attention! the database " );
      System.err.println( "has exploted due to your sloppy query:" + query );
      System.err.flush();
    }
    finally
    {
      return minId;
    }
  }


  public static int fetchNumberActiveLinks( Connection conn )
  {
    ResultSet rs;
    int total = 0;
    Statement stmt = null;
    String query = "SELECT count(*) total FROM featuretolink, link WHERE link.linkId = featuretolink.linkId AND link.description like '%comments%'";

    try
    {
      stmt = conn.createStatement();
      rs = stmt.executeQuery( query );
      if( rs.next() )
        total = rs.getInt( "total" );
      stmt.close();
    } catch( SQLException e )
    {
      System.err.println( "Hey pay attention! the database " );
      System.err.println( "has exploted due to your sloppy query:" + query );
      System.err.flush();
    }
    finally
    {
      return total;
    }
  }


  public static int fetchMinTrackIdsFromFid2attribute( Connection conn )
  {
    ResultSet rs;
    int minId = 0;
    Statement stmt = null;
    String query = "SELECT min( ftypeid ) minimum  FROM ftype2attributeName";

    try
    {
      stmt = conn.createStatement();
      rs = stmt.executeQuery( query );
      if( rs.next() )
        minId = rs.getInt( "minimum" );
      stmt.close();
    } catch( SQLException e )
    {
      System.err.println( "Hey pay attention! the database " );
      System.err.println( "has exploted due to your sloppy query:" + query );
      System.err.flush();
    }
    finally
    {
      return minId;
    }
  }

  public static int fetchMinTrackIdsFromFdatabase( Connection conn )
  {
    int fdata2 = 0;
    int fidText = 0;
    int fatt = 0;
    int min = 10000;

    fdata2 = fetchMinTrackIdsFromFdata2( conn );
    if( fdata2 < min )
      min = fdata2;
    fidText = fetchMinTrackIdsFromFidText( conn );
    if( fidText < min )
      min = fidText;
    fatt = fetchMinTrackIdsFromFid2attribute( conn );
    if( fatt < min )
      min = fatt;

    return min;
  }

  public static String[] fetchTracksFromDatabase( DBAgent db, String databaseName, int genboreeUserId )
  {
    Connection conn = null;
    ResultSet rs;
    StringBuffer qs = new StringBuffer( 200 );
    Hashtable tempFtypeHash = null;
    Statement stmt = null;
    String ftypes[] = null;
    String query = "SELECT distinct(ftypeid) typeid from fdata2";
    int i = 0;
    int counter = 0;
    Enumeration en;
    int size = 0;

    if( databaseName == null ) return null;
    qs.append( "SELECT fmethod, fsource FROM ftype where ftypeid in (" );
    tempFtypeHash = new Hashtable();

    try
    {
      conn = db.getConnection( databaseName );
      stmt = conn.createStatement();
      rs = stmt.executeQuery( query );
      while( rs.next() )
      {
        if( counter > 0 ) qs.append( ", " );
        qs.append( rs.getString( "typeid" ) );
        counter++;
      }
      qs.append( ")" );

      rs = stmt.executeQuery( qs.toString() );

      while( rs.next() )
      {
        String fmethod = rs.getString( 1 );
        String fsource = rs.getString( 2 );
        String ftypeKey = fmethod + ":" + fsource;
        if( TrackPermission.isTrackAllowed( databaseName, fmethod, fsource, genboreeUserId ) )
          tempFtypeHash.put( ftypeKey, ftypeKey );
      }
      size = tempFtypeHash.size();
      ftypes = new String[size];
      i = 0;
      for( en = tempFtypeHash.keys(); en.hasMoreElements(); )
      {
        if( i < size )
          ftypes[ i ] = ( String )en.nextElement();
        i++;
      }
      stmt.close();
    } catch( SQLException e )
    {
      System.err.println( "There has been an exception using databaseName = " + databaseName );
      System.err.println( "and the query is " + qs.toString() );
      System.err.flush();
    }
    finally
    {
      return ftypes;
    }
  }

  public static boolean updateFtypeidInDatabase( Connection databaseConnection, int oldFtypeId, int newFtypeId )
  {
    boolean rc = false;
    String fdata2Query = "UPDATE fdata2 set ftypeid = " + newFtypeId + " WHERE ftypeid = " + oldFtypeId;
    String fidTextQuery = "UPDATE fidText set ftypeid = " + newFtypeId + " WHERE ftypeid = " + oldFtypeId;
    String ftype2attributeQuery = "UPDATE ftype2attributeName set ftypeid = " + newFtypeId + " WHERE ftypeid = " + oldFtypeId;
    try
    {
      Statement stmt = databaseConnection.createStatement();
      stmt.executeUpdate( fdata2Query );
      stmt.executeUpdate( fidTextQuery );
      stmt.executeUpdate( ftype2attributeQuery );
      stmt.close();

      rc = true;
    } catch( Exception ex )
    {
      ex.printStackTrace( System.err );
      System.err.println( "I already told you to pass me an open connection to the database so I can do my job" );
      System.err.flush();
    }

    return rc;
  }

  public static Hashtable fetchTracksFromUploads( DBAgent db, String myRefseqId, String EntryPointId, int genboreeUserId )
  {
    return fetchTracksFromUploads( db, myRefseqId, EntryPointId, false, genboreeUserId );
  }

  public static Hashtable fetchTracksFromUploads( DBAgent db, String myRefseqId, String EntryPointId, boolean allEPs, int genboreeUserId )
  {
    String uploads[] = null;
    Connection conn = null;
    ResultSet rs;
    String qs = null;
    Hashtable htFtype = null;
    Statement stmt = null;
    String fmethod = null;
    String fsource = null;
    String ftypeKey = null;
    String ftype[] = null;
    int i = 0;
    String local_ftypeIds = null;
    boolean trackAllowed = false;

    if( myRefseqId == null )
      return null;

    if( EntryPointId == null && !allEPs )
      return null;

    uploads = GenboreeUpload.returnDatabaseNames( db, myRefseqId );

    if( uploads == null ) return null;

    htFtype = new Hashtable();
    try
    {
      for( int k = 0; k < uploads.length; k++ )
      {
        conn = db.getConnection( uploads[ k ] );
        local_ftypeIds = GenboreeUtils.filterFtypeIdsUsingFdata2( conn, EntryPointId );
        if( local_ftypeIds == null || local_ftypeIds.length() < 1 )
          continue;
        stmt = conn.createStatement();
        System.err.println( "The databaseIs " + uploads[ k ] );
        System.err.println( "SELECT ftypeid, fmethod, fsource FROM ftype WHERE ftypeid IN ( " + local_ftypeIds + " )" );
        rs = stmt.executeQuery( "SELECT ftypeid, fmethod, fsource FROM ftype WHERE ftypeid IN ( " + local_ftypeIds + " )" );
        while( rs.next() )
        {
          fmethod = rs.getString( 1 );
          fsource = rs.getString( 2 );
          ftypeKey = fmethod + ":" + fsource;
          ftype = new String[2];
          ftype[ 0 ] = fmethod;
          ftype[ 1 ] = fsource;
          /* using the static method */
          if( TrackPermission.isTrackAllowed( uploads[ k ], fmethod, fsource, genboreeUserId ) )
            htFtype.put( ftypeKey, ftype );
          /* using the object oriented method
                    TrackPermission myTck = new TrackPermission( uploads[ i ], fmethod, fsource, genboreeUserId  );
                    if(myTck.canUserAccessTrack())
                        htFtype.put( ftypeKey, ftype );
          */
        }
      }
      stmt.close();
    } catch( Exception ex )
    {
      ex.printStackTrace( System.err );
      System.err.println( "Exception GenboreeUpload#fetchTracksFromUploads using databaseName = " + uploads[ i ] );
      System.err.flush();
    }
    finally
    {
      return htFtype;
    }
  }

  // These are poorly implemented. Try to avoid using. Use and add stuff in dbaccess/util/ that's similar to approaches in those files.
  public static DbFtype[] fetchTracksFromRefSeqIdEntryPoint( DBAgent db, String _refSeqId, String _entryPointId, int genboreeUserId )
  {
    return fetchTracksFromRefSeqIdEntryPoint( db, _refSeqId, _entryPointId, false, genboreeUserId );
  }
  public static DbFtype[] fetchTracksFromRefSeqIdEntryPoint( DBAgent db, String _refSeqId, String _entryPointId, boolean allEPs, int genboreeUserId )
  {
    Vector v = null;
    DbFtype[] rc = null;
    String ftype[];
    String fmethod = null;
    String fsource = null;
    int ftypeId = -1;
    String uploads[] = null;
    String[] allUrls = null;
    Connection conn = null;
    ResultSet rs;
    String qs = null;
    Statement stmt = null;
    String local_ftypeIds = null;
    int k = 0;

    if( _refSeqId == null )
      return null;

    if( _entryPointId == null && !allEPs )
      return null;

    uploads = GenboreeUpload.returnDatabaseNames( db, _refSeqId );
    if( uploads == null ) return null;
    v = new Vector();
    try
    {
      for( k = 0; k < uploads.length; k++ )
      {
        conn = db.getConnection( uploads[ k ] );
        local_ftypeIds = GenboreeUtils.fetchListFtypeIds( conn );
        if( local_ftypeIds == null || local_ftypeIds.length() < 1 )
          continue;
        stmt = conn.createStatement();
        rs = stmt.executeQuery( "SELECT ftypeid, fmethod, fsource FROM ftype WHERE ftypeid IN ( " + local_ftypeIds + " )" );
        while( rs.next() )
        {
          ftypeId = rs.getInt( 1 );
          fmethod = rs.getString( 2 );
          fsource = rs.getString( 3 );
          ftype = new String[2];
          ftype[ 0 ] = fmethod;
          ftype[ 1 ] = fsource;
          DbFtype ft = new DbFtype(uploads[k], ftypeId, fmethod, fsource);
          String[] Gclasses = DbGclass.fetchGClasses( db, uploads, fmethod, fsource );
          ft.setBelongToAllThisGclasses( Gclasses );
          ft.setUploadId( fetchUploadIdFromRefSeqIdDbName( db, _refSeqId, uploads[ k ] ) );
          allUrls = getUrlsFromFtype( db, uploads, fmethod, fsource );
          if( allUrls != null )
            ft.setAllUrl( allUrls[ 0 ], allUrls[ 1 ], allUrls[ 2 ] );
          v.addElement( ft );
        }
      }
    }
    catch( Exception ex )
    {
      ex.printStackTrace( System.err );
      System.err.println( "Exception GenboreeUpload#fetchTracksFromRefSeqIdEntryPoint using databaseName = " + uploads[ k ] );
      System.err.flush();
    }


    rc = new DbFtype[v.size()];
    v.copyInto( rc );

    return rc;
  }

}
