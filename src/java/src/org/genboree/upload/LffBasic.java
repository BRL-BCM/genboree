package org.genboree.upload;

import org.genboree.util.GenboreeUtils;


import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.ArrayList;
import java.util.regex.Pattern;
import java.util.regex.Matcher;


public class LffBasic implements RefSeqParams,LffConstants {

    protected boolean commentsEmpty = false;
    protected boolean sequencesEmpty = false;
    protected boolean freeStyleCommentsEmpty = false;
    protected boolean parseError = false;
    protected boolean annotationsSuccessfullyParsed = false;
    protected boolean conflictInComments = false;
    private int rid;
    private int ftypeId;
    private int annotationAction = INSERTANNOTATION;
    private int attributeAction = UPDATEATTRIBUTE;
    protected boolean useVP = false;

    protected int tableId;
    protected int lineNumber;
    protected int displayColor = -1;
    protected int displayCode = -1;

    protected long start;
    protected long fid = -1;
    protected long stop;
    protected long targetStart;
    protected long targetStop;

    protected double score;

    protected String indexMd5Key;
    protected String lineMd5Value;
    private String databaseName;

    protected String strand;
    protected String phase;
    protected String scoreStr;
    protected String className;
    protected String groupName;
    protected String sequences;
    protected String freeStyleComments;
    protected String entryPoint;
    protected String sFbin;
    protected String type;
    protected String subType;
    protected String errorInLff;
    protected String cleanComments;
    protected String ftypeIdString;
    protected String fidString;
    protected String commentsLeftOvers;
    protected String initialComments;
    protected String newCommentField;
    protected String comments;
    protected String[] metaData = metaAnnotations;
    protected String[] lffLine;
    protected String[] extraClasses;

    protected HashMap valuePairs;

//    String exampleText = "this is a test";
//    protected String regex1   = "(?:\\s*[^=;]{1,255}\\s*=\\s*[^;]+\\s*;)+";
    protected String regex2   = "((?:\\s*[^=;]{1,255}\\s*=\\s*[^;]*\\s*;)+)([^\t]*)";
    protected String regex3   = "\\s*[^=;]{1,255}\\s*=\\s*[^;]*\\s*;";
    protected String regex4   = "(?:\\s*[^=;]{1,255}\\s*=\\s*[^;]*\\s*;)+([^\t]*)";

 //           "^\\s*inflating:\\s*(.*)\\s*$";
    protected Pattern compiledRegex3 = Pattern.compile( regex3, 8); // 40 is 8 (Multiline) + 32(DOTALL)
    protected Matcher matchRegex3 = compiledRegex3.matcher("empty");
    protected Pattern compiledRegex2 = Pattern.compile( regex2, 8); // 40 is 8 (Multiline) + 32(DOTALL)
    protected Matcher matchRegex2 = compiledRegex2.matcher("empty");
    protected Pattern compiledRegex4 = Pattern.compile( regex4, 8); // 40 is 8 (Multiline) + 32(DOTALL)
    protected Matcher matchRegex4 = compiledRegex4.matcher("empty");
//    protected Matcher matchRegex1 = compiledRegex1.matcher(exampleText);




    protected LffBasic()
    {

    }

    protected String getScoreStr()
    {
        return scoreStr;
    }

    protected void setScoreStr(String scoreStr)
    {
        this.scoreStr = scoreStr;
    }

    protected String getEntryPoint()
    {
        return entryPoint;
    }

    protected int getLineNumber()
    {
        return lineNumber;
    }

    protected String getsFbin()
    {
        return sFbin;
    }

    public boolean isUseVP() {
        return useVP;
    }

    public void setUseVP(boolean useVP) {
        this.useVP = useVP;
    }

    protected boolean isParseError()
    {
        return parseError;
    }

    public int getAnnotationAction()
    {
        return annotationAction;
    }


    public void setAnnotationAction(int annotationAction)
    {
        this.annotationAction = annotationAction;
    }

    public int getAttributeAction()
    {
        return attributeAction;
    }

