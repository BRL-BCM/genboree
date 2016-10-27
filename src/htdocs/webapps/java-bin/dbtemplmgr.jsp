<%@ page import="javax.servlet.http.*, org.genboree.dbaccess.*, org.genboree.util.*, org.genboree.upload.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/common.incl" %>
<%
    db.setDefaultDbName( "genboree_Main" );
	int i;
	
	String editDbId = request.getParameter("dbId");
	if( editDbId == null ) editDbId = (String) mys.getAttribute( "editDbId" );
	if( editDbId == null ) editDbId = "#";
	
	boolean need_update = request.getParameter("btnUpdate") != null;
	boolean need_delete = request.getParameter("btnDelete") != null;
	boolean need_entry = request.getParameter("btnEntry") != null;
	
	Gdatabase[] gdbs = (Gdatabase []) mys.getAttribute( "gdatabases" );
	Gdatabase gdb = null;
	if( gdbs == null )
	{
		editDbId = "#";
		need_delete = need_update = false;
	}
	else
	{
		for( i=0; i<gdbs.length; i++ ) if( gdbs[i].getId().equals(editDbId) )
			gdb = gdbs[i];
		if( gdb == null ) gdb = new Gdatabase();
	}
	
	if( need_update )
	{
		gdb.setName( request.getParameter("dbName") );
		gdb.setDescription( request.getParameter("dbDescr") );
		Frefseq frs = gdb.getFrefseq();
		frs.setSpecies( request.getParameter("rsSpecies") );
		frs.setVersion( request.getParameter("rsVer") );
		frs.setDescription( request.getParameter("rsDescr") );
		frs.setType( "public" );
		if( editDbId.equals("#") )
		{
			gdb.setHostname( "localhost" );
			gdb.setType( "reference_sequence" );
			gdb.insert( db, true );
			if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
			gdb.createFdataSet( db, false );
			if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
			frs.insert( db );
			if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
			need_entry = true;
		}
		else
		{
			gdb.update( db );
			if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
			frs.update( db );
			if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
		}
		editDbId = gdb.getId();
		gdbs = null;
		gdb = null;
	}
	
	if( need_delete )
	{
		gdb.delete( db );
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
		editDbId = "#";
		gdbs = null;
		gdb = null;
	}
	
	if( gdbs == null )
	{
		gdbs = Gdatabase.fetchAll( db, "reference_sequence" );
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
		if( gdbs == null ) gdbs = new Gdatabase[0];
		for( i=0; i<gdbs.length; i++ ) if( gdbs[i].getId().equals(editDbId) )
			gdb = gdbs[i];
	}
	if( gdb == null )
	{
		gdb = new Gdatabase();
		editDbId = "#";
		need_entry = false;
	}
	
	mys.setAttribute( "editDbId", editDbId );
	mys.setAttribute( "gdatabases", gdbs );
	
	if( need_entry )
	{
		gdb.fetchMeta( db );
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
		mys.setAttribute( "editGdatabase", gdb );
		mys.removeAttribute( "fentrypoints" );
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/dbtemplep.jsp" );
		return;
	}
%>

<HTML>
<head>
<title>Genboree - Database Template Manager</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY bgcolor="#DDE0FF">

<%@ include file="include/header.incl" %>

<center>

<form action="dbtemplmgr.jsp" onsubmit='return checkForm(this);' method="post">

  <select name="dbId" onchange="this.form.submit()" style="width:350">
    <option value="#">&lt;&lt;&lt;&lt;== New Database ==&gt;&gt;&gt;&gt;</option>
<% for( i=0; i<gdbs.length; i++ )
   {
     String myId = gdbs[i].getId();
     String sel = myId.equals(editDbId) ? " selected" : "";
%>          <option value="<%=myId%>"<%=sel%>><%=gdbs[i].getName()%></option><%
   } %>
  </select>
  <br>&nbsp;

  <table class='TABLE' cellpadding="2" cellspacing="0" border="1"
    bgcolor="#aac5ff" align="center">
    <tbody>
	  <tr><td colspan=2 bgcolor=white align=center>Database</td></tr>
      <tr><td>
        &nbsp;Name:&nbsp;&nbsp;                           
      </td><td>
        <input type=text name="dbName" value="<%=Util.htmlQuote(gdb.getName())%>"
		  style="width: 400">&nbsp;&nbsp;
      </td></tr>
      <tr><td>
        &nbsp;Description:&nbsp;&nbsp;                           
      </td><td>
        <input type=text name="dbDescr" value="<%=Util.htmlQuote(gdb.getDescription())%>"
		  style="width: 400">&nbsp;&nbsp;
      </td></tr>
	</tbody>
  </table>

<br>
	  
  <table class='TABLE' cellpadding="2" cellspacing="0" border="1"
    bgcolor="#aac5ff" align="center">
    <tbody>
	  <tr><td colspan=2 bgcolor=white align=center>Reference Sequence</td></tr>
      <tr><td>
        &nbsp;Species:&nbsp;&nbsp;                           
      </td><td>
        <input type=text name="rsSpecies"
		  value="<%=Util.htmlQuote(gdb.getFrefseq().getSpecies())%>"
		  style="width: 400">&nbsp;&nbsp;
      </td></tr>
      <tr><td>
        &nbsp;Version:&nbsp;&nbsp;                           
      </td><td>
        <input type=text name="rsVer"
		  value="<%=Util.htmlQuote(gdb.getFrefseq().getVersion())%>"
		  style="width: 400">&nbsp;&nbsp;
      </td></tr>
      <tr><td>
        &nbsp;Description:&nbsp;&nbsp;                           
      </td><td>
        <input type=text name="rsDescr"
		  value="<%=Util.htmlQuote(gdb.getFrefseq().getDescription())%>"
		  style="width: 400">&nbsp;&nbsp;
      </td></tr>
	</tbody>
  </table>

<br>
<% if( editDbId.equals("#") ) { %>
<input type=submit name="btnUpdate" onClick=setCmd(this.name); style="width:100" value="Create">
<% } else { %>
<input type=submit name="btnUpdate" onClick=setCmd(this.name); style="width:100"
  value="Update">&nbsp;&nbsp;<input
  type=submit name="btnDelete" onClick=setCmd(this.name); style="width:100"
  value="Delete">&nbsp;&nbsp;<input
  type=submit name="btnEntry" onClick=setCmd(this.name); style="width:150"
  value="Entry Points">
<% } %>

</form>

</center>

<script language='javascript'>
var cmd = "";
function setCmd(val) { cmd=val; }

function checkForm(f)
{
	if( cmd=="btnUpdate" )
	{
		if( f.dbName.value == "" )
		{
			alert( "Database name must not be empty." );
			f.dbName.focus();
			return false;
		}
		if( f.rsSpecies.value == "" )
		{
			alert( "Species name must not be empty." );
			f.rsSpecies.focus();
			return false;
		}
	}
	return true;
}
</script>

<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
