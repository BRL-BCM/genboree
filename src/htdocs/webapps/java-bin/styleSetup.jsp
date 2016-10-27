<%@ page import="javax.servlet.http.*, java.net.*, java.sql.*,
  java.util.*, org.genboree.dbaccess.*, org.genboree.util.Util,
                 org.genboree.util.GenboreeUtils" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%!
    static int colordiff( int ic1, int ic2 )
    {
        int dr = ((ic1 >> 16) & 0xFF) - ((ic2 >> 16) & 0xFF);
        int dg = ((ic1 >> 8) & 0xFF) - ((ic2 >> 8) & 0xFF);
        int db = (ic1 & 0xFF) - (ic2 & 0xFF);
        return (int)(Math.sqrt( (double)(dr*dr + dg*dg + db*db) ) + 0.5);
    }
	static int colordiff( String sc1, int ic2 )
	{
		try
		{
			if( sc1.startsWith("#") ) sc1 = sc1.substring(1);
			int rc = colordiff( Integer.parseInt(sc1,16), ic2 );
			return rc;
		} catch( Exception ex ) {}
		return 0xFFFFFF;
	}
	
%>
<%
    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );

	String destback = (String) mys.getAttribute( "destback" );
	if( destback == null ) destback = "/java-bin/login.jsp";
	
	if( request.getParameter("back") != null )
	{
		GenboreeUtils.sendRedirect(request,response,  destback );
		return;
	}

	int i = 0;
	int  a = 0;
	int b = 0;
	String tempValue[];
	Refseq editRefseq = new Refseq();
	String refSeqId = (String) mys.getAttribute( "editRefSeqId" );

	if(refSeqId == null || userInfo[2].equals("0"))
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/login.jsp" );
		return;
	}

   	editRefseq.setRefSeqId(refSeqId);
   	editRefseq.fetch(db);
	if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;

	if( !is_admin )
	{
		String acs = Refseq.fetchUserAccess(db, editRefseq.getDatabaseName(), userInfo[2]);
		if( acs!=null && acs.equals("o") ) is_admin = true;
	}

	boolean is_fromdefault = true;	
	String cmd = (is_admin) ? request.getParameter("applyAll") : null;
	if( cmd == null )
	{
		is_fromdefault = false;
		cmd = request.getParameter("apply");
	}

	int currentUser = is_fromdefault ? 0 : Util.parseInt(userInfo[2],-1);

	String[] trackNames = (String []) mys.getAttribute( "featuretypes" );
	
	boolean need_delete_usr = request.getParameter("default") != null;
	if( is_admin && is_fromdefault ) need_delete_usr = true;

	Hashtable trackLookup = null;
	if( trackNames!=null && trackNames.length>0 )
	{
		trackLookup = new Hashtable();
		for( i=0; i<trackNames.length; i++ )
			trackLookup.put( trackNames[i], "y" );
	}
	
	Style[] styleList = editRefseq.fetchStyles( db );
	Style[] colorList = editRefseq.fetchColors( db );
	if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;

	Style[] styleMap = editRefseq.fetchStyleMap( db, currentUser );
	if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;

	if( need_delete_usr )
	{
		Vector vd = new Vector();
		for( i=0; i<styleMap.length; i++ )
		{
			Style st = styleMap[i];
			String trackName = st.fmethod+":"+st.fsource;
			if( trackLookup!=null && trackLookup.get(trackName)==null ) continue;
			if( trackName.compareToIgnoreCase("Component:Chromosome") == 0 ||
				trackName.compareToIgnoreCase("Supercomponent:Sequence") == 0 )
				continue;
			vd.addElement( st );
		}
		Style[] delst = new Style[ vd.size() ];
		vd.copyInto( delst );
		editRefseq.deleteStyleMap( db, delst, currentUser );
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;

		styleMap = editRefseq.fetchStyleMap( db, currentUser );
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
	}
	
	if( cmd != null )
	{
		Hashtable htStyle = new Hashtable();
		for( i=0; i<styleList.length; i++ ) htStyle.put( styleList[i].name, styleList[i] );
		
		Vector vu = new Vector();
		for( i=0; i<styleMap.length; i++ )
		{
			Style st = styleMap[i];
			String trackName = st.fmethod+":"+st.fsource;
			if( trackLookup!=null && trackLookup.get(trackName)==null ) continue;
			if( trackName.compareToIgnoreCase("Component:Chromosome") == 0 ||
				trackName.compareToIgnoreCase("Supercomponent:Sequence") == 0 )
				continue;

			String stName = request.getParameter( trackName + ":style" );
			Style cst = (stName!=null) ? (Style)htStyle.get(stName) : (Style)null;
			String curColor = request.getParameter( trackName + ":color" );
			if( cst == null && curColor == null ) continue;
			if( cst != null )
			{
				st.name = cst.name;
				st.description = cst.description;
			}
			if( curColor != null ) st.color = curColor;

			vu.addElement( st );
		}

		Style[] updst = new Style[ vu.size() ];
		vu.copyInto( updst );
		editRefseq.setStyleMap( db, updst, currentUser );
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;

		GenboreeUtils.sendRedirect(request,response,  destback );
		return;
	}

