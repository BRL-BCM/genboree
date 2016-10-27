package org.genboree.tabular;
import org.apache.commons.validator.routines.DateValidator;
import org.apache.commons.validator.routines.DoubleValidator;
import org.apache.commons.validator.routines.LongValidator;
import org.genboree.editor.AnnotationDetail;

import java.sql.Connection;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Date;
import java.util.HashMap;

/**
 * User: tong
 * Date: Jan 30, 2007
 * Time: 4:10:32 PM
 */
public class AnnotationSorter {

    public static HashMap sortAnnotationsByStart (AnnotationDetail [] annotations) {
    HashMap att2Anno = new HashMap ();          
    String  attrribute = null; 
    ArrayList annoList = null; 
    long [] starts = new long [annotations.length]; 
    int count = 0; 
    for (int i=0; i<annotations.length; i++) {
    attrribute = "" + annotations[i].getStart(); 

        if (attrribute == null)
                       attrribute = "" + Long.MAX_VALUE;
              
    if (att2Anno.get(attrribute) != null)            
    annoList = (ArrayList)att2Anno.get(attrribute);     
    else {
    annoList = new ArrayList (); 
    starts[count] = annotations[i].getStart(); 
    count ++; 
    }

    annoList.add(annotations[i]); 
    att2Anno.put (attrribute, annoList); 
    }
    String [] attributes  = (String [])att2Anno.keySet().toArray(new String [att2Anno.size()] );
    long [] intAtt = new long [attributes.length] ; 
    for (int i=0; i<intAtt.length; i++) {           
    intAtt [i] =  starts[i];              
    }        
    Arrays.sort (intAtt);     

    HashMap index2Anno = new HashMap (); 
    for (int i=0; i<intAtt.length; i++) {
    index2Anno.put("" + i, att2Anno.get("" + intAtt[i]) ); 
    }
    return index2Anno;  
    } 
    
    
    public static HashMap sortAnnotationsByStop (AnnotationDetail [] annotations ) {
      HashMap att2Anno = new HashMap ();       
        String  attrribute = null; 
        ArrayList annoList = null; 
        long [] starts = new long [annotations.length]; 
        int count = 0; 
        for (int i=0; i<annotations.length; i++) {
        attrribute = "" + annotations[i].getStop(); 
        
     
            if (attrribute == null)
                           attrribute = "" + Long.MAX_VALUE;
               
            
        if (att2Anno.get(attrribute) != null)            
        annoList = (ArrayList)att2Anno.get(attrribute);     
        else {
        annoList = new ArrayList (); 
        starts[count] = annotations[i].getStop(); 
        count ++; 
        }
        
        annoList.add(annotations[i]); 
        att2Anno.put (attrribute, annoList); 
        }
        String [] attributes  = (String [])att2Anno.keySet().toArray(new String [att2Anno.size()] );
        long [] intAtt = new long [attributes.length] ; 
        for (int i=0; i<intAtt.length; i++) {           
        intAtt [i] =  starts[i];              
        }        
        Arrays.sort (intAtt);             
         HashMap index2Anno = new HashMap (); 
    for (int i=0; i<intAtt.length; i++) {
    index2Anno.put("" + i, att2Anno.get("" + intAtt[i]) ); 
    }
    return index2Anno;  
    }  
   
