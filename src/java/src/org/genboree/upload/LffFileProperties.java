package org.genboree.upload;

import org.genboree.util.TimingUtil;
import org.genboree.util.Util;
import org.genboree.dbaccess.DBAgent;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.Statement;
import java.util.HashMap;
import java.util.Hashtable;
import java.util.Vector;
import java.io.PrintWriter;
import java.io.PrintStream;

public class LffFileProperties implements RefSeqParams
{
    protected boolean is_error = false;
    protected boolean ignore_refseq = false;
    protected boolean ignore_assembly = false;
    protected boolean ignore_annotations = false;
    protected boolean byPassClassName = false;


    protected boolean fdata2BufferFull = false;
    protected boolean fdata2CVBufferFull = false;
    protected boolean fdata2GVBufferFull = false;
    protected boolean fidTextBufferFull = false;

    protected boolean ignoreComments = false;
    protected boolean ignoreSequences = false;
    protected boolean limitInLffSize = false;
    protected boolean usingValuePairs = false;

    protected int maxNumberOfInserts;


    protected int currentLffLineNumber;
    protected int maxNumberOfErrors;
    protected int fdata2BufferLength;
    protected int sleepTime = LffConstants.uploaderSleepTime;
    protected int fdata2_cvBufferLength;
    protected int fdata2_gvBufferLength;
    protected int fidTextBufferLength;
    protected int maxSizeOfBufferInBytes;
    protected int limitNumberOfLffLinesTo;
    protected int continueAtLine;
    protected String individualInsertsFtype2Gclass = "INSERT IGNORE INTO ftype2gclass (ftypeid, gid) VALUES (?, ?)";
    protected String selectFidFromFdata2 = "SELECT fid FROM fdata2 WHERE fbin = ? AND rid = ? AND fstart = ? AND fstop = ?  " +
                "AND ftypeid = ? AND  gname = ? AND fscore between ? AND ? AND fstrand = ? AND ( fphase = ? OR fphase = ?)";
    protected long minFbin = 1000L;
    protected long maxFbin = 100000000L;
    protected String nameNewClass = null;
    protected String groupId;
    protected String lffFile;
    protected String refseqId;
    protected String databaseName;
    protected String fileName = null;
    protected String refSeqId;
    protected String mapmaster;
    protected String userId;
    protected String refseqName;
    protected String currSect = "annotations";

    protected String[] metaData = metaAnnotations;
    protected String[] newFtypes = new String[0];
    protected StringBuffer[] tableDump;
//    protected StringBuffer fdata2Buffer;
    protected StringBuffer fdata2Buffer_cv;
    protected StringBuffer fdata2Buffer_gv;
    protected StringBuffer fidTextBuffer;
    protected Hashtable htGclass;
    protected Hashtable htFref;
    protected Hashtable htFtype;
    protected HashMap ftypeIdsInLffFile;
    protected Hashtable htFtypeGclass;
    protected HashMap featureTypeToGclasses;
    protected Hashtable gclass2ftypesHash;
    protected Vector vFtype;
    protected Vector errs;
    protected Connection _conn;
    protected Connection databaseConnection;
    protected Connection[] databaseConnections;
    protected DBAgent db;
    protected Statement currStmtFid;

    protected TimingUtil currentUploaderTimer = null;



    protected PreparedStatement fdata2QueryToGetFid;


    protected PreparedStatement deleteFids;

    protected PrintWriter printerOutStream;
    protected String mysqlInsertAttributes = " IGNORE ";
    protected String mysqlDeleteAttributes = " ";
    protected PreparedStatement statementIndividualInsertsFtype2Gclass;
    protected StringBuffer debugInfo = null;
    protected static int initialBufferSize = 4 * 1024 * 1024 ;
    protected TimingUtil timer = null;
    protected int annotationsSuccessfullyParsed = 0;
    protected int annotationsForInsertion = 0;
    protected int annotationsForUpdate = 0;
    protected BulkUploadManager insertManager = null;
    protected boolean printQueries = false;
    protected boolean insertData = true;
    protected boolean deleteExtraRecords = false;

    protected GroupAssigner groupAssigner = null;
    protected String timmingInfo = null;
    protected String groupAssignerTimmerInfo = null;
    protected int maxNumberOfColumnsInLff = -1;
    protected PrintStream fullLogFile = null;


     public boolean isInsertData()
     {
         return insertData;
     }
     public void setInsertData(boolean insertData)
     {
         this.insertData = insertData;
     }

    public boolean isUsingValuePairs()
    {
        return usingValuePairs;
    }

    public void setUsingValuePairs(boolean usingValuePairs) 
    {
        this.usingValuePairs = usingValuePairs;
        if(usingValuePairs)
            maxNumberOfColumnsInLff = 15;
        else
            maxNumberOfColumnsInLff =14;
    }


    public PrintStream getFullLogFile()
    {
        return fullLogFile;
    }

