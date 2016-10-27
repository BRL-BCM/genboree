package org.genboree.dbaccess;

import java.sql.*;
import java.util.*;
import org.genboree.util.Util;

public class Fentrypoint
{
    protected String id;
    public String getId() { return id; }
    public void setId( String id )
    {
        if( id == null ) id = "#";
        this.id = id;
    }
    protected String parent_id;
    public String getParent_id() { return parent_id; }
    public void setParent_id( String parent_id ) { this.parent_id = parent_id; }
    protected String name;
    public String getName() { return name; }
    public void setName( String name ) { this.name = name; }
    protected String description;
    public String getDescription() { return description; }
    public void setDescription( String description ) { this.description = description; }
    protected String frefseq_id;
    public String getFrefseq_id() { return frefseq_id; }
    public void setFrefseq_id( String frefseq_id ) { this.frefseq_id = frefseq_id; }
    protected String fdata_id;
    public String getFdata_id() { return fdata_id; }
    public void setFdata_id( String fdata_id ) { this.fdata_id = fdata_id; }
    protected String fdatatoc_id;
    public String getFdatatoc_id() { return fdatatoc_id; }
    public void setFdatatoc_id( String fdatatoc_id ) { this.fdatatoc_id = fdatatoc_id; }

    protected Hashtable tbSet = null;

    protected Gdatabase gdb = null;
    public Gdatabase getGdatabase() { return gdb; }
    public void setGdatabase( Gdatabase gdb )
    {
        this.gdb = gdb;
        tbSet = null;
    }

    protected Fdata fd = new Fdata();
    public Fdata getFdata() { return fd; }

    public void clear()
    {
        id = "#";
        parent_id = name = description = frefseq_id = fdata_id = fdatatoc_id = "";
        gdb = null;
        fd.clear();
    }

    public Fentrypoint()
    {
        clear();
    }

    protected void initTbSet()
    {
        tbSet = new Hashtable();
        tbSet.put( "fdata", "fdata" );
        tbSet.put( "flink", "flink" );
        tbSet.put( "fnote", "fnote" );
        tbSet.put( "fsequence", "fsequence" );
        tbSet.put( "fdata_to_flink", "fdata_to_flink" );
        tbSet.put( "fdata_to_fsequence", "fdata_to_fsequence" );
        tbSet.put( "fdata_to_fnote", "fdata_to_fnote" );
        tbSet.put( "fgroup", "fgroup" );
        tbSet.put( "fname", "fname" );
    }

    public String getTableByType( String tbType ) throws SQLException {
        return getTableByType( tbType, DBAgent.getInstance() );
    }

    public String getTableByType( String tbType, DBAgent db ) throws SQLException {
        Gdatabase gdb = getGdatabase();
        if( gdb == null ) return tbType;
        if( tbSet == null )
        {
            Connection conn = db.getConnection( gdb.getCodeName() );
            if( conn == null ) return tbType;
            initTbSet();
            if( gdb.isMulti() ) try
            {
                Statement stmt = conn.createStatement();
                ResultSet rs = stmt.executeQuery( "SELECT fdatatoc_name, fdatatoc_type "+
                "FROM fdatatoc, fdatatoc_to_fentrypoint_to_ftype "+
                "WHERE FK_fdatatoc_id=fdatatoc_id AND FK_fentrypoint_id="+getId()+
                " AND FK_ftype_id="+getFdata().getFtype_id() );
                while( rs.next() )
                {
                    String tbn = rs.getString(1);
                    String tbt = rs.getString(2);
                    tbSet.put( tbt, tbn );
                }
                stmt.close();
            } catch( Exception ex ) {}
        }
        return (String) tbSet.get( tbType );
    }

    public String getFdata_name() throws SQLException { return getTableByType("fdata"); }

    public boolean update( DBAgent db ) throws SQLException {
        Gdatabase gdb = getGdatabase();
        if( gdb == null ) return false;
        Fdata fd = getFdata();
        Connection conn = db.getConnection( gdb.getCodeName(), false );
        if( conn == null ) return false;
        try
        {
            PreparedStatement pstmt = conn.prepareStatement( "UPDATE fentrypoint "+
                "SET fentrypoint_name=?, fentrypoint_description=? "+
                "WHERE fentrypoint_id="+getId() );
            pstmt.setString( 1, getName() );
            pstmt.setString( 2, getDescription() );
            pstmt.executeUpdate();

            fd.update( conn, getFdata_name(), gdb.getMinBin() );

            pstmt = conn.prepareStatement( "UPDATE "+getTableByType("fname")+
                " SET fname_value=? WHERE fname_id="+fd.getFname_id() );
            pstmt.setString( 1, getName() );
            pstmt.executeUpdate();
            pstmt.close();
            return true;
        } catch( Exception ex ) {
            db.reportError( ex, "Fentrypoint.update()" );
        }
        return false;
    }

