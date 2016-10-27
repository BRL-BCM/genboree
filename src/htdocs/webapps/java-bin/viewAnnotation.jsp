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
                 org.json.JSONArray"
        %>
<%@ page import="org.genboree.editor.Chromosome" %>

<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/group.incl" %>
<%@ include file="include/sessionGrp.incl" %>

<%!
  public static HashMap populatev2id( String[][] fidAttributes, JspWriter out )
  {
    HashMap v2id = new HashMap();
    ArrayList list = null;
    String[] arr1 = null;
    for( int i = 0; i < fidAttributes.length; i++ )
    {
      arr1 = fidAttributes[ i ];

      if( arr1[ 1 ] == null || arr1[ 1 ] == "" )
        arr1[ 1 ] = OneAttAnnotationSorter.maxStringValue;
      fidAttributes[ i ] = arr1;

      if( v2id.get( arr1[ 1 ] ) == null )
        list = new ArrayList();
      else
        list = ( ArrayList )v2id.get( arr1[ 1 ] );

      if( arr1 != null && arr1[ 1 ] != null )
      {
        list.add( arr1 );
        v2id.put( arr1[ 1 ], list );
      }

    }
    return v2id;
  }


%>

<%@ include file="include/pageInit.incl" %>
<%
  response.addDateHeader( "Expires", 0L );
  response.addHeader( "Cache-Control", "no-cache, no-store" );
  GenboreeMessage.clearMessage( mys );
  boolean ascendingSort = true;
  String orderedSortNames[] = null;
  String displayNames[] = null;
  String jsparams = request.getParameter( "jsparams" );
  boolean recurPage = request.getParameter( "navigator" ) != null;
  boolean fromSelection = request.getParameter( "viewData" ) != null;
  boolean sortingColumns = false;
  String sortingColumnName = request.getParameter( "sortingColumnName" );
  if( sortingColumnName != null )
  {
    sortingColumnName = sortingColumnName.trim();
    sortingColumnName = Util.urlDecode( sortingColumnName );
  }
  String[] selectedTrackNames = request.getParameterValues( "dbTrackNames" );
  boolean restrictRegion = false;

  String groupMode = null;


  int rid = -1;
  long chrStart = -1;
  long chrStop = -1;

  String pressed = request.getParameter( "viewData" );
  if( pressed != null && pressed.compareTo( "1" ) == 0 )
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
%>
<%@ include file="include/chromosome.incl" %>
<%


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
  }

  if( jsparams == null || jsparams.length() == 0 )
  {
    if( !recurPage && !fromSelection )
    {
      GenboreeUtils.sendRedirect( request, response, "/java-bin/displaySelection.jsp" );
      return;
    }
  } else
  {
    JSONObject json = new JSONObject( jsparams );
    if( json != null )
    {
      displayNames = LffUtility.parseJson( json, "rearrange_list_1" );
      if( displayNames != null && displayNames.length > 0 )
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
      }
    }


  }

  HashMap shareddb2Ftypes = null;
  boolean hasSharedTrack = false;
  if( request.getParameter( "btnBack" ) != null )
  {
    //LffUtility.clearCache(mys);
    GenboreeUtils.sendRedirect( request, response, "/java-bin/displaySelection.jsp?fromBrowser=View" );
    return;
  }

  int numLocalAnnos = 0;
  int numShareAnnos = 0;
  // initialization
  int totalNumAnnotations = 0;
  dispNum = new int[]{ 20, 25, 50, 100, 200 };
  String[] fdataSortNames = null;
  HashMap nameid2values = null;
  HashMap valueid2values = null;
  int[] attNameIds = null;
  boolean hasData = true;
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
  int[] localftypeids = null;
  int[] shareftypeids = null;
  AnnotationDetail[] localAnnotations = null;
  AnnotationDetail[] sharedAnnotations = null;
  int currentIndex = 0;
  // GET NUMBER OF ANNOTATIONS PER PAGE
  int topDisplayNum = 50;
  if( request.getParameter( "app" ) != null )
  {
    String temp = request.getParameter( "app" );
    topDisplayNum = Integer.parseInt( temp );
  }

 int genboreeUserId = Util.parseInt( myself.getUserId(), -1 );

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

  String[] avpNames = null;
  ArrayList avpDisplayNameList = new ArrayList();

  int i = 0;
  ArrayList lffSortNameList = new ArrayList();
  HashMap order2Att = new HashMap();

  Refseq rseq = null;
  HashMap localftypeid2Gclass = null;
  HashMap shareftypeid2Gclass = null;
  boolean noAttributeSelected = false;
  String viewDisplay = "block";

  ArrayList avpSortNameList = new ArrayList();

  if( mys.getAttribute( "lastStartPageNum" ) != null )
    sstartPageNum = ( String )mys.getAttribute( "lastStartPageNum" );

  if( rseqs == null || rseqs.length == 0 )
    GenboreeMessage.setErrMsg( mys, "Sorry, there is no database in this group. <br> -- Please create a database and try again." );

  dbName = SessionManager.getSessionDatabaseName( mys );
  if( dbName == null )
  {
    GenboreeUtils.sendRedirect( request, response, "/java-bin/displaySelection.jsp" );
    return;
  }


  String[] dbNames = null;
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

  int localAVPAssociationCount = 0;
  int shareAVPAssociationCount = 0;
  if( sharedbName != null )
    sharedConnection = db.getConnection( sharedbName );

  if( mys.getAttribute( "localftypeids" ) != null )
  {
    localftypeids = ( int[] )mys.getAttribute( "localftypeids" );
  }

  if( mys.getAttribute( "shareftypeids" ) != null )
    shareftypeids = ( int[] )mys.getAttribute( "shareftypeids" );
  // first, display all names for selection
  if( localftypeids != null )
  {
    if( !restrictRegion )
    {
      numLocalAnnos = Utility.countAnnotations( con, localftypeids );
      localAVPAssociationCount = AttributeRetriever.countAVPAssociation( con, localftypeids, 1000000, numLocalAnnos, out );
    } else
    {
      numLocalAnnos = Utility.countAnnotations( con, localftypeids, rid, chrStart, chrStop );
      localAVPAssociationCount = AttributeRetriever.countAVPAssociationByChromosomeRegion( con, localftypeids, 1000000, numLocalAnnos, rid, chrStart, chrStop, out );
    }
  }

  int[] shareFids = null;
  if( sharedbName != null && shareftypeids != null )
  {
    if( !restrictRegion )
    {
      if( localAVPAssociationCount < 1000000 )
        shareAVPAssociationCount = AttributeRetriever.countAVPAssociation( sharedConnection, shareftypeids, 1000000, numShareAnnos, out );

      numShareAnnos = Utility.countAnnotations( sharedConnection, shareftypeids );
    } else
    {
      numShareAnnos = Utility.countAnnotations( sharedConnection, shareftypeids, rid, chrStart, chrStop );

      if( localAVPAssociationCount < 1000000 )
        shareAVPAssociationCount = AttributeRetriever.countAVPAssociationByChromosomeRegion( sharedConnection, shareftypeids, 1000000, numShareAnnos, rid, chrStart, chrStop, out );
    }

  }

  totalNumAnnotations = numLocalAnnos + numShareAnnos;


  HashMap trackHash = new HashMap();
  if( con != null )
  {

    localftypeid2ftype = Utility.retrieveFtypeid2ftype( con, dbName, genboreeUserId );

  }

  if( sharedbName != null )
  {
    shareftypeid2ftype = Utility.retrieveFtypeid2ftype( sharedConnection, sharedbName, genboreeUserId );

  }
  String totalCount = "" + totalNumAnnotations;
  if( totalNumAnnotations > 1000 )
    totalCount = Util.putCommas( totalCount );


  if( totalNumAnnotations <= 0 )
  {
    String track = "track";
    String tracks = "tracks ";
    if( selectedTrackNames != null )
    {
      if( selectedTrackNames.length > 1 || selectedTrackNames.length == 0 )
        track = "tracks ";


      if( selectedTrackNames != null && selectedTrackNames.length == 1 )
        tracks = tracks + ":" + selectedTrackNames[ 0 ];

      if( selectedTrackNames != null && selectedTrackNames.length > 1 )
      {
        for( i = 0; i < selectedTrackNames.length; i++ )
          tracks = tracks + "\"" + selectedTrackNames[ i ] + "\",";
        tracks = tracks.substring( 0, tracks.length() - 1 );

      }
    }

    String chrRegion = "";
    if( chrName != null )
    {
      chrRegion = chrName;

      if( startString != null )
        chrRegion = chrRegion + ":" + chrStart;

      if( stopString != null && startString != null )
        chrRegion = chrRegion + "-" + chrStop;
    }
    if( totalNumAnnotations <= 0 && selectedTrackNames != null )
    {
      ArrayList errlist = new ArrayList();
      errlist.add( "There is no annotation in the above selected " + track + " and chromosomal region." );
      errlist.add( "Please try a longer chromosomal region, or different chromosome, or track." );
      GenboreeMessage.setErrMsg( mys, "You have selected " + tracks + " and chromosomal region " + chrRegion, errlist );
    }

    GenboreeUtils.sendRedirect( request, response, "/java-bin/displaySelection.jsp?fromBrowser=View" );
    hasData = false;
    return;
  }

  int numSelectedAssociation = localAVPAssociationCount + shareAVPAssociationCount;

  if( totalNumAnnotations > 100000 || numSelectedAssociation > 1000000 )
    isLargeSamples = true;

  int numSortNames = 0;
  if( request.getParameter( "navigator" ) != null )
  {
    initPage = false;
    if( sortingColumnOrder == null || sortingColumnOrder.length() == 0 )
      sortingColumns = false;
    else
    {
      if( mys.getAttribute( "sortingColumnOrder" ) != null )
        sortingColumnOrder = ( String )mys.getAttribute( "sortingColumnOrder" );

    }

  }

  String[] avpDisplayNames = null;

  if( initPage )
  {
    mys.removeAttribute( "sortingByColumnName" );

    if( displayNames == null )
    {
      GenboreeMessage.setErrMsg( mys, "Please select some attributes for annotation display. " );
      viewDisplay = "none";
      noAttributeSelected = true;
    } else
    {
      if( orderedSortNames != null )
      {
        for( i = 0; i < orderedSortNames.length; i++ )
        {
          if( !lffNameArrayList.contains( orderedSortNames[ i ] ) )
            avpDisplayNameList.add( orderedSortNames[ i ] );
        }
        avpDisplayNames = ( String[] )avpDisplayNameList.toArray( new String[avpDisplayNameList.size()] );
      }
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

    /// /   retrieveFidStart(con, localftypeids, totalNumAnnotations,  out);
    //      retrieveAnnosByStart(con, localftypeids, out);

    if( sortingColumns )
      isLargeSamples = true;


    if( !isLargeSamples && hasData )
    {
      if( restrictRegion )
      {
%>
<%@ include file="include/smallAnnoRetrieveByChrom.incl" %>
<%
} else
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
<%@ include file="include/largeAnnoRetrieveByRegion.incl" %>
<%

} else
{
%>
<%@ include file="include/largeAnnoRetrieve.incl" %>
<%
    }
  }
  mys.setAttribute( "totalAnnotations_AV", totalAnnotations );
  // end of data retrieval


  paging = true;
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


} else
{  //  recuring page
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
  if( mys.getAttribute( "totalAnnotations_AV" ) != null )
    totalAnnotations = ( AnnotationDetail[] )mys.getAttribute( "totalAnnotations_AV" );

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

  if( sortingColumns )
  {
    if( !lffNameArrayList.contains( sortingColumnName ) )
      avpDisplayNameList.add( sortingColumnName );

    // check here
    avpDisplayNames = ( String[] )avpDisplayNameList.toArray( new String[avpDisplayNameList.size()] );
    sortList = new ArrayList();
    numSortNames = 1;

    sortList.add( sortingColumnName );
    if( !lffNameArrayList.contains( sortingColumnName ) )
    {
      sortByAVP = true;
      avpSortNameList.add( sortingColumnName );
    }

    if( lffNameArrayList.contains( sortingColumnName ) )

      lffSortNames = new String[]{ sortingColumnName };

    fdataSortNames = LffUtility.covertNames( orderedSortNames );
    if( fdataSortNames == null || fdataSortNames.length == 0 )
      fdataSortNames = null;
    needSort = true;

// case 1: small samples
    hasData = true;
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
    }
  }


  if( request.getParameter( "currentPage" ) != null )
    currentPage = request.getParameter( "currentPage" );
  else
    currentPage = "0";

  if( mys.getAttribute( "sortingByColumnName" ) != null )
    sortingColumns = true;


  if( sortingColumns )
    paging = true;

  if( sortingColumns )
  {
    isLargeSamples = true;
  }


  if( hasData )
  { %>
<%@ include file="include/multipaging.incl" %>
<%@ include file="include/annotationView.incl" %>
<%
  }

  boolean hasError = false;
  String[][] tempFidAtt = null;
  if( mys.getAttribute( "sortingByColumnName" ) != null )
  {
    isLargeSamples = true;
  }

  if( mys.getAttribute( "sortingColumnOrder" ) != null )
  {
    sortingColumnOrder = ( String )mys.getAttribute( "sortingColumnOrder" );
    if( sortingColumnOrder.equals( "up" ) )
      sortingArrow = "&uarr;";
    else if( sortingColumnOrder.equals( "down" ) )
      sortingArrow = "&darr;";
  }


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
  } else if( !isLargeSamples && hasData )
  {
    if( page2Annotations != null && page2Annotations.get( currentPage ) != null )
      annotations = ( AnnotationDetail[] )page2Annotations.get( currentPage );

  }


  AnnotationDetail[] newannos = null;
  if( annotations != null && annotations.length > 0 )
    newannos = new AnnotationDetail[annotations.length];

  HashMap fid2order = new HashMap();
  if( hasData && annotations != null && annotations.length > 0 )
  {
    // first classify local and share
    ArrayList sharedPageFids = new ArrayList();
    ArrayList localPageFids = new ArrayList();
    for( i = 0; i < annotations.length; i++ )
    {
      if( !annotations[ i ].isShare() )
      {
        localPageFids.add( "" + annotations[ i ].getFid() );
        fid2order.put( "" + annotations[ i ].getFid(), new Integer( i ) );
      }

      if( annotations[ i ].isShare() )
      {
        sharedPageFids.add( "" + annotations[ i ].getFid() );
        fid2order.put( "s" + annotations[ i ].getFid(), new Integer( i ) );
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
      HashMap localpagefid2anno = new HashMap();
      if( localannotations != null )
      {
        for( i = 0; i < localannotations.length; i++ )
          localpagefid2anno.put( "" + localannotations[ i ].getFid(), localannotations[ i ] );
      }
      localannotations = AttributeRetriever.populateAnnotationText( localannotations, localpagefid2anno, con );


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
        for( i = 0; i < localannotations.length; i++ )
          localannotations[ i ].setlff2value();
      }

    }

    // populate share annotations
    AnnotationDetail[] shareannotations = null;
    if( !sharedPageFids.isEmpty() )
    {
      int sharepagefids[] = new int[sharedPageFids.size()];
      for( i = 0; i < sharepagefids.length; i++ )
      {
        sharepagefids[ i ] = Integer.parseInt( ( String )sharedPageFids.get( i ) );
      }
      shareannotations = AttributeRetriever.retrieveAnnotations( sharedConnection, sharepagefids, shareftypeid2ftype, shareid2Chromosome );

      HashMap sharepagefid2anno = new HashMap();
      if( shareannotations != null )
      {
        for( i = 0; i < shareannotations.length; i++ )
        {
          sharepagefid2anno.put( "" + shareannotations[ i ].getFid(), shareannotations[ i ] );
        }
      }


      shareannotations = AttributeRetriever.populateAnnotationText( shareannotations, sharepagefid2anno, sharedConnection );
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


        for( int m = 0; m < shareannotations.length; m++ )
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
          shareannotations[ i ].setShare( true );
        }
    }

    //combine into new annotations
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
  {
    if( initPage )
    {

      ArrayList errList = new ArrayList();
      errList.add( "Please go back to previous page and change your selection(s). " );
      GenboreeMessage.setErrMsg( mys, "There is no annotation in the selected track(s).", errList );
      if( restrictRegion )
        GenboreeMessage.setErrMsg( mys, "There is no annotation in the selected chromosome region: " + chrName + " " + chrStart + ":" + chrStop + ".", errList );

    } else
    {


      GenboreeUtils.sendRedirect( request, response, "/java-bin/displaSelection.jsp?fromBrowser=View" );
      return;
    }
  }