    public static HashMap  sortAnnotationsByScore (AnnotationDetail [] annotations ) {
        HashMap att2Anno = new HashMap ();       
         String  attrribute = null; 
         ArrayList annoList = null; 
        int count = 0; 
        double [] scores = new double [annotations.length]; 
        for (int i=0; i<annotations.length; i++) {
        attrribute = "" + annotations[i].getScore(); 
            
     
            if (attrribute == null)
                           attrribute = ""  + Double.MAX_VALUE;
               
            
        if (att2Anno.get(attrribute) != null)            
        annoList = (ArrayList)att2Anno.get(attrribute);     
        else  {
        annoList = new ArrayList (); 
            scores[i] =   annotations[i].getScore(); 
        count ++; 
        }
        annoList.add(annotations[i]); 
        att2Anno.put (attrribute, annoList); 
        }
    
        String [] attributes  = (String [])att2Anno.keySet().toArray(new String [att2Anno.size()] );
    
        double []  doubles = new double [attributes.length] ; 
        for (int i=0; i<doubles.length; i++) {           
          doubles [i] =  Double.parseDouble(attributes[i]);              
        }        
        Arrays.sort (doubles);  
      HashMap index2Anno = new HashMap (); 
    for (int i=0; i<doubles.length; i++) {
    index2Anno.put("" + i, att2Anno.get("" + doubles[i]) ); 
    }
    return index2Anno;  
    }  
    
    
   
