<%@ page import="javax.servlet.http.*, java.util.*, java.io.*, java.sql.*,
org.genboree.browser.*,
org.genboree.dbaccess.*, org.genboree.dbaccess.util.*, org.genboree.gdasaccess.*,
org.genboree.util.*, org.genboree.upload.*,
org.genboree.message.GenboreeMessage, java.sql.Date" %>
<%@ page import="org.genboree.util.GBrowserUtils, org.genboree.rest.util.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%
    // chromThumbnail options:
    int CHROM_THUMB_WIDTH = 300 ;
    int CHROM_THUMB_HEIGHT = 15 ;
    int[] CHROM_THUMB_MARGINS = {2, 2, 2, 2} ;

    GenboreeMessage.clearMessage(mys);
    Vector vTimes = null;
    Vector vTimeLabs = null;
    ReadFile processedMapFile = null;
    ReadFile fileWithLinkNames = null;
    boolean loadDefaultDisplay = false;
    boolean developmentServer = false;
    String serverName = null;
    String viewDbAccess = null;
    String rootUploadId = "#";
    String nav = null;
    String editGroupId = null;
    String  editRefSeqId = null;
    String editEP = null;
    String editStart = null;
    String editStop = null;
    String searchstr = null;
    String sRefSeqId = null;
    String fwdTgt = null;
    Refseq crs = null;
    String acs = null;
    Vector vDebug = null;
    int i = 0;
    boolean processSearch = false;
    String btnSearch = null;
    boolean force_view = false;
    Refseq[] rseqs = null;
    Vector v = null;
    boolean grp_hard = false;
    boolean need_picture = false;
    boolean hasTabularView = false;
    String viewGroupId = null;
    String viewRefSeqId = null;
    String viewEP = null;
    String viewStart = null;
    String viewStop = null;
    String[] rsids = null;
    String sessionGroupId = null;
    String oldRefSeqId = null;
    String oldEP = null;
    String oldStart = null;
    String oldStop = null;
    String baseJsp  = null;
    Refseq vRseq = null;
    String fwdRefSeqId = null;
    String fwdEP = null;
    String fwdStart = null;
    String fwdStop = null;
    String fwdPictWidth = null;
    String tgtUrl = null;
    String msgUrl = null;
    DbFref[] vFrefs = null;
    DbFref vFref = null;
    String ctr_gclass = null;
    String ctr_gname = null;
    String ctr_track = null;
    long new_from = -1L;
    long new_to = -1L;
    long[] lims = null;
    long new_range = 0;
    long new_center = 0;
    long vMinFrom = 1L;
    long vMaxTo = 0;
    long vFrom = 0;
    long vTo = 0;
    long vRange = 0;
    long vCtr = 0;
    boolean has_seq = false;
    boolean is_db_owner = false;
    boolean hasLastView = (mys.getAttribute("lastBrowserView") == null);
    String pictWidth = null;
    String sDisplayEmptyTracks = null;
    int iDisplayEmptyTracks = 0;
    String displayEmptyTracks = null;
    String sDrawInMargin = null;
    int iDrawInMargin = 0;
    String drawInMargin = null;
    String displayTrackDesc = null;
    String sDisplayTrackDesc = null;
    int iDisplayTrackDesc = 1;
    DbFtype[] trackArray = null;
    String[] trackNames = null;
    Hashtable htTrkGr = null;
    Vector vft = null;
    DbFtype[] trks = null;
    String trk1 = null;
    String trk2 = null;
    String trkKey = null;
    DbFtype trk = null;
    String trackName = null;
    Hashtable oldTrackView = null;
    Hashtable trackView = null;
    Vector vTrkDispl = null;
    DbFtype ft = null;
    String tn = null;
    DbFtype[] trkDisplArray = null;
    String tv = null;
    String xtrack = null;
    File xtrackFile = null;
    FileReader fIn = null;
    BufferedReader xIn = null;
    String sss = null;
    String[] ss = null;
    boolean view_enabled = true;
    GenboreeGroup grp = null;
    int tempStyleValue = 0;
    String displ = null;
    GenboreeGroup nGrp = null;
    int nAcs = 0;
    int minTimeCache = 1 ; //600;  If the image generation process takes more seconds, than this value, the image is cached
    String refseqVersion = null;
    boolean i_am_owner = false;
    boolean is_ro_group = false;
    String myGrpAccess = null;
    String absStart = null;
    long minFrom = 0L;
    long maxTo = 0L;
    long cFrom = 0L;
    long cTo = 0L;
    boolean refSeqBelongsToGroup = false;
    StringBuffer errorStringCProgram = new StringBuffer();
    errorStringCProgram.append("");
    String[] classes = null;
    HashMap<String, ArrayList<DbFtype>> dbFtypesByClass = null ;
    String trackVisibilityMenus = null;
    Connection tConn = null ;
    int totalFrefCount = -1 ;
    BufferedReader err = null;
    String typeOfImage = ".png";
    serverName = Constants.REDIRECTTO;
    String target = (String)mys.getAttribute("target");
     HashMap trackName2Ftype = new HashMap ();
    developmentServer = true;
    mys.removeAttribute( "target" );
    mys.setAttribute( "popup_links", "1" );

    MapLinkFile mapLinkFile = null ;

    // Initialize timers
    vTimes = new Vector();
    vTimeLabs = new Vector();
    vTimeLabs.addElement( "start" );
    vTimes.addElement( new java.util.Date() );

    if(developmentServer)
    {
      minTimeCache = 1; //Exclusive for the development server bypass the minTimeCache
    }
    response.addDateHeader( "Expires", 0L );

    if( request.getParameter("loadDefaultDisplay")!=null )
        loadDefaultDisplay = true;
    else
        loadDefaultDisplay = false;

    // is_navbar flag
    boolean is_navbar = false ;
    is_navbar = request.getParameter("isNavBar") != null ;

    // -- process search request --
    searchstr = request.getParameter("searchstr");
    if (searchstr != null)
      searchstr = searchstr.trim();

    sRefSeqId = request.getParameter("refSeqId");

    btnSearch = request.getParameter("btnSearch");
    String     rtnSearch = request.getParameter("rtnSearch");
    processSearch = ( (btnSearch !=null || (rtnSearch != null && rtnSearch.compareTo("1")==0)) && searchstr!=null && (searchstr.compareTo("") != 0) && sRefSeqId!=null );
    if (searchstr != null && searchstr.compareTo ("") ==0 && btnSearch != null)
         GenboreeMessage.setErrMsg(mys, "Search string is empty.");
    force_view = request.getParameter("btnView") != null;

    if( processSearch )
    {
      fwdTgt = "/java-bin/genboreeSearchWrapper.jsp";
      fwdTgt = fwdTgt + "?refSeqID=" + sRefSeqId + "&query=" + Util.urlEncode(searchstr) ;

      crs = new Refseq();
      crs.setRefSeqId( sRefSeqId );
      crs.fetch( db );
      if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
      acs = Refseq.fetchUserAccess( db, crs.getDatabaseName(), "0" );

      if( !Util.isEmpty(acs) )
      {
        fwdTgt = fwdTgt + "&ip=y";
      }
      GenboreeUtils.sendRedirect(request,response,  fwdTgt );
      return;
    }

    vDebug = new Vector();

    vTimeLabs.addElement( "DONE - Initialization and Setting Attributes" );
    vTimes.addElement( new java.util.Date() );

    if(grps == null || grps.length == 0)
    {
      grps = GenboreeGroup.recreateteGroupList(db, myself.getUserId());
      if(grps == null )
      {
        GenboreeUtils.sendRedirect(request,response,  "/java-bin/login.jsp" );
        return ;
      }
    }

    vTimeLabs.addElement( "DONE - Fetching Groups" );
    vTimes.addElement( new java.util.Date() );

    if( rseqs==null || rseqs.length==0) {
      rseqs = Refseq.recreateteRefseqListFromGroup(db, grps);
      if(rseqs == null )
      {
        System.err.println("rseqs list is null. Redirecting to login.") ;
        GenboreeUtils.sendRedirect(request,response,  "/java-bin/login.jsp" );
        return ;
      }
    }

    v = new Vector();
    for( i=0; i<grps.length; i++ )
    {
      rsids = grps[i].getRefseqs();
      if( rsids!=null && rsids.length>0 )
        v.addElement( grps[i] );
    }

    grp_hard = !is_public && is_navbar;
    need_picture = true;

    nav = request.getParameter( "nav" );
    // Get groupId
    editGroupId = request.getParameter( "groupId" ) ;
    System.err.println("DEBUG: groupId: " + editGroupId) ;
    if(editGroupId == null || editGroupId.length() == 0) // then maybe coming in with a groupName and dbName
    {
      String groupName = request.getParameter( "groupName" ) ;
      System.err.println("DEBUG: groupName: " + groupName) ;
      int groupIdInt = GenboreegroupTable.getGroupIdByName(groupName, db) ;
      System.err.println("DEBUG: groupIdInt: " + groupIdInt) ;
      if(groupIdInt > 0) // Only set editGroupId if got actual groupId int back
      {
        editGroupId = "" + groupIdInt ;
      }
      // else leave editGroupId as-is for later code to deal with
    }
    // Get refSeqId for database
    editRefSeqId = request.getParameter( "refSeqId" ) ;
    System.err.println("DEBUG: refSeqId: " + editRefSeqId) ;
    if(editGroupId != null && (editRefSeqId == null || editRefSeqId.length() == 0)) // then maybe coming in with a groupName and dbName
    {
      String dbName = request.getParameter( "dbName" ) ;
      System.err.println("DEBUG: dbName: " + dbName) ;
      int refSeqIdInt = RefSeqTable.getRefSeqIdByRefSeqName(editGroupId, dbName, db) ;
      System.err.println("DEBUG: refSeqIdInt: " + refSeqIdInt) ;
      if(refSeqIdInt > 0) // Only set editGroupId if got actual groupId int back
      {
        editRefSeqId = "" + refSeqIdInt ;
      }
      // else leave editRefSeqId as-is for later code to deal with
    }

    int errorCode  = 0;
    if( editRefSeqId  != null)
    {
      errorCode = SessionManager.setSessionDatabaseId(mys,  editRefSeqId) ;
    }

    if(errorCode >0)
    {
      errorCode = SessionManager.setSessionDatabaseIdHard(mys, editRefSeqId) ;
    }
    editEP = request.getParameter( "entryPointId" ) ;
    editStart = Util.remCommas(request.getParameter("from")) ;
    if(editStart != null)
    {
      editStart = editStart.replaceAll("\\s+", "") ;
    }
    editStop = Util.remCommas( request.getParameter("to") );
    if(editStop != null)
    {
      editStop = editStop.replaceAll("\\s+", "");
    }
    if(editRefSeqId == null || editEP == null)
    {
      GenboreeUtils.sendRedirect(request,response,  "/java-bin/index.jsp" );
      return;
    }

    if(grps.length < 1)
    {
      GenboreeUtils.sendRedirect(request,response,  "/java-bin/index.jsp" );
      return;
    }

    // Have access?
    refSeqBelongsToGroup = Refseq.isPublished(db, editRefSeqId) ;
    if(!refSeqBelongsToGroup)
    {
      for (i = 0; i < grps.length; i++)
      {
        refSeqBelongsToGroup = grps[i].belongsTo(editRefSeqId);
        if(refSeqBelongsToGroup)
        {
          break;
        }
      }
    }
    else
    {
      public_view = true ;
    }

    if(!refSeqBelongsToGroup) // Then access denied
    {
      String tempServerName =  request.getHeader("host");
      String tempContext = request.getContextPath();
      String tempServletPath = request.getServletPath();

      String qs = request.getQueryString();
      if( qs == null || qs.length() < 1)
      {
        qs = "";
      }
      else
      {
        qs = "?"+qs;
      }
      String tempTarget = "http://" + tempServerName + tempContext + tempServletPath + qs  ;

      mys.setAttribute( "target", tempTarget ) ;


      String groupIDInURL = GenboreeUtils.fetchGroupIdFromRefSeqId(editRefSeqId);
      GenboreeGroup groupInURL = new GenboreeGroup();
      groupInURL.setGroupId( groupIDInURL );
      groupInURL.fetch( db );
      groupInURL.fetchRefseqs( db );
      String groupNameInURL = groupInURL.getGroupName();
      String myUrl = null;

      if(userInfo[0].equals("Public"))
      {
        myUrl = "/java-bin/login.jsp" ;
      }
      else if(groupNameInURL != null)
      {
        myUrl = "/java-bin/notifyAdmin.jsp?";
        myUrl += "groupAllowed=" + groupNameInURL + "&msgRefSeqId=" + editRefSeqId;
      }
      else
      {
        mys.setAttribute( "warnMsg", "<strong>Sorry, We have detected that this page has "+
                          "serious problems please contact " + GenboreeConfig.getConfigParam("gbAdminEmail") + " immediately to fix your account</strong>" );
        GenboreeUtils.sendRedirect(request, response,  "/java-bin/warn.jsp" );
        return;
      }
      mys.setAttribute("target", GenboreeUtils.getCurrentUrl(request)) ;
      GenboreeUtils.sendRedirect(request, response,  myUrl );
      return ;
    }
    else // access allowed
    {
      // Make sure to clear any accessDenied setting
      mys.removeAttribute("accessDenied") ;
    }

    viewGroupId = editGroupId;
    viewRefSeqId = editRefSeqId;
    viewEP = editEP;
    viewStart = editStart;
    viewStop = editStop;

    sessionGroupId = SessionManager.getSessionGroupId(mys);
    oldRefSeqId = SessionManager.getSessionDatabaseId(mys);
    oldEP = (String) mys.getAttribute( "editEP" );
    oldStart = (String) mys.getAttribute( "editStart" );
    oldStop = (String) mys.getAttribute( "editStop" );
    baseJsp = "/java-bin/gbrowser.jsp" ;

    vTimeLabs.addElement( "DONE - Get refseq records and process relative to group info" );
    vTimes.addElement( new java.util.Date() );

    if( editGroupId == null )
      grp_hard = false;

    if( is_navbar )
    {
      if( !Util.areEqual(editRefSeqId, request.getParameter("defRefSeqId")) )
      {
        editEP = editStart = editStop = null;
      }
      if( !Util.areEqual(editEP, request.getParameter("defEP")) )
      {
        editStart = editStop = null;
      }
    }
    if( is_navbar && !force_view )
    {
      viewGroupId = sessionGroupId;
      viewRefSeqId = oldRefSeqId;
      viewEP = oldEP;
      viewStart = oldStart;
      viewStop = oldStop;
      need_picture = false;
    }
    if( viewRefSeqId == null || viewEP == null )
    {
      GenboreeUtils.sendRedirect(request,response,  "/java-bin/defaultGbrowser.jsp" );
      return;
    }

    if( !is_navbar )
    {
      editGroupId = viewGroupId;
      editRefSeqId = viewRefSeqId;
      editEP = viewEP;
      editStart = viewStart;
      editStop = viewStop;
    }

    // -- Prepare viewbox --

    for( i=0; i<rseqs.length; i++ )
    {
      if( rseqs[i].getRefSeqId().equals(viewRefSeqId) )
      {
        vRseq = rseqs[i];
        break;
      }
    }

    vTimeLabs.addElement( "DONE - Set baseJsp and various navbar stuff" );
    vTimes.addElement( new java.util.Date() );

    if( vRseq == null )
    {
      if( !public_view && is_public )
      {
        fwdRefSeqId = request.getParameter( "refSeqId" );
        fwdEP = request.getParameter( "entryPointId" );
        fwdStart = Util.remCommas( request.getParameter("from") );
        fwdStop = Util.remCommas( request.getParameter("to") );
        fwdPictWidth = request.getParameter( "pictWidth" );
        if( fwdRefSeqId!=null && fwdEP!=null && fwdStart!=null && fwdStop!=null )
        {
          tgtUrl = baseJsp + "?refSeqId=" + fwdRefSeqId + "&entryPointId=" + Util.urlEncode(fwdEP) + "&from=" + Util.remCommas(fwdStart) + "&to=" + Util.remCommas(fwdStop);
          if( fwdPictWidth!=null )
          {
            tgtUrl = tgtUrl + "&pictWidth=" + fwdPictWidth;
          }
          mys = GenboreeUtils.invalidateSession(mys, request, response, true) ;
          GenboreeUtils.sendRedirect(request, response,  "/java-bin/login.jsp" );
          return;
        }
      }

      // This code is repeated from above. Should be a method that is fed editRefSeqId.
      String groupIDInURL = GenboreeUtils.fetchGroupIdFromRefSeqId(editRefSeqId);
      GenboreeGroup groupInURL = new GenboreeGroup();
      groupInURL.setGroupId( groupIDInURL );
      groupInURL.fetch( db );
      groupInURL.fetchRefseqs( db );
      String groupNameInURL = groupInURL.getGroupName();
      String myUrl = null;

      if(userInfo[0].equals("Public"))
      {
        myUrl = "/java-bin/login.jsp" ;
      }
      else if(groupNameInURL != null)
      {
        myUrl = "/java-bin/notifyAdmin.jsp?";
        myUrl += "groupAllowed=" + groupNameInURL + "&msgRefSeqId=" + editRefSeqId;
      }
      else
      {
          mys.setAttribute( "warnMsg", "<strong>Sorry, We have detected that this page has "+
                            "serious problems please contact " + GenboreeConfig.getConfigParam("gbAdminEmail") + " immediately to fix your account</strong>" );
          GenboreeUtils.sendRedirect(request, response,  "/java-bin/warn.jsp" );
          return;
      }
      mys.setAttribute( "msgRefSeqId", viewRefSeqId );
      mys.setAttribute( "target", GenboreeUtils.getCurrentUrl(request)) ;
      GenboreeUtils.sendRedirect(request, response, myUrl );
      return;
    }

    vTimeLabs.addElement( "DONE - Assess is_public view and redirect to public view if needed" );
    vTimes.addElement( new java.util.Date() );

    viewDbAccess = Refseq.fetchUserAccess( db, vRseq.getDatabaseName(), myself.getUserId() );

    if( JSPErrorHandler.checkErrors(request,response, db,mys) )
      return;
    if( Util.isEmpty(viewDbAccess) )
      viewDbAccess = "r";
    rootUploadId = Refseq.fetchRootId( db, viewRefSeqId );

    vTimeLabs.addElement( "DONE - DB Queries for user access and rootid" );
    vTimes.addElement( new java.util.Date() );

    // Try to get database connection only once in this page
    if(tConn == null)
      tConn = db.getConnection(vRseq.getDatabaseName()) ;

    // Try to get the fref count ONCE in this page
    totalFrefCount = DbFref.countAll(tConn) ;

    // Frefs were retrieved twice in previous version. Now it is just once (I think this is good)
    // and uses the fast methods (esp. in the face of many many EPs).
    if(totalFrefCount < 1)
    {
      vFrefs = new DbFref[0] ;
      view_enabled = false ;
    }
    else if(totalFrefCount <= Constants.GB_MAX_FREF_FOR_DROPLIST)
    {
      vFrefs = DbFref.fetchAll( db.getConnection(vRseq.getDatabaseName()) );
    }
    else // Too many entrypoints to get list and lengths for
    {
      vFrefs = new DbFref[0] ;
    }
    if(viewEP != null)
    {
      vFref = DbFref.fetchByName( tConn, viewEP ) ;
    }
    if( vFref == null )
    {
      mys.setAttribute( "editRefSeqId", viewRefSeqId );
      mys.removeAttribute( "editEP" );
      mys.removeAttribute( "editStart" );
      mys.removeAttribute( "editStop" );
      mys.setAttribute( "warnMsg", "<strong>Missing Entry Point '" + viewEP + "' in the database ID=" + viewRefSeqId + "</strong>" );
      GenboreeUtils.sendRedirect(request,response,  "/java-bin/warn.jsp" );
      return ;
    }

    vTimeLabs.addElement( "DONE - Got EP information" );
    vTimes.addElement( new java.util.Date() );

    pictWidth = request.getParameter( "pictWidth" );
    if( pictWidth == null )
      pictWidth = (String) mys.getAttribute( "pictWidth" );
    int iPictWidth = Util.parseInt( pictWidth, -1 );
    if( iPictWidth < GbrowserConstants.MIN_PICT_WIDTH )
      iPictWidth = GbrowserConstants.MIN_PICT_WIDTH;
    else if( iPictWidth > GbrowserConstants.MAX_PICT_WIDTH )
      iPictWidth = GbrowserConstants.MAX_PICT_WIDTH;
    mys.setAttribute( "pictWidth", "" + iPictWidth );

    // -- process center annotation request --
    if( nav!=null && nav.equals("ctrnav") )
    {
      ctr_gclass = request.getParameter("center_gclass");
      if( ctr_gclass == null ) ctr_gclass = "#";
          ctr_gname = request.getParameter("center_gname");
      if( ctr_gname == null ) ctr_gname = "#";
          ctr_track = request.getParameter("center_track");
      if( !ctr_gclass.equals("#") && !ctr_gname.equals("#") )
      {
        lims = vRseq.fetchGroupLimits( db, ctr_gclass, ctr_gname, viewEP, ctr_track );
        if( JSPErrorHandler.checkErrors(request,response, db,mys) )
          return;

        if( lims != null )
        {
          new_from = lims[0];
          new_to = lims[1];
          new_range = new_to - new_from;
          new_range += (long)Math.ceil(new_range/10.0);
          if( new_range < 10L ) new_range = 10L ;
          long namePad = (long)Math.ceil((new_range /(double)(iPictWidth - 120 )) * 210);
          new_range += namePad;
          new_center = (long)Math.ceil((new_to + new_from) / 2.0) ;
          new_from = (long)Math.floor(new_center - new_range/2.0) ;
          if( new_from < 1L ) new_from = 1L ;
          new_to = new_from + new_range ;

          viewStart = ""+new_from;
          viewStop = ""+new_to;
        }
      }
    }

    // -- set viewbox range --
    vMaxTo = Util.parseLong( vFref.getRlength(), 1000L );
    vFrom = Util.parseLong( viewStart, 0L );
    vTo = Util.parseLong( viewStop, 0L );
    if( vFrom==0L || vTo==0L || vTo<vFrom )
    {
      vRange = vMaxTo / 3L;
      vCtr = (vMaxTo + vMinFrom) / 2;
      vFrom = vCtr - vRange / 2;
      vTo = vFrom + vRange;
    }

    if( vFrom >= vMaxTo ) vFrom = vMaxTo - 5 ;
    if( vFrom < vMinFrom ) vFrom = vMinFrom;
    if( vTo > vMaxTo ) vTo = vMaxTo;
    viewStart = "" + vFrom;
    viewStop = "" + vTo;


    vTimeLabs.addElement( "DONE - Processed Range for viewbox" );
    vTimes.addElement( new java.util.Date() );

    has_seq = vRseq.fetchSequenceFiles( db, viewEP );

    is_db_owner = is_admin;
    if( !is_db_owner && !is_public )
    {
      acs = Refseq.fetchUserAccess(db, vRseq.getDatabaseName(), userInfo[2]);
      if( acs!=null && acs.equals("o") )
        is_db_owner = true;
    }

    vTimeLabs.addElement( "DONE - Get private user info (again?? why???) and set some picture params" );
    vTimes.addElement( new java.util.Date() );

    // --Empty track settings --
    sDisplayEmptyTracks = request.getParameter( "displayEmptyTracks" ); //check if the user changed the settings
    if( sDisplayEmptyTracks==null && request.getParameter("btnApply")==null ) //Looks like the user did not changed the settings
    {
      sDisplayEmptyTracks = (String) mys.getAttribute( "sDisplayEmptyTracks" ); //Check in the sessing for the value
      if(sDisplayEmptyTracks != null) //Check in the sessing for the value
    	iDisplayEmptyTracks = Util.parseInt( sDisplayEmptyTracks, 0 ); //parsing the value
    }
    else //Looks like the user did changed the settings
    {
    	iDisplayEmptyTracks = Util.parseInt( sDisplayEmptyTracks, 0 ); //parsing the value
    	mys.setAttribute( "sDisplayEmptyTracks", ""+iDisplayEmptyTracks ); // saving the value in the session

    }
    displayEmptyTracks = (iDisplayEmptyTracks == 1) ? " checked" : "";

    vTimeLabs.addElement( "DONE - Display EmptyTracks" );
    vTimes.addElement( new java.util.Date() );

        // -- drawInMargin settings --
    sDrawInMargin = request.getParameter( "drawInMargin" ); //check if the user changed the settings
    if( sDrawInMargin==null && request.getParameter("btnApply")==null ) //Looks like the user did not changed the settings
    {
      sDrawInMargin = (String) mys.getAttribute( "sDrawInMargin" ); //Check in the sessing for the value
	if(sDrawInMargin != null) //Check in the sessing for the value
    	    iDrawInMargin = Util.parseInt( sDrawInMargin, 0 ); //parsing the value
    }
    else
    {
    	iDrawInMargin = Util.parseInt( sDrawInMargin, 0 ); //parsing the value
    	mys.setAttribute( "sDrawInMargin", ""+iDrawInMargin ); // saving the value in the session
    }
    drawInMargin = (iDrawInMargin == 1) ? " checked" : "";

    //-- displayTrackDescription settings ---
    sDisplayTrackDesc = request.getParameter( "displayTrackDesc" ); //check if the user changed the settings

    if( sDisplayTrackDesc == null && request.getParameter( "btnApply" ) == null ) //Looks like the user did not changed the settings
    {
      sDisplayTrackDesc = ( String )mys.getAttribute( "sDisplayTrackDesc" ); //Check in the sessing for the value
      if(sDisplayTrackDesc != null) //There is a value in the session
      {
        iDisplayTrackDesc = Util.parseInt( sDisplayTrackDesc, 0 ); //parsing the value
      }
    }
    else //Looks like the user did changed the settings
    {
      iDisplayTrackDesc = Util.parseInt( sDisplayTrackDesc, 0 ); //parsing the value
      mys.setAttribute( "sDisplayTrackDesc", "" + iDisplayTrackDesc ); // saving the value in the session
    }
    displayTrackDesc = ( iDisplayTrackDesc == 1 ) ? " checked" : ""; //Use the value of the iDisplay to set the status of the display
    vTimeLabs.addElement( "DONE - Display TrackDesc" );
    vTimes.addElement( new java.util.Date() );

    if(trackArray == null || trackNames == null)
    {
      boolean allTracks = false ;
      int userId = Util.parseInt(myself.getUserId(), -1) ;
      if(iDisplayEmptyTracks > 0)
      {
        allTracks = true ;
      }

      vTimeLabs.addElement("  - DONE - Setup to call FtypeTable.fetchDbFtypeArray(db, viewRefSeqId, userId)") ;
      vTimes.addElement(new java.util.Date()) ;
      trackArray = FtypeTable.fetchDbFtypeArray(db, viewRefSeqId, userId) ;
      vTimeLabs.addElement("  - DONE - With call to FtypeTable.fetchDbFtypeArray(db, viewRefSeqId, userId)") ;
      vTimes.addElement(new java.util.Date()) ;
      // Get just track names
      trackNames = GBrowserUtils.extractTrackNameArray(trackArray) ;
      vTimeLabs.addElement("  - DONE - Calling GBrowserUtils.extractTrackNameArray(trackArray) for track name list") ;
      vTimes.addElement(new java.util.Date()) ;
      // Get all unique class names
      classes = GBrowserUtils.extractClassNameArray(trackArray) ;
      vTimeLabs.addElement("  - DONE - Calling GBrowserUtils.extractClassNameArray(trackArray) for class list") ;
      vTimes.addElement(new java.util.Date()) ;
      // Get map of classes -> list of dbFtypes within that class (local dbFype overrides shared dbFtype)
      dbFtypesByClass = GBrowserUtils.getCompleteTracksByClassHashMap(trackArray) ;
      vTimeLabs.addElement("  - DONE - Calling GBrowserUtils.getCompleteTracksByClassHashMap(trackArray) for class->tracks map") ;
      vTimes.addElement(new java.util.Date()) ;
    }

    vTimeLabs.addElement( "DONE - Fetching Tracks" );
    vTimes.addElement( new java.util.Date() );

    // track view settings
    oldTrackView = (Hashtable) mys.getAttribute( "trackView" );
    if( oldTrackView == null )
      oldTrackView = new Hashtable();
    trackView = new Hashtable();

    vTrkDispl = new Vector();
    // Preferentially use the user DB DbFtype (which come first in trackArray) over the template (which comes second)
    for( i=0; i<trackArray.length; i++ )
    {
      ft = trackArray[i] ;
      tn = ft.toString() ;

      if(!trackName2Ftype.containsKey(tn)) // Then not in there yet, can store it
      {
        trackName2Ftype.put(tn, ft) ;
      }
      if( oldTrackView.get(tn) == null )
      {
        vTrkDispl.addElement( ft );
      }
    }

    if( vTrkDispl.size() > 0 )
    {
      trkDisplArray = new DbFtype[ vTrkDispl.size() ];
      vTrkDispl.copyInto( trkDisplArray );
      vRseq.fetchTrackDisplay( db, trkDisplArray, iUserId );
      for( i=0; i<trkDisplArray.length; i++ )
      {
        ft = trkDisplArray[i];
        oldTrackView.put( ft.toString(), ft.getDisplay() );
      }
    }

    for( i=0; i<trackNames.length; i++ )
    {
      tn = trackNames[i];
      tv = request.getParameter( tn );
      if( tv == null ) tv = (String) oldTrackView.get( tn );
      if( tv == null ) tv = "1";
      trackView.put( tn, tv );
    }

    if( loadDefaultDisplay == true )
    {
      for( i=0; i<trackArray.length; i++ )
      {
        ft = trackArray[i];
        vTrkDispl.addElement( ft );
      }

      if( vTrkDispl.size() > 0 )
      {
        trkDisplArray = new DbFtype[ vTrkDispl.size() ];
        vTrkDispl.copyInto( trkDisplArray );
        vRseq.fetchTrackDisplay( db, trkDisplArray, 0 );
        for( i=0; i<trkDisplArray.length; i++ )
        {
            ft = trkDisplArray[i];
            if(ft != null)
              trackView.put( ft.toString(), ft.getDisplay() );
        }
      }
    }

    mys.setAttribute( "trackView", trackView );

    // Here is the code to take a file with track visibility
    // in the /usr/local/brl/local/apache/htdocs/xmlTemplates
    // and bypass the regular track visibility settings.

    xtrack = request.getParameter( "xtrack" );
    if( xtrack != null )
    {
      xtrackFile = new File( GbrowserConstants.templateDir, xtrack );
      if( !xtrackFile.exists() || xtrackFile.length() <= 0L )
      {
        xtrack = null;
        xtrackFile = null;
      }
      else
      {
        try
        {
          fIn = new FileReader( xtrackFile );
          xIn = new BufferedReader( fIn );
          while( (sss = xIn.readLine()) != null )
          {
            ss = Util.parseString(sss,'\t');
            if( ss.length < 2 )
              continue;
            tn = ss[0];
            tempStyleValue = Util.parseInt( ss[1], -1 );
            if(tempStyleValue >= 0 && tempStyleValue <= 5)
              trackView.put( tn, ss[1] );
            else
              trackView.put( tn, "1" );
          }
        }
        catch( Exception ex500 )
        {}
      }
    }

  // save track view settings permanently
  // First, collect current display info from the UI (might be different than in database)
  HashMap<String, String> uiViewableTracks = new HashMap<String, String>() ;
  for( i=0; i<trackArray.length; i++ )
  {
    ft = trackArray[i] ;
    String trkName = ft.getTrackName() ;
    displ = (String)trackView.get(trkName) ;
    if(displ == null )
    {
      displ = ft.getDisplay() ;
    }
    else // displ no null, so there is a UI setting. Use that setting from here on
    {
      ft.setDisplay(displ) ;
    }
    // Keep track of non-Hidden (a.k.a. 'relevant') tracks
    if(!displ.equals("2"))
    {
      uiViewableTracks.put(trkName, displ) ;
    }
  }
  if( !is_public && request.getParameter("btnSaveDisplay")!=null )
  {
    vRseq.updateTrackDisplay( db, trackArray, iUserId );
  }
  if( is_db_owner && request.getParameter("btnSaveDefaultDisplay")!=null )
  {
    vRseq.updateDefaultTrackDisplay( db, trackArray, 0 );
  }

  vTimeLabs.addElement( "DONE - Processing Track View Settings" );
  vTimes.addElement( new java.util.Date() );

  // -- prepare navbar --
  if(editGroupId == null)
  {
    editGroupId = "#";
  }

  // find group
  for( i=0; i<grps.length; i++ )
  {
    if( grps[i].getGroupId().equals(editGroupId) )
    {
      grp = grps[i];
      break;
    }
  }

  if( grp==null && grp_hard && grps.length>0 )
  {
    grp = grps[0];
    editGroupId = grp.getGroupId();
  }
  if( grp == null ) grp = new GenboreeGroup();

  if( editRefSeqId == null )
    editRefSeqId = "#";


  // search for appropriate group given a refSeqId
  if( !grp_hard && vRseq!=null && !grp.belongsTo(editRefSeqId) )
  {
    for( i=0; i<grps.length; i++ )
    {
      GenboreeGroup cGrp = grps[i];
      if( !cGrp.belongsTo(editRefSeqId) ) continue;
      int cacs = 2;
      if( cGrp.isOwner(myself.getUserId()) || is_admin ) cacs = 3;
      if( cGrp.isReadOnly(myself.getUserId()) || is_public ) cacs = 1;
      if( cacs > nAcs )
      {
        nAcs = cacs;
        nGrp = cGrp;
      }
      if( nAcs == 3 ) break;
    }
    if( nGrp!=null )
    {
      grp = nGrp;
      editGroupId = grp.getGroupId();
      grp_hard = true;
    }
  }

  vTimeLabs.addElement( "DONE - Get group info (again? slightly different?)" );
  vTimes.addElement( new java.util.Date() );

  if( vRseq == null && rseqs.length > 0 )
  {
    vRseq = rseqs[0];
    editRefSeqId = vRseq.getRefSeqId();
    editEP = editStart = editStop = null;
  }

  if( vRseq == null )
  {
    vRseq = new Refseq();
    editRefSeqId = "#";
    view_enabled = false;
  }

  refseqVersion = vRseq.getRefseq_version();

  i_am_owner = is_admin || grp.isOwner( myself.getUserId() );
  is_ro_group = !is_admin && grp.isReadOnly( myself.getUserId() );
  // This should all be under the control of group.incl. But for some silly reason, that wasn't [can't] used for this page.
  boolean userRoleCanEdit = !is_ro_group ;
  myGrpAccess = "SUBSCRIBER";
  if(!is_ro_group)
  {
    myGrpAccess = i_am_owner ? "ADMINISTRATOR" : "AUTHOR";
  }

 	String[] myrs = grp.getRefseqs();

  if( editRefSeqId == null && myrs != null && myrs.length > 0 )
  {
    editRefSeqId = myrs[0];
    editEP = null;
    editStart = editStop = null;
  }

  v = new Vector();
  for( i=0; i<rseqs.length; i++ )
  {
    Refseq rs = rseqs[i];
    if( grp.belongsTo(rs.getRefSeqId()) ) v.addElement( rs );
  }
  rseqs = new Refseq[ v.size() ];
  v.copyInto( rseqs );

  Refseq editRefseq = null;
  if( editRefSeqId != null )
  {
    for( i=0; i<rseqs.length; i++ )
      if( rseqs[i].getRefSeqId().equals(editRefSeqId) )
      {
        editRefseq = rseqs[i];
        break;
      }
  }
  if( editRefseq == null )
  {
    editEP = null;
    editStart = editStop = null;

    if( rseqs.length > 0 )
    {
      editRefseq = rseqs[0];
      editRefSeqId = editRefseq.getRefSeqId();
    }
    else
    {
      editRefSeqId = "#";
    }
  }

  if( view_enabled )
  {
    // Try to get database connection only once in this page
    if(tConn == null)
      tConn = db.getConnection(vRseq.getDatabaseName()) ;
    totalFrefCount = DbFref.countAll(tConn) ;
    if(totalFrefCount > Constants.GB_MAX_FREF_FOR_DROPLIST)
    {
      vFrefs = new DbFref[0] ;
    }
    else
    {
      vFrefs = DbFref.fetchAll( tConn );
    }
  }
  if( vFrefs == null )
  {
    vFrefs = new DbFref[0];
    view_enabled = false;
  }

  // This gets the fref object for the actual EP being viewed.
  if( editEP != null )
  {
    if(tConn == null)
      tConn = db.getConnection(vRseq.getDatabaseName()) ;
    vFref = DbFref.fetchByName( tConn, editEP ) ;
  }
  // No vFref set by now? Then just pick the first from frefs, if it has any records in it.
  if( vFref == null && vFrefs.length>0 )
  {
    vFref = vFrefs[0];
    editEP = vFref.getRefname();
    editStart = editStop = null;
  }

  absStart = "1";
  String absStop = null;
  absStop = "1000";
  minFrom = 1L;
  maxTo = 1000L;
  cFrom = minFrom;
  cTo = maxTo;

  if( vFref != null ){
    absStop = vFref.getRlength();
    maxTo = Util.parseLong( absStop, 3000L );
    long []arr = org.genboree.browser.Utils.calcEditRange(maxTo);

      cFrom = arr[0];
      cTo = arr[1];
   }
  else
    view_enabled = false;


  if( cFrom < minFrom )
    cFrom = minFrom;
  if( cTo > maxTo )
    cTo = maxTo;
  editStart = "" + cFrom;
  editStop = "" + cTo;
   //   viewStart = editStart;
   // viewStop = editStop;
   if( viewGroupId==null && viewRefSeqId.equals(editRefSeqId) )
  {
    viewGroupId = editGroupId;
  }

  if( viewGroupId != null )
  {
    mys.setAttribute( "editGroupId", viewGroupId );
//    mys.setAttribute( "uploadGroupId", viewGroupId );
  }
  else
    mys.removeAttribute( "editGroupId" );

  mys.setAttribute( "editRefSeqId", viewRefSeqId );
  mys.setAttribute( "editEP", viewEP );
  mys.setAttribute( "editStart", viewStart );
  mys.setAttribute( "editStop", viewStop );

  vTimeLabs.addElement( "DONE - Setting EP and Range for Navigation Bar" );
  vTimes.addElement( new java.util.Date() );

  // -- navigation --
  String extVal = Util.remCommas( request.getParameter("extVal") );
  if( extVal == null ) extVal = (String) mys.getAttribute( "extVal" );
  if( extVal == null || Util.parseInt(extVal,-1)<=0 ) extVal = "2000";
  mys.setAttribute( "extVal", extVal );

  long curRng = (vTo - vFrom);
  long curShift = (curRng / 10) * 9;
  long leftFrom = vFrom - curShift;
  if( leftFrom < vMinFrom )
    leftFrom = vMinFrom;
  long leftTo = leftFrom + curRng;

  long rightTo = vTo + curShift;
  if( rightTo > vMaxTo )
    rightTo = vMaxTo;
  long rightFrom = rightTo - curRng;

  curShift = curRng / 10;
  long sleftFrom = vFrom - curShift;
  if( sleftFrom < vMinFrom )
    sleftFrom = vMinFrom;
  long sleftTo = sleftFrom + curRng;

  long srightTo = vTo + curShift;
  if( srightTo > vMaxTo )
    srightTo = vMaxTo;
  long srightFrom = srightTo - curRng;

  long xleftFrom = vMinFrom;
  long xleftTo = xleftFrom + curRng;

  long xrightTo = vMaxTo;
  long xrightFrom = xrightTo - curRng;

  String realIdxPath =  pageContext.getServletContext().getRealPath( "defaultGbrowser.jsp" );
  File fRealBase = (new File(realIdxPath)).getParentFile();
  File fRealBinary = new File( Constants.GBROWSER );
  String realBinary = fRealBinary.getAbsolutePath();

  File fgif = null;
  String gifName = (fgif!=null) ? fgif.getName() : null;
  File fmap = null;
  String mapName = (fmap!=null) ? fmap.getName() : null;
  String finalMapFileName = new String();
  String linkNameString = new String();
  File finalMapFile =   null;
  File linkNameFile =  null;

  if( fgif==null || fmap==null )
    need_picture = true;

  if( !need_picture )
  {
    if( !fgif.exists() || !fmap.exists() )
      need_picture = true;
  }

  if( gifName == null )
    gifName = "#.gif";
  String fileName = gifName;
  int dotidx = gifName.lastIndexOf( '.' );
  if( dotidx > 0 )
    fileName = gifName.substring( 0, dotidx );
  String xmlName = fileName + ".xml";
  File fxml =  (fgif!=null) ? new File( fgif.getParentFile(), xmlName ) : null;

  Exception __ex = null;
  String cmdLine = "#";

  if( need_picture )
  {
    fgif = TempSyncFile.createTempFile( "genb", typeOfImage, GbrowserConstants.graphicsDir );
    gifName = fgif.getName();

    fileName = gifName;
    dotidx = gifName.lastIndexOf( '.' );
    if( dotidx > 0 )
      fileName = gifName.substring( 0, dotidx );

    mapName = fileName+".map";
    fmap = new File( fgif.getParentFile(), mapName );
    finalMapFileName = fileName + "_final.map";
    finalMapFile =    new File( fgif.getParentFile(), finalMapFileName );
    linkNameString = fileName + ".links";
    linkNameFile =  new File( fgif.getParentFile(), linkNameString );
    mys.setAttribute("lastlinks", linkNameFile);
  }

  if( request.getParameter("btnClearCache") != null )
  {
    CacheManager.clearCache( db, vRseq );
    vDebug.addElement( "Cache cleared." );
  }

  vTimeLabs.addElement( "    - BEFORE create CacheManager") ;
  vTimes.addElement( new java.util.Date() ) ;
  CacheManager cacheManager = new CacheManager( db, vRseq, myself.getUserId(), serverName, uiViewableTracks  ) ;
  cacheManager.setVTimeLabs(vTimeLabs, vTimes) ;
  vTimeLabs.addElement( "    - AFTER create CacheManager ; about to search cache") ;
  vTimes.addElement( new java.util.Date() ) ;
  if( need_picture &&
      cacheManager.cacheSearch(vFref, vFrom, vTo, iPictWidth, iDisplayEmptyTracks,iDrawInMargin, iDisplayTrackDesc) != null )
  {
    vTimeLabs.addElement("    - AFTER cacheSearch() came up positive for cache hit!") ;
    vTimes.addElement( new java.util.Date() ) ;

    if( cacheManager.retrieveFiles(fgif, fmap, finalMapFile, linkNameFile, typeOfImage) )
    {
      vTimeLabs.addElement("    - AFTER retrieveFiles()") ;
      vTimes.addElement( new java.util.Date() ) ;
      need_picture = false ;
      vTimeLabs.addElement( "DONE - Cache retrieval" ) ;
      vTimes.addElement( new java.util.Date() ) ;
    }
  }
  vTimeLabs.addElement("    - AFTER cache check & possible retrieval") ;
  vTimes.addElement( new java.util.Date() ) ;

  if( JSPErrorHandler.checkErrors(request,response, db,mys) )
    return;

  if( need_picture )
  {
      java.util.Date genStart = new java.util.Date();
      xmlName = fileName + ".xml";
      fxml = new File( fgif.getParentFile(), xmlName );
      File saveTrackFile = null;
      PrintWriter psOut = null;
      String saveXtrack = request.getParameter( "savextrack" );
      if( !is_admin || request.getParameter("btnSaveXtrack")==null )
      saveXtrack = null;
      if( !Util.isEmpty(saveXtrack) )
      {
      saveTrackFile = new File( GbrowserConstants.templateDir, saveXtrack );
      psOut = new PrintWriter( new FileWriter(saveTrackFile) );
      }


      Process pr;
      try
      {
      //        fgif.delete();
      fxml.createNewFile();
      pr = Runtime.getRuntime().exec( "chmod 666 " + fxml.getAbsolutePath() );
      pr.waitFor();
      } catch( Exception ex04 )
      {}

      PrintWriter pout = new PrintWriter( new FileWriter(fxml) );
      pout.println( "<GENBOREETRACKS>" );
      for( i=0; i<trackNames.length; i++ ) {
      String vis = (String) trackView.get(trackNames[i]);
      if( vis == null ) vis = "1";
      sss = "<TRACKVIS trackName=\"" +
      Util.base64encode(trackNames[i]) +
      "\" visibility=\"" + vis + "\" order=\"" + i + "\" className=\"" +
      Util.getXMLCompliantString(trackArray[i].getGclass()) +
      "\"> </TRACKVIS>";
      pout.println( sss );
      if( psOut != null )
      psOut.println( trackNames[i]+"\t"+vis+"\t"+i );
      }
      pout.println( "</GENBOREETRACKS>" );
      pout.flush();
      pout.close();

      if( psOut != null )
      {
      psOut.flush();
      psOut.close();
      }

      vTimeLabs.addElement( "DONE - Creating Parameter Files for Picture Generator" );
      vTimes.addElement( new java.util.Date() );

      try
      {
      /*
      Usage: ./genboree.exe
      -i START
      -t STOP
      -r REFSEQID
      -u USERID
      -e ENTRYPOINT
      -n FILENAME [-b BASEDIR]
      [-v LIST-VISIBILITIES || -? FILE-WITH-VISIBILITIES-OPTIONS || -x XMLFILE-WITH-VISIBILITIES-OPTIONS]
      */
      cmdLine = realBinary+
      " -i "+viewStart+" -t "+viewStop+" -r "+viewRefSeqId+" -f 2"+
      " -u "+userInfo[2]+" -e "+viewEP+
      " -n "+fileName+
      " -w "+(iPictWidth - GbrowserConstants.PICT_BORDER_WIDTH)+
      " -b "+fgif.getParent()+File.separator+
      " -x "+fxml.getAbsolutePath(); // + " -d";

      if( iDisplayEmptyTracks == 1 )
      cmdLine = cmdLine + " -l";

      if( iDrawInMargin == 1)
      cmdLine = cmdLine + " -y";

      if( iDisplayTrackDesc  == 1 )
        cmdLine = cmdLine + " -g";

      if(true || userInfo[0].equals("admin")  || userInfo[0].equals("andrewj") || userInfo[0].equals("charneck") || userInfo[0].equals("paithank"))
      {
        cmdLine = cmdLine + " -d ";
      }

      if(typeOfImage.equalsIgnoreCase(".png"))
      cmdLine = cmdLine + " -p ";

      vTimeLabs.addElement( "DONE - Command line PNG-drawer command built. About to execute." ) ;
      vTimes.addElement( new java.util.Date() );

      pr = Runtime.getRuntime().exec( cmdLine );

      vTimeLabs.addElement( "DONE - Command line executed. About to consume command's stderr stream (if any stderr output)." ) ;
      vTimes.addElement( new java.util.Date() );

      vDebug.addElement( "Command Line is " + cmdLine );

      // Redirect process' stderr to our jsp's stderr
      InputStream p_err = pr.getErrorStream();
      err = new BufferedReader( new InputStreamReader(p_err) );
      /* The error stream need to be consummed even if it is not printed otherwise the process is not terminated and the c program does not finish */
      String es;
      System.err.println( "------------------------------------\nC PROG STDERR\n---------------------------------\n") ;
      while( (es = err.readLine()) != null )
      {
        errorStringCProgram.append( es + "\n") ;
        System.err.println(es) ; // uncomment this line if you want to print the c program errors to the catalina log
      }
      System.err.println( "------------------------------------") ;
      /* Fisnish consumming the error buffer */
      pr.waitFor();
      }
      catch( Exception ex03 )
      { __ex = ex03; }

    vTimeLabs.addElement( "DONE - Drawing command's stderr consumed. Drawing command all finished." ) ;
    vTimes.addElement( new java.util.Date() ) ;

    // -------------------------------------------------------------------------
    // Write <map> file. Also write the unique linkNames list Javascript code file.
    // -------------------------------------------------------------------------
    // ARJ => begin MOD'd this section 2008/10/13
    mapLinkFile = new MapLinkFile(fmap, finalMapFile, linkNameFile, trackName2Ftype, userRoleCanEdit) ;
    vTimeLabs.addElement( "DONE - new MapLinkFile instance created" ) ;
    vTimes.addElement( new java.util.Date() ) ;
    boolean madeMapAndLinkFile = mapLinkFile.createMapAndLinkFile() ;
    vTimeLabs.addElement( "DONE - created map and link file via mapLinkFile.createMapAndLinkFile()" ) ;
    vTimes.addElement( new java.util.Date() ) ;
    if(!madeMapAndLinkFile)
    {
      System.err.println("ERROR: couldn't read and convert raw map file from C program to final map and link files when using calling gbrowser with the following arguments " + cmdLine ) ;
    }
    // Report timings for this step.
    vTimeLabs.addElement( "DONE - All Done Processing Special C Map File and Writing Final Map and Links File" ) ;
    vTimes.addElement( new java.util.Date() ) ;
    // ARJ => end MOD'd this section 2008/10/13
    // END: writing <map> file and unique linkNames Javascripts list file.
    // -------------------------------------------------------------------------

    java.util.Date genStop = new java.util.Date();
    long genSecs = (genStop.getTime() - genStart.getTime()) / 1000L;

    if( genSecs >= minTimeCache )
    {
    // In here the name of the files are the full path for example
    cacheManager.storeFiles( fgif, fmap, finalMapFile, linkNameFile, typeOfImage);
    if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
    vDebug.addElement( "Cache stored." );
    }

    vTimeLabs.addElement( "DONE - Generating  Map Files" );
    vTimes.addElement( new java.util.Date() );
  }

  String bkmkUrl =  baseJsp + "?refSeqId=" + viewRefSeqId + "&entryPointId=" +
                    Util.urlEncode(viewEP) + "&from=" + viewStart + "&to=" + viewStop;

   if( iPictWidth > GbrowserConstants.MIN_PICT_WIDTH )
    bkmkUrl = bkmkUrl + "&pictWidth=" + iPictWidth;
    if( xtrack != null )
    bkmkUrl = bkmkUrl + "&xtrack=" + xtrack;
    if( is_public )
    bkmkUrl = bkmkUrl + "&isPublic=YES";

    String locImageName = "/graphics/" + gifName;
    if( !fgif.exists() || fgif.length()<256 )
    locImageName = "/images/empty.gif";

    mys.setAttribute( "destback", bkmkUrl );
    mys.setAttribute( "lastBrowserView", bkmkUrl );

    vTimeLabs.addElement( "DONE - URL prep (Before reading map/link files)" );
    vTimes.addElement( new java.util.Date() );

    processedMapFile  = new ReadFile( finalMapFile.getAbsolutePath() );
    fileWithLinkNames = new ReadFile(linkNameFile.getAbsolutePath());

    SessionManager.setSessionGroupId(mys, editGroupId);
    SessionManager.setSessionDatabaseId(mys, editRefSeqId);
    mys.setAttribute("browserGroupID",  editGroupId);
    mys.setAttribute("browserRefseqId", editRefSeqId);

    String tableWidth ="670";
    vTimeLabs.addElement( "Generating Final HTML" );
    vTimes.addElement( new java.util.Date() );

