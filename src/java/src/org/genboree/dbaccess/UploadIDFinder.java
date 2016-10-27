package org.genboree.dbaccess;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.ResultSet;

/**
 * Created by IntelliJ IDEA. User: tong Date: Jun 12, 2005 Time: 10:55:01 PM To change this template use File | Settings
 * | File Templates.
 */
public class UploadIDFinder{

    public static int findUploadID (int refseqId, String dbName )  throws IDUnfoundException{
        int uploadID = -1;
        String sql = "SELECT uploadId  FROM upload " +
                " WHERE databaseName= '" + dbName + "' and  " +
                " refSeqId= " + refseqId;
        Connection con = null;
        try {
            con = DBAgent.getInstance().getConnection("genboree");
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
       sql + " upload ID for refseq id  " + refseqId + " database " + dbName + " is  " + uploadID   );

        return uploadID;
    }

        public static String  findDBName (int uploadid )  throws IDUnfoundException{

        String sql = "SELECT databaseName  FROM upload " +
                " where uploadId = ? " ;
        Connection con = null;
        String dbName = null;
        try {
            con = DBAgent.getInstance().getConnection("genboree");

            PreparedStatement stms = con.prepareStatement(sql) ;
            stms.setInt(1, uploadid);
            ResultSet rs = stms.executeQuery();
            while (rs.next()){
                     dbName  = rs.getString(1);
            }
            rs.close();
            stms.close();

            }
        catch (SQLException e) {
            e.printStackTrace();
        }


       if (dbName== null)  throw new IDUnfoundException (
                  sql + " no databaseName was found for upload ID " +uploadid  );
         

        return dbName;

    }

    public static void main (String [] args) {
        try {
        System.out.println("" + findUploadID(319, "genboree_r_a1b781df4cea94a00143fe23ca66284d"));;
        }
        catch (Exception e) {}

    }


}
