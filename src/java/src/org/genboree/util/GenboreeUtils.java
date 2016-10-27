package org.genboree.util;

import javax.naming.directory.Attribute;
import javax.naming.directory.Attributes;
import javax.naming.directory.DirContext;
import javax.naming.directory.InitialDirContext;
import javax.servlet.http.Cookie;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;
import javax.servlet.jsp.JspWriter;
import java.io.*;
import java.net.HttpURLConnection;
import java.net.InetAddress;
import java.net.URL;
import java.security.MessageDigest;
import java.sql.*;
import java.util.*;

import org.genboree.dbaccess.*;
import static org.genboree.dbaccess.GenboreeUpload.fetchUploadIdFromRefSeqIdDbName;
import org.genboree.dbaccess.util.Database2HostTable;
import org.genboree.downloader.AnnotationDownloader;
import org.genboree.upload.*;
import org.genboree.util.MemoryUtil ;

public class GenboreeUtils
{
  public static final String propertiesFile = GenboreeUtils.getConfigFileName() ;
  public static final String colorDescFile = Constants.GENBOREE_ROOT + "/colorCode.txt";
  public static HashMap colorCode = null;

  public static ArrayList getMXRecs(String hostName)
  {
    String[] recTypes = { "MX" } ;
    ArrayList mxRecords = new ArrayList() ;
    Hashtable contextEnv = new Hashtable() ;
    // If we've been given the full email address, fix it so we have just the domain
    String newHost = hostName ;
    if(hostName.indexOf("@") >= 0)
    {
      String[] parts = hostName.split("@") ;
      newHost = parts[parts.length-1] ;
    }
    try
    {
      contextEnv.put( "java.naming.factory.initial", "com.sun.jndi.dns.DnsContextFactory" ) ;
      DirContext initContext = new InitialDirContext( contextEnv ) ;
      Attributes attrs = initContext.getAttributes( newHost, recTypes ) ;
      for(Enumeration enumer = attrs.getAll(); enumer.hasMoreElements(); )
      {
        Attribute attrib = (Attribute)enumer.nextElement() ;
        int attribSize = attrib.size() ;
        for(int ii=0; ii<attribSize; ii++)
        {
          mxRecords.add((String)attrib.get(ii)) ;
        }
      }
      initContext.close() ;
    }
    catch(Exception ex)
    {
      System.err.println("ERROR: GenboreeGroup#getMXRecs() => MX record lookup for domain '" + newHost + "' failed.") ;
      ex.printStackTrace(System.err) ;
    }
    return mxRecords;
  }

  // Valid email host names have at least 1 MX record.
  // They may or may NOT have IP addresses. Example: DFCI.HARVARD.EDU has no
  // IP address and thus may look like a bad host name, but it has DNS MX
  // records, so mail can actually be sent there.
  public static boolean validateEmailHost(String hostName)
  {
    ArrayList mxRecords = getMXRecs(hostName) ;
    return mxRecords.size() > 0 ;
  }

  public static HashMap getColorCode()
  {
    if(GenboreeUtils.colorCode == null || GenboreeUtils.colorCode.size() < 1)
    {
      GenboreeUtils.colorCode = DirectoryUtils.transformFileWithValuePairsIntoHash(GenboreeUtils.colorDescFile);
    }
    return GenboreeUtils.colorCode;
  }

  // Pending have to add and deploy additional methods to the uploader
  public static HashMap insertLffLines(String refSeqId, String userId, String groupId, String[] lffLines)
  {
    HashMap results = new HashMap();
    AnnotationUploader currentUpload = null ;

    String databaseNameInUse = GenboreeUtils.fetchMainDatabaseName(refSeqId);
    boolean validRefseqId = DatabaseCreator.checkIfRefSeqExist(refSeqId, databaseNameInUse);
    if(validRefseqId)
    {
      currentUpload = new AnnotationUploader(refSeqId, userId, groupId, databaseNameInUse);
      results.put("maxNumberOfInserts", "" + currentUpload.getMaxNumberOfInserts());
      results.put("maxSizeOfBufferInByte", "" + currentUpload.getMaxSizeOfBufferInBytes());
      // Start timing the whole upload
      currentUpload.setIgnore_refseq(true);
      currentUpload.setIgnore_assembly(true);
      currentUpload.setSleepTime(LffConstants.uploaderSleepTime);
      currentUpload.setMaxNumberOfInserts(LffConstants.defaultNumberOfInserts);

      boolean fileLoaded = currentUpload.loadLffArray(lffLines);

      results.put("groupAssignerTimeInfo", currentUpload.getGroupAssignerTimmerInfo());
      results.put("numberOfLines", "" + currentUpload.getCurrentLffLineNumber());
      results.put("numberOfParsedRecords", "" + currentUpload.getAnnotationsSuccessfullyParsed());
      results.put("numberOfInsertedRecords", "" + currentUpload.getAnnotationsForInsertion());
      results.put("numberOfUpdatedRecords",  "" + currentUpload.getAnnotationsForUpdate());
    }
    return results;
  }

  public static String readFileIntoMemory(String fidFile)
  {
    StringBuffer fileContent = new StringBuffer();
    int numberOfLines = 0;
          try {
            FileReader frd = new FileReader( fidFile );
            BufferedReader in = new BufferedReader( frd );

            String s;

            while( (s = in.readLine()) != null )
            {
                numberOfLines++;
                fileContent.append( s );
            }
          }
          catch(Exception ex)
          {
             System.err.println("Error during reading of file " + fidFile);
             ex.printStackTrace(System.err);
          }
          finally{
            return fileContent.toString().trim();
          }

  }

  public static String makeSqlSetString(int numItems)
  {
    // Build SQL set string
    StringBuffer sqlIO = new StringBuffer();
    sqlIO.append(" (");
    for(int i = 0; i < numItems; i++)
    {
      sqlIO.append("?");
      if(i < (numItems -1) )
        sqlIO.append(",");
    }
    sqlIO.append(") ");
    return sqlIO.toString();
  }



 public static String sampleStringFilter(String fidString)
 {
    Character comma = new Character( ',' );
    Character zero = new Character( '0' );
    Character one = new Character( '1' );
    Character two = new Character( '2' );
    Character three = new Character( '3' );
    Character four = new Character( '4' );
    Character five = new Character( '5' );
    Character six = new Character( '6' );
    Character seven = new Character( '7' );
    Character eight = new Character( '8' );
    Character nine = new Character( '9' );
    StringBuffer newFidBuffer = new StringBuffer();


    for( int i = 0; i < fidString.length(); i++ )
    {
      Character location = (Character)(fidString.charAt( i ));
      if( location.equals(comma) || location.equals(zero) || location.equals(one) ||
          location.equals(two) || location.equals(three) || location.equals(four) ||
           location.equals(five) || location.equals(six) || location.equals(seven) ||
          location.equals(eight) || location.equals(nine) )
      newFidBuffer.append( location );

    }

  if(newFidBuffer.length() > 0)
    return newFidBuffer.toString();
  else
    return null;
 }

  public static int anotherExampleCountChar(String fidString)
  {
       Character comma = new Character( ',' );
     int numberOfCommas = 0;
       for(int i = 0; i < fidString.length(); i++)
       {
         if(comma.equals( fidString.charAt(i) ))
            numberOfCommas++;
       }

     return numberOfCommas;
  }


  public static String getCommaSeparatedKeys( HashMap hashWithKeys )
  {
    StringBuffer ftypeIdsBuffer = null;
    int counterT = 0;

    if(hashWithKeys == null || hashWithKeys.size() < 1)
      return null;

    ftypeIdsBuffer = new StringBuffer( 200 );
    for( Object key : hashWithKeys.keySet() )
    {
      ftypeIdsBuffer.append( key );
      counterT += 1;
      if( counterT < hashWithKeys.size() )
        ftypeIdsBuffer.append( "," );
    }
    return ftypeIdsBuffer.toString();
  }

  public static String getCommaSeparatedIds( int[] fids )
  {
    StringBuffer ftypeIdsBuffer = null;
    int counterT = 0;

    if(fids == null || fids.length < 1)
      return null;

    ftypeIdsBuffer = new StringBuffer( 200 );
    for( int i = 0; i < fids.length; i++ )
    {
      ftypeIdsBuffer.append( fids[i] );
      counterT += 1;
      if( counterT < fids.length )
        ftypeIdsBuffer.append( "," );
    }
    return ftypeIdsBuffer.toString();
  }

  public static HashMap returnFidValuePairInfo(Connection myConnection, ArrayList fids )
  {
    HashMap fidValuePairHash = null;
    String theInStatement = null;
    Connection currentConnection = null;
    fidValuePairHash = new HashMap();
    Statement currentFidTextStatement = null;
    ResultSet currentFidTextResultSet = null;
    String valuePairQuery = "SELECT fid2attribute.fid theKey,  " +
            "concat(attNames.name, '=', attValues.value, '; ') text " +
            "FROM attNames, attValues, fid2attribute  WHERE " +
            "attNames.attNameId = fid2attribute.attNameId  AND " +
            "attValues.attValueId = fid2attribute.attValueId AND " +
            "fid2attribute.fid in (";

    Statement stmt = null;
    if(fids == null || fids.size() < 1)
    {
      return null;
    }

    theInStatement = DirectoryUtils.join(fids, ",");
    valuePairQuery += theInStatement + ")";

    try
    {
      String fidTextKey = null;
      String fidTextValue = null;
      currentConnection = myConnection;
      currentFidTextStatement = currentConnection.createStatement();
      currentFidTextResultSet = currentFidTextStatement.executeQuery(valuePairQuery);

      while( currentFidTextResultSet.next() )
      {
        fidTextKey = currentFidTextResultSet.getString("theKey");
        fidTextValue = currentFidTextResultSet.getString("text");
        if(fidValuePairHash.containsKey(fidTextKey))
        {
          String previousValue = (String)fidValuePairHash.get(fidTextKey);
          fidTextValue = previousValue + " " + fidTextValue;
        }
        fidValuePairHash.put(fidTextKey, fidTextValue);
      }
      currentFidTextResultSet.close() ;
      currentFidTextStatement.close();
    }
    catch(SQLException e3)
    {
      e3.printStackTrace(System.err);
    }
    finally
    {
      return fidValuePairHash;
    }
  }

  /*  This method is not used obsolete  MLGG
    This method is used in tabular view, don't remove it.
  */
  public static HashMap returnMultiValueHash(Connection myConnection, ArrayList fids )
  {

      HashMap fidValuePairHash = null;
      String theInStatement = null;
      Connection currentConnection = null;
      fidValuePairHash = new HashMap();
      Statement currentFidTextStatement = null;
      ResultSet currentFidTextResultSet = null;
      String valuePairQuery = "SELECT fid2attribute.fid fid, " +
              "fid2attribute.ftypeid ftypeid, " +
              "attNames.name name, attValues.value value " +
              "FROM attNames, attValues, fid2attribute  WHERE " +
              "attNames.attNameId = fid2attribute.attNameId  AND " +
              "attValues.attValueId = fid2attribute.attValueId AND " +
              "fid2attribute.fid in (";

      Statement stmt = null;
      if(fids == null || fids.size() < 1)
      {
        return null;
      }

      theInStatement = DirectoryUtils.join(fids, ",");
      valuePairQuery += theInStatement + ")";

      try
      {
          String fid = null;
          String ftypeId = null;
          String name = null;
          String value = null;
          currentConnection = myConnection;
          currentFidTextStatement = currentConnection.createStatement();
          currentFidTextResultSet = currentFidTextStatement.executeQuery(valuePairQuery);
          fidValuePairHash = new HashMap();

          while( currentFidTextResultSet.next() )
          {
              fid = currentFidTextResultSet.getString("fid");
              ftypeId = currentFidTextResultSet.getString("ftypeid");
              name = currentFidTextResultSet.getString("name");
              value = currentFidTextResultSet.getString("value");

              if(fidValuePairHash.containsKey(fid))
              {
                  HashMap tempHashMap = (HashMap)fidValuePairHash.get(fid);
                  HashMap valuePairs = (HashMap)tempHashMap.get("valuePairs");
                  if(valuePairs.containsKey(name))
                  {
                      ArrayList tempArray = (ArrayList)valuePairs.get(name);
                      tempArray.add(value);
                      valuePairs.put(name, tempArray);
                  }
                  else
                  {

                      ArrayList tempArray = new ArrayList(20);
                      tempArray.add(value);
                      valuePairs.put(name, tempArray);
                  }
                  tempHashMap.put("valuePairs", valuePairs);
                  if(!tempHashMap.containsKey("ftypeId"))
                      tempHashMap.put("ftypeId", ftypeId);
                  if(!tempHashMap.containsKey("action"))
                      tempHashMap.put("action", "1");
                  fidValuePairHash.put(fid, tempHashMap);
              }
              else
              {
                  HashMap tempHashMap = new HashMap();
                  HashMap valuePairs = new HashMap();
                  ArrayList tempArray = new ArrayList(20);
                  tempArray.add(value);
                  valuePairs.put(name, tempArray);
                  tempHashMap.put("valuePairs", valuePairs);
                  tempHashMap.put("ftypeId", ftypeId);
                  tempHashMap.put("action", "1");
                  fidValuePairHash.put(fid, tempHashMap);
              }
          }
          currentFidTextStatement.close();
      }
      catch (SQLException e3)
      {
          e3.printStackTrace(System.err);
      }
      finally
      {
          return fidValuePairHash;
      }
  }

  public static void deleteValuePairs(Connection myConnection, String refSeqId, ArrayList fids)
  {
    AttributeInserter inserter = new AttributeInserter(myConnection, refSeqId);
    inserter.deleteValuePairs(fids);
    inserter.terminateAttribute();
    inserter.finalFlushRecord();
  }

  /**
   *
   * @param myConnection
   * @param refSeqId
   * @param fid
   * @param ftypeId
   * @param valuesToAdd  HashMap of attribute name (String): attribute values (array list).  if an attribute
   * is mapped to multiple values (i.e., array list has multiple entry) , only the last one will be used ;   -- commented by Mark
   * @param action
   */
  public static void addValuePairs(Connection myConnection, String refSeqId, long fid, int ftypeId, HashMap valuesToAdd, int action)
  {
    AttributeInserter inserter = new AttributeInserter(myConnection, refSeqId);
    inserter.addValuePairs(fid, ftypeId, valuesToAdd, action);
    inserter.terminateAttribute();
    inserter.finalFlushRecord();
  }

  public static void addValuePairs(Connection myConnection, String refSeqId, long fid, int ftypeId, String comments, int action)
  {
    AttributeInserter inserter = new AttributeInserter(myConnection, refSeqId);
    int errorLevel = inserter.transformRawCommentsIntoValuePairs(comments);
    if(errorLevel == 6 || errorLevel == 0)
    {
      HashMap valuesToAdd = inserter.getValuePairs();
      inserter.addValuePairs(fid, ftypeId, valuesToAdd, action);
      inserter.terminateAttribute();
      inserter.finalFlushRecord();
    }
  }

  public static void addValuePairs(Connection myConnection, String refSeqId, ArrayList fids, int ftypeId, HashMap valuesToAdd, int action)
  {
    AttributeInserter inserter = new AttributeInserter(myConnection, refSeqId);
    inserter.addValuePairs(fids, ftypeId, valuesToAdd, action);
    inserter.terminateAttribute();
    inserter.finalFlushRecord();
  }

  public static void addValuePairs(Connection myConnection, String refSeqId, ArrayList fids, int ftypeId, String comments, int action)
  {
    AttributeInserter inserter = new AttributeInserter(myConnection, refSeqId);
    int errorLevel = inserter.transformRawCommentsIntoValuePairs(comments);
    if(errorLevel == 6 || errorLevel == 0)
    {
      HashMap valuesToAdd = inserter.getValuePairs();
      inserter.addValuePairs(fids, ftypeId, valuesToAdd, action);
      inserter.terminateAttribute();
      inserter.finalFlushRecord();
    }
  }