    public void setAttributeAction(int attributeAction)
    {
        this.attributeAction = attributeAction;
    }

    protected void setParseError(boolean parseError)
    {
        this.parseError = parseError;
    }

    protected boolean isAnnotationsSuccessfullyParsed()
    {
        return annotationsSuccessfullyParsed;
    }

    protected void setAnnotationsSuccessfullyParsed(boolean annotationsSuccessfullyParsed)
    {
        this.annotationsSuccessfullyParsed = annotationsSuccessfullyParsed;
    }

    public String getNewCommentField()
    {
        return newCommentField;
    }

    protected void setNewCommentField(String newCommentField)
    {
        this.newCommentField = newCommentField;
    }


    protected void setsFbin(String sFbin)
    {
        this.sFbin = sFbin;
    }

    protected void setLineNumber(int lineNumber)
    {
        this.lineNumber = lineNumber;
    }

    protected void setEntryPoint(String entryPoint)
    {
        this.entryPoint = entryPoint;
    }

    protected String getFtypeIdString()
    {
        return ftypeIdString;
    }

    protected String getFidString()
    {
        return fidString;
    }

    protected void setFidString(String fidString)
    {
        this.fidString = fidString;
    }

    protected void setFtypeIdString(String ftypeIdString)
    {
        this.ftypeIdString = ftypeIdString;
    }

    protected String getDatabaseName()
    {
        return databaseName;
    }

    public String getComments() {
        return comments;
    }

    public void setComments(String comments) {
        this.comments = comments;
    }

    protected void setDatabaseName(String databaseName)
    {
        this.databaseName = databaseName;
    }

    protected String[] getExtraClasses()
    {
        return extraClasses;
    }

    protected String getCleanComments()
    {
        return cleanComments;
    }

    protected String getInitialComments()
    {
        return initialComments;
    }

    protected HashMap getValuePairs()
    {
        return valuePairs;
    }

    protected String getCommentsLeftOvers()
    {
        return commentsLeftOvers;
    }


    protected String getSubType()
    {
        return subType;
    }

    public boolean isFreeStyleCommentsEmpty()
    {
        return freeStyleCommentsEmpty;
    }

    public void setFreeStyleCommentsEmpty(boolean freeStyleCommentsEmpty)
    {
        this.freeStyleCommentsEmpty = freeStyleCommentsEmpty;
    }

    public String getFreeStyleComments()
    {
        return freeStyleComments;
    }

    public void setFreeStyleComments(String freeStyleComments)
    {
        this.freeStyleComments = freeStyleComments;
    }

    protected int getDisplayColor()
    {
        return displayColor;
    }

    protected void setDisplayColor(int displayColor)
    {
        this.displayColor = displayColor;
    }

    protected int getDisplayCode()
    {
        return displayCode;
    }

    protected void setDisplayCode(int displayCode)
    {
        this.displayCode = displayCode;
    }

    protected void setIndexMd5Key()
    {
        String mykey = null;

        mykey = new StringBuffer().append(sFbin).append("-").append(rid).append("-").append(start).append("-").append(stop).append("-").append(ftypeId).append("-").append(groupName).append("-").append(score).append("-").append(strand).append("-").append(phase).toString();

        indexMd5Key = GenboreeUtils.generateUniqueKey(mykey);

    }

    public String getIndexMd5Key()
    {
        return indexMd5Key;
    }

    public String getLineMd5Value()
    {
        return lineMd5Value;
    }

    protected void setSubType(String subType)
    {
        this.subType = subType;
    }

    protected String getType()
    {
        return type;
    }

    protected void setType(String type)
    {
        this.type = type;
    }

    protected long getFid()
    {
        return fid;
    }

    protected void setFid(long fid)
    {
        this.fid = fid;
        this.fidString = "" + fid;
    }

    protected boolean isCommentsEmpty()
    {
        return commentsEmpty;
    }

    protected void setCommentsEmpty(boolean commentsEmpty)
    {
        this.commentsEmpty = commentsEmpty;
    }

