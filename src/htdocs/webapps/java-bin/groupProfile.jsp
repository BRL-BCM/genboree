<%@ page import="javax.servlet.http.*, java.net.*, java.util.*, java.sql.*,
 org.genboree.dbaccess.*, org.genboree.util.Util,
                 org.genboree.util.GenboreeUtils" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%!
	static final int MODE_DEFAULT = -1;
	static final int MODE_NEW_GROUP = 0;
	static final int MODE_RENAME = 1;
	static final int MODE_DATABASES = 2;
	static final String[] myModes = { "NewGroup", "Rename", "Databases" };
%>
<%
    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );
	if( !userInfo[0].equals("admin") )
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/index.jsp" );
		return;
	}

	String destback = (String) mys.getAttribute( "destback" );
	if( destback == null ) destback = "/java-bin/index.jsp";

	if( request.getParameter("btnBack") != null )
	{
		GenboreeUtils.sendRedirect(request,response,  destback );
		return;
	}

	int i;
	Vector verr = new Vector();
	Vector vLog = new Vector();
	
	int mode = MODE_DEFAULT;
	String sMode = request.getParameter( "m" );
	if( sMode != null )
	for( i=0; i<myModes.length; i++ )
	{
		if( sMode.compareToIgnoreCase(myModes[i]) == 0 )
		{
			mode = i;
			break;
		}
	}
	if( request.getParameter("btnCancel") != null )
	{
		mode = MODE_DEFAULT;
	}
	if( request.getParameter("btnNewGroup") != null )
	{
		mode = MODE_NEW_GROUP;
	}
	
    String editGroupId = request.getParameter( "groupId" );
	GenboreeGroup editGroup = new GenboreeGroup();
	if( mode == MODE_NEW_GROUP )
	{
		editGroupId = "#";
	}
	else if( mode==MODE_RENAME || mode==MODE_DATABASES )
	{
		editGroup.setGroupId( editGroupId );
		if( !editGroup.fetch(db) )
		{
			mode = MODE_DEFAULT;
		}
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
	}
	
	String dropRefSeqId = request.getParameter("dropdb");
	if( dropRefSeqId!=null && mode==MODE_DATABASES )
	{
		boolean del_yes = (request.getParameter("askYes") != null);
		boolean del_no = (request.getParameter("askNo") != null);
		Refseq rseq = new Refseq();
		rseq.setRefSeqId( dropRefSeqId );
		if( !rseq.fetch(db) )
		{
			del_yes = false;
			del_no = true;
		}
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
		if( !del_yes && !del_no )
		{
			mys.setAttribute( "target", "groupProfile.jsp" );

			String quest = "<br><font color=\"red\" size=\"+1\">"+
			"<strong>ATTENTION!</strong></font><br>\n"+
			"You are about to PERMANENTLY delete the database ID="+
			dropRefSeqId+"<br>\n"+
			"&laquo;<strong>"+
			Util.htmlQuote(rseq.getRefseqName())+
			"</strong>&raquo;<br>\n"+
			"All the data in the database will be lost FOREVER.<br><br>\n"+
			"Are you willing to proceed?<br><br>\n";

			mys.setAttribute( "question", quest );
			mys.setAttribute( "form_text",
			"<input type=\"hidden\" name=\"m\" id=\"m\" "+
			"value=\"Databases\">\n"+
			"<input type=\"hidden\" name=\"groupId\" id=\"groupId\" value=\""+
			editGroupId+"\">\n"+
			"<input type=\"hidden\" name=\"dropdb\" id=\"dropdb\" value=\""+
			dropRefSeqId+"\">" );
			GenboreeUtils.sendRedirect(request,response,  "/java-bin/ask.jsp" );
			return;
		}
		if( del_yes )
		{
			rseq.delete( db );
			if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
				vLog.addElement( "Database ID="+dropRefSeqId+" <b>"+
				Util.htmlQuote(rseq.getRefseqName())+"</b> dropped." );
		}
	}
	
	
	GenboreeGroup pubGroup = new GenboreeGroup();
	pubGroup.setGroupName("Public");
	pubGroup.fetchByName(db);
	if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;

	if( request.getParameter("btnApply") != null )
	{
		if( mode == MODE_NEW_GROUP || mode == MODE_RENAME )
		{
			String grpName = request.getParameter( "group_name" );
			String grpDesc = request.getParameter( "description" );
			editGroup.setDescription( grpDesc );
			if( Util.isEmpty(grpName) )
			{
				verr.addElement( "Group Name must not be empty." );
			}
			else if( mode == MODE_NEW_GROUP || !editGroup.getGroupName().equals(grpName) )
			{
				GenboreeGroup grp = new GenboreeGroup();
				grp.setGroupName( grpName );
				if( grp.fetchByName(db) )
					verr.addElement( "A group with this name already exists; "+
					"please choose a different name and try again" );
				if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
			}
			if( verr.size() == 0 )
			{
				if( mode==MODE_RENAME &&
					pubGroup.getGroupId().equals(editGroup.getGroupId()) )
				{
					if( !grpName.equals(pubGroup.getGroupName()) )
						vLog.addElement( "<b>Warning</b>: cannot change name of Public group." );
				}
				else editGroup.setGroupName( grpName );
				boolean rc = (mode == MODE_NEW_GROUP) ?
					editGroup.insert(db) : editGroup.update(db);
				if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
				if( rc )
				{
					vLog.addElement( "Group <b>"+
					Util.htmlQuote(editGroup.getGroupName())+
					"</b> "+((mode == MODE_NEW_GROUP) ? "created" : "updated") + "." );

					mode = (mode == MODE_NEW_GROUP) ? MODE_DATABASES : MODE_DEFAULT;
				}
				else verr.addElement( "DB error." );
			}
		}
		else if( mode == MODE_DATABASES )
		{
			String[] refSeqIds = request.getParameterValues("refSeqId");
			editGroup.setRefseqs( refSeqIds );
			if( editGroup.updateRefseqs(db) )
			{
				vLog.addElement( "Group <b>"+
				Util.htmlQuote(editGroup.getGroupName())+
				"</b> now has "+editGroup.getRefseqs().length+" database(s)." );
				mode = MODE_DEFAULT;
			}
			else verr.addElement( "DB error." );
			if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
		}
	}
	
	if( mode == MODE_DEFAULT && request.getParameter("btnDelete") != null )
	{
		String[] delIds = request.getParameterValues("delgrpid");
		if( delIds == null ) delIds = (String[]) mys.getAttribute( "delgrpid" );
		mys.removeAttribute( "delgrpid" );
		
		if( delIds!=null && delIds.length>0 )
		{
			Vector vDelGrp = new Vector();
			for( i=0; i<delIds.length; i++ )
			{
				GenboreeGroup grp = new GenboreeGroup();
				grp.setGroupId( delIds[i] );
				if( pubGroup.getGroupId().equals(grp.getGroupId()) )
				{
					vLog.addElement( "<b>Warning</b>: cannot delete Public group." );
					continue;
				}
				if( grp.fetch(db) )
				{
					vDelGrp.addElement( grp );
				}
				if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
			}
			
			boolean del_yes = (request.getParameter("askYes") != null);
			boolean del_no = (request.getParameter("askNo") != null);
			if( vDelGrp.size() == 0 )
			{
				del_yes = false;
				del_no = true;
				vLog.addElement( "No groups were checked for deletion." );
			}

			if( !del_yes && !del_no )
			{
				mys.setAttribute( "delgrpid", delIds );
				mys.setAttribute( "target", "groupProfile.jsp" );
				String quest = "<br><font color=\"red\" size=\"+1\">"+
				"<strong>ATTENTION!</strong></font><br><br>\n"+
				"You are about to PERMANENTLY delete the following group(s):<br>\n"+
				"<br>\n";
				
				for( i=0; i<vDelGrp.size(); i++ )
				{
					GenboreeGroup grp = (GenboreeGroup) vDelGrp.elementAt( i );
					quest = quest +
					"<strong>"+Util.htmlQuote(grp.getGroupName())+
					"</strong> ID="+grp.getGroupId()+"<br>\n";
				}

				quest = quest + "<br>\n" +				
				"Are you willing to proceed?<br><br>\n";
	
				mys.setAttribute( "question", quest );
				mys.setAttribute( "form_text",
				"<input type=\"hidden\" name=\"btnDelete\" id=\"btnDelete\" "+
				"value=\"d\">\n" );
				
				GenboreeUtils.sendRedirect(request,response,  "/java-bin/ask.jsp" );
				return;
			}

			if( del_yes )
			for( i=0; i<vDelGrp.size(); i++ )
			{
				GenboreeGroup grp = (GenboreeGroup) vDelGrp.elementAt( i );
				String grpName = Util.htmlQuote(grp.getGroupName());
				String grpId = grp.getGroupId();
				if( grp.delete(db) )
				{
					vLog.addElement( "Group <b>"+grpName+
						"</b> ID="+grpId+" deleted." );
				}
				if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
			}
		}
	}
	
    GenboreeGroup[] allGroups = GenboreeGroup.fetchAll( db );
	if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
	
	GenboreeUser[] usrs = null;
	Hashtable htUsr = new Hashtable();
	Hashtable htAdmins = new Hashtable();

	if( mode == MODE_DEFAULT )
	{
		usrs = GenboreeUser.fetchAll( db );
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
		for( i=0; i<usrs.length; i++ )
		{
			GenboreeUser usr = usrs[i];
			if( usr.getUserId().equals(userInfo[2]) ) continue;
			htUsr.put( usr.getUserId(), usr );
		}
		try
		{
            DbResourceSet dbRes = db.executeQuery( "SELECT groupId, userId FROM usergroup WHERE userGroupAccess='o'" );
			ResultSet rs = dbRes.resultSet;
			while( rs.next() )
			{
				String groupId = rs.getString(1);
				String userId = rs.getString(2);
				GenboreeUser usr = (GenboreeUser) htUsr.get( userId );
				if( usr == null ) continue;
				Vector v = (Vector) htAdmins.get( groupId );
				if( v == null )
				{
					v = new Vector();
					htAdmins.put( groupId, v );
				}
				v.addElement( usr );
			}
            dbRes.close();
        } catch( Exception ex01 ) {
            System.err.println("Exception at groupProfile.jsp 300");
            ex01.printStackTrace(System.err);
        }
	}

	Refseq[] rseqs = null;
	Hashtable htdb = new Hashtable();
	Hashtable htDbGrp = new Hashtable();
	Hashtable htDbLost = new Hashtable();
	if( mode == MODE_DATABASES )
	{
		rseqs = Refseq.fetchAll( db );
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
		for( i=0; i<rseqs.length; i++ )
		{
			Refseq rseq = rseqs[i];
			htdb.put( rseq.getRefSeqId(), rseq );
			htDbLost.put( rseq.getRefSeqId(), rseq );
		}
		try
		{
            DbResourceSet dbRes = db.executeQuery( "SELECT refSeqId, groupId FROM grouprefseq" );
            ResultSet rs = dbRes.resultSet;
			while( rs.next() )
			{
				String refSeqId = rs.getString(1);
				String groupId = rs.getString(2);
				if( groupId.equals(editGroupId) )
				{
					Refseq rseq = (Refseq) htdb.get( refSeqId );
					if( rseq != null ) htDbGrp.put( refSeqId, editGroupId );
				}
				htDbLost.remove( refSeqId );
			}
            dbRes.close();
        } catch( Exception ex02 ) {
            ex02.printStackTrace(System.err);
        }
	}

	String applyLabel = "Apply";
	if( mode == MODE_NEW_GROUP ) applyLabel = "Create";
