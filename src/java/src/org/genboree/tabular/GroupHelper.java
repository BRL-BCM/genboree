package org.genboree.tabular;

import org.genboree.editor.AnnotationDetail;

import javax.servlet.jsp.JspWriter;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Iterator;

/**
 * User: tong
 * Date: Jul 26, 2007
 * Time: 2:08:05 PM
 */
public class GroupHelper {
	public static int   countChromosome (Connection con ) {
		int num = 0; 
		String sql = sql = "select count(*) from fref ";
		try {
		PreparedStatement stms = con.prepareStatement(sql);
		ResultSet rs = stms.executeQuery();
		if (rs.next()) 
		num = rs.getInt(1);   
		if (rs != null) 	
		rs.close(); 
		stms.close(); 
		}
		catch (Exception e) {
		e.printStackTrace();
		System.err.println(sql); 
		}
		return  num; 
	}  


public static AnnotationDetail []  populateGroupText (boolean isVerbose, Connection con,  AnnotationDetail [] annotations, HashMap groupName2Fids ,boolean isLocal, JspWriter out) {    
	if (annotations == null || annotations.length ==0) 
	return annotations; 
	
	if (groupName2Fids == null || groupName2Fids.isEmpty()) 
	return annotations; 
	
	String groupComments = "";
	String groupSequences = ""; 
	HashMap commentMap  =  null;  
	HashMap sequenceMap  =  null; 
	
	String [] groupFids = null; 
	ArrayList fidArrayList  = null;     
	HashMap fid2Text =   null; 
	String [] fidText = null; 
	String varies = "varies"; 
	String yes = "y";
	String blank = ""; 
	String comma = ","; 
	StringBuffer grpSequences = new StringBuffer(); 
	StringBuffer grpComments = new StringBuffer(); 
	try {
		if (con == null || con.isClosed()) 
		throw new Exception  ("Connection failed: GroupHelper populateAnnotationText ");  
			
		if ( annotations != null) {   
			for (int m=0; m<annotations.length; m++){     
				groupFids = null; 
				fidArrayList  = null;                   
				fidArrayList = (ArrayList) groupName2Fids.get (annotations[m].getGname() + "_"  + annotations[m].getFtypeId()+ "_" + annotations[m].getRid()); 
				if (fidArrayList != null) 
					groupFids =(String []) fidArrayList.toArray(new String [fidArrayList.size()] );  
				
			    fid2Text =   null; 
				if (groupFids != null && groupFids.length > 0) 
					fid2Text = GroupHelper.retrieveFidText (con, groupFids, annotations[m].getFtypeId(), out);  
				else 
				continue; 
						  
				if (fid2Text== null || fid2Text.isEmpty()) 
				continue;
				
				commentMap  =   new HashMap ();  
				sequenceMap  =  new HashMap ();  
				String comments = null;     
				String sequence = null;
				groupComments ="";
				groupSequences = ""; 
				for (int j=0; j< groupFids.length; j++) { 
					fidText = (String[])fid2Text.get("" + groupFids[j]);           
					if (fidText != null && fidText.length==2 ) {                            
						if (fidText[0]  != null) {                         
							comments  = fidText[0] ;
							if (comments != null) 
								comments = comments.trim();
							
							if (comments != null && comments.length() >0) {
								if (!isVerbose) {
									if (j>0 && commentMap.get(comments) ==null ) {
										groupComments =varies; 
										break;
									}
								}
						
								commentMap.put(comments, yes);       
							}
						}
					}
				}
				
				if (isVerbose){ 
					if (commentMap != null && !commentMap.isEmpty()) {
						String [] arr = (String[])commentMap.keySet().toArray(new String[commentMap.size()]); 
						if (arr != null)
						Arrays.sort(arr); 
						
						for (int i=0; i<arr.length; i++) {
							 if (i>0) 
							  grpComments.append (comma) ;
						   grpComments.append (arr[i]) ;
						}
						
						arr = null; 
							
					}
					else {
						groupComments = blank;     
					}
				}
				else {
					groupComments = comments;  		
				}
				
				  annotations[m].setComments(groupComments);
									
				for (int j=0; j< groupFids.length; j++) { 
					fidText = (String[])fid2Text.get("" + groupFids[j]);                       
					if (fidText != null && fidText.length==2 ) {         
						if (fidText[1] != null) {                                                      
							sequence = fidText[1];  
							if (sequence != null && sequence.length() >0) {                
								if (!isVerbose) {
									if (j>0 &&  sequenceMap.get(sequence) ==null ) {
										groupSequences =varies; 
										break;
									}
								
								}
								
								sequenceMap.put(sequence, yes);    
							}    
						}
					
					}
       			}
                             
                  
                if (isVerbose){ 
						if ( sequenceMap != null && !sequenceMap.isEmpty()) {
							String [] arr = (String[])sequenceMap.keySet().toArray(new String[sequenceMap.size()]); 
							if (arr != null)
							Arrays.sort(arr); 
							
							for (int i=0; i<arr.length; i++) {
								if (i>0) 
								grpSequences.append(comma); 
							    grpSequences.append(arr[i]) ;
							}
							arr = null; 
							groupSequences = grpSequences.toString();
						}
						else {
							  groupSequences = blank;     
						  }
				}
				else {
					groupSequences = sequence;  
				 }    
                     annotations[m].setSequences(groupSequences);
			}              
		   }
           }
           catch (Exception e) {e.printStackTrace();}  
	       finally {
		        if (sequenceMap != null) 
				sequenceMap.clear();
				sequenceMap = null; 
		      if (commentMap != null ) 
				commentMap.clear();
				commentMap = null; 
				groupComments = null; 
				groupSequences = null; 
				grpComments = null; 
				grpSequences = null; 
		
			}
		
		   return annotations; 
       }
               
   
    
    public static AnnotationDetail []  updateAnnotations (Connection con,  AnnotationDetail [] annotations, boolean isLocal,  JspWriter out ) {
          PreparedStatement stms = null; 
		   String sql = "select gname, ftypeid, rid from fdata2  where fid = ? "; 
		 boolean isShare  = false; 
		  ResultSet rs = null; 
		try {
          stms = con.prepareStatement(sql);
        
          for (int i=0; i<annotations.length; i++) {
                isShare = annotations[i].isShare(); 
                 if (isLocal && isShare) 
                    continue; 
                 if (!isLocal && !isShare)   
                       continue; 
            
            
              stms.setInt(1, annotations[i].getFid());
              rs = stms.executeQuery();
              if (rs.next()) {
                  annotations[i].setGname(rs.getString(1));
                  annotations[i].setFtypeId(rs.getInt(2));      
                  annotations[i].setRid(rs.getInt(3));
              }
          }
            
            if (rs != null)
              rs.close (); 
            
              stms.close();
          }
    
      catch (Exception e) {
    
      e.printStackTrace();
      }
		return annotations; 
      }
                      
    
    
	public static  String   getValue(AnnotationDetail anno,   String sortName, boolean  isLff, int index) {
	if (!isLff) 
	return getAVPValue(anno, sortName); 
	else 
	return getLffValue(anno, index); 
	}

	public static  String   getAVPValue(AnnotationDetail anno,   String sortName) {
		String value = null; 
		HashMap map  =  anno.getAvp(); 
		if (map != null) {
		return (String)map.get(sortName); 
		}  
		return value;
	}

     
    public static String[]   retrieveSingleAttributeValueIds (Connection con, String [] fids,  int  nameId , JspWriter out) {
       if (fids ==null || fids.length ==0)
        return null; 
   
		ResultSet rs = null; 
		PreparedStatement stms = null;      
            
        String idString = ""; 
        int length = fids.length;
		String quote = "'"; 
		String comma = ","; 
		StringBuffer  idBuffer = new StringBuffer (); 
		for (int i=0; i<length ; i++) {
             idBuffer.append(quote); 
			 idBuffer.append(fids[i]); 
			 idBuffer.append(quote);
			  if (i<length-1 ) 
			    idBuffer.append(comma);   
		}
       
              String s = "y";  
        String sql = "select attValueId from fid2attribute where fid in (" + idString + ")  and attNameId = ? ";                     
        HashMap map  = new HashMap (); 
        try {  
            stms = con.prepareStatement(sql); 
            stms.setInt(1, nameId);
            rs = stms.executeQuery(); 
      
            while (rs.next())                     
            	map.put(rs.getString(1), s);  
			
		   if (rs != null ) 
            rs.close(); 
            stms.close();
        } 
        catch (Exception e) {
        e.printStackTrace();
        }
        
		String arr[] = null; 
		if (map != null && !map.isEmpty()) 
        	 arr =  (String []) map.keySet().toArray(new String[map.size()]); 
        
		if (map != null) 
		  map.clear(); 
		map = null; 
		return arr; 
	}

    
    
