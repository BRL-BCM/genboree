package org.genboree.dbaccess;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.Vector;

/**
 * Created by IntelliJ IDEA. User: tong Date: Jun 9, 2005 Time: 10:43:54 AM To change this template use File | Settings
 * | File Templates.
 */
public class TableFieldUpdator implements SqlQueries {

    /**
     * update int field of a databse table
     * @param tableName
     * @param fieldName
     * @param value
     * @param con
     */

    public static void updateTable (String tableName, String fieldName, int value, Connection con  ) {
        String sql = "update " + tableName + "  set " + fieldName + "='"  + value + "'";

          System.out.println (sql );
        PreparedStatement stms  =  null;
        try {
           stms =  con.prepareStatement(sql);


           stms.executeUpdate();

           stms.close();
        }
        catch (SQLException e) {
            e.printStackTrace();
        }
    }



    /**
     * @param con
     * @return
     */
    public static RefSeqInfo [] findUploadInfo (Connection con  ) {
            String sql = "select r.refSeqId, r.databaseName, u.uploadId  "
                    + "  from refseq r, upload u, refseq2upload ru "
                    + "  where r.refseqId = ru.refSeqId and u.uploadId = ru.uploadId "
                     + " and r.databaseName = u.databaseName";

                             System.out.println (sql);

            PreparedStatement stms  =  null;
            RefSeqInfo rinfo = null;
            ArrayList list = new ArrayList();
            try {
               stms =  con.prepareStatement(sql);
               ResultSet rs =stms.executeQuery(sql);
               while (rs.next()) {
                  rinfo = new RefSeqInfo();
                  rinfo.refseqID = rs.getInt(1);
                  rinfo.uploadId = rs.getInt(3);
                  rinfo.databaseName = rs.getString(2);
                  list.add(rinfo);
               }
               rs.close();
               stms.close();
            }
            catch (SQLException e) {
                System.out.println ("1111111111");
                e.printStackTrace();
            }
           return (RefSeqInfo[])list.toArray(new RefSeqInfo [list.size()]);
        }



    public static void updateTable(RefSeqInfo[] rs,  String serverName, String sql, String testdbName) {
       if (rs == null || rs.length <= 0)
           return;

        if (serverName == null)
            serverName = "locahost";

        Connection con = null;
        //DBAgent agent = new DBAgent ();
        String database = null;

        PreparedStatement stms = null;


        for (int i = 0; i < rs.length; i++) {

            // for (int i = 0; i < 1; i++) {
            database = rs[i].databaseName;

            System.out.println(" !!! working with  " + database);

            try {
                con = DBConnector.makeConnection(serverName, database);
                int a = 0;
                int b = 0;

                if (con == null || con.isClosed()) {
                    a++;
                   // System.out.println("connection not made for databse " + database + "\t fail  " + a);
                    continue;
                } else {
                    b++;
                   // System.out.println("  !!  connection success for database " + database + "\t success ");
                }


               stms = con.prepareStatement(sql);
               stms.executeUpdate();


                con.close();
            } catch (SQLException e) {
                System.out.println(" skipped sql: \n " + sql );
                //e.printStackTrace();
                continue;
            }
        }

        try {stms.close();} catch (SQLException e) {e.printStackTrace();}

    }






   public static  void  findDBNames(RefSeqInfo[] rs, String fmethod, String fsource,  String serverName,  String testdbName) {
       if (rs == null || rs.length <= 0)
           return;

        if (serverName == null)
            serverName = "locahost";

        Connection con = null;
        //DBAgent agent = new DBAgent ();
        String database = null;

        PreparedStatement stms = null;
        ArrayList list = new ArrayList();
         String sql = " select count(distinct refseqId) from upload where databaseName = ? ";

            try {
                con = DBConnector.makeConnection(serverName, "genboree");

                if (con == null || con.isClosed())
                  return;
               stms = con.prepareStatement(sql);
                   // System.out.println("  !!  connection success for database " + database + "\t success ");

        for (int i = 0; i < rs.length; i++) {

            // for (int i = 0; i < 1; i++) {
            database = rs[i].databaseName;

            System.out.println(" !!! working with  " + database);




               stms.setString(1, database);
               ResultSet rs1  = stms.executeQuery();
             while (rs1.next())  {
                   System.out.println (database + "\t" + rs1.getInt(1));
               }


        }        stms.close();
                con.close();
            } catch (SQLException e) {

                e.printStackTrace();

            }




    }



