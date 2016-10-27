  <%@ page import="org.genboree.dbaccess.GenboreeGroup,
java.util.*,
java.io.*,
org.genboree.message.GenboreeMessage,
org.genboree.editor.AnnotationDetail,
org.genboree.manager.tracks.Utility,
org.genboree.tabular.*,
org.genboree.tabular.AttributeRetriever,
org.genboree.tabular.LffConstants,
org.genboree.tabular.LffUtility,
org.genboree.tabular.AnnotationSorter,
org.apache.commons.validator.routines.LongValidator,
org.apache.commons.validator.routines.DoubleValidator,
org.apache.commons.validator.routines.DateValidator,
org.json.JSONObject,
org.json.JSONException,
org.json.JSONArray,
java.lang.reflect.Array,
org.genboree.util.Util"
%>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/group.incl" %>
<%@ include file="include/sessionGrp.incl" %>
<%@ include file="include/pageInit.incl" %>
<%
	int  sortingOrder = 0;
	   int mode = -1;
	String [] localfids  = null;
	String [] sharefids  = null;
	String localfidAttributes [][] = null;
	String sharefidAttributes [][] = null;
    boolean verbose = false;
    int numLocalAnnos =0;
    int numShareAnnos = 0;
    int totalNumGrpAnnotations = 0;
	boolean ascendingSort  = true;
     // initialization
    int totalNumAnnotations = 0;
    dispNum = new int []{20, 25, 50, 100, 200};
    String[] fdataSortNames = null;
    boolean hasData = true;
    boolean isLargeSamples = false;
    displayNum = 50;
    ArrayList sortList = null;
   String fidAttributes [][] = null;
    HashMap localid2Chromosome = null;
    HashMap shareid2Chromosome = null;
    HashMap localftypeid2ftype = null;
    HashMap shareftypeid2ftype = null;
    boolean sortingColumns = false;
	String groupMode = request.getParameter("groupMode");
    if (groupMode != null && groupMode.equals("verbose"))
	{	verbose = true;

	}

   if (groupMode == null)
        groupMode = "terse";

	 String pressed = request.getParameter("viewData");
    if (pressed != null && pressed.compareTo("1") == 0) {
        currentPageIndex = 0;
        currentPage = "0";
        mys.setAttribute("lastPageIndex", "0");
        mys.removeAttribute("lastStartPageNum");
        mys.removeAttribute("lastEndPageNum");
		mys.removeAttribute("");
		// start
		mys.removeAttribute("totalGroup");
		mys.removeAttribute("totalAnnotations_VGA");
		mys.removeAttribute("numPages");
		mys.removeAttribute("page2Annotation_GAV");
		mys.removeAttribute("sharedGrpAnnotations");
		mys.removeAttribute("sharedGroupName2fids");
		mys.removeAttribute("localGrpAnnotations");
		mys.removeAttribute("localGroupName2fids");
		 // end
		mys.setAttribute("lastStartPageNum", "" +  0);
        mode = LffConstants.VIEW;
        initPage = true;
        mys.setAttribute("lastMode", ""+LffConstants.VIEW);
		mys.setAttribute("groupMode", groupMode);


	}
	else {
		if (mys.getAttribute("groupMode") != null )
		 groupMode =(String) mys.getAttribute("groupMode");

		if (groupMode != null && groupMode.equals("verbose"))
		   verbose = true;
	}


	String sortingColumnName = request.getParameter("sortingColumnName");
    if (sortingColumnName!= null) {
		sortingColumnName = sortingColumnName.trim();
		sortingColumnName = Util.urlDecode(sortingColumnName);
	}
	mys.setAttribute("restrictRegion" , "false");
	String sortingColumnOrder = request.getParameter("sortingColumnOrder");
	String sortingArrow = "&nbsp;";
	if (sortingColumnOrder != null && sortingColumnOrder.length() > 0  ) {
		 if (sortingColumnOrder.equals("up"))
			 sortingArrow = "&uarr;";
		 else if (sortingColumnOrder.equals("down")) {
			 sortingArrow = "&darr;";
			ascendingSort = false;
		 }
		mys.setAttribute("sortingColumnOrder", sortingColumnOrder);
	}

    if (sortingColumnOrder != null && sortingColumnOrder.length()  >0) {
			sortingColumns = true;
			//mys.setAttribute("sortingByColumnName", "y");
	}

	int i=0;
    boolean sortingText = false;
    boolean sortByAVP = false;
    GenboreeMessage.clearMessage(mys);
    AnnotationDetail []  localGrpAnnotations = null;
    AnnotationDetail []  sharedGrpAnnotations = null;
    boolean debugging = true;
    HashMap localGroupName2fids = new HashMap ();
    HashMap sharedGroupName2fids = new HashMap ();
    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );
    GenboreeMessage.clearMessage(mys);

    //HashMap groupName2Fids = new HashMap ();
    String orderedSortNames []= null;
    String displayNames [] =  null;
    String jsparams =  request.getParameter("jsparams");

	//	if (jsparams != null)
	//		jsparams = Util.urlDecode(jsparams);
