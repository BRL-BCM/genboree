package org.genboree.manager.tracks;

import org.genboree.dbaccess.DBAgent;
import org.genboree.dbaccess.DbFtype;
import org.genboree.dbaccess.Refseq;
import org.genboree.dbaccess.Style;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.*;

/**
 * User: tong Date: Jun 29, 2005 Time: 9:25:58 AM
 */
public class TrackSortManager
{
  public static void setTrackOrders(Connection conn, DbFtype[] tracks, int userId, ArrayList sharedOnlyTrackNameList){
    String deleteTrack = "delete from featuresort where userId = ? ";
    String insertTrack = "INSERT INTO featuresort (ftypeid,  userId, sortkey) VALUES (?, ?, ?)";
    try {
        PreparedStatement stmt = conn.prepareStatement(deleteTrack);
        stmt.setInt(1, userId) ;
        stmt.executeUpdate();
        stmt.close();
        if(tracks != null){
          PreparedStatement pstmt = conn.prepareStatement(insertTrack);
          for(int i = 0; i < tracks.length; i++){
            DbFtype ft = tracks[i];
            if(ft == null)
              continue;
            if (sharedOnlyTrackNameList != null && sharedOnlyTrackNameList.contains(ft.toString())){
              ft = updateFtype (ft, conn);
            }

            if(ft.getFtypeid() > 0) {
              pstmt.setInt(1, ft.getFtypeid());
              pstmt.setInt(2, userId);
              pstmt.setInt(3, ft.getSortOrder());
              pstmt.executeUpdate();
            }
          }
          pstmt.close();
        }
    }
    catch (Exception ex) {
        ex.printStackTrace();
    }
  }



  public static void deleteUserOrder(Connection conn,int userId){
    String deleteTrack = "delete from featuresort where userId = ? ";
    try {
        PreparedStatement stmt = conn.prepareStatement(deleteTrack);
        stmt.setInt(1, userId) ;
        stmt.executeUpdate();
        stmt.close();
    }
    catch (Exception ex) {
        ex.printStackTrace();
    }
  }



  public static void deleteUserStyles(Connection conn,int userId){
    String deleteStyle = "delete from featuretostyle where userId = ? ";
    String deleteColor = "delete from featuretocolor where userId = ? ";
    try {
            PreparedStatement stmt = conn.prepareStatement(deleteStyle);
            stmt.setInt(1, userId) ;
            stmt.executeUpdate();
            stmt = conn.prepareStatement(deleteColor);
            stmt.setInt(1, userId) ;
            stmt.executeUpdate();
            stmt.close();
    }
    catch (Exception ex) {
        ex.printStackTrace();
    }
  }


  public static boolean emptyFeatureSort(DBAgent db, String databaseName, int userId) {
      String selectTrack = "select * FROM featuresort where userId = " + userId;
      boolean b = true;
      try
      {
        Connection conn = db.getConnection(databaseName);

        if(conn != null)
        {
          PreparedStatement stmt = conn.prepareStatement(selectTrack);
          ResultSet rs = stmt.executeQuery();
          if(rs.next())
          {
            b = false;
          }

          rs.close();
          stmt.close();
        }
      } catch (Exception ex) {
          ex.printStackTrace();
      }
      return b;
  }

    /**
     * @param tracks  DbFtype [], tracks to be sorted based on requirement of sorting order
     * @param dbName  String name of local db
     * @param dbNames String [] name of all db
     * @param db      DBAgent
     * @param out     Jspwriter
     *
     * @return arr DbFtype [] containing sorted tracks
     */

