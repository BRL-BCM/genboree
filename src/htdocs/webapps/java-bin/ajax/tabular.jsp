<%@ page import="
  java.util.Vector,
  java.sql.Connection,
  java.sql.SQLException,
  org.genboree.dbaccess.Refseq,
  org.genboree.dbaccess.DbFtype,
  org.genboree.dbaccess.GenboreeGroup,
  org.genboree.dbaccess.TabularLayout,
  org.genboree.dbaccess.TrackPermission,
  org.genboree.util.Constants,
  org.genboree.util.GenboreeUtils,
  org.genboree.util.GenboreeConfig,
  org.genboree.tabular.Table,
  org.genboree.tabular.Utility"
%>
<%
  /**
   * File:
   *   ajax/tabular.jsp
   * Description:
   *   This file providers helper methods for the tabular layout setup page.
   *   This Ajax Provider recognizes the following actions.  An AJAX widget can
   *   perform any of these actions by passing the "action=<action>" parameter
   *   to this .JSP file.
   *   + list_attributes
   *   + update_track_selection
   *   + clear_cached_table
   *   + list_layouts
   *   + read_layout
   *   + delete_layout
   *   + save_layout
   */

  // First things first, we must check for a session timeout (or public login)
  // This must be done before we include userInfo.incl because that file makes
  // calls to response.sendRedirect() which potentially can respond to an AJAX
  // widget with very undesirable effect.  
  // NOTE: It may be smarter to create methods in GenboreeUtil that will check
  // if a redirect is about to occur, so that we have that common code in one
  // place - SGD
  if(session.getAttribute("username") == null
    || session.getAttribute("pass") == null
    || session.getAttribute("userid") == null)
  {
    out.write("{'error': 'Missing login information'}") ;
    return ;
  }
  
  // Now check for public access attempts to a non-published database
  String databaseId = request.getParameter("refSeqId") ;
  if (databaseId == null) databaseId = SessionManager.getSessionDatabaseId(session) ;
  if(session.getAttribute("username").toString().equalsIgnoreCase("Public") &&
    !Refseq.isPublished(DBAgent.getInstance(), databaseId))
  {
    out.write("{'error': 'Access Denied'}") ;
    return ;
  }
