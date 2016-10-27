<%@ page import="java.text.NumberFormat, java.text.DecimalFormat, java.io.InputStream, java.util.*,
java.util.regex.Pattern,java.util.regex.Matcher,
java.lang.reflect.Array,java.sql.*,
                 org.genboree.util.*,
                 org.genboree.editor.AnnotationEditorHelper,
                 org.genboree.manager.tracks.Utility"
%>
<%@ page import="javax.servlet.http.*, org.genboree.upload.HttpPostInputStream " %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%@ include file="include/fidInfo.incl" %>
<%@ include file="include/pageInit.incl" %>
<%@ include file="include/cancelHandler.incl" %>
    <%
    String  validate =  " return validateAnnotationName();";
    AnnotationDetail [] lastPageAnnotations  = null;
    String changed ="0";     Vector vlog = new Vector();
    String initVal ="";
    String formId = "editorForm";
    HashMap fid2AnnoNums = new HashMap ();
    HashMap fid2Annos = new HashMap ();
    String actionName = "Duplicate Selected";
    String selectAll = "selectAll(0)";
    String confirmSelected = " return confirmSelected(0,0,false)"; ;
    String unSelectAll = "unSelectAll(0)";
    String doSelected ="doSelected";
    String aid ="newGroupName";
    String aval = "";
    ArrayList groupSelectedFidList = new ArrayList();
    String checkBoxName = "checkBoxName";
    if (request.getParameter("upfid") != null){
    mys.removeAttribute("selectedFidList");
    mys.setAttribute("initval", "");
    mys.setAttribute("changed", "no");
    mys.removeAttribute("gname");
    }
    else {
    if (mys.getAttribute("selectedFidList") != null)
    groupSelectedFidList =   (ArrayList)mys.getAttribute("selectedFidList");
    }

    ArrayList pageSelectedFidList = new ArrayList();
    AnnotationDetail [] selectedAnnotations = null;
    String [] fids = null;
    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );
    String pageName = "duplicateGroupAnnotation.jsp";
    boolean updateAll = false;
    boolean refreshGbrowser = false;
    int state = 0;
    AnnotationDetail annotation = null;
    AnnotationDetail[] annotations = null;
    AnnotationDetail[] totalAnnotations = null;
    boolean done = false;
    boolean success = false;
    String message = "";
    if (mys.getAttribute("duplicateGroupMsg") != null) {
    message = (String)mys.getAttribute("duplicateGroupMsg") ;
    mys.removeAttribute("duplicateGroupMsg");
    }
    Connection con = db.getConnection(dbName);
    int i = 0;
    HashMap errorFields = new HashMap();
    String gname = request.getParameter("newGroupName");
    if (gname == null)
    gname = (String )mys.getAttribute("gname");
    else {
    mys.setAttribute("gname", gname);
    }
    if (gname == null)
    gname="";

    int db2jsp = 0;
    String className =  "";
    %>
 <%@ include file="include/largeGroup.incl" %>