    public static  String   getLffValue(AnnotationDetail anno, int index ) {
        String value = null; 
        
        switch (index) {
        case (0): { value =  anno.getGname(); }    
		break;
		case (1): { value = anno.getGclassName(); }  
		break;
        
		case (2): { value =  anno.getFmethod(); }  
		break; 
		case (3): {value = anno.getFsource(); }    
		break; 
		case (4): { value =  anno.getChromosome();  }
		break;
		case (5): {value = "" + anno.getStart();}    
		break; 
        
		case (6): { value =   "" + anno.getStop();  }    
		break; 
		case (7): {value =  anno.getStrand(); }  
		break; 
		case (8): { value =  anno.getPhase();  } 
		break ; 
		case (9): {value =  ""+ anno.getScore(); }  
		break;
        
		case (10): { value =   "" + anno.getTargetStart();  }  
		break; 
		case (11): {value =  "" + anno.getTargetStop(); } 
		break; 
		case (12): { value =   anno.getSequences();  } 
		break; 
		case (13): {value =  anno.getComments(); }    
		break; 
        
		default: {
       
        }                
        }
		
		return value; 
        
	}
      
    public static  int    getType( int index, boolean isLff , HashMap map  ) {
    int type = 1; 
    
    if (isLff) {
		switch (index) {
		case (0): {   } 
		break; 
		case (1): { }    
		  break; 
		case (2): {  }  
		break; 
		case (3): { }  
		break; 
		case (4): {   }   	break;  
		case (5): {type=2;}    	break; 
		
		case (6): { type=2;  }    	break; 
		case (7): {  }   	break;  
		case (8): {   }  	break;   
		case (9): {type=3; }   	break;  
		
		case (10): { type= 2;  }  	break;   
		case (11): { type=2; }    	break; 
		case (12): {    } 	break;    
		case (13): { }  	break;   
		}              
    }    
    else {  // avp     
		if (map != null) {
			Iterator iterator = map.keySet().iterator(); 	
			String value = null; 
			while (iterator.hasNext()) { 
				value = (String)iterator.next(); 
				if (value != null)
					value = value.trim();
					if (value != null && value != "") {
					
					type = LffUtility.findDataType(value);  
					break;
				}   
			
			}  
			iterator = null; 
		}     
    }
		
	return type; 
    
    }

  
    public static HashMap  getGrpName2fids(Connection con, AnnotationDetail []  annotations ,   boolean isLocal, JspWriter out) {       
		HashMap grpName2fids = new HashMap ();  
		ArrayList list = null; 
		String sql =  "SELECT fid  FROM fdata2 WHERE gname = ? and rid = ?  and ftypeid = ?    ";           	
		if (annotations == null || annotations.length == 0)
		return null; 
		PreparedStatement stms = null; 
		String fid = null;             
		ResultSet rs = null; 
		String grpName = null;  
		AnnotationDetail annotation = null;
		int ftypeid = -1; 
		int rid = -1 ; 
		int i=0;
		try {
		 stms = con.prepareStatement(sql);  
		
		for ( i=0; i<annotations.length; i++) { 
			annotation = annotations[i]; 
			if (annotation == null) {
			continue; 			
			}
	
			if (isLocal && annotation.isShare()) 
			continue; 
			
			if (!isLocal && !annotation.isShare()) {			
				continue;
			}
	
	
			grpName = annotation.getGname();
			if (grpName == null) {
				continue;             
			}
	
			ftypeid = annotation.getFtypeId(); 
			rid = annotation.getRid(); 
			
			stms.setString(1, grpName);
			stms.setInt(2, rid);
			stms.setInt(3, ftypeid);
	
			rs = stms.executeQuery(); 
			while (rs.next()) {  
				fid = rs.getString(1);             
				
				if (grpName2fids.get(grpName + "_" + ftypeid + "_" + rid ) == null) {
				list = new ArrayList (); 
				}
				else {
				list = (ArrayList)grpName2fids.get(grpName + "_" + ftypeid + "_" + rid ); 
				}  
		
				list.add(fid); 
				
				grpName2fids.put (grpName + "_" + ftypeid +"_" +rid  , list); 
				list = null; 
			}  
			}
			if (rs != null) 
			rs.close();
			stms.close();
		}
		catch (Exception e) {
			System.err.println(sql  + "  gname " +  grpName + "  ftypeid "+ ftypeid  + "  rid " + rid + "annotation is " + i + "  islocal " + isLocal );
			e.printStackTrace();
		}
		
		finally {
		 sql = null; 
			rs = null; 
			stms = null; 
			list = null; 
			annotation = null; 
		}	
		
	return grpName2fids;
	}

                       
       
    
       public static   String    retrieveGeneAttValue (Connection con, String [] valueids, boolean verbose , JspWriter out) {
       String nameString = ""; 
     if (valueids == null || valueids.length ==0) 
        return null; 
       int valueLength = valueids.length; 
		  String quote = "'"; 
		   String comma = ", "; 
		StringBuffer nameBuffer = new StringBuffer ();    
	   for (int i=0; i<valueLength; i++) {
       		nameBuffer.append(quote); 
		    nameBuffer.append(valueids[i]); 
		     nameBuffer.append(quote); 
		   if (i<valueLength-1) 
			nameBuffer.append(comma); 
	   }
	
	
	   nameString = nameBuffer.toString();  
       String sql = "select   distinct value from attValues where attValueId in (" + nameString + ") ";         
  
       ResultSet rs = null; 
       PreparedStatement stms = null;              
       String value = ""; 
	   StringBuffer vBuf = new StringBuffer (); 	   
	   try {       
        if (valueids != null && valueLength <=1000) {    
                stms = con.prepareStatement(sql);             
                rs = stms.executeQuery();             
               if (verbose) {  // verbose        
				  int count = 0;  
					while (rs.next()) { 
						if (count > 0) 
						vBuf.append(comma); 				
						vBuf.append(rs.getString(1));  
					}
				   value = vBuf.toString();
			   }
               else {  // terse mode
                   String lastValue = ""; 
                   int count = 0; 
                 while (rs.next())  {             
                     value  =  rs.getString(1);
                     if (count >0  && !value.equals(lastValue)) {
                         value = "varies"; 
                         break; 
                      }
                 
                     lastValue = value; 
                     count ++; 
                 }   
               }
       }
       else {
       String []   nameStrings = LffUtility.getFidStrings (valueids, LffConstants.BLOCK_SIZE);
             String lastValue = ""; 
                   int count = 0; 
           boolean isDiff = false; 
       for (int i=0; i<nameStrings.length; i++) {
       nameString = nameStrings [i]; 
       sql = "select  attValueId, value from attValues where attValueId in (" + nameString + ") ";         
       stms = con.prepareStatement(sql);             
       rs = stms.executeQuery(); 
         if (verbose) {  // verbose 
                while (rs.next())               
                value  = value +  ", " + rs.getString(1);  
               }
               else {  // terse mode
              
                 while (rs.next())  {             
                     value  =  rs.getString(1);
                     if (count >0  && !value.equals(lastValue)) {
                         value = "varies"; 
                         isDiff = true;
                         break; 
                      }
                 
                     lastValue = value; 
                     count ++; 
                 }   
               
               
               }
           if (isDiff) 
               break; 
       }      
       }                          
       rs.close(); 
       stms.close();
       } 
       catch (Exception e) {
       e.printStackTrace();
       }
       
       
       
       if (value != null && value.length() > 0 && value.indexOf(",")>=0) 
         value = value.substring(1); 
       return value; 
       }
    
    
    
