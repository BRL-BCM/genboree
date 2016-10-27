<%@ page import="java.text.NumberFormat,
    java.text.DecimalFormat,
    java.io.InputStream,
    java.util.*,
    java.util.regex.Pattern,
    java.util.regex.Matcher,
    java.lang.reflect.Array,
    org.genboree.util.*,
    org.genboree.editor.AnnotationEditorHelper,
    org.genboree.editor.Chromosome,
    java.sql.*,
    java.util.Date"
%>
<%@ page import="javax.servlet.http.*, org.genboree.upload.HttpPostInputStream " %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%@ include file="include/fidInfo.incl" %>
<%@ include file="include/cancelHandler.incl" %>
<%
    String aid ="";
    String aval = "";
    String changed ="0";
    String initVal ="";
    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );
    Vector vLog = new Vector();
    String []  chromosomes = new String [] {""};
    ArrayList  chromosomeList = new ArrayList();
    String [] tracks = new String [] {""};
    HashMap errorFields = new HashMap ();
    int state = 0;
    String classGname = "";
    int classFtypeid = 0;
    int classRid = 0;
    int currentIndex = 0;
    boolean refreshGbrowser  = false;
    int i = 0;
    int genboreeUserId = Util.parseInt(myself.getUserId(), -1);

    boolean success = false;
    AnnotationDetail annotation = new AnnotationDetail(ifid);
    Connection con =  db.getConnection(dbName);
    if (con == null || con.isClosed())
    GenboreeUtils.sendRedirect(request,response, destback);
    int db2jsp  = 0;
    int jsp2db = 1;
    try {
        annotation = AnnotationEditorHelper.findAnnotation (annotation, db, con, fid );
    }
    catch (Exception e)
    {
      e.printStackTrace( System.err );
      System.err.println("Error AnnotationEditor line 53");
     GenboreeUtils.sendRedirect(request,response,  "/java-bin/error.jsp");
     return;
    }

    if (annotation == null) {
     GenboreeUtils.sendRedirect(request,response,  "/java-bin/error.jsp");
     return;
    }
    if (annotation.getGname() == null || annotation.getGname().compareTo("") == 0 ) {
    GenboreeUtils.sendRedirect(request,response, destback);
     return;
    }
    classGname = annotation.getGname();
    classFtypeid = annotation.getFtypeId();
    classRid = annotation.getRid();
    AnnotationDetail  annotationDB = annotation;
    annotation = AnnotationEditorHelper.convertAnnotation(annotation, db2jsp);
    con =  db.getConnection(dbName);
    if (con == null || con.isClosed()) {
        GenboreeUtils.sendRedirect(request,response, destback);
        return;
    }
    HashMap trackMap = null;

    trackMap =AnnotationEditorHelper.findTracks (db, con, genboreeUserId, dbName);

    HashMap chromosomeMap = null;
    try {
        chromosomeMap = AnnotationEditorHelper.findChromosomes (db, con);
    }
    catch (SQLException e) {
     e.printStackTrace(System.err);
     GenboreeUtils.sendRedirect(request,response,  "/java-bin/error.jsp");
     return;
    }
    Chromosome chromosome = null;
    if (trackMap != null && trackMap.size() > 0) {
        Iterator iterator = trackMap.keySet().iterator();
        int count = 0;
        tracks = new String [trackMap.size()];
        while (iterator.hasNext()) {
        tracks[count] = (String) iterator.next();
        count++;
        }
    }
    else {
      GenboreeUtils.sendRedirect(request,response,  "/java-bin/error.jsp");
      return;
    }
    if (tracks != null)
    Arrays.sort(tracks);

    String newTrack =  "**New Track**";
    String [] newTracks = new String[0] ;
    // String [] newTracks = updateTracks (annotations.length, request, dbName, trackMap);
    if (tracks != null && tracks.length >0) {
        newTracks = new String[tracks.length + 1] ;
        newTracks [0] = newTrack;
        for (int n =1; n<=tracks.length; n++)
        newTracks [n] = tracks[n-1];
        tracks = newTracks;
    }
    else
        tracks = new String [] {newTrack};

     if (chromosomeMap == null ||chromosomeMap.isEmpty()) {
        GenboreeUtils.sendRedirect(request,response,  "/java-bin/error.jsp");
     }

    if (!chromosomeMap.isEmpty()) {
        chromosomes =  (String[])chromosomeMap.keySet().toArray(new String[chromosomeMap.size()]);
    }
    Arrays.sort(chromosomes);
    if (chromosomes != null && chromosomes.length >0)
    {
        for (i=0; i<chromosomes.length; i++)
        {
        chromosomeList.add(chromosomes[i]);
        }
    }
   %>
   <%@ include file="include/setColor.incl" %>
 <%
 String message = "";
    String vStatus = null;

   // if (request.getParameter("doSelected") != null) {
        if ((vStatus = request.getParameter("vstate")) != null  && vStatus.compareTo("1")==0) {
            state = 0;
            if (AnnotationEditorHelper.validateForm(  annotation, trackMap, mys, request,  errorFields,  vLog,  chromosomeMap, out, upload.getDatabaseName(), con))  {
            String tempTrack =  request.getParameter("tracks");
             if (tempTrack != null && tempTrack.indexOf("New Track") >0) {
                newTracks = new String[tracks.length + 1] ;
                String type =   request.getParameter("new_type");
                String subtype = request.getParameter("new_subtype");
                if (  type!= null && subtype != null){
                    type = type.trim();
                    subtype = subtype.trim();
                    if (type.length() > 0 && subtype.length() > 0 ) {
                    newTracks[tracks.length] = type+ ":" + subtype;
                    Arrays.sort(tracks);
                    for ( int n=0; n<tracks.length; n++)
                    newTracks[n] = tracks [n];
                    tracks = newTracks;
                    }
                }
            }
            AnnotationDetail anno = AnnotationEditorHelper.convertAnnotation(annotation, jsp2db);
            int intHColor = 0;
            curColor = request.getParameter("hiddenInputId");
            String useDefault =  request.getParameter("isDefaultColor");
             if (useDefault != null && useDefault.indexOf("true")>=0)
                 isDefaultColor = true;
              else
               isDefaultColor = false;

            if (curColor == null)
                curColor="000000" ;
            else {
                curColor =  curColor.trim();
               curColor = curColor.replaceAll("#", "");
            }
               anno.setHexAnnoColor(curColor);
            if (isDefaultColor)
               anno.setHexAnnoColor(null);

            if (curColor != null && curColor.compareTo("#") != 0 && !isDefaultColor) {
                String temp = curColor.replaceAll("#", "") ;
                if (temp.length()>0 && temp!="")
                intColor = Integer.parseInt(temp, 16);
                anno.setDisplayColor(intColor);
            }

            boolean isFDataDup = false;
            int id  = AnnotationEditorHelper.isDupAnnotation(dbName, anno, con);
            boolean isTextDup = false;
            if (id > 0)   {
                isFDataDup = true;
                isTextDup = AnnotationEditorHelper.isDupText(dbName, id,  anno, con);
            }

            if ( !isFDataDup) {
                     AnnotationEditorHelper.updateAnnotation(anno, db, upload, out, con);
                  int [] arr = new int [] {  anno.getFid()};
                AnnotationEditorHelper.updateFeature2AVPName(anno.getFtypeId(), arr, con);

                     success = true;
            }
          if (!isTextDup && isFDataDup) {
            String comments = anno.getComments();
            String sequences = anno.getSequences();
            if  (comments != null)
            comments = comments.trim();
             if (sequences != null )
            sequences = sequences.trim();
            boolean updatable = false;
            if (comments != null && comments.compareTo("") != 0)
            updatable = true;

            if (sequences != null && sequences.compareTo("") != 0)
            updatable = true;

             if ( updatable) {
                AnnotationEditorHelper.updateText(id, anno, db, upload, out, con);
                success = true;
            }
        }
        JSPErrorHandler.checkErrors(request, response, db, mys);

        if (isFDataDup  && isTextDup )  {
            success = false;
            vLog.add("Exact same annotation exist. Please make some change and submit again." );
        }

            String avpValues = request.getParameter("avpvalues");
      %>
        <%@ include file="include/updateAVP.incl"%>
      <%
        if (success) {
            annotation.setDisplayColor(intColor);
            annotation.setHexAnnoColor(curColor);
            annotation = AnnotationEditorHelper.convertAnnotation(annotation, db2jsp);
            vLog = new Vector();
            message = "<BR>This annotation is updated successfully<br>";
            refreshGbrowser = true;
            CacheManager.clearCache(db, upload.getDatabaseName()) ;
        }
        }
        }
   // }
    else{
        refreshGbrowser = false;
    }
    String validationStatus = null;
    if (request.getParameter("btnReset") != null) {
        if ((validationStatus = request.getParameter("vstatus")) != null  && validationStatus.compareTo("1")==0) {
        annotation = annotationDB;
        vLog.clear();
        }
    }
    if (request.getParameter("btnCancel") != null) {
        GenboreeUtils.sendRedirect(request,response, destback);
    }
    HashMap name2Values = new HashMap ();
    if (annotation!= null)
    annotation = AnnotationEditorHelper.convertAnnotation(annotation, db2jsp);