%>

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"> <!-- "http://www.w3.org/TR/html4/loose.dtd"> -->
<HTML lang="en">
<head>
<title>Genboree - Genome Browser</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css"></link>
<link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css"></link>
<link rel="stylesheet" href="/styles/gbrowser.css<%=jsVersion%>" type="text/css"></link>
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
<meta HTTP-EQUIV="Pragma" CONTENT="no-cache">
  <script type="text/javascript">
    // Label this window as one that may need refreshing
    window.refreshMe = true ;
    window.name = "_refreshMe" ;
  </script>
<script type="text/javascript" src="/javaScripts/util.js<%=jsVersion%>"></script>               <!-- This should be on all pages, but often is not -->
<script type="text/javascript" src="/javaScripts/overlib.js<%=jsVersion%>"></script>            <!-- Core, official overlib -->
<script type="text/javascript" src="/javaScripts/overlib_hideform.js<%=jsVersion%>"></script>    <!-- Official extension to make sure popup is on top of form elements -->
<script type="text/javascript" src="/javaScripts/overlib_draggable.js<%=jsVersion%>"></script>  <!-- Unofficial extension to allow dragging of the popup -->
<script type="text/javascript" src="/javaScripts/overlib_cssstyle.js<%=jsVersion%>"></script>    <!-- Official extension to use css style classes for the title bar appearance -->
<script type="text/javascript" src="/javaScripts/prototype-1.6.js<%=jsVersion%>"></script>    <!-- Official extension to use css style classes for the title bar appearance -->
<script type="text/javascript" src="/javaScripts/scriptaculous-1.8/scriptaculous.js<%=jsVersion%>&load=effects,builder,dragdrop"></script>    <!-- Official extension to use css style classes for the title bar appearance -->
<script type="text/javascript" src="/javaScripts/commonFunctions.js<%=jsVersion%>"></script>    <!-- Official extension to use css style classes for the title bar appearance -->
<link rel="stylesheet" href="/javaScripts/jsCropperUI/cropper/cropper.css<%=jsVersion%>" type="text/css"></link>
<script type="text/javascript" src="/javaScripts/jsCropperUI/cropper/cropper.uncompressed.js<%=jsVersion%>"></script>
<!-- onchange="updateChromosomeSelected()" -->

