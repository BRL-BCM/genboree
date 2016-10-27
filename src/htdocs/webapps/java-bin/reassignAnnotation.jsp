<%@ page import="java.sql.ResultSet,
    java.io.InputStream,
    java.sql.SQLException,
    java.util.*,
    java.util.regex.Pattern,
    java.util.regex.Matcher,
    java.lang.reflect.Array,
     java.sql.Connection,
     org.genboree.util.*,
     org.genboree.editor.AnnotationEditorHelper"
%>
<%@ page import="javax.servlet.http.*, org.genboree.upload.HttpPostInputStream " %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%@ include file="include/fidInfo.incl" %>
<%@ include file="include/cancelHandler.incl" %>
<%
    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );
    boolean deleted = false;
    int i = 0;
    int currentIndex = 0;
    String changed="0";
    String aid = "rgnewTrackName";
    String aval = "";
    int genboreeUserId = Util.parseInt(myself.getUserId(), -1);
    HashMap name2Values = new HashMap ();
    AnnotationDetail annotation = new AnnotationDetail(ifid);
    Connection con =  db.getConnection(dbName);
    if (con == null || con.isClosed())
      GenboreeUtils.sendRedirect(request,response, "/java-bin/error.jsp");
    String currentTrackName = "";
    String [] tracks = new String [0];
    HashMap trackMap = AnnotationEditorHelper.findTracks (db, con, genboreeUserId, dbName);

  if (trackMap != null && trackMap.size() > 0) 
  {
    Iterator iterator = trackMap.keySet().iterator();
    int count = 0;
    tracks = new String [trackMap.size()];
    while (iterator.hasNext())
    {
      tracks[count] = (String) iterator.next();
      System.err.println("The track for the editor is " + tracks[count]);
      count++;
    }
    Arrays.sort(tracks);
    String [] newTracks = new String [tracks.length + 1] ;
    newTracks [0] = "**New Track**";
    for (int j=1; j<=tracks.length; j++)
      newTracks [j] = tracks [j-1];
    tracks = newTracks;
  }
  else
  {
    GenboreeUtils.sendRedirect(request,response, "/java-bin/error.jsp");
  }

    int db2jsp  = 0;
    String message = "";
    con =  db.getConnection(dbName);
    if (con == null || con.isClosed())
    GenboreeUtils.sendRedirect(request,response, "/java-bin/error.jsp");
    annotation = AnnotationEditorHelper.findAnnotation (annotation, db, con, fid );
    if (annotation == null)
      GenboreeUtils.sendRedirect(request,response, "/java-bin/error.jsp");

    String    className = annotation.getGname();
    int classFtypeid = annotation.getFtypeId();
    int  classRid = annotation.getRid();
    int oldid = annotation.getFtypeId();
    annotation = AnnotationEditorHelper.convertAnnotation(annotation, db2jsp);
    Vector vlog = new Vector();
    HashMap errorField = new HashMap();
    String type = "";
    String subtype = "";
    boolean success = false;
    AnnotationDetail oldAnnotation =  annotation;
    boolean updated = false;
    AnnotationDetail annobk = new AnnotationDetail(annotation.getFid());
    annobk = AnnotationEditorHelper.copy(annotation, annobk);
     String newTrackName = annotation.getTrackName();
     if (request.getParameter("upfid")==null)
        newTrackName =(String) mys.getAttribute("lastTrackName");

    if (newTrackName == null)
        newTrackName = "";

     if (request.getParameter("btnReassignAnnotation") != null)
     {
        String status = request.getParameter("okReassign");
        if (status != null && status.compareTo("1")==0)
        {
    // startCheck dup

    request.setAttribute("okReassign", "0");
    newTrackName = request.getParameter("rgnewTrackName");

          if (newTrackName != null)
          {
            if ( newTrackName  != null && newTrackName.indexOf("New Track") < 0)
            {
              currentTrackName =  newTrackName ;
              newTrackName =  newTrackName.trim();
              if (AnnotationEditorHelper.validateTracks(false,  newTrackName, type, subtype, dbName,  mys, trackMap,  annotation, request, errorField, vlog,  out, con) ==0) {
                success = true;
              }
            }
            else if (newTrackName  != null && newTrackName.indexOf("New Track") >0)
            {
              type = request.getParameter("rgnewtype");
              subtype = request.getParameter("rgnewsubtype");
              if (type!= null && subtype != null)
              {
                type = type.trim();
                subtype = subtype.trim();
                if (AnnotationEditorHelper.validateTracks(true,  newTrackName, type, subtype, dbName,  mys, trackMap,  annotation, request, errorField, vlog,  out, con) ==0)
                {
                  success = true;
                  annotation.setFmethod(type);
                  annotation.setFsource(subtype);
                  String []  newTracks = new String [tracks.length + 1];
                  for ( int n=0; n<tracks.length; n++)
                    newTracks[n] = tracks [n];
                  newTracks[tracks.length] =  type + ":" + subtype;
                  tracks = newTracks;
                }
                else {
                  mys.setAttribute("lastSelectedGroupnewType", type);
                  mys.setAttribute("lastSelectedGroupnewSubType", subtype);

                }
              }
            }
            boolean isDupAnno = false;
            boolean isDupText = false;
            int dupfid = 0;
            // check duplication
            if (success)
            {
              mys.setAttribute("lastTrackName", newTrackName);
              dupfid = AnnotationEditorHelper.isDupAnnotation(dbName, annotation, con);
              if (dupfid > 0)
              {
                isDupText = AnnotationEditorHelper.isDupText(dbName, dupfid, annotation, con);
                isDupAnno = true;
              }
              if (isDupAnno && isDupText)
              {
                vlog.add("An exact copy of this annotation already exists in track \"" +annotation.getTrackName()
                        + "\". <BR><BR>");
                annotation.setFtypeId(annobk.getFtypeId());
                annotation.setTrackName(annobk.getTrackName());
                annotation.setFmethod(annobk.getFsource());
                annotation.setFsource(annobk.getFsource());
                success = false;
              }
            }
            if (success)
            {
              if (request.getParameter("copytrack") != null)
              {
                int newfid = 0;
                if (!isDupAnno) {
                  newfid = AnnotationEditorHelper.duplicateAnnotation( annotation.getFtypeId(), annotation, dbName, con);

                  if (newfid > 0)
                  {
                    message = "Successfully assigned the annotation to a copy.<br>" ;
                    updated = true;
                  }
                  else
                  {
                    newfid = AnnotationEditorHelper.isDupAnnotationData(dbName, annotation, con);

                    if (newfid >0 )
                    {
                      AnnotationEditorHelper.deleteAnnotation ( newfid, db, dbName, out, con);

                      newfid = AnnotationEditorHelper.duplicateAnnotation( annotation.getFtypeId(), annotation, dbName, con);

                      if (newfid > 0)
                      {
                        message = "Successfully assigned the annotation to a copy.<br>" ;
                        updated = true;
                      }
                    }
                  }
                }
                else {  //isDupANno
                  if (!isDupText)
                  {
                    AnnotationEditorHelper.duplicateAnnoText(dupfid, annotation.getFid(), dbName, con);
                    message = "Successfully assigned the annotation to a copy.<br>" ;
                  }
                }
                int arr [] = new int [] {newfid} ;
                AnnotationEditorHelper.updateFeature2AVPName( annotation.getFtypeId(), arr, con );
              }
              else
              {
                if (!isDupAnno)
                {
                  //  AnnotationEditorHelper.deleteAnnotation ( ifid, db, dbName, out);
                  // int newfid = AnnotationEditorHelper.insertAnnotation (annotation, dbName) ;
                    // test when comments non exist in new ftype
                    AnnotationEditorHelper.updateFtypeid( annotation.getFtypeId(), ifid,   con);
                    int [] arr = new int [] {ifid};
                    AnnotationEditorHelper.updateFeature2AVPName( annotation.getFtypeId(), arr, con );
                    // AnnotationEditorHelper.deleteAnnotation ( ifid, db, dbName, out);
                    int newfid = AnnotationEditorHelper.isDupAnnotationData(dbName, annotation, con);
                    if (newfid >0 )
                    {
                      AnnotationEditorHelper.deleteAnnotation ( newfid, db, dbName, out, con);
                      AnnotationEditorHelper.updateFtypeid( annotation.getFtypeId(), ifid,  con);
                      arr = new int [] {ifid};
                      AnnotationEditorHelper.updateFeature2AVPName( annotation.getFtypeId(), arr, con );
                    }
                    else
                    {
                      vlog.add("failed in reassign operation ");
                    }

                }
                else {  //isDupAnnotation
                  if (!isDupText)
                  {
                    AnnotationEditorHelper.reassignAnnotationText ( con, dupfid,annotation.getFid(), annotation,  db, dbName );
                  }

                  int [] arr = new int [] {dupfid};
                  AnnotationEditorHelper.updateFeature2AVPName( annotation.getFtypeId(), arr, con );

                  AnnotationEditorHelper.deleteAnnotation ( ifid, db, dbName, out, con);


                }





                if (vlog.isEmpty()) {
                  message = "Successfully reassigned the annotation.<br>" ;
                  updated = true;
                }
                annotation = oldAnnotation;
                //success = false;
              }
            }
            else {
              message = "";
            }
          }
          // end of valid
        }
     }
    %>

 <%@ include file="include/saved.incl" %>

 <%@ include file="include/avpPopulator.incl" %>

