package org.genboree.tabular;
import org.genboree.editor.AnnotationDetail;
import org.genboree.manager.tracks.Utility;

import javax.servlet.jsp.JspWriter;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
/**
* User: tong
* Date: Jan 3, 2007
* Time: 1:53:04 PM
*/
public class AttributeRetriever {

/**
* retrieves all attribute names from table  saAttName
* @param con
* @return String [] of attribute names; null if none is found 
*/

public static int countAVPAssociation (Connection con, int [] ftypeids, int limit, int numAnnos, JspWriter out) {
        int count =0; 
        
        if (numAnnos <=0) 
          return 0; 
        
        int i=0; int j=0; 
        
         int [] fids = AttributeRetriever.retrieveFidByFtypeids(con, ftypeids, numAnnos);
              if (fids == null || fids.length ==0) 
                return 0; 
	
	PreparedStatement stms = null;  
		 ResultSet rs = null; 
         
	String  sql =   "select count(*) from fid2attribute where fid in (" + LffConstants.Q1000 + ") ";
           
      	
		 try {            
       int [][] arr = LffUtility.getFidArrays (fids, 1000); 
                stms = con.prepareStatement(sql);
              for ( i=0; i<arr.length; i++) {
               for ( j=0; j<1000; j++) 
                   stms.setInt(j+1,  arr[i][j] );
                rs = stms.executeQuery(); 
                if (rs.next()) 
                  count += rs.getInt(1); 
                if (count > limit) 
                    break;
              
            }
        
		arr = null; 
			 
			if (rs != null)  
				rs.close();             
             stms.close();
           
        }
        catch (Exception e) {
         e.printStackTrace(); 
          
        }
	
	   finally {
	       fids = null; 
	    
       }
        
		return count; 
    }
 

	public static int countAVPAssociationByChromosomeRegion  (Connection con, int [] ftypeids, int limit, int numAnnos, int rid, long start, long stop,  JspWriter out) {
		int count =0; 
		
		if (numAnnos <=0) 
		return 0; 
		
		int i=0; int j=0; 
		
		String  [] fids = AnnotationRetriever.retrieveFidByChromosomeFtypeids(con, ftypeids, rid, start, stop);
		if (fids == null || fids.length ==0) 
		return 0; 
		PreparedStatement stms = null;  
		ResultSet rs = null; 
		
		String  sql =   "select count(*) from fid2attribute where fid in (" + LffConstants.Q1000 + ") ";
		 try {
		   String [][] arr = LffUtility.getFidArrays (fids, 1000); 
            
						stms = con.prepareStatement(sql);
				  for ( i=0; i<arr.length; i++) {
				   for ( j=0; j<1000; j++) 
					   stms.setString(j+1,  arr[i][j] );
					rs = stms.executeQuery(); 
					if (rs.next()) 
					  count += rs.getInt(1); 
					if (count > limit) 
						break;
              
				}              
				if (rs != null) 
				rs.close(); 
				stms.close();
			 arr = null; 
           
			}
			catch (Exception e) {
			 e.printStackTrace();           
			}
		   finally {
				sql = null; 
				fids = null; 		 	 
			 }
        
			return count; 
		}
 
	
	
	
	
	

	public  static String [] retrievesAttributeNames (Connection con, int [] ftypeids) {
       if (ftypeids == null || ftypeids.length ==0) 
         return null; 
       
        String  [] attributeNames = null; 
        HashMap map = new HashMap (); 
          String sql = "select attNameId,  name from attNames"; 
		   PreparedStatement stms = null; 
		 ResultSet rs = null; 
		try {
             stms = con.prepareStatement(sql);   
             rs = stms.executeQuery();          
            while (rs.next())              
                map.put(rs.getString(1),rs.getString(2)); 
            
			if (rs != null) 
			rs.close(); 
          if (stms != null) 
            stms.close();                           
        }
        catch (SQLException e) {
            e.printStackTrace();
        }
		
		     String quote = "'"; 
		 String comma = ","; 
		
		StringBuffer  ftypeBuffer  =  new StringBuffer ("");    
				 for (int i=0; i<ftypeids.length; i++){ 
					 ftypeBuffer.append (quote);  
					 ftypeBuffer.append(ftypeids[i]);
					 ftypeBuffer.append(quote); 
					 if (i<ftypeids.length-1) 
					 ftypeBuffer.append(comma);  
				 }
            
		  		
	 sql = "select distinct attNameId from ftype2attributeName where ftypeid in (" +ftypeBuffer.toString() +") ";
       			
		
		ArrayList list = new ArrayList (); 
         try {
                
           
             stms = con.prepareStatement(sql);   
            rs = stms.executeQuery();                       
           String id = null; 
            while (rs.next()){    
                id = rs.getString(1);
                
                if (id != null) 
                id = id.trim();
                
                if (id != null && id.length() >0)                 
                list.add(rs.getString(1));   
            }
			 
			if (rs != null)  
			rs.close(); 
            if (stms != null)
			 stms.close();                           
        }
        catch (SQLException e) {
        e.printStackTrace();
        }
    
    
    ArrayList   validNameList = new ArrayList (); 
                   String id =  null; 
        if (list.size() >0 ) {            
            for (int i=0; i<list.size(); i++) {  
                  id =  null; 
                 if (list.get(i) != null)
                 id = (String) list.get(i);
                if (id != null && map.get(id) != null) 
                     validNameList.add((String)map.get(id));             
            }                     
        } 
		
		
	if (!validNameList.isEmpty()) 
       attributeNames = (String []) validNameList.toArray(new String [validNameList.size()] );
    
		validNameList = null; 
		list = null; 
		map = null; 
		
		return attributeNames;
    } 