       public static AnnotationDetail []  populateAVP (boolean verbose, Connection con,  AnnotationDetail [] annotations, HashMap groupName2Fids ,boolean isLocal,  JspWriter out ) {
            ArrayList fidList = getGroupFidList(annotations, groupName2Fids,isLocal, out); 
        try {
            if (fidList == null || fidList.isEmpty()) {    
                     
                return   annotations; 
            }
    
            int [] fids = new int [fidList.size()];
            for (int i=0; i<fids.length; i++) 
               fids [i] = Integer.parseInt((String) fidList .get(i)); 
            HashMap  fid2hash = AttributeRetriever.retrieveSmallNumAnnotationAVPs(con, fids);
            HashMap groupAVP = null;    
            HashMap annoAVP = null; 
  String varies = "varies"; 
        if (fid2hash != null  && annotations != null) {              
                for (int m=0; m<annotations.length; m++){     
                    String [] groupFids = null; 
                    ArrayList fidArrayList  = (ArrayList) groupName2Fids.get (annotations[m].getGname() + "_" +  annotations[m].getFtypeId() + "_" +  annotations[m].getRid() ); 
                    if (fidArrayList != null) 
                    groupFids =(String []) fidArrayList.toArray(new String [fidArrayList.size()] );  
                
                    groupAVP = new HashMap (); 
                    String groupValue  = null; 
                
                    if (groupFids == null|| groupFids.length==0) {
                        
                        continue;                        
                    }
                      
                    for (int j=0; j< groupFids.length; j++) {                        
                           if (annotations[m] != null  && fid2hash.get("" + groupFids[j] ) != null) {
                            annoAVP = (HashMap )fid2hash.get("" + groupFids[j] );  
                            int annoCount = 0;  
                           if (annoAVP != null && !annoAVP.isEmpty()) {
                               Iterator iterator = annoAVP.keySet().iterator(); 
                           
                                while (iterator.hasNext()) {
                                 annoCount ++;   
                                   String key = (String)iterator.next();   
                                   String value = (String)annoAVP.get(key); 
                                
                                    if (key == null || value == null)
                                        continue; 
                                
                                    if (verbose) {
                                         HashMap  map = new HashMap(); 
                                        if (groupAVP.get(key) != null) {
                                            map = (HashMap)groupAVP.get(key); 
                                           if (map.get(value) == null) 
                                              map.put(value, "y"); 
                                           
                                        }   
                                         else {
                                            map = new HashMap(); 
                                           map.put(value, "y"); 
                                        }
                                           groupAVP.put(key, map ) ; 
                                         
                                           // groupAVP.put(key, value ) ; 
                                        }
                                        else {  // terse mode 
                                            if (groupAVP.get(key) == null) {
                                                HashMap map  = new HashMap (); 
                                                map.put(value, "y");  
                                                groupAVP.put(key, map ) ; 
                                                //   groupAVP.put(key, value ) ;  
                                                groupValue = value; 
                                            }  
                                            else {                                   
                                               HashMap map =  (HashMap  )groupAVP.get(key);
                                               if (map.get(varies) != null) 
                                                 continue; 
                                              
                                             
                                               map.put(value, "y");  
                                                
                                                if (map.size() >1) {
                                              
                                                if (groupValue != null  && value.compareTo(groupValue)!= 0){                                          
                                                  
                                                //   map.clear(); 
                                                   map.put("varies", "y");  
                                                      groupAVP.put(key, map ) ; 
                                                  //  groupAVP.put(key, "varies"); 
                                                   
                                                }
                                                }
                                            }
                                         }                                   
                               }
                                 }  
                           
                             }
                         }
                
                       Iterator iterator = groupAVP.keySet().iterator(); 
                       while (iterator.hasNext()) {
                          String key = (String)iterator.next(); 
                          HashMap map = (HashMap)groupAVP.get(key); 
                           ArrayList list = new ArrayList (); 
                          if (map != null && !map.isEmpty()) {
                              String[] arr =(String[]) map.keySet().toArray(new String [map.size()]);
							  Arrays.sort(arr); 
							  String temp = ""; 
                              for (int n=0; n<arr.length; n++) 
							      temp = temp + "," + arr[n] ; 
							      if (temp.indexOf("," ) >= 0)
								    temp = temp.substring(temp.indexOf(",") + 1); 
								  list.add(temp); 
                          }
                           groupAVP.put (key, list) ; 
                       }
                        
                        annotations[m].setAvp(groupAVP);
                    }              
                
                    for (int i=0; i<annotations.length; i++) 
                        annotations[i].setlff2value();       
    
         }
                     }
               catch (Exception e) {e.printStackTrace();}     
           return annotations; 
        }
     
    
    
    
    
    
  
    
    
    
        public static AnnotationDetail []  mergeAnnotations  ( AnnotationDetail [] local,  AnnotationDetail [] share ) {
             if (local == null || local.length == 0) 
            return share; 
        
            if (share == null || share.length ==0) 
              return local; 
        
            if (share == null && local == null) 
               return null; 
        
             AnnotationDetail[] all = new AnnotationDetail [local.length + share.length]; 
                    
            for (int i=0; i<local.length; i++) 
            all[i] = local [i]; 
        
        
             for (int i=0; i<share.length; i++) 
            
              all [i+local.length] = share [i];   
       
            return all; 
        }
   
   
   
   
    public static  ArrayList   getGroupFidList ( AnnotationDetail [] annotations, HashMap map,  boolean isLocal, JspWriter out ) {
        ArrayList list = new ArrayList (); 
        ArrayList temp = null; 
        try {
            String key = null;  
            if (isLocal) {
                for (int i=0; i<annotations.length; i++) {
                key = annotations[i].getGname() + "_" + annotations[i].getFtypeId() + "_" + annotations[i].getRid(); 
                if (map.get(key) != null) {
                temp =(ArrayList) map.get(key); 
                if (temp!= null && !temp.isEmpty()) 
                for (int j=0; j<temp.size(); j++) 
                list.add((String)temp.get(j));  
                }
                }
            }
            else {                    
                for (int i=0; i<annotations.length; i++) {
                key = annotations[i].getGname()+ "_"+ annotations[i].getFtypeId() + "_" + annotations[i].getRid(); 
                if (map.get(key) != null) {
                temp =(ArrayList) map.get(key); 
                if (temp!= null && !temp.isEmpty()) 
                for (int j=0; j<temp.size(); j++) 
                list.add((String)temp.get(j));  
                }
                } 
            }              
        }
        catch (Exception e ) {
        e.printStackTrace();}
        return list; 
    }

    
    
