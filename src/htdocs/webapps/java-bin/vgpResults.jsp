<%@ page import="
  javax.servlet.http.*, 
  java.util.*, 
  java.sql.*,
  java.io.*, 
  java.net.*,
  org.genboree.util.*, 
  org.genboree.dbaccess.*, 
  org.genboree.dbaccess.util.*, 
  org.genboree.message.*, 
  org.genboree.manager.tracks.*,
  org.genboree.util.helpers.*"
%>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/group.incl" %>
<%@ include file="include/sessionGrp.incl" %>
<%
  // Constants
  final String underlyingPage = "/genboree/vgpResults.rhtml" ;

  // Key variables:
  String urlStr = null ;
  boolean doHtmlStripping = true ;
  String contentUrl = null ;                       // String to store the entire content of an URL using getContentOfUrl(urlStr )
  String refSeqId = null ; // Not needed here, but staticContent.incl expects the variable
  String currPageURI = request.getRequestURI() ;
  String pageTitle = "Genboree Discovery System - VGP Results" ;

  // The handing of group/DB selection taken from existing codebase, MFS (BNI)
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
  postContentBuff.append("userLogin=").append(URLEncoder.encode(userInfo[0], "UTF-8")) ;
  // 1.b Loop over request key-value pairs, append them to rhtml request:
  Iterator paramIter = paramMap.entrySet().iterator() ;
  while(paramIter.hasNext())
  {
    Map.Entry paramPair = (Map.Entry) paramIter.next() ;
    String pName = URLEncoder.encode((String) paramPair.getKey(), "UTF-8") ;
    String[] pValues = (String[]) paramPair.getValue() ; // <-- Array!
    postContentBuff.append("&") ;
    if(pValues != null)
    { // then there is 1+ actual values
      for(int ii = 0; ii < pValues.length; ii++)
      { // Add all of the values to the POST
        postContentBuff.append(pName).append("=").append(URLEncoder.encode(pValues[ii], "UTF-8")) ;
      }
    }
    else // no value, just a key? ok...
    {
      postContentBuff.append("&").append(pName).append("=") ;
    }
  }
  
  // Set group_id if it has not been set -- we must use key names of group_id && rseq_id because that is what might be
  // originally posted to us from code outside of us
  if((postContentBuff.indexOf("group_id") == -1) && (SessionManager.getSessionGroupId(mys) != null))
  {
    postContentBuff.append("&group_id=").append(URLEncoder.encode(SessionManager.getSessionGroupId(mys), "UTF-8")) ;
  }

  if((postContentBuff.indexOf("rseq_id") == -1) && (SessionManager.getSessionDatabaseId(mys) != null))
  {
    postContentBuff.append("&rseq_id=").append(URLEncoder.encode(SessionManager.getSessionDatabaseId(mys), "UTF-8")) ;
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
      <!-- BEGIN: Scriptaculous support -->
      <script type="text/javascript" src="/javaScripts/prototype.js<%=jsVersion%>"></script>
      <script type="text/javascript" src="/javaScripts/scriptaculous.js?load=effects,dragdrop,slider"></script>
      <!-- END -->

      <!-- BEGIN: Genboree specific support -->
      <link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css" >
      <link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">
      <link rel="stylesheet" href="/styles/vgpResults.css<%=jsVersion%>" type="text/css">
      <!-- END -->
    </head>
    <BODY>
      <%@ include file="/include/header.incl" %>
      <%@ include file="/include/navbar.incl" %>
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