%>

<HTML>
<head>
<title>Genboree - Admin - Group Profile</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY>

<%@ include file="include/header.incl" %>
<%@ include file="include/navbar.incl" %>

<%
	if( verr.size() > 0 )
	{
%><br><font color="red"><strong>Error:</strong></font>
The requested operation cannot be performed due to the following problem(s):
<ul>
<%
	for( i=0; i<verr.size(); i++ )
		out.println( "<li>"+((String)verr.elementAt(i))+"</li>" );
%></ul>
<%
	}

	if( vLog.size() > 0 )
	{
		out.println( "<ul>" );
		for( i=0; i<vLog.size(); i++ )
			out.println( "<li>"+((String)vLog.elementAt(i))+"</li>" );
		out.println( "</ul>" );
	}
%>

<form name="groupProfile" id="groupProfile" action="groupProfile.jsp" method="post">
<% if( mode != MODE_DEFAULT ) { %>
<input type="hidden" name="m" id="m" value="<%=myModes[mode]%>">
<% } %>
<% if( mode == MODE_RENAME || mode == MODE_DATABASES ) { %>
<input type="hidden" name="groupId" id="groupId" value="<%=editGroupId%>">
<% } %>

<% if( mode == MODE_DEFAULT ) { %>
  <input type="submit" name="btnNewGroup" id="btnNewGroup" class="btn"
  	value="New Group">
  <input type="submit" name="btnDelete" id="btnDelete" class="btn"
  	value="Delete Checked Groups">
  <input type="submit" name="btnBack" id="btnBack" class="btn" value=" Back ">
<table border="0" cellpadding="2" cellspacing="2" width="100%">
<tbody>

  <tr>
	<td colspan="6"><b>Note:</b> Groups with no administrator (other than <b>admin</b>)
	are <span class="hiliter">highlighted</span>.</td>
  </tr>
  <tr>
	<td class="form_header">ID</td>
	<td class="form_header">Name</td>
	<td class="form_header">Administrator(s)</td>
	<td class="form_header">Rename</td>
	<td class="form_header">Databases</td>
	<td class="form_header">Delete</td>
  </tr>

<%
	for( i=0; i<allGroups.length; i++ )
	{
		String altStyle = ((i%2) == 0) ? "form_body" : "bkgd";
		GenboreeGroup g = allGroups[i];
		
		String delCtl =
			"<input type=\"checkbox\" name=\"delgrpid\" id=\"delgrpid\" value=\""+
			g.getGroupId()+"\">";
		if( g.getGroupId().equals(pubGroup.getGroupId()) ) delCtl = "&nbsp;";

		Vector vAdmins = (Vector) htAdmins.get( g.getGroupId() );
		String sAdmins = "&nbsp;";
		if( vAdmins!=null && vAdmins.size()>0 )
		{
			sAdmins = null;
			for( int j=0; j<vAdmins.size(); j++ )
			{
				GenboreeUser usr = (GenboreeUser) vAdmins.elementAt(j);
				String uName = Util.htmlQuote( usr.getName() );
				String eml = usr.getEmail();
				if( !Util.isEmpty(eml) )
				{
					uName = "<a href=\"mailto:"+Util.htmlQuote(eml)+"\">"+
						uName+"</a>";
				}
				if( sAdmins == null ) sAdmins = uName;
				else sAdmins = sAdmins + ", " + uName;
			}
		}
		else
		{
			altStyle = ((i%2) == 0) ? "h_darker" : "h_lighter";
		}
%>
<tr>
<td class="<%=altStyle%>"><%=g.getGroupId()%></td>
<td class="<%=altStyle%>"><%=Util.htmlQuote(g.getGroupName())%></td>
<td class="<%=altStyle%>"><%=sAdmins%></td>
<td class="<%=altStyle%>"><a href="groupProfile.jsp?groupId=<%=g.getGroupId()%>&m=Rename">Rename</a></td>
<td class="<%=altStyle%>"><a href="groupProfile.jsp?groupId=<%=g.getGroupId()%>&m=Databases">Databases</a></td>
<td class="<%=altStyle%>"><%=delCtl%></td>
</tr><%
	}
%>

</tbody>
</table>
  <input type="submit" name="btnNewGroup" id="btnNewGroup" class="btn"
  	value="New Group">
  <input type="submit" name="btnDelete" id="btnDelete" class="btn"
  	value="Delete Checked Groups">
  <input type="submit" name="btnBack" id="btnBack" class="btn" value=" Back ">
<% } // MODE_DEFAULT %>

