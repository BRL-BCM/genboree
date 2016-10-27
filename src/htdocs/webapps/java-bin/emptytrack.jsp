<%@ page import="org.genboree.util.GenboreeUtils"%>
<%@ include file="include/group.incl" %>
<%@ include file="include/emptyTrack.incl" %>
<%
    GenboreeMessage.clearMessage(mys);   
    Refseq rseq = null;
    mys.removeAttribute("emptyTrackAssignSuccess");
    if ( mys.getAttribute("rseq") != null)
        rseq =  (Refseq)  mys.getAttribute("rseq");
    
     String  dbName = null;    
    if (rseq != null) 
      dbName = rseq.getDatabaseName();
    
    int i =0;     
    DbFtype [] selftypes = (DbFtype[]) mys.getAttribute("selftypes");      
    DbGclass editingClass = (DbGclass)mys.getAttribute("editingClass");         
    DbGclass [] etgclasses =   (DbGclass [])mys.getAttribute("gclasses");
    DbFtype [] emptyTracks = (DbFtype[]) mys.getAttribute("emptyTracks");
    
     HashMap className2Gclass= new HashMap (); 
    if (etgclasses != null && etgclasses.length >0) {
        for (i=0; i<etgclasses.length; i++)
            className2Gclass.put(etgclasses[i].getGclass(), etgclasses[i]);        
    }
        
    Connection con = db.getConnection(dbName); 
    HashMap httrack2Classes = new HashMap();
    if (emptyTracks!= null) {
            for ( i =0; i<emptyTracks.length; i++) {
                String  selectedClassName = request.getParameter("emptyClassName_" + i) ;
                if (selectedClassName != null)
                          httrack2Classes.put(emptyTracks[i].getFmethod()+":" + emptyTracks[i].getFsource() , selectedClassName);           
                               
         }
    }
    
    boolean isreset  = false;
    int updatedTracks = 0;
    if (request.getParameter("saveButton")!= null) {
        if (emptyTracks == null || emptyTracks.length <=0)
                return;
        DbFtype ft  = null;
        String state = request.getParameter("success");
        if (state != null && state.compareTo ("y") ==0) {

        if (validateSelection (emptyTracks.length, request, out)) {
        // update track map of previous selection
      
        ClassManager.updateTrackMap(con, selftypes, editingClass.getGid());
   
        isreset = false;
       
        if (className2Gclass==null) {
                String [] errs = new String [2];
                errs[0]= " happend inrtriving class information from database.";
                errs[1] = " error in trackClassify_gclasses";
                GenboreeUtils.sendRedirect(request,response, "/java-bin/error.jsp");
        }
       
        for (int k =0; k< emptyTracks.length; k++ ){
            ft = emptyTracks[k];
             String selectedClassName = request.getParameter("emptyClassName_" + k) ;
             out.println(selectedClassName);  
              httrack2Classes.put(emptyTracks[k].getFmethod()+":" + emptyTracks[k].getFsource() , selectedClassName);                                        
                 DbGclass gclass = null;
                 if (className2Gclass.get(selectedClassName) != null) {
                     gclass =(DbGclass) className2Gclass.get(selectedClassName);
                       if (!gclass.isLocal()) {
                                int id = ClassManager.insertGclass( con, selectedClassName) ;
                             if (id > 0) {
                                 gclass.setGid(id);
                                gclass.setLocal(true);
                                className2Gclass.remove(selectedClassName) ;
                                className2Gclass.put(selectedClassName, gclass);
                             }
                             else {   String [] errs = new String [2];
                                            errs[0]= " happend in updating database for new class creation";
                                             errs[1] = " error in gclass.insert";
                                GenboreeUtils.sendRedirect(request,response, "/java-bin/error.jsp");
                             }
                        }
                }
             }     //checking for shared track and make a local copy
     // }

      // checking for shared class and update
      if (!editingClass.isLocal()) {
          if (editingClass.insert(con))
             editingClass.setLocal(true);
          else {   
                String [] errs = new String [2];
                errs[0]= " happend in updating database for new class creation";
                errs[1] = " error in gclass.insert";
                GenboreeUtils.sendRedirect(request,response, "/java-bin/error.jsp");
          }
       }
            
        if(saveEmptyTrackMap (con, httrack2Classes, emptyTracks, etgclasses,rseq, db, out)) {        
            String be = selftypes.length >1 ? "were" :"was";
            String message = " The assignment operation was successful. <br>" + selftypes.length + " tracks " + be + " assigned to selected classes." ;
            mys.setAttribute("emptyTrackAssignSuccess", message);
            //GenboreeMessage.setSuccessMsg(mys, message);
             GenboreeUtils.sendRedirect(request,response, "/java-bin/trackClassify.jsp?mode=classAssign");
        }
        else  {
          GenboreeUtils.sendRedirect(request,response,  "/java-bin/trackClassify.jsp"  );
         }
      }
      else {
        GenboreeMessage.setErrMsg(mys, " Please select a class for all the tracks.") ;
      }
      }
       else {
         GenboreeMessage.setErrMsg(mys, " Please select a class for all the tracks.") ;
      }
   }

    if (request.getParameter("resetClass") != null){
        isreset = true;
    }

    if( request.getParameter("back2mgr") != null ){  
        GenboreeUtils.sendRedirect(request,response, "/java-bin/trackClassify.jsp?mode=classAssign");
        return;
    }
    
    int n = 0;
    String defaultMsg =   "The following tracks would no longer have classes. ";
    ArrayList errlist = new ArrayList();
    errlist.add("please pick a class for each classless-track.");

    if (emptyTracks != null)
       n = emptyTracks.length;

    String validate = " validateForm (" + n + ");";
     dbName =  SessionManager.getSessionDatabaseDisplayName(mys);
      
