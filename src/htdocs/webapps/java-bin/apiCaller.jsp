<%@ page import="javax.servlet.http.*, java.util.*, java.sql.*, java.io.*, java.net.*, org.json.*, org.genboree.util.*"%><%@ page import="org.genboree.dbaccess.*, org.genboree.dbaccess.util.*, org.genboree.util.helpers.*, org.genboree.rest.util.*" %><%
  // NO NEWLINES BETWEEN % > and < % on this page! Else JSP engine will feel obligated to
  // emit an out.write("\n") and cause the response output stream to be initialized as a
  // String oriented JspWriter (which is what "out" is)...that's horrible if we want to be outputting
  // binary content [image data say].

  //long startTime = Calendar.getInstance().getTimeInMillis() ;

  // Key variables:
  String urlStr = null ;
  String contentUrl = null ;    // String to store the entire content of an URL using getContentOfUrl(urlStr )
  String refSeqId = null ;      // Not needed here, but staticContent.incl expects the variable
  String currPageURI = request.getRequestURI() ;
  // We need this for staticContent.incl, but really we're going to defer access
  // issues to the RHTML page:
  String groupAllowed = null ;
  // PARAM: the rsrcPath where to make the request
  // This may have the format /REST/... which implies the same host
  // or http://<host>/REST/... which will proxy to <host> using the same username/password
  String rsrcPathParam = request.getParameter("rsrcPath").trim() ;
  String rsrcHost = "" ;
  String rsrcPath = null ;
  String rsrcScheme = null ;
  Integer rsrcPort = null ;
  // If path includes host break up the path
  try
  {
    URL rsrcURL = new URL(rsrcPathParam) ;
    rsrcHost = rsrcURL.getHost() ;
    rsrcPath = rsrcURL.getFile() ;
    rsrcScheme = rsrcURL.getProtocol() ;
    rsrcPort =  rsrcURL.getPort() ;
    System.err.println("rsrcPort: "+rsrcPort) ;
    if(rsrcScheme == null){
      rsrcScheme = "http" ;
    }
  }
  catch(Exception e)
  {
    // rsrcPath has format /REST/...
    rsrcPath = rsrcPathParam ;
  }
  // PARAM: rsrcParams, given separately
  String rsrcParams = request.getParameter("rsrcParams") ;

  if(rsrcParams == null)
  {
    rsrcParams = "" ;
  }
  else
  {
    rsrcParams = rsrcParams.trim() ;
  }
  // PARAM: method to use for API request
  // Note: used to be "method" but some javascript libraries don't allow that to be easily used.
  // We decided on "apiMethod" here and for the POST-with-override technique. Safer than _method too.
  String method = request.getParameter("apiMethod") ;
  if(method == null)
  {
    method = "GET" ;
  }
  else
  {
    method = method.trim().toUpperCase() ;
  }
  // PARAM: gbKey to use, if any
  String gbKey = request.getParameter("gbKey") ;
  if(gbKey == null)
  {
    gbKey = request.getParameter("context") ;
  }
  // PARAM: promptForLogin to get it to do the whole redirect to a login page thing (for browser usage, not Ajax)
  // - one use of this is for URLs that link to files for download
  boolean promptForLogin = false ;
  String promptForLoginStr = request.getParameter("promptForLogin") ;
  if(promptForLoginStr != null && (promptForLoginStr.equalsIgnoreCase("true") || promptForLoginStr.equalsIgnoreCase("yes")))
  {
    promptForLogin = true ;
  }

  // PARAM: use binary mode and don't treat response as a String
  boolean useBinMode = false ;
  String binMode = request.getParameter("binMode") ;
  if(binMode != null && (binMode.equalsIgnoreCase("true") || binMode.equalsIgnoreCase("yes")))
  {
    useBinMode = true ;
  }

  // PARAM: Can specify an error format for communicating/passing forward errors.
  // - 'original' passes error response through from the call, as is.
  // - 'html' shows some static html content for certain known errors
  String errorFormat = "original" ;
  String errorFormatStr = request.getParameter("errorFormat") ;
  if(errorFormatStr != null)
  {
    errorFormat = errorFormatStr.toLowerCase() ;
  }

  // PARAM: should we pass along the error response body (usually error JSON text or similar)
  // from the API when an API error response is received. Usually we do want this, so Ajax code
  // can process and display appropriate info. BUT for some uses, like when asking for binary
  // image data within the "src" URL of an <img> tag, we don't want the text...it will be
  // processed as incorrect image data.
  boolean errorRespTextOk = true ;
  String errorRespTextOkStr = request.getParameter("errorRespTextOk") ;
  if(errorRespTextOkStr != null && (errorRespTextOkStr.equalsIgnoreCase("false") || errorRespTextOkStr.equalsIgnoreCase("no")))
  {
    errorRespTextOk = false ;
  }

  // PARAM: file download
  boolean fileDownload = false ;
  String fileDownloadStr = request.getParameter("fileDownload") ;
  if(fileDownloadStr != null && (fileDownloadStr.equalsIgnoreCase("true") || fileDownloadStr.equalsIgnoreCase("yes")))
  {
    useBinMode = true ;
    fileDownload = true ;
  }
  // PARAM: track download (as a file)
  boolean trkDownload = false ;
  String trkDownloadStr = request.getParameter("trkDownload") ;
  String trkFormat = "" ;
  if(trkDownloadStr != null && (trkDownloadStr.equalsIgnoreCase("true") || trkDownloadStr.equalsIgnoreCase("yes")))
  {
    useBinMode = true ;
    trkDownload = true ;
    // Get the format as well
    trkFormat = request.getParameter("trkFormat") ;
  }
	// PARAM: Job Summary download (as a tab-delimited file)
	boolean jobSummary = false ;
  String jobSummaryStr = request.getParameter("jobSummary") ;
  if(jobSummaryStr != null && (jobSummaryStr.equalsIgnoreCase("true") || jobSummaryStr.equalsIgnoreCase("yes")))
  {
    useBinMode = true ;
    jobSummary = true ;
  }

  // --------------------------------------------------------------------------
  // INIT KEY GENBOREE SESSION & OBJECTS
  // - We are going to try to avoid using an .incl file and all the .incl it
  //   would then bring in (common.incl, fwdurl.incl, userinfo.incl, staticContent.incl)
  // - We only need a few key things.
  // --------------------------------------------------------------------------
  // A) The Session
  HttpSession mys = request.getSession() ;
  // B) A DBAgent instance
  DBAgent db = DBAgent.getInstance() ;
  // C) Host name of original request
  String hostName = request.getHeader("host") ;
  String origHostName = hostName ;
  // We might be proxying the request to a different host
  boolean proxying = false ;
  if(!rsrcHost.equals(""))
  {
    hostName = rsrcHost ;
    if(!origHostName.equalsIgnoreCase(rsrcHost))
    {
      // System.err.println("PROXYING --------------> TRUE! rsrcHost: " + rsrcHost + " ; hostName: " + hostName + " ; origHostName: " + origHostName) ;
      proxying = true ;
    }
  }
  hostName = hostName.replaceFirst(":[0-9]+$", "") ;

  // D) User info
  String[] userInfo = new String[3] ;
  String[] origUserInfo = new String[3] ;
  // Initial from session, which will work if the request is to this host (i.e. not proxying)
  origUserInfo[0] = userInfo[0] = (String) mys.getAttribute("username") ;
  if(userInfo[0] == null)
  {
    origUserInfo[0] = userInfo[0] = "" ;
  }
  origUserInfo[1] = userInfo[1] = (String) mys.getAttribute("pass") ;
  if(userInfo[1] == null)
  {
    origUserInfo[1] = userInfo[1] = "" ;
  }
  origUserInfo[2] = userInfo[2] = (String)mys.getAttribute("userid") ;
  if(userInfo[2] == null)
  {
    origUserInfo[2] = userInfo[2] = "-1" ;
  }

  // Should we show a login prompt if it looks like the user is not logged in?
  if(promptForLogin && (mys.isNew() || (userInfo[0].length() == 0) || (userInfo[1].length() == 0) || (userInfo[2].length() == 0) || (userInfo[2].equals("-1"))))
  {
    mys.setAttribute("accessDenied", "true") ;
    GenboreeUtils.sendRedirectSaveTarget(mys, request, response, "/java-bin/login.jsp") ;
    return ;
  }

  // Does it look like the session has expired or something? If so, we'll prep an appropriate response manually
  if(request.isRequestedSessionIdValid() && !mys.isNew())
  {
    // If proxy, need to replace the above with the proper user login for the remote host.
    // Do a request to THIS host as the user for the user's host auth rec info for the remote host.
    if(proxying)
    {
      boolean gotHostAuthRec = false ;
      String apiPath = "/REST/v1/usr/" + Util.urlEncode(userInfo[0]) + "/host/" + Util.urlEncode(rsrcHost) ;
      // Do an API call to THIS host to get auth record for user at the remote host.
      String apiURL = RESTapiUtil.computeFinalURL(origHostName, apiPath, "", userInfo) ;
      System.err.println("PROXYING --------------> apiURL to get auth info for user " + userInfo[0] + " @ host " + rsrcHost + "\n\n" + apiURL + "\n\n") ;
      HttpURLConnection apiConn = ApiCallerUtil.doApiCall(apiURL, "GET", null) ;
      int apiResultCode = apiConn.getResponseCode() ;
      if(apiResultCode == 200)
      {
        InputStream apiResultStream = apiConn.getInputStream() ;
        String respBody ;
        try
        {
          respBody = new java.util.Scanner(apiResultStream).useDelimiter("\\A").next() ;
          apiResultStream.close() ;
          apiConn.disconnect() ;
          System.err.println("PROXYING --------------> host info record payload:\n\n " + respBody + "\n\n") ;
          // Parse JSON.
          try
          {
            String remoteUser, remotePass ;
            JSONObject respObj = new JSONObject(respBody) ;
            if(respObj.has("data"))
            {
              JSONObject dataObj = respObj.getJSONObject("data") ;
              if(dataObj.has("login"))
              {
                remoteUser = dataObj.getString("login") ;
                if(dataObj.has("token"))
                {
                  remotePass = dataObj.getString("token") ;
                  System.err.println("PROXYING --------------> extracted from payload:" + remoteUser + " ; " + remotePass) ;
                  userInfo[0] = remoteUser ;
                  userInfo[1] = remotePass ;
                  rsrcPath = rsrcPath.replaceFirst(origUserInfo[0], remoteUser) ;
                  gotHostAuthRec = true ;
                }
              }
            }
          }
          catch(JSONException jex)
          {
            // No-op; will clear userInfo.
            System.err.println("PROXY ERROR: " + jex) ;
            jex.printStackTrace(System.err) ;
          }
        }
        catch(java.util.NoSuchElementException nsee)
        {
          // No-op; will clear userInfo.
          System.err.println("PROXY ERROR: " + nsee) ;
          nsee.printStackTrace(System.err) ;
        }
      }
      // If we didn't get a valid record, wipe userInfo [which currently has the info for THIS host, not the one we need info for]
      if(!gotHostAuthRec)
      {
        userInfo[0] = "" ;
        userInfo[1] = "" ;
        userInfo[2] = "-1" ;
      }
    } // if(proxying)
    // --------------------------------------------------------------------------

    // Generate the final URL with the auth parameters on the end, etc
    String fullApiURL ;
    if(Util.parseInt(userInfo[2], -2) <= 0 && gbKey != null) // Public user or case where userId is not available/set, but WITH a gbKey
    {
      System.err.println("DEBUG: computeFinalURL info 1: " + hostName + " ; " + rsrcPath + " ; " + rsrcParams + " ; " + userInfo[0] + " ; " + userInfo[1] + " ; " + userInfo[2]) ;
      if(rsrcScheme == null || rsrcPort == null) {
        fullApiURL = RESTapiUtil.computeFinalURL(hostName, rsrcPath, rsrcParams, gbKey) ;
      }
      else {
        fullApiURL = RESTapiUtil.computeFinalURL(hostName, rsrcPath, rsrcParams, gbKey, rsrcScheme, rsrcPort) ;
      }
    }
    else // Either a regular user OR Public user WITHOUT a gbKey (in that case API will see if resource access is allowed for Public user or not)
    {
      if(rsrcScheme == null || rsrcPort == null) {
        fullApiURL = RESTapiUtil.computeFinalURL(hostName, rsrcPath, rsrcParams, userInfo) ;
      }
      else{
        fullApiURL = RESTapiUtil.computeFinalURL(hostName, rsrcPath, rsrcParams, userInfo, rsrcScheme, rsrcPort) ;
      }
    }

    System.err.println("DEBUG: fullApiURL = " + fullApiURL) ;

    // Send the request using the appropriate method and pass back the response:
    // --------------------------------------------------------------------------
    // 1. Make URL
    URL apiUrl = new URL(fullApiURL) ;
    System.err.println("DEBUG: check URI apiUrl object carefully:\n  apiUrl.toString(): " + apiUrl.toString() + "\n  apiUrl.toExternalForm(): " +  apiUrl.toExternalForm() + "\n  apiUrl.getPath(): " + apiUrl.getPath() + "\n  apiUrl.toURI().toString(): " + apiUrl.toURI().toString() + "\n\n") ;
    // 2. Open connection to URL
    HttpURLConnection apiConn = (HttpURLConnection)apiUrl.openConnection() ;
    //System.err.println("DEBUG: verify URL from HttpURLConnection apiConn still looks good:\n  apiConn.toString(): " + apiConn.toString() + "\n  apiConn.getURL().toString(): " + apiConn.getURL().toString() + "\n  apiConn.getURL().getPath(): " + apiConn.getURL().getPath() + "\n\n") ;
    // 3. Set request method and configure to make request
    apiConn.setRequestMethod(method) ;
    apiConn.setDoOutput(true) ;
    apiConn.setConnectTimeout(10*1000) ;
    apiConn.setReadTimeout(1800*1000) ;
    apiConn.setFollowRedirects(false) ;
    // 3.5 Set request content if a PUT
    // Simply pass through the contents of payload parameter
    if(request.getParameter("payload") != null)
    {
      // NOTE: Reading the request body in this way will not work because of
      // the previous calls to "getParameter()"  According to the Java Servlet
      // Spec, once you call getParameter(), the request body is unavailable
      // so the reader will only return null.
      // In order to combat this, any payloads must be sent as a parameter
      // called "payload" (either GET or POST should work).
      String body = request.getParameter("payload") ;

      // Write the body out to the API connection
      PrintWriter apiConnWriter = new PrintWriter(apiConn.getOutputStream()) ;
      apiConnWriter.print(body) ;
      // Close the output stream so we can get the results
      apiConnWriter.close() ;
    }
    // 4. Send request to API
    apiConn.connect() ;
    // 5. Get api result response code
    int apiResultCode = apiConn.getResponseCode() ;
    //System.err.println("DEBUG: apiResultCode = " + apiResultCode) ;
    // 6. Get api result length
    int apiResultLength = apiConn.getContentLength() ;
    // 7. Get key headers from the API result
    String apiResultLocation = apiConn.getHeaderField("Location") ;
    String apiResultContentType = apiConn.getContentType() ;
    // 8. We need to get the correct stream...Java does this really dumb, making is non-obvious and hard.
    InputStream apiResultStream = (apiResultCode < 400 ? apiConn.getInputStream() : apiConn.getErrorStream()) ;

    // 9 Process result stream according to response code and useBinMode:
    // --------- OK: BINARY RESPONSE AND HAVE BINARY PAYLOAD FROM API--------------
    if(useBinMode && (apiResultCode < 300))  // then binary response expected and API gave us some good binary payload
    {
      // Reset any response stuff the jsp framework prepped
      response.reset() ;
      // Set up the respnse
      if(fileDownload)
      {
        // Need the fileName, extract from the rsrcPath
        // Get everything before '/data' up to '/', this won't include subdirs
        String dlFileName = rsrcPath.substring(0, rsrcPath.lastIndexOf("/data")) ;
        dlFileName = dlFileName.substring(dlFileName.lastIndexOf('/') + 1) ;
        response.setHeader( "Content-Disposition", "attachment; filename=\""+Util.urlDecode(dlFileName)+"\"" );
      }
      if(trkDownload)
      {
        String dlTrkName = rsrcPath.substring(0, rsrcPath.lastIndexOf("/annos")) ;
        dlTrkName = dlTrkName.substring(dlTrkName.lastIndexOf('/') + 1) ;
        //System.err.println("trkFormat: " + trkFormat) ;
        response.setHeader( "Content-Disposition", "attachment; filename=\""+Util.urlDecode(dlTrkName)+"." + trkFormat + "\"" );
      }
			if(jobSummary)
			{
        response.setHeader( "Content-Disposition", "attachment; filename=\"jobSummary.txt\"" );
			}

      ApiCallerUtil.prepResponse(response, apiResultCode, apiResultLength, apiResultContentType, apiResultLocation) ;

      // Get a response outputstream suitable for doing binary writing
      BufferedOutputStream respOut = new BufferedOutputStream(response.getOutputStream(), 16*1024) ;
      // Write out bytes
      int numBytesRead ;
      byte[] byteBuff = new byte[1024*1024] ;
      while( (numBytesRead = apiResultStream.read(byteBuff)) > 0 )
      {
        respOut.write(byteBuff, 0, numBytesRead) ;
      }

      // Done with the input stream and the http connection
      try
      {
        apiResultStream.close() ;
        apiConn.disconnect() ;
        respOut.close() ;
      }
      catch(IOException ioe)
      {
        /* nothing, safe close() */
      }
      // Return...don't want automatic JSP clean up mucking with our special output stream or doing implicit out.write("\n") because it sees a % >
      return ;
    }
    // --------- ERROR: BINARY RESPONSE AND HAVE POSSIBLE NON-BINARY PAYLOAD FROM API (e.g. error details text) AND TEXT RESPONSE *NOT* OK --------------
    else if(useBinMode && (apiResultCode >= 300) && !(errorRespTextOk || errorFormatStr.equals("html"))) // then have binary mode, but ERROR (or redirect) and error text is NOT OK to respond with
    {
      // Since can't pass along any text in the response, we'll set
      // the proper response headers and just log any error payload text from the api response.
      // Set up the response
      ApiCallerUtil.prepResponse(response, apiResultCode, apiResultLength, apiResultContentType, apiResultLocation) ;
      // Log response
      ApiCallerUtil.logApiResponse(fullApiURL, apiResultCode, apiResultLength, apiResultContentType, apiResultLocation, apiResultStream) ;
    }
    // --------- REDIRECT: GOT BACK A "Bad Request" OR "Forbidden". Html presentation of error is ok. ------------
    else if(errorFormat.equals("html") && (apiResultCode == 400 || apiResultCode == 403))
    {
      String[] errMsg = new String[2] ;
      if(apiResultCode == 400) // Bad Request.
      {
        errMsg[0] = "BAD REQUEST:" ;
        errMsg[1] = "The API URL being accessed is not correct or is causing an exception on the server.<br>&nbsp;<br>The questionable URL is<br>&nbsp;&nbsp; " + rsrcPathParam ;
      }
      else if(apiResultCode == 403) // Forbidden, tell user
      {
        errMsg[0] = "FORBIDDEN:" ;
        errMsg[1] = "You are not in the appropriate user group or the data entity is otherwise restricted.<br>&nbsp;<br>Please contact the group adminstrators for access to:<br>&nbsp;<br>&nbsp;&nbsp;" + rsrcPathParam ;
      }
      else // WTF? something weird happened (error probably); tell user and log info
      {
        // Log response
        ApiCallerUtil.logApiResponse(fullApiURL, apiResultCode, apiResultLength, apiResultContentType, apiResultLocation, apiResultStream) ;
      }
      // Show error page with message
      mys.setAttribute("lastError", errMsg) ;
      GenboreeUtils.sendRedirect(request, response, "/java-bin/error.jsp") ;
    }
    // --------- ERROR: EITHER TEXT RESPONSE EXPECTED AND FAILED, OR BINARY EXPECTED AND FAILED BUT ANY ERROR TEXT PAYLOAD IS OK TO SEND--------------
    else
    {
      // Set up the respnse
      ApiCallerUtil.prepResponse(response, apiResultCode, apiResultLength, apiResultContentType, apiResultLocation) ;

      // Make a nice text reader out of the inputstream
      InputStreamReader apiResultStreamReader = new InputStreamReader(apiResultStream) ;
      BufferedReader apiResultReader = new BufferedReader(apiResultStreamReader) ;
      // Accumlate response ; NOTE: probably better to prep response and then
      // write out the text in a loop, not accumulate in memory first.
      StringBuffer apiResultBuff = new StringBuffer() ;
      String resultLine ;
      while((resultLine = apiResultReader.readLine()) != null)
      {
        apiResultBuff.append(resultLine) ;
      }
      apiResultReader.close() ;
      // Done with the input stream and the http connection
      apiResultStream.close() ;
      apiConn.disconnect() ;
      // Get buffered text as String
      String apiResultBody = apiResultBuff.toString() ;
      // Clear buffer as best we can (free mem early if possible)
      apiResultBuff.setLength(0) ;
      apiResultBuff = null ;

      // 8. Write the api result content in the response
      out.write(apiResultBody) ;
      out.flush() ;
    }
  }
  else // new session or session expired it looks like
  {
    System.err.println("API_CALLERR ERROR: new session or something (" + mys.isNew() + ")") ;
    // Prep a manual 412 response response
    String statusMsg = "{ \"data\" : {}, \"status\" : { \"statusCode\" : \"Precondition Failed\", \"msg\" : \"SESSION EXPIRED\" } }\n" ;
    // Reset any response stuff the jsp framework prepped
    response.reset() ;
    // Prep the 412 response we'll be sending back.
    ApiCallerUtil.prepResponse(response, 412, statusMsg.length(), "application/json", null) ;
    // Write out a little JSON payload. Key thing is the 412 header though.
    PrintStream respOut = new PrintStream(new BufferedOutputStream(response.getOutputStream(), 16*1024)) ;
    respOut.print(statusMsg) ;
    respOut.close() ;
    // Return...don't want automatic JSP clean up mucking with our special output stream or doing implicit out.write("\n") because it sees a % >
    return ;
  }
  // long endTime = Calendar.getInstance().getTimeInMillis() ;
  // System.err.println("started at " + startTime + " and ended at " + endTime);
%>
