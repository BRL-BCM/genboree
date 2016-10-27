package org.genboree.util;

import javax.servlet.http.HttpSession;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

import java.sql.SQLException;
import org.genboree.dbaccess.* ;
import org.genboree.dbaccess.util.* ;

/**
 * User: tong Date: Jul 14, 2006 Time: 3:23:58 PM
 */
public class SessionManager
{
  public static final int NO_ERROR = 0 ;
  public static final int INSYNC_ID_N_NAME = 100 ;
  public static final int NULL_PARAMS = 200 ;
  public static final int NULL_GROUP_ID = 210 ;
  public static final int NULL_GROUP_NAME = 220 ;
  public static final int NULL_SESSION = 230 ;
  public static final int NULL_DB_ID = 310 ;
  public static final int NULL_DB_NAME = 320 ;
  public static final int NULL_PROJ_VAL = 510 ;
  public static final int NULL_USER_ID = 610 ;
  public static final int NULL_USER_NAME = 620 ;
  public static final int EMPTY_GROUP = 400 ;

  public static int setSessionGroup(HttpSession mys, String groupId, String groupName)
  {
    if(groupId == null)
    {
      return NULL_GROUP_ID;
    }

    if(groupName == null)
    {
      return NULL_GROUP_NAME;
    }

    if(mys == null)
    {
      return NULL_SESSION;
    }

    String dbgrpName = null;
    try
    {
      Connection con =  DBAgent.getInstance().getConnection() ;
      String sql = "select groupName from genboreegroup where groupId = ? " ;
      PreparedStatement stms = con.prepareStatement(sql) ;
      stms.setString(1, groupId) ;
      ResultSet rs = stms.executeQuery() ;
      if(rs.next())
      {
        dbgrpName = rs.getString(1);
      }

      rs.close() ;
      stms.close() ;
    }
    catch(Exception e)
    {
      e.printStackTrace() ;
    }


    if(dbgrpName == null || dbgrpName.compareTo(groupName) != 0)
    {
      return INSYNC_ID_N_NAME;
    }

    mys.removeAttribute(Constants.SESSION_GROUP_NAME) ;
    mys.setAttribute(Constants.SESSION_GROUP_NAME, groupName) ;
    mys.removeAttribute(Constants.SESSION_GROUP_ID) ;
    mys.setAttribute(Constants.SESSION_GROUP_ID, groupId) ;

    return NO_ERROR ;
  }

  public static int setSessionGroupId(HttpSession mys, String groupId)
  {
    if(groupId == null)
    {
      return NULL_GROUP_ID ;
    }

    if(mys == null)
    {
      return NULL_SESSION;
    }

    String dbgrpName = null ;
    try
    {
      Connection con =  DBAgent.getInstance().getConnection() ;
      String sql = "select groupName from genboreegroup where groupId = ? " ;
      PreparedStatement stms = con.prepareStatement(sql) ;
      stms.setString(1, groupId) ;
      ResultSet rs = stms.executeQuery() ;

      if(rs.next())
      {
        dbgrpName = rs.getString(1);
      }

      rs.close() ;
      stms.close() ;
    }
    catch (Exception e)
    {
      e.printStackTrace();
    }

    if(dbgrpName == null)
    {
      return INSYNC_ID_N_NAME;
    }

    mys.removeAttribute(Constants.SESSION_GROUP_NAME);
    mys.setAttribute(Constants.SESSION_GROUP_NAME, dbgrpName);
    mys.removeAttribute(Constants.SESSION_GROUP_ID);
    mys.setAttribute(Constants.SESSION_GROUP_ID, groupId);
    return NO_ERROR;
  }

  public static int setSessionGroupName(HttpSession mys, String groupName)
  {
    if(groupName == null)
    {
      return NULL_GROUP_NAME ;
    }

    if(mys == null)
    {
      return NULL_SESSION ;
    }

    String dbgrpId = null;
    try
    {
      Connection con =  DBAgent.getInstance().getConnection() ;
      String sql = "select groupId from genboreegroup where groupName = ? " ;
      PreparedStatement stms = con.prepareStatement(sql) ;
      stms.setString(1, groupName) ;
      ResultSet rs = stms.executeQuery() ;

      if(rs.next())
      {
        dbgrpId = rs.getString(1) ;
      }

      rs.close() ;
      stms.close() ;
    }
    catch(Exception e)
    {
      e.printStackTrace() ;
    }

    if(dbgrpId == null)
    {
      return INSYNC_ID_N_NAME ;
    }

    mys.removeAttribute(Constants.SESSION_GROUP_NAME) ;
    mys.setAttribute(Constants.SESSION_GROUP_NAME, groupName) ;
    mys.removeAttribute(Constants.SESSION_GROUP_ID) ;
    mys.setAttribute(Constants.SESSION_GROUP_ID, dbgrpId) ;

    return NO_ERROR ;
  }

