<%@ page import="
  java.sql.*,
  java.util.*,
  org.json.JSONObject,
  org.json.JSONException,
  org.genboree.util.*,
  org.genboree.upload.*,
  org.genboree.dbaccess.*,
  org.genboree.dbaccess.util.*,
  org.genboree.tabular.Table,
  org.genboree.tabular.Utility,
  org.genboree.tabular.ColumnType"
%>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/group.incl" %>
<%
  //
  // Session management
  //
  // First remove any cached table
  if(session.getAttribute("tabularTable") != null)
    ((Table) session.getAttribute("tabularTable")).destroy() ;
  session.removeAttribute("tabularTable") ;

  // Now to give URL GETs priority over session attributes, add the GETs to the
  // session and then redirect to this page without any GET parameters
  // NOTE: We currently only do this for the trackName parameter, but any other
  //  paramaters could be handled in the same way. - SGD (Added landmark param)
  // NOTE: Currently the presence of the trackName GET parameter signals to the
  //  page to start a new 'layout session'.  This means all of the other stored
  //  tabular layout parameters are removed from the session.  This is somewhat
  //  arbitrary (because the only way to reach this page is from the gbrowser
  //  page, therefore the trackName parameter will always be a GET parameter
  //  for a new 'layout session'.  Additionally, the 'newLayout=true' parameter
  //  can be passed, but no pages yet implement this.  Without this parameter,
  //  a direct link to this page will possibly result in some layout settings
  //  appearing from the session, possibly unintended. - SGD
  if(request.getParameter("trackNames") != null || request.getParameter("trackName") != null
    || request.getParameter("landmark") != null)
  {
    String[] passedTracks = null ;
    String landmark = null ;
    if(request.getParameter("trackName") != null)
    {
      passedTracks = (String[]) request.getParameterValues("trackName") ;
    }
    else
    {
      String[] trackNameList = (String[])request.getParameterValues("trackNames") ;
      passedTracks = (String[])trackNameList[0].split(",") ;
    }

    if(request.getParameter("landmark") != null)
      landmark = request.getParameter("landmark") ;

    // Clear the other layout parameters out of the session
    session.removeAttribute("tabularLayout") ;
    session.removeAttribute("tabularLayoutName") ;
    session.removeAttribute("tabularLandmark") ;
    session.removeAttribute("tabularTracks") ;

    // The URL GET parameters have priority, replace anything in the session
    try
    {
      Refseq database = new Refseq() ;
      // Sameer: If refseqId is being provided, we need to update the database in the session. 
      if(request.getParameter("refseqId") != null)
      {
        String refseqId = request.getParameter("refseqId") ;
        session.setAttribute("currDatabaseID", refseqId) ;
        database.setRefSeqId(refseqId) ;
      }
      else
      {
        database.setRefSeqId(SessionManager.getSessionDatabaseId(session)) ;
      }


      if(database.fetch(db))
      {
        // First tracknames
        if(passedTracks != null && passedTracks.length > 0)
        {
          Vector<DbFtype> newTracks = Utility.getTracksFromNames(db,
            Integer.parseInt(myself.getUserId()), database, passedTracks) ;
          session.setAttribute("tabularTracks", newTracks) ;
        }

        // Now landmark
        if(landmark != null && landmark.length() > 0)
        {
          session.setAttribute("tabularLandmark", landmark) ;
        }

        // Now redirect to our page
        GenboreeUtils.sendRedirect(request, response, "/java-bin/tabular.jsp") ;
        return ;
      }
      else
      {
        System.err.println("tabular.jsp: Tracks passed as GET parameters, but problem " +
          "getting database from the session") ;
      }
    }
    catch(NumberFormatException e)
    {
      System.err.println("tabular.jsp: Cannot parse my user id as an integer: " + e) ;
    }
  }
  else if(new String("true").equals(request.getParameter("newLayout")))
  {
    // Clear all layout parameters out of the session
    session.removeAttribute("tabularTracks") ;
    session.removeAttribute("tabularLayout") ;
    session.removeAttribute("tabularLayoutName") ;
    session.removeAttribute("tabularLandmark") ;
    GenboreeUtils.sendRedirect(request, response, "/java-bin/tabular.jsp") ;
  }

  // Turn off caching for this page (can cause inconsistencies for the ajax code)
  response.addHeader( "Cache-Control", "no-cache, no-store" );
