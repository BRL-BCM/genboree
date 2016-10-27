package org.genboree.samples;

/**
 * User: tong
 * Date: Nov 30, 2006
 * Time: 3:24:40 PM
 */
 
import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.util.HashMap;

public class SampleFileValidator {

         
    /**
           * validate passed  sample file for intactness and correctness
           * assumes: 
           * text file delimited by tabs
           * rows can be empty 
           * The first now empty row is header line for attribute names
           * In the none-empty line, the first column is sample id; -- no tabs before sample id 
           * attribute could have no values 
           * 
           * error 1:  number of values does not match number of attributes
           * error 2:  has right number of values but no sample Id
           * error 3:  file has only one line of data (could be either name or value)
           * error 4: file does not exist
           * error 5:  file is blank;
           * error 6:  duplicate samples
           *@ return : empty ArrayList if success; null if file does not exist; other wise, non-empty arraylist    
           */ 
public static  SampleError   validateFile (File file, String fileName) {                
    int errCount = 0;
    int numAttributes = 0; 
    int numDataLines = 0; 
    int lineNum = 0; 
    SampleError  err = new SampleError(fileName); 
    // this should not happen as the file is already uploaded
    if (file == null || !file.exists()) {
    err.errStatus = 100;  
    err.error2Line.put("error_" + errCount, " File not exist or wrong permission " );   
    return err; 
    }
    int firstLine = 0; 
    HashMap  id2count = new HashMap ();
    int   firstHeaderTokenIndex  = -1; 
    int firstValueTokenIndex = -1; 
    boolean processed = false; 
    // start validate 
    try {         
        BufferedReader br = new BufferedReader(new FileReader (file) ); 
        String line = null; 
        boolean isHeaderLine = true; 
        String [] headLineAttributes = null; 
        String [] attributes = null; 
         int  arrLength  = 0; 
        while ((line = br.readLine()) != null ) {
             
            lineNum ++; 
          //  line = line.trim(); 
            if (line =="" || line.length() ==0 ) 
                continue;
            else {
                numDataLines ++;                              
                if (firstLine ==0) 
                    firstLine = lineNum; 
            } 
            String testLine = line.trim(); 
            if (testLine == "" || testLine.length() ==0) 
              continue; 
                          
            attributes = line.split("\t");        
            if (attributes != null) 
                arrLength = attributes.length;   
                                                                                                 
            if (isHeaderLine) {      // find the position of first column label          
                String firstColumnLabel =  null; 
                 
                if (attributes != null && attributes.length > 0)  {
                    firstColumnLabel = attributes[0];
                    numAttributes = arrLength; 
                }
                
                if (firstColumnLabel != null ) 
                    firstHeaderTokenIndex = line.indexOf(firstColumnLabel); 
                
                if (firstHeaderTokenIndex <0) {
                    err.errStatus = 300; 
                    err.error2Line.put("error_" + errCount, "Line " + lineNum + ":\tblank attribute " +line );   
                    break;
                }
                isHeaderLine = false;  
            }               
            else {
                String sampleId =  null; 
                if (attributes != null && attributes.length > 0)
                   sampleId = attributes[0];
                  
                       String testValue = ""; 
                // get sampleId  index 
                if (sampleId  != null && !processed){                        
                        testValue = sampleId.trim();
                         boolean isBlank = false; 
                        if (testValue.length() ==0)  {  
                              isBlank = true; 
                           err.errStatus = 300; 
                            errCount++; 
                            err.error2Line.put("error_" + errCount,  "Line "+lineNum + "\t" + line);  
                            break;                           
                        }
                    
                    firstValueTokenIndex = line.indexOf(sampleId );                     
                    // case 1, there is a value in the cell cross header and sampleId                 
                    if (firstValueTokenIndex == firstHeaderTokenIndex ) {   
                        numAttributes --; 
                        processed = true; 
                    } 
                    else if (firstValueTokenIndex < firstHeaderTokenIndex) {
                        // in this case, the cell cross header and sampleId is blank
                        processed = true; 
                    }                  
                   else {                      
                        // all other possible cases are wrong              
                        err.errStatus = 300; 
                        errCount++; 
                        err.error2Line.put("error_" + errCount,  "Line "+lineNum + ":\t" + line);  
                        break;
                    }
                     processed = true;                     
               }
               else {
                    if (sampleId  == null )  {
                            err.errStatus = 300; 
                            errCount++; 
                            err.error2Line.put("error_" + errCount,  "Line "+lineNum + ":\tblank id" );   
                            break;
                        }   
                        else {
                           sampleId = sampleId.trim();
                           if (sampleId.length() == 0) {
                                err.errStatus = 300; 
                                errCount++; 
                                err.error2Line.put("error_" + errCount,  "Line "+lineNum + ":\tblank id" );   
                                break;
                           }
                        }
                 }  
                 
                if (  numAttributes >0 && numAttributes < arrLength-1 )  {
                    err.errStatus = 300; 
                    err.error2Line.put("error_" + errCount,  "Line "+lineNum + ":\tmore data values than attribute columns." );   
                    errCount++; 
                 };
                
                if (attributes.length > 0 && (sampleId.equals("") )){ 
                        err.errStatus = 300;                      
                        err.error2Line.put("error_" + errCount,  "Line "+lineNum + ":\tblank id" );
                       errCount++; 
                           break;
                } 
            
            // check duplicate of id 
                if (id2count.get(sampleId ) == null) {
                    id2count.put(sampleId , "" + lineNum); 
                }
                else {
                    err.errStatus = 300; 
                    err.error2Line.put ("error_" + errCount,  "Line "+lineNum + ":\tduplicate sample id ('" +  sampleId + "' already used in this file)."  );  
                    errCount++;                            
                    if (errCount >30) 
                    break; 
                }
            }
          
        }  br.close();
    } 
    catch (IOException e) {            
        e.printStackTrace();
        err.errStatus = 100; 
        return err;    
    }    
        
    if (numDataLines == 0) 
        err.errStatus = 110;        
    else if(numDataLines == 1) { 
        err.errStatus = 300;
        err.error2Line.put ("error_0" , "Line 1:\tfile has only one line of data.");  
    } 
         
    return err;   
}
                        
   
        public static void main (String [] args ) {
           String fileName = "test.txt"; 
           if (args.length >0)
               fileName = args[0];
        
           File file = new File (fileName);
           validateFile (file, ""); 
        
        }
    
        
    }

