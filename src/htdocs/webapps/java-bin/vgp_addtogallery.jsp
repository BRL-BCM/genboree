<%@ page import="java.util.*, java.io.*, java.security.*,
	java.awt.Dimension,
	javax.servlet.http.*, org.genboree.dbaccess.*,
	org.genboree.util.*, org.genboree.upload.*,
	org.genboree.svg.*,
	org.genboree.gdasaccess.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%!
	static final File galleryDir =
		new File( System.getProperty("catalina.home",org.genboree.util.Constants.GENBOREE_HTDOCS), "gallery" );
	static
	{
		try
		{
			if( !galleryDir.exists() ) galleryDir.mkdir();
		} catch( Exception ex ) {}
	}

	static String requestUniqueDir()
	{
		int iprf = 0;
		String pref = ""+iprf;
		String _suff = Util.generateUniqueString(pref) ;
		if( _suff == null ) return null;
		File f = new File( galleryDir, _suff );
		while( f.exists() )
		{
			iprf++;
			pref = ""+iprf;
			_suff = Util.generateUniqueString(pref);
			if( _suff == null ) return null;
			f = new File( galleryDir, _suff );
		}
		return _suff;
	}
%>
<%
	int i;

	VGPaint vgp = (VGPaint) mys.getAttribute( "VGPaint" );
	File userDir = (File)mys.getAttribute( "vgp_locdir" );
	if( vgp==null || userDir==null || !userDir.exists() ||
		!galleryDir.exists() || !galleryDir.isDirectory() )
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/vgp.jsp" );
		return;
	}

	String tgtId = requestUniqueDir();
	File tgtDir = new File( galleryDir, tgtId );
	tgtDir.mkdir();

	File f = new File( tgtDir, "vgpdesign.xml" );
	FileOutputStream fos = new FileOutputStream( f );
	vgp.serialize( fos );
	fos.close();

	f = new File( tgtDir, "dirinfo" );
	Properties props = new Properties();
	props.setProperty( "databaseName", vgp.getDatabaseName() );
	props.setProperty( "description", vgp.getDescription() );
	props.setProperty( "creator", userInfo[2] );
	fos = new FileOutputStream( f );
	props.store( fos, "Machine generated file. Do not modify." );
	fos.close();

	File[] flist = userDir.listFiles();
	for( i=0; i<flist.length; i++ )
	{
		f = flist[i];
		String fn = f.getName();
		if( !fn.toLowerCase().endsWith(".svg") ) continue;
		BufferedReader fin = new BufferedReader( new FileReader(f) );
		PrintWriter fout = new PrintWriter( new FileWriter( new File(tgtDir,fn) ) );
		String s = null;
		while( (s = fin.readLine()) != null )
		{
			int idx = s.indexOf( "xlink:href=\"/java-bin/EPWrapper.jsp?EP=" );
			if( idx > 0 )
			{
				idx = s.lastIndexOf( "\">" );
				if( idx > 0 ) s = s.substring(0,idx) + "&amp;id=" + tgtId + s.substring(idx);
			}
			fout.println( s );
		}
		fout.flush();
		fout.close();
		fin.close();
	}

	String tgtUrl = "/java-bin/vgp_view.jsp" + "?id="+tgtId;

	f = new File( tgtDir, "index.html" );
	PrintWriter ffout = new PrintWriter( new FileWriter(f) );

	ffout.println( "<html><body onload=\"location.replace('"+tgtUrl+"')\">" );
	ffout.println( "This page has been moved to another location.<br>" );
	ffout.println( "If your browser does not redirect automatically, "+
		"<a href=\""+tgtUrl+"\">click here</a>." );
	ffout.println( "</body></html>" );

	ffout.flush();
	ffout.close();

%>

<HTML>
<head>
<title>Add VGP View To Gallery</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY>
<%@ include file="include/header.incl" %>

<br>
<p>A new entry <a href="<%=tgtUrl%>"><%=Util.htmlQuote(vgp.getDescription())%></a>
has been successfully added to the VGP Gallery. To access it, use the following URL:</p>
<p align="center"><a href="<%=tgtUrl%>">http://<%=Constants.REDIRECTTO%><%=tgtUrl%></a></p>

<p>Click <a href="defaultGbrowser.jsp">here</a> to go back to Genboree.</p>

<p>&nbsp;</p>

<%@ include file="include/footer.incl" %>
</BODY>
</HTML>