<script type="text/javascript">
  // Ensure jsession cookie present and not a static hand-off (MSIE library -> MSIE browser hand off fix).
  // Do this NOW rather than waiting for page to fully finish loading.
  requireSession() ;
  requireBrowserApp() ;
<%

    // In here the array of links is created
    vTimeLabs.addElement( "Before the additional link file" );
    vTimes.addElement( new java.util.Date() );
    try
    {
      String stringWithLinks = fileWithLinkNames.readEntireFile();
      out.println(stringWithLinks);
      out.flush();
    } catch (FileNotFoundException ex)
    {
      System.err.println("Fatal error reading file " + fileWithLinkNames.getFileName());
    }

    vTimeLabs.addElement( "After the additional link file");
    vTimes.addElement( new java.util.Date() );
%>

// These are available to functions on this page and other included .js files (gbrowser.js in particular makes use of them)
var origFrom = <%=viewStart%> ;
var origTo = <%=viewStop%> ;
var absStart = <%=absStart%>;
var absStop = <%=absStop%>;
var cAbsStop = "<%=Util.putCommas(absStop)%>";
var minFrom = <%=vMinFrom%>;
var maxTo = <%=vMaxTo%>;
var hasSequence = <%=has_seq%>;
var minPictureWidth = <%=GbrowserConstants.MIN_PICT_WIDTH%>;
var maxPictureWidth = <%=GbrowserConstants.MAX_PICT_WIDTH%>;
var imgLeftMarginPxWidth = <%= GenboreeConfig.getIntConfigParam("imgLeftMarginPxWidth", 120) %> ;
var imgRightMarginPxWidth = <%= GenboreeConfig.getIntConfigParam("imgRightMarginPxWidth", 60) %> ;
var developmentHost = <%=developmentServer %> ;// JSP: Looks like a test for OLD Genomic DNA link, which only gets + strand? Or maybe its the new one that goes to an intermediate page first?
<% boolean allowToEdit = ( "ow".indexOf(viewDbAccess) >= 0 );%>
var allowToEdit = <%=allowToEdit %> ;
var rootUploadId = <%=rootUploadId%>;
var viewGroupId = <%=viewGroupId%>;
var referenceSequenceName = "<%=viewEP%>";
var viewRefSeqId = <%=viewRefSeqId%>;
var entryPointSize = new Array();
<%
    // ------------------------------------------------------------------------
    // ARJ 8/23/2005 2:52PM :
    //   If too many frefs, we don't send all the EP lengths. Users will enter
    //   info manually and we'll do our best with what they submit.
    // ------------------------------------------------------------------------
    // CASE 1: Have small number of entrypoint. (Most common case.)
    // ------------------------------------------------------------------------
    if(totalFrefCount <= Constants.GB_MAX_FREF_FOR_DROPLIST)
    {
      for(int ii = 0; ii < vFrefs.length; ii++)
      {
        out.println("entryPointSize[\"" + vFrefs[ii].getRefname() + "\"] = " + vFrefs[ii].getRlength() + ";");
       }
    }
