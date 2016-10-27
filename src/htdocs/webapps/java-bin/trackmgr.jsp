<%@ include file="include/trackmgr.incl" %>
<HTML>
<head>
<title>Genboree - Track Management</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">
<link rel="stylesheet" href="/styles/colorWheel.css<%=jsVersion%>" type="text/css">
<!-- Page-specific style-sheet: -->
<link rel="stylesheet" href="/styles/trackmgr.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
<!-- ----------------------------------------------------------------------- -->
<!-- Define the validation function -->
<!-- - goes in the <head> section, officially -->
<!-- ----------------------------------------------------------------------- -->
<!-- Common javascript utils. Not Genboree nor page specific: -->
  <script src="/javaScripts/util.js<%=jsVersion%>" type="text/javascript"></script>
<!-- Prototype/script.aculo.us libraries for great UI effects: -->
  <script src="/javaScripts/prototype.js<%=jsVersion%>" type="text/javascript"></script>

 <script src="/javaScripts/scriptaculous.js<%=jsVersion%>" type="text/javascript"></script>
<!-- Overlib libraries for popups -->
<SCRIPT type="text/javascript" src="/javaScripts/overlib.js<%=jsVersion%>"></SCRIPT>
<SCRIPT type="text/javascript" src="/javaScripts/overlib_hideform.js<%=jsVersion%>"></SCRIPT>
<SCRIPT type="text/javascript" src="/javaScripts/colorbox.js<%=jsVersion%>"></SCRIPT>
<SCRIPT type="text/javascript" src="/javaScripts/trkmgrcolor.js<%=jsVersion%>"></SCRIPT>
<SCRIPT type="text/javascript" src="/javaScripts/util.js<%=jsVersion%>"></SCRIPT>
<SCRIPT type="text/javascript" src="/javaScripts/colorWheel.js<%=jsVersion%>"></SCRIPT>
<SCRIPT type="text/javascript" src="/javaScripts/overlib_draggable.js<%=jsVersion%>"></SCRIPT>
<!-- Official extension to use css style classes for the title bar appearance -->
<script type="text/javascript" src="/javaScripts/overlib_cssstyle.js<%=jsVersion%>"></script>
<!-- Page-specific javascript -->
<script src="/javaScripts/trackmgr.js<%=jsVersion%>" type="text/javascript"></script>
</head>
<BODY >
<div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>

<%  //include loaded
String[] lkmodeids = LinkConstants.modeIds;
String[] lkmodeLabels = LinkConstants.modeLabs;
String pMode = request.getParameter("mode");
Vector lkBtns = new Vector();
lkBtns.add(btnCreate);
lkBtns.add(btnUpdate );
lkBtns.add(btnDelete);
lkBtns.add( btnAssign );
lkBtns.add( btnHelp );
if( mode == TrackMgrConstants.MODE_STYLES )
{
%>
  <SCRIPT type="text/javascript">
<%
  Style [] coloList = info.getColorList();
  if(coloList != null)
  {
    int nColors = info.getColorList().length;
    int nColumns = 12;
    coloList = Style.sortByColors(info.getColorList(), 12 );
    for( i=0; i<nColors; i++ ){
    String curColor = info.getColorList()[i].color;
    if( curColor.startsWith("#") )
    curColor = curColor.substring(1);
    out.println( "colorArray["+i+"]='"+curColor+"';" );
    }
    int nRows = (nColors + nColumns - 1) / nColumns;
    out.println( "nColors="+nColors+";" );
    out.println( "nColorColumns="+nColumns+";" );
    out.println( "nColorRows="+nRows+";" );
    int wHeight = nRows * 20 + 50;
    out.println( "cBoxHeight="+wHeight+";" );
%>
    var styleSampleList = new Object();
    var ssimg ;
<%
    for( i=0; i<info.getStyleList().length; i++ )
    {
      String styleId = info.getStyleList()[i].name;
      String styleUrl = (String) htSampleStyleMap.get( styleId );
      if( styleUrl == null )
      {
        styleUrl = TrackMgrConstants.sampleStyleUrls[0];
      }
%>
      ssimg = new Image() ;
      ssimg.src = "<%=styleUrl%>" ;
      // styleSampleList[<%=i%>] = ssimg;
      styleSampleList["<%=styleId%>"] = ssimg;
<%
    }
  }
%>
  </SCRIPT>
<%
} // END:  if MODE_STYLES %>
<%@ include file="include/sessionGrp.incl" %>
<%@ include file="include/header.incl" %>
<%@ include file="include/navbar.incl" %>
<%
String [] modeids =  TrackMgrConstants.modeIds;
String [] modeLabels =  TrackMgrConstants.modeLabs;
String hrefStart = "trackmgr.jsp";
String labelNameStart = "Track&nbsp;Manager";
String href =  "linkmgr.jsp";
String labelName ="Link&nbsp;Setup";
if(origMode <0 || origMode >= TrackMgrConstants.modeIds.length )
origMode = 0;
%>
<table border="0" cellspacing="4" cellpadding="2">
<tr>
<td><a href="<%=info.getDestback()%>">&laquo;</a>&nbsp;&nbsp;</td>
<td class="nav_selected">
<a href=<%=hrefStart%>><font color=white><%=labelNameStart%></font></a>
</td>
<td>:&nbsp;</td>
<%
int idlength = modeids.length;

