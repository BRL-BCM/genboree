<%@ page import="javax.servlet.http.*,
 java.util.*, java.sql.*,
 org.genboree.dbaccess.*, org.genboree.util.*, org.genboree.upload.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%!
%>
<%
    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );
	if( !userInfo[0].equals("admin") )
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/login.jsp" );
		return;
	}

	String destback = (String) mys.getAttribute( "destback" );
	if( destback == null ) destback = "/java-bin/login.jsp";

	if( request.getParameter("btnBack") != null )
	{
		GenboreeUtils.sendRedirect(request,response,  destback );
		return;
	}

	int i;
	Refseq[] rseqs = Refseq.fetchAll( db, null );

	String refSeqId = request.getParameter( "refSeqId" );
	if( refSeqId == null ) refSeqId = "#";
	
	Refseq rseq = null;
	for( i=0; i<rseqs.length; i++ )
	{
		String myId = rseqs[i].getRefSeqId();
		if( myId.equals(refSeqId) ) rseq = rseqs[i];
	}
	if( rseq == null )
	{
		if( rseqs.length > 0 ) rseq = rseqs[0];
		else
		{
			rseq = new Refseq();
			rseq.setDatabaseName( "#####" );
		}
	}
/*
	else if( request.getParameter("btnFixGclass") != null )
	{
		String gclass = request.getParameter( "fixGclass" );
		if( gclass == null ) gclass = "";
		else gclass = gclass.trim();
		if( !Util.isEmpty(gclass) )
		{
			rseq.fixGclass( db, gclass );
			if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
		}
	}
*/	
	RefseqTemplate.EntryPoint[] rsEps = RefseqTemplate.getRefseqEntryPoints( rseq, db );

	String rsTemplId = request.getParameter( "rsTemplId" );
	if( rsTemplId == null ) rsTemplId = "#";
	RefseqTemplate rst = null;

	RefseqTemplate[] rsTempls = RefseqTemplate.fetchAll( db );

	db.clearLastError();
	
	boolean is_checked = request.getParameter("dtChecked") != null;
	String dtChecked = is_checked ? " checked" : "";

	if( request.getParameter("cmdCreateTempl") != null && rsEps.length>0 )
	{
		GenboreeUpload upld = null;
		if( is_checked )
		{
          int userId = Util.parseInt(myself.getUserId(), -1);
      GenboreeUpload[] uplds =
				GenboreeUpload.fetchAll( db, rseq.getRefSeqId(), null, userId  );
			for( i=0; i<uplds.length; i++ )
			if( uplds[i].getDatabaseName().equals( rseq.getDatabaseName() ) )
			{
				upld = uplds[i];
				break;
			}
			if( upld == null && uplds.length>0 ) upld = uplds[0];
		}
		rst = new RefseqTemplate( rseq );
		rst.insert( db );
		rst.updateEntryPoints( db, rsEps );
		if( upld != null )
		{
			String[] uids = new String[1];
			uids[0] = ""+upld.getUploadId();
			rst.setTemplateUploadIds( db, uids );
		}
		rsTemplId = rst.getRefseqTemplateId();
		rsTempls = RefseqTemplate.fetchAll( db );
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;

		// copy chromosomeTemplate records, if any
		if( rseq!=null && Util.parseInt(rseq.getFK_genomeTemplate_id(),-1)!=-1 )
		try
		{
			String genomeId = rseq.getFK_genomeTemplate_id();
			Connection conn = db.getConnection();
			Statement stmt = conn.createStatement();
			ResultSet rs = stmt.executeQuery(
				"SELECT * FROM chromosomeTemplate WHERE FK_genomeTemplate_id="+genomeId );
			ResultSetMetaData rsmd = rs.getMetaData();
			int ccnt = rsmd.getColumnCount();
			int[] imap = new int[ ccnt+2 ];
			int midx = 0;
			String colList = null;
			String valList = null;
			for( i=0; i<ccnt; i++ )
			{
				int ic = i+1;
				String cName = rsmd.getColumnName(ic);
				if( cName.equals("chromosomeTemplate_id") ) continue;
				imap[i] = ++midx;
				if( colList == null )
				{
					colList = cName;
					valList = "?";
				}
				else
				{
					colList = colList + ", " + cName;
					valList = valList + ", ?";
				}
			}
			PreparedStatement pstmt = conn.prepareStatement(
				"INSERT INTO chromosomeTemplate ("+colList+
				") VALUES ("+valList+")" );
			while( rs.next() )
			{
				for( i=0; i<ccnt; i++ )
				{
					int ic = i+1;
					String cName = rsmd.getColumnName(ic);
					String cVal = rs.getString(ic);
					if( cName.equals("chromosomeTemplate_id") ) continue;
					if( cName.equals("FK_genomeTemplate_id") ) cVal = rsTemplId;
					pstmt.setString( imap[i], cVal );
				}
				pstmt.executeUpdate();
			}
			pstmt.close();
			stmt.close();
		} catch( Exception ex01 )
		{
			out.println( "Exception: "+ex01.getClass().getName()+"<br>" );
			out.println( "Message:"+Util.htmlQuote(ex01.getMessage())+"<br>" );
		}

	}

	for( i=0; i<rsTempls.length; i++ )
	{
		String myId = rsTempls[i].getRefseqTemplateId();
		if( myId.equals(rsTemplId) ) rst = rsTempls[i];
	}
	if( rst == null ) rsTemplId = "#";

	if( request.getParameter("cmdUpdateTempl") != null && rst != null )
	{
		String templ_name = request.getParameter( "templ_name" );
		String templ_descr = request.getParameter( "templ_descr" );
		String templ_species = request.getParameter( "templ_species" );
		String templ_ver = request.getParameter( "templ_ver" );
		rst.setName( templ_name );
		rst.setDescription( templ_descr );
		rst.setSpecies( templ_species );
		rst.setVersion( templ_ver );
		rst.update( db );
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
	}

	if( request.getParameter("cmdDeleteTempl") != null && rst != null )
	{
		rst.delete( db );
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
		rst = null;
		rsTempls = RefseqTemplate.fetchAll( db );
		rsTemplId = "#";
	}
	
	RefseqTemplate.EntryPoint[] rstEps = null;
	if( rst != null )
	{
		rstEps = rst.fetchEntryPoints( db );
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
	}

