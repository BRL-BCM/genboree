<%@ page import="javax.servlet.http.*, java.net.*, java.util.*,
 org.genboree.dbaccess.*, org.genboree.util.Util,
                 org.genboree.util.GenboreeUtils" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%
    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );
	if( !userInfo[0].equals("admin") )
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/login.jsp" );
		return;
	}

	String destback = (String) mys.getAttribute( "destback" );
	if( destback == null ) destback = "login.jsp";

	if( request.getParameter("btnBack") != null )
	{
		GenboreeUtils.sendRedirect(request,response,  destback );
		return;
	}
	
	if( request.getParameter("btnNewUser") != null )
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/userProfile.jsp?m=NewUser" );
		return;
	}
	
	int i;
	Vector verr = (Vector) mys.getAttribute("verr");
	if( verr == null ) verr = new Vector();
	Vector vLog = (Vector) mys.getAttribute("vLog");
	if( vLog == null ) vLog = new Vector();
	
	mys.removeAttribute( "verr" );
	mys.removeAttribute( "vLog" );

    GenboreeUser[] usrs = null;
	if( request.getParameter("btnDelete") != null )
	{
		Vector vDel = new Vector();
		String[] delIds = request.getParameterValues( "delusr" );
		
		if( delIds == null ) delIds = (String[]) mys.getAttribute( "delusr" );
		mys.removeAttribute( "delusr" );
		
		if( delIds != null )
		for( i=0; i<delIds.length; i++ )
		{
			GenboreeUser usr = new GenboreeUser();
			usr.setUserId( delIds[i] );
			if( !usr.fetch(db) )
			{
				if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
				continue;
			}

			if( !usr.getName().equals("admin") && !usr.getName().equals("public") )
				vDel.addElement( usr );
		}

		if( vDel.size() > 0 )
		{
			GenboreeUser[] delUsrs = new GenboreeUser[ vDel.size() ];
			vDel.copyInto( delUsrs );
			
			boolean del_yes = (request.getParameter("askYes") != null);
			boolean del_no = (request.getParameter("askNo") != null);
			if( !del_yes && !del_no )
			{
				mys.setAttribute( "target", "userList.jsp" );
	
				String quest = "<br><font color=\"red\" size=\"+1\">"+
				"<strong>ATTENTION!</strong></font><br><br>\n"+
				"You are about to PERMANENTLY delete the following user(s):<br>\n"+
				"<br>\n";
				
				for( i=0; i<delUsrs.length; i++ )
				{
					quest = quest +
					"<strong>"+Util.htmlQuote(delUsrs[i].getScreenName())+
					"</strong> ID="+delUsrs[i].getUserId()+"<br>\n";
				}

				quest = quest + "<br>\n" +				
				"Are you willing to proceed?<br><br>\n";
	
				mys.setAttribute( "question", quest );
				mys.setAttribute( "form_text",
				"<input type=\"hidden\" name=\"btnDelete\" id=\"btnDelete\" "+
				"value=\"d\">\n" );
				
				mys.setAttribute( "delusr", delIds );
				
				GenboreeUtils.sendRedirect(request,response,  "/java-bin/ask.jsp" );
				return;
			}
			if( del_yes )
			{
				for( i=0; i<delUsrs.length; i++ )
				{
					GenboreeUser u = delUsrs[i];
					String usrName = Util.htmlQuote(u.getScreenName());
					String usrId = u.getUserId();
					if( u.delete(db) )
					{
						vLog.addElement( "User <b>"+usrName+
							"</b> ID="+usrId+" deleted." );
					}
					if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
				}
			}
		}
		else vLog.addElement( "No users marked for deletion." );
	}

    usrs = GenboreeUser.fetchAll( db );
    if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
%>
<HTML>
<head>
<title>Genboree - Admin - User List</title>
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

<form name="userList" id="userList" action="userList.jsp" method="post">
  <table border="0" cellpadding="2" cellspacing="2" width="100%">
  <tbody>

	<tr>
	<td colspan="6">
	  <input type="submit" name="btnNewUser" id="btnNewUser" class="btn"
	  	value="Create a New User">
	  <input type="submit" name="btnDelete" id="btnDelete" class="btn"
	  	value="Delete Checked Users">
	  <input type="submit" name="btnBack" id="btnBack" class="btn" value=" Back ">
	</td>
	</tr>
	<tr>
	<td class="form_header">User&nbsp;ID</td>
	<td class="form_header">Login&nbsp;Name</td>
	<td class="form_header">Full&nbsp;Name</td>
	<td class="form_header">Profile</td>
	<td class="form_header">Group&nbsp;Access</td>
	<td class="form_header">Delete</td>
	</tr>
<%
	for( i=0; i<usrs.length; i++ )
	{
		GenboreeUser usr = usrs[i];
		String altStyle = ((i%2) == 0) ? "form_body" : "bkgd";
		String delElem = "&nbsp;";
		if( !usr.getName().equals("admin") && !usr.getName().equals("public") )
		{
			delElem = "<input type=\"checkbox\" "+
			"name=\"delusr\" id=\"delusr\" value=\""+usr.getUserId()+"\">";
		}
%>
	<tr>
	<td class="<%=altStyle%>"><%=usr.getUserId()%></td>
	<td class="<%=altStyle%>"><%=Util.htmlQuote(usr.getName())%></td>
	<td class="<%=altStyle%>"><%=Util.htmlQuote(usr.getFullName())%></td>
	<td class="<%=altStyle%>"><a href="userProfile.jsp?userId=<%=usr.getUserId()%>&m=Profile">Edit&nbsp;Profile</a></td>
	<td class="<%=altStyle%>"><a href="userProfile.jsp?userId=<%=usr.getUserId()%>&m=Groups">Set&nbsp;Access</a></td>
	<td class="<%=altStyle%>"><%=delElem%></td>
	</tr>
<%
	}
%>
	<tr>
	<td colspan="6">
	  <input type="submit" name="btnNewUser" id="btnNewUser" class="btn"
	  	value="Create a New User">
	  <input type="submit" name="btnDelete" id="btnDelete" class="btn"
	  	value="Delete Checked Users">
	  <input type="submit" name="btnBack" id="btnBack" class="btn" value=" Back ">
	</td>
	</tr>
	<tr>
  </tbody>
  </table>
</form>
                                     
<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
