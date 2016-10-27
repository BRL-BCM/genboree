<%@ include file="include/notify.incl" %>
<HTML>
<head>
<title>Genboree - Send Notification Message to a Group</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY>

<%@ include file="include/header.incl" %>

<form name="notify" id="notify" action="notify.jsp" method="post">
<table width="100%" border="0" cellpadding="2" cellspacing="2" align="center">
<tbody>
<% if( !void_page && grps != null) { %>
<tr>
  <td class="form_header" nowrap>Send Message to Group: &nbsp;</td>
  <td class="form_body">
	<select name="groupId" id="groupId" class="txt" style="width:320">
<%
    boolean submitEmail = false;
	for( i=0; i<grps.length; i++ )
	{
        if(grps[i].getGroupName().equalsIgnoreCase("Public")) continue;
        submitEmail = true;
		String myId = grps[i].getGroupId();
		String sel = myId.equals(groupId) ? " selected" : "";
%><option value="<%=myId%>"<%=sel%>><%=Util.htmlQuote(grps[i].getGroupName())%></option>
<%
    }
%>
	</select>
  </td>
</tr>

<tr>
  <td class="form_header" valign="top" nowrap>Signature:</td>
  <td class="form_body"><strong><%=Util.htmlQuote(addrFrom)%></strong></td>
</tr>
<% if( stdInfo != null ) { %>
<tr>
  <td class="form_header" valign="top" nowrap>Standard Information: &nbsp;</td>
  <td class="form_body">
	<textarea rows="5" cols="60" name="msg_stdinfo" class="txt"
	  id="msg_stdinfo"><%=Util.htmlQuote(stdInfo)%></textarea>
  </td>
</tr>
<% } %>
<% if( msgUrl != null ) { %>
<tr>
  <td class="form_header" valign="top" nowrap>URL:</td>
  <td class="form_body">
	<input type="text" size="60" name="msg_url" id="msg_url" class="txt"
	  value="<%=Util.htmlQuote(msgUrl)%>">
  </td>
</tr>
<% } %>
<tr>
  <td class="form_header" valign="top" nowrap>Message: &nbsp;</td>
  <td class="form_body">
	<textarea rows="15" cols="60" name="msg_body"
	  id="msg_body" class="txt"><%=Util.htmlQuote(msgBody)%></textarea>
  </td>
</tr>

<tr>
  <td class="form_body">&nbsp;</td>
  <td class="form_body">
  <% if(submitEmail)
  { %>
	<input type="submit" name="btnSend" id="btnSend"
	  class="btn" value="  Send  ">
      <% }%>        

	<input type="button" name="btnClose" id="btnClose" value="  Cancel  "
	  class="btn" onClick="window.close();">
  </td>
</tr>
<% } else { %>

<tr><td align="center">
<%=statMsg%>
</td></tr>
<tr><td align="center">
	<input type="button" name="btnClose" id="btnClose" value="  Close  "
	  class="btn" onClick="window.close();">
</td></tr>

<% } %>
</tbody>
</table>
</form>

<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
