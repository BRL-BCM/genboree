package org.genboree.dbaccess;

import java.util.*;
import java.sql.*;
import org.genboree.util.Util;
import org.genboree.manager.tracks.Utility;


/**
 * class to handle ftype to gclass mapping
 */



public class DbFtypeGroup implements SQLCreateTable
{
/*
	protected int ftypeid;
	public int getFtypeid() { return ftypeid; }
	public void setFtypeid( int ftypeid ) { this.ftypeid = ftypeid; }
	protected int gid;
	public int getGid() { return gid; }
	public void setGid( int gid ) { this.gid = gid; }

	public DbFtypeGroup() {}
*/


    public static DbFtype[] fetchAll( Connection conn, DbFtype[] trackArray )
    {
        Vector vr = new Vector();
        if( conn != null && trackArray != null ) try
        {
            int i;
            PreparedStatement pstmt = conn.prepareStatement(
                "SELECT gclass FROM gclass g, ftype2gclass f WHERE f.gid=g.gid AND f.ftypeid=?" );
            Hashtable htMap = new Hashtable();
            Hashtable htDef = new Hashtable();
            Hashtable htCur = new Hashtable();
            for( i=0; i<trackArray.length; i++ )
            {
                DbFtype ft = trackArray[i];
                String trackName = ft.toString();
                Vector v = (Vector) htDef.get( trackName );
                if( v == null )
                {
                    v = new Vector();
                    htMap.put( trackName, ft );
                    htDef.put( trackName, v );
                }
                if( !Util.isEmpty(ft.getGclass()) ) v.addElement( ft.getGclass() );
                v = (Vector) htCur.get( trackName );
                if( v == null )
                {
                    v = new Vector();
                    pstmt.setInt( 1, ft.getFtypeid() );
                    ResultSet rs = pstmt.executeQuery();
                    while( rs.next() )
                    {
                        v.addElement( rs.getString(1) );
                    }
                    htCur.put( trackName, v );
                }
            }
            for( Enumeration en = htMap.keys(); en.hasMoreElements(); )
            {
                String trackName = (String) en.nextElement();
                DbFtype ft = (DbFtype) htMap.get( trackName );
                Vector v = (Vector) htCur.get( trackName );
                if( v == null ) v = new Vector();
                if( v.size()==0 ) v = (Vector) htDef.get( trackName );
                if( v.size()==0 )
                {
                    vr.addElement( ft );
                }
                else
                {
                    for( i=0; i<v.size(); i++ )
                    {
                        String gclass = (String) v.elementAt( i );
                        DbFtype ftx = (DbFtype) ft.clone();
                        ftx.setGclass( gclass );
                        vr.addElement( ftx );
                    }
                }
            }
            pstmt.close();
        } catch( Exception ex )
        {
		    if( ex instanceof SQLException && ((SQLException)ex).getErrorCode()==1146 )
		        org.genboree.manager.tracks.Utility.createTable( conn, createTableFtype2gclass );
// ex.printStackTrace( System.err );
// System.err.flush();
		    return trackArray;
        }
        DbFtype[] rc = new DbFtype[ vr.size() ];
        vr.copyInto( rc );
        return rc;
    }

    public static String[] fetchSingle( Connection conn, DbFtype ft )
    {
        Vector v = new Vector();
        if( conn != null && ft != null ) try
        {
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery(
                "SELECT gid FROM ftype2gclass WHERE ftypeid="+ft.getFtypeid() );
            while( rs.next() )
            {
                v.addElement( rs.getString(1) );
            }
            stmt.close();
        } catch( Exception ex )
        {
		    if( ex instanceof SQLException && ((SQLException)ex).getErrorCode()==1146 )
		         Utility.createTable( conn, createTableFtype2gclass );
        }
        String[] rc = new String[ v.size() ];
        v.copyInto( rc );
        return rc;
    }

    public static boolean updateSingle( Connection conn, DbFtype ft, String[] gids )
    {
        if( conn != null && ft != null ) try
        {
            int i;
            Statement stmt = conn.createStatement();
            stmt.executeUpdate( "DELETE FROM ftype2gclass WHERE ftypeid="+ft.getFtypeid() );
            stmt.close();
            if( gids==null || gids.length==0 ) return true;
            PreparedStatement pstmt = conn.prepareStatement(
                "INSERT INTO ftype2gclass (ftypeid, gid) VALUES (?, ?)" );
            for( i=0; i<gids.length; i++ )
            {
                pstmt.setInt( 1, ft.getFtypeid() );
                pstmt.setString( 2, gids[i] );
                pstmt.executeUpdate();
            }
            pstmt.close();
            return true;
        } catch( Exception ex ) {}
        return false;
    }

    public static DbGclass[] fetchFgroups( Connection conn )
    {
        Vector v = new Vector();
        if( conn != null ) try
        {
			String qs = "SELECT gid, gclass FROM gclass";
			PreparedStatement pstmt = conn.prepareStatement( qs );
			ResultSet rs = pstmt.executeQuery();
			while( rs.next() )
			{
				DbGclass p = new DbGclass();
				p.setGid( rs.getInt(1) );
				p.setGclass( rs.getString(2) );
				if( p.getGclass().compareToIgnoreCase("Sequence") != 0 )
				    v.addElement( p );
			}
			pstmt.close();
        } catch( Exception ex ) {}
        DbGclass[] rc = new DbGclass[ v.size() ];
        v.copyInto( rc );
        return rc;
    }

	public static int updateFdata( Connection conn, String trkId, String oldGid, String newGid )
	{
	    int rc = 0;
	    if( trkId==null || oldGid==null || newGid==null ) return 0;
	    try
	    {
	        Statement stmt = conn.createStatement();
	        String qs = " SET gid="+newGid+" WHERE ftypeid="+trkId+" AND gid="+oldGid;
	        rc = stmt.executeUpdate( "UPDATE fdata2"+qs );
	        rc += stmt.executeUpdate( "UPDATE fdata2_cv"+qs );
	        rc += stmt.executeUpdate( "UPDATE fdata2_gv"+qs );
	        stmt.close();
	    } catch( Exception ex ) {}
	    return rc;
	}
}

