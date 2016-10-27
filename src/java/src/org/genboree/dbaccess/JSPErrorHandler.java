package org.genboree.dbaccess;

import org.genboree.util.GenboreeUtils;

import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;
import javax.servlet.http.HttpServletRequest;

/**
 * User: tong Date: Jul 20, 2005 Time: 1:17:15 PM
 */
public class JSPErrorHandler {


   public static  boolean checkErrors(HttpServletRequest request, HttpServletResponse response, DBAgent db, HttpSession mys )
     throws java.io.IOException
   {
     String[] errs = db.getLastError();
     if( errs == null ) return false;
     mys.setAttribute( "lastError", db.getLastError() );
     GenboreeUtils.sendRedirect(request,response,  "/java-bin/error.jsp" );
     return true;
   }

}
