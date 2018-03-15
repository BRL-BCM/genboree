package org.genboree.util.helpers ;

import java.math.* ;
import java.util.*;
import java.security.* ;
import javax.servlet.* ;
import org.genboree.util.* ;

public class RESTapiUtil
{
  private static final char[] HEX_CHARS = { '0','1','2','3','4','5','6','7','8','9','a','b','c','d','e','f' } ;

  // One-stop shop for SHA1 digest (as hex string). Java doesn't have one
  // of these already, can you believe it???
  public static String SHA1(String src)
  {
    String retVal = null ;
    try
    {
      MessageDigest md = MessageDigest.getInstance("SHA") ;
      byte[] hash = md.digest(src.getBytes()) ;
      BigInteger asBigNum = new BigInteger(1, hash) ;
      // Ensure the hex string is 40 long, including any leading 0s (toString(16) will strip them)
      retVal = String.format("%040x", asBigNum) ;
    }
    catch(NoSuchAlgorithmException nsae)
    {
      System.err.println("ERROR: MessageDigest doesn't have a SHA provider??") ;
      System.err.println("- " + nsae.getMessage()) ;
      nsae.printStackTrace(System.err) ;
      retVal = null ;
    }
    return retVal ;
  }

  // Compute the final REST API URL based on coreURI, but containing the
  // appropriate gbLogin, gbTime, and gbToken parameters based on the
  // userInfo String[] that comes from the current session.
  public static String computeFinalURL(String coreURI, String[] userInfo)
  {
    coreURI = coreURI.trim() ;
    // Compute the auth token for coreURI, using time and user info
    long timeSecs = System.currentTimeMillis() / 1000L ;
    String tokenValue = RESTapiUtil.computeGbToken(coreURI, userInfo, timeSecs) ;
    // Append the auth params onto the coreURI to form the finalURL
    if(coreURI.indexOf("?") < 0) // add a ? query-string delimiter if there isn't one already
    {
      coreURI = coreURI + "?" ;
    }
    StringBuffer finalURL = new StringBuffer(coreURI) ;
    finalURL.append("&gbLogin=").append(Util.urlEncode(userInfo[0])) ;
    finalURL.append("&gbTime=").append(timeSecs) ;
    finalURL.append("&gbToken=").append(tokenValue) ;
    return finalURL.toString() ;
  }

  // Compute the final REST API URL based on coreURI, but using the indicated gbKey rather
  // than gb* auth parameters. If the gbKey is null, the coreURI had better include
  // the gbKey parameter itself already.
  public static String computeFinalURL(String coreURI, String gbKey)
  {
    coreURI = coreURI.trim() ;
    // Compute the auth token for coreURI, using time and user info
    long timeSecs = System.currentTimeMillis() / 1000L ;
    if(coreURI.indexOf("?") < 0) // add a ? query-string delimiter if there isn't one already
    {
      coreURI = coreURI + "?" ;
    }
    // Append the gbKey to the core URI if necessary
    StringBuffer finalURL = new StringBuffer(coreURI) ;
    if(gbKey != null)
    {
      finalURL.append("&gbKey=").append(Util.urlEncode(gbKey)) ;
    }
    return finalURL.toString() ;
  }

  // Compute the final REST API URL based on coreURI, but containing the
  // appropriate gbLogin, gbTime, and gbToken parameters based on the
  // userInfo String[] that comes from the current session.
  // - in this version the components are provided separately
  public static String computeFinalURL(String host, String rsrcPath, String rsrcParamsStr, String[] userInfo)
  {
    String coreURI = "http://" + host.trim() + rsrcPath.trim() ;
    if(coreURI.indexOf("?") < 0)
    {
      coreURI = coreURI + "?" ;
    }
    if(rsrcParamsStr != null)
    {
      coreURI += rsrcParamsStr.trim() ;
    }
    return computeFinalURL(coreURI, userInfo) ;
  }

