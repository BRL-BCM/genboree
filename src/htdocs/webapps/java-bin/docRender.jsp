<%// GENBOREE ARBITRARY CONTENT WRAPPER *TEMPLATE*
  // - Use a *copy* of this template to wrap arbitrary HTML within Genboree,
  //   including session management and group-based access control.
%>
<%!
    // --------------------------------------------------------------------------
    // TEMPLATE CONFIGURATION
    // --------------------------------------------------------------------------
    // 1) Specify the file that has the content. Probably some sort of .incl file.
    //    EX: helpFile = "help/entrypointUpload.incl" ;
    String helpFile = null;
    // 2) If autoExternalPage, then specify the title for the page, else put empty string.
    String pageTitle = "Clingen Calculator";

    // --------------------------------------------------------------------------
    // TEMPLATE VARIABLES
    // --------------------------------------------------------------------------
    String[] userInfo = new String[3] ;
    HttpSession mys = null ;


%>
<%@ include file="help/staticHelp.incl" %>
<%@ include file="include/fwdurl.incl" %>

  


  <%
    Enumeration paramNames = request.getParameterNames() ;
    final String underlyingPage = "/clingenInference/V2.5/docRender.rhtml";
    String pageTitle = "ClinGenGrid" ;
    // Key variables:
    String urlStr = null ;
    boolean doHtmlStripping = true ;
    String contentUrl = null ; // String to store the entire content of an URL using getContentOfUrl(urlStr )
    String refSeqId = null ; // Not needed here, but staticContent.incl expects the variable
    String currPageURI = request.getRequestURI() ;
    String groupAllowed = null ;
    // REBUILD the request params we will pass to RHTML side (via a POST)
    Map paramMap = request.getParameterMap() ; // "key"=>String[]
    StringBuffer postContentBuff = new StringBuffer() ;

    // 1.b Loop over request key-value pairs, append them to rhtml request:
    Iterator paramIter = paramMap.entrySet().iterator() ;
    while(paramIter.hasNext())
    {
      Map.Entry paramPair = (Map.Entry) paramIter.next() ;
      String pName = Util.urlEncode((String) paramPair.getKey()) ;
      String[] pValues = (String[]) paramPair.getValue() ; // <-- Array!
      if(pValues != null)
      { // then there is 1+ actual values
        for(int ii = 0; ii < pValues.length; ii++)
        { // Add all of the values to the POST
          postContentBuff.append("&").append(pName).append("=").append(URLEncoder.encode(pValues[ii], "UTF-8")) ;
          System.out.println(pValues[ii]);
        }
      }
      else // no value, just a key? ok...
      {
        postContentBuff.append("&").append(pName).append("=") ;
      }
    }

    String postContentStr = postContentBuff.toString() ;
    String uriPath = request.getRequestURI().replaceAll("/[^/]+\\.jsp.*$", "") ;
    urlStr = myBase + underlyingPage ;


    if(urlStr != null)
    {
      HashMap hdrsMap = new HashMap() ;
      //contentUrl = GenboreeUtils.getContentOfUrl(urlStr, doHtmlStripping, hdrsMap, mys);
      contentUrl = GenboreeUtils.postToURL(urlStr, postContentStr, doHtmlStripping, hdrsMap, mys ) ;
      
      // Extract & Apply some key response headers from the upstream server, if available
      // -- hdrsMap is a: HashMap<String, List<String>>
      // -- So there is some java casting to do here.
      List contentTypeList = (List)hdrsMap.get("Content-Type") ;
      if(contentTypeList != null && !contentTypeList.isEmpty())
      {
        response.setContentType((String)contentTypeList.get(0)) ;
      }
      List dispositionList = (List)hdrsMap.get("Content-Disposition") ;
      if(dispositionList != null && !dispositionList.isEmpty())
      {
        response.setHeader("Content-Disposition", (String)dispositionList.get(0)) ;
      }     
       
      // write out the content
      out.write(contentUrl) ;
    }

 %>