%>
<%@ include file="../include/userinfo.incl" %>
<%

  // Assume this means someone went directly to this page instead of calling it
  // from an AJAX widget
  if(request.getParameter("action") == null)
  {
    GenboreeUtils.sendRedirect(request, response, "/java-bin/index.jsp") ;
    return ;
  }

  //
  // Get a few common parameters
  //
  // First get our Refseq id
  Refseq database = new Refseq() ;
  database.setRefSeqId(SessionManager.getSessionDatabaseId(mys)) ;
  if(!database.fetch(db))
    database = null ;

  // Now, get our group
  // NOTE: Because of the way that published databases work ("Public" group
  //  stored in the session) we will actually get the group not from the
  //  session, but slightly less efficiently by searching through the list
  //  of all of the groups and finding the one matching our RefSeqId from
  //  the session.
  GenboreeGroup grp = null ;
  Connection conn = db.getConnection() ;
  for(GenboreeGroup testGroup : GenboreeGroup.fetchAll(db))
  {
    // Try to get the refseqs
    if(!testGroup.fetchRefseqs(conn)) continue ;

    if(database != null && testGroup.belongsTo(database.getRefSeqId()))
    {
      grp = testGroup ;
      grp.fetchUsers(db) ;
      break ;
    }
  }
  
  //
  // Determine what action to perform
  //
  if (request.getParameter("action").equals("list_attributes"))
  {
    if (mys.getAttribute("tabularTracks") == null)
    {
      // Nothing to return
      out.write("[]") ;
      return ;
    }

    // Assume "tabularTracks" is a proper Array
    try
    {
      Vector<String> attributes = Utility.listAttributes(db, 
        (Vector<DbFtype>) mys.getAttribute("tabularTracks")) ;
      String output = "" ;
      for(String item : attributes)
      {
        output += (output.length() == 0 ? "" : ", ") + "'" + item + "'";
      }
      out.write("[" + output + "]") ;
    }
    catch (ClassCastException e)
    {
      System.err.println("The 'tabularTracks' array is not properly stored in the session... Removing.") ;
      mys.removeAttribute("tabularTracks") ;
      out.write("{'reload': true}") ;
      return ;
    }
  }
  else if (request.getParameter("action").equals("update_track_selection")) 
  {
    if (request.getParameter("trackName") == null)
    {
      // Clear our selection
      mys.removeAttribute("tabularTracks") ;
      return ;
    }

    // Check for missing required objects
    if(database == null)
    {
      System.err.println("ajax/tabular.jsp: Problem getting Refseq object for id - " + 
        SessionManager.getSessionDatabaseId(mys)) ;
      out.write("{'refresh':true}") ;
      return ;
    }

    // Fetch the track objects from the DB
    String[] trackNames = (String[]) request.getParameterValues("trackName") ;
    if(trackNames == null)
    {
      out.write("{'attributes':[]}") ;
      return ;
    }
    Vector<DbFtype> tracks = Utility.getTracksFromNames(db, Integer.parseInt(myself.getUserId()), 
      database, trackNames) ;

    // Now save the track list
    mys.setAttribute("tabularTracks", tracks) ;

    // And send back the new attribute list
    Vector<String> attributes = Utility.listAttributes(db, tracks) ;
    StringBuilder output = new StringBuilder() ;
    for(String item : attributes)
    {
      output.append(output.length() == 0 ? "" : ", ") ;
      output.append("'").append(item).append("'");
    }
    out.write("{'attributes':[" + output + "]}") ;
  }
  else if(request.getParameter("action").equals("get_annotation_count"))
  {
    if(session.getAttribute("tabularTracks") != null)
    {
      // Assume the session variable is a proper Vector
      Vector<DbFtype> tracks = (Vector<DbFtype>) session.getAttribute("tabularTracks") ;

      out.write("{'count': " + Utility.getAnnotationCount(db, tracks) + "}") ;
      return ;
    }

    // Count is zero if no track names are supplied
    if(request.getParameter("trackName") == null)
    {
      out.write("{'count':0}") ;
      return ;
    }

    // Check for missing required objects
    if(database == null)
    {
      System.err.println("ajax/tabular.jsp: Problem getting Refseq object for id - " + 
        SessionManager.getSessionDatabaseId(mys)) ;
      out.write("{'refresh':true}") ;
      return ;
    }

    // Fetch the track objects from the DB
    String[] trackNames = (String[]) request.getParameterValues("trackName") ;
    Vector<DbFtype> tracks = Utility.getTracksFromNames(db, Integer.parseInt(myself.getUserId()), 
      database, trackNames) ;

    // Return the count
    out.write("{'count': " + Utility.getAnnotationCount(db, tracks) + "}") ;
  }
  else if(request.getParameter("action").equals("clear_cached_table"))
  {
    System.err.println("ajax/tabular.jsp: Clearing cached Table from session") ;
    if(session.getAttribute("tabularTable") != null)
      ((Table) session.getAttribute("tabularTable")).destroy() ;
    session.removeAttribute("tabularTable") ;
  }
  else if(request.getParameter("action").equals("list_layouts"))
  {
    // Check for missing required objects
    if(database == null)
    {
      System.err.println("ajax/tabular.jsp: Problem getting Refseq object for id - " + 
        SessionManager.getSessionDatabaseId(mys)) ;
      out.write("{'refresh':true}") ;
      return ;
    }
    if(grp == null)
    {
      System.err.println("ajax/tabular.jsp: Problem getting Group for id - " + 
        SessionManager.getSessionGroupId(mys)) ;
      out.write("{'refresh':true}") ;
      return ;
    }

    // Build the list out of any files in the directory that are not hidden
    StringBuilder output = new StringBuilder() ;
    try
    {
      TabularLayout[] layouts = TabularLayout.fetchAll(db.getConnection(database.getDatabaseName())) ;
      for (TabularLayout layout : layouts)
      {
        output.append(output.length() == 0 ? "" : ",") ;
        output.append("{\"name\": \"").append(layout.getName().replaceAll("\"", "\\\\\"")).append("\"}") ;
      }
    }
    catch (SQLException e)
    {
      System.err.println("java-bin/ajax/tabular.jsp: Problem fetching all tabular layouts " + 
        "for database " + database.getDatabaseName() + ": " + e) ;
      output = new StringBuilder() ;
      // TODO - notify user
    }

    // Output the response
    out.write("[" + output + "]") ;
  }
  else if(request.getParameter("action").equals("read_layout"))
  {
    // Check for missing required objects
    if(database == null)
    {
      System.err.println("ajax/tabular.jsp: Problem getting Refseq object for id - " + 
        SessionManager.getSessionDatabaseId(mys)) ;
      out.write("{'refresh':true}") ;
      return ;
    }
    if(grp == null)
    {
      System.err.println("ajax/tabular.jsp: Problem getting Group for id - " + 
        SessionManager.getSessionGroupId(mys)) ;
      out.write("{'refresh':true}") ;
      return ;
    }
    if(request.getParameter("layoutName") == null)
    {
      System.err.println("ajax/tabular.jsp: Must specify a layout name for action=read_layout") ;
      out.write("{error: 'No layout name specified'}") ;
      return ;
    }

    // Fetch the layout from the DB
    TabularLayout layout = null ;
    try
    {
      layout = TabularLayout.fetchByName(
        db.getConnection(database.getDatabaseName()), request.getParameter("layoutName")) ;
    }
    catch (SQLException e)
    {
      System.err.println("ajax/tabular.jsp: SQL Exception while fetching layout: " + e) ;
      out.write("{error: 'A DB error has occurred'}") ;
      return ;
    }

    if(layout == null)
    {
      System.err.println("ajax/tabular.jsp: No layout named '" + 
        request.getParameter("layoutName") + "' found in database " + database.getDatabaseName()) ;
      out.write("{error: 'No layout exists by that name'}") ;
      return ;
    }

    // Write layout out to stream
    out.write(layout.toJson()) ;
  }
  else if(request.getParameter("action").equals("delete_layout"))
  {
    // Check for missing required data
    if(database == null)
    {
      System.err.println("ajax/tabular.jsp: Problem getting Refseq object for id - " + 
        SessionManager.getSessionDatabaseId(mys)) ;
      out.write("{'refresh':true}") ;
      return ;
    }
    if(grp == null)
    {
      System.err.println("ajax/tabular.jsp: Problem getting Group for id - " + 
        SessionManager.getSessionGroupId(mys)) ;
      out.write("{'refresh':true}") ;
      return ;
    }
    else if(!grp.isOwner(myself.getUserId()))
    {
      System.err.println("ajax/tabular.jsp: Non-admin user attempted to delete a layout: " +
        grp.getGroupName() + ", " + myself.getUserId()) ;
      out.write("{error: 'Insufficient privileges'}") ;
      return ;
    }
    if(request.getParameter("layoutName") == null)
    {
      System.err.println("ajax/tabular.jsp: Must specify a layout name for action=delete_layout") ;
      out.write("{error: 'No layout name specified'}") ;
      return ;
    }

    // First fetch the layout object
    TabularLayout layout = null ;
    try
    {
      layout = TabularLayout.fetchByName(
        db.getConnection(database.getDatabaseName()), request.getParameter("layoutName")) ;
    }
    catch (SQLException e)
    {
      System.err.println("ajax/tabular.jsp: SQL Exception while fetching layout: " + e) ;
      out.write("{error: 'A DB error has occurred'}") ;
      return ;
    }

    if(layout == null)
    {
      System.err.println("ajax/tabular.jsp: No layout named '" + 
        request.getParameter("layoutName") + "' found in database " + database.getDatabaseName()) ;
      out.write("{error: 'No layout exists by that name'}") ;
      return ;
    }

    // Delete the layout
    layout.delete(db) ;

    // No problems, return an empty object
    out.write("{success: true}") ;
  }
  else if(request.getParameter("action").equals("save_layout"))
  {
    // Gather the parameters
    String layoutName = request.getParameter("layoutName") ;
    String columns = request.getParameter("columns") ;
    String sort = request.getParameter("sort") ;
    String groupMode = request.getParameter("groupMode") ;

    // This flag checks for proper updates
    boolean update = false ;
    if(new String("true").equals(request.getParameter("update")))
      update = true ;

    // Check for bad inputs (forward back to the creation page)
    if(columns == null || layoutName == null)
    {
      System.err.println("ajax/tabular.jsp: save_layout requested with missing " + 
        "required parameters") ;
      out.write("{'error' : 'You must provide all of the required parameters!'}") ;
      return ;
    }
    else if(columns.trim().length() == 0 || layoutName.trim().length() == 0)
    {
      System.err.println("ajax/tabular.jsp: save_layout requested with empty " +
        "required parameters") ;
      out.write("{'error' : 'You cannot provide empty parameters!'}") ;
      return ;
    }

    // Check for bad Session information
    if(grp == null || database == null)
    {
      System.err.println("ajax/tabular.jsp: save_layout requested without proper " +
        "refseq id in session") ;
      out.write("{'error' : 'You must select a group / database first.'}") ;
      return ;
    }
    if(grp.isReadOnly(myself.getUserId()) ||
      session.getAttribute("username").toString().equalsIgnoreCase("Public"))
    {
      // TODO - not yet working
      System.err.println("ajax/tabular.jsp: User without write access attempted to save a layout") ;
      out.write("{'error': 'Insufficient privileges'}") ;
      return ;
    }

    if(update)
    {
      // Update a layout
      // First fetch the layout object
      TabularLayout layout = null ;
      try
      {
        layout = TabularLayout.fetchByName(
          db.getConnection(database.getDatabaseName()), request.getParameter("layoutName")) ;
      }
      catch (SQLException e)
      {
        System.err.println("ajax/tabular.jsp: SQL Exception while fetching layout: " + e) ;
        out.write("{'error': 'A DB error has occurred'}") ;
        return ;
      }

      if(layout == null)
      {
        System.err.println("ajax/tabular.jsp: No layout named '" + 
          request.getParameter("layoutName") + "' found in database " + database.getDatabaseName()) ;
        out.write("{'error': 'No layout exists by that name (" + layoutName + ")'}") ;
        return ;
      }

      // Update the fields
      layout.setName(layoutName) ;
      layout.setColumns(columns) ;
      layout.setSort(sort) ;
      layout.setGroupMode(groupMode) ;
      layout.setLastModifiedTime(Calendar.getInstance().getTime()) ;

      // Now do the update
      try
      {
        layout.update(db) ;
        out.write("{'success': 'update'}") ;
      }
      catch (SQLException e)
      {
        System.err.println("ajax/tabular.jsp: Problem updating layout: " + e) ;
        out.write("{\"error\": \"DB error while updating layout: " + e + "\"}") ;
        return ;
      }
    }
    else
    {
      // Create a new layout
      TabularLayout layout = new TabularLayout() ;
      layout.setName(layoutName) ;
      layout.setUserId(Integer.parseInt(myself.getUserId())) ;
      layout.setCreateDate(Calendar.getInstance().getTime()) ;
      layout.setLastModifiedTime(Calendar.getInstance().getTime()) ;
      layout.setDescription("") ;  // TODO
      layout.setColumns(columns) ;
      layout.setSort(sort) ;
      layout.setGroupMode(groupMode) ;

      // Create the layout
      try
      {
        layout.insert(db, database.getDatabaseName()) ;
        out.write("{'success': 'true'}") ;
      }
      catch (SQLException e)
      {
        System.err.println("ajax/tabular.jsp: Problem creating new layout: " + e) ;
        out.write("{\"error\": \"DB error while saving layout: " + e + "\"}") ;
        return ;
      }
    }
  }
%>