for( i=0; i<idlength; i++  )
{
String cls = "nav";
String a1 = "<a href=\"trackmgr.jsp?mode="+modeids[i]+"\">";
String a2 = "</a>";
if( i == mode )
{
cls = "nav_selected";
a1 = a1 + "<font color=white>";
a2 = "</font>" + a2;
}
%>
<td class="<%=cls%>"><%=a1%><%=modeLabels[i]%><%=a2%></td>
<%
}
%>
<td class="nav"><a href=<%=href%>><%=labelName%></a></td>
</tr>
</table>
<%@ include file="include/message.incl" %>
<form name="trkmgr" id="trkmgr" action="trackmgr.jsp" method="post" onSubmit="return handleSubmit(this); ">
<%
if( origMode != TrackMgrConstants.MODE_DEFAULT)
{
%>
<input type="hidden" name="mode" id="mode" value="<%=TrackMgrConstants.modeIds[origMode]%>">
<input type="hidden" name="b2b" id="b2b" value="<%=mode%>">
<input type="hidden" name="deleteTrack" id="deleteTrack" value="0">
<input type="hidden" name="btnReset2Default" id="btnReset2Default" value="">
<% } // END: if( mode != MODE_DEFAULT ) %>
<table border="0" cellpadding="4" cellspacing="2" width="100%">
<tr>
<%@ include file="include/groupbar.incl" %>
</tr>
<tr>
<%@ include file="include/databaseBar.incl" %>
</tr>
</table>
<table border="0" cellpadding="4" cellspacing="0">
<tr>
<td>
<%
  for( i=0; i<vBtn.size(); i++ )
  {
    btn = (String []) vBtn.elementAt(i);
    String onclick = (btn[3]==null) ? "" : btn[3];
    if(mode == TrackMgrConstants.MODE_DELETE && i == 2)
    {
      %>&nbsp;&nbsp;&nbsp;&nbsp;<%
    }

    if(mode == TrackMgrConstants.MODE_ORDER ||mode == TrackMgrConstants.MODE_STYLES )
    {

      if (i!=vBtn.size()-1)
      {
        onclick = btn[4];
      }
    }
%>
<input type="<%=btn[0]%>"  title="<%=btn[3]%>" name="<%=btn[1]%>" id="<%=btn[1]%>" value="<%=btn[2]%>" class="btn" onClick="<%=onclick%>"   >
<%
  }
