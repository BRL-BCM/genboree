package org.genboree.tabular;

import org.genboree.editor.AnnotationDetail;

import javax.servlet.jsp.JspWriter;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Connection;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;

/**
 * User: tong
 * Date: Sep 20, 2007
 * Time: 2:52:39 PM
 */
public class AnnotationRetriever {
	public static   String  [][]  retrieveFidStringType(Connection con, int[] ftypeids, int total , String name , JspWriter out) {
		if (ftypeids == null || ftypeids.length == 0)
			return null;  Date date1 = new Date(); 
		String sql = "SELECT fid, " + name + "   FROM  fdata2 WHERE  ftypeid ";
		String [][] arr = new String [total][2];   
		try {
			String ftypeidString = "";
			for (int i = 0; i < ftypeids.length - 1; i++)
				ftypeidString = ftypeidString + "'" + ftypeids[i] + "', ";
			ftypeidString = ftypeidString + "'" + ftypeids[ftypeids.length - 1] + "'";
			if (ftypeids.length == 1)
				sql = sql + "=" + ftypeids[0] + "  order by  "  + name;
			else if (ftypeids.length > 1)
				sql = sql + " in ( " + ")  order by " + name ;
			PreparedStatement stms = con.prepareStatement(sql);
			ResultSet rs = stms.executeQuery();

			int i = 0; 
			while (rs.next() && i < total) {
				arr[i][0] = rs.getString(1);
			   arr[i][1] = rs.getString(2);
				i++; 
			}
			rs.close();
			stms.close();
		}
		catch (Exception e) {
			e.printStackTrace();
		}
		return arr;
	}
	              
	
	public static   long [][]  retrieveFidLongType(Connection con, int[] ftypeids, int total , String name , JspWriter out) {
		if (ftypeids == null || ftypeids.length == 0)
			return null;  Date date1 = new Date(); 
		String sql = "SELECT fid, " + name + "   FROM  fdata2 WHERE  ftypeid ";
		long [][] arr = new long[total][2];   
		try {
			String ftypeidString = "";
			for (int i = 0; i < ftypeids.length - 1; i++)
				ftypeidString = ftypeidString + "'" + ftypeids[i] + "', ";
			ftypeidString = ftypeidString + "'" + ftypeids[ftypeids.length - 1] + "'";
			if (ftypeids.length == 1)
				sql = sql + "=" + ftypeids[0] + "  order by  "  + name;
			else if (ftypeids.length > 1)
				sql = sql + " in ( " + ")  order by " + name ;
		
			PreparedStatement stms = con.prepareStatement(sql);
			ResultSet rs = stms.executeQuery();

			int i = 0; 
			while (rs.next() && i < total) {
				arr[i][0] = rs.getLong(1);
			   arr[i][1] = rs.getLong(2);
				i++; 
			}
			rs.close();
			stms.close();
		}
		catch (Exception e) {
			e.printStackTrace();
		}
		return arr;
	}

	public static AnnotationDetail [] getAnnosByStart (Connection con, Connection sharedConnection,int numLocalAnnos, int numShareAnnos,  int [] localftypeids, int[] shareftypeids, JspWriter out) { 
		long  [][]  a1 = retrieveFidLongType(con, localftypeids,  numLocalAnnos, "fstart", out);
		long  [][] a2 =	retrieveFidLongType(sharedConnection, shareftypeids,  numShareAnnos, "fstart", out);
		int totalNumAnnotations = numShareAnnos + numLocalAnnos; 
		AnnotationDetail[] totalAnnotations = new AnnotationDetail[totalNumAnnotations];
		if (numLocalAnnos > 0) {
		for (int i = 0; i < numLocalAnnos; i++) {
		totalAnnotations[i] =  new AnnotationDetail ((int)a1[i][0]);   
		totalAnnotations[i].setStart(a1[i][1]);; 
		}
		}
		if (a2 != null && a2.length  > 0) {
		for (int i = 0; i < a2.length; i++) {
		totalAnnotations[i + numLocalAnnos] = new AnnotationDetail ((int)a2[i][0]);
		totalAnnotations[i].setStart(a2[i][1]);
		totalAnnotations[i].setShare(true); 
		}} 
		return totalAnnotations ; 
	}

