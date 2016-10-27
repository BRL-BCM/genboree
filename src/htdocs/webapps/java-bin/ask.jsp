<%@ page import="javax.servlet.http.*, org.genboree.dbaccess.*, org.genboree.util.*, org.genboree.upload.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%
	String actHref = (String) mys.getAttribute( "target" );
	if( actHref == null ) actHref = request.getRequestURL().toString();
	String quest = (String) mys.getAttribute( "question" );
	if( quest == null ) quest = "Don't know what happened. Do you?";
	mys.removeAttribute( "target" );
	mys.removeAttribute( "question" );
	String formText = (String)mys.getAttribute("form_text");
	if( formText == null ) formText = "";
%>

<HTML>
<head>
<title>Genboree - Question</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY>

<%@ include file="include/header.incl" %>

<center>
<%=quest%>
<form action="<%=actHref%>" method="post">
	<%=formText%>
    <input name="askYes" type=submit value="Yes" style="width:100">&nbsp;&nbsp;
    <input name="askNo" type=submit value="No" style="width:100">&nbsp;
</form>
</center>

<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
