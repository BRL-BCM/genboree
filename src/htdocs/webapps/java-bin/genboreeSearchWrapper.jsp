<%@ page import="javax.servlet.http.*, java.util.*, java.sql.*,java.io.*, java.net.*" %>
<%@ page import="org.genboree.util.*, org.genboree.dbaccess.*, org.genboree.dbaccess.util.*, org.genboree.message.*, org.genboree.manager.tracks.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/group.incl" %>
<%@ include file="include/sessionGrp.incl" %>
<%
  // Constants
  final String underlyingPage = "/genboree/genboreeSearchWrapper.rhtml" ;

  // Key variables:
  String urlStr = null ;
  boolean doHtmlStripping = true ;
  String contentUrl = null ;                       // String to store the entire content of an URL using getContentOfUrl(urlStr )
  String refSeqId = null ; // Not needed here, but staticContent.incl expects the variable
  String currPageURI = request.getRequestURI() ;
  String pageTitle = "Genboree Discovery System - Search User Database" ;

  // REBUILD the request params we will pass to RHTML side (via a POST)
  Map paramMap = new HashMap(request.getParameterMap()) ; // "key"=>String[] (note that the request's Map is locked read-only)
  // 1. Send the userId, whether on form or not
  String[] userIdArray = new String[1] ;
  userIdArray[0] = "" + userId ;
  paramMap.put("userId", userIdArray) ;
  // 2. Send a flag that this is from an internal Genboree jsp page
  String[] internalArray = new String[1] ;
  internalArray[0] = "true" ;
  paramMap.put("fromInternalGbPage", internalArray) ;
  // Get the rebuilt query string
  String postContentStr = Util.rebuildQueryString(paramMap) ;

  String uriPath = request.getRequestURI().replaceAll("/[^/]+\\.jsp.*$", "") ;
  urlStr = myBase + underlyingPage ;
%>
    <HTML>
    <head>
      <title><%=pageTitle%></title>
      <meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
      <link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css" >
      <link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">
    </head>
    <BODY>
      <%@ include file="/include/header.incl" %>
      <%@ include file="/include/navbar.incl" %>
      <!-- Feedback Message: -->
      <%@ include file="include/message.incl" %>
<%
    if(urlStr != null)
    {
      HashMap hdrsMap = new HashMap() ;
      // Do as a POST
      contentUrl = GenboreeUtils.postToURL(urlStr, postContentStr, doHtmlStripping, hdrsMap, mys ) ;
      // Update group/database if correct X-HEADERS are found:
      GenboreeUtils.updateSessionFromXHeaders(hdrsMap, mys) ;
      // Write out content of other page
      out.write(contentUrl) ;
    }
%>
      <BR>
<%@ include file="/include/footer.incl" %>
    </BODY>
    </HTML>
