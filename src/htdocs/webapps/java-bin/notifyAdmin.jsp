<%@ include file="include/notifyAdmin.incl" %>

<%
  // First, if we're being told to redirect to a public view of the data by the user,
  // then do so. (this case should not come up if all users are members of the "Public" group)
  String yesToPublic = request.getParameter("yesToPublic") ;
  if(yesToPublic != null && yesToPublic.trim().equalsIgnoreCase("yes"))
  {
    String target = (String) mys.getAttribute("target") ;
    // Tack on isPublic=YES to target if it looks like it's not there.
    String extraParam = "" ;
    if(target != null && target.indexOf("isPublic") < 0)
    {
      extraParam = "isPublic=YES" ;
      if(target.indexOf("?") < 0) // then we need a ?
      {
        extraParam = "?" + extraParam ;
      }
      else // we have a ?
      {
        if(target.indexOf("&") > 0 || target.indexOf("=") > 0) // then looks like we have ? and a NVP param already
        {
          extraParam = "&" + extraParam ;
        }
      }
    }
    // Invalidate current session and redirect them directly to the public view
    GenboreeUtils.invalidateSession(mys, request, response, false) ;
    mys.removeAttribute("target") ;
    GenboreeUtils.sendRedirect(request, response, target + extraParam) ;
    return ;
  }
  
  String refSeqId_str = request.getParameter("msgRefSeqId") ;
  boolean haveRefSeqId = ( (refSeqId_str != null) && (refSeqId_str.length() > 0) ) ;
  // If no msgRefSeqId NVP, try to get it by genbDbId aliases
  if(!haveRefSeqId)
  {
    refSeqId_str = request.getParameter("genbDbId") ;
    haveRefSeqId = ( (refSeqId_str != null) && (refSeqId_str.length() > 0) ) ;
    if(!haveRefSeqId)
    {
      refSeqId_str = request.getParameter("refSeqId") ;
      haveRefSeqId = ( (refSeqId_str != null) && (refSeqId_str.length() > 0) ) ;
    }
  }
  boolean isPublished = false ;
  if(haveRefSeqId)
  {
  	isPublished = Refseq.isPublished(db, refSeqId) ;
  }
  
%>
<HTML>
<head>
  <title>Genboree - Send Message to Group Administrators</title>
  <meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
  <link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
  <script type="text/javascript" src="/javaScripts/prototype.js<%=jsVersion%>"></script>          <!-- Official extension to use css style classes for the title bar appearance -->
  <script type="text/javascript" src="/javaScripts/util.js<%=jsVersion%>"></script>               <!-- This should be on all pages, but often is not -->
  <script type="text/javascript" src="/javaScripts/commonFunctions.js<%=jsVersion%>"></script>    <!-- Official extension to use css style classes for the title bar appearance -->
   
  <script type="text/javascript">
    // Used in cases where user is prompted to see either Public or Private data
    // (should not be used if all users are in the Public group)
    function showPublic()
    {
      $('yesToPublic').value = 'yes' ;
      $('notify').submit() ;
    }
    
    function showRequestForm()
    {
      hideToggle('notifyMsgDiv2') ;
      hideToggle('requestForm') ;
      return ;
    }
  </script>
</head>
<BODY>

  <%@ include file="include/header.incl" %>
  
  <form name="notify" id="notify" action="notifyAdmin.jsp" method="get">
