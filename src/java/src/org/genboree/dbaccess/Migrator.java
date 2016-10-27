package org.genboree.dbaccess;

import java.io.PrintStream;
import java.security.MessageDigest;
import java.sql.*;
import java.util.Arrays;
import java.util.Enumeration;
import java.util.Hashtable;
import java.util.Vector;

public class Migrator extends DBAgent implements SQLCreateTable
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
        return "genboree_" + outstr;
    }

    public String replicateChild( String oldName ) throws SQLException
    {
        String baseDb = "genboree_test";
        DbResourceSet dbRes = null;
        DbResourceSet dbRes2 = null;
        DbResourceSet dbRes3 = null;
        ResultSet rs = null;
        ResultSet rs2 = null;
        Connection oldConn = getConnection( oldName );
        Connection baseConn = getConnection( baseDb );


        if( oldConn == null || baseConn == null ) return null;
        String newName = newDatabaseName();
        dbRes = executeQuery( null, "CREATE DATABASE "+newName );


        Connection newConn = getConnection( newName );
        if( newConn == null ) return null;
        dbRes = executeQuery( baseDb, "SHOW TABLES" );
        rs = dbRes.resultSet;

        while( rs.next() )
        {
            String tbName = rs.getString(1);
            dbRes2 = executeQuery( baseDb, "SHOW CREATE TABLE "+tbName );
            rs2 = dbRes2.resultSet;


            if( rs2.next() )
            {
                String crt = rs2.getString(2);
                dbRes3 = executeQuery( newName, crt );
                dbRes3.close();
            }
            rs2.close();
        }
        rs.close();
        return newName;
    }

// Migrate fdata/fgroup -> fdata2/gclass/fref