  public static void addValuePairs(Connection myConnection, String refSeqId, HashMap multiFids)
  {
      AttributeInserter inserter = new AttributeInserter(myConnection, refSeqId);

      Iterator  uniqueIterator = multiFids.entrySet().iterator() ;
      while(uniqueIterator.hasNext())
      {
          Map.Entry uniqueMap = (Map.Entry)uniqueIterator.next() ;
          String fid = (String)uniqueMap.getKey();
          HashMap fidValuePairHash = (HashMap)uniqueMap.getValue();
          String myComments = (String)fidValuePairHash.get("comments");
          int errorLevel = inserter.transformRawCommentsIntoValuePairs(myComments);
          if(errorLevel == 6 || errorLevel == 0)
          {
              HashMap valuePairs = inserter.getValuePairs();
              fidValuePairHash.put("valuePairs", valuePairs);
          }
          fidValuePairHash.put(fid, fidValuePairHash);
      }

      inserter.addValuePairs(multiFids);
      inserter.terminateAttribute();
      inserter.finalFlushRecord();
  }

  public static void addValuePairs(Connection myConnection, String refSeqId, HashMap multiFids, int multi)
  {
    AttributeInserter inserter = new AttributeInserter(myConnection, refSeqId);
    inserter.addValuePairs(multiFids);
    inserter.terminateAttribute();
    inserter.finalFlushRecord();
  }

  public static String getCurrentHost(HttpServletRequest request)
  {
    return request.getHeader("host").replaceFirst(":[0-9]+$", "") ;
  }

  public static String getCurrentPage(HttpServletRequest request)
  {
    String page = request.getRequestURI() ;
    String qs = request.getQueryString() ;
    if(qs != null && (qs.length() > 0))
    {
      page += ("?" + qs) ;
    }
    return page ;
  }

  public static String getCurrentUrl(HttpServletRequest request)
  {
    return getCurrentUrl(request, null) ;
  }

  public static String getCurrentUrl(HttpServletRequest request, HttpServletResponse response)
  {
    String host = GenboreeUtils.getCurrentHost(request) ;
    String page = GenboreeUtils.getCurrentPage(request) ;
    return "http://" + host + page ;
  }

  public static boolean goToRedirector(HttpServletRequest request, HttpServletResponse response)
  {
    String currUrl = GenboreeUtils.getCurrentUrl(request, response) ;
    String redirectTo = "/gbRedirect.rhtml?gbtgt=" + Util.urlEncode(currUrl);
    // System.err.println("GenboreeUtils.goToRedirector(HSR,HSR) => currUrl is: " + currUrl +
    //                    "\n                                      => redirectTo is: " + redirectTo +
    //                    "\n                                      => TIME: " + (new java.util.Date()).toString() +
    //                    "\n                                      => USER AGENT: " + request.getHeader("user-agent") +
    //                    "\n                                      => MEMORY: totalMem: " + Util.commify(Runtime.getRuntime().totalMemory()) + ", maxMem: " + Util.commify(Runtime.getRuntime().maxMemory()) + ", usedMem: " + Util.commify(MemoryUtil.usedMemory())) ;
    return GenboreeUtils.sendRedirect(response, redirectTo) ;
  }

  public static String returnRedirectString(HttpServletRequest request, HttpServletResponse response, String page)
  {
    String host = request.getHeader("host").replaceFirst(":[0-9]+$", "") ;
    return returnRedirectString(host, page) ;
  }

    public static String returnRedirectString(String host, String page)
    {
      String target = null;
      String newPage = null;
      String newHost = null;
      String staticPageRegect = "/java-bin/login.jsp";

      System.err.println( "\n\nARG: page: " + page + "\n\n") ;

      if(host != null && page != null && host.length() > 0 && page.length() > 0)
      {
        // Note any http/https at the front if provided
        boolean httpsGiven = false ;
        if( page.matches("^https://") ) {
          httpsGiven = true ;
        }

        // If page has http://domain.com at the front, remove it
        newPage = page.replaceFirst("http(?:s)://[^/]+", "");
        // Replace leading / chars at front of the page str
        newPage = newPage.replaceFirst("^/+", "") ;
        // If host has trailing / char, remove it
        newHost = host.replaceFirst("/+$", "");
        // If host has a port, strip it. *EVERYTHING* must go through the Apache/Lighttpd for proxying
        newHost = newHost.replaceFirst(":[0-9]+", "") ;

        if(page.indexOf(newHost) < 0)
        {
          target = ( ( httpsGiven ? "https://" : "http://" ) + newHost + "/" + newPage ) ;
        }
        else
        {
          if( ( page.indexOf("http:") > -1 ) || ( page.indexOf("https:") > -1 ) )
          {
            target = page;
          }
          else
          {
            target = ( ( httpsGiven ? "https://" : "http://" ) + newHost + staticPageRegect ) ;
          }
        }
      }
      return target ;
    }

    // Redirects to 'page' but saves current URL as the ultimate session target
    public static boolean sendRedirectSaveTarget(HttpSession mys, HttpServletRequest request, HttpServletResponse response, String page)
    {
      // 1. Get info to save the target
      String target = GenboreeUtils.getCurrentUrl(request, response) ;
      mys.setAttribute( "target", target );
      // 2. Redirect but send the session info to page
      return sendRedirect(request, response, page) ;
    }

    public static boolean sendRedirect(HttpServletRequest request, HttpServletResponse response, String page)
    {
      String url = null;
      String newPage ;
      String currPage = GenboreeUtils.getCurrentPage(request) ;

      if(page == null) // then use current path as page
      {
        page = newPage = currPage ;
      }
      else
      {
        newPage = page ;
      }

      if(request == null || page.length() < 1)
      {
        return false;
      }

      String host = GenboreeUtils.getCurrentHost(request) ;
      if(host == null)
      {
        return false;
      }
      url = GenboreeUtils.returnRedirectString(host, newPage);
      // System.err.println("GenboreeUtils#sendRedirect(HSR,HSR,S) => the url is: " + url +
      //                    "\n                                      page is: " + page  +
      //                    "\n                                      => TIME: " + (new java.util.Date()).toString() +
      //                    "\n                                      => USER AGENT: " + request.getHeader("user-agent") +
      //                    "\n                                      => MEMORY: totalMem: " + Util.commify(Runtime.getRuntime().totalMemory()) + ", maxMem: " + Util.commify(Runtime.getRuntime().maxMemory()) + ", usedMem: " + Util.commify(MemoryUtil.usedMemory())) ;
      try
      {
        response.sendRedirect(url);
      }
      catch(Exception ex)
      {
        System.err.println("Exception in GenboreeUtils#sendRedirect the page is " + page + " the host is " + host + " and the generated url is " + url);
        ex.printStackTrace(System.err);
      }
      return true;
    }

    // Redirect to current request uri
    public static boolean sendRedirect(HttpServletRequest request, HttpServletResponse response)
    {
      return sendRedirect(request, response, null) ;
    }

    public static boolean sendRedirect(HttpServletResponse response, String url)
    {
      try
      {
        response.sendRedirect(url);
      }
      catch(Exception ex)
      {
          System.err.println("Exception in GenboreeUtils#sendRedirect(HSR,S) => the url is " + url);
          ex.printStackTrace(System.err);
      }
      return true ;
    }

    public static HttpSession invalidateSession(HttpSession currSess, HttpServletRequest request, HttpServletResponse response, boolean makeNewSession)
    {
      HttpSession retVal = null ;
      if(currSess != null)
      {
        // Get current id
        String currSessId = currSess.getId() ;
        // System.err.println( "  GenboreeUtils.java => invalidating session id " + currSessId +
        //                     "\n                                      => TIME: " + (new java.util.Date()).toString() +
        //                     "\n                                      => USER AGENT: " + request.getHeader("user-agent") +
        //                     "\n                                      => MEMORY: totalMem: " + Util.commify(Runtime.getRuntime().totalMemory()) + ", maxMem: " + Util.commify(Runtime.getRuntime().maxMemory()) + ", usedMem: " + Util.commify(MemoryUtil.usedMemory())) ;
        // Clear the attributes in the session.
        // - we do this because it's not clear that invalidate() will free/clear the session
        // - if it doesn't, it won't be garbage collected because Tomcat has a pointer to ALL
        //   the session objects and will only let go once its inactivity timeout expires.
        Enumeration attrEnum = currSess.getAttributeNames() ;
        String currAttr = null ;
        Object currValue = null ;
        ArrayList<String> attrNames = new ArrayList<String>() ;
        while(attrEnum.hasMoreElements()) // Grab all the names first; then can delete safely, outside of active Enumeration
        {
          currAttr = (String)attrEnum.nextElement() ;
          attrNames.add(currAttr) ;
        }
        for(Iterator<String> iter = attrNames.iterator(); iter.hasNext(); )
        {
          currSess.removeAttribute(iter.next()) ;
        }
        // Invalidate current session:
        currSess.invalidate() ;
        // Ensure cookie gets deleted (this seems to be a problem on MSIE and
        // with multiple copies of the cookies appearing...)
        Cookie[] cks = request.getCookies() ;
        // Check each cookie...if it has a name of JSESSION, let's invalidate it
        // - this should catch them all and prevent some of the multiple cookie problems
        // - another approach might be to only delete the cookie(s) that also have
        //   our currSessId as their value...this would be more conservative.
        // - this probably doesn't work as intended because Tomcat alters this cookie itself
        //   before responding to the user
        //   . a work around for that is to set a javascript flag on the response that causes
        //     some javascript function to delete the cookie from the browser!
        if(cks != null)
        {
          for(int ii = 0; ii < cks.length; ii++)
          {
            String ckName = cks[ii].getName() ;
            if(ckName.equals("JSESSIONID"))
            {
              String ckValue = cks[ii].getValue() ;
              String ckPath = cks[ii].getPath() ;
              String ckDomain = cks[ii].getDomain() ;
              cks[ii].setMaxAge(0) ; // this deletes a cookie
              response.addCookie(cks[ii]) ; // send the cookie back with immediate expiration
            }
          }
        }
      }
      // Should we make a new session?
      if(makeNewSession)
      {
        retVal = request.getSession(true) ;
        // System.err.println("  GenboreeUtils.java => made a new session whose key is : " + retVal.getId() ) ;
      }
      MemoryUtil.forceGC(1,1) ;
      return retVal ;
    }

    public static boolean isBrowserAppCookieSet(HttpServletRequest request, HttpServletResponse response)
    {
      boolean retVal = false ;
      Cookie[] cks = request.getCookies() ;
      if(cks != null)
      {
        for(int ii = 0; ii < cks.length; ii++)
        {
          String ckName = cks[ii].getName() ;
          if(ckName.equals("GB_INBROWSER"))
          {
            retVal = true ;
            break ;
          }
        }
      }
      return retVal ;
    }

    public static String returnFullURL(HttpServletRequest request, String page)
    {
        String host = null;
        String url = null;
        if(request == null || page == null || page.length() < 1)
            return null;

        host = request.getHeader("host");
        if(host == null) return null;
        url = returnRedirectString(host, page);
        return url;
    }

    public static String joinArray(String[] myArray, String separator)
    {
        StringBuffer myBuffer = new StringBuffer( 200 );
        if(myArray == null) return null;

        for(int i = 0; i < myArray.length; i++)
        {
            myBuffer.append(myArray[i]);
            if(i < (myArray.length - 1) )
                myBuffer.append(separator);
        }
        return myBuffer.toString();
    }

    public static Vector splitBlockIntoLines(String outStr)
    {
        StringTokenizer strtokLines = null;
        Vector stringArray = null;
        String line = null;

        if(outStr == null) return null;

        strtokLines = new StringTokenizer(outStr, "\n");

        /** vector to store String tokens in **/
        stringArray = new Vector();

        while (strtokLines.hasMoreTokens())
        {
            line = strtokLines.nextToken();
            stringArray.addElement(line);
            line = null;
        }
        return stringArray;
    }

  public static String getContentOfUrl( String urlStr, boolean doHtmlStripping )
  {
    URL uu = null;
    StringBuffer outBuff = new StringBuffer();
    try
    {
      uu = new URL(urlStr);
        //in = new BufferedReader(new InputStreamReader(uu.openStream())) ;
        //String line ;
        //while((line = in.readLine()) != null)
        //{
        //  outBuff.append(line) ;
        //}
      try
      {
        InputStreamReader urlResultReader = new InputStreamReader(uu.openStream()) ;
        char[] inputBuff = new char[4*1024*1024] ;
        int numRead = 0 ;
        while(numRead >= 0)
        {
          numRead = urlResultReader.read(inputBuff, 0, inputBuff.length) ;
          if(numRead > 0)
          {
            outBuff.append(inputBuff, 0, numRead) ;
          }
        }
        urlResultReader.close() ;
      }
      catch(Exception ex)
      {
        ex.printStackTrace(System.err);
        System.err.println("GenboreeUtils#getContentOfUrl(S,b) encountered a problem reading an http response for: " + urlStr ) ;
        // see if we can continue...maybe just problem closing the reader?
      }
    }
    catch(Exception e)
    {
      e.printStackTrace(System.err);
      System.err.println("GenboreeUtils#getContentOfUrl encounter a generic exception with page " + urlStr );
      return "<P><FONT COLOR='red'>ERROR: the url " + urlStr + " is invalid. Cannot display it here.</FONT><P>&nbsp;" ;
    }

    String outStr = outBuff.toString();
    if(doHtmlStripping)
    {
        outStr = outStr.replaceAll("</?HEAD[^>]*>|</?head[^>]*>|</?Head[^>]*>", "");
        outStr = outStr.replaceAll("</?HTML[^>]*>|</?html[^>]*>|</?Html[^>]*>", "");
        outStr = outStr.replaceAll("</?BODY[^>]*>|</?body[^>]*>|</?Body[^>]*>", "");
        outStr = outStr.replaceAll("</?META[^>]*>|</?meta[^>]*>|</?Meta[^>]*>", "");
        outStr = outStr.replaceAll("<!DOCTYPE[^>]*>|<!doctype[^>]*|<!Doctype[^>]*", "");
    }
    return outStr;
  }


  public static final String GROUP_ID_X_HEADER = "X-GENBOREE-GROUP-ID" ;
  public static final String DATABASE_ID_X_HEADER = "X-GENBOREE-DATABASE-ID" ;
  public static final String GROUP_NAME_X_HEADER = "X-GENBOREE-GROUP-NAME" ;
  public static final String DATABASE_NAME_X_HEADER = "X-GENBOREE-DATABASE-NAME" ;
  public static final String PROJECT_ID_X_HEADER = "X-GENBOREE-PROJECT-ID" ;
  public static final String PROJECT_NAME_X_HEADER = "X-GENBOREE-PROJECT-NAME" ;

