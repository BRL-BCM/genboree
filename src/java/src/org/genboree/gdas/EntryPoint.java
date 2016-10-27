package org.genboree.gdas;

import java.sql.*;
import java.util.*;
import java.io.*;

import org.genboree.dbaccess.*;
import org.genboree.util.Util;

public class EntryPoint
    implements Comparable
{
    public String fref;
    public String fstop;
    public String gname;

    public int compareTo( Object o )
    {
        return fref.compareTo( ((EntryPoint)o).fref );
    }

    public static EntryPoint[] fetchAll( DBAgent db, String[] dbNames )
    {
        Vector v = new Vector();
        int i;
        for( i=0; i<dbNames.length; i++ )
        try
        {
            Connection conn = db.getConnection( dbNames[i] );
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery(
                "SELECT refname, rlength, gname FROM fref ORDER BY refname" );

            while( rs.next() )
            {
                EntryPoint ep = new EntryPoint();
                ep.fref = rs.getString(1);
                ep.fstop = rs.getString(2);
                ep.gname = rs.getString(3);
                v.addElement( ep );
            }
            stmt.close();
        } catch( Exception ex )
        {
		    if( ex instanceof SQLException && ((SQLException)ex).getErrorCode()==1146 )
		        return fetchAllS( db, dbNames );

            db.reportError(ex, "EntryPoint.fetchAll()");
        }

        EntryPoint[] rc = new EntryPoint[ v.size() ];
        v.copyInto( rc );
        return rc;
    }

    public static EntryPoint[] fetchAllS( DBAgent db, String[] dbNames )
    {
        Hashtable ht = new Hashtable();
        int i;
        for( i=0; i<dbNames.length; i++ )
        try
        {
            Connection conn = db.getConnection( dbNames[i] );
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery(
                "SELECT fref, MAX(fstop), g.gname "+
                "FROM fdata, fgroup g "+
                "WHERE g.gid = fdata.gid AND g.gclass='Sequence' "+
                "GROUP BY fref" );
            while( rs.next() )
            {
                EntryPoint ep = new EntryPoint();
                ep.fref = rs.getString(1);
                ep.fstop = rs.getString(2);
                ep.gname = rs.getString(3);
                ht.put( ep.fref, ep );
            }
            stmt.close();
        } catch( Exception ex ) { db.reportError(ex, "EntryPoint.fetchAll()"); }

        EntryPoint[] rc = new EntryPoint[ ht.size() ];
        i = 0;
        for( Enumeration en = ht.keys(); en.hasMoreElements(); )
        {
            rc[i++] = (EntryPoint) ht.get( en.nextElement() );
        }
        Arrays.sort( rc );
        return rc;
    }

}