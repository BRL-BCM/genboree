<%@ page import="javax.servlet.http.*, org.genboree.dbaccess.*, org.genboree.util.*, org.genboree.upload.*, java.util.*, java.util.zip.*, java.io.* " %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/common.incl" %>
<%!
	static String[] epMeta = { "id", "class", "length", "description" };
%>
<%
    db.setDefaultDbName( "genboree_Main" );
	
	long totalBytes = request.getContentLength();
    mys.setAttribute( "totalBytes", new Long(totalBytes) );
    HttpPostInputStream hpIn = new HttpPostInputStream( request.getInputStream(), mys );
	TDReceiver tdr = new TDReceiver();

	Gdatabase gdb = (Gdatabase) mys.getAttribute( "editGdatabase" );
	Ftype[] fts = (Ftype []) mys.getAttribute( "ftypes" );
	if( gdb == null || fts == null )
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/dbtemplmgr.jsp" );
		return;
	}
	
	int i, j;
	
    String s = null;
	boolean need_delete = false;

    while( hpIn.nextPart() )
    {
      String cn = hpIn.getPartAttrib( "name" );
      String fn = hpIn.getPartAttrib( "filename" );
      String ct = hpIn.getPartAttrib( "Content-Type" );
	  if( cn.equals("delete_all") ) need_delete = true;
	  if( !cn.startsWith("entries_") ) continue;
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
    }
	
	Fentrypoint[] feps = (Fentrypoint []) mys.getAttribute( "fentrypoints" );
	if( feps != null && need_delete )
	{
		for( i=0; i<feps.length; i++ ) feps[i].delete(db);
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
	}
	feps = null;
	
	tdr.setSection( "[reference_points]" );
	String[] md = tdr.getMeta();
	if( md == null ) md = epMeta;
	else
	{
		for( i=0; i<md.length; i++ )
		{
			if( md[i].equalsIgnoreCase("name") ) md[i] = "id";
			else if( md[i].equalsIgnoreCase("type") ) md[i] = "class";
		}
	}
	tdr.setMeta( md );
	
	Vector ok = new Vector();
	Vector err = new Vector();
	
	int nameIdx = tdr.keyToIndex( "id" );
	int typeIdx = tdr.keyToIndex( "class" );
	int lenIdx = tdr.keyToIndex( "length" );
	int descrIdx = tdr.keyToIndex( "description" );
	
	String problem = "";
	
	for( i=0; i<tdr.getLength(); i++ )
	{
		Fentrypoint fep = new Fentrypoint();
		fep.setGdatabase( gdb );
		Fdata fd = fep.getFdata();
		fd.setStart( 1 );
		fd.setPhase( "0" );
		fd.setScore( "0" );
		fd.setStrand( "+" );
		fd.setUpload_id( "0" );
		fep.setParent_id( "0" );
		String fepName = tdr.getValueAt( i, nameIdx );
		fep.setName( fepName );
		String fepLenS = tdr.getValueAt(i, lenIdx);
		int fepLen = Util.decodeNumber( fepLenS );
		fd.setStop( fepLen );
		String fepDescr = tdr.getValueAt( i, descrIdx );
		String fepType = tdr.getValueAt( i, typeIdx );
		if( fepType == null ) fepType = "?";
		if( Util.isEmpty(fepDescr) ) fepDescr = fepType;
		fep.setDescription( fepDescr );
		
		String ftype_id = null;
		for( j=0; j<fts.length; j++ )
			if( fts[j].getFcategory_name().equalsIgnoreCase(fepType) )
		{
			ftype_id = fts[j].getId();
			break;
		}
		
		String errMsg = null;
		if( Util.isEmpty(fepName) ) errMsg = "Missing name";
		else if( ftype_id == null ) errMsg = "Unknown or missing type ("+fepType+")";
		else if( fepLen <= 1 ) errMsg = "Length out of range ("+fepLenS+")";
		
		if( errMsg != null )
		{
			err.addElement( errMsg );
			err.addElement( fep );
			fepName = fep.getName();
			if( Util.isEmpty(fepName) ) fepName = "?";
			if( Util.isEmpty(fepLenS) ) fepLenS = "0";
			problem = problem + fepName + "\t" + fepType + "\t" + fepLenS + "\t" +
				fepDescr + "\n";
		}
		else
		{
			fd.setFtype_id( ftype_id );
			fep.insert( db );
			if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
			ok.addElement( fep );
		}
	}
	
	if( !Util.isEmpty(problem) )
	{
		problem = "[reference_points]\n#id\tclass\tlength\tdescription\n" + problem;
		mys.setAttribute( "problemEp", problem );
	}

	mys.removeAttribute( "editFepId" );
	mys.removeAttribute( "fentrypoints" );
	mys.removeAttribute( "editFepId" );

%>

<HTML>
<head>
<title>Genboree - Upload Entry Points - Summary</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>

<BODY bgcolor="#DDE0FF">

<%@ include file="include/header.incl" %>

The following <%=ok.size()%> entrypoint(s) were successfully created:<br><br>&nbsp;

  <table class='TABLE' cellpadding="4" cellspacing="0" border="1" align="center">
    <tbody>
	<tr><td bgcolor="#aac5ff">Name</td><td bgcolor="#aac5ff">Length</td>
	<td bgcolor="#aac5ff">Description</td></tr>
<%
	for( i=0; i<ok.size(); i++ )
	{
		Fentrypoint fep = (Fentrypoint) ok.elementAt(i);
%>	<tr><td><%=fep.getName()%></td><td><%=""+fep.getFdata().getStop()%></td>
	<td><%=fep.getDescription()%>&nbsp;</td></tr>
<%	
	}
%>	
	</tbody>
  </table>

<% if( err.size() > 0 ) { %>
<br><font color=red><%=err.size()/2%> entries were not added due to parsing errors:</font><br>

  <table class='TABLE' cellpadding="4" cellspacing="0" border="1" align="center">
    <tbody>
	<tr><td bgcolor="#aac5ff">Name</td><td bgcolor="#aac5ff">Length</td>
	<td bgcolor="#aac5ff">Description</td><td bgcolor="#aac5ff">Reason</td></tr>
<%
	for( i=0; i<err.size(); i+=2 )
	{
		String errMsg = (String) err.elementAt(i);
		Fentrypoint fep = (Fentrypoint) err.elementAt(i+1);
%>	<tr><td><%=fep.getName()%></td><td><%=""+fep.getFdata().getStop()%></td>
	<td><%=fep.getDescription()%>&nbsp;</td><td><%=errMsg%></td></tr>
<%	
	}
%>	
	</tbody>
  </table>

<% } %>

<center>
<form action="dbtemplep.jsp" method="post">
<input type="submit" name="btnOk" value="OK" class="btn" style="width:100">
</form>
</center>

<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