//	jsparams =   Util.htmlQuote(attributeNames[i].trim());


	 String startString =  request.getParameter("chrStart");
	String stopString =  request.getParameter("chrStop");
	String chrName =  request.getParameter("chrName");

	boolean recurPage = request.getParameter("navigator") != null;
    boolean fromSelection = request.getParameter("viewData") != null;
    boolean hasMode =   request.getParameter("mode") != null ;
    if (jsparams == null  || jsparams.length()==0) {

		if (!recurPage && !fromSelection && !hasMode) {

			GenboreeUtils.sendRedirect(request, response, "/java-bin/displaySelection.jsp");
            return;
        }
    }
    else {
        JSONObject json = new JSONObject( jsparams ) ;



		if (json != null) {
            displayNames = LffUtility.parseJson(json, "rearrange_list_1")  ;
            if (displayNames != null && displayNames.length >0)
                mys.setAttribute("displayNames",displayNames);

            if (displayNames != null)
            for (int j=0; j<displayNames.length ; j++) {
            displayNames[j] = Util.urlDecode(displayNames[j]);
            }

            orderedSortNames = LffUtility.parseJson(json, "rearrange_list2");
            if (orderedSortNames != null) {
                int index = -1;
                for (int j=0; j<orderedSortNames.length; j++) {
					orderedSortNames [j] = Util.urlDecode(orderedSortNames[j]);
					index = orderedSortNames[j].indexOf("_sort");
					if (index >0)
						orderedSortNames[j] = orderedSortNames[j].substring(0, index);
                }
            }
        }
    }

       HashMap lffConstantMap = new HashMap ();
       for (int j=0; j<LffConstants.LFF_COLUMNS.length; j++) {
            lffConstantMap.put(LffConstants.LFF_COLUMNS[j], "y");
        }

      if (orderedSortNames != null && orderedSortNames.length > 0) {
            for (i=0; i<orderedSortNames.length; i++) {
				if (orderedSortNames[i].equals(LffConstants.LFF_COLUMNS[12]))  {
				sortingText = true;
				break;
				}

				if (orderedSortNames[i].equals(LffConstants.LFF_COLUMNS[13]))  {
				sortingText = true;
				break;
				}
            }

            for (i=0; i<orderedSortNames.length; i++) {
            if (lffConstantMap.get(orderedSortNames[i]) == null)
            {
            sortByAVP = true;
            break;
            }
            }
     }

      if (request.getParameter("btnBack") != null) {
        LffUtility.clearCache(mys);
        GenboreeUtils.sendRedirect(request, response, "/java-bin/displaySelection.jsp?fromBrowser=View");
        return;
    }

    ArrayList  lffNameArrayList = new ArrayList ();
    for (i=0 ; i<LffConstants.LFF_COLUMNS.length; i++)
    lffNameArrayList.add(LffConstants.LFF_COLUMNS[i]);
    LffConstants.setHash();
    String sharedbName = null;
     ArrayList allLffColumns = new ArrayList ();
    for (i=0; i<org.genboree.tabular.LffConstants.LFF_COLUMNS.length; i++)
    allLffColumns.add(org.genboree.tabular.LffConstants.LFF_COLUMNS[i]);
    String dbName = null;
    Connection con = null;
    Connection sharedConnection = null;
     AnnotationDetail[] annotations = null;
    AnnotationDetail [] totalAnnotations = null;
    int [] localftypeids = null;
    int [] shareftypeids = null;

    int  currentIndex = 0;
    // GET NUMBER OF ANNOTATIONS PER PAGE
    int topDisplayNum = 50;
    if (request.getParameter("app") != null) {
        String temp = request.getParameter("app");
        topDisplayNum = Integer.parseInt(temp);
    }

    String sessionDisplayNum = null;
    if (mys.getAttribute("displayNum") != null) {
        sessionDisplayNum =   (String)mys.getAttribute("displayNum");
        int sessionNum  = Integer.parseInt(sessionDisplayNum);
        displayNum = sessionNum;
        if (sessionNum != topDisplayNum ) {
            displayNum = topDisplayNum;
            paging = true;
        }
        mys.setAttribute("displayNum", ""+displayNum);
    }

  int genboreeUserId = Util.parseInt( myself.getUserId(), -1 );

    ArrayList avpDisplayNameList = new ArrayList ();
    String totalCount =  (String)mys.getAttribute("totalCount") ;
     ArrayList  lffSortNameList  = new ArrayList ();

    Refseq rseq = null;
    HashMap localftypeid2Gclass = null;
    HashMap shareftypeid2Gclass = null;

    String viewDisplay="block";

    ArrayList avpSortNameList  = new ArrayList ();
    String currentMode = request.getParameter("mode");
    if (currentMode != null) {
        for (i=0; i<LffConstants.modeIds.length; i++) {
        if (currentMode.equals(LffConstants.modeIds[i])) {
        mode = i ;
        break;
        } }
    }

    if ( request.getParameter("View") != null) {
        mode = LffConstants.VIEW;
     }


	//out.println("<br>session group mode " + groupMode  + " verbose " + verbose );

	if (mys.getAttribute("lastStartPageNum") != null)
        sstartPageNum = (String )mys.getAttribute("lastStartPageNum");

    if ( request.getParameter("navigator") != null && request.getParameter("download") == null )
        mode = LffConstants.VIEW;

    if (rseqs== null || rseqs.length==0 && mode >=0)
        GenboreeMessage.setErrMsg(mys, "Sorry, there is no database in this group. <br> -- Please create a database and try again.");

    dbName = SessionManager.getSessionDatabaseName(mys);
    if (dbName == null) {

	   GenboreeUtils.sendRedirect(request, response, "/java-bin/displaySelection.jsp");
       return;
    }
     String [] dbNames = null;
    if (mys.getAttribute("dbNames") != null)
        dbNames = (String [])mys.getAttribute("dbNames");

    String sharedTrackId  = null;

    if ( mys.getAttribute("ftypeid2sharedbNames") != null)  {
        HashMap map = (HashMap)mys.getAttribute("ftypeid2sharedbNames");
        sharedTrackId = ((String[])map.keySet().toArray(new String [map.size()]))[0];
        sharedbName = (String)map.get( sharedTrackId);
    }

    if (dbNames != null   && sharedbName == null) {
        for (i=0; i<dbNames.length; i++) {
         if (!dbNames[i].equals(dbName)) {
        sharedbName = dbNames [i];
        break;
        }}
    }
    if (dbName != null)
        con = db.getConnection(dbName);
    if (sharedbName != null)
        sharedConnection = db.getConnection(sharedbName);

    if (mys.getAttribute("localftypeids") != null)  {
        localftypeids =(int []) mys.getAttribute("localftypeids");
    }

    HashMap localftype2chromsomeMap  = new HashMap ();
    if (con != null )
        localftype2chromsomeMap = GroupHelper.mapftypeid2chromsome (con, out);

       // first, display all names for selection
    if (localftypeids != null)
        numLocalAnnos  = Utility.countAnnotations(con, localftypeids);


    if (mys.getAttribute("shareftypeids") != null)
        shareftypeids =(int []) mys.getAttribute("shareftypeids");
        HashMap shareftype2chromsomeMap = new HashMap ();
       if (sharedConnection != null)
           shareftype2chromsomeMap = GroupHelper.mapftypeid2chromsome (sharedConnection, out);


    if (sharedbName != null && shareftypeids != null)
        numShareAnnos  = Utility.countAnnotations(sharedConnection, shareftypeids);


	totalNumAnnotations = numLocalAnnos + numShareAnnos;

	//out.println("<br>322 " + totalNumAnnotations +"  is init page " +  initPage);
	int sessionTotalNumAnno = 0;
    String sessionTotal = null;
     if (mys.getAttribute("totalNumAnnotations_VGA" )!= null)  {
         sessionTotal = (String)mys.getAttribute("totalNumAnnotations_VGA");

        try {
        sessionTotalNumAnno = Integer.parseInt(sessionTotal);
        }
        catch (Exception e) {
        GenboreeUtils.sendRedirect(request, response, "/java-bin/displaySelection.jsp?fromBrowser=View");
         return ;

         }
     }

	   if (!initPage && totalNumAnnotations != sessionTotalNumAnno ) {
			GenboreeUtils.sendRedirect(request, response, "/java-bin/displaySelection.jsp?fromBrowser=View");
              return;
      }


    if ( totalNumAnnotations  >LffConstants.Display_Limit) {
        isLargeSamples = true;
         mys.setAttribute("isLargeSamples", new Boolean (true));
    }

    int numSortNames = 0;
    if ( request.getParameter("navigator") != null   )
        initPage = false;

    String [] avpDisplayNames = null;
    if ( initPage ){
			if (displayNames == null) {
                GenboreeMessage.setErrMsg(mys, "Please select some attributes for annotation display. ");
                viewDisplay="none";
   			////out.println("<br>359 " + totalNumGrpAnnotations );
					  return ;
			}
            else   {
              if (orderedSortNames != null) {
                 for (i=0; i<orderedSortNames.length; i++) {
                    if (lffConstantMap.get(orderedSortNames[i]) == null)
                        avpDisplayNameList.add(orderedSortNames[i]);
                 }
                avpDisplayNames = (String [])avpDisplayNameList.toArray(new String [avpDisplayNameList.size()]);
              }
            }

        if (orderedSortNames != null && orderedSortNames.length >0) {
            sortList = new ArrayList ();
            numSortNames = orderedSortNames.length;
            for (i=0; i<orderedSortNames.length; i++) {
                sortList.add(orderedSortNames[i]);
                if (lffConstantMap.get(orderedSortNames[i])==null) {
                    avpSortNameList.add(orderedSortNames[i]);
                }
                else {
                   lffSortNameList.add(orderedSortNames[i]);
                }
            }

         }

            if (con != null) {
                if (localftypeids != null && localftypeids.length > 0 )
                localftypeid2Gclass = Utility.retrieveFtype2Gclass (con, localftypeids);
                localftypeid2ftype =  Utility.retrieveFtypeid2ftype (con, dbName, genboreeUserId );
                localid2Chromosome = Utility.retrieveRid2Chromosome(con);
            }

            if (sharedbName != null) {
                if (shareftypeids != null && shareftypeids.length > 0)
                shareftypeid2Gclass = Utility.retrieveFtype2Gclass (sharedConnection, shareftypeids);
                if (sharedConnection == null || sharedConnection.isClosed())
                    sharedConnection = db.getConnection(sharedbName);
                shareftypeid2ftype =  Utility.retrieveFtypeid2ftype(sharedConnection, sharedbName, genboreeUserId );
                shareid2Chromosome = Utility.retrieveRid2Chromosome(sharedConnection);
            }

            mys.setAttribute("totalNumAnnotations_VGA", ""+ totalNumAnnotations );
            mys.setAttribute("localftypeid2Gclass", localftypeid2Gclass);
            mys.setAttribute("localftypeid2ftype", localftypeid2ftype);
            mys.setAttribute("localid2Chromosome", localid2Chromosome);
            mys.setAttribute("shareftypeid2Gclass", shareftypeid2Gclass);
            mys.setAttribute("shareftypeid2ftype", shareftypeid2ftype);
            mys.setAttribute("shareid2Chromosome", shareid2Chromosome);
         // case 1: small samples
           if (totalNumAnnotations >0 || !initPage)  {
               hasData = true;
           }
  	////out.println("<br>422 " + totalNumGrpAnnotations );


        if (!isLargeSamples  && hasData) {
            AnnotationGroup localAnnoGrp =  null;
          if (localftypeids   != null && localftypeids.length > 0 )
              localAnnoGrp = GroupHelper.retrieveGroupAnnotations (localftypeids, localftypeid2Gclass, localftypeid2ftype, localid2Chromosome, localftype2chromsomeMap, con, out);
           int localgrpNum = 0;
            if (localAnnoGrp != null){
                if (localAnnoGrp.getAnnos() != null)
                localGrpAnnotations  = localAnnoGrp.getAnnos();
                localGroupName2fids = localAnnoGrp.getGroupName2Fids();
                mys.setAttribute("localGrpAnnotations", localGrpAnnotations);
                mys.setAttribute("localGroupName2fids", localGroupName2fids);



        if (localGrpAnnotations != null && sortingText) {
        localGrpAnnotations = GroupHelper.populateGroupText (verbose, con,localGrpAnnotations, localGroupName2fids,  true, out);
        }

        if (localGrpAnnotations != null  && sortByAVP ) {
        localGrpAnnotations = GroupHelper.populateAVP (verbose, con, localGrpAnnotations,localGroupName2fids, true, out);
        }


                if (localGrpAnnotations != null)
               localgrpNum = localGrpAnnotations.length;
            }


        AnnotationGroup shareAnnoGrp =  null;
        if (shareftypeids != null && shareftypeids.length>0)
        shareAnnoGrp = GroupHelper.retrieveGroupAnnotations (shareftypeids, shareftypeid2Gclass, shareftypeid2ftype, shareid2Chromosome, shareftype2chromsomeMap, sharedConnection, out);
        int sharegrpnum = 0;
        if (shareAnnoGrp != null){
            if (shareAnnoGrp.getAnnos() != null)
            sharedGrpAnnotations = shareAnnoGrp.getAnnos();
           sharedGroupName2fids =shareAnnoGrp.getGroupName2Fids();

            if (sharedGrpAnnotations != null  &&  sharedGrpAnnotations.length > 0  && sortingText) {
            sharedGrpAnnotations  = GroupHelper.populateGroupText(verbose, sharedConnection, sharedGrpAnnotations, sharedGroupName2fids , true, out);
            }
            if (sharedGrpAnnotations != null  &&  sharedGrpAnnotations.length > 0 && sortByAVP ) {
            sharedGrpAnnotations  = GroupHelper.populateAVP (verbose,sharedConnection, sharedGrpAnnotations, sharedGroupName2fids,false, out);
            }
            mys.setAttribute("sharedGrpAnnotations", sharedGrpAnnotations);
            mys.setAttribute("sharedGroupName2fids", sharedGroupName2fids);
            if (sharedGrpAnnotations != null  &&  sharedGrpAnnotations.length > 0 )
            sharegrpnum = sharedGrpAnnotations.length;
        }


        totalNumGrpAnnotations = localgrpNum + sharegrpnum;

		 AnnotationDetail [] tempTotal = new AnnotationDetail [totalNumGrpAnnotations];
        int baseIndex = 0;
       if (localGrpAnnotations != null && localGrpAnnotations.length > 0) {
        for (i=0; i<localGrpAnnotations.length ; i++) {
        tempTotal[i] = localGrpAnnotations[i];
        }
        baseIndex = localGrpAnnotations.length;
       }

        if ( sharedGrpAnnotations != null &&  sharedGrpAnnotations.length > 0) {
            for (i=0; i<sharedGrpAnnotations.length ; i++) {
                tempTotal[i+ baseIndex] =  sharedGrpAnnotations[i];
                tempTotal[i+ baseIndex].setShare(true);
            }
        }

        totalAnnotations = tempTotal;
          if (debugging)
        System.err.println ("view grp annotation: line 400: local grp annotations " + localgrpNum+  "  share grp anno  " + sharegrpnum );
        if (orderedSortNames != null  && totalNumGrpAnnotations >1)
        totalAnnotations = AnnotationSorter.sortAllAnnotations(orderedSortNames, totalAnnotations);
     }
    else if (isLargeSamples)  {
           String sortName = null;
          if (orderedSortNames != null)
              sortName = orderedSortNames[0];
              if (localftypeids  != null) {
               AnnotationGroup localGroup =  GroupHelper.retrieveLargeAnnoGroup (localftypeids, localftype2chromsomeMap, con, out  ) ;
               localGrpAnnotations = localGroup.getAnnos();
               localGroupName2fids = localGroup.getGroupName2Fids();
              }
			  else {
				   localGrpAnnotations = null;
               localGroupName2fids =  null;
			  }


			   mys.setAttribute("localGrpAnnotations", localGrpAnnotations);
               mys.setAttribute("localGroupName2fids", localGroupName2fids);
			 if (shareftypeids != null) {
                     AnnotationGroup sharedGroup =  GroupHelper.retrieveLargeAnnoGroup (shareftypeids, shareftype2chromsomeMap, sharedConnection, out  ) ;
                    sharedGrpAnnotations = sharedGroup.getAnnos();
                    sharedGroupName2fids = sharedGroup.getGroupName2Fids();

                    if (sharedGrpAnnotations != null) {
                    for (i=0; i<sharedGrpAnnotations.length; i++) {
                    sharedGrpAnnotations[i].setShare(true);
                   // sharedGrpAnnotations[i].setGname("s___" + sharedGrpAnnotations[i].getGname());
                    }
                    }
             }
			else {
				 sharedGrpAnnotations = null;
								   sharedGroupName2fids = null;

			 }
					 mys.setAttribute("sharedGrpAnnotations", sharedGrpAnnotations);
                    mys.setAttribute("sharedGroupName2fids", sharedGroupName2fids);

			 totalAnnotations = GroupHelper.mergeAnnotations (localGrpAnnotations, sharedGrpAnnotations);

          if (totalAnnotations != null)
              totalNumGrpAnnotations = totalAnnotations.length;

        if (orderedSortNames != null){
            HashMap localvalue2fids = new HashMap ();
            HashMap sharevalue2fids = new HashMap ();

            if (sortByAVP) {
                 HashMap localvalue2anno = new HashMap ();
               if (localftypeids != null  && localGrpAnnotations != null && localGrpAnnotations.length > 0) {
                    int localsortNameId = AttributeRetriever.retrieveNameId(con,sortName);

                      String  values = null;
                   String[] localGenevalueids  =  null;
                    String  [] fids = null;
                   ArrayList list = null;
                     int count = 0;
                    for ( i=0; i<localGrpAnnotations.length; i++) {
                        list  = (ArrayList)localGroupName2fids.get(localGrpAnnotations[i].getGname() + "_" + localGrpAnnotations[i].getFtypeId() + "_" +  localGrpAnnotations[i].getRid());
                        fids = (String [])list.toArray(new String [list.size()]);

                        values = null;
                        if (fids != null && fids.length > 0)
                        localGenevalueids  =  GroupHelper.retrieveSingleAttributeValueIds  (con,  fids, localsortNameId, out);


                        if (localGenevalueids != null && localGenevalueids.length >0)
                        values  =  GroupHelper.retrieveGeneAttValue ( con, localGenevalueids , verbose, out ) ;

                        if (values != null)
                        values = values.trim();
                        if (values == null || values == "")
                        values= "zzzz";

                        HashMap m = new HashMap ();
                        m.put (sortName, values);
                        localGrpAnnotations[i].setAvp(m);

                        ArrayList annolist  = null;
                        if (localvalue2anno.get(values) == null)
                        annolist = new ArrayList ();
                        else
                        annolist = (ArrayList)localvalue2anno.get(values);

                        annolist.add(localGrpAnnotations[i]);

                        localvalue2anno.put(values, annolist);
                        //   localAnnotations[i].setAvp(new HashMap ().put(sortName, values));
                    }
               }


                 HashMap sharevalue2anno = new HashMap ();
                    if (sharedGrpAnnotations != null  && sharedGrpAnnotations.length > 0) {
                        int sharesortNameId = AttributeRetriever.retrieveNameId(sharedConnection,sortName);
                        String  values = null;
                        String[]  shareGenevalueids  =  null;
                        String  [] fids = null;
                        ArrayList list = null;

                        int count = 0;
                        for ( i=0; i< sharedGrpAnnotations.length; i++) {
                        list  = (ArrayList)sharedGroupName2fids.get(sharedGrpAnnotations[i].getGname() + "_" + sharedGrpAnnotations[i].getFtypeId() + "_" +  sharedGrpAnnotations[i].getRid());
                        fids = (String [])list.toArray(new String [list.size()]);

                        values = null;
                        if (fids != null && fids.length > 0)
                        shareGenevalueids  =  GroupHelper.retrieveSingleAttributeValueIds  (sharedConnection,  fids, sharesortNameId, out);


                        if (shareGenevalueids != null && shareGenevalueids.length >0)
                        values  =  GroupHelper.retrieveGeneAttValue ( sharedConnection, shareGenevalueids , verbose, out ) ;

                        if (values != null)
                        values = values.trim();
                        if (values == null || values == "")
                        values= "zzzz";

                        HashMap m = new HashMap ();
                        m.put (sortName, values);
                         sharedGrpAnnotations[i].setAvp(m);

                        ArrayList annolist  = null;
                        if (sharevalue2anno.get(values) == null)
                        annolist = new ArrayList ();
                        else
                        annolist = (ArrayList)sharevalue2anno.get(values);

                        annolist.add(sharedGrpAnnotations[i]);

                        sharevalue2anno.put(values, annolist);

                        }
                    }

                    String []  localkeys = null;
                    if (!localvalue2anno.isEmpty()) {
                        localkeys = (String [])localvalue2anno.keySet().toArray(new String [localvalue2anno.size()]);
                    }


                 String []  sharekeys = null;
                     if (!sharevalue2anno.isEmpty()) {
                        sharekeys = (String [])sharevalue2anno.keySet().toArray(new String [sharevalue2anno.size()]);
                    }

            HashMap keyMap = new HashMap ();
            if (localkeys != null && localkeys.length >0) {
            for (i=0; i<localkeys.length; i++) {
            if (localkeys[i] != null)
            keyMap.put(localkeys[i], "y"); }
            }
            if (sharekeys != null && sharekeys.length > 0){
            for (i=0; i<sharekeys.length; i++) {
            if (sharekeys [i] != null)
            keyMap.put(sharekeys[i], "y");
            }
            }

            String []  keys = (String [])keyMap.keySet().toArray(new String [keyMap.size()]);
            Arrays.sort(keys);
            ArrayList temp = new ArrayList ();

            ArrayList  locallist = null;
            ArrayList  sharelist =  null;

            if (keys != null && keys.length > 0 ) {
             for (i=0; i<keys.length; i++) {
                locallist = (ArrayList )localvalue2anno.get(keys[i]);
                if (locallist != null) {
                for (int j=0; j<locallist.size(); j++) {
                temp.add((AnnotationDetail)locallist.get(j));
                }
                }

                sharelist = (ArrayList )sharevalue2anno.get(keys[i]);
                if (sharelist != null) {
                for ( int j=0; j<sharelist.size(); j++) {
                temp.add((AnnotationDetail)sharelist.get(j));
                }
                }
             }
            }
            if (!temp.isEmpty()) {
                totalAnnotations = (AnnotationDetail [] )temp.toArray(new AnnotationDetail [temp.size()]);
                totalNumGrpAnnotations = totalAnnotations.length;
            }

       }
       else {  // sort: non-avp sort

                 // if sorting by type or subtype, populate annotation with name
        if (sortName.equals(LffConstants.LFF_COLUMNS[2])  || sortName.equals(LffConstants.LFF_COLUMNS[3])) {
            if (localGrpAnnotations  != null) {
            for (i=0; i<localGrpAnnotations.length; i++) {
            if (localftypeid2ftype.get("" + localGrpAnnotations[i].getFtypeId()) != null ) {
            String [] ftypeString = null;

            ftypeString =(String [] )localftypeid2ftype.get("" + localGrpAnnotations[i].getFtypeId());

            String fmethod = null;
            String fsource = null;
            if (ftypeString != null && ftypeString != null){
            fmethod = ftypeString[0];
            fsource = ftypeString[1];
            localGrpAnnotations[i].setFmethod(fmethod);
            localGrpAnnotations[i].setFsource(fsource);
            localGrpAnnotations[i].setTrackName(fmethod + ":" + fsource);
            }
            }
            }
            }
            if (sharedGrpAnnotations  != null)
            for (i=0; i<sharedGrpAnnotations.length; i++) {
            if (localftypeid2ftype.get("" + sharedGrpAnnotations[i].getFtypeId()) != null ) {
            String [] ftypeString = null;

            ftypeString =(String [] )localftypeid2ftype.get("" + sharedGrpAnnotations[i].getFtypeId());
            String fmethod = null;
            String fsource = null;
            if (ftypeString != null && ftypeString != null){
            fmethod = ftypeString[0];
            fsource = ftypeString[1];
            sharedGrpAnnotations[i].setFmethod(fmethod);
            sharedGrpAnnotations[i].setFsource(fsource);

            sharedGrpAnnotations[i].setTrackName(fmethod + ":" + fsource);

            }
            }}
        }
        // sort by class name
        else if (sortName.equals(LffConstants.LFF_COLUMNS[1])){
            if (localGrpAnnotations != null) {
            for (i=0; i<localGrpAnnotations.length; i++) {
            String className = "";
            if (localftypeid2Gclass.get("" + localGrpAnnotations[i].getFtypeId()) != null) {
            className = (String )localftypeid2Gclass.get("" + localGrpAnnotations[i].getFtypeId());
                localGrpAnnotations[i].setGclassName(className);
            }
            }
            }
            if (sharedGrpAnnotations!= null) {
                for (i=0; i<sharedGrpAnnotations.length; i++) {
                String className = "";
                if (shareftypeid2Gclass.get("" + sharedGrpAnnotations[i].getFtypeId()) != null) {
                className = (String )shareftypeid2Gclass.get("" + sharedGrpAnnotations[i].getFtypeId());
                    sharedGrpAnnotations[i].setGclassName(className);
                }
                 }}
        }
                    // sort by chromosome
        else if (sortName.equals(LffConstants.LFF_COLUMNS[4])){
                if (localGrpAnnotations != null) {
                    for (i=0; i<localGrpAnnotations.length; i++) {
                    String chr = "";
                    if (localftype2chromsomeMap.get("" + localGrpAnnotations[i].getFtypeId()) != null) {
                    chr = (String )localid2Chromosome.get("" + localGrpAnnotations[i].getRid());
                    localGrpAnnotations[i].setChromosome(chr);
                    }
                    }
                }
                if (sharedGrpAnnotations != null) {
                    for (i=0; i<sharedGrpAnnotations.length; i++) {
                        String chr = "";
                        if (shareftype2chromsomeMap.get("" + sharedGrpAnnotations[i].getFtypeId()) != null) {
                        chr = (String )shareid2Chromosome.get("" + sharedGrpAnnotations[i].getRid());
                        sharedGrpAnnotations[i].setChromosome(chr);
                    }
                    } }
        }
                    // sort by Text
        else if (sortingText){
            if (con != null && localGrpAnnotations != null)
                localGrpAnnotations = GroupHelper.populateGroupText (verbose, con, localGrpAnnotations, localGroupName2fids, true, out);
            if (sharedConnection != null && sharedGrpAnnotations != null)
                sharedGrpAnnotations = GroupHelper.populateGroupText (verbose, sharedConnection, sharedGrpAnnotations, sharedGroupName2fids, false, out);
        }
        else {
            if (sortName.indexOf(". Start")  > 0)  {
                if (con != null && localGrpAnnotations != null)
                    localGrpAnnotations =GroupHelper.populateStart (con,  localGrpAnnotations,  out ) ;
                if (sharedConnection != null && sharedGrpAnnotations != null)
                    sharedGrpAnnotations =GroupHelper.populateStart (sharedConnection, sharedGrpAnnotations,  out ) ;
                     }
            else if (sortName.indexOf(". Stop")  > 0)  {
                if (con != null && localGrpAnnotations != null)
                    localGrpAnnotations =GroupHelper.populateStop (con,  localGrpAnnotations,  out ) ;
                if (sharedConnection != null && sharedGrpAnnotations != null)
                    sharedGrpAnnotations =GroupHelper.populateStop (sharedConnection, sharedGrpAnnotations,  out ) ;
            }
            else if (sortName.indexOf("QStop")  > 0)  {
                if (con != null && localGrpAnnotations != null)
                    localGrpAnnotations =GroupHelper.populateTargetStop (con,  localGrpAnnotations,  out ) ;
                if (sharedConnection != null && sharedGrpAnnotations != null)
                sharedGrpAnnotations =GroupHelper.populateTargetStop (sharedConnection, sharedGrpAnnotations,  out ) ;

              }
            else if (sortName.indexOf("QStart")  > 0) {
            if (con != null && localGrpAnnotations != null)
            localGrpAnnotations =GroupHelper.populateTargetStart (con, localGrpAnnotations, out ) ;
            if (sharedConnection != null && sharedGrpAnnotations != null)
            sharedGrpAnnotations =GroupHelper.populateTargetStart (sharedConnection, sharedGrpAnnotations, out) ;
                }
            else if (sortName.indexOf("Score")  > 0)  {
                if (con != null && localGrpAnnotations != null)
                localGrpAnnotations =GroupHelper.populateScore (con,  localGrpAnnotations, out) ;
                if (sharedConnection != null && sharedGrpAnnotations != null)
                sharedGrpAnnotations =GroupHelper.populateScore (sharedConnection, sharedGrpAnnotations, out) ;
            }
            else if (sortName.indexOf("Phase")  > 0)  {
                if (con != null && localGrpAnnotations != null)
                localGrpAnnotations =GroupHelper.populatePhase (con, localGrpAnnotations, out) ;
                if (sharedConnection != null && sharedGrpAnnotations != null)
                sharedGrpAnnotations =GroupHelper.populatePhase (sharedConnection, sharedGrpAnnotations, out) ;
            }
            else if (sortName.indexOf("Strand")  > 0) {
                if (con != null && localGrpAnnotations != null)
                localGrpAnnotations =GroupHelper.populateStrand (con,  localGrpAnnotations,  out ) ;
                if (sharedConnection != null && sharedGrpAnnotations != null)
                sharedGrpAnnotations =GroupHelper.populateStrand (sharedConnection, sharedGrpAnnotations, out) ;
            }
         }

            totalAnnotations = GroupHelper.mergeAnnotations (localGrpAnnotations, sharedGrpAnnotations);
            if (totalAnnotations != null)
                 totalNumGrpAnnotations = totalAnnotations.length;

            //  AnnotationDetail[] sortedTotalAnnotations =  //sortLargeAnos(totalAnnotations, sortName);
           AnnotationDetail[] sortedTotalAnnotations =null;
                if (orderedSortNames != null && totalAnnotations != null) {
                    sortedTotalAnnotations =AnnotationSorter.sortAllAnnotations (orderedSortNames, totalAnnotations);
                 }
                 if (sortedTotalAnnotations != null) {
                    totalAnnotations=   sortedTotalAnnotations ;
                   }
         }

        }


       if (totalNumGrpAnnotations ==0){
			GenboreeMessage.setErrMsg(mys, " No annotations are found with the track information provided.");
            GenboreeUtils.sendRedirect(request, response, "/java-bin/displaySelection.jsp?fromBrowser=View");
         hasData = false;
        return;

        }
        else  {
            hasData = true;
            if (totalAnnotations != null)
          totalNumGrpAnnotations = totalAnnotations.length;

         }


      }  // end of large sample retrieval
    // end of data retrieval
         mys.setAttribute("totalAnnotations_VGA", totalAnnotations);
        mys.setAttribute("totalNumGrpAnnotations", "" + totalNumGrpAnnotations);
    paging = true;
    if (displayNames != null &&displayNames.length >0){
        for (int k=0; k<displayNames.length; k++) {
            if (!lffNameArrayList.contains(displayNames[k]))
                avpDisplayNameList.add(displayNames[k]);
        }
    }

    if (!avpDisplayNameList.isEmpty()) {
        avpDisplayNames =(String []) avpDisplayNameList.toArray(new String [avpDisplayNameList.size()]);
        mys.setAttribute("avpDisplayNames", avpDisplayNames);
    }
     hasData = false;
    if ( totalAnnotations  != null && totalAnnotations.length > 0)
    hasData = true;

}
else {  //  recuring page
       displayNames = (String [])  mys.getAttribute("displayNames");
        if ( mys.getAttribute("avpDisplayNames") != null)
            avpDisplayNames =   (String [])  mys.getAttribute("avpDisplayNames");
        String temp = null;
            temp = (String)mys.getAttribute("displayNum");

        if (temp!=null) {
            int displayN = Integer.parseInt(temp);
            if (displayN != displayNum)
            paging = true;
        }
        if (mys.getAttribute("totalAnnotations_VGA") != null)
           totalAnnotations = (AnnotationDetail[])mys.getAttribute("totalAnnotations_VGA");
         if (totalAnnotations != null)
         totalNumGrpAnnotations = totalAnnotations.length;

          if ( totalAnnotations  != null && totalAnnotations.length > 0)
           hasData = true;
        localGrpAnnotations =  (AnnotationDetail [])   mys.getAttribute("localGrpAnnotations");
        localGroupName2fids = (HashMap )mys.getAttribute("localGroupName2fids");
        sharedGrpAnnotations= (AnnotationDetail [] ) mys.getAttribute("sharedGrpAnnotations");
        sharedGroupName2fids = (HashMap ) mys.getAttribute("sharedGroupName2fids");

        localftypeid2ftype = (HashMap)mys.getAttribute("localftypeid2ftype");
        localftypeid2Gclass = (HashMap)mys.getAttribute("localftypeid2Gclass");
        localid2Chromosome =   (HashMap)mys.getAttribute("localid2Chromosome");
        shareftypeid2ftype = (HashMap)mys.getAttribute("shareftypeid2ftype");
        shareftypeid2Gclass = (HashMap)mys.getAttribute("shareftypeid2Gclass");
        shareid2Chromosome =   (HashMap)mys.getAttribute("shareid2Chromosome");
		 // large group
		if (mys.getAttribute("fid2Attributes") != null) {
			fidAttributes = (String [][])mys.getAttribute("fid2Attributes");
		}


		if(sortingColumns)
		isLargeSamples = true;

		if (sortingColumnName  != null)
		orderedSortNames = new String [] {sortingColumnName} ;

		if (orderedSortNames != null) {
			for (i=0; i<orderedSortNames.length; i++) {
				if (orderedSortNames[i].equals(LffConstants.LFF_COLUMNS[12]))  {
				sortingText = true;
				break;
				}

				if (orderedSortNames[i].equals(LffConstants.LFF_COLUMNS[13]))  {
				sortingText = true;
				break;
				}
			}

			for (i=0; i<orderedSortNames.length; i++) {
				if (lffConstantMap.get(orderedSortNames[i]) == null)
				{
				sortByAVP = true;
				break;
				}
			}
		}


	if (sortingColumns) {
		if (!isLargeSamples  && hasData) {
			AnnotationGroup localAnnoGrp =  null;
			if (localftypeids   != null && localftypeids.length > 0 )
			localAnnoGrp = GroupHelper.retrieveGroupAnnotations (localftypeids, localftypeid2Gclass, localftypeid2ftype, localid2Chromosome, localftype2chromsomeMap, con, out);
			int localgrpNum = 0;
			if (localAnnoGrp != null){
				if (localAnnoGrp.getAnnos() != null)
				localGrpAnnotations  = localAnnoGrp.getAnnos();
				localGroupName2fids = localAnnoGrp.getGroupName2Fids();
				mys.setAttribute("localGrpAnnotations", localGrpAnnotations);
				mys.setAttribute("localGroupName2fids", localGroupName2fids);
				if (localGrpAnnotations != null && sortingText) {
				localGrpAnnotations = GroupHelper.populateGroupText(verbose, con,localGrpAnnotations, localGroupName2fids,true, out);
				}

				if (localGrpAnnotations != null  && sortByAVP ) {
				localGrpAnnotations = GroupHelper.populateAVP (verbose, con, localGrpAnnotations,localGroupName2fids, true, out);
				}

				if (localGrpAnnotations != null)
				localgrpNum = localGrpAnnotations.length;
			}

        AnnotationGroup shareAnnoGrp =  null;
        if (shareftypeids != null && shareftypeids.length>0)
        shareAnnoGrp = GroupHelper.retrieveGroupAnnotations (shareftypeids, shareftypeid2Gclass, shareftypeid2ftype, shareid2Chromosome, shareftype2chromsomeMap, sharedConnection, out);
        int sharegrpnum = 0;
        if (shareAnnoGrp != null){
            if (shareAnnoGrp.getAnnos() != null)
            sharedGrpAnnotations = shareAnnoGrp.getAnnos();
           sharedGroupName2fids =shareAnnoGrp.getGroupName2Fids();

            if (sharedGrpAnnotations != null  &&  sharedGrpAnnotations.length > 0  && sortingText) {
            sharedGrpAnnotations  = GroupHelper.populateGroupText(verbose, sharedConnection, sharedGrpAnnotations, sharedGroupName2fids ,true, out);
		         }


            if (sharedGrpAnnotations != null  &&  sharedGrpAnnotations.length > 0 && sortByAVP ) {
            sharedGrpAnnotations  = GroupHelper.populateAVP (verbose,sharedConnection, sharedGrpAnnotations, sharedGroupName2fids, false, out);
            }


            mys.setAttribute("sharedGrpAnnotations", sharedGrpAnnotations);
            mys.setAttribute("sharedGroupName2fids", sharedGroupName2fids);
            if (sharedGrpAnnotations != null  &&  sharedGrpAnnotations.length > 0 )
            sharegrpnum = sharedGrpAnnotations.length;
        }


        totalNumGrpAnnotations = localgrpNum + sharegrpnum;
         AnnotationDetail [] tempTotal = new AnnotationDetail [totalNumGrpAnnotations];
        int baseIndex = 0;
       if (localGrpAnnotations != null && localGrpAnnotations.length > 0) {
        for (i=0; i<localGrpAnnotations.length ; i++) {
        tempTotal[i] = localGrpAnnotations[i];
        }
        baseIndex = localGrpAnnotations.length;
       }

        if ( sharedGrpAnnotations != null &&  sharedGrpAnnotations.length > 0) {
            for (i=0; i<sharedGrpAnnotations.length ; i++) {
                tempTotal[i+ baseIndex] =  sharedGrpAnnotations[i];
                tempTotal[i+ baseIndex].setShare(true);
            }
        }

        totalAnnotations = tempTotal;
          if (debugging)
        System.err.println ("view grp annotation: line 400: local grp annotations " + localgrpNum+  "  share grp anno  " + sharegrpnum );
        if (orderedSortNames != null  && totalNumGrpAnnotations >1)
        totalAnnotations = AnnotationSorter.sortAllAnnotations(orderedSortNames, totalAnnotations);
     }
    else if (isLargeSamples)  {

           String sortName = sortingColumnName;

              if (localftypeids  != null) {
               AnnotationGroup localGroup =  GroupHelper.retrieveLargeAnnoGroup (localftypeids, localftype2chromsomeMap, con, out  ) ;
               localGrpAnnotations = localGroup.getAnnos();
               localGroupName2fids = localGroup.getGroupName2Fids();

               mys.setAttribute("localGrpAnnotations", localGrpAnnotations);
               mys.setAttribute("localGroupName2fids", localGroupName2fids);
              }

             if (shareftypeids != null) {
                     AnnotationGroup sharedGroup =  GroupHelper.retrieveLargeAnnoGroup (shareftypeids, shareftype2chromsomeMap, sharedConnection, out  ) ;
                    sharedGrpAnnotations = sharedGroup.getAnnos();
                    sharedGroupName2fids = sharedGroup.getGroupName2Fids();

                    if (sharedGrpAnnotations != null) {
                    for (i=0; i<sharedGrpAnnotations.length; i++) {
                    sharedGrpAnnotations[i].setShare(true);
                   // sharedGrpAnnotations[i].setGname("s___" + sharedGrpAnnotations[i].getGname());
                    }
                    }

                    mys.setAttribute("sharedGrpAnnotations", sharedGrpAnnotations);
                    mys.setAttribute("sharedGroupName2fids", sharedGroupName2fids);
            }

             totalAnnotations = GroupHelper.mergeAnnotations (localGrpAnnotations, sharedGrpAnnotations);

          if (totalAnnotations != null)
              totalNumGrpAnnotations = totalAnnotations.length;

        if (orderedSortNames != null){
            HashMap localvalue2fids = new HashMap ();
            HashMap sharevalue2fids = new HashMap ();

            if (sortByAVP) {
                 HashMap localvalue2anno = new HashMap ();
               if (localftypeids != null  && localGrpAnnotations != null && localGrpAnnotations.length > 0) {
                    int localsortNameId = AttributeRetriever.retrieveNameId(con,sortName);

                      String  values = null;
                   String[] localGenevalueids  =  null;
                    String  [] fids = null;
                   ArrayList list = null;
                     int count = 0;
                    for ( i=0; i<localGrpAnnotations.length; i++) {
                        list  = (ArrayList)localGroupName2fids.get(localGrpAnnotations[i].getGname() + "_" + localGrpAnnotations[i].getFtypeId() + "_" +  localGrpAnnotations[i].getRid());
                        fids = (String [])list.toArray(new String [list.size()]);

                        values = null;
                        if (fids != null && fids.length > 0)
                        localGenevalueids  =  GroupHelper.retrieveSingleAttributeValueIds  (con,  fids, localsortNameId, out);


                        if (localGenevalueids != null && localGenevalueids.length >0)
                        values  =  GroupHelper.retrieveGeneAttValue ( con, localGenevalueids , verbose, out ) ;

                        if (values != null)
                        values = values.trim();
                        if (values == null || values == "")
                        values= OneAttAnnotationSorter.maxStringValue;

                        HashMap m = new HashMap ();
						ArrayList tempList = new ArrayList ();
						tempList.add(values);
                        m.put (sortName, tempList);
                        localGrpAnnotations[i].setAvp(m);

                        ArrayList annolist  = null;
                        if (localvalue2anno.get(values) == null)
                        annolist = new ArrayList ();
                        else
                        annolist = (ArrayList)localvalue2anno.get(values);

                        annolist.add(localGrpAnnotations[i]);

                        localvalue2anno.put(values, annolist);
                        //   localAnnotations[i].setAvp(new HashMap ().put(sortName, values));
                    }
               }


                 HashMap sharevalue2anno = new HashMap ();
                    if (sharedGrpAnnotations != null  && sharedGrpAnnotations.length > 0) {
                        int sharesortNameId = AttributeRetriever.retrieveNameId(sharedConnection,sortName);
                        String  values = null;
                        String[]  shareGenevalueids  =  null;
                        String  [] fids = null;
                        ArrayList list = null;

                        int count = 0;
                        for ( i=0; i< sharedGrpAnnotations.length; i++) {
                        list  = (ArrayList)sharedGroupName2fids.get(sharedGrpAnnotations[i].getGname() + "_" + sharedGrpAnnotations[i].getFtypeId() + "_" +  sharedGrpAnnotations[i].getRid());
                        fids = (String [])list.toArray(new String [list.size()]);

                        values = null;
                        if (fids != null && fids.length > 0)
                        shareGenevalueids  =  GroupHelper.retrieveSingleAttributeValueIds  (sharedConnection,  fids, sharesortNameId, out);


                        if (shareGenevalueids != null && shareGenevalueids.length >0)
                        values  =  GroupHelper.retrieveGeneAttValue ( sharedConnection, shareGenevalueids , verbose, out ) ;

                        if (values != null)
                        values = values.trim();
                        if (values == null || values == "")
                        values= OneAttAnnotationSorter.maxStringValue;

                        HashMap m = new HashMap ();
							ArrayList tempList = new ArrayList ();
							tempList.add(values);
                        m.put (sortName, tempList);
                         sharedGrpAnnotations[i].setAvp(m);

                        ArrayList annolist  = null;
                        if (sharevalue2anno.get(values) == null)
                        annolist = new ArrayList ();
                        else
                        annolist = (ArrayList)sharevalue2anno.get(values);

                        annolist.add(sharedGrpAnnotations[i]);

                        sharevalue2anno.put(values, annolist);

                        }
                    }

                    String []  localkeys = null;
                    if (!localvalue2anno.isEmpty()) {
                        localkeys = (String [])localvalue2anno.keySet().toArray(new String [localvalue2anno.size()]);
                    }


                 String []  sharekeys = null;
                     if (!sharevalue2anno.isEmpty()) {
                        sharekeys = (String [])sharevalue2anno.keySet().toArray(new String [sharevalue2anno.size()]);
                    }

            HashMap keyMap = new HashMap ();
            if (localkeys != null && localkeys.length >0) {
            for (i=0; i<localkeys.length; i++) {
            if (localkeys[i] != null)
            keyMap.put(localkeys[i], "y"); }
            }
            if (sharekeys != null && sharekeys.length > 0){
            for (i=0; i<sharekeys.length; i++) {
            if (sharekeys [i] != null)
            keyMap.put(sharekeys[i], "y");
            }
            }

            String []  keys = (String [])keyMap.keySet().toArray(new String [keyMap.size()]);

	  sortingOrder = 0;
				if (!ascendingSort)
				 sortingOrder = 2;
		keys = OneAttAnnotationSorter.sortStrings(keys,sortingOrder, OneAttAnnotationSorter.maxStringValue );
            ArrayList tempList = new ArrayList ();

            ArrayList  locallist = null;
            ArrayList  sharelist =  null;

            if (keys != null && keys.length > 0 ) {
             for (i=0; i<keys.length; i++) {
                locallist = (ArrayList )localvalue2anno.get(keys[i]);
                if (locallist != null) {
                for (int j=0; j<locallist.size(); j++) {
                tempList.add((AnnotationDetail)locallist.get(j));
                }
                }

                sharelist = (ArrayList )sharevalue2anno.get(keys[i]);
                if (sharelist != null) {
                for ( int j=0; j<sharelist.size(); j++) {
                tempList.add((AnnotationDetail)sharelist.get(j));
                }
                }
             }
            }
            if (!tempList.isEmpty()) {
                totalAnnotations = (AnnotationDetail [] )tempList.toArray(new AnnotationDetail [tempList.size()]);
                totalNumGrpAnnotations = totalAnnotations.length;
            }

       }
       else {  // sort: non-avp sort

                 // if sorting by type or subtype, populate annotation with name
        if (sortName.equals(LffConstants.LFF_COLUMNS[2])  || sortName.equals(LffConstants.LFF_COLUMNS[3])) {
            if (localGrpAnnotations  != null) {
            for (i=0; i<localGrpAnnotations.length; i++) {
            if (localftypeid2ftype.get("" + localGrpAnnotations[i].getFtypeId()) != null ) {
            String [] ftypeString = null;

            ftypeString =(String [] )localftypeid2ftype.get("" + localGrpAnnotations[i].getFtypeId());

            String fmethod = null;
            String fsource = null;
            if (ftypeString != null && ftypeString != null){
            fmethod = ftypeString[0];
            fsource = ftypeString[1];
            localGrpAnnotations[i].setFmethod(fmethod);
            localGrpAnnotations[i].setFsource(fsource);
            localGrpAnnotations[i].setTrackName(fmethod + ":" + fsource);
            }
            }
            }
            }
            if (sharedGrpAnnotations  != null)
            for (i=0; i<sharedGrpAnnotations.length; i++) {
            if (localftypeid2ftype.get("" + sharedGrpAnnotations[i].getFtypeId()) != null ) {
            String [] ftypeString = null;

            ftypeString =(String [] )localftypeid2ftype.get("" + sharedGrpAnnotations[i].getFtypeId());
            String fmethod = null;
            String fsource = null;
            if (ftypeString != null && ftypeString != null){
            fmethod = ftypeString[0];
            fsource = ftypeString[1];
            sharedGrpAnnotations[i].setFmethod(fmethod);
            sharedGrpAnnotations[i].setFsource(fsource);

            sharedGrpAnnotations[i].setTrackName(fmethod + ":" + fsource);

            }
            }}
        }
        // sort by class name
        else if (sortName.equals(LffConstants.LFF_COLUMNS[1])){
            if (localGrpAnnotations != null) {
            for (i=0; i<localGrpAnnotations.length; i++) {
            String className = "";
            if (localftypeid2Gclass.get("" + localGrpAnnotations[i].getFtypeId()) != null) {
            className = (String )localftypeid2Gclass.get("" + localGrpAnnotations[i].getFtypeId());
                 localGrpAnnotations[i].setGclassName(className);
            }
            }
            }
            if (sharedGrpAnnotations!= null) {
                for (i=0; i<sharedGrpAnnotations.length; i++) {
                String className = "";
                if (shareftypeid2Gclass.get("" + sharedGrpAnnotations[i].getFtypeId()) != null) {
                className = (String )shareftypeid2Gclass.get("" + sharedGrpAnnotations[i].getFtypeId());
                    sharedGrpAnnotations[i].setGclassName(className);
                }
                 }}
        }
                    // sort by chromosome
        else if (sortName.equals(LffConstants.LFF_COLUMNS[4])){
                if (localGrpAnnotations != null) {
                    for (i=0; i<localGrpAnnotations.length; i++) {
                    String chr = "";
                    if (localftype2chromsomeMap.get("" + localGrpAnnotations[i].getFtypeId()) != null) {
                    chr = (String )localid2Chromosome.get("" + localGrpAnnotations[i].getRid());
                    localGrpAnnotations[i].setChromosome(chr);
                    }
                    }
                }
                if (sharedGrpAnnotations != null) {
                    for (i=0; i<sharedGrpAnnotations.length; i++) {
                        String chr = "";
                        if (shareftype2chromsomeMap.get("" + sharedGrpAnnotations[i].getFtypeId()) != null) {
                        chr = (String )shareid2Chromosome.get("" + sharedGrpAnnotations[i].getRid());
                        sharedGrpAnnotations[i].setChromosome(chr);
                    }
                    } }
        }
                    // sort by Text
        else if (sortingText){
            if (con != null && localGrpAnnotations != null) {
                localGrpAnnotations = GroupHelper.populateGroupText (verbose, con, localGrpAnnotations, localGroupName2fids, true, out) ;
 			}
             if (sharedConnection != null && sharedGrpAnnotations != null) {
                sharedGrpAnnotations = GroupHelper.populateGroupText (verbose, sharedConnection, sharedGrpAnnotations, sharedGroupName2fids, false, out) ;
  			}
        }
        else {
            if (sortName.indexOf(". Start")  > 0)  {
                if (con != null && localGrpAnnotations != null)
                    localGrpAnnotations =GroupHelper.populateStart (con,localGrpAnnotations,out) ;
                if (sharedConnection != null && sharedGrpAnnotations != null)
                    sharedGrpAnnotations =GroupHelper.populateStart (sharedConnection, sharedGrpAnnotations,  out ) ;
                     }
            else if (sortName.indexOf(". Stop")  > 0)  {
                if (con != null && localGrpAnnotations != null)
                    localGrpAnnotations =GroupHelper.populateStop (con,  localGrpAnnotations,  out ) ;
                if (sharedConnection != null && sharedGrpAnnotations != null)
                    sharedGrpAnnotations =GroupHelper.populateStop (sharedConnection, sharedGrpAnnotations,  out ) ;
            }
            else if (sortName.indexOf("QStop")  > 0)  {
                if (con != null && localGrpAnnotations != null)
                    localGrpAnnotations =GroupHelper.populateTargetStop (con,  localGrpAnnotations,  out ) ;
                if (sharedConnection != null && sharedGrpAnnotations != null)
                sharedGrpAnnotations =GroupHelper.populateTargetStop (sharedConnection, sharedGrpAnnotations,  out ) ;

              }
            else if (sortName.indexOf("QStart")  > 0) {
            if (con != null && localGrpAnnotations != null)
            localGrpAnnotations =GroupHelper.populateTargetStart (con, localGrpAnnotations, out ) ;
            if (sharedConnection != null && sharedGrpAnnotations != null)
            sharedGrpAnnotations =GroupHelper.populateTargetStart (sharedConnection, sharedGrpAnnotations, out) ;
                }
            else if (sortName.indexOf("Score")  > 0)  {
                if (con != null && localGrpAnnotations != null)
                localGrpAnnotations =GroupHelper.populateScore (con,  localGrpAnnotations, out) ;
                if (sharedConnection != null && sharedGrpAnnotations != null)
                sharedGrpAnnotations =GroupHelper.populateScore (sharedConnection, sharedGrpAnnotations, out) ;
            }
            else if (sortName.indexOf("Phase")  > 0)  {
                if (con != null && localGrpAnnotations != null)
                localGrpAnnotations =GroupHelper.populatePhase (con, localGrpAnnotations, out) ;
                if (sharedConnection != null && sharedGrpAnnotations != null)
                sharedGrpAnnotations =GroupHelper.populatePhase (sharedConnection, sharedGrpAnnotations, out) ;
            }
            else if (sortName.indexOf("Strand")  > 0) {
                if (con != null && localGrpAnnotations != null)
                localGrpAnnotations =GroupHelper.populateStrand (con,  localGrpAnnotations,  out ) ;
                if (sharedConnection != null && sharedGrpAnnotations != null)
                sharedGrpAnnotations =GroupHelper.populateStrand (sharedConnection, sharedGrpAnnotations, out) ;
            }
         }

            totalAnnotations = GroupHelper.mergeAnnotations (localGrpAnnotations, sharedGrpAnnotations);
            if (totalAnnotations != null)
                 totalNumGrpAnnotations = totalAnnotations.length;

	}

	}
	}

		if (totalNumGrpAnnotations ==0){
		GenboreeMessage.setErrMsg(mys, " No annotations are found with the track information provided.");
		GenboreeUtils.sendRedirect(request, response, "/java-bin/displaySelection.jsp?fromBrowser=View");
		hasData = false;
		return;

		}
		else  {
		hasData = true;
		if (totalAnnotations != null)
		totalNumGrpAnnotations = totalAnnotations.length;

		}


		sortingOrder = 0;
		//   ascending sort
		if (!ascendingSort)
		sortingOrder= 2;


		totalAnnotations = OneAttAnnotationSorter.sortAllAnnotations(sortingColumnName, totalAnnotations, sortingOrder);
							paging = true;

		  mys.setAttribute("totalAnnotations_VGA", totalAnnotations);
			}
    }

    if ( request.getParameter("currentPage")!= null)
        currentPage = request.getParameter("currentPage");
    else
        currentPage = "0";


