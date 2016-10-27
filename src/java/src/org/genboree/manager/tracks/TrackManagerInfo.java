package org.genboree.manager.tracks;

import org.genboree.dbaccess.*;
import org.genboree.util.GenboreeUtils;
import org.genboree.util.SessionManager;
import org.genboree.util.Util;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;
import javax.servlet.jsp.JspWriter;
import java.io.IOException;
import java.sql.*;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Hashtable;
import java.util.Vector;

/**
 * User: tong Date: Jul 20, 2005 Time: 9:21:15 AM
 */
public class TrackManagerInfo
{
    private Refseq rseq;
    String refSeqId;
    private String localdbName;
    private String[] dbNames;
    Hashtable name2Track = new Hashtable();
    private String destback;
    private boolean auto_goback;
    private boolean hasSubordinateDB;
    private String[] subdbNames;
    private int userId;
    int mode;
    boolean is_admin;

    String editClassName;
    String myGrpAccess;
    // error log and log vectors
    Vector verr;

    Vector vBtn;
    String[] btnBack;
    boolean old_db;
    boolean from_default;
    int fetchUserId;
    int classmode = 13;
    boolean is_preview;
    Vector shareclasses;
    boolean no_acs;
    String clsdatacnt;
    String oldRefseqId;
    private DbFtype[] tracks;
    private DbFtype[] shareTracks ;
    private DbFtype[] localTracks ;
    private DbFtype [] orderTracks;
    ArrayList allLocalTrackNameList;

    public ArrayList getSharedOnlyTrackNames() {
        return sharedOnlyTrackNames;
    }

    public void setSharedOnlyTrackNames(ArrayList sharedOnlyTrackNames) {
        this.sharedOnlyTrackNames = sharedOnlyTrackNames;
    }

    ArrayList sharedOnlyTrackNames ;
    private DbFtype[] allLocalTracks;
    DbFtype[] urltracks;
    DbGclass[] gclasses;
    Hashtable htGroupLookup;
    String oldClassName;
    DbGclass editingClass;
    Hashtable hftypeidtogid;
    DbFtype clsTrack;
    HashMap htTrackSel;
    String[] localClassIds;
    DbFtype editTrack;
    String editTrackId;
    String[] trackNames;
    Hashtable trackLookup;
    int cmd;
    Style[] styleList;
    Style[] colorList;
    Style[] styleMap;
    DbFtype[] selTracks;
    String[] clsTrackNames;
    int iEditTrackId;
    // track error hashtable of ht
    Hashtable htTrkErr;
    Refseq[] rseqs;
    DbFtype [] sharedOnlyTracks ;

    public Hashtable getName2Track(){
        return name2Track;
    }

    public void setName2Track(Hashtable name2Track) {
        this.name2Track = name2Track;
    }