     public static HashMap sortAnnotationsByAVPSortName(String sortName, AnnotationDetail [] annotations ) {      
            HashMap att2Anno = new HashMap ();     
            String  attrribute = null; 
            for (int i=0; i<annotations.length; i++) {
                HashMap avpMap = annotations[i].getAvp();
               
                if (avpMap.get(sortName) != null)
                    attrribute =(String) ((ArrayList )avpMap.get(sortName)).get(0);  
                else 
                    attrribute = "zzzzzz"; 
               
				//attrribute = attrribute.trim(); 
				if (attrribute.length() ==0) 
				   attrribute = "zzzzzz"; 
				
				
				 ArrayList annoList = null; 
                if (att2Anno.get(attrribute) != null)            
                    annoList = (ArrayList)att2Anno.get(attrribute);     
                else 
                    annoList = new ArrayList (); 
               
                annoList.add(annotations[i]);
				
				//System.err.println("index " + i + " length " +  attrribute.length()); 
				
				
				
				att2Anno.put (attrribute, annoList); 
            }
            String [] attributeValues  = (String [])att2Anno.keySet().toArray(new String [att2Anno.size()] );
            if (attributeValues != null)   
            Arrays.sort (attributeValues); 
            String testValue =  null; 
            for (int i=0; i<attributeValues.length; i++){
                if (attributeValues[i] != null && !attributeValues[i].startsWith("zzzz")) 
                    testValue = attributeValues[i]; 
            }                       
            int type = LffConstants.String_TYPE; 
            if (testValue != null) 
               type = LffUtility.findDataType (testValue);
         
           HashMap  index2Anno = AnnotationSorter.sortAnno(attributeValues, att2Anno, type ); 
           return index2Anno;       
      }    
    
    
    public static  AnnotationDetail  []sortAllAnnotations (String [] sortNames, AnnotationDetail [] annotations) throws Exception {   
        HashMap index2Annos  = null; 
        AnnotationDetail [] newAnnotations = new AnnotationDetail[annotations.length]; 
        try {
        if ( sortNames == null || sortNames.length ==0 )   
        return annotations;  
        
        int currentIndex = 0;      
        int index2 = LffUtility.findLffIndex(sortNames[0]);
        
        if (index2 >=0)
            index2Annos =  sortAnnotations (annotations, sortNames[0]);  
        else  
            index2Annos =   sortAnnotationsByAVPSortName (sortNames[0], annotations);                     
             
        if (index2Annos != null) {        
            for (int j=0; j<index2Annos.size(); j++) {                     
                ArrayList annoList = (ArrayList)index2Annos.get("" + j); 
                
                if (annoList != null && annoList.size() ==1) {             
                    newAnnotations[currentIndex ]  = (AnnotationDetail) annoList.get(0); 
                    currentIndex ++;                
                }
                else  if (annoList != null && annoList.size() >1) {
                    if (sortNames != null && sortNames.length >1){          
                        AnnotationDetail [] tempSamples = AnnotationSorter.orderAnnotations( annoList, sortNames,  1);                                    
                        for (int k=0; k<tempSamples.length; k++) {
                            newAnnotations[currentIndex ] =tempSamples [k];                                     
                            currentIndex ++; 
                        } 
                    }
                    else {
                        if (annoList != null) {  
                            for (int k=0; k<annoList.size(); k++) {
                                newAnnotations[currentIndex ] = (AnnotationDetail)annoList.get(k);       
                                currentIndex ++; 
                            }               
                        }        
                    }
                }              
            } 
        }               
        }
        catch (Exception e) {
        e.printStackTrace();
        }
        return newAnnotations;    
}
   
      
    public static  AnnotationDetail  []sortAllAnnotations (String [] sortNames, Connection  con, HashMap fid2Anno,   AnnotationDetail [] annotations, HashMap ftypeid2Gclass) throws Exception {   
    if ( sortNames == null || sortNames.length ==0 )   
    return annotations;  
         
   HashMap index2Annos  = null; 
    AnnotationDetail [] newAnnotations = new AnnotationDetail[annotations.length]; 
    int currentIndex = 0;      
    int index2 = LffUtility.findLffIndex(sortNames[0]);
        
    if (index2 >=0){
        index2Annos =  sortAnnotations (annotations, sortNames[0]);
    }
    else             
      index2Annos =   sortAnnotationsByAVPSortName (sortNames[0], annotations);                     
          
if (index2Annos != null) {
    for (int j=0; j<index2Annos.size(); j++) {                     
        ArrayList annoList = (ArrayList)index2Annos.get("" + j);
        
        if (annoList != null && annoList.size() ==1) {             
            newAnnotations[currentIndex ]  = (AnnotationDetail) annoList.get(0); 
            currentIndex ++;                
        }
        else  if (annoList != null && annoList.size() >1) {
            if (sortNames != null && sortNames.length >1){          
                AnnotationDetail [] tempSamples = orderAnnotations( annoList, sortNames, 1);                                    
                for (int k=0; k<tempSamples.length; k++) {
                    newAnnotations[currentIndex ] =tempSamples [k]; 
                               
                  currentIndex ++; 
                } 
             }
            else {
                if (annoList != null) {   
                    for (int k=0; k<annoList.size(); k++) {
                        newAnnotations[currentIndex ] = (AnnotationDetail)annoList.get(k);
                        currentIndex ++; 
                    }               
                }        
            }
        }              
    } 
} 
    return newAnnotations;    
}
   
   
        public static String []   sortArray (String [] arr, HashMap h, int type) {
             String [] temp = new String [arr.length];   
            switch (type) {
            case LffConstants.String_TYPE: {
              
				
				Arrays.sort(arr);
               temp = arr; 
            }
            break;
    
            case LffConstants.Long_TYPE: {
                long [] values = new long [arr.length]; 
                for (int i=0; i<arr.length; i++) {
                    Long  longv = LongValidator.getInstance().validate(arr[i]); 
                    if (longv != null) {
                        values [i] = longv.longValue();
                    }
                    else {
                        values [i] = Long.MAX_VALUE;   
                        h.remove("" + arr[i]);         
                        h.put("" + values[i],  (ArrayList) h.get(""+ arr[i]));          
                    }
                }
                Arrays.sort(values);
                for (int i=0; i<values.length; i++) 
                temp[i] = "" + values[i];
            }; 
            break; 
    
            case LffConstants.Double_TYPE: {
            double []  values = new double [arr.length]; 
            for (int i=0; i<arr.length; i++) {  
            Double   integer = DoubleValidator.getInstance().validate(arr[i]); 
            if (integer != null) {
            values [i] = integer.doubleValue();
				  h.put("" + values[i],  (ArrayList) h.get(""+ arr[i]));
			}
            else {
            values [i] = Double.MAX_VALUE;   
                   h.remove("" + arr[i]);     
                h.put("" + values[i],  (ArrayList) h.get(""+ arr[i]));
                 h.remove("" + arr[i]); 
           
            }  
            }  
            Arrays.sort(values);
          
                for (int i=0; i<values.length; i++) 
                temp[i] = "" + values[i];          
            }
            break; 
            case LffConstants.Date_TYPE: {
            Date currentDate = new Date (); 
            Date []  values = new Date [arr.length]; 
            for (int i=0; i<arr.length; i++) {
                Date  date = DateValidator.getInstance().validate(arr[i]); 
                if (date != null) {
                    values [i] = date; 
                }
                else {
                       h.remove("" + arr[i]);     
                    values [i] = currentDate;  
                    h.put("" + values[i],  (ArrayList) h.get(""+ arr[i]));                    
                }    
            }
            Arrays.sort(values);
       
                for (int i=0; i<values.length; i++) 
                temp[i] = "" + values[i];
           
            }
            break; 
            }
            return temp ;                                  
            }
 
    
public static AnnotationDetail [] orderAnnotations (ArrayList annoList, String[] sortedNames,  int index) throws Exception  {         
     
    if (sortedNames == null || sortedNames.length ==0)
    return (AnnotationDetail[]) annoList.toArray(new AnnotationDetail [annoList.size()]); 
    
    // if there is no more sorting, return in passed order 
    if (sortedNames != null && sortedNames.length ==1 ) 
    return(AnnotationDetail []) annoList.toArray(new AnnotationDetail [annoList.size()]); 

    // this is the sorted annotations to be returned 
    AnnotationDetail [] newAnnos = new AnnotationDetail[annoList.size()];        
    String sortName = sortedNames [index];         
    if (sortedNames != null && index ==sortedNames.length -1 ){ 
         HashMap currentHash = sortAnnotations ((AnnotationDetail [])annoList.toArray(new AnnotationDetail [annoList.size()]), sortName);         
         int currentIndex = 0;  
        for (int i=0; i<currentHash.size(); i++){         
            ArrayList list = null; 
            if (currentHash.get(""+i) != null) {
                list = (ArrayList)currentHash.get(""+ i);
            if (list.size()==1) {
                    AnnotationDetail anno = (AnnotationDetail) list.get(0);         
                 
                         newAnnos[currentIndex] = anno; 
                    currentIndex++;
                } 
                else {                            
                    AnnotationDetail [] temparr  = new AnnotationDetail [list.size()]; 
                    
                    
                    for (int k=0; k<temparr.length; k++) {                                                
                    if (currentIndex < annoList.size()) {    newAnnos[currentIndex] =  (AnnotationDetail) list.get(k);
                        currentIndex++;
					}
						else {
						
						 System.err.println(" exceed limit" + currentIndex); 
						
					}
					}    
                } 
            }
         }    
        return   newAnnos;
    }   
       
              // current sort Name
         
              // boolean to test if is last sort
              boolean isLastSort = false;                  
              if (index==(sortedNames.length -1))  
                  isLastSort = true; 
      
              // do the passed sorting 
              HashMap currentHash = sortAnnotations ((AnnotationDetail [])annoList.toArray(new AnnotationDetail [annoList.size()]), sortName);         
       int currentIndex = 0;         
    for (int i=0; i<currentHash.size(); i++){ 
    int tempIndex = index;
    ArrayList list = null; 
    if (currentHash.get(""+i) != null)
    list = (ArrayList)currentHash.get(""+ i);
       
    if (list.size()==1) {
        AnnotationDetail sample = (AnnotationDetail) list.get(0); 
        list.remove(sample);
        newAnnos[currentIndex] = sample; 
        currentIndex++;
    } 
    else {    // continue sorting 
        // go to next sorting attribute 
        tempIndex++;    
  
        // upfdate current hash 
        if (tempIndex < sortedNames.length) 
            sortName = sortedNames [ tempIndex];                     
        else {
            AnnotationDetail [] temparr  = new AnnotationDetail [list.size()]; 
            for (int k=0; k<temparr.length; k++) {                                        
                temparr[k] = (AnnotationDetail)list.get(k);              
                return temparr;             
            }    
        }
        if (tempIndex == sortedNames.length-1) 
        isLastSort = true; 
        
        AnnotationDetail [] temparr  = orderAnnotations (list,  sortedNames, tempIndex);
        
        for (int k=0; k<temparr.length; k++) {                                        
            newAnnos [currentIndex] = temparr[k];
            currentIndex ++;              
        }     
    }  
    } 
    return newAnnos; 
    }

