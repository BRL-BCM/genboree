<%@ page import="
  java.util.Date,
  java.net.URLEncoder,
  java.io.UnsupportedEncodingException,
  java.text.SimpleDateFormat,
  org.json.JSONObject,
  org.json.JSONException,
  org.genboree.util.Util,
  org.genboree.util.Constants,
  org.genboree.util.MemoryUtil,
  org.genboree.util.GenboreeUtils,
  org.genboree.util.GenboreeConfig,
  org.genboree.util.SessionManager,
  org.genboree.dbaccess.DbFtype,
  org.genboree.dbaccess.IDFinder,
  org.genboree.tabular.Row,
  org.genboree.tabular.Table,
  org.genboree.tabular.ColumnType"
%><%@ include file="include/fwdurl.incl" %><%
  // Constant to affect download file speed
  final int BLOCK_SIZE = 10000 ;
  String columns = null ;
  String sort = null ;
  String groupMode = null ;
  String landmark = null ;
  Refseq database = new Refseq() ;
  Vector<DbFtype> tracks = new Vector<DbFtype>() ;

  // Determine if we have any URL parameters (or missing session attributes)
  if(request.getQueryString() != null)
  {
    // Forward to the setup page with all of the GET parmeters encoded
    GenboreeUtils.sendRedirect(request, response, "/java-bin/tabularSetup.jsp?" +
      request.getQueryString()) ;
    return ;
  }

  // Get a DBAgent to use
  DBAgent dbAgent = DBAgent.getInstance() ;

  // If no download was requested from the form, build the Table from scratch
  long timer = System.currentTimeMillis() ;
  Table tabular = null ;
  if(new String("true").equals(request.getParameter("download"))
    && session.getAttribute("tabularTable") != null)
  {
    tabular = (Table) session.getAttribute("tabularTable") ;
  }
  else
  {
    session.removeAttribute("tabularTable") ;

    // NOTE: cannot include userinfo.incl because it would be included multiple
    //   times from the call to group.incl...  Cannot include group.incl
    //   because it will output multiple blank lines into the downloaded file.
    //   Therefore, several common activities (access checks, convenience
    //   variables, etc.) must be duplicated on this page.  Not ideal, but
    //   functional.

    // Test for a valid RefSeq
    database.setRefSeqId(SessionManager.getSessionDatabaseId(session));
    if(!database.fetch(dbAgent))
    {
      System.err.println("tabularDisplay.jsp: Problem getting Refseq object for id - " +
        SessionManager.getSessionDatabaseId(session)) ;
      GenboreeUtils.sendRedirect(request, response, "/java-bin/tabular.jsp") ;
      return ;
    }

    // Check for empty tracks
    if(session.getAttribute("tabularTracks") != null)
      tracks = (Vector<DbFtype>) session.getAttribute("tabularTracks") ;
    if(tracks.size() == 0)
    {
      System.err.println("tabularDisplay.jsp: Cannot find any tracks!!") ;
      GenboreeUtils.sendRedirect(request, response, "/java-bin/tabular.jsp") ;
      return ;
    }

    // Get the landmark
    if(session.getAttribute("tabularLandmark") != null)
      landmark = session.getAttribute("tabularLandmark").toString() ;

    // Determine how to get the layout
    if(session.getAttribute("tabularLayout") != null)
    {
      // Layout defined in the session
      try
      {
        JSONObject json = new JSONObject(session.getAttribute("tabularLayout").toString()) ;
        columns = json.getString("columns") ;
        if(json.has("sort")) sort = json.getString("sort") ;
        if(json.has("groupMode")) groupMode = json.getString("groupMode") ;
      }
      catch(JSONException e)
      {
        System.err.println("tabularDisplay.jsp: Problem parsing layout in session: " + e) ;
        GenboreeUtils.sendRedirect(request, response, "/java-bin/tabular.jsp") ;
        return ;
      }
    }
    else if(session.getAttribute("tabularLayoutName") != null)
    {
      // Get layout from the DB
      String layoutName = session.getAttribute("tabularLayoutName").toString() ;
      try
      {
        TabularLayout layout = TabularLayout.fetchByName(
          dbAgent.getConnection(database.getDatabaseName()), layoutName) ;

        if(layout == null) throw new SQLException("Cannot find layout by that name: " + layoutName) ;
        columns = layout.getColumns() ;
        sort = layout.getSort() ;
        groupMode = layout.getGroupMode() ;
      }
      catch(SQLException e)
      {
        System.err.println("java-bin/tabularDisplay.jsp: Problem fetching layout from DB: " + e) ;
        GenboreeUtils.sendRedirect(request, response, "/java-bin/tabular.jsp") ;
        return ;
      }
    }
    else
    {
      // Some problem has occurred
      System.err.println("tabularDisplay.jsp: Missing both layout and layout name in session "+
        "(one or the other is required)") ;
      GenboreeUtils.sendRedirect(request, response, "/java-bin/tabular.jsp") ;
      return ;
    }

    // Create the table object
    if(groupMode == null)
      tabular = new Table(dbAgent, tracks, columns, Table.UNGROUPED, sort, landmark) ;
    else if(groupMode.equals("verbose"))
      tabular = new Table(dbAgent, tracks, columns, Table.GROUPED_VERBOSE, sort, landmark) ;
    else if(groupMode.equals("terse"))
      tabular = new Table(dbAgent, tracks, columns, Table.GROUPED_TERSE, sort, landmark) ;
    else
      tabular = new Table(dbAgent, tracks, columns, Table.UNGROUPED, sort, landmark) ;

    // Cache the Table (for paging / sorting requests)
    session.setAttribute("tabularTable", tabular) ;
    timer = System.currentTimeMillis() - timer ;
  }

  //
  // Generate a file for download
  //
  if(new String("true").equals(session.getAttribute("tabularDownload"))
    || new String("true").equals(request.getParameter("download")))
  {
    SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd_HHmm_z") ;
    response.setHeader("Content-Disposition", "attachment; filename=annotation_file_" +
      sdf.format(new Date()) + ".txt") ;
    response.setContentType("text/plain") ;

    // Skip the edit links
    int skip = -1;
    if(tabular.containsHeader(ColumnType.UNDEFINED_ID))
    {
      for(int col = 1; col <= tabular.getVisibleColumnCount(); col++)
      {
        if(tabular.getHeader(col).getType().getId() == ColumnType.UNDEFINED_ID)
        {
          skip = col ;
          break ;
        }
      }
    }

    // Headers
    out.write("#");
    for(int col = 1; col <= tabular.getVisibleColumnCount(); col++)
      if(skip != col)
        out.write((col == 1 || (skip == 1 && col == 2) ? "" : "\t") + tabular.getHeader(col)) ;
    out.newLine();
    out.flush() ;

    // Fill the table in large blocks and send the data as it becomes available.
    // Note: This is a tweakable parameter that will affect only the initial
    // startup speed for the file download feature.
    for(int block = 0; block < ((tabular.getRowCount() - 1) / BLOCK_SIZE) + 1; block++)
    {
      System.err.println("row count: " + tabular.getRowCount()) ;
      int stop = ((block + 1) * BLOCK_SIZE - 1 >= tabular.getRowCount()) ?
        tabular.getRowCount() - 1 : (block + 1) * BLOCK_SIZE - 1 ;

      // Fill this block
      tabular.fill(dbAgent, block * BLOCK_SIZE, stop) ;

      // Send the Data for this block
      for(int row = block * BLOCK_SIZE; row <= stop; row++)
      {
        for(int col = 1; col <= tabular.getVisibleColumnCount(); col++)
          if(skip != col)
            out.write((col == 1 || (skip == 1 && col == 2) ? "" : "\t")
              + tabular.getRow(row).get(col)) ;

        // Note: I believe this always generates *nix style carraige returns,
        // because the server is running Linux.  Other operating systems
        // might have a problem with this...
        out.newLine();
      }
    }

    // Download is complete (remove from the session)
    session.removeAttribute("tabularDownload") ;

    // Don't generate the rest of the page
    return ;
  }

  // Turn off caching for this page (can cause inconsistencies for the ajax code)
  response.addHeader("Cache-Control", "no-cache, no-store") ;
