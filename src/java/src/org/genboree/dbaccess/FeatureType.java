package org.genboree.dbaccess;

import java.sql.*;
import java.util.*;

public class FeatureType
{
    protected String featureTypeId;
    public String getFeatureTypeId() { return featureTypeId; }
    public void setFeatureTypeId( String featureTypeId )
    {
        if( featureTypeId == null ) featureTypeId = "#";
        this.featureTypeId = featureTypeId;
    }
    protected String name;
    public String getName() { return name; }
    public void setName( String name ) { this.name = name; }
    protected String description;
    public String getDescription() { return description; }
    public void setDescription( String description ) { this.description = description; }

    protected Link defaultLink;
    public Link getDefaultLink() { return defaultLink; }

    protected Link[] userLinks;
    public Link[] getUserLinks() { return userLinks; }
    public void setUserLinks( Link[] userLinks )
    {
        if( userLinks == null )
        {
            userLinks = new Link[0];
        }
        else
        {
			Vector v = new Vector();
			for( int i=0; i<userLinks.length; i++ )
				if( !isDefault( userLinks[i].getLinkId() ) )
					v.addElement( userLinks[i] );
			userLinks = new Link[ v.size() ];
			v.copyInto( userLinks );
        }
        this.userLinks = userLinks;
    }
    public boolean isDefault( String linkId )
    {
        Link lnk = getDefaultLink();
        if( lnk == null ) return false;
        return lnk.getLinkId().equals(linkId);
    }

    protected String userId;
    public String getUserId() { return userId; }
    public void setUserId( String userId ) { this.userId = userId; }

    public void clear()
    {
        featureTypeId = "#";
        name = description = "";
        defaultLink = null;
        userLinks = new Link[0];
        linkIds = new String[0];
    }

    public FeatureType()
    {
        clear();
    }

    public static FeatureType[] fetchAll( DBAgent db ) throws SQLException {
        Connection conn = db.getConnection();
        if( conn == null ) return null;
        try
        {
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery(
              "SELECT featureTypeId, name, description "+
              "FROM featuretype ORDER BY name" );
            Vector v = new Vector();
            while( rs.next() )
            {
                FeatureType ft = new FeatureType();
                ft.setFeatureTypeId( rs.getString(1) );
                ft.setName( rs.getString(2) );
                ft.setDescription( rs.getString(3) );
                v.addElement( ft );
            }
            stmt.close();
            FeatureType[] rc = new FeatureType[ v.size() ];
            v.copyInto( rc );
            return rc;
        } catch( Exception ex ) {
            db.reportError( ex, "FeatureType.fetchAll()" );
        }
        return null;
    }

    public boolean fetch( DBAgent db ) throws SQLException {
        if( getFeatureTypeId().equals("#") ) return false;
        Connection conn = db.getConnection();
        if( conn == null ) return false;
        try
        {
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery(
              "SELECT featureTypeId, name, description "+
              "FROM featuretype WHERE featureTypeId=" + getFeatureTypeId() );
            if( rs.next() )
            {
                setFeatureTypeId( rs.getString(1) );
                setName( rs.getString(2) );
                setDescription( rs.getString(3) );
                stmt.close();
                return true;
            }
            stmt.close();
        } catch( Exception ex ) {
            db.reportError( ex, "FeatureType.fetch()" );
        }
        return false;
    }


    protected String[] linkIds = new String[0];
    public boolean isAssigned( String linkId )
    {
        for( int i=0; i<linkIds.length; i++ )
            if( linkIds[i].equals(linkId) ) return true;
        return false;
    }

    public boolean fetchLinkIds( DBAgent db ) throws SQLException {
        if( getFeatureTypeId().equals("#") ) return false;
        Connection conn = db.getConnection();
        if( conn != null ) try
        {
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery(
                "SELECT linkId FROM defaultlink WHERE featureTypeId="+getFeatureTypeId() );
            Vector v = new Vector();
            while( rs.next() )
            {
                v.addElement( rs.getString(1) );
            }
            linkIds = new String[ v.size() ];
            v.copyInto( linkIds );
            stmt.close();
            return true;
        } catch( Exception ex ) {
            db.reportError( ex, "FeatureType.fetchLinkIds()" );
        }
        return false;
    }