%>
  // Chrom Thumbnail cropper
  var chrCropper ;
  Event.observe(window, 'load', function()
  {
    var chromThumbImg = $('chromThumb') ;
    // The width/height checks in the following are mainly to check if IE
    // is displaying a placeholder icon because an error HTTP code was received
    // from the page. We don't want that to show up (interestingly, IE does give
    // this "no image" placehold icon the correct id tag.) The constants are defined in the JSP.
    if(chromThumbImg != null && chromThumbImg.width >= <%=CHROM_THUMB_WIDTH%> && chromThumbImg.height >= <%=CHROM_THUMB_HEIGHT%>)
    {
      var rightMargin = $('chromThumb').width ;
      chrCropper = new Cropper.Img(
        'chromThumb',                                         // Id of the image to apply "cropping selection" to
        {
          displayOnInit : true,
          onloadCoords : { x1: bpCoordToImgX(origFrom, 'thumb'), y1: 0, x2: bpCoordToImgX(origTo, 'thumb'), y2: 20},
          autoIncludeCSS : false,                             // Original feature: disable auto CSS load by library (we need to jsVersion it)
          minHeight : $('chromThumb').height,                 // Original feature: set minimum crop height to be height of whole image
          maxHeight : $('chromThumb').height,
          minWidth  : 2,                                      // Original feature: set the minimum width of the crop rectangle (usability here)
          minX      : 0,                                    // New feature: set the left-bound (left margin if you will) for the crop rectangle within the image
          maxX      : rightMargin,                            // New feature: set the right-bound(right margin if you will) for the crop rectangle within the image
          hideHandles : false,                                // New feature: can hide the resize handles (e.g. true + location redirect upon endCrop == UCSC behavior)
          overlayCancels : false,                              // New feature: enables clicks in the overlays to cancel the crop selection
          showOverlayText : false,                             // New feature: show some dev-provided basic text within the overlays (recommend: info on how to cancel--was annoying not having natural/obvious cancel)
          overlayText : "",   // New feature: the text to show centered in the overlays if showOverlayText is true
          useActivationRegion : false,                         // *New feature: only activate the crop selection when initiated in a specifc (dev-defined) region of the image
          mouseupFuzziness : { top: 2, right: 2, bottom: 2, left: 2 }, // *New feature: this is the number of pixels the mouseup event can be *outside* the activation region (can be a little more convenient while still having code make sure we're not stealing events meant for other widgets). Default is 0,0,0,0.
          onEndCrop : onEndChrCrop,                              // Original feature: register a callback for the endCrop event (we update from/to coords)
          onCancel  : onCancelChrCrop,                            // New feature: register a callback for the cancel event (we restore/reset the original from/to coords)
          escCancels : false,
          handleType : "full",
          handleConfig : {
            size : 2,
            border : "1px solid #330066",
            background : "#CC00CC",
            opacity : 1.0
          },
          overlayConfig : {
            opacity : 0.16
          },
          marqueeConfig : {
            vertMarqueeGif  : '/images/genbMarqueeVert.gif',
            horizMarqueeGif : '/images/genbMarqueeHoriz.gif',
            vertMarqueeWidth : '2px',
            horizMarqueeHeight : '2px'
          }
        }
      ) ;
    }
    else // it's messed up; IE8 and others will show ugly icon thing instead, so remove it if it's there
    {
      if(chromThumbImg && chromThumbImg.remove)
      {
        chromThumbImg.remove() ;
      }
    }
  }) ;

  // ARJ: To hold the cropper and allow functions on this page access to it.
  var cropper ;
  // ARJ: On page load, create an instance of our modified Image Cropper library.
  Event.observe(window, 'load', function()
  {
    var rightMargin = $('bimg').width - 60 ;                // Our image has a 60px right margin "dead" space (no crop select should go in there)
    cropper = new Cropper.Img(
      'bimg',                                               // Id of the image to apply "cropping selection" to
      {
        autoIncludeCSS : false,                             // Original feature: disable auto CSS load by library (we need to jsVersion it)
        minHeight : $('bimg').height,                       // Original feature: set minimum crop height to be height of whole image
        maxHeight : $('bimg').height,
        minWidth  : 5,                                      // Original feature: set the minimum width of the crop rectangle (usability here)
        minX      : 120,                                    // New feature: set the left-bound (left margin if you will) for the crop rectangle within the image
        maxX      : rightMargin,                            // New feature: set the right-bound(right margin if you will) for the crop rectangle within the image
        hideHandles : false,                                // New feature: can hide the resize handles (e.g. true + location redirect upon endCrop == UCSC behavior)
        overlayCancels : true,                              // New feature: enables clicks in the overlays to cancel the crop selection
        escCancels : true,
        showOverlayText : true,                             // New feature: show some dev-provided basic text within the overlays (recommend: info on how to cancel--was annoying not having natural/obvious cancel)
        overlayText : "'Esc' to Cancel<br>or click here",   // New feature: the text to show centered in the overlays if showOverlayText is true
        useActivationRegion : true,                         // *New feature: only activate the crop selection when initiated in a specifc (dev-defined) region of the image
        activationRegion : { x1: 120-119, y1: 0, x2: rightMargin+59, y2: 18 }, // *New feature: if useActivationRegion, this is the bounding box of the activation region within the image.
        mouseupFuzziness : { top: 5, right: 0, bottom: 0, left: 0 }, // *New feature: this is the number of pixels the mouseup event can be *outside* the activation region (can be a little more convenient while still having code make sure we're not stealing events meant for other widgets). Default is 0,0,0,0.
        onEndCrop : onEndCrop,                              // Original feature: register a callback for the endCrop event (we update from/to coords)
        onCancel  : onCancelCrop,                            // New feature: register a callback for the cancel event (we restore/reset the original from/to coords)
        handleType : "full",
        handleConfig : {
          size : 2,
          border : "1px solid green",
          background : "#CC00CC",
          opacity : 0.7
        },
        overlayConfig : {
          opacity : 0.6
        },
        marqueeConfig : {
          vertMarqueeGif  : '/images/genbMarqueeVert.gif',
          horizMarqueeGif : '/images/genbMarqueeHoriz.gif',
          vertMarqueeWidth : '2px',
          horizMarqueeHeight : '2px'
        }
      }
    ) ;
  }) ;

  // ARJ: endCrop callback. Called when crop selection finishes due to a drag or a move.
  //      We update the from/to numbers based on bp/px resolution and location of the crop selection box.
  //      Calls bp-related functions from gbrowser.js.
  function onEndCrop(coords, dims)
  {
    // Update from and to form fields with new values
    var bpPerPx = getImgBpPerPx('gbrowser') ;
    var selectedBpWidth = dims.width * bpPerPx ;
    var selectedStartAsBpPos = Math.round(imgXToBpCoord(coords.x1, 'gbrowser')) ;
    var selectedStopAsBpPos = Math.round(selectedStartAsBpPos + selectedBpWidth - 1) ;
    // Update the various wigets named 'from/to/start/stop' that exist within various forms on this page (ugh, what a mess).
    // Anyway, now they will act on the selected region
    updateCoordWidgets(selectedStartAsBpPos, selectedStopAsBpPos,  'crimson') ;
    // Update the displayed from/to text inputs
    $('entryPointFrom').value = commify(selectedStartAsBpPos) ;
    $('entryPointTo').value = commify(selectedStopAsBpPos) ;
    return ;
  }

  // ARJ: cancel crop callback. Called when the user hits 'Esc' (on browsers that support it; not Safari 4 it seems) or clicks in an overlay (if enabled)
  //      We restore the original from/to using a function from gbrowser.js.
  function onCancelCrop(e)
  {
    restoreOrigFromTo(e) ;
    // Reset chromosome cropper too
    chrCropper.reset() ;
    return ;
  }

  // ARJ: endCrop callback. Called when crop selection finishes due to a drag or a move.
  //      We update the from/to numbers based on bp/px resolution and location of the crop selection box.
  //      Calls bp-related functions from gbrowser.js.
  function onEndChrCrop(coords, dims)
  {
    // Update from and to form fields with new values
    var bpPerPx = getImgBpPerPx('thumb') ;
    var selectedBpWidth = dims.width * bpPerPx ;
    var selectedStartAsBpPos = Math.round(imgXToBpCoord(coords.x1, 'thumb')) ;
    var selectedStopAsBpPos = Math.round(selectedStartAsBpPos + selectedBpWidth - 1) ;
    // Update the various wigets named 'from/to/start/stop' that exist within various forms on this page (ugh, what a mess).
    // Anyway, now they will act on the selected region
    updateCoordWidgets(selectedStartAsBpPos, selectedStopAsBpPos, 'crimson') ;
    // Show the 'view' hint (unless already showing)
    if(!$('chromThumbHint'))
    {
      $('chromThumb').insert(
      {
        after: "<span id='chromThumbHint' name='chromThumbHint' onclick=\"$('btnView').click() ;\" >View</span>"
      }) ;
    }
    // Update the displayed from/to text inputs
    $('entryPointFrom').value = commify(selectedStartAsBpPos) ;
    $('entryPointTo').value = commify(selectedStopAsBpPos) ;
    return ;
  }

  // ARJ: cancel crop callback. Called when the user hits 'Esc' (on browsers that support it; not Safari 4 it seems) or clicks in an overlay (if enabled)
  //      We restore the original from/to using a function from gbrowser.js.
  function onCancelChrCrop(evt)
  {
    restoreOrigFromTo(evt) ;
    return ;
  }
