<%@ page import="javax.servlet.http.*, java.io.*, java.util.*, org.genboree.dbaccess.*, org.genboree.util.*, org.genboree.upload.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%!
	static final File galleryDir =
		new File( System.getProperty("catalina.home",org.genboree.util.Constants.GENBOREE_HTDOCS), "gallery" );

	static String[] modeIds =
	{
		"VGPaint", "Gallery"
	} ;
	static String[] modeLabs =
	{
		"VGPaint", "VGP&nbsp;Gallery"
	} ;
	static final int MODE_DEFAULT = -1;
	static final int MODE_VGPAINT = 0;
	static final int MODE_GALLERY = 1;

%>
<%
  response.addDateHeader( "Expires", 0L ) ;
  response.addHeader( "Cache-Control", "no-cache, no-store" ) ;

	int i ;

	String pMode = request.getParameter("mode") ;
	int mode = MODE_DEFAULT ;
	if( pMode != null )
  {
    for( i=0; i<modeIds.length; i++ )
    {
      if( pMode.equals(modeIds[i]) )
      {
      	mode = i ;
      	break ;
      }
    }
  }

  if( userInfo == null )
  {
    String qs = request.getQueryString();
    if( qs == null )
    {
      qs = "" ;
    }
    else
    {
      qs = "?"+qs ;
    }
    mys.setAttribute( "target", request.getRequestURL().toString()+qs ) ;
    GenboreeUtils.sendRedirect(request,response,  "/java-bin/login.jsp" ) ;
    return;
  }

	String destback = "tools.jsp";
	mys.setAttribute( "destback", destback );

	if( is_public ) mode = MODE_GALLERY;

	if( !is_public )
	{
		String delId = request.getParameter("delId");
		String editId = request.getParameter("editId");
		File dirFile = null;
		String fid = delId;
		if( fid == null ) fid = editId;
		if( fid != null ) try
		{
			dirFile = new File( galleryDir, fid );
			if( !dirFile.exists() || !dirFile.isDirectory() ) dirFile = null;
			File infoFile = new File( dirFile, "dirinfo" );
			Properties props = new Properties();
			FileInputStream fin = new FileInputStream( infoFile );
			props.load( fin );
			fin.close();
			String dbName = props.getProperty( "databaseName" );
			String acsCode = Refseq.fetchUserAccess( db, dbName, userInfo[2] );
			if( acsCode == null ) dirFile = null;
			else if( acsCode.equals("r") && delId != null ) dirFile = null;
		} catch( Exception ex00 ) { dirFile = null; }

		if( dirFile != null && delId != null ) try
		{
			FileKiller.clearDirectory( dirFile );
			dirFile.delete();
			mode = MODE_GALLERY;
		} catch( Exception ex01 ) {}

		if( dirFile != null && editId != null ) try
		{
			File f = new File( dirFile, "vgpdesign.xml" );
      int userId = Util.parseInt(myself.getUserId(), -1);
      if( f.exists() )
			{
				FileInputStream fin = new FileInputStream( f );
				VGPaint vgp = new VGPaint();
				vgp.deserialize( fin );
				fin.close();
				mys.setAttribute( "vgp_file_uploaded", "1" );
				mys.setAttribute( "VGPaint", vgp );
				String refSeqId = vgp.fetchRefSeqId( db );
				if( !refSeqId.equals("#") )
				{
					String descr = vgp.getDescription();
					String dsn = vgp.getDsnSource();
					vgp.initDBaccess( db, refSeqId, Util.parseInt(myself.getUserId(), -1));
					vgp.setDsnSource( dsn );
					vgp.setDescription( descr );
					mys.setAttribute( "refSeqId", refSeqId );
				}
				mys.setAttribute( "vgp_reset", "yes" );
				GenboreeUtils.sendRedirect(request,response,  "/java-bin/vgp_step1.jsp" );
				return;
			}
		} catch( Exception ex02 ) {}
	}
%>

<HTML>
<head>
<title>Genboree - Tools</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
    <style type="text/css">

     div {
        text-align:left;
        font-size:medium;
        font-weight:normal;
   }
    div.highliter{
      background-color:LightCyan ;
    }

</style>
</head>
<BODY>

<%@ include file="include/header.incl" %>
<%@ include file="include/navbar.incl" %>

<% if( !is_public ) { %>
<table border="0" cellspacing="4" cellpadding="2">
<tr>
<%
	for( i=0; i<modeIds.length; i++ )
	{
		String cls = "nav";
		String a1 = "<a href=\"tools.jsp?mode="+modeIds[i]+"\">";
		String a2 = "</a>";
		if( i == mode )
		{
			cls = "nav_selected";
			a1 = a1 + "<font color=white>";
			a2 = "</font>" + a2;
		}
%><td class="<%=cls%>"><%=a1%><%=modeLabs[i]%><%=a2%></td>
<%
	}
%>
	<td class="nav">
	<a href="trackOps.jsp">Track&nbsp;Operations</a>
	</td>

    <td class="nav">
	<a href="toolPluginsWrapper.jsp">Plug-ins</a>
	</td>

    <td class="nav">
	<a href="toolPluginsResults.jsp">Plug-in Results</a>
	</td>

</tr>
</table>
<% } // !is_public %>

<% if( mode == MODE_VGPAINT || mode == MODE_GALLERY ) { %>
&nbsp;<br>
<table border="0" cellspacing="0" cellpadding="2" width="100%"><tbody>

<div>
<p>The current version of vgp will be replaced by a totally new rewrite very soon.
  We do not have a definitive release date yet, but
  we are currently working on it and we will post any updates when information become available.</p>
  <br />
  <p><strong>Thank you for your Patience</strong>.</p>
  </div>
<div class="highliter">

<p><A HREF='mailto:genboree_admin@genboree.org'>For any questions or concerns please feel free to contact us.</A></p>

</div>


</tbody></table>
<% } // MODE_VGPAINT %>



<% if( mode == MODE_DEFAULT ) { %>
    <table border="0" cellspacing="0" cellpadding="2" width="100%"><tbody>
    <tr>
    	<td align="center" valign="middle" height="24">
    	  <IMG height=1 alt="" src="/images/bluemed1px.gif" width="480" border="0">
    	</td>
  	</tr>
  	<tr>
    	<td align="center">
    	  ( Select a functionality from the sub-menu )
    	</td>
    </tr>
    </table>
<% } %>



<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