    public static AnnotationDetail []  populateAnnotations ( AnnotationDetail [] annotations,    boolean isLocal,  Connection con, JspWriter out ) {
        if (annotations == null || annotations.length ==0) 
          return annotations; 
        
        
       String sql =   "SELECT  fstart, fstop, fscore, fphase, fstrand,  ftarget_start, ftarget_stop "
               +  "   FROM  fdata2 WHERE  gname = ? and ftypeid = ?  and rid = ? ";
               AnnotationDetail anno = null; 
  
       try {
             PreparedStatement stms = con.prepareStatement(sql);   
             ResultSet rs = null; 
             String grpName = null; 
           
            for (int i=0; i< annotations.length; i++) {
               anno = annotations[i]; 
          
                 grpName = anno.getGname();
              
                if (!isLocal && !anno.isShare() ) {
                    
                  continue; 
                }
               else if (isLocal && anno.isShare()) {
                   continue; 
                  }
               
            stms.setString(1, grpName);
            stms.setInt(2,  anno.getFtypeId());
            stms.setInt(3,  anno.getRid()); 
               
             rs = stms.executeQuery(); 
   
            long groupTStart = Long.MAX_VALUE; 
            long groupTStop = -1; 
            double groupScore = 0.0; 
            int [] grpStrand = null; 
            int [] grpPhase = new int [4] ; 
            int  grpCount = 0;  
               long grpStop = 0; 
              grpStrand = new int [2]; 
                    grpPhase = new int [4]; 
            while (rs.next()) {   
                grpCount ++;
              
                 if (anno.getStart() == 0 || rs.getLong(1) < anno.getStart())  
                anno.setStart(rs.getLong(1));
               
               
                if ( rs.getLong(2) > grpStop )
                 grpStop = rs.getLong(2); 
            
                
                groupScore += rs.getDouble(3);
            
                if (rs.getString(5).equals("+"))
                grpStrand [0] += 1; 
                else 
                grpStrand [1] += 1; 
            
                if(rs.getInt(4) == 0)
                grpPhase [0] += 1;  
            
                else  if (rs.getInt(4) == 1)
                grpPhase [1] += 1; 
                else if (rs.getInt(4) == 2)
                grpPhase [2] += 1;    
                else 
               grpPhase [3] += 1;  
            
                if (rs.getLong(6) < groupTStart )  
                groupTStart = rs.getLong(6); 
            
                if (rs.getLong(7) > groupTStop)
                groupTStop = rs.getLong(7);                    
             }
       
           anno.setStop(grpStop);  
           anno.setTargetStart(groupTStart);
                  anno.setTstart("" + groupTStart);
           anno.setTargetStop(groupTStop);  
                 anno.setTstop("" + groupTStop);  
           anno.setStrand((grpStrand[0] >= grpStrand[1]) ? "+" :"-"  );
            if (grpCount ==0)
              grpCount =1;
           double dscore = groupScore/grpCount ; 
           
           anno.setScore(dscore);  
             annotations[i] = anno;   
               
            }  
     if (rs != null ) 
       rs.close();
       stms.close();
       }
       catch (Exception e) {
       e.printStackTrace();
       }
       
       return annotations;
     
       }      
  
    
          public static  int [] getAnnoFids ( AnnotationDetail [] annotations, HashMap map, JspWriter out ) {
              if (annotations == null || annotations.length ==0) 
                     return null; 
                ArrayList list = new ArrayList (); 
                ArrayList temp = null; 
                   
                try {            
                    for (int i=0; i<annotations.length; i++) {
                        if (map.get(annotations[i].getGname()) != null) {
                            temp =(ArrayList) map.get(annotations[i].getGname()); 
                            list.addAll(temp);  
                        }
                    }
                 }
                catch (Exception e ) {e.printStackTrace();}
                return null; 
            }
    
    
           public static  AnnotationDetail []   setGrpAVP ( AnnotationDetail [] annotations, HashMap grpName2Fids, HashMap fid2Hash ) {        
               if (annotations == null || annotations.length ==0) 
                      return annotations; 
                    
              
                for (int i=0; i<annotations.length; i++) {
                    String name = annotations[i].getGname();
                    ArrayList  fidList  = (ArrayList)grpName2Fids.get(name + "_" +annotations[i].getFtypeId()  +"_" +  annotations[i].getRid()); 
                    HashMap grpAVP = new HashMap (); 
                     for (int j=0; j<fidList.size(); j++) {
                       String fid = (String)fidList.get(j); 
                       HashMap annoAVP = (HashMap)fid2Hash.get(fid); 
                       if (annoAVP!= null) {                       
                            if (j <= 0) 
                               grpAVP = annoAVP; 
                            else {
                             Iterator iterator = annoAVP.keySet().iterator();                 
                             while (iterator.hasNext()) {
                              String key = (String)iterator.next(); 
                                 String value = (String)annoAVP.get(key); 
                             if (grpAVP.get(key) != null)
                                  value =(String) grpAVP.get(key) + value;
                                grpAVP.put (key, value);  
                               } 
                           }                       
                       }                       
                    }
                  annotations[i].setAvp(grpAVP);   
                }
                return annotations; 
            }
    
    
        public static String maxPhase (int  [] arr) {
          if (arr == null) 
           return null;  
           int max = -1; 
            String phase = "0"; 
           int index = 0;  
            for (int i=0; i<arr.length ; i++) {
                if (arr[i] > max ) {
                    max = arr[i]; 
                    index = i; 
                }
            }
        
           if (index <3)
             phase = "" + index; 
            else 
            phase = "."; 
      
           return phase  ;  
        }
    
   
    
    
          public static AnnotationGroup  retrieveLargeAnnoGroup (int[] ftypeids, HashMap ftypeid2chromosome , Connection con, JspWriter out  ) {
              if (ftypeids == null || ftypeids.length ==0) 
                     return null; 
              AnnotationDetail [] annotations =  null;
            AnnotationGroup annoGroup = new AnnotationGroup(); 
                 HashMap groupName2fids = new HashMap ();  
              HashMap  groupName2annos = new HashMap ();  
                String sql =   "SELECT  fid, gname, rid FROM  fdata2 WHERE  ftypeid = ? ";
                    ResultSet rs = null; 
			  	PreparedStatement stms = null; 
			   try {
					 stms = con.prepareStatement(sql); 
						for (int i=0; i<ftypeids.length; i++) {
						stms.setInt(1, ftypeids[i]);
						ArrayList ridList = null; 
						
						rs = stms.executeQuery(); 
						String currentName = "";  
						
						AnnotationDetail anno = null; 
						ArrayList fidList = new ArrayList ();  
						String rid = null; 
						while (rs.next()) {  
						currentName = rs.getString(2);     
						rid = rs.getString(3);
						if ( groupName2fids.get(currentName + "_" + ftypeids[i] + "_" + rid) == null) {
						fidList = new ArrayList ();   
						anno = new AnnotationDetail (rs.getInt(1));
						anno.setFtypeId(ftypeids[i]);  
						anno.setRid(Integer.parseInt(rid)); 
						anno.setGname(currentName);  
						fidList.add(rs.getString(1)); 
						}
						else {
						fidList =(ArrayList) groupName2fids.get(currentName + "_" + ftypeids[i] + "_" + rid);                                  
						anno = (AnnotationDetail)groupName2annos.get(currentName + "_" + ftypeids[i] + "_" + rid); 
						fidList.add(rs.getString(1)); 
						}
						groupName2annos.put(currentName + "_" + ftypeids[i] + "_" + rid, anno); 
						groupName2fids.put(currentName + "_" + ftypeids[i] + "_" + rid, fidList); 
						}
                    }
				 if (rs != null)           
				   rs.close();
				   stms.close();
               }
               catch (Exception e) {
               e.printStackTrace();
               }
			  
			   finally {
				     if( groupName2annos.size() > 0) {
					annotations = (AnnotationDetail[])groupName2annos.values().toArray(new AnnotationDetail[groupName2annos.size()]);
					annoGroup.setAnnos(annotations); 
					annoGroup.setGroupName2Fids(groupName2fids);
					groupName2fids = null; 
					annotations = null; 
					groupName2annos = null;    				   
			   }        
			   }
            
			 
               return annoGroup;
               }
	
	
	
	
	public static AnnotationGroup  retrieveLargeAnnoGroupByChromosomalRegion  (int[] ftypeids, HashMap ftypeid2chromosome , Connection con,int rid,  long start, long stop,  JspWriter out  ) {
		  if (ftypeids == null || ftypeids.length ==0) 
				 return null; 
		  AnnotationDetail [] annotations =  null;
		AnnotationGroup annoGroup = new AnnotationGroup(); 
			 HashMap groupName2fids = new HashMap ();  
		  HashMap  groupName2annos = new HashMap ();  
			String sql =   "SELECT fid, gname  FROM  fdata2 WHERE  ftypeid = ? and rid = ? and fstart >= ? and fstop <= ? ";
				ResultSet rs = null;  
		   try {
				   PreparedStatement stms = con.prepareStatement(sql); 
				 for (int i=0; i<ftypeids.length; i++) {
					stms.setInt(1, ftypeids[i]);
					 
					stms.setInt(2, rid); 
					 stms.setLong(3, start);
					 stms.setLong(4, stop);
					 
					rs = stms.executeQuery(); 
						String currentName = "";  
                           
						AnnotationDetail anno = null; 
						ArrayList fidList = new ArrayList ();  
                         
						while (rs.next()) {  
							currentName = rs.getString(2);     
                               
							if ( groupName2fids.get(currentName + "_" + ftypeids[i] + "_" + rid) == null) {
								fidList = new ArrayList ();   
								anno = new AnnotationDetail (rs.getInt(1));
								anno.setFtypeId(ftypeids[i]);  
								anno.setRid(rid); 
								anno.setGname(currentName);  
								fidList.add(rs.getString(1)); 
							}
							else {
								fidList =(ArrayList) groupName2fids.get(currentName + "_" + ftypeids[i] + "_" + rid);                                  
								anno = (AnnotationDetail)groupName2annos.get(currentName + "_" + ftypeids[i] + "_" + rid); 
								fidList.add(rs.getString(1)); 
						   }
							groupName2annos.put(currentName + "_" + ftypeids[i] + "_" + rid, anno); 
							groupName2fids.put(currentName + "_" + ftypeids[i] + "_" + rid, fidList); 
						 }
				}
		 if (rs != null)           
		   rs.close();
		   stms.close();
		   }
		   catch (Exception e) {
		   e.printStackTrace();
		   }
            
		   if( groupName2annos.size() > 0) {
		   annotations = (AnnotationDetail[])groupName2annos.values().toArray(new AnnotationDetail[groupName2annos.size()]);
			annoGroup.setAnnos(annotations); 
			annoGroup.setGroupName2Fids(groupName2fids);
		   }        
		   return annoGroup;
		   }
		      
	
       public static AnnotationDetail [] retrieveGroupAnnotations (int ftypeid,   String className, int rid , String chr, String ftype, String subtype,  Connection con, JspWriter out  ) {
       if(ftypeid ==0) 
       return null; 
   
       ArrayList list = new ArrayList();        
       AnnotationDetail[] annotations = null;
        //HashMap groupName2fids = new HashMap ();  
   
       String sql =   "SELECT  fid, ftypeid, fstart, fstop, fscore, fphase, fstrand,  gname, ftarget_start, ftarget_stop "
 +  "   FROM  fdata2 WHERE  ftypeid = ? and rid = ? order by ftypeid, rid, gname  ";
       
		   String blank = ""; 
		   String plus = "+";
		   String minus = "-"; 
	   try {
               PreparedStatement stms = con.prepareStatement(sql);   
            stms.setInt(1, ftypeid);
            stms.setInt(2, rid);
            ResultSet rs = stms.executeQuery(); 
            String currentName = "";  
            String lastName = ""; 
            AnnotationDetail anno = null; 
            long groupStart = Long.MAX_VALUE; 
            long groupStop = -1; 
            long groupTStart = Long.MAX_VALUE; 
            long groupTStop = -1; 
            double groupScore = 0.0; 
            int [] grpStrand = null; 
            int [] grpPhase = new int [4] ; 
            int  grpCount = 0;  
            boolean init = true; 
           // ArrayList fidList = null; 
            while (rs.next()) {  
                currentName = rs.getString(8);   
               if ( !currentName.equals(lastName) ) {  
                    if (!init) {
                        anno.setStart(groupStart);
                        anno.setStop(groupStop);  
                        anno.setTargetStart(groupTStart);
                         anno.setTstart("" + groupTStart);
                        anno.setTargetStop(groupStop); 
                         anno.setTstop("" + groupStop); 
                        anno.setStrand((grpStrand[0] >= grpStrand[1]) ? plus :minus  );
						if (grpCount ==0)
						grpCount = 1; 
						double dscore = groupScore/grpCount; 
						anno.setScore(dscore);  
                     //   anno.setScore(groupScore/		      
                        anno.setPhase(maxPhase (grpPhase) );
                        anno.setChromosome(chr);
                        anno.setRid(rid);
                        anno.setFtypeId(ftypeid);
                        anno.setFmethod(ftype);
                        anno.setFsource(subtype);
                        anno.setTrackName(ftype+ ":" + subtype);
                        anno.setGclassName(className);
                      //  groupName2fids.put(lastName + "_" +ftypeid + "_"+rid  , fidList); 
                        list.add(anno); 
						
						anno = null; 
						
					}
                   // fidList = new ArrayList (); 
                    anno = new AnnotationDetail (rs.getInt(1)); 
                    lastName = currentName; 
                    anno.setFtypeId(ftypeid);  
                    anno.setRid(rid); 
                    anno.setGname(rs.getString(8));    
                    groupStart = Long.MAX_VALUE; 
                    groupStop  = -1; 
                    groupTStart = Long.MAX_VALUE; 
                    groupTStop  = -1; 
                    groupScore = 0; 
                    grpStrand = new int [2]; 
                    grpPhase = new int [4]; 
                    grpCount = 0;  
                    init = false; 
                }
				
			   //fidList.add(rs.getString(1));             
                grpCount ++;   
                if (rs.getLong(3) < groupStart )  
                groupStart = rs.getLong(3); 
            
                if (rs.getLong(4) > groupStop)
                groupStop = rs.getLong(4); 
            
                groupScore += rs.getDouble(5);
            
                if (rs.getString(7).equals("+"))
                grpStrand [0] += 1; 
                else 
                grpStrand [1] += 1; 
            
                if(rs.getInt(6) == 0)
                grpPhase [0] += 1;  
            
                else  if (rs.getInt(6) == 1)
                grpPhase [1] += 1; 
                else if (rs.getInt(6) == 2)
                grpPhase [2] += 1;    
                else 
                grpPhase [3] += 1;                		   
		   
                if (rs.getLong(9) < groupTStart )  
                groupTStart = rs.getLong(9); 
            
                if (rs.getLong(10) > groupTStop)
                groupTStop = rs.getLong(10);                    
             }
       
           anno.setStart(groupStart);
           anno.setStop(groupStop);         
           anno.setTargetStart(groupTStart);
           anno.setTargetStop(groupTStop); 
            anno.setTstart("" + groupTStart);
           anno.setTstop("" + groupTStop); 
            anno.setStrand((grpStrand[0] >= grpStrand[1]) ? plus :minus  );
           // set phase anno.setStrand((grpStrand[0] >= grpStrand[1]) ? "+" :"-"  );
          if (grpCount == 0) 
              grpCount = 1; 
     
        double dscore = groupScore/grpCount;
        anno.setScore(dscore); 
             anno.setPhase(maxPhase (grpPhase) );
                       anno.setChromosome(chr);
                       anno.setRid(rid);
                       anno.setFtypeId(ftypeid);
                       anno.setFmethod(ftype);
                       anno.setFsource(subtype);
                       anno.setTrackName(ftype+ ":" + subtype);
                       anno.setGclassName(className);
               
           list.add(anno);   
              //groupName2fids.put(lastName, anno); 
      if (rs!=null)     
       rs.close();
       stms.close();
	   }
       catch (Exception e) {
       e.printStackTrace();
       }
    
       if (list.size() > 0) {
       annotations = (AnnotationDetail[]) list.toArray(new AnnotationDetail[list.size()]);
		 list = null;   
	   }        
       return annotations;
  }
	
	
   
