<%@ page import="org.genboree.dbaccess.GenboreeGroup,
java.util.*,
java.io.*,         
org.genboree.message.GenboreeMessage,
org.genboree.editor.AnnotationDetail,
org.genboree.tabular.*,
org.apache.commons.validator.routines.LongValidator,
org.apache.commons.validator.routines.DoubleValidator,
org.apache.commons.validator.routines.DateValidator"    
session= "false"            
%>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>  
<%@ include file="include/pageInit.incl" %>
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
    
    boolean isLargeSamples = false; 
    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );  
    GenboreeMessage.clearMessage(mys);  
    
    if (request.getParameter("btnBack") != null) {   
        response.sendRedirect("fileDisplay.jsp?fromBrowser=View");
        return; 
    }        
   
  
    // initialization     
    int totalNumAnnotations = 0;
    dispNum = new int []{20, 25,  50, 100, 200};
    String[] fdataSortNames = null; 
  
    boolean hasData = true;
  
    displayNum = 50;
    ArrayList sortList = null; 
    String [][] fidAttributes = null; 
     boolean needSort = false;  
    String [] lffSortNames = null;
  
    boolean sortByAVP = false;
    int[] displayIndexes  = null; 
    ArrayList  lffNameArrayList = new ArrayList ();
    for (i=0 ; i<LffConstants.LFF_COLUMNS.length; i++) 
    lffNameArrayList.add(LffConstants.LFF_COLUMNS[i]); 
    LffConstants.setHash();      
  
    ArrayList lffAttributes  = null;
    ArrayList avpAttributes  = new ArrayList();
    ArrayList allLffColumns = new ArrayList (); 
    for ( i=0; i<org.genboree.tabular.LffConstants.LFF_COLUMNS.length; i++) 
    allLffColumns.add(org.genboree.tabular.LffConstants.LFF_COLUMNS[i]);   
   
    AnnotationDetail[] annotations = null;
    AnnotationDetail [] totalAnnotations = null; 
    int  currentIndex = 0;                       
    // GET NUMBER OF ANNOTATIONS PER PAGE 
        int topDisplayNum = 50; 
    if (request.getParameter("app") != null) {   
        String temp = request.getParameter("app");
        topDisplayNum = Integer.parseInt(temp);                      
    }
      
    int botDisplayNum = 50;   
    if (request.getParameter("appBottom") != null) {
        String temp = request.getParameter("appBottom");
        botDisplayNum = Integer.parseInt(temp);                      
    }
            
    String sessionDisplayNum = null; 
    if (mys.getAttribute("displayNum") != null) {
        sessionDisplayNum =   (String)mys.getAttribute("displayNum");
        int sessionNum  = Integer.parseInt(sessionDisplayNum);
         displayNum = sessionNum; 
      
         if (sessionNum != topDisplayNum ) {
            displayNum = topDisplayNum;
              paging = true; 
        } 
        
         if (sessionNum != botDisplayNum ) {
            displayNum = botDisplayNum;
              paging = true; 
        }
        
        mys.setAttribute("displayNum", ""+displayNum);
    }  
       
    String [] avpNames =  null;               
    ArrayList avpDisplayNameList = new ArrayList (); 
    String totalCount =  (String)mys.getAttribute("totalCount") ;       
   
    ArrayList  lffSortNameList  = new ArrayList (); 
    HashMap order2Att = new HashMap ();  
    
    boolean noAttributeSelected = false;     
    String viewDisplay="block";  
    
    ArrayList avpSortNameList  = new ArrayList (); 
    // determine the mode    
    
    String pressed = request.getParameter("viewData");      
    if (pressed != null && pressed.compareTo("1") == 0) {   
        currentPageIndex = 0;
        currentPage = "0";
        initPage = true; 
        mys.setAttribute("lastPageIndex", "0");
        mys.removeAttribute("lastStartPageNum");
        mys.removeAttribute("lastEndPageNum");
        mys.setAttribute("lastStartPageNum", "" +  0);             
     
        initPage = true; 
        mys.setAttribute("lastMode", ""+LffConstants.VIEW);
    }
    
    if (mys.getAttribute("lastStartPageNum") != null) 
    sstartPageNum = (String )mys.getAttribute("lastStartPageNum");
      
    totalNumAnnotations = 0;
  
    int numSortNames = 0;        
    if ( request.getParameter("navigator") != null   )
    initPage = false;
    String [] avpDisplayNames = null;     
    if ( initPage){             
    if (orderedDisplayNames == null) {
        GenboreeMessage.setErrMsg(mys, "Please select some attributes for sample display. ");                
        viewDisplay="none";  
        //selectDisplay="block"; 
        noAttributeSelected = true; 
    } 
    else {          
         for (i=0; i<orderedSortNames.length; i++) {
            if (!lffNameArrayList.contains(orderedSortNames[i]))  
                avpDisplayNameList.add(orderedSortNames[i]);              
         }  
        avpDisplayNames = (String [])avpDisplayNameList.toArray(new String [avpDisplayNameList.size()]); 
    }
    
    
if (orderedSortNames != null && orderedSortNames.length >0) {  
    sortList = new ArrayList (); 
    numSortNames = orderedSortNames.length;
    for (i=0; i<orderedSortNames.length; i++) {         
        sortList.add(orderedSortNames[i]); 
        if (!lffNameArrayList.contains(orderedSortNames[i])) { 
            sortByAVP = true;                   
            avpSortNameList.add(orderedSortNames[i]);          
        }
    }  
    
    for (int n=0; n<orderedSortNames.length; n++) {
        if (lffNameArrayList.contains(orderedSortNames[n])) 
        lffSortNameList.add(orderedSortNames[n]);         
    } 
    
    if (!lffSortNameList.isEmpty()) 
        lffSortNames =(String []) lffSortNameList.toArray(new String [lffSortNameList.size()] ); 
    }     
     
    mys.setAttribute("totalNumAnnotations", ""+ totalNumAnnotations );
   
    if (orderedSortNames != null) {
        fdataSortNames = LffUtility.covertNames(orderedSortNames);
        if(fdataSortNames == null || fdataSortNames.length ==0)
        fdataSortNames = null;         
        needSort = true; 
    }      
           
        //  retrieve information from session
        ParseResult result = (ParseResult)mys.getAttribute("parseResult");   
        if (result == null) 
           GenboreeMessage.setErrMsg(mys, "There is no annotations to display. -- 11");
            
        HashMap fid2Annos = result.getFid2annos();
        if (fid2Annos == null || fid2Annos.isEmpty())
          
           GenboreeMessage.setErrMsg(mys, "There is no annotations to display. -- 22");
         else {    
              totalAnnotations  =(AnnotationDetail []) fid2Annos.values().toArray(new AnnotationDetail [fid2Annos.size()]);  
                if (totalAnnotations != null) {
                      mys.setAttribute("totalAnnotations", totalAnnotations) ;
                      totalNumAnnotations = totalAnnotations.length;
                      totalCount = "" +  totalNumAnnotations;
                }   
        }
        
    paging = true;  
    if  (orderedDisplayNames != null && orderedDisplayNames.length >0){          
        for (int k=0; k<orderedDisplayNames.length; k++) {
            if (!lffNameArrayList.contains(orderedDisplayNames[k]))              
                avpDisplayNameList.add(orderedDisplayNames[k]);                         
        } 
    }   
    
    if (!avpDisplayNameList.isEmpty()) {
        avpDisplayNames =(String []) avpDisplayNameList.toArray(new String [avpDisplayNameList.size()]);   
        mys.setAttribute("avpDisplayNames", avpDisplayNames);  
    }
}    
else {  //  recuring page 
    orderedDisplayNames = (String [])  mys.getAttribute("orderedDisplayNames");         
    if ( mys.getAttribute("avpDisplayNames") != null)
        avpDisplayNames =   (String [])  mys.getAttribute("avpDisplayNames");  
                
    String temp = null;  
    temp = (String)mys.getAttribute("displayNum");
    if (temp!=null) {
        int displayN = Integer.parseInt(temp);
        if (displayN != displayNum)
        paging = true;
    }
        
    lffAttributes = (ArrayList)mys.getAttribute("lffAttributes");
         
    if (mys.getAttribute("totalAnnotations") != null) 
        totalAnnotations = (AnnotationDetail[])mys.getAttribute("totalAnnotations");            
} 
    if ( request.getParameter("currentPage")!= null)           
    currentPage = request.getParameter("currentPage");
    else 
    currentPage = "0"; 
    
 if(totalAnnotations == null || totalAnnotations.length <1) 
   hasData = false; 
    
    if (hasData) {       %>   
    <%@ include file="include/multipaging.incl" %>
    <%@ include file="include/annotationView.incl" %>
    <%@ include file="include/pageInfo.incl" %>
    <%  annotations = (AnnotationDetail[])page2Annotations.get(currentPage);  }  %>