  public static String getSessionGroupId(HttpSession mys)
  {
    String groupId = null;
    if(mys.getAttribute(Constants.SESSION_GROUP_ID) != null)
    {
      groupId = (String) mys.getAttribute(Constants.SESSION_GROUP_ID);
      groupId = groupId.trim();
    }
    return groupId ;
  }

  public static String getSessionGroupName(HttpSession mys)
  {
    String groupName = null ;
    if(mys.getAttribute(Constants.SESSION_GROUP_NAME) != null)
    {
      groupName = (String) mys.getAttribute(Constants.SESSION_GROUP_NAME) ;
    }
    return groupName ;
  }

  public static int setSessionDatabaseId(HttpSession mys, String refseqId) {
    if (refseqId == null) {
    return NULL_DB_ID;
    }

    if (mys == null) {
    return NULL_SESSION;
    }
    String groupId = SessionManager.getSessionGroupId(mys);
    if (groupId == null)
    {
    mys.removeAttribute(Constants.SESSION_DATABASE_NAME);
    mys.removeAttribute(Constants.SESSION_DATABASE_ID);
    return NULL_GROUP_ID;
    }

    String dbName = null;
    try {
    Connection con =  DBAgent.getInstance().getConnection();

    String sql = "select * from grouprefseq where groupId = ? and refSeqId = ?  ";
    PreparedStatement stms = con.prepareStatement(sql);
    stms.setString(1,groupId);
    stms.setString(2, refseqId);
    ResultSet rs = stms.executeQuery();

    if (!rs.next())
    {
    mys.removeAttribute(Constants.SESSION_DATABASE_NAME);
    mys.removeAttribute(Constants.SESSION_DATABASE_ID);
    rs.close();
    stms.close();
    return EMPTY_GROUP;
    }
    sql = "select databaseName from refseq where refseqId = ? ";
    stms = con.prepareStatement(sql);
    stms.setString(1, refseqId);
    rs = stms.executeQuery();

    if (rs.next())
    dbName = rs.getString(1);

    rs.close();
    stms.close();
    }
    catch (Exception e) {
    e.printStackTrace();
    }

    if (dbName == null) {
    return INSYNC_ID_N_NAME;
    }

    mys.removeAttribute(Constants.SESSION_DATABASE_NAME);
    mys.setAttribute(Constants.SESSION_DATABASE_NAME, dbName);
    mys.removeAttribute(Constants.SESSION_DATABASE_ID);
    mys.setAttribute(Constants.SESSION_DATABASE_ID, refseqId);
    return NO_ERROR;
  }

  public static int setSessionDatabaseIdHard(HttpSession mys, String refseqId, DBAgent db) {
    if (refseqId == null) {
    return NULL_DB_ID;
    }

    if (mys == null) {
    return NULL_SESSION;
    }
    String dbName = null;
    try {
    Connection con = db.getConnection();

    String sql = "select groupId from grouprefseq where  refSeqId = ?  ";
    PreparedStatement stms = con.prepareStatement(sql);

    stms.setString(1, refseqId);
    ResultSet rs = stms.executeQuery();
    if (!rs.next())
    {
    mys.removeAttribute(Constants.SESSION_DATABASE_NAME);
    mys.removeAttribute(Constants.SESSION_DATABASE_ID);
    rs.close();
    stms.close();
    return EMPTY_GROUP;
    }
    else
    {
    String  groupId =  rs.getString(1) ;
    String   grpName = null;
    sql = "select groupName from genboreegroup where groupId = ? ";
    stms = con.prepareStatement(sql);
    stms.setString(1, groupId);
    rs = stms.executeQuery();

    if (rs.next())
    grpName = rs.getString(1);

    if (grpName != null) {
    mys.removeAttribute(Constants.SESSION_GROUP_NAME);
    mys.setAttribute(Constants.SESSION_GROUP_NAME, grpName);
    mys.removeAttribute(Constants.SESSION_GROUP_ID);
    mys.setAttribute(Constants.SESSION_GROUP_ID, groupId);}
    else
    return INSYNC_ID_N_NAME;
    }

    String   sql2 = "select databaseName from refseq where refseqId = ? ";
    PreparedStatement   stms2 = con.prepareStatement(sql2);
    stms2.setString(1, refseqId);
    ResultSet rs2 = stms.executeQuery();

    if (rs2.next())
    dbName = rs2.getString(1);

    rs2.close();
    stms2.close();
    }
    catch (Exception e) {
    e.printStackTrace();
    }

    if (dbName == null) {
    return INSYNC_ID_N_NAME;
    }

    mys.removeAttribute(Constants.SESSION_DATABASE_NAME);
    mys.setAttribute(Constants.SESSION_DATABASE_NAME, dbName);
    mys.removeAttribute(Constants.SESSION_DATABASE_ID);
    mys.setAttribute(Constants.SESSION_DATABASE_ID, refseqId);
    return NO_ERROR;
  }