%>
<%@ include file="include/saveLayout.incl" %>
<%
  Connection homeConnection = db.getConnection();


  if( rseqs != null && rseqs.length > 0 )
  {

    if( selectedTrackNames != null )
    {
      HashMap selectedTrackHash = new HashMap();
      for( i = 0; i < selectedTrackNames.length; i++ )
      {
        selectedTrackHash.put( selectedTrackNames[ i ], "y" );
        mys.setAttribute( "selectedTrackHash", selectedTrackHash );
      }
    }
  }


  String refseqId = SessionManager.getSessionDatabaseId( mys );
  int localUploadId = 0;
  if( dbName != null && refseqId != null )
    try
    {
      localUploadId = IDFinder.findUploadID( homeConnection, refseqId, dbName );
    }
    catch( Exception e )
    {
      localUploadId = 0;
    }
  int sharedUploadId = 0;
  if( sharedbName != null && refseqId != null )
    try
    {
      sharedUploadId = IDFinder.findUploadID( homeConnection, refseqId, sharedbName );
    }
    catch( Exception e )
    {
      sharedUploadId = 0;
    }
  int tooFewForMenuBtn = 29;
  int tooManyForMenuBtn = 150;
  if( sortingColumnName == null )
    sortingColumnName = "";
  String ensortingColumnName = Util.urlEncode( sortingColumnName );


