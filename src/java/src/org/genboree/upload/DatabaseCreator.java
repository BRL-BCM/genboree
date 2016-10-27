package org.genboree.upload;


import org.genboree.util.Util;
import org.genboree.dbaccess.*;
import org.genboree.dbaccess.util.* ;

import java.io.*;
import java.sql.*;
import java.security.MessageDigest;

public class DatabaseCreator implements RefSeqParams , SQLCreateTable
{
    protected String databaseName;
    protected String refSeqId;
    protected String userId;
    protected String refseqName;
    protected String description;
    protected String refseq_species;
    protected String merged;
    protected String refseq_version;
    protected String FK_genomeTemplate_id;
    protected String mapmaster;
    protected final String mapMaster = "http://localhost/java-bin/das";
    protected String fastaDir;
    private DBAgent db;
    private String groupId;
    protected String uniqueName;
    protected boolean RefseqIdExist = false;
    protected int scid = -1;
    protected String baseDir = null;
    protected String sequenceDir = null;
    protected String srcFullDir = null;
    protected String targetFullDir = null;
    protected File srcDir = null;
    protected File tgtDir = null;
    protected int uploadId = -1;

    public int getUploadId()
    {
        return uploadId;
    }

    public String getSrcFullDir() {
        return srcFullDir;
    }


    public String getTargetFullDir() {
        return targetFullDir;
    }


    public File getSrcDir()
    {
        return srcDir;
    }


    public File getTgtDir()
    {
        return tgtDir;
    }


    public boolean isRefseqIdExist()
    {
        return RefseqIdExist;
    }

    public String getUniqueName() {
        return uniqueName;
    }

    public String getGroupId() {
        return groupId;
    }

    public String getFastaDir()
    {
        return fastaDir;
    }

    public String getFK_genomeTemplate_id()
    {
        return FK_genomeTemplate_id;
    }
    public String getRefseq_version()
    {
        return refseq_version;
    }
    public String getMerged()
    {
        return merged;
    }
    public String getRefseq_species()
    {
        return refseq_species;
    }
    public String getDescription()
    {
        return description;
    }
    public String getRefseqName()
    {
        return refseqName;
    }
    public int getUserIdInt()
    {
        return Util.parseInt(getUserId(),-1);
    }
    public String getUserId()
    {
        return userId;
    }
    private void createSequenceDir( ) throws Exception 
    {
        File seqDir = this.tgtDir;

        if(seqDir.exists())
        {
            if( seqDir.isDirectory() && seqDir.canWrite())
            {
            	File[] files = seqDir.listFiles();
                for(int i = 0; i < files.length; i++ )
                {
                        File sf = files[i];
                        if( sf.isDirectory() ) continue;
                        if(sf.canWrite()) sf.delete();
                }
            } else {
            	throw new RuntimeException("Cannot create sequence dir: there is a file with the same name: " + seqDir.getPath());
            }
        }
        else
        {
            if( ! seqDir.mkdir() )
            {
            	throw new RuntimeException("Cannot create sequence dir: mkdir() failed");
            }
        }

        File refSeqInfo = new File( seqDir, "refseq.info" );
        PrintStream out = new PrintStream( new FileOutputStream(refSeqInfo) );
        out.println( "databaseName: "+getDatabaseName() );
        out.println( "refseqName: "+getRefseqName() );
        out.println( "description: "+getDescription() );
        out.flush();
        out.close();
    }

    private void insertRidseqdir() throws Exception 
    {
        String insertQuery = "INSERT INTO fmeta (fname, fvalue) VALUES ("
                + "'RID_SEQUENCE_DIR', '" + this.targetFullDir + "')";
    	Connection conn = this.db.getConnection( getDatabaseName());
    	Statement stmt = conn.createStatement();
        stmt.executeUpdate(insertQuery);
        stmt.close();
    }


    private void setSequenceAndBaseDir() throws Exception 
    {
        String qs = "SELECT genomeTemplate_baseDir, genomeTemplate_sequenceDir "+
                "FROM genomeTemplate WHERE genomeTemplate_id="+this.FK_genomeTemplate_id;
    	Connection conn = this.db.getConnection();
    	Statement stmt = conn.createStatement();
    	ResultSet rs = stmt.executeQuery( qs );

        if( rs.next() )
        {
            baseDir = rs.getString(1);
            if( baseDir != null ) baseDir = baseDir.trim();
            sequenceDir = rs.getString(2);
            if( sequenceDir != null ) sequenceDir = sequenceDir.trim();
        }
        stmt.close();
        setSrcFullDir();
        setTargetFullDir();
        srcDir = retrieveDir("src");
        tgtDir = retrieveDir("target");
    }

