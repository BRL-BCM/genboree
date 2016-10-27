<%@ page import="java.util.*, java.io.*, org.genboree.util.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%
	
  String locDir = org.genboree.util.Constants.GENBOREE_HTDOCS;
  String catBase = System.getProperty( "catalina.base" );
  if( catBase != null ) locDir = catBase + "/";
  String webDir = "syntenyGIFS/";
  String parentUrl = "http://brl.bcm.tmc.edu/";
  String imageDir = parentUrl+"graphics/";
  
  boolean is_human = false;
  boolean is_rat = false;
  boolean is_mouse = false;
  String specieId = request.getParameter( "specieId" );
  if( specieId == null ) specieId = "7";
  if( specieId.equals("8") ) is_rat = true;
  else if( specieId.equals("9") ) is_mouse = true;
  else { specieId = "7"; is_human = true; }
  
  File imgf = new File( locDir+webDir+specieId+"_compact.gif" );
  String sImg = "not found";
  GIFInfo imgInf = null;
  try{
  	sImg = imgf.getCanonicalPath();
	imgInf = GIFInfo.getGIFInfo( sImg );
  } catch( Exception ex2 ) {}
  if( imgInf == null ) imgInf = new GIFInfo();
%>
<HTML>
<HEAD>
<SCRIPT type="text/javascript">

//Popup Window Script
//By JavaScript Kit (http://javascriptkit.com)
// With mods by Andrew R. Jackson
var winpops
function openpopup(theUrl){
var popurl= theUrl
winpops=window.open(popurl,"pgiGlossary","width=475,height=338,scrollbars,resizable,")
winpops.focus()
}

var newWin
function openNewWin(theUrl){
var winUrl = theUrl
newWin = window.open(winUrl, "", "width=600,height=440,toolbar,location,directories,status,scrollbars,menubar,resizable,")
newWin.focus()
}

function openLink( theUrl )
{
	location.href = theUrl;
}

</SCRIPT>

<TITLE>Bioinformatics Research Laboratory - Rat/Mouse/Human Three-Way Comparisome</TITLE>
<LINK REL="stylesheet" HREF="/styles/style_brl.css<%=jsVersion%>" TYPE="text/css">
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
</HEAD>
<BODY>

<table cellpadding=0 cellspacing=0 border=0 bgcolor=white width="840" class='TOP'>
<tbody>
  <tr><td width=10></td>
  <td height=10></td>
  <td width=10></td>
  <td width=10 class="bkgd"></td></tr>
  <tr><td></td><td>
  
      <table border=0 cellpadding=0 cellspacing=0 width="100%"><tr>
        <td width="484"><a href="defaultGbrowser.jsp"><img
          src="/images/genboree.jpg" width="484" height="72" border="0"
          alt="Genboree"></a></td>
        <td align="center"><a href="http://hgsc.bcm.tmc.edu"><img
          src="/images/hgsc50.gif" width="93" height="50"
          alt="HGSC" border="0"></a></td>
        <td align="right" width="70"><a href="http://brl.bcm.tmc.edu"><img
          src="/images/brl50.gif" width="70" height="50"
          alt="Bioinformatics Research Laboratory" border="0"></a></td>
       </tr></table>

  </td>
  <td width=10></td>
  <td class="shadow"></td></tr>
  <tr><td></td><td>
<%@ include file="include/navbar.incl" %>
<br>

