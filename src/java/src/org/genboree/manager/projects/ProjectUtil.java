package org.genboree.manager.projects ;

import java.util.regex.* ;

public class ProjectUtil
{
  public static String getProjectNameFromURI(String uri)
  {
    Pattern projRe = Pattern.compile("^\\s*/java-bin/([^/]+)/") ;
    Matcher projMatch = projRe.matcher(uri) ;
    boolean foundProj = projMatch.find() ;
    String projName = null ;
    if(foundProj)
    {
      projName = projMatch.group(1) ;
    }

    return projName ;
  }
}
