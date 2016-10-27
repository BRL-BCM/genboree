package org.genboree.upload;

import org.genboree.util.GenboreeUtils;
import org.genboree.util.Util;
import java.sql.*;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.ArrayList;
import java.util.regex.Pattern;
import java.util.regex.Matcher;
import java.io.PrintStream;

public class AttributeInserter implements LffConstants
{
    protected TableBulkInsertManager valuePairDeleter = null;
    protected TableBulkInsertManager attNameInserter = null;
    protected TableBulkInsertManager attValueInserter = null;
    protected TableBulkInsertManager fid2attribute = null;
    protected TableBulkInsertManager ftype2attributeName = null;
    protected Connection sqlConnection;
    protected String databaseName;
    protected String deletevaluePairQuery;
    protected String attNameIdQuery;
    protected String attValueIdQuery;
    protected int maxSizeOfBufferInBytes;
    protected int recordCounter = 0;
    protected int maxRecords = 10000;
    protected int maxNumberOfInserts = 10000;
    protected StringBuffer selectAttNameId;
    protected StringBuffer selectAttValueId;
    protected int attNameCounter = 0;
    protected int attValueCounter = 0;
    protected HashMap attNames2ids = null;
    protected HashMap attValues2ids = null;
    protected HashMap fids2valuePairs = null;
    protected HashMap ftype2attributeNameHash = null;
    protected HashMap fid2FtypeId = null;
    protected int valuePairDeleterCounter = 0;

    protected String regexCaptureValuePairs   = "((?:\\s*[^=;]{1,255}\\s*=\\s*[^;]+\\s*;)+)([^\t]*)";
    protected String regexCaptureFreeComments  = "(?:\\s*[^=;]{1,255}\\s*=\\s*[^;]+\\s*;)+([^\t]*)";
    protected String regexSingleValuePair   = "\\s*[^=;]{1,255}\\s*=\\s*[^;]+\\s*;";
    protected Pattern compiledRegexCaptureValuePairs = null;
    protected Matcher matchRegexCaptureValuePairs  = null;
    protected Pattern compiledRegexCaptureFreeComments = null;
    protected Matcher matchRegexCaptureFreeComments = null;
    protected Pattern compiledRegexSingleValuePair = null;
    protected Matcher matchRegexSingleValuePair = null;
    protected HashMap valuePairs;
    protected boolean containExtraComments = false;
    protected boolean containValuePairs = false;
    protected String rawComments = null;
    protected String commentsLeftOver = null;
    protected String processedComments = null;
    protected String cleanComments = null;
    protected static String[] reservedKeys = {"aHClasses=", "annotationColor=","annotationCode=", "annotationAction=","attributeAction=" };


    public AttributeInserter( Connection myConnection, String refSeqId)
    {
        String databaseName = GenboreeUtils.fetchMainDatabaseName(refSeqId);
        this.databaseName = databaseName;
        this.sqlConnection = myConnection;
        this.maxSizeOfBufferInBytes = LffConstants.defaultMaxSizeOfBufferInBytes;
        initializeVariables();
        initializeTableBulkInsertManagers();
        cleanStringBuffers();
    }


    protected void initializeVariables()
    {
        deletevaluePairQuery = "DELETE IGNORE FROM  fid2attribute where fid in ( ";
        attNameIdQuery = "SELECT name, attNameId FROM attNames WHERE name in (";
        attValueIdQuery = "SELECT value, attValueId FROM attValues WHERE md5 in (";

        attNames2ids = new HashMap();
        attValues2ids = new HashMap();
        fids2valuePairs = new HashMap();
        ftype2attributeNameHash = new HashMap();
        fid2FtypeId = new HashMap();
        compiledRegexCaptureValuePairs = Pattern.compile( regexCaptureValuePairs, 8); // 40 is 8 (Multiline) + 32(DOTALL)
        matchRegexCaptureValuePairs = compiledRegexCaptureValuePairs.matcher("empty");
        compiledRegexCaptureFreeComments = Pattern.compile( regexCaptureFreeComments, 8); // 40 is 8 (Multiline) + 32(DOTALL)
        matchRegexCaptureFreeComments = compiledRegexCaptureFreeComments.matcher("empty");
        compiledRegexSingleValuePair = Pattern.compile( regexSingleValuePair, 8); // 40 is 8 (Multiline) + 32(DOTALL)
        matchRegexSingleValuePair = compiledRegexSingleValuePair.matcher("empty");
    }

