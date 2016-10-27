<%@ page import="javax.servlet.http.*, java.util.*, java.sql.*,
org.genboree.dbaccess.*, org.genboree.gdasaccess.*,
org.genboree.util.*, org.genboree.upload.*,
                 org.genboree.message.GenboreeMessage" %>
<%!
  public static long [] calcEditRange (long chromosomeSize)
  {
    // % Range to view depends on the size of the chromosome;
    // smaller % for very large ones and much larger % for smaller ones.
    // Minimum % is 1%. Maximum $ is 50%.
    // The range model is this:
    //    range = 4260*size^(-0.584)
    // This results in:
    //    250,000,000 => 5%  (view range 12,500,000)
    //     50,000,000 => 15% (view range 7,500,000)
    //      5,000,000 => 50% (view range  2,250,000)
    long[] arr = new long[2] ;
    long midPoint = chromosomeSize / 2 ;
    double rangeSizeFraction = 4260*Math.pow( (double)chromosomeSize, -0.584) ;
    if(rangeSizeFraction < 0.01)
    {
      rangeSizeFraction = 0.01 ;
    }
    else if(rangeSizeFraction > 0.5)
    {
      rangeSizeFraction = 0.5 ;
    }
    // Determine range in bases (rounded up)
    long rangeSize = (long)((chromosomeSize * rangeSizeFraction) + 0.5) ;
    // Determine coords
    long from = midPoint - (rangeSize / 2) ;
    if(from < 1)
    {
      from = 1 ;
    }
    long to = from + rangeSize ;
    if(to > chromosomeSize)
    {
      to = chromosomeSize ;
    }
    arr[0] = from ;
    arr[1] = to ;
    return arr ;
  }
