<%@ page import="javax.servlet.http.*, java.util.*, java.sql.*, java.io.*,
                 org.genboree.dbaccess.*, org.genboree.dbaccess.util.*, org.genboree.util.*, org.genboree.upload.*,
                 java.text.NumberFormat,
                 java.text.DecimalFormat,
                 org.genboree.editor.AnnotationDetail,
                 org.genboree.message.GenboreeMessage,
                 org.genboree.editor.AnnotationEditorHelper" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%@ include file="include/pageInit.incl" %>
<%@ include file="include/saved.incl" %>
<%
        boolean trackBlocked = false ;
        int i;
        String aid ="";
        String aval = "";
        String dbName = "";
        String [] fids = null;
        AnnotationDetail [] lastPageAnnotations  = null;
        String groupNewName = "";
        String okState ="okState";
        String state = "0";
        String changed ="0";
        String initVal ="";
        String chrName = "1";
        response.addDateHeader( "Expires", 0L );
        response.addHeader( "Cache-Control", "no-cache, no-store" );

        AnnotationDetail annotation = null;
        AnnotationDetail[] annotations = null;
        AnnotationDetail[] totalAnnotations = null;
        String formId = "editorForm";
        String uploadId = null ;
        String fidParam = null ;

        ArrayList pageSelectedFidList = new ArrayList();
        AnnotationDetail [] selectedAnnotations = null;
        String orderNum = "1";
        HashMap fid2AnnoNums = new HashMap ();
        HashMap fid2Annos = new HashMap ();
        int numRemain = 0;
        ArrayList selectedFids = new ArrayList();
        boolean updateAll = false;
        String  lastPageIndex ="";
        int numSelected = 0;
        int [] fidi  = new int [0];
        boolean validFid = false ;
        String selectAll = "selectAll(0)";
        String className = "";
        String rid= "";
        String ftypeid = "" ;
        String gclass = null;
        String confirmSelected = " return confirmSelected(0,0,false)"; ;
        String unSelectAll = "unSelectAll(0)";
        String doSelected ="doSelected";
        ArrayList groupSelectedFidList = new ArrayList();
        if (request.getParameter("upfid") != null){
        mys.removeAttribute("selectedFidList");
        mys.removeAttribute("initVal");
        }
        else {
        if (mys.getAttribute("selectedFidList") != null)
        groupSelectedFidList =   (ArrayList)mys.getAttribute("selectedFidList");
        }


        ArrayList totalAnnoList = new ArrayList();

        String textid = request.getParameter("upfid");
        String[] ss = null;
        if( textid != null ) ss = Util.parseString(textid,',');
        else ss = new String[0];

        Hashtable htUpl = new Hashtable();
        String groupName = null;

        String trackName = "";


        if (request.getParameter("upfid") == null ) {
            className = (String)mys.getAttribute("gclassName");
            trackName =  (String)mys.getAttribute("trackName");
             chrName =  (String)mys.getAttribute("chrName");
            initVal =  (String)mys.getAttribute("initval");
             gclass = (String)mys.getAttribute("gclass");
            totalAnnotations =  (AnnotationDetail[])mys.getAttribute("totalAnnotations");
            fid2AnnoNums = (HashMap )mys.getAttribute("fid2AnnoNums");
            dbName = (String)mys.getAttribute("dbName");
        }

        String checkBoxName = "";
      Connection con = null;

  if (request.getParameter("upfid") != null)
  {
    byte[] b = new byte[70] ;
    for( i=0; i<ss.length; i++ )
    {
        textid = ss[i];
        String[] sss = Util.parseString( textid, ':' );
        if( sss.length < 2 ) continue;
        uploadId = sss[0];
        fidParam = sss[1];
        GenboreeUpload u = (GenboreeUpload) htUpl.get( uploadId );

        if( u == null )
        {
        u = new GenboreeUpload();
        u.setUploadId( Util.parseInt(uploadId,-1) );
        u.fetch( db );
        htUpl.put( uploadId, u );
        }
        dbName = u.getDatabaseName();
            if (dbName != null && !dbName.equals(""))
              mys.setAttribute("dbName", dbName);
          con = db.getConnection(u.getDatabaseName());

        // See if user has ability to Edit this fid in this upload
        Connection mainCon = db.getConnection();
        if (con == null || con.isClosed() || mainCon== null || mainCon.isClosed())
        {
          GenboreeUtils.sendRedirect(request,response, "/java-bin/error.jsp");
        }
        if(u != null && (request.getParameter("upfid") != null)  )
        {
          validFid =  AnnotationEditorHelper.verifyUploadIdAndFid(iUserId, Integer.parseInt(uploadId), Integer.parseInt(fidParam), u, mainCon, con) ;
        }

        String aText = null;
        String aSeq = null;
        String fstart = null;
        String fstop = null;
        String fscore = null;
        String fstrand = "n/a";
        String ftargetStartString = null;
        String ftargetStopString = null;
        long ftargetStart = 0;
        long ftargetStop = 0;
        String gname = null;

        String fmethod = null;
        String fsource = null;

        String srcRid = null ;
        String fidStr = null;
        String typeId = null;
        long len = 0;
        String sLen = null;
        String query1 = null;
        String query2 = null;
        String query3 = null;
        double dScore = 0.0;
        StringBuffer tempGclass = null;
        String queryX = null;
        DbResourceSet dbRes = null;
        DbResourceSet dbRes2 = null;

        try
        {
            // Get the fdata2 record for the annotation that was clicked.
            query1 = "SELECT fd.gname, fd.ftypeid, fd.rid FROM fdata2 fd WHERE fd.fid = ?" ;
            String[] bindVars1 = { fidParam } ;
            dbRes = db.executeQuery( u.getDatabaseName(), query1, bindVars1 );
            ResultSet rs = dbRes.resultSet;

            if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
            if( rs!=null && rs.next() ){
                groupName = rs.getString(1);
                className = groupName;
                typeId = rs.getString(2);
                srcRid = rs.getString(3) ;
                rid = srcRid;
                dbRes.close();
            }
            else
            {
              return;
            }

          // First, are we even allowed to see the details of this annotation?
          // If the track download is blocked, we cannot show details.
          trackBlocked = FtypeTable.isAnnoDownloadBlocked(con, fidParam) ;
          if( !trackBlocked )
          {
            // Get the ftype record for the annotation that was clicked
            queryX = "SELECT fmethod, fsource FROM ftype WHERE ftypeid = ? " ;
            String[] bindVarsX = { typeId } ;
            dbRes =  db.executeQuery( u.getDatabaseName(), queryX, bindVarsX ) ;
            rs = dbRes.resultSet;
            if( JSPErrorHandler.checkErrors(request,response, db,mys) )
            {
               dbRes.close();
              return ;
            }
            if( rs!=null && rs.next() ) {
              fmethod = rs.getString("fmethod");
              fsource = rs.getString("fsource");
              trackName = fmethod + ":" + fsource;
               dbRes.close();
            }
            else
            {
              dbRes.close();
              return ;
            }

            // Get the fref record for the annotation that was clicked
            queryX = "SELECT refname FROM fref where rid = ? " ;
            String[] bindVarsY = { srcRid } ;
            dbRes = db.executeQuery( u.getDatabaseName(), queryX, bindVarsY ) ;
            rs = dbRes.resultSet;
            if( JSPErrorHandler.checkErrors(request,response, db,mys) )
            {
               dbRes.close();
               return ;
            }
            if( rs!=null && rs.next() ) {
              chrName = rs.getString("refname");
              dbRes.close();
            }
            else
            {
              dbRes.close();
              return ;
            }

            query2 = "SELECT fstart, fstop, fscore, fstrand, fphase, gname, fid, ftarget_start, ftarget_stop " +
                     "FROM fdata2 fd " +
                     "WHERE " +
                        "fd.ftypeid = ? AND " +
                        "fd.rid = ? AND " +
                        "fd.gname = ? " +
                     "ORDER BY fstart, fstop" ;
            String bindVars2[] = { typeId, srcRid, groupName } ;

            query3 = "SELECT gclass.gclass gclassName FROM gclass, ftype2gclass WHERE " +
                     "gclass.gid = ftype2gclass.gid and ftype2gclass.ftypeid = ? " ;
            String bindVars3[] = { typeId } ;
            dbRes =  db.executeQuery( u.getDatabaseName(), query3, bindVars3 ) ;
            rs = dbRes.resultSet;

            if( JSPErrorHandler.checkErrors(request,response, db,mys) )
            {
              dbRes.close();
              return;
            }

            if(rs == null)
            {
              gclass = "UnAssigned";
               dbRes.close();
            }
            else
            {
                tempGclass = new StringBuffer( 200 );
                while( rs.next() )
                {
                    tempGclass.append(rs.getString("gclassName"));
                    if(!rs.isLast())
                    {
                      tempGclass.append(",");
                    }
                }
                gclass = tempGclass.toString();
                dbRes.close();

            }

            dbRes = db.executeQuery( u.getDatabaseName(), query2, bindVars2 );
            rs = dbRes.resultSet;
            if( JSPErrorHandler.checkErrors(request,response, db,mys) )
            {
              dbRes.close();
              return;
            }


         while( rs.next() )
            {
              AnnotationDetail anno = new AnnotationDetail(rs.getInt("fid"));
                fstart = rs.getString("fstart");
                fstop = rs.getString("fstop");
               anno.setFstart(fstart);
               anno.setFstop(fstop);

               long longstart  = Long.parseLong(fstart);
               long longstop = Long.parseLong(fstop);
               anno.setStart(longstart);
                anno.setStop(longstop);


                 fstrand = rs.getString("fstrand");
                if(fstrand == null || (fstrand == ""))
                {
                  fstrand = "+" ;
                }

                 anno.setStrand(fstrand) ;



                String fphase = rs.getString("fphase");
                if(fphase == null || (fphase == ""))
                {
                  fphase = "0" ;
                }

                 anno.setPhase(fphase); ;
            anno.setGname(rs.getString("gname"));
                fidStr = rs.getString("fid");
                anno.setTargetStart(rs.getLong("ftarget_start"));
                anno.setTargetStop(rs.getLong("ftarget_stop"));

                len = Util.parseLong(fstop,0L) - Util.parseLong(fstart,0L) + 1L;

                // NumberFormat formatter = new DecimalFormat("0.#####E0");
                NumberFormat formatter = new DecimalFormat("#,##0.0000");
                dScore =  rs.getDouble("fscore");

                fscore = formatter.format(dScore);
                anno.setScore(rs.getDouble("fscore") );
                  anno.setFscore(fscore);
              anno.setFstart(fstart);
                anno.setFstop(fstop);

                if(ftargetStart == 0)
                    ftargetStartString = "n/a";
                else
                    ftargetStartString = Util.putCommas(""+ftargetStart);

                if(ftargetStop == 0)
                    ftargetStopString = "n/a";
                else
                    ftargetStopString = Util.putCommas(""+ftargetStop);
                anno.setTstart(  ftargetStartString);
                anno.setTstop( ftargetStopString);

                query3 =  "SELECT textType, text FROM fidText WHERE fid = ?";
                bindVars3[0] = fidStr ;
                dbRes2 =  db.executeQuery( u.getDatabaseName(), query3, bindVars3);
                ResultSet rs2 =  dbRes2.resultSet;
                aText = null;
                aSeq = null;
                while( rs2.next() )
                {
                    String tt = rs2.getString(1);
                    if( tt.equals("t") )
                    {
                        aText = rs2.getString(2);
                    }
                    else
                    {
                        InputStream bIn = rs2.getAsciiStream(2);
                        int n = bIn.read( b );
                        while( n > 0 )
                        {
                            if( aSeq == null ) aSeq = "";
                            aSeq = aSeq + (new String(b,0,n)) + "<br>\r\n";
                            n = bIn.read( b );
                        }
                    }
                }
                dbRes2.close();

                len = anno.getStop() - anno.getStart();
                 sLen = Util.putCommas(""+len);
                fstart =Util.putCommas(""+fstart);
                fstop = Util.putCommas(""+fstop);
                anno.setComments(aText);
                anno.setSequences(aSeq);
                 totalAnnoList.add(anno);


            }
            dbRes.close();
          }
          else // track is blocked for download
          {
            break ; // exit for loop, we don't need to bother
          }
        }
        catch( Exception ex00 )
        {
            out.println( ex00.getClass().getName() );
            if( ex00 instanceof SQLException )
            {
                out.println( ((SQLException)ex00).getMessage() );
            }
        }
        if (totalAnnoList.size() >0) {
            totalAnnotations =(AnnotationDetail[]) totalAnnoList.toArray(new AnnotationDetail[totalAnnoList.size()]);
        }

        if ( totalAnnotations != null &&  totalAnnotations.length >0)
        {
            className = totalAnnotations[0].getGname();
              mys.setAttribute("gclass",  gclass);
            mys.setAttribute("gclassName",  className);
            mys.setAttribute("totalAnnotations",  totalAnnotations);
            mys.setAttribute("trackName", trackName);
            mys.setAttribute("ftypeid", "" +  totalAnnotations[0].getFtypeId());
            mys.setAttribute("rid", "" +  rid);
             mys.setAttribute("chrName", chrName);
            mys.setAttribute("initval", "" + totalAnnotations.length);
            mys.setAttribute("changed", "no");
            int tempint = 0;
            mys.setAttribute("totalNumAnnotations", "" + totalAnnotations.length);
            for (i=0; i<totalAnnotations.length; i++) {
            tempint = i+1;
            fid2AnnoNums.put("" + totalAnnotations[i].getFid(), "" + tempint);
            }
            mys.setAttribute("fid2AnnoNums", fid2AnnoNums);
        }
    } // END: for( i=0; i<ss.length; i++ )
  }