%>
<%
if (success) {
    int refseqid = upload.getRefSeqId();
    int  ftypeid =  annotation.getFtypeId();
    String gname = annotation.getGname();
    int rid =  annotation.getRid();
    boolean validParams = false;
    if (refseqid >0 && ftypeid >0 && rid >0 && gname != null)
    validParams = true;
    if (validParams)
    GenboreeUtils.processGroupContextForGroup(""+refseqid,  gname,  "" + ftypeid,  "" + rid, false);
    validParams = false;
    if (refseqid >0 && classFtypeid >0 && classRid >0 && classGname != null)
    validParams = true;
    GenboreeUtils.processGroupContextForGroup(""+refseqid,  classGname,  "" + classFtypeid,  "" + classRid, false);
}
%>
<%@ include file="include/saved.incl" %>
<%@ include file="include/avpPopulator.incl" %>
<%
    if (mys.getAttribute("fromDup") != null){
    refreshGbrowser = true;
    mys.removeAttribute("fromDup") ;
    }
 %>
<HTML>
    <head>
    <title>Genboree - Show Annotation Text and Sequence</title>
    <link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
    <link rel="stylesheet" href="/styles/avp.css<%=jsVersion%>" type="text/css">
    <link rel="stylesheet" href="/styles/querytool.css<%=jsVersion%>" type="text/css">
    <link rel="stylesheet" href="/styles/colorWheel.css<%=jsVersion%>" type="text/css">
    <link rel="stylesheet" href="/styles/annotationEditor.css<%=jsVersion%>" type="text/css">
    <meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
    <SCRIPT TYPE="text/javascript" SRC="/javaScripts/annotationEditor.js<%=jsVersion%>"></SCRIPT>
    <SCRIPT TYPE="text/javascript" SRC="/javaScripts/delimitComments.js<%=jsVersion%>"></SCRIPT>
    <script src="/javaScripts/util.js<%=jsVersion%>" type="text/javascript"></script>
    <script src="/javaScripts/prototype.js<%=jsVersion%>" type="text/javascript"></script>
    <script src="/javaScripts/commonFunctions.js<%=jsVersion%>" type="text/javascript"></script>
    <script src="/javaScripts/attributeValuePairs.js<%=jsVersion%>"  defer="true" type="text/javascript"></script>
    <script src="/javaScripts/scriptaculous.js<%=jsVersion%>" type="text/javascript"></script>
    <SCRIPT type="text/javascript" src="/javaScripts/overlib.js<%=jsVersion%>"></SCRIPT>
    <SCRIPT type="text/javascript" src="/javaScripts/json.js<%=jsVersion%>"></SCRIPT>
    <SCRIPT type="text/javascript" src="/javaScripts/overlib_hideform.js<%=jsVersion%>"></SCRIPT>
    <script type="text/javascript" src="/javaScripts/overlib_cssstyle.js<%=jsVersion%>"></script>
    <SCRIPT type="text/javascript" src="/javaScripts/colorbox.js<%=jsVersion%>"></SCRIPT>
    <SCRIPT type="text/javascript" src="/javaScripts/trkmgrcolor.js<%=jsVersion%>"></SCRIPT>
    <SCRIPT type="text/javascript" src="/javaScripts/colorWheel.js<%=jsVersion%>"></SCRIPT>
    <script type="text/javascript" src="/javaScripts/overlib_cssstyle.js<%=jsVersion%>"></script>
    <script type="text/javascript" src="/javaScripts/editorCommon.js<%=jsVersion%>"></script>
    <SCRIPT type="text/javascript" src="/javaScripts/overlib_draggable.js<%=jsVersion%>"></SCRIPT>
    </head>