if (hasData) {
        // start of include file
      if (paging && totalNumGrpAnnotations >0) {
            page2Annotations = new HashMap();
           numPages = totalNumGrpAnnotations/displayNum;
           if ((totalNumGrpAnnotations % displayNum) != 0)
               numPages +=1;

           int baseIndex = 0;

           AnnotationDetail [] annos  = null;
           for (int k=0; k<numPages; k++) {
               baseIndex = k*displayNum;
               if ((totalNumGrpAnnotations - k * displayNum) >= displayNum){
                    annos = new AnnotationDetail[displayNum];
                    for (int m=0; m<displayNum; m++)
                    annos[m] = totalAnnotations[baseIndex+m];
                    page2Annotations.put("" + k, annos);
               }
               else {
                   int remainNum = totalNumGrpAnnotations - k * displayNum;
                   if (remainNum > 0 ) {
                    annos = new AnnotationDetail[remainNum];
                   for (int m=0; m<remainNum; m++)
                   annos[m] = totalAnnotations[baseIndex+m];
                   page2Annotations.put("" + k, annos);
                   }
               }
           }

        if (request.getParameter("currentPage") != null) {
           String indexPage  = request.getParameter("currentPage");
           if (indexPage != null) {
               int tempN = Integer.parseInt(indexPage);
               currentPageIndex = tempN;
               if (currentPageIndex <0)
               currentPageIndex = 0;

               if (currentPageIndex > (numPages -1))
               currentPageIndex = numPages -1;

               currentPage = "" + currentPageIndex;
               mys.setAttribute("lastPageIndex", currentPage  );

               if (numPages >maxDisplay) {
               modNum  =  currentPageIndex % maxDisplay;
               if (modNum == 0) {
               startPageNum = currentPageIndex;
               endPageNum = currentPageIndex + (maxDisplay-1);
               if (endPageNum > (numPages -1))
               endPageNum = numPages -1;

               mys.setAttribute("lastStartPageNum", "" +  startPageNum);
               mys.setAttribute("lastEndPageNum", "" + endPageNum);
               }
               else {
               startPageNum = (currentPageIndex/maxDisplay) * maxDisplay;
               endPageNum = startPageNum + (maxDisplay-1);
               if (endPageNum > (numPages -1))
               endPageNum = numPages -1;

               mys.setAttribute("lastStartPageNum", "" +  startPageNum);
               mys.setAttribute("lastEndPageNum", "" + endPageNum);
               }

               }
               else {
               endPageNum = numPages -1;
               startPageNum = 0;
               mys.setAttribute("lastStartPageNum", "" +  startPageNum);
               mys.setAttribute("lastEndPageNum", "" + endPageNum);
               }
           }
       }
       else {
       currentPageIndex = 0;
       currentPage = "0";
       mys.setAttribute("lastStartPageNum", "" +  0);
       }

       mys.setAttribute("page2Annotation_GAV", page2Annotations);
       mys.setAttribute("numPages", "" + numPages);
       doPaging = false;
    }
    else
           page2Annotations = (HashMap )mys.getAttribute("page2Annotation_GAV");

     if (!initPage)
          page2Annotations = (HashMap )mys.getAttribute("page2Annotation_GAV");

    // end of include file
    %>
    <%@ include file="include/annotationView.incl" %>
    <%
}


		if (mys.getAttribute("sortingColumnOrder") != null) {
			sortingColumnOrder = (String)mys.getAttribute("sortingColumnOrder");
			if (sortingColumnOrder.equals("up"))
			sortingArrow = "&uarr;";
			else if (sortingColumnOrder.equals("down"))
			sortingArrow = "&darr;";
		}



   if (hasData)
        annotations = (AnnotationDetail[])page2Annotations.get(currentPage);


    if (annotations == null || annotations.length==0) {
            GenboreeUtils.sendRedirect(request, response, "/java-bin/displaySelection.jsp?fromBrowser=View");
       return;
    }

    else {
        // update annotation name, ftypeid, and rid
        if (con != null)
        GroupHelper.updateAnnotations (con, annotations, true, out );
        if (annotations != null && sharedConnection != null)
        GroupHelper.updateAnnotations (sharedConnection, annotations, false, out);
     }
        // check recuring page
     if (groupMode  == null  && mys.getAttribute("isLargeSamples" ) != null) {
         isLargeSamples =((Boolean ) mys.getAttribute("isLargeSamples")).booleanValue();
        if (mys.getAttribute("localGrpAnnotations")!= null )
         localGrpAnnotations  = (AnnotationDetail [])mys.getAttribute("localGrpAnnotations");
         if (mys.getAttribute("sharedGrpAnnotations") != null)
         sharedGrpAnnotations = (AnnotationDetail [] )mys.getAttribute("sharedGrpAnnotations");
      }


    // isLargeSamples) {
	 if (con != null && localGrpAnnotations != null && localGrpAnnotations.length > 0) {
        annotations = GroupHelper.populateAnnotations (annotations, true, con, out);
          if (annotations != null) {
             for (i=0; i<annotations.length; i++){
                 if (annotations[i].isShare())
                 continue;
                 if (localftypeid2ftype.get("" + annotations[i].getFtypeId()) != null ) {
                    String [] ftypeString = null;
                  ftypeString =(String [] )localftypeid2ftype.get("" + annotations[i].getFtypeId());
                    String fmethod = null;
                    String fsource = null;
                    if (ftypeString != null && ftypeString != null){
                    fmethod = ftypeString[0];
                    fsource = ftypeString[1];
                    annotations[i].setFmethod(fmethod);
                    annotations[i].setFsource(fsource);
                    annotations[i].setTrackName(fmethod + ":" + fsource);
                    }
                 }
                 String chr = "";
                 if (localid2Chromosome.get("" + annotations[i].getRid())  != null){
                     chr = (String)localid2Chromosome.get("" + annotations[i].getRid());
                 annotations[i].setChromosome(chr);
                 }

                 String className = "";
                if (localftypeid2Gclass != null && localftypeid2Gclass.get("" + annotations[i].getFtypeId()) != null) {
                    className = (String )localftypeid2Gclass.get("" + annotations[i].getFtypeId());
                        annotations[i].setGclassName(className);
                }
                 annotations[i].setlff2value();
               }
          }
       }


     if (sharedConnection != null&& sharedGrpAnnotations != null && sharedGrpAnnotations.length > 0 )  {
          annotations = GroupHelper.populateAnnotations (annotations, false, sharedConnection, out);
              if (annotations != null) {
                     for (i=0; i<annotations.length; i++) {
                          if (!annotations[i].isShare())
                           continue;
                         if (shareftypeid2ftype.get("" + annotations[i].getFtypeId()) != null ) {
                            String [] ftypeString = null;

                          ftypeString =(String [] )shareftypeid2ftype.get("" + annotations[i].getFtypeId());

                            String fmethod = null;
                            String fsource = null;
                            if (ftypeString != null && ftypeString != null){
                            fmethod = ftypeString[0];
                            fsource = ftypeString[1];
                            annotations[i].setFmethod(fmethod);
                            annotations[i].setFsource(fsource);
                            annotations[i].setTrackName(fmethod + ":" + fsource);
                            }
                         }
                         String chr = "";
                         if (shareid2Chromosome.get("" + annotations[i].getRid())  != null){
                             chr = (String)shareid2Chromosome.get("" + annotations[i].getRid());
                         annotations[i].setChromosome(chr);
                         }

                         String className = "";
                        if (shareftypeid2Gclass != null && shareftypeid2Gclass.get("" + annotations[i].getFtypeId()) != null) {
                            className = (String )shareftypeid2Gclass.get("" + annotations[i].getFtypeId());
                                annotations[i].setGclassName(className);
                        }
                         annotations[i].setlff2value();
                       }
              }
        }
   //

   HashMap localName2fids = new HashMap ();
   HashMap sharegrpName2fids = new HashMap ();
    if (hasData && annotations != null && annotations.length >0) {
		if (annotations != null && con != null) {
			localName2fids = GroupHelper.getGrpName2fids(con, annotations,  true,  out);
			if (localName2fids != null && !localName2fids.isEmpty()) {
				annotations = GroupHelper.populateGroupText (verbose, con, annotations, localName2fids,  true, out);
				annotations = GroupHelper.populateAVP (verbose, con, annotations, localName2fids, true, out);
				}
		}

		if (annotations != null && sharedConnection != null) {
			sharegrpName2fids = GroupHelper.getGrpName2fids(sharedConnection, annotations, false, out);
			if (sharegrpName2fids  != null && !sharegrpName2fids.isEmpty()){
				annotations = GroupHelper.populateAVP (verbose,sharedConnection, annotations, sharegrpName2fids ,  false, out);
				annotations = GroupHelper.populateGroupText(verbose, sharedConnection,annotations,sharegrpName2fids,false, out);
			}
		}
     }
    else
       GenboreeMessage.setErrMsg(mys, "There is no annotation to be displayed.");
      Connection homeConnection = db.getConnection();
