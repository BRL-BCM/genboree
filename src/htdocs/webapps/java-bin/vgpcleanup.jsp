<%@ page import="javax.servlet.http.*,
	java.util.*, java.io.*,
	org.genboree.dbaccess.*, org.genboree.util.*, org.genboree.upload.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%!
	static final File graphicsDir =
		new File( System.getProperty("catalina.home",org.genboree.util.Constants.GENBOREE_HTDOCS), "graphics" );
%>
<%
	int i;
	File[] flst = graphicsDir.listFiles();
	
	if( request.getParameter("btnDel") != null )
	{
		String[] mks = request.getParameterValues( "mark" );
		Hashtable ht = new Hashtable();
		if( mks != null )
		for( i=0; i<mks.length; i++ ) ht.put( mks[i], "y" );
		for( i=0; i<flst.length; i++ )
		{
			File f = flst[i];
			if( ht.get(f.getName()) == null ) continue;
			if( f.isDirectory() ) FileKiller.clearDirectory( f );
			f.delete();
		}
		flst = graphicsDir.listFiles();
	}
	
	Date curd = new Date();
	long curt = curd.getTime();
	long diff = 24L * 60L * 60L * 1000L; // 24 hours
%>

<HTML>
<head>
<title>VGP Paint - Purge temp files</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY>

<form name="vgpclean" id="vgpclean" action="vgpcleanup.jsp" method="post">
<table border="0" cellpadding="4" cellspacing="2" bgcolor="white">
<tr>
<td colspan="4"><strong><%=curd.toString()%></strong></td>
</tr>
<tr>
<td class="form_header">Name</td>
<td class="form_header">Attributes</td>
<td class="form_header">Modified</td>
<td class="form_header">Mark</td>
</tr>
<%
	for( i=0; i<flst.length; i++ )
	{
		File f = flst[i];
		String fn = Util.htmlQuote( f.getName() );
		String fa = f.isDirectory() ? "DIR" : "&nbsp;";
		long ft = f.lastModified();
		String fd = (new Date(ft)).toString();
		String chk = (curt - ft) > diff ? " checked" : "";
%><tr>
<td class="form_body"><%=fn%></td>
<td class="form_body"><%=fa%></td>
<td class="form_body"><%=fd%></td>
<td class="form_body">
<input type="checkbox" name="mark" id="mark" value="<%=fn%>"<%=chk%>>
</td>
</tr>
<%
	}
%>
<tr>
<td colspan="4">
<input type="submit" name="btnDel" id="btnDel" value="Delete" class="btn">
</td>
</tr>
</table>
</form>

</BODY>
</HTML>
