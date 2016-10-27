package org.genboree.dbaccess;

import org.genboree.manager.tracks.Utility;

import java.sql.*;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Vector;

public class DbLink implements Comparable
{
    private String  linkId;
    public String getLinkId() { return linkId; }
    public void setLinkId( String linkId ) { this.linkId = linkId; }

    protected String name;
    public String getName() { return name; }
    public void setName( String name ) { this.name = name; }

    protected String description;
    public String getDescription() { return description; }
    public void setDescription( String description ) { this.description = description; }

    private boolean fromShareDb;
    public boolean  getFromShareDb() {return fromShareDb;}
    public void setFromShareDb(boolean b) {fromShareDb = b;}



    public int compareTo( Object o )
    {
        String s1 = getName();
        if( s1 == null ) s1 = "";
        String s2 = ((DbLink)o).getName();
        if( s2 == null ) s2 = "";
        return s1.compareTo( s2 );
    }

    public DbLink() {}

    public static DbLink[] mergeLinks(DbLink[] linksMain, DbLink[] linksShare)
    {
        if (linksShare == null || linksShare.length < 1)
        {
             if(linksMain != null && linksMain.length>0)
                    Arrays.sort(linksMain);
            return linksMain;
        }

        if (linksMain == null || linksMain.length < 1)
        {
              if(linksShare != null && linksShare.length>0)
                    Arrays.sort(linksShare);
            return linksShare;
        }


      HashMap  h = new HashMap();
      for (int i=0; i<linksMain.length; i++) {
                    if (h.get(linksMain[i].getLinkId() )== null)
                   h.put(linksMain[i].getLinkId(), linksMain[i]);
               }

        ArrayList shareOnly  = new ArrayList ();
        for (int i = 0; i < linksShare.length; i++) {
           if (h.get(linksShare[i].getLinkId())== null){
            h.put(linksShare[i].getLinkId(), linksShare[i]);
            shareOnly.add(linksShare[i]);
           }
        }



        int n = h.size();
        DbLink [] all = new DbLink[n];
        for (int j = 0; j <shareOnly.size(); j++)
            all[ j] = (DbLink)shareOnly.get(j);

        int i =0;
        int index = shareOnly.size();
        for ( i =0; i<linksMain.length; i++)
               all[index + i] = linksMain[i];
       
     return  all;
    }


    public boolean fetch( Connection conn )
    {
        try
        {
            String qs = "SELECT name, description FROM link WHERE linkId = '"+getLinkId() + "'";
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery( qs );
            boolean rc = false;
            if( rs.next() )
            {

                setName( rs.getString(1) );
                setDescription( rs.getString(2) );
                rc = true;
            }
            stmt.close();
            return rc;
        } catch( Exception ex ) {}
        return false;
    }

    public boolean  insert( Connection conn )
    {
        boolean b = false;
        try
        {
            String qs = "INSERT INTO link (name, description, linkId) VALUES (?, ?, ?)";
            PreparedStatement pstmt = conn.prepareStatement( qs );
            pstmt.setString( 1, getName() );
            pstmt.setString( 2, getDescription() );
            pstmt.setString( 3, Utility.generateMD5(getName() + ":" + getDescription()));
            b = (pstmt.executeUpdate() >0);
            pstmt.close();
        }
        catch( Exception ex ) {
          ex.printStackTrace();
        }
        return b;
    }



    public boolean insert(Connection conn, String name, String desc, String linkmd5)
    {
    	  boolean b = false;
        try {
            String qs = "INSERT INTO link (name, description, linkId) VALUES (?, ?, ?)";
            PreparedStatement pstmt = conn.prepareStatement(qs);
            pstmt.setString(1, getName());
            pstmt.setString(2, getDescription());
            pstmt.setString(3, linkmd5);

            b = (pstmt.executeUpdate() >0);
            pstmt.close();

        } catch (Exception ex) {
            ex.printStackTrace();
        }
        return b;
    }

    public  boolean update( Connection conn , String name, String desc, String linkmd5, DBAgent db )
    {
        try
        {
            String qs = "UPDATE link SET name = ? , description = ? WHERE linkId  = ? ";
            System.out.println (qs);
            PreparedStatement pstmt = conn.prepareStatement( qs );
            pstmt.setString( 1, name );
            pstmt.setString( 2, desc );
            pstmt.setString( 3, linkmd5 );
            boolean rc = (pstmt.executeUpdate() > 0);
            pstmt.close();
            return rc;
        } catch( Exception ex ) {
           db.reportError(ex, "DBlink.update()");
        }
        return false;
    }