	public static String [][] retrieveFidAtt(Connection con,  int [] ftypeids, String sortName) {
	
	   if(ftypeids == null || ftypeids.length ==0) 
	   {
		  
		   System.err.println ("  AttributeRetriver.retrieveFidAtt:  passed ftype id is null "); 
		   return null;             
	   }
        
		   ArrayList list = new ArrayList ();     
		String ftypeidString = "";   
        for (int i=0; i<ftypeids.length -1; i++) 
        ftypeidString = ftypeidString + "'" +  ftypeids[i] + "', ";  
        ftypeidString = ftypeidString + "'" +  ftypeids[ftypeids.length-1] + "'";   
		
		
		String sql =   "SELECT fid   FROM  fdata2 WHERE  ftypeid in (" +  ftypeidString  +  " ) ";
        String arr[] =  new String [1]; 
        if (sortName != null) {
        sql = "SELECT fid, " +  sortName  + 
        "  FROM  fdata2 WHERE  ftypeid in (" +  ftypeidString  +  " ) ";
        sql =  sql + "  order by " + sortName ;
        }
        
        try {
			PreparedStatement stms = con.prepareStatement(sql);              
			ResultSet rs = stms.executeQuery();   
			int i=0; 
			if (sortName == null) {
				while (rs.next()) { 
					arr = new String [2];   
					arr[0] = rs.getString(1);  
					list.add(arr);  
				}
			}
			else {
				while (rs.next()) { 
					arr = new String [2];   
					arr[0] = rs.getString(1);
					arr[1] = rs.getString(2) ; 
					list.add(arr);  
				}    
			}    
			rs.close();
			stms.close();
        }
        catch (Exception e) {
        e.printStackTrace();
        }
		
		String temp [][]  = (String [][])list.toArray(new String [list.size()][2]);
		     list = null;
		ftypeidString = null; 
		sql = null; 
		return  temp;
    } 

public static String [][] retrieveNonSortFidAtt(Connection con,  int [] ftypeids,  int count) {
    if(ftypeids == null || ftypeids.length ==0) 
    return null; 
    
    String ftypeidString = "";   
    for (int i=0; i<ftypeids.length -1; i++) 
        ftypeidString = ftypeidString + "'" +  ftypeids[i] + "', ";  
    ftypeidString = ftypeidString + "'" +  ftypeids[ftypeids.length-1] + "'";     
    
    String sql =   "SELECT fid   FROM  fdata2 WHERE  ftypeid in (" +  ftypeidString  +  " ) ";
    
    String [][] fidatt = new String [count][1]; 
    try {     
        PreparedStatement stms = con.prepareStatement(sql);              
        ResultSet rs = stms.executeQuery();   
        int i=0;             
        while (rs.next()) {   
         fidatt[i]= new String [1]; 
            fidatt[i][0] = rs.getString(1);  
            i++; 
        }  
        rs.close();
        stms.close();
    }
    catch (Exception e) {
    e.printStackTrace();
    }
	
	ftypeidString = null; 
		sql = null; 
	return fidatt;
} 

    public static String [][] retrieveFidAtt(Connection con,  int [] ftypeids) {
    ArrayList list = new ArrayList ();     
    if(ftypeids == null || ftypeids.length ==0) 
    return null; 
    String ftypeidString = "";   
    for (int i=0; i<ftypeids.length -1; i++) 
    ftypeidString = ftypeidString + "'" +  ftypeids[i] + "', ";  
    ftypeidString = ftypeidString + "'" +  ftypeids[ftypeids.length-1] + "'";     
    String sql =   "SELECT fid   FROM  fdata2 WHERE  ftypeid in (" +  ftypeidString  +  " ) ";
    String arr[] =  new String [1]; 
    try {       
    PreparedStatement stms = con.prepareStatement(sql);              
    ResultSet rs = stms.executeQuery();   
    while (rs.next()) { 
    arr = new String [2];   
    arr[0] = rs.getString(1);  
    list.add(arr); 
		
	}
    rs.close();
    stms.close();
    }
    catch (Exception e) {
    e.printStackTrace();
    }
		arr = null; 
		
		ftypeidString = null; 
		sql = null; 
	
			String temp [][]  = (String [][])list.toArray(new String [list.size()][2]);
		     list = null;
		ftypeidString = null; 
		sql = null; 
		return  temp;
		
    } 

        public static String [] retrieveFidByFtypeids(Connection con,  int [] ftypeids) {
            ArrayList list = new ArrayList ();     
            if(ftypeids == null || ftypeids.length ==0) 
            return null;               
            String ftypeidString = "";   
            for (int i=0; i<ftypeids.length -1; i++) 
            ftypeidString = ftypeidString + "'" +  ftypeids[i] + "', ";  
            ftypeidString = ftypeidString + "'" +  ftypeids[ftypeids.length-1] + "'";     
            String sql = "SELECT fid  FROM  fdata2 WHERE  ftypeid in (" +  ftypeidString  +  " ) ";
            try {     
            PreparedStatement stms = con.prepareStatement(sql);              
            ResultSet rs = stms.executeQuery();   
            while (rs.next()) { 
            list.add(rs.getString(1));  
            }
            rs.close();
            stms.close();
            }
            catch (Exception e) {
            e.printStackTrace();
            }
			

			String temp []  = (String [])list.toArray(new String [list.size()]);
		     list = null;
		ftypeidString = null; 
		sql = null; 
		return  temp;
					

        } 

    public static int[] retrieveFidByFtypeids(Connection con,  int [] ftypeids, int count) {
    if(ftypeids == null || ftypeids.length ==0) 
    return null; 
    String ftypeidString = "";   
    for (int i=0; i<ftypeids.length -1; i++) 
    ftypeidString = ftypeidString + "'" +  ftypeids[i] + "', ";  
    ftypeidString = ftypeidString + "'" +  ftypeids[ftypeids.length-1] + "'";     
    String sql =   "SELECT fid   FROM  fdata2 WHERE  ftypeid in (" +  ftypeidString  +  " ) ";
    int annos[] = new int [count]; 
    try {     
    PreparedStatement stms = con.prepareStatement(sql);              
    ResultSet rs = stms.executeQuery();   
    int ct = 0;   
    while (rs.next()) {                  
    annos[ct] = rs.getInt(1);                 
    ct++; 
    }
    rs.close();
    stms.close();
    }
    catch (Exception e) {
    e.printStackTrace();
    }
		
   ftypeidString = null; 		
		
	return annos;
    
    } 