<TABLE CELLPADDING="0" CELLSPACING="3" BORDER="0">

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
                <% if( is_human ) { %>
                <TD> <IMG SRC="<%=imageDir%>pash/human_thumb_small.gif" WIDTH="29" HEIGHT="41" ALIGN="center"> 
                </TD>
                <TD> <SPAN CLASS="hdr"><B>Human-Centric View</B>:</SPAN> Rat and 
                  Mouse chromosomal similarity to the chromosomes of Human.
		  This similarities were found using <A HREF="http://brl.bcm.tmc.edu/pash/index.html"><U>Pash</U></A>.
		 </TD>
                <% } else if( is_rat ) { %>
                <TD> <IMG SRC="<%=imageDir%>pash/rat_thumb_small.gif" WIDTH="61" HEIGHT="41" ALIGN="center"> 
                </TD>
                <TD> <SPAN CLASS="hdr"><B>Rat-Centric View</B>:</SPAN> Mouse and 
                  Human chromosomal similarity to the chromosomes of Rat.
		  This similarities were found using <A HREF="http://brl.bcm.tmc.edu/pash/index.html"><U>Pash</U></A>.
		 </TD>
                <% } else if( is_mouse ) { %>
                <TD> <IMG SRC="<%=imageDir%>pash/mouse_thumb_small.gif" WIDTH="61" HEIGHT="41" ALIGN="center"> 
                </TD>
                <TD> <SPAN CLASS="hdr"><B>Mouse-Centric View</B>:</SPAN> Rat and 
                  Human chromosomal similarity to the chromosomes of Mouse.
		  This similarities were found using <A HREF="http://brl.bcm.tmc.edu/pash/index.html"><U>Pash</U></A>.
		 </TD>
                <% } %>
              </TR>
            </TABLE></TD>
        </TR>
        <TR> 
          <TD COLSPAN="2"> <IMG SRC="<%=imageDir%>spacer.gif" HEIGHT="1" WIDTH="40" ALT="" BORDER="0"> 
          </TD>
          <TD ALIGN="left" WIDTH="100%"> <BR>
		    <% if( is_human ) { %> <UL>
              <LI>Each Human chromosome (chromosome numbers along the x-axis) 
                is colored according to similarity to: 
                <UL>
                  <LI>Rat chromosomes (&quot;R&quot;, on the left)</LI>
                  <LI>Mouse chromosomes (&quot;M&quot;, on the right)</LI>
                </UL>
              </LI>
              <LI>Clicking on a boxed-region brings up the a more detailed view 
                for that Human chromosome.</LI>
            </UL>
            <% } else if( is_rat ) { %> <UL>
              <LI>Each Rat chromosome (chromosome numbers along the x-axis) is 
                colored according to similarity to: 
                <UL>
                  <LI>Mouse chromosomes (&quot;M&quot;, on the right)</LI>
                  <LI>Human chromosomes (&quot;H&quot;, on the left)</LI>
                </UL>
              </LI>
              <LI>Clicking on a boxed-region brings up the a more detailed view 
                for that Rat chromosome.</LI>
            </UL>
            <% } else if( is_mouse ) { %> <UL>
              <LI>Each Mouse chromosome (chromosome numbers along the x-axis) 
                is colored according to similarity to: 
                <UL>
                  <LI>Rat chromosomes (&quot;R&quot;, on the right)</LI>
                  <LI>Human chromosomes (&quot;H&quot;, on the left)</LI>
                </UL>
              </LI>
              <LI>Clicking on a boxed-region brings up the a more detailed view 
                for that Mouse chromosome.</LI>
            </UL>
            <% } %> 
            <!-- END: INFO -->
          </TD>
        </TR>
      </TABLE>
      <!-- END: PAGE CONTENT -->
    </TD>
  </TR>
</TABLE>
<!-- BEGIN: PAGE CONTENT -->
<TABLE CELLPADDING="0" CELLSPACING="3" BORDER="0">
  <!--
<TR>
	<TD COLSPAN="2" ALIGN="right">
		<FONT SIZE="-2">[ <A HREF="human_expanded.html">Expanded View</A> ]</FONT>
		<IMG SRC="<%=imageDir%>spacer.gif" WIDTH="70" HEIGHT="0" BORDER="0">
	</TD>
</TR>
-->
  <TR> 
    <TD COLSPAN="2"> 
      <!-- BEGIN: INFO -->
      <!--
    	<EMBED
				TYPE="image/svg+xml"
				SRC="/java-bin/SVGServlet?specieId=7&svgType=compact"
				WIDTH="800"
				HEIGHT="350"
				ALIGN="CENTER"
				MEMORY="15"
				PLUGINSPAGE="http://www.adobe.com/svg/viewer/install/main.html"
    	>
    	</EMBED>
    <TABLE WIDTH="100%" CELLPADDING="0" CELLSPACING="0" BORDER="0">
    <TR>
			<TD WIDTH="100%" COLSPAN="1" ALIGN="center">
				<FONT SIZE="-2">
				(Image above is an SVG visualization, a W3C standard.
				<A HREF="http://brl.bcm.tmc.edu/svgInfo.html">Problems viewing SVGs?</A>)
				</FONT>
			</TD>
		</TR>
		</TABLE>
    &nbsp;<P>
