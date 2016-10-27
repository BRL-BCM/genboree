package org.genboree.tabular;

import java.util.Vector;
import java.sql.Statement;
import java.sql.ResultSet;
import java.sql.Connection;
import java.sql.SQLException;
import org.genboree.dbaccess.Refseq;
import org.genboree.dbaccess.DbFtype;
import org.genboree.dbaccess.DBAgent;
import org.genboree.dbaccess.TrackPermission;

/**
 * <p>This class performs some of the DB query utility methods needed for the
 * tabular layout display and setup.</p>
 * <p>Created on: August 14th, 2008</p>
 * @author sgdavis@bioneos.com
 */
public class Utility
{
  /**
   * Grab the attributes for the specified {@link DbFtype} array (tracks). This
   * method will query the databases for this information.
   * @param db
   *   The {@link DBAgent} to use in order to obtain database connections.
   * @param tracks
   *   A {@link Vector} of {@link DbFtype} objects representing data tracks.
   *   Take note that the {@link DbFtype} {@link Vector} may contain multiple
   *   objects with the same track name.  This occurs when a user uploads data 
   *   to a database based on a template DB.  The data will therefore exist on 
   *   two different MySQL databases, but represent a single data track.
   * @return
   *   A {@link Vector} of {@link String}s for all of the attributes associated
   *   with the supplied data tracks.  Note: if an error occurred during db
   *   querying, this error is noted in the system error log, but the problem
   *   track (or database) is silently skipped. This method never returns null.
   */
  public static Vector<String> listAttributes(DBAgent db, Vector<DbFtype> tracks)
  {
    // Determine which connection to retreive based on the name specified in
    // the DbFtype class.  This way we can support searching across multiple
    // databases.  In order to reduce overhead of this method, first get the
    // get the list of dbNames, or else we will have to make too many calls
    // to DBAgent.getConnection(dbName) => expensive!
    Vector<String> dbNames = new Vector<String>() ;
    for(DbFtype track : tracks)
      if(track.getDatabaseName() != null && !dbNames.contains(track.getDatabaseName()))
        dbNames.add(track.getDatabaseName()) ;

    Vector<String> attributes = new Vector<String>() ;
    for (String databaseName : dbNames)
    {
      // Grab the connection first
      Connection conn = null ;
      try
      {
        conn = db.getConnection(databaseName) ;
      }
      catch(SQLException e)
      {
      }
      if(conn == null)
      {
        System.err.println("tabular.Utility.listAttributes(): Cannot get db connection for " + databaseName) ;
        continue ;
      }

      // Build a list of track ids (ftypeid's)
      StringBuilder trackIds = new StringBuilder() ;
      for(DbFtype track : tracks)
      {
        // Only query for this data track if it is from this database
        if(!databaseName.equals(track.getDatabaseName())) continue ;
        trackIds.append((trackIds.length() == 0) ? "" : ",").append(track.getFtypeid()) ;
      }

      // Now get the attributes used in these data tracks
      try
      {
        String query = "SELECT DISTINCT n.attNameId, n.name " +
          "FROM attNames n, ftype2attributeName f2a " +
          "WHERE n.attNameId=f2a.attNameId AND f2a.ftypeid IN (" + trackIds + ")" ;
        Statement st = conn.createStatement() ;
        ResultSet rs = st.executeQuery(query) ;
        while(rs.next())
          if (!attributes.contains(rs.getString(2)))
            attributes.add(rs.getString(2)) ;
      }
      catch (SQLException e)
      {
        System.err.println("tabular.Utility.listAttributes(): Cannot query db " + databaseName +
          " for track attributes: " + e) ;
      }
    }

    // All done
    return attributes ;
  }

