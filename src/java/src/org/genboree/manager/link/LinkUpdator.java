package org.genboree.manager.link;

import org.genboree.dbaccess.DBAgent;
import org.genboree.dbaccess.DbFtype;
import org.genboree.dbaccess.DbLink;
import org.genboree.manager.tracks.Utility;
import org.genboree.message.GenboreeMessage;
import org.genboree.util.GenboreeUtils;
import org.genboree.util.Util;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.util.ArrayList;

/**
 * User: tong Date: Apr 3, 2006 Time: 5:56:29 PM
 */
public class LinkUpdator {
    public static void updateLink (HttpSession mys, HttpServletRequest request, HttpServletResponse response, java.sql.Connection con, DbLink editLink, DBAgent db) {
        ArrayList list = new ArrayList();
        String lnkName = request.getParameter("link_name");
        String lnkPattern = request.getParameter("link_pattern");
        DbLink lnk = new DbLink();

        lnk.setName(lnkName);
        lnk.setDescription(lnkPattern);

        String linkId = editLink.getLinkId();
        lnk.setLinkId(linkId);
        String  newLinkID = Utility.generateMD5(lnkName + ":" + lnkPattern);

        if (Util.isEmpty(lnkName)) {
            list = new ArrayList();
            list.add("Link name field is empty");
            GenboreeMessage.setErrMsg(mys, "The link update operation failed:", list);
        }
        else if (Util.isEmpty(lnkPattern)) {
            list = new ArrayList();
            list.add("Link pattern field is empty");
            GenboreeMessage.setErrMsg(mys, "The link update operation failed:", list);
        }
        else if (Utility.checkDuplicate(newLinkID, con)) {
            list = new ArrayList();
            list.add("Identical link name and pattern exist. Please choose a differnt name or pattern");
            GenboreeMessage.setErrMsg(mys, "The link update operation failed:", list);
        }
        else {
            updateLinkMap(linkId, newLinkID, con);

         if (
           lnk.delete(con)){
            lnk.setLinkId(newLinkID);

             if ( lnk.insert(con)) {
                GenboreeMessage.setSuccessMsg(mys, " The update operation was successful. ");
                editLink.setName(lnk.getName());
                editLink.setDescription(lnk.getDescription());


            }
            else {
                GenboreeUtils.sendRedirect(request, response, "/java-bin/error.jsp");
            }
        }


        }
    }

    public static boolean updateLinkMap(String oldId, String newId, Connection con) {
       try {
           PreparedStatement pstmt = con.prepareStatement("update featuretolink set linkId = ? WHERE linkId=? ");
            pstmt.setString (1,newId);
            pstmt.setString(2, oldId);

            pstmt.executeUpdate();
            pstmt.close();

            return true;
        } catch (Exception ex) {
            ex.printStackTrace();
        }
        return false;
    }





    public static boolean updateLinks(Connection con, DbFtype  ftype,  DbLink[] links, String dbName, int userId) {

        int ftypeid =  ftype.getFtypeid();

        try {
            boolean localFtype = false;
            if(ftype.getDatabaseName().compareTo(dbName)==0){
               localFtype = true;
            }

            PreparedStatement pstmt = con.prepareStatement("DELETE FROM featuretolink where  ftypeid=?");
            pstmt.setInt(1, ftypeid);
            pstmt.executeUpdate();
            //pstmt.close();


            if (links == null) return true;
            pstmt = con.prepareStatement("INSERT INTO featuretolink (linkId,ftypeid) VALUES (?, ?)");

            for (int i = 0; i < links.length; i++) {
                String lid = links[i].getLinkId();
                pstmt.setString(1, lid);

                pstmt.setInt(2,ftypeid);
                pstmt.executeUpdate();
            }

            return true;
        } catch (Exception ex) {
            ex.printStackTrace();
        }
        return false;
    }



}