	public static AnnotationDetail [] retrieveAnnosByFtypeids(Connection con,  int [] ftypeids, int count) {
	if(ftypeids == null || ftypeids.length ==0) 
	return null; 
	String ftypeidString = "";   
	for (int i=0; i<ftypeids.length -1; i++) 
	ftypeidString = ftypeidString + "'" +  ftypeids[i] + "', ";  
	ftypeidString = ftypeidString + "'" +  ftypeids[ftypeids.length-1] + "'";     
	String sql =   "SELECT fid   FROM  fdata2 WHERE  ftypeid in (" +  ftypeidString  +  " ) ";
	AnnotationDetail annos[] = new AnnotationDetail [count]; 
	try {     
	PreparedStatement stms = con.prepareStatement(sql);              
	ResultSet rs = stms.executeQuery();   
	int ct = 0;   
	while (rs.next()) {                  
	annos[ct] = new AnnotationDetail(rs.getInt(1));                 
	ct++; 
	}
	rs.close();
	stms.close();
	}
	catch (Exception e) {
	e.printStackTrace();
	}
		
		
 ftypeidString =null; 
	return  annos;
	} 

	public static String [][] retrieveFidText(Connection con,   String [][] fid2att,  String type) {
	HashMap  map = new HashMap ();    
	String [] fids = new String [fid2att.length];  
	for (int i=0; i<fid2att.length; i++) 
	fids [i] = fid2att[i][0]; 
		
		
	String [] fidSQLs = LffUtility.getFidStrings(fids, 1000); 
	String sql =  null;   ResultSet rs = null;       PreparedStatement stms = null; 
	try {
	for (int i=0; i<fidSQLs.length; i++) {
	sql =   "SELECT fid, text "  + 
	"  FROM  fidText WHERE  fid in (" +  fidSQLs[i]  +  " )  and textType = '" + type + "'" ;
	stms = con.prepareStatement(sql);
		
		
	rs = stms.executeQuery();   
	while (rs.next())  
	map.put (rs.getString(1), rs.getString(2));
	}
	rs.close();
	stms.close();
	}
	catch (Exception e) {
	e.printStackTrace();
	}
	
	if (!map.isEmpty()) {
	for (int i=0; i<fid2att.length; i++){ 
	if (map.get(fid2att[i][0]) != null) {
	fid2att[i][1] =(String)map.get(fid2att[i][0]); 
	}}
	}
	fids = null; 	
	sql = null; 	
	map = null; 	
		fidSQLs = null; 
	return  fid2att; 
	}  

	
	public static HashMap populatev2id (String [][] fidAttributes) {
		HashMap v2id  = new HashMap ();
		ArrayList list = null;  
		String [] arr1  = null; 
		
		for (int i=0; i<fidAttributes.length; i++) {
			arr1 = fidAttributes[i]; 
			
			if (arr1[1]== null || arr1[1]=="") 
				arr1[1] = OneAttAnnotationSorter.maxStringValue;                  
			fidAttributes[i]  = arr1; 
			
			if (v2id.get(arr1[1])== null)
				list = new ArrayList();
			else
				list = (ArrayList)v2id.get(arr1[1]);
					
			if (arr1 != null && arr1[1] != null) { 
				list.add(arr1);
				v2id.put(arr1[1], list); 
			}
		}
		
		list = null; 
		arr1 = null; 
		
		return v2id; 
	}


    public static HashMap populatev2id (String [][] fidAttributes, HashMap map, int index) {
        HashMap v2id  = new HashMap ();
        ArrayList list = null;  
        String [] arr1  = null; 
        String [] arr  = null; 
        for (int i=0; i<fidAttributes.length; i++) {
            arr1 = fidAttributes[i]; 
            if (map.get(arr1[1])== null) {
            arr1[1]  = OneAttAnnotationSorter.maxStringValue;             
            }                   
            else {    
            arr1 = (String[])map.get(arr1[1]);       
            arr1[1]  = arr[index];                    
            }
            
            fidAttributes[i]  = arr1;                   
            if (v2id.get(arr1[1])== null)
            list = new ArrayList();
            else
            list = (ArrayList)v2id.get(arr1[1]); 
            if (arr1 != null && arr1[1] != null) { 
            list.add(arr1);
            v2id.put(arr1[1], list); 
            }
        }   
		
		
		    list = null;  
         arr1  = null; 
         arr  = null; 
		return v2id; 
    }

    public static HashMap populatev2id (String [][] fidAttributes, HashMap map) {
            HashMap v2id  = new HashMap ();
            ArrayList list = null; 
		  String [] arr1 = null; 
			for (int i=0; i<fidAttributes.length; i++) {
              arr1 = fidAttributes[i]; 
            if (map.get(arr1[1])== null) {
            arr1[1]  = OneAttAnnotationSorter.maxStringValue;                    
            }                   
            else {                   
            arr1[1]  =  (String)map.get(arr1[1]);                         
            }
            fidAttributes[i]  = arr1;                   
            if (v2id.get(arr1[1])== null)
            list = new ArrayList();
            else
            list = (ArrayList)v2id.get(arr1[1]); 
            if (arr1 != null && arr1[1] != null) { 
            list.add(arr1);
            v2id.put(arr1[1], list); 
            }
            } 
		list = null; 
		 arr1 = null; 
		return v2id; 
    }
  
