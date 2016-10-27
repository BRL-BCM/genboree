<%@ page import="javax.servlet.http.*, org.genboree.dbaccess.*, org.genboree.util.*, org.genboree.upload.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%
    db.setDefaultDbName( "genboree_Main" );
	int i;

	String editAnnDbId = request.getParameter("annDbId");
	String oldEditAnnDbId = (String) mys.getAttribute( "editAnnDbId" );
	boolean has_changed = false;
	boolean first_time = (editAnnDbId == null);
	if( first_time ) editAnnDbId = oldEditAnnDbId;
	if( oldEditAnnDbId == null || !oldEditAnnDbId.equals(editAnnDbId) )
		has_changed = true;
	if( editAnnDbId == null ) editAnnDbId = "#";

	Gdatabase[] gdbUpl = (Gdatabase []) mys.getAttribute( "gdbUpl" );
	Gdatabase gdb = null;
	boolean is_new = true;
	if( gdbUpl != null )
	{
		for( i=0; i<gdbUpl.length; i++ )
		if( gdbUpl[i].getId().equals(editAnnDbId) )
		{
			is_new = false;
			gdb = gdbUpl[i];
			break;
		}
	}
	
	if( gdb != null && request.getParameter("btnUpload") != null )
	{
		gdb.fetchMeta( db );
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
		mys.setAttribute( "annotationsDb", gdb );
		mys.removeAttribute( "upload_id" );
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/uploadAnnotations.jsp" );
		return;
	}
	
	if( gdb != null && request.getParameter("btnDelete") != null )
	{
		gdb.delete( db );
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
		gdb = null;
		gdbUpl = null;
	}
	
	if( gdb == null )
	{
		gdb = new Gdatabase();
		editAnnDbId = "#";
		is_new = true;
	}
	else if( gdb.getGroupIds() == null )
	{
		gdb.fetchGroupIds( db );
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
	}

	String editTemplDbId = request.getParameter("templDbId");
	if( editTemplDbId == null ) editTemplDbId = (String) mys.getAttribute( "editTemplDbId" );
	if( editTemplDbId == null ) editTemplDbId = "#";

	Gdatabase[] gdbRef = first_time ?
		Gdatabase.fetchAll( db, "reference_sequence" ) :
		(Gdatabase [])mys.getAttribute( "gdbRef" );
	if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
	if( gdbRef == null ) gdbRef = new Gdatabase[0];
	mys.setAttribute( "gdbRef", gdbRef );
	
	Gdatabase tgdb = null;
	for( i=0; i<gdbRef.length; i++ )
	{
		if( i==0 && editTemplDbId.equals("#") )
		{
			tgdb = gdbRef[i];
			editTemplDbId = tgdb.getId();
			break;
		}
		if( gdbRef[i].getId().equals(editTemplDbId) )
		{
			tgdb = gdbRef[i];
			break;
		}
	}

	Frefseq frs = gdb.getFrefseq();
	boolean need_update = request.getParameter("btnUpdate") != null;
	if( need_update )
	{
		gdb.setName( request.getParameter("dbName") );
		gdb.setDescription( request.getParameter("dbDescr") );
		gdb.setGroupIds( request.getParameterValues("group_id") );
		if( is_new && tgdb!=null )
		{
			String pubId = "#";
			for( i=0; i<grps.length; i++ )
				if( grps[i].getGroupName().equalsIgnoreCase("Public") ) pubId = grps[i].getGroupId();
			boolean is_multi = request.getParameter("use_multi") != null;
			Frefseq tfrs = tgdb.getFrefseq();
			frs.setSpecies( tfrs.getSpecies() );
			frs.setVersion( tfrs.getVersion() );
			frs.setDescription( tfrs.getDescription() );
			frs.setType( is_public ? "public" : "private" );

			gdb.setMulti( is_multi );		
			gdb.setHostname( "localhost" );
			gdb.setType( "data_upload" );
		
			gdb.insertByTemplate( db, tgdb );
			if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
		
			editAnnDbId = gdb.getId();
			gdbUpl = null;
		}
		else if( !is_new )
		{
			gdb.update( db );
			if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
			gdbUpl = null;
		}
		gdb.insertGroupIds( db );
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
	}

	if( gdbUpl == null )
	{
		gdbUpl = Gdatabase.fetchAll( db, "data_upload" );
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
		if( gdbUpl == null ) gdbUpl = new Gdatabase[0];
	}

	for( i=0; i<gdbUpl.length; i++ )
	if( gdbUpl[i].getId().equals(editAnnDbId) )
	{
		is_new = false;
		tgdb = null;
		gdb = gdbUpl[i];
		gdb.fetchGroupIds( db );
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
		frs = gdb.getFrefseq();
		break;
	}
	
	mys.setAttribute( "gdbUpl", gdbUpl );
	mys.setAttribute( "editAnnDbId", editAnnDbId );
	mys.setAttribute( "editTemplDbId", editTemplDbId );
