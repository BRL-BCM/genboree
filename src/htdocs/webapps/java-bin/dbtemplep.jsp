<%@ page import="javax.servlet.http.*, org.genboree.dbaccess.*, org.genboree.util.*, org.genboree.upload.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/common.incl" %>
<%
    db.setDefaultDbName( "genboree_Main" );
	int i;
	
	Gdatabase gdb = (Gdatabase) mys.getAttribute( "editGdatabase" );
	if( gdb == null )
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/dbtemplmgr.jsp" );
		return;
	}

	String editFepId = request.getParameter("fepId");
	if( editFepId == null ) editFepId = (String) mys.getAttribute( "editFepId" );
	if( editFepId == null || (request.getParameter("btnNew") != null) ) editFepId = "#";

	boolean need_update = request.getParameter("btnUpdate") != null;
	boolean need_delete = request.getParameter("btnDelete") != null;

	Fentrypoint fep = null;
	Fentrypoint[] feps = (Fentrypoint []) mys.getAttribute( "fentrypoints" );
	Ftype[] fts = (Ftype []) mys.getAttribute( "ftypes" );
	if( feps == null || fts == null ) need_update = need_delete = false;
	
	if( feps != null )
	{
		for( i=0; i<feps.length; i++ ) if( feps[i].getId().equals(editFepId) )
			fep = feps[i];
	}
	if( fep == null )
	{
		fep = new Fentrypoint();
		editFepId = "#";
		fep.setGdatabase( gdb );
	}
	
	Fdata fd = fep.getFdata();

	if( need_update )
	{
		fep.setName( request.getParameter("fepName") );
		fep.setDescription( request.getParameter("fepDescr") );
		fd.setStop( Util.decodeNumber(request.getParameter("fepLen")) );
		String ftype_id = request.getParameter( "ftypeId" );
		fd.setFtype_id( ftype_id );
		if( editFepId.equals("#") )
		{
			fd.setStart( 1 );
			fd.setPhase( "0" );
			fd.setScore( "0" );
			fd.setStrand( "+" );
			fd.setUpload_id( "0" );
			fep.setParent_id( "0" );
			fep.insert( db );
			if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
			editFepId = fep.getId();
		}
		else
		{
			fep.update( db );
			if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
		}
		feps = null;
		fts = null;
		fep = null;
	}
	
	if( need_delete )
	{
		fep.delete( db );
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
		editFepId = "#";
		feps = null;
		fts = null;
		fep = null;
	}

	if( feps == null || fts == null )
	{
		feps = gdb.fetchEntrypoints( db );
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
		if( feps == null ) feps = new Fentrypoint[0];
		fts = gdb.fetchFtypes( db );
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
		if( fts == null ) fts = new Ftype[0];
	}

	for( i=0; i<feps.length; i++ ) if( feps[i].getId().equals(editFepId) )
		fep = feps[i];
	if( fep == null )
	{
		fep = new Fentrypoint();
		editFepId = "#";
		fep.setGdatabase( gdb );
	}
	fd = fep.getFdata();
	String editFtypeId = fd.getFtype_id();
	
	mys.setAttribute( "editFepId", editFepId );
	mys.setAttribute( "fentrypoints", feps );
	mys.setAttribute( "ftypes", fts );
	
	String problem = (String) mys.getAttribute( "problemEp" );
	if( problem == null ) problem = "";
	mys.removeAttribute( "problemEp" );
%>

<HTML>
<head>
<title>Genboree - Database Template Entry Points Manager</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY bgcolor="#DDE0FF">

<%@ include file="include/header.incl" %>

<center>

<form action="dbtemplep.jsp" onsubmit='return checkForm(this);' method="post">

  <table class='TABLE' cellpadding="0" cellspacing="0" border="0" align="center">
    <tbody>
	<tr><td><a href="dbtemplmgr.jsp">Select another <br>Reference Sequence</a></td><td>
  <select name="fepId" size="8" onchange="this.form.submit()" class="txt" style="width:350">