  public static String getContentOfUrl( String urlStr, boolean doHtmlStripping, Map headersMap, HttpSession session )
  {
    URL url = null;
    HttpURLConnection urlConn = null ;
    StringBuffer outBuff = new StringBuffer();
    try
    {
      url = new URL(urlStr);
      urlConn = (HttpURLConnection)url.openConnection() ;
      if(session != null)
      {
        String currGroupId = SessionManager.getSessionGroupId(session) ;
        String currGroupName = SessionManager.getSessionGroupName(session) ;
        String currDatabaseId = SessionManager.getSessionDatabaseId(session) ;
        String currDatabaseName = SessionManager.getSessionDatabaseDisplayName(session) ;
        String currProjectId = SessionManager.getSessionProjectId(session) ;
        String currProjectName = SessionManager.getSessionProjectName(session) ;
         System.err.println( "ARJ_DEBUG: GenboreeUtils.java#getContentofUrl(S,b,M,H) => current group/db info from session (out-going as X headers):" +
                "\n  - X-GENBOREE-GROUP-ID: " + currGroupId +
                "\n  - X-GENBOREE-GROUP-NAME: " + currGroupName +
                "\n  - X-GENBOREE-DATABASE-ID: " + currDatabaseId +
                "\n  - X-GENBOREE-DATABASE-NAME: " + currDatabaseName +
                "\n  - X-GENBOREE-PROJECT-ID: " + currProjectId +
                "\n  - X-GENBOREE-PROJECT-ID: " + currProjectName) ;
        if(currGroupId != null)
        {
          urlConn.setRequestProperty( GROUP_ID_X_HEADER, currGroupId) ;
        }
        if(currGroupName != null)
        {
          urlConn.setRequestProperty( GROUP_NAME_X_HEADER, currGroupName) ;
        }
        if(currDatabaseId != null)
        {
          urlConn.setRequestProperty( DATABASE_ID_X_HEADER, currDatabaseId) ;
        }
        if(currDatabaseName != null)
        {
          urlConn.setRequestProperty( DATABASE_NAME_X_HEADER, currDatabaseName) ;
        }
        if(currProjectId != null)
        {
          urlConn.setRequestProperty( PROJECT_ID_X_HEADER, currProjectId) ;
        }
        if(currProjectName != null)
        {
          urlConn.setRequestProperty( PROJECT_NAME_X_HEADER, currProjectName) ;
        }
      }

      // Get content (returned as String)
        //in = new BufferedReader(new InputStreamReader(urlConn.getInputStream())) ;
        //String line ;
        //while((line = in.readLine()) != null)
        //{
        //  outBuff.append(line) ;
        //}
      try
      {
        InputStreamReader urlResultReader = new InputStreamReader(urlConn.getInputStream()) ;
        char[] inputBuff = new char[4*1024*1024] ;
        int numRead = 0 ;
        while(numRead >= 0)
        {
          numRead = urlResultReader.read(inputBuff, 0, inputBuff.length) ;
          if(numRead > 0)
          {
            outBuff.append(inputBuff, 0, numRead) ;
          }
        }
        urlResultReader.close() ;
      }
      catch(Exception ex)
      {
        ex.printStackTrace(System.err);
        System.err.println("GenboreeUtils#getContentOfUrl(S,b,M,H) encountered a problem reading an http response for: " + urlStr ) ;
        // see if we can continue...maybe just problem closing the reader?
      }
      // Get headers (copied into headersMap)
      Map origHeaders = urlConn.getHeaderFields() ;
      Iterator mapIter = origHeaders.entrySet().iterator() ;
      while(mapIter.hasNext())
      {
        Map.Entry entryPair = (Map.Entry) mapIter.next() ;
        headersMap.put(entryPair.getKey(), entryPair.getValue()) ;
      }
      // Update session variablels if correct X-HEADERS are found:
      GenboreeUtils.updateSessionFromXHeaders(headersMap, session) ;
    }
    catch(Exception e)
    {
      e.printStackTrace(System.err);
      System.err.println("GenboreeUtils#getContentOfUrl encounter a generic exception with page " + urlStr );
      return "<P><FONT COLOR='red'>ERROR: the url " + urlStr + " is invalid. Cannot display it here.</FONT><P>&nbsp;" ;
    }

    String outStr = outBuff.toString();
    if(doHtmlStripping)
    {
      outStr = outStr.replaceAll("</?HEAD[^>]*>|</?head[^>]*>|</?Head[^>]*>", "");
      outStr = outStr.replaceAll("</?HTML[^>]*>|</?html[^>]*>|</?Html[^>]*>", "");
      outStr = outStr.replaceAll("</?BODY[^>]*>|</?body[^>]*>|</?Body[^>]*>", "");
    }
    return outStr;
  }

  public static void echoPostToURL(String urlStr, String postContentStr, Map resultHdrsMap, HttpSession session, PrintWriter out )
  {
    StringBuffer rhtmlResultBuff = new StringBuffer() ;
    BufferedReader in = null ;
    try
    {
      // ----------------------------------------------------------------------
      // Get external page as a POST, because maybe form data is huge (too big for GET)
      // 1. Make URL
      URL rhtmlUrl = new URL(urlStr) ;
      // 2. Open connection to URL
      HttpURLConnection rhtmlConn = (HttpURLConnection) rhtmlUrl.openConnection() ;
      // 3. Set outgoing X-HEADERS, if available (have to do this before output stream is connected)
      // 4. Set output method to POST and prep for us to write the POST content
      rhtmlConn.setRequestMethod("POST") ;
      rhtmlConn.setDoOutput(true) ;
      if(session != null)
      {
        String currGroupId = SessionManager.getSessionGroupId(session) ;
        String currGroupName = SessionManager.getSessionGroupName(session) ;
        String currDatabaseId = SessionManager.getSessionDatabaseId(session) ;
        String currDatabaseName = SessionManager.getSessionDatabaseDisplayName(session) ;
        String currProjectId = SessionManager.getSessionProjectId(session) ;
        String currProjectName = SessionManager.getSessionProjectName(session) ;
        System.err.println( "ARJ_DEBUG: GenboreeUtils#echoPostToURL(S,S,b,M,H) => current group/db info from session (out-going as X headers):" +
                "\n  - X-GENBOREE-GROUP-ID: " + currGroupId +
                "\n  - X-GENBOREE-GROUP-NAME: " + currGroupName +
                "\n  - X-GENBOREE-DATABASE-ID: " + currDatabaseId +
                "\n  - X-GENBOREE-DATABASE-NAME: " + currDatabaseName +
                "\n  - X-GENBOREE-PROJECT-ID: " + currProjectId +
                "\n  - X-GENBOREE-PROJECT-ID: " + currProjectName) ;
        if(currGroupId != null)
        {
          rhtmlConn.setRequestProperty( GROUP_ID_X_HEADER, currGroupId) ;
        }
        if(currGroupName != null)
        {
          rhtmlConn.setRequestProperty( GROUP_NAME_X_HEADER, currGroupName) ;
        }
        if(currDatabaseId != null)
        {
          rhtmlConn.setRequestProperty( DATABASE_ID_X_HEADER, currDatabaseId) ;
        }
        if(currDatabaseName != null)
        {
          rhtmlConn.setRequestProperty( DATABASE_NAME_X_HEADER, currDatabaseName) ;
        }
        if(currProjectId != null)
        {
          rhtmlConn.setRequestProperty( PROJECT_ID_X_HEADER, currProjectId) ;
        }
        if(currProjectName != null)
        {
          rhtmlConn.setRequestProperty( PROJECT_NAME_X_HEADER, currProjectName) ;
        }
      }
      PrintWriter rhtmlPostWriter = new PrintWriter(rhtmlConn.getOutputStream()) ;
      // 5. Write out the POST parameters:
      rhtmlPostWriter.println(postContentStr) ;
      // 6. Close the output stream so we can get the results
      rhtmlPostWriter.close() ;
      // 7. Get results from the external page:
      try
      {
        in = new BufferedReader(new InputStreamReader(rhtmlConn.getInputStream())) ;
        String line ;
//        int lcount = 0;
//        System.err.println("\n\nARJ_DEBUG: downloading...\n\n") ;
        while((line = in.readLine()) != null)
        {
//          System.err.println("" + (lcount+=1) + ". " + line) ;
          out.println(line) ;
        }
 
      }
      catch(Exception e)
      {
        e.printStackTrace(System.err);
        System.err.println("GenboreeUtils#echoContentOfUrl encounter a generic exception with page " + urlStr );
        try
        {
            out.print("\n\nERROR: the url " + urlStr + " is invalid. Cannot display it here.") ;
        }
        catch(Exception e1)
        {
            // No need to do more, error was already logged...we just can't tell the user due to the problem!
        }
      }
      finally
      {
        try
        {
            if (in != null) in.close();
        }
        catch(IOException ioe)
        {
            ioe.printStackTrace(System.err);
            System.err.println("A IOException on GenboreeUtils#echoContentOfUrl");
        }
      }

      // 8. Get HTTP HEADERS from external page:
      // Get headers (copied into headersMap)
      Map origHeaders = rhtmlConn.getHeaderFields() ;
      Iterator mapIter = origHeaders.entrySet().iterator() ;
      while(mapIter.hasNext())
      {
        Map.Entry entryPair = (Map.Entry) mapIter.next() ;
        resultHdrsMap.put(entryPair.getKey(), entryPair.getValue()) ;
      }
      // 9. Update group/database if correct X-HEADERS are found:
      GenboreeUtils.updateSessionFromXHeaders(resultHdrsMap, session) ;
      // ----------------------------------------------------------------------
    }
    catch(Exception e)
    {
      e.printStackTrace(System.err);
      System.err.println("GenboreeUtils#postToURL encounter a generic exception with page " + urlStr );
    }
  }



		// ** Gets the content of a URL using *POST*
		// - postContent must already be prepared (http name-value pairs, connected with &, as a String)
		// - does group/database sync via HTTP X-HEADERS going out (from the session object)
		// - gets incoming HTTP headers in case they are needed
		//   (puts them in headersMap, an object supplied by the caller that is usually just empty)
		// - tries to update the session using the incoming X-HEADERS from the external page
		//   (but all headers are returned in the resultHdrsMap variable)
		// - does rudimentary html stripping if asked (so can put contents on existing page)

  public static String postToURL(String urlStr, String postContentStr, boolean doHtmlStripping, Map resultHdrsMap, HttpSession session )
  {
    StringBuffer rhtmlResultBuff = new StringBuffer() ;
    try
    {
      // ----------------------------------------------------------------------
      // Get external page as a POST, because maybe form data is huge (too big for GET)
      // 1. Make URL
      URL rhtmlUrl = new URL(urlStr) ;
      // 2. Open connection to URL
      HttpURLConnection rhtmlConn = (HttpURLConnection) rhtmlUrl.openConnection() ;
      // 3. Set outgoing X-HEADERS, if available (have to do this before output stream is connected)
      // 4. Set output method to POST and prep for us to write the POST content
      rhtmlConn.setRequestMethod("POST") ;
      rhtmlConn.setDoOutput(true) ;
      if(session != null)
      {
        String currGroupId = SessionManager.getSessionGroupId(session) ;
        String currGroupName = SessionManager.getSessionGroupName(session) ;
        String currDatabaseId = SessionManager.getSessionDatabaseId(session) ;
        String currDatabaseName = SessionManager.getSessionDatabaseDisplayName(session) ;
        String currProjectId = SessionManager.getSessionProjectId(session) ;
        String currProjectName = SessionManager.getSessionProjectName(session) ;
        System.err.println( "ARJ_DEBUG: GenboreeUtils#postToURL(S,S,b,M,H) => current group/db info from session (out-going as X headers):" +
                "\n  - X-GENBOREE-GROUP-ID: " + currGroupId +
                "\n  - X-GENBOREE-GROUP-NAME: " + currGroupName +
                "\n  - X-GENBOREE-DATABASE-ID: " + currDatabaseId +
                "\n  - X-GENBOREE-DATABASE-NAME: " + currDatabaseName +
                "\n  - X-GENBOREE-PROJECT-ID: " + currProjectId +
                "\n  - X-GENBOREE-PROJECT-ID: " + currProjectName) ;
        if(currGroupId != null)
        {
          rhtmlConn.setRequestProperty( GROUP_ID_X_HEADER, currGroupId) ;
        }
        if(currGroupName != null)
        {
          rhtmlConn.setRequestProperty( GROUP_NAME_X_HEADER, currGroupName) ;
        }
        if(currDatabaseId != null)
        {
          rhtmlConn.setRequestProperty( DATABASE_ID_X_HEADER, currDatabaseId) ;
        }
        if(currDatabaseName != null)
        {
          rhtmlConn.setRequestProperty( DATABASE_NAME_X_HEADER, currDatabaseName) ;
        }
        if(currProjectId != null)
        {
          rhtmlConn.setRequestProperty( PROJECT_ID_X_HEADER, currProjectId) ;
        }
        if(currProjectName != null)
        {
          rhtmlConn.setRequestProperty( PROJECT_NAME_X_HEADER, currProjectName) ;
        }
      }
      PrintWriter rhtmlPostWriter = new PrintWriter(rhtmlConn.getOutputStream()) ;
      // 5. Write out the POST parameters:
      rhtmlPostWriter.println(postContentStr) ;
      // 6. Close the output stream so we can get the results
      rhtmlPostWriter.close() ;
      // 7. Get results from the external page:
        // BufferedReader rhtmlResultReader = new BufferedReader(new InputStreamReader(rhtmlConn.getInputStream()));
        // String resultLine ;
        // while((resultLine = rhtmlResultReader.readLine()) != null)
        // {
        //   rhtmlResultBuff.append(resultLine).append("\n") ;
        //  }
        //  rhtmlResultReader.close() ;
      try
      {
        InputStreamReader rhtmlResultReader = new InputStreamReader(rhtmlConn.getInputStream()) ;
        char[] inputBuff = new char[4*1024*1024] ;
        int numRead = 0 ;
        while(numRead >= 0)
        {
          numRead = rhtmlResultReader.read(inputBuff, 0, inputBuff.length) ;
          if(numRead > 0)
          {
            
            rhtmlResultBuff.append(inputBuff, 0, numRead) ;
          }
        }
        rhtmlResultReader.close() ;
      }
      catch(Exception ex)
      {
        ex.printStackTrace(System.err);
        System.err.println("GenboreeUtils#postToURL encountered a problem reading an http response for: " + urlStr ) ;
        // see if we can continue...maybe just problem closing the reader?
      }
      // 8. Get HTTP HEADERS from external page:
      // Get headers (copied into headersMap)
      Map origHeaders = rhtmlConn.getHeaderFields() ;
      Iterator mapIter = origHeaders.entrySet().iterator() ;
      while(mapIter.hasNext())
      {
        Map.Entry entryPair = (Map.Entry) mapIter.next() ;
        resultHdrsMap.put(entryPair.getKey(), entryPair.getValue()) ;
      }
      // 9. Update group/database if correct X-HEADERS are found:
      GenboreeUtils.updateSessionFromXHeaders(resultHdrsMap, session) ;
      // ----------------------------------------------------------------------
    }
    catch(Exception e)
    {
      e.printStackTrace(System.err);
      System.err.println("GenboreeUtils#postToURL encounter a generic exception with page " + urlStr );
      return "<P><FONT COLOR='red'>ERROR: the url " + urlStr + " is invalid. Cannot display it here.</FONT><P>&nbsp;" ;
    }
    String outStr = rhtmlResultBuff.toString();
    if(doHtmlStripping)
    {
      outStr = outStr.replaceAll("</?HEAD[^>]*>|</?head[^>]*>|</?Head[^>]*>", "");
      outStr = outStr.replaceAll("</?HTML[^>]*>|</?html[^>]*>|</?Html[^>]*>", "");
      outStr = outStr.replaceAll("</?BODY[^>]*>|</?body[^>]*>|</?Body[^>]*>", "");
    }
    return outStr ;
  }

    public static boolean updateSessionFromXHeaders(Map httpHeaders, HttpSession session )
    {
      boolean retVal = false ;

      if((httpHeaders == null) || httpHeaders.isEmpty())
      {
        return retVal ;
      }

      List xGroupIdValList = (List) httpHeaders.get(GROUP_ID_X_HEADER) ;
      List xDatabaseIdValList = (List) httpHeaders.get(DATABASE_ID_X_HEADER) ;
      List xGroupNameValList = (List) httpHeaders.get(GROUP_NAME_X_HEADER) ;
      List xDatabaseNameValList = (List) httpHeaders.get(DATABASE_NAME_X_HEADER) ;
      List xProjectIdValList = (List)httpHeaders.get(PROJECT_ID_X_HEADER) ;
      List xProjectNameValList = (List)httpHeaders.get(PROJECT_NAME_X_HEADER) ;

      // Header Priority (in case of inconsistency):  name < id
      // Since setSession*() methods set matching id -and- name at once, by id coming last, it will be (a) the priority and (b) with name-id in sync
      if(xGroupNameValList != null && !xGroupNameValList.isEmpty())
      {
        String xGroupVal = (String) xGroupNameValList.get(0) ;
        SessionManager.setSessionGroupName(session, xGroupVal) ;
        retVal = true ;
      }
      if(xGroupIdValList != null && !xGroupIdValList.isEmpty())
      {
        String xGroupVal = (String) xGroupIdValList.get(0) ;
        SessionManager.setSessionGroupId(session, xGroupVal) ;
        retVal = true ;
      }
      if(xDatabaseNameValList != null && !xDatabaseNameValList.isEmpty())
      {
        String xDatabaseVal = (String) xDatabaseNameValList.get(0) ;
        SessionManager.setSessionDatabaseId(session, xDatabaseVal) ;
        retVal = true ;
      }
      if(xDatabaseIdValList != null && !xDatabaseIdValList.isEmpty())
      {
        String xDatabaseVal = (String) xDatabaseIdValList.get(0) ;
        SessionManager.setSessionDatabaseId(session, xDatabaseVal) ;
        retVal = true ;
      }
      if(xProjectNameValList != null && !xProjectNameValList.isEmpty())
      {
        String xProjectVal = (String)xProjectNameValList.get(0) ;
        SessionManager.setSessionProjectInfo(session, xProjectVal, false) ;
        retVal = true ;
      }
      if(xProjectIdValList != null && !xProjectIdValList.isEmpty())
      {
        String xProjectVal = (String)xProjectIdValList.get(0) ;
        SessionManager.setSessionProjectInfo(session, xProjectVal, true) ;
        retVal = true ;
      }
      return retVal ;
    }