   static    void populateFtype2GClassFromFeaturetogroup(RefSeqInfo[] rs, DBAgent db) {
          String sqlInsert = " insert ignore into ftype2gclass select * from featuretogroup ";
          for (int i = 0; i < rs.length; i++) {
              // for (int i = 0; i < 1; i++) {
              String database = rs[i].databaseName;
              if (database == null || (database.compareTo("")==0))
              continue;
              System.out.println(" !!! working with  " + database);
              try {
                  Connection con = db.getConnection(database);

                  if (con != null && !con.isClosed()) {
                      PreparedStatement stms = con.prepareStatement(sqlInsert);
                      stms.executeUpdate();
                      stms.close();
                      con.close();
                  }
              } catch (SQLException e) {

                  e.printStackTrace();
                  continue;
              }
          }

      }


    static    void populateFtype2GClassFromFdata2(RefSeqInfo[] info, DBAgent db) {

             String selectFromFData2  = "select distinct  ftypeid, gid from fdata2 ";
             String isEmpty = "select * from ftype2gclass where ftypeid = ? and gid = ? ";
             for (int i = 0; i < info.length; i++) {

             PreparedStatement stms = null;
             ResultSet rs = null;
             Connection con = null;
                 PreparedStatement stms1 = null;

                 // for (int i = 0; i < 1; i++) {
                 String database = info[i].databaseName;
                 if (database == null || (database.compareTo("")==0))
                 continue;
                 System.out.println(" !!! working with  " + database);
                 try {
                     con = db.getConnection(database);
                     if (con != null && !con.isClosed()) {
                          stms = con.prepareStatement(selectFromFData2 );
                          rs = stms.executeQuery();

                         while (rs.next()) {
                             int [] ids = new int[2];
                             ids[0] = rs.getInt(1);
                             ids[1] = rs.getInt(2);
                             if (!inFtype2Class(con, ids))
                                 insertClassMap(con, ids);
                         }
                         rs.close();
                    }

                    stms.close();
                    con.close();

                 } catch (SQLException e) {

                     e.printStackTrace();
                     continue;
                 }
             }

         }