		// if multiple ftypeids , loop through the following function 
 
	public static AnnotationDetail [] retrieveGroupAnnotationsByChromosomeRegion (int ftypeid,  int rid, long start, long stop,  String className,  String chr, String ftype, String subtype,  Connection con, JspWriter out  ) {
		if(ftypeid ==0) 
		return null;    
		ArrayList list = new ArrayList();        
		AnnotationDetail[] annotations = null;
		HashMap groupName2fids = new HashMap ();  
          AnnotationDetail anno = null; 
			 long groupStart = Long.MAX_VALUE; 
			 long groupStop = -1; 
			 long groupTStart = Long.MAX_VALUE; 
			 long groupTStop = -1; 
			 double groupScore = 0.0; 
			 int [] grpStrand = null; 
			 int [] grpPhase = new int [4] ; 
			 int  grpCount = 0;  
			 boolean init = true; 
			 ArrayList fidList = null; 
		 String currentName = "";  
			 String lastName = ""; 
		String sql =   "SELECT  fid, ftypeid, fstart, fstop, fscore, fphase, fstrand,  gname, ftarget_start, ftarget_stop "
				+  "   FROM  fdata2 WHERE  ftypeid = ? and  rid = ? and fstart >= ? and fstop <= ?  order by ftypeid, rid, gname  ";
       
		try {
		     PreparedStatement stms = con.prepareStatement(sql);   
			 stms.setInt(1, ftypeid);
			 stms.setInt(2, rid);
			 stms.setLong(3, start);
			 stms.setLong(4, stop);
			 ResultSet rs = stms.executeQuery(); 
			 while (rs.next()) {  
				 currentName = rs.getString(8);   
				if ( !currentName.equals(lastName) ) {  
					 if (!init) {
						 anno.setStart(groupStart);
						 anno.setStop(groupStop);  
						 anno.setTargetStart(groupTStart);
						  anno.setTstart("" + groupTStart);
						 anno.setTargetStop(groupStop); 
						  anno.setTstop("" + groupStop); 
						 anno.setStrand((grpStrand[0] >= grpStrand[1]) ? "+" :"-"  );
							if (grpCount ==0)
							  grpCount = 1; 
							  double dscore = groupScore/grpCount; 
								   anno.setScore(dscore);  
					  //   anno.setScore(groupScore/grpCount);    
						 anno.setPhase(maxPhase (grpPhase) );
						 anno.setChromosome(chr);
						 anno.setRid(rid);
						 anno.setFtypeId(ftypeid);
						 anno.setFmethod(ftype);
						 anno.setFsource(subtype);
						 anno.setTrackName(ftype+ ":" + subtype);
						 anno.setGclassName(className);
						 groupName2fids.put(lastName + "_" +ftypeid + "_"+rid  , fidList); 
						 list.add(anno);   
					 }
					 fidList = new ArrayList (); 
					 anno = new AnnotationDetail (rs.getInt(1)); 
					 lastName = currentName; 
					 anno.setFtypeId(ftypeid);  
					 anno.setRid(rid); 
					 anno.setGname(rs.getString(8));    
					 groupStart = Long.MAX_VALUE; 
					 groupStop  = -1; 
					 groupTStart = Long.MAX_VALUE; 
					 groupTStop  = -1; 
					 groupScore = 0; 
					 grpStrand = new int [2]; 
					 grpPhase = new int [4]; 
					 grpCount = 0;  
					 init = false; 
				 }
				fidList.add(rs.getString(1));             
				 grpCount ++;   
				 if (rs.getLong(3) < groupStart )  
				 groupStart = rs.getLong(3); 
            
				 if (rs.getLong(4) > groupStop)
				 groupStop = rs.getLong(4); 
            
				 groupScore += rs.getDouble(5);
            
				 if (rs.getString(7).equals("+"))
				 grpStrand [0] += 1; 
				 else 
				 grpStrand [1] += 1; 
            
				 if(rs.getInt(6) == 0)
				 grpPhase [0] += 1;  
            
				 else  if (rs.getInt(6) == 1)
				 grpPhase [1] += 1; 
				 else if (rs.getInt(6) == 2)
				 grpPhase [2] += 1;    
				 else 
				 grpPhase [3] += 1;  
            
				 if (rs.getLong(9) < groupTStart )  
				 groupTStart = rs.getLong(9); 
            
				 if (rs.getLong(10) > groupTStop)
				 groupTStop = rs.getLong(10);                    
			  }
       
			if (anno != null) {
				anno.setStart(groupStart);
				anno.setStop(groupStop);         
				anno.setTargetStart(groupTStart);
				anno.setTargetStop(groupTStop); 
				anno.setTstart("" + groupTStart);
				anno.setTstop("" + groupTStop); 
				anno.setStrand((grpStrand[0] >= grpStrand[1]) ? "+" :"-"  );
			
			// set phase anno.setStrand((grpStrand[0] >= grpStrand[1]) ? "+" :"-"  );
			
		   if (grpCount == 0) 
			   grpCount = 1; 
     
		 double dscore = groupScore/grpCount;
		 anno.setScore(dscore); 
			  anno.setPhase(maxPhase (grpPhase) );
						anno.setChromosome(chr);
						anno.setRid(rid);
						anno.setFtypeId(ftypeid);
						anno.setFmethod(ftype);
						anno.setFsource(subtype);
						anno.setTrackName(ftype+ ":" + subtype);
						anno.setGclassName(className);
			
			list.add(anno);   
			   groupName2fids.put(lastName, anno);    }
	   if (rs!=null)     
		rs.close();
		stms.close();
		}
		catch (Exception e) {
		e.printStackTrace();
		}
    
		if (list.size() > 0) {
		annotations = (AnnotationDetail[]) list.toArray(new AnnotationDetail[list.size()]);
		}
		
		if (list != null) 
		list.clear();
		
		return annotations;
		}
    	
	
	
	
	
	
	
