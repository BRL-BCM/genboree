package org.genboree.dbaccess;

import java.io.*;
import java.sql.ResultSet;
import java.sql.SQLException;



public class RefseqSynch extends Refseq
{
    boolean fetchFirstAvailable = true;
    boolean fetchNextAvailable = true;
    boolean uploadAvailable = true;

    public RefseqSynch ()
    {

    }

    public RefseqSynch ( Refseq refSeq )
    {
	this._conn = refSeq._conn;
	this._db = refSeq._db;
	this._upldConn = refSeq._upldConn;
	this.curLine = refSeq.curLine;
	this.currPstmt = refSeq.currPstmt;
	this.currPstmtCV = refSeq.currPstmtCV;
	this.currPstmtGV = refSeq.currPstmtGV;
	this.currSect = refSeq.currSect;
	this.databaseName = refSeq.databaseName;
	this.description = refSeq.description;
	this.errs = refSeq.errs;
	this.fastaDir = refSeq.fastaDir;
	this.first_line = refSeq.first_line;	
	this.FK_genomeTemplate_id = refSeq.FK_genomeTemplate_id;
	this.frCurDb = refSeq.frCurDb;
	this.frCurTable = refSeq.frCurTable;
	this.frDbNames = refSeq.frDbNames;
	this.frEntryPointId = refSeq.frEntryPointId;
	this.frQs1 = refSeq.frQs1;
	this.frQs2 = refSeq.frQs2;
	this.frTables = refSeq.frTables;
	this.frTrackFilter = refSeq.frTrackFilter;
	this.frTracks = refSeq.frTracks;
	this.htFref = refSeq.htFref;
	this.htFtype = refSeq.htFtype;
	this.htGclass = refSeq.htGclass;
	this.ignore_annotations = refSeq.ignore_annotations;
	this.ignore_assembly = refSeq.ignore_assembly;
	this.ignore_refseq = refSeq.ignore_refseq;
	this.is_error = refSeq.is_error;
	this.mapmaster = refSeq.mapmaster;
	this.maxFbin = refSeq.maxFbin;
	this.merged = refSeq.merged;
	this.metaData = refSeq.metaData;
	this.minFbin = refSeq.minFbin;
	this.newFtypes = refSeq.newFtypes;
	this.numRecords = refSeq.numRecords;
	this.refseq_species = refSeq.refseq_species;
	this.refseq_version = refSeq.refseq_version;
	this.refSeqId = refSeq.refSeqId;
	this.refseqName = refSeq.refseqName;
	this.rootUpload = refSeq.rootUpload;
	this.userId = refSeq.userId;
	this.vFtype = refSeq.vFtype;

    }

    public synchronized int doUpload( DBAgent db, String userId, String groupId, String uploadName,
				      int _refSeqId , String newClassName) throws SQLException {
	while ( uploadAvailable == false )
	    {
		try {
		    wait();
		}
		catch ( InterruptedException e ) {}
	    }
	uploadAvailable = false;

	super.initializeUpload( db, userId, groupId,
				uploadName, _refSeqId, false, null );

	int counter = 0;
	int numRecs = 0;

	try {

	    //-------------
	    // temporary
	    File testOutputFile = File.createTempFile( "test", ".txt" );
	    PrintWriter fTestOut = new PrintWriter( new FileWriter( testOutputFile.toString() ) );

	    //-------------

        setByPassClassName(true);
        setNameNewClass(newClassName);
	    BufferedReader bIn = new BufferedReader( new FileReader( uploadName ) );
	    String str = null;
	    while ( ( str = bIn.readLine() ) != null )
		{
		    fTestOut.println( str );
		    super.consume( str );
		    counter++;
		}
	    bIn.close();
	}
	catch ( Exception ex )
	    {
		// print out error stack via standard output
		System.out.println( "----------------------------------------" );
		System.out.println( "EXCEPTION CAUGHT IN trackOps.jsp (upload)" );
		ex.printStackTrace();
		System.out.println( "----------------------------------------" );
	    }

	numRecs = super.getNumRecords();
		//numRecs = counter;

	super.terminateUpload();

	uploadAvailable = true;
	notifyAll();

	return numRecs;
    }


    public synchronized DbResourceSet fetchRecordsFirst( DBAgent db,
						     String [] trackNames, String from, String to,
						     String entryPointId, String filter ) throws SQLException {
                DbResourceSet dbRes = null;
    while ( fetchFirstAvailable == false )
	    {
		try {
		    wait();
		}
		catch ( InterruptedException e ) {}
	    }
	fetchFirstAvailable = false;
    dbRes = super.fetchRecordsFirst( db, trackNames, from, to, entryPointId, filter );
	ResultSet rs = dbRes.resultSet;

	fetchFirstAvailable = true;
	notifyAll();

	return dbRes;
    }

    public synchronized  DbResourceSet fetchRecordsNext( DBAgent db )
    {
        DbResourceSet dbRes = null;
    while ( fetchNextAvailable == false )
	    {
		try {
		    wait();
		}
		catch ( InterruptedException e ) {}
	    }
	fetchNextAvailable = false;
    dbRes =  super.fetchRecordsNext( db );
	ResultSet rs = dbRes.resultSet;


	fetchNextAvailable = true;
	notifyAll();

	return dbRes;
    }


}
