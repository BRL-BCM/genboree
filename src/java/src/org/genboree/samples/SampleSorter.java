package org.genboree.samples;

import org.genboree.tabular.LayoutHelper;
import org.genboree.tabular.OneAttAnnotationSorter;

import javax.servlet.jsp.JspWriter;
import java.util.*;
import java.lang.reflect.Array;


/**
 * a class for helper methods in sample sorting 
 * logic: 
 *   sorting samples by many attrributes is recursive,, until last attrribute is sorted.  
 *   if still equal values are still un-resolved till last sorting, return as the order it was passed
 * 
 * User: tong
 * Date: Dec 14, 2006
 * Time: 8:37:56 AM
   */
     public class SampleSorter {  
    
	public static 	String maxString = "zzzzzz";	
    
	public static java.sql.Date currentDate = new java.sql.Date (new java.util.Date().getTime()); 
		 
   
	public static  Sample [] sortAllSamples (JspWriter out, String [] sortNames, int [] attIndexes,  Sample [] samples, HashMap attribute2Index, boolean isAscendingSort) throws SampleException {   
     
      
      
         if ( sortNames == null || sortNames.length ==0 || sortNames[0].equals("saName"))        
              return samples;  
   
        Sample [] sortedSamples = new Sample[samples.length];              
        
        java.sql.Date currentDate = new java.sql.Date (new java.util.Date().getTime()); 
        HashMap sortName2OrderArray = new HashMap (); 
        SortResult[] results = new SortResult[sortNames.length];        
        HashMap id2index = new HashMap (); 
        for ( int j=0; j<samples.length; j++) 
            id2index.put("" + samples[j].getSampleId(), new Integer(j)); 

        int [] attributeIndexes = populateAttributeIndexes(sortNames, attribute2Index); 
        if (attributeIndexes == null || attributeIndexes.length ==0) 
            throw new SampleException ("Error: error in function populateAttributeIndexs: returned null value for sort names" ); 
        int attributeIndex= -1;
        for( int i=0; i<sortNames.length;  i++) {
           
			  SortResult result =  null; 
            attributeIndex = attIndexes[i];
            try {
             result = sortSampleByAttribute (out, samples, sortNames[i],  attributeIndex, currentDate, isAscendingSort); 
            }
            catch (Exception e) {
				System.err.println("catch an error in line 47 of Sample SOrter "); 
				//throw e; 
            }
            
            if (result == null) 
            throw new SampleException ("Error: sorted result is null for sort name " + sortNames[i]); 
            
            results[i] = result;
            sortName2OrderArray.put(sortNames[i], result.sampleOrder); 
        }
    
        SortResult result = results[0]; 
         HashMap key2Samples =  result.value2Samples;               
         String [] orderedKeys = (String [])result.dataType2sortedData.get("dataType");                     
         int currentIndex = 0;         
          ArrayList sampleList = null; 
           
		
			for (int i=0; i<orderedKeys.length ; i++) {                                
                if (key2Samples.get(orderedKeys[i]) == null) {
                   throw new SampleException (" key " + orderedKeys[i] + " has no matching sample " );               
                }
              
               sampleList = (ArrayList)key2Samples.get(orderedKeys[i]);
             
                if (sampleList== null || sampleList.isEmpty()) {
                      throw new SampleException (" key " + orderedKeys[i] + " has no matching sample " );               
                   }
                
				
						
                if (sampleList != null && sampleList.size() ==1) {
                      sortedSamples [currentIndex ] =(Sample) sampleList.get(0); 
                      currentIndex ++; 
                }
              
               else  if (sampleList != null && sampleList.size() >1) {
                    if (sortNames != null && sortNames.length >1){   
                      
                        Sample []  tempSamples =  null; 
                        try {
                          tempSamples =  orderSamples (out, sampleList, sortNames, id2index,  sortName2OrderArray,1);                                                      
                        }
                        catch (Exception e) {
							e.printStackTrace() ; 
						}
                     
                        for (int k=0; k<tempSamples.length; k++) {
                          sortedSamples [currentIndex ] =tempSamples [k]; 
                          currentIndex ++; 
                          } 
                    }
                    else {                    
                          for (int k=0; k< sampleList.size(); k++) {
                             if (currentIndex < samples.length) 
                              sortedSamples [currentIndex ] = (Sample)sampleList.get(k);
                              currentIndex ++; 
                          }                                                
                       }
                }
                }
		
		
// if no sort selected, do nothing     
      return sortedSamples;    
     }
    
     
   
    
   
 /* * the sorting step of sample sorting 
     * @param sampleList  ArrayList, passed samples to be sorted, with  equal attribute values 
     * @param orderArr  int [], the order of the next sorting to be used
     * @param id2index   HashMap sample id : array index (Integer) map of the original sample list
     * @param isLastSort   boolean  if last sort, return sample list in the order they were passed     
     * @return  HashMap
     * @exception Exception   when sample not found in the HashMap 
     */ 
     public static HashMap  sortSamples (ArrayList sampleList, int [] sampleOrders, HashMap sampleid2index, boolean isLastSort) throws SampleException  {         
        if (sampleList == null  || sampleList.isEmpty()) 
            throw new SampleException (" SampleSorter.sortSamples: sample list is empty" ); 
     
        if (sampleOrders == null  || sampleOrders.length ==0) 
                throw new SampleException (" SampleSorter.sortSamples: sample order is not set" ); 
                        
        if (sampleid2index == null  || sampleid2index.isEmpty()) 
               throw new SampleException (" SampleSorter.sortSamples: sample id 2 index map is not empty" ); 
                  
     
          // get current  attribute sorting  order                           
          int [] listSampleOrders = retrieveOrder (sampleList, sampleid2index, sampleOrders); 
           if (listSampleOrders == null || listSampleOrders.length ==0) {
                   throw new SampleException ("Error in SampleSorter.sortSamples: new sample order is not set" );                
           }
      
               // sorting samples by new order 
           HashMap index2samples = index2samples = updateOrder2samples(listSampleOrders, sampleList);  
            if (index2samples  == null || index2samples.isEmpty()) {
                throw new SampleException ("Error in SampleSorter.sortSamples: new sample order is not set" );                
            }
          
            String [] keys  = (String [])index2samples.keySet().toArray(new String [index2samples.size()]); 
            // new rodered sorting values 
            int [] sortedKeys  = new int [keys.length];
            for (int i=0; i<keys.length; i++) {
                try {
                   sortedKeys[i]= Integer.parseInt(keys[i]);
                }
                catch (NumberFormatException e) {
                   throw new SampleException("Error: invalid index in SampleSorter.sortSamples:  "  + keys[i]);  
                }
            }
     
            Arrays.sort (sortedKeys);             
            // if last sort, no more sorting
            if (isLastSort) 
               index2samples = lastSort(sortedKeys, index2samples); 
            else 
               return index2samples; 
        
         return index2samples; 
      }       
    
  /**
   * if last sort, create a hashMap where each sample is uniquely indexed 
   * for those samples which ties, set their order sequencially; 
   * @param key2samples
   * @return  HashMap of order to sample list, where each list has only one sample
   */ 
     public static  HashMap lastSort (int [] orderedKeys, HashMap key2samples ) throws SampleException  {     
       if ( key2samples == null || key2samples.isEmpty()) 
           throw new SampleException("Error in SampleSorter.lastSort: passed hashMap is null or empty.  ");  
     
        if ( orderedKeys == null || orderedKeys.length ==0) 
              throw new SampleException("Error in SampleSorter.lastSort: passed array of keys is null or empty.  ");  
      
        int currentIndex = 0;  
        HashMap index2sampleList = new HashMap ();     
        for (int i=0; i<orderedKeys.length; i++ ) {               
            ArrayList sampleList =null; 
            if (key2samples.get(""+ orderedKeys [i]) != null) 
              sampleList =  (ArrayList)key2samples.get(""+ orderedKeys [i]); 
            else 
                throw new SampleException("Error in SampleSorter.lastSort: sample for key  " + orderedKeys[i] + " is not found." );  
                
            for (int k=0; k<sampleList.size(); k++ ) {
                ArrayList list = new ArrayList (); 
                list.add( (Sample)sampleList.get(k)); 
                index2sampleList.put("" + currentIndex, list); 
                currentIndex ++; 
            }
        } 
            
        return   index2sampleList; 
     }
    
    
    
    public static HashMap updateOrder2samples (int [] newOrder,  ArrayList sampleList) throws SampleException  {
        if ( sampleList == null || sampleList.isEmpty()) 
                throw new SampleException("Error in SampleSorter.updateOrderedSamples: passed sample list is null or empty.  ");  
     
             if ( newOrder == null || newOrder.length ==0) 
                   throw new SampleException("Error in SampleSorter.updateOrder2Samples: passed array of orders is null or empty.  ");  
         
        
        
         HashMap key2samples = new HashMap (); 
          for (int i=0; i<newOrder.length; i++ ) {
                ArrayList list  = null;
                    if (key2samples.get("" + newOrder[i]) != null) {
                    list  = (ArrayList)key2samples.get("" + newOrder[i]);
                    list.add(sampleList.get(i));  
                }
                else {
                    list = new ArrayList (); 
                    list.add(sampleList.get(i));                       
                }                
                key2samples.put(""+newOrder[i], list);                 
            }
       return key2samples;  
    }
    
    
         
   // find the sorted order of these passed samples    
   public static int [] retrieveOrder (ArrayList sampleList, HashMap id2index, int [] orders) throws SampleException { 
       if (sampleList == null || sampleList.isEmpty()) 
           throw new SampleException("Error in SampleSorter.retrieveOrder: passed sample list is null or empty.  ");  
          
        int [] newOrder = new int[sampleList.size()];  
       int index = -1;
         Sample sample =  null; 
       
       
            for (int j=0; j<sampleList.size(); j++ ) {
                sample = (Sample)sampleList.get(j);
                index = -1;     
                if (id2index.get("" + sample.getSampleId()) == null) 
                    throw new SampleException("Error in SampleSorter.retrieveOrder: order for sample "  + sample.getSampleName() + " id " + sample.getSampleId() + " is not set.");  
               Integer  integer = (Integer)id2index.get("" + sample.getSampleId()); 
                if (integer != null) {
                    index = integer.intValue();                
                    newOrder[j] = orders[index];
                }
                 
                if (index <0)    
                    throw new SampleException (" SampleSorter.sortSamples: sample " + sample.getSampleName() + " index is not found. " ); 
            }
      return newOrder; 
   } 
    
       
    /**
       * 
       * @param sampleList ArrayList of samples to be ordered 
       * @param sortedNames array of attribute names to be sorted 
       * @param id2index  hashMap of sample id to sample index of the original sample array
       * @param name2order  HashMap of sample name to sample order 
       * @param index  int current sorting index
       * @return Sample [] 
       * @throws   SampleException when sorting fails
       */ 
    public static Sample [] orderSamples (JspWriter out, ArrayList sampleList, String[] sortedNames, HashMap id2index, HashMap name2order, int index) throws SampleException  {         
        if (sortedNames == null || sortedNames.length ==0) 
           throw new SampleException (" SampleSorter.orderSamples: sorting names is null or empty ") ; 
       
        if (sampleList == null ) 
                 throw new SampleException (" SampleSorter.orderSamples: sample list  is null ") ; 
           
        
        if (sampleList.size() ==0) 
                       throw new SampleException (" SampleSorter.orderSamples: sample list  is empty ") ; 
           
       // if there is no more sorting, return in passed order 
       if (sortedNames != null && sortedNames.length ==1) 
            return(Sample []) sampleList.toArray(new Sample [sampleList.size()]); 
        
        // this is the sorted samples to be returned 
        Sample [] sortedSamples = new Sample[sampleList.size()];        
         // current sort Name
        String sortName = sortedNames [index]; 
        
        // get sorted order of the current sorting 
        int [] orderArr =(int []) name2order.get(sortName); 
      
        // boolean to test if is last sort
        boolean isLastSort = false;                  
        if (index==(sortedNames.length -1))  
            isLastSort = true; 
       HashMap currentMap =  null; 
        // do the passed sorting 
          try {
            currentMap = sortSamples (sampleList, orderArr, id2index, isLastSort); 
          }
        catch (SampleException e) {
           throw e;   
       }
        // get the sorted orders
        String keys []= (String [])currentMap.keySet().toArray(new String [currentMap.size()]);                  
        int [] sortedKeys = new int [ keys.length];
        for (int i=0; i< keys.length; i++) {            
            try {
                sortedKeys[i]= Integer.parseInt( keys[i]);   
            }
            catch (NumberFormatException e) {
              throw new SampleException ("Error: invalid index for key " + keys[i]  + " in SampleSorter.orderSamples" ); 
            }
        }
        
        Arrays.sort (sortedKeys); 
       int currentIndex = 0;         
        for (int i=0; i< sortedKeys.length; i++){ 
            int tempIndex = index;
             ArrayList list = null; 
            if (currentMap.get(""+ sortedKeys[i]) != null)
                list = (ArrayList)currentMap.get(""+ sortedKeys[i]);
            else {
                throw new SampleException ("Error:  index  " + i + "  key " +  sortedKeys[i] + " has no samples " );                                               
            }
             
            if (list == null || list.size() ==0) {
                throw new SampleException ("Error:  index  " + i + "  key " +  sortedKeys[i] + " has no samples " );                    
            }
              
            if (list.size()==1) {
                Sample sample = (Sample) list.get(0); 
                list.remove(sample);
                sortedSamples[currentIndex] = sample; 
                currentIndex++;
            } 
            else {    // continue sorting 
                // go to next sorting attribute 
                tempIndex++;    
                // upfdate current hash 
                sortName = sortedNames [ tempIndex];                     
                orderArr =  (int []) name2order.get(sortName); 
                
                if (tempIndex == sortedNames.length-1) 
                    isLastSort = true; 
                Sample [] temparr =orderSamples (out, list, sortedNames, id2index, name2order, tempIndex);                                                                      
                for (int k=0; k<temparr.length; k++) {                                        
                    sortedSamples [currentIndex] = temparr[k];
                    currentIndex ++;                         
               }                                                                                                        
             }  
          } 
         
    return sortedSamples; 
    }
    
   
 public static   int [] populateAttributeIndexes (String [] sortNames, HashMap attribute2Index) throws SampleException {
        int count =0; 
        String attIndex  = null; 
        int  index = -1; 
        if (sortNames == null || sortNames.length ==0) 
           return null; 
     
        if (attribute2Index == null || attribute2Index.isEmpty()) 
            throw new SampleException ("Error: attribute2index map is empty in populateAttributeIndexes " ); 
       
        int []  attributeIndexes = new int [sortNames.length];
        for (int i=0; i< sortNames.length; i++) {
            if (attribute2Index.get(sortNames[i]) != null) 
            attIndex  = (String)attribute2Index.get(sortNames[i]);                
            else { 
            throw new SampleException ("Error: no index was found for sort name " + sortNames[i]);           
            }         
            
            if ( attIndex != null) {
            try {
                index = Integer.parseInt( attIndex );  
            }
            catch (NumberFormatException e) {
                throw new SampleException ("Error: invalid attribute index was found for sort name " + sortNames[i]); 
            }
            attributeIndexes[count] = index;  
            count++;
            }
            else {
            throw new SampleException ("Error: no index was found for sort name " + sortNames[i]); 
            }
        } 
        
      return attributeIndexes;   
        
    }
    
    
    
 

    
    public static HashMap mapAttribute2Samples (Sample [] samples, int attIndex, String sortName )   {
      
		System.err.println( " 413 passed sort name "  + sortName +"  sorting index " +  attIndex + " num samples " + samples.length ); 
                  
      
        if (samples == null) 
            return null; 
        
        if (sortName == null) 
         System.err.println( "Error in mapAttribute2Samples:  passed sort name is null." ); 
        
        if ( attIndex <0) 
             System.err.println( "Error in mapAttribute2Samples:  passed sort name is null." ); 
         
       Attribute [] attributes = null; 
        HashMap attributeValue2samples = new HashMap (); 
          String attributeValue = null; 
      for (int i=0; i<samples.length; i++) {                  
          // find the values of the sorting attributes in sample j     
          attributes = samples [i].getAttributes();
             // if no attributes, or no attribute, or attribute value is null, put to last
          if (attributes == null || attributes[attIndex] == null || attributes[attIndex].getAttributeValue() == null )                    
               attributeValue= maxString;        
          else // get get attribute value 
               attributeValue = attributes[attIndex].getAttributeValue() ; 
        
          // if sorting by sample name
          if (sortName.equals("saName")) 
                attributeValue = samples[i].getSampleName(); 
            
          // put null value and blank to bottom of array     
         attributeValue = attributeValue.trim(); 
          if (attributeValue.equals("")) 
              attributeValue =maxString;   
            
          attributeValue = attributeValue.toLowerCase(); 
       
          // get arraylist for samples with same value     
          ArrayList sampleList = null; 
          if (attributeValue2samples.get(attributeValue ) != null)               
              sampleList =(ArrayList) attributeValue2samples.get(attributeValue);
          else 
              sampleList = new ArrayList (); 
        
          // put current sample to the list     
          sampleList.add(samples[i]);  
          attributeValue2samples.put(attributeValue, sampleList); 
          // put the value to the list    
      }
		
		
  
		System.err.println( " 463 returned  sizxe fo f hash  " + attributeValue2samples.size() ); 
   		
		
	  return attributeValue2samples;   
    }               
            
   
public static HashMap populateData2samples (JspWriter out, HashMap value2samples, int type, Date currentDate , ArrayList  invalidValues  ) throws SampleException {
    HashMap v2samples = new HashMap (); 
    
    if (type <=1) 
        return value2samples; 
    
    if (value2samples == null || value2samples.isEmpty()) 
        return value2samples;
    
    Iterator iterator = value2samples.keySet().iterator(); 
    while (iterator.hasNext()) {
        String attValue = (String) iterator.next();
        
        if (attValue == null || attValue.length() ==0) 
        throw new SampleException ("Error in SampleHelper.populateData2samples  : key value is null  " + attValue);                         
        
        // get arraylist for samples with same value     
        ArrayList sampleList = null; 
        if (value2samples.get(attValue ) != null)               
            sampleList =(ArrayList) value2samples.get(attValue );
        
        
        if (sampleList == null || sampleList.isEmpty())   
        throw new SampleException ("Error in SampleHelper.populateData2samples  : sample list is emoty for key   " + attValue);                         
       
        Object o = SampleHelper.validateType ( attValue, type);
        if (o!= null) {                      
            v2samples.put(o.toString(), sampleList);                     
        }
        else {
            invalidValues.add(attValue); 
            String maxValue =  SortingUtility.findMaxValue (type, currentDate);  
            ArrayList list =  null; 
            if (v2samples.get(maxValue) != null) {   
                list = (ArrayList) v2samples.get(maxValue); 
                                    
            }
            else 
                list = new ArrayList (); 
             for (int i=0; i<sampleList.size(); i++)
                    list.add(sampleList.get(i));     
            
            v2samples.put (maxValue, list);   
        }  
    }
  
    return v2samples;   
}               
   
	public static   SortResult sortSampleByAttribute (JspWriter out, Sample [] samples , String sortName, int attIndex , Date currentDate, boolean isAscendingOrder)  {
		
		System.err.println (" 520 in SampleSOerter.sortSampel by att    " );                      
			
		
		
		SortResult result = new SortResult();
		//  result.dataType2sortedData = new HashMap ();         
		int [] arr = new int [samples.length];  
		// created a value  to sample hashmap , and find uniq attribute values of the sorting attributes in all samples 
		Attribute [] attributes = null;        
		boolean hasData = false; 
		
		int order = 0; 
		if (!isAscendingOrder) 
		order =1; 
	
		HashMap stringValue2sample = mapAttribute2Samples (samples, attIndex, sortName);  
		int  dataType = SampleHelper.findAttributeDataType (samples, attIndex, sortName); 
		if (dataType >0) 
		hasData = true; 
		else 
		dataType = 1; 
		
		result.setDataType(dataType); 
	
		HashMap data2samples = new HashMap();      
		HashMap h = new HashMap (); 
	
		data2samples = stringValue2sample;

		result.setValue2Samples(data2samples);   
		String [] keys = (String [])data2samples.keySet().toArray(new String [data2samples.size()]);     
		
		HashMap sample2OrderMap = new HashMap (); 
		
		
		
	String [] orderedKeys =  SortingUtility.sortArray(keys, order, dataType, maxString, currentDate) ; 
   
		
		try {
		sample2OrderMap = SampleHelper.setSampleOrder(out, data2samples, orderedKeys);
		}
		catch (SampleException e) {
		System.err.println("<br> error happened in 897  " +  data2samples.size() );  	  
		
		//throw e;          
		}   
		
		HashMap dataType2keys = new HashMap (); 
		dataType2keys.put("dataType", orderedKeys);  
		result.setDataType2sortedData(dataType2keys);
		try {   
		arr = SampleHelper.findSampleOrders (samples, sample2OrderMap);     
		}
		catch (SampleException e) {
		System.err.println("<br>   error happened in 909  "  );  	  
		
		}   
		
		result.setSampleOrder(arr);    
		

		System.err.println( " 611 returned  result  " + result ); 
   			
		
		return  result;  
	} 
	                             
	
	
	public static Sample[] sortSamplesByName(Sample[] totalSamples, boolean isAscendingSort) {
			HashMap map = new HashMap();
			Sample[] sortedSamples = null;
	   
			if (totalSamples != null && totalSamples.length > 0) {
				sortedSamples = new Sample[totalSamples.length];
				String name = null;
				String id = null;
				for (int i = 0; i < totalSamples.length; i++) {
					name = totalSamples[i].getSampleName();
					ArrayList list = new ArrayList();
					if (name != null && map.get(name) != null)
						list = (ArrayList) map.get(name);
					list.add(totalSamples[i]);
					map.put(name, list);
				}

				if (!map.isEmpty()) {
					int index = 0;
					String[] names = (String[]) map.keySet().toArray(new String[map.size()]);
					// sorting by names
					if (isAscendingSort)  	// ascending sort 	
						LayoutHelper.alphabeticSort(names);
					else   // descending 
						Arrays.sort(names, Collections.reverseOrder());

					//  reorder sampels 
					for (int i = 0; i < names.length; i++) {
						ArrayList list = (ArrayList) map.get(names[i]);
						for (int j = 0; j < list.size(); j++) {
							sortedSamples[index] = (Sample) list.get(j);
							index++;
						}
					}
				}

			}

			return sortedSamples;
		}
	
	
	
	public static  Sample [] sortAllSamplesByColumn (JspWriter out, String sortName, int  index,  Sample [] samples, HashMap attribute2Index, boolean isAscendingSort) {   
		
		            if ( sortName == null )        
				return samples;  
   
		  Sample [] sortedSamples = new Sample[samples.length];              
    	  HashMap sortName2OrderArray = new HashMap (); 
		  HashMap id2index = new HashMap (); 
		  for ( int j=0; j<samples.length; j++) 
			  id2index.put("" + samples[j].getSampleId(), new Integer(j)); 
		  String [] sortNames = new String [] {sortName} ; 
		 // int [] attributeIndexes = populateAttributeIndexes(sortNames, attribute2Index);
		
		//  if (attributeIndexes == null || attributeIndexes.length ==0) 
		//	  System.err.println("Error: error in function populateAttributeIndexs: returned null value for sort names" ); 
		 
		   SortResult result =  null; 
			
		    int attributeIndex= -1;
  		  attributeIndex = index;
			  //try {
			   result = sortSampleByAttribute (out, samples, sortNames[0],  attributeIndex, currentDate, isAscendingSort); 
     	  sortName2OrderArray.put(sortNames[0], result.sampleOrder); 
			   HashMap key2Samples =  result.value2Samples;               
		   String [] orderedKeys = (String [])result.dataType2sortedData.get("dataType");                     
		   int currentIndex = 0;         
			ArrayList sampleList = null; 
 			  for (int i=0; i<orderedKeys.length ; i++) {                                
				  if (key2Samples.get(orderedKeys[i]) == null) {
					  System.err.println(" there is no sample sor key    "   +  orderedKeys[i]) ; 
							         
					  continue; 
					 	 	// throw new SampleException (" key " + orderedKeys[i] + " has no matching sample " );               
				  }
              
				 sampleList = (ArrayList)key2Samples.get(orderedKeys[i]);
             
				  if (sampleList== null || sampleList.isEmpty()) {
					  System.err.println(" there is no sample sor key    "   +  orderedKeys[i]) ; 
					  
					   continue;  
					  
					//	throw new SampleException (" key " + orderedKeys[i] + " has no matching sample " );               
				 }
                
				
						
				  if (sampleList != null && sampleList.size() ==1) {
						sortedSamples [currentIndex ] =(Sample) sampleList.get(0); 
						currentIndex ++; 
				  }
              
				 else  if (sampleList != null && sampleList.size() >1) {          
							for (int k=0; k< sampleList.size(); k++) {
							   if (currentIndex < samples.length) 
								sortedSamples [currentIndex ] = (Sample)sampleList.get(k);
								currentIndex ++; 
							}                                                
						 
				  }
	  }
		
		System.err.println(" 692 returned samples    "  + sortedSamples.length); 
       
					        
// if no sort selected, do nothing     
		return sortedSamples;    
	   }
    
     	
	
	
	
	}