<BODY  >
<%@ include file="include/header.incl" %>
<%@ include file="include/validateFid.incl" %>
<form name="editorForm" id="editorForm"  action="annotationEditor.jsp" method="post"  >
    <input type="hidden"  name="vstate" id="vstate" value="<%=state%>">
    <input type="hidden"  name="vsub" id="vsub" value="1">
    <input type="hidden" name="cancelState" id="cancelState" value="0">

    <input type="hidden" name="avpvalues" id="avpvalues" value="">
    <input type="hidden" name="index" id="index" value="<%=currentIndex%>">

    <table width="100%" border="0" cellpadding="2" cellspacing="2">
    <TR>
    <TD>
    <BR>
    <div class="title4" align="center"><B>Editing This Annotation</B></div>
    <div align="center" id="successMsg" class="successMsg">
    <%=message%>
    </div>
    <div id="messageid" class="annotation1">
    <%
    if( vLog != null && vLog.size() > 0 ) {
    out.print( " <UL class=\"compact2\">" );
    for( i=0; i<vLog.size(); i++ ) {
    out.print( "<li> &middot; " + (String)vLog.elementAt(i) +"</li>" );  }
    out.println( "</ul>" );
    }
    %>
    </div><BR>
    <TABLE  width="100%" border="0" cellpadding="0" cellspacing="0">

    <TR align="center">
        <TD>
        <%@ include file="include/delimit.incl"%>
        </TD>
    </TR>

    <TR><TD>&nbsp;</TD></TR>
    <TR>
    <TD>
    <table width="100%" id="infoTable"  border="1" cellpadding="2" cellspacing="1">
    <TR>
    <%
    if ( errorFields.get("gname") != null) {  %>
    <TD class="annotation1" colspan="1">
    <div id="annoname" >  <B>Annotation&nbsp;Name</B> </div>
    </TD>
    <%
    errorFields.remove("gname");
    }
    else {
    %>
    <td class="annotation2" colspan="1"> <div id="annoname" > <B>Annotation&nbsp;Name</B></div>
    </td>
    <%} %>
    <TD class="annotation2" colspan="3">
    <input type="text" name="gname" id ="gname" class="largeInput"  maxlength="200" value="<%=Util.htmlQuote(annotation.getGname()) %>" onChange="setChanged(1);" >
    </TD>
    </TR>
    <TR id="trackRow">
    <TD ALIGN="left" class="annotation2" colspan="1">
    <div id="track"><B>Track</B></div>
    </TD>
    <TD class="annotation2" colspan="1">
    <select class="longDroplist" name="tracks" id="tracks" BGCOLOR="white" onchange="checkNewTrack(); setChanged(1);" >
    <%
    if (curColor!= null)
       curColor = curColor.replaceAll("#", "");
    for (int j=0; j<tracks.length; j++) {
    String sel = "";
    if (errorFields.get("newTrackRow") != null && (j==(tracks.length-1)))
    sel = " selected";
    else  if (tracks[j].compareTo(annotation.getTrackName()) ==0)
    sel = " selected";
    %>
    <option  value="<%=Util.htmlQuote(tracks[j])%>" <%=sel%>> <%=Util.htmlQuote(tracks[j])%>  </option>
    <%}%>
    </select>
    </TD>
    <TD ALIGN="left" class="annotation2" colspan="2">
    <a href="#wheellink"  name="wheellink" id="wheellink"  onClick="setChanged(1);">
    <div name="imageId" id="imageId"  class="colorIconLong"  style="background-color:<%=curColor%>"  onClick="setDivIdndfColor('imageId','hiddenInputId', '<%=curColor%>', 'isDefaultColor');">
    </div>
    <div  class="bottomdiv" onClick="setDivIdndfColor('imageId', 'hiddenInputId', '<%=curColor%>', 'isDefaultColor');">&nbsp;&nbsp;Set Annotation Color</div>
    </a>
    <input type="hidden" name="hiddenInputId" id="hiddenInputId" value="#<%=curColor%>" >
    <input type="hidden" name="isDefaultColor" id="isDefaultColor" value="<%=isDefaultColor%>" >
    </TD>
    </TR>
