<%@ page import="java.util.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>

<HTML>
<head>
<title>Genboree - Upload Complete</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY>
<%@ include file="include/header.incl" %>
<%@ include file="include/navbar.incl" %>
     <%
         String fileName = request.getParameter("fileName");
         String destback = (String )mys.getAttribute("lastBrowserView");
     %>

<p><strong><%=myself.getFullName()%></strong>,</p>
<p>your data has been submitted for uploading.</p>

<p>Since the <i>annotation uploading</i> process may take a while (depending on the size
of your data file), we will send you a confirmation email when it is complete.</p>
<p>If you do not receive such an email within 48 hours, please feel free to
contact our administrator.</p>
<p>When contacting us, please be sure to include the following
information about your data transaction:</p>
<p>
<i>Login Name:</i><%=Util.htmlQuote(myself.getName())%><br>
<i>File:</i><%=Util.htmlQuote(fileName)%><br>
<i>Date:</i><%=Util.htmlQuote((new Date()).toString())%><br>
</p>

<br>
<p align="center">
<%
  if(fileName != null)
  {
    if(destback == null)
    {
      destback = "/java-bin/defaultGbrowser.jsp" ;
      mys.setAttribute( "lastBrowserView", destback );
    }
%>
    <a href="<%=destback%>"><img src="/images/goBackToBrowser.gif" width="134" height="24"></a>&nbsp&nbsp
<%
  }
%>
<a href="myrefseq.jsp?mode=Upload"><img src="/images/uploadMoreData.gif" width="125" height="24"></a></p>

<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
