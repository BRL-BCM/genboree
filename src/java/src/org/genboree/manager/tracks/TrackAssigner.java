package org.genboree.manager.tracks;

import org.genboree.dbaccess.DBAgent;
import org.genboree.dbaccess.DbFtype;
import org.genboree.dbaccess.DbGclass;
import org.genboree.message.GenboreeMessage;
import org.genboree.util.GenboreeUtils;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;
import javax.servlet.jsp.JspWriter;
import java.sql.*;
import java.util.ArrayList;
import java.util.HashMap;

/**
 * User: tong Date: Mar 30, 2006 Time: 11:40:18 AM
 */
public class TrackAssigner  {
   
    public static void assignTracks(DBAgent db, String [] shareddbNames, ArrayList selectedTrackNames, DbFtype [] selectedTracks, HttpSession mys, HttpServletRequest request, HttpServletResponse response,  Connection con , String dbName,  DbFtype[] tracks, DbGclass editingClass, DbGclass[] gclasses,  JspWriter out ) {   
        boolean selectedNothing = false; 
        boolean isOK2Map = false; 
 try{
        // Step 1:   upcate gclass : if not in local db, insert new class
        if (editingClass != null && !editingClass.isLocal() ) 
            editingClass = ClassManager.updateGclass(editingClass, con);

            
         if (selectedTrackNames.isEmpty())
            selectedNothing = true; 
        
        //step 2: assign: case 1: no tracks in db     
        if ( tracks == null || tracks.length <1)  {
            ArrayList list = new ArrayList();
            list.add("No tracks are available for assignment");
            GenboreeMessage.setErrMsg(mys, "The assign operation failed:", list) ;
        }
        // case 2: no classes in db 
        else if (gclasses == null || gclasses.length<1 )  {
            ArrayList list = new ArrayList();
            list.add("No classes are available for assignment");
            GenboreeMessage.setErrMsg(mys, "The assign operation failed:", list);
        }
            // case 3:  remove all local mapping 
        else if (selectedNothing && editingClass != null) {
            isOK2Map = true; 
           // delete class mapping if nothing selected 
            ClassManager.deleteClassMappingByName(editingClass.getGclass(), con) ;
             ArrayList  sharedClassTracks = retrieveClassTracks (db, shareddbNames, editingClass, out); 
            ArrayList list = new ArrayList();
            if (sharedClassTracks != null) {  
                selectedTrackNames = sharedClassTracks;
                for (int i=0; i<selectedTrackNames.size(); i++) 
                        list.add("<font color=\"red\">Note: \"" + selectedTrackNames.get(i) + "\" can not be removed from class \"" + editingClass.getGclass() + "\" because it is from the genome template.<font>");                                            
             }
            else
                list.add("Class \"" + editingClass.getGclass() + "\" contains no tracks now");
            GenboreeMessage.setSuccessMsg(mys, "The assign operation was successful", list);
        }
       else { // case 4 : normal assignment 
                  isOK2Map = true;     
        
            ArrayList  sharedClassTracks = retrieveClassTracks (db, shareddbNames, editingClass, out); 
                      
                  // copy shared tracks to local if not alreay exist 
                    for (int j=0; j<selectedTracks.length; j++) {
                        String tempdbName = selectedTracks[j].getDatabaseName();
                        if (tempdbName != null && tempdbName.compareToIgnoreCase(dbName) ==0)
                            continue;
                        else  {
                            if (selectedTracks[j].insert(con)){
                                selectedTracks[j].setDatabaseName(dbName);
                            }
                            else {
                                String [] errs = new String [2];
                                errs[0]= " happend in updating database for new track creation";
                                errs[1] = " error in Dbftye.insert";
                                GenboreeUtils.sendRedirect(request,response, "/java-bin/error.jsp");
                            }
                        }
                    }

                // update class Mapping:: real assign 
                    if (ClassManager.updateTrackMap(con, selectedTracks, editingClass.getGid()))  {
                           ArrayList list = new ArrayList();
                           String be = selectedTracks.length >1 ? "  tracks were ": "  track was";
                           list.add("" + selectedTracks.length +  be + " assigned to class \"" +  editingClass.getGclass() + "\"");
    
                        // in case a track is removed from local mapping, 
                        // mapping from shared database is still displayed
                            if (sharedClassTracks != null) {
                           
                                for (int i=0; i<sharedClassTracks.size() ; i++) {
                                    String trackName = (String )sharedClassTracks.get(i);
                                    if (!selectedTrackNames.contains(trackName)) {                       
                                        list.add("<font color=\"red\">Note: \"" + trackName + "\" can not be removed from class \"" + editingClass.getGclass() + "\" because it is from the genome template.<font>");                         
                                        selectedTrackNames.add(trackName);
                                    }
                                }    
                                mys.removeAttribute("selectedTrackNames");
                                mys.setAttribute("selectedTracks",selectedTrackNames);
                            }   
                         GenboreeMessage.setSuccessMsg(mys, " The assign operation was successful",list);
                    }  
        }  
 }
        catch (Exception e) {}
       
         }

      
      public static DbFtype [] findEmptyTracks (JspWriter out, boolean isOK2Map,ArrayList selectedTrackNameList,  ArrayList currentSelectedTrackNameList, DbGclass editingClass, HashMap name2Track, Connection con, String [] shareddbNames, DBAgent db) {
  
        DbFtype []  emptyTracks = null;         
        // 2.1 get empty track Name List 
       if (isOK2Map) {
         ArrayList emptyTrackNames = new ArrayList (); 
           
         for (int i=0; i<selectedTrackNameList.size(); i++) {
             String trackName = (String)selectedTrackNameList.get(i);
            if (selectedTrackNameList.contains(trackName) && currentSelectedTrackNameList.contains(trackName) ){      
                continue;            
            }
            else{                
              DbFtype ft = (DbFtype)name2Track.get(trackName);   
              if (!hasOtherClasses (out, con, shareddbNames, db, ft, editingClass)) 
                 emptyTrackNames.add(trackName);    
            }              
         }
        
         
        if (emptyTrackNames.isEmpty()) 
           return null; 
       // 2.2get empty local tracks 
            ArrayList emptyTrackList = new ArrayList();
            if ( !emptyTrackNames.isEmpty()) {  
                for (int i = 0; i < emptyTrackNames.size(); i++) {
                    String key = (String) emptyTrackNames.get(i);         
                    if (name2Track.get(key) != null)
                      emptyTrackList.add(name2Track.get(key));
                }
            }
           emptyTracks = (DbFtype[]) emptyTrackList.toArray(new DbFtype[emptyTrackList.size()]);      
       } 
          return emptyTracks;  
      
 }
  
    
    public static boolean hasOtherClasses (JspWriter out, Connection con,  String[] dbNames, DBAgent db, DbFtype ft,  DbGclass g){
         boolean b = false; 
            if( g == null || db == null)
           return true;    
     
           try{
                  
              
               String  sql = "select distinct  g.gclass  from ftype f, ftype2gclass fg, gclass g " +
                   " where f.fmethod =  ? and f.fsource = ? and fg.ftypeid = f.ftypeid and fg.gid = g.gid and g.gclass != ? ";
                   PreparedStatement stms = con.prepareStatement(sql);
                   stms.setString(1, ft.getFmethod()) ;
                   stms.setString(2, ft.getFsource());  
                  stms.setString(3, g.getGclass());
                   ResultSet rs = stms.executeQuery();
                   if (rs.next()){
                     b = true; 
                   }
          
                 rs.close();
                 stms.close();
             
             if (!b && dbNames != null)  {   
                 for(int i = 0; i < dbNames.length; i++){                 
                     sql = "select distinct  g.gclass  from ftype f, ftype2gclass fg, gclass g " +
                                    " where f.fmethod =  ? and f.fsource = ? and fg.ftypeid = f.ftypeid and fg.gid = g.gid ";
                              
                     Connection scon = db.getConnection(dbNames[i]);
                     PreparedStatement stms2 = scon.prepareStatement(sql);
                     stms2.setString(1, ft.getFmethod()) ;
                   stms2.setString(2, ft.getFsource());  
                
                   ResultSet rs2 = stms2.executeQuery();
                   if (rs2.next()){
                     b = true; 
                   } 
                     
                        rs2.close();
                 stms2.close();
             if (b ) {        
                 break;                
             }
               
                 }       
           }}
           catch(Exception e){
                e.printStackTrace();        
           }       
           return b;
       }
       
   
   
   
    public static ArrayList  updateClassMapping  (boolean isOK2Map, JspWriter out,ArrayList currentSelectedTrackNameList, DbGclass editingClass, String [] shareddbNames, DBAgent db) {
    if (!isOK2Map) 
     return  currentSelectedTrackNameList;    
        if(shareddbNames == null ||  editingClass== null || db == null)
        return  currentSelectedTrackNameList;    
      
        
        ArrayList sharedTracks = retrieveClassTracks (db, shareddbNames, editingClass, out); 
  
        if (sharedTracks != null && !sharedTracks.isEmpty()) {
            for (int i=0; i<sharedTracks.size(); i++) 
            {
                String trackName = (String)sharedTracks.get(i);  
                if (!currentSelectedTrackNameList.contains(trackName)) 
                    currentSelectedTrackNameList.add(trackName);                
            }            
        }
        
           return currentSelectedTrackNameList;          
    }      
   
   
   
