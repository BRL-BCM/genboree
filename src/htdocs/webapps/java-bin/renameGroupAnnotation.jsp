<%@ page import="java.text.NumberFormat, java.text.DecimalFormat, java.io.InputStream, java.util.*,
    java.util.regex.Pattern,java.util.regex.Matcher,
    java.lang.reflect.Array,java.sql.*,
    org.genboree.util.*,
    org.genboree.editor.AnnotationEditorHelper,
    org.genboree.message.GenboreeMessage"
%>
<%@ page import="javax.servlet.http.*, org.genboree.upload.HttpPostInputStream " %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<HTML>
<HEAD>
<TITLE>Genboree - Annotation Group Editor</TITLE>
<LINK rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<LINK rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">
<LINK rel="stylesheet" href="/styles/annotationEditor.css<%=jsVersion%>" type="text/css">
 <link rel="stylesheet" href="/styles/avp.css<%=jsVersion%>" type="text/css">
<LINK rel="stylesheet" href="/styles/querytool.css<%=jsVersion%>" type="text/css">
<script type="text/javascript" src="/javaScripts/util.js<%=jsVersion%>"></script>
<script src="/javaScripts/commonFunctions.js<%=jsVersion%>" type="text/javascript"></script>
<script src="/javaScripts/attributeValuePairs.js<%=jsVersion%>"  defer="true" type="text/javascript"></script>
<SCRIPT TYPE="text/javascript" SRC="/javaScripts/dupanno.js<%=jsVersion%>"></SCRIPT>
<!--SCRIPT TYPE="text/javascript" SRC="/javaScripts/groupAnnotationEditor.js<%=jsVersion%>"></SCRIPT-->
<SCRIPT TYPE="text/javascript" SRC="/javaScripts/editorCommon.js<%=jsVersion%>"></SCRIPT>
<SCRIPT TYPE="text/javascript" SRC="/javaScripts/delimitGrpComments.js<%=jsVersion%>"></SCRIPT>
<SCRIPT TYPE="text/javascript" SRC="/javaScripts/prototype.js<%=jsVersion%>"></SCRIPT>
<META HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</HEAD>
<BODY>
<%@ include file="include/fidInfo.incl" %>
<%@ include file="include/pageInit.incl" %>
<%    AnnotationDetail [] lastPageAnnotations  = null;
String groupNewName = "";
String okState ="okState";
String state = "0";
String changed ="0";
String initVal ="";
String  validate =   " return validateAnnotationName();" ;
Vector vlog = new Vector();
response.addDateHeader( "Expires", 0L );
response.addHeader( "Cache-Control", "no-cache, no-store" );
String pageName = "renameGroupAnnotation.jsp";
String checkBoxName = "checkBoxName" ;
GenboreeMessage.clearMessage(mys);
boolean refreshGbrowser = false;
AnnotationDetail annotation = null;
AnnotationDetail[] annotations = null;
AnnotationDetail[] totalAnnotations = null;
String formId = "editorForm";
String aid = "newGroupName";
String aval = "";

int numSelected = 0;
int [] fidi  = new int [0];
String selectAll = "selectAll(0)";
String [] fids = null;
String actionName = "  Rename Selected   ";

String confirmSelected = " return confirmSelected(0,0,false)"; ;
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
ArrayList mlist = null;
String orderNum = "1";
HashMap fid2AnnoNums = new HashMap ();
HashMap fid2Annos = new HashMap ();
int numRemain = 0;
ArrayList selectedFids = new ArrayList();
boolean updateAll = false;
String message = "";
String warnMsg = "";
String className ="";
int ftypeid = 0;
boolean displayOK = true;
if (mys.getAttribute("duplicateGroupMsg") != null) {
message = (String)mys.getAttribute("duplicateGroupMsg") ;
mys.removeAttribute("duplicateGroupMsg");
}

int i = 0;
HashMap errorFields = new HashMap();