%>
<HTML>
<head>
    <title>Genboree - Track Management: Empty Tracks </title>
    <link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
    <link rel="stylesheet" href="/styles/trackmgr.css<%=jsVersion%>" type="text/css">
      <link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">
    <meta HTTP-EQUIV='Content-Type' CONTENT='text/className2Gclassml; charset=iso-8859-1'>
    <SCRIPT TYPE="text/javascript" SRC="/javaScripts/emptyTrack.js<%=jsVersion%>"></SCRIPT>
</head>

<BODY >
<DIV id="overDiv" class="c1"></DIV>
<%@ include file="include/header.incl" %>
<%@ include file="include/navbar.incl" %>

<form name="eptrack" id="eptrack" action="emptytrack.jsp" method="post">
<input type="hidden"  size="20" name="success"  id="success"  value="n">

<table border="0" cellpadding="4" cellspacing="2" width="100%">
    <tr>
        <td class="form_header" width="110"><strong>Database</strong></td>
        <td class="form_header">
        <%=dbName%>
        </td>
    </tr>
</table>

 <% if (mys.getAttribute("errorMsg") == null && mys.getAttribute("successMsg") == null && mys.getAttribute("genericMsg") == null) {
        GenboreeMessage.setErrMsg(mys, defaultMsg, errlist);
 }%>


 <%@ include file="include/message.incl" %>
        <table border="0" cellpadding="4" cellspacing="0">
            <tr>
                <td>
                <input type="submit"  name="saveButton" id="saveButton"	value=" Save " class="btn"  onClick="<%=validate%>" > &nbsp;
                <input type="reset"  name="resetClass" id="resetClass"	value=" Reset " class="btn" > &nbsp;
                <input type="submit" name="back2mgr"   id="back2mgr"	value=" Cancel " class="btn">  &nbsp;
                </td>
            </tr>
        </table>


        <table border="0" cellpadding="2" width="100%">
            <tr>
                <td class="form_header" width="50%">Tracks</td>
                <td class="form_header" width="50%">Classes</td>
            </tr>
        <%      String sel = "";
            if (emptyTracks != null )
            for( i=0; i<emptyTracks.length; i++ ){
                DbFtype  ft = emptyTracks[i];
                String trackName = ft.getFmethod()+":"+ft.getFsource();
                String trackid = "emptyClassName_" + i;
                String trackLabel =  "emptyClassNameLabel_" + i;
                boolean firstTime = false;
                boolean isDefault = false;
            %>
                <tr>
                    <td  name="<%=trackLabel%>" id="<%=trackLabel%>"  class="form_body" >
                         <%=Util.htmlQuote(trackName)%>
                    </td>
                    <td class="form_body">
                    <select name="<%=trackid%>" id="<%=trackid%>"  size="1" class="txt" style="width:320" >

                    <%  if (request.getParameter(trackid) == null) {
                        firstTime = true;
                        sel = "  selected";
                    %>
                    <option value="select a class" <%=sel%>>--- Select a class ---</option>
                    <%  }
                    else  {
                        sel = "";
                        String s  = (String)httrack2Classes.get(trackName);
                        if (s!=null && s != null)
                        sel = (s.indexOf("select a class")>=0) ? " selected" : "";
                        %>
                        <option value="select a class" <%=sel%>>--- Select a class ---</option>
                    <%}%>

                    <%
               if (etgclasses != null)
                        for( int j=0; j<etgclasses.length; j++ ){
                            DbGclass gclass = etgclasses[j];
                            String className = gclass.getGclass();
                            String s  = (String)httrack2Classes.get(trackName);
                                sel = "";
                            if (s!=null && className != null)
                                sel = (s.compareTo(className)==0) ? " selected" : "";
                    %>
                    <option value="<%=gclass.getGclass()%>" <%=sel%> ><%=gclass.getGclass()%></option>
                    <% } %>
                    </select>
                    </td>
                </tr>
            <%}
            isreset = false;
            %>
        </table>
<br>
<%@ include file="/include/footer.incl" %>
</form>
</BODY>
</HTML>
