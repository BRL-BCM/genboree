package org.genboree.upload;

import org.genboree.util.GenboreeUtils;
import org.genboree.util.Util;

import java.io.PrintWriter;
import java.io.PrintStream;
import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

public class TableBulkInsertManager
{

    private int bufferDelta = 10;

    private int defaultMaxSizeOfBufferInBytes = 16 * 1024 * 1024;
    private Connection databaseConnection;
    private boolean tableBufferFull = false;
    private int tableBufferDelta = 0;
    private int tableBufferLength;
    private StringBuffer tableBuffer;
    private int initialBufferSize = 4 * 1024 * 1024 ;
    private boolean tableNewLine= false;
    private String queryAction = "INSERT ";
    private String mysqlInsertAttributes = " IGNORE ";
    private String beforetable = " INTO ";
    private String tableName = null;
    private String[] arrayDataFields = null;
    private String dataFields = null;
    private String beforeValues = " VALUES ";
    private String[] updateFields =  null;
    private String endExpression = null;
    private String queryBootStrap = null;
    private long reservedId;
    private long currentId;
    private boolean needCheckReservedId = false;
    private boolean printQueries = false;
    private boolean insertData = true;
    private int maxSizeOfBufferInBytes;
    private int sleepTime = LffConstants.uploaderSleepTime;
    private PrintWriter printerOutStream;
    private int maxNumberOfRecordsBeforeInsert = 100000;
    private int recordCounter = 0;
    private boolean useCounterToLimit = false;
    private boolean autoInsert = true;
    private int numberOfInserts = -1;


    public TableBulkInsertManager( Connection myConnection)
    {
        setDatabaseConnection(myConnection);
        setTableName(null);
        setArrayDataFields(null);
        setUpdateFields(null);
        setQueryBootStrap(null);
        setNeedCheckReservedId(false);
        setPrintQueries(false);
        setInsertData(true);
        setMaxSizeOfBufferInBytes(defaultMaxSizeOfBufferInBytes);
        setPrinterOutStream(new PrintWriter(System.err));
    }

    public void setQueryBootStrap(String queryBootStrap)
    {
        if(queryBootStrap == null || queryBootStrap.length() < 1)
        {
            this.queryBootStrap = queryAction + mysqlInsertAttributes + beforetable + " " + tableName + " " + dataFields + beforeValues ;
        }
        else
            this.queryBootStrap = queryBootStrap;
    }
    public void initializeStringBuffer()
    {
        tableBuffer = new StringBuffer( initialBufferSize );
        tableBuffer.append(queryBootStrap);
        tableBufferLength = tableBuffer.length();
        setTableBufferDelta(0);
        setTableBufferFull(false);
        setTableNewLine(true);
    }
    protected void cleanStringBuffers()
    {
        tableBuffer.setLength(0) ;
        tableBuffer.ensureCapacity(initialBufferSize);
        tableBuffer.append(queryBootStrap);
        tableBufferLength = tableBuffer.length();
        setTableBufferDelta(0);
        setTableBufferFull(false);
        setTableNewLine(true);
    }
    public void setArrayDataFields(String[] arrayDataFields)
    {
        this.arrayDataFields = arrayDataFields;
        setDataFields();
    }
    public void setUpdateFields(String[] updateFields)
    {
        this.updateFields = updateFields;
        setEndExpression();
    }
    public void setSleepTime(int sleepTime)
    {
        this.sleepTime = sleepTime;
    }

    public int getNumberOfInserts() {
        return numberOfInserts;
    }

    public boolean isAutoInsert()
    {
        return autoInsert;
    }

    public void setAutoInsert(boolean autoInsert)
    {
        this.autoInsert = autoInsert;
    }

    public boolean isUseCounterToLimit()
    {
        return useCounterToLimit;
    }

    public void setUseCounterToLimit(boolean useCounterToLimit) {
        this.useCounterToLimit = useCounterToLimit;
    }

    public int getMaxNumberOfRecordsBeforeInsert()
    {
        return maxNumberOfRecordsBeforeInsert;
    }

    public void setMaxNumberOfRecordsBeforeInsert(int maxNumberOfRecordsBeforeInsert)
    {
        this.maxNumberOfRecordsBeforeInsert = maxNumberOfRecordsBeforeInsert;
    }

    public int getRecordCounter()
    {
        return recordCounter;
    }

    public void setRecordCounter(int recordCounter)
    {
        this.recordCounter = recordCounter;
    }

