<%@ page import="javax.servlet.http.*, java.net.*, java.util.*,
 org.genboree.dbaccess.*, org.genboree.util.Util,
                 org.genboree.util.GenboreeUtils" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%!
	static String[] acsCodes = { "o", "w", "r", "#" };
	static String[] acsNames = { "A", "W", "R", "N" };
	static final int MODE_DEFAULT = -1;
	static final int MODE_NEW_USER = 0;
	static final int MODE_PROFILE = 1;
	static final int MODE_GROUPS = 2;
	static final String[] myModes = { "NewUser", "Profile", "Groups" };
%>
<%
    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );
	if( !userInfo[0].equals("admin") )
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/login.jsp" );
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
	if( mode==MODE_DEFAULT || request.getParameter("btnCancel")!=null )
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/userList.jsp" );
		return;
	}

	String applyLabel = "Apply";
	
    String editUserId = request.getParameter( "userId" );
	GenboreeUser editUser = new GenboreeUser();
	if( mode == MODE_NEW_USER )
	{
		editUserId = "#";
	}
	else
	{
		editUser.setUserId( editUserId );
		if( !editUser.fetch(db) ) editUser = null;
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
	}
	if( editUser == null )
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/userList.jsp" );
		return;
	}

    GenboreeGroup[] allGroups = null;
    String errMsg;
	
	if( mode == MODE_GROUPS )
	{
		editUser.fetchGroups( db );
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
		allGroups = GenboreeGroup.fetchAll( db );
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
	}
	
	mys.removeAttribute( "verr" );
	mys.removeAttribute( "vLog" );

	if( request.getParameter("btnApply") != null )
	{
		mys.setAttribute( "verr", verr );
		mys.setAttribute( "vLog", vLog );

		if( mode == MODE_NEW_USER || mode == MODE_PROFILE )
		{
			editUser.setPassword( request.getParameter("password") );
			editUser.setFirstName( request.getParameter("first_name") );
			editUser.setLastName( request.getParameter("last_name") );
			editUser.setInstitution( request.getParameter("institution") );
			editUser.setPhone( request.getParameter("telephone") );
			editUser.setEmail( request.getParameter("email") );
			if( mode == MODE_NEW_USER )
			{
				editUser.setName( request.getParameter("login_name") );
				errMsg = editUser.checkLoginName( db );
				if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
				if( errMsg != null ) verr.addElement( errMsg );
				else if( editUser.insert(db) )
				{
					vLog.addElement( "New user <b>"+
						Util.htmlQuote(editUser.getScreenName())+
						"</b> created successfully." );
					GenboreeGroup pubGrp = new GenboreeGroup();
					pubGrp.setGroupName( "Public" );
					if( pubGrp.fetchByName(db) )
					{
						pubGrp.grantAccess( db, editUser.getUserId(), "r" );
					}
					editUser.fetchGroups( db );
					if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
					editUserId = editUser.getUserId();
					
					mode = MODE_GROUPS;
					allGroups = GenboreeGroup.fetchAll( db );
				}
				else verr.addElement( "DB error." );
				if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
			}
			else
			{
				if( editUser.update(db) )
				{
					vLog.addElement( "Profile of user <b>"+
						Util.htmlQuote(editUser.getScreenName())+
						"</b> updated successfully." );
					if( editUserId.equals(userInfo[2]) )
					{
						mys.setAttribute( "pass", editUser.getPassword() );
						userInfo[1] = editUser.getPassword();
					}
					GenboreeUtils.sendRedirect(request,response,  "/java-bin/userList.jsp" );
					return;
				}
				else verr.addElement( "DB error." );
				if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
			}
		}
		else if( mode == MODE_GROUPS )
		{
			int ngrps = 0;
			
			for( i=0; i<allGroups.length; i++ )
			{
          GenboreeGroup g = allGroups[i];
          String groupId = g.getGroupId();
          String newAcs = request.getParameter("grp_acs" + groupId);

          String acs = "#";

          if(editUser.getUserId().equalsIgnoreCase("75"))
          {
              acs = "o";
              newAcs = acs;
          } else
          {
              if(newAcs == null) continue;
              if(editUser.isGroupOwner(groupId)) acs = "o";
              else if(editUser.isReadOnlyGroup(groupId)) acs = "r";
              else if(editUser.belongsTo(groupId)) acs = "w";
              if(newAcs.equals(acs)) continue;
          }

				g.grantAccess( db, editUserId, newAcs );
				if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
				ngrps++;
			}
			editUser.fetchGroups( db );
			if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
			
			if( ngrps > 0 ) vLog.addElement( "Group Access of user <b>"+
				Util.htmlQuote(editUser.getScreenName())+
				"</b> changed for "+ngrps+" groups." );
			
			GenboreeUtils.sendRedirect(request,response,  "/java-bin/userList.jsp" );
			return;
		}
	}

	if( mode == MODE_NEW_USER ) applyLabel = "Create";
%>
<HTML>
<head>
<title>Genboree - Admin - User Profile</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY bgcolor="#DDE0FF">

<%@ include file="include/header.incl" %>
<%@ include file="include/navbar.incl" %>

