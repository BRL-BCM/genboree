<%@ page import="javax.servlet.http.*,
 java.util.*, java.sql.*,
 org.genboree.dbaccess.*, org.genboree.util.*, org.genboree.upload.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%
    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );

	String destback = (String) mys.getAttribute( "destback" );
	if( destback == null ) destback = "/java-bin/defaultGbrowser.jsp";
	
	if( request.getParameter("btnGetBack") != null )
	{
		GenboreeUtils.sendRedirect(request,response,  destback );
		return;
	}

	Refseq editRefseq = new Refseq();
	String refSeqId = (String) mys.getAttribute( "editRefSeqId" );
  int userId = Util.parseInt(myself.getUserId(), -1);

  if(refSeqId == null || userInfo[2].equals("0"))
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/defaultGbrowser.jsp" );
		return;
	}

   	editRefseq.setRefSeqId(refSeqId);
   	editRefseq.fetch(db);
	if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;


	int i, j;

	String[] trackNames = (String []) mys.getAttribute( "featuretypes" );
	Hashtable trackLookup = null;
	if( trackNames!=null && trackNames.length>0 )
	{
		trackLookup = new Hashtable();
		for( i=0; i<trackNames.length; i++ )
			trackLookup.put( trackNames[i], "y" );
	}
	
	Connection conn = db.getConnection( editRefseq.getDatabaseName() );
	
	DbFtype[] ftypes = DbFtype.fetchAll( conn , editRefseq.getDatabaseName(), userId);
	Vector v = new Vector();
	for( i=0; i<ftypes.length; i++ )
	{
		DbFtype ft = ftypes[i];
		if( trackLookup!=null && trackLookup.get(ft.getTrackName())==null ) continue;
		v.addElement( ft );
	}
	ftypes = new DbFtype[ v.size() ];
	v.copyInto( ftypes );
	Arrays.sort( ftypes );
	
	DbLink[] links = DbLink.fetchAll( conn, false );

	String editLinkId = request.getParameter( "editLinkId" );
	int iEditLinkId = Util.parseInt( editLinkId, -1 );
// TODO I am not sure what was expected in here I modified the editLink for editLinkId hope I did not brake
  // anything MLGG
  DbLink editLink = null;
	for( i=0; i<links.length; i++ )
	{
		if( links[i].getLinkId().compareTo(editLinkId)==0)
		{
			editLink = links[i];
			break;
		}
	}


  boolean is_new_link = false;
	if( editLink == null )
	{
		editLinkId = "#";
		iEditLinkId = -1;
		editLink = new DbLink();
		is_new_link = true;
	}
	
	String errMsg = null;
	boolean has_been_added = false;

	String lnkName = request.getParameter("link_name");
	if( lnkName == null ) lnkName = "";
	else lnkName = lnkName.trim();
	String lnkPatt = request.getParameter("link_pattern");
	if( lnkPatt == null ) lnkPatt = "";
	
	if( request.getParameter("btnCreateLink") != null && is_new_link )
	{
		editLink.setName( lnkName );
		editLink.setDescription( lnkPatt );
		if( Util.isEmpty(lnkName) )
		{
			errMsg = "Link Name must not be empty.";
		}
		else
		{
			editLink.insert( conn );
			DbLink[] newLinks = new DbLink[ links.length + 1 ];
			System.arraycopy( links, 0, newLinks, 1, links.length );
			links = newLinks;
			links[0] = editLink;
			is_new_link = false;
			has_been_added = true;
		}
	}
	else if( request.getParameter("btnUpdateLink") != null && !is_new_link )
	{
		editLink.setName( lnkName );
		editLink.setDescription( lnkPatt );
		if( Util.isEmpty(lnkName) )
		{
			errMsg = "Link Name must not be empty.";
		}
		else
		{
			editLink.update( conn );
		}
	}
	else if( request.getParameter("btnDeleteLink") != null && !is_new_link )
	{
		if( editLink.delete(conn) )
		{
			editLinkId = "#";
			iEditLinkId = -1;
			editLink = new DbLink();
			is_new_link = true;
			links = DbLink.fetchAll( conn, false);
		}
	}

	if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
	

	Vector vSel = new Vector();
	String[] selFtIds = request.getParameterValues( "featureTypeId" );
	if( selFtIds != null )
	for( i=0; i<selFtIds.length; i++ )
	{
		selFtIds[i] = Util.urlDecode( selFtIds[i] );
		vSel.addElement( selFtIds[i] );
	}

	Vector ftSel = new Vector();
	for( i=0; i<ftypes.length; i++ )
	if( vSel.contains(ftypes[i].toString()) )
	{
		ftypes[i].fetchLinkIds( conn, 0 );
		ftSel.addElement( ftypes[i] );
	}

	Vector lSel = new Vector();
	if( has_been_added && ftSel.size()>0 )
	{
		lSel.addElement( editLink );
	}
	
	if( request.getParameter("btnAssign") != null )
	{
		String[] newLinkIds = request.getParameterValues("linkId");
		for( j=0; j<ftSel.size(); j++ )
		{
			DbFtype ft = (DbFtype)ftSel.elementAt(j);
			ft.updateLinkIds( conn, newLinkIds, 0 );
			if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
		}
	}

	if( ftSel.size() > 0 && request.getParameter("btnClear") == null )
	for( i=0; i<links.length; i++ )
	{
		String linkId = ""+links[i].getLinkId();
		for( j=0; j<ftSel.size(); j++ )
		{
			DbFtype ft = (DbFtype) ftSel.elementAt(j);
			if( ft.belongsTo(linkId) )
			{
				if( !lSel.contains(linkId) ) lSel.addElement( linkId );
				break;
			}
		}
	}
	
