<%@ page import="org.genboree.dbaccess.GenboreeGroup,
java.util.*,
java.io.*,              
org.genboree.upload.*,
org.genboree.upload.HttpPostInputStream,
org.genboree.upload.AnnotationUploader,
org.genboree.upload.DatabaseCreator,
org.genboree.upload.FastaEntrypointUploader,
org.genboree.message.GenboreeMessage,
org.genboree.samples.*,
java.util.regex.Pattern,
java.util.regex.Matcher,
java.text.SimpleDateFormat,
org.json.JSONObject,
org.genboree.tabular.LffUtility,
java.text.DateFormat,
java.text.ParseException"
%>          
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/group.incl" %>  
<%@ include file="include/sessionGrp.incl" %>               
<%
    HashMap displayOrder = new HashMap ();
    String orderedSortNames []= null;       
    String []  orderedDisplayNames =  null;  
    String jsparams =  request.getParameter("jsparams");

    if (jsparams != null && jsparams.length() >0) {        
        JSONObject json = new JSONObject( jsparams ) ; 
        if (json != null) {
            orderedDisplayNames = LffUtility.parseJson(json, "rearrange_list_1")  ;
                
           if (orderedDisplayNames != null) 
            for (int j=0; j<orderedDisplayNames.length ; j++) {  
            orderedDisplayNames[j] = Util.urlDecode(orderedDisplayNames[j]);
            displayOrder.put(orderedDisplayNames[j], "" + j);  
            }
        } 
        
        orderedSortNames = LffUtility.parseJson(json, "rearrange_list2"); 
        if (orderedSortNames != null) {
        int index = -1; 
        for (int j=0; j<orderedSortNames.length; j++) {
        orderedSortNames [j] = Util.urlDecode(orderedSortNames[j]);
        index = orderedSortNames[j].indexOf("_sort"); 
        if (index >0) 
        orderedSortNames[j] = orderedSortNames[j].substring(0, index);          
        // out.println("<br> sort names " + j + "  " +  orderedSortNames[j]);
        }
        }  
    //   out.println("<br> num sort names " + orderedSortNames.length);
    }

    if(userInfo[0].equals("admin")){
        myGrpAccess = "ADMINISTRATOR";
        i_am_owner = true; 
        isAdmin = true;
    }
        
        if (orderedDisplayNames == null || orderedDisplayNames.length ==0) 
        GenboreeMessage.setErrMsg(mys, " There is no sample for display.");
        int totalNumSamples = 0; 
        response.addDateHeader( "Expires", 0L );
        response.addHeader( "Cache-Control", "no-cache, no-store" );  
        GenboreeMessage.clearMessage(mys);  
        
        int i=0;    
        int mode = -1;
        Refseq rseq = null; 
        
        Sample [] samples = null; 
        String [] attributeNames  = null; 
        Sample[] totalSamples = null;
        
        if (request.getParameter("btnBack") != null) 
        GenboreeUtils.sendRedirect(request, response, "java-bin/mySamples.jsp"); 
    
     if (rseqs== null || rseqs.length==0 ) 
        GenboreeMessage.setErrMsg(mys, "Sorry, there is no database in this group. <br> -- Please create a database and try again."); 
    %>
    
    <%@ include file="include/sampleInit.incl" %>        
    <%  if (rseqs != null && rseqs.length >0) {  
    
    rseq = rseqs[0];
    if (rseq_id != null && !rseq_id.equals("")) {
        for ( i=0; i<rseqs.length; i++) {
        if (rseqs[i].getRefSeqId().equals(rseq_id))
        rseq = rseqs[i];           
        } 
    }
    else {
        rseq = null; 
    } 

    if ( grpChangeState!= null && grpChangeState.compareTo("1") ==0 ) {
    rseq = null;
    }

    if ( sessionCleared) {
        String cmode = request.getParameter("currentMode");
        if (cmode != null) 
        mode = Integer.parseInt(cmode); 
    }

    String dbName = null;
    Connection con = null;      
    
    if (rseq != null) {
        dbName =  rseq.getDatabaseName();
        
        //   out.println(dbName);
        con = db.getConnection(dbName); 
    }
        
    if( rseq != null) {  
    // get all attribute names
        attributeNames = SampleRetriever.retrievesAllAttributeNames(con); 
        totalNumSamples =    SampleRetriever.countAllSamples(con); 
         if (attributeNames != null)     
        Arrays.sort(attributeNames);
    }

    String selectAtt = ""; 
  //  if (rseq != null  && isAdmin) {         
   if (rseq != null) {      
    if (attributeNames==null || attributeNames.length==0)         
    GenboreeMessage.setErrMsg(mys, "There is no sample data to download." );

    
    if (orderedDisplayNames  == null) {          
        GenboreeMessage.setErrMsg(mys, "Please select some attributes for sample display. ");                
    }     
    else {           
        int order =0; 
        HashMap displayOrder2Name = new HashMap ();  
        String jsQuotedName = null; 
        for (i=0; i<orderedDisplayNames .length; i++) {
            order = i + 1;   
            jsQuotedName  = Util.simpleJsQuote(orderedDisplayNames[i]);                
            selectAtt +=  "'" +   jsQuotedName  + "', "; 
            //  displayOrder2Name.put(""+order,  jsQuotedName);  
            displayOrder2Name.put(""+order,  orderedDisplayNames[i]);  
        }

        selectAtt = selectAtt.substring(0, selectAtt.length() -2);
        totalSamples =  SampleRetriever.retrieveAllSamples (con, false, selectAtt,  displayOrder2Name); 
    }
        
    if (totalSamples == null ||totalSamples.length ==0)  
        GenboreeMessage.setErrMsg(mys, "There is no sample data to download." );
    else {     //                   
        if (orderedSortNames!= null && orderedSortNames.length >0) {    
        int [] attributeIndexes = new int [orderedSortNames.length];         
        int attributeIndex= -1;
        //find indexes of the selected attributes    
        int count =0; 
        for (int j=0; j< orderedSortNames.length; j++) {                
        String attIndex  = (String)displayOrder.get(orderedSortNames[j]);                
        if ( attIndex != null) 
        attributeIndex = Integer.parseInt( attIndex );             
        attributeIndexes[count] = attributeIndex;  
        count++; 
        }
    
        try {      		 
        totalSamples =SampleSorter.sortAllSamples(out, orderedSortNames, attributeIndexes,  totalSamples, displayOrder,  true ); 
        }
        catch (SampleException e) {                
       // out.println("Error happened in sample sorting: " + e.getMessage());
        e.printStackTrace();
        db.reportError(e, "There is an error in sample sorting ");
        }
    }
         
    String dd = new Date().toString();
    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );
    response.setContentType( "text/fasta" );
    response.setHeader( "Content-Disposition", "inline; filename=\"sample_file_" + dd + ".txt\"" );
    response.setHeader("Accept-Ranges", "bytes");
    response.addHeader("status", "200");
    PrintWriter writer = new PrintWriter(response.getOutputStream());        
    writer.print( "Sample ID\t" );  
    
    String displayName = ""; 
    for (i=0; i<orderedDisplayNames.length -1; i++) { 
    displayName =  orderedDisplayNames[i];
    if (displayName != null){ 
    displayName = displayName.trim();
    // displayName = displayName.replaceAll(" ","&nbsp;" );
    } 
    else displayName  = "";             
    writer.print(displayName+ "\t" );   
    }
    
    displayName =  orderedDisplayNames[orderedDisplayNames.length -1]; 
    if (displayName != null){ 
    displayName = displayName.trim();
    } 
    else displayName  = ""; 
    writer.println(displayName);              
    writer.flush();

    for ( i=0; i<totalSamples.length; i++) {            
        Attribute [] attributes  = totalSamples[i].getAttributes();
        writer.print(totalSamples[i].getSampleName() + "\t" ); 
        if (attributes!=null) {                 
        for (int j=0; j<attributes.length-1; j++) {
        if (attributes[j]!=null && attributes[j].getAttributeValue() != null) {
        String atname =  attributes[j].getAttributeValue() ;
        atname = atname.trim() ;                          
        writer.print( atname +"\t" );
        }
        else {                         
        writer.print("\t" );
        }
        }
        
        if (attributes[attributes.length-1]!=null && attributes[attributes.length-1].getAttributeValue() != null) {
        String atname =  attributes[attributes.length-1].getAttributeValue() ;
        atname = atname.trim() ;             
        writer.println( atname );
        }  
        else 
        writer.println("");                
        writer.flush();                     
        }
    }    
    writer.flush();
    writer.close();  
    return;   
    } 
    } 
    }    

