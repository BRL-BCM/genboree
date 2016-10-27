<%@ page import="org.genboree.dbaccess.GenboreeGroup,
java.util.*,
java.io.*,         
org.genboree.message.GenboreeMessage,
                 org.genboree.editor.AnnotationDetail,
                 org.genboree.manager.tracks.Utility,
                 org.genboree.tabular.*,
                 org.genboree.tabular.AttributeRetriever,
                 org.genboree.tabular.LffConstants,
                 org.genboree.tabular.LffUtility,
                 org.genboree.util.Util,
                 java.util.regex.Matcher,
                 java.util.regex.Pattern" %>  
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>

<%          
    response.addHeader( "Cache-Control", "no-cache, no-store" );  
    GenboreeMessage.clearMessage(mys);  
    int totalNumAnnotations = 0; 
    String browserTrackName = null; 
    String trackNames []  = null; 
    ParseResult result = null;
    LffParser parser = null;  
    
    
    String totalCount = "0"; 
    // size of the passed file; if over limit, display error message and return ; 
    long fileSize = 0; 
    // file size limit in byte; adjust table 
    long fileSizeLimit = 100000000; 
    String []  orderedDisplayNames = null; 
     boolean displayTracks = false; 
    boolean hasError = false;  
  
    boolean hasSession = false; 
      
    int mode = -1;
    int i=0;   
     HashMap selectedTrackHash = new HashMap ();          
     
    String fileName = null; 
    if (request.getParameter("fileName") != null)  {
        
        mys.removeAttribute("parseResult");
        fileName = request.getParameter("fileName");
             
        File file = new File (fileName); 
        
        if (file.exists()) {
            fileSize = file.length();
             
            if (fileSize > fileSizeLimit) {
                GenboreeMessage.setErrMsg(mys, "File " + fileName+ " is too large for online view right now. <br>Please upload the file using <a href='myrefseq.jsp?mode=Upload'> my database </a> tool and view it after it is uploaded.");
              ///  return; 
            }
            
            try {                
                result = new ParseResult();
                parser = new LffParser();  
                result = parser.parse4Annotation(fileName, out, 5000000);
                
                
                  if (result != null ) 
                    trackNames = result.getTrackNames();
            
                if (trackNames != null) {
                  // out.println(" num track names " + trackNames.length );
                    Arrays.sort( trackNames);
                }
                else 
                    GenboreeMessage.setErrMsg(mys, "There is no annotation to display.");
                
                mys.setAttribute("trackNames", trackNames);
                
                mys.setAttribute("parseResult", result);                
                System.err.println("File name " + result.getFileName());
                
                System.err.println("File parsing start time " + result.getStartTime().getTime());
                System.err.println("File parsing   end time " + result.getEndTime().getTime());
                System.err.flush();                       
                     
                displayTracks = true;           
                mode = LffConstants.VIEW;
             }
           catch (Exception e) {
           // e.printStackTrace();                   
          } 
      }
      else {     
            //   catch unfound file names
                  GenboreeMessage.setErrMsg(mys, "File \"" + fileName+ "\" does not exist. </a> ");
          }
    }
    else {
        if (mys.getAttribute("parseResult") != null) 
        result = (ParseResult)mys.getAttribute("parseResult");
        
        if (result != null) 
            hasSession = true; 
        else 
            GenboreeMessage.setErrMsg(mys, "Sorry.  A valid file name is needed for further processing.");
     
       if (hasSession) {        
        if (mys.getAttribute("trackNames") != null) 
        trackNames = (String[])mys.getAttribute("trackNames");                  
        }
                                             
    } 
 
    
     String [] selectedTrackNames = null;      
   // if (request.getParameter("trkCommand") != null){       
        selectedTrackNames = request.getParameterValues("dbTrackNames");
        if (selectedTrackNames != null) {           
            for (i=0; i<selectedTrackNames.length; i++)
                selectedTrackHash.put(selectedTrackNames[i], "y"); 
        }
       else {               
            displayTracks = true; 
             if (hasSession && (request.getParameter("fileName") == null) && (request.getParameter("btnCancel") == null)  &&  (request.getParameter("trackName")==null) && (request.getParameter("fromBrowser") == null))     
            GenboreeMessage.setErrMsg(mys, "Please select some tracks.");
        }
    
   // }
    
    if (request.getParameter("btnCancel") != null) {
        displayTracks = true;      
        mys.removeAttribute("lastMode");
          // browserTrackName =  null; 
        if (mys.getAttribute("browserTrackName") != null)  {
           browserTrackName = (String)mys.getAttribute("browserTrackName");
           selectedTrackHash.put(browserTrackName, "y"); 
        }         
    } 
    
    if (request.getParameter("fromBrowser") != null) {
        String srcPage =  request.getParameter("fromBrowser") ;
        if (srcPage.equals("View")) {           
        mode = LffConstants.VIEW;
        }
          browserTrackName = (String)mys.getAttribute("browserTrackName");
          selectedTrackHash.put(browserTrackName, "y");        
    }  
     
   
   
    boolean noAttributeSelected = false;        
    String [] sortDisplaynames = new String [] {LffConstants.LFF_COLUMNS[2], LffConstants.LFF_COLUMNS[3], LffConstants.LFF_COLUMNS[4], LffConstants.LFF_COLUMNS[5], LffConstants.LFF_COLUMNS[6], LffConstants.LFF_COLUMNS[0], LffConstants.LFF_COLUMNS[1]}; 
    String [] attributeNames  = null; 
      
    String bkPressed = request.getParameter( "back2View") ;       
    if (bkPressed!= null && bkPressed.equals("1"))      
        mode = LffConstants.VIEW; 
 
        
    String viewData =  request.getParameter("viewData");
    if ( viewData != null  && viewData.equals("1")) 
          mode = LffConstants.VIEW;      
    
   String downloadData = request.getParameter("downloadData");
    
     if ( downloadData != null  && downloadData.equals("1")) {                         
             mode = LffConstants.DOWNLOAD;   
     }
    
              
     // the following code handles user selected tracks      
    if (selectedTrackNames != null) {               
        mode = 1;        
    }
            
              
    if((mode==LffConstants.VIEW || mode==LffConstants.DOWNLOAD) ) {         
          String [] avpNames = null; 
          if (result != null && result.getAvpAttributes() != null) 
             avpNames =  result.getAvpAttributes();
        
          if (avpNames!= null) {              
                Arrays.sort(avpNames);
                attributeNames = new String [LffConstants.LFF_COLUMNS.length + avpNames.length] ;  
                for ( i=0; i<LffConstants.LFF_COLUMNS.length; i++) 
                    attributeNames [i] = LffConstants.LFF_COLUMNS[i];
              
                for ( i=0; i<avpNames.length; i++) 
                    attributeNames [i+ LffConstants.LFF_COLUMNS.length] = avpNames[i];
          }
          else
                attributeNames  = LffConstants.LFF_COLUMNS; 
        
        mys.setAttribute("attributeNames", attributeNames);  
                
        HashMap fid2Annos = null; 
        if (result != null) 
            fid2Annos = result.getFid2annos();
        
      if (result != null && result.getFid2annos() != null )   
        totalNumAnnotations =   result.getFid2annos().size();              
        totalCount = "" + totalNumAnnotations;     
        if (totalNumAnnotations > 1000) 
        totalCount = Util.putCommas( "" + totalNumAnnotations); 
        mys.setAttribute("totalCount", totalCount);  
        
        if (totalNumAnnotations <=0 && selectedTrackNames != null)   
            GenboreeMessage.setErrMsg(mys, "There is no annotation in the selected tracks " );
        
       
        orderedDisplayNames = attributeNames;  
        if (!hasSession  &&  trackNames==null&& selectedTrackNames != null)           
        GenboreeMessage.setErrMsg(mys, "There is no annotation in the selected database " );    
     }
 
    String actionJsp = "viewAnnotation.jsp";  
      if (mode == LffConstants.DOWNLOAD )  
               actionJsp = "downloadAnnotations.jsp";     
    
    String  scrollableClass = "scrollable260";
    if (attributeNames != null && attributeNames.length <15) 
        scrollableClass = "scrollable200";
      
      %>         
