<%@ page import="java.sql.ResultSet,
    java.text.NumberFormat,
    java.text.DecimalFormat,
    java.io.InputStream,
    java.sql.SQLException,
    java.util.*,
    java.util.regex.Pattern,
    java.util.regex.Matcher,
    java.sql.Time,
    java.lang.reflect.Array,
    java.sql.Connection,
    org.genboree.util.*,
    org.genboree.editor.AnnotationEditorHelper,
    org.genboree.manager.tracks.Utility"
 %>
<%@ page import="javax.servlet.http.*, org.genboree.upload.HttpPostInputStream " %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%@ include file="include/fidInfo.incl"%>
<%@ include file="include/cancelHandler.incl"%>
    <%
    String aid = "newGroupName";
    String aval = "";
    String className = "";
    String changed="0";
    int currentIndex=0;
    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );
    boolean duplicated= false;
    HashMap errorFields = new HashMap ();
    String gname = "";
  
    HashMap name2Values = new HashMap ();
    boolean success = false;
    if (request.getParameter("upfid") == null) {
      if (mys.getAttribute("gname") != null) 
        gname = (String )mys.getAttribute("gname");
          if (mys.getAttribute("name2Values") != null)        
        name2Values = (HashMap)mys.getAttribute("name2Values");
    }
    else
        mys.removeAttribute("gname");
        
        
        
        
    if (gname == null)
    gname="";
    int i = 0;
    boolean refreshGbrowser = false;
    int newfid = 0;
    AnnotationDetail annotation = new AnnotationDetail(ifid);
    int db2jsp  = 0;
    String message = "";
    Connection con =  db.getConnection(dbName);
    if (con == null || con.isClosed())
    GenboreeUtils.sendRedirect(request,response, "/java-bin/error.jsp");
    annotation = AnnotationEditorHelper.findAnnotation(annotation, db, con, fid);
    if (annotation== null || annotation.getGname() == "") {
    GenboreeUtils.sendRedirect(request,response, "/java-bin/error.jsp");
    return;
    }
    else
    className = annotation.getGname();
    annotation = AnnotationEditorHelper.convertAnnotation(annotation, db2jsp);
    if (request.getParameter("doSelected") != null) {
    gname = request.getParameter("newGroupName");
    String okValue = request.getParameter("okDuplicate");
    if (okValue != null && okValue.compareTo ("1") ==0) {
    //if (true) {
    gname = request.getParameter("newGroupName");
    if (gname != null)
    gname = gname.trim();

    if (gname != null && ((gname.trim()).compareTo("") !=0) && gname.length() <=200)   {
        if (!Utility.existClassName(dbName, gname, annotation.getFtypeId(), annotation.getRid())) {
        annotation.setGname(gname);
        newfid = AnnotationEditorHelper.duplicateAnnotation (gname, annotation, dbName, con) ;
        if ( newfid >0) {
        errorFields.remove("gname");
        message="";
        mys.removeAttribute("newGroupName");
        success = true;
      
        if (name2Values != null) {
        HashMap avp = new HashMap ();
        Iterator it = name2Values.keySet().iterator();
        while (it.hasNext()) {
        String key = (String)it.next();
        String value =  (String)name2Values.get(key);
        ArrayList list = new ArrayList();
        list.add(value);
        avp.put(key, list);
        }
        GenboreeUtils.addValuePairs(con, ""+upload.getRefSeqId(),  newfid, annotation.getFtypeId(), avp, 0);
        }
        
        textid  = uploadId +  ":" + newfid;
        mys.setAttribute("lastTextID", textid);
        request.setAttribute("upfid", textid);
        String confirmMessage =
        "Successfully duplicated the annotation, &nbsp;" +
        " using the new name '&lt;" + gname + "&gt;'. "
        +  "<br>Would you like to edit this new annotation?" ;
        // message = "<li>The annotation has been duplicated successfully.<br> ";

        String editPage = "/java-bin/annotationEditor.jsp?upfid=" +  uploadId + ":" + newfid ;
        mys.setAttribute( "displayMsg", confirmMessage );
        mys.setAttribute( "displayTgt", editPage);
        GenboreeUtils.sendRedirect(request,response, "/java-bin/confirm.jsp");
        }
    }
      else {
         message = "The new annotation name already exists.<BR><BR> ";
         errorFields.put("gname", "true");
      }}
        else {
            message = "Please enter a valid annotation name.<br><br>";
            errorFields.put("gname", "true");
        }
    }
}

  String validate =  "return validateAnnotationName();" ;
  String annotationClass = "annotation2";
  if (errorFields.get("gname") != null)
     annotationClass = "annotation1";
 aval = className;

 if (gname != null && gname != "" &&className != null && gname.compareTo (className) !=0)
 changed = "1";
 %>
