package org.genboree.manager.tracks;

import org.genboree.dbaccess.*;

import java.sql.*;
import java.util.*;


/**
 * User: tong Date: Jul 29, 2005 Time: 4:27:37 PM
 */
public class ClassManager implements SqlQueries, SQLCreateTable {
  
    public static DbFtype[] checkEmptyTracks(DbFtype[] tracks, Connection con) {
        if (con == null) {
            System.err.println(" Classmanager.connection in cehckEMptyTrack() is null ");
            return null;
        }

        HashMap h = new HashMap();
        if (tracks != null && tracks.length > 0) {
            for (int i = 0; i < tracks.length; i++)
                h.put(tracks[i].getFmethod() + ":" + tracks[i].getFsource(), tracks[i]);
        }

        ArrayList list = new ArrayList();
        String sql = "select fmethod, fsource  from ftype  where ftypeid  not in " +
                " (select distinct ftypeid from ftype2gclass) ";

        try {
            PreparedStatement stms = con.prepareStatement(sql);
            ResultSet rs = stms.executeQuery();
            while (rs.next())
                list.add(rs.getString(1) + ":" + rs.getString(2));
            rs.close();
            stms.close();

        } catch (SQLException e) {
            System.err.println(" sql error happened in ClassManager.checkEmptyTrack()");
        }

        ArrayList list2 = null;
        if (!list.isEmpty()) {
            list2 = new ArrayList();
            for (int i = 0; i < list.size(); i++) {
                String key = (String) list.get(i);
                //  if (key.indexOf("Component") >= 0  && key.indexOf("Chromosome") >= 0 )
                //    continue;
                //    if (key.indexOf("Supercomponent") >= 0  && key.indexOf("Sequence") >= 0 )
                //     continue;
                if (h.get(key) != null)
                    list2.add((DbFtype) h.get(key));

            }
        }

        if (list2 != null)
            return (DbFtype[]) list2.toArray(new DbFtype[list2.size()]);
        else
            return null;
    }


    static ArrayList checkEmptyTracks(Connection con, DBAgent db) {
        ArrayList list = new ArrayList();
        try {
            if (con == null) {
                System.err.println(" Classmanager.connection in cehckEMptyTrack() is null ");
                return null;
            }

            String sql = getEmptyTrackIds(con, db);

            try {
                PreparedStatement stms = con.prepareStatement(sql);
                ResultSet rs = stms.executeQuery();
                while (rs.next()) {
                    list.add(rs.getString(1) + ":" + rs.getString(2));
                }
                rs.close();
                stms.close();
            } catch (Exception e) {
                e.printStackTrace();
                System.err.println(" sql error happened in ClassManager.checkEmptyTrack()\n " + sql);
            }

        } catch (Exception e) {}
        return list;
    }


    static String getEmptyTrackIds(Connection con, DBAgent db) {
        if (con == null) {
            System.err.println(" Classmanager.connection in cehckEMptyTrack() is null ");
            return null;
        }
        String sql = "select fmethod, fsource  from ftype  where ftypeid  not in ";

        //   " (select distinct ftypeid from ftype2gclass) " ;
        int count = 0;
        try {
            PreparedStatement stms = con.prepareStatement("select distinct ftypeid from ftype2gclass ");
            ResultSet rs = stms.executeQuery();
            String s = "'";
            while (rs.next()) {
                s = s + rs.getInt(1) + "', '";
                count++;
            }
            s = s.substring(0, s.lastIndexOf(','));
            sql = sql + "(" + s + ")";
            rs.close();
            stms.close();
        } catch (Exception e) {
            e.printStackTrace();
            System.err.println(" sql error happened in ClassManager.checkEmptyTrack()\n " + sql);
        }
        if (count == 0)
            sql = sql + " (-1)";
        return sql;
    }

    public static String[] getTrackNames(Connection con, int gid) {
        if (con == null) {
            System.err.println(" Classmanager.connection in cehckEMptyTrack() is null ");
            return null;
        }
        ArrayList list = new ArrayList();

        String sql = "select distinct  f.fmethod, f.fsource  from ftype f, ftype2gclass fg   where "
                + " fg.gid = ?  and fg.ftypeid = f.ftypeid";
        try {
            PreparedStatement stms = con.prepareStatement(sql);
            stms.setInt(1, gid);
            ResultSet rs = stms.executeQuery();

            while (rs.next()) {
                String key = rs.getString(1) + ":" + rs.getString(2);
                if (!list.contains(key))
                    list.add(key);
            }
            rs.close();
            stms.close();

        } catch (Exception e) {
            e.printStackTrace();
            System.err.println(" sql error happened in ClassManager.checkEmptyTrack()\n " + sql);
        }
        return (String[]) list.toArray(new String[list.size()]);
    }


