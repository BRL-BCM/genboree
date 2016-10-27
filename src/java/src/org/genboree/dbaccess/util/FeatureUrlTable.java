package org.genboree.dbaccess.util ;

import java.sql.* ;
import java.util.* ;
import org.genboree.dbaccess.* ;

public class FeatureUrlTable
{
  // Get track url, urlLabel, description (as array) for track by type, subtype
  public static String[] getTrackUrlArrayByTypeAndSubtype(String type, String subtype, Connection conn)
  {
    String[] retVal = null ;
    String sql =  "SELECT featureurl.url, featureurl.description, featureurl.label " +
                  "FROM ftype, featureurl WHERE featureurl.ftypeid = ftype.ftypeid " +
                  "AND ftype.fmethod = ? AND ftype.fsource = ?" ;
    ResultSet resultSet = null ;
    PreparedStatement pstmt = null ;

    if(type != null && subtype != null)
    {
      try
      {
        pstmt = conn.prepareStatement(sql);
        pstmt.setString(1, type ) ;
        pstmt.setString(2, subtype) ;
        resultSet = pstmt.executeQuery() ;
        String url, description, label ;
        if(resultSet.next())
        {
          url = resultSet.getString(1) ;
          description = resultSet.getString(2) ;
          label = resultSet.getString(3) ;
        }
        else
        {
          url = description = label = null ;
        }
        // Set the url info array triple
        if(url != null || description != null || label != null)
        {
          retVal= new String[3] ;
          retVal[0] = url ;
          retVal[1] = description ;
          retVal[2] = label ;
        }
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: FtypeTable#getTrackUrlArrayByTypeAndSubtype(S,S,C) => exception getting track record via type (" + type + ") and subtype (" + subtype + ") ; sql = " + sql) ;
        ex.printStackTrace(System.err) ;
      }
      finally
      {
        DBAgent.safelyCleanup(resultSet, pstmt) ;
      }
    }
    return retVal ;
  }
}
