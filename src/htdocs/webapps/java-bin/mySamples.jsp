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
  if(userInfo[0].equals("admin")){
        myGrpAccess = "ADMINISTRATOR";
        i_am_owner = true; 
        isAdmin = true;
    }
        String dbName = null;
       Connection con = null;      
        
    int totalNumSamples = 0; 
    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );  
    GenboreeMessage.clearMessage(mys);  
        String numString = "0";
  
    int i=0;    
    int mode = -1;
    Refseq rseq = null; 
    String scrollableClass = null; 
    boolean noAttributeSelected = false;     
   
 
    Sample [] samples = null; 
    String [] attributeNames  = null; 
    
    String pressedDownload = request.getParameter("download");  
    
    
    if (!isAdmin  && pressedDownload != null && pressedDownload.equals("1")) {
       // GenboreeMessage.setErrMsg(mys, "Sorry, you have no rights to download from this database."); 
        mode = 1; 
    }
    
    // determine the mode    
    String currentMode = request.getParameter("mode");      
    if (currentMode != null) {       
        if (currentMode.equals("View/Download")) 
            mode = 1 ;                       
        else if (currentMode.equals("Upload")) 
            mode = 0;                
    }
  
   if (request.getParameter("btnBack") != null) {
        mode = -1; 
        mys.removeAttribute("lastMode");        
    }
     
  if (rseqs== null || rseqs.length==0 && mode >=0) 
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
    
       if (rseq != null) {
            dbName =  rseq.getDatabaseName();
            //   out.println(dbName);
            con = db.getConnection(dbName); 
            if (mode == SampleConstants.UPLOAD  ) {  
                if (isAdmin) 
                GenboreeUtils.sendRedirect(request, response, "java-bin/uploadFrame.jsp");            
                else
                GenboreeMessage.setErrMsg(mys, "Sorry, you have no rights to upload to this database.");
            
            // Please note: input file does not support default value; see @  http://www.blooberry.com/indexdot/html/tagpages/i/inputfile.htm
            // so we can not have default after database or group change
            }                            
            else if( mode >0) {  
                // get all attribute names
                attributeNames = SampleRetriever.retrievesAllAttributeNames(con); 
                totalNumSamples =    SampleRetriever.countAllSamples(con); 
                numString = "" + totalNumSamples; 
                numString = Util.putCommas(numString);
                if (attributeNames != null)     
                Arrays.sort(attributeNames);  
                
                   if (totalNumSamples == 0 ) 
                        GenboreeMessage.setErrMsg(mys, "There is no sample for display in this database.");
                                 
            }
       }
 } 
    
      
   scrollableClass = "scrollable260";
   if (attributeNames != null && attributeNames.length <15) 
        scrollableClass = "scrollable200"; 
      
   
%>
<!--!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN""http://www.w3.org/TR/REC-html40/loose.dtd"-->
<HTML>
<head>
<title><%=" My Samples "%></title>
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css" >
<link rel="stylesheet" href="/genboree/toolPlugins/nameSelector/nameSelector.css<%=jsVersion%>" type="text/css">
<link rel="stylesheet" href="/styles/sortableLists.css<%=jsVersion%>" type="text/css"> 
<link rel="stylesheet" href="/styles/samples.css<%=jsVersion%>" type="text/css">  
<link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">  
<SCRIPT type="text/javascript" src="/javaScripts/sample.js<%=jsVersion%>"></SCRIPT>     
<SCRIPT type="text/javascript" src="/javaScripts/toolPlugins/toolPluginsWrapper.js<%=jsVersion%>"></SCRIPT>
<script type="text/javascript" SRC="/javaScripts/prototype.js<%=jsVersion%>"></script>
<script src="/javaScripts/scriptaculous.js<%=jsVersion%>" type="text/javascript"></script>
<script type="text/javascript" SRC="/javaScripts/overlib.js<%=jsVersion%>"></script>
<script type="text/javascript" SRC="/javaScripts/overlib_hideform.js<%=jsVersion%>"></script>
<script type="text/javascript" SRC="/javaScripts/overlib_draggable.js<%=jsVersion%>"></script>
<script type="text/javascript" SRC="/javaScripts/overlib_cssstyle.js<%=jsVersion%>"></script>
<script type="text/javascript" SRC="/javaScripts/util.js<%=jsVersion%>"></script>
<script type="text/javascript" src="/javaScripts/json.js<%=jsVersion%>"></script>
<SCRIPT type="text/javascript" src="/javaScripts/commonFunctions.js<%=jsVersion%>"></SCRIPT>               
<script type="text/javascript" SRC="/javaScripts/editorCommon.js<%=jsVersion%>"></script> 
<script type="text/javascript" src="/genboree/toolPlugins/nameSelector/nameSelector.js<%=jsVersion%>"></script>
</head>
<BODY>      

