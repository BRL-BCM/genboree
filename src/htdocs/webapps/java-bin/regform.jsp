<%@ page import="javax.servlet.http.*, java.util.*, java.sql.*, org.genboree.dbaccess.*, org.genboree.dbaccess.util.*, org.genboree.util.*, org.genboree.upload.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/common.incl" %>



<%
  String[] userInfo = new String[3] ;
  String adrFrom = "\"Genboree Team\"<" +  GenboreeConfig.getConfigParam("gbFromAddress") + ">" ;
  // Get new registration BCC email list (if any)
  String bccStr = GenboreeConfig.getConfigParam("gbBccAddress") ;
  if(bccStr != null)
  {
    bccStr = bccStr.trim() ;
  }
  String[] bccAddresses = null ;
  if(bccStr != null)
  {
    bccAddresses = bccStr.split("\\s*,\\s*") ;
  }
  else
  {
    bccAddresses = new String[0] ;
  }

  if( request.getParameter("cmdBack") != null )
  {
    GenboreeUtils.sendRedirect(request,response,  "/java-bin/workbench.jsp" ) ;
    return ;
  }

  int i ;

  Newuser.checkExpired( db ) ;
  if( JSPErrorHandler.checkErrors(request,response, db,mys) )
  {
    return ;
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

  // If we're processing the submitted registration form or something, get the account code from the form if present
  String accountCode = request.getParameter("accountCode") ;
  if(accountCode == null)
  {
    accountCode = "" ;
  }
  else
  {
    accountCode = accountCode.trim() ;
  }

  String user_name = request.getParameter("user_name");
  if( user_name == null ) user_name = "";
  else user_name = user_name.trim();

  String user_email = request.getParameter("user_email");
  if( user_email == null ) user_email = "";
  else user_email = user_email.trim();

  String first_name = request.getParameter("first_name");
  if( first_name == null ) first_name = "";
  else first_name = first_name.trim();

  String last_name = request.getParameter("last_name");
  if( last_name == null ) last_name = "";
  else last_name = last_name.trim();

  String institution = request.getParameter("institution");
  if( institution == null ) institution = "";

  String telephone = request.getParameter("telephone");
  if( telephone == null ) telephone = "";

  boolean nam_ok = true;
  boolean eml_ok = true;
  boolean fst_ok = true;
  boolean lst_ok = true;

  boolean reg1_ok = false;

  Vector errs = new Vector();

  Newuser nu = null;
  String fullName = null;

  HashMap accountInfo = new HashMap() ;
  boolean accountCodeOk = false ;
  int accountId = -1 ;
  // Are we processing a submitted form (have cmdReg) or do we need to display a form?
  if( request.getParameter("cmdReg") != null )
  {
    // If accounts feature is turned on, check the account code is valid and such
    accountCodeOk = true ;
    if(useAccounts)
    {
      // Retreive account record using this code
      DbResourceSet accountRecordDbResSet = AccountsTable.getRecordByCode(accountCode, conn) ;
      accountCodeOk = false ;
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
        errs.addElement("The account code entered does not correspond to a existing Genboree account.") ;
      }
      else // got valid account code
      {
        // check if num users for account not exceeded
        accountId = (Integer)accountInfo.get("id") ;
        accountCodeOk = !AccountsTable.isMaxNumUsersExceeded(accountId, conn) ;
        if(!accountCodeOk)
        {
          errs.addElement("The account has the maximum number of allowed users. Cannot register a new user on this account.") ;
        }
      }
    }

    if( user_name.length() < 5 )
    {
      errs.addElement( "User Name must be at least 5 characters long." );
      nam_ok = false;
    }
    else
    {
      for( i=0; i<user_name.length(); i++ )
      {
        char c = user_name.charAt( i );
        if( Character.isJavaIdentifierPart(c) ) continue;
        errs.addElement( "User Name must contain only letters, digits, and underscores." );
        nam_ok = false;
      }
    }

    if( user_email.length() < 3 )
    {
      errs.addElement( "Invalid email address." );
      eml_ok = false;
    }
    if( first_name.length() < 1 )
    {
      errs.addElement( "First Name must be specified." );
      fst_ok = false;
    }
    if( last_name.length() < 1 )
    {
      errs.addElement( "Last Name must be specified." );
      lst_ok = false;
    }

    if( errs.size() == 0 )
    {
      Vector gn = Newuser.fetchUserNames( db );
      if( gn.contains(user_name.toLowerCase()) )
      {
        errs.addElement( "That Login Name already exists (try a different one)." );
        nam_ok = false;
      }
    }

    // If no errors in validation/checking phase, add new user.
    if( errs.size() == 0 )
    {
      nu = new Newuser();
      nu.setName( user_name );
      nu.setEmail( user_email );
      nu.setFirstName( first_name );
      nu.setLastName( last_name );
      nu.setInstitution( institution );
      nu.setPhone( telephone );
      // If using Genboree accounts feature, record the account code so we have it
      // when creating the actual user once registration is verified.
      if(useAccounts)
      {
        nu.setAccountCode(accountCode) ;
      }
      else
      {
        nu.setAccountCode(null) ;
      }
      // Insert the new user record; await sending of email
      nu.insert( db ) ;
      if( JSPErrorHandler.checkErrors(request,response, db,mys) )
      {
        return ;
      }

      // Send email
      fullName = nu.getFirstName() + " " + nu.getLastName() ;
      SendMail m = new SendMail() ;
      m.setHost( Util.smtpHost );
      m.setFrom( adrFrom );
      m.setReplyTo( adrFrom );
      m.addTo("\"" + fullName + "\" <" + nu.getEmail() + ">" ) ;
      // Add BCC addresses
      for(int ii=0; ii < bccAddresses.length; ii++)
      {
        String bccEmail = bccAddresses[ii].trim() ;
        m.addBcc(bccEmail) ;
      }
      m.setSubj("Genboree Registration" ) ;
      m.setBody("Dear " + fullName + ",\n\nTo complete your Genboree registration, please go to the following page:\n\n" +
                GenboreeUtils.returnRedirectString(request.getHeader("host"), "/java-bin/regfinal.jsp") +  "?regno=" + nu.getRegno() + "\n\n" +
                "You will then be prompted to choose a password for the User Name you have choosen.\n" +
                "Please note that the above link will remain active one week from now.\n" +
                "(If you fail to complete your registration within one week, your " +
                "registration will be cancelled.)\n\n" +
                "Thank you for your interest in Genboree,\n" +
                "Genboree Team\n" );

      if( !m.go() )
      {
        String[] emailErrors = m.getErrors() ;
        System.err.println("----------------------------------------------\nSENDING EMAIL - ERRORS ENCOUNTERED using host " + Util.smtpHost + " and User email " + nu.getEmail() + "\n--------------------------------------------") ;
        if(emailErrors != null)
        {
          for(int ii=0; ii<emailErrors.length; ii++)
          {
            System.err.println("   " + ii + ". " + emailErrors[ii]) ;
          }
        }
        System.err.println("") ;

        errs.addElement(" We are having problems validating your email address. " +
                        "  Please report this problem to genboree admin " + GenboreeConfig.getConfigParam("gbAdminEmail"));
        eml_ok = false;
        nu.delete( db );
        nu = null;
      }
      else
      {
        reg1_ok = true ;
        Subscription curSub = Subscription.fetchSubscription( db, user_email );
        if( curSub == null )
        {
          curSub = new Subscription();
          curSub.setEmail( user_email );
          curSub.setNews( 1 );
          curSub.insert( db );
        }
      }
    }
  }
