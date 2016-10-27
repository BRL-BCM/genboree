package org.genboree.dbaccess;

import java.sql.*;
import java.util.ArrayList;
import java.util.Vector;

/**
 * User: tong Date: Jul 15, 2005 Time: 2:35:32 PM
 */
public class SubOrdinateDBManager {

    /**
     * delete tracks in subordinate db when  tracks from a localDB are deleted
     * @param db
     * @param trkIds : track Ids deleted from local db
     * @param localdbName
     * @throws SQLException
     */

    public static void deleteSubordinateTracks(DBAgent db, String[] trkIds,String [] subdbNames, String localdbName) throws SQLException {


       Vector trackFeatures = new Vector();
        String dbName = null;


       trackFeatures = findTrackFeatures(db, trkIds, localdbName);

        if(trackFeatures == null || trackFeatures.isEmpty())
            return;

        for(int i = 0; i < subdbNames.length; i++) {
            dbName = subdbNames[i];
            int [] trackIds = findTrackIds(db, dbName, trackFeatures);
            deleteTracks(dbName, trackIds, db);
        }
        return;
    }



    static int [] findTrackIds(DBAgent db, String dbName, Vector trackFeatures) {
      Connection con = null;
        String sql = "select ftypeid from ftype where fmethod = ? and fsource = ? ";
       int [] ids = null;
      PreparedStatement stms = null;
        ResultSet rs = null;
        Vector v = new Vector();
      try {
          con = db.getConnection(dbName);
          if(con==null && con.isClosed())
                      return null;
           stms = con.prepareStatement(sql);

      }
        catch(SQLException e ) {
          e.printStackTrace();
          return null;
      }




        for(int i = 0; i < trackFeatures.size(); i++) {
            String[] feature = (String[]) trackFeatures.get(i);
            if(feature == null || feature.length < 2)
                continue;
            try {
                stms.setString(1, feature[0]);
                stms.setString(2, feature[1]);
                rs = stms.executeQuery();
                while(rs.next())
                    v.add(rs.getString(1));
            } catch(SQLException e) {
                e.printStackTrace();
                continue;
            }

        }


        if(!v.isEmpty()) {
            ids = new int[v.size()];
            for(int i = 0; i < v.size(); i++) {
                try{
                ids[i] = Integer.parseInt((String) v.get(i));
                }
                catch(NumberFormatException e) {
                    e.printStackTrace();
                    continue;
                }
            }
        }

        try {rs.close();
        stms.close();
        } catch(SQLException e) {
            e.printStackTrace();
          return null;
        }


        return ids;
    }






    public static void   deleteTracks(String dbName, int [] trkIds, DBAgent db){

        try {
            int i;
             String lst = null;

             if( trkIds != null )
             for( i=0; i<trkIds.length; i++ )
             {
                 if( lst == null )
                     lst = "" + trkIds[i];
                 else lst = lst + "," + trkIds[i];
             }

             Connection conn = db.getConnection(dbName);
             if( lst != null )
             {
                 Statement stmt = conn.createStatement();
                 stmt.executeUpdate(
                     "DELETE FROM fdata2 WHERE ftypeid IN ("+lst+")" );
                stmt.executeUpdate(
                     "DELETE FROM fdata2_cv WHERE ftypeid IN ("+lst+")" );
                stmt.executeUpdate(
                     "DELETE FROM fdata2_gv WHERE ftypeid IN ("+lst+")" );
                 stmt.executeUpdate("DELETE FROM ftype WHERE ftypeid IN (" + lst + ")");
                 stmt.executeUpdate("DELETE FROM featuredisplay WHERE ftypeid IN (" + lst + ")");
                 stmt.executeUpdate("DELETE FROM featuretocolor WHERE ftypeid IN (" + lst + ")");
                 stmt.executeUpdate("DELETE FROM featuretostyle WHERE ftypeid IN (" + lst + ")");
                 stmt.executeUpdate("DELETE FROM featuretolink WHERE ftypeid IN (" + lst + ")");
                 stmt.executeUpdate("DELETE FROM fidText WHERE ftypeid IN (" + lst + ")");
                 stmt.executeUpdate("DELETE FROM featureurl WHERE ftypeid IN (" + lst + ")");
                 stmt.executeUpdate("DELETE FROM featuresort WHERE ftypeid IN (" + lst + ")");
                 stmt.executeUpdate("DELETE FROM ftype2gclass WHERE ftypeid IN (" + lst + ")");
               stmt.close();
             }
            }
             catch(SQLException e1) {
                 e1.printStackTrace();
                return ;
             }

    };


