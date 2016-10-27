<%@ page import="java.util.*,
	javax.servlet.http.*, org.genboree.dbaccess.*,
	org.genboree.util.*, org.genboree.upload.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%
	if( request.getParameter("btnGetBack") != null )
	{
		String destback = (String) mys.getAttribute( "destback" );
		if( destback == null ) destback = "/java-bin/workbench.jsp";
		GenboreeUtils.sendRedirect(request,response,  destback );
		return;
	}

	int i;

	String[] trackNames = (String []) mys.getAttribute( "featuretypes" );
	Hashtable trackLookup = null;
	if( trackNames!=null && trackNames.length>0 )
	{
		trackLookup = new Hashtable();
		for( i=0; i<trackNames.length; i++ )
			trackLookup.put( trackNames[i], "y" );
	}
	
	boolean isDelete = request.getParameter("btnDelete") != null;
	boolean isCreate = false;
	boolean isModify = false;
	boolean isApply = request.getParameter("btnApply") != null;
	String deflnk = request.getParameter( "deflnk" );
	String crValue = request.getParameter("btnCreate");
	if( crValue != null )
	{
		if( crValue.equals("Create") ) isCreate = true;
		else if( crValue.equals("Modify") ) isModify = true;
		isApply = true;
	}
	String editFeatureTypeId = request.getParameter( "featureTypeId" );
	if( editFeatureTypeId == null ) isApply = false;
	String editLinkId = request.getParameter( "defaultLinkId" );
	if( isApply && deflnk != null )
	{
		if( deflnk.equals("no") )
			editLinkId = null;
		else if( deflnk.equals("select") )
			isModify = true;
		else if( deflnk.equals("new") )
			isCreate = true;
	}
	
	if( isDelete )
	{
		isCreate = isModify = isApply = false;
		Link lnk = new Link();
		lnk.setLinkId( editLinkId );
		lnk.delete( db );
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
	}
	
	if( isCreate || isModify )
	{
		String cName = request.getParameter( "linkName" );
		String cDescr = request.getParameter( "linkDescr" );
		if( (cName==null && cDescr==null) || (isModify && editLinkId==null) )
		{
			isCreate = isModify = isApply = false;
		}
		else
		{
			Link lnk = new Link();
			lnk.setName( cName );
			lnk.setDescription( cDescr );
			if( isModify )
			{
				lnk.setLinkId( editLinkId );
				lnk.update( db );
			}
			else
			{
				if( lnk.insert(db) ) editLinkId = lnk.getLinkId();
				else isApply = false;
			}
			if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
		}
	}
	
	if( isApply )
	{
		FeatureType ft = new FeatureType();
		ft.setFeatureTypeId( editFeatureTypeId );
		Link lnk = new Link();
		lnk.setLinkId( editLinkId );
		ft.updateDefaultLink( db, lnk );
		if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
	}
	
	FeatureType[] ftypes = FeatureType.fetchAll( db );
   	if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
	if( ftypes == null ) ftypes = new FeatureType[0];
	
	if( editFeatureTypeId==null && ftypes.length>0 )
		editFeatureTypeId = ftypes[0].getFeatureTypeId();
	FeatureType curft = null;
	Link defln = null;
	if( editFeatureTypeId != null )
	{
		for( i=0; i<ftypes.length; i++ )
		if( ftypes[i].getFeatureTypeId().equals(editFeatureTypeId) )
		{
			curft = ftypes[i];
			defln = curft.getDefaultLink();
			break;
		}
	}
	editLinkId = (defln != null) ? defln.getLinkId() : null;
	
	Link[] avlLinks = Link.fetchAll( db );
	if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
	if( avlLinks == null ) avlLinks = new Link[0];
%>

<HTML>
<head>
<title>Genboree - Default Links</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY bgcolor="#DDE0FF">

<%@ include file="include/header.incl" %>

