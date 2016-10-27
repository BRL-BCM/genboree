               
<%@ include file="include/fwdurl.incl" %>  
<%@ include file="include/userinfo.incl" %>
<%@ page import="org.genboree.util.Util,
                 java.util.Date"%>  
                 
<%
    String fileName =  null; 
    if (mys.getAttribute("fileName") != null) {
        fileName =(String)mys.getAttribute("fileName");      
    }
    
    if (fileName != null && fileName.startsWith("/usr/local/brl/local/apache/htdocs//genboreeUploads/")) 
        fileName = fileName.replaceAll ("/usr/local/brl/local/apache/htdocs//genboreeUploads/", ""); 
    
    
    
    String fileDate = null; 
    if (mys.getAttribute("fileDate") != null) {
        fileDate = (String) mys.getAttribute("fileDate");  
    }
     
    if (fileName == null) {
        GenboreeMessage.setErrMsg(mys, " an error happened upload file name ");
      return; 
    }
    
    if (fileDate == null) {        
          GenboreeMessage.setErrMsg(mys, " there is an error in the date of uploading file ");
            return;   
    }
        
    
%>

<HTML>
<head>
<title>Genboree - Entrypoint Upload</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>

</head>
<BODY>
<%@ include file="include/header.incl" %>
<%@ include file="include/navbar.incl" %>
<%@ include file="include/message.incl" %>
<form name="id" id="id" action="uploadMsg.jsp.jsp" >
<input  type="hidden" name="fileName" id="fileName" value="<%=fileName%>">
<input  type="hidden" name="fileDate" id="fileDate" value="<%=fileDate%>">

<p><strong><%=myself.getFullName()%></strong>,</p>
<p>Your &quot;sample&quot;  file has been uploaded and is being processed.</p>
<p>
Because processing of the sample file take some time (depending on the size
of your file), we will send you a confirmation email when it is complete.
</p>
<p>
If you do not receive such an email within 48 hours, please feel free to
contact our <A HREF="mailto:<%=GenboreeConfig.getConfigParam("gbAdminEmail")%>">administrator</A>.
</p>
<p>
When contacting us, please be sure to include the following
information about your data transaction:</p>
<p>
<i>Login Name:&nbsp;</i><%=Util.htmlQuote(myself.getName())%><br>
<i>File:&nbsp;</i><%=Util.htmlQuote(fileName)%><br>
<i>Date:&nbsp;</i><%=Util.htmlQuote(fileDate)%><br>
</p>
<br>
<p align="center">
<p align="center">
<p align="center">
 <table><tr><td valign="center">
 <div class="btnImage2">
<div style="align:center" id="bkMysamples" class="btnImage">
<a href="mySamples.jsp"><font color="white">Back To My Samples</font></a>
</div>
</div>
&nbsp; &nbsp;</td><td valign="center">
<div class="btnImage2">
<div id="bkUpload" style="align:center; valign:center;" class="btnImage">
<a href="mySamples.jsp?mode=Upload"><font color="white">Upload More Data</font></a>
</div>
</div>
</td></table>
</p>
</form>
<%@ include file="include/footer.incl" %>
</BODY>
</HTML>