%>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%
     GenboreeMessage.clearMessage(mys);
    Connection dbConn = null ;
    int totalFrefCount = -1 ;
    boolean groupChanged = false;
    boolean emptyDB = false;
    String absStart = "1";
    String absStop = "1000";
    long vMinFrom = 1L;
    long vMaxTo = 0;
    boolean isDebugging = false;
    // ARJ: Create a TimingUtil object for easy timing of code
    TimingUtil timer = new TimingUtil(userInfo) ;
    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );
    int i ;
    mys.removeAttribute( "target" );
    myself.setUserId( userInfo[2] );
    myself.fetch( db );
    if( JSPErrorHandler.checkErrors(request,response, db,mys) )
    return;
    myself.fetchGroups( db );
    if( JSPErrorHandler.checkErrors(request,response, db,mys) )
    return;
    mys.setAttribute( "myself", myself );

    String editRefSeqId = request.getParameter( "refSeqId" );
    String searchstr = request.getParameter("searchstr");
    if( request.getParameter("btnSearch")!=null && searchstr!=null && editRefSeqId!=null )
    {
        String fwdTgt = "/java-bin/genboreeSearchWrapper.jsp";
        fwdTgt = fwdTgt + "?refSeqID=" + editRefSeqId + "&query=" + Util.urlEncode(searchstr);
        Refseq crs = new Refseq();
        crs.setRefSeqId( editRefSeqId );
        crs.fetch( db );
        if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
        String acs = Refseq.fetchUserAccess( db, crs.getDatabaseName(), "0" );

        if( !Util.isEmpty(acs) )
        {
            fwdTgt = fwdTgt + "&ip=y";
        }
        GenboreeUtils.sendRedirect(request,response,  fwdTgt );
        return ;
        }

        Vector v = new Vector();
        for( i=0; i<grps.length; i++ )
        {
        String[] rsids = grps[i].getRefseqs();
        //  if( rsids!=null && rsids.length>0 )
        v.addElement( grps[i] );
        }
        grps = new GenboreeGroup[ v.size() ];
        v.copyInto( grps );
        String groupId = request.getParameter( "groupId" );

        String pageGroupId = groupId;
        boolean grp_hard = !is_public;
        if( groupId == null )
        {
        groupId = SessionManager.getSessionGroupId(mys);
        grp_hard = false;
        }

        String sessionGroupId =  SessionManager.getSessionGroupId(mys);
        if (  (pageGroupId != null && sessionGroupId != null && sessionGroupId.compareTo(pageGroupId )!=0))
        groupChanged = true;

        if (groupChanged)   {
            groupChanged = true;
            mys.removeAttribute("lastBrowserView");
            mys.removeAttribute( "editStart" );
            mys.removeAttribute( "editStop" );
            mys.removeAttribute( "editEP" );
        }

        if( groupId == null )
        groupId = "#";
        GenboreeGroup grp = null;
   // grp = (GenboreeGroup)mys.getAttribute( "uploadGroup" );
        for( i=0; i<grps.length; i++ )
        {
            if( grps[i].getGroupId().equals(groupId) )
            {
            grp = grps[i];
            break;
            }
        }
        if( grp == null && grps.length > 0 )
        {
            grp = grps[0];
            groupId = grp.getGroupId();
        }

        if(grp != null)
        {
            currentGroupName = grp.getGroupName();
            currentGroupId = grp.getGroupId();
//            mys.setAttribute("uploadGroup", grp);
            SessionManager.setSessionGroupId(mys, groupId) ;
        }
        else
        grp = new GenboreeGroup();

       Refseq[] rseqs = Refseq.fetchAll( db, grps );
        if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
         if (rseqs != null)

        if( rseqs == null ) rseqs = new Refseq[0];
         //  mys.setAttribute( "RefSeqs", rseqs );

        // display popup links
        String sPopupLinks = request.getParameter( "popup_links" );
        if( sPopupLinks == null ) sPopupLinks = (String) mys.getAttribute( "popup_links" );
        int iPopupLinks = Util.parseInt( sPopupLinks, 1 );
        mys.setAttribute( "popup_links", ""+iPopupLinks );
        boolean popup_links = (iPopupLinks == 1);

        String editStart = Util.remCommas( request.getParameter("startPos") );
        String editStop = Util.remCommas( request.getParameter("endPos") );

      /*  if (editStart != null)
        editStart = editStart.trim();

        if( editStart == null || editStart.compareTo("") ==0)
        editStart = (String) mys.getAttribute( "editStart" );

        if (editStop != null)
        editStop = editStop.trim();

        if( editStop == null || editStop.compareTo("") ==0) editStop = (String) mys.getAttribute( "editStop" );
          */

        String oldEditRefSeqId = SessionManager.getSessionDatabaseId(mys);