<HTML>       
<head>
<title><%="Tabular View of Annotations"%></title>
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css" >
<link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css"> 
<link rel="stylesheet" href="/styles/samples.css<%=jsVersion%>" type="text/css">
<SCRIPT type="text/javascript" src="/javaScripts/drag_common.js<%=jsVersion%>"></SCRIPT>
<SCRIPT type="text/javascript" src="/javaScripts/fileview.js<%=jsVersion%>"></SCRIPT>
<SCRIPT type="text/javascript" src="/javaScripts/toolPlugins/toolPluginsWrapper.js<%=jsVersion%>"></SCRIPT>
<link rel="stylesheet" href="/styles/sortableLists.css<%=jsVersion%>" type="text/css">
<link rel="stylesheet" href="/genboree/toolPlugins/nameSelector/nameSelector.css<%=jsVersion%>" type="text/css">
<script type="text/javascript" SRC="/javaScripts/prototype.js<%=jsVersion%>">
</script><script src="/javaScripts/scriptaculous.js<%=jsVersion%>" type="text/javascript"></script>
<script type="text/javascript" SRC="/javaScripts/overlib.js<%=jsVersion%>">
</script><script type="text/javascript" SRC="/javaScripts/overlib_hideform.js<%=jsVersion%>"></script>
<script type="text/javascript" SRC="/javaScripts/overlib_draggable.js<%=jsVersion%>"></script>
<script type="text/javascript" SRC="/javaScripts/overlib_cssstyle.js<%=jsVersion%>"></script>
<script type="text/javascript" SRC="/javaScripts/util.js<%=jsVersion%>"></script>
<script type="text/javascript" src="/javaScripts/json.js<%=jsVersion%>"></script>
<SCRIPT type="text/javascript" src="/javaScripts/commonFunctions.js<%=jsVersion%>"></SCRIPT>               
<script type="text/javascript" SRC="/javaScripts/editorCommon.js<%=jsVersion%>"></script> 
<script type="text/javascript" src="/genboree/toolPlugins/nameSelector/nameSelector.js<%=jsVersion%>"></script>     
</head>
<BODY>  
<%@ include file="include/header.incl" %>
<%@ include file="include/navbar.incl" %>         
<%@ include file="include/message.incl" %> 
  