    private void setSrcFullDir()
    {
        this.srcFullDir = baseDir + "/" + sequenceDir;
    }

    private void setTargetFullDir()
    {
        this.targetFullDir = baseDir + "/" + refSeqId;
    }

    private File retrieveDir(String type)
    {
        File rc = null;
        
        if(type.equalsIgnoreCase("src")) {
            rc = new File( this.srcFullDir );
        } else if(type.equalsIgnoreCase("target")) {
            rc = new File( this.targetFullDir );
        } else {
        	throw new RuntimeException("Unknown type: " + type);
        }

        return rc;
    }

    public String getSequenceDir()
    {
        return sequenceDir;
    }
    public String getBaseDir()
    {
        return baseDir;
    }

    private void createSequenceLinks( ) throws Exception
    {
        File[] lst = srcDir.listFiles();
        for(int i = 0; i < lst.length; i++ )
        {
        	File sf = lst[i];
            if( sf.isDirectory() ) continue;
            File tf = new File( tgtDir, sf.getName() );
            String cmdLine = "ln -s "+sf.getAbsolutePath()+" "+tf.getAbsolutePath();
            Process p = Runtime.getRuntime().exec( cmdLine );
            p.waitFor();
        }
    }
/* TODO - not used? to delete
    private boolean oldFillRidSequenceTable( )
    {
        DBAgent myDb = null;
        Connection conn = null;
        DbFref[] refs = null;
        PreparedStatement psRef = null;
        PreparedStatement psRid = null;
        File sf = null;
        File tf = null;
        String insertRidSequence = null;
        String insertRid2RidSequence = null;
        DbFref fr = null;
        String refname = null;
        String sn = null;
        String dn = null;
        int ridSeqId = -1;

        insertRidSequence = "INSERT INTO ridSequence (seqFileName, deflineFileName) VALUES (?, ?)";
        insertRid2RidSequence = "INSERT INTO rid2ridSeqId (rid, ridSeqId) VALUES (?, ?)";

        myDb = this.db;

        try {
            conn = myDb.getConnection( getDatabaseName() );

            refs = DbFref.fetchAll( conn );
            psRef = conn.prepareStatement(insertRidSequence);
            psRid = conn.prepareStatement(insertRid2RidSequence);

            for(int i=0; i<refs.length; i++ )
            {
                fr = refs[i];
                refname = fr.getRefname();
                sn = refname+".fa";
                dn = refname+".def";

                sf = new File( tgtDir, sn );
                tf = new File( tgtDir, dn );
                if( !sf.exists() || !tf.exists() ) continue;

                psRef.setString( 1, sn );
                psRef.setString( 2, dn );
                psRef.executeUpdate();
                ridSeqId = myDb.getLastInsertId( conn );
                psRid.setInt( 1, fr.getRid() );
                psRid.setInt( 2, ridSeqId );
                psRid.executeUpdate();
            }
            psRef.close();
            psRid.close();
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return true;
    }
*/

