package org.genboree.upload;

import org.genboree.util.Util;
import org.genboree.util.GenboreeUtils;
import org.genboree.util.TimingUtil;

import java.sql.*;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.ArrayList;
import java.io.PrintStream;

public class BulkUploadManager implements LffConstants
{

    protected TableBulkInsertManager extraFieldsUpdater = null;
    protected TableBulkInsertManager fdata2Inserter = null;
    protected TableBulkInsertManager fdata2InserterGV = null;
    protected TableBulkInsertManager fdata2InserterCV = null;
    protected TableBulkInsertManager fidTextInserter = null;
    protected TableBulkInsertManager valuePairDeleter = null;
    protected TableBulkInsertManager fdata2Deleter = null;
    protected TableBulkInsertManager commentsDeleter = null;
    protected TableBulkInsertManager sequenceDeleter = null;
    protected TableBulkInsertManager attNameInserter = null;
    protected TableBulkInsertManager attValueInserter = null;
    protected TableBulkInsertManager fid2attribute = null;
    protected TableBulkInsertManager ftype2attributeName = null;
    protected PreparedStatement lockFdataTables;
    protected PreparedStatement unlockFdataTables;
    protected PreparedStatement selectMaxFidFdata2;
    protected PreparedStatement selectMaxFidFdata2CV;
    protected PreparedStatement selectMaxFidFdata2GV;
    protected PreparedStatement selectMaxFromFidText;
    protected PreparedStatement selectMaxFromFid2Attribute;
    protected PreparedStatement currPstmt;
    protected PreparedStatement currPstmtCV;
    protected PreparedStatement currPstmtGV;
    protected PreparedStatement currPstmTFidText;
    protected PreparedStatement deleteReservedFromFdata2;
    protected PreparedStatement deleteReservedFromFdata2_CV;
    protected PreparedStatement deleteReservedFromFdata2_GV;
    protected PreparedStatement deleteFromFidTextPS;
    protected PreparedStatement selectTextFromFidText;
    protected PrintStream fullLogFile = null;
    protected HashMap ftype2attributeNameHash = null;
    Connection sqlConnection;
    protected final String[] dataFieldsForFdata2 = {"fid", "ftarget_start", "ftarget_stop", "displayCode", "displayColor" };
    protected final String[] updateFieldsFdata2 = {"ftarget_start", "ftarget_stop", "displayCode", "displayColor" };
    protected String lastMaxFid;
    protected String lastMaxFidcv ;
    protected String lastMaxFidgv;
    protected String lastFidFromFidText;
    protected String lastFidFromFid2Attribute;
    protected String databaseName;
    protected String sqlAttributes;
    protected String deleteCommentsQuery;
    protected String deletevaluePairQuery;
    protected String fdata2DeleterQuery;
    protected String deleteSequenceQuery;
    protected String deleteGen;
    protected String deleteReserve;
    protected String fdata2FieldsToInsert;
    protected String lockTables;
    protected String unlockTables ;
    protected String insert;
    protected String fdataField;
    protected String fdatavalues;
    protected String fdata2ReservedName;
    protected String fdata2CVReservedName;
    protected String fdata2GVReservedName;
    protected String attNameIdQuery;
    protected String attValueIdQuery;


    protected int fdata2StartRange;
    protected int fdata2CVStartRange;
    protected int fdata2GVStartRange;
    protected int fid2AttributeStartRange;
    protected int fidTextStartRange;
    protected int recordCounter = 0;
    protected int maxRecords = -1 ; // TODO new change bug fix
    protected int maxNumberOfInserts = -1; // TODO new change bug fix
    protected int maxSizeOfBufferInBytes; // TODO new change bug fix
    protected int numberOfSuccessfullInsertsIntoFdata2 = 0; // TODO new change bug fix
    protected int numberOfSuccessfullInsertsIntoFdata2CV = 0; // TODO new change bug fix
    protected int numberOfSuccessfullInsertsIntoFdata2GV = 0; // TODO new change bug fix


    protected StringBuffer selectAttNameId;
    protected StringBuffer selectAttValueId;
    protected int attNameCounter = 0;
    protected int attValueCounter = 0;

    protected int fdata2_counter;
    protected int fdata2_counter_cv;
    protected int fdata2_counter_gv;
    protected HashMap attNames2ids = null;
    protected HashMap attValues2ids = null;
    protected HashMap fids2valuePairs = null;
    protected HashMap fid2FtypeId = null;

    protected int extraFieldsUpdateCounter = 0;
    protected int fdata2InserterCounter = 0;
    protected int fdata2InserterGVCounter = 0;
    protected int fdata2InserterCVCounter = 0;
    protected int fidTextInserterCounter = 0;
    protected int commentsDeleterCounter = 0;
    protected int sequenceDeleterCounter = 0;
    protected int valuePairDeleterCounter = 0;
    protected int fdata2DeleterCounter = 0;


    protected int fdata2ReservedId;
    protected int fdata2CVReservedId;
    protected int fdata2GVReservedId;
    protected int fdata2CurrentId;
    protected int fdata2CVCurrentId;
    protected int fdata2GVCurrentId;
    protected HashMap lffLinesMd5;
    protected HashMap annotationsMd5;
    protected TimingUtil bulkUploadManagerTimer = null;
    protected boolean useTimmingUtil = false;
    protected String timmingInfo = null;
    protected int numberOfLinesInLffFile = -1;


    public BulkUploadManager( Connection myConnection, String databaseName, int maxRecords, int maxSizeOfBufferInBytes, PrintStream fullLogFile)
    {
        if(useTimmingUtil)
        {
            bulkUploadManagerTimer = new TimingUtil() ;
            bulkUploadManagerTimer.addMsg("Initializing BulkUpladmanager");
        }
        this.maxRecords =maxRecords;
        this.maxNumberOfInserts = maxRecords; // TODO new change bug fix
        this.databaseName = databaseName;
        this.sqlConnection = myConnection;
        this.maxSizeOfBufferInBytes = maxSizeOfBufferInBytes;
        setFullLogFile(fullLogFile);
        initializeVariables();
        initializeTableBulkInsertManagers();
        cleanStringBuffers();
        initializePrepareStatements();
//        initialReserveOfFids();
        if(useTimmingUtil)
            bulkUploadManagerTimer.addMsg("finish Initializing BulkUpladmanager");
    }


    protected void initializeVariables()
    {
        sqlAttributes = "LOW_PRIORITY IGNORE";
        lastMaxFid = "SELECT MAX(fid) FROM fdata2";
        lastMaxFidcv = "SELECT MAX(fid) FROM fdata2_cv";
        lastMaxFidgv = "SELECT MAX(fid) FROM fdata2_gv";
        lastFidFromFidText = "SELECT MAX(fid) FROM fidText";
        lastFidFromFid2Attribute = "SELECT MAX(fid) FROM fid2attribute";
        deleteCommentsQuery = "DELETE " + sqlAttributes + " FROM fidText where textType = 't' and fid in ( ";
        deletevaluePairQuery = "DELETE " + sqlAttributes + " FROM  fid2attribute where fid in ( ";
        fdata2DeleterQuery = "DELETE " + sqlAttributes + " FROM fdata2 where fid in ( ";
        deleteSequenceQuery = "DELETE " + sqlAttributes + " FROM fidText where textType = 's' and fid in ( ";
        deleteGen = "DELETE " + sqlAttributes + " FROM ";
        deleteReserve = " WHERE gname = ?";
        fdata2FieldsToInsert = "(fid, rid, fstart, fstop, fbin, ftypeid, " +
                "fscore, fstrand, fphase, ftarget_start, ftarget_stop, gname, " +
                "displayCode, displayColor) VALUES ";
        lockTables =  "LOCK TABLES fdata2 WRITE, fdata2_cv WRITE, fdata2_gv WRITE, fid2attribute WRITE, fidText WRITE, ftype WRITE, gclass WRITE, ftype2gclass WRITE, fmeta WRITE";
        unlockTables = "UNLOCK TABLES";
        insert = "INSERT " + sqlAttributes + " INTO ";
        fdataField = "(fid, rid, fstart, fstop, fbin, ftypeid, fscore, fstrand, fphase, gname) VALUES ";
        fdatavalues = "(?, ?, ?, ?, ?, ?, ?, ?, ?, ? )";
        attNameIdQuery = "SELECT name, attNameId FROM attNames WHERE name in (";
        attValueIdQuery = "SELECT value, attValueId FROM attValues WHERE md5 in (";

        attNames2ids = new HashMap();
        attValues2ids = new HashMap();
        ftype2attributeNameHash = new HashMap();
        fids2valuePairs = new HashMap();
        fid2FtypeId = new HashMap();

        lffLinesMd5 = new HashMap();
        annotationsMd5 = new HashMap();
    }

