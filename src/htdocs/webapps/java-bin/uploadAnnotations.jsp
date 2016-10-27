<%@ page import="javax.servlet.http.*, org.genboree.dbaccess.*,
      org.genboree.util.*, org.genboree.upload.*,
      java.util.*, java.util.zip.*, java.io.* " %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%
    db.setDefaultDbName( "genboree_Main" );
	int i;
	
	Gdatabase gdb = (Gdatabase) mys.getAttribute( "annotationsDb" );
	if( gdb == null )
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/dbcreat.jsp" );
		return;
	}

	long totalBytes = request.getContentLength();
    mys.setAttribute( "totalBytes", new Long(totalBytes) );
    HttpPostInputStream hpIn = new HttpPostInputStream( request.getInputStream(), mys );
	
	TDReceiver tdr = null;
	AnnotationConsumer ac = null;
	String s = null;
	
    while( hpIn.nextPart() )
    {
      String cn = hpIn.getPartAttrib( "name" );
      String fn = hpIn.getPartAttrib( "filename" );
      String ct = hpIn.getPartAttrib( "Content-Type" );
	  if( !cn.startsWith("annotation_") ) continue;
	  
	  if( tdr == null )
	  {
		tdr = new TDReceiver();
		ac = new AnnotationConsumer( gdb, db );
		tdr.setSection( "[annotations]" );
		tdr.setConsumer( ac );
		String upload_id = (String) mys.getAttribute( "upload_id" );
		if( upload_id == null )
		{
			upload_id = gdb.createUpload( db, "0" );
			if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
		}
		if( upload_id == null ) upload_id = "0";
		ac.setUpload_id( upload_id );
		mys.setAttribute( "upload_id", upload_id );
	  }
	  
      if( ct.startsWith("application/x-zip") )
      {
         ZipInputStream zin = new ZipInputStream( hpIn );
         ZipEntry zen;
         while( (zen=zin.getNextEntry()) != null )
         {
           BufferedReader br = new BufferedReader( new InputStreamReader(zin) );
           while( (s=br.readLine()) != null ) tdr.addLine( s );
         }
      }
      else if( ct.startsWith("application/x-gzip") )
      {
        GZIPInputStream gzin = new GZIPInputStream( hpIn );
        BufferedReader br = new BufferedReader( new InputStreamReader(gzin) );
        while( (s=br.readLine()) != null ) tdr.addLine( s );
      }
      else
      {
        BufferedReader br = new BufferedReader( new InputStreamReader(hpIn) );
        while( (s=br.readLine()) != null ) tdr.addLine( s );
      }

	  ac.flush();
	  if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
	  
    }

	String problem = "";
	
	String log = db.getLog();
%>

<HTML>
<head>
<title>Genboree - Upload Annotations</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY bgcolor="#DDE0FF">

<%@ include file="include/header.incl" %>
<% if(log != null) { %>
<PRE>
<%=log%>
</PRE>
<% } %>
<center>

<form action="uploadAnnotations.jsp" method="post" enctype="multipart/form-data">

  <table class='TABLE' cellpadding="2" cellspacing="0" border="1"
    bgcolor="#aac5ff" align="center">
    <tbody>
	  <tr><td bgcolor=white>Please specify LFF file or paste tab-delimited data into the box below.</td></tr>
	  <tr><td>
		<input type="file" name="annotation_file" class="txt" size="60"><br>
      </td></tr>
	  <tr><td>
		<textarea rows="10" wrap=off name="annotation_data"
		 style="width:540; font-size:15"><%=Util.htmlQuote(problem)%></textarea>
	  </td></tr>
	</tbody>
  </table>

	<br>
	<input type=submit name="btnUpload" style="width:100" value="Submit">

</form>

</center>

<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
