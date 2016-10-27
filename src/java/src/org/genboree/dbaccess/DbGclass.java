package org.genboree.dbaccess;

import org.genboree.util.GenboreeUtils;

import java.sql.*;
import java.util.Enumeration;
import java.util.Hashtable;
import java.util.Vector;

// ARJ REVIEW: Use spaces, not tabs. (This has a mix of tabs and spaces, which is worse.

public class DbGclass
{
    // ARJ REVIEW: Put a header for this section too, like you did for G&S below:
    /* Instance Variables */
	protected int gid = -1;
    protected String gclass = null;
    protected String[][] ftypes = null;
    protected boolean isEmpty = false;
    protected boolean isLocal = false;

    /* Setters and Getters */
    public boolean isLocal()
    {
        return isLocal;
    }
    public void setLocal(boolean local)
    {
        isLocal = local;
    }
	public int getGid()
    {
        return gid;
    }
	public void setGid( int gid )
    {
        this.gid = gid;
    }
	public String getGclass()
    {
        return gclass;
    }
	public void setGclass( String gclass )
    {
        this.gclass = gclass;
    }
    public boolean isEmpty()
    {
        return isEmpty;
    }
    public void setEmpty(boolean empty)
    {
        isEmpty = empty;
    }
    public String[][] getFtypes()
    {
        return ftypes;
    }




    public void setFtypes( DBAgent db, String myRefSeqId )
	{
        // ARJ REVIEW: In methods, avoid pre-declaring all the variables. It means too much scrolling to find the type
        //             and whether the variable is local to the method or not. Hurts maintainability.
        // ARJ REVIEW: Basically, if it is only used locally (within a few lines or with the next {} block), then declare it locally.
        // ARJ REVIEW: If it's used throught the method, then up here makes good sense.
        Connection conn = null;
        ResultSet rs = null;
        // ARJ REVIEW: Consider using the Java Collections Framework. It is faster. Shorter methods. Makes more sense.
        // ARJ REVIEW: Here, you would probably use HashMap not Hashtable.
        Hashtable htFtype = new Hashtable();
        String fmethod = null;
        String fsource = null;
        String ftypeKey = null;
        String ftype[] = null;
        int i = 0;
        Statement stmt = null;
        String qs = null;

        // ARJ REVIEW: Sanity checking like this is *good* and *required*
        // ARJ REVIEW: Make sure the user is informed that something went wrong?? (silent errors are a no-no)
        if(myRefSeqId == null || gid < 1)
        {
            System.err.println("Problem in the DbGclass the method setFtypes is getting empty values");
            System.err.println("The myRefSeqId parameter is " + myRefSeqId + " and the gid is " + gid );
            System.err.flush();
            return;
        }

        qs = "SELECT DISTINCT ftype.fmethod, ftype.fsource FROM ftype2gclass, ftype WHERE " +
                "ftype.ftypeid = ftype2gclass.ftypeid and ftype2gclass.gid = " + gid;

        String[] uploads = GenboreeUpload.returnDatabaseNames(db, myRefSeqId );
        try {
            for(i = 0; i < uploads.length; i++)
            {
                // ARJ REVIEW: Statement object created in a loop. Very Bad.
                // ARJ REVIEW: Create a PreparedStatement outside the loop, then bind variables to it with
                //             each iteration of the loop. It will make a Huge difference in longer loops.
                //             But for good coding practice and consistency, just do it for all loops.
                conn = db.getConnection( uploads[i] );
                stmt = conn.createStatement();
                rs = stmt.executeQuery( qs );
                while( rs.next() )
                {
                  // ARJ REVIEW: Let's not do this EVER:
                    fmethod = rs.getString(1);
                    fsource = rs.getString(2);
                  // ARJ REVIEW: The problem is that 1 and 2 are hard coded. They should be constants.
                  // ARJ REVIEW: For cases like this, you could easily justify some static final variables at
                  //             the top of the method or near the query (which determines the column order in the first place)
                    ftypeKey = fmethod + ":" + fsource;
                    ftype = new String[2];
                    htFtype.put( ftypeKey, ftype );
                }
            }

            ftypes = new String[htFtype.size()][2];
            int count = 0;
            // ARJ REVIEW: Use the Java Collections Framwork and the Iterator object. Here, you get the iter for the keySet().
            // ARJ REVIEW: short overview: http://www.particle.kth.se/~lindsey/JavaCourse/Book/Part1/Java/Chapter10/iterator.html
            for( Enumeration en=htFtype.keys(); en.hasMoreElements(); )
            {
                ftype = (String[]) htFtype.get( en.nextElement() );
                ftypes[count][0] = ftype[0];
                ftypes[count][1] = ftype[1];
                count++;
            }

		} catch( Exception ex ) {
            System.err.println("There has been an exception on DbGclass.setFtypesusing databaseName = " + uploads[i]);
            System.err.println("and the query is " + qs);
            System.err.flush();
        }
        finally
        {
		    return ;
        }
	}