    public static ArrayList  retrieveClassTracks (DBAgent db, String[] dbNames,  DbGclass g, JspWriter out){
        ArrayList trackNames  = new ArrayList(); 
        if(dbNames == null ||  g == null || db == null)
        return trackNames;    
        String dbName = null;      
        try{
            for(int i = 0; i < dbNames.length; i++){
                Connection sharedCon = null;       
                dbName = dbNames[i];
                sharedCon = db.getConnection(dbNames[i]);
                if(sharedCon == null || sharedCon.isClosed())
                 continue;              
                           
                String  sql = "select f.fmethod, f.fsource from ftype f, ftype2gclass fg, gclass g " +
                " where g.gclass = ? and  fg.gid =  g.gid  and fg.ftypeid = f.ftypeid ";
               // out.println(sql + g.getGclass());
                PreparedStatement stms = sharedCon.prepareStatement(sql);
                stms.setString(1, g.getGclass()) ;
                ResultSet rs = stms.executeQuery();
                while(rs.next()){
                    String fm = rs.getString(1);
                    String fs = rs.getString(2);
                    if (!trackNames.contains(fm + ":" + fs)) 
                    trackNames.add(fm + ":" + fs);
                }
                rs.close();
                stms.close();  
            }         
        }
        catch(Exception e){
        System.err.println(e.getMessage() + ": sql error happened in ClassManager.retrieveClassTracksk()<br>" + " in db: " + dbName);
        e.printStackTrace();        
        }       
        return trackNames;
    }
    