if (mys.getAttribute("lastPageIndex")!= null)
{
  lastPageIndex =  (String)mys.getAttribute("lastPageIndex");
}

  // These JAVA variables define what is "too few" and what is "too many" records
  // on the page, so we can avoid using (a) page init masks unnecessarily when
  // there are very few records needing special widgets and (b) there are too
  // many records to use special widgets and we'll use our less convenient backup.
  // - these are ALSO made available in the JavaScript
  // - the editMenuBtn.widget.js file assumes these are available to it
  // - this allows coordination between: JSP, HTML page, widget.js file
  int tooFewForMenuBtn = 29 ;
  int tooManyForMenuBtn = 150 ;
%>
<%@ include file="include/cancelHandler.incl" %>
<%@ include file="include/multipage.incl" %>
<HTML>
<head>
  <title>Genboree - Show Annotation Text and Sequence</title>
  <meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
  <!-- Load the page-init mask CSS first -->
  <link rel="stylesheet" href="/javaScripts/extjs/resources/css/loading-genboree.css<%=jsVersion%>" type="text/css">
  <!-- Expose the tooFew/tooMany settings asap in the page. -->
  <script type="text/javascript">
    tooFewForMenuBtn = <%= tooFewForMenuBtn %> ;
    tooManyForMenuBtn = <%= tooManyForMenuBtn %> ;
  </script>