<%
	if( verr.size() > 0 )
	{
%><font color="red"><strong>Error:</strong></font>
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

<form name="userProfile" id="userProfile" action="userProfile.jsp" method="post">
<input type="hidden" name="m" id="m" value="<%=myModes[mode]%>">
<% if( mode != MODE_NEW_USER ) { %>
<input type="hidden" name="userId" id="userId" value="<%=editUserId%>">
<% } %>
<p>
<% if( mode == MODE_NEW_USER ) { %>
<strong>New User Profile</strong>
<% } else if( mode == MODE_PROFILE ) { %>
Profile of user <strong><%=Util.htmlQuote(editUser.getScreenName())%></strong>
ID <strong><%=editUser.getUserId()%></strong>
<% } else if( mode == MODE_GROUPS ) { %>
Group Access of user <strong><%=Util.htmlQuote(editUser.getScreenName())%></strong>
ID <strong><%=editUser.getUserId()%></strong>
<% } %>
</p>
<input type="submit" name="btnApply" id="btnApply" class="btn" value=" <%=applyLabel%> ">
<input type="reset" name="btnReset" id="btnReset" class="btn" value=" Reset ">
<input type="submit" name="btnCancel" id="btnCancel" class="btn" value=" Cancel ">

<% if( mode == MODE_NEW_USER || mode == MODE_PROFILE ) { %>
  <table border="0" cellpadding="2" cellspacing="2" width="100%">
  <tbody>
	<tr>
	  <td class="form_header"><strong>Login Name</strong></td>
	  <td class="form_body">
       <% if( mode == MODE_NEW_USER ){ %>
	  <input type="text" name="login_name" id="login_name"
	  class="txt" size="72" maxlength="255"
	  value="<%=Util.htmlQuote(editUser.getName())%>">
      <% } else {  %>
	  <strong><%=Util.htmlQuote(editUser.getName())%></strong>&nbsp;
	  <% } %>
	  </td>
	</tr>
	<tr>
	  <td class="form_header"><strong>Password</strong></td>
	  <td class="form_body">
	  <input type="text" name="password" id="password"
	  class="txt" size="72" maxlength="255"
	  value="<%=Util.htmlQuote(editUser.getPassword())%>">
	  </td>
	</tr>
	<tr>
	  <td class="form_header"><strong>First Name</strong></td>
	  <td class="form_body">
	  <input type="text" name="first_name" id="first_name"
	  class="txt" size="72" maxlength="255"
	  value="<%=Util.htmlQuote(editUser.getFirstName())%>">
	  </td>
	</tr>
	<tr>
	  <td class="form_header"><strong>Last Name</strong></td>
	  <td class="form_body">
	  <input type="text" name="last_name" id="last_name"
	  class="txt" size="72" maxlength="255"
	  value="<%=Util.htmlQuote(editUser.getLastName())%>">
	  </td>
	</tr>
	<tr>
	  <td class="form_header"><strong>Institution</strong></td>
	  <td class="form_body">
	  <input type="text" name="institution" id="institution"
	  class="txt" size="72" maxlength="255"
	  value="<%=Util.htmlQuote(editUser.getInstitution())%>">
	  </td>
	</tr>
	<tr>
	  <td class="form_header"><strong>Telephone</strong></td>
	  <td class="form_body">
	  <input type="text" name="telephone" id="telephone"
	  class="txt" size="72" maxlength="255"
	  value="<%=Util.htmlQuote(editUser.getPhone())%>">
	  </td>
	</tr>
	<tr>
	  <td class="form_header"><strong>Email</strong></td>
	  <td class="form_body">
	  <input type="text" name="email" id="email"
	  class="txt" size="72" maxlength="255"
	  value="<%=Util.htmlQuote(editUser.getEmail())%>">
	  </td>
	</tr>
  </tbody>
  </table>
<% } // MODE_PROFILE %>

<% if( mode == MODE_GROUPS ) { %>
  <table border="0" cellpadding="2" cellspacing="2" width="100%">
  <tbody>
	<tr><td colspan="3">
	Group Access Legend:
	<b>A</b> - Administrator; <b>W</b> - Author;
	<b>R</b> - Subscriber; <b>N</b> - No Access
	</td></tr>
	<tr>
	<td class="form_header" width="5%">Group&nbsp;ID</td>
	<td class="form_header">Group&nbsp;Name</td>
	<td class="form_header" width="10%">Access</td>
	</tr>
<%
	for( i=0; i<allGroups.length; i++ )
	{
		String altStyle = ((i%2) == 0) ? "form_body" : "bkgd";
		GenboreeGroup g = allGroups[i];
		String groupId = g.getGroupId();
		String elemId = "grp_acs"+groupId;
		String groupName = Util.htmlQuote( g.getGroupName() );
		int iacs = 3;
		if(editUser.getUserId().equalsIgnoreCase("75"))
    {
        iacs = 0;
    }
    else
    {
        if( editUser.isGroupOwner(groupId) ) iacs = 0;
		    else if( editUser.isReadOnlyGroup(groupId) ) iacs = 2;
		    else if( editUser.belongsTo(groupId) ) iacs = 1;
    }
%>
<tr>
<td class="<%=altStyle%>"><%=groupId%></td>
<td class="<%=altStyle%>"><%=groupName%></td>
<td class="<%=altStyle%>" nowrap><%
		
		for( int j=0; j<acsCodes.length; j++ )
		{
			String sel = (iacs == j) ? " checked" : "";
%><input type="radio" name="<%=elemId%>" id="<%=elemId%>"
	value="<%=acsCodes[j]%>"<%=sel%>><%=acsNames[j]%>&nbsp;&nbsp;<%
		}
%></td>
</tr><%
	}
%>
	<tr><td colspan="3">
	Group Access Legend:
	<b>A</b> - Administrator; <b>W</b> - Author;
	<b>R</b> - Subscriber; <b>N</b> - No Access
	</td></tr>
  </tbody>
  </table>
<% } // MODE_GROUPS %>

<input type="submit" name="btnApply" id="btnApply" class="btn" value=" <%=applyLabel%> ">
<input type="reset" name="btnReset" id="btnReset" class="btn" value=" Reset ">
<input type="submit" name="btnCancel" id="btnCancel" class="btn" value=" Cancel ">

</form>

<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