%>
<HTML>
<head>
  <title><%="Tabular View of Annotations"%>
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
  <!-- Set a local "blank" image file; default is a URL to extjs.com -->
  <script type='text/javascript'>
    Ext.BLANK_IMAGE_URL = '/javaScripts/extjs/resources/images/genboree/s.gif';
  </script>
  <link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
  <link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">
  <link rel="stylesheet" href="/styles/samples.css<%=jsVersion%>" type="text/css">
  <script type="text/javascript" src="/javaScripts/extjs/adapter/prototype/prototype.js<%=jsVersion%>"></script>
  <!-- Stuff here used in rest of files... -->

  <SCRIPT type="text/javascript" src="/javaScripts/tabularView.js<%=jsVersion%>"></SCRIPT>
  <SCRIPT type="text/javascript" src="/javaScripts/sorttable.js<%=jsVersion%>"></SCRIPT>
  <script type="text/javascript">
    tooFewForMenuBtn = <%= tooFewForMenuBtn %>;
    tooManyForMenuBtn = <%= tooManyForMenuBtn %>;
    var sortingArrow = '<%=sortingColumnOrder%>';
  </script>
</head>
<BODY>
<%
  if( annotations != null && annotations.length > tooFewForMenuBtn && annotations.length <= tooManyForMenuBtn ) // Then let's us a mask. Else not needed or too many anyway and we do something else
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
<!-- include EVERYTHING ELSE after the loading indicator -->
<%
  }
