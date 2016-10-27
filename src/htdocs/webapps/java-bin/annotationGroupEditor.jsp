<%@ page import=" java.lang.reflect.Array,java.sql.*, java.util.*,
      java.util.Date,
      org.genboree.editor.AnnotationEditorHelper,
      org.genboree.editor.AnnotationConstants,
      org.genboree.editor.Chromosome,
      org.genboree.manager.tracks.TrackMgrConstants,
      org.genboree.message.GenboreeMessage,
      org.genboree.util.GenboreeUtils"
%>
<%@ page import="javax.servlet.http.*, org.genboree.upload.HttpPostInputStream " %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%@ include file="include/fidInfo.incl" %>
<%@ include file="include/pageInit.incl" %>
<%@ include file="include/cancelHandler.incl" %>
<%
     String formId = "editorForm";
    boolean saved = false;
    int numOK=0;
    int db2jsp = 0;
    int jsp2db = 1;
    HashMap attributeNameValueMap = new HashMap ();
    String warnMsg = "";
    String aid ="";
    String aval = "";
    String changed ="0";
    String initVal ="";
    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );
    String pageName="annotationGroupEditor.jsp";
    String orderNum = "1";
    HashMap fid2AnnoNums = new HashMap ();
    HashMap page2WebAnnos = new HashMap();
    //boolean useAVP = GenboreeUtils.isDatabaseUseAVP(upload.getRefSeqId(), db);
    HashMap fid2Anno = new HashMap ();
    GenboreeMessage.clearMessage(mys);
    String state = "0";
    Vector vLog = null;
    String [] chromosomes = null;
    HashMap trackMap = null;
    HashMap chromosomeMap = null;

    String [] tracks = new String [] {""};
    HashMap errorFields = new HashMap ();
    ArrayList drawList = new ArrayList();
    AnnotationDetail annotation = null;
    AnnotationDetail[] annotations = null;
    AnnotationDetail[] totalAnnotations = null;
    String errorMsg = "";

    boolean success = false;
    String className = null;
    String classTrackName = "";
    int classFtypeId = -1;
    int classRid = -1;
    Hashtable trackClass  = new Hashtable();
    Vector [] vlogs = null;
    int i = 0;
    boolean refreshGbrowser = false;
    String successAll ="";
    // String  trackId  = "";
    AnnotationDetail [] annotationsWeb = null;
    class DrawParams {
    String rid;
    String ftypeid;
    String gname;
    }
    String chromosomeid = null;
    String validateForm =  "return validateForm( 0)";
    String validateAll = "";
    String resetAll = "resetAll(0)";
    String upfid = (String)mys.getAttribute("lastTextID") ;
    Connection con =  db.getConnection(dbName);
    int genboreeUserId = Util.parseInt(myself.getUserId(), -1);


    if (con == null || con.isClosed()) {

        System.err.println(" connection failed at line 75 of annotationEditor.jsp");
  GenboreeUtils.sendRedirect(request,response, "/java-bin/error.jsp");
    return;
    }