   public static AnnotationDetail [] getAnnosByStop(Connection con, Connection sharedConnection,int numLocalAnnos, int numShareAnnos,  int [] localftypeids, int[] shareftypeids, JspWriter out) { 
				long  [][]  a1 = retrieveFidLongType(con, localftypeids,  numLocalAnnos, "fstop", out);
				long  [][] a2 =	retrieveFidLongType(sharedConnection, shareftypeids,  numShareAnnos, "fstop", out);
				int totalNumAnnotations = numShareAnnos + numLocalAnnos; 
				AnnotationDetail[] totalAnnotations = new AnnotationDetail[totalNumAnnotations];
				if (numLocalAnnos > 0) {
				for (int i = 0; i < numLocalAnnos; i++) {
				totalAnnotations[i] =  new AnnotationDetail ((int)a1[i][0]);   
				totalAnnotations[i].setStop(a1[i][1]);
				}
				}
				if (a2 != null && a2.length  > 0) {
				for (int i = 0; i < a2.length; i++) {
				totalAnnotations[i + numLocalAnnos] = new AnnotationDetail ((int)a2[i][0]);
				totalAnnotations[i].setStop(a2[i][1]);
				totalAnnotations[i].setShare(true); 
				}}       
				
				return totalAnnotations ; 
		}	
	

	
	public static AnnotationDetail [] getAnnosByTargetStart (Connection con, Connection sharedConnection,int numLocalAnnos, int numShareAnnos,  int [] localftypeids, int[] shareftypeids, JspWriter out) { 
		long  [][]  a1 = retrieveFidLongType(con, localftypeids,  numLocalAnnos,"ftarget_start" , out);
		long  [][] a2 =	retrieveFidLongType(sharedConnection, shareftypeids,  numShareAnnos, "ftarget_start", out);
		int totalNumAnnotations = numShareAnnos + numLocalAnnos; 
		AnnotationDetail[] totalAnnotations = new AnnotationDetail[totalNumAnnotations];
			if (numLocalAnnos > 0) {
				for (int i = 0; i < numLocalAnnos; i++) {
					totalAnnotations[i] =  new AnnotationDetail ((int)a1[i][0]);   
					totalAnnotations[i].setTargetStart(a1[i][1]);; 
					}
			}
			if (a2 != null && a2.length  > 0) {
				for (int i = 0; i < a2.length; i++) {
					totalAnnotations[i + numLocalAnnos] = new AnnotationDetail ((int)a2[i][0]);
						totalAnnotations[i].setTargetStart(a2[i][1]);
					totalAnnotations[i].setShare(true); 
				}} 
	        
			 return totalAnnotations ; 
		}
	
   public static AnnotationDetail [] getAnnosByTargetStop(Connection con, Connection sharedConnection,int numLocalAnnos, int numShareAnnos,  int [] localftypeids, int[] shareftypeids, JspWriter out) { 
			long  [][]  a1 = retrieveFidLongType(con, localftypeids,  numLocalAnnos, "ftarget_stop", out);
			long  [][] a2 =	retrieveFidLongType(sharedConnection, shareftypeids,  numShareAnnos, "ftarget_stop", out);
			int totalNumAnnotations = numShareAnnos + numLocalAnnos; 
			AnnotationDetail[] totalAnnotations = new AnnotationDetail[totalNumAnnotations];
			if (numLocalAnnos > 0) {
			for (int i = 0; i < numLocalAnnos; i++) {
			totalAnnotations[i] =  new AnnotationDetail ((int)a1[i][0]);   
			totalAnnotations[i].setTargetStop(a1[i][1]);; 
			}
			}
			if (a2 != null && a2.length  > 0) {
			for (int i = 0; i < a2.length; i++) {
			totalAnnotations[i + numLocalAnnos] = new AnnotationDetail ((int)a2[i][0]);
			totalAnnotations[i].setTargetStop(a2[i][1]);
			totalAnnotations[i].setShare(true); 
			}} 
			
			return totalAnnotations ; 
		}	
  


