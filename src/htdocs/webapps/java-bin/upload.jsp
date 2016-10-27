<%@ page import="javax.servlet.http.*, java.util.Enumeration, org.genboree.dbaccess.*, org.genboree.dbaccess.util.*,
    org.genboree.gdasaccess.*, org.genboree.util.*, org.genboree.upload.*, java.sql.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%
    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );
%>
<%
  if( request.getParameter("btnBack") != null )
	{
		String destback ="/java-bin/myrefseq.jsp?mode=Upload";
		GenboreeUtils.sendRedirect(request, response, destback );
		return;
	}

	int i;
	String refseqId = SessionManager.getSessionDatabaseId(mys);
  String groupId =  SessionManager.getSessionGroupId(mys);
  String groupName = SessionManager.getSessionGroupName(mys);
   int userId = Util.parseInt(myself.getUserId(), -1);

  if( myself==null || groupId==null || refseqId==null )
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/defaultGbrowser.jsp" );
		return;
	}
  String refseqName = SessionManager.findRefSeqName (refseqId, db) ;

  // We need the track names for the current database
  String annoDbName = GenboreeUtils.fetchMainDatabaseName(refseqId) ;
  Connection annoDbConn = db.getConnection(annoDbName) ;
  HashMap trackMap = GenboreeUtils.fetchTracks(annoDbConn, annoDbName, userId) ;
  StringBuffer jsTrackMapBuff = new StringBuffer("var jsTrackMap = $H({") ;
  for(Iterator it=trackMap.entrySet().iterator(); it.hasNext();  )
  {
    Map.Entry entry = (Map.Entry)it.next();
    String encodedTrackName = (String)entry.getKey() ;
    DbFtype dbFtype = (DbFtype)entry.getValue() ;
    jsTrackMapBuff.append("'" + Util.urlEncode(dbFtype.getFmethod()) + ":" + Util.urlEncode(dbFtype.getFsource()) + "': true") ;
    if(it.hasNext())
    {
      jsTrackMapBuff.append(", ") ;
    }
  }
  jsTrackMapBuff.append("}) ;") ;
  String jsTrackMap = jsTrackMapBuff.toString() ;


  // Get database size numbers, based on counts of fdata2, attValues, and fid2attribute
  long fdata2Count = Fdata2Table.count(annoDbConn) ;
  long attValuesCount = AttValuesTable.count(annoDbConn) ;
  long fid2attributeCount = Fid2AttributeTable.count(annoDbConn) ;
  // Get the limits for these values from the config file
  long maxFdata2Count = GenboreeConfig.getLongConfigParam("maxFdata2CountForUpload", -1) ;
  long maxAttValuesCount = GenboreeConfig.getLongConfigParam("maxAttValuesCountForUpload", -1) ;
  long maxFid2AttributeCount = GenboreeConfig.getLongConfigParam("maxFid2AttributeCountForUpload", -1) ;
  String uploadOverrideStr = GenboreeConfig.getConfigParam("overrideNoUploadRefseqList") ;
  String[] uploadOverrideStrs = uploadOverrideStr.split(",") ;
  HashMap uploadingAllowed = new HashMap() ;  // HashMap of refSeqIds for databases that are -allowed- to upload
                                              // even though they are known to exceed some of the above max-Count limits
  for(int ii=0; ii<uploadOverrideStrs.length; ii++)
  {
    uploadingAllowed.put(uploadOverrideStrs[ii], true) ;
  }
  // Ok to upload or not?
  boolean okToUpload =  (
                          !( fdata2Count > maxFdata2Count ||
                            attValuesCount > maxAttValuesCount ||
                            fid2attributeCount > maxFid2AttributeCount
                          ) // then 1+ limits exceeded
                          ||
                          ( uploadingAllowed.containsKey(refseqId) ) // if in special "OK" list, allow regardless of exceeded limits
                        );
