package org.genboree.dbaccess ;

import java.io.* ;
import java.security.MessageDigest ;
import java.sql.* ;
import java.util.* ;
import org.genboree.util.* ;
import org.genboree.upload.* ;
import org.genboree.dbaccess.util.* ;

public class Refseq   implements RefSeqParams , SQLCreateTable
{
    protected String refSeqId;
    protected String userId;
    protected String refseqName;
    protected String refseq_species;
    protected String refseq_version;
    protected String description;
    protected String FK_genomeTemplate_id;
    protected String mapmaster;
    protected String merged;
    protected String fastaDir;
    protected String databaseName;
    protected String [] nameShareDatabases;
    protected static final String __acs_codes = "rwo";
    protected String[] frDbNames;
    protected String[] frTables;
    protected int frCurDb;
    protected int frCurTable;
    protected String frQs0;
    protected String frQs1;
    protected String frQs2;
    protected String frTrackFilter;
    protected String frEntryPointId;
    protected Hashtable frTracks;
    protected Hashtable frLinkHash;
    protected File deflineFile = null;
    protected File seqFile = null;
    protected GenboreeUpload rootUpload = null;
    protected int curLine = 0;
    protected int numRecords = 0;
    protected boolean first_line = true;
    protected String currSect = "annotations";
    protected String[] metaData = metaAnnotations;
    protected Vector errs = new Vector();
    boolean is_error = false;
    protected DBAgent _db = null;
    protected Connection _conn;
    protected Connection _upldConn;
    protected PreparedStatement currPstmt;
    protected PreparedStatement currPstmtCV;
    protected PreparedStatement currPstmtGV;
    protected PreparedStatement currPstmtSeq;
    protected PreparedStatement getTextStatement;
    protected Statement currStmtFid;
    protected long minFbin = 1000L;
    protected long maxFbin = 100000000L;
    protected Hashtable htGclass;
    protected Hashtable htFref;
    protected Hashtable htFtype;
    protected Vector vFtype;
    protected boolean byPassClassName = false;
    protected String nameNewClass = null;
    protected String[] newFtypes = new String[0];
    protected Hashtable htFtypeGclass;
    protected boolean ignore_refseq = false;
    protected boolean ignore_assembly = false;
    protected boolean ignore_annotations = false;
    protected Hashtable gclass2ftypesHash;
    protected Hashtable featureTypeToGclasses;


    public Refseq()
    {
        clear();
    }
    protected static class StyleNameComparator
        implements Comparator
    {
        public int compare( Object o1, Object o2 )
        {
            Style s1 = (Style) o1;
            Style s2 = (Style) o2;
            String d1 = s1.description;
            if( Util.isEmpty(d1) ) d1 = s1.name;
            String d2 = s2.description;
            if( Util.isEmpty(d2) ) d2 = s2.name;
            return d1.compareToIgnoreCase( d2 );
        }
    }
    public String getRefSeqId()
    {
        return refSeqId;
    }
    public void setRefSeqId( String refSeqId )
    {
        if( refSeqId == null ) refSeqId = "#";
        this.refSeqId = refSeqId;
    }
    public String getUserId()
    {
        return userId;
    }
    public void setByPassClassName(boolean byPass)
    {
        byPassClassName = byPass;
    }
    public boolean getByPassClassName()
    {
        return byPassClassName;
    }
    public void setNameNewClass(String newClassName)
    {
        nameNewClass = newClassName;
    }
    public String getNameNewClass()
    {
        return  nameNewClass;
    }
    public void setUserId( String userId )
    {
        if( userId == null || userId.equals("#") ) userId = "1";
        this.userId = userId;
    }
    public String getRefseqName()
    {
        return refseqName;
    }
    public void setNameShareDatabases(DBAgent db ) throws SQLException
    {
        nameShareDatabases = fetchDatabaseNames(db);
    }
    public String [] getNameShareDatabases()
    {
        return nameShareDatabases;
    }
    public void setRefseqName( String refseqName )
    {
        this.refseqName = refseqName;
    }
    public String getRefseq_species()
    {
        return refseq_species;
    }
    public void setRefseq_species( String refseq_species )
    {
        this.refseq_species = refseq_species;
    }
    public String getRefseq_version()
    {
        return refseq_version;
    }
    public void setRefseq_version( String refseq_version )
    {
        this.refseq_version = refseq_version;
    }
    public String getDescription()
    {
        return description;
    }
    public void setDescription( String description )
    {
        this.description = description;
    }
    public String getFK_genomeTemplate_id()
    {
        return FK_genomeTemplate_id;
    }
    public void setFK_genomeTemplate_id( String FK_genomeTemplate_id )
    {
        this.FK_genomeTemplate_id = FK_genomeTemplate_id;
    }
    public String getMapmaster()
    {
        return mapmaster;
    }
    public void setMapmaster( String mapmaster )
    {
        this.mapmaster = mapmaster;
    }
    public String getDatabaseName()
    {
        return databaseName;
    }
    public void setDatabaseName( String databaseName )
    {
        this.databaseName = databaseName;
    }
    public String getFastaDir()
    {
        return fastaDir;
    }
    public void setFastaDir( String fastaDir )
    {
        this.fastaDir = fastaDir;
    }
	public String getMerged()
    {
        return merged;
    }
	public void setMerged( String merged )
    {
        this.merged = merged;
    }
    public boolean isMerged()
    {
        if( Util.isEmpty(merged) ) return false;
        return merged.equals("y");
    }
    public void setMerged( boolean is_merged )
    {
        merged = is_merged ? "y" : "n";
    }
    public void clear()
    {
        refSeqId = "#";
        userId = "1";
        merged="n";
        refseqName = description = mapmaster = databaseName = fastaDir = "";
        refseq_species = refseq_version = "";
        FK_genomeTemplate_id = null;
        gclass2ftypesHash = null;
        featureTypeToGclasses = null;
    }
    public String getScreenName()
    {
        String rn = getRefseqName();
        if( rn == null ) rn = "";
        String sn = getDescription();
        if( sn == null ) sn = "";
        else sn = sn.trim();
        if( sn.length() > 0 ) return sn;
        return rn;
    }
    public static Refseq[] fetchAll( DBAgent db ) throws SQLException
    {
        return fetchAll( db, null );
    }
    public static String fetchRootId( DBAgent db, String myRefSeqId )
    {
        String rootUploadId = null;
        Connection conn = null;
        try
        {
            conn = db.getConnection();
        }
        catch( Exception ex )
        {
            db.reportError( ex, "Refseq.fetch()" );
        }
        if( conn == null ) return null;
        try
        {
            String qs = "SELECT u.uploadId FROM upload u, refseq2upload ru, refseq r " +
                    "WHERE r.refSeqId=ru.refSeqId AND u.uploadId=ru.uploadId AND " +
                    "r.databaseName=u.databaseName && ru.refSeqId="+ myRefSeqId ;
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery( qs );
            if( rs.next() )
            {
                rootUploadId = rs.getString(1);
            }
            stmt.close();
        } catch( Exception ex )
        {
            db.reportError( ex, "Refseq.fetch()" );
        }
        return rootUploadId;
    }

    public static Refseq[] fetchAll( DBAgent db, GenboreeGroup[] grps ) throws SQLException
    {
        Connection conn = db.getConnection();
        if( conn == null ) return null;
        try
        {
            String qs = "SELECT refSeqId, userId, refseqName, description, "+
                        "mapmaster, databaseName, fastaDir, "+
                        "refseq_species, refseq_version, FK_genomeTemplate_id, "+
                        "merged "+
                        "FROM refseq ORDER BY refseqName";
            if( grps != null )
            {
                if( grps.length == 0 ) return new Refseq[0];
                String incl = grps[0].getGroupId();
                for( int i=1; i<grps.length; i++ )
                {
                    incl = incl + "," + grps[i].getGroupId();
                }
                qs = "SELECT distinct rs.refSeqId, rs.userId, rs.refseqName, "+
                        "rs.description, rs.mapmaster, rs.databaseName, rs.fastaDir, "+
                        "rs.refseq_species, rs.refseq_version, rs.FK_genomeTemplate_id, "+
                        "rs.merged "+
                        "FROM refseq rs, grouprefseq gr "+
                        "WHERE rs.refSeqId=gr.refSeqId AND gr.groupId IN ("+incl+") "+
                        "ORDER BY rs.refseqName";
            }
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery( qs );
            Vector v = new Vector();
            while( rs.next() )
            {
                Refseq r = new Refseq();
                r.setRefSeqId( rs.getString(1) );
                r.setUserId( rs.getString(2) );
                r.setRefseqName( rs.getString(3) );
                r.setDescription( rs.getString(4) );
                r.setMapmaster( rs.getString(5) );
                r.setDatabaseName( rs.getString(6) );
                r.setFastaDir( rs.getString(7) );
                r.setRefseq_species( rs.getString(8) );
                r.setRefseq_version( rs.getString(9) );
                r.setFK_genomeTemplate_id( rs.getString(10) );
                r.setMerged( rs.getString(11) );
                v.addElement( r );
            }
            stmt.close();
            Refseq[] rc = new Refseq[ v.size() ];
            v.copyInto( rc );
            return rc;
        } catch( Exception ex ) {
            db.reportError( ex, "Refseq.fetchAll()" );
        }
        return null;
    }
	public boolean fetch( DBAgent db, String dbName ) throws SQLException
    {
		Connection conn = db.getConnection();
		if( getRefSeqId().equals("#") && dbName==null ) return false;
		if( conn != null ) try
		{
			String qs = "SELECT userId, refseqName, description, mapmaster, "+
			    "databaseName, fastaDir, "+
                "refseq_species, refseq_version, FK_genomeTemplate_id, "+
                "merged, refSeqId FROM refseq WHERE ";
            qs = qs + ((dbName == null) ? "refSeqId="+getRefSeqId() :
                "databaseName='"+dbName+"'");
			PreparedStatement pstmt = conn.prepareStatement( qs );
			ResultSet rs = pstmt.executeQuery();
			boolean rc = false;
			if( rs.next() )
			{

				setUserId( rs.getString(1) );
				setRefseqName( rs.getString(2) );
				setDescription( rs.getString(3) );
				setMapmaster( rs.getString(4) );
				setDatabaseName( rs.getString(5) );
				setFastaDir( rs.getString(6) );
                setRefseq_species( rs.getString(7) );
                setRefseq_version( rs.getString(8) );
                setFK_genomeTemplate_id( rs.getString(9) );
                setMerged( rs.getString(10) );
                setRefSeqId( rs.getString(11) );
				rc = true;
			}
			pstmt.close();
			return rc;
		} catch( Exception ex )
		{
			db.reportError( ex, "Refseq.fetch()" );
		}
		return false;
	}
	public boolean fetch( DBAgent db ) throws SQLException
    {
	    return fetch( db, null );
	}

  // ARJ:
  // Refseq.isPublished() : is the database given by refSeqId published (a.k.a. isPublic/isPublished database)
  public static boolean isPublished( DBAgent db, String refSeqId )
  {
    boolean retVal = false ;
    String qs = null ;
    try
    {
      Connection conn = db.getConnection();
      qs = "SELECT grouprefseq.groupRefSeqId from genboreegroup, grouprefseq where " +
                  "grouprefseq.groupId = genboreegroup.groupId and " +
                  "genboreegroup.groupName = 'Public' and grouprefseq.refseqid = ? " ;
      PreparedStatement pstmt = conn.prepareStatement( qs );
      pstmt.setString( 1, refSeqId );
      ResultSet rs = pstmt.executeQuery();
      rs.last() ; // jump to last row
      int count = rs.getRow() ; // get index of last row...it is the count (because 1-based)
      retVal = (count >= 1) ;
    }
    catch( Exception ex )
    {
      System.err.println("ERROR: Refseq.isPublished() => Determine if refSeq '" + refSeqId + "' is published or not had query failure");
      System.err.println("       Query: " + qs);
      System.err.println("       Error message: " + ex.getMessage()) ;
      ex.printStackTrace(System.err) ;
      retVal = false ;
    }
    return retVal ;
	}

	public static String fetchUserAccess( DBAgent db, String dbName, String userId ) throws SQLException
    {
		Connection conn = db.getConnection();
		if( conn != null ) try
		{
	        String qs = userId.equals("0") ?
	        "SELECT 'r' FROM genboreegroup g, grouprefseq gr, refseq r "+
            "WHERE g.groupName='Public' AND g.groupId=gr.groupId AND gr.refSeqId=r.refSeqId "+
            "AND r.databaseName='"+dbName+"'" :
	        "SELECT ug.userGroupAccess FROM usergroup ug, grouprefseq gr, refseq r "+
            "WHERE ug.userId="+userId+" AND ug.groupId=gr.groupId AND gr.refSeqId=r.refSeqId "+
            "AND r.databaseName='"+dbName+"'";
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery( qs );
            int idx = -1;
            while( rs.next() )
            {
                String s = rs.getString(1);
                if( s == null ) continue;
                int idx1 = __acs_codes.indexOf( s );
                if( idx < idx1 ) idx = idx1;
            }
            stmt.close();
            if( idx < 0 ) return null;
            return __acs_codes.substring( idx, idx+1 );
        }
        catch( Exception ex ) {}
        return null;
	}