	public static int   countAnnotationsByChromosomeFtypeids(Connection con, int []  ftypeids, int rid , long start, long stop) {
		   if (ftypeids == null || ftypeids.length ==0) 
		   return 0; 
        
		   String sql = null; 
		   String ftypeidString = "";   
		   for (int i=0; i<ftypeids.length -1; i++) 
		   ftypeidString = ftypeidString + "'" +  ftypeids[i] + "', ";  
		   ftypeidString = ftypeidString + "'" +  ftypeids[ftypeids.length-1] + "'";  
		   boolean hasChromosome = false; 
		   boolean hasStart = false; 
		   boolean hasStop = false;         
		   sql = "select count(*) from fdata2 where ftypeid in (" + ftypeidString+ ") and rid = ? and fstart >= ? and fstop <= ?  ";
	         
		   int totalNumAnno = 0;   
		   try {
			   PreparedStatement stms = con.prepareStatement(sql); 
			   stms.setInt(1, rid);
			   if(hasStart) 
			   stms.setLong(2, start );
			   else  // use default 
			   stms.setInt(2, 1); 
			   stms.setLong(3,stop);
			   ResultSet rs = stms.executeQuery();
			   if (rs.next()) 
			   totalNumAnno = rs.getInt(1);   
			  if (rs != null) 
				  rs.close(); 
			   stms.close(); 
		   }
		   catch (Exception e) {
		   e.printStackTrace();
		   System.err.println(sql); 
		   }
		   return totalNumAnno; 
	   };   