    public static DbFtype[] topShareTracks(DbFtype[] tracks, String dbName, String[] dbNames, DBAgent db, javax.servlet.jsp.JspWriter out) {
        DbFtype[] arr = null;
        ArrayList list1 = new ArrayList();
        ArrayList list2 = new ArrayList();
        if(tracks == null)
            return tracks;

        try {
            for(int i = 0; i < tracks.length; i++) {
            DbFtype ft = tracks[i];
            if(ft == null || ft.getFmethod() == null || ft.getFsource() == null)
            continue;

            if(inShareDatabase(db, dbName, dbNames, ft.getFmethod(), ft.getFsource()))
            list1.add(ft);
            else
            list2.add(ft);
            }
            if(list1.isEmpty() || list2.isEmpty())
            return Utility.alphabeticTrackSort(tracks);
            arr = new DbFtype[tracks.length];
            DbFtype[] arr1 = new DbFtype[list1.size()];
            for(int i = 0; i < list1.size(); i++)
            arr1[i] = (DbFtype) list1.get(i);

            arr1 = Utility.alphabeticTrackSort(arr1);
            DbFtype[] arr2 = new DbFtype[list2.size()];

            for(int i = 0; i < list2.size(); i++)
            arr2[i] = (DbFtype) list2.get(i);

            arr2 = Utility.alphabeticTrackSort(arr2);
            for(int i = 0; i < list1.size(); i++)
            arr[i] = arr1[i];

            for(int i = list1.size(); i < arr.length; i++)
            arr[i] = arr2[i - list1.size()];

        }
        catch (Exception e) {
            db.reportError(e, "tracksortmanager.topshareTracks");
            //e.printStackTrace();
            return tracks;
        }
        return arr;
    }


    public static Style[] topShareStyle(Style[] tracks, String dbName, String[] dbNames, javax.servlet.jsp.JspWriter out, DBAgent db) {
        ArrayList list1 = new ArrayList();
        ArrayList list2 = new ArrayList();

        for(int i = 0; i < tracks.length; i++) {
            Style ft = tracks[i];
            if(inShareDatabase(db, dbName, dbNames, ft.fmethod, ft.fsource))
                list1.add(ft);
            else
                list2.add(ft);
        }
        try {
            if(list1.isEmpty() || list2.isEmpty()) {

                return tracks;
            }
        } catch (Exception e) {}

        Style[] arr = new Style[tracks.length];


        for(int i = 0; i < list1.size(); i++)
            arr[i] = (Style) list1.get(i);

        for(int i = list1.size(); i < arr.length; i++)
            arr[i] = (Style) list2.get(i - list1.size());

        return arr;
    }


    public static DbFtype[] topUnSortedTracks(DbFtype[] tracks, String dbName, DBAgent db, javax.servlet.jsp.JspWriter out) {
        ArrayList v = getTracks(db, dbName);

        ArrayList list1 = new ArrayList();
        ArrayList list2 = new ArrayList();
        ArrayList list3 = new ArrayList();
        for(int i = 0; i < tracks.length; i++) {
            DbFtype ft = tracks[i];
            if(v.contains(ft.getFmethod() + ":" + ft.getFsource()))
                list3.add(ft);
            else if(ft.getDatabaseName().compareTo(dbName) == 0)
                list2.add(ft);
            else if(ft.getDatabaseName().compareTo(dbName) != 0)
                list1.add(ft);
        }

        if(list1.isEmpty() && list2.isEmpty())
            return tracks;


        DbFtype[] arr = new DbFtype[tracks.length];
        int start = 0;
        if(!list1.isEmpty()) {
            DbFtype[] a1 = (DbFtype[]) list1.toArray(new DbFtype[list1.size()]);
            Arrays.sort(a1);
            for(int i = 0; i < a1.length; i++)
                arr[i] = a1[i];
            start = list1.size();

        }

        if(!list2.isEmpty()) {
            DbFtype[] a2 = (DbFtype[]) list2.toArray(new DbFtype[list2.size()]);
            Arrays.sort(a2);
            for(int i = 0; i < list2.size(); i++)
                arr[i + start] = a2[i];
            start = start + list2.size();
        }

        if(!list3.isEmpty()) {
            DbFtype[] a3 = (DbFtype[]) list3.toArray(new DbFtype[list3.size()]);
            Arrays.sort(a3);
            for(int i = 0; i < a3.length; i++)
                arr[i + start] = a3[i];
        }
        return arr;
    }