	public boolean update( DBAgent db ) throws SQLException
    {
		Connection conn = db.getConnection();
		if( conn != null ) try
		{
			String qs = "UPDATE refseq SET userId=?, refseqName=?, "+
			    "refseq_species=?, refseq_version=?, description=?, "+
			    "FK_genomeTemplate_id=?, mapmaster=?, databaseName=?, "+
			    "fastaDir=?, merged=? "+
				"WHERE refSeqId="+getRefSeqId();
			PreparedStatement pstmt = conn.prepareStatement( qs );
			pstmt.setString( 1, getUserId() );
			pstmt.setString( 2, getRefseqName() );
			pstmt.setString( 3, getRefseq_species() );
			pstmt.setString( 4, getRefseq_version() );
			pstmt.setString( 5, getDescription() );
			pstmt.setString( 6, getFK_genomeTemplate_id() );
			pstmt.setString( 7, getMapmaster() );
			pstmt.setString( 8, getDatabaseName() );
			pstmt.setString( 9, getFastaDir() );
			pstmt.setString( 10, getMerged() );
			boolean rc = (pstmt.executeUpdate() > 0);
			pstmt.close();
			return rc;
		} catch( Exception ex )
		{
			db.reportError( ex, "Refseq.update()" );
		}
		return false;
	}

    public static String deleteRids( DBAgent db, String databaseName, HashMap deleteFrefs)
    {
        String deleteINFref = null;
        String deleteINFDATA2 = null;
        String deleteINFDATA2CV = null;
        String deleteINFDATA2GV = null;
        String deleteQuery = "WHERE rid in (";
        String deleteQueryEnd = ")";
        Connection conn =  null;
        Statement stmt = null;
        String ftypeids = null;
        String frefIds = null;

        frefIds = GenboreeUtils.getCommaSeparatedKeys( deleteFrefs );

        deleteINFref = "DELETE FROM fref " + deleteQuery + frefIds + deleteQueryEnd;
        deleteINFDATA2 = "DELETE FROM fdata2 " + deleteQuery + frefIds + deleteQueryEnd;
        deleteINFDATA2CV = "DELETE FROM fdata2_cv " + deleteQuery + frefIds + deleteQueryEnd;
        deleteINFDATA2GV = "DELETE FROM fdata2_gv " + deleteQuery + frefIds + deleteQueryEnd;

        try
        {
            conn =  db.getConnection(databaseName);
            ftypeids = GenboreeUtils.getFtypeIdsFromRids(conn, frefIds);

            stmt = conn.createStatement();
            stmt.executeUpdate( deleteINFref );
            stmt.executeUpdate( deleteINFDATA2 );
            stmt.executeUpdate( deleteINFDATA2CV );
            stmt.executeUpdate( deleteINFDATA2GV );
            AnnotationCounter.updateCountTableUsingTrackIds( conn,  ftypeids );

            db.safelyCleanup( null, stmt, conn );
            return ftypeids ;
        } catch( Exception ex )
        {
          System.err.println("Error in Refseq::deleteRids");
           ex.printStackTrace( System.err );
        }

        return null;
    }

  // Delete this user database from Genboree entirely.
	public boolean delete(DBAgent db) throws SQLException
  {
    boolean retVal = false ;
      System.err.println("Refseq::delete DROPING DB " + databaseName + " DELETION time: " + (new java.util.Date()).toString());
        Connection conn = db.getConnection() ;
		if(getRefSeqId().equals("#"))
    {
      retVal = false ;
    }
    else
    {
      if(conn != null)
      {
        try
        {
          // Delete the annotationDataFiles directories
          // There may be multiple groups linked to the refseq, delete them all
          try // This might fail. Continue operation, but log it.
          {
            File[] annoDirFileArr = fetchAnnotationDataFilesDirs(db) ;
            if(annoDirFileArr != null && annoDirFileArr.length > 0)
            {
              for( int i=0; i<annoDirFileArr.length; i++ )
              {
                FileKiller.clearDirectory(annoDirFileArr[i]) ;
                annoDirFileArr[i].delete() ;
              }
            }
          }
          catch(Exception ex)
          {
            System.err.println("ERROR: Refseq.delete(D) => Failed to clear out annotationDataFile dir when deleting this refseq from Genboree. Details: " + ex.getMessage()) ;
            ex.printStackTrace(System.err) ;
          }

          try // This might fail. Continue operation, but log it.
          {
            File seqDir = fetchSequenceDir(db) ;
            if(seqDir != null)
            {
              FileKiller.clearDirectory(seqDir) ;
              seqDir.delete() ;
            }
            CacheManager.removeCacheDir(this) ;
          }
          catch(Exception ex)
          {
            System.err.println("ERROR: Refseq.delete(D) => Failed to clear out sequence dir when deleting this refseq from Genboree. Details: " + ex.getMessage()) ;
            ex.printStackTrace(System.err) ;
          }
          Statement stmt = conn.createStatement() ;
          String upldList = null ;
          ResultSet rs = stmt.executeQuery( "SELECT uploadId FROM upload WHERE refSeqId=" + getRefSeqId() ) ;
          while( rs.next() )
          {
            String upldId = rs.getString(1) ;
            if(upldList == null)
            {
              upldList = upldId ;
            }
            else
            {
              upldList = upldList + ", " + upldId ;
            }
          }
          rs.close() ;
          if(upldList != null)
          {
            stmt.executeUpdate( "DELETE FROM refseq2upload WHERE uploadId IN (" + upldList + ")" ) ;
          }
          stmt.executeUpdate( "DELETE FROM grouprefseq WHERE refSeqId=" + getRefSeqId() ) ;
          stmt.executeUpdate( "DELETE FROM refseq2upload WHERE refSeqId=" + getRefSeqId() ) ;
          stmt.executeUpdate( "DELETE FROM upload WHERE refSeqId=" + getRefSeqId() ) ;
          stmt.executeUpdate( "DELETE FROM refseq WHERE refSeqId=" + getRefSeqId() ) ;

          stmt.executeUpdate( "DELETE FROM unlockedGroupResources WHERE resource_id=" + getRefSeqId() + " AND resourceType = 'database'" ) ;
          stmt.executeUpdate( "DELETE ugr, ugrp FROM unlockedGroupResources ugr, unlockedGroupResourceParents ugrp WHERE ugr.id = ugrp.unlockedGroupResource_id AND ugrp.resourceType='database' AND ugrp.resource_id=" + getRefSeqId() ) ;

          String dbName = this.getDatabaseName() ;
          // First, drop user database...this uses the genboree.database2host table to find the right db host to drop the database from
          boolean dropDatabaseOk = db.dropUserDatabase(dbName) ;
          if(!dropDatabaseOk)
          {
            System.err.println("ERROR: Refseq.delete(D) => Couldn't drop database '" + dbName + "'") ;
          }
          // THEN remove the entry in genboree.database2host (last) since we don't need it to do anything more
          boolean delHostMappingOk = Database2HostTable.deleteHostMappingForDatabase(dbName, conn) ;
          if(!delHostMappingOk)
          {
            System.err.println("ERROR: Refseq.delete(D) => Couldn't remove database '" + dbName + "' from host mapping table.") ;
          }
          // clean up
          stmt.close() ;
          db.closeConnection(conn) ;
          retVal = true ;
        }
        catch(Exception ex)
        {
          System.err.println("ERROR: Refseq.delete(D) => problem deleting user database from Genboree. Details: " + ex.getMessage()) ;
          ex.printStackTrace(System.err) ;
          db.reportError( ex, "Refseq.delete()" ) ;
          retVal = false ;
        }
      }
    }
    return retVal ;
	}

    public String[] fetchDatabaseNames( DBAgent db ) throws SQLException
    {
		if( getRefSeqId().equals("#") ) return null;
		Connection conn = db.getConnection();
		if( conn != null ) try
		{
		    Vector v = new Vector();
		    v.addElement( getDatabaseName() );
		    Statement stmt = conn.createStatement();
            //This query is designed to get the name of  share databases
            ResultSet rs = stmt.executeQuery( "SELECT u.databaseName "+
            "FROM upload u, refseq2upload ru, refseq r "+
            "WHERE u.uploadId=ru.uploadId AND r.refSeqId=ru.refSeqId AND "+
            "r.databaseName<>u.databaseName AND ru.refSeqId="+getRefSeqId() );
            while( rs.next() )
            {
                v.addElement( rs.getString(1) );
            }
            stmt.close();
            String[] rc = new String[ v.size() ];
            v.copyInto( rc );
            return rc;
		} catch( Exception ex )
		{
			db.reportError( ex, "Refseq.fetchDatabaseNames()" );
		}
		return null;
    }
    public String fetchMapmaster( DBAgent db ) throws SQLException
    {
        String[] dbNames = fetchDatabaseNames( db );
        if( dbNames == null ) return null;
        String rc = getMapmaster() + "/";
        String sep = "";
        for( int i=0; i<dbNames.length; i++ )
        {
            rc = rc + sep + dbNames[i];
            sep = "&";
        }
        return rc;
    }
    public static String computeBin( long start, long stop, long min )
    {
        long tier = min;
        long bin_start, bin_end;
        while( true )
        {
            bin_start = start / tier;
            bin_end = stop / tier;
            if( bin_start == bin_end ) break;
            tier *= 10;
        }
        String fract = "" + bin_start;
        while( fract.length() < 6 ) fract = "0" + fract;
        return ""+tier+"."+fract;
    }

    // This needs to be very conservative in making unique names!
    // Time-stamp only based code has generated errors in the past, due to non-careful approaches!
    public static String generateUniqueName()
    {
      return Util.generateUniqueString() ;
    }

    public String[][] fetchEntryPoints( Connection conn ) throws SQLException
    {
        DbFref[] ff = DbFref.fetchAll( conn );
        String[][] rc = new String[ ff.length ][3];
        for( int i=0; i<ff.length; i++ )
        {
            DbFref f = ff[i];
            String[] ep = new String[3];
            rc[i] = ep;
            ep[0] = f.getRefname();
            ep[2] = f.getRlength();
            ep[1] = f.getGname();
        }
        return rc;
    }

  public DbFtype[] fetchTracks( DBAgent db, String _entryPointId, int genboreeUserId ) throws SQLException
  {
    return fetchTracks( db, null, _entryPointId, genboreeUserId );
  }

  public DbFtype[] fetchTracks( DBAgent db, String[] dbNames, String _entryPointId, int genboreeUserId ) throws SQLException
  {
    String local_ftypeIds = null;
    if( dbNames == null ) dbNames = fetchDatabaseNames( db );
    if( dbNames == null ) return new DbFtype[0];
    Hashtable ht = new Hashtable();

    try
    {
      for( int k = 0; k < dbNames.length; k++ )
      {
        Connection conn = db.getConnection( dbNames[ k ] );
        local_ftypeIds = GenboreeUtils.filterFtypeIdsUsingFdata2( conn, _entryPointId );
        if(local_ftypeIds == null || local_ftypeIds.length() < 1)
          continue;
        Statement stmt = conn.createStatement();
        ResultSet rs = stmt.executeQuery( "SELECT ftypeid, fmethod, fsource FROM ftype WHERE ftypeid IN ( " + local_ftypeIds + " )" );

        while( rs.next() )
        {
          int ftypeId = rs.getInt( "ftypeid" );
          String fmethod = rs.getString( "fmethod"  );
          String fsource = rs.getString( "fsource"  );
          DbFtype ft = new DbFtype(dbNames[k], ftypeId, fmethod, fsource  );
          String key = ft.toString();
          if( TrackPermission.isTrackAllowed( dbNames[ k ], fmethod, fsource, genboreeUserId ) )
          {
            if( ht.get( key ) == null )
              ht.put( key, ft );
          }
        }
        stmt.close();
      }
    }
    catch( Exception ex )
    {
      ex.printStackTrace( System.err );
      System.err.println( "Exception trying to find ftypeIds in method Refseq::fetchTracks" );
      System.err.flush();
      db.reportError( ex, "Refseq.fetchTracks()" );
    }

    DbFtype[] rc = new DbFtype[ht.size()];
    int j = 0;
    for( Enumeration en = ht.keys(); en.hasMoreElements(); )
    {
      Object key = en.nextElement();
      rc[ j++ ] = ( DbFtype )ht.get( key );
    }
    Arrays.sort( rc );
    return rc;
  }