    protected void initializeTableBulkInsertManagers()
    {
        String tableName = "fdata2";
        String queryBootStrap = null;

        extraFieldsUpdater = new TableBulkInsertManager(sqlConnection);
        extraFieldsUpdater.setTableName(tableName);
        extraFieldsUpdater.setArrayDataFields(dataFieldsForFdata2);
        extraFieldsUpdater.setUpdateFields(updateFieldsFdata2);
        extraFieldsUpdater.setNeedCheckReservedId(true);
        extraFieldsUpdater.setQueryBootStrap(null);
        extraFieldsUpdater.initializeStringBuffer();

        queryBootStrap = "INSERT " + sqlAttributes +
                " INTO " + tableName + fdata2FieldsToInsert;
        fdata2Inserter = new TableBulkInsertManager(sqlConnection);
        fdata2Inserter.setNeedCheckReservedId(true);
        fdata2Inserter.setQueryBootStrap(queryBootStrap);
        fdata2Inserter.initializeStringBuffer();

        tableName = "fdata2_gv";
        queryBootStrap = "INSERT " + sqlAttributes +
                " INTO " + tableName + fdata2FieldsToInsert;

        fdata2InserterGV = new TableBulkInsertManager(sqlConnection);
        fdata2InserterGV.setNeedCheckReservedId(true);
        fdata2InserterGV.setQueryBootStrap(queryBootStrap);
        fdata2InserterGV.initializeStringBuffer();

        tableName = "fdata2_cv";
        queryBootStrap = "INSERT " + sqlAttributes +
                " INTO " + tableName + fdata2FieldsToInsert;
        fdata2InserterCV = new TableBulkInsertManager(sqlConnection);
        fdata2InserterCV.setNeedCheckReservedId(true);
        fdata2InserterCV.setQueryBootStrap(queryBootStrap);
        fdata2InserterCV.initializeStringBuffer();

        String fidTextFields ="(fid, ftypeid, textType, text) VALUES ";

        tableName = "fidText";
        queryBootStrap = "INSERT " + sqlAttributes +
                " INTO " + tableName + fidTextFields;
        fidTextInserter= new TableBulkInsertManager(sqlConnection);
        fidTextInserter.setQueryBootStrap(queryBootStrap);
        fidTextInserter.initializeStringBuffer();



        commentsDeleter = new TableBulkInsertManager(sqlConnection);
        commentsDeleter.setQueryBootStrap(deleteCommentsQuery);
        commentsDeleter.initializeStringBuffer();
        commentsDeleter.setUseCounterToLimit(true);
        commentsDeleter.setMaxNumberOfRecordsBeforeInsert(maxRecords);
        commentsDeleter.setEndExpression(")");
        commentsDeleter.setAutoInsert(false);



        valuePairDeleter = new TableBulkInsertManager(sqlConnection);
        valuePairDeleter.setQueryBootStrap(deletevaluePairQuery);
        valuePairDeleter.initializeStringBuffer();
        valuePairDeleter.setUseCounterToLimit(true);
        valuePairDeleter.setMaxNumberOfRecordsBeforeInsert(maxRecords);
        valuePairDeleter.setEndExpression(")");
        valuePairDeleter.setAutoInsert(false);



        fdata2Deleter = new TableBulkInsertManager(sqlConnection);
        fdata2Deleter.setQueryBootStrap(fdata2DeleterQuery);
        fdata2Deleter.initializeStringBuffer();
        fdata2Deleter.setUseCounterToLimit(true);
        fdata2Deleter.setMaxNumberOfRecordsBeforeInsert(maxRecords);
        fdata2Deleter.setEndExpression(")");
        fdata2Deleter.setAutoInsert(false);

        sequenceDeleter = new TableBulkInsertManager(sqlConnection);
        sequenceDeleter.setQueryBootStrap(deleteSequenceQuery);
        sequenceDeleter.initializeStringBuffer();
        sequenceDeleter.setUseCounterToLimit(true);
        sequenceDeleter.setMaxNumberOfRecordsBeforeInsert(maxRecords);
        sequenceDeleter.setEndExpression(")");
        sequenceDeleter.setAutoInsert(false);


        attNameInserter = new TableBulkInsertManager(sqlConnection);
        attNameInserter.setQueryBootStrap("INSERT " + sqlAttributes + " into attNames (name) VALUES");
        attNameInserter.initializeStringBuffer();
        attNameInserter.setUseCounterToLimit(true);
        attNameInserter.setMaxNumberOfRecordsBeforeInsert(maxRecords);
        attNameInserter.setAutoInsert(false);

        attValueInserter = new TableBulkInsertManager(sqlConnection);
        attValueInserter.setQueryBootStrap("INSERT " + sqlAttributes + " into attValues (value, md5) VALUES");
        attValueInserter.initializeStringBuffer();
        attValueInserter.setUseCounterToLimit(true);
        attValueInserter.setMaxNumberOfRecordsBeforeInsert(maxRecords);
        attValueInserter.setAutoInsert(false);


        fid2attribute = new TableBulkInsertManager(sqlConnection);
        fid2attribute.setQueryBootStrap("insert " + sqlAttributes + " into fid2attribute (fid, attNameId, attValueId) VALUES ");
        fid2attribute.initializeStringBuffer();
        fid2attribute.setUseCounterToLimit(true);
        fid2attribute.setMaxNumberOfRecordsBeforeInsert(maxRecords);
        fid2attribute.setAutoInsert(false);

        ftype2attributeName = new TableBulkInsertManager(sqlConnection);
        ftype2attributeName.setQueryBootStrap("insert " + sqlAttributes + " into ftype2attributeName(ftypeid, attNameId) VALUES ");
        ftype2attributeName.initializeStringBuffer();
        ftype2attributeName.setUseCounterToLimit(true);
        ftype2attributeName.setMaxNumberOfRecordsBeforeInsert(maxRecords);
        ftype2attributeName.setAutoInsert(false);




        selectAttNameId = new StringBuffer(150);
        selectAttValueId = new StringBuffer(150);
    }




    public void setUseTimmingUtil(boolean useTimmingUtil)
    {
        this.useTimmingUtil = useTimmingUtil;
    }

    public String getTimmingInfo()
    {
        return timmingInfo;
    }

    protected void initializePrepareStatements()
    {
        StringBuffer genericBuffer;
        genericBuffer = new StringBuffer( 200 );

        try
        {

            selectMaxFidFdata2 = sqlConnection.prepareStatement(lastMaxFid);
            selectMaxFidFdata2CV = sqlConnection.prepareStatement(lastMaxFidcv);
            selectMaxFidFdata2GV = sqlConnection.prepareStatement(lastMaxFidgv);
            selectMaxFromFidText = sqlConnection.prepareStatement(lastFidFromFidText);
            selectMaxFromFid2Attribute = sqlConnection.prepareStatement(lastFidFromFid2Attribute);
            lockFdataTables = sqlConnection.prepareStatement(lockTables);
            unlockFdataTables = sqlConnection.prepareStatement(unlockTables);
            genericBuffer.append(insert).append("fdata2 ").append(fdataField).append(fdatavalues);
            currPstmt = sqlConnection.prepareStatement( genericBuffer.toString());
            genericBuffer.setLength(0);
            genericBuffer.append(insert).append("fdata2_cv ").append(fdataField).append(fdatavalues);
            currPstmtCV = sqlConnection.prepareStatement( genericBuffer.toString());
            genericBuffer.setLength(0);
            genericBuffer.append(insert).append("fdata2_gv ").append(fdataField).append(fdatavalues);
            currPstmtGV = sqlConnection.prepareStatement( genericBuffer.toString());

            genericBuffer.setLength(0);
            genericBuffer.append(deleteGen).append("fdata2 ").append(deleteReserve);
            deleteReservedFromFdata2 = sqlConnection.prepareStatement(genericBuffer.toString());
            genericBuffer.setLength(0);
            genericBuffer.append(deleteGen).append("fdata2_cv ").append(deleteReserve);
            deleteReservedFromFdata2_CV = sqlConnection.prepareStatement(genericBuffer.toString());
            genericBuffer.setLength(0);
            genericBuffer.append(deleteGen).append("fdata2_gv ").append(deleteReserve);
            deleteReservedFromFdata2_GV = sqlConnection.prepareStatement(genericBuffer.toString());
            String deleteFromFidText = "DELETE " + sqlAttributes + " FROM fidText where fid = ? and TextType = ? ";
            deleteFromFidTextPS = sqlConnection.prepareStatement(deleteFromFidText);

            String selectTextFromFidTextQuery = "SELECT text FROM fidText WHERE fid = ? AND ftypeid = ? AND textType = ?";
            selectTextFromFidText = sqlConnection.prepareStatement(selectTextFromFidTextQuery);

        } catch (SQLException e)
        {
            e.printStackTrace(System.err);  //To change body of catch statement use File | Settings | File Templates.
        }

    }