%>
<%@ include file="include/group.incl" %>
<html>
<head>
  <meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
  <title>Genboree - Tabular Layout</title>
</head>
<body onBeforeUnload="if(!downloading) clearCachedTable() ; else downloading = false ;">

  <!-- BEGIN: Prototype 1.5 support -->
  <script type="text/javascript" src="/javaScripts/prototype.js<%=jsVersion%>"></script>
  <!-- END -->
  <!-- BEGIN: Extjs 2.2 support (for GridPanel and MessageBox) -->
  <link rel="stylesheet" type="text/css" href="/javaScripts/ext-2.2/resources/css/ext-all.css<%=jsVersion%>"/>
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
  <link rel="stylesheet" href="/styles/querytool.css<%=jsVersion%>" type="text/css">
  <link rel="stylesheet" href="/styles/annotationEditor.css<%=jsVersion%>" type="text/css">
  <link rel="stylesheet" href="/styles/vgpConfig.css<%=jsVersion%>" type="text/css">
  <script type="text/javascript" src="/javaScripts/tabular.js<%=jsVersion%>"></script>
  <script type="text/javascript" src="/javaScripts/tabular-help.js<%=jsVersion%>"></script>
  <script type="text/javascript" src="/javaScripts/util.js<%=jsVersion%>"></script>
  <!-- END -->

  <style rel="stylesheet" type="text/css">
    /* Shows the image next to the button value */
    .x-btn-text-icon .x-btn-center .x-btn-text
    {
      background-image:url(/images/silk/application_form_edit.gif) ;
    }
    /* To fix the bad Ext CSS for SplitButtons inside of GridPanels */
    .x-grid3-row td
    {
      padding: 0;
    }
  </style>

  <%@ include file="include/header.incl" %>
  <%@ include file="include/navbar.incl" %>
