package org.genboree.dbaccess;

import java.sql.*;
import java.util.*;
import java.security.*;
import org.genboree.util.* ;

public class Gdatabase
{
    protected String id;
    public String getId() { return id; }
    public void setId( String id )
    {
        if( id == null ) id = "#";
        this.id = id;
    }
    protected String name;
    public String getName() { return name; }
    public void setName( String name ) { this.name = name; }
    protected String codeName;
    public String getCodeName() { return codeName; }
    public void setCodeName( String codeName ) { this.codeName = codeName; }
    protected String description;
    public String getDescription() { return description; }
    public void setDescription( String description ) { this.description = description; }
    protected String hostname;
    public String getHostname() { return hostname; }
    public void setHostname( String hostname ) { this.hostname = hostname; }
    protected String creation;
    public String getCreation() { return creation; }
    public void setCreation( String creation ) { this.creation = creation; }
    protected String type;
    public String getType() { return type; }
    public void setType( String type )
    {
        if( type==null || !type.equals("data_upload") ) type = "reference_sequence";
        this.type = type;
    }

    Frefseq fref = new Frefseq();
    public Frefseq getFrefseq() { return fref; }

    protected boolean multi = false;
    public boolean isMulti() { return multi; }
    public void setMulti( boolean multi ) { this.multi = multi; }

    protected boolean minBin_set = false;
    protected int minBin = 1000;
    public int getMinBin() { return minBin; }
    public boolean isMinBinSet() { return minBin_set; }
    public void setMinBin( int minBin )
    {
        this.minBin = minBin;
        minBin_set = true;
    }

    protected String fdata_id = "#";
    public String getFdataId() { return fdata_id; }

    public boolean fetchMeta( DBAgent db ) throws SQLException {
        Connection conn = db.getConnection( getCodeName() );
        if( conn == null ) return false;
        try
        {
            Statement stmt = conn.createStatement();

            ResultSet rs = stmt.executeQuery( "SELECT fdatatoc_id FROM fdatatoc "+
                "WHERE fdatatoc_name='fdata'" );
            if( rs.next() )
            {
                fdata_id = rs.getString(1);
                setMulti( false );
            }
            else setMulti( true );

            rs = stmt.executeQuery( "SELECT fname, fvalue FROM fmeta" );
            while( rs.next() )
            {
                String nam = rs.getString(1);
                String val = rs.getString(2);
                if( nam.equals("MIN_BIN") )
                    setMinBin( Integer.parseInt(val) );
            }

            stmt.close();
            return true;
        } catch( Exception ex ) {
            db.reportError( ex, "Gdatabase.fetchMeta()" );
        }
        return false;
    }

    protected String[] groupIds = null;
    public String[] getGroupIds() { return groupIds; }
    public void setGroupIds( String[] ids ) { groupIds = ids; }
    public boolean belongsToGroup( String grpId )
    {
        if( groupIds == null || grpId == null ) return false;
        for( int i=0; i<groupIds.length; i++ )
            if( groupIds[i].equals(grpId) ) return true;
        return false;
    }

    public boolean fetchGroupIds( DBAgent db ) throws SQLException {
        groupIds = null;
        if( getId().equals("#") ) return false;
        Connection conn = db.getConnection();
        if( conn == null ) return false;
        try
        {
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery( "SELECT FK_genboree_group_id "+
                "FROM genboree_group_to_gdatabase WHERE FK_gdatabase_id="+getId() );
            Vector v = new Vector();
            while( rs.next() )
            {
                v.addElement( rs.getString(1) );
            }
            stmt.close();
            groupIds = new String[ v.size() ];
            v.copyInto( groupIds );
            return true;
        } catch( Exception ex ) {
            db.reportError( ex, "Gdatabase.fetchGroupIds()" );
        }
        return false;
    }