	public static String [] retrieveFidByChromosomeFtypeids(Connection con,  int  [] ftypeids, int rid, long start, long stop) {
			  ArrayList list = new ArrayList ();     
			  if(ftypeids == null || ftypeids.length ==0) 
			  return null;               
			  String ftypeidString = "";   
			  for (int i=0; i<ftypeids.length -1; i++) 
			  ftypeidString = ftypeidString + "'" +  ftypeids[i] + "', ";  
			  ftypeidString = ftypeidString + "'" +  ftypeids[ftypeids.length-1] + "'";     
			  String sql = "SELECT fid  FROM  fdata2 WHERE  rid = ? and fstart >= ? and fstop <=? and  ftypeid in (" +  ftypeidString  +  " ) ";
			  try {     
				PreparedStatement stms = con.prepareStatement(sql);              
				stms.setInt(1, rid); 
				stms.setLong(2, start);
				stms.setLong(3, stop);
				  
				  
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
			  return  (String [])list.toArray(new String [list.size()]);
		  } 
	
	public static AnnotationDetail[] retrieveSortAnnotationsByChromosomeFtypeids(Connection con,  int [] ftypeids,  int rid, long start, long stop, ArrayList sortList,  String [] sortNames, HashMap ftypeid2ftype, HashMap ftypeid2Gclass, HashMap chromosomeMap) {
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
	"  FROM  fdata2 WHERE  ftypeid in (" +  ftypeidString  +  " )  and rid = ? and fstart >= ? and fstop <= ?  ";
	if (sortNames != null && sortNames.length >0) 
	sql =  sql + "  order by " + orderString ;
	try {
		PreparedStatement stms = con.prepareStatement(sql);              
		stms.setInt(1, rid);
		stms.setLong(2, start);
		stms.setLong(3, stop);
		ResultSet rs = stms.executeQuery();    
		while (rs.next()) {        
			AnnotationDetail anno = new AnnotationDetail(rs.getInt(1));                    
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
	return annotations;
	}
			 

	public static String [][] retrieveNonSortFidAttByChromosomeRegion(Connection con,  int [] ftypeids,  int count, int rid, long start, long stop) {
    if(ftypeids == null || ftypeids.length ==0) 
    return null; 
    
    String ftypeidString = "";   
    for (int i=0; i<ftypeids.length -1; i++) 
        ftypeidString = ftypeidString + "'" +  ftypeids[i] + "', ";  
    ftypeidString = ftypeidString + "'" +  ftypeids[ftypeids.length-1] + "'";     
    
    String sql =   "SELECT fid   FROM  fdata2 WHERE  ftypeid in (" +  ftypeidString  +  " ) and rid = ? and fstart >= ? and fstop <= ?  ";
    
    String [][] fidatt = new String [count][1]; 
    try {     
        PreparedStatement stms = con.prepareStatement(sql);              
	    stms.setInt(1, rid);
		 stms.setLong(2, start); 
		stms.setLong(3, stop);
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
    return fidatt;
} 

	
	public static String [][] retrieveFidAttByChromosomeRegion(Connection con,  int [] ftypeids, String sortName, int rid, long start, long stop) {
			   ArrayList list = new ArrayList ();     
			   if(ftypeids == null || ftypeids.length ==0) 
			   {
				   System.err.println ("  AttributeRetriver.retrieveFidAtt:  passed ftype id is null "); 
				   return null; 
            
			   }
        
        String ftypeidString = "";   
        for (int i=0; i<ftypeids.length -1; i++) 
        ftypeidString = ftypeidString + "'" +  ftypeids[i] + "', ";  
        ftypeidString = ftypeidString + "'" +  ftypeids[ftypeids.length-1] + "'";     
        String sql =   "SELECT fid   FROM  fdata2 WHERE  ftypeid in (" +  ftypeidString  +  " ) and rid = ? and fstart >= ? and fstop <= ?  ";
        String arr[] =  new String [1]; 
        if (sortName != null) {
        sql = "SELECT fid, " +  sortName  + 
        "  FROM  fdata2 WHERE  ftypeid in (" +  ftypeidString  +  " )  and rid = ? and fstart >= ? and fstop <= ?  ";
        sql =  sql + "  order by " + sortName ;
        }
        
        try {
        PreparedStatement stms = con.prepareStatement(sql);   
			
			stms.setInt(1, rid); 
			stms.setLong(2, start); 
			stms.setLong(3, stop);
			
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
        return  (String [][] )list.toArray(new String [list.size()][2]);
    } 
	  
	public static String [] retrieveFidByFtypeid(Connection con,  int  ftypeid) {
			ArrayList list = new ArrayList ();     
		             
			 
			String sql = "SELECT fid  FROM  fdata2 WHERE  ftypeid = ? ";
			try {     
			PreparedStatement stms = con.prepareStatement(sql);
				stms.setInt(1, ftypeid);
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
			return  (String [])list.toArray(new String [list.size()]);
		} 
	
	public static String [] retrieveFidByFtypeidChrom(Connection con,  int  ftypeid, int rid, long start, long stop) {
				ArrayList list = new ArrayList ();     
				String sql = "SELECT fid  FROM  fdata2 WHERE  ftypeid = ? and rid = ? and fstart >= ? and fstop <= ?";
				try {     
				PreparedStatement stms = con.prepareStatement(sql);
			    stms.setInt(1, ftypeid);
					stms.setInt(2, rid);
					stms.setLong(3, start); 
					stms.setLong(4, stop);
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
				return  (String [])list.toArray(new String [list.size()]);
			} 
		
	  public static AnnotationDetail[] retrieveAnnotationsByChromosomeRegion(Connection con, int rid, long start, long stop ,  int [] fids, HashMap ftypeid2ftype, HashMap id2chrom  ) {
          if (fids == null || fids.length <1)  return null; 
		  if (rid <= 0 || start <=0  || stop <= 0) return null; 
			
	   ArrayList list = new ArrayList();        
		AnnotationDetail[] annotations = null;
		String qString = "";   
		for (int i=0; i<fids.length -1; i++) 
		qString = qString + "?,";  
		qString = qString + "?";  
		String sql = "SELECT fid, ftypeid, fstart, fstop, fscore, fphase, " +
		" fstrand, gname,  ftarget_start, ftarget_stop, fbin, rid " +
		"  FROM  fdata2 WHERE   fid in (" +  qString  +  " ) and  rid = ? and fstart >= ? and fstop <= ?   ";
     
    try {
        PreparedStatement stms = con.prepareStatement(sql);
		stms.setInt(1, rid); 
		stms.setLong(2, start); 
		stms.setLong(3, stop);
		for (int i=0; i<fids.length; i++) 
		  stms.setInt(i+4, fids[i]);
		  System.err.println(sql); 
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
return annotations;
}      

}