// if (!isAdmin)
  //  GenboreeMessage.setErrMsg(mys, "Sorry, you have no rights to download from this database.");    
%>
<!--!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN""http://www.w3.org/TR/REC-html40/loose.dtd"-->
<HTML>
<head>
<title><%=" My Samples "%></title>
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css" >
<link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">  
<SCRIPT type="text/javascript" src="/javaScripts/sample.js<%=jsVersion%>"></SCRIPT>     
<script type="text/javascript" SRC="/javaScripts/prototype.js<%=jsVersion%>"></script>
<script type="text/javascript" SRC="/javaScripts/util.js<%=jsVersion%>"></script>
<SCRIPT type="text/javascript" src="/javaScripts/commonFunctions.js<%=jsVersion%>"></SCRIPT>               
<script type="text/javascript" SRC="/javaScripts/editorCommon.js<%=jsVersion%>"></script> 
</head>
<BODY>       
<%@ include file="include/header.incl" %>
<%@ include file="include/navbar.incl" %> 
<%@ include file="include/message.incl" %> 
<input type="hidden" name="uploadFileName"  id="uploadFileName" value="1">
<input type="hidden" name="currentMode"  id="currentMode" value="<%=mode%>">             
<table border="0" cellpadding="4" cellspacing="2" width="100%">                  
<%  if( rwGrps.length == 1 ) { %>         
<TR> <td width="20%"></td><td></td></TR>
<TR>         
<td class="form_header"><strong>Group</strong></td>
<input type="hidden" name="group_id" id="group_id" value="<%=groupId%>">
<td class="form_header">
<%=Util.htmlQuote(grp.getGroupName())%>
&nbsp;&nbsp;<font color="#CCCCFF">Role:</font>&nbsp;&nbsp;<%=myGrpAccess%></td></TR>
<%}
else { %>
<TR><%@ include file="include/groupbar.incl"%></TR><% }%>
<TR><%@ include  file="include/databaseBar.incl" %></TR>
</table>
<form name="viewForm" id="viewForm" action="mySamples.jsp" method="post" >                 
<input type="submit" name="btnBack" value="Back"  class="btn" style="WIDTH:100">&nbsp;&nbsp; 
</form> 
<%@ include file="include/footer.incl" %>
</BODY>
</HTML>