</script>
</head>
<BODY onload="initMenus( viewGroupId, viewRefSeqId);">
<!-- This overDiv object is used by overlib. It's not really necessary. -->
<DIV id="overDiv" class="c1"></DIV>
<div id='hDiv' style='border-width:1px; border-color:red;position:absolute;' >&nbsp;</div>

<table cellpadding="0" cellspacing="0" border="0" bgcolor="white" width="<%=(iPictWidth+100)%>" class='TOP'>
<tbody>
  <tr>
  <td width="10"></td>
  <td height="10"></td>
  <td width="10"></td>
  <td width="10" class="bkgd"></td></tr>
  <tr><td></td><td>
      <table border="0" cellpadding="0" cellspacing="0" width="100%">
      <tr>
        <td width="484">
          <a href="defaultGbrowser.jsp">
            <img src="/images/genboree.jpg" width="484" height="72" border="0" alt="Genboree">
          </a>
        </td>
        <td width="151" align="right">
          <a href="http://www.bcm.edu">
            <img src="/images/logo_sm.gif" width="151" height="80" alt="BCM" title="BCM" border="0">
          </a>
        </td>
      </tr>
      </table>

  </td>
  <td width="10"></td>
  <td class="shadow"></td></tr>
  <tr><td></td><td>

<%@ include file="include/navbar.incl" %>
<%@ include file="include/gbrowsernav.incl" %>
<%@  include file="include/message.incl" %>

