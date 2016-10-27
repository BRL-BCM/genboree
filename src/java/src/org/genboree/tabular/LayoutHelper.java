package org.genboree.tabular;

import org.genboree.util.Util;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import javax.servlet.jsp.JspWriter;
import java.io.*;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.Date;

/**
 * User: tong
 * Date: Jun 14, 2007
 * Time: 5:16:19 PM
 */
public class LayoutHelper {
	public static final String DEFAULT_ALL_ANNOS = "Default All Annos.";   
	public static final String DEFAULT_GROUPED_ANNOS = "Default Grouped Annos.";   
	public static final String ALL_CHROMOSOMES = "All Chromosomes"; 
	
     
  
   
   public static void alphabeticSort (String []  arr) {
            Arrays.sort(arr, new Comparator() { 
        public int compare(Object o1, Object o2)
        {
        return (((String) o1).toLowerCase().
        compareTo(((String) o2).toLowerCase()));
        }
        }); 
    }
   
	
	public static final String JSON_DF_ALL = 
			"{\"date created\":\"Thu Oct 11 14:32:37 CDT 2007\",\"rearrange_list_1\":[[\"item_0\",\"%22Edit%22%20Link_display\",\"0\"],  " + 
		"[\"item_1\",\"Anno.%20Name_display\",\"1\"],[\"item_2\",\"Anno.%20Class_display\",\"0\"]," + 
			" [\"item_3\",\"Anno.%20Type_display\",\"1\"],[\"item_4\",\"Anno.%20Subtype_display\",\"1\"],[\"item_5\",\"Anno.%20Chr_display\",\"1\"]," 
			+"[\"item_6\",\"Anno.%20Start_display\",\"1\"],[\"item_7\",\"Anno.%20Stop_display\",\"1\"],[\"item_8\",\"Anno.%20Strand_display\",\"1\"]," + 
			"[\"item_9\",\"Anno.%20Phase_display\",\"0\"],[\"item_10\",\"Anno.%20Score_display\",\"1\"]," +
			"[\"item_11\",\"Anno.%20QStart_display\",\"0\"],[\"item_12\",\"Anno.%20QStop_display\",\"0\"]],\"user\":\"all\"," +
			"\"rearrange_list2\":[[\"sortitem_5\",\"Anno.%20Name_sort\",\"1\"],[\"sortitem_0\",\"Anno.%20Type_sort\",\"0\"]," +
			"[\"sortitem_1\",\"Anno.%20Subtype_sort\",\"0\"],[\"sortitem_2\",\"Anno.%20Chr_sort\",\"1\"],[\"sortitem_3\",\"Anno.%20Start_sort\",\"0\"]," +
			"[\"sortitem_4\",\"Anno.%20Stop_sort\",\"0\"],[\"sortitem_6\",\"Anno.%20Class_sort\",\"0\"],[\"sortitem_7\",\"Anno.%20Strand_sort\",\"0\"]," +
			"[\"sortitem_8\",\"Anno.%20Phase_sort\",\"0\"],[\"sortitem_9\",\"Anno.%20Score_sort\",\"0\"],[\"sortitem_10\",\"Anno.%20QStart_sort\",\"0\"]," +
			"[\"sortitem_11\",\"Anno.%20QStop_sort\",\"0\"]],\"groupMode\":\"none\", \"chrName\":\"All Chromosomes\"}";
	  
		public static final String JSON_DF_GROUP = 
			"{\"date created\":\"Thu Oct 11 14:32:37 CDT 2007\",\"rearrange_list_1\":[[\"item_0\",\"%22Edit%22%20Link_display\",\"0\"],  " + 
		"[\"item_1\",\"Anno.%20Name_display\",\"1\"],[\"item_2\",\"Anno.%20Class_display\",\"0\"]," + 
			" [\"item_3\",\"Anno.%20Type_display\",\"1\"],[\"item_4\",\"Anno.%20Subtype_display\",\"1\"],[\"item_5\",\"Anno.%20Chr_display\",\"1\"]," 
			+"[\"item_6\",\"Anno.%20Start_display\",\"1\"],[\"item_7\",\"Anno.%20Stop_display\",\"1\"],[\"item_8\",\"Anno.%20Strand_display\",\"1\"]," + 
			"[\"item_9\",\"Anno.%20Phase_display\",\"0\"],[\"item_10\",\"Anno.%20Score_display\",\"1\"]," +
			"[\"item_11\",\"Anno.%20QStart_display\",\"0\"],[\"item_12\",\"Anno.%20QStop_display\",\"0\"]],\"user\":\"all\"," +
			"\"rearrange_list2\":[[\"sortitem_5\",\"Anno.%20Name_sort\",\"1\"],[\"sortitem_0\",\"Anno.%20Type_sort\",\"0\"]," +
			"[\"sortitem_1\",\"Anno.%20Subtype_sort\",\"0\"],[\"sortitem_2\",\"Anno.%20Chr_sort\",\"1\"],[\"sortitem_3\",\"Anno.%20Start_sort\",\"0\"]," +
			"[\"sortitem_4\",\"Anno.%20Stop_sort\",\"0\"],[\"sortitem_6\",\"Anno.%20Class_sort\",\"0\"],[\"sortitem_7\",\"Anno.%20Strand_sort\",\"0\"]," +
			"[\"sortitem_8\",\"Anno.%20Phase_sort\",\"0\"],[\"sortitem_9\",\"Anno.%20Score_sort\",\"0\"],[\"sortitem_10\",\"Anno.%20QStart_sort\",\"0\"]," +
			"[\"sortitem_11\",\"Anno.%20QStop_sort\",\"0\"]],\"groupMode\":\"terse\", \"chrName\":\"All Chromosomes\"}";
	

