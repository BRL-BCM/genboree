
<%@ page import="java.text.NumberFormat, java.text.DecimalFormat, java.io.InputStream, java.util.*,
java.util.regex.Pattern,java.util.regex.Matcher,

java.lang.reflect.Array,java.sql.*,
                 org.genboree.util.*,
                 org.genboree.editor.AnnotationEditorHelper,
                 org.genboree.message.GenboreeMessage"
%>
<%@ page import="javax.servlet.http.*, org.genboree.upload.HttpPostInputStream " %>
<%@ page import="org.genboree.editor.AnnotationDetail" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<HTML>
<HEAD>
<TITLE>Genboree - Annotation Group Editor</TITLE>
<LINK rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<LINK rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">
<SCRIPT TYPE="text/javascript" SRC="/javaScripts/prototype.js<%=jsVersion%>"></SCRIPT>
<LINK rel="stylesheet" href="/styles/annotationEditor.css<%=jsVersion%>" type="text/css">
<SCRIPT TYPE="text/javascript" SRC="/javaScripts/addGroupAVP.js<%=jsVersion%>"></SCRIPT>
<SCRIPT TYPE="text/javascript" SRC="/javaScripts/editorCommon.js<%=jsVersion%>"></SCRIPT>
<SCRIPT TYPE="text/javascript" SRC="/javaScripts/delimitAddComments.js<%=jsVersion%>"></SCRIPT>
<SCRIPT type="text/javascript" src="/javaScripts/json.js<%=jsVersion%>"></SCRIPT>
<link rel="stylesheet" href="/styles/avp.css<%=jsVersion%>" type="text/css">
<LINK rel="stylesheet" href="/styles/querytool.css<%=jsVersion%>" type="text/css">
<script type="text/javascript" src="/javaScripts/util.js<%=jsVersion%>"></script>
<script src="/javaScripts/commonFunctions.js<%=jsVersion%>" type="text/javascript"></script>
<script src="/javaScripts/attributeValuePairs.js<%=jsVersion%>"  defer="true" type="text/javascript"></script>
<META HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</HEAD>
<BODY>
<%@ include file="include/fidInfo.incl" %>
<%@ include file="include/pageInit.incl" %>
<%

    /* @todo: seems if avp already exist in database, new avp with same key are not added.  need confirmed.*/
    String aid ="addnewComments";
    String aval = "";
    String changed ="0";
    String initVal ="";
    AnnotationDetail [] lastPageAnnotations  = null;
    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );
    GenboreeMessage.clearMessage(mys);
    String pageName = "addGroupAVP.jsp";
    String groupAVP = null;
    HashMap groupAVPMap = new HashMap();
    boolean groupReplacing = false;
    boolean refreshGbrowser = false;
    AnnotationDetail annotation = null;
    AnnotationDetail[] annotations = null;
    AnnotationDetail[] totalAnnotations = null;
    HashMap fid2OrderNum = new HashMap();
    boolean updateAll = false;
    HashMap fid2Annos = new HashMap();
    String checkBoxName = "checkBoxName" ;
    GenboreeMessage.clearMessage(mys);
    HashMap fid2AnnoNums = new HashMap ();
      ArrayList errList = new ArrayList ();
    boolean success = false;
    boolean done = false;

    int globalIndex = 5;
    String indexS = request.getParameter("index");
    if (indexS != null)
        globalIndex = Integer.parseInt(indexS);
    String  lastPageIndex ="";
    String formId = "editorForm";
    int numSelected = 0;
    int [] fidi  = new int [0];
    String selectAll = "selectAll(0)";
    String [] fids = null;
     String confirmSelected = " return confirmAddAVPSelected(0, 0, " + updateAll + ")";

    String unSelectAll = "unSelectAll(0)";
    String doSelected ="doSelected";
    ArrayList groupSelectedFidList = new ArrayList();

    if (request.getParameter("upfid") != null){
        mys.removeAttribute("selectedFidList");
        mys.removeAttribute("groupAVP");
    }
    else {
        if (mys.getAttribute("selectedFidList") != null)
        groupSelectedFidList =   (ArrayList)mys.getAttribute("selectedFidList");
    }
    ArrayList pageSelectedFidList = new ArrayList();
    AnnotationDetail [] selectedAnnotations = null;
    String message = "";
    String className ="";
     int ftypeid = 0;
    if (mys.getAttribute("duplicateGroupMsg") != null) {
        message = (String)mys.getAttribute("duplicateGroupMsg") ;
        mys.removeAttribute("duplicateGroupMsg");
    }

    int i = 0;
    HashMap errorFields = new HashMap();
    int rid = -1;
    String gname = request.getParameter("newGroupName");
    if (request.getParameter("upfid") == null)
        gname = (String )mys.getAttribute("ren_newgname");
    if (gname == null)
        gname="";
  Connection  con = db.getConnection(dbName);
  %>
 <%@ include file="include/largeGroup.incl" %>
