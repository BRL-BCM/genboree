<%@ page import="java.text.NumberFormat,
java.text.DecimalFormat,
java.io.InputStream,
java.util.*,
java.util.regex.Pattern,
java.util.regex.Matcher,
java.lang.reflect.Array,
java.sql.*,
org.genboree.util.*,
org.genboree.editor.AnnotationEditorHelper,
org.genboree.editor.Chromosome"
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
    Vector vannos = new Vector();

    HashMap name2Values = new HashMap ();
    int currentIndex = 0;
    String lastGname =  null;
    String className = null;
    boolean isTemplate = false;
    int counter = 0;
    String currentCount = request.getParameter("counter");
    boolean isRefresh = false;
    if (currentCount != null)
    counter = Integer.parseInt(currentCount);
    else
    mys.removeAttribute("lastCount");
    String lastCount = null;
    if (mys.getAttribute("lastCount")!= null)
    lastCount = (String)mys.getAttribute("lastCount");
    if (lastCount != null && currentCount != null && currentCount.compareTo (lastCount) == 0)
    isRefresh = true;
    mys.setAttribute("lastCount", currentCount);
    String []  chromosomes = new String [] {""};
    ArrayList  chromosomeList = new ArrayList();
    String [] tracks = new String [] {""};
    HashMap errorFields = new HashMap ();
    boolean refreshGbrowser  = false;
    int i = 0;
    AnnotationDetail annotation = new AnnotationDetail(ifid);
    int db2jsp  = 0;
    int jsp2db = 1;
    Connection con =  db.getConnection(dbName);
    if (con == null || con.isClosed())
    GenboreeUtils.sendRedirect(request,response, destback);
    int genboreeUserId = Util.parseInt(myself.getUserId(), -1);
  
    annotation = AnnotationEditorHelper.findAnnotation (annotation, db, con, fid );
    if (annotation == null && annotation.getGname() == null || annotation.getGname().compareTo("") == 0 )
    {
      GenboreeUtils.sendRedirect(request,response, "/java-bin/error.jsp");
      return;
    }
    AnnotationDetail  annotationDB = annotation;
    annotation = AnnotationEditorHelper.convertAnnotation(annotation, db2jsp);

    if (request.getParameter("upfid") != null) {
       // vannos = new Vector();
        mys.removeAttribute("lastAnnos");
        mys.removeAttribute("dutype");
        mys.removeAttribute("dupsubtype");
        className = annotation.getGname();
        lastGname  = annotation.getGname();
        mys.removeAttribute("lastGname"); mys.setAttribute("lastGname", annotation.getGname());
        mys.setAttribute("className", annotation.getGname());
        mys.setAttribute("isTemplate", new Boolean(true));
        mys.setAttribute("lastFid", fid);
        isTemplate = true;
    }
   else {
        if (mys.getAttribute("lastAnnos")!= null)
        vannos =  (Vector) mys.getAttribute("lastAnnos");
        if (mys.getAttribute("className")!= null)
        className = (String)mys.getAttribute("className");
        if (mys.getAttribute("lastGname")!= null)
        lastGname = (String)mys.getAttribute("lastGname");
        if (mys.getAttribute("isTemplate")!= null)
       isTemplate = ((Boolean)mys.getAttribute("isTemplate")).booleanValue();
      //    name2Values = (HashMap)mys.getAttribute("name2Values");
       fid =  (String) mys.getAttribute("lastFid");
    }
    con =  db.getConnection(dbName);

    if (con == null || con.isClosed())
      GenboreeUtils.sendRedirect(request,response, destback);

    HashMap trackMap = null;
    trackMap =AnnotationEditorHelper.findTracks (db, con, genboreeUserId, dbName);

    HashMap chromosomeMap = null;
    try {
    chromosomeMap = AnnotationEditorHelper.findChromosomes (db, con);
    }
    catch (SQLException e) {
    e.printStackTrace();
    GenboreeUtils.sendRedirect(request,response,  "/java-bin/error.jsp");
    }
    Chromosome chromosome = (Chromosome)chromosomeMap.get(annotation.getChromosome());
    String message = "";
    if (trackMap != null && trackMap.size() > 0) {
        Iterator iterator = trackMap.keySet().iterator();
        int count = 0;
        tracks = new String [trackMap.size()];
        while (iterator.hasNext()) {
            tracks[count] = (String) iterator.next();
            count++;
        }
    }
    else
          GenboreeUtils.sendRedirect(request,response, "/java-bin/error.jsp");
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
    if (chromosomeMap != null && !chromosomeMap.isEmpty()) {
    chromosomes =  (String[])chromosomeMap.keySet().toArray(new String[chromosomeMap.size()]);
    }
    else
    GenboreeUtils.sendRedirect(request,response, "/java-bin/error.jsp");
    Arrays.sort(chromosomes);
    if (chromosomes != null && chromosomes.length >0)
    {
    for (i=0; i<chromosomes.length; i++)
    {
    chromosomeList.add(chromosomes[i]);
    }
    }
    int newid = 0;
    AnnotationDetail dbAnno = new AnnotationDetail (ifid);
    dbAnno = AnnotationEditorHelper.copy(annotation, dbAnno);
    boolean success = false;
    String vStatus = "0";
    if (request.getParameter("upfid")!= null){
    vannos.add(0, annotation);
    mys.setAttribute("lastAnnos", vannos);
    }
    if (!isRefresh) {
    if (request.getParameter("doSelected") != null) {
    if ((request.getParameter("vstate")) != null) {
    vStatus = request.getParameter("vstate");
    if  (vStatus.compareTo("1")==0)   {
    vStatus = "0";
    //request.setAttribute("okCreate", "0");
    if (AnnotationEditorHelper.validateForm (annotation, trackMap, mys, request,  errorFields,  vLog,  chromosomeMap, out, upload.getDatabaseName(), con))  {
    String  fbin = (Refseq.computeBin(annotation.getStart(), annotation.getStop(), 1000));
    annotation.setFbin(fbin);
    boolean isDup =AnnotationEditorHelper.isDupAnno (dbName, annotation, con);
    if (!AnnotationEditorHelper.compareAnnos(annotation, dbAnno)  && !isDup) {
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
    newid = AnnotationEditorHelper.insertAnnotation(anno, dbName, con);
    if (newid > 0) {
    try {
    success = AnnotationEditorHelper.insertText(newid, annotation,db, dbName, con, out) ;
            int [] arr = new int [] { newid};
                AnnotationEditorHelper.updateFeature2AVPName(anno.getFtypeId(), arr, con);
        }
    catch (SQLException e) {
    out.println (e.getMessage());
    }
    mys.setAttribute("lastFid", ""+newid);
    fid ="" +  newid;
    annotation.setFid(newid);

    String avpValues = request.getParameter("avpvalues");
    if (avpValues != null) {
    String testStr = "";
    HashMap avp = new HashMap ();
    StringTokenizer st = new StringTokenizer(avpValues, "]");
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
    ArrayList list = new ArrayList();
    list.add(value);
    avp.put(name,list)  ;
    testStr = testStr + name + "=" +value + "; ";
    }
    GenboreeUtils.addValuePairs(con,  ""+upload.getRefSeqId(), newid, annotation.getFtypeId(), avp , 0);
    success = true;
    };
    //}
    }
    if (success) {
    // counter++;
    con =  db.getConnection(dbName);
    if (con == null || con.isClosed()) {
    out.println ("con is null");
    GenboreeUtils.sendRedirect(request,response, "/java-bin/error.jsp");
    return;
    }
    AnnotationDetail newAnnotation =  AnnotationEditorHelper.findAnnotation (annotation, db, con, "" + newid );
    if (newAnnotation == null)  {
    GenboreeUtils.sendRedirect(request,response, "/java-bin/error.jsp");
    return;
    }
    if (isTemplate)
    vannos = new Vector();
    isTemplate = false;
    vannos.add(0, newAnnotation);
    lastGname =  newAnnotation.getGname();
    mys.removeAttribute("lastTextID");
    mys.setAttribute("lastTextID", uploadId + ":" + newid);
    mys.removeAttribute("lastAnnos");
    mys.setAttribute("lastAnnos", vannos);
    mys.setAttribute("lastGname", newAnnotation.getGname());
    mys.setAttribute( "isTemplate", new Boolean(false));
    message = "<BR>Successfuly created annotation";
    annotation = AnnotationEditorHelper.convertAnnotation(newAnnotation, db2jsp);
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
    refreshGbrowser = true;
    }
    }
    else {
    boolean qstartSame = false;
    boolean qstopSame = false;
    boolean commentSame = false;
    boolean seqSame = false;
    if (annotation.getComments() != null && (annotation.getComments()).compareTo(dbAnno.getComments()) ==0)
    commentSame = true;
    if (annotation.getSequences() != null && annotation.getSequences().compareTo(dbAnno.getSequences()) ==0)
    seqSame = true;
    if (annotation.getTstart() != null && annotation.getTstart().compareTo(dbAnno.getTstart()) ==0)
    qstartSame  = true;
    if (annotation.getTstop()!= null && annotation.getTstop().compareTo(dbAnno.getTstop()) ==0)
    qstopSame  = true;
    String fieldNames = "";
    boolean ischanged = false;
    if (!commentSame) {fieldNames = "comment,";
    ischanged = true;};
    if (!seqSame) {fieldNames = fieldNames + " sequence, "; ischanged = true;};
    if (!qstartSame) {fieldNames = fieldNames + " query start, "; ischanged = true;};
    if (!qstopSame) {fieldNames = fieldNames + " query stop,"; ischanged = true;};
    int commaindex = fieldNames.lastIndexOf(",");
    if (fieldNames.compareTo("")!= 0) {
    fieldNames = fieldNames.substring(0, commaindex);
    commaindex = fieldNames.lastIndexOf(",");
    if (commaindex>0) {
    String tail = fieldNames.substring(commaindex +1) ;
    fieldNames = fieldNames.substring(0, commaindex) + ", and " + tail;
    }

    String  id = fid;
    if (newid != 0)
    id = "" +  newid;
    String warn = "<B>WARN</B>: This annotation is exactly the same as the original and differs only by "
    +    fieldNames
    +  " </font><font color=\"black\"><li>&nbsp;&nbsp;- If you wish to add or replace " +
    fieldNames + " for the original annotation, "
    +  " please use the <a  class=\"invisiLink\" href=\"annotationEditor.jsp?upfid=" + uploadId + ":" + id
    + "\"><B><i>EDIT</i></B></a> tool. "
    +  "<li>&nbsp;&nbsp;- Otherwise, please  make the annotation different from the original by "
    +  " changing the name, coordinates, or other fundamental data marked in red." ;

    vLog.add (warn);
    }
    else {
    vLog.add ("<B>WARN</B>: This annotation is exactly the same as the original. " +
    "<br></font><font color=\"black\"><li>&nbsp;&nbsp;-Please  make the annotation different from the original by "
    +  " changing the name, coordinates, or other fundamental data marked in red." );
    }
    // mys.setAttribute("dup", "1");
    // vLog.add ("Annotation exists. Please modify any of the fields marked with red before resubmitting.");
    errorFields.put("gname", "y");
    errorFields.put("track", "y");
    errorFields.put("start", "y");
    errorFields.put("stop", "y");
    errorFields.put("phase", "y");
    errorFields.put("chromosome", "y");
    errorFields.put("strand", "y");
    errorFields.put("score", "y");
    }
    }
    }
    }
    }
    else {
    errorFields = new HashMap();
    }
    }
    String validationStatus = null;
    if (request.getParameter("btnReset") != null) {
    if ((validationStatus = request.getParameter("vstatus")) != null  && validationStatus.compareTo("1")==0) {
    annotation = annotationDB;
    vLog.clear();
    }
    }
    String validateForm = " return validateForm(" + annotation.getGname() + ");";
    if (request.getParameter("btnCancel") != null) {
    GenboreeUtils.sendRedirect(request,response, destback);
    return;
    }
    %>
    <%@ include file="include/avpPopulator.incl" %>
    <%@ include file="include/saved.incl" %>
    <HTML>
    <head>
    <title>Genboree - Show Annotation Text and Sequence</title>
    <link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
    <link rel="stylesheet" href="/styles/annotationEditor.css<%=jsVersion%>" type="text/css">
    <link rel="stylesheet" href="/styles/avp.css<%=jsVersion%>" type="text/css">
    <LINK rel="stylesheet" href="/styles/querytool.css<%=jsVersion%>" type="text/css">
    <meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
    <SCRIPT TYPE="text/javascript" SRC="/javaScripts/create.js<%=jsVersion%>"></SCRIPT>
    <SCRIPT TYPE="text/javascript" SRC="/javaScripts/delimitComments.js<%=jsVersion%>"></SCRIPT>
    <script type="text/javascript" src="/javaScripts/editorCommon.js<%=jsVersion%>"></script>
    <script  type="text/javascript"  src="/javaScripts/prototype.js<%=jsVersion%>"></script>
    <SCRIPT type="text/javascript" src="/javaScripts/json.js<%=jsVersion%>"></SCRIPT>
    <script src="/javaScripts/commonFunctions.js<%=jsVersion%>" type="text/javascript"></script>
    <script src="/javaScripts/attributeValuePairs.js<%=jsVersion%>"  defer="true" type="text/javascript"></script>
    </head>
    <BODY onUnload="resetCounter('counter');">
    <%@ include file="include/header.incl" %>
    <%@ include file="include/validateFid.incl" %>
    <form name="editorForm" id="editorForm"  action="createAnnotation.jsp"  method="post"  onsubmit="return validateForm();">
    <input type="hidden"  name="counter" id="counter" value="<%=counter%>" >
    <input type="hidden"  name="vstate" id="vstate" value="<%=vStatus%>">
    <input type="hidden"  name="lastGname" id="lastGname" value="<%=lastGname%>">
    <input type="hidden"  name="className" id="className" value="<%=className%>">
    <input type="hidden"  name="vsub" id="vsub" value="0">
    <input type="hidden" name="cancelState" id="cancelState" value="0">
    <input type="hidden" name="changed" id="changed" value="<%=changed%>">

    <input type="hidden" name="avpvalues" id="avpvalues" value="">
    <input type="hidden" name="index" id="index" value="<%=currentIndex%>">

    <BR>
    <table width="100%" border="0" cellpadding="2" cellspacing="2">
    <tr>
    <td>
    <div  align="center" class="title4">Create Annotation </div>
    <div align="center" >   <font size="2">
    <B>(Based&nbsp;on&nbsp; the&nbsp; annotation&nbsp; you&nbsp; selected &nbsp;from&nbsp; group "<I><%=Util.htmlQuote(lastGname)%></I>")</B>
    </font>
    </div>
    <div id="messageid" class="successMsg" align="center" >
    <% if (success) {  %>   <%=message%>   <%}%>
    </div>
    <div class="annotation1"  id="errorMsgid">
    <%
    if( vLog != null && vLog.size() > 0 ) {
    out.print( " <UL class=\"compact2\">" );
    for( i=0; i<vLog.size(); i++ ) {
    out.print( "<li> &middot; " + (String)vLog.elementAt(i) +"</li>" );  }
    out.println( "</ul>" );
    }
    %>
    </div>
    <BR>
    <table  width="100%" border="0" cellpadding="0" cellspacing="0">

    <TR><TD>&nbsp;</TD></TR>
    <TR>
    <TD>
    <TABLE width="100%" id="infoTable"  border="1" cellpadding="2" cellspacing="1">
    <TR>
    <%
    if ( errorFields.get("gname") != null) {  %>
    <TD class="annotation1" colspan="1">
    <div id="annoname" >  <B>Annotation&nbsp;Name</B></div> </TD>
    <%
    errorFields.remove("gname");
    }
    else {
    %>
    <TD class="annotation2" colspan="1"> <div id="annoname" > <B>Annotation&nbsp;Name</B></div> </td>
    <%} %>
    <TD class="annotation2" colspan="3">
        <input type="text" name="gname" id ="gname" class="largeInput"  maxlength="200"  onChange="setChanged(1);" value="<%=Util.htmlQuote(annotation.getGname()) %>" >
    </TD>
    </TR>
    <TR id="trackRow">
    <% if (errorFields.get("track") == null) { %>
    <TD ALIGN="left" class="annotation2" colspan="1">
        <div id="track"><B>Track</B></div></TD>
     <% } else {
        errorFields.remove("track");
    %>
         <TD ALIGN="left" class="annotation1" colspan="1">
        <div id="track"><B>Track</B></div></TD>
      <%}%>
    <TD class="annotation2" colspan="1">
        <select class="longDroplist" name="tracks" id="tracks" BGCOLOR="white" onchange="checkNewTrack(); setChanged(1);" >
        <%
        for (int j=0; j<tracks.length; j++) {
        String sel = "";
        if (errorFields.get("newTrackRow") != null && (j==(tracks.length-1)))
        sel = " selected";
        else  if (tracks[j].compareTo(annotation.getTrackName()) ==0)
        sel = " selected";
        %>
        <option  value="<%=tracks[j]%>" <%=sel%>> <%=tracks[j]%>  </option>
        <%}%>
        </select>
    </TD>
    <TD ALIGN="left" class="annotation2" colspan="2">&nbsp;</TD>
    </TR>
        <%
        if (errorFields.get("newTrackRow") != null) {
        errorFields.remove("newTrackRow");
        String typeValue = "";
        String subtypeValue = "";
        %>
        <TR id="newTrackRow"  style="track.style.display">
        <TD class="annotation2" id="newTypeLabel" style="color:red" >
        <B>Track&nbsp;Type</B>
        </TD>
        <TD class="annotation2" >
        <input type="text" class="longInput" maxlength="20" name="newType" id="newType" value = "<%=typeValue%>" onChange="setChanged(1);"  >
        </TD>

        <TD class="annotation2" id="newSubtypeLabel"  style="color:red">
        <B>Track&nbsp;Subtype</B>
        </TD>
        <TD class="annotation2" >
        <input type="text" class="longInput" maxlength="20" name="newsubtype" id="newsubtype"   onChange="setChanged(1);"  value="<%=subtypeValue%>">
        </TD>
        <%}
        else {
        %>
        <TR id="newTrackRow"  style="display:none">
        <TD class="annotation2" id="newTypeLabel" style="color:#403c59">
        <B>Track&nbsp;Type</B>
        </TD>
        <TD class="annotation2" >
        <input type="text" id="new_type" class="longInput" maxlength="20" name="new_type"  onChange="setChanged(1);"  >
        </TD>
        <TD class="annotation2" id="newSubtypeLabel"  style="color:#403c59">
        <B>Track&nbsp;Subtype</B>
        </TD>
        <TD class="annotation2" >
        <input type="text" id="new_subtype"  class="longInput" maxlength="20" name="new_subtype"  onChange="setChanged(1);"  >
        </TD>
        <% } %>
        </TR>
        <TR>
        <%
        if (chromosomes != null && chromosomes.length >0 && chromosomes.length <=org.genboree.util.Constants.GB_MAX_FREF_FOR_DROPLIST ) {  %>
         <% if (errorFields.get("chromosome")==null) { %>
        <TD ALIGN="left" class="annotation2" colspan="1"><div id="ch1"><B>Chromosome</B></div></TD>
         <% } else {
         errorFields.remove("chromosome");
         %>
         <TD ALIGN="left" class="annotation1" colspan="1"><div id="ch1"><B>Chromosome<B></div></TD>
         <%}%>
        <TD class="annotation2" colspan="1">
        <select name="chromosomes" id="chromosomes"  class="longDroplist" BGCOLOR="white"   onChange="setChanged(1);"  >
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
        <%
        }
        else if (chromosomes != null && (chromosomes.length > org.genboree.util.Constants.GB_MAX_FREF_FOR_DROPLIST )  && (errorFields.get("chromosome")==null) ){
        %>
        <TD ALIGN="left" class="annotation2" colspan="1"><div id="ch2"><B>Chromosome</B></div></TD>
        <TD class="annotation2" colspan="">
        <input type="text"  name="chromosomes"  id="chromosomes" class="longInput"  onChange="setChanged(1);"  value="<%=annotation.getChromosome()%>">
        <% }
        else if (chromosomes != null && (chromosomes.length > org.genboree.util.Constants.GB_MAX_FREF_FOR_DROPLIST ) && (errorFields.get("chromosome")!=null) )  {
        %>
    <TD ALIGN="left" class="annotation1" colspan="1"><B>Chromosome</B></TD>
    <TD class="annotation2" colspan="1">
    <input type="text"   name="chromosomes" id="chromosomes"  class="longInput"  onChange="setChanged(1);"  value="<%=annotation.getChromosome()%>">
    <%
    // errorFields.remove("chromosome");
    }
    else {
    %>
    <!-- if no entry point name in db, make an empty field  -->
    <TD ALIGN="left" class="annotation2" colspan="1"><div id="ch0"><B>Chromosome<B></div></TD>
    <TD class="annotation2" colspan="1">
    <input type="text" name="chromosomes" id="chromosomes" class="longInput"  onChange="setChanged(1);"  value="" >
    <% }
    %>
    </TD>
    <TD ALIGN="left" class="annotation2" colspan="2">&nbsp;</TD>
    </TR>
    <TR align="center">
    <% if (errorFields.get("start")!=null) { %>
    <TD ALIGN="left" class="annotation1" colspan="1"><div id="startLabel"><B>Start</B></div></TD>
    <TD class="annotation2" colspan="1">
    <input type="text" class="longInput" maxlength="50"  name="startValue" id="startValue"   onChange="setChanged(1);" value="<%=annotation.getFstart()%>"  >
    </TD>
    <%
    errorFields.remove("start");
    }
    else { %>
    <TD  ALIGN="left"class="annotation2" colspan="1"><div id="startLabel"><B>Start<B></div></TD>
    <TD ALIGN="left" class="annotation2" colspan="1">
    <input type="text"  class="longInput" name="startValue" id="startValue" maxlength="50"  onChange="setChanged(1);" value= "<%=annotation.getFstart()%>" >
    </TD>
    <% } %>
    <% if (errorFields.get("stop")!=null ) {%>
    <TD ALIGN="left" class="annotation1" colspan="1"><div id="stopLabel"><B>Stop<B></div></TD>
    <TD class="annotation2" BGCOLOR="white" colspan="1">
    <input type="text" class="longInput" name="stopValue" id="stopValue" minLength="20" maxlength="50"  onChange="setChanged(1);" value="<%=annotation.getFstop()%>" >
    </TD>
    <% errorFields.remove("stop");
    } else {
    %>
    <TD ALIGN="left" class="annotation2" colspan="1"><div id="stopLabel"><B>Stop<B></div></TD>
    <TD class="annotation2" BGCOLOR="white" colspan="1">
    <input type="text" class="longInput" name="stopValue" id="stopValue"  minLength="20"  maxlength="50"   onChange="setChanged(1);" value="<%=annotation.getFstop()%>" >
    </TD>
    <%}%>
    </TR>
    <TR>
    <%  String tempQstart = annotation.getTstart();
    String tempQstop = annotation.getTstop();
    if (tempQstart == null)
    tempQstart = "n/a";
    if (tempQstop == null)
    tempQstop = "n/a";
    if (errorFields.get("tstart") == null) { %>
    <TD ALIGN="left" class="annotation2" colspan="1"><div id="qstartLabel"><B>Query&nbsp;Start</B></div></TD>
    <!-- Target Start -->
    <TD class="annotation2" colspan="1">
    <input name="qstart" id = "qstart" type="text" BGCOLOR="white" class="longInput" maxlength="50"  onChange="setChanged(1);" value="<%=tempQstart%>" >
    </TD>
    <%  } else {    %>
    <TD ALIGN="left" class="annotation1" colspan="1"><div id="qstartLabel"><B>Query&nbsp;Start</B></div></TD>
    <!-- Target Start -->
    <TD class="annotation2" colspan="1">
    <input name="qstart" id = "qstart" type="text" BGCOLOR="white" class="longInput" maxlength="50"  onChange="setChanged(1);" value="<%=tempQstart%>" >
    </TD>
    <% } %>
    <%   if (errorFields.get("tstop") == null) {  %>
    <TD ALIGN="left" class="annotation2" colspan="1"><div id="qstopLabel"><B>Query&nbsp;Stop</B></div></TD>
    <!-- Target Stop -->
    <TD class="annotation2" colspan="1">
    <input type="text"  name="qstop" id="qstop" BGCOLOR="white" class="longInput" maxlength="50"  onChange="setChanged(1);" value="<%=tempQstop%>">
    </TD>
    <% }
    else{%>
    <TD ALIGN="left" class="annotation1" colspan="1"><div id="qstopLabel"><B>Query&nbsp;Stop</B></div></TD>
    <TD class="annotation2" colspan="1">
    <input type="text"  name="qstop" id="qstop" BGCOLOR="white" class="longInput" maxlength="50"  onChange="setChanged(1);"  value="<%=tempQstop%>">
    </TD>
    <%}%>
    </TR>
    <TR> <% if (errorFields.get("strand")== null) {%>
    <TD ALIGN="left" id="strandLabel" name="strandLabel" class="annotation2" colspan="1"><strand><B>Strand</B></td>
    <%} else {
    errorFields.remove("strand");
    %>
    <TD ALIGN="left" id="strandLabel" name="strandLabel"  class="annotation1" colspan="1"><strand><B>Strand</B></td>
    <%}%>
    <TD class="annotation2" colspan="1">
    <select name="strand" class="longDroplist" id="strand" align="left" BGCOLOR="white" onChange="setChanged(1);" >
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
    <% if (errorFields.get("phase")== null) {%>
    <TD ALIGN="left" name="phaseLabel" id="phaseLabel" class="annotation2" colspan="1"><B>Phase</B></TD>
    <%} else {
    errorFields.remove("phase");
    %>
    <TD ALIGN="left" name="phaseLabel" id="phaseLabel" class="annotation1" colspan="1"><B>Phase</B></TD>
    <%}%>
    <TD ALIGN="left" class="annotation2" colspan="1">
    <select  class="longDroplist" align="left" name="phase"  id="phase"  onChange="setChanged(1);" >
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
<% } %>
</select>
</TD>
</TR>
<TR>
<%if (errorFields.get("score") == null) { %>
<TD ALIGN="left" class="annotation2" colspan="1"><div id="scoreLabel"><B>Score</B></div></TD>                                                     			<!-- SCORE -->
<TD ALIGN="left" class="annotation2" colspan="1">
<input type="text" class="longInput" name="score" id="score"  maxlength="50"  onChange="setChanged(1);" value="<%=annotation.getFscore()%>">
</TD>
<%   } else { %>
<TD ALIGN="left" class="annotation1" colspan="1"><div id="scoreLabel"><B>Score</B></div></TD>                                                     			<!-- SCORE -->
<TD class="annotation2">
<input type="text" class="longInput" name="score" id="score" BGCOLOR="white" maxlength="50" onChange="setChanged(1);"  value="<%=annotation.getFscore()%>">
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
<TEXTAREA name="comments" id="comments"  align="left" rows="4" class="largeTextarea"  onChange="setChanged(1);"  value="<%=annotation.getComments()%>"><%=annotation.getComments()%></TEXTAREA>
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
<TEXTAREA name="sequence" id="sequence" align="left" rows="4" class="largeTextarea"   onChange="setChanged(1);"  value="<%=annotation.getSequences()%>"><%=annotation.getSequences()%></TEXTAREA>
</TD>
</TR>
</TABLE>
</TD>
</TR>
</TABLE>
<br>
<table align="left" width="50%" border="0" cellpadding="2" cellspacing="10" >
<div align="center">
<tr align="center"  class="form_body"> &nbsp;&nbsp;
<nobr>
<input  type="Submit"  class="btn"   name="doSelected" id="doSelected"  value=" Create "   width="120" HEIGHT="110" onClick="confirmCreate();" > &nbsp;
<input  type="Reset" class="btn"  name="btnReset" id="btnReset"  value="  Reset  " onClick="resetForm();">&nbsp; &nbsp;
<% if (!saved) { %>
<input type="button" name="btnClose" id="btnClose" value="Cancel"  class="btn"  onClick="processQuit('<%=aval%>', '<%=aid%>', <%=false%>);" >
<%}   else  { %>
<input type="button" name="btnClose" id="btnClose" value="Close Window"  class="btn"  onClick="processQuit('<%=aval%>', '<%=aid%>', <%=true%>);" >
<%}%>
</nobr>
</tr>
</div>
</table>
<td>
</tr>
</table>
<%
if (vannos != null && vannos.size() >0)
for (i=0; i<vannos.size(); i++ ) {
AnnotationDetail oldAnnotation = (AnnotationDetail)vannos.get(i);
%>
<center>
_________________________________________________________________________________
</center>
<br> <br>      <TABLE width="100%"  border="0" cellpadding="2" cellspacing="2">  <TR><TD>
<TABLE width="100%"   border="0" cellpadding="0" cellspacing="0"> <TR><TD>
<TABLE width="100%" id="infoTable"  border="1" cellpadding="2" cellspacing="1">
<TR>
<TD colspan="4" class="form_body">
<div  align="center" >
<font size="2">
<B>
<%if (isTemplate) { %>
Annotation&nbsp;Template
<% }
else { %>
Recently&nbsp;Created&nbsp;Annotation&nbsp;(<%=vannos.size()-i%>)
<%} %>
</b> </font>
</div>
</TD>
</TR>
<TR>
<TD class="annotation2" colspan="1"> <div id="annoname" > <B>Annotation&nbsp;Name</B></div> </td>
<TD class="annotation2" colspan="3">
<input READONLY type="text" name="gname" id ="gname" class="largeInputRO"  maxlength="200" value="<%=Util.htmlQuote(oldAnnotation.getGname()) %>" >
</TD>
</TR>
<TR id="trackRow">
<TD ALIGN="left" class="annotation2" colspan="1">
<div id="track"><B>Track<B></div></TD>
<TD class="annotation2" colspan="1">
<input READONLY type="text"  name="trackName"  id="trackName" class="longInputRO"   value="<%=oldAnnotation.getTrackName()%>">
</TD>
<TD ALIGN="left" class="annotation2" colspan="2">&nbsp;</TD>
</TR>
<TR>
<TD ALIGN="left" class="annotation2" colspan="1"><div id="ch2"><B>Chromosome</B></div></TD>
<TD class="annotation2" colspan="">
<input READONLY type="text"  name="chromosomes"  id="chromosomes" class="longInputRO" value="<%=oldAnnotation.getChromosome()%>">
</TD>
<TD ALIGN="left" class="annotation2" colspan="2">&nbsp;</TD>
</TR>
<TR>
<TD ALIGN="left" class="annotation2" colspan="1"><div id="startLabel"><B>Start</B></div></TD>
<TD class="annotation2" colspan="1">
<input READONLY type="text"  class="longInputRO" name="ep_Start" id="ep_Start" maxlength="50"    value= "<%=oldAnnotation.getFstart()%>" >
</TD>
<TD ALIGN="left" class="annotation2" colspan="1"><div id="stop"><B>Stop</B></div></TD>
<TD class="annotation2" BGCOLOR="white" colspan="1">
<input READONLY type="text" class="longInputRO" name="epStop" id="epStop" maxlength="50"    value="<%=oldAnnotation.getFstop()%>" >
</TD>
</TR>
<TR>
<TD ALIGN="left" class="annotation2" colspan="1"><div id="qstart"><B>Query&nbsp;Start</B></div></TD>
<TD class="annotation2" colspan="1">
<input name="tstart" READONLY id = "tstart" type="text" BGCOLOR="white" class="longInputRO" maxlength="50"    value="<%=oldAnnotation.getTstart()%>" >
</TD>
<TD ALIGN="left" class="annotation2" colspan="1"><div id="qstop"><B>Query&nbsp;Stop</B></div></TD>
<TD class="annotation2" colspan="1">
<input type="text" READONLY name="tstop" id="tstop" BGCOLOR="white" class="longInputRO" maxlength="50"    value="<%=oldAnnotation.getTstop()%>">
</TD>
</TR>
<TR>
<TD ALIGN="left" class="annotation2" colspan="1"><div id="strand"><B>Strand</B></div></td>
<TD class="annotation2" colspan="1">
<input READONLY type="text" class="longInputRO" name="strand" id="strand" BGCOLOR="white" maxlength="50"    value="<%=oldAnnotation.getStrand()%>">
</TD>
<TD ALIGN="left" class="annotation2" colspan="1"><div id="phase"><B>Phase</B></div></TD>
<TD ALIGN="left" class="annotation2" colspan="1">
<input READONLY type="text" class="longInputRO" name="phase" id="phase" BGCOLOR="white" maxlength="50"    value="<%=oldAnnotation.getPhase()%>">
</TD>
</TR>
<TR>
<TD ALIGN="left" class="annotation2" colspan="1"><div id="score"><B>Score</B></div></TD>                                                     			<!-- SCORE -->
<TD ALIGN="left" class="annotation2" colspan="1">
<input READONLY type="text" class="longInputRO" name="fscore" id="fscore" BGCOLOR="white" maxlength="50"  value="<%=oldAnnotation.getFscore()%>">
</TD>
<TD ALIGN="left" class="annotation2" colspan="2">&nbsp;</TD>
</TR>

<%@ include file="include/singleAnnoAVPDisplay4cols.incl" %>

<TR>
<TD ALIGN="left" colspan="1" class="annotation2"><div id="labelcomment"><B>Free-Form Comment</B></div></TD>
<TD align="left" class="annotation2" colspan="3">
<TEXTAREA READONLY name="comments" id="comments"  align="left" rows="4" class="largeTextareaRO"   value="<%=oldAnnotation.getComments()%>"><%=oldAnnotation.getComments()%></TEXTAREA>
</TD>
</TR>
<TR>
<TD ALIGN="left" colspan="1" class="annotation2"><div id="sequences"><B>Sequence</B></div></TD>
<TD align="left" class="annotation2" colspan="3">
<TEXTAREA READONLY name="sequence" id="sequence" align="left" rows="4" class="largeTextareaRO"    value="<%=oldAnnotation.getSequences()%>"><%=oldAnnotation.getSequences()%></TEXTAREA>
</TD>
</TR>
</TABLE>  </TD>
</TR>
</TABLE> </TD>
</TR>
</TABLE>
<%}%>
</form>
<%@ include file="include/invalidFidMsg.incl"%>
<%@ include file="include/footer.incl" %>
</BODY>
</HTML>
<%
  if(refreshGbrowser)
  {
%>
    <script type="text/javascript">
      confirmRefresh() ;
    </script>
<%
  }
%>