    public void setPrinterOutStream(PrintWriter printerOutStream)
    {
        this.printerOutStream = printerOutStream;
    }
    private void setMaxSizeOfBufferInBytes(int maxSizeOfBuffer)
    {
        this.maxSizeOfBufferInBytes = maxSizeOfBuffer;
    }
    public void setPrintQueries(boolean printQueries)
    {
        this.printQueries = printQueries;
    }
    private void setInsertData(boolean insertData)
    {
        this.insertData = insertData;
    }
    private void setReservedId(long reservedId)
    {
        this.reservedId = reservedId;
    }
    private void setCurrentId(long currentId)
    {
        this.currentId = currentId;
    }
    public void setNeedCheckReservedId(boolean needCheckReservedId)
    {
        this.needCheckReservedId = needCheckReservedId;
    }
    private void setTableNewLine(boolean tableNewLine)
    {
        this.tableNewLine = tableNewLine;
    }
    private void setTableBufferFull(boolean tableBufferFull)
    {
        this.tableBufferFull = tableBufferFull;
    }
    public StringBuffer getTableBuffer()
    {
        return tableBuffer;
    }
    public String getQuery()
    {
        if(tableBuffer != null && tableBuffer.length() > 0)
            return tableBuffer.toString();
        else
            return "tableBuffer is empty";
    }
    private void setTableBufferDelta(int tableBufferDelta)
    {
        this.tableBufferDelta = tableBufferDelta;
    }
    public void setQueryAction(String queryAction)
    {
        this.queryAction = queryAction;
    }
    public void setMysqlInsertAttributes(String mysqlInsertAttributes)
    {
        this.mysqlInsertAttributes = mysqlInsertAttributes;
    }
    public void setBeforetable(String beforetable)
    {
        this.beforetable = beforetable;
    }
    public void setBeforeValues(String beforeValues)
    {
        this.beforeValues = beforeValues;
    }
    public void setTableName(String tableName)
    {
        this.tableName = tableName;
    }
    private void setDataFields()
    {
        StringBuffer tempDataField = null;

        if(arrayDataFields != null && arrayDataFields.length > 0)
        {
            tempDataField = new StringBuffer(200);
            tempDataField.append("(");
            for(int i = 0; i < arrayDataFields.length; i++)
            {
               tempDataField.append(arrayDataFields[i]);
                if(i < (arrayDataFields.length -1))
                       tempDataField.append(",");
                else
                    tempDataField.append(") ");
            }
            this.dataFields = tempDataField.toString();
        }
        else
            this.dataFields = "";
    }
    private void setDatabaseConnection(Connection databaseConnection)
    {
        this.databaseConnection = databaseConnection;
    }
    private void setEndExpression()
    {
        StringBuffer tempExpression = null;

        if(updateFields != null && updateFields.length > 0)
        {
            tempExpression = new StringBuffer(200);
            tempExpression.append(" ON DUPLICATE KEY UPDATE ");
            for(int i = 0; i < updateFields.length; i++)
            {
               tempExpression.append(" ").append(updateFields[i]).append("=VALUES(").append(updateFields[i]);
                if(i < (updateFields.length -1))
                       tempExpression.append("),");
                else
                    tempExpression.append(")");
            }
            this.endExpression = tempExpression.toString();
        }
        else
            this.endExpression = "";

    }

    public void setEndExpression(String theEndExp)
    {
        this.endExpression = theEndExp;
    }

    public void submitStringBuffer( )
    {
        submitStringBuffer(System.err );
    }

    //TODO temp Change from private to public
    public void submitStringBuffer(PrintStream fullLogFile )
    {
        Statement stmt = null;
        boolean rc = false;
        numberOfInserts = -1;

        try {
            stmt = databaseConnection.createStatement();
        } catch (SQLException e) {
            e.printStackTrace(System.err);
        }

        if(!tableNewLine)
        {
            tableBuffer.append(endExpression);
            try {
                numberOfInserts = stmt.executeUpdate(tableBuffer.toString());
                if(numberOfInserts > 0){
                fullLogFile.println("the number of inserts is " + numberOfInserts);
                fullLogFile.flush();
		}
                rc = (numberOfInserts > 0);
                stmt.close() ;
            } catch (SQLException e) {
                System.err.println("The query with the exception is " + tableBuffer.toString());
                e.printStackTrace(System.err);
                System.err.flush();
            }
        }


    }
    protected void printStringBuffer()
    {
        if(!tableNewLine)
        {
            printerOutStream.print(tableBuffer.toString() + " ");
            printerOutStream.println(endExpression);
            printerOutStream.println(";");
            printerOutStream.flush();
        }
    }
    private boolean checkIfCurrentIdIsInRange()
    {

        if(!needCheckReservedId) return true;

        if(currentId >=  reservedId)
            return false;
        else
            return true;
    }


