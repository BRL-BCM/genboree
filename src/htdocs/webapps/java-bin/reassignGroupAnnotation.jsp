<%@ page import="java.text.NumberFormat, java.text.DecimalFormat, java.io.InputStream, java.util.*,
    java.util.regex.Pattern,java.util.regex.Matcher,
    java.lang.reflect.Array,java.sql.*,
    org.genboree.util.*,
    java.util.Date,
    org.genboree.editor.AnnotationEditorHelper,
    org.genboree.message.GenboreeMessage,
                 org.genboree.tabular.LffUtility"
%>
<%
     AnnotationDetail [] lastPageAnnotations  = null;
 boolean debugging = false;
 long startTime = 0;
  if (debugging) {
  startTime =  Calendar.getInstance().getTimeInMillis();
  System.err.println("\n***********************************************************\nTesting of time used \n \nstart time:" + startTime);
  }
%>
<%@ page import="javax.servlet.http.*, org.genboree.upload.HttpPostInputStream " %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%@ include file="include/fidInfo.incl" %>
<%
    String validate = " return validTrackName ();";
    String aid = "rgnewTrackName";
    String aval = "";
    String changed = "0";
    String[] fids = null;
    String initVal = "";
    String pageName = "reassignGroupAnnotation.jsp";
    String orderNum = "1";
    String actionName = "  Assign  Selected  ";
    String doSelected = "doSelected";
    HashMap fid2AnnoNums = new HashMap();
    HashMap fid2Annos = new HashMap();
    String checkBoxName = "checkBoxName";
    String okState = "okState";
    boolean updateAll = false;
    String copyChecked = "";
    int [] fidi = null;
    HashMap trackMap = null;
    String type = ""; String subtype="";
    String [] tracks = null;
    ArrayList groupSelectedFidList = new ArrayList();
    String formId = "editorForm";
    if (request.getParameter("upfid") != null)
        mys.removeAttribute("selectedFidList");
    else
    if (mys.getAttribute("selectedFidList") != null)
          groupSelectedFidList =   (ArrayList)mys.getAttribute("selectedFidList");

    ArrayList pageSelectedFidList = new ArrayList();
    AnnotationDetail [] selectedAnnotations = null;
    String selectAll = "selectAll(0)";
    String confirmSelected = " return confirmSelected(0,0,false)";
    String unSelectAll = "unSelectAll(0)";
    int refseqid = upload.getRefSeqId();
    GenboreeMessage.clearMessage(mys);
    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );
    boolean refreshGbrowser = false;
    String currentTrackName = null;
    AnnotationDetail annotation = null;
    AnnotationDetail[] annotations = null;
    AnnotationDetail[] totalAnnotations = null;
    String classTrackName = "";
    String lastSelectedTrackName = "";
    int classFtypeid = -1;
    String rid = "0";
    int ridInt = 0;
    int state = 0;
    ArrayList copiedFids =  new ArrayList();
    boolean success = false;
    int i = 0;
    String lastTrkName = "";
    Connection con =  db.getConnection(dbName);
    if (con == null || con.isClosed())
        GenboreeUtils.sendRedirect(request, response, destback);
    int genboreeUserId = Util.parseInt(myself.getUserId(), -1);
    int  newFtypeid = -1;
    int db2jsp = 0;
    String className = "";
    HashMap errorField = new HashMap();
    int numAnnotations = 0;
%>
<%@ include file="include/largeGroup.incl" %>

