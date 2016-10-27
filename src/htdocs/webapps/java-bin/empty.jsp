<%@ page import="javax.servlet.http.*, org.genboree.dbaccess.*, org.genboree.util.*, org.genboree.upload.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<HTML>
<head>
<title>Genboree - </title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY bgcolor="#DDE0FF">

<%@ include file="include/header.incl" %>

<center>

<form action="empty.jsp" method="post">
  <table class='TABLE' align="center" border="2" bgcolor="#aac5ff">
  <tbody>
  <tr>
  <td>
    <input name="cmd" type=submit value='Submit'>
  </td>
  </tr>
  </tbody>
  </table>
</form>

</center>

<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