%>
<HTML>
<head>
  <meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
  <title>Genboree - Setup a Tabular View</title>
  <!-- Styling for the multi-select style uls -->
  <style>
  div.list
  {
    margin: 0 6px;
    width: 31%;
    float: left;
  }

  div.list ul#display_order li,
  div.list ul#sorting_order li
  {
    cursor: move;
  }

  ul.checklist
  {
    border: 1px solid #aaaaaa;
    background-color: #ffffff;
    list-style: none;
    height: 35em;
    width: 100%;
    overflow: auto;
  }

  ul.sm
  {
    height: 16.75em;
  }

  ul.checklist li
  {
    background-color: transparent;
    white-space: nowrap;
    margin: 0;
    padding: 0;
    border: 0;
  }

  ul.checklist li.displayed
  {
    background: #eadee9;
  }

  ul.checklist li.sorted
  {
    background: #dde8f3;
  }

  ul.checklist li.dispsort
  {
    background: #cbcee2;
  }

  ul.checklist li:hover, ul.checklist li.hover
  {
    background: #777;
  }

  ul.checklist li:hover label, ul.checklist li.hover label
  {
    color: #fff;
  }

  option.empty, ul.checklist li.empty
  {
    color: #bbbbbb;
  }
  </style>
  <script>
<%
    // Expose config values to the JS code as necessary
    out.write("var numAnnosForTabularWarning = " +
      GenboreeConfig.getIntConfigParam("numAnnosForTabularWarning", 0) + " ;\n") ;
    out.write("var tabularMaxRows = " +
      GenboreeConfig.getIntConfigParam("tabularMaxRows", 0)  + " ;\n") ;
    // Expose our write permissions
    String writeAccess = "r";
    if(grp.isOwner(myself.getUserId())) writeAccess = "o" ;
    else if(!grp.isReadOnly(myself.getUserId())) writeAccess = "w" ;
%>
  </script>
</head>
<body onLoad="initTabularSetup('<%= writeAccess %>');">
  <!-- BEGIN: Scriptaculous support -->
  <script type="text/javascript" src="/javaScripts/prototype.js<%=jsVersion%>"></script>
  <script type="text/javascript" src="/javaScripts/scriptaculous.js<%=jsVersion%>&load=effects,dragdrop"></script>
  <!-- END -->

  <!-- BEGIN: Extjs 2.2 support (for MessageBox) -->
  <link rel="stylesheet" type="text/css" href="/javaScripts/ext-2.2/resources/css/window.css<%=jsVersion%>"/>
  <link rel="stylesheet" type="text/css" href="/javaScripts/ext-2.2/resources/css/dialog.css<%=jsVersion%>"/>
  <link rel="stylesheet" type="text/css" href="/javaScripts/ext-2.2/resources/css/panel.css<%=jsVersion%>"/>
  <link rel="stylesheet" type="text/css" href="/javaScripts/ext-2.2/resources/css/core.css<%=jsVersion%>"/>
  <script type="text/javascript" src="/javaScripts/ext-2.2/adapter/ext/ext-base.js<%=jsVersion%>"></script>
  <script type="text/javascript" src="/javaScripts/ext-2.2/ext-all.js<%=jsVersion%>"></script>
  <!-- Set a local "blank" image file; default is a URL to extjs.com -->
  <script type='text/javascript'>
    Ext.BLANK_IMAGE_URL = '/javaScripts/extjs/resources/images/genboree/s.gif';
  </script>
  <!-- END -->

  <!-- BEGIN: Genboree Specific -->
  <link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
  <link rel="stylesheet" href="/styles/avp.css<%=jsVersion%>" type="text/css">
  <LINK rel="stylesheet" href="/styles/querytool.css<%=jsVersion%>" type="text/css">
  <link rel="stylesheet" href="/styles/annotationEditor.css<%=jsVersion%>" type="text/css">
  <link rel="stylesheet" href="/styles/vgpConfig.css<%=jsVersion%>" type="text/css">
  <script type="text/javascript" src="/javaScripts/util.js<%=jsVersion%>"></script>
  <script type="text/javascript" src="/javaScripts/ajax.js<%= jsVersion %>"></script>
  <script type="text/javascript" src="/javaScripts/tabular.js<%= jsVersion %>"></script>
  <script type="text/javascript" src="/javaScripts/tabular-help.js<%= jsVersion %>"></script>
  <!-- END -->

  <%@ include file="include/header.incl" %>
  <%@ include file="include/navbar.incl" %>

