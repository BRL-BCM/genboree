<%@ page import="org.genboree.util.GenboreeUtils,
                 org.genboree.message.GenboreeMessage"%> 
                 <%@ include file="include/group.incl"
                 
                 %>
<%
    
    GenboreeMessage.clearMessage(mys);
String ftypeids = "";
   if (request.getParameter("ftypeids") != null) {
       String ids = request.getParameter("ftypeids"); 
      GenboreeUtils.sendRedirect(request, response, "java-bin/displaySelection.jsp?ftypeids="+ ids); 
   }
   else 
   GenboreeMessage.setErrMsg(mys, "Please enter ftype id ");
    
    %>
<html>
  <head>
<title>test page  page  </title>
    <link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css" >
<link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">
  </head>
  <body>
<%@ include file="include/header.incl" %>
  
 <UL><li> Please input some ftype id in the following field.
  <br>
 <li> If more than one number is netered, please use comma to seperate them.
 </UL>
  <br>
  
  <%@ include file="include/message.incl" %>
  
 <form id="test" name="test" action="ftypeidInput.jsp" method="post">
 &nbsp; &nbsp; &nbsp; &nbsp;<input type="text"  name="ftypeids" id="ftypeids " value="<%=ftypeids%>"   >
<input type="submit"  value="submit"> 
</form>
 <%@ include file="include/footer.incl" %>
</body>
</html>