//  if database changed, need reset session variables as well
       String editEP = request.getParameter( "entryPointId" );

        if (editRefSeqId != null  &&  oldEditRefSeqId != null && editRefSeqId.compareTo(oldEditRefSeqId) !=0) {
            mys.removeAttribute("lastBrowserView");
            mys.removeAttribute( "editStart" );
            mys.removeAttribute( "editStop" );
            mys.removeAttribute( "editEP" );
            editEP = null;
            editStart = null;
            editStop = null;
        }


        if( editRefSeqId == null ) editRefSeqId = oldEditRefSeqId;
        if(editRefSeqId == null || editRefSeqId.equals("#")){
            //editRefSeqId = rseqs[0].getRefSeqId();
            groupChanged = true;
        }
        String oldEditEP = (String) mys.getAttribute( "editEP" );
        if( editEP!=null && (oldEditEP==null || !oldEditEP.equals(editEP)) )
        editStart = editStop = null;
        if( editRefSeqId != null && !grp_hard ){
            GenboreeGroup oldGrp = grp;
            if( grp!=null && !grp.belongsTo(editRefSeqId) ) {
                groupChanged = true;
                grp = oldGrp;
            }
        }

        grp.fetchUsers( db );
        grp.fetchRefseqs( db );
        if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
        groupId = grp.getGroupId();

        boolean i_am_owner = is_admin || grp.isOwner( myself.getUserId() );
        boolean is_ro_group = !is_admin && grp.isReadOnly( myself.getUserId() );
        String myGrpAccess = "SUBSCRIBER";
        if( !is_ro_group ) myGrpAccess = i_am_owner ? "ADMINISTRATOR" : "AUTHOR";
        String[] myrs = grp.getRefseqs();
        if( editRefSeqId == null && myrs != null && myrs.length > 0 ) {
            editRefSeqId = "#";
            editEP = null;
            editStart = editStop = null;
            groupChanged = true;
        }
         v = new Vector();
        for( i=0; i<rseqs.length; i++ ){
            Refseq rs = rseqs[i];
            if( grp.belongsTo(rs.getRefSeqId()) ) v.addElement( rs );
        }
        rseqs = new Refseq[ v.size() ];
        v.copyInto( rseqs );
       Refseq editRefseq = null;
        if( editRefSeqId != null )
        {
        for( i=0; i<rseqs.length; i++ )
            if( rseqs[i].getRefSeqId().equals(editRefSeqId) )
            {
                editRefseq = rseqs[i];
                break;
            }
        }

        if( editRefseq == null ){
            editEP = null;
            editStart = editStop = null;
            groupChanged = true;
            editRefSeqId = "#";
        }


        timer.addMsg("DONE - Initial set up (group stuff, refSeq stuff, popup stuff).") ;
        boolean view_enabled = true;
        String dbName = "#";
        String refseqName = "";
        String refseqVersion = "";
        String epUrl = "--previous--";
        DbFref[] frefs = null ;

        if( editRefseq != null  )   {
            dbName = editRefseq.getDatabaseName();

            if(dbConn == null)
                dbConn =  db.getConnection(dbName) ;
            refseqVersion = editRefseq.getRefseq_version();
            refseqName = editRefseq.getRefseqName();

        // ARJ: Try to get the frefs using the new standard way
            if( frefs == null || frefs.length==0 ){
            try{
                totalFrefCount = DbFref.countAll(dbConn) ;
                if(totalFrefCount <= Constants.GB_MAX_FREF_FOR_DROPLIST){
                    frefs = DbFref.fetchAll( dbConn ) ;
                }
                else {     // Too many entrypoints
                    frefs = new DbFref[0] ;
                }
            }
            catch( Exception ex01 ){
                System.err.println("EXCEPTION: defaultGbrowser.jsp failed to get frefs because:") ;
                ex01.printStackTrace(System.err) ;
            }
            timer.addMsg("DONE - fetched EPs from refSeq object" ) ;
            }
        }    //
        else{
            view_enabled = false;
        }

        if( frefs == null ) {
            frefs = new DbFref[0] ;
            view_enabled = false;
        }
        DbFref currFref = null;
        if (editEP != null && editEP.compareTo("")==0)
        editEP = null;
       //  case 1:  get chromsome object if name is selected
        if( editEP != null && !editEP.equals("null") ){
            if(dbConn == null)
            dbConn =  db.getConnection(dbName) ;
            currFref = DbFref.fetchByName( dbConn, editEP) ;
              editEP = currFref.getRefname() ;

        }
        else if (dbName != null && !dbName.equals("#"))  {
            if(dbConn == null)
            dbConn =  db.getConnection(dbName) ;
            DbFref[] tmpFrefs = DbFref.fetchAll( dbConn, 1) ; // Gets only 1 fref obj
          if(tmpFrefs != null && tmpFrefs.length > 0) {
                currFref = tmpFrefs[0] ;
                editEP = currFref.getRefname() ;

            }
            else
            {
                emptyDB = true;
                currFref = null;
                editEP = null;
                if (!groupChanged)
                GenboreeMessage.setErrMsg(mys, "There is no annotation to display.<br>  -- Please goto my databases,  upload data and try again.");
            }
        }

        if( currFref != null ){
            absStop = currFref.getRlength() ;
              vMaxTo = Util.parseLong( currFref.getRlength(), 1000L );
          }

        if( editStart == null || editStop == null ){
            try
            {
                long lAbsStart = Long.parseLong( absStart );
                long lAbsStop = Long.parseLong( absStop );
               long [] arr = calcEditRange(lAbsStop);
                 editStart = "" + arr[0];
            editStop = "" + arr[1];
            } catch( Exception ex ) {
                ex.printStackTrace();
            }
        }
        SessionManager.setSessionGroupId(mys, groupId) ;
        SessionManager.setSessionDatabaseId(mys, editRefSeqId ) ;
        mys.setAttribute( "editEP", editEP );
        mys.setAttribute( "editStart", editStart );
        mys.setAttribute( "editStop", editStop );
        mys.removeAttribute( "featuretypes" );
      if (rseqs == null || rseqs.length ==0) {
           GenboreeMessage.setErrMsg(mys, "There is no database in the group '"+ grp.getGroupName() + "'. <BR> -- Please go to the 'My Databases' to create a new database.");
      }
     if( request.getParameter("btnView") != null ){
          GenboreeUtils.sendRedirect(request,response,  "/java-bin/gbrowser.jsp?" + "refSeqId=" + editRefSeqId + "&entryPointId=" + editEP +  "&from=" + editStart + "&to=" + editStop );
            return;
        }
        mys.setAttribute( "destback", "defaultGbrowser.jsp" );
 %>