int rid = 0;
int db2jsp = 0;
Connection con = db.getConnection(dbName);
if (con == null || con.isClosed()) {
return;
}
%>
<%@ include file="include/largeGroup.incl" %>
<%
if (request.getParameter("upfid") != null) {
if (proceedLargeGroup || totalNumAnno <Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN) {
totalAnnotations =   AnnotationEditorHelper.findGroupAnnotations(dbName,  ifid,  response,  mys,  out, con);
if (totalAnnotations != null && totalAnnotations.length >0  ){
className = totalAnnotations[0].getGname();
initVal = className;
mys.setAttribute("initVal", initVal);
ftypeid = totalAnnotations[0].getFtypeId();
rid =   totalAnnotations[0].getRid();
mys.setAttribute("ren_className", className);
mys.setAttribute("ren_ftypeid", ""+ftypeid);
mys.setAttribute("ren_rid", ""+rid);
mys.setAttribute("ren_newgname",groupNewName);
for (i=0; i<totalAnnotations.length; i++) {

int tempInt = i+1;
fid2AnnoNums.put("" + totalAnnotations[i].getFid(), "" + tempInt);
fid2Annos.put("" + totalAnnotations[i].getFid(), totalAnnotations[i]);
totalAnnotations[i] = AnnotationEditorHelper.convertAnnotation(totalAnnotations[i], db2jsp);
}
mys.setAttribute("fid2AnnoNums", fid2AnnoNums);
mys.setAttribute("fid2Annotation", fid2Annos);
mys.setAttribute("totalAnnotations", totalAnnotations);
}
mys.setAttribute("groupNewName", "" );
}
}
else {
groupNewName = (String )mys.getAttribute("ren_newgname");
className = (String)mys.getAttribute("ren_className");
String id = (String) mys.getAttribute("ren_ftypeid");
if (id != null)
ftypeid = Integer.parseInt(id);
String ridString = (String) mys.getAttribute("ren_rid");
rid = Integer.parseInt(ridString);
totalAnnotations = (AnnotationDetail [] )mys.getAttribute("totalAnnotations");
fid2Annos =  (HashMap )mys.getAttribute("fid2Annotation");

fid2AnnoNums =  (HashMap )mys.getAttribute("fid2AnnoNums");
}
HashMap errorField = new HashMap();
int numAnnotations = 0;
if (proceedLargeGroup || totalNumAnno <Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN) {
if (totalAnnotations == null || totalAnnotations.length==0) {
String upfid1 = (String)mys.getAttribute("lastTextID") ;
GenboreeUtils.sendRedirect(request, response, "/java-bin/annotationEditorMenu.jsp?upfid="+ upfid1) ;
return;
}
String  lastPageIndex ="";
if (mys.getAttribute("lastPageIndex")!= null)
lastPageIndex =  (String)mys.getAttribute("lastPageIndex");
if ( totalAnnotations == null)
totalAnnotations = new AnnotationDetail[0];
%>
<%@ include file="include/cancelHandler.incl" %>
<%@ include file="include/multipage.incl" %>
<%@ include file="include/doSelect.incl" %>
<%
boolean doUpdate = false;
if (lastPageIndex != null ) {
if (lastPageIndex.compareTo("" + currentPageIndex)!=0)
doUpdate = true;

if (!initPage)
doUpdate = true;
}
if (doUpdate) {
if (lastPageIndex != null && page2Annotations.get(lastPageIndex)!= null)
lastPageAnnotations  =  (AnnotationDetail[]) page2Annotations.get(lastPageIndex);
fids = request.getParameterValues(checkBoxName);
if (fids == null && initPage) {

if (lastPageAnnotations != null)
for (int j=0; j<lastPageAnnotations.length; j++) {
if (groupSelectedFidList.contains("" + lastPageAnnotations[j].getFid()))
groupSelectedFidList.remove("" + lastPageAnnotations[j].getFid());
}
}
else  if (fids != null) {
ArrayList tempList = new ArrayList();
for (int j=0; j<fids.length; j++)
tempList.add(fids[j]);
if(lastPageAnnotations != null) {
for (int j=0; j<lastPageAnnotations.length; j++) {
if (tempList.contains("" + lastPageAnnotations[j].getFid())){
if (!groupSelectedFidList.contains("" +lastPageAnnotations[j].getFid()))
groupSelectedFidList.add("" + lastPageAnnotations[j].getFid());
}
}
}
if (lastPageIndex != null && page2Annotations.get(lastPageIndex)!= null)
lastPageAnnotations  =  (AnnotationDetail[]) page2Annotations.get(lastPageIndex);

if (lastPageAnnotations != null)
for (int j=0; j<lastPageAnnotations.length; j++) {

if (!tempList.contains("" + lastPageAnnotations[j].getFid()))
groupSelectedFidList.remove("" + lastPageAnnotations[j].getFid());
}
}
mys.setAttribute("selectedFidList", groupSelectedFidList);
}
if ((groupNewName = request.getParameter("newGroupName")) != null)  {
mys.setAttribute("groupNewName", groupNewName);
}
else {
groupNewName = (String)mys.getAttribute("groupNewName");
}
if (groupNewName == null)
groupNewName = "";
confirmSelected = "confirmSel()" ;

if ( annotations == null)
annotations = new AnnotationDetail[0];
%>
<%  if (request.getParameter(doSelected) != null) {
String status = request.getParameter(okState);
if (status != null && status.compareTo("1")==0) {

groupNewName = request.getParameter("newGroupName");
if ( groupNewName != null)
groupNewName =  groupNewName.trim();
if (AnnotationEditorHelper.validateGname( groupNewName, request,   vlog,  out)) {
numSelected = groupSelectedFidList.size();
fidi  = new int [numSelected];
int count = 0;
if ( numSelected>0)  {
for (int j=0; j<totalAnnotations.length; j++)  {
if (groupSelectedFidList.contains("" + totalAnnotations[j].getFid())){
fidi[count]= totalAnnotations[j].getFid();
totalAnnotations[j].setFlagged(true);
groupSelectedFidList.remove("" + totalAnnotations[j].getFid());
count++;
}
}
if (AnnotationEditorHelper.updateAnnotationsName( groupNewName,  fidi, db, upload, out, con)){
errorField.remove("gname");
message="";
mys.setAttribute("ren_newgname",  groupNewName);
vlog = new Vector();
totalAnnotations = AnnotationEditorHelper.findGroupAnnotations(dbName, className, ftypeid, rid, response, mys, out, con) ;
mys.setAttribute("totalAnnotations", totalAnnotations);

numRemain = 0;
if (totalAnnotations != null)
for (i=0; i<totalAnnotations.length; i++)
if (!totalAnnotations[i].isFlagged())
numRemain ++;
if (numRemain <0)
numRemain = 0;
String  annoRemain = numRemain>1? "  annotations remain in \"" + className +   "\"  group" : "  annotation remains in \"" + className +   "\"  group." ;
String  annoRename =  (fidi.length >1)? "  annotations have been renamed as \"" +  groupNewName + "\"" :  "  annotation has been renamed as \"" +  groupNewName + "\"" ;

mlist = new ArrayList();
mlist.add( fidi.length + annoRename);
mlist.add(numRemain  + annoRemain );
GenboreeMessage.setSuccessMsg(mys, "The operation was successful", mlist);
int refseqid = upload.getRefSeqId();
boolean validParams = false;
GenboreeUtils.processGroupContextForGroup(""+refseqid,  groupNewName,  "" + ftypeid,  "" + rid, false);
GenboreeUtils.processGroupContextForGroup(""+refseqid,  className,  "" + ftypeid,  "" + rid, false);
CacheManager.clearCache(db, upload.getDatabaseName());
refreshGbrowser = true;
doPaging = true;

%>
<%@ include file="include/multipage.incl" %>
<%
}
}
else {
mys.setAttribute("selectedAnnos", null);
vlog.add ("Please select an annotation.");
}
}
else {
vlog.add ("The new group name is invalid.  Please enter a new group name.");
errorField.put("gname", "true");
}
}
else{
mys.setAttribute("selectedAnnos", null);
}
}
confirmSelected = " return confirmSelectedChanges(0)"; ;
int pageSelected = 0;
if (annotations != null && annotations.length > 0 ) {
for (i=0; i<annotations.length; i++)  {
if (groupSelectedFidList.contains("" + annotations[i].getFid()) && !annotations[i].isFlagged())
pageSelected ++;
}

int newSelected = groupSelectedFidList.size() -  pageSelected;
if (newSelected <0)
newSelected = 0 ;             selectAll = "selectAll(" + annotations.length+  ")";
unSelectAll = "unSelectAll(" + annotations.length+  ")";
confirmSelected = " return confirmRenameSelected(" + newSelected + ", " + totalAnnotations.length  + ", " + updateAll +   ")";
}
aval =   groupNewName;
if (initVal == null || initVal.compareTo("") ==0) {
initVal = (String)mys.getAttribute("initVal");
}
if (initVal ==null)
initVal = "";
if ( !initPage && aval.compareTo(initVal)!=0) {
changed = "1";
}
}
%>
<%@ include file="include/saved.incl" %>
<%@ include file="include/validateFid.incl" %>
<%if (proceedLargeGroup || totalNumAnno <Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN) {  %>
<%@ include file="include/header.incl" %>
<%}%>
<%@ include file="include/redir.incl" %>
<form name="<%=formId%>" id="<%=formId%>" action="<%=redir%>" method="post" onSubmit="<%=validate%>" >
<input type="hidden" name="<%=okState%>" id="<%=okState%>"  value="<%=state%>" >
<input type="hidden" name='selectAllAnnos' id='selectAllAnnos' value="false" >
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
<center><FONT SIZE="4"><B>  Rename Annotations
<br>From&nbsp;Group&nbsp; &quot;<%=className%>&quot;</B></FONT>
</center>
<TD>
</TR>
<tr>
<td>
<%@ include file="include/message.incl" %>
<font color="red" size="4">
<div id="rgmessage1"  class="compact2" >
</div>
<br>
<div id="rgmessage" align="center">
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
</td>
</tr>
<%  if (annotations != null && annotations.length >0){ %>
<%@ include file="include/mp_pageIndex.incl" %>
<TR align="center"><TD>
<TABLE cellpadding="1" cellspacing="1" border="1">
<tr id="rgnewTrackRow1" align="center">
<td name="newGrpNameLabel" id="newGrpNameLabel" class="annotation2" ><b>New&nbsp;Annotation&nbsp;Group&nbsp;Name:&nbsp;</b></td>
<td  colspan="2" class="annotation2">&nbsp;
<input id="newGroupName" type="text" name="newGroupName"  class="txt" style="width:192"   value="<%=groupNewName%>"  onChange="setChanged(1);" onKeyPress="return event.keyCode!=13;">
</td>
</tr>

</TABLE>
</TD>
</TR>
<%}%>
<%
if (annotations != null && annotations.length >0){
%>
<TR align="center" >
<TD> <BR>
<%@ include file="include/buttonSet.incl" %>
</TD>
</TR>
<%
}
else {
%>
<TR align="center" >
<TD> <BR>
<TABLE>
<TR>
<TD >
<NOBR>
<input  type="button" name="btnClose" id="btnClose" value="Close Window"  class="btn"  onClick="window.close();" >
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
int tempint = i+1;
orderNum = "" + tempint;
if (annotation == null || annotation.isFlagged())
continue;
else {
if (  fid2AnnoNums.get ("" + annotation.getFid()) != null)
{
orderNum =  (String )fid2AnnoNums.get ("" + annotation.getFid()) ;
}
}
String checkBoxId = "checkBox_" + i ;
String checked = "";
if (groupSelectedFidList.contains(""+ annotation.getFid()))
checked = "checked" ;
String commentsid = "comments_"+i;
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
<% if (i!=0) { %>
<tr><td>&nbsp;</td></tr>
<% } %>
<TR>
<td>
<table width="100%"  border="1" cellpadding="2" cellspacing="1">
<TR>
<TD class="annotation2" colspan="4">
<input type="checkbox"   name="<%=checkBoxName%>" id="<%=checkBoxId%>" <%=checked%> value=<%=annotation.getFid()%> >
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
<TEXTAREA  name="comments" id="<%=commentsid%>"  READONLY align="left" rows="4" class="largeTextareaRO" value="<%=annotation.getComments()%>"><%=annotation.getComments()%></TEXTAREA>
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
} %>
<%  if (annotations != null && annotations.length >0){
%>
<TR align="center" >
<td>
<br>
<%@ include file="include/buttonSet.incl" %>
</td>
<br>
</TR>
<%@ include file="include/multipageEditorBottom.incl" %>
<%}%>
</td>
</TR>
</table>
</form>
<%}%>
<%@ include file="include/invalidFidMsg.incl"%>
<% if (proceedLargeGroup || totalNumAnno<org.genboree.util.Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN) {%>
<%@ include file="include/footer.incl" %>
<%}%>
</BODY>
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
</HTML>