  /**
   * This function is designed for the case of a pasted refseqID is passed to grbowser
   * it set session database id and group id via a single refseqId
   * The idea is to retrieve group id via refseqId, which is right as long as a unique mapping is found
   * for refseqId: group Id
   * In case in the future the refseq maps to multiple group Id, it pick the fist one
   * so user can still change in GUI

    * @param mys
   * @param refseqId
   * @return
   */
  public static int setSessionDatabaseIdHard(HttpSession mys, String refseqId) {
    if (refseqId == null) {
    return NULL_DB_ID;
    }

    if (mys == null) {
    return NULL_SESSION;
    }
    String dbName = null;
    try {
    Connection con =  DBAgent.getInstance().getConnection();

    String sql = "select groupId from grouprefseq where  refSeqId = ?  ";
    PreparedStatement stms = con.prepareStatement(sql);

    stms.setString(1, refseqId);
    ResultSet rs = stms.executeQuery();
    if (!rs.next())
    {
    mys.removeAttribute(Constants.SESSION_DATABASE_NAME);
    mys.removeAttribute(Constants.SESSION_DATABASE_ID);
    rs.close();
    stms.close();
    return EMPTY_GROUP;
    }
    else
    {
    String  groupId =  rs.getString(1) ;
    String   grpName = null;
    sql = "select groupName from genboreegroup where groupId = ? ";
    stms = con.prepareStatement(sql);
    stms.setString(1, groupId);
    rs = stms.executeQuery();

    if (rs.next())
    grpName = rs.getString(1);

    if (grpName != null) {
    mys.removeAttribute(Constants.SESSION_GROUP_NAME);
    mys.setAttribute(Constants.SESSION_GROUP_NAME, grpName);
    mys.removeAttribute(Constants.SESSION_GROUP_ID);
    mys.setAttribute(Constants.SESSION_GROUP_ID, groupId);}
    else
    return INSYNC_ID_N_NAME;
    }

    String   sql2 = "select databaseName from refseq where refseqId = ? ";
    PreparedStatement   stms2 = con.prepareStatement(sql2);
    stms2.setString(1, refseqId);
    ResultSet rs2 = stms.executeQuery();

    if (rs2.next())
    dbName = rs2.getString(1);

    rs2.close();
    stms2.close();
    }
    catch (Exception e) {
    e.printStackTrace();
    }

    if (dbName == null) {
    return INSYNC_ID_N_NAME;
    }

    mys.removeAttribute(Constants.SESSION_DATABASE_NAME);
    mys.setAttribute(Constants.SESSION_DATABASE_NAME, dbName);
    mys.removeAttribute(Constants.SESSION_DATABASE_ID);
    mys.setAttribute(Constants.SESSION_DATABASE_ID, refseqId);
    return NO_ERROR;
  }

  public static void clearSessionDatabase(HttpSession mys) {
      mys.removeAttribute(Constants.SESSION_DATABASE_NAME);
      mys.removeAttribute(Constants.SESSION_DATABASE_ID);
  }

  public static void clearSessionGroup(HttpSession mys)
  {
    mys.removeAttribute(Constants.SESSION_GROUP_NAME) ;
    mys.removeAttribute(Constants.SESSION_GROUP_ID) ;
    mys.removeAttribute(Constants.SESSION_DATABASE_NAME) ;
    mys.removeAttribute(Constants.SESSION_DATABASE_ID) ;
    mys.removeAttribute(Constants.SESSION_PROJECT_ID) ;
    mys.removeAttribute(Constants.SESSION_PROJECT_NAME) ;
  }

