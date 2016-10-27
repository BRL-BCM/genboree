package org.genboree.message;

import javax.servlet.http.HttpSession;
import java.util.ArrayList;

/**
 * User: tong Date: Mar 23, 2006 Time: 9:33:23 AM
 */
public class GenboreeMessage {

    private static  final int NOMSG = 0;
    private static final int SUCCESS = 10;
    private static final int SUCCESS_DETAIL = 15;
    private static final int ERROR = 20;
    private static final int DETAILERROR = 25;
    private static final int WARN = 30;
    private static final int CONFIRM = 40;

    private static final int GENERIC = 100;

    /**
     * for generic html message display, allows user to set his/her own style

     * @param message String , may contains user's own html style
     */
    public static String  convertMessage(String message) {

       return  wrapMessage(message, 100, null);

    };


    /**
     * for generic html message display, allows user to set his/her own style
     * @param mys     Session
     * @param message  String , may contains user's own html style
     */
    public static void setMessage(HttpSession mys, String message) {
        clearMessage(mys);
        String msg = wrapMessage(message, 100, null);
        mys.setAttribute("genericMsg", msg);
    };


    /**
     * user to set key:value pair for successful operation
     * @param mys
     * @param message String message  for successful operation
     */
    public static void setSuccessMsg (HttpSession mys, String message){
       clearMessage(mys);
       String msg = wrapMessage (message, 10, null);
       mys.setAttribute("successMsg", msg);
    };

    /**
     * user to set key:value pair for successful operation
     * and list of details below the general message
     * @param mys
     * @param message String message  for successful operation
     */
    public static void setSuccessMsg(HttpSession mys, String message, ArrayList list) {
        clearMessage(mys);
        String msg = wrapMessage(message, 15, list);
        mys.setAttribute("successMsg", msg);
    };





    /**
     * for simple error message display
     * @param mys
     * @param message
     */
    public static void setErrMsg(HttpSession mys, String message) {
       clearMessage(mys);
       String  msg = wrapMessage(message, 20, null);
       mys.setAttribute("errorMsg", msg);
    };


    /**
     * for error message with list of errors
     * @param mys
     * @param message
     * @param list
     */
    public static void setErrMsg(HttpSession mys, String message, ArrayList list) {
        clearMessage(mys);
        String  msg = wrapMessage(message, 25, list);
        mys.setAttribute("errorMsg", msg);
    };



    /**
     * for error message with list of errors
     *
     * @param mys
    
     */
    public static String getDefault( HttpSession mys ) {
        clearMessage(mys);
      return "";
    };



    public static void clearMessage(HttpSession mys) {
        if (mys.getAttribute("successMsg") != null)
        mys.removeAttribute("successMsg");

        if (mys.getAttribute("errorMsg") != null)
       mys.removeAttribute("errorMsg");

        if (mys.getAttribute("genericMsg") != null) 
       mys.removeAttribute("genericMsg");
    };

    /*
    public static void setWarnMsg(HttpSession mys, String message, ArrayList list) {};

    public static void setConfirmMsg(HttpSession mys, String message, ArrayList list) {};

    */


   private static  String  wrapMessage(String message, int type, ArrayList list  ) {
    if (type ==0 )
    return "";

    String  cssClass = null;
    String wrappedMsg = "";
    switch (type){
     case SUCCESS :
            cssClass = "successMsg";
            break;

    case SUCCESS_DETAIL:
            cssClass = "successMsg";
            break;

     case ERROR:
            cssClass = "errorMsg";
            break;

     case DETAILERROR:
            cssClass = "errorMsg";
            break;

     case GENERIC:
            cssClass = "genericMsg";
            break;

    }

    if (type!=GENERIC  && cssClass == null)
      return "";

    if (type != GENERIC)
    wrappedMsg =  wrapMessage(message, cssClass, list);
    else {
        wrappedMsg = wrapMessage(message, list);
    }


    return wrappedMsg;
 }



    static String wrapMessage(String msg,  ArrayList list) {
        String wrappedMsg = "";

        if (list == null || list.isEmpty())
            wrappedMsg = "<DIV name=\"gbmsg\" id=\"gbmsg\"  class=\"message\">" + msg + "</DIV>";
        else {
            String temp = "";

            for (int i = 0; i < list.size(); i++) {
                temp = temp + "<li>&middot; " + (String) list.get(i) ;
            }

            wrappedMsg =  msg + "<BR>";
            wrappedMsg =  wrappedMsg + "<UL class=\"compactMsg\">" + temp + "</UL>";
            wrappedMsg = "<DIV class=\"message\">" + wrappedMsg + "</DIV>";
        }

        return wrappedMsg;
    }




  static String wrapMessage (String msg,  String cssclass, ArrayList list) {
      String wrappedMsg = "";

     if (list== null || list.isEmpty())
       wrappedMsg = "<DIV name=\"gbmsg\" id=\"gbmsg\" class=\"message\"><span class=\""  + cssclass + "\">" + msg + "</span></DIV>";
     else {
        String temp = "";

        for (int i=0; i<list.size(); i++) {
        temp = temp + "<li>&middot; <span class=\"" + cssclass + "\">" +  (String )list.get(i) + "</span>";
        }

        wrappedMsg = "<span class=\"" +  cssclass +  " \">" + msg + "</span><BR>";
        wrappedMsg = wrappedMsg +  "<UL class=\"compactMsg\">" + temp + "</UL>";
        wrappedMsg = "<DIV class=\"message\"  >   " + wrappedMsg + "</DIV>";
     }

      return wrappedMsg;
  }

}
