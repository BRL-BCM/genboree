<%@ page import="java.sql.ResultSet,
    java.text.NumberFormat,
    java.text.DecimalFormat,
    java.io.InputStream,
    java.sql.SQLException,
    java.util.*,
    java.sql.Time,
    java.lang.reflect.Array,
    java.sql.Connection,
    org.genboree.util.*,
    org.genboree.editor.AnnotationEditorHelper"
%>
<%@ page import="javax.servlet.http.*, org.genboree.upload.HttpPostInputStream " %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%@ include file="include/fidInfo.incl" %>
<%
    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );
    boolean deleted = false;
    boolean refreshGbrowser = false;
    int i = 0;
    int currentIndex = 0;

    HashMap name2Values = new HashMap ();
    String upfid22 = (String)mys.getAttribute("lastTextID") ;

    if (request.getParameter("btnCancel") != null) {
          if (upfid22!=null) {
              GenboreeUtils.sendRedirect(request, response, "/java-bin/annotationEditorMenu.jsp?upfid="+ upfid22) ;
               return;
          }
          else {
              out.println ("<script> window.close(); </script>");
          }
    }
    AnnotationDetail annotation = new AnnotationDetail(ifid);
     int db2jsp  = 0;
    String message = "";
    Connection con =  db.getConnection(dbName);
    if (con == null || con.isClosed())
        GenboreeUtils.sendRedirect(request,response, destback);

    if (request.getParameter("upfid") != null) {
        annotation = AnnotationEditorHelper.findAnnotation (annotation, db, con, fid );
        if (annotation == null || annotation.getGname() == "") {
             GenboreeUtils.sendRedirect(request,response, "/java-bin/error.jsp");
        }
        annotation = AnnotationEditorHelper.convertAnnotation(annotation, db2jsp);
        mys.setAttribute("lastAnnotation", annotation);

        mys.removeAttribute("name2Values");
    }
    else {
        annotation = (AnnotationDetail)mys.getAttribute("lastAnnotation");
        if (mys.getAttribute("name2Values") != null)
        name2Values = (HashMap)mys.getAttribute("name2Values");

    }

    if (request.getParameter("doSelected") != null) {
        String status = request.getParameter("okState");
         if (status != null && status.compareTo("1")==0) {
            AnnotationEditorHelper.deleteAnnotation(annotation.getFid(), db, upload.getDatabaseName(), out, con);
           // .addValuePairs(con,  ""+upload.getRefSeqId(), ifid, annotation.getFtypeId(), name2Values, 0);
            ArrayList fids = new ArrayList();
            fids.add("" + annotation.getFid());
             GenboreeUtils.deleteValuePairs(con, "" + upload.getRefSeqId(), fids);
            deleted = true;
            refreshGbrowser = true;
             message = "<li>The annotation has been deleted successfully.<br> " ;
        }
    }

   if (deleted){
        int refseqid = upload.getRefSeqId();
        int  ftypeid =  annotation.getFtypeId();
        String gname = annotation.getGname();
        int rid =  annotation.getRid();
        boolean validParams = false;
        if (refseqid >0 && ftypeid >0 && rid >0 && gname != null)
        validParams = true;
        if (validParams)
        GenboreeUtils.processGroupContextForGroup(""+refseqid,  gname,  "" + ftypeid,  "" + rid, false);
        CacheManager.clearCache(db, upload.getDatabaseName()) ;
    }
%>
<HTML>
<head>
  <title>Genboree - Show Annotation Text and Sequence</title>
  <link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
  <link rel="stylesheet" href="/styles/annotationEditor.css<%=jsVersion%>" type="text/css">
  <SCRIPT TYPE="text/javascript" SRC="/javaScripts/delimitComments.js<%=jsVersion%>"></SCRIPT>
  <SCRIPT TYPE="text/javascript" SRC="/javaScripts/prototype.js<%=jsVersion%>"></SCRIPT>
  <SCRIPT TYPE="text/javascript" SRC="/javaScripts/editorCommon.js<%=jsVersion%>"></SCRIPT>
  <SCRIPT TYPE="text/javascript" SRC="/javaScripts/prototype.js<%=jsVersion%>"></SCRIPT>
  <script type="text/javascript" src="/javaScripts/util.js<%=jsVersion%>"></script>
  <SCRIPT TYPE="text/javascript" SRC="/javaScripts/commonFunctions.js<%=jsVersion%>"></SCRIPT>
  <script src="/javaScripts/attributeValuePairs.js<%=jsVersion%>"  defer="true" type="text/javascript"></script>
  <link rel="stylesheet" href="/styles/avp.css<%=jsVersion%>" type="text/css">
  <LINK rel="stylesheet" href="/styles/querytool.css<%=jsVersion%>" type="text/css">
<%
  if(refreshGbrowser)
  {
    refreshGbrowser = false;
%>
    <script language="javascript" type="text/javascript">
      confirmRefresh() ;
      onBlur=self.focus();
    </script>
<%
  }
%>
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY>
<%@ include file="include/header.incl" %>
<%@ include file="include/validateFid.incl" %>
<%@ include file="include/avpPopulator.incl" %>
<form name="editorForm" id="editorForm"  action="delAnnotationEditor.jsp" method="post"   >
<input type="hidden"  name="okState" id="okState" value="0">
<input type="hidden"  name="doSelected" id="doSelected" value="">
    <table width="100%" border="0" cellpadding="2" cellspacing="2">
    <tr><BR>
    <td>
    <div align="center" class="title4">Delete This Annotation</div> <BR>
    <div class="successMsg" align="center">
    <UL class="compact2"  >
    <%=message%>
    </UL>
    </div>
    <table  width="100%" border="0" cellpadding="0" cellspacing="0">


        <TR><TD>&nbsp;</TD></TR>
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
    <input READONLY type="text" class="longInputRO" name="epStop" id="epStop" maxlength="50"  value="<%=annotation.getFstop()%>" >
    </TD>
    </TR>
    <TR>
    <TD ALIGN="left" class="annotation2" colspan="1"><div id="qstart"><B>Query&nbsp;Start</B></div></TD>
    <TD class="annotation2" colspan="1">
    <input name="tstart" READONLY id = "tstart" type="text" BGCOLOR="white" class="longInputRO" maxlength="50" value="<%=annotation.getTstart()%>" >
    </TD>
    <TD ALIGN="left" class="annotation2" colspan="1"><div id="qstop"><B>Query&nbsp;Stop</B></div></TD>
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
    <TD align="left" class="annotation1" colspan="3">
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
    <tr align="center"  class="form_body">&nbsp;&nbsp;
    <nobr>
    <% if (!deleted) { %>
    <input  type="button"  class="btn"   name="btnDeleteAnnotation" id="btnDeleteAnnotation"  value=" Delete "   width="120" HEIGHT="110" onClick="confirmAction1('delete', '<%=annotation.getGname()%>')"> &nbsp;
    <input type="submit" name="btnCancel" id="btnCancel" value="Cancel"  class="btn" >
    <%
    }
    else {
    %>
    <input type="button" name="btnClose" id="btnClose" value="Close Window"  class="btn" onClick="window.close();">
    <%}%>
    </nobr>
    </tr>
    </p>
    </table>
    <td>
    </tr>
    </table>
    </form>
    <%@ include file="include/invalidFidMsg.incl"%>
    <%@ include file="include/footer.incl" %>
    </BODY>
    </HTML>