<HTML>
<head>
    <title>Genboree - Genome Browser Gateway</title>
    <link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
    <link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">
    <script src="/javaScripts/prototype.js<%=jsVersion%>" type="text/javascript"></script>
    <script src="/javaScripts/util.js<%=jsVersion%>" type="text/javascript"></script>
    <script src="/javaScripts/defaultGbrowser.js<%=jsVersion%>" type="text/javascript"></script>
    <script type="text/javascript" src="/javaScripts/commonFunctions.js<%=jsVersion%>"></script>
    <meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
<script type="text/javascript">
var absStart = <%=absStart%>;
var absStop = <%=absStop%>;
var cAbsStop = "<%=Util.putCommas(absStop)%>";
var minFrom = <%=vMinFrom%>;
var maxTo = <%=vMaxTo%>;
var entryPointSize = new Array();
<%
    if(totalFrefCount <= Constants.GB_MAX_FREF_FOR_DROPLIST){
      for(int ii = 0; ii < frefs.length; ii++)
      {
        out.println("entryPointSize[\"" + frefs[ii].getRefname() + "\"] = " + frefs[ii].getRlength() + ";");
       }
    }
%>
</script>

</head>
<BODY bgcolor="#DDE0FF">
<% // <%=Util.htmlQuote(epUrl);%><br>
<%@ include file="include/header.incl" %>
<%@ include file="include/navbar.incl" %>
<%@ include file="include/message.incl" %>
<br>
<form id="refresh" name="refresh" action="defaultGbrowser.jsp" method="post">
<% if( !is_public ) { %>
<input type="hidden" name="groupId" id="groupId" value="<%=groupId%>">
<% } %>
<input type="hidden" name="refSeqId" id="refSeqId" value="<%=editRefSeqId%>">
<input type="hidden" name="entryPointId" id="entryPointId" value="<%=editEP%>">
<input type="hidden" name="startPos" id="startPos" value="<%=editStart%>">
<input type="hidden" name="endPos" id="endPos" value="<%=editStop%>">
</form>
<form id="viewbar" name="viewbar" action="gbrowser.jsp" method="post" target="_top"  onsubmit="return validateViewbar();">
<input type="hidden"  name="grpChanged" id="grpChanged" value="0">
<input type="hidden"  name="databaseChanged" id="databaseChanged" value="0">

