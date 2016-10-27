package org.genboree.tabular;

/**
 * User: tong
 * Date: Sep 11, 2007
 * Time: 11:49:55 AM
 */


	import org.apache.commons.validator.routines.DateValidator;
	import org.apache.commons.validator.routines.DoubleValidator;
	import org.apache.commons.validator.routines.LongValidator;
	import org.genboree.editor.AnnotationDetail;

	import java.util.ArrayList;
	import java.util.Arrays;
	import java.util.Date;
	import java.util.HashMap;

public class OneAttAnnotationSorter {


		public static final String maxStringValue =  "zzzzzz"; 
      
		public static  AnnotationDetail  []sortAllAnnotations (String  sortName, AnnotationDetail [] annotations, int order) throws Exception {   
			HashMap index2Annos  = null; 
			AnnotationDetail [] newAnnotations = new AnnotationDetail[annotations.length]; 
			try {
			if ( sortName == null || sortName.length() ==0 )   
			return annotations;  
        
			int currentIndex = 0;      
			int index2 = LffUtility.findLffIndex(sortName);
        
			if (index2 >=0)
				index2Annos =  sortAnnotations (annotations, sortName, order);  
			else  
				index2Annos =   sortAnnotationsByAVPSortName (sortName, annotations, order);                     
             
			if (index2Annos != null) {        
				for (int j=0; j<index2Annos.size(); j++) {                     
					ArrayList annoList = (ArrayList)index2Annos.get("" + j); 
                
					if (annoList != null && annoList.size() ==1) {             
						newAnnotations[currentIndex ]  = (AnnotationDetail) annoList.get(0); 
						currentIndex ++;                
					}
					else  if (annoList != null && annoList.size() >1) {
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
			catch (Exception e) {
			e.printStackTrace();
			}
			return newAnnotations;    
	}
   
    
	
	public static HashMap sortAnnotationsByAVPSortName(String sortName, AnnotationDetail [] annotations, int order ) {      
			   HashMap att2Anno = new HashMap ();     
			   String  attrribute = null; 
			   for (int i=0; i<annotations.length; i++) {
				   HashMap avpMap = annotations[i].getAvp();
               
				   if (avpMap.get(sortName) != null) {
					    ArrayList attlist  = (ArrayList )avpMap.get(sortName); 
					   if (attlist != null&& attlist.size() > 0) 
						   attrribute = (String)attlist.get(0);
					   if (attrribute == null ) 
						     attrribute = maxStringValue; 
					   else {
						   attrribute = attrribute.trim(); 
						   if (attrribute.length() ==0) 
							     attrribute = maxStringValue; 
						   
					   }
				   }
				   else 
					   attrribute = maxStringValue; 
               
					ArrayList annoList = null; 
				   if (att2Anno.get(attrribute) != null)            
					   annoList = (ArrayList)att2Anno.get(attrribute);     
				   else 
					   annoList = new ArrayList (); 
               
				   annoList.add(annotations[i]); 
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
         
			  HashMap  index2Anno = sortAnno(attributeValues, att2Anno, type, order  ); 
			  return index2Anno;       
		 }    
    	

		public static HashMap  sortAnnotationsByChromosome (AnnotationDetail [] annotations, int order ) {
			   HashMap chromosome2Anno = new HashMap ();       
			   ArrayList annoList = null; 
			   String chromosome = null; 
			   for (int i=0; i<annotations.length; i++) {
				  chromosome = annotations[i].getChromosome();   
				  if (chromosome == null) 
						chromosome = maxStringValue; 
               
				  if (chromosome2Anno.get(chromosome) != null)            
					   annoList = (ArrayList)chromosome2Anno.get(chromosome);     
				   else 
					   annoList = new ArrayList (); 
      
				   annoList.add(annotations[i]);               
				   chromosome2Anno.put (chromosome, annoList); 
			   }
			   String [] chromosomes = (String [])chromosome2Anno.keySet().toArray(new String [chromosome2Anno.size()] );
				return sortAnno(chromosomes, chromosome2Anno, LffConstants.String_TYPE, order); 
		   } 
    
	public static HashMap sortAnnotationsByType (AnnotationDetail [] annotations , int order ) {
		HashMap att2Anno = new HashMap ();         
		String  attrribute = null; 
		for (int i=0; i<annotations.length; i++) {
		attrribute = annotations[i].getFmethod();  
	
		if (attrribute == null)
		attrribute = maxStringValue;
		ArrayList annoList = null; 
		if (att2Anno.get(attrribute) != null)            
		annoList = (ArrayList)att2Anno.get(attrribute);     
		else 
		annoList = new ArrayList ();         
		annoList.add(annotations[i]); 
		att2Anno.put (attrribute, annoList); 
		}
		String [] attributes = (String [])att2Anno.keySet().toArray(new String [att2Anno.size()] );
		return sortAnno(attributes, att2Anno, LffConstants.String_TYPE, order ); 
	} 

     
	public static HashMap sortAnnotationsBySequence (AnnotationDetail [] annotations, int order ) {
		HashMap att2Anno = new HashMap ();       
		 String  attrribute = null; 
		for (int i=0; i<annotations.length; i++) {
			attrribute = annotations[i].getSequences(); 
        
			if (attrribute != null)  
			attrribute = attrribute.trim(); 
        
			if (attrribute == null || attrribute.equals("")) 
			attrribute = maxStringValue; 
      
			ArrayList annoList = null; 
			if (att2Anno.get(attrribute) != null)            
			annoList = (ArrayList)att2Anno.get(attrribute);     
			else 
			annoList = new ArrayList (); 
        
			annoList.add(annotations[i]); 
			att2Anno.put (attrribute, annoList); 
		}
		String [] attributes = (String [])att2Anno.keySet().toArray(new String [att2Anno.size()] );
		return sortAnno( attributes , att2Anno, LffConstants.String_TYPE, order); 
	}  


	public static HashMap sortAnnotationsByComments (AnnotationDetail [] annotations, int order  ) {  
	   HashMap att2Anno = new HashMap ();       
		 String  attrribute = null; 
		for (int i=0; i<annotations.length; i++) {
		  attrribute = annotations[i].getComments();    
			if (attrribute != null)  
			attrribute = attrribute.trim(); 
        
			if (attrribute == null || attrribute.equals("")) 
			attrribute = maxStringValue; 
      
			ArrayList annoList = null; 
			if (att2Anno.get(attrribute) != null)            
			annoList = (ArrayList)att2Anno.get(attrribute);     
			else 
			annoList = new ArrayList (); 
        
			annoList.add(annotations[i]); 
			att2Anno.put (attrribute, annoList); 
		}
    
		String [] attributes = (String [])att2Anno.keySet().toArray(new String [att2Anno.size()] );
	
		
		return sortAnno( attributes , att2Anno, LffConstants.String_TYPE, order); 
 
	}  
        
    
	public static HashMap sortAnnotationsByClass (AnnotationDetail [] annotations, int order ) {
	   HashMap att2Anno = new HashMap ();          
		String  attrribute = null; 

		for (int i=0; i<annotations.length; i++) {
			attrribute = annotations[i].getGclassName();
			if (attrribute != null) 
			   attrribute = attrribute.trim();
			if (attrribute == null || attrribute.length() ==0) 
			attrribute = maxStringValue; 
       
			ArrayList annoList = null; 
			if (att2Anno.get(attrribute) != null)            
			annoList = (ArrayList)att2Anno.get(attrribute);     
			else 
			annoList = new ArrayList (); 
        
			annoList.add(annotations[i]); 
			att2Anno.put (attrribute, annoList); 
		}
	
		String [] attributes = (String [])att2Anno.keySet().toArray(new String [att2Anno.size()] );
			return sortAnno( attributes , att2Anno, LffConstants.String_TYPE, order); 
	}  

    
	public static HashMap sortAnnotationsBySubType (AnnotationDetail [] annotations, int order  ) {
		HashMap att2Anno = new HashMap ();         
		String  attrribute = null; 
		for (int i=0; i<annotations.length; i++) {
			attrribute = annotations[i].getFsource();  
			 if (attrribute == null)
				 attrribute = maxStringValue ;
			  ArrayList annoList = null; 
			if (att2Anno.get(attrribute) != null)            
			annoList = (ArrayList)att2Anno.get(attrribute);     
			else 
			annoList = new ArrayList ();        
			annoList.add(annotations[i]); 
			att2Anno.put (attrribute, annoList); 
		}
		String [] attributes = (String [])att2Anno.keySet().toArray(new String [att2Anno.size()] );
		return sortAnno( attributes , att2Anno, LffConstants.String_TYPE, order); 
	}  
        
	/**
	*  +, - : +, - 
	* @param annotations
	* @return
	*/ 
	public static HashMap sortAnnotationsByStrand (AnnotationDetail [] annotations, int order  ) {
		HashMap att2Anno = new HashMap ();        
		String  attrribute = null; 
		for (int i=0; i<annotations.length; i++) {
		attrribute = annotations[i].getStrand();   
     
			if (attrribute == null)
						   attrribute = maxStringValue ;
        
		ArrayList annoList = null; 
		if (att2Anno.get(attrribute) != null)            
		annoList = (ArrayList)att2Anno.get(attrribute);     
		else 
		annoList = new ArrayList (); 
    
		annoList.add(annotations[i]); 
		att2Anno.put (attrribute, annoList); 
		}
		String [] attributes = (String [])att2Anno.keySet().toArray(new String [att2Anno.size()] );
		return sortAnno( attributes , att2Anno, LffConstants.String_TYPE, order); 
	}  
  
	/**
	*  phase 0, 1, 2 
	* 
	* @return
	*/ 
	public static HashMap sortAnnotationsByPhase (AnnotationDetail [] annotations, int order  ) {
		HashMap att2Anno = new HashMap ();          
		String  attrribute = null; 
		for (int i=0; i<annotations.length; i++) {
			attrribute = annotations[i].getPhase();   
			if (attrribute == null)
			attrribute = maxStringValue ;
			ArrayList annoList = null; 
			if (att2Anno.get(attrribute) != null)            
			annoList = (ArrayList)att2Anno.get(attrribute);     
			else 
			annoList = new ArrayList ();     
			annoList.add(annotations[i]); 
			att2Anno.put (attrribute, annoList); 
		}
	   String [] attributes = (String [])att2Anno.keySet().toArray(new String [att2Anno.size()] );
		return sortAnno( attributes , att2Anno, LffConstants.String_TYPE, order); 
	}  
   
		   public static HashMap  sortAnnotationsByQStart (AnnotationDetail [] annotations , int order ) {
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
			   
					return sortAnno(attributes, att2Anno, LffConstants.Long_TYPE, order); 
			}  
                        
    
		public static HashMap  sortAnnotationsByQStop (AnnotationDetail [] annotations, int order  ) {
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
		  
			return sortAnno(attributes, att2Anno, LffConstants.Long_TYPE, order); }
                               

  
		public static HashMap    sortAnnotations(AnnotationDetail [] annotations,  String  sortName, int order) {
		int  index2 = LffUtility.findLffIndex(sortName); 
		HashMap index2Anno = null; 
		 if (index2>-1) {
			 // sort LFF_Columns 
			 switch (index2) {
			 case (1) : index2Anno = sortAnnotationsByClass (annotations, order) ; 
			 break; 
			 case (2) : index2Anno = sortAnnotationsByType (annotations, order) ; 
			 break; 
			 case (3) : index2Anno = sortAnnotationsBySubType (annotations, order) ; 
			 break; 
			 case (0) : index2Anno = sortAnnotationsByName (annotations, order) ; 
			 break;
			 case (4) : index2Anno =sortAnnotationsByChromosome (annotations, order) ; 
			 break; 
			 case (5) : index2Anno =sortAnnotationsByStart (annotations, order) ; 
			 break; 
			 case (6) : index2Anno =sortAnnotationsByStop (annotations, order) ;   break;           
			 case (7) : index2Anno =sortAnnotationsByStrand (annotations, order ) ;  break; 
			 case (8) : index2Anno =sortAnnotationsByPhase (annotations, order ) ;     break; 
			 case (9) : index2Anno =sortAnnotationsByScore (annotations, order ) ;    break; 
			 case (10) : index2Anno =sortAnnotationsByQStart (annotations, order) ;   break; 
			 case (11) : index2Anno =sortAnnotationsByQStop (annotations, order ) ;     break; 
			 case (12) : index2Anno =sortAnnotationsBySequence (annotations, order ) ;   break; 
			 case (13) : index2Anno =sortAnnotationsByComments (annotations, order ) ;      break;           
			 }
		 }
		 else {  // sort avp value pairs 
			index2Anno = sortAnnotationsByAVPSortName(sortName, annotations, order);
		 }
		 return index2Anno;
		 }

   
    
	public static HashMap sortAnnotationsByName (AnnotationDetail [] annotations, int order ) {
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
			attrribute = maxStringValue; 
			att2Anno.put (attrribute, annoList); 
		}
   
		String [] attributes  = (String [])att2Anno.keySet().toArray(new String [att2Anno.size()] );
		HashMap hash = sortAnno(attributes, att2Anno, LffConstants.String_TYPE, order); 
		return hash; 
	}  
      
	public static HashMap  sortAnno (String [] arr, HashMap h, int type, int order) {
		HashMap index2Anno = new HashMap (); 
		switch (type) {
		case LffConstants.String_TYPE: {
			arr = sortStrings(arr, order, maxStringValue); 
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
			values = sortLongs(values, order); 
			for (int i=0; i<arr.length; i++) {
				index2Anno.put("" + i, (ArrayList) h.get(""+values[i]));                        
			}
		}; 
		break; 

		case LffConstants.Double_TYPE: {
		double []  values = new double [arr.length]; 
		for (int i=0; i<arr.length; i++) {  
		Double   integer = DoubleValidator.getInstance().validate(arr[i]); 
		if (integer != null) {
		values [i] = integer.intValue();
		}
		else {
		values [i] = Double.MAX_VALUE;   
			h.put("" + values[i],  (ArrayList) h.get(""+ arr[i]));           
		}
		}  
		  values = sortDoubles(values, order); 
		for (int i=0; i<arr.length; i++) 
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
		  values = sortDates (values, order, currentDate); 
		for (int i=0; i<arr.length; i++) 
		index2Anno.put("" + i , (ArrayList) h.get(""+values[i]));  
		}
		break; 
		}   ; 

		return index2Anno ;                                  
		} 
	
	
		public static String [] sortStrings (String [] ss, int order , String maxValue ) {
			
				Arrays.sort (ss); 
			String [] temp = ss; 
		
				if (order > 0 && ss != null) {
					temp = new String[ss.length] ; 
					int count = 0; 
					int length = ss.length; 
					for (int i=0; i<ss.length; i++) {
						
						if (!ss[length - 1 - i].startsWith ("zzzz")) {
							temp [count] = ss[length - 1 - i]; 
							count ++; 
						}
					}
				
					if (count < ss.length) 
					for (int i=count; i<ss.length; i++) 
					temp [i] = maxValue; 
			
				}
			
				return temp; 
		}
	
	
	
	public static Date  [] sortDates (Date [] ss, int order , Date maxValue ) {
			
				Arrays.sort (ss); 
			Date  [] temp = ss; 
		
				if (order > 0 && ss != null) {
					temp = new Date[ss.length] ; 
					int count = 0; 
					int length = ss.length; 
					for (int i=0; i<ss.length; i++) {
					if (!ss[i].equals(maxValue)) {
					temp [count] = ss[length - 1 - i]; 
					count ++; 
					}
					}
				
					if (count < ss.length) 
					for (int i=count; i<ss.length; i++) 
					temp [i] = maxValue; 
			
				}
			
				return temp; 
		}
	
		public static long [] sortLongs (long [] ss, int order) {
			
				Arrays.sort (ss); 
			long[] temp = ss; 
		
				if (order > 0 && ss != null) {
					temp = new long[ss.length] ; 
					int count = 0; 
					int length = ss.length; 
					for (int i=0; i<ss.length; i++) {
					if (ss[i] != Long.MAX_VALUE) {
					temp [count] = ss[length - 1 - i]; 
					count ++; 
					}
					}
				
					if (count < ss.length) 
					for (int i=count; i<ss.length; i++) 
					temp [i] =Long.MAX_VALUE; 
			
				}
			
				return temp; 
		}

		public static double [] sortDoubles (double [] ss, int order) {
			Arrays.sort (ss); 
			 double [] temp = ss; 
				if (order > 0 && ss != null) {
					temp = new double[ss.length] ; 
					int count = 0; 
					int length = ss.length; 
					for (int i=0; i<ss.length; i++) {
					if (ss[i] != Double.MAX_VALUE) {
					temp [count] = ss[length - 1 - i]; 
					count ++; 
					}
					}
				
					if (count < ss.length) 
					for (int i=count; i<ss.length; i++) 
					temp [i] =Double.MAX_VALUE; 
				}
			
				return temp; 
		}
	
	
	public static HashMap sortAnnotationsByStart (AnnotationDetail [] annotations,  int  order ) {
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
	   intAtt = sortLongs(intAtt, order); 

		
		HashMap index2Anno = new HashMap (); 
		for (int i=0; i<intAtt.length; i++) {
		index2Anno.put("" + i, att2Anno.get("" + intAtt[i]) ); 
		}
		return index2Anno;  
		} 
    
    
		public static HashMap sortAnnotationsByStop (AnnotationDetail [] annotations, int order ) {
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
			intAtt = sortLongs(intAtt, order);      
			 HashMap index2Anno = new HashMap (); 
		for (int i=0; i<intAtt.length; i++) {
		index2Anno.put("" + i, att2Anno.get("" + intAtt[i]) ); 
		}
		return index2Anno;  
		}  
   
		public static HashMap  sortAnnotationsByScore (AnnotationDetail [] annotations , int order ) {
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
       
			doubles = sortDoubles(doubles, order); 
		  HashMap index2Anno = new HashMap (); 
		for (int i=0; i<doubles.length; i++) {
		index2Anno.put("" + i, att2Anno.get("" + doubles[i]) ); 
		}
		return index2Anno;  
		}  
    
	}
	
	