    /**
     * retrieve sort order of the tracks from local database;
     * for new tracks unordered from share db or local db,
     * put them on top and in aphabactic order

     * @param db
     * @param userId
     * @param out
     * @return
     */

    public static DbFtype[] getTrackOrders(String dbName, String dbNames[], Connection conn, DbFtype [] allTracks, DbFtype[] localTracks, DbFtype [] sharedOnlyTracks,  DBAgent db, int userId, javax.servlet.jsp.JspWriter out) {
     // DbFtype[] newTracks = new DbFtype[tracks.length];
        DbFtype ft = null;
        DbFtype [] tracks = null;
        HashMap ftype2order = new HashMap();
        ArrayList  unsortedLocalTrackList = new ArrayList ();
        ArrayList orderedLocalTrackList = new ArrayList ();
      try {
           // case 1: get local track orders
         // out.println("<br>00: local tracks " + localTracks.length);
        if (localTracks != null && localTracks.length >0) {
                ftype2order = retrieveTrackOrders (conn, userId);

            if ( ftype2order != null &&  !ftype2order.isEmpty()) {
                int [] indexes = new int [ftype2order.size()];
                for (int j =0; j<indexes.length; j++)
                indexes [j] = 100000;
                for(int i = 0; i < localTracks.length; i++) {
                ft = localTracks[i];
                if(ftype2order.get( ft.toString()) != null) {


                int order = ((Integer)(ftype2order.get( ft.toString()))).intValue();
                //  ft.setSortOrder(order);
                if (orderedLocalTrackList.isEmpty()){
                orderedLocalTrackList.add(0, ft);
                indexes [0] = order;
                }
                else  {
                int index = findIndex(indexes, order);
                orderedLocalTrackList.add(index, ft);
                indexes = reorderIndexes (indexes, index, order);
                }

                }
                else {
                unsortedLocalTrackList.add(ft);
                }
                }
            }
            else {
                for (int i=0; i<localTracks.length; i++)
              unsortedLocalTrackList.add(localTracks[i]);

            }
       }
        // case 2 : get trackOrder of shared tracks
        ArrayList  orderedSharedTrackList = new ArrayList  ();
          //out.println("<br>00++ : all tracks " + localTracks.length);


         if (allTracks != null && allTracks.length >0) {
            for (int i=0; i<dbNames.length; i++) {
                if (dbNames[i].compareTo(dbName) ==0)
                continue;

                try {
                    Connection con = db.getConnection(dbNames[i]);
                     HashMap track2Order  =  retrieveTrackOrders (con, userId);
                     if (track2Order != null  && !track2Order.isEmpty()) {
                            int [] indexes = new int [track2Order.size()];
                            for (int j =0; j<indexes.length; j++)
                                    indexes [j] = 100000;

                            for(int j = 0; j < allTracks.length; j++) {
                                ft = allTracks[j];
                                if(track2Order.get( ft.toString()) != null) {
                                    int order = ((Integer)(track2Order.get( ft.toString()))).intValue();
                                    // add to ordered list
                                    if (orderedSharedTrackList.isEmpty()){
                                        orderedSharedTrackList.add(0, ft);
                                        indexes [0] = order;
                                    }
                                    else  {
                                        int index = findIndex(indexes, order);
                                        orderedSharedTrackList.add(index, ft);
                                        indexes = reorderIndexes (indexes, index, order);
                                    }
                                }
                                else {
                                // we can not put it to unordered list for it may present in other db
                                }
                            }
                     }
                    else {

                     }
                }
                catch (SQLException e) {
                e.printStackTrace();
                }
            }
        }

          ArrayList tempList = new ArrayList ();
          // update share ordered
        for (int i=0; i<orderedSharedTrackList.size(); i++) {
            ft = (DbFtype )orderedSharedTrackList.get(i);
            if( !orderedLocalTrackList.contains( ft)) {
            tempList.add(ft);
            }
        }
         orderedSharedTrackList = tempList;


         // case 3:  get shared  unsorted tracks
          ArrayList unorderedShareTrackList = new ArrayList ();
        for(int i = 0; i < sharedOnlyTracks.length; i++) {
            ft = sharedOnlyTracks[i];
            if( !orderedSharedTrackList.contains( ft)) {
                unorderedShareTrackList.add(ft);
            }
        }
         ArrayList unorderedLocalList = new ArrayList ();

         // update local unordered
         for (int i=0; i<unsortedLocalTrackList.size(); i++) {
                 ft = (DbFtype )unsortedLocalTrackList.get(i);
           if( !orderedSharedTrackList.contains( ft) && !unorderedShareTrackList.contains(ft)) {
               unorderedLocalList.add(ft);
           }

         }
            // update unordered tracks
           ArrayList unorderedShareList = new ArrayList ();
          for (int i=0; i< unorderedShareTrackList.size(); i++) {
                  ft = (DbFtype ) unorderedShareTrackList.get(i);
            if( !unorderedLocalList.contains( ft)) {
                unorderedShareList.add(ft);
            }
          }

         // now we order the tracks
        // the order is : bottom: ordered local tracks; next : order share only tracks;
        // next: unordered local tracks ;
        // top : unordered share tracks
         int numTracks = allTracks.length;
         tracks = new DbFtype [numTracks];
       if (numTracks ==0)
          return null;

        int index = 0;

       //top layer: unordered, shared tracks
       if ( unorderedShareTrackList.size() >0) {
           DbFtype [] temp =  (DbFtype []) unorderedShareTrackList.toArray(new DbFtype [ unorderedShareTrackList.size()]);
          Arrays.sort(temp);
          for (int i=0; i< temp.length; i++) {
              tracks [i] = temp[i];
             }
       }

       index = unorderedShareList.size();
         // layer 2: unordered local tracks

          if (unorderedLocalList.size() >0) {

             DbFtype [] temp =  (DbFtype []) unorderedLocalList.toArray(new DbFtype [ unorderedLocalList.size()]);
          Arrays.sort(temp);
             for (int i=0; i< temp.length; i++) {
                 tracks [i+index] = temp[i];
                     int x = i + index;
                 }
          }

        index = unorderedLocalList.size() +unorderedShareList.size();
        //layer 3 layer: ordered, shared tracks

          for (int i=0; i< orderedSharedTrackList.size(); i++) {
                 int x = i + index;
              tracks [i + index] = (DbFtype) orderedSharedTrackList.get(i);
            }
              index += orderedSharedTrackList.size();

        //layer 4 layer: ordered, local tracks

            for (int i=0; i< orderedLocalTrackList.size(); i++) {
              tracks [i + index] = (DbFtype) orderedLocalTrackList.get(i);
                  int x = i + index;
               }

           if (tracks != null && tracks.length > 0 ) {
            for (int i=0; i< tracks.length; i++) {
              if (tracks[i] != null)
                  tracks[i].setSortOrder(i+1);
             }
           }

      }
        catch (Exception e)  {
          e.printStackTrace();
      }
        return tracks;
   }

