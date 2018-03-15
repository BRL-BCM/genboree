
<%
// The following flag is used in login.incl to decide whether the "Public" user
// can see the page if the user is currently logged in as "Public". This must
// therefore come BEFORE "include/login.incl".
// For Genboree's main *index.jsp* this is true, while for login.jsp it is false
// (because we are trying to prompt them for login most times).
boolean allowPublicAccess = false ;
%>
<%@ include file="include/login.incl" %>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
  <title>Genboree - Login</title>

  <%@ include file="include/linkTags.incl" %>

  <link rel="stylesheet" href="/styles/news.css<%=jsVersion%>" type="text/css">
  <link rel="stylesheet" href="/styles/help.css<%=jsVersion%>" type="text/css">
  <meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<body bgcolor="#DDE0FF">
  <!-- Standard Genboree Header -->
  <%@ include file="include/header.incl" %>
<%
  if(logged_in)
  {
%>
    <script type="text/javascript">window.location = "/java-bin/workbench.jsp" ;</script>
    <%@ include file="include/navbar.incl" %>
<%
  }
  else // Not logged in yet, just draw a gif-line
  {
%>
    <center><img src="/images/shade_1px.gif" width="500" height="1"></center>
<%
  }
%>
    <table cellpadding="0" cellspacing="2" border="0" width="100%">
    <tr>
      <td>
        <!-- Content Body -->

        <!-- Downtime warning? -->
        <div id="downtime" style="width: 100% ; text-align: center ; ">
          <%@ include file="include/downtimeWarning.html" %>
        </div>
<%
        // Have we got an accessDenied situation?
        // If so, display a message and the login prompt ONLY.
        if(accessDenied || err_login)
        {
          // Decide which text/html to use to allow some degree of custom login prompt.
          // - Default:
          String promptMsgMain = "The Genboree page you are trying to access requires you to be logged in." ;
          String promptMsgNotes =
            "<ul class=\"compact4\" style=\"margin-top: 10px; margin-bottom: 10px; margin-right: auto;\" >" +
              "<li>- If you have access permission, you will be redirected to the page after login.</li>" +
              "<li>- Otherwise, there will be an opportunity to ask the group administrators for access to their group.</li>" +
            "</ul>" ;
          // - Target-page specific text/html, if applicable:
          if(tgt != null || tgtParam != null)
          {
            // Extract just the file name itself from the possibly complex target URL string:
            String tgtFileName = ( (tgt != null) ? FilenameUtils.getName(tgt) : FilenameUtils.getName(tgtParam) ) ;
            // Check for each target-page for which we have specific login message text/html
            if(tgtFileName.equals("workbench.jsp"))
            {
              promptMsgMain = "Login required to access the Genboree Workbench" ;
              promptMsgNotes =
                "<ul class=\"compact4\" style=\"margin-top: 10px; margin-bottom: 10px; margin-right: auto;\" >" +
                  "<li>- If you forgot your password or wish to create a new Genboree account, you can utilize the links included in the login box (below).</li>" +
                  "<li>- If you have additional questions, please email us at <a href=\"mailto:genboree_admin@genboree.org\">genboree_admin@genboree.org</a></li>" +
                "</ul>" ;
            }
          }
%>
          <!-- Access Error Message -->
          <div id="loginAndProject" style="text-align: center; margin-left: auto; margin-right: auto; width: 72% ; vertical-align: top; ">
            <%
              if(!isPublicDb)
              {
            %>
                <div id="accessMsg" name="accessMsg" style="width: 100%; margin-left: auto; margin-right: auto; ">
                  <center>
                    <P style="color: red; font-weight: bold;">
                    <%= promptMsgMain %>
                  </center>
                </div>
            <%
              }
            %>
            <div id="loginPrompt" style="text-align: left; font-size: 92%; margin-left: auto; margin-right: auto; width: 72%; ">
              <%= promptMsgNotes %>
            </div>

            <!-- Login Area -->
            <div id="loginArea" style="margin-left: auto; margin-right: auto; padding-bottom: 0px; width: 80%;">
              <form name="logpub" id="logpub" action="login.jsp" method='post'>
                <input type='hidden' name='rm' value='view'>
              </form>
<%
              if(!logged_in)
              {
%>
                <%@ include file="include/loginPrompt.incl" %>
<%
              } // if( !logged_in )
%>

            </div>
          </div>
<%
        }
        else // no accessDenied situation, display login.jsp content as usual
        {
%>
          <!-- Logged In Message Line -->
          <div id="loggedMsg" style="width: 100% ; text-align: center ; margin-bottom: 10px ;">
<%
            if(logged_in) // User is logged in, display welcome
            {
              mys.removeAttribute("accessDenied") ;
%>
              Welcome, <B><%= myself.getFullName() %></B>.<br>
              <small>(If you are not <%= myself.getFullName() %>,
              click <a href="login.jsp?rm=logout">here</a>).</small>
<%
            }
            else // Not logged in, display message
            {
%>
              <B>You are currently not logged in.</B>
<%
            }
%>
          </div>

          <!-- Genboree Updates, Left -->
          <div id="genboreeNews" class="news" style="float: left ; margin-top:24px; width: 40% ; vertical-align: top ; border-right: 1px solid gray; padding-right: 10px;">
            <%@ include file="include/genboreeNews.incl" %>
          </div>

          <!-- Vertical Spacer Bar
          <div id="vertSpacer" style="float: left ; margin-left: 5px ; margin-right: 5px ; padding-top: 25px ; padding-bottom: 15px ; width: 3% ; vertical-align: middle ; text-align: center ; width: 16px ;">
            <img src="/images/shade_1px.gif" height="300" width="1">
          </div
          -->
          <!-- Login Box + Project List, Right -->
          <div id="loginAndProject" style="float: right ; width: 56% ; vertical-align: top;">
            <!-- Login Error Message -->
<%          if(err_login)
            {
%>
              <div id="loginError" style="color: red ; padding-bottom: 0px ;">
                <b>Error Message:<br>There was an error with either your Username or Password.
                We were unable to log you on successfully. Please try again.</b>
              </div>
<%
            }
            else if(accessDenied)
            {
%>
              <div id="accessDeniedDiv" style="color: red ; font-weight: bold ;">
                <b>ACCESS REJECTED, you need to login to see that resource</b>
              </div>
<%
            }
%>
            <!-- Login Area -->
            <div id="loginArea" style="padding-bottom: 0px ; width: 100% ;">
              <form name="logpub" id="logpub" action="login.jsp" method='post'>
                <input type='hidden' name='rm' value='view'>
              </form>
              <br>
<%            if(!logged_in)
              {
%>
                <%@ include file="include/loginPrompt.incl" %>
                <p>&nbsp;
                <hr>
<%
              } // if( !logged_in )
%>
            </div>
            <%
              if(logged_in)
              {
            %>
              <!-- Project List -->
              <div id="projPages" style="padding-bottom: 20px ; width: 100% ;">
                <%@ include file="include/projectPageLinksLoggedIn.incl" %>
              </div>
            <%
              }
              else
              {
            %>
              <div id="projPages" style="padding-bottom: 20px ; width: 100% ;">
                <%@ include file="include/projectPageLinksNotloggedIn.incl" %>
              </div>
            <%
              }
            %>
          </div>
<%
        }
%>
      </td>
    </tr>
    </table>

  <!-- Standard Footer -->
  <%@ include file="include/footer.incl" %>

</body>
</html>
