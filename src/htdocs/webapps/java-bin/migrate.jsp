<%@ page import="javax.servlet.http.*, org.genboree.dbaccess.*,
	org.genboree.util.*, org.genboree.upload.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/common.incl" %>
<%@ include file="include/userinfo.incl" %>
<%!
%>
<%
    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );
	if( !userInfo[0].equals("admin") )
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/defaultGbrowser.jsp" );
		return;
	}

	int i;
	Refseq[] rseqs = Refseq.fetchAll( db, null );

	String refSeqId = request.getParameter( "refSeqId" );
	if( refSeqId == null ) refSeqId = "#";
	
	String stat = "";
	
	Refseq rseq = null;
	for( i=0; i<rseqs.length; i++ )
	{
		String myId = rseqs[i].getRefSeqId();
		if( myId.equals(refSeqId) ) rseq = rseqs[i];
	}
	if( rseq == null )
	{
		if( rseqs.length > 0 ) rseq = rseqs[0];
		else
		{
			rseq = new Refseq();
			rseq.setDatabaseName( "#####" );
		}
	}
	else if( request.getParameter("cmdMigrate") != null )
	{
    int userId = Util.parseInt(myself.getUserId(), -1);
    GenboreeUpload[] gbUplds = GenboreeUpload.fetchAll( db, rseq.getRefSeqId(), null, userId );
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
		for( i=0; i<gbUplds.length; i++ )
		{
			String dbName = gbUplds[i].getDatabaseName();
			boolean st = Migrator.migrateFdataTables( db, dbName );
			if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
			stat = stat + dbName + " : " + (st ? "OK" : "Failed");
		}
		Migrator.setFdataSort( db, rseq.getDatabaseName(), gbUplds );		
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
	}
	else if( request.getParameter("cmdStyles") != null )
	{
		Migrator.setUserStyleColor( db );
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
	}
	
%>

<HTML>
<head>
<title>Genboree - Migrate</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY>

<%@ include file="include/header.incl" %>

<form action="migrate.jsp" method="post">

<table border="0" cellspacing="0" cellpadding="2">
<tr>
	<td class="form_header"><b>Reference Sequence</b></td>
	<td class="form_body">

		<select name="refSeqId" id="refSeqId"
		onchange='this.form.submit()'
		 class="txt" style="width:300">
<%
	for( i=0; i<rseqs.length; i++ )
	{
		String myId = rseqs[i].getRefSeqId();
		String sel = myId.equals(refSeqId) ? " selected" : "";
%><option value="<%=myId%>"<%=sel%>><%=rseqs[i].getRefseqName()%></option>
<%
	}
%>
		</select>
	</td>
	<td class="form_body">
		<input type="submit" name="cmdMigrate" id="cmdMigrate"
		class="btn"
		value="Migrate">
	</td>		
</tr>
<tr>
  <td class="form_body" colspan="2">
		<input type="submit" name="cmdStyles" id="cmdStyles"
		class="btn"
		value="Migrate User Syles (all databases)">
  </td>
</tr>
</table>

</form>

<br><%=stat%>

<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
