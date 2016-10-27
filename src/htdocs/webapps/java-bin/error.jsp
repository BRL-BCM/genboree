<%@ page import="javax.servlet.http.*, java.net.*, org.genboree.util.*, org.genboree.dbaccess.*, java.util.*" %>
<%@ include file="include/fwdurl.incl" %>

<%
  String[] userInfo = new String[3] ;
  String[] errorMsg = null ;
  int maxLen = 15 ;

  HttpSession mys = request.getSession() ;
  errorMsg = (String []) mys.getAttribute( "lastError" ) ;
  mys.removeAttribute( "lastError" ) ;
  if( errorMsg == null )
  {
    errorMsg = new String[2] ;
    errorMsg[0] = errorMsg[1] = "UNKNOWN" ;
  }
  if( errorMsg.length < maxLen )
  {
    maxLen = errorMsg.length ;
  }
%>

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
  <head>
    <title>Genboree - Error!!!</title>
    <link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
    <meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
  </head>
  <body bgcolor="#DDE0FF">
    <%@ include file="include/header.incl" %>
    <p>
<%
      String errTitle = null ;
      String errMsg = null ;
      if( errorMsg[0].equals("java.sql.SQLException") )
      {
        errTitle = "DB SERVER ERROR: The database is not accessible at this time." ;
        errMsg = "Please try again later, and if the problem persists, contact the system administrator." ;
      }
      else if(errorMsg[0].equals("FORBIDDEN:"))
      {
        errTitle = "FORBIDDEN: You do not have access to that data." ;
      }
      else
      {
        errTitle = "INTERNAL ERROR: An internal exception has occured. (" + errorMsg[0] + ")" ;
        errMsg = "Please report this problem to the system administrator." ;
      }
%>
      <div style="color:red; font-size:13pt; font-weight: bold; padding-top: 20px;"><%= errTitle %></div>
      <br>&nbsp;<br>
      <span style="color:red; font-size:11pt;">We apologize for any inconvenience this may cause to you.</span>
      <br>&nbsp;<br>
<%
      if(errMsg != null)
      {
%>
        <%= errMsg %>
        <br>&nbsp;<br>
<%
      }
%>
      <hr style="height:1px;">
      <span style="font-size: 11pt;">Additional error details:</span>
      <br>&nbsp;<br>
      <div style="width:100%; font-family:monospace; font-size: 10pt;">
<%
      for(int ii=1; ii < maxLen; ii++)
      {
%><%=errorMsg[ii]%><br>
<%
      }
%>
      </div>
      <hr style="height:1px;">
      <form action="index.jsp" method="post">
        <input type="submit" value="Cancel" class="btn">
      </form>
    <%@ include file="include/footer.incl" %>
  </BODY>
</HTML>
