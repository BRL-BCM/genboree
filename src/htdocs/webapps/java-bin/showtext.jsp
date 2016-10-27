<%@ page import="javax.servlet.http.*, java.util.*, java.text.*, java.math.*,java.sql.*, java.io.*,
  org.genboree.dbaccess.*, org.genboree.dbaccess.util.*, org.genboree.util.*, org.genboree.upload.*, org.genboree.editor.AnnotationEditorHelper" %>

<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%
  int i;
  HashMap name2Values = new HashMap ();
  String textid = request.getParameter("upfid");
  String[] ss = null;
  if( textid != null )
  {
    ss = Util.parseString(textid,',');
  }
  else
  {
    ss = new String[0];
  }
  Hashtable htUpl = new Hashtable();
  Vector v = new Vector();

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
<HTML>
<head>
  <meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
  <title>Genboree - Show Annotation Text and Sequence</title>
  <!-- Load the page-init mask CSS first -->
  <link rel="stylesheet" href="/javaScripts/extjs/resources/css/loading-genboree.css<%=jsVersion%>" type="text/css">
  <!-- Expose the tooFew/tooMany settings asap in the page. -->
  <script type="text/javascript">
    tooFewForMenuBtn = <%= tooFewForMenuBtn %> ;
    tooManyForMenuBtn = <%= tooManyForMenuBtn %> ;
  </script>
</head>
<BODY >

<%
  // We only mask IF the number of records to appear on the page is:
  // (a) more than a trivial amount (tooFew)
  // (b) less than a crazy huge ammount (tooMany) <-- in this case we'll use our "plan b" UI widget anyway
  if(ss.length >= tooFewForMenuBtn && ss.length <= tooManyForMenuBtn) // Then let's us a mask. Else not needed or too many anyway and we do something else
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
  <script type="text/javascript" SRC="/javaScripts/showtext.js<%=jsVersion%>"></script>
  <script type="text/javascript" SRC="/javaScripts/editMenuBtn.widget.js<%=jsVersion%>"></script>
  <link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
  <link rel="stylesheet" href="/styles/avp.css<%=jsVersion%>" type="text/css">
  <LINK rel="stylesheet" href="/styles/querytool.css<%=jsVersion%>" type="text/css">
  <link rel="stylesheet" href="/styles/annotationEditor.css<%=jsVersion%>" type="text/css">
  <!-- END -->

  <style rel="stylesheet" type="text/css">
    /* Shows the image next to the button value */
    .x-btn-text-icon .x-btn-center .x-btn-text
    {
      background-image:url(/images/silk/application_form_edit.gif) ;
    }
  </style>

  <%@ include file="include/header.incl" %>

