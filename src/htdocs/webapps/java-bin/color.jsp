<%@ page import="java.io.*, javax.servlet.*, javax.servlet.http.*, org.genboree.util.Util,
                 org.genboree.util.ColorBox"%>
<%
    String str = request.getParameter( "c" );


    byte[] buf = ColorBox.returnImage(str);

    response.setContentType( "image/gif" );
    ServletOutputStream servletOutStream = response.getOutputStream();
    response.setHeader( "Content-Disposition", "inline; filename=\"colorbox.gif\"" );
    servletOutStream.write( buf );
    servletOutStream.flush();
    servletOutStream.close();
  %>
