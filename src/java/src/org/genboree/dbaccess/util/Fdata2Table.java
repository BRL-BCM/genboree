package org.genboree.dbaccess.util ;

import java.sql.* ;
import java.util.* ;
import org.genboree.dbaccess.* ;

public class Fdata2Table
{
  // Count all annotations.
  public static long count(Connection conn)
  {
    long count = 0 ;
    ResultSet rs = null ;
    PreparedStatement stmt = null ;
    if(conn != null)
    {
      try
      {
        String sql = "select count(*) from fdata2 " ;
        stmt = conn.prepareStatement(sql) ;
        rs = stmt.executeQuery() ;
        while(rs.next())
        {
          count = rs.getLong(1) ;
        }
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: Fdata2Table#count() => exception counting fdata2 records" ) ;
        ex.printStackTrace(System.err) ;
      }
      finally
      {
        DBAgent.safelyCleanup(rs, stmt) ;
      }
    }
    return count ;
  }

  // Count all annotations in given tracks.
  public static long countAnnosInTracks(String[] ftypeIds, Connection conn)
  {
    long count = 0 ;
    ResultSet rs = null ;
    PreparedStatement stmt = null ;
    if(conn != null)
    {
      try
      {
        StringBuffer tracksBuff = new StringBuffer() ;
        if(ftypeIds != null)
        {
          for(int ii = 0; ii < ftypeIds.length; ii++)
          {
            tracksBuff.append(ftypeIds[ii]) ;
            if(ii < (ftypeIds.length -1) ) // then not the last one, add a ','
            {
              tracksBuff.append(",") ;
            }
          }
        }
        if(tracksBuff != null && tracksBuff.length() > 0)
        {
          String sql = "select count(*) from fdata2 where ftypeid in ( " + tracksBuff.toString() + " )" ;
          stmt = conn.prepareStatement(sql) ;
          rs = stmt.executeQuery() ;
          if(rs.next())
          {
            count = rs.getLong(1) ;
          }
        }
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: Fdata2Table#countAnnosInTracks() => exception counting annos in tracks. ") ;
        ex.printStackTrace(System.err) ;
      }
      finally
      {
        DBAgent.safelyCleanup(rs, stmt) ;
      }
    }
    return count ;
  }
}