<form name="selectionForm" id="selectionForm" action="fileDisplay.jsp" method="post"> 
        <input type="hidden" name="currentMode"  id="currentMode" value="<%=mode%>"> 
        <table border="0" cellpadding="4" cellspacing="2" width="100%">                              
          
           <TR>
                  <td class="form_header" colspan="4"><b>Available Tracks Retrieved From File </b></td>
          </TR>
          
            <% if (trackNames!= null) {
                String onChange = ""; 
                if (!displayTracks) 
                    onChange = "selectionForm.submit();";                
            %>
                <TR>
                    <td class="form_header" valign="top">Track</td>
                    <TD colspan="3" class="form_body">
                    <select  class="txt"  name="dbTrackNames" id="dbTrackNames"  style="width:540" multiple  size="4"  onchange="<%=onChange%>">
                    <% 
                    String trackName = "";
                    for (i=0; i<trackNames.length; i++) {     
                        trackName = trackNames[i];        
                        String isSel = "";
                        if (selectedTrackHash.get(trackNames[i]) != null) 
                            isSel =  " selected";
                    %>
                    <option value="<%=trackNames[i]%>" <%=isSel%> ><%=trackNames[i]%></option>                
                    <%}%>
                    </select>
                    </td>
                    </tr>
                
                
                <% if ( displayTracks) { %>                   
                <TR >
                    <td colspan="4" >
                     <BR>
                    <input type="button" name="viewTrack"  id="viewTrack" value="View" class="btn" style="WIDTH:100" onClick="checkTrack(1); "  >
                    &nbsp;                                                               
                    <input type="button" name="downloadTrack"  value="Download" class="btn" style="WIDTH:100"  onClick="checkTrack(0); " >&nbsp;                                                               
                    <input type="submit" name="bk2browser"  value="Back to Browser" class="btn" style="WIDTH:100"  >&nbsp; 
                     </td>
                </tr>                 
                    <%}%>
                  <input type="hidden" name="trkCommand"  id="trkCommand" >&nbsp;      
            <%}%>
        </table>
        <input type="hidden" id="trackIds" name="trackIds" >
        <input type="hidden" id="totalcount" value="<%=totalCount%>">
     
</form>