    public static HashMap  sortAnnotationsByChromosome (AnnotationDetail [] annotations ) {
           HashMap chromosome2Anno = new HashMap ();       
           ArrayList annoList = null; 
           String chromosome = null; 
           for (int i=0; i<annotations.length; i++) {
              chromosome = annotations[i].getChromosome();   
              if (chromosome == null) 
                    chromosome = "zzzz"; 
               
              if (chromosome2Anno.get(chromosome) != null)            
                   annoList = (ArrayList)chromosome2Anno.get(chromosome);     
               else 
                   annoList = new ArrayList (); 
      
               annoList.add(annotations[i]);               
               chromosome2Anno.put (chromosome, annoList); 
           }
           String [] chromosomes = (String [])chromosome2Anno.keySet().toArray(new String [chromosome2Anno.size()] );
           Arrays.sort (chromosomes);      
            return sortAnno(chromosomes, chromosome2Anno, LffConstants.String_TYPE); 
       } 
    
public static HashMap sortAnnotationsByType (AnnotationDetail [] annotations ) {
    HashMap att2Anno = new HashMap ();         
    String  attrribute = null; 
    for (int i=0; i<annotations.length; i++) {
        attrribute = annotations[i].getFmethod();  
     
        if (attrribute == null)
                       attrribute = "zzzz" ;
           
        
        ArrayList annoList = null; 
        if (att2Anno.get(attrribute) != null)            
        annoList = (ArrayList)att2Anno.get(attrribute);     
        else 
        annoList = new ArrayList ();         
        annoList.add(annotations[i]); 
        att2Anno.put (attrribute, annoList); 
    }
    String [] attributes = (String [])att2Anno.keySet().toArray(new String [att2Anno.size()] );
    Arrays.sort (attributes);      
    return sortAnno(attributes, att2Anno, LffConstants.String_TYPE); 
} 

     
public static HashMap sortAnnotationsBySequence (AnnotationDetail [] annotations ) {
    HashMap att2Anno = new HashMap ();       
     String  attrribute = null; 
    for (int i=0; i<annotations.length; i++) {
        attrribute = annotations[i].getSequences(); 
        
        if (attrribute != null)  
        attrribute = attrribute.trim(); 
        
        if (attrribute == null || attrribute.equals("")) 
        attrribute = "zzzzzz"; 
      
        ArrayList annoList = null; 
        if (att2Anno.get(attrribute) != null)            
        annoList = (ArrayList)att2Anno.get(attrribute);     
        else 
        annoList = new ArrayList (); 
        
        annoList.add(annotations[i]); 
        att2Anno.put (attrribute, annoList); 
    }
    String [] attributes = (String [])att2Anno.keySet().toArray(new String [att2Anno.size()] );
    Arrays.sort (attributes);          
    return sortAnno( attributes , att2Anno, LffConstants.String_TYPE); 
}  


public static HashMap sortAnnotationsByComments (AnnotationDetail [] annotations ) {
  
   HashMap att2Anno = new HashMap ();       
     String  attrribute = null; 
    for (int i=0; i<annotations.length; i++) {
      attrribute = annotations[i].getComments();    
        if (attrribute != null)  
        attrribute = attrribute.trim(); 
        
        if (attrribute == null || attrribute.equals("")) 
        attrribute = "zzzzzz"; 
      
        ArrayList annoList = null; 
        if (att2Anno.get(attrribute) != null)            
        annoList = (ArrayList)att2Anno.get(attrribute);     
        else 
        annoList = new ArrayList (); 
        
        annoList.add(annotations[i]); 
        att2Anno.put (attrribute, annoList); 
    }
        String [] attributes = (String [])att2Anno.keySet().toArray(new String [att2Anno.size()] );
    Arrays.sort (attributes);          
    return sortAnno( attributes , att2Anno, LffConstants.String_TYPE); 
 
}  
        
    
public static HashMap sortAnnotationsByClass (AnnotationDetail [] annotations ) {
   HashMap att2Anno = new HashMap ();          
    String  attrribute = null; 
    for (int i=0; i<annotations.length; i++) {
        attrribute = annotations[i].getGclassName();
        if (attrribute == null) 
        attrribute = "zzzzzz"; 
       
        ArrayList annoList = null; 
        if (att2Anno.get(attrribute) != null)            
        annoList = (ArrayList)att2Anno.get(attrribute);     
        else 
        annoList = new ArrayList (); 
        
        annoList.add(annotations[i]); 
        att2Anno.put (attrribute, annoList); 
    }
   String [] attributes = (String [])att2Anno.keySet().toArray(new String [att2Anno.size()] );
    Arrays.sort (attributes);          
    return sortAnno( attributes , att2Anno, LffConstants.String_TYPE); 
}  

    
public static HashMap sortAnnotationsBySubType (AnnotationDetail [] annotations ) {
    HashMap att2Anno = new HashMap ();         
    String  attrribute = null; 
    for (int i=0; i<annotations.length; i++) {
        attrribute = annotations[i].getFsource();  
        
     
        if (attrribute == null)
                       attrribute = "zzzz" ;
           
        
        ArrayList annoList = null; 
        if (att2Anno.get(attrribute) != null)            
        annoList = (ArrayList)att2Anno.get(attrribute);     
        else 
        annoList = new ArrayList ();        
        annoList.add(annotations[i]); 
        att2Anno.put (attrribute, annoList); 
    }
    String [] attributes = (String [])att2Anno.keySet().toArray(new String [att2Anno.size()] );
    Arrays.sort (attributes);          
    return sortAnno( attributes , att2Anno, LffConstants.String_TYPE); 
}  
        
/**
*  +, - : +, - 
* @param annotations
* @return
*/ 
public static HashMap sortAnnotationsByStrand (AnnotationDetail [] annotations ) {
    HashMap att2Anno = new HashMap ();        
    String  attrribute = null; 
    for (int i=0; i<annotations.length; i++) {
    attrribute = annotations[i].getStrand();   
     
        if (attrribute == null)
                       attrribute = "zzzz" ;
        
    ArrayList annoList = null; 
    if (att2Anno.get(attrribute) != null)            
    annoList = (ArrayList)att2Anno.get(attrribute);     
    else 
    annoList = new ArrayList (); 
    
    annoList.add(annotations[i]); 
    att2Anno.put (attrribute, annoList); 
    }
    String [] attributes = (String [])att2Anno.keySet().toArray(new String [att2Anno.size()] );
    Arrays.sort (attributes);          
    return sortAnno( attributes , att2Anno, LffConstants.String_TYPE); 
}  
  
/**
*  phase 0, 1, 2 
* 
* @return
*/ 
public static HashMap sortAnnotationsByPhase (AnnotationDetail [] annotations ) {
    HashMap att2Anno = new HashMap ();          
    String  attrribute = null; 
    for (int i=0; i<annotations.length; i++) {
    attrribute = annotations[i].getPhase();   
        
        if (attrribute == null)
                       attrribute = "zzzz" ;
               
                   
    ArrayList annoList = null; 
    if (att2Anno.get(attrribute) != null)            
    annoList = (ArrayList)att2Anno.get(attrribute);     
    else 
    annoList = new ArrayList (); 
    
    annoList.add(annotations[i]); 
    att2Anno.put (attrribute, annoList); 
    }
   String [] attributes = (String [])att2Anno.keySet().toArray(new String [att2Anno.size()] );
    Arrays.sort (attributes);          
    return sortAnno( attributes , att2Anno, LffConstants.String_TYPE); 
}  
   
