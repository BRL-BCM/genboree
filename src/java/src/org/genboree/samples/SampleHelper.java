package org.genboree.samples;



import org.apache.commons.validator.DateValidator;
import org.apache.commons.validator.routines.BigDecimalValidator;
import org.apache.commons.validator.routines.CurrencyValidator;
import org.apache.commons.validator.routines.DoubleValidator;
import org.apache.commons.validator.routines.IntegerValidator;

import javax.servlet.jsp.JspWriter;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Locale;

/**
 * User: tong
 * Date: Feb 13, 2007
 * Time: 9:57:25 AM
 */
public class SampleHelper {
   
   public static HashMap setHash(Sample [] totalObjs, int numPages, int displayNum) {
    int baseIndex = 0;
    HashMap page2Obj  = new HashMap ();   
    for (int k=0; k<numPages; k++) {
        baseIndex = k*displayNum;
        if ((totalObjs.length - k * displayNum) >= displayNum){
            Sample [] objs = new Sample[displayNum];            
            for (int m=0; m<displayNum; m++)
             objs[m] = totalObjs[baseIndex+m];
            page2Obj.put("" + k, objs);
        }
        else {
            int remainNum =  totalObjs.length - k * displayNum;
            if (remainNum > 0 ) {
                Sample [] objs = new Sample[remainNum];
                for (int m=0; m<remainNum; m++)
                objs[m] = totalObjs[baseIndex+m];
                page2Obj.put("" + k, objs);
            }
        }
     }                        
    return  page2Obj ; 
   }   
    
    
 /**
  * validate if the passed String is the data type labeled 
  * @param s
  * @param type
  * @return
  */   
    public static Object  validateType (String s, int type ) {
            Object o = null; 
            if (s == null && type > 1) 
                return null; 
            else if (type <=1) 
                return s;
              
            switch  (type) {
               case (SampleConstants.INTEGER_TYPE) :                  
                    try {
                    return  org.apache.commons.validator.routines.IntegerValidator.getInstance().validate(s); 
                     } 
                    catch (Exception e) {                         
                        o = null;                    
                    }
                break;
                     
                     case (SampleConstants.MONEY_TYPE) :                  
                    try {
                        
                              BigDecimalValidator validator = CurrencyValidator.getInstance();

        o = validator.validate(s, Locale.US);
                      } 
                    catch (Exception e) {                         
                        o = null;                           
                    }
                break;
                     
                     
               case (SampleConstants.DOUBLE_TYPE) :                  
                    try {
                       return  org.apache.commons.validator.routines.DoubleValidator.getInstance().validate(s); 
                      } 
                    catch (Exception e) {                         
                       o = null;                        
                    }
                break;
                     
                     
                                                   
               case (SampleConstants.DATE_TYPE) :                  
                   try {
                       return org.apache.commons.validator.routines.DateValidator.getInstance().validate(s);                      
                   } 
                   catch (Exception e) {                         
                      o = null;                    
                   }
               break;
                     
                     
                 default: 
              break; 
                 }  
              
              
             return o; 
         }
             
   
    
    
    public static int findDataType (String s) {
     
     if (s == null ) 
       return -1; 
        s = s.trim(); 
        if (s.equals("")) 
          return -1; 
     
        Integer integer = IntegerValidator.getInstance().validate(s); 
     
        if (integer != null) 
            return SampleConstants.INTEGER_TYPE; 
    
         Double dou = DoubleValidator.getInstance().validate(s); 
        if (dou != null) 
          return SampleConstants.DOUBLE_TYPE;
     
     
       try {
        if (DateValidator.getInstance().isValid(s, "mm/dd/yyyy", false) || DateValidator.getInstance().isValid(s, "yyyy/mm/dd", false) ||DateValidator.getInstance().isValid(s, "mm-dd-yyyy", false))     
           return SampleConstants.DATE_TYPE; 
       } 
       catch (Exception e) {
        
       } 
 
        if (s.startsWith("$") ) {
           BigDecimalValidator validator = CurrencyValidator.getInstance();
           BigDecimal fooAmount = validator.validate(s, Locale.US);
   
           if (fooAmount != null)     
           return SampleConstants.MONEY_TYPE; 
        }
    
        return SampleConstants.STRING_TYPE; 
    }   
       
    
    
    
    public static int [] findSampleOrders (Sample [] samples , HashMap map ) throws SampleException  {
        int [] orders =  null; 
        if (samples == null  || samples.length ==0) 
        return null; 
        
        if (map == null) 
        throw new SampleException ("Error in SampleHelper.findSampleOrdders: samples is not empty, the map is null "); 
        
        orders = new int [samples.length]; 
        String  index =null; 
        for (int i=0; i<samples.length; i++) { 
            if (samples[i] == null) 
                throw new SampleException ("Error in SampleHelper.findSampleOrdders: samples "  + i + "  is null." ) ;  
            
            if (map.get(""+samples[i].getSampleId()) != null) {
                index = (String)map.get(""+samples[i].getSampleId());                   
                if (index != null)  {                  
                    try {
                        orders[i] = Integer.parseInt(index);
                    }
                    catch (NumberFormatException e ) {        
                        throw new SampleException ("Error in SampleHelper.findSampleOrders: sample  " + samples[i].getSampleName()  + "  id " +   samples[i].getSampleId() + " has invalid index " + index);  
                    } 
                }
                else         
                    throw new SampleException ("Error in SampleHelper.findSampleOrders: sample  " + samples[i].getSampleName()  + "  id " +   samples[i].getSampleId() + " has null index " );                         
            }
            else               
                throw new SampleException ("Error in SampleHelper.findSampleOrders: sample " + samples[i].getSampleName()  + "  id " +   samples[i].getSampleId() + "  is not set in order map." );                     
        }   
        return orders; 
       }      
          
          
    public static HashMap setSampleOrder (JspWriter out, HashMap map, String [] orderedKeys)  throws SampleException{
         HashMap orderedSampleMap = new HashMap ();  
         ArrayList list = null; 
          if (orderedKeys == null || orderedKeys.length ==0 ) 
              throw new SampleException("Error in SampleHelper.setSampleOrder: passed key values is null "   );                                                   
          
           if (map == null || map.size() == 0) 
               throw new SampleException("Error in SampleHelper.setSampleOrder:  passed key2sample map is null" );                                                   
                         
         for (int i=0; i< orderedKeys.length; i++) {
                String  key  = orderedKeys[i];
                if (key != null && map.get(key) !=null ) {
                    list = (ArrayList)map.get(key); 
                    if (list != null && !list.isEmpty()) { 
                        for (int k=0; k<list.size(); k++){
                        Sample sample = (Sample)list.get(k); 
                        orderedSampleMap.put(""+sample.getSampleId(), "" + i); 
                        }
                    }
                    else {
                        throw new SampleException("Error in SampleHelper.setSampleOrder:  key " + key + " has no corresponding values "   );                                                   
                    }   
                }
                else  {                           
                    throw new SampleException("Error in SampleHelper.setSampleOrder:  key " + key + " has no corresponding values "   );                                   
                }
          } 
        
        return orderedSampleMap; 
    }  
          