    public void init(String[] userInfo, Refseq[] rseqs, HttpSession mys, HttpServletRequest request, HttpServletResponse response, JspWriter out, DBAgent db, int genboreeUserId) throws IOException
    {
      this.rseqs = rseqs;
        // check to see if removable
        /*****/
      if(userInfo[0] == null || userInfo[1] == null || userInfo[2] == null){
        userInfo = null;
      }
      if(userInfo != null)
          is_admin = userInfo[0].equals("admin");

      this.vBtn = new Vector();
      iEditTrackId = -1;
      htTrackSel = new HashMap();
      destback = (String) mys.getAttribute("destback");
      if(destback == null)
        destback = "/java-bin/login.jsp";
      auto_goback = (destback.indexOf("gbrowser.jsp") >= 0);

      // get request1 mode
      String pMode = request.getParameter("mode");
      mode = TrackMgrConstants.MODE_DEFAULT;
      if(pMode != null)
      {
        for(int i = 0; i < TrackMgrConstants.modeIds.length; i++)
        {
          if(pMode.equals(TrackMgrConstants.modeIds[i]))
          {
            this.mode = i ;
            break ;
          }
        }
      }
      // error log and log vectors
      this.verr = new Vector();

      // button vectors and array of button names
      htGroupLookup = new Hashtable();
      // track error hashtable of ht
      this.htTrkErr = new Hashtable();
      // retrive last editted refseq id
      oldRefseqId = SessionManager.getSessionDatabaseId(mys);
      // get current refseq id
      this.refSeqId = request.getParameter("rseq_id");

      if(refSeqId == null)
        refSeqId = oldRefseqId;

      if(refSeqId == null)
        refSeqId = "#";
      this.old_db = ((oldRefseqId != null) && (this.refSeqId == null || this.refSeqId.equals(oldRefseqId)));
      userId = Util.parseInt(userInfo[2], -1);
      fetchUserId = userId;
      Connection localcon = null;
      if(mode != TrackMgrConstants.MODE_DEFAULT)
        is_preview = (request.getParameter(TrackMgrConstants.btnPreview[1]) != null);
      trackLookup = new Hashtable();

      if(rseqs == null || rseqs.length <= 0)
        return;
      for(int i = 0; i < rseqs.length; i++){
        if(rseqs[i].getRefSeqId().equals(refSeqId))
        {
          rseq = rseqs[i];
          break;
        }
      }

      if(rseq == null) {
          return ;
      }

     if(!old_db)
        mys.removeAttribute("featuretypes");

      if(rseq != null)
          localdbName = rseq.getDatabaseName();

      try{
        if(rseq != null)
          dbNames = rseq.fetchDatabaseNames(db);
      }
      catch(SQLException e){
        // db.reportError(e, "TrackManagerInfo.init()");
        mys.setAttribute("lastError", db.getLastError());
        GenboreeUtils.sendRedirect(request,response, "/java-bin/error.jsp");
      }

      if(localdbName != null){
        try{
          subdbNames = SubOrdinateDBManager.findSubordinateDBNames(db, localdbName);
        }
        catch(SQLException e)
        {
          db.reportError(e, "TrackManager.init()");
          mys.setAttribute("lastError", db.getLastError());
          GenboreeUtils.sendRedirect(request,response, "/java-bin/error.jsp");
        }
      }
      this.old_db = ((oldRefseqId != null) && (this.refSeqId == null || this.refSeqId.equals(oldRefseqId)));

      if(subdbNames != null && subdbNames.length > 0)
        hasSubordinateDB = true;

      // Cache the connection to the local DB, at least in this init() method:

      try {
        localcon = db.getConnection(localdbName);
      }
      catch(SQLException e){
        //  db.reportError(e, "TrackManager.init()");
          e.printStackTrace();
        return;
      }

      // Get SHARED tracks:
      DbFtype[] currSharedTracks = null ;
      ArrayList allSharedTracks = new ArrayList() ;
      HashMap sharedTrackHash = new HashMap() ;
      Connection con = null;
        this.sharedOnlyTrackNames = new ArrayList();
      for(int jj = 0; jj < dbNames.length; jj++) {
            if(rseq.getDatabaseName().compareTo(dbNames[jj]) == 0) // skip the local db
            continue;
            try{

                con = db.getConnection(dbNames[jj]);
                 // Get the tracks from the current shared databases (eg template databases)
                currSharedTracks = DbFtype.fetchAll(con, dbNames[jj], genboreeUserId );
                 if(currSharedTracks == null || currSharedTracks.length == 0)
                continue;

                // Add URL info to the shared tracks:
                currSharedTracks = URLShareManager.fetchUrlFromShareDB(con, currSharedTracks, out);
                if (currSharedTracks != null)
                for(int ii = 0; ii < currSharedTracks.length; ii++) {
                    DbFtype ft = currSharedTracks[ii];
                    String key = ft.toString();
                    if(key.compareToIgnoreCase("Component:Chromosome") == 0 || key.compareToIgnoreCase("Supercomponent:Sequence") == 0)
                    continue;
                    else {
                        ft.setDatabaseName(dbNames[jj]);
                        allSharedTracks.add(ft) ;
                        sharedTrackHash.put(key, ft) ;
                    }
                }
            }
            catch(SQLException e){
                e.printStackTrace();
                continue;
            }
      }
      this.shareTracks = (DbFtype[]) allSharedTracks.toArray(new DbFtype[allSharedTracks.size()]) ;

      // Get LOCAL tracks: (not any shared with same name)
      ArrayList localTracksList = new ArrayList() ;
     ArrayList allLocalTracksList = new ArrayList();
        this.allLocalTrackNameList = new ArrayList();
       String[] sharedOnlyTrackNamesArr = null;
      if(localdbName != null && localcon != null)
      {
        try {
          localcon = db.getConnection(localdbName);
          this.localTracks = DbFtype.fetchAll(localcon, localdbName, genboreeUserId);
          this.allLocalTracks = null;
          for(int ii = 0; ii < this.localTracks.length; ii++){
            String key = this.localTracks[ii].toString() ;
            if( key.compareToIgnoreCase("Component:Chromosome") == 0 ||
                key.compareToIgnoreCase("Supercomponent:Sequence") == 0 )
              continue;
            else {
              if ( !sharedTrackHash.containsKey(key) ){
                this.localTracks[ii].setDatabaseName(localdbName) ;
                localTracksList.add(this.localTracks[ii]) ;
              }
                allLocalTracksList.add(this.localTracks[ii]);
                this.allLocalTrackNameList.add(this.localTracks[ii].toString());
            }
          }

          this.localTracks = (DbFtype[]) localTracksList.toArray(new DbFtype[localTracksList.size()]) ;
          this.allLocalTracks = (DbFtype[]) allLocalTracksList.toArray(new DbFtype[allLocalTracksList.size()]);

            ArrayList sharedOnlyTrackList = new ArrayList ();
            for (int i = 0; i <  this.shareTracks.length; i++) {
                String trackNm =  this.shareTracks[i].toString();

                if (!this.allLocalTrackNameList.contains(trackNm)) {
                    this.sharedOnlyTrackNames.add(trackNm);
                    sharedOnlyTrackList.add(this.shareTracks[i]);
                }
            }

          sharedOnlyTrackNamesArr = (String[]) sharedOnlyTrackNames.toArray(new String[sharedOnlyTrackNames.size()]);
          this.sharedOnlyTracks =    (DbFtype[]) sharedOnlyTrackList.toArray(new DbFtype[sharedOnlyTrackList.size()]);

          // Add URL info
          DbFtype.fetchUrls(localcon, this.localTracks);
          DbFtype.fetchUrls(localcon, this.allLocalTracks);
        }
        catch(SQLException e)
        {
          mys.setAttribute("lastError", db.getLastError());
          GenboreeUtils.sendRedirect(request,response, "/java-bin/error.jsp");
          return;
        }
      }

      // All tracks together:
        ArrayList allTracksList = new ArrayList() ;
        for(int ii = 0; ii < this.allLocalTracks.length; ii++){
            if (this.allLocalTracks[ii] != null)
            allTracksList.add(this.allLocalTracks[ii]) ;
        }

        for(int ii = 0; ii < this.shareTracks.length; ii++){
        if (!(allLocalTrackNameList.contains(this.shareTracks[ii].toString()))){
        allTracksList.add(this.shareTracks[ii]) ;
        }
        }

      this.tracks = (DbFtype[]) allTracksList.toArray(new DbFtype[allTracksList.size()]) ;

     styleMap = TrackManager.findStyles(rseq, db, userId);


      // Arrays.sort(gclasses);
    if(is_preview) {
    tracks = (DbFtype[]) mys.getAttribute("previewTracks");
    }

    if(tracks != null)  {
      try {
        tracks =   Utility.alphabeticTrackSort(tracks);

      }
        catch (Exception e) {
          System.err.println(e.getMessage());
      }

    }



        // Get tracks and such, if needed
    if(mode == TrackMgrConstants.MODE_ORDER){
      this.orderTracks = TrackSortManager.getTrackOrders(localdbName,  dbNames, localcon, this.tracks,  allLocalTracks, sharedOnlyTracks, db, userId, out);
        // if (sharedOnlyTrackNamesArr != null && styleMap != null)
       // saveSharedTrackStyles(sharedOnlyTrackNamesArr,this.getDbName(), styleMap, out);
    }
    else if(mode == TrackMgrConstants.MODE_URL){
        urltracks = URLShareManager.updateTrackandURL(tracks, currSharedTracks, out);
        //  urltracks = tracks;
        if(urltracks != null)  {
         try {
          urltracks = Utility.alphabeticTrackSort(urltracks);
         }
            catch (Exception e ) {

              System.err.println(e.getMessage());

         }

        }
        else
        urltracks = tracks;
    }

      else if(mode == TrackMgrConstants.MODE_DELETE ||  mode == TrackMgrConstants.MODE_RENAME  || mode== TrackMgrConstants.MODE_DEFAULT){
        if(tracks == null || tracks.length == 0)
          return;

        tracks = TrackSortManager.topShareTracks(tracks, rseq.getDatabaseName(), dbNames, db, out);
        if(JSPErrorHandler.checkErrors(request,response,  db, mys))
          return;
      }

      if(trackNames != null && trackNames.length > 0) {
        trackLookup = new Hashtable();
        for(int i = 0; i < trackNames.length; i++)
            trackLookup.put(trackNames[i], "y");
      }

      // get all style data from dtyle table of db
      try {
        // get all style data from dtyle table of db
        styleList = rseq.fetchStyles(db);
        colorList = Style.fetchColors(db.getConnection(rseq.getDatabaseName()));
        if(JSPErrorHandler.checkErrors(request,response,  db, mys))
        return;
      }
      catch(SQLException e){
        db.reportError(e, "TrackManager.init()");
        mys.setAttribute("lastError", db.getLastError());
        GenboreeUtils.sendRedirect(request,response, "/java-bin/error.jsp");
        return;
      }

       // styleMap = TrackSortManager.topShareStyle(styleMap, rseq.getDatabaseName(), dbNames, out, db);
      if(JSPErrorHandler.checkErrors(request,response,  db, mys))
        return;
    } // END: public void init()