<%

  int db2jsp = 0;
    if (request.getParameter("upfid") != null) {
         if (proceedLargeGroup || totalNumAnno <Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN)
        totalAnnotations =   AnnotationEditorHelper.findGroupAnnotations(dbName,  ifid,  response,  mys,  out, con);
          mys.removeAttribute("groupAVPMap");
         mys.removeAttribute("groupReplacing");
    }
    else {
       className = (String)mys.getAttribute("ren_className");
       String id = (String) mys.getAttribute("ren_ftypeid");
            if (id != null)
            ftypeid = Integer.parseInt(id);
            String srid = (String) mys.getAttribute("ren_rid");
            if (srid != null)
            rid = Integer.parseInt(srid);
            if (className != null && ftypeid >0)
            totalAnnotations =   AnnotationEditorHelper.findGroupAnnotations(dbName, className, ftypeid, rid, response, mys, out, con);
            else
            totalAnnotations = new AnnotationDetail[0];
             fid2AnnoNums =  (HashMap )mys.getAttribute("fid2AnnoNums");
          if ( mys.getAttribute("groupAVPMap") != null)
           groupAVPMap =(HashMap) mys.getAttribute("groupAVPMap");
    }

  if (proceedLargeGroup || totalNumAnno <Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN) {

   if (totalAnnotations != null && totalAnnotations.length >0  && request.getParameter("upfid") != null){
      className = totalAnnotations[0].getGname();
        ftypeid = totalAnnotations[0].getFtypeId();
        rid =  totalAnnotations[0].getRid();
        mys.setAttribute("ren_className", className);
        mys.setAttribute("ren_ftypeid", ""+ftypeid);
        mys.setAttribute("ren_rid", ""+rid);
        mys.setAttribute("ren_newgname", gname);
          mys.setAttribute("initval", "");
            mys.setAttribute("changed", "no");
          for (i=0; i<totalAnnotations.length; i++) {

                int tempInt = i+1;
                fid2AnnoNums.put("" + totalAnnotations[i].getFid(), "" + tempInt);
                fid2Annos.put("" + totalAnnotations[i].getFid(), totalAnnotations[i]);
                totalAnnotations[i] = AnnotationEditorHelper.convertAnnotation(totalAnnotations[i], db2jsp);
            }
            mys.setAttribute("fid2AnnoNums", fid2AnnoNums);
    }

    if (totalAnnotations != null && totalAnnotations.length >0 )
        for (i=0; i<totalAnnotations.length; i++) {
            int temp = i + 1;
            fid2OrderNum.put("" + totalAnnotations[i].getFid(), ""+temp);
        }
    HashMap errorField = new HashMap();
    int numAnnotations = 0;
    if ( totalAnnotations != null)
        numAnnotations =  totalAnnotations.length;
    else {
       totalAnnotations= new AnnotationDetail[0];
    }

    if (mys.getAttribute("lastPageIndex")!= null)
        lastPageIndex =  (String)mys.getAttribute("lastPageIndex");

    %>
    <%@ include file="include/multipage.incl" %>
    <%@ include file="include/doSelect.incl" %>
    <%@ include file="include/fidUpdate.incl" %>
    <%
       if (lastPageIndex != null ) {
       if (lastPageIndex.compareTo("" + currentPageIndex)!=0)
           doUpdate = true;
    }

   groupAVP = request.getParameter("globalAVPValues");

    if (groupAVP != null && !groupAVP.equals("")) {
        groupAVPMap = new HashMap ();
        StringTokenizer st = new StringTokenizer(groupAVP, "]");

        while (st.hasMoreTokens()) {
            String token = st.nextToken();
            int indexOfQuote = token.indexOf("\"");
            int indexOfComma = token.indexOf(",", indexOfQuote);
            if (indexOfQuote <0)
            continue;

            String name = null;
            if (indexOfComma >0)
            name = token.substring(indexOfQuote+1, indexOfComma-1);
            if (name==null)
            continue;
            String value = token.substring(indexOfComma +2, token.length()-1);

           if (  groupAVPMap.get(name)  == null) {
            ArrayList tempList = new ArrayList ();

            tempList.add(value);
            groupAVPMap.put(name,tempList)  ;
           }
            else {
             ArrayList tempList = (ArrayList)groupAVPMap.get(name)  ;
            //  tempList = new ArrayList ();
             tempList.add(value);
               groupAVPMap.remove(name)  ;
               groupAVPMap.put(name,tempList)  ;
               errList.add(name);
            }
            }
        if (errList.size() >0)
                GenboreeMessage.setErrMsg(mys, "Identical attribute names are found.  Please rename some of the following attribute names:  ", errList);

         if (groupAVPMap.size() > 0 )
            globalIndex = groupAVPMap.size()-1;

        mys.setAttribute("groupAVPMap", groupAVPMap);
    }
    else
    {
       groupAVPMap = new HashMap ();
          globalIndex = 5;
    };

    if (request.getParameter("replaceComm") != null){
        groupReplacing = true;
        //mys.setAttribute("groupReplacing", new Boolean (groupReplacing));
    }
    else{
        groupReplacing = false;
        if (request.getParameter("upfid") == null) {
            //mys.setAttribute("groupReplacing", new Boolean (false));
        }
    }

    if (request.getParameter(doSelected) != null && errList.size() <=0) {
        String status = request.getParameter("okdupSelected");

        if (status != null && status.compareTo("1")==0) {
        if (groupAVP != null){
            groupAVP = groupAVP.trim();
            groupAVP = AnnotationEditorHelper.stripTabAndReturn(groupAVP);
        }
        numSelected = groupSelectedFidList.size();

           fidi  = new int [numSelected];
           selectedAnnotations = new AnnotationDetail [numSelected];
        int count = 0;
        if (numSelected >0)  {
            if (request.getParameter("replaceComm") != null) {
               groupReplacing = true;
               GenboreeUtils.deleteValuePairs(con, ""+upload.getRefSeqId(),groupSelectedFidList);
              if (groupAVP != null && !groupAVP.equals(""))
               GenboreeUtils.addValuePairs(con, ""+upload.getRefSeqId(),  groupSelectedFidList, ftypeid, groupAVPMap, 0);
            }
            else {

               GenboreeUtils.addValuePairs(con, ""+upload.getRefSeqId(),  groupSelectedFidList, ftypeid, groupAVPMap , 1);
            }

              String [] arr =  (String [])groupSelectedFidList.toArray(new String[groupSelectedFidList.size()] );
              int [] arrInt = new int [arr.length];
             if (arr != null && arr.length > 0)
             {
                   for (i=0; i<arr.length; i++) {
                       arrInt[i] = Integer.parseInt(arr[i]);
                   }

             }
                AnnotationEditorHelper.updateFeature2AVPName(ftypeid, arrInt, con);


            doPaging = true;
    %>
    <%@ include file="include/multipage.incl"%>
    <%
        errorField.remove("gname");
        message="";
        mys.removeAttribute("newGroupName");

        ArrayList msglist = new ArrayList();
        String ss = fidi.length>1? " annotations were updated for their attribute:value pairs ":" annotation was updated for its comment";
        msglist.add(fidi.length +  ss);
        GenboreeMessage.setSuccessMsg(mys, "Process was successful.", msglist);
        CacheManager.clearCache(db, upload.getDatabaseName());
        refreshGbrowser = true;
        success = true;
    }
    else {
    mys.setAttribute("selectedAnnos", null);
    GenboreeMessage.setErrMsg(mys, "Please select some annotations.");
    }
    }
      else{
       mys.setAttribute("selectedAnnos", null);
     }
}

    if (annotations != null && annotations.length>0) {
        selectAll = "selectAll(" + annotations.length+  ")";
        unSelectAll = "unSelectAll(" + annotations.length+  ")";
        int pageSelected  = 0;
        for (i=0; i<annotations.length; i++)  {
        if (groupSelectedFidList.contains("" + annotations[i].getFid()) && !annotations[i].isFlagged())
        pageSelected ++;
        }
        int newSelected = groupSelectedFidList.size() -  pageSelected;
        if (newSelected <0)
        newSelected = 0 ;
        confirmSelected = " return confirmAddAVPSelected("+ newSelected + ", " + totalAnnotations.length + ", " + updateAll +", " + groupAVPMap.size() +  ")";
    }

        if (initVal == null || initVal.compareTo("") ==0) {
            initVal = (String)mys.getAttribute("initVal");
        }

       if (initVal == null)
         initVal ="";

        changed = (String)mys.getAttribute("changed") ;
        if (changed != null && changed.compareTo("yes") == 0)  {
            changed = "1";
        }
        else if (changed != null && changed.compareTo("no") == 0)  {
        changed ="0";
        }
     }

     if (groupAVPMap != null && groupAVPMap.size()>0){
      globalIndex = groupAVPMap.size() -1;
     }

       %>