%>
<%@ include file="include/largeGroup.incl" %>
<%
    if( request.getParameter("upfid") == null) {
        changed = (String)mys.getAttribute("changed");
        page2WebAnnos = (HashMap)mys.getAttribute("webAnnotations");
        if (page2WebAnnos == null)
        page2WebAnnos = new HashMap();

        if (mys.getAttribute("className")!=null)
        className = (String) (String)mys.getAttribute("className");

        if (mys.getAttribute("classTrackName")!=null)
        classTrackName = (String)mys.getAttribute("classTrackName");

        String tempRid = null;
        if (mys.getAttribute("classRid")!=null)
        tempRid = (String)mys.getAttribute("classRid");

        if (tempRid != null)
        classRid = Integer.parseInt(tempRid);

        String tid    = null;
        if (mys.getAttribute("classFtypeId")!=null)
            tid= (String)mys.getAttribute("classFtypeId");

        fid2AnnoNums =  (HashMap )mys.getAttribute("fid2AnnoNums");
        if (tid != null)
            classFtypeId = Integer.parseInt(tid);
            totalAnnotations = AnnotationEditorHelper.findGroupAnnotations(dbName, className, classFtypeId, classRid, response, mys, out, con);
    }
    else {
        initPage = true;
        if (proceedLargeGroup || totalNumAnno <org.genboree.util.Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN) {
        mys.setAttribute("changed", "no");
        totalAnnotations =   AnnotationEditorHelper.findGroupAnnotations(dbName, ifid, response, mys, out, con);
        if ( totalAnnotations != null &&  totalAnnotations.length>0) {
        for (i=0; i<totalAnnotations.length; i++)
        fid2Anno.put("" + totalAnnotations[i].getFid(), totalAnnotations[i]);

        className =  totalAnnotations[0].getGname();

        mys.setAttribute("classTrackName", totalAnnotations[0].getTrackName());
        mys.setAttribute("classFtypeId", "" + totalAnnotations[0].getFtypeId());
        mys.setAttribute("className", className);

        mys.setAttribute("classRid",  "" +  totalAnnotations[0].getRid());

        mys.setAttribute("totalAnnotations", totalAnnotations);

        for (i=0; i<totalAnnotations.length; i++) {
        int tempInt = i+1;
        fid2AnnoNums.put("" + totalAnnotations[i].getFid(), "" + tempInt);
        }
        mys.setAttribute("fid2AnnoNums", fid2AnnoNums);
        }
        }
    }

             if (proceedLargeGroup || totalNumAnno < org.genboree.util.Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN) {
            try {
                chromosomeMap = AnnotationEditorHelper.findChromosomes (db, con);
            }
            catch (Exception e)
            {
                e.printStackTrace( System.err );
                System.err.println("Error AnnotationGroupEditor.jsp #149");
                GenboreeUtils.sendRedirect(request,response,  "/java-bin/error.jsp");
            }

            if (!chromosomeMap.isEmpty()) {
                chromosomes = (String[]) chromosomeMap.keySet().toArray(new String[chromosomeMap.size()]);
            }

            Arrays.sort(chromosomes);

            mys.setAttribute("chromosomeArray", chromosomes);
            mys.setAttribute("chromosomeMap", chromosomeMap);

            try
            {
                trackMap =AnnotationEditorHelper.findTracks (db, con, genboreeUserId, dbName);
            }
            catch (Exception e) {
                e.printStackTrace( System.err );
                System.err.println("Error AnnotationGroupEditor.jsp #165");
                GenboreeUtils.sendRedirect(request,response,  "/java-bin/error.jsp");
            }

            if (trackMap == null || chromosomeMap == null || trackMap.isEmpty() || chromosomeMap.isEmpty())
            {
              System.err.println("Error AnnotationGroupEditor.jsp #172");
              System.err.println("No  track is null in database  " + dbName);
                GenboreeUtils.sendRedirect(request,response, "/java-bin/error.jsp");
                  return;

            }

        String newTrack =  "**New Track**";
            if (trackMap != null && trackMap.size() > 0) {
                Iterator iterator = trackMap.keySet().iterator();
                int count = 0;
                tracks = new String[trackMap.size()];
                while (iterator.hasNext()) {
                tracks[count] = (String) iterator.next();
                count++;
                }
                Arrays.sort(tracks);
                String [] newTracks = new String[tracks.length + 1] ;

                for (int n =1; n<=tracks.length; n++) {
                newTracks [n] = tracks[n-1];
                }
                newTracks [0] = newTrack;
                tracks = newTracks;
             }
            else {
                tracks = new String [] {newTrack};
            }

            mys.setAttribute("trackArray", tracks);
            mys.setAttribute("trackMap", trackMap);
            mys.setAttribute("lastPageIndex", "0");
       if (totalAnnotations  == null || totalAnnotations.length ==0) {
             if (upfid!=null) {

              GenboreeUtils.sendRedirect(request, response, "/java-bin/annotationEditorMenu.jsp?upfid="+ upfid) ;
            }
            else {   out.println ("<script> window.close(); </script>");
            }
           return;
        }

        if (className == null){
            GenboreeUtils.sendRedirect(request,response, destback);
               return;
        }

    if (totalAnnotations == null || totalAnnotations.length == 0)
    {
       if (upfid!=null) {
           GenboreeUtils.sendRedirect(request, response, "/java-bin/annotationEditorMenu.jsp?upfid="+ upfid) ;
        }
        else {   out.println ("<script> window.close(); </script>");
        }
        return;
    }
  %>
 <%@ include file="include/multipage.incl" %>
    <%
    if (page2Annotations != null &&  page2Annotations.get(currentPage) != null)
        annotations =   (AnnotationDetail []) page2Annotations.get(currentPage);
        if (annotations == null)  {
            if (upfid!=null) {
            GenboreeUtils.sendRedirect(request, response, "/java-bin/annotationEditorMenu.jsp?upfid="+ upfid) ;
            }
            else {   out.println ("<script> window.close(); </script>");
            }
            return;
        }
        if (totalAnnotations != null) {
            annotation = totalAnnotations  [0];
            vlogs = new Vector[annotations.length];
            for (i=0; i<annotations.length; i++)
            vlogs[i] = new Vector();
        }
    // end of include file
        try {
        annotationsWeb  = AnnotationEditorHelper.getAnnotationsFromWeb(annotations,request, out, chromosomeMap, trackMap , dbName,  con);
        }
        catch (Exception e) {
    //GenboreeUtils.sendRedirect(request,response, "/java-bin/error.jsp");

              e.printStackTrace(System.err);

           // GenboreeUtils.sendRedirect(request,response, "/java-bin/error.jsp");
            return;
        }
   HashMap   fid2webAnno = new HashMap();
    if (annotationsWeb != null)  {
        for (i=0; i<annotationsWeb.length ; i++) {
            if (annotationsWeb[i] != null)
             fid2webAnno.put("" + annotations[i].getFid(), annotationsWeb[i]);
        }
    }
    AnnotationDetail []  temparr = new AnnotationDetail[annotations.length];
    for (i=0; i<annotations.length ; i++) {
         if (annotationsWeb[i]!= null &&  fid2webAnno.get("" + annotations[i].getFid())!= null)
          temparr[i] = (AnnotationDetail)fid2webAnno.get("" + annotations[i].getFid());
         else   {
               temparr[i] = annotations[i];
               AnnotationEditorHelper.convertAnnotation(temparr[i] , db2jsp);
         }
    }
   annotationsWeb = temparr;
   if (request.getParameter("state")!= null)
        state = (String)  request.getParameter("state");
    if (state.compareTo("1")==0){
       state = "0";
    if (request.getParameter("btnUpdateAll") != null) {
        mys.setAttribute("saved", new Boolean(true));
        String [] selectedAnnos  = null;
        // ArrayList tempList = new ArrayList ();
        ArrayList selectedFids = new ArrayList();
        if ((selectedAnnos = request.getParameterValues("annoCheckBox")) != null) {
        for (i=0; i<selectedAnnos.length; i++)  {
        selectedFids.add("" + selectedAnnos[i]);
        }
        int numUpdated = 0;
        if (annotationsWeb == null ) {
        GenboreeUtils.sendRedirect(request,response, destback);
        }
        int validationErrors = 0;
        for (i=0; i< annotationsWeb.length; i++) {
                if (annotationsWeb[i] == null)
                continue;

                if (!selectedFids.contains ("" + annotationsWeb[i].getFid()))
                continue;

            if (AnnotationEditorHelper.validateAnnotation(i, annotationsWeb[i], trackMap, mys, request,  errorFields,  vlogs[i],  chromosomeMap, out, upload.getDatabaseName(), con))
            {
            long startw = annotationsWeb[i].getStart();
            long startdb = annotations[i].getStart();
            long stopw = annotationsWeb[i].getStop();
            long stopdb = annotations[i].getStop();
            if (startw != startdb  || stopw != stopdb ) {
            String  fbin = (Refseq.computeBin(startw, stopw, 1000));
            annotationsWeb[i].setFbin(fbin);
            }
            page2WebAnnos.put(currentPage, annotationsWeb);
            mys.setAttribute("webAnnotations", page2WebAnnos);

            AnnotationDetail anno = AnnotationEditorHelper.convertAnnotation(annotationsWeb[i], jsp2db);
            int fidInt  = AnnotationEditorHelper.isDupAnnotation(dbName, anno, con);
            boolean isFDataDup = false;
            boolean isTextDup = false;
            if (fidInt > 0)   {
                isFDataDup = true;
                isTextDup = AnnotationEditorHelper.isDupText(dbName, fidInt,  anno, con);
            }

        boolean updated = false;
        if (!isFDataDup) {
            AnnotationEditorHelper.updateAnnotation(anno, db, upload, out, con);
            int rid =  anno.getRid();
            int ftypeid = anno.getFtypeId();
            String gname = anno.getGname();

            if (rid != classRid || ftypeid != classFtypeId || gname.compareTo(className) != 0 )  {
            DrawParams params = new DrawParams();
            params.rid = "" + rid;
            params.gname = gname;
            params.ftypeid = "" + ftypeid;
            drawList.add(params);
            }
            updated = true;
        }

        if ( !isTextDup) {
            int id = anno.getFid();
            if (isFDataDup)
            id = fidInt;

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
            updated = true;
            }
        }
    //    if (useAVP) {
            String avpValues = request.getParameter("avpvalues_"+ i);
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
             GenboreeUtils.addValuePairs(con,  ""+upload.getRefSeqId(), anno.getFid(), anno.getFtypeId(), avp , 0);

                   int [] arr = new int [] {  anno.getFid()};
                AnnotationEditorHelper.updateFeature2AVPName(anno.getFtypeId(), arr, con);

               if (con == null || con.isClosed()) {
                  con = db.getConnection(dbName);
                }

                 updated = true;
                };
          //  }
         mys.setAttribute("lastPageIndex", currentPage);
         if ( updated){
            //AnnotationDetail anno1 = null;
            numUpdated  ++;
            boolean classChanged = false;
            if (annotationsWeb[i].getGname().compareTo(annotations[i].getGname()) != 0 )
            classChanged = true;

            if (annotationsWeb[i].getRid()!= annotations[i].getRid())
            classChanged = true;

            if (annotationsWeb[i].getTrackName().compareTo(annotations[i].getTrackName()) != 0 )
            classChanged = true;

            if (classChanged) {
            annotations[i].setFlagged(true);
            annotationsWeb[i].setFlagged (true);
            }
            String tempTrack =  request.getParameter("track_" + i );
            if (tempTrack != null && tempTrack.indexOf("New Track") >0) {
                String []   newTracks = new String[tracks.length + 1] ;
                String type =   request.getParameter("type_" + i );
                String subtype = request.getParameter("subtype_" + i );
                if (  type!= null && subtype != null){
                    type = type.trim();
                    subtype = subtype.trim();
                    if (type.length() > 0 && subtype.length() > 0 ) {
                        tracks[tracks.length-1] = type+ ":" + subtype;
                        Arrays.sort(tracks);
                        for (int n=0; n<tracks.length; n++)
                        newTracks[n] = tracks [n];
                        newTracks[tracks.length ] =  "**New Track**";
                        tracks = newTracks;
                    }
                }
            }    // end of new track
        }
            annotations[i] = anno;
            }   // end of validate
            else {
                validationErrors++;
            }
        } // end of for loop

    if ( numUpdated >0 ) {
            DrawParams params = new DrawParams();
            params.rid = "" + classRid;
            params.gname = className;
            params.ftypeid = "" + classFtypeId;
            drawList.add(params);
            totalAnnotations = AnnotationEditorHelper.findGroupAnnotations(dbName, className, classFtypeId, classRid, response, mys, out, con);
            doPaging = true;
            mys.setAttribute("lastPageIndex", currentPage);
        %>
        <%@ include file="include/multipage.incl" %>
        <%
            if (page2Annotations != null &&  page2Annotations.get(currentPage) != null)
            annotations =   (AnnotationDetail []) page2Annotations.get(currentPage);
            else if (page2Annotations != null &&  page2Annotations.get(currentPage)== null) {
                int temp = currentPageIndex  + 1;
                if (page2Annotations.get("" + temp)!= null) {
                currentPage = "" + temp;
                currentPageIndex = temp;
                mys.setAttribute("lastPageIndex", currentPage);
                }
                else {
                    temp = currentPageIndex -1;
                    if (temp <0)
                        temp=0;
                    currentPage = "" +temp;
                    currentPageIndex = temp;
                    mys.setAttribute("lastPageIndex", currentPage);
                }
            }
           AnnotationDetail[] tempArr = annotations;
            HashMap fid2webanno = new HashMap();
            if (annotations != null && annotationsWeb != null && annotationsWeb.length >0){
                for (int k=0; k<annotationsWeb.length ; k++) {
                    if (annotationsWeb[k] != null ) {
                    fid2webanno.put("" + annotationsWeb[k].getFid() , annotationsWeb[k]);
                    }
                }
            }
            if (annotations != null) {
                for (int k=0; k<annotations.length ; k++) {
                    if ((annotationsWeb[k] != null) &&  (fid2webanno.get("" + annotations[k].getFid())!=null))
                    {
                        tempArr[k] = (AnnotationDetail)fid2webanno.get("" + annotations[k].getFid());
                    }
                    else{
                    AnnotationEditorHelper.convertAnnotation( annotations[k], db2jsp);
                    }
                }
            }
            annotationsWeb = tempArr;

            page2WebAnnos.put(currentPage,  annotationsWeb)  ;
            //mys.setAttribute("webAnnotations", page2WebA
            mys.setAttribute("webAnnotations", page2WebAnnos);

            errorMsg ="";
            ArrayList messageList   = new ArrayList();
            String s = numUpdated > 1? " annotations  were updated. ": " annotation was updated";
            messageList.add("" + numUpdated + s );
            GenboreeMessage.setSuccessMsg(mys, "The operation was successful", messageList);
            refreshGbrowser = true;

            if (annotations == null )
                annotations = new AnnotationDetail[0];
    } // num updated >0
            else  {
                successAll = "";
                //  no updated could be from 2 cases: a, no chnage b. chnaged annotation already exist
                // in latter case, all to be done is delete from current
                if ( validationErrors ==0) {
             //  GenboreeMessage.setErrMsg(mys, "Identical annotations exist in database. ") ;
                }
            }
       }
       else {
               GenboreeMessage.setErrMsg(mys, "Identical annotations exist in database. ") ;
            }       // end of selected andos
         }  // end of upodateAll


   if (annotations != null && annotations.length >0) {
       for(i=0; i<annotations.length; i++) {
             if (request.getParameter("btnUpdate_" + i) != null) {
                   mys.setAttribute("saved", new Boolean(true));
                   vLog = new Vector();
                   vlogs[i] = new Vector();
                   page2WebAnnos.put(currentPage,  annotationsWeb)  ;
                   mys.setAttribute("webAnnotations", page2WebAnnos);
                 if (AnnotationEditorHelper.validateAnnotation(i,annotationsWeb[i], trackMap,mys,  request,  errorFields,  vlogs[i],  chromosomeMap, out, upload.getDatabaseName(), con))  {
                      page2WebAnnos.put(currentPage,  annotationsWeb)  ;
                      mys.setAttribute("webAnnotations", page2WebAnnos);
                      long startw = annotationsWeb[i].getStart();
                      long startdb = annotations[i].getStart();
                      long stopw = annotationsWeb[i].getStop();
                      long stopdb = annotations[i].getStop();
                      if ( startw  != startdb  || stopw != stopdb ) {
                            String  fbin = (Refseq.computeBin(startw, stopw, 1000));
                            annotationsWeb[i].setFbin(fbin);
                        }
                        AnnotationDetail anno = AnnotationEditorHelper.convertAnnotation(annotationsWeb[i], jsp2db);

                        boolean updated = false;
                        int fidInt  = AnnotationEditorHelper.isDupAnnotation(dbName, anno, con);

                        boolean isFDataDup = false;
                        boolean isTextDup = false;
                        if (fidInt > 0)   {
                        isFDataDup = true;
                        isTextDup = AnnotationEditorHelper.isDupText(dbName, fidInt,  anno, con);
                        }

                        if (!isFDataDup) {
                          AnnotationEditorHelper.updateAnnotation(anno, db, upload, out, con);
                            int refseqid = upload.getRefSeqId();
                            int  ftypeid =  anno.getFtypeId();
                            String gname = anno.getGname();
                            int rid =  anno.getRid();

                                GenboreeUtils.processGroupContextForGroup(""+refseqid,  gname,  "" +  classFtypeId,  "" + classRid, false);
                            GenboreeUtils.processGroupContextForGroup(""+refseqid,  className,  "" + classFtypeId,  "" + classRid, false);
                            updated = true;
    }
    if ( !isTextDup) {
    int id = anno.getFid();
    if (isFDataDup)
    id = fidInt;

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
    updated = true;
    }
    }
    // the following code update AVP
  //  if (useAVP) {
    String avpValues = request.getParameter("avpvalues_"+ i);
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
    GenboreeUtils.addValuePairs(con,  ""+upload.getRefSeqId(), anno.getFid(), anno.getFtypeId(), avp , 0);
    updated = true;
    };
   // }

    mys.setAttribute("lastPageIndex", currentPage);
    if (updated){
        String wtrackName = anno.getTrackName();
        if (wtrackName != null)
        wtrackName = wtrackName.trim();
        String gNameWeb = anno.getGname();
        gNameWeb = gNameWeb.trim();
        boolean haschanged = false;
        if (gNameWeb.compareTo(className) !=0  || wtrackName.compareTo(classTrackName)!=0 || anno.getRid() != classRid)
        haschanged = true;

    // if name changed, move to new group
    // else, keep the same group
        if(haschanged){
        annotations[i].setFlagged(true);
        annotationsWeb[i].setFlagged(true);
        }

        String tempTrack =  request.getParameter("track_" + i );
        if (tempTrack != null && tempTrack.indexOf("New Track") >0) {
        String []   newTracks = new String[tracks.length + 1] ;
        String type =   request.getParameter("type_" + i );
        String subtype = request.getParameter("subtype_" + i );
        if (  type!= null && subtype != null){
        type = type.trim();
        subtype = subtype.trim();
        if (type.length() > 0 && subtype.length() > 0 ) {
        tracks[tracks.length-1] = type+ ":" + subtype;
        Arrays.sort(tracks);
        for (int  n=0; n<tracks.length; n++)
        newTracks[n] = tracks [n];
        newTracks[tracks.length ] =  "**New Track**";
        tracks = newTracks;
        }
        }
        } // end of new track

        int   n = i+1;
        totalAnnotations = AnnotationEditorHelper.findGroupAnnotations(dbName, className, classFtypeId, classRid, response, mys, out, con);
        doPaging = true;

        %>
        <%@ include file="include/multipage.incl" %>
        <%
        if (page2Annotations != null &&  page2Annotations.get(currentPage) != null)
        annotations =   (AnnotationDetail []) page2Annotations.get(currentPage);
        else   if (page2Annotations != null &&  page2Annotations.get(currentPage)== null) {
        int temp = currentPageIndex  + 1;
        if (page2Annotations.get("" + temp)!= null) {
        currentPage = "" + temp;
        currentPageIndex = temp;
        mys.setAttribute("lastPageIndex", currentPage);
        }
        else {

        temp = currentPageIndex -1;
        if (temp <0)
        temp=0;
        currentPage = "" +temp;
        currentPageIndex = temp;
        mys.setAttribute("lastPageIndex", currentPage);
        }
        }
        AnnotationDetail[] tempArr = annotations;
        HashMap fid2webanno = new HashMap();
        if (annotations != null && annotationsWeb != null && annotationsWeb.length >0){

        for (int k=0; k<annotationsWeb.length ; k++) {
        if (annotationsWeb[k] != null ) {
        fid2webanno.put("" + annotationsWeb[k].getFid() , annotationsWeb[k]);
        }
        }
        }

        if (annotations != null) {
        for (int k=0; k<annotations.length ; k++) {

        if ((annotationsWeb[k] != null) &&  (fid2webanno.get("" + annotations[k].getFid())!=null))
        {
        tempArr[k] = (AnnotationDetail)fid2webanno.get("" + annotations[k].getFid());
        }
        else{
        AnnotationEditorHelper.convertAnnotation( annotations[k], db2jsp);
        }

        }
        }
        annotationsWeb = tempArr;
        page2WebAnnos.put(currentPage,  annotationsWeb)  ;
        //mys.setAttribute("webAnnotations", page2WebAnnos);
        ArrayList successList = new ArrayList();
        successList.add("Annotation  is updated." );
        GenboreeMessage.setSuccessMsg(mys, "Operation was successful:", successList);
        refreshGbrowser = true;
        }
        else {
        vlogs[i].add("Identical annotation exist in database.  ");
        }
        } // end of validate
        else
        {
        refreshGbrowser = false;
        }
        break;
        }
        }
        }
    }

        if (annotations == null )
        annotations = new AnnotationDetail[0];

        if (annotations != null) {
        validateForm = "return validateForm(" + annotations.length + ")";
        resetAll = "resetAll(" + annotations.length + ")";
        }

        if (totalAnnotations != null && totalAnnotations.length>0) {
        for (i=0; i<totalAnnotations.length; i++) {
        if (totalAnnotations[i] != null  && !totalAnnotations[i].isFlagged())
        numOK++;
        }
        }
        String [] ids =  request.getParameterValues("annoCheckBox");

        if ( !initPage &&  ids != null) {
        changed = "1";
        mys.setAttribute("changed", "yes");
        }

        changed = (String)mys.getAttribute("changed") ;
        if (changed != null && changed.compareTo("yes") == 0)  {
        changed = "1";
        }
        else if (changed != null && changed.compareTo("no") == 0)  {
        changed ="0";
        }

        if (request.getParameter("upfid")!=null)
        {mys.removeAttribute("saved");}
        else{
            Object o = mys.getAttribute("saved");
            if (o!=null) {
            Boolean B  = (Boolean)o;
            saved = B.booleanValue();
            }
        }
    }//
 %>
