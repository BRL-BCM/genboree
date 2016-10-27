package org.genboree.samples;

import java.util.*;

/**
 * User: tong
 * Date: Nov 27, 2007
 * Time: 10:18:44 AM
 */
public class SortingUtility {
	
	/**
		 * Sorting Strings alphabetically in both order, with null and empty value moved to the end   
		 * @param ss
		 * @param order   0 for ascending (default sort) , and  1 for descending 
		 * @param maxValue
		 * @return
		 */
			public static String [] sortStrings (String [] ss, int order , String maxValue ) {			
				alphabeticAscendingSort(ss); 
				String [] temp = new String [ss.length];  
		
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
						
						  ss = temp; 
					}
		
		System.err.println ("   finished sorting string arrays   "    ); 
					return ss; 
			}
	
	public static String [] sortArray (String [] keys, int order, int dataType, String maxString,  Date currentDate ) {
	switch (dataType) {   
        
	  case (SampleConstants.STRING_TYPE) : 
		   keys = SortingUtility.sortStrings(keys, order, maxString ); 
	
		  break; 
        
	  case (SampleConstants.INTEGER_TYPE) :   
			keys = SortingUtility.sortIntStringArray(keys, order); 
	  break; 
   
	  case (SampleConstants.MONEY_TYPE) : 
		  keys = SortingUtility.sortDoubleStringArray(keys, order); 
	  break;         
            
            
	  case (SampleConstants.DOUBLE_TYPE) :         
				   keys = SortingUtility.sortDoubleStringArray(keys, order); 	 
	  break;         
        
        
	  case (SampleConstants.DATE_TYPE) :                    
			 keys = SortingUtility.sortDateStringArray(keys, order, currentDate); 	 
	   break;
            
	   default: 
			  break;             
	  }  
		
     return keys; 		
		
	}  	
	
	
	/**
	 * 
	  *@param type
 
	 * @return
	 */    
		public static String findMaxValue (int type, java.util.Date  date) {
			  String maxValue = "zzzzzz"; 
			  switch (type) {
				  case (SampleConstants.STRING_TYPE) : 
					// do nothing
            
					  break; 
               
				  case (SampleConstants.INTEGER_TYPE) : 
					   maxValue=  "" + Integer.MAX_VALUE;
              
					  break;
                  
				  case (SampleConstants.DOUBLE_TYPE): 
					  maxValue = "" + Double.MAX_VALUE;                 
              
					  break; 
                  
				 case (SampleConstants.DATE_TYPE) : 
					   maxValue = date.toString();              
					  break;
                  
				 case (SampleConstants.MONEY_TYPE) : 
					 maxValue = "" + Integer.MAX_VALUE;                  
             
					break;   
                  
				  default : 
					  {
					  // do nothing;     
					  }
					  break;
			  }   
		 return maxValue;  
	   }
	
	
	
	public static void alphabeticAscendingSort (String []  arr) {
			  Arrays.sort(arr, new Comparator() { 
		  public int compare(Object o1, Object o2)
		  {
		  return (((String) o1).toLowerCase().
		  compareTo(((String) o2).toLowerCase()));
		  }
		  }); 
	  }
	

	public static String [] sortIntStringArray (String [] keys , int order ) {
		Integer [] ii = new Integer [keys.length]; 
        String []  orderedKeys = new String [ii.length]; 
		Integer max = new Integer (Integer.MAX_VALUE); 
			int count = 0; 			
		// first , mapping converted int to original keys 
			HashMap h = new HashMap (); 
		for (int i=0; i<keys.length; i++)  { 
            try {
                ii[i] = new Integer(keys[i]); 
                h.put(ii[i], keys[i]);   
				count ++; 
			}
            catch (NumberFormatException e) {  
				// invalid keys could be more than one. 
				// in this case, put all invalid keys into a list 
				ii[i] = max;  
				ArrayList list = null; 
				if (h.get(ii[i]) == null)
				    list = new ArrayList (); 
				else 
				    list = (ArrayList) h.get(ii[i]); 
		
				list.add(keys[i]); 
				
		
				//System.err.println (" index is in hash  "  + i +   " key value   " + keys[i]   + "  int  value " + ii[i]  ); 
						   
				h.put(max, list); 
             }
        }  
		   
		
	
		// sorting Arrays by natural order; which mean, may not be alphabetically for Strings 
		SortingUtility.sortArray(ii, order); 
			           
		// move invalid elements w/maxValue to last in reverse order; 
	    
		if (order > 0) {      
				Integer[] 	temp = new Integer[ii.length] ; 
				int length = ii.length; 
			    int index = 0 ; 
				for (int i=0; i<ii.length; i++) {
					if (ii[i].intValue() != Integer.MAX_VALUE) {
					temp [index] = ii[i]; 
					}
				    index ++; 
				}
				
				if (index < ii.length) 
				for (int i=index; i<ii.length; i++) 
				temp [i] = max; 
			ii = temp; 
		}
		
		

		for (int i=0; i<count;  i++)        
			orderedKeys[i] =  (String) h.get(ii[i]); 
		
		if ( h.get(max) != null) {
			ArrayList list = (ArrayList) h.get(max); 
			String [] temp = (String []) list.toArray(new String[list.size()] ); 
			alphabeticAscendingSort(temp);
			for (int i=0; i< temp.length;  i++)        
			orderedKeys[count + i ] = temp[i];  
		}
	      
          return orderedKeys ;
	}
	
	
	
	
	public static String [] sortDoubleStringArray (String[] keys , int order ) {
			Double [] ii = new Double [keys.length]; 
			String []  orderedKeys = new String [ii.length]; 
			Double max = new Double (Integer.MAX_VALUE); 
	          int count = 0; 
						
			// first , mapping converted int to original keys 
				HashMap h = new HashMap (); 
			for (int i=0; i<keys.length; i++)  { 
				
				
				try {
					ii[i] = new Double(keys[i]); 
					h.put(ii[i], keys[i]);   
					 count ++; 
				
					  System.err.println (" index "  + i +   " key value   " + keys[i]   + "  double value " + ii[i]  ); 
					
				}
				catch (NumberFormatException e) {  
					// invalid keys could be more than one. 
					// in this case, put all invalid keys into a list 
					ii[i] = max;  
					ArrayList list = null; 
					if (h.get(ii[i]) == null)
						list = new ArrayList (); 
					else 
						list = (ArrayList) h.get(ii[i]); 
		
					list.add(keys[i]);           

					
					
					h.put(max, list); 
					System.err.println ("  max key  is  in hash "  +   ii[i] + "  as a list "   ); 
					
					
				 }
			}  
			// sorting Arrays by natural order; which mean, may not be alphabetically for Strings 
			SortingUtility.sortArray(ii, order); 
			// move invalid elements w/maxValue to last in reverse order; 
				
			if (order > 0) {
				Double[] temp = new Double[ii.length] ; 
				int length = ii.length; 
				int index  = 0; 
				for (int i=0; i<ii.length; i++) {
				if (ii[i] != max) {
						temp [index] = ii[i]; 
						index ++; 
					}
				}
				
				if (index < ii.length) 
					for (int i=index; i<ii.length; i++) 
						temp [i] = max; 
				
				ii = temp; 
		
			}
		
		     // get original keys 
		for (int i=0; i<ii.length;  i++) {
		       if (ii[i] != max  )   
				orderedKeys[i] =  (String) h.get(ii[i]); 
		}
		
			if ( h.get(max) != null) {
				ArrayList list = (ArrayList) h.get(max); 
				
				String [] temp = (String []) list.toArray(new String[list.size()] ); 
				alphabeticAscendingSort(temp);
				for (int i=0; i< temp.length;  i++)        
				orderedKeys[count + i ] = temp[i]; 
			}
	
		
		
			  return orderedKeys ;
		}
		
	
	
	
	public static String [] sortDateStringArray (String [] keys , int order, Date currentDate  ) {
				Date [] ii = new Date [keys.length]; 
				String []  orderedKeys = new String [ii.length]; 
				Date max = currentDate ; 
						int count = 0; 
				// first , mapping converted int to original keys 
					HashMap h = new HashMap (); 
				for (int i=0; i<keys.length; i++)  { 
					try {
						ii[i] = new Date (keys[i]) ;  
						h.put(ii[i], keys[i]);     
								 count ++; 
					}
					catch (Exception e) {  
						// invalid keys could be more than one. 
						// in this case, put all invalid keys into a list 
						ii[i] = max;  
						ArrayList list = null; 
						if (h.get(ii[i]) == null)
							list = new ArrayList (); 
						else 
							list = (ArrayList) h.get(ii[i]); 
		
						list.add(keys[i]); 
						h.put(max, list); 
						

						System.err.println (" index is in hash  "  + i +   " key value   " + keys[i]   + "  date  value " + ii[i]  ); 
								
					 }
				}  
		
				// sorting Arrays by natural order; which mean, may not be alphabetically for Strings 
				SortingUtility.sortArray(ii, order); 
		
				// move invalid elements w/maxValue to last in reverse order; 
				
				if (order > 0) {
					Date[] 	temp = new Date[ii.length] ; 
							int length = ii.length;
					int index = 0; 
							  for (int i=0; i<ii.length; i++) {
							if (ii[i] != max) {
							temp [index] = ii[i]; 
							index ++; 
							}
							}
			
							if (index < ii.length) 
							for (int i=index; i<ii.length; i++) 
							temp [i] = max; 
					ii = temp; 
				}
		
		
				for (int i=0; i<count;  i++)        
					orderedKeys[i] =  (String) h.get(ii[i]); 
		
				if ( h.get(max) != null) {
					ArrayList list = (ArrayList) h.get(max); 
					String [] temp = (String []) list.toArray(new String[list.size()] ); 
					alphabeticAscendingSort(temp);
					for (int i=0; i< temp.length;  i++)        
					orderedKeys[count + i ] = temp[i];  
				}
	
				  return orderedKeys ;
			}
			
	
	
	
	public static String [] sortMoneyStringArray (String [] keys , int order ) {
					  return keys;
				}
			
	
	   /**
		* 
	      Arrays.sort can not have null elemenet. 
		  Therefore, caution is needed to avoid null object value.
		*/
	public static void sortArray (Object [] ss, int order) {
			     if ( ss == null || ss.length ==0) 
				    return; 
				
				 if (order == 0 ) {
					Arrays.sort (ss); 
				} 
				else {
				     Arrays.sort(ss, Collections.reverseOrder()); 
				 }
					return ; 
			}
	
}
