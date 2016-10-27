<%@ page import="java.text.NumberFormat,
    java.text.DecimalFormat,
    java.io.InputStream,
    java.util.*,
    java.util.regex.Pattern,
    java.util.regex.Matcher,
    java.lang.reflect.Array,
    org.genboree.util.*,
    java.sql.*,
    java.util.Date,
    org.genboree.editor.AnnotationEditorHelper,
    org.genboree.message.GenboreeMessage"
%>
<%@ page import="javax.servlet.http.*, org.genboree.upload.HttpPostInputStream " %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%@ include file="include/fidInfo.incl" %>
<%@ include file="include/cancelHandler.incl" %>
<%
    GenboreeMessage.clearMessage(mys);
    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );
    Vector vlog = new Vector ();
    HashMap errorFields = new HashMap ();
    boolean success = false;
    String  distance  = "";
    if (request.getParameter("upfid")== null) {
        distance = (String)mys.getAttribute("distance");
    }

    HashMap name2Values = new HashMap ();
    String changed="0";
    int i = 0;
    String errorPage = "/java-bin/error.jsp";
    AnnotationDetail annotation = new AnnotationDetail(ifid);
    int db2jsp  = 0;
    String message = "";
    Connection con =  db.getConnection(dbName);
    if (con == null || con.isClosed())
        GenboreeUtils.sendRedirect(request,response, destback);
    annotation = AnnotationEditorHelper.findAnnotation(annotation, db, con, fid);
    if (annotation == null ) {
        mys.setAttribute("lastError", "No annotation in annotationShift.jsp");
        GenboreeUtils.sendRedirect(request,response, errorPage);
        return;
    }
    else {
        mys.setAttribute("annotation", annotation);
    }
    long chromosomeLength = AnnotationEditorHelper.findChromosomeLength (con, db, dbName, annotation.getRid());
    annotation = AnnotationEditorHelper.convertAnnotation(annotation, db2jsp);
   // String confirm = "confirmAction ( shift ) ";
    mys.setAttribute("localdbName", dbName);
    mys.setAttribute("localConnection", con);
   String  direction = request.getParameter ("direction");
    //if (request.getParameter("btnShiftAnnotation") != null) {
            String okValue =  request.getParameter("okShift");
            if (okValue != null && okValue.compareTo ("1") ==0) {
                direction = request.getParameter ("direction");
                distance = request.getParameter("distance");
                if (distance != null) {
                    mys.setAttribute("distance", distance);
                }
        if (AnnotationEditorHelper.validateShift(distance, annotation.getFstart(), annotation.getFstop(), chromosomeLength, direction,  errorFields, vlog, out)) {
        String fbin = "";
        long dist = Long.parseLong(distance);
        long newStart =  0 ;
        long newStop = 0;

        if (direction != null && direction.compareTo("3")==0) {
        newStart = dist + annotation.getStart();
        newStop = dist + annotation.getStop();
        fbin = (Refseq.computeBin(newStart, newStop, 1000));
        }
        else if (direction != null && direction.compareTo("5")==0) {
        newStart = -dist + annotation.getStart();
        newStop =  -dist + annotation.getStop();
        fbin = (Refseq.computeBin(newStart, newStop, 1000));
        }
        else {
        // report error and exit
        }
        success =   AnnotationEditorHelper.updateAnnotation (newStart, newStop, fbin, ifid,db,  dbName, out, con) ;

        if ( success) {
            mys.removeAttribute("distance");
            if ( errorFields.get("distance") != null)
            errorFields.remove("distance");
            int refseqid = upload.getRefSeqId();
            int  ftypeid =  annotation.getFtypeId();
            String gname = annotation.getGname();
            int rid =  annotation.getRid();
            boolean validParams = false;

            if (refseqid >0 && ftypeid >0 && rid >0 && gname != null)
            validParams = true;

            if (validParams)
            GenboreeUtils.processGroupContextForGroup(""+refseqid,  gname,  "" + ftypeid,  "" + rid);
            CacheManager.clearCache(db, upload.getDatabaseName());
            if (dbName == null)
            response.sendRedirect(destback);

            annotation = AnnotationEditorHelper.findAnnotation(annotation, db, con, fid);
            if (annotation == null)
            response.sendRedirect(destback);
            annotation = AnnotationEditorHelper.convertAnnotation(annotation, db2jsp);
            message = "The annotation has been shifted successfully toward  " + direction + "' end for " + distance + " bp.";
            GenboreeMessage.setSuccessMsg(mys, message);
         }
        else {
            if (JSPErrorHandler.checkErrors(request, response,db,mys))
                return;
        }
      }
   }
      //  }

    String aid = "distance";
    String aval = "";
    String validate =  "return validateForm(" + chromosomeLength + ");" ;
    int currentIndex = 0;

 %>

