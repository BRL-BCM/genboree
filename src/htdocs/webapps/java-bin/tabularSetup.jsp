<%@ page import="
  org.json.JSONObject,
  org.json.JSONException,
  org.genboree.tabular.Utility,
  org.genboree.dbaccess.Refseq,
  org.genboree.dbaccess.DBAgent,
  org.genboree.util.SessionManager"
%>
<%@ include file="include/group.incl" %>
<%
/**
 * The purpose of this file is twofold:
 * 1.) Check for required variables and redirect to tabular.jsp as appropriate.
 * 2.) Put any GET variables into the session (GET has priority over existing
 *     session attributes).  Also, some session attributes may be removed as
 *     is necessary (depends on missing GET parameters, like landmark).
 * This file always redirects (either to the display, tabularDisplay.jsp, or to
 * the setup page, tabular.jsp) so it will never appear in the client's browser
 * history.  Because of this, browser histories will not have URLs with GET
 * variables in them, making the pages display correctly when the user arrives
 * at them using the back button.
 *
 * The session variables used by the tabular layout pages are:
 * - tabularTable [org.genboree.tabular.Table]
 *   The actual table data.  This will be cleared in the onUnload method of the
 *   tabularDisplay.jsp page.
 * - tabularTracks [java.util.Vector<org.genboree.dbaccess.DbFtype>]
 *   An array of the data tracks for which the Table.
 * - tabularLandmark [java.lang.String]
 *   The landmark string for the Table.
 * - tabularLayout [java.lang.String] 
 *   A JSON formatted string (parseable by org.json.JSONObject) defining the
 *   table layout data.  This session attribute should only be used when the 
 *   tabularLayoutName attribute is missing.  Also, this attribute will take
 *   priority over the tabularLayoutName attribute.
 * - tabularLayoutName [java.lang.String]
 *   The name of the layout stored on disk.
 *
 * NOTE: When all of the layout GET parameters (columns, sort, group_mode or 
 * groupMode) have been provided, they will have priority over a layoutName
 * provided as a GET parameter.  Therefore, if a layout is to be used, the
 * layoutName GET parameter must be present, but the columns, sort, and
 * group_mode or groupMode parameters must be missing as well!
 */
String destination = "/java-bin/tabularDisplay.jsp" ;

// Gather information from the request
String landmark = request.getParameter("landmark") ;
String[] trackNames = request.getParameterValues("trackName") ;
String columns = request.getParameter("columns") ;
String sort = request.getParameter("sort") ;
String groupMode = request.getParameter("groupMode") ;
String layoutName = request.getParameter("layoutName") ;
String refSeqId = request.getParameter("refSeqId") ;
// Fallback for old links
if (trackNames == null || trackNames.length == 0)
  trackNames = request.getParameterValues("trackNames") ;
if (groupMode == null)
  groupMode = request.getParameter("group_mode") ;

// Now place all GETted parameters into the session
// Ref seq id is optional (can use the existing id in the session)
if(refSeqId != null && refSeqId.trim().length() > 0)
  SessionManager.setSessionDatabaseIdHard(session, refSeqId) ;

// For downloads (optional, removed if missing)
session.removeAttribute("tabularDownload") ;
if(new String("true").equals(request.getParameter("download")))
  session.setAttribute("tabularDownload", "true") ;

// Now get our Refseq Object
Refseq database = new Refseq() ;
database.setRefSeqId(SessionManager.getSessionDatabaseId(session)) ;
if(!database.fetch(DBAgent.getInstance()))
  database = null ;

// Landmark is optional, but is removed from the session if missing
session.removeAttribute("tabularLandmark") ;
if(landmark != null && landmark.trim().length() > 0)
  session.setAttribute("tabularLandmark", landmark) ;

// Tracks are optional (can use the existing array in the session)
if(trackNames != null && trackNames.length > 0 && database != null)
{
  session.setAttribute("tabularTracks", Utility.getTracksFromNames(DBAgent.getInstance(), 
    Integer.parseInt(myself.getUserId()), database, trackNames)) ;
}

// One of either the tuple (column, sort, [groupMode]) or layoutName
// must be provided in the GET (i.e. the session cannot be used)
// The tuple takes precedence over the name, and the columns parameter
// must be present (the other two are optional
session.removeAttribute("tabularLayout") ;
session.removeAttribute("tabularLayoutName") ;
if(columns != null && columns.trim().length() > 0)
{
  // Use the tuple to construct the "tabularLayout" attribute
  try
  {
    JSONObject json = new JSONObject() ;
    json.put("columns", columns) ;
    if(sort != null) json.put("sort", sort) ;
    if(groupMode != null) json.put("groupMode", groupMode) ;

    // Now add this layout to the session
    session.setAttribute("tabularLayout", json.toString()) ;
  }
  catch(JSONException e)
  {
    System.err.println("java-bin/tabularSetup.jsp: Problem constructing JSON Object for " +
      "tabular layout in session: " + e) ;
  }
}
else
{
  // Put the layoutName into the session
  if(layoutName != null && layoutName.trim().length() > 0)
    session.setAttribute("tabularLayoutName", layoutName.trim()) ;
}

// Finally, check the session for a bad combination of parameters (forward back
//   to the creation page)
// TODO - alert the user, not just the log file
if(database == null)
{
  System.err.println("tabularSetup.jsp called without refSeqId as a parameter " +
    "and no Group / RefSeq in the session.") ;
  GenboreeUtils.sendRedirect(request, response, "/java-bin/tabular.jsp") ;
  return ;
}
if(session.getAttribute("tabularTracks") == null || 
  ((Vector<DbFtype>) session.getAttribute("tabularTracks")).size() == 0)
{
  System.err.println("tabularSetup.jsp called without any data tracks") ;
  GenboreeUtils.sendRedirect(request, response, "/java-bin/tabular.jsp") ;
  return ;
}
if(session.getAttribute("tabularLayout") == null && 
  session.getAttribute("tabularLayoutName") == null)
{
  System.err.println("tabularSetup.jsp called without any tabular layout!") ;
  GenboreeUtils.sendRedirect(request, response, "/java-bin/tabular.jsp") ;
  return ;
}

// All required parameters are now in the session
// Forward to display page (all GET parameters should now be in the session)
GenboreeUtils.sendRedirect(request, response, destination) ; 
%>
