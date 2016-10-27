package org.genboree.tabular;

import org.genboree.editor.AnnotationDetail;
import org.genboree.util.Util;
import javax.servlet.jsp.JspWriter;
import java.util.HashMap;
import java.util.ArrayList;
import java.util.Date;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.io.*;

/**
 * User: tong
 * Date: Mar 23, 2007
 * Time: 2:34:35 PM
 * this is a short version of LffParser with function rewirtten for a faster parsing.
 * The following assumptions are used: 
 *  1. file format is lff annotation   only
 *  2. the file format is fixed lff format. i,e., the order of lff names is not changed.
 
 * 
 */
public class LffParser {
  
    protected String regex2  = "((?:\\s*[^=;]{1,255}\\s*=\\s*[^;]*\\s*;)+)([^\t]*)";
    protected String regex3  = "\\s*[^=;]{1,255}\\s*=\\s*[^;]*\\s*;";
    protected String regex4  = "(?:\\s*[^=;]{1,255}\\s*=\\s*[^;]*\\s*;)+([^\t]*)";
    
    //           "^\\s*inflating:\\s*(.*)\\s*$";
   // protected Pattern compiledRegex3 = Pattern.compile( regex3, 8); // 40 is 8 (Multiline) + 32(DOTALL)  
  //  protected Matcher match3 = compiledRegex3.matcher("empty");
  
    protected Pattern compiledRegex2 = Pattern.compile( regex2, 8); // 40 is 8 (Multiline) + 32(DOTALL)
    protected Matcher match2 = compiledRegex2.matcher("empty");
 
   // protected Pattern compiledRegex4 = Pattern.compile( regex4, 8); // 40 is 8 (Multiline) + 32(DOTALL)
   // protected Matcher match4 = compiledRegex4.matcher("empty");
   
   static  Pattern headerPattern = Pattern.compile("^\\s*#\\s*class\\s*");
   static  Matcher headermatcher = headerPattern.matcher("empty");

    static  HashMap lff2index ;
    
  public   LffParser  () {
       lff2index = new  HashMap ();
       String [] LFF_NAMES =  new String[] { "#class", "name",  "type",  "subtype",  "ref", "start", "stop", "strand", "phase", "score", "qStart", "qStop", "attribute-comments", "sequence",  "freeform-comments"};
      
       for (int i=0; i<LFF_NAMES.length; i++) 
          lff2index.put (LFF_NAMES[i] , new Integer(i)) ; 
          
  }
   
    
    public ParseResult  parse4Annotation (String fileName, JspWriter out, long limit ) {
         HashMap fid2anno = new HashMap ();  
         ParseResult result = new ParseResult();
         result.setFileName(fileName);   
         result.setEndTime(new Date());    
        
         result.setStartTime( new Date()); 
            int lineNumber = 0;
            try {
       
            File file = new File (fileName); 
            BufferedReader  br = new BufferedReader( new FileReader (file ) );          
            String s = null;           
            AnnotationDetail annotation = null;
            boolean start = false;   
            boolean isdataline = false;
            HashMap attributesHash  = new HashMap (); 
            HashMap trackNameHash = new HashMap ();      
          
            String fmethod = null; 
            String fsource = null; 
            long currentSize = 0;
                 
            while((s = br.readLine()) != null && currentSize < limit ) {
                lineNumber++;
                 
                if (!start) 
                     start =  parse4AnnotationStart(s); 
                else  {
                 currentSize += s.getBytes().length;
                
                
                    if (!isdataline)
                        annotation = parse4FirstDataLine (s, lineNumber,attributesHash);  
                    else
                        annotation = parseAnnotation(s, lineNumber, attributesHash); 
                
                    if (annotation != null) {
                        isdataline = true; 
                        fid2anno.put("" +  lineNumber, annotation);
                        fmethod = annotation.getFmethod();
                        fsource = annotation.getFsource();
                        if (fmethod != null && fsource != null) 
                            trackNameHash.put(fmethod + ":" + fsource, "y"); 
                    }              
                }
               
            }    
            br.close();
             
                 result.setFid2annos(fid2anno);
               
                String [] avpAttributes = null; 
                if (!attributesHash.isEmpty()) 
                     avpAttributes = (String [])attributesHash.keySet().toArray(new String [attributesHash.size()]);
              result.setAvpAttributes(avpAttributes);   
               
                String [] trackNames = null; 
                            if (!trackNameHash.isEmpty()) 
                                 trackNames = (String [])trackNameHash.keySet().toArray(new String [trackNameHash.size()]);
               result.trackNames = trackNames;        
               
              
                result.setEndTime(new Date());   
                   
                } 
            catch (FileNotFoundException e) {
                e.printStackTrace(System.err);  //To change body of catch statement use File | Settings | File Templates.
            } 
            catch (Exception e) {
                e.printStackTrace(System.err);  //To change body of catch statement use File | Settings | File Templates.            
            }
            return result;         
        }
            
    
    /**
     * search for annotation start label with [annotations] label
      * @param s
     * @return
     */    
        public boolean   parse4AnnotationStart( String s ){          
            AnnotationDetail annotation = null; 
            if (s ==null)  
                return false;     
        
            if( (s.length() == 0))     
                return false ;
        
            String[] data = s.split("\t") ; // 99% of the time we need to do this anyway
        
            if(data != null && data.length == 1) // then maybe a header line (or who knows what?)  
                if( s.regionMatches(true, 0, "[annotations]", 0, 13) ) {                       
                return true ;
            }
            return false;
        }
    
    
    