<br>
<table border="0" cellspacing="0" cellpadding="0" bgcolor="#D3CFE6">
<tr><td>

<%
  if(!is_public)
  {
%>
    <form class="no_margins" name="sendmsg" action="notify.jsp" method="post" target="sendmsg">
      <input type="hidden" name="groupId" id="groupId" value="<%=viewGroupId%>">
      <input type="hidden" name="msg_test" id="msg_test" value="<%=Util.htmlQuote(myself.getScreenName())%>">
      <input type="hidden" name="msg_stdinfo" id="msg_stdinfo" value="<%=Util.htmlQuote(myself.getScreenName())%> has the following comment about this Genboree visualization: Database <%=Util.htmlQuote(vRseq.getRefseqName())%>, ID <%=viewRefSeqId%>">
      <input type="hidden" name="msg_url" id="msg_url" value="<%=Util.htmlQuote(bkmkUrl)%>">
    </form>
<% } %>

<form name="sendSearch" action="/java-bin/genboreeSearchWrapper.jsp" method="post">
<input type="hidden" name="refSeqID" id="searchRefSeqId" value="">
<input type="hidden" name="query" id="searchQuery" value="">
</form>
<form class="no_margins" id="navbar" name="navbar" action="gbrowser.jsp" method="post" target="_top" onsubmit="return validateNavbar();">
  <input type="hidden" name="isNavBar" id="isNavBar" value="1">
  <input type="hidden" name="defRefSeqId" id="defRefSeqId" value="<%=editRefSeqId%>">
  <input type="hidden" name="defEP" id="defEP" value="<%=editEP%>">
  <table width="<%=tableWidth%>" border="0" cellpadding="2" cellspacing="0" align="left">
<%
    if( !is_public )
    {
%>
      <tr>
        <td class="form_header" colspan="5">Group:&nbsp;&nbsp;
          <select name="groupId" id="groupIdNavBar" class="txt" style="width:200" onchange='switchGroup(this.options[this.selectedIndex].value);' >
<%
            vTimeLabs.addElement( "Before the group loop" );
            vTimes.addElement( new java.util.Date() );
            for( i=0; i<grps.length; i++ )
            {
              String myId = grps[i].getGroupId();
              String sel = myId.equals(editGroupId) ? " selected" : "";
              String hcls = Util.areEqual(myId,viewGroupId) ? " class=\"txthilit\"" : "";
%>
              <option<%=hcls%> value="<%=myId%>"<%=sel%>><%=Util.htmlQuote(grps[i].getGroupName())%></option>
<%          } %>
          </select>
          &nbsp;&nbsp;<font color="#CCCCFF">Role:</font>&nbsp;&nbsp;<%=myGrpAccess%>
          &nbsp;&nbsp;
        </td>
        <td class="form_header"  align="right">
          <input type="button"  name="btnSend" id="btnSend" value="Email Group" class="btn" style="width:90" onClick="document.sendmsg.submit()">
        </td>
      </tr>
      <tr>
        <td colspan="6" style="height:2"></td>
      </tr>
<%  } // !is_public %>
    <tr>
      <td class="form_header">Database</td>
      <td class="form_header">Assembly&nbsp;</td>
      <td class="form_header">&nbsp;Entry Point</td>
      <td class="form_header">From</td>
      <td class="form_header">To</td>
      <td class="form_header" align="right">&nbsp;</td>
    </tr>
    <tr>
      <td class="form_header">