    public static int findAttributeDataType (Sample [] samples , int attIndex, String sortName) {   
           int dataType = -1; 
                // if sorting by sample name
                    if (sortName.equals("saName")) 
                    return 1; 
         HashMap skipTypes = new HashMap (); 
            skipTypes.put("" , "y"); 
            skipTypes.put("n/a" , "y"); 
            skipTypes.put("N/A" , "y"); 
            skipTypes.put("-" , "y"); 
            skipTypes.put("--" , "y"); 
            skipTypes.put("_" , "y"); 
            skipTypes.put("__" , "y");              
            skipTypes.put("." , "y"); 
            skipTypes.put("n/A" , "y"); 
            skipTypes.put("N/a" , "y"); 

             Attribute [] attributes = null; 
            for (int i=0; i<samples.length; i++) {                  
         // find the values of the sorting attributes in sample j     
         attributes = samples [i].getAttributes();
         String attValue = null; 
         // if no attributes, or no attribute, or attribute value is null, put to last
         if (attributes == null || attributes[attIndex] == null || attributes[attIndex].getAttributeValue() == null )                    
         continue;      
       //  else // get get attribute value 
         attValue= attributes[attIndex].getAttributeValue() ; 
        
            
         // put null value and blank to bottom of array     
         attValue = attValue.trim(); 
         if (skipTypes.get( attValue ) != null) 
         continue;
                
          
         dataType =  SampleHelper.findDataType(attValue);
         break;        
        
     }
     return  dataType;   
          
        }          
          
                        
  
}
