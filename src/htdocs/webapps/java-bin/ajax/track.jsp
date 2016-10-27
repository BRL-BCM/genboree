<%@ page import="
  java.util.Vector,
  java.util.ArrayList,
  java.util.Hashtable,
  java.sql.SQLException,
  java.sql.Connection,
  java.sql.ResultSet,
  java.sql.PreparedStatement,
  java.beans.Statement,
  org.genboree.util.*,
  org.genboree.dbaccess.GenboreeGroup,
  org.genboree.dbaccess.JSPErrorHandler"
%>
<%
  /**
   * File:
   *   ajax/track.jsp
   * Description:
   *   This Ajax Provider recognizes the following actions.  An AJAX widget can
   *   perform any of these actions by passing the "action=<action>" parameter
   *   to this .JSP file.
   *   + list
   *     Send back a JSON array of Objects that indicate the Database Name,
   *     Track Name, and Ftype IDs associated with the current Group ID and
   *     RefSeq ID that are stored for this session.
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
    GenboreeUtils.sendRedirect(request,response,  "/java-bin/index.jsp") ;
    return ;
  }

  //
  // This Ajax Provider recognizes the following actions
  //   + list
  //
  if (request.getParameter("action").equals("list"))
  {
    // Get the database from the session
    Refseq database = new Refseq() ;
    database.setRefSeqId(SessionManager.getSessionDatabaseId(mys)) ;

    if(database.fetch(db))
    {
      String[] dbNames = database.fetchDatabaseNames(db) ;
      Vector<String> trackNames = new Vector<String>() ;
      Vector<String> emptyNames = new Vector<String>() ;
      for(String dbName : dbNames)
      {
        Connection connection = db.getConnection(dbName) ;
        if(connection != null)
        {
          try
          {
            DbFtype[] tracks = DbFtype.fetchAll(connection, dbName, Integer.parseInt(myself.getUserId())) ;
            for (DbFtype track : tracks)
            {
              // Check for permission
              if(!TrackPermission.isTrackAllowed(dbName, track.getFmethod(), track.getFsource(), 
                Integer.parseInt(myself.getUserId())))
                continue ;

              // Check for duplicates
              if(!trackNames.contains(track.getTrackName()))
              {
                trackNames.add(track.getTrackName()) ;
                if(track.isEmpty(db)) 
                  emptyNames.add(track.getTrackName()) ;
              }

              if(!track.isEmpty(db) && emptyNames.contains(track.getTrackName()))
                emptyNames.remove(track.getTrackName()) ;
            }
          }
          catch (NumberFormatException e)
          {
            System.err.println("track.jsp: Cannot parse Session user id into an integer...") ;
          }
        }
        else
        {
          System.err.println("track.jsp: Cannot get a Database connection for - (" + 
            dbName+ ") ") ;
        }
      }

      // Now output the track "objects" alphabetically
      Collections.sort(trackNames) ;
      out.write("[\n") ;
      for(String name: trackNames)
      {
        out.write(trackNames.firstElement().equals(name) ? "" : ",") ;
%>
        {
          'name' : '<%= Util.simpleJsQuote(name) %>',
          'refseq_id' : '<%= database.getRefSeqId() %>'
          <%= emptyNames.contains(name) ? ", 'empty' : true" : "" %>
        }
<%
      }
      out.write("]\n") ;
    }
    else
    {
      System.err.println("track.jsp: Trying to list tracks without a session group/database") ;
      out.write("[]\n") ;
    }
  }
  else
  {
    // Misunderstood request
    out.write("{'refresh': true}") ;
  }
%>