%>
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>

  <meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
  <title>Genboree Annotation Uploads</title>
  <!-- BEGIN: Extjs, etc, Support -->
  <script type="text/javascript" src="/javaScripts/extjs/adapter/prototype/prototype.js<%=jsVersion%>"></script>
  <script type="text/javascript" src="/javaScripts/extjs/adapter/prototype/scriptaculous.js<%=jsVersion%>"></script>
  <script type="text/javascript" src="/javaScripts/extjs/adapter/prototype/ext-prototype-adapter.js<%=jsVersion%>"></script>
  <script type="text/javascript" src="/javaScripts/extjs/package/genboree/ext-msgbox-only-pkg.js"></script>
  <script type="text/javascript" src="/javaScripts/extjs/ext-all.js<%=jsVersion%>"></script>
  <script type="text/javascript" src="/javaScripts/progressUpload.js<%=jsVersion%>"></script>

  <link rel="stylesheet" type="text/css" href="/javaScripts/extjs/resources/css/core.css<%=jsVersion%>">
  <link rel="stylesheet" type="text/css" href="/javaScripts/extjs/resources/css/button.css<%=jsVersion%>">
  <link rel="stylesheet" type="text/css" href="/javaScripts/extjs/resources/css/basic-dialog.css<%=jsVersion%>">
  <link rel="stylesheet" type="text/css" href="/javaScripts/extjs/resources/css/ytheme-genboree.css<%=jsVersion%>">
  <link rel="stylesheet" type="text/css" href="/javaScripts/extjs/resources/css/loading-genboree.css<%=jsVersion%>">
  <!-- Set a local "blank" image file; default is a URL to extjs.com -->
  <script type='text/javascript'>
    Ext.BLANK_IMAGE_URL = '/javaScripts/extjs/resources/images/genboree/s.gif';
  </script>
  <!-- END -->
  <!-- BEGIN: Genboree Specific -->
  <script src="/javaScripts/util.js<%=jsVersion%>" type="text/javascript"></script>
  <script src="/javaScripts/commonFunctions.js<%=jsVersion%>" type="text/javascript"></script>
  <script src="/javaScripts/uploadFeature.js<%=jsVersion%>" type="text/javascript"></script>
  <link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
  <link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">
  <link rel="stylesheet" href="/styles/samples.css<%=jsVersion%>" type="text/css">
  <!-- END -->
  <script type="text/javascript">
    <%= jsTrackMap %>
  </script>

  <style>
   td,th { font-size: 8pt; }
  </style


</head>