	public static AnnotationDetail [] retrieveGroupAnnotationsByChromosomeRegion (int ftypeid, int rid, long start, long stop, Connection con, JspWriter out  ) {
		if(ftypeid ==0) 
		return null;    
		ArrayList list = new ArrayList();        
		AnnotationDetail[] annotations = null;
		
		String sql =   "SELECT  fid, ftypeid, gname FROM  fdata2 WHERE  ftypeid = ? and rid = ? and fstart >= ? and fstop <= ?";       
		try {
			PreparedStatement stms = con.prepareStatement(sql);   
			 stms.setInt(1, ftypeid);
			 stms.setInt(2, rid);
			stms.setLong(3, start);
			stms.setLong(4, stop);
			ResultSet rs = stms.executeQuery(); 
			 String currentName = "";  
			 String lastName = ""; 
			 AnnotationDetail anno = null; 
			 long groupStart = Long.MAX_VALUE; 
			 long groupStop = -1; 
			 int  grpCount = 0;  
			 boolean init = true; 
			// ArrayList fidList = null; 
			 while (rs.next()) {  
				 currentName = rs.getString(3);   
				if ( !currentName.equals(lastName) ) {  
					 if (!init) {
						 anno.setStart(groupStart);
						 anno.setStop(groupStop);  

							if (grpCount ==0)
							  grpCount = 1; 
						 anno.setRid(rid);
						 anno.setFtypeId(ftypeid);
						 list.add(anno);   
					 }
					
					 anno = new AnnotationDetail (rs.getInt(1)); 
					 lastName = currentName; 
					 anno.setFtypeId(ftypeid);  
					 anno.setRid(rid); 
					 anno.setGname(rs.getString(3));    
				
					 grpCount = 0;  
					 init = false; 
				 }
				//fidList.add(rs.getString(1));             
				 grpCount ++;   
			
 			  }
       
		// set phase anno.setStrand((grpStrand[0] >= grpStrand[1]) ? "+" :"-"  );
		   if (grpCount == 0) 
			   grpCount = 1; 
     				anno.setRid(rid);
						anno.setFtypeId(ftypeid);
					list.add(anno);   
			//   groupName2fids.put(lastName, anno); 
	   if (rs!=null)     
		rs.close();
		stms.close();
		}
		catch (Exception e) {
		e.printStackTrace();
		}
    
		if (list.size() > 0) {
		annotations = (AnnotationDetail[]) list.toArray(new AnnotationDetail[list.size()]);
		list = null; 
		}
		
		
		
		return annotations;
		}
    	
	
	
	
	
	
	public static AnnotationDetail []  populateStart (Connection con,  AnnotationDetail []   annotations, JspWriter out )  {    
        String sql = "SELECT min(fstart) FROM  fdata2 WHERE  gname = ? and ftypeid = ? and rid = ? group by gname  ";        
        if ( annotations == null ||  annotations.length ==0) 
        return  annotations; 
        try {
        PreparedStatement stms = con.prepareStatement(sql); 
        ResultSet rs = null; 
        for (int i=0; i<annotations.length; i++) {       
        stms.setString(1, annotations[i].getGname());
          stms.setInt(2,  annotations[i].getFtypeId());
        stms.setInt(3,  annotations[i].getRid());
        rs = stms.executeQuery(); 
        if  (rs.next()) {  
        annotations[i].setStart (rs.getLong(1));           
        }       
        }
             if (rs!=null)     
        rs.close();
        stms.close();
        }
        catch (Exception e) {
        e.printStackTrace();
        }
    return  annotations; 
    }

    
    
    
    public static AnnotationDetail []  populateTargetStart (Connection con,  AnnotationDetail []   annotations, JspWriter out)  {
        if ( annotations == null ||  annotations.length ==0) 
        return  annotations; 
        String sql =   "SELECT min(ftarget_start) FROM fdata2 WHERE  gname =? and ftypeid=? and rid =? ";
        
        try {
            PreparedStatement stms = con.prepareStatement(sql); 
            ResultSet rs = null; 
            for (int i=0; i<annotations.length; i++) {       
            stms.setString(1, annotations[i].getGname());
            stms.setInt(2,  annotations[i].getFtypeId());
            stms.setInt(3,  annotations[i].getRid());
            rs = stms.executeQuery(); 
            if  (rs.next()) {  
                annotations[i].setTargetStart (rs.getLong(1));    
                annotations[i].setTstart (rs.getString(1));   
        }       
            }
            if (rs != null) 
            rs.close();
            stms.close();
        }
        catch (Exception e) {
        e.printStackTrace();
        }
        return  annotations; 
    }

        
            
    
    public static AnnotationDetail []  populateStop (Connection con,  AnnotationDetail []   annotations, JspWriter out )  {
        if ( annotations == null ||  annotations.length ==0) 
        return  annotations; 
        String sql = "SELECT max(fstop) FROM fdata2 WHERE gname = ? and ftypeid = ? and rid = ?";
        try {
            PreparedStatement stms = con.prepareStatement(sql); 
            ResultSet rs = null; 
             for (int i=0; i<annotations.length; i++) {   
                 stms.setString(1, annotations[i].getGname());
            stms.setInt(2,  annotations[i].getFtypeId());
            stms.setInt(3,  annotations[i].getRid());
            rs = stms.executeQuery(); 
            if  (rs.next()) {  
            annotations[i].setStop (rs.getLong(1));           
            }       
            }
             if (rs!=null)     
            rs.close();
            stms.close();
        }
        catch (Exception e) {
        e.printStackTrace();
        }
       return  annotations; 
    }
            
            
    
    
    public static AnnotationDetail []  populateTargetStop (Connection con,  AnnotationDetail []   annotations, JspWriter out )  {    
        if ( annotations == null ||  annotations.length ==0) 
        return  annotations; 
        
        String sql =   "SELECT max(ftarget_stop) FROM fdata2 WHERE gname=? and ftypeid=? and rid =?   ";
        
        try {
        PreparedStatement stms = con.prepareStatement(sql); 
        ResultSet rs = null; 
        for (int i=0; i<annotations.length; i++) {       
        stms.setString(1, annotations[i].getGname());
        stms.setInt(2,  annotations[i].getFtypeId());
        stms.setInt(3,  annotations[i].getRid());
        rs = stms.executeQuery(); 
        if  (rs.next()) {  
            annotations[i].setTargetStop (rs.getLong(1)); 
            annotations[i].setTstop (rs.getString(1));
        }
       
        }
             if (rs!=null)     
        rs.close();
        stms.close();
        }
        catch (Exception e) {
        e.printStackTrace();
        }
       return  annotations; 
    }
                
                
                            