<HTML>
  <head>
    <title>Genboree - Show Annotation Text and Sequence</title>
    <link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
    <link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">
    <link rel="stylesheet" href="/styles/annotationEditor.css<%=jsVersion%>" type="text/css">
    <script type="text/javascript" src="/javaScripts/util.js<%=jsVersion%>"></script>
    <SCRIPT type="text/javascript" src="/javaScripts/commonFunctions.js<%=jsVersion%>"></SCRIPT>
    <SCRIPT TYPE="text/javascript" SRC="/javaScripts/prototype.js<%=jsVersion%>"></SCRIPT>
    <SCRIPT TYPE="text/javascript" SRC="/javaScripts/editorCommon.js<%=jsVersion%>"></SCRIPT>
    <SCRIPT TYPE="text/javascript" SRC="/javaScripts/shiftAnnotation.js<%=jsVersion%>"></SCRIPT>
    <SCRIPT TYPE="text/javascript" SRC="/javaScripts/delimitComments.js<%=jsVersion%>"></SCRIPT>
    <link rel="stylesheet" href="/styles/avp.css<%=jsVersion%>" type="text/css">
    <LINK rel="stylesheet" href="/styles/querytool.css<%=jsVersion%>" type="text/css">
    <meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
<%
    if(success)
    {
%>
      <script>
        confirmRefresh() ;
      </script>
<%
    }
%>
  </head>
  <BODY>
<%@ include file="include/header.incl" %>
<%@ include file="include/validateFid.incl" %>
<%@ include file="include/avpPopulator.incl" %>
<form name="editorForm" id="editorForm"  action="annotationShift.jsp" method="post" onSubmit="<%=validate%>" >
<input type="hidden"  name="okShift" id="okShift" value="0">
<input type="hidden" name="changed" id="changed" value="<%=changed%>">
<input type="hidden" name="cancelState" id="cancelState" value="0">
<table width="100%" border="0" cellpadding="2" cellspacing="2">
<tr>
<td>
<p>&nbsp;
<CENTER><FONT SIZE="4"><B>Shift This Annotation</B></FONT></CENTER>
<%@ include file="include/message.incl" %>
<%
 // if (success) { %>
