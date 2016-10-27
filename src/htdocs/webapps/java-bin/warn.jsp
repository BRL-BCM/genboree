<%@ page import="javax.servlet.http.*, org.genboree.dbaccess.*, org.genboree.util.*, org.genboree.upload.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%!
%>
<%
  response.addDateHeader( "Expires", 0L );

	String warnMsg = (String) mys.getAttribute( "warnMsg" );
	if( warnMsg == null )
	{ warnMsg = "UNKNOWN"; }
	String sTmo = (String) mys.getAttribute( "warnTmo" );
	int warnTmo = Util.parseInt( sTmo, 10 );
	String tgt = (String) mys.getAttribute( "warnTgt" );
	if( tgt == null )
	{ tgt = "login.jsp"; }
	mys.removeAttribute( "warnMsg" );
	mys.removeAttribute( "warnTmo" );
	mys.removeAttribute( "warnTgt" );
%>

<HTML>
<head>
<title>Genboree - Warning</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY onLoad="setTimeout('forwardHome()', <%=warnTmo%>000);">

<%@ include file="include/header.incl" %>

<center>
	<font color="red"><strong>WARNING</strong></font><br><br>
	<%=warnMsg%><br><br>
</center>

In <%=warnTmo%> seconds you will be automatically forwarded to the start page. 
Click <a href="<%=tgt%>">here</a> if you do not want to wait any longer, or if 
your browser does not support automatic forwarding.

<%@ include file="include/footer.incl" %>

<script language="JavaScript">
function forwardHome()
{
	document.location.replace( "<%=tgt%>" );
}
</script>

</BODY>
</HTML>