%>
<%@include file="include/saveLayout.incl" %>
<%
		String totalGroup = "0";
		if (totalAnnotations != null ) {
			 totalGroup = "" + totalAnnotations.length;
		    if (totalAnnotations.length > 1000  )
			totalGroup=Util.putCommas( "" + totalAnnotations.length);

		}
		         mys.setAttribute("totalGroup", totalGroup);
		totalGroup = (String)mys.getAttribute("totalGroup");

			String refseqId = SessionManager.getSessionDatabaseId(mys);
        int uploadId =  IDFinder.findUploadID(homeConnection, refseqId, dbName);

	    if (sortingColumnName == null)
	  sortingColumnName = "";


		int tooFewForMenuBtn = 29;
        int tooManyForMenuBtn = 150 ;
 %>
	<HTML>
	<head>
	<title><%=" My annotations "%></title>
	<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
	<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css" >
	<link rel="stylesheet" href="/javaScripts/extjs/resources/css/loading-genboree.css<%=jsVersion%>" type="text/css">
  <link rel="stylesheet" type="text/css" href="/javaScripts/extjs/resources/css/menu.css<%=jsVersion%>">
  <link rel="stylesheet" type="text/css" href="/javaScripts/extjs/resources/css/button.css<%=jsVersion%>">
  <link rel="stylesheet" type="text/css" href="/javaScripts/extjs/resources/css/qtips.css<%=jsVersion%>">
  <link rel="stylesheet" type="text/css" href="/javaScripts/extjs/resources/css/core.css<%=jsVersion%>">
  <link rel="stylesheet" type="text/css" href="/javaScripts/extjs/resources/css/reset-min.css<%=jsVersion%>">
  <link rel="stylesheet" type="text/css" href="/javaScripts/extjs/resources/css/ytheme-genboree.css<%=jsVersion%>">
  <!-- Set a local "blank" image file; default is a URL to extjs.com -->
  <script type='text/javascript'>
    Ext.BLANK_IMAGE_URL = '/javaScripts/extjs/resources/images/genboree/s.gif';
  </script>