<p>
<% if( mode == MODE_NEW_GROUP ) { %>
<strong>Create a New Group</strong>
<% } else if( mode == MODE_RENAME ) { %>
Rename group <strong><%=Util.htmlQuote(editGroup.getGroupName())%></strong>
ID <strong><%=editGroup.getGroupId()%></strong>
<% } else if( mode == MODE_DATABASES ) { %>
Databases in the group <strong><%=Util.htmlQuote(editGroup.getGroupName())%></strong>
ID <strong><%=editGroup.getGroupId()%></strong>
<% } %>
</p>
<% if( mode == MODE_NEW_GROUP || mode == MODE_RENAME ) { %>
  <table border="0" cellpadding="2" cellspacing="2" width="100%">
  <tbody>
	<tr>
	  <td class="form_header"><strong>Group Name</strong></td>
	  <td class="form_body">
	  <input type="text" name="group_name" id="group_name"
	  class="txt" size="72" maxlength="255"
	  value="<%=Util.htmlQuote(editGroup.getGroupName())%>">
	  </td>
	</tr>
	<tr>
	  <td class="form_header"><strong>Description</strong></td>
	  <td class="form_body">
	  <input type="text" name="description" id="description"
	  class="txt" size="72" maxlength="255"
	  value="<%=Util.htmlQuote(editGroup.getDescription())%>">
	  </td>
	</tr>
  </tbody>
  </table>
<% } // MODE_RENAME %>