<%
  String debug = GenboreeConfig.getConfigParam("debugTabularView");
  if(debug != null && debug.equals("true"))
  {
    int maxRows = GenboreeConfig.getIntConfigParam("tabularMaxRows", -1) ;
    int warning = GenboreeConfig.getIntConfigParam("numAnnosForTabularWarning", -1) ;
    out.write("<div id='debug' style='margin-bottom: 15px;'>") ;
    out.write("Used Memory: " + Util.commify(MemoryUtil.usedMemory()/1024/1024) + " MB");
    if(maxRows < 0)
      out.write("<br><br>The required parameter " +
        "<em><strong><code>tabularMaxRows</code></strong></em> " +
        "is missing or set to an invalid value in your config file.") ;
    if(warning < 0)
      out.write("<br><br>The parameter " +
        "<em><strong><code>numAnnosForTabularWarning</code></strong></em> " +
        "is missing or set to an invalid value in your config file.") ;
    out.write("</div>") ;
  }
%>

  <table cellspacing="2" cellpadding="4" border="0" width="100%">
    <!-- Group Selection: -->
    <%@ include file="include/ajax/groupBar.incl" %>
    <!-- Database Selection: -->
    <%@ include file="include/ajax/databaseBar.incl" %>
  </table>
  <div id="main">
    <div id="container">
      <h1 style="font-size: 1.25em; color: #403C80; font-weight: bold; margin: 8px 0">
        Step 1: Select Annotation Data for the Table
      </h1>
      <div id="content">
        <!-- Track Selection: -->
