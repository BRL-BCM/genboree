<%@ page import="javax.servlet.http.*, java.net.*, org.genboree.dbaccess.*, java.io.*, java.util.*, org.genboree.util.*, org.genboree.upload.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%
	int i;
	
	Refseq[] allRefseqs = null;
    allRefseqs = Refseq.fetchAll( db );
    if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
    if( allRefseqs == null ) allRefseqs = new Refseq[0];
	
	String grName = null;
	String grDescr = null;
	String student = null;
	String refseqId = null;
	String btnSubmit = null;
	
	long totalBytes = request.getContentLength();
    mys.setAttribute( "totalBytes", new Long(totalBytes) );
    HttpPostInputStream hpIn = new HttpPostInputStream( request.getInputStream(), mys );
	
	String s = null;
	
	Vector v = new Vector();

    while( hpIn.nextPart() )
    {
      String cn = hpIn.getPartAttrib( "name" );
      BufferedReader br = new BufferedReader( new InputStreamReader(hpIn) );
      while( (s=br.readLine()) != null )
	  {
	  	if( cn.equals("userList") ) v.addElement( s );
		else if( cn.equals("grName") ) grName = s;
		else if( cn.equals("grDescr") ) grDescr = s;
		else if( cn.equals("student") ) student = s;
		else if( cn.equals("refseqId") ) refseqId = s;
		else if( cn.equals("btnSubmit") ) btnSubmit = s;
	  }
    }

	GenboreeGroup gGroup = new GenboreeGroup();
	if( grName == null ) grName = "-- New Group --";
	gGroup.setGroupName( grName );
	if( !gGroup.fetchByName(db) )
	{
		if( grDescr == null ) grDescr = grName;
		gGroup.setDescription( grDescr );
		if( student != null )
		try
		{
			gGroup.setStudent( Integer.parseInt(student) );
		} catch( Exception ex2 ) {}
	}
	else
	{
		gGroup.fetchRefseqs(db);
	}
	db.clearLastError();
	
	Refseq crs = null;
	if( refseqId != null )
		for( i=0; i<allRefseqs.length; i++ )
		if( gGroup.belongsTo(allRefseqs[i].getRefSeqId()) )
			crs = allRefseqs[i];
	if( crs == null && allRefseqs.length > 0 )
	{
		crs = allRefseqs[0];
		String[] rsids = new String[1];
		rsids[0] = crs.getRefSeqId();
		gGroup.setRefseqs( rsids );
	}
	if( crs == null )
	{
		crs = new Refseq();
		btnSubmit = null;
	}
	
	if( btnSubmit != null )
	{
		if( gGroup.getGroupId().equals("#") )
		{
			gGroup.insert( db );
			if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
			gGroup.updateRefseqs( db );
			if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
		}

/*
		String[] grpids = null;
		GenboreeGroup pGroup = new GenboreeGroup();
		pGroup.setGroupName( "Public" );
		if( pGroup.fetchByName(db) )
		{
			grpids = new String[2];
			grpids[1] = pGroup.getGroupId();
		}
*/		
		String[] grpids = new String[1];
		db.clearLastError();
		grpids[0] = gGroup.getGroupId();
		
		Random rnd = new Random( (new java.util.Date()).getTime() );
		for( i=0; i<v.size(); i++ )
		{
			String src = ((String)v.elementAt(i)).trim();
			if( src.length() == 0 ) continue;
			String[] rm = Util.parseString( src, '\t' );
			if( rm.length < 2 )
			{
				if( rm.length == 1 ) db.log( "Syntax error: "+src );
				continue;
			}
			String lastName = rm[0].trim();
			String firstName = "";
			String email = rm[1];
			rm = Util.parseString( lastName, ' ' );
			if( rm.length > 1 )
			{
				firstName = rm[0];
				lastName = rm[1];
			}
			rm = Util.parseString( email, '@' );
			if( rm.length <= 1 )
			{
				db.log( "Invalid email: "+src );
				continue;
			}
			String loginName = rm[0];
			int r = rnd.nextInt( 100 );
			String passwd = loginName + (char)('0' + (r/10)) + "" + (char)('0' + (r%10));
			
			// db.log( "OK: "+firstName+"|"+lastName+"|"+email+"|"+loginName+"|"+passwd );
			
			GenboreeUser usr = new GenboreeUser();
			usr.setName( loginName );
			s = usr.checkLoginName(db);
			if( s != null )
			{
				db.log( s );
				continue;
			}
			usr.setPassword( passwd );
			usr.setLastName( lastName );
			usr.setFirstName( firstName );
			usr.setEmail( email );
			usr.setGroups( grpids );
			
			usr.insert( db );
			if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
			usr.updateGroups( db );
			if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
		}
	}
	
	String log = db.getLog();
%>

<HTML>
<head>
<title>Genboree - Admin - Register Students</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY bgcolor="#DDE0FF">

<%@ include file="include/header.incl" %>
<%@ include file="include/navbar.incl" %>

<% if(log != null) { %>
<PRE>
<%=log%>
</PRE>
<% } %>

<center>

<form action="regstud.jsp" method="post" enctype="multipart/form-data">
  <table class='TABLE' align="center" border="2" bgcolor="#aac5ff">
  <tbody>
	  <tr><td>&nbsp;User List File:&nbsp;&nbsp;</td><td>
		<input type="file" name="userList"  class="txt" size="40">
      </td></tr>
	  
	  <tr><td align=center>Group</td><td align=center>Description</td></tr>
	  <tr>
	  <td>
		<input type="text" name="grName" value="<%=Util.htmlQuote(gGroup.getGroupName())%>" style="width:150">
      </td>
	  <td>
		<input type="text" name="grDescr" value="<%=Util.htmlQuote(gGroup.getDescription())%>" style="width:420">
      </td>
	  </tr>
      <tr><td>
        &nbsp;Group Type:                           
      </td><td>
        <select name="student"  class="txt" style="width:420">
			<option value="0"<%=(gGroup.getStudent()==0)?" selected":""%>>Normal</option>
			<option value="1"<%=(gGroup.getStudent()==1)?" selected":""%>>Single track access (students)</option>
			<option value="2"<%=(gGroup.getStudent()==2)?" selected":""%>>Multiple track access (honey bee)</option>
		</select>
      </td></tr>
	  

      <tr><td>
        &nbsp;Ref. Sequences:&nbsp;&nbsp;
      </td><td>
<%	int numRefseqs = allRefseqs.length;
	if( numRefseqs > 8 )
    { %>
        <select size="8" name="refseqId"  class="txt" style="width: 350">
<%    for( i=0; i<numRefseqs; i++ )
      {
        refseqId = allRefseqs[i].getRefSeqId();
        String refseqName = Util.htmlQuote( allRefseqs[i].getScreenName() );
        String sel = gGroup.belongsTo(refseqId) ? " selected" : "";
%>
        <option value="<%=refseqId%>"<%=sel%>><%=refseqName%></option>
<%    } %>
        </select>
<%  } else
    {
      for( i=0; i<numRefseqs; i++ )
      {
        refseqId = allRefseqs[i].getRefSeqId();
        String refseqName = Util.htmlQuote( allRefseqs[i].getScreenName() );
        String sel = gGroup.belongsTo(refseqId) ? " checked" : "";
%>
        <input type=radio name="refseqId" value="<%=refseqId%>"<%=sel%>><%=refseqName%></input><br>
<%    }
    } %>
      </td></tr>

  </tbody>
  </table>
  
  <br><input type="submit" name="btnSubmit" value="Submit" class="btn" style="width:100">
  
</form>

</center>

<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
