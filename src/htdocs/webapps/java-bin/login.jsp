
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
  <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css" integrity="sha384-BVYiiSIFeK1dGmJRAkycuHAHRg32OmUcww7on3RYdg4Va+PmSTsz/K68vbdEjh4u" crossorigin="anonymous">
  <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap-theme.min.css" integrity="sha384-rHyoN1iRsVXV4nD0JutlnGaslCJuC7uwjduW9SVrLvRYooPp2bWYgmgJQIXwl/Sp" crossorigin="anonymous">
  <script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/js/bootstrap.min.js" integrity="sha384-Tc5IQib027qvyjSMfHjOMaLkfuWVxZxUPnCJA7l2mCWNIpG9mGCD8wGNIcPD7Txa" crossorigin="anonymous"></script>

  <meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<body bgcolor="#DDE0FF">
  <div class="container">
  <div class="row" style="margin-top:20px">
  <div class="col-sm-4">
  </div>
  <div class="col-sm-4" style="background:rgba(58, 158, 224, 0.16) none repeat scroll 0% 0%;border-radius:10px">
  <!-- Standard Genboree Header -->
  <%@ include file="include/header.incl" %>
<%
  if(logged_in) // Then display the navbar
  {
%>
    < %@ include file="include/navbar.incl" %> 
<%
  }
  else // Not logged in yet, just draw a gif-line
  {
%>
    <!-- center><img src="/images/shade_1px.gif" width="500" height="1"></center -->
<%
  }
%>
    <table cellpadding="0" cellspacing="2" border="0" width="100%">
    <tr>
      <td>
        <!-- Content Body -->
<%
        // Have we got an accessDenied situation?
        // If so, display a message and the login prompt ONLY.
        //System.err.println("DEBUG -> accessDenied: " + accessDenied) ;
        if(accessDenied)
        {
          // Decide which text/html to use to allow some degree of custom login prompt.
          // - Default:
          String promptMsgMain = "<br>The ClinGen Pathogenicity Calculator page you are trying to access requires you to be logged in." ;
          String promptMsgNotes =
            "<ul class=\"compact4\" style=\"margin-top: 10px; margin-bottom: 10px; margin-right: auto;\" >" + 
            "</ul>" ;
          // - Target-page specific text/html, if applicable:
          if(tgt != null || tgtParam != null)
          {
            // Extract just the file name itself from the possibly complex target URL string:
            String tgtFileName = ( (tgt != null) ? FilenameUtils.getName(tgt) : FilenameUtils.getName(tgtParam) ) ;
            System.err.println("tgtFilename: '" + tgtFileName) ;
            // Check for each target-page for which we have specific login message text/html
            if(tgtFileName.equals("workbench.jsp") || tgtFileName.equals("clingenV2.5.jsp"))
            {
              promptMsgMain = "<br>Login required for accessing pathogenicity calculator" ;
              promptMsgNotes =
                "<ul class=\"compact4\" style=\"margin-top: 10px; margin-bottom: 10px; margin-right: auto;\" >" +
                  "<li>Please provide a valid login and password</li>" +
                "</ul>" ;
            }
          }
%>
          <!-- Access Error Message -->
          <div id="loginAndProject" class="col-sm-12">
            <%
              if(!isPublicDb)
              {
            %>
                <div id="accessMsg" name="accessMsg" style="width: 100%; margin-left: auto; margin-right: auto; ">
                  <!-- center --> 
                    <P class="text-danger">
                    <%= promptMsgMain %>
                  <!-- /center -->
                </div>
            <%
              }
            %>
            <div id="loginPrompt" class="text-muted" >
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

          <!-- Downtime warning? -->
          <div id="downtime" style="width: 100% ; text-align: center ; ">
            <%@ include file="include/downtimeWarning.html" %>
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

  </div>
  <div class="col-sm-4">
  </div>
  <!-- Standard Footer -->
  <%@ include file="include/footer.incl" %>
  </div>
  </div>

</body>
</html>