    public static HashMap inGclass(DBAgent db, String[] dbNames, DbFtype[] ftypes, DbGclass gclass, JspWriter out)
    {
      HashMap h = new HashMap();
      if(dbNames == null || ftypes == null || gclass == null || db == null)
        return h;
      String sql = null;
      String dbName = null;
      for(int i = 0; i < dbNames.length; i++)
      {
        Connection con = null;
        try
        {
          dbName = dbNames[i];
          con = db.getConnection(dbNames[i]);
          if(con == null || con.isClosed())
            return h;
          DbFtype ft = null;
          int gid = 0;
          for(int j = 0; j < ftypes.length; j++)
          {
            ft = ftypes[j];
            if(ft != null && h.get(ft.toString()) != null)
              continue;

            // find gid
            sql = "select distinct gid from gclass where gclass = ? ";
            PreparedStatement stms = con.prepareStatement(sql);
            stms.setString(1, gclass.getGclass()) ;
            ResultSet rs = stms.executeQuery();
            if(rs.next())
            {
              gid = rs.getInt(1);
            }
            rs.close();
            stms.close();

            String sql2 = "select f.fmethod, f.fsource from ftype f, ftype2gclass fg " +
                          " where fg.gid =  ? and fg.ftypeid = f.ftypeid ";

            PreparedStatement stms1 = con.prepareStatement(sql2);
            stms1.setInt(1, gid) ;
            ResultSet rs1 = stms1.executeQuery();
            while(rs1.next())
            {
              String fm = rs1.getString(1);
              String fs = rs1.getString(2);
              if((fm.compareTo(ft.getFmethod()) == 0) && (fs.compareTo(ft.getFsource()) == 0))
              {
                h.put(ft.toString(), ft);
                break;
              }
            }
            rs1.close();
            stms1.close();
          }
        }
        catch(Exception e)
        {
          System.err.println(e.getMessage() + ": sql error happened in ClassManager.inTrack()<br>" + " in db: " + dbName);
          e.printStackTrace();
          return h;
        }
      }
      return h;
    }

