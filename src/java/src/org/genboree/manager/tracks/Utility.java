package org.genboree.manager.tracks;

import javax.servlet.jsp.JspWriter;
import java.security.MessageDigest;
import java.sql.*;
import java.util.*;
import org.genboree.util.* ;
import org.genboree.dbaccess.* ;
import org.genboree.editor.Chromosome ;


/**
 * User: tong Date: Jul 11, 2005 Time: 2:33:07 PM
 */
public class Utility
{
  public static boolean checkDuplicate( String lnkMD5, Connection con )
  {
    if( lnkMD5 == null || con == null )
      return true;

    boolean isDup = false;
    try
    {
      String qs = "select linkId from link where linkId = '" + lnkMD5 + "'";
      PreparedStatement pstmt = con.prepareStatement( qs );
      ResultSet rs = pstmt.executeQuery();
      while( rs.next() )
      {
        isDup = true;
      }
      if( rs != null )
        rs.close();
      pstmt.close();

    } catch( Exception ex )
    {
      ex.printStackTrace();
    }

    return isDup;
  }


  public static HashMap retrieveChromosomeMap( Connection con )
  {

    HashMap map = new HashMap();
    String sql = "SELECT  rid, refname, rlength  from fref ";
    try
    {
      PreparedStatement stms = con.prepareStatement( sql );
      ResultSet rs = stms.executeQuery();
      while( rs.next() )
      {
        Chromosome chromosome = new Chromosome( rs.getString( 2 ) );
        chromosome.setId( rs.getInt( 1 ) );
        chromosome.setLength( rs.getLong( 3 ) );
        map.put( rs.getString( 2 ), chromosome );
      }
      rs.close();
      stms.close();
    }
    catch( Exception e )
    {
      e.printStackTrace();
    }
    return map;
  }


  public static HashMap retrivesTrack2Ftype( Connection con, String dbName, int genboreeUserId )
  {
    HashMap trackName2ftype = new HashMap();
    String sql = "select ftypeid,  fmethod, fsource from ftype";
    try
    {
      Connection tempConnection = null;
      PreparedStatement stms = null;
      ResultSet rs = null;
      DbFtype ftype = null;
      stms = con.prepareStatement( sql );
      rs = stms.executeQuery();
      while( rs.next() )
      {
        int ftypeId = rs.getInt( 1 );
        String fmethod = rs.getString( 2 );
        String fsource = rs.getString( 3 );
        ftype = new DbFtype(dbName, ftypeId, fmethod, fsource);
        if( TrackPermission.isTrackAllowed( dbName, fmethod, fsource, genboreeUserId ) )
        {
          trackName2ftype.put( fmethod + ":" + fsource, ftype );
        }
      }
      rs.close();
      stms.close();
    }
    catch( SQLException e )
    {
      e.printStackTrace();
    }
    return trackName2ftype;
  }

  public static boolean existData( String dbName, String tableName, String columnName, String value )
  {
    boolean b = false;
    String sql = "select * from " + tableName + " where " + columnName + " = ? ";
    String s = null;
    Connection con = null;
    String sqlupdate = "update fdata2 " +
            " set ftypeid=? where fid = ? ";
    String updateFidTex = "update fidText set ftypeid= ? where fid = ? ";
    try
    {
      con = DBAgent.getInstance().getConnection( dbName );
      if( con != null || !con.isClosed() )
      {
        PreparedStatement stms = con.prepareStatement( sql );
        stms.setString( 1, value );
        ResultSet rs = stms.executeQuery();
        if( rs.next() )
        {
          b = true;
        }
        rs.close();
        stms.close();
        // con.close();
      }
    } catch( SQLException e )
    {
      e.printStackTrace( System.err );
    }
    return b;
  }


  public static boolean existClassName( String dbName, String gname, int ftypeid )
  {
    boolean b = false;
    String sql = "select * from  fdata2 where gname = ?  and ftypeid = ? ";
    String s = null;
    Connection con = null;
    try
    {
      con = DBAgent.getInstance().getConnection( dbName );
      if( con != null || !con.isClosed() )
      {
        PreparedStatement stms = con.prepareStatement( sql );
        stms.setString( 1, gname );
        stms.setInt( 2, ftypeid );
        ResultSet rs = stms.executeQuery();
        if( rs.next() )
        {
          b = true;
        }
        rs.close();
        stms.close();
        //  con.close();
      }
    } catch( SQLException e )
    {
      e.printStackTrace( System.err );
    }
    return b;
  }


