<%@ page import="javax.servlet.http.*, java.util.*, java.sql.*,
	org.genboree.dbaccess.*,
	org.genboree.util.*, org.genboree.upload.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%
    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );
	
	int i;
	String tgtBack = "/java-bin/trackmgr.jsp?mode=Classify";
	
	if( request.getParameter("btnCancel") != null )
	{
		GenboreeUtils.sendRedirect(request,response,  tgtBack );
		return;
	}
	
	Refseq rseq = (Refseq) mys.getAttribute( "clsRseq" );
	DbFtype trk = (DbFtype) mys.getAttribute( "clsTrack" );
	Vector vRem = (Vector) mys.getAttribute( "remClsIds" );
	DbGclass[] gclasses = (DbGclass[]) mys.getAttribute( "gclasses" );

	if( rseq==null || trk==null || vRem==null || gclasses==null )
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/login.jsp" );
		return;
	}
	
	Hashtable htClsId = new Hashtable();
	for( i=0; i<gclasses.length; i++ )
	{
		String clsId = ""+gclasses[i].getGid();
		htClsId.put( clsId, gclasses[i] );
	}

	if( request.getParameter("btnApply") != null )
	{
		int cnt = 0;
		String trkId = ""+trk.getFtypeid();
		Connection conn = db.getConnection( rseq.getDatabaseName() );
		for( i=0; i<vRem.size(); i++ )
		{
			String clsId = (String) vRem.elementAt(i);
			String ctlId = "cls_"+clsId;
			String newClsId = request.getParameter( ctlId );
			if( newClsId == null ) continue;
			cnt += DbFtypeGroup.updateFdata( conn, trkId, clsId, newClsId );
		}
		
		if( cnt > 0 )
			mys.setAttribute( "clsdatacnt", ""+cnt );
		else
			mys.removeAttribute( "clsdatacnt" );

		GenboreeUtils.sendRedirect(request,response,  tgtBack );
		return;
	}

	String trkName = Util.htmlQuote(trk.toString());
%>

<HTML>
<head>
<title>Genboree - Track Classification</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY>

<%@ include file="include/header.incl" %>
<%@ include file="include/navbar.incl" %>

<p><font color="#008800"><strong>ATTENTION:</strong></font>
You have choosen to remove one or more track to class associations. You cannot remove
those associations from the physical data, but you can change them. If you really
want to do so, please choose another class for every association,
and press Apply button. Otherwise, press Cancel button.</p>

<form action="trackcls.jsp" method="post">

  <table border="0" cellpadding="2" width="100%">
  <tbody>
	<tr>
	  <td class="form_header"><strong>Track</strong></td>
	  <td class="form_header"><strong>Class</strong></td>
	  <td class="form_header"><strong>New&nbsp;Class</strong></td>
	</tr>
<%
	for( i=0; i<vRem.size(); i++ )
	{
		String clsId = (String) vRem.elementAt(i);
		String ctlId = "cls_"+clsId;
		DbGclass cls = (DbGclass) htClsId.get( clsId );
		if( cls == null ) continue;
%>
	<tr>
	  <td class="form_body"><strong><%=trkName%></strong></td>
	  <td class="form_body"><strong><%=Util.htmlQuote(cls.getGclass())%></strong></td>
	  <td class="form_body">
		<select class="txt" style="width:300" name="<%=ctlId%>" id="<%=ctlId%>">
<%
		for( int j=0; j<gclasses.length; j++ )
		{
			DbGclass gc = gclasses[j];
			String sel = "";
			String gcName = gc.getGclass();
			if( gc.getGid() == cls.getGid() )
			{
				sel = " selected";
				gcName = gcName + " (no change)";
			}
			out.println( "<option value=\""+gc.getGid()+"\""+sel+">"+
				Util.htmlQuote(gcName)+"</option>" );
		}
%>
		</select>
	  </td>
	</tr>
<%
	}
%>
  </tbody>
  </table>
  
<br>
<input type="submit" name="btnApply" id="btnApply"
	class="btn" value=" Apply ">
<input type="submit" name="btnCancel" id="btnCancel"
	class="btn" value=" Cancel ">

</form>

<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