    public static boolean inTrack(DBAgent db, String[] dbNames, DbFtype ft, String gname, JspWriter out)
    {
      if(dbNames == null || ft == null)
        return false;
      boolean b = false;
      ArrayList list = new ArrayList();
      String sql = "select distinct ftypeid from ftype where fmethod = ? and fsource = ? ";

      for(int i = 0; i < dbNames.length; i++)
      {
        try
        {
          Connection con = db.getConnection(dbNames[i]);
          if(con == null || con.isClosed())
            return false;

          PreparedStatement stms = con.prepareStatement(sql);
          stms.setString(1, ft.getFmethod()) ;
          stms.setString(2, ft.getFsource()) ;
          int id = 0;
          ResultSet rs = stms.executeQuery();
          if(rs.next())
          {
            id = rs.getInt(1);
          }
          rs.close();
          stms.close();

          if(id <= 0)
            continue;

          String sql2 = "select g.gclass from gclass g, ftype2gclass fg where fg.ftypeid = ? and fg.gid = g.gid ";

          PreparedStatement stms1 = con.prepareStatement(sql2);
          stms1.setInt(1, id) ;
          ResultSet rs1 = stms1.executeQuery();
          while(rs1.next())
          {
            if(rs1.getString(1).compareTo(gname) == 0)
            {
              b = true;
              break;
            }
          }
          rs1.close();
          stms1.close();
          // con.close();
          if(b)
            break;
        }
        catch(SQLException e)
        {
          System.err.println(" sql error happened in ClassManager.findClassGids()");
          e.printStackTrace();
        }
      }
      return b;
    }