<%
        String options = "" ;
        int count = 0 ;
        Refseq database = new Refseq() ;
        database.setRefSeqId(SessionManager.getSessionDatabaseId(mys)) ;
        if(database.fetch(db))
        {
          Vector<String> visibleTracks = new Vector<String>() ;
          Vector<String> emptyTracks = new Vector<String>() ;
          String[] dbNames = database.fetchDatabaseNames(db) ;
          for(int num = 0; num < dbNames.length; num++)
          {
            Connection connection = db.getConnection(dbNames[num]) ;
            if(connection != null)
            {
              try
              {
                DbFtype[] tracks = DbFtype.fetchAll(connection, dbNames[num], Integer.parseInt(myself.getUserId())) ;
                for(DbFtype track : tracks)
                {
                  // Check track permissions
                  if( !TrackPermission.isTrackAllowed(dbNames[num], track.getFmethod(), track.getFsource(),Integer.parseInt(myself.getUserId()))
                      || FtypeTable.isTrackDownloadBlocked(connection, track.getTrackName()) )
                  {
                    continue ;
                  }

                  // Duplicate Track name (different db, same track)
                  if(!visibleTracks.contains(track.getTrackName()))
                  {
                    visibleTracks.add(track.getTrackName()) ;
                    if(track.isEmpty(db))
                      emptyTracks.add(track.getTrackName()) ;
                  }

                  // Duplicate track has data (track is no longer empty)
                  if(!track.isEmpty(db) && emptyTracks.contains(track.getTrackName()))
                    emptyTracks.remove(track.getTrackName()) ;
                }
              }
              catch (NumberFormatException e)
              {
                System.err.println("tabular.jsp: Cannot parse my user id as an integer: " + e) ;
              }
            }
            else
            {
              System.err.println("tabular.jsp: Cannot get a connection to database - (" +
                dbNames[num] + ")") ;
            }
          }

          // Now display the tracks
          Collections.sort(visibleTracks) ;
          for(String track : visibleTracks)
          {
            count++ ;
            options += "<option value=\"" + track.replaceAll("\"", "&quot;") + "\"" ;
            options += (emptyTracks.contains(track)) ? " class=\"empty\"" : "" ;

            // Check if this track should be set as selected
            if(session.getAttribute("tabularTracks") != null)
            {
              // Already in Session
              Vector<DbFtype> selectedTracks = (Vector<DbFtype>) session.getAttribute("tabularTracks") ;
              for(DbFtype selected : selectedTracks)
              {
                if(selected.getTrackName().equals(track))
                {
                  options += " selected" ;
                  break ;
                }
              }
            }

            // Finish this option up
            options += ">" + track + "</option>\n" ;
          }
        }
        else
        {
          // Database isn't set correctly in the session,
          // Clear any session tracks and entry points
          session.removeAttribute("tabularTracks");
          session.removeAttribute("tabularEPs");
        }
%>
        <fieldset>
          <legend>Track</legend>
          <div id='trackNumberLabel'>
            <%= count == 0 ? "Please select a database..." : count + " tracks:" %>
          </div>
          <div id="track_names_mask">
            <select style='width:540px; margin-top: 5px;"' id='track_names' size='15'
            multiple='true' class='txt' onChange="updateTrack(this);">
              <%= options %>
            </select>
          </div>
        </fieldset>
        <fieldset>
          <legend>Location</legend>
<%
          // TODO - Check with Andrew to see if I should get Entry Points from all
          // databases including shared ones...

          // Check for a valid database selection
          String selectDisplay = "" ;
          String textDisplay = "display:none" ;
          String sessionEp = "" ;
          int sessionStart = -1, sessionStop = -1 ;
          Connection localDbConn = db.getConnection(database.getDatabaseName()) ;
          if(localDbConn != null)
          {
            // Check for previous settings from the session
            if(session.getAttribute("tabularLandmark") != null)
            {
              sessionEp = session.getAttribute("tabularLandmark").toString() ;
              if(sessionEp.indexOf(':') != -1 && sessionEp.indexOf('-') != -1)
              {
                try
                {
                  sessionStart = Integer.parseInt(
                    sessionEp.substring(sessionEp.indexOf(':') + 1, sessionEp.indexOf('-'))) ;
                  sessionStop = Integer.parseInt(
                    sessionEp.substring(sessionEp.indexOf('-') + 1)) ;
                  sessionEp = sessionEp.substring(0, sessionEp.indexOf(':')) ;
                }
                catch (NumberFormatException e)
                {
                  System.err.println("tabular.jsp: Landmark start/stop value in session " +
                    "is corrupt") ;
                }
              }
              else
              {
                System.err.println("tabular.jsp: Landmark value in session is corrupt") ;
              }
            }

            // Now check our display type (textfield or drop down)
            int totalEntryPoints = DbFref.countAll(localDbConn) ;
            if(totalEntryPoints <= Constants.GB_MAX_FREF_FOR_DROPLIST)
            {
              // Sort the list
              DbFref[] eps = DbFref.fetchAll(localDbConn) ;
              Arrays.sort(eps, new EntryPointComparator()) ;

              // Create a dropdown
              options = "<option value='all'>All Entry Points</option>\n" ;
              for(DbFref entryPoint : eps)
              {
                options += "<option value='" + entryPoint.getRefname() + "'" ;
                if(entryPoint.getRefname().equals(sessionEp)) options += " selected" ;
                options += ">";
                options += entryPoint.getRefname() + "</option>\n" ;
              }
            }
            else
            {
              // Create a textfield
              selectDisplay = "display:none" ;
              textDisplay = "" ;
            }
          }
          else
          {
            options = "<option>Please select a database first...</option>" ;
          }