    public int deleteTracks( DBAgent db, String[] trkIds ) throws SQLException
    {
        int rc = 0;

        Connection conn = db.getConnection( getDatabaseName() );
        if( conn != null ) try
        {
            CacheManager.clearCache( db, this );

            int i;
		    String lst = null;

		    if( trkIds != null )
		    for( i=0; i<trkIds.length; i++ )
		    {
			    if( lst == null ) lst = trkIds[i];
			    else lst = lst + "," + trkIds[i];
		    }

		    if( lst != null )
		    {


			    Statement stmt = conn.createStatement();
			    rc += stmt.executeUpdate(
				    "DELETE FROM fdata2 WHERE ftypeid IN ("+lst+")" );
			    rc += stmt.executeUpdate(
				    "DELETE FROM fdata2_cv WHERE ftypeid IN ("+lst+")" );
			    rc += stmt.executeUpdate(
				    "DELETE FROM fdata2_gv WHERE ftypeid IN ("+lst+")" );
			    stmt.executeUpdate( "DELETE FROM ftype WHERE ftypeid IN ("+lst+")" );
			    stmt.executeUpdate( "DELETE FROM featuredisplay WHERE ftypeid IN ("+lst+")" );
			    stmt.executeUpdate( "DELETE FROM featuretocolor WHERE ftypeid IN ("+lst+")" );
			    stmt.executeUpdate( "DELETE FROM featuretostyle WHERE ftypeid IN ("+lst+")" );
			    stmt.executeUpdate( "DELETE FROM featuretolink WHERE ftypeid IN ("+lst+")" );
			    stmt.executeUpdate( "DELETE FROM ftypeCount WHERE ftypeid IN ("+lst+")" );
			    stmt.executeUpdate( "DELETE FROM fidText WHERE ftypeid IN ("+lst+")" );
			    stmt.executeUpdate( "DELETE FROM zoomLevels WHERE ftypeid IN ("+lst+")" );
			    try
			    {
			        stmt.executeUpdate( "DELETE FROM featureurl WHERE ftypeid IN ("+lst+")" );
			    } catch( Exception ex ) {}



				    stmt.executeUpdate(
					    "DELETE FROM featuresort WHERE " +
					    " ftypeid IN ("+lst+")" );


			    stmt.close();
            }

        } catch( Exception ex )
        {
            db.reportError( ex, "Refseq.deleteTracks()" );
        }
        return rc;
    }
    public void fetchTrackDisplay( DBAgent db, DbFtype[] ftypes, int userId ) throws SQLException
    {
        Hashtable ht = DbFtype.breakByDatabase( ftypes );
        for( Enumeration en=ht.keys(); en.hasMoreElements(); )
        {
            String dbName = (String) en.nextElement();
            Connection conn = db.getConnection( dbName );
            if( conn == null ) continue;
            try
            {
                Vector v = (Vector) ht.get( dbName );
                PreparedStatement pstmt = conn.prepareStatement(
                    "SELECT display FROM featuredisplay WHERE ftypeid=? AND userId=?" );
                for( int i=0; i<v.size(); i++ )
                {
                    DbFtype ft = (DbFtype) v.elementAt(i);
                    pstmt.setInt( 1, ft.getFtypeid() );
                    pstmt.setInt( 2, userId );
                    ResultSet rs = pstmt.executeQuery();
                    if( !rs.next() ) rs = null;
                    if( rs==null && userId!=0 )
                    {
                        pstmt.setInt( 1, ft.getFtypeid() );
                        pstmt.setInt( 2, 0 );
                        rs = pstmt.executeQuery();
                        if( !rs.next() ) rs = null;
                    }
                    if( rs != null ) ft.setDisplay( rs.getString(1) );
                }
                pstmt.close();
            } catch( Exception ex )
            {
		        if( ex instanceof SQLException && ((SQLException)ex).getErrorCode()==1146 )
	            try
	            {
	                Statement stmt = conn.createStatement();
	                stmt.executeUpdate( createTableFeaturedisplay );
	                stmt.close();
	            } catch( Exception ex1 ) {}
            }
        }
    }
    protected static String prepareFtypeidList( Vector v )
    {
        String rc = null;
        for( int i=0; i<v.size(); i++ )
        {
            DbFtype ft = (DbFtype) v.elementAt(i);
            if( rc == null ) rc = ""+ft.getFtypeid();
            else rc = rc + "," + ft.getFtypeid();
        }
        if( rc == null ) return "(-1)";
        return "("+rc+")";
    }

    protected static String prepareSQLSetString( Vector vv )
    {
      StringBuffer buffer = new StringBuffer() ;
      if(vv.size() > 0)
      {
        buffer.append("(") ;
        for( int ii=0; ii<vv.size(); ii++ )
        {
          buffer.append("?") ;
          if(ii < vv.size()-1)
          {
            buffer.append(",") ;
          }
        }
        buffer.append(")") ;
      }
      return buffer.toString() ;
    }

    public Hashtable deleteTrackDisplay( DBAgent db, DbFtype[] ftypes, int userId )
    {
      String deleteQuery = null;
      Hashtable ht = DbFtype.breakByDatabase( ftypes );
      System.err.println("DEBUG: ht: " + ht.toString()) ;
      for( Enumeration en=ht.keys(); en.hasMoreElements(); )
      {
        String dbName = (String)en.nextElement() ;
        // Remove local DB settings for this userId (don't update shared databases, i.e. make changes to template DB)
        if(dbName.equals(this.databaseName))
        {
          Vector vv = (Vector)ht.get( dbName );
          deleteQuery = "DELETE FROM featuredisplay WHERE userId = ? " +
                        " AND ftypeid IN " + prepareSQLSetString(vv) ;
          try
          {
            Connection conn = db.getConnection(dbName) ;
            PreparedStatement pstmt = conn.prepareStatement(deleteQuery) ;
            pstmt.setInt(1, userId) ;
            for(int ii = 0; ii < vv.size(); ii++)
            {
              DbFtype ft = (DbFtype)vv.elementAt(ii) ;
              pstmt.setString(ii+2, "" + ft.getFtypeid()) ;
            }
            int numRowsUpdated = pstmt.executeUpdate() ;
          }
          catch( Exception ex )
          {
            db.reportError(ex, "Refseq.deleteTrackDisplay(D,D,i): dnName = " + dbName + ", sql = " + deleteQuery) ;
          }
        }
      }
      return ht;
    }

    public void updateTrackDisplay( DBAgent db, DbFtype[] ftypes, int userId ) throws SQLException
    {
      String sql = "INSERT INTO featuredisplay (ftypeid, userId, display) VALUES (?,?,?) ON DUPLICATE KEY UPDATE display = VALUES(display)" ;
      String dbName = null ;
      PreparedStatement pstmt = null ;
      // First, remove any local DB settings for the userId.
      // - ht should be a hash of DbFtype objects keyed by the database they come from
      System.err.println("DEBUG: this.databaseName: " + this.databaseName) ;
      Hashtable ht = deleteTrackDisplay( db, ftypes, userId ) ;
      try
      {
        // Prep a repeatedly used insert sql for setting the display ;
        Connection localConn = db.getConnection(this.databaseName) ;
        pstmt = localConn.prepareStatement(sql) ;
        // Get a map of all track names in the local database:
        HashMap<String, Integer> trackName2ftypeid = FtypeTable.getTrackName2FtypeidMap(localConn) ;
        // For each track, no matter where found, make a local DB settings entry.
        for( Enumeration en=ht.keys(); en.hasMoreElements(); )
        {
          // Currently examined database name:
          dbName = (String) en.nextElement() ;
          // Go through each track in this database
          Vector vv = (Vector) ht.get(dbName) ;
          System.err.println("DEBUG: PROCESSING dbName = " + dbName) ;
          for( int ii=0; ii<vv.size(); ii++ )
          {
            DbFtype ft = (DbFtype)vv.elementAt(ii) ;
            String trackName = ft.getTrackName() ;
            // If it is not in the local database, insert it into the local database.
            if(!trackName2ftypeid.containsKey(trackName))
            {
              String fmethod = ft.getFmethod() ;
              String fsource = ft.getFsource() ;
              int newFtypeid = FtypeTable.insertTrack(fmethod, fsource, localConn) ;
              if(newFtypeid >= 0)
              {
                trackName = fmethod + ":" + fsource ;
                trackName2ftypeid.put(trackName, newFtypeid) ;
              }
            }
            System.err.println("        trackName = " + trackName + " ; trackName2ftypeid = " + trackName2ftypeid.toString()) ;
            if(trackName == null)
            {
              continue ;
            }
            // Get the ftypeid for the track in the local database
            int ftypeid = trackName2ftypeid.get(trackName) ;
            System.err.println("     updating ftypeid " + ftypeid + " to display of " + ft.getDisplay());
            // Make the display setting in the local database.
            pstmt.setInt(1, ftypeid) ;
            pstmt.setInt(2, userId) ;
            pstmt.setString(3, ft.getDisplay()) ;
            pstmt.executeUpdate() ;
          }
        }
        CacheManager.clearCache(db, this.databaseName) ;
      }
      catch( Exception ex )
      {
        db.reportError(ex, "Refseq.updateTrackDisplay(D,D,i): dnName = " + dbName + ", sql = " + sql) ;
      }
      finally
      {
        if(pstmt != null)
        {
          pstmt.close() ;
        }
      }
    }

    public void updateDefaultTrackDisplay( DBAgent db, DbFtype[] ftypes, int userId ) throws SQLException
    {
        if( userId != 0 ) return;
       // deleteTrackDisplay( db, ftypes, userId );
        updateTrackDisplay( db, ftypes, userId );
    }

