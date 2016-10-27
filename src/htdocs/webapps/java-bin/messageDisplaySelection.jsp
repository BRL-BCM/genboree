<%@ page import="javax.servlet.http.*,
 java.util.*,
 org.genboree.dbaccess.*, org.genboree.util.*, org.genboree.upload.*,
                 java.sql.Connection,
                 java.sql.PreparedStatement,
                 java.sql.ResultSet" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>



<HTML>
<head>
<title>Genboree - User Profile</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<link rel="stylesheet" href="/styles/annotationEditor.css<%=jsVersion%>" type="text/css">
 <SCRIPT TYPE="text/javascript" SRC="/javaScripts/prototype.js<%=jsVersion%>"></SCRIPT>
  <SCRIPT TYPE="text/javascript" SRC="/javaScripts/mygenboree.js<%=jsVersion%>"></SCRIPT>
  <style type="text/css">

     div {
        text-align:left;
        font-size:medium;
        font-weight:normal;
   }
    div.highliter{
      background-color:LightCyan ;
    }

</style>


<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY>

<%@ include file="include/header.incl" %>
<%@ include file="include/navbar.incl" %>



<div>

<p>The current version of the tabular view was temporarily disabled due to excessive use.
  A new version of the tool that can handle very large data sets is being developed and will be deployed soon.
  We do not have a definitive release date yet but we will post any updates when information become available.</p>
  <br />
  <p><strong>Thank you for your Patience</strong>.</p>
  </div>
<div class="highliter">

<p><A HREF='mailto:genboree_admin@genboree.org'>For any questions or concerns please feel free to contact us.</A></p>

</div>


<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