  public static boolean existClassName( String dbName, String gname, int ftypeid, int rid )
  {
    boolean b = false;
    String sql = "select * from  fdata2 where gname = ?  and ftypeid = ? and rid = ? ";
    String s = null;
    Connection con = null;
    try
    {
      con = DBAgent.getInstance().getConnection( dbName );
      if( con != null || !con.isClosed() )
      {
        PreparedStatement stms = con.prepareStatement( sql );
        stms.setString( 1, gname );
        stms.setInt( 2, ftypeid );
        stms.setInt( 3, rid );
        ResultSet rs = stms.executeQuery();
        if( rs.next() )
        {
          b = true;
        }
        rs.close();
        stms.close();
        //  con.close();
      }
    } catch( SQLException e )
    {
      e.printStackTrace( System.err );
    }
    return b;
  }


  public static void createTable( Connection conn, String createStmt )
  {
    try
    {
      Statement stmt = conn.createStatement();
      stmt.executeUpdate( createStmt );
      stmt.close();
    } catch( Exception ex )
    {
    }
  }

  /**
   * @param tracks DbFtype []
   * @return Hashmap that could be empty
   * @throws Exception if connection is null or is closed.
   */
  public static Hashtable populateTrack2Classes( DbFtype[] tracks, Connection con, JspWriter out ) throws Exception
  {
    Hashtable tk2g = new Hashtable();
    if( tracks == null )
      return tk2g;
    for( int i = 0; i < tracks.length; i++ )
    {
      DbFtype ft = tracks[ i ];
      Vector vclasses = findGclasses( con, ft, out );
      if( vclasses != null && !vclasses.isEmpty() )
        tk2g.put( ft.toString().trim(), vclasses );
    }
    return tk2g;
  }


  public static Vector findGclasses( Connection con, DbFtype ft, JspWriter out )
  {
    Vector vclassNames = new Vector();
    if( ft == null || ft.getFmethod() == null || ft.getFsource() == null )
      return vclassNames;
    String sql = "select distinct g.gclass from gclass g, ftype2gclass fg , ftype ft "
            + "  where ft.fmethod = ? and ft.fsource = ? and  fg.ftypeid = ft.ftypeid  and fg.gid = g.gid";
    try
    {

      if( con != null && !con.isClosed() )
      {
        PreparedStatement stms = con.prepareStatement( sql );
        stms.setString( 1, ft.getFmethod() );
        stms.setString( 2, ft.getFsource() );
        ResultSet rs = stms.executeQuery();
        while( rs.next() )
        {
          vclassNames.add( rs.getString( 1 ) );
        }
        rs.close();
        stms.close();
      }

    } catch( Exception ex )
    {
      System.err.println( sql );
      ex.printStackTrace();
    }
    return vclassNames;
  }

  public static int findFtypeId( DBAgent db, String dbName, String fmethod, String fsource )
  {
    String sql = null;
    int fid = 0;
    if( fmethod != null && fsource != null )
      try
      {
        Connection con = db.getConnection( dbName );
        if( con != null && !con.isClosed() )
        {
          PreparedStatement stms =
                  con.prepareStatement( "select distinct ftypeid from ftype where fmethod= '" +
                          fmethod + "' and fsource = '" + fsource + "' " );

          ResultSet rs = stms.executeQuery();
          if( rs.next() )
            fid = rs.getInt( 1 );
          rs.close();
          stms.close();
          con.close();
        }
      } catch( Exception ex )
      {
        System.err.println( sql );
        ex.printStackTrace();
      }
    return fid;
  }


  public static int getGid( Connection conn, String gclass )
  {
    String sql = null;
    int gid = 0;
    if( gclass != null )
      try
      {
        if( conn == null || conn.isClosed() )
        {

          return -1;
        }
        PreparedStatement stms =
                conn.prepareStatement( "select distinct gid from gclass where gclass = '"
                        + gclass + "'" );
        ResultSet rs = stms.executeQuery();
        if( rs.next() )
          gid = rs.getInt( 1 );

        if( gid <= 0 )
          return -1;
        rs.close();
        stms.close();
      } catch( Exception ex )
      {
        System.err.println( sql );
        ex.printStackTrace();
      }
    return gid;
  }


