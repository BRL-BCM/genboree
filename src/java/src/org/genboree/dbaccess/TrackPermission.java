package org.genboree.dbaccess;

import org.genboree.util.GenboreeUtils;
import org.genboree.util.Constants;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

public class TrackPermission
{
  protected String fmethod = null;
  protected String fsource = null;
  protected int genboreeUserId = -1;
  protected String databaseName = null;
  protected int ftypeId = -1;
  protected DBAgent db = null;
  protected Connection databaseConnection = null;
  protected boolean userHasPermission = false;
  protected boolean databaseHasAccessControl = false;
  protected boolean trackHasAccessControl = false;




  public TrackPermission( String databaseName, String fmethod, String fsource, int genboreeUserId  )
  {
    this.databaseName = databaseName;
    this.fmethod = fmethod;
    this.fsource = fsource;
    this.genboreeUserId = genboreeUserId;
    try
    {
      this.db = DBAgent.getInstance();
      ftypeId = GenboreeUtils.fetchFtypeId( db, databaseName, fmethod, fsource );
      this.databaseConnection = db.getConnection( databaseName );
      //System.out.println("The initial Values with " + fmethod + ":"  + fsource +  " are databasehasAccess = " + databaseHasAccessControl  + " the trackHasPermission " + trackHasAccessControl + " userHasPermission " + userHasPermission);

      isTrackAllowed( );

     // System.out.println("The final Values with " + fmethod + ":"  + fsource +  " are databasehasAccess = " + databaseHasAccessControl  + " the trackHasPermission " + trackHasAccessControl + " userHasPermission " + userHasPermission);


    } catch( SQLException e )
    {
      System.err.println( "There has been an exception using databaseName = " + databaseName );
      System.err.println( "during initialization of TrackPermission Class");
      System.err.flush();
    }
  }

  public TrackPermission( String databaseName, int ftypeId, int genboreeUserId  )
  {
    this.databaseName = databaseName;
    this.ftypeId = ftypeId;
    this.genboreeUserId = genboreeUserId;
    try
    {
      this.db = DBAgent.getInstance();
      this.databaseConnection = db.getConnection( databaseName );
      isTrackAllowed( );
    } catch( SQLException e )
    {
      System.err.println( "There has been an exception using databaseName = " + databaseName );
      System.err.println( "during initialization of TrackPermission Class");
      System.err.flush();
    }
  }

   public TrackPermission( int fId, String databaseName,  int genboreeUserId  )
  {
    this.databaseName = databaseName;

    this.genboreeUserId = genboreeUserId;
    try
    {
      this.db = DBAgent.getInstance();
      this.databaseConnection = db.getConnection( databaseName );
      this.ftypeId = getTypeIdFromFid(fId);
      isTrackAllowed( );
    } catch( SQLException e )
    {
      System.err.println( "There has been an exception using databaseName = " + databaseName );
      System.err.println( "during initialization of TrackPermission Class");
      System.err.flush();
    }
  }

  protected int getTypeIdFromFid(int fId)
  {
    ResultSet rs = null;
    PreparedStatement pstmt = null;
    String query = "select ftypeid from fdata2 where fid = ?";
    int typeId = 0;

    try
    {
      if( fId < 1 )
        return -1 ;


      pstmt = databaseConnection.prepareStatement( query );

      pstmt.setInt( 1, fId );
      rs = pstmt.executeQuery();

      if( rs.next() )
        typeId = rs.getInt( "ftypeid" );

      rs.close();
      pstmt.close();

    } catch( SQLException e )
    {
      System.err.println( "There has been an exception using databaseName = " + databaseName );
      System.err.println( "and the query is " + query + " on TrackPermission::hasTrackAccessControl");
      System.err.flush();
    }
    finally
    {
      return typeId ;
    }
  }


  public boolean canUserAccessTrack()
  {
    return userHasPermission;
  }

