package org.genboree.manager.tracks;

import org.genboree.dbaccess.DbGclass;
import org.genboree.message.GenboreeMessage;

import javax.servlet.http.HttpSession;
import java.sql.Connection;
import java.util.ArrayList;

// todo: release

/**
 * User: tong Date: Mar 30, 2006 Time: 10:24:15 AM
 * class created for new class creation
 * can be converted to new custom tag if extend tagSupport
 * @version 1.0
 */
public class ClassCreator  {
    
    /**
     * a simple function for creating a class in local databse 
     * @param className
     * @param mys 
     * @param con  
     * @return
     */ 
    
    public static DbGclass  createClass(String className, HttpSession mys,   Connection con) {
    boolean success = false;
       DbGclass gclass = null;
        if (!ClassManager.inGclass(className, con)) {
                if (className.compareToIgnoreCase("Chromosome") == 0 || className.compareToIgnoreCase("Sequence") == 0) {
                    GenboreeMessage.setErrMsg(mys, "Chromosome and Sequence are reserved. Please choose a different class name.");
                    return null;
                }  
                else {
                   gclass = new DbGclass();
                    gclass.setGclass(className);
                    gclass.setLocal(true);
                    try {                 
                        int id = ClassManager.insertGclass(con, className);
                        if (id > 0) {
                        gclass.setGid(id);                   
                        success = true;                                
                        }
                        else {
                            String[] errs = new String[2];
                            errs[0] = " happend in updating database for new class creation";
                            errs[1] = " error in gclass.insert";                
                            mys.setAttribute("lastError", errs);
                             return null;
                        } 
                    }
                    catch (Exception e) {
                    e.printStackTrace();
                    }
                }
          }
        else {
            ArrayList   errlist = new ArrayList();
            errlist.add("Class \"" + className + "\" already exists. Please choose a different class name.");        
            GenboreeMessage.setErrMsg(mys, "The creation of new annotation class failed:", errlist);        
        }

        if (success) {
            GenboreeMessage.setSuccessMsg(mys, " The new class was created successfully.");
        }
    
    return gclass ;
}
}