  public static  void updateFtype(DbFtype ft, String newfmethod, String newfsource, String [] subdbnames, DBAgent db)
  {
    if(subdbnames == null || subdbnames.length <=0)
    {
      return ;
    }
    String dbName = null ;
    for(int i=0; i<subdbnames.length ; i++)
    {
      dbName = subdbnames[i] ;
      if(dbName == null)
      {
        continue ;
      }
      updateFtype(dbName, ft.getFmethod(), ft.getFsource(), newfmethod, newfsource) ;
    }
  }

  public static void updateFtype( String dbName, String oldfmethod, String oldfsource, String newfmethod, String newfsource)
  {
    // System.err.println("SubOrdinateDBManager.updateFtype: dbName = " + dbName +
    //                   "\n                                  oldfmethod = " + oldfmethod +
    //                   "\n                                  oldfsource = " + oldfsource +
    //                   "\n                                  newfmethod = " + newfmethod +
    //                   "\n                                  newfsource = " + newfsource) ;
    try
    {
      DBAgent db = DBAgent.getInstance();
      Connection conn = db.getConnection(dbName) ;
      if(conn == null)
      {
        System.err.println("ERROR: SubOrdinateDBManager.updateFtype(S,S,S,S,S) => can't get connection to user database that uses this template (which is being changed).\n" +
                           "       Where did this database go or was it not deleted properly? Database name:\n" +
                           "       " + dbName) ;
      }
      else
      {
        PreparedStatement pstmt = conn.prepareStatement("delete from ftype where fmethod = ? and fsource = ?") ;
        pstmt.setString(1, oldfmethod) ;
        pstmt.setString(2, oldfsource) ;
        pstmt.executeUpdate() ;
        pstmt.close() ;
        pstmt = conn.prepareStatement("insert into ftype (fmethod, fsource) values (?, ?)") ;
        pstmt.setString(1, newfmethod) ;
        pstmt.setString(2, newfsource) ;
        pstmt.close() ;
      }
      db.closeConnection(conn) ;
    }
    catch(SQLException e1)
    {
      e1.printStackTrace() ;
    }
    return ;
  }




    public static void   updateURL( String [] subdbNames, String fmethod, String fsource,   String url, String description,String label)
    {


        String sqlfid  = "select distinct ftypeid from ftype where fmethod = '" + fmethod + "' and fsource = '" +
        fsource + "'";
       for(int i =0; i<subdbNames.length; i++) {
             int ftypeId = -1;

       PreparedStatement stms = null;
       ResultSet rs = null;
       try {
            Connection con = DBAgent.getInstance().getConnection(subdbNames[i]);
              if(con != null && !con.isClosed()) {
                   stms = con.prepareStatement(sqlfid);
                   rs = stms.executeQuery();
                  while(rs.next())
                       ftypeId = rs.getInt(1);

                  if(ftypeId <=0 )
                    continue;

                  String  url1="";
                  String desc1=""; String label1="";

                  String sqlSelect = "select url, label, description from featureurl where ftypeid = "  + ftypeId;
                    stms = con.prepareStatement(sqlSelect);
                  rs = stms.executeQuery();
                  if(rs.next()) {
                      url1 = rs.getString(1);
                      if(url1 != null)
                          url1 = url1.trim();

                      if(url1==null || url1.compareTo("")==0)
                      url1 = url;


                      label1 = rs.getString(2);
                      if(label1 != null)
                          label1 = label1.trim();

                      if(label1==null || label1.compareTo("")==0)
                      label1 = label;



                      desc1 = rs.getString(3);

                      if(desc1 != null)
                          desc1 = desc1.trim();

                      if(desc1==null || desc1.compareTo("")==0)
                      desc1 = description;
                      System.out.println (" id " + ftypeId  + "  hasresult"  );

                  }
                  else {
                      System.out.println (" id " + ftypeId  + "  no result"  );
                    url1 = url;
                    label1 = label;
                    desc1 = description;

                  }

                  rs.close();
                String sqldelete = " delete from featureurl where ftypeId = " + ftypeId;
                     stms = con.prepareStatement(sqldelete) ;
                      stms.executeUpdate();

               String s =    "INSERT INTO featureurl (ftypeId, url, description, label) "+
                        "VALUES (" + ftypeId + ", '" + url1 + "', '" + desc1 + "' , '" + label1 + "')";

               System.out.println (s);

                  stms = con.prepareStatement(s) ;


                stms.executeUpdate();
                stms.close();

              }

           con.close();
        }
        catch(SQLException e) {
             e.printStackTrace();
           continue;
        }   catch(Exception e) {
             e.printStackTrace();
           continue;
        }
     }

    };