    protected void initializeTableBulkInsertManagers()
    {
        valuePairDeleter = new TableBulkInsertManager(sqlConnection);
        valuePairDeleter.setQueryBootStrap(deletevaluePairQuery);
        valuePairDeleter.initializeStringBuffer();
        valuePairDeleter.setUseCounterToLimit(true);
        valuePairDeleter.setMaxNumberOfRecordsBeforeInsert(maxRecords);
        valuePairDeleter.setEndExpression(")");
        valuePairDeleter.setAutoInsert(false);

        attNameInserter = new TableBulkInsertManager(sqlConnection);
        attNameInserter.setQueryBootStrap("INSERT ignore into attNames (name) VALUES");
        attNameInserter.initializeStringBuffer();
        attNameInserter.setUseCounterToLimit(true);
        attNameInserter.setMaxNumberOfRecordsBeforeInsert(maxRecords);
        attNameInserter.setAutoInsert(false);

        attValueInserter = new TableBulkInsertManager(sqlConnection);
        attValueInserter.setQueryBootStrap("INSERT ignore into attValues (value, md5) VALUES");
        attValueInserter.initializeStringBuffer();
        attValueInserter.setUseCounterToLimit(true);
        attValueInserter.setMaxNumberOfRecordsBeforeInsert(maxRecords);
        attValueInserter.setAutoInsert(false);

        fid2attribute = new TableBulkInsertManager(sqlConnection);
        fid2attribute.setQueryBootStrap("insert ignore into fid2attribute (fid, attNameId, attValueId) VALUES ");
        fid2attribute.initializeStringBuffer();
        fid2attribute.setUseCounterToLimit(true);
        fid2attribute.setMaxNumberOfRecordsBeforeInsert(maxRecords);
        fid2attribute.setAutoInsert(false);

        ftype2attributeName = new TableBulkInsertManager(sqlConnection);
        ftype2attributeName.setQueryBootStrap("insert ignore into ftype2attributeName(ftypeid, attNameId) VALUES ");
        ftype2attributeName.initializeStringBuffer();
        ftype2attributeName.setUseCounterToLimit(true);
        ftype2attributeName.setMaxNumberOfRecordsBeforeInsert(maxRecords);
        ftype2attributeName.setAutoInsert(false);



        selectAttNameId = new StringBuffer(150);
        selectAttValueId = new StringBuffer(150);
    }


    protected void initializeBuffers()
    {
        cleanStringBuffers();
    }

    protected boolean anyFieldsIsLargerThanDefault()
    {
        if( valuePairDeleterCounter >= maxRecords )
            return true;
        else
            return false;
    }


    public int removeReservedKeysFromRawComments(String rawComments)
    {
        String newComments = null;
        String[] tokens = null;
        StringBuffer stringBuffer = null;
        boolean foundReservedKeys = false;

        if(rawComments == null) return 4;

        stringBuffer = new StringBuffer( 200 );

        if(rawComments.indexOf(';') > -1)
            tokens = rawComments.split(";");
        else
        {
            tokens = new String[1];
            tokens[0] = rawComments;
        }

        for( int i = 0; i < tokens.length; i++)
        {
            String comment = tokens[i].trim();

            if(comment.startsWith("aHClasses=")) { foundReservedKeys = true;}
            else if(comment.startsWith("annotationColor=")) { foundReservedKeys = true; }
            else if(comment.startsWith("annotationCode=")) { foundReservedKeys = true; }
            else if(comment.startsWith("annotationAction=")){ foundReservedKeys = true; }
            else if(comment.startsWith("attributeAction=")){ foundReservedKeys = true; }
            else
            {
                stringBuffer.append(comment);
                stringBuffer.append("; ");
            }
        }
        if(stringBuffer.length() > 0)
            newComments = stringBuffer.toString();
        else
        {
            newComments = null;
            return 5;
        }

        this.processedComments = newComments;

        return 0;
    }

    public boolean isContainExtraComments()
    {
        return containExtraComments;
    }


    public boolean isContainValuePairs()
    {
        return containValuePairs;
    }


    public String getRawComments()
    {
        return rawComments;
    }