    public Style[] fetchStyleMap( DBAgent db, int userId ) throws SQLException
    {
        String[] dbNames = fetchDatabaseNames( db );
        if( dbNames==null || dbNames.length==0 ) return new Style[0];

        return Style.fetchAll( db, dbNames, userId );
    }
    public Style[] fetchColors( DBAgent db ) throws SQLException
    {
        String[] dbNames = fetchDatabaseNames( db );
        if( dbNames==null || dbNames.length==0 ) return new Style[0];

        int i;
        Hashtable ht = new Hashtable();
        try
        {
            for( i=0; i<dbNames.length; i++ )
            {
                Connection conn = db.getConnection( dbNames[i] );
                Statement stmt = conn.createStatement();
                ResultSet rs = stmt.executeQuery( "SELECT colorId, value FROM color" );
                while( rs.next() )
                {
                    Style st = new Style();
                    st.colorid = rs.getInt(1);
                    st.color = rs.getString(2);
                    if( ht.get(st.color) == null )
                    {
                        st.databaseName = dbNames[i];
                        ht.put( st.color, st );
                    }
                }
                stmt.close();
            }
        } catch( Exception ex )
        {
            db.reportError( ex, "Refseq.fetchColors()" );
        }

        Style[] rc = new Style[ ht.size() ];
        int j = 0;
        for( Enumeration en=ht.keys(); en.hasMoreElements(); )
        {
            Style s = (Style) ht.get( en.nextElement() );
            rc[j++] = s;
        }
        return rc;
    }
    public Style[] fetchStyles( DBAgent db ) throws SQLException
    {
        String[] dbNames = fetchDatabaseNames( db );
        if( dbNames==null || dbNames.length==0 ) return new Style[0];

        int i;
        Hashtable ht = new Hashtable();
        try
        {
            for( i=0; i<dbNames.length; i++ )
            {
                Connection conn = db.getConnection( dbNames[i] );
                Statement stmt = conn.createStatement();
                ResultSet rs = stmt.executeQuery(
                    "SELECT styleId, name, description FROM style" );
                while( rs.next() )
                {
                    Style st = new Style();
                    st.styleId = rs.getString(1);
                    st.name = rs.getString(2);
                    st.description = rs.getString(3);
                    if( ht.get(st.name) == null )
                    {
                        st.databaseName = dbNames[i];
                        ht.put( st.name, st );
                    }
                }
                stmt.close();
            }
        } catch( Exception ex )
        {
            db.reportError( ex, "Refseq.fetchStyles()" );
        }

        Style[] rc = new Style[ ht.size() ];
        int j = 0;
        for( Enumeration en=ht.keys(); en.hasMoreElements(); )
        {
            Style s = (Style) ht.get( en.nextElement() );
            rc[j++] = s;
        }
        Arrays.sort( rc, new StyleNameComparator() );
        return rc;
    }
    public void deleteStyleMap( DBAgent db, Style[] delst, int _userId )
    {
        if( _userId < 0 ) return;
        Hashtable ht = new Hashtable();
        try
        {
            for( int i=0; i<delst.length; i++ )
            {
                Style st = delst[i];
                PreparedStatement pstmt1 = null;
                PreparedStatement pstmt2 = null;
                PreparedStatement[] pstmts = (PreparedStatement []) ht.get( st.databaseName );
                if( pstmts == null )
                {
                    Connection conn = db.getConnection( st.databaseName );
                    pstmt1 = conn.prepareStatement(
                        "DELETE FROM featuretostyle WHERE userId=? AND ftypeid = ?" );
                    pstmt2 = conn.prepareStatement(
                        "DELETE FROM featuretocolor WHERE userId=? AND ftypeid = ?");
                    pstmts = new PreparedStatement[ 2 ];
                    pstmts[0] = pstmt1;
                    pstmts[1] = pstmt2;

                    ht.put( st.databaseName, pstmts );
                }
                else
                {
                    pstmt1 = pstmts[0];
                    pstmt2 = pstmts[1];
                }
                pstmt1.setInt( 1, _userId );
                pstmt1.setInt( 2, st.ftypeid );
                pstmt1.executeUpdate();
                pstmt2.setInt( 1, _userId );
                pstmt2.setInt( 2, st.ftypeid );
                pstmt2.executeUpdate();
            }
        } catch( Exception ex )
        {
            db.reportError( ex, "Refseq.deleteStyleMap()" );
        }
    }
	public static int colorval( String sc )
	{
		try
		{
			if( sc.startsWith("#") ) sc = sc.substring(1);
			int rc = Integer.parseInt(sc,16);
			return rc;
		} catch( Exception ex ) {}
		return 0x00AAAA;
	}
    public static int colordiff( int ic1, int ic2 )
    {
        int dr = ((ic1 >> 16) & 0xFF) - ((ic2 >> 16) & 0xFF);
        int dg = ((ic1 >> 8) & 0xFF) - ((ic2 >> 8) & 0xFF);
        int db = (ic1 & 0xFF) - (ic2 & 0xFF);
        return (int)(Math.sqrt( (double)(dr*dr + dg*dg + db*db) ) + 0.5);
    }
	public static int colordiff( String sc1, int ic2 )
	{
		try
		{
			if( sc1.startsWith("#") ) sc1 = sc1.substring(1);
			int rc = colordiff( Integer.parseInt(sc1,16), ic2 );
			return rc;
		} catch( Exception ex ) {}
		return 0xFFFFFF;
	}
    public boolean setStyleMap( DBAgent db, Style[] styleMap, int _userId ) throws SQLException
    {
        String[] dbNames = fetchDatabaseNames( db );
        if( dbNames==null || dbNames.length==0 ) return false;

        int i;
        try
        {
            for( int j=0; j<dbNames.length; j++ )
            {
                String dbName = dbNames[j];
                Connection conn = null;
                Statement stmt = null;
                PreparedStatement psColorIns = null;
                PreparedStatement psStyleIns = null;
                PreparedStatement psFeatureColorDel = null;
                PreparedStatement psFeatureStyleDel = null;
                PreparedStatement psFeatureColorIns = null;
                PreparedStatement psFeatureStyleIns = null;

                Hashtable htStyle = null;
                Hashtable htColor = null;

                System.gc();

                for( i=0; i<styleMap.length; i++ )
                {
                    Style st = styleMap[i];
                    if( ! st.databaseName.equals(dbName) ) continue;
                    if( conn == null )
                    {
                        conn = db.getConnection( dbName );
                        stmt = conn.createStatement();
                        htStyle = new Hashtable();
                        htColor = new Hashtable();

                        ResultSet rs = stmt.executeQuery( "SELECT styleId, name FROM style" );
                        while( rs.next() )
                        {
                            String val = rs.getString(1);
                            String key = rs.getString(2);
                            htStyle.put( key, val );
                        }

                        rs = stmt.executeQuery( "SELECT colorId, value FROM color" );
                        while( rs.next() )
                        {
                            String val = rs.getString(1);
                            String key = rs.getString(2);
                            htColor.put( key, val );
                        }

                        psFeatureColorDel = conn.prepareStatement(
                            "DELETE FROM featuretocolor WHERE userId=? AND ftypeid=?" );
                        psFeatureStyleDel = conn.prepareStatement(
                            "DELETE FROM featuretostyle WHERE userId=? AND ftypeid=?" );
                        psFeatureColorIns = conn.prepareStatement(
                            "INSERT INTO featuretocolor (userId, ftypeid, colorId) VALUES (?, ?, ?)" );
                        psFeatureStyleIns = conn.prepareStatement(
                            "INSERT INTO featuretostyle (userId, ftypeid, styleId) VALUES (?, ?, ?)" );
                    }

                    String styleId = (String) htStyle.get( st.name );
                    if( styleId == null )
                    {
                        if( psStyleIns == null ) psStyleIns = conn.prepareStatement(
                            "INSERT INTO style (name, description) VALUES (?, ?)" );
                        psStyleIns.setString( 1, st.name );
                        psStyleIns.setString( 2, st.description );
                        if( psStyleIns.executeUpdate() > 0 )
                        {
                            ResultSet rs = stmt.executeQuery( "SELECT LAST_INSERT_ID()" );
                            if( rs.next() )
                            {
                                st.styleId = styleId = rs.getString(1);
                                htStyle.put( st.name, styleId );
                            }
                        }
                    }
                    psFeatureStyleDel.setInt( 1, _userId );
                    psFeatureStyleDel.setInt( 2, st.ftypeid );
                    psFeatureStyleDel.executeUpdate();
                    if( styleId != null )
                    {
                        psFeatureStyleIns.setInt( 1, _userId );
                        psFeatureStyleIns.setInt( 2, st.ftypeid );
                        psFeatureStyleIns.setString( 3, styleId );
                        psFeatureStyleIns.executeUpdate();
                    }

                    String colorId = (String) htColor.get( st.color );
                    if( colorId == null )
                    {
                        int srcCval = colorval( st.color );
                        String bestCid = null;
                        String bestCval = null;
                        int bestDiff = 0;
                        for( Enumeration en=htColor.keys(); en.hasMoreElements(); )
                        {
                            String cid = (String) en.nextElement();
                            String tgtCval = (String) htColor.get(cid);
                            int cdiff = colordiff( tgtCval, srcCval );
                            if( bestCid==null || bestDiff>cdiff )
                            {
                                bestCid = cid;
                                bestCval = tgtCval;
                                bestDiff = cdiff;
                            }
                        }
                        colorId = bestCid;
                    }

                    if( colorId == null )
                    {
                        if( psColorIns == null ) psColorIns = conn.prepareStatement(
                            "INSERT INTO color (value) VALUES (?)" );
                        psColorIns.setString( 1, st.color );
                        if( psColorIns.executeUpdate() > 0 )
                        {
                            ResultSet rs = stmt.executeQuery( "SELECT LAST_INSERT_ID()" );
                            if( rs.next() )
                            {
                                st.colorid = rs.getInt(1);
                                colorId = ""+st.colorid;
                                htColor.put( st.color, colorId );
                            }
                        }
                    }
                    psFeatureColorDel.setInt( 1, _userId );
                    psFeatureColorDel.setInt( 2, st.ftypeid );
                    psFeatureColorDel.executeUpdate();
                    if( colorId != null )
                    {
                        psFeatureColorIns.setInt( 1, _userId );
                        psFeatureColorIns.setInt( 2, st.ftypeid );
                        psFeatureColorIns.setString( 3, colorId );
                        psFeatureColorIns.executeUpdate();
                    }

                }
            }
            return true;
        } catch( Exception ex )
        {
            db.reportError( ex, "Refseq.setStyleMap()" );
        }
        return false;
    }
    public String[][] fetchLinkMap( DBAgent db, int _userId ) throws SQLException
    {
        Vector v = new Vector();
		Connection conn = db.getConnection( getDatabaseName() );
		if( conn != null ) try
		{
		    PreparedStatement pstmt = conn.prepareStatement(
		        "SELECT ftypeid, linkId FROM featuretolink WHERE userId=?" );
		    pstmt.setInt( 1, _userId );
		    ResultSet rs = pstmt.executeQuery();
		    while( rs.next() )
		    {
		        String[] lf = new String[2];
		        lf[0] = rs.getString(1);
		        lf[1] = rs.getString(2);
		        v.addElement( lf );
		    }
            pstmt.close();
		} catch( Exception ex )
		{
			db.reportError( ex, "Refseq.fetchLinkMap()" );
		}
        String[][] rc = new String[ v.size() ][2];
        v.copyInto( rc );
        return rc;
    }
    public String getCurDbName()
    {
        if( frDbNames == null ) return null;
        if( frCurDb >= frDbNames.length ) return null;
        return frDbNames[frCurDb];
    }
    public Hashtable getLinkHash( DBAgent db, int _userId )
    {
        if( frLinkHash != null ) return frLinkHash;
        String dbName = getCurDbName();
        if( dbName == null ) return null;
        try
        {
            frLinkHash = new Hashtable();
            Connection conn = db.getConnection( dbName );
            DbLink[] links = DbLink.fetchAll( conn, false);
            Hashtable ht = new Hashtable();
            int i;
            for( i=0; i<links.length; i++ ) ht.put( ""+links[i].getLinkId(), links[i] );
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery(
                "SELECT fl.linkId, ft.fmethod, ft.fsource "+
                "FROM ftype ft, featuretolink fl where ft.ftypeid=fl.ftypeid "+
                "AND fl.userId="+ _userId );
            while( rs.next() )
            {
                String linkId = rs.getString(1);
                String fmethod = rs.getString(2);
                String fsource = rs.getString(3);
                DbLink lnk = (DbLink)ht.get(linkId);
                if( lnk == null ) continue;
                String trackName = fmethod+":"+fsource;
                Vector v = (Vector)frLinkHash.get( trackName );
                if( v == null )
                {
                    v = new Vector();
                    frLinkHash.put( trackName, v );
                }
                v.addElement( lnk );
            }
            stmt.close();
        } catch( Exception ex )
        {
            db.reportError( ex, "Refseq.getLinkHash()" );
        }
        return frLinkHash;
    }
    public String fetchFidText(DBAgent db, String dbName, String fid, char textType) throws SQLException
    {
        String textField = null;
        String query = "SELECT text FROM fidText WHERE fid= "+fid + " and textType = '" + textType + "'";
        Connection conn = db.getConnection( dbName );
        PreparedStatement pstmt = conn.prepareStatement( query );

        ResultSet rs = pstmt.executeQuery();
        if( rs.next() ) textField = rs.getString(1);
        pstmt.close();
        return textField;
    }

    public Hashtable getFeatureTypeToGclasses()
    {
        return featureTypeToGclasses;
    }

    public void setFeatureTypeToGclasses(DBAgent db, String myRefseqId )
    {
        String[] ftypes = null;
        String[] uploads = null;
        String[]fmethodfsource = null;
        String[] classNames = null;
        int genboreeUserId = Util.parseInt( userId, -1 );
        ftypes = GenboreeUpload.fetchAllTracksFromUploads(db, myRefseqId, genboreeUserId );
        uploads = GenboreeUpload.returnDatabaseNames(db, myRefseqId );
        featureTypeToGclasses = new Hashtable();


        for(int i = 0; i < ftypes.length; i++)
        {
            String ftype = ftypes[i];
            if(ftype == null) continue;
            fmethodfsource = ftype.split(":");
            if(fmethodfsource == null || fmethodfsource.length < 2)
                continue;
            String fmethod = fmethodfsource[0];
            String fsource = fmethodfsource[1];
            if(fmethod != null && fsource != null)
                classNames = GenboreeUpload.fetchClassesInFtypeId(db, uploads, fmethod, fsource);
            if(classNames != null)
                featureTypeToGclasses.put( ftypes[i], classNames );
        }

        return;
    }



    public static String[] returnVectorWithColumNames(ResultSet rs)
    {
        ResultSetMetaData rm = null;
        Vector columnNames = null;
        int numCols = 0;
        String[] columns = null;

        columnNames = new Vector();

        try {
            rm = rs.getMetaData();
            numCols = rm.getColumnCount();
            for(int i=0; i<numCols; i++ )
            {
                String lab = rm.getColumnLabel(i+1);
                columnNames.addElement( lab );
            }
            columns = new String[ columnNames.size() ];
            columnNames.copyInto( columns );
        }
        catch (SQLException e) {
            System.out.println ("");
            e.printStackTrace();
        }
        finally{
            return columns;
        }
    }

    public String createAnnotationHeader(String[] columns)
    {
        StringBuffer stringBuffer = null;
        String annotationHeader = null;
        int added = 0;
        int i = 0;

        if(columns == null)
        {
            System.err.println("Error on function createAnnotationHeader columns is null");
            System.err.flush();
            return null;
        }
        stringBuffer = new StringBuffer( 200 );

        stringBuffer.append( "#" );

        for(i = 0,added = 0; i < columns.length; i++ )
        {
            if(columns[i].equalsIgnoreCase("databaseName"))
            {
                continue;
            }
            else
            {
                stringBuffer.append( columns[i]);
                added++;
            }

            if( added > 0 ) stringBuffer.append( "\t" );
        }
        annotationHeader = stringBuffer.toString();

        return annotationHeader;
    }

    public String retrieveClassName(DBAgent db, String fmethod, String fsource)
    {
        String gclass = null;
        String[] gclasses = null;

        if(fmethod == null|| fsource == null) return null;

        gclasses = retrieveClassesName(db, fmethod, fsource);

        if(gclasses == null || gclasses.length == 0) return null;
        gclass = gclasses[0];

        return gclass;
    }

    public String retrieveExtraClassName(DBAgent db, String fmethod, String fsource)
    {
        String[] gclasses = null;
        int sizeOfClasses = 0;
        StringBuffer gclassBuffer = null;

        if(fmethod == null|| fsource == null) return null;

        gclasses = retrieveClassesName(db, fmethod, fsource);

        if(gclasses == null)
            return null;

        sizeOfClasses = gclasses.length;

        if(sizeOfClasses < 2) return null;

        gclassBuffer = new StringBuffer( 200 );
        gclassBuffer.append(" aHClasses=");
        for(int i = 1; i < sizeOfClasses; i++)
        {
            gclassBuffer.append(gclasses[i]);
            if(i < (sizeOfClasses -1))
                    gclassBuffer.append(",");
        }
        gclassBuffer.append(";");
        return gclassBuffer.toString();
    }

    public String[] retrieveClassesName(DBAgent db, String fmethod, String fsource)
    {
        String ftypeKey = null;
        Hashtable myFtoCHash = null;
        String[] gclasses = null;

        if(fmethod == null|| fsource == null) return null;

        myFtoCHash = getFeatureTypeToGclasses();
        if(myFtoCHash == null) return null;

        ftypeKey = fmethod + ":" + fsource;
        gclasses = (String[])myFtoCHash.get(ftypeKey);

        return gclasses;
    }




