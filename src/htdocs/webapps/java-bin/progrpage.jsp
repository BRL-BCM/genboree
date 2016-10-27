<%@ page import="javax.servlet.http.*, java.net.*, java.util.Date" %>
<%@ include file="include/fwdurl.incl" %>
<%
   HttpSession mys = request.getSession();
   String fn = request.getParameter( "f" );
   String idStr = request.getParameter( "id" ) ;
   if(idStr == null)
   {
    idStr = "" ;
   }
   if( fn!=null && fn.trim().length()==0 ) fn = null;
   if( fn != null ) fn = "Uploading <b><font color='#AA0000'>"+fn+"</font></b>;<br>";
   else fn = "Upload in progress. ";
   String ct = ""+(new Date()).getTime();
   String linkToProgressBar = GenboreeUtils.returnFullURL(request, "/java-bin/servlets/ProgressServlet?n=");
%>
<HTML>
<HEAD>
  <!-- BEGIN: Extjs: Split Button Support -->
  <script type="text/javascript" src="/javaScripts/extjs/adapter/prototype/prototype.js<%=jsVersion%>"></script> <!-- Stuff here used in rest of files... -->
  <script type="text/javascript" src="/javaScripts/extjs/adapter/prototype/scriptaculous.js<%=jsVersion%>"></script> <!-- Stuff here used in rest of files... -->
  <script type="text/javascript" src="/javaScripts/extjs/adapter/prototype/ext-prototype-adapter.js<%=jsVersion%>"></script> <!-- Stuff here used in rest of files... -->
  <script type="text/javascript" src="/javaScripts/extjs/package/genboree/ext-menuBtn-only-pkg.js<%=jsVersion%>"></script>
  <!-- Set a local "blank" image file; default is a URL to extjs.com -->
  <script type='text/javascript'>
    Ext.BLANK_IMAGE_URL = '/javaScripts/extjs/resources/images/genboree/s.gif';
  </script>
  <!-- END -->

<SCRIPT language=javascript>
/* */
var linkToProgressBar = "<%=linkToProgressBar%>";
var periodicExecuter ;

function initUpdate_<%=idStr%>()
{
  periodicExecuter = new PeriodicalExecuter(updatePicture_<%=idStr%>, 10) ;
}

function updatePicture_<%=idStr%>()
{
  var idStr = <%= idStr %> ;
  var cur_time = new Date();
  var img = Ext.get("progrImg_<%=idStr%>") ;
  if(img)
  {
    Element.extend(img) ;
    img.remove();
  }
  var imgDiv = Ext.get('progImgDiv') ;
  imgDiv.update( "<img id='progrImg_<%=idStr%>' name='progrImg_<%=idStr%>' src='" +
                (linkToProgressBar + cur_time.getTime() + "&id=" + idStr) +
                "' width='400' height='40' border='visibility: hidden ;'>" ) ;
  return ;
}
/* */
</SCRIPT>
<title>Genboree</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY onLoad="initUpdate_<%=idStr%>();" onFocus="initUpdate_<%=idStr%>();">

<table cellpadding=0 cellspacing=0 border=0 bgcolor=white width=700 class='TOP'>
<tbody>
  <tr><td width=10></td>
  <td height=10></td>
  <td width=10 class="bkgd"></td></tr>

  <tr><td></td><td align='center'>
  <div id='progImgDiv' name='progImgDiv'>
    <IMG id="progrImg_<%=idStr%>" name="progrImg_<%=idStr%>" SRC="<%=GenboreeUtils.returnFullURL(request, "/java-bin/servlets/ProgressServlet?x=" + ct + "&id=" + idStr )%>" WIDTH="400" HEIGHT="40" border="visibility: hidden ;">
  </div>

	<br><%=fn%>Please wait...

	<p>&nbsp;</p>
	<p>&nbsp;</p>
	<p>&nbsp;</p>
	<p>&nbsp;</p>
	<p>&nbsp;</p>
	<p>&nbsp;</p>
  </td><td class="shadow"></td></tr>
</tbody>
</table>


</BODY>
</HTML>