%>
          <div style="position: relative; padding: .5em; <%= selectDisplay %>">
            <label for="entry_point">Entry Point</label>
            <div style="position: absolute; left: 10em; top: .1em;">
              <select id='entry_point' style="width: 140px;"
              onChange="$('entry_point_text').value = this.value; updateEntryPoint(this.value);">
                <%= options %>
              </select>
            </div>
          </div>
          <div style="position: relative; padding: .5em; <%= textDisplay %>">
            <label for="entry_point_text">Entry Point</label>
            <div style="position: absolute; left: 10em; top: .2em;">
              <input type='text' id='entry_point_text' style="width: 140px;"
                value='<%= (sessionEp.equals("")) ? "all" : sessionEp %>'>
            </div>
          </div>
          <div style="position: relative; padding: .5em;">
            <label for="ep_start">Start</label>
            <div style="position: absolute; left: 10em; top: .2em;">
              <input type='text' id='ep_start' style="width: 140px;"
              value='<%= (sessionStart >= 0) ? sessionStart : "" %>'
              <%=(sessionEp.equals("")) ? " disabled" : ""%>>
            </div>
            <span id="entry_point_min" style="position: absolute; left: 30em; top: .5em;"></span>
          </div>
          <div style="position: relative; padding: .5em;">
            <label for="ep_stop">Stop</label>
            <div style="position: absolute; left: 10em; top: .2em;">
              <input type='text' id='ep_stop' style="width: 140px;"
              value='<%= (sessionStop >= 0) ? sessionStop : "" %>'
              <%=(sessionEp.equals("")) ? " disabled" : ""%>>
            </div>
            <span id="entry_point_max" style="position: absolute; left: 30em; top: .5em;"></span>
          </div>
        </fieldset>
      </div>
      <h1 style="font-size: 1.25em; color: #403C80; font-weight: bold; margin: 8px 0">
        Step 2: Modify the Layout of the Table
      </h1>
      <div id="content">
        <!-- Step 2 contents -->
        <fieldset>
          <legend>Layout Name
<%
          // First check for a layout name from the session
          String sessionLayoutName = "" ;
          String[] sessionCols = new String[0], sessionSort = new String[0] ;
          if(session.getAttribute("tabularLayoutName") != null)
            sessionLayoutName = session.getAttribute("tabularLayoutName").toString() ;
          if(session.getAttribute("tabularLayout") != null)
          {
            sessionLayoutName = grp.isReadOnly(myself.getUserId()) ? "temp" : "new" ;
            try
            {
              JSONObject json = new JSONObject(
                session.getAttribute("tabularLayout").toString()) ;
              sessionCols = json.getString("columns").split(",") ;
              sessionSort = json.getString("sort").split(",") ;
            }
            catch(JSONException e)
            {
              System.err.println("tabular.jsp: Problem with layout JSON string: " + e) ;
            }
          }
%>
          <a href="javascript:void(0);"
          onClick="return displayHelpPopup(this, tabularHelp[1]['text'], tabularHelp[1]['title']);">
            <img src="/images/gHelp1.png" border="0">
          </a>
          </legend>
          <select id='layout_name_list' onChange="handleLayoutChange();" style="margin-top: 5px;">
            <optgroup label="Defaults">
              <option value="default">Default Grouped Layout</option>
              <option value="default2">Default Ungrouped Layout</option>
            </optgroup>
            <optgroup label="Create">