    private void fillRidSequenceTable( ) throws Exception 
    {
        int tempId = Util.parseInt(this.FK_genomeTemplate_id, -1);
        if (tempId <= 0) {
        	throw new RuntimeException("Invalid FK_genomeTemplate_id: " + this.FK_genomeTemplate_id);
        }
        
        String templateIdDatabaseName = "SELECT u.databaseName FROM template2upload as t, upload as u where u.uploadId = t.uploadId AND t.templateId = " + tempId;
        String selectRid2ridSequence = "SELECT rid,ridSeqId,offset,length FROM rid2ridSeqId";
        String insertRid2RidSequence = "INSERT INTO rid2ridSeqId (rid, ridSeqId, offset, length) VALUES (?, ?, ?, ?)";
        String selectRidSequence = "SELECT ridSeqId,seqFileName,deflineFileName FROM ridSequence";
        String insertRidSequence = "INSERT INTO ridSequence (ridSeqId, seqFileName, deflineFileName) VALUES (?, ?, ?)";

    	Connection genboreeCon = this.db.getConnection();
    	Statement templateQuery = genboreeCon.createStatement();
    	ResultSet rs = templateQuery.executeQuery(templateIdDatabaseName);
        
    	String templateDatabase = null;
    	if( rs.next() )
        {
            templateDatabase = rs.getString(1);
        }
    	if (templateDatabase == null) {
    		throw new RuntimeException("Cannot find template database with id: " + tempId);
    	}
    	
        Connection templateConn = this.db.getConnection( templateDatabase );
        Statement stSelectRid2ridSequence = templateConn.createStatement();
        Statement stSelectRidSequence = templateConn.createStatement();
        Connection conn = this.db.getConnection( this.databaseName );
        PreparedStatement psInsertRid2ridSequence = conn.prepareStatement(insertRidSequence);
        PreparedStatement psInsertRidSequence = conn.prepareStatement(insertRid2RidSequence);

        rs = stSelectRid2ridSequence.executeQuery(selectRid2ridSequence);
        while( rs.next() )
        {
            psInsertRidSequence.setInt(1, rs.getInt(1));
            psInsertRidSequence.setInt(2, rs.getInt(2));
            psInsertRidSequence.setInt(3, rs.getInt(3));
            psInsertRidSequence.setInt(4, rs.getInt(4));
            psInsertRidSequence.executeUpdate();
        }
        rs = stSelectRidSequence.executeQuery(selectRidSequence);
        while( rs.next() )
        {
            psInsertRid2ridSequence.setInt(1, rs.getInt(1));
            psInsertRid2ridSequence.setString(2, rs.getString(2));
            psInsertRid2ridSequence.setString(3, rs.getString(3));
            psInsertRid2ridSequence.executeUpdate();
        }

        psInsertRid2ridSequence.close();
        psInsertRidSequence.close();
    }

    protected void createRootUpload() throws Exception 
    {
		Connection conn = this.db.getConnection(this.databaseName);
		Statement stmt = conn.createStatement() ;
		for(int ii=0; ii<dbSchema.length; ii++ )
		{
		  String currCreateTableStr = dbSchema[ii] ;
		  //System.err.println("DEBUG: STATUS: creating database table via this SQL:\n  " + currCreateTableStr + "\n---------------------------------------------------------------------\n") ;
		  stmt.executeUpdate(currCreateTableStr) ;
		}
		stmt.close();
		
		DbResourceSet dbRes = this.db.executeQuery( "SELECT name, description FROM style" ) ;
		ResultSet rs = dbRes.resultSet ;
		PreparedStatement pstmt = conn.prepareStatement( "INSERT INTO style (name, description) VALUES (?, ?)" ) ;
		while(rs.next())
		{
		  pstmt.setString(1, rs.getString(1)) ;
		  pstmt.setString(2, rs.getString(2)) ;
		  pstmt.executeUpdate() ;
		}
		pstmt.close() ;
		dbRes.close() ;
		
		dbRes =  this.db.executeQuery( "SELECT value FROM color" ) ;
		rs = dbRes.resultSet ;
		pstmt = conn.prepareStatement( "INSERT INTO color (value) VALUES (?)" ) ;
		while(rs.next())
		{
		  pstmt.setString( 1, rs.getString(1) ) ;
		  pstmt.executeUpdate() ;
		}
		pstmt.close() ;
		dbRes.close() ;
    }

    public String getDatabaseName()
    {
        return databaseName;
    }
    public int getRefSeqIdInt()
    {
        return Util.parseInt(getRefSeqId(), -1);
    }
    public String getRefSeqId()
    {
        return refSeqId;
    }
    public String getMapmaster()
    {
        return mapMaster;
    }

     public static boolean checkIfRefSeqExist(String myRefSeqId, String myDatabaseName)
    {
       return checkIfRefSeqExist(myRefSeqId, myDatabaseName, true);
    }


    public static boolean checkIfRefSeqExist(String myRefSeqId, String myDatabaseName, boolean doCache)
    {
        DBAgent db = DBAgent.getInstance();
        return checkIfRefSeqExist(db,myRefSeqId, myDatabaseName, doCache);
    }

     public static boolean checkIfRefSeqExist(DBAgent myDb, String myRefSeqId, String myDatabaseName)
    {
      return checkIfRefSeqExist(myDb,myRefSeqId, myDatabaseName, true);
    }