    public long[] fetchGroupLimits( DBAgent db, String gclass, String gname, String entryPointId, String trackName ) throws SQLException
    {
        String[] dbNames = fetchDatabaseNames( db );
        if( dbNames == null || dbNames.length==0 ) return null;
        for( int idb=0; idb<dbNames.length; idb++ )
        {
            String dbName = dbNames[idb];
            try
            {
                int rid = -1;
                int ftypeid = -1;
                Connection conn = db.getConnection( dbName );

                PreparedStatement pstmt = conn.prepareStatement( "SELECT rid FROM fref WHERE refname=?" );
                pstmt.setString( 1, entryPointId );
                ResultSet rs = pstmt.executeQuery();
                if( rs.next() ) rid = rs.getInt(1);
                pstmt.close();

                if( rid!=-1 )
                {
                    int idx = -1;
                    if( trackName != null ) idx = trackName.indexOf(':');
                    if( idx > 0 )
                    {
                        String fmethod = trackName.substring(0,idx);
                        String fsource = trackName.substring(idx+1);
                        pstmt = conn.prepareStatement( "SELECT ftypeid FROM ftype "+
                            "WHERE fmethod=? AND fsource=?" );
                        pstmt.setString( 1, fmethod );
                        pstmt.setString( 2, fsource );
                        rs = pstmt.executeQuery();
                        if( rs.next() ) ftypeid = rs.getInt(1);
                    }

                    long[] rc = null;
                    String qs = "SELECT MIN(fstart), MAX(fstop) FROM fdata2 "+
                        "WHERE rid="+rid;
                    if( ftypeid != -1 ) qs = qs + " AND ftypeid="+ftypeid;
                    qs = qs + " AND gname=?";
                    pstmt = conn.prepareStatement( qs );
                    pstmt.setString( 1, gname );
                    rs = pstmt.executeQuery();
                    if( rs.next() )
                    {
                        rc = new long[2];
                        rc[0] = rs.getLong(1);
                        rc[1] = rs.getLong(2);
                        if( rc[0]==0L || rc[1]==0L ) rc = null;
                    }
                    pstmt.close();

                    if( rc != null ) return rc;
                }
            } catch( Exception ex ) {}
        }
        return null;
    }
    public DbResourceSet fetchRecordsFirst( DBAgent db,
        String[] trackNames, String from, String to,
        String entryPointId, String filter ) throws SQLException
    {

        if( filter == null ) filter = "b";
        else filter = filter.toLowerCase();
        Vector v = new Vector();
        if( filter.indexOf('b')>=0 ) v.addElement( "fdata2" );
        if( filter.indexOf('c')>=0 ) v.addElement( "fdata2_cv" );
        if( filter.indexOf('g')>=0 ) v.addElement( "fdata2_gv" );
        if( v.size() < 1 ) return null;

        frTables = new String[ v.size() ];
        v.copyInto( frTables );

        frDbNames = fetchDatabaseNames( db );
        if( frDbNames==null || frDbNames.length<1 ) return null;

        int i;

        frEntryPointId = entryPointId;

        if( trackNames == null ) frTracks = null;
        else
        {
            frTracks = new Hashtable();
            for( i=0; i<trackNames.length; i++ ) frTracks.put( trackNames[i], "y" );
        }

	    frQs1 = " 'gclass' class, f.gname name, ft.fmethod type, "+
	    "ft.fsource subtype, fr.refname ref, fstart start, fstop stop, fstrand strand, "+
	    "fphase phase, fscore score, ftarget_start tstart, ftarget_stop tend, f.fid comments, f.fid sequence "+
	    "FROM ";

	    frQs2 = " f, ftype ft, fref fr "+
	    "WHERE ft.ftypeid=f.ftypeid AND f.rid=fr.rid";
	    if( frEntryPointId != null ) frQs2 = frQs2 + " AND fr.refname=?";
	    if( from != null ) frQs2 = frQs2 + " AND fstop>"+from;
	    if( to != null ) frQs2 = frQs2 + " AND fstart<"+to;

	    frCurDb = -1;
	    frCurTable = frTables.length;
	    frTrackFilter = null;
	    frLinkHash = null;

        return fetchRecordsNext( db );
    }
    public DbResourceSet fetchRecordsNext( DBAgent db )
    {
        ResultSet rs = null;
        DbResourceSet dbRes = null;
        if( frDbNames==null || frTables==null ) return null;
        if( frCurTable >= frTables.length )
        {
            frCurTable = 0;
            frCurDb++;
            if( frCurDb >= frDbNames.length ) return null;
            frTrackFilter = null;
            frLinkHash = null;
        }


        try
        {
            Connection conn = db.getConnection( frDbNames[frCurDb] );
            frQs0 = "SELECT \""+ frDbNames[frCurDb] + "\" databaseName, ";

            if( conn == null ) return null;

            int i;

            if( frTrackFilter==null )
            {
                if( frTracks == null ) frTrackFilter = "";
                else
                {
                  int genboreeUserId = Util.parseInt( userId, -1 );
                    DbFtype[] fts = DbFtype.fetchAll( conn, frDbNames[frCurDb], genboreeUserId  );
                    if( fts == null ) return null;
                    String lst = null;
                    for( i=0; i<fts.length; i++ )
                    {
                        DbFtype ft = fts[i];
                        String trkn = ft.getFmethod() + " : " + ft.getFsource();
                        if( frTracks.get(trkn) == null ) continue;
                        if( lst == null ) lst = ""+ft.getFtypeid();
                        else lst = lst + ", "+ft.getFtypeid();
                    }
                    if( lst == null ) lst = "-1";
                    frTrackFilter = " AND f.ftypeId IN ("+lst+")";
                }
            }

            String tableName = frTables[ frCurTable++ ];
            PreparedStatement pstmt = conn.prepareStatement(frQs0 + frQs1 + tableName + frQs2 + frTrackFilter );
            if( frEntryPointId != null ) pstmt.setString( 1, frEntryPointId );

            rs = pstmt.executeQuery();
            dbRes = new DbResourceSet(rs, pstmt, conn, db);
        } catch( Exception ex )
        {
            db.reportError( ex, "Refseq.fetchRecordsNext()" );
            return null;
        }
        return dbRes;
    }
    public Hashtable fetchUploadMap( DBAgent db ) throws SQLException
    {
        Hashtable ht = new Hashtable();
        Connection conn = db.getConnection();
        if( conn != null ) try
        {
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery(
                "SELECT u.uploadId, u.databaseName "+
                "FROM upload u, refseq2upload ru "+
			    "WHERE u.uploadId=ru.uploadId AND ru.refSeqId="+getRefSeqId() );
			while( rs.next() )
			{
			    String uploadId = rs.getString(1);
			    String dbName = rs.getString(2);
			    ht.put( dbName, uploadId );
			}
			stmt.close();
        } catch( Exception ex )
        {
            db.reportError( ex, "Refseq.fetchUploadMap()" );
        }
        return ht;
    }
    public DbFtype[] fetchTracksSorted( DBAgent db, int userId ) throws SQLException
    {
        Hashtable ht = new Hashtable();
        Hashtable htUpld = fetchUploadMap( db );
        Enumeration en;
        int i;
        try
        {
            for( en = htUpld.keys(); en.hasMoreElements(); )
            {
                String dbName = (String) en.nextElement();
                String uploadId = (String) htUpld.get( dbName );
                DbFtype[] tracks = DbFtype.fetchAll( db.getConnection(dbName), dbName, userId );
                for( i=0; i<tracks.length; i++ )
                {
                    DbFtype ft = tracks[i];
                    String key = ft.toString();
                    if( key.compareToIgnoreCase("Component:Chromosome") == 0 ||
                        key.compareToIgnoreCase("Supercomponent:Sequence") == 0 )
                        continue;

                    ft.setDatabaseName( dbName );
                    ft.setUploadId( uploadId );
                    if( ht.get(key) == null ) ht.put( key, ft );
                }
            }

            Connection conn = db.getConnection( getDatabaseName() );
            PreparedStatement pstmt = conn.prepareStatement(
                "SELECT sortkey FROM featuresort WHERE ftypeid=?  AND userId=?" );
            ResultSet rs;
            for( en=ht.keys(); en.hasMoreElements(); )
            {
                String trkName = (String) en.nextElement();
                DbFtype ft = (DbFtype) ht.get( trkName );
                pstmt.setInt( 1, ft.getFtypeid() );
                //pstmt.setString( 2, ft.getUploadId() );
                pstmt.setInt( 2, userId );
                rs = pstmt.executeQuery();
                if( !rs.next() )
                {
                    if( userId != 0 )
                    {
                        pstmt.setInt( 1, ft.getFtypeid() );
                        //pstmt.setString( 2, ft.getUploadId() );
                        pstmt.setInt( 2, 0 );
                        rs = pstmt.executeQuery();
                        if( !rs.next() ) rs = null;
                    }
                    else rs = null;
                }
                if( rs != null )
                {
                    ft.setSortOrder( rs.getInt(1) );
                }
            }
            pstmt.close();
        } catch( Exception ex )
        {
            db.reportError( ex, "Refseq.fetchTracksSorted()" );
        }

        DbFtype[] rc = new DbFtype[ ht.size() ];
        i=0;
        for( en=ht.keys(); en.hasMoreElements(); )
        {
            rc[i++] = (DbFtype) ht.get( en.nextElement() );
        }
        Arrays.sort( rc );

        return rc;
    }
    public boolean setSortTracks( DBAgent db, DbFtype[] tracks, int userId ) throws SQLException
    {
        Connection conn = db.getConnection( getDatabaseName() );
        if( conn != null ) try
        {
            Statement stmt = conn.createStatement();
            stmt.executeUpdate( "DELETE FROM featuresort WHERE userId="+userId );

            if( tracks != null )
            {
                PreparedStatement pstmt = conn.prepareStatement(
                    "INSERT INTO featuresort (ftypeid, userId, sortkey) "+
                    "VALUES (?, ?, ?, ?)" );
                for( int i=0; i<tracks.length; i++ )
                {
                    DbFtype ft = tracks[i];
                    pstmt.setInt( 1, ft.getFtypeid() );
                    //pstmt.setString( 2, ft.getUploadId() );
                    pstmt.setInt( 2, userId );
                    pstmt.setInt( 3, ft.getSortOrder() );
                    pstmt.executeUpdate();
                }
                pstmt.close();
            }

            stmt.close();
            return true;
        } catch( Exception ex )
        {
            db.reportError( ex, "Refseq.setSortTracks()" );
        }
        return false;
    }
    public boolean deleteSortTracks( DBAgent db, int userId ) throws SQLException
    {
        return setSortTracks( db, null, userId );
    }
    public boolean createSequenceDir( DBAgent db )
    {
        if( getRefSeqId().equals("#") ) return false;
        try
        {
            String seqDirName = Constants.SEQUENCESDIR + getRefSeqId();
            File seqDir = new File( seqDirName );
            if( !seqDir.mkdir() ) return false;

            File f = new File( seqDir, "refseq.info" );
            PrintStream out = new PrintStream( new FileOutputStream(f) );
            out.println( "databaseName: "+getDatabaseName() );
            out.println( "refseqName: "+getRefseqName() );
            out.println( "description: "+getDescription() );
            out.flush();
            out.close();

            Connection conn = db.getConnection( getDatabaseName() );
            PreparedStatement pstmt = conn.prepareStatement(
                "INSERT INTO fmeta (fname, fvalue) VALUES (?, ?)" );
            pstmt.setString( 1, "RID_SEQUENCE_DIR" );
            pstmt.setString( 2, seqDirName );
            pstmt.executeUpdate();
            pstmt.close();
            return true;
        } catch( Exception ex )
        {
            db.reportError( ex, "Refseq.createSequenceDir()" );
        }
        return false;
    }
    public File fetchSequenceDir( DBAgent db )
    {
        File rc = null;
        try
        {
            Connection conn = db.getConnection( getDatabaseName() );
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery(
                "SELECT fvalue FROM fmeta WHERE fname='RID_SEQUENCE_DIR'" );
            if( rs.next() )
            {
                String fName = rs.getString(1);
                if( !Util.isEmpty(fName) ) rc = new File( fName );
            }
            stmt.close();
        } catch( Exception ex )
        {
            db.reportError( ex, "Refseq.fetchSequenceDir()" );
        }
        return rc;
    }

    public File[] fetchAnnotationDataFilesDirs( DBAgent db )
    {
        File[] rc = null ;
        if(refSeqId == null || refSeqId.equals("#") )
        {
          System.err.println("ERROR in Refseq.fetchAnnotationDataFilesDirs(), refSeqId is not set.") ;
          return null ;
        }
        // Get dir path from config file
        String dirPathName = GenboreeConfig.getConfigParam("gbAnnoDataFilesDir") ;
        System.err.println("FETCHING ANNO DIRS")        ;
        try
        {
            // Get the groups that the refseq is linked to
            Connection conn = db.getConnection() ;
            if( conn == null ) return null ;
            PreparedStatement pstmt = null ;
            ResultSet rs = null ;
            // Get the refseqName, if it isn't set.
            if(refseqName == null || refseqName.equals("") )
            {
              pstmt = conn.prepareStatement("SELECT refseqName FROM refseq WHERE refSeqId=?") ;
              pstmt.setString( 1, refSeqId ) ;
              rs = pstmt.executeQuery() ;
              if(rs != null && rs.next())
              {
                refseqName = rs.getString(1) ;
              }
            }
            String refseqNameEsc = Util.urlEncode(refseqName) ;
            String qs = "SELECT gr.groupId, gg.groupName FROM grouprefseq gr, genboreegroup gg WHERE gr.groupId=gg.groupId AND gr.refSeqId=?" ;
            pstmt = conn.prepareStatement(qs) ;
            pstmt.setString( 1, refSeqId ) ;
            rs = pstmt.executeQuery() ;
            Vector v = new Vector() ;
            while( rs.next() )
            {
                String grpName = rs.getString(2) ;
                String grpNameEsc = Util.urlEncode(grpName) ;
                String grpDirPathName = dirPathName + "grp/" + grpNameEsc + "/db/" + refseqNameEsc ;
                File grpDirPathFile = new File( grpDirPathName ) ;
                v.addElement( grpDirPathFile ) ;
            }
            pstmt.close();
            rc = new File[ v.size() ];
            v.copyInto( rc );
        } catch( Exception ex ) {
            System.err.println("Error in Refseq.fetchAnnotationDataFilesDirs") ;
            ex.printStackTrace() ;
            db.reportError( ex, "Refseq.fetchAnnotationDataFilesDirs()" );
        }

        return rc;
    }

