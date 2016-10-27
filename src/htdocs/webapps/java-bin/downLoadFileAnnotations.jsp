<%@ page import="java.io.*, 
org.genboree.message.GenboreeMessage,
org.genboree.tabular.LffConstants,
org.genboree.editor.AnnotationDetail,
java.util.*,
org.genboree.tabular.LffUtility,
org.genboree.tabular.AnnotationSorter,
org.genboree.util.Util,
org.genboree.tabular.ParseResult"
session = "false"    
%>

<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/common.incl" %>  
<%@ include file="include/sessionGrp.incl" %>
<%       
    HashMap displayOrder = null;
    String orderedSortNames []= null;       
    String []  orderedDisplayNames =  null;   
    String jsparams =  request.getParameter("jsparams");        
    if (jsparams != null) {    
    orderedDisplayNames = jsparams.split(",");  
    mys.setAttribute("orderedDisplayNames", orderedDisplayNames);  
    displayOrder= new HashMap ();
    
    if (orderedDisplayNames != null) 
    for (int j=0; j<orderedDisplayNames.length ; j++)              
    displayOrder.put(orderedDisplayNames[j], "" + j);   
    }
    
    int i=0; 
    String jssortparams =  request.getParameter("jssortparams");
    if (jssortparams != null)  
    orderedSortNames = jssortparams.split(",");   
     
    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );  
    GenboreeMessage.clearMessage(mys);  

    if (request.getParameter("btnBack") != null) {   
        response.sendRedirect("fileDisplay.jsp?fromBrowser=View");
        return; 
    }     
    
    // boolean debugging = true; 
    boolean debugging = false; 
    int flushCounter  = 0; 
    int flushLimit = 10000;  
    final  int sleepTime = 2000 ;
    
    // initialization     
    int totalNumAnnotations = 0;
    boolean hasData = true;    
    boolean needSort = false;  
 
    LffConstants.setHash();            
    AnnotationDetail[] annotations = null;
    AnnotationDetail [] totalAnnotations = null; 
   //  retrieve information from session
    ParseResult result = (ParseResult)mys.getAttribute("parseResult");   
    if (result == null) {
        GenboreeMessage.setErrMsg(mys, "There is no annotations to display. -- 11");
        return; 
    }
    
    HashMap fid2Annos = result.getFid2annos();    
    if (fid2Annos == null || fid2Annos.isEmpty()) {   
        GenboreeMessage.setErrMsg(mys, "There is no annotations to display. -- 22");
        return ; 
    }
    else {    
        totalAnnotations  =(AnnotationDetail []) fid2Annos.values().toArray(new AnnotationDetail [fid2Annos.size()]);  
        if (totalAnnotations != null) {
             mys.setAttribute("totalAnnotations", totalAnnotations) ;
            totalNumAnnotations = totalAnnotations.length;             
        }      
    }  
        
    if (orderedSortNames != null && orderedSortNames.length >0) {  
        mys.setAttribute("totalNumAnnotations", ""+ totalNumAnnotations );
        needSort = true; 
    }        

      
    if(totalAnnotations == null || totalAnnotations.length <1) 
        hasData = false; 
    
    LffConstants.setHash();      
    LffConstants.poulateLffMap();    
     
    String [] fids  = null; 
     
    if (needSort)   
        totalAnnotations = AnnotationSorter.sortAllAnnotations(orderedSortNames, totalAnnotations);     
 
      
    
    if (!hasData) 
         GenboreeMessage.setErrMsg(mys, "There is no annotation data to download." );      
    else {          
        int count = 0; 
        PrintWriter writer = null;    
       
            String date = new Date().toString();
            response.addDateHeader( "Expires", 0L );
            response.addHeader( "Cache-Control", "no-cache, no-store" );
            response.setContentType( "text/fasta" );
            response.setHeader( "Content-Disposition", "inline; filename=\"annotation_file_" + date + ".txt\"" );
            response.setHeader("Accept-Ranges", "bytes");
            response.addHeader("status", "200");
            writer = new PrintWriter(response.getOutputStream());   
     
        if (orderedDisplayNames != null) { 
            String name = "";      
            for ( i=0; i<orderedDisplayNames.length-1; i++){       
                name =  orderedDisplayNames[i];  
                name = (String) LffConstants.display2downloadNames.get(name); 
                if (name == null) 
                    name = orderedDisplayNames[i];
              
                     writer.print(name+ "\t" );  
              
            }
            
            name =  orderedDisplayNames[orderedDisplayNames.length-1];  
            name = (String ) LffConstants.display2downloadNames.get(name);
            if (name == null) 
                name = orderedDisplayNames[i];
            
         
                writer.println(name);              
                writer.flush();
            
           
        } 
        
        AnnotationDetail annotation = null; 
        HashMap avpMap = null;  
        HashMap lffMap = null;          
        // writing to file 
        String displayName2 = null;  
        String value =  "";    
        fids = new String [totalNumAnnotations]; 
        for (i=0; i<totalAnnotations.length; i++)
            fids[i] = "" + totalAnnotations[i].getFid();                                 
                
        int blocksize = LffConstants.BLOCK_SIZE;    
        int numPages  = fids.length/blocksize;
        int lastPagefids = fids.length%blocksize;
        if ( lastPagefids>0)          
            numPages ++;  
       
        HashMap page2fids = new HashMap ();             
        int arrLength = blocksize;   
        for ( int pageIndex =0; pageIndex<numPages; pageIndex++) {     
            if (pageIndex== numPages-1 ) 
                arrLength  = lastPagefids;  
            
                String [] pagefids = new String [arrLength ] ; 
                for (int j=0; j< arrLength; j++) {
                    int index = pageIndex*blocksize  + j ; 
                     pagefids[j]  = fids[index];
                  }
            page2fids.put("" + pageIndex, pagefids);    
        }    
                 
    for ( int pageIndex =0; pageIndex<numPages; pageIndex++) {  
   //    for ( int pageIndex =0; pageIndex<1; pageIndex++) {          
        String []pagefids = (String [])page2fids.get("" + pageIndex);
        if (pagefids != null  && pagefids.length >0) {
        annotations = new AnnotationDetail [pagefids.length]; 
        for (i=0; i< annotations.length; i++) 
        annotations[i] = (AnnotationDetail) fid2Annos.get (pagefids[i]);         
        }
        
        // print to file   
     //   for (int n=0; n<2; n++) {    
        
         for (int n=0; n<annotations.length; n++) {        
        flushCounter++;        
        annotation = annotations[n];
        annotation.setlff2value();
        avpMap = annotation.getAvp();
        if (annotation.getLff2value() != null)
        lffMap = (HashMap) annotation.getLff2value(); 
        
        for (int j=0; j< orderedDisplayNames.length; j++) {
        displayName2 = orderedDisplayNames[j];   
        value =  ""; 
        if (lffMap != null && lffMap.get(displayName2) != null)
        value = (String )lffMap.get(displayName2);   
        else if (avpMap != null && avpMap.get(displayName2)!= null) {        
        value = (String)avpMap.get(displayName2);                      
        }
        
        if (value != null) 
        value = value.trim() ; 
        else {  // value == null
        if( displayName2.equals(LffConstants.LFF_COLUMNS[10]) || displayName2.equals(LffConstants.LFF_COLUMNS[11])  || displayName2.equals(LffConstants.LFF_COLUMNS[12]) || displayName2.equals(LffConstants.LFF_COLUMNS[13])  )
        value = ".";
        }
        
       
        writer.print(value +"\t" );
       
      
        }   
        writer.println("");
        writer.flush();  
       // }
     
        } 
        
        if(!debugging && flushCounter > flushLimit){
        writer.flush();
        try { Util.sleep(sleepTime) ; }
        catch(Exception ex) { }
        flushCounter = 0;
        }    
        }
             
      
            writer.flush();
            writer.close();
          
  }
       
%>
<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<HTML>       
<head>
<title><%=" My annotations "%></title>
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css" >
<link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">   
<script type="text/javascript" SRC="/javaScripts/editorCommon.js<%=jsVersion%>"></script>   
</head>
<BODY>  
<%@ include file="include/header.incl" %>
<%@ include file="include/navbar.incl" %>      
<%@ include file="include/message.incl" %> 
<form name="uploadForm" id="uploadForm" action="fileDisplay.jsp" method="post"> 
<table width="100%" border="0" cellpadding="2" cellspacing="2" width="500px">       
<tr align="center">  
<td colspan="2"> <BR><BR>
<input  type="submit" name="backBtn" id="backBtn" value="Back" class="btn" style="WIDTH:100">
</td></tr></table>
</form>
<%@ include file="include/footer.incl" %>
</BODY>
</HTML>