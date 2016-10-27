<%@ page import="java.util.*, java.io.*, org.genboree.util.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%
	
  String locDir = Constants.GENBOREE_HTDOCS;
  String catBase = System.getProperty( "catalina.base" );
  if( catBase != null ) locDir = catBase + "/";
  String webDir = "syntenyGIFS/";
  String parentUrl = "http://brl.bcm.tmc.edu/";
  String imageDir = parentUrl+"graphics/";
  
  String specieId = request.getParameter( "specieId" );
  if( specieId==null || !(specieId.equals("8") || specieId.equals("9")) )
  	specieId = "7";
  String specie = "Human";
  String lSpecie = "human";
  if( specieId.equals("8") )
  {
 	specie = "Rat";
	lSpecie = "rat";
  }	
  if( specieId.equals("9") )
  {
	specie = "Mouse";
	lSpecie = "mouse";
  }	

  String chromosome = request.getParameter( "chromosome" );
  if( chromosome == null ) chromosome = "0";
  
  File imgf = new File( locDir+webDir+specieId+"_"+chromosome+"_chromosome.gif" );
  String sImg = "not found";
  GIFInfo imgInf = null;
  try{
  	sImg = imgf.getCanonicalPath();
	imgInf = GIFInfo.getGIFInfo( sImg );
  } catch( Exception ex2 ) {}
  if( imgInf == null ) imgInf = new GIFInfo();

%>

<TITLE>Bioinformatics Research Laboratory - Rat/Mouse/Human Three-Way Comparisome</TITLE>
<LINK REL="stylesheet" HREF="/styles/style_brl.css<%=jsVersion%>" TYPE="text/css">
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
</HEAD>
<BODY>

<%@ include file="include/header.incl" %>
<%@ include file="include/navbar.incl" %>
<br>

<TABLE WIDTH="100%" CELLPADDING="0" CELLSPACING="3" BORDER="0">

  <TR> 
    <TD> 
      <!-- BEGIN: PAGE CONTENT -->
      <TABLE CELLPADDING="0" CELLSPACING="0" BORDER="0" WIDTH="100%">
        <TR> 
          <TD VALIGN="top" WIDTH="30">&nbsp;
          </TD>
          <TD WIDTH="10"> <IMG SRC="<%=imageDir%>spacer.gif" HEIGHT="1" WIDTH="10" ALT="" BORDER="0"> 
          </TD>
          <TD VALIGN="top" ALIGN="left"> <TABLE CELLPADDING="0" CELLSPACING="3" BORDER="0">
              <TR> 
                <TD>
				<% if( specieId.equals("7") ) { %>
				<IMG SRC="<%=imageDir%>pash/human_thumb_small.gif" WIDTH="29" HEIGHT="41" ALIGN="center" BORDER="0">
				<% } else if( specieId.equals("8") ) { %>
				<IMG SRC="<%=imageDir%>pash/rat_thumb_small.gif" WIDTH="61" HEIGHT="41" ALIGN="center" BORDER="0">
				<% } else if( specieId.equals("9") ) { %>
				<IMG SRC="<%=imageDir%>pash/mouse_thumb_small.gif" WIDTH="61" HEIGHT="41" ALIGN="center">
				<% } %>
                </TD>
                <TD> <SPAN CLASS="hdr"><B>Whole Chromosome View</B>:</SPAN> <%=specie%> 
                  chromosome <%=chromosome%> </TD>
              </TR>
            </TABLE></TD>
        </TR>
        <TR> 
          <TD COLSPAN="2"> <IMG SRC="<%=imageDir%>spacer.gif" HEIGHT="1" WIDTH="40" ALT="" BORDER="0"> 
          </TD>
          <TD ALIGN="left" WIDTH="100%"> <BR> <UL>
              <LI>Clicking on a chromosome segment will open a new window with 
                the detailed Genboree view of that segment.This similarities were 
		found using <A HREF="http://brl.bcm.tmc.edu/pash/index.html"><U>Pash</U></A>.</LI>
            </UL>
            <!-- END: INFO -->
          </TD>
        </TR>
      </TABLE>
      <!-- END: PAGE CONTENT -->
    </TD>
  </TR>
