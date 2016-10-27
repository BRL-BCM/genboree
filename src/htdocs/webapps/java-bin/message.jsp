                        <%@ page import="javax.servlet.http.*, org.genboree.dbaccess.*, org.genboree.util.*, org.genboree.upload.*" %>
                        <%@ include file="include/fwdurl.incl" %>
                        <%@ include file="include/userinfo.incl" %>
                        <%!
                        %>
                        <%
                            response.addDateHeader( "Expires", 0L );

                        	String warnMsg = (String) mys.getAttribute( "displayMsg");
                        	if( warnMsg == null ) warnMsg = "UNKNOWN";
                        	String sTmo = (String) mys.getAttribute( "displayTmo" );
                        	int warnTmo = Util.parseInt( sTmo, 3 );
                        	String tgt = (String) mys.getAttribute("displayTgt"  );
                        	if( tgt == null ) tgt = "login.jsp";
                        	mys.removeAttribute( "displayMsg" );
                        	mys.removeAttribute( "displayTmo" );
                        	mys.removeAttribute( "displayTgt" );
                        %>

                        <HTML>
                        <head>
                        <title>Genboree - Warning</title>
                        <link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
                        <meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
                        </head>
                        <BODY onLoad="setTimeout('forwardHome()', <%=warnTmo%>000);">

                        <%@ include file="include/header.incl" %>

                        <center>
                        	<font size="4" color="green"><strong>Message</strong>
                              <br><br>
                        	<%=warnMsg%><br><br>  </font>
                        </center>

                        In <%=warnTmo%> seconds you will be automatically forwarded to the start page.
                        Click <a href="<%=tgt%>">here</a> if you do not want to wait any longer, or if
                        your browser does not support automatic forwarding.

                        <%@ include file="include/footer.incl" %>

                        <script language="JavaScript">
                        function forwardHome()
                        {
                        	document.location.replace( "<%=tgt%>" );
                        }
                        </script>

                        </BODY>
                        </HTML>