<%@ include file="include/navbar.incl" %>
<br>

	<form name="defaultLinkSetupForm" action="defaultLink.jsp" method="post"
	  onsubmit="return checkSubmit();">
    	      <table width="100%" align="center" border="0" cellpadding="2">
                <tbody>
                  <tr> 
                    <td width="43%" align="center" class="form_header"><strong>Feature Type</strong></td>
                    <td colspan="2" align="center" class="form_header"><strong>Default Link</strong></td>
                  </tr>
                  <tr> 
                    <td class="form_body"><select name="featureTypeId" 
					  onchange=document.defaultLinkSetupForm.submit();
					  size="11"  class="txt" style="width:260">
                        <%
	for( i=0; i<ftypes.length; i++ )
	{
		String myName = ftypes[i].getName();
		if( trackLookup!=null && trackLookup.get(myName)==null ) continue;
		String sel = "";
		if( editFeatureTypeId!=null &&
		    editFeatureTypeId.equals(ftypes[i].getFeatureTypeId()) )
		{
			sel = " selected";
		}
		String myId = ftypes[i].getFeatureTypeId();
%>
                        <option value="<%=myId%>"<%=sel%>><%=myName%></option>
                        <%
	}
	
	String ck1 = (defln==null) ? " checked" : "";
	String ck2 = (defln==null) ? "" : " checked";
%>
                      </select></td>
                    <td width="30%" class="form_body"> <input type="radio" name="deflnk"
						onclick="checkRadio()" value="no"<%=ck1%>>
                      No Default Link</input><br><br><input type="radio" name="deflnk"
					  	onclick="checkRadio()" value="select"<%=ck2%>>
                      Select From List</input><br><br><input type="radio" name="deflnk"
					  	onclick="checkRadio()" value="new">
                      Create New Link</input></td>
                    <td width="27%" align="center" valign="top" class="form_body">
                        <select name="defaultLinkId" size="8" onchange="onLinkSelChange()"
						   class="txt" style="width:160">
                          <%
	int defaultSelected = -1;
	for( i=0; i<avlLinks.length; i++ )
	{
		Link lnk = avlLinks[i];
		String myId = lnk.getLinkId();
		String myName = lnk.getName();
		String sel = "";
		if( editLinkId!=null && editLinkId.equals(myId) )
		{
			sel = " selected";
			defaultSelected = i;
		}
%>
                          <option value="<%=myId%>"<%=sel%>><%=myName%></option>
                          <%		
	}
%>
                        </select>
						<br><br>
                        <input type="submit" name="btnDelete" value="Delete" 
						  onclick="onBtnClick(this)" class="btn" style="width:100">
                      </td>
                  </tr>
                  <tr> 
                    <td colspan=3 align=center class="form_body"> <table class='TABLE' border="0" cellspacing="0" cellpadding="0">
                        <tr> 
                          <td>&nbsp;Link Name:&nbsp;</td>
                          <td>
						    <input name="linkName" onchange="checkBtnCreate()"
							  onfocus="onLinkNameFocus()"
				              type="text" style="width:400">
							<input name="btnCreate" type="submit" value="Create"
							  onclick="onBtnClick(this)"
							   class="btn" style="width:100">
						  </td>
                        </tr>
                        <tr> 
                          <td>&nbsp;Link Pattern:&nbsp;</td>
                          <td>
						    <input name="linkDescr" type="text"
						      onfocus="this.select()" style="width:500">
						  </td>
                        </tr>
                      </table></td>
                  </tr>
                </tbody>
              </table>

<br>
	<input type="submit" name="btnApply" value="Apply" onclick="onBtnClick(this)"
	   class="btn" style="width:100">&nbsp;&nbsp;<input
	       type="button" name="btnReset" value="Reset" onClick="doReset()"
	   class="btn" style="width:100">&nbsp;&nbsp;<input
		name="btnGetBack" type="submit" value="Back"  class="btn" style="width:100">
			  
    </form>

