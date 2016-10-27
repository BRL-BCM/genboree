<%@ page import="javax.servlet.http.*, java.net.*, java.sql.*,
  java.util.*, org.genboree.dbaccess.*, org.genboree.gdasaccess.*, org.genboree.util.Util" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>

<%
	response.addDateHeader( "Expires", 0L );
	response.addHeader( "Cache-Control", "no-cache, no-store" );

	String destback = (String) mys.getAttribute( "destback" );
	if( destback == null ) destback = "defaultGbrowser.jsp";
	
	if( request.getParameter("back") != null || userInfo[2].equals("0"))
	{
		GenboreeUtils.sendRedirect(request,response,  destback );
		return;
	}

	int a = 0;
	int b = 0;
	String tempValue[];
	Refseq editRefseq = null;
	String refSeqId = (String) mys.getAttribute( "editRefSeqId" );
	if( refSeqId == null ) refSeqId = "#";

	int i;
//	Refseq[] rseqs = (Refseq[]) mys.getAttribute( "RefSeqs" );
  Refseq[] rseqs = Refseq.fetchAll( db, grps );
  if( rseqs != null )
	{
		for( i=0; i<rseqs.length; i++ )
		{
			if( rseqs[i].getRefSeqId().equals(refSeqId) )
			{
				editRefseq = rseqs[i];
				break;
			}
		}
		if( editRefseq==null && rseqs.length>0 )
		{
			editRefseq = rseqs[0];
			refSeqId = editRefseq.getRefSeqId();
		}
	}

	if( refSeqId == null )
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/defaultGbrowser.jsp" );
		return;
	}

   	editRefseq.setRefSeqId(refSeqId);
   	editRefseq.fetch(db);
	if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;


	String __fileName = request.getRequestURL().toString();
	
	String __normal = "nav";
	String __highlighted = "nav_selected";
	String[] __navigationHrefs = {
		"trackOps.jsp"
		};
	String[] __navigationLabels = {
		"Track Operations"
 		};
	String[] __descriptions = {
		"Tools for manipulating annotations."
		};


%>
<HTML>
<head>
<title>Genboree - My Analyses</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>

<BODY>
<DIV id="overDiv" class="c1"></DIV>
</SCRIPT>

<%@ include file="include/header.incl" %>
<%@ include file="include/navbar.incl" %>

<p>
<CENTER><SPAN STYLE="font-size:12pt; font-weight:bold; background-color: #ffffe6;">&nbsp;My Analyses&nbsp;</SPAN></CENTER>
</p>


<table border="0" cellpadding="2" cellspacing="4" width="100%">
<tbody>
<tr>
	<td class="form_body"><strong>Analysis Type</strong></td>
	<td class="form_body"><strong>Description</strong></td>
</tr>

<%
	for( int j=0; j<__navigationHrefs.length; j++ )
	{
%>
		<tr>
<%
		String __a1 = "<a href=\"" + __navigationHrefs[j] + "\">";
		String __a2 = "</a>";
%>
			<td><%=__a1%><%=__navigationLabels[j]%><%=__a2%></td>
			<td><%=__descriptions[j]%></td>
		
		</tr>

		<tr>
			<td class="form_body" height="2"></td>
			<td class="form_body" height="2"></td>
		</tr>
<%
	}
%>
</tbody>
</table>



<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
