<%@ page import="
  java.io.*,
  java.util.*,
  java.util.regex.*,
  org.json.JSONArray,
  org.json.JSONObject,
  org.json.JSONException,
  org.genboree.util.*,
  org.genboree.util.helpers.*,
  org.genboree.message.GenboreeMessage"
%>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/group.incl" %>
<%@ include file="include/sessionGrp.incl" %>
<%
  // Constants
  final String underlyingPage = "/genboree/workbench/workbench.rhtml" ;

  // Key variables:
  String urlStr = null ;
  boolean doHtmlStripping = true ;
  // String to store the entire content of an URL using getContentOfUrl(urlStr)
  String contentUrl = null ;
  String currPageURI = request.getRequestURI() ;
  // Turn off caching for this page (can cause inconsistencies for the ajax code)
  response.addHeader( "Cache-Control", "no-cache, no-store" );

  // Get hosted site name, since we're going to lose this the way it's written.
  // We will need to page hostedSite onwards to workbench.rhtml
  String hostedSite = "default" ;
  Pattern hostedProjRe = Pattern.compile("/java-bin/([^/]+)/") ;
  Matcher hostedProjMatch = hostedProjRe.matcher(currPageURI) ;
  if(hostedProjMatch.lookingAt())
  {
    hostedSite = hostedProjMatch.group(1) ;
  }

  // This page provides two responses, 1.) the valid HTML for the workbench
  // page, and 2.) the JSON string describing the icon configuration for the
  // toolbar according to the active data set.  The different responses are
  // achieved by passing a activeDataset= flag.  If this parameter is not-null,
  // the JSON string is returned.  If missing the HTML is returned.
  //
  if(request.getParameter("activeDataset") != null)
  {
    // Provide the JSON string
    JSONArray output = new JSONArray() ;

    // Parse the dataset config
    JSONArray dataset = new JSONArray() ;
    try
    {
      dataset = new JSONArray(request.getParameter("activeDataset")) ;

      // Parse our toolbar config file
      String toolConfigStr = "" ;
      try
      {
        BufferedReader reader = new BufferedReader(new FileReader(GenboreeConfig.getConfigParam("gbWorkbenchToolbarConfig"))) ;
        while(reader.ready()) toolConfigStr += reader.readLine() ;
      }
      catch(IOException e)
      {
        System.err.println("workbench.jsp: Error reading the workbench toolbar config file: " + e) ;
        toolConfigStr = "[]" ;
      }
      JSONArray toolConfigJson = new JSONArray() ;
      try
      {
        toolConfigJson = new JSONArray(toolConfigStr) ;
      }
      catch(JSONException e)
      {
        System.err.println("workbench.jsp: Error parsing workbench toolbar config file (bad JSON): " + e) ;
      }

      // For every pair in the database, see if our dataset matches
      for(int configNum = 0; configNum < toolConfigJson.length(); configNum++)
      {
        int configTrackNum = toolConfigJson.getJSONObject(configNum).getJSONArray("tracks").length() ;
        JSONObject[] configDataset = new JSONObject[configTrackNum] ;
        for(int configTrack = 0; configTrack < configTrackNum; configTrack++)
          configDataset[configTrack] = toolConfigJson.getJSONObject(configNum).getJSONArray("tracks").getJSONObject(configTrack) ;

        // Easiest comparison, first check the length
        boolean match = false ;
        if(configDataset.length == dataset.length())
        {
          match = true ;
          // Loop through the config dataset looking for a match
          for(int datasetNum = 0; datasetNum < dataset.length(); datasetNum++)
          {
            boolean trackMatch = false ;
            JSONObject datasetObj = dataset.getJSONObject(datasetNum) ;
            for(JSONObject configObj : configDataset)
            {
              trackMatch = trackMatch || (datasetObj.getString("type").equals("track") &&
                datasetObj.getString("group").equals(configObj.getString("group")) &&
                datasetObj.getString("database").equals(configObj.getString("database")) &&
                datasetObj.getString("name").equals(configObj.getString("name"))) ;
            }

            // If all tracks have a match, we have a match
            match = match && trackMatch ;
          }
        }

        // If we have a match, add this "tool" to the output
        if(match)
        {
          JSONObject tool = new JSONObject() ;
          tool.put("id", toolConfigJson.getJSONObject(configNum).getString("tool")) ;
          tool.put("enabled", true) ;
          tool.put("url", toolConfigJson.getJSONObject(configNum).getString("url")) ;
          output.put(tool) ;
        }
      }
    }
    catch (JSONException e)
    {
      System.err.println("workbench.jsp: Unknown problem parsing JSON string for active dataset: " + e) ;
    }

    // Return the response
    out.write(output.toString()) ;
  }
  else
  {
    // Provide the HTML page

    //
    // The following section is where we perform the JSP wrapped rhtml magic.
    // Basically read any and all important variables out of the session and
    // re-POST them to the underlying rhtml page which will generate *all*
    // of the required HTML for us.
    //

    // 1.) Rebuild the request params we will pass to RHTML side (via a POST)
    Map paramMap = request.getParameterMap() ; // "key"=>String[]
    StringBuffer postContentBuff = new StringBuffer() ;
    postContentBuff.append("userId=").append(URLEncoder.encode(userInfo[2], "UTF-8")) ;
    postContentBuff.append("&userEmail=").append(URLEncoder.encode(myself.getEmail(), "UTF-8")) ;
    postContentBuff.append("&userFirstName=").append(URLEncoder.encode(myself.getFirstName(), "UTF-8")) ;
    postContentBuff.append("&userLastName=").append(URLEncoder.encode(myself.getLastName(), "UTF-8")) ;
    postContentBuff.append("&userLogin=").append(URLEncoder.encode(userInfo[0], "UTF-8")) ;
    postContentBuff.append("&hostedSite=").append(URLEncoder.encode(hostedSite, "UTF-8")) ;
    String userPwdDigest = RESTapiUtil.SHA1(userInfo[0] + userInfo[1]) ;
    if(userPwdDigest != null)
    {
      postContentBuff.append("&userPwdDigest=").append(URLEncoder.encode(userPwdDigest, "UTF-8")) ;
    }

    // 1.b Loop over request key-value pairs, append them to rhtml request:
    Iterator paramIter = paramMap.entrySet().iterator() ;
    while(paramIter.hasNext())
    {
      Map.Entry paramPair = (Map.Entry) paramIter.next() ;
      String pName = URLEncoder.encode((String) paramPair.getKey(), "UTF-8") ;
      String[] pValues = (String[]) paramPair.getValue() ; // <-- Array!
      postContentBuff.append("&") ;
      if(pValues != null)
      {
        // There is 1+ actual values
        for(int ii = 0; ii < pValues.length; ii++)
        {
          // Add all of the values to the POST
          postContentBuff.append(pName).append("=").append(URLEncoder.encode(pValues[ii], "UTF-8")) ;
        }
      }
      else // no value, just a key? ok...
      {
        postContentBuff.append("&").append(pName).append("=") ;
      }
    }

    // Set group_id if it has not been set
    if((postContentBuff.indexOf("group_id") == -1) && (SessionManager.getSessionGroupId(session) != null))
    {
      postContentBuff.append("&group_id=").append(
        URLEncoder.encode(SessionManager.getSessionGroupId(session), "UTF-8")) ;
    }

    if(SessionManager.getSessionGroupName(session) != null)
    {
      postContentBuff.append("&groupName=").append(
        URLEncoder.encode(SessionManager.getSessionGroupName(session), "UTF-8")) ;
    }

    if((postContentBuff.indexOf("rseq_id") == -1) && (SessionManager.getSessionDatabaseId(session) != null))
    {
      postContentBuff.append("&rseq_id=").append(
        URLEncoder.encode(SessionManager.getSessionDatabaseId(session), "UTF-8")) ;
    }

    if(SessionManager.getSessionDatabaseDisplayName(session) != null)
    {
      postContentBuff.append("&rseqName=").append(
        URLEncoder.encode(SessionManager.getSessionDatabaseDisplayName(session), "UTF-8")) ;
    }

    // 1.c Get the string we will post IF that's what we will be doing
    String postContentStr = postContentBuff.toString() ;
    urlStr = myBase + underlyingPage ;

    // 2.) Actually post to the .rhtml and simply write the response to "out"
    if(urlStr != null)
    {
      HashMap hdrsMap = new HashMap() ;
      // Do as a POST
      contentUrl = GenboreeUtils.postToURL(urlStr, postContentStr, doHtmlStripping, hdrsMap, session) ;
      // Update group/database if correct X-HEADERS are found:
      GenboreeUtils.updateSessionFromXHeaders(hdrsMap, session) ;
      // Write out content of other page
      out.write(contentUrl) ;
    }
  }
%>
