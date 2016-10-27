<%@ page import="
  java.util.*,
  java.sql.*,
  java.security.*,
  org.genboree.util.*,
  org.genboree.util.helpers.*,
  org.genboree.dbaccess.*"
%>
<%
  // Variables we will be filling in:
  String finalURL = null ;
  String statusCode = "OK" ;
  int respStatus = HttpServletResponse.SC_OK ;
  String statusMsg = "" ;
  String statusDmsg = "" ;

  // First things first, we must check for a session timeout or lack of
  // login. Public/guest access ought to be ok, as long as logged in as such.
  boolean sessionAccessOk = org.genboree.util.helpers.UserInfoUtil.checkSessionAccess(request, true) ;

  if(sessionAccessOk) // session not timed out, have a username/password in session, etc
  {
    // Get userinfo[] array, groups, and such for this user
%> <%@ include file="../include/userinfo.incl" %> <%
    String coreURI = request.getParameter("coreURI") ;
    if(coreURI != null)
    {
      coreURI = coreURI.trim() ;
      if((coreURI.length() > 0) && coreURI.matches("^http://[^.]+(?:\\.[^.]+)+/REST/v.+$") ) // then it appears valid
      {
        finalURL = RESTapiUtil.computeFinalURL(coreURI, userInfo) ;
      }
    }

    if(finalURL == null) // then either coreURI was null or it's empty or messed up somehow
    {
      respStatus = HttpServletResponse.SC_BAD_REQUEST ;
      statusCode = "Bad Request" ;
      statusMsg = Constants.GB_BAD_REQUEST_MSG ;
      statusDmsg = Constants.GB_BAD_REQUEST_DMSG + "\\ncoreURI was: " + coreURI ;
    }
  }
  else // session might have timed out or user not logged in or something...anyway forbidden
  {
    respStatus = HttpServletResponse.SC_FORBIDDEN ;
    statusCode = "Forbidden" ;
    statusMsg = Constants.GB_FORBIDDEN_MSG ;
    statusDmsg = Constants.GB_FORBIDDEN_DMSG ;
  }

  // Now output the JSON
  response.setContentType("application/json") ;
  response.setStatus(respStatus) ;
  response.resetBuffer() ; // arrr, doesn't seem to be implemented (i.e. doesn't do what it's supposed to)
  if(finalURL != null) // have computed a URL
  {
%>
    {
      "data" :
      {
        "text" : "<%= finalURL %>",
        "refs" : []
      },
<%
  }
  else // something went wrong, compose "data" accordingly
  {
%>
    {
      "data" : null,
<%
  }
  // Now for status info
%>
      "status" :
      {
        "statusCode" : "<%= statusCode %>",
        "statusMsg" : "<%= statusMsg %>"
      }
    }