    public static int findIndex (int [] indexes, int order) {
        int index = 0;
        for (int x=0; x<indexes.length; x++) {
            if (indexes[x] >order){
                index = x;
                break;
            }
        }
        return index;
    }


public static int [] reorderIndexes (int [] indexes, int index, int order) {
    int length = indexes.length;
    for (int y=0; y< length -index-1; y++) {
        indexes [length -y-1] = indexes[length-y-2];
    }
    indexes [index] = order;
    return indexes;
}


public static HashMap retrieveTrackOrders (Connection conn, int userId) {
    HashMap ftype2Order = new HashMap ();
    String sql = " select f.fmethod, f.fsource from featuresort fs, ftype f where fs.userId = ?  and f.ftypeid = fs.ftypeid order by sortkey";

    try {
        if(conn != null && !conn.isClosed()){
            int count = 1;
            PreparedStatement stms = conn.prepareStatement(sql);
            stms.setInt(1, userId);
            ResultSet rs = stms.executeQuery();
            while(rs.next()){
            ftype2Order.put(rs.getString(1)+ ":" + rs.getString(2) , new Integer(count));
            count++;
            }
              rs.close();
           // user has no order, by it has default order, use default
            if ( ftype2Order.isEmpty()) {
                 PreparedStatement stms1 = conn.prepareStatement(sql);
                count = 1;

                stms1.setInt(1, 0);
              ResultSet rs1   = stms1.executeQuery();
                while(rs1.next()){
                ftype2Order.put(rs1.getString(1)+ ":" + rs1.getString(2) , new Integer(count));
                count++;
                }
                  rs1.close();     stms1.close();
            }

            stms.close();
        }
        }
        catch (Exception e) {
        e.printStackTrace();
        }

   return ftype2Order ;
}




