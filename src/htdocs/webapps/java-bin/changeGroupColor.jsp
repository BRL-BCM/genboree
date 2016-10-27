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
    <link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">
    <LINK rel="stylesheet" href="/styles/annotationEditor.css<%=jsVersion%>" type="text/css">
    <SCRIPT TYPE="text/javascript" SRC="/javaScripts/grpcolor.js<%=jsVersion%>"></SCRIPT>
    <SCRIPT TYPE="text/javascript" SRC="/javaScripts/editorCommon.js<%=jsVersion%>"></SCRIPT>
    <SCRIPT TYPE="text/javascript" SRC="/javaScripts/prototype.js<%=jsVersion%>"></SCRIPT>
    <link rel="stylesheet" href="/styles/avp.css<%=jsVersion%>" type="text/css">
    <link rel="stylesheet" href="/styles/querytool.css<%=jsVersion%>" type="text/css">
    <script type="text/javascript" src="/javaScripts/util.js<%=jsVersion%>"></script>
    <script src="/javaScripts/commonFunctions.js<%=jsVersion%>" type="text/javascript"></script>
    <script src="/javaScripts/attributeValuePairs.js<%=jsVersion%>"  defer="true" type="text/javascript"></script>
    <SCRIPT TYPE="text/javascript" SRC="/javaScripts/delimitGrpComments.js<%=jsVersion%>"></SCRIPT>
    <%@ include file="include/colorWheelFiles.incl" %>
    <META HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
    </HEAD>
    <BODY>
<%@ include file="include/fidInfo.incl" %>
<%@ include file="include/cancelHandler.incl" %>
<%@ include file="include/pageInit.incl" %>
<%

    String  state = "0";
    String aid ="hiddenInputId";
    String aval = "";
    String changed="0";
    String initColorS= "#";
    AnnotationDetail [] lastPageAnnotations  = null;
    boolean isInitGrpColor = true;
    String initGrpColor = "";
    GenboreeMessage.clearMessage(mys);
    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );
    boolean refreshGbrowser = false;
    GenboreeMessage.clearMessage(mys);
    String pageName = "changeGroupColor.jsp";
    String orderNum = "0";
    HashMap errorField = new HashMap();
    Vector vlog = new Vector();
    HashMap fid2AnnoNums = new HashMap ();
    boolean confirmOK = false;
    boolean done = false;
    boolean success = false;
    AnnotationDetail annotation = null;
    AnnotationDetail[] annotations = null;
    AnnotationDetail[] totalAnnotations = null;
    HashMap fid2OrderNum = new HashMap();
    boolean updateAll = false;
    HashMap fid2Annos = new HashMap();
    String checkBoxName = "checkBoxName" ;
    GenboreeMessage.clearMessage(mys);
    String formId = "editorForm";
    int numSelected = 0;
    int [] fidi  = new int [0];
    String selectAll = "selectAll(0)";
    String [] fids = null;
    String actionName = "   Change  Color   ";
    String okState ="okState";
    String confirmSelected = "";
    String unSelectAll = "unSelectAll(0)";
    String doSelected ="doSelected";
    ArrayList groupSelectedFidList = new ArrayList();
    String groupColor = "";
    if (request.getParameter("upfid") != null){
    mys.removeAttribute("selectedFidList");
    mys.setAttribute("groupColor", "");
    }
    else {
        if (mys.getAttribute("selectedFidList") != null)
        groupSelectedFidList =   (ArrayList)mys.getAttribute("selectedFidList");
    }
    ArrayList pageSelectedFidList = new ArrayList();
    AnnotationDetail [] selectedAnnotations = null;

    String className ="";
    int ftypeid = 0;
    int i = 0;
    HashMap errorFields = new HashMap();
    String gname = request.getParameter("newGroupName");
    if (request.getParameter("upfid") == null)
    gname = (String )mys.getAttribute("ren_newgname");

    if (gname == null)
    gname="";
    int rid = 0;
    int db2jsp = 0;
    Connection con = db.getConnection(dbName);

    // JSPErrorHandler.checkErrors(response, db, mys);
    if (con == null || con.isClosed()) {
        GenboreeUtils.sendRedirect(request, response, "/java-bin/error.jsp");
        return;
    }
     %>
 <%@ include file="include/largeGroup.incl" %>