    /**
     * try to skip the header line if exist.
     * if it has a header line starts with #\s*class
     * @param s
     * @param fid
     * @param map
     
     * @return  annotation if is data line; else null
     */ 
    
    public AnnotationDetail  parse4FirstDataLine( String s, int fid, HashMap map){     
        AnnotationDetail annotation = null; 
        if (s!= null) 
        s = s.trim(); 
        if(s == null || s.length() == 0)     
        return  null ;            
    
        String[] data = s.split("\t") ; // 99% of the time we need to do this anyway
        if (data == null || data.length <10) 
        return null;             
  
        if(data.length >= 10 ) {
            if (data[0] != null) {
                 String temp = data[0].trim();
              headermatcher.reset(temp);
                 if (headermatcher.find())  {
                     
                   return null;                      
                 }
            
            else  {
                  annotation = parseAnnotation(s, fid, map );  
            
            } 
        }}
     
        return annotation;
    }
        
    
    public AnnotationDetail  parseAnnotation(String s, int fid, HashMap map){             
        if (s == null)  
            return null;     
        
        String[] lffData = s.split("\t") ; // 99% of the time we need to do this anyway                  
        int length = 0;           
                    if (lffData == null || lffData.length <10) 
                        return null;
                    else 
                     length = lffData.length; 
                  
              AnnotationDetail annotation = new AnnotationDetail (fid);   
              // set class name 
               String  className = lffData[0];   
                  if (className != null)       
                  className = className.trim();
                  annotation.setGclassName(className);
             
               
                 String  groupName = lffData[1];   
               if(groupName != null)          
               groupName = groupName.trim();         
               annotation.setGname(groupName);
         
                String type =lffData[2];        // ftype.fmethod
               if(type != null)
               type = type.trim();         
               annotation.setFmethod(type);
             
         
               String   subType  = lffData[3];   
               if(subType != null)
               subType = subType.trim();
               annotation.setFsource(subType);
         
             String  entryPoint = lffData[4];   
                        if(entryPoint != null)
                    entryPoint = entryPoint.trim();
                  annotation.setChromosome(entryPoint);               
         
      
          long  start = Util.parseLong( lffData[5], 1L );
          long  stop = Util.parseLong( lffData[6], 1L );
          annotation.setStart(start);
          annotation.setStop(stop);
         
         
                String  strand = lffData[7];   
               if(strand == null) 
                   strand = "+";            
               annotation.setStrand(strand);
          
              String  phase = lffData[8];   
               if(phase == null) 
                   phase = "0";
     
                annotation.setPhase(phase);
               String  scoreStr  = lffData[9];   
               if(scoreStr == null)
                   scoreStr = "0.0";
             
               scoreStr = scoreStr.trim();
               if(scoreStr.startsWith("e") || scoreStr.startsWith("E"))
               scoreStr = "1" + scoreStr;
               else if(scoreStr.startsWith(".") )
               scoreStr = "0" + scoreStr;
                 double  score =  0.0;
                  try{
                     score = Double.parseDouble( scoreStr );
                  }
                  catch(  Throwable thr )
                  {
                      //reportError(  "Unable to read score field" );
                      return null;
                  }
               annotation.setScore(score);
             
           
               long targetStart =  0; 
             if (length >=12) {
                 targetStart = Util.parseLong( lffData[10] , 0L );
               if(targetStart >= Integer.MAX_VALUE) targetStart = Integer.MAX_VALUE -1;
               if(targetStart <= Integer.MIN_VALUE) targetStart = Integer.MIN_VALUE+1;
            
               long targetStop = Util.parseLong( lffData[11]   , 0L );
         
               if(targetStop >= Integer.MAX_VALUE)
               targetStop = Integer.MAX_VALUE -1;
               if(targetStop <= Integer.MIN_VALUE) 
               targetStop = Integer.MIN_VALUE +1;
               if(targetStop == 1 && targetStart == 1){
               targetStop = targetStart = 0;
               }
                       
               annotation.setTargetStart(targetStart);
               annotation.setTargetStop(targetStop);
             }
            
              // retrive comments  and sequences         
         
          if (length >=14)  {
                    String avps = lffData[12];   
                    annotation.setSequences(lffData[13]);   
                    
                    try {  
                        if( avps != null ){
                        avps = avps.trim();
                        if(avps.length() > 1) {   
                            // clean avps string by replace ;\\s* with "; "
                            avps = avps.replaceAll("(?:\\s*;\\s*)+", "; ");                             
                            HashMap avp  = parseValuePairs(avps, map);
                            annotation.setAvp(avp);  
                        }               
                        }             
                    }
                    catch (Exception e) {
                    e.printStackTrace();           
                    }
          }         

            if (length == 15) 
            annotation.setComments(lffData[14]);   
          return annotation;
      }
           