<%
  // The following is used to generate the correct Edit Links
  int editCol = -1 ;
  for(int col = 1; col <= tabular.getVisibleColumnCount() && editCol == -1; col++)
    if(tabular.getHeader(col).getType().getId() == ColumnType.UNDEFINED_ID)
      editCol = col ;
%>

  <script>
    // For cached download link
    var downloading = false ;

    // For Grid Panel
    var tabularDataStore ;
    var tabularColumnModel ;
    var tabularGrid ;

    Ext.onReady(function()
    {
      Ext.QuickTips.init() ;

      tabularDataStore = new Ext.data.Store(
      {
        id: 'TabularDataStore',
        proxy: new Ext.data.HttpProxy(
        {
          url: 'tabularResults.jsp',
          method: 'POST',
          timeout: 300000
        }),
        baseParams: {action: "list", refSeqId: <%= SessionManager.getSessionDatabaseId(session) %>},
        remoteSort: true,
        reader: new Ext.data.JsonReader(
        {
          root: 'results',
          totalProperty: 'total',
          id: 'fid',
          fields:
          [
<%
            for(int col = 1; col <= tabular.getVisibleColumnCount(); col++)
              out.write((col == 1 ? "" : ", ") + "'column" + col + "'\n") ;
%>
          ]
        })
        ,listeners:
        {
          'loadexception':
          {
            fn: function(proxy, options, transport, err)
            {
              try
              {
                var response = eval('(' + transport.responseText + ')') ;
                if(response['refresh']) window.location.reload(true) ;
                else if(response['error'])
                {
                  alert("There was an error while reading the table data\n"
                    + "from the server:\n\n" + response['error']);
                }
              }
              catch (e)
              {
                alert("An unrecoverable error has occurred: " + e);
              }
            }
          }
<%
          if(editCol != -1)
          {
%>
            ,'load':
            {
              fn: function(store, records, options)
              {
                var edit = 'column' + <%= editCol %> ;
                for(var rec = 0; rec < records.length; rec++)
                  buildEditButton(Ext.get('editBtnDiv_' + rec), records[rec].data[edit], false) ;
              }
            }
<%
          }
%>
        }
      });

      tabularColumnModel = new Ext.grid.ColumnModel(
      [
<%
        for(int col = 1; col <= tabular.getVisibleColumnCount(); col++)
        {
          out.write((col == 1 ? "" : ", ") + "{") ;
          out.write("header:'" + tabular.getHeader(col) + "'") ;
          out.write(", dataIndex:'column" + col + "'") ;
          if(editCol == col)
          {
%>
            ,
            renderer: function(value, md, rec, rowIndex)
            {
              var e = "editBtnDiv_" + rowIndex ;
              if(value.match(/^-1:.*/))
                return "<div style='font-style: italic'>Read Only</div>" ;
              else if(value.match(/^-2:.*/))
                return "<div style='font-style: italic'>Error</div>" ;
              else
                return "<div id='" + e + "' name='" + e + "' class='editBtnDiv'></div>" ;
            }
<%
          }
          out.write("}\n") ;
        }
%>
      ]) ;
      tabularColumnModel.defaultSortable= true;

      // Add a small plugin for dynamic page sizing
      Ext.namespace("Ext.ux", "Ext.ux.grid") ;
      Ext.ux.grid.DynamicPager = function(config)
      {
        Ext.apply(this, config) ;
      }

      Ext.extend(Ext.ux.grid.DynamicPager, Ext.util.Observable,
      {
        init: function(PagingToolbar)
        {
          this.PagingToolbar = PagingToolbar ;
          this.store = PagingToolbar.store ;
          PagingToolbar.on("render", this.onRender, this) ;
        },
        update : function(newSize)
        {
          var w = $('table-width').value ;
          var newPageSize = parseInt(newSize.getValue(), 10) ;
          this.PagingToolbar.pageSize = newPageSize ;
          this.PagingToolbar.doLoad(0) ;

          // Check if we are using a scrollbar, or not
          if($('table-all-rows').checked)
          {
            // The 3 is for the 3 header rows, the +1 is for an added row to
            // fit in a scrollbar, if it is visible (no easy way to tell).
            var newHeight = 3 * $(tabularGrid.getTopToolbar().getEl()).getHeight() +
              ((newPageSize + 1) * $(tabularGrid.getView().getRow(0)).getHeight()) ;
            tabularGrid.setSize({height: newHeight, width: w}) ;
            $('table-height').value = newHeight ;
          }
        },
        onRender: function()
        {
          var config =
          {
            maskRe: /^\d*$/,
            store: new Ext.data.SimpleStore(
            {
              fields: ['pageSize'],
              data: [[10],[25],[50],[100],[250]]
            }),
            displayField: 'pageSize',
            mode: 'local',
            emptyText: this.pageSize,
            triggerAction: 'all',
            value: this.PagingToolbar.pageSize,
            editable: false,
            width: 50
          }

          var combo = new Ext.form.ComboBox(config) ;
          combo.on("change", this.update, this) ;
          combo.on("select", this.update, this) ;
          this.PagingToolbar.add("-", "Rows / Page: ", combo) ;
          combo.getEl().on('keydown', function(e)
            {
              var key = e.getKey() ;
              switch(key)
              {
                case Ext.EventObject.ENTER:
                  this.update(combo) ;
              }
            }, this) ;
        }
      }) ;


      tabularGrid =  new Ext.grid.GridPanel(
      {
        id: 'TabularGrid',
        store: tabularDataStore,
        cm: tabularColumnModel,
        enableColumnMove: false,
        enableColumnHide: false,
        height: 620,
        width: 670,
        renderTo: 'tabular-grid',
        title: 'Tabular Layout',
        viewConfig:
        {
          emptyText: 'No annotations match your constraints'
        },
        tbar: new Ext.PagingToolbar(
          {
            pageSize: 25,
            store: tabularDataStore,
            displayInfo: true,
            plugins: new Ext.ux.grid.DynamicPager({})
          })
      }) ;

      // Show the first page of the table
      tabularGrid.getTopToolbar().changePage(0) ;
    }) ;

    function generateDirectLink(button)
    {
      // Setup the direct link
      var directLink = "<%
      out.write("http://" + request.getServerName()) ;
      out.write("/java-bin/tabularSetup.jsp?refSeqId=" + SessionManager.getSessionDatabaseId(session)) ;
      if(session.getAttribute("tabularLayoutName") != null)
      {
        // Build the track name string
        try
        {
          for(DbFtype track : ((Vector<DbFtype>) session.getAttribute("tabularTracks")))
            out.write("&trackName=" + URLEncoder.encode(track.getTrackName(), "UTF-8")) ;
        }
        catch(UnsupportedEncodingException e)
        {
          // Not much we can do here...
        }
        out.write("&layoutName=") ;
        out.write(URLEncoder.encode(session.getAttribute("tabularLayoutName").toString(), "UTF-8")) ;
      }
      else
      {
        out.write(tabular.getQueryUrl()) ;
      }
      %>" ;

      var title = "Direct Link to this Table" ;

      Ext.Msg.show(
      {
        title: title,
        msg : directLink,
        height: 80,
        width: 350,
        minHeight: 50,
        minWidth: 150,
        modal: false,
        proxyDrag: true
      }) ;
      Ext.Msg.getDialog().setPagePosition(Ext.get(button).getX() + 25, Ext.get(button).getY() + 25) ;
      return false ;
    }
  </script>
  <div id="second-level-nav" style="margin: 6px;">
    <span style="background-color: #E0E8E0; margin-right: 6px;">
      <a href="/java-bin/tabular.jsp">&lt;&lt; Layout Setup</a>
    </span>
    <span style="background-color: #E0E8E0; margin-right: 6px;">
      <a href='javascript:void(0)' onClick="return generateDirectLink(this)">Table URL</a>
    </span>
    <form id="downloadForm" method="post" style="display: inline; background-color: #E0E8E0;">
      <a href="#" onClick="downloading = true ; $('downloadForm').submit() ; return false ;">Download Table</a>
      <input id="download" name="download" type="hidden" value="true">
    </form>
  </div>
  <div style="clear: both;"></div>
