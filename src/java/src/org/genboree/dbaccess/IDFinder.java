package org.genboree.dbaccess;

import java.sql.*;
import java.util.HashMap;
import java.util.Iterator;

/**
 * User: tong Date: Jun 29, 2005 Time: 9:43:09 AM
 */
public class IDFinder {


    /**
     *  a generic method to find int id from tables with String values from all columns specified
     *
     * @param databaseName
     * @param tableName
     * @param targetColumn
     * @param columnNameValue
     * @return
     * @throws IDUnfoundException
     */
    public static int findId (String databaseName, String tableName, String targetColumn,  HashMap columnNameValue) throws IDUnfoundException {
       int id = -1;
        String sql = " select " + targetColumn  + " from " + tableName + " where " ;
        String params = "";
        String whereClause = "";
        DBAgent db = DBAgent.getInstance();
        try {
            Connection con = db.getConnection(databaseName)  ;


             int i =0;
            Iterator it = columnNameValue.keySet().iterator();
             while (it.hasNext()) {
                 String key = (String)it.next();
                 String value = (String)columnNameValue.get(key);
                 sql = sql + key + " = '" + value + "' and ";
             }

            int index = sql.lastIndexOf("and");
             sql = sql.substring(0, index -1);
             System.out.println(sql);
            PreparedStatement stms = con.prepareStatement(sql);

            ResultSet rs = stms.executeQuery();
            while (rs.next())
                id = rs.getInt(1) ;
       }
        catch (SQLException e ) {
            e.printStackTrace();
        }

        if (id <0 )
           throw new IDUnfoundException (targetColumn + " id from table " + tableName + " is unfound with the parameter passed:  "  + sql  + "  " + params);

        return id;
    }


    public static int findFtypeId(Connection con, String fmethod, String fsource) {
        int id = 0;
        String sql = " select ftypeid  from  ftype where fmethod  = ? and fsource = ? ";
        try {
            PreparedStatement stms = con.prepareStatement(sql);
            stms.setString(1, fmethod);
            stms.setString(2, fsource);
            ResultSet rs = stms.executeQuery();

            if (rs.next()) {
                id = rs.getInt(1);
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }

        return id;
    }



    public static int getNewFtypeId (String fmethod, String fsource, String dbName) {
          String sqlInsert = " insert into ftype (fmethod, fsource) values (?, ?) " ;
          String sqlSelect = "select last_insert_id()";
          int id = 0;
        try {
           Connection con = DBAgent.getInstance().getConnection(dbName);
             PreparedStatement stms = con.prepareStatement(sqlInsert);
             stms.setString(1, fmethod);
             stms.setString(2, fsource);
             stms.executeUpdate() ;


              Statement stmt = con.createStatement();
                ResultSet rs = stmt.executeQuery( "SELECT LAST_INSERT_ID()" );

            if (rs.next())
                id = rs.getInt(1);
            rs.close();
            stmt.close();
            stms.close();

        } catch (SQLException e) {e.printStackTrace();}
        return id;


        }

    public static int findUploadID (Connection con, String refseqId, String databaseName)  throws IDUnfoundException{
           int uploadID = -1;
           String sql = "SELECT uploadId  FROM upload " +
                   " WHERE databaseName= '" + databaseName + "' and  " +
                   " refSeqId= " + refseqId;

           if (con == null  || refseqId == null)
               throw new IDUnfoundException ( " refseq id  " + refseqId + " is invalid  or database connection is not established");

           try {

               PreparedStatement stms = con.prepareStatement(sql) ;
               ResultSet rs = stms.executeQuery();
               while (rs.next()){
                       uploadID = rs.getInt(1);
               }
               rs.close();
               stms.close();

               }
           catch (SQLException e) {
               e.printStackTrace();
           }

          if (uploadID <0)  throw new IDUnfoundException (
          sql + " upload ID for refseq id  " + refseqId + " database " + databaseName + " is  " + uploadID   );

           return uploadID;
       }


    /** for testing purpose only */

 public static void main (String args [] ) {
     DBAgent db = DBAgent.getInstance();
     String databaseName = "genboree_r_0f017cf20579fc9d442bfb7227ef3a4c";
     String tableName = "ftype";
     String targetColumn = "ftypeId";
     HashMap h = new HashMap ();
     h.put("fmethod", "Gene");
     h.put("fsource", "RefSeq");

     int id = 0;
     try {
         id = findId(databaseName, tableName, targetColumn, h);
         System.out.println("id = " + id );
     }
     catch (IDUnfoundException e) {
         System.out.println (e.getMessage());
         e.printStackTrace();
     }


 }



}