%>
</td>
</tr>
</table>
<%
if( info.isNo_acs() ){
%>
<p><strong>Sorry, you do not have enough privilege to perform this operation.</strong></p>
<%  }
if (rseq!= null) {
    if( mode == TrackMgrConstants.MODE_ORDER ){%>
    <table border="0" cellpadding="2" width="100%">
    <tr>
    <td class="form_header" width="1%"><strong>Order</strong></td>
    <td class="form_header"><strong>&nbsp;&nbsp;Track&nbsp;Name</strong></td>
    </tr>
    <tr>
    <td COLSPAN="2">
    <P>
    Drag-and-drop the tracks listed below to get the order you desire.<BR>
    <FONT SIZE="-2">(Provide <A HREF="mailto:brl_admin@brl.bcm.tmc.edu">feedback</A> about this user interface.)</FONT>
    </P>
    <OL class="sortablelist" id="rearrange_list1" style="list-style-type:none; ">
    <%
    if(orderTracks!=null && orderTracks.length>0){
        int maxTimes = (int)Math.floor(Math.log(orderTracks.length)/Math.log(10.0)) ;
        for( int ii=0; ii<orderTracks.length; ii++ ){
            int ll = ii + 1 ;
            int times = (int)Math.abs(maxTimes - Math.floor(Math.log(ll)/Math.log(10.0))) ;
            DbFtype ft = orderTracks[ii];
            if(ft == null)
            continue;
            String trackName = ft.toString();
            String hTrackName = Util.htmlQuote(trackName);
            String listItemID = "trkOrd" + ll;
            %>
            <LI ID="<%=listItemID%>" >
            <span style='width: 10px;'><%= ll %>.<% for(int kk=0; kk<times; kk++) { %>&nbsp;<% } %></span>
            <span class="handle" <% if(times > 0) { %>style='padding-left:<%= 5*times %>px;' <% } %>>Drag</span>
            <strong style="cursor:move" >&nbsp;<%=hTrackName%></strong>
            <input type="hidden" size="4" name="<%=hTrackName%>" id="<%=hTrackName%>" value="<%=ft.getSortOrder()%>" class="txt">
            </LI>
        <% }} %>
    </OL>
    </td>
    </tr>
    <TR><TD CLASS="form_header" COLSPAN="2">&nbsp;</TD></TR>
    </table>
<% } // END: MODE_ORDER
if( mode == TrackMgrConstants.MODE_DELETE ){
    %>
    <table border="0" cellspacing="0" cellpadding="2" width="100%">
    <tr>
    <td class="form_header">Track&nbsp;Name</td>
    <td class="form_header" width="50">Deletable?</td>
    <td class="form_header" width="2"></td>
    <td class="form_header" width="80">Delete</td>
    </tr>
    <%
    int rowCount = 0;
    int count = 0;
    if(tracks!=null && tracks.length>0){
    for( i=0; i<tracks.length; i++ ){
        String altStyle = ((rowCount%2) == 0) ? "form_body" : "bkgd";
        rowCount ++;
        DbFtype ft = tracks[i];
        String ftName = ft.toString();
        boolean allowEdit = true;
        if (shareTrackList.contains(ftName)) {
            allowEdit = false;
            count ++;
        }

        String [] colors = new String [] { "#d3cfe6", "#eae6ff" };
        if(allowEdit){
    %>
    <tr>
    <td class="<%=altStyle%>"><%=Util.htmlQuote(ft.toString())%></td>
    <td class="<%=altStyle%>">Yes</td>
    <td class="<%=altStyle%>" width="2"></td>
    <td class="<%=altStyle%>">
    <input type="checkbox" name="delTrkId" id="delTrkId" <%=checked%> value="<%=ft.getFtypeid()%>">
    </td>
    </tr>
    <% }
      else {
    %>
    <tr>
    <td bgcolor = <%=colors[i%2]%>>  <%=Util.htmlQuote(ft.toString()) %></td>
    <td class="<%=altStyle%>">No. <font color="blue"><NOBR>(Template Track. Protected.)</NOBR></font></td>
    <td class="<%=altStyle%>" width="2"></td>
    <td class="<%=altStyle%>"></td>
    </tr>
    <%}
     if (!allowEdit && shareTrackList != null && count == shareTrackList.size() && localTracks != null && localTracks.length >0) {
         altStyle =  ((i%2) == 0) ?  "bkgd": "form_body" ;
           rowCount ++;
    %>

    <tr>
<td class="<%=altStyle%>" colspan="4">
<hr>
</td>
</tr>


 <% }  }
    }%>
    </table>
<% } // END: MODE_DELETE
    if( mode == TrackMgrConstants.MODE_RENAME ){
%>
      <table border="0" cellspacing="0" cellpadding="2" width="100%">
      <tr>
        <td class="form_header">Original&nbsp;Name</td>
        <td class="form_header" width="60">Can Rename?</td>
        <td class="form_header" style="width:120">Type</td>
        <td class="form_header" style="width:120">Subtype</td>
      </tr>
<%
String dbName = info.getDbName();
if(dbName== null )
dbName = "##";
String [] colors = new String [] { "#d3cfe6", "#eae6ff" };
// Print all shared tracks at the top, sorted, but not editable.
int rowCount = 0 ;
if(shareTracks != null && shareTracks.length>0 ){
for( int ii=0; ii<shareTracks.length; ii++, rowCount++ ){
String altStyle = ((rowCount%2) == 0) ? "form_body" : "bkgd";
DbFtype ft = shareTracks[ii] ;
Hashtable h = info.getHtTrkErr();
if(ft==null)
continue;
String featureType =  ft.toString();
String methId = "meth_"+ft.getFtypeid();
String srcId = "src_"+ft.getFtypeid();
%>
<tr>
<td bgcolor=<%=colors[ii%2]%>>  <%=Util.htmlQuote(featureType) %></td>
<td class="<%=altStyle%>">No. <font color="blue"><NOBR>(Template Track. Protected.)</NOBR></font></td>
<td class="<%=altStyle%>">
<input READONLY type="text" name="<%=methId%>" id="<%=methId%>" class="txt" style="background-color: #E0E0E0; width:120" value="<%=Util.htmlQuote(ft.getFmethod())%>" >
</td>
<td class="<%=altStyle%>">
<input READONLY type="text"  name="<%=srcId%>" id="<%=srcId%>" class="txt" style="background-color: #E0E0E0; width:120" value="<%=Util.htmlQuote(ft.getFsource())%>">
</td>
</tr>
<%
}
}
if( shareTracks != null && shareTracks.length>0 &&
localTracks != null && localTracks.length>0 )
{
%>
<tr>
<td class="<%= ((rowCount%2) == 0) ? "form_body" : "bkgd" %>" colspan="4">
<hr>
</td>
</tr>
<%
rowCount++ ;
}
if(localTracks != null && localTracks.length>0 )
{
for( i=0; i<localTracks.length; i++, rowCount++ )
{
String altStyle = ((rowCount%2) == 0) ? "form_body" : "bkgd";
DbFtype ft = localTracks[i];
Hashtable h = info.getHtTrkErr();
if(ft==null)
continue;
if( (h.get(""+ft.getFtypeid())) != null )
altStyle="form_fixed";

String featureType =  ft.toString();
String methId = "lclType_"+ft.getFtypeid();
String srcId = "lclSubtype_"+ft.getFtypeid();
%>
<tr>
<td class="<%=altStyle%>"><%=Util.htmlQuote(ft.toString())%></td>
<td class="<%=altStyle%>">Yes</td>
<td class="<%=altStyle%>">
<input type="text" name="<%=methId%>" id="<%=methId%>" class="txt" style="width:120" value="<%=Util.htmlQuote(ft.getFmethod())%>">
</td>
<td class="<%=altStyle%>">
<input type="text" name="<%=srcId%>" id="<%=srcId%>" class="txt" style="width:120" value="<%=Util.htmlQuote(ft.getFsource())%>">
</td>
</tr>
<%
}
}
%>
</table>
<script language="JavaScript">
var trkIdArray = new Object();
var ntrkids ;
<%  if(tracks!=null && tracks.length>0)
    {
%>
      ntrkids = <%=tracks.length%> ;
<%
      for( i=0; i<tracks.length; i++ )
      {
        DbFtype ft = tracks[i];
        if(ft==null)
          continue;
        out.println( "trkIdArray["+i+"]='"+ft.getFtypeid()+"';" );
      }
    }
%>
</script>
<%
  } // END: MODE_RENAME
  if( mode == TrackMgrConstants.MODE_STYLES )
  {
%>
    <input type="hidden" name="testElem" id="testElem" value="test" >
    <table border="0" cellpadding="2" width="100%">
    <tr>
      <td class="form_header">Track</td>
      <td class="form_header" width="34%">Style</td>
      <td class="form_header" width="10%">Sample</td>
      <td class="form_header" width="12%">
        <a href="javascript:void(0);" ONCLICK="MyWindow=window.open('/colors.html', 'ColorWindow','toolbar=no,location=no,directories=no,status=no,menubar=no,scrollbars=no,resizable=yes,width=250,height=600,left=500,top=20'); return false;" >
        <font color="white">Color</font></a>
      </td>
    </tr>
<%
   if(styles != null)
   {
     for( i=0; i<styles.length; i++ )
     {
        Style st = styles[i] ;
        String trackDatabaseName = st.databaseName ;
        if(st == null)
        {
          continue ;
        }
        String trackName = st.fmethod + ":" + st.fsource ;
        // Skip these two special track names
        if( trackName.compareToIgnoreCase("Component:Chromosome") == 0 ||
            trackName.compareToIgnoreCase("Supercomponent:Sequence") == 0 )
        {
          continue ;
        }
        // Is this an HDHV track? Check all databases for the HD flag.
        boolean isHDHV = FtypeTable.fetchHighDensityFlag(dbNames, trackName) ;
        String felemId = trackName + ":style" ;
        String hfElemId = Util.htmlQuote(felemId) ;
        String qfElemId = Util.simpleJsQuote(hfElemId) ;
        String imgUrl = (String) htSampleStyleMap.get( st.name ) ;
        if( imgUrl == null )
        {
          imgUrl = TrackMgrConstants.sampleStyleUrls[0] ;
        }
        // id/name of the <img> tag
        String picId = "pic_" + i ;
%>
      <tr>
        <td class="form_body"><%=Util.htmlQuote(trackName)%></td>
        <td class="form_body">
          <select class="txt" style="width: 100%; " onChange="changePic(this,'<%=picId%>')" name="<%=hfElemId%>" id="<%=hfElemId%>">
<%
          for( int j=0; j<styleList.length; j++ )
          {
            Style cst = styleList[j] ;
            String isSel = cst.name.equals(st.name) ? " selected" : "" ;
            if(  isSel.equals(" selected")    ||
                (!isHDHV) ||
                (isHDHV &&
                  (cst.name.equals("local_scoreBased_draw") ||
                  cst.name.equals("local_largeScore_draw") ||
                  cst.name.equals("scoreBased_draw") ||
                  cst.name.equals("largeScore_draw") ||
                  cst.name.equals("bidirectional_draw_large") ||
                  cst.name.equals("bidirectional_local_draw_large")
                ))
              )
            {

%>
              <option value="<%=cst.name%>"<%=isSel %>><%=Util.htmlQuote(cst.description)%></option>
<%
            }
          }
%>
          </select>
        </td>
        <td class="form_body">
          <img src="<%=imgUrl%>" border="0"  name="<%=picId%>" id="<%=picId%>">
        </td>
        <td class="form_body" nowrap>
<%

          String imgId = "colordiv"+i;
          String wheelLink = "wheelLink" + i;
          String elemId = Util.urlEncode(trackName) ;
          String curColor = st.color;
          if( curColor.startsWith("#") )
            curColor = curColor.substring(1);
%>
<a href="javascript:void(0);" onClick="setDivId('<%=imgId%>','<%=elemId%>', '<%=curColor%>');">
<div   name="<%=imgId%>" id="<%=imgId%>"   class="colorIcon"  style="background-color:<%=curColor%>"  onClick="setDivId('<%=imgId%>','<%=elemId%>', '<%=curColor%>');"  >
</div>
<div  class="bottomdiv" onClick="setDivId('<%=imgId%>', '<%=elemId%>', '<%=curColor%>');">&nbsp;Change</div></a>
<input type="hidden" name="<%=elemId%>" id="<%=elemId%>" value="#<%=curColor%>" >
</td>
</tr>
<%
      }
    }
    timer.addMsg("DONE: laying out style setup HTML.") ;
    timer.writeTimingReport(System.err) ;
%>
  </table>
<% } // END: MODE_STYLE

    if( mode == TrackMgrConstants.MODE_URL )
    {
      if(info.getUrltracks()!=null && info.getUrltracks().length>0)
      {
%>
    <table border="0" cellspacing="1" cellpadding="2" width="100%">
        <tr>
            <td class="form_header">Tracks</td>
            <td class="form_header">
            <select name="ftypeid" id="ftypeid" class="txt" style="width:540" onChange="this.form.submit();">
            <%
          for( i=0; i<info.getUrltracks().length; i++ ){
                DbFtype ft = info.getUrltracks()[i];
                String sel = (ft.toString().compareTo(info.getEditTrack().toString())==0) ? " selected" : "";
            %>
            <option value="<%=ft.toString()%>"<%=sel%>><%=Util.htmlQuote(ft.toString())%></option>
            <%
           }
            %>
            </select>
            </td>
        </tr>
<%
        boolean deletable = true;
        DbFtype ft = info.getEditTrack();
        String dbName = info.getDbName();
        if(fromShareDb){
           deletable = false;
        }
%>
        <tr>
          <td class="form_body" nowrap><b><span id="url_headerText">URL (optional)</span></b></td>
          <td class="form_body">
            <input type="text" name="track_url" id="track_url" class="txt" style="width:540" value="<%=Util.htmlQuote(info.getEditTrack().getUrl())%>">
          </td>
        </tr>
        <tr>
          <td class="form_body" nowrap><b><span id="urlLabel_headerText">URL Label (optional)</span></b></td>
          <td class="form_body">
            <input type="text" name="url_label" id="url_label" class="txt" style="width:540" value="<%=Util.htmlQuote(info.getEditTrack().getUrlLabel())%>">
        </td>
        </tr>
        <tr>
          <td class="form_body" valign="top" nowrap><b><span id="trackDescription_headerText">Description</span></b></td>
          <td class="form_body">
            <textarea name="url_description" id="url_description" rows="10" cols="72" class="txt"><%=Util.htmlQuote(info.getEditTrack().getUrlDescription())%></textarea>
          </td>
        </tr>
        </table>
<%
      }
    } // END: MODE_URL
 %>
<%
 if( mode == TrackMgrConstants.MODE_DEFAULT && tracks!=null && tracks.length>0 )
  {
%>
      <table border="0" cellspacing="0" cellpadding="2" width="100%">
      <tr>
        <td class="form_header">Track&nbsp;List</td>
      </tr>
<%
     int count =0;
     int rowCount = 0;
     if(tracks != null && tracks.length>0)
      {
        for( i=0; i<tracks.length; i++ )
        {



            String altStyle = ((rowCount%2) == 0) ? "form_body" : "bkgd";
           rowCount ++;
            DbFtype ft = tracks[i];
            String ftName = ft.toString();

               boolean allowEdit = true;
        if (shareTrackList != null && shareTrackList.contains(ftName)) {
            allowEdit = false;
            count ++;
        }

    %>

    <tr>
        <%  if (allowEdit )  { %>
        <td class="<%=altStyle%>"><%=Util.htmlQuote(ftName)%></td>
        <% }  else  {
         %>
        <td class="<%=altStyle%>"><%=Util.htmlQuote(ftName)%><font color="blue">&nbsp;&nbsp;<NOBR>(Template Track.)</NOBR></font></td>
        <%
         }%>
    </tr>

  <% if (!allowEdit && shareTrackList != null &&  count == shareTrackList.size()  && localTracks != null && localTracks.length >0) {
   altStyle = ((i%2) == 0) ?  "bkgd" :"form_body";
      rowCount++;
  %>
              <td class="<%=altStyle%>">
              <hr>
              </td>


<%  }
        }
      }
%>
      </table>
<%  } // END: MODE_DEFAULT
    if( mode != TrackMgrConstants.MODE_DEFAULT &&  mode != TrackMgrConstants.MODE_CLASSIFY)
    {
%>
    <br>
    <table border="0" cellpadding="4" cellspacing="0"><tr><td>
<%
    for( i=0; i<vBtn.size(); i++ ){
        btn = (String []) vBtn.elementAt(i);
        String onclick = (btn[3]==null) ? "" : btn[3];
        if(mode == TrackMgrConstants.MODE_DELETE && i == 2){
        %>&nbsp;&nbsp;&nbsp;&nbsp;<%
    }

    if(mode == TrackMgrConstants.MODE_ORDER ||mode == TrackMgrConstants.MODE_STYLES ){

        if (i!=vBtn.size()-1)
        onclick = btn[4];

    }
%>
<input type="<%=btn[0]%>" title="<%=btn[3]%>" name="<%=btn[1]%>" id="<%=btn[1]%>" value="<%=btn[2]%>" class="btn" onClick="<%=onclick%>"   >
<%}%>
</td></tr></table>
<%
  }
}
  timer.writeTimingReport(System.err) ;
%>
</form>
<%@ include file="include/footer.incl" %>
</BODY>
</HTML>
