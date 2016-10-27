<%@ page import="java.util.*, java.io.*, javax.servlet.http.*,
	org.genboree.dbaccess.*,
	org.genboree.util.*, org.genboree.upload.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%!
	static final File templateDir =
		new File( System.getProperty("catalina.home",org.genboree.util.Constants.GENBOREE_HTDOCS), "xmlTemplates" );
%>
<%
//    response.addDateHeader( "Expires", 0L );
//    response.addHeader( "Cache-Control", "no-cache, no-store" );
	if( request.getParameter("cmdBack") != null )
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

	Refseq[] rseqs = null;
	int i;

	if( myself != null && !myself.getUserId().equals(userInfo[2]) )
	{
		myself = null;
	}

	if( myself == null )
	{
		myself = new GenboreeUser();
		myself.setUserId( userInfo[2] );
		myself.fetch( db );
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
		mys.setAttribute( "myself", myself );
	}


	if( grps == null )
	{
        grps = GenboreeGroup.recreateteGroupList(db, myself.getUserId());
//        grps = GenboreeGroup.fetchAll( db, myself.getUserId() );
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
		if( grps == null ) grps = new GenboreeGroup[0];
//		mys.setAttribute( "GenboreeGroups", grps );
	}
	if( rseqs == null )
	{
		rseqs = Refseq.fetchAll( db, grps );
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
		if( rseqs == null ) rseqs = new Refseq[0];
//		mys.setAttribute( "RefSeqs", rseqs );
	}

	if( mys.getAttribute("vgp_reset") != null )
	{
		for( i=0; i<rseqs.length; i++ )
		{
			String myId = rseqs[i].getRefSeqId();
			mys.removeAttribute( "vgp:"+myId );
		}
		mys.removeAttribute( "vgp_file_default" );
		mys.removeAttribute( "vgp_reset" );
	}

	String dbRefSeqId = null;
	String rsName = request.getParameter( "db" );
	if( rsName != null )
	{
		for( i=0; i<rseqs.length; i++ )
		{
			if( !rseqs[i].isMerged() ) continue;
			String myId = rseqs[i].getRefSeqId();
			if( rseqs[i].getRefseqName().equals(rsName) ) dbRefSeqId = myId;
		}
	}

	String refSeqId = request.getParameter("refSeqId");
	if( refSeqId == null ) refSeqId = dbRefSeqId;
	if( refSeqId == null ) refSeqId = (String) mys.getAttribute( "refSeqId" );
	boolean is_new = false;

	if( refSeqId == null )
	{
		refSeqId = "#";
		for( i=0; i<rseqs.length; i++ )
		{
			if( !rseqs[i].isMerged() ) continue;
			String myId = rseqs[i].getRefSeqId();
			refSeqId = myId;
			break;
		}
		is_new = true;
	}
	else
	{
		String oldRefSeqId = (String) mys.getAttribute( "refSeqId" );
		if( oldRefSeqId==null || !oldRefSeqId.equals(refSeqId) ) is_new = true;
	}
	mys.setAttribute( "refSeqId", refSeqId );

	if( is_new ) mys.removeAttribute( "vgp_file_default" );

	String vgpKey = "vgp:"+refSeqId;
	VGPaint vgp = (VGPaint) mys.getAttribute( vgpKey );
  int userId = Util.parseInt(myself.getUserId(), -1);
  if( vgp == null && mys.getAttribute("vgp_file_uploaded")!=null )
		vgp = (VGPaint) mys.getAttribute( "VGPaint" );
	if( vgp == null )
	{
		vgp = new VGPaint();
		vgp.setDsnSource( "http://www.genboree.org" );
		if( vgp.initDBaccess(db, refSeqId, userId ) )
		{
			vgp.defineFcategory( "left", 1, "Left", "Left Header", "L" );
			vgp.defineFcategory( "right", 1, "Right", "Right Header", "R" );
			String dbName = vgp.getDatabaseName();
			if( dbName != null ) try
			{
				FileInputStream fin = new FileInputStream(
					new File(templateDir, "vgp_"+dbName+".xml") );
				vgp.deserialize( fin );
				fin.close();
				mys.setAttribute( "vgp_file_default", "y" );
			} catch( Exception ex01 ) {}
		}
	}
	else vgp.initDBaccess(db, refSeqId, userId );