	/**
       * 
        * @param path
       * @return list of file names in alphabetic order; could be null if none found
       * @throws IOException when path is invalid
       */ 
        
    public static String []  retrieveExistingConfigs (String path ) throws IOException {
            if (path == null || path.trim().length() ==0) 
            throw new IOException ("Error in LayoutHelper.retrieveExistingConfigs: invalid blank path. ");  
            String viewNames []  = null;           
            File file = new File (path); 
            if (!file.exists())
            throw new IOException ("Error in LayoutHelper.retrieveExistingConfigs: invalid path:  " + path);  
            
            viewNames = file.list(); 
            if (viewNames != null && viewNames.length >0) { 
               for (int i=0; i<viewNames.length; i++) 
                  viewNames [i] = Util.urlDecode(viewNames[i]);
                alphabeticSort(viewNames);
                
            }

        return  viewNames ;        
      }
         
    
	
	public static boolean  deleteLayout(String path, String layout, JspWriter out ) {
			  boolean success = false; 
				 if (path == null || path.trim().length() ==0) 
				 {  System.err.println ("Error in LayoutHelper: invalid blank path. ");  
				  return  false; 
				 }
			   try {
				 File file = new File (path +"/"+  Util.urlEncode(layout)); 
				 if (!file.exists())
				{ 
					 System.err.println ("Error in LayoutHelper: invalid blank path. ");  
				  return  false; 
				 }  
				success =file.delete(); 
			   }
		   catch (Exception e) {
				   e.printStackTrace();
			   }
		  
			 return success; 
		   }  
	
	
	  
	  public static void saveUserConfig (JspWriter out, String userName, String grpMode, String rootPath, String groupId, String refseqId, String fileName, JSONObject json ) {
        
             File file = null; 
              String path = rootPath + "/" + groupId   + "/"  + refseqId + "/"+ fileName; 
                
              try {
                  file = new File (path); 
                  if (!file.exists())                   
                     file = createJsonConfigFile(out, rootPath, groupId, refseqId, fileName); 
                 
                  if (file == null || !file.exists()){
                      System.err.println(" error in creating file : " +  path  ); 
                 
                  return; 
                  }
              }
              catch  (Exception e) {
                 System.err.println(" error in creating file : " + e.getMessage()); 
                  e.printStackTrace();
                  return; 
               } 
            
        
              try {
                  PrintWriter pw = new PrintWriter (new FileWriter( file));                      
                  json.put("user", userName); 
                  if (grpMode == null) 
                  grpMode = "none";  
                   json.put("groupMode", grpMode); 
                  json.put("date created", new Date().toString());             
                  JSONObject jo = new JSONObject(); 
                  jo.put (fileName, json); 
                  pw.println(json.toString() ); 
                  pw.flush();
                  pw.close();        
            }
              catch  (Exception e) {
                 System.err.println(" error in writinh json file : " + file.getAbsolutePath()); 
                  e.printStackTrace();
                  return; 
               } 
          return ;          
      }
    
	
	