  public static String generateMD5( String stringWithInfo )
  {
    return Util.generateMD5(stringWithInfo) ;
  }

  /**
   * @param dbName
   * @param trackIDFeature
   * @return int [] of ids; null if none found
   */

  public static int[] findTrackIds( String dbName, Hashtable trackIDFeature )
  {
    java.util.Enumeration e = trackIDFeature.elements();
    String[] feature = null;
    String fmethod = null;
    String fsource = null;
    int[] ftypeIds = null;
    Vector v = new Vector();
    int id = 0;

    while( e.hasMoreElements() )
    {
      feature = ( String[] )e.nextElement();
      fmethod = feature[ 0 ];
      fsource = feature[ 1 ];
      HashMap h = new HashMap();
      h.put( "fmethod", fmethod );
      h.put( "fsource", fsource );
      try
      {
        id = IDFinder.findId( dbName, "ftype", "ftypeId", h );
      } catch( IDUnfoundException e1 )
      {
        continue;
      }

      if( id > 0 )
        v.add( new Integer( id ) );
    }

    int[] ids = null;
    if( !v.isEmpty() )
    {
      ids = new int[v.size()];
      for( int i = 0; i < v.size(); i++ )
        ids[ i ] = ( ( Integer )v.get( i ) ).intValue();
    }

    return ids;
  }

  /**
   * retrieve ftypeid 2 fmethod:fsouce array Hashmap
   *
   * @param con
   * @return HashMap; could be empty if nothinhg
   */
  public static HashMap retrieveFtypeid2ftype( Connection con, String databaseName, int genboreeUserId )
  {
    HashMap map = new HashMap();
    String sql = "SELECT ftypeid, fmethod, fsource from ftype";
    try
    {
      PreparedStatement stms = con.prepareStatement( sql );
      ResultSet rs = stms.executeQuery();
      while( rs.next() )
      {
        int ftypeId = rs.getInt( 1 );
        String fmethod = rs.getString( 2 );
        String fsource = rs.getString( 3 );
        if( TrackPermission.isTrackAllowed( databaseName, fmethod, fsource, genboreeUserId ) )
        {
          String[] arr = new String[]{ rs.getString( 2 ), rs.getString( 3 ) };
          map.put( rs.getString( 1 ), arr );
        }
      }
      rs.close();
      stms.close();
    }
    catch( SQLException e )
    {
      e.printStackTrace();
    }
    return map;
  }

  public static HashMap retrieveFtype2ftypeId( Connection con, String databaseName, int genboreeUserId )
  {
    HashMap map = new HashMap();
    String sql = "SELECT ftypeid, fmethod, fsource from ftype";
    try
    {
      PreparedStatement stms = con.prepareStatement( sql );
      ResultSet rs = stms.executeQuery();
      while( rs.next() )
      {
        String ftypeIdString = rs.getString( 1 );
        String fmethod = rs.getString( 2 );
        String fsource = rs.getString( 3 );

        if( TrackPermission.isTrackAllowed( databaseName, fmethod, fsource, genboreeUserId ) )
        {
          map.put( fmethod + ":" + fsource, ftypeIdString );
        }

      }
      rs.close();
      stms.close();
    }
    catch( SQLException e )
    {
      e.printStackTrace();
    }
    return map;
  }