<%
      if( is_public )
      {
%>
        <select name="refSeqId" id="refSeqIdMenu" class="txt" style="width:200" onchange='switchToPublicDefaultBrowser(this.options[this.selectedIndex].value);' >
<%
      }
      else
      {
%>
        <select name="refSeqId" id="refSeqIdMenu" class="txt" style="width:200" onchange="switchGroup(document.getElementById('groupIdNavBar').value, this.options[this.selectedIndex].value);" >
<%    } // !is_public %>
      <!-- onchange='this.form.submit()' -->
<%
      vTimeLabs.addElement( "Before the refseq loop" );
      vTimes.addElement( new java.util.Date() );
      for( i=0; i<rseqs.length; i++ )
      {
        String myId = rseqs[i].getRefSeqId();
        String sel = myId.equals(editRefSeqId) ? " selected" : "";
        String hcls = Util.areEqual(myId,viewRefSeqId) ? " class=\"txthilit\"" : "";
%>
        <option<%=hcls%> value="<%=myId%>"<%=sel%>><%=Util.htmlQuote(rseqs[i].getRefseqName())%></option>
<%
      }
      boolean same_rseq = Util.areEqual(editRefSeqId,viewRefSeqId);
%>
        </select>
      </td>
      <td class="form_header">
        <table border="1" cellspacing="0" cellpadding="0" width="100%">
        <tr>
          <td bgcolor="<%=same_rseq?"#EAE6FF":"white"%>">
            <strong><%=Util.htmlQuote(refseqVersion)%></strong>&nbsp;
          </td>
        </tr>
        </table>
      </td>
      <td class="form_header">
<%
        // ------------------------------------------------------------------------
        // ARJ 8/22/2005 3:33PM :
        //   Construct the entrypoint droplist/textInput.
        //   If too many, make it a textInput rather than a list.
        // ------------------------------------------------------------------------
        // CASE 1: Have small number of entrypoint. Use droplist. (Most common case.)
        // ------------------------------------------------------------------------
        String cls = "txt" ;
        if(totalFrefCount <= Constants.GB_MAX_FREF_FOR_DROPLIST)
        {
%>
          <select name="entryPointId" id="entryPointIdSelection" onchange="updateEntryPointSelected()" class="txt" style="width:130px">
            <!-- onchange='this.form.submit()' -->
<%
            for( i=0; i<vFrefs.length; i++ )
            {
              String myId = vFrefs[i].getRefname();
              String sel = myId.equals(editEP) ? " selected" : "";
              String hcls = (same_rseq && Util.areEqual(myId,viewEP)) ? " class=\"txthilit\"" : "";
%>
              <option<%=hcls%> value="<%=myId%>"<%=sel%>><%=myId%></option>
<%
            }
            cls = (same_rseq && Util.areEqual(editEP,viewEP)) ? "txthilit" : "txt";
%>
          </select>
<%
        }
        // ------------------------------------------------------------------------
        // CASE 2: Have large number of entrypoint. Use text input. (Most common case.)
        // ------------------------------------------------------------------------
        else
        {
%>
          <input type="text" name="entryPointId" id="entryPointIdSelection" class="txt" style="width:130px;" value="<%= viewEP %>">
<%
        }
        // -----------------------------------------------------------------------
%>
      </td>
      <td class="form_header">
        <input name="from" type="text" id="entryPointFrom" value="<%=Util.putCommas(viewStart)%>" class="<%=cls%>" style="width:85">
      </td>
      <td class="form_header">
        <input name="to" type="text" id="entryPointTo" value="<%=Util.putCommas(viewStop)%>" class="<%=cls%>" style="width:85">
      </td>
      <td class="form_header" align="right">
        <input name="btnView" type="submit" id="btnView" <%=view_enabled ? "" : "disabled "%>value='View' class="btn" style="width:70">
      </td>
    </tr>
  </table>
</form>

</td>
</tr>
<tr>
<td>

<form class="no_margins" id="viewbox" name="viewbox" action="gbrowser.jsp" method="post" target="_top"
  onsubmit="return validateViewbox();">
<table>
<tr>
<td>
<input type="hidden" name="nav" id="nav" value="none">
<% if( viewGroupId != null ) { %>
<input type="hidden" name="groupId" id="groupId" value="<%=viewGroupId%>">
<% } %>
<input type="hidden" name="refSeqId" id="refSeqId" value="<%=viewRefSeqId%>">
<input type="hidden" name="entryPointId" id="entryPointId" value="<%=viewEP%>">
<input type="hidden" name="from" id="from" value="<%=viewStart%>">
<input type="hidden" name="to" id="to" value="<%=viewStop%>">

<input type="hidden" name="center_gclass" id="center_gclass" value="#">
<input type="hidden" name="center_gname" id="center_gname" value="#">
<input type="hidden" name="center_track" id="center_track" value="#">

<table width="680" border="0" cellpadding="2" cellspacing="0" align="left">
<tbody>
  <tr>
    <td class="form_body" align="left" valign="bottom" nowrap>
    &nbsp;<b>Extend:</b>
    <a href="javascript:handleLeft();"
      onMouseDown="btnDown(this,'imgXl')"
      onMouseUp="btnUp(this,'imgXl')"
  onMouseOut="btnUp(this,'imgXl')"
  onMouseOver="btnLightup(this, 'imgXl')"
      >
      <img border="0"
      width="24"
      height="18"
      alt="Extend view to the left"
      title="Extend view to the left"
      align="absmiddle" name="imgXl" id="imgXl" src="/images/imgXl.gif">
     </a>
  <input type="text" name="extVal" id="extVal"
    class="txt" style="width:100" value="<%=Util.putCommas(extVal)%>">
    <a href="javascript:handleRight();"
      onMouseDown="btnDown(this,'imgXr')"
      onMouseUp="btnUp(this,'imgXr')"
  onMouseOut="btnUp(this,'imgXr')"
  onMouseOver="btnLightup(this, 'imgXr')"
      >
<img border="0"
    width="24"
    height="18"
    alt="Extend view to the right"
    title="Extend view to the right"
    align="absmiddle" name="imgXr" id="imgXr" src="/images/imgXr.gif"></a> &nbsp;
  </td>

    <td class="form_body" align="center" nowrap>
    <a href="javascript:handleNav(<%=xleftFrom%>,<%=xleftTo%>);"
      onMouseDown="btnDown(this,'imgStart')"
      onMouseUp="btnUp(this,'imgStart')"
  onMouseOut="btnUp(this,'imgStart')"
  onMouseOver="btnLightup(this, 'imgStart')"
      >


<img border="0"
    width="24"
    height="18"
    alt="Move view to the start of sequence"
    title="Move view to the start of sequence"
    align="absmiddle" name="imgStart" id="imgStart" src="/images/imgStart.gif"></a>
    <a href="javascript:handleNav(<%=leftFrom%>,<%=leftTo%>);"
      onMouseDown="btnDown(this,'imgFrw')"
      onMouseUp="btnUp(this,'imgFrw')"
  onMouseOut="btnUp(this,'imgFrw')"
  onMouseOver="btnLightup(this, 'imgFrw')"
      >
<img border="0"
    width="24"
    height="18"
    alt="Move view 9/10 screen to the left"
    title="Move view 9/10 screen to the left"
    align="absmiddle" name="imgFrw" id="imgFrw" src="/images/imgFrw.gif"></a>

    <a href="javascript:handleNav(<%=sleftFrom%>,<%=sleftTo%>);"
      onMouseDown="btnDown(this,'imgRw')"
      onMouseUp="btnUp(this,'imgRw')"
  onMouseOut="btnUp(this,'imgRw')"
  onMouseOver="btnLightup(this, 'imgRw')"
      >
<img border="0"
    width="20"
    height="18"
    alt="Move view 1/10 screen to the left"
    title="Move view 1/10 screen to the left"
    align="absmiddle" name="imgRw" id="imgRw" src="/images/imgRw.gif"></a>
  &nbsp;&nbsp;

    <a href="javascript:handleNav(<%=srightFrom%>,<%=srightTo%>);"
      onMouseDown="btnDown(this,'imgFw')"
      onMouseUp="btnUp(this,'imgFw')"
  onMouseOut="btnUp(this,'imgFw')"
  onMouseOver="btnLightup(this, 'imgFw')"
      >
<img border="0"
    width="20"
    height="18"
    alt="Move view 1/10 screen to the right"
    title="Move view 1/10 screen to the right"
    align="absmiddle" name="imgFw" id="imgFw" src="/images/imgFw.gif"></a>


    <a href="javascript:handleNav(<%=rightFrom%>,<%=rightTo%>);"
      onMouseDown="btnDown(this,'imgFfw')"
      onMouseUp="btnUp(this,'imgFfw')"
  onMouseOut="btnUp(this,'imgFfw')"
  onMouseOver="btnLightup(this, 'imgFfw')"
      >

<img border="0"
    width="24"
    height="18"
    alt="Move view 9/10 screen to the right"
    title="Move view 9/10 screen to the right"
    align="absmiddle" name="imgFfw" id="imgFfw" src="/images/imgFfw.gif"></a>


    <a href="javascript:handleNav(<%=xrightFrom%>,<%=xrightTo%>);"
      onMouseDown="btnDown(this,'imgEnd')"
      onMouseUp="btnUp(this,'imgEnd')"
  onMouseOut="btnUp(this,'imgEnd')"
  onMouseOver="btnLightup(this, 'imgEnd')"
      >
<img border="0"
    width="24"
    height="18"
    alt="Move view to the end of sequence"
    title="Move view to the end of sequence"
    align="absmiddle" name="imgEnd" id="imgEnd" src="/images/imgEnd.gif"></a>
    </td>

  <td class="form_body" align="right" nowrap>
    <input type="hidden" name="searchstate" id="searchState" value="0">
    <input type="text" name="searchstr" id="searchstr"  class="txt" style="width:160"   onkeypress="processEvent(event);">
    &nbsp;<input type="submit" name="btnSearch" id="btnSearch"  value="Search" class="btn" style="width:80" onClick="$('searchState').value='1'"> <!-- onClick="TODO" -->
  </td>
  </tr>
</tbody>
</table>

</td>
</tr>
<tr>
<td>

<table width="<%=tableWidth%>" border="0" cellpadding="2" cellspacing="0" align="left">
<tbody>
  <tr>
    <td class="form_body" align="right" nowrap>
  <strong>Zoom In</strong>
<%
  long cRange = (vTo - vFrom);
  long cCenter = (vFrom + vTo + 1L) / 2L;
  long bpRange = (long) (iPictWidth - GbrowserConstants.PICT_BORDER_WIDTH) / 5;
  long bpFrom = cCenter - bpRange / 2;
  if( bpFrom < 1L ) bpFrom = 1L;
  long bpTo = bpFrom + bpRange - 1L;
  boolean need_zoom_out = true;
  for( i=0; i<GbrowserConstants.zoomIds.length; i++ )
  {
    String zoomId = GbrowserConstants.zoomIds[i];
    if( need_zoom_out && zoomId.startsWith("out") )
    {
      if( has_seq )
        {
        %>
            <a href="javascript:handleNav(<%=bpFrom%>,<%=bpTo%>);"
            onMouseDown="btnDown(this,'imgBase')"
            onMouseUp="btnUp(this,'imgBase')"
            onMouseOut="btnUp(this,'imgBase')"
            onMouseOver="btnLightup(this, 'imgBase')"
            >
            <img border="0"
            width="40"
            height="18"
            alt="Zoom In to the basepair level"
            title="Zoom In to the basepair level"
            align="absmiddle" name="imgBase" id="imgBase" src="/images/imgBase.gif"></a> <%
        }
%>
  </td>
  <td class="form_body" style="width:20"></td>
  <td class="form_body" align="left" nowrap><strong>Zoom Out</strong><%
      need_zoom_out = false;
    }
    String aId = GbrowserConstants.zoomLabs[i];
    String imgId = "img"+(need_zoom_out?"In":"Out")+aId;
    long nRange = (cRange * GbrowserConstants.zoomNoms[i]) / GbrowserConstants.zoomDens[i];
    if( nRange < 10 ) nRange = 10;
    long nFrom = cCenter - nRange/2L;
    if( nFrom < vMinFrom ) nFrom = vMinFrom;
    long nTo = nFrom + nRange;
    if( nTo > vMaxTo ) nTo = vMaxTo;
%>
<a href="javascript:handleNav(<%=nFrom%>,<%=nTo%>);"
      onMouseDown="btnDown(this,'<%=imgId%>')"
      onMouseUp="btnUp(this,'<%=imgId%>')"
  onMouseOut="btnUp(this,'<%=imgId%>')"
  onMouseOver="btnLightup(this, '<%=imgId%>')"
      >
<img border="0"
    width="<%
        if(aId.equalsIgnoreCase("1.5X") || aId.equalsIgnoreCase("10X"))
            out.print("36");
        else
            out.print("28");
    %>"
    height="18"
    alt="Zoom <%=need_zoom_out?"In":"Out"%> <%=aId%>"
    title="Zoom <%=need_zoom_out?"In":"Out"%> <%=aId%>"
    align="absmiddle" name="<%=imgId%>" id="<%=imgId%>" src="/images/<%=imgId%>.gif"></a> <%
  }