<%
if (errorFields.get("newTrackRow") != null) {
errorFields.remove("newTrackRow");
String typeValue = "";
String subtypeValue = "";
if (mys.getAttribute("duptype") != null)
typeValue = (String )mys.getAttribute("duptype")  ;
if (mys.getAttribute("dupsubtype") != null)
subtypeValue = (String )mys.getAttribute("dupsubtype")  ;
mys.removeAttribute("dutype");
mys.removeAttribute("dupsubtype");
%>
<TR id="newTrackRow"  style="track.style.display">
    <TD class="annotation2" id="newTypeLabel" style="color:red" >
        <B>Track&nbsp;Type</B>
    </TD>
    <TD class="annotation2" >
        <input type="text" class="longInput" maxlength="20" name="newType" id="newType" value="<%=Util.htmlQuote(typeValue)%>" onChange="setChanged(1);">
    </TD>
    <TD class="annotation2" id="newSubtypeLabel"  style="color:red">
        <B>Track&nbsp;Subtype</B>
    </TD>
    <TD class="annotation2" >
        <input type="text" class="longInput" maxlength="20" name="newsubtype" id="newsubtype"  value="<%=Util.htmlQuote(subtypeValue)%>"  onChange="setChanged(1);">
    </TD>
    <%}
    else {
    %>
<TR id="newTrackRow"  style="display:none">
    <TD class="annotation2" id="newTypeLabel" style="color:#403c59">
        <B>Track&nbsp;Type</B>
    </TD>
    <TD class="annotation2" >
        <input type="text" id="new_type" class="longInput" maxlength="20" name="new_type" onChange="setChanged(1);" >
    </TD>
    <TD class="annotation2" id="newSubtypeLabel"  style="color:#403c59">
        <B>Track&nbsp;Subtype</B>
    </TD>
    <TD class="annotation2" >
        <input type="text" id="new_subtype"  class="longInput" maxlength="20" name="new_subtype"  onChange="setChanged(1);">
    </TD>
    <% } %>
