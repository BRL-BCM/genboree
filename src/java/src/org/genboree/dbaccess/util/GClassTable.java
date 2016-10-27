package org.genboree.dbaccess.util ;

import java.sql.* ;
import java.util.* ;
import org.genboree.dbaccess.* ;

public class GClassTable
{
  // Get this track's classes via a connection to a single user DB.
  public static ArrayList<String> getClassListByTrackName(String type, String subtype, Connection conn)
  {
    ArrayList<String> retVal = null ;
    PreparedStatement stmt = null ;
    ResultSet rs = null ;
    if(conn != null)
    {
      try
      {
        String sql =  "SELECT distinct gclass.gclass FROM gclass, ftype2gclass, ftype " +
                      "WHERE gclass.gid = ftype2gclass.gid " +
                      "AND ftype.ftypeid = ftype2gclass.ftypeid " +
                      "AND ftype.fmethod = ? AND ftype.fsource = ?" ;
        stmt = conn.prepareStatement(sql) ;
        stmt.setString(1, type) ;
        stmt.setString(2, subtype) ;
        rs = stmt.executeQuery() ;
        retVal = new ArrayList<String>() ;
        while(rs.next())
        {
          retVal.add(rs.getString("gclass")) ;
        }
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: GClassTable#getClassListByTrackName(C, S, S) => exception getting class list by track name") ;
        ex.printStackTrace(System.err) ;
      }
      finally
      {
        DBAgent.safelyCleanup(rs, stmt) ;
      }
    }
    return retVal ;
  }

  // Get this track's unique classes from several databases
  public static ArrayList<String> getClassListByTrackName(String type, String subtype, String[] databaseNames, DBAgent db)
  {
    ArrayList<String> retVal = null ;
    HashMap<String, Boolean> uniqueClassHash = new HashMap<String, Boolean>() ;
    Connection currDbConn = null ;

    if(db != null && databaseNames != null && databaseNames.length > 0)
    {
      try
      {
        retVal = new ArrayList<String>() ;
        // Look in each database:
        for(String currDbName : databaseNames)
        {
          System.err.println("LOOK IN " + currDbName + " for track " + type + ":" + subtype) ;
          // Get a connection to it
          currDbConn = db.getConnection(currDbName) ;
          // Get class list for track from current db
          ArrayList<String> classList = GClassTable.getClassListByTrackName(type, subtype, currDbConn) ;
          System.err.println("        FOUND " + classList.size() + "classes:") ;
          for(String currClass : classList)
          {
            System.err.println("        - " + currClass) ;
            uniqueClassHash.put(currClass, true) ;
          }
        }
        retVal.addAll(uniqueClassHash.keySet()) ;
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: GClassTable#getClassListByTrackName(D[]) => exception getting connection to a user database") ;
        ex.printStackTrace(System.err) ;
        retVal = null ;
      }
    }
    return retVal ;
  }
}