</TABLE>
<!-- BEGIN: PAGE CONTENT -->
<TABLE WIDTH="530" CELLPADDING="0" CELLSPACING="3" BORDER="0">
  <TR> 
    <TD> <IMG SRC="<%=imageDir%>spacer.gif" HEIGHT="1" WIDTH="40" ALT="" BORDER="0"> 
    </TD>
    <!--
	<TD ALIGN="right">
		<FONT SIZE="-2">[ <A HREF="mouse_compact.html">Compact View</A> ]</FONT>
		<IMG SRC="<%=imageDir%>spacer.gif" WIDTH="5" HEIGHT="0" BORDER="0">
	</TD>
	-->
  </TR>
  <TR> 
    <TD> <IMG SRC="<%=imageDir%>spacer.gif" HEIGHT="1" WIDTH="40" ALT="" BORDER="0"> 
    </TD><TD>
    <!-- BEGIN: INFO -->
    <TABLE CELLSPACING="0" CELLPADDING="0" BORDER="1">
      <TR><TD>

<!--
        <TD> <EMBED
					TYPE="image/svg+xml"
					SRC="/java-bin/SVGServlet?specieId=8&chromosome=6"
					WIDTH="530"
					HEIGHT="460"
					ALIGN="CENTER"
					MEMORY="15"
					PLUGINSPAGE="http://www.adobe.com/svg/viewer/install/main.html"> 
          </EMBED> </TD>
-->

<%
	File fMap = new File( locDir+webDir+specieId+"_"+chromosome+"_chromosome.map" );
	try
	{
		BufferedReader in = new BufferedReader( new FileReader(fMap.getCanonicalPath()) );
		String s = null;
		while( (s = in.readLine()) != null )
		{
%>
        <%=s%> 
<%
		}
		in.close();
	} catch( Exception ex3 ) {}
%>

		<img src="/<%=webDir%><%=specieId%>_<%=chromosome%>_chromosome.gif" border=0
  width=<%=imgInf.getWidth()%> height=<%=imgInf.getHeight()%>
  usemap=#genomeimap ismap>

	    </TD></TR>
    </TABLE>
	
<!--
	<TABLE WIDTH="100%" CELLPADDING="0" CELLSPACING="0" BORDER="0">
      <TR> 
        <TD WIDTH="100%" COLSPAN="1" ALIGN="center"> <FONT SIZE="-2"> (Image above 
          is an SVG visualization, a W3C standard. <A HREF="http://brl.bcm.tmc.edu/svgInfo.html">Problems 
          viewing SVGs?</A>) </FONT> </TD>
      </TR>
    </TABLE>
    &nbsp;
    <P> 
-->

    <CENTER>
      <TABLE CELLPADDING="0" CELLSPACING="3" BORDER="0">
        <TR> 
          <TD> <A HREF="VGPaint.jsp"> <IMG SRC="<%=imageDir%>pash/upArrow_small.gif" WIDTH="32" HEIGHT="41" ALIGN="center" BORDER="0"> 
            </A> </TD>
          <TD> <A HREF="VGPaint.jsp"> Three-Genome Main </A> </TD>
          <TD><IMG SRC="<%=imageDir%>spacer.gif" WIDTH="20" HEIGHT="0" BORDER="0"></TD>
          <TD> <A HREF="syntenyCompact.jsp?specieId=<%=specieId%>"><IMG SRC="<%=imageDir%>pash/<%=lSpecie%>_thumb_small.gif" ALIGN="center" BORDER="0"></A> 
          </TD>
          <TD> <A HREF="syntenyCompact.jsp?specieId=<%=specieId%>"><%=specie%> Overview</A> </TD>
        </TR>
      </TABLE>
    </CENTER>
    &nbsp;<BR></TD>
  </TR>
</TABLE>
<!-- END: PAGE CONTENT -->

<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