<%
    // Loop over each of our annotations.
    // - as we go through them use Ext.genboree.addRecord() to add them to a
    //   global JavaScript variable (set up in editMenuBtn.widget.js)
    byte[] b = new byte[70];
    int currentIndex = 0;
    for( i=0; i<ss.length; i++ )
    {
      textid = ss[i];
      String[] sss = Util.parseString( textid, ':' );
      if( sss.length < 2 )
      {
        continue ;
      }
      String uploadId = sss[0];
      String fid = sss[1];
%>
      <script type="text/javascript">
        Ext.genboree.addRecord(<%=uploadId%>, <%=fid%>) ;
      </script>
<%
      GenboreeUpload u = (GenboreeUpload) htUpl.get( uploadId );
      if( u == null )
      {
        u = new GenboreeUpload();
        u.setUploadId( Util.parseInt(uploadId,-1) );
        u.fetch( db );
        htUpl.put( uploadId, u );
      }
      String aText = null;
      String aSeq = null;
      String fstart = null;
      String fstop = null;
      String ftargetStartString = null;
      String ftargetStopString = null;
      long ftargetStart = 0;
      long ftargetStop = 0;
      String fscore = null;
      String fstrand = "n/a";
      String gname = null;
      String gclass = null;
      String fmethod = null;
      String fsource = null;
      String typeId = null;
      double dScore = 0.0;
      String chrName = null;
      long len = 0;
      StringBuffer tempGclass = null;
      String sLen = null;
      boolean validFid = false ;
      boolean trackBlocked = false ;
      String query1 = "SELECT fd.fstart fstart, fd.fstop fstop, fd.fscore fscore, " +
                      "fd.fstrand fstrand, fd.gname gname, ft.fmethod fmethod, ft.fsource fsource, " +
                      "ft.ftypeid ftypeid, fr.refname ref, " +
                      "fd.ftarget_start ftarget_start, fd.ftarget_stop ftarget_stop FROM " +
                      "fdata2 fd, ftype ft, fref fr WHERE fd.ftypeid=ft.ftypeid AND " +
                      "fd.rid = fr.rid AND fd.fid=" + fid;

      String query3 = "SELECT gclass.gclass gclassName FROM gclass, ftype2gclass WHERE " +
                      "gclass.gid = ftype2gclass.gid and ftype2gclass.ftypeid = ";

      try
      {
        Connection con = db.getConnection(u.getDatabaseName()) ;
        // First, are we even allowed to see the details of this annotation?
        // If the track download is blocked, we cannot show details.
        trackBlocked = FtypeTable.isAnnoDownloadBlocked(con, fid) ;
        if( !trackBlocked )
        {
          DbResourceSet dbRes =  db.executeQuery( u.getDatabaseName(),query1);
          ResultSet rs = dbRes.resultSet;
          if( JSPErrorHandler.checkErrors(request,response, db,mys) )
          {
            dbRes.close();
            return;
          }

          // See if user has ability to Edit this fid in this upload
          Connection mainCon = db.getConnection();
          if (con == null || con.isClosed() || mainCon== null || mainCon.isClosed())
          {
            GenboreeUtils.sendRedirect(request,response, "/java-bin/error.jsp");
          }
          if(u != null && (request.getParameter("upfid") != null)  )
          {
            validFid =  AnnotationEditorHelper.verifyUploadIdAndFid(iUserId, Integer.parseInt(uploadId), Integer.parseInt(fid), u, mainCon, con) ;
          }
          System.err.println("showtext.jsp => validFid: " + validFid) ;
          if( rs!=null && rs.next() )
          {
            fstart = rs.getString("fstart");
            fstop = rs.getString("fstop");
            dScore = rs.getDouble("fscore");
            if(rs.getString("fstrand") != null)
            {
              fstrand = rs.getString("fstrand");
            }
            gname = rs.getString("gname");
            fmethod = rs.getString("fmethod");
            fsource = rs.getString("fsource");
            chrName = rs.getString("ref");
            ftargetStart = rs.getLong("ftarget_start");
            ftargetStop = rs.getLong("ftarget_stop");
            typeId = rs.getString("ftypeid");

            len = Util.parseLong(fstop,0L) - Util.parseLong(fstart,0L) + 1L;

            NumberFormat formatter = new DecimalFormat("0.#####");
            fscore = formatter.format(dScore);

            sLen = Util.putCommas("" + len);
            fstart = Util.putCommas("" + fstart);
            fstop = Util.putCommas("" + fstop);
            if(ftargetStart == 0)
            {
              ftargetStartString = "n/a";
            }
            else
            {
              ftargetStartString = Util.putCommas("" + ftargetStart);
            }

            if(ftargetStop == 0)
            {
              ftargetStopString = "n/a";
            }
            else
            {
              ftargetStopString = Util.putCommas(""+ftargetStop);
            }
          }

          query3 += typeId;
          dbRes =  db.executeQuery( u.getDatabaseName(),query3 );
          rs = dbRes.resultSet;
          if( JSPErrorHandler.checkErrors(request,response, db,mys) )
          {
            dbRes.close();
            return;
          }

          if(rs == null)
          {
            dbRes.close();
            gclass = "UnAssigned";
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
          }
          dbRes.close();
          dbRes = db.executeQuery( u.getDatabaseName(), "SELECT textType, text FROM fidText WHERE fid=" + fid );
          rs = dbRes.resultSet;
          while( rs.next() )
          {
            String tt = rs.getString(1);
            if( tt.equals("t") )
            {
              aText = rs.getString(2);
            }
            else
            {
              InputStream bIn = rs.getAsciiStream(2);
              int n = bIn.read( b );
              while( n > 0 )
              {
                if( aSeq == null )
                {
                  aSeq = "";
                }
                aSeq = aSeq + (new String(b,0,n)) + "<br>\r\n";
                n = bIn.read( b );
              }
            }
          }
          dbRes.close();
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

      Connection con = null;
      con = db.getConnection(u.getDatabaseName());

%>

<%@ include file="include/avpPopulator.incl" %>

    <!-- ----------------------------------------------------------------------- -->
    <!-- START OF PAGE CONTENT -->
    <!-- ----------------------------------------------------------------------- -->
    <table width="100%" border="0" cellpadding="2" cellspacing="2">
<%
      if(!trackBlocked)
      {
%>
      <tr>
        <td>
          <p>&nbsp;
          <CENTER><FONT SIZE="4"><B>Annotation Details</B></FONT></CENTER>
          <P>
          <TABLE CELLPADDING="0" CELLSPACING="0" BORDER="0">
          <TR>
            <TD>
              <INPUT SIZE="14" id="commentFormatBtn" name="commentFormatBtn" TYPE="button" class="btn" onclick="dispatchWrapComments('commentContent', $('commentDelims').value);" VALUE="Wrap Comments">
            </TD>
            <TD>
              &nbsp;&nbsp;&nbsp;&nbsp;
            </TD>
            <TD>
              Wrap delimiters:&nbsp;<INPUT SIZE="2" id="commentDelims" name="commentDelims" TYPE="text" VALUE=";">
            </TD>
          </TR>
          </TABLE>
          <!-- ----------------------------------------------------------------------- -->
          <!-- START ANNOTATION #1 -->
          <!-- ----------------------------------------------------------------------- -->
          <!-- 'BORDERS' PROVIDED BY THIS WRAPPER TABLE and the BGCOLOR PROPERTY--REGULAR BORDERS LOOK BAD IN I.E. OR FIREFOX, DEPENDING -->
          <table BGCOLOR="navy" width="100%" border="0" cellpadding="0" cellspacing="1">
          <TR>
            <TD>
              <!-- TOP ROW TABLE: Has the larger-font annotation and group name. -->
              <!-- Cellpadding & spacing are deliberate -->
              <table width="100%" border="0" cellpadding="2" cellspacing="1">
              <tr>
                <TD WIDTH="20%" class="form_body">
                    <FONT SIZE="2"><B>Annotation Name:</B></FONT>
                </TD>
                <TD BGCOLOR="white" WIDTH="30%">
                    <FONT SIZE="2">&nbsp;<B>
                    <%=gname %></B></FONT><!-- Real name in bold --> </TD>
                <TD WIDTH="15%" class="form_body">
                    <FONT SIZE="2"><B>Group Name:</B></FONT>
                </TD>
                <TD BGCOLOR="white" WIDTH="30%">
                  <div style="float: left; width: auto; margin-right: auto; margin-left: 0px;">
                    <FONT SIZE="2">&nbsp;<%=gname %></FONT><!-- Group name not bold (separate in case someday we discriminate name from group -->
                  </div>
                  <div style="float:right; border-left: 2px solid navy; background: #d3cfe6; width: auto; padding: 2px; margin-left:auto; margin-right: 0px;">
<%
                    if(validFid) // this user is allowed to edit
                    {
                      if(ss.length >= tooManyForMenuBtn) // too many records on page for all to have buttons, use plan b.
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
              </table>
            </TD>
          </TR>
          <TR>
            <TD>
              <!-- DETAILS TABLE: Has all the details of the annotation -->
              <!-- Note the &nbsp; before each value -->
              <table width="100%" border="0" cellpadding="2" cellspacing="1">
              <TR>
                <TD ALIGN="right" class="form_body" WIDTH="15%">
                  <B>Location:</B>
                </TD>
                <!-- ENTRYPOINT : START - STOP -->
                <td class="form_body">
                  &nbsp;<%=chrName %> : <%=fstart%> - <%=fstop%>
                </td>
              </TR>
              <TR>
                <TD ALIGN="right" class="form_body" WIDTH="10%"><B>Strand:</B></TD>
                <!-- STRAND -->
                <!-- Put 'n/a' if Strand is null -->
                <TD class="form_body">&nbsp;<%=fstrand %> </TD>
              </TR>
              <TR>
                <TD ALIGN="right" class="form_body" WIDTH="15%"><B>Class:</B></TD>
                <!-- CLASS -->
                <TD class="form_body">&nbsp;<%=Util.htmlQuote(gclass) %></TD>
              </TR>
              <TR>
                <TD ALIGN="right" class="form_body" WIDTH="10%"><B>Track:</B></TD>
                <!-- TRACKNAME -->
                <TD class="form_body">&nbsp;<%=fmethod%>:<%=fsource%></TD>
              </TR>
              <TR>
                <TD ALIGN="right" class="form_body" WIDTH="15%"><B>Length:</B></TD>
                <!-- LENGTH -->
                <TD class="form_body">&nbsp;<%=sLen%></TD>
              </TR>
              <TR>
                <TD ALIGN="right" class="form_body" WIDTH="15%"><B>Query Start:</B></TD>
                <!-- Query Start -->
                <TD class="form_body">&nbsp;<%=ftargetStartString%></TD>
              </TR>
              <TR>
                <TD ALIGN="right" class="form_body" WIDTH="15%"><B>Query Stop:</B></TD>
                <!-- Query Stop -->
                <TD class="form_body">&nbsp;<%=ftargetStopString%></TD>
              </TR>
              <TR>
                <TD ALIGN="right" class="form_body" WIDTH="10%"><B>Score:</B></TD>
                <!-- SCORE -->
                <TD class="form_body">&nbsp;<%=fscore%></TD>
              </TR>
               <%@ include file="include/smallAVP.incl" %>

              <TR>
                <TD VALIGN="top" ALIGN="right" class="form_body"><B>Free-Form Comments:</B></TD>
                <!-- COMMENTS: the value has a *white* background, like the name/group name. This is on purpose. -->
                <!-- NOTE: at the end of the value there is always a <BR>&nbsp; -->
                <!-- If there is no comment, only put the &nbsp; as shown in annotation #2 -->
                <TD BGCOLOR="white">
                  <SPAN name='commentContent' id='commentContent'>
<%
                  if(aText == null)
                  {
                    out.println("n/a");
                  }
                  else
                  {
                    out.println(aText);
                  }
%>
                  </SPAN><BR>&nbsp;
                </TD>
              </TR>
              <TR>
                <TD VALIGN="top" ALIGN="right" class="form_body"><B>Sequence:</B></TD>
                <!-- SEQURENCE: the value has a *white* background, like the name/group name. This is on purpose. -->
                <!-- NOTE: at the end of the value there is always a <BR>&nbsp; -->
                <!-- If there is no comment, only put the &nbsp; as shown in annotation #2 -->
                <TD BGCOLOR="white">
                  <SPAN name='sequenceContent' id='sequenceContent'>
<%
                  if(aSeq == null)
                  {
                    out.println("n/a");
                  }
                  else
                  {
                    out.println(aSeq);
                  }
%>
                  </SPAN>
                  <BR>&nbsp;
                </TD>
              </TR>
              </TABLE>
            </TD>
          </TR>
          </TABLE>
          <!-- ----------------------------------------------------------------------- -->
          <!-- END ANNOTATION #1 -->
          <!-- ----------------------------------------------------------------------- -->
          <p align="center">&nbsp;</p>
          <input type="button" name="btnClose" id="btnClose" value="Close Window" class="btn" onClick="window.close();">
        </td>
      </tr>
<%
      }
      else // track is blocked for download
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
    }
%>
    </table>
<%@ include file="include/footer.incl" %>
</BODY>
</HTML>