    protected boolean anyFieldsIsLargerThanDefault()
    {
        if( extraFieldsUpdateCounter >= maxRecords ||
                fdata2InserterCounter >= maxRecords ||
                fdata2InserterGVCounter >= maxRecords ||
                fdata2InserterCVCounter >= maxRecords ||
                fidTextInserterCounter >= maxRecords ||
                commentsDeleterCounter >= maxRecords  ||
                valuePairDeleterCounter >= maxRecords ||
                fdata2DeleterCounter >= maxRecords ||
                sequenceDeleterCounter >= maxRecords )
            return true;
        else
            return false;
    }


    public void printAttValuesBuffers()
    {
        fullLogFile.println(attNameInserter.getTableBuffer().toString());
        fullLogFile.println(attValueInserter.getTableBuffer().toString());
        fullLogFile.println(fid2attribute.getTableBuffer().toString());
        fullLogFile.println(ftype2attributeName.getTableBuffer().toString());
        fullLogFile.flush();
    }


    public void addValuePairRecord(long currentId, int ftypeId, HashMap valuesToAdd)
    {
        if(valuesToAdd == null || valuesToAdd.size() == 0) return;

        if(!fid2FtypeId.containsKey(""+ currentId))
        {
            fid2FtypeId.put("" + currentId, "" + ftypeId);
        }

        if(!fids2valuePairs.containsKey(""+ currentId))
        {
            if(valuesToAdd == null || valuesToAdd.size() < 1)
            {
                fids2valuePairs.put("" + currentId, "" + null);
            }
            else
            {
                fids2valuePairs.put("" + currentId, valuesToAdd);
            }
        }

        if(attNameCounter == 0)
        {
            selectAttNameId.setLength(0);
            selectAttNameId.append(attNameIdQuery);
        }

        if(attValueCounter == 0)
        {
            selectAttValueId.setLength(0);
            selectAttValueId.append(attValueIdQuery);
        }

//TODO  may be I can move this block to a method or to the processRecords method
        Iterator  valuePairIterator = valuesToAdd.entrySet().iterator() ;

        while(valuePairIterator.hasNext())
        {
            Map.Entry valuePairMap = (Map.Entry) valuePairIterator.next() ;
            String key = (String)valuePairMap.getKey();

            if(!attNames2ids.containsKey(key))
            {
                attNames2ids.put(key.toUpperCase(), null);
                attNameInserter.addSingleValue(key);
                if(attNameCounter > 0) selectAttNameId.append(", ");
                    selectAttNameId.append("'").append(GenboreeUtils.mysqlEscapeSpecialChars(key)).append("'"); 
                attNameCounter++;
            }
            ArrayList value = (ArrayList) valuePairMap.getValue();
            for(int i = 0; i < value.size(); i++)
            {
                String tempValue = (String)value.get(i);
                if(!attValues2ids.containsKey(tempValue))
                {
                    attValues2ids.put(tempValue, null);
                    attValueInserter.addSingleValueWithMd5(tempValue);
                    if(attValueCounter > 0) selectAttValueId.append(", ");
                    selectAttValueId.append("MD5('").append(GenboreeUtils.mysqlEscapeSpecialChars(tempValue)).append("')");
                    attValueCounter++;
                }
            }
        }

        if(attNameCounter > maxRecords || attValueCounter > maxRecords)
        {
            processRecords();
        }
    }

    private void processRecords( )
    {
        Statement attValuesStatement = null;
        ResultSet attValuesResultSet = null;
        Statement attNameStatement = null;
        ResultSet attNameResultSet = null;
        String fid = null;
        String ftypeId = null;
        String name = null;
        String value = null;
        String attNameId = null;
        String attValueId = null;
        java.util.Date now = null;

        now = new java.util.Date() ;
        fullLogFile.println(now.toString() + "\tFlushing valuePairDeleter" );
        fullLogFile.flush();
        valuePairDeleter.flushRecord(fullLogFile);
        valuePairDeleter.setRecordCounter(0);

        now = new java.util.Date() ;
        fullLogFile.println(now.toString() + "\tFlushing attNameInserter" );
        fullLogFile.flush();
        attNameInserter.flushRecord(fullLogFile);
        attNameInserter.setRecordCounter(0);
        now = new java.util.Date() ;
        fullLogFile.println(now.toString() + "\tFlushing attValueInserter" );
        fullLogFile.flush();
        attValueInserter.flushRecord(fullLogFile);
        attValueInserter.setRecordCounter(0);

        if(selectAttNameId.length() < 1 || selectAttValueId.length() < 1)
        {
            return;
        }


        try
        {
            attNameStatement= sqlConnection.createStatement();
            attValuesStatement = sqlConnection.createStatement();
            selectAttNameId.append(")");
            selectAttValueId.append(")");
            attNameCounter = 0;
            attValueCounter = 0;
            now = new java.util.Date() ;
            fullLogFile.println(now.toString() + "\tQuering the attName and attValue tables" );
            fullLogFile.flush();
            attNameResultSet = attNameStatement.executeQuery(selectAttNameId.toString());
            attValuesResultSet = attValuesStatement.executeQuery(selectAttValueId.toString());

//            System.err.println("the selectAttNameId is " + selectAttNameId.toString());
//             System.err.println("the selectAttValueId is " + selectAttValueId.toString());
//             System.err.flush();
            

            if(useTimmingUtil)
                bulkUploadManagerTimer.addMsg("After the executing the select statement");

            while( attNameResultSet.next() )
            {
                name = attNameResultSet.getString("name");
                attNameId = attNameResultSet.getString("attNameId");
                name = name.toUpperCase();
                attNames2ids.put(name, attNameId);
            }
            attNameResultSet.close();

            while( attValuesResultSet.next() )
            {
                value = attValuesResultSet.getString("value");
                attValueId = attValuesResultSet.getString("attValueId");
                attValues2ids.put(value, attValueId);
//                System.err.println("the fid2attribute query is " + fid2attribute.getQuery());
//                System.err.flush();
            }
            attValuesResultSet.close();

        } catch (SQLException e3) {
            e3.printStackTrace(System.err);
        }

//TODO  may be I can move this block to a method
//        System.err.println("the size of the attName2ids is " + attNames2ids.size() + " and the size of the attValues2ids is " +  attValues2ids.size());
//        System.err.flush();
        Iterator  fids2valuePairsIterator = fids2valuePairs.entrySet().iterator() ;
        while(fids2valuePairsIterator.hasNext())
        {
            Map.Entry fids2valuePairsMap = (Map.Entry)fids2valuePairsIterator.next() ;
            fid = (String)fids2valuePairsMap.getKey();
            HashMap myvaluePairs = (HashMap)fids2valuePairsMap.getValue();
            ftypeId = (String)fid2FtypeId.get(fid);
            Iterator valuePairIterator = myvaluePairs.entrySet().iterator() ;
            while(valuePairIterator.hasNext())
            {
                Map.Entry valuePairMap = (Map.Entry) valuePairIterator.next() ;

                name  = (String)valuePairMap.getKey();
                name = name.toUpperCase();
                attNameId =  (String)attNames2ids.get(name);
                ArrayList values = (ArrayList) valuePairMap.getValue();
                for(int i = 0; i < values.size(); i++)
                {
                    value = (String)values.get(i);
                    attValueId = (String)attValues2ids.get(value);

                    fid2attribute.addThreeInts(fid, attNameId, attValueId);
                    String tempFtype2attName = ftypeId + "-" + attNameId;

                    if(!ftype2attributeNameHash.containsKey(tempFtype2attName))
                    {
                        ftype2attributeNameHash.put(tempFtype2attName, tempFtype2attName);
                        ftype2attributeName.addTwoInts(ftypeId, attNameId);
                    }

                }
            }
        }
//        System.err.println("the fid2attribute query is " + fid2attribute.getQuery());
//        System.err.flush();
        now = new java.util.Date() ;
        fullLogFile.println(now.toString() + "\tFlushing the fid2attribute table" );
        fullLogFile.flush();
        fid2attribute.flushRecord(fullLogFile);
        fid2attribute.setRecordCounter(0);
        ftype2attributeName.flushRecord(fullLogFile);
        ftype2attributeName.setRecordCounter(0);
        selectAttNameId.setLength( 0 );
        fid2FtypeId.clear();
        fids2valuePairs.clear();
        attNames2ids.clear();
        attValues2ids.clear();


    }