    public static void echoContentOfUrl( String urlStr, HttpSession session , JspWriter out)
    {
        URL url = null;
        BufferedReader in = null ;
        HttpURLConnection urlConn = null ;
        StringBuffer outBuff = new StringBuffer();
        try
        {
            url = new URL(urlStr);
            urlConn = (HttpURLConnection)url.openConnection() ;
            // Get content (returned as String)
            in = new BufferedReader(new InputStreamReader(urlConn.getInputStream())) ;
            String line ;
            int lcount = 0;
            // System.err.println("\n\nARJ_DEBUG: downloading...\n\n") ;
            while((line = in.readLine()) != null)
            {
              // System.err.println("" + (lcount+=1) + ". " + line) ;
              out.println(line) ;
            }
        }
        catch(Exception e)
        {
            e.printStackTrace(System.err);
            System.err.println("GenboreeUtils#echoContentOfUrl encounter a generic exception with page " + urlStr );
            try
            {
                out.print("\n\nERROR: the url " + urlStr + " is invalid. Cannot display it here.") ;
            }
            catch(IOException ioe)
            {
                // No need to do more, error was already logged...we just can't tell the user due to the problem!
            }
        }
        finally
        {
            try
            {
                if (in != null) in.close();
            }
            catch(IOException e1)
            {
                e1.printStackTrace(System.err);
                System.err.println("A IOException on GenboreeUtils#echoContentOfUrl");
            }
        }
        return ;
    }

    // NOTE: This version takes the response object
    // It assumes you want to subordinate the Content-Type and the Content-Disposition HTTP
    // headers to whatever the server at urlStr sets them to.
    public static void echoContentOfUrl( String urlStr, HttpSession session , JspWriter out, HttpServletResponse response)
    {
      URL url = null;
      BufferedReader in = null ;
      HttpURLConnection urlConn = null ;
      StringBuffer outBuff = new StringBuffer();
      try
      {
        url = new URL(urlStr);
        urlConn = (HttpURLConnection)url.openConnection() ;
        response.setContentType(urlConn.getContentType()) ;
        response.setHeader("Content-Disposition", urlConn.getHeaderField("Content-Disposition")) ;
        // Get content (returned as String)
        in = new BufferedReader(new InputStreamReader(urlConn.getInputStream())) ;
        String line ;
        int lcount = 0;
        // System.err.println("\n\nARJ_DEBUG: downloading...\n\n") ;
        while((line = in.readLine()) != null)
        {
          // System.err.println("" + (lcount+=1) + ". " + line) ;
          out.println(line) ;
        }
      }
      catch(Exception e)
      {
        e.printStackTrace(System.err);
        System.err.println("GenboreeUtils#echoContentOfUrl encounter a generic exception with page " + urlStr );
        try
        {
            out.print("\n\nERROR: the url " + urlStr + " is invalid. Cannot display it here.") ;
        }
        catch(IOException ioe)
        {
            // No need to do more, error was already logged...we just can't tell the user due to the problem!
        }
      }
      finally
      {
        try
        {
            if (in != null) in.close();
        }
        catch(IOException e1)
        {
            e1.printStackTrace(System.err);
            System.err.println("A IOException on GenboreeUtils#echoContentOfUrl");
        }
      }
      return ;
    }

    public static HashMap retrieveChromosomesInfo(String refseqId)
    {
        return retrieveChromosomesInfo(refseqId, Constants.GB_MAX_FREF_FOR_DROPLIST);
    }
    public static HashMap retrieveChromosomesInfo(String refseqId, int maxNumberEntries) // use -5 if want to remove limits
    {
        Connection tConn = null;
        DBAgent db = null;
        int totalFrefCount = -1;
        DbFref[] vFrefs = null;
        HashMap chromosomeProperties = null;
        String databaseName = null;

        databaseName = fetchMainDatabaseName(refseqId);
        if(databaseName == null)
            return null;

        try
        {
            db =  DBAgent.getInstance();
            tConn = db.getConnection(databaseName) ;

            totalFrefCount = DbFref.countAll(tConn) ;


            if(totalFrefCount < 1)
            {
                vFrefs = new DbFref[0] ;
            }
            else if(totalFrefCount <= maxNumberEntries || maxNumberEntries == -5) // -5 is without limits
            {
                vFrefs = DbFref.fetchAll( db.getConnection(databaseName) );
            }
            else // Too many entrypoints to get list and lengths for
            {
                vFrefs = new DbFref[0] ;
            }

            chromosomeProperties = new HashMap();

            for(int ii = 0; ii < vFrefs.length; ii++)
            {
                chromosomeProperties.put(vFrefs[ii].getRefname(),  vFrefs[ii].getRlength());
            }

            tConn.close();

        } catch (SQLException e)
        {
            e.printStackTrace(System.err);
        }
        finally
        {
            return chromosomeProperties;
        }
    }
    
    public static String getConfigFileName()
    {
      return (System.getenv("GENB_CONFIG") == null) ? (Constants.GENBOREE_ROOT + "/genboree.config.properties") : System.getenv("GENB_CONFIG") ;
    }
    
    public static String getNameLocalMachine()
    {

        String machineName = null;
        try {
            ReadConfigFile myConfig = new ReadConfigFile(propertiesFile);
            if (myConfig.getGoodFile()) {
                machineName = myConfig.getProps().getProperty("machineName");

            }
        } catch (IOException e) {
            System.err.println("DirectoryUtils#getNameLocalMachine: Unable to read properties file " + propertiesFile);
            e.printStackTrace(System.err);
        }

        return  machineName;
    }

    public static String getJsVer()
    {
        String jsVer = null;
        try {
            ReadConfigFile myConfig = new ReadConfigFile(propertiesFile);
            if (myConfig.getGoodFile()) {
                jsVer = myConfig.getProps().getProperty("jsVer");
            }
        } catch (IOException e) {
            System.err.println("DirectoryUtils#getJsVer: Unable to read properties file " + propertiesFile);
            e.printStackTrace(System.err);
        }

        return  jsVer;
    }

    public static String getBadPattern()
    {
        String badPattern = null;
        try {
            ReadConfigFile myConfig = new ReadConfigFile(propertiesFile);
            if (myConfig.getGoodFile()) {
                badPattern = myConfig.getProps().getProperty("badPattern");
            }
        } catch (IOException e) {
            System.err.println("DirectoryUtils#getBadPattern: Unable to read properties file " + propertiesFile);
            e.printStackTrace(System.err);
        }

        return  badPattern;
    }

    public static boolean generateFileWithLffHeaders(String myFile, String myRefSeqId, int genboreeUserId )
    {
        File filePtr = null;
        File parentDir = null;
        if(myFile == null || myRefSeqId == null)
        {
            System.err.println("fileName (" + myFile + ") or refSeqId (" + myRefSeqId + ") variable is null");
            return false;
        }


        filePtr = new File(myFile);
        parentDir = new File(filePtr.getParent());


        if(filePtr.exists() && filePtr.isDirectory())
        {
            System.err.println("fileName (" + myFile + ") is a directory");
            return false;

        }
        if(filePtr.exists() && !filePtr.canWrite())
        {
            System.err.println("Unable to write to file (" + myFile + ") wrong permissions");
            return false;
        }

        if(!parentDir.exists() || !parentDir.isDirectory())
        {
            System.err.println("Unable to write to file (" + myFile + ") wrong path parent directory does not exist");
            return false;
        }


        if(parentDir.exists() && !parentDir.canWrite())
        {
            System.err.println("Unable to write to file (" + myFile + ") wrong permissions on parent directory");
            return false;
        }


        PrintWriter fout = null;
        try {
            fout = fout = new PrintWriter( new FileWriter(myFile) );
        } catch (IOException e)
        {
            e.printStackTrace(System.err);
            return false;
        }
        String tempDatabaseName = fetchMainDatabaseName( myRefSeqId );
        if(tempDatabaseName != null)
        {
            AnnotationDownloader currentDownload = new AnnotationDownloader(  DBAgent.getInstance(),  myRefSeqId, genboreeUserId);
            currentDownload.setPrintAssemblySectionAlso(false);
            currentDownload.printChromosomes(fout);
        }
        else
        {
            System.err.println("unable to find a database for RefseqId = " + myRefSeqId);
        }
        fout.close();
        return true;
    }

    public static void fillAllEmptyGroupContext(String refseqId)
    {
        GroupAssigner groupAssigner = null;
        groupAssigner = new GroupAssigner( refseqId, null );
        groupAssigner.callMethodsForEmptyGroups();

        return;
    }

    public static void processGroupContextForGroup(String refseqId, String groupName, String typeid, String rid, boolean doSleep)
    {
        GroupAssigner groupAssigner = null;
        groupAssigner = new GroupAssigner( refseqId, null );
        groupAssigner.assignContextForSingleGroup(groupName, typeid, rid, doSleep );

        return;
    }

    public static void processGroupContextForGroup(String refseqId, String groupName, String typeid, String rid)
    {
        processGroupContextForGroup(refseqId, groupName, typeid,  rid,  true);
        return;
    }

    public static HashMap fetchGclasses(Connection databaseConnection)
    {
        HashMap htGclass;
        htGclass = new HashMap();
        DbGclass[] gcs = DbGclass.fetchAll( databaseConnection );
        for(int i=0; i<gcs.length; i++ )
        {
            htGclass.put( ""+gcs[i].getGclass(), gcs[i] );
        }
        return htGclass;
    }

    public static HashMap fetchTracks(Connection databaseConnection, String databaseName, int genboreeUserId )
    {
        HashMap htFtype = new HashMap();
        DbFtype[] tps = DbFtype.fetchAll( databaseConnection, databaseName, genboreeUserId );
        if( tps != null )
        {
            for(int i=0; i<tps.length; i++ )
            {
                DbFtype ft = tps[i];
                String methodUC = ft.getFmethod();
                methodUC = methodUC.toUpperCase();
                String sourceUC = ft.getFsource();
                sourceUC = sourceUC.toUpperCase();
                htFtype.put( methodUC+":"+sourceUC, ft );
            }
        }
        return htFtype;
    }

    public static HashMap fetchClass2ftypesRelation(Connection databaseConnection)
    {
        StringBuffer query = null;
        String qs = null;
        String previousSortingValue = null;
        query = new StringBuffer( 200 );

        HashMap gclass2ftypesHash = new HashMap();

        query.append("SELECT gclass.gclass myClass,  ftype.fmethod myMethod, ftype.fsource mySource ");
        query.append(", CONCAT('(',ftype.ftypeid,', ', gclass.gid, ')') myvalues ");
        query.append("FROM ftype, gclass, ftype2gclass WHERE ");
        query.append("ftype.ftypeid = ftype2gclass.ftypeid AND gclass.gid = ftype2gclass.gid ");
        query.append("order by ftype.ftypeid,gclass.gid");
        qs = query.toString();

        try
        {
            Statement stmt = databaseConnection.createStatement();
            ResultSet rs = stmt.executeQuery(qs);

            while( rs.next() )
            {
                String myClass = rs.getString("myClass");
                String myMethod = rs.getString("myMethod");
                String mySource = rs.getString("mySource");
                if(myClass == null || myMethod == null || mySource == null)
                {
                    continue;
                }
                myClass = myClass.toUpperCase();
                myMethod = myMethod.toUpperCase();
                mySource = mySource.toUpperCase();
                String myKey = myClass + ":" + myMethod + ":" + mySource;
                previousSortingValue = (String)gclass2ftypesHash.get(myKey);
                if(previousSortingValue == null)
                    gclass2ftypesHash.put(myKey, rs.getString("myValues"));
            }
            stmt.close();


        } catch( Exception ex ) {
            System.err.println("Exception during  quering the db GenboreeUtils#fetchClass2ftypesRelation()");
            System.err.println("The query is ");
            System.err.println(query.toString());
        }
        finally
        {
            return gclass2ftypesHash;
        }
    }

    public static DbGclass returnGclassCaseInsensitiveKey(String gclass, HashMap htGclass)
    {
        DbGclass tempRc = null;
        if( gclass == null ) return null;

        Iterator iter = htGclass.keySet().iterator();

        while (iter.hasNext())
        {
            String tempKey = (String) iter.next();
            if(gclass.equalsIgnoreCase(tempKey))
            {
                tempRc = (DbGclass) htGclass.get( tempKey );
                return tempRc;
            }
        }
        return null;
    }

    public static int fetchFtypeId(String method, String source, HashMap htFtype)
    {
        String  methodUC = null;
        String sourceUC = null;
        String ftKey = null;
        DbFtype ft = null;

        if(method == null || source == null || htFtype == null || htFtype.size() < 1) return -1;

        methodUC =  method.toUpperCase();
        sourceUC =  source.toUpperCase();

        ftKey = methodUC+":"+sourceUC;
        ft = (DbFtype) htFtype.get( ftKey );

        if(ft == null)
        {
            return -1;
        }
        else
        {
            return ft.getFtypeid();
        }
    }

    public static int fetchGid(String className, HashMap htGclass)
    {
        DbGclass rc = null;

        if(className == null || htGclass == null || htGclass.size() < 1) return -1;

        rc = returnGclassCaseInsensitiveKey(className, htGclass);

        if(rc == null)
        {
            return -1;
        }
        else
        {
            return rc.getGid();
        }
    }

    public static String extractExtraClasses(String originalComments)
    {
        String[] tokens = null;


        if(originalComments == null) return null;
        if(originalComments.indexOf(';') > -1)
            tokens = originalComments.split(";");
        else
        {
            tokens = new String[1];
            tokens[0] = originalComments;
        }

        for( int i = 0; i < tokens.length; i++)
        {
            String comment = tokens[i].trim();
            if(comment.startsWith("aHClasses="))
            {
                comment = comment.replaceFirst("aHClasses=", "");
                return comment;
            }
        }

        return null;
    }
    public static String removeExtraClasses(String originalComments)
    {
        String[] tokens = null;
        StringBuffer stringBuffer = null;

        if(originalComments == null) return null;

        stringBuffer = new StringBuffer( 200 );
        if(originalComments.indexOf(';') > -1)
            tokens = originalComments.split(";");
        else
        {
            tokens = new String[1];
            tokens[0] = originalComments;
        }

        for( int i = 0; i < tokens.length; i++)
        {
            String comment = tokens[i].trim();
            if(comment.startsWith("aHClasses=")) { }
            else
            {
                stringBuffer.append(comment);
                stringBuffer.append(";");
                if(i < (tokens.length - 1))
                {
                    stringBuffer.append(" ");
                }
            }
        }
        if(stringBuffer.length() > 0)
            return stringBuffer.toString();
        else
            return null;
    }

    public static int extractColorCodeFromComments(String comments)
    {
        String[] tokens = null;
        int colorCode = -1;

        if(comments == null) return -1;

        if(comments.indexOf("annotationColor=") > -1)
            tokens = comments.split(";");
        else
            return -1;

        for( int i = 0; i < tokens.length; i++)
        {
            String comment = tokens[i].trim();

            if(comment.startsWith("annotationColor="))
            {
                comment = comment.replaceFirst("annotationColor=", "");
                colorCode = extractColorIntValueFormColorValuePair(comment);
                return colorCode;
            }
        }

        return colorCode;
    }

