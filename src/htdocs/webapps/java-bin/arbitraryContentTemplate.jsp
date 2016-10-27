<%// GENBOREE ARBITRARY CONTENT WRAPPER *TEMPLATE*
  // - Use a *copy* of this template to wrap arbitrary HTML within Genboree,
  //   including session management and group-based access control.
%>
<%!
    // --------------------------------------------------------------------------
    // TEMPLATE CONFIGURATION
    // --------------------------------------------------------------------------
    // 1) Assign access limitation: *either* a group-name OR a refSeqId:
    String groupAllowed = "Ion Channel";            // Specify a group name OR
    String refSeqId = null;                         // RefSeqId as a string
    // 2) Specify the external URL that has the content. If you will put the
    //    static content on *this* page itself, make this string null (i.e.
    //    there is NO external URL to go to, this page has everything).
    //    EX: urlStr = myBase + "/java-bin/MyProj/index.rhtml"
    String urlStr = null;
    // 3) If there is an external URL, decide whether you want the content as
    //    a single String object, else you get a Vector of lines.
    boolean singleString = true;
    // 4) Do you want the template to suck in and present your external page
    //    *automatically* for you?? This will allow the template to show the
    //    Genboree logos, the navbar, and the footer. Otherwise, ALL the HTML
    //    will come from the external page (if there is one).
    boolean autoExternalPage = false;
    // 5) If autoExternalPage, then specify the title for the page, else put empty string.
    String pageTitle = "Genboree Arbitrary Content Wrapper TEMPLATE";
    // 6) If autoExternalPage, do you want it to strip the html, head, body, etc
    //    tags that might mess things up a bit?
    boolean doHtmlStripping = true ;
    
    // --------------------------------------------------------------------------
    // TEMPLATE VARIABLES
    // --------------------------------------------------------------------------
    String contentUrl = null;                       // String to store the entire content of an URL using getContentOfUrl(urlStr )
    Vector urlLines = null;                         // Vector to store lines of contentUrl using splitBlockIntoLines(contentUrl);
    Enumeration lineOfUrl = null;                   // Enumeration to loop over the urlLines
%>

<%@ include file="include/staticContent.incl" %>

<% if(urlStr != null && autoExternalPage) {  // (A) We have an external url with content and want to auto-wrap its content
  // ------------------------------------------------------------------------
  // (A) AUTOPROCESS AN EXTERNAL PAGE:
  // ------------------------------------------------------------------------
%>
  <HTML>
  <head>
  <title><%=pageTitle%></title>
  <meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
  <link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css" >
  </head>
  <BODY>      
      <%@ include file="include/header.incl" %>
      <%@ include file="include/navbar.incl" %>
  
  <BR><BR>
  <%  // TEMPLATE: grab the external page and present its contents:
      contentUrl = GenboreeUtils.getContentOfUrl(urlStr, doHtmlStripping );
      
      if(singleString)                // We sucked in the page as a single string
      {
        // Add extra parsing of the String content here, if needed.
        out.write(contentUrl);
      }
      else                            // We have a Vector of lines to loop over...modify if you want...
      {
        urlLines = GenboreeUtils.splitBlockIntoLines(contentUrl);
        for( lineOfUrl = urlLines.elements(); lineOfUrl.hasMoreElements(); )
        {
          String singleLine = (String)lineOfUrl.nextElement();
          // Add extra parsing of the line here, if needed.
          out.println(singleLine);
        }
      }
  %>
  <BR>
  <%@ include file="include/footer.incl" %>
  </BODY>
  </HTML>
<% } else if(urlStr != null) {                  // (B) We have an external url with content but DO NOT want to auto-wrap its content
    // ------------------------------------------------------------------------
    // (B) INCLUDE AN EXTERNAL PAGE, NO GENBOREE STUFF SHOWN:
    // ------------------------------------------------------------------------
    // TEMPLATE: grab the external page and present its contents:
    contentUrl = GenboreeUtils.getContentOfUrl(urlStr, doHtmlStripping );
    
    if(singleString)                // We sucked in the page as a single string
    {
      // Add extra parsing of the String content here, if needed.
      out.write(contentUrl);
    }
    else                            // We have a Vector of lines to loop over...modify if you want...
    {
      urlLines = GenboreeUtils.splitBlockIntoLines(contentUrl);
      for( lineOfUrl = urlLines.elements(); lineOfUrl.hasMoreElements(); )
      {
        String singleLine = (String)lineOfUrl.nextElement();
        // Add extra parsing of the line here, if needed.
        out.println(singleLine);
      }
    }
  } else {                                       // (C) We just have some static HTML below to show
  // ------------------------------------------------------------------------
  // (C) JUST WANT TO SHOW STATIC HTML PROVIDED BELOW
  // ------------------------------------------------------------------------
%>
  <%// You can include or remove the Genboree stuff, as you wish %>
  <HTML>
  <head>
  <title><%=pageTitle%></title>
  <meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
  <link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css" >
  </head>
  <BODY>      
      <%@ include file="include/header.incl" %>
      <%@ include file="include/navbar.incl" %>
  <BR><BR>
  <%// TEMPLATE: Put your content here %>
  
  <B>Put your content here</B>
  
  <BR>
  <%@ include file="include/footer.incl" %>
  </BODY>
  </HTML>
<% } %>
