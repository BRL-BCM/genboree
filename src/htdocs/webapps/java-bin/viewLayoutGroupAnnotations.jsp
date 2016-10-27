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
org.genboree.util.Util,
java.sql.Connection,
org.genboree.dbaccess.Refseq,
org.genboree.util.SessionManager"
%>
 <%@ page import="org.genboree.editor.Chromosome" %>
 <%@ include file="include/fwdurl.incl" %>

<%@ include file="include/userinfo.incl" %>
<%@ include file="include/pageInit.incl" %>
<%

	String chrName = null;

	 int totalNumGrpAnnotations = 0;
	 // initialization

	 dispNum = new int[]{20, 25, 50, 100, 200};
	 boolean ascendingSort = true;
	 displayNum = 50;
	 boolean sortingText = false;
	 boolean sortingAVP = false;
	 GenboreeMessage.clearMessage(mys);
	 AnnotationDetail[] localGrpAnnotations = null;
	 AnnotationDetail[] sharedGrpAnnotations = null;
	 boolean debugging = true;
	 HashMap localGroupName2fids = new HashMap();
	 HashMap sharedGroupName2fids = new HashMap();
	 int numSortNames = 0;

	 if (request.getParameter("groupMode") != null)
		 initPage = true;

	 boolean verbose = false;
	 String groupMode = request.getParameter("groupMode");

	 if (groupMode == null)
		 groupMode = "terse";
	 else if (groupMode.equals("verbose"))
		 verbose = true;

	 boolean isLargeSample = false;
	 // this part should put into include file

	 JSONObject json = null;
	 if (mys.getAttribute("urlJson") != null) {
		 json = (JSONObject) mys.getAttribute("urlJson");
		 mys.removeAttribute("urlJson");
	 }
	 else {
		 GenboreeMessage.setErrMsg(mys, " Some parameters are missing: layout. ");
		 GenboreeUtils.sendRedirect(request, response, "/java-bin/displaySelection.jsp?fromUrl=true");
		 return;
	 }
	 boolean sortingColumns = false;

	 String sortingColumnName = request.getParameter("sortingColumnName");
	 if (sortingColumnName != null) {
		 sortingColumnName = sortingColumnName.trim();
		 sortingColumnName = Util.urlDecode(sortingColumnName);
	 }

	 boolean restrictRegion = false;

	 int rid = -1;
	 long chrStart = -1;
	 long chrStop = -1;


	 String sessionRest = null;
	 if (chrName == null) {
		 if (mys.getAttribute("restrictRegion") != null)
			 sessionRest = (String) mys.getAttribute("restrictRegion");

		 if (sessionRest != null && sessionRest.equals("true"))
			 restrictRegion = true;
	 }


	Chromosome chromosome = null;
	if (mys.getAttribute("displayChromosome") != null) {
	chromosome = (Chromosome) mys.getAttribute("displayChromosome");
	if (chromosome != null) {
	rid = chromosome.getId();
	chrStart = chromosome.getStart();
	chrStop = chromosome.getStop();
		chrName = chromosome.getRefname();
	}
	}


	 String sortingColumnOrder = request.getParameter("sortingColumnOrder");
	 String sortingArrow = "&nbsp;";
	 if (sortingColumnOrder != null && sortingColumnOrder.length() > 0) {
		 if (sortingColumnOrder.equals("up"))
			 sortingArrow = "&uarr;";
		 else if (sortingColumnOrder.equals("down")) {
			 sortingArrow = "&darr;";
			 ascendingSort = false;
		 }
		 mys.setAttribute("sortingColumnOrder", sortingColumnOrder);
	 }


	 if (sortingColumnOrder != null && sortingColumnOrder.length() > 0) {
		 sortingColumns = true;
		 //mys.setAttribute("sortingByColumnName", "y");
	 }

	 boolean isLargeSamples = false;
	 int annoLimit = 300000;
	 int avpLimit = 1000000;
	 int localNumAnnotations = 0;
	 int shareNumAnnotations = 0;
	 String[] sharedTracks = null;
	 int[] localftypeids = null;
	 int[] shareftypeids = null;
	 int localAVPAssociationCount = 0;
	 int shareAVPAssociationCount = 0;
	 String dbName = SessionManager.getSessionDatabaseName(mys);
	 String sharedbName = null;
   int genboreeUserId = Util.parseInt( myself.getUserId(), -1 );

   if (mys.getAttribute("layoutSharedDbName") != null)
		 sharedbName = (String) mys.getAttribute("layoutSharedDbName");

	 Connection con = null;
	 if (dbName != null)
		 con = db.getConnection(dbName);

	 Connection sharedConnection = null;
	 if (sharedbName != null)
		 sharedConnection = db.getConnection(sharedbName);

	 HashMap shareTrack2Ftypes = null;
	 if (sharedConnection != null)
		 shareTrack2Ftypes = Utility.retrivesTrack2Ftype(sharedConnection, sharedbName, genboreeUserId );

	 if (shareTrack2Ftypes != null && !shareTrack2Ftypes.isEmpty()) {
		 shareTrack2Ftypes.remove("Component:Chromosome");
		 shareTrack2Ftypes.remove("SuperComponent:Sequence");


		 sharedTracks = (String[]) (shareTrack2Ftypes.keySet().toArray(new String[shareTrack2Ftypes.size()]));
		 if (sharedTracks != null)
			 mys.setAttribute("sharetracks", sharedTracks);
	 }

	 HashMap trackNameMap = new HashMap();


	 URLParams params = null;
	 if (mys.getAttribute("URLParams") != null)
		 params = (URLParams) mys.getAttribute("URLParams");
	 else {
		 GenboreeMessage.setErrMsg(mys, " Some parameters are missing: layout. ");
		 GenboreeUtils.sendRedirect(request, response, "/java-bin/displaySelection.jsp?fromUrl=true");
		 return;
	 }

	 String[] selectedTrackNames = params.getTrackNameArr();
	 int i = 0;
	 // the following code handles user selected tracks
	 if (selectedTrackNames != null) {
		 HashMap selectedTrackHash = new HashMap();
		 for (i = 0; i < selectedTrackNames.length; i++) {
			 selectedTrackHash.put(selectedTrackNames[i], "y");
			 mys.setAttribute("selectedTrackHash", selectedTrackHash);
		 }

		 HashMap localftype2ftypeIds = null;

		 if (con != null)
			 localftype2ftypeIds = Utility.retrieveFtype2ftypeId( con, dbName, genboreeUserId );
		 HashMap shareftype2ftypeIds = null;
		 ArrayList localTrackList = new ArrayList();
		 ArrayList shareTrackList = new ArrayList();


		 if (sharedConnection != null)
			 shareftype2ftypeIds = Utility.retrieveFtype2ftypeId( sharedConnection, sharedbName, genboreeUserId );
		 String id = null;
		 for (i = 0; i < selectedTrackNames.length; i++) {
			 if (localftype2ftypeIds != null && localftype2ftypeIds.get(selectedTrackNames[i]) != null)
				 localTrackList.add(selectedTrackNames[i]);
			 if (shareftype2ftypeIds != null && shareftype2ftypeIds.get(selectedTrackNames[i]) != null)
				 shareTrackList.add(selectedTrackNames[i]);
		 }

		 if (!localTrackList.isEmpty()) {
			 localftypeids = new int[localTrackList.size()];
			 for (i = 0; i < localTrackList.size(); i++) {
				 String trackName = (String) localTrackList.get(i);
				 id = (String) localftype2ftypeIds.get(trackName);
				 localftypeids[i] = Integer.parseInt(id);
			 }
		 }

		 if (!shareTrackList.isEmpty()) {
			 shareftypeids = new int[shareTrackList.size()];
			 for (i = 0; i < shareTrackList.size(); i++) {
				 String trackName = (String) shareTrackList.get(i);
				 id = (String) shareftype2ftypeIds.get(trackName);
				 shareftypeids[i] = Integer.parseInt(id);
			 }
		 }
		 mys.setAttribute("localftypeids", localftypeids);
		 mys.setAttribute("shareftypeids", shareftypeids);
	 }  // selected reack name snot null


	 if (mys.getAttribute("localftypeids") != null) {
		 localftypeids = (int[]) mys.getAttribute("localftypeids");
		 //mys.removeAttribute("localLayoutFtypeids");
	 }





	 if (mys.getAttribute("shareftypeids") != null)
		 shareftypeids = (int[]) mys.getAttribute("shareftypeids");


	 if (localftypeids != null) {
			  if (!restrictRegion)  {
				  localNumAnnotations = Utility.countAnnotations(con, localftypeids);
					  localAVPAssociationCount = LffUtility.countAVPAssociation(con, localftypeids, 1000000, localNumAnnotations, out);
					  }
			  else  {
				 localNumAnnotations = Utility.countAnnotations(con, localftypeids, rid, chrStart, chrStop);
		    }
		  }

     int[] shareFids = null;
	if (sharedbName != null && shareftypeids != null) {
			if (!restrictRegion)   {
			shareNumAnnotations = Utility.countAnnotations(sharedConnection, shareftypeids);
			if (localAVPAssociationCount < 1000000)
			shareAVPAssociationCount = LffUtility.countAVPAssociation(sharedConnection, shareftypeids, 1000000, shareNumAnnotations, out);
			}
			else {
			shareNumAnnotations = Utility.countAnnotations(sharedConnection, shareftypeids, rid, chrStart, chrStop);
			if (localAVPAssociationCount < 1000000)
			shareAVPAssociationCount = AttributeRetriever.countAVPAssociationByChromosomeRegion(sharedConnection, shareftypeids, 1000000,  shareNumAnnotations, rid, chrStart, chrStop, out);
			}
	  }


	 int numSelectedAssociation = localAVPAssociationCount + shareAVPAssociationCount;
	 int totalNumAnnotations = localNumAnnotations + shareNumAnnotations;


	               String totalCount = "" + totalNumAnnotations;
	 if (totalNumAnnotations > 1000)
		 totalCount = Util.putCommas(totalCount);

	 if (totalNumAnnotations > annoLimit || numSelectedAssociation > avpLimit)
		 isLargeSample = true;

	 if (groupMode == null)
		 groupMode = "groupedTerse";
	 String[] localtracks = null;

	 String invalidTracks = "";
	 response.addDateHeader("Expires", 0L);
	 response.addHeader("Cache-Control", "no-cache, no-store");
	 GenboreeMessage.clearMessage(mys);

	 String orderedSortNames[] = null;
	 String displayNames[] = null;

	 AnnotationDetail[] localAnnotations = null;
	 AnnotationDetail[] sharedAnnotations = null;
	 boolean recurPage = request.getParameter("navigator") != null;
	 boolean fromSelection = request.getParameter("viewData") != null;
	 boolean hasMode = request.getParameter("mode") != null;
	 HashMap shareddb2Ftypes = null;
	 boolean hasSharedTrack = false;
	 String[] avpDisplayNames = null;

	 if (request.getParameter("btnBack") != null) {
		// LffUtility.clearCache(mys);
		 GenboreeUtils.sendRedirect(request, response, "/java-bin/displaySelection.jsp?fromUrl=true");
		 return;
	 }

	 String[] avpNames = null;
	 ArrayList avpDisplayNameList = new ArrayList();
	 ArrayList avpSortNameList = new ArrayList();
	 AnnotationDetail[] newannos = null;
	 int numLocalAnnos = 0;
	 int numShareAnnos = 0;
	 int uploadId = 0;
	 String[] fdataSortNames = null;
	 HashMap nameid2values = null;
	 HashMap valueid2values = null;
	 int[] attNameIds = null;
	 boolean hasData = true;

	 String fidAttributes[][] = null;
	 String localfidAttributes[][] = null;
	 String sharefidAttributes[][] = null;

	 ArrayList sortList = null;
	 HashMap avp = null;
	 HashMap localid2Chromosome = null;
	 HashMap shareid2Chromosome = null;
	 boolean needSort = false;
	 String[] lffSortNames = null;
	 HashMap localftypeid2ftype = null;
	 HashMap localfid2anno = new HashMap();
	 HashMap shareftypeid2ftype = null;
	 HashMap sharefid2anno = new HashMap();
	 boolean sortByAVP = false;
	 int[] displayIndexes = null;
	 ArrayList lffNameArrayList = new ArrayList();
	 for (i = 0; i < LffConstants.LFF_COLUMNS.length; i++)
		 lffNameArrayList.add(LffConstants.LFF_COLUMNS[i]);
	 LffConstants.setHash();

	 //  String []   fids  = null;
	 String[] sharefids = null;
	 String[] localfids = null;
	 ArrayList lffAttributes = null;
	 ArrayList avpAttributes = new ArrayList();
	 ArrayList allLffColumns = new ArrayList();
	 HashMap localfid2hash = null;
	 HashMap sharefid2hash = null;
	 AnnotationDetail[] annotations = null;
	 AnnotationDetail[] totalAnnotations = null;
	 boolean isFromLayoutURL = false;

	 int tooFewForMenuBtn = 29;
	 int tooManyForMenuBtn = 150;

	 ArrayList lffSortNameList = new ArrayList();
	 HashMap order2Att = new HashMap();
	 int mode = -1;
	 Refseq rseq = null;
	 HashMap localftypeid2Gclass = null;
	 HashMap shareftypeid2Gclass = null;
	 boolean noAttributeSelected = false;
	 String viewDisplay = "block";
	 String[] dbNames = null;

	 currentPageIndex = 0;
	 currentPage = "0";

	 if (initPage) {
		 displayNames = LffUtility.parseJson(json, "rearrange_list_1");
		 if (displayNames == null || displayNames.length == 0) {
			 GenboreeMessage.setErrMsg(mys, "Please select some attributes for annotation display. ");
			 GenboreeUtils.sendRedirect(request, response, "/java-bin/urldisplaySelection.jsp?fromUrl=true");
			 return;
		 }
		 else {
			 mys.setAttribute("displayNames", displayNames);

			 if (displayNames != null)
				 for (int j = 0; j < displayNames.length; j++) {
					 displayNames[j] = Util.urlDecode(displayNames[j]);
				 }

			 orderedSortNames = LffUtility.parseJson(json, "rearrange_list2");
			 if (orderedSortNames != null) {
				 int index = -1;
				 for (int j = 0; j < orderedSortNames.length; j++) {
					 orderedSortNames[j] = Util.urlDecode(orderedSortNames[j]);
					 index = orderedSortNames[j].indexOf("_sort");
					 if (index > 0)
						 orderedSortNames[j] = orderedSortNames[j].substring(0, index);
				 }

				 for (i = 0; i < orderedSortNames.length; i++) {
					 if (!lffNameArrayList.contains(orderedSortNames[i]))
						 avpDisplayNameList.add(orderedSortNames[i]);
				 }
				 avpDisplayNames = (String[]) avpDisplayNameList.toArray(new String[avpDisplayNameList.size()]);
			 }

			 if (orderedSortNames != null && orderedSortNames.length > 0) {
				 sortList = new ArrayList();
				 numSortNames = orderedSortNames.length;
				 for (i = 0; i < orderedSortNames.length; i++) {
					 sortList.add(orderedSortNames[i]);
					 if (!lffNameArrayList.contains(orderedSortNames[i])) {
						 sortByAVP = true;
						 avpSortNameList.add(orderedSortNames[i]);
					 }
				 }

				 for (int n = 0; n < orderedSortNames.length; n++) {
					 if (lffNameArrayList.contains(orderedSortNames[n]))
						 lffSortNameList.add(orderedSortNames[n]);
				 }

				 if (!lffSortNameList.isEmpty())
					 lffSortNames = (String[]) lffSortNameList.toArray(new String[lffSortNameList.size()]);
			 }

			 if (sharedConnection != null)
				 shareTrack2Ftypes = Utility.retrivesTrack2Ftype(sharedConnection, sharedbName, genboreeUserId );

			 if (shareTrack2Ftypes != null && !shareTrack2Ftypes.isEmpty()) {
				 shareTrack2Ftypes.remove("Component:Chromosome");
				 shareTrack2Ftypes.remove("SuperComponent:Sequence");
				 sharedTracks = (String[]) (shareTrack2Ftypes.keySet().toArray(new String[shareTrack2Ftypes.size()]));
				 if (sharedTracks != null)
					 mys.setAttribute("sharetracks", sharedTracks);
			 }


			 if (sharedTracks != null)
				 for (i = 0; i < sharedTracks.length; i++)
					 trackNameMap.put(sharedTracks[i], "y");
		 }
	 }
	 else {  // recuring page
		 dbName = SessionManager.getSessionDatabaseName(mys);
		 if (mys.getAttribute("dbNames") != null)
			 dbNames = (String[]) mys.getAttribute("dbNames");

		 String sharedTrackId = null;
		 if (mys.getAttribute("ftypeid2sharedbNames") != null) {
			 HashMap map = (HashMap) mys.getAttribute("ftypeid2sharedbNames");
			 sharedTrackId = ((String[]) map.keySet().toArray(new String[map.size()]))[0];
			 sharedbName = (String) map.get(sharedTrackId);
		 }

		 if (dbNames != null && sharedbName == null) {
			 for (i = 0; i < dbNames.length; i++) {
				 if (!dbNames[i].equals(dbName)) {
					 sharedbName = dbNames[i];
					 break;
				 }
			 }
		 }
		 if (dbName != null)
			 con = db.getConnection(dbName);

		 if (sharedbName != null)
			 sharedConnection = db.getConnection(sharedbName);
		 if (mys.getAttribute("localftypeids") != null) {
			 localftypeids = (int[]) mys.getAttribute("localftypeids");
		 }
		 if (mys.getAttribute("shareftypeids") != null)
			 shareftypeids = (int[]) mys.getAttribute("shareftypeids");
	 }

	 HashMap lffConstantMap = new HashMap();
	 for (int j = 0; j < LffConstants.LFF_COLUMNS.length; j++) {
		 lffConstantMap.put(LffConstants.LFF_COLUMNS[j], "y");
	 }
	 if (orderedSortNames != null && orderedSortNames.length > 0) {
		 for (i = 0; i < orderedSortNames.length; i++) {
			 if (orderedSortNames[i].equals(LffConstants.LFF_COLUMNS[12])) {
				 sortingText = true;
				 break;
			 }

			 if (orderedSortNames[i].equals(LffConstants.LFF_COLUMNS[13])) {
				 sortingText = true;
				 break;
			 }
		 }

		 for (i = 0; i < orderedSortNames.length; i++) {
			 if (lffConstantMap.get(orderedSortNames[i]) == null) {
				 sortingAVP = true;
				 break;
			 }
		 }
	 }


	 for (i = 0; i < LffConstants.LFF_COLUMNS.length; i++)
		 lffNameArrayList.add(LffConstants.LFF_COLUMNS[i]);
	 LffConstants.setHash();

	 for (i = 0; i < org.genboree.tabular.LffConstants.LFF_COLUMNS.length; i++)
		 allLffColumns.add(org.genboree.tabular.LffConstants.LFF_COLUMNS[i]);

	 // GET NUMBER OF ANNOTATIONS PER PAGE
	 if (request.getParameter("app") != null) {
		 String temp = request.getParameter("app");
		 displayNum = Integer.parseInt(temp);
	 }


	 if (mys.getAttribute("displayNum") != null) {
		 String sessionDisplayNum = (String) mys.getAttribute("displayNum");
		 int sessionNum = Integer.parseInt(sessionDisplayNum);
		 if (sessionNum != displayNum) {
			 paging = true;
		 }
		 mys.setAttribute("displayNum", "" + displayNum);
	 }

	 if (request.getParameter("groupMode") != null) {
		 currentPageIndex = 0;
		 currentPage = "0";
		 initPage = true;
		 mys.setAttribute("lastPageIndex", "0");
		 mys.removeAttribute("lastStartPageNum");
		 mys.removeAttribute("lastEndPageNum");
		 mys.setAttribute("lastStartPageNum", "" + 0);
		 mode = LffConstants.VIEW;
		 initPage = true;
		 mys.setAttribute("lastMode", "" + LffConstants.VIEW);
	 }

	 if (mys.getAttribute("lastStartPageNum") != null)
		 sstartPageNum = (String) mys.getAttribute("lastStartPageNum");
	 HashMap localftype2chromsomeMap = new HashMap();
	 if (con != null)
		 localftype2chromsomeMap = GroupHelper.mapftypeid2chromsome(con, out);

	 HashMap shareftype2chromsomeMap = new HashMap();
	 if (sharedConnection != null)
		 shareftype2chromsomeMap = GroupHelper.mapftypeid2chromsome(sharedConnection, out);


	 int sessionTotalNumAnno = 0;
	 String sessionTotal = null;
	 if (mys.getAttribute("totalNumAnnotations_VGA") != null) {
		 sessionTotal = (String) mys.getAttribute("totalNumAnnotations_VGA");
		 try {
			 sessionTotalNumAnno = Integer.parseInt(sessionTotal);
		 }
		 catch (Exception e) {
			 GenboreeUtils.sendRedirect(request, response, "/java-bin/displaySelection.jsp?fromBrowser=View");
			 return;
		 }
	 }

	 if (!initPage && totalNumAnnotations != sessionTotalNumAnno) {
		 GenboreeUtils.sendRedirect(request, response, "/java-bin/displaySelection.jsp?fromBrowser=View");
		 return;
	 }


	 if (request.getParameter("navigator") != null)
		 initPage = false;

	 if (initPage) {
		 if (displayNames != null) {

			 if (orderedSortNames != null) {
				 for (i = 0; i < orderedSortNames.length; i++) {
					 if (lffConstantMap.get(orderedSortNames[i]) == null)
						 avpDisplayNameList.add(orderedSortNames[i]);
				 }
				 avpDisplayNames = (String[]) avpDisplayNameList.toArray(new String[avpDisplayNameList.size()]);
			 }
		 }

		 if (orderedSortNames != null && orderedSortNames.length > 0) {
			 sortList = new ArrayList();
			 numSortNames = orderedSortNames.length;
			 for (i = 0; i < orderedSortNames.length; i++) {
				 sortList.add(orderedSortNames[i]);
				 if (lffConstantMap.get(orderedSortNames[i]) == null) {
					 avpSortNameList.add(orderedSortNames[i]);
				 }
				 else {
					 lffSortNameList.add(orderedSortNames[i]);
				 }
			 }

		 }

		 if (con != null) {
			 if (localftypeids != null && localftypeids.length > 0)
				 localftypeid2Gclass = Utility.retrieveFtype2Gclass(con, localftypeids);
			 localftypeid2ftype = Utility.retrieveFtypeid2ftype(con, dbName, genboreeUserId );
			 localid2Chromosome = Utility.retrieveRid2Chromosome(con);
		 }

		 if (sharedbName != null) {
			 if (shareftypeids != null && shareftypeids.length > 0)
				 shareftypeid2Gclass = Utility.retrieveFtype2Gclass(sharedConnection, shareftypeids);
			 if (sharedConnection == null || sharedConnection.isClosed())
				 sharedConnection = db.getConnection(sharedbName);
			 shareftypeid2ftype = Utility.retrieveFtypeid2ftype(sharedConnection, sharedbName, genboreeUserId );
			 shareid2Chromosome = Utility.retrieveRid2Chromosome(sharedConnection);
		 }

		 mys.setAttribute("totalNumAnnotations_VGA", "" + totalNumAnnotations);
		 mys.setAttribute("localftypeid2Gclass", localftypeid2Gclass);
		 mys.setAttribute("localftypeid2ftype", localftypeid2ftype);
		 mys.setAttribute("localid2Chromosome", localid2Chromosome);
		 mys.setAttribute("shareftypeid2Gclass", shareftypeid2Gclass);
		 mys.setAttribute("shareftypeid2ftype", shareftypeid2ftype);
		 mys.setAttribute("shareid2Chromosome", shareid2Chromosome);

		 // case 1: small samples
		 if (totalNumAnnotations > 0 || !initPage) {
			 hasData = true;
		 }


		if (!isLargeSamples && hasData) {
		AnnotationGroup localAnnoGrp = null;
		if (localftypeids != null && localftypeids.length > 0)  {
		if (!restrictRegion) {
		localAnnoGrp = GroupHelper.retrieveGroupAnnotations(localftypeids, localftypeid2Gclass, localftypeid2ftype, localid2Chromosome, localftype2chromsomeMap, con, out);
		}
		else
		localAnnoGrp = GroupHelper.retrieveGroupAnnotationsByChromosomeRegion(localftypeids,  rid, chrStart, chrStop, localftypeid2Gclass, localftypeid2ftype, localid2Chromosome, localftype2chromsomeMap, con, out);
		}
		int localgrpNum = 0;
		if (localAnnoGrp != null) {
		if (localAnnoGrp.getAnnos() != null)
		localGrpAnnotations = localAnnoGrp.getAnnos();
		localGroupName2fids = localAnnoGrp.getGroupName2Fids();
		mys.setAttribute("localGrpAnnotations", localGrpAnnotations);
		mys.setAttribute("localGroupName2fids", localGroupName2fids);
		if (localGrpAnnotations != null && sortingText)
		localGrpAnnotations = GroupHelper.populateGroupText(verbose, con, localGrpAnnotations, localGroupName2fids, true, out);

		if (localGrpAnnotations != null && sortByAVP)
		localGrpAnnotations = GroupHelper.populateAVP(verbose, con, localGrpAnnotations, localGroupName2fids, true, out);

		if (localGrpAnnotations != null)
		localgrpNum = localGrpAnnotations.length;
		}
					int	 sharegrpnum = 0;
						 AnnotationGroup shareAnnoGrp = null;
						 if (shareftypeids != null && shareftypeids.length > 0)
							if (restrictRegion) {
							shareAnnoGrp = GroupHelper.retrieveGroupAnnotationsByChromosomeRegion(shareftypeids, rid, chrStart, chrStop,shareftypeid2Gclass, shareftypeid2ftype, shareid2Chromosome, shareftype2chromsomeMap, sharedConnection, out);
							}
							else {
								shareAnnoGrp = GroupHelper.retrieveGroupAnnotations (shareftypeids, shareftypeid2Gclass, shareftypeid2ftype, shareid2Chromosome, shareftype2chromsomeMap, sharedConnection, out);
    							}
							if (shareAnnoGrp != null) {
							 if (shareAnnoGrp.getAnnos() != null)
								 sharedGrpAnnotations = shareAnnoGrp.getAnnos();
							 sharedGroupName2fids = shareAnnoGrp.getGroupName2Fids();

							 if (sharedGrpAnnotations != null && sharedGrpAnnotations.length > 0 && sortingText) {
								 sharedGrpAnnotations = GroupHelper.populateGroupText(verbose, sharedConnection, sharedGrpAnnotations, sharedGroupName2fids, true, out);
							 }
							 if (sharedGrpAnnotations != null && sharedGrpAnnotations.length > 0 && sortByAVP) {
								 sharedGrpAnnotations = GroupHelper.populateAVP(verbose, sharedConnection, sharedGrpAnnotations, sharedGroupName2fids, false, out);
							 }
							 mys.setAttribute("sharedGrpAnnotations", sharedGrpAnnotations);
							 mys.setAttribute("sharedGroupName2fids", sharedGroupName2fids);
							 if (sharedGrpAnnotations != null && sharedGrpAnnotations.length > 0)
								 sharegrpnum = sharedGrpAnnotations.length;
						 }

			 totalNumGrpAnnotations = localgrpNum + sharegrpnum;



			 AnnotationDetail[] tempTotal = new AnnotationDetail[totalNumGrpAnnotations];
			 int baseIndex = 0;
			 if (localGrpAnnotations != null && localGrpAnnotations.length > 0) {
				 for (i = 0; i < localGrpAnnotations.length; i++) {
					 tempTotal[i] = localGrpAnnotations[i];
				 }
				 baseIndex = localGrpAnnotations.length;
			 }

			 if (sharedGrpAnnotations != null && sharedGrpAnnotations.length > 0) {
				 for (i = 0; i < sharedGrpAnnotations.length; i++) {
					 tempTotal[i + baseIndex] = sharedGrpAnnotations[i];
					 tempTotal[i + baseIndex].setShare(true);
				 }
			 }

			 totalAnnotations = tempTotal;

			 if (orderedSortNames != null && totalNumGrpAnnotations > 1)
				 totalAnnotations = AnnotationSorter.sortAllAnnotations(orderedSortNames, totalAnnotations);
		 }
		 else if (isLargeSamples) {

			 String sortName = null;
			 if (orderedSortNames != null)
				 sortName = orderedSortNames[0];
			 if (localftypeids != null) {
				 AnnotationGroup localGroup = GroupHelper.retrieveLargeAnnoGroup(localftypeids, localftype2chromsomeMap, con, out);
				 localGrpAnnotations = localGroup.getAnnos();
				 localGroupName2fids = localGroup.getGroupName2Fids();


			 } else {
				localGrpAnnotations = null;
				 localGroupName2fids = null;
			 }

			 	 mys.setAttribute("localGrpAnnotations", localGrpAnnotations);
				 mys.setAttribute("localGroupName2fids", localGroupName2fids);


			 if (shareftypeids != null) {
				 AnnotationGroup sharedGroup = GroupHelper.retrieveLargeAnnoGroup(shareftypeids, shareftype2chromsomeMap, sharedConnection, out);
				 sharedGrpAnnotations = sharedGroup.getAnnos();
				 sharedGroupName2fids = sharedGroup.getGroupName2Fids();

				 if (sharedGrpAnnotations != null) {
					 for (i = 0; i < sharedGrpAnnotations.length; i++) {
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

			 totalAnnotations = GroupHelper.mergeAnnotations(localGrpAnnotations, sharedGrpAnnotations);

			 if (totalAnnotations != null)
				 totalNumGrpAnnotations = totalAnnotations.length;

			 if (orderedSortNames != null) {
				 HashMap localvalue2fids = new HashMap();
				 HashMap sharevalue2fids = new HashMap();

				 if (sortingAVP) {
					 HashMap localvalue2anno = new HashMap();
					 if (localftypeids != null && localGrpAnnotations != null && localGrpAnnotations.length > 0) {
						 int localsortNameId = AttributeRetriever.retrieveNameId(con, sortName);

						 String values = null;
						 String[] localGenevalueids = null;
						 String[] fids = null;
						 ArrayList list = null;
						 int count = 0;
						 for (i = 0; i < localGrpAnnotations.length; i++) {
							 list = (ArrayList) localGroupName2fids.get(localGrpAnnotations[i].getGname() + "_" + localGrpAnnotations[i].getFtypeId() + "_" + localGrpAnnotations[i].getRid());
							 fids = (String[]) list.toArray(new String[list.size()]);

							 values = null;
							 if (fids != null && fids.length > 0)
								 localGenevalueids = GroupHelper.retrieveSingleAttributeValueIds(con, fids, localsortNameId, out);


							 if (localGenevalueids != null && localGenevalueids.length > 0)
								 values = GroupHelper.retrieveGeneAttValue(con, localGenevalueids, verbose, out);

							 if (values != null)
								 values = values.trim();
							 if (values == null || values == "")
								 values = "zzzz";

							 HashMap m = new HashMap();
							 m.put(sortName, values);
							 localGrpAnnotations[i].setAvp(m);

							 ArrayList annolist = null;
							 if (localvalue2anno.get(values) == null)
								 annolist = new ArrayList();
							 else
								 annolist = (ArrayList) localvalue2anno.get(values);

							 annolist.add(localGrpAnnotations[i]);

							 localvalue2anno.put(values, annolist);
							 //   localAnnotations[i].setAvp(new HashMap ().put(sortName, values));
						 }
					 }


					 HashMap sharevalue2anno = new HashMap();
					 if (sharedGrpAnnotations != null && sharedGrpAnnotations.length > 0) {
						 int sharesortNameId = AttributeRetriever.retrieveNameId(sharedConnection, sortName);
						 String values = null;
						 String[] shareGenevalueids = null;
						 String[] fids = null;
						 ArrayList list = null;

						 int count = 0;
						 for (i = 0; i < sharedGrpAnnotations.length; i++) {
							 list = (ArrayList) sharedGroupName2fids.get(sharedGrpAnnotations[i].getGname() + "_" + sharedGrpAnnotations[i].getFtypeId() + "_" + sharedGrpAnnotations[i].getRid());
							 fids = (String[]) list.toArray(new String[list.size()]);

							 values = null;
							 if (fids != null && fids.length > 0)
								 shareGenevalueids = GroupHelper.retrieveSingleAttributeValueIds(sharedConnection, fids, sharesortNameId, out);


							 if (shareGenevalueids != null && shareGenevalueids.length > 0)
								 values = GroupHelper.retrieveGeneAttValue(sharedConnection, shareGenevalueids, verbose, out);

							 if (values != null)
								 values = values.trim();
							 if (values == null || values == "")
								 values = "zzzz";

							 HashMap m = new HashMap();
							 m.put(sortName, values);
							 sharedGrpAnnotations[i].setAvp(m);

							 ArrayList annolist = null;
							 if (sharevalue2anno.get(values) == null)
								 annolist = new ArrayList();
							 else
								 annolist = (ArrayList) sharevalue2anno.get(values);

							 annolist.add(sharedGrpAnnotations[i]);

							 sharevalue2anno.put(values, annolist);

						 }
					 }

					 String[] localkeys = null;
					 if (!localvalue2anno.isEmpty()) {
						 localkeys = (String[]) localvalue2anno.keySet().toArray(new String[localvalue2anno.size()]);
					 }


					 String[] sharekeys = null;
					 if (!sharevalue2anno.isEmpty()) {
						 sharekeys = (String[]) sharevalue2anno.keySet().toArray(new String[sharevalue2anno.size()]);
					 }

					 HashMap keyMap = new HashMap();
					 if (localkeys != null && localkeys.length > 0) {
						 for (i = 0; i < localkeys.length; i++) {
							 if (localkeys[i] != null)
								 keyMap.put(localkeys[i], "y");
						 }
					 }
					 if (sharekeys != null && sharekeys.length > 0) {
						 for (i = 0; i < sharekeys.length; i++) {
							 if (sharekeys[i] != null)
								 keyMap.put(sharekeys[i], "y");
						 }
					 }

					 String[] keys = (String[]) keyMap.keySet().toArray(new String[keyMap.size()]);
					 Arrays.sort(keys);
					 ArrayList temp = new ArrayList();

					 ArrayList locallist = null;
					 ArrayList sharelist = null;

					 if (keys != null && keys.length > 0) {
						 for (i = 0; i < keys.length; i++) {
							 locallist = (ArrayList) localvalue2anno.get(keys[i]);
							 if (locallist != null) {
								 for (int j = 0; j < locallist.size(); j++) {
									 temp.add((AnnotationDetail) locallist.get(j));
								 }
							 }

							 sharelist = (ArrayList) sharevalue2anno.get(keys[i]);
							 if (sharelist != null) {
								 for (int j = 0; j < sharelist.size(); j++) {
									 temp.add((AnnotationDetail) sharelist.get(j));
								 }
							 }
						 }
					 }
					 if (!temp.isEmpty()) {
						 totalAnnotations = (AnnotationDetail[]) temp.toArray(new AnnotationDetail[temp.size()]);
						 totalNumGrpAnnotations = totalAnnotations.length;
					 }

				 }
				 else {  // sort: non-avp sort

					 // if sorting by type or subtype, populate annotation with name
					 if (sortName.equals(LffConstants.LFF_COLUMNS[2]) || sortName.equals(LffConstants.LFF_COLUMNS[3])) {
						 if (localGrpAnnotations != null) {
							 for (i = 0; i < localGrpAnnotations.length; i++) {
								 if (localftypeid2ftype.get("" + localGrpAnnotations[i].getFtypeId()) != null) {
									 String[] ftypeString = null;

									 ftypeString = (String[]) localftypeid2ftype.get("" + localGrpAnnotations[i].getFtypeId());

									 String fmethod = null;
									 String fsource = null;
									 if (ftypeString != null && ftypeString != null) {
										 fmethod = ftypeString[0];
										 fsource = ftypeString[1];
										 localGrpAnnotations[i].setFmethod(fmethod);
										 localGrpAnnotations[i].setFsource(fsource);
										 localGrpAnnotations[i].setTrackName(fmethod + ":" + fsource);
									 }
								 }
							 }
						 }
						 if (sharedGrpAnnotations != null)
							 for (i = 0; i < sharedGrpAnnotations.length; i++) {
								 if (localftypeid2ftype.get("" + sharedGrpAnnotations[i].getFtypeId()) != null) {
									 String[] ftypeString = null;

									 ftypeString = (String[]) localftypeid2ftype.get("" + sharedGrpAnnotations[i].getFtypeId());
									 String fmethod = null;
									 String fsource = null;
									 if (ftypeString != null && ftypeString != null) {
										 fmethod = ftypeString[0];
										 fsource = ftypeString[1];
										 sharedGrpAnnotations[i].setFmethod(fmethod);
										 sharedGrpAnnotations[i].setFsource(fsource);

										 sharedGrpAnnotations[i].setTrackName(fmethod + ":" + fsource);

									 }
								 }
							 }
					 }
					 // sort by class name
					 else if (sortName.equals(LffConstants.LFF_COLUMNS[1])) {
						 if (localGrpAnnotations != null) {
							 for (i = 0; i < localGrpAnnotations.length; i++) {
								 String className = "";
								 if (localftypeid2Gclass.get("" + localGrpAnnotations[i].getFtypeId()) != null) {
									 className = (String) localftypeid2Gclass.get("" + localGrpAnnotations[i].getFtypeId());


									 localGrpAnnotations[i].setGclassName(className);
								 }
							 }
						 }
						 if (sharedGrpAnnotations != null) {
							 for (i = 0; i < sharedGrpAnnotations.length; i++) {
								 String className = "";
								 if (shareftypeid2Gclass.get("" + sharedGrpAnnotations[i].getFtypeId()) != null) {
									 className = (String) shareftypeid2Gclass.get("" + sharedGrpAnnotations[i].getFtypeId());
									 sharedGrpAnnotations[i].setGclassName(className);
								 }
							 }
						 }
					 }
					 // sort by chromosome
					 else if (sortName.equals(LffConstants.LFF_COLUMNS[4])) {
						 if (localGrpAnnotations != null) {
							 for (i = 0; i < localGrpAnnotations.length; i++) {
								 String chr = "";
								 if (localftype2chromsomeMap.get("" + localGrpAnnotations[i].getFtypeId()) != null) {
									 chr = (String) localid2Chromosome.get("" + localGrpAnnotations[i].getRid());
									 localGrpAnnotations[i].setChromosome(chr);
								 }
							 }
						 }
						 if (sharedGrpAnnotations != null) {
							 for (i = 0; i < sharedGrpAnnotations.length; i++) {
								 String chr = "";
								 if (shareftype2chromsomeMap.get("" + sharedGrpAnnotations[i].getFtypeId()) != null) {
									 chr = (String) shareid2Chromosome.get("" + sharedGrpAnnotations[i].getRid());
									 sharedGrpAnnotations[i].setChromosome(chr);
								 }
							 }
						 }
					 }
					 // sort by Text
					 else if (sortingText) {
						 if (con != null && localGrpAnnotations != null)
							 localGrpAnnotations = GroupHelper.populateGroupText(verbose, con, localGrpAnnotations, localGroupName2fids, true, out);
						 if (sharedConnection != null && sharedGrpAnnotations != null)
							 sharedGrpAnnotations = GroupHelper.populateGroupText(verbose, sharedConnection, sharedGrpAnnotations, sharedGroupName2fids, false, out);
					 }
					 else {
						 if (sortName.indexOf(". Start") > 0) {
							 if (con != null && localGrpAnnotations != null)
								 localGrpAnnotations = GroupHelper.populateStart(con, localGrpAnnotations, out);
							 if (sharedConnection != null && sharedGrpAnnotations != null)
								 sharedGrpAnnotations = GroupHelper.populateStart(sharedConnection, sharedGrpAnnotations, out);
						 }
						 else if (sortName.indexOf(". Stop") > 0) {
							 if (con != null && localGrpAnnotations != null)
								 localGrpAnnotations = GroupHelper.populateStop(con, localGrpAnnotations, out);
							 if (sharedConnection != null && sharedGrpAnnotations != null)
								 sharedGrpAnnotations = GroupHelper.populateStop(sharedConnection, sharedGrpAnnotations, out);
						 }
						 else if (sortName.indexOf("QStop") > 0) {
							 if (con != null && localGrpAnnotations != null)
								 localGrpAnnotations = GroupHelper.populateTargetStop(con, localGrpAnnotations, out);
							 if (sharedConnection != null && sharedGrpAnnotations != null)
								 sharedGrpAnnotations = GroupHelper.populateTargetStop(sharedConnection, sharedGrpAnnotations, out);

						 }
						 else if (sortName.indexOf("QStart") > 0) {
							 if (con != null && localGrpAnnotations != null)
								 localGrpAnnotations = GroupHelper.populateTargetStart(con, localGrpAnnotations, out);
							 if (sharedConnection != null && sharedGrpAnnotations != null)
								 sharedGrpAnnotations = GroupHelper.populateTargetStart(sharedConnection, sharedGrpAnnotations, out);
						 }
						 else if (sortName.indexOf("Score") > 0) {
							 if (con != null && localGrpAnnotations != null)
								 localGrpAnnotations = GroupHelper.populateScore(con, localGrpAnnotations, out);
							 if (sharedConnection != null && sharedGrpAnnotations != null)
								 sharedGrpAnnotations = GroupHelper.populateScore(sharedConnection, sharedGrpAnnotations, out);
						 }
						 else if (sortName.indexOf("Phase") > 0) {
							 if (con != null && localGrpAnnotations != null)
								 localGrpAnnotations = GroupHelper.populatePhase(con, localGrpAnnotations, out);
							 if (sharedConnection != null && sharedGrpAnnotations != null)
								 sharedGrpAnnotations = GroupHelper.populatePhase(sharedConnection, sharedGrpAnnotations, out);
						 }
						 else if (sortName.indexOf("Strand") > 0) {
							 if (con != null && localGrpAnnotations != null)
								 localGrpAnnotations = GroupHelper.populateStrand(con, localGrpAnnotations, out);
							 if (sharedConnection != null && sharedGrpAnnotations != null)
								 sharedGrpAnnotations = GroupHelper.populateStrand(sharedConnection, sharedGrpAnnotations, out);
						 }
					 }

					 totalAnnotations = GroupHelper.mergeAnnotations(localGrpAnnotations, sharedGrpAnnotations);
					 if (totalAnnotations != null)
						 totalNumGrpAnnotations = totalAnnotations.length;

					 //  AnnotationDetail[] sortedTotalAnnotations =  //sortLargeAnos(totalAnnotations, sortName);
					 AnnotationDetail[] sortedTotalAnnotations = null;
					 if (orderedSortNames != null && totalAnnotations != null) {
						 sortedTotalAnnotations = AnnotationSorter.sortAllAnnotations(orderedSortNames, totalAnnotations);
					 }
					 if (sortedTotalAnnotations != null) {
						 totalAnnotations = sortedTotalAnnotations;
					 }
				 }

			 }


			 if (totalNumGrpAnnotations == 0) {
				 GenboreeMessage.setErrMsg(mys, " No annotations are found with the track information provided.");

		GenboreeUtils.sendRedirect(request, response, "/java-bin/displaySelection.jsp?fromUrl=true");
				 hasData = false;
				 return;

			 }
			 else {
				 hasData = true;
				 if (totalAnnotations != null)
					 totalNumGrpAnnotations = totalAnnotations.length;

			 }


		 }  // end of large sample retrieval
		 // end of data retrieval
		 mys.setAttribute("totalAnnotations_VGA", totalAnnotations);
		 mys.setAttribute("totalNumGrpAnnotations", "" + totalNumGrpAnnotations);
		 paging = true;
		 if (displayNames != null && displayNames.length > 0) {
			 for (int k = 0; k < displayNames.length; k++) {
				 if (!lffNameArrayList.contains(displayNames[k]))
					 avpDisplayNameList.add(displayNames[k]);
			 }
		 }

		 if (!avpDisplayNameList.isEmpty()) {
			 avpDisplayNames = (String[]) avpDisplayNameList.toArray(new String[avpDisplayNameList.size()]);
			 mys.setAttribute("avpDisplayNames", avpDisplayNames);
		 }
		 hasData = false;
		 if (totalAnnotations != null && totalAnnotations.length > 0)
			 hasData = true;

	 }
	 else {  //  recuring page
		 displayNames = (String[]) mys.getAttribute("displayNames");
		 if (mys.getAttribute("avpDisplayNames") != null)
			 avpDisplayNames = (String[]) mys.getAttribute("avpDisplayNames");
		 String temp = null;
		 temp = (String) mys.getAttribute("displayNum");

		 if (temp != null) {
			 int displayN = Integer.parseInt(temp);
			 if (displayN != displayNum)
				 paging = true;
		 }
		 if (mys.getAttribute("totalAnnotations_VGA") != null)
			 totalAnnotations = (AnnotationDetail[]) mys.getAttribute("totalAnnotations_VGA");

		 if (totalAnnotations != null)
			 totalNumGrpAnnotations = totalAnnotations.length;

		 if (totalAnnotations != null && totalAnnotations.length > 0)
			 hasData = true;
		 localGrpAnnotations = (AnnotationDetail[]) mys.getAttribute("localGrpAnnotations");
		 localGroupName2fids = (HashMap) mys.getAttribute("localGroupName2fids");
		 sharedGrpAnnotations = (AnnotationDetail[]) mys.getAttribute("sharedGrpAnnotations");
		 sharedGroupName2fids = (HashMap) mys.getAttribute("sharedGroupName2fids");

		 localftypeid2ftype = (HashMap) mys.getAttribute("localftypeid2ftype");
		 localftypeid2Gclass = (HashMap) mys.getAttribute("localftypeid2Gclass");
		 localid2Chromosome = (HashMap) mys.getAttribute("localid2Chromosome");
		 shareftypeid2ftype = (HashMap) mys.getAttribute("shareftypeid2ftype");
		 shareftypeid2Gclass = (HashMap) mys.getAttribute("shareftypeid2Gclass");
		 shareid2Chromosome = (HashMap) mys.getAttribute("shareid2Chromosome");
	 }

	 if (request.getParameter("currentPage") != null)
		 currentPage = request.getParameter("currentPage");
	 else
		 currentPage = "0";


	 Date d6 = new Date();
	 if (hasData) {
		 // start of include file
		 if (paging && totalNumGrpAnnotations > 0) {
			 page2Annotations = new HashMap();
			 numPages = totalNumGrpAnnotations / displayNum;
			 if ((totalNumGrpAnnotations % displayNum) != 0)
				 numPages += 1;

			 int baseIndex = 0;

			 AnnotationDetail[] annos = null;
			 for (int k = 0; k < numPages; k++) {
				 baseIndex = k * displayNum;
				 if ((totalNumGrpAnnotations - k * displayNum) >= displayNum) {
					 annos = new AnnotationDetail[displayNum];
					 for (int m = 0; m < displayNum; m++)
						 annos[m] = totalAnnotations[baseIndex + m];
					 page2Annotations.put("" + k, annos);
				 }
				 else {
					 int remainNum = totalNumGrpAnnotations - k * displayNum;
					 if (remainNum > 0) {
						 annos = new AnnotationDetail[remainNum];
						 for (int m = 0; m < remainNum; m++)
							 annos[m] = totalAnnotations[baseIndex + m];
						 page2Annotations.put("" + k, annos);
					 }
				 }
			 }

			 if (request.getParameter("currentPage") != null) {
				 String indexPage = request.getParameter("currentPage");
				 if (indexPage != null) {
					 int tempN = Integer.parseInt(indexPage);
					 currentPageIndex = tempN;
					 if (currentPageIndex < 0)
						 currentPageIndex = 0;

					 if (currentPageIndex > (numPages - 1))
						 currentPageIndex = numPages - 1;

					 currentPage = "" + currentPageIndex;
					 mys.setAttribute("lastPageIndex", currentPage);

					 if (numPages > maxDisplay) {
						 modNum = currentPageIndex % maxDisplay;
						 if (modNum == 0) {
							 startPageNum = currentPageIndex;
							 endPageNum = currentPageIndex + (maxDisplay - 1);
							 if (endPageNum > (numPages - 1))
								 endPageNum = numPages - 1;

							 mys.setAttribute("lastStartPageNum", "" + startPageNum);
							 mys.setAttribute("lastEndPageNum", "" + endPageNum);
						 }
						 else {
							 startPageNum = (currentPageIndex / maxDisplay) * maxDisplay;
							 endPageNum = startPageNum + (maxDisplay - 1);
							 if (endPageNum > (numPages - 1))
								 endPageNum = numPages - 1;

							 mys.setAttribute("lastStartPageNum", "" + startPageNum);
							 mys.setAttribute("lastEndPageNum", "" + endPageNum);
						 }

					 }
					 else {
						 endPageNum = numPages - 1;
						 startPageNum = 0;
						 mys.setAttribute("lastStartPageNum", "" + startPageNum);
						 mys.setAttribute("lastEndPageNum", "" + endPageNum);
					 }
				 }
			 }
			 else {
				 currentPageIndex = 0;
				 currentPage = "0";
				 mys.setAttribute("lastStartPageNum", "" + 0);
			 }

			 mys.setAttribute("page2Annotation_GAV", page2Annotations);
			 mys.setAttribute("numPages", "" + numPages);
			 doPaging = false;
		 }
		 else
			 page2Annotations = (HashMap) mys.getAttribute("page2Annotation_GAV");

		 if (!initPage)
			 page2Annotations = (HashMap) mys.getAttribute("page2Annotation_GAV");

		 // end of include file
 %>
    <%@ include file="include/annotationView.incl" %>
    <%
}

   if (hasData)
        annotations = (AnnotationDetail[])page2Annotations.get(currentPage);
    if (annotations == null || annotations.length==0) {
		  if (restrictRegion)
		   GenboreeMessage.setErrMsg(mys, "No annotations to display in your selected track(s) and chromsome region " + chrName + ":" + chrStart +"-" +  chrStop+ ".");
		  GenboreeUtils.sendRedirect(request, response, "/java-bin/displaySelection.jsp?fromUrl=true");
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


    //   if (isLargeSamples) {
       if (con != null && localGrpAnnotations != null && localGrpAnnotations.length > 0) {
        annotations = GroupHelper.populateAnnotations (annotations, true, con, out);
		  if (annotations != null) {
             for (i=0; i<annotations.length; i++) {
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
                if (localftypeid2Gclass.get("" + annotations[i].getFtypeId()) != null) {
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
		if (shareftypeid2Gclass.get("" + annotations[i].getFtypeId()) != null) {
		className = (String )shareftypeid2Gclass.get("" + annotations[i].getFtypeId());
		annotations[i].setGclassName(className);
		}
		annotations[i].setlff2value();
		}
		}
		}

 //   }


   HashMap localName2fids = new HashMap ();
   HashMap sharegrpName2fids = new HashMap ();
    if (hasData && annotations != null && annotations.length >0) {
      if (annotations != null && con != null) {
        localName2fids = GroupHelper.getGrpName2fids(con, annotations,  true,  out);
        if (localName2fids != null && !localName2fids.isEmpty()) {
            annotations = GroupHelper.populateGroupText (verbose, con, annotations, localName2fids,  true,  out);
            annotations = GroupHelper.populateAVP (verbose, con, annotations, localName2fids, true,  out);
         }
      }

      if (annotations != null && sharedConnection != null) {
        sharegrpName2fids = GroupHelper.getGrpName2fids(sharedConnection, annotations, false, out);
        if (sharegrpName2fids  != null && !sharegrpName2fids.isEmpty()){
             annotations = GroupHelper.populateAVP (verbose,sharedConnection, annotations, sharegrpName2fids ,  false,  out);
            annotations = GroupHelper.populateGroupText(verbose, sharedConnection, annotations,  sharegrpName2fids,   false,  out);
        }
      }
     }
    else
       GenboreeMessage.setErrMsg(mys, "There is no annotation to be displayed.");

       	String totalGroup = "0";
		if (totalAnnotations != null ) {
			 totalGroup = "" + totalAnnotations.length;
		    if (totalAnnotations.length > 1000  )
			totalGroup=Util.putCommas( "" + totalAnnotations.length);

		}
		         mys.setAttribute("totalGroup", totalGroup);
		totalGroup = (String)mys.getAttribute("totalGroup");

        String refseqId = SessionManager.getSessionDatabaseId(mys);

		Connection homeConnection = db.getConnection();
		if (dbName != null && refseqId != null)
		try {
		uploadId = IDFinder.findUploadID(homeConnection, refseqId, dbName);
		}
		catch (Exception e) {
		e.printStackTrace();
		}


	String actionString =	"viewGroupAnnotations.jsp"    ;
		if (restrictRegion)
		        actionString = "viewGroupAnnotationsByRegion.jsp";

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
<!-- END -->
<link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">
<link rel="stylesheet" href="/styles/samples.css<%=jsVersion%>" type="text/css">
	<script type="text/javascript">
tooFewForMenuBtn = <%= tooFewForMenuBtn %> ;
tooManyForMenuBtn = <%= tooManyForMenuBtn %> ;
var sortingArrow ='<%=sortingColumnOrder%>';
var groupMode = "<%= groupMode %>" ;
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
<script type="text/javascript" SRC="/javaScripts/gbrowser.js<%=jsVersion%>"></script>
  <style rel="stylesheet" type="text/css">
    /* Shows the image next to the button value */
    .x-btn-text-icon .x-btn-center .x-btn-text
    {
      background-image: url(images/silk/application_form_edit.gif) ;
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
<form name="viewForm" id="viewForm" action="<%=actionString%>" method="post" >
<input type="hidden" name="currentMode"  id="currentMode" value="<%=mode%>">
	<input type="hidden" name="sortingColumnName"  id="sortingColumnName" value="<%=sortingColumnName== null ? sortingColumnName:Util.urlEncode(sortingColumnName)%>"><input type="hidden" name="sortingColumnOrder"  id="sortingColumnOrder">
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
            if (displayName.equals("Anno. Name"))
                annoNameIndex = i;
             	 if(sortingColumnName != null && sortingColumnName.equals(displayName) )
           	   displayArrow = sortingArrow;
                else displayArrow = "&nbsp;";
            if (displayName != null){
                displayName = displayName.trim();
                // displayName = displayName.replaceAll(" ", "&nbsp;" );
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
                value = (String )lffMap.get(displayName2);
            else if (avpMap != null && avpMap.get(displayName2)!= null)
                value = (String )((ArrayList)avpMap.get(displayName2)).get(0);


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

                end = (long)(end + length *0.2);  // verification of end is not necessary here because it is done in gbrowser.jsp


                if (length <100 )
                end = start + 100;


				if (start < 1)
				start = 1;

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
                  System.err.println(" <br> exception " + e.getMessage());
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
     <%  }%>
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
