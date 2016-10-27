<%@ page import="org.genboree.dbaccess.GenboreeGroup,
                 java.util.*,
                 java.io.*,
                 org.genboree.message.GenboreeMessage,
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
                 org.json.JSONArray"
        %>
<%@ page import="org.genboree.editor.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/group.incl" %>
<%@ include file="include/sessionGrp.incl" %>
<%@ include file="include/pageInit.incl" %>


<%!
  public static Chromosome findChromosome( Connection con, String chrName )
  {
    Chromosome chromosome = null;
    String sql = "select rid, rlength  from fref where refname = ? ";
    try
    {
      PreparedStatement stms = con.prepareStatement( sql );
      stms.setString( 1, chrName );
      ResultSet rs = stms.executeQuery();
      if( rs.next() )
      {
        chromosome = new Chromosome( rs.getInt( 1 ) );
        chromosome.setLength( rs.getLong( 2 ) );
        chromosome.setRefname( chrName );
      }
    }
    catch( Exception e )
    {
      e.printStackTrace();
    }

    return chromosome;

  }
%>
<%
  boolean ascendingSort = true;
  int numSortNames = 0;
  int currentIndex = 0;
  HashMap trackNameMap = new HashMap();
  String[] localtracks = null;
  String[] sharedTracks = null;
  HashMap shareTrack2Ftypes = null;
  String invalidTracks = "";
  response.addDateHeader( "Expires", 0L );
  response.addHeader( "Cache-Control", "no-cache, no-store" );
  GenboreeMessage.clearMessage( mys );
  String totalCount = "0";
  String orderedSortNames[] = null;
  String displayNames[] = null;
  int[] localftypeids = null;
  int[] shareftypeids = null;
  AnnotationDetail[] localAnnotations = null;
  AnnotationDetail[] sharedAnnotations = null;
  boolean recurPage = request.getParameter( "navigator" ) != null;
  boolean fromSelection = request.getParameter( "viewData" ) != null;
  boolean hasMode = request.getParameter( "mode" ) != null;
  HashMap shareddb2Ftypes = null;
  boolean hasSharedTrack = false;
  String[] avpDisplayNames = null;
  String selectedTrackNames[] = null;
  if( request.getParameter( "bk2display" ) != null && request.getParameter( "bk2display" ).equals( "1" ) )
  {
    String restrictChr = ( String )mys.getAttribute( "restrictRegion" );

    LffUtility.clearCache( mys );
    GenboreeUtils.sendRedirect( request, response, "/java-bin/displaySelection.jsp?fromUrl=true" );
    return;
  }


  boolean sortingColumns = false;
  String sortingColumnName = request.getParameter( "sortingColumnName" );
  if( sortingColumnName != null )
  {
    sortingColumnName = sortingColumnName.trim();
    sortingColumnName = Util.urlDecode( sortingColumnName );
  } else
  {
    mys.removeAttribute( "sortingByColumnName" );

  }

  boolean restrictRegion = false;
  int rid = -1;
  long chrStart = -1;
  long chrStop = -1;
  String urlLayout = request.getParameter( "layoutName" );  // handled
  String urlTrakNames = request.getParameter( "trackNames" );

  Map paramMap = request.getParameterMap();
  String urlRefseqId = ( request.getParameter( "refSeqId" ) != null ) ? ( request.getParameter( "refSeqId" ) ) : ( request.getParameter( "refseqid" ) );
  String chrName = request.getParameter( "chrName" );


  Chromosome chromosome = null;
  String startString = request.getParameter( "start" );
  String stopString = request.getParameter( "stop" );

  if( startString != null )
  {
    startString = startString.trim();
    startString = startString.replaceAll( ",", "" );
    if( startString.length() > 0 )
      chrStart = Long.parseLong( startString );
    //return;
  }

  if( stopString != null )
  {
    stopString = stopString.trim();

    stopString = stopString.replaceAll( ",", "" );
    if( stopString.length() > 0 )
      chrStop = Long.parseLong( stopString );
  }

  if( ( startString != null && stopString != null ) && chrName == null )
  {

    GenboreeMessage.setErrMsg( mys, "The start and stop parameters were provided without the chrName \n" +
            "parameter that indicates which chromosome/scaffold/etc the start and " +
            "stop coordinates are on. <br>" +
            "- This is incorrect.<br>" +
            "- Currently the whole track is selected." );

    GenboreeUtils.sendRedirect( request, response, "/java-bin/displaySelection.jsp?fromUrl=true &showAll=true" );
    return;

  }


  if( ( startString != null ) && chrName == null )
  {
    GenboreeMessage.setErrMsg( mys, "The start parameters was provided without the chrName \n" +
            "parameter that indicates which chromosome/scaffold/etc the start and " +
            "stop coordinates are on. <br>" +
            "- This is incorrect.<br>" +
            "- Currently the whole track is selected." );
    GenboreeUtils.sendRedirect( request, response, "/java-bin/displaySelection.jsp?fromUrl=true &showAll=true" );
    return;
  }


  if( stopString != null && chrName == null )
  {

    GenboreeMessage.setErrMsg( mys, "The stop parameters was provided without the chrName \n" +
            "parameter that indicates which chromosome/scaffold/etc the start and " +
            "stop coordinates are on. <br>" +
            "- This is incorrect.<br>" +
            "- Currently the whole track is selected." );


    GenboreeUtils.sendRedirect( request, response, "/java-bin/displaySelection.jsp?fromUrl=true &showAll=true" );
    return;
  }
  // Guess user provided  refseqid  if user does not provide refseqid and refSeqId
  // refseqid is checked because there will be no error catched if session has one
  String invalidurlparam = null;
  if( paramMap != null && urlRefseqId == null )
  {
    Set keySet = paramMap.keySet();
    if( keySet != null )
    {
      Iterator iterator = keySet.iterator();
      while( iterator.hasNext() )
      {
        String key = ( String )iterator.next();
        if( key.compareToIgnoreCase( "trackNames" ) == 0 )
          continue;
        else if( key.compareToIgnoreCase( "layoutName" ) == 0 )
          continue;
        else if( key.compareToIgnoreCase( "refseqid" ) == 0 )
        {
          urlRefseqId = request.getParameter( key );
          continue;
        } else if( key.compareToIgnoreCase( "chrName" ) == 0 )
        {
          if( chrName == null )
            chrName = request.getParameter( key );
        } else if( key.compareToIgnoreCase( "entryPointId" ) == 0 )
        {
          if( chrName == null )
            chrName = request.getParameter( key );
        } else if( key.compareToIgnoreCase( "start" ) == 0 )
        {
          if( startString == null )
            startString = request.getParameter( key );
        } else if( key.compareToIgnoreCase( "from" ) == 0 )
        {
          if( startString == null )
            startString = request.getParameter( key );
        } else if( key.compareToIgnoreCase( "stop" ) == 0 )
        {
          if( stopString == null )
            stopString = request.getParameter( key );
        } else if( key.compareToIgnoreCase( "to" ) == 0 )
        {
          if( stopString == null )
            stopString = request.getParameter( key );
        } else
        {
          // extra params : not trackNames, not layoutName, not refseqid
          if( invalidurlparam == null )
            invalidurlparam = key;
          else
            invalidurlparam = invalidurlparam + ", " + key;
        }
      }
    }
  }

  // if still not right, send error message
  if( paramMap != null && paramMap.size() > 6 && urlRefseqId == null )
  {
    if( urlLayout != null && urlTrakNames != null && invalidurlparam != null )
    {
      GenboreeMessage.setErrMsg( mys, "Parameter \"" + invalidurlparam + "\" is not valid in URL" );
      GenboreeUtils.sendRedirect( request, response, "/java-bin/displaySelection.jsp?fromUrl=true" );
    }
    return;
  }


  if( urlTrakNames != null && urlLayout != null )
  {
    currentPageIndex = 0;
    currentPage = "0";
    initPage = true;
    mys.setAttribute( "lastPageIndex", "0" );
    mys.removeAttribute( "lastStartPageNum" );
    mys.removeAttribute( "lastEndPageNum" );
    mys.setAttribute( "lastStartPageNum", "" + 0 );
    mys.removeAttribute( "sortingColumnOrder" );
    initPage = true;
  }
  if( initPage )
  {
    mys.removeAttribute( "restrictRegion" );
    mys.removeAttribute( "displayChromosome" );
  }

  if( chrName != null && chrName.indexOf( "Show" ) < 0 )
  {
    restrictRegion = true;
    mys.setAttribute( "restrictRegion", "true" );
  } else if( chrName != null && chrName.indexOf( "Show" ) >= 0 )
  {
    mys.setAttribute( "restrictRegion", "false" );
  } else if( chrName == null )
  {
    restrictRegion = false;
    mys.setAttribute( "restrictRegion", "false" );
    mys.setAttribute( "displayChromosome", LayoutHelper.ALL_CHROMOSOMES );
  }
  String sortingColumnOrder = request.getParameter( "sortingColumnOrder" );
  String sortingArrow = "&nbsp;";
  if( sortingColumnOrder != null && sortingColumnOrder.length() > 0 )
  {
    if( sortingColumnOrder.equals( "up" ) )
      sortingArrow = "&uarr;";
    else if( sortingColumnOrder.equals( "down" ) )
    {
      sortingArrow = "&darr;";
      ascendingSort = false;
    }
    mys.setAttribute( "sortingColumnOrder", sortingColumnOrder );
  }

  if( sortingColumnOrder != null && sortingColumnOrder.length() > 0 )
  {
    sortingColumns = true;
    //mys.setAttribute("sortingByColumnName", "y");
  }
  String[] avpNames = null;
  ArrayList avpDisplayNameList = new ArrayList();
  ArrayList avpSortNameList = new ArrayList();
  AnnotationDetail[] newannos = null;
  int numLocalAnnos = 0;
  int numShareAnnos = 0;
  int uploadId = 0;
  String[] alltracks = null;
  // initialization
  int totalNumAnnotations = 0;
  dispNum = new int[]{ 20, 25, 50, 100, 200 };
  String[] fdataSortNames = null;
  HashMap nameid2values = null;
  HashMap valueid2values = null;
  int[] attNameIds = null;
  boolean hasData = false;
  boolean isLargeSamples = false;
  String fidAttributes[][] = null;
  String localfidAttributes[][] = null;
  String sharefidAttributes[][] = null;
  displayNum = 50;
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
  for( int i = 0; i < LffConstants.LFF_COLUMNS.length; i++ )
    lffNameArrayList.add( LffConstants.LFF_COLUMNS[ i ] );
  LffConstants.setHash();
  String sharedbName = null;
  //  String []   fids  = null;
  String[] sharefids = null;
  int[] shareFids = null;
  String[] localfids = null;
  ArrayList lffAttributes = null;
  ArrayList avpAttributes = new ArrayList();
  ArrayList allLffColumns = new ArrayList();
  for( int i = 0; i < org.genboree.tabular.LffConstants.LFF_COLUMNS.length; i++ )
    allLffColumns.add( org.genboree.tabular.LffConstants.LFF_COLUMNS[ i ] );
  String dbName = null;
  Connection con = null;
  Connection sharedConnection = null;
  HashMap localfid2hash = null;
  HashMap sharefid2hash = null;
  AnnotationDetail[] annotations = null;
  AnnotationDetail[] totalAnnotations = null;
  boolean hasInvalidParams = false;
  boolean isFromLayoutURL = false;
  URLParams params = null;
  int tooFewForMenuBtn = 29;
  int tooManyForMenuBtn = 150;
  int i = 0;
  ArrayList lffSortNameList = new ArrayList();
  HashMap order2Att = new HashMap();
  int mode = -1;
  Refseq rseq = null;
  HashMap localftypeid2Gclass = null;
  HashMap shareftypeid2Gclass = null;
  boolean noAttributeSelected = false;
  String viewDisplay = "block";
  String[] dbNames = null;
  // trackNames is handled below

  if( chrName != null && restrictRegion )
  {
    chromosome = new Chromosome( chrName );
    if( startString == null )
      chrStart = 1;
    chromosome.setStart( chrStart );
    chromosome.setStop( chrStop );

    mys.setAttribute( "displayChromosome", chromosome );
    //return;
  } else
  {
    if( initPage )
    {  // this set
      mys.removeAttribute( "displayChromosome" );
    } else
    {
      if( mys.getAttribute( "displayChromosome" ) != null )
      {
        chromosome = ( Chromosome )mys.getAttribute( "displayChromosome" );
        if( chromosome != null )
        {
          rid = chromosome.getId();
          chrStart = chromosome.getStart();
          chrStop = chromosome.getStop();
        }
      }
    }
  }
  HashMap urlTrackMap = new HashMap();
  if( urlLayout != null || urlTrakNames != null )
  {
    String trackNamesStr = request.getParameter( "trackNames" ) ;
    params = new URLParams();
    params.setLayoutName( urlLayout );
    params.setTrackNames( trackNamesStr );
    // This should not be necessary...doing request.getParameter -automatically- URL escapes
    // Only time this is needed is when we are double encoding...which sometimes we do
    // to hand args on the command line safely (if value is encoded, it gets double encoded during
    // this procedure.)
    //params.decode();
    // There is a side effect in decode() to set the tracksStringArr, so do it here:
    params.parseTracks(trackNamesStr) ;
    if( params.getTrackNameArr() != null )
    {
      selectedTrackNames = params.getTrackNameArr();

      for( i = 0; i < selectedTrackNames.length; i++ )
        urlTrackMap.put( selectedTrackNames[ i ], "y" );
    }
    mys.setAttribute( "urlParams", params );
  }

  boolean hasValidLayout = true;
  boolean hasValidTracks = true;
  boolean hasValidRefseqId = true;
  boolean hasErrorParams = false;
  boolean missingLayout = false;
  boolean missingTracks = false;

  int annoLimit = 300000;
  int avpLimit = 1000000;
  int localNumAnnotations = 0;
  int shareNumAnnotations = 0;
  int localAVPAssociationCount = 0;
  int shareAVPAssociationCount = 0;
  String groupMode = null;
  if( urlLayout == null && !recurPage )
  {
    hasErrorParams = true;
    missingLayout = true;
  }
  //   case2; validating track id

  // missing parameter trackNames
  if( request.getParameter( "trackNames" ) == null )
  {
    mys.removeAttribute( "localftypeids" );
    mys.removeAttribute( "shareftypeids" );
    mys.removeAttribute( "selectedTrackHash" );
    mys.setAttribute( "sessionLayout", urlLayout );
    hasErrorParams = true;
    mys.removeAttribute( "urlParams" );
    missingTracks = true;
  }

  String nava = request.getParameter( "navigator" );
  if( missingTracks && missingLayout && !recurPage )
  {
    ArrayList errMsgList = new ArrayList();
    errMsgList.add( "\"trackNames\" parameter missing in URL" );
    errMsgList.add( "\"layoutName\" parameter missing in URL" );
    if( ( SessionManager.getSessionDatabaseId( mys ) == null ) && urlRefseqId == null )
    {
      errMsgList.add( "\"refSeqId\" parameter missing in URL" );
    }
    GenboreeMessage.setErrMsg( mys, "Insufficient parameters provided to direct table link. ", errMsgList );
    GenboreeUtils.sendRedirect( request, response, "/java-bin/displaySelection.jsp?fromUrl=true" );
    return;
  }

  // case 3
  // if (!missingLayout  && !missingTracks) {
  if( urlRefseqId != null )
  {
    int error = SessionManager.setSessionDatabaseIdHard( mys, urlRefseqId, db );
    if( error == SessionManager.NO_ERROR )
    {
      groupId = SessionManager.getSessionGroupId( mys );
      rseq_id = urlRefseqId;

      if( groupId == null )
      {
        hasValidRefseqId = false;
        GenboreeMessage.setErrMsg( mys, "Please select a database " );
        GenboreeUtils.sendRedirect( request, response, "/java-bin/displaySelection.jsp?fromUrl=true" );
        return;
      }

      GenboreeGroup cgrp = null;
      for( i = 0; i < rwGrps.length; i++ )
      {
        cgrp = rwGrps[ i ];

        if( cgrp.getGroupId().equals( groupId ) )
          grp = cgrp;
      }

//			rseqs = (Refseq[]) mys.getAttribute("RefSeqs");
      rseqs = Refseq.fetchAll( db, rwGrps );

      //  String[] groupRefseqs  = grp.getRefseqs();
      ArrayList rslist = new ArrayList();
      Refseq rs = null;
      for( i = 0; i < rseqs.length; i++ )
      {
        rs = rseqs[ i ];
        if( grp.belongsTo( rs.getRefSeqId() ) )
          rslist.add( rs );
      }
      rseqs = ( Refseq[] )rslist.toArray( new Refseq[rslist.size()] );
      if( rseq_id != null )
      {
        boolean isValidRefseqId = false;
        for( i = 0; i < rseqs.length; i++ )
        {
          if( rseqs[ i ].getRefSeqId().equals( rseq_id ) )
          {
            rseq = rseqs[ i ];
            isValidRefseqId = true;
            break;
          }
        }

        if( !isValidRefseqId )
        {
          GenboreeMessage.setErrMsg( mys, "Refseq id: " + rseq_id + " is not valid. " );
          GenboreeUtils.sendRedirect( request, response, "/java-bin/displaySelection.jsp?fromUrl=true" );
        }
      }
    } else
    {
      hasErrorParams = true;
      hasValidRefseqId = false;
    }
  } else
  {
    // check if session has refseq id
    rseq_id = SessionManager.getSessionDatabaseId( mys );
    if( rseq_id == null )
    {   // not  has database session
      hasValidRefseqId = false;
      hasErrorParams = true;
    } else
    {   // in session , validating
      int error = SessionManager.setSessionDatabaseIdHard( mys, rseq_id, db );
      if( error == SessionManager.NO_ERROR )
      {
        groupId = SessionManager.getSessionGroupId( mys );
        if( groupId == null )
        {
          hasErrorParams = true;
          hasValidRefseqId = false;
          SessionManager.clearSessionDatabase( mys );
          GenboreeMessage.setErrMsg( mys, "There is no database in the group. " );
          GenboreeUtils.sendRedirect( request, response, "/java-bin/displaySelection.jsp?fromUrl=true" );
        } else
        {
          GenboreeGroup cgrp = null;
          for( i = 0; i < rwGrps.length; i++ )
          {
            cgrp = rwGrps[ i ];
            if( cgrp.getGroupId().equals( groupId ) )
              grp = cgrp;
          }

//          rseqs = (Refseq[]) mys.getAttribute("RefSeqs");
          rseqs = Refseq.fetchAll( db, rwGrps );
          //  String[] groupRefseqs  = grp.getRefseqs();
          ArrayList rslist = new ArrayList();
          Refseq rs = null;
          for( i = 0; i < rseqs.length; i++ )
          {
            rs = rseqs[ i ];
            if( grp.belongsTo( rs.getRefSeqId() ) )
              rslist.add( rs );
          }
          rseqs = ( Refseq[] )rslist.toArray( new Refseq[rslist.size()] );
          if( rseq_id != null )
          {
            boolean isValidRefseqId = false;
            for( i = 0; i < rseqs.length; i++ )
            {
              if( rseqs[ i ].getRefSeqId().equals( rseq_id ) )
              {
                rseq = rseqs[ i ];
                isValidRefseqId = true;
                break;
              }
            }

            if( !isValidRefseqId )
            {
              GenboreeMessage.setErrMsg( mys, "Refseq id: " + rseq_id + " is not valid. " );
              GenboreeUtils.sendRedirect( request, response, "/java-bin/displaySelection.jsp?fromUrl=true" );
            }
          }
        }
      } else
      {

        hasErrorParams = true;
        hasValidRefseqId = false;
      }
    }
  }

  String selectedView = urlLayout;
  mys.setAttribute( "sessionLayout", selectedView );