    public boolean insertGroupIds( DBAgent db ) throws SQLException {
        if( getId().equals("#") ) return false;
        Connection conn = db.getConnection();
        if( conn == null ) return false;
        try
        {
            Statement stmt = conn.createStatement();
            stmt.executeUpdate( "DELETE FROM "+
                "genboree_group_to_gdatabase WHERE FK_gdatabase_id="+getId() );
            stmt.close();
            if( groupIds == null ) return true;
            PreparedStatement pstmt = conn.prepareStatement( "INSERT INTO "+
                "genboree_group_to_gdatabase (FK_genboree_group_id, FK_gdatabase_id) "+
                "VALUES (?, "+getId()+")" );
            for( int i=0; i<groupIds.length; i++ )
            {
                pstmt.setString( 1, groupIds[i] );
                pstmt.executeUpdate();
            }
            pstmt.close();
            return true;
        } catch( Exception ex ) {
            db.reportError( ex, "Gdatabase.insertGroupIds()" );
        }
        return false;
    }

    public void clear()
    {
        id = "#";
        type = "reference_sequence";
        name = description = hostname = creation = "";
        groupIds = null;
        fref.clear();
        fref.setGdatabase( this );
    }

    public Gdatabase()
    {
        clear();
    }

    // This needs to be very conservative in making unique names!
    // Time-stamp only based code has generated errors in the past, due to non-careful approaches!
    public static String generateUniqueName()
    {
      return Util.generateUniqueString() ;
    }

    public static Gdatabase[] fetchAll( DBAgent db, String gtype ) throws SQLException {
        Connection conn = db.getConnection();
        if( conn == null ) return null;
        Gdatabase[] rc = null;
        try
        {
            String qs = "SELECT gdatabase_id, gdatabase_name, gdatabase_code_name, "+
              "gdatabase_description, gdatabase_hostname, gdatabase_creation, gdatabase_type "+
              "FROM gdatabase";
            if( gtype != null ) qs = qs + " WHERE gdatabase_type='" + gtype +"'";
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery( qs );
            Vector v = new Vector();
            while( rs.next() )
            {
                Gdatabase gdb = new Gdatabase();
                gdb.setId( rs.getString(1) );
                gdb.setName( rs.getString(2) );
                gdb.setCodeName( rs.getString(3) );
                gdb.setDescription( rs.getString(4) );
                gdb.setHostname( rs.getString(5) );
                gdb.setCreation( rs.getString(6) );
                gdb.setType( rs.getString(7) );
                gdb.getFrefseq().fetch( db );
                if( db.getLastError() != null )
                {
                    gdb.getFrefseq().setDescription( "Error: database "+gdb.getCodeName() );
                    db.clearLastError();
                }
                v.addElement( gdb );
            }
            stmt.close();
            rc = new Gdatabase[ v.size() ];
            v.copyInto( rc );
            return rc;
        } catch( Exception ex ) {
            db.reportError( ex, "Gdatabase.fetchAll()" );
        }

        return null;
    }

    public String createUpload( DBAgent db, String user_id ) throws SQLException {
        Connection conn = db.getConnection( null, false );
        if( conn == null ) return null;
        String rc = null;
        try
        {
            Statement stmt = conn.createStatement();
            if( stmt.executeUpdate( "INSERT INTO upload "+
                "(upload_created, FK_user_id, FK_gdatabase_id) VALUES "+
                "(NOW(), "+user_id+", "+getId()+")" ) > 0)
            {
                ResultSet rs = stmt.executeQuery( "SELECT LAST_INSERT_ID()" );
                if( rs.next() ) rc = rs.getString( 1 );
            }
            stmt.close();
            conn.close();
        } catch( Exception ex ) {
            db.reportError( ex, "Gdatabase.createUpload()" );
        }
        return rc;
    }