<HTML>
<HEAD>
    <TITLE>Genboree - Annotation Group Editor</TITLE>
    <LINK rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
    <LINK rel="stylesheet" href="/styles/annotationEditor.css<%=jsVersion%>" type="text/css">
    <META HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
    <SCRIPT TYPE="text/javascript" SRC="/javaScripts/groupAnnotationEditor.js<%=jsVersion%>"></SCRIPT>
    <SCRIPT TYPE="text/javascript" SRC="/javaScripts/groupEditorDelimit.js<%=jsVersion%>"></SCRIPT>
    <SCRIPT TYPE="text/javascript" SRC="/javaScripts/editorCommon.js<%=jsVersion%>"></SCRIPT>
    <SCRIPT TYPE="text/javascript" SRC="/javaScripts/prototype.js<%=jsVersion%>"></SCRIPT>
    <LINK rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">
    <link rel="stylesheet" href="/styles/avp.css<%=jsVersion%>" type="text/css">
    <link rel="stylesheet" href="/styles/querytool.css<%=jsVersion%>" type="text/css">
    <script type="text/javascript" src="/javaScripts/util.js<%=jsVersion%>"></script>
    <script src="/javaScripts/commonFunctions.js<%=jsVersion%>" type="text/javascript"></script>
    <script src="/javaScripts/attributeValuePairs.js<%=jsVersion%>"  type="text/javascript"></script>
    <script src="/javaScripts/prototype.js<%=jsVersion%>" type="text/javascript"></script>
    <SCRIPT type="text/javascript" src="/javaScripts/json.js<%=jsVersion%>"></SCRIPT>
    <%@ include file="include/colorWheelFiles.incl" %>
