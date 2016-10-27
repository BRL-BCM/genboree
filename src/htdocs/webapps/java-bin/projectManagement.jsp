<%@ page import="javax.servlet.http.*, java.util.*, java.sql.*,java.io.*, java.net.*" %>
<%@ page import="org.genboree.util.*, org.genboree.manager.projects.*, org.genboree.dbaccess.*, org.genboree.dbaccess.util.*, org.genboree.upload.*, org.genboree.message.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/group.incl" %>
<%
  // Constants
  final String underlyingPage = "/genboree/projectManagement.rhtml" ;
  final String[] modeLabels = { "Create", "Rename", "Delete", "Copy", "Move" } ;
  final int MODE_DEFAULT = -1;
  final int MODE_CREATE = 0 ;
  final int MODE_RENAME = 1 ;
  final int MODE_DELETE = 2 ;
  final int MODE_COPY = 3 ;
  final int MODE_MOVE = 4 ;

  // Key variables:
  String urlStr = null ;
  boolean doHtmlStripping = true ;
  String contentUrl = null ;                       // String to store the entire content of an URL using getContentOfUrl(urlStr )
  String refSeqId = null ; // Not needed here, but staticContent.incl expects the variable
  String currPageURI = request.getRequestURI() ;
  String pageTitle = "Genboree Discovery System - Project Management" ;
  int modeArg = Util.parseInt(request.getParameter("mode"), -1) ;
  // Are we even using projects feature?
  boolean useProjects = ( !GenboreeConfig.getConfigParam("useProjects").equalsIgnoreCase("false") ) ;

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
  //System.err.println("DEBUG: context path: " + uriPath) ;
  urlStr = myBase + underlyingPage ;
  //System.err.println("DEBUG: urlStr: " + urlStr) ;
  // Set session info
  SessionManager.clearSessionGroup(mys) ;
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
<%
if( modeArg == MODE_COPY || modeArg == MODE_MOVE )
{
%>
      <script type="text/javascript" src="/javaScripts/ext-2.2/adapter/prototype/prototype.js<%=jsVersion%>"></script>
      <script type="text/javascript" src="/javaScripts/ext-2.2/adapter/prototype/scriptaculous.js<%=jsVersion%>"></script>
      <script type="text/javascript" src="/javaScripts/ext-2.2/adapter/prototype/ext-prototype-adapter.js<%=jsVersion%>"></script>
      <script type="text/javascript" src="/javaScripts/ext-2.2/ext-all.js<%=jsVersion%>"></script>
      <link rel="stylesheet" href="/javaScripts/ext-2.2/resources/css/window.css<%=jsVersion%>" type="text/css">
      <link rel="stylesheet" href="/javaScripts/ext-2.2/resources/css/dialog.css<%=jsVersion%>" type="text/css">
      <link rel="stylesheet" href="/javaScripts/ext-2.2/resources/css/panel.css<%=jsVersion%>" type="text/css">
      <link rel="stylesheet" href="/javaScripts/ext-2.2/resources/css/core.css<%=jsVersion%>" type="text/css">
      <!-- Set a local "blank" image file; default is a URL to extjs.com -->
      <script type='text/javascript'>
        Ext.BLANK_IMAGE_URL = '/javaScripts/extjs/resources/images/genboree/s.gif';
      </script>

<%
}
%>
    </head>
    <BODY>
      <%@ include file="include/header.incl" %>
      <%@ include file="include/navbar.incl" %>
      <!-- Sub-Menu: -->
      <table border="0" cellspacing="4" cellpadding="2">
      <tr>
<%
        for(int ii=0; ii<modeLabels.length; ii++ )
        {
          String cls = "nav" ;
          String a1 = "<a href=\"projectManagement.jsp?mode=" + ii + "\">" ;
          String a2 = "</a>" ;
          if( ii == modeArg )
          {
            a1 += "<font color='white'>" ;
            a2 = "</font>" + a2 ;
            cls = "nav_selected" ;
          }
%>
          <td class="<%=cls%>"><%= a1 %><%= modeLabels[ii] %><%= a2 %></td>
<%
        }
%>
      </tr>
      </table>
      <!-- Group Selection: -->
      <form name="groupSelectionForm" id="groupSelectionForm" action="" method="post" style="margin-bottom: 0px;">
        <input type="hidden" name="mode" id="mode" value="<%= modeArg %>">
        <table id="grpDbBarsTable" name="grpDbBarsTable" border="0" cellpadding="4" cellspacing="2" width="100%">
        <tr>
<%
          if(rwGrps.length == 1)
          {
%>
            <td class="form_header">
              <strong>Group</strong>
              <input type="hidden" name="group_id" id="group_id" value="<%=groupId%>">
            </td>
            <td class="form_header">
              <%= Util.htmlQuote(grp.getGroupName()) %>
              &nbsp;&nbsp;<font color="#CCCCFF">Role:</font>&nbsp;&nbsp;<%= myGrpAccess %>
            </td>
<%
          }
          else
          {
            // if( rwGrps.length != 1 ) %>
            <%@ include file="include/groupbar.incl"%>
<%
          }
%>
        </tr>
        </table>
      </form>
      <!-- Feedback Message: -->
      <%@ include file="include/message.incl" %>
<%
  if(useProjects)
  {
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
    else // Project probably not registered...error
    {
      urlStr = request.getContextPath() + "/mygroup.jsp" ;
%>
      <center>
      <font color="red"><b>ERROR: It looks like the project management feature has some issues or you've reached this page in
      an inappropriate manner.</b>
      <p>
      You will be redirected to a safe location in 8 seconds or you can <a href="<%= urlStr %>" >
      go there now</a>.</font>
      <p>
      <script type="text/javascript">
      //<!--
        function redir()
        {
          top.location="<%= urlStr %>" ;
        }

        setTimeout('redir()', 8000) ;
      //-->
      </script>
      </center>
<%
    }
  }
%>
      <BR>
<%@ include file="include/footer.incl" %>
    </BODY>
    </HTML>