    public static boolean setStyle(String dbName,  DBAgent db, Style style, int _userId) throws SQLException {

        int i;
        try {

                Connection conn = null;
                Statement stmt = null;
                PreparedStatement psColorIns = null;
                PreparedStatement psStyleIns = null;
                PreparedStatement psFeatureColorDel = null;
                PreparedStatement psFeatureStyleDel = null;
                PreparedStatement psFeatureColorIns = null;
                PreparedStatement psFeatureStyleIns = null;




                System.gc();

                        conn = db.getConnection(dbName);
                        stmt = conn.createStatement();
                        int colorId = 136;
                        int styleId =-1;
                        ResultSet rs = stmt.executeQuery("SELECT styleId FROM style where name='" + style.name + "'");

                        while (rs.next()) {
                          styleId = rs.getInt(1);

                        }

                        rs = stmt.executeQuery("SELECT colorId FROM color where value = '" + style.color + "'");
                        while (rs.next()) {
                           colorId = rs.getInt(1);

                        }

                        psFeatureColorDel = conn.prepareStatement("DELETE FROM featuretocolor WHERE userId=? AND ftypeid=?");
                        psFeatureStyleDel = conn.prepareStatement("DELETE FROM featuretostyle WHERE userId=? AND ftypeid=?");
                        psFeatureColorIns = conn.prepareStatement("INSERT INTO featuretocolor (userId, ftypeid, colorId) VALUES (?, ?, ?)");
                        psFeatureStyleIns = conn.prepareStatement("INSERT INTO featuretostyle (userId, ftypeid, styleId) VALUES (?, ?, ?)");



                    if (styleId <1) {
                        if (psStyleIns == null)
                            psStyleIns = conn.prepareStatement("INSERT INTO style (name, description) VALUES (?, ?)");
                        psStyleIns.setString(1, style.name);
                        psStyleIns.setString(2, style.description);
                        if (psStyleIns.executeUpdate() > 0) {
                            ResultSet rs1 = stmt.executeQuery("SELECT LAST_INSERT_ID()");
                            if (rs1.next()) {
                                 styleId = rs.getInt(1);
                                style.styleId = "" + styleId;

                            }
                        }
                    }


                    psFeatureStyleDel.setInt(1, _userId);
                    psFeatureStyleDel.setInt(2, style.ftypeid);
                    psFeatureStyleDel.executeUpdate();
                    if (styleId >0) {
                        psFeatureStyleIns.setInt(1, _userId);
                        psFeatureStyleIns.setInt(2, style.ftypeid);
                        psFeatureStyleIns.setInt(3, styleId);
                        psFeatureStyleIns.executeUpdate();
                    }

                    if (style.color != null)
                        style.color = style.color.toUpperCase();

                    if (colorId <1) {
                        if (psColorIns == null)
                            psColorIns = conn.prepareStatement("INSERT INTO color (value) VALUES (?)");
                        psColorIns.setString(1, style.color);
                        if (psColorIns.executeUpdate() > 0) {
                            ResultSet rs2 = stmt.executeQuery("SELECT LAST_INSERT_ID()");
                            if (rs.next()) {
                                style.colorid = rs.getInt(1);
                                colorId =  style.colorid;

                            }
                        }
                    }

                    psFeatureColorDel.setInt(1, _userId);
                    psFeatureColorDel.setInt(2, style.ftypeid);
                    psFeatureColorDel.executeUpdate();
                    if (colorId >0) {
                        psFeatureColorIns.setInt(1, _userId);
                        psFeatureColorIns.setInt(2, style.ftypeid);
                        psFeatureColorIns.setInt(3, colorId);
                        psFeatureColorIns.executeUpdate();
                    }
               return true;

        } catch (Exception ex) {
            db.reportError(ex, "Refseq.setStyleMap()");
        }
        return false;
    }



public  boolean saveSharedTrackStyles(String[] sharedOnlyTracks, String localDBName, Style[] styles, JspWriter out) {
    try {
        DBAgent db = DBAgent.getInstance();
        HashMap styleMap = new HashMap();
        for (int i = 0; i < styles.length; i++) {
            styleMap.put(styles[i].featureType, styles[i]);
        }

        for (int i = 0; i < sharedOnlyTracks.length; i++) {
            String trackName = sharedOnlyTracks[i];
            Style st = (Style) styleMap.get(trackName);
            st.ftypeid = TrackManager.findFtypeId(st, db, getDbName());
            st.databaseName = getDbName();
            if (st != null) {
                TrackManager.updateFtype(st, db, localDBName);
                st.ftypeid = TrackManager.findFtypeId(st, db, localDBName);
                st.databaseName = localDBName;
                setStyle( localDBName, db, st, userId);
            }
        }
    } catch (Exception e) {
    e.printStackTrace();
    }
    return true;
}

