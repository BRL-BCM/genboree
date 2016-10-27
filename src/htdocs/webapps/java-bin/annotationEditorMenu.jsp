<%@ page import="java.sql.ResultSet,
java.text.NumberFormat,
java.text.DecimalFormat,
java.io.InputStream,
java.sql.SQLException,
java.util.*,
java.util.regex.Pattern,
java.util.regex.Matcher,
java.sql.Time,
java.lang.reflect.Array,
org.genboree.util.*,
org.genboree.dbaccess.util.*"
%>

<%@ page import="javax.servlet.http.*, org.genboree.upload.HttpPostInputStream " %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%@ include file="include/fidInfo.incl" %>
<%
  boolean trackBlocked = false ;
  response.addDateHeader( "Expires", 0L );
  response.addHeader( "Cache-Control", "no-cache, no-store" );
  String href1 =  "annotationEditor.jsp?upfid=" + textid;
  String href2 =  "annotationGroupEditor.jsp?upfid=" + textid;
  String hrefDelAnno =  "delAnnotationEditor.jsp?upfid=" + textid;
  String hrefDelGrp =  "delAnnotationGroup.jsp?upfid=" + textid;
  String hrefReassignAnno =  "reassignAnnotation.jsp?upfid=" + textid;
  String hrefReassignGrp =  "reassignGroupAnnotation.jsp?upfid=" + textid;
  String hrefDupAnno =  "duplicateAnnotation.jsp?upfid=" + textid;
  String hrefDupGrp =  "duplicateGroupAnnotation.jsp?upfid=" + textid;
  String hrefShiftAnno =  "annotationShift.jsp?upfid=" + textid;
  String hrefShiftGrp =  "annotationGroupShift.jsp?upfid=" + textid;
  String hrefCrate =  "createAnnotation.jsp?upfid=" + textid;
  String hrefRenameGrp =  "renameGroupAnnotation.jsp?upfid=" + textid;
  String hrefAddComment =  "commentGroupAnnotations.jsp?upfid=" + textid;
  String hrefAddAVP =  "addGroupAVP.jsp?upfid=" + textid;
  String hrefGrpColor =  "changeGroupColor.jsp?upfid=" + textid;
  int totalNumAnno = 0;
  if (request.getParameter("upfid") != null )
  {
    Connection con = db.getConnection(dbName);
    // First, are we even allowed to see the details of this annotation?
    // If the track download is blocked, we cannot show details.
    trackBlocked = FtypeTable.isAnnoDownloadBlocked(con, fid) ;
    totalNumAnno = AnnotationEditorHelper.findClassAnnoNum(con, ifid);
  }
%>

<HTML>
<head>
<title>Genboree - Show Annotation Text and Sequence</title>
<script type="text/javascript" src="/javaScripts/util.js<%=jsVersion%>"></script>
<SCRIPT type="text/javascript" src="/javaScripts/commonFunctions.js<%=jsVersion%>"></SCRIPT>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<link rel="stylesheet" href="/styles/annotationEditor.css<%=jsVersion%>" type="text/css">
<link rel="stylesheet" href="/styles/help.css<%=jsVersion%>" type="text/css" >
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY >
    <table cellpadding="0" cellspacing="0" border="0" bgcolor=white width="482" >
        <tr>
            <td width="10"></td>
            <td height="10"></td>
            <td width="10"></td>
            <td width="10" class="bkgd"></td>
        </tr>
        <tr>
	    <td></td>
            <td valign="top"><nobr> <div   style="float: left" >
                <a href="defaultGbrowser.jsp">
                <img src="/images/genboree.jpg" style="margin-top: 0px; padding-top: 0px; margin-bottom: 0px; padding-bottom: 0px;" width="242" height="36" border="0" alt="Genboree">
                </a>
                   </div>
                <div class="rightClose" >
                <a align="right" href="#"  onClick="window.close();">Close Window
                </a></div>
                 </nobr>
            </td>
            <td width=30></td>
            <td class="shadow"></td>
        </tr>
     <%@ include file="include/validateFid.incl" %>
            <tr>
    <td></td>
    <td >
<table cellpadding="20" cellspacing="20" border="0" width="100%">
<tr><td>
    <font class="topicTitle">
    <CENTER>Annotation Manipulation Tools</CENTER>
    </font>
    <P>&nbsp;<P><BR>
