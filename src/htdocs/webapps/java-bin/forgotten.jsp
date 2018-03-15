<%@ page import="javax.servlet.http.*,
 java.sql.*,
 org.genboree.dbaccess.*, org.genboree.util.*, org.genboree.upload.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/common.incl" %>
<%!
	static String adrFrom = "\"Genboree Team\" <" + GenboreeConfig.getConfigParam("gbFromAddress") + ">" ;
    String[] userInfo = new String[3] ;
%>
<%
	if( request.getParameter("cmdOk") != null )
	{
		GenboreeUtils.sendRedirect(request,response,  "/java-bin/workbench.jsp" ) ;
		return ;
	}

	String userName = request.getParameter("genboree_user") ;
	String userEmail = request.getParameter("genboree_email") ;
	String[] errs = null ;
	GenboreeUser usr = null ;
	String adrTo = null ;
	boolean sent_ok = false ;
	int i ;

  if(userName == null)
  {
    userName = "" ;
  }
  if(userEmail == null)
  {
    userEmail = "" ;
  }

  userName = userName.trim() ;
  userEmail = userEmail.trim() ;
  if(!Util.isEmpty(userName) && !Util.isEmpty(userEmail))
  {
    boolean by_email = true ;

    if(request.getParameter("cmdSend") != null)
    {

      String qs = "SELECT name, password, firstName, lastName, email FROM genboreeuser WHERE email = ? and name = ? " ;
      String[] bindVars = { userEmail, userName } ;
      if(qs != null)
      {
        DbResourceSet dbRes = db.executeQuery(null, qs, bindVars) ;
        ResultSet rs = dbRes.resultSet ;

        if(rs != null && rs.next())
        {
          usr = new GenboreeUser() ;
          usr.setName(rs.getString(1)) ;
          usr.setPassword(rs.getString(2)) ;
          usr.setFirstName(rs.getString(3)) ;
          usr.setLastName(rs.getString(4)) ;
          usr.setEmail(rs.getString(5) ) ;

          adrTo = "\"" + usr.getFullName() + "\" <" + usr.getEmail() + ">" ;
          SendMail m = new SendMail() ;

          m.setHost(Util.smtpHost) ;
          m.setFrom(adrFrom) ;
          m.setReplyTo(adrFrom) ;
          m.addTo(adrTo) ;
          m.setSubj("The information you recently requested.") ;

          String body =
            "Here is the information you requested:\n\n" +
            usr.getPassword() + "\n\n" ;
          dbRes.close() ;

          body += "If you did not recently request this information, please ignore this email.\n" ;

          m.setBody(body) ;

          sent_ok = m.go() ;
          if(!sent_ok)
          {
            errs = m.getErrors() ;
            if(errs != null && errs.length == 0)
            {
              errs = null ;
            }
          }
        }
        else
        {
          errs = new String[1] ;
          if(by_email)
          {
            errs[0] = "Unknown username & email combination." ;
          }
        }
      }
    }
  }
  else // Maybe missing email or user name, or maybe just arrived at page
  {
    if(Util.isEmpty(userName) ^ Util.isEmpty(userEmail))
    {
      errs = new String[1] ;
      errs[0] = "Both the email address and Genboree login name are required." ;
    }
    else // missing both, just arrived at page
    {
      if(userName == null)
      {
        userName = "" ;
      }
      if(userEmail == null)
      {
        userEmail = "" ;
      }
    }
  }
%>

<HTML>
<head>
<title>Genboree - Forgot Password</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta http-equiv="refresh" content="0; URL='/<%=GenboreeConfig.getConfigParam("gbKbMount")%>/projects/genboree_profile_management/genboree_profile_management/profile/forgot_pwd'">
</head>
<BODY>
<%@ include file="include/header.incl" %>
<%
	if( errs != null )
	{
		out.println( "<strong>" ) ;
		out.println( "<font color=red>Error(s):</font><br>" ) ;
		for( i=0; i<errs.length; i++ )
    {
			out.println("-- "+Util.htmlQuote(errs[i])+"<br>") ;
    }
		out.println("</strong>") ;
	}

	if(!sent_ok)
  {
%>
<br>
	Please enter BOTH your email address AND your Genboree User Name (login)
	in the box below, then press &quot;Send&quot;.
<br>&nbsp;<br>
	Your password will be sent to your email address in a very generic looking email.
<br>
  (Subject: &quot;The information you recently requested.&quot;)
<br>

<form action="forgotten.jsp" method="post">
<table border="0" cellpadding="4" cellspacing="2">

<tr>
<td class="form_body"><strong>&nbsp;Email:&nbsp;</strong></td>
<td class="form_body">
    <input type="text" name="genboree_email" id="genboree_email"
	  size="60" maxlength="80"
	  value="<%=userEmail%>">
</td>
</tr>

<tr>
<td class="form_body"><strong>&nbsp;User&nbsp;Name:&nbsp;</strong></td>
<td class="form_body">
    <input type="text" name="genboree_user" id="genboree_user"
	  size="40" maxlength="40"
	  value="<%=userName%>">
    <input name="cmdSend" id="cmdSend" type="submit"
	value='Send' class="btn" style="width:100">
</td>
</tr>

</table>
</form>

<%
  }
  else
  {
%>

<br>
	Your Genboree registration info has been sent to:<br>
	<%= Util.htmlQuote(adrTo) %>
<br>

<form action="forgotten.jsp" method="post">
<table border="0" cellpadding="10" cellspacing="0">
<tr><td><input name="cmdOk" id="cmdOk" type="submit"
	value='OK'  class="btn" style="width:100"></td></tr>
</table>
</form>
<%
  }
%>
<%@ include file="include/footer.incl" %>
</BODY>
</HTML>
