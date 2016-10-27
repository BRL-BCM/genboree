<%@ page import="javax.servlet.http.*, org.genboree.dbaccess.*, org.genboree.util.*, org.genboree.upload.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%
    response.addDateHeader( "Expires", 0L );
    int mode=0;
    String  msgstart = "";
    String msgend = "";
    String warnMsg = (String) mys.getAttribute( "displayMsg");

     String destback = (String )mys.getAttribute("lastBrowserView");
     if (destback == null)
            destback = "/java-bin/workbench.jsp";



    if( warnMsg == null )
        warnMsg = "";
    else {
        int index = warnMsg.indexOf("edit");
        if (index > 0){
            msgstart = warnMsg.substring(0,index);
            msgend = warnMsg.substring(index +4);
        }
    }
    String tgt = (String) mys.getAttribute("displayTgt");
    boolean refreshGbrowser = false;
    if( tgt == null )
        tgt =  "/java-bin/login.jsp";
    if (request.getParameter("bk2Editor") != null){

        mys.removeAttribute( "displayMsg");
        mys.removeAttribute("displayTgt");
        mys.setAttribute("fromDup", "true");
        GenboreeUtils.sendRedirect(request, response, tgt);
    }

    if  (request.getParameter("clsWin") != null) {
        mys.removeAttribute( "displayMsg");
        mys.removeAttribute("displayTgt");
        refreshGbrowser = true;

    }
%>
    <HTML>
    <head>
      <script type="text/javascript" src="/javaScripts/editorCommon.js<%=jsVersion%>"></script>
<%
  if(refreshGbrowser)
  {
    refreshGbrowser = false ;
%>
    <script language="javascript" type="text/javascript">
      onBlur = self.focus() ;
      confirmRefresh() ;
      window.close();
    </script>
<%
  }
%>

        <title>Genboree - Warning</title>
        <link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
        <meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
    </head>
    <BODY >
        <form name="confirm" id="confirm" action="confirm.jsp" method="post">
               <input type="hidden" name="ok2bk" id="ok2bk" value="<%=mode%>">
                <%@ include file="include/header.incl" %>
                <div style="margin:50">
                    <center>
                        <font size="4" color="green">
                            <%	if (warnMsg != null) { %>
                                <%=msgstart%><B><I>edit</i></B><%=msgend%>
                              <%  } %>
                            </font> <br><br>
                           <input type="submit" class="btn"  name="bk2Editor" id="bk2Editor" value="Yes, please!"> &nbsp; &nbsp;   &nbsp; &nbsp;
                           <!--input type="submit" class="btn"  name="clsWin" id="clsWin" value="No, I'm done!" onClick="window.close();"-->
                             <input type="submit" class="btn"  name="clsWin" id="clsWin" value="No, I'm done!">

                    </center>
                </div> <br><br>
         </form>
        <%@ include file="include/footer.incl" %>
    </BODY>

    </HTML>