  // Compute the final REST API URL but using the indicated gbKey rather
  // than gb* auth parameters. If the gbKey is null, the rsrcPath had better include
  // the gbKey parameter itself already.
  // - in this version the components are provided separately
  public static String computeFinalURL(String host, String rsrcPath, String rsrcParamsStr, String gbKey)
  {
    String coreURI = "http://" + host.trim() + rsrcPath.trim() ;
    if(coreURI.indexOf("?") < 0)
    {
      coreURI = coreURI + "?" ;
    }
    if(rsrcParamsStr != null)
    {
      coreURI += rsrcParamsStr.trim() ;
    }
    return computeFinalURL(coreURI, gbKey) ;
  }
  
  
  // Compute the final REST API URL based on coreURI, but containing the
  // appropriate gbLogin, gbTime, and gbToken parameters based on the
  // userInfo String[] that comes from the current session.
  // - in this version the components are provided separately
  public static String computeFinalURL(String host, String rsrcPath, String rsrcParamsStr, String[] userInfo, String scheme, Integer port)
  {
    String coreURI ;
    if(scheme == null ){
      scheme = "http" ;
    }
    if(port == null || port == -1) {
      coreURI = scheme+"://" + host.trim() + rsrcPath.trim() ;
    }
    else{
      coreURI = scheme+"://" + host.trim() + ":" + Integer.toString(port)  + rsrcPath.trim() ;
    }
    if(coreURI.indexOf("?") < 0)
    {
      coreURI = coreURI + "?" ;
    }
    if(rsrcParamsStr != null)
    {
      coreURI += rsrcParamsStr.trim() ;
    }
    return computeFinalURL(coreURI, userInfo) ;
  }

  // Compute the final REST API URL but using the indicated gbKey rather
  // than gb* auth parameters. If the gbKey is null, the rsrcPath had better include
  // the gbKey parameter itself already.
  // - in this version the components are provided separately
  public static String computeFinalURL(String host, String rsrcPath, String rsrcParamsStr, String gbKey, String scheme, Integer port)
  {
    String coreURI ;
    if(scheme == null ){
      scheme = "http" ;
    }
    if(port == null || port == -1) {
      coreURI = scheme+"://" + host.trim() + rsrcPath.trim() ;
    }
    else{
      coreURI = scheme+"://" + host.trim() + ":" + Integer.toString(port)  + rsrcPath.trim() ;
    }
    if(coreURI.indexOf("?") < 0)
    {
      coreURI = coreURI + "?" ;
    }
    if(rsrcParamsStr != null)
    {
      coreURI += rsrcParamsStr.trim() ;
    }
    return computeFinalURL(coreURI, gbKey) ;
  }
  
  

  // Compute the authentication token using the already-computed digestURL, given a
  // userInfo String[] that comes from the current session.
  public static String computeGbToken(String coreURI, String[] userInfo, long timeSecs)
  {
    String token = null ;
    // Get password for user
    String passwd = "" ;
    if(Util.parseInt(userInfo[2], -1) > 0) // then is not the Public/Guest user
    {
      passwd = userInfo[1] ;
    }
    passwd = SHA1(userInfo[0] + passwd) ;
    if(passwd != null)
    {
      token = SHA1(coreURI + passwd + String.valueOf(timeSecs)) ;
    }
    return token ;
  }
  
  // Fill in the current URI template with variable values.
  // [+uriPattern+] URI template with variables to be replaced
  // [+fieldValues+] The map of template variable names to +String+ values.
  // [+returns+] URI template with any template variables filled in, as a +String+.
    public static String fillURIPattern(String uriPattern, HashMap<String, String> fieldValues)
  {
    for(Map.Entry<String, String> entry : fieldValues.entrySet())
    {
       uriPattern = uriPattern.replaceAll("\\{"+entry.getKey()+"\\}",Util.urlEncode(entry.getValue()));       
    }
    return uriPattern;
  }
}