    public static AnnotationDetail []  populateScore (Connection con,  AnnotationDetail []   annotations, JspWriter out )  {    
        if ( annotations == null ||  annotations.length ==0) 
        return  annotations; 
        
        String sql =   "SELECT avg(fscore)  FROM  fdata2 WHERE  gname  = ? and ftypeid = ? and rid = ?   ";
        
        try {
        PreparedStatement stms = con.prepareStatement(sql); 
        ResultSet rs = null; 
        for (int i=0; i<annotations.length; i++) {       
        stms.setString(1, annotations[i].getGname());
        stms.setInt(2,  annotations[i].getFtypeId());
        stms.setInt(3,  annotations[i].getRid());
        rs = stms.executeQuery(); 
        if  (rs.next()) {  
        annotations[i].setScore (rs.getDouble(1));           
        }       
        }
             if (rs!=null)     
        rs.close();
        stms.close();
        }
        catch (Exception e) {
        e.printStackTrace();
        }
       return  annotations; 
    }

    
    public static AnnotationDetail []  populateStrand (Connection con,  AnnotationDetail []   annotations, JspWriter out )  {    
            if ( annotations == null ||  annotations.length ==0) 
            return  annotations; 
            
            String sqlAll =   "SELECT count(*)   FROM  fdata2 WHERE  gname  = ? and ftypeid = ? and rid = ?   ";
            String sqlPlus =  "SELECT count(*)  FROM  fdata2 WHERE  gname  = ? and ftypeid = ? and rid = ? and fstrand = '+' ";
            
            try {
            PreparedStatement stmsAll = con.prepareStatement(sqlAll); 
            PreparedStatement stmsPlus = con.prepareStatement(sqlPlus); 
            ResultSet rsAll = null; 
            ResultSet rsPlus = null; 
            int total = 0; 
            int plusCount = 0; 
            for (int i=0; i<annotations.length; i++) {       
            stmsAll.setString(1, annotations[i].getGname());
            stmsAll.setInt(2,  annotations[i].getFtypeId());
            stmsAll.setInt(3,  annotations[i].getRid());
            rsAll = stmsAll.executeQuery(); 
            if  (rsAll.next()) {  
            total = rsAll.getInt(1);      
            }  
            stmsPlus.setString(1, annotations[i].getGname());
            stmsPlus.setInt(2, annotations[i].getFtypeId());
            stmsPlus.setInt(3, annotations[i].getRid());
            rsPlus = stmsPlus.executeQuery(); 
            if  (rsPlus.next()) {  
            plusCount = rsPlus.getInt(1);      
            }  
            
            
            if (total==0)   
            annotations[i].setStrand ("+");    
            else   {
            if (plusCount >= (total-plusCount))  annotations[i].setStrand ("+") ; 
            else annotations[i].setStrand ("-");  
            }
            }
            rsAll.close();
            stmsAll.close();
            rsPlus.close();
            stmsPlus.close();               
            }
            catch (Exception e) {
            e.printStackTrace();
            }
           return  annotations; 
    }
                
                                                                         

    public static AnnotationDetail []  populatePhase(Connection con,  AnnotationDetail []   annotations, JspWriter out )  {
            if ( annotations == null ||  annotations.length ==0) 
            return  annotations; 
            
            
            String sql =   "SELECT fphase  FROM  fdata2 WHERE  gname  = ? and ftypeid = ? and rid = ?";
            
            try {
            PreparedStatement stmsAll = con.prepareStatement(sql); 
            
            ResultSet rsAll = null; 
            
            int  phase = 0; 
            
            for (int i=0; i<annotations.length; i++) {    
            int a = 0;  
            int b = 0; 
            int c = 0; 
            stmsAll.setString(1, annotations[i].getGname());
            stmsAll.setInt(2,  annotations[i].getFtypeId());
            stmsAll.setInt(3,  annotations[i].getRid());
            rsAll = stmsAll.executeQuery(); 
            while  (rsAll.next()) {  
            phase = rsAll.getInt(1);  
            
            if (phase ==1)
            b++; 
            else if (phase ==2)
            c++;
            else 
            a++;
            }  
            int max = a; 
            if (b>max ) {
            max = b;
            phase = 1; 
            }
            if (c>max){ 
            //max = c; 
            phase = 2; 
            } 
            annotations[i].setPhase("" + phase) ; 
            
            }
            
            rsAll.close();
            stmsAll.close();
    
    }
    catch (Exception e) {
    e.printStackTrace();
    }
     return  annotations; 
    }
    
      
    
         public static HashMap retrieveFidText (Connection con, String [] fids, int ftypeid,JspWriter out  )  throws Exception {
          if(ftypeid ==0) 
           return null;
             
             
          if (fids ==null || fids.length ==0) 
             return null; 
             
			 
		
          HashMap fid2Text = new HashMap (); 
       
           String sql =  "SELECT text, textType FROM fidText WHERE fid = ? and  ftypeid = ?  ";           
           try {
			   
			   if (con == null || con.isClosed())
						 System.err.println("connection failed: GroupHelper.retrieveFidText"); 
  				 PreparedStatement stms = con.prepareStatement(sql);  
                 String text = null; 
                 String type = null; 
                  ResultSet rs = null; 
               
                for (int i=0; i<fids.length; i++) {
                stms.setString(1, fids[i]);
                stms.setInt(2, ftypeid);
               
                 rs = stms.executeQuery(); 
					  String [] arr = null;  
				while (rs.next()) {  
                    text = rs.getString(1);             
                    type = rs.getString(2);  
                    if (fid2Text.get("" + fids[i]) == null) {
                         arr = new String [2]; 
                        if (type.equals("t")) 
                            arr[0] =  text;  
                        else if (type.equals("s")) 
                           arr [1] =  text;  
                    
                        fid2Text.put ("" + fids[i], arr); 
                     }
                    else {
                        arr = (String [])fid2Text.get("" + fids[i]); 
                       if ( arr != null && arr.length ==2) {  
                        if (type.equals("t")) 
                            arr[0] =  text;  
                        else if (type.equals("s")) 
                           arr [1] =  text;  
                    
                        fid2Text.put ("" + fids[i], arr);  
                       }  
                    
                    }
					arr = null; 
					text = null; 
					type = null; 
				 }
               
                }
			   
			  
				if (rs!=null)     
            rs.close();
           stms.close();
           }
           catch (Exception e) {
           e.printStackTrace();
           }
           return fid2Text;
           }
        