<%
            if(grp.isReadOnly(myself.getUserId()))
            {
              out.write("<option value='temp'") ;
              if(sessionLayoutName.equals("temp")) out.write(" selected") ;
              out.write(">Create Temporary Layout</option>") ;
            }
            else
            {
              out.write("<option value='new'") ;
              if(sessionLayoutName.equals("new")) out.write(" selected") ;
              out.write(">Create New Layout</option>") ;
            }
%>
            </optgroup>
            <optgroup label="Saved" id="layout_name_list_saved">
<%
            if(database != null)
            {
              // List all the tabular layouts for this database
              try
              {
                Connection conn = db.getConnection(database.getDatabaseName()) ;
                TabularLayout[] layouts = TabularLayout.fetchAll(conn) ;
                if(layouts == null) throw new SQLException("Unknown error, nothing reported") ;
                for(TabularLayout layout : layouts)
                {
                  out.write("<option value=\"saved-") ;
                  out.write(layout.getName().replaceAll("\"", "&quot;") + "\"") ;
                  out.write(sessionLayoutName.equals(layout.getName()) ? " selected" : "") ;
                  out.write(">") ;
                  out.write(layout.getName() + "</option>") ;
                }
              }
              catch(SQLException e)
              {
                System.err.println("java-bin/tabular.jsp: Error fetching layouts for " +
                  database.getDatabaseName() + ": " + e) ;
                // TODO - notify user
              }
            }
%>
            </optgroup>
          </select>
          <label id="layout_create_name_label" style="display: none; margin-left: 2em;">New Layout Name:
            <input id="layout_create_name" type="text" style="width: 140px;"
              onKeyPress="if(event.keyCode == 13) handleLayoutSave();">
          </label>
          <span id='layout_modified' style='display: none; margin-left: 2em;'><em>* modified</em></span>
          <div style="margin-top: 10px;">
            <input id='layout_save_update' type='button' onClick="handleLayoutSave();"
            value="Save / Update" <%= grp.isReadOnly(myself.getUserId()) ? " disabled" : "" %>>
            <input id='layout_delete' type='button' onClick="handleLayoutDelete();" value="Delete"
            <%= grp.isOwner(myself.getUserId()) ? "" : " disabled" %>>
          </div>
          <div id="layout_name_feedback" class="feedback" style="display: none;"><div></div></div>
        </fieldset>
        <fieldset>
          <legend>
            Layout Setup
            <a href="javascript:void(0);"
            onClick="return displayHelpPopup(this, tabularHelp[2]['text'], tabularHelp[2]['title']);">
              <img src="/images/gHelp1.png" border="0">
            </a>
          </legend>
<%
          Vector<String> attributes = new Vector<String>() ;
          if (session.getAttribute("tabularTracks") != null)
          {
            attributes = Utility.listAttributes(db,
              (Vector<DbFtype>) session.getAttribute("tabularTracks")) ;
          }
%>
          <div class="list">
            Core Annotation Attributes
            <ul id="default_attributes" class="checklist">
<%
              ColumnType[] lff = ColumnType.getTabularDefaults() ;
              for(int defs = 0; defs < lff.length; defs++)
              {
                boolean display = false, sort = false ;
                for(int check = 0; check < sessionCols.length; check++)
                  if(sessionCols[check].equals("l" + lff[defs]))
                    display = true ;
                for(int check = 0; check < sessionSort.length; check++)
                  if(sessionSort[check].equals("l" + lff[defs]))
                    sort = true ;
%>
                <li id='l<%= lff[defs] %>' onclick="colorCode(this)">
                  <input type="checkbox" title="Display" id="l<%= lff[defs] %>-display-check"
                    onclick='control("display_order", this)'
                    <%= display ? "checked" : "" %> value="l<%= lff[defs] %>">
                  <input type="checkbox" title="Sort" id="l<%= lff[defs] %>-sort-check"
                    onclick='control("sorting_order", this)'
                    <%= sort ? "checked" : "" %> value="l<%= lff[defs] %>"
                    <%= lff[defs].isSortable() ? "" : " disabled"%>>
                  <%= lff[defs] %>
                </li>
<%
              }