  /**
   * retrieve ftypeid 2 fmethod:fsouce array Hashmap
   *
   * @param con
   * @return HashMap; could be empty if nothinhg
   */
  public static String[] retrieveTrackNames( Connection con, String databaseName, int genboreeUserId )
  {
    ArrayList list = new ArrayList();
    String sql = "SELECT fmethod, fsource from ftype";
    try
    {
      PreparedStatement stms = con.prepareStatement( sql );
      ResultSet rs = stms.executeQuery();
      while( rs.next() )
      {
        String fmethod = rs.getString( 1 );
        String fsource = rs.getString( 2 );

        if( rs.getString( 1 ).startsWith( "Component" ) && rs.getString( 2 ).startsWith( "Chromosome" ) )
          continue;
        if( rs.getString( 1 ).startsWith( "Supercomponent" ) && rs.getString( 2 ).startsWith( "Sequence" ) )
          continue;

        if( TrackPermission.isTrackAllowed( databaseName, fmethod, fsource, genboreeUserId ) )
        {
          list.add( rs.getString( 1 ) + ":" + rs.getString( 2 ) );
        }


      }
      rs.close();
      stms.close();
    }
    catch( SQLException e )
    {
      e.printStackTrace();
    }

    if( list.isEmpty() )
      return null;

    String[] tracks = ( String[] )list.toArray( new String[list.size()] );
    if( tracks.length > 0 )
      Arrays.sort( tracks );
    return tracks;
  }

  /**
   * retrieves ftypeid to gclass name from database
   *
   * @param con
   * @param ftypeids
   * @return HashMap; could be empty if nothinhg
   */

  public static HashMap retrieveFtype2Gclass( Connection con, int[] ftypeids )
  {
    HashMap map = new HashMap();
    if( ftypeids == null || ftypeids.length < 1 )
      return map;
    String fidString = "";
    for( int i = 0; i < ftypeids.length - 1; i++ )
      fidString = fidString + "'" + ftypeids[ i ] + "', ";
    fidString = fidString + "'" + ftypeids[ ftypeids.length - 1 ] + "'";

    String sql = "SELECT fg.ftypeid, g.gclass from gclass g, ftype2gclass fg  WHERE fg.ftypeid in (" + fidString + ")  and fg.gid = g.gid";
    try
    {

      System.err.println( "" + sql );
      PreparedStatement stms = con.prepareStatement( sql );
      ResultSet rs = stms.executeQuery();
      while( rs.next() )
        map.put( rs.getString( 1 ), rs.getString( 2 ) );
      rs.close();
      stms.close();
    }
    catch( SQLException e )
    {
      e.printStackTrace();
    }
    return map;
  }

  /**
   * retrieves rid to chromosome name from database
   *
   * @param con
   * @param rids
   * @return HashMap; could be empty if nothinhg
   */
  public static HashMap retrieveRid2Chromosome( Connection con, String[] rids )
  {
    HashMap map = new HashMap();
    if( rids == null || rids.length < 1 )
      return map;

    String ridString = "";
    for( int i = 0; i < rids.length - 1; i++ )
      ridString = ridString + "'" + rids[ i ] + "', ";

    ridString = ridString + "'" + rids[ rids.length - 1 ] + "'";
    String sql = "SELECT distinct rid, refname  from fref  WHERE rid in (" + ridString + ")";
    try
    {
      PreparedStatement stms = con.prepareStatement( sql );
      ResultSet rs = stms.executeQuery();
      while( rs.next() )
        map.put( rs.getString( 1 ), rs.getString( 2 ) );
      rs.close();
      stms.close();
    }
    catch( SQLException e )
    {
      e.printStackTrace();
    }
    return map;
  }

  public static HashMap retrieveRid2Chromosome( Connection con )
  {
    HashMap map = new HashMap();
    String sql = "SELECT rid, refname  from fref  ";
    try
    {
      PreparedStatement stms = con.prepareStatement( sql );
      ResultSet rs = stms.executeQuery();
      while( rs.next() )
        map.put( rs.getString( 1 ), rs.getString( 2 ) );
      rs.close();
      stms.close();
    }
    catch( SQLException e )
    {
      e.printStackTrace();
    }
    return map;
  }


  public static HashMap retrievesChromosome2id( Connection con )
  {

    HashMap chromosomeName2id = new HashMap();
    String sql = "SELECT rid, refname  from fref ";
    try
    {
      PreparedStatement stms = con.prepareStatement( sql );
      ResultSet rs = stms.executeQuery();
      while( rs.next() )
      {
        chromosomeName2id.put( rs.getString( 2 ), rs.getString( 1 ) );
      }
    }
    catch( SQLException e )
    {
      e.printStackTrace();
    }
    return chromosomeName2id;
  }