<%@ include file="include/pageInit.incl" %>
<%@ include file="include/cancelHandler.incl" %>
<%
    if ( totalAnnotations != null)
      numAnnotations =   totalAnnotations.length;
    int numreassigned = 0;
    Vector vlog = new Vector();
    boolean newTrackError = false;
    if (request.getParameter("upfid") == null )// In Here upload and fid are check
    {                                          // It not clear to me what is the objective of this if MLGG
      className = (String)mys.getAttribute("gclassName");
      String s  = (String)mys.getAttribute("classFtypeid");
      if (s != null)
      classFtypeid = Integer.parseInt(s);
      rid = (String)mys.getAttribute("rid");
      ridInt = Integer.parseInt(rid);
      classTrackName =  (String)mys.getAttribute("classTrackName");
      if (classTrackName == null )
      classTrackName = "";
      lastTrkName =  (String)mys.getAttribute("lastSelectedGroupTrak");
      currentTrackName = lastTrkName;
      fid2Annos =  (HashMap )mys.getAttribute("fid2Annotation");
      totalAnnotations =(AnnotationDetail []) mys.getAttribute("totalAnnotations") ;
      fid2AnnoNums =  (HashMap )mys.getAttribute("fid2AnnoNums");
      copyChecked = (String)mys.getAttribute("copyChecked");
    }
    else  // in here the page contains the fid and the uploadId
    {
      if (  mys.getAttribute("lastSelectedGroupnewType")!=null)
            mys.removeAttribute("lastSelectedGroupnewType");
      if (  mys.getAttribute("lastSelectedGroupnewSubType")!=null)
            mys.removeAttribute("lastSelectedGroupnewSubType");
      if (totalNumAnno<Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN || proceedLargeGroup)
      {
        totalAnnotations =   AnnotationEditorHelper.findGroupAnnotations(dbName, ifid, response, mys, out, con);
        if (totalAnnotations != null)  
        {
          rid = ""+  totalAnnotations[0].getRid();
          mys.setAttribute("gclassName", totalAnnotations[0].getGname());
          mys.setAttribute("ftypeid", "" +  totalAnnotations[0].getFtypeId());
          mys.setAttribute("rid", "" + rid);
          className =   totalAnnotations[0].getGname();
          classFtypeid =  totalAnnotations[0].getFtypeId();
          mys.setAttribute("classFtypeid", "" + classFtypeid);
          classTrackName =   totalAnnotations[0].getTrackName();
          currentTrackName = classTrackName;
          mys.setAttribute("classTrackName", classTrackName);
          mys.setAttribute("changed", "no");
          mys.setAttribute("copiedfids", copiedFids);
          mys.setAttribute("lastSelectedGroupTrak",  classTrackName);
        }

        if (totalAnnotations != null && totalAnnotations.length >0)
        {
          for (i=0; i<totalAnnotations.length; i++)
          {
            int tempInt = i+1;
            fid2AnnoNums.put("" + totalAnnotations[i].getFid(), "" + tempInt);
            fid2Annos.put("" + totalAnnotations[i].getFid(), totalAnnotations[i]);
            totalAnnotations[i] = AnnotationEditorHelper.convertAnnotation(totalAnnotations[i], db2jsp);
          }
          mys.setAttribute("fid2AnnoNums", fid2AnnoNums);
          mys.setAttribute("fid2Annotation", fid2Annos);
          mys.setAttribute("totalAnnotations", totalAnnotations);
        }
      }
    }



    if (totalNumAnno < Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN  || proceedLargeGroup )
    {
      if (totalAnnotations == null && totalAnnotations.length==0)
      {
        String upfid1 = (String)mys.getAttribute("lastTextID") ;
        GenboreeUtils.sendRedirect(request, response, "/java-bin/annotationEditorMenu.jsp?upfid="+ upfid1) ;
        return;
      }
      if (totalAnnotations != null && totalAnnotations.length > 0)
        annotation = totalAnnotations[0];
      // retrieve existing tracks
      tracks = new String [0];
      trackMap = AnnotationEditorHelper.findTracks(db, con, genboreeUserId, dbName);
      if (trackMap != null && trackMap.size() > 0)
      {
          Iterator iterator = trackMap.keySet().iterator();
          int count = 0;
          tracks = new String [trackMap.size()];
          while (iterator.hasNext())
          {
            tracks[count] = (String) iterator.next();
            count++;
          }
          Arrays.sort(tracks);
          String [] newTracks = new String [tracks.length + 1] ;
          newTracks [0] = "**New Track**";
          for (int j=1; j<=tracks.length; j++)
          newTracks [j] = tracks [j-1];
          tracks = newTracks;
    }
    int numAssign = 0;
    int numRemain = 0;
    String annoAssign = "annotation(s)";
    String annoRemain = "annotation(s)";
    // boolean confirmOK = false;
    fids = request.getParameterValues("reassignAnnoIds");
    int numSelected = 0;
    // currentTrackName  = request.getParameter("rgnewTrackName");
    String newTrackName = "";
    String newTrkName = "";
    newTrackName = request.getParameter("rgnewTrackName");
    newTrkName =  newTrackName;

    if ( newTrackName  != null)
    {
        mys.setAttribute("lastSelectedGroupTrak", newTrackName);
        String  snewFtypeid = (String)trackMap.get(newTrackName);
        currentTrackName =  newTrackName;
      if (snewFtypeid != null)
      {
        newFtypeid = Integer.parseInt(snewFtypeid);
      }
      if (newTrackName.compareTo(classTrackName)==0)
        newTrackError = true;
    }

    if (currentTrackName ==null)
      currentTrackName = classTrackName;

    if (request.getParameter("copytrack") != null)
    {
      copyChecked = " checked";
      mys.setAttribute("copyChecked", copyChecked)  ;
    }

    if (request.getParameter("copytrack") == null)
      copyChecked = "";

    type = request.getParameter("rgnewtype");
    subtype = request.getParameter("rgnewsubtype");
    if (type != null && type.compareTo("")!=0)
      mys.setAttribute("lastSelectedGroupnewType", type);
    if (subtype != null && subtype.compareTo("")!=0)
      mys.setAttribute("lastSelectedGroupnewSubType", subtype);
    if (type== null)
      type= (String) mys.getAttribute("lastSelectedGroupnewType");
    if (type== null )
      type="";
    type = type.trim();
    if (subtype== null)
      subtype= (String) mys.getAttribute("lastSelectedGroupnewSubType");
    if (subtype== null)
      subtype="";
    subtype = subtype.trim();
    String  lastPageIndex ="";
    if (mys.getAttribute("lastPageIndex")!= null)
      lastPageIndex =  (String)mys.getAttribute("lastPageIndex");
  %>
<%@ include file="include/multipage.incl" %>
<%@ include file="include/doSelect.incl"  %>
<%@ include file="include/fidUpdate.incl"  %>
<%
        if (request.getParameter(doSelected) != null) // What is this do selection???
        {
          String status = request.getParameter(okState);
        if (status != null && status.compareTo("1")==0) {
          newTrackName = request.getParameter("rgnewTrackName");
        newTrkName =  newTrackName;
        if ( newTrackName  != null && newTrackName.indexOf("New Track") >=0) {
        type = request.getParameter("rgnewtype");
        subtype = request.getParameter("rgnewsubtype");
        mys.setAttribute("lastSelectedGroupnewType", type);
        mys.setAttribute("lastSelectedGroupnewSubType", subtype);
        if (type!= null && subtype != null){
        type = type.trim();
        subtype = subtype.trim();
        int numErrors = AnnotationEditorHelper.validateTracks(true,  newTrackName, type, subtype, dbName,  mys, trackMap,  annotation, request, errorField, vlog,  out, con) ;
        if (numErrors <=0) {
        String []  newTracks = new String [tracks.length + 1];
        for ( int n=0; n<tracks.length; n++)
        newTracks[n] = tracks [n];
        newTracks[tracks.length] = type + ":" + subtype;
        tracks = newTracks;
        mys.removeAttribute("lastSelectedGroupTrak");
        mys.setAttribute("lastSelectedGroupTrak", type + ":" + subtype);
        newTrackName = type + ":" + subtype;
        newTrkName = newTrackName;
        newFtypeid = annotation.getFtypeId();
        }
        else {
        newTrackError = true;
        }
        }
        currentTrackName =  newTrackName;
        }
        if (newTrackName.indexOf("New Track") >=0 )
          newTrkName = type+ ":" + subtype;
    if(!newTrackError)
    {
        state = 0;
        numSelected = groupSelectedFidList.size();
        fidi = new int[ numSelected];
        selectedAnnotations = new AnnotationDetail[ numSelected];

        int count = 0;
        if (numSelected >0)
        {
          for (int j=0; j<totalAnnotations.length; j++)
          {
            if (groupSelectedFidList.contains("" + totalAnnotations[j].getFid())) {
                totalAnnotations[j].setFlagged(true);
                selectedAnnotations[count] = totalAnnotations[j];
                fidi[count] =   totalAnnotations[j].getFid();
                count++;
            }
           }

          // What is this classFtypeid??
           if(newFtypeid != classFtypeid)
           {
              AnnotationEditorHelper.updateTrackColor(newFtypeid, classFtypeid, dbName, out,   con);
              if(request.getParameter("copytrack") != null)
              {
                if( numSelected > 0 )
                {
                  String[] newfids = AnnotationEditorHelper.duplicateAnnotations( newFtypeid, selectedAnnotations, dbName, con );
                  if( newfids != null && newfids.length > 0 )
                  {
                    int[] arr = new int[newfids.length];
                    for( int n = 0; n < newfids.length; n++ )
                    {
                      arr[ n ] = Integer.parseInt( newfids[ n ] );
                    }
                    AnnotationEditorHelper.updateFeature2AVPName( newFtypeid, arr, con );
                  }
                  if( fids != null && fids.length > 0 )
                  {
                    for( i = 0; i < fids.length; i++ )
                    {
                      if( !copiedFids.contains( fids[ i ] ) )
                        copiedFids.add( fids[ i ] );
                    }
                  }
                  groupSelectedFidList = new ArrayList();
                  mys.setAttribute( "selectedFidList", groupSelectedFidList );
                  mys.setAttribute( "copiedfids", copiedFids );
                  ArrayList mlist = new ArrayList();
                  numRemain = 0;
                  for( int j = 0; j < totalAnnotations.length; j++ )
                  {
                    if( !totalAnnotations[ j ].isFlagged() )
                      numRemain++;
                   }
                  if( numRemain < 0 )
                    numRemain = 0;
                  String copy = ( newfids.length > 1 ) ? "\" as copies." : " \" as a copy.";
                  String tail = ( numRemain > 1 ) ? "\"  remain to be copied." : " \"  remains to be copied.";
                  annoRemain = numRemain > 1 ? "annotations of the original grou in track \"" : "annotation of the original group in track \"";
                  annoAssign = ( fidi.length > 1 ) ? "annotations have been reassigned to track \"" : "annotation of the original group has been reassigned to track \"";
                  mlist.add( "" + fidi.length + "&nbsp;" + annoAssign + newTrkName + copy );
                  mlist.add( "" + numRemain + "&nbsp;" + annoRemain + classTrackName + tail );




                  GenboreeMessage.setSuccessMsg( mys, "The process was successful.", mlist );
                  GenboreeUtils.processGroupContextForGroup( "" + refseqid, className, "" + newFtypeid, "" + rid, false );
                  GenboreeUtils.processGroupContextForGroup( "" + refseqid, className, "" + classFtypeid, "" + rid, false );
                  CacheManager.clearCache( db, upload.getDatabaseName() );
                  refreshGbrowser = true;
                  ArrayList unselectedAnnos = new ArrayList();
                  for( int j = 0; j < annotations.length; j++ )
                  {
                    if( copiedFids.contains( "" + annotations[ j ].getFid() ) )
                    {
                      annotations[ j ].setFlagged( true );
                    }
                  }
                  count = 0;
                  for( int j = 0; j < annotations.length; j++ )
                  {
                    if( annotations[ j ].isFlagged() )
                      count++;
                  }
                  doPaging = true;
                  %>
                  <%@ include file="include/multipage.incl" %>
                  <%
                }
                else
                {
                  System.err.println("In the group editor no selection does not make sense!!!");
                }
              }
              else
              { //not copy
                boolean hasMyPermission = TrackPermission.isTrackAllowed( dbName, newFtypeid, genboreeUserId );
                if(hasMyPermission)
                {
                  AnnotationEditorHelper.updateSelectedFtype( newFtypeid , fidi, con, dbName, genboreeUserId );
                  AnnotationEditorHelper.updateFeature2AVPName(newFtypeid, fidi, con) ;
                  // update current page for display
                  for (int j=0; j<annotations.length; j++)
                  {
                      if (groupSelectedFidList.contains("" + annotations[j].getFid()))
                      {
                          annotations[j].setFlagged(true);
                      }
                  }
                  // update groupSelcetedFidList
                  groupSelectedFidList = new ArrayList();
                  mys.setAttribute("selectedFidList", groupSelectedFidList);
                  refreshGbrowser = true;
                  ArrayList mlist = new ArrayList();
                  int newtotal = 0;
                  for (int j=0; j<totalAnnotations.length; j++)
                  {
                      if (!totalAnnotations[j].isFlagged())
                      {
                          newtotal++;
                      }
                  }
                  for (int j=0; j<totalAnnotations.length; j++)
                  {
                      if (!totalAnnotations[j].isFlagged())
                      {
                          numRemain  ++;
                      }
                  }
                  if(numRemain <0) numRemain = 0;
                  annoRemain = numRemain>1? "annotations of the original group remain within track \"" : "annotation of the original group remains within track  \"";
                  annoAssign =  (fidi.length >1)? "annotations have been reassigned to track \"" : "annotation has been reassigned to track \"";
                  mlist.add("" +  fidi.length + "&nbsp;" + annoAssign + newTrkName + "\"");
                  mlist.add("" +  numRemain + "&nbsp;" + annoRemain +  classTrackName + "\"") ;
                  GenboreeMessage.setSuccessMsg(mys, "The process was successful." ,mlist);
                  GenboreeUtils.processGroupContextForGroup(""+refseqid, className,  "" +newFtypeid,  "" + rid, false);
                  GenboreeUtils.processGroupContextForGroup(""+refseqid, className,  "" +classFtypeid,  "" + rid, false);
                  CacheManager.clearCache(db, upload.getDatabaseName()) ;
                  count = 0;
                  vlog = new Vector();
                  if (  fids != null  )
                  {
                      for (int j=0; j<annotations.length; j++)
                      {
                        if (annotations[j].isFlagged())
                        {
                          count++;
                          try
                          {
                            AnnotationEditorHelper.updateAnnotationText(newFtypeid,  annotations[j],  db,  dbName,   con,  out) ;
                           }
                           catch (Exception e)
                           {
                              e.printStackTrace(System.err);
                           }
                        } // Why are you doing this!!!
                        AnnotationEditorHelper.deleteAnnotationText( annotations[j].getFid() , db, con, out);
                      }
                   }
                  vlog = new Vector();
                  doPaging = true;
                  %>
                  <%@ include file="include/multipage.incl" %>
                  <%
                }
          else
          {
             GenboreeMessage.setErrMsg(mys,  " Please select a different track.");
             newTrackError = false;
          }
        }
     }
   }
   else
   {
        if (groupSelectedFidList.size() ==0)
        GenboreeMessage.setErrMsg(mys,  "Please select an annotation.");
    }
}
else if  ((currentTrackName) != null &&  currentTrackName.compareTo(classTrackName)==0)
{
        GenboreeMessage.setErrMsg(mys,  " Please select a different track.");
        newTrackError = false;
}
}
else
{
           if (groupSelectedFidList.size() ==0)
            GenboreeMessage.setErrMsg(mys,  "Please select an annotation.");
}
}

   if (totalAnnotations != null && totalAnnotations.length > 0 )
   {
     for (i=0; i<totalAnnotations.length; i++)
     {
         if (groupSelectedFidList.contains("" + totalAnnotations[i].getFid()) && totalAnnotations[i].isFlagged())
           groupSelectedFidList.remove("" + totalAnnotations[i].getFid()) ;
     }
   }

    int pageSelected = 0  ;
    if (annotations != null && annotations.length > 0 ) {
    for (i=0; i<annotations.length; i++)  {
    if (groupSelectedFidList.contains("" + annotations[i].getFid()) && !annotations[i].isFlagged())
    pageSelected ++;
    }

    int newSelected = groupSelectedFidList.size() -  pageSelected;
    if (newSelected <0)
    newSelected = 0 ;

    confirmSelected = " return confirmSelected("+  newSelected  +  ", " + totalAnnotations.length + ", " + updateAll +  ")";
    selectAll = "selectAll(" + totalAnnotations.length +  ")";
    unSelectAll = "unSelectAll(" + totalAnnotations.length+  ")";
    }
    mys.setAttribute("lastPageAnnotations" , annotations);
    aval = classTrackName;
    if (aval == null)
    aval ="";
    else
    aval = Util.urlEncode(aval);
    if ( !initPage && aval.compareTo(classTrackName)!=0) {
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

    HashMap errorFields = new HashMap();
%>
 <%@ include file="include/saved.incl" %>
<HTML>
<HEAD>
<TITLE>Genboree - Annotation Group Editor</TITLE>
    <LINK rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
    <LINK rel="stylesheet" href="/styles/annotationEditor.css<%=jsVersion%>" type="text/css">
    <LINK rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">
    <SCRIPT TYPE="text/javascript" SRC="/javaScripts/reassignGroupAnnotation.js<%=jsVersion%>"></SCRIPT>
    <SCRIPT TYPE="text/javascript" SRC="/javaScripts/prototype.js<%=jsVersion%>"></SCRIPT>
    <SCRIPT TYPE="text/javascript" SRC="/javaScripts/editorCommon.js<%=jsVersion%>"></SCRIPT>
    <SCRIPT TYPE="text/javascript" SRC="/javaScripts/delimitGrpComments.js<%=jsVersion%>"></SCRIPT>
    <link rel="stylesheet" href="/styles/avp.css<%=jsVersion%>" type="text/css">
    <LINK rel="stylesheet" href="/styles/querytool.css<%=jsVersion%>" type="text/css">
    <script type="text/javascript" src="/javaScripts/util.js<%=jsVersion%>"></script>
    <script src="/javaScripts/commonFunctions.js<%=jsVersion%>" type="text/javascript"></script>
    <script src="/javaScripts/attributeValuePairs.js<%=jsVersion%>"  defer="true" type="text/javascript"></script>
    <META HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</HEAD>
<BODY>
<%  if (totalNumAnno < Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN || proceedLargeGroup) {%>
<%@ include file="include/header.incl" %>
<%}%>
<%@ include file="include/validateFid.incl" %>
<%@ include file="include/redir.incl" %>
<form name="<%=formId%>" id="<%=formId%>" action="<%=redir%>" method="post" onSubmit="<%=validate%>" >
    <input type="hidden" name="<%=okState%>" id="<%=okState%>" value="<%=state%>" >
    <input type="hidden" name="rggroupTrackName" id="rggroupTrackName" value="<%=Util.urlEncode(classTrackName)%>))" >
    <input type="hidden" name='selectAllAnnos' id='selectAllAnnos' value="false" >
    <input type="hidden" name="currentPage" id="currentPage" value="<%=currentPage%>">
    <input type="hidden" name="navigator" id="navigator" value="home">
    <input type="hidden" name="cancelState" id="cancelState" value="0">
    <input type="hidden" name="doSelected" id="doSelected" value="">
    <input type="hidden" name="changed" id="changed" value="<%=changed%>">
<%@ include file="include/largeGrpConfirm.incl" %>
<%
    if (totalNumAnno < Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN || proceedLargeGroup) {
    %>
    <TABLE width="100%" border="0" cellpadding="2" cellspacing="2">
    <%  if (annotations != null && annotations.length >0 ){  %>
    <TR align="center">
    <TD  class="form_body">
    <center><FONT SIZE="4"><B>  Assign Annotations
    <br>From&nbsp;Group&nbsp;&quot;<%=className%>&quot;</B></FONT>
    </center>
    </TD>
    </TR>
    <%@ include file="include/mp_pageIndex.incl"%>
    <% }
    %>
    <TR>
    <TD>
    <%@ include  file="include/message.incl" %>
    <%  GenboreeMessage.clearMessage(mys);%>
    <font color="red">
    <UL class="compact2">
    <div id="rgmessage1" >
    </div>
    </UL>
    <div id="rgmessage" >
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
    </TD>
        </TR>
  <%  if (annotations != null && annotations.length >0 ){  %>
    <TR align="center">
    <TD>
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
    <%  if (errorField.get("newTrackRow") == null) {
     String sdisplay = "display:none";
    %>
    <TR id="rgTrackRow">
    <TD name="rgtrackLabel" id="rgtrackLabel" align="center" class="annotation2">
    <B>Assign&nbsp;to&nbsp;Track:</B></TD>
    <td colspan="2" class="annotation2">&nbsp;
    <select style="width: 190px" name="rgnewTrackName" id="rgnewTrackName" onchange=" checkNewTrack(); " >
    <%
    for (int j=0; j<tracks.length; j++) {
    String sel = "";
    if (currentTrackName != null && tracks[j].compareTo(Util.htmlQuote(currentTrackName)) ==0){
    sel = " selected";
    }
    %>
    <option  value="<%=tracks[j]%>" <%=sel%>> <%=tracks[j]%> </option>
    <%}%>
    </select>
    </td>
    </tr>
    <tr id="rgnewTrackRow1" style="<%=sdisplay%>" >
    <td id="rgtypeLabel" class="annotation2" ><b>New&nbsp;Type:&nbsp;</b></td>
    <td  colspan="2" class="annotation2">&nbsp;
    <input id="rgtype" type="text" name="rgnewtype"  class="txt" style="width:192px" value="<%=Util.htmlQuote(type)%>"></td>
    </tr>
    <tr id="rgnewTrackRow2" style="<%=sdisplay%>" >
    <td id="rgsubtypeLabel" class="annotation2"><b>New &nbsp;Subtype:&nbsp;</b></td>
    <td  colspan="2" class="annotation2">&nbsp;
    <input type="text" id="rgsubtype" name="rgnewsubtype" class="longInput2"  style="width:190px" value="<%=Util.htmlQuote(subtype)%>"></td>
    </tr>
    <%
    if (request.getParameter("rgnewTrackName")!=null) {
    String s = request.getParameter("rgnewTrackName");
    if (s.indexOf ("New Track") >0) { %>
    <script>
        var trackRowId =$("rgTrackRow");
        var newTrackRowId1 =$( "rgnewTrackRow1");
        var newTrackRowId2 =$( "rgnewTrackRow2");
        var classTrkName =$("rggroupTrackName").value;
        $("rgtrackLabel").style.color="#403c59";
        var trackName =$("rgnewTrackName").value;
        if (trackName.indexOf("New Track") >0) {
        newTrackRowId1.style.display = trackRowId.style.display;
        newTrackRowId2.style.display = trackRowId.style.display;
        var typeLabel = $("rgtypeLabel");
        var subtypeLabel = $("rgsubtypeLabel");
        typeLabel.style.color="#403c59";
        subtypeLabel.style.color = "#403c59";
        $("rgtrackLabel").style.color="#403c59";
    }
    </script>
    <%
    };
    }
    %>
    <%   }
    else {     %>
    <TR id="rgTrackRow">
    <TD name="rgtrackLabel" id="rgtrackLabel" align="center" class="annotation2">
    <B>Assign&nbsp;to&nbsp;Track:</B></TD>
    <td colspan="2" class="annotation2">&nbsp;
    <select style="width: 190px" name="rgnewTrackName" id="rgnewTrackName" onchange="checkRGNewTrack()" >
    <%
    type =  (String)mys.getAttribute("lastSelectedGroupnewType");
    subtype = (String)mys.getAttribute("lastSelectedGroupnewSubType");
    String  selectedTrackName = "";
    for (int j=0; j<tracks.length; j++) {
    String sel = "";
    if (currentTrackName != null && tracks[j].compareTo(Util.htmlQuote(currentTrackName)) ==0) {
    sel = " selected";

    }
    %>
    <option  value="<%=tracks[j]%>" <%=sel%>> <%=tracks[j]%> </option>
    <%}%>
    </select>
    </td>
    </tr>
    <tr id="rgnewTrackRow1"  >
    <td id="rgtypeLabel" class="annotation1" ><b>New&nbsp;Type:&nbsp;</b></td>
    <td  colspan="2" class="annotation2">&nbsp;
    <input id="rgtype" type="text" name="rgnewtype"  class="txt" style="width:192px" value="<%=type%>"></td>
    </tr>
    <tr id="rgnewTrackRow2" >
    <td id="rgsubtypeLabel" class="annotation1"><b>Subtype:&nbsp;</b></td>
    <td  colspan="2" class="annotation2">&nbsp;
    <input type="text" id="rgsubtype" name="rgnewsubtype" class="longInput2"  style="width:190px" value="<%=subtype%>"></td>
    </tr>
    <%   }  %>
    <TR align="center"><td class="annotation2" colspan="4">
    <B><I>Copy</I> to track, rather than move to track?</B>
    <input type="checkbox"  name="copytrack" id="copytrack" <%=copyChecked%> >
    </TD> </TR>

    </TABLE>
    </TD>
    </TR>
    <%}%>
    <% if (annotations != null && annotations.length >0){ %>
    <TR align="center"><TD>
    <%@ include file="include/buttonSet.incl" %>
    </TD></TR>
    <% } else {
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
    if (annotations != null && annotations.length > 0 ) {
    for (i=0; i<annotations.length; i++) {
    annotation = annotations[i];
    int tempint = i+1;
    orderNum = "" + tempint;
    if (annotation == null || annotation.isFlagged()){
    continue;
    }
    else {
    if (  fid2AnnoNums.get ("" + annotation.getFid()) != null)
    {
    orderNum =  (String )fid2AnnoNums.get ("" + annotation.getFid()) ;
    }
    }
    String checkBoxId = "checkBox_" + orderNum;
    String checked = "";
    if (groupSelectedFidList.contains(""+ annotation.getFid()))
    checked = "checked" ;
    String commentsid = "comments_" + i;
    String reassignId = "reassign_" + i;
    String gnameid = "gname_" + i;
    HashMap      name2Values = new HashMap ();
    fid = "" + annotation.getFid();
    int currentIndex = 0;
    %>

    <%@ include file="include/avpPopulator.incl" %>
    <input type="hidden" name="avpvalues_<%=i%>" id="avpvalues_<%=i%>" value="">
    <input type="hidden" name="index_<%=i%>" id="index_<%=i%>" value="<%=currentIndex%>">

    <input type="hidden" name="<%=reassignId%>" id="<%=reassignId%>" value="0">
    <%     if (i!=0) { %><tr><td>&nbsp;</td></tr> <%}%>
    <TR>
    <td>
    <TABLE width="100%"  border="1" cellpadding="2" cellspacing="1">
    <TR>
    <TD class="annotation2" colspan="4">
    <input type="checkbox"  name="<%=checkBoxName%>" id="<%=checkBoxId%>" <%=checked%> value="<%=annotation.getFid()%>">
    &nbsp; &nbsp;  &nbsp; &nbsp; &nbsp; &nbsp;  &nbsp; &nbsp;   &nbsp; &nbsp;  &nbsp; &nbsp;        &nbsp; &nbsp;  &nbsp; &nbsp; &nbsp; &nbsp;  &nbsp; &nbsp;          &nbsp; &nbsp;  &nbsp; &nbsp;    &nbsp; &nbsp;  &nbsp; &nbsp;    &nbsp; &nbsp;  &nbsp; &nbsp;
    <B><FONT SIZE="2">
    &quot;<%=annotations[i].getGname()%> &quot; <%="("%>Annotation <%=orderNum%><%=")"%>
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
    <B>Track</B>
    </TD>
    <TD class="annotation2" colspan="1">
    <input type="text" id="annotrackName" READONLY class="longInputRO" maxlength="20"  value="<%=Util.htmlQuote(annotation.getTrackName())%>">
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
    <input READONLY type="text" class="longInputRO" name="strand" id="strand" maxlength="50" value="<%=annotation.getStrand()%>">
    </TD>
    <TD ALIGN="left" class="annotation2" colspan="1"><B>Phase</B></TD>
    <TD ALIGN="left" class="annotation2" colspan="1">
    <input READONLY type="text" class="longInputRO" name="phase" id="phase"  maxlength="50" value="<%=annotation.getPhase()%>">
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
    <%}%>
    <%}%>
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
<%}
if (totalAnnotations != null && totalAnnotations.length >0)  { %>
<%@ include file="include/multipageEditorBottom.incl" %>
<%}%>
</table>
<%
fids = request.getParameterValues(checkBoxName);
if (fids != null && fids.length>0)  {
for (int j=0; j<fids.length; j++)
pageSelectedFidList.add(fids[j]);
}
if (annotations != null)
for (int j=0; j<annotations.length; j++) {
if (!pageSelectedFidList.contains("" +annotations[j].getFid() ))
groupSelectedFidList.remove("" + annotations[j].getFid());
} }
%>
</form>
<%@ include file="include/invalidFidMsg.incl"%>
<%    if (totalNumAnno < Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN || proceedLargeGroup) {  %>
<%@ include file="include/footer.incl" %>
<%}%>
<%
    if (debugging) {
    long endTime = Calendar.getInstance().getTimeInMillis();
    System.err.println("end time: "  + endTime);
    long used = (endTime - startTime);
    System.err.println("time used in millseconds:  " + used );
    System.err.println("***********************************************************\n  "  );
    }



%>
<%
  if(refreshGbrowser)
  {
    refreshGbrowser = false ;
%>
    <script>
      confirmRefresh() ;
    </script>
<%
  }
%>
</BODY>
</HTML>