<% if (proceedLargeGroup || totalNumAnno <Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN) {  %>
<%@ include file="include/header.incl" %>
<%}%>
<%@ include file="include/saved.incl" %>
<%@ include file="include/cancelHandler.incl" %>
<%@ include file="include/validateFid.incl" %>
<%@ include file="include/redir.incl" %>
<form name="<%=formId%>" id="<%=formId%>" action="<%=redir%>" method="post" onSubmit=" return checkAVP(); " >
    <input type="hidden" name="okdupSelected" id="okdupSelected" value="0" >
    <input type="hidden" name="selectAllAnnos" id="selectAllAnnos" value="false" >
    <input type="hidden" name="currentPage" id="currentPage" value="<%=currentPage%>">
    <input type="hidden" name="navigator" id="navigator"  value="home">
    <input type="hidden" name="cancelState" id="cancelState" value="0">
     <input type="hidden" name="doSelected" id="doSelected" value="">
    <input type="hidden" name="globalAVPValues" id="globalAVPValues" value="">
    <input type="hidden" name="index" id="index" value="<%=globalIndex%>">
    <input type="hidden" name="changed" id="changed" value="<%=changed%>">
<%@ include file="include/largeGrpConfirm.incl" %>
 <%if (proceedLargeGroup || totalNumAnno <Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN) {  %>
    <TABLE width="100%" border="0" cellpadding="2" cellspacing="2">
    <TR align="center">
    <TD  class="form_body">    <br>
    <center><FONT SIZE="4">
    <B> Add&nbsp;Attribute:Value&nbsp;pairs&nbsp;to&nbsp;Group&nbsp;&quot;<%=className%>&quot;</B></FONT>
    </center>
    <br>
    <TD></TR>

     <%@ include file="include/mp_pageIndex.incl" %>

    <tr>
    <td>
    <BR>
    <%@ include file="include/message.incl" %>
    <font color="red" size="4">
    <div id="rgmessage1"  class="compact2" >
    </div>
    <div id="rgmessage" align="center" >
    <%

    String  rchecked = "";
    if (groupReplacing)
    rchecked = " checked";
    %>
    </div>
    </font>
    </td>
    </tr>

        <TR>
        <TD width="100%">
        <TABLE width="100%" cellpadding="1" cellspacing="1" border="1">
            <%@include file="include/globalAVP.incl"%>
            <TR align="center">
            <td class="annotation2" colspan="4">
            <B><font color="red"> <I>Replace:</I></font>&nbsp; All the attributes for the WHOLE group will be replaced with the ones
        listed above? &nbsp;</B>
            <input type="checkbox"  name="replaceComm" id="replaceComm" <%=rchecked%> >
        </TD></TR>
        </table>
        <TD>
        </TR>

      <%
    if (annotations != null && annotations.length >0 ){
    %>
    <TR align="center" >
    <TD> <BR>
        <%@ include file="include/avpButton.incl"%>
    </TD>
    </TR>
    <%
    }
    else
    {
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
        <%  }  %>
    <%
    if (annotations != null ) {
        mys.setAttribute("lastPageAnnotations", annotations);

    for (i=0; i<annotations.length; i++) {
        annotation = annotations[i];
       int tempint = i+1;
         String       orderNum = "" + tempint;
         if (  fid2AnnoNums.get ("" + annotation.getFid()) != null)
         {
             orderNum =  (String )fid2AnnoNums.get ("" + annotation.getFid()) ;
         }
        String checkBoxId = "checkBox_" + i ;
        String checked = "";
       if (groupSelectedFidList.contains(""+ annotation.getFid()))
        checked = "checked" ;
       String duplicateId = "duplicate_"+i;
        String gnameid = "gname_" + i;
        HashMap name2Values = new HashMap ();
        fid = "" + annotation.getFid();
        int currentIndex = 0;
    %>

    <%@ include file="include/avpPopulator.incl" %>
    <input type="hidden" name="avpvalues_<%=i%>" id="avpvalues_<%=i%>" value="">
    <input type="hidden" name="index_<%=i%>" id="index_<%=i%>" value="<%=currentIndex%>">

    <input type="hidden" name="<%=duplicateId%>" id="<%=duplicateId%>" value="0">
    <%if (i!=0) {%>
    <tr><td>&nbsp;</td></tr>
    <%}%>
<TR>
<td>
    <table width="100%"  border="1" cellpadding="2" cellspacing="1">
    <TR>
        <TD class="annotation2" colspan="4">
        <input type="checkbox"  name="<%=checkBoxName%>" id="<%=checkBoxId%>" <%=checked%> value=<%=annotation.getFid()%> >
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
        <input type="text"  READONLY  name="<%=gnameid%>" id="<%=gnameid%>" class="largeInputRO"  maxlength="200" value="<%=Util.htmlQuote(annotation.getGname()) %>" >
        </TD>
    </TR>
    <TR>
        <TD ALIGN="left" class="annotation2" colspan="1">
        <B>Track</B>
        </TD>
        <TD class="annotation2" colspan="1">
        <input type="text" id="annotrackName" READONLY class="longInputRO" maxlength="20"  value="<%=annotation.getTrackName()%>">
        </TD>
        <TD ALIGN="left" class="annotation2" colspan="2">&nbsp;</TD>
    </TR>
    <TR>
        <TD ALIGN="left" class="annotation2" colspan="1"><div id="ch2"><B>Chromosome</B></div></TD>
        <TD class="annotation2" colspan="">
        <input READONLY type="text"  name="chromosomes"  id="chromosomes" class="longInputRO" value="<%=annotation.getChromosome()%>">
        </TD>
        <TD ALIGN="left" class="annotation2" colspan="2">&nbsp;</TD>
    </TR>
    <TR>
        <TD ALIGN="left" class="annotation2" colspan="1"><B>Start</B></TD>
        <TD class="annotation2" colspan="1">
        <input type="text" READONLY class="longInputRO"  maxlength="50" value= "<%=annotation.getFstart()%>" >
        </TD>

        <TD ALIGN="left" class="annotation2" colspan="1"> <B>Stop</B></TD>
        <TD class="annotation2" BGCOLOR="white" colspan="1">
        <input READONLY type="text" class="longInputRO"  maxlength="50"  value="<%=annotation.getFstop()%>" >
        </TD>
    </TR>
   <%
        String tempQstart = annotation.getTstart();
        String tempQstop = annotation.getTstop();
        if (tempQstart == null)
        tempQstart = "n/a";
        if (tempQstop == null)
        tempQstop = "n/a";

   %>
    <TR>
        <TD ALIGN="left" class="annotation2" colspan="1"><B>Query&nbsp;Start</B></TD>
        <TD class="annotation2" colspan="1">
        <input  type="text" READONLY BGCOLOR="white" class="longInputRO" maxlength="50" value="<%=tempQstart%>" >
        </TD>

        <TD ALIGN="left" class="annotation2" colspan="1"><B>Query&nbsp;Stop</B></TD>
        <TD class="annotation2" colspan="1">
        <input type="text"  READONLY BGCOLOR="white" class="longInputRO" maxlength="50" value="<%=tempQstop%>">
        </TD>
    </TR>
    <TR>
        <TD ALIGN="left" class="annotation2" colspan="1"><B>Strand</B></TD>
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

        <%@ include file="include/singleAnnoAVPDisplay4cols.incl" %>

    </TR>
    <%
    String commentsid = "comments_" + i ;
    %>
    <TR>
        <TD ALIGN="left" colspan="1" class="annotation2"><B>Free-Form Comment</B></TD>
        <TD align="left" class="annotation2" colspan="3">
        <TEXTAREA  name="comments" id="<%=commentsid%>" READONLY align="left" rows="4" class="largeTextareaRO" value="<%=annotation.getComments()%>"><%=annotation.getComments()%></TEXTAREA>
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
<%}} %>
<% if(annotations != null && annotations.length >1  ){
%>

<TR align="center" >
<td>
<br>
<%@ include file="include/avpButton.incl"%>

</td>
</TR>
<TR><td>&nbsp;</td></tr>
<%@ include file="include/multipageEditorBottom.incl" %>
<%}%>
</table>
<%}%>
</form>
<%@ include file="include/invalidFidMsg.incl"%>
<% if (proceedLargeGroup || totalNumAnno <Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN) {  %>
<%@ include file="include/footer.incl" %>
<%}%>
</BODY>
</HTML>
<%
  if(refreshGbrowser)
  {
    refreshGbrowser = false ;
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
