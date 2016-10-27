<%@ page import="javax.servlet.http.*, java.net.*, java.sql.*,
  java.util.*, org.genboree.dbaccess.*, org.genboree.util.Util,
                 org.genboree.manager.tracks.Utility,
                 org.genboree.message.GenboreeMessage,
                 org.genboree.manager.link.LinkCreator,
                 org.genboree.manager.link.LinkUpdator,
                 java.io.IOException,
                 org.genboree.manager.tracks.TrackManagerInfo,
                 org.genboree.manager.link.LinkManagerHelper" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/linkmgr.incl" %>
<%@ include file="include/group.incl" %>
<%

    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );
    GenboreeMessage.clearMessage(mys);
    int origMode = 0;
    boolean no_acs = false;
    String dbName = null;
    String[] dbNames = null;
    Connection conn = null;
    String acs = null;
    Refseq rseq = null;
    boolean no_links = false;
    ArrayList localTrackList = null ;
    ArrayList sharedTrackList = null ;
    TrackManagerInfo info = new TrackManagerInfo();
    HashMap linkid2index = new HashMap ();
    userId = Util.parseInt(userInfo[2], -1);
    HashMap id2Link = new HashMap();
    HashMap db2Tracks = new HashMap ();
    HashMap localTrack2Links = new HashMap();

    try
    {
      info.init(userInfo, rseqs, mys, request, response, out, db, userId);
    }
    catch(Exception ex)
    {
      System.err.println("ERROR: linkmgr.jsp => couldn't init TrackManagerInfo. Probably no tracks in database?") ;
      ex.printStackTrace(System.err) ;
    }
    DbFtype[] sharedTracks  = null;
    DbFtype[] localTracks  = null;
    DbFtype[] allTracks  = null;
    HashMap track2links = new HashMap ();
    String editLinkId = null;
    DbLink editLink = null;
    ArrayList shareLinkList = new ArrayList ();
    ArrayList  listSelectedTracks = new ArrayList();
    HashMap selectedLinks = new HashMap();
    HashMap htTrkSel = new HashMap();
    DbLink[] links = null;
    DbLink[] shareLinks = null;
    HashMap  dbtrack2links = null;
    int i;
    HashMap track2Links = new HashMap();
    String []  databaseNames = null;
    String destback = (String) mys.getAttribute( "destback" );
    if( destback == null ) destback = "login.jsp";
    boolean auto_goback = (destback.indexOf("gbrowser.jsp") >= 0);
    HashMap shareTrack2Links = new HashMap ();
    if( rseqs == null && grps!=null ){
        rseqs = Refseq.fetchAll( db, grps );
        if( JSPErrorHandler.checkErrors(request,response, db,mys) )
            return;
//        mys.setAttribute( "RefSeqs", rseqs );
    }



    String pMode = request.getParameter("mode");
    int mode = MODE_DEFAULT;
    if( pMode != null ) {
        for( i=0; i<modeIds.length; i++ )
        if( pMode.equals(modeIds[i]) )
        {
            mode = i;
            break;
        }
    }

        String lastpage = (String)mys.getAttribute("pagename");
        if (request.getParameter("back") != null) {
            boolean bk2Browser = (request.getParameter("b2b") ==null) ? true:false;
            String back2 = (String )mys.getAttribute("lastBrowserView");
            if (bk2Browser )  {
                if (lastpage != null && lastpage.compareTo("tkmgr") != 0){
                    if (back2 != null)
                        GenboreeUtils.sendRedirect(request,response, back2);
                    else
                        GenboreeUtils.sendRedirect(request,response, "/java-bin/defaultGbrowser.jsp");
                }
                else
                GenboreeUtils.sendRedirect(request,response, "/java-bin/trackmgr.jsp");
            }
             else
                GenboreeUtils.sendRedirect(request,response, "/java-bin/linkmgr.jsp");
        }
        mys.setAttribute("pagename", "lkmgr");
        Vector vBtn = new Vector();
        String[] btn = new String[]{  "submit",   "back",  " Cancel ",  null} ;
        String[] btnBack = btn;
        String[] trackNames = null;
        HashMap  trackLookup = null;
        String oldRefseqId = SessionManager.getSessionDatabaseId(mys);
        String refSeqId = request.getParameter( "rseq_id" );

         boolean old_db = oldRefseqId!=null && (refSeqId==null || refSeqId.equals(oldRefseqId));
        if( refSeqId == null ) refSeqId = oldRefseqId;

        if( refSeqId == null )
            refSeqId = "#";

        rseq = null;
        if (rseqs != null) {
            for( i=0; i<rseqs.length; i++ ){
                if( rseqs[i].getRefSeqId().equals(refSeqId) ) {
                    rseq = rseqs[i];

                    break;
                }
            }
        }
   HashMap  trackName2ftype = new HashMap ();
 //if (rseq==null && rseqs != null && rseqs.length>0)
 //rseq = rseqs[0];

    if (rseqs != null && rseq != null) {
        SessionManager.setSessionDatabaseId(mys,  refSeqId );
        if( !old_db ){
            mys.removeAttribute( "featuretypes" );
        }
        acs = Refseq.fetchUserAccess( db, rseq.getDatabaseName(), userInfo[2] );
        if( acs == null ) acs = "r";

        if( !is_admin ){
            if( acs!=null && acs.equals("o") ) is_admin = true;
        }
        else acs = "o";

       dbName = rseq.getDatabaseName();
       dbNames = rseq.fetchDatabaseNames(db) ;

        localTracks = info.getAllLocalTracks();
       sharedTracks = info.getShareTracks();
       localTrackList = new ArrayList ();
       sharedTrackList = new ArrayList ();
      if(sharedTracks != null)
      {
        for (i=0; i<sharedTracks.length; i++)
        {
          if(sharedTracks[i] != null)
          {
            sharedTrackList.add( sharedTracks[i]) ;
          }
        }
      }

      if(localTracks != null)
      {
        for(i=0; i<localTracks.length; i++)
        {
          if(localTracks[i] != null)
          {
            localTrackList.add( localTracks[i]) ;
            trackName2ftype.put(localTracks[i].toString(), localTracks[i]);
          }
        }
      }

        allTracks = info.getTracks();

        if (allTracks != null && allTracks.length >0)
            Arrays.sort(allTracks);
           else
             GenboreeMessage.setErrMsg(mys, "There are no tracks available.");

        listSelectedTracks = new ArrayList();
        selectedLinks = new HashMap();

        conn = db.getConnection( dbName );
        DbLink[] localLinks = DbLink.fetchAll( conn , false);

        if (rseq != null)
            shareLinks = DbLink.fetchShareLinks(rseq.getDatabaseName(), rseq.fetchDatabaseNames(db), db );
        // links from main and shared database are merge to one

        links  = LinkManagerHelper.mergeLinks(localLinks, shareLinks, out);
        if (links != null)
         Arrays.sort(links);

        for (i=0; i<shareLinkList.size(); i++)
            shareLinkList.add(shareLinks[i].getLinkId());

        if (links != null)
        for (i=0; i<links.length; i++) {
            id2Link.put(links[i].getLinkId(), links[i]);
        }

           editLinkId = request.getParameter( "editLinkId" );

        if (editLinkId != null && links != null)
        for( i=0; i<links.length; i++ ){
            if( links[i].getLinkId().compareTo(editLinkId)==0 ){
                editLink = links[i];
                break;
            }
        }
        if( editLink == null && links != null && links.length >0 && mode==MODE_UPDATE ){
            editLink = links[0];
            //iEditLinkId = editLink.getLinkId();
            editLinkId = editLink.getLinkId();
        }

        if( editLink == null ) {
            editLinkId = "#";
            //iEditLinkId = -1;
            editLink = new DbLink();
        }
        no_links = false;
        boolean b = (links==null);

        if( links == null  && (mode==MODE_UPDATE || mode==MODE_DELETE) ){
            no_links = true;
            mode = MODE_DEFAULT;
        }
    }


  origMode = mode;
  ArrayList list = null;
  switch( mode ){
  case MODE_CREATE:
    if( acs_level < 1 ){
      mode = MODE_DEFAULT;
      no_acs = true;
    }
    else {
     if (rseq != null){
      vBtn.addElement( btnCreate );
      if( request.getParameter(btnCreate[1]) != null )
      {
        LinkCreator.createLink(mys, request, response,conn,vBtn, editLink, links, shareLinks );
      }
     }} // btnCreate

    break; // MODE_CREATE

  case MODE_UPDATE:
    if( acs_level < 1 )
    {
      mode = MODE_DEFAULT;
      no_acs = true;
    }
    else
    {
       if (rseq!=null){
          vBtn.addElement( btnApply );
          if( request.getParameter(btnApply[1]) != null )
          {
           LinkUpdator.updateLink(mys, request, response, conn, editLink, db);
          } // btnApply
        }
    }
    break; // MODE_UPDATE

  case MODE_DELETE:
    if( acs_level < 1 )
    {
      mode = MODE_DEFAULT;
      no_acs = true;
    }
    else
    {
      if (rseq != null) {
        vBtn.addElement( btnDelete );

      if( request.getParameter(btnDelete[1]) != null ) {
        String[] lnkIds = request.getParameterValues( "delLnkId" );
        int cnt = DbLink.deleteLinks( conn, lnkIds );
        if( cnt > 0 )
        {
            list = new ArrayList();
            list.add("" + cnt + " links were deleted");
            GenboreeMessage.setSuccessMsg(mys, " The delete operation was successful. " ) ;
        }
          links = DbLink.fetchAll( conn , false);
          links  = DbLink.mergeLinks(links, shareLinks);
      }
      } // btnDelete
    }
    break; // MODE_DELETE

  case MODE_ASSIGN:
    if( acs_level < 1 ) {
      mode = MODE_DEFAULT;
      no_acs = true;
    }
    else {
        list = new ArrayList();
        if (rseq != null) {
            if (allTracks == null || allTracks.length ==0) {
                list.add("There are no tracks available for assignment ");
                break;
            }

        DbLink[] localLinks = DbLink.fetchAll( conn , false);
        if (rseq != null)
        shareLinks = DbLink.fetchShareLinks(rseq.getDatabaseName(), rseq.fetchDatabaseNames(db), db );
          // links from main and shared database are merge to one
            links  = LinkManagerHelper.mergeLinks(localLinks, shareLinks, out );
            if (links == null || links.length ==0)
                list.add("There are no links available for assigment ");

            if (!list.isEmpty())
                GenboreeMessage.setErrMsg(mys, "The assign operation failed:", list);

            if (links != null) {
                Arrays.sort(links);
                for(i=0; i<links.length; i++) {
                   linkid2index.put(links[i].getLinkId(), ""+i);
                }
          }

            if( old_db ) trackNames = (String []) mys.getAttribute( "featuretypes" );
            if( trackNames!=null && trackNames.length>0 ){
               trackLookup = new HashMap();
                for( i=0; i<trackNames.length; i++ )
                trackLookup.put( trackNames[i], "y" );
            }

            listSelectedTracks = new ArrayList();
            selectedLinks = new HashMap();
            String[] seltrackNames = request.getParameterValues( "trackName" );
            if( seltrackNames != null ){
                for( i=0; i<seltrackNames.length; i++ ){
                    htTrkSel.put( seltrackNames[i], "y" );
                }
            }

            db2Tracks = new HashMap ();
            for (int j=0; j<dbNames.length ; j++) {
               if (dbNames[j].compareTo(dbName)==0)
                   db2Tracks.put(dbName, localTrackList);
                else
                    db2Tracks.put(dbNames[j], sharedTrackList);

            }

           databaseNames = (String [])db2Tracks.keySet().toArray(new String [db2Tracks.size()]);
            for (i=0; i< databaseNames.length; i++) {
                String databaseName  = databaseNames[i];
                ArrayList tracklist = (ArrayList)db2Tracks.get(databaseName);

                boolean b =  databaseName.equals(dbName)  ;

                Connection con = null;
                if (!databaseName.equals(dbName))
                continue;

                con = db.getConnection(databaseName);
                dbtrack2links = LinkManagerHelper.mapTracks2Links (tracklist, con, out);
                localTrack2Links = dbtrack2links;
            }


              for (i=0; i< databaseNames.length; i++) {
                String databaseName  = databaseNames[i];
                ArrayList tracklist = (ArrayList)db2Tracks.get(databaseName);

                boolean b =  databaseName.equals(dbName)  ;

                Connection con = null;
                if (b)
                continue;

                con = db.getConnection(databaseName);
                 shareTrack2Links  = LinkManagerHelper.mapTracks2Links (tracklist, con, out);
              }





            // select local links based on the mapping
            for( i=0; i<allTracks.length; i++ ){
                DbFtype ft = allTracks[i];
                if( htTrkSel.get(""+ft.toString()) != null ){
                    listSelectedTracks.add( ft );
                    ArrayList linkIds  = new ArrayList();
                    if ( shareTrack2Links.get(ft.toString())!=null)
                        linkIds  =  (ArrayList)shareTrack2Links.get(ft.toString());

                    if (linkIds != null) {
                        for( int j=0; j<linkIds.size(); j++ ) {
                            String linkId = (String)linkIds.get(j);
                            DbLink link = (DbLink)id2Link.get(linkId);
                            if (link==null)
                              continue;
                            selectedLinks.put( linkId, link );
                        }
                    }

                    if ( localTrack2Links.get(ft.toString())!=null)
                        linkIds  =  (ArrayList)localTrack2Links.get(ft.toString());

                    if (linkIds != null){
                        for( int j=0; j<linkIds.size(); j++ ) {
                            String linkId = (String)linkIds.get(j);
                            DbLink link = (DbLink)id2Link.get(linkId);
                             if (link==null)
                              continue;
                            selectedLinks.put( linkId, link );
                        }
                    }
                }
            }

            DbLink [] selectedLinks1 = null;
            vBtn.addElement( btnAssign );
            vBtn.addElement( btnClear );

            if( request.getParameter(btnAssign[1]) != null ){
                String[] newLinkIds = request.getParameterValues("linkId");

                ArrayList selectedLinkIdsList =new  ArrayList();
                if (newLinkIds != null){
                    selectedLinks1 = new DbLink [newLinkIds.length];
                    for (i=0; i<newLinkIds.length; i++) {
                        selectedLinks1[i] = (DbLink)id2Link.get(newLinkIds[i]);
                        selectedLinkIdsList.add(newLinkIds[i]);
                    }


                }

                if( newLinkIds == null )
                    newLinkIds = new String[0];

                DbFtype ft = null;
                int numSuccess = 0;
                for( int j=0; j<listSelectedTracks.size(); j++ ){
                    ft = (DbFtype)listSelectedTracks.get(j);
                    String tempdbName = ft.getDatabaseName();
                    if (dbName.compareTo(tempdbName)!=0){
                     if (trackName2ftype.get(ft.toString())!= null) {
                      ft= (DbFtype)trackName2ftype.get(ft.toString());
                     }
                     else {
                     ft.insert(conn);
                     ft.setDatabaseName(dbName);

                     }


                    }
                    if (conn.isClosed())
                        conn = db.getConnection(dbName);

                     ArrayList linkIds  = new ArrayList();
                    if ( shareTrack2Links.get(ft.toString())!=null)
                        linkIds  =  (ArrayList)shareTrack2Links.get(ft.toString());
                     ArrayList selectedShareLinks = new ArrayList();
                   if (linkIds != null) {
                    for (i=0; i<linkIds.size(); i++) {
                        String id = (String) linkIds.get(i);
                        DbLink link = (DbLink)id2Link.get(id);
                       if (!selectedLinkIdsList.contains(id))
                          selectedShareLinks.add(link);
                    }
                   }
                    int newArrsize = 0;


                    if (selectedLinks1 != null)
                        newArrsize = selectedLinks1.length;
                     if (!selectedShareLinks.isEmpty() )
                         newArrsize = newArrsize + selectedShareLinks.size();

                    DbLink []  allSelectedLinks = new DbLink [newArrsize];

                    if (!selectedShareLinks.isEmpty() ) {
                        for (i=0; i<selectedShareLinks.size(); i++)
                        allSelectedLinks[i] = (DbLink)selectedShareLinks.get(i);
                    }

                      if (selectedLinks1 != null) {
                        for (i=0; i<selectedLinks1.length; i++)
                        allSelectedLinks[i+ selectedShareLinks.size()] = selectedLinks1[i];
                   }

                    selectedLinks1 =  allSelectedLinks;
   if (LinkUpdator.updateLinks( conn, ft, selectedLinks1, dbName, 0 ))
                        numSuccess ++;
                    if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
                }

                if (numSuccess > 0 && numSuccess == listSelectedTracks.size() )
                    GenboreeMessage.setSuccessMsg(mys, " The assign operation was successful. ");
                else if (listSelectedTracks == null && allTracks != null && allTracks.length >0){
                    list = new ArrayList();
                    list.add("Please select a track");
                    GenboreeMessage.setErrMsg(mys, " The assign operation failed:", list);
                }
                else if (links != null && links.length >0)
                    GenboreeMessage.setErrMsg(mys, " The assign operation failed.");

                selectedLinks.clear();
                if (selectedLinks1 != null && selectedLinks1.length>0) {
                    for(int  j=0; j<selectedLinks1.length; j++ ) {
                        DbLink lnk = selectedLinks1[j];
                        if (lnk != null) {
                        String lnkId = lnk.getLinkId();
                        selectedLinks.put( lnkId, lnk );
                        }
                    }
                }
            } // END OF REQUEST
    }}
    break; // MODE_ASSIGN
  }



    if (dbNames != null) {
        for (i=0; i< dbNames.length; i++) {
            String databaseName  = dbNames[i];
            Connection con = null;
            if (!databaseName.equals(dbName))
                con = db.getConnection(databaseName);
            else
                continue;

            dbtrack2links = LinkManagerHelper.mapTracks2Links (listSelectedTracks, con, out);
            if (i==0)
                shareTrack2Links  = dbtrack2links;
            else
                shareTrack2Links  = LinkManagerHelper.mapmerge(track2Links, dbtrack2links);
        }
    }




  // for unselected links, retrieve info from shared db
   if (listSelectedTracks != null && !listSelectedTracks.isEmpty()) {
        for( i=0; i<listSelectedTracks.size(); i++ ){
            String trackName = null;
            DbFtype ft = null;
            if (listSelectedTracks.get(i) != null)  {
                ft= (DbFtype)listSelectedTracks.get(i);
                trackName = ft.toString();
            }
            else
                continue;

            ArrayList linkIds  = null;
            if ( shareTrack2Links.get(trackName)!=null)
                linkIds =  (ArrayList)shareTrack2Links.get(trackName);

            if (linkIds != null){
                for( int j=0; j<linkIds.size(); j++ ){
                    String linkId = (String)linkIds.get(j);
                    DbLink link = (DbLink)id2Link.get(linkId);
                    if (link==null)
                        continue;
                         selectedLinks.remove( linkId );
                        selectedLinks.put( linkId, link );
                        link.setFromShareDb(true);
                       String index = (String)linkid2index.get(linkId);
                        int indexi = Integer.parseInt(index);
                        links [indexi].setFromShareDb(true);
                }
            }
        }
    }

    if (links != null)
    for( int j=0; j<links.length; j++ ){
        String linkid = links[j].getLinkId();
        if (sharedTrackList.contains(linkid))
            links[j].setFromShareDb(true);

        if (localTrackList.contains(linkid))
            links[j].setFromShareDb(false);
    }

     if( no_acs ) {
        GenboreeMessage.setErrMsg(mys, "Sorry, you do not have enough privileges to perform this operation.");
     }

     if( no_links ) {
        GenboreeMessage.setErrMsg(mys, "There is no links in this database. Please create some first.");
    }


  btnBack[2] = (mode==MODE_DEFAULT) ? "Cancel" : "Cancel";
  if (mode!=MODE_DEFAULT)
    vBtn.addElement( btnBack );
    else
        vBtn.addElement( btnBack );