</head>
<BODY>

<%
  // We only mask IF the number of records to appear on the page is:
  // (a) more than a trivial amount (tooFew)
  // (b) less than a crazy huge ammount (tooMany) <-- in this case we'll use our "plan b" UI widget anyway
  if(annotations != null && annotations.length >= tooFewForMenuBtn && annotations.length <= tooManyForMenuBtn) // Then let's us a mask. Else not needed or too many anyway and we do something else
  {
%>
    <!-- PAGE LOADING MASK -->
    <div id="genboree-loading-mask" name="genboree-loading-mask" style="width:100%;height:100%;background:#e1c4ff;opacity:0.5;position:absolute;z-index:20000;left:0px;top:0px;">
      &#160;
    </div>
    <div id="genboree-loading" name="genboree-loading">
      <div class="genboree-loading-indicator">
        <img src="/javaScripts/extjs/resources/images/default/grid/loading.gif" style="width:16px; height:16px;" align="absmiddle">
         &#160;Initializing Page...
      </div>
    </div>
    <!-- include EVERYTHING ELSE after the loading indicator -->
<%
  }
%>

  <!-- BEGIN: Extjs: Split Button Support -->
  <script type="text/javascript" src="/javaScripts/extjs/adapter/prototype/prototype.js<%=jsVersion%>"></script> <!-- Stuff here used in rest of files... -->
  <script type="text/javascript" src="/javaScripts/extjs/adapter/prototype/scriptaculous.js<%=jsVersion%>"></script> <!-- Stuff here used in rest of files... -->
  <script type="text/javascript" src="/javaScripts/extjs/adapter/prototype/ext-prototype-adapter.js<%=jsVersion%>"></script> <!-- Stuff here used in rest of files... -->
  <script type="text/javascript" src="/javaScripts/extjs/package/genboree/ext-menuBtn-only-pkg.js<%=jsVersion%>"></script>
  <link rel="stylesheet" type="text/css" href="/javaScripts/extjs/resources/css/menu.css<%=jsVersion%>">
  <link rel="stylesheet" type="text/css" href="/javaScripts/extjs/resources/css/button.css<%=jsVersion%>">
  <link rel="stylesheet" type="text/css" href="/javaScripts/extjs/resources/css/qtips.css<%=jsVersion%>">
  <link rel="stylesheet" type="text/css" href="/javaScripts/extjs/resources/css/core.css<%=jsVersion%>">
  <link rel="stylesheet" type="text/css" href="/javaScripts/extjs/resources/css/reset-min.css<%=jsVersion%>">
  <link rel="stylesheet" type="text/css" href="/javaScripts/extjs/resources/css/ytheme-genboree.css<%=jsVersion%>">
  <!-- Set a local "blank" image file; default is a URL to extjs.com -->
  <script type='text/javascript'>
    Ext.BLANK_IMAGE_URL = '/javaScripts/extjs/resources/images/genboree/s.gif';
  </script>
  <!-- END -->

  <!-- BEGIN: Genboree Specific -->
  <script type="text/javascript" src="/javaScripts/util.js<%=jsVersion%>"></script> <!-- Stuff here used in rest of files... -->
  <script type="text/javascript" SRC="/javaScripts/editorCommon.js<%=jsVersion%>"></script>
  <script type="text/javascript" SRC="/javaScripts/showtext.js<%=jsVersion%>"></script>
  <script type="text/javascript" SRC="/javaScripts/editMenuBtn.widget.js<%=jsVersion%>"></script>
  <link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
  <link rel="stylesheet" href="/styles/avp.css<%=jsVersion%>" type="text/css">
  <link rel="stylesheet" href="/styles/querytool.css<%=jsVersion%>" type="text/css">
  <link rel="stylesheet" href="/styles/annotationEditor.css<%=jsVersion%>" type="text/css">
  <!-- END -->

  <style rel="stylesheet" type="text/css">
    /* Shows the image next to the button value */
    .x-btn-text-icon .x-btn-center .x-btn-text
    {
      background-image:url(/images/silk/application_form_edit.png) ;
    }
  </style>