  public static HashMap retrievesChromosome2Length( Connection con )
  {

    HashMap chromosomeName2id = new HashMap();
    String sql = "SELECT refname, rlength   from fref ";
    try
    {
      PreparedStatement stms = con.prepareStatement( sql );
      ResultSet rs = stms.executeQuery();
      while( rs.next() )
      {
        chromosomeName2id.put( rs.getString( 1 ), rs.getString( 2 ) );
      }
    }
    catch( SQLException e )
    {
      e.printStackTrace();
    }
    return chromosomeName2id;
  }


  public static HashMap retrieveChromosomeNames( String[] ridList, Connection con )
  {
    String ridString = "";
    HashMap chromosomeid2name = new HashMap();
    for( int i = 0; i < ridList.length - 1; i++ )
      ridString = ridString + "'" + ( String )ridList[ i ] + "', ";
    ridString = ridString + "'" + ( String )ridList[ ridList.length - 1 ] + "'";
    String sql = "SELECT distinct rid, refname  from fref  WHERE rid in (" + ridString + ")";
    try
    {
      PreparedStatement stms3 = con.prepareStatement( sql );
      ResultSet rs = stms3.executeQuery();
      while( rs.next() )
      {
        chromosomeid2name.put( rs.getString( 1 ), rs.getString( 2 ) );
      }
    }
    catch( SQLException e )
    {
      e.printStackTrace();
    }
    return chromosomeid2name;
  }

  public static HashMap retrieveFtype( int ftypeids[], Connection con )
  {
    HashMap ftypeid2track = new HashMap();
    String ftypeidString = "";
    for( int i = 0; i < ftypeids.length - 1; i++ )
      ftypeidString = ftypeidString + "'" + ftypeids[ i ] + "', ";
    ftypeidString = ftypeidString + "'" + ftypeids[ ftypeids.length - 1 ] + "'";
    String sql = "SELECT distinct ftypeid, fmethod, fsource  from ftype  WHERE  ftypeid in (" + ftypeidString + ")";
    try
    {
      PreparedStatement stms = con.prepareStatement( sql );
      ResultSet rs = stms.executeQuery();
      while( rs.next() )
      {
        String[] temp = new String[2];
        temp[ 0 ] = rs.getString( 2 );
        temp[ 1 ] = rs.getString( 3 );
        ftypeid2track.put( rs.getString( 1 ), temp );
      }
      rs.close();
      stms.close();
    }
    catch( SQLException e )
    {
      e.printStackTrace();
    }

    return ftypeid2track;
  }

  public static int countAnnotations( Connection con, int[] ftypeids )
  {
    int totalNumAnno = 0;
    if( ftypeids == null || ftypeids.length == 0 )
      return 0;
    String sql = null;
    String ftypeidString = "";
    for( int i = 0; i < ftypeids.length - 1; i++ )
      ftypeidString = ftypeidString + "'" + ftypeids[ i ] + "', ";
    ftypeidString = ftypeidString + "'" + ftypeids[ ftypeids.length - 1 ] + "'";
    sql = "select count(*) from fdata2 where ftypeid in (" + ftypeidString + ") ";


    try
    {
      PreparedStatement stms = con.prepareStatement( sql );
      ResultSet rs = stms.executeQuery();
      if( rs.next() )
        totalNumAnno = rs.getInt( 1 );
      rs.close();
      stms.close();
    }
    catch( Exception e )
    {
      e.printStackTrace();
      System.err.println( sql );
    }
    return totalNumAnno;
  }


  public static int countAnnotations( Connection con, int[] ftypeids, int rid, long start, long stop )
  {
    int totalNumAnno = 0;
    if( ftypeids == null || ftypeids.length == 0 )
      return 0;
    String sql = null;
    String ftypeidString = "";
    for( int i = 0; i < ftypeids.length - 1; i++ )
      ftypeidString = ftypeidString + "'" + ftypeids[ i ] + "', ";
    ftypeidString = ftypeidString + "'" + ftypeids[ ftypeids.length - 1 ] + "'";
    sql = "select count(*) from fdata2 where rid = ? and fstart >= ? and fstop <= ? and ftypeid in (" + ftypeidString + ") ";


    try
    {
      PreparedStatement stms = con.prepareStatement( sql );
      stms.setInt( 1, rid );
      stms.setLong( 2, start );
      stms.setLong( 3, stop );
      ResultSet rs = stms.executeQuery();
      if( rs.next() )
        totalNumAnno = rs.getInt( 1 );
      rs.close();
      stms.close();
    }
    catch( Exception e )
    {
      e.printStackTrace();
      System.err.println( sql );
    }
    return totalNumAnno;
  }