    public boolean checkIfBufferIsFull(int textBufferLength)
    {
        boolean bufferFull = false;

        bufferFull = ((textBufferLength + bufferDelta + tableBufferDelta) >= maxSizeOfBufferInBytes  );

        return bufferFull;
    }

    public boolean setFlagIfBufferFull()
    {
        boolean bufferFull = false;
        int textBufferLength = 0;
        int textBufferDelta = 0;
        boolean reachedEndOfRange = false;

        textBufferLength = tableBuffer.length();
        textBufferDelta = tableBufferDelta;
        reachedEndOfRange = !checkIfCurrentIdIsInRange();

        if(!reachedEndOfRange)
        {
            reachedEndOfRange = ((textBufferLength + bufferDelta + textBufferDelta) >= maxSizeOfBufferInBytes  );
        }
        if(reachedEndOfRange)
            bufferFull = true;
        else
            bufferFull = false;


        setTableBufferFull(bufferFull);


        return bufferFull;

    }

    public boolean flushRecord()
    {
      return flushRecord(System.err);
    }

    public boolean flushRecord(PrintStream fullLogFile)
    {
        if(printQueries)
        {
            printStringBuffer();
        }
        if(insertData)
        {
            submitStringBuffer(fullLogFile);
        }

        cleanStringBuffers();

        if(!checkIfCurrentIdIsInRange())
        {
            return true;
        }
        else
        {
            return false;
        }
    }
    private void flushRecordIfFull()
    {
        boolean myTableBufferIsFull = false;

        myTableBufferIsFull = setFlagIfBufferFull();
        if( myTableBufferIsFull )
        {
            flushRecord();
            System.gc();
        }
    }

    public void addStringBuffer(StringBuffer valuesToAdd)
    {
        if(tableNewLine)
            setTableNewLine(false);
        else
            tableBuffer.append(", ");

        tableBuffer.append(valuesToAdd);
    }




    public void addValuesToUpdateFdata(String[] valuesToAdd, long currentId, long maxRange)
    {
        StringBuffer localFdataBuffer = null;
        setCurrentId(currentId);
        setReservedId(maxRange);

        if(valuesToAdd != null && valuesToAdd.length > 0)
        {
            localFdataBuffer = new StringBuffer(200);
            localFdataBuffer.append(" ( ");
            for(int i = 0; i < valuesToAdd.length; i++)
            {
                if(valuesToAdd[i] == null || valuesToAdd[i].equalsIgnoreCase("null"))
                    localFdataBuffer.append("NULL");
                else
                    localFdataBuffer.append("'").append(GenboreeUtils.mysqlEscapeSpecialChars(valuesToAdd[i])).append("'");

                if(i < (valuesToAdd.length -1))
                    localFdataBuffer.append(", ");
                else
                    localFdataBuffer.append(")");
            }

            setTableBufferDelta(localFdataBuffer.length());

            setRecordCounter(getRecordCounter() + 1);

            if(isUseCounterToLimit() && getRecordCounter() > getMaxNumberOfRecordsBeforeInsert())
            {
                  flushRecord();
                  System.gc();
                  setRecordCounter(0);
            }
            else
            {
                flushRecordIfFull();
            }

            if(tableNewLine)
                setTableNewLine(false);
            else
                tableBuffer.append(", ");

            tableBuffer.append(localFdataBuffer);
        }
    }