<%@ include file="include/header.incl" %>

<form name="<%=formId%>" id="<%=formId%>" action="showAllAnotations.jsp?upfid=<%=uploadId%>:<%=fidParam%>" method="post"  >
    <input type="hidden" name="okDeleteSel" id="okDeleteSel" value="<%=state%>" >
    <input type="hidden" name='selectAllAnnos' id='selectAllAnnos' value="false" >
    <input type="hidden" name="currentPage" id="currentPage" value="<%=currentPage%>">
    <input type="hidden" name="navigator" id="navigator" value="home">
    <input type="hidden" name="cancelState" id="cancelState" value="0">
    <input type="hidden" name="changed" id="changed" value="<%=changed%>">
    <table width="100%" border="0" cellpadding="2" cellspacing="2">
<%
  if( !trackBlocked )
  {
%>
    <tr align="center">
    <td>
    <CENTER><FONT SIZE="4"><B>Annotation Details</B></FONT></CENTER>
    <BR>
    <TABLE  CELLPADDING="0" CELLSPACING="0" BORDER="1">
    <TR align="center">
    <td class="annotation2">
    <input type="button" style="margin-right:100px" class="btn" onClick="window.close(); " value="Close Window" name="closebtn" >
    &nbsp; &nbsp;   &nbsp; &nbsp;   &nbsp; &nbsp;
    </td> <td class="annotation2"><INPUT SIZE="14" id="commentFormatBtn" name="commentFormatBtn"   TYPE="button" class="btn" onclick="dispatchWrapComments('commentContent', document.getElementById('commentDelims').value);" VALUE="Wrap Comments">
    &nbsp; &nbsp;   &nbsp; &nbsp;
    Wrap delimiters:&nbsp;<INPUT SIZE="2" id="commentDelims" name="commentDelims" TYPE="text" VALUE=";">
    </TD>
    </tr>
    </TABLE>
    </td>
    </tr>
    </table>
    <TABLE width="100%" border="0" cellpadding="2" cellspacing="2">
    <%@ include file="include/mp_pageIndex.incl" %>
    </table>
<%

  if (annotations != null)
  {
    for ( i=0; i<annotations.length;  i++)
    {
      String commentsid ="comments_" + i ;
      AnnotationDetail anno = annotations[i];
      long sLen = anno.getStop() - anno.getStart();
      orderNum = (String )fid2AnnoNums.get("" + anno.getFid());
      String fid = "" + anno.getFid();
%>
      <script type="text/javascript">
        Ext.genboree.addRecord(<%=uploadId%>, <%=fid%>) ;
      </script>
<%
      //  out.println(" fid = " + fid );
      if (con == null || con.isClosed())
        con = db.getConnection(dbName);
      if (con == null)
      {
          System.err.println ("database connection error in showAllAnnotation.jsp");
          return;

      }
      HashMap name2Values = new HashMap ();
      int currentIndex = 0;
 %>

 <%@ include file="include/avpPopulator.incl" %>

         <table BGCOLOR="navy" width="100%" border="0" cellpadding="0" cellspacing="1">
          <TR align="center">
          <TD>
            <!-- TOP ROW TABLE: Has the larger-font annotation and group name. -->
            <!-- Cellpadding & spacing are deliberate -->
            <table width="100%" border="0" cellpadding="2" cellspacing="1">
            <tr >
              <TD BGCOLOR="white" class="form_body">
                <FONT SIZE="2">&nbsp;<%=orderNum%>&nbsp;</FONT><!-- Group name not bold (separate in case someday we discriminate name from group -->
              </TD>
              <TD WIDTH="20%" class="form_body">
                <FONT SIZE="2"><B>Annotation Name:</B></FONT>
              </TD>
              <TD BGCOLOR="white" WIDTH="30%">
                <FONT SIZE="2">&nbsp;<B>
                       <%=annotations[i].getGname()  %>    </B></FONT><!-- Real name in bold --> </TD>
              <TD WIDTH="15%" class="form_body">
                <FONT SIZE="2"><B>Group Name:</B></FONT>
              </TD>
              <TD BGCOLOR="white" WIDTH="30%">
                <div style="float: left; width: auto; margin-right: auto; margin-left: 0px;">
                  <FONT SIZE="2">&nbsp;<%=annotations[i].getGname() %></FONT><!-- Group name not bold (separate in case someday we discriminate name from group -->
                </div>
                <div style="float:right; border-left: 2px solid navy; background: #d3cfe6; width: auto; padding: 2px; margin-left:auto; margin-right: 0px;">
<%
                  if(validFid) // this user is allowed to edit
                  {
                    if(annotations.length >= tooManyForMenuBtn) // too many records on page for all to have buttons
                    {
%>
                      <a href="/java-bin/annotationEditorMenu.jsp?upfid=<%=uploadId%>:<%=fid%>" style="color: darkorchid;">Edit Menu</a>
<%
                    }
                    else
                    {
%>
                      <div id="editBtnDiv_<%=i%>" name="editBtnDiv_<%=i%>" class='editBtnDiv'></div>
<%
                    }
                  }
                  else // this user is not allowed to edit
                  {
%>
                    &nbsp;
<%
                  }
%>
                </div>
              </TD>
            </TR>
            </TABLE>
          </TD>
          </TR>
          <TR>
          <TD>
            <!-- DETAILS TABLE: Has all the details of the annotation -->
            <table width="100%" border="0" cellpadding="2" cellspacing="1">
            <TR >
              <TD ALIGN="right" class="form_body" WIDTH="15%"><B>Location:</B></TD>
              <!-- ENTRYPOINT : START - STOP -->
              <TD class="form_body" >&nbsp;<%=chrName%> : <%=anno.getFstart()%> - <%=anno.getFstop()%></TD>
              <!-- Note the &nbsp; before each value -->
            </TR>
            <TR>
              <TD ALIGN="right" class="form_body" WIDTH="10%"><B>Strand:</B></TD>
              <!-- STRAND -->
              <!-- Put 'n/a' if Strand is null -->
              <TD class="form_body">&nbsp;<%=anno.getStrand() %> </TD>
            </TR>
            <TR>
              <TD ALIGN="right" class="form_body" WIDTH="10%"><B>Phase:</B></TD>
              <!-- STRAND -->
              <!-- Put 'n/a' if Strand is null -->
              <TD class="form_body">&nbsp;<%=anno.getPhase() %> </TD>
            </TR>
            <TR>
              <TD ALIGN="right" class="form_body" WIDTH="15%"><B>Class:</B></TD>
              <!-- CLASS -->
              <TD class="form_body">&nbsp;<%=Util.htmlQuote(gclass) %></TD>
            </TR>
            <TR>
              <TD ALIGN="right" class="form_body" WIDTH="10%"><B>Track:</B></TD>
              <!-- TRACKNAME -->
              <TD class="form_body">&nbsp;<%=trackName%></TD>
            </TR>
            <TR>
              <TD ALIGN="right" class="form_body" WIDTH="15%"><B>Length:</B></TD>
              <!-- LENGTH -->
              <TD class="form_body">&nbsp;<%=sLen%></TD>
            </TR>
            <TR>
              <TD ALIGN="right" class="form_body" WIDTH="15%"><B>Target Start:</B></TD>
              <!-- Target Start -->
              <TD class="form_body">&nbsp;<%=anno.getTstart()%></TD>
            </TR>
                <TR>
                <TD ALIGN="right" class="form_body" WIDTH="15%"><B>Target Stop:</B></TD>
                <!-- Target Stop -->
                <TD class="form_body">&nbsp;<%=anno.getTstop()%></TD>
                </TR>
            <TR>
              <TD ALIGN="right" class="form_body" WIDTH="10%"><B>Score:</B></TD>
              <!-- SCORE -->
              <TD class="form_body">&nbsp;<%=anno.getScore()%></TD>
            </TR>

               <%@ include file="include/smallAVP.incl"%>

            <TR>
              <TD VALIGN="top" ALIGN="right" class="form_body"><B>Free-Form Comments:</B></TD>
              <!-- COMMENTS: the value has a *white* background, like the name/group name. This is on purpose. -->
              <!-- NOTE: at the end of the value there is always a <BR>&nbsp; -->
              <!-- If there is no comment, only put the &nbsp; as shown in annotation #2 -->
              <TD BGCOLOR="white"><SPAN name='commentContent' id='commentContent'>
                    <% if(anno.getComments() == null)
                         out.println("n/a");
                       else out.println(anno.getComments());
                     %></SPAN><BR>&nbsp;</TD>
            </TR>

            <TR>
              <TD VALIGN="top" ALIGN="right" class="form_body"><B>Sequence:</B></TD>
              <!-- SEQURENCE: the value has a *white* background, like the name/group name. This is on purpose. -->
              <!-- NOTE: at the end of the value there is always a <BR>&nbsp; -->
              <!-- If there is no comment, only put the &nbsp; as shown in annotation #2 -->
              <TD BGCOLOR="white"><SPAN name='sequenceContent' id='sequenceContent'>
                      <% if(anno.getSequences() == null)
                        out.println("n/a");
                    else out.println(anno.getSequences());
                     %></SPAN><BR>&nbsp;</TD>
            </TR>
            </TABLE>
          </TD>
          </TR>
          </TABLE>
            <P>&nbsp;<BR>
<%
    }
  }
%>
<TABLE width="100%" border="0" cellpadding="2" cellspacing="2">
<%@ include file="include/multipageEditorBottom.incl" %>
</table>
<%
  }
  else
  {
%>
    <tr>
      <td style="padding-top: 20px; text-align: center; color: red; font-size: 80%; font-weight: bold; font-style: italic; width: 100%;">
        To protect sensitive data (e.g. patient data, pre-publication raw data, etc), the detailed
        annotation views and downloads for this track have been blocked.
      </td>
    </tr>
<%
  }
%>
</table>
</form>
<%@ include file="include/footer.incl" %>
</BODY>
</HTML>