%>
<HTML>
<head>
<title>Genboree - Link Setup</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">
<script src="/javaScripts/selectionUtil.js<%=jsVersion%>" type="text/javascript"></script>
<script src="/javaScripts/linkmgr.js<%=jsVersion%>" type="text/javascript"></script>
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY>
<%@ include file="include/sessionGrp.incl"%>
<%@ include file="include/header.incl" %>
<%@ include file="include/navbar.incl" %>
<table border="0" cellspacing="4" cellpadding="2">
<tr>
  <td><a href="<%=destback%>">&laquo;</a>&nbsp;&nbsp;</td>
  <td class="nav_selected">
  <a href="linkmgr.jsp"><font color=white>Link&nbsp;Setup</font></a>
  </td>
  <td>:&nbsp;</td>
<%
  for( i=0; i<modeIds.length; i++ )
  {
    String cls = "nav";
    String a1 = "<a href=\"linkmgr.jsp?mode="+modeIds[i]+"\">";
    String a2 = "</a>";
    if( i == mode )
    {
      cls = "nav_selected";
      a1 = a1 + "<font color=white>";
      a2 = "</font>" + a2;
    }
%>
<td class="<%=cls%>"><%=a1%><%=modeLabs[i]%><%=a2%></td>
<% } %>
  <td class="nav"><a href="trackmgr.jsp">Manage&nbsp;Tracks</a></td>