    public boolean insert( DBAgent db, boolean copy_content, String code_name, String templ_name ) throws SQLException {
        Connection conn = db.getConnection( null, false );
        if( conn == null ) return false;
        if( code_name == null ) code_name = "genboree_y_" + generateUniqueName();
        if( templ_name == null ) templ_name = "genboree_template";
        setCodeName( code_name );
        if( !replicate(db, templ_name, getCodeName(), copy_content) )
            return false;
        try
        {
            PreparedStatement pstmt = conn.prepareStatement(
              "INSERT INTO gdatabase (gdatabase_name, gdatabase_code_name, "+
              "gdatabase_description, gdatabase_hostname, gdatabase_creation, "+
              "gdatabase_type) VALUES (?,?,?,?,NOW(),?)" );
            pstmt.setString( 1, getName() );
            pstmt.setString( 2, getCodeName() );
            pstmt.setString( 3, getDescription() );
            pstmt.setString( 4, getHostname() );
            pstmt.setString( 5, getType() );
            int nr = pstmt.executeUpdate();
            if( nr > 0 )
            {
                Statement stmt = conn.createStatement();
                ResultSet rs = stmt.executeQuery( "SELECT LAST_INSERT_ID()" );
                if( rs.next() )
                {
                    setId( rs.getString(1) );
                }
                stmt.close();
            }
            pstmt.close();
            conn.close();
            return true;
        } catch( Exception ex ) {
            db.reportError( ex, "Gdatabase.insert()" );
        }
        return false;
    }

    public boolean insert( DBAgent db, boolean copy_content ) throws SQLException {
        return insert( db, copy_content, null, null );
    }


    public boolean insertByTemplate( DBAgent db, Gdatabase tgdb ) throws SQLException {
        if( !isMulti() )
        {
            boolean rc = insert( db, true, "genboree_s_"+generateUniqueName(), tgdb.getCodeName() );
            if( rc ) rc = getFrefseq().update( db );
            return rc;
        }

        if( !insert(db, false, "genboree_m_"+generateUniqueName(), null) )
            return false;
        if( !getFrefseq().insert(db) )
            return false;
        Connection srcConn = db.getConnection( tgdb.getCodeName() );
        Connection tgtConn = db.getConnection( getCodeName() );
        if( srcConn == null || tgtConn == null ) return false;
        try
        {
            String[] tbList = { "fmeta", "fcategory", "ftype", "ftypestyle", "ftypelink" };
            int i;
            for( i=0; i<tbList.length; i++ )
                copyTable( srcConn, tgtConn, tbList[i] );

            fetchMeta( db );
            setMulti( true );

            Fentrypoint[] feps = tgdb.fetchEntrypoints( db );
            if( feps != null )
            for( i=0; i<feps.length; i++ )
            {
                Fentrypoint fep = feps[i];
                fep.setGdatabase( this );
                fep.setId( "#" );
                fep.getFdata().setId( "#" );
                fep.insert( db );
            }
            return true;
        } catch( Exception ex ) {
            db.reportError( ex, "Gdatabase.insertByTemplate()" );
        }
        return false;
    }


    public boolean update( DBAgent db ) throws SQLException {
        if( getId().equals("#") ) return false;
        Connection conn = db.getConnection();
        if( conn == null ) return false;
        try
        {
            PreparedStatement pstmt = conn.prepareStatement(
              "UPDATE gdatabase SET gdatabase_name=?, "+
              "gdatabase_description=?, gdatabase_hostname=? "+
              "WHERE gdatabase_id="+getId() );
            pstmt.setString( 1, getName() );
            pstmt.setString( 2, getDescription() );
            pstmt.setString( 3, getHostname() );
            pstmt.executeUpdate();
            pstmt.close();
            return true;
        } catch( Exception ex ) {
            db.reportError( ex, "Gdatabase.update()" );
        }
        return false;
    }

    public boolean delete( DBAgent db ) throws SQLException {
        if( getId().equals("#") ) return false;
        Connection conn = db.getConnection();
        if( conn == null ) return false;
        try
        {
            Statement stmt = conn.createStatement();
            stmt.executeUpdate( "DELETE FROM gdatabase WHERE gdatabase_id="+getId() );
            try
            {
                stmt.executeUpdate( "DROP DATABASE "+getCodeName() );
            } catch( Exception ex1 ) {}
            stmt.close();
            clear();
            return true;
        } catch( Exception ex ) {
            db.reportError( ex, "Gdatabase.delete()" );
        }
        return false;
    }