    public static DbFtype[] reorderTracks(DbFtype[] tracks) {
        if(tracks == null || tracks.length == 0)
            return tracks;
        DbFtype[] newTracks = new DbFtype[tracks.length];
        int index = -1;
        ArrayList list = new ArrayList ();
        int min = 0;
        int max = 0;
        int currentOrder = 0;
        for(int i = 0; i < tracks.length; i++) {
            DbFtype ft = tracks[i];
            currentOrder = ft.getSortOrder();
            if(list.isEmpty()) {
                list.add(ft);
            } else {
                min = ((DbFtype) list.get(0)).getSortOrder();
                max = ((DbFtype) list.get(list.size() - 1)).getSortOrder();
                index = findIndex(list, min, max, currentOrder);
                list.add(index, ft);
            }

        }
        newTracks =(DbFtype []) list.toArray(new DbFtype [list.size()]);
        for(int i = 0; i < newTracks.length; i++)
            newTracks[i].setSortOrder(i + 1);

        return newTracks;
    }


    public static int findIndex(ArrayList  list, int min, int max, int currentOrder) {
        int index = -1;
        if(list.isEmpty() || currentOrder < min)
            return 0;
        else if(currentOrder > max)
            return list.size();
        else {
            int current = -1;
            int next = -1;
            for(int i = 0; i < list.size(); i++) {
                DbFtype ft = (DbFtype) list.get(i);
                current = ft.getSortOrder();
                DbFtype ftNext = (DbFtype) list.get(i + 1);
                next = ftNext.getSortOrder();
                if(currentOrder >= current && currentOrder <= next)
                    return i + 1;
            }
        }

        return -1;
    }


    public static ArrayList getTracks(DBAgent db, String databaseName) {
        String selectTrack = " select f.fmethod, f.fsource from  ftype f, featuresort fs " +
                " where f.ftypeId = fs.ftypeId  ";
        ArrayList v = new ArrayList();
        try {
            Connection conn = db.getConnection(databaseName);
            if(conn != null) {
                PreparedStatement stmt = conn.prepareStatement(selectTrack);

                ResultSet rs = stmt.executeQuery();
                while(rs.next()) {
                    v.add(rs.getString(1) + ":" + rs.getString(2));
                }
                stmt.close();
            }
        } catch (Exception ex) {
            ex.printStackTrace();
            db.reportError(ex, "Refseq.setSortTracks()");
        }
        return v;
    }


    public static boolean inShareDatabase(DBAgent db, String databaseName, String[] dbNames, String fmethod, String fsource) {
        String selectTrack = " select * from  ftype f " +
                " where f.fmethod =  ?  and f.fsource = ? ";
        boolean inDB = false;
        try {

            for(int i = 0; i < dbNames.length; i++) {
                if(dbNames[i].compareTo(databaseName) == 0)
                    continue;
                 Connection conn = db.getConnection(dbNames[i]);
                if(conn != null) {
                    PreparedStatement stms = conn.prepareStatement(selectTrack);
                    stms.setString(1, fmethod);
                    stms.setString(2, fsource);
                    ResultSet rs = stms.executeQuery();
                    if(rs.next()) {
                        inDB = true;
                        break;
                    }
                    rs.close();
                    stms.close();
                }
            }
        } catch (Exception ex) {
            ex.printStackTrace();
            db.reportError(ex, "TrackSortManager.inShareDatabase()");
        }
        return inDB;
    }