%>

<HTML>
<head>
<title>Genboree - Registration Form</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta http-equiv="Refresh" content="0; URL='/<%=GenboreeConfig.getConfigParam("gbKbMount")%>/projects/genboree_profile_management/genboree_profile_management/profile/new'" />
</head>
<BODY style="display:none !important;">

<script type="text/javascript">
  window.location.href = "/<%= GenboreeConfig.getConfigParam("gbKbMount") %>/projects/genboree_profile_management/genboree_profile_management/profile/new" %> ;
</script>

<%@ include file="include/header.incl" %>

<%
  if(reg1_ok)
  {
%>
<p><%=Util.htmlQuote(fullName)%>,</p>
<p>Thank you for registering with Genboree. An email has been recently sent to the
following address:</p>
<p align="center"><strong><%=Util.htmlQuote(nu.getEmail())%></strong></p>
<p>
It contains instructions to complete the final registration step. Please note that
your registration is not complete until you follow these instructions.
</p>
<form name="reg" id="reg" action="regform.jsp" method="post">
  <input type="submit" name="cmdBack" id="cmdBack" class="btn" value="&nbsp;OK&nbsp;">
</form>
<%
  }
  else
  {
%>
    <br>
<%
    if( errs.size() > 0 )
    {
%>
      <font color=red><strong>
      Your request cannot be processed due to the following reason(s):
      </strong></font>
      <ul>
<%
      for( i=0; i<errs.size(); i++ )
      {
        String s = (String) errs.elementAt(i);
        out.println( "<li>" + Util.htmlQuote(s) + "</li>" ) ;
      }
%>
      </ul>
      Please correct the problem and try again.
<%
    }
%>
    <form name="reg" id="reg" action="regform.jsp" method="post">
    <table border="0" cellpadding="4" cellspacing="2">
    <tbody>
<%
    // Add segment for entering account code
    if(useAccounts)
    {
%>
      <tr>
        <td class="form_header" colspan="2" align="center">
          Genboree Account Code
        </td>
        <td>
          &nbsp;
        </td>
      </tr>
      <tr>
        <td class="form_body">
          <strong>&nbsp;Account Code &nbsp;Name&nbsp;(*)&nbsp;</strong>
        </td>
        <td class="form_body">
          <input type="text" name="accountCode" id="accountCode" size="40" maxlength="40" value="<%=Util.htmlQuote(accountCode)%>">
        </td>
        <td>
          <%=nam_ok?"&nbsp;":"<font color=red><strong>Please fix</strong></font>"%>
        </td>
      </tr>
      <tr>
        <td colspan="3">
          Users will be added under the Genboree Account corresponding to this code.
        </td>
      </tr>
<%
    }
%>
      <tr>
        <td class="form_header" colspan="2" align="center">
          Genboree New User Registration
        </td>
        <td>
          &nbsp;
        </td>
      </tr>
      <tr>
        <td class="form_body">
          <strong>&nbsp;Login&nbsp;Name&nbsp;(*)&nbsp;</strong>
        </td>
        <td class="form_body">
          <input type="text" name="user_name" id="user_name" size="40" maxlength="40" value="<%=Util.htmlQuote(user_name)%>">
        </td>
        <td>
          <%=nam_ok?"&nbsp;":"<font color=red><strong>Please fix</strong></font>"%>
        </td>
      </tr>
      <tr>
        <td colspan="3">
          Any name from 5 to 40 characters long.<br>
          Only letters, digits and underscores are allowed.
        </td>
      </tr>
      <tr>
        <td class="form_body">
          <strong>&nbsp;Email&nbsp;Address&nbsp;(*)&nbsp;</strong>
        </td>
        <td class="form_body">
          <input type="text" name="user_email" id="user_email" size="40" maxlength="80" value="<%=Util.htmlQuote(user_email)%>">
        </td>
        <td>
          <%=eml_ok?"&nbsp;":"<font color=red><strong>Please fix</strong></font>"%>
        </td>
      </tr>
      <tr>
        <td colspan="3">
          Must be your valid email address.
        </td>
      </tr>
      <tr>
        <td class="form_body">
          <strong>&nbsp;First&nbsp;Name&nbsp;(*)&nbsp;</strong>
        </td>
        <td class="form_body">
          <input type="text" name="first_name" id="first_name" size="40" maxlength="40" value="<%=Util.htmlQuote(first_name)%>">
        </td>
        <td>
          <%=fst_ok?"&nbsp;":"<font color=red><strong>Please fix</strong></font>"%>
        </td>
      </tr>
      <tr>
        <td class="form_body">
          <strong>&nbsp;Last&nbsp;Name&nbsp;(*)&nbsp;</strong>
        </td>
        <td class="form_body">
          <input type="text" name="last_name" id="last_name" size="40" maxlength="40" value="<%=Util.htmlQuote(last_name)%>">
        </td>
        <td>
          <%=lst_ok?"&nbsp;":"<font color=red><strong>Please fix</strong></font>"%>
        </td>
      </tr>
      <tr>
        <td class="form_body">
          &nbsp;Institution&nbsp;
        </td>
        <td class="form_body">
          <input type="text" name="institution" id="institution" size="40" maxlength="40" value="<%=Util.htmlQuote(institution)%>">
        </td>
        <td>
          &nbsp;
        </td>
      </tr>
      <tr>
        <td class="form_body">
          &nbsp;Telephone&nbsp;
        </td>
        <td class="form_body">
          <input type="text" name="telephone" id="telephone" size="40" maxlength="40" value="<%=Util.htmlQuote(telephone)%>">
        </td>
        <td>
          &nbsp;
        </td>
      </tr>
      <tr>
        <td colspan="3">
          <input type="checkbox" name="wantnews" id="wantnews" value="y" checked>
          I want to receive occasional emails about Genboree updates and have access
          to software download.
        </td>
      </tr>
      <tr>
        <td colspan="3">
          <input type="submit" name="cmdBack" id="cmdBack" class="btn" value="&nbsp;&lt;Back&nbsp;">
          <input type="submit" name="cmdReg" id="cmdReg" class="btn" value="Submit&gt;">
        </td>
      </tr>
    </tbody>
    </table>
    </form>

    <p>
    Please choose a "login name" which will be used to identify you when logging to Genboree,
    and provide at least the required (*) personal information. Note that the user name
    must be unique within our system. If it conflicts with
    an existing registration, you will be prompted to reenter.
    </p>
    <p>
    Please note also that your email address is required to complete the registration,
    so be sure to provide a valid one.
    </p>
    <p>
    <strong>
    We will never share any personal information (such as emails and telephones)
    with any third-party persons or organizations. All your personal data will never be
    used by ourselves but for the purpose of improving your experience with Genboree.
    </strong>
    </p>

<% } // else if(reg1_ok) %>

<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
