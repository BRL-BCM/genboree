package org.genboree.manager.tracks;
import org.genboree.dbaccess.DbGclass;
import org.genboree.message.GenboreeMessage;

import javax.servlet.http.HttpSession;
import java.sql.Connection;
import java.util.ArrayList;

/**
 * User: tong Date: Mar 29, 2006 Time: 5:09:26 PM
 * created for class rename
 * can be converted to new tag by extending tag support with changes
 * @version  1.0
 */
public class ClassRenamer  {
    public static  DbGclass  renameClass( String newClassName, HttpSession mys,  Connection con,  DbGclass editingClass, DbGclass[] gclasses,  String editClassName) {
        ArrayList errlist = new ArrayList();
        boolean success = false; 
        boolean inclass =  ClassManager.inGclass(newClassName, con); 
        if (!inclass) {
        //  if old Name exist, update  else insert 
            if (!ClassManager.inGclass(editClassName, con)) {
                int id = ClassManager.insertGclass(con, newClassName);
                if (id > 0) {
                    editingClass.setGid(id);
                    editingClass.setGclass(newClassName);
                    editingClass.setLocal(true);       
                    mys.removeAttribute("editingClass");
                    mys.setAttribute("editingClass", editingClass);       
                    success = true;                               
                }            
            }
            else  {// is local class
                ClassManager.updateClass(editingClass.getGid(), newClassName, con);
                editingClass.setGclass(newClassName);
                mys.removeAttribute("editingClass");
                mys.setAttribute("editingClass", editingClass);
                // the following code is commented off based on the eamil from Manuel and Andrew
                // on  Fri, 10 Feb 2006 10:20:20 -0600
                
                //if (newName != null && editClassName != null)
                //if (info.isHasSubordinateDB()) {
                //SubOrdinateDBManager.updateClass(info.getSubdbNames(), editClassName, newName);
                //}
                success = true;               
            }
        }
        else {
            errlist = new ArrayList();
            errlist.add("Class \"" + newClassName  +"\" already exists.");
            // errlist.add("Please choose a different class names.");
            GenboreeMessage.setErrMsg(mys, "The rename operation failed:", errlist);
            return editingClass;
        }       
        if (success) {
            GenboreeMessage.setSuccessMsg(mys, "Class \"" + editClassName + "\" was renamed successfully.");
        }
        return editingClass;
    }
   
}
