package org.genboree.rest.util ;
import java.net.* ;
import java.io.* ;
import javax.servlet.http.* ;
import org.genboree.util.* ;

public class ApiCallerUtil
{
  public static boolean prepResponse(HttpServletResponse response, int respCode, int contentLength, String contentType, String location)
  {
    boolean retVal = true ;
    // Set response code to that of api result
    response.setStatus(respCode) ;
    // Set the content type to that of the api result
    response.setContentType(contentType) ;
    // Set content length to that of api result
    // response.setContentLength(contentLength) ;
    // Try to set response Location if the api set one (this may not work, Servlet container might override)
    if(location != null)
    {
      response.setHeader("Location", location) ;
    }
    return retVal ;
  }

  public static boolean logApiResponse(String apiURI, int respCode, int respLength, String respContentType, String respLocation, InputStream respStream)
  {
    boolean retVal = true ;
    System.err.println(
      "=====================================================================\n" +
      "ApiCaller - Error Response Received" +
      "\n  API Response Code     = " + respCode +
      "\n  API Response Length   = " + respLength +
      "\n  API Response Location = " + respLocation +
      "\n  API Content Type      = " + respContentType +
      "\n  API URL:\n    " + apiURI +
      "\n  API Response Body:\n"
    ) ;
    try // to print api response body (as binary data, should be same as what we received)
    {
      // File tmpFile = File.createTempFile("testPng", ".png", new File("/usr/local/brl/data/genboree/temp/")) ;
      // FileOutputStream tmpFileOut = new FileOutputStream(tmpFile) ;
      int numBytesRead ;
      byte[] byteBuff = new byte[1024*1024] ;
      while( (numBytesRead = respStream.read(byteBuff)) > 0 )
      {
        // tmpFileOut.write(byteBuff, 0, numBytesRead) ;
        System.err.write(byteBuff, 0, numBytesRead) ;
      }
      // tmpFileOut.close() ;
      respStream.close() ;
    }
    catch(Exception ex)
    {}
    System.err.println("\n=====================================================================\n") ;
    return retVal ;
  }

  // Returns a completed HttpURLConnection, which can be interrogated for
  // status code, headers, etc. YOU MUST close the returned HttpURLConnection when you are done with it.
  public static HttpURLConnection doApiCall(String apiURI, String method, String payload)
  {
    HttpURLConnection apiConn = null ;
    try
    {
      // Send the request using the appropriate method and pass back the response:
      // --------------------------------------------------------------------------
      // 1. Make URL
      URL apiUrl = new URL(apiURI) ;
      // 2. Open connection to URL
      apiConn = (HttpURLConnection)apiUrl.openConnection() ;
      // 3. Set request method and configure to make request
      apiConn.setRequestMethod(method) ;
      apiConn.setDoOutput(true) ;
      apiConn.setConnectTimeout(10*1000) ;
      apiConn.setReadTimeout(1800*1000) ;
      apiConn.setFollowRedirects(false) ;
      // 3.5 Set request content if a PUT
      // Simply pass through the contents of payload parameter
      if(payload != null)
      {
        // Write the body out to the API connection
        PrintWriter apiConnWriter = new PrintWriter(apiConn.getOutputStream()) ;
        apiConnWriter.print(payload) ;
        // Close the output stream so we can get the results
        apiConnWriter.close() ;
      }
      // 4. Send request to API
      apiConn.connect() ;
    }
    catch(Exception ex)
    {
      System.err.println("PROXY ERROR: " + ex) ;
      ex.printStackTrace(System.err) ;
    }
    return apiConn ;
  }
}