</tr>
</table>
<%@ include file="include/message.incl" %>
<%
  String onsubm = "";
  if( mode==MODE_CREATE || mode==MODE_UPDATE ){
    onsubm = "onSubmit=\"return validateForm(this);\"";
  }
%>

<form name="lnkmgr" id="lnkmgr" action="linkmgr.jsp" <%=onsubm%> method="post">
<% if( origMode != MODE_DEFAULT ) { %>
<input type="hidden" name="mode" id="mode" value="<%=modeIds[origMode]%>">
<input type="hidden" name="b2b" id="b2b" value="<%=mode%>">
<% } // if( mode != MODE_DEFAULT ) %>

<table border="0" cellpadding="4" cellspacing="2" width="100%">
<tr>
<%@ include file="include/groupbar.incl" %>
</tr>
<tr>
<%@ include file="include/databaseBar.incl" %>
</tr>
</table>

<div id="button_set1" style="float: left ; width: 95% ; margin-top: 5px ; margin-bottom: 5px ;" >
<%

    for( i=0; i<vBtn.size(); i++ ){
        if ( vBtn.elementAt(i) != null)
            btn = (String []) vBtn.elementAt(i);
        String onclick = (btn[3]==null) ? "" : " onClick=\""+btn[3]+"\"";
        %>
        <input type="<%=btn[0]%>" name="<%=btn[1]%>" id="<%=btn[1]%>"
        value="<%=btn[2]%>" class="btn"<%=onclick%>>
    <%  } %>