<body id="bodyId">
<!-- Placeholders for upload message and preload the image -->
<div id="genboree-loading-mask" name="genboree-loading-mask" style="visibility: hidden;"></div>
<div id="genboree-loading" name="genboree-loading" style="visibility: hidden;"><img src="/javaScripts/extjs/resources/images/default/grid/loading.gif"></div>
<%@ include file="include/header.incl" %>
<%@ include file="include/navbar.incl" %>

  <br>
  Please read the following carefully before uploading any data:
  <UL>
    <LI>Genboree Help document: <A HREF="showHelp.jsp?topic=uploadAnnoHowto" target="_helpWin"><SPAN class="helpTopic">&quot;4. Uploading Annotations&quot;</SPAN></A></LI>
    <LI>Genboree Help document: <A HREF="showHelp.jsp?topic=lffFileFormat" target="_helpWin"><SPAN class="helpTopic">&quot;5. The LFF Annotation Format&quot;</SPAN></A></LI>
  </UL>
  <p>Your data must be <A HREF="showHelp.jsp?topic=lffFileFormat" target="_helpWin">formatted
  correctly</A> before uploads will work properly.</p>
  <p>If you would like to overwrite the annotations in an existing track, use the following link to manage your tracks.
  <a href="/java-bin/trackmgr.jsp?mode=Delete" target="_blank">Delete annotation tracks prior to upload</a></p>

  <form name="back" action="uploadFeature.jsp" target="_top" method="post">
    <input type="hidden" name="btnBack" id="btnBack" value="Back">
  </form>

  <form id="norm" name="norm" action="/genbUpload/genboree/upload.rhtml" target="_top" onsubmit="return uploadFormSubmitIt();" method="post" ENCTYPE="multipart/form-data" >
    <input type="hidden" name="rm" value="upload">
    <input type="hidden" name="userId" value="<%=userId%>">
    <input type="hidden" name="refseq" value="<%=refseqId%>">
    <input type="hidden" name="groups" value="<%=groupId%>">
    <input type="hidden" name="origFileName" id="origFileName" value="">
    <input type="hidden" name="idStr" id="idStr" value="">

    <table width="100%" border="0" cellpadding="4">
    <tbody id="uploadUItable">
    <tr>
      <td width="38%" class="form_body">
        <strong>&nbsp;Reference Sequence:&nbsp;</strong>
      </td>
      <td class="form_body">
        <%= ( refseqId==null) ? "-- New Reference Sequence --" : refseqName %>
      </td>
    </tr>
    <tr>
      <td class="form_body">
        <strong>&nbsp;Group:&nbsp;</strong>
      </td>
      <td class="form_body">
        <%=Util.htmlQuote(groupName)%>
      </td>
    </tr>
    <tr>
      <td class="form_body">
        <strong>&nbsp;Upload File:&nbsp;</strong>
      </td>
      <td class="form_body">
        <input type="file" id="upload_file" name="upload_file" class="txt" size="40">
      </td>
    <tr>
      <td colspan="2">
        <strong>&nbsp;&nbsp;&nbsp;&#8212;&nbsp;OR&nbsp;&#8212;</strong>
        &nbsp;paste your data into the box below:<br>
      </td>
    </tr>
    <tr>
      <td colspan="2" class="form_body">
        <textarea rows="10" name="paste_data" wrap="off" style="width:650px; font-size:15px;"></textarea>
      </td>
    </tr>
    <tr>
<%
      if(!okToUpload)
      {
%>
      <td class="form_body" width="18%">
        <font color="red"><b>NOTICE:</b></font>
      </td>
      <td class="form_body" width="81%" valign="middle">
        <font color="red">
          Due to the size of this database, further uploads have been disabled to protect other users.
          <p>
          Number of Annotations: <b><%=fdata2Count%></b><br>
          Number of Unique Attribute Values: <b><%=attValuesCount%></b><br>
          Number of Custom Attribute Associations: <b><%=fid2attributeCount%></b><br>
          <p>
          If you need more information and possibly advice about organizing your data, please contact a <a href="mailto:<%=GenboreeConfig.getConfigParam("gbAdminEmail")%>?subject=Large+database">Genboree Admin</a>.
        </font>
      </td>
<%
      }
      else
      {
%>
      <td class="form_body" width="18%">
        <input type="hidden" id="merge_type" name="merge_type" value="5">
        <strong>Input format</strong>
      </td>
      <td class="form_body" width="81%">
        <select class="txt" id="ifmt" name="ifmt" onchange="formatChanged(this);">
          <option value="lff" selected>LFF (Genboree format)</option>
          <option value="agilent">Agilent Probes</option>
          <option value="blat">Blat (PSL version 3)</option>
          <option value="blast">Blast (Tab delimited)</option>
          <option value="pash">Pash 2.0</option>
          <option value="wig">Wiggle (fixedStep/variableStep)</option>
        </select>
      </td>
<%
      }
%>
    </tr>
    </tbody>
    </table>
    <br>
    <div id="formButtons" <%= (okToUpload ? "" : "style=\"display:none\";")%> >
      <input type="button" name="btnBack" value="&lt;Back" onClick="document.back.submit()" class="btn" style="width:100px;">&nbsp;&nbsp;
      <input type="submit" value="Upload&gt;" class="btn" style="width:100px;">
    </div>
  </form>

<%@ include file="include/footer.incl" %>
</body>
</html>