    protected void deleteReservedIds()
    {
        String previousKey = null;
        String previousKeyCV = null;
        String previousKeyGV = null;

        previousKey = getFdata2ReservedName();
        previousKeyCV = getFdata2CVReservedName();
        previousKeyGV = getFdata2GVReservedName();

        try {
            if(previousKey != null)
            {

                deleteReservedFromFdata2.clearParameters();
                deleteReservedFromFdata2.setString(1, previousKey);
                deleteReservedFromFdata2.executeUpdate();
            }
            if(previousKeyCV != null)
            {
                deleteReservedFromFdata2_CV.clearParameters();
                deleteReservedFromFdata2_CV.setString(1, previousKeyCV);
                deleteReservedFromFdata2_CV.executeUpdate();

            }
            if(previousKeyGV != null)
            {
                deleteReservedFromFdata2_GV.clearParameters();
                deleteReservedFromFdata2_GV.setString(1, previousKeyGV);
                deleteReservedFromFdata2_GV.executeUpdate();
            }

        } catch (SQLException e) {
            e.printStackTrace(System.err);
            System.err.flush();
        }
    }

    public void terminateAttribute()
    {

        processRecords();
        attNameInserter.flushRecord(fullLogFile);
        attValueInserter.flushRecord(fullLogFile);
        fid2attribute.flushRecord(fullLogFile);
        ftype2attributeName.flushRecord(fullLogFile);
    }



    protected void initialReserveOfFids()
    {

        String reservedKeyFd2 = null;
        String reservedKeyFd2CV = null;
        String reservedKeyFd2GV = null;
        String previousKeyFd2 = null;
        String previousKeyFd2CV = null;
        String previousKeyFd2GV = null;
        int reservedIdForFd2 = 0;
        int reservedIdForFd2CV = 0;
        int reservedIdForFd2GV = 0;

        java.util.Date currentDate = new java.util.Date();
        String tempKey = null;

        if(!isTableLocked())
        {
            lockTables();
        }
        setStartRange(); // In here finds out the max in the fdata table and set var fdata2StartRange

        setFdata2CurrentId(getFdata2StartRange() + 1);
        setFdata2CVCurrentId(getFdata2CVStartRange() + 1);
        setFdata2GVCurrentId(getFdata2GVStartRange() + 1);

        reservedIdForFd2 = getFdata2StartRange() + numberOfLinesInLffFile + 2;
        reservedIdForFd2CV = getFdata2CVStartRange() + numberOfLinesInLffFile + 2;
        reservedIdForFd2GV = getFdata2CVStartRange() + numberOfLinesInLffFile + 2;

        tempKey = "reserved key for database = " + databaseName + "with fid = " + reservedIdForFd2 +  "on " +currentDate.toString();
        reservedKeyFd2 = GenboreeUtils.generateUniqueKey(tempKey);
        tempKey = "reserved key for database = " + databaseName + "with fid = " + reservedIdForFd2CV +  "on " +currentDate.toString();
        reservedKeyFd2CV = GenboreeUtils.generateUniqueKey(tempKey);
        tempKey = "reserved key for database = " + databaseName + "with fid = " + reservedIdForFd2GV +  "on " +currentDate.toString();
        reservedKeyFd2GV = GenboreeUtils.generateUniqueKey(tempKey);
        previousKeyFd2 = getFdata2ReservedName();
        previousKeyFd2CV = getFdata2CVReservedName();
        previousKeyFd2GV = getFdata2GVReservedName();


        try {
            if(previousKeyFd2 != null)
            {
                deleteReservedFromFdata2.setString(1, previousKeyFd2);
                deleteReservedFromFdata2.executeUpdate();
            }
            if(previousKeyFd2CV != null)
            {
                deleteReservedFromFdata2_CV.setString(1, previousKeyFd2CV);
                deleteReservedFromFdata2_CV.executeUpdate();
            }

            if(previousKeyFd2GV != null)
            {
                deleteReservedFromFdata2_GV.setString(1, previousKeyFd2GV);
                deleteReservedFromFdata2_GV.executeUpdate();
            }

            currPstmt.setInt(1, reservedIdForFd2 + 1); // TODO new change bug fix
            currPstmt.setInt( 2,  -1);
            currPstmt.setLong( 3, -50 );
            currPstmt.setLong( 4, -50 );
            currPstmt.setString( 5, "0");
            currPstmt.setInt( 6,  -1);
            currPstmt.setDouble( 7, -1.0);
            currPstmt.setString( 8, "");
            currPstmt.setString( 9, "");
            currPstmt.setString( 10, reservedKeyFd2);
            currPstmt.executeUpdate();

            currPstmtCV.setInt(1, reservedIdForFd2CV + 1); // TODO new change bug fix
            currPstmtCV.setInt( 2,  -1);
            currPstmtCV.setLong( 3, -50 );
            currPstmtCV.setLong( 4, -50 );
            currPstmtCV.setString( 5, "0");
            currPstmtCV.setInt( 6,  -1);
            currPstmtCV.setDouble( 7, -1.0);
            currPstmtCV.setString( 8, "");
            currPstmtCV.setString( 9, "");
            currPstmtCV.setString( 10, reservedKeyFd2CV);
            currPstmtCV.executeUpdate();

            currPstmtGV.setInt(1, reservedIdForFd2GV + 1); // TODO new change bug fix
            currPstmtGV.setInt( 2,  -1);
            currPstmtGV.setLong( 3, -50 );
            currPstmtGV.setLong( 4, -50 );
            currPstmtGV.setString( 5, "0");
            currPstmtGV.setInt( 6,  -1);
            currPstmtGV.setDouble( 7, -1.0);
            currPstmtGV.setString( 8, "");
            currPstmtGV.setString( 9, "");
            currPstmtGV.setString( 10, reservedKeyFd2GV);
            currPstmtGV.executeUpdate();


        } catch (SQLException e) {
            e.printStackTrace(System.err);
        }


        setFdata2ReservedName(reservedKeyFd2);
        setFdata2_counter( 0 );
        setFdata2CurrentId(getFdata2StartRange() + 1);
        setFdata2CVReservedName(reservedKeyFd2CV);
        setFdata2_counter_cv( 0 );
        setFdata2CVCurrentId(getFdata2CVStartRange() + 1);
        setFdata2GVReservedName(reservedKeyFd2GV);
        setFdata2_counter_gv( 0 );
        setFdata2GVCurrentId(getFdata2GVStartRange() + 1);
        setFdata2ReservedId(reservedIdForFd2);
        setFdata2CVReservedId(reservedIdForFd2CV);
        setFdata2GVReservedId(reservedIdForFd2GV);


        if(isTableLocked())
            unLockTables();
    }






    public PrintStream getFullLogFile()
    {
        return fullLogFile;
    }

    public void setFullLogFile(PrintStream fullLogFile)
    {
        this.fullLogFile = fullLogFile;
    }