    public void addValuesPairs(long currentId, int ftypeId, HashMap valuesToAdd)
    {
        StringBuffer localFdataBuffer = null;
        int counter = 0;


        if(valuesToAdd != null && valuesToAdd.size() > 0)
        {
            localFdataBuffer = new StringBuffer(200);

            Iterator  valuePairIterator = valuesToAdd.entrySet().iterator() ;
            counter = 0;
            while(valuePairIterator.hasNext())
            {
                Map.Entry valuePairMap = (Map.Entry) valuePairIterator.next() ;
                String key = (String)valuePairMap.getKey();
                String value = (String)valuePairMap.getValue();

                if(key == null || key.length() < 1 || key.equalsIgnoreCase("null"))
                    continue;

                if(value == null || value.equalsIgnoreCase("null"))
                    value = "";

                localFdataBuffer.append(" ( ").append("" + currentId).append(", " + ftypeId + ", ");
                localFdataBuffer.append("'").append(GenboreeUtils.mysqlEscapeSpecialChars(key)).append("', ");
                localFdataBuffer.append("'").append(GenboreeUtils.mysqlEscapeSpecialChars(value)).append("')");

                if(counter < (valuesToAdd.size() -1))
                    localFdataBuffer.append(", ");
                counter++;
            }

            setTableBufferDelta(localFdataBuffer.length());

            setRecordCounter(getRecordCounter() + 1);

            if(autoInsert)
            {
                if(isUseCounterToLimit() && getRecordCounter() > getMaxNumberOfRecordsBeforeInsert())
                {
                    flushRecord();
                    System.gc();
                    setRecordCounter(0);
                }
                else
                    flushRecordIfFull();
            }

            if(tableNewLine)
                setTableNewLine(false);
            else
                tableBuffer.append(", ");

            tableBuffer.append(localFdataBuffer);
        }
    }

    public void addSingleValueWithMd5(String valueToAdd)
    {
        StringBuffer localFdataBuffer = null;

        if(valueToAdd == null || valueToAdd.length() < 0) return;

        localFdataBuffer = new StringBuffer(200);

        localFdataBuffer.append(" ( ");
        localFdataBuffer.append("'").append(GenboreeUtils.mysqlEscapeSpecialChars(valueToAdd)).append("', ");
        localFdataBuffer.append("MD5('");
        localFdataBuffer.append(GenboreeUtils.mysqlEscapeSpecialChars(valueToAdd));
        localFdataBuffer.append("'))");

        setTableBufferDelta(localFdataBuffer.length());

        setRecordCounter(getRecordCounter() + 1);

        if(autoInsert)
        {
            if(isUseCounterToLimit() && getRecordCounter() > getMaxNumberOfRecordsBeforeInsert())
            {
                flushRecord();
                System.gc();
                setRecordCounter(0);
            }
            else
                flushRecordIfFull();
        }

        if(tableNewLine)
            setTableNewLine(false);
        else
            tableBuffer.append(", ");

        tableBuffer.append(localFdataBuffer);
    }



    public void addSingleValue(String valueToAdd)
    {
        StringBuffer localFdataBuffer = null;

        if(valueToAdd == null || valueToAdd.length() < 0) return;

        localFdataBuffer = new StringBuffer(200);

        localFdataBuffer.append(" ( ");
        localFdataBuffer.append("'").append(GenboreeUtils.mysqlEscapeSpecialChars(valueToAdd)).append("')");

        setTableBufferDelta(localFdataBuffer.length());

        setRecordCounter(getRecordCounter() + 1);

        if(autoInsert)
        {
            if(isUseCounterToLimit() && getRecordCounter() > getMaxNumberOfRecordsBeforeInsert())
            {
                flushRecord();
                System.gc();
                setRecordCounter(0);
            }
            else
                flushRecordIfFull();
        }

        if(tableNewLine)
            setTableNewLine(false);
        else
            tableBuffer.append(", ");

        tableBuffer.append(localFdataBuffer);
    }

    public void addValues(String[] valuesToAdd)
    {
        StringBuffer localFdataBuffer = null;

        if(valuesToAdd != null && valuesToAdd.length > 0)
        {
            localFdataBuffer = new StringBuffer(200);
            localFdataBuffer.append(" ( ");
            for(int i = 0; i < valuesToAdd.length; i++)
            {
                if(valuesToAdd[i] == null || valuesToAdd[i].equalsIgnoreCase("null"))
                    localFdataBuffer.append("NULL");
                else
                    localFdataBuffer.append("'").append(GenboreeUtils.mysqlEscapeSpecialChars(valuesToAdd[i])).append("'");

                if(i < (valuesToAdd.length -1))
                    localFdataBuffer.append(", ");
                else
                    localFdataBuffer.append(")");
            }

            setTableBufferDelta(localFdataBuffer.length());

            setRecordCounter(getRecordCounter() + 1);

            if(autoInsert)
            {
                if(isUseCounterToLimit() && getRecordCounter() > getMaxNumberOfRecordsBeforeInsert())
                {
                    flushRecord();
                    System.gc();
                    setRecordCounter(0);
                }
                else
                    flushRecordIfFull();
            }
            if(tableNewLine)
                setTableNewLine(false);
            else
                tableBuffer.append(", ");

            tableBuffer.append(localFdataBuffer);
        }
    }