<%
     if (proceedLargeGroup || totalNumAnno <Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN ){
       totalAnnotations =   AnnotationEditorHelper.findGroupAnnotations(dbName,  ifid,  response,  mys,  out, con);
      if (totalAnnotations != null) {
          annotation = totalAnnotations[0];
        for (i=0; i<totalAnnotations.length; i++) {
                int tempInt = i+1;
                fid2AnnoNums.put("" + totalAnnotations[i].getFid(), "" + tempInt);
                fid2Annos.put("" + totalAnnotations[i].getFid(), totalAnnotations[i]);
            }
      }
       int ftypeid = 0;
        int rid = -1;
        if (totalAnnotations != null && totalAnnotations.length >0){
            className = totalAnnotations[0].getGname();
            ftypeid = totalAnnotations[0].getFtypeId();
            rid =   totalAnnotations[0].getRid();
        }
    String  lastPageIndex ="";
    if (mys.getAttribute("lastPageIndex")!= null)
    lastPageIndex =  (String)mys.getAttribute("lastPageIndex");

    %>

<%@ include file="include/multipage.incl" %>
<%
HashMap errorField = new HashMap();
int numduplicateed = 0;
%>
<%@ include file="include/doSelect.incl" %>
<%@ include file="include/fidUpdate.incl" %>
<%
if (request.getParameter(doSelected) != null) {
String status = request.getParameter("okdupSelected");
if (status != null && status.compareTo("1")==0) {
gname = request.getParameter("newGroupName");
if (groupSelectedFidList != null && groupSelectedFidList.size()>0)  {
selectedAnnotations  = new AnnotationDetail [groupSelectedFidList.size()];
mys.setAttribute("selectedAnnos", groupSelectedFidList);
for (int k=0; k<groupSelectedFidList.size(); k++) {
if (fid2Annos.get(groupSelectedFidList.get(k)) != null) {
selectedAnnotations[k] = (AnnotationDetail)fid2Annos.get(groupSelectedFidList.get(k));
}
}
doPaging = true;
HashMap  fid2newfids =new HashMap ();
if(selectedAnnotations!= null)
fid2newfids   =  AnnotationEditorHelper.duplicateSelectedAnnotations(gname, selectedAnnotations, dbName, con);
int newfid = 0;
if ( fid2newfids.size() >0) {
Iterator it = fid2newfids.keySet().iterator();
if (con == null || con.isClosed())
con = db.getConnection(dbName);
while (it.hasNext()) {
String key = (String)it.next();
String value = (String )fid2newfids.get(key);
int oldfid = Integer.parseInt(key);
newfid = Integer.parseInt(value);
boolean b =  AnnotationEditorHelper.duplicateAVP (oldfid, newfid,  con) ;
}
}
if ( fid2newfids.size() >0) {
errorField.remove("gname");
message="";
mys.removeAttribute("newGroupName");
vlog = new Vector();
textid  = uploadId +  ":" +  fid2newfids.get("" + selectedAnnotations[0]);
mys.setAttribute("lastTextID", textid);
request.setAttribute("upfid", textid);
String confirmMessage =
"Successfully duplicated "  + selectedAnnotations.length + " annotations,&nbsp;" +
" using the new group name \"" + gname + "\". "
+  "<br><br>Would you like to edit these new annotations?" ;
int refseqid = upload.getRefSeqId();
GenboreeUtils.processGroupContextForGroup(""+refseqid,  gname,  "" + ftypeid,  "" + rid, false);
CacheManager.clearCache(db, upload.getDatabaseName());
String editPage = "/java-bin/annotationGroupEditor.jsp?upfid=" +  uploadId + ":" + newfid ;
String upfid = (String)mys.getAttribute("lastTextID") ;
mys.setAttribute("menuPage",   "/java-bin/annotationEditorMenu.jsp?upfid="+ upfid) ;
mys.setAttribute( "displayMsg", confirmMessage );
mys.setAttribute( "displayTgt", editPage);
refreshGbrowser = true;
success = true;
mys.removeAttribute("selectedFidList");
mys.removeAttribute("visitedPage");
GenboreeUtils.sendRedirect(request,response, "/java-bin/confirm.jsp");
}
}
else {
mys.setAttribute("selectedAnnos", null);
groupSelectedFidList = new ArrayList();
vlog.add ("You must select an annotation.");
}
}
}
int pageSelected = 0;
if (annotations != null && annotations.length > 0 ) {
for (i=0; i<annotations.length; i++)  {
if (groupSelectedFidList.contains("" + annotations[i].getFid()) && !annotations[i].isFlagged())
pageSelected ++;
}
int newSelected = groupSelectedFidList.size() -  pageSelected;
if (newSelected <0)
newSelected = 0 ;
int totalNum = 0;
for (i=0; i<totalAnnotations.length; i++)  {
if (totalAnnotations[i]!= null && !totalAnnotations[i].isFlagged())
totalNum ++;
}
selectAll = "selectAll(" + annotations.length+  ")";
unSelectAll = "unSelectAll(" + annotations.length+  ")";
confirmSelected = " return confirmDupSelected("+  newSelected+  ", " + totalAnnotations.length + ", " + updateAll +  ")";
}
aval =gname;
if (initVal == null || initVal.compareTo("") ==0) {
initVal = (String)mys.getAttribute("initVal");
}
if (initVal == null)
initVal ="";
if ( !initPage && aval.compareTo(initVal)!=0) {
changed = "1";
mys.setAttribute("changed", "yes");
}
changed = (String)mys.getAttribute("changed") ;
if (changed != null && changed.compareTo("yes") == 0)  {
changed = "1";
}
else   if (changed != null && changed.compareTo("no") == 0)  {
changed ="0";
}
}
%>
<HTML>
<HEAD>
<TITLE>Genboree - Annotation Group Editor</TITLE>
    <LINK rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
    <LINK rel="stylesheet" href="/styles/annotationEditor.css<%=jsVersion%>" type="text/css">
    <SCRIPT TYPE="text/javascript" SRC="/javaScripts/dupanno.js<%=jsVersion%>"></SCRIPT>
    <SCRIPT TYPE="text/javascript" SRC="/javaScripts/groupAnnotationEditor.js<%=jsVersion%>"></SCRIPT>
    <SCRIPT TYPE="text/javascript" SRC="/javaScripts/delimitGrpComments.js<%=jsVersion%>"></SCRIPT>
    <SCRIPT TYPE="text/javascript" SRC="/javaScripts/prototype.js<%=jsVersion%>"></SCRIPT>
    <SCRIPT TYPE="text/javascript" SRC="/javaScripts/editorCommon.js<%=jsVersion%>"></SCRIPT>
    <link rel="stylesheet" href="/styles/avp.css<%=jsVersion%>" type="text/css">