  public static int setSessionDatabaseName(HttpSession mys, String databaseName) {
    Connection con = null;
    String refseqid = null;
    int returnId = NO_ERROR;

    if (mys == null)
            return NULL_SESSION;
    if (databaseName != null ) {
        DBAgent db = new DBAgent ();

         try {
            con = db.getConnection();
            String sql = "select refSeqId  from refseq where databaseName = ? ";
            PreparedStatement stms = con.prepareStatement(sql);
            stms.setString(1,databaseName);
            ResultSet rs = stms.executeQuery();

            if (rs.next())
                refseqid = rs.getString(1);

       if (refseqid != null)  {
             String groupId = SessionManager.getSessionGroupId(mys);
             if (groupId != null) {
               sql = "select * from grouprefseq where groupId = ? and refSeqId = ?  ";
               stms = con.prepareStatement(sql);
                stms.setString(1, groupId);
                stms.setString(2, refseqid);
                rs = stms.executeQuery();
               if (!rs.next())  {
                      databaseName = null;
                      refseqid = null;
                         returnId =  EMPTY_GROUP;
                 }
             }
            if (groupId == null) {
               databaseName = null;
                      refseqid = null;
                         returnId =  EMPTY_GROUP;
         }


     }
     else
             returnId =  INSYNC_ID_N_NAME;

         if (rs != null)
         rs.close();
         stms.close();
        }
        catch (Exception e) {
            e.printStackTrace();
        }
   }
     else
        refseqid = null;


        mys.setAttribute(Constants.SESSION_DATABASE_NAME, databaseName);
        mys.setAttribute(Constants.SESSION_DATABASE_ID, refseqid);
        return returnId;
   }

  public static int setSessionDatabaseName(HttpSession mys, String databaseName, DBAgent db ) {
    Connection con = null;
    String refseqid = null;
    int returnId = NO_ERROR;

       if (mys == null)
           return NULL_SESSION;
   if (databaseName != null ) {
        try {
           con = db.getConnection();
           String sql = "select refSeqId  from refseq where databaseName = ? ";
           PreparedStatement stms = con.prepareStatement(sql);
           stms.setString(1,databaseName);
           ResultSet rs = stms.executeQuery();

           if (rs.next())
               refseqid = rs.getString(1);

      if (refseqid != null)  {
            String groupId = SessionManager.getSessionGroupId(mys);
            if (groupId != null) {
              sql = "select * from grouprefseq where groupId = ? and refSeqId = ?  ";
              stms = con.prepareStatement(sql);
               stms.setString(1, groupId);
               stms.setString(2, refseqid);
               rs = stms.executeQuery();
              if (!rs.next())  {
                     databaseName = null;
                     refseqid = null;
                        returnId =  EMPTY_GROUP;
                }
            }
           if (groupId == null) {
              databaseName = null;
                     refseqid = null;
                        returnId =  EMPTY_GROUP;
        }


    }
    else
            returnId =  INSYNC_ID_N_NAME;

        if (rs != null)
        rs.close();
        stms.close();
       }
       catch (Exception e) {
           e.printStackTrace();
       }
    }
    else
       refseqid = null;


       mys.setAttribute(Constants.SESSION_DATABASE_NAME, databaseName);
       mys.setAttribute(Constants.SESSION_DATABASE_ID, refseqid);
       return returnId;
  }

    /**
     * a convenient method for getting session display name
     * @param mys
     * @return
     */
    public static String getSessionDatabaseDisplayName(HttpSession mys) {
        if (mys == null) {
            return null;
        }

        String refseqName = null;
        String refseqId = SessionManager.getSessionDatabaseId(mys);
        if (refseqId == null)
            return null;

        try {
            Connection con =  DBAgent.getInstance().getConnection();
            String sql = "select refseqName  from refseq where refSeqId  = ? ";
            PreparedStatement stms = con.prepareStatement(sql);
            stms.setString(1, refseqId);
            ResultSet rs = stms.executeQuery();

            if (rs.next())
                refseqName = rs.getString(1);

            rs.close();
            stms.close();
        } catch (Exception e) {
            e.printStackTrace();
        }

        return refseqName;
    }