    public void addfourInts(String fid, String ftypeId, String attNameId, String attValueId)
    {

        StringBuffer localFdataBuffer = null;

        if(fid == null || fid.length() < 1) return;
        if(ftypeId == null || ftypeId.length() < 1) return;
        if(attNameId == null || attNameId.length() < 1) return;
        if(attValueId == null || attValueId.length() < 1) return;


        localFdataBuffer = new StringBuffer(200);
        localFdataBuffer.append(" ( ");
        localFdataBuffer.append(fid);
        localFdataBuffer.append(", ");
        localFdataBuffer.append(ftypeId);
        localFdataBuffer.append(", ");
        localFdataBuffer.append(attNameId);
        localFdataBuffer.append(", ");
        localFdataBuffer.append(attValueId);
        localFdataBuffer.append(")");

//System.err.println("the localBuffer is " + localFdataBuffer.toString());
//        System.err.flush();

        setTableBufferDelta(localFdataBuffer.length());

        setRecordCounter(getRecordCounter() + 1);

        if(autoInsert)
        {

            if(isUseCounterToLimit() && getRecordCounter() > getMaxNumberOfRecordsBeforeInsert())
            {
                flushRecord();
                System.gc();
                setRecordCounter(0);
            }
            else
                flushRecordIfFull();
        }

        if(tableNewLine)
            setTableNewLine(false);
        else
            tableBuffer.append(", ");

        tableBuffer.append(localFdataBuffer);
    }


    public void addThreeInts(String fid, String attNameId, String attValueId)
    {

        StringBuffer localFdataBuffer = null;

        if(fid == null || fid.length() < 1) return;
        if(attNameId == null || attNameId.length() < 1) return;
        if(attValueId == null || attValueId.length() < 1) return;


        localFdataBuffer = new StringBuffer(200);
        localFdataBuffer.append(" ( ");
        localFdataBuffer.append(fid);
        localFdataBuffer.append(", ");
        localFdataBuffer.append(attNameId);
        localFdataBuffer.append(", ");
        localFdataBuffer.append(attValueId);
        localFdataBuffer.append(")");

//System.err.println("the localBuffer is " + localFdataBuffer.toString());
//        System.err.flush();

        setTableBufferDelta(localFdataBuffer.length());

        setRecordCounter(getRecordCounter() + 1);

        if(autoInsert)
        {

            if(isUseCounterToLimit() && getRecordCounter() > getMaxNumberOfRecordsBeforeInsert())
            {
                flushRecord();
                System.gc();
                setRecordCounter(0);
            }
            else
                flushRecordIfFull();
        }

        if(tableNewLine)
            setTableNewLine(false);
        else
            tableBuffer.append(", ");

        tableBuffer.append(localFdataBuffer);
    }

    public void addTwoInts(String ftypeId, String attNameId)
    {

        StringBuffer localFdataBuffer = null;

        if(ftypeId == null || ftypeId.length() < 1) return;
        if(attNameId == null || attNameId.length() < 1) return;


        localFdataBuffer = new StringBuffer(200);
        localFdataBuffer.append(" ( ");
        localFdataBuffer.append(ftypeId);
        localFdataBuffer.append(", ");
        localFdataBuffer.append(attNameId);
        localFdataBuffer.append(")");

//System.err.println("the localBuffer is " + localFdataBuffer.toString());
//        System.err.flush();

        setTableBufferDelta(localFdataBuffer.length());

        setRecordCounter(getRecordCounter() + 1);

        if(autoInsert)
        {

            if(isUseCounterToLimit() && getRecordCounter() > getMaxNumberOfRecordsBeforeInsert())
            {
                flushRecord();
                System.gc();
                setRecordCounter(0);
            }
            else
                flushRecordIfFull();
        }

        if(tableNewLine)
            setTableNewLine(false);
        else
            tableBuffer.append(", ");

        tableBuffer.append(localFdataBuffer);
    }


    public void addId(String id)
    {
        setRecordCounter(getRecordCounter() + 1);
        if(tableNewLine)
            setTableNewLine(false);
        else
            tableBuffer.append(", ");

        tableBuffer.append(id);


    }





}