    public String getFdata2ReservedName()
    {
        return fdata2ReservedName;
    }
    public void setFdata2ReservedName(String fdata2ReservedName)
    {
        this.fdata2ReservedName = fdata2ReservedName;
    }
    public String getFdata2CVReservedName()
    {
        return fdata2CVReservedName;
    }
    public void setFdata2CVReservedName(String fdata2CVReservedName)
    {
        this.fdata2CVReservedName = fdata2CVReservedName;
    }
    public String getFdata2GVReservedName()
    {
        return fdata2GVReservedName;
    }
    public void setFdata2GVReservedName(String fdata2GVReservedName)
    {
        this.fdata2GVReservedName = fdata2GVReservedName;
    }

    public int getNumberOfLinesInLffFile()
    {
        return numberOfLinesInLffFile;
    }

    public void setNumberOfLinesInLffFile(int numberOfLinesInLffFile)
    {
        this.numberOfLinesInLffFile = numberOfLinesInLffFile;
        initialReserveOfFids();
    }


    private void incrementCounter(int tableType)
    {
        if(tableType == fdata2Table)
        {
            fdata2_counter++;
            fdata2CurrentId++;
            fdata2InserterCounter++;
        }
        else if(tableType == fdata2_cvTable)
        {
            fdata2_counter_cv++;
            fdata2InserterCVCounter++;
            fdata2CVCurrentId++;
        }
        else if(tableType == fdata2_gvTable)
        {
            fdata2_counter_gv++;
            fdata2InserterGVCounter++;
            fdata2GVCurrentId++;
        }

    }




    public void fdata2GVStartRange(int fdata2GVStartRange)
    {
        this.fdata2GVStartRange = fdata2GVStartRange;
    }


    public int getMaxNumberOfInserts()
    {
        return maxNumberOfInserts;
    }
    public void setMaxNumberOfInserts(int maxNumberOfInserts)
    {
        this.maxNumberOfInserts = maxNumberOfInserts;
    }

    public void setFdata2StartRange(int fdata2StartRange)
    {
        this.fdata2StartRange = fdata2StartRange;
    }
    public void setFdata2CVStartRange(int fdata2CVStartRange)
    {
        this.fdata2CVStartRange = fdata2CVStartRange;
    }

    public TableBulkInsertManager getExtraFieldsUpdater()
    {
        return extraFieldsUpdater;
    }

    public void setExtraFieldsUpdater(TableBulkInsertManager extraFieldsUpdater)
    {
        this.extraFieldsUpdater = extraFieldsUpdater;
    }




    protected boolean printQueries = false;

    public boolean isPrintQueries()
    {
        return printQueries;
    }
    public void setPrintQueries(boolean printQueries)
    {
        this.printQueries = printQueries;
    }

    public int getFdata2_counter()
    {
        return fdata2_counter;
    }
    public int getFdata2_counter_gv()
    {
        return fdata2_counter_gv;
    }
    public int getFdata2_counter_cv()
    {
        return fdata2_counter_cv;
    }
    public void setFdata2_counter(int fdata2_counter)
    {
        this.fdata2_counter = fdata2_counter;
    }
    public void setFdata2_counter_gv(int fdata2_counter_gv)
    {
        this.fdata2_counter_gv = fdata2_counter_gv;
    }
    public void setFdata2_counter_cv(int fdata2_counter_cv)
    {
        this.fdata2_counter_cv = fdata2_counter_cv;
    }



    private long getCurrentFid(int tableType)
    {
        long currentFid = 0;
        int counter = -1;
        int maxValue = -1;

        if(tableType == 0)
        {
            counter = getFdata2_counter();
            maxValue = getFdata2StartRange();
            currentFid = counter + maxValue + 1;
            if(currentFid == getFdata2ReservedId())
            {
                fullLogFile.println("IN GETCOUNTERFID table type 0 THIS SECTION SHOULD NOT EXCECUTE EVENTUALLY SHOULD BE REMOVED!");
                fullLogFile.flush();
                incrementCounter(tableType);
                currentFid++;
            }
        }
        else if(tableType == 1)
        {
            counter = getFdata2_counter_cv();
            maxValue = getFdata2CVStartRange();
            currentFid = counter + maxValue + 1;
            if(currentFid == getFdata2CVReservedId())
            {
                fullLogFile.println("IN GETCOUNTERFID table type 1 THIS SECTION SHOULD NOT EXCECUTE EVENTUALLY SHOULD BE REMOVED!");
                fullLogFile.flush();
                incrementCounter(tableType);
                currentFid++;
            }
        }
        else if(tableType == 2)
        {
            counter = getFdata2_counter_gv();
            maxValue = getFdata2GVStartRange();
            currentFid = counter + maxValue + 1;
            if(currentFid == getFdata2CVReservedId())
            {
                fullLogFile.println("IN GETCOUNTERFID table type 2 THIS SECTION SHOULD NOT EXCECUTE EVENTUALLY SHOULD BE REMOVED!");
                fullLogFile.flush();
                incrementCounter(tableType);
                currentFid++;
            }
        }


        return currentFid;
    }


    protected String fetchTextFromFidText(long fid, int typeId, char type)
    {
        ResultSet fidRs = null;
        String textField = null;

        try
        {
            selectTextFromFidText.setLong( 1, fid );
            selectTextFromFidText.setInt( 2, typeId );
            selectTextFromFidText.setString( 3, String.valueOf(type) );
            fidRs = selectTextFromFidText.executeQuery();
            if( fidRs.next() ) textField = fidRs.getString("text");

        } catch (SQLException e)
        {
            e.printStackTrace(System.err);
        }
        finally
        {
            return textField;
        }
    }




    protected boolean insertData = true;

    public boolean isInsertData()
    {
        return insertData;
    }
    public void setInsertData(boolean insertData)
    {
        this.insertData = insertData;
    }





    protected boolean tableLocked = false;


    public boolean isTableLocked()
    {
        return tableLocked;
    }
    public void setTableLocked(boolean tableLocked)
    {
        this.tableLocked = tableLocked;
    }


    protected boolean lockTables()
    {
        boolean tablesSuccessfullyLock = false;

        try
        {
            if(lockFdataTables.executeUpdate() >0)
                tablesSuccessfullyLock = true;
            setTableLocked(true);
        } catch (SQLException e)
        {
            e.printStackTrace(System.err);
        }
        finally
        {
            return tablesSuccessfullyLock;
        }
    }
    protected boolean unLockTables()
    {
        boolean operationCompleted = false;

        try
        {
            if(unlockFdataTables.executeUpdate() > 0 )
                operationCompleted = true;
            setTableLocked(false);
        } catch (SQLException e)
        {
            e.printStackTrace(System.err);
        }
        finally
        {
            return operationCompleted;
        }
    }

    protected void setStartRange()
    {
        ResultSet fidRs = null;
        try
        {
            fidRs = selectMaxFidFdata2.executeQuery();
            if( fidRs.next() ) fdata2StartRange = fidRs.getInt(1);
            fidRs = null;
            fidRs = selectMaxFidFdata2CV.executeQuery();
            if( fidRs.next() ) fdata2CVStartRange = fidRs.getInt(1);
            fidRs = null;
            fidRs = selectMaxFidFdata2GV.executeQuery();
            if( fidRs.next() ) fdata2GVStartRange = fidRs.getInt( 1 );
            fidRs = null;
            fidRs = selectMaxFromFidText.executeQuery();
            if( fidRs.next() ) fidTextStartRange = fidRs.getInt( 1 );
            fidRs = null;
            fidRs = selectMaxFromFid2Attribute.executeQuery();
            if( fidRs.next() ) fid2AttributeStartRange = fidRs.getInt( 1 );
            /* We only care about fdata2StartRange the CV and GV tables should be removed soon MLGG 02/18/09 */
            if(fidTextStartRange > fdata2StartRange ) fdata2StartRange = fidTextStartRange;
            if(fid2AttributeStartRange > fdata2StartRange ) fdata2StartRange = fid2AttributeStartRange;



        } catch (SQLException e)
        {
            e.printStackTrace(System.err);
        }
    }
    protected void setStartRange(int tableType)
    {
        ResultSet fidRs = null;
        try
        {
            fidRs = selectMaxFromFidText.executeQuery();
            if( fidRs.next() ) fidTextStartRange = fidRs.getInt( 1 );
            fidRs = null;
            fidRs = selectMaxFromFid2Attribute.executeQuery();
            if( fidRs.next() ) fid2AttributeStartRange = fidRs.getInt( 1 );

            if(tableType == fdata2Table)
            {
                fidRs = null;
                fidRs = selectMaxFidFdata2.executeQuery();
                if( fidRs.next() ) fdata2StartRange = fidRs.getInt(1);
                /* We only care about fdata2StartRange the CV and GV tables should be removed soon MLGG 02/18/09 */
                if(fidTextStartRange > fdata2StartRange ) fdata2StartRange = fidTextStartRange;
                if(fid2AttributeStartRange > fdata2StartRange ) fdata2StartRange = fid2AttributeStartRange;
            }
            else if(tableType == fdata2_cvTable)
            {
                fidRs = null;
                fidRs = selectMaxFidFdata2CV.executeQuery();
                if( fidRs.next() ) fdata2CVStartRange = fidRs.getInt(1);
            }
            else if(tableType == fdata2_gvTable)
            {
                fidRs = null;
                fidRs = selectMaxFidFdata2GV.executeQuery();
                if( fidRs.next() ) fdata2GVStartRange = fidRs.getInt(1);
            }

        } catch (SQLException e)
        {
            e.printStackTrace(System.err);
        }
    }