%>
<HTML>
<head>
<title>Genboree - User Style Setup</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY>
<DIV id="overDiv" class="c1"></DIV>
<SCRIPT type="text/javascript" src="/javaScripts/overlib.js<%=jsVersion%>"></SCRIPT>
<SCRIPT type="text/javascript" src="/javaScripts/overlib_hideform.js<%=jsVersion%>"></SCRIPT>
<SCRIPT type="text/javascript" src="/javaScripts/colorbox.js<%=jsVersion%>"></SCRIPT>
<script type="text/javascript" src="/javaScripts/overlib_cssstyle.js<%=jsVersion%>"></script>		<!-- Official extension to use css style classes for the title bar appearance -->
<SCRIPT type="text/javascript">
<%
	int nColors = colorList.length;
	int nColumns = 12;
	
	colorList = Style.sortByColors( colorList, 12 );
	
	for( i=0; i<nColors; i++ )
	{
		String curColor = colorList[i].color;
		if( curColor.startsWith("#") ) curColor = curColor.substring(1);
		out.println( "colorArray["+i+"]='"+curColor+"';" );
	}
	int nRows = (nColors + nColumns - 1) / nColumns;
	out.println( "nColors="+nColors+";" );
	out.println( "nColorColumns="+nColumns+";" );
	out.println( "nColorRows="+nRows+";" );
	int wHeight = nRows * 20 + 50;
	out.println( "cBoxHeight="+wHeight+";" );
%>
</SCRIPT>

<%@ include file="include/header.incl" %>

<%@ include file="include/navbar.incl" %>

<p>
<CENTER><SPAN STYLE="font-size:12pt; font-weight:bold; background-color: #ffffe6;">&nbsp;Drawing Style Setup&nbsp;</SPAN></CENTER>
</p>


<FORM name="ss" id="ss" action="styleSetup.jsp" method="post">

  <INPUT TYPE="submit" name="apply" id="apply" VALUE="Apply" class="btn" style="width:100">&nbsp;&nbsp;
<%	if( is_admin ) { %>
  <INPUT TYPE="submit" name="applyAll" id="applyAll" VALUE="Set As Default" class="btn" style="width:120">&nbsp;&nbsp;
<%	} %>
  <INPUT TYPE="submit" name="default" id="default" VALUE="Load Default" class="btn" style="width:120">&nbsp;&nbsp;
  <INPUT type="submit" name="back" id="back" VALUE="Back" class="btn" style="width:100">
<br><p>
  <table border="0" cellpadding="2" width="100%">

  <tr>
  <td class="form_header">Track</td>
  <td class="form_header">Style</td>
  <td class="form_header"><a
    href="javascript:void(0);" 
    ONCLICK="MyWindow=window.open('/colors.html', 'ColorWindow','toolbar=no,location=no,directories=no,status=no,menubar=no,scrollbars=no,resizable=yes,width=250,height=600,left=500,top=20'); return false;";>
    <font color="white">Color</font></a>
  </td>
  </tr>

<%
   for( i=0; i<styleMap.length; i++ )
   {
		Style st = styleMap[i];
		String trackName = st.fmethod+":"+st.fsource;
		if( trackLookup!=null && trackLookup.get(trackName)==null ) continue;
		if( trackName.compareToIgnoreCase("Component:Chromosome") == 0 ||
			trackName.compareToIgnoreCase("Supercomponent:Sequence") == 0 )
			continue;

		String felemId = trackName + ":style";
%>
  <tr>
  <td class="form_body"><%=Util.htmlQuote(trackName)%></td>
  <td class="form_body"><select class="txt" name="<%=felemId%>">
<%
	for( int j=0; j<styleList.length; j++ )
	{
		Style cst = styleList[j];
		String isSel = cst.name.equals(st.name) ? " selected" : "";
%>
    <option value="<%=cst.name%>"
<%=isSel %> >
<%=Util.htmlQuote(cst.description)%>
</option>
<%
    } 
%>
  </select></td>
  
  <td class="form_body">
<%
	String imgId = "img"+i;
	String elemId = trackName + ":color";
	String curColor = st.color;
	if( curColor.startsWith("#") ) curColor = curColor.substring(1);
%>
  <a href="javascript:void null;"
	onClick="showColorPop('<%=imgId%>','ss','<%=elemId%>', '<%="http://" + ipAddress.getHostAddress()%>')">
  <img name="<%=imgId%>" id="<%=imgId%>" border="0"
	src="http://<%=ipAddress.getHostAddress()%>/java-bin/ColorBox?c=<%=curColor%>">&nbsp;Change
  <input type="hidden" name="<%=elemId%>" id="<%=elemId%>"
	value="#<%=curColor%>">
  </a>
  
  </td>

</tr>
<%
  	}
%>

  </table>
  <br>
  <INPUT TYPE="submit" name="apply" id="apply" VALUE="Apply" class="btn" style="width:100">&nbsp;&nbsp;
<%	if( is_admin ) { %>
  <INPUT TYPE="submit" name="applyAll" id="applyAll" VALUE="Set As Default" class="btn" style="width:120">&nbsp;&nbsp;
<%	} %>
  <INPUT TYPE="submit" name="default" id="default" VALUE="Load Default" class="btn" style="width:120">&nbsp;&nbsp;
  <INPUT type="submit" name="back" id="back" VALUE="Back" class="btn" style="width:100">
</FORM>

<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
