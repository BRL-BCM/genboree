package org.genboree.samples;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Iterator;

/**
 * User: tong
 * Date: Nov 9, 2006
 * Time: 4:29:28 PM
*/
public class SampleRetriever {      

/**
 * an inner class for temporary data storage which correspond to a recrod in original data record
  */    
private static  class Data  {
    int sampleId ; 
    int attributeId; 
    String sampleName; 
    String attName; 
    String value;        
}

 /**
  *  functions created to retrieve samples with selected attributes and display order 
  *  
   * @param con
  * @param selectAll boolean 
  * @param saNames String  attribute name list to be selected
  * @param attributeOrder2Name HashMap of display order to attribute Name ; start with one   
  * @return sample [] ; null if none selected 
  */  
    public static  Sample [] retrieveAllSamples (Connection con, boolean selectAll, String saNames, HashMap attributeOrder2Name) {
        Sample [] samples = null;   
        HashMap id2sample = new HashMap (); 
        HashMap sample2Id = new HashMap ();   
        String [] sampleNames = null;
        String sqlSample = "select  saID,  saName from samples order by saName "; 
        String sqlAtt = "select a.saAttNameId, a.saName  from samplesAttNames a  "
        + " where  a.saName in (" + saNames +  ") " ; 
      
         if (selectAll) 
             sqlAtt = "select a.saAttNameId, a.saName  from samplesAttNames a order by a.saName "; 
      
         // get sample info  , ok   
       ArrayList sampleNameList = new ArrayList ();  
      try {
          PreparedStatement stms = con.prepareStatement(sqlSample);   
            ResultSet rs = stms.executeQuery();             
         
            while (rs.next()) {
          id2sample.put(rs.getString(1), rs.getString(2)); 
            sample2Id.put(rs.getString(2),  rs.getString(1));
                sampleNameList.add(rs.getString(2)); 
            }
             sampleNames = (String [])sampleNameList.toArray(new String [sampleNameList.size()]); 
           Arrays.sort(sampleNames);
             ArrayList saIdList = new ArrayList ();        
        // get attribute info      
        HashMap attributeName2id = new HashMap ();            
        stms = con.prepareStatement(sqlAtt);   
        rs = stms.executeQuery();         
        while (rs.next()) {
            saIdList.add(rs.getString(1)); 
            attributeName2id.put(rs.getString(2), rs.getString(1));   
        } 
         
        int numAttributes = saIdList.size();    
       // prepare id for  query of savalue
        String saIds = "";      
        for (int i=0; i<saIdList.size(); i++) {
            saIds += "'" + (String)saIdList.get(i) + "', ";            
        }     
           
        int index = saIds.lastIndexOf(','); 
        saIds = saIds.substring(0, index ) ;                       
        String valueids = "";    
        // get  mapping  info
        HashMap saId_attId2valueId = new HashMap(); 
        String sql3 = "select saId, saAttNameId, saAttValueId from samples2attributes where saAttNameId in (" + 
        saIds + ") ";
        stms = con.prepareStatement(sql3);                     
        rs = null; 
        rs = stms.executeQuery();  
        ArrayList templist = new ArrayList (); 
        while (rs.next()) {
            String vid = rs.getString(3);
            saId_attId2valueId.put(rs.getString(1) + "_" + rs.getString(2), vid);          
            if (vid != null && !templist.contains(vid)) {
                valueids +="'" + vid+"', "; 
                templist.add(vid); 
            }
        }                            
        valueids = valueids.substring(0, valueids.lastIndexOf(','));                                                                      
       // get value info
        ArrayList valueList = new ArrayList (); 
        String sqlValue = "select saAttValueId,  saValue from samplesAttValues  where  saAttValueId in (" + valueids + ")";
        stms = con.prepareStatement(sqlValue);  
        rs = null; 
        rs = stms.executeQuery(); 
             HashMap id2value = new HashMap ();   
        while (rs.next()) {        
            //valueList.add(attribute);
            id2value.put(rs.getString(1), rs.getString(2));  
        }                  
       rs.close(); 
       stms.close();            
       Iterator iterator = id2sample.keySet().iterator();  
     
       samples = new Sample[id2sample.size()]; 
       for (int  n=0; n<sampleNames.length; n++) {
           // set Sample name and Id 
            Sample sample = new Sample (); 
            sample.setSampleName(sampleNames[n]); 
            String sampleId = (String)sample2Id.get(sample.getSampleName());
            int id = -1; 
             if (sampleId != null) 
                   id =  Integer.parseInt(sampleId);  
            sample.setSampleId(id);
           
            Attribute [] attributes = new Attribute [numAttributes]; 
            int count = 0; 
            for (int i =0; i<numAttributes; i++) {
                int order = i+1; 
                    attributes[i] = new Attribute(); 
                String attName =  null; 
                if (attributeOrder2Name.get("" + order) != null) {
                    attName = (String)attributeOrder2Name.get("" + order);
                    attributes[i].setAttributeName(attName);          
                } 
               
                String attributeId = null; 
                if (attName != null && attributeName2id.get(attName) != null) 
                   attributeId = (String)attributeName2id.get(attName); 
                 
               
               int aid = 0; 
                try {
                    if (attributeId != null) 
                aid = Integer.parseInt(attributeId);
                }
                catch (NumberFormatException e) {
                    System.err.println(" in valid name " + attName + "  id " + attributeId);
                    System.err.flush();
                    continue; 
                }
               attributes[i].setAttributeId(aid);
            
                String valueId  = (String) saId_attId2valueId.get(sampleId+"_" + attributeId);                          
                String value = (String)id2value.get(valueId);  
                attributes[i].setAttributeValue(value); 
            
            }
            sample.setAttributes(attributes);
            samples[n] = sample;        
         
        }
         
      } 
      catch (Exception e) {
          e.printStackTrace();
      } 
     return samples ;   
  }
    
    /**
     * retrieves all attribute names from table  saAttName

     * @param con
     * @return String [] of attribute names; null if none is found 
     */    
    public  static int countAllSamples (Connection con) {
       int totalNumSamples = 0; 
        try {
             String sql = "select count(*) from samples ";          
             PreparedStatement stms = con.prepareStatement(sql);   
             ResultSet rs = stms.executeQuery();          
             if  (rs.next()) {         
               totalNumSamples = rs.getInt(1);
               
            }      
            rs.close(); 
            stms.close();                           
        }
        catch (SQLException e) {
            e.printStackTrace();
        }
       return totalNumSamples;
    }  
    
       
 

/**
 * retrieves all attribute names from table  saAttName

 * @param con
 * @return String [] of attribute names; null if none is found 
 */    
public  static String [] retrievesAllAttributeNames (Connection con) {
    String  [] attributeNames = null; 
    ArrayList list = new ArrayList (); 
    try {
         String sql = "select distinct saName from samplesAttNames order by saAttNameId ";          
         PreparedStatement stms = con.prepareStatement(sql);   
         ResultSet rs = stms.executeQuery();          
         while (rs.next()) {         
            String attName = rs.getString(1);
            if (attName != null)  
                list.add(attName); 
        }      
        rs.close(); 
        stms.close();                           
    }
    catch (SQLException e) {
        e.printStackTrace();
    }
    
    if (!list.isEmpty()) 
        attributeNames = (String [])list.toArray(new String [list.size()]);
    
    return attributeNames;
}  
    
    
  
   public static void  main (String [] args) {
   
   } 
    
}