    protected boolean isSequencesEmpty()
    {
        return sequencesEmpty;
    }

    protected void setSequencesEmpty(boolean sequencesEmpty)
    {
        this.sequencesEmpty = sequencesEmpty;
    }

    protected int getFtypeId()
    {
        return ftypeId;
    }

    protected void setFtypeId(int ftypeId)
    {
        this.ftypeId = ftypeId;
        this.ftypeIdString = "" + ftypeId;
    }

    protected int getRid()
    {
        return rid;
    }

    protected void setRid(int rid)
    {
        this.rid = rid;
    }

    protected int getTableId()
    {
        return tableId;
    }

    protected void setTableId(int tableId)
    {
        this.tableId = tableId;
    }

    protected String getClassName()
    {
        return className;
    }

    protected void setClassName(String className)
    {
        this.className = className;
    }

    protected String getGroupName()
    {
        return groupName;
    }

    protected void setGroupName(String groupName)
    {
        this.groupName = groupName;
    }

    protected long getStart()
    {
        return start;
    }

    protected void setStart(long start)
    {
        this.start = start;
    }

    protected long getStop()
    {
        return stop;
    }

    protected void setStop(long stop)
    {
        this.stop = stop;
    }

    protected String getStrand()
    {
        return strand;
    }

    protected void setStrand(String strand)
    {
        this.strand = strand;
    }

    protected String getPhase()
    {
        return phase;
    }

    protected void setPhase(String phase)
    {
        this.phase = phase;
    }

    protected double getScore()
    {
        return score;
    }

    protected void setScore(double score)
    {
        this.score = score;
    }

    protected long getTargetStart()
    {
        return targetStart;
    }

    protected void setTargetStart(long targetStart)
    {
        this.targetStart = targetStart;
    }

    protected long getTargetStop()
    {
        return targetStop;
    }

    protected void setTargetStop(long targetStop)
    {
        this.targetStop = targetStop;
    }

    protected String getSequences()
    {
        return sequences;
    }

    protected void setSequences(String sequences)
    {
        this.sequences = sequences;
    }

    protected int metaIndexOf( String s )
    {
        for( int i=0; i<metaData.length; i++ ) if( s.equals(metaData[i]) ) return i;
        return -1;
    }

    protected String getMeta( String key )
    {
        int idx = metaIndexOf( key );
        if( idx >= 0 && idx < lffLine.length ) return lffLine[idx];
        return null;
    }

    protected static String computeBin( long start, long stop, long min )
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

    public void printTheValues()
    {
        System.err.println(
            "TableId = " + tableId +
                " className = " + className +
                " groupName = " + groupName +
                " start = " + start +
                " stop = " + stop +
                " entryPoint = " +  entryPoint +
                " sbin = " + sFbin +
                " type = " + type +
                " subtype = " + subType +
                " line number = " +  lineNumber +
                " initialComments = " + initialComments
        );

        if(valuePairs != null && valuePairs.size() > 0)
        {
           Iterator  valuePairIterator = valuePairs.entrySet().iterator() ;
            while(valuePairIterator.hasNext())
            {
                Map.Entry valuePairMap = (Map.Entry) valuePairIterator.next() ;
                String key = (String)valuePairMap.getKey();
                ArrayList value = (ArrayList) valuePairMap.getValue();
                for(int i = 0; i < value.size(); i++)
                {
                    System.err.println("name = " + key + " and value = " + (String)value.get(i) );

                }

            }
        }
        else
            System.err.println("Value pairs empty");
    }



    protected void reportError( String msg )
    {
        StringBuffer commonError = null;

        commonError = new StringBuffer(50);

        commonError.append("An Error has been detected in the following Lff line:\n");
        for(int i = 0; i < lffLine.length; i++)
        {
            commonError.append(lffLine[i]);
            commonError.append("\t");
        }
        commonError.append("In LffLine number");
        commonError.append(lineNumber).append("\n").append("Error type:\n" + msg);

        parseError = true;
        errorInLff = commonError.toString();
    }

}