<%
    if (request.getParameter("upfid") != null) {
      if (proceedLargeGroup || totalNumAnno <Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN) {
        totalAnnotations =   AnnotationEditorHelper.findGroupAnnotations(dbName,  ifid,  response,  mys,  out, con);
        if (totalAnnotations != null && totalAnnotations.length >0 ){
       className =totalAnnotations[0].getGname();
        ftypeid =totalAnnotations[0].getFtypeId();
        rid =  totalAnnotations[0].getRid();
        mys.setAttribute("ren_className", className);
        mys.setAttribute("ren_ftypeid", ""+ftypeid);
        mys.setAttribute("ren_rid", ""+rid);
        mys.setAttribute("ren_newgname", gname);
        groupSelectedFidList = new ArrayList();
          for (i=0; i<totalAnnotations.length; i++) {
                int tempInt = i+1;
                fid2AnnoNums.put("" + totalAnnotations[i].getFid(), "" + tempInt);
                fid2Annos.put("" + totalAnnotations[i].getFid(), totalAnnotations[i]);
                totalAnnotations[i] = AnnotationEditorHelper.convertAnnotation(totalAnnotations[i], db2jsp);
            }
              mys.setAttribute("fid2AnnoNums", fid2AnnoNums);
              mys.setAttribute("fid2Annotation", fid2Annos);
        }
      }
    }
    else {
        className = (String)mys.getAttribute("ren_className");
        String id = (String) mys.getAttribute("ren_ftypeid");
        if (id != null)
        ftypeid = Integer.parseInt(id);
        String ridString = (String) mys.getAttribute("ren_rid");
        rid = Integer.parseInt(ridString);
         fid2AnnoNums =  (HashMap )mys.getAttribute("fid2AnnoNums");
        if (className != null && ftypeid >0)
        totalAnnotations =   AnnotationEditorHelper.findGroupAnnotations(dbName, className, ftypeid, rid, response, mys, out, con);
    }
    String  lastPageIndex ="";
    if (mys.getAttribute("lastPageIndex")!= null)
    lastPageIndex =  (String)mys.getAttribute("lastPageIndex");