<% if( mode == MODE_DATABASES ) { %>
<input type="submit" name="btnApply" id="btnApply" class="btn" value=" <%=applyLabel%> ">
<input type="reset" name="btnReset" id="btnReset" class="btn" value=" Reset ">
<input type="submit" name="btnCancel" id="btnCancel" class="btn" value=" Cancel ">
<table border="0" cellpadding="2" cellspacing="1" width="100%">
<tbody>

  <tr>
	<td colspan="6"><b>Note:</b> Databases not in any group (&quot;Lost Databases&quot;)
	are <span class="hiliter">highlighted</span>.</td>
  </tr>
  <tr>
	<td class="form_header">In</td>
	<td class="form_header">ID</td>
	<td class="form_header">Name</td>
	<td class="form_header" width="5%">Species</td>
	<td class="form_header" width="5%">Version</td>
	<td class="form_header" width="2%">&nbsp;</td>
  </tr>

<%
	for( i=0; i<rseqs.length; i++ )
	{
		String altStyle = ((i%2) == 0) ? "form_body" : "bkgd";
		Refseq rseq = rseqs[i];
		String refSeqId = rseq.getRefSeqId();
		String chk = (htDbGrp.get(refSeqId)!=null) ? " checked" : "";

		if( htDbLost.get(refSeqId) != null )
		{
			altStyle = ((i%2) == 0) ? "h_darker" : "h_lighter";
		}
%>
<tr>
<td class="<%=altStyle%>" valign="top">
<input type="checkbox" name="refSeqId" id="refSeqId" value="<%=refSeqId%>"<%=chk%>>
</td>
<td class="<%=altStyle%>" valign="top"><a href="javascript:void prompt('Database Name:','<%=rseq.getDatabaseName()%>');"><%=refSeqId%></a></td>
<td class="<%=altStyle%>"><%=Util.htmlQuote(rseq.getRefseqName())%></td>
<td class="<%=altStyle%>" nowrap><%=Util.htmlQuote(rseq.getRefseq_species())%></td>
<td class="<%=altStyle%>" nowrap><%=Util.htmlQuote(rseq.getRefseq_version())%></td>
<td class="<%=altStyle%>" nowrap><a 
href="groupProfile.jsp?groupId=<%=editGroupId%>&m=Databases&dropdb=<%=refSeqId%>">drop</a></td>
</tr><%
	}
%>
</tbody>
</table>
<% } %>

<% if( mode != MODE_DEFAULT ) { %>
<input type="submit" name="btnApply" id="btnApply" class="btn" value=" <%=applyLabel%> ">
<input type="reset" name="btnReset" id="btnReset" class="btn" value=" Reset ">
<input type="submit" name="btnCancel" id="btnCancel" class="btn" value=" Cancel ">
<% } %>

</form>

<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
