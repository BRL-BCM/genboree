package org.genboree.dbaccess;

import java.io.*;
import java.sql.*;
import java.util.*;
import java.security.*;
import org.genboree.util.Util;

public class Replicator extends DBAgent
{

    public static String newDatabaseName()
    {
        String outstr = "child";
        try
        {
            MessageDigest md = MessageDigest.getInstance( "MD5" );
            String instr = "genboree_source_key_" + (new java.util.Date()).toString();
            md.update( instr.getBytes() );
            byte[] dg = md.digest();
            String outc = "";
            for( int i=0; i<dg.length; i++ )
            {
                String hc = Integer.toHexString( (int)dg[i] & 0xFF );
                while( hc.length() < 2 ) hc = "0" + hc;
                outc = outc + hc;
            }
            outstr = new String( outc );
        } catch( Exception ex ) {}
        return "genboree_x_" + outstr;
    }

    public boolean copyTable( String srcdb, String tgtdb, String tbName )
        throws SQLException
    {
        Connection srcConn = getConnection( srcdb );
        Connection tgtConn = getConnection( tgtdb );
        DbResourceSet dbRes = null;
        ResultSet rs =  null;



        if( srcConn == null || tgtConn == null ) return false;

        dbRes = executeQuery( srcdb, "SELECT * FROM " + tbName );
        rs =  dbRes.resultSet;
        PreparedStatement pstmt = null;
        int ncol = 0;
        int i;
        while( rs.next() )
        {
            if( pstmt == null )
            {
                ResultSetMetaData rm = rs.getMetaData();
                ncol = rm.getColumnCount();
                String s1 = "";
                String s2 = "";
                for( i=0; i<ncol; i++ )
                {
                    if( i > 0 ) { s1 = s1 + ","; s2 = s2 + ","; }
                    s1 = s1 + rm.getColumnLabel( i+1 );
                    s2 = s2 + "?";
                }
                String q = "INSERT INTO "+tbName+"("+s1+") VALUES ("+s2+")";
                pstmt = tgtConn.prepareStatement( q );
            }
            for( i=0; i<ncol; i++ )
                pstmt.setString( i+1, rs.getString(i+1) );
            pstmt.executeUpdate();
        }
        dbRes.close(); 
        if( pstmt != null ) pstmt.close();
        return true;
    }

    public boolean replicateSchema( String baseDbName, String newDbName, boolean copy_tables )
        throws SQLException
    {
        DbResourceSet dbRes = null;
        DbResourceSet dbRes2 = null;
        DbResourceSet dbRes3 = null;
        ResultSet rs =  null;
        ResultSet rs2 =  null;
        Connection baseConn = getConnection( baseDbName );
        if( baseConn == null ) return false;
        executeUpdate( null, "CREATE DATABASE "+newDbName );
        Connection newConn = getConnection( newDbName );
        if( newConn == null ) return false;

        dbRes = executeQuery( baseDbName, "SHOW TABLES" );
        rs =  dbRes.resultSet;
        while( rs.next() )
        {
            String tbName = rs.getString(1);
            dbRes2 = executeQuery( baseDbName, "SHOW CREATE TABLE "+tbName );
            rs2 =  dbRes2.resultSet;
            if( rs2.next() )
            {
//System.out.println( tbName );
                String crt = rs2.getString(2);
                dbRes3 = executeQuery( newDbName, crt );
                dbRes3.close();
                if( copy_tables )
                    copyTable( baseDbName, newDbName, tbName );
            }
            dbRes2.close();
        }
        dbRes.close();
        return true;
    }

    public boolean showTables( String srcDbName ) throws SQLException {
        Connection srcConn = getConnection( srcDbName );
        DbResourceSet dbRes = null;
        ResultSet crtb = null;


        if( srcConn==null ) return false;
        try
        {
            Statement stmt = srcConn.createStatement();
            ResultSet tbList = stmt.executeQuery( "SHOW TABLES" );
            while( tbList.next() )
            {
                String tbName = tbList.getString(1);
                dbRes = executeQuery( srcDbName, "SHOW CREATE TABLE "+tbName );
                crtb = dbRes.resultSet;
                if( crtb.next() )
                {
                    String qs = crtb.getString(2);
//                    System.out.println( qs );
                }
                dbRes.close();
            }
            tbList.close();
            stmt.close();
        } catch( Exception ex ) {
            reportError( ex, "Gdatabase.createTables()" );
        }
        return false;
    }


    public static void main( String[] args )
        throws SQLException
    {
        Replicator rp = new Replicator();
        rp.showTables( "genboree_Main" );
        System.exit(0);
    }

}