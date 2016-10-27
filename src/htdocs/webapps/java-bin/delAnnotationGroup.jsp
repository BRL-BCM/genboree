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
<%@ include file="include/fidInfo.incl" %>
<%@ include file="include/pageInit.incl" %>
<%@ include file="include/cancelHandler.incl" %>
<%  AnnotationDetail [] lastPageAnnotations  = null;
    String state="0";
    String changed ="0";
    String initVal ="";
    String aid ="";
    String aval = "";
    String validate = "";

    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );
    String formId = "editorForm";
    String pageName = "delAnnotationGroup.jsp";
    String selectAll = "selectAll(0)";
    String [] fids = null;
    String actionName = "   Delete  Selected   ";
       String checkBoxName = "checkBoxName";
    String confirmSelected = " return confirmSelected(0,0,false)"; ;
    String unSelectAll = "unSelectAll(0)";
    String doSelected ="doSelected";
    ArrayList groupSelectedFidList = new ArrayList();
    if (request.getParameter("upfid") != null){
    mys.removeAttribute("selectedFidList");
        mys.removeAttribute("initVal");
    }
    else {
    if (mys.getAttribute("selectedFidList") != null)
    groupSelectedFidList =   (ArrayList)mys.getAttribute("selectedFidList");
    }
    ArrayList pageSelectedFidList = new ArrayList();
    AnnotationDetail [] selectedAnnotations = null;
    int numDeleted = 0;
    String orderNum = "1";
    HashMap fid2AnnoNums = new HashMap ();
    HashMap fid2Annos = new HashMap ();
    boolean updateAll = false;
    GenboreeMessage.clearMessage(mys);
    boolean refreshGbrowser = false;
    AnnotationDetail annotation = null;
    AnnotationDetail[] totalAnnotations = null;
    AnnotationDetail[] annotations = null;
    int numSelected = 0;
    String rid = "0";
    int ridInt = 0;
    String message = "";
    int i = 0;
    boolean success = false;
    int db2jsp = 0;
    String className =  "";
    String ftypeid = "0";
    int ftypeidInt =0;
    String trackName = "";
    Connection con = db.getConnection(dbName) ;
   %>
 <%@ include file="include/largeGroup.incl" %>