   /* End of setters and getters */
   
    /* Why is this constructor only creating an empty class instead of initialize the values? */
	public DbGclass()
    {
    }
	public static DbGclass[] fetchAll( Connection conn )
	{
	  // ARJ REVIEW: *NO* single-char variable names. EVER.
		Vector v = new Vector();
        String  qs = "SELECT gid, gclass FROM gclass";
        Statement stmt = null;
        ResultSet rs = null;
        DbGclass[] rc = null;

		try
		{
			stmt = conn.createStatement();
			rs = stmt.executeQuery(qs);
			while( rs.next() )
			{
				DbGclass p = new DbGclass();
				// ARJ REVIEW: *NO* single-char variable names. EVER.
				p.setGid( rs.getInt(1) );
				p.setGclass( rs.getString(2) );
				v.addElement( p );
			}
			stmt.close();
            rc = new DbGclass[ v.size() ];
            v.copyInto( rc );
		} catch( Exception ex )
        {
            System.err.println("An exception has been caught in Class DbGclass method fetchAll");
            System.err.println("and query is " + qs);
            System.err.flush();
        }
        finally
        {
            return rc;
        }
	}
    /* This method is just and wrapper of the fetchGclasses don't need to create a list of databases */
    public static String[] fetchGClasses(DBAgent db, String _refSeqId, String fmethod, String fsource)
    {
       String uploads[] = null;
        String [] Gclasses = null;
        // ARJ REVIEW: *NO* variables starting with _. EVER. This is a stupid carry over from C and is not necessary with OOP
        if(_refSeqId == null || fmethod == null || fsource == null) return null;

        uploads = GenboreeUpload.returnDatabaseNames(db, _refSeqId );
        if(uploads != null)
            Gclasses = DbGclass.fetchGClasses(db, uploads, fmethod, fsource);

        return Gclasses;
    }
    /* This method is just for convenience  should be part of other class I need to moved may be to a static class?*/
    public static String[] fetchGClasses(DBAgent db, String[] uploads, String fmethod, String fsource)
    {
        Connection conn = null;
        ResultSet rs = null;
        String  qs = "SELECT distinct gclass.gclass from gclass, " +
                "ftype2gclass, ftype where gclass.gid = " +
                "ftype2gclass.gid AND ftype.ftypeid = ftype2gclass.ftypeid " +
                "AND ftype.fmethod = ? AND ftype.fsource = ?";
        Hashtable htGclass = new Hashtable();
        int i = 0;
        int a = 0;
        int ftypeId = -1;
        String listOfGclasses[] = null;
        PreparedStatement pstmt = null;
        boolean goNextDb = true;

        if(uploads == null || fmethod == null || fsource == null) return null;


        try {
            for(i = 0; i < uploads.length && goNextDb; i++)
            {
                ftypeId = GenboreeUtils.fetchFtypeId(db, uploads[i], fmethod, fsource);
                if(ftypeId > 0)
                {
                    conn = db.getConnection( uploads[i] );
                    pstmt = conn.prepareStatement( qs );
                    pstmt.setString( 1, fmethod );
                    pstmt.setString( 2, fsource );
                    rs = pstmt.executeQuery();

                    while( rs.next() )
                        // ARJ REVIEW: hard-coded again:
                        htGclass.put(rs.getString(1), rs.getString(1));

                    listOfGclasses = new String[htGclass.size()];
                    a = 0;
                    for( Enumeration en=htGclass.keys(); en.hasMoreElements(); )
                    {
                        listOfGclasses[a] = (String) htGclass.get( en.nextElement() );
                        a++;
                    }
                    if(listOfGclasses.length > 0)
                        break;
                }
            }
        } catch( Exception ex ) {
            System.err.println("There has been an exception on DbGclass#fetchGClasses using databaseName = " + uploads[i]);
            System.err.println("and the query is " + qs);
            System.err.flush();
        }
        finally
        {
            return listOfGclasses;
        }
    }
/* I need to analyse this method Why is not accepting the database name as a parameter Is used only by the nasty Refseq class */
	public boolean fetch( Connection conn )
	{
        String qs = null;
        Statement stmt = null;
        ResultSet rs = null;
        boolean rc = false;

        qs = "SELECT gclass FROM gclass WHERE gid="+getGid();
		try
		{
			stmt = conn.createStatement();
			rs = stmt.executeQuery( qs );
			rc = false;
			if( rs.next() )
			{
				setGclass( rs.getString(2) );
				rc = true;
			}
			stmt.close();
			return rc;
		} catch (SQLException e) {
                System.err.println("There has been an exception using databaseName = genboree");
                System.err.println("and the query is " + qs);
                System.err.flush();
        }
        finally
        {
            return rc;
        }
	}
/* I need to analyse this method Why is not accepting the database name as a parameter Is used only by the nasty Refseq class */
	public boolean insert( Connection conn)
	{
        String qs = null;
        PreparedStatement pstmt = null;
        boolean rc = false;

        qs = "INSERT INTO gclass (gclass) VALUES (?)";

		try
		{      
			pstmt = conn.prepareStatement( qs );
			pstmt.setString( 1, getGclass() );
			rc = (pstmt.executeUpdate() > 0);
            if( rc )
            {
                Statement stmt = conn.createStatement();
                ResultSet rs = stmt.executeQuery( "SELECT LAST_INSERT_ID()" );
                if( rs.next() ) setGid( rs.getInt(1) );
                stmt.close();
            } 
			pstmt.close();

        } catch (SQLException e) {
            System.err.println("There has been an exception using databaseName = genboree");
            System.err.println("and the query is " + qs);
            System.err.flush();
        }
        finally
        {
            return rc;
        }
	}
/* I need to analyse this method Why is not accepting the database name as a parameter Is used only by the nasty Refseq class */
	public boolean update( Connection conn )
	{
        String qs = null;
        PreparedStatement pstmt = null;
        boolean rc = false;

         if( gid < 1)
        {
            System.err.println("Problem in the DbGclass the method update is getting empty gid value");
            System.err.flush();
            return false;
        }

        qs = "UPDATE gclass SET gclass=? "+
                "WHERE gid= " + gid;
		try
		{
			pstmt = conn.prepareStatement( qs );
			// ARJ REVIEW: The Bind index should not be hard-coded either, really.
			//             Variable/constant declared near the query string is nice.
			pstmt.setString( 1, getGclass() );
			rc = (pstmt.executeUpdate() > 0);
			pstmt.close();
        } catch (SQLException e) {
            System.err.println("There has been an exception using databaseName = genboree");
            System.err.println("and the query is " + qs);
            System.err.flush();
        }
        finally
        {
            return rc;
        }
	}
/* I need to analyse this method Why is not accepting the database name as a parameter Is used only by the nasty Refseq class */
	public boolean delete( Connection conn )
	{
        String qs = null;
        Statement stmt = null;
        boolean rc = false;
        if( gid < 1)
        {
            System.err.println("Problem in the DbGclass the method update is getting empty gid value");
            System.err.flush();
            return false;
        }
        qs = "DELETE FROM gclass WHERE gid="+ gid;

		try
		{
			stmt = conn.createStatement();
			rc = (stmt.executeUpdate(qs) > 0);
			stmt.close();
        } catch (SQLException e) {
            System.err.println("There has been an exception using databaseName = genboree");
            System.err.println("and the query is " + qs);
            System.err.flush();
        }
        finally
        {
            return rc;
        }
	}
}
