<%@ page import="javax.servlet.http.*, org.genboree.dbaccess.*,
	  java.sql.*, java.util.*, java.io.*,
    org.genboree.util.*, org.genboree.upload.*, org.genboree.downloader.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%
  boolean sendFile = false ;
  String submittedDownload = null ;
  String refSeqId = null ;
  String refseqName = null ;
  String entryPointId = null ;
  String from = null ;
  String to = null ;
  String display = null ;
  String filter = null ;
  String isPublic = null ;
  boolean need_choice = false ;
  boolean need_upload = false ;
  String[] trackNames = null ;

  isPublic = (String) mys.getAttribute( "username" ) ;

  if( isPublic != null && isPublic.equals("Public") )
  {
    isPublic = "&isPublic=YES" ;
  }
  else
  {
    isPublic = "" ;
  }

  refSeqId = (String) mys.getAttribute( "downloadEditRefSeqId" ) ;
  refseqName = (String) mys.getAttribute( "downloadRefseqName" ) ;
  if(refSeqId == null)
  {
    refSeqId = SessionManager.getSessionDatabaseId(mys) ;
    refseqName = SessionManager.findRefSeqName (refSeqId, db) ;
  }

  if( refseqName == null )
  {
    refseqName = "" ;
  }

  entryPointId = (String) mys.getAttribute( "downloadEditEP" ) ;
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

  if( request.getParameter("btnBack") != null || refSeqId == null ||
      (entryPointId!=null && (from==null || to==null)) )
  {
    GenboreeUtils.sendRedirect(request,response,  "/java-bin/download.jsp" ) ;
    return ;
  }

  submittedDownload = request.getParameter("btnOk") ;
  if(submittedDownload != null && submittedDownload.equalsIgnoreCase("Download"))
  {
    sendFile = true ;
  }

  Refseq rseq = new Refseq() ;
  rseq.setRefSeqId( refSeqId ) ;
  if( !rseq.fetch(db) )
  {
    GenboreeUtils.sendRedirect(request,response,  "/java-bin/download.jsp" ) ;
    return ;
  }
  if( JSPErrorHandler.checkErrors(request,response, db,mys) )
  {
    return ;
  }
  // Get frefs for this database
  DbFref[] frefs = new DbFref[0] ;
  int totalFrefCount = 0 ;
  HashMap chromLengths = new HashMap() ;
  Connection tConn = null ;
  if( rseq != null )
  {
    String dbName = rseq.getDatabaseName() ;
    if(tConn == null)
    {
      tConn =  db.getConnection(dbName) ;
    }
    // ARJ: Try to get the frefs using the new standard way
    if( frefs == null || frefs.length==0 )
    {
      try
      {
        totalFrefCount = DbFref.countAll(tConn) ;
        if(totalFrefCount <= Constants.GB_MAX_FREF_FOR_DROPLIST)
        {
          frefs = DbFref.fetchAll( tConn ) ;
        }
        // else Too many entrypoints

        // Collect hash of epName=>length for putting on page
        for(int ii = 0; ii < frefs.length; ii++)
        {
          chromLengths.put(frefs[ii].getRefname(), frefs[ii].getRlength()) ;
        }
      }
      catch( Exception ex01 )
      {
        System.err.println("EXCEPTION: tdview.jsp failed to get frefs because:") ;
        ex01.printStackTrace(System.err) ;
      }
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

  if(display != null)
  {
    if(display.equalsIgnoreCase("genomebrowser"))
    {
      filter = "b" ;
    }
    else if(display.equalsIgnoreCase("genome"))
    {
      filter = "g" ;
    }
    else if(display.equalsIgnoreCase("chromosome"))
    {
      filter = "c" ;
    }
    else
    {
      filter = "bgc" ;
    }
  }
  else
  {
    filter = "bgc" ;
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

  boolean bAll = false ;
  String entryPointName = null ;
  if( entryPointId == null )
  {
    entryPointId = "All Entry Points" ;
    bAll = true ;
  }
  else
  {
    entryPointName = entryPointId ;
  }

  if( sendFile )
  {
    String myEntryPointId = null ;
    String myFrom = null ;
    String myTo = null ;
    if(entryPointId != null && !entryPointId.equalsIgnoreCase("All Entry Points"))
    {
      myEntryPointId = entryPointId ;
      myFrom = from ;
      myTo = to ;
    }
    String printTrackNames = (trackNames == null || trackNames.length < 1) ? "trackNames are null": " trackNames are not null" ;

    AnnotationDownloader currentDownload = new AnnotationDownloader(db, genboreeUserId , myEntryPointId, filter, refSeqId, trackNames, myFrom, myTo, false) ;

    String includeOtherSections = request.getParameter("includeOtherSections") ;
    currentDownload.setPrintAnnotationBracket(false) ;
    if(includeOtherSections != null && includeOtherSections != "")
    {
      currentDownload.setPrintAssemblySectionAlso(true) ;
      currentDownload.setPrintAnnotationBracket(true) ;
      currentDownload.printChromosomes(response) ;
    }
    currentDownload.downloadAnnotations(response) ;
    need_upload = true ;
  }
%>

<HTML>
<head>
  <title>Genboree - Download annotation data from <%=Util.htmlQuote(refseqName)%></title>
  <link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
  <meta HTTP-EQUIV='Content-Type' CONTENT='text/html ; charset=iso-8859-1'>
  <script src="/javaScripts/prototype.js<%=jsVersion%>" type="text/javascript"></script>
  <script type="text/javascript" src="/javaScripts/util.js<%=jsVersion%>"></script>
  <script type="text/javascript" src="/javaScripts/commonFunctions.js<%=jsVersion%>"></script>
  <script type="text/javascript" src="/javaScripts/tdview.js<%=jsVersion%>"></script>
  <script type="text/javascript">
  var entryPointId = <%=entryPointName==null ? null : "'" + entryPointName + "'"%> ;
  var chromLengths = $H({
<%
    if(totalFrefCount <= Constants.GB_MAX_FREF_FOR_DROPLIST)
    {
      Iterator iter = chromLengths.keySet().iterator() ;
      while(iter.hasNext())
      {
        String chromosomeName = (String)iter.next();
        String chromosomeSize = (String)chromLengths.get(chromosomeName) ;
        out.print("'" + chromosomeName + "': " + chromosomeSize + (iter.hasNext() ? "," : "")) ;
       }
     }
%>
  });

</script>
</head>
<BODY>

<%@ include file="include/header.incl" %>

<form name="gettrk" id="gettrk" action="tdview.jsp" method="post" onsubmit="return validate(this) ;">
<input type="button" value="&laquo; Download More" name="btnBack" id="btnBack" class="btn" onclick="window.location='/java-bin/download.jsp';">
<input type="button" value="Close Window" onClick="window.close()" class="btn">
<br>
<table cellpadding="4" cellspacing="2" border="0" width="100%">
<tbody>
	<tr>
	  <td align=right class="form_body"><b>REFERENCE SEQUENCE:&nbsp;</b></td>
	  <td class="form_body">&nbsp;<%=Util.htmlQuote(refseqName)%></td>
	  <td align="right" class="form_body"><b>FROM:&nbsp;</b></td>
	  <td class="form_body">
<%
      if( need_choice && !bAll )
      {
%>
  		  <input type='text' id='from' name='from' value='<%=from==null ? "" : Util.htmlQuote(from) %>' class="txt">
<%
      }
      else
      {
%>
  		  <%=Util.htmlQuote(from)%>
  		  <input type='hidden' id='from' name='from' value='<%=Util.htmlQuote(from) %>'>
        <%= bAll ? "N/A" : "" %>
<%
      }
%>
		</td>
	</tr>
	<tr>
	  <td align="right" class="form_body"><b>ENTRY POINT:&nbsp;</b></td>
	  <td class="form_body">&nbsp;<%=Util.htmlQuote(entryPointId)%></td>
	  <td align="right" class="form_body"><b>TO:&nbsp;</b></td>
	  <td class="form_body">
<%
      if( need_choice && !bAll )
      {
%>
  	  <input type='text' id='to' name='to' value='<%=to==null ? "" : Util.htmlQuote(to)%>' class="txt">
<%
      }
      else
      {
%>
  		  <%=Util.htmlQuote(to)%>
  		  <input type='hidden' id='to' name='to' value='<%= Util.htmlQuote(to) %>'>
        <%= bAll ? "N/A" : "" %>
<%
      }
%>
		</td>
  </tr>
  <tr>
    <td style="text-align: center; white-space: nowrap;" class="form_body" colspan="4">
      <b>Download Corresponding Chromosome/Entrypoint &amp; Assembly Sections?</b>
      &nbsp;
      <input id="includeOtherSections" name="includeOtherSections" value="true" type="checkbox" style="padding:0px; margin: 0px;">
    </td>
  </tr>
</tbody>
</table>
<input type='submit' name='btnOk' value='Download' style='width:120' class="btn">
<table border="0" cellpadding="4" width="100%">
<tbody>
  <tr>
    <td class="form_body">
      <div style="float: left; width: 74%;">
        <b>Select Annotation Tracks to Download in LFF Format:</b>
      </div>
      <div style="float:right; width: 24%; white-space:nowrap;">
        <input type="button" class="btn" value="Select All" onClick="checkAll()">
        <input type="button" class="btn" value="Clear All" onClick="clearAll()">
      </div>
    </td>
  </tr>
<%
  if( need_choice )
  {
%>
  <tr>
    <td class="form_body">
<%
	for(int i=0 ; i<trackNames.length ; i++ )
	{
%>
    <input type='checkbox' name='trkId' value='<%=Util.urlEncode(trackNames[i])%>' checked>
    <%=Util.htmlQuote( trackNames[i] )%><br>
<%
	}
%>
    </td>
  </tr>
<%
  }
%>

<%
  if( need_upload )
  {
%>
    <tr>
      <td class="form_body">
<%
        for(int i=0 ; i<trackNames.length ; i++ )
        {
%>
          &nbsp;&nbsp;&nbsp;<%=Util.htmlQuote( trackNames[i] )%><br>
<%
        }
%>
      </td>
    </tr>
<%
  }
%>
  <tr>
    <td class="form_body">
      <div style="float: left; width: 74%;">
        &nbsp;
      </div>
      <div style="float:right; width: 24%; white-space:nowrap;">
        <input type="button" class="btn" value="Select All" onClick="checkAll()">
        <input type="button" class="btn" value="Clear All" onClick="clearAll()">
      </div>
    </td>
  </tr>
</tbody>
</table>
<input type='submit' name='btnOk' value='Download' style='width:120' class="btn">

</form>
<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