<!-- END -->

<link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">
<link rel="stylesheet" href="/styles/samples.css<%=jsVersion%>" type="text/css">
<script type="text/javascript" SRC="/javaScripts/sorttable.js<%=jsVersion%>"></script>
<script type="text/javascript" SRC="/javaScripts/gbrowser.js<%=jsVersion%>"></script>
<script type="text/javascript">
tooFewForMenuBtn = <%= tooFewForMenuBtn %> ;
tooManyForMenuBtn = <%= tooManyForMenuBtn %> ;
var groupMode = "<%= groupMode %>" ;
var sortingArrow ='<%=sortingColumnOrder%>';
</script>
</head>
<BODY>
	  <%
		if(annotations != null && annotations.length >tooFewForMenuBtn && annotations.length <= tooManyForMenuBtn) // Then let's us a mask. Else not needed or too many anyway and we do something else
		{
	  %>
      <!-- PAGE LOADING MASK -->

      <div id="genboree-loading-mask" name="genboree-loading-mask" style="width:100%;height:100%;background:#e1c4ff;position:absolute;z-index:20000;left:0px;top:0px;">
        &#160;
      </div>
      <div id="genboree-loading" name="genboree-loading">
        <div class="genboree-loading-indicator">
          <img src="/javaScripts/extjs/resources/images/default/grid/loading.gif" style="width:16px; height:16px;" align="absmiddle">
           &#160;Initializing Page...
        </div>
      </div>
      <!-- include EVERYTHING ELSE after the loading indicator -->
  <%
    }
  %>
