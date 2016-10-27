<%@ page import="java.text.NumberFormat, java.text.DecimalFormat, java.io.InputStream, java.util.*,
    java.util.regex.Pattern,java.util.regex.Matcher,
    java.lang.reflect.Array,java.sql.*,
                 org.genboree.util.*,
                 org.genboree.editor.AnnotationEditorHelper,
                 org.genboree.editor.Chromosome"
%>
<%@ page import="javax.servlet.http.*, org.genboree.upload.HttpPostInputStream " %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%@ include file="include/fidInfo.incl" %>
<%@ include file="include/pageInit.incl" %>
<%  AnnotationDetail [] lastPageAnnotations  = null;
    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );
    boolean refreshGbrowser = false;
    String  initVal = "0";
    String changed="0";
    GenboreeMessage.clearMessage(mys);

    String pageName = "annotationGroupShift.jsp";
    AnnotationDetail annotation = null;
    AnnotationDetail[] annotations = null;
    AnnotationDetail[] totalAnnotations = null;
    boolean updateAll = false;
    String aid = "distance";
    String aval = "";
    ArrayList selectedAnnos = new ArrayList();
    String message = "" ;
    String validate = "";
    String checkBoxName = "checkBoxName" ;
    GenboreeMessage.clearMessage(mys);
    Chromosome chromosome = null;
    long chromosomeLength = 0;
    String  direction = request.getParameter ("direction");
    String formId = "editorForm";
    int numSelected = 0;
    int [] fidi  = new int [0];
    String selectAll = "selectAll(0)";
    String [] fids = null;
    String actionName = "    Shift   Selected    ";
    String confirmSelected = " return confirmShiftSelected(0,0,false, \"3' direction\")";
    String unSelectAll = "unSelectAll(0)";
    String doSelected ="doSelected";
    ArrayList groupSelectedFidList = new ArrayList();
    if (request.getParameter("upfid") != null){
        mys.removeAttribute("selectedFidList");
    }
    else {
        if (mys.getAttribute("selectedFidList") != null)
        groupSelectedFidList =   (ArrayList)mys.getAttribute("selectedFidList");
    }
    ArrayList pageSelectedFidList = new ArrayList();
    AnnotationDetail [] selectedAnnotations = null;
    Vector vlog = new Vector();
    String errorPage = "/java-bin/error.jsp";
    int dirChoice = 0;
    long dist = 0;
    String orderNum = "1";
    HashMap fid2AnnoNums = new HashMap ();
    HashMap fid2Annos = new HashMap ();
    boolean success = false;
    String distance = "0";
    long minStart = 2147483647;
    long maxStop = 0;
    int i = 0;
    HashMap errorFields = new HashMap();
    Connection con =  db.getConnection(dbName);
    if (con == null || con.isClosed())
      GenboreeUtils.sendRedirect(request, response, destback);
    int db2jsp = 0;
    String className =  "";
    int  classFtypeId = 0;
    int classRid = 0;
       %>
 <%@ include file="include/largeGroup.incl" %>
