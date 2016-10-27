<% /* 
      *DYNAMIC* INCLUDE FILE
      - This include file is used with the dynamic <jsp:include> tag.
      - It must be named with ".jsp" to get properly processed at runtime.
      - NO java variables are shared with the including page, so you need
        to include all the session-setup and standard stuff (see @ includes below)
   */
%>

<%// STANDARD GENBOREE JSP SETUP: %>
<%@ page import="javax.servlet.http.*, java.util.*, java.sql.*, java.io.*,
                 org.genboree.dbaccess.*, org.genboree.util.*, org.genboree.upload.*" %>
<%@ include file="fwdurl.incl" %>
<%@ include file="userinfo.incl" %>

<%// do your page and word and stuff here %>
<%@ include file="navbar.incl" %>