            // if multiple ftypeids , loop through the following function 
        
    
     public static AnnotationGroup retrieveGroupAnnotations (int [] ftypeids,  HashMap ftype2classMap, HashMap ftypeid2trckNameArray,   HashMap rid2Chromes, HashMap ftypeid2rids ,   Connection con, JspWriter out  ) {
            AnnotationDetail[] annos = null; 
            AnnotationDetail [] annotations =  null;
            AnnotationGroup annoGroup = new AnnotationGroup(); 
            ArrayList annoList = new ArrayList (); 
            int totalNum = 0; 
            if (ftypeids == null || ftypeids.length==0) 
                 return null; 
         
            try{                      
        for (int i=0; i<ftypeids.length; i++) {
            int  ftypeid  = ftypeids[i]; 
            if(ftypeid ==0) 
            continue; 
            
            
            ArrayList ridList = null; 
            if (ftypeid2rids.get("" + ftypeid)!= null ) 
            ridList = (ArrayList) ftypeid2rids.get("" + ftypeid); 
            else {
                 continue; // no record in fdata2
            } 
        
            int [] rids = null;  
            if (!ridList.isEmpty()){
                rids = new int[ridList.size()]; 
                for (int j=0; j< ridList.size(); j++) {
                rids [j] = Integer.parseInt((String)ridList.get(j)) ; 
                } 
            } 
          ///  ridList.clear();
		///	ridList = null; 
		
			String fmethod = null; 
			String fsource = null; 
				
			if (rids != null && rids.length > 0) { 
                for (int j=0; j< ridList.size(); j++) {               
                String chr =  null; 
                    if (rid2Chromes.get("" + rids[j]) != null) 
                        chr  = (String) rid2Chromes.get("" + rids[j]); 
                String className = null; 
                     if (ftype2classMap.get("" + ftypeid) != null) 
                         className = (String)ftype2classMap.get("" + ftypeid);  
                    else 
                      className = ""; 
                
                String [] ftypeString = null; 
                    if (ftypeid2trckNameArray.get("" + ftypeid) != null) 
                      ftypeString = (String [])ftypeid2trckNameArray.get("" + ftypeid);
                
              
                   if (ftypeString != null && ftypeString != null){
                        fmethod = ftypeString[0];
                        fsource = ftypeString[1];
                   }
                   else {	
						fmethod = "";
						fsource = ""; 
                   }
            
                  annos = retrieveGroupAnnotations (ftypeid, className, rids[j], chr, fmethod, fsource, con, out) ; 
                  if (annos != null) {
                    annoList.add(annos); 
                    totalNum += annos.length;  
                  }                
                }  
            }                    
        }
            
          int currentIndex = 0; 
            annotations = new AnnotationDetail [totalNum]; 
            HashMap name2ids = new HashMap (); 
            ArrayList list = null; 
            String name = null; 
				String tab = "_"; 
				String key = null; 
				String blank = ""; 
			for (int i=0; i< annoList.size(); i++) {
                annos = (AnnotationDetail [])annoList.get(i);
                for (int j=0; j<annos.length;j++) {
                    annotations[currentIndex] = annos[j]; 
                    name = annos[j].getGname();
					key = name + tab +  annos[j].getFtypeId() + tab +  annos[j].getRid();
					 if (name2ids.get(key) == null ) {
                         list = new ArrayList (); 
                     }
                     else 
                       list = (ArrayList)name2ids.get(key);
                
                    list.add(blank + annos[j].getFid()); 
                    name2ids.put(key , list);  
                    currentIndex ++; 
					list = null; 
					key = null; 
				}    
            }
				
		   annoGroup.setAnnos(annotations); 
           annoGroup.setGroupName2Fids(name2ids);
	       annotations = null; 
		   name2ids = null; 	
		 }
         catch (Exception e) {
                e.printStackTrace();
         } 
		 
		 if (annoList != null) 
		 annoList.clear();
		 annoList = null; 
		 
		   return annoGroup;                                                                   
       }
	
	
	
	
	
	
	public static AnnotationGroup retrieveGroupAnnotationsByChromosomeRegion  (int [] ftypeids, int rid, long start, long stop ,  HashMap ftype2classMap, HashMap ftypeid2trckNameArray,   HashMap rid2Chromes, HashMap ftypeid2rids ,   Connection con, JspWriter out  ) {
	AnnotationDetail[] annos = null; 
	AnnotationDetail [] annotations =  null;
	AnnotationGroup annoGroup = new AnnotationGroup(); 
	ArrayList annoList = new ArrayList (); 
	int totalNum = 0; 
	int ftypeid = 0; 
	String chr =  null; 
	String className = null; 
	String [] ftypeString = null;
	String fmethod = null; 
	String fsource = null; 
	String blank = ""; 
	String key = null; 
	String tab = "-"; 
	if (ftypeids == null || ftypeids.length==0) 
	return null; 
    try{                      
		for (int i=0; i<ftypeids.length; i++) {
		    ftypeid  = ftypeids[i]; 
			if(ftypeid ==0) 
			continue; 
			 chr =  null; 
			if (rid2Chromes.get("" + rid) != null) 
			chr  = (String) rid2Chromes.get("" + rid); 
			
			 className = null; 
			if (ftype2classMap.get("" + ftypeid) != null) 
			className = (String)ftype2classMap.get("" + ftypeid);  
			else 
			className = ""; 
			
			 ftypeString = null; 
			if (ftypeid2trckNameArray.get("" + ftypeid) != null) 
			ftypeString = (String [])ftypeid2trckNameArray.get("" + ftypeid);
			
			 fmethod = null; 
			 fsource = null; 
			if (ftypeString != null && ftypeString != null){
			fmethod = ftypeString[0];
			fsource = ftypeString[1];
			}
			else{
				fmethod = blank;
				fsource = blank; 
			}
 			annos = retrieveGroupAnnotationsByChromosomeRegion ( ftypeid,  rid , start, stop, className,chr,  fmethod, fsource,  con, out) ; 
			if (annos != null) {
			annoList.add(annos); 
			totalNum += annos.length;  
			}                
		   }
            
			 int currentIndex = 0; 
			   annotations = new AnnotationDetail [totalNum]; 
			   HashMap name2ids = new HashMap (); 
			   ArrayList list = null; 
			   String name = null; 
			   for (int i=0; i< annoList.size(); i++) {
				   annos = (AnnotationDetail [])annoList.get(i);
				   for (int j=0; j<annos.length;j++) {
					   annotations[currentIndex] = annos[j]; 
					   name = annos[j].getGname();
					   key = name+ tab +  annos[j].getFtypeId() + tab +  annos[j].getRid(); 
						if (name2ids.get(key) == null ) {
							list = new ArrayList (); 
						}
						else 
						  list = (ArrayList)name2ids.get(key);
                
					   list.add(tab + annos[j].getFid()); 
					   name2ids.put(key , list);  
					   currentIndex ++; 
					   key = null;
					   list = null; 
				   }    
			   }  
			  annoGroup.setAnnos(annotations); 
			  annoGroup.setGroupName2Fids(name2ids);
		       annotations = null; 
		    name2ids = null; 
		if (annoList != null) 
		  annoList.clear();
		   annoList = null; 
			}
			catch (Exception e) {
				   e.printStackTrace();
			}       
			  return annoGroup;                                                                   
}
		
	
	
	
	
	public static AnnotationGroup retrieveGroupAnnotationsByChromosomeRegion (int [] ftypeids,  int rid, long start, long stop , Connection con , JspWriter out) {
		AnnotationDetail[] annos = null; 
		AnnotationDetail [] annotations =  null;
		AnnotationGroup annoGroup = new AnnotationGroup(); 
		ArrayList annoList = new ArrayList (); 
		int totalNum = 0; 
		if (ftypeids == null || ftypeids.length==0) 
		return null; 
		 int ftypeid = 0; 
		try{                      
		for (int i=0; i<ftypeids.length; i++) {
			 ftypeid  = ftypeids[i]; 
			annos = retrieveGroupAnnotationsByChromosomeRegion(ftypeid, rid, start, stop, con, out); 
			if (annos != null) {
				annoList.add(annos); 
				totalNum += annos.length;  
			}  
			annos = null; 
		}  
	String key = null; 	
			String tab = "-"; 
	int currentIndex = 0; 
	annotations = new AnnotationDetail [totalNum]; 
	HashMap name2ids = new HashMap (); 
	ArrayList list = null;                
	String name = null; 
	for (int i=0; i< annoList.size(); i++) {
	annos = (AnnotationDetail [])annoList.get(i);
	for (int j=0; j<annos.length;j++) {
	annotations[currentIndex] = annos[j]; 
	name = annos[j].getGname();
		key = name+ tab +  annos[j].getFtypeId() + tab +  annos[j].getRid(); 
						
	if (name2ids.get(key) == null ) {
	list = new ArrayList (); 
	}
	else 
	list = (ArrayList)name2ids.get(key);
	
	list.add("" + annos[j].getFid()); 
	name2ids.put(key, list);  
	currentIndex ++; 
		list = null; 
	}    
	}  
	annoGroup.setAnnos(annotations); 
	annoGroup.setGroupName2Fids(name2ids);
	}
	catch (Exception e) {
	e.printStackTrace();
	}  
	
	annoList = null; 
	
	return annoGroup;                                                                   
}
           	
	
	
	
	public static HashMap mapftypeid2chromsome ( Connection con, JspWriter out ) {
        String sql =   "SELECT  distinct ftypeid, rid FROM  fdata2  order by ftypeid, rid ";  
        
            HashMap map = new HashMap (); 
          try {
           PreparedStatement stms = con.prepareStatement(sql);              
          ResultSet rs = stms.executeQuery(); 
           ArrayList list  = null;  
          while (rs.next()) {  
              if (map.get(rs.getString(1)) == null ) {
                  list = new ArrayList (); 
              }
              else {
                  list = (ArrayList) map.get(rs.getString(1)); 
              }
              list.add(rs.getString(2)); 
              map.put(rs.getString(1), list); 
          } 
            if (rs!=null)            
          rs.close();
          stms.close();
			  if (list != null ) 
			   list.clear();
			  list = null; 
		  }
          catch (Exception e) {
          e.printStackTrace();
          }
           return  map ;
          }

}
