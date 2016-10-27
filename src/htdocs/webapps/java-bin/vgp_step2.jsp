<%@ page import="javax.servlet.http.*,
	java.util.*,
	org.genboree.dbaccess.*,
	org.genboree.util.*, org.genboree.upload.*, org.genboree.gdasaccess.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%!
	static String digs = "ABCDEFGHJKLMNPQRSTUVWXYZ";
	static String cvtAbc( int seed )
	{
		int n = digs.length();
		int i = (seed % n);
		seed /= n;
		String s = digs.substring(i,i+1);
		while( seed > 0 )
		{
			i = (seed % n);
			seed /= n;
			s = s + digs.substring(i,i+1);
		}
		return s;
	}
%>
<%
    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );
	if( request.getParameter("cmdBack") != null )
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/vgp_step1.jsp" );
		return;
	}
	int i;
	VGPaint vgp = (VGPaint) mys.getAttribute( "VGPaint" );
	if( vgp == null )
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/vgp.jsp" );
		return;
	}

	boolean can_finish = (mys.getAttribute("vgp_file_uploaded") != null);
	if( can_finish && request.getParameter("cmdFinish") != null )
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/vgp_step4.jsp" );
		return;
	}

	vgp.fetchEntryPoints( db );
	int neps = vgp.getFentrypointCount();	
	for( i=0; i<neps; i++ )
	{
		VGPaint.VGPFentrypoint ep = vgp.getFentrypointAt(i);
		String cthd = request.getParameter( "epcthd"+i );
		if( cthd != null ) ep.setCenter_header( cthd );
		String displ = request.getParameter( "epdispl"+i );
		if( displ != null )
		{
			ep.setDisplay( Util.parseInt(displ,0) != 0 );
		}
		String ab = request.getParameter( "epab"+i );
		if( ab != null ) ep.setAbbreviation( ab );
	}

	boolean are_unique = true;
	Hashtable ht = new Hashtable();
	int seed = 0;
	for( i=0; i<neps; i++ )
	{
		VGPaint.VGPFentrypoint ep = vgp.getFentrypointAt(i);
		String ab = ep.getAbbreviation();
		if( ht.get(ab) != null || Util.isEmpty(ab) )
		{
			are_unique = false;
			ab = cvtAbc( seed++ );
			ep.setAbbreviation( ab );
			ep.setCenter_header( "Chromosome "+ab );
		}
		ht.put( ab, "y" );
	}
	
	if( request.getParameter("cmdNext") != null )
	{
		boolean is_new = (mys.getAttribute("vgp_file_uploaded") == null) &&
			(mys.getAttribute("vgp_file_default") == null) ;
		vgp.updateTracksAndColors( db, is_new, userInfo[2] );
		
		if( are_unique )
		{
			GenboreeUtils.sendRedirect(request,response,  "/java-bin/vgp_step3.jsp" );
			return;
		}
	}
	else are_unique = true;

%>

<HTML>
<head>
<title>VGP - Choose Entry Points</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY bgcolor="#DDE0FF">

<%@ include file="include/header.incl" %>
<%@ include file="include/navbar.incl" %>

<form name="vgp" action="vgp_step2.jsp" method="post">
  <table width="100%" border="0" cellpadding="4">
  <tbody>

  <tr>
	<td colspan="2">
<%@ include file="include/vgpnav.incl" %>
	</td>
  </tr>

  <tr>
	<td colspan="2">
<table border="0" cellspacing="0" cellpadding="0" width="100%">
<tr>
<td align="left">
	<input name="cmdBack" type=submit value='<Back' class="btn">&nbsp;
	<input name="cmdNext" type=submit value='Next>' class="btn">&nbsp;
<% if(can_finish) { %>
	<input name="cmdFinish" type=submit value='Finish' class="btn">&nbsp;
<% } %>
	<input name="clr" type=button value='Clear' class="btn" onClick="clearAll()">&nbsp;
	<input name="rst" type=reset value='Reset' class="btn">&nbsp;