    public static String getSessionDatabaseId(HttpSession mys)
    {
      String databaseId = null ;
      databaseId = (String) mys.getAttribute(Constants.SESSION_DATABASE_ID) ;
      if(databaseId == null) // Then not using proper ID string for database_ID in session
      {
        System.err.println("*** ERROR *** => current refSeqId not stored in session using Constants.SESSION_DATABASE_ID but bad, uninformative name. Will now search some possible/known old bad names for this key.") ;
        databaseId = (String) mys.getAttribute("uploadRefseqId") ;
        if(databaseId != null)
        {
          System.err.println("              -> found via 'uploadRefseqId' (" + databaseId + ")") ;
        }
      }
      return databaseId ;
    }

    public static String getSessionDatabaseName(HttpSession mys) {
        String databaseName = null;
        if (mys.getAttribute(Constants.SESSION_DATABASE_NAME) != null)
           databaseName = (String) mys.getAttribute(Constants.SESSION_DATABASE_NAME);
        return databaseName;
    }

    public static String findRefSeqName(String id, DBAgent db) {
        String refseqName = null;
        try {
            Connection con = db.getConnection();
            String sql = "select refseqName from refseq where refSeqId = ?";
            PreparedStatement stms = con.prepareStatement(sql);
            stms.setString(1, id);
            ResultSet rs = stms.executeQuery();

            if (rs.next())
                refseqName = rs.getString(1);


            rs.close();
            stms.close();
        } catch (SQLException e) {
            e.printStackTrace();
        }

        return refseqName;
    }


    public static boolean matchRefseqGroupId(String gid, String rid, DBAgent db) {
        boolean b = false;
        try {
            Connection con = db.getConnection();
            String sql = "select * from grouprefseq where groupId = ? and refSeqId = ?  ";
            PreparedStatement stms = con.prepareStatement(sql);
            stms.setString(1, gid);
            stms.setString(2, rid);
            ResultSet rs = stms.executeQuery();
            if (rs.next())
                b = true;
            rs.close();
            stms.close();

        } catch (Exception e) {
            e.printStackTrace();
        }
        return b;
    }

  public static String getSessionProjectId(HttpSession mys)
  {
    String groupId = null ;
    if(mys.getAttribute(Constants.SESSION_PROJECT_ID) != null)
    {
      groupId = (String)mys.getAttribute(Constants.SESSION_PROJECT_ID) ;
    }
    return groupId ;
  }

  public static String getSessionProjectName(HttpSession mys)
  {
    String groupName = null ;
    if(mys.getAttribute(Constants.SESSION_PROJECT_NAME) != null)
    {
      groupName = (String) mys.getAttribute(Constants.SESSION_PROJECT_NAME) ;
    }
    return groupName ;
  }

  public static int setSessionProjectInfo(HttpSession mys, String projectVal, boolean byId)
  {
    int projectId = -1 ;
    String projectName = null ;
    if(projectVal == null)
    {
      return NULL_PROJ_VAL ;
    }

    if(mys == null)
    {
      return NULL_SESSION;
    }

    String dbgrpName = null ;
    try
    {
      Connection conn =  DBAgent.getInstance().getConnection() ;
      DbResourceSet projDbResSet = null ;
      if(byId)
      {
        int projectValAsInt = Integer.parseInt(projectVal) ;
        projDbResSet = ProjectsTable.getProjectById(projectValAsInt, conn) ;
      }
      else // by name
      {
        projectId = ProjectsTable.getProjectIdByName(projectVal, conn) ;
        projDbResSet = ProjectsTable.getProjectById(projectId, conn) ;
      }

      if(projDbResSet.resultSet.next())
      {
        projectName = projDbResSet.resultSet.getString("name") ;
      }
      projDbResSet.close() ;
    }
    catch (Exception ex)
    {
      System.err.println("ERROR: SessionManager.setSessionProjectInfo(H,S,b) => exception trying to set project info for session. Int parsing ok?") ;
      ex.printStackTrace(System.err) ;
    }

    if(projectName == null)
    {
      return INSYNC_ID_N_NAME ;
    }

    mys.removeAttribute(Constants.SESSION_PROJECT_NAME) ;
    mys.setAttribute(Constants.SESSION_PROJECT_NAME, projectName) ;
    mys.removeAttribute(Constants.SESSION_PROJECT_ID) ;
    mys.setAttribute(Constants.SESSION_PROJECT_ID, projectName) ;
    return NO_ERROR ;
  }
 }