  public static String[] retrieveOrderedRid( Connection con )
  {
    ArrayList list = new ArrayList();
    try
    {
      String sql = "select distinct rid from fref order by refname ";
      PreparedStatement stms = con.prepareStatement( sql );
      ResultSet rs = stms.executeQuery();
      while( rs.next() )
        list.add( rs.getString( 1 ) );
      rs.close();
      stms.close();
    }
    catch( SQLException e )
    {
      e.printStackTrace();
    }
    return ( String[] )list.toArray( new String[list.size()] );
  }


  public static boolean isInGroup( String userId, String groupId, DBAgent db )
  {
    boolean ingroup = false;
    try
    {
      Connection con = db.getConnection();
      String sql = "select * from usergroup where groupId = ? and userId = ? ";
      PreparedStatement stms = con.prepareStatement( sql );
      stms.setString( 1, groupId );
      stms.setString( 2, userId );
      ResultSet rs = stms.executeQuery();
      if( rs.next() )
        ingroup = true;
      rs.close();
      stms.close();
    }
    catch( Exception e )
    {
      e.printStackTrace();
    }
    return ingroup;
  }

  /** untested.
   * alphabetic sort of objects
   * @throws Exception : when track name is null

  public static ArrayList  alphabeticObjectSort (String [] arr, HashMap key2obj) throws Exception {
  ArrayList  sortedObjects = new ArrayList ();
  if (arr== null || arr.length <1 )
  return null;

  if ( key2obj== null || key2obj.size() <1 )
  return null;

  if (arr.length != key2obj.size() )
  {
  throw new Exception ("Error: org.genboree.manager.tracks.Utility.alphabeticObjectSort: key and objects does not match " ) ;
  }


  if (arr.length ==1 )
  {
  sortedObjects.add(key2obj.values().iterator().next());
  return sortedObjects;
  }

  String [] lowcaseNames = new String [arr.length] ;
  String name = null;
  for (int i=0; i< arr.length; i++) {
  name = arr[i];
  if (name != null)
  lowcaseNames[i] = name.toLowerCase();
  else
  throw new Exception ("DbGclass array gclasses[" + i + "] has is null") ;
  }
  Arrays.sort(lowcaseNames);

  HashMap indexMap = new HashMap ();
  HashMap dupMap = new HashMap ();
  for (int i=0; i<lowcaseNames.length; i++) {
  if (indexMap.get(lowcaseNames[i])==null) {
  indexMap.put( lowcaseNames[i], new Integer(i));
  }
  else {
  if (dupMap.get(lowcaseNames[i]) == null)
  dupMap.put(lowcaseNames[i], new Integer(1));
  else {
  int num = ((Integer)dupMap.get(lowcaseNames[i])).intValue();
  num ++;
  dupMap.put(lowcaseNames[i], new Integer(num));
  }

  // indexMap.put("" , "");
  }
  }


  int index = -1;
  Iterator iterator = key2obj.keySet().iterator();
  while (iterator.hasNext()) {
  name = (String)iterator.next();
  index = ((Integer)indexMap.get(name.toLowerCase())).intValue();

  if (dupMap.get(name.toLowerCase())!= null) {
  int n = ((Integer)dupMap.get(name.toLowerCase())).intValue();
  n--;
  if (n>0)  {
  dupMap.put(name.toLowerCase(), new Integer(n));
  indexMap.put(name.toLowerCase(), new Integer (index+1));
  }
  else {
  dupMap.remove(name.toLowerCase());
  }
  index++;
  }
  sortedObjects.add (key2obj.get(name));
  }
  return sortedObjects ;
  }
   */