    static    void updateGclasses(RefSeqInfo[] info, DBAgent db) {

               String selectFromFData2  = "select distinct gid from ftype2gclass where gid not in (select distinct gid from gclass)";

               for (int i = 0; i < info.length; i++) {

                   System.out.println ("" + i  + " th database ")   ;
                   PreparedStatement stms = null;
                   ResultSet rs = null;
                   Connection con = null;
                   PreparedStatement stms1 = null;
                   Vector v = new Vector();
                   // for (int i = 0; i < 1; i++) {
                   String database = info[i].databaseName;
                   if (database == null || (database.compareTo("") == 0))
                       continue;

                  if  (database.indexOf("0f017") <=0)
                                         continue;


                   System.out.println(" !!! working with  " + database);
                   try {
                       con = db.getConnection(database);
                       if (con != null && !con.isClosed()) {
                           stms = con.prepareStatement(selectFromFData2);
                           rs = stms.executeQuery();

                           while (rs.next()) {
                               v.add(rs.getString(1));
                           }
                           rs.close();
                       }

                       stms.close();
                       con.close();

                   } catch (SQLException e) {
                      continue;
                       //e.printStackTrace();

                   }

                 //  Hashtable h = new Hashtable();


                 /*
                   if (!v.isEmpty()) {

                       System.out.println (" 222 retireving gname");
                       String sql = "select distinct groupName from genboreegroup where groupId = ? ";
                       PreparedStatement stms2 = null;
                         ResultSet rs2 = null;
                       try {
                           Connection con1 = db.getConnection("genboree");
                           if (con1 != null && !con1.isClosed()) {
                               stms2 = con1.prepareStatement(sql);
                               for (int j  = 0; j < v.size(); j++) {
                                   String id = (String) v.get(j);
                                   stms2.setString(1, id);
                                   rs2 = null;
                                 rs2 = stms2.executeQuery();

                                   while (rs2.next()) {
                                       h.put(id, rs2.getString(1));
                                   }

                               }
                           }
                           rs2.close();
                           stms2.close();
                           con1.close();
                       } catch (SQLException e) {
                          continue;

                       }
                  }
                   */


                if (!v.isEmpty()) {

                   System.out.println ("333update gclass");
                    try {
                         Connection con3 = db.getConnection(database);
                         PreparedStatement stms3 = null;
                           System.out.println ("444update gclass");
                        if (con3 != null && !con3.isClosed()) {
                                  for (int k =0; k<v.size(); k++) {
                                   String id = (String) v.get(k);
                                      String sqldel =  "delete from  gclass  where gid = '"  + id  + "'";


                                    String sql =  "insert into gclass  (gid, gclass) values ('" + id +
                                    "', 'unknown" + "_" + id + "')";
                                    System.out.println ("5555 update sql "  + sql );

                                    stms3 = con3.prepareStatement(sqldel);

                                    stms3.executeUpdate();

                                      System.out.println (sqldel);

                                      stms3 = con3.prepareStatement(sql);

                                             stms3.executeUpdate();

             }

                        stms3.close();
                        con3.close();
                    }
                    } catch (SQLException e) {
                        e.printStackTrace();
                       continue;
                    }
                }



               } // end of for loop
          }






    static  boolean inFtype2Class(Connection con, int [] ids) {
                 String sql = "select * from ftype2gclass where ftypeid = ? and gid = ? ";

        PreparedStatement stms = null;
        ResultSet rs = null;
         boolean b = false;
        try {
            if (con != null && !con.isClosed()) {
                stms = con.prepareStatement(sql);
                stms.setInt(1, ids[0]);
                stms.setInt(2, ids[1]);
                rs = stms.executeQuery();
                if (rs.next()) {
                  b = true;
                }
                rs.close();
            }
            rs.close();
            stms.close();


        } catch (SQLException e) {

            e.printStackTrace();

        }
      return b ;
    }





    static void insertClassMap(Connection con, int [] ids) {
        String sqlInsert = " insert into ftype2gclass  (ftypeid, gid) values (?, ?) ";
        PreparedStatement stms = null;

        try {
            if (con != null && !con.isClosed()) {
                stms = con.prepareStatement(sqlInsert);
                stms.setInt(1, ids[0]);
                stms.setInt(2, ids[1]);
                stms.executeUpdate();
                stms.close();
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }

    }





    public static void main (String [] args) {

        String serverName = null;
         String testdbName = "199c13";


//        if (args != null && args.length == 1)
//            testdbName = args[0];
//        else
//            testdbName = "199c13";

        if(args != null && args.length > 0 && args[0] != null)
            serverName = args[0];
        else
            serverName = "localhost";

        String tableName = "link";
        String tablesNames[] = new String[1];
        tablesNames[0] = tableName;
        DBAgent agent = DBAgent.getInstance();
        Connection con = null;
        try {
            con = agent.getConnection("genboree");
        } catch (SQLException e) {
            System.out.println("11 ");
            e.printStackTrace();
        }

        RefSeqInfo[] rs = findUploadInfo(con);
        System.out.println("num record " + rs.length);

        try {
            con.close();
        } catch (SQLException e) {
            System.out.println("2 ");
            e.printStackTrace();
        }
     populateFtype2GClassFromFeaturetogroup(rs, agent);
     populateFtype2GClassFromFdata2 (rs, agent);
     updateGclasses(rs,  agent) ;

    }
}
