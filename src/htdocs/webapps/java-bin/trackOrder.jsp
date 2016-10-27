<%@ page import="javax.servlet.http.*, java.net.*, java.sql.*,
  java.util.*, org.genboree.dbaccess.*,
                 org.genboree.util.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%
    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );

	int i;

	String destback = (String) mys.getAttribute( "destback" );
	if( destback == null ) destback = "/java-bin/login.jsp";
	
	if( request.getParameter("back") != null )
	{
		GenboreeUtils.sendRedirect(request,response,  destback );
		return;
	}

	Refseq rseq = new Refseq();
	String refSeqId = SessionManager.getSessionDatabaseId(mys);

	if(refSeqId == null || userInfo[2].equals("0"))
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/login.jsp" );
		return;
	}

   	rseq.setRefSeqId(refSeqId);
   	rseq.fetch(db);
	if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;

	if( !is_admin )
	{
		String acs = Refseq.fetchUserAccess(db, rseq.getDatabaseName(), userInfo[2]);
		if( acs!=null && acs.equals("o") ) is_admin = true;
	}

	int userId = Util.parseInt(userInfo[2],-1);
	int fetchUserId = userId;
	
	boolean from_default = false;
	
	if( request.getParameter("default") != null )
	{
		from_default = true;
		fetchUserId = 0;
	}
		
	DbFtype[] tracks = rseq.fetchTracksSorted( db, fetchUserId );
	if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
	for( i=0; i<tracks.length; i++ )
	{
		DbFtype ft = tracks[i];
		ft.setSortOrder( i+1 );
	}

	if( !from_default )
	{
		
	Vector v = new Vector();
	
	Vector vm = new Vector();
	for( i=0; i<tracks.length; i++ )
	{
		DbFtype ft = tracks[i];
		String ord = request.getParameter( ft.toString() );
		if( ord == null ) continue;
		int iOrd = Util.parseInt( ord, -1 );
		if( iOrd == -1 ) iOrd = ft.getSortOrder();
		
		if( iOrd < 1 ) iOrd = 1;
		else if( iOrd > tracks.length ) iOrd = tracks.length;
		
		if( iOrd != ft.getSortOrder() )
		{
			ft.setSortOrder( iOrd );
			vm.addElement( ft );
		}
		else v.addElement( ft );
	}
	DbFtype[] trkm = new DbFtype[ vm.size() ];
	vm.copyInto( trkm );
	Arrays.sort( trkm );
	for( i=0; i<trkm.length; i++ )
	{
		DbFtype ft = trkm[i];
		int idx = ft.getSortOrder() - 1;
		if( idx < 0 ) idx = 0;
		else if( idx > v.size() ) idx = v.size();
		v.insertElementAt( ft, idx );
	}
	
	v.copyInto( tracks );
	for( i=0; i<tracks.length; i++ )
	{
		DbFtype ft = tracks[i];
		ft.setSortOrder( i+1 );
	}
	
	} // if( !from_default )
	
	if( request.getParameter("apply") != null )
	{
		rseq.setSortTracks( db, tracks, userId );
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;

		GenboreeUtils.sendRedirect(request,response,  destback );
		return;
	}
	else if( request.getParameter("applyAll") != null && is_admin )
	{
		rseq.deleteSortTracks( db, userId );
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
		rseq.setSortTracks( db, tracks, 0 );
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;

		GenboreeUtils.sendRedirect(request,response,  destback );
		return;
	}
	
%>

<HTML>
<head>
<title>Genboree - Track Order</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY bgcolor="#DDE0FF">

<%@ include file="include/header.incl" %>

<%@ include file="include/navbar.incl" %>

<p>
<CENTER><SPAN STYLE="font-size:12pt; font-weight:bold; background-color: #ffffe6;">&nbsp;Track Order Setup&nbsp;</SPAN></CENTER>
</p>

<form action="trackOrder.jsp" method="post">

  <INPUT type="submit" name="back" id="back" VALUE="Back" class="btn" style="width:100">
  <INPUT TYPE="submit" name="apply" id="apply" VALUE="Apply" class="btn" style="width:100">&nbsp;&nbsp;
<%	if( is_admin ) { %>
  <INPUT TYPE="submit" name="applyAll" id="applyAll" VALUE="Set As Default" class="btn" style="width:130">&nbsp;&nbsp;
<%	} %>
  <INPUT TYPE="submit" name="default" id="default" VALUE="Load Default" class="btn" style="width:130">&nbsp;&nbsp;

<br><p>

  <table border="0" cellpadding="2" width="100%">
  <tbody>
	<tr>
	  <td class="form_header" width="1%"><strong>Order</strong></td>
	  <td class="form_header"><strong>&nbsp;&nbsp;Track&nbsp;Name</strong></td>
	</tr>

<%
	for( i=0; i<tracks.length; i++ )
	{
		DbFtype ft = tracks[i];
		String trackName = ft.toString();
%>	<tr>
	  <td class="form_body">
	  <input type="text" size="6" name="<%=trackName%>" id="<%=trackName%>"
	  	value="<%=ft.getSortOrder()%>" class="txt">
	  </td>
	  <td class="form_body"><strong>&nbsp;&nbsp;<%=Util.htmlQuote(trackName)%></strong></td>
	</tr>
<%
	}
%>
  
  </tbody>
  </table>

<br>

  <INPUT type="submit" name="back" id="back" VALUE="Back" class="btn" style="width:100">
  <INPUT TYPE="submit" name="apply" id="apply" VALUE="Apply" class="btn" style="width:100">&nbsp;&nbsp;
<%	if( is_admin ) { %>
  <INPUT TYPE="submit" name="applyAll" id="applyAll" VALUE="Set As Default" class="btn" style="width:130">&nbsp;&nbsp;
<%	} %>
  <INPUT TYPE="submit" name="default" id="default" VALUE="Load Default" class="btn" style="width:130">&nbsp;&nbsp;

</form>

<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