<HTML>
<head>
    <title>Genboree - Show Annotation Text and Sequence</title>
    <link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
    <link rel="stylesheet" href="/styles/annotationEditor.css<%=jsVersion%>" type="text/css">
    <link rel="stylesheet" href="/styles/avp.css<%=jsVersion%>" type="text/css">
    <LINK rel="stylesheet" href="/styles/querytool.css<%=jsVersion%>" type="text/css">
    <script type="text/javascript" src="/javaScripts/util.js<%=jsVersion%>"></script>
   <SCRIPT TYPE="text/javascript" SRC="/javaScripts/commonFunctions.js<%=jsVersion%>"></SCRIPT>
<SCRIPT TYPE="text/javascript" SRC="/javaScripts/reassignAnnotation.js<%=jsVersion%>"></SCRIPT>
    <SCRIPT TYPE="text/javascript" SRC="/javaScripts/delimitComments.js<%=jsVersion%>"></SCRIPT>
    <SCRIPT TYPE="text/javascript" SRC="/javaScripts/prototype.js<%=jsVersion%>"></SCRIPT>
    <SCRIPT TYPE="text/javascript" SRC="/javaScripts/editorCommon.js<%=jsVersion%>"></SCRIPT>

    <script src="/javaScripts/attributeValuePairs.js<%=jsVersion%>"  defer="true" type="text/javascript"></script>
    <meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY>
    <%@ include file="include/header.incl" %>
    <%@ include file="include/validateFid.incl" %>
    <form name="editorForm" id="editorForm"  action="reassignAnnotation.jsp" method="post" onSubmit="return validTrackName();">
    <input type="hidden"  name="okReassign" id="okReassign" value="0">
    <input type="hidden" name="rggroupTrackName" id="rggroupTrackName" value="<%=annotation.getTrackName()%>" >
    <input type="hidden" name="changed" id="changed" value="<%=changed%>">
    <input type="hidden" name="cancelState" id="cancelState" value="0">
    <table width="100%" border="0" cellpadding="2" cellspacing="2">
    <tr align="center">
    <td>
    <p>&nbsp;
    <CENTER><FONT SIZE="4"><B>Assign This Annotation</B></FONT></CENTER>
    <% if (!updated) {   %>
    <script>
    var trkArr = new Object();
    var numTrks = <%=tracks.length%>;
    <%

          for (int x=0; x<tracks.length; x++){
      if (tracks[x] != null && tracks[x].indexOf("\"") >=0 )
      {
              tracks[x] = Util.htmlQuote(tracks[x]);
         // tracks[x] = tracks[x].replaceAll("\"", "\\\"");
       }
        out.println( "trkArr["+x+"]=\""+tracks[x]+"\";" );
      }
    %>
    </script>
    <TABLE cellpadding="1" cellspacing="1" border="1">
    <% if (errorField.get("newTrackRow") == null) {  %>
    <TR id="rgTrackRow" align="center"><BR>
    <TD name="rgtrackLabel" id="rgtrackLabel" align="right" class="annotation2">
    <B>Assign&nbsp;to&nbsp;Track:</B></TD>
    <td colspan="2" class="annotation2">&nbsp;
    <select  name="rgnewTrackName" id="rgnewTrackName" class="longDropList"  onchange="checkRGNewTrack();" >
    <%
    for (int j=0; j<tracks.length; j++) {
    String sel = "";
    if (tracks[j].compareTo(Util.htmlQuote(newTrackName)) ==0)
    sel = " selected";
    %>
    <option  value="<%=tracks[j]%>" <%=sel%>> <%=tracks[j]%> </option>
    <%}%>
    </select>
    </td>
    </tr>
    <tr id="rgnewTrackRow1"  style="display:none">
    <td id="rgtypeLabel" class="annotation2" align="center" ><b>New&nbsp;Type:&nbsp;</b></td>
    <td  colspan="2" class="annotation2">&nbsp;
    <input id="rgtype" type="text" name="rgnewtype" class="longInput3"></td>
    </tr>
    <tr id="rgnewTrackRow2" style="display:none" >
    <td id="rgsubtypeLabel" class="annotation2" align="center"><b>New &nbsp;Subtype:&nbsp;</b></td>
    <td  colspan="2" class="annotation2">&nbsp;
    <input type="text" id="rgsubtype" name="rgnewsubtype" class="longInput3"  ></td>
    </tr>
    <% }
    else {%>
    <TR id="rgTrackRow" align="center"> <BR>
    <TD name="rgtrackLabel" id="rgtrackLabel" align="center" class="annotation2">
    <B>Assign&nbsp;to&nbsp;Track:</B></TD>
    <td colspan="2" class="annotation2">&nbsp;
    <select  name="rgnewTrackName" id="rgnewTrackName" class="longDropList" onchange="checkRGNewTrack()" >
    <%
    type =  (String)mys.getAttribute("lastSelectedGroupnewType");
    subtype = (String)mys.getAttribute("lastSelectedGroupnewSubType");
    if (type==null)
    type="";
    if (subtype==null)
    subtype="";

    for (int j=0; j<tracks.length; j++) {
    String sel = "";
    if (tracks[j].compareTo(currentTrackName) ==0)
    sel = " selected";
        %>
    <option  value="<%=Util.htmlQuote(tracks[j])%>"<%=sel%>><%=Util.htmlQuote(tracks[j])%></option>
    <%}%>
    </select>
    </td>
    </tr>
    <tr id="rgnewTrackRow1" >
    <td id="rgtypeLabel" class="annotation1" align="right" ><b>New&nbsp;Type:&nbsp;</b></td>
    <td  colspan="2" class="annotation2">&nbsp;
    <input  type="text" name="rgnewtype"  id="rgtype" class="longInput3"  value="<%=Util.htmlQuote(type)%>"></td>
    </tr>
    <tr id="rgnewTrackRow2" >
    <td id="rgsubtypeLabel" class="annotation1" align="right"><b>Subtype:&nbsp;</b></td>
    <td  colspan="2" class="annotation2">&nbsp;
    <input type="text"  name="rgnewsubtype" id="rgsubtype" class="longInput3" value="<%=Util.htmlQuote(subtype)%>"></td>
    </tr>
    <%}%>
    <TR>
    <TD class="annotation2" colspan="4">
    <B><I>Copy</I> to track, rather than move to track?</B>
    <input type="checkbox"  name="copytrack" id="copytrack">
    </TD>
    </TR>

    </TABLE>
    <%}%>
    <BR>
    <div id="msg" class="successMsg" align="center">
    <%=message%>
    </div>

    <font color="red">
    <UL class="compact2">
    <div id="rgmessage" align="left">
    <%
    if( vlog != null && vlog.size() > 0 ) { %>
    <%     for( i=0; i<vlog.size(); i++ ) {
    out.print( "<li> &middot; " + (String)vlog.elementAt(i) );
    }
    out.print( "<BR>");
    %>
    <% } %>
    </div>  </UL>
    </font>
    <table  width="100%" border="0" cellpadding="0" cellspacing="0">
    <TR>
    <TD>
    <table width="100%" id="infoTable"  border="1" cellpadding="2" cellspacing="1">
    <TR>
    <TD class="annotation2" colspan="1" align="center"> <div id="annoname" > <B>Annotation&nbsp;Name</B></div> </td>
    <TD class="annotation2" colspan="3">
    <input READONLY type="text" name="gname" id ="gname" class="largeInputRO"  maxlength="200" value="<%=Util.htmlQuote(annotation.getGname()) %>" >
    </TD>
    </TR>
    <TR id="trackRow">
    <TD ALIGN="center" class="annotation2" colspan="1">
    <div id="track"><B>Track<B></div></TD>
    <TD class="annotation2" colspan="1">
    <input READONLY type="text"  name="trackName"  id="trackName" class="longInputRO" value="<%=Util.htmlQuote(annotation.getTrackName())%>">
    </TD>
    <TD ALIGN="right" class="annotation2" colspan="2">&nbsp;</TD>
    </TR>
    <TR>
    <TD ALIGN="center" class="annotation2" colspan="1"><div id="ch2"><B>Chromosome<B></div></TD>
    <TD class="annotation2" colspan="">
    <input READONLY type="text"  name="chromosomes"  id="chromosomes" class="longInputRO" value="<%=annotation.getChromosome()%>">
    </TD>    <TD ALIGN="left" class="annotation2" colspan="2">&nbsp;</TD>
    </TR>
    <TR>
    <TD ALIGN="right" class="annotation2" colspan="1"><div id="startLabel"><B>Start<B></div></TD>
    <TD class="annotation2" colspan="1">
    <input READONLY type="text"  class="longInputRO" name="ep_Start" id="ep_Start" maxlength="50" value= "<%=annotation.getFstart()%>" >
    </TD>
    <TD ALIGN="right" class="annotation2" colspan="1"><div id="stop"><B>Stop<B></div></TD>
    <TD class="annotation2" BGCOLOR="white" colspan="1">
    <input READONLY type="text" class="longInputRO" name="epStop" id="epStop" maxlength="50"  value="<%=annotation.getFstop()%>" >
    </TD>
    </TR>
    <TR>
    <TD ALIGN="right" class="annotation2" colspan="1"><div id="qstart"><B>Query&nbsp;Start</B></div></TD>
    <TD class="annotation2" colspan="1">
    <input name="tstart" READONLY id = "tstart" type="text" BGCOLOR="white" class="longInputRO" maxlength="50" value="<%=annotation.getTstart()%>" >
    </TD>
    <TD ALIGN="right" class="annotation2" colspan="1"><div id="qstop"><B>Query&nbsp;Stop</B></div></TD>
    <TD class="annotation2" colspan="1">
    <input type="text" READONLY name="tstop" id="tstop" BGCOLOR="white" class="longInputRO" maxlength="50" value="<%=annotation.getTstop()%>">
    </TD>
    </TR>
    <TR>
    <TD ALIGN="right" class="annotation2" colspan="1"><strand><B>Strand</B></div></td>
    <TD class="annotation2" colspan="1">
    <input READONLY type="text" class="longInputRO" name="strand" id="strand" BGCOLOR="white" maxlength="50" value="<%=annotation.getStrand()%>">
    </TD>
    <TD ALIGN="right" class="annotation2" colspan="1"><div id="phase"></div><B>Phase</B></div></TD>
    <TD ALIGN="left" class="annotation2" colspan="1">
    <input READONLY type="text" class="longInputRO" name="phase" id="phase" BGCOLOR="white" maxlength="50" value="<%=annotation.getPhase()%>">
    </TD>
    </TR>
    <TR>
    <TD ALIGN="right" class="annotation2" colspan="1"><div id="score"><B>Score</B></div></TD>                                                     			<!-- SCORE -->
    <TD ALIGN="right" class="annotation2" colspan="1">
    <input READONLY type="text" class="longInputRO" name="fscore" id="fscore" BGCOLOR="white" maxlength="50" value="<%=annotation.getFscore()%>">
    </TD>
    <TD ALIGN="right" class="annotation2" colspan="2">&nbsp;</TD>
    </TR>

    <%@ include file="include/singleAnnoAVPDisplay4cols.incl" %>

    <TR>
    <TD ALIGN="right" colspan="1" class="annotation2"><div id="labelcomment"><B>Free-Form Comment</B></div></TD>
    <TD align="left" class="annotation2" colspan="3">
    <TEXTAREA READONLY name="comments" id="comments"  align="left" rows="4" class="largeTextareaRO" value="<%=annotation.getComments()%>"><%=annotation.getComments()%></TEXTAREA>
    </TD>
    </TR>
    <TR>
    <TD ALIGN="right" colspan="1" class="annotation2"><div id="sequences"><B>Sequence</B></div></TD>
    <TD align="left" class="annotation2" colspan="3">
    <TEXTAREA READONLY name="sequence" id="sequence" align="left" rows="4" class="largeTextareaRO"  value="<%=annotation.getSequences()%>"><%=annotation.getSequences()%></TEXTAREA>
    </TD>
    </TR>
     </TABLE>
     </TD>
     </TR>
    </TABLE>
        <td>
        </tr>
      <TR align="left"><TD>
        <% if (!updated) { %>
            <div aign="left"> <BR>  <nobr>  &nbsp;&nbsp;
            <input  type="submit" class="btn"  name="btnReassignAnnotation" id="btnReassignAnnotation"  value=" Assign "   width="120" HEIGHT="110" onClick="confirmReassign()"> &nbsp;
            <input type="button" name="btnCancelReassign" id="btnCancelReassign" value="Cancel"  class="btn"  onClick="processQuit('<%=aval%>', '<%=aid%>');" >
            <%} else {%>  &nbsp;&nbsp;
            <input type="button" name="btnClose" id="btnClose" value="Close Window"  class="btn" onClick="window.close();">
            </nobr>
            </div>
         <%}%>
        </TD></TR>
      </table>
    </form>
    <%@ include file="include/invalidFidMsg.incl"%>
    <%@ include file="include/footer.incl" %>
    </BODY>
    <%if(updated){
    if (con == null || con.isClosed())
    con = db.getConnection(dbName);
    //  System.err.println("before call process context in single assign with sleep 3000: " + new Date().getTime());
    int refseqid = upload.getRefSeqId();
    int ftypeid =  annotation.getFtypeId();
    String gname = annotation.getGname();
    int rid =  annotation.getRid();
    boolean validParams = false;
    if (refseqid >0 && ftypeid >0 && rid >0 && gname != null)
    validParams = true;
    if (validParams)
    GenboreeUtils.processGroupContextForGroup(""+refseqid,  gname,  "" + ftypeid,  "" + rid, false);
    validParams = false;
    if (refseqid >0 &&classFtypeid >0 && classRid >0 && className != null)
    validParams = true;
    if (validParams)
    GenboreeUtils.processGroupContextForGroup(""+refseqid, className,  "" + classFtypeid,  "" + classRid , false);
    CacheManager.clearCache(db, upload.getDatabaseName()) ;
    %>
    <script language="javascript" type="text/javascript">
    confirmRefresh() ;
    onBlur=self.focus();
    </script>
    <%}%>
    </HTML>