    public static String findShareDatabaseName(DBAgent db, String databaseName, String[] dbNames, String fmethod, String fsource) {
        String selectTrack = " select * from  ftype f " +
                " where f.fmethod = ?  and f.fsource = ?  ";
        String dbname = null;
        try {
            for(int i = 0; i < dbNames.length; i++) {
                if(dbNames[i].compareTo(databaseName) == 0)
                    continue;

                Connection conn = db.getConnection(dbNames[i]);
                if(conn != null) {
                    PreparedStatement stms = conn.prepareStatement(selectTrack);
                    stms.setString(1, fmethod);
                    stms.setString(2, fsource);

                    ResultSet rs = stms.executeQuery();
                    if(rs.next()) {
                        stms.close();
                        return dbNames[i];
                    }
                    stms.close();
                }
            }
        } catch (Exception ex) {
            ex.printStackTrace();
            db.reportError(ex, "Refseq.setSortTracks()");
        }
        return dbname;
    }


    public static boolean checkSortTracks(DBAgent db, int userId, String databaseName) {
        String selectTrack = "select  sortkey from featuresort where userId = " + userId + "  order by sortkey";
        int current = 0;
        int last = 0;
        boolean b = true;
        try {
            Connection conn = db.getConnection(databaseName);
            if(conn != null) {
                PreparedStatement stmt = conn.prepareStatement(selectTrack);

                ResultSet rs = stmt.executeQuery();
                while(rs.next()) {
                    current = rs.getInt(1);
                    if((current - last) != 1) {

                        b = false;
                        break;
                    }
                    last = current;

                }
                rs.close();
                stmt.close();


            }
        } catch (Exception ex) {
            ex.printStackTrace();
            db.reportError(ex, "Refseq.setSortTracks()");
        }
        return b;
    }


    public static void deleteSortTracks(DBAgent db, int userId, String databaseName) {
        String deleteTrack = "delete from featuresort where userId =   " + userId;
        try {
            Connection conn = db.getConnection(databaseName);
            if(conn != null) {
                PreparedStatement stmt = conn.prepareStatement(deleteTrack);

                stmt.executeUpdate(deleteTrack);

                stmt.close();
            }
        } catch (Exception ex) {
            ex.printStackTrace();
            db.reportError(ex, "Refseq.setSortTracks()");
        }
    }


    public static DbFtype[] updateFtypeIds(DbFtype[] tracks, Connection con) {
        for(int i = 0; i < tracks.length; i++) {
                if(tracks[i] != null)
                    tracks[i] = updateFtype(tracks[i], con);
        }
        return tracks;
    }


    public static DbFtype updateFtype(DbFtype ft, Connection con)  {
    if(ft == null)
    return ft;
    String sqlInsert = " insert ignore  into ftype (fmethod, fsource) values (?, ?) " ;
    String sqlSelect = "select last_insert_id()";
    int id = 0;
    try {
        PreparedStatement stms = con.prepareStatement(sqlInsert);
        stms.setString(1, ft.getFmethod());
        stms.setString(2, ft.getFsource());
        stms.executeUpdate() ;

        stms = con.prepareStatement(sqlSelect);
        ResultSet rs = stms.executeQuery();
        if (rs.next())
        id = rs.getInt(1);
        rs.close();
        stms.close();
        ft.setFtypeid(id);
    }
    catch (SQLException e) {
        e.printStackTrace();
    }

    return ft;
    }