    public static int extractDiplayCodeFromComments(String comments)
    {
        String[] tokens = null;
        int displayCode = -1;

        if(comments == null) return -1;

        if(comments.indexOf("annotationCode=") > -1)
            tokens = comments.split(";");
        else
            return -1;

        for( int i = 0; i < tokens.length; i++)
        {
            String comment = tokens[i].trim();

            if(comment.startsWith("annotationCode="))
            {
                comment = comment.replaceFirst("annotationCode=", "");
                displayCode = extractIntValueFormDisplayCode(comment);

                return displayCode;
            }
        }

        return displayCode;
    }
/* TODO modify this method when specs are in place 03/20/06 MLGG */
    public static int extractIntValueFormDisplayCode(String annotationCode)
    {
        return -1;
    }

    public static String cleanCommentsFromSpecialKeys(String comments, int ftypeId, String databaseName)
    {
        String newComments = null;
        String[] tokens = null;
        StringBuffer stringBuffer = null;



        if(comments == null) return null;

        stringBuffer = new StringBuffer( 200 );

        if(comments.indexOf(';') > -1)
            tokens = comments.split(";");
        else
        {
            tokens = new String[1];
            tokens[0] = comments;
        }

        for( int i = 0; i < tokens.length; i++)
        {
            String comment = tokens[i].trim();

            if(comment.startsWith("aHClasses="))
            {
                processCommentsWithExtraClasses(comment, ftypeId, databaseName);
            }
            else if(comment.startsWith("annotationColor=")) { }
            else if(comment.startsWith("annotationCode=")) { }
            else if(comment.startsWith("annotationAction=")){}
            else if(comment.startsWith("attributeAction=")){}
            else
            {
                stringBuffer.append(comment);
                stringBuffer.append("; ");
            }
        }
        if(stringBuffer.length() > 0)
            newComments = stringBuffer.toString();
        else
            newComments = null;

        return newComments;
    }

    public static int extractColorIntValueFormColorValuePair(String annotationColor)
    {
        String colorCodeHex = null;
        int intColorFromHex = -1;
        String newHex = null;

        if(annotationColor == null || annotationColor.length() < 1) return -1;

        colorCodeHex = annotationColor.replaceAll(" ", "");
        if(colorCodeHex.startsWith("#"))
        {
            newHex = colorCodeHex;
        }
        else if(colorCodeHex.indexOf(",") > -1)
        {
            String[] rgb = colorCodeHex.split(",");
            if(rgb.length != 3) return -1;

            String r = Integer.toHexString(Util.parseInt(rgb[0], 0));
            String g = Integer.toHexString(Util.parseInt(rgb[1], 0));
            String b = Integer.toHexString(Util.parseInt(rgb[2], 0));
            newHex = "#" + r + g + b;
        }
        else
        {
            HashMap colors = GenboreeUtils.getColorCode();
            String tempColorCode = colorCodeHex.replaceAll(" ", "").toUpperCase();

            if(colors != null && colors.containsKey(tempColorCode) )
                newHex = (String)colors.get(tempColorCode);
            else
                newHex = colorCodeHex;
        }


        colorCodeHex = newHex.replaceFirst("#", "");

        if(colorCodeHex.length() == 6)
        {
            intColorFromHex = Integer.parseInt(colorCodeHex, 16);
        }
        else
            return -1;

        return  intColorFromHex;
    }


    public static String mysqlEscapeSpecialChars( String s )
    {
        if(s == null || s.length() < 1) return "";

        StringBuffer sb = new StringBuffer( s );
        StringBuffer rc = new StringBuffer();
        for( int i=0; i<sb.length(); i++ )
        {
            char c = sb.charAt(i);
//            if( c=='\\' || c=='\'' || c=='\"' || c== '%') rc.append( '\\' );
            if( c=='\\' || c=='\'' || c=='\"') rc.append( '\\' );
            rc.append( c );
        }
        return rc.toString();
    }

    public static String generateUniqueKey(String tempKey)
    {
        String reservedKey = null;

        if(tempKey == null || tempKey.length() < 1) return null;

        try
        {
            MessageDigest md = MessageDigest.getInstance( "MD5" );
            md.update( tempKey.getBytes() );
            byte[] dg = md.digest();
            String outc = "";
            for( int i=0; i<dg.length; i++ )
            {
                String hc = Integer.toHexString( (int)dg[i] & 0xFF );
                while( hc.length() < 2 ) hc = "0" + hc;
                outc = outc + hc;
            }
            reservedKey = outc;
        }
        catch( Exception ex )
        {
            System.err.println("Exception caught in GenboreeUtils.generateUniqueKey for" +
                    "tempKey = " + tempKey);
        }
        finally
        {
            return reservedKey;
        }
    }




    public static boolean processCommentsWithExtraClasses(String comments, int ftypeId, String databaseName)
    {
        String extraClasses = null;
        String[] tokens = null;
        DBAgent db = null;
        Connection databaseConnection = null;
        HashMap htGclass = null;


        if(comments == null || comments.length() < 1) return false;

        try
        {
            db =  DBAgent.getInstance();
            databaseConnection = db.getConnection(databaseName) ;
        } catch (SQLException e)
        {
            e.printStackTrace(System.err);
        }

        extraClasses = comments.replaceFirst("aHClasses=", "");
        htGclass = fetchGclasses(databaseConnection);

        if(extraClasses != null)
        {
            tokens = extraClasses.split(",");
        }

        if(tokens != null)
        {
            for(int i = 0; i < tokens.length; i++)
            {
                DbGclass newgclass = null;
                if(tokens[i] == null || tokens[i].length() < 1) continue;

                if(!htGclass.containsKey(tokens[i]))
                    newgclass = insertAndReturnNewGclass( tokens[i] , databaseConnection );

                if(newgclass != null)
                {
                    htGclass.put( tokens[i], newgclass);
                }
            }
        }

        Iterator iter = htGclass.keySet().iterator();
        while (iter.hasNext())
        {
            DbGclass newgclass = null;
            String tempKey = (String) iter.next();
            newgclass = (DbGclass)htGclass.get(tempKey);
            insertNewFtype2Gclass(ftypeId, newgclass.getGid(), databaseConnection);
        }

        try{
               databaseConnection.close();
        }catch(Exception e)
        {
            e.printStackTrace(System.err);
        }

        return true;
    }


    public static HashMap fetchHashWithAllTracks(Connection databaseConnection)
    {
        ResultSet rs;
        String qs = null;
        HashMap ftypeHash = null;
        Statement stmt = null;


        qs = "SELECT ftypeid, fmethod, fsource FROM ftype" ;


        ftypeHash = new HashMap();

        try {
            stmt = databaseConnection.createStatement();
            rs = stmt.executeQuery(qs);

            while( rs.next() )
            {
                String ftypeid = rs.getString("ftypeid");
                String fmethod = rs.getString("fmethod");
                String fsource = rs.getString("fsource");
                String ftypeValue = fmethod + ":" + fsource;
                ftypeHash.put( ftypeid, ftypeValue );
            }
            stmt.close();
        } catch (SQLException e) {
            System.err.println("There has been an exception #GenboreeUtils:fetchHashTracks");
            System.err.println("and the query is " + qs);
        }
        finally
        {
            return ftypeHash;
        }
    }



    public static boolean recalculateFbin(Connection databaseConnection, long maxFbin)
    {
        boolean rc = false;

        try
        {
            long updMaxFbin = maxFbin;
            long fb = 0L;
            Statement stmt = databaseConnection.createStatement();
            ResultSet rs = stmt.executeQuery( "SELECT MAX(fbin) FROM fdata2" );
            if( rs.next() )
            {
                fb = rs.getLong(1);
                if( fb > updMaxFbin ) updMaxFbin = fb;
            }
            rs = stmt.executeQuery( "SELECT MAX(fbin) FROM fdata2_cv" );
            if( rs.next() )
            {
                fb = rs.getLong(1);
                if( fb > updMaxFbin ) updMaxFbin = fb;
            }
            rs = stmt.executeQuery( "SELECT MAX(fbin) FROM fdata2_gv" );
            if( rs.next() )
            {
                fb = rs.getLong(1);
                if( fb > updMaxFbin ) updMaxFbin = fb;
            }
            maxFbin = 1000000L;
            while( updMaxFbin > maxFbin )
            {
                maxFbin *= 10;
                if( maxFbin < 1000000L ) break;
            }
            stmt.executeUpdate( "UPDATE fmeta SET fvalue='"+maxFbin+"' WHERE fname='MAX_BIN'" );
            stmt.close();

            rc = true;
        } catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("There has been an exception #GenboreeUtils:recalculateFbin");
        }