  protected boolean hasDbAccessControl( )
  {
    ResultSet rs = null;
    Statement stmt = null;
    String query = "SELECT count(*) total FROM ftypeAccess";
    int numberOfRecords = 0;

    try
    {
      stmt = databaseConnection.createStatement();
      rs = stmt.executeQuery( query );
      if( rs.next() )
        numberOfRecords = rs.getInt( "total" );

      if( numberOfRecords > 0 )
        databaseHasAccessControl = true;

      rs.close();
      stmt.close();

    } catch( SQLException e )
    {
      System.err.println( "There has been an exception using databaseName = " + databaseName );
      System.err.println( "and the query is " + query + " on TrackPermission::hasDbAccessControl");
      System.err.flush();
    }
    finally
    {
      return databaseHasAccessControl ;
    }

  }

  public boolean hasTrackAccessControl(  )
  {
    ResultSet rs = null;
    PreparedStatement pstmt = null;
    String query = "SELECT count(*) total FROM ftypeAccess where FTYPEID = ?";
    int numberOfRecords = 0;

    try
    {
      if( ftypeId < 1 )
      {
        trackHasAccessControl = false;
        return trackHasAccessControl ;
      }

      pstmt = databaseConnection.prepareStatement( query );

      pstmt.setInt( 1, ftypeId );
      rs = pstmt.executeQuery();

      if( rs.next() )
        numberOfRecords = rs.getInt( "total" );

      if( numberOfRecords > 0 )
        trackHasAccessControl = true;

      rs.close();
      pstmt.close();

    } catch( SQLException e )
    {
      System.err.println( "There has been an exception using databaseName = " + databaseName );
      System.err.println( "and the query is " + query + " on TrackPermission::hasTrackAccessControl");
      System.err.flush();
    }
    finally
    {
      return trackHasAccessControl ;
    }

  }

  public boolean hasUserAccessToTrack( )
  {
    ResultSet rs = null;
    PreparedStatement pstmt = null;
    String query = "SELECT permissionBits FROM ftypeAccess WHERE userId = ? AND FTYPEID = ?";
    int permissionBits = 0;


    try
    {
      if( ftypeId < 1 )
      {
        userHasPermission = false;
        return userHasPermission;
      }

      pstmt = databaseConnection.prepareStatement( query );
      pstmt.setInt( 1, genboreeUserId );
      pstmt.setInt( 2, ftypeId );
      rs = pstmt.executeQuery();
      if( rs.next() ) permissionBits = rs.getInt( 1 );

      if( ( permissionBits & Constants.TRACK_PERMISSION ) > 0 )
        userHasPermission = true;

      rs.close();
      pstmt.close();


    } catch( SQLException e )
    {
      System.err.println( "There has been an exception using databaseName = " + databaseName );
      System.err.println( "and the query is: SELECT permissionBits FROM ftypeAccess WHERE userId =  " +
              genboreeUserId + " AND FTYPEID = " + ftypeId + "; on TrackPermission::hasUserAccessToTrack" );
      System.err.flush();
    }
    finally
    {
      return userHasPermission ;
    }

  }

  public boolean isTrackAllowed( )
  {

    if( !hasDbAccessControl(  ) )
      {
        userHasPermission = true;
        return userHasPermission;
      }

    if(!hasTrackAccessControl(  ))
      {
        userHasPermission = true;
        return userHasPermission;
      }

    if(hasUserAccessToTrack( ))
      {
        userHasPermission = true;
        return userHasPermission;
      }

    return false;

  }


  public static boolean hasDbAccessControl( String databaseName )
  {
    return hasDbAccessControl( databaseName, true );
  }