	public static void saveUserConfig (JspWriter out, String chromosome, String chrStart, String chrStop,  String userName, String grpMode, String rootPath, String groupId, String refseqId, String fileName, JSONObject json ) {
        
				File file = null; 
				 String path = rootPath + "/" + groupId   + "/"  + refseqId + "/"+ fileName; 
                
				 try {
					 file = new File (path); 
					 if (!file.exists())                   
						file = createJsonConfigFile(out, rootPath, groupId, refseqId, fileName); 
                 
					 if (file == null || !file.exists()){
						 System.err.println(" error in creating file : " +  path  ); 
                 
					 return; 
					 }
				 }
				 catch  (Exception e) {
					System.err.println(" error in creating file : " + e.getMessage()); 
					 e.printStackTrace();
					 return; 
				  } 
            
        
				 try {
					 PrintWriter pw = new PrintWriter (new FileWriter( file));                      
					 json.put("user", userName); 
					 json.put("chrName", chromosome); 
					  if (chromosome != null && chromosome.indexOf ("Show All") <0) {
						  json.put("chrStart", chrStart);  
						  json.put("chrStop",  chrStop); 
					  }
					 
					 if (grpMode == null) 
					 grpMode = "none";  
					  json.put("groupMode", grpMode); 
					 json.put("date created", new Date().toString());             
					 JSONObject jo = new JSONObject(); 
					 jo.put (fileName, json); 
					 pw.println(json.toString() ); 
					 pw.flush();
					 pw.close();        
			   }
				 catch  (Exception e) {
					System.err.println(" error in writinh json file : " + file.getAbsolutePath()); 
					 e.printStackTrace();
					 return; 
				  } 
			 return ;          
		 }
    
    	
	
    
    
    
	public static  File   createJsonConfigFile (JspWriter out, String rootPath, String groupId, String refseqId, String fileName) throws Exception {      
          if (fileName == null) 
              throw new Exception (" failed in creating file for storing tabular view parameters: passed file name is null. "); 
                      
         fileName = fileName.trim(); 
        if (fileName.length() ==0) 
                   throw new Exception (" failed in creating file for storing tabular view parameters: blank file name not allowed. "); 
                  
          
          if (fileName != null) 
              fileName =Util.urlEncode(fileName) ; 
        
            
          
           File rootDir = new File (rootPath);  
           if (!rootDir.exists()) 
                  throw new Exception (" failed in creating file for storing tabular view parameters: check root directory. "); 
        
           File groupDir = new File (rootDir ,  groupId);                   
              if (!groupDir.exists()) 
              groupDir.mkdir(); 
           
           if (!groupDir.exists()) { 
             throw new Exception (" failed in creating file for storing tabular view parameters: check passed group id "); 
           }
            
           
          File dbDir = new File (groupDir, refseqId); 
          if (!dbDir.exists()){           
            dbDir.mkdir();          
          } 
           
           if (!dbDir.exists()) { 
                throw new Exception (" failed in creating file for storing tabular view parameters: check passed refseqId "); 
               }
        
              File annoFile = new File (dbDir, fileName);  
           
             if (!annoFile.exists()) 
              annoFile.createNewFile();
        
                if (!annoFile.exists()) { 
                throw new Exception (" failed in creating file for storing tabular view parameters: check passed fileName "   ); 
               }
        
            return annoFile;          
        };  
                
    
    public static JSONObject   retrievesJsonObject (String parentPath, String viewName) throws ViewRetrieveException  {      
        if (viewName == null) 
            throw new ViewRetrieveException("File path "  + parentPath + " does not exist or is not accessible." ); 
     
       viewName = viewName.trim(); 
        if (viewName.length () ==0) 
                 throw new ViewRetrieveException("File path "  + parentPath + " does not exist or is not accessible." ); 
         
        String encodedName = Util.urlEncode(viewName); 
        JSONObject json =  null; 
        File parentDir = new File (parentPath );  
        if (!parentDir.exists()) 
           throw new ViewRetrieveException("File path "  + parentPath + " does not exist or is not accessible." ); 
          
        File viewFile = new File (parentDir, encodedName); 
        if (!viewFile.exists())
                throw new ViewRetrieveException("File path "  + parentPath + "\\" + viewName +  " does not exist or is not accessible." ); 
                             
      
         String line =  null; 
         try {
            BufferedReader br = new BufferedReader (new FileReader (viewFile));   
           line =  br.readLine();         
             br.close();
            } 
        catch (IOException e) {e.printStackTrace();} 
     
   
        if (line != null) {
            try {
                json = new JSONObject(line);     
            }
            catch (Exception e) {    
                e.printStackTrace();    
            }
        }    
        return  json ;    
    }
    
    
/**
 * used to retrieve display configs or sort configs using json object created from displaySelection page  
 * this function is tailed for json object created using js function saveOrder only.
 * @param json: json object contains displayNames, sortNames, user, dated created etc.
 * @param key for retrieval 
 * @return String [] 
 * @throws JSONException
 */ 
    
public static String [] getJsonDisplay  (JSONObject json, String key) throws JSONException  {
    String [] selectedNames = null;   
  
    
   
    if (json == null || key == null) 
        throw new JSONException( "Error: passed json object is null"); 
    
    if ( key == null) 
        throw new JSONException( "Error: passed json key is null"); 
           
     try {            
        if (!json.has(key)) 
            throw new JSONException( "Error: json key  " + key + "  is not found in json object " + json.toString());    
          else  { // has key 
            JSONArray displayArray  = json.getJSONArray(key);                 
            String status = null; 
            String trackName = null;
            ArrayList list = new ArrayList ();              
            if (displayArray != null) {                
                for (int i=0; i< displayArray.length(); i++) {
                JSONArray arr = displayArray.getJSONArray(i);         
                if (arr != null && arr.length () == 3) 
                status = (String)arr.get(2);  
                if (status != null && status.equals("1")) {
                trackName = (String)arr.get(1); 
              if (trackName.indexOf("_display")>=0) 
                trackName = trackName.substring(0, trackName.length() - 8); 
                    
                    
                if (trackName != null) 
                list.add(org.genboree.util.Util.urlDecode(trackName)); 
                }
                } 
             } 
                
                if (!list.isEmpty()) 
                    selectedNames  = (String[])list.toArray(new String[list.size()]);                
            }        
   }
   catch (Exception e) {
        e.getMessage();
        e.printStackTrace();
   }
           
     return selectedNames; 
 }      
}
