package org.genboree.manager.link;

import org.genboree.manager.tracks.Utility;
import org.genboree.util.Util;
import org.genboree.util.GenboreeUtils;
import org.genboree.message.GenboreeMessage;
import org.genboree.dbaccess.DbLink;

import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpSession;
import java.util.ArrayList;
import java.util.Vector;
import java.io.IOException;
import org.genboree.manager.tracks.Utility;

import com.mysql.jdbc.Connection;

/**
 * User: tong Date: Apr 3, 2006 Time: 5:36:06 PM
 */
public class LinkCreator {

    public static boolean  createLink(HttpSession mys, HttpServletRequest request, HttpServletResponse response, java.sql.Connection con, Vector vBtn, DbLink editLink, DbLink[] links, DbLink[] shareLinks ) {
    boolean success = false;
    ArrayList list = new ArrayList();
    String lnkName = request.getParameter("link_name");
    String lnkPattern = request.getParameter("link_pattern");
        editLink.setName( lnkName );
        editLink.setDescription( lnkPattern );
        String linkmd5 = Utility.generateMD5(lnkName + ":" + lnkPattern);
        editLink.setLinkId(linkmd5);
        if( Util.isEmpty(lnkName)) {
            list = new ArrayList();
            list.add("Link name field is empty");
            GenboreeMessage.setErrMsg(mys, "The create link operation failed:", list);

        }
        else if ( Util.isEmpty(lnkPattern) )
        {
            list = new ArrayList();
            list.add("Link pattern field is empty");
            GenboreeMessage.setErrMsg(mys, "The create link operation failed:", list);
        }
        else if (Utility.checkDuplicate(linkmd5, con)) {
            list = new ArrayList();
            list.add("Identical link name and pattern exist. Please choose a differnt name or pattern");
            GenboreeMessage.setErrMsg(mys, "The create link operation failed:", list);
        }
        else
        {
            if (!editLink.insert(con, lnkName, lnkPattern, linkmd5)) {
                GenboreeUtils.sendRedirect(request,response, "/java-bin/error.jsp");
            }
            else {
                GenboreeMessage.setSuccessMsg(mys, " The create operation was successful.");
                links = DbLink.fetchAll(con, false);
                links = DbLink.mergeLinks(links, shareLinks);
               // origMode = mode = MODE_DEFAULT;
               // vBtn.removeElement(btnCreate);
            }
        }
        return success;
    }
}