</td>
<td align="right">
	<input name="dfl" type=button value='Apply Abbreviations' onClick="generateDefaults()" class="btn">&nbsp;
</td>
</tr>
</table>
	</td>
  </tr>

<% if( !are_unique ) { %>
  <tr>
	<td colspan="2"><font color=red><strong>Warning:<strong></font>
	Missing or duplicating Entry Point abbreviated names have been detected;
	they have been fixed automatically, but now you may want to review the new names.
	If you want to change some of them, please make sure they are unique.
	Press "Next" button to continue.
	</td>
  </tr>
<% } %>
  
  <tr>
	<td>
	  <table width="100%" border="0" cellpadding="2">
	  <tbody>
	  	
		<tr>
		  <td class="form_header">Entry Point</td>
		  <td class="form_header">Center Name</td>
		  <td class="form_header">Display</td>
		  <td class="form_header">Abbreviation</td>
		</tr>

<%
	for( i=0; i<neps; i++ )
	{
		VGPaint.VGPFentrypoint ep = vgp.getFentrypointAt(i);
		String epcthdid = "epcthd"+i;
		String epdisplid = "epdispl"+i;
		String epdisplYes = ep.getDisplay() ? " checked" : "";
		String epdisplNo = ep.getDisplay() ? "" : " checked";
		String epabid = "epab"+i;
%>
		<tr>
		  <td class="form_body"><strong>&nbsp;<%=ep.getName()%></strong></td>
		  <td class="form_body">
			<input type="text" id="<%=epcthdid%>" name="<%=epcthdid%>"
			value="<%=ep.getCenter_header()%>" size="20" class="txt">
		  </td>
		  <td class="form_body">
			<input type="radio" id="<%=epdisplid%>" name="<%=epdisplid%>"
				value="1"<%=epdisplYes%>>Yes
			&nbsp;
			<input type="radio" id="<%=epdisplid%>" name="<%=epdisplid%>"
				value="0"<%=epdisplNo%>>No
		  </td>
		  <td class="form_body">
			<input type="text" id="<%=epabid%>" name="<%=epabid%>"
			size="4" maxlength="4"
			value="<%=ep.getAbbreviation()%>" class="txt">
		  </td>
		</tr>
<%
	}
%>
		
	  </tbody>
	  </table>
	</td>
  </tr>

  <tr>
	<td colspan="2">

<table border="0" cellspacing="0" cellpadding="0" width="100%">
<tr>
<td align="left">
	<input name="cmdBack" type=submit value='<Back' class="btn">&nbsp;
	<input name="cmdNext" type=submit value='Next>' class="btn">&nbsp;
<% if(can_finish) { %>
	<input name="cmdFinish" type=submit value='Finish' class="btn">&nbsp;
<% } %>
	<input name="clr" type=button value='Clear' class="btn" onClick="clearAll()">&nbsp;
	<input name="rst" type=reset value='Reset' class="btn">&nbsp;
</td>
<td align="right">
	<input name="dfl" type=button value='Apply Abbreviations' onClick="generateDefaults()" class="btn">&nbsp;
</td>
</tr>
</table>

	</td>
  </tr>
  
  </tbody>
  </table>

</form>

<script language="javascript">
var neps = <%=neps%>;
function clearAll()
{
	var i;
	for( i=0; i<neps; i++ )
	{
		var kt = "epcthd"+i;
		document.vgp.elements[kt].value = "";
		kt = "epab"+i;
		document.vgp.elements[kt].value = "";
	}
}
function generateDefaults()
{
	var i;
	for( i=0; i<neps; i++ )
	{
		var kt = "epcthd"+i;
		var ksv = document.vgp.elements["epab"+i].value;
		document.vgp.elements[kt].value = "Chromosome "+ksv;
	}
}
</script>

<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
