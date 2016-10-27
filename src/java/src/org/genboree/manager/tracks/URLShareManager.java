package org.genboree.manager.tracks;

import org.genboree.dbaccess.DbFtype;
import org.genboree.dbaccess.DBAgent;

import javax.servlet.jsp.JspWriter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Vector;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

/**
 * User: tong Date: Jun 23, 2005 Time: 10:01:55 PM
 */
public class URLShareManager {
    public static DbFtype[] updateTrackandURL(DbFtype[] main, DbFtype[] vshare, javax.servlet.jsp.JspWriter out) {


        ArrayList list = new ArrayList();
        ArrayList all = new ArrayList();
        HashMap map = new HashMap();

        if(main == null || main.length == 0)
            return vshare;

        if(vshare == null || vshare.length == 0)
            return main;
        try {
            for(int i = 0; i < main.length; i++) {
                DbFtype f = main[i];


                if(f != null && f.getFmethod() != null && f.getFsource() != null) {
                    list.add(f.getFmethod() + ":" + f.getFsource());
                    map.put(f.getFmethod() + ":" + f.getFsource(), f);
                    // out.println ( f.getFmethod() + ":" + f.getFsource() + " url desc " + f.getUrlDescription() +  " from main is put into hash<br> " );
                }
            }

            String key = null;
            // update main with share db information
            for(int i = 0; i < vshare.length; i++) {
                DbFtype fshare = vshare[i];
                if(fshare != null && fshare.getFmethod() != null && fshare.getFsource() != null) {
                    key = (fshare.getFmethod() + ":" + fshare.getFsource());

                    // if main  does not has this track, add to current url
                    if(!list.contains(key))
                        all.add(fshare);
                    else {
                        // case both db has entry, update main with share db if main miss some attribute
                        DbFtype fmain = (DbFtype) map.get(key);
                        if((fmain != null) && (fmain.getUrlDescription() == null) && (fshare.getUrlDescription() != null)) {
                            map.remove(key);
                            map.put(key, fshare);
                            //  out.println(key + " from share is put into hash<br> ");
                        }
                    }
                }
            }
            Iterator it = map.values().iterator();
            while(it.hasNext())
                all.add(it.next());
        } catch(Exception e) {}

        return (DbFtype[]) all.toArray(new DbFtype[all.size()]);
    }


    static Vector mergeTracks(DbFtype[] t, Vector v) {
        Vector vkey = new Vector();
        Vector all = new Vector();
        for(int i = 0; i < t.length; i++) {
            String key = t[i].getFmethod() + "" + t[i].getFsource();
            if(!vkey.contains(key)) {
                all.add(t[i]);
                vkey.add(key);

            }
        }
        return all;
    }

    static DbFtype[] mergeMainTracks(DbFtype[] main, Vector vshare) {

        ArrayList list = new ArrayList();
        ArrayList all = new ArrayList();
        for(int i = 0; i < main.length; i++) {
            DbFtype f = main[i];
            list.add(f.getFmethod() + ":" + f.getFsource());
        }

        for(int j = 0; j < main.length; j++)
            all.add(main[j]);
        for(int i = 0; i < vshare.size(); i++) {
            DbFtype f = main[i];
            String key = (f.getFmethod() + ":" + f.getFsource());
            if(!list.contains(key))
                all.add(f);
        }

        return (DbFtype[]) all.toArray(new DbFtype[all.size()]);
    }

    public static DbFtype[] fetchUrlFromShareDB(Connection conn, DbFtype[] ftypes, javax.servlet.jsp.JspWriter out) {

        String method = null;
        String source = null;

        if(conn != null)
            try {
                PreparedStatement pstmt = null;

                String sql = "SELECT fu.url, fu.description, fu.label FROM featureurl fu, ftype f   " +
                        " WHERE f.ftypeid= fu.ftypeid and f.fmethod = ? and f.fsource = ? ";

                for(int i = 0; i < ftypes.length; i++) {
                    DbFtype ft = ftypes[i];
                    method = ft.getFmethod();
                    source = ft.getFsource();
                    pstmt = conn.prepareStatement(sql);
                    pstmt.setString(1, method);
                    pstmt.setString(2, source);


                    ResultSet rs = pstmt.executeQuery();
                    if(rs.next()) {
                        ft.setUrl(rs.getString(1));
                        ft.setUrlDescription(rs.getString(2));
                        ft.setUrlLabel(rs.getString(3));
                        //   out.println( " url  " + rs.getString(1)  + "  <br>label " + rs.getString(2)  +  "  <br>desc " +rs.getString(3) +  "<br>");

                    }

                }
                pstmt.close();

            } catch(Exception ex) {
                ex.printStackTrace();

                // if( ex instanceof SQLException && ((SQLException)ex).getErrorCode()==1146 )
                // createUrlTable( conn );
            }
        return ftypes;
    }
    
    public static DbFtype[] updateTrackandURL(DbFtype[] main, Vector vshare) {


        ArrayList list = new ArrayList();
        ArrayList all = new ArrayList();
        HashMap map = new HashMap();
        for(int i = 0; i < main.length; i++) {
            DbFtype f = main[i];
            list.add(f.getFmethod() + ":" + f.getFsource());
            map.put(f.getFmethod() + ":" + f.getFsource(), f);
        }

        ArrayList updateFtype = new ArrayList();

        // update main with share db information
        for(int i = 0; i < vshare.size(); i++) {
            DbFtype fshare = main[i];
            String key = (fshare.getFmethod() + ":" + fshare.getFsource());

            // if main  does not has this track, add to current url
            if(!list.contains(key))
                all.add(fshare);
            else {
                // case both db has entry, update main with share db if main miss some attribute
                DbFtype fmain = (DbFtype) map.get(key);
                if(fmain.getUrl() == null && fshare.getUrl() != null)
                    fmain.setUrl(fshare.getUrl());

                if(fmain.getUrlDescription() == null && fshare.getUrlDescription() != null)
                    fmain.setUrlDescription(fshare.getUrlDescription());

                if(fmain.getUrlLabel() == null && fshare.getUrlLabel() != null)
                    fmain.setUrlLabel(fshare.getUrlLabel());
                // end of update
                all.add(fmain);
                map.remove(key);
            }
        }


        Iterator it = map.values().iterator();
        while(it.hasNext())
            all.add(it.next());

        return (DbFtype[]) all.toArray(new DbFtype[all.size()]);
    }

    public static DbFtype[] updateURL(DbFtype[] tracks, DBAgent db, JspWriter out) {
        for(int i = 0; i < tracks.length; i++) {
            DbFtype ft = tracks[i];
            String dbName = ft.getDatabaseName();
            if(dbName == null)
                continue;
            Connection con = null;
            try {
                con = db.getConnection(dbName);


            } catch
                    (SQLException e) {
                db.reportError(e, "TrackManager.init()");

                continue;
            }

            tracks = fetchUrlFromShareDB(con, tracks, out);


        }
        return tracks;
    }
}