    protected String[][] fdSet = null;
    protected int fdNameToIdx( String n )
    {
        if( fdSet == null ) return -1;
        for( int i=0; i<fdSet.length; i++ )
            if( fdSet[i][0].equals(n) ) return i;
        return -1;
    }
    public String[][] getFdset() { return fdSet; }

    public String createFdataSet( DBAgent db, boolean multi ) throws SQLException {
        if( fdSet == null ) fdSet = db.fetchSchema( "genboree_tables" );
        if( fdSet == null ) return null;
        Connection tgtConn = db.getConnection( getCodeName(), false );
        if( tgtConn==null ) return null;
        try
        {
            Statement tgtStmt = tgtConn.createStatement();
            String suff = "";
            String fdata_id = null;
            int nr = tgtStmt.executeUpdate( "INSERT INTO fdatatoc (fdatatoc_name, "+
              "fdatatoc_type) VALUES ('fdata', 'fdata')" );
            ResultSet rs = tgtStmt.executeQuery( "SELECT LAST_INSERT_ID()" );
            if( rs.next() )
            {
                fdata_id = rs.getString(1);
                if( multi ) suff = "_" + fdata_id;
            }

            for( int i=0; i<fdSet.length; i++ )
            {
                String tbName = fdSet[i][0];
                String qs = fdSet[i][1];
                int l = tbName.length();
                String tbNameS = tbName + suff;
                if( multi )
                {
                    int idx = qs.indexOf( tbName );
                    if( idx >= 0 ) qs = qs.substring(0,idx) + tbNameS + qs.substring(idx+l);
                }

                tgtStmt.executeUpdate( qs );

                String tbId = null;
                if( fdata_id!=null && tbName.equals("fdata") )
                {
                    tgtStmt.executeUpdate( "UPDATE fdatatoc SET fdatatoc_name='"+tbNameS+
                        "' WHERE fdatatoc_id="+fdata_id );
                    tbId = fdata_id;
                }
                else
                {
                    tgtStmt.executeUpdate( "INSERT INTO fdatatoc (fdatatoc_name, "+
                        "fdatatoc_type) VALUES ('"+tbNameS+"','"+tbName+"')" );
                    rs = tgtStmt.executeQuery( "SELECT LAST_INSERT_ID()" );
                    if( rs.next() ) tbId = rs.getString(1);
                }
                fdSet[i][2] = tbId;
                fdSet[i][3] = tbNameS;
            }

            tgtStmt.close();
            tgtConn.close();
            return fdata_id;
        } catch( Exception ex ) {
            db.reportError( ex, "Gdatabase.createFdataSet()" );
        }
        return null;
    }

