<%--
  Created by IntelliJ IDEA.
  User: tong
  Date: Dec 1, 2006
  Time: 1:46:16 PM
  To change this template use File | Settings | File Templates.
--%>
<%! 
   public static String[] modeIds =  { "Upload", "View/DownLoad"};
    public static String[] modeLabs =  { "Upload", "View&nbsp;/&nbsp;DownLoad"};      
%>
<%
String mode = request.getParameter("status"); 
    if (mode != null && mode.equals("1")) 
    GenboreeUtils.sendRedirect(request, response, "java-bin/mySamples.jsp?mode=View/DownLoad");
  
%>
<%@ page import="javax.servlet.http.*, org.genboree.util.* " %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<HTML>
<head>
<title>Genboree - Upload Samples</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
<script type="text/javascript">
function submitForm(m) {
document.getElementById('status').value = m; 
document.sampleForm.submit(); 
}
</script>
</head>
<BODY class="body_noBottom"  bgcolor="#DDE0FF">
<%@ include file="include/header.incl" %>
<%@ include file="include/navbar.incl" %>   
<form class="no_margins" name="sampleForm" id="sampleForm"  action="sampleTop.jsp" target="_top" method="post">
<input type="hidden"  id="status" name="status" value="0">
<table  border="0" cellspacing="4" cellpadding="2">          
<TR>
<%
for( int i=0; i<modeIds.length; i++ ){
String cls = "nav";
String a1 = "<div class='nomargin' onclick=submitForm(" + i + ")><a href=#>";
String a2 = "</a></div>";
if( i == 0 ){
cls = "nav_selected";
a1 = a2 = "";      
}
%>
<td class="<%=cls%>"><%=a1%><%=modeLabs[i]%><%=a2%></td>
<%}%>
</tr>  
</table> 
</td><td>&nbsp;</td><td class="shadow">&nbsp;</td></tr>
</table>
</form>
</BODY>
</HTML>