    public String getProcessedComments()
    {
        return processedComments;
    }

    public String getCommentsLeftOver()
    {
        return commentsLeftOver;
    }

    public HashMap getValuePairs()
    {
        return valuePairs;
    }

    public String getCleanComments()
    {
        return cleanComments;
    }

    private ArrayList splitValuePairs(String inputText)
    {
        ArrayList valuePairsArray = null;
        String capturedText = null;

        if(inputText == null) return null;

        valuePairsArray = new ArrayList();
        matchRegexSingleValuePair.reset(inputText);

        int thePos = 0;
        while(matchRegexSingleValuePair.find(thePos))
        {
            capturedText = inputText.substring(matchRegexSingleValuePair.start(),matchRegexSingleValuePair.end());
            valuePairsArray.add(capturedText);
            thePos = matchRegexSingleValuePair.end();
        }


        if(valuePairsArray.isEmpty() || valuePairsArray.size() < 1) return null;

        return valuePairsArray;
    }

    private String[] splitValueAndPair(String valuepairs)
    {
        String[] valueAndPair = null;
        if(valuepairs == null || valuepairs.length() < 1) return null;

        valueAndPair = new String[2];

        int indexOfEqual = valuepairs.indexOf('=');
        int lastIndexOfSemiColon = valuepairs.lastIndexOf(';');
        valueAndPair[0] = valuepairs.substring(0, indexOfEqual);
        valueAndPair[1] = valuepairs.substring(indexOfEqual + 1, lastIndexOfSemiColon);
        return valueAndPair;

    }




    public int transformRawCommentsIntoValuePairs(String myRawComments)
    {
        HashMap results = null;
        rawComments = null;
        processedComments = null;
        containExtraComments = false;
        containValuePairs = false;
        valuePairs = null;


        if(myRawComments != null && myRawComments.length() > 0)
            this.rawComments = myRawComments.trim();
        else
            this.rawComments = null;

        if(rawComments == null || rawComments.length() < 2) return 4;

        matchRegexCaptureValuePairs.reset(rawComments);

//        System.err.println("Initially the rawComments are \n----------->" + rawComments);
//        System.err.flush();

        if(matchRegexCaptureValuePairs.matches())
        {
            cleanComments = matchRegexCaptureValuePairs.replaceAll("$1");
        }
        else
        {
            cleanComments = rawComments;
        }

//        System.err.println("after the first regex the cleanComments are  \n" +
//                "----------->" + cleanComments + "\n and the raw comments are  \n" +
//                "----------->" + rawComments);
        matchRegexCaptureFreeComments.reset(this.rawComments);

        commentsLeftOver = matchRegexCaptureFreeComments.replaceAll("$1");
//        System.err.println("THE COMMENTSLEFTOVER = '" + commentsLeftOver + "' and the length is " + commentsLeftOver.length());
//        System.err.flush();
        commentsLeftOver = commentsLeftOver.trim();
        if(commentsLeftOver != null && commentsLeftOver.length() > 1)
            containExtraComments = true;
        else
        {
            commentsLeftOver = null;
            containExtraComments = false;
        }

//        System.err.println("Now the commentsLeftOver are  \n" +
//                "----------->" + commentsLeftOver + "\n and the rawComments are  \n" +
//                "----------->" + rawComments);

        removeReservedKeysFromRawComments(cleanComments);

//       System.err.println("After the remoreReservedKeys the cleanComments are  \n" +
//                "----------->" + cleanComments + "\n and the processedComments are  \n" +
//                "----------->" + processedComments);

        results = new HashMap();

        ArrayList matches = splitValuePairs(this.processedComments);


        for(int i = 0; i < matches.size(); i++)
        {
            String comment = (String)matches.get(i);
            comment = comment.trim();

//            System.err.println("The value pair are " + comment);
//            System.err.flush();

            String[] vp = splitValueAndPair(comment);

// TODO in here I can remove duplicated value pairs in same line
            if(comment != null && vp.length == 2)
            {
                String key = vp[0];
                ArrayList tempValues;
                if(results.containsKey(key))
                {
                    tempValues = (ArrayList)results.get(key);
                    boolean valueAlreadyThere = tempValues.contains(vp[1]);
                    if(!valueAlreadyThere)
                        tempValues.add(vp[1]);
                }
                else
                {
                    tempValues = new ArrayList(10);
                    tempValues.add(vp[1]);
                }
                results.put(key, tempValues);
            }
        }



        if(results.isEmpty() )
        {
            this.valuePairs = null;
        }
        else
        {
            this.valuePairs = results;
            containValuePairs = true;
        }
        cleanComments = null;
  /*
        System.err.println("Before the Iterator loop");
         Iterator  valuePairsIterator = valuePairs.entrySet().iterator() ;
         while(valuePairsIterator.hasNext())
         {
             Map.Entry valuePairsMap = (Map.Entry)valuePairsIterator.next() ;
             String name = (String)valuePairsMap.getKey();
             ArrayList value = (ArrayList)valuePairsMap.getValue();

                  for(int i = 0; i < value.size(); i++)
                  {
                 System.err.println(name + " = " + value.get(i));
                  }

         }
        System.err.println("After the Iterator loop");
        System.err.flush();
*/

        if(!containExtraComments && containValuePairs )
            return 0;
        else if(containValuePairs && containExtraComments)
            return 6;
        else
            return 10;
    }