  /* * alphabetic sorting of tracks by track names
     * @param tracks:  DbFtype []
     * @return  sortedTracks : tracks in alphabetic ooder by track names
     * @throws Exception : when track name is null

    public static Style [] alphabeticstylesort (Style [] objects ) throws Exception {
                  Style [] sortedObjects= null;
                  if (objects== null || objects.length <=1)
                   return objects;

                  String [] keys = new String [objects.length] ;
                  String key = null;
                  HashMap k2o = new HashMap ();
                  for (int i=0; i<objects.length; i++) {
                     key = objects[i].featureType;
                     if (key != null) {
                         keys[i] =key;
                         k2o.put(key, objects[i]);
                     }
                     else
                         throw new Exception ("DfFtype array styles[" + i + "] has is null") ;
                  }

           ArrayList sortedList = alphabeticObjectSort(keys, k2o);
                 if (sortedList != null)
                     sortedObjects = (Style [])sortedList.toArray(new Style[sortedList.size()] ) ;
                   return sortedObjects;
              }

  */


  /**
   * alphabetic sorting of tracks by track names
   *
   * @param tracks: DbFtype []
   * @return sortedTracks : tracks in alphabetic ooder by track names
   * @throws Exception : when track name is null
   */
  public static DbFtype[] alphabeticTrackSort( DbFtype[] tracks ) throws Exception
  {
    DbFtype[] sortedTracks = null;
    if( tracks == null || tracks.length <= 1 )
      return tracks;

    String[] lowcaseTracksNames = new String[tracks.length];
    String trackName = null;
    for( int i = 0; i < tracks.length; i++ )
    {
      trackName = tracks[ i ].toString();
      if( trackName != null )
        lowcaseTracksNames[ i ] = trackName.toLowerCase();
      else
        throw new Exception( "DfFtype array tracks[" + i + "] has is null" );
    }

    Arrays.sort( lowcaseTracksNames );
    HashMap indexMap = new HashMap();

    HashMap dupMap = new HashMap();
    for( int i = 0; i < lowcaseTracksNames.length; i++ )
    {
      if( indexMap.get( lowcaseTracksNames[ i ] ) == null )
      {
        indexMap.put( lowcaseTracksNames[ i ], new Integer( i ) );
      } else
      {
        if( dupMap.get( lowcaseTracksNames[ i ] ) == null )
          dupMap.put( lowcaseTracksNames[ i ], new Integer( 1 ) );
        else
        {
          int num = ( ( Integer )dupMap.get( lowcaseTracksNames[ i ] ) ).intValue();
          num++;
          dupMap.put( lowcaseTracksNames[ i ], new Integer( num ) );
        }

        // indexMap.put("" , "");
      }
    }
    sortedTracks = new DbFtype[tracks.length];
    int index = -1;
    for( int i = 0; i < tracks.length; i++ )
    {
      trackName = tracks[ i ].toString();
      index = ( ( Integer )indexMap.get( trackName.toLowerCase() ) ).intValue();
      if( dupMap.get( trackName.toLowerCase() ) != null )
      {
        int n = ( ( Integer )dupMap.get( trackName.toLowerCase() ) ).intValue();
        n--;
        if( n > 0 )
        {
          dupMap.put( trackName.toLowerCase(), new Integer( n ) );
          indexMap.put( trackName.toLowerCase(), new Integer( index + 1 ) );
        } else
        {
          dupMap.remove( trackName.toLowerCase() );
        }
        index++;
      }
      if( index < tracks.length )
        sortedTracks[ index ] = tracks[ i ];
    }
    return sortedTracks;
  }


