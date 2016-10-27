<%@ page import="org.genboree.samples.Attribute,
	java.io.*, 
	org.genboree.message.GenboreeMessage,
	java.sql.Connection,
	org.genboree.dbaccess.Refseq,
	org.genboree.editor.Chromosome, 
	java.util.*,
	org.genboree.util.SessionManager,
	org.genboree.manager.tracks.Utility,
	org.genboree.util.Util,
	java.sql.PreparedStatement,
	java.sql.ResultSet,
	java.sql.SQLException,
	org.json.JSONObject,
	org.genboree.tabular.*,
	org.json.JSONArray,
	org.json.JSONException"
     session= "false"    
 %>
<%@ page import="org.genboree.editor.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/group.incl" %>  
<%@ include file="include/sessionGrp.incl" %>
<%
	 String ALL_CHROMOSOMES = "All Chromosomes"; 
	boolean displayAVP = false; 
	boolean displayText = false; 
	boolean restrictRegion = false;
        // out.println ("entered download"); 
	int rid = -1;
	long chrStart = -1;
	long chrStop = -1;
	String groupMode = "none"; 
	String orderedSortNames []= null;       
    String []  orderedDisplayNames =  null;   
    String jsparams =  request.getParameter("jsparams");        
     if (jsparams == null  || jsparams.length()==0) {            
		//GenboreeUtils.sendRedirect(request, response, "/java-bin/displaySelection.jsp");
		return;
	}
	else {
        JSONObject json = new JSONObject( jsparams ) ; 
		if (json != null) {
            orderedDisplayNames = LffUtility.parseJson(json, "rearrange_list_1")  ; 
            if ( orderedDisplayNames != null &&  orderedDisplayNames.length >0) 
				mys.setAttribute("displayNames", orderedDisplayNames);

            if ( orderedDisplayNames != null) 
            for (int j=0; j< orderedDisplayNames.length ; j++) {  
             orderedDisplayNames[j] = Util.urlDecode( orderedDisplayNames[j]);
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

 %>
<% boolean initPage= true; %>
<%@ include file="include/chromosome.incl" %>
<%@ include file="include/saveLayout.incl" %> <%   
		String [] selectedTrackNames = null;      

	selectedTrackNames = request.getParameterValues("dbTrackNames");
	if (selectedTrackNames != null) {
                HashMap selectedTrackHash = new HashMap (); 
                for (int i=0; i<selectedTrackNames.length; i++) {
			selectedTrackHash.put(selectedTrackNames[i], "y");
			mys.setAttribute("selectedTrackHash", selectedTrackHash);
		}
	}
	// boolean debugging = true; 
	 //boolean debugging = false; 
	boolean debugging = false;
	ArrayList avpNameList = new ArrayList();
	response.addDateHeader("Expires", 0L);
	response.addHeader("Cache-Control", "no-cache, no-store");
	GenboreeMessage.clearMessage(mys);
	int flushCounter = 0;
	int flushLimit = 10000;
	final int sleepTime = 2000;
	if (request.getParameter("btnBack") != null) {
		LffUtility.clearCache(mys);
	//	response.sendRedirect("displaySelection.jsp?mode=DownLoad");
		return;
	}
	String sharedbName = null;
	String[] sharefids = null;
	int[] shareFids = null;
	String[] localfids = null;
	String[] avpNames = null;
	int numShareAnnos = 0;
	int numLocalAnnos = 0;
	AnnotationDetail[] sharedAnnotations = null;
	AnnotationDetail[] localAnnotations = null;
	Connection sharedConnection = null;
	int[] localftypeids = null;
	int[] shareftypeids = null;
	HashMap localfid2hash = null;
	HashMap sharefid2hash = null;
	HashMap localftypeid2ftype = null;
	HashMap localfid2anno = null; 
	HashMap shareftypeid2ftype = null;
	HashMap sharefid2anno = new HashMap();
	HashMap localftypeid2Gclass = null;
	HashMap shareftypeid2Gclass = null;
	HashMap localid2Chromosome = null;
	HashMap shareid2Chromosome = null;
	 HashMap order2Att = new HashMap();
	HashMap ftypeid2Gclass = null;
	ArrayList localPageFids  = null; 
	String []pagefids = null; 
	HashMap fid2order = null; 
	ArrayList sharedPageFids = null; 
	HashMap localpagefid2anno = null; 
	
	String localfidAttributes[][] = null;
	String sharefidAttributes[][] = null;
	int currentIndex = 0;
	String[] fdataSortNames = null;
	HashMap nameid2values = null;
	HashMap valueid2values = null;
	int[] attNameIds = null;
	boolean hasData = true;
	boolean isLargeSamples = false;
	String fidAttributes[][] = null;

	ArrayList sortList = null;
	HashMap avp = null;

		String blank = ""; 	 
	HashMap sharepagefid2anno = null; 
	AnnotationDetail[]  sharedPageAnnotations = null;
	ArrayList shareFidList = null; 
	AnnotationDetail [] newAnnos = null; 
	   AnnotationDetail [] localPageAnnotations = null; 
	   String gclass = null;   	 
  StringBuffer sb = null; 
		   int sharepagefids[]= null; 
	boolean needSort = false;
	String[] lffSortNames = null;
	HashMap ftypeid2ftype = null;
	
	boolean sortByAVP = false;

	ArrayList lffNameArrayList = new ArrayList();
	for (int i = 0; i < LffConstants.LFF_COLUMNS.length; i++)
		lffNameArrayList.add(LffConstants.LFF_COLUMNS[i]);
	LffConstants.setHash();
	LffConstants.poulateLffMap();
	HashMap lffAttMap = LffConstants.lffName2fdataName;

	String[] fids = null;
	ArrayList lffAttributes = null;
	ArrayList avpAttributes = new ArrayList();
	ArrayList allLffColumns = new ArrayList();
	for (int i = 0; i < org.genboree.tabular.LffConstants.LFF_COLUMNS.length; i++)
		allLffColumns.add(org.genboree.tabular.LffConstants.LFF_COLUMNS[i]);
	int totalNumAnnotations = 0;
	String dbName = null;
	Connection con = null;

	AnnotationDetail[] annotations = null;
	AnnotationDetail[] totalAnnotations = null;

	HashMap order2sortName = null;
	ArrayList avpDisplayNameList = new ArrayList();
	String totalCount = "0";

	int i = 0;
	ArrayList lffSortNameList = new ArrayList();
	
	int mode = -1;
	Refseq rseq = null;
	
	boolean noAttributeSelected = false;
	String[] displayNames = null;
	ArrayList avpSortNameList = new ArrayList();
	// determine the mode    

	dbName = SessionManager.getSessionDatabaseName(mys);
	String[] dbNames = null;
	if (mys.getAttribute("dbNames") != null)
		dbNames = (String[]) mys.getAttribute("dbNames");
	String sharedTrackId = null;

	if (mys.getAttribute("ftypeid2sharedbNames") != null) {
		HashMap map = (HashMap) mys.getAttribute("ftypeid2sharedbNames");
		sharedTrackId = ((String[]) map.keySet().toArray(new String[map.size()]))[0];
		sharedbName = (String) map.get(sharedTrackId);
		map.clear (); 
		map = null; 
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
  int genboreeUserId = Util.parseInt( myself.getUserId(), -1 );
	int localAVPAssociationCount = 0;
	int shareAVPAssociationCount = 0;


	if (sharedbName != null)
		sharedConnection = db.getConnection(sharedbName);
	
	if (sharedConnection == null ||sharedConnection.isClosed()) 
	  //out.println(" no shared connection "); 
	
	
	if (mys.getAttribute("localftypeids") != null) 
		localftypeids = (int[]) mys.getAttribute("localftypeids");

	if (mys.getAttribute("shareftypeids") != null)
		shareftypeids = (int[]) mys.getAttribute("shareftypeids");

	// first, display all names for selection
	if (localftypeids != null) {
		if (!restrictRegion)  {
		numLocalAnnos = Utility.countAnnotations(con, localftypeids);
		
		localAVPAssociationCount = AttributeRetriever.countAVPAssociation(con, localftypeids, 1000000, numLocalAnnos, out);	  
		}
		else  {
			numLocalAnnos = Utility.countAnnotations(con, localftypeids, rid, chrStart, chrStop);
			localAVPAssociationCount = AttributeRetriever.countAVPAssociationByChromosomeRegion(con, localftypeids, 1000000, numLocalAnnos,rid, chrStart, chrStop, out);
		}
	}

	
	if (sharedbName != null && shareftypeids != null) {
		if (!restrictRegion)   {
			if (localAVPAssociationCount < 1000000)
				shareAVPAssociationCount = AttributeRetriever.countAVPAssociation(sharedConnection, shareftypeids, 1000000, numShareAnnos, out);
        			
			numShareAnnos = Utility.countAnnotations(sharedConnection, shareftypeids);
		}
		      else {
		  	numShareAnnos = Utility.countAnnotations(sharedConnection, shareftypeids, rid, chrStart, chrStop);
		
		if (localAVPAssociationCount < 1000000)
			shareAVPAssociationCount = AttributeRetriever.countAVPAssociationByChromosomeRegion(sharedConnection, shareftypeids, 1000000, numShareAnnos, rid, chrStart, chrStop, out);
		}		
	
	}


	if (shareFids != null && shareFids.length > 0)
		numShareAnnos = shareFids.length;
	totalNumAnnotations = numLocalAnnos + numShareAnnos;
	int numSelectedAssociation = localAVPAssociationCount + shareAVPAssociationCount;

	if (totalNumAnnotations > 300000 || numSelectedAssociation > 1000000)
		isLargeSamples = true;

	String[] avpDisplayNames = null;
	displayNames = request.getParameterValues("displayOrder");
	if (displayNames == null) {
		GenboreeMessage.setErrMsg(mys, "Please select some attributes for annotation display. ");
		//selectDisplay="block"; 
		noAttributeSelected = true;
	}
	else {
		mys.setAttribute("orderedDisplayNames", orderedDisplayNames);
		// step 2: get sort Names and order 
		if (orderedSortNames != null) {
			for (i = 0; i < orderedSortNames.length; i++) {
				if (lffAttMap.get(orderedSortNames[i]) == null) {
					avpDisplayNameList.add(orderedSortNames[i]);
				}
			}
			avpDisplayNames = (String[]) avpDisplayNameList.toArray(new String[avpDisplayNameList.size()]);
		}
	}

	if (orderedSortNames != null && orderedSortNames.length > 0) {
		sortList = new ArrayList();
		for (i = 0; i < orderedSortNames.length; i++) {
			sortList.add(orderedSortNames[i]);
			if (lffAttMap.get(orderedSortNames[i]) == null) {
				sortByAVP = true;
				avpSortNameList.add(orderedSortNames[i]);
			}
			else
				lffSortNameList.add(orderedSortNames[i]);
		}

		if (!lffSortNameList.isEmpty())
			lffSortNames = (String[]) lffSortNameList.toArray(new String[lffSortNameList.size()]);

	}

	if (con != null) {
		localftypeid2Gclass = Utility.retrieveFtype2Gclass(con, localftypeids);
		localftypeid2ftype = Utility.retrieveFtypeid2ftype(con, dbName, genboreeUserId );
		localid2Chromosome = Utility.retrieveRid2Chromosome(con);
	}

	if (sharedbName != null) {
		shareftypeid2Gclass = Utility.retrieveFtype2Gclass(sharedConnection, shareftypeids);
		if (sharedConnection == null || sharedConnection.isClosed())
			sharedConnection = db.getConnection(sharedbName);
		shareftypeid2ftype = Utility.retrieveFtypeid2ftype(sharedConnection, sharedbName, genboreeUserId );
		shareid2Chromosome = Utility.retrieveRid2Chromosome(sharedConnection);
	}

	if (orderedSortNames != null) {
		fdataSortNames = LffUtility.covertNames(orderedSortNames);
		if (fdataSortNames == null || fdataSortNames.length == 0)
			fdataSortNames = null;
		needSort = true;
	}
	
	
		if (!isLargeSamples && hasData) {
		if (restrictRegion) {
%>
    <%@ include file="include/smallAnnoRetrieveByChrom.incl" %>
    <%    
    }  
	else {	// retrive small annos	
		if (numShareAnnos >0  &&   (orderedSortNames == null  ||  orderedSortNames.length ==0))  {
			shareFids = AttributeRetriever.retrieveFidByFtypeids(sharedConnection, shareftypeids,  numShareAnnos );       
			
			if (shareFids != null &&shareFids.length > 0) {
			sharedAnnotations = new AnnotationDetail [shareFids.length];             
			for (i=0; i<shareFids.length; i++) {
			sharedAnnotations[i] =  new AnnotationDetail(shareFids[i]);  
			sharedAnnotations[i].setShare(true);
			}
			}
		}
    
		if (numLocalAnnos >0   &&   (orderedSortNames == null  ||  orderedSortNames.length ==0)) {
			int []fidlocal = AttributeRetriever.retrieveFidByFtypeids(con, localftypeids, numLocalAnnos);       
			localAnnotations = new AnnotationDetail [fidlocal.length]; 
			for (i=0; i<fidlocal.length; i++)
			localAnnotations[i] =  new AnnotationDetail (fidlocal[i]);  
			fidlocal = null; 
		}  
	
	
		// case 1.1. has  sorting 
		if (orderedSortNames != null){  
			if (localftypeids != null && localftypeids.length > 0 ) {
				  localAnnotations = null; 
				
			localAnnotations = AttributeRetriever.retrieveSortAnnotations(con, localftypeids, sortList, fdataSortNames, localftypeid2ftype,localftypeid2Gclass, localid2Chromosome );                                                       

	        if ( localAnnotations != null && localAnnotations.length >0) {                   
					int localfidsInt[]  = new int [localAnnotations.length] ; 
					for ( i=0; i<localAnnotations.length; i++)       
							localfidsInt[i] = localAnnotations[i].getFid();
					    
			// if sorting by text
					if (displayText || sortList.contains(LffConstants.LFF_COLUMNS[12]) || sortList.contains(LffConstants.LFF_COLUMNS[13])) {           
					       localfid2anno = new HashMap (); 
					    
					    for ( i=0; i<localAnnotations.length; i++)       
						localfid2anno.put(blank + localAnnotations[i].getFid() , localAnnotations[i]);					
						
						AttributeRetriever.populateAnnotationText (localAnnotations,localfid2anno, con);           
								 						
						if (sortList.contains(LffConstants.LFF_COLUMNS[12]) || sortList.contains(LffConstants.LFF_COLUMNS[13]))            									
						needSort = true; 
					} 
            // retrieves  avp data
					avpNames =(String []) avpSortNameList.toArray(new String [avpSortNameList.size()]);                                                                   
					
					
					if (displayAVP || (avpNames != null && avpNames.length > 0) ) {  
						needSort = true;    
						
						localfid2hash = AttributeRetriever.retrieveSmallNumAnnotationAVPs(con, localfidsInt);
						
						localfidsInt = null; 
						if (localfid2hash != null  && localAnnotations != null) {
							for (int m=0; m<localAnnotations.length; m++){
								if (localAnnotations[m] != null  && localfid2hash.get("" + localAnnotations[m].getFid() ) != null) {
									avp = (HashMap )localfid2hash.get("" + localAnnotations[m].getFid());									
									localAnnotations[m].setAvp(avp);
								}
							}						
						}
						if (avpNames != null && avpNames.length > 0)   									  
							needSort = true;   
					}        
				
				 localfidsInt = null; 
			}
        }
        
        
            if (shareftypeids != null && shareftypeids.length > 0 ) {
              sharedAnnotations = null; 
                sharedAnnotations = AttributeRetriever.retrieveSortAnnotations(sharedConnection, shareftypeids, sortList, fdataSortNames, shareftypeid2ftype,shareftypeid2Gclass, shareid2Chromosome);               
                if (sharedAnnotations != null) {
						int []   sharefidsInt = new int [sharedAnnotations.length] ; 
						for ( i=0; i<sharedAnnotations.length; i++){        
							sharefidsInt[i] = sharedAnnotations[i].getFid();
							sharedAnnotations[i].setShare(true);
						}
                // if sorting by text
                if (displayText || sortList.contains(LffConstants.LFF_COLUMNS[12]) || sortList.contains(LffConstants.LFF_COLUMNS[13])) {           
                    
                     for ( i=0; i<sharedAnnotations.length; i++)        
                        sharefid2anno.put(blank + sharedAnnotations[i].getFid() , sharedAnnotations[i]);
                   
                    AttributeRetriever.populateAnnotationText (sharedAnnotations,sharefid2anno, con);           
                     sharefid2anno.clear();
					  sharefid2anno = null; 
					if (sortList.contains(LffConstants.LFF_COLUMNS[12]) || sortList.contains(LffConstants.LFF_COLUMNS[13]))                                         
                    needSort = true; 
                }
					
					
				// retrieves  avp data
                if (displayAVP || avpNames != null && avpNames.length > 0 ) {
					 if (avpNames != null && avpNames.length > 0 )
						needSort = true;                        
                        sharefid2hash = AttributeRetriever.retrieveSmallNumAnnotationAVPs(sharedConnection, sharefidsInt);
                        if (sharefid2hash != null  &&  sharedAnnotations!= null) {
                        for (int m=0; m<sharedAnnotations.length; m++){
                            if (sharefid2hash.get("" + sharedAnnotations[m].getFid() ) != null&&  sharedAnnotations[m] != null  ) {
                                avp = (HashMap )sharefid2hash.get("" + sharedAnnotations[m].getFid());
                                sharedAnnotations[m].setAvp(avp);
                            }
                        
                        }
                        }   
                    }
				   sharefidsInt = null; 
				}
					
			}    
    }    
    
   
	totalAnnotations = new AnnotationDetail [totalNumAnnotations]; 
    if (numLocalAnnos>0){
        for (i=0; i<numLocalAnnos; i++)
        totalAnnotations [i] = localAnnotations[i]; 
			localAnnotations = null; 
	}
	
	if (numShareAnnos>0){
        for (i=0; i<numShareAnnos; i++) 
        totalAnnotations [i+numLocalAnnos] = sharedAnnotations[i]; 
		
		sharedAnnotations = null; 
	}   
    
    
    
    if (totalAnnotations == null) {
        GenboreeMessage.setErrMsg(mys, " No annotations are found with the track information provided.");
        hasData = false;
    }
    else {  // has data
   	   if (needSort)  { 
		   totalAnnotations = AnnotationSorter.sortAllAnnotations(orderedSortNames, totalAnnotations);
   	
       }
      Runtime.getRuntime().gc();
	}

     // end of retrieve small annos 
	}
	}
    else if (isLargeSamples)  {  // case 2:  large samples
	if (restrictRegion) {
		 %>
    <%@ include file="include/largeAnnoRetrieveByRegion.incl" %>
    <%   
	}
	  else {    
 %>
    <%@ include file="include/largeAnnoRetrieve.incl" %>
    <%
			}

		}
		String prefix = "s";
		int localCount = 0;
		int shareCount = 0;
		fids = new String[totalNumAnnotations];
		if (isLargeSamples) {
			for (i = 0; i < fidAttributes.length; i++)
				fids[i] = fidAttributes[i][0];
		}
		else {

			for (i = 0; i < totalAnnotations.length; i++) {
				if (totalAnnotations[i].isShare()) {
					fids[i] = prefix + totalAnnotations[i].getFid();
					shareCount++;
				}
				else {
					fids[i] = blank + totalAnnotations[i].getFid();
					localCount++;
				}
			}
		}

		totalAnnotations = null;

		Runtime.getRuntime().gc();
		if (!hasData)
			GenboreeMessage.setErrMsg(mys, "There is no annotation data to download.");
		else {
			int count = 0;
			PrintWriter writer = null;
			if (!debugging) {
				String date = new Date().toString();
				response.addDateHeader("Expires", 0L);
				response.addHeader("Cache-Control", "no-cache, no-store");
				response.setContentType("text/fasta");
				response.setHeader("Content-Disposition", "inline; filename=\"annotation_file_" + date + ".txt\"");
				response.setHeader("Accept-Ranges", "bytes");
				response.addHeader("status", "200");
				writer = new PrintWriter(out);
			}

			String tab = "\t";
			if (orderedDisplayNames != null) {
				String name = "";
				sb = new StringBuffer();
				for (i = 0; i < orderedDisplayNames.length; i++) {
					name = orderedDisplayNames[i];
					if (name != null && name.equals("\"Edit\" Link"))
						continue;

					name = (String) LffConstants.display2downloadNames.get(name);
					if (name == null)
						name = orderedDisplayNames[i];
					
						if (!debugging) {
						sb.append(name);
						if (i < orderedDisplayNames.length - 1)
							sb.append(tab);
					}
				}
		           
				if (!debugging) {
					writer.println(sb.toString());
					sb = null;
				}
			}
			
		AnnotationDetail annotation = null;
			HashMap avpMap = null;
			HashMap lffMap = null;
			// writing to file 
			String displayName2 = null;
			int blocksize = 50;
			int numPages = fids.length / blocksize;
			int lastPagefids = fids.length % blocksize;
			if (lastPagefids > 0)
				numPages++;

			HashMap page2fids = new HashMap();
			int arrLength = blocksize;
			String[] temp = null;
			for (int pageIndex = 0; pageIndex < numPages; pageIndex++) {
				if (pageIndex == numPages - 1)
					arrLength = lastPagefids;
				temp = new String[arrLength];
				for (int j = 0; j < arrLength; j++) {
					int index = pageIndex * blocksize + j;
					temp[j] = fids[index];
				}
				page2fids.put("" + pageIndex, temp);
			}


			for (int pageIndex = 0; pageIndex < numPages; pageIndex++) {
				sharedPageFids = new ArrayList();
				localPageFids = new ArrayList();
				pagefids = (String[]) page2fids.get("" + pageIndex);
				fid2order = new HashMap();

				for (int j = 0; j < pagefids.length; j++) {
					if (pagefids[j].startsWith("s")) {
						sharedPageFids.add(pagefids[j]);
						fid2order.put(pagefids[j], new Integer(j));
					}
					else {
						localPageFids.add(blank + pagefids[j]);
						fid2order.put(pagefids[j], new Integer(j));
					}
				}

// populate local annotations     
				localPageAnnotations = null;
				gclass = null;
				if (!localPageFids.isEmpty()) {
					int[] localpagefids = new int[localPageFids.size()];
					for (int j = 0; j < localpagefids.length; j++)
						localpagefids[j] = Integer.parseInt((String) localPageFids.get(j));

					//if (isLargeSamples) 
					localPageAnnotations = AttributeRetriever.retrieveAnnotations(con, localpagefids, localftypeid2ftype, localid2Chromosome);


					if (displayText) {
						localpagefid2anno = new HashMap();
						if (localPageAnnotations != null) {
							for (int j = 0; j < localPageAnnotations.length; j++)
								localpagefid2anno.put(blank + localPageAnnotations[j].getFid(), localPageAnnotations[j]);
						}

						localPageAnnotations = AttributeRetriever.populateAnnotationText(localPageAnnotations, localpagefid2anno, con);
						localpagefid2anno.clear();
						localpagefid2anno = null;
					}
					if (localPageAnnotations != null) {
						for (int j = 0; j < localPageAnnotations.length; j++) {
							if (localftypeid2Gclass != null && localftypeid2Gclass.get(blank + localPageAnnotations[j].getFtypeId()) != null) {
								gclass = (String) localftypeid2Gclass.get(blank + localPageAnnotations[j].getFtypeId());
								localPageAnnotations[j].setGclassName(gclass);
							}
						}
					}


					if (displayAVP) {
						localfid2hash = AttributeRetriever.retrieveSmallNumAnnotationAVPs(con, localpagefids);
						if (localfid2hash != null && localPageAnnotations != null) {
							for (int m = 0; m < localPageAnnotations.length; m++) {
								if (localPageAnnotations[m] != null && localfid2hash.get(blank + localPageAnnotations[m].getFid()) != null) {
									avp = (HashMap) localfid2hash.get(blank + localPageAnnotations[m].getFid());
									localPageAnnotations[m].setAvp(avp);
									avp.clear();
								}
							}
						}
						localfid2hash.clear();
						localfid2hash = null;
					}

					if (localPageAnnotations != null)
						for (int j = 0; j < localPageAnnotations.length; j++)
							localPageAnnotations[j].setlff2value();
				}

				// populate share annotations 
				sharedPageAnnotations = null;
				shareFidList = new ArrayList();


				if (!sharedPageFids.isEmpty()) {
					sharepagefids = new int[sharedPageFids.size()];
					String id = null;
					for (int j = 0; j < sharepagefids.length; j++) {
						id = (String) sharedPageFids.get(j);
						id = id.substring(1);
						shareFidList.add(id);
						sharepagefids[j] = Integer.parseInt(id);
					}

					sharedPageAnnotations = AttributeRetriever.retrieveAnnotations(sharedConnection, sharepagefids, shareftypeid2ftype, shareid2Chromosome);

					if (sharedPageAnnotations != null) {

					}

					if (displayText) {
						sharepagefid2anno = new HashMap();
						for (int j = 0; j < sharepagefids.length; j++) {
							sharepagefid2anno.put(blank + sharedPageAnnotations[j].getFid(), sharedPageAnnotations[j]);
						}

						sharedPageAnnotations = AttributeRetriever.populateAnnotationText(sharedPageAnnotations, sharepagefid2anno, sharedConnection);
						sharepagefid2anno.clear();
						sharepagefid2anno = null;
					}
					gclass = null;
					if (sharedPageAnnotations != null) {
						for (int j = 0; j < sharedPageAnnotations.length; j++) {
							if (shareftypeid2Gclass != null && shareftypeid2Gclass.get("" + sharedPageAnnotations[j].getFtypeId()) != null) {
								gclass = (String) shareftypeid2Gclass.get("" + sharedPageAnnotations[j].getFtypeId());
								sharedPageAnnotations[j].setGclassName(gclass);
							}
						}
					}


					if (displayAVP) {
						sharefid2hash = AttributeRetriever.retrieveSmallNumAnnotationAVPs(sharedConnection, sharepagefids);

						if (sharefid2hash != null && sharedPageAnnotations != null) {
							for (int m = 0; m < sharedPageAnnotations.length; m++) {
								if (sharefid2hash.get("" + sharedPageAnnotations[m].getFid()) != null && sharedPageAnnotations[m] != null) {
									avp = (HashMap) sharefid2hash.get("" + sharedPageAnnotations[m].getFid());
									sharedPageAnnotations[m].setAvp(avp);
								}
							}
						}
						sharefid2hash.clear();
						sharefid2hash = null;
					}
					if (sharedPageAnnotations != null)
						for (int j = 0; j < sharedPageAnnotations.length; j++) {
							sharedPageAnnotations[j].setlff2value();
						}
				}

				// combine into new annotations 
				int index = 0;
				newAnnos = new org.genboree.editor.AnnotationDetail[pagefids.length];
				if (localPageAnnotations != null) {
					//	out.println("<br>page  "  + pageIndex  + " anno " + localPageAnnotations.length  );  

					for (int j = 0; j < localPageAnnotations.length; j++) {
						index = ((Integer) fid2order.get("" + localPageAnnotations[j].getFid())).intValue();
						newAnnos[index] = localPageAnnotations[j];
					}
				}


				localPageAnnotations = null;

				if (sharedPageAnnotations != null) {
					//out.println("<br>page  "  + pageIndex  + "  shared  "  + sharedPageAnnotations );  

					for (int j = 0; j < sharedPageAnnotations.length; j++) {
						index = ((Integer) fid2order.get("s" + sharedPageAnnotations[j].getFid())).intValue();
						newAnnos[index] = sharedPageAnnotations[j];
					}
				}
				sharedPageAnnotations = null;

				String value = "";
				for (int n = 0; n < newAnnos.length; n++) {
					sb = new StringBuffer("");
					flushCounter++;
					annotation = newAnnos[n];
					if (annotation == null) {
						//out.println("<br>page  "  + pageIndex  + " anno " + n +  " is null ");  
						continue;
					}
					annotation.setlff2value();
					if (displayAVP)
						avpMap = annotation.getAvp();
					if (annotation.getLff2value() != null)
						lffMap = (HashMap) annotation.getLff2value();
					for (int j = 0; j < orderedDisplayNames.length; j++) {
						displayName2 = orderedDisplayNames[j];
						if (displayName2 != null && displayName2.equals("\"Edit\" Link"))
							continue;
						if (lffMap != null && lffMap.get(displayName2) != null)
							value = (String) lffMap.get(displayName2);

						else if (displayAVP && avpMap != null && avpMap.get(displayName2) != null)
							value = (String) avpMap.get(displayName2);

						if (value == null) {  // value == null
							if (displayName2.equals(LffConstants.LFF_COLUMNS[10]) || displayName2.equals(LffConstants.LFF_COLUMNS[11]) || displayName2.equals(LffConstants.LFF_COLUMNS[12]) || displayName2.equals(LffConstants.LFF_COLUMNS[13]))
								value = ".";
						}
						sb.append(value);
						sb.append(tab);
						//sb.append(blank);
					}
					if (!debugging)
						writer.println(sb.toString());
					//writer.flush();  
					if (pageIndex == 0 && n == 0)
						out.println(sb.toString());

					sb = null;
					if (avpMap != null)
						avpMap.clear();
					if (lffMap != null)
						lffMap.clear();
					annotation = null;
					value = null;

				}

				if (!debugging && flushCounter > flushLimit) {
					writer.flush();
					try {
						Util.sleep(sleepTime);
					}
					catch (Exception ex) {
					}
					flushCounter = 0;
				}

				annotations = null;
				newAnnos = null;
				shareFidList = null;
				sharepagefids = null;

				localPageFids = null;
				;
				pagefids = null;
				if (fid2order != null)
					fid2order.clear();
				fid2order = null;


			}

			if (!debugging) {
				writer.flush();
				localftypeid2ftype = null;
				localfid2anno = null;
				shareftypeid2ftype = null;
				sharefid2anno = null;
				localftypeid2Gclass = null;
				shareftypeid2Gclass = null;
				localid2Chromosome = null;
				shareid2Chromosome = null;

				localPageFids = null;
				pagefids = null;
				fid2order = null;
				sharedPageFids = null;
				localfidAttributes = null;
				sharefidAttributes = null;

				fdataSortNames = null;
				nameid2values = null;
				valueid2values = null;
				attNameIds = null;

				fidAttributes = null;

				sortList = null;


				lffSortNames = null;
				ftypeid2ftype = null;

				lffNameArrayList = null;


				order2Att = null;
				ftypeid2Gclass = null;
				fids = null;
				lffAttributes = null;
				avpAttributes = null;
				allLffColumns = null;


				order2sortName = null;
				avpDisplayNameList = null;

				try {
					if (con != null && !con.isClosed())
						con.close();

					if (sharedConnection != null && !sharedConnection.isClosed())
						sharedConnection.close();
				}
				catch (Exception e) {
					e.printStackTrace();
				}
				finally {
			//out.clear();
					out = pageContext.pushBody();
					response.setContentType("text/html");
					
					Runtime.getRuntime().gc();
				}

			}
		;
		}

	%>
<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<HTML>       
<head>
<title><%=" My annotations "%></title>
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css" >
<link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">   
<script type="text/javascript" SRC="/javaScripts/editorCommon.js<%=jsVersion%>"></script>   
</head>
<BODY>  
<%@ include file="include/header.incl" %>
<%@ include file="include/navbar.incl" %>      
<%@ include file="include/message.incl" %> 
<form name="downloadForm" id="downloadForm" action="downloadAnnotations.jsp" method="post"> 
<table width="100%" border="0" cellpadding="2" cellspacing="2" width="500px">       
<tr align="center">  
<td colspan="2"> <BR><BR>
<input  type="submit" name="backBtn" id="backBtn" value="Back" class="btn" style="WIDTH:100">
</td></tr></table>
</form>
<%@ include file="include/footer.incl" %>
</BODY>
</HTML>
