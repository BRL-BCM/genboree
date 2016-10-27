<%@ page import="javax.servlet.http.*, java.util.*, java.sql.*, org.genboree.dbaccess.*, org.genboree.dbaccess.util.*, org.genboree.util.*, org.genboree.upload.*" %>
<%@ include file="include/common.incl" %>
<%@ include file="include/fwdurl.incl" %>
<%
  String[] userInfo = new String[3] ;
  response.addDateHeader("Expires", 0L) ;
  response.addHeader("Cache-Control", "no-cache, no-store") ;

  String adrFrom = "\"Genboree Team\"<" +  GenboreeConfig.getConfigParam("gbFromAddress") + ">" ;
  // Get new registration BCC email list (if any)
  String newRegBccStr = GenboreeConfig.getConfigParam("gbNewRegBccAddress") ;
  if(newRegBccStr != null)
  {
    newRegBccStr = newRegBccStr.trim() ;
  }
  String[] newRegBccAddresses = null ;
  if(newRegBccStr != null)
  {
    newRegBccAddresses = newRegBccStr.split("\\s*,\\s*") ;
  }
  else
  {
    newRegBccAddresses = new String[0] ;
  }

  // First, determine if we have the 'accounts' feature turned on or not
  Connection conn = db.getConnection() ;
  String useAccountsStr = GenboreeConfig.getConfigParam("useAccounts") ;
  boolean useAccounts = false ;
  if(useAccountsStr != null && useAccountsStr.length() > 0)
  {
    if(useAccountsStr.toLowerCase().equals("true"))
    {
      useAccounts = true ;
    }
  }

	int i ;
	Newuser nu = null ;
	String regno = request.getParameter("regno") ;
	String err = null ;
	boolean is_wrong = false ;
	boolean is_right = false ;
  boolean continueProcessing = true ;
  int accountId = -1 ;

	String user_name = request.getParameter("user_name") ;
	if(user_name == null)
  {
    user_name = "" ;
  }
	else
  {
    user_name = user_name.trim() ;
  }
	String passw1 = request.getParameter("passw1") ;
	if( passw1 == null )
  {
    passw1 = "" ;
  }
	String passw2 = request.getParameter("passw2") ;
	if( passw2 == null )
  {
    passw2 = "" ;
  }

  // If we have a registration number, fetch the newuser record for it
	if( regno != null )
	{
		nu = new Newuser() ;
		if( !nu.fetch(db, regno) )
		{
			nu = null;
			is_wrong = true;
			err = "Wrong Registration ID. Please repeat registration.";
		}
	}

  // Now that have newuser record, use the account code from it to check the account info again
  // if accounts feature is turned on
  if(useAccounts)
  {
    // If we're processing the verified registration or something,
    // get the account code from the newuser record if present
    String accountCode = nu.getAccountCode() ;
    // Retreive account record using this code
    DbResourceSet accountRecordDbResSet = AccountsTable.getRecordByCode(accountCode, conn) ;
    boolean accountCodeOk = false ;
    HashMap accountInfo = new HashMap() ;
    if(accountRecordDbResSet != null && accountRecordDbResSet.resultSet != null)
    {
      accountRecordDbResSet.db = db ;
      while(accountRecordDbResSet.resultSet.next())
      {
        accountInfo.put("id", accountRecordDbResSet.resultSet.getInt("id")) ;
        accountInfo.put("name", accountRecordDbResSet.resultSet.getString("name")) ;
        accountInfo.put("code", accountRecordDbResSet.resultSet.getString("code")) ;
        accountInfo.put("primaryContactName", accountRecordDbResSet.resultSet.getString("primaryContactName")) ;
        accountInfo.put("primaryContactEmail", accountRecordDbResSet.resultSet.getString("primaryContactEmail")) ;
        accountCodeOk = true ;
        break ;
      }
      accountRecordDbResSet.close() ;
    }
    // Did we get an account using this code?
    if(!accountCodeOk)
    {
      String gbAdminEmail = GenboreeConfig.getConfigParam("gbAdminEmail") ;
      err = "Registration error: the account code entered does not correspond to a existing Genboree account. " +
            "This will cause problems when trying to use Genboree. Please contact an administrator (" + gbAdminEmail + ")." ;
      continueProcessing = false ;
    }
    else // got valid account code
    {
      // check if num users for account not exceeded
      try
      {
        accountId = ((Integer)accountInfo.get("id")).intValue() ;
        accountCodeOk = !AccountsTable.isMaxNumUsersExceeded(accountId, conn) ;
        if(!accountCodeOk)
        {
          err = "The account has reached the maximum number of allowed users. Can no longer register a new user on this account." ;
          continueProcessing = false ;
        }
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: regfinal.jsp => probably exception converting userId value to an integer. (accountId: " + accountId + ")") ;
        ex.printStackTrace(System.err) ;
        continueProcessing = false ;
      }
    }
  }

	GenboreeUser usr = null ;

	boolean is_email_change = false ;
  // Weird change-your-email case?
	if( nu != null && nu.getLastName().equals("-- email change --") )
	{
		usr = new GenboreeUser() ;
		usr.setUserId( nu.getFirstName() ) ;
		if(usr.fetch(db))
    {
      if(usr.getName().equals(nu.getName()))
      {
        is_email_change = true ;
      }
    }
		if(JSPErrorHandler.checkErrors(request,response, db,mys))
    {
      return ;
    }
	}

	if(request.getParameter("cmdCancel") != null && nu != null && continueProcessing)
	{
		nu.delete( db ) ;
		nu = null ;
	}

	if( nu == null && !is_wrong )
	{
		GenboreeUtils.sendRedirect(request,response,  is_email_change ? "/java-bin/mygenboree.jsp" : "/java-bin/regform.jsp" ) ;
		return ;
	}

	boolean ok_to_submit = (request.getParameter("cmdSubmit") != null && !is_wrong) ;

	if(ok_to_submit && !is_email_change && continueProcessing)
	{
		if(!user_name.equals(nu.getName()))
		{
			err = "Wrong User Name specified." ;
		}
		else if( !passw1.equals(passw2) )
		{
			err = "Password mismatch." ;
		}
		else if( passw1.length() < 6 )
		{
			err = "Password must be at least 6 chars long.";
		}
		else
		{
      continueProcessing = true ;
			// Create user
			usr = new GenboreeUser() ;
			usr.setName( nu.getName() ) ;
			usr.setPassword( passw1 ) ;
			usr.setEmail( nu.getEmail() ) ;
			usr.setFirstName( nu.getFirstName() ) ;
			usr.setLastName( nu.getLastName() ) ;
			usr.setInstitution( nu.getInstitution() ) ;
			usr.setPhone( nu.getPhone() ) ;
			usr.insert( db ) ;
			if(JSPErrorHandler.checkErrors(request,response, db,mys))
      {
        return ;
      }

      // Associate user with account:
      if(useAccounts)
      {
        int userId = -1 ;
        try
        {
          // Get the GenboreeUser id number & do association
          userId = Integer.parseInt(usr.getUserId()) ;
          int numUpdated = User2AccountTable.associateUserWithAccount(userId, accountId, conn) ;
          if(numUpdated != 1)
          {
            System.err.println("ERROR: regfinal.jsp => userId not properly associated with 1 accountId when registering this user." +
                               "(userId: " + userId + ", accountId: " + accountId + ", numUpdated: " + numUpdated + ")") ;
          }
        }
        catch(Exception ex)
        {
          System.err.println("ERROR: regfinal.jsp => exception converting userId value to an integer. (user_id: " + usr.getUserId() + ", accountId: " + accountId + ")") ;
          ex.printStackTrace(System.err) ;
        }
      }

      if(continueProcessing) // Then no problems accumulated so far, continue with registration...
      {
        // Delete registration record
        nu.delete( db );
        if(JSPErrorHandler.checkErrors(request,response, db,mys))
        {
          return ;
        }

        // Create group
        GenboreeGroup grp = new GenboreeGroup() ;
        grp.setGroupName( usr.getName()+"_group" ) ;
        grp.setDescription( "" ) ;
        grp.setStudent( 2 ) ;
        grp.insert( db ) ;
        if(JSPErrorHandler.checkErrors(request,response, db,mys))
        {
          return ;
        }

        // Set group owner
        String qs = "INSERT INTO usergroup (groupId, userId, userGroupAccess) " +
                    "VALUES (" + grp.getGroupId() + ", " + usr.getUserId() + ", 'o')" ;
        db.executeUpdate(null, qs) ;

        // Add to public group
        grp.clear() ;
        grp.setGroupName("Public") ;
        if(grp.fetchByName(db))
        {
          qs =  "INSERT INTO usergroup (groupId, userId, userGroupAccess) " +
                "VALUES (" + grp.getGroupId() + ", " + usr.getUserId() + ", 'r')" ;
          db.executeUpdate(null, qs) ;
        }

        // Send notifincation email to Admins and Such
        String fullName = nu.getFirstName() + " " + nu.getLastName() ;
        SendMail m = new SendMail() ;
        m.setHost( Util.smtpHost );
        m.setFrom( adrFrom );
        m.setReplyTo( adrFrom );
        // Add BCC addresses
        for(int ii=0; ii < newRegBccAddresses.length; ii++)
        {
          String bccEmail = newRegBccAddresses[ii].trim() ;
          m.addBcc(bccEmail) ;
        }
        m.setSubj("GENBOREE NOTICE: New User Registration" ) ;
        m.setBody("\nThis is an administration notice. The following user has completed the Genboree registration process:\n\n" +
                  "  NAME:  " + fullName + "\n" +
                  "  LOGIN: " + nu.getName() + "\n" +
                  "  EMAIL: " + nu.getEmail() + "\n\n") ;
        // Did sending email work?
        if( !m.go() )
        {
          String[] emailErrors = m.getErrors() ;
          System.err.println("----------------------------------------------\nSENDING EMAIL - ERRORS ENCOUNTERED using host " + Util.smtpHost + ":\n--------------------------------------------") ;
          for(int ii=0; ii<emailErrors.length; ii++)
          {
            System.err.println("   " + ii + ". " + emailErrors[ii]) ;
          }
          System.err.println("") ;
        }

        // Regardless of admin email, complete registration
        if(JSPErrorHandler.checkErrors(request, response, db, mys))
        {
          return ;
        }
        is_right = true ;
      }
		}
	}

	if(ok_to_submit && is_email_change)
	{
		if(usr.getName().equals(user_name) && usr.getPassword().equals(passw1))
		{
			usr.setEmail( nu.getEmail() ) ;
			usr.update( db ) ;
			nu.delete( db ) ;
			if( JSPErrorHandler.checkErrors(request,response, db,mys) )
      {
        return ;
      }

			mys.invalidate() ;
			mys = request.getSession( true ) ;
			mys.setAttribute( "username", usr.getName() ) ;
			mys.setAttribute( "pass", usr.getPassword() ) ;
			mys.setAttribute( "userid", usr.getUserId() ) ;
			mys.setAttribute( "myself", usr ) ;
			GenboreeUtils.sendRedirect(request,response, "/java-bin/mygenboree.jsp" ) ;
			return ;
		}
		else
    {
      err = "Invalid Login Name and/or Password." ;
    }
	}