<script type="text/javascript" >
var isAdmin = <%=isAdmin%>;
</script>

<%@ include file="include/header.incl" %>
<%@ include file="include/navbar.incl" %> 
    <table   border="0" cellspacing="4" cellpadding="2" >          
        <TR>
          <%  
             String cls = "nav";    
             if( mode >0)
                cls = "nav_selected";
           %>
           <td class="nav">
           <a href="uploadFrame.jsp">Upload </a>   
           </td>
         
           <td class="<%=cls%>" >   
                <a href="mySamples.jsp?mode=View/Download"> View&nbsp;/&nbsp;Download </a>   
           </td> 
        </TR>  
    </table>
</td> 
<td width="10"></td>
 <td class="shadow"></td> </TR>
<TR><td></td><td>
<%@ include file="include/message.incl" %> 
    <form name="uploadForm" id="uploadForm" action="mySamples.jsp" method="post"> 
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
        <% 
            if (mode == -1 ){ %>
            <UL class="compact4">
                <br> -- Use this interface to add, download, or view sample data
                <br> -- Please select an option from the submenu             
            </UL>      
        <% } %>
    </form> 
    </td>
    <td width="10"></td>
    <td class="shadow"></td>
    </TR>

<form name="viewForm" id="viewForm" action="mySamples.jsp" method="post" > 
<input type="hidden" name="jsparams" id="jsparams" value="">
<input type="hidden" name="jssortparams" id="jssortparams" value="">
<%
    
    if (rseq != null  && attributeNames != null) {  
        String checked = "checked";
        int sortOrder = 1; 
        String divclass = "checkBoxDiv1";
        if (noAttributeSelected) {
            checked = ""; 
            divclass = "checkBoxDiv";
        }        
        
        
%>       
        <TR>
        <td></td>
        <td> 
        <DIV id="listDiv"  style="display:block" >
        <table border="0" cellpadding="2" cellspacing="2">
        <tr> 
        <td width="5%"> </td>
        <td valign="top">      
            <CENTER><FONT SIZE="5"><B>Select & Arrange Columns For Display </B></FONT></CENTER>  
            <CENTER><b>(Total of <%=numString%>&nbsp;samples)</B></CENTER>  
            <BR>                 
    <table>       
    <tr>          
        <td valign="top" width="310"> 
        <table cellspacing="0" cellpadding="0"> 
        <tr align="center">
            <td  valign="top"  class="topBorder">                           
                <span class="sa_subTitle">Display Order</span>
                <br>
            </td>
        </tr>
        <tr>            
            <TD valign="top" width="310"  class="midBorder">             
                    <UL class="compact4" style="height:150px">
                    Below is a list of available sample attribute columns.
                    <br>
                    <br><i><u>Which columns to display?</u> 
                    <br>You can select only those sample attributes you wish to display.
                    (Sample ID always displayed)</i>
                    <br>
                    <br><i><u>What column order?</u> 
                    <br>You can drag the columns into the order <br>you want them displayed.</i>
                </UL>
            </td>
        </tr>
                             
        <TR align="center"> 
            <td  class="midBorder"> 
            <input  type="button"  value="Display All"  class="btn" onclick="selectAllDisplay(<%=attributeNames.length%>);">&nbsp;&nbsp    
            <input  type="button"  value="Clear All"  class="btn" onClick="clearAllDisplay(<%=attributeNames.length%>);">      
            </td>  
        </tr>
                        
        <TR>
        <TD  valign="top"  width="310"   class="midBorder">
            <div id="listDiv" class="<%=scrollableClass%>" style=" position:relative; margin-top:10pt;margin-left:10pt; border-style:solid; border-width:2px;height:260px; overflow:auto;">     
        <div id="rearrange_list_1" name="rearrange_list_1" style=" margin-top:10pt;margin-left:10pt; list-style-type:none; " class="sortableList1">        
        <%
           
            String quotedName = "";
         if (attributeNames != null)            
         for (i=0; i<attributeNames.length; i++) {
            int order = i+1;
            quotedName = Util.urlEncode(attributeNames[i]);       
            %>
            <div id="item_<%=i%>">
            <div class="<%=divclass%>" id="item_<%=i%>_chkdiv" name="item_<%=i%>_chkdiv"   onclick="doCheckToggle('item_<%=i%>_chkdiv', '<%=quotedName%>');">
            </div>            
            <span style="padding-bottom:5px;"><%=order%>.</span>
            <span class="handle"  style="cursor:move;">Drag</span>
            <b>&nbsp;<%=attributeNames[i]%></b> 
            <input type="hidden" id="<%=quotedName%>" name="<%=quotedName%>" value="1" ></input> 
            <input type="hidden" id="item_<%=i%>_trackName"  name="trackNames"  value="<%=quotedName%>" >  </input>
            </div> 
        <% } %>            
        </div>
        <div id="lastdiv"  style="height: 11px ;"  >       
        </div>
        
        <script type="text/javascript">     
        Position.includeScrollOffsets = true ;     
        Sortable.create("rearrange_list_1", { tag: 'div', dropOnEmpty: true, constraint: 'vertical', scroll: 'listDiv', handle: 'handle' }) ;
        </script>   
        </td>  
        </tr>  
        
        <TR align="center"> 
        <td   class="midBorder"> 
        <input  type="button"  value="Display All"  class="btn" onclick="selectAllDisplay(<%=attributeNames.length%>);">&nbsp;&nbsp    
        <input  type="button"  value="Clear All"  class="btn" onClick="clearAllDisplay(<%=attributeNames.length%>);">      
        </td>  
        </tr>
        
        <TR > 
        <td   height="10" class="botBorder">&nbsp;
        </td>  
        </tr>
        </table>
        </td>
        
        <td valign="top"  width="310" >      
        <table cellspacing="0" cellpadding="0" > 
        <tr align="center">   
        <td  valign="top"  class="topBorder">               
        <span class="sa_subTitle">Sort Order</span>  
        <br>
        </td> 
        </tr>
        
        <tr>
            <TD valign="top" width="310"  class="midBorder">             
            <UL class="compact4" style="height:150px">
                Below are the sort columns, and the sort order.
               <br>
                <br><i><u>What columns to sort on?</u> <br>Select which columns to sort on.</i>
                <br>
                <br><i><u>What is the sort order?</u> <br>Drag your selected columns into the sorting order you desire.</i>
            </UL>
            </TD>
        </tr>
        
        <TR align="center"> 
        <td class="midBorder">
        <input  type="button"  value="Clear All" class="btn" onclick="clearAllSort(<%=attributeNames.length%>);" >
        </td>
        </TR> 
       
     
        
        <TR>  
        <TD  valign="top"  width="310"   class="midBorder">
        <div id="listDiv" class="<%=scrollableClass%>" style=" position:relative; margin-top:10pt;margin-left:10pt; border-style:solid; border-width:2px;height:260px; overflow:auto;">     
        <div id="rearrange_list2" name="rearrange_list2" style=" margin-top:10pt;margin-left:10pt; list-style-type:none; " class="sortableList1">
        <div id="sortitem_said">
        <div  class="checkBoxDiv1" id="sortitem_chkdiv"  onclick="doCheckToggle('sortitem_chkdiv', 'saName_sort' )" >        
        </div>             
        <span style="padding-bottom:5px;">1.</span>                  
        <span class="handle"  style="cursor:move;">Drag</span>                  
        <span><b>&nbsp;Sample&nbsp;ID</b></span>                 
        <input type="hidden"  id="sortitem_said_trackName" name=trackNames_sort" value="saName_sort"></input>                  
        <input type="hidden"  id="saName_sort" name="saName_sort" value="1"></input>
        </div>    
        
        <% 
        if (attributeNames !=null) 
        for (i=0; i<attributeNames.length; i++) {
        sortOrder = i+2;     
        quotedName = Util.urlEncode(attributeNames[i]);
        %> 
      
        <div id="sortitem_<%=i%>">                                                          
        <div class="checkBoxDiv" id="sortItem_<%=i%>_chkdiv" name="sortItem_<%=i%>_chkdiv"   onclick="doCheckToggle('sortItem_<%=i%>_chkdiv', '<%=quotedName%>_sort')">            
        </div>                  
        <span style="padding-bottom:5px;"><%=sortOrder%>.</span>                  
        <span class="handle"  style="cursor:move;">Drag</span>                                       
        <span><b >&nbsp;<%=attributeNames[i]%></b></span>                 
        <input type="hidden"  id="sortitem_<%=i%>_trackName" name="trackNames_sort" value="<%=quotedName%>_sort" ></input>                  
        <input type="hidden"  id="<%=quotedName%>_sort"   name="<%=quotedName%>_sort" value="0"></input>                  
        </div>                                     
        <%}%>
        </div>
        </div>                                    
        <script type="text/javascript">     
        Position.includeScrollOffsets = true ;     
        Sortable.create("rearrange_list2", { tag: 'div', dropOnEmpty: true, constraint: 'vertical', scroll: 'listDiv', handle: 'handle' }) ;                                    
        </script>                                       
        </td>
        </tr>                              
        <TR align="center"> 
        <td class="midBorder">
        <input  type="button"  value="Clear All" class="btn" onclick="clearAllSort(<%=attributeNames.length%>);" >
        </td>
        </TR>      
        
        <TR > 
        <td   height="10" class="botBorder"> &nbsp; 
        </td>  
        </tr>                                     
        </table> 
        </td>    
        </tr>
        </table>
        </td>
        </tr>
        
        <TR align="center">
        <td colspan="3">
        <BR>
        <input  type="button" name="apply"  id="apply" value="View" class="btn" style="WIDTH:100"  onClick="processSubmit('viewForm', '1');">
      <% //if (isAdmin) {%>
        <input  type="button" name="downloadBtn"  value="Download" class="btn" style="WIDTH:100"  onClick="processSubmit('viewForm', '2');"> 
        <input  type="hidden" id="download" name="download" value="0"  >                       
      <%//}%>
        <input type="submit" name="btnBack" value="Cancel"  class="btn" style="WIDTH:100">&nbsp;&nbsp          
         </td>
        </tr>
        </table>
        </div>
        
        </td>               
        <td width="10"></td>
        <td class="shadow"></td>
        </TR>               
        <% 
    }
        else if (mode >=0){%>
        <TR>
            <td width="10"></td>
            <td>
            <input type="submit" name="btnBack" value="Cancel"  class="btn" style="WIDTH:100">&nbsp;&nbsp;   
            </td>               
            <td width="10"></td>
            <td class="shadow"></td>
        </TR>        
      
        <%}%>                                     
</form>   
<TR>
<td width="10"></td>
<td>
<%@ include file="include/footer.incl" %>
</BODY>
</HTML>