    public static boolean checkIfRefSeqExist(DBAgent myDb, String myRefSeqId, String myDatabaseName, boolean doCache)
    {
        boolean exist = false;
        Connection conn = null;
        Statement stmt = null;
        String query = null;
        ResultSet rs = null;
        String newRefSeqId = null;

        if( myRefSeqId == null && myDatabaseName == null ) return false; // TODO - it is an error

        query = "SELECT refseqId FROM refseq WHERE " +
                ((myDatabaseName == null) ? "refSeqId = " +
                myRefSeqId : "databaseName ='" + myDatabaseName + "'");
        try
        {

            if(doCache)
              conn = myDb.getConnection();
            else
              conn = myDb.getNoCacheConnection(null);

            stmt = conn.createStatement();
            rs = stmt.executeQuery( query );

            if( rs.next() )
            {
                newRefSeqId = rs.getString("refseqId");
                if(newRefSeqId != null) exist = true;
            }
        }
        catch (SQLException e)
        {
            e.printStackTrace();
            // TODO - it is an error
        }
        finally
        {
            myDb.safelyCleanup(rs, stmt, conn);
            return exist;
        }
    }


    private void fetchTemplateInfo( String name, String description,
                                   String species, String version,
                                   String myFK_genomeTemplate_id) throws Exception 
    {
        String genomeTemplate_name = null;
        String genomeTemplate_species = null;
        String genomeTemplate_version = null;
        String genomeTemplate_description = null;

        if(myFK_genomeTemplate_id != null && myFK_genomeTemplate_id.length() > 0)
        {
            String query = "SELECT genomeTemplate_name, genomeTemplate_species, "
                    + " genomeTemplate_version,  genomeTemplate_description "  +
                    "FROM genomeTemplate WHERE genomeTemplate_id = " + myFK_genomeTemplate_id;

            	Connection conn = this.db.getConnection( null, false );
            	Statement stmt = conn.createStatement();
            	ResultSet rs = stmt.executeQuery( query );

                if( rs.next() )
                {
                    if(name == null || name.length() < 1)
                        genomeTemplate_name =  getUniqueName() + "_" + rs.getString("genomeTemplate_name");
                    else
                        genomeTemplate_name = name;

                    if(species == null || species.length() < 1)
                        genomeTemplate_species = rs.getString("genomeTemplate_species");
                    else
                        genomeTemplate_species = species;

                    if(version == null || version.length() < 1)
                        genomeTemplate_version = rs.getString("genomeTemplate_version");
                    else
                        genomeTemplate_version = version;

                    if(description == null || description.length() < 1)
                        genomeTemplate_description = rs.getString("genomeTemplate_description");
                    else
                        genomeTemplate_description = description;

                }
        }
        else
        {
            if(name == null || name.length() < 1)
                genomeTemplate_name =  getUniqueName();
            else
                genomeTemplate_name = name;

            if(species == null || species.length() < 1)
                genomeTemplate_species = "";
            else
                genomeTemplate_species = species;

            if(version == null || version.length() < 1)
                genomeTemplate_version = "";
            else
                genomeTemplate_version = version;

            if(description == null || description.length() < 1)
                genomeTemplate_description = "";
            else
                genomeTemplate_description = description;

        }

        setTemplateRelatedVariables(genomeTemplate_name, genomeTemplate_description,
                genomeTemplate_species, genomeTemplate_version);
    }

    private void fillFromExistingRefseqId(String dbName, String myRefseqId ) throws Exception 
    {
    	if (dbName == null && myRefseqId == null) {
    		throw new RuntimeException("Neither dbName nor myRefseqId is set");
    	}
        Connection conn = this.db.getConnection();

    	String qs = "SELECT userId, refseqName, description, "+
                "databaseName, fastaDir, "+
                "refseq_species, refseq_version, FK_genomeTemplate_id, "+
                "merged, refSeqId FROM refseq WHERE ";
        qs = qs + ((dbName == null) ? "refSeqId=" + myRefseqId : "databaseName='" + dbName + "'");
        PreparedStatement pstmt = conn.prepareStatement( qs );
        ResultSet rs = pstmt.executeQuery();
        if( rs.next() )
        {
        	this.userId = rs.getString("userId");
            this.refseqName = rs.getString("refseqName");
            this.description = rs.getString("description");
            this.databaseName = rs.getString("databaseName");
            this.fastaDir = rs.getString("fastaDir");
            this.refseq_species = rs.getString("refseq_species");
            this.refseq_version = rs.getString("refseq_version");
            this.FK_genomeTemplate_id = rs.getString("FK_genomeTemplate_id");
            this.merged = rs.getString("merged");
            this.refSeqId = rs.getString("refSeqId");
        }
        pstmt.close();
    }


    private void setGroupIdWhenNoProvided(String userId ) throws Exception 
    {
        String qs = "SELECT groupid FROM usergroup WHERE userGroupAccess = 'o' AND userid = " + userId;
        Connection conn = this.db.getConnection( null, false );
        if (conn == null) {
        	throw new NullPointerException("returns by myDb.getConnection(null, false)");
        }
    	Statement stmt = conn.createStatement( );
    	ResultSet rs = stmt.executeQuery( qs );
        if( rs.next() )
        {
            int myGroupId = rs.getInt("groupid");
            if(myGroupId > 0)
                groupId = "" + myGroupId;
        }
        stmt.close();
    }



