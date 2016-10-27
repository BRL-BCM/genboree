<%@ page import="javax.servlet.http.*, java.util.*, java.sql.*,java.io.*, java.net.*" %>
<%@ page import="org.genboree.util.*, org.genboree.dbaccess.*, org.genboree.dbaccess.util.*, org.genboree.message.*, org.genboree.manager.tracks.*" %>
<%@ page import="org.genboree.util.helpers.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/group.incl" %>
<%@ include file="include/sessionGrp.incl" %>
<%
  // Constants
  final String underlyingPage = "/genboree/ucscBigFiles.rhtml";
  String pageTitle = "Genboree Discovery System - BigBed and BigWig file management" ;

            // Key variables:
   String urlStr = null ;
   boolean doHtmlStripping = true ;
   String contentUrl = null ; // String to store the entire content of an URL using getContentOfUrl(urlStr )
   String refSeqId = null ; // Not needed here, but staticContent.incl expects the variable
   String currPageURI = request.getRequestURI() ;
   String groupAllowed = null ;
   // REBUILD the request params we will pass to RHTML side (via a POST)
   Map paramMap = request.getParameterMap() ; // "key"=>String[]
   StringBuffer postContentBuff = new StringBuffer() ;
   // 1.a Send the userId, whether on form or not
   postContentBuff.append("userId=").append(Util.urlEncode(userInfo[2])) ;
   // Need to send the group_id when it's not post'd
   postContentBuff.append("&group_id=").append(Util.urlEncode(groupId)) ;
   postContentBuff.append("&refseq_id=").append(Util.urlEncode(rseq_id)) ;

   // Set group_id if it has not been set -- we must use key names of group_id && rseq_id because that is what might be
   // originally posted to us from code outside of us
   if((postContentBuff.indexOf("group_id") == -1) && (SessionManager.getSessionGroupId(mys) != null))
   {
     postContentBuff.append("&group_id=").append(URLEncoder.encode(SessionManager.getSessionGroupId(mys), "UTF-8")) ;
   }

   if(SessionManager.getSessionGroupName(mys) != null)
   {
     postContentBuff.append("&groupName=").append(URLEncoder.encode(SessionManager.getSessionGroupName(mys), "UTF-8")) ;
   }

   if((postContentBuff.indexOf("rseq_id") == -1) && (SessionManager.getSessionDatabaseId(mys) != null))
   {
     postContentBuff.append("&rseq_id=").append(URLEncoder.encode(SessionManager.getSessionDatabaseId(mys), "UTF-8")) ;
   }

   if(SessionManager.getSessionDatabaseDisplayName(mys) != null)
   {
     postContentBuff.append("&rseqName=").append(URLEncoder.encode(SessionManager.getSessionDatabaseDisplayName(mys), "UTF-8")) ;
   }

   postContentBuff.append("&grpChangeState=").append(Util.urlEncode(grpChangeState)) ;


   postContentBuff.append("&userEmail=").append(URLEncoder.encode(myself.getEmail(), "UTF-8")) ;
   postContentBuff.append("&userLogin=").append(URLEncoder.encode(userInfo[0], "UTF-8")) ;
   postContentBuff.append("&passwd=").append(URLEncoder.encode(userInfo[1], "UTF-8")) ;
   String userPwdDigest = RESTapiUtil.SHA1(userInfo[0] + userInfo[1]) ;
   if(userPwdDigest != null)
   {
     postContentBuff.append("&userPwdDigest=").append(URLEncoder.encode(userPwdDigest, "UTF-8")) ;
   }

   postContentBuff.append("&userPwdDigest=").append(Util.urlEncode(userPwdDigest)) ;

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
   urlStr = myBase + underlyingPage ;



%>
    <HTML>
    <head>
      <title><%=pageTitle%></title>
      <meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
      <link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css" >
      <link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">

      <script type="text/javascript" src="/javaScripts/ext-2.2/adapter/prototype/prototype.js<%=jsVersion%>"></script>
      <script type="text/javascript" src="/javaScripts/ext-2.2/adapter/prototype/scriptaculous.js<%=jsVersion%>"></script>
      <script type="text/javascript" src="/javaScripts/ext-2.2/adapter/prototype/ext-prototype-adapter.js<%=jsVersion%>"></script>
      <script type="text/javascript" src="/javaScripts/ext-2.2/ext-all.js<%=jsVersion%>"></script>
      <!-- Set a local "blank" image file; default is a URL to extjs.com -->
      <script type='text/javascript'>
        Ext.BLANK_IMAGE_URL = '/javaScripts/extjs/resources/images/genboree/s.gif';
      </script>

      <link rel="stylesheet" href="/javaScripts/ext-2.2/resources/css/window.css<%=jsVersion%>" type="text/css">
      <link rel="stylesheet" href="/javaScripts/ext-2.2/resources/css/dialog.css<%=jsVersion%>" type="text/css">
      <link rel="stylesheet" href="/javaScripts/ext-2.2/resources/css/panel.css<%=jsVersion%>" type="text/css">
      <link rel="stylesheet" href="/javaScripts/ext-2.2/resources/css/core.css<%=jsVersion%>" type="text/css">



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