<!--div class="successMsg" id="successMsg" align="center">
</div-->
<% // } else { %>
<font color="red" >
<div id="messageid" >
<%
if( vlog != null && vlog.size() > 0 ) {
out.print( " <UL class=\"compact2\">" );
for( i=0; i<vlog.size(); i++ ) {
out.print( "<li> &middot; " + (String)vlog.elementAt(i) +"</li>" );  }
out.println( "</ul>" );  }
%>
</div>
</font>
<br>
<% //}
%>
<div align="center">
<TABLE  border="1" cellpadding="2" cellspacing="1" width="560pt">
<%
if (!success) { %>
<TR> <nobr>
<% if (errorFields.get("distance") == null) { %>
<TD name="distanceLabel" id="distanceLabel"  class="annotation2"  width="60pt" align="right">
<B>&nbsp;Distance&nbsp;(bp):</B>
</TD>
<%} else {%>
<TD name="distanceLabel" id="distanceLabel"  class="annotation1"  width="60pt" align="left">
<B>&nbsp;Distance&nbsp;(bp):</B>
</TD>
<%}%>
<td class="form_body">
<input  name="distance" id="distance" width="80"  type="text" align="left" maxlength="20" value="<%=distance%>"  onChange="setChanged(1);" onKeyPress="return event.keyCode!=13"  >
</td>
<% if (errorFields.get("direction") == null) { %>
<td  name="directionLabel" id="directionLabel" class="annotation2" width="60pt" align="right">
<B> &nbsp;&nbsp;Direction:</B>
</td>
<%} else {%>
<td  name="directionLabel" id="directionLabel" class="annotation1" width="60pt" align="right">
<B> &nbsp;&nbsp;Direction:</B>
</td>
<%}%>

<td width="300" align="left" class="form_body" >
<NOBR> <input  name="direction" id="direction5" type="radio"  value="5">
<B>5'&nbsp;</B>
<input  name="direction" id="direction3" type="radio"  value="3">
<B>3'&nbsp;</B>(Relative&nbsp;to&nbsp;<B>&nbsp;POSITIVE&nbsp;</B>&nbsp;strand)
</NOBR>
</TD>
</nobr>
</TR>

<% } %>
</TABLE>
</div>
<br>
<table  width="100%" border="0" cellpadding="0" cellspacing="0">
    <TR>
    <TD>
    <table width="100%" id="infoTable"  border="1" cellpadding="2" cellspacing="1">
    <TR>
    <TD class="annotation2" colspan="1"> <div id="annoname" > <B>Annotation&nbsp;Name</B></div> </td>
    <TD class="annotation2" colspan="3">
    <input READONLY type="text" name="gname" id ="gname" class="largeInputRO"  maxlength="200" value="<%=Util.htmlQuote(annotation.getGname()) %>" >
    </TD>
    </TR>
    <TR id="trackRow">
    <TD ALIGN="left" class="annotation2" colspan="1">
    <div id="track"><B>Track<B></div></TD>
    <TD class="annotation2" colspan="1">
    <input READONLY type="text"  name="trackName"  id="trackName" class="longInputRO" value="<%=annotation.getTrackName()%>">
    </TD>
    <TD ALIGN="left" class="annotation2" colspan="2">&nbsp;</TD>
    </TR>
    <TR>
    <TD ALIGN="left" class="annotation2" colspan="1"><div id="ch2"><B>Chromosome<B></div></TD>
    <TD class="annotation2" colspan="">
    <input READONLY type="text"  name="chromosomes"  id="chromosomes" class="longInputRO" value="<%=annotation.getChromosome()%>">
    </TD>    <TD ALIGN="left" class="annotation2" colspan="2">&nbsp;</TD>
    </TR>
    <TR>
    <TD ALIGN="left" class="annotation2" colspan="1"><div id="startLabel"><B>Start<B></div></TD>
    <TD class="annotation2" colspan="1">
    <input READONLY type="text"  class="longInputRO" name="ep_Start" id="ep_Start" maxlength="50" value= "<%=annotation.getFstart()%>" >
    </TD>
    <TD ALIGN="left" class="annotation2" colspan="1"><div id="stop"><B>Stop<B></div></TD>
    <TD class="annotation2" BGCOLOR="white" colspan="1">
    <input READONLY type="text" class="longInputRO" name="ep_Stop" id="ep_Stop" maxlength="50"  value="<%=annotation.getFstop()%>" >
    </TD>
    </TR>
    <TR>
    <TD ALIGN="left" class="annotation2" colspan="1"><div id="qstart"><B>Query&nbsp;Start</B></div></TD>
    <!-- Target Start -->
    <TD class="annotation2" colspan="1">
    <input name="tstart" READONLY id = "tstart" type="text" BGCOLOR="white" class="longInputRO" maxlength="50" value="<%=annotation.getTstart()%>" >
    </TD>
    <TD ALIGN="left" class="annotation2" colspan="1"><div id="qstop"><B>Query&nbsp;Stop</B></div></TD>
    <!-- Target Stop -->
    <TD class="annotation2" colspan="1">
    <input type="text" READONLY name="tstop" id="tstop" BGCOLOR="white" class="longInputRO" maxlength="50" value="<%=annotation.getTstop()%>">
    </TD>
    </TR>
    <TR>
        <TD ALIGN="left" class="annotation2" colspan="1"><strand><B>Strand</B></div></td>
        <TD class="annotation2" colspan="1">
        <input READONLY type="text" class="longInputRO" name="strand" id="strand" BGCOLOR="white" maxlength="50" value="<%=annotation.getStrand()%>">
        </TD>
        <TD ALIGN="left" class="annotation2" colspan="1"><div id="phase"></div><B>Phase</B></div></TD>
        <TD ALIGN="left" class="annotation2" colspan="1">
        <input READONLY type="text" class="longInputRO" name="phase" id="phase" BGCOLOR="white" maxlength="50" value="<%=annotation.getPhase()%>">
        </TD>
        </TR>
        <TR>
        <TD ALIGN="left" class="annotation2" colspan="1"><div id="score"><B>Score</B></div></TD>                                                     			<!-- SCORE -->
        <TD ALIGN="left" class="annotation2" colspan="1">
        <input READONLY type="text" class="longInputRO" name="fscore" id="fscore" BGCOLOR="white" maxlength="50" value="<%=annotation.getFscore()%>">
        </TD>
        <TD ALIGN="left" class="annotation2" colspan="2">&nbsp;</TD>
        </TR>

        <%@ include file="include/singleAnnoAVPDisplay4cols.incl" %>

        <TR>
        <TD ALIGN="left" colspan="1" class="annotation2"><div id="labelcomment"><B>Free-Form Comment</B></div></TD>
        <TD align="left" class="annotation2" colspan="3">
        <TEXTAREA READONLY name="comments" id="comments"  align="left" rows="4" class="largeTextareaRO" value="<%=annotation.getComments()%>"><%=annotation.getComments()%></TEXTAREA>
        </TD>
        </TR>
        <TR>
        <TD ALIGN="left" colspan="1" class="annotation2"><div id="sequences"><B>Sequence</B></div></TD>
        <TD align="left" class="annotation2" colspan="3">
        <TEXTAREA READONLY name="sequence" id="sequence" align="left" rows="4" class="largeTextareaRO"  value="<%=annotation.getSequences()%>"><%=annotation.getSequences()%></TEXTAREA>
        </TD>
        </TR>
       </TABLE>
        </TD>
        </TR>
        </TABLE>
        <br>
        <table align="left" width="50%" border="0" cellpadding="2" cellspacing="10" >
        <p align="center">
        <tr align="center"  class="form_body">   &nbsp;&nbsp;
        <nobr>
        <% if (!success) { %>
        <input  type="button"  class="btn"   name="btnShiftAnnotation" id="btnShiftAnnotation"  value=" Shift " width="120" HEIGHT="110"  onclick="shiftCoord(<%=chromosomeLength%>);"> &nbsp;
        <input type="button" name="btnCancel" id="btnCancel" value="Cancel"  class="btn" onClick="processQuit('<%=aval%>', '<%=aid%>');" >
        <%   }else { %>
        <input type="button" name="btnClose" id="btnClose" value="Close Window"  class="btn" onClick="window.close();">
        <%}%>
        </nobr>
        </tr>
        </p>
        </table>
        </td>
        </tr>
        </table>
        </form>
<%@ include file="include/invalidFidMsg.incl"%>
<%@ include file="include/footer.incl" %>
    </BODY>
</HTML>
