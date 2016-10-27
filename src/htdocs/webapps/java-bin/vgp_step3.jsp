<%@ page import="java.util.*, java.io.*,
	javax.servlet.http.*, org.genboree.dbaccess.*,
	org.genboree.util.*, org.genboree.upload.*, org.genboree.gdasaccess.*,
                 org.genboree.editor.AnnotationEditorHelper" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>

<%@ include file="include/colorWheelFiles.incl" %>

<%!

	static String digs = "ABCDEFGHJKLMNPQRSTUVWXYZ";
	static String cvtAbc( int seed )
	{
		int n = digs.length();
		int i = (seed % n);
		seed /= n;
		String s = digs.substring(i,i+1);
		while( seed > 0 )
		{
			i = (seed % n);
			seed /= n;
			s = s + digs.substring(i,i+1);
		}
		return s;
	}
%>
<%
//    response.addDateHeader( "Expires", 0L );
//    response.addHeader( "Cache-Control", "no-cache, no-store" );
	if( request.getParameter("cmdBack") != null )
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/vgp_step2.jsp" );
		return;
	}
	int i, j;
	VGPaint vgp = (VGPaint) mys.getAttribute( "VGPaint" );

    if( vgp == null )
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/vgp.jsp" );
		return;
	}

	Refseq editRefseq = vgp.getRefseq();
	if( editRefseq == null )
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/vgp.jsp" );
		return;
	}

	Style[] colorList = editRefseq.fetchColors( db );
	if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;

	int nftypes = vgp.getFtypeCount();
	VGPaint.VGPFcategory[] acats = vgp.getFcategories();
	
	Vector vft = new Vector();
	Vector vftgr = new Vector();
	Vector vftgr1 = new Vector();
	Vector vftid = new Vector();
	for( i=0; i<nftypes; i++ )
	{
		VGPaint.VGPFtype ft = vgp.getFtypeAt( i );
		vft.addElement( ft );
		String fsrc = ft.getSource();
		if( Util.isEmpty(fsrc) ) fsrc = " ";
		else fsrc = fsrc.substring(0,1);
		String baseId = ft.getMethod() + "_" + fsrc + "_";
		fsrc = ft.getMethod() + ":" + fsrc;
		if( !vftgr.contains(fsrc) )
		{
			vftgr.addElement( fsrc );
			vftgr1.addElement( fsrc );
			vftid.addElement( baseId );
		}
	}
	
	VGPaint.VGPFtype[] ftypes = new VGPaint.VGPFtype[ vft.size() ];
	vft.copyInto( ftypes );
	Arrays.sort( ftypes );

	for( i=0; i<ftypes.length; i++ )
	{
		VGPaint.VGPFtype ft = ftypes[i];
		String sideid = request.getParameter( "trkside"+i );
		if( sideid != null )
		{
			int ori = Util.parseInt( sideid, 0 );
			if( ori < 0 || ori >= acats.length ) ori = 0;
			ft.setOrientation( ori );
		}
		String color = request.getParameter( "trkcolor"+i );
        if (color != null && !color.startsWith("#"))
        color = "#" + color ;
		if( color != null ) ft.setColor( color );
		String displ = request.getParameter( "trkdispl"+i );
		if( displ != null )
		{
			ft.setDisplay( Util.parseInt(displ,0) != 0 );
		}
		String abbr = request.getParameter( "trkabr"+i );
		if( abbr != null ) ft.setAbbreviation( abbr );
	}
	
	for( j=0; j<vftid.size(); j++ )
	{
		String baseId = (String) vftid.elementAt( j );
		String grpName = (String) vftgr.elementAt( j );
		int icat = -1;
		boolean need_upd = false;
		boolean set_displ = false;
		boolean displ = false;
		for( i=0; i<acats.length; i++ )
		{
			String cn = baseId+"cat"+i;
			if( request.getParameter(baseId+"cat"+i) != null )
			{
				icat = i;
				need_upd = true;
			}
		}
		if( request.getParameter(baseId+"disp") != null )
		{
			displ = true;
			need_upd = set_displ = true;
		}
		if( request.getParameter(baseId+"hide") != null )
		{
			displ = false;
			need_upd = set_displ = true;
		}
		if( !need_upd ) continue;
		for( i=0; i<ftypes.length; i++ )
		{
			VGPaint.VGPFtype ft = ftypes[i];
			String fsrc = ft.getSource();
			if( Util.isEmpty(fsrc) ) fsrc = " ";
			else fsrc = fsrc.substring(0,1);
			fsrc = ft.getMethod() + ":" + fsrc;
			if( !fsrc.equals(grpName) ) continue;
			if( icat >= 0 ) ft.setOrientation( icat );
			if( set_displ ) ft.setDisplay( displ );
		}
	}
	
	if( request.getParameter("cmdColors") != null )
	{
		vgp.loadDefaultColors( db, userInfo[2] );
	}
	
	vgp.validateFtypes();

	int grpIdx;
	String suff;
	boolean are_unique = true;
	
