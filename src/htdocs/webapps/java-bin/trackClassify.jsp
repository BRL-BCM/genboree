<%@ include file="include/trackClassify.incl" %>
<HTML>
<head>
    <title>Genboree - Track Management</title>
    <link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
    <link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">
    <meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
    <script src="/javaScripts/emptyTrack.js<%=jsVersion%>" type="text/javascript"></script>
</head>
<BODY >

<DIV id="overDiv" class="c1"></DIV>
<%
   String   hrefStart = "trackClassify.jsp";
   String   labelNameStart = "Classify&nbsp;Tracks";
   String   hrefLast = "trackmgr.jsp";
   String   labelNameLast = "Manage&nbsp;Tracks";
  // if (!errlist.isEmpty())
    //    GenboreeMessage.setErrMsg(mys, "The operation failed:  ", errlist);
%>

<%@ include file="include/header.incl" %>
<%@ include file="include/navbar.incl" %>

<table border="0" cellspacing="4" cellpadding="2">
    <tr>
        <td><a href="<%=destBack%>">&laquo;</a>&nbsp;&nbsp;</td>
        <td class="nav_selected">
            <a href=<%=hrefStart%>><font color=white><%=labelNameStart%></font></a>
        </td>
        <td>:&nbsp;</td>
        <%    String a1 = null;
        for( i=0; i<modeIds.length; i++ )
        {
            String cls = "nav";
            a1 = "<a href=\"trackClassify.jsp?mode=" +modeIds[i] + "\">";
            String a2 = "</a>";
            if( i == (iclassMode) )
            {
                cls = "nav_selected";
                a1 = a1 + "<font color=white>";
                a2 = "</font>" + a2;
            }
        %>
        <td class="<%=cls%>"><%=a1%><%=modeLabels[i]%><%=a2%></td>
        <%
        }
        %>
        <td class="nav"><a href=<%=hrefLast%>><%=labelNameLast%></a></td>
    </tr>
</table>
 <%@ include file="include/message.incl" %>

    <form name="trkClassify" id="trkClassify" action="trackClassify.jsp" method="post">
        <input type="hidden" name="classmode" id="classmode" value="<%=modeIds[startmode]%>">
        <input type="hidden" name="bk2tgr" id="bk2tgr" value="<%=iclassMode%>">
    <table border="0" cellpadding="4" cellspacing="2" width="100%">
        <tr>
           <%@ include file="include/groupbar.incl" %>
        </tr>
       <tr>
          <%@ include file="include/databaseBar.incl"%>
        </tr>
    </table>
    <table border="0" cellpadding="4" cellspacing="0">
        <tr>
            <td>
                <%
                for(i=0; i<vBtn.size(); i++ ) {
                String onclick = null;
                btn = (String[]) vBtn.elementAt(i);
                onclick = (btn[3] == null) ? "" : " onClick=\"" + btn[3] + "\"";
                %>
                <input type="<%=btn[0]%>" name="<%=btn[1]%>" id="<%=btn[1]%>"	value="<%=btn[2]%>" class="btn"<%=onclick%>>
                <%
                }
                %>
            </td>
        </tr>
    </table>
            <%
            if( no_acs ) { %>
            <p><strong>Sorry, you do not have enough privileges to perform this operation.</strong></p>
            <%
            }
            %>
