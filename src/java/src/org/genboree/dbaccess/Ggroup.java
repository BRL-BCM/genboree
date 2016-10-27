package org.genboree.dbaccess;

import java.sql.*;
import java.util.*;

public class Ggroup
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
    protected String description;
    public String getDescription() { return description; }
    public void setDescription( String description ) { this.description = description; }

    public void clear()
    {
        id = "#";
        name = description = "";
    }

    public Ggroup()
    {
        clear();
    }

    public boolean fetch( DBAgent db ) throws SQLException {
        if( getId().equals("#") ) return false;
        Connection conn = db.getConnection();
        if( conn == null ) return false;
        try
        {
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery(
              "SELECT genboree_group_id, genboree_group_name, genboree_group_description "+
              "FROM genboree_group WHERE genboree_group_id=" + getId() );
            if( rs.next() )
            {
                setId( rs.getString(1) );
                setName( rs.getString(2) );
                setDescription( rs.getString(3) );
                stmt.close();
                return true;
            }
            stmt.close();
        } catch( Exception ex ) {
            db.reportError( ex, "Ggroup.fetch()" );
        }
        return false;
    }

    public static Ggroup[] fetchAll( DBAgent db ) throws SQLException {
        Connection conn = db.getConnection();
        if( conn == null ) return null;
        try
        {
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery(
              "SELECT genboree_group_id, genboree_group_name, genboree_group_description "+
              "FROM genboree_group ORDER BY genboree_group_name" );
            Vector v = new Vector();
            while( rs.next() )
            {
                Ggroup gr = new Ggroup();
                gr.setId( rs.getString(1) );
                gr.setName( rs.getString(2) );
                gr.setDescription( rs.getString(3) );
                v.addElement( gr );
            }
            stmt.close();
            Ggroup[] rc = new Ggroup[ v.size() ];
            v.copyInto( rc );
            return rc;
        } catch( Exception ex ) {
            db.reportError( ex, "Ggroup.fetchAll()" );
        }
        return null;
    }

}