    public File getSeqFile()
    {
        return seqFile; }
    public File getDeflineFile()
    {
        return deflineFile;
    }
    public boolean fetchSequenceFiles( DBAgent db, String epId )
    {
        try
        {
            seqFile = deflineFile = null;

            Connection conn = db.getConnection( getDatabaseName() );
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery(
                "SELECT fvalue FROM fmeta WHERE fname='RID_SEQUENCE_DIR'" );
            File dirFile = null;
            if( rs.next() )
            {
                String fName = rs.getString(1);
                if( !Util.isEmpty(fName) ) dirFile = new File( fName );
            }
            stmt.close();
            if( dirFile == null ) return false;

            String qs = "SELECT r.seqFileName, r.deflineFileName "+
                "FROM ridSequence r, rid2ridSeqId rr, fref f "+
                "WHERE r.ridSeqId=rr.ridSeqId AND rr.rid=f.rid AND f.refname=?";
            PreparedStatement pstmt = conn.prepareStatement( qs );
            pstmt.setString( 1, epId );
            rs = pstmt.executeQuery();
            if( rs.next() )
            {
                String seqName = rs.getString(1);
                if( !Util.isEmpty(seqName) ) seqFile = new File( dirFile, seqName );
                String deflineName = rs.getString(2);
                if( !Util.isEmpty(deflineName) ) deflineFile = new File( dirFile, deflineName );
            }
            pstmt.close();

        } catch( Exception ex ) {}
        return seqFile != null;
    }
    public GenboreeUpload getRootUpload()
    {
        return rootUpload;
    }
    public int deleteData( DBAgent db, boolean del_refs ) throws SQLException
    {
        if( getRefSeqId().equals("#") ) return 0;

        CacheManager.clearCache( db, this );

        rootUpload = new GenboreeUpload();
        rootUpload.setDatabaseName( getDatabaseName() );
        rootUpload.setRefSeqId( Util.parseInt(getRefSeqId(),-1) );
        if( !rootUpload.fetchByDatabase(db) ) return 0;
        try
        {
            Connection conn = db.getConnection( getDatabaseName() );
            Statement stmt = conn.createStatement();
            int nr = stmt.executeUpdate( "DELETE FROM fdata2" );
            stmt.executeUpdate( "DELETE FROM fdata2_cv" );
            stmt.executeUpdate( "DELETE FROM fdata2_gv" );
            stmt.executeUpdate( "DELETE FROM featuretocolor" );
            stmt.executeUpdate( "DELETE FROM featuretostyle" );
            stmt.executeUpdate( "DELETE FROM featuretolink" );
            stmt.executeUpdate( "DELETE FROM fidText" );
            try
            {
                stmt.executeUpdate( "DELETE FROM featureurl" );
			} catch( Exception ex ) {}
            //stmt.executeUpdate( "DELETE FROM featuresort WHERE uploadId="+rootUpload.getUploadId() );
            stmt.executeUpdate(
                "DELETE FROM ftype WHERE fmethod<>'Component' AND fmethod<>'Supercomponent'" );
            stmt.executeUpdate(
                "DELETE FROM gclass WHERE gclass<>'Sequence'" );
            if( del_refs )
            {
                stmt.executeUpdate( "DELETE FROM fref" );
            }
            return nr;
        } catch( Exception ex )
        {
            db.reportError( ex, "Refseq.deleteData()" );
        }
        return 0;
    }
    protected boolean createRootUpload( DBAgent db ) throws SQLException
    {
      int i;
      DbResourceSet dbRes = null;
      ResultSet rs = null;
      String dbName = null ;
      GenboreeUpload u = new GenboreeUpload();

      // Keep generating new names until we get one that is not in use.
      boolean foundUniqDbName = false ;
      String uniqDbName = null ;
      long retryCounter = 0 ;
      while(!foundUniqDbName)
      {
        // Make "uniq" name using conservative approach:
        uniqDbName = Util.generateUniqueString("" + retryCounter) ;
        dbName = "genboree_r_" + uniqDbName ;
        // Check if database name in use already (ties when lots of people at same time, like workshops)
        boolean inUse = RefSeqTable.hasDatabaseName(databaseName) ;
        if(inUse)
        {
          retryCounter += 1 ;
          foundUniqDbName = false ;
        }
        else
        {
          foundUniqDbName = true ;
        }
      }

      u.setDatabaseName( dbName );
      u.setConfigFileName( dbName+".conf" );

      db.executeUpdate( null, "CREATE DATABASE "+dbName );
      Connection conn = db.getConnection( dbName );
      if( conn == null ) return false;

      Statement stmt = conn.createStatement();
      for( i=0; i<dbSchema.length; i++ ) stmt.executeUpdate( dbSchema[i] );
      stmt.close();
      dbRes =  db.executeQuery( "SELECT name, description FROM style" );
      rs = dbRes.resultSet;
      PreparedStatement pstmt = conn.prepareStatement( "INSERT INTO style (name, description) VALUES (?, ?)" );
      while( rs.next() )
      {
          pstmt.setString( 1, rs.getString(1) );
          pstmt.setString( 2, rs.getString(2) );
          pstmt.executeUpdate();
      }
      pstmt.close();
      dbRes.close();

      dbRes =  db.executeQuery( "SELECT value FROM color" );
      rs = dbRes.resultSet;
      pstmt = conn.prepareStatement( "INSERT INTO color (value) VALUES (?)" );
      while( rs.next() )
      {
          pstmt.setString( 1, rs.getString(1) );
          pstmt.executeUpdate();
      }
      pstmt.close();

      rootUpload = u;
      setDatabaseName( dbName );

      return true;
    }
    public boolean create( DBAgent db, String groupId ) throws SQLException
    {
        if( !getRefSeqId().equals("#") ) return false;
        Connection conn = db.getConnection( null, false );
        if( conn != null ) try
        {
            setMapmaster( "http://localhost/java-bin/das" );

            createRootUpload( db );

            PreparedStatement pstmt = conn.prepareStatement(
                "INSERT INTO refseq (userId, "+
                "refseqName, description, mapmaster, databaseName, "+
                "refseq_species, refseq_version, FK_genomeTemplate_id, merged) "+
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)" );
            pstmt.setString( 1, getUserId() );
            pstmt.setString( 2, getRefseqName() );
            pstmt.setString( 3, getDescription() );
            pstmt.setString( 4, getMapmaster() );
            pstmt.setString( 5, getDatabaseName() );
            pstmt.setString( 6, getRefseq_species() );
            pstmt.setString( 7, getRefseq_version() );
            pstmt.setString( 8, getFK_genomeTemplate_id() );
            pstmt.setString( 9, getMerged() );
            pstmt.executeUpdate();
            int rsId = db.getLastInsertId( conn );
            setRefSeqId( ""+rsId );
            pstmt.close();

            rootUpload.setRefSeqId( rsId );
            rootUpload.setUserId( Util.parseInt(getUserId(),-1) );
            rootUpload.setUserDbName( getRefseqName() );
            rootUpload.insert( db );

            db.executeUpdate( null, "INSERT INTO refseq2upload (uploadId, refSeqId) "+
                "VALUES ("+rootUpload.getUploadId()+", "+getRefSeqId()+")" );

            if( groupId != null )
            {
                db.executeUpdate( null, "INSERT INTO grouprefseq (groupId, refSeqId)"+
                    "VALUES ("+groupId+", "+getRefSeqId()+")" );
            }

            createSequenceDir( db );

//            conn.close();
            return true;
        } catch( Exception ex )
        {
            db.reportError( ex, "Refseq.create()" );
        }
        return false;
    }
    public int getCurLine()
    {
        return curLine;
    }
    public int getNumRecords()
    {
        return numRecords;
    }
    protected int metaIndexOf( String s )
    {
        for( int i=0; i<metaData.length; i++ ) if( s.equals(metaData[i]) ) return i;
        return -1;
    }
    protected String getMeta( String[] d, String key )
    {
        int idx = metaIndexOf( key );
        if( idx >= 0 && idx < d.length ) return d[idx];
        return null;
    }
    public int getNumErrors()
    {
        return errs.size();
    }
    public String getErrorAt( int i )
    {
        return (String) errs.elementAt(i);
    }
    protected void reportError( String msg )
    {
        String prefx = is_error ? "\t" : "Error in line "+getCurLine()+": ";
        errs.addElement( prefx+msg );
        is_error = true;
    }
    public String[] getNewFtypes()
    {
        return newFtypes;
    }
    public DbGclass returnGclassCaseInsensitiveKey(String gclass)
    {
        DbGclass tempRc = null;
        if( gclass == null ) return null;
        for( Enumeration en=htGclass.keys(); en.hasMoreElements(); )
        {
            String tempKey = (String) en.nextElement();
            if(gclass.equalsIgnoreCase(tempKey))
            {
                tempRc = (DbGclass) htGclass.get( tempKey );
                return tempRc;
            }
        }
        return null;
    }
    protected DbGclass defineGclass( String gclass )
    {
        DbGclass rc = returnGclassCaseInsensitiveKey(gclass);
        if( rc == null )
        {
            rc = new DbGclass();
            rc.setGclass( gclass );
            rc.insert( _upldConn );
            htGclass.put( gclass, rc );
        }
        return rc;
    }
    protected DbFtype defineFtype( String _method, String _source )
    {
        String methodUC =  _method.toUpperCase();
        String sourceUC =  _source.toUpperCase();
        String ftKey = methodUC+":"+sourceUC;
        DbFtype ft = (DbFtype) htFtype.get( ftKey );
        if( ft == null )
        {
            ft = new DbFtype();
            ft.setFmethod( _method );
            ft.setFsource( _source );
            ft.insert( _upldConn );
            htFtype.put( ftKey, ft );
            vFtype.addElement( ftKey );
        }
        return ft;
    }

    /* TODO May be obsolete */
    protected void addFtypeToGroup( DbFtype ft, DbGclass gc )
    {
        Vector v = (Vector) htFtypeGclass.get( ft );
        if( v == null )
        {
            v = new Vector();
            htFtypeGclass.put( ft, v );
        }
        String gid = ""+gc.getGid();
        if( !v.contains(gid) ) v.addElement( gid );
    }
    public void initializeUpload( DBAgent db, String userId, String groupId, String uploadName,
        int _refSeqId, boolean is_new, String studName ) throws SQLException
    {
        initializeUpload( db, userId, groupId, uploadName, _refSeqId );
    }
    public void initializeUpload( DBAgent db,
        String userId, String groupId, String uploadName, int _refSeqId ) throws SQLException
    {


        boolean is_new = (getRefSeqId().equals("#") && _refSeqId < 0);
        int genboreeUserId = Util.parseInt(userId, -1);

        if( is_new )
        {
            if( uploadName != null ) setRefseqName( uploadName );
            if( !create(db, groupId) ) return;
        }
        else
        {
            CacheManager.clearCache( db, this );

            if( _refSeqId > 0 )
            {
                setRefSeqId( ""+_refSeqId );
                if( !fetch(db) ) return;
            }
            else _refSeqId = Util.parseInt( getRefSeqId(), -1 );
            rootUpload = new GenboreeUpload();
            rootUpload.setDatabaseName( getDatabaseName() );
            rootUpload.setRefSeqId( _refSeqId );
            if( !rootUpload.fetchByDatabase(db) ) return;
        }

        _db = db;
        _conn = db.getConnection();
        _upldConn = db.getConnection( getDatabaseName(), false );
        currPstmt = currPstmtCV = currPstmtGV = currPstmtSeq = getTextStatement = null;
        currStmtFid = null;
        int i;

        setGclass2ftypesHash();
        curLine = 0;
        numRecords = 0;
        first_line = true;
        currSect = "annotations";
        metaData = metaAnnotations;

        errs = new Vector();
        is_error = false;

        minFbin = 1000L;
        maxFbin = 100000000L;
        htGclass = new Hashtable();
        htFref = new Hashtable();
        htFtype = new Hashtable();
        htFtypeGclass = new Hashtable();
        vFtype = new Vector();

        try
        {
            PreparedStatement pstmt = _upldConn.prepareStatement(
                "SELECT fvalue FROM fmeta WHERE fname=?" );
            pstmt.setString( 1, "MIN_BIN" );
            ResultSet rs = pstmt.executeQuery();
            if( rs.next() ) minFbin = rs.getLong(1);
            pstmt.setString( 1, "MAX_BIN" );
            rs = pstmt.executeQuery();
            if( rs.next() ) maxFbin = rs.getLong(1);
            pstmt.close();

            DbGclass[] gcs = DbGclass.fetchAll( _upldConn );
            for( i=0; i<gcs.length; i++ ){
                htGclass.put( ""+gcs[i].getGclass(), gcs[i] );
            }

            DbFref[] frs = DbFref.fetchAll( _upldConn );
            for( i=0; i<frs.length; i++ )
            {
                htFref.put( frs[i].getRefname(), frs[i] );
            }

            DbFtype[] tps = DbFtype.fetchAll( _upldConn, getDatabaseName(), genboreeUserId );
            if( tps != null )
            for( i=0; i<tps.length; i++ )
            {
                DbFtype ft = tps[i];
                String methodUC = ft.getFmethod();
                methodUC = methodUC.toUpperCase();
                String sourceUC = ft.getFsource();
                sourceUC = sourceUC.toUpperCase();
                htFtype.put( methodUC+":"+sourceUC, ft );
            }

        } catch( Exception ex )
        {
            db.reportError( ex, "Refseq.initializeUpload()" );
        }
    }
    public boolean terminateUpload()
    {
        boolean rc = false;
        if( _db == null ) return false;
        try
        {
            long updMaxFbin = maxFbin;
            long fb = 0L;
            Statement stmt = _upldConn.createStatement();
            ResultSet rs = stmt.executeQuery( "SELECT MAX(fbin) FROM fdata2" );
            if( rs.next() )
            {
                fb = rs.getLong(1);
                if( fb > updMaxFbin ) updMaxFbin = fb;
            }
            rs = stmt.executeQuery( "SELECT MAX(fbin) FROM fdata2_cv" );
            if( rs.next() )
            {
                fb = rs.getLong(1);
                if( fb > updMaxFbin ) updMaxFbin = fb;
            }
            rs = stmt.executeQuery( "SELECT MAX(fbin) FROM fdata2_gv" );
            if( rs.next() )
            {
                fb = rs.getLong(1);
                if( fb > updMaxFbin ) updMaxFbin = fb;
            }
            maxFbin = 1000000L;
            while( updMaxFbin > maxFbin )
            {
                maxFbin *= 10;
                if( maxFbin < 1000000L ) break;
            }
            stmt.executeUpdate( "UPDATE fmeta SET fvalue='"+maxFbin+"' WHERE fname='MAX_BIN'" );
            stmt.close();

            newFtypes = new String[ vFtype.size() ];
            vFtype.copyInto( newFtypes );

            insertNewValuesGclass2FtypesHash();

            rc = true;
        } catch( Exception ex )
        {
            _db.reportError( ex, "Refseq.terminateUpload()" );
        }
        _db = null;
        _conn = null;
        _upldConn = null;
        currPstmt = currPstmtCV = currPstmtGV = currPstmtSeq = getTextStatement = null;
        currStmtFid = null;
        htGclass = null;
        htFref = null;
        htFtype = null;
        vFtype = null;
        htFtypeGclass = null;
        return rc;
    }
    protected void consumeReferencePoints( String[] d )
    {
        String[] rpt = new String[3];
        rpt[0] = getMeta( d, "id" );
        rpt[1] = getMeta( d, "class" );
        rpt[2] = getMeta( d, "length" );
        doConsumeReferencePoints( rpt );
    }
    protected void consumeAssembly( String[] d )
    {
        String[] rpt = new String[3];
        rpt[0] = getMeta( d, "id" );
        rpt[1] = getMeta( d, "class" );
        rpt[2] = getMeta( d, "end" );
        doConsumeReferencePoints( rpt );
    }
    protected void deleteTextSequences(long fid, int typeId, char type) throws SQLException
    {

        Statement stmt = _upldConn.createStatement();
        int nrecs = stmt.executeUpdate( "DELETE FROM fidText where fid = "
                + fid + " and ftypeid = " + typeId + " and TextType ='" + type + "'" );

    }
    protected void consumeTextSequences(long fid, int typeId, char type, String data) throws SQLException
    {
        if(Util.isEmpty(data)) return;

        if( currPstmtSeq == null )
        {
            currPstmtSeq = _upldConn.prepareStatement(
                    "INSERT INTO fidText (fid, ftypeid, textType, text) VALUES (?, ?, ?, ?)" );
        }
        currPstmtSeq.setLong( 1, fid );
        currPstmtSeq.setInt( 2, typeId );
        currPstmtSeq.setString( 3, String.valueOf(type) );
        currPstmtSeq.setString( 4, data );
        currPstmtSeq.executeUpdate();

        return;
    }
    protected void doConsumeReferencePoints( String[] rpt )
    {
        is_error = false;
        if( rpt[0]==null || rpt[1]==null || rpt[2]==null )
        {
            reportError( "Invalid format of entry point record" );
            return;
        }

        String _id = rpt[0].trim();
        if( htFref.get(_id) != null ) return;
        long len = Util.parseLong( rpt[2], -1L );
        if( len < 1L )
        {
            reportError( "Invalid length parameter" );
            return;
        }

        DbFref fref = new DbFref();
        fref.setRefname( _id );
        fref.setRlength( ""+len );
        fref.setGname( rpt[1].trim() );

        String sFbin = computeBin( 1L, len, minFbin );
        fref.setRbin( sFbin );
        try
        {
            DbGclass gclass = defineGclass( "Sequence" );
            fref.setGid( gclass.getGid() );

            DbFtype ft = defineFtype( "Component", "Chromosome" );
            fref.setFtypeid( ft.getFtypeid() );

            fref.insert( _upldConn );

            htFref.put( _id, fref );
        } catch( Exception ex )
        {
            _db.reportError( ex, "Refseq.consumeReferencePoints()" );
        }
    }
    double myRound(double value, int decimalPlace)
    {
        double power_of_ten = 1;
        while (decimalPlace-- > 0)
            power_of_ten *= 10.0;
        return Math.round(value * power_of_ten)
                / power_of_ten;
    }
    protected String getMaxInsertedValue( String d , int maxValue)
    {
        char key = '.';
        String maxInsertedValue;
        int idx = d.indexOf(key);
        if( idx >= 0 && idx < d.length() )
        {
            if((idx + maxValue) < d.length())
            {
                maxInsertedValue = d.substring(0, (idx+ maxValue));
                return maxInsertedValue;
            }
            else return d;
        }
        return d + ".0";
    }