<%
    if (request.getParameter("upfid")!= null) {
    if (proceedLargeGroup || totalNumAnno <1000) {
    totalAnnotations = AnnotationEditorHelper.findGroupAnnotations(dbName,  ifid,  response,  mys,  out, con);
    mys.setAttribute("totalAnnotations", totalAnnotations);
    if (totalAnnotations != null && totalAnnotations.length >0){
    annotation = totalAnnotations[0];
    className = annotation.getGname();
    classFtypeId = annotation.getFtypeId();
    classRid = annotation.getRid();
    }
    mys.removeAttribute("selectedList");
    mys.setAttribute("className", className);
    mys.setAttribute("classFtypeId", "" + classFtypeId);
    mys.setAttribute("classRid", "" + classRid);
    mys.setAttribute("distance", "0");
    mys.setAttribute("initval", "0");
    mys.setAttribute("changed", "no");
    mys.setAttribute("direction", "3");
    }
    }
    else {
        totalAnnotations = (AnnotationDetail [])mys.getAttribute("totalAnnotations");
        if (mys.getAttribute("className")!= null)
        className =  (String) mys.getAttribute("className");
         if (mys.getAttribute("classFtypeId") != null)
        classFtypeId = Integer.parseInt((String )mys.getAttribute("classFtypeId"));
        if (mys.getAttribute("classRid") != null)
        classRid =Integer.parseInt( (String)mys.getAttribute("classRid"));
        if (mys.getAttribute("selectedList") != null)
            groupSelectedFidList = (ArrayList )mys.getAttribute("selectedList");
    }
    if (proceedLargeGroup || totalNumAnno <Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN) {
    if (totalAnnotations == null || totalAnnotations.length ==0){
        return;
    }
    else  {   int tempInt =0;
      annotation = totalAnnotations[0];
        for (int n=0; n<totalAnnotations.length ; n++) {
                if (totalAnnotations[n].getStart() < minStart) {
                    minStart = totalAnnotations[n].getStart();
                }
                if (totalAnnotations[n].getStop() > maxStop) {
                     maxStop = totalAnnotations[n].getStop();
                }
            tempInt = n+1;
                fid2AnnoNums.put("" + totalAnnotations[n].getFid(), "" + tempInt);
                fid2Annos.put("" + totalAnnotations[n].getFid(), totalAnnotations[n]);
        }
    }
    HashMap chromosomeMap = AnnotationEditorHelper.findChromosomes (db, con);
    if (JSPErrorHandler.checkErrors(request, response, db, mys))
        return;
    String chr = null;
    if (annotation != null)
        chr = annotation.getChromosome();
    if (chromosomeMap != null && chromosomeMap.size() > 0) {
        if (chromosomeMap.get(chr) != null)
            chromosome = (Chromosome)chromosomeMap.get(annotation.getChromosome());
        else {
            mys.setAttribute("lastError", "chromosome  is not defined in annotationGroupShift.jsp");
           return;
        }
    }
    if (chromosomeMap==null || chromosome == null || (chromosome != null && chromosome.getLength() ==0)) {
        mys.setAttribute("lastError", "chromosome length is not defined in annotationShift.jsp");
        GenboreeUtils.sendRedirect(request, response, destback);
    }
     chromosomeLength = chromosome.getLength();
     direction = request.getParameter ("direction");
    if (direction==null)
     direction = (String)mys.getAttribute("direction");
    else
      mys.setAttribute("direction", direction);
    if (direction== null)
      direction = "3";
    distance = request.getParameter("distance");
    if (distance == null)
       distance = (String)mys.getAttribute("distance");
    else
      mys.setAttribute("distance", distance);
    if (distance == null)
    distance = "0";
    String  lastPageIndex ="";
    if (mys.getAttribute("lastPageIndex")!= null)
    lastPageIndex =  (String)mys.getAttribute("lastPageIndex");
  %>
<%@ include file="include/multipage.incl"%>
<%@ include file="include/doSelect.incl"%>
<%@ include file="include/fidUpdate.incl"%>
   <%
    if (request.getParameter(doSelected) != null) {
        String status = request.getParameter("okState");
         if (status != null && status.compareTo("1")==0) {
            distance = request.getParameter("distance");
            direction = request.getParameter("direction");
            numSelected =groupSelectedFidList.size();
            selectedAnnotations = new AnnotationDetail[numSelected];
            int count = 0;
        if (numSelected>0)  {
            for (i=0; i<totalAnnotations.length; i++) {
               if (groupSelectedFidList.contains("" + totalAnnotations[i].getFid())) {
                selectedAnnotations[count] = totalAnnotations[i];
                count++;
               }
            }
         }
        mys.setAttribute("selectedAnnos",groupSelectedFidList);
        ArrayList successFids =null;
        if (selectedAnnotations != null && AnnotationEditorHelper.validateShiftAnnotations (distance, direction, selectedAnnotations, chromosomeLength, errorFields, vlog, out )) {
                dist = Long.parseLong(distance);
                dirChoice = Integer.parseInt(direction);
                successFids  =  AnnotationEditorHelper.shiftGroupAnnotations(dist, dirChoice, db,  selectedAnnotations, dbName, out, con);
                totalAnnotations =   AnnotationEditorHelper.findGroupAnnotations(dbName,  ifid,  response,  mys,  out, con);
                mys.setAttribute("totalAnnotations", totalAnnotations);
                //groupSelectedFidList = new ArrayList();
               mys.setAttribute("selectedAnnos",groupSelectedFidList);

         if (successFids != null && successFids.size() == selectedAnnotations.length){
            success = true;
            refreshGbrowser = true;
            CacheManager.clearCache(db, upload.getDatabaseName()) ;
           }
          String annoSuffix =selectedAnnotations.length > 1?  " annotations were shifted " : " annotation was shifted  ";
          ArrayList msglist = new ArrayList();
          msglist.add( groupSelectedFidList.size() + annoSuffix  + distance + " bp toward " + direction + "' end.");

        if (success) {
            GenboreeMessage.setSuccessMsg(mys, "The operation was successful", msglist);
            vlog = new Vector();
        }
        else {
            mys.setAttribute("selectedAnnos", null);
            vlog.add ("Please select an annotation.");
        }
        doPaging = true;
       %>
  <%@ include file="include/multipage.incl" %>
    <%
         }
        }
    }
    int pageSelected = 0;
    annotations = (AnnotationDetail[])page2Annotations.get(currentPage);
     validate =  "return validateGroupAnnos(" + chromosome.getLength() + ", " + minStart + ", " + maxStop + ");" ;
    if (annotations != null && annotations.length>0) {
        selectAll = "selectAll(" + annotations.length+  ")";
        unSelectAll = "unSelectAll(" + annotations.length+  ")";
            for (i=0; i<annotations.length; i++)  {
            if (groupSelectedFidList.contains("" + annotations[i].getFid()) && !annotations[i].isFlagged())
            pageSelected ++;
            }
             int newSelected = groupSelectedFidList.size() -  pageSelected;
             if (newSelected <0)
              newSelected = 0 ;
        confirmSelected =  " return confirmShiftSelected(" + newSelected + ", " + totalAnnotations.length + ", " + updateAll + ", '" + direction  +  "')";
    }
    aval = distance;
    if (initVal == null || initVal.compareTo("") ==0) {
    initVal = (String)mys.getAttribute("initVal");
    }
    if (initVal == null)
    initVal = "";
    if ( !initPage && aval.compareTo(initVal)!=0) {
    changed = "1";
    mys.setAttribute("changed", "yes");
    }
    changed = (String)mys.getAttribute("changed") ;
    if (changed != null && changed.compareTo("yes") == 0)  {
    changed = "1";
    }
    else if(changed != null && changed.compareTo("no") == 0)
    {
        changed = "0";
    }
}
%>
<%@ include file="include/cancelHandler.incl" %>
<%@ include file="include/saved.incl" %>
<HTML>
<HEAD>
<TITLE>Genboree - Annotation Group Editor</TITLE>
<LINK rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<LINK rel="stylesheet" href="/styles/annotationEditor.css<%=jsVersion%>" type="text/css">
<LINK rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">
<SCRIPT TYPE="text/javascript" SRC="/javaScripts/prototype.js<%=jsVersion%>"></SCRIPT>
<script src="/javaScripts/util.js<%=jsVersion%>" type="text/javascript"></script>
<script src="/javaScripts/scriptaculous.js<%=jsVersion%>" type="text/javascript"></script>
<SCRIPT TYPE="text/javascript" SRC="/javaScripts/shiftAnnotation.js<%=jsVersion%>"></SCRIPT>
<SCRIPT TYPE="text/javascript" SRC="/javaScripts/delimitGrpComments.js<%=jsVersion%>"></SCRIPT>
<SCRIPT TYPE="text/javascript" SRC="/javaScripts/editorCommon.js<%=jsVersion%>"></SCRIPT>
<link rel="stylesheet" href="/styles/avp.css<%=jsVersion%>" type="text/css">
<link rel="stylesheet" href="/styles/querytool.css<%=jsVersion%>" type="text/css">
<script src="/javaScripts/commonFunctions.js<%=jsVersion%>" type="text/javascript"></script>
<script src="/javaScripts/attributeValuePairs.js<%=jsVersion%>"  defer="true" type="text/javascript"></script>
<META HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</HEAD>
<BODY >
 <% if (proceedLargeGroup || totalNumAnno <Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN) {%>
<%@ include file="include/header.incl" %>
 <%}%>
