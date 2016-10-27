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
   *   ajax/database.jsp
   * Description:
   *   This Ajax Provider recognizes the following actions.  An AJAX widget can
   *   perform any of these actions by passing the "action=<action>" parameter
   *   to this .JSP file.
   *   + list
   *     Send back a JSON array of the RefSeq IDs associated with the current
   *     Group ID that is stored for this session.
   *   + list_entrypoints
   *     Send a JSON array of the Fref names associated with the current RefSeq
   *     ID stored in the session.  This list can be empty if no RefSeq ID is
   *     set in the session.  Also, it may be replaced by a single element hash
   *     {'toomany' : true} if the list of Frefs is too large for a dropdown
   *     list on a webpage.  This behavior can be overridden by supplying a
   *     second paramater force like so: "action=list_entrypoints&force=true"
   *   + update
   *     Switch the database according to the supplied refSeqId parameter.
   *     Return an object containing the new refseqId, name, and access.
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
  //   + update
  //
  if (request.getParameter("action").equals("list"))
  {
    // Find the active group (or null)
    String groupId = SessionManager.getSessionGroupId(mys) ;
    GenboreeGroup[] activeGroup = new GenboreeGroup[0] ;
    for(int num = 0; num < grps.length; num++)
    {
      if(grps[num].getGroupId().equals(groupId))
      {
        activeGroup = new GenboreeGroup[1] ;
        activeGroup[0] = grps[num] ;
      }
    }

    // Get the list of rseqs
    Refseq[] databases = Refseq.fetchAll(db, activeGroup);

    // do the listing from the "rseqs" array in memory
    out.write("[") ;
    for (int num = 0; num < databases.length; num++)
    {
      out.write((num == 0 ? "" : ", ")) ;
%>
      {
        'id' : <%= databases[num].getRefSeqId() %>,
        'name' : '<%= databases[num].getRefseqName().replaceAll("'", "\\\\'") %>'
      }
<%
    }
    out.write("]") ;
  }
  else if (request.getParameter("action").equals("list_entrypoints"))
  {
    // Grab the current database from the session
    Connection localDbConn = db.getConnection(SessionManager.getSessionDatabaseName(mys)) ;
    if(SessionManager.getSessionDatabaseName(mys) != null && localDbConn != null)
    {
      int totalEps = (new String("true").equals(request.getParameter("force"))) ? 0 : DbFref.countAll(localDbConn) ;
      if(totalEps <= Constants.GB_MAX_FREF_FOR_DROPLIST)
      {
        // Sort the list
        DbFref[] eps = DbFref.fetchAll(localDbConn) ;
        Arrays.sort(eps, new EntryPointComparator()) ;

        // Respond to our caller
        out.write("[") ;
        String comma = "" ;
        for(DbFref entryPoint : eps)
        {
          out.write(comma + "'" + entryPoint.getRefname() + "'") ;
          comma = ", " ;
        }
        out.write("]") ;
        return ;
      }
      else
      {
        out.write("{'toomany' : true}") ;
        return ;
      }
    }
    else
    {
      // No database set in the session
      out.write("['empty']") ;
      return ;
    }
  }
  else if (request.getParameter("action").equals("update"))
  {
    // Get our group
    String groupId = SessionManager.getSessionGroupId(mys) ;
    GenboreeGroup grp = null ;
    for(int num = 0; num < grps.length; num++)
      if(grps[num].getGroupId().equals(groupId))
        grp = grps[num] ;
    
    if(grp == null)
    {
      // Something wrong here...
      out.write("{'refresh': true}") ;
      System.err.println("database.jsp: Trying to update database without a session group") ;
      return ;
    }
    
    // Validate this request
    if(!grp.belongsTo(databaseId))
    {
      // TODO - notification to the user would be a good idea...
      SessionManager.clearSessionDatabase(mys) ;
      System.err.println("database.jsp: Trying to set the session database (" + databaseId + 
        ") to a refseq id that does not belong to the session group (" + groupId + ")") ;
      out.write("{}") ;
      return ;
    }

    // Set the database to the session
    SessionManager.setSessionDatabaseId(mys, databaseId) ;

    // Get the user access level
  	GenboreeGroup pubGrp = (GenboreeGroup) mys.getAttribute("public_group") ;
    String myDatabaseAccess = pubGrp.belongsTo(databaseId) ? "Public" : "Private" ;

    // Send the response
%>
    {
      'id' : <%= databaseId %>,
      'name' : '<%= SessionManager.findRefSeqName(databaseId, db).replaceAll("'", "\\\\'") %>',
      'accessLevel' : '<%= myDatabaseAccess %>'
    }
<%
  }
  else
  {
    // Misunderstood request
    out.write("{'refresh': true}") ;
  }
%>
