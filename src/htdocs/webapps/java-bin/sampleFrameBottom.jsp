<%@ page import="org.genboree.dbaccess.GenboreeGroup,
java.util.*,
java.io.*,
org.genboree.upload.*,
org.genboree.upload.HttpPostInputStream,
org.genboree.upload.AnnotationUploader,
org.genboree.upload.DatabaseCreator,
org.genboree.upload.FastaEntrypointUploader,
org.genboree.message.GenboreeMessage,
org.genboree.samples.*" %> 
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/group.incl" %> 
<%
response.addDateHeader( "Expires", 0L );
response.addHeader( "Cache-Control", "no-cache, no-store" );  
if (request.getParameter("back2Sample")!= null) {
GenboreeUtils.sendRedirect(request, response, "/java-bin/mySamples.jsp"); 
}         

GenboreeMessage.clearMessage(mys);    
Refseq rseq = null;
String refseqId = null; 
if (rseqs != null && rseqs.length>0) {
rseq = rseqs[0];
refseqId = rseq.getRefSeqId(); 
}
else {

GenboreeMessage.setErrMsg(mys, "Sorry, there is no database in this group. <br> -- Please create a database and try again.");
}

boolean hasAccess = true;
if ( myGrpAccess == null ||myGrpAccess.compareToIgnoreCase("Subscriber")==0 ) 
{
GenboreeMessage.setErrMsg(mys, "Sorry, you don't have access to this group.");
hasAccess = false; 
} 
GenboreeMessage.clearMessage(mys);  

if (!hasAccess) 
GenboreeMessage.setErrMsg(mys, "Sorry, you don't have access to this group.");


int stud = 0;

Integer iStudent = (Integer) mys.getAttribute( "uploadStudent" );
if( iStudent != null ) stud = iStudent.intValue();
%>           
<%@ include file="include/sessionGrp.incl" %>         
<HTML>
<head>
<title >My Samples</title>
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css" >
<link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css" >
<SCRIPT type="text/javascript" src="/javaScripts/prototype.js<%=jsVersion%>"></SCRIPT>
<SCRIPT type="text/javascript" src="/javaScripts/util.js<%=jsVersion%>"></SCRIPT>
<SCRIPT type="text/javascript" src="/javaScripts/commonFunctions.js<%=jsVersion%>"></SCRIPT>               
<SCRIPT type="text/javascript" src="/javaScripts/sample.js<%=jsVersion%>"></SCRIPT>     
</head>
<BODY  class="notop" >       
<table cellpadding=0 cellspacing=0 border=0 bgcolor=white width=700 class='TOP'>
<tr><td></td><td>   
<form class="no_margins" name="uploadForm2" id="uploadForm2" action="sampleFrameBottom.jsp" target="_top" method="post"> 
<input type="hidden" name="back2Sample"  name="back2Sample"   value="0">
</form>            
<form class="no_margins" name="uploadForm" id="uploadForm" action="sampleFrameBottom.jsp" method="post"> 
<%@ include file="include/message.incl" %>


<input type="hidden" name="uploadFileName"  name="uploadFileName" value="">
<table border="0" cellpadding="4" cellspacing="2" width="100%">
<%   if( rwGrps.length == 1 ) { %>
<TR> <td width="20%"></td><td></td></TR>
<TR>         
<td  class="form_header">
<strong>Group</strong>
</td>
<input type="hidden" name="group_id" id="group_id" value="<%=groupId%>">
<td class="form_header">
<%=Util.htmlQuote(grp.getGroupName())%>
&nbsp;&nbsp;<font color="#CCCCFF">Role:</font>&nbsp;&nbsp;<%=myGrpAccess%>
</td> 
</TR>
<% }
else {  %>
<TR>
<%@ include file="include/groupbar.incl"%>
</TR>
<% }  %>
<TR>        
<%@ include  file="include/databaseBar.incl" %>
</TR>
</table>
</form>      
<form name="uploadForm1" id="uploadForm1" action="sampleUpload.jsp" 
target="_top" method="post" ENCTYPE="multipart/form-data" onsubmit="return uploadFormSubmitIt(this);">
<input type="hidden" name="uploadFileName" id="uploadFileName" value="" >
<input type="hidden" name="rm" value="upload">
<input type="hidden" name="refseq" value="<%=refseqId%>">
<input type="hidden" name="groups" value="<%=groupId%>">
<input type="hidden" name="origFileName" id="origFileName" value="">
<table border="0" cellpadding="4" cellspacing="2" width="100%">
<tr>
<td width="38%" class="form_body" id="uploadLabel">            
<strong>&nbsp;Upload File:&nbsp;</strong>            
</td>
<% if(   refseqId==null &&  rseqs.length >0  && rseqs!= null && hasAccess) { %>

<td class="form_body"><input type="text" name="sampleFileName" id="sampleFileName"  size="55"></td>
<% }
else if (rseqs!= null &&  rseqs.length >0 && refseqId != null && hasAccess)  {
%>     
<td class="form_body">
<input type="file" name="sampleFileName"  id="sampleFileName"  class="txt" size="40"  onChange="updateUpload();">                           
</td> 
<%}%>     
</tr> 
<tr> 
<td colspan="2" >
<% if (rseqs!=null && rseqs.length >0 && hasAccess) {%>
<input  type="submit" name="upload" id="upload" value="Upload" class="btn"  style="WIDTH:100">
<% }%>
<input type="button" name="btnBack" value="Cancel"  class="btn" onClick="document.uploadForm2.submit();" style="WIDTH:100">&nbsp;&nbsp;       
</td>         
</tr>   
</table>
</form>
<IMG SRC="<%=GenboreeUtils.returnFullURL(request, "/java-bin/servlets/ProgressServlet")%>" WIDTH="0" HEIGHT="0" style="visibility: hidden ;">

<script language=javascript> 
var upload_started = false;

function reallyCheck(chkBox, dialogMessage)
{
var retVal = true ;
if(chkBox.checked)
{
retVal = confirm(dialogMessage) ;
if(!retVal) // Uncheck the box because they said 'no'
{
chkBox.checked = false ;
}
}
return retVal ;
}

function uploadFormSubmitIt(uploadForm1)
{
<% if( stud == 0 ) { %>

<% } %>
if (uploadForm1.sampleFileName.value == "" )
{
alert("You didn't specify upload file!");
uploadForm1.sampleFileName.focus();
return false;
}

document.uploadForm1.origFileName.value = document.uploadForm1.sampleFileName.value;
if( upload_started ) return true;
startUpload() ;
return false;
}

function startUpload()
{
upload_started = true;
var progr = window.open( null, "progressFrame" );
progr.location.replace( "progrpage.jsp?f=" + document.uploadForm1.sampleFileName.value );

setTimeout("document.uploadForm1.submit()", 1000);
}
</script>
<%@ include file="include/footer.incl" %>
</BODY>
</HTML>
           
           
           
           