</div>
<%
    if( mode == MODE_DELETE || mode == MODE_ASSIGN ){
        %>
          <DIV style="float: right ; width: 5% ; text-align: right ; margin-top: 5px ; margin-bottom: 5px ;">
            <A HREF="showHelp.jsp?topic=linkSetup" target="_helpWin">
              <IMG class="" style="vertical-align: top;" SRC="/images/gHelp1.png" BORDER="0" WIDTH="16" HEIGHT="16"></SPAN></A>
          </DIV><BR CLEAR="all">
    <% } %>
    <BR clear="ALL">


<%
if (rseq!= null) {
    if( mode==MODE_CREATE || mode==MODE_UPDATE ) { %>
    <table border="0" cellpadding="4" cellspacing="0" width="100%">
        <tr>
            <td class="form_header" colspan="2">
                <strong>Link Editor
                <%= (mode==MODE_CREATE) ? "-- Create New Link" : "" %>
                </strong>
                <A HREF="showHelp.jsp?topic=linkSetup" target="_helpWin">
                <SPAN class="subtopicHeader">
                <IMG class="helpNavImg" SRC="/images/gHelp2.png" BORDER="0" WIDTH="16" HEIGHT="16">
                </SPAN>
                </A>
            </td>
        </tr>

<% if( mode==MODE_UPDATE ) { %>
  <tr>
  <td class="form_body"><strong>Link</strong></td>
  <td class="form_body">
  <select name="editLinkId" id="editLinkId"
  onChange="this.form.submit()"
   class="txt" style="width:580">
<%
 if (links != null)
  for( i=0; i<links.length; i++ )
  {
    DbLink lnk = links[i];
    String sel = (editLinkId.compareToIgnoreCase(lnk.getLinkId())==0) ? " selected" : "";

%>
<%if (lnk.getFromShareDb()) { %>
<option   value="<%=lnk.getLinkId()%>"<%=sel%>><%=Util.htmlQuote(lnk.getName())%>&nbsp<%=Util.htmlQuote("<TEMPLATE LINK>") %></option>
 <%}
 else {%>
    <option  value="<%=lnk.getLinkId()%>"<%=sel%>><%=Util.htmlQuote(lnk.getName())%></option>
<%}}%>
</select>
  </td>
  </tr>
<% } %>
  <%    if (rseq != null && editLink != null && editLink.getFromShareDb()) { %>
    <tr>
  <td class="form_body"><strong>Name</strong></td>

  <td class="form_body">
    <input READONLY type="text" name="link_name" id="link_name"
    class="txt" style="background-color: #C0C0C0; width:580" value="<%=Util.htmlQuote(editLink.getName())%>">
  </td>
  </tr>
    <tr>
  <td class="form_body"><strong>Pattern</strong></td>
  <td class="form_body">
    <input  READONLY type="text" name="link_pattern" id="link_pattern"
    class="txt" style="background-color: #C0C0C0; width:580" value="<%=Util.htmlQuote(editLink.getDescription())%>">
  </td>
  </tr>
     <% }
  else if (rseq!= null) {
      String name ="";
      if (editLink != null)
          name = editLink.getName();
      String desc = "";
          if (editLink != null)
          desc = editLink.getDescription();
  %>    <tr>
  <td class="form_body"><strong>Name</strong></td>

    <td class="form_body">
    <input type="text" name="link_name" id="link_name"
    class="txt" style="width:580" value="<%=Util.htmlQuote(name)%>">
  </td>
  </tr>
    <tr>
  <td class="form_body"><strong>Pattern</strong></td>
  <td class="form_body">
    <input type="text" name="link_pattern" id="link_pattern"
    class="txt" style="width:580" value="<%=Util.htmlQuote(desc)%>">
  </td>
  </tr>
       <%}%>
  </table>

  <% if (rseq!= null) {%>
  <!-- Quick Ref & Help -->
  <P>
  <A HREF="showHelp.jsp?topic=linkSetup" target="_helpWin"><IMG class="helpNavImg" SRC="/images/gHelp1.png" BORDER="0" WIDTH="16" HEIGHT="16"></A>Full documentation is available in the Genboree Help, section
  <A HREF="showHelp.jsp?topic=linkSetup" target="_helpWin"><SPAN class="helpTopic">&quot;6. Custom Links&quot;</SPAN></A>.
  <P>
  <SPAN class="subtopicHeader">Substitution Tag Quick-Reference:</SPAN>
  <P>
  <B>Simple Tags:</B>
  <P>
  <DIV style="font-size: 7pt ;">
  <UL class="compact4_bigIndent">
    <LI><b><a href="javascript:addtag('class')">$class</a></b></LI>
    <LI><b><a href="javascript:addtag('name')">$name</a></b> (but see &quot;Special Tags&quot; below)</LI>
    <LI><b><a href="javascript:addtag('type')">$type</a></b></LI>
    <LI><b><a href="javascript:addtag('subtype')">$subtype</a></b></LI>
    <LI><b><a href="javascript:addtag('entrypoint')">$entrypoint</a></b></LI>
    <LI><b><a href="javascript:addtag('start')">$start</a></b></LI>
    <LI><b><a href="javascript:addtag('stop')">$stop</a></b> (or <b>$end</b>)</LI>
    <LI><b><a href="javascript:addtag('strand')">$strand</a></b></LI>
    <LI><b><a href="javascript:addtag('phase')">$phase</a></b></LI>
    <LI><b><a href="javascript:addtag('score')">$score</a></b></LI>
    <LI><b><a href="javascript:addtag('qstart')">$qstart</a></b></LI>
    <LI><b><a href="javascript:addtag('qstop')">$qstop</a></b></LI>
    <LI><b><a href="javascript:addtag('comments')">$comments</a></b> (but see &quot;Regular Expression Tags&quot; below)</LI>
    <LI><b><a href="javascript:addVPtag('attName')">${"attName"}</a></b> (but see &quot;Regular Expression Tags&quot; below)</LI>
    <LI><b><a href="javascript:addtag('sequence')">$sequence</a></b></LI>
  </UL>
  </DIV>
  <P>
  <B>Regular Expression Tags:</B>
  <P>
  <DIV style="font-size: 7pt ;">
  <UL class="compact4_bigIndent">
    <LI><b><a href="javascript:addtag('{FIELD:REG(_)EXPR}')">${<FONT color="blue">&lt;field_name&gt;</FONT>:<FONT color="blue">&lt;regexp&gt;</FONT>}</a></b>
    <LI><b><a href="javascript:addVPRegtag('attName', 'REG(_)EXPR')">${<FONT color="blue">&lt;&quot;att_name&quot;&gt;</FONT>:<FONT color="blue">&lt;regexp&gt;</FONT>}</a></b>
      <UL class="compact2">
        <LI>- first sub-group in <FONT color="blue">&lt;regexp&gt;</FONT> used as replacement text</LI>
      </UL>
    </LI>
  </UL>
  </DIV>
  <P>
  <B>Special Tags:</B>
  <P>
  <DIV style="font-size: 7pt ;">
  <UL class="compact4_bigIndent">
    <LI><b><a href="javascript:addtag('stripName')">$stripName</a></b>
      <UL class="compact2">
        <LI>- Removes characters after, and including, the last <SPAN class="genbLabel">&quot;.&quot;</SPAN> from the <i>name</i>.</LI>
      </UL>
    </LI>
  </UL>
  </DIV>
  <P>
  <B>Genboree-Specific Tags:</B>
  <P>
  <DIV style="font-size: 7pt ;">
  <UL class="compact4_bigIndent">
     <LI><b><a href="javascript:addtag('genboreeRefSeqId')">$genboreeRefSeqId</a></b> The current database's id number (refSeqId)</LI>
     <!--
     <LI><b><a href="javascript:addtag('genboreeUserId')">$genboreeUserId</a></b> Internal tag to get the userId</LI>
     <LI><b><a href="javascript:addtag('genboreeGroupId')">$genboreeGroupId</a></b> Internal tag to get the current groupId</LI>
     <LI><b><a href="javascript:addtag('genboreeDbId')">$genboreeDbId</a></b> Internal tag to get the uploadId</LI>
     <LI><b><a href="javascript:addtag('genboreeAnnotId')">$genboreeAnnotId</a></b> Internal tag to get the fid</LI>
     <LI><b><a href="javascript:addtag('genboreeGroupId')">$genboreeGroupId</a></b> Internal tag to get annotation GroupId</LI>
      -->
  </UL>
  </DIV>

  <P>
  <!-- End Quick Ref & Helf -->
 <SCRIPT language="javascript">
function addtag( tag )
{
  var patt = document.lnkmgr.link_pattern;
  patt.value = patt.value + '$' + tag;
  patt.focus();
}

function addVPtag( tag )
{
  var patt = document.lnkmgr.link_pattern;
  patt.value = patt.value + '$' + '{\"' + tag + '\"}';
  patt.focus();
}


function addVPRegtag( tag, regex )
{
  var patt = document.lnkmgr.link_pattern;
  patt.value = patt.value + '$' + '{\"' + tag + '\"' + ':' + regex + '}';
  patt.focus();
}


</SCRIPT>
   <% }} // MODE_CREATE || MODE_UPDATE
    if( mode == MODE_DELETE ) { %>
  <table border="0" cellspacing="0" cellpadding="2" width="100%">
    <tr>
    <td class="form_header">Name</td>
    <td class="form_header">Pattern</td>
            <td class="form_header">From Genome Template</td>
    <td class="form_header" width="80">Delete</td>
    </tr>
    <%
     if (links!= null)
    for( i=0; i<links.length; i++ )
    {
        String altStyle = ((i%2) == 0) ? "form_body" : "bkgd";
        DbLink lnk = links[i];
        if (!lnk.getFromShareDb())  {
            %>
        <tr>
        <td class="<%=altStyle%>"><strong><%=Util.htmlQuote(lnk.getName())%></strong></td>
        <td class="<%=altStyle%>"><%=Util.htmlQuote(lnk.getDescription())%></td>
         <td READONLY class="<%=altStyle%>">No</td>
        <td class="<%=altStyle%>">
          <input type="checkbox" name="delLnkId" id="delLnkId"
          value="<%=lnk.getLinkId()%>">
        </td>
        </tr>
        <% }
        else  {
          %>
           <tr>
            <td READONLY class="<%=altStyle%>"><strong><%=Util.htmlQuote(lnk.getName())%></strong></td>
            <td READONLY class="<%=altStyle%>"><%=Util.htmlQuote(lnk.getDescription())%></td>
            <td READONLY class="<%=altStyle%>">Yes</td>
             <td class="<%=altStyle%>">
            </td>
        </tr>
            <% }
    } %>
 </table>
<% } // MODE_DELETE %>
<%
    if( mode == MODE_ASSIGN ) { %>
  <table border="0" cellspacing="2" cellpadding="4" width="100%">
    <tr>
    <td class="form_header">Tracks</td>
    <td class="form_header">Links</td>
    </tr>

 <%
  if (rseq != null)  { %>

  <tr>
  <td class="form_body">
  <select name="trackName" id="trackName" onchange="this.form.submit(); "  multiple size="16" class="txt" style="width:320">
<%
  if (allTracks != null)
  for( i=0; i<allTracks.length; i++ )
  {
    DbFtype ft = allTracks[i];
    String trackName = ft.toString();
    if( trackLookup!=null && trackLookup.get(trackName)==null ) continue;
    if( trackName.compareToIgnoreCase("Component:Chromosome") == 0 ||
      trackName.compareToIgnoreCase("Supercomponent:Sequence") == 0 )
      continue;

    String sel = listSelectedTracks.contains(ft) ? " selected" : "";

%>
<option value="<%=trackName%>" <%=sel%>><%=Util.htmlQuote(trackName)%></option>
<%
  }
%>  </select>
  </td>
  <td class="form_body">
  <select name="linkId" id="linkId" multiple size="16" class="txt" style="width:320">
    <%
      if (links != null)
      for( i=0; i<links.length; i++ )
      {
        DbLink lnk = links[i];
        String myId = ""+lnk.getLinkId();
        String sel = (selectedLinks.get(myId) != null) ? " selected" : "";
        String linkName = lnk.getName();
        if (lnk.getFromShareDb())
           linkName = linkName + " <TEMPLATE LINK>";

        if (localTrack2Links.get(myId) != null)
            linkName =  lnk.getName();
    %>
      <option value="<%=myId%>"<%=sel%>><%=Util.htmlQuote(linkName)%></option>
    <% } %>
    </select>
  </td>
  </tr>
 <%}%>
    </table>
<% } %>


<% if( origMode == MODE_DEFAULT && !no_links ) { %>
  <table border="0" cellspacing="0" cellpadding="2" width="100%">
    <tr>
    <td class="form_header">Name</td>
    <td class="form_header">Pattern</td>
    </tr>
<%     if (links!=null)
      for( i=0; i<links.length; i++ )
      {
        String altStyle = ((i%2) == 0) ? "form_body" : "bkgd";
        DbLink lnk = links[i];
       if (lnk.getFromShareDb()) {
%>
    <tr>
    <td class="<%=altStyle%>"><strong><%=Util.htmlQuote(lnk.getName())%></strong></td>
    <td class="<%=altStyle%>"><%=Util.htmlQuote(lnk.getDescription())%></td>
    </tr>
  <%} else {%>
     <tr>
    <td class="<%=altStyle%>"><strong><%=Util.htmlQuote(lnk.getName())%></strong></td>
    <td class="<%=altStyle%>"><%=Util.htmlQuote(lnk.getDescription())%></td>
    </tr>
<%}}%>
</table>
<% } // MODE_DEFAULT %>


<% if( mode != MODE_DEFAULT ) {
%>
<br>
<table border="0" cellpadding="4" cellspacing="0"><tr><td>
<%
  for( i=0; i<vBtn.size(); i++ )
  {
    btn = (String []) vBtn.elementAt(i);
    String onclick = (btn[3]==null) ? "" : " onClick=\""+btn[3]+"\"";
%><input type="<%=btn[0]%>" name="<%=btn[1]%>" id="<%=btn[1]%>"
  value="<%=btn[2]%>" class="btn"<%=onclick%>>
<%
  }
%>
</td></tr></table>
<% }
} %>
</form>
<%@ include file="include/footer.incl" %>
</BODY>


</HTML>
