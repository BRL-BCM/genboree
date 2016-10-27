<%@ page import="
  org.genboree.util.*,
  org.genboree.dbaccess.GenboreeGroup"
%>
<%
  /**
   * File:
   *   ajax/group.jsp
   * Description:
   *   This Ajax Provider recognizes the following actions.  An AJAX widget can
   *   perform any of these actions by passing the "action=<action>" parameter
   *   to this .JSP file.
   *   + list
   *     Send back a JSON array of the Group IDs accessible to the user
   *     currently logged in according to the session information.
   *   + update
   *     Switch the group according to the supplied groupId parameter.
   *     Return an object containing the new groupId and access level.
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
    // Perform a 'list'
    if (grps == null)
    {
      // TODO - should we call recreateteGroupList instead?
      out.write("{'refresh': true}") ;
      return ;
    }

    // do the listing from the "grps" array in memory
    out.write("[") ;
    for (int num = 0; num < grps.length; num++)
    {
      out.write((num == 0 ? "" : ", ") + grps[num].getGroupId()) ;
    }
    out.write("]") ;
  }
  else if (request.getParameter("action").equals("update"))
  {
    // Determine the group id
    String groupId = request.getParameter("groupId") ;
    if(groupId == null) groupId = SessionManager.getSessionGroupId(mys) ;
    if(groupId == null || groupId.compareTo("#") == 0) groupId = grps[0].getGroupId() ;

    // Set the group in the session
    SessionManager.clearSessionDatabase(mys) ;
    SessionManager.setSessionGroupId(mys, groupId) ;

    // Get the user access level
    String myGroupAccess = "Error" ;
    try
    {
      myGroupAccess = GenboreeUtils.fetchGrpAccess(
        Integer.parseInt(myself.getUserId()), Integer.parseInt(groupId), db) ;
    }
    catch (NumberFormatException e)
    {
      System.err.println("ajax/group.jsp: Error parsing integers while trying " + 
        "to read GroupAccess" + e.getMessage()) ;
    }

    // Send the response
%>
    {
      'id' : <%= groupId %>,
      'name' : '<%= SessionManager.getSessionGroupName(mys).replaceAll("'", "\\\\'") %>',
      'accessLevel' : '<%= myGroupAccess %>'
    }
<%
  }
  else
  {
    // Misunderstood request
    out.write("{'refresh': true}") ;
  }
%>
