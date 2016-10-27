<%@ page import="java.util.*, java.io.*,
	java.awt.Dimension,
	javax.servlet.http.*, org.genboree.dbaccess.*,
	org.genboree.util.*, org.genboree.upload.*,
	org.genboree.svg.*,
	org.genboree.gdasaccess.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%!
    static {
      System.setProperty( "java.awt.headless", "true" );
    }
	static String[] fmtVal = { "gif", "png", "tiff" };
	static String[] fmtDesc = { "GIF", "PNG", "TIFF" };
	static String[] scVal = { "1", "1.5", "2", "3", "4", "5" };
	static int[] scNom = { 1, 3, 2, 3, 4, 5 };
	static int[] scDen = { 1, 2, 1, 1, 1, 1 };
	static final File galleryDir =
		new File( System.getProperty("catalina.home",org.genboree.util.Constants.GENBOREE_HTDOCS), "gallery" );
%>
<%
    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );
	
	String galleryId = request.getParameter( "id" );
	if( galleryId == null ) galleryId = (String) mys.getAttribute( "galleryId" );
	boolean is_gallery = false;
	VGPaint vgp0 = null;
	File galleryDirf = null;
	if( galleryId != null )
	{
		galleryDirf = new File( galleryDir, galleryId );
		if( galleryDirf.exists() && galleryDirf.isDirectory() ) try
		{
			File vgpf = new File( galleryDirf, "vgpdesign.xml" );
			vgp0 = new VGPaint( vgpf.getCanonicalPath() );
			is_gallery = true;
			mys.setAttribute( "VGPaint", vgp0 );
			mys.setAttribute( "vgp_gallerydir", galleryDirf );
		} catch( Exception ex00 )
		{
		}
	}
	
	if( !is_gallery )
	{
		mys.removeAttribute( "galleryId" );
		galleryId = null;
	}

	VGPaint vgp = (VGPaint) mys.getAttribute( "VGPaint" );
	File userDir = (File)mys.getAttribute( is_gallery ? "vgp_gallerydir" : "vgp_locdir" );
	if( vgp==null || userDir==null || !userDir.exists() ||
		request.getParameter("btnStart")!=null )
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/vgp.jsp" );
		return;
	}
	
	String acsCode = Refseq.fetchUserAccess( db, vgp.getDatabaseName(), userInfo[2] );
	