    // Getter/Setter Spam starts here.
    public DbFtype[] getShareTracks() {
        return shareTracks;
    }

    public void setShareTracks(DbFtype[] shareTracks) {
        this.shareTracks = shareTracks;
    }

    public DbFtype[] getLocalTracks() {
      return this.localTracks ;
    }

    public void setLocalTracks(DbFtype[] localTracks) {
      this.localTracks = localTracks ;
    }

    public void setMyGrpAccess(String myGrpAccess) {
        this.myGrpAccess = myGrpAccess;
    }

    public void setVerr(Vector verr) {
        this.verr = verr;
    }



    public void setvBtn(Vector vBtn) {
        this.vBtn = vBtn;
    }

    public void setBtnBack(String[] btnBack) {
        this.btnBack = btnBack;
    }

    public void setHtTrkErr(Hashtable htTrkErr) {
        this.htTrkErr = htTrkErr;
    }

    public void setOld_db(boolean old_db) {
        this.old_db = old_db;
    }

    public void setFetchUserId(int fetchUserId) {
        this.fetchUserId = fetchUserId;
    }

    public void setIs_preview(boolean is_preview) {
        this.is_preview = is_preview;
    }

    public void setNo_acs(boolean no_acs) {
        this.no_acs = no_acs;
    }