      public static ArrayList  findLocalEmptyTracks (Connection con){ 
     
           ArrayList trackList = new ArrayList (); 
          String  sql = "select distinct fg.ftypeid from ftype2gclass fg, ftype ft  "+
                  " where ft.ftypeid = fg.ftypeid";
              try {  
                       ArrayList list = new ArrayList (); 
                PreparedStatement stms = con.prepareStatement(sql);            
                ResultSet rs = stms.executeQuery();
                while(rs.next()){
                  list.add(rs.getString(1)); 
                }
                stms.close();  
                if (list == null) 
                     sql = "select distinct  fmethod, fsource from ftype  " ;
               else {
                    String ids = ""; 
                    for  (int i=0; i<list.size() -1; i++)                
                       ids = ids + (String)list.get(i) + ", ";  
                    
                    ids = ids + (String)list.get(list.size()-1);  
                    
                    sql = "select distinct fmethod, fsource from ftype  " +
                    " where ftypeid not in (" + ids +  ")";   
                }
              
               
                Statement stms1 = con.createStatement();            
                rs = stms1.executeQuery(sql);
                while(rs.next()){
                  trackList.add(rs.getString(1) + ":" + rs.getString(2)); 
                }               
                rs.close();
                stms1.close();  
              } catch (SQLException e) {
                  e.printStackTrace();
              } 
          
         return trackList;  
      } 
    
       public static ArrayList  findSharedEmptyTracks (String [] shareddbNames, DBAgent db ){ 
          
            ArrayList trackList = new ArrayList ();
            if (shareddbNames == null || shareddbNames.length ==0) 
              return trackList; 
          String  sql = "select distinct fg.ftypeid from ftype2gclass fg, ftype ft  "+
                  " where ft.ftypeid = fg.ftypeid";
           for (int i=0; i<shareddbNames.length;  i++) {        
              try {  
                ArrayList list = new ArrayList (); 
                Connection scon = db.getConnection(shareddbNames[i]) ; 
                PreparedStatement stms = scon.prepareStatement(sql);            
                ResultSet rs = stms.executeQuery();
                while(rs.next()){
                  list.add(rs.getString(1)); 
                }
                stms.close(); 
                  
                if (list == null) 
                     sql = "select distinct  fmethod, fsource from ftype  " ;
               else {
                    String ids = ""; 
                    for  (int j=0; j<list.size() -1; j++)                
                       ids = ids + (String)list.get(j) + ", ";  
                    
                    ids = ids + (String)list.get(list.size()-1);  
                    
                    sql = "select distinct fmethod, fsource from ftype  " +
                    " where ftypeid not in ('" + ids +  "')";   
                }
                
               
                Statement stms1 = scon.createStatement();            
                rs = stms.executeQuery(sql);
                while(rs.next()){
                    String trackName =   rs.getString(1) + ":" + rs.getString(2);
                    if (!trackList.contains(trackName)) 
                  trackList.add(trackName); 
                }               
                rs.close();
                stms1.close();  
              } catch (Exception e) {} 
       } 
         return trackList;  
      } 
    
}