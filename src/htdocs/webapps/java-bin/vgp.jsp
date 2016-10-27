<%@ page import="java.util.*, java.util.zip.*,
	javax.servlet.http.*, org.genboree.dbaccess.*,
	org.genboree.util.*, org.genboree.upload.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%
    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );
	mys.removeAttribute( "vgpsv" );
	
	if( userInfo[0].equals("Public") )
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/login.jsp" );
		return;
	}
	
	int i;

	if( request.getParameter("btnCancel") != null )
	{
		GenboreeUtils.sendRedirect(request,response, "/java-bin/index.jsp");
		return;
	}


	
    long totalBytes = request.getContentLength();
    mys.setAttribute( "totalBytes", new Long(totalBytes * 4) );
	boolean need_edit = false;
	boolean cmdNext = false;
	VGPaint vgp = null;

	String contType = request.getContentType();
	String lContType = contType==null ? "" : contType.toLowerCase();
	if( lContType.startsWith("multipart/form-data") )
	{
		HttpPostInputStream hpIn =
			new HttpPostInputStream( request.getInputStream(), mys );
		while( hpIn.nextPart() )
		{
		  String cn = hpIn.getPartAttrib( "name" );
		  String fn = hpIn.getPartAttrib( "filename" );
		  String ct = hpIn.getPartAttrib( "Content-Type" );
		  if( cn.equals("need_edit") ) need_edit = true;
		  if( cn.equals("cmdNext") ) cmdNext = true;
		  if( !cn.equals("upload_vgp") ) continue;
		  try
		  {
			  if( ct.startsWith("application/x-zip") )
			  {
				 ZipInputStream zin = new ZipInputStream( hpIn );
				 ZipEntry zen;
				 if( (zen=zin.getNextEntry()) != null )
				 {
					vgp = new VGPaint();
					vgp.deserialize( zin );
				 }
			  }
			  else if( ct.startsWith("application/x-gzip") )
			  {
				vgp = new VGPaint();
				vgp.deserialize( new GZIPInputStream(hpIn) );
			  }
			  else
			  {
				vgp = new VGPaint();
				vgp.deserialize( hpIn );
			  }
		  } catch( Exception ex00 ) { vgp=null; }
		}
	}
	
	String vgpUploadedKey = "vgp_file_uploaded";
	String vgpKey = "VGPaint";	
	mys.removeAttribute( vgpUploadedKey );
	mys.removeAttribute( vgpKey );
    Refseq[] rseqs = null;
    if (cmdNext) {
        String refSeqId = "#";
        if (vgp != null) {
            mys.setAttribute(vgpUploadedKey, "1");
            mys.setAttribute(vgpKey, vgp);
            refSeqId = vgp.fetchRefSeqId(db);
            if (refSeqId.equals("#")) {
                need_edit = true;
            } else {

                rseqs = Refseq.recreateteRefseqListFromGroup(db, grps);
                if (rseqs == null) {
                    rseqs = Refseq.fetchAll(db, grps);
                    if (JSPErrorHandler.checkErrors(request, response, db, mys)) return;
                }
                Refseq rseq = null;
				for( i=0; i<rseqs.length; i++ )
				if( rseqs[i].getRefSeqId().equals(refSeqId) )
				{
					rseq = rseqs[i];
					break;
				}
				if( rseq == null )
				{
					mys.setAttribute( "warnMsg",
						"<strong>Sorry, you do not have access to the "+
						"database ID="+refSeqId+"</strong>" );
					mys.setAttribute( "warnTgt", "vgp.jsp" );
					GenboreeUtils.sendRedirect(request,response,  "/java-bin/warn.jsp" );
					return;
				}
		    int userId = Util.parseInt(myself.getUserId(), -1);
				String descr = vgp.getDescription();
				String dsn = vgp.getDsnSource();
				vgp.initDBaccess( db, refSeqId, userId );
				vgp.setDsnSource( dsn );
				vgp.setDescription( descr );

				if( !need_edit )
				{
					vgp.fetchEntryPoints( db );
					vgp.updateTracksAndColors( db, false, userInfo[2] );
					vgp.validateFtypes();
				}

				mys.setAttribute( "refSeqId", refSeqId );
//				mys.setAttribute( "vgp:"+refSeqId, vgp );
			}
		}
		else need_edit = true;
		String tgt = need_edit ? "/java-bin/vgp_step1.jsp" : "/java-bin/vgp_step4.jsp";
		mys.setAttribute( "vgp_reset", "yes" );
		GenboreeUtils.sendRedirect(request,response,  tgt );
		return;
	}
%>

<HTML>
<head>
<title>VGP - Main</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY bgcolor="#DDE0FF">

<%@ include file="include/header.incl" %>
<%@ include file="include/navbar.incl" %>

<form name="vgp" action="vgp.jsp" method="post"
  ENCTYPE="multipart/form-data">
  <input id="cmdNext" name="cmdNext" type="hidden" value='Next'>
  <table width="100%" border="0" cellpadding="4">
  <tbody>
  <tr>
  	<td class="form_body" valign="top">
	  <strong>Use&nbsp;Existing Visualization&nbsp;Design</strong>
	</td>
  	<td class="form_body">
	  <input type="file" id="upload_vgp" name="upload_vgp"
		 class="txt" style="width:440"><br>
	  <input type="submit" name="need_edit" id="need_edit"
	    class="btn" style="width:100"
	   value="Edit">&nbsp;
	  <input type="submit" name="view_only" id="view_only"
	    class="btn" style="width:100"
	   value="View">
	</td>
  </tr>
  <tr>
	<td colspan="2">
	  <input type="button" value="Make A New Design"
	  onclick="document.vgpnew.submit()" class="btn" >
	  <input type="button" name="btnCancel" class="btn" 
	value="&nbsp;Cancel&nbsp;" onclick="document.cancelForm.submit()">
	</td>
  </tr>
  </tbody>
  </table>
</form>

<form name="cancelForm" id="cancelForm" action="vgp.jsp" method="post">
  <input id="btnCancel" name="btnCancel" type="hidden" value='cancel'>
</form>

<form name="vgpnew" action="vgp.jsp" method="post"
  ENCTYPE="multipart/form-data">
  <input id="cmdNext" name="cmdNext" type="hidden" value='Next'>
</form>

<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