  /**
   * retrieves fid2AttributeValues with known attribute Name
   * used for fast annotation sorting 
   * @param con  
   * @param nameId: attribute name Id 
   * @param fids int [] arr of fids 
   * @return
   */ 
     public static HashMap   retrieveAttValueMap (Connection con, String  [] fids, String nameId) {
        String nameString = ""; 
        HashMap fid2valueids = new HashMap (); 
        HashMap valueIdMap = new HashMap () ; 
        HashMap valueId2value = new HashMap () ;
	     HashMap fid2values = new HashMap (); 
		int numFids  = fids.length; 
         String sql = null;     
        ResultSet rs = null; 
        PreparedStatement stms = null;              
     
       String emptyString = "";  
	  String quote = "'"; 
	   String comma = ","; 
		try {                
            StringBuffer sb = new StringBuffer ("");             
            if (fids != null && numFids  <=1000) {  
                for (int i=0; i<numFids; i++)  {
                sb.append(quote); 
			    sb.append(fids[i]); 
			     sb.append(quote); 
					if (i<numFids -1 ) 
					sb.append(comma); 
				}
				
                nameString = sb.toString();             
                
                sql = "select fid, attValueId from fid2attribute where attNameId = ? and fid in (" + nameString+ ") ";         
                stms = con.prepareStatement(sql); 
                stms.setString(1, nameId); 
              
                rs = stms.executeQuery(); 
                while (rs.next())    {          
                        fid2valueids.put( rs.getString(1),rs.getString(2)); 
                        valueIdMap.put(rs.getString(2), "1"); 
                    }
            }
            else {
               // String []   nameStrings = LffUtility.getFidStrings (fids, LffConstants.BLOCK_SIZE); 
              
                   // nameString = nameStrings [i]; 
                    sql = "select fid, attValueId from fid2attribute where attNameId = " + nameId + " and fid in (" +  LffConstants.Q1000 + ") ";         
                      
                    stms = con.prepareStatement(sql);  
               
                    int num = fids.length; 
                    int length = num/1000;
                    if (num % 1000 >0) 
                    length ++; 
                    String  [][] fidsArrays  = new String  [length][1000]; 
                                 	  
	  
	  

                    for (int i=0; i<length-1; i++) {   
                    for (int j=0; j<1000; j++)    
                    fidsArrays [i][j] = fids[i*1000 + j ];                         
                    }  
                    
                    int lastRow = length -1; 
                    if (num% 1000>0) {
                    int remain = num%1000; 
                    for (int j=0; j<remain; j++)    
                    fidsArrays [lastRow][j] = fids[lastRow*1000 + j ]; 
                    
                    if (remain < 1000) 
                    for (int j=remain; j>1000; j++)    
                    fidsArrays [lastRow][j] = "-1"; 
                    }     

                
                    for (int i=0; i<fidsArrays.length; i++) {
                        for (int j=0; j<1000; j++) 
                            stms.setString(j+1,  fidsArrays [i][j] );
                        
                        rs = stms.executeQuery(); 
                        while (rs.next())  {               
                            fid2valueids.put( rs.getString(1),rs.getString(2)); 
                            valueIdMap.put(rs.getString(2), "1");                      
                        }
                    }      
            }
        } 
        catch (Exception e) {
             e.printStackTrace();
        }
      
      String [] valueids = (String[])valueIdMap.keySet().toArray(new String[valueIdMap.size()]); 
      
       
      if (valueids == null || valueids.length ==0)
      {
        for (int i=0; i<fids.length; i++) 
            fid2values.put(""+fids[i] , emptyString);          
      }
      else {      
            // step2, populate valueid  with attribute values        
            valueId2value = retrieveAttValueId2ValueMap(con, valueids ); 
              // step3, populate fid with attribute values                   
           
            if (valueId2value == null && valueId2value.isEmpty()) 
            {
                for (int i=0; i<fids.length; i++) 
                fid2values.put(""+fids[i] , emptyString);                       
            }
         else { 
                String fid = null;  
                String valueId = null; 
                String value = null;                 
                for (int i=0; i<fids.length; i++) {
                    fid =""+fids[i];  
                    value= emptyString;    
                    if (fid2valueids.get(fid) != null) {
                    valueId = (String)fid2valueids.get(fid); 
                    if (valueId != null && valueId2value.get(valueId) != null) {
                        value = (String)valueId2value.get(valueId);                        
                    }
                    else {
                        value= emptyString;                          
                    }
                    } 
                    else {
                        value= emptyString; 
                    }
                    fid2values.put(fid, value);                             
                }            
            }
      }
	      nameString =  null; 
         fid2valueids = null; 
         valueIdMap = null ; 
         valueId2value = null ;
	   
          sql = null;     
       
	  
	 return  fid2values; 
    }
    
    
   
	public static int []  retrieveNameIds(Connection con, String  [] names) {
	StringBuffer  nameBuffer = new StringBuffer( ""); 
	int nameLength = names.length; 
     String quote = "'"; 
		String comma = ","; 
	for (int i=0; i<nameLength; i++){ 
	nameBuffer.append(quote);  
		nameBuffer.append(names[i]); 
		nameBuffer.append (quote ) ;
		if (i<nameLength -1) 
		nameBuffer.append(comma);  
	}
	
	ResultSet rs = null; 
	PreparedStatement stms = null;      
	int [] ids = new int [nameLength];
			int count = 0; 
	String sql = "select  distinct attNameId from attNames where name in (" + nameBuffer.toString() + ") ";         
	try {      
		stms = con.prepareStatement(sql);             
		rs = stms.executeQuery(); 
	
		while (rs.next())  {               
		ids[count] = rs.getInt(1);  
		count ++; 
		}
		rs.close(); 
		stms.close();
	} 
	catch (Exception e) {
		e.printStackTrace();       	
	}
		
		nameBuffer = null; 
	return ids; 
	}

    public static int   retrieveNameId(Connection con, String   name) {
        ResultSet rs = null; 
        PreparedStatement stms = null;      
        int  id =  0; 
        String sql = "select attNameId from attNames where name = ?";             
        try {      
        stms = con.prepareStatement(sql);     
        stms.setString(1, name);
        rs = stms.executeQuery();      
        if (rs.next())  {               
        id = rs.getInt(1);        
        }
        rs.close(); 
        stms.close();
        } 
        catch (Exception e) {
        e.printStackTrace();
        }
        return id; 
    }