    public int getFdata2StartRange()
    {
        return fdata2StartRange;
    }
    public int getFdata2CVStartRange()
    {
        return fdata2CVStartRange;
    }
    public int getFdata2GVStartRange()
    {
        return fdata2GVStartRange;
    }



    protected void reserveFids(int tableType)
    {
        String reservedKey = null;
        PreparedStatement tempPrepStatement = null;
        PreparedStatement deleteTempPST = null;
        String previousKey = null;
        int nextValue = 0;

        lockTables();
        setStartRange(tableType);

        if(tableType == fdata2Table)
        {
            setFdata2CurrentId(getFdata2StartRange() + 1);
            nextValue = getFdata2CurrentId() + getMaxNumberOfInserts();
            tempPrepStatement = currPstmt;
            deleteTempPST = deleteReservedFromFdata2;
            previousKey = getFdata2ReservedName();
        }
        else if(tableType == fdata2_cvTable)
        {
            setFdata2CVCurrentId(getFdata2CVStartRange() + 1);
            nextValue = getFdata2CVCurrentId() + getMaxNumberOfInserts();
            tempPrepStatement = currPstmtCV;
            deleteTempPST = deleteReservedFromFdata2_CV;
            previousKey = getFdata2CVReservedName();
        }
        else if(tableType == fdata2_gvTable)
        {
            setFdata2GVCurrentId(getFdata2GVStartRange() + 1);
            nextValue = getFdata2GVCurrentId() + getMaxNumberOfInserts();
            tempPrepStatement = currPstmtGV;
            deleteTempPST = deleteReservedFromFdata2_GV;
            previousKey = getFdata2GVReservedName();
        }
        else
        {
            // I don't need this for the comments at least for now
        }


        java.util.Date currentDate = new java.util.Date();
        String tempKey = "reserved key for database = " + databaseName + "with fid = " + nextValue +  "on " +currentDate.toString();
        reservedKey = GenboreeUtils.generateUniqueKey(tempKey);


        try {
            if(previousKey != null)
            {
                deleteTempPST.clearParameters();
                deleteTempPST.setString(1, previousKey);
                deleteTempPST.executeUpdate();
            }
            tempPrepStatement.clearParameters();
            tempPrepStatement.setInt(1, nextValue + 1); //TODO new change
            tempPrepStatement.setInt( 2,  -1);
            tempPrepStatement.setLong( 3, -50 );
            tempPrepStatement.setLong( 4, -50 );
            tempPrepStatement.setString( 5, "0");
            tempPrepStatement.setInt( 6,  -1);
            tempPrepStatement.setDouble( 7, -1.0);
            tempPrepStatement.setString( 8, "");
            tempPrepStatement.setString( 9, "");
            tempPrepStatement.setString( 10, reservedKey);

            tempPrepStatement.executeUpdate();
        } catch (SQLException e) {
            e.printStackTrace(System.err);
            System.err.flush();
        }


        if(tableType == fdata2Table)
        {
            setFdata2ReservedName(reservedKey);
            setFdata2_counter( 0 );
            setFdata2ReservedId(nextValue);
        }
        else if(tableType == fdata2_cvTable)
        {
            setFdata2CVReservedName(reservedKey);
            setFdata2_counter_cv( 0 );
            setFdata2CVReservedId(nextValue);
        }
        else if(tableType == fdata2_gvTable)
        {
            setFdata2GVReservedName(reservedKey);
            setFdata2_counter_gv( 0 );
            setFdata2GVReservedId(nextValue);
        }


        if(isTableLocked())
            unLockTables();
    }

    protected void finalFlushRecord()
    {
        if(isPrintQueries())
        {
            printStrinBuffer();
        }
        if(isInsertData())
        {
            submitStrinBuffer(true);
        }

        System.err.flush();
        cleanStringBuffers();
        if(useTimmingUtil)
        {
            bulkUploadManagerTimer.addMsg("Ending finalFlushRecord");
            timmingInfo = bulkUploadManagerTimer.generateStringWithReport();
        }
    }

    protected void flushRecord()
    {
        if(isPrintQueries())
        {
            printStrinBuffer();
        }
        if(isInsertData())
        {
            submitStrinBuffer(true);
        }
        cleanStringBuffers();
    }


    protected void reserveFidsInAllTables()
    {
        reserveFids(fdata2Table);
        reserveFids(fdata2_cvTable);
        reserveFids(fdata2_gvTable);
    }

    public int getFdata2CurrentId()
    {
        return fdata2CurrentId;
    }
    public void setFdata2CurrentId(int fdata2CurrentId)
    {
        this.fdata2CurrentId = fdata2CurrentId;
    }
    public int getFdata2CVCurrentId()
    {
        return fdata2CVCurrentId;
    }
    public void setFdata2CVCurrentId(int fdata2CVCurrentId)
    {
        this.fdata2CVCurrentId = fdata2CVCurrentId;
    }
    public int getFdata2GVCurrentId()
    {
        return fdata2GVCurrentId;
    }


    public void setFdata2GVCurrentId(int fdata2GVCurrentId)
    {
        this.fdata2GVCurrentId = fdata2GVCurrentId;
    }

    public int getFdata2ReservedId()
    {
        return fdata2ReservedId;
    }
    public void setFdata2ReservedId(int fdata2ReservedId)
    {
        this.fdata2ReservedId = fdata2ReservedId;
    }
    public int getFdata2CVReservedId()
    {
        return fdata2CVReservedId;
    }
    public void setFdata2CVReservedId(int fdata2CVReservedId)
    {
        this.fdata2CVReservedId = fdata2CVReservedId;
    }
    public int getFdata2GVReservedId()
    {
        return fdata2GVReservedId;
    }
    public void setFdata2GVReservedId(int fdata2GVReservedId)
    {
        this.fdata2GVReservedId = fdata2GVReservedId;
    }



    protected boolean checkIfCurrentIdIsInRange(int tableType)
    {
        if(tableType == fdata2Table)
        {
            if(getFdata2CurrentId() >=  getFdata2ReservedId())
                return false;
            else
                return true;
        }
        else if(tableType == fdata2_cvTable)
        {
            if(getFdata2CVCurrentId() >=  getFdata2CVReservedId())
                return false;
            else
                return true;
        }
        else if(tableType == fdata2_gvTable)
        {
            if(getFdata2GVCurrentId() >=  getFdata2GVReservedId())
                return false;
            else
                return true;
        }
        else
        {
            return true;
        }
    }


    public void setRecordCounter(int recordCounter)
    {
        this.recordCounter = recordCounter;
    }

    public void setMaxRecords(int maxRecords)
    {
        this.maxRecords = maxRecords;
    }


    public int getMaxSizeOfBufferInBytes()
    {
        return maxSizeOfBufferInBytes;
    }
    public void setMaxSizeOfBufferInBytes(int maxSizeOfBuffer)
    {
        this.maxSizeOfBufferInBytes = maxSizeOfBuffer;
    }

    public void printStrinBuffer()
    {
        extraFieldsUpdater.printStringBuffer();
        fdata2Inserter.printStringBuffer();
        fdata2InserterGV.printStringBuffer();
        fdata2InserterCV.printStringBuffer();
        commentsDeleter.printStringBuffer();
        valuePairDeleter.printStringBuffer();
        fdata2Deleter.printStringBuffer();
        sequenceDeleter.printStringBuffer();
        fidTextInserter.printStringBuffer();
    }

