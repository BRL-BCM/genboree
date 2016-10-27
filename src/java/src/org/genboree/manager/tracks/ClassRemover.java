package org.genboree.manager.tracks;

import org.genboree.message.GenboreeMessage;

import javax.servlet.http.HttpSession;
import javax.servlet.jsp.JspWriter;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.Statement;
import java.util.ArrayList;

/**
 * User: tong Date: Mar 30, 2006 Time: 10:51:11 AM
 * @version 1.0
 *
 */
public class ClassRemover   {

    public static void   deleteClass (HttpSession mys,  String [] classids, Connection con, JspWriter out) {   
    
        if (classids == null || classids.length <1) 
        return; 
          
        // delete classes  from gclasses 
        int rc = deleteClasses(classids, con);         
        if (rc==classids.length) {
            ArrayList list = new ArrayList();
            String be = rc>1? "  classes were" : "  class was";
            list.add("" + rc  + be + " deleted" );
            GenboreeMessage.setSuccessMsg(mys, "The delete operation was successful", list);         
        }
         return;
    }
       
/**
 *  deletes a class from gclass table 
  * @param gclassName
 * @param con 
 * @return
 */  
  
    public static boolean  deleteClass(String gclassName,  Connection con) {
          boolean success = false;
          if (gclassName == null) {
              System.err.println("null  className  passed to  trackClassify.jsp. delete Class ");
              return false;
          }       
          try {
              String sql = "delete from gclass where gclass = ? " ; 
              PreparedStatement stms  = con.prepareStatement(sql);
              stms.setString(1, gclassName);
              int rc = stms.executeUpdate();
              success = rc>0 ? true:false;       
              stms.close();
          }
          catch (Exception e) {      
          System.err.println("SQL error in ClassRemover.deleteClass Class ");
           e.printStackTrace();
          }       
          return success;
      }
   
    
    /**
     * deletes array of classes 
     * @param gclassids
     */ 
    public static int deleteClasses(String[] gclassids,Connection con) {
        int rc = -1; 
        if (gclassids == null || gclassids.length <= 0)
        return -1;
        try {
        String ids = ""; 
        Statement stms = null;         
        for (int i=0; i<gclassids.length-1; i++) {
            ids = ids + gclassids[i] + ", ";             
        }
        ids = ids + gclassids[gclassids.length -1];  
        String sql = "delete from gclass where gid in (" +ids +  ")";          
        stms = con.createStatement();             
         rc = stms.executeUpdate(sql);        
        stms.close();
        } 
        catch (Exception e) {
            e.printStackTrace();        
        }
        return rc; 
      }
}