-->
      <CENTER>
<%
	File fMap = new File( locDir+webDir+specieId+"_compact.map" );
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
        <img src="/<%=webDir%><%=specieId%>_compact.gif" border=0
  width=<%=imgInf.getWidth()/2%> height=<%=imgInf.getHeight()/2%>
  usemap=#genomeimap ismap>
  <br> 
        <TABLE CELLPADDING="0" CELLSPACING="3" BORDER="0">
          <TR> 
            <TD> <A HREF="VGPaint.jsp"> <IMG SRC="<%=imageDir%>pash/upArrow_small.gif" WIDTH="32" HEIGHT="41" ALIGN="center" BORDER="0"> 
              </A> </TD>
            <TD> <A HREF="VGPaint.jsp"> Three-Genome Main </A> </TD>
            <TD><IMG SRC="<%=imageDir%>spacer.gif" WIDTH="20" HEIGHT="0" BORDER="0"></TD>
            <% if (is_human) { %>
            <TD> <A HREF="syntenyCompact.jsp?specieId=8"> <IMG SRC="<%=imageDir%>pash/rat_thumb_small.gif" WIDTH="61" HEIGHT="41" ALIGN="center" BORDER="0"> 
              </A> </TD>
            <TD> <A HREF="syntenyCompact.jsp?specieId=8"> Rat-Centric View </A> </TD>
            <TD><IMG SRC="<%=imageDir%>spacer.gif" WIDTH="20" HEIGHT="0" BORDER="0"></TD>
            <TD> <A HREF="syntenyCompact.jsp?specieId=9"> <IMG SRC="<%=imageDir%>pash/mouse_thumb_small.gif" WIDTH="61" HEIGHT="41" ALIGN="center" BORDER="0"> 
              </A> </TD>
            <TD> <A HREF="syntenyCompact.jsp?specieId=9"> Mouse-Centric View </A> </TD>
            <% } else if (is_rat) { %>
            <TD> <A HREF="syntenyCompact.jsp?specieId=9"> <IMG SRC="<%=imageDir%>pash/mouse_thumb_small.gif" WIDTH="61" HEIGHT="41" ALIGN="center" BORDER="0"> 
              </A> </TD>
            <TD> <A HREF="syntenyCompact.jsp?specieId=9"> Mouse-Centric View </A> </TD>
            <TD><IMG SRC="<%=imageDir%>spacer.gif" WIDTH="20" HEIGHT="0" BORDER="0"></TD>
            <TD> <A HREF="syntenyCompact.jsp?specieId=7"> <IMG SRC="<%=imageDir%>pash/human_thumb_small.gif" WIDTH="29" HEIGHT="41" ALIGN="center" BORDER="0"> 
              </A> </TD>
            <TD> <A HREF="syntenyCompact.jsp?specieId=7"> Human-Centric View </A> </TD>
            <% } else if (is_mouse) { %>
            <TD> <A HREF="syntenyCompact.jsp?specieId=8"> <IMG SRC="<%=imageDir%>pash/rat_thumb_small.gif" WIDTH="61" HEIGHT="41" ALIGN="center" BORDER="0"> 
              </A> </TD>
            <TD> <A HREF="syntenyCompact.jsp?specieId=8"> Rat-Centric View </A> </TD>
            <TD><IMG SRC="<%=imageDir%>spacer.gif" WIDTH="20" HEIGHT="0" BORDER="0"></TD>
            <TD> <A HREF="syntenyCompact.jsp?specieId=7"> <IMG SRC="<%=imageDir%>pash/human_thumb_small.gif" WIDTH="29" HEIGHT="41" ALIGN="center" BORDER="0"> 
              </A> </TD>
            <TD> <A HREF="syntenyCompact.jsp?specieId=7"> Human-Centric View </A> </TD>
            <% } %>
          </TR>
        </TABLE>
      </CENTER>
      </TD>
  </TR>
</TABLE>
<br>&nbsp;
<!-- END: PAGE CONTENT -->

<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