    public void setOldRefseqId(String oldRefseqId) {
        this.oldRefseqId = oldRefseqId;
    }

    public void setUrltracks(DbFtype[] urltracks) {
        this.urltracks = urltracks;
    }

    public void setGclasses(DbGclass[] gclasses) {
        this.gclasses = gclasses;
    }

    public void setHtGroupLookup(Hashtable htGroupLookup) {
        this.htGroupLookup = htGroupLookup;
    }

    public void setClsTrack(DbFtype clsTrack) {
        this.clsTrack = clsTrack;
    }

    public void setEditTrack(DbFtype editTrack) {
        this.editTrack = editTrack;
    }

    public void setEditTrackId(String editTrackId) {
        this.editTrackId = editTrackId;
    }

    public void setTrackNames(String[] trackNames) {
        this.trackNames = trackNames;
    }

    public void setTrackLookup(Hashtable trackLookup) {
        this.trackLookup = trackLookup;
    }

    public void setCmd(int cmd) {
        this.cmd = cmd;
    }

    public void setStyleList(Style[] styleList) {
        this.styleList = styleList;
    }

    public void setColorList(Style[] colorList) {
        this.colorList = colorList;
    }

    public void setStyleMap(Style[] styleMap) {
        this.styleMap = styleMap;
    }

    public void setiEditTrackId(int iEditTrackId) {
        this.iEditTrackId = iEditTrackId;
    }

    public String getRefSeqId() {
        return refSeqId;
    }

    public String getLocaldbName() {
        return localdbName;
    }

    public String[] getSubdbNames() {
        return subdbNames;
    }

    public int getMode() {
        return mode;
    }

    public boolean isIs_admin() {
        return is_admin;
    }

    public String getMyGrpAccess() {
        return myGrpAccess;
    }

    public Vector getVerr() {
        return verr;
    }


    public Vector getvBtn() {
        return vBtn;
    }

    public String[] getBtnBack() {
        return btnBack;
    }

    public Hashtable getHtTrkErr() {
        return htTrkErr;
    }

    public boolean isOld_db() {
        return old_db;
    }

    public int getFetchUserId() {
        return fetchUserId;
    }

    public boolean isIs_preview() {
        return is_preview;
    }

    public boolean isNo_acs() {
        return no_acs;
    }

    public String getOldRefseqId() {
        return oldRefseqId;
    }

    public DbFtype[] getUrltracks() {
        return urltracks;
    }

    public DbGclass[] getGclasses() {
        return gclasses;
    }

    public Hashtable getHtGroupLookup() {
        return htGroupLookup;
    }

    public DbFtype getClsTrack() {
        return clsTrack;
    }

    public DbFtype getEditTrack() {
        return editTrack;
    }

    public String getEditTrackId() {
        return editTrackId;
    }

    public String[] getTrackNames() {
        return trackNames;
    }

    public Hashtable getTrackLookup() {
        return trackLookup;
    }

    public int getCmd() {
        return cmd;
    }

    public Style[] getStyleList() {
        return styleList;
    }

    public Style[] getColorList() {
        return colorList;
    }

    public Style[] getStyleMap() {
        return styleMap;
    }


    public int getiEditTrackId() {
        return iEditTrackId;
    }

    public void setRseq(Refseq rseq) {
        this.rseq = rseq;
    }

    public void setDbName(String dbName) {
        this.localdbName = dbName;
    }

    public void setDbNames(String[] dbNames) {
        this.dbNames = dbNames;
    }

    public void setDestback(String destback) {
        this.destback = destback;
    }

    public void setAuto_goback(boolean auto_goback) {
        this.auto_goback = auto_goback;
    }