public static boolean migrateFdataTables( DBAgent db, String dbName ) throws SQLException {
    Connection conn = db.getConnection( dbName, false );
    if( conn != null ) try
    {
        int i;
// System.err.println( "migrate "+dbName+" : "+(new java.util.Date()).toString() );
        Statement stmt = conn.createStatement();

        ResultSet rs = stmt.executeQuery( "SELECT fref FROM fdata WHERE fid=0" );

        for( i=0; i<migrateFdata.length; i+=2 )
        {
            try
            {
                stmt.executeUpdate( "DROP TABLE "+migrateFdata[i] );
            } catch( Exception ex00 ) {}
            stmt.executeUpdate( migrateFdata[i+1] );
        }

        Hashtable htGclass = new Hashtable();
        Hashtable htGupp = new Hashtable();
        Hashtable htFref = new Hashtable();

        PreparedStatement psGclass = conn.prepareStatement(
            "INSERT INTO gclass (gclass) VALUES (?)" );

        String gclass = "Sequence";
        psGclass.setString( 1, gclass );
        psGclass.executeUpdate();
        int igclassId = db.getLastInsertId( conn );
        htGclass.put( gclass, ""+igclassId );

        PreparedStatement psFref = conn.prepareStatement(
            "INSERT INTO fref (refname, rlength, ftypeid, rstrand, gid, gname) "+
            "VALUES (?, ?, ?, '+', ?, ?)" );

        rs = stmt.executeQuery(
            "SELECT f.fref, f.ftypeid, MAX(f.fstop), g.gname "+
            "FROM fdata f, fgroup g "+
            "WHERE g.gid = f.gid AND g.gclass='Sequence' "+
            "GROUP BY f.fref, f.ftypeid" );

        while( rs.next() )
        {
            String fref = rs.getString(1);

            psFref.setString( 1, fref );
            psFref.setLong( 2, rs.getLong(3) );
            psFref.setString( 3, rs.getString(2) );
            psFref.setInt( 4, igclassId );
            psFref.setString( 5, rs.getString(4) );
            try
            {
                psFref.executeUpdate();
                int frefId = db.getLastInsertId( conn );
                htFref.put( fref, ""+frefId );
            } catch( Throwable thr ) {}
        }

// System.err.println( "fref done: "+(new java.util.Date()).toString() );

        String sfdataIns = " (rid, fstart, fstop, fbin, ftypeid, fscore, fstrand, "+
            "fphase, ftarget_start, ftarget_stop, gname) "+
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";

        PreparedStatement psFdata = conn.prepareStatement( "INSERT INTO fdata2" + sfdataIns );
        PreparedStatement psFdata_cv = conn.prepareStatement( "INSERT INTO fdata2_cv" + sfdataIns );
        PreparedStatement psFdata_gv = conn.prepareStatement( "INSERT INTO fdata2_gv" + sfdataIns );

        rs = stmt.executeQuery(
            "SELECT fref, fstart, fstop, fbin, f.ftypeid, fscore, fstrand, "+
            "fphase, ftarget_start, ftarget_stop, fg.gname, fg.gclass "+
            "FROM fdata f, fgroup fg "+
            "WHERE fg.gid = f.gid AND fg.gclass<>'Sequence'" );
        while( rs.next() )
        {
            String fref = rs.getString(1);
            String frefId = (String) htFref.get( fref );
            if( frefId == null ) continue;

            String gname = rs.getString(11);
            PreparedStatement ps = psFdata;
            if( gname.endsWith("_CV") ) ps = psFdata_cv;
            if( gname.endsWith("_GV") ) ps = psFdata_gv;

            ps.setString( 1, frefId );
            ps.setLong( 2, rs.getLong(2) );
            ps.setLong( 3, rs.getLong(3) );
            ps.setString( 4, rs.getString(4) );
            ps.setString( 5, rs.getString(5) );
            ps.setString( 6, rs.getString(6) );
            ps.setString( 7, rs.getString(7) );
            ps.setString( 8, rs.getString(8) );
            ps.setString( 9, rs.getString(9) );
            ps.setString( 10, rs.getString(10) );
            ps.setString( 11, gname );

            gclass = rs.getString(12);

            String gcUpp = gclass.toUpperCase();
            String gclassId = (String) htGclass.get( gclass );
            if( gclassId == null )
            {
                String gKey = (String) htGupp.get( gcUpp );
                if( gKey != null ) gclassId = (String) htGclass.get( gKey );
            }

            if( gclassId == null )
            {
                psGclass.setString( 1, gclass );
                psGclass.executeUpdate();
                igclassId = db.getLastInsertId( conn );
                gclassId = ""+igclassId;
                htGclass.put( gclass, gclassId );
                htGupp.put( gcUpp, gclass );
            }

            ps.setString( 12, gclassId );
            ps.executeUpdate();
        }

// System.err.println( "fdata2 done: "+(new java.util.Date()).toString() );

        psGclass.close();
        psFref.close();
        psFdata.close();
        psFdata_cv.close();
        psFdata_gv.close();

        // Copy styles, colors and links
        Hashtable htStyleId = new Hashtable(); // map oldStyleID->newStyleId
        Hashtable htColorId = new Hashtable(); // map oldColorID->newColorId
        Hashtable htLinkId = new Hashtable();  // map oldLinkID->newLinkId
        Hashtable htLink = new Hashtable();  // map oldLinkID->link (String[2])

        String defColorId = null;
        String defStyleId = null;

        Connection mconn = db.getConnection();
        Statement mstmt = mconn.createStatement();

        // Copy styles
        PreparedStatement psStyle = conn.prepareStatement(
            "INSERT INTO style (name, description) VALUES (?, ?)" );
        rs = mstmt.executeQuery( "SELECT styleId, name, description FROM style" );
        while( rs.next() )
        {
            String oldStyleId = rs.getString(1);
            String styleName = rs.getString(2);
            psStyle.setString( 1, styleName );
            psStyle.setString( 2, rs.getString(3) );
            psStyle.executeUpdate();
            String newStyleId = ""+db.getLastInsertId(conn);
            htStyleId.put( oldStyleId, newStyleId );
            if( defStyleId==null || styleName.equals("gene_draw") ) defStyleId = newStyleId;
        }
        psStyle.close();

// System.err.println( "style done: "+(new java.util.Date()).toString() );

        // Copy colors
        PreparedStatement psColor = conn.prepareStatement(
            "INSERT INTO color (value) VALUES (?)" );
        rs = mstmt.executeQuery( "SELECT colorId, value FROM color" );
        while( rs.next() )
        {
            String oldColorId = rs.getString(1);
            String colorValue = rs.getString(2);
            psColor.setString( 1, colorValue );
            psColor.executeUpdate();
            String newColorId = ""+db.getLastInsertId(conn);
            htColorId.put( oldColorId, newColorId );
            if( defColorId==null || colorValue.equals("#6699FF") ) defColorId = newColorId;
        }
        psColor.close();

// System.err.println( "color done: "+(new java.util.Date()).toString() );

        // Cache links
        rs = mstmt.executeQuery( "SELECT linkId, name, description FROM link" );
        while( rs.next() )
        {
            String oldLinkId = rs.getString(1);
            String[] lnk = new String[2];
            lnk[0] = rs.getString(2);
            lnk[1] = rs.getString(3);
            htLink.put( oldLinkId, lnk );
        }

        PreparedStatement psFtype = mconn.prepareStatement(
            "SELECT featureTypeId FROM featuretype WHERE name=?" );

        psStyle = mconn.prepareStatement(
        "SELECT styleId FROM defaultuserfeaturetypestyle WHERE featureTypeId=?" );
        psColor = mconn.prepareStatement(
        "SELECT colorId FROM defaultColor WHERE featureTypeId=?" );

        PreparedStatement psStyleIns = conn.prepareStatement(
        "INSERT INTO featuretostyle (ftypeid, userId, styleId) VALUES (?, ?, ?)" );
        PreparedStatement psColorIns = conn.prepareStatement(
        "INSERT INTO featuretocolor (ftypeid, userId, colorId) VALUES (?, ?, ?)" );

        PreparedStatement psLinkSel = mconn.prepareStatement(
        "SELECT linkId FROM defaultlink WHERE featureTypeId=?" );
        PreparedStatement psLink = conn.prepareStatement(
        "INSERT INTO link (name, description) VALUES (?, ?)" );
        PreparedStatement psLinkIns = conn.prepareStatement(
        "INSERT INTO featuretolink (ftypeid, userId, linkId) VALUES (?, ?, ?)" );

        PreparedStatement psSortIns = conn.prepareStatement(
        "INSERT INTO featuresort (ftypeid, userId, sortkey) VALUES (?, ?, ?)" );

        // map featuretypes
        rs = stmt.executeQuery( "SELECT ftypeid, fmethod, fsource FROM ftype "+
            "ORDER BY fmethod, fsource" );
        int sortKey = 0;
        while( rs.next() )
        {
            String ftypeId = rs.getString(1);
            String fmethod = rs.getString(2);
            String fsource = rs.getString(3);

            String newStyleId = defStyleId;
            String newColorId = defColorId;

            psSortIns.setString( 1, ftypeId );
            psSortIns.setInt( 2, 0 );
            psSortIns.setInt( 3, ++sortKey );
            psSortIns.executeUpdate();

            psFtype.setString( 1, fmethod+":"+fsource );
            ResultSet ftrs = psFtype.executeQuery();
            if( ftrs.next() )
            {
                String oldFtypeId = ftrs.getString(1);

                psStyle.setString( 1, oldFtypeId );
                ResultSet rs1 = psStyle.executeQuery();
                if( rs1.next() ) newStyleId = (String) htStyleId.get( rs1.getString(1) );

                psColor.setString( 1, oldFtypeId );
                rs1 = psColor.executeQuery();
                if( rs1.next() ) newColorId = (String) htColorId.get( rs1.getString(1) );

                psLinkSel.setString( 1, oldFtypeId );
                rs1 = psLinkSel.executeQuery();
                while( rs1.next() )
                {
                    String oldLinkId = rs1.getString(1);
                    String newLinkId = (String) htLinkId.get( oldLinkId );
                    if( newLinkId == null )
                    {
                        String[] lnk = (String[]) htLink.get( oldLinkId );
                        if( lnk != null )
                        {
                            psLink.setString( 1, lnk[0] );
                            psLink.setString( 2, lnk[1] );
                            psLink.executeUpdate();
                            newLinkId = ""+db.getLastInsertId( conn );
                            htLinkId.put( oldLinkId, newLinkId );
                        }
                    }
                    if( newLinkId != null )
                    {
                        psLinkIns.setString( 1, ftypeId );
                        psLinkIns.setInt( 2, 0 );
                        psLinkIns.setString( 3, newLinkId );
                        psLinkIns.executeUpdate();
                    }
                }
            }
            psStyleIns.setString( 1, ftypeId );
            psStyleIns.setInt( 2, 0 );
            psStyleIns.setString( 3, newStyleId );
            psStyleIns.executeUpdate();

            psColorIns.setString( 1, ftypeId );
            psColorIns.setInt( 2, 0 );
            psColorIns.setString( 3, newColorId );
            psColorIns.executeUpdate();
        }

// System.err.println( "link done: "+(new java.util.Date()).toString() );

        conn.close();
        return true;
    } catch( Exception ex )
    {
	    if( ex instanceof SQLException && ((SQLException)ex).getErrorCode()==1146 )
		        return true;

        db.reportError( ex, "Migrator.migrateFdataTables()" );
    }
    return false;
}