%>

<HTML>
<head>
<title>Genboree - Link Setup</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY>

<%@ include file="include/header.incl" %>
<%@ include file="include/navbar.incl" %>

<p>
<CENTER><SPAN STYLE="font-size:12pt; font-weight:bold; background-color: #ffffe6;">&nbsp;Link Setup&nbsp;</SPAN></CENTER>
</p>



<form name="lnk" id="lnk" action="linkSetup.jsp" method="post">
<table border="0" cellspacing="2" cellpadding="4" width="100%">
<tbody>
  <tr>
	<td colspan="3">
	<input type="submit" name="btnGetBack" id="btnGetBack"
	class="btn" value="&lt;Back" style="width:80">
	</td>
  </tr>

  <tr>
	<td class="form_header">Feature Types</td>
	<td class="form_header">&nbsp;</td>
	<td class="form_header">Links</td>
  </tr>
  <tr>
	<td class="form_body">
	<select name="featureTypeId" id="featureTypeId"
	onchange="reloadIfSingle()"
	multiple size="12" class="txt" style="width:300">
<%
	for( i=0; i<ftypes.length; i++ )
	{
		DbFtype ft = ftypes[i];
		String myId = ft.toString();
		String sel = vSel.contains(myId) ? " selected" : "";
%><option value="<%=Util.urlEncode(myId)%>"<%=sel%>><%=Util.htmlQuote(myId)%></option>
<%
	}
%>	</select>
	</td>
	
	<td class="form_body">
	
	  <table border="0" cellspacing="0" cellpadding="0" width="100%" height="100%">
		<tr><td valign="top" align="center">
	<input type="submit" name="btnRefresh" id="btnRefresh"
	class="btn" value="Refresh" style="width:100"><br>
	<input type="submit" name="btnClear" id="btnClear"
	class="btn" value="Clear" style="width:100">
		</td></tr>
		<tr><td>&nbsp;<br>&nbsp;<br></td></tr>
		<tr><td valign="bottom" align="center">
	<input type="submit" name="btnAssign" id="btnAssign"
	class="btn" value="&lt;Assign&gt;" style="width:100">
		</td></tr>
	  </table>
	
	</td>

	<td class="form_body">
	<select name="linkId" id="linkId"
	multiple size="12" class="txt">
<%
	for( i=0; i<links.length; i++ )
	{
		DbLink lnk = links[i];
		String myId = ""+lnk.getLinkId();
		String sel = lSel.contains(myId) ? " selected" : "";
%><option value="<%=myId%>"<%=sel%>><%=Util.htmlQuote(lnk.getName())%></option>
<%
	}
%>	</select>
	</td>
  </tr>
  
  <tr><td colspan="3" style="height:12"></td></tr>
  
  <tr>
	<td class="form_header" colspan="3">Link Editor &nbsp;<a href="linkEditorHelp.jsp" target="genboreehelp"><font color="yellow">HELP?</font></a>
</td>
  </tr>
  
  <tr>
	<td class="form_body" colspan="3">
	
	<table border="0" cellspacing="2" cellpadding="0" width="100%">
	  <tr>
		<td><strong>Link</strong></td>
		<td>
	<select name="editLinkId" id="editLinkId"
	onChange="this.form.submit()"
	 class="txt" style="width:460">
<option value="#">-- Create New Link --</option>
<%
	for( i=0; i<links.length; i++ )
	{
		DbLink lnk = links[i];
		String myId = ""+lnk.getLinkId();
		String sel = editLinkId.equals(myId) ? " selected" : "";
%><option value="<%=myId%>"<%=sel%>><%=Util.htmlQuote(lnk.getName())%></option>
<%
	}
	
%>	</select>
		</td>
		<td>
<% if( is_new_link ) { %>
		<input type="submit" name="btnCreateLink" id="btnCreateLink"
		class="btn" style="width:100" value="Create">
<% } else { // if( is_new_link ) %>
		<input type="submit" name="btnDeleteLink" id="btnDeleteLink"
		class="btn" style="width:100" value="Delete">
<% } // else if( is_new_link ) %>
		</td>
	  </tr>
	  <tr>
		<td><strong>Name</strong></td>
		<td>
		<input type="text" name="link_name" id="link_name"
		class="txt" style="width:460"
		value="<%=Util.htmlQuote(editLink.getName())%>">
		</td>
		<td>
<% if( is_new_link ) { %>
		&nbsp;
<% } else { // if( is_new_link ) %>
		<input type="submit" name="btnUpdateLink" id="btnUpdateLink"
		class="btn" style="width:100" value="Update">
<% } // else if( is_new_link ) %>
		</td>
	  </tr>
	  
	  <tr>
		<td><strong>Pattern&nbsp;&nbsp;</strong></td>
		<td colspan="2">
		<input type="text" name="link_pattern" id="link_pattern"
		class="txt" style="width:580"
		value="<%=Util.htmlQuote(editLink.getDescription())%>">
		</td>
	  </tr>
	  
	</table>

	
	</td>
  </tr>
  
  <tr>
	<td colspan="3">
	<input type="submit" name="btnGetBack" id="btnGetBack"
	class="btn" value="&lt;Back" style="width:80">
	</td>
  </tr>
</tbody>
</table>
</form>

<SCRIPT language=javascript>
function reloadIfSingle()
{
	var opts = document.lnk.featureTypeId.options;
	var cnt = 0;
	var i=0;
	for( i=0; i<opts.length; i++ ) if( opts[i].selected ) cnt++;
	if( cnt == 1 ) document.lnk.submit();
}
</SCRIPT>

<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