<% for( i=0; i<feps.length; i++ )
   {
     String myId = feps[i].getId();
     String sel = myId.equals(editFepId) ? " selected" : "";
%>          <option value="<%=myId%>"<%=sel%>><%=feps[i].getName()%></option><%
   } %>
  </select>
  	</td></tr>
	</tbody>
  </table>

  <br>&nbsp;

  <table class='TABLE' cellpadding="2" cellspacing="0" border="1"
    bgcolor="#aac5ff" align="center">
    <tbody>
	  <tr><td colspan=2 bgcolor=white align=center>Entry Point</td></tr>
      <tr><td>
        &nbsp;Name:&nbsp;&nbsp;                           
      </td><td>
        <input type=text name="fepName" value="<%=Util.htmlQuote(fep.getName())%>"
		  style="width: 400">&nbsp;&nbsp;
      </td></tr>
      <tr><td>
        &nbsp;Description:&nbsp;&nbsp;                           
      </td><td>
        <input type=text name="fepDescr" value="<%=Util.htmlQuote(fep.getDescription())%>"
		  style="width: 400">&nbsp;&nbsp;
      </td></tr>
      <tr><td>
        &nbsp;Length:&nbsp;&nbsp;                           
      </td><td>
        <input type=text name="fepLen" value="<%=""+fd.getStop()%>"
		  style="width: 400">&nbsp;&nbsp;
      </td></tr>
      <tr><td>
        &nbsp;Type:&nbsp;&nbsp;                           
      </td><td>
  <select name="ftypeId"  class="txt" style="width:400">
<% for( i=0; i<fts.length; i++ )
   {
     String myId = fts[i].getId();
     String sel = myId.equals(editFtypeId) ? " selected" : "";
%>          <option value="<%=myId%>"<%=sel%>><%=fts[i].getScreenName()%></option><%
   } %>
  </select>
      </td></tr>
	  <tr><td>&nbsp;</td><td>Category/Type/Subtype</td><tr>
	</tbody>
  </table>

<br>
<% if( editFepId.equals("#") ) { %>
<input type=submit name="btnUpdate" onClick=setCmd(this.name); style="width:100" value="Create">
<% } else { %>
<input type=submit name="btnUpdate" onClick=setCmd(this.name); style="width:100"
  value="Update">&nbsp;&nbsp;<input
  type=submit name="btnDelete" onClick=setCmd(this.name); style="width:100"
  value="Delete">&nbsp;&nbsp;<input
  type=submit name="btnNew" onClick=setCmd(this.name); style="width:100"
  value="New">
<% } %>

</form>

<br>
<form action="dbtemplupld.jsp" method="post" enctype="multipart/form-data">

  <table class='TABLE' cellpadding="2" cellspacing="0" border="1"
    bgcolor="#aac5ff" align="center">
    <tbody>
	  <tr><td colspan=2 bgcolor=white>Please specify upload file or paste tab-delimited data into the box below.</td></tr>
      <tr><td colspan=2><input type=checkbox name="delete_all" value="1">Delete all existing entrypoints</input><td></tr>
	  <tr><td>
		<input type="file" name="entries_file" class="txt" size="40"><br>
      </td><td>
	    <input type=submit name="btnUpload" style="width:100" value="Submit">
      </td></tr>
	  <tr><td colspan=2>
		<textarea rows="10" wrap=off name="entries_data"
		 style="width:540; font-size:15"><%=Util.htmlQuote(problem)%></textarea>
	  </td></tr>
	</tbody>
  </table>

</form>

<script language='javascript'>
var cmd = "";
function setCmd(val) { cmd=val; }

function stripNumber(s)
{
	var t = "";
	var i;
	for( i=0; i<s.length; i++ )
	{
		var c = s.substring(i,i+1);
		if( (c >= "0") && (c <= "9") ) { t = t + c; }
	}
	if( isNaN(parseInt(t)) ) return -1;
	return parseInt(t);
}

function checkForm(f)
{
	if( cmd=="btnUpdate" )
	{
		if( f.fepName.value == "" )
		{
			alert( "Entry point name must not be empty." );
			f.fepName.focus();
			return false;
		}
		var l = stripNumber( ""+f.fepLen.value );
		if( l <= 1 || l > 2147483647 )
		{
			alert( "Length must be greater than 1 and less than 2147483648" );
			f.fepLen.focus();
			return false;
		}
	}
	return true;
}
</script>

</center>

<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