public static class Ftype
    implements Comparable
{
    public String fmethod;
    public String fsource;
    public String ftypeid;
    public int uploadId;
    public int compareTo( Object o )
    {
        Ftype f = (Ftype)o;
        int rc = fmethod.compareTo( f.fmethod );
        if( rc != 0 ) return rc;
        return fsource.compareTo( f.fsource );
    }
}

public static boolean setFdataSort( DBAgent db, String dbName, GenboreeUpload[] gbUplds ) throws SQLException {
    Connection conn = db.getConnection( dbName );
    if( conn != null ) try
    {
        int i;

        int idx = 0;
        for( i=1; i<gbUplds.length; i++ )
        if( gbUplds[i].getDatabaseName().equals(dbName) )
        {
            idx = i;
            break;
        }
        if( idx > 0 )
        {
            GenboreeUpload u = gbUplds[idx];
            gbUplds[idx] = gbUplds[0];
            gbUplds[0] = u;
        }

        Hashtable htFtype = new Hashtable();
        for( i=0; i<gbUplds.length; i++ )
        {
            DbResourceSet dbRes = null;
            dbRes = db.executeQuery( gbUplds[i].getDatabaseName(), "SELECT ftypeid, fmethod, fsource FROM ftype" );
            ResultSet rs =  dbRes.resultSet;
            if( rs == null ) continue;
            while( rs.next() )
            {
                String ftypeid = rs.getString(1);
                String fmethod = rs.getString(2);
                String fsource = rs.getString(3);
                String key = fmethod+":"+fsource;
                if( htFtype.get(key) != null ) continue;
                Ftype f = new Ftype();
                f.fmethod = fmethod;
                f.fsource = fsource;
                f.ftypeid = ftypeid;
                f.uploadId = gbUplds[i].getUploadId();
                htFtype.put( key, f );
            }
            dbRes.close();
        }

        Ftype[] fts = new Ftype[ htFtype.size() ];
        i = 0;
        for( Enumeration en=htFtype.keys(); en.hasMoreElements(); )
        {
            fts[i++] = (Ftype) htFtype.get( en.nextElement() );
        }
        Arrays.sort( fts );

        db.executeUpdate( dbName, "DELETE FROM featuresort" );

        int sortKey = 0;
        PreparedStatement pstmt = conn.prepareStatement( "INSERT INTO featuresort "+
            "(ftypeid,userId,sortkey) VALUES (?,0,?)" );
        for( i=0; i<fts.length; i++ )
        {
            pstmt.setString( 1, fts[i].ftypeid );

            pstmt.setInt( 2, ++sortKey );
            pstmt.executeUpdate();
        }
        pstmt.close();

        return true;

    } catch( Exception ex )
    {
        db.reportError( ex, "Migrator.setFdataSort()" );
    }
    return false;
}

    public static boolean setUserStyleColor( DBAgent db ) throws SQLException {
        Connection mConn = db.getConnection();
        try
        {
            Hashtable htStyle = new Hashtable();
            Hashtable htColor = new Hashtable();
            Enumeration usrEn;
            PreparedStatement pstmt;

            Statement stmt = mConn.createStatement();
            ResultSet rs = stmt.executeQuery(
                "SELECT fs.userId, ft.name, st.name "+
                "FROM userfeaturetypestyle fs, featuretype ft, style st "+
                "WHERE fs.featureTypeId=ft.featureTypeId AND fs.styleId=st.styleId" );
            while( rs.next() )
            {
                int _userId = rs.getInt(1);
                if( _userId <= 0 ) continue;
                String userId = ""+_userId;
                String ftype = rs.getString(2);
                String style = rs.getString(3);
                Hashtable ht = (Hashtable) htStyle.get( userId );
                if( ht == null )
                {
                    ht = new Hashtable();
                    htStyle.put( userId, ht );
                }
                ht.put( ftype, style );
            }

            rs = stmt.executeQuery(
                "SELECT uc.userId, ft.name, c.value "+
                "FROM userColor uc, featuretype ft, color c "+
                "WHERE uc.featureTypeId=ft.featureTypeId AND uc.colorId=c.colorId" );
            while( rs.next() )
            {
                int _userId = rs.getInt(1);
                if( _userId <= 0 ) continue;
                String userId = ""+_userId;
                String ftype = rs.getString(2);
                String color = rs.getString(3);
                Hashtable ht = (Hashtable) htColor.get( userId );
                if( ht == null )
                {
                    ht = new Hashtable();
                    htColor.put( userId, ht );
                }
                ht.put( ftype, color );
            }
            stmt.close();

            Refseq[] rseqs = Refseq.fetchAll( db );
            for( int rIdx=0; rIdx<rseqs.length; rIdx++ )
            {
                Refseq rseq = rseqs[rIdx];
                String dbName = rseq.getDatabaseName();
                Connection conn = db.getConnection( dbName );
                stmt = conn.createStatement();

                Hashtable locStyle = new Hashtable();
                rs = stmt.executeQuery( "SELECT styleId, name FROM style" );
                while( rs.next() )
                {
                    String styleId = rs.getString(1);
                    String styleName = rs.getString(2);
                    locStyle.put( styleName, styleId );
                }

                Hashtable locColor = new Hashtable();
                rs = stmt.executeQuery( "SELECT colorId, value FROM color" );
                while( rs.next() )
                {
                    String colorId = rs.getString(1);
                    String colorValue = rs.getString(2);
                    locColor.put( colorValue, colorId );
                }

                Hashtable locFtype = new Hashtable();
                rs = stmt.executeQuery( "SELECT ftypeid, fmethod, fsource FROM ftype" );
                while( rs.next() )
                {
                    String ftypeid = rs.getString(1);
                    String fmethod = rs.getString(2);
                    String fsource = rs.getString(3);
                    locFtype.put( fmethod+":"+fsource, ftypeid );
                }

                pstmt = conn.prepareStatement( "INSERT INTO featuretostyle "+
                    "(ftypeid, userId, styleId) VALUES (?, ?, ?)" );

                for( usrEn=htStyle.keys(); usrEn.hasMoreElements(); )
                {
                    String userId = (String) usrEn.nextElement();
                    Hashtable ht = (Hashtable) htStyle.get( userId );

                    stmt.executeUpdate( "DELETE FROM featuretostyle WHERE userId="+userId );

                    for( Enumeration en=ht.keys(); en.hasMoreElements(); )
                    {
                        String ftype = (String) en.nextElement();
                        String style = (String) ht.get( ftype );

                        String ftypeid = (String) locFtype.get( ftype );
                        String styleId = (String) locStyle.get( style );
                        if( ftypeid!=null && styleId!=null )
                        {
                            pstmt.setString( 1, ftypeid );
                            pstmt.setString( 2, userId );
                            pstmt.setString( 3, styleId );
                            pstmt.executeUpdate();
                        }
                    }
                }

                pstmt.close();

                pstmt = conn.prepareStatement( "INSERT INTO featuretocolor "+
                    "(ftypeid, userId, colorId) VALUES (?, ?, ?)" );

                for( usrEn=htColor.keys(); usrEn.hasMoreElements(); )
                {
                    String userId = (String) usrEn.nextElement();
                    Hashtable ht = (Hashtable) htColor.get( userId );

                    stmt.executeUpdate( "DELETE FROM featuretocolor WHERE userId="+userId );

                    for( Enumeration en=ht.keys(); en.hasMoreElements(); )
                    {
                        String ftype = (String) en.nextElement();
                        String color = (String) ht.get( ftype );

                        String ftypeid = (String) locFtype.get( ftype );
                        String colorId = (String) locColor.get( color );
                        if( ftypeid!=null && colorId!=null )
                        {
                            pstmt.setString( 1, ftypeid );
                            pstmt.setString( 2, userId );
                            pstmt.setString( 3, colorId );
                            pstmt.executeUpdate();
                        }
                    }
                }

                pstmt.close();

                stmt.close();
                conn.close();
            }

        } catch( Exception ex )
        {
            db.reportError( ex, "Migrator.setUserStyleColor()" );
        }
        return false;
    }


    private static void printError( DBAgent db, PrintStream out )
    {
        String[] err = db.getLastError();
        db.clearLastError();
        if( err != null )
        for( int i=0; i<err.length; i++ ) out.println( err[i] );
    }

