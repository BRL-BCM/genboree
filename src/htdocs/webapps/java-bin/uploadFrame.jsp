<%--
Created by IntelliJ IDEA.
User: tong
Date: Nov 28, 2006
Time: 3:52:17 PM
To change this template use File | Settings | File Templates.
--%>
<%@ page import="javax.servlet.http.*, org.genboree.dbaccess.*,
org.genboree.util.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<% 
response.addDateHeader( "Expires", 0L );
response.addHeader( "Cache-Control", "no-cache, no-store" );
%>
<HTML>
<HEAD>
<TITLE>Genboree - Upload Ref.Sequence</TITLE>
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
</HEAD>
<FRAMESET rows="170, *"  FRAMEBORDER="no" border="0"  framespacing="0">
<FRAME src="/java-bin/sampleTop.jsp" name="progressFrame"  marginheight="0" scrolling=no>
<FRAME src="/java-bin/sampleFrameBottom.jsp"   marginheight="0" name="uploadFrame" NORESIZE>
</FRAMESET>
</HTML>