// Force uniqueness of the abbreviations
	Hashtable htChanged = new Hashtable();
	Hashtable[] htAbs = new Hashtable[ acats.length ];
	for( j=0; j<htAbs.length; j++ ) htAbs[j] = new Hashtable();
	
	int seed = 0;
	for( i=0; i<ftypes.length; i++ )
	{
		VGPaint.VGPFtype ft = ftypes[i];
		if( !ft.getDisplay() ) continue;
		Hashtable htAb = htAbs[ ft.getOrientation() ];
		String ab = ft.getAbbreviation();
		if( ab == null ) ab = "";
		String pref = ab;
		suff = "";
		int idx = ab.indexOf('.');
		if( idx >= 0 )
		{
			pref = ab.substring( 0, idx );
			suff = ab.substring( idx );
		}
		if( pref.trim().length()==0 || htAb.get(ab)!=null )
		{
			are_unique = false;
			do
			{
				ab = cvtAbc( seed++ ) + suff;
			} while( htAb.get(ab)!=null );
			ft.setAbbreviation( ab );
			htChanged.put( ft, "y" );
		}
		htAb.put( ab, "y" );
	}

	
	if( request.getParameter("cmdNext") != null )
	{
        for( i=0; i<ftypes.length; i++ )
	{
		VGPaint.VGPFtype ft = ftypes[i];
		String sideid = request.getParameter( "trkside"+i );
		if( sideid != null )
		{
			int ori = Util.parseInt( sideid, 0 );
			if( ori < 0 || ori >= acats.length ) ori = 0;
			ft.setOrientation( ori );
		}
		String color = request.getParameter( "trkcolor"+i );
		if( color != null ) ft.setColor( color );
		String displ = request.getParameter( "trkdispl"+i );
		if( displ != null )
		{
			ft.setDisplay( Util.parseInt(displ,0) != 0 );
		}
		String abbr = request.getParameter( "trkabr"+i );
		if( abbr != null ) ft.setAbbreviation( abbr );
	}

		if( are_unique )
		{
			GenboreeUtils.sendRedirect(request,response,  "/java-bin/vgp_step4.jsp" );
			return;
		}
	}

%>

<HTML>
<head>
<title>VGP - Choose Tracks</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY>
<DIV id="overDiv" class="c1"></DIV>
<SCRIPT type="text/javascript" src="/javaScripts/overlib.js<%=jsVersion%>"></SCRIPT>
<SCRIPT type="text/javascript" src="/javaScripts/overlib_hideform.js<%=jsVersion%>"></SCRIPT>
<SCRIPT type="text/javascript" src="/javaScripts/colorbox.js<%=jsVersion%>"></SCRIPT>
<script type="text/javascript" src="/javaScripts/overlib_cssstyle.js<%=jsVersion%>"></script>