    public String removeExtraClasses(String originalComments)
    {
        String[] tokens = null;
        StringBuffer stringBuffer = null;

        if(originalComments == null) return null;

        stringBuffer = new StringBuffer( 200 );
        if(originalComments.indexOf(';') > -1)
            tokens = originalComments.split(";");
        else
        {
            tokens = new String[1];
            tokens[0] = originalComments;
        }

        for( int i = 0; i < tokens.length; i++)
        {
            String comment = tokens[i].trim();
            if(comment.startsWith("aHClasses=")) { }
            else
            {
                stringBuffer.append(comment);
                stringBuffer.append(";");
                if(i < (tokens.length - 1))
                {
                    stringBuffer.append(" ");
                }
            }
        }

        return stringBuffer.toString();
    }

    public String extractExtraClasses(String originalComments)
    {
        String[] tokens = null;


        if(originalComments == null) return null;
        if(originalComments.indexOf(';') > -1)
            tokens = originalComments.split(";");
        else
        {
            tokens = new String[1];
            tokens[0] = originalComments;
        }

        for( int i = 0; i < tokens.length; i++)
        {
            String comment = tokens[i].trim();
            if(comment.startsWith("aHClasses="))
            {
               comment = comment.replaceFirst("aHClasses=", "");
               return comment;
            }
        }

        return null;
    }

    protected void consumeAnnotations( String[] d ) throws SQLException
    {
        is_error = false;
        boolean useNewClassName = false;
        String _class = getMeta( d, "class" );      // gclass.gclass
        String _name = getMeta( d, "name" );        // fdata2.gname
        String _type = getMeta( d, "type" );        // ftype.fmethod
        String _subtype = getMeta( d, "subtype" );  // ftype.fsource
        String _ref = getMeta( d, "ref" );          // fref.refname
        String extraClasses = null;
        String insertForFdata2 =  "INSERT IGNORE INTO fdata2 ";
        String insertForFdataCV = "INSERT IGNORE INTO fdata2_cv ";
        String insertForFdataGV = "INSERT IGNORE INTO fdata2_gv ";
        String  qs = "(rid, fstart, fstop, fbin, ftypeid, fscore, fstrand, fphase, "+
               "ftarget_start, ftarget_stop, gname) ";
        String  values =   "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
        int sucess = 0;
        if( _class==null || _name==null || _type==null || _subtype==null || _ref==null )
        {
            reportError( "Invalid format of annotation record" );
            return;
        }

       if(getByPassClassName() && getNameNewClass() != null)
            useNewClassName = true;

        if(useNewClassName)
            _class = getNameNewClass().trim();
        else
            _class = _class.trim();
        _name = _name.trim();
        _type = _type.trim();
        _subtype = _subtype.trim();
        _ref = _ref.trim();

        for( Enumeration en = htFref.keys(); en.hasMoreElements(); )
        {
            DbFref ft = (DbFref) htFref.get(en.nextElement());
        }

        DbFref fref = (DbFref) htFref.get( _ref );
        if( fref == null )
        {
            reportError( "Undefined entry point" );
            return;
        }

        long  epLen = Util.parseLong( fref.getRlength(), -1L );

        long _fstart = Util.parseLong( getMeta(d, "start"), -1L );
        long _fstop = Util.parseLong( getMeta(d, "stop"), -1L );

        if( _fstart<0L || _fstart>epLen )
        {
            reportError( "fstart must be within 0.."+epLen );
            return;
        }
        if( _fstop<=1L ) reportError( "fstop must be greater than 0" );
        if( _fstart > _fstop ) reportError( "fstart must be less than fstop" );

        String _fstrand = getMeta(d, "strand");
        String _fphase = getMeta(d, "phase" );
        double _fscore = 0.;

        try
        {
            _fscore = Double.parseDouble( getMeta(d, "score") );
        } catch( Throwable thr ) {}

        if( !_fstrand.equals("+") && !_fstrand.equals("-") && !_fstrand.equals(".") )
            reportError( "Strand must be either '+', '-', or '.'" );
        if( is_error ) return;

        long _ftarget_start = Util.parseLong( getMeta(d, "tstart"), -1L );
        long _ftarget_stop = Util.parseLong( getMeta(d, "tend"), -1L );

        if( _ftarget_start<0L ) _ftarget_start = 0L;
        if( _ftarget_stop < 0L) _ftarget_stop = 0L;

        String _text = null;
        String _seq = null;
        String data = null;
        String[] tokens = null;
        char typeOfNote = ' ';

        if(! _name.endsWith("_CV") && !_name.endsWith("_GV"))
        {
            _seq = getMeta( d, "sequence" );
            _text = getMeta( d, "text" );
            if( _text != null && _text.equals(".") ) _text = null;
            if( _seq != null && _seq.equals(".") ) _seq = null;
            if(_text != null)
            {
                extraClasses = extractExtraClasses(_text);
                _text = removeExtraClasses(_text);
	            if(extraClasses != null)
        	        tokens = extraClasses.split(",");
            }
        }

        try
        {
            if( currPstmt == null )
            {
                currPstmt = _upldConn.prepareStatement( insertForFdata2 + qs + values);
                currPstmtCV = _upldConn.prepareStatement( insertForFdataCV + qs + values);
                currPstmtGV = _upldConn.prepareStatement( insertForFdataGV + qs + values );
            }

            PreparedStatement pstmt = currPstmt;
            if( _name.endsWith("_CV") ) pstmt = currPstmtCV;
            else if( _name.endsWith("_GV") ) pstmt = currPstmtGV;

            DbGclass gclass = defineGclass( _class );

            DbFtype ft = defineFtype( _type, _subtype );

            addToGclass2ftypesHash(_class, _type, _subtype, gclass.getGid() , ft.getFtypeid());

            if(tokens != null)
            {
            	for(int i = 0; i < tokens.length; i++)
            	{
               		 DbGclass newgclass = defineGclass( tokens[i] );
                	addToGclass2ftypesHash(tokens[i], _type, _subtype, newgclass.getGid() , ft.getFtypeid());
            	}
            }


            String sFbin = computeBin( _fstart, _fstop, minFbin );

            pstmt.setInt( 1, fref.getRid() );
            pstmt.setLong( 2, _fstart );
            pstmt.setLong( 3, _fstop );
            pstmt.setString( 4, sFbin );
            pstmt.setInt( 5, ft.getFtypeid() );
            pstmt.setDouble( 6, _fscore );
            pstmt.setString( 7, _fstrand );
            pstmt.setString( 8, _fphase );
            pstmt.setLong( 9, _ftarget_start );
            pstmt.setLong( 10, _ftarget_stop );
            pstmt.setString( 11, _name );

            sucess = pstmt.executeUpdate();
            if(sucess == 1)
            {
                numRecords++;

                long fid = 0;
                currStmtFid = _upldConn.createStatement();
                ResultSet rs = currStmtFid.executeQuery( "SELECT LAST_INSERT_ID()" );
                if( rs.next() ) fid = rs.getLong(1);
                else return;

                if( !Util.isEmpty(_text) )
                {
                    if(_text.equals(".")) { }
                    else
                    {
                        typeOfNote = 't';
                        data = _text;
                        consumeTextSequences(fid, ft.getFtypeid(), typeOfNote, data);
                    }
                }

                if( !Util.isEmpty(_seq) )
                {
                    if(_seq.equals(".")) { }
                    else
                    {
                        typeOfNote = 's';
                        data = _seq;
                        consumeTextSequences(fid, ft.getFtypeid(), typeOfNote, data);
                    }
                }
            }
            else
            {
                double delta = 0.0000001;
                String newPhase;
                String myFtargetStart;
                String myFtargetStop;

                Statement askForFid  = _upldConn.createStatement();
                if(_fphase.equals("0") || _fphase.equals("1") || _fphase.equals("2"))
                    newPhase = "= '" + _fphase + "'";
                else
                    newPhase = "is null or fphase = ''";
                if(_ftarget_start == 0)
                    myFtargetStart = "(ftarget_start = 0 or ftarget_start is NULL)";
                else
                    myFtargetStart = "ftarget_start = " + _ftarget_start;
                if(_ftarget_stop == 0)
                    myFtargetStop = "(ftarget_stop = 0 or ftarget_stop is NULL)";
                else
                    myFtargetStop = "ftarget_stop = " + _ftarget_stop;


                String selectFromFdata2 = "SELECT fid FROM fdata2 WHERE"
                        + " rid = " + fref.getRid()
                        + " and fstart = " + _fstart
                        + " and fstop = " + _fstop
                        + " and ftypeid = " + ft.getFtypeid()
                        + " and fscore between  " + (_fscore - delta) + " and " + (_fscore + delta)
                        + " and (fphase " + newPhase + ")"
                        + " and fstrand = '" + _fstrand + "'"
                        + " and " + myFtargetStart
                        + " and " + myFtargetStop
                        + " and gname = '" + _name + "'";

                String  selectTextFromFidText = "SELECT text FROM fidText where fid = ?"
                        + " and ftypeid = ? and textType = ?";
                long fid = 0;
                ResultSet tempRs;
                String comments = null;
                String sequence = null;

                ResultSet fidRs = askForFid.executeQuery(selectFromFdata2);

                if( fidRs.next() ) fid = fidRs.getLong(1);
                else
                {
/* Uncomment this part to print the select query
                    System.err.println("unable to find fid");
                    System.err.println("Query = " + selectFromFdata2);
                    System.err.flush();
 Until hete to see the query */
                    return;
                }


               if( getTextStatement == null )
                    getTextStatement = _upldConn.prepareStatement(selectTextFromFidText);

                getTextStatement.setLong(1, fid);
                getTextStatement.setInt(2, ft.getFtypeid());
                getTextStatement.setString( 3, String.valueOf('t') );
                tempRs =  getTextStatement.executeQuery();
                if( tempRs.next() )
                    comments = tempRs.getString(1);

                getTextStatement.setLong(1, fid);
                getTextStatement.setInt(2, ft.getFtypeid());
                getTextStatement.setString( 3, String.valueOf('s') );
                tempRs =  getTextStatement.executeQuery();
                if( tempRs.next() )
                    sequence = tempRs.getString(1);

                if(!Util.isEmpty(_text) && Util.isEmpty(comments))
                {
                    if(_text.equals(".")) { }
                    else
                    {
                        typeOfNote = 't';
                        data = _text;
                        consumeTextSequences(fid, ft.getFtypeid(), typeOfNote, data);
                    }
                }

                if(!Util.isEmpty(_seq) && Util.isEmpty(sequence))
                {
                    if(_seq.equals(".")) { }
                    else
                    {
                        typeOfNote = 's';
                        data = _seq;
                        consumeTextSequences(fid, ft.getFtypeid(), typeOfNote, data);
                    }
                }

                if(!Util.isEmpty(_text) && !Util.isEmpty(comments))
                {
                    if(_text.equals(".")) { }
                    else if(!comments.equals(_text))
                    {
                        typeOfNote = 't';
                        data = _text;
                        deleteTextSequences(fid, ft.getFtypeid(), typeOfNote);
                        consumeTextSequences(fid, ft.getFtypeid(), typeOfNote, data);
                    }
                }


                if(!Util.isEmpty(_seq) && !Util.isEmpty(sequence)){
                    if(_seq.equals(".")) { }
                    else if(!sequence.equals(_seq))
                    {
                        typeOfNote = 's';
                        data = _seq;
                        deleteTextSequences(fid, ft.getFtypeid(), typeOfNote);
                        consumeTextSequences(fid, ft.getFtypeid(), typeOfNote, data);
                    }
                }

            }

        } catch( Exception ex )
        {
            int errc = 0;
            if( ex instanceof SQLException ) errc = ((SQLException)ex).getErrorCode();
            if( errc != 1062 ) _db.reportError( ex, "Refseq.consumeAnnotations()" );
        }
    }
    public void setIgnoreFlags( boolean ignore_refseq, boolean ignore_assembly,
        boolean ignore_annotations )
    {
        this.ignore_refseq = ignore_refseq;
        this.ignore_assembly = ignore_assembly;
        this.ignore_annotations = ignore_annotations;
    }
    public void consume( String s )
    {
        curLine++;
        String ss = s.trim().toLowerCase();
        if( ss.startsWith("[annotations]") )
        {
            currSect = "annotations";
            metaData = metaAnnotations;
            first_line = true;
            currPstmt = currPstmtCV = currPstmtGV = null;
            return;
        }
        else if( ss.startsWith("[assembly]") )
        {
            currSect = "assembly";
            metaData = metaAssembly;
            first_line = true;
            currPstmt = currPstmtCV = currPstmtGV = null;
            return;
        }
        else if( ss.startsWith("[reference_points]") || ss.startsWith("[references]") )
        {
            currSect = "reference_points";
            metaData = metaReferencePoints;
            first_line = true;
            currPstmt = currPstmtCV = currPstmtGV = null;
            return;
        }
        else if( ss.length() == 0 ) return;
        else if( ss.startsWith("#") )
        {
            // if( first_line ) metaData = Util.parseString( ss.substring(1), '\t' );
            first_line = false;
            return;
        }

        first_line = false;
        String[] data = Util.parseString( s, '\t' );
        if( currSect.equals("reference_points") )
        {
            if( !ignore_refseq )
                consumeReferencePoints( data );
        }
        else if( currSect.equals("assembly") )
        {
            if( !ignore_assembly )
                consumeAssembly( data );
        }
        else if( currSect.equals("annotations") )
        {
            if( !ignore_annotations )
                try {
                    consumeAnnotations( data );
                } catch (SQLException e) {
                    e.printStackTrace();  //To change body of catch statement use File | Settings | File Templates.
                }
        }
    }
    private static void printError( DBAgent db, PrintStream out )
    {
        String[] err = db.getLastError();
        db.clearLastError();
        if( err != null )
        for( int i=0; i<err.length; i++ ) out.println( err[i] );
    }
    public static Refseq[] recreateteRefseqListFromGroup( DBAgent db,  GenboreeGroup[] grps)
    {
        Refseq[] myRseqs = null;
        if(grps == null) return null;


        try {
            myRseqs = Refseq.fetchAll( db, grps );
        } catch (SQLException e) {
            System.err.println("Exception in the recreateRefseqListFromGroup with ");
            System.err.flush();
            return null;
            //e.printStackTrace();  //To change body of catch statement use File | Settings | File Templates.
        }

        if( myRseqs == null ) myRseqs = new Refseq[0];
        return myRseqs;

    }