    public void cleanStringBuffers()
    {

        extraFieldsUpdater.cleanStringBuffers();
        extraFieldsUpdateCounter = 0;
        fdata2Inserter.cleanStringBuffers();
        fdata2InserterCounter = 0;
        fdata2InserterGV.cleanStringBuffers();
        fdata2InserterGVCounter = 0;
        fdata2InserterCV.cleanStringBuffers();
        fdata2InserterCVCounter = 0;
        commentsDeleter.cleanStringBuffers();
        commentsDeleterCounter = 0;
        valuePairDeleter.cleanStringBuffers();
        valuePairDeleterCounter = 0;

        sequenceDeleter.cleanStringBuffers();
        sequenceDeleterCounter = 0;
        fidTextInserter.cleanStringBuffers();
        fidTextInserterCounter = 0;
        fdata2Deleter.cleanStringBuffers();
        fdata2DeleterCounter = 0;

        lffLinesMd5.clear();
        annotationsMd5.clear();

    }

    protected void submitStrinBuffer(boolean goToSleep)
    {
        java.util.Date now = null;
        if(useTimmingUtil)
            bulkUploadManagerTimer.addMsg("start submitStringBuffer");

        now = new java.util.Date() ;
        fullLogFile.println(now.toString() + "\tUpdating records in fdata2 table" );
        fullLogFile.flush();
        extraFieldsUpdater.submitStringBuffer(fullLogFile);

        if(useTimmingUtil)
            bulkUploadManagerTimer.addMsg("the number of records for extra field are" +
                    extraFieldsUpdater.getRecordCounter() + " and the size of the buffer is " +
                    extraFieldsUpdater.getTableBuffer().length());

        now = new java.util.Date() ;
        fullLogFile.println(now.toString() + "\tFlushing fdata2" );
        fullLogFile.flush();
        fdata2Inserter.submitStringBuffer(fullLogFile);
        numberOfSuccessfullInsertsIntoFdata2 += fdata2Inserter.getNumberOfInserts();

        if(useTimmingUtil)
            bulkUploadManagerTimer.addMsg("the number of records for fdata field are" +
                    fdata2Inserter.getRecordCounter() + " and the size of the buffer is " +
                    fdata2Inserter.getTableBuffer().length());


        fdata2InserterGV.submitStringBuffer(fullLogFile);
        numberOfSuccessfullInsertsIntoFdata2GV += fdata2InserterGV.getNumberOfInserts();
        fdata2InserterCV.submitStringBuffer(fullLogFile);
        numberOfSuccessfullInsertsIntoFdata2CV += fdata2InserterCV.getNumberOfInserts();
        commentsDeleter.submitStringBuffer(fullLogFile);


        if(useTimmingUtil)
            bulkUploadManagerTimer.addMsg("the number of records for commentDeleter field are" +
                    commentsDeleter.getRecordCounter() + " and the size of the buffer is " +
                    commentsDeleter.getTableBuffer().length());

        if(useTimmingUtil)
            bulkUploadManagerTimer.addMsg("the number of records for valuePairDeleter field are" +
                    valuePairDeleter.getRecordCounter() + " and the size of the buffer is " +
                    valuePairDeleter.getTableBuffer().length());


        processRecords( );

        fdata2Deleter.submitStringBuffer(fullLogFile);
        if(useTimmingUtil)
            bulkUploadManagerTimer.addMsg("the number of records for fdata2Deleter field are" +
                    fdata2Deleter.getRecordCounter() + " and the size of the buffer is " +
                    fdata2Deleter.getTableBuffer().length());
        sequenceDeleter.submitStringBuffer(fullLogFile);
        if(useTimmingUtil)
            bulkUploadManagerTimer.addMsg("the number of records for sequenceDeleter field are" +
                    sequenceDeleter.getRecordCounter() + " and the size of the buffer is " +
                    sequenceDeleter.getTableBuffer().length());
        fidTextInserter.submitStringBuffer(fullLogFile);


        if(useTimmingUtil)
            bulkUploadManagerTimer.addMsg("the number of records for fidTextInserter field are" +
                    fidTextInserter.getRecordCounter() + " and the size of the buffer is " +
                    fidTextInserter.getTableBuffer().length());
        if(useTimmingUtil)
            bulkUploadManagerTimer.addMsg("finish submitStringBuffer");

        if(goToSleep)
        {
            try
            {
                Util.sleep(LffConstants.uploaderSleepTime);
            } catch (InterruptedException e)
            {
                System.err.println("Exeption suring sleep  submitStringBuffer tableBuffer");
                e.printStackTrace(System.err);
            }
        }
    }

    public void submitStrinBuffer(int tableType, boolean goToSleep)
    {
        java.util.Date now = null;
        if(tableType == fdata2Table)
        {

            if(useTimmingUtil)
                bulkUploadManagerTimer.addMsg("start submitStringBuffer for fdata2 table");
            now = new java.util.Date() ;
            fullLogFile.println(now.toString() + "\tFlushing group of fdata2 related tables " );
            fullLogFile.flush();
            fdata2Deleter.submitStringBuffer(fullLogFile);
            fdata2Inserter.submitStringBuffer(fullLogFile);
            commentsDeleter.submitStringBuffer(fullLogFile);
            sequenceDeleter.submitStringBuffer(fullLogFile);
            fidTextInserter.submitStringBuffer(fullLogFile);
            if(useTimmingUtil)
                bulkUploadManagerTimer.addMsg("finish submitStringBuffer for fdata2 table");
            now = new java.util.Date() ;
            fullLogFile.println(now.toString() + "\tFinish Flushing group of fdata2 related tables " );
            fullLogFile.flush();
        }
        else if(tableType == fdata2_cvTable)
        {
            fdata2InserterCV.submitStringBuffer(fullLogFile);
        }
        else if(tableType == fdata2_gvTable)
        {
            fdata2InserterGV.submitStringBuffer(fullLogFile);
        }
        else if(tableType == fidTextTable)
        {
            if(useTimmingUtil)
                bulkUploadManagerTimer.addMsg("start submitStringBuffer for fidText table");
            now = new java.util.Date() ;
            fullLogFile.println(now.toString() + "\tFlushing fidText table" );
            fullLogFile.flush();
            fdata2Deleter.submitStringBuffer(fullLogFile);
            commentsDeleter.submitStringBuffer(fullLogFile);
            sequenceDeleter.submitStringBuffer(fullLogFile);
            fidTextInserter.submitStringBuffer(fullLogFile);
            fdata2Inserter.submitStringBuffer(fullLogFile);
            if(useTimmingUtil)
                bulkUploadManagerTimer.addMsg("finish submitStringBuffer for fidText table");
            now = new java.util.Date() ;
            fullLogFile.println(now.toString() + "\tFinish flushing fidText table" );
            fullLogFile.flush();
        }
        else
        {
            System.err.println("Unknow table type " + tableType);
            System.err.flush();
        }

        if(goToSleep)
        {
            try
            {
                Util.sleep(LffConstants.uploaderSleepTime);
            } catch (InterruptedException e)
            {
                System.err.println("Exeption suring sleep  submitStringBuffer tableBuffer");
                e.printStackTrace(System.err);
            }
        }



    }