    public static void updateClass(String[] subdbNames, String oldClassName, String newClassName) {
       String sqlupdate = "update gclass set gclass = '" + newClassName + "'  where gclass = '"  + oldClassName + "'";
        for(int i = 0; i < subdbNames.length; i++) {
        PreparedStatement stms = null;
        try {
                Connection con = DBAgent.getInstance().getConnection(subdbNames[i]);
                if(con != null && !con.isClosed()) {
                    stms = con.prepareStatement(sqlupdate);
                   stms.executeUpdate();
                 stms.close();    con.close();
             }
           } catch(SQLException e) {
                e.printStackTrace();
                continue;
            } catch(Exception e) {
                e.printStackTrace();
                continue;
            }
        }

    };




     /**
      *
      * @param db
      * @param trkIds
      * @param dbName
      * @return Hashtable of track ftypeID : String [] contains fmethod and fsource; empty if none found
      */


     public static Vector  findTrackFeatures(DBAgent db, String [] trkIds, String dbName){
        Vector v = new Vector();
         String lst = null;
         if( trkIds != null )
         for( int i=0; i<trkIds.length; i++ )
         {
             if( lst == null ) lst = trkIds[i];
             else lst = lst + "," + trkIds[i];
         }

         try {
             if( lst != null )
             {
                 String sql = "select distinct fmethod, fsource from ftype where ftypeId in (" + lst + ")" ;
                 Connection con = db.getConnection(dbName);
                 PreparedStatement stms = con.prepareStatement(sql);
                 ResultSet rs = stms.executeQuery();
                 while(rs.next()) {
                  String [] feature = new String[2];
                  feature[0]= rs.getString(1);
                  feature[1] = rs.getString(2) ;
                  v.add( feature );
                 }
             }
         }
         catch(SQLException e ) {
             e.printStackTrace();
         }
         return v;
     };


    /**
     *
     * @param db  DBAgent
     * @param databaseName  String  main database data used to find subordinate db names
     * @return  String [] of subordinate db names, null if empty
     */

    public static String[] findSubordinateDBNames(DBAgent db, String databaseName) throws SQLException {
        String sql = " select distinct refseqId  from upload where databaseName = '" + databaseName + "'";
        String sql2 = "select distinct databaseName from upload where refseqId = ? "
                + " and databaseName != ? ";
        ArrayList listRefseqIds = new ArrayList();
        ArrayList listdbnames = new ArrayList();
        Connection con = null;
        PreparedStatement stms = null;
         ResultSet rs = null;
         String refseqId =  null;
         int id = 0;
            try {
                con = db.getConnection("genboree");
            if(con != null) {
                stms = con.prepareStatement(sql);

                rs = stms.executeQuery();
                while(rs.next()) {
                    listRefseqIds.add(rs.getString(1));
                }

                if(listRefseqIds.isEmpty() || listRefseqIds.size() <= 1)
                    return null;

                stms = con.prepareStatement(sql2);
                stms.setString(2, databaseName);
                for(int i = 0; i < listRefseqIds.size(); i++) {
                     refseqId = (String) listRefseqIds.get(i);
                     try {
                     id = Integer.parseInt(refseqId);
                     }
                    catch(NumberFormatException e ){
                         System.err.println("error happened in findSubordinateDBName().parsingInt "  + refseqId);
                         continue;
                     }
                   stms.setInt(1, id);
                   rs = stms.executeQuery();
                    while(rs.next()) {
                        if(databaseName.compareToIgnoreCase(rs.getString(1)) !=0 )
                        listdbnames.add(rs.getString(1));
                    }
                }
                rs.close();
                stms.close();
            }
        } catch(SQLException ex) {
          throw ex;
        }
        return (String[]) listdbnames.toArray(new String[listdbnames.size()]);
    }


  public static void main (String [] args ) {
    ///  String [] dbnames = findSubordinateDBNames ( DBAgent.getInstance(), "genboree_r_a6127b8fd3939f3b6f157e06ae2e562b");

      String [] dbnames = new String [] { "genboree_r_0f017cf20579fc9d442bfb7227ef3a4c"};

      updateURL (dbnames, "Gene", "RefSeq",    "testqq", "testqq", "testqq");

  }



}