    public Hashtable getGclass2ftypesHash()
    {
        return gclass2ftypesHash;
    }

    public void addToGclass2ftypesHash(String gname, String fmethod, String fsource, int gid, int ftypeid)
    {
        String myKey = null;
        String myValue = null;
        String previousSortingValue = null;


        if(gname == null || fmethod == null || fsource == null) return;
        String methodUC = fmethod.toUpperCase();
        String sourceUC = fsource.toUpperCase();

        myKey = gname + ":" + methodUC + ":" + sourceUC;
        myValue = "(" + ftypeid + ", " + gid + ")";
        Hashtable myGclass2ftypesHash = null;
        myGclass2ftypesHash = getGclass2ftypesHash();

        previousSortingValue = (String)gclass2ftypesHash.get(myKey);
        if(previousSortingValue == null)
            gclass2ftypesHash.put(myKey, myValue);
    }

    public void insertNewValuesGclass2FtypesHash()
    {
        StringBuffer query = null;
        String qs = null;
        query = new StringBuffer( 200 );
        Hashtable myGclass2ftypesHash = null;
        String deleteQuery = "DELETE FROM ftype2gclass";
        String[] processedList = null;
        Statement stmt = null;

        myGclass2ftypesHash = getGclass2ftypesHash();

        if(myGclass2ftypesHash != null && myGclass2ftypesHash.size() > 0)
        {

            query.append("INSERT INTO ftype2gclass VALUES ");
            Vector inserts = new Vector();
            for( Enumeration en = myGclass2ftypesHash.keys(); en.hasMoreElements(); )
            {
                String myValue = (String)myGclass2ftypesHash.get( en.nextElement() );
                inserts.addElement(myValue);
            }

            processedList = new String[ inserts.size() ];
            inserts.copyInto( processedList );

            for( int j=0; j< processedList.length; j++ )
            {
                query.append(processedList[j]);
                if(j < (processedList.length -1))
                    query.append(", ");
            }


            qs = query.toString();

            try
            {
                stmt = _upldConn.createStatement();

            } catch( Exception ex ) {
                System.err.println("Exception during createStatement for ftype2gclass");
                System.err.flush();
            }

            try{
                stmt.executeUpdate( deleteQuery );
             } catch( Exception ex ) {
                System.err.println("Exception during deletion of data from ftype2gclass");
                System.err.println("Databasename = " + getDatabaseName());
                System.err.println("The delete query is " + deleteQuery);
                System.err.flush();
            }

            try{
                stmt.executeUpdate(qs);
            } catch( Exception ex ) {
                System.err.println("Exception during uploading data into ftype2gclass");
                System.err.println("Databasename = " + getDatabaseName());
                System.err.println("The insert query is " + qs);
                System.err.flush();
            }
            try{
                stmt.close();

            } catch( Exception ex ) {
                System.err.println("Exception during closing the connection for ftype2gclass");
                System.err.println("Databasename = " + getDatabaseName());
                System.err.flush();
            }
        }

        return;
    }

    public void setGclass2ftypesHash()
    {
        StringBuffer query = null;
        String qs = null;
        String previousSortingValue = null;
        query = new StringBuffer( 200 );
        Hashtable myGclass2ftypesHash = null;
        myGclass2ftypesHash = getGclass2ftypesHash();

        gclass2ftypesHash = new Hashtable();

//        query.append("SELECT CONCAT(gclass.gclass,':', ftype.fmethod, ':',ftype.fsource) mykey ");
        query.append("SELECT gclass.gclass myClass,  ftype.fmethod myMethod, ftype.fsource mySource ");
        query.append(", CONCAT('(',ftype.ftypeid,', ', gclass.gid, ')') myvalues ");
        query.append("FROM ftype, gclass, ftype2gclass WHERE ");
        query.append("ftype.ftypeid = ftype2gclass.ftypeid AND gclass.gid = ftype2gclass.gid ");
        query.append("order by ftype.ftypeid,gclass.gid");
        qs = query.toString();


        try
        {
            Statement stmt = _upldConn.createStatement();
            ResultSet rs = stmt.executeQuery(qs);

            while( rs.next() )
            {
                String myClass = rs.getString("myClass");
                String myMethod = rs.getString("myMethod");
                String mySource = rs.getString("mySource");
                if(myClass == null || myMethod == null || mySource == null)
                {
                    continue;
                }
                myMethod = myMethod.toUpperCase();
                mySource = mySource.toUpperCase();
                String myKey = myClass + ":" + myMethod + ":" + mySource;
                previousSortingValue = (String)gclass2ftypesHash.get(myKey);
                if(previousSortingValue == null)
                    gclass2ftypesHash.put(myKey, rs.getString("myValues"));
            }
            stmt.close();

        } catch( Exception ex ) {
            System.err.println("Exception during quering db in method Refseq.java#setGclass2ftypesHash()");
            System.err.println("Databasename = " + getDatabaseName());
            System.err.println("The query is ");
            System.err.println(query.toString());
            System.err.flush();
        }

        return;
    }

/*
    /www/jdks/j2sdk1.4.1_01/bin/java -classpath GDASServlet.jar org.genboree.dbaccess.Refseq -d 244 mouseSynteny.lff
    -a - delete just annotations
    -x - delete everything, including the ref.seq
*/
    public static void main( String[] args )
        throws Exception
    {
        int i;
        String cmd = (args.length > 0) ? args[0] : "-";
        if( cmd.startsWith("-") ) cmd = cmd.substring(1);
        cmd = cmd.toLowerCase();

        boolean del_only = false;
        if( cmd.startsWith("x") || cmd.startsWith("a") )
            del_only = true;
        else if( !(cmd.startsWith("d") || cmd.startsWith("l") || cmd.startsWith("e")) )
            cmd = null;
        int argl = 3;
        if( del_only ) argl = 2;
        if( args.length < argl || cmd == null )
        {
            System.out.println(
                "Usage: java org.genboree.dbaccess.Refseq -{d|l|e|a|x} <refSeqId> [<lffFile>]" );
            System.out.println( "  Options:" );
            System.out.println( "  -d <refSeqId> <lffFile> delete annotations and ref.sequence, then upload" );
            System.out.println( "  -l <refSeqId> <lffFile> upload" );
            System.out.println( "  -e <refSeqId> <lffFile> upload ref.sequence only, ignore annotations if any" );
            System.out.println( "  -a <refSeqId> delete annotations" );
            System.out.println( "  -x <refSeqId> delete annotations and ref.sequence" );
            System.exit(0);
        }
        char mode = cmd.charAt(0);

        DBAgent db = DBAgent.getInstance();
        Refseq rseq = new Refseq();
        rseq.setRefSeqId( args[1] );
        if( !rseq.fetch(db) )
        {
            System.err.println( "Invalid RefSeq ID: "+args[1] );
            System.exit(0);
        }

        if( mode == 'd' || del_only )
        {
            Connection conn = db.getConnection( rseq.getDatabaseName() );
            Statement stmt = conn.createStatement();
            int nrecs = 0;
            if( mode=='d' || mode=='x' )
            {
                nrecs = stmt.executeUpdate( "DELETE FROM fref" );
                System.out.println( ""+nrecs+" records deleted from `fref`" );
            }
            nrecs = stmt.executeUpdate( "DELETE FROM fdata2" );
            nrecs += stmt.executeUpdate( "DELETE FROM fdata2_cv" );
            nrecs += stmt.executeUpdate( "DELETE FROM fdata2_gv" );
            System.out.println( ""+nrecs+" records deleted from `fdata2*`" );
            stmt.close();
        }
        if( del_only ) System.exit(0);

        FileReader frd = new FileReader( args[2] );
        BufferedReader in = new BufferedReader( frd );

        rseq.initializeUpload( db, "0", "0", null, Util.parseInt(rseq.getRefSeqId(),-1) );
        if( db.getLastError() != null )
        {
            printError( db, System.err );
            System.exit(0);
        }

        if( mode=='e' || mode=='d' )
        {
            if( mode=='e' ) rseq.setIgnoreFlags( false, false, true );
            rseq.consume( "[reference_points]" );
        }
        else
        {
            rseq.consume( "[annotations]" );
        }

        String s;
        while( (s = in.readLine()) != null )
        {
            rseq.consume( s );
            if( rseq.getNumErrors() > 50 ) break;
        }
        rseq.terminateUpload();

        frd.close();

        int nerr = rseq.getNumErrors();
        for( i=0; i<nerr; i++ )
        {
            System.err.println( rseq.getErrorAt(i) );
        }

        System.exit(0);
    }





}
