<%@ page import="org.genboree.util.*, org.genboree.manager.projects.*, org.genboree.dbaccess.*, org.genboree.dbaccess.util.*" %>
<%
  // Key variables:
  String urlStr = null ;
  boolean doHtmlStripping = true ;
  String contentUrl = null ;                       // String to store the entire content of an URL using getContentOfUrl(urlStr )
  String refSeqId = null ; // Not needed here, but staticContent.incl expects the variable
  String currPageURI = request.getRequestURI() ;
  // Are we even using projects feature?
  String useProjectsValue = GenboreeConfig.getConfigParam("useProjects") ;
  boolean useProjects = ( (useProjectsValue != null ) && !(useProjectsValue.equalsIgnoreCase("false")) ) ;
  // We need this for staticContent.incl, but really we're going to defer access issues
  // to the RHTML page:
  String groupAllowed = null ;
  String projName = request.getParameter("projectName") ;
  String pageTitle = ("Genboree Discovery System - Project: " + projName) ;
%>
<%@ include file="include/staticContent.incl" %>
<%
  // REBUILD the request params we will pass to RHTML side (via a POST)
  Map paramMap = request.getParameterMap() ; // "key"=>String[]
  StringBuffer postContentBuff = new StringBuffer() ;
  // 1.a Send the userId, whether on form or not
  postContentBuff.append("userId=").append(Util.urlEncode(userInfo[2])) ;
  // 1.b Loop over request key-value pairs, append them to rhtml request:
  Iterator paramIter = paramMap.entrySet().iterator() ;
  while(paramIter.hasNext())
  {
    Map.Entry paramPair = (Map.Entry) paramIter.next() ;
    String pName = Util.urlEncode((String) paramPair.getKey()) ;
    String[] pValues = (String[]) paramPair.getValue() ; // <-- Array!
    if(pValues != null)
    { // then there is 1+ actual values
      for(int ii = 0; ii < pValues.length; ii++)
      { // Add all of the values to the POST
        postContentBuff.append("&").append(pName).append("=").append(URLEncoder.encode(pValues[ii], "UTF-8")) ;
      }
    }
    else // no value, just a key? ok...
    {
      postContentBuff.append("&").append(pName).append("=") ;
    }
  }
  // 1.c Get the string we will post IF that's what we will be doing
  String postContentStr = postContentBuff.toString() ;

  String uriPath = request.getRequestURI().replaceAll("/[^/]+\\.jsp.*$", "") ;
  urlStr = myBase + "/genboree/project.rhtml" ;

  // TODO: remove this message when everything is looking stable
  if(useProjects)
  {
    GenboreeMessage.setErrMsg(mys, "<span style='white-space:nowrap'>(This is a recently added feature. Report issues to <a href='mailto:" +
                              GenboreeConfig.getConfigParam("gbAdminEmail") + "?subject=Project%20functionality'>Genboree Admin</a>.)</span>") ;
  }
  else // Projects not turned on
  {
    GenboreeMessage.setErrMsg(mys, "<span style='white-space:nowrap'>(The projects feature is not enabled on this server. How did you arrive here?)</span>") ;
  }
%>
  <HTML>
    <head>
      <title><%=pageTitle%></title>
      <meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
      <link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css" >
      <link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">
    </head>
    <BODY>
      <%@ include file="include/header.incl" %>
      <%@ include file="include/navbar.incl" %>
      <%@ include file="include/message.incl" %>
<%
  if(useProjects)
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
<%@ include file="include/footer.incl" %>
    </BODY>
  </HTML>