%>
            </ul>
          </div>
          <div class="list">
            User-Defined Attributes
            <ul id="all_attributes" class="checklist">
<%
              // Add all attributes from what is in the session
              for(int cols = 0; cols < attributes.size(); cols++)
              {
                boolean display = false, sort = false ;
                for(int check = 0; check < sessionCols.length; check++)
                  if(sessionCols[check].equals("a" + attributes.get(cols)))
                    display = true ;
                for(int check = 0; check < sessionSort.length; check++)
                  if(sessionSort[check].equals("a" + attributes.get(cols)))
                    sort = true ;
%>
                <li id='a<%= attributes.get(cols) %>' onclick="colorCode(this)">
                  <input type="checkbox" title="Display" id="a<%= attributes.get(cols) %>-display-check"
                    onclick='control("display_order", this)'
                    <%= display ? "checked" : "" %> value="a<%= attributes.get(cols) %>">
                  <input type="checkbox" title="Sort" id="a<%= attributes.get(cols) %>-sort-check"
                    onclick='control("sorting_order", this)'
                    <%= sort ? "checked" : "" %> value="a<%= attributes.get(cols) %>">
                  <%= attributes.get(cols) %>
                </li>
<%
              }

              // Save all missing attributes in a list
              Vector<String> missingAttrs = new Vector<String>() ;

              // We have to look for any attributes that might be from
              // this saved or temp layout, but not exist in the track
              // First, check for attributes from the display
              for(int disp = 0; disp < sessionCols.length; disp++)
              {
                if(sessionCols[disp].charAt(0) == 'a' && !attributes.contains(sessionCols[disp].substring(1)))
                {
                  boolean sort = false ;
                  for(int check = 0; check < sessionSort.length; check++)
                    if(sessionSort[check].equals(sessionCols[disp]))
                      sort = true ;

                  missingAttrs.add(sessionCols[disp]) ;
%>
                  <li id='<%= sessionCols[disp] %>' onclick="colorCode(this)" class="empty">
                    <input type="checkbox" title="Display" id="<%= sessionCols[disp] %>-display-check"
                      onclick='control("display_order", this)' checked value="<%= sessionCols[disp] %>">
                    <input type="checkbox" title="Sort" id="<%= sessionCols[disp] %>-sort-check"
                      onclick='control("sorting_order", this)'
                      <%= sort ? "checked" : "disabled" %> value="<%= sessionCols[disp] %>">
                    <%= sessionCols[disp].substring(1) %>
                  </li>
<%
                }
              }

              // Now, from the sort
              for(int sort = 0; sort < sessionSort.length; sort++)
              {
                if(sessionSort[sort].charAt(0) == 'a' && !attributes.contains(sessionSort[sort].substring(1)))
                {
                  boolean display = false ;
                  for(int check = 0; check < sessionCols.length; check++)
                    if(sessionCols[check].equals(sessionSort[sort]))
                      display = true ;
                  if(display) continue ; // Was already handled

                  missingAttrs.add(sessionSort[sort]) ;
%>
                  <li id='<%= sessionSort[sort] %>' onclick="colorCode(this)" class="empty">
                    <input type="checkbox" title="Display" id="<%= sessionSort[sort] %>-display-check"
                      onclick='control("display_order", this)' disabled value="<%= sessionSort[sort] %>">
                    <input type="checkbox" title="Sort" id="<%= sessionSort[sort] %>-sort-check"
                      onclick='control("sorting_order", this)' checked value="<%= sessionSort[sort] %>">
                    <%= sessionSort[sort].substring(1) %>
                  </li>
<%
                }
              }
%>
            </ul>
          </div>
          <div class="list">
            Order of Columns
            <ul id="display_order" class="checklist sm">
