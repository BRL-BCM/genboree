package org.genboree.dbaccess;

import java.sql.Connection;
import java.sql.DriverManager;

/**
 * Created by IntelliJ IDEA. User: tong Date: Jun 9, 2005 Time: 5:10:32 PM To change this template use File | Settings |
 * File Templates.
 */
public class DBConnector {

    /**
     * making connection using server params
     * @param serverName
     * @param dbName
     * @return
     */

     public static  Connection makeConnection(String serverName, String dbName) {

         Connection con = null;

         String userName = "genboree";
         String passwd = "Gnb0r33";
         String dbUrl = "jdbc:mysql://" + serverName + "/" + dbName;

         try {
             Class.forName("com.mysql.jdbc.Driver").newInstance();
             con = DriverManager.getConnection(dbUrl, userName, passwd);
             if (con.isClosed())
                 System.err.println(" failed making connection to server: " + serverName + "\t database: " + dbName);

         } catch (Exception ex) {
             ex.printStackTrace();
         }


         return con;

     }


}