    HashMap parseValuePairs(String comments, HashMap map ){
           HashMap avp  = new HashMap ();
           String s = null;
             
           match2.reset(comments);         
           // remove tailing tabs  after a=b; value pairs 
             if(match2.matches())
              s = match2.replaceAll("$1");       
           else
              s = comments;
                                       
               
           ArrayList list = splitValuePairs(s);
            
               String key = null;
               String value = null; 
             if(list != null  && !list.isEmpty()){
                 
                  for(int i = 0; i < list.size(); i++) {
                       String comment = (String)list.get(i);
                   
                       if(comment == null) 
                            continue; 
                       comment = comment.trim();
                       if ( comment.length() < 1) 
                       continue;
                    
                       int index1 = comment.indexOf('=');
                       key = comment.substring(0, index1);
                  
                       value = comment.substring(index1 + 1);
                       if (key!= null) {
                       avp.put(key, value);    
                         map.put(key, "y");
                       }
                  }
             }
              
           
             return avp;
         }
        
       
    
    private ArrayList splitValuePairs(String s)
          {    ArrayList list = null; 
          
             if(s == null) return null;                
               list = new ArrayList();
              String text = null;            
              int start = 0;
              int index = 0; 
              while((index = s.indexOf(';', start)) >0  && start < s.length()) {
                  text = s.substring(start,index);
               
                  list.add(text);
                  start = index +1;
              }
           
           
              return list;
          }
   
    
}