<%
  String debug = GenboreeConfig.getConfigParam("debugTabularView");
  if (debug != null && debug.equals("true"))
  {
    out.write("<div style='margin: 15px 0; border: 1px solid #008888; background-color: #00DDDD; color: white; font-size: 8pt; padding: 5px; font-family: courier, serif'>\n");
    out.write("Table created of size: " + tabular.getRowCount() + " in " + timer + "ms<br>") ;
    out.write("Used Memory: " + Util.commify(MemoryUtil.usedMemory()/1024/1024) + "MB<br>") ;
    Runtime.getRuntime().gc() ;
    out.write("Used Memory after gc(): " + Util.commify(MemoryUtil.usedMemory()/1024/1024) + "MB") ;
    out.write("</div>\n");
  }
%>
  <fieldset>
    <legend>Display Options</legend>
    <div style="position: relative; padding: .5em;">
      <label for="table-width">Table Width:</label>
      <input type="text" id="table-width" value="670" onBlur="updateTableSize();"
        onKeyPress="if((event.which && event.which==13) || (event.keyCode && event.keyCode == 13)) updateTableSize();"
        style="position: absolute; left: 100px; width: 50px; top: .2em;">
      <span style="position: absolute; left: 155px;"> px</span>
      <label>
        <input type="checkbox" id="table-all-cols" onClick="updateTableSize();"
          style="position: absolute; left: 180px; top: .25em">
        <span style="position: absolute; left: 200px; font-size: .9em;">Show all cols</span>
      </label>
    </div>
    <div style="position: relative; padding: .5em;">
      <label for="table-height">Table Height:</label>
      <input type="text" id="table-height" value="620" onBlur="updateTableSize();"
        onKeyPress="if((event.which && event.which==13) || (event.keyCode && event.keyCode == 13)) updateTableSize();"
        style="position: absolute; left: 100px; width: 50px; top: .2em;">
      <span style="position: absolute; left: 155px;"> px</span>
      <label>
        <input type="checkbox" id="table-all-rows" onClick="updateTableSize();"
          style="position: absolute; left: 180px; top: .25em" >
        <span style="position: absolute; left: 200px; font-size: .9em;">Show all rows</span>
      </label>
    </div>
  </fieldset>
  <div id='tabular-grid'> </div>

  <%@ include file="include/footer.incl" %>
</body>
</html>