  /**
   * Count the number of annotations associated with the supplied track names.
   * This method queries the ftypeCount table in the required databases.
   * @param db
   *   The {@link DBAgent} to use in order to obtain database connections.
   * @param tracks
   *   A {@link Vector} of {@link DbFtype} objects representing data tracks.
   *   Take note that the {@link DbFtype} {@link Vector} may contain multiple
   *   objects with the same track name.  This occurs when a user uploads data 
   *   to a database based on a template DB.  The data will therefore exist on 
   *   two different MySQL databases, but represent a single data track.
   * @return
   *   A {@link Vector} of {@link String}s for all of the attributes associated
   */
  public static int getAnnotationCount(DBAgent db, Vector<DbFtype> tracks)
  {
    Vector<String> dbNames = new Vector<String>() ;
    for(DbFtype track : tracks)
      if(track.getDatabaseName() != null && !dbNames.contains(track.getDatabaseName()))
        dbNames.add(track.getDatabaseName()) ;

    int count = 0;
    for (String databaseName : dbNames)
    {
      // Grab the connection first
      Connection conn = null ;
      try
      {
        conn = db.getConnection(databaseName) ;
      }
      catch(SQLException e)
      {
      }
      if(conn == null)
      {
        System.err.println("tabular.Utility.getAnnotationCount(): " +
          "Cannot get db connection for " + databaseName) ;
        continue ;
      }

      // Build a list of track ids (ftypeid's)
      StringBuilder trackIds = new StringBuilder() ;
      for(DbFtype track : tracks)
      {
        // Only query for this data track if it is from this database
        if(!databaseName.equals(track.getDatabaseName())) continue ;
        trackIds.append((trackIds.length() == 0) ? "" : ",").append(track.getFtypeid()) ;
      }

      try
      {
        String query = "SELECT SUM(numberOfAnnotations) FROM ftypeCount " +
          "WHERE ftypeId IN (" + trackIds + ")" ;
        Statement st = conn.createStatement() ;
        ResultSet rs = st.executeQuery(query) ;
        if(rs.next()) count += rs.getInt(1);
      }
      catch (SQLException e)
      {
        System.err.println("tabular.Utility.getAnnotationCount(): Cannot query db " + databaseName +
          " for annotation count: " + e) ;
      }
    }

    // Finished counting
    return count;
  }

  /**
   * A utility method for building a {@link Vector} of {@link DbFtype} objects
   * from a {@link String}[] containing a list of track names.  This method is
   * useful because the Javascript and UI components usually have to represent
   * data tracks using only their names, but the Java objects represented by
   * these names are needed for several other Java methods.
   * @param db
   *   The {@link DBAgent} to use in order to obtain database connections.
   * @param userId
   *   The internal database id representing the current Genboree user.
   * @param database
   *   The currently selected {@link Refseq} database.  This will affect what
   *   {@link DbFtype} objects are built because of the way that data tracks
   *   can be spread across a template and user database.
   * @param trackNames
   *   The {@link String}[] of track names.
   * @return
   *   A {@link Vector} of {@link DbFtype} objects representing data tracks.
   *   Take note that the {@link DbFtype} {@link Vector} may contain multiple
   *   objects with the same track name.  This occurs when a user uploads data 
   *   to a database based on a template DB.  The data will therefore exist on 
   *   two different MySQL databases, but represent a single data track.
   */
  public static Vector<DbFtype> getTracksFromNames(DBAgent db, int userId, Refseq database, String[] trackNames)
  {
    Vector<DbFtype> tracks = new Vector<DbFtype>() ;

    // Get all database names
    String[] dbNames = new String[0];
    try
    {
      dbNames = database.fetchDatabaseNames(db) ;
    }
    catch (SQLException e)
    {
      System.err.println("tabular.Utility.getTracksFromNames(): Error fetching database names: " + e) ;
      return tracks ;
    }

    for(String dbName : dbNames)
    {
      Connection conn = null ;
      try
      {
        conn = db.getConnection(dbName) ;
      }
      catch (SQLException e)
      {
      }
      // Return an empty Vector on error
      if(conn == null) 
      {
        System.err.println("tabular.Utility.getTracksFromNames(): Could not get connection to db - " + dbName) ;
        continue;
      }

      // Get all DbFtypes to compare to the requested names
      DbFtype[] dbftypes = DbFtype.fetchAll(conn, dbName, userId) ;
      for(DbFtype track : dbftypes)
      {
        if(!TrackPermission.isTrackAllowed(dbName, track.getFmethod(), track.getFsource(), userId))
          continue ;
          
        for (String trackName : trackNames)
          if(track.getTrackName().equals(trackName))
            tracks.add(track) ;
      }
    }

    // All done
    return tracks ;
  }
}