    // ------------------------------------------------------------------
    // CONSTRUCTORS
    // ------------------------------------------------------------------
    public DatabaseCreator(DBAgent myDb, String dbName, String myRefseqId) throws Exception
    {
    	this.db = myDb;
    	fillFromExistingRefseqId(dbName, myRefseqId ) ;
    }

    public DatabaseCreator(DBAgent myDb, String myGroupId, String myUserId, String myRefseqId,
                           String myFK_genomeTemplate_id, String name, String description,
                           String species, String version, boolean myMerged) throws Exception
    {
    	this.db = myDb;
      String databaseName = null;
      String isMerged = (myMerged) ? ("y") : ("n");

      // Keep generating new names until we get one that is not in use.
      boolean foundUniqDbName = false ;
      String uniqDbName = null ;
      long retryCounter = 0 ;
      while(!foundUniqDbName)
      {
    	// This needs to be very conservative in making unique names!
    	// Time-stamp only based code has generated errors in the past, due to non-careful approaches!
        uniqDbName = Util.generateUniqueString("" + retryCounter) ;
        databaseName = "genboree_r_" + uniqDbName ;
        // Check if database name in use already (ties when lots of people at same time, like workshops)
        boolean inUse = RefSeqTable.hasDatabaseName(databaseName) ;
        if(inUse)
        {
          retryCounter += 1 ;
          foundUniqDbName = false ;
        }
        else
        {
          this.uniqueName = Util.generateUniqueString();
          foundUniqDbName = true ;
        }
      }

      // What host machine to put the new database on?
      String dbHost = Database2HostAssigner.assignNewDbToHost(this.db, databaseName) ;
      // Create the new database on the indicated host.
      this.db.createNewUserDatabase(dbHost, databaseName) ;

      if(myGroupId == null && myUserId != null)
      {
          setGroupIdWhenNoProvided(myUserId);
          myGroupId = this.groupId;
      }
      else if(myGroupId == null && myUserId == null) {
    	  throw new RuntimeException("User id is not set");
      }

      setBasicVariables(myGroupId, myUserId, myFK_genomeTemplate_id,
              isMerged, myRefseqId, databaseName);

      this.RefseqIdExist = DatabaseCreator.checkIfRefSeqExist(this.db, this.refSeqId, this.databaseName);

      fetchTemplateInfo(name, description, species, version, myFK_genomeTemplate_id);

      insertIntoRefseqTable();
      if (this.FK_genomeTemplate_id != null) {
          filluptemplate();
      }
      setScid();
      InsertScid();

      if (this.FK_genomeTemplate_id != null) {
          setSequenceAndBaseDir();
          createSequenceDir( );
          insertRidseqdir();
          createSequenceLinks( );
          fillRidSequenceTable( );
      }
    }

/*
    public void updateRootUpload()
    {
        DBAgent myDb = this.db;
        rootUpload.setRefSeqId( getRefSeqIdInt() );
        rootUpload.setUserId( getUserIdInt() );
        rootUpload.setUserDbName( getRefseqName() );
        try {
            rootUpload.insert( myDb );
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }
  */

    private void insertIntoRefseqTable() throws Exception
    {
        boolean addRefseqId = false;
        String insertQuery ="INSERT INTO refseq (userId, "+
                "refseqName, description, mapmaster, databaseName, "+
                "refseq_species, refseq_version, FK_genomeTemplate_id, merged ";

        if ( this.refSeqId != null && !this.RefseqIdExist )
        {
            insertQuery += ", refSeqId) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
            addRefseqId = true;
        }
        else
        {
            insertQuery += ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)";
            addRefseqId = false;
        }

        Connection conn = this.db.getConnection( null, false );
        createRootUpload();
        PreparedStatement pstmt = conn.prepareStatement( insertQuery );
        pstmt.setString( 1, this.userId );
        pstmt.setString( 2, this.refseqName );
        pstmt.setString( 3, this.description );
        pstmt.setString( 4, this.mapMaster );
        pstmt.setString( 5, this.databaseName );
        pstmt.setString( 6, this.refseq_species );
        pstmt.setString( 7, this.refseq_version );
        pstmt.setString( 8, this.FK_genomeTemplate_id );
        pstmt.setString( 9, this.merged );
        if(addRefseqId) pstmt.setInt( 10, getRefSeqIdInt() );
        pstmt.executeUpdate();
        int rsId = -1;
        if(addRefseqId)
            rsId = getRefSeqIdInt();
        else
        {
            rsId = this.db.getLastInsertId( conn );
            this.refSeqId = "" + rsId;
        }
        pstmt.close();

//            updateRootUpload();