int genboreeUserId = Util.parseInt( myself.getUserId(), -1 );

  JSONObject json = null;
  boolean isDefaultLayout = false;
  String jsonString = null;
  if( selectedView != null )
  {
    if( selectedView.indexOf( "Default Group" ) >= 0 )
    {
      json = new JSONObject( LayoutHelper.JSON_DF_GROUP );
      mys.setAttribute( "sessionLayout", LayoutHelper.DEFAULT_GROUPED_ANNOS );

    } else if( selectedView.indexOf( "Default All" ) >= 0 )
    {
      json = new JSONObject( LayoutHelper.JSON_DF_ALL );
      mys.setAttribute( "sessionLayout", LayoutHelper.DEFAULT_ALL_ANNOS );

    }
    if( json != null )
    {
      isDefaultLayout = true;
      mys.setAttribute( "urlJson", json );
    }
  }
  if( !isDefaultLayout && !missingLayout && hasValidRefseqId )
  {
    mys.setAttribute( "sessionLayout", selectedView );
    if( selectedView != null )
    {
      String parentPath = org.genboree.upload.LffConstants.ROOTDIR_ANNOTATION_TABLE_VIEW + "/annoTableViews"
              + "/" + groupId + "/" + rseq_id;
      String errMsg = null;

      try
      {
        json = LayoutHelper.retrievesJsonObject( parentPath, selectedView );
      }
      catch( ViewRetrieveException e )
      {
        hasValidLayout = false;
        errMsg = e.getMessage();
        if( errMsg.indexOf( "Error2" ) >= 0 )
          GenboreeMessage.setErrMsg( mys, "Error in retrieving saved layout from refseq id: " + urlRefseqId );
        else if( errMsg.indexOf( "Error3" ) >= 0 )
          GenboreeMessage.setErrMsg( mys, "Error in retrieving saved layout from layout: " + urlLayout );

        json = null;
      }

      if( json == null )
      {
        hasErrorParams = true;
        hasValidLayout = false;
        mys.removeAttribute( "localftypeids" );
        mys.removeAttribute( "shareftypeids" );
      }
    }
    mys.setAttribute( "urlJson", json );
  }

  // validate tracks
  if( !missingTracks && hasValidRefseqId )
  {
    isFromLayoutURL = true;
    // case 1
    if( rseqs == null || rseqs.length == 0 )
    {
      GenboreeMessage.setErrMsg( mys, "Sorry, there is no database in this group. <br> -- Please create a database and try again." );
      GenboreeUtils.sendRedirect( request, response, "/java-bin/displaySelection.jsp?fromUrl=true" );
    } else
    { //   == (rseqs != null && rseqs.length >0) {
      boolean isValidRefseqId = false;
      if( rseq_id != null )
      {
        for( i = 0; i < rseqs.length; i++ )
        {
          if( rseqs[ i ].getRefSeqId().equals( rseq_id ) )
          {
            rseq = rseqs[ i ];
            isValidRefseqId = true;
            break;
          }
        }

        if( !isValidRefseqId )
        {
          GenboreeMessage.setErrMsg( mys, "Refseq id: " + rseq_id + " is not valid. " );
          GenboreeUtils.sendRedirect( request, response, "/java-bin/displaySelection.jsp?fromUrl=true" );
          return;
        }
      }

      if( rseq != null )
      {
        // set dbname and conncetions \
        dbName = rseq.getDatabaseName();


        dbNames = rseq.fetchDatabaseNames( db );
        mys.setAttribute( "dbNames", dbNames );

        mys.setAttribute( Constants.SESSION_DATABASE_NAME, dbName );
        mys.setAttribute( Constants.SESSION_DATABASE_ID, rseq_id );

        ///SessionManager.setSessionDatabaseName(mys, dbName);
        //SessionManager.setSessionDatabaseIdHard(mys, rseq_id);

        for( i = 0; i < dbNames.length; i++ )
        {
          if( !dbNames[ i ].equals( dbName ) )
            sharedbName = dbNames[ i ];
        }
        con = db.getConnection( dbName );

        if( sharedbName != null )
        {
          sharedConnection = db.getConnection( sharedbName );
          sharedTracks = Utility.retrieveTrackNames( sharedConnection, sharedbName, genboreeUserId );
        }

        if( con != null )
        {
          localtracks = Utility.retrieveTrackNames( con, dbName, genboreeUserId );
        }
        if( localtracks != null )
        {
          for( i = 0; i < localtracks.length; i++ )
            trackNameMap.put( localtracks[ i ], "y" );
        }
        if( sharedTracks != null )
        {
          for( i = 0; i < sharedTracks.length; i++ )
            trackNameMap.put( sharedTracks[ i ], "y" );
        }
        String[] urlTracks = null;
        if( params.getTrackNameArr() != null )
          urlTracks = params.getTrackNameArr();


        for( i = 0; i < urlTracks.length; i++ )
        {
          if( trackNameMap.get( urlTracks[ i ] ) == null )
          {
            invalidTracks = invalidTracks + urlTracks[ i ] + ",";
          }
        }
        if( invalidTracks.length() > 1 )
          invalidTracks = invalidTracks.substring( 0, invalidTracks.length() - 1 );
        else
          invalidTracks = null;
        if( invalidTracks != null )
        {
          hasErrorParams = true;
          hasValidTracks = false;
        }
      } else
      {  // don't have valid rseq
        GenboreeMessage.setErrMsg( mys, "Refseq id: " + rseq_id + " is not valid. " );
        GenboreeUtils.sendRedirect( request, response, "/java-bin/displaySelection.jsp?fromUrl=true" );
      }
    }
  }
  if( con != null && chrName != null )
  {
    Chromosome temp = findChromosome( con, chrName );
    if( temp == null )
    {
      GenboreeMessage.setErrMsg( mys, "Chrosome name: " + chrName + " is not valid. " );
      GenboreeUtils.sendRedirect( request, response, "/java-bin/displaySelection.jsp?fromUrl=true" );
      return;
    }

    rid = temp.getId();
    long chrLength = temp.getLength();

    if( rid <= 0 )
    {
      GenboreeMessage.setErrMsg( mys, "Chrosome name: " + chrName + " is not valid. " );
      GenboreeUtils.sendRedirect( request, response, "/java-bin/displaySelection.jsp?fromUrl=true" );
      return;
    }


    if( startString != null && chrStart <= 0 )
    {
      GenboreeMessage.setErrMsg( mys, "Chrosome start: " + chrName + " is not valid. " );
      GenboreeUtils.sendRedirect( request, response, "/java-bin/displaySelection.jsp?fromUrl=true" );
      return;

    }


    if( stopString != null && chrStop > chrLength )
    {
      GenboreeMessage.setErrMsg( mys, "Chrosome stop: " + stopString + " is not valid. " );
      GenboreeUtils.sendRedirect( request, response, "/java-bin/displaySelection.jsp?fromUrl=true" );
      return;
    }
    if( stopString == null )
    {
      chromosome.setStop( chrLength );
      chrStop = chrLength;

    }
    chromosome.setId( rid );
  }
  ArrayList errMsgList = new ArrayList();
  if( hasErrorParams )
  {
    int count = 0;
    if( missingTracks )
    {
      errMsgList.add( "\"trackNames\" parameter missing in URL" );
      count++;
      mys.removeAttribute( "selectedTrackHash" );
      errMsgList.add( "please select a track below" );

    }


    if( missingLayout )
    {
      count++;
      errMsgList.add( "\"layoutName\" parameter missing in URL" );
      if( count == 1 )
        errMsgList.add( "please select a layout below" );

    }

    if( !hasValidTracks )
    {
      mys.removeAttribute( "selectedTrackHash" );
      mys.removeAttribute( "urlParams" );
      count++;
      errMsgList.add( "the track name \"" + urlTrakNames + "\" does not exist." );
      if( count == 1 )
        errMsgList.add( "please select a track below" );
      else if( count > 1 )
      {
        errMsgList.remove( 1 );
      }

    }

    if( !hasValidLayout )
    {
      count++;
      errMsgList.add( " the layout name \"" + urlLayout + "\" does not exist." );
      if( count == 1 )
        errMsgList.add( "please select a layout below" );

      else if( count > 1 )
      {
        errMsgList.remove( 1 );
      }
    }

    if( !hasValidRefseqId )
    {
      count++;
      if( urlRefseqId == null )
      {
        errMsgList.add( "\"refSeqId\" parameter missing in URL." );
        if( count == 1 )
          errMsgList.add( "please select a database below" );
      } else
      {
        errMsgList.add( "refSeqId: \"" + urlRefseqId + "\" does not exist" );
        if( count == 1 )
          errMsgList.add( "please select a database below" );
        else if( count == 2 )
        {
          errMsgList.remove( 1 );
        }
      }
    }

    if( count == 1 )
    {
      GenboreeMessage.setErrMsg( mys, "One of the parameters to this page is not valid: ", errMsgList );
    } else
    {
      String countWord = "Two";
      if( count == 3 )
        countWord = "Three";

      if( count > 1 && missingTracks )
        errMsgList.remove( 1 );

      GenboreeMessage.setErrMsg( mys, countWord + " of the parameters to this page are not valid: ", errMsgList );
    }
    GenboreeUtils.sendRedirect( request, response, "/java-bin/displaySelection.jsp?fromUrl=true" );
    return;
  }
  // init page
  if( urlLayout != null && urlTrakNames != null )
  {
    if( rseqs == null || rseqs.length == 0 )
    {
      GenboreeMessage.setErrMsg( mys, "Sorry, there is no database in this group. <br> -- Please create a database and try again." );
      GenboreeUtils.sendRedirect( request, response, "/java-bin/displaySelection.jsp?fromUrl=true" );
    } else
    { //   == (rseqs != null && rseqs.length >0) {
      if( rseq == null )
      {
        GenboreeMessage.setErrMsg( mys, "Please select a database " );
        GenboreeUtils.sendRedirect( request, response, "/java-bin/displaySelection.jsp?fromUrl=true" );
      }
    }
    // start of controoler

    mys.setAttribute( "layoutSharedDbName", sharedbName );
    mys.setAttribute( "URLParams", params );
    selectedTrackNames = params.getTrackNameArr();
    if( selectedTrackNames != null )
    {
      HashMap selectedTrackHash = new HashMap();
      for( i = 0; i < selectedTrackNames.length; i++ )
      {
        selectedTrackHash.put( selectedTrackNames[ i ], "y" );
        mys.setAttribute( "selectedTrackHash", selectedTrackHash );
      }

      HashMap localftype2ftypeIds = null;
      if( con != null )
        localftype2ftypeIds = Utility.retrieveFtype2ftypeId( con, dbName, genboreeUserId );
      HashMap shareftype2ftypeIds = null;
      ArrayList localTrackList = new ArrayList();
      ArrayList shareTrackList = new ArrayList();
      if( sharedConnection != null )
        shareftype2ftypeIds = Utility.retrieveFtype2ftypeId( sharedConnection, sharedbName, genboreeUserId );
      String id = null;
      for( i = 0; i < selectedTrackNames.length; i++ )
      {
        if( localftype2ftypeIds != null && localftype2ftypeIds.get( selectedTrackNames[ i ] ) != null )
          localTrackList.add( selectedTrackNames[ i ] );
        if( shareftype2ftypeIds != null && shareftype2ftypeIds.get( selectedTrackNames[ i ] ) != null )
          shareTrackList.add( selectedTrackNames[ i ] );
      }

      if( !localTrackList.isEmpty() )
      {
        localftypeids = new int[localTrackList.size()];
        for( i = 0; i < localTrackList.size(); i++ )
        {
          String trackName = ( String )localTrackList.get( i );
          id = ( String )localftype2ftypeIds.get( trackName );
          localftypeids[ i ] = Integer.parseInt( id );
        }
      }

      if( !shareTrackList.isEmpty() )
      {
        shareftypeids = new int[shareTrackList.size()];
        for( i = 0; i < shareTrackList.size(); i++ )
        {
          String trackName = ( String )shareTrackList.get( i );
          id = ( String )shareftype2ftypeIds.get( trackName );
          shareftypeids[ i ] = Integer.parseInt( id );
        }
      }
      mys.setAttribute( "localftypeids", localftypeids );
      mys.setAttribute( "shareftypeids", shareftypeids );
    }  // selected reack name snot null


    if( localftypeids == null && mys.getAttribute( "localftypeids" ) != null )
      localftypeids = ( int[] )mys.getAttribute( "localftypeids" );

    if( shareftypeids == null && mys.getAttribute( "shareftypeids" ) != null )
      shareftypeids = ( int[] )mys.getAttribute( "shareftypeids" );


    if( localftypeids != null )
    {
      if( !restrictRegion )
      {
        localNumAnnotations = Utility.countAnnotations( con, localftypeids );
        localAVPAssociationCount = LffUtility.countAVPAssociation( con, localftypeids, 1000000, localNumAnnotations, out );

      } else
      {
        localNumAnnotations = Utility.countAnnotations( con, localftypeids, rid, chrStart, chrStop );
        localAVPAssociationCount = AttributeRetriever.countAVPAssociationByChromosomeRegion( con, localftypeids, 1000000, numLocalAnnos, rid, chrStart, chrStop, out );
      }
    }


    if( shareftypeids != null && sharedConnection != null )
    {
      if( !restrictRegion )
      {
        shareNumAnnotations = Utility.countAnnotations( sharedConnection, shareftypeids );
        if( localAVPAssociationCount < 1000000 )
          shareAVPAssociationCount = LffUtility.countAVPAssociation( sharedConnection, shareftypeids, 1000000, shareNumAnnotations, out );
      } else
      {
        shareNumAnnotations = Utility.countAnnotations( sharedConnection, shareftypeids, rid, chrStart, chrStop );

        if( localAVPAssociationCount < 1000000 )
          shareAVPAssociationCount = AttributeRetriever.countAVPAssociationByChromosomeRegion( sharedConnection, shareftypeids, 1000000, numShareAnnos, rid, chrStart, chrStop, out );
      }
    }
    int numSelectedAssociation = localAVPAssociationCount + shareAVPAssociationCount;
    totalNumAnnotations = localNumAnnotations + shareNumAnnotations;
    if( totalNumAnnotations == 0 )
    {
      String track = "track ";
      String tracks = track;
      if( selectedTrackNames != null )
      {
        if( selectedTrackNames.length > 1 || selectedTrackNames.length == 0 )
          track = "tracks ";


        tracks = track;
        if( selectedTrackNames != null && selectedTrackNames.length == 1 )
          tracks = tracks + ":\"" + selectedTrackNames[ 0 ] + "\"";

        if( selectedTrackNames != null && selectedTrackNames.length > 1 )
        {
          for( i = 0; i < selectedTrackNames.length; i++ )
            tracks = tracks + "\"" + selectedTrackNames[ i ] + "\",";
          tracks = tracks.substring( 0, tracks.length() - 1 );
        }
      } else
      {
        tracks = "";
      }
      String region = "";
      if( chrName != null && chrName.length() > 0 )
      {
        region = " and chromosome ";
        if( startString != null )
          region = " and  chromosomal region ";
      }
      String chrRegion = "";
      if( chrName != null )
        chrRegion = chrName;

      if( startString != null )
        chrRegion = chrRegion + ":" + startString;

      if( stopString != null && startString != null )
        chrRegion = chrRegion + "-" + stopString;
      ArrayList errlist = new ArrayList();
      errlist.add( "There is no annotation in the above selected " + track + region + "." );
      errlist.add( "Please try a longer chromosomal region, different chromosome, or track." );
      GenboreeMessage.setErrMsg( mys, "You have selected " + tracks + region + chrRegion, errlist );
      GenboreeUtils.sendRedirect( request, response, "/java-bin/displaySelection.jsp?fromUrl=true" );
      return;
    }


    if( totalNumAnnotations > annoLimit || numSelectedAssociation > avpLimit )
      isLargeSamples = true;

    if( json.has( "groupMode" ) )
      groupMode = json.getString( "groupMode" );

    // default
    if( groupMode == null )
      groupMode = "terse";
    else
    {
      if( groupMode.compareToIgnoreCase( "terse" ) == 0 )
        groupMode = "terse";
      if( groupMode.compareToIgnoreCase( "verbose" ) == 0 )
        groupMode = "verbose";
      if( groupMode.compareToIgnoreCase( "none" ) == 0 )
        groupMode = "NonGrouped";
    }

    if( groupMode.equals( "terse" ) || groupMode.equals( "verbose" ) )
    {
      String target = "/java-bin/viewLayoutGroupAnnotations.jsp?groupMode=" + groupMode;
      if( isLargeSamples )
      {
        ArrayList errlist = new ArrayList();
        errlist.add( "If you have more than one track selected, you may try unselecting all but the most relevant track." );
        errlist.add( "Otherwise, you will have to deselect the group mode checkbox." );
        if( totalNumAnnotations > annoLimit || numSelectedAssociation > avpLimit )
          GenboreeMessage.setErrMsg( mys, "Warning: Due to the large amount of data in the selected track(s), grouping of annotations in the tabular view is disabled.", errlist );

        target = "/java-bin/displaySelection.jsp?fromUrl=true";
      }

      if( restrictRegion )
        target = "/java-bin/viewLayoutGroupAnnotations.jsp?groupMode=" + groupMode;
      GenboreeUtils.sendRedirect( request, response, target );
      //	return;

    }
    // end of controller


    currentPageIndex = 0;
    currentPage = "0";
    mys.setAttribute( "lastPageIndex", "0" );
    mys.removeAttribute( "lastStartPageNum" );
    mys.removeAttribute( "lastEndPageNum" );
    mys.setAttribute( "lastStartPageNum", "" + 0 );


    mode = LffConstants.VIEW;
    initPage = true;
    mys.setAttribute( "lastMode", "" + LffConstants.VIEW );
    isFromLayoutURL = true;
    mys.setAttribute( "URLParams", params );


    displayNames = LffUtility.parseJson( json, "rearrange_list_1" );
    if( displayNames == null || displayNames.length == 0 )
    {
      GenboreeMessage.setErrMsg( mys, "Please select some attributes for annotation display. " );
      GenboreeUtils.sendRedirect( request, response, "/java-bin/urldisplaySelection.jsp?fromUrl=true" );
    } else
    {
      mys.setAttribute( "displayNames", displayNames );

      if( displayNames != null )
        for( int j = 0; j < displayNames.length; j++ )
        {
          displayNames[ j ] = Util.urlDecode( displayNames[ j ] );
        }

      orderedSortNames = LffUtility.parseJson( json, "rearrange_list2" );
      if( orderedSortNames != null )
      {
        int index = -1;
        for( int j = 0; j < orderedSortNames.length; j++ )
        {
          orderedSortNames[ j ] = Util.urlDecode( orderedSortNames[ j ] );
          index = orderedSortNames[ j ].indexOf( "_sort" );
          if( index > 0 )
            orderedSortNames[ j ] = orderedSortNames[ j ].substring( 0, index );
        }

        for( i = 0; i < orderedSortNames.length; i++ )
        {
          if( !lffNameArrayList.contains( orderedSortNames[ i ] ) )
            avpDisplayNameList.add( orderedSortNames[ i ] );
        }
        avpDisplayNames = ( String[] )avpDisplayNameList.toArray( new String[avpDisplayNameList.size()] );
      }

      if( orderedSortNames != null && orderedSortNames.length > 0 )
      {
        sortList = new ArrayList();
        numSortNames = orderedSortNames.length;
        for( i = 0; i < orderedSortNames.length; i++ )
        {
          sortList.add( orderedSortNames[ i ] );
          if( !lffNameArrayList.contains( orderedSortNames[ i ] ) )
          {
            sortByAVP = true;
            avpSortNameList.add( orderedSortNames[ i ] );
          }
        }

        for( int n = 0; n < orderedSortNames.length; n++ )
        {
          if( lffNameArrayList.contains( orderedSortNames[ n ] ) )
            lffSortNameList.add( orderedSortNames[ n ] );
        }

        if( !lffSortNameList.isEmpty() )
          lffSortNames = ( String[] )lffSortNameList.toArray( new String[lffSortNameList.size()] );
      }

      if( sharedConnection != null )
        shareTrack2Ftypes = Utility.retrivesTrack2Ftype( sharedConnection, sharedbName, genboreeUserId );

      if( shareTrack2Ftypes != null && !shareTrack2Ftypes.isEmpty() )
      {
        shareTrack2Ftypes.remove( "Component:Chromosome" );
        shareTrack2Ftypes.remove( "SuperComponent:Sequence" );
        sharedTracks = ( String[] )( shareTrack2Ftypes.keySet().toArray( new String[shareTrack2Ftypes.size()] ) );
        if( sharedTracks != null )
          mys.setAttribute( "sharetracks", sharedTracks );
      }


      if( sharedTracks != null )
        for( i = 0; i < sharedTracks.length; i++ )
          trackNameMap.put( sharedTracks[ i ], "y" );


      if( !trackNameMap.isEmpty() )
        alltracks = ( String[] )trackNameMap.keySet().toArray( new String[trackNameMap.size()] );

      if( alltracks != null )
        Arrays.sort( alltracks );
      else
      {
        GenboreeMessage.setErrMsg( mys, "There is no annotation to display." );
        GenboreeUtils.sendRedirect( request, response, "/java-bin/displaySelection.jsp?fromUrl=true" );
      }
      mys.setAttribute( "alltracks", alltracks );
    }
  } else
  {  // recuring page
    dbName = SessionManager.getSessionDatabaseName( mys );
    if( mys.getAttribute( "dbNames" ) != null )
      dbNames = ( String[] )mys.getAttribute( "dbNames" );

    String sharedTrackId = null;
    if( mys.getAttribute( "ftypeid2sharedbNames" ) != null )
    {
      HashMap map = ( HashMap )mys.getAttribute( "ftypeid2sharedbNames" );
      sharedTrackId = ( ( String[] )map.keySet().toArray( new String[map.size()] ) )[ 0 ];
      sharedbName = ( String )map.get( sharedTrackId );
    }

    if( dbNames != null && sharedbName == null )
    {
      for( i = 0; i < dbNames.length; i++ )
      {
        if( !dbNames[ i ].equals( dbName ) )
        {
          sharedbName = dbNames[ i ];
          break;
        }
      }
    }
    if( dbName != null )
      con = db.getConnection( dbName );

    if( sharedbName != null )
      sharedConnection = db.getConnection( sharedbName );
    if( mys.getAttribute( "localftypeids" ) != null )
    {
      localftypeids = ( int[] )mys.getAttribute( "localftypeids" );
    }
    if( mys.getAttribute( "shareftypeids" ) != null )
      shareftypeids = ( int[] )mys.getAttribute( "shareftypeids" );


    if( sortingColumns )
      isLargeSamples = true;


    orderedSortNames = new String[]{ sortingColumnName };


    if( sortingColumns )
    {
      mys.setAttribute( "sortingByColumnName", "y" );

%>
<%@ include file="include/sortingColumnRetrieveByChr.incl" %>
<%
    }

    paging = true;

  }

  // common to both init and recuring page
  // counting total is needed  because used is allowed to  delete or create new annotation
  // if in the future the editing page goes to display page, then these varibles can be sessioned
  if( localftypeids != null )
  {
    if( !restrictRegion )
    {
      numLocalAnnos = Utility.countAnnotations( con, localftypeids );
    } else
    {
      numLocalAnnos = Utility.countAnnotations( con, localftypeids, rid, chrStart, chrStop );
    }
  }

  if( shareftypeids != null && sharedConnection != null )
  {
    if( !restrictRegion )
    {
      numShareAnnos = Utility.countAnnotations( sharedConnection, shareftypeids );
    } else
    {
      numShareAnnos = Utility.countAnnotations( sharedConnection, shareftypeids, rid, chrStart, chrStop );
    }
  }


  totalNumAnnotations = numLocalAnnos + numShareAnnos;
  totalCount = "" + totalNumAnnotations;
  if( totalNumAnnotations > annoLimit )
    isLargeSamples = true;

  // GET NUMBER OF ANNOTATIONS PER PAGE
  int topDisplayNum = 50;
  if( request.getParameter( "app" ) != null )
  {
    String temp = request.getParameter( "app" );
    topDisplayNum = Integer.parseInt( temp );
  }

  String sessionDisplayNum = null;
  if( mys.getAttribute( "displayNum" ) != null )
  {
    sessionDisplayNum = ( String )mys.getAttribute( "displayNum" );
    int sessionNum = Integer.parseInt( sessionDisplayNum );
    displayNum = sessionNum;

    if( sessionNum != topDisplayNum )
    {
      displayNum = topDisplayNum;
      paging = true;
    }
    mys.setAttribute( "displayNum", "" + displayNum );
  }

  if( mys.getAttribute( "lastStartPageNum" ) != null )
    sstartPageNum = ( String )mys.getAttribute( "lastStartPageNum" );

  if( request.getParameter( "navigator" ) != null && request.getParameter( "download" ) == null )
    mode = LffConstants.VIEW;

  if( initPage )
  {
    mys.setAttribute( "totalCount", totalCount );
    if( displayNames != null && displayNames.length > 0 )
    {
      for( int k = 0; k < displayNames.length; k++ )
      {
        if( !lffNameArrayList.contains( displayNames[ k ] ) )
          avpDisplayNameList.add( displayNames[ k ] );
      }
    }

    if( !avpDisplayNameList.isEmpty() )
    {
      avpDisplayNames = ( String[] )avpDisplayNameList.toArray( new String[avpDisplayNameList.size()] );
      mys.setAttribute( "avpDisplayNames", avpDisplayNames );
    }

    // ok, this three hash will not change
    if( con != null )
    {
      localftypeid2Gclass = Utility.retrieveFtype2Gclass( con, localftypeids );
      localftypeid2ftype = Utility.retrieveFtypeid2ftype( con, dbName, genboreeUserId );
      localid2Chromosome = Utility.retrieveRid2Chromosome( con );

    }

    if( sharedbName != null )
    {
      shareftypeid2Gclass = Utility.retrieveFtype2Gclass( sharedConnection, shareftypeids );
      if( sharedConnection == null || sharedConnection.isClosed() )
        sharedConnection = db.getConnection( sharedbName );
      shareftypeid2ftype = Utility.retrieveFtypeid2ftype( sharedConnection, sharedbName, genboreeUserId );
      shareid2Chromosome = Utility.retrieveRid2Chromosome( sharedConnection );
    }

    mys.setAttribute( "totalNumAnnotations", "" + totalNumAnnotations );
    mys.setAttribute( "localftypeid2Gclass", localftypeid2Gclass );
    mys.setAttribute( "localftypeid2ftype", localftypeid2ftype );
    mys.setAttribute( "localid2Chromosome", localid2Chromosome );
    mys.setAttribute( "shareftypeid2Gclass", shareftypeid2Gclass );
    mys.setAttribute( "shareftypeid2ftype", shareftypeid2ftype );
    mys.setAttribute( "shareid2Chromosome", shareid2Chromosome );

    // this won't change either
    if( orderedSortNames != null )
    {
      fdataSortNames = LffUtility.covertNames( orderedSortNames );
      if( fdataSortNames == null || fdataSortNames.length == 0 )
        fdataSortNames = null;
      needSort = true;
    }

    // case 1: small samples
    if( totalNumAnnotations > 0 || !initPage )
    {
      hasData = true;
    }
  } else
  {
    displayNames = ( String[] )mys.getAttribute( "displayNames" );
    if( mys.getAttribute( "avpDisplayNames" ) != null )
      avpDisplayNames = ( String[] )mys.getAttribute( "avpDisplayNames" );
    String temp = null;
    temp = ( String )mys.getAttribute( "displayNum" );
    if( temp != null )
    {
      int displayN = Integer.parseInt( temp );
      if( displayN != displayNum )
        paging = true;
    }

    // large group
    lffAttributes = ( ArrayList )mys.getAttribute( "lffAttributes" );
    if( mys.getAttribute( "fid2Attributes" ) != null )
    {
      fidAttributes = ( String[][] )mys.getAttribute( "fid2Attributes" );
    }
    // small group
    if( mys.getAttribute( "totalAnnotations" ) != null )
      totalAnnotations = ( AnnotationDetail[] )mys.getAttribute( "totalAnnotations" );

    if( totalAnnotations != null && totalAnnotations.length > 0 )
      hasData = true;

    if( fidAttributes != null && fidAttributes.length > 0 )
      hasData = true;

    localftypeid2ftype = ( HashMap )mys.getAttribute( "localftypeid2ftype" );
    localftypeid2Gclass = ( HashMap )mys.getAttribute( "localftypeid2Gclass" );
    localid2Chromosome = ( HashMap )mys.getAttribute( "localid2Chromosome" );
    shareftypeid2ftype = ( HashMap )mys.getAttribute( "shareftypeid2ftype" );
    shareftypeid2Gclass = ( HashMap )mys.getAttribute( "shareftypeid2Gclass" );
    shareid2Chromosome = ( HashMap )mys.getAttribute( "shareid2Chromosome" );
  }

  int sessionNumAnnos = totalNumAnnotations;
  if( mys.getAttribute( "totalCount" ) != null )
  {
    String s = ( String )mys.getAttribute( "totalCount" );
    sessionNumAnnos = Integer.parseInt( s );
  }

  boolean numAnnoChanged = false;
  if( totalNumAnnotations != sessionNumAnnos )
  {
    numAnnoChanged = true;
    mys.setAttribute( "totalCount", "" + totalNumAnnotations );
  }


  if( totalNumAnnotations > 100000 )
    isLargeSamples = true;


  if( initPage || numAnnoChanged )
  {
    if( !isLargeSamples && hasData )
    {
      if( restrictRegion )
      {
%>
<%@ include file="include/smallAnnoRetrieveByChrom.incl" %>
<% } else
{
%>
<%@ include file="include/smallAnnoRetrieve.incl" %>
<%
  }
} else if( isLargeSamples )
{  // case 2:  large samples
  if( restrictRegion )
  {
%>
<%@ include file="include/largeAnnoRetrieve.incl" %>
<% } else
{
%>
<%@ include file="include/largeAnnoRetrieve.incl" %>
<%
      }
    }          // end of data retrieval
    paging = true;
  }


  if( request.getParameter( "currentPage" ) != null )
    currentPage = request.getParameter( "currentPage" );
  else
    currentPage = "0";

  if( hasData )
  { %>
<%@ include file="include/multipaging.incl" %>
<%@ include file="include/annotationView.incl" %>
<%
  }

  // done processing paging
  // the following will be page specifc
  if( mys.getAttribute( "sortingByColumnName" ) != null )
    isLargeSamples = true;


  if( mys.getAttribute( "sortingColumnOrder" ) != null )
  {
    sortingColumnOrder = ( String )mys.getAttribute( "sortingColumnOrder" );

    if( sortingColumnOrder.equals( "up" ) )
      sortingArrow = "&uarr;";
    else if( sortingColumnOrder.equals( "down" ) )
      sortingArrow = "&darr;";
  }


  boolean hasError = false;
  String[][] tempFidAtt = null;
  if( isLargeSamples && hasData )
  {
    if( page2Annotations != null && page2Annotations.get( currentPage ) != null )
    {
      tempFidAtt = ( String[][] )page2Annotations.get( currentPage );
      if( tempFidAtt != null && tempFidAtt.length > 0 )
      {
        annotations = new AnnotationDetail[tempFidAtt.length];
        int fid = 0;
        for( i = 0; i < annotations.length; i++ )
        {
          String sfid = tempFidAtt[ i ][ 0 ];
          boolean isShare = false;
          if( sfid != null && sfid.startsWith( "s" ) )
          {
            isShare = true;
            sfid = sfid.substring( 1 );
          }

          try
          {
            fid = Integer.parseInt( sfid );
          }
          catch( Exception e )
          {
            continue;
          }
          annotations[ i ] = new AnnotationDetail( fid );

          if( isShare )
            annotations[ i ].setShare( true );
        }
      }
    }
  } else if( hasData )
  {
    if( page2Annotations != null )
      annotations = ( AnnotationDetail[] )page2Annotations.get( currentPage );
  }


  if( annotations != null && annotations.length > 0 )
    newannos = new AnnotationDetail[annotations.length];

  HashMap fid2order = new HashMap();
  if( hasData && annotations != null && annotations.length > 0 )
  {
    // first classify local and share
    ArrayList sharedPageFids = new ArrayList();
    ArrayList localPageFids = new ArrayList();
    localfid2anno = new HashMap();
    sharefid2anno = new HashMap();
    for( i = 0; i < annotations.length; i++ )
    {
      if( !annotations[ i ].isShare() )
      {
        localPageFids.add( "" + annotations[ i ].getFid() );
        fid2order.put( "" + annotations[ i ].getFid(), new Integer( i ) );
        localfid2anno.put( "" + annotations[ i ].getFid(), annotations[ i ] );
      }

      if( annotations[ i ].isShare() )
      {
        sharedPageFids.add( "" + annotations[ i ].getFid() );
        fid2order.put( "s" + annotations[ i ].getFid(), new Integer( i ) );
        sharefid2anno.put( "" + annotations[ i ].getFid(), annotations[ i ] );
      }
    }
    // populate local annotations
    AnnotationDetail[] localannotations = null;
    if( !localPageFids.isEmpty() )
    {
      int[] localpagefids = new int[localPageFids.size()];
      for( i = 0; i < localpagefids.length; i++ )
        localpagefids[ i ] = Integer.parseInt( ( String )localPageFids.get( i ) );

      localannotations = AttributeRetriever.retrieveAnnotations( con, localpagefids, localftypeid2ftype, localid2Chromosome );
      localannotations = AttributeRetriever.populateAnnotationText( localannotations, con );

      String gclass = null;
      if( localannotations != null )
      {
        for( i = 0; i < localannotations.length; i++ )
        {
          if( localftypeid2Gclass != null && localftypeid2Gclass.get( "" + localannotations[ i ].getFtypeId() ) != null )
          {
            gclass = ( String )localftypeid2Gclass.get( "" + localannotations[ i ].getFtypeId() );
            localannotations[ i ].setGclassName( gclass );
          }
        }
      }

      localfid2hash = AttributeRetriever.retrieveSmallNumAnnotationAVPs( con, localpagefids );
      if( localfid2hash != null && localannotations != null )
      {
        for( int m = 0; m < localannotations.length; m++ )
        {
          if( localannotations[ m ] != null && localfid2hash.get( "" + localpagefids[ m ] ) != null )
          {
            avp = ( HashMap )localfid2hash.get( "" + localpagefids[ m ] );
            localannotations[ m ].setAvp( avp );
          }
        }
      }

      for( i = 0; i < localannotations.length; i++ )
      {
        localannotations[ i ].setlff2value();
      }
    }
    // populate share annotations
    AnnotationDetail[] shareannotations = null;
    if( !sharedPageFids.isEmpty() )
    {
      int sharepagefids[] = new int[sharedPageFids.size()];
      for( i = 0; i < sharepagefids.length; i++ )
        sharepagefids[ i ] = Integer.parseInt( ( String )sharedPageFids.get( i ) );
      shareannotations = AttributeRetriever.retrieveAnnotations( sharedConnection, sharepagefids, shareftypeid2ftype, shareid2Chromosome );
      shareannotations = AttributeRetriever.populateAnnotationText( shareannotations, sharedConnection );
      String gclass = null;
      if( shareannotations != null )
      {
        for( i = 0; i < shareannotations.length; i++ )
        {
          if( shareftypeid2Gclass != null && shareftypeid2Gclass.get( "" + shareannotations[ i ].getFtypeId() ) != null )
          {
            gclass = ( String )shareftypeid2Gclass.get( "" + shareannotations[ i ].getFtypeId() );
            shareannotations[ i ].setGclassName( gclass );
          }
        }
      }
      sharefid2hash = AttributeRetriever.retrieveSmallNumAnnotationAVPs( sharedConnection, sharepagefids );
      if( sharefid2hash != null && shareannotations != null )
      {
        for( int m = 0; m < sharepagefids.length; m++ )
        {
          if( sharefid2hash.get( "" + sharepagefids[ m ] ) != null && shareannotations[ m ] != null )
          {
            avp = ( HashMap )sharefid2hash.get( "" + sharepagefids[ m ] );
            shareannotations[ m ].setAvp( avp );
          }
        }
      }
      if( shareannotations != null )
        for( i = 0; i < shareannotations.length; i++ )
        {
          shareannotations[ i ].setlff2value();
        }
    }
    // combine into new annotations
    int index = 0;
    if( annotations != null )
    {
      if( localannotations != null )
      {
        for( i = 0; i < localannotations.length; i++ )
        {
          index = ( ( Integer )fid2order.get( "" + localannotations[ i ].getFid() ) ).intValue();
          newannos[ index ] = localannotations[ i ];
        }
      }
      if( shareannotations != null )
      {
        for( i = 0; i < shareannotations.length; i++ )
        {
          index = ( ( Integer )fid2order.get( "s" + shareannotations[ i ].getFid() ) ).intValue();
          newannos[ index ] = shareannotations[ i ];
        }
      }
      annotations = null;
      annotations = newannos;
    }

  } else
    GenboreeMessage.setErrMsg( mys, "There is no annotation to be displayed." );

  Connection homeConnection = db.getConnection();
  String refseqId = SessionManager.getSessionDatabaseId( mys );
  int localUploadId = 0;
  if( dbName != null && refseqId != null )
    try
    {
      localUploadId = IDFinder.findUploadID( homeConnection, refseqId, dbName );
    }
    catch( Exception e )
    {
      e.printStackTrace();
    }
  int sharedUploadId = 0;
  if( sharedbName != null && refseqId != null )
    try
    {
      sharedUploadId = IDFinder.findUploadID( homeConnection, refseqId, sharedbName );
    }
    catch( Exception e )
    {
      e.printStackTrace();
    } %>
