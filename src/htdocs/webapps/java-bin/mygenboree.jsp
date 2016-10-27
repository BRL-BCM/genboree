<%@ page import="javax.servlet.http.*,  java.util.*, org.genboree.dbaccess.*, org.genboree.dbaccess.util.*, org.genboree.util.*, org.genboree.upload.*, java.sql.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%
  response.addDateHeader( "Expires", 0L ) ;
  response.addHeader( "Cache-Control", "no-cache, no-store" ) ;
  boolean emailNamePresent = false ;
  boolean emailNameExists = false ;
  boolean fullNameExist = false ;
  boolean serialNameExist = false ;
  boolean loginExists = false ;
  boolean done = false ;
  String adrFrom = "\"Genboree Team\" <" + GenboreeConfig.getConfigParam("gbFromAddress") + ">" ;
  String myselfEmail = myself.getEmail() ;
  String emailName = null ;
  String first_name = "" ;
  String last_name ="" ;
  String serialName = "" ;
  String be = " names are " ;
  String editChoice = "0" ;
  String redir = "mygenboree.jsp" ;
  String selectedUserName = userInfo[0] ;

	int i ;
	if( request.getParameter("btnCancel") != null )
	{
		GenboreeUtils.sendRedirect(request,response, "/site/cg-calculator") ;
		return ;
	}
  else if(myself==null || grps == null)
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/mygenboree.jsp" ) ;
		return ;
	}

	Subscription curSub = Subscription.fetchSubscription(db, myselfEmail) ;
  Connection conn = db.getConnection() ;
	Vector errs = new Vector() ;
	boolean email_update = false ;
	String newEmail = null ;
	String alert = null ;
  String newUserName = request.getParameter("usr_user_name") ;
  String oldUserName =userInfo[0] ;

  if(newUserName != null)
  {
    newUserName = newUserName.trim() ;
  }

	if(request.getParameter("btnChangePass") != null)
	{
    newUserName = request.getParameter("pass_user_name") ;
    if( newUserName != null && oldUserName != null && newUserName.compareTo(oldUserName) != 0 )
    {
      loginExists = GenboreeuserTable.loginExists(newUserName, conn) ;
      if(loginExists)
      {
        errs.add(0, "User name \"" + newUserName + "\" is already in use and thus unavailable. ") ;
		    if(myselfEmail != null)
        {
          emailName = myselfEmail.substring(0, myselfEmail.indexOf("@")) ;
        }

        if(emailName != null)
        {
          emailName = emailName.trim() ;
        }
        emailNamePresent = GenboreeuserTable.loginExists(emailName, conn) ;
      }
      first_name = myself.getFirstName() ;
      last_name = myself.getLastName() ;
      String fullNameStr = first_name + "_" + last_name ;
      fullNameExist = GenboreeuserTable.loginExists(fullNameStr, conn) ;
      if(fullNameExist && emailNamePresent)
      {
        be= "name is " ;
      }
      else // emailName is null
      {
        emailName = fullNameStr ;
        errs.add(0, "Please enter firstName, lastName, and email address. ") ;
      }

      // We've tried very hard to get some kind of email name; if still a problem, let's try adding some version numbers to the names
      if(emailName != null)
      {
        int n= 1 ;
        for(n=1 ; n<1000 ; n++)
        {
          String serialNameTmp = emailName + "_" + n ;
          serialNameExist = GenboreeuserTable.loginExists(serialNameTmp, conn) ;
          if(!serialNameExist) // then found one that doesn't exist
          {
            serialName = serialNameTmp ;
            break ;
          }
        }
      }

      selectedUserName = serialName ;

      if(request.getParameter("pass_new_name") != null)
      {
        selectedUserName = request.getParameter("usr_new_name") ;
      }
    }

    String old_pass = request.getParameter( "old_pass" ) ;
    String new_pass1 = request.getParameter( "new_pass1" ) ;
    String new_pass2 = request.getParameter( "new_pass2" ) ;
    if(old_pass != null && new_pass1 != null && new_pass2 != null )
    {
      if(!old_pass.equals(myself.getPassword()))
      {
        errs.addElement( "Incorrect current password." ) ;
      }
      if(!new_pass1.equals(new_pass2))
      {
        errs.addElement( "Password mismatch." ) ;
      }
      if(new_pass1.length()<6)
      {
        errs.addElement( "Password must be at least 6 characters long." ) ;
      }

      // is everything ok?
      if(errs.size() == 0)
      {
        selectedUserName = request.getParameter("pass_user_name") ;
        if(selectedUserName != null)
        {
          myself.setName(selectedUserName) ;
        }
        myself.setPassword(new_pass1) ;
        mys.setAttribute("pass", new_pass1) ;

        if(myself.update(db))
        {
          done = true ;
          alert = "Your password has been changed. Next, either close this browser window OR  navigate to the <a href=\"http://calculator.clinicalgenome.org\" style=\"font-size:20px\">Pathogenicity Calculator</a> or to the <a href=\"http://reg.clinicalgenome.org\" style=\"font-size:20px\">Allele Registry</a>" ;
        }
      }
    }
  }

  if(request.getParameter("btnUpdateProfile") != null)
  {
    newUserName = request.getParameter("usr_user_name") ;
    first_name = request.getParameter("usr_first_name") ;
    first_name = (first_name == null ? "" : first_name.trim()) ;
    last_name = request.getParameter("usr_last_name") ;
    last_name = (last_name == null ? "" : last_name.trim()) ;
    String institution = request.getParameter("usr_institution") ;
    institution = (institution == null ? "" : institution.trim()) ;
    String telephone = request.getParameter("usr_phone") ;
    telephone = (telephone == null ? "" : telephone.trim()) ;
    String email = request.getParameter("usr_email") ;
    if(email != null)
    {
      emailName = myselfEmail.substring(0, myselfEmail.indexOf ("@")) ;
      emailName = emailName.trim() ;
    }
    else
    {
      email = "" ;
    }

    // validations
    if(first_name.length() < 1)
    {
      errs.addElement( "First Name must not be empty." ) ;
    }
    if(last_name.length() < 1)
    {
      errs.addElement( "Last Name must not be empty." ) ;
    }
    if(myselfEmail.length() < 3)
    {
      errs.addElement( "Invalid email address." ) ;
    }

    // looks ok so far
    if( newUserName != null && oldUserName != null && newUserName.compareTo(oldUserName) != 0 )
    {
      // check if user name is used
      boolean userNameExist = GenboreeuserTable.loginExists(newUserName, conn) ;
      if(userNameExist)
      {
        errs.add(0, "User name \"" + newUserName + "\" is unavailable. ") ;
        emailNamePresent = GenboreeuserTable.loginExists(emailName, conn) ;
      }
    }

    String firstAndLast = first_name + "_" + last_name ;
    fullNameExist = GenboreeuserTable.loginExists(firstAndLast, conn) ;

    // We've tried very hard to get some kind of email name; if still a problem, let's try adding some version numbers to the names
    if(emailName != null)
    {
      int n= 1 ;
      for(n=1 ; n<1000 ; n++)
      {
        String serialNameTmp = emailName + "_" + n ;
        serialNameExist = GenboreeuserTable.loginExists(serialNameTmp, conn) ;
        if(!serialNameExist) // then found one that doesn't exist
        {
          serialName = serialNameTmp ;
          break ;
        }
      }
    }

    if(fullNameExist && emailNameExists)
    {
      be = "name is " ;
    }

    selectedUserName = serialName ;
    if(request.getParameter("usr_new_name")!= null)
    {
      selectedUserName = request.getParameter("usr_new_name") ;
    }

    // If no errors proceed
    if( errs.size() == 0 )
    {
      if(!(loginExists && emailNameExists))
      {
        if(newUserName==null)
        {
          newUserName = "" ;
        }
        selectedUserName = newUserName ;
        myself.setName( newUserName ) ;
        myself.setFirstName( first_name ) ;
        myself.setLastName( last_name ) ;
        myself.setInstitution( institution ) ;
        myself.setPhone( telephone ) ;
        myself.update( db ) ;
        done = true ;

        String wnews = request.getParameter("wantnews") ;
        if( wnews==null && curSub!=null )
        {
          curSub.delete( db ) ;
        }
        if( wnews!=null && curSub==null )
        {
          curSub = new Subscription() ;
          curSub.setEmail( email ) ;
          curSub.setNews( 1 ) ;
          if(!curSub.insert(db))
          {
            curSub = null ;
          }
        }

        if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return ;

        // Has email changed? If so update it
        if(!myself.getEmail().equals(email))
        {
          Newuser.checkExpired(db) ;
          if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return ;

          Vector gn = Newuser.fetchUserNames(db) ;
          if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return ;

          done = true ;
          Newuser nu = new Newuser() ;
          nu.setName(myself.getName()) ;
          nu.setEmail(email) ;
          nu.setFirstName(myself.getUserId()) ;
          nu.setLastName( "-- email change --" ) ;
          nu.setInstitution(null) ;
          nu.setPhone(null) ;
          nu.insert(db) ;
          if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return ;
          fullName = myself.getFullName() ;
          SendMail m = new SendMail() ;
          m.setHost(Util.smtpHost) ;
          m.setFrom(adrFrom) ;
          m.setReplyTo(adrFrom) ;
          newEmail = "\"" + fullName + "\" <" + nu.getEmail() + ">" ;
          m.addTo(newEmail) ;
          m.setSubj("Genboree - Email address change notice") ;
          m.setBody(
            "Dear " + fullName + ",\n\n" +
            "To confirm change of your email address, " +
            "please go to the following page:\n\n" +
            GenboreeUtils.returnRedirectString(request.getHeader("host"), "/java-bin/regfinal.jsp")	+
            "?regno="+nu.getRegno() + "\n\n" +
            "You will then be prompted to login to Genboree, and this will " +
            "confirm your new email address.\n" +
            "Please note that the above link will remain active one week from now.\n" +
            "(If you fail to confirm your new email within a week, your old email " +
            "address will be kept unchanged.)\n\n" +
            "Thank you for using Genboree,\n" +
            "Genboree Team\n"
          ) ;

          if(!m.go())
          {
            errs.addElement("Invalid email address.") ;
            nu.delete(db) ;
            if(curSub != null)
            {
              curSub.setEmail(myself.getEmail()) ;
              curSub.update(db) ;
            }
          }
          else
          {
            email_update = true ;
          }
        }
      }
    }
  }