</TR>
<TR>
    <%
    if (chromosomes != null && chromosomes.length >0 && chromosomes.length <=org.genboree.util.Constants.GB_MAX_FREF_FOR_DROPLIST ) {  %>
    <TD ALIGN="left" class="annotation2" colspan="1"><div id="ch1"><B>Chromosome</B></div>
    </TD>
    <TD class="annotation2" colspan="1">
        <select name="chromosomes" id="chromosomes"  class="longDroplist" BGCOLOR="white"  onChange="setChanged(1);" >
        <%
        for (int j=0; j<chromosomes.length; j++) {
        String sel = "";
        if (chromosomes[j].compareTo(annotation.getChromosome()) ==0)  {
        sel = " selected";
        chromosome = (Chromosome)chromosomeMap.get(chromosomes[j]);
        }
        %>
        <option value="<%=chromosomes[j]%>"<%=sel%>><%=chromosomes[j]%></option>
        <%}%>
        </select>
        </TD>
    <%
    }
    else if (chromosomes != null && (chromosomes.length > org.genboree.util.Constants.GB_MAX_FREF_FOR_DROPLIST )  && (errorFields.get("chromosome")==null) ){
    %>
    <TD ALIGN="left" class="annotation2" colspan="1"><div id="ch2"><B>Chromosome</B></div>
    </TD>
    <TD class="annotation2" colspan="">
        <input type="text"  name="chromosomes"  id="chromosomes" class="longInput" value="<%=annotation.getChromosome()%>">
    </TD>
    <% }
    else if (chromosomes != null && (chromosomes.length > org.genboree.util.Constants.GB_MAX_FREF_FOR_DROPLIST ) && (errorFields.get("chromosome")!=null) )  {
    %>
    <TD ALIGN="left" class="annotation1" colspan="1"><B>Chromosome</B>
    </TD>
    <TD class="annotation2" colspan="1">
        <input type="text"   name="chromosomes" id="chromosomes"  class="longInput" value="<%=annotation.getChromosome()%>" onChange="setChanged(1);">
    </TD>
    <%
    // errorFields.remove("chromosome");
    }
    else {
    %>
     <TD ALIGN="left" class="annotation2" colspan="1"><div id="ch0"><B>Chromosome<B></div>
    </TD>
    <TD class="annotation2" colspan="1">
        <input type="text" name="chromosomes" id="chromosomes" class="longInput" value="<%=annotation.getChromosome()%>" onChange="setChanged(1);">
    </TD>
    <% } %>
    <TD ALIGN="left" class="annotation2" colspan="2">&nbsp;</TD>