    public static DbFtype[] fetchTracksSorted(Refseq rseq, DBAgent db, int userId, String databaseName) throws SQLException {
        Hashtable ht = new Hashtable();
        Hashtable htUpld = rseq.fetchUploadMap(db);
        Enumeration en;
        int i;
        try {
            for(en = htUpld.keys(); en.hasMoreElements();) {
                String dbName = (String) en.nextElement();
                String uploadId = (String) htUpld.get(dbName);
                DbFtype[] tracks = DbFtype.fetchAll(db.getConnection(dbName), dbName, userId);
                for(i = 0; i < tracks.length; i++) {
                    DbFtype ft = tracks[i];
                    String key = ft.toString();
                    if(key.compareToIgnoreCase("Component:Chromosome") == 0 ||
                            key.compareToIgnoreCase("Supercomponent:Sequence") == 0)
                        continue;

                    ft.setDatabaseName(dbName);
                    ft.setUploadId(uploadId);
                    if(ht.get(key) == null) ht.put(key, ft);
                }
            }

            Connection conn = db.getConnection(databaseName);
            PreparedStatement pstmt = conn.prepareStatement("SELECT sortkey FROM featuresort WHERE ftypeid=?  AND userId=?");
            ResultSet rs;
            for(en = ht.keys(); en.hasMoreElements();) {
                String trkName = (String) en.nextElement();
                DbFtype ft = (DbFtype) ht.get(trkName);
                pstmt.setInt(1, ft.getFtypeid());

                pstmt.setInt(2, userId);
                rs = pstmt.executeQuery();
                if(!rs.next()) {
                    if(userId != 0) {
                        pstmt.setInt(1, ft.getFtypeid());

                        pstmt.setInt(2, 0);
                        rs = pstmt.executeQuery();
                        if(!rs.next()) rs = null;
                    } else
                        rs = null;
                }
                if(rs != null) {
                    ft.setSortOrder(rs.getInt(1));
                }
            }
            pstmt.close();
        } catch (Exception ex) {
            db.reportError(ex, "Refseq.fetchTracksSorted()");
        }

        DbFtype[] rc = new DbFtype[ht.size()];
        i = 0;
        for(en = ht.keys(); en.hasMoreElements();) {
            rc[i++] = (DbFtype) ht.get(en.nextElement());
        }
        Arrays.sort(rc);

        return rc;
    }


    public static int findSortKey(DBAgent db, int ftypeId, int userId, String databaseName) {
        int order = -1;
        try {
            Connection conn = db.getConnection(databaseName);
            PreparedStatement pstmt = conn.prepareStatement("SELECT sortkey FROM featuresort WHERE ftypeid=?  AND userId=?");
            ResultSet rs;
            pstmt.setInt(1, ftypeId);
            pstmt.setInt(2, userId);
            rs = pstmt.executeQuery();
            if(!rs.next()) {
                if(userId != 0) {
                    pstmt.setInt(1, ftypeId);
                    pstmt.setInt(2, 0);
                    rs = pstmt.executeQuery();
                    if(!rs.next()) rs = null;
                } else
                    rs = null;
            }
            if(rs != null) {
                order = rs.getInt(1);
            }

            pstmt.close();
        } catch (Exception ex) {
            db.reportError(ex, "Refseq.fetchTracksSorted()");
        }
        return order;
    }

    public static int findFtypeId(DBAgent db, String fmethod, String fsource, String databaseName) {
        int id = -1;
        try {

            Connection conn = db.getConnection(databaseName);
            PreparedStatement pstmt = conn.prepareStatement("SELECT ftypeId FROM ftype WHERE fmethod = ?  AND fsource = ? ");
            ResultSet rs;

            pstmt.setString(1, fmethod);

            pstmt.setString(2, fsource);
            rs = pstmt.executeQuery();
            if(rs.next()) {
                id = rs.getInt(1);
            }

            pstmt.close();
        } catch (Exception ex) {
            db.reportError(ex, "Refseq.fetchTracksSorted()");
        }


        return id;
    }


    public static void main(String[] args) {
        String[] dbNames = new String[2];
        dbNames[0] = "genboree_r_a6127b8fd3939f3b6f157e06ae2e562b";
        dbNames[1] = "genboree_r_0f017cf20579fc9d442bfb7227ef3a4c";
        String dbName = dbNames[0];
        String fmethod = "Cytogenetic";
        String fsource = "Band";
        String sharedbname = findShareDatabaseName(DBAgent.getInstance(), dbName, dbNames, fmethod, fsource);
        System.out.println(sharedbname);
    }


}