%>

<HTML>
<head>
<title>Genboree - Refseq Template Manager</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY>

<%@ include file="include/header.incl" %>
<%@ include file="include/navbar.incl" %>

<form name="mgr" id="mgr" action="templatemanager.jsp" method="post">
  <input type="submit" name="btnBack" id="btnBack" class="btn" value=" Back ">
  <table border="0" cellpadding="4" cellspacing="2">
  <tbody>

	<tr>
	  <td class="form_body"><strong>Template</strong></td>  
	  <td class="form_body" colspan="2">
		<select name="rsTemplId" id="rsTemplId"
		onchange='this.form.submit()'
		 class="txt" style="width:300">
<option value="#">-- New Template --</option>
<%
	for( i=0; i<rsTempls.length; i++ )
	{
		String myId = rsTempls[i].getRefseqTemplateId();
		String sel = myId.equals(rsTemplId) ? " selected" : "";
%><option value="<%=myId%>"<%=sel%>><%=rsTempls[i].getName()%></option>
<%
	}
%>
		</select>
	  </td>
	</tr>

<% if( rsTemplId.equals("#") ) { %>
	<tr>
	  <td class="form_body" rowspan="6" valign="top">
	  <strong>Ref. Sequence</strong>
	  </td>  
	  <td class="form_body">
		<select name="refSeqId" id="refSeqId"
		onchange='this.form.submit()'
		 class="txt" style="width:300">
<%
	for( i=0; i<rseqs.length; i++ )
	{
		String myId = rseqs[i].getRefSeqId();
		String sel = myId.equals(refSeqId) ? " selected" : "";
%><option value="<%=myId%>"<%=sel%>><%=rseqs[i].getRefseqName()%></option>
<%
	}
%>
		</select>
	  </td>
	  <td class="form_body">
		<input name="cmdCreateTempl" id="cmdCreateTempl"
		type="submit" class="btn" value='Create Template'>
	  </td>
	</tr>
	
	<tr>
	  <td class="form_body" colspan="2">
		<i>Description:</i>
		<strong><%=Util.htmlQuote(rseq.getDescription())%></strong>
	  </td>
	</tr>
	<tr>
	  <td class="form_body" colspan="2">
		<i>Species:</i>
		<strong><%=Util.htmlQuote(rseq.getRefseq_species())%></strong>
	  </td>
	</tr>

	<tr>
	  <td class="form_body">
		<i>Version:</i>
		<strong><%=Util.htmlQuote(rseq.getRefseq_version())%></strong>
	  </td>
	  <td class="form_body">
		<i>Genome ID:</i>
		<strong><%=Util.htmlQuote(rseq.getFK_genomeTemplate_id())%></strong>
	  </td>
	</tr>

	<tr>
	  <td class="form_body" colspan="2">
	  <input type="checkbox" name="dtChecked" id="dtChecked" value="yes"<%=dtChecked%>>
	  <strong>Include data tracks into template</strong>
	  </td>
	</tr>

<!--
	<tr>
	  <td bgcolor="#CCFFCC" colspan="2">
	  To set the class of all entrypoints in the database to a new fixed value,<br>
	  specify that new value and press "Update".<br>
	  <input type="text" name="fixGclass" id="fixGclass"
	  class="txt" size="40" maxlength="100"
	  value="Chromosome">&nbsp;
	  <input type="submit" name="btnFixGclass" id="btnFixGclass"
	  class="btn" value="Update">
	  </td>
	</tr>
 -->

	<tr><td class="form_body" colspan="2">
	&nbsp;<%=rsEps.length%> Entry Points in this Ref. Sequence.<br>
	<table width="100%" border="0" cellspacing="2" cellpadding="4">
	<tbody>
	  <tr>
		<td class="form_header">Name</td>
		<td class="form_header">Class</td>
		<td class="form_header">Length</td>
	  </tr>
<%	for( i=0; i<rsEps.length; i++ )
	{
		RefseqTemplate.EntryPoint ep = rsEps[i];
%>	  <tr>
		<td bgcolor="white"><%=Util.htmlQuote(ep.fref)%></td>
		<td bgcolor="white"><%=Util.htmlQuote(ep.gclass)%></td>
		<td bgcolor="white"><%=ep.len%></td>
	  </tr>
<%	} %>
	</tbody>
	</table>
	</td></tr>
<% } else { // if( rsTemplId.equals("#") ) %>

	<tr>
	  <td class="form_body"><strong>Name</strong></td>  
	  <td class="form_body" colspan="2">
	  <input type="text" name="templ_name" id="templ_name"
	   class="txt" size="64" maxlength="255"
	  value="<%=Util.htmlQuote(rst.getName())%>">
	  </td>
	</tr>

	<tr>
	  <td class="form_body"><strong>Description</strong></td>  
	  <td class="form_body" colspan="2">
	  <input type="text" name="templ_descr" id="templ_descr"
	   class="txt" size="64" maxlength="255"
	  value="<%=Util.htmlQuote(rst.getDescription())%>">
	  </td>
	</tr>

	<tr>
	  <td class="form_body"><strong>Species</strong></td>  
	  <td class="form_body" colspan="2">
	  <input type="text" name="templ_species" id="templ_species"
	   class="txt" size="64" maxlength="255"
	  value="<%=Util.htmlQuote(rst.getSpecies())%>">
	  </td>
	</tr>

	<tr>
	  <td class="form_body"><strong>Version</strong></td>  
	  <td class="form_body" colspan="2">
	  <input type="text" name="templ_ver" id="templ_ver"
	   class="txt" size="64" maxlength="255"
	  value="<%=Util.htmlQuote(rst.getVersion())%>">
	  </td>
	</tr>

	<tr>
	  <td class="form_body">&nbsp;</td>
	  <td class="form_body" colspan="2">
		<input type="submit" name="cmdUpdateTempl" id="cmdUpdateTempl"
		 class="btn" style="width:120" value="Update">
		<input name="cmdDeleteTempl" id="cmdDeleteTempl" type="submit"
		 class="btn" style="width:120" value='Delete'>
	  </td>
	</tr>

<% if( rstEps != null ) { %>
	<tr><td class="form_body" colspan="3">
	<strong>&nbsp;<%=rstEps.length%> Entry Points in this template.</strong><br>
	<table width="100%" border="0" cellspacing="2" cellpadding="4">
	<tbody>
	  <tr>
		<td class="form_header">Name</td>
		<td class="form_header">Class</td>
		<td class="form_header">Length</td>
	  </tr>
<%	for( i=0; i<rstEps.length; i++ )
	{
		RefseqTemplate.EntryPoint ep = rstEps[i];
%>	  <tr>
		<td bgcolor="white"><%=Util.htmlQuote(ep.fref)%></td>
		<td bgcolor="white"><%=Util.htmlQuote(ep.gclass)%></td>
		<td bgcolor="white"><%=ep.len%></td>
	  </tr>
<%	} %>
	</tbody>
	</table>
	</td></tr>
<% } // if( rstEps != null ) %>

<% } // else if( rsTemplId.equals("#") ) %>
  </tbody>
  </table>
  <input type="submit" name="btnBack" id="btnBack" class="btn" value=" Back ">
</form>

<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