%>

<HTML>
<head>
<title>Genboree - User Profile</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<link rel="stylesheet" href="/styles/annotationEditor.css<%=jsVersion%>" type="text/css">
  <SCRIPT TYPE="text/javascript" SRC="/javaScripts/prototype.js<%=jsVersion%>"></SCRIPT>
  <SCRIPT TYPE="text/javascript" SRC="/javaScripts/mygenboree.js<%=jsVersion%>"></SCRIPT>
  <meta HTTP-EQUIV='Content-Type' CONTENT='text/html ; charset=iso-8859-1'>
</head>
<BODY>
<%@include file="include/header.incl" %>
<!-- <%@include file="include/profile.incl" %> -->
<%
    String editingChoice = "0" ;
    if(editProfile)
    {
      mys.setAttribute("editingChoice", "1") ;
      editingChoice = "1" ;
      redir = "mygenboree.jsp?eP=yes" ;
    }
    else if(changePassword)
    {
      editingChoice = "2" ;
      redir="mygenboree.jsp?cP=yes" ;
      mys.setAttribute("editingChoice", "2") ;
    }
    else
    {
      mys.setAttribute("editingChoice", "0") ;
    }

    if(mys.getAttribute("editingChoice")!= null)
    {
      editingChoice = (String)mys.getAttribute("editingChoice") ;
    }

    if(done || request.getParameter("cancelProfile")!= null || request.getParameter("cancelPassword")!= null)
    {
      redir = "mygenboree.jsp" ;
      editProfile = false ;
      changePassword = false ;
      mys.setAttribute("editingChoice", "0") ;
    }

    if(alert != null) // Should be a GenboreeMessage
    {
%>
      <br>
        <strong><font color=red>ALERT: </font><%=alert%></strong><br>
<%
    }

    if(email_update )
    {
%>
      <p><%=Util.htmlQuote(myself.getFullName())%>,</p>
      <p>In order to ensure the validity of your new email address, an email message
      has been sent to the new address (<strong><%=Util.htmlQuote(newEmail)%></strong>.)</p>
      <p>To complete your email change request, after receiving that message you must follow
      the link it contains, then login to Genboree.</p>

      <form name="gen" id="gen" action="mygenboree.jsp" method="post">
        <input type="submit" name="cmdBack" id="cmdBack" class="btn" value="&nbsp;OK&nbsp;">
      </form>
<%
    }
    else
    { // No email update
%>
      <form name="gen" id="gen" action="<%=redir%>" method="post"  onSubmit=" return validGenboree(this) ;">
<%
      if( errs.size() > 0 )
      {
%>
        <br>
        <font color=red><strong>
        Your request cannot be processed due to the following reason(s):
        </strong></font>
        <ul>
<%
        for(i=0 ; i<errs.size() ; i++)
        {
          String s = (String) errs.elementAt(i) ;
          out.println( "<li>"+Util.htmlQuote(s)+"</li>" ) ;
        }
%>
        </ul>
<%
        if(loginExists)
        {
%>
          <span style="margin:30px ;"><b> The following user <%=be%> available: </b> </span><BR>
          <input type="radio" name="usr_new_name" id="usr_new_name"  value="<%=serialName%>" class="userRadio"  checked onClick="setUserName('<%=serialName%>') ;">  <%=serialName%>  <BR>
<%
          if(emailName != null && !emailNameExists)
          {
%>
            <input type="radio" name="usr_new_name" id="usr_new_name" value="<%=emailName%>"  onClick="setUserName('<%=emailName%>') ;" class="userRadio"> <%=emailName%>   <BR>
<%
          }

          if(!fullNameExist)
          {
%>
            <input type="radio" name="usr_new_name" id="usr_new_name" value="<%=first_name%>_<%=last_name%>"  onClick="setUserName('<%=first_name%>_<%=last_name%>') ;"  class="userRadio"> <%=first_name%><%=last_name%>   <BR>
<%        }   %>
          <br>
<%      }   %>
        Please correct the problem and try again.
<%
      }

      if(!changePassword)
      {
%>
        <!--
        <table border="0" cellpadding="4" cellspacing="2" width="100%">
        <tr>
          <td class="form_header" colspan="2">Your Profile</td>
        </tr>
        <tr>
          <td class=""><strong>User Name</strong></td>
          <td class="">
<%
            if(editProfile)
            {
%>
              <input type="text" name="usr_user_name" id="usr_user_name" class="txt" size="64" maxlength="255" value="<%=selectedUserName %>" >
<%
            }
            else
            {
%>
              <table width="75%" border="0" cellspacing="0" cellpadding="0">
              <tr>
                <td>
                  <input  type="text" class="largeInputRO2" size="64" maxlength="255" READONLY value="<%=selectedUserName%>" >
                </td>
              </tr>
              </table>
<%          }   %>
          </td>
        </tr>
        <tr>
          <td class=""><strong>First Name</strong></td>
          <td class="">
<%
            if( editProfile )
            {
%>
              <input type="text" name="usr_first_name" id="usr_first_name" class="txt" size="64" maxlength="255" value="<%=Util.htmlQuote(myself.getFirstName())%>">
<%
            }
            else
            {
%>
              <table width="75%" border="0" cellspacing="0" cellpadding="0">
              <tr>
                <td>
                  <input  type="text" READONLY class="largeInputRO2" size="64" maxlength="255" value="<%=Util.htmlQuote(myself.getFirstName())%>">
                </td>
              </tr>
              </table>
<%          }   %>
          </td>
        </tr>
        <tr>
          <td class=""><strong>Last Name</strong></td>
          <td class="">
<%
            if(editProfile )
            {
%>
              <input type="text" name="usr_last_name" id="usr_last_name" class="txt" size="64" maxlength="255" value="<%=Util.htmlQuote(myself.getLastName())%>">
<%
            }
            else
            {
%>
              <table width="75%" border="0" cellspacing="0" cellpadding="0">
              <tr>
                <td>
                  <input  type="text" class="largeInputRO2" READONLY size="64" maxlength="255" value="<%=Util.htmlQuote(myself.getLastName())%>" >
                </td>
              </tr>
              </table>
<%          }   %>
          </td>
        </tr>
        <tr>
          <td class=""><strong>Institution</strong></td>
          <td class="">
<%
            if(editProfile)
            {
%>
              <input type="text" name="usr_institution" id="usr_institution" class="txt" size="64" maxlength="255" value="<%=Util.htmlQuote(myself.getInstitution())%>">
<%          }
            else
            {
%>
              <table width="75%" border="0" cellspacing="0" cellpadding="0">
              <tr>
                <td>
                  <input type="text" name="usr_institution" id="usr_institution" READONLY size="64" maxlength="255" class="largeInputRO2" size="64" maxlength="255" value="<%=Util.htmlQuote(myself.getInstitution())%>">
                </td>
              </tr>
              </table>
<%          }   %>
          </td>
        </tr>
        <tr>
          <td class=""><strong>Telephone</strong></td>
          <td class="">
<%
            if(editProfile)
            {
%>
              <input type="text" name="usr_phone" id="usr_phone" class="txt" size="64" maxlength="255" value="<%=Util.htmlQuote(myself.getPhone())%>">
<%
            }
            else
            {
%>
              <table width="75%" border="0" cellspacing="0" cellpadding="0">
              <tr>
                <td>
                  <input  type="text" class="largeInputRO2"  size="64" maxlength="255" value="<%=Util.htmlQuote(myself.getPhone())%>" READONLY>
                </td>
              </tr>
              </table>
<%          }   %>
          </td>
        </tr>
        <tr>
          <td class=""><strong>Email</strong></td>
          <td class="">
<%
            if(editProfile)
            {
%>
              <input type="text" name="usr_email" id="usr_email" class="txt" size="64" maxlength="255" value="<%=Util.htmlQuote(myself.getEmail())%>">
<%
            }
            else
            {
%>
              <table width="75%" border="0" cellspacing="0" cellpadding="0">
              <tr>
                <td>
                  <input type="text" class="largeInputRO2" READONLY size="64" maxlength="255"  value="<%=Util.htmlQuote(myself.getEmail())%>" >
                </td>
              </tr>
              </table>
<%          }   %>
          </td>
        </tr>
<%
        if(editProfile )
        {
%>
          <tr>
            <td class="form_body" colspan="2">
              <input type="checkbox" name="wantnews" id="wantnews" value="y"<%= curSub!=null ? " checked" : "" %>>
              I want to receive occasional emails about Genboree updates and have access
              to software download.
            </td>
          </tr>
          <tr>
            <td colspan="2">
              <input type="submit" name="btnUpdateProfile" id="btnUpdateProfile" class="btn" value="Edit Profile">
              <input type="submit" name="cancelProfile" id="cancelProfile" class="btn" value="Cancel">
            </td>
          </tr>
<%      }   %>
        </table>
       -->
<%    }   %>
<%
      if(changePassword)
      {
%>
        <div class="row">
        <div class="col-sm-4">
        </div>
        <div class="col-sm-4">
        <h2>Change your password:</h2>
        <table border="0" cellpadding="4" cellspacing="2" width="100%">
        <tr>
          <td class=""><strong>User Name</strong></td>
          <td class="">
            <input type="text" name="pass_user_name" id="pass_user_name" class="txt form-control" size="40" maxlength="40"  value="<%=selectedUserName%>">
          </td>
        </tr>
        <tr>
          <td class=""><strong>1. Type in your old password</strong></td>
          <td class="">
            <input type="password" name="old_pass" id="old_pass" class="txt form-control" size="40" maxlength="40" value="">
          </td>
        </tr>
        <tr>
          <td class=""><strong>2. Type in your new password</strong></td>
          <td class="">
            <input type="password" name="new_pass1" id="new_pass1" class="txt form-control" size="40" maxlength="40" value="">
          </td>
        </tr>
        <tr>
          <td class=""><strong>3. Type in your new password again</strong></td>
          <td class="">
            <input type="password" name="new_pass2" id="new_pass2" class="txt form-control" size="40" maxlength="40" value="">
          </td>
        </tr>
        <tr>
          <td colspan="2">
            <input type="submit" name="btnChangePass" id="btnChangePass" class="btn btn-success" value="Change Password" style="margin-top:20px;margin-bottom:20px">
            <!--
            <input type="submit" name="cancelPassword" id="cancelPassword" class="btn" value="Cancel">
            -->
          </td>
        </tr>
        <tr>
          <td colspan="2">
            Note that your Genboree password is case-sensitive and
            must contain at least 6 characters.
            <br>
            If you do not want to change your password now, either close this browser window OR navigate to the <a href="http://calculator.clinicalgenome.org">Pathogenicity Calculator</a> or to the <a href="http://reg.clinicalgenome.org">Allele Registry</a>.
          </td>
        </tr>
        </table>
        </div>
<%    }   %>
<%
      if(!editProfile && !changePassword && !email_update)
      {
%>
         <!--
         <input id="btnCancel" name="btnCancel" type="submit" class="btn"value="&nbsp;Cancel&nbsp;" >
         -->
<%    }   %>
      </form>
<%  }   %>


<form name="cancelForm" id="cancelForm" action="mygenboree.jsp" method="post">
  <input id="btnCancel" name="btnCancel" type="hidden" value='cancel'>
</form>
<%@ include file="include/footer.incl" %>
</BODY>
</HTML>