<%@ include file="include/validateFid.incl" %>
<%@ include file="include/redir.incl" %>
<form name="<%=formId%>" id="<%=formId%>" action="<%=redir%>" method="post" onSubmit="<%=validate%>" >
    <input type="hidden" name="okState" id="okState" value="0" >
    <input type="hidden" name="selectAllAnnos" id="selectAllAnnos" value="false" >
    <input type="hidden" name="currentPage" id="currentPage" value="<%=currentPage%>">
    <input type="hidden" name="navigator" id="navigator" value="home">
    <input type="hidden" name="cancelState" id="cancelState" value="0">
    <input type="hidden" name="doSelected" id="doSelected" value="">
    <input type="hidden" name="changed" id="changed" value="<%=changed%>">
 <%@ include file="include/largeGrpConfirm.incl" %>
 <%if (proceedLargeGroup || totalNumAnno <Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN) {  %>
    <TABLE width="100%" border="0" cellpadding="2" cellspacing="2">
    <TR align="center">
    <TD  class="form_body">
    <center><FONT SIZE="4"><B>Shift Annotations
    <br>From&nbsp;Group&nbsp;&quot;<%=className%>&quot;</B></FONT> </center>
    </TD>
    </TR>
    <% if (annotations != null && annotations.length >0 ){
    if( vlog != null && vlog.size() > 0 )
    message = "";
    String checked3 = "no";
    String checked5 = "no";
    dirChoice = Integer.parseInt(direction);
    if (direction != null && dirChoice==3) {
    checked3 = "checked";
    checked5 = "";
    }
    else if (direction != null && dirChoice ==5) {
    checked3 = "";
    checked5 = "checked";
    }
    else {
    checked3 = "checked";
    checked5 = "";
    }
    if (distance==null || distance.compareTo("")==0)
    distance= "0";
    %>
    <%@ include file="include/mp_pageIndex.incl" %>
<TR align="center" >
<TD>
<TABLE>
<TR><TD>
<div id="msg" class="successMsg" align="center">
<%=message%>
</div>
<%@ include file="include/message.incl" %>
<font color="red">
<div id="messageid" align="left">
</div>
</font>
</TD></TR>
</TABLE>
<div align="center">
<TABLE  border="1" cellpadding="2" cellspacing="1" width="560pt">
<TR> <nobr>
<% if (errorFields.get("distance") == null) { %>
<TD name="distanceLabel" id="distanceLabel"  class="annotation2"  width="60pt" align="right">
<B>&nbsp;Distance&nbsp;(bp):</B>
</TD>
<%} else {%>
<TD name="distanceLabel" id="distanceLabel"  class="annotation1"  width="60pt" align="right">
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
<NOBR>
<input  name="direction" id="direction5" type="radio"  value="5"   <%=checked5%>>
<B>5'&nbsp;</B>
<input  name="direction" id="direction3" type="radio"  value="3"  <%=checked3%>>
<B>3'&nbsp;</B>
(Relative&nbsp;to&nbsp;<B>&nbsp;POSITIVE&nbsp;</B>&nbsp;strand)  </NOBR>
</TD>
</nobr>
</TR>
</TABLE>
</div>
</TD>
</TR>

<TR align="center">
<TD>
<%@ include file="include/delimit.incl"  %>
</TD>
</TR>

<TR><TD></TD></TR>
<TR align="center"><TD>
<%@ include file="include/buttonSet.incl" %>
</TD></TR>
<%  }  %>
<%
if (annotations != null ) {
for (i=0; i<annotations.length; i++) {
annotation = annotations[i];
int tempint = i+1;
orderNum = "" + tempint;
if (  fid2AnnoNums.get ("" + annotation.getFid()) != null)
{
orderNum =  (String )fid2AnnoNums.get ("" + annotation.getFid()) ;
}
String checkBoxId = "checkBox_" + i ;
String checked = "";
if (groupSelectedFidList.contains(""+ annotation.getFid()))
checked = " checked" ;
// if (selectedList.isEmpty())
//      checked = "checked" ;
annotation = AnnotationEditorHelper.convertAnnotation(annotation, db2jsp);
String testWarn = "test warn";
String commentsid = "comments_" + i;
String duplicateId = "duplicate_" + i;
String gnameid = "gname_" + i;
HashMap      name2Values = new HashMap ();
fid = "" + annotation.getFid();
int currentIndex = 0;
%>

<%@ include file="include/avpPopulator.incl" %>
<input type="hidden" name="avpvalues_<%=i%>" id="avpvalues_<%=i%>" value="">
<input type="hidden" name="index_<%=i%>" id="index_<%=i%>" value="<%=currentIndex%>">

<input type="hidden" name="<%=duplicateId%>" id="<%=duplicateId%>" value="0">
<%if(i!=0) {%>
<tr><td>&nbsp;</td></tr>
<%}%>
<TR>
<td>
<table width="100%"  border="1" cellpadding="2" cellspacing="1">
<TR>
<TD class="annotation2" colspan="4">
<input type="checkbox"  name="<%=checkBoxName%>" id="<%=checkBoxId%>" <%=checked%> value=<%=annotation.getFid()%>>
&nbsp; &nbsp;  &nbsp; &nbsp;&nbsp; &nbsp;  &nbsp; &nbsp;   &nbsp; &nbsp;  &nbsp; &nbsp; &nbsp; &nbsp;&nbsp; &nbsp;    &nbsp; &nbsp;  &nbsp; &nbsp;          &nbsp; &nbsp;  &nbsp; &nbsp;    &nbsp; &nbsp;  &nbsp; &nbsp;    &nbsp; &nbsp;  &nbsp; &nbsp;
<B><FONT SIZE="2">
&quot;<%=annotations[i].getGname()%>&quot;&nbsp;<%="("%>Annotation&nbsp;<%=orderNum%><%=")"%>
</font></B>
</TD>
</TR>
<TR>
<TD class="annotation2" colspan="1">
<B>Annotation&nbsp;Name</B>
</TD>
<TD class="annotation2" colspan="3">
<input type="text"  READONLY  name="<%=gnameid%>" id = "<%=gnameid%>" class="largeInputRO"  maxlength="200" value="<%=Util.htmlQuote(annotation.getGname()) %>" >
</TD>
</TR>
<TR>
<TD ALIGN="left" class="annotation2" colspan="1">
<B>Track<B>
</TD>
<TD class="annotation2" colspan="1">
<input type="text" id="annotrackName" READONLY class="longInputRO" maxlength="20"  value="<%=annotation.getTrackName()%>">
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
<TD ALIGN="left" class="annotation2" colspan="1"><B>Start<B></TD>
<TD class="annotation2" colspan="1">
<input type="text" READONLY class="longInputRO"  maxlength="50" value= "<%=annotation.getFstart()%>" >
</TD>
<TD ALIGN="left" class="annotation2" colspan="1"> <B>Stop<B></TD>
<TD class="annotation2" BGCOLOR="white" colspan="1">
<input READONLY type="text" class="longInputRO"  maxlength="50"  value="<%=annotation.getFstop()%>" >
</TD>
</TR>
<TR>
<TD ALIGN="left" class="annotation2" colspan="1"><B>Query&nbsp;Start</B></div></TD>
<TD class="annotation2" colspan="1">
<input  type="text" READONLY BGCOLOR="white" class="longInputRO" maxlength="50" value="<%=annotation.getTstart()%>" >
</TD>
<TD ALIGN="left" class="annotation2" colspan="1"><B>Query&nbsp;Stop</B></TD>
<TD class="annotation2" colspan="1">
<input type="text"  READONLY BGCOLOR="white" class="longInputRO" maxlength="50" value="<%=annotation.getTstop()%>">
</TD>
</TR>
<TR>
<TD ALIGN="left" class="annotation2" colspan="1"><strand><B>Strand</B></TD>
<TD class="annotation2" colspan="1">
<input READONLY type="text" class="longInputRO" name="strand" id="strand" BGCOLOR="white" maxlength="50" value="<%=annotation.getStrand()%>">
</TD>
<TD ALIGN="left" class="annotation2" colspan="1"><B>Phase</B></TD>
<TD ALIGN="left" class="annotation2" colspan="1">
<input READONLY type="text" class="longInputRO" name="phase" id="phase" BGCOLOR="white" maxlength="50" value="<%=annotation.getPhase()%>">
</TD>
</TR>
<TR>
<TD ALIGN="left" class="annotation2" colspan="1"><B>Score</B></TD>
<TD ALIGN="left" class="annotation2" colspan="1">
<input READONLY type="text" class="longInputRO"  BGCOLOR="white" maxlength="50" value="<%=annotation.getFscore()%>">
</TD>
<TD ALIGN="left" class="annotation2" colspan="2">&nbsp;</TD>
</TR>

<%@ include file="include/singleAnnoAVPDisplay4cols.incl" %>

<TR>
<TD ALIGN="left" colspan="1" class="annotation2"><B>Comment</B></TD>
<TD align="left" class="annotation2" colspan="3">
<TEXTAREA  name="comments"  id="<%=commentsid%>" READONLY align="left" rows="4" class="largeTextareaRO" value="<%=annotation.getComments()%>"><%=annotation.getComments()%></TEXTAREA>
</TD>
</TR>
<TR>
<TD ALIGN="left" colspan="1" class="annotation2"><B>Sequence</B></TD>
<TD align="left" class="annotation2" colspan="3">
<TEXTAREA  READONLY align="left" rows="4" class="largeTextareaRO"  value="<%=annotation.getSequences()%>"><%=annotation.getSequences()%></TEXTAREA>
</TD>
</TR>
</TABLE>
</TD>
</TR>
<TR align="center" >
<td>
<%}
}
%>
<%
if (annotations != null && annotations.length >0   )
{
%>
<TR align="center" >
<td>
<br>
<%@ include file="include/buttonSet.incl" %>
<br>
</td>
</TR>
<%@ include file="include/multipageEditorBottom.incl" %>
<%}%>
</td>
</TR>
</table>
<%}%>
</form>
<%@ include file="include/invalidFidMsg.incl"%>

<% if (proceedLargeGroup || totalNumAnno <Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN) {%>
<%@ include file="include/footer.incl" %>
<%}%>
<%
  if(refreshGbrowser)
  {
    refreshGbrowser = false;
%>
    <script>
      confirmRefresh() ;
    </script>
<%
  }
%>
</BODY>
</HTML>