	public static int []  retrieveValueIds(Connection con, int [] nameids) {
		StringBuffer  nameString =  new StringBuffer ("");  
		int nameLength = nameids.length; 
		String quote = "'"; 
		String comma = ","; 
		for (int i=0; i<nameLength; i++) {
			nameString.append(quote);
			nameString.append(nameids[i]); 
			nameString.append(quote); 
			if (i<nameLength ) 
			nameString.append(comma) ;  
		}
		ResultSet rs = null; 
		PreparedStatement stms = null;      
		int [] ids = null;
		String sql = "select  distinct attValueId from  fid2attribute where attNameId in (" + nameString + ") ";         
		
		ArrayList list = new ArrayList (); 
		try {      
			stms = con.prepareStatement(sql);             
			rs = stms.executeQuery(); 
			
			while (rs.next())  {               
			list.add(rs.getString(1)); 
			}
			
			String [] arr = (String [])list.toArray(new String [list.size()]); 
			ids = new int [arr.length] ; 
			for (int i=0; i<arr.length; i++) 
			ids [i] = Integer.parseInt(arr[i]); 
			rs.close(); 
			stms.close();
		} 
		catch (Exception e) {
		e.printStackTrace();
		}
		
		list = null; 
		nameString = null; 
		
		return ids; 
	}                  	
	
	
	
	
	
    public static HashMap   retrieveAttValueId2ValueMap (Connection con,   String[] valueids) {
        StringBuffer  sb  = new StringBuffer (""); 
		String  nameString = ""; 
	 	           		
		HashMap map = new HashMap (); 
        int valueLength = valueids.length; 
		String comma = ", "; 
		String quote = "'";  
		for (int i=0; i<valueLength; i++){ 
		    sb.append(quote); 
			sb.append(valueids[i]);
			sb.append(quote);
			if (i < valueLength -1) 
			sb.append(comma);  
		}				
	         
		
		ResultSet rs = null; 
        PreparedStatement stms = null;              
          String sql = null;
        try {                        
                if (valueids != null && valueLength <=1000) {  
                          sql = "select  attValueId, value from attValues where attValueId in (" + sb.toString() + ") ";         
                        
                        stms = con.prepareStatement(sql);             
                        rs = stms.executeQuery();                         
                        while (rs.next())               
                        map.put( rs.getString(1),rs.getString(2));                       
                }
                else {
                    String []   nameStrings = LffUtility.getFidStrings (valueids, LffConstants.BLOCK_SIZE); 
                    for (int i=0; i<nameStrings.length; i++) {
                    nameString = nameStrings [i]; 
                    sql = "select  attValueId, value from attValues where attValueId in (" + nameString + ") ";         
                    stms = con.prepareStatement(sql);             
                    rs = stms.executeQuery(); 
                    while (rs.next())  {               
                    map.put( rs.getString(1),rs.getString(2));                       
                    }
                    }      
                }                          
        rs.close(); 
        stms.close();
        } 
        catch (Exception e) {
        e.printStackTrace();
        }
		
		sb = null; 
		
		
		return map; 
    }
	
	
	
	

	public static HashMap   retrieveAttNameMap (Connection con, int [] ids) {
        String nameString = ""; 
        HashMap map = new HashMap (); 
        int nameLength = ids.length; 
		StringBuffer sb = new StringBuffer (""); 
		String comma = ", "; 
			String quote = "'";  
			for (int i=0; i<nameLength -1; i++) { 
				sb.append(quote); 
				sb.append(ids[i]);
				sb.append(quote);
				if (i < ids.length -1) 
				sb.append(comma);  
			}				
	         		
	
        nameString = sb.toString();  
     	
		ResultSet rs = null; 
        PreparedStatement stms = null;      
        String sql = "select  distinct attNameId, name from attNames where attNameId in (" + nameString + ") ";         
        try {      
        stms = con.prepareStatement(sql);             
        rs = stms.executeQuery(); 
        
        while (rs.next())  {               
        map.put( rs.getString(1),rs.getString(2));                       
        }
        rs.close(); 
        stms.close();
        } 
        catch (Exception e) {
        e.printStackTrace();
        }
		
		
		return map; 
    }

public static HashMap  retrieveSmallNumAnnotationAVPs(Connection con, int [] fids) {
    HashMap fid2hash = new HashMap (); 
		String sql = null; 
	     String sql2 = null; 
	    String  sql3 = null;
	HashMap fid2avpids = new HashMap(); 
		   HashMap attNameId2value = new HashMap (); 
		 HashMap attValueId2value = new HashMap (); 
		PreparedStatement stms = null; 
	  ResultSet rs =  null; 
	  String fid = null; 
        HashMap idmap = null;
	 String nameId = null; 
    String valueId = null; 
    String name = null; 
    String value = null; 
	                String fidString = ""; 
	try {     
   
          
		
			StringBuffer sb = new StringBuffer (""); 
		String comma = ", "; 
			String quote = "'";  
			for (int i=0; i<fids.length ; i++) { 
				sb.append(quote); 
				sb.append(fids[i]);
				sb.append(quote);
				if (i < fids.length -1) 
				sb.append(comma);  
			}				
	         		
	                          	

        fidString = sb.toString();  
		
		
	
	 sql = "select fid, attNameId, attValueId from fid2attribute where fid in (" + fidString + ") ";                           
   	 sql2 = "select n.attNameId, n.name from attNames n, fid2attribute f  where f.fid in (" + fidString + ") " + 
		 " and f.attNameId  = n.attNameId";  
    	 
    // now get attvalues 
      sql3 = "select v.attValueId, v.value from attValues v, fid2attribute f  where f.fid in (" + fidString + ") " + 
    " and f.attValueId = v.attValueId"; 	
		
			
	 stms = con.prepareStatement(sql); 
     rs = stms.executeQuery();   
      
        while (rs.next())   {   
			fid = rs.getString(1);         
			idmap = null; 
			if (fid2avpids.get(fid) != null) 
			idmap = (HashMap) fid2avpids.get(fid);  
			else {
			idmap = new HashMap ();  
			} 
			idmap.put(rs.getString(2), rs.getString(3)); 
			fid2avpids.put(fid , idmap);  
			idmap = null; 
		}                
    
    // now get attNames  
		stms = con.prepareStatement(sql2);             
		rs = stms.executeQuery();                       
		while (rs.next())                 
			attNameId2value.put(rs.getString(1), rs.getString(2));  
	  
		stms = con.prepareStatement(sql3);             
		rs = stms.executeQuery();                       
		while (rs.next())                 
			attValueId2value.put(rs.getString(1), rs.getString(2));  
		
		
		for (int i=0; i<fids.length; i++){               
			HashMap  fidmap = null; 
			if (fid2avpids.get(""+fids[i]) != null) 
				fidmap = (HashMap) fid2avpids.get(""+fids[i]);
			
			HashMap temp = new HashMap();
			if (fidmap != null) {
				Iterator iterator = fidmap.keySet().iterator(); 
				while (iterator.hasNext()) {
					nameId = (String)iterator.next(); 
					valueId =(String) fidmap.get(nameId); 
					name = (String)attNameId2value.get(nameId);  
					value = (String)attValueId2value.get(valueId);
					temp.put(name, value);
				}   
			}
			fid2hash.put(""+fids[i], temp); 
			temp = null; 
		}               
    }
    catch (Exception e) {
		System.err.println(fidString); 
				
		System.err.println("error " + sql ); 
	e.printStackTrace();
    }

	
	sql =  null; 
	sql2 =  null; 
	
	// now get attvalues 
	sql3 = 	 null; 
	
	fid2avpids =  null; 
	attNameId2value = null; 
	attValueId2value = null; 
	fid2avpids = null; 
	idmap = null; 
	fid2avpids = null; 
	
		return fid2hash; 
}

	
	
	
	
