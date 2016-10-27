<%@ page import="javax.servlet.http.*, java.util.*, java.sql.*,java.io.*, java.net.*" %>
<%@ page import="org.genboree.util.*, org.genboree.dbaccess.*, org.genboree.dbaccess.util.*, org.genboree.message.*, org.genboree.manager.tracks.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/group.incl" %>
<%@ include file="include/sessionGrp.incl" %>
<%
  // Constants
  final String underlyingPage = "/genboree/trackAccessControl.rhtml" ;

  // Key variables:
  String urlStr = null ;
  boolean doHtmlStripping = true ;
  String contentUrl = null ;                       // String to store the entire content of an URL using getContentOfUrl(urlStr )
  String refSeqId = null ; // Not needed here, but staticContent.incl expects the variable
  String currPageURI = request.getRequestURI() ;
  String pageTitle = "Genboree Discovery System - Track Access Control" ;

  // First, deal with new group Selection
  String grpChangedParam = request.getParameter("grpChanged") ;
  if(grpChangedParam != null && grpChangedParam.equals("1"))
  {
    String grpId = request.getParameter("group_id") ;
    // Make sure to clear existing group/database/project, because group is changing!
    SessionManager.clearSessionGroup(mys) ;
    SessionManager.setSessionGroupId(mys, grpId) ;
  }
  // Second, deal with new database Selection
  String dbChangedParam = request.getParameter("databaseChanged") ;
  if(dbChangedParam != null && dbChangedParam.equals("1"))
  {
    String rseqId = request.getParameter("rseq_id") ;
    SessionManager.setSessionDatabaseId(mys, rseqId) ;
  }

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
        postContentBuff.append("&").append(pName).append("=").append(Util.urlEncode(pValues[ii])) ;
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
  urlStr = myBase + underlyingPage ;
  // TODO: remove this message when everything is looking stable
  GenboreeMessage.setErrMsg(mys, "<span style='white-space:nowrap'>(This is a recently added feature. Report issues to <a href='mailto:" +
                            GenboreeConfig.getConfigParam("gbAdminEmail") + "?subject=Project%20functionality'>Genboree Admin</a>.)</span>") ;
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
      <%@ include file="/include/trackManagerMenuBar.incl" %>
      <!-- Feedback Message: -->
      <%@ include file="include/message.incl" %>
      <!-- Group & Database Selection: -->
      <form method="post" action="" id="usrfsq" name="usrfsq">
        <table border="0" cellpadding="4" cellspacing="2" width="100%">
          <tr>
            <%@ include file="/include/groupbar.incl" %>
          </tr>
          <tr>
            <%@ include file="/include/databaseBar.incl" %>
          </tr>
        </table>
      </form>
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
