package org.genboree.dbaccess;

import java.io.* ;
import java.sql.*;
import java.util.*;

public class DbFmeta
{
  public static final String SEQ_DIR = "RID_SEQUENCE_DIR" ;
  
	public DbFmeta() {}
	
	// Gets a HashMap of all fname => fvalue records in fmeta table.
	// * String => String
	// * returns null if execption was thrown
	public static HashMap fetchAll( Connection conn ) throws SQLException
	{
		HashMap retVal = null ;
		if( conn != null )
		{
		  try
  		{
  			String qs = "SELECT fname, fvalue FROM fmeta";
  			PreparedStatement pstmt = conn.prepareStatement( qs );
  			ResultSet rs = pstmt.executeQuery();
  			retVal = new HashMap() ;
  			while( rs.next() )
  			{
  			  retVal.put( rs.getString(1), rs.getString(2) ) ;
  			}
  			pstmt.close();
  		}
  		catch( Exception ex )
  		{
  			System.err.println("ERROR: DbFmeta.fetchAll() :" );
  			ex.printStackTrace( System.err ) ;
  			retVal = null ;
  		}
  	}
		return retVal ;
	}

  // Get a fvalue for a given fname
  // * String
  // * returns null if exception thrown
  // * returns empty string if fname not found or has empty fvalue
  public static String fetchValue( Connection conn, String fname ) throws SQLException
  {
		String retVal = null ;
		if( conn != null )
		{
		  try
  		{
  			String qs = "SELECT fvalue FROM fmeta WHERE fname = ? " ;
  			PreparedStatement pstmt = conn.prepareStatement( qs ) ;
  			pstmt.setString(1, fname) ;
  			ResultSet rs = pstmt.executeQuery() ;
  			if( rs.next() )
  			{
          retVal = rs.getString(1) ;
        }
        else
        {
          retVal = "" ;
        }
  			pstmt.close() ;
  		}
  		catch( Exception ex )
  		{
  			System.err.println( "ERROR: DbFmeta.fetchValue()" ) ;
        ex.printStackTrace(System.err) ;
  			retVal = null ;
  		}
  	}
		return retVal;
	}

  public static boolean hasMaskedSequence( Connection conn )
  {
    boolean retVal = false ;
    try
    {
      String seqDir = DbFmeta.fetchValue( conn, SEQ_DIR ) ;
   
      if(seqDir == null) // check seqDir not null (query was ok)
      {
        // error already logged, so just say no masked sequence
        retVal = false ;
      }
      else if(seqDir.length() == 0) // check seqDir not empty (invalid or missing)
      {
        // log missing dir error
        throw new Exception(" ERROR: DbFmeta.java => RID_SEQUENCE_DIR has no valid value in this database. ") ;
      }
      else // we proceed
      {
        // look for one or more masked files in the directory provided
        String trimSeqDir = seqDir.trim() ;
        String[] maskList ;
        File path = new File(trimSeqDir) ;
        maskList =  path.list( new FilenameFilter() {
                      public boolean accept(File dir, String name) {
                        String ff = new File(name).getName() ;
                        return ff.endsWith(".masked") ;
                      }
                    } ) ;
        retVal = (maskList.length > 0) ;
      }
    }
    catch( Exception ex )
    {
      System.err.println( "ERROR: DbFmeta.hasMaskedSequence() :" ) ;
      ex.printStackTrace(System.err) ;
      retVal = false ;
    }
    return retVal ;
  }
}