<LINK rel="stylesheet" href="/styles/querytool.css<%=jsVersion%>" type="text/css">
<script type="text/javascript" src="/javaScripts/util.js<%=jsVersion%>"></script>
<script src="/javaScripts/commonFunctions.js<%=jsVersion%>" type="text/javascript"></script>
<script src="/javaScripts/attributeValuePairs.js<%=jsVersion%>"  defer="true" type="text/javascript"></script>
<META HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</HEAD>
<BODY>
<%if (proceedLargeGroup || totalNumAnno <Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN) {  %>
<%@ include file="include/header.incl" %>
<%}%>
<%@ include file="include/validateFid.incl" %>
<%@ include file="include/saved.incl" %>
<%@ include file="include/redir.incl" %>
<form name="<%=formId%>" id="<%=formId%>" action="<%=redir%>" method="post" onSubmit="<%=validate%>" >
    <input type="hidden" name="okdupSelected" id="okdupSelected" value="<%=state%>" >
    <input type="hidden" name="selectAllAnnos" id="selectAllAnnos" value="false" >
    <input type="hidden" name="currentPage" id="currentPage" value="<%=currentPageIndex%>" >
    <input type="hidden" name="navigator" id="navigator" value="home">
    <input type="hidden" name="cancelState" id="cancelState" value="0">
    <input type="hidden" name="changed" id="changed" value="<%=changed%>">
    <input type="hidden" name="doSelected" id="doSelected" value="">