%>

<!-- BEGIN: Extjs: Split Button Support -->
<script type="text/javascript" src="/javaScripts/extjs/adapter/prototype/scriptaculous.js<%=jsVersion%>"></script>
<!-- Stuff here used in rest of files... -->
<script type="text/javascript"
        src="/javaScripts/extjs/adapter/prototype/ext-prototype-adapter.js<%=jsVersion%>"></script>
<!-- Stuff here used in rest of files... -->
<script type="text/javascript" src="/javaScripts/extjs/package/genboree/ext-menuBtn-only-pkg.js<%=jsVersion%>"></script>

<script type="text/javascript" src="/javaScripts/util.js<%=jsVersion%>"></script>
<!-- Stuff here used in rest of files... -->
<script type="text/javascript" SRC="/javaScripts/editorCommon.js<%=jsVersion%>"></script>
<script type="text/javascript" SRC="/javaScripts/editMenuBtn.widget.js<%=jsVersion%>"></script>
<!-- END -->

<SCRIPT type="text/javascript" src="/javaScripts/prototype.js<%=jsVersion%>"></SCRIPT>
<SCRIPT type="text/javascript" src="/javaScripts/sample.js<%=jsVersion%>"></SCRIPT>

<script type="text/javascript" SRC="/javaScripts/gbrowser.js<%=jsVersion%>"></script>
<style rel="stylesheet" type="text/css">
  /* Shows the image next to the button value */
  .x-btn-text-icon .x-btn-center .x-btn-text {
    background-image: url( '/images/silk/application_form_edit.gif' );
  }