<%
              for(int cols = 0; cols < sessionCols.length; cols++)
              {
                boolean miss = missingAttrs.contains(sessionCols[cols]) ;
%>
                <li id="<%= sessionCols[cols] %>-display_order" <%= miss ? "class='empty'" : "" %>>
                  <%= (miss ? "( " : "") + sessionCols[cols].substring(1) + (miss ? " )" : "") %>
                  <input type="hidden" value="<%= sessionCols[cols] %>">
                </li>
<%
              }
%>
            </ul>
            Sorting Order
            <ul id="sorting_order" class="checklist sm">
<%
              for(int cols = 0; cols < sessionSort.length; cols++)
              {
                boolean miss = missingAttrs.contains(sessionSort[cols]) ;
%>
                <li id="<%= sessionSort[cols] %>-sorting_order" <%= miss ? "class='empty'" : "" %>>
                  <%= (miss ? "( " : "") + sessionSort[cols].substring(1) + (miss ? " )" : "") %>
                  <input type="hidden" value="<%= sessionSort[cols] %>">
                </li>
<%
              }
%>
            </ul>
          </div>
          <div style="clear: both;"></div>
        </fieldset>
<%
        boolean groupMode = true, terse = true ;
        if(session.getAttribute("tabularLayout") != null)
        {
          try
          {
            JSONObject json = new JSONObject(
              session.getAttribute("tabularLayout").toString()) ;
            groupMode = json.has("groupMode") ;
            if(groupMode) terse = json.getString("groupMode").equals("terse") ;
          }
          catch(JSONException e)
          {
            System.err.println("tabular.jsp: Problem with layout JSON string: " + e) ;
          }
        }
%>
        <fieldset>
          <legend>
            Grouping
            <a href="javascript:void(0);"
            onClick="return displayHelpPopup(this, tabularHelp[0]['text'], tabularHelp[0]['title']);">
              <img src="/images/gHelp1.png" border="0">
            </a>
          </legend>
          <input type="checkbox" id="useGroups" value="true" <%= (groupMode ? "checked" : "") %>
          onCLick="handleGroupClick(this) ;">
          <label for="useGroups">Show annotation groups, not individual annotations</label>
          <div style="margin-top: 15px;">
            <input type="radio" name="groupMode" id="terseGroupMode" value="terse"
            <%= (terse ? "checked" : "") %> <%= (groupMode ? "" : "disabled") %>
            onClick="modifyLayout(true);">
            <label for="terseGroupMode">Terse Mode</label>
            <br>
            <input type="radio" name="groupMode" id="verboseGroupMode" value="verbose"
            <%= (terse ? "" : "checked") %> <%= (groupMode ? "" : "disabled") %>
            onClick="modifyLayout(true);">
            <label for="verboseGroupMode">Verbose Mode</label>
          </div>
        </fieldset>
        <div style="text-align: right; padding: 10px;">
          <input type='button' value='Generate Table' onclick='generateTabularLayout();'>
          <input type='button' value='Download Data File' onclick='downloadTabularLayout();'>
        </div>
      </div>
    </div>
  </div>
  <script>
<%
    // Output the group name for Javascript REST API calls
    if(SessionManager.getSessionGroupName(mys) != null)
      out.print("grpName = '" + SessionManager.getSessionGroupName(mys).replaceAll("'", "\\\\'") + "' ;\n") ;
    else
      out.print("grpName = '" + grp.getGroupName() + "' ;\n") ;

    // Output the db name for Javascript REST API calls
    if (SessionManager.getSessionDatabaseId(mys) != null)
    {
      String dbId = SessionManager.getSessionDatabaseId(mys) ;
      out.print("dbName = '" + SessionManager.findRefSeqName(dbId, db).replaceAll("'", "\\\\'") + "' ;\n") ;
    }
%>
  </script>
  <%@ include file="include/footer.incl" %>
</BODY>
</HTML>