/*
    /www/jdks/j2sdk1.4.1_01/bin/java -Xmx1800MB -classpath GDASServlet.jar org.genboree.dbaccess.Migrator 244
*/
    public static void main( String[] args )
        throws Exception
    {
        DBAgent db = DBAgent.getInstance();
        int i;
        if( args.length < 1 )
        {
            Refseq[] rseqs = Refseq.fetchAll( db );
            if( db.getLastError() != null )
            {
                printError( db, System.err );
            }
            else
            {
                System.out.println( "Usage: java Migrator id1 [id2 id3 ...]" );
                System.out.println( "   id1...idn - RefSeq IDs from the list:" );
                for( i=0; i<rseqs.length; i++ )
                {
                    System.out.println( rseqs[i].getRefSeqId()+" "+rseqs[i].getRefseqName() );
                }
            }
            return;
        }
        Vector v = new Vector();
        Vector vv = new Vector();
        if( args[0].equals("all") )
        {
            Refseq[] rseqs = Refseq.fetchAll( db );
            if( db.getLastError() != null )
            {
                printError( db, System.err );
                return;
            }
            for( i=0; i<rseqs.length; i++ )
            {
                Refseq rseq = rseqs[i];
                String[] dbNames = rseq.fetchDatabaseNames( db );
                if( dbNames!=null )
                {
                    vv.addElement( rseq );
                    for( int j=0; j<dbNames.length; j++ )
                    {
                        if( !v.contains(dbNames[j]) ) v.addElement( dbNames[j] );
                    }
                }
            }
        }
        else
        {
            for( i=0; i<args.length; i++ )
            {
                Refseq rseq = new Refseq();
                rseq.setRefSeqId( args[i] );
                rseq.fetch( db );
                if( db.getLastError() != null )
                {
                    printError( db, System.err );
                    return;
                }
                String[] dbNames = rseq.fetchDatabaseNames( db );
                if( dbNames!=null )
                {
                    vv.addElement( rseq );
                    for( int j=0; j<dbNames.length; j++ )
                    {
                        if( !v.contains(dbNames[j]) ) v.addElement( dbNames[j] );
                    }
                }
            }
        }
        for( i=0; i<v.size(); i++ )
        {
            String dbName = (String) v.elementAt( i );
            System.out.println( dbName + " " );

java.util.Date startDate = new java.util.Date();
            if( migrateFdataTables(db, dbName) )
            {
java.util.Date stopDate = new java.util.Date();
long timeDiff = (stopDate.getTime() - startDate.getTime()) / 100;
long ds = timeDiff % 10;
long ss = timeDiff / 10;
long mm = ss / 60; ss %= 60;
long hh = mm / 60; mm %= 60;
                System.out.println( "OK, " + hh+":"+mm+":"+ss+"."+ds );
            }
            else
            {
                System.out.println( "Error!" );
            }
            if( db.getLastError() != null )
            {
                printError( db, System.err );
            }
            System.err.flush();
            System.gc();
        }
        for( i=0; i<vv.size(); i++ )
        {
            Refseq rseq = (Refseq) vv.elementAt(i);
            System.out.println( "Sort ftypes in "+rseq.getRefseqName() + " " );

            GenboreeUpload[] uplds = GenboreeUpload.fetchAll( db, rseq.getRefSeqId(), null, 7 );
            if( setFdataSort(db, rseq.getDatabaseName(), uplds) ) System.out.println( "OK" );
            else System.out.println( "Error!" );
            if( db.getLastError() != null )
            {
                printError( db, System.err );
            }
            System.err.flush();
            System.gc();
        }
    }

/*
    public static void main( String[] args )
        throws SQLException
    {
        Migrator mg = new Migrator();
        String s = mg.replicateChild( "genboree_0178c8e3975b307f73a0fd45482f1105" );
        System.out.println( "Database created: " + s );
        System.exit(0);
    }
*/
}