%>
    <a href="javascript:handleNav(<%=vMinFrom%>,<%=vMaxTo%>);" onMouseDown="btnDown(this,'imgFull')" onMouseUp="btnUp(this,'imgFull')" onMouseOut="btnUp(this,'imgFull')" onMouseOver="btnLightup(this, 'imgFull')">
      <img border="0" width="36" height="18" alt="Zoom Out to the full sequence" title="Zoom Out to the full sequence" align="absmiddle" name="imgFull" id="imgFull" src="/images/imgFull.gif">
    </a>
  </td>
  </tr>
</tbody>
</table>

</td></tr><tr><td>

<table width="100%" border="0" cellpadding="4" cellspacing="0" align="left">
<tbody>
<tr>
<td class="form_body" align="center" valign="middle">
  <div id="chromThumbDiv" style="margin-bottom:5px; margin-left:60px;">
<%
    Connection conn = db.getConnection() ;
    CytoDrawer cytoDrawer = new CytoDrawer() ;
    cytoDrawer.pxWidth = CHROM_THUMB_WIDTH ;
    cytoDrawer.topMargin = CHROM_THUMB_MARGINS[0] ;
    cytoDrawer.bottomMargin = CHROM_THUMB_MARGINS[1] ;
    cytoDrawer.leftMargin = CHROM_THUMB_MARGINS[2] ;
    cytoDrawer.rightMargin = CHROM_THUMB_MARGINS[3] ;
    String landmark = editEP ;
    String cytoThumbImgUrl = cytoDrawer.createCytobandImageUrl(editGroupId, editRefSeqId, landmark, conn) ;
    if(cytoThumbImgUrl != null)
    {
%>
      <img id="chromThumb" src="<%= cytoThumbImgUrl %>" border="0" >
<%  } %>
  </div>
  <div id="bimgDiv">
<%
    vTimeLabs.addElement( "Before the mapFile loop" );
    vTimes.addElement( new java.util.Date() );
// to test the image map    out.println("<!--");
  String stringWithFinalMapFile = processedMapFile.readEntireFile();
  if(userRoleCanEdit == false)
  {
    stringWithFinalMapFile = org.genboree.browser.Utils.removeTracks( stringWithFinalMapFile );
  }
   out.println("" + stringWithFinalMapFile );
   out.flush();

    vTimeLabs.addElement( "After the mapFile loop" );
    vTimes.addElement( new java.util.Date() );
// to test the image map    out.println("-->");
%>
    <img id="bimg" src="<%=locImageName%>?verNum=<%=System.currentTimeMillis()%>" border="0" usemap="#genomeimap" ismap>
  </div>
  </td>
  </tr>
</tbody>
</table>

</td></tr><tr><td>

<table width="<%=tableWidth%>" border="0" cellpadding="2" cellspacing="0" align="left">
<tbody>
  <tr>
    <td class="form_header" align="left" colspan="2">&nbsp;&nbsp;

    <INPUT type="reset" name="btnReset" id="btnReset"
  class="btn" style="width:90" value="Reset">&nbsp;&nbsp;
    <INPUT type="submit" name="btnApply" id="btnApply"
  class="btn" style="width:90" value="Apply">&nbsp;&nbsp;
<% if( is_admin ) { %>
    &nbsp;
    <INPUT type="text" name="savextrack" id="savextrack" size="16" class="txt" value="">
    <INPUT type="submit" name="btnSaveXtrack" id="btnSaveXtrack"
  class="btn" value="Save Track Settings">
<% } %>

    </td>
  </tr>
  <tr>
    <td class="form_body" colspan="2" align="center" nowrap>&nbsp;
      <select name="allTracksVisibility" id="allTracksVisibility" class="txt" onChange="setAllbuttons(this.selectedIndex);">
        <option value="-1">Set Visibility For All Tracks</option>
<%
        vTimeLabs.addElement( "Before the visibilities loop" );
        vTimes.addElement( new java.util.Date() );

        for( i=0; i<GbrowserConstants.tvValues.length; i++ )
        {
          String sel = "";
          String forAll = " All";
          if( i==4 || i==5 )
          {
            forAll = " for All";
          }
          out.println("<option value=\"" + i + "\"" + sel + ((i==2) ? " style=\"background-color:#d3cfe6\">" : ">") + GbrowserConstants.tvValues[i] + forAll + "</option>") ;
        }
%>
      </select>
      &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
      <strong>Picture width: </strong>
      <input type="text" name="pictWidth" id="pictWidth" size="6" class="txt" value="<%=iPictWidth%>">
    </td>
  </tr>
  <tr>
  <td class="form_body" colspan="2" align="center" nowrap>&nbsp;

  <input type="checkbox" name="displayEmptyTracks" id="displayEmptyTracks" value="1"<%=displayEmptyTracks%>><strong>Display empty tracks</strong>

  &nbsp;&nbsp;&nbsp;&nbsp;
 <input type="checkbox" name="drawInMargin" id="drawInMargin" value="1"<%=drawInMargin%>><strong>Indicate continuations?</strong>
  &nbsp;&nbsp;&nbsp;&nbsp;
 <input type="checkbox" name="displayTrackDesc" id="displayTrackDesc" value="1"<%=displayTrackDesc%>><strong>Display track descriptions</strong>

 </td>
 </tr>

  <tr><td colspan="2" class="form_header" style="height:2"></td></tr>
  <tr><td colspan="2" class="form_body" style="height:2"></td></tr>
  <tr>
  <td class="form_body" colspan="2">
  <table id="tracksByClassTable" name="tracksByClassTable" width="100%" border="0">
<%
    Arrays.sort(classes) ;
    trackVisibilityMenus = GBrowserUtils.generateMenus(dbFtypesByClass, trackView, userRoleCanEdit) ;
    if(trackVisibilityMenus != null)
    {
      out.print(trackVisibilityMenus) ;
    }
%>
    <tr>
      <td bgcolor="#847AB9" align="center" colspan="4"> &nbsp;</td>
    </tr>
  </table>
  </td>
  </tr>

  <tr>
    <td colspan="2" class="form_header">
  &nbsp;&nbsp;
    <INPUT type="submit" name="back" id="back" class="btn" style="width:80" value="Back">
  &nbsp;&nbsp;
    <INPUT type="submit" name="btnApply" id="btnApply" class="btn" style="width:80" value="Apply">
<% if( !is_public ) { %>
  &nbsp;&nbsp;
    <INPUT type="submit" name="btnSaveDisplay" id="btnSaveDisplay" class="btn" style="width:80" value="Save">
    &nbsp;&nbsp;
    <INPUT type="submit" name="loadDefaultDisplay" id="loadDefaultDisplay" class="btn" style="width:80" value="Load Default">
<% } %>
<% if( is_db_owner ) { %>
  &nbsp;&nbsp;
    <INPUT type="submit" name="btnSaveDefaultDisplay" id="btnSaveDefaultDisplay"
    class="btn" value="Save As Default">
<% } %>
<%   if( __is_admin) { %>
  &nbsp;&nbsp;
    <INPUT type="submit" name="btnClearCache" id="btnClearCache"
    class="btn" value="Clear Cache">
   <% } %>
  </td>
  </tr>
</tbody>
</table>
</td>
</tr>
</table>
</form>
</td></tr>
</table>

<form class="no_margins" name="getdefaultBrowserForm" action="defaultGbrowser.jsp" method="put" >
<input type="hidden" name="groupId" id="newGroupId" value="">
<input type="hidden" name="refSeqId" id="newRefSeqId" value="">
</form>

<form class="no_margins" name="getdefaultPublicBrowserForm" action="defaultGbrowser.jsp" method="put" >
<input type="hidden" name="refSeqId" id="newRefSeqId" value="">
</form>

<% if( has_seq ) { %>
<form class="no_margins" id="getdnaform" name="getdnaform" action="downloadGenomicDNA.jsp" method="get" target="_newWin">
  <input type="hidden" name="refSeqId" id="getDNArefSeqId" value="<%=viewRefSeqId%>">
  <input type="hidden" name="refName" id="getDNArefName" value="<%=viewEP%>">
    <input type="hidden" name="stop" id="getDNAstop" value="<%=viewStop%>">
  <input type="hidden" name="start" id="getDNAstart" value="<%=viewStart%>">
    <!--
chrName = document.getElementById('entryPointIdSelection').value ;
start = document.getElementById('entryPointFrom').value;
stop = document.getElementById('entryPointTo').value;
-->
</form>
<% } %>
<form class="no_margins" id="dnld" name="dnld" action="download.jsp" method="post">
  <input type="hidden" name="refSeqId" id="refSeqId" value="<%=viewRefSeqId%>">
  <input type="hidden" name="entryPointId" id="entryPointId" value="<%=viewEP%>">
  <input type="hidden" name="from" id="from" value="<%=viewStart%>">
  <input type="hidden" name="to" id="to" value="<%=viewStop%>">
</form>
<%
// Don't move the javascript libraries from this location. They don't work in other places ???.
%>
<script type="text/javascript" src="/javaScripts/gbrowser.js<%=jsVersion%>"></script>
<script type="text/javascript" src="/javaScripts/popl.js<%=jsVersion%>"></script>
<%@ include file="include/footer.incl" %>

</BODY>
</HTML>

<!--
<%
    // Read in timingAllowedUsers from config file, get userIds as keys (Strings) of a HashMap
    HashMap<String,Boolean> timingAllowedUsers = GenboreeConfig.getHashFromListConfigParam("timingAllowedUsers") ;

    if(__is_admin || timingAllowedUsers.containsKey(userInfo[2]))
    {
        vTimeLabs.addElement( "After printing HTML" );
        vTimes.addElement( new java.util.Date() );

        java.util.Date d1 = (java.util.Date) vTimes.elementAt(0);

        out.println( "Started at: " + d1.toString() );
        out.println();

        java.util.Date d2 = null;
        for( i=1; i<vTimes.size(); i++ )
        {
            d2 = (java.util.Date) vTimes.elementAt(i);
            String lab = (String) vTimeLabs.elementAt(i);
            long td = (d2.getTime() - d1.getTime()) / 100;
            out.println( lab + ": " + (td/10)+"."+(td%10)+" s" );
            d1 = d2;
        }
        out.println(errorStringCProgram.toString());
        out.println();
        out.println( "Finished at: " + d2.toString() );

        if( vDebug.size() > 0 )
        {
            out.println();
            out.println( "Trace info:" );
            for( i=0; i<vDebug.size(); i++ )
            {
                out.println( Util.htmlQuote((String)vDebug.elementAt(i)) );
            }
        }
    }
%>
-->