<!-- BEGIN: Extjs: Split Button Support -->
<script type="text/javascript" src="/javaScripts/extjs/adapter/prototype/prototype.js<%=jsVersion%>"></script> <!-- Stuff here used in rest of files... -->
<script type="text/javascript" src="/javaScripts/extjs/adapter/prototype/scriptaculous.js<%=jsVersion%>"></script> <!-- Stuff here used in rest of files... -->
<script type="text/javascript" src="/javaScripts/extjs/adapter/prototype/ext-prototype-adapter.js<%=jsVersion%>"></script> <!-- Stuff here used in rest of files... -->
<script type="text/javascript" src="/javaScripts/extjs/package/genboree/ext-menuBtn-only-pkg.js<%=jsVersion%>"></script>
<!-- BEGIN: Genboree Specific -->
<script type="text/javascript" src="/javaScripts/util.js<%=jsVersion%>"></script> <!-- Stuff here used in rest of files... -->
<script type="text/javascript" SRC="/javaScripts/editorCommon.js<%=jsVersion%>"></script>
<script type="text/javascript" SRC="/javaScripts/editMenuBtn.widget.js<%=jsVersion%>"></script>
<!-- END -->
<link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">
<link rel="stylesheet" href="/styles/tabularView.css<%=jsVersion%>" type="text/css">
<SCRIPT type="text/javascript" src="/javaScripts/prototype.js<%=jsVersion%>"></SCRIPT>
<SCRIPT type="text/javascript" src="/javaScripts/commonFunctions.js<%=jsVersion%>"></SCRIPT>
<SCRIPT type="text/javascript" src="/javaScripts/sample.js<%=jsVersion%>"></SCRIPT>

