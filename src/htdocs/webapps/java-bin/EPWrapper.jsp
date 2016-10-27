<%@ page import="javax.servlet.http.*,
	java.util.*, java.io.*, org.genboree.util.*,
	java.awt.Dimension,
	org.genboree.svg.*,
	org.genboree.dbaccess.*, org.genboree.util.*, org.genboree.upload.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%!
	static String[] fmtVal = { "gif", "png", "tiff" };
	static String[] fmtDesc = { "GIF", "PNG", "TIFF" };
	static String[] scVal = { "1", "1.5", "2", "3", "4", "5" };
	static int[] scNom = { 1, 3, 2, 3, 4, 5 };
	static int[] scDen = { 1, 2, 1, 1, 1, 1 };
	static final File galleryDir =
		new File( System.getProperty("catalina.home", org.genboree.util.Constants.GENBOREE_HTDOCS), "gallery" );
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
			mys.setAttribute( "VGPaint", vgp0 );
			mys.setAttribute( "vgp_gallerydir", galleryDirf );
			is_gallery = true;
		} catch( Exception ex00 ) {}
	}
	
	if( !is_gallery )
	{
		mys.removeAttribute( "galleryId" );
		galleryId = null;
	}

	VGPaint vgp = (VGPaint) mys.getAttribute( "VGPaint" );
	String abbr = request.getParameter( "EP" );
	String baseFnam = abbr;
	File userDir = (File)mys.getAttribute( is_gallery ? "vgp_gallerydir" : "vgp_locdir" );
	if( vgp==null || baseFnam==null || userDir==null || !userDir.exists() )
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/vgp.jsp" );
		return;
	}

	String webDir = (is_gallery ? "/gallery/" :	"/graphics/") +
		userDir.getName() + "/";
	
	int i;

	baseFnam = "EP" + baseFnam;
	
	File svgFile = new File( userDir, baseFnam+".svg" );
	SVGDocument svgDoc = new SVGDocument( svgFile );
	Dimension d = svgDoc.getSize();

	String sfmt = (String)mys.getAttribute( "vgpDisplayFormat" );
	if( sfmt == null ) sfmt = "gif";
	boolean is_gif = sfmt.equals("gif");

	String gifFnam = baseFnam + ".gif";

	String vgp_ver = (String)mys.getAttribute( "vgp_ver" );
	if( vgp_ver == null )
	{
		vgp_ver = "vgp_ver"+(new Date()).getTime();
		mys.setAttribute( "vgp_ver", vgp_ver );
	}

	if( is_gif )
	{
		File gifFile = new File( userDir, gifFnam );
		if( !gifFile.exists() || gifFile.length()==0 )
		{
			FileOutputStream fout = new FileOutputStream( gifFile );
			svgDoc.export( fout, "gif", 2., null );
			fout.close();
		}
	}
	
	String dnldId = "vgp"+baseFnam;
	mys.setAttribute( dnldId, svgFile );

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
%>

<HTML>
<head>
<title>VGP - Entry Point</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY>
<SCRIPT type="text/javascript" src="/javaScripts/cookie.js<%=jsVersion%>" ></SCRIPT>
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

<table border="0" cellpadding="4" cellspacing="2">

<% if( !is_gallery ) { %>
<tr>
<td colspan="3" bgcolor="white">
<%@ include file="include/navbar.incl" %>
</td>
</tr>
<% } %>

<tr>
<td colspan="3" class="form_header"><%=vgp.getDescription()%>: <%=abbr%>
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
<EMBED	TYPE="image/svg+xml"
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
	value="<%=fmtVal[i]%>"<%=sel%>><strong><%=fmtDesc[i]%></strong>
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
	onClick="javascript:document.location.href='<%=GenboreeUtils.returnFullURL(request, "/java-bin/servlets/VGPDownloader?src=" + dnldId + "&fmt='+cfgCookie.fmt+'&d=a&scale='+cfgCookie.sc")%>;" class="btn">
</td>
</tr>

<tr>
	<td colspan="3" style="height:8"></td>
</tr>

<tr>
	<td colspan="3">
	<input type="submit" name="btnBackEP" id="btnBackEP" value="&nbsp;&lt;Back&nbsp;" class="btn">
	</td>
</tr>

</table>

</form>

</BODY>
</HTML>