<% if(iclassMode == MODE_ASSIGN  && rseq!= null) { %>
    <table border="0" cellspacing="2" cellpadding="4" width="100%">
        <tr>
            <td class="form_header">Class</td>
            <td class="form_body" width="1%">
            <select class="txt" name="gclassName" id="gclassName" style="width:540" onchange="this.form.submit()">
                <%
                if (gclasses != null)
                for( i=0; i<gclasses.length; i++ )
                {
                DbGclass gr = gclasses[i];
                if (gr== null  )
                continue;
                String isSel = "";
                if (editClassName != null && gr.getGclass() != null)
                isSel =  (gr.getGclass().compareTo(editClassName) == 0 ) ? "selected" : "";
                if (isSel.compareTo("selected")==0)
                mys.setAttribute("editingClass", gr);
                out.println( "<option value=\""+gr.getGclass()+"\""+isSel+">"+	Util.htmlQuote(gr.getGclass())+"</option>" );
                }%>
            </select>
            </td>
        </tr>
        <tr>
            <td class="form_header" valign="top">Track</td>
            <td class="form_body" width="1%">
            <select class="txt" name="clsTrackNames" id="clsTrackNames" style="width:540" multiple size="12">
                <%
               String trackName = null;
                if (tracks != null)
                for( i=0; i<tracks.length; i++ )
                {
                DbFtype ft = tracks[i];
                if (ft == null)
                continue;

                trackName = ft.toString();
                String isSel = (selectedTrackNames.contains(trackName)) ? " selected" : "";
                out.println( "   <option value=\""+ft.toString()+"\""+isSel+">"+Util.htmlQuote(trackName)+"</option>" );
                }

                %>
            </select>
            </td>
        </tr>
    </table>
            <%
            }
            else if( iclassMode == MODE_CREATE && rseq!= null)  {

            %>
    <table border="0" cellspacing="2" cellpadding="4" width="100%">
    <tr>
        <td class="form_header" colspan="2"><strong>Class Editor
        -- Create New Class
        </strong></td>
    </tr>
    <tr>
        <td class="form_body"><strong>Name</strong></td>
        <td class="form_body">
        <input type="text" name="class_name" id="class_name"   style="width:580" value="<%=newClassName%>">
        </td>
    </tr>
    </table>
    <% }
    else if(iclassMode == MODE_RENAME)  {
      if (rseq!= null) {

    %>
    <table border="0" cellspacing="2" cellpadding="4" width="100%">
    <tr>
        <td class="form_body"><strong>Class</strong></td>
        <td class="form_body">
            <select class="txt" name="gclassName" id="gclassName" style="width:540" onchange="this.form.submit()">
            <%
            if (gclasses != null)
            for(  i=0; i<gclasses.length; i++ )
            {
                DbGclass gclass = gclasses[i];
                if (gclass == null) {
                continue;
                }
                
                if (gclass.getGclass() != null && gclass.getGclass().compareToIgnoreCase ("Sequence") == 0) 
                    continue;
                
                String sel = "";
                if (editClassName != null && gclass.getGclass() != null)
                  sel = (gclass.getGclass().compareTo(editClassName) == 0 ) ? "selected" : "";

                if (sel.compareTo ( "selected") ==0)
                            editingClass = gclass;
                if (gclass.isLocal()) {
                  
            %>
        <option   value="<%=gclasses[i].getGclass()%>"<%=sel%>><%=Util.htmlQuote(gclasses[i].getGclass()) %></option>
            <%}
            else {%>
        <option   value="<%=gclasses[i].getGclass()%>"<%=sel%>><%=Util.htmlQuote(gclasses[i].getGclass()) + "  (Share Class)" %></option>
                <% }
                } %>
        </select>
        </td>
    </tr>

    <tr>
        <td class="form_body"><strong>New Name</strong></td>
        <td class="form_body">
            <input type="text" name="newclass_name" id="newclass_name" class="txt" style="width:580" >
        </td>
    </tr>


</table>
    <% }}
    else if( iclassMode == MODE_DELETE)  { %>
<table border="0" cellspacing="2" cellpadding="4" width="100%">
<%
  if (rseq != null)      {
%>

    <tr>
        <td class="form_header">Name</td>
        <td class="form_header">Deletable?</td>
        <td class="form_header" width="80">Delete</td>
    </tr>
    <%
    if (gclasses != null )      {
        for( i=0; i<gclasses.length; i++ ) {
            DbGclass gclass = gclasses[i];
            if (gclass != null && gclass.getGclass() != null) {
            if (gclass.getGclass().compareToIgnoreCase("Chromosome")==0)
            continue;
            else  if (gclass.getGclass().compareToIgnoreCase("Sequence")==0)
            continue;
            String altStyle = ((i%2) == 0) ? "form_body" : "bkgd";
            boolean b =ClassManager.isEmpty(gclasses[i].getGclass(), db, rseq.getDatabaseName());
            if ( b && gclasses[i].isLocal()) {
            %>
                <tr>
                <td class="<%=altStyle%>"><strong><%=Util.htmlQuote(gclasses[i].getGclass())%></strong></td>
                <td  class="<%=altStyle%>">Yes</td>
                <td class="<%=altStyle%>">
                <input type="checkbox" name="delclassId" id="delclassId" value=<%=gclasses[i].getGid()%> >
                </td>
                </tr>
            <% }
            else if (!b && gclasses[i].isLocal())  {  %>
                <tr>
                <td class="<%=altStyle%>"><strong><%=Util.htmlQuote(gclasses[i].getGclass())%></strong></td>
                <td  class="<%=altStyle%>">No. Class not empty.</td>
                <td class="<%=altStyle%>">
                </td>
                </tr>
            <% }
            else if (!gclasses[i].isLocal()) { %>
                <tr>
                    <td class="<%=altStyle%>"><strong><%=Util.htmlQuote(gclasses[i].getGclass())%></strong></td>
                    <td  class="<%=altStyle%>">No. Class from genome template.</td>
                    <td class="<%=altStyle%>">
                    </td>
                </tr>
            <%}  }
        }
    }}
    %>
</table>
        <% }
        else if( iclassMode == MODE_HELP)  { }
        else if( iclassMode == MODE_DEFAULT && rseq!= null) { %>
    <table border="0" cellspacing="0" cellpadding="2" width="100%">
        <tr>
            <td class="form_header">Available Track&nbsp;List</td>
        </tr>
        <%
       if (tracks != null)
        for(  i=0; i<tracks.length; i++ )  {
            String ftName ="";
            String altStyle = ((i%2) == 0) ? "form_body" : "bkgd";
            if (tracks != null && i <tracks.length ){
            //	String altStyle = ((i%2) == 0) ? "form_body" : "bkgd";
            DbFtype ft = tracks[i];
            ftName = ft.toString();
        %>
        <tr>
        <td class="<%=altStyle%>"><%=Util.htmlQuote(ftName)%></td>
        </tr>
        <% } }
        %>
    </table>
        <br>
     <table border="0" cellspacing="0" cellpadding="2" width="100%">
    <tr>
        <td class="form_header">Available Class&nbsp;List</td>
    </tr>
        <%
        if (gclasses != null)
        for(  i=0; i<gclasses.length; i++ )  {
            DbGclass gclass = gclasses[i];
            if (gclass == null || gclass.getGclass() == null) {
              
               continue;  
            }    
                
                
            String altStyle = ((i%2) == 0) ? "form_body" : "bkgd";
            String  className = gclass.getGclass();
                
                 if (!gclass.isLocal()) 
                      className = className + "  (Template Class)";
            
            
                 
        %>
    <tr>
        <td class="<%=altStyle%>"><%=Util.htmlQuote(className)%></td> </tr>
        <%
        }
        %>
    </table>
        <% } // MODE_DEFAULT %>

        <% if( iclassMode != MODE_HELP  && iclassMode != MODE_DEFAULT) { %>
    <br>
    <table border="0" cellpadding="4" cellspacing="0">
    <tr>
    <td>
        <%
         if (rseq != null)
        for( i=0; i<vBtn.size(); i++ )
        {
        btn = (String []) vBtn.elementAt(i);
        String onclick = (btn[3]==null) ? "" : " onClick=\""+btn[3]+"\"";
       %>
    <input type="<%=btn[0]%>" name="<%=btn[1]%>" id="<%=btn[1]%>" value="<%=btn[2]%>" class="btn"<%=onclick%>>
        <%
        }
        %>
    </td>
    </tr>
    </table>
    <% } %>
    </form>
<%@ include file="include/footer.incl" %>
</BODY>
</HTML>