<%
    if (request.getParameter("upfid") == null ) {
        className = (String)mys.getAttribute("gclassName");
        trackName =  (String)mys.getAttribute("trackName");
        ftypeid = (String)mys.getAttribute("ftypeid");
        rid = (String)mys.getAttribute("rid");
         ridInt = Integer.parseInt(rid);
        initVal =  (String)mys.getAttribute("initval");
        if (ftypeid != null)  {
            ftypeidInt = Integer.parseInt(ftypeid);
         }
     totalAnnotations =  (AnnotationDetail[])mys.getAttribute("totalAnnotations");
     fid2AnnoNums = (HashMap )mys.getAttribute("fid2AnnoNums");
    }
    else {
         if (proceedLargeGroup || totalNumAnno <Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN) {
        totalAnnotations =   AnnotationEditorHelper.findGroupAnnotations(dbName, ifid, response, mys, out, con);
        if ( totalAnnotations != null &&  totalAnnotations.length >0) {
            className = totalAnnotations[0].getGname();
            rid= ""+ totalAnnotations[0].getRid();
            ridInt = totalAnnotations[0].getRid();
            ftypeid = "" + totalAnnotations[0].getFtypeId() ;
            ftypeidInt = totalAnnotations[0].getFtypeId();
            mys.setAttribute("gclassName",  totalAnnotations[0].getGname());
            mys.setAttribute("totalAnnotations",  totalAnnotations);
            mys.setAttribute("trackName",  totalAnnotations[0].getTrackName());
            mys.setAttribute("ftypeid", "" +  totalAnnotations[0].getFtypeId());
            mys.setAttribute("rid", "" +  totalAnnotations[0].getRid());
              mys.setAttribute("initval", "" + totalAnnotations.length);
            mys.setAttribute("changed", "no");
            int tempint = 0;
             mys.setAttribute("totalNumAnnotations", "" + totalAnnotations.length);
            for (i=0; i<totalAnnotations.length; i++) {
             tempint = i+1;
              fid2AnnoNums.put("" + totalAnnotations[i].getFid(), "" + tempint);
            }
            mys.setAttribute("fid2AnnoNums", fid2AnnoNums);
        }
        }
    }
   if (proceedLargeGroup || totalNumAnno <Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN) {
  if (totalAnnotations == null || totalAnnotations.length==0) {
        String upfid1 = (String)mys.getAttribute("lastTextID") ;
       GenboreeUtils.sendRedirect(request, response, "/java-bin/annotationEditorMenu.jsp?upfid="+ upfid1) ;
      return;
  }
    String lastPageIndex ="";
    if (mys.getAttribute("lastPageIndex")!= null)
    lastPageIndex =  (String)mys.getAttribute("lastPageIndex");
   %>
   <%@ include file="include/multipage.incl"%>
   <%@ include file="include/doSelect.incl" %>
   <%@ include file="include/fidUpdate.incl" %>
 <%
       if (request.getParameter(doSelected) != null) {
        String status = request.getParameter("okState");
        if (status != null && status.compareTo("1")==0) {
              //  mys.setAttribute("selectedFidList", groupSelectedFidList);
                numSelected = groupSelectedFidList.size();
               int [] fidi   = new int [numSelected];
                 String id = "0";
              ArrayList delList = new ArrayList ();
                 for (i=0; i<groupSelectedFidList.size(); i++) {
                   id = (String)groupSelectedFidList.get(i);
                   fidi[i] = Integer.parseInt(id);
                   delList.add(id);
                 }
             if (fidi.length >0) {
               AnnotationEditorHelper.deleteAllAnnotation(fidi, con);

             GenboreeUtils.deleteValuePairs(con, "" + upload.getRefSeqId(), delList);
             }
                for (int j=0; j<annotations.length; j++) {
                    if (groupSelectedFidList.contains("" + annotations[j].getFid()))
                    {
                        annotations[j].setFlagged(true);
                    }
                }

              for (int k=0; k<totalAnnotations.length; k++) {
                 if (groupSelectedFidList.contains("" + totalAnnotations[k].getFid())) {
                     totalAnnotations[k].setFlagged(true);
                    groupSelectedFidList.remove("" + totalAnnotations[k].getFid());
                 }
            }
           int numRemain = 0;
                for (int k=0; k<totalAnnotations.length; k++) {
                   if (!totalAnnotations[k].isFlagged())
                   numRemain ++;
                }
                 if (numRemain <0)
                numRemain =0;
                String annoSel =numSelected <2 ?  " annotation has ":" annotations have ";
                String annoRem =numRemain <2 ?  " more annotation ":" more annotations ";
                ArrayList mlist = new ArrayList();
                mlist.add(   "The " + numSelected + annoSel +" been deleted successfully from group \"" + className + "\"" );
                mlist.add( numRemain + annoRem +" remain in group.<BR><BR> ");
                GenboreeMessage.setSuccessMsg(mys, "The operation was successful.", mlist);
               doPaging = true;
                groupSelectedFidList = new ArrayList();
              mys.setAttribute("selectedFidList", groupSelectedFidList);
    %>
    <%@ include file="include/multipage.incl" %>
    <%
      if (annotations != null)
        annotation = annotations[0];
        int refseqid = upload.getRefSeqId();
        GenboreeUtils.processGroupContextForGroup(""+ refseqid,  className,   ftypeid,  "" + rid, false);
        CacheManager.clearCache(db, upload.getDatabaseName()) ;
        refreshGbrowser = true;
            }
        }
    if (annotations != null && annotations.length >0) {
        for(i=0; i<annotations.length; i++) {
            if (request.getParameter("btnDelete_" + i) != null) {
              String   status = request.getParameter("okDelete_"+i);
                if (status != null && status.compareTo("1")==0) {
                    AnnotationEditorHelper.deleteAnnotation(annotations[i].getFid(), db, upload.getDatabaseName(), out, con);
                    ArrayList delfid = new ArrayList();
            delfid.add("" + annotations[i].getFid());
             GenboreeUtils.deleteValuePairs(con, "" + upload.getRefSeqId(), delfid);
                      groupSelectedFidList.remove("" + annotations[i].getFid());
                   mys.setAttribute("selectedFidList", groupSelectedFidList);
                   annotations [i].setFlagged(true);
                    int numRemain = 0;
                   for (int k=0; k<totalAnnotations.length; k++)
                   if (totalAnnotations[k]!= null && !totalAnnotations[k].isFlagged())
                        numRemain  ++;
                    if (numRemain <0)
                    numRemain =0;
                    String annoSel = " annotation has ";
                    String annoRem =numRemain <2 ?  " more annotation remains in group ":" more annotations remain in group ";
                    ArrayList mlist = new ArrayList();
                    mlist.add("The 1 "  + annoSel +" been deleted successfully from group \"" + className +
                    "\"" );
                    mlist.add(numRemain + annoRem );
                 GenboreeMessage.setSuccessMsg(mys, "The operation was successful.", mlist);
       int count=0;
       for (int m=0; m<annotations.length; m++)
       if (annotations[m].isFlagged())
       count++;
        if (count ==annotations.length) {
        for (int m=currentPageIndex; m<numPages; m++) {
        page2Annotations.remove("" + m);
        int tempint = m+1;
        AnnotationDetail [] tempArr = (AnnotationDetail[])page2Annotations.get("" + tempint);
        page2Annotations.put("" +m, tempArr);

        }
        currentPageIndex--;

        if (currentPageIndex <0)
        currentPageIndex = 0;
        currentPage = "" + currentPageIndex;

        mys.setAttribute("lastPageIndex", currentPage);
        mys.setAttribute("totalNumAnnotations", "" + totalAnnotations.length);
        doPaging = true;
    %>
<%@ include file="include/multipage.incl" %>
<%
     }
    if (annotations != null)
    annotation = annotations[0];
    int refseqid = upload.getRefSeqId();
    GenboreeUtils.processGroupContextForGroup(""+ refseqid,  className,   ftypeid,  "" + rid, false);
    CacheManager.clearCache(db, upload.getDatabaseName()) ;
    refreshGbrowser = true;

    if (annotations != null && annotations.length > 0 ) {
        for (i = 0; i < annotations.length; i++) {
            annotations[i] = AnnotationEditorHelper.convertAnnotation(annotations[i], db2jsp);
        }
    }
}
      break;
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
    confirmSelected = "confirmSelectedChanges(" + newSelected  + ", " +  totalNum + ", " + updateAll + ", 'delete')" ;
    }
   unSelectAll = "unSelectAll(" + totalAnnotations.length+ ")";
   selectAll = "selectAll(" + totalAnnotations.length+ ")";
      if (initVal == null || initVal.compareTo("") ==0) {
                 initVal = (String)mys.getAttribute("initVal");
             }
            if (initVal == null || initVal =="")
              initVal ="0";
     int intVal = Integer.parseInt(initVal);
             if ( (!initPage) && (intVal != totalAnnotations.length) ) {
                 changed = "1";
                 mys.setAttribute("changed", "yes");
             }
             changed = (String)mys.getAttribute("changed") ;
             if (changed != null && changed.compareTo("yes") == 0)  {
                 changed = "1";
                 cancelState ="1";
             }
             else   if (changed != null && changed.compareTo("no") == 0)  {
             changed ="0";      }
   }
  %>
  <%@ include file="include/saved.incl" %>
<HTML>
<HEAD>
    <TITLE>Genboree - Annotation Group Editor</TITLE>
    <LINK rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
    <LINK rel="stylesheet" href="/styles/annotationEditor.css<%=jsVersion%>" type="text/css">
    <LINK rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">
    <SCRIPT TYPE="text/javascript" SRC="/javaScripts/deleteGroup.js<%=jsVersion%>"></SCRIPT>
    <SCRIPT TYPE="text/javascript" SRC="/javaScripts/prototype.js<%=jsVersion%>"></SCRIPT>
    <SCRIPT TYPE="text/javascript" SRC="/javaScripts/editorCommon.js<%=jsVersion%>"></SCRIPT>
    <SCRIPT TYPE="text/javascript" SRC="/javaScripts/delimitGrpComments.js<%=jsVersion%>"></SCRIPT>
    <SCRIPT TYPE="text/javascript" SRC="/javaScripts/delimitComments.js<%=jsVersion%>"></SCRIPT>
    <link rel="stylesheet" href="/styles/avp.css<%=jsVersion%>" type="text/css">
    <LINK rel="stylesheet" href="/styles/querytool.css<%=jsVersion%>" type="text/css">
    <script type="text/javascript" src="/javaScripts/util.js<%=jsVersion%>"></script>
    <script src="/javaScripts/commonFunctions.js<%=jsVersion%>" type="text/javascript"></script>
    <script src="/javaScripts/attributeValuePairs.js<%=jsVersion%>"  defer="true" type="text/javascript"></script>
    <META HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</HEAD>
<BODY>
 <%   if (totalNumAnno <Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN|| proceedLargeGroup) { %>
    <%@ include file="include/header.incl" %>
      <%
    }
   %>
<%@ include file="include/redir.incl" %>
<form name="<%=formId%>" id="<%=formId%>" action="<%=redir%>" method="post" onSubmit="<%=validate%>" >
<input type="hidden" name="okState" id="okState" value="<%=state%>" >
<input type="hidden" name='selectAllAnnos' id='selectAllAnnos' value="false" >
<input type="hidden" name="currentPage" id="currentPage" value="<%=currentPage%>">
<input type="hidden" name="navigator" id="navigator" value="home">
<input type="hidden" name="cancelState" id="cancelState" value="0">
<input type="hidden" name="changed" id="changed" value="<%=changed%>">
<input type="hidden" name="doSelected" id="doSelected" value="">
 <%@ include file="include/largeGrpConfirm.incl" %>
 <%if (proceedLargeGroup || totalNumAnno <Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN) {  %>
<TABLE width="100%" border="0" cellpadding="2" cellspacing="2">
<%  if (annotations != null && annotations.length>0) { %>
<TR align="center">
<TD  class="form_body">
<div align="center" class="title4">  Delete Annotations
<br>In&nbsp;Group&nbsp;"<%=className%>"
</div>
</TD>
</TR>
<%@ include file="include/mp_pageIndex.incl" %>
<%} %>
<TR>
<TD>
<%@ include file="include/message.incl" %>
</TD>
</TR>
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
<input  type="button" name="btnClose" id="btnClose" value="Close Window"  class="btn" onClick="window.close();" >
&nbsp;   &nbsp;
</NOBR>
</TD>
</TR>
</TABLE>
</TD>
</TR>
<%  }  %>
<%
    if (annotations != null && annotations.length > 0) {
    for (i = 0; i < annotations.length; i++)   {
    annotations[i] = AnnotationEditorHelper.convertAnnotation(annotations[i], db2jsp);
    }
    }
    if (annotations != null && annotations.length >0) {
    int tempint = i+1;
    orderNum = "" + tempint;
    for (i=0; i<annotations.length; i++) {
    annotation = annotations[i];
    if (annotation.isFlagged())
    continue;
    orderNum = (String )fid2AnnoNums.get("" + annotation.getFid());
    String checkBoxId = "checkBox_" + i ;
    String checked = "";
    if (groupSelectedFidList.contains("" + annotation.getFid()))
    checked =" checked";
    String delId = "okDelete_"+i;
    String gnameid = "gname_" + i;
    String commentsid ="comments_" + i ;
    HashMap      name2Values = new HashMap ();
    fid = "" + annotation.getFid();
    int currentIndex = 0;
    %>

    <%@ include file="include/avpPopulator.incl" %>
    <input type="hidden" name="avpvalues_<%=i%>" id="avpvalues_<%=i%>" value="">
    <input type="hidden" name="index_<%=i%>" id="index_<%=i%>" value="<%=currentIndex%>">

    <input type="hidden" name="<%=delId%>" id="<%=delId%>" value="0">
    <%if (i!=0) {%>
    <tr><td>&nbsp; </td></tr>
    <%}%>
<TR>
<TD>
<TABLE width="100%"  border="1" cellpadding="2" cellspacing="1">
    <TR>
        <TD class="annotation2" colspan="4">
        <input type="checkbox" name="<%=checkBoxName%>" id="<%=checkBoxId%>" <%=checked%> value="<%=annotation.getFid()%>">
        &nbsp; &nbsp;  &nbsp; &nbsp; &nbsp; &nbsp;  &nbsp; &nbsp; &nbsp; &nbsp;  &nbsp; &nbsp; &nbsp; &nbsp;  &nbsp; &nbsp;
        &nbsp; &nbsp;  &nbsp; &nbsp; &nbsp; &nbsp;  &nbsp; &nbsp; &nbsp; &nbsp;  &nbsp; &nbsp; &nbsp; &nbsp;  &nbsp; &nbsp;
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
        <input type="text"  READONLY  name="<%=gnameid%>" id="<%=gnameid%>" class="largeInputRO"  maxlength="200" value="<%=Util.htmlQuote(className) %>" >
        </TD>
    </TR>
    <TR>
        <TD ALIGN="left" class="annotation2" colspan="1">
        <B>Track<B>
        </TD>
        <TD class="annotation2" colspan="1">
        <input type="text" READONLY class="longInputRO" maxlength="20"  value="<%=annotations[0].getTrackName()%>">
        </TD>
        <TD ALIGN="left" class="annotation2" colspan="2">&nbsp;
        </TD>
    </TR>
    <TR>
        <TD ALIGN="left" class="annotation2" colspan="1"><B>Chromosome<B></TD>
        <TD class="annotation2" colspan="1">
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
        <TD ALIGN="left" class="annotation2" colspan="1"><B>Query&nbsp;Start</B></TD>
        <TD class="annotation2" colspan="1">
        <input  type="text" READONLY BGCOLOR="white" class="longInputRO" maxlength="50" value="<%=annotation.getTstart()%>" >
        </TD>
        <TD ALIGN="left" class="annotation2" colspan="1"><B>Query&nbsp;Stop</B></TD>
        <TD class="annotation2" colspan="1">
        <input type="text"  READONLY BGCOLOR="white" class="longInputRO" maxlength="50" value="<%=annotation.getTstop()%>">
        </TD>
    </TR>
     <TR>
        <TD ALIGN="left" class="annotation2" colspan="1"><B>Strand</B></TD>
        <TD class="annotation2" colspan="1">
            <input READONLY type="text" class="longInputRO" name="strand" id="strand" BGCOLOR="white" maxlength="50" value="<%=annotation.getStrand()%>">
        </TD>
        <TD ALIGN="left" class="annotation2" colspan="1"><B>Phase</B></TD>
        <TD ALIGN="left" class="annotation2" colspan="1">
            <input READONLY type="text" class="longInputRO" name="phase" id="phase" BGCOLOR="white" maxlength="50"   value="<%=annotation.getPhase()%>">
        </TD>
    </TR>
    <TR>
        <TD ALIGN="left" class="annotation2" colspan="1"><B>Score</B></TD>
        <TD ALIGN="left" class="annotation2" colspan="1">
            <input READONLY type="text" class="longInputRO"  BGCOLOR="white" maxlength="50" value="<%=annotation.getFscore()%>">
        </TD>
        <TD ALIGN="left" class="annotation2" colspan="2"></TD>
    </TR>

                      <%@ include file="include/singleAnnoAVPDisplay4cols.incl" %>

     <TR>
        <TD ALIGN="left" colspan="1" class="annotation2"><B>Free-Form Comment</B>
        </TD>
        <TD align="left"  class="annotation2" colspan="3">
            <TEXTAREA  name="comments" id="<%=commentsid%>" READONLY align="left" rows="4" class="largeTextareaRO" value="<%=annotation.getComments()%>"><%=annotation.getComments()%></TEXTAREA>
        </TD>
    </TR>
    <TR>
        <TD ALIGN="left" colspan="1" class="annotation2"><B>Sequence</B></TD>
        <TD align="left" class="annotation2" colspan="3">
            <TEXTAREA  READONLY align="left" rows="4" class="largeTextareaRO" value="<%=annotation.getSequences()%>"><%=annotation.getSequences()%></TEXTAREA>
        </TD>
    </TR>
</TABLE>
<%
String btnDeleteId = "btnDelete_" + i;
String confirmDel = "confirmDelete (" + i + ", '" +   orderNum + "')";
%>
<table align="left" width="100%" border="1"   cellpadding="2" cellspacing="1" >
    <TR align="left">
        <TD height="40" class="form_body">
        <input  type="button" class="btn" name="<%=btnDeleteId%>" id="<%=btnDeleteId%>" value=" Delete " onClick ="<%=confirmDel%>"> &nbsp; &nbsp;
        <input  type="hidden" class="btn" name="<%=btnDeleteId%>" id="<%=btnDeleteId%>" value="" >

       </TD>
    </TR>
</table>
</TD>
</TR>
<% }
} %>
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
</TD>
</TR>
</TABLE>
<%}%>
</form>
   <%   if (totalNumAnno <Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN|| proceedLargeGroup) { %>
<%@ include file="include/footer.incl" %>
<%
   }
%>
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