    protected static void copyTable( Connection srcConn, Connection tgtConn, String tbName )
        throws SQLException
    {
        Statement stmt = srcConn.createStatement();
        ResultSet rs = stmt.executeQuery( "SELECT * FROM "+tbName );
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
                String q = "INSERT INTO "+tbName+" ("+s1+") VALUES ("+s2+")";
                pstmt = tgtConn.prepareStatement( q );
            }
            for( i=0; i<ncol; i++ ) pstmt.setString( i+1, rs.getString(i+1) );
            pstmt.executeUpdate();
        }
        stmt.close();
        if( pstmt != null ) pstmt.close();
    }

    public static boolean createTables( DBAgent db, String srcDbName, String tgtDbName, boolean copy_content ) throws SQLException {
        Connection srcConn = db.getConnection( srcDbName );
        Connection tgtConn = db.getConnection( tgtDbName );
        if( srcConn==null || tgtConn==null ) return false;
        try
        {
            Statement stmt = srcConn.createStatement();
            Statement srcStmt = srcConn.createStatement();
            Statement tgtStmt = tgtConn.createStatement();
            ResultSet tbList = stmt.executeQuery( "SHOW TABLES" );
            while( tbList.next() )
            {
                String tbName = tbList.getString(1);
                ResultSet crtb = srcStmt.executeQuery( "SHOW CREATE TABLE "+tbName );
                if( crtb.next() )
                {
                    String qs = crtb.getString(2);
                    tgtStmt.executeUpdate( qs );
                    if( copy_content ) copyTable( srcConn, tgtConn, tbName );
                }
            }
            stmt.close();
            srcStmt.close();
            tgtStmt.close();
            return true;
        } catch( Exception ex ) {
            db.reportError( ex, "Gdatabase.createTables()" );
        }
        return false;
    }

    public static boolean replicate( DBAgent db, String srcDbName, String tgtDbName, boolean copy_content ) throws SQLException {
        if( db.executeUpdate(srcDbName, "CREATE DATABASE " + tgtDbName) == -1 )
            return false;
        return createTables( db, srcDbName, tgtDbName, copy_content );
    }

    public Fentrypoint[] fetchEntrypoints( DBAgent db ) throws SQLException {
        if( getId().equals("#") ) return null;
        Connection conn = db.getConnection( getCodeName() );
        if( conn == null ) return null;
        try
        {
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery( "SELECT fentrypoint_id, fentrypoint_name, "+
                "fentrypoint_description, FK_frefseq_id, FK_fdata_id, FK_fentrypoint_parent_id, "+
                "FK_fdatatoc_id, fdatatoc_name FROM fentrypoint, fdatatoc "+
                "WHERE FK_fdatatoc_id=fdatatoc_id" );
            Vector v = new Vector();
            while( rs.next() )
            {
                Fentrypoint fep = new Fentrypoint();
                fep.setId( rs.getString(1) );
                fep.setName( rs.getString(2) );
                fep.setDescription( rs.getString(3) );
                fep.setFrefseq_id( rs.getString(4) );
                fep.setFdata_id( rs.getString(5) );
                fep.setParent_id( rs.getString(6) );
                fep.setFdatatoc_id( rs.getString(7) );
                String tbName = rs.getString(8);
                Fdata fd = fep.getFdata();
                fd.setId( fep.getFdata_id() );
                fd.fetch( conn, tbName );
                fep.setGdatabase( this );
                v.addElement( fep );
            }
            stmt.close();
            Fentrypoint[] rc = new Fentrypoint[ v.size() ];
            v.copyInto( rc );
            return rc;
        } catch( Exception ex ) {}
        return null;
    }

    public Ftype[] fetchFtypes( DBAgent db ) throws SQLException {
        Connection conn = db.getConnection( getCodeName() );
        if( conn == null ) return null;
        try
        {
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery( "SELECT ftype_id, ftype_type, "+
                "ftype_subtype, ftype_order, FK_ftypestyle_id, FK_fcategory_id, "+
                "fcategory_name FROM ftype, fcategory WHERE FK_fcategory_id=fcategory_id "+
                "ORDER BY ftype_order" );
            Vector v = new Vector();
            while( rs.next() )
            {
                Ftype ft = new Ftype();
                ft.setId( rs.getString(1) );
                ft.setType( rs.getString(2) );
                ft.setSubtype( rs.getString(3) );
                ft.setOrder( rs.getString(4) );
                ft.setFtypestyle_id( rs.getString(5) );
                ft.setFcategory_id( rs.getString(6) );
                ft.setFcategory_name( rs.getString(7) );
                ft.setGdatabase( this );
                v.addElement( ft );
            }
            Ftype[] rc = new Ftype[ v.size() ];
            v.copyInto( rc );
            return rc;
        } catch( Exception ex ) {
            db.reportError( ex, "Gdatabase.fetchFtypes()" );
        }
        return null;
    }

}