</TR>
<TR align="center">
    <% if (errorFields.get("start")!=null) { %>
    <TD ALIGN="left" class="annotation1" colspan="1"><div id="startLabel"><B>Start</B></div>

    </TD>
    <TD class="annotation2" colspan="1">
        <input type="text" class="longInput" maxlength="50"  name="startValue" id="startValue"  value="<%=annotation.getFstart()%>"  onChange="setChanged(1);">
    </TD>
    <%
    errorFields.remove("start");
    }
    else { %>
    <TD  ALIGN="left"class="annotation2" colspan="1"><div id="startLabel"><B>Start</B></div></TD>
    <TD ALIGN="left" class="annotation2" colspan="1">
        <input type="text"  class="longInput" name="startValue" id="startValue" maxlength="50" value= "<%=annotation.getFstart()%>" onChange="setChanged(1);">
    </TD>
    <% } %>
    <% if (errorFields.get("stop")!=null ) {%>
    <TD ALIGN="left" class="annotation1" colspan="1"><div id="stopLabel"><B>Stop</B></div></TD>
    <TD class="annotation2" BGCOLOR="white" colspan="1">
        <input type="text" class="longInput" name="stopValue" id="stopValue" minLength="20" maxlength="50" value="<%=annotation.getFstop()%>" onChange="setChanged(1);">
    </TD>
    <% errorFields.remove("stop");
    } else {
    %>
    <TD ALIGN="left" class="annotation2" colspan="1"><div id="stopLabel"><B>Stop</B></div></TD>
    <TD class="annotation2" BGCOLOR="white" colspan="1">
        <input type="text" class="longInput" name="stopValue" id="stopValue"  minLength="20"  maxlength="50"  value="<%=annotation.getFstop()%>" onChange="setChanged(1);">
    </TD>
    <%}%>
</TR>
<TR>
    <% if (errorFields.get("tstart") == null) { %>
    <TD ALIGN="left" class="annotation2" colspan="1"><div id="qstartLabel"><B>Query&nbsp;Start</B></div>
    </TD>
    <TD class="annotation2" colspan="1">
        <input name="qstart" id="qstart" type="text" BGCOLOR="white" class="longInput" maxlength="50" value="<%=annotation.getTstart()%>" onChange="setChanged(1);">
    </TD>
    <%  } else {    %>
    <TD ALIGN="left" class="annotation1" colspan="1"><div id="qstartLabel"><B>Query&nbsp;Start</B></div>
    </TD>
    <TD class="annotation2" colspan="1">
        <input name="qstart" id = "qstart" type="text" BGCOLOR="white" class="longInput" maxlength="50" value="<%=annotation.getTstart()%>" onChange="setChanged(1);">
    </TD>
    <% } %>
    <%   if (errorFields.get("tstop") == null) {  %>
    <TD ALIGN="left" class="annotation2" colspan="1"><div id="qstopLabel"><B>Query&nbsp;Stop</B></div>
    </TD>
    <!-- Target Stop -->
    <TD class="annotation2" colspan="1">
        <input type="text"  name="qstop" id="qstop" BGCOLOR="white" class="longInput" maxlength="50" value="<%=annotation.getTstop()%>" onChange="setChanged(1);">
    </TD>
    <% }
    else{%>
    <TD ALIGN="left" class="annotation1" colspan="1"><div id="qstopLabel"><B>Query&nbsp;Stop</B></div></TD>
    <!-- Target Stop -->
    <TD class="annotation2" colspan="1">
        <input type="text"  name="qstop" id="qstop" BGCOLOR="white" class="longInput" maxlength="50" value="<%=annotation.getTstop()%>" onChange="setChanged(1);">
    </TD>
    <%}%>
</TR>
<TR>
    <TD ALIGN="left" class="annotation2" colspan="1"><div><strand><B>Strand</B></div></TD>
    <TD class="annotation2" colspan="1">
        <select name="strand" class="longDroplist" id="strand" align="left" BGCOLOR="white" onChange="setChanged(1);">
        <%
        String [] strands = new String [] {"+", "-"} ;
        for (int j=0; j<2; j++) {
        String sel = "";
        if (strands[j].compareTo(annotation.getStrand()) ==0) {
        sel = " selected";
        }
        %>
        <option  value="<%=strands[j]%>" <%=sel%>> <%=strands[j]%>  </option>
        <%}%>
        </select>
    </TD>
    <TD ALIGN="left" class="annotation2" colspan="1"><div id="phase"><B>Phase</B></div>
    </TD>
    <TD ALIGN="left" class="annotation2" colspan="1">
        <select  class="longDroplist" align="left" name="phase"  id="phase" onChange="setChanged(1);" >
        <%
        String [] phases = new String [] {"0", "1", "2"} ;
        for (int  j=0; j<phases.length; j++) {
        String sel = "";
        if (annotation.getPhase() != null){
        if (phases[j].compareTo(annotation.getPhase())==0)
        sel = " selected";
        }
        else {
        if (j==0)
        sel = " selected";
        }
        %>
        <option  value="<%=phases[j]%>" <%=sel%>><%= phases[j]%></option>
        <%
        }
        %>
        </select>
    </TD>