    public void setFullLogFile(PrintStream fullLogFile) 
    {
        this.fullLogFile = fullLogFile;
    }

    public boolean isPrintQueries()
    {
        return printQueries;
    }
    public void setPrintQueries(boolean printQueries)
    {
        this.printQueries = printQueries;
    }

    public String getTimmingInfo()
    {
        return timmingInfo;
    }

    public int getAnnotationsForUpdate()
    {
        return annotationsForUpdate;
    }

    public void setAnnotationsForUpdate(int annotationsForUpdate)
    {
        this.annotationsForUpdate = annotationsForUpdate;
    }

    public int getAnnotationsForInsertion()
    {
        return annotationsForInsertion;
    }

    public String getGroupAssignerTimmerInfo()
    {
        return groupAssignerTimmerInfo;
    }

    public void setAnnotationsForInsertion(int annotationsForInsertion)
    {
        this.annotationsForInsertion = annotationsForInsertion;
    }

    public int getAnnotationsSuccessfullyParsed()
    {
        return annotationsSuccessfullyParsed;
    }

    public void setAnnotationsSuccessfullyParsed(int annotationsSuccessfullyParsed)
    {
        this.annotationsSuccessfullyParsed = annotationsSuccessfullyParsed;
    }

    public int getSleepTime()
    {
        return sleepTime;
    }

    public void setSleepTime(int sleepTime)
    {
        this.sleepTime = sleepTime;
    }

    public Hashtable getHtFtypeGclass()
    {
        return htFtypeGclass;
    }

    public void setHtFtypeGclass(Hashtable htFtypeGclass)
    {
        this.htFtypeGclass = htFtypeGclass;
    }

    public Hashtable getHtFref()
    {
        return htFref;
    }

    public void setHtFref(Hashtable htFref)
    {
        this.htFref = htFref;
    }

    public Hashtable getHtGclass()
    {
        return htGclass;
    }

    public void setHtGclass(Hashtable htGclass)
    {
        this.htGclass = htGclass;
    }

    public Hashtable getHtFtype()
    {
        return htFtype;
    }

    public void setHtFtype(Hashtable htFtype)
    {
        this.htFtype = htFtype;
    }


    public int getMaxNumberOfInserts()
    {
        return maxNumberOfInserts;
    }
    public void setMaxNumberOfInserts(int maxNumberOfInserts)
    {
        this.maxNumberOfInserts = maxNumberOfInserts;
    }


    public StringBuffer getDebugInfo()
    {
        return debugInfo;
    }

    public void setDebugInfo(StringBuffer debugInfo)
    {
        this.debugInfo = debugInfo;
    }

    public PreparedStatement getStatementIndividualInsertsFtype2Gclass()
    {
        return statementIndividualInsertsFtype2Gclass;
    }

    public void setStatementIndividualInsertsFtype2Gclass(PreparedStatement statementIndividualInsertsFtype2Gclass)
    {
        this.statementIndividualInsertsFtype2Gclass = statementIndividualInsertsFtype2Gclass;
    }

    public String getMysqlDeleteAttributes() {
        return mysqlDeleteAttributes;
    }
    public void setMysqlDeleteAttributes(String mysqlDeleteAttributes) {
        this.mysqlDeleteAttributes = mysqlDeleteAttributes;
    }
    public String getMysqlInsertAttributes() {
        return mysqlInsertAttributes;
    }
    public String getIndividualInsertsFtype2Gclass() {
        return individualInsertsFtype2Gclass;
    }
    public void setIndividualInsertsFtype2Gclass(String individualInsertsFtype2Gclass) {
        this.individualInsertsFtype2Gclass = individualInsertsFtype2Gclass;
    }
    public void setMysqlInsertAttributes(String mysqlInsertAttributes) {
        this.mysqlInsertAttributes = mysqlInsertAttributes;
    }
    public PrintWriter getPrinterOutStream() {
        return printerOutStream;
    }

    public String fetchTableName(int tableType)
    {
        String tableName = null;

        if(tableType == 0)
            tableName = "fdata2";
        else if(tableType == 1)
            tableName = "fdata2_cv";
        else if(tableType == 2)
            tableName = "fdata2_gv";
        else if(tableType == 3)
            tableName = "fidText";

        return tableName;
    }

    public void setPrinterOutStream(PrintWriter printerOutStream) {
        this.printerOutStream = printerOutStream;
    }

    public boolean isLimitInLffSize()
    {
        return limitInLffSize;
    }
    public void setLimitInLffSize(boolean limitInLffSize)
    {
        this.limitInLffSize = limitInLffSize;
    }
    public boolean isIgnoreComments()
    {
        return ignoreComments;
    }
    public void setIgnoreComments(boolean ignoreComments)
    {
        this.ignoreComments = ignoreComments;
    }
    public boolean isIgnoreSequences()
    {
        return ignoreSequences;
    }
    public void setIgnoreSequences(boolean ignoreSequences)
    {
        this.ignoreSequences = ignoreSequences;
    }
    public int getLimitNumberOfLffLinesTo()
    {
        return limitNumberOfLffLinesTo;
    }
    public void setLimitNumberOfLffLinesTo(int limitNumberOfLffLinesTo)
    {
        this.limitNumberOfLffLinesTo = limitNumberOfLffLinesTo;
    }
    public int getContinueAtLine() {
        return continueAtLine;
    }