<% if( is_public ) { %>
<input type="hidden" name="isPublic" value="YES">
<% } %>
<table width="100%" border="0" cellpadding="2" cellspacing="0" align="center">
<% if( !is_public ) {
%>
<tr>
    <td class="form_header" colspan="6">Group:&nbsp;&nbsp;
        <select name="groupId" id="groupId"  class="txt" style="width:200" onchange="submitRefresh(<%=is_public%>)">
        <%
        for( i=0; i<grps.length; i++ )
        {
            String myId = grps[i].getGroupId();
            String sel = myId.equals(groupId) ? " selected" : "";
        %>
        <option value="<%=myId%>"<%=sel%>><%=Util.htmlQuote(grps[i].getGroupName())%></option>
        <% } %>
        </select>
        &nbsp;&nbsp;<font color="#CCCCFF">Role:</font>&nbsp;&nbsp;<%=myGrpAccess%>
    </td>
</tr>

<tr>
<td colspan="6" style="height:2"></td>
</tr>
<% } // !is_public %>

<tr>
    <td class="form_header">Database</td>
    <td class="form_header">Assembly&nbsp;</td>
    <td class="form_header">&nbsp;Entry Point</td>
    <td class="form_header">From</td>
    <td class="form_header">To</td>
    <td class="form_header">&nbsp;</td>
</tr>
<tr>
    <td class="form_body">
        <select name="refSeqId" id="refSeqId" onchange="changeDB(<%=is_public%>)" class="txt" style="width:200">
       <% if (rseqs != null && rseqs.length>0) { %>
        <%  if (groupChanged ){%>
        <option value="test" selected>--Please select a database--</option>
        <% }
        for( i=0; i<rseqs.length; i++ )
        {
            String myId = rseqs[i].getRefSeqId();
            String sel = "";
            if (!groupChanged)
                sel = myId.equals(editRefSeqId) ? " selected" : "";
            %>
            <option value="<%=myId%>" <%=sel%> ><%=rseqs[i].getRefseqName()%></option>
        <% }
        }
        else  { %>
           <option value="" " =sel" >-- No database exist --</option>
        <%}%>
        </select>
    </td>

    <td class="form_body">
        <table border="1" cellspacing="0" cellpadding="0" width="100%">
            <tr>
                <% if (!groupChanged && !emptyDB) { %>
                <td bgcolor="white">
                <strong><%=Util.htmlQuote(refseqVersion)%></strong>&nbsp;
                </td>
                <% } else { %>    <td disabled> &nbsp;
               <!--input disabled  type="text"   class="txt" style="width:50"-->
                </td>
                <%}%>
            </tr>
        </table>
    </td>
    <td class="form_body">
    <%
    // ------------------------------------------------------------------------
    // ARJ 8/22/2005 3:33PM :
    //   Construct the entrypoint droplist/textInput.
    //   If too many, make it a textInput rather than a list.
    // ------------------------------------------------------------------------
    // CASE 1: Have small number of entrypoint. Use droplist. (Most common case.)
    // ------------------------------------------------------------------------

     if(totalFrefCount <= Constants.GB_MAX_FREF_FOR_DROPLIST && !groupChanged && !emptyDB){
            %>
            <select name="entryPointId" id="entryPointId" onchange="updateEntryPointSelected()" class="txt" style="width:100">
            <%  for( i=0; i<frefs.length; i++ )
            {
            String myId = frefs[i].getRefname();
            String sel = "";
            if (!groupChanged )
            sel = myId.equals(editEP) ? " selected" : "";
            String refName = frefs[i].getRefname();
            if (refName == null)
                refName ="";
            %>
            <option value="<%=myId%>"<%=sel%>><%=refName%></option>
            <%
            }
            %>
            </select>
            <%
     }
        else if (!groupChanged && !emptyDB && totalFrefCount > Constants.GB_MAX_FREF_FOR_DROPLIST){
            if (editEP == null)
            editEP ="";
        %>
       <input type="text" name="entryPointId" id="entryPointId" class="txt" style="width:90" value="<%=editEP%>">
        <%
        }
        else if (groupChanged || emptyDB) { %>
        <select disabled name="entryPointId" id="entryPointId" onchange='submitRefresh()' class="txt" style="width:90">
         <option value="" selected>&nbsp;</option>
        <!--input disabled type="text" name="entryPointId" id="entryPointIdSelection" class="txt" style="width:100"  value="" -->
        <%}%>
    </td>
    <td class="form_body" width="13%">
        <% if (!groupChanged && !emptyDB) { %>
        <input name="from" type="text" id="from" value="<%=Util.putCommas(editStart)%>" class="txt" style="width:90">
        <% }
        else { %>
        <input disabled name="from" type="text" id="from"  class="txt" style="width:90">
        <%}%>
    </td>

    <td class="form_body"  width="13%">
        <% if (!groupChanged && !emptyDB) { %>
        <input name="to" type="text" id="to" value="<%=Util.putCommas(editStop)%>" class="txt" style="width:90">
        <% }
        else { %>
        <input disabled name="to" type="text" id="to"  class="txt" style="width:90">
        <%}%>
    </td>
    <%
    if (groupChanged || emptyDB)
    view_enabled = false;
    %>
    <td class="form_body" width="10%">
    <input name="btnView" type="submit" id="btnView" <%=view_enabled ? "" : "disabled "%>value='View' class="btn" style="width:70"  >
    </td>