       public static HashMap  sortAnnotationsByQStart (AnnotationDetail [] annotations ) {
                   HashMap att2Anno = new HashMap ();       
                 int count =0; 
             long [] starts = new long [annotations.length] ; 
                 String  attrribute = null; 
                 for (int i=0; i<annotations.length; i++) {
        attrribute =  ""+annotations[i].getTargetStart();                
                     if (attrribute == null)
                                    attrribute = "" + Long.MAX_VALUE;
               
                                
                      ArrayList annoList = null; 
                     if (att2Anno.get(attrribute) != null)            
                         annoList = (ArrayList)att2Anno.get(attrribute);     
                     else {
                         annoList = new ArrayList (); 
                         starts [count] = annotations[i].getTargetStart();
                     }
                     annoList.add(annotations[i]); 
                     att2Anno.put (attrribute, annoList); 
                 }
                 String [] attributes  = (String [])att2Anno.keySet().toArray(new String [att2Anno.size()] );
        long [] intAtt = new long [attributes.length] ; 
        for (int i=0; i<intAtt.length; i++) {           
        intAtt [i] =  starts[i];              
        }        
        Arrays.sort (intAtt);             
        return sortAnno(attributes, att2Anno, LffConstants.Long_TYPE); 
               }  
                        
    
    public static HashMap  sortAnnotationsByQStop (AnnotationDetail [] annotations ) {
        HashMap att2Anno = new HashMap ();       
        int count =0; 
        long [] starts = new long [annotations.length] ; 
        String  attrribute = null; 
        for (int i=0; i<annotations.length; i++) {
            attrribute = "" + annotations[i].getTargetStop();   
            if (attrribute == null)
                attrribute = "" + Long.MAX_VALUE;
               
            ArrayList annoList = null; 
            if (att2Anno.get(attrribute) != null)            
                annoList = (ArrayList)att2Anno.get(attrribute);     
            else {
                annoList = new ArrayList (); 
                starts [count] = annotations[i].getTargetStop();
            }
            annoList.add(annotations[i]); 
            att2Anno.put (attrribute, annoList); 
         }
        String [] attributes  = (String [])att2Anno.keySet().toArray(new String [att2Anno.size()] );
        long [] intAtt = new long [attributes.length] ; 
        for (int i=0; i<intAtt.length; i++) {           
        intAtt [i] =  starts[i];              
        }        
        Arrays.sort (intAtt);             
        return sortAnno(attributes, att2Anno, LffConstants.Long_TYPE);   
    }  
                               

     
public static HashMap    sortAnnotations(AnnotationDetail [] annotations,  String  sortName) {
int  index2 = LffUtility.findLffIndex(sortName); 
HashMap index2Anno = null; 
 if (index2>-1) {
     // sort LFF_Columns 
     switch (index2) {
     case (1) : index2Anno = sortAnnotationsByClass (annotations) ; 
     break; 
     case (2) : index2Anno = sortAnnotationsByType (annotations) ; 
     break; 
     case (3) : index2Anno = sortAnnotationsBySubType (annotations) ; 
     break; 
     case (0) : index2Anno = sortAnnotationsByName (annotations) ; 
     break;
     case (4) : index2Anno =sortAnnotationsByChromosome (annotations) ; 
     break; 
     case (5) : index2Anno =sortAnnotationsByStart (annotations) ; 
     break; 
     case (6) : index2Anno =sortAnnotationsByStop (annotations) ;   break;           
     case (7) : index2Anno =sortAnnotationsByStrand (annotations) ;  break; 
     case (8) : index2Anno =sortAnnotationsByPhase (annotations) ;     break; 
     case (9) : index2Anno =sortAnnotationsByScore (annotations) ;    break; 
     case (10) : index2Anno =sortAnnotationsByQStart (annotations) ;   break; 
     case (11) : index2Anno =sortAnnotationsByQStop (annotations) ;     break; 
     case (12) : index2Anno =sortAnnotationsBySequence (annotations) ;   break; 
     case (13) : index2Anno =sortAnnotationsByComments (annotations) ;      break;           
     }
 }
 else {  // sort avp value pairs 
    index2Anno = sortAnnotationsByAVPSortName(sortName, annotations);
 }
 return index2Anno;
 }

    
    
public static HashMap sortAnnotationsByName (AnnotationDetail [] annotations ) {
    HashMap att2Anno = new HashMap ();       
    String  attrribute = null; 
    ArrayList annoList = null; 
    for (int i=0; i<annotations.length; i++) {
        attrribute = annotations[i].getGname();               
        if (att2Anno.get(attrribute) != null)            
            annoList = (ArrayList)att2Anno.get(attrribute);     
        else 
            annoList = new ArrayList ();         
        annoList.add(annotations[i]); 
        
        if (attrribute  == null) 
        attrribute = "zzzzzz"; 
        att2Anno.put (attrribute, annoList); 
    }
   
    String [] attributes  = (String [])att2Anno.keySet().toArray(new String [att2Anno.size()] );
    Arrays.sort (attributes);  
    HashMap hash = sortAnno(attributes, att2Anno, LffConstants.String_TYPE); 
    return hash; 
}  
      
public static HashMap  sortAnno (String [] arr, HashMap h, int type) {
    HashMap index2Anno = new HashMap (); 
    switch (type) {
    case LffConstants.String_TYPE: {
			Arrays.sort(arr);
		for (int i=0; i<arr.length; i++) {
           index2Anno.put("" + i , (ArrayList) h.get(arr[i]));   
          }    
    }
    break;

    case LffConstants.Long_TYPE: {
        long [] values = new long [arr.length]; 
        for (int i=0; i<arr.length; i++) {
            Long  longv = LongValidator.getInstance().validate(arr[i]); 
            if (longv != null) {
                values [i] = longv.longValue();
            }
            else {
                values [i] = Long.MAX_VALUE;                                                     
                h.put("" + values[i],  (ArrayList) h.get(""+ arr[i]));          
            }
        }
        Arrays.sort(values);
        for (int i=0; i<arr.length; i++) {
            index2Anno.put("" + i, (ArrayList) h.get(""+values[i]));                        
        }
    }; 
    break; 

    case LffConstants.Double_TYPE: {
    double []  values = new double [arr.length]; 
    for (int i=0; i<arr.length; i++) {  
    Double  dvalue = DoubleValidator.getInstance().validate(arr[i]); 
    if (dvalue != null) {
    values [i] = dvalue.doubleValue();
    }
    else {
    values [i] = Double.MAX_VALUE;   
	}   h.put("" + values[i],  (ArrayList) h.get(""+ arr[i]));           
    
    }  
    Arrays.sort(values);
    for (int i=0; i<values.length; i++) 
    index2Anno.put("" + i , (ArrayList) h.get(""+values[i]));  
    }
    break; 
    case LffConstants.Date_TYPE: {
    Date currentDate = new Date (); 
    Date []  values = new Date [arr.length]; 
    for (int i=0; i<arr.length; i++)  
    {
    Date  date = DateValidator.getInstance().validate(arr[i]); 
    if (date != null) {
    values [i] = date; 
    }
    else {
    values [i] = currentDate;  
        h.put("" + values[i],  (ArrayList) h.get(""+ arr[i]));          
    }
    }
    Arrays.sort(values);
    for (int i=0; i<arr.length; i++) 
    index2Anno.put("" + i , (ArrayList) h.get(""+values[i]));  
    }
    break; 
    }   ; 

    return index2Anno ;                                  
    }        
}