%>

<HTML>
<head>
<title>Genboree - New User Registration - Final Step</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY>

<%@ include file="include/header.incl" %>

<% if( is_wrong ) { %>
<p>&nbsp;</p>
<p><strong>You have entered the link which is no longer active.</strong></p>
<p>If you attempted to register with Genboree more than a week ago, your
previous registration has been expired. Please <a href="regform.jsp">click here</a>
to repeat the registration</p>
<p>If you have already completed your registration (i.e. selected a password),
<a href="login.jsp">click here</a> to login to Genboree.</p>
<p>If you have forgotten your password, <a href="forgotten.jsp">click here</a>.</p>
<p>&nbsp;</p>
<% } else if( is_right ) { %>
<p>&nbsp;</p>
<p>Congratulations, <strong><%=usr.getFullName()%></strong>!</p>
<p>You have successfully registered with Genboree.</p>
<p><a href="login.jsp">Click here</a> to login and go to the Genboree Workbench.</p>
<p>&nbsp;</p>
<% } else { %>

<% if( err != null ) { %>
<p><strong><font color="red">Error:</font> <%=Util.htmlQuote(err)%></strong></p>
<% } %>
<br>

<% if( !is_email_change ) { %>

<br>Please enter your Genboree Login Name (which you have previously selected)
and enter your desired password, then press "Submit" to complete your registration.

<% } else { // if( !is_email_change ) %>

<br>In order to confirm your new email address, please login to Genboree.
<i>(If you have changed your mind, you can keep your previous email address by clicking
"Cancel" now.)</i>

<% } // else if( !is_email_change ) %>

<form name="reg" id="reg" action="regfinal.jsp" method="post">
  <input type="hidden" name="regno" id="regno" value="<%=regno%>">
  <table border="0" cellpadding="4" cellspacing="2">
  <tbody>

  <tr>
	<td class="form_body">
	<strong>&nbsp;Login&nbsp;Name&nbsp;</strong>
	</td>
	<td class="form_body">
	<input type="text" name="user_name" id="user_name" size="40"
	maxlength="40" value="<%=Util.htmlQuote(user_name)%>">
	</td>
  </tr>

  <tr>
	<td class="form_body">
	<strong>&nbsp;Password&nbsp;</strong>
	</td>
	<td class="form_body">
	<input type="password" name="passw1" id="passw1" size="40"
	maxlength="40" value="">
	</td>
  </tr>

<% if( !is_email_change ) { %>
  <tr>
	<td class="form_body">
	<strong>&nbsp;Confirm&nbsp;Password&nbsp;</strong>
	</td>
	<td class="form_body">
	<input type="password" name="passw2" id="passw2" size="40"
	maxlength="40" value="">
	</td>
  </tr>

  <tr>
  <td colspan="2">Password is case-sensitive and must contain at least 6 characters.
  </td>
  </tr>
<% } // if( !is_email_change ) %>

  <tr>
  <td colspan="2">
    <input name="cmdSubmit" type="submit" class="btn" value='Submit'>
    <input name="cmdCancel" type="submit" class="btn" value='Cancel'>
  </td>
  </tr>

  </tbody>
  </table>
</form>

<% } %>

<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