</tr>
<tr>
    <td colspan="3" class="form_body" align="left">&nbsp;
    <!--
    <strong>
    Display Link Popups:&nbsp;
    <input type="radio" name="popup_links" id="popup_links" value="1"<%=popup_links?" checked":""%>>Yes&nbsp;&nbsp;
    <input type="radio" name="popup_links" id="popup_links" value="0"<%=popup_links?"":" checked"%>>No
    </strong>
    -->
    </td>

    <%  if (!groupChanged && !emptyDB) {  %>
     <td colspan="2" valign="center" class="form_body"  width="26%">
     <input type="hidden" name="rtnSearch" id="rtnSearch"  value="0"  >
    <input type="text" name="searchstr" id="searchstr" class="txt" style="width:184"    onkeypress="processEvent(event);" >
    </td>
    <td class="form_body" width="10%">
    <input type="submit" name="btnSearch" id="btnSearch" value="Search" class="btn" style="width:70"  onClick="$('rtnSearch').value='1'" >
    </td>
        <%}
    else { %>
     <td colspan="2" valign="center" class="form_body" width="26%">
    <input disabled type="text" name="searchstr" id="searchstr" class="txt" style="width:184">
    </td>
   <td class="form_body" width="10%">
    <input disabled type="submit" name="btnSearch" id="btnSearch" value="Search" class="btn" style="width:70">
    </td>
    <%}%>

</tr>
<%  if( grps != null ) { %>
<tr><td colspan="6"><FONT COLOR=RED>If the menu bar does not refresh use the shift +reload combination to force the page to reload </font></td></tr>

<tr>
<td colspan="4" class="form_header">
You are a member of the following group(s):
</td>
<td colspan="2" class="form_header">
Role
</td>
</tr>
<%    for( i=0; i<grps.length; i++ )
{
GenboreeGroup g = grps[i];
String acs = "AUTHOR";
if( g.isOwner(myself.getUserId()) )
acs = "ADMINISTRATOR";
else if( g.isReadOnly(myself.getUserId()) )
acs = "SUBSCRIBER";
if( i>0 ) { %>
<tr><td colspan="6" height="2"></td></tr>
<%      } %>
<tr>
<td colspan="4" class="form_body"><strong><%=g.getGroupName()%></strong></td>
<td colspan="2" class="form_body"><strong><%=acs%></strong></td>
</tr>
<%
}
}
%>
</table>
</form>
<%@ include file="include/footer.incl" %>
</BODY>
</HTML>