    public void setHasSubordinateDB(boolean hasSubordinateDB) {
        this.hasSubordinateDB = hasSubordinateDB;
    }

    public void setSubordinateDBNames(String[] subordinateDBNames) {
        this.subdbNames = subordinateDBNames;
    }

    public void setUserId(int userId) {
        this.userId = userId;
    }

    public Refseq getRseq() {
        return rseq;
    }

    public String getDbName() {
        return localdbName;
    }

    public String[] getDbNames() {
        return dbNames;
    }

    public String getDestback() {
        return destback;
    }

    public boolean isAuto_goback() {
        return auto_goback;
    }

    public boolean isHasSubordinateDB() {
        return hasSubordinateDB;
    }

    public String[] getSubordinateDBNames() {
        return subdbNames;
    }

    public int getUserId() {
        return userId;
    }

    public DbFtype[] getTracks() {
        return tracks;
    }

    public void setTracks(DbFtype[] tracks) {
        this.tracks = tracks;
    }

    public DbGclass getEditingClass() {
        return editingClass;
    }

    public void setEditingClass(DbGclass editingClass) {
        this.editingClass = editingClass;
    }

    public void setHftypeidtogid(Hashtable hftypeidtogid) {
        this.hftypeidtogid = hftypeidtogid;
    }

    public Hashtable getHftypeidtogid() {
        return hftypeidtogid;
    }

    public void setFrom_default(boolean from_default) {
        this.from_default = from_default;
    }

    public void setRefSeqId(String refSeqId) {
        this.refSeqId = refSeqId;
    }

    public String getOldClassName() {
        return oldClassName;
    }

    public void setOldClassName(String oldClassName) {
        this.oldClassName = oldClassName;
    }

    public void setLocaldbName(String localdbName) {
        this.localdbName = localdbName;
    }

    public int getClassmode() {
        return classmode;
    }


    public void setSubdbNames(String[] subdbNames) {
        this.subdbNames = subdbNames;
    }

    public void setMode(int mode) {
        this.mode = mode;
    }

    public void setIs_admin(boolean is_admin) {
        this.is_admin = is_admin;
    }

    public HashMap getHtTrackSel() {
        return htTrackSel;
    }

    public void setHtTrackSel(HashMap htTrackSel) {
        this.htTrackSel = htTrackSel;
    }

    public String[] getClsTrackNames() {
        return clsTrackNames;
    }

    public void setClsTrackNames(String[] clsTrackNames) {
        this.clsTrackNames = clsTrackNames;
    }

    public DbFtype[] getSelTracks() {
        return selTracks;
    }

    public void setSelTracks(DbFtype[] selTracks) {
        this.selTracks = selTracks;
    }

    public Refseq[] getRseqs() {
        return rseqs;
    }

    public void setRseqs(Refseq[] rseqs) {
        this.rseqs = rseqs;
    }

    public String getEditClassName() {
        return editClassName;
    }

    public void setEditClassName(String editClassName) {
        this.editClassName = editClassName;
    }


    public DbFtype[] getAllLocalTracks() {
        return allLocalTracks;
    }

    public void setAllLocalTracks(DbFtype[] allLocalTracks) {
        this.allLocalTracks = allLocalTracks;
    }




    public ArrayList getAllLocalTrackNameList() {
        return allLocalTrackNameList;
    }

    public void setAllLocalTrackNameList(ArrayList allLocalTrackNameList) {
        this.allLocalTrackNameList = allLocalTrackNameList;
    }

    public DbFtype[] getSharedOnlyTracks() {
          return sharedOnlyTracks;
      }

      public void setSharedOnlyTracks(DbFtype[] sharedOnlyTracks) {
          this.sharedOnlyTracks = sharedOnlyTracks;
      }
    public DbFtype[] getOrderTracks() {
           return orderTracks;
       }

       public void setOrderTracks(DbFtype[] orderTracks) {
           this.orderTracks = orderTracks;
       }


}