<SCRIPT type="text/javascript">
<%
	int nColors = colorList.length;
	int nColumns = 12;

	colorList = Style.sortByColors( colorList, 12 );

	for( i=0; i<nColors; i++ )
	{
		String curColor = colorList[i].color;
		if( curColor.startsWith("#") ) curColor = curColor.substring(1);
  		out.println( " colorArray["+i+"]='"+curColor+"';" );
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

<form name="vgp" id="vgp" action="vgp_step3.jsp" method="post">
  <table width="100%" border="0" cellpadding="4">
  <tbody>

  <tr>
	<td colspan="2">
<%@ include file="include/vgpnav.incl" %>
	</td>
  </tr>

  <tr>
	<td colspan="2">
	<input name="cmdBack" type=submit value='<Back' style="width:100" class="btn">&nbsp;
	<input name="cmdNext" type=submit value='Next>' style="width:100" class="btn">&nbsp;
	<input name="cmdColors" type=submit value='Load Default Colors' class="btn">
	</td>
  </tr>
  
<% if( !are_unique ) { %>
  <tr>
	<td colspan="2"><font color=red><strong>Warning:<strong></font>
	Missing or duplicating Track abbreviated names have been detected;
	they have been fixed automatically and highlighted with pink background color.
	</td>
  </tr>
<% } %>

  <tr>
	<td>
	  <table width="100%" border="0" cellpadding="2">
	  <tbody>
	  	
		<tr>
		  <td class="form_header">Track</td>
		  <td class="form_header">Side</td>
		  <td class="form_header">Color</td>
		  <td class="form_header">Display</td>
		  <td class="form_header">Abbr.</td>
		</tr>

<%
	grpIdx = 0;
	suff = "";
	for( i=0; i<ftypes.length; i++ )
	{
		VGPaint.VGPFtype ft = ftypes[i];
		
		String bkgcls = (htChanged.get(ft) != null) ? "form_fixed" : "form_body";

		String fsrc = ft.getSource();
		if( Util.isEmpty(fsrc) ) fsrc = " ";
		else fsrc = fsrc.substring(0,1);
		String baseId = ft.getMethod() + "_" + fsrc + "_";
		fsrc = ft.getMethod() + ":" + fsrc;
		if( vftgr.contains(fsrc) )
		{
			vftgr.remove( fsrc );
			if( grpIdx != 0 )
			{
				out.println( "<tr><td colspan=\"5\" style=\"height:12\"></td></tr>" );
				suff = "."+grpIdx;
			}
%>	<tr>
		<td><strong><%=fsrc%><strong></td>
		<td colspan="2">
<%
		for( j=0; j<acats.length; j++ )
		{
			String cn = acats[j].getName();
			String ab = acats[j].getAbbreviation();
%><input type="button" name="<%=baseId%>cat<%=j%>" id="<%=baseId%>cat<%=j%>"
	value="<%=cn%> (<%=ab%>)" class="btn"
	onClick="setGroupCat(<%=grpIdx%>,<%=j%>)">&nbsp;
<%
		}
%>		</td>
		<td colspan="2">
	<input type="button" name="<%=baseId%>disp" id="<%=baseId%>disp"
		onClick="setGroupDisplay(<%=grpIdx%>,0)"
		value="Yes" class="btn">
	<input type="button" name="<%=baseId%>hide" id="<%=baseId%>hide"
		onClick="setGroupDisplay(<%=grpIdx%>,1)"
		value="No&nbsp;" class="btn">
		</td>

	</tr>
<%
			grpIdx++;
		}
		
		String trksideid = "trkside"+i;
		String trkcolorid = "trkcolor"+i;
		String trkabrid = "trkabr"+i;
		String trkdisplid = "trkdispl"+i;
		String trkdisplYes = ft.getDisplay() ? " checked" : "";
		String trkdisplNo = ft.getDisplay() ? "" : " checked";
		String cc = ft.getColor();

		String ftAbbr = ft.getAbbreviation();
/*		
		if( grpIdx!=0 && ftAbbr.indexOf(".")<0 )
		{
			ftAbbr = ftAbbr + suff;
			ft.setAbbreviation( ftAbbr );
		}
*/

%>
		<tr>
		  <td class="<%=bkgcls%>">
			<strong>&nbsp;<%=Util.htmlQuote(ft.toString())%>&nbsp;</strong>
		  </td>
		  <td class="<%=bkgcls%>">
			<select name="<%=trksideid%>" id="<%=trksideid%>" class="txt">
<%
		for( j=0; j<acats.length; j++ )
		{
			String sel = (ft.getOrientation() == j) ? " selected" : "";
%>
				<option value="<%=j%>"<%=sel%>><%=acats[j].getName()%></option>
<%
		}
%>
			</select>
		  </td>
		  <td class="<%=bkgcls%>">
<%
	String imgId = "img"+i;
	String curColor = cc;
	if( curColor.startsWith("#") ) curColor = curColor.substring(1);
%>

<a href="javascript:void null;"  id="wheellink">
   <div name="<%=imgId%>" id="<%=imgId%>"  class="colorIconLong2"  style="background-color:<%=curColor%>"  onClick="setDivId('<%=imgId%>', '<%=trkcolorid %>', '<%=curColor%>');" ></div>
   <div class="bottomdivLong" onClick="setDivId('<%=imgId%>', '<%=trkcolorid %>', '<%=curColor%>');">&nbsp;&nbsp;&nbsp;&nbsp;Change Color</div>
   </a>

      <input type="hidden" name="<%=trkcolorid%>" id="<%=trkcolorid%>"  value="#<%=curColor%>" >
		  </td>
		  <td class="<%=bkgcls%>">
			<input type="radio" id="<%=trkdisplid%>" name="<%=trkdisplid%>"
				value="1"<%=trkdisplYes%>>Yes
			&nbsp;
			<input type="radio" id="<%=trkdisplid%>" name="<%=trkdisplid%>"
				value="0"<%=trkdisplNo%>>No
		  </td>
		  <td class="<%=bkgcls%>">
			<input type="text" name="<%=trkabrid%>" id="<%=trkabrid%>"
			size="6" maxlength="6"
			value="<%=Util.htmlQuote(ftAbbr)%>" class="txt">
		  </td>
		</tr>
<%
	}
%>

	  </tbody>
	  </table>
	</td>
  </tr>
  <tr>
	<td colspan="2">
	<input name="cmdBack" type=submit value='<Back' style="width:100" class="btn">&nbsp;
	<input name="cmdNext" type=submit value='Next>' style="width:100" class="btn">
	</td>
  </tr>
  </tbody>
  </table>

</form>

<script language="JavaScript">
var lim = new Object();
<%
	String soFar = "#";
	int jsIdx = 0;
	for( i=0; i<ftypes.length; i++ )
	{
		VGPaint.VGPFtype ft = ftypes[i];
		String fsrc = ft.getSource();
		if( Util.isEmpty(fsrc) ) fsrc = " ";
		else fsrc = fsrc.substring(0,1);
		fsrc = ft.getMethod() + ":" + fsrc;
		if( fsrc.equals(soFar) ) continue;
		soFar = fsrc;
		out.println( "lim["+jsIdx+"] = "+i+";" );
		jsIdx++;
	}
	out.println( "lim["+jsIdx+"] = "+i+";" );


%>
function setGroupCat( gr, cat )
{
	var n0 = lim[gr];
	var n1 = lim[gr+1];
	var i;
	for( i=n0; i<n1; i++ )
	{
		var kt = "trkside"+i;
		document.vgp.elements[kt].selectedIndex = cat;
	}
}
function setGroupDisplay( gr, disp )
{
	var n0 = lim[gr];
	var n1 = lim[gr+1];
	var i;
	for( i=n0; i<n1; i++ )
	{
		var kt = "trkdispl"+i;
		var yesno = document.vgp.elements[kt];
		yesno[disp].checked = true;
	}
}
</script>

<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