    public void updateFidText(LffData currentLffData)
    {
        String commentsFromDatabase = null;
        String sequenceFromDatabase = null;
        char typeOfNote = 0;
        boolean commentsFromDatabaseAreEmpty = false;
        boolean sequenceFromDatabaseAreEmpty = false;
        boolean commentsFromLffAreEmpty = false;
        boolean sequenceFromLffAreEmpty = false;
        boolean commentsAreEqual = false;
        boolean sequencesAreEqual = false;

        if(   !lffLinesMd5.containsKey(currentLffData.getLineMd5Value())  )
            lffLinesMd5.put(currentLffData.getLineMd5Value(), "lkey"); // I use this key just to test if the line is in the current buffer
        else
            return; // I already have seen the line before the user have multiple copies of the line


        commentsFromDatabase = fetchTextFromFidText(currentLffData.getFid(), currentLffData.getFtypeId(), 't');
        sequenceFromDatabase = fetchTextFromFidText(currentLffData.getFid(), currentLffData.getFtypeId(), 's');

        commentsFromLffAreEmpty = Util.isEmpty(currentLffData.getComments());
        if(!commentsFromLffAreEmpty && currentLffData.getComments().equals("."))
            commentsFromLffAreEmpty = true;

        sequenceFromLffAreEmpty = Util.isEmpty(currentLffData.getSequences());
        if(!sequenceFromLffAreEmpty && currentLffData.getSequences().equals("."))
            sequenceFromLffAreEmpty = true;


        commentsFromDatabaseAreEmpty =Util.isEmpty(commentsFromDatabase);
        if(!commentsFromDatabaseAreEmpty && commentsFromDatabase.equals("."))
            commentsFromDatabaseAreEmpty = true;
        sequenceFromDatabaseAreEmpty = Util.isEmpty(sequenceFromDatabase);
        if(!sequenceFromDatabaseAreEmpty && sequenceFromDatabase.equals("."))
            sequenceFromDatabaseAreEmpty = true;

        if(!commentsFromLffAreEmpty && !commentsFromDatabaseAreEmpty)
        {
            commentsAreEqual = commentsFromDatabase.equals(currentLffData.getComments());
        }
        if(!sequenceFromLffAreEmpty && !sequenceFromDatabaseAreEmpty)
            sequencesAreEqual = sequenceFromDatabase.equals(currentLffData.getSequences());


        if(!commentsFromLffAreEmpty && commentsFromDatabaseAreEmpty )
        {
            typeOfNote = 't';
            addValuesFidText(currentLffData, String.valueOf(typeOfNote));
        }
        else if(!commentsFromLffAreEmpty && !commentsFromDatabaseAreEmpty && !commentsAreEqual)
        {
            typeOfNote = 't';
            addValuesFidText(currentLffData, String.valueOf(typeOfNote));
        }
        else if(commentsFromLffAreEmpty && !commentsFromDatabaseAreEmpty)
        {
            commentsDeleter.addId("" + currentLffData.getFid());
            commentsDeleterCounter++;
        }


        if(!sequenceFromLffAreEmpty && sequenceFromDatabaseAreEmpty)
        {
            typeOfNote = 's';
            addValuesFidText(currentLffData, String.valueOf(typeOfNote));
        }
        else if(!sequenceFromLffAreEmpty && !sequenceFromDatabaseAreEmpty && !sequencesAreEqual)
        {
            typeOfNote = 's';
            addValuesFidText(currentLffData, String.valueOf(typeOfNote));
        }
        else if(sequenceFromLffAreEmpty && !sequenceFromDatabaseAreEmpty)
        {
            sequenceDeleter.addId("" + currentLffData.getFid());
            sequenceDeleterCounter++;
        }

    }


    protected void addToDeleteFdata2(long fid)
    {
        fdata2Deleter.addId("" + fid);
        fdata2DeleterCounter++;
        return;
    }

    protected void addValuePairIdsToDelete(long fid)
    {
        valuePairDeleter.addId("" + fid);
        valuePairDeleterCounter++;
        return;
    }

    protected void addValuesFidText(LffData currentLffData, String typeOfNote)
    {
        StringBuffer localFidTextBuffer = null;
        String idLength;
        boolean isDeleteFull = false;
        boolean isBufferFull = false;

        if(typeOfNote.equalsIgnoreCase("t"))
        {
            idLength = "" + currentLffData.getFid();
            isDeleteFull = commentsDeleter.checkIfBufferIsFull(idLength.length());
            localFidTextBuffer = currentLffData.exportComments2Insert();
            if(localFidTextBuffer != null)
                isBufferFull = fidTextInserter.checkIfBufferIsFull(localFidTextBuffer.length());
            else
                isBufferFull = fidTextInserter.checkIfBufferIsFull(0);
            if(isDeleteFull || isBufferFull || anyFieldsIsLargerThanDefault())
                flushRecord();
            commentsDeleter.addId(idLength);
            commentsDeleterCounter++;
            if(localFidTextBuffer != null)
            {
                fidTextInserter.addStringBuffer(localFidTextBuffer);
                fidTextInserterCounter++;
            }

        }
        else if(typeOfNote.equalsIgnoreCase("s"))
        {
            idLength = "" + currentLffData.getFid();
            isDeleteFull = sequenceDeleter.checkIfBufferIsFull(idLength.length());
            localFidTextBuffer = currentLffData.exportSequences2Insert();
            if(localFidTextBuffer != null)
                isBufferFull = fidTextInserter.checkIfBufferIsFull(localFidTextBuffer.length());
            else
                isBufferFull = fidTextInserter.checkIfBufferIsFull(0);
            if(isDeleteFull || isBufferFull || anyFieldsIsLargerThanDefault())
                flushRecord();
            sequenceDeleter.addId(idLength);
            sequenceDeleterCounter++;
            if(localFidTextBuffer != null)
            {
                fidTextInserter.addStringBuffer(localFidTextBuffer);
                fidTextInserterCounter++;
            }
        }
    }

    protected boolean addValuesFdata(LffData lffData)
    {
        boolean isFull = false;
        boolean passReservedId = false;

        StringBuffer localFdataBuffer = null;

        if(lffData == null || lffData.getGroupName() == null)
            return false;


        if(   !lffLinesMd5.containsKey(lffData.getLineMd5Value())  )
            lffLinesMd5.put(lffData.getLineMd5Value(), "lkey"); // I use this key just to test if the line is in the current buffer
        else
            return false; // I already have seen the line before the user have multiple copies of the line


        if(   !annotationsMd5.containsKey(lffData.getIndexMd5Key())  )
                annotationsMd5.put(lffData.getLineMd5Value(), "ikey");
        else // I already have the value in the current block of lff in memory  so the same annotation two times in the same lff file what to do for now nothing
        {
//            this.updateFidText(lffData);
            return false;
        }

        int tableType = lffData.getTableId();
        localFdataBuffer = lffData.exportFdata2Insert();

        if(tableType == fdata2Table)
        {
            isFull = fdata2Inserter.checkIfBufferIsFull(localFdataBuffer.length());
            passReservedId = ((getFdata2_counter() + getFdata2StartRange() + 1) >= getFdata2ReservedId());
            if(isFull || anyFieldsIsLargerThanDefault() || passReservedId)
                flushRecord();

            lffData.setFid(getCurrentFid(lffData.getTableId()));
            localFdataBuffer = lffData.exportFdata2Insert();
            fdata2Inserter.addStringBuffer(localFdataBuffer);
        }
        else if(tableType == fdata2_cvTable)
        {
            isFull = fdata2InserterCV.checkIfBufferIsFull(localFdataBuffer.length());
            passReservedId = ((getFdata2_counter_cv() + getFdata2CVStartRange() + 1) >= getFdata2CVReservedId());
            if(isFull || anyFieldsIsLargerThanDefault() || passReservedId)
                flushRecord();

            lffData.setFid(getCurrentFid(lffData.getTableId()));
            localFdataBuffer = lffData.exportFdata2Insert();
            fdata2InserterCV.addStringBuffer(localFdataBuffer);
        }
        else if(tableType == fdata2_gvTable)
        {
            isFull = fdata2InserterGV.checkIfBufferIsFull(localFdataBuffer.length());
            passReservedId = ((getFdata2_counter_gv() + getFdata2GVStartRange() + 1) >= getFdata2GVReservedId());
            if(isFull || anyFieldsIsLargerThanDefault() || passReservedId)
                flushRecord();

            lffData.setFid(getCurrentFid(lffData.getTableId()));
            localFdataBuffer = lffData.exportFdata2Insert();
            fdata2InserterGV.addStringBuffer(localFdataBuffer);
        }
        incrementCounter(tableType);

        return true;
    }




    public void updateFdata(LffData currentLffData)
    {
        StringBuffer valuesToUpdate = currentLffData.addValuesToUpdateFdata();
        boolean isFull = false;

        isFull = extraFieldsUpdater.checkIfBufferIsFull(valuesToUpdate.length());
        if(isFull)
            flushRecord();
        else if(anyFieldsIsLargerThanDefault())
            flushRecord();

        extraFieldsUpdater.addStringBuffer(valuesToUpdate);
        extraFieldsUpdateCounter++;
    }






}

