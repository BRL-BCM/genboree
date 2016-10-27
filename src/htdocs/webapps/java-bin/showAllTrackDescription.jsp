<%@ page import="javax.servlet.http.*, java.util.*, java.sql.*, java.io.*,
  org.genboree.dbaccess.*, org.genboree.util.*, org.genboree.upload.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>

<%
	String uploadId = request.getParameter("uploadId");
    String trackName = request.getParameter("trackName");
	String[] sss = Util.parseString( trackName, ':' );
    String ftypeid = null;
    String url = null;
    String description = null;
    String label = null;
//	if( sss.length < 2 ) continue;
	String fmethod = sss[0];
	String fsource = sss[1];
	GenboreeUpload u = new GenboreeUpload();
	u.setUploadId( Util.parseInt(uploadId,-1) );
	u.fetch( db );
%>
<HTML>
<head>
<title>Genboree - Show Track Description of <%=trackName %></title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY>

<%@ include file="include/header.incl" %>


<%
    DbResourceSet dbRes = null;

		try
		{
            dbRes = db.executeQuery( u.getDatabaseName(), "SELECT ftypeid FROM ftype WHERE  fmethod = '" + fmethod + "' and fsource = '" + fsource + "'");
            ResultSet rs = dbRes.resultSet;

			if( JSPErrorHandler.checkErrors(request,response, db,mys) )
            {
                dbRes.close();
                return;
            }
			
			if( rs!=null && rs.next() )
            {
                ftypeid = rs.getString(1);
                dbRes.close();
            }

            dbRes = db.executeQuery( u.getDatabaseName(), "SELECT url, description, label FROM featureurl WHERE ftypeid="+ftypeid );
            rs = dbRes.resultSet;
            if( JSPErrorHandler.checkErrors(request,response, db,mys) )
            {
                dbRes.close();
                return;
            }

            if( rs!=null && rs.next() )
            {
                url = rs.getString(1);
                description = rs.getString(2);
                label = rs.getString(3);
                dbRes.close();
            }


		} catch( Exception ex00 )
		{
			out.println( ex00.getClass().getName() );
			if( ex00 instanceof SQLException )
			{
				out.println( ((SQLException)ex00).getMessage() );
			}
		}

       String[] ss = Util.parseString( description, '\n' );

       description = null;

        for(int i=0; i<ss.length; i++ )
        {
            String s = ss[i].trim();
            if( description == null ) description = s;
            else description = description + " <br>" + s;
        }

%>
<!-- ----------------------------------------------------------------------- -->
<!-- START OF PAGE CONTENT -->
<!-- ----------------------------------------------------------------------- -->
<table width="100%" border="0" cellpadding="2" cellspacing="2">
<tbody>
<tr>
<td>
<p>&nbsp;
<CENTER><FONT SIZE="4"><B>Track Details of <%=trackName %></B></FONT></CENTER>
<P>
<p>&nbsp;</p>

        	<table BGCOLOR="navy" width="100%" border="0" cellpadding="0" cellspacing="1">
        	<TR>
        	<TD>
        		<table width="100%" border="0" cellpadding="2" cellspacing="1">
        		<tr>
        			<TD class="form_body"   WIDTH="20%" ALIGN="right">
        				<FONT SIZE="2"><B>Track Name:</B></FONT>
        			</TD>
        			<TD BGCOLOR="white" >
        				<FONT SIZE="2">&nbsp;<B>
                        <%=trackName %></B></FONT></TD>
                </tr>
                <tr>
                    <TD class="form_body" WIDTH="20%" ALIGN="right">
                        <FONT SIZE="2"><B>URL:</B></FONT>
                    </TD>
        			<TD BGCOLOR="white">
        				<FONT SIZE="2"><B><A HREF=<%=url%> ><%=label%></A></B></FONT>
        			</TD>
               </tr>
               <tr>
                    <TD colspan="2" class="form_body" Align="center">
                    <FONT SIZE="2"><B>Description:</B></FONT>
                    </TD>
              </tr>
              <tr>
        			<TD BGCOLOR="white" colspan="2">
        				<FONT SIZE="2">&nbsp;<%=description %></FONT><P>&nbsp;
        			</TD>
        		</TR>
        		</TABLE>
        	</TD>
        	</TR>
        	</TABLE>
	<p align="center">&nbsp;</p>
	<input type="button" name="btnClose" id="btnClose" value="Close Window"
	  class="btn" onClick="window.close();">
  </td>
  </tr>
</tbody>
</table>

<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