<form name="viewFileForm" id="viewFileForm" action="<%=actionJsp%>" method="post"   >
<input type="hidden" name="jsparams" id="jsparams" value="">
<input type="hidden" name="jssortparams" id="jssortparams" value="">
    <% if ( orderedDisplayNames != null   && mode >-1 && selectedTrackNames != null  && selectedTrackNames.length >0 ) {            
    // the followging code is shared by both view and download  
    String checked = "checked";
    int sortOrder = 1; 
 
    String divclass = "checkBoxDiv1";
    if (noAttributeSelected) {
    checked = ""; 
    divclass = "checkBoxDiv"; }    
      if (totalNumAnnotations > 0  ) {  
        if ( mode >-1 ) { %>          
            <!--div style="width:600px;"-->  
            <table border="0" cellpadding="0" cellspacing="0"  width="100%" >       
            <tr> 
            <td width="30">&nbsp;</td>
            <td colspan="1"  width="620"><CENTER><FONT SIZE="5"><B>Select & Arrange Columns</B></FONT></CENTER>  
            <CENTER><b>(Total of <%=totalCount%>&nbsp;annotations)</B></CENTER>  
            <br><br>
            </td>   
            </TR>    
            <TR>
            <td width="30">&nbsp;</td>
            <TD  width="640" > 
            <table border="0" cellpadding="2" cellspacing="2"   >
            <TR >
            <TD  width="310"   valign="top">
            <table border="0" cellpadding="0" cellspacing="0">
            <tr align="center" colspan=""> 
            <td  valign="top"  width="310"  class="topBorder">                           
            <span class="sa_subTitle">Display Order</span>
            <br><br>
            </td>                       
            </tr>             
            <TR>
            <td  valign="top"   width="310"  height="130" class="midBorder" colspan="1">   
                <UL class="compact4">
                Below is a list of available annotation attribute columns. 
                <br><i>&nbsp; If you wish to use only a subset of columns, please select only those.</i>
                <br><i>&nbsp; If you wish to change the column order, please do so by dragging.</i></UL>
            </td>               
            </TR> 
            <TR align="center"> 
            <td class="midBorder"   width="310" valign="top" colspan="1"> 
            <input  type="button"  value="Display All"  class="btn" onclick="selectAllDisplay(<%=attributeNames.length%>);">&nbsp;&nbsp    
            <input  type="button"  value="Clear All"  class="btn" onClick="clearAllDisplay(<%=attributeNames.length%>);">      
            </td>               
            </tr>                      
            <%
        } %>     
        
            <TR>
            <TD height="260pt"  width="310" class="midBorder" valign="top">            
    <div id="listDiv" style="position:relative; margin-top:10pt;margin-left:20pt; border-style:solid; border-width:2px;height:260px; overflow:auto;">     
    <div id="rearrange_list_1" name="rearrange_list_1" style=" margin-top:10pt;margin-left:20pt; list-style-type:none; " class="sortableList1">
    <%                       
        if (attributeNames != null )    
        for (i=0; i<attributeNames.length; i++) { 
        int order = i + 1;
    %>
         <div id="item_<%=i%>">
            <div class="checkBoxDiv1" id="item_<%=i%>_chkdiv"   name="item_<%=i%>_chkdiv"  onclick="doCheckToggle('item_<%=i%>_chkdiv', '<%=attributeNames[i]%>');">
            </div>
            <span style="padding-bottom:5px;"><%=order%>.</span>
            <span class="handle"  style="cursor:move;">Drag</span>          
            <span ><b>&nbsp;<%=attributeNames[i].trim()%></b></span> 
            
<input type="hidden" id="<%=attributeNames[i]%>" name="<%=attributeNames[i]%>" value="1" ></input>         
<input type="hidden" id="item_<%=i%>_trackName"  name="trackNames"  value="<%=attributeNames[i]%>" > </input>
         </div>
           
    <%}%>    
    </div>
    </div>           
<script type="text/javascript">     
    Position.includeScrollOffsets = true ;     
    Sortable.create("rearrange_list_1", { tag: 'div', dropOnEmpty: true, constraint: 'vertical', scroll: 'listDiv', handle: 'handle' }) ;
    
</script>
     <br> 
            </td>
            </TR>
            <TR align="center" valign="top">  
            <td class="midBorder">
            <input  type="button"  value="Display All"  class="btn" onclick="selectAllDisplay(<%=attributeNames.length%>);">&nbsp;&nbsp    
            <input  type="button"  value="Clear All"  class="btn" onClick="clearAllDisplay(<%=attributeNames.length%>);">      
            </td>      
            </TR>      
            <TR > 
                <td   height="10" class="botBorder"> &nbsp; 
                </td>         
            </tr>                 
            </table>
    </TD>
   
    
    <TD  width="310pt"  valign="top">
    <table border="0" cellpadding="0" cellspacing="0">
    <tr align="center">                     
    <td  valign="top"  width="310"  class="topBorder">                           
    <span class="sa_subTitle">Sort Order</span>
    <br><br>
    </td>
    </tr>
    <TR>               
    <TD valign="top" width="310"  height="130" class="midBorder">             
        <UL class="compact4">        
        Below is a list of available record columns and their sorting orders. 
        <br><i>&nbsp; If you wish to add more sorting, please select them.</i>
        <br><i>&nbsp; If you wish to change the sorting order, please do so by dragging.</i></UL>                
    </TD>
    </TR>   
    <TR align="center">                
    <td  valign="top"  width="310"  class="midBorder"> 
    <input type="button" value="Clear All" class="btn" onclick="clearAllAnnoSort(<%=attributeNames.length%>);" >
    </td>  
    </tr>                  
    <TR>                           
    <TD  valign="top"  width="310"  height="260pt" class="midBorder">
    
    <div id="listDiv2" style="position:relative;  margin-top:10pt;margin-left:20pt;border-style:solid; border-width:2px;height:260px; overflow:auto;">     
    <div id="rearrange_list2" name="rearrange_list2"  style="  margin-top:10pt;margin-left:20pt;list-style-type:none; " class="sortableList1">
    <% if (attributeNames !=null && totalNumAnnotations >0) {
    for (i=0; i<attributeNames.length; i++) {
    sortOrder = i+1;         
    String name = attributeNames[i];
     //   if (name!= null)
     //   name = name.trim();
    checked = "";
         
    String booValue = "false"; 
    if (i<7){
    name = sortDisplaynames[i];           
    divclass = "checkBoxDiv";  
    }
    else 
    divclass = "checkBoxDiv";
    %>
<div id="sortitem_<%=i%>">                 
<div class="checkBoxDiv" id="sortitem_<%=i%>_chkdiv"   name="sortitem_<%=i%>_chkdiv"  onclick="doCheckToggle('sortitem_<%=i%>_chkdiv', '<%=name%>_sort');">
</div>
    <span style="padding-bottom:5px;"><%=sortOrder%>.</span>                  
    <span class="handle"  style="cursor:move;">Drag</span>                  
    <b >&nbsp;<%=name%></b>    
    <input type="hidden" id="sortitem_<%=i%>_trackName" name="trackNames_sort" value="<%=name%>_sort" > </input>                                  
    <input type="hidden" id="<%=name%>_sort"  name="<%=name%>_sort"  value="0"></input>                      
   </div>   
    <% } %>
    </div> 
    </div>
                                
    <script type="text/javascript">     
    Position.includeScrollOffsets = true ;     
    Sortable.create("rearrange_list2", 
    { tag: 'div', dropOnEmpty: true, constraint: 'vertical', scroll: 'listDiv2', handle: 'handle' }) ;
    // alert(Sortable.serialize('rearrange_list_1').toQueryParams()) ;   
    </script>    
    <br>     
    </td>    
    </tr>
    <TR align="center"> 
    <td  valign="top" class="midBorder">
    <input  type="button"  value="Clear All" class="btn" onclick="clearAllAnnoSort(<%=attributeNames.length%>);" >
    </td>
    </TR>      
    <TR >       
    <td height="10" class="botBorder"> &nbsp; 
    </td>  
    </tr>                 
    </table>
    </td>
    </tr>
    </table> 
    </TD>
    </TR>
    <tr align="center">  
    <td colspan="3"> <BR><BR>
    <% if (totalNumAnnotations >0) { %>   
        <input  type="button" name="apply"  id="apply" value="View" class="btn" style="WIDTH:100"  onClick="submitForm('viewData', <%=totalNumAnnotations%>, <%=LffConstants.Display_Limit%>, '<%=totalCount%>', <%=attributeNames.length%>, 1);">
        <input  type="hidden" name="viewData"  id="viewData" value="" >         
        <input  type="button" name="download" id="download" value="Download" class="btn" style="WIDTH:100"   onClick="submitForm('downloadData', <%=totalNumAnnotations%>, <%=LffConstants.Display_Limit%>, '<%=totalCount%>', <%=attributeNames.length%>, 0);">
        <input  type="hidden" name="downloadData"  id="downloadData" value="0">      
    <%}%>
    <input type="button"  name="btnCancel" value="Cancel"  class="btn" style="WIDTH:100" onclick="viewForm2.submit();">&nbsp;&nbsp;      
    </td>    
    </tr>     
    <%} 
    else {%>      
    <tr align="center">  
    <td colspan="2">
    <input type="button"  name="btnCancel" value="Cancel"  class="btn" style="WIDTH:100" onclick="viewForm2.submit();">&nbsp;&nbsp;      
    </td>    
    </tr>    
    <%}%>
    </table>
<% }      
    else {%>        
   <input type="button"  name="btnCancel" value="Cancel"  class="btn" style="WIDTH:100" onclick="viewForm2.submit();">&nbsp;&nbsp;      
     <%}}%>
</form>
<form name="viewForm2" id="viewForm2" action="fileDisplay.jsp" method="post"> 
    <input type="hidden" name="back2View"  id="back2View" value="0">
    <input type="hidden" name="btnCancel"   value="true">     
</form>
    <%@ include file="include/footer.incl" %>
                                 
</BODY>
</HTML>                                                      