<%
    if(groupAllowed == null && refSeqId != null)
    {
%>
      <input type="hidden" name="msgRefSeqId"  value="<%=refSeqId%>">
<%
    }
    else if(groupAllowed != null)
    {
%>
      <input type="hidden" name="groupAllowed"  value="<%=groupAllowed%>">
<%
    }
    else
    {
%>
      <input type="hidden" name="operationNotPermitted"  value="true">
<%
    }
    if( !void_page )
    {
%>
      <p>
      <div id="notifyMsgDiv1" style="text-align: center; margin-left: auto; margin-right: auto; font-weight: bold; color: red">
        Sorry, you do not have permission to<br>access private data
<%
        if(groupAllowed == null && haveRefSeqId)
        {
%>
          within the database
          <b>'<%=Util.htmlQuote(rseq.getRefseqName())%>'</b> ID=<b><%=refSeqId%></b>.
<%
        }
        else if(groupAllowed != null)
        {
%>
          within the group <b>'<%=Util.htmlQuote(groupAllowed) %>'</b>.
<%
        }
%>
        </div>
        <p>
        <!-- If it's published, we'll see if they want to see that -->
        <div id="notifyMsgDiv2" style="padding: 10px; text-align: center; margin-left: auto; margin-right: auto; <%=isPublished ? "" : "display: none;" %> ">
          However, the database you are trying to access has been <b>published</b>.
          <p>
          Would you like to display the <u>public view</u> of the data, rather than a private one?
          <p>
          <input type="hidden" name="yesToPublic" id="yesToPublic" value="">
          <input type="button" name="btnYesToPublic" id="btnYesToPublic" class="btn" value="  Yes, Show Me a Public View  " onclick="showPublic();">
          <input type="button" name="btnNoToPublic" id="btnNoToPublic" class="btn" value="  No, I Need Private Access  " onclick="showRequestForm();">
        </div>
        
        <!-- Request access form -->
        <div id="requestForm" name="requestForm" style='<%= isPublished ? "display: none;" : "" %>' >
          <div id="notifyMsgDiv3" style="width: 70%; text-align: center; margin-left: auto; margin-right: auto;">
            If you want access to the private data within this group, then use this form to contact one of the administrators below and
            request access to their group.
          </div>
          <p>
          <table width="100%" border="0" cellpadding="2" cellspacing="2" align="center">
          <tr>
            <td colspan="2" style="height:8"></td>
          </tr>
          <tr>
            <td colspan="2">
              <table width="100%" border="0" cellspacing="2" cellpadding="2">
              <tr>
                <td class="form_header">Notify</td>
                <td class="form_header">Login Name</td>
                <td class="form_header">Full Name</td>
                <td class="form_header">Group</td>
              </tr>
<%
              String chk = " checked";
              for( i=0; i<gAdmins.length; i++ )
              {
                GenboreeUser usr = gAdmins[i];
                String userId = usr.getUserId();
                String groupName = (String)htug.get(usr.getName());
%>
                <tr>
                  <td class="form_body">
                    <input type="checkbox" name="userId" id="userId" value="<%=userId%>"<%=chk%>>
                  </td>
                  <td class="form_body"><%=Util.htmlQuote(usr.getName())%></td>
                  <td class="form_body"><%=Util.htmlQuote(usr.getFullName())%></td>
                  <td class="form_body"><%=Util.htmlQuote(groupName)%></td>
                </tr>
<%
                chk = "";
              }
%>
              </table>
            </td>
          </tr>  
          <tr>
            <td class="form_header" valign="top" nowrap>
              Signature:
            </td>
            <td class="form_body">
              <b><%=Util.htmlQuote(myself.getFullName())%> &lt;<%=Util.htmlQuote(myself.getEmail())%>&gt;</b>
            </td>
          </tr>
<%
          if( stdInfo != null )
          {
%>
            <tr>
              <td class="form_header" valign="top" nowrap>Standard Information: &nbsp;</td>
              <td class="form_body">
                <textarea rows="5" cols="60" name="msg_stdinfo" class="txt" id="msg_stdinfo"><%=Util.htmlQuote(stdInfo)%></textarea>
              </td>
            </tr>
<%
          }
          if( msgUrl != null )
          {
%>
            <tr>
              <td class="form_header" valign="top" nowrap>URL Attempted:</td>
              <td class="form_body">
                <input type="text" size="80" name="msg_url" id="msg_url" class="txt" value="<%=Util.htmlQuote(msgUrl)%>">
              </td>
            </tr>
<%
          }
%>
          <tr>
            <td class="form_header" valign="top" nowrap>Email Message: &nbsp;</td>
            <td class="form_body">
              <textarea rows="15" cols="80" name="msg_body" id="msg_body" class="txt">
                <%=Util.htmlQuote(msgBody)%>
              </textarea>
            </td>
          </tr>
          <tr>
            <td class="form_body">&nbsp;</td>
            <td class="form_body">
              <input type="submit" name="btnSend" id="btnSend" class="btn" value="  Send  ">
              <input type="submit" name="btnCancel" id="btnCancel1" value="  Cancel  " class="btn">
            </td>
          </tr>
<%
    }
    else
    {
%>
          <table width="100%" border="0" cellpadding="2" cellspacing="2" align="center">
          <tr>
            <td colspan="2" style="height:8"></td>
          </tr>
          <tr>
            <td align="center">
              <%=statMsg%>
            </td>
          </tr>
          <tr>
            <td align="center">
              <input type="submit" name="btnCancel" id="btnCancel2" value="<%=canBtnLab%>" class="btn" style="width:100">
            </td>
          </tr>
<%
    }
%>
          </table>
        </div>
  </form>

  <%@ include file="include/footer.incl" %>

</BODY>
</HTML>