  public static boolean hasDbAccessControl( String databaseName, boolean doCache )
  {
    DBAgent db = null;
    Connection databaseConnection = null;
    ResultSet rs = null;
    Statement stmt = null;
    String query = "SELECT count(*) total FROM ftypeAccess";
    int numberOfRecords = 0;
    boolean hasDBAccess = false;

    try
    {
      db = DBAgent.getInstance();
      if(doCache)
          databaseConnection = db.getConnection(databaseName );
      else
          databaseConnection = db.getNoCacheConnection(databaseName);

      stmt = databaseConnection.createStatement();
      rs = stmt.executeQuery( query );
      if( rs.next() )
        numberOfRecords = rs.getInt( "total" );

      if( numberOfRecords > 0 )
        hasDBAccess = true;

    } catch( SQLException e )
    {
      System.err.println( "There has been an exception using databaseName = " + databaseName );
      System.err.println( "and the query is " + query + " on TrackPermission::hasDbAccessControl");
      System.err.flush();
    }
    finally
    {
      db.safelyCleanup(rs, stmt, databaseConnection);
      return hasDBAccess;
    }

  }


  public static boolean hasTrackAccessControl( String databaseName, String fmethod, String fsource  )
  {
    return hasTrackAccessControl( databaseName, fmethod, fsource, true  );
  }


  public static boolean hasTrackAccessControl( String databaseName, String fmethod, String fsource, boolean doCache )
  {
    DBAgent db = null;
    Connection databaseConnection = null;
    ResultSet rs = null;
    PreparedStatement pstmt = null;
    String query = "SELECT count(*) total FROM ftypeAccess where FTYPEID = ?";
    int numberOfRecords = 0;
    boolean hasTrackAccessControl = false;
    int ftypeId = -1;

    try
    {
      db = DBAgent.getInstance();
      ftypeId = GenboreeUtils.fetchFtypeId( db, databaseName, fmethod, fsource, doCache);
      if( ftypeId < 1 ) return hasTrackAccessControl ;

      if(doCache)
          databaseConnection = db.getConnection(databaseName );
      else
          databaseConnection = db.getNoCacheConnection(databaseName);

      pstmt = databaseConnection.prepareStatement( query );

      pstmt.setInt( 1, ftypeId );
      rs = pstmt.executeQuery();


      if( rs.next() )
        numberOfRecords = rs.getInt( "total" );

      if( numberOfRecords > 0 )
        hasTrackAccessControl = true;

    } catch( SQLException e )
    {
      System.err.println( "There has been an exception using databaseName = " + databaseName );
      System.err.println( "and the query is " + query + " on TrackPermission::hasTrackAccessControl");
      System.err.flush();
    }
    finally
    {
      db.safelyCleanup(rs, pstmt, databaseConnection);
      return hasTrackAccessControl;
    }

  }

    public static boolean hasTrackAccessControl( String databaseName, int ftypeId  )
  {
    return hasTrackAccessControl( databaseName, ftypeId, true  );
  }

  public static boolean hasTrackAccessControl( String databaseName, int ftypeId, boolean doCache  )
  {
    DBAgent db = null;
    Connection databaseConnection = null;
    ResultSet rs = null;
    PreparedStatement pstmt = null;
    String query = "SELECT count(*) total FROM ftypeAccess where FTYPEID = ?";
    int numberOfRecords = 0;
    boolean hasTrackAccessControl = false;


    try
    {
      db = DBAgent.getInstance();

      if( ftypeId < 1 ) return hasTrackAccessControl ;

      if(doCache)
          databaseConnection = db.getConnection(databaseName );
      else
          databaseConnection = db.getNoCacheConnection(databaseName);

      pstmt = databaseConnection.prepareStatement( query );

      pstmt.setInt( 1, ftypeId );
      rs = pstmt.executeQuery();


      if( rs.next() )
        numberOfRecords = rs.getInt( "total" );

      if( numberOfRecords > 0 )
        hasTrackAccessControl = true;

    } catch( SQLException e )
    {
      System.err.println( "There has been an exception using databaseName = " + databaseName );
      System.err.println( "and the query is " + query + " on TrackPermission::hasTrackAccessControl");
      System.err.flush();
    }
    finally
    {
      db.safelyCleanup(rs, pstmt, databaseConnection);
      return hasTrackAccessControl;
    }

  }

