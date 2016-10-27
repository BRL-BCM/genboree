<%@ include file="include/downloadGenomicDNA.incl" %>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<HTML>
<head>
  <title>Genboree - Genomic DNA Download</title>
  <link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
  <meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
<SCRIPT type="text/javascript">
  var initialState = '<%= browserRange ? "stCustomRange" : sequenceType %>';
  var initialStrand = '<%=strand%>';
  var chromosomeStart = 1;
  var chromosomeStop = <%=to3%>
  var original_chromosomeStop = '<%=original_to3%>';
  var refName = '<%=refName%>';
  var from1 = '<%=from1%>';
  var to1 = '<%=to1%>';
  var from2 = '<%=from2%>';
  var to2 = '<%=to2%>';
  var from3 = '<%=from3%>';
  var to3 = '<%=to3%>';
  var original_from1 = '<%=original_from1%>';
  var original_from2 = '<%=original_from2%>';
  var original_to1 = '<%=original_to1%>';
  var original_to2 = '<%=original_to2%>';
  var original_refSeq = '<%=originalRefSeq%>';
  var defaultValue = "<%=refName%>" ;

  entryPointSizes = new Array();
  entryPointNames = new Array();
  annoRefSeq = '<%=refName%>' ;
  <%
      timer.addMsg("DONE - setting up JSP page") ;

      // ------------------------------------------------------------------------
      // MLGG copy part of ARJ 8/23/2005 2:52PM  on 10/18/05 12:05 PM:
      //   If too many frefs, we don't send all the EP lengths. Users will enter
      //   info manually and we'll do our best with what they submit.
      // ------------------------------------------------------------------------
      // CASE 1: Have small number of entrypoint. (Most common case.)
      // ------------------------------------------------------------------------
      if(totalFrefCount <= Constants.GB_MAX_FREF_FOR_DROPLIST)
      {
        int ii = 0 ;
        for( Enumeration en=chromosomeProperties.keys(); en.hasMoreElements(); )
        {
            String chromosomeName = (String) en.nextElement();
            String chromosomeSize = new String() ;
            chromosomeSize = (String) chromosomeProperties.get( chromosomeName );
            out.println("entryPointSizes[" + ii + "] = " + chromosomeSize + " ;" ) ;
            out.println("entryPointNames[" + ii + "] = '" + chromosomeName + "' ;" ) ;
            ii += 1 ;
         }
      }
  %>
</SCRIPT>
  <!-- BEGIN: Extjs, etc, Support -->
  <script type="text/javascript" src="/javaScripts/extjs/adapter/prototype/prototype.js<%=jsVersion%>"></script> <!-- Stuff here used in rest of files... -->
  <script type="text/javascript" src="/javaScripts/extjs/adapter/prototype/scriptaculous.js<%=jsVersion%>"></script> <!-- Stuff here used in rest of files... -->
  <script type="text/javascript" src="/javaScripts/extjs/adapter/prototype/ext-prototype-adapter.js<%=jsVersion%>"></script> <!-- Stuff here used in rest of files... -->
  <script type="text/javascript" src="/javaScripts/extjs/package/genboree/ext-coreUtil-only-pkg.js<%=jsVersion%>"></script>
  <link rel="stylesheet" type="text/css" href="/javaScripts/extjs/resources/css/core.css<%=jsVersion%>">
  <link rel="stylesheet" type="text/css" href="/javaScripts/extjs/resources/css/ytheme-genboree.css<%=jsVersion%>">
  <!-- Set a local "blank" image file; default is a URL to extjs.com -->
  <script type='text/javascript'>
    Ext.BLANK_IMAGE_URL = '/javaScripts/extjs/resources/images/genboree/s.gif';
  </script>
  <!-- END -->
  <!-- BEGIN: Genboree Specific -->
  <SCRIPT TYPE="text/javascript" SRC="/javaScripts/overlib.js<%=jsVersion%>"></SCRIPT>
  <SCRIPT TYPE="text/javascript" SRC="/javaScripts/overlib_hideform.js<%=jsVersion%>"></SCRIPT>
  <SCRIPT TYPE="text/javascript" SRC="/javaScripts/overlib_draggable.js<%=jsVersion%>"></SCRIPT>
  <SCRIPT TYPE="text/javascript" SRC="/javaScripts/overlib_cssstyle.js<%=jsVersion%>"></SCRIPT>
  <DIV id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></DIV> <!-- # For overlib support -->
  <script type="text/javascript" src="/javaScripts/downloadGenomicDNA.js<%=jsVersion%>"></script>
  <!-- END -->