    public void printAttValuesBuffers()
    {
        System.err.println(attNameInserter.getTableBuffer().toString());
        System.err.println(attValueInserter.getTableBuffer().toString());
        System.err.println(fid2attribute.getTableBuffer().toString());
        System.err.println(ftype2attributeName.getTableBuffer().toString());
    }


    public void addValuePairs(ArrayList fids, int ftypeId, HashMap valuesToAdd, int action)
    {
        long fid = -1;
        String tempFid = null;

        for(int i = 0; i < fids.size(); i++)
        {
            tempFid = (String)fids.get(i);
            fid = Util.parseLong(tempFid, -1);
            if(fid > 0)
            {
                if(action == DELETEATTRIBUTE)
                {
                    addValuePairIdsToDelete(fid);
                }
                else
                {
                    if(action != APPENDATTRIBUTE)
                        addValuePairIdsToDelete(fid);

                    if(action != DELETEATTRIBUTE)
                        insertValuePairRecord(fid, ftypeId, valuesToAdd);
                }
            }
        }
    }







    public void deleteValuePairs(ArrayList fids)
    {
        long fid = -1;
        String tempFid = null;

        for(int i = 0; i < fids.size(); i++)
        {
            tempFid = (String)fids.get(i);
            fid = Util.parseLong(tempFid, -1);
            addValuePairIdsToDelete(fid);
        }
    }

    public void addValuePairs(HashMap multiFids)
    {
        long fid = -1;
        String tempFid = null;
        int  ftypeId = -1;
        String tempFtypeId = null;
        HashMap valuePairs = null;
        int action = -1;
        String tempAction = null;

        if(multiFids == null || multiFids.size() < 1) return;

        Iterator  fids2valuePairsIterator = multiFids.entrySet().iterator() ;
        while(fids2valuePairsIterator.hasNext())
        {
            Map.Entry fids2valuePairsMap = (Map.Entry)fids2valuePairsIterator.next() ;
            tempFid = (String)fids2valuePairsMap.getKey();
            HashMap tempHash = (HashMap)fids2valuePairsMap.getValue();


            if(tempHash == null || tempHash.size() < 1) continue;

            if(tempFid == null) continue;
            fid = Util.parseLong(tempFid, -1);
            if(fid < 1) continue;
            tempFtypeId = (String)tempHash.get("ftypeId");
            if(tempFtypeId == null) continue;
            ftypeId = Util.parseInt(tempFtypeId, -1);
            if(ftypeId < 1) continue;
            valuePairs = (HashMap)tempHash.get("valuePairs");
            if(valuePairs == null || valuePairs.size() < 1)continue;
            tempAction = (String)tempHash.get("action");
            if(tempAction == null)
                action = 0;
            else
                action = Util.parseInt(tempAction, -1);

            if(action < 0 || action > 2) action = 0;

            addValuePairs(fid, ftypeId, valuePairs, action);
        }

    }



