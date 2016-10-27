<%// GENBOREE ARBITRARY CONTENT WRAPPER *TEMPLATE*
  // - Use a *copy* of this template to wrap arbitrary HTML within Genboree,
  //   including session management and group-based access control.
%>
<%!
    // --------------------------------------------------------------------------
    // TEMPLATE CONFIGURATION
    // --------------------------------------------------------------------------
    // 1) Specify the file that has the content. Probably some sort of .incl file.
    //    EX: helpFile = "help/entrypointUpload.incl" ;
    String helpFile = null;
    // 2) If autoExternalPage, then specify the title for the page, else put empty string.
    String pageTitle = "Genboree Help & Documentation";

    // --------------------------------------------------------------------------
    // TEMPLATE VARIABLES
    // --------------------------------------------------------------------------
    String[] userInfo = new String[3] ;
    HttpSession mys = null ;


%>

<%@ include file="help/staticHelp.incl" %>
<%@ include file="include/fwdurl.incl" %>

<HTML>
<head>
  <title><%=pageTitle%></title>
  <meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1' >
  <link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css" >
  <link rel="stylesheet" href="/styles/help.css<%=jsVersion%>" type="text/css" >
  <script src="/javaScripts/showHelp.js<%=jsVersion%>" type="text/javascript"></script>
</head>
<BODY>
  <%@ include file="include/helpHeader.incl" %>
  <P class="body">
  <%
    Enumeration paramNames = request.getParameterNames() ;
    String topic = request.getParameter("topic") ;
    if(topic != null && !topic.equals(""))
    {
      // TEMPLATE: *dynamically* load the help content
      String topicFile = "help/" + topic.trim() + ".incl" ;
  %>
      <jsp:include page="<%=topicFile%>" flush="true" />
  <%
    }
    else // no topic specified
    {
      out.println("<BR>&nbsp;<P><FONT CLASS='errorTxt'>No valid help topic specified. Nothing to display.</FONT></P>") ;
    }
  %>
  &nbsp;
  <BR>
  <%@ include file="include/footer.incl" %>
</BODY>
</HTML>
