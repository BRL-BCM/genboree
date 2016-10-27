package org.genboree.manager.link;

import org.genboree.dbaccess.DbFtype;
import org.genboree.dbaccess.DbLink;
import org.genboree.dbaccess.IDFinder;

import javax.servlet.jsp.JspWriter;
import java.util.HashMap;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Iterator;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

/**
 * User: tong Date: Aug 17, 2006 Time: 9:43:08 AM
 */
public class LinkManagerHelper {
    public static HashMap mapTracks2Links(ArrayList tracklist, Connection con, JspWriter out) {
        HashMap track2links = new HashMap();
        String sql = " select linkId  from  featuretolink where ftypeid = ?";
        try {
            PreparedStatement stms = con.prepareStatement(sql);
            for (int i = 0; i < tracklist.size(); i++) {
                DbFtype ft = (DbFtype) tracklist.get(i);
                int id = 0;
                String fmethod = ft.getFmethod();
                String fsource = ft.getFsource();
                id = IDFinder.findFtypeId(con, fmethod, fsource);
                stms.setInt(1, id);
                ResultSet rs = stms.executeQuery();
                ArrayList linkList = new ArrayList();
                while (rs.next()) {
                    String linkId = rs.getString(1);
                    if (!linkList.contains(linkId))
                        linkList.add(linkId);
                }
                track2links.put(ft.toString(), linkList);
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }

        return track2links;
    }


    public static DbLink[] mergeLinks(DbLink[] linksMain, DbLink[] linksShare, JspWriter out) {
        DbLink[] all = null;

        if (linksShare == null || linksShare.length < 1) {
            if (linksMain != null && linksMain.length > 0)
                Arrays.sort(linksMain);
            return linksMain;
        }

        if (linksMain == null || linksMain.length < 1) {
            if (linksShare != null && linksShare.length > 0)
                Arrays.sort(linksShare);
            return linksShare;
        }

        try {
            HashMap h = new HashMap();
            for (int i = 0; i < linksMain.length; i++) {
                if (h.get(linksMain[i].getLinkId()) == null)
                    h.put(linksMain[i].getLinkId(), linksMain[i]);
            }

            ArrayList shareOnly = new ArrayList();
            for (int i = 0; i < linksShare.length; i++) {
                if (h.get(linksShare[i].getLinkId()) == null) {
                    h.put(linksShare[i].getLinkId(), linksShare[i]);
                    shareOnly.add(linksShare[i]);
                }
            }

            int n = h.size();
            all = new DbLink[n];
            for (int j = 0; j < shareOnly.size(); j++)
                all[j] = (DbLink) shareOnly.get(j);

            int i = 0;
            int index = shareOnly.size();
            for (i = 0; i < linksMain.length; i++)
                all[index + i] = linksMain[i];
        } catch (Exception e) {}
        return all;
    }




    public static HashMap mapmerge(HashMap track2links, HashMap temp) {
        Iterator it = temp.keySet().iterator();
        while (it.hasNext()) {
            String trackName = (String) it.next();
            ArrayList links = (ArrayList) temp.get(trackName);
            if (track2links.get(trackName) == null) {
                track2links.put(trackName, links);
            } else { // existing
                ArrayList mainlist = (ArrayList) track2links.get(trackName);
                for (int j = 0; j < links.size(); j++) {
                    String linkId = (String) links.get(j);
                    if (!mainlist.contains(linkId))
                        mainlist.add(linkId);
                }
                track2links.remove(trackName);
                track2links.put(trackName, mainlist);
            }
        }
        return track2links;
    }



}