</style>
<%
  int fid = 0;
  int uploadId = -1;
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
<% if( displayNames != null && hasData )
{ %>
<p style="text-align:center; color:red;">
  The tabular views of annotations are new and some issues may be experienced.
  Improvements are under development and will be deployed as they become available. If you have any problems, please
  contact the <a href="mailto:<%=GenboreeConfig.getConfigParam("gbAdminEmail")%>">Genboree Admin</a> with the details.
</p> <%}%>
<form name="viewForm" id="viewForm" action="viewAnnotation.jsp" method="post">
<input type="hidden" name="sortingColumnName" id="sortingColumnName" value="<%=ensortingColumnName%>">
<input type="hidden" name="sortingColumnOrder" id="sortingColumnOrder">

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
      <div align="left" style="display:<%=viewDisplay%>; margin-bottom:5px; margin-left:0px;">
        <input type="submit" name="btnBack" value="Back" class="btn" style="WIDTH:100">&nbsp;&nbsp
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
  <% int annoNameIndex = -1;
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

        String encodedString = Util.urlEncode( displayNames[ i ] );
  %>

  <td class="form_header" name="name_<%=i%>" id="id_<%=i%>" align="center" value="<%=encodedString%>"
      onclick="sortingByColumn(<%=i%>, <%=displayNames.length%>, '<%=encodedString %>'); ">
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
        if(length < 10)
        {
          start -= smallDelta;
          end +=  smallDelta;
        }
        else
        {
          if( start > 0 && ( start - length * .2 ) > 0 )
            start = ( long )( start - length * 0.2 );
          else
            start = 0;

          end = ( long )( end + length * 0.2 );  // verification of end is not necessary here because it is done in gbrowser.jsp
          if( start < 1 )
            start = 1;

          if( length < 100 )
            end = start + 100;
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
          // value = "<A href=\"/java-bin/annotationEditor.jsp?upfid="  + uploadId  +":" + annotation.getFid() +  " \">" +  "Edit </a>";
          if( uploadId > 0 )
            value = "<A href=\"#\"  onClick=\"winPopFocus('annotationEditor.jsp?upfid=" + uploadId + ":" + annotation.getFid() + "', '_newWin')\"  >Edit </a>";
          else
            value = "Link not available";
        }
        catch( Exception e )
        {
          System.err.println( " <br> exception " + e.getMessage() );
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
    <a href="/java-bin/annotationEditorMenu.jsp?upfid=<%=uploadId%>:<%=annotation.getFid()%>"
       style="color: darkorchid;">Edit Menu</a>
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
      }%>

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
        <TR>
          <TD>
            <div id="viewbk" align="left" style="display:<%=viewDisplay%>; margin-left: 0px;">
              <input type="submit" name="btnBack" value="Back" class="btn" style="WIDTH:100">&nbsp;&nbsp
            </div>
          </TD>
        </TR>
      </table>
      <table width="100%" border="1" cellpadding="2" cellspacing="1"><BR>
        <%@ include file="include/viewPageIndexBottom.incl" %>
      </table>
      <%

 }
 else if ( !hasData)  {
      %>
      <input type="submit" name="btnBack" value="Cancel" class="btn" style="WIDTH:100">&nbsp;&nbsp;
      <%}%>
</form>
<%@ include file="include/footer.incl" %>
</BODY>
</HTML>