<script language=javascript>
var linkIds = new Array(<%=avlLinks.length%>);
var linkNames = new Array(<%=avlLinks.length%>);
var linkDescs = new Array(<%=avlLinks.length%>);
<%
	for( i=0; i<avlLinks.length; i++ )
	{
		Link lnk = avlLinks[i];
%>
	linkIds[<%=i%>] = "<%=lnk.getLinkId()%>";
	linkNames[<%=i%>] = "<%=Util.simpleJsQuote(lnk.getName())%>";
	linkDescs[<%=i%>] = "<%=Util.simpleJsQuote(lnk.getDescription())%>)";
<%		
	}
%>
var defaultSelected = <%=defaultSelected%>;
var cform = document.defaultLinkSetupForm;
var radios = cform.deflnk;
var lnklist = cform.defaultLinkId;
var btnCreate = cform.btnCreate;
var btnDelete = cform.btnDelete;
var tfLinkName = cform.linkName;
var tfLinkDescr = cform.linkDescr;
var cmd = "";
function onBtnClick( btn )
{
	cmd = btn.value;
}
function checkSubmit()
{
	if( ((cmd == "Apply") && radios[2].checked) || (cmd == "Create") )
	{
		if( tfLinkName.value == "-- New Link --" ) tfLinkName.value = "";
		if( tfLinkName.value == "" )
		{
			alert( "Please provide Link Name" );
			tfLinkName.focus();
			return false;
		}
	}
	return true;
}
function updateLinkSelection( selOn )
{
	var idx = -1;
	if( selOn )
	{
		idx = defaultSelected;
		if( idx < 0 && lnklist.options.length > 0 ) idx = 0;
	}
	lnklist.selectedIndex = idx;
	checkDelete();
	updateText();
}
function resetRadios( ir )
{
	var idx = lnklist.selectedIndex;
	if( idx >= 0 )
	{
		defaultSelected = idx;
		radios[0].checked = (ir == 0);
		radios[1].checked = (ir == 1);
		radios[2].checked = (ir == 2);
	}
}
function checkRadio()
{
	updateLinkSelection( radios[1].checked );
}
function checkDelete()
{
	btnDelete.disabled = (lnklist.selectedIndex < 0);
}
function updateText()
{
	var idx = lnklist.selectedIndex;
	if( idx >= 0 )
	{
		tfLinkName.value = linkNames[idx];
		tfLinkDescr.value = linkDescs[idx];
	}
	else
	{
		if( radios[2].checked ) tfLinkName.value = "-- New Link --";
		else tfLinkName.value = "";
	}
	checkBtnCreate();
}
function onLinkSelChange()
{
	resetRadios( 1 );
	checkDelete();
	updateText();
}
function onLinkNameFocus()
{
	if( tfLinkName.value == "-- New Link --" )
		tfLinkName.value = "";
	else
		tfLinkName.select();
}
function checkBtnCreate()
{
  var cName = tfLinkName.value;
  var i;
  var isModify = false;
  for( i=0; i<linkNames.length; i++ )
  {
    if( linkNames[i] == cName )
	{
		isModify = true;
		defaultSelected = i;
		lnklist.selectedIndex = i;
	}
  }
  var ir = 1;
  if( isModify )
  {
    btnCreate.disabled = false;
	btnCreate.value = "Modify";
  }
  else
  {
    btnCreate.value = "Create";
	if( cName == "" )
	{
		btnCreate.disabled = true;
		ir = 0;
	}
	else
	{
		btnCreate.disabled = false;
		ir = 2;
	}
  }
  radios[0].checked = (ir == 0);
  radios[1].checked = (ir == 1);
  radios[2].checked = (ir == 2);
}
function doReset()
{
	cform.reset();
	checkDelete();
	updateText();
	lnklist.focus();
}
checkDelete();
updateText();
lnklist.focus();
</script>

<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
