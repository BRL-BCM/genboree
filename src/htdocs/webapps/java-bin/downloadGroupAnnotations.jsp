 <%@ page import="org.genboree.dbaccess.GenboreeGroup,
java.util.*,
java.io.*,         
org.genboree.message.GenboreeMessage,
org.genboree.editor.AnnotationDetail,
org.genboree.manager.tracks.Utility,
org.genboree.tabular.*,
org.genboree.editor.*,
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
	
	   AnnotationGroup localGroup = null;	
	boolean restrictRegion = false;
	int rid = -1;
	long chrStart = -1;
	long chrStop = -1;
	response.addDateHeader( "Expires", 0L );
	response.addHeader( "Cache-Control", "no-cache, no-store" );  
	GenboreeMessage.clearMessage(mys);  
	int i=0;  
	String dbName = null; 
	Connection con = null; 
	String dbNames[] = null; 
	String sharedbName = null; 
	int totalNumAnnotations = 0; 
	AnnotationDetail [] totalAnnotations = null; 
	Connection  sharedConnection = null; 
	boolean hasData = false;
	boolean displayAVP = false; 
	boolean displayText = false; 	
	boolean hasSharedTrack = false; 
	 HashMap shareftype2chromsomeMap = new HashMap () ; 
	int numLocalAnnos =0; 
	int numShareAnnos = 0; 
	
	// initialization     
	String[] fdataSortNames = null; 
	HashMap localftype2chromsomeMap  = null;  
	ArrayList sortList = null; 
	HashMap avp = null;
	HashMap localid2Chromosome = null; 
	HashMap shareid2Chromosome = null; 
	boolean needSort = false;  
	String [] lffSortNames = null;
	HashMap localftypeid2ftype = null; 
	
	HashMap shareftypeid2ftype = null; 
	int  flushCounter  = 0; 
	int flushLimit = 10000;  
	final  int sleepTime = 2000 ;
	
	boolean sortByAVP = false;
	int[] displayIndexes  = null; 
	ArrayList  lffNameArrayList = new ArrayList ();
	for ( i=0 ; i<LffConstants.LFF_COLUMNS.length; i++) 
	lffNameArrayList.add(LffConstants.LFF_COLUMNS[i]); 
	LffConstants.setHash();      
	AnnotationDetail[] annotations = null;
	
	int [] localftypeids = null; 
	int [] shareftypeids = null; 
	
	String [] avpNames =  null;               
	ArrayList avpDisplayNameList = new ArrayList (); 
	String totalCount =  (String)mys.getAttribute("totalCount") ;       
	ArrayList  lffSortNameList  = new ArrayList (); 
	HashMap order2Att = new HashMap ();  
	int mode = -1;
	Refseq rseq = null; 
	HashMap localftypeid2Gclass = null;  
	HashMap shareftypeid2Gclass = null;     
	ArrayList avpSortNameList  = new ArrayList (); 
	AnnotationDetail []  localGrpAnnotations = null; 
	AnnotationDetail []  sharedGrpAnnotations = null;       
	
	HashMap localGroupName2fids = new HashMap ();  
	HashMap sharedGroupName2fids = new HashMap ();  
	if (request.getParameter("btnBack") != null) {
	LffUtility.clearCache(mys);
	response.sendRedirect("displaySelection.jsp?mode=DownLoad");
	return; 
	}  
	
	//HashMap id2Chromosome = null;         
	HashMap ftypeid2ftype = null; 
	//HashMap fid2anno = new HashMap (); 
	
	LffConstants.setHash();      
	LffConstants.poulateLffMap();    
	HashMap lffAttMap = LffConstants.lffName2fdataName;
	
	String [] fids  = null; 
	ArrayList allLffColumns = new ArrayList (); 
  int genboreeUserId = Util.parseInt( myself.getUserId(), -1 );
 %>
	<%@ include file="include/chromosome.incl" %>
	 <%  
   boolean verbose = false;     
   String groupMode = request.getParameter("groupMode"); 
    if (groupMode != null && groupMode.equals("verbose")) 
    verbose = true; 
    
    if (groupMode == null) 
    groupMode = "terse";  
    String jsparams =  request.getParameter("jsparams");   
   String []  orderedDisplayNames =  null;   
    String orderedSortNames []= null;   
	if (jsparams == null  || jsparams.length()==0) {         
		System.err.println("debugging : js params is null in downloadGroupAnnotations.jsp line 105   "   );          
		GenboreeUtils.sendRedirect(request, response, "/java-bin/displaySelection.jsp");                                       //  return;
	}   

      if (jsparams != null  ) {    
   		 // System.err.println("debugging info : downloadGroupAnnotations.jsp :line 114: js params   "  + jsparams  );          
			JSONObject json = null; 
		          try { 
					 json = new JSONObject( jsparams ) ; 
				  }
				  catch (Exception e) {
					  e.printStackTrace();   
					  GenboreeUtils.sendRedirect(request, response, "/java-bin/displaySelection.jsp");   
     				}
			if (json != null) {
				
				//out.println("<br>jon string   " + json.toString()  );  
				orderedDisplayNames = LffUtility.parseJson(json, "rearrange_list_1")  ; 
                   if (orderedDisplayNames != null) 
                for (int j=0; j<orderedDisplayNames.length ; j++) {  
                orderedDisplayNames[j] = Util.urlDecode(orderedDisplayNames[j]);
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
		  // return ; 
		}
   %><%@ include file="include/saveLayout.incl" %>      
<% String [] selectedTrackNames = null;      
        
        selectedTrackNames = request.getParameterValues("dbTrackNames");
        if (selectedTrackNames != null) {  
            HashMap selectedTrackHash = new HashMap (); 
            for (  i=0; i<selectedTrackNames.length; i++) {
            selectedTrackHash.put(selectedTrackNames[i], "y"); 
            mys.setAttribute("selectedTrackHash", selectedTrackHash);
            }
		}    
    
        for ( i=0; i<org.genboree.tabular.LffConstants.LFF_COLUMNS.length; i++) 
        allLffColumns.add(org.genboree.tabular.LffConstants.LFF_COLUMNS[i]); 
        totalNumAnnotations  = 0; 
        dbName = null;
        con = null; 
      
		dbName = SessionManager.getSessionDatabaseName(mys); 
		if (dbName == null)
    {
		  GenboreeUtils.sendRedirect(request, response, "/java-bin/displaySelection.jsp");
		  return;
		}
		else
    {
      con = db.getConnection(dbName);
    }
   
    if (mys.getAttribute("dbNames") != null) 
        dbNames = (String [])mys.getAttribute("dbNames"); 
     if (dbNames != null   && sharedbName == null) {    
        for (i=0; i<dbNames.length; i++) {
        if (!dbNames[i].equals(dbName)) { 
        sharedbName = dbNames [i];  
        break;
        }}}
             
        if (sharedbName != null) 
        sharedConnection = db.getConnection(sharedbName); 
        
        if (mys.getAttribute("localftypeids") != null)  { 
        localftypeids =(int []) mys.getAttribute("localftypeids");
        }
        if (mys.getAttribute("shareftypeids") != null) 
        shareftypeids =(int []) mys.getAttribute("shareftypeids");        
          
        // first, display all names for selection 
        if (localftypeids != null) 
           numLocalAnnos  = Utility.countAnnotations(con, localftypeids);   
        
        int []shareFids =  null; 
        if (sharedbName != null && shareftypeids != null)               
            numShareAnnos  = Utility.countAnnotations(sharedConnection, shareftypeids);  
	
	if (localftypeids != null) {
		if (!restrictRegion)  {
		numLocalAnnos = Utility.countAnnotations(con, localftypeids);
		}
		else  {
		   numLocalAnnos = Utility.countAnnotations(con, localftypeids, rid, chrStart, chrStop);
		    
		}
	}
	if (sharedbName != null && shareftypeids != null) {
		if (!restrictRegion)   {
					
			numShareAnnos = Utility.countAnnotations(sharedConnection, shareftypeids);
		}
		      else {
		  	numShareAnnos = Utility.countAnnotations(sharedConnection, shareftypeids, rid, chrStart, chrStop);
	}
	}
	
  		totalNumAnnotations = numLocalAnnos + numShareAnnos;
        String [] avpDisplayNames = null;             
        if (orderedDisplayNames == null) {
        GenboreeMessage.setErrMsg(mys, "Please select some attributes for sample display. ");                            
        }
   
      
if (con != null && !con.isClosed()) 
localftype2chromsomeMap =  GroupHelper.mapftypeid2chromsome (con, out);    

if (sharedConnection != null && !sharedConnection.isClosed()) 
      shareftype2chromsomeMap = GroupHelper.mapftypeid2chromsome (sharedConnection, out);  
 	  if (orderedDisplayNames != null && orderedDisplayNames.length >0){          
		for (int k=0; k<orderedDisplayNames.length; k++) {
			if (!lffNameArrayList.contains(orderedDisplayNames[k]))              
			   avpDisplayNameList.add(orderedDisplayNames[k]);  
			
		if (orderedDisplayNames[k].equals(LffConstants.LFF_COLUMNS[13]) ||orderedDisplayNames[k].equals(LffConstants.LFF_COLUMNS[12])) 
			displayText = true; 
		}
      } 
       if (!avpDisplayNameList.isEmpty()) {
        avpDisplayNames =(String []) avpDisplayNameList.toArray(new String [avpDisplayNameList.size()]);   
        mys.setAttribute("avpDisplayNames", avpDisplayNames);  
        displayAVP = true; 
     }     
     
	if (orderedSortNames != null && orderedSortNames.length >0) {  
        String temp = orderedSortNames[0]; 
        orderedSortNames = new String [] {temp}; 
        
        sortList = new ArrayList (); 
        for (i=0; i<orderedSortNames.length; i++) {
			sortList.add(orderedSortNames[i]); 
			if (lffAttMap.get(orderedSortNames[i]) == null) { 
				sortByAVP = true;                   
				avpSortNameList.add(orderedSortNames[i]);          
			}
			else 
			lffSortNameList.add(orderedSortNames[i]);  
        }  
        
        if (!lffSortNameList.isEmpty()) 
        lffSortNames =(String []) lffSortNameList.toArray(new String [lffSortNameList.size()] ); 
    }  
         if (con != null) {   
            if (localftypeids != null && localftypeids.length > 0) 
            localftypeid2Gclass = Utility.retrieveFtype2Gclass (con, localftypeids); 
            localftypeid2ftype =  Utility.retrieveFtypeid2ftype(con, dbName, genboreeUserId );
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

        if (orderedSortNames != null) {
            fdataSortNames = LffUtility.covertNames(orderedSortNames);
            if(fdataSortNames == null || fdataSortNames.length ==0)
            fdataSortNames = null; 
            needSort = true; 
        }   
        if (totalNumAnnotations >0 )  { 
            hasData = true;        
        }
     String sortName = null; 
    if (orderedSortNames != null) 
    sortName = orderedSortNames[0];
    if (localftypeids  != null) {
    //   groupName2Fids= retrieveGrpName2fids(con, localftypeids, groupName2Fids, true, out);        
	if (!restrictRegion) 
		localGroup = GroupHelper.retrieveLargeAnnoGroup (localftypeids, localftype2chromsomeMap, con, out) ;
	else 
		localGroup = GroupHelper.retrieveGroupAnnotationsByChromosomeRegion(localftypeids,rid,chrStart, chrStop,localftypeid2Gclass, localftypeid2ftype, localid2Chromosome, localftype2chromsomeMap, con, out);
				
	localGrpAnnotations = localGroup.getAnnos(); 
	localGroupName2fids = localGroup.getGroupName2Fids(); 
	localftype2chromsomeMap.clear();		
	 } 
 	if (shareftypeids != null) {
        //  groupName2Fids = retrieveGrpName2fids(sharedConnection, shareftypeids,  groupName2Fids,  false, out);                                             
        AnnotationGroup sharedGroup =  null ;
		if (!restrictRegion) 
		sharedGroup=GroupHelper.retrieveLargeAnnoGroup (shareftypeids, shareftype2chromsomeMap, sharedConnection, out  ) ;
		else 
		sharedGroup=GroupHelper.retrieveGroupAnnotationsByChromosomeRegion(shareftypeids, rid, chrStart, chrStop,shareftypeid2Gclass, shareftypeid2ftype, shareid2Chromosome, shareftype2chromsomeMap, sharedConnection, out);
	 	
		sharedGrpAnnotations = sharedGroup.getAnnos(); 
        sharedGroupName2fids = sharedGroup.getGroupName2Fids();   
        
        if (sharedGrpAnnotations != null) {
        for (i=0; i<sharedGrpAnnotations.length; i++) {
        sharedGrpAnnotations[i].setShare(true);                       
         }
        }
		 
		shareftype2chromsomeMap.clear(); 
	 }                                                
   		totalAnnotations = GroupHelper.mergeAnnotations (localGrpAnnotations, sharedGrpAnnotations);                             
        if (totalAnnotations != null) 
        totalNumAnnotations = totalAnnotations.length; 
      
        if (orderedSortNames != null){
          //  HashMap localvalue2fids = new HashMap (); 
           // HashMap sharevalue2fids = new HashMap (); 
          
            if (sortByAVP) {  
                   Date d1 = new Date();  
                 HashMap localvalue2anno = new HashMap (); 
    if (localftypeids != null  && localGrpAnnotations != null && localGrpAnnotations.length > 0) {    
                                                                  
                    int localsortNameId = AttributeRetriever.retrieveNameId(con,sortName);
                                                                            
                      String  values = null;  
                   String[] localGenevalueids  =  null; 
                    fids = null; 
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
                        fids = null; 
                        ArrayList list = null;
                         int count = 0;          
                        for ( i=0; i< sharedGrpAnnotations.length; i++) {
                        list  = (ArrayList)sharedGroupName2fids.get(sharedGrpAnnotations[i].getGname() + "_" + sharedGrpAnnotations[i].getFtypeId() + "_" +  sharedGrpAnnotations[i].getRid()); 
                        fids = (String [])list.toArray(new String [list.size()]); 
                        
                        values = null;  
                        if (fids != null && fids.length > 0)      
                        shareGenevalueids  =  GroupHelper.retrieveSingleAttributeValueIds  (sharedConnection,  fids, sharesortNameId, out);                                                    
                        if (shareGenevalueids != null && shareGenevalueids.length >0) 
                        values  =  GroupHelper.retrieveGeneAttValue (sharedConnection, shareGenevalueids , verbose, out ) ;
                        
                        if (values != null)
                        values = values.trim();
                        if (values == null || values == "")
                        values= "zzzz"; 
                        
                        HashMap m = new HashMap (); 
                        m.put (sortName, values); 
                        sharedGrpAnnotations [i].setAvp(m);  
                        
                        ArrayList annolist  = null; 
                        if (sharevalue2anno.get(values) == null) 
                        annolist = new ArrayList (); 
                        else 
                        annolist = (ArrayList)sharevalue2anno.get(values); 
                        
                        annolist.add(sharedGrpAnnotations[i] );
                        
                        sharevalue2anno.put(values, annolist); 
                        //   localAnnotations[i].setAvp(new HashMap ().put(sortName, values));
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
                            for (int j=0; j<sharelist.size(); j++) {                           
                            temp.add((AnnotationDetail)sharelist.get(j));
                                 }
                        }
                    }
                }
                    if (!temp.isEmpty()) {
                    totalAnnotations = (AnnotationDetail [] )temp.toArray(new AnnotationDetail [temp.size()]); 
                    totalNumAnnotations = totalAnnotations.length; 
                   temp.clear();; 
                    }
				localvalue2anno.clear();
				sharevalue2anno.clear();
				
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
                for (i=0; i<sharedGrpAnnotations .length; i++) {
                if (localftypeid2ftype.get("" + sharedGrpAnnotations [i].getFtypeId()) != null ) {
                String [] ftypeString = null; 
                
                ftypeString =(String [] )localftypeid2ftype.get("" + sharedGrpAnnotations [i].getFtypeId());                        
                String fmethod = null; 
                String fsource = null; 
                if (ftypeString != null && ftypeString != null){
                fmethod = ftypeString[0];
                fsource = ftypeString[1];
                sharedGrpAnnotations [i].setFmethod(fmethod); 
                sharedGrpAnnotations [i].setFsource(fsource);
                
                sharedGrpAnnotations [i].setTrackName(fmethod + ":" + fsource);                
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
                
                 if (sharedGrpAnnotations != null) {
                    for (i=0; i<sharedGrpAnnotations.length; i++) {
                        String className = ""; 
                        if (shareftypeid2Gclass.get("" + sharedGrpAnnotations[i].getFtypeId()) != null) {
                        className = (String )shareftypeid2Gclass.get("" + sharedGrpAnnotations[i].getFtypeId());
                        sharedGrpAnnotations[i].setGclassName(className);
                        } 
                    }  
                 } 
              }
	
                    // sort by Text 
            else if (sortName.equals(LffConstants.LFF_COLUMNS[12])  ||  sortName.equals(LffConstants.LFF_COLUMNS[13])){
			if (con != null && localGrpAnnotations != null) 
			localGrpAnnotations = GroupHelper.populateGroupText (verbose, con, localGrpAnnotations, localGroupName2fids, true, out ) ;
			if (sharedConnection != null && sharedGrpAnnotations != null) 
			sharedGrpAnnotations = GroupHelper.populateGroupText (verbose, sharedConnection, sharedGrpAnnotations, sharedGroupName2fids, false, out) ;        
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
                sharedGrpAnnotations =GroupHelper. populateTargetStop (sharedConnection, sharedGrpAnnotations,  out ) ;  
            
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
            totalNumAnnotations = totalAnnotations.length; 
            
            //  AnnotationDetail[] sortedTotalAnnotations =  //sortLargeAnos(totalAnnotations, sortName); 
            AnnotationDetail[] sortedTotalAnnotations =null; 
            if (orderedSortNames != null && totalAnnotations != null) {
            sortedTotalAnnotations =AnnotationSorter.sortAllAnnotations(orderedSortNames, totalAnnotations);  
            }
            
            if (sortedTotalAnnotations != null) {
            totalAnnotations=   sortedTotalAnnotations ; 
            }
         }  
          
        }
        if (totalNumAnnotations ==0){
            GenboreeMessage.setErrMsg(mys, " No annotations are found with the track information provided.");
             GenboreeUtils.sendRedirect(request, response, "/java-bin/displaySelection.jsp?fromBrowser=View");
         hasData = false;
        return; 
          
        } 
        else  {
            hasData = true; 
            if (totalAnnotations != null)                
          totalNumAnnotations = totalAnnotations.length;  
          
         }
       
   
if (!hasData) 
    GenboreeMessage.setErrMsg(mys, "There is no annotation data to download." );      
else  {  
	
	   int blocksize = 50;  
       // int blocksize = LffConstants.BLOCK_SIZE;    
            numPages  = totalAnnotations.length/blocksize;
        int lastPagefids = totalAnnotations.length%blocksize;
        if ( lastPagefids>0)          
            numPages ++;  
	HashMap page2annos = new HashMap ();             
		   int arrLength = blocksize;   
		   for ( int pageIndex =0; pageIndex<numPages; pageIndex++) {     
			   if (pageIndex== numPages-1 ) 
			   arrLength  = lastPagefids;  
            
			   AnnotationDetail [] pageAnnotations = new AnnotationDetail [arrLength ] ; 
			   for (int j=0; j< arrLength; j++) {
			   int index = pageIndex*blocksize  + j ; 
			   pageAnnotations[j]  =  totalAnnotations[index];
			   }
			   page2annos.put("" + pageIndex, pageAnnotations);    
		   }    
	//System.err.println("<br>before  starting  of download, number of memory is: " + Runtime.getRuntime().freeMemory() );  
				
	AnnotationDetail annotation   =  null;         
		   HashMap lffMap = null;          
		   // writing to file 
		   String displayName2 = null;  
		   String value =  "";
	
	int count = 0; 
    PrintWriter writer = null;    
       String tab = "\t"; 
	 String dot = "."; 
	String blank = ""; 
	String comma = ","; 
	String date = new Date().toString();
//	boolean debugging =  true;
		boolean debugging =  false; 
	if (!debugging) {
	response.addDateHeader( "Expires", 0L );
	response.addHeader( "Cache-Control", "no-cache, no-store" );
	response.setContentType( "text/fasta" );
	response.setHeader( "Content-Disposition", "inline; filename=\"annotation_file_" + date + ".txt\"" );
	response.setHeader("Accept-Ranges", "bytes");
	response.addHeader("status", "200");
	writer = new PrintWriter(out);  
	}
        
        if (orderedDisplayNames != null) { 
                String name = "";   
			    StringBuffer sbhead = new StringBuffer (); 
				for ( i=0; i<orderedDisplayNames.length-1; i++){       
					name =  orderedDisplayNames[i];
					if (name!= null && name.equals("\"Edit\" Link")) 
					continue; 
					
					name = (String) LffConstants.display2downloadNames.get(name); 
					if (name == null) 
					name = orderedDisplayNames[i];
				    sbhead.append(name );
					sbhead.append(tab);  
					    
                }
                
                name =  orderedDisplayNames[orderedDisplayNames.length-1];  
                name = (String ) LffConstants.display2downloadNames.get(name);
                if (name == null) 
                name = orderedDisplayNames[i];
                sbhead.append(name);
			
			
			  if (!debugging) 
				writer.println(sbhead.toString());              
              //  writer.flush();                        
        }                                
         
	
	
	for ( int pageIndex =0; pageIndex<numPages; pageIndex++) { 
	
		 annotations = ( AnnotationDetail [])page2annos.get("" + pageIndex);
        {   
                if (con != null && localGrpAnnotations != null && localGrpAnnotations.length > 0) {            
                annotations = GroupHelper.populateAnnotations (annotations, true, con, out); 
                // annotations = GroupHelper.populateAnnotations (annotations, true, con, out); 
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
				String chr = blank; 
                if (localid2Chromosome.get("" + annotations[i].getRid())  != null){ 
					chr = (String)localid2Chromosome.get("" + annotations[i].getRid());
					annotations[i].setChromosome(chr);
                }
                
                String className = blank; 
                if (localftypeid2Gclass.get(blank + annotations[i].getFtypeId()) != null) {
                className = (String )localftypeid2Gclass.get("" + annotations[i].getFtypeId());
                annotations[i].setGclassName(className);
                } 
                annotations[i].setlff2value();
                }
              }
				localid2Chromosome.clear();	
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
		}   
       shareid2Chromosome.clear();      
    HashMap localname2fids = GroupHelper.getGrpName2fids(con, annotations,  true,  out); 
   if (localname2fids != null && !localname2fids.isEmpty()  && displayAVP ) {
    annotations = GroupHelper.populateAVP (verbose, con, annotations, localname2fids, true,  out); 
      if (displayText) 
	    annotations = GroupHelper.populateGroupText (verbose, con, annotations, localname2fids,  true, out);            
      localname2fids.clear();
   }
      
	HashMap sharegrpName2fids = new HashMap (); 
	if (sharedConnection != null && !sharedConnection.isClosed()) {
		sharegrpName2fids = GroupHelper.getGrpName2fids(sharedConnection, annotations, false, out);  
		if (sharegrpName2fids != null && !sharegrpName2fids.isEmpty() && displayAVP) {
		annotations = GroupHelper.populateAVP (verbose,sharedConnection, annotations,sharegrpName2fids,false,out);              
        if (displayText) 
		annotations = GroupHelper.populateGroupText(verbose, sharedConnection,annotations,sharegrpName2fids,true,out); 
			sharedGroupName2fids.clear();
		}
	}     
		
		if (annotations != null) 
        for (i=0; i<annotations.length; i++)
        annotations [i].setlff2value();
    
        HashMap avpMap = null; 
        // print to file     
        for (int n=0; n<annotations.length; n++) {        
            flushCounter++;        
            annotation = annotations[n];
              annotation.setlff2value();
             avpMap = annotation.getAvp();
            if (annotation.getLff2value() != null)
            lffMap = (HashMap) annotation.getLff2value();  
			
			StringBuffer sb = new StringBuffer(); 
			for (int j=0; j< orderedDisplayNames.length; j++) {
                displayName2 = orderedDisplayNames[j];  
                if ( displayName2 != null &&  displayName2 .equals("\"Edit\" Link")) 
                continue; 
                value =  blank; 
                if (lffMap != null && lffMap.get(displayName2) != null)
                value = (String )lffMap.get(displayName2);  
                
                else if (displayAVP && avpMap != null && avpMap.get(displayName2)!= null)   {      
                       value = (String)((ArrayList)avpMap.get(displayName2)).get(0);                  
                }
                 
                if (value != null) 
                    value = value.trim() ; 
                else {  // value == null
                    if( displayName2.equals(LffConstants.LFF_COLUMNS[10])||displayName2.equals(LffConstants.LFF_COLUMNS[11]))
					value = dot;
					else if (displayName2.equals(LffConstants.LFF_COLUMNS[12])||displayName2.equals(LffConstants.LFF_COLUMNS[13]))
                    value = dot; 
                }
                                   
                if (value != null && verbose && value.indexOf(",") >0)   {                
                    String []values = value.split(comma);
                    if (values != null  && values.length >1){
                     HashMap   map = new HashMap (); 
                           
                            for ( n =0; n<values.length; n++)
                                map.put(values[n], "1"); 
                            values = (String[])map.keySet().toArray(new String [map.size()] );
                           // value = ""; 
                        map.clear();
						//map = null; 
                        
							for ( n =0; n<values.length; n++){
							   sb.append(values[n]); 
								if (n < values.length -1) 
								sb.append(comma); 
							}
					
					}                 
                }
				else
				   sb.append(value); 
				  
			    sb.append(tab);
            }   
               if (!debugging) 
                writer.println(sb.toString());
			sb = null; 
			 //   writer.flush();  
			if (avpMap != null) 
			avpMap.clear();
			if (lffMap != null) 
			lffMap.clear();
			annotation = null; 
		} 
         
        if(flushCounter > flushLimit){
         if (!debugging) 
            writer.flush();
          try { Util.sleep(sleepTime) ; }
           catch(Exception ex) { 
		ex.printStackTrace(			)    ; 
		}
			// Runtime.getRuntime().gc();

			
			flushCounter = 0;
        } 
		
		
		annotations = null;
		sharegrpName2fids = null;
		localname2fids= null; 
	}
	     localGroup = null;
		totalAnnotations = null; 
         localGrpAnnotations = null; 
	if(localGroupName2fids != null) 
	localGroupName2fids.clear(); 
	
	sharedGrpAnnotations = null;  
	if (sharedGroupName2fids != null) 
	sharedGroupName2fids.clear();   
	if (page2Annotations!= null) 
	page2Annotations.clear();
	page2Annotations= null; 
	if (!debugging ) {
		writer.flush();
	 	writer = null; 
	}
	
	try {
	if (	con != null && !con.isClosed())
	con.close();
	
	if (sharedConnection != null && !sharedConnection.isClosed()) 
	sharedConnection.close(); 	
	} 
	catch (Exception e)  {
	e.printStackTrace(); 
	}
	finally {
		 //out.clear();
         out = pageContext.pushBody(); 
		 response.setContentType( "text/html" ); 
         Runtime.getRuntime().gc();
	}
	
	
	}   
 	%><%@ page contentType="text/html;charset=UTF-8" language="java" %>
    <HTML>       
    <head>
    <title> Download Group Annotations </title>
    <meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
    <link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css" >
    <link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">   
     </head>
    <BODY>  
    <%@ include file="include/header.incl" %>
    <%@ include file="include/navbar.incl" %>      
    <%@ include file="include/message.incl" %> 
     <form name="downloadForm" id="downloadForm" action="downloadGroupAnnotations.jsp" method="post"> 
    <table width="100%" border="0" cellpadding="2" cellspacing="2" width="500px">       
    <tr align="center">  
    <td colspan="2"> <BR><BR>
    <input  type="submit" name="backBtn" id="backBtn" value="Back" class="btn" style="WIDTH:100">
    </td></tr></table>
    </form>
    <%@ include file="include/footer.incl" %>
    </BODY>
    </HTML>
 