<HTML>
<head>
  <title><%=" My annotations "%>
  </title>
  <meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
  <link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
  <link rel="stylesheet" href="/javaScripts/extjs/resources/css/loading-genboree.css<%=jsVersion%>" type="text/css">
  <link rel="stylesheet" type="text/css" href="/javaScripts/extjs/resources/css/menu.css<%=jsVersion%>">
  <link rel="stylesheet" type="text/css" href="/javaScripts/extjs/resources/css/button.css<%=jsVersion%>">
  <link rel="stylesheet" type="text/css" href="/javaScripts/extjs/resources/css/qtips.css<%=jsVersion%>">
  <link rel="stylesheet" type="text/css" href="/javaScripts/extjs/resources/css/core.css<%=jsVersion%>">
  <link rel="stylesheet" type="text/css" href="/javaScripts/extjs/resources/css/reset-min.css<%=jsVersion%>">
  <link rel="stylesheet" type="text/css" href="/javaScripts/extjs/resources/css/ytheme-genboree.css<%=jsVersion%>">
  <link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
  <link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">
  <link rel="stylesheet" href="/styles/samples.css<%=jsVersion%>" type="text/css">
  <script type="text/javascript" src="/javaScripts/extjs/adapter/prototype/prototype.js<%=jsVersion%>"></script>
  <!-- Stuff here used in rest of files... -->
  <SCRIPT type="text/javascript" src="/javaScripts/tabularView.js<%=jsVersion%>"></SCRIPT>
  <SCRIPT type="text/javascript" src="/javaScripts/sorttable.js<%=jsVersion%>"></SCRIPT>
  <SCRIPT type="text/javascript" src="/javaScripts/layoutView.js<%=jsVersion%>"></SCRIPT>
  <script type="text/javascript">
    tooFewForMenuBtn = <%= tooFewForMenuBtn %>;
    tooManyForMenuBtn = <%= tooManyForMenuBtn %>;
    var sortingArrow = '<%=sortingColumnOrder%>';
  </script>
