package org.genboree.util ;

import javax.servlet.http.* ;
import java.util.* ;

public class RequestUtils
{
  public static String getRelativeUriPath(HttpServletRequest request)
  {
    String retVal = "/" ;
    String fullUriPath = request.getRequestURI() ;
    String relPath = fullUriPath.substring(0, fullUriPath.lastIndexOf("/")) ;
    if(relPath.length() > 0) // then got some kind of path, else path was just "/" and we've now got relPath="", so correct result is "/""
    {
      retVal = relPath ;
    }
    return retVal ;
  }
}