  /**
   * alphabetic sorting of tracks by track names
   *
   * @param tracks: DbFtype []
   * @return sortedTracks : tracks in alphabetic ooder by track names
   * @throws Exception : when track name is null
   */
  public static Style[] alphabeticStyleSort( Style[] tracks ) throws Exception
  {
    Style[] sortedTracks = null;
    if( tracks == null || tracks.length <= 1 )
      return tracks;

    String[] lowcaseTracksNames = new String[tracks.length];
    String trackName = null;
    for( int i = 0; i < tracks.length; i++ )
    {
      trackName = tracks[ i ].fmethod + ":" + tracks[ i ].fsource;
      if( trackName != null )
        lowcaseTracksNames[ i ] = trackName.toLowerCase();
      else
        throw new Exception( "DfFtype array tracks[" + i + "] has is null" );
    }

    Arrays.sort( lowcaseTracksNames );
    HashMap indexMap = new HashMap();

    HashMap dupMap = new HashMap();
    for( int i = 0; i < lowcaseTracksNames.length; i++ )
    {
      if( indexMap.get( lowcaseTracksNames[ i ] ) == null )
      {
        indexMap.put( lowcaseTracksNames[ i ], new Integer( i ) );
      } else
      {
        if( dupMap.get( lowcaseTracksNames[ i ] ) == null )
          dupMap.put( lowcaseTracksNames[ i ], new Integer( 1 ) );
        else
        {
          int num = ( ( Integer )dupMap.get( lowcaseTracksNames[ i ] ) ).intValue();
          num++;
          dupMap.put( lowcaseTracksNames[ i ], new Integer( num ) );
        }

        // indexMap.put("" , "");
      }
    }
    sortedTracks = new Style[tracks.length];
    int index = -1;
    for( int i = 0; i < tracks.length; i++ )
    {
      trackName = tracks[ i ].fmethod + ":" + tracks[ i ].fsource;
      index = ( ( Integer )indexMap.get( trackName.toLowerCase() ) ).intValue();
      if( dupMap.get( trackName.toLowerCase() ) != null )
      {
        int n = ( ( Integer )dupMap.get( trackName.toLowerCase() ) ).intValue();
        n--;
        if( n > 0 )
        {
          dupMap.put( trackName.toLowerCase(), new Integer( n ) );
          indexMap.put( trackName.toLowerCase(), new Integer( index + 1 ) );
        } else
        {
          dupMap.remove( trackName.toLowerCase() );
        }
        index++;
      }
      if( index < tracks.length )
        sortedTracks[ index ] = tracks[ i ];
    }
    return sortedTracks;
  }


  /**
   * alphabetic sorting of tracks by track names
   *
   * @param gclasses: DbFtype []
   * @return sortedTracks : tracks in alphabetic ooder by track names
   * @throws Exception : when track name is null
   */
  public static DbGclass[] alphabeticClassSort( DbGclass[] gclasses ) throws Exception
  {
    DbGclass[] sortedClasses = null;
    if( gclasses == null || gclasses.length <= 1 )
      return gclasses;

    String[] lowcaseGclassesNames = new String[gclasses.length];
    String className = null;
    for( int i = 0; i < gclasses.length; i++ )
    {
      className = gclasses[ i ].getGclass();

      if( className != null )
        lowcaseGclassesNames[ i ] = className.toLowerCase();
      else
        throw new Exception( "DbGclass array gclasses[" + i + "] has is null" );
    }

    Arrays.sort( lowcaseGclassesNames );
    HashMap indexMap = new HashMap();
    HashMap dupMap = new HashMap();
    for( int i = 0; i < lowcaseGclassesNames.length; i++ )
    {
      if( indexMap.get( lowcaseGclassesNames[ i ] ) == null )
      {
        indexMap.put( lowcaseGclassesNames[ i ], new Integer( i ) );
      } else
      {
        if( dupMap.get( lowcaseGclassesNames[ i ] ) == null )
          dupMap.put( lowcaseGclassesNames[ i ], new Integer( 1 ) );
        else
        {
          int num = ( ( Integer )dupMap.get( lowcaseGclassesNames[ i ] ) ).intValue();
          num++;
          dupMap.put( lowcaseGclassesNames[ i ], new Integer( num ) );
        }

        // indexMap.put("" , "");
      }
    }

    sortedClasses = new DbGclass[gclasses.length];
    int index = -1;
    for( int i = 0; i < gclasses.length; i++ )
    {
      className = gclasses[ i ].getGclass();
      index = ( ( Integer )indexMap.get( className.toLowerCase() ) ).intValue();
      if( dupMap.get( className.toLowerCase() ) != null )
      {
        int n = ( ( Integer )dupMap.get( className.toLowerCase() ) ).intValue();
        n--;
        if( n > 0 )
        {
          dupMap.put( className.toLowerCase(), new Integer( n ) );
          indexMap.put( className.toLowerCase(), new Integer( index + 1 ) );
        } else
        {
          dupMap.remove( className.toLowerCase() );
        }
        index++;
      }
      sortedClasses[ index ] = gclasses[ i ];
    }
    return sortedClasses;
  }


}