        InsertGClassValue(1, "Sequence");


        int tempUploadId = insertUpload(getUserIdInt(), getRefSeqIdInt(), this.refseqName, this.databaseName, this.databaseName + ".conf" );
        this.uploadId = tempUploadId;
        insertRefseq2upload(this.refSeqId, "" + getUploadId());
        if(this.FK_genomeTemplate_id != null)
        {
            tempUploadId = fetchUploadIdForTemplateId();
            if(tempUploadId > 0)
            {
                String tempRefSeqName = fetchOriginalRefSeqname(tempUploadId);
                String tempDatabaseName = fetchUploadDbName(tempUploadId);
                insertRefseq2upload(this.refSeqId, "" + tempUploadId);
                insertUpload(getUserIdInt(), getRefSeqIdInt(), tempRefSeqName, tempDatabaseName, tempDatabaseName + ".conf" );
            }
        }

        String insertGrouprefseq = "INSERT INTO grouprefseq (groupId, refSeqId)"+
                "VALUES (" + this.groupId + ", " + this.refSeqId + ")";

        if( this.groupId != null )
        {
            this.db.executeUpdate( null, insertGrouprefseq );
        }
    }

    private void insertRefseq2upload(String myRefseqId, String myUploadId) throws Exception
    {
        String insertQuery = "INSERT INTO refseq2upload (uploadId, refSeqId) VALUES ("
                + myUploadId + ", " + myRefseqId + ")";
    	Connection conn = this.db.getConnection( null, false  );
    	Statement stmt = conn.createStatement();
        stmt.executeUpdate(insertQuery);
        stmt.close();
    }

    private String fetchOriginalRefSeqname(int templateUploadId) throws Exception
    {
        String query = "SELECT userDbName FROM upload WHERE uploadId = " + templateUploadId;
    	Connection conn = this.db.getConnection( null, false );
    	Statement stmt = conn.createStatement();
    	ResultSet rs = stmt.executeQuery( query );
    	String userDbName = null;
        if( rs.next() )
        {
            userDbName = rs.getString("userDbName");
        }
        stmt.close();
        return userDbName;
    }

    private String fetchUploadDbName(int templateUploadId) throws Exception
    {
        String query = "SELECT databaseName FROM upload WHERE uploadId = " + templateUploadId;
    	Connection conn = this.db.getConnection( null, false );
    	Statement stmt = conn.createStatement();
    	ResultSet rs = stmt.executeQuery( query );
    	String databaseName = null;
        if( rs.next() )
        {
            databaseName = rs.getString("databaseName");
        }
        stmt.close();
        return databaseName;
    }

    // returns ID or -1 when not exists
    private int fetchUploadIdForTemplateId() throws Exception
    {
        int tempUploadId = -1;
        String query = "SELECT uploadId FROM template2upload WHERE templateid = " + this.FK_genomeTemplate_id;
    	Connection conn = this.db.getConnection( null, false );
    	Statement stmt = conn.createStatement();
    	ResultSet rs = stmt.executeQuery( query );
        if( rs.next() )
        {
            tempUploadId = rs.getInt("uploadId");
        }
        stmt.close();
        return tempUploadId;
    }


    private void setBasicVariables(String myGroupId, String myUserId,
                                  String myFK_genomeTemplate_id, String isMerged, String myRefseqId, String databaseName)
    {
    	this.groupId = myGroupId;
    	this.userId = myUserId;
        this.FK_genomeTemplate_id = myFK_genomeTemplate_id;
        this.merged = isMerged;
        this.refSeqId = myRefseqId;
        this.databaseName = databaseName;
    }

    private void setTemplateRelatedVariables(String genomeTemplate_name,
                                            String genomeTemplate_description,
                                            String  genomeTemplate_species, String genomeTemplate_version)

    {
    	this.refseqName = genomeTemplate_name;
        this.description = genomeTemplate_description;
        this.refseq_species = genomeTemplate_species;
        this.refseq_version = genomeTemplate_version;

    }

    private void InsertScid() throws Exception
    {
        if( this.refSeqId == null || this.scid < 1 ) return;  // TODO - it is an error, isn't it ?

        String insertQuery = "INSERT INTO refSeqId2scid (refSeqID, scid) VALUES ("
                + this.refSeqId + ", " + this.scid + ")";
    	Connection conn = this.db.getConnection( null, false  );
    	Statement stmt = conn.createStatement();
        stmt.executeUpdate(insertQuery);
        stmt.close();
    }

    private void InsertGClassValue(int id, String valueToInsert) throws Exception
    {
        String insertQuery = "INSERT INTO gclass (gid, gclass) VALUES (" + id + ", '" + valueToInsert + "')";
    	Connection conn = this.db.getConnection( getDatabaseName() );
    	Statement stmt = conn.createStatement();
        stmt.executeUpdate(insertQuery);
        stmt.close();
    }

    public int getScid()
    {
        return scid;
    }
    private void setScid() throws Exception
    {
        if(this.FK_genomeTemplate_id == null)
        {
        	this.scid = 1;
            return;
        }

        String query = "SELECT scid FROM template2scid where templateId = " + this.FK_genomeTemplate_id;
    	Connection conn = this.db.getConnection( null, false );
    	Statement stmt = conn.createStatement( );
    	ResultSet rs = stmt.executeQuery( query );
        if( rs.next() )
        {
        	this.scid = rs.getInt("scid");
        } else {
        	this.scid = 1;
        }
        stmt.close();
    }

    private String fetchDatabaseNameFromTemplateId() throws Exception
    {
        String query = "SELECT u.databasename name FROM upload u, template2upload t " +
                "WHERE u.uploadid = t.uploadid AND t.templateid = " + this.FK_genomeTemplate_id;
        Connection conn = this.db.getConnection( null, false );
        if (conn == null) {
        	throw new NullPointerException("this.db.getConnection( null, false ) failed");
        }
    	Statement stmt = conn.createStatement( );
    	ResultSet rs = stmt.executeQuery( query );
    	String myTemplateDatabaseName;
        if( rs.next() )
        {
            myTemplateDatabaseName = rs.getString("name");
        } else {
        	throw new RuntimeException("Cannot find template with id: " + this.FK_genomeTemplate_id);
        }
        stmt.close();
        return myTemplateDatabaseName;
    }


    protected void filluptemplate( ) throws Exception
    {        
        String templateDatabaseName = fetchDatabaseNameFromTemplateId();
        String queryTemplateDatabase = "SELECT rid, refname, rlength, rbin, ftypeid, rstrand, gid, gname FROM fref";
        String insertQuery ="INSERT INTO fref (rid, refname, rlength, rbin, ftypeid, rstrand, gid, gname) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?)";

    	Connection mainConn = this.db.getConnection( this.databaseName );
    	Connection tempConn = this.db.getConnection( templateDatabaseName );

    	PreparedStatement pstmt = mainConn.prepareStatement( insertQuery );
    	Statement stmt = tempConn.createStatement();

    	ResultSet rs = stmt.executeQuery(queryTemplateDatabase);
        while( rs.next() )
        {
            pstmt.setInt( 1, rs.getInt("rid") );
            pstmt.setString( 2,  rs.getString("refname"));
            pstmt.setInt( 3, rs.getInt("rlength") );
            pstmt.setDouble( 4, rs.getDouble("rbin") );
            pstmt.setInt( 5, rs.getInt("ftypeid") );
            pstmt.setString( 6, rs.getString("rstrand") );
            pstmt.setInt( 7, rs.getInt("gid") );
            pstmt.setString( 8, rs.getString("gname") );
            pstmt.executeUpdate();
        }
        pstmt.close();
    }


    // returns ID of new record
    private int insertUpload(int myUserId, int myRefSeqId, String myRefSeqName, String myDatabaseName, String myConfName ) throws Exception
    {
        String qs = "INSERT INTO upload (userId, refSeqId, created, userDbName, "+
                "databaseName, configFileName) VALUES (?, ?, sysdate(), ?, ?, ?)";
         try
         {
        	 Connection conn = this.db.getConnection(null, false);
        	 PreparedStatement pstmt = conn.prepareStatement( qs );
             pstmt.setInt( 1, myUserId );
             pstmt.setInt( 2, myRefSeqId );
             pstmt.setString( 3, myRefSeqName );
             pstmt.setString( 4, myDatabaseName );
             pstmt.setString( 5, myConfName );
             pstmt.executeUpdate();
             pstmt.close();
             return this.db.getLastInsertId(conn);
         } catch( Exception ex )
         {
             System.err.println( "Exception on insertUpload where query is " +
                     "INSERT INTO upload (userId, refSeqId, created, userDbName, "+
                "databaseName, configFileName) VALUES (" + myUserId + ", " + myRefSeqId + ", sysdate(), '" +
                 myRefSeqName + "', '" + myDatabaseName + "', '" + myConfName + "')");
             System.err.flush();
             throw ex;
         }
     }


    public static void printUsage(){
        System.out.print("usage: AnnotationDownloader ");
        System.out.println("-r refSeqId -g groupId, -s genboreeDatabaseName -u userId, " +
                " [-m isMerged -d description -n refseqName -e species" +
                " -v version -t templateId]");
        return;
    }


    public static void main(String[] args) throws Exception
    {
        String groupId = null;
        String userId = null;
        String refseqName = null;
        String description = null;
        String species = null;
        String version = null;
        String refseqId = null;
        String template_id = null;
        boolean isMerged = false;
        String genboreeDbName = null;

        if(args.length == 0 )
        {
            printUsage();
            System.exit(-1);
        }

        if(args.length >= 1)
        {

            for(int i = 0; i < args.length; i++ )
            {

                if(args[i].compareToIgnoreCase("-g") == 0){
                    if(args[i+ 1] != null){
                        groupId = args[i + 1];
                    }
                }
                else if(args[i].compareToIgnoreCase("-u") == 0){
                    if(args[i+ 1] != null){
                        userId = args[i + 1];
                    }
                }
                else if(args[i].compareToIgnoreCase("-m") == 0){
                    isMerged = true;
                }
                else if(args[i].compareToIgnoreCase("-d") == 0){
                    if(args[i+ 1] != null){
                        description =args[i + 1];
                    }
                }
                else if(args[i].compareToIgnoreCase("-n") == 0){
                    if(args[i+ 1] != null){
                        refseqName = args[i + 1];
                    }
                }
                else if(args[i].compareToIgnoreCase("-e") == 0){
                    if(args[i+ 1] != null){
                        species = args[i + 1];
                    }
                }
                else if(args[i].compareToIgnoreCase("-v") == 0){
                    if(args[i+ 1] != null){
                        version = args[i + 1];
                    }
                }
                else if(args[i].compareToIgnoreCase("-r") == 0){
                    if(args[i+ 1] != null){
                        refseqId = args[i + 1];
                    }
                }
                else if(args[i].compareToIgnoreCase("-s") == 0){
                    if(args[i+ 1] != null){
                        genboreeDbName = args[i + 1];
                    }
                }
                else if(args[i].compareToIgnoreCase("-t") == 0){
                    if(args[i+ 1] != null){
                        template_id = args[i + 1];
                    }
                }
            }

        }
        else
        {
            printUsage();
            System.exit(-1);
        }

        DBAgent myDb = DBAgent.getInstance();
        if(refseqId == null && genboreeDbName == null && userId == null)
        {
            System.err.println("Minimum requirement is to provide a valid refseqId or a valid genboreeDbName");
            System.err.println("or if you want to create a new database in addition you need to provide");
            System.err.println("groupId, userId and optionally a template_id");
            System.err.flush();
            System.exit(1);
        }

        try {
	        boolean validRefseqId = DatabaseCreator.checkIfRefSeqExist(myDb, refseqId, genboreeDbName);
	        DatabaseCreator dbC;
	        if(validRefseqId)
	        {
	            dbC = new DatabaseCreator(myDb, genboreeDbName, refseqId);
	        }
	        else
	        {
	            if(userId != null)
	            {
	                dbC = new DatabaseCreator(myDb, groupId, userId, refseqId,
	                        template_id,refseqName, description, species, version, isMerged);
	            } else {
	            	throw new RuntimeException(" assertion failed: validRefseqId == true OR userId != null ");
	            }
	        }
	        if (dbC.getRefSeqIdInt() > 0 && !validRefseqId) {
	            System.err.println("a new genboree database (" + dbC.getDatabaseName() + ") with refseqId = " + dbC.getRefSeqIdInt() + " has been created");
	        } else {
	        	System.err.println("??");
	        }
	     } catch (Exception e) {
        	System.err.println("Failed to create genboree database! The following exception was catched:");
        	System.err.println("Exception: " + e.toString());
        	System.err.println("Message: " + e.getMessage());
        	System.err.println("StackTrace:\n");
        	e.printStackTrace(System.err);
        	System.err.flush();
        	System.exit(2);
        }
            
        System.exit(0);
    }
}
