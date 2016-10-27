<%@ page import="javax.servlet.http.*, java.net.*, java.sql.*,
  java.util.*, org.genboree.dbaccess.*, org.genboree.util.Util,
                 org.genboree.manager.tracks.Utility,
                 org.genboree.message.GenboreeMessage,
                 org.genboree.manager.link.LinkCreator,
                 org.genboree.manager.link.LinkUpdator,
                 org.genboree.util.*, org.genboree.upload.*, org.genboree.downloader.*,
                 java.sql.*, java.util.*, java.io.*,
                 java.io.IOException,
                 org.genboree.manager.tracks.TrackManagerInfo,
                 org.genboree.manager.link.LinkManagerHelper" %>

<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/group.incl" %>
<%
  boolean sendFile = false ;
  String submittedDownload = null ;
  String refSeqId = null ;
  String entryPointId = null ;
  String from = null ;
  String to = null ;
  String landmark = null;
  String display = null ;
  String filter = null ;
  String fileFormat = null ;
  boolean need_choice = false ;
  String[] trackNames = null ;
  String[] epNames = null ;
  boolean showPage = true ;

  // values may be POSTed from other locations so capture those values first.
  refSeqId = request.getParameter( "refSeqId" ) ;
  entryPointId = request.getParameter( "entryPointId" ) ;
  from = request.getParameter( "from" ) ;
  to = request.getParameter( "to" ) ;
  landmark = request.getParameter( "landmark" ) ;
  fileFormat = request.getParameter( "fileFormat" ) ;

  entryPointId = (String) request.getParameter("entryPointId" ) ;
  if(entryPointId == null)
  {
    entryPointId = (String) mys.getAttribute( "downloadEditEP" ) ;
  }
  if(entryPointId == null)
  {
    entryPointId = (String) mys.getAttribute( "editEP" ) ;
  }
  from = request.getParameter("from") ;
  if( from==null )
  {
    from = (String) mys.getAttribute( "downloadDnld_from" ) ;
  }
  if(from == null)
  {
    from = (String) mys.getAttribute( "dnld_from" ) ;
  }

  to = request.getParameter("to") ;
  if( to==null )
  {
    to = (String) mys.getAttribute( "downloadDnld_to" ) ;
  }
  if( to==null )
  {
    to = (String) mys.getAttribute( "dnld_to" ) ;
  }

  display = (String) mys.getAttribute( "display" ) ;

  if( entryPointId!=null && entryPointId.equals("--all--") )
  {
    entryPointId = null ;
  }
  if( entryPointId == null )
  {
    from = to = null ;
  }

  submittedDownload = request.getParameter("btnOk") ;
  if(submittedDownload != null && submittedDownload.equalsIgnoreCase("Download"))
  {
    sendFile = true ;
  }

  Refseq rseq = new Refseq() ;
  rseq.setRefSeqId( refSeqId ) ;
  if( JSPErrorHandler.checkErrors(request,response, db,mys) )
  {
    return ;
  }


  epNames = request.getParameterValues( "epId" ) ;
  if( epNames != null )
  {
    for(int i=0 ; i<epNames.length ; i++ )
    {
      epNames [i] = Util.urlDecode( epNames [i] ) ;
    }
  }

  trackNames = request.getParameterValues( "trkId" ) ;
  if( trackNames != null )
  {
    for(int i=0 ; i<trackNames.length ; i++ )
    {
      trackNames[i] = Util.urlDecode( trackNames[i] ) ;
    }
    Arrays.sort( trackNames ) ;
  }

  int genboreeUserId = Util.parseInt( myself.getUserId(), -1 );
  if( trackNames == null && !sendFile)
  {
    need_choice = true ;
    DbFtype[] trks = rseq.fetchTracks( db, entryPointId, genboreeUserId ) ;
    if( JSPErrorHandler.checkErrors(request,response, db,mys) )
    {
      return ;
    }
    trackNames = new String[ trks.length ] ;
    for(int i=0 ; i<trks.length ; i++ )
    {
      trackNames[i] = trks[i].getFmethod().trim() + ":" + trks[i].getFsource().trim() ;
    }
    Arrays.sort( trackNames ) ;
  }

  String entryPointName = null ;
  if( entryPointId == null )
  {
    entryPointId = "All Entry Points" ;
  }
  else
  {
    entryPointName = entryPointId ;
  }


  // RUBY preperation
  // Key variables:
  String urlStr = null ;
  boolean doHtmlStripping = true ;
  String contentUrl = null ; // String to store the entire content of an URL using getContentOfUrl(urlStr )
  String currPageURI = request.getRequestURI() ;
  String groupAllowed = null ;
  // REBUILD the request params we will pass to RHTML side (via a POST)
  Map paramMap = request.getParameterMap() ; // "key"=>String[]
  StringBuffer postContentBuff = new StringBuffer() ;
  // 1.a Send the userId, whether on form or not
  postContentBuff.append("userId=").append(Util.urlEncode(userInfo[2])) ;
  // Need to send the group_id when it's not post'd
  postContentBuff.append("&group_id=").append(Util.urlEncode(groupId)) ;
  postContentBuff.append("&rseq_id=").append(Util.urlEncode(rseq_id)) ;

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
  urlStr = myBase + "/genboree/download.rhtml" ;
  HashMap hdrsMap = new HashMap() ;
  // Update group/database if correct X-HEADERS are found:
  GenboreeUtils.updateSessionFromXHeaders(hdrsMap, mys) ;


  // After form is POSTed, download the file
  if( sendFile )
  {
    
    String fileName = GenboreeUtils.getFileName(refSeqId) + '.' + fileFormat ;
    PrintWriter printerOutStream = null;
    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );
    response.setContentType( "text/plain" );
    response.setHeader( "Content-Disposition", "attachment; filename=\""+ fileName +"\"" );
    response.setHeader("Accept-Ranges", "bytes");
    response.addHeader("status", "200");
    try
    {
      if(printerOutStream == null && response != null)
      {
        printerOutStream = response.getWriter() ;
      }
    }
    catch(IOException e)
    {
        System.err.println("Fail getting the printerOutStream");
        System.err.flush();
        return;
    }
    GenboreeUtils.echoPostToURL(urlStr, postContentStr, hdrsMap, mys, printerOutStream) ;


    printerOutStream.flush();
    printerOutStream.close();
    printerOutStream = null ;
    showPage = false ;
    

  }

  if(showPage) {
%>

<HTML>
<head>
  <meta HTTP-EQUIV='Content-Type' CONTENT='text/html ; charset=iso-8859-1'>
  <title>Genboree - Download annotation data</title>
  <link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
  <link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">
  <script type="text/javascript" src="/javaScripts/util.js<%=jsVersion%>"></script>
  <script type="text/javascript" src="/javaScripts/commonFunctions.js<%=jsVersion%>"></script>
  <script type="text/javascript" src="/javaScripts/download.js<%=jsVersion%>"></script>
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
</head>
<BODY>

<%@ include file="include/sessionGrp.incl"%>
<%@ include file="include/header.incl" %>
<%@ include file="include/navbar.incl" %>

<form action="download.jsp" method="POST">

<table border="0" cellpadding="4" cellspacing="2" width="100%">
<tr>
<%@ include file="include/groupbar.incl" %>
</tr>
<tr>
<%@ include file="include/databaseBar.incl" %>
</tr>
</table>

</form>
<%
  // Do as a POST
  contentUrl = GenboreeUtils.postToURL(urlStr, postContentStr, doHtmlStripping, hdrsMap, mys ) ;
  out.write(contentUrl) ;
%>


<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
<% } // end showPage %>