if (proceedLargeGroup || totalNumAnno <Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN){
        if ( totalAnnotations == null)
            totalAnnotations = new AnnotationDetail[0];
        %>
        <%@ include  file="include/multipage.incl" %>
        <%@ include  file="include/doSelect.incl" %>
        <%@ include  file="include/fidUpdate.incl" %>
        <%
        if (annotations != null)
        annotation = annotations[0];
        %>
        <%@ include file="include/setColor.incl" %>
        <%
        if (mys.getAttribute("initColor") != null)
        initColorS = (String)mys.getAttribute("initColor");
        groupColor = request.getParameter("hiddenInputId");
        if (groupColor!= null)
        groupColor = groupColor.replaceAll("#", "");

        if (groupColor!= null && groupColor.compareTo("")!= 0) {
        mys.setAttribute("groupColor", groupColor);
        }
        else if (mys.getAttribute("groupColor")!= null) {
        groupColor = (String)mys.getAttribute("groupColor");
        }

        if (curColor == "" && (mys.getAttribute("grpColor") != null))
        curColor = (String)mys.getAttribute("grpColor");

        if (groupColor == null || groupColor.compareTo("")==0)  {
        groupColor = curColor;
        initGrpColor = groupColor;
        mys.setAttribute("initGroupColor", groupColor);
        }
        mys.setAttribute("groupColor", groupColor);
        if (initGrpColor == null || initGrpColor.compareTo("") ==0)
        initGrpColor = (String)mys.getAttribute("initGroupColor");
        if (initGrpColor.compareToIgnoreCase (groupColor) != 0)
        isInitGrpColor = false;

        String annoColor=curColor;
        if (request.getParameter(doSelected) != null) {
        state = request.getParameter("okState");

        if (state != null && state.compareTo("1")==0) {
        annoColor = request.getParameter("hiddenInputId");
        if (annoColor == null)
        annoColor="" ;
        if ( annoColor != null )
        annoColor = annoColor.trim();
        //  anno.setHexAnnoColor(annoColor);

        if (annoColor != null && annoColor.compareTo("#") != 0) {
        String temp = annoColor.replaceAll("#", "") ;

        if (temp.length()>0 && temp!="")
        intColor = Integer.parseInt(temp, 16);
        //      anno.setDisplayColor(intHColor);
        }
        curColor = annotation.getHexAnnoColor();
        mys.setAttribute("grpColor", curColor);
        numSelected = groupSelectedFidList.size();

        if (numSelected >0) {
        numSelected = groupSelectedFidList.size();
        fidi = new int [numSelected];
        int count = 0;
        for (i=0; i<totalAnnotations.length; i++) {
        if (groupSelectedFidList.contains("" + totalAnnotations[i].getFid())) {
        fidi[count] = totalAnnotations[i].getFid();
        count ++;
        }
        }

        if (AnnotationEditorHelper.updateAnnotationsColor(intColor, fidi, db, upload, out, con))
        {
        mys.removeAttribute("newGroupName");
        // groupSelectedFidList = new ArrayList();
        mys.setAttribute("selectedFidList", groupSelectedFidList);
        vlog = new Vector();
        totalAnnotations =  AnnotationEditorHelper.findGroupAnnotations(dbName, className, ftypeid, rid, response, mys, out, con);
        doPaging = true;
        %>
        <%@ include  file="include/multipage.incl" %>
        <%
        if (totalAnnotations != null && totalAnnotations.length>0)
        annotation = annotations[0];
        if (fidi.length >0) {
        ArrayList list1 = new ArrayList();
        String be = fidi.length  > 1? "  annotations were changed." :"  annotation was changed.";
        list1.add("Colors of "+ fidi.length + be);
        GenboreeMessage.setSuccessMsg(mys, "The color change  was successful",  list1);
        }

        int refseqid = upload.getRefSeqId();
        boolean validParams = false;
        CacheManager.clearCache(db, upload.getDatabaseName());
        refreshGbrowser = true;
        success = true;
        }
        }
        else {
        GenboreeMessage.setErrMsg (mys, "Please select some annotations.");
        }}
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

        selectAll = "selectAll(" + annotations.length+  ")";
        unSelectAll = "unSelectAll(" + annotations.length+  ", '" + curColor + "')";
        confirmSelected = " return confirmSelectedChanges("+ newSelected + ", " + totalAnnotations.length + ", " + updateAll +  ", 'change display color')";
        }

        //upfid = (String)mys.getAttribute("lastTextID") ;
        if (initColorS==null)
        initColorS="000000";

        if (curColor== null)
        curColor = "000000";
        if ( initColorS != null && curColor!= null && curColor.compareTo(initColorS)!=0) {
            changed = "1";
        }
        if (groupColor == null)
        groupColor ="000000";
        aval =annoColor;
        if (aval==null)
        aval="000000";
}
    %>
    <%  if (proceedLargeGroup || totalNumAnno <Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN) {  %>
    <%@ include file="include/header.incl" %>
    <%}%>
    <%@ include file="include/validateFid.incl" %>
    <%@ include file="include/saved.incl" %>
    <%@ include file="include/redir.incl" %>
    <form name="<%=formId%>" id="<%=formId%>" action="<%=redir%>" method="post"  >
    <input type="hidden" name="<%=okState%>" id="<%=okState%>" value="state" >
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
    <center><FONT SIZE="4"><B>  Change Group Color
    <br>For&nbsp;Group&nbsp; &quot;<%=className%>&quot;</B></FONT>
    </center>
    <br>
    <div>
    <TD></TR>
    <TR> <TD>
    </TD>
    </TR>
    <%@ include file="include/mp_pageIndex.incl"  %>
    <%