<%@ include file="include/largeGrpConfirm.incl" %>
<%if (proceedLargeGroup || totalNumAnno <Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN) {  %>
    <TABLE width="100%" border="0" cellpadding="2" cellspacing="2">
    <TR align="center">
    <TD  class="form_body">
    <center><FONT SIZE="4"><B>  Duplicate Annotations
    <br>From&nbsp;Group&nbsp; &quot;<%=className%>&quot;</B></FONT>
    </center>
    <br>
    <TD></TR>
       <%@ include file="include/mp_pageIndex.incl" %>
    <TR> <TD>
    <center><FONT SIZE="2" color="black">  <nobr>
    [To make a copy of this annotation in a different track,<BR>
    use <a href="/java-bin/reassignGroupAnnotation.jsp?upfid=<%=textid%>"><B>Group Reassign</B></a> and select the <I>copy</i> checkbox.]</FONT>
    <nobr>
    </center>
    </TD>
    </TR>
<%
if (annotations != null && annotations.length >0){
%>
<TR align="center" >
    <TD>     <div id="msg"  align="center" class="successMsg" >
    <%=message%>
    </div>
    <font color="red">
    <div id="rgmessage1"  class="compact2" >
    </div>
    <div id="rgmessage" align="left">
    <%
    if( vlog != null && vlog.size() > 0 ) {
    out.print( " <UL class=\"compact2\">" );
    for( i=0; i<vlog.size(); i++ ) {
    out.print( "<li> &middot; " + (String)vlog.elementAt(i) +"</li>" );  }
    out.println( "</ul>" );
    }
    %>
    </div>
    </font>
    <BR>
    <TABLE cellpadding="1" cellspacing="1" border="1">
    <tr id="rgnewTrackRow1">
    <td name="newGrpNameLabel" id="newGrpNameLabel" class="annotation2" ><b>New&nbsp;Annotation&nbsp;Group&nbsp;Name:&nbsp;</b></td>
    <td  colspan="2" class="annotation2">&nbsp;
    <input id="newGroupName" type="text" name="newGroupName"  class="txt" style="width:192"  value="<%=gname%>"   onChange="setChanged(1);" onKeyPress="return event.keyCode!=13;"></td>
    </tr>

    </TABLE>
    </TD>
    </TR>
    <% }  %>
    <% if (annotations != null && annotations.length >0){ %>
    <TR align="center"><TD> <BR>
    <%@ include file="include/buttonSet.incl" %>
    </TD></TR>
    <% } else { %>
    <TR align="center" >
    <TD> <BR>
    <TABLE>
    <TR>
    <TD >
    <NOBR>
    <input  type="button" name="btnClose" id="btnClose" value="Cancel"  class="btn15"  onClick="window.close();" >
    &nbsp;   &nbsp;
    </NOBR>
    </TD>
    </TR>
    </TABLE>
    </TD>
    </TR>
    <%  }  %>
<%
if (annotations != null ) {
    for (i=0; i<annotations.length; i++) {
        annotation = annotations[i];
         annotation = AnnotationEditorHelper.convertAnnotation(annotation, 0);
        String checkBoxId = "checkBox_" + i ;
        String checked = "";
        int tempint = i+1;
        String orderNum = "" + tempint;
        if (  fid2AnnoNums.get ("" + annotation.getFid()) != null)
        orderNum =  (String )fid2AnnoNums.get ("" + annotation.getFid()) ;
        if (groupSelectedFidList.contains(""+ annotation.getFid()))
        checked = "checked" ;
        String commentsid = "comments_" + i;
        String duplicateId = "duplicate_"+i;
        String gnameid = "gname_" + i;
        HashMap      name2Values = new HashMap ();
        fid = "" + annotation.getFid();
        int currentIndex = 0;
    %>

    <%@ include file="include/avpPopulator.incl" %>
    <input type="hidden" name="avpvalues_<%=i%>" id="avpvalues_<%=i%>" value="">
    <input type="hidden" name="index_<%=i%>" id="index_<%=i%>" value="<%=currentIndex%>">

    <input type="hidden" name="<%=duplicateId%>" id="<%=duplicateId%>" value="0">
    <%if (i!=0) {%>
    <tr><td>&nbsp;</td></tr>
    <% } %>
    <TR>
    <td>
    <TABLE width="100%"  border="1" cellpadding="2" cellspacing="1">
    <TR>
    <TD class="annotation2" colspan="4">
    <input type="checkbox"  name="<%= checkBoxName%>" id="<%=checkBoxId%>" <%=checked%> value=<%=annotation.getFid()%> >
    &nbsp; &nbsp;  &nbsp; &nbsp;&nbsp; &nbsp;  &nbsp; &nbsp;   &nbsp; &nbsp;  &nbsp; &nbsp;&nbsp; &nbsp;  &nbsp; &nbsp;    &nbsp; &nbsp;  &nbsp; &nbsp;          &nbsp; &nbsp;  &nbsp; &nbsp;    &nbsp; &nbsp;  &nbsp; &nbsp;    &nbsp; &nbsp;  &nbsp; &nbsp;
    <B><FONT SIZE="2">
    &quot;<%=annotations[i].getGname()%>&quot; <%="("%>Annotation <%=orderNum%><%=")"%>
    </font> </B>
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
    <TD ALIGN="left" colspan="1" class="annotation2"><B>Free-Form Comment</B></TD>
    <TD align="left" class="annotation2" colspan="3">
    <TEXTAREA  READONLY name="comments" id="<%=commentsid%>" align="left" rows="4" class="largeTextareaRO" value="<%=annotation.getComments()%>"><%=annotation.getComments()%></TEXTAREA>
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
<%}  }
mys.setAttribute("lastPageAnnos", annotations);
%>
<%  if (annotations != null && annotations.length >0  )
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
<%if (proceedLargeGroup || totalNumAnno <Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN) {  %>
<%@ include file="include/footer.incl" %>
<%}%>
</BODY>
<%
  if(refreshGbrowser)
  {
    refreshGbrowser = false;
%>
    <script>
      confirmRefresh() ;
<%
      done = true ;
%>
    </script>
<%
  }
%>
</HTML>
