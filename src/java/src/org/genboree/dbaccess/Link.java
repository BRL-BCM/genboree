package org.genboree.dbaccess;

import java.sql.*;
import java.util.*;
import org.genboree.util.Util;

public class Link
{
    protected boolean needs_update;
    public boolean needsUpdate() { return needs_update; }

    protected String linkId;
    public String getLinkId() { return linkId; }
    public void setLinkId( String linkId )
    {
        if( linkId == null ) linkId = "#";
        this.linkId = linkId;
    }
    protected String name;
    public String getName() { return name; }
    public void setName( String name )
    {
        this.name = name;
        needs_update = true;
    }
    protected String description;
    public String getDescription() { return description; }
    public void setDescription( String description )
    {
        this.description = description;
        needs_update = true;
    }

    public void clear()
    {
        linkId = "#";
        name = description = "";
        needs_update = false;
    }

    public Link()
    {
        clear();
    }

    public static Link[] fetchAll( DBAgent db ) throws SQLException {
        Connection conn = db.getConnection();
        if( conn == null ) return null;
        try
        {
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery(
              "SELECT linkId, name, description "+
              "FROM link ORDER BY name" );
            Vector v = new Vector();
            while( rs.next() )
            {
                Link l = new Link();
                l.setLinkId( rs.getString(1) );
                l.setName( rs.getString(2) );
                l.setDescription( Util.htmlUnQuote(rs.getString(3)) );
                l.needs_update = false;
                v.addElement( l );
            }
            stmt.close();
            Link[] rc = new Link[ v.size() ];
            v.copyInto( rc );
            return rc;
        } catch( Exception ex ) {
            db.reportError( ex, "Link.fetchAll()" );
        }
        return null;
    }

    public boolean fetch( DBAgent db ) throws SQLException {
        if( getLinkId().equals("#") ) return false;
        Connection conn = db.getConnection();
        if( conn == null ) return false;
        try
        {
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery(
              "SELECT linkId, name, description "+
              "FROM link WHERE linkId=" + getLinkId() );
            if( rs.next() )
            {
                setLinkId( rs.getString(1) );
                setName( rs.getString(2) );
                setDescription( Util.htmlUnQuote(rs.getString(3)) );
                needs_update = false;
                stmt.close();
                return true;
            }
            stmt.close();
        } catch( Exception ex ) {
            db.reportError( ex, "Link.fetch()" );
        }
        return false;
    }

    public String checkLinkName( DBAgent db ) throws SQLException {
        Connection conn = db.getConnection();
        if( conn == null ) return "No DB connection available";
        String myId = getLinkId();
        String linkName = getName();
        if( linkName == null ) linkName = "";
        if( linkName.trim().length() == 0 ) return "Link Name must not be empty";
        try
        {
            PreparedStatement pstmt = conn.prepareStatement(
              "SELECT linkId FROM link WHERE name=?" );
            pstmt.setString( 1, linkName );
            ResultSet rs = pstmt.executeQuery();
            String rc = null;
            if( rs.next() )
            {
                String herId = rs.getString(1);
                if( !herId.equals(myId) )
                  rc = "Another link with the same name ("+linkName+
                    ") exists. Please enter a different name and try again.";
            }
            pstmt.close();
            return rc;
        } catch( Exception ex ) {
            db.reportError( ex, "Link.checkLinkName()" );
        }
        return "Database error";
    }

    public boolean insert( DBAgent db ) throws SQLException {
        if( !getLinkId().equals("#") ) return false;
        Connection conn = db.getConnection();
        if( conn == null ) return false;
        int nrows = 0;
        try
        {
            PreparedStatement pstmt = conn.prepareStatement(
              "INSERT INTO link (name, description) VALUES (?,?)" );
            pstmt.setString( 1, getName() );
            pstmt.setString( 2, Util.htmlQuote(getDescription()) );
            nrows = pstmt.executeUpdate();
            if( nrows > 0 )
            {
                pstmt.close();
                pstmt = conn.prepareStatement(
                  "SELECT linkId FROM link WHERE name=?" );
                pstmt.setString( 1, getName() );
                ResultSet rs = pstmt.executeQuery();
                if( rs.next() )
                {
                    setLinkId( rs.getString(1) );
                    needs_update = false;
                }
                else nrows = 0;
            }
            pstmt.close();
        } catch( Exception ex ) {
            db.reportError( ex, "Link.insert()" );
        }
        return (nrows > 0);
    }

    public boolean update( DBAgent db ) throws SQLException {
        if( getLinkId().equals("#") ) return false;
        Connection conn = db.getConnection();
        if( conn == null ) return false;
        int nrows = 0;
        try
        {
            PreparedStatement pstmt = conn.prepareStatement(
              "UPDATE link SET name=?, description=? "+
              "WHERE linkId="+getLinkId() );
            pstmt.setString( 1, getName() );
            pstmt.setString( 2, Util.htmlQuote(getDescription()) );
            nrows = pstmt.executeUpdate();
            pstmt.close();
            needs_update = false;
        } catch( Exception ex ) {
            db.reportError( ex, "Link.update()" );
        }
        return (nrows > 0);
    }

    public boolean delete( DBAgent db ) throws SQLException {
        if( getLinkId().equals("#") ) return false;
        Connection conn = db.getConnection();
        if( conn == null ) return false;
        int nrows = 0;
        try
        {
            Statement stmt = conn.createStatement();
            stmt.executeUpdate( "DELETE FROM defaultlink WHERE linkId=" + getLinkId() );
            stmt.executeUpdate( "DELETE FROM userLink WHERE linkId=" + getLinkId() );
            nrows = stmt.executeUpdate( "DELETE FROM link WHERE linkId=" + getLinkId() );
            stmt.close();
            if( nrows > 0 ) clear();
        } catch( Exception ex ) {
            db.reportError( ex, "Link.delete()" );
        }
        return (nrows > 0);
    }

    public static Link[] linksNotInUse( DBAgent db, Link[] lnks ) throws SQLException {
        Link[] rc = new Link[0];
        Connection conn = db.getConnection();
        if( conn == null ) return rc;
        try
        {
            PreparedStatement ps1 = conn.prepareStatement(
              "SELECT COUNT(*) FROM defaultlink WHERE linkId=?" );
            PreparedStatement ps2 = conn.prepareStatement(
              "SELECT COUNT(*) FROM userlink WHERE linkId=?" );
            Vector v = new Vector();
            for( int i=0; i<lnks.length; i++ )
            {
                int cnt = 0;
                String cId = lnks[i].getLinkId();
                ps1.setString( 1, cId );
                ResultSet rs = ps1.executeQuery();
                if( rs.next() ) cnt = rs.getInt( 1 );
                ps2.setString( 1, cId );
                rs = ps2.executeQuery();
                if( rs.next() ) cnt += rs.getInt( 1 );
                if( cnt == 0 ) v.addElement( lnks[i] );
            }
            ps1.close();
            ps2.close();
            rc = new Link[ v.size() ];
            v.copyInto( rc );
            return rc;
        } catch( Exception ex ) {}
        return rc;
    }

    public static boolean removeNotInUse( DBAgent db, Link[] unused ) throws SQLException {
        Connection conn = db.getConnection();
        if( conn==null || unused==null ) return false;
        try
        {
            PreparedStatement pstmt = conn.prepareStatement(
              "DELETE FROM link WHERE linkId=?" );
            for( int i=0; i<unused.length; i++ )
            {
                pstmt.setString( 1, unused[i].getLinkId() );
                pstmt.executeUpdate();
            }
            pstmt.close();
            return true;
        } catch( Exception ex ) {}
        return false;
    }

}