</TR>
    <TR>
        <%if (errorFields.get("score") == null) { %>
        <TD ALIGN="left" class="annotation2" colspan="1"><div id="scoreLabel"><B>Score</B></div></TD>                                                     			<!-- SCORE -->
        <TD ALIGN="left" class="annotation2" colspan="1">
        <input type="text" class="longInput" name="score" id="score" maxlength="50" value="<%=annotation.getFscore()%>" onChange="setChanged(1);">
        </TD>
        <%   } else { %>
        <TD ALIGN="left" class="annotation1" colspan="1"><div id="scoreLabel"><B>Score</B></div></TD>                                                     			<!-- SCORE -->
        <TD class="annotation2">
        <input type="text" class="longInput" name="score" id="score"  maxlength="50" value="<%=annotation.getFscore()%>" onChange="setChanged(1);">
        </TD>
        <% }
        %>
        <TD ALIGN="left" class="annotation2" colspan="2">&nbsp;</TD>
    </TR>

<%@ include file="include/avp.incl" %>

    <TR>
    <%if (errorFields.get("comments") != null) { %>
    <TD ALIGN="left" class="annotation1" colspan="1"><div id="labelcomment"><B>Free-Form Comment</B></div></TD>
    <%
    }
    else {
    %>
    <TD ALIGN="left" colspan="1" class="annotation2"><div id="labelcomment"><B>Free-Form Comment</B></div></TD>
    <%
    }
    %>
    <TD align="left" class="annotation2" colspan="3">
    <TEXTAREA name="comments" id="comments"  align="left" rows="4" class="largeTextarea" onChange="setChanged(1);"><%=annotation.getComments()%></TEXTAREA>
    </TD>
    </TR>

    <TR>
    <%if ( errorFields.get("sequence") != null) { %>
    <TD ALIGN="left" class="annotation1" colspan="1"><div id="sequences"><B>Sequence</B></div></TD>
    <%    }
    else {
    %>
    <TD ALIGN="left" colspan="1" class="annotation2"><div id="sequences"><B>Sequence</B></div></TD>
    <% } %>
    <TD align="left" class="annotation2" colspan="3">
      <TEXTAREA name="sequence" id="sequence" align="left" rows="4" class="largeTextarea" onChange="setChanged(1);"><%=annotation.getSequences()%></TEXTAREA>
    </TD>
    </TR>
</TABLE>
</TD>
</TR>
<table align="left" width="50%" border="0" cellpadding="2" cellspacing="10" >
<p align="center">
<tr align="center"  class="form_body">  <br>     &nbsp;&nbsp;
<nobr>
<input  type="button"  class="btn"   name="doSelected"  id="doSelected"  value=" Update "   width="120" HEIGHT="110" onClick="getAVPValues('avpvalues'); processSubmit(); " > &nbsp;
<input  type="Submit" class="btn"  name="btnReset" id="btnReset"  value="  Reset  "  onClick="resetForm()">&nbsp; &nbsp;
<% if (!saved) { %>
<input type="button" name="btnClose" id="btnClose" value="Cancel"  class="btn"  onClick="processQuit('<%=aval%>', '<%=aid%>', <%=false%>);" >
<% }
else {  %>
  <input type="button" name="btnClose" id="btnClose" value="Close Window"  class="btn"  onClick="processQuit('<%=aval%>', '<%=aid%>', <%=true%>);" >
<%}%>
</nobr>
</tr>
</p>
</table>
<TD>
</table>
</form>
<%@ include file="include/invalidFidMsg.incl"%>
<%@ include file="include/footer.incl" %>
</BODY>
<%
  if(refreshGbrowser)
  {
    refreshGbrowser = false;
%>
    <script language="javascript" type="text/javascript">
      confirmRefresh() ;
    </script>
<%
  }
%>
</HTML>