<HTML>
<head>  
<title><%=" My annotations "%></title>
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css" >
<link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">
<link rel="stylesheet" href="/styles/samples.css<%=jsVersion%>" type="text/css"> 
<SCRIPT type="text/javascript" src="/javaScripts/prototype.js<%=jsVersion%>"></SCRIPT>
<SCRIPT type="text/javascript" src="/javaScripts/util.js<%=jsVersion%>"></SCRIPT>
<SCRIPT type="text/javascript" src="/javaScripts/commonFunctions.js<%=jsVersion%>"></SCRIPT>               
<SCRIPT type="text/javascript" src="/javaScripts/sample.js<%=jsVersion%>"></SCRIPT>     
<script type="text/javascript" SRC="/javaScripts/sorttable.js<%=jsVersion%>"></script>
<script type="text/javascript" SRC="/javaScripts/editorCommon.js<%=jsVersion%>"></script>   
</head>
<BODY><%@ include file="include/header.incl" %><%@ include file="include/navbar.incl" %><table   border="0" cellspacing="4" cellpadding="2" >          

</table><%@ include file="include/message.incl" %> 
<form name="viewForm" id="viewForm" action="viewFileAnnotations.jsp" method="post" >

<%if ( orderedDisplayNames != null) {%> 
<table width="100%" >
<%@ include file="include/viewPageIndex.incl" %></table>
<input type="hidden" name="currentPage" id="currentPage" value="<%=currentPage%>">
<input type="hidden" name="navigator" id="navigator" value="">    
<div id="viewDiv" class="scrollable" style="display:<%=viewDisplay%>">                    
<table width="100%"  id="sampleView"  class="sortable" border="1" cellpadding="1" cellspacing="1"> 
<TR><CENTER><b>(Total of <%=totalCount%>&nbsp;Annotations)</B></CENTER>
<%     if (orderedDisplayNames != null) { 
String displayName = "";      
for ( i=0; i<orderedDisplayNames.length; i++){       
displayName =  orderedDisplayNames[i];  
if (displayName != null){ 
displayName = displayName.trim();
displayName = displayName.replaceAll(" ", "&nbsp;" );  
}      %>
<td class="form_header"  align="center"><nobr><font color="white"><%=displayName%></font></nobr></td>
<%}}%>
</TR>       
<% HashMap avpMap =  null; 
if (hasData &&  annotations != null){     
    for ( i=0; i< annotations.length; i++) {
        AnnotationDetail annotation  =  annotations[i]; 
        annotation.setlff2value();
        avpMap = annotation.getAvp();
        if (annotation == null){ continue;}       
            HashMap lffMap = (HashMap)  annotation.getLff2value() ;
        %>
<TR>
        <% 
        String value =  ""; 
        String displayName2 = null;  
        for (int j=0; j< orderedDisplayNames.length; j++){
            displayName2 = orderedDisplayNames[j];        
            value = ""; 
            if (lffMap != null && lffMap.get(displayName2) != null) 
            value = (String )lffMap.get(displayName2);              
            else if (avpMap != null && avpMap.get(displayName2)!= null)         
            value = (String )avpMap.get(displayName2);               
            %>
        <TD class="form_body2"><%="&nbsp;" + value%></TD>
        <% }%>
</TR>    
<% }}%>
</table>
</div><BR> 
<div id="viewbk" style="display:<%=viewDisplay%>">
<input type="submit" name="btnBack" value="Back"  class="btn" style="WIDTH:100">&nbsp;&nbsp 
</div>         
<table width="100%"  border="1" cellpadding="2" cellspacing="1"> <BR><BR>
<%@ include file="include/viewPageIndexBottom.incl" %>    
</table>
<%} 
 %>
<input type="submit" name="btnBack" value="Cancel"  class="btn" style="WIDTH:100">&nbsp;&nbsp;   
</form>
<%@ include file="include/footer.incl" %>
</BODY>
</HTML>