if (annotations != null && annotations.length >0){%>
    <TR align="center">
    <TD>
    <TABLE cellpadding="0" cellspacing="0" border="1">
    <tr id="rgnewTrackRow1" align="center">
    <td name="newGrpNameLabel" id="newGrpNameLabel" class="annotation2" colspan="4">
    <a href="javascript:void null;"  id="wheellink" class="annotation2">
    <div name="AllimageId" id="AllimageId"  class="colorIconLong2"  style="background-color:<%=groupColor%>"  onClick="setSelectedDivId('AllimageId','hiddenInputId', '<%=groupColor%>', '<%=annotations.length%>');">
    </div>
    <div  id="AllId" class="bottomdiv" onClick="setSelectedDivId('AllimageId', 'hiddenInputId', '<%=groupColor%>',  '<%=annotations.length%>');">&nbsp;&nbsp;Set Color for Selected Annotations</div>
    </a>
    <input  type="hidden" name="hiddenInputId" id="hiddenInputId" value="#<%=groupColor%>"  >
    </td>
    </tr>

    </TABLE>
    </TD>
    </TR>
    <% }
    else {
    %>
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
    <%  } %>
<tr>
<td >
<%@ include file="include/message.incl" %>
</td>
</tr>
<TR align="center" >
    <TD>
    <%@ include file="include/buttonSet.incl"%>
    </TD>
</TR>
<%
if (annotations != null ) {
    for (i=0; i<annotations.length; i++) {
        annotation = annotations[i];
        HashMap name2Values = new HashMap ();
        String checkBoxId = "checkBox_" + i ;
        String checked = "";
        if (groupSelectedFidList.contains(""+ annotation.getFid()))
        checked = "checked" ;
        int tempint = i+1;
        orderNum = "" + tempint;
        if (  fid2AnnoNums.get ("" + annotation.getFid()) != null){
            orderNum =  (String )fid2AnnoNums.get ("" + annotation.getFid()) ;
        }
        String colorImageId ="colorImageId"+i;
        String hiddenInputId ="hiddenInputId"+i;
        String commentsid = "comments_"+i;
        String duplicateId = "duplicate_"+i;
        String gnameid = "gname_" + i;
         int currentIndex = 0;
        fid = "" + annotation.getFid();
    %>

        <%@ include file="include/avpPopulator.incl" %>
        <input type="hidden" name="avpvalues_<%=i%>" id="avpvalues_<%=i%>" value="">
        <input type="hidden" name="index_<%=i%>" id="index_<%=i%>" value="<%=currentIndex%>">

        <input type="hidden" name="<%=duplicateId%>" id="<%=duplicateId%>" value="0">
        <% if (i!=0){ %>
        <tr><td>&nbsp;</td></tr>
       <% } %>
       <%@include file="include/setColor.incl" %>
    <TR>
    <td>
    <table width="100%"  border="1" cellpadding="2" cellspacing="1">
    <TR>
    <TD class="annotation2" colspan="4">
    <input type="checkbox"  name="<%=checkBoxName%>" id="<%=checkBoxId%>" <%=checked%> value=<%=annotation.getFid()%> onClick="setDefaultColor('<%=checkBoxId%>', '<%=curColor%>', 'hiddenInputId', '<%=colorImageId%>', '<%=hiddenInputId%>');" >
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
   <TD ALIGN="center" class="annotation2" colspan="2">
    <%
    if (groupSelectedFidList.contains(""+ annotation.getFid()) && !isInitGrpColor)
        curColor = groupColor;
    %>
   <div name="<%=colorImageId%>" id="<%=colorImageId%>"  class="colorIconLong"  style="background-color:<%=curColor%>"   >
   </div>
   <div class="bottomdivLong" >&nbsp;&nbsp; Annotation Color</div>
   <input type="hidden" name="<%=hiddenInputId%>" id="<%=hiddenInputId%>" value="<%=curColor%>" >
</TD>
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
     <%@ include file="include/buttonSet.incl"%>
    <%  if (annotations != null && annotations.length >0  )
    {
    %>
    <TR align="center" >
    <td>
    <br>
     <%@ include file="include/multipageEditorBottom.incl" %>
    </td>
    </TR>
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
    </div>
    </BODY>
<%
  if(refreshGbrowser)
  {
    refreshGbrowser = false;
%>
    <script language="javascript" type="text/javascript">
      confirmRefresh() ;
<%
      done = true ;
%>
      onBlur=self.focus();
   </script>
<%
  }
%>
    </HTML>