<%
  if( !trackBlocked )
  {
%>
    <div class="toolGroupTitle">
    Manipulating A Specific Annotation
    </div>These tools let you modify and manipulate just the annotation
    itself.
    <BR>&nbsp;<BR>

<table cellpadding="20" cellspacing="1" border="0" width="100%">
<!-- BEGIN: Annotation specific tools -->
<tr><td style="margin-left:20">
<DIV class="toolName">
<a class="invisiLink" href="<%=hrefReassignAnno%>"><span class="genbLabel2">Assign</span></a>
</DIV>

<DIV class="toolDesc">
<UL class="compact4">
<LI>- Assign this annotation to a different track.</LI>
<LI>- OR assign a <I>copy</I> to a different track.</LI>
</UL></DIV></td></tr>

<tr><td><DIV class="toolName">
<a class="invisiLink" href="<%=hrefCrate%>"><span class="genbLabel2">Create</span></a>
</DIV>
<DIV class="toolDesc">
<UL class="compact4">
<LI>- Create a new annotation based on this annotation.</LI>
</UL></DIV></td></tr>

<tr><td><DIV class="toolName">
<a class="invisiLink" href="<%=hrefDelAnno%>"><span class="genbLabel2">Delete</span></a>
</DIV>
<DIV class="toolDesc">
<UL class="compact4">
<LI>- Remove this annotation from the database.</LI>
</UL></DIV></td></tr>
<tr>
<td>
<DIV class="toolName">
<a class="invisiLink" href="<%=hrefDupAnno%>"><span class="genbLabel2">Duplicate</span></a>
</DIV>

<DIV class="toolDesc">
<UL class="compact4">
<LI>- Make a duplicate of this annotation.</LI>
<LI>- And optionally, modify the details of the duplicate.</LI>
</UL>
</DIV>
</td>
</tr>
<tr>
<td>
<DIV class="toolName">
<a class="invisiLink" href="<%=href1%>"><span class="genbLabel2">Edit</span></a>
</DIV>

<DIV class="toolDesc">
<UL class="compact4">
<LI>- Modify the data for this annotation.</LI>
</UL>
</DIV>

</td>
</tr>
<tr>
<td>

<DIV class="toolName">
<a class="invisiLink" href="<%=hrefShiftAnno%>"><span class="genbLabel2">Shift</span></a>
</DIV>
<DIV class="toolDesc">
<UL class="compact4">
<LI>- Move the annotation to the 5' or 3'.</LI>
</UL>
</DIV>
</td>
</tr>

<!-- END: Annotation specific tools -->

<tr>
<td>  <P>&nbsp;<P><BR>
<div class="toolGroupTitle">
Manipulating An Annotation Group
</div>
</td>
</tr>

<%   if (totalNumAnno < Constants.GB_MAX_ANNO_FOR_DISPLAY ){ %>
<tr>
<td>
These tools let you modify and manipulate the annotation group, affecting
<I>multiple</I> annotations at once.
<BR>&nbsp;<BR>

<!-- BEGIN: Group specific tools -->
 </td>
</tr>

<tr>
<td>
<DIV class="toolName">
<a class="invisiLink" href="<%=hrefReassignGrp%>"><span class="genbLabel2">Group Assign</span></a>
</DIV>
<DIV class="toolDesc">
<UL class="compact4">
<LI>- Assign annotations to a different track.</LI>
<LI>- <I>OR</I> assign <I>copies</I> to a different track.</LI>
</UL>
</DIV>
</td>
</tr>

<tr>
<td>
<DIV class="toolName">
<a class="invisiLink" href="<%=hrefDelGrp%>"><span class="genbLabel2">Group Delete</span></a>
</DIV>
<DIV class="toolDesc">
<UL class="compact4">
<LI>- Remove annotations from this group.</LI>
</UL>
</DIV>
</td>
</tr>


<tr>
<td>
<DIV class="toolName">
<a  class="invisiLink" href="<%=hrefDupGrp%>"><span class="genbLabel2">Group Duplicate</span></a>
</DIV>
<DIV class="toolDesc">
<UL class="compact4">
<LI>- Copy annotations in this group to a new group.</LI>
<LI>- And optionally, modify the details of the copies.</LI>
</UL>
</DIV>
</td>
</tr>


<tr>
<td>
<DIV class="toolName">
<a class="invisiLink" href="<%=href2%>"><span class="genbLabel2">Group Edit</span></a>
</DIV>
<DIV class="toolDesc">
<UL class="compact4">
<LI>- Edit all  annotations within the group at once.</LI>
</UL>
</DIV>
</td>
</tr>

<tr>
<td>
<DIV class="toolName">
<a class="invisiLink" href="<%=hrefRenameGrp%>"><span class="genbLabel2">Group Rename</span></a>
</DIV>
<DIV class="toolDesc">
<UL class="compact4">
<LI>- Rename annotations from this group.</LI>
<LI>- This puts the annotations in a different group.</LI>
</UL>
</DIV>
</td>
</tr>

<tr>
<td>
<DIV class="toolName">
<a class="invisiLink" href="<%=hrefShiftGrp%>" ><span class="genbLabel2">Group Shift</span></a>
</DIV>
<DIV class="toolDesc">
<UL class="compact4">
<LI>- Shift annotations in this group to the 5' or 3'.</LI>
</UL>
</DIV>
</td>
</tr>

<tr>
<td>
<DIV class="toolName">
<a class="invisiLink" href="<%=hrefAddComment%>"><span class="genbLabel2">Add Comments</span></a>
</DIV>

<DIV class="toolDesc">
<UL class="compact4">
<LI>- Append a comment to annotations in the group.</LI>
</UL>
</DIV>
</td>
</tr>


<tr>
<td>
<DIV class="toolName">
<a class="invisiLink" href="<%=hrefAddAVP%>"><span class="genbLabel2">Add Attributes</span></a>
</DIV>

<DIV class="toolDesc">
<UL class="compact4">
<LI>- Append attribute:value pairs to annotations in the group.</LI>
</UL>
</DIV>
</td>
</tr>

<tr>
<td>
<DIV class="toolName">
<a class="invisiLink" href="<%=hrefGrpColor%>"><span class="genbLabel2">Group Color</span></a>
</DIV>
<DIV class="toolDesc">
<UL class="compact4">
<LI>- Change annotation display color in the group.</LI>
</UL>
</DIV>
</td>
</tr>

<tr>
<td>
<P>&nbsp;<P>
<B>NOTE:</B> If the group has too many annotations, you may only be allowed to modify <I>all</I>
the annotations or none, rather than selected group members. Or the tool may not yet
available for large groups.
<P>
<!-- END: Group specific tools -->
<%}else {%>
<div class="warningMsg">
<P>&nbsp;<P>
<font color="red"><B>Warning:</B> &nbsp; &nbsp;
This group has <%=totalNumAnno%> annotations, which is not currently supported for online editing. &nbsp; &nbsp;
Sorry!
</font>
<P>
</div>
<%
    }
%>
    </td>
    </tr>
    </table>
<%
  }
  else
  {
%>
    <div style="text-align: center; color: red; font-size: 100%; font-weight: bold; font-style: italic; width: 100%;">
      To protect sensitive data (e.g. patient data, pre-publication raw data, etc), annotation editing and downloads for this track have been blocked.
    </div>
<%
  }
%>

</td>
</tr>
</table>
</td>
<td width=10></td>
<td class="shadow"></td>
</tr>
<tr>
<td colspan="3" height="10"></td>
<td class="shadow" width="10"></td>
</tr>
<%@ include file="include/invalidFidMsg.incl"%>
<tr><td width=10></td>
<td>
<table width="452" border="0" cellpadding="8">
<tr>
<td class="note">
&copy; 2003 <A HREF="http://brl.bcm.tmc.edu">Bioinformatics Research Laboratory</A>
</td>

<td class="highlight" align="center" valign="middle">
<a href='mailto:<%=GenboreeConfig.getConfigParam("gbAdminEmail")%>'>Questions or comments?</a>
</td>
</tr>
</table>
</td>
<td width=10></td>
<td width=10 class="shadow"></td>
</tr>

<tr>
<td width=10 class="bkgd"></td>
<td height=10 class="shadow"></td>
<td width=10 class="shadow"></td>
<td width=10 class="shadow"></td>
</tr>
</table>
</BODY>
</HTML>
