
<%
// The following flag is used in login.incl to decide whether the "Public" user
// can see the page if the user is currently logged in as "Public". This must
// therefore come BEFORE "include/login.incl".
// For Genboree's main *index.jsp* this is true, while for login.jsp it is false
// (because we are trying to prompt them for login most times).
boolean allowPublicAccess = true ;
%>
<%@ include file="include/login.incl" %>
<%
  // =========================================================================
  // index.jsp
  // =========================================================================
  // This is very similar to login.jsp in what it displays. With these
  // differences:
  //
  // 1. Requires you be logged in (as Public can be ok) or you get redirected to login.jsp
  // 2. Doesn't show the login prompt
%>

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
  <title>Genboree - Login</title>

<%@ include file="include/linkTags.incl" %>

  <link rel="stylesheet" href="/styles/news.css<%=jsVersion%>" type="text/css">
  <meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<body bgcolor="#DDE0FF">
  <!-- Standard Header -->
  <%@ include file="include/header.incl" %>
<%
    if(logged_in) // Then display the page. Note that for Genboree's main *index.jsp* the Public user is allowed.
    {
      mys.removeAttribute("accessDenied") ;
%>
      <%@ include file="include/navbar.incl" %>

      <br>
      <table cellpadding="0" cellspacing="2" border="0" width="100%">
      <tr>
        <td>
          <!-- Content Body -->
          <!-- Logged In Message Line -->
          <div id="loggedMsg" style="width: 100% ; text-align: center ; margin-bottom: 10px ;">
<%
            if(!uName.equals("Public"))
            {
%>
              Welcome, <B><%= myself.getFullName() %></B>.<br>
              <small>(If you are not <%= myself.getFullName() %>,
              click <a href="login.jsp?rm=logout">here</a>).</small>
<%
            }
%>
          </div>

          <!-- Downtime warning? -->
          <div id="downtime" style="width: 100% ; text-align: center ; ">
            <%@ include file="include/downtimeWarning.html" %>
          </div>

          <!-- Genboree Updates, Left -->
          <div id="genboreeNews" class="news" style="float: left ; width: 40% ; vertical-align: top ;">
            <%@ include file="include/genboreeNews.incl" %>
          </div>

          <!-- Vertical Spacer Bar -->
          <div id="vertSpacer" style="float: left ; margin-left: 5px ; margin-right: 5px ; padding-top: 25px ; padding-bottom: 15px ; width: 3% ; vertical-align: middle ; text-align: center ; width: 16px ;">
            <img src="/images/shade_1px.gif" height="300" width="1">
          </div

          <!-- Login Box + Project List, Right -->
          <div id="loginAndProject" style="float: right ; width: 56% ; veritcal-align: top; ">
            <!-- Project List -->
            <div id="projPages" style="padding-bottom: 20px ; width: 100% ;">
              <%@ include file="include/projectPageLinksLoggedIn.incl" %>
            </div>
          </div>
        </td>
      </tr>
      </table>

      <!-- Standard Footer -->
      <%@ include file="include/footer.incl" %>
</body>
</html>

<%
    }
    else // Not logged in yet
    {
      System.err.println("index.jsp => not logged_in." +
                         "             - target is " + tgt) ;
      mys = GenboreeUtils.invalidateSession(mys, request, response, true) ;
      // Redirect to login.jsp. Save current url (this page) in the session target.
      GenboreeUtils.sendRedirectSaveTarget(mys, request, response,  "/java-bin/login.jsp" ) ;
      return ;
    }
%>