	public static AnnotationDetail[] retrieveSortAnnotations(Connection con,  int [] ftypeids,  ArrayList sortList,  String [] sortNames, HashMap ftypeid2ftype, HashMap ftypeid2Gclass, HashMap chromosomeMap) {
		if(ftypeids == null || ftypeids.length ==0) 
		return null; 
		
		ArrayList list = new ArrayList();        
		AnnotationDetail[] annotations = null;
		String type = null; 
		String subtype = null; 
		String trackName = null; 
		String [] trackElements = null; 
		String ftypeidString = "";   
		
			for (int i=0; i<ftypeids.length -1; i++) 
			ftypeidString = ftypeidString + "'" +  ftypeids[i] + "', ";  
			ftypeidString = ftypeidString + "'" +  ftypeids[ftypeids.length-1] + "'";     
			
		String orderString = "";   
		if (sortNames != null && sortNames.length >0) { 
			for (int i=0; i<sortNames.length -1; i++) {
			orderString = orderString + "'" +  sortNames[i] + "', ";  
			}
			orderString = orderString + "'" +  sortNames[sortNames.length-1] + "'";     
		}
		
		String sql =   "SELECT fid, ftypeid, fstart, fstop, fscore, fphase, fstrand, gname, ftarget_start, ftarget_stop, fbin, rid " +
		"  FROM  fdata2 WHERE  ftypeid in (" +  ftypeidString  +  " ) ";
		if (sortNames != null && sortNames.length >0) 
		sql =  sql + "  order by " + orderString ;
		try {
		PreparedStatement stms = con.prepareStatement(sql);              
		ResultSet rs = stms.executeQuery();  
			AnnotationDetail anno = null; 
			while (rs.next()) {        
				 anno = new AnnotationDetail(rs.getInt(1));                    
				anno.setFtypeId(rs.getInt(2));    
				anno.setFstart(rs.getString(3));
				anno.setFstop(rs.getString(4));
				anno.setStart(rs.getLong(3));
				anno.setStop(rs.getLong(4));    
				anno.setFscore(rs.getString(5));
				anno.setScore(rs.getDouble(5));    
				anno.setPhase(rs.getString(6));
				anno.setStrand(rs.getString(7));   
				anno.setGname(rs.getString(8));    
				anno.setTstart(rs.getString(9));
				anno.setTstop(rs.getString(10));
				anno.setTargetStart(rs.getLong(9));
				anno.setTargetStop(rs.getLong(10));
				anno.setFbin(rs.getString(11));
				anno.setRid(rs.getInt(12));      
				
				list.add(anno); 
				anno = null; 	
			}
			rs.close();
			stms.close();
			}
			catch (Exception e) {
			e.printStackTrace();                                 
			}
		
			if (list.size() > 0) {
			annotations = (AnnotationDetail[]) list.toArray(new AnnotationDetail[list.size()]);
			if ( sortList.contains(LffConstants.LFF_COLUMNS[4]) ){
			for (int i=0; i<annotations.length ; i++) 
			annotations[i].setChromosome((String)chromosomeMap.get("" + annotations[i].getRid()));
			}   
		
			if (sortList.contains(LffConstants.LFF_COLUMNS[3])  || sortList.contains(LffConstants.LFF_COLUMNS[2])) {
			for (int i=0; i<annotations.length ; i++) {
			trackElements =(String[]) ftypeid2ftype.get("" + annotations[i].getFtypeId());                                           
			if ( trackElements != null) {    
			type = trackElements[0]; 
			subtype = trackElements[1]; 
			trackName = type + ":" + subtype;                         
			annotations[i].setFmethod(type);
			annotations[i].setFsource(subtype);
			annotations[i].setTrackName(trackName);
			}
			}
			}  
			
			if (sortList.contains(LffConstants.LFF_COLUMNS[1])) {
				for (int j=0; j<annotations.length; j++) 
					annotations[j].setGclassName((String )ftypeid2Gclass.get("" + annotations[j].getFtypeId()));
				}  
			}  
			
			if (list != null) 
			list.clear();
			list = null; 
			return annotations;
		}
		

	
	
	

	
	public static AnnotationDetail []  populateAnnotationText (AnnotationDetail [] annotations,  Connection con) {
		if (annotations == null || annotations.length == 0) 
		return annotations; 
		String sql =  null;   
		PreparedStatement stms =  null;            
		ResultSet rs = null; 
		String type = null; 
		sql =   "SELECT textType,  text  FROM  fidText WHERE  fid = ?  ";    
		try {       
		
		stms = con.prepareStatement(sql);  
		
		for (int i=0; i<annotations.length; i++){
		stms.setInt(1, annotations[i].getFid());
		rs = stms.executeQuery();    
		while (rs.next()) {          
		type = rs.getString(1);
		if (type.equals("s")) 
		annotations[i].setSequences(rs.getString(2));
		else  if (type.equals("t")) {
		annotations[i].setComments(rs.getString(2));  
		}
		} 
		}
		if (rs != null) 
		rs.close();
		stms.close();
		}
		catch (Exception e) {
		e.printStackTrace();
		}
		return annotations ; 
	  } 

	
	
	
	
	
	public static AnnotationDetail []  populateAnnotationText (AnnotationDetail [] annotations,  HashMap fid2anno,  Connection con) {
	if (annotations == null || annotations.length == 0) 
	return annotations; 
	int fids [] = new int [annotations.length];   
	for (int i=0; i<annotations.length; i++)
	fids [i]= annotations[i].getFid();
	String [] fidStrings = LffUtility.getFidStrings (fids, LffConstants.BLOCK_SIZE);     
	String sql =  null;   
	String ftypeidString = null; 
	PreparedStatement stms =  null;            
	ResultSet rs = null; 
	String fid = null; 
	String type = null; 
	AnnotationDetail annotation = null;   
	try {       
	for (int i=0; i<fidStrings.length; i++){
	ftypeidString = fidStrings[i];    
	sql =   "SELECT fid, textType,  text  FROM  fidText WHERE  fid in (" +  ftypeidString  +  ")  ";    
	   // System.err.println("sql " + i +" " +  sql) ; 
		
		stms = con.prepareStatement(sql);              
	rs = stms.executeQuery();    
	while (rs.next()) {
	fid = rs.getString(1); 
	annotation = (AnnotationDetail)fid2anno.get(fid); 
	type = rs.getString(2);
	if (annotation != null && type.equals("s")) 
	annotation.setSequences(rs.getString(3));
	else  if (annotation != null && type.equals("t")) {
	annotation.setComments(rs.getString(3));  
	}            
	}     }
	rs.close();
	stms.close();
	}
	catch (Exception e) {
	e.printStackTrace();
	}
	return annotations ; 
	} 