%>

<HTML>
<head>
<title>Genboree - Annotation Database Manager</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY bgcolor="#DDE0FF">

<%@ include file="include/header.incl" %>

<center>

<form action="dbcreat.jsp" method="post">

  <select name="annDbId" onchange="this.form.submit()" class="txt" style="width:350">
    <option value="#">&lt;&lt;== New Annotations Database ==&gt;&gt;</option>
<% for( i=0; i<gdbUpl.length; i++ )
   {
     String myId = gdbUpl[i].getId();
     String sel = myId.equals(editAnnDbId) ? " selected" : "";
%>          <option value="<%=myId%>"<%=sel%>><%=gdbUpl[i].getName()%></option><%
   } %>
  </select>
  <br>&nbsp;

  <table class='TABLE' align="center" border="2" bgcolor="#aac5ff">
  <tbody>
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
	  
<% if( is_new ) { %>
  <tr><td>&nbsp;Template:</td><td>
  <select name="templDbId" onchange="this.form.submit()" class="txt" style="width:400">
<% for( i=0; i<gdbRef.length; i++ )
   {
     String myId = gdbRef[i].getId();
     String sel = myId.equals(editTemplDbId) ? " selected" : "";
%>          <option value="<%=myId%>"<%=sel%>><%=gdbRef[i].getName()%></option><%
   } %>
  </select>
  </td></tr>
<% } %>

<% 
	Frefseq fr = (tgdb != null) ? tgdb.getFrefseq() : gdb.getFrefseq();
%>
  <tr><td rowspan=3>&nbsp;Ref. Sequence:&nbsp;&nbsp;</td><td>Species: <%=Util.htmlQuote(fr.getSpecies())%></td></tr>
  <tr><td>Assembly Version: <%=Util.htmlQuote(fr.getVersion())%></td></tr>
  <tr><td>Description: <%=Util.htmlQuote(fr.getDescription())%></td></tr>

  <tr><td>&nbsp;Group:</td><td>
<%	int numGroups = grps.length;
	if( numGroups > 8 )
    { %>
        <select size="8" name="group_id" multiple class="txt" style="width: 400">
<%    for( i=0; i<numGroups; i++ )
      {
        String groupId = grps[i].getGroupId();
        String groupName = Util.htmlQuote( grps[i].getGroupName() );
        String sel = gdb.belongsToGroup(groupId) ? " selected" : "";
%>
        <option value="<%=groupId%>"<%=sel%>><%=groupName%></option>
<%    } %>
        </select>
<%  } else
    {
      for( i=0; i<numGroups; i++ )
      {
        String groupId = grps[i].getGroupId();
        String groupName = Util.htmlQuote( grps[i].getGroupName() );
        String sel = gdb.belongsToGroup(groupId) ? " checked" : "";
%>
        <input type=checkbox name="group_id" value="<%=groupId%>"<%=sel%>><%=groupName%></input><br>
<%    }
    } %>
  </td></tr>
  
<% if( is_new ) { %>
  <tr><td colspan=2><input type=checkbox name="use_multi" value="1"
	checked>Use separate table set for each entry point</input><td></tr>
<% } %>
	
  </tbody>
  </table>
<br>

<% if( is_new ) { %>
<input type=submit name="btnUpdate" style="width:100" value="Create">
<% } else {%>
<input type=submit name="btnUpdate" style="width:100" value="Update">&nbsp;&nbsp;<input
       type=submit name="btnDelete" style="width:100" value="Delete">&nbsp;&nbsp;<input
       type=submit name="btnUpload" style="width:200" value="Upload Annotations">
<% } %>
  
</form>

</center>

<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