</head>
<BODY>

<%@ include file="include/header.incl" %>

<table width="100%" border="0" cellpadding="2" cellspacing="2">
  <tr>
    <td>
      <p>&nbsp; <CENTER><FONT SIZE="4"><B>Genomic DNA Download</B></FONT></CENTER>
<%
      if(refName == null)
      {
        String safeLoc = GenboreeUtils.returnRedirectString(request, response, "/java-bin/index.jsp") ;
%>
        <center>
          <font color="red"><b>ERROR: you have reached this page by following an incorrect link or through
          some other invalid means.</b>
          <p>
          You will be redirected to a safe location in 5 seconds or you can <a href="<%= safeLoc %>" >
          go there now</a>.</font>
          <p>
          <script type="text/javascript">
          //<!--
            function redir()
            {
              top.location="<%= safeLoc %>" ;
            }

            setTimeout('redir()', 5000) ;
          //-->
          </script>
        </center>
<%
      }
      else
      {
        if(browserRange)
        {
%>
          <p align="center">This service retrieves the genomic DNA spanning<BR>
          a region of a particular chromosome or entrypoint.<p>
<%
        }
        else
        {
%>
          <CENTER>
          <FONT SIZE="4"><B>For Annotations in Track <%=trackName%></B></FONT>
          </CENTER>
          <p align="center">This service retrieves the <B>genomic</B> DNA corresponding to one
          or more annotations.<BR>It doesn't retrieve the sequence of the annotation itself (if there is any),<BR>but rather the underlying genomic DNA at the annotation's coordinates.
          <A HREF="javascript:void(0);" onclick="return dgdna_overlibEg('titleExample');" >
            <IMG ALIGN="top" SRC="/images/gEg1.png" BORDER="0" WIDTH="16" HEIGHT="16">
          </A>
          <p>
<%
        }
%>
        <form name="downloadGM" id="downloadGM" action="downloadGenomicDNA.jsp" method="post" onsubmit="return validateDGDNAForm();">
        <input type="hidden" name="uploadId" id="uploadId" value="<%=uploadId%>">
        <input type="hidden" name="isInit" id="isInit" value="false">
<%
        if(!browserRange)
        {
%>
          <input type="hidden" name="trackName" id="trackName" value="<%=trackName%>">
          <input type="hidden" name="fid" id="fid" value="<%=fid%>">
          <input type="hidden" name="typeId" id="typeId" value="<%=typeId%>">
          <input type="hidden" name="groupName" id="groupName" value="<%=groupName%>">
<%
        }
        else
        {
%>
        <input type="hidden" name="browserRange" id="browserRange" value="true">
<%
        }
%>
        <table BGCOLOR="navy" width="100%" border="0" cellpadding="0" cellspacing="1">
        <TR>
          <TD>
            <table width="100%" border="0" cellpadding="2" cellspacing="1">
            <tr>
              <TD WIDTH="20%" class="form_body" ALIGN="right">
                <FONT SIZE="2"><B>Genomic DNA to Download:</B></FONT>
              </TD>
              <td BGCOLOR="white" >
                <TABLE BGCOLOR="white" BORDER="0" CELLPADDING="0" CELLSPACING="0">
                <% if(!browserRange) { %>
                <TR>
                  <TD WIDTH="100%">
                    <input type="radio" id="stAnnOnly" name="sequenceType" value="stAnnOnly" onclick="activateRightControls('stAnnOnly');" checked >
                    Spanning this annotation only.
                  </TD>
                  <TD WIDTH="18">
                    <A HREF="javascript:void(0);" onclick="return dgdna_overlibEg('stAnnOnly');" >
                      <IMG SRC="/images/gEg1.png" BORDER="0" WIDTH="16" HEIGHT="16">
                    </A>
                  </TD>
                  <TD WIDTH="18">
                    <A HREF="javascript:void(0);" onclick="return dgdna_overlibHelp('stAnnOnly');" >
                      <IMG SRC="/images/gHelp1.png" BORDER="0" WIDTH="16" HEIGHT="16">
                    </A>
                  </TD>
                </TR>
                <TR>
                  <TD WIDTH="100%">
                    <input type="radio" id="stGroupRange" name="sequenceType" value="stGroupRange" onclick="activateRightControls('stGroupRange');" >
                    Spanning this annotation's entire group.
                  </TD>
                  <TD WIDTH="18">
                    <A HREF="javascript:void(0);" onclick="return dgdna_overlibEg('stGroupRange');" >
                      <IMG SRC="/images/gEg1.png" BORDER="0" WIDTH="16" HEIGHT="16">
                    </A>
                  </TD>
                  <TD WIDTH="18">
                    <A HREF="javascript:void(0);" onclick="return dgdna_overlibHelp('stGroupRange');" >
                      <IMG SRC="/images/gHelp1.png" BORDER="0" WIDTH="16" HEIGHT="16">
                    </A>
                  </TD>
                </TR>
                <TR>
                  <TD WIDTH="100%">
                    <input type="radio" id="stAnnoGroup" name="sequenceType" value="stAnnoGroup" onclick="activateRightControls('stAnnoGroup');" >
                    Spanning each annotation in this annotations's group.
                  </TD>
                  <TD WIDTH="18">
                    <A HREF="javascript:void(0);" onclick="return dgdna_overlibEg('stAnnoGroup');" >
                      <IMG SRC="/images/gEg1.png" BORDER="0" WIDTH="16" HEIGHT="16">
                    </A>
                  </TD>
                  <TD WIDTH="18">
                    <A HREF="javascript:void(0);" onclick="return dgdna_overlibHelp('stAnnoGroup');" >
                      <IMG SRC="/images/gHelp1.png" BORDER="0" WIDTH="16" HEIGHT="16">
                    </A>
                  </TD>
                </TR>
                <TR>
                  <TD WIDTH="100%">
                    <input type="radio" id="stAnnConcat" name="sequenceType" value="stAnnConcat" onclick="activateRightControls('stAnnConcat');" >
                    Concatenate each annotation's sequence in this annotations's group.
                  </TD>
                  <TD WIDTH="18">
                    <A HREF="javascript:void(0);" onclick="return dgdna_overlibEg('stAnnConcat');" >
                      <IMG SRC="/images/gEg1.png" BORDER="0" WIDTH="16" HEIGHT="16">
                    </A>
                  </TD>
                  <TD WIDTH="18">
                    <A HREF="javascript:void(0);" onclick="return dgdna_overlibHelp('stAnnConcat');" >
                      <IMG SRC="/images/gHelp1.png" BORDER="0" WIDTH="16" HEIGHT="16">
                    </A>
                  </TD>
                </TR>
                <TR>
                  <TD WIDTH="100%">
                    <input type="radio" id="stAnnTrack" name="sequenceType" value="stAnnTrack" onclick="activateRightControls('stAnnTrack');" >
                    Spanning each &quot;<I><%=trackName%></I>&quot; annotation on &quot;<I id="atRefName"><%=refName%></I>&quot;.
                  </TD>
                  <TD WIDTH="18">
                    <A HREF="javascript:void(0);" onclick="return dgdna_overlibEg('stAnnTrack');" >
                      <IMG SRC="/images/gEg1.png" BORDER="0" WIDTH="16" HEIGHT="16">
                    </A>
                  </TD>
                  <TD WIDTH="18">
                    <A HREF="javascript:void(0);" onclick="return dgdna_overlibHelp('stAnnTrack');" >
                      <IMG SRC="/images/gHelp1.png" BORDER="0" WIDTH="16" HEIGHT="16">
                    </A>
                  </TD>
                </TR>
                <TR>
                  <TD WIDTH="100%">
                    <input type="radio" id="stGroupTrack" name="sequenceType" value="stGroupTrack" onclick="activateRightControls('stGroupTrack');" >
                    Spanning each &quot;<I><%=trackName%></I>&quot; annotation group on "<I id="gtRefName"><%=refName%></I>".
                  </TD>
                  <TD WIDTH="18">
                    <A HREF="javascript:void(0);" onclick="return dgdna_overlibEg('stGroupTrack');" >
                      <IMG SRC="/images/gEg1.png" BORDER="0" WIDTH="16" HEIGHT="16">
                    </A>
                  </TD>
                  <TD WIDTH="18">
                    <A HREF="javascript:void(0);" onclick="return dgdna_overlibHelp('stGroupTrack');" >
                      <IMG SRC="/images/gHelp1.png" BORDER="0" WIDTH="16" HEIGHT="16">
                    </A>
                  </TD>
                </TR>
                <!-- TR>
                  <TD WIDTH="100%">
                    <input type="radio" id="stAnnTrackConcat" name="sequenceType" value="stAnnTrackConcat" onclick="activateRightControls('stAnnTrackConcat');" >
                    Concatenate sequences for each &quot;<I><%=trackName%></I>&quot; annotation group on "<I id="gtRefName"><%=refName%></I>".
                  </TD>
                  <TD WIDTH="18">
                    <A HREF="javascript:void(0);" onclick="return dgdna_overlibEg('stAnnTrackConcat');" >
                      <IMG SRC="/images/gEg1.png" BORDER="0" WIDTH="16" HEIGHT="16">
                    </A>
                  </TD>
                  <TD WIDTH="18">
                    <A HREF="javascript:void(0);" onclick="return dgdna_overlibHelp('stAnnTrackConcat');" >
                      <IMG SRC="/images/gHelp1.png" BORDER="0" WIDTH="16" HEIGHT="16">
                    </A>
                  </TD>
                </TR -->
                <% } %>
                <TR>
                  <TD WIDTH="100%" colspan="2">
                    <input type="radio" id="stCustomRange" name="sequenceType" value="stCustomRange" onclick="activateRightControls('stCustomRange');">
                    Spanning a custom range .
                  </TD>
                  <TD WIDTH="18">
                    <A HREF="javascript:void(0);" onclick="return dgdna_overlibHelp('stCustomRange');" >
                     <IMG SRC="/images/gHelp1.png" BORDER="0" WIDTH="16" HEIGHT="16">
                   </A>
                  </TD>
                </TR>
                </TABLE>
              </td>
            </tr>
            <tr>
              <TD WIDTH="20%" class="form_body" ALIGN="right">
                <FONT SIZE="2"><B>EntryPoint:</B></FONT>
              </TD>
              <td BGCOLOR="white">
<%
                if(totalFrefCount <= Constants.GB_MAX_FREF_FOR_DROPLIST)
                {
%>
                  <select name="refName" id="refName" onchange="updateChromosomeSelected(true)" class="txt" style="width:130">
<%
                  if(!browserRange)
                  {
%>
                    <option value="--all entry points--">All Entry Points</option>
<%
                  }
%>
                  </select>
<%
                }
                else
                {
                    // ------------------------------------------------------------------------
                    // CASE 2: Have large number of entrypoint. Use text input. (Most common case.)
                    // ------------------------------------------------------------------------
%>
                  <input type="text" name="refName" id="refName" class="txt" style="width:130px;" value="<%=refName%>">
<%
                }
                // -----------------------------------------------------------------------
%>
                <input type="checkbox" name="chkEntire" id="chkEntire" onClick="setEntryPointId();" value="n">
                <strong>Select All Entry Points</strong>
              </td>
            </tr>
            <tr>
              <TD WIDTH="20%" class="form_body" ALIGN="right">
                <FONT SIZE="2"><B>Strand:</B></FONT>
              </TD>
              <td BGCOLOR="white">
                <TABLE WIDTH="100%" BGCOLOR="white" BORDER="0" CELLPADDING="0" CELLSPACING="0">
                <TR>
                  <TD WIDTH="100%">
                    <input type="radio" name="strand" id="strand_plus" value="plus" checked >plus (+)</input>
                    &nbsp;
                    <input type="radio" name="strand" id="strand_minus" value="minus">minus (-)</input>
                    &nbsp;
                    <input type="radio" name="strand" id="strand_field" value="field">use 'strand' field (<font color="red">see Help</font>)</input>
                  </TD>
                  <TD WIDTH="18">
                    <A HREF="javascript:void(0);" onclick="return dgdna_overlibHelp('strand');" >
                      <IMG SRC="/images/gHelp1.png" BORDER="0" WIDTH="16" HEIGHT="16">
                   </A>
                  </TD>
                </TR>
                </TABLE>
              </td>
            </tr>
            <TR>
              <TD WIDTH="20%" class="form_body" ALIGN="right">
              <FONT SIZE="2"><B>Position:</B></FONT>
              </TD>
              <td BGCOLOR="white" >
                <FONT SIZE="2"><B>&nbsp;Start:</B></FONT>
                <input type="text" id="sequenceStart" name="sequenceStart" class="txt" value="<%=from1%>" size="20" maxlength="55" ONCHANGE="activateRightControls('customRange');"  onKeyPress="activateRightControls('customRange');">&nbsp;&nbsp;
                <FONT SIZE="2"><B>End:</B></FONT>
                <input type="text" id="sequenceEnd" name="sequenceEnd" class="txt" value="<%=to1%>" size="20" maxlength="55" ONCHANGE="activateRightControls('customRange');" onKeyPress="activateRightControls('customRange');">
              </TD>
            </TR>
            <TR>
              <TD WIDTH="20%" class="form_body" ALIGN="right">
              <FONT SIZE="2"><B>Masking:</B></FONT>
              </TD>
              <TD BGCOLOR="white" >
                <TABLE WIDTH="100%" BGCOLOR="white" BORDER="0" CELLPADDING="0" CELLSPACING="0">
                <TR>
                  <TD WIDTH="100%">
                    <input type="checkbox" name="hardRepMask" id="hardRepMask" value="true" <%= hasMaskedSeq ? "" : "disabled='disabled'" %> >&nbsp;<i>Hard</i> repeat-masked</input>
                  </TD>
                  <TD WIDTH="18">
                    <A HREF="javascript:void(0);" onclick="return dgdna_overlibHelp('hardRepMask');" >
                      <IMG SRC="/images/gHelp1.png" BORDER="0" WIDTH="16" HEIGHT="16">
                   </A>
                  </TD>
                </TR>
                </TABLE>
              </TD>
            </TR>
            </TABLE>
          </td>
        </TR>
        </TABLE>
        <P>
        <TABLE BORDER="0">
        <TR>
          <td>
            <input type="submit" name="actionDisplay" id="actionDisplay_view" class="btn" value="View DNA" onclick="javascript:(submitValue='View DNA');">&nbsp;
            <input type="submit" name="actionDisplay" id="actionDisplay_save" class="btn" value="Save DNA" onclick="javascript:(submitValue='Save DNA');">&nbsp;
            <input type="button" name="cancelDownloadGenomicSequences" id="cancelDownloadGenomicSequences" class="btn" value="Reset" onClick="dgdna_reset();">&nbsp;
            <input type="button" name="btnClose" id="btnClose" value="Close Window" class="btn" onClick="window.close();">
          </td>
        </tr>
        </TABLE>
        </form>
<%
      }
%>
    </td>
  </tr>
</table>

<%@ include file="include/footer.incl" %>

</BODY>
</HTML>

<!--
<%
  timer.addMsg("DONE - JSP PAGE END") ;

  timer.writeTimingReport(out) ;
  // timer.writeTimingReport(System.err) ;
%>
-->
