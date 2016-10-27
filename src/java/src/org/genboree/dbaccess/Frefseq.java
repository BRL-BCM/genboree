package org.genboree.dbaccess;

import java.sql.*;
import java.util.*;

public class Frefseq
{
    protected String id;
    public String getId() { return id; }
    public void setId( String id )
    {
        if( id == null ) id = "#";
        this.id = id;
    }
    protected String species;
    public String getSpecies() { return species; }
    public void setSpecies( String species ) { this.species = species; }
    protected String version;
    public String getVersion() { return version; }
    public void setVersion( String version ) { this.version = version; }
    protected String description;
    public String getDescription() { return description; }
    public void setDescription( String description ) { this.description = description; }
    protected String type;
    public String getType() { return type; }
    public void setType( String type )
    {
        if( type==null || !type.equals("public") ) type = "private";
        this.type = type;
    }

    protected Gdatabase gdb;
    public void setGdatabase( Gdatabase gdb ) { this.gdb = gdb; }
    public Gdatabase getGdatabase() { return gdb; }

    public void clear()
    {
        id = "#";
        type = "private";
        species = version = description = "";
        gdb = null;
    }

    public Frefseq()
    {
        clear();
    }

    public boolean fetch( DBAgent db ) throws SQLException {
        Gdatabase gdb = getGdatabase();
        if( gdb == null ) return false;
        Connection conn = db.getConnection( gdb.getCodeName() );
        if( conn == null ) return false;
        try
        {
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery( "SELECT frefseq_id, frefseq_species, "+
              "frefseq_version, frefseq_type, frefseq_description FROM frefseq" );
            if( rs.next() )
            {
                setId( rs.getString(1) );
                setSpecies( rs.getString(2) );
                setVersion( rs.getString(3) );
                setType( rs.getString(4) );
                setDescription( rs.getString(5) );
           }
            stmt.close();
            return true;
        } catch( Exception ex ) {
            db.reportError( ex, "Frefseq.fetch()" );
        }
        return false;
    }

    public boolean insert( DBAgent db ) throws SQLException {
        Gdatabase gdb = getGdatabase();
        if( gdb == null ) return false;
        Connection conn = db.getConnection( gdb.getCodeName(), false );
        if( conn == null ) return false;
        try
        {
            PreparedStatement pstmt = conn.prepareStatement( "INSERT INTO frefseq "+
              "(frefseq_species, frefseq_version, frefseq_type, frefseq_description) VALUES "+
              "(?,?,?,?)" );
            pstmt.setString( 1, getSpecies() );
            pstmt.setString( 2, getVersion() );
            pstmt.setString( 3, getType() );
            pstmt.setString( 4, getDescription() );
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
            db.reportError( ex, "Frefseq.insert()" );
        }
        return false;
    }

    public boolean update( DBAgent db ) throws SQLException {
        if( getId().equals("#") ) return insert( db );
        Gdatabase gdb = getGdatabase();
        if( gdb == null ) return false;
        Connection conn = db.getConnection( gdb.getCodeName() );
        if( conn == null ) return false;
        try
        {
            PreparedStatement pstmt = conn.prepareStatement( "UPDATE frefseq SET "+
              "frefseq_species=?, frefseq_version=?, "+
              "frefseq_type=?, frefseq_description=? WHERE frefseq_id="+getId() );
            pstmt.setString( 1, getSpecies() );
            pstmt.setString( 2, getVersion() );
            pstmt.setString( 3, getType() );
            pstmt.setString( 4, getDescription() );
            pstmt.executeUpdate();
            pstmt.close();
            return true;
        } catch( Exception ex ) {
            db.reportError( ex, "Frefseq.update()" );
        }
        return false;
    }

}