</HEAD>
<BODY>
 <%if (proceedLargeGroup || totalNumAnno <Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN) {  %>
<%@ include file="include/header.incl" %>
<%}%>
<%@ include file="include/validateFid.incl" %>
<%@ include file="include/redir.incl" %>
<form name="<%=formId%>" id="<%=formId%>" action="<%=redir%>" method="post" onSubmit="<%=validateForm%>" >
<input type="hidden" name="chosenAnno" id="chosenAnno" value="-1" >
<input type="hidden" name="state" id="state" value="<%=state%>">
<input type="hidden" name="currentPage" id="currentPage" value="<%=currentPage%>">
<input type="hidden" name="editPage" id="editPage" value="1">
<input type="hidden" name="cancelState" id="cancelState" value="0">
<input type="hidden" name="navigator" id="navigator" value="home">
<input type="hidden" name="changed" id="changed" value="<%=changed%>">
<%@ include file="include/largeGrpConfirm.incl" %>
<%if (proceedLargeGroup || totalNumAnno <Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN) {  %>
<TABLE width="100%" border="0" cellpadding="2" cellspacing="2">
   <%
       if (annotations != null && annotations.length>0 && numOK >0) {
// if (!emptyAnno) {

   %>
<TR align="center">
<TD  class="form_body">
<TABLE width="100%" border="1" cellpadding="0" cellspacing="0">
<TR>
<TD>
<div align="center" class="title4">
Annotation Editor
<br>   For&nbsp;Group &nbsp;  &quot;<%=className%>&quot;
</div>
</TD>
</TR>
</TABLE>
</TD>
</TR>
<%if (totalAnnotations != null && totalAnnotations.length>5) {%>
<%@ include file="include/mp_pageIndex.incl" %>
<%}}%>
<TR>
<TD>
<%@ include file="include/message.incl" %>
</TD>
</TR>

    <TR align="center" >
        <TD>
        <table>
        <TR>   <BR>
            <TD class="helpNav"><NOBR>
                <%if (annotations != null && annotations.length>0 && numOK >0 ) {%>
                <input  type="submit" class="btn"  name="btnUpdateAll" id="btnUpdateAll"  value=" Update All In Page"   width="120" HEIGHT="110" onClick="choseAllAnno(<%=annotations.length%>)"  > &nbsp;
                <input  type="reset" class="btn"  name="btnResetAll" id="btnResetAll"  value="  Reset All In Page" onClick="<%=resetAll%>"  >&nbsp; &nbsp;
                <% if (!saved) {%>
                <input  type="button" name="btnClose" id="btnClose" value="Cancel"  class="btn"  onClick="ask4quit ();" >
                <%} else { %>
                       <input  type="button" name="btnClose" id="btnClose" value="Close Window"  class="btn"  onClick="processQuit('', '', <%=true%>); " >
                <%}%>

                &nbsp;   &nbsp;
                </NOBR>
                <a class="helpNav" href="showHelp.jsp?topic=top" target="_helpWin">
                Help<IMG class="helpNavImg" SRC="/images/gHelp3.png" BORDER="0" WIDTH="16" HEIGHT="16">
                </a>
                <%} else  {%>
                <input  type="button" name="btnClose" id="btnClose" value="Close Window"  class="btn15"  onClick="window.close();" >
                <%} %>
            </TD>
        </TR>
        </table>
        </TD>
    </TR>
<%
if ( annotations != null && annotations.length>0 )  {%>
    <SCRIPT type="text/javascript">
        var colorArr = new Object();
        <%
        String messageid = "";
for (i = 0; i < annotations.length; i++) {   %>
        <%@ include file="include/setColor.incl" %>
        colorArr[<%=i%>] = '<%=curColor%>';
        <%     annotations[i] = AnnotationEditorHelper.convertAnnotation(annotations[i], db2jsp);
        }
        %>
    </script>
<%   for (i=0; i< annotations.length; i++) {
        annotation = annotations[i];
        orderNum = "" + i;
        if (annotation == null || annotation.isFlagged())
            continue;
        else {
         if (fid2AnnoNums.get ("" + annotation.getFid()) != null)
         {
            orderNum =  (String)fid2AnnoNums.get ("" + annotation.getFid()) ;
         }
        }

        Chromosome chromosome = (Chromosome)chromosomeMap.get(annotation.getChromosome());
        String annoid = "anotations_" + i ;
        String checkBoxId = "checkBox_" +i;
        if (vlogs[i] == null)
        vlogs[i] = new Vector();
        messageid = "message_" + i;

        int currentIndex = 0;
        HashMap name2Values = new HashMap ();
        fid = "" + annotation.getFid();
    %>
       <% // if(useAVP){ %>
    <%@ include file="include/avpPopulator.incl" %>
         <input type="hidden" name="avpvalues_<%=i%>" id="avpvalues_<%=i%>" value="">
         <input type="hidden" name="index_<%=i%>" id="index_<%=i%>" value="<%=currentIndex%>">
      <%// } %>
        <% if (i>0) { %>
        <TR> <TD>&nbsp;</TD></TR>
        <%}%>
    <TR>
    <TD>
    <%
    String tableid = "infoTable" + orderNum ;
    if (vlogs != null && vlogs[i]!= null) {
    vLog = vlogs[i];
    }
    if( vLog != null) {
    %>
    <div id="<%=messageid%>" class="annotation1" >
        <%
        out.println( " <UL class=\"compact2\">" );
        for( int n=0; n<vLog.size(); n++ )
            out.println( "<li>&middot; " + ((String)vLog.elementAt(n)) +"</li>" );
        out.println( "</ul>" );
        %>
    </div>
    <% }
      %>
    <TABLE width="100%"  border="1" cellpadding="0" cellspacing="0">
    <TR align="center">
    <TD class="form_body">
    <center>
    <div style="display:none">
    <input type="checkbox" name="annoCheckBox" id="<%=checkBoxId%>" value="<%=annotations[i].getFid()%>"  >
    </div>
    &nbsp; &nbsp;  &nbsp; &nbsp;
    <FONT SIZE="2"><B>  <%=annotations[i].getGname()%> <%="("%>Annotation
    <%=orderNum%> <%=")"%> </B></FONT>
    </center>
    </TD>
    </TR>
    </TABLE>

    <TABLE width="100%" id="<%=tableid%>"  border="1" cellpadding="2" cellspacing="1">
    <TR>
    <% String gnameLabel = "gnameLabel" + i ;
    String gnameid = "gname_" + i ;
    if ( errorFields.get("gname_" + i ) != null) {
    %>
    <TD class="annotation1" colspan="1">
    <div id="<%=gnameLabel%>" >
    <B>Annotation&nbsp;Name</B>
    </div>
    </TD>
    <%
      errorFields.remove("gname_" + i );
    }
    else {
    %>
    <TD class="annotation2" colspan="1">
    <div id="<%=gnameLabel%>" > <B>Annotation&nbsp;Name</B></div>
    </TD>
    <%}
    String trackLabel = "trackLabel" + i ;
    String trackRowID = "trackRow_" + i ;
    String newTrackRowID = "newTrackRow_" + i ;
    %>
    <TD class="annotation2" colspan="3">
    <input type="text" name="<%=gnameid%>" id ="<%=gnameid%>" class="largeInput"  maxlength="200" value="<%=Util.htmlQuote(annotation.getGname()) %>"   onChange="markAnnotation('<%=checkBoxId%>')" >
    </TD>
    </TR>
    <TR id="<%=trackRowID%>" >
    <TD ALIGN="left" class="annotation2" colspan="1">
    <div id="<%=trackLabel%>"><B>Track</B></div>
    </TD>
    <%   String trackid = "track_" + i ;
    String checkTrack = "checkNewTrack(" + i  + ", '" + checkBoxId + "' )";
    String typeid = "type_" + i ;
    String typeLabel = "typeLabel_" + i ;
    String subtypeid = "subtype_" + i ;
    String subtypeLabel = "subtypeLabel_" + i ;

    String type = "";
    String subtype = "";
    %>
    <TD class="annotation2" colspan="1">
    <select class="longDroplist" name="<%=trackid%>" id="<%=trackid%>" BGCOLOR="white" onchange="<%=checkTrack%>">
            <%
          if (tracks != null)  { for (int j=0; j<tracks.length; j++) {
            String sel = "";
            if (tracks[j] != null && annotation.getTrackName() != null && tracks[j].compareTo(annotation.getTrackName()) ==0 && errorFields.get("newTrackRow") == null )
            sel = " selected";
            else if (errorFields.get("newTrackRow") != null &&  j == (tracks.length -1))
            sel = " selected";
            %>
            <option  value="<%=Util.htmlQuote(tracks[j])%>" <%=sel%>> <%=Util.htmlQuote(tracks[j])%>  </option>
            <%}}%>
            </select>
            </TD>
   <TD ALIGN="center" class="annotation2" colspan="2">
 <%@ include file="include/setColor.incl" %>
   <%
   String colorImageId ="colorImageId" + i;
   String hiddenInputId ="hiddenInputId" + i;
    String isDefaultColorId ="isDfcolorId" + i;
    if (curColor != null)
       curColor = curColor.replaceAll ("#", "");
   %>
   <a href="javascript:void null;"  id="wheellink"  onClick="markAnnotation('<%=checkBoxId%>')" >
   <div name="<%=colorImageId%>" id="<%=colorImageId%>"  class="colorIconLong"
style="background-color:<%=curColor%>"  onClick="setDivIdndfColor('<%=colorImageId%>', '<%=hiddenInputId%>', '<%=curColor%>', '<%=isDefaultColorId%>');" >
   </div>
   <div class="bottomdivLong" onClick="setDivIdndfColor('<%=colorImageId%>', '<%=hiddenInputId%>', '<%=curColor%>', '<%=isDefaultColorId%>');">&nbsp;&nbsp;Set Annotation Color</div>
   </a>
    <input type="hidden" name="isDefaultColor" id="<%=isDefaultColorId%>" value="<%=isDefaultColor%>" >
   <input type="hidden" name="<%=hiddenInputId%>" id="<%=hiddenInputId%>" value="#<%=curColor%>"  >
</TD>
</TR>
            <%
            String display = trackRowID + ".style.display";
            String  trackNameN = annotation.getTrackName();
            if (errorFields.get("newTrackRow") != null) {
                    errorFields.remove("newTrackRow");
            %>
            <TR id="<%=newTrackRowID%>"  style="<%=display%>">
            <TD class="annotation2" id="<%=typeLabel%>" style="color:red" >
            <B>Track&nbsp;Type</B>
            </TD>
            <TD class="annotation2" >
            <input type="text" class="longInput" maxlength="20" name="<%=typeid%>" id="<%=typeid%>" value="<%=Util.htmlQuote(type)%>">
            </TD>

        <TD class="annotation2" id="<%=subtypeLabel%>"  style="color:red">
        <B>Track&nbsp;Subtype</B>
    </TD>

    <TD class="annotation2" >
    <input type="text" class="longInput" maxlength="20" name="<%=subtypeid%>" id="<%=subtypeid%>" value="<%=Util.htmlQuote(subtype)%>">
    </TD> </TR>

    <%}
    else if ((errorFields.get("newTrackRow") == null) && (trackNameN.indexOf("New Track") >=0)) { %>
    <TR id="<%=newTrackRowID%>"  style="<%=display%>">
    <TD class="annotation2" id="<%=typeLabel%>" style="color:#403c59" >
    <B>Track&nbsp;Type</B>
    </TD>
    <TD class="annotation2" >
    <input type="text" class="longInput" maxlength="20" name="<%=typeid%>" id="<%=typeid%>" value="<%=Util.htmlQuote(type)%>">
    </TD>

    <TD class="annotation2" id="<%=subtypeLabel%>"  style="color:#403c59">
    <B>Track&nbsp;Subtype</B>
    </TD>

    <TD class="annotation2" >
    <input type="text" class="longInput" maxlength="20" name="<%=subtypeid%>" id="<%=subtypeid%>" value="<%=Util.htmlQuote(subtype)%>">
    </TD> </TR>

    <%   }
    else if (errorFields.get("newTrackRow") == null) {
    %>
    <TR id="<%=newTrackRowID%>"  style="display:none">

    <TD class="annotation2" id="<%=typeLabel%>" style="color:#403c59">
    <B>Track&nbsp;Type</B>
    </TD>
    <TD class="annotation2" >
    <input type="text" class="longInput" maxlength="20" name="<%=typeid%>" id="<%=typeid%>"  value="<%=Util.htmlQuote(type)%>">
    </TD>

    <TD class="annotation2" id="<%=subtypeLabel%>"  style="color:#403c59">
    <B>Track&nbsp;Subtype</B>
    </TD>

    <TD class="annotation2" >
    <input type="text" class="longInput" maxlength="20" name="<%=subtypeid%>" id="<%=subtypeid%>" value="<%=Util.htmlQuote(subtype)%>">
    </TD>  </TR>
    <% } %>

    <%
    chromosomeid = "chromosome_" + i ;
    String chromosomeLabel = "chromosomeLabel" + i ;
    if (chromosomes != null && chromosomes.length >0 && chromosomes.length <=org.genboree.util.Constants.GB_MAX_FREF_FOR_DROPLIST ) {  %>
    <TR> <TD ALIGN="left" class="annotation2" colspan="1">
    <div id="<%=chromosomeLabel%>"><B>Chromosome</B>
    </div></TD>
    <TD class="annotation2" colspan="1">
    <select name="<%=chromosomeid%>" id="<%=chromosomeid%>"  class="longDroplist" BGCOLOR="white" onChange="markAnnotation('<%=checkBoxId%>')" >
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
    </select> </TD>   <TD ALIGN="left" class="annotation2" colspan="2">&nbsp;</TD></TR>
    <!-- if number of entry points = 1 or more than 50 , make a textfield instead of drop list-->
    <%
    }
    else if (chromosomes != null && (chromosomes.length > org.genboree.util.Constants.GB_MAX_FREF_FOR_DROPLIST )  && (errorFields.get("chromosome_" + i)==null) ){

    %>
    <TR>
    <TD ALIGN="left" class="annotation2" colspan="1"><div id="<%=chromosomeLabel%>"><B>Chromosome</B></div></TD>
    <TD class="annotation2" colspan="1">
    <input type="text"  name="<%=chromosomeid%>"  id="<%=chromosomeid%>" class="longInput" value="<%=annotation.getChromosome()%>"  onChange="markAnnotation('<%=checkBoxId%>')">
    </TD>   <TD ALIGN="left" class="annotation2" colspan="2"></TD></TR>
    <% }
    else if (chromosomes != null && (chromosomes.length > org.genboree.util.Constants.GB_MAX_FREF_FOR_DROPLIST ) && (errorFields.get("chromosome_"+ i)!=null) )  {
    %>
    <TR>
    <TD ALIGN="left" class="annotation1" colspan="1"><div id="<%=chromosomeLabel%>"><B>Chromosome</B></div></TD>
    <TD class="annotation2" colspan="1">
    <input type="text"   name="<%=chromosomeid%>" id="<%=chromosomeid%>"  class="longInput" value="<%=annotation.getChromosome()%>">
    </TD>   <TD ALIGN="left" class="annotation2" colspan="2"></TD></TR>
    <%
    // errorFields.remove("chromosome");
    }
    else {
    %>
    <TD ALIGN="left" class="annotation2" colspan="1"><div id="<%=chromosomeLabel%>"><B>Chromosome</B></div></TD>
    <TD class="annotation2" colspan="1">
    <input type="text" name="<%=chromosomeid%>" id="<%=chromosomeid%>" class="longInput" value="<%=annotation.getChromosome()%>"  onChange="markAnnotation('<%=checkBoxId%>')">
    </TD>
    <TD ALIGN="left" class="annotation2" colspan="2"></TD>
    <%
        }
    %>
    <TR>
    <%
    String startid = "annostart_" + i ;
    String stopid = "annostop_" + i ;
    String startLabel = "startLabel" + i ;
    String stopLabel = "stopLabel" + i ;
    if (errorFields.get("start_" + i )!=null) {
    %>

    <TD ALIGN="left" class="annotation1" colspan="1">
    <div id="<%=startLabel%>"><B>Start</B></div>

    </TD>
    <TD class="annotation2" colspan="1">
    <input type="text" class="longInput" maxlength="50"  name="<%=startid%>" id="<%=startid%>"  value="<%=annotation.getFstart()%>"  onChange="markAnnotation('<%=checkBoxId%>')">
    </TD>
    <%
    errorFields.remove("start_" + i );
    }
    else {
    errorFields.remove("start_" + i  );
    %>
    <TD ALIGN="left" class="annotation2" colspan="1">
    <div id="<%=startLabel%>"><B>Start</B></div></TD>
    <TD class="annotation2" colspan="1">
    <input type="text"  class="longInput" name="<%=startid%>" id="<%=startid%>"  maxlength="50" value= "<%=annotation.getFstart()%>" onChange="markAnnotation('<%=checkBoxId%>')" >
    </TD>
    <% } %>
    <% if (errorFields.get("stop_"+i )!=null ) {%>
    <TD ALIGN="left" class="annotation1" colspan="1"><div id="<%=stopLabel%>" ><B>Stop</B></div></TD>
    <TD class="annotation2" BGCOLOR="white" colspan="1">
    <input type="text" class="longInput" name="<%=stopid%>" id="<%=stopid%>"  maxlength="50" value="<%=annotation.getFstop()%>"  onChange="markAnnotation('<%=checkBoxId%>')">
    </TD>
    <%  errorFields.remove("stop_" + i );
    }
    else {
    errorFields.remove("stop_" + i );
    %>
    <TD ALIGN="left" class="annotation2" colspan="1"><div id="<%=stopLabel%>" > <B>Stop</B></div></TD>
    <TD class="annotation2" BGCOLOR="white" colspan="1">
    <input type="text" class="longInput" name="<%=stopid%>" id="<%=stopid%>" maxlength="50"  value="<%=annotation.getFstop()%>"  onChange="markAnnotation('<%=checkBoxId%>')">
    </TD>
    <%}%>
    </TR>

    <TR>
    <%
    String qstartid = "qStart_" + i ;
    String qstartLabel = "qStartLabel" + i ;
    if (errorFields.get("tstart_" + i ) == null) {
    errorFields.remove("tstart_" + i );
    %>
    <TD ALIGN="left" class="annotation2" colspan="1"><div id="<%=qstartLabel%>"><B>Query&nbsp;Start</B></div></TD>
    <!-- Target Start -->
    <TD class="annotation2" colspan="1">
    <input name="<%=qstartid%>" id = "<%=qstartid%>" type="text" BGCOLOR="white" class="longInput" maxlength="50" value="<%=annotation.getTstart()%>" onChange="markAnnotation('<%=checkBoxId%>')" >
    </TD>
    <%  } else {
    %>
    <TD ALIGN="left" class="annotation1" colspan="1"><div id="<%=qstartLabel%>"><B>Query&nbsp;Start</B></div></TD>
    <!-- Target Start -->
    <TD class="annotation2" colspan="1">
    <input name="<%=qstartid%>" id = "<%=qstartid%>" type="text" BGCOLOR="white" class="longInput" maxlength="50" value="<%=annotation.getTstart()%>"  onChange="markAnnotation('<%=checkBoxId%>')">
    </TD>
    <% }
    String qstopid = "qStop_" + i ;
    String qstopLabel = "qStopLabel" + i ;
    if (errorFields.get("tstop_" + i ) == null) {
    errorFields.remove("tstop_" + i );
    %>
    <TD ALIGN="left" class="annotation2" colspan="1"><div id="<%=qstopLabel%>"><B>Query&nbsp;Stop</B></div></TD>
    <!-- Target Stop -->
    <TD class="annotation2" colspan="1">
    <input type="text"  name="<%=qstopid%>" id="<%=qstopid%>" BGCOLOR="white" class="longInput" maxlength="50" value="<%=annotation.getTstop()%>" onChange="markAnnotation('<%=checkBoxId%>')">
    </TD>
    <% }
    else{%>
    <TD ALIGN="left" class="annotation1" colspan="1"><div id="<%=qstopLabel%>"><B>Query&nbsp;Stop</B></div></TD>
    <!-- Target Stop -->
    <TD class="annotation2" colspan="1">
    <input type="text"  name="<%=qstopid%>" id="<%=qstopid%>" BGCOLOR="white" class="longInput" maxlength="50" value="<%=annotation.getTstop()%>" onChange="markAnnotation('<%=checkBoxId%>')">
    </TD>
    <%}
    String strandid = "strand_" + i ;
    String strandLabel = "strandLabel" + i ;
    %>
    </TR>
    <TR>
    <TD ALIGN="left" class="annotation2" colspan="1"><div id="<%=strandLabel%>"><B>Strand</B></div></td>
    <!-- STRAND -->
    <!-- Put 'n/a' if Strand is null -->
    <TD class="annotation2" colspan="1" align="left">
    <select name="<%=strandid%>" class="longDroplist" id="<%=strandid%>"  BGCOLOR="white" onChange="markAnnotation('<%=checkBoxId%>')">
    <%
      String sel = "";
        for (int j=0; j<2; j++) {
        sel = "";
        if (AnnotationConstants.STRANDS[j].compareTo(annotation.getStrand()) ==0) {
        sel = " selected";
        }
        %>
        <option  value="<%=AnnotationConstants.STRANDS[j]%>" <%=sel%>> <%=AnnotationConstants.STRANDS[j]%>  </option>
        <%}
    String phaseid = "phase_" + i ;
    %>
    </select>
    </TD>
    <TD ALIGN="left" class="annotation2" colspan="1"><div id="phase"><B>Phase</B></div></TD>
    <TD ALIGN="left" class="annotation2" colspan="1">
    <select  class="longDroplist" name="<%=phaseid%>"  id="<%=phaseid%>" onChange="markAnnotation('<%=checkBoxId%>')">
    <%
      sel = "";
    for (int  j=0; j<AnnotationConstants.PHASES.length; j++) {
        sel = "";
        if (annotation.getPhase() != null){
        if (AnnotationConstants.PHASES[j].compareTo(annotation.getPhase())==0)
        sel = " selected";
        }
        else {
        if (j==0)
        sel = " selected";
        }
        %>
        <option  value="<%=AnnotationConstants.PHASES[j]%>" <%=sel%>><%= AnnotationConstants.PHASES[j]%></option>
        <%
    }
    %>
    </select>
    </TD>
    </TR>
    <TR>
    <%
    String scoreid = "score_" + i ;
    String scoreLabel = "scoreLabel" + i ;
    if (errorFields.get("score_" + i ) == null) {
    errorFields.remove("score_" + i ) ;
    %>
    <TD ALIGN="left" class="annotation2" colspan="1"><div id="<%=scoreLabel%>"><B>Score</B></div></TD>                                                     			<!-- SCORE -->
    <TD ALIGN="left" class="annotation2" colspan="1">
    <input type="text" class="longInput" name="<%=scoreid%>" id="<%=scoreid%>" BGCOLOR="white" maxlength="50" value="<%=annotation.getFscore()%>" onChange="markAnnotation('<%=checkBoxId%>')">
    </TD>
    <%   } else { %>
    <TD ALIGN="left" class="annotation1" colspan="1"><B>Score</B></TD>                                                     			<!-- SCORE -->
    <TD class="annotation2">
    <input type="text" class="longInput" name="<%=scoreid%>" id="<%=scoreid%>" BGCOLOR="white" maxlength="50" value="<%=annotation.getFscore()%>"  onChange="markAnnotation('<%=checkBoxId%>')">
    </TD>
    <% }
    %>
    <TD ALIGN="left" class="annotation2" colspan="2">&nbsp;</TD>
    </TR>

            <%@ include file="include/groupAVP.incl" %>

    <TR>
    <%
    String commentsid = "comments_" + i ;
    String commentLabel = "commentLabel" + i ;
    if (errorFields.get("comments") != null) { %>
    <TD ALIGN="left" class="annotation1" colspan="1"><div id="<%=commentLabel%>"><B>Free-Form Comment</B></div></TD>
    <%
    }
    else {
    %>
    <TD ALIGN="left" colspan="1" class="annotation2"><div id="<%=commentLabel%>"><B>Free-Form Comment</B></div></TD>
    <%
    }
    %>
    <TD align="left" class="annotation2" colspan="3">
    <TEXTAREA name="<%=commentsid%>"  id="<%=commentsid%>"  align="left" rows="4" cols="80"  class="largeTextarea" onChange="markAnnotation('<%=checkBoxId%>')" ><%=annotation.getComments()%></TEXTAREA>
    </TD>
    </TR>

    <TR>
    <%
    String sequenceid = "sequences_" + i ;
    String sequenceLabel = "sequenceLabel" + i ;
    if ( errorFields.get("sequence") != null) { %>
    <TD ALIGN="left" class="annotation1" colspan="1"><div id="<%=sequenceLabel%>"><B>Sequence</B></div></TD>
    <%    }
    else {
    %>
    <TD ALIGN="left" colspan="1" class="annotation2"><div id="<%=sequenceLabel%>"><B>Sequence</B></div></TD>
    <% } %>

    <TD align="left" class="annotation2" colspan="3">
      <TEXTAREA name="<%=sequenceid%>" id="<%=sequenceid%>" align="left" rows="4" cols="80" class="largeTextarea" onChange="markAnnotation('<%=checkBoxId%>')" ><%=annotation.getSequences()%></TEXTAREA>
    </TD>
    </TR>
    </TABLE>
    <%
    String btnUpdateId = "btnUpdate_" + i ;
    String resetId = "btnReset_" + i ;
    String resetForm = "resetAForm(" + i  + ", '" + curColor + "')" ;
    String choseAnno = "choseAnno("  + i  + ")";
    %>
    <table align="left" width="100%" border="1"   cellpadding="2" cellspacing="1" >
    <TR align="left">
    <td height="40" class="form_body">  &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
    <NOBR>
    <input  type="submit" class="btn"  name="<%=btnUpdateId%>"   id="<%=btnUpdateId%>"    value=" Update " onClick="<%=choseAnno%>" > &nbsp; &nbsp;
    <input  type="button" class="btn"  name="<%=resetId%>"   id="<%=resetId%>"  value="  Reset  "  onClick="<%=resetForm%>">&nbsp; &nbsp;
    </NOBR>
    </td>
    </TR>
    </table>
    </TD>
    </TR>
     <%} %>
       <TR align="center" >
        <TD>
        <table>    <%if (annotations != null && annotations.length>0 && numOK >0) {%>
       <TR>
        <TD class="helpNav"> <NOBR>
        <input  type="submit" class="btn"  name="btnUpdateAll" id="btnUpdateAll"  value=" Update All In Page"   width="120" HEIGHT="110" onClick="choseAllAnno(<%=annotations.length%>)"  > &nbsp;
        <input  type="reset" class="btn"  name="btnResetAll" id="btnResetAll"  value="  Reset All In Page " onClick="<%=resetAll%>"  >&nbsp; &nbsp;
          <% if (!saved) {%>
                <input  type="button" name="btnClose" id="btnClose" value="Cancel"  class="btn"  onClick="ask4quit ();" >
                <%} else { %>
           <input  type="button" name="btnClose" id="btnClose" value="Close Window"  class="btn"  onClick="processQuit('', '', <%=true%>); " >
                <%}%></NOBR>
        <a class="helpNav" href="showHelp.jsp?topic=top" target="_helpWin">
        Help<IMG class="helpNavImg" SRC="/images/gHelp3.png" BORDER="0" WIDTH="16" HEIGHT="16">
        </a>
        </TD>
        </TR>
         <%
        }
        %>
        </table>
          <br>   <br>
        </TD>
        </TR>
           <%if (totalAnnotations != null && totalAnnotations.length >  displayNum  ) {%>
              <%@ include file="include/multipageEditorBottom.incl"%>
              <%}%>
    <%if (state.compareTo("1")==0){%>
      <script> $("state").value="0"; </script>
    <%}%>
    </TABLE>
    <script>  <%=validateAll%> </script>
    <%  }
        }
     %>
    </form>
     <%@ include file="include/invalidFidMsg.incl"%>
      <%    if (proceedLargeGroup || totalNumAnno < org.genboree.util.Constants.GB_MIN_ANNO_FOR_DISPLAY_WARN) { %>
    <%@ include file="include/footer.incl" %>
     <%}%>
    </BODY>
     <%
     if (mys.getAttribute("fromDup") != null){
             refreshGbrowser = true;
             mys.removeAttribute("fromDup");
        }
      if(refreshGbrowser)
      {
        int refseqid = upload.getRefSeqId();
        for(i=0; i<drawList.size(); i++)
        {
          DrawParams params = (DrawParams)drawList.get(i);
          String rid = params.rid;
          String gname = params.gname;
          String ftypeid = params.ftypeid;
          GenboreeUtils.processGroupContextForGroup(""+refseqid,  gname, ftypeid,  rid, false);
        }
        CacheManager.clearCache(db, upload.getDatabaseName()) ;
        refreshGbrowser = false;
%>
        <script>
          confirmRefresh() ;
        </script>
<%
      }
%>

</HTML>