<HTML>
<head>
<title>Genboree - Show Annotation Text and Sequence</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<link rel="stylesheet" href="/styles/annotationEditor.css<%=jsVersion%>" type="text/css">
<SCRIPT TYPE="text/javascript" SRC="/javaScripts/dupanno.js<%=jsVersion%>"></SCRIPT>
<SCRIPT TYPE="text/javascript" SRC="/javaScripts/delimitComments.js<%=jsVersion%>"></SCRIPT>
<SCRIPT TYPE="text/javascript" SRC="/javaScripts/prototype.js<%=jsVersion%>"></SCRIPT>
<script type="text/javascript" src="/javaScripts/util.js<%=jsVersion%>"></script>
<SCRIPT TYPE="text/javascript" SRC="/javaScripts/commonFunctions.js<%=jsVersion%>"></SCRIPT>
<SCRIPT TYPE="text/javascript" SRC="/javaScripts/editorCommon.js<%=jsVersion%>"></SCRIPT>
<link rel="stylesheet" href="/styles/avp.css<%=jsVersion%>" type="text/css">
<LINK rel="stylesheet" href="/styles/querytool.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY>
<%@ include file="include/header.incl" %>
<%@ include file="include/validateFid.incl" %>
<%@ include file="include/avpPopulator.incl" %>
<form name="editorForm" id="editorForm"  action="duplicateAnnotation.jsp" method="post" onSubmit="<%=validate%>">
    <input type="hidden"  name="okDuplicate" id="okDuplicate" value="0">
    <input type="hidden" name="changed" id="changed" value="<%=changed%>">
    <input type="hidden" name="cancelState" id="cancelState" value="0">
    <input type="hidden"  name="doSelected" id="doSelected" value="">
  
    <input type="hidden" name="avpvalues" id="avpvalues" value="">
    <input type="hidden" name="index" id="index" value="<%=currentIndex%>">
 
    <table width="100%" border="0" cellpadding="2" cellspacing="2">
    <TR>
    <TD>
    &nbsp;<CENTER><FONT SIZE="4"><B>Duplicate This Annotation</B></FONT></CENTER>
    <BR>
    <div align="center">
    <TABLE cellpadding="1" cellspacing="1" border="1" width="320pt">
    <TR>  <nobr>
    <TD name="newGrpNameLabel" id="newGrpNameLabel" class="<%=annotationClass%>" align="center" width="180pt">
    <B>New&nbsp;Annotation's&nbsp;Name:&nbsp;</B>
    </TD>
    <TD class="formbody" width="25%">
    <input  name="newGroupName" id="newGroupName" type="text" class="centerInput" align="left" maxlength="200" value="<%=gname%>"  onChange="setChanged(1);" onKeyPress="return event.keyCode!=13"  >
    </TD>    </nobr>
    </TR>
     
    </TABLE>
    </div>
    <table  width="100%" border="0" cellpadding="0" cellspacing="0">
    <TR>        <BR>
    <TD> <UL class="compact2">   <font color="red" size="2">
    <div id="errormessage" align="left"> <br><br>
    <%=message%>
    </div> </font>  </UL>
    </TD>
    </TR>
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
    </TD>
    <TD ALIGN="left" class="annotation2" colspan="2">&nbsp;</TD>
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
    <TD ALIGN="left" class="annotation2" colspan="1"><div><strand><B>Strand</B></div></td>
    <TD class="annotation2" colspan="1">
    <input READONLY type="text" class="longInputRO" name="strand" id="strand" BGCOLOR="white" maxlength="50" value="<%=annotation.getStrand()%>">
    </TD>
    <TD ALIGN="left" class="annotation2" colspan="1"><div id="phase"><B>Phase</B></div></TD>
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
    <TD ALIGN="left" colspan="1" class="annotation2"><div id="labelcomment"><B>Free-FormComment</B></div></TD>
    <TD align="left" class="annotation2" colspan="3">
    <TEXTAREA READONLY name="comments" id="comments" align="left" rows="4" class="largeTextareaRO" value="<%=annotation.getComments()%>"><%=annotation.getComments()%></TEXTAREA>
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
    </TABLE><br>
    <table align="left" width="50%" border="0" cellpadding="2" cellspacing="10" >
    <p align="center">
    <tr align="center"  class="form_body">   &nbsp;&nbsp;
    <nobr>
    <% if (!duplicated) { %>
    <input  type="button"  class="btn"   name="doSelected" id="doSelected"  value=" Duplicate "   width="120" HEIGHT="110" onClick="confirmDuplication();"> &nbsp;
    <input type="button" name="btnCancel" id="btnCancel" value="Cancel"  class="btn"   onClick="processQuit('<%=aval%>', '<%=aid%>');" >
    <% }
    else {  %>
    <input type="button" name="btnClose" id="btnClose" value="Close Window"  class="btn" onClick="window.close();">
    <%}%>
    </nobr>
    </tr>
    </p>
    </table>
</TD>
</TR>
</TABLE>
</form>
<%@ include file="include/invalidFidMsg.incl"%>
<%@ include file="include/footer.incl" %>
<%   if (success) {
int refseqid = upload.getRefSeqId();
int  ftypeid =  annotation.getFtypeId();
int rid =  annotation.getRid();
boolean validParams = false;
if (refseqid >0 && ftypeid >0 && rid >0 && gname != null)
validParams = true;
if (validParams)
GenboreeUtils.processGroupContextForGroup(""+refseqid,  gname,  "" + ftypeid,  "" + rid, false);
CacheManager.clearCache(db, upload.getDatabaseName());
}
%>
</BODY>
</HTML>