    public void setContinueAtLine(int continueAtLine) {
        this.continueAtLine = continueAtLine;
    }


    public boolean isFdata2BufferFull()
    {
        return fdata2BufferFull;
    }
    public void setFdata2BufferFull(boolean fdata2BufferFull)
    {
        this.fdata2BufferFull = fdata2BufferFull;
    }
    public boolean isFdata2CVBufferFull()
    {
        return fdata2CVBufferFull;
    }
    public void setFdata2CVBufferFull(boolean fdata2CVBufferFull)
    {
        this.fdata2CVBufferFull = fdata2CVBufferFull;
    }
    public boolean isFdata2GVBufferFull()
    {
        return fdata2GVBufferFull;
    }
    public void setFdata2GVBufferFull(boolean fdata2GVBufferFull)
    {
        this.fdata2GVBufferFull = fdata2GVBufferFull;
    }
    public boolean isFidTextBufferFull()
    {
        return fidTextBufferFull;
    }
    public void setFidTextBufferFull(boolean fidTextBufferFull)
    {
        this.fidTextBufferFull = fidTextBufferFull;
    }
    public int getMaxSizeOfBufferInBytes()
    {
        return maxSizeOfBufferInBytes;
    }
    public void setMaxSizeOfBufferInBytes(int maxSizeOfBuffer)
    {
        this.maxSizeOfBufferInBytes = maxSizeOfBuffer;
    }


    public boolean isIgnore_refseq()
    {
        return ignore_refseq;
    }
    public void setIgnore_refseq(boolean ignore_refseq)
    {
        this.ignore_refseq = ignore_refseq;
    }
    public boolean isIgnore_assembly()
    {
        return ignore_assembly;
    }
    public void setIgnore_assembly(boolean ignore_assembly)
    {
        this.ignore_assembly = ignore_assembly;
    }
    public boolean isIgnore_annotations()
    {
        return ignore_annotations;
    }
    public void setIgnore_annotations(boolean ignore_annotations)
    {
        this.ignore_annotations = ignore_annotations;
    }
    public Connection getDatabaseConnection()
    {
        return databaseConnection;
    }
    public String getGroupId()
    {
        return groupId;
    }
    public void setGroupId(String groupId)
    {
        this.groupId = groupId;
    }
    public String getLffFile()
    {
        return lffFile;
    }
    public void setLffFile(String lffFile)
    {
        this.lffFile = lffFile;
    }
    public String getMapmaster()
    {
        return mapmaster;
    }
    public void setMapmaster( String mapmaster )
    {
        this.mapmaster = mapmaster;
    }
    public boolean getByPassClassName()
    {
        return byPassClassName;
    }
    public String getRefseqName()
    {
        return refseqName;
    }
    public void setRefseqName(String refseqName)
    {
        this.refseqName = refseqName;
    }
    public String getUserId()
    {
        return userId;
    }
    public void setUserId(String userId)
    {
        this.userId = userId;
    }
    public int getGenboreeUserId()
    {
      int genboreeUserId = Util.parseInt(userId, -1);
      return genboreeUserId;
    }
    public String getFileName()
    {
        return fileName;
    }
    public String getDatabaseName()
    {
        return databaseName;
    }
    public void setDatabaseName( String databaseName )
    {
        this.databaseName = databaseName;
    }
    public Connection[] getDatabaseConnections()
    {
        return databaseConnections;
    }
    public DBAgent getDb()
    {
        return db;
    }
    public void setDb(DBAgent db)
    {
        this.db = db;
    }
    public String getRefseqId()
    {
        return refseqId;
    }
    public void setRefseqId(String myRefseqId)
    {
        if( myRefseqId == null ) refseqId = "#";
        this.refseqId = myRefseqId;
    }
    public HashMap getFeatureTypeToGclasses()
    {
        return featureTypeToGclasses;
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
    public Hashtable getGclass2ftypesHash()
    {
        return gclass2ftypesHash;
    }


    public void setMaxNumberOfErrors(int maxNumberOfErrors)
    {
        this.maxNumberOfErrors = maxNumberOfErrors;
    }
    public void setCurrentLffLineNumber(int currentLffLineNumber)
    {
        this.currentLffLineNumber = currentLffLineNumber;
    }
    public String getNameNewClass()
    {
        return  nameNewClass;
    }
    public void setNameNewClass(String newClassName)
    {
        this.nameNewClass = newClassName;
    }


}