    public boolean delete( DBAgent db ) throws SQLException {
        Gdatabase gdb = getGdatabase();
        if( gdb == null ) return false;
        Fdata fd = getFdata();
        Connection conn = db.getConnection( gdb.getCodeName(), false );
        if( conn == null ) return false;
        try
        {
            Statement stmt = conn.createStatement();
            stmt.executeUpdate( "DELETE FROM fentrypoint WHERE fentrypoint_id="+getId() );
            fd.delete( conn, getFdata_name() );
            stmt.executeUpdate( "DELETE FROM "+getTableByType("fname")+
                " WHERE fname_id="+fd.getFname_id() );
            stmt.close();
            clear();
            return true;
        } catch( Exception ex ) {
            db.reportError( ex, "Fentrypoint.delete()" );
        }
        return false;
    }

    public boolean insert( DBAgent db ) throws SQLException {
        Gdatabase gdb = getGdatabase();
        if( gdb == null ) return false;
        String frefseq_id = gdb.getFrefseq().getId();
        if( frefseq_id.equals("#") ) return false;
        Fdata fd = getFdata();
        Connection conn = db.getConnection( gdb.getCodeName(), false );
        if( conn == null ) return false;
        try
        {
            setFrefseq_id( frefseq_id );
            setFdatatoc_id( gdb.isMulti() ? gdb.createFdataSet(db, true) : gdb.getFdataId() );

            PreparedStatement pstmt = conn.prepareStatement( "INSERT INTO fentrypoint "+
                "(fentrypoint_name, fentrypoint_description, FK_frefseq_id, "+
                "FK_fentrypoint_parent_id, FK_fdatatoc_id) VALUES (?,?,?,?,?)" );
            Statement stmt = conn.createStatement();
            ResultSet rs;
            pstmt.setString( 1, getName() );
            pstmt.setString( 2, getDescription() );
            pstmt.setString( 3, getFrefseq_id() );
            pstmt.setString( 4, getParent_id() );
            pstmt.setString( 5, getFdatatoc_id() );
            if( pstmt.executeUpdate() > 0 )
            {
                rs = stmt.executeQuery( "SELECT LAST_INSERT_ID()" );
                if( rs.next() ) setId( rs.getString(1) );
            }
            pstmt.close();

            initTbSet();

            if( gdb.isMulti() )
            {
                String[][] fdSet = gdb.getFdset();
                String ftid = fd.getFtype_id();
                if( Util.isEmpty(ftid) ) ftid = "0";
                else if( ftid.equals("#") ) ftid = "0";
                pstmt = conn.prepareStatement( "INSERT INTO fdatatoc_to_fentrypoint_to_ftype "+
                    "(FK_fdatatoc_id, FK_fentrypoint_id, FK_ftype_id) VALUES "+
                    "(?," + getId() + "," + ftid + ")" );
                for( int i=0; i<fdSet.length; i++ )
                {
                    String fdatatoc_id = fdSet[i][2];
                    String fdatatoc_name = fdSet[i][3];
                    String fdatatoc_type = fdSet[i][0];
                    tbSet.put( fdatatoc_type, fdatatoc_name );
                    pstmt.setString( 1, fdatatoc_id );
                    pstmt.executeUpdate();
                }

                pstmt.close();
            }

            String tbFname = getTableByType( "fname" );

            pstmt = conn.prepareStatement( "INSERT INTO " + tbFname +
                " (fname_value) VALUES (?)" );
            pstmt.setString( 1, getName() );
            if( pstmt.executeUpdate() > 0 )
            {
                rs = stmt.executeQuery( "SELECT LAST_INSERT_ID()" );
                if( rs.next() ) fd.setFname_id( rs.getString(1) );
            }
            pstmt.close();

            fd.setFentrypoint_id( getId() );
            fd.insert( conn, getFdata_name(), gdb.getMinBin() );

            stmt.executeUpdate( "UPDATE fentrypoint SET FK_fdata_id="+fd.getId()+
                " WHERE fentrypoint_id="+getId() );

            stmt.close();
            conn.close();
            return true;
        } catch( Exception ex ) {
            db.reportError( ex, "Fentrypoint.insert()" );
        }
        return false;
    }
}