</head>
<BODY>
<%
  if( annotations != null && annotations.length > tooFewForMenuBtn && annotations.length <= tooManyForMenuBtn )
  {
%>
<!-- PAGE LOADING MASK -->
<div id="genboree-loading-mask" name="genboree-loading-mask"
     style="width:100%;height:100%;background:#e1c4ff;position:absolute;z-index:20000;left:0px;top:0px;">
  &#160;
</div>
<div id="genboree-loading" name="genboree-loading">
  <div class="genboree-loading-indicator">
    <img src="/javaScripts/extjs/resources/images/default/grid/loading.gif" style="width:16px; height:16px;"
         align="absmiddle">
    &#160;Initializing Page...
  </div>
</div>
<%}%>
<script type="text/javascript" src="/javaScripts/extjs/adapter/prototype/scriptaculous.js<%=jsVersion%>"></script>
<!-- Stuff here used in rest of files... -->
<script type="text/javascript" src="/javaScripts/extjs/adapter/prototype/ext-prototype-adapter.js<%=jsVersion%>"></script>
<!-- Stuff here used in rest of files... -->
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
<script type="text/javascript" src="/javaScripts/util.js<%=jsVersion%>"></script>
<!-- Stuff here used in rest of files... -->
<script type="text/javascript" SRC="/javaScripts/editorCommon.js<%=jsVersion%>"></script>
<script type="text/javascript" SRC="/javaScripts/editMenuBtn.widget.js<%=jsVersion%>"></script>
<link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">
<link rel="stylesheet" href="/styles/tabularView.css<%=jsVersion%>" type="text/css">
<SCRIPT type="text/javascript" src="/javaScripts/prototype.js<%=jsVersion%>"></SCRIPT>
<SCRIPT type="text/javascript" src="/javaScripts/commonFunctions.js<%=jsVersion%>"></SCRIPT>
<SCRIPT type="text/javascript" src="/javaScripts/sample.js<%=jsVersion%>"></SCRIPT>
<script type="text/javascript" SRC="/javaScripts/gbrowser.js<%=jsVersion%>"></script>
<style rel="stylesheet" type="text/css">
  /* Shows the image next to the button value */
  .x-btn-text-icon .x-btn-center .x-btn-text {
    background-image: url( images/silk/application_form_edit.gif );
  }