  public static int getTypeIdFromFid(int fId, String databaseName)
  {
    return getTypeIdFromFid(fId, databaseName, true);
  }

  public static int getTypeIdFromFid(int fId, String databaseName, boolean doCache )
  {
    DBAgent db = null;
    Connection databaseConnection = null;
    ResultSet rs = null;
    PreparedStatement pstmt = null;
    String query = "select ftypeid from fdata2 where fid = ?";
    int typeId = 0;

    try
    {
      if( fId < 1 )
        return -1 ;

      db = DBAgent.getInstance();
      if(doCache)
          databaseConnection = db.getConnection(databaseName );
      else
          databaseConnection = db.getNoCacheConnection(databaseName);

      pstmt = databaseConnection.prepareStatement( query );

      pstmt.setInt( 1, fId );
      rs = pstmt.executeQuery();

      if( rs.next() )
        typeId = rs.getInt( "ftypeid" );

      db.safelyCleanup( rs, pstmt, databaseConnection );

    } catch( SQLException e )
    {
      System.err.println( "There has been an exception using databaseName = " + databaseName );
      System.err.println( "and the query is " + query + " on TrackPermission::getTypeIdFromFid");
      System.err.flush();
    }
    finally
    {
      return typeId ;
    }
  }

    public static int getTypeIdFromFid(int fId, Connection databaseConnection)
  {
    ResultSet rs = null;
    PreparedStatement pstmt = null;
    String query = "select ftypeid from fdata2 where fid = ?";
    int typeId = 0;

    try
    {
      if( fId < 1 )
        return -1 ;

      pstmt = databaseConnection.prepareStatement( query );

      pstmt.setInt( 1, fId );
      rs = pstmt.executeQuery();

      if( rs.next() )
        typeId = rs.getInt( "ftypeid" );

      rs.close();
      pstmt.close();

    } catch( SQLException e )
    {
      System.err.println( "There has been an exception using connection ");
      System.err.println( "the query is " + query + " on TrackPermission::getTypeIdFromFid");
      System.err.flush();
    }
    finally
    {
      return typeId ;
    }
  }

  public static boolean hasUserAccessToTrack( String databaseName, String fmethod, String fsource, int genboreeUserId )
  {
    return hasUserAccessToTrack( databaseName, fmethod, fsource, genboreeUserId, true );
  }

  public static boolean hasUserAccessToTrack( String databaseName, String fmethod, String fsource, int genboreeUserId, boolean doCache )
  {
    DBAgent db = null;
    Connection databaseConnection = null;
    ResultSet rs = null;
    PreparedStatement pstmt = null;
    String query = "SELECT permissionBits FROM ftypeAccess WHERE userId = ? AND FTYPEID = ?";
    boolean hasUserAccess = false;
    int permissionBits = 0;
    int ftypeId = -1;


    try
    {
      db = DBAgent.getInstance();

      ftypeId = GenboreeUtils.fetchFtypeId( db, databaseName, fmethod, fsource, doCache );
      if( ftypeId < 1 ) return true;

     if(doCache)
          databaseConnection = db.getConnection(databaseName );
      else
          databaseConnection = db.getNoCacheConnection(databaseName);
      
      pstmt = databaseConnection.prepareStatement( query );
      pstmt.setInt( 1, genboreeUserId );
      pstmt.setInt( 2, ftypeId );
      rs = pstmt.executeQuery();
      if( rs.next() ) permissionBits = rs.getInt( 1 );

      if( ( permissionBits & Constants.TRACK_PERMISSION ) > 0 )
        hasUserAccess = true;



    } catch( SQLException e )
    {
      System.err.println( "There has been an exception using databaseName = " + databaseName );
      System.err.println( "and the query is: SELECT permissionBits FROM ftypeAccess WHERE userId =  " +
              genboreeUserId + " AND FTYPEID = " + ftypeId + "; on TrackPermission::hasUserAccessToTrack" );
      System.err.flush();
    }
    finally
    {
      db.safelyCleanup( rs, pstmt, databaseConnection );
      return hasUserAccess;
    }

  }