    public boolean updateLinkIds( DBAgent db, String[] newLinkIds ) throws SQLException {
        if( getFeatureTypeId().equals("#") ) return false;
        Connection conn = db.getConnection();
        if( conn != null ) try
        {
            Statement stmt = conn.createStatement();
            stmt.executeUpdate( "DELETE FROM defaultlink WHERE featureTypeId="+getFeatureTypeId() );
            stmt.close();
            linkIds = new String[0];
            if( newLinkIds == null ) newLinkIds = linkIds;
            PreparedStatement pstmt = conn.prepareStatement(
                "INSERT INTO defaultlink (featureTypeId, linkId) "+
                "VALUES ("+getFeatureTypeId()+", ?)" );
            for( int i=0; i<newLinkIds.length; i++ )
            {
                pstmt.setString( 1, newLinkIds[i] );
                pstmt.executeUpdate();
            }
            pstmt.close();
            linkIds = newLinkIds;
            return true;
        } catch( Exception ex ) {
            db.reportError( ex, "FeatureType.updateLinkIds()" );
        }
        return false;
    }



    public boolean updateDefaultLink( DBAgent db, Link lnk ) throws SQLException {
        if( getFeatureTypeId().equals("#") ) return false;
        Connection conn = db.getConnection();
        if( conn == null ) return false;
        try
        {
            Statement stmt = conn.createStatement();
            stmt.executeUpdate( "DELETE FROM defaultlink WHERE featureTypeId="+getFeatureTypeId() );
            if( lnk != null && !lnk.getLinkId().equals("#") )
            {
                stmt.executeUpdate( "INSERT INTO defaultlink(featureTypeId, linkId) "+
                  "VALUES("+getFeatureTypeId()+", "+lnk.getLinkId()+")" );
            }
            defaultLink = lnk;
            stmt.close();
            return true;
        } catch( Exception ex ) {
            db.reportError( ex, "FeatureType.updateDefaultLink()" );
        }
        return false;
    }

    public boolean fetchUserLinks( DBAgent db ) throws SQLException {
        if( getFeatureTypeId().equals("#") ) return false;
        Connection conn = db.getConnection();
        if( conn == null ) return false;
        try
        {
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery(
              "SELECT ln.linkId, ln.name, ln.description "+
              "FROM link ln, userlink ul "+
              "WHERE ul.linkId=ln.linkId AND ul.userId="+getUserId()+
              " AND ul.featureTypeId="+getFeatureTypeId() );
            Vector v = new Vector();
            while( rs.next() )
            {
                Link ln = new Link();
                ln.setLinkId( rs.getString(1) );
                ln.setName( rs.getString(2) );
                ln.setDescription( rs.getString(3) );
                v.addElement( ln );
            }
            stmt.close();
            userLinks = new Link[ v.size() ];
            v.copyInto( userLinks );
            return true;
        } catch( Exception ex ) {
            db.reportError( ex, "FeatureType.fetchUserLinks()" );
        }
        return false;
    }

    public boolean updateUserLinks( DBAgent db ) throws SQLException {
        if( getFeatureTypeId().equals("#") ) return false;
        Connection conn = db.getConnection();
        if( conn == null ) return false;
        try
        {
            Statement stmt = conn.createStatement();
            stmt.executeUpdate( "DELETE FROM userlink WHERE userId="+getUserId()+
              " AND featureTypeId="+getFeatureTypeId() );
            stmt.close();
            PreparedStatement pstmt = conn.prepareStatement(
              "INSERT INTO userlink(featureTypeId,userId,linkId) " +
              "VALUES(" + getFeatureTypeId() + "," + getUserId() + ",?)" );
            for( int i=0; i<userLinks.length; i++ )
            {
                pstmt.setString( 1, userLinks[i].getLinkId() );
                pstmt.executeUpdate();
            }
            pstmt.close();
            return true;
        } catch( Exception ex ) {
            db.reportError( ex, "FeatureType.updateUserLinks()" );
        }
        return false;
    }

}