	public static AnnotationDetail[] retrieveAllAnnotations(Connection con,  int [] ftypeids,   boolean isTooManyAnnotations) {
	if(ftypeids == null || ftypeids.length ==0) 
	return null; 
	
	ArrayList list = new ArrayList();        
	AnnotationDetail[] annotations = null;
	HashMap chromosomeid2name  = new HashMap ();        
	HashMap ftypeid2trackName  = new HashMap ();    
	String type = null; 
	String subtype = null; 
	String trackName = null; 
	String [] trackElements = null; 
	String ftypeidString = "";   
	for (int i=0; i<ftypeids.length -1; i++) 
	ftypeidString = ftypeidString + "'" +  ftypeids[i] + "', ";  
	ftypeidString = ftypeidString + "'" +  ftypeids[ftypeids.length-1] + "'";     
	
	String sql =   "SELECT fid, ftypeid, fstart, fstop, fscore, fphase, fstrand, gname, ftarget_start, ftarget_stop, fbin, rid " +
	"  FROM  fdata2 WHERE  ftypeid in (" +  ftypeidString  +  " ) ";
	
	ArrayList  ridList = new ArrayList ();        
	try {
	PreparedStatement stms = con.prepareStatement(sql);              
	ResultSet rs = stms.executeQuery();    
	while (rs.next()) {
	int fid = rs.getInt(1);
	AnnotationDetail anno = new AnnotationDetail(fid);                    
	anno.setFtypeId(rs.getInt(2));    
	anno.setFstart(rs.getString(3));
	anno.setFstop(rs.getString(4));
	anno.setStart(rs.getLong(3));
	anno.setStop(rs.getLong(4));    
	anno.setFscore(rs.getString(5));
	anno.setScore(rs.getDouble(5));    
	anno.setPhase(rs.getString(6));
	anno.setStrand(rs.getString(7));   
	anno.setGname(rs.getString(8));    
	// anno.setChromosome(rs.getString(10));
	anno.setTstart(rs.getString(9));
	anno.setTstop(rs.getString(10));
	anno.setTargetStart(rs.getLong(9));
	anno.setTargetStop(rs.getLong(10));
	anno.setFbin(rs.getString(11));
	anno.setRid(rs.getInt(12));
	if (!ridList.contains(rs.getString(12))) 
	ridList.add(rs.getString(12));  
	list.add(anno);
	}
	rs.close();
	stms.close();
	}
	catch (Exception e) {
	e.printStackTrace();
	}
	if (list.size() > 0) {
	annotations = (AnnotationDetail[]) list.toArray(new AnnotationDetail[list.size()]);
	
	if (!ridList.isEmpty()) {   
	String [] rids = (String [])ridList.toArray(new String [ridList.size()] ); 
	chromosomeid2name = Utility.retrieveChromosomeNames (rids, con);  
	} 
	ftypeid2trackName = Utility.retrieveFtype(ftypeids, con);
	if (ftypeid2trackName != null && !ftypeid2trackName.isEmpty()) {
	for (int i=0; i<annotations.length ; i++) {
	trackElements =(String[]) ftypeid2trackName.get("" + annotations[i].getFtypeId());                                           
	if ( trackElements != null) {
	
	type = trackElements[0]; 
	subtype = trackElements[1]; 
	trackName = type + ":" + subtype;                         
	annotations[i].setFmethod(type);
	annotations[i].setFsource(subtype);
	annotations[i].setTrackName(trackName);
	annotations[i].setChromosome((String)chromosomeid2name.get("" + annotations[i].getRid()));
	}}}}
		
		
		if (list != null) 
	  list.clear();
		list = null; 
	
	 chromosomeid2name  = null; 
	ftypeid2trackName  = null; 
		
	return annotations;
	}

/**
* populate annotations with provided fid list
* if the number of fids > 1000, don't use this method due to the limit of string length
* @param con
* @param fids
* @return
*/   
public static AnnotationDetail[] retrieveAnnotations(Connection con,  int [] fids, HashMap ftypeid2ftype, HashMap id2chrom  ) {
 	ArrayList list = new ArrayList();        
	AnnotationDetail[] annotations = null;
	String fidString = "";   
	
	
	StringBuffer sb = new StringBuffer (""); 
		String comma = ", "; 
			String quote = "'";  
			for (int i=0; i<fids.length ; i++) { 
				sb.append(quote); 
				sb.append(fids[i]);
				sb.append(quote);
				if (i < fids.length -1) 
				sb.append(comma);  
			}				
	      fidString = sb.toString();    			 
	
	String sql = "SELECT fid, ftypeid, fstart, fstop, fscore, fphase, " +
	" fstrand, gname,  ftarget_start, ftarget_stop, fbin, rid " +
	"  FROM  fdata2 WHERE  fid in (" +  fidString  +  " )  ";
     
	//  System.err.println(sql);  
	
	
	try {
	    //if (fids != null) 
	    //  System.err.println("passed num fids " + fids.length);  
		
		if (con == null || con.isClosed()) { 
		    System.err.println("No connection in AttributeRetriver.retrieveAnnotations "); 
			return null; 
		}
		PreparedStatement stms = con.prepareStatement(sql);
        ResultSet rs = stms.executeQuery();
        while (rs.next()) {
            int fid = rs.getInt(1);
            AnnotationDetail anno = new AnnotationDetail(fid);                    
            anno.setFtypeId(rs.getInt(2));
            anno.setFstart(rs.getString(3));
            anno.setFstop(rs.getString(4));
            anno.setStart(rs.getLong(3));
            anno.setStop(rs.getLong(4));    
            anno.setFscore(rs.getString(5));
            anno.setScore(rs.getDouble(5));    
            anno.setPhase(rs.getString(6));
            anno.setStrand(rs.getString(7));
            anno.setGname(rs.getString(8));
            anno.setTstart(rs.getString(9));
            anno.setTstop(rs.getString(10));
            anno.setTargetStart(rs.getLong(9));
            anno.setTargetStop(rs.getLong(10));
            anno.setFbin(rs.getString(11));
            anno.setRid(rs.getInt(12));
             list.add(anno);
        }
        if (list.size() > 0)
            annotations = (AnnotationDetail[]) list.toArray(new AnnotationDetail[list.size()]);

		}
		catch (Exception e) {    
		e.printStackTrace();
		}
		
		String type = null; 
		String subtype = null; 
		String trackName = null; 
		if (annotations != null && annotations.length >0) {
			for (int i=0; i<annotations.length ; i++) {
				if ( ftypeid2ftype.get("" + annotations[i].getFtypeId())  != null) {
					String trackString[] =(String[]) ftypeid2ftype.get("" + annotations[i].getFtypeId());                           
					if (trackString != null  && trackString.length>0) {                          
						type = trackString[0]; 
						subtype = trackString[1]; 
						trackName = type + ":" + subtype;                           
					} 
					annotations[i].setFmethod(type);
					annotations[i].setFsource(subtype);
					annotations[i].setTrackName(trackName);
				}                
				if (id2chrom.get("" + annotations[i].getRid()) != null) 
					annotations[i].setChromosome((String)id2chrom.get("" + annotations[i].getRid()));
			}
		} 
		if (list != null) 
		list.clear();
		list = null; 	
		return annotations;
}      

