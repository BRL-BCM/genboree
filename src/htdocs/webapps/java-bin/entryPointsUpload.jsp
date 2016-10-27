<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
   <HTML>
    <head>
    <title>Genboree - Entrypoint Upload</title>
    <link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
     <link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">
    <meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
    </head>
    <BODY>
      <%@ include file="include/header.incl" %>
      <%@ include file="include/navbar.incl" %>

     <%
         String fileName = request.getParameter("fileName");
         String destback = (String )mys.getAttribute("lastBrowserView");
         if(destback == null || destback.length() < 1)
         {
           destback = "/java-bin/defaultGbrowser.jsp";
           mys.setAttribute( "lastBrowserView",  destback );
         }
     %>


     <p><strong><%=myself.getFullName()%></strong>,</p>
      <p>Your &quot;entrypoint&quot; fasta file has been uploaded and is being processed.</p>
      <p>
      Because processing of the fasta file take some time (depending on the size
      of your file), we will send you a confirmation email when it is complete.
      </p>
      <p>
      If you do not receive such an email within 48 hours, please feel free to
      contact our <A HREF="mailto:<%=GenboreeConfig.getConfigParam("gbAdminEmail")%>">administrator</A>.
      </p>
      <p>
      When contacting us, please be sure to include the following
      information about your data transaction:</p>
      <p>
      <i>Login Name:</i><%=Util.htmlQuote(myself.getName())%><br>
      <i>File:</i><%=Util.htmlQuote(fileName)%><br>
      <i>Date:</i><%=Util.htmlQuote((new Date()).toString())%><br>
      </p>
      <br>
      <p align="center">
<% if(fileName != null)
{%>
      <a href="<%=destback%>"><img src="/images/goBackToBrowser.gif" width="134" height="24"></a>&nbsp&nbsp
<%}%>
      <a href="myrefseq.jsp?mode=EPs"><img src="/images/uploadMoreData.gif" width="125" height="24"></a></p>


<%@ include file="include/message.incl" %>
      <form name="id" id="id" action="entryPointUpload.jsp" >
       <input type="submit" name="btnClose" id="btnClose" value="Close Window"  class="btn" >
     </form>
      <%@ include file="include/footer.incl" %>
      </BODY>
      </HTML>