//	mys.setAttribute( vgpKey, vgp );
	mys.setAttribute( "VGPaint", vgp );

	int ncats = vgp.getFcategoryCount();

	String displName = is_new ? null : request.getParameter("displName");
	if( displName != null ) vgp.setDescription( displName );

	if( !is_new )
	for( i=0; i<ncats; i++ )
	{
		VGPaint.VGPFcategory c = vgp.getFcategoryAt(i);
//		String catDesc = is_new ? null : request.getParameter( "catDesc"+i );
		String catDesc = request.getParameter( "catDesc"+i );
		if( catDesc != null ) c.setDescription( catDesc );
//		String catAbbr = is_new ? null : request.getParameter( "catAbbr"+i );
		String catAbbr = request.getParameter( "catAbbr"+i );
		if( catAbbr != null ) c.setAbbreviation( catAbbr );
	}

	if( refSeqId!=null && request.getParameter("cmdNext") != null )
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/vgp_step2.jsp" );
		return;
	}

	int __nrowspans = 4 + ncats;

%>

<HTML>
<head>
<title>VGP - Choose Reference Sequence</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY bgcolor="#DDE0FF">

<%@ include file="include/header.incl" %>
<%@ include file="include/navbar.incl" %>

<form name="vgp" action="vgp_step1.jsp" method="post">
  <table width="100%" border="0" cellpadding="4">
  <tbody>
  <tr>
	<td colspan="4">
<%@ include file="include/vgpnav.incl" %>
	</td>
  </tr>
  <tr>
	<td class="form_body"><strong>&nbsp;Reference Sequence:&nbsp;</strong></td>
	<td class="form_body" colspan="2">
		<select name="refSeqId" id="refSeqId" onchange='this.form.submit()'
		 class="txt" style="width:400">
<%
	for( i=0; i<rseqs.length; i++ )
	{
		if( !rseqs[i].isMerged() ) continue;
		String myId = rseqs[i].getRefSeqId();
		String sel = myId.equals(refSeqId) ? " selected" : "";
%><option value="<%=myId%>"<%=sel%>><%=rseqs[i].getRefseqName()%></option>
<%
	}
%>
        </select>
	</td>
  <tr>
	<td class="form_body"><strong>&nbsp;Displayed Name:&nbsp;</strong></td>
	<td class="form_body" colspan="2">
		<input type='text' name="displName" id="displName"
		value="<%=Util.htmlQuote(vgp.getDescription())%>"
		class="txt" style="width:400">
	</td>
  </tr>

  <tr>
	<td class="form_header">&nbsp;</td>
	<td class="form_header">Side Header</td>
	<td class="form_header">Abbreviation</td>
  </tr>
<%
	for( i=0; i<ncats; i++ )
	{
		VGPaint.VGPFcategory c = vgp.getFcategoryAt(i);
		String catDescLab = "catDesc"+i;
		String catAbbrLab = "catAbbr"+i;
%>
  <tr>
	<td class="form_body"><strong>&nbsp;<%=c.getName()%>&nbsp;Header</strong></td>
	<td class="form_body">
	  <input type="text" name="<%=catDescLab%>" id="<%=catDescLab%>"
	  value="<%=Util.htmlQuote(c.getDescription())%>"
	  class="txt" style="width:300">
	</td>
	<td class="form_body">
	  <input type="text" name="<%=catAbbrLab%>" id="<%=catAbbrLab%>"
	  value="<%=Util.htmlQuote(c.getAbbreviation())%>"
	  maxlength="1"
	  class="txt" style="width:80">
	</td>
  </tr>
<%
	}
%>
  <tr>
	<td colspan="3">
	<input name="cmdBack" type=submit value='<Back' style="width:100" class="btn">&nbsp;
	<input name="cmdNext" type=submit value='Next>' style="width:100" class="btn">
<% if(can_finish) { %>
	&nbsp;<input name="cmdFinish" type=submit value='Finish' style="width:100" class="btn">
<% } %>
	</td>
  </tr>
  </tbody>
  </table>

</form>

<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