<SCRIPT type="text/javascript" src="/javaScripts/tabularView.js<%=jsVersion%>"></SCRIPT>
<style rel="stylesheet" type="text/css">
    /* Shows the image next to the button value */
    .x-btn-text-icon .x-btn-center .x-btn-text
    {
      background-image: url(/images/silk/application_form_edit.gif) ;
    }

  </style>
   <%
      if (annotations != null)
        for (i=0; i<annotations.length; i++) {
         AnnotationDetail  annotation = annotations [i];
         int fid =0;
            if (annotation != null)
                fid =annotation.getFid();
            else {
                System.err.println(" annotation: " + i + "  fid " + fid  + " current page index " + currentPageIndex );

                continue;}
         %>
         <script type="text/javascript">
       Ext.genboree.addRecord(<%=uploadId%>, <%=fid%>) ;
         </script>
         <%
         }
 %>
  <%@ include file="include/header.incl" %>
<%@ include file="include/navbar.incl" %>
		<%@ include file="include/message.incl" %>
		<form name="viewForm" id="viewForm" action="viewGroupAnnotations.jsp" method="post" >
		<input type="hidden" name="currentMode"  id="currentMode" value="<%=mode%>">
		<input type="hidden" name="sortingColumnName"  id="sortingColumnName" value="<%=Util.urlEncode(sortingColumnName)%>">
		<input type="hidden" name="sortingColumnOrder"  id="sortingColumnOrder">
		<%if (displayNames != null  && hasData) {%>
        <input type="hidden" name="currentPage" id="currentPage" value="<%=currentPage%>">
        <input type="hidden" name="navigator" id="navigator" value="">
        <table width="100%"   style="margin-bottom:5px;" border="1" cellpadding="2" cellspacing="1">
        <%@ include file="include/viewPageIndex.incl" %>
        </table>
	<table>
	<TR>   <TD>
	<div id="viewbk"  align="left" style="display:<%=viewDisplay%>; margin-bottom: 5px; margin-left: 0px;">
	<input type="submit" name="btnBack" value="Back"  class="btn" style="WIDTH:100">&nbsp;&nbsp
	</div>
	</TD>   </TR>
	</table>
       </td>
        <td width=10></td>
        <td class="shadow"></td>
        </tr>

        <tr>
        <td width=10 class="bkgd"></td>
        <td height=10 class="shadow"></td>
        <td width=10 class="shadow"></td>
        <td width=10 class="shadow"></td>
        </tr>
    </table>
    <table width="700" border="1" cellpadding="1" cellspacing="1" page-break-after="avoid" style="margin-bottom:0px; margin-top:10px;" >
        <TR align="center" >
        <TD class="form_header"> <b>(Total of <%=totalCount%>&nbsp;Annotations in <%=totalGroup%>  groups)</B> </td>
        </TR>
    </table>
     <table width="100%"  id="sampleView" page-break-before="avoid" style="margin-top:0px; margin-bottom:10px;"  class="sortable" border="1" cellpadding="1" cellspacing="1">
    <TR>
    <%
        int annoNameIndex = -1;
        if (displayNames != null) {
        String displayName = "";
			String displayArrow = "&nbsp;";
			for ( i=0; i<displayNames.length; i++){
			displayName = displayNames[i];

           	 if(sortingColumnName != null && sortingColumnName.equals(displayName) )
           	   displayArrow = sortingArrow;
                else displayArrow = "&nbsp;";


            if (displayName.equals("Anno. Name"))
                annoNameIndex = i;

            if (displayName != null){
                displayName = displayName.trim();
                    displayName = Util.htmlQuote(displayName);
                if (displayName.length() <50)
                displayName = "<nobr>" + displayName + "</nobr>";
            }
            else
                displayName = "";
        %>
<td class="form_header"   name="name_<%=i%>" id="id_<%=i%>"  align="center"   value="<%=Util.urlEncode(displayNames[i])%>"  onclick="sortingByColumn(<%=i%>, <%=displayNames.length%>, '<%=Util.urlEncode(displayNames[i])%>'); ">
<a href="#" class="sortheader"><font color="white"><%=displayName%></font></a><span id="span_<%=i%>" class="sortarrow"><%=displayArrow%> </span>
</td>
        <%}}%></TR>
        <%
        HashMap avpMap =  null;
           if (hasData &&  annotations != null){
            for ( i=0; i< annotations.length; i++) {
                AnnotationDetail annotation  =  annotations[i];
                if (annotation == null){
                    continue;
                }

                if (annotation.getAvp()!= null)
                avpMap =   annotation.getAvp();
                 HashMap lffMap = (HashMap)  annotation.getLff2value() ;
   %>
        <TR>
        <%
        String value =  "";
        String displayName2 = null;
        refseqId = SessionManager.getSessionDatabaseId(mys);
         String tdclass = "form_body3";
        for (int j=0; j<displayNames.length; j++){
            displayName2 =displayNames[j];
            value = "";
            tdclass = "form_body3";
            if (lffMap != null && lffMap.get(displayName2) != null)
			{    value = (String )lffMap.get(displayName2);

			}
			else if (avpMap != null && avpMap.get(displayName2)!= null)
			{   value = (String )((ArrayList)avpMap.get(displayName2)).get(0);


			}
            if (value==null)
                value = "";
            else
                value = value.trim();
            if (verbose && value.indexOf(",") >0)   {
                 String []values = value.split(", ");
                if (values != null  && values.length >1){
                    HashMap map = new HashMap ();
                     for (int n =0; n<values.length; n++)
                         map.put(values[n], "1");
                    values = (String[])map.keySet().toArray(new String [map.size()] );
                    value = "";
                     for (int n =0; n<values.length; n++)
                          value = value + "," + values[n];
                    if (value.length() >1)
                        value = value.substring(1);
                }
              }
            value = Util.htmlQuote(value);
            if (annoNameIndex >-1 && annoNameIndex == j) {
                long start = annotation.getStart();
                long end = annotation.getStop();


				long length = end - start;
                if (start > 0 && (start - length*.2) >0)
                start = (long)(start -length* 0.2);
                else
                start = 1;

				if (start <=0 )
				  start = 1;

				end = (long)(end + length *0.2);  // verification of end is not necessary here because it is done in gbrowser.jsp
                if (length <100 )
                end = start + 100;
				String chr = annotation.getChromosome();
                value = "<A href=\"/java-bin/gbrowser.jsp?refSeqId=" + refseqId + "&entryPointId=" + chr + "&from=" + start + "&to=" + end + " \">" + value + "</a>";
            }

          if (value.length() >= 50  )
                tdclass = "form_body2";
            if (displayName2.equals("\"Edit\" Link")) {
                try {
                        value = "<A href=\"#\"  onClick=\"winPopFocus('annotationEditor.jsp?upfid="+uploadId+":" +  annotation.getFid() + "', '_newWin')\"  >Edit </a>";
                }
                catch (Exception e) {
                  System.err.println(" <br> exption " + e.getMessage());
                  System.err.flush();
                }
                %>
      <TD class="<%=tdclass%>"  align="center">
         <%    if (annotation.isShare()) {
        %>
        Template Annotation (protected)
         <% }
         else { %>
         <% if(annotation != null && annotations.length > tooManyForMenuBtn) {// too many records on page for all to have button
        %>
        <a href="/java-bin/annotationEditorMenu.jsp?upfid=<%=uploadId%>:<%=annotation.getFid()%>" style="color: darkorchid;">Edit Menu</a>
        <%
        }
        else{
        %>
        <div id="editBtnDiv_<%=i%>" name="editBtnDiv_<%=i%>" class='editBtnDiv' style="margin-top: 2px;"></div>
        <%
        } %>
       </td>
        <% } }
        else { %>
        <TD class="<%=tdclass%>">
        <%="&nbsp;" + value%>
        </TD>
         <% }}%>
        </TR>
    <% }  %>
     </table>
     <% } %>
        <!--/div-->
    <table cellpadding="0" cellspacing="0" border="0" bgcolor="white" width="700" class='TOP'>
    <tr>
        <td width="10"></td>
        <td height="10"></td>
        <td width="10"></td>
        <td width="10" class="bkgd"></td>
    </TR>
    <TR>
        <td width="10"></td>
        <td height="10">
        <table>
            <TR>   <TD>
            <div id="viewbk"  align="left" style="display:<%=viewDisplay%>; margin-left: 0px;">
            <input type="submit" name="btnBack" value="Back"  class="btn" style="WIDTH:100">&nbsp;&nbsp
            </div>
            </TD>   </TR>
        </table>
        <table width="100%"  border="1" cellpadding="2" cellspacing="1"> <BR>
        <% if (mode==LffConstants.VIEW ) {%><%@ include file="include/viewPageIndexBottom.incl" %>
        <%}%></table>
<%
}
else if (mode >=0 || !hasData)  {%>
<input type="submit" name="btnBack" value="Cancel"  class="btn" style="WIDTH:100">&nbsp;&nbsp;
<%}%>
</form>
<%@ include file="include/footer.incl" %>
</BODY>
</HTML>