        return rc;
    }

    /* TODO This method is kind of stupid I need to rewrite
    was quickly modified from Andrei old code */
    public static String[] fetchClassesInFtypeId(Connection databaseConnection, String ftypeId)
    {
        ResultSet rs = null;
        String qs = null;
        HashMap htGclass = null;
        int a = 0;
        String listOfGclasses[] = null;
        Statement stmt;

        qs = "SELECT distinct gclass.gclass from gclass, ftype2gclass, ftype where gclass.gid = " +
                "ftype2gclass.gid AND ftype.ftypeid = ftype2gclass.ftypeid AND ftype.ftypeid = " +
                ftypeId ;

        htGclass = new HashMap();
        try {
            stmt = databaseConnection.createStatement();
            rs = stmt.executeQuery( qs );
            while( rs.next() )
            {
                htGclass.put(rs.getString(1), rs.getString(1));
            }

            listOfGclasses = new String[htGclass.size()];

            Iterator iter = htGclass.keySet().iterator();

            a = 0;
            while (iter.hasNext())
            {
                String tempKey = (String) iter.next();
                listOfGclasses[a] = tempKey;
                a++;
            }

        } catch( Exception ex ) {
            System.err.println("There has been an exception on #GenboreeUtils:fetchClassesInFtypeId " +
                    "and the query is " + qs);
        }
        finally
        {
            return listOfGclasses;
        }
    }

    public static HashMap getTrackName2FtypeObject(String refSeqId, String databaseName)
    {
	    return getTrackName2FtypeObject(refSeqId, databaseName, true);
    }

    public static HashMap getTrackName2FtypeObject( String refSeqId, String databaseName, boolean doCache )
    {
      DBAgent db = null;
      ResultSet rs = null;
      String qs = "SELECT ftypeid, fmethod, fsource FROM ftype";
      HashMap ftypeHash = null;
      Statement stmt = null;
      Connection conn = null;
      String ftype[];
      String uploads[] = null;
      String[] allUrls = null;

      try
      {
        ftypeHash = new HashMap();
        db = DBAgent.getInstance();

         uploads = GenboreeUpload.returnDatabaseNames( db, refSeqId );


        if( doCache )
          conn = db.getConnection(databaseName);
        else
          conn = db.getNoCacheConnection( databaseName  );

        stmt = conn.createStatement();
        rs = stmt.executeQuery( qs );

        while( rs.next() )
        {
          int ftypeId = rs.getInt( "ftypeid" );
          String fmethod = rs.getString( "fmethod" );
          String fsource = rs.getString( "fsource" );
          ftype = new String[2];
          ftype[ 0 ] = fmethod;
          ftype[ 1 ] = fsource;
          DbFtype ft = new DbFtype();
          ft.setFmethod( fmethod );
          ft.setFsource( fsource );
          ft.setFtypeid( ftypeId );
          ft.setDatabaseName( databaseName );
          String[] Gclasses = DbGclass.fetchGClasses( db, uploads, fmethod, fsource );
          ft.setBelongToAllThisGclasses( Gclasses );
          ft.setUploadId( fetchUploadIdFromRefSeqIdDbName( db, refSeqId, databaseName) );
          allUrls = GenboreeUpload.getUrlsFromFtype( db, uploads, fmethod, fsource );
          if( allUrls != null )
            ft.setAllUrl( allUrls[ 0 ], allUrls[ 1 ], allUrls[ 2 ] );
          ftypeHash.put( ft.toString(), ft );
        }


      } catch( SQLException e )
      {
        e.printStackTrace(System.err);
        System.err.println( "There has been an exception #GenboreeUtils:getTrackName2FtypeId" );
        System.err.println( "and the query is " + qs );
      }
      finally
      {
        db.safelyCleanup( rs, stmt, conn );
        return ftypeHash;
      }
    }




      public static boolean isDatabaseUsingNewFormat(String databaseName)
    {
      return isDatabaseUsingNewFormat(databaseName, true);
    }

    public static boolean isDatabaseUsingNewFormat(String databaseName, boolean doCache)
    {
        DBAgent db = null;
        String qs = null;
        String valuePairs = "n";
        PreparedStatement pstmt = null;
        ResultSet rs = null;
        Connection conn = null;
        qs = "SELECT useValuePairs FROM refseq where databaseName = ?";

        try
        {
            db =  DBAgent.getInstance();
            if( doCache )
              conn = db.getConnection();
            else
              conn = db.getNoCacheConnection( null );

            pstmt = conn.prepareStatement( qs );
            pstmt.setString( 1,  databaseName);
            rs = pstmt.executeQuery();
            if( rs.next() )
                valuePairs = rs.getString("useValuePairs");
        } catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("Exception trying to find useValuePaies for database = " + databaseName);
        }
        finally
        {
            db.safelyCleanup( rs, pstmt, conn );
            if(valuePairs.equalsIgnoreCase("y"))
                return true;
            else
                return false;
        }

    }

    public static void updateVPDatabase(String databaseName, boolean newStyle)
    {
        DBAgent db = null;
        String qs = null;
        String valuePairs = "n";
        Statement stmt = null;
        Connection conn = null;
        if(newStyle)
            valuePairs = "y";

        qs = "UPDATE refseq SET useValuePairs = '" + valuePairs + "' where databaseName = '" + databaseName + "'";

        try
        {
            db =  DBAgent.getInstance();
            conn = db.getConnection();
            stmt = conn.createStatement();
            stmt.executeUpdate(qs);
            stmt.close();
            conn.close();
        } catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("Exception trying to update useValuePaies for database = " + databaseName);
        }


    }





    /**
     * Retrieves attribute name:values pairs from database
     * @param fid  fdata id
     * @param con Connection
     * @return String of concatenated name:values pairs if exist, null otherwise
     * @throws SQLException if the passed connection is null or closed
     */

    public static String  findAVPByFid(Connection con, int fid) throws SQLException  {
        if (fid <=0 ){
            System.err.println (" invalid fid  in findAVPByFid(con, fid); ");
            return null;
        }

        if (con == null || con.isClosed()) {
            throw new SQLException ("Connection failure to server database " );
        }

        String value = "";
        String sql = "SELECT  concat(attNames.name, '=', attValues.value, '; ') text " +
                "FROM attNames, attValues, fid2attribute  WHERE " +
                "attNames.attNameId = fid2attribute.attNameId  AND " +
                "attValues.attValueId = fid2attribute.attValueId AND " +
                "fid2attribute.fid = ? ";
        try {
            PreparedStatement stms = con.prepareStatement(sql);
            stms.setInt(1, fid);
            ResultSet rs  = stms.executeQuery();

            while ( rs.next())
                value = value + " " + rs.getString(1);

            if (value.equals(""))
                value = null;
            rs.close();
            stms.close();
        }
        catch (SQLException e3) {
            e3.printStackTrace();

        }

        return value;
    }

    /**
     * retrieves information on whether a database is using attribute:value  pairs
     * @param refseqId   database id
     * @param db  DBAgent object  for making db connection
     * @return true if the database is set to y , false if not
     * @throws SQLException
     * @since Sept 20, 2006
     * @exception SQLException : db connection failure
     */

    public static boolean isDatabaseUseAVP (int refseqId, DBAgent db) throws SQLException {
        boolean useAVP = false;
        if (db==null)
            db=  DBAgent.getInstance();

        Connection con = db.getConnection();
        if (con== null || con.isClosed()){
            throw new SQLException ("Connection failure to server database " );
        }
        PreparedStatement stms = con.prepareStatement("select useValuePairs from refseq where refSeqId = ? ");
        stms.setInt(1, refseqId);
        ResultSet rs =stms.executeQuery();
        String x = "n";
        if (rs.next())
            x = rs.getString(1);
        rs.close();
        stms.close();
        if (x.compareTo("y")==0)
            useAVP = true;

        return useAVP;
    }

    public static boolean isRefSeqIdUsingNewFormat(String refSeqId)
    {
        DBAgent db = null;
        String qs = null;
        String valuePairs = "n";
        PreparedStatement pstmt = null;
        ResultSet rs = null;
        Connection conn = null;
        qs = "SELECT useValuePairs FROM refseq where refSeqId = ?";

        try
        {
            db =  DBAgent.getInstance();
            conn = db.getConnection();
            pstmt = conn.prepareStatement( qs );
            pstmt.setString( 1,  refSeqId);
            rs = pstmt.executeQuery();
            if( rs.next() )
                valuePairs = rs.getString("useValuePairs");
            db.safelyCleanup( rs, pstmt, conn );
        } catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("Exception trying to find find useValuePaies for  refseqId = " + refSeqId);
        }
        finally{
            if(valuePairs.equalsIgnoreCase("y"))
                return true;
            else
                return false;
        }

    }



    public static HashMap fetchFtypeIdToGclasses(Connection databaseConnection )
    {
        HashMap ftypeIdToGclasses = null;
        HashMap allFtypes = null;

        allFtypes = fetchHashWithAllTracks( databaseConnection );

        ftypeIdToGclasses = new HashMap();


        Iterator iter = allFtypes.keySet().iterator();
        while (iter.hasNext())
        {
            String ftypeId = (String) iter.next();
            String[] classNames =  fetchClassesInFtypeId(databaseConnection, ftypeId);
            if(classNames != null)
                ftypeIdToGclasses.put( ftypeId, classNames );
        }

        return ftypeIdToGclasses;
    }

    public static String fetchAllClassesForAFtypeId(int ftypeId, String databaseName, String mainClass)
    {
        String[] gclasses = null;
        int sizeOfClasses = 0;
        StringBuffer gclassBuffer = null;
        DBAgent db = null;
        Connection databaseConnection = null;
        HashMap ftypeIdsToGclassesHash = null;
        boolean removeMainClass = false;
        String aHClasses = null;

        if(ftypeId < 1|| databaseName == null) return null;

        try
        {
            db =  DBAgent.getInstance();
            databaseConnection = db.getConnection(databaseName) ;
        } catch (SQLException e)
        {
            e.printStackTrace(System.err);
        }

        if(mainClass != null && mainClass.length() > 0)
            removeMainClass = true;

        ftypeIdsToGclassesHash = fetchFtypeIdToGclasses(databaseConnection );
        gclasses = (String[])ftypeIdsToGclassesHash.get("" + ftypeId);

        if(removeMainClass && gclasses.length > 1)
        {
            String[] tempGclasses = new String[gclasses.length];
            int tempCounter = 0;
            for(int i = 0; i < gclasses.length; i++)
            {
                if(!gclasses[i].equalsIgnoreCase(mainClass))
                {
                    tempGclasses[tempCounter] = gclasses[i];
                    tempCounter++;
                }
            }
            gclasses = tempGclasses;
        }
        else if(removeMainClass && gclasses.length <= 1)
            gclasses = null;


        if(gclasses == null)
            return null;

        sizeOfClasses = gclasses.length;

        if(sizeOfClasses < 2)
            return null;

        gclassBuffer = new StringBuffer( 200 );
        gclassBuffer.append(" aHClasses=");
        for(int ii = 0; ii < sizeOfClasses; ii++)
        {
            if(gclasses[ii] != null)
                gclassBuffer.append(gclasses[ii]);

            if(ii < (sizeOfClasses -1))
                gclassBuffer.append(",");
        }
        gclassBuffer.append("; ");

        aHClasses = gclassBuffer.toString();
        aHClasses = aHClasses.replaceFirst(",; ", "; ");
        aHClasses = aHClasses.replaceAll(",,", ",");

        try{
               databaseConnection.close();
        }catch(Exception e)
        {
            e.printStackTrace(System.err);
        }

        return aHClasses;
    }

    public static int fetchClass2Ftypeid(String className, String method, String source, HashMap gclass2ftypesHash)
    {
        String methodUC = null;
        String sourceUC = null;
        String classNameUC = null;
        String ftype2gclassValue = null;
        String myKey = null;

        if(method == null || source == null ||className == null || gclass2ftypesHash == null || gclass2ftypesHash.size() < 1) return -1;

        methodUC =  method.toUpperCase();
        sourceUC =  source.toUpperCase();
        classNameUC = className.toUpperCase();

        myKey = classNameUC + ":" + methodUC + ":" + sourceUC;
        ftype2gclassValue = (String)gclass2ftypesHash.get(myKey);

        if(ftype2gclassValue == null)
        {
            return -1;
        }
        else
        {
            return Util.parseInt(ftype2gclassValue, -1);
        }
    }

    public static HashMap insertNewFtype2Gclass(int ftypeid, int gid, Connection databaseConnection)
    {
        StringBuffer query = null;
        String qs = null;
        HashMap gclass2ftypesHash = null;

        if(ftypeid < 1 || gid < 1 )
            return  fetchClass2ftypesRelation(databaseConnection);

        query = new StringBuffer();
        query.append("INSERT IGNORE INTO ftype2gclass (ftypeid, gid) VALUES ( ");
        query.append(ftypeid).append(",").append(gid).append(" )");
        qs = query.toString();

        try {
            Statement stmt = databaseConnection.createStatement();
            stmt.executeUpdate(qs);
            stmt.close();

            gclass2ftypesHash = fetchClass2ftypesRelation(databaseConnection);

        } catch (SQLException e) {
            e.printStackTrace(System.err);
        }finally
        {
            return gclass2ftypesHash;
        }
    }

    public static HashMap insertNewFtype( String method, String source, Connection databaseConnection, String databaseName, int genboreeUserId )
    {
        HashMap htFtype = null;
        DbFtype ft = null;

        ft = new DbFtype();
        ft.setFmethod( method );
        ft.setFsource( source );
        ft.setDatabaseName(databaseName);
        ft.insert( databaseConnection);

        htFtype = fetchTracks(databaseConnection, databaseName, genboreeUserId );

        return htFtype;
    }

    public static HashMap insertNewGclass(String gclass, Connection databaseConnection )
    {
        HashMap htGclass = null;
        if(gclass == null)
            return null;
        DbGclass rc = null;
        rc = new DbGclass();
        rc.setGclass( gclass );
        rc.insert( databaseConnection );
        htGclass = fetchGclasses(databaseConnection);
        return htGclass;
    }

    public static DbGclass insertAndReturnNewGclass(String gclass, Connection databaseConnection )
    {
        DbGclass rc = null;

        if(gclass == null) return null;

        rc = new DbGclass();
        rc.setGclass( gclass );
        rc.insert( databaseConnection );
        return rc;
    }

  public static boolean verifyIfDabaseExistInGenboree(String databaseName, DBAgent db)
  {
    Statement stmt = null;
    ResultSet rs = null;
    Connection conn = null;
    String uploadQuery = "SELECT uploadId FROM upload WHERE databaseName = '" + databaseName + "' LIMIT 1";
    String refseqQuery = "SELECT refSeqId FROM refseq WHERE databaseName = '" + databaseName + "'";
    String database2HostQuery = "SELECT id FROM database2host WHERE  databaseName = '" + databaseName + "'";
    int uploadId = -1;
    int refseqId = -1;
    int database2HostId = -1;
    boolean databaseExist = false;

    try
    {
      conn = db.getConnection();
      stmt = conn.createStatement();
      rs = stmt.executeQuery(uploadQuery);
      if(rs.next())
      {
        uploadId = rs.getInt("uploadId");
      }
      rs = stmt.executeQuery(refseqQuery);
      if(rs.next())
      {
        refseqId = rs.getInt("refSeqId");
      }
      rs = stmt.executeQuery(database2HostQuery);
      if(rs.next())
      {
        database2HostId = rs.getInt("id");
      }
      if(database2HostId > 0 && refseqId > 0 && uploadId > 0)
      {
        databaseExist = true;
      }
    }
    catch(Exception ex)
    {
      ex.printStackTrace(System.err);
      System.err.println("ERROR: GenboreeUtils.verifyIfDabaseExistInGenboree(S,D) => Exception trying to find if database " + databaseName +  " exists");
      System.err.println("    queries:\n" + uploadQuery + "\n" + refseqQuery + "\n" + database2HostQuery );
    }
    finally // safely clean up
    {
      db.safelyCleanup(rs, stmt, conn) ;
    }
    return databaseExist;
  }

    public static boolean verifyIfDabaseLookLikeGenboree_r_Type(Connection myConnection, String databaseName)
    {
        String[] tableNames = Constants.genboreeTables;
        HashMap tablesPresent = new HashMap();
        try {
            Statement stmt = myConnection.createStatement();
            ResultSet rs = stmt.executeQuery( "Show tables" );
            while( rs.next())
            {
                String descripTable;
                descripTable = rs.getString(1);
                tablesPresent.put(descripTable, descripTable);
            }
            stmt.close();
        } catch( Exception ex )
        {
            ex.printStackTrace(System.err);
        }


        for(int i = 0; i < tableNames.length; i++)
        {
            String tempTableName = tableNames[i];
            if(!tablesPresent.containsKey(tempTableName))
            {
                System.err.println("DatabaseName ("+ databaseName +
                        ") does not look like a genboree database. Table "
                        + tempTableName + " is not present!");
                return false;
            }
        }

        return true;
    }


    public static String getIpAddressOfLocalMachine()
    {

        String ipAddress = null;
        try {
            ReadConfigFile myConfig = new ReadConfigFile(propertiesFile);
            if (myConfig.getGoodFile()) {
                String machineName =  machineName = myConfig.getProps().getProperty("machineName");
                ipAddress = InetAddress.getByName( machineName ).getHostAddress();
            }
        } catch (IOException e) {
            System.err.println("Unable to read properties file " + propertiesFile);
            e.printStackTrace(System.err);
        }

        return  ipAddress;
    }

    public static String fetchGroupIdFromRefSeqId(String refseqId)
    {
        DBAgent db = null;
        String qs = null;
        String groupId = null;
        PreparedStatement pstmt = null;
        ResultSet rs = null;
        Connection conn = null;
        qs = "SELECT groupId FROM grouprefseq WHERE " +
                "grouprefseq.refSeqId = ?";

        try
        {
            db =  DBAgent.getInstance();
            conn = db.getConnection();
            pstmt = conn.prepareStatement( qs );
            pstmt.setString( 1,  refseqId);
            rs = pstmt.executeQuery();
            if( rs.next() )
                groupId = rs.getString("groupId");
        } catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("Exception trying to find groupId using query " +
                    qs + " where refseqId = " + refseqId);
        }
        finally{
            db.safelyCleanup( rs, pstmt, conn );
            return groupId;
        }
    }

    public static String fetchGroupId(String refseqId, String genboreeUserId )
    {
         return fetchGroupId(refseqId, genboreeUserId, true);
    }

    public static String fetchGroupId(String refseqId, String genboreeUserId, boolean doCache)
    {
        DBAgent db = null;
        String qs = null;
        String groupId = null;
        PreparedStatement pstmt = null;
        ResultSet rs = null;
        Connection conn = null;
        qs = "SELECT grouprefseq.groupId groupId FROM grouprefseq, usergroup WHERE " +
                "usergroup.groupId = grouprefseq.groupId " +
                "AND usergroup.userId = ? " +
                "AND grouprefseq.refSeqId = ?";

        try
        {
          db =  DBAgent.getInstance();
          if(doCache)
            conn = db.getConnection();
          else
            conn = db.getNoCacheConnection(null);
          pstmt = conn.prepareStatement( qs );
          pstmt.setString( 1,  genboreeUserId);
          pstmt.setString( 2,  refseqId);
          rs = pstmt.executeQuery();
            if( rs.next() )
                groupId = rs.getString("groupId");
        } catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("Exception trying to find groupId using query " +
                    qs + " where userId = " + genboreeUserId + " refseqId = " + refseqId);
        }
        finally{
            db.safelyCleanup( rs, pstmt, conn );
            return groupId;
        }
    }

    public static String fetchRefSeqIdFromDatabaseName(String databaseName)
    {
        DBAgent db = null;
        String qs = null;
        String refSeqId = null;
        PreparedStatement pstmt = null;
        ResultSet rs = null;
        Connection conn = null;

        if(databaseName == null || databaseName.length() < 1) return null;

        // obtain refseqId from databaseName
        qs = "SELECT refSeqId FROM refseq WHERE databaseName =  ?";

        try
        {
            db =  DBAgent.getInstance();
            conn = db.getConnection();
            pstmt = conn.prepareStatement( qs );
            pstmt.setString( 1,  databaseName);
            rs = pstmt.executeQuery();
            if( rs.next() )
                refSeqId = rs.getString("refSeqId");
        } catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("Exception trying to find refSeqId From UploadId using query " +
                    qs + " where databaseName = " + databaseName);
        }
        finally{
          db.safelyCleanup( rs, pstmt, conn );
            return refSeqId;
        }
    }

    public static String fetchRefSeqIdFromUploadId(String uploadId, Connection conn)
    {
        String qs = null;
        String refSeqId = null;
        PreparedStatement pstmt = null;
        ResultSet rs = null;

        if(uploadId == null || uploadId.length() < 1) return null;

        // obtain refseqId from uploadId
        // TODO probably there is a shorter query but for now I just need to be sure it works
        qs = "SELECT upload.refSeqId refSeqId FROM upload, refseq2upload, refseq " +
                "WHERE upload.uploadId=refseq2upload.uploadId AND refseq.refSeqId=refseq2upload.refSeqId " +
                "AND refseq.databaseName = upload.databaseName AND refseq2upload.uploadId = ?";

        try
        {
            pstmt = conn.prepareStatement( qs );
            pstmt.setString( 1,  uploadId);
            rs = pstmt.executeQuery();
            if( rs.next() )
                refSeqId = rs.getString("refSeqId");
        } catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("Exception trying to find refSeqId From UploadId using query " +
                    qs + " where uploadId = " + uploadId);
        }
        finally{
            return refSeqId;
        }
    }

    public static String fetchRefSeqIdFromUploadId(String uploadId)
    {
        DBAgent db = null;
        String qs = null;
        String refSeqId = null;
        PreparedStatement pstmt = null;
        ResultSet rs = null;
        Connection conn = null;

        if(uploadId == null || uploadId.length() < 1) return null;

        // obtain refseqId from uploadId
        // TODO probably there is a shorter query but for now I just need to be sure it works
        qs = "SELECT upload.refSeqId refSeqId FROM upload, refseq2upload, refseq " +
                "WHERE upload.uploadId=refseq2upload.uploadId AND refseq.refSeqId=refseq2upload.refSeqId " +
                "AND refseq.databaseName = upload.databaseName AND refseq2upload.uploadId = ?";

        try
        {
            db =  DBAgent.getInstance();
            conn = db.getConnection();
            pstmt = conn.prepareStatement( qs );
            pstmt.setString( 1,  uploadId);
            rs = pstmt.executeQuery();
            if( rs.next() )
                refSeqId = rs.getString("refSeqId");
        } catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("Exception trying to find refSeqId From UploadId using query " +
                    qs + " where uploadId = " + uploadId);
        }
        finally{
          db.safelyCleanup( rs, pstmt, conn );
            return refSeqId;
        }
    }

    public static boolean verifyUserAccess(int refSeqId, int userId, Connection conn)
    {
        String qs = null;
        int groupId = 0;
        PreparedStatement pstmt = null;
        ResultSet rs = null;
        boolean b = false;


        if (userId < 1 || refSeqId < 1) return false;

        qs = "SELECT usergroup.groupId groupId FROM usergroup , grouprefseq , genboreegroup " +
                "WHERE usergroup.groupId=grouprefseq.groupId AND grouprefseq.groupId=genboreegroup.groupId " +
                "AND (usergroup.userGroupAccess='o' OR usergroup.userGroupAccess='w') " +
                "AND grouprefseq.refSeqId = ? and usergroup.userId = ?";

        try
        {
            pstmt = conn.prepareStatement(qs);
            pstmt.setInt(1, refSeqId);
            pstmt.setInt(2, userId);
            rs = pstmt.executeQuery();
            if (rs.next())
                b = true;

        }
        catch (Exception ex)
        {
            ex.printStackTrace();
            System.err.println("Exception trying to groupId From RefseqId when UserCanWrite query " +
                    qs + " where genboreeUserId  = " + userId + " AND refseqId = " + refSeqId);
            System.err.flush();
        }
        finally
        {
          return b;
        }

    }


    public static String fetchGroupIdFromRefseqIdAndUserCanWrite(String refSeqId, String userId, Connection conn)
    {
        String qs = null;
        String groupId = null;
        PreparedStatement pstmt = null;
        ResultSet rs = null;


        if(refSeqId == null || refSeqId.length() < 1) return null;
        if(userId == null || userId.length() < 1) return null;

        // get usergroup from refseqId and userId if user has permission to write to upload
        // TODO probably there is a shorter query but for now I just need to be sure it works
        qs = "SELECT usergroup.groupId groupId FROM usergroup , grouprefseq , genboreegroup " +
                "WHERE usergroup.groupId=grouprefseq.groupId AND grouprefseq.groupId=genboreegroup.groupId " +
                "AND (usergroup.userGroupAccess='o' OR usergroup.userGroupAccess='w') " +
                "AND grouprefseq.refSeqId = ? and usergroup.userId = ?";

        try
        {
            pstmt = conn.prepareStatement( qs );
            pstmt.setString( 1,  refSeqId);
            pstmt.setString( 2,  userId);
            rs = pstmt.executeQuery();
            if( rs.next() )
                groupId = rs.getString("groupId");
        } catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("Exception trying to groupId From RefseqId when UserCanWrite query " +
                    qs + " where genboreeUserId  = " + userId + " AND refseqId = " + refSeqId);
        }
        finally{
            return groupId;
        }
    }


  public static int fetchFtypeId(DBAgent db, String myDatabaseName, String fmethod, String fsource)
  {
    return fetchFtypeId(db, myDatabaseName, fmethod, fsource, true);
  }

    public static int fetchFtypeId(DBAgent db, String myDatabaseName, String fmethod, String fsource, boolean doCache)
    {
        Connection conn = null;
        int ftypeid = -1;
        PreparedStatement pstmt = null;
        ResultSet rs = null;
        String  qs = "SELECT ftypeid FROM ftype WHERE fmethod = ? AND fsource  = ?";
        if(myDatabaseName == null || fmethod == null || fsource == null ) return -1;

        try {
          if( doCache )
            conn = db.getConnection( myDatabaseName );
          else
            conn = db.getNoCacheConnection( myDatabaseName );

          pstmt = conn.prepareStatement( qs );
          pstmt.setString( 1, fmethod );
          pstmt.setString( 2, fsource );
          rs = pstmt.executeQuery();
          if( rs.next() ) ftypeid = rs.getInt(1);
        } catch (SQLException e) {
            System.err.println("GenboreeUtils#fetchFtypeId There has been an exception using databaseName = " + myDatabaseName);
            System.err.println("and the query is " + qs);
        }
        finally
        {
            db.safelyCleanup( rs, pstmt, conn );
            return ftypeid;
        }
    }

     public static String fetchGroupIdFromRefseqIdAndUserCanWrite(String refSeqId, String userId)
    {
      return fetchGroupIdFromRefseqIdAndUserCanWrite(refSeqId, userId, true);
    }

    public static String fetchGroupIdFromRefseqIdAndUserCanWrite(String refSeqId, String userId, boolean doCache)
    {
        DBAgent db = null;
        String qs = null;
        String groupId = null;
        PreparedStatement pstmt = null;
        ResultSet rs = null;
        Connection conn = null;

        if(refSeqId == null || refSeqId.length() < 1) return null;
        if(userId == null || userId.length() < 1) return null;

        // get usergroup from refseqId and userId if user has permission to write to upload
        // TODO probably there is a shorter query but for now I just need to be sure it works
        qs = "SELECT usergroup.groupId groupId FROM usergroup , grouprefseq , genboreegroup " +
                "WHERE usergroup.groupId=grouprefseq.groupId AND grouprefseq.groupId=genboreegroup.groupId " +
                "AND (usergroup.userGroupAccess='o' OR usergroup.userGroupAccess='w') " +
                "AND grouprefseq.refSeqId = ? and usergroup.userId = ?";

        try
        {
            db =  DBAgent.getInstance();
            if(doCache)
              conn = db.getConnection();
            else
              conn = db.getNoCacheConnection(null);
            pstmt = conn.prepareStatement( qs );
            pstmt.setString( 1,  refSeqId);
            pstmt.setString( 2,  userId);
            rs = pstmt.executeQuery();
            if( rs.next() )
                groupId = rs.getString("groupId");
        } catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("Exception trying to groupId From RefseqId when UserCanWrite query " +
                    qs + " where genboreeUserId  = " + userId + " AND refseqId = " + refSeqId);
        }
        finally
        {
            db.safelyCleanup( rs, pstmt, conn );
            return groupId;
        }
    }

    public static String verifyFid(Connection conn, String fid)
    {
        DBAgent db = null;
        String qs = null;
        String realFid = null;
        PreparedStatement pstmt = null;
        ResultSet rs = null;

        if(fid == null) return null;
        if(conn == null) return null;

        qs = "SELECT fid FROM fdata2 WHERE fid = ?";

        try
        {
            pstmt = conn.prepareStatement( qs );
            pstmt.setString( 1,  fid);
            rs = pstmt.executeQuery();
            if( rs.next() )
                realFid = rs.getString("fid");
        }
        catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("Exception trying to verify fid query " +
                    qs + " AND fid = " + fid);
        }
        finally
        {
            return realFid;
        }
    }

    public static String verifyFid(String databaseName, String fid, Connection conn)
    {
        String qs = null;
        String realFid = null;
        PreparedStatement pstmt = null;
        ResultSet rs = null;

        if(databaseName == null) return null;
        if(fid == null) return null;

        qs = "SELECT fid FROM fdata2 WHERE fid = ?";

        try
        {
            pstmt = conn.prepareStatement( qs );
            pstmt.setString( 1,  fid);
            rs = pstmt.executeQuery();
            if( rs.next() )
                realFid = rs.getString("fid");
        } catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("Exception trying to verify fid query " +
                    qs + " where databaseName   = " + databaseName + " AND fid = " + fid);
        }
        finally{
            return realFid;
        }
    }

    public static PreparedStatement returnPrepStatWithLimits(Connection currentConnection, String query)
    {
        PreparedStatement currentPrepareStatement = null;
        String appendToQuery = " limit ?, ?";
        String newQuery = null;

        if(query.indexOf(" limit ") < 0 )
            newQuery = query + appendToQuery;
        else
            newQuery = query;

        try
        {
            currentPrepareStatement = currentConnection.prepareStatement( newQuery );
        }
        catch (SQLException ex)
        {
            System.err.println((new java.util.Date()).toString() + "ERROR: GenboreeUtils#returnPrepStatWithLimits => An exception has been caught when preparing statement from query = " + query);
        }
        finally
        {
            return currentPrepareStatement;
        }

    }

    public static ResultSet returnResultSet(String args[], PreparedStatement currentPrepareStatement,
                                            int limit, int startRange)
    {
        ResultSet localResultSet = null;
        int setArgsCounter = 0;


        if(currentPrepareStatement == null) return null;

        try {

            if(args != null && args.length > 0)
            {
                for (int i = 0; i < args.length; i++)
                {
                    setArgsCounter = i + 1;
                    currentPrepareStatement.setString(setArgsCounter, args[setArgsCounter]);
                }
            }

            setArgsCounter++;
            currentPrepareStatement.setInt(setArgsCounter, startRange);
            setArgsCounter++;
            currentPrepareStatement.setInt(setArgsCounter, limit);

            localResultSet = currentPrepareStatement.executeQuery();

        } catch (SQLException e) {
            e.printStackTrace();
        }
        finally
        {
            return localResultSet;
        }
    }


  public static String getFtypeIdsFromFids(Connection conn, String fids)
  {
    String findFtypeIdFromFidQuery = null;
    String listOfFtypeIds = null;
    HashMap hashWithKeys = new HashMap();

    if(fids == null || fids.length() < 1)
      return "";

    findFtypeIdFromFidQuery = "SELECT DISTINCT(ftypeId) typeId FROM fdata2 WHERE fid IN ( " + fids + " )";
    try
    {
      Statement stmt = conn.createStatement();
      ResultSet rs = stmt.executeQuery( findFtypeIdFromFidQuery  );
      while( rs.next() )
      {
        hashWithKeys.put( rs.getString( 1 ), "" );
      }
      stmt.close();
      rs.close();
    }
    catch( Exception ex )
    {
      ex.printStackTrace( System.err );
      System.err.println( "Exception trying to find ftypeIds in method GenboreeUtils::getFtypeIdsFromFids where fids =  " + fids);
      System.err.flush();
    }

    listOfFtypeIds = GenboreeUtils.getCommaSeparatedKeys( hashWithKeys );

    if(listOfFtypeIds == null || listOfFtypeIds.length() < 1)
      return "";
    else
      return listOfFtypeIds;

  }

  public static String getFtypeIdsFromRids(Connection conn, String rids)
  {
    String findFtypeIdFromFidQuery = null;
    String listOfFtypeIds = null;
    HashMap hashWithKeys = new HashMap();

    if(rids == null || rids.length() < 1)
      return "";

    findFtypeIdFromFidQuery = "SELECT DISTINCT(ftypeId) typeId FROM fdata2 WHERE rid IN ( " + rids + " )";
    try
    {
      Statement stmt = conn.createStatement();
      ResultSet rs = stmt.executeQuery( findFtypeIdFromFidQuery  );
      while( rs.next() )
      {
        hashWithKeys.put( rs.getString( 1 ), "" );
      }
      stmt.close();
      rs.close();
    }
    catch( Exception ex )
    {
      ex.printStackTrace( System.err );
      System.err.println( "Exception trying to find ftypeIds in method GenboreeUtils::getFtypeIdsFromRids where fids =  " + rids);
      System.err.flush();
    }

    listOfFtypeIds = GenboreeUtils.getCommaSeparatedKeys( hashWithKeys );

    if(listOfFtypeIds == null || listOfFtypeIds.length() < 1)
      return "";
    else
      return listOfFtypeIds;

  }


  public static String filterFtypeIdsUsingFdata2( Connection conn, String _entryPointId)
  {
    HashMap hashWithKeys = new HashMap();
    String listOfFtypeIds = null;
    String query = null;
    String local_ftypeIds = null;
    String local_rid = null;


    local_ftypeIds = GenboreeUtils.fetchListFtypeIds( conn );
    local_rid = GenboreeUtils.fetchEntryPointIdFromRefName(conn, _entryPointId);

    if(local_ftypeIds == null || local_ftypeIds.length() < 1)
      return "";

    if(local_rid == null || local_rid.length() < 1)
      return local_ftypeIds;

    query  = "SELECT DISTINCT(ftypeId) typeId FROM fdata2 WHERE ftypeid IN (" + local_ftypeIds + ") AND rid = " + local_rid ;

    try
    {
      Statement stmt = conn.createStatement();
      ResultSet rs = stmt.executeQuery( query );
      while( rs.next() )
      {
        hashWithKeys.put( rs.getString( 1 ), "" );
      }
      stmt.close();
      rs.close();
    }
    catch( Exception ex )
    {
      ex.printStackTrace( System.err );
      System.err.println( "Exception trying to find ftypeIds in method Refseq::filterFtypeIdsUsingFdata2 " );
      System.err.flush();
    }

    listOfFtypeIds = GenboreeUtils.getCommaSeparatedKeys( hashWithKeys );

    if(listOfFtypeIds == null || listOfFtypeIds.length() < 1)
      return "";
    else
      return listOfFtypeIds;
  }


   public static String fetchListFtypeIds( Connection conn )
  {
    HashMap hashWithKeys = new HashMap();
    String listOfFtypeIds = null;

    try
    {
      Statement stmt = conn.createStatement();
      ResultSet rs = stmt.executeQuery( "SELECT ftypeid FROM ftypeCount" );
      while( rs.next() )
      {
        hashWithKeys.put( rs.getString( 1 ), "" );
      }
      stmt.close();
      rs.close();
    }
    catch( Exception ex )
    {
      ex.printStackTrace( System.err );
      System.err.println( "Exception trying to find ftypeIds in method Refseq::fetchListFtypeIds " );
      System.err.flush();
    }

    listOfFtypeIds = GenboreeUtils.getCommaSeparatedKeys( hashWithKeys );
    return listOfFtypeIds;
  }


  public static String fetchEntryPointIdFromRefName(Connection conn, String refName)
  {
    String entryPointId = null;
    Statement stmt = null;
    ResultSet rs = null;
     try
    {
      stmt = conn.createStatement();
      rs = stmt.executeQuery( "SELECT rid FROM fref WHERE refname = '" + refName + "'" );
      if( rs.next() )
      {
        entryPointId =  rs.getString( 1 );
      }
      stmt.close();
      rs.close();
    }
    catch( Exception ex )
    {
      ex.printStackTrace( System.err );
      System.err.println( "Exception trying to find rid in method GenboreeUtils::fetchEntryPointIdFromRefName" );
      System.err.flush();
    }

    return entryPointId ;
  }

    public static String[] retrieveGroupsOfRids(String databaseName, int limit)
    {
        int counter = 0;
        int annotationsProcessed = -1;
        ResultSet currentMainResultSet = null;
        String query = "SELECT rid FROM fref";
        PreparedStatement currentPrepareStatement = null;
        int numberOfLoops = 0;
        String[] results = null;
        ArrayList rids = null;
        ArrayList inStatements = null;
        DBAgent db =  DBAgent.getInstance();
        Connection currentConnection = null;


        try {
            currentConnection = db.getConnection(databaseName);
        } catch (SQLException ex)
        {
            System.err.println("Exception on GenboreeUtils::retrieveGroupsOfRids");
            ex.printStackTrace(System.err);
            System.err.flush();
        }

        rids = new ArrayList();
        inStatements = new ArrayList();

        currentPrepareStatement = returnPrepStatWithLimits(currentConnection, query);


        do {

            currentMainResultSet = returnResultSet(null, currentPrepareStatement, limit, counter);

            try {
                annotationsProcessed = 0;
                while( currentMainResultSet.next() )
                {
                    String myRid = currentMainResultSet.getString("rid");
                    rids.add(myRid);
                    annotationsProcessed++;
                }

                String theInStatement = " (" + DirectoryUtils.join(rids, ",") + " ) ";
                inStatements.add(theInStatement);
                theInStatement = null;
                rids.clear();


            } catch (SQLException e) {
                e.printStackTrace();
            }

            numberOfLoops ++;
            if(annotationsProcessed >= limit)
                counter = limit * numberOfLoops;
            else
                counter = 0;

           db.safelyCleanup(currentMainResultSet, null, null);

        }
        while(counter > 0 );

        db.safelyCleanup(null,currentPrepareStatement,  currentConnection);

        results = (String[])inStatements.toArray(new String[inStatements.size()]);
        return results;
    }

    public static String verifyFid(String databaseName, String fid)
    {
        DBAgent db = null;
        String qs = null;
        String realFid = null;
        PreparedStatement pstmt = null;
        ResultSet rs = null;
        Connection conn = null;

        if(databaseName == null) return null;
        if(fid == null) return null;

        qs = "SELECT fid FROM fdata2 WHERE fid = ?";

        try
        {
            db =  DBAgent.getInstance();
            conn = db.getConnection(databaseName);
            pstmt = conn.prepareStatement( qs );
            pstmt.setString( 1,  fid);
            rs = pstmt.executeQuery();
            if( rs.next() )
                realFid = rs.getString("fid");
        } catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("Exception trying to verify fid query " +
                    qs + " where databaseName   = " + databaseName + " AND fid = " + fid);
        }
        finally{
          db.safelyCleanup( rs, pstmt, conn );
            return realFid;
        }

    }




    public static boolean verifyUpladIdAndFid(String userId, String uploadId, String fid, Connection mainConnection, Connection specificConnection)
    {
        String refSeqId = null;
        String groupId = null;
        String databaseName = null;
        String realFid = null;
        long valueFid =  -1;

        valueFid = Util.parseLong(fid, -1);//Checking if fid is a valid number
        if(valueFid < 1)
        {
            System.err.println("#GenboreeUtils:verifyUpladIdAndFid Fid is not a valid number -- userId = " + userId + " uploadId = " + uploadId + " fid = " + fid);
            return false;
        }
        refSeqId = fetchRefSeqIdFromUploadId(uploadId, mainConnection);// Checking if valid uploadId
        if(refSeqId == null)
        {
            System.err.println("#GenboreeUtils:verifyUpladIdAndFid uploadId is not valid-- userId = " + userId + " uploadId = " + uploadId);
            return false;
        }
        groupId = fetchGroupIdFromRefseqIdAndUserCanWrite(refSeqId, userId, mainConnection);// Checking if user has permission to write into database
        if(groupId == null)
        {
            System.err.println("#GenboreeUtils:verifyUpladIdAndFid user does not have permission to edit this upload -- userId = " + userId + " uploadId = " + uploadId);
            return false;
        }
        databaseName = fetchMainDatabaseName( refSeqId, mainConnection );// Checking if database is listed in genboree tables
        // excessive but I need to get databaseName anyway
        if(databaseName == null)
        {
            System.err.println("#GenboreeUtils:verifyUpladIdAndFid database not register in genboree ERROR -- userId = " + userId + " uploadId = " + uploadId);
            return false;
        }

        realFid = verifyFid(databaseName, fid);// Checking if fid exist in database again excessive but better safe than sorry!
        if(realFid == null)
        {
            System.err.println("#GenboreeUtils:verifyUpladIdAndFid fId does not exist for this upload -- userId = " + userId + " uploadId = " + uploadId + " fid = " + fid);
            return false;
        }
        return true;
    }

    public static boolean verifyUpladIdAndFid(String userId, String uploadId, String fid)
    {
        String refSeqId = null;
        String groupId = null;
        String databaseName = null;
        String realFid = null;
        long valueFid =  -1;

        valueFid = Util.parseLong(fid, -1);//Checking if fid is a valid number
        if(valueFid < 1)
        {
            System.err.println("#GenboreeUtils:verifyUpladIdAndFid Fid is not a valid number -- userId = " + userId + " uploadId = " + uploadId + " fid = " + fid);
            return false;
        }
        refSeqId = fetchRefSeqIdFromUploadId(uploadId);// Checking if valid uploadId
        if(refSeqId == null)
        {
            System.err.println("#GenboreeUtils:verifyUpladIdAndFid uploadId is not valid-- userId = " + userId + " uploadId = " + uploadId);
            return false;
        }
        groupId = fetchGroupIdFromRefseqIdAndUserCanWrite(refSeqId, userId);// Checking if user has permission to write into database
        if(groupId == null)
        {
            System.err.println("#GenboreeUtils:verifyUpladIdAndFid user does not have permission to edit this upload -- userId = " + userId + " uploadId = " + uploadId);
            return false;
        }
        databaseName = fetchMainDatabaseName( refSeqId );// Checking if database is listed in genboree tables
        // excessive but I need to get databaseName anyway
        if(databaseName == null)
        {
            System.err.println("#GenboreeUtils:verifyUpladIdAndFid database not register in genboree ERROR -- userId = " + userId + " uploadId = " + uploadId);
            return false;
        }

        realFid = verifyFid(databaseName, fid);// Checking if fid exist in database again excessive but better safe than sorry!
        if(realFid == null)
        {
            System.err.println("#GenboreeUtils:verifyUpladIdAndFid fId does not exist for this upload -- userId = " + userId + " uploadId = " + uploadId + " fid = " + fid);
            return false;
        }

        return true;
    }