if( !is_gallery )
{
	if( request.getParameter("btnAddToGallery") != null )
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/vgp_addtogallery.jsp" );
		return;
	}
	
	if( request.getParameter("btnEdit")!=null )
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/vgp_step1.jsp" );
		return;
	}
	
	if( request.getParameter("btnBack")!=null )
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/vgp_step4.jsp" );
		return;
	}
}
else
{
	if( acsCode==null )
	{
		mys.setAttribute( "warnMsg",
			"<strong>Sorry, you do not have access to <i>"+
			Util.htmlQuote(vgp.getDescription())+
			"</i></strong>" );
		mys.setAttribute( "warnTgt", "VGPaint.jsp" );
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/warn.jsp" );
		return;
	}
}
	if( acsCode == null ) acsCode = "r";
	
	String webDir = (is_gallery ? "/gallery/" :	"/graphics/") +
		userDir.getName() + "/";

	String vgp_ver = (String)mys.getAttribute( "vgp_ver" );
	if( vgp_ver == null )
	{
		vgp_ver = "vgp_ver"+(new Date()).getTime();
		mys.setAttribute( "vgp_ver", vgp_ver );
	}
	
	int i;
	
	boolean is_creator = !( is_gallery || acsCode.equals("r") );

	File svgFile = new File( userDir, "refSeq.svg" );
	SVGDocument svgDoc = new SVGDocument( svgFile );
	Dimension d = svgDoc.getSize();
	
	String sfmt = request.getParameter( "viewAs" );
	if( sfmt != null )
	{
		mys.setAttribute( "vgpDisplayFormat", sfmt );
	}
	else
	{
		sfmt = (String)mys.getAttribute( "vgpDisplayFormat" );
	}
	if( sfmt == null ) sfmt = "gif";
	boolean is_gif = sfmt.equals("gif");

	String baseFnam = svgFile.getName();
	int idx = baseFnam.lastIndexOf('.');
	if( idx > 0 ) baseFnam = baseFnam.substring( 0, idx );
	String gifFnam = baseFnam + ".gif";
	
	String chkGif = "";
	String chkSvg = " checked";

	if( is_gif )
	{
		chkGif = chkSvg;
		chkSvg = "";
		File gifFile = new File( userDir, gifFnam );
		if( !gifFile.exists() || gifFile.length()==0 ) try
		{
			FileOutputStream fout = new FileOutputStream( gifFile );
			svgDoc.export( fout, "gif", 2., null );
			fout.close();
		} catch( Exception ex01 )
		{
			db.reportError( ex01, "vgp_view.jsp:export" );
			if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
		}
	}
	mys.setAttribute( "vgpRefSeq", svgFile );
	
	String dnfmt = null;
	String dnscale = null;
	String ckval = "-- none --";
	Cookie[] cks = request.getCookies();
	if( cks != null )
	for( i=0; i<cks.length; i++ )
	{
		if( !cks[i].getName().equals("vgpcfg") ) continue;
		ckval = cks[i].getValue();
		String[] ss = Util.parseString( ckval, '&' );
		for( int j=0; j<ss.length; j++ )
		{
			String s = ss[j];
			if( s.startsWith("sc:") ) dnscale = s.substring(3);
			else if( s.startsWith("fmt:") ) dnfmt = s.substring(4);
		}
	}
	
	String backParam = is_gallery ? "?id="+galleryId : "";

	if( dnfmt == null ) dnfmt = (String)mys.getAttribute( "vgp_dnfmt" );
	if( dnfmt == null ) dnfmt = "gif";
	mys.setAttribute( "vgp_dnfmt", dnfmt );
	if( dnscale == null ) dnscale = (String)mys.getAttribute( "vgp_dnscale" );
	if( dnscale == null ) dnscale = "2";
	mys.setAttribute( "vgp_dnscale", dnscale );

	String fileName = (String) mys.getAttribute( "vgpDesignFile" );
	
	String zipName = fileName;
	if( zipName == null ) zipName = "all_images";
	idx = zipName.lastIndexOf( '.' );
	if( idx > 0 ) zipName = zipName.substring( 0, idx );
	zipName = "vgp_"+zipName;
	
	mys.setAttribute( zipName, userDir );

%>

<HTML>
<head>
<title>VGP - View Result</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY>
<SCRIPT type="text/javascript" src="/javaScripts/cookie.js<%=jsVersion%>"></SCRIPT>
<SCRIPT type="text/javascript">
var cfgCookie = new Cookie( document, "vgpcfg" );
if( !cfgCookie.load() || !cfgCookie.sc || !cfgCookie.fmt )
{
  cfgCookie.sc = "<%=dnscale%>";
  cfgCookie.fmt = "<%=dnfmt%>";
}
function UpdateCookie()
{
  cfgCookie.store();
}
function ChangeScale( val )
{
  cfgCookie.sc = val;
  UpdateCookie();
}
function ChangeFormat( val )
{
  cfgCookie.fmt = val;
  UpdateCookie();
}
</SCRIPT>


<form action="vgp_view.jsp<%=backParam%>" method="post">

<table border="0" cellpadding="4" cellspacing="0">

<tr>
<td colspan="3" bgcolor="white">
<%@ include file="include/navbar.incl" %>
</td>
</tr>

<tr>
<td colspan="2" class="form_header"><%=vgp.getDescription()%>
</td>
<td class="form_header" align="right">
<font color="#eae6ff">View As</font>&nbsp;&nbsp;
<input type="radio" name="viewAs" id="viewAs"
 onClick="this.form.submit()"
 value="gif"<%=chkGif%>>GIF&nbsp;&nbsp;
<input type="radio" name="viewAs" id="viewAs"
 onClick="this.form.submit()"
 value="svg"<%=chkSvg%>>SVG
</td>
</tr>

<tr>
<td colspan="3" bgcolor="white" align="center">