  public static boolean hasUserAccessToTrack( String databaseName, int ftypeId, int genboreeUserId )
  {
    return hasUserAccessToTrack( databaseName, ftypeId, genboreeUserId, true );
  }

  public static boolean hasUserAccessToTrack( String databaseName, int ftypeId, int genboreeUserId, boolean doCache )
  {
    DBAgent db = null;
    Connection databaseConnection = null;
    ResultSet rs = null;
    PreparedStatement pstmt = null;
    String query = "SELECT permissionBits FROM ftypeAccess WHERE userId = ? AND FTYPEID = ?";
    boolean hasUserAccess = false;
    int permissionBits = 0;


    try
    {
      db = DBAgent.getInstance();

      if( ftypeId < 1 ) return true;

      if(doCache)
          databaseConnection = db.getConnection(databaseName );
      else
          databaseConnection = db.getNoCacheConnection(databaseName);

      pstmt = databaseConnection.prepareStatement( query );
      pstmt.setInt( 1, genboreeUserId );
      pstmt.setInt( 2, ftypeId );
      rs = pstmt.executeQuery();
      if( rs.next() ) permissionBits = rs.getInt( 1 );

      if( ( permissionBits & Constants.TRACK_PERMISSION ) > 0 )
        hasUserAccess = true;



    } catch( SQLException e )
    {
      System.err.println( "There has been an exception using databaseName = " + databaseName );
      System.err.println( "and the query is: SELECT permissionBits FROM ftypeAccess WHERE userId =  " +
              genboreeUserId + " AND FTYPEID = " + ftypeId + "; on TrackPermission::hasUserAccessToTrack" );
      System.err.flush();
    }
    finally
    {
      db.safelyCleanup( rs, pstmt, databaseConnection );
      return hasUserAccess;
    }

  }


  public static boolean isTrackAllowed( String databaseName, int ftypeId, int genboreeUserId )
  {
    return isTrackAllowed( databaseName, ftypeId, genboreeUserId , true);
  }

   public static boolean isTrackAllowed( String databaseName, int ftypeId, int genboreeUserId, boolean doCache )
  {

    if( !hasDbAccessControl( databaseName, doCache  ) )
      return true;

    if(!hasTrackAccessControl( databaseName, ftypeId, doCache   ))
       return true;

    if(hasUserAccessToTrack( databaseName, ftypeId, genboreeUserId, doCache ))
      return true;

    return false;

  }

  public static boolean isTrackAllowed( String databaseName, String fmethod, String fsource, int genboreeUserId )
  {
    return isTrackAllowed( databaseName, fmethod, fsource, genboreeUserId, true);
  }

  public static boolean isTrackAllowed( String databaseName, String fmethod, String fsource, int genboreeUserId, boolean doCache )
  {

    if( !hasDbAccessControl( databaseName, doCache ) )
      return true;

    if(!hasTrackAccessControl( databaseName, fmethod, fsource, doCache ))
       return true;

    if(hasUserAccessToTrack( databaseName, fmethod, fsource, genboreeUserId, doCache ))
      return true;

    return false;

  }

   public static boolean isTrackAllowed( int fId, String databaseName,  int genboreeUserId)
  {
    return isTrackAllowed( fId, databaseName,  genboreeUserId, true);
  }

  public static boolean isTrackAllowed( int fId, String databaseName,  int genboreeUserId, boolean doCache )
  {
    int ftypeId = getTypeIdFromFid(fId, databaseName, doCache);

    if( !hasDbAccessControl( databaseName, doCache ) )
      return true;

    if(!hasTrackAccessControl( databaseName, ftypeId, doCache  ))
       return true;

    if(hasUserAccessToTrack( databaseName, ftypeId, genboreeUserId, doCache ))
      return true;

    return false;

  }



}