</style>
<%
  int fid = 0;
  if( annotations != null )
    for( i = 0; i < annotations.length; i++ )
    {
      AnnotationDetail annotation = annotations[ i ];
      if( annotation != null )
        fid = annotation.getFid();
      else
        fid = 0;
      if( localUploadId > 0 )
      {
        //  uploadId = sharedUploadId;
        uploadId = localUploadId;
%>
<script type="text/javascript">
  Ext.genboree.addRecord(<%=uploadId%>, <%=fid%>);
</script>
<%
      }
    }
%>
<%@ include file="include/header.incl" %>
<%@ include file="include/navbar.incl" %>
<%@ include file="include/message.incl" %>
<form name="viewForm" id="viewForm" action="viewAnnotation.jsp" method="post">
<input type="hidden" name="currentMode" id="currentMode" value="<%=mode%>">
<input type="hidden" name="sortingColumnName" id="sortingColumnName" value="<%=sortingColumnName%>">
<input type="hidden" name="sortingColumnOrder" id="sortingColumnOrder">
<input type="hidden" name="bk2display" id="bk2display">
<%
  if( displayNames != null && hasData )
  {
%>
<input type="hidden" name="currentPage" id="currentPage" value="<%=currentPage%>">
<input type="hidden" name="navigator" id="navigator" value="">
<table width="100%" style="margin-bottom:5px;" border="1" cellpadding="2" cellspacing="1">
  <%@ include file="include/viewPageIndex.incl" %>
</table>
<table>
  <TR>
    <TD>
      <div id="viewbk" align="left" style="display:<%=viewDisplay%>; margin-bottom: 5px; margin-left: 0px;">
        <input type="submit" name="btnBack" value="Back" class="btn" style="WIDTH:100"> &nbsp; &nbsp;
      </div>
    </TD>
  </TR>
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

<table width="700" border="1" cellpadding="1" cellspacing="1" page-break-after="avoid"
       style="margin-bottom:0px; margin-top:10px;">
  <TR align="center">
    <TD class="form_header"><b>(Total of <%=totalCount%>&nbsp;Annotations)</B></td>
  </TR>
</table>
<table width="100%" id="sampleView" page-break-before="avoid" style="margin-top:0px; margin-bottom:10px;"
       class="sortable" border="1" cellpadding="1" cellspacing="1">
<TR>
  <%
    int annoNameIndex = -1;
    if( displayNames != null )
    {
      String displayName = "";
      String displayArrow = "&nbsp;";
      for( i = 0; i < displayNames.length; i++ )
      {
        displayName = displayNames[ i ];
        if( sortingColumnName != null && sortingColumnName.equals( displayName ) )
          displayArrow = sortingArrow;
        else displayArrow = "&nbsp;";
        if( displayName.equals( "Anno. Name" ) )
          annoNameIndex = i;

        if( displayName != null )
        {
          displayName = displayName.trim();
          // displayName = displayName.replaceAll(" ", "&nbsp;" );
          displayName = Util.htmlQuote( displayName );
          if( displayName.length() < 50 )
            displayName = "<nobr>" + displayName + "</nobr>";
        } else
          displayName = "";
  %>
  <td class="form_header" name="name_<%=i%>" id="id_<%=i%>" align="center" value="<%=Util.urlEncode(displayNames[i])%>"
      onclick="sortingByColumn(<%=i%>, <%=displayNames.length%>, '<%=displayNames[i]%>'); ">
    <a href="#" class="sortheader"><font color="white"><%=displayName%>
    </font></a><span id="span_<%=i%>" class="sortarrow"><%=displayArrow%> </span>
  </td>
  <%
      }
    }
  %></TR>
<%
  HashMap avpMap = null;
  if( hasData && newannos != null )
  {
    for( i = 0; i < newannos.length; i++ )
    {
      AnnotationDetail annotation = newannos[ i ];
      annotation.setlff2value();
      if( annotation == null )
      {
        continue;
      }

      if( !annotation.isShare() && localfid2hash != null && localfid2hash.get( "" + annotation.getFid() ) != null )
        avpMap = ( HashMap )localfid2hash.get( "" + annotation.getFid() );
      else if( annotation.isShare() && sharefid2hash != null && sharefid2hash.get( "" + annotation.getFid() ) != null )
        avpMap = ( HashMap )sharefid2hash.get( "" + annotation.getFid() );
      HashMap lffMap = ( HashMap )annotation.getLff2value();
%>
<TR>
<%
  String value = "";
  String displayName2 = null;
  refseqId = SessionManager.getSessionDatabaseId( mys );

  String tdclass = "form_body3";
  for( int j = 0; j < displayNames.length; j++ )
  {
    displayName2 = displayNames[ j ];
    value = "";
    tdclass = "form_body3";
    if( lffMap != null && lffMap.get( displayName2 ) != null )
      value = ( String )lffMap.get( displayName2 );
    else if( avpMap != null && avpMap.get( displayName2 ) != null )
      value = ( String )avpMap.get( displayName2 );
    if( value == null )
      value = "";
    else
      value = value.trim();

    value = Util.htmlQuote( value );

    int smallDelta = 20;

    if( annoNameIndex > -1 && annoNameIndex == j )
    {
      long start = annotation.getStart();
      long end = annotation.getStop();
      long length = end - start;

      if( length < 10 )
      {
        start -= smallDelta;
        end += smallDelta;
      } else
      {

        if( start > 0 && ( start - length * .2 ) > 0 )
          start = ( long )( start - length * 0.2 );
        else
          start = 0;
        end = ( long )( end + length * 0.2 );  // verification of end is not necessary here because it is done in gbrowser.jsp
        if( length < 100 )
          end = start + 100;


        if( start < 1 )
          start = 1;

      }
      String chr = annotation.getChromosome();

      value = "<A href=\"/java-bin/gbrowser.jsp?refSeqId=" + refseqId + "&entryPointId=" + chr + "&from=" + start + "&to=" + end + " \">" + value + "</a>";
    }

    if( value.length() >= 50 )
      tdclass = "form_body2";
    if( displayName2.equals( "\"Edit\" Link" ) )
    {
      try
      {
        if( uploadId > 0 )
          value = "<A href=\"#\"  onClick=\"winPopFocus('annotationEditor.jsp?upfid=" + uploadId + ":" + annotation.getFid() + "', '_newWin')\"  >Edit </a>";
        else
          value = "Link not available";
      }
      catch( Exception e )
      {
        System.err.println( " exception " + e.getMessage() );
        System.err.flush();
      }
%>
<TD class="<%=tdclass%>" align="center">
  <%
    if( annotation.isShare() )
    {

  %>
  Template Annotation (protected)

  <% } else
  { // local
    if( newannos.length > tooManyForMenuBtn )
    {// too many records on page for all to have button
      if( uploadId > 0 )
      {
  %>
  <a href="/java-bin/annotationEditorMenu.jsp?upfid=<%=uploadId%>:<%=annotation.getFid()%>" style="color: darkorchid;">Edit
    Menu</a>
  <%
  } else
  {
  %>
  link not availale
  <% }

  } else
  {
    if( uploadId > 0 )
    {
  %>
  <div id="editBtnDiv_<%=i%>" name="editBtnDiv_<%=i%>" class='editBtnDiv' style="margin-top: 2px;"></div>
  <%
        }
      }
    }
  %>
</td>
<% } else
{ %>
<TD class="<%=tdclass%>">
  <%="&nbsp;" + value%>
</TD>
<% }
}%>
</TR>
<% } %>
</table>
<% }%>
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
        <TR>
          <TD>
            <div id="viewbk" align="left" style="display:<%=viewDisplay%>; margin-left: 1px;">
              <input type="submit" name="btnBack" value="Back" class="btn" style="WIDTH:100">&nbsp;&nbsp;
            </div>
          </TD>
        </TR>
      </table>
      <table width="100%" border="1" cellpadding="2" cellspacing="1"><BR>
        <% if( mode == LffConstants.VIEW )
        {%>
        <%@ include file="include/viewPageIndexBottom.incl" %>
        <%}%></table>
      <%



}
else if (mode >=0 || !hasData)  {


      %>
      <input type="submit" name="btnBack" value="Cancel" class="btn" style="WIDTH:100">&nbsp;&nbsp;
      <%}%>
</form>
<%@ include file="include/footer.incl" %>
</BODY>
</HTML>