<% if( is_gif ) { %>
<map name="vgpimgmap">
<%
	SVGDocument.MapElement[] mes = svgDoc.getImageMap();
	for( i=0; i<mes.length; i++ )
	{
		SVGDocument.MapElement mel = mes[i];
		int x0 = mel.rect.x;
		int y0 = mel.rect.y;
		int x1 = x0 + mel.rect.width - 1;
		int y1 = y0 + mel.rect.height - 1;
%><area href="<%=mel.href%>" SHAPE="rect" coords="<%=x0%>,<%=y0%>,<%=x1%>,<%=y1%>">
<%
	}
%>
</map>

<img src="<%=webDir%><%=gifFnam%>?<%=vgp_ver%>"
	width="<%=d.width%>" height="<%=d.height%>"
	usemap=#vgpimgmap ismap
	border="0">
<% } else { %>
<EMBED TYPE="image/svg+xml"
	SRC="<%=webDir%><%=svgFile.getName()%>"
	WIDTH="<%=d.width%>"
	HEIGHT="<%=d.height%>"
	ALIGN="CENTER"
	MEMORY="15"
	PLUGINSPAGE="http://www.adobe.com/svg/viewer/install/main.html"> 
</EMBED>
<% } %>

</td>
</tr>

<tr>
<td class="form_body" colspan="3">
<i>Graphics Format:</i><%
	for( i=0; i<fmtVal.length; i++ )
	{
		String sel = dnfmt.equals(fmtVal[i]) ? " checked" : "";
%><input type="radio" name="dnfmt" id="dnfmt"
	onclick="ChangeFormat(this.value)"
	value="<%=fmtVal[i]%>"<%=sel%>><strong><%=fmtDesc[i]%></strong>&nbsp;
<%
	}
%>
&nbsp;&nbsp;
<i>Scale:</i>
<select name="dnscale" id="dnscale"
	onchange="ChangeScale(this.value)"
	class="txt"><%
	for( i=0; i<scVal.length; i++ )
	{
		String sel = dnscale.equals(scVal[i]) ? " selected" : "";
		String desc = scVal[i]+"x ("+(d.width*scNom[i])/scDen[i]+" by "+
			(d.height*scNom[i])/scDen[i]+" px)";
%><option value="<%=scVal[i]%>"<%=sel%>><%=desc%></option>
<%
	}
%>
</select>
&nbsp;
<input type="button" value="Download Image"
	onClick="javascript:document.location.href='<%=GenboreeUtils.returnFullURL(request, "/java-bin/servlets/VGPDownloader?src=vgpRefSeq&fmt='+cfgCookie.fmt+'&d=a&scale='+cfgCookie.sc")%>;" class="btn">
	</td>
</tr>

<tr>
  <td class="form_body" colspan="3">
<input type="button" value="Download All Images"
	onClick="javascript:document.location.href='<%=GenboreeUtils.returnFullURL(request, "/java-bin/servlets/VGPDownloader?src=" + Util.urlEncode(zipName) + "&fmt='+cfgCookie.fmt+'&d=a&scale='+cfgCookie.sc")%>;" class="btn">
  </td>
</tr>

<tr>
	<td colspan="3" style="height:8"></td>
</tr>

<% if( !is_gallery) { %>
<tr>
	<td colspan="3">
	<input type="submit" name="btnBack" id="btnBack" value="&nbsp;&lt;Back&nbsp;" class="btn">
	<input type="submit" name="btnStart" id="btnStart" value="Make New Design" class="btn">
	&nbsp;
<% if( fileName != null ) { %>
	<input type="button" value="Save Design" onclick="javascript:document.location.href='<%=GenboreeUtils.returnFullURL(request, "/java-bin/servlets/FileRetriever?f=" + fileName + "&s=vgpsv&d=a")%>';" class="btn">
<% } %>
	<input type="submit" name="btnEdit" id="btnEdit" value="Edit Design" class="btn">
<% if( is_creator ) { %>
	&nbsp;
	<input type="submit" name="btnAddToGallery" id="btnAddToGallery"
	value="Add To Gallery" class="btn">
<% } %>
	</td>
</tr>
<% } // if( !is_gallery) %>

</table>

</form>

</BODY>
</HTML>