    public void addValuePairs(long fid, int ftypeId, HashMap valuesToAdd, int action)
    {
        if(action == DELETEATTRIBUTE)
        {
            addValuePairIdsToDelete(fid);
        }
        else
        {
            if(action != APPENDATTRIBUTE)
            {
                addValuePairIdsToDelete(fid);
            }

            if(action != DELETEATTRIBUTE)
            {
                insertValuePairRecord(fid, ftypeId, valuesToAdd);
            }
        }

    }


    public void insertValuePairRecord(long currentId, int ftypeId, HashMap valuesToAdd)
    {

        if(valuesToAdd == null || valuesToAdd.size() == 0) return;
        if(currentId < 1 || ftypeId < 1) return;


        if(!fid2FtypeId.containsKey(""+ currentId))
        {
            fid2FtypeId.put("" + currentId, "" + ftypeId);
        }

        if(!fids2valuePairs.containsKey(""+ currentId))
        {
            if(valuesToAdd == null || valuesToAdd.size() < 1)
            {
                fids2valuePairs.put("" + currentId, "" + null);
//                System.err.println("adding null hash to = " + currentId );
//                System.err.flush();
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

        valuePairDeleter.flushRecord();
        valuePairDeleter.setRecordCounter(0);
        attNameInserter.flushRecord();
        attNameInserter.setRecordCounter(0);
        attValueInserter.flushRecord();
        attValueInserter.setRecordCounter(0);

        if(selectAttNameId.length() < 1 || selectAttValueId.length() < 1)
        {
//            System.err.println("The selectAttNameId length is " + selectAttNameId.length() + " and the selectAttValueId length = " + selectAttValueId.length());
//            System.err.flush();
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
            attNameResultSet = attNameStatement.executeQuery(selectAttNameId.toString());
            attValuesResultSet = attValuesStatement.executeQuery(selectAttValueId.toString());
            /*
            System.err.println("the selectAttNameId is " + selectAttNameId.toString());
            System.err.println("the selectAttValueId is " + selectAttValueId.toString());
            System.err.flush();
              */

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
            }
            attValuesResultSet.close();

        } catch (SQLException e3) {
            e3.printStackTrace(System.err);
        }

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

//        System.err.println("the fid2attribute query is " + fid2attribute.toString());
//        System.err.println("the ftype2attributeName query is " + this.ftype2attributeName.toString());
//        System.err.flush();

        fid2attribute.flushRecord();
        fid2attribute.setRecordCounter(0);
        ftype2attributeName.flushRecord();
        ftype2attributeName.setRecordCounter(0);
        selectAttNameId.setLength( 0 );
        fid2FtypeId.clear();
        fids2valuePairs.clear();
        attNames2ids.clear();
        attValues2ids.clear();
    }


    public void terminateAttribute()
    {

        processRecords();
        attNameInserter.flushRecord();
        attValueInserter.flushRecord();
        fid2attribute.flushRecord();
        ftype2attributeName.flushRecord();
    }

    public int getMaxNumberOfInserts()
    {
        return maxNumberOfInserts;
    }
    public void setMaxNumberOfInserts(int maxNumberOfInserts)
    {
        this.maxNumberOfInserts = maxNumberOfInserts;
    }


    public void submitStrinBuffer(PrintStream fullLogFile )
    {
        valuePairDeleter.submitStringBuffer(fullLogFile );
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

    protected boolean insertData = true;

    public boolean isInsertData()
    {
        return insertData;
    }
    public void setInsertData(boolean insertData)
    {
        this.insertData = insertData;
    }



    public void finalFlushRecord()
    {
        if(isPrintQueries())
        {
            printStrinBuffer();
        }
        if(isInsertData())
        {
            submitStrinBuffer(false); //TODO  reactivate sleep time
        }

        cleanStringBuffers();
    }



    protected void flushRecord()
    {
        if(isPrintQueries())
        {
            printStrinBuffer();
        }
        if(isInsertData())
        {
            submitStrinBuffer(false);
        }

        cleanStringBuffers();
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
        valuePairDeleter.printStringBuffer();
    }

    public void cleanStringBuffers()
    {
        valuePairDeleter.cleanStringBuffers();
        valuePairDeleterCounter = 0;

    }

    protected void submitStrinBuffer(boolean goToSleep)
    {
        processRecords( );
    }


    protected void addValuePairIdsToDelete(long fid)
    {
        valuePairDeleter.addId("" + fid);
        valuePairDeleterCounter++;
        return;
    }


}