	public static AnnotationDetail[] retrieveAnnotations(Connection con,  String fidString, HashMap ftypeid2ftype) {
	ArrayList list = new ArrayList();        
	AnnotationDetail[] annotations = null;
	String sql = "SELECT fid, ftypeid, fstart, fstop, fscore, fphase, " +
	" fstrand, gname,  ftarget_start, ftarget_stop, fbin, rid " +
	"  FROM  fdata2 WHERE  fid in (" +  fidString  +  " )  ";         
	ArrayList  ridList = new ArrayList (); 
	HashMap id2chrom  = new HashMap (); 
	try {
	PreparedStatement stms = con.prepareStatement(sql);
	ResultSet rs = stms.executeQuery();
	while (rs.next()) {
	int fid = rs.getInt(1);
	AnnotationDetail anno = new AnnotationDetail(fid);                    
	anno.setFtypeId(rs.getInt(2));
	anno.setFstart(rs.getString(3));
	anno.setFstop(rs.getString(4));
	anno.setStart(rs.getLong(3));
	anno.setStop(rs.getLong(4));    
	anno.setFscore(rs.getString(5));
	anno.setScore(rs.getDouble(5));    
	anno.setPhase(rs.getString(6));
	anno.setStrand(rs.getString(7));
	anno.setGname(rs.getString(8));
	anno.setTstart(rs.getString(9));
	anno.setTstop(rs.getString(10));
	anno.setTargetStart(rs.getLong(9));
	anno.setTargetStop(rs.getLong(10));
	anno.setFbin(rs.getString(11));
	anno.setRid(rs.getInt(12));
	if (!ridList.contains(rs.getString(12))) 
	ridList.add(rs.getString(12));             
	list.add(anno);
	}
	if (list.size() > 0)
	annotations = (AnnotationDetail[]) list.toArray(new AnnotationDetail[list.size()]);
	
	if (!ridList.isEmpty()) {
	String [] rids = (String [])ridList.toArray(new String [ridList.size()] ); 
	id2chrom = Utility.retrieveRid2Chromosome (con, rids); 
	}
	}
	catch (Exception e) {
	
	e.printStackTrace();
	}
	String type = null; 
	String subtype = null; 
	String trackName = null; 
	if (annotations != null && annotations.length >0) {
	for (int i=0; i<annotations.length ; i++) {
	String trackString[] =(String[]) ftypeid2ftype.get("" + annotations[i].getFtypeId());                           
	if (trackString != null) {                          
	type = trackString[0]; 
	subtype = trackString[1]; 
	trackName = type + ":" + subtype;                           
	} 
	annotations[i].setFmethod(type);
	annotations[i].setFsource(subtype);
	annotations[i].setTrackName(trackName);
	annotations[i].setChromosome((String)id2chrom.get("" + annotations[i].getRid()));
	}
	}
		
		list = null; 
	return annotations;
	}  

}

