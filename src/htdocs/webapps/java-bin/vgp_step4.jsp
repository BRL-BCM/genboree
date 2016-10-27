<%@ page import="java.util.*, java.io.*, javax.servlet.http.*, org.genboree.dbaccess.*,
	org.genboree.svg.image.*,
	org.genboree.util.*, org.genboree.upload.*, org.genboree.gdasaccess.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%!
    static {
      System.setProperty( "java.awt.headless", "true" );
    }
	static final File templateDir =
		new File( System.getProperty("catalina.home",org.genboree.util.Constants.GENBOREE_HTDOCS), "xmlTemplates" );
	static final File graphicsDir =
		new File( System.getProperty("catalina.home",org.genboree.util.Constants.GENBOREE_HTDOCS), "graphics" );
	static File requestUniqueDir( String _prefix )
	{
		int suff = 1;
		File rc = new File( graphicsDir, _prefix+"_"+suff );
		while( rc.exists() )
		{
			suff++;
			rc = new File( graphicsDir, _prefix+"_"+suff );
		}
		return rc;
	}
%>
<%
    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );
	if( request.getParameter("cmdBack") != null )
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/vgp_step3.jsp" );
		return;
	}
	int i;
	VGPaint vgp = (VGPaint) mys.getAttribute( "VGPaint" );
	if( vgp == null )
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/vgp.jsp" );
		return;
	}
	
	ByteArrayOutputStream bout = new ByteArrayOutputStream();
	vgp.serialize( bout );
	String vgpBody = bout.toString();
	bout = null;
	mys.setAttribute( "vgpsv", vgpBody );
	
	boolean is_creator = false;
	try
	{
		if( vgp.getRefseq().getUserId().equals(userInfo[2]) ) is_creator = true;
	} catch( Exception ex02 ) {}
	
	File templFile = new File( templateDir, "vgp_"+vgp.getDatabaseName()+".xml" );
	if( ((request.getParameter("cmdSave")!=null) || !templFile.exists()) &&
		is_creator )
	try
	{
		PrintStream fout = new PrintStream(
			new FileOutputStream(templFile) );
		fout.print( vgpBody );
		fout.flush();
		fout.close();
	} catch( Exception ex01 ) {}
	
	String fileName = vgp.getDescription();
	if( Util.isEmpty(fileName) )
	{
		java.text.SimpleDateFormat fmt = new java.text.SimpleDateFormat( "yyyyMMddHHmmss" ); 
		fileName = "vgp"+userInfo[2]+"-"+fmt.format(new Date());
	}
	else
	{
		fileName = fileName.replace( ' ', '_' );
		fileName = fileName.replace( '.', '-' );
		fileName = fileName.replace( '*', '-' );
	}
	fileName = Util.urlEncode( fileName + ".xml" );
	
	mys.setAttribute( "vgpDesignFile", fileName );
	
	if( request.getParameter("cmdNext") != null )
	{
		String fmt = request.getParameter( "fmt" );
		if( fmt == null ) fmt = "svg";
		mys.setAttribute( "vgp_format", fmt );

		// prepare the directory and files
		if( !graphicsDir.exists() ) graphicsDir.mkdir();

		int userId = Util.parseInt(userInfo[2],0);
		
		File userDir = (File) mys.getAttribute( "vgp_locdir" );
		if( userDir == null )
		{
			userDir = requestUniqueDir( "vgp_"+userInfo[0] );
//			FileKiller fk = (FileKiller) mys.getAttribute( "FileKiller" );
//			if( fk == null )
//			{
//				fk = new FileKiller( "genb", ".lff" );
//				mys.setAttribute( "FileKiller", fk );
//			}
//			fk.put( userDir.getName(), userDir );
			mys.setAttribute( "vgp_locdir", userDir );
		}
		String dirName = userDir.getName();
		
		if( userDir.exists() )
		{
			if( userDir.isDirectory() )
			{
				FileKiller.clearDirectory( userDir );
			}
			else userDir.delete();
		}
		if( !userDir.exists() )
		{
			userDir.mkdir();
		}
		
		String absUserDir = userDir.getAbsolutePath();
		try
		{
			absUserDir = userDir.getCanonicalPath();
		} catch( Exception ex01 ) {}
		
		ImageGenerator imgGen = new ImageGenerator( vgp, userId, absUserDir );
		
		String vgp_ver = "vgp_ver"+(new Date()).getTime();
		mys.setAttribute( "vgp_ver", vgp_ver );

		String sfmt = request.getParameter( "fmt" );
		if( sfmt == null ) sfmt = "gif";
		else if( !sfmt.equals("svg") ) sfmt = "gif";
		mys.setAttribute( "vgpDisplayFormat", sfmt );
		
		mys.removeAttribute( "galleryId" );
		
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/vgp_view.jsp" );
		return;
	}
%>

<HTML>
<head>
<title>VGP - Select Format</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY>
<%@ include file="include/header.incl" %>
<%@ include file="include/navbar.incl" %>

<form name="vgp" action="vgp_step4.jsp" method="post">
  <table width="100%" border="0" cellpadding="4">
  <tbody>

  <tr>
	<td colspan="2">
<%@ include file="include/vgpnav.incl" %>
	</td>
  </tr>

  <tr>
  	<td class="form_body"><strong>&nbsp;Graphics Format</strong>
	</td>
  	<td class="form_body" width="60%">
	  <input type="radio" name="fmt" id="fmt" value="gif" checked>GIF&nbsp;&nbsp;
	  <input type="radio" name="fmt" id="fmt" value="svg">SVG
	</td>
  </tr>
  <tr>
  	<td colspan="2">
	<a href="<%=GenboreeUtils.returnFullURL(request, "/java-bin/servlets/FileRetriever?f=" + fileName + "&s=vgpsv")%>">Click here to download your Visualization Design</a>
	</td>
  </tr>

  <tr>
	<td colspan="2">
	  <input name="cmdBack" type=submit value='<Back' style="width:90">&nbsp;
	  <input name="cmdNext" type=submit value='View>' style="width:100">
<% if( is_creator ) { %>
	  &nbsp;<input name="cmdSave" type=submit value='Save Template' style="width:140">
<% } %>
	</td>
  </tr>

  <tr>
	<td colspan="2">&nbsp;</td>
  </tr>

  </tbody>
  </table>
</form>

<%@ include file="include/footer.incl" %>
</BODY>
</HTML>