    public boolean update( Connection conn )
    {
        try
        {
            String qs = "UPDATE link SET name = ?, description = ? WHERE linkId = ? ";
            PreparedStatement pstmt = conn.prepareStatement( qs );
            pstmt.setString( 1, getName() );
            pstmt.setString( 2, getDescription() );
            pstmt.setString( 3, getLinkId() ) ;
            boolean rc = (pstmt.executeUpdate() > 0);
            pstmt.close();
            return rc;
        } catch( Exception ex ) {}
        return false;
    }

    public boolean delete( Connection conn )
    {
        try
        {
            String qs = "DELETE FROM link WHERE linkId = '"+getLinkId() + "'";
            Statement stmt = conn.createStatement();
            boolean rc = (stmt.executeUpdate(qs) > 0);
            if( rc )
            {
                stmt.executeUpdate( "DELETE FROM featuretolink WHERE linkId='" + getLinkId() + "'" );
            }
            stmt.close();
            return rc;
        } catch( Exception ex ) {}
        return false;
    }

    public static int deleteLinks( Connection conn, String[] lnkIds )
    {
        if( lnkIds==null || lnkIds.length==0 ) return 0;
        try
        {

            String lst =  "'" + lnkIds[0] + "', ";

            for(int i=1; i<lnkIds.length; i++ )
                 lst = lst + " '" + lnkIds[i] + "', ";
            lst = lst.substring(0, lst.lastIndexOf(','));

            Statement stmt = conn.createStatement();
            stmt.executeUpdate( "DELETE FROM featuretolink WHERE linkId IN ("+lst+")" );
            int rc = stmt.executeUpdate( "DELETE FROM link WHERE linkId IN ("+lst+")" );
            stmt.close();
            return rc;
        } catch( Exception ex ) {}
        return 0;
    }


    /**
     * retrieves link information fro share database
     * @param localDBName
     * @param dbNames     String [] of all database names
     * @param db          DBAgent

     * @return links of DbLinks.
     */
    public static DbLink[] fetchShareLinks( String localDBName, String [] dbNames, DBAgent db )
        {
            DbLink []links = null;
            String dbName = null;
            Vector v = new Vector ();
            try
            {
                String qs = "SELECT name, description, linkId FROM link";
                for (int i =0; i<dbNames.length; i++) {

                   if (dbNames[i].compareToIgnoreCase(localDBName) ==0)
                       continue;
                 Connection con = db.getConnection(dbNames[i]) ;
                 if (con == null)
                    throw new SQLException (" fail in making connection with database "  + dbName);

                Statement stmt = con.createStatement();
                ResultSet rs = stmt.executeQuery( qs );
                while( rs.next() )
                {
                    DbLink p = new DbLink();
                    p.setName(rs.getString(1));
                    p.setDescription(rs.getString(2));

                    p.setLinkId(rs.getString(3));
                    p.setFromShareDb(true);
                    if (!v.contains(p))
                    v.addElement( p );
                }
                stmt.close();
                }
            } catch( Exception ex ) {
               System.out.println(ex.getMessage()
              );          ex.printStackTrace();

            }
           links = new DbLink[ v.size() ];
           v.copyInto(  links );

            return  links;
    }
    public static DbLink[] fetchAll( Connection conn, boolean isShareDb )
        {

            Vector v = new Vector();
            try
            {
                  if(conn.isClosed())
                  System.out.println ("con closed ");

                String qs = "SELECT name, description, linkId FROM link";
                Statement stmt = conn.createStatement();
                ResultSet rs = stmt.executeQuery( qs );
                while( rs.next() )
                {
                    DbLink link = new DbLink();
                    //link.setLinkId( rs.getInt(1) );
                link.setName( rs.getString(1) );
                    link.setDescription( rs.getString(2) );
                    link.setLinkId( rs.getString(3) );
                    link.setFromShareDb(isShareDb);
                    v.addElement( link );
                }

                stmt.close();
            } catch( Exception ex ) {ex.printStackTrace();}
            DbLink[] rc = new DbLink[ v.size() ];
            v.copyInto( rc );
            return rc;
        }


    public static void main (String [] args) {
         String s = "1";
         String [] s2 = new String [] {"genboree_r_a6127b8fd3939f3b6f157e06ae2e562b"};
       //DbLink[] links =   fetchShareLinks(s, s2,  DBAgent.getInstance() );
        DBAgent db = DBAgent.getInstance();

        try {
         Connection con = db.getConnection(s2[0]) ;
            //fetchAll(con, false);
           new DbLink().update(con, "my test",  "www.yahoo.com", "62a3ed90c3eb7f8c9204779c2d538bf0",  db);

        }

        catch (Exception e) {
            e.printStackTrace();
        }



    }


}