/**
 * polymorphic function for fast group access retrieval
 * @param userId
 * @param groupId
 * @param db  DBAgent
 * @return access to group, null if not found
 */
    public static String fetchGrpAccess(int userId, int groupId, DBAgent db  )
    {
      String access = null;
      String qs = null;
      PreparedStatement pstmt = null;
      ResultSet rs = null;
      Connection conn = null;
      qs = "select userGroupAccess access from usergroup where userId = ? and groupId = ? ";

      try
      {

          conn = db.getConnection();
          pstmt = conn.prepareStatement( qs );
          pstmt.setInt( 1,  userId);
          pstmt.setInt( 2,  groupId);
          rs = pstmt.executeQuery();
          if( rs.next() )
              access  = rs.getString("access");
      } catch( SQLException ex )
      {
          ex.printStackTrace();
          System.err.println("Exception trying to find access level using query " +
                  qs + " where userId = " + userId + " groupId = " + groupId);
      }
      finally{
        db.safelyCleanup( rs, pstmt, conn );
          return access;
      }
    }

    public static String fetchGrpAccess(int userId, int groupId )
    {
        DBAgent db = null;
        String access = null;
        String qs = null;
        PreparedStatement pstmt = null;
        ResultSet rs = null;
        Connection conn = null;
        qs = "select userGroupAccess access from usergroup where userId = ? and groupId = ? ";

        try
        {
            db =  DBAgent.getInstance();
            conn = db.getConnection();
            pstmt = conn.prepareStatement( qs );
            pstmt.setInt( 1,  userId);
            pstmt.setInt( 2,  groupId);
            rs = pstmt.executeQuery();
            if( rs.next() )
                access  = rs.getString("access");
        } catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("Exception trying to find access level using query " +
                    qs + " where userId = " + userId + " groupId = " + groupId);
        }
        finally{
          db.safelyCleanup( rs, pstmt, conn );
            return access;
        }
    }

    public static String fetchPermission(String refseqId, String genboreeUserId )
    {
        DBAgent db = null;
        String qs = null;
        String access = null;
        PreparedStatement pstmt = null;
        ResultSet rs = null;
        Connection conn = null;
        qs = "SELECT usergroup.userGroupAccess access FROM grouprefseq, usergroup WHERE " +
                "usergroup.groupId = grouprefseq.groupId " +
                "AND usergroup.userId = ? " +
                "AND grouprefseq.refSeqId = ?";

        try
        {
            db =  DBAgent.getInstance();
            conn = db.getConnection();
            pstmt = conn.prepareStatement( qs );
            pstmt.setString( 1,  genboreeUserId);
            pstmt.setString( 2,  refseqId);
            rs = pstmt.executeQuery();
            if( rs.next() )
                access = rs.getString("access");
        } catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("Exception trying to find access level using query " +
                    qs + " where userId = " + genboreeUserId + " refseqId = " + refseqId);
        }
        finally{
          db.safelyCleanup( rs, pstmt, conn );
            return access;
        }
    }

    public static String fetchDatabaseHost(String databaseName)
    {
       return fetchDatabaseHost(databaseName, true);
    }

    public static String fetchDatabaseHost(String databaseName, boolean doCache)
    {
        String databaseHost = null;
        DBAgent db  =  null;
        Connection conn = null;

         try
        {
            db  =  DBAgent.getInstance();
            if(doCache)
              conn = db.getConnection();
            else
              conn = db.getNoCacheConnection(null);
            databaseHost =  Database2HostTable.getHostForDbName(databaseName, conn);
            conn.close();
        } catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("Exception unable to generate a connection in GenboreeUtils#fetchDatabaseHost");
        }
        finally
         {
            return databaseHost;
         }
    }

    public static String fetchMainDatabaseName(String refseqId )
    {
        return fetchMainDatabaseName(refseqId, true );
    }

    public static String fetchMainDatabaseName(String refseqId, boolean doCache)
    {
        DBAgent db = null;
        String qs = null;
        String mainDatabase = null;
        PreparedStatement pstmt = null;
        ResultSet rs = null;
        Connection conn = null;
        qs = "SELECT  databaseName FROM refseq where refSeqId = ?";

        try
        {
            db =  DBAgent.getInstance();
            if(doCache)
              conn = db.getConnection();
            else
              conn = db.getNoCacheConnection(null);
            pstmt = conn.prepareStatement( qs );
            pstmt.setString( 1,  refseqId);
            rs = pstmt.executeQuery();
            if( rs.next() )
                mainDatabase = rs.getString("databaseName");
        } catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("Exception trying to find database for refseqId = " + refseqId);
        }
        finally{
          db.safelyCleanup( rs, pstmt, conn );
            return mainDatabase;
        }
    }

    public static String fetchMainDatabaseName(String refseqId, Connection conn )
    {
        String qs = null;
        String mainDatabase = null;
        PreparedStatement pstmt = null;
        ResultSet rs = null;

        qs = "SELECT  databaseName FROM refseq where refSeqId = ?";

        try
        {
            pstmt = conn.prepareStatement( qs );
            pstmt.setString( 1,  refseqId);
            rs = pstmt.executeQuery();
            if( rs.next() )
                mainDatabase = rs.getString("databaseName");
        } catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("Exception trying to find database for refseqId = " + refseqId);
        }
        finally{
            return mainDatabase;
        }
    }

    public static String fetchUserName(String userId )
    {
        return fetchUserName(userId, true);
    }

    public static String fetchUserName(String userId, boolean doCache)
    {
        DBAgent db = null;
        String qs = null;
        String name = null;
        PreparedStatement pstmt = null;
        ResultSet rs = null;
        Connection conn = null;
        qs = "SELECT name FROM genboreeuser WHERE userId = ?";

        try
        {
            db =  DBAgent.getInstance();
            if(doCache)
               conn = db.getConnection();
            else
               conn = db.getNoCacheConnection(null);
            pstmt = conn.prepareStatement( qs );
            pstmt.setString(1,  userId);
            rs = pstmt.executeQuery();
            if( rs.next() )
                name = rs.getString("name");
        } catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("Exception trying to find genboree user name for userId = " + userId);
        }
        finally{
          db.safelyCleanup( rs, pstmt, conn );
            return name;
        }
    }
     public static String fetchUserEmail(String userId )
    {
        return fetchUserEmail(userId, true );
    }

    public static String fetchUserEmail(String userId, boolean doCache)
    {
        DBAgent db = null;
        String qs = null;
        String email = null;
        PreparedStatement pstmt = null;
        ResultSet rs = null;
        Connection conn = null;
        qs = "SELECT email FROM genboreeuser WHERE userId = ?";

        try
        {
            db =  DBAgent.getInstance();
            if(doCache)
               conn = db.getConnection();
            else
               conn = db.getNoCacheConnection(null);
            pstmt = conn.prepareStatement( qs );
            pstmt.setString(1,  userId);
            rs = pstmt.executeQuery();
            if( rs.next() )
                email = rs.getString("email");
        } catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("Exception trying to find genboree email address for userId = " + userId);
        }
        finally{
          db.safelyCleanup( rs, pstmt, conn );
            return email;
        }
    }

    public static String fetchRefseqIdForTemplateDatabase(String templateId)
    {
        DBAgent db = null;
        String qs = null;
        String refseqId = null;
        PreparedStatement pstmt = null;
        ResultSet rs = null;
        Connection conn = null;

        if(templateId == null) return null;

        qs = "SELECT upload.refSeqId refseqId FROM upload, template2upload " +
                "WHERE template2upload.uploadId = upload.uploadId AND " +
                "template2upload.templateId  = ?";

        try
        {
            db =  DBAgent.getInstance();
            conn = db.getConnection();
            pstmt = conn.prepareStatement( qs );
            pstmt.setString(1,  templateId);
            rs = pstmt.executeQuery();
            if( rs.next() )
                refseqId = rs.getString("refseqId");
        } catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("Exception trying to find refseqId for template id = " + templateId);
        }
        finally{
          db.safelyCleanup( rs, pstmt, conn );
            return refseqId;
        }
    }


    public static String fetchGroupName(String groupId )
    {
        DBAgent db = null;
        String qs = null;
        String name = null;
        PreparedStatement pstmt = null;
        ResultSet rs = null;
        Connection conn = null;
        qs = "SELECT groupName FROM genboreegroup WHERE groupId = ?";

        try
        {
            db =  DBAgent.getInstance();
            conn = db.getConnection();
            pstmt = conn.prepareStatement( qs );
            pstmt.setString(1,  groupId);
            rs = pstmt.executeQuery();
            if( rs.next() )
                name = rs.getString("groupName");
        } catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("Exception trying to find genboree groupName for groupId = " + groupId);
        }
        finally{
          db.safelyCleanup( rs, pstmt, conn );
            return name;
        }
    }

    public static String fetchUserFullName(String userId )
    {
        DBAgent db = null;
        String qs = null;
        String fullName = null;
        PreparedStatement pstmt = null;
        ResultSet rs = null;
        Connection conn = null;
        qs = "SELECT concat(firstName, ' ', lastName ) fullName FROM genboreeuser WHERE userId = ?";

        try
        {
            db =  DBAgent.getInstance();
            conn = db.getConnection();
            pstmt = conn.prepareStatement( qs );
            pstmt.setString(1,  userId);
            rs = pstmt.executeQuery();
            if( rs.next() )
                fullName = rs.getString("fullName");
        } catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("Exception trying to find fullName for userId = " + userId);
        }
        finally{
          db.safelyCleanup( rs, pstmt, conn );
            return fullName;
        }
    }





    public static void printUsage()
    {
        System.out.print("usage: CleanComments");
        System.out.println("\n" +
                "-d databaseName\n" +
                "-c comments\n" +
                "-m mainClass\n" +
                "-t typeId\n");
        return;
    }
    public static void main(String[] args) throws Exception
    {
        String comments = null;
        String databaseName = null;
        int ftypeId = -1;
        String newComments = null;
        String mainClass = null;
        int colorCode = -5;
        Connection conn = null;
        DBAgent db = null;
        String query = "SELECT fid, ftypeid, text FROM  fidText_back where textType = 't' and fid >= 1200  and fid <= 1300 order by fid";
        Statement stmt = null;
        ResultSet resultSet = null;
        ArrayList theList = new ArrayList(110);
        HashMap fidValuePairHash = null;
        HashMap valuePairs = null;
        HashMap unique = null;
        String refSeqId = null;

        System.err.println("The refseqId 529 is " + GenboreeUtils.isRefSeqIdUsingNewFormat("529") );
        System.err.println("The database  genboree_r_7494996b1c093ddb6b260110b1722018 is " + GenboreeUtils.isDatabaseUsingNewFormat("genboree_r_7494996b1c093ddb6b260110b1722018"));
        System.err.println("The refseqId 528 is " + GenboreeUtils.isRefSeqIdUsingNewFormat("528") );
        System.err.println("The database genboree_r_0deefc1dfcec013d953facedcd19a793 is " + GenboreeUtils.isDatabaseUsingNewFormat("genboree_r_0deefc1dfcec013d953facedcd19a793"));
        System.exit(0);
        databaseName = "genboree_r_dbf54044d73c7dac2d8e8876de773924";
        refSeqId = GenboreeUtils.fetchRefSeqIdFromDatabaseName(databaseName);
        try
        {
            db =  DBAgent.getInstance();
            conn = db.getConnection(databaseName) ;
            stmt = conn.createStatement();
            resultSet = stmt.executeQuery(query);

            while( resultSet.next() )
            {
                long fid = resultSet.getLong("fid");
                int ftypeid = resultSet.getInt("ftypeid");
                String text = resultSet.getString("text");
                addValuePairs(conn, refSeqId,fid, ftypeid, text, 0);

            }
            stmt.close();

        } catch (SQLException e)
        {
            e.printStackTrace(System.err);
        }
      db.safelyCleanup( resultSet , stmt, conn );

        return;
    }
    
    public static String getFileName(String refseqId)
    {
        java.util.Date rightNow = new java.util.Date();
        String myRightNow = null;
        String nameToUse = null;

        myRightNow = rightNow.toString();
        myRightNow = myRightNow.replaceAll("\\s+", "");
        myRightNow = myRightNow.replaceAll(":", "");
        nameToUse = "databaseId" + refseqId + "-" + myRightNow ;
        return nameToUse;
    }

}