    public static boolean isEmpty(String gname, DBAgent db, String dbName) {
        boolean b = true;
        try {
            Connection con = db.getConnection(dbName);
            int gid = getGid(con, gname);
            if (gid <= 0)
                return true;
            String sql = "select *  from ftype2gclass where gid ='" + gid + "'";
            PreparedStatement stms = con.prepareStatement(sql);
            ResultSet rs = stms.executeQuery();
            if (rs.next()) {
                b = false;
            }
            rs.close();
            stms.close();
        } catch (Exception e) {
            db.reportError(e, "TrackManager.isEmpty()");
        }
        return b;
    }


    public static void updateGclasses(Connection con, DbGclass[] gclasses) {

        String sql = "insert ignore into gclass (gclass)  values (?) ";
        if (con == null || gclasses == null)
            return;
        try {
            if (con == null || con.isClosed())
                return;
            PreparedStatement stms = con.prepareStatement(sql);
            for (int i = 0; i < gclasses.length; i++) {
                stms.setString(1, gclasses[i].getGclass());
                stms.executeUpdate();
            }
            stms.close();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
   
    public static DbGclass updateGclass(DbGclass gclass,  Connection con) {              
                int id = insertGclass( con, gclass.getGclass());
                if (id > 0) {
                    gclass.setGid(id);
                    gclass.setLocal(true);  
                } 
                else
                return null;
          return gclass;
    }

      public static boolean updateClass(int gid, String newName, Connection con) { 
        String sql = "update  gclass  set gclass = ?  where gid = ? " ;
        boolean success = false;
        try {
            PreparedStatement stms = con.prepareStatement(sql);
            stms.setString(1, newName);
            stms.setInt(2, gid);
            stms.executeUpdate();
            success = true;
            stms.close();
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return success;
    }
    

    public static int insertGclass(Connection con, String gclass) {
        int id = -1;
        if (gclass == null || gclass.compareTo("") == 0) 
            return -1;
        gclass = gclass.trim();   
        String sql = "insert ignore into gclass (gclass) values (?) ";
        try {  
            PreparedStatement stms = con.prepareStatement(sql);
            stms.setString(1, gclass);
            stms.executeUpdate();
            stms = con.prepareStatement("SELECT LAST_INSERT_ID()");
            ResultSet rs = stms.executeQuery();
            if (rs.next()) {
                id = rs.getInt(1);
            }
            rs.close();
            stms.close();
        } catch (Exception e) {
            e.printStackTrace();
        }
        return id;
    }
 
  
    public static String[] findClassGids(String[] dbNames, String localdbName, DbFtype clsTrack, DBAgent db) {
        if (clsTrack == null)
            return null;
        ArrayList list = new ArrayList();
        String dbName = null;
        String sql = "select distinct gid from ftypetogclass where ftypeid in " +
                " (select distinct ftypeid from ftype where fmethod = ? and fsouce = ? ) ";
        for (int i = 0; i < dbNames.length; i++) {
            dbName = dbNames[i];
            if (dbName.compareTo(localdbName) == 0)
                continue;
            try {
                Connection con = db.getConnection(dbName);
                PreparedStatement stms = con.prepareStatement(sql);
                stms.setString(1, clsTrack.getFmethod());
                stms.setString(2, clsTrack.getFsource());
                ResultSet rs = stms.executeQuery();
                while (rs.next())
                    list.add(rs.getString(1));
                rs.close();
                stms.close();
                con.close();
            } catch (SQLException e) {
                System.err.println(" sql error happened in ClassManager.findClassGids()");
                continue;
            }
        }

        return (String[]) list.toArray(new String[list.size()]);
    }


    public static String[] findGids(Connection conn, DbFtype ft) {
        Vector v = new Vector();
        if (conn != null && ft != null)
            try {
                Statement stmt = conn.createStatement();
                ResultSet rs = stmt.executeQuery("SELECT gid FROM ftypetogclass WHERE ftypeid=" + ft.getFtypeid());
                while (rs.next()) {
                    v.addElement(rs.getString(1));
                }
                stmt.close();
            } catch (Exception ex) {
                if (ex instanceof SQLException && ((SQLException) ex).getErrorCode() == 1146)
                    Utility.createTable(conn, createTableFtype2gclass);
            }
        String[] rc = new String[v.size()];
        v.copyInto(rc);
        return rc;
    }

  
    public static boolean updateTrackMap(Connection con,  DbFtype selTracks [], int gid) {
           boolean b = false;
           try {
               if (con != null && !con.isClosed()) {
                   Statement stmt = con.createStatement();
                   stmt.executeUpdate("DELETE FROM ftype2gclass WHERE gid = " + gid);
                   stmt.close();
                   PreparedStatement pstmt = null;
                   if (selTracks != null && selTracks.length > 0) {
                       int ftypeid = 0;
                       for (int i = 0; i < selTracks.length; i++) {
                           DbFtype ft = selTracks[i];
                           if (ft == null) {
                               continue;
                           }
                           ftypeid = findFtypeId(ft, con);
                           String sql = "INSERT ignore  INTO ftype2gclass (gid, ftypeid) VALUES (" + gid + ", " + ftypeid + ")";
                           pstmt = con.prepareStatement(sql);
                           pstmt.executeUpdate();
                       }
                       b = true;
                   }

                   if (pstmt != null)
                       pstmt.close();
               }

           } catch (Exception ex) {
               ex.printStackTrace();
           }
           return b;
       }
 
    public static void updateGclassInfo(HashMap h, DbGclass gclass,DbFtype [] selTracks,  Connection con) {
         int gid = findGid(gclass.getGclass(), con);
         for (int i = 0; i < selTracks.length; i++) {
            DbFtype ft = selTracks[i];
            if (h.get(ft.toString()) != null) {
                int id = -1;
                id = findFtypeId(ft, con);
                ft.setFtypeid(id);
            }
        }
    }

    public static DbFtype[] updateFtype(DbFtype[] ftypes, Connection con, String dbName) throws SQLException {     
        if (ftypes != null && ftypes.length > 0) {
            for (int i = 0; i < ftypes.length; i++) {
                DbFtype ft = ftypes[i];
                if (ft == null)
                    continue;
                if (ft.getFmethod() == null || ft.getFsource() == null)
                    continue;
                if (!inFtype(ftypes[i].getFmethod(), ftypes[i].getFsource(),  con)) {
                    int id = insertFtype(ftypes[i].getFmethod(), ftypes[i].getFsource(), con);
                    if (id > 0) {
                        ftypes[i].setFtypeid(id);
                        ftypes[i].setDatabaseName(dbName);
                    } else {
                        throw new SQLException("failed in insert new ftype ");
                    }
                }
            }
        }
        return ftypes;
    }


    public static void deleteClass(String[] gclassids, TrackManagerInfo info, DBAgent db) {
        if (gclassids == null || gclassids.length <= 0)
            return;
        String sql = "delete from gclass where gclass = ? ";
        try {
            Connection con = db.getConnection(info.getDbName());
            PreparedStatement stms = con.prepareStatement(sql);
            for (int i = 0; i < gclassids.length; i++) {
                stms.setString(1, gclassids[i]);
                stms.executeUpdate();
            }
            stms.close();
        } catch (SQLException e) {
            db.reportError(e, "TrackManager.deleteClass");
        }
    }

    public static int insertFtype(String fmethod, String fsource, Connection con) {
        int id = -1;
        String sql = "insert ignore into ftype (fmethod, fsource) values (?,? )";
        try {        
            PreparedStatement stms = con.prepareStatement(sql);
            stms.setString(1, fmethod);
            stms.setString(2, fsource);
            stms.executeUpdate();
            stms = con.prepareStatement("SELECT LAST_INSERT_ID()");
            ResultSet rs = stms.executeQuery();
            if (rs.next())
                id = rs.getInt(1);
            rs.close();
            stms.close();
        } catch (SQLException e) {         
            e.printStackTrace();
            return -1;
        }
        return id;
    }

    /*
    public static void doClassify ( TrackManagerInfo info, DBAgent db , HttpSession mys,  HttpServletRequest request, HttpServletResponse response,  JspWriter out) {
    if (info.getAcs_level() < 1) {
    info.mode = TrackMgrConstants.MODE_DEFAULT;
    info.setNo_acs(true);
    return;
    }
    else  {
    info.vBtn.addElement(TrackMgrConstants.btnApply);
    info.vBtn.addElement(TrackMgrConstants.btnReset);
    }
    }
    */

    public static DbGclass[] setClassTrackInfo(DbGclass[] gclasses, String dbName, DBAgent db) {
        if (gclasses == null || gclasses.length <= 0)
            return gclasses;
        //check if class if empty

        for (int i = 0; i < gclasses.length; i++) {
            if (isEmpty(gclasses[i].getGid(), db, dbName))
                gclasses[i].setEmpty(false);
            else
                gclasses[i].setEmpty(true);
        }

        return gclasses;
    }


    public static boolean isEmpty(int gid, DBAgent db, String dbName) {
        boolean b = true;
        String sql = "select  ftypeid  from ftype2gclass where gid = ? ";

        try {
            Connection con = db.getConnection(dbName);
            PreparedStatement stms = con.prepareStatement(sql);
            stms.setInt(1, gid);
            ResultSet rs = stms.executeQuery();
            if (rs.next()) {
                b = false;
            }
            rs.close();
            stms.close();
        } catch (SQLException e) {
            db.reportError(e, "TrackManager.isEmpty()");
        }
        return b;
    }


    public static boolean inFtype(String fmethod, String fsource,  Connection con) {
        boolean b = false;
        String sql = "select *   from ftype where fmethod = ? and fsource = ?";
 
        try {
            PreparedStatement stms = con.prepareStatement(sql);
                stms.setString(1, fmethod);
                stms.setString(1, fsource);
                ResultSet rs = stms.executeQuery();
            if (rs.next()) {
                b = true;
            }
            rs.close();
            stms.close();
        } catch (SQLException e) {          
          e.printStackTrace();
        }
        return b;
    }


public static boolean inGclass(String name, Connection con) {
    if (name == null || name.compareTo("") == 0)
    return false;
    boolean b = false;
    try {
    String sql = "select * from gclass where gclass = ? ";
    PreparedStatement stms = con.prepareStatement(sql);
    stms.setString(1, name);
    ResultSet rs = stms.executeQuery();
    if (rs.next()) {
    b = true;
    }
    rs.close();
    stms.close();
    
    } catch (Exception e) {
    e.printStackTrace();
    System.out.println("TrackManager.inClass()");
    }
    return b;
}


    /**
      * quick retirve if class from database
     * @param con
     * @return array of   DbGcalss, null if none found  
     * @since  modified Otc10, 2006 
     */
    public static DbGclass[] fetchFgroups(Connection con) {
        ArrayList list = new ArrayList ();     
        String sql = "SELECT gid, gclass FROM gclass order by gclass";
        try {
                PreparedStatement pstmt = con.prepareStatement(sql);
                ResultSet rs = pstmt.executeQuery();
                while (rs.next()) {
                    DbGclass p = new DbGclass();
                    p.setGid(rs.getInt(1));
                    p.setGclass(rs.getString(2));
                    //if( p.getGclass().compareToIgnoreCase("Sequence") != 0 )
                    list.add(p);
                }
                rs.close();
                pstmt.close();
        } 
        catch (Exception ex) {
            ex.printStackTrace();
        }
        DbGclass[] rc = null; 
        if (!list.isEmpty()) {
            rc = new DbGclass[list.size()];
          rc = (DbGclass [])list.toArray(new DbGclass [list.size()]);
        }

        return rc;
    }


    public static int findGid(String className, Connection con) {
        int id = -1;
        String sql = "select distinct gid from gclass where gclass = ? ";
        try {

            if (con == null || con.isClosed()) {
                return -1;
            }
            PreparedStatement stms = con.prepareStatement(sql);
            stms.setString(1, className);
            ResultSet rs = stms.executeQuery();
            if (rs.next())
                id = rs.getInt(1);
            rs.close();
            stms.close();

        } catch (SQLException e) {
          e.printStackTrace();
        }
        return id;
    }


    public static int findFtypeId(DbFtype ft, Connection con) {
        int id = -1;
        String sql = "select distinct ftypeId from ftype where fmethod  = ?  and fsource = ? ";
        try {
            PreparedStatement stms = con.prepareStatement(sql);
            stms.setString(1, ft.getFmethod());
            stms.setString(2, ft.getFsource());
            ResultSet rs = stms.executeQuery();
            if (rs.next())
                id = rs.getInt(1);
            rs.close();
            stms.close();

        } catch (SQLException e) {
           e.printStackTrace();
            return -1;
        }
        return id;
    }


    public static Vector findGid(String dbName, DBAgent db, int ftypeId) {
        Vector vClsDef = new Vector();
        String sql = "select distinct gid from ftype2gclass where ftypeid = " + ftypeId;
        try {
            Connection con = db.getConnection(dbName);

            if (con == null || con.isClosed()) {

                return null;
            }
            PreparedStatement stms = con.prepareStatement(sql);
            ResultSet rs = stms.executeQuery();

            while (rs.next()) {
                vClsDef.addElement(rs.getString(1));
            }

            rs.close();
            stms.close();

        } catch (SQLException e) {
            db.reportError(e, "ClassManager.findGid()");
            return null;
        }
        return vClsDef;
    }


    /**
     * @param dbName String local database name
     * @param tracks DbFtype []
     * @param db     DbAGent
     *
     * @return Hashtable object, could be empty
     */


    public static Hashtable fetchSharedFgroups(String dbName, DbFtype[] tracks, DBAgent db) {
        Hashtable ftypeid2classid = new Hashtable();
        if (tracks == null)
            return ftypeid2classid;
        Hashtable h = new Hashtable();
        for (int i = 0; i < tracks.length; i++) {
            if (h.get(tracks[i].getDatabaseName()) == null) {
                Vector v = new Vector();
                v.add(tracks[i]);
                h.put(tracks[i].getDatabaseName(), v);
            } else {
                Vector v = (Vector) h.get(tracks[i].getDatabaseName());
                v.add(tracks[i]);
                h.remove(tracks[i].getDatabaseName());
                h.put(tracks[i].getDatabaseName(), v);
            }
        }

        if (h.isEmpty())
            return ftypeid2classid;

        Iterator it = h.keySet().iterator();
        while (it.hasNext()) {
            String key = (String) it.next();
            Vector v = (Vector) h.get(key);
            ftypeid2classid = findGclass(key, v, db, ftypeid2classid);
        }

        return ftypeid2classid;
        //return null;
    }


    public static Hashtable findGclass(String dbName, Vector tracks, DBAgent db, Hashtable h) {
        if (dbName == null || tracks == null)
            return null;
        String sql = "SELECT DISTINCT g.gid, g.gclass " +
                "FROM ftype2gclass fg, gclass g " +
                "WHERE fg.ftypeid = ? AND fg.gid = g.gid";
        try {
            Connection con = db.getConnection(dbName);
            PreparedStatement stms = con.prepareStatement(sql);
            ResultSet rs = null;
            if (!tracks.isEmpty()) {
                for (int i = 0; i < tracks.size(); i++) {
                    DbFtype ft = (DbFtype) tracks.get(i);
                    Vector v = new Vector();

                    if (ft != null)
                        stms.setInt(1, ft.getFtypeid());
                    rs = stms.executeQuery();
                    while (rs.next()) {
                        DbGclass c = new DbGclass();
                        c.setGid(rs.getInt(1));
                        c.setGclass(rs.getString(2));
                        c.setEmpty( false);
                        c.setLocal( false);
                        v.add(c);
                    }
                    h.put("" + ft.getFmethod() + ":" + ft.getFsource(), v);
                }
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return h;
    }


    public static Vector findShareClassIds(DbFtype clsTrack, String[] dbNames, String localdbName, DBAgent db) {
        String[] classIds = null;
        Vector v = new Vector();
        if (clsTrack != null) {
            String fmethod = clsTrack.getFmethod();
            String fsource = clsTrack.getFsource();
            int ftypeid = -1;

            if (dbNames != null && dbNames.length > 1) {
                for (int i = 0; i < dbNames.length; i++) {
                    if (dbNames[i].compareTo(localdbName) != 0) {
                        Connection conn = null;
                        try {
                            conn = db.getConnection(dbNames[i]);
                            PreparedStatement stms = conn.prepareStatement("select distinct  ftypeid from ftype where fmethod = ? and fsource = ? order by fmethod ");
                            stms.setString(1, fmethod);
                            stms.setString(2, fsource);
                            ResultSet rs = stms.executeQuery();
                            if (rs.next()) {
                                ftypeid = rs.getInt(1);
                            }

                            if (ftypeid >= 0) {
                                stms = conn.prepareStatement("SELECT DISTINCT g.gid, g.gclass " +
                                        " FROM ftype2gclass fg, gclass g WHERE fg.ftypeid = ? AND fg.gid = g.gid");
                                stms.setInt(1, ftypeid);
                                rs = stms.executeQuery();
                                while (rs.next()) {
                                    DbGclass p = new DbGclass();
                                    p.setGid( rs.getInt(1));
                                    p.setGclass(rs.getString(2));
                                    p.setEmpty(false);
                                    p.setLocal( false);
                                    v.add(p);
                                }

                            }
                            rs.close();
                            stms.close();
                            conn.close();

                        } catch (SQLException e) {
                            e.printStackTrace();
                        }
                    }

                }
            }
        }


        return v;

    }

 public static DbGclass[]  retrieveClasses(Connection con, boolean isLocal ) throws SQLException { 
     ArrayList list = new ArrayList ();     
        String sql = "SELECT gid, gclass FROM gclass order by gclass";
        try {
                PreparedStatement pstmt = con.prepareStatement(sql);
                ResultSet rs = pstmt.executeQuery();
                while (rs.next()) {
                    DbGclass p = new DbGclass();
                    p.setGid(rs.getInt(1));
                    p.setGclass(rs.getString(2));
                    p.setLocal(isLocal);
                    // comment:  this is because some one may want to use this class                
                    //if( p.getGclass().compareToIgnoreCase("Sequence") != 0 )
                        list.add(p);
                }
                rs.close();
                pstmt.close();
        } 
        catch (SQLException ex) {
            ex.printStackTrace(System.err);
            System.err.println("Errors in retrieveClasses");
            System.err.flush();
           throw ex;
        }
        DbGclass[] rc = null; 
        if (!list.isEmpty()) {
            rc = new DbGclass[list.size()];
          rc = (DbGclass [])list.toArray(new DbGclass [list.size()]);
        }

        return rc;  
}
     
    
    
/**
 * retrieves class information from shared databses, except class "Sequence"(why?)
 * @param dbNames
 * @param db
 * @return
 */

public static DbGclass[] retrieveShareClasses(String[] dbNames, DBAgent db) { 
    ArrayList list  = new ArrayList();
    ArrayList classNames = new ArrayList();
    if (dbNames != null ) {
        for (int i = 0; i < dbNames.length; i++) {         
            Connection conn = null;
            try {
                conn = db.getConnection(dbNames[i]);
                PreparedStatement stms = conn.prepareStatement("SELECT DISTINCT gid, gclass " +
                " FROM  gclass  order by gclass");
                ResultSet rs = stms.executeQuery();
                while (rs.next()) {
                    DbGclass p = new DbGclass();
                    p.setGid (rs.getInt(1));
                    p.setGclass (rs.getString(2));
                    p.setEmpty(false);
                    p.setLocal(false);
                   // if (!classNames.contains(p.getGclass()) && p.getGclass().compareToIgnoreCase("Sequence") != 0 )
                   if (!classNames.contains(p.getGclass()))  {
                        list.add(p);
                        classNames.add(p.getGclass());
                    }
                }
                rs.close();
                stms.close();
              
            } 
            catch (SQLException e) {
            e.printStackTrace();
            }
        }
    }
    DbGclass[] gclasses = null; 
    if (!list.isEmpty()) 
       gclasses = (DbGclass [])list.toArray(new DbGclass [list.size()]);
    return gclasses;
}
 
 
 /**
  * retrives all tracks, local database first, sorted in alphabetical order by track names  
  
  * @param db
  
  * @return
  * @throws SQLException
  */ 
    public static DbFtype[] retrieveAllSharedTracksSorted(String [] dbNames, DBAgent db, int genboreeUserId) throws SQLException {   
       HashMap name2track = new HashMap ();
       ArrayList trackNameList = new ArrayList (); 
         try {
             for (int i = 0; i < dbNames.length; i++) {
                DbFtype[] tracks = DbFtype.fetchAll(db.getConnection(dbNames[i]), dbNames[i], genboreeUserId );
                 if (tracks == null)
                   continue; 
                 for (int j = 0; j < tracks.length; j++) {
                     DbFtype ft = tracks[j];
                     String key = ft.toString();
                     if (key.compareToIgnoreCase("Component:Chromosome") == 0 ||
                             key.compareToIgnoreCase("Supercomponent:Sequence") == 0)
                         continue;                   
                    if (name2track.get(key) == null)  { 
                        ft.setDatabaseName(dbNames[i]);
                        name2track.put(key, ft);
                        trackNameList.add(ft.toString());
                    }
                 }
             }
   
         } catch (Exception ex) {
             ex.printStackTrace();
             db.reportError(ex, "TrackManager.fetchTracksSorted()");
         }
     
         DbFtype[] rc = new DbFtype[name2track.size()];
         String [] trackNames =(String []) trackNameList.toArray(new String [trackNameList.size()]); 
      
       // put unique tracks to array 
         for (int i=0; i<trackNames.length; i++) {
             rc[i] = (DbFtype) name2track.get(trackNames[i]);
         }
           return rc;
     }
 
public static int getGid(Connection conn, String gclass) {
    String sql = null;
    int gid = 0;
    if (gclass != null)
    try { 
        PreparedStatement stms =
        conn.prepareStatement("select distinct gid from gclass where gclass = ? ");
        stms.setString(1, gclass);
        ResultSet rs = stms.executeQuery();
        if (rs.next())
        gid = rs.getInt(1);
        if (gid <= 0)
        return -1;
        rs.close();
        stms.close();
    }
    catch (Exception ex) {
        System.err.println(sql);
        ex.printStackTrace();
    }
    return gid;
}
    
    
    public static HashMap retrieveAllSharedTrack2Classes(DBAgent db,DbFtype[] tracks, String []dbNames, String localdbName) throws Exception {
        HashMap tk2g = new HashMap();
        if (tracks == null || dbNames == null )
        return tk2g;
        String dbName = null;
        HashMap db2trackclass = new HashMap (); 
    for(int i = 0; i < dbNames.length; i++)
    {
        Connection con = null;
        try {
            if (dbNames[i].compareTo(localdbName)==0) 
            continue;
              con = db.getConnection(dbNames[i]);
            HashMap track2Classes =  ClassManager.retrieveTrack2Classes (tracks, con, false);
            if (track2Classes != null && !track2Classes.isEmpty()) 
            db2trackclass.put(dbNames[i], track2Classes);                                                                  
        }
        catch(Exception e) {
           System.err.println(e.getMessage() + ": sql error happened in ClassManager.populateSharedTrack2Classes<br>" + " in db: " + dbName);
            e.printStackTrace();   
        }    
    }
    
        // merge classes 
    HashMap   track2classNames  = new HashMap ();   
    if (!db2trackclass.isEmpty()) {
                Iterator iterator = db2trackclass.values().iterator();
            while (iterator.hasNext()) {
                 HashMap temp = (HashMap)iterator.next();  
                 if (temp!=null && !temp.isEmpty()) {
                       Iterator it1 = temp.keySet().iterator();  
                       while (it1.hasNext()) {
                           String trackName = (String)it1.next();  
                           ArrayList list = (ArrayList)temp.get(trackName); 
                              
                           
                        if (list != null && !list.isEmpty()) {
                            ArrayList existingClassNameList = (ArrayList) track2classNames.get(trackName); 
                            ArrayList existingClassList = (ArrayList)tk2g.get(trackName);
                            if (existingClassList == null) 
                                existingClassList = new ArrayList (); 
                             if (existingClassNameList == null) 
                                 existingClassNameList = new ArrayList(); 
                               
                               
                               for (int i=0; i<list.size(); i++) {
                               DbGclass gclass = (DbGclass) list.get(i); 
                                
                               if (!existingClassNameList.contains(gclass.getGclass())) {
                                   existingClassNameList.add(gclass.getGclass()); 
                                   track2classNames.remove(trackName);
                                   track2classNames.put(trackName, existingClassNameList); 
                                   existingClassList.add(gclass); 
                                   tk2g.remove(trackName);
                                   tk2g.put(trackName, existingClassList); 
                               }
                               
                               } 
                           }                               
                       }  
                 }
            }
        }
       
    return tk2g;
    }
    
    /**
        * @param tracks DbFtype []
        *@param isLocal : boolean indicating if a database is local database (true) or from shared database (false)
        * @return Hashmap from feature2class,  could be empty 
        *
         */
       public static HashMap  retrieveTrack2Classes(DbFtype[] tracks, Connection con, boolean isLocal) {    
           HashMap t2k = new HashMap ();            
        HashMap  track2Classes = new HashMap();
        if (tracks == null || tracks.length ==0)
        return track2Classes ;   
        String trackIds = ""; 
        for (int i = 0; i < tracks.length-1; i++) {
        trackIds += tracks[i].getFtypeid() + ", "; 
        }
        trackIds += tracks[tracks.length-1].getFtypeid(); 
        
        String sql = "SELECT g.gid, g.gclass, ft.fmethod, ft.fsource " +
        "FROM ftype2gclass fg, gclass g, ftype ft " +
        "WHERE fg.ftypeid in (" + trackIds + " ) and ft.ftypeid = fg.ftypeid AND fg.gid = g.gid";
        ArrayList mapList = new ArrayList ();
        try {
        Statement stms = con.createStatement();                                   
        ResultSet rs = stms.executeQuery(sql);
        
        while (rs.next()) {
        ArrayList list  = new ArrayList ();
        list.add (0, rs.getString(3) + ":" + rs.getString(4));     
        list.add(1, "" + rs.getInt(1));
        list.add(2, rs.getString(2));
      
        mapList.add(list); 
        }
        }    
        catch (SQLException e) {
        e.printStackTrace();
        }
        
        String trackName = null; 
        String gid = null; 
        String className = null; 
        ArrayList list = null; 
        // process information from db 
        if (!mapList.isEmpty()) {
        for(int i=0; i<mapList.size(); i++) {
            list =(ArrayList) mapList.get(i); 
            trackName = (String)list.get(0);  
            DbGclass g = new DbGclass(); 
            g.setEmpty(false);
            g.setLocal(isLocal);   
            
            gid = (String) list.get(1) ; 
            if (gid != null) 
            g.setGid(Integer.parseInt(gid));
            
            className = (String) list.get(2);
            g.setGclass(className);
            // new entry in hashmap 
            if (track2Classes.get(trackName) == null ) {
            
            HashMap name2Class = new HashMap();                
            name2Class.put(className, g); 
            
            track2Classes.put(trackName, name2Class); 
            
            } 
            else { // existing entry 
                HashMap name2Class = (HashMap) track2Classes.get(trackName); 
                // use hashmap to check the class is alreay in the track 
                if (name2Class.get(className) == null){                    
                    name2Class.put(className, g); 
                    track2Classes.remove(trackName);
                    track2Classes.put(trackName, name2Class);                    
                }
            } 
        }
        
        // change hashmap to arry list  
            
            
        Iterator iterator = track2Classes.keySet().iterator();  
     
        while (iterator.hasNext()) {
          String key  = (String)iterator.next();  
            HashMap map = (HashMap)track2Classes.get(key);
            if (!map.isEmpty()) {
                ArrayList classlist = new ArrayList (map.values());             
                t2k.put(trackName, classlist);   
            }  
        }                       
        }
       
        return  t2k;
        }
    
    
    public static void deleteClassMappingById(Connection conn, int id) {
         try {
             PreparedStatement stmt = conn.prepareStatement("DELETE FROM ftype2gclass WHERE gid = ? ");
             stmt.setInt(1, id);
             stmt.executeUpdate();
             stmt.close();
         }
         catch (SQLException ex) {
             ex.printStackTrace();
         }
     }

     public static void deleteClassMappingByName(String gname, Connection con ) {
           try {       
               int gid = getGid(con, gname);
               if (gid <= 0)
                   return;
               String sql = "delete  from ftype2gclass where gid =" + gid;
               PreparedStatement stms = con.prepareStatement(sql);
               stms.executeUpdate();
               stms.close();
           } catch (SQLException e) {
            e.printStackTrace(); 
           }
       }
     
    
  
    
}