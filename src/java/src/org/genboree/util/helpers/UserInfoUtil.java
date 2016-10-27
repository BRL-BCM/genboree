package org.genboree.util.helpers ;

import org.genboree.util.* ;
import org.genboree.dbaccess.* ;
import javax.servlet.http.* ;

public class UserInfoUtil
{
  /** Check that user is logged in, session hasn't timed-out,
   *  and in some cases that the user is not the public user
   *  - doesn't check access to resources or anything */
  public static boolean checkSessionAccess(HttpServletRequest request, boolean publicUserOk)
  {
    String userName = (String) request.getSession().getAttribute("username") ;
    boolean sessionAccessValid = (userName != null) ;
    sessionAccessValid = sessionAccessValid && (request.getSession().getAttribute("pass") != null) ;
    sessionAccessValid = sessionAccessValid && (request.getSession().getAttribute("userid") != null) ;
    if(!publicUserOk)
    {
      sessionAccessValid = sessionAccessValid && userName.equals(userName) ;
    }
    return sessionAccessValid ;
  }
}
