package org.genboree.upload;

import org.genboree.util.Util;
import org.genboree.util.GenboreeUtils;


import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.ArrayList;
import java.util.regex.Pattern;
import java.util.regex.Matcher;


public class LffData extends LffBasic  {

    public LffData(String[] lffLine, int lineNumber, String lineMd5Value, boolean useVP)
    {
        this.lffLine = lffLine;
        this.lineNumber = lineNumber;
        this.lineMd5Value = lineMd5Value;
        this.useVP = useVP;
    }

    private int extractColorIntValueFromColorValuePair(String annotationColor)
    {
        String colorCodeHex = null;
        int intColorFromHex = -1;
        String newHex = null;

        if(annotationColor == null || annotationColor.length() < 1) return -1;

        colorCodeHex = annotationColor.replaceAll(" ", "");
        if(colorCodeHex.startsWith("#"))
        {
            newHex = colorCodeHex;
        }
        else if(colorCodeHex.indexOf(",") > -1)
        {
            String[] rgb = colorCodeHex.split(",");
            if(rgb.length != 3) return -1;

            String r = Integer.toHexString(Util.parseInt(rgb[0], 0));
            String g = Integer.toHexString(Util.parseInt(rgb[1], 0));
            String b = Integer.toHexString(Util.parseInt(rgb[2], 0));
            newHex = "#" + r + g + b;
        }
        else
        {
            HashMap colors = GenboreeUtils.getColorCode();
            String tempColorCode = colorCodeHex.replaceAll(" ", "").toUpperCase();

            if(colors != null && colors.containsKey(tempColorCode) )
                newHex = (String)colors.get(tempColorCode);
            else
                newHex = colorCodeHex;
        }


        colorCodeHex = newHex.replaceFirst("#", "");

        if(colorCodeHex.length() == 6)
        {
            intColorFromHex = Integer.parseInt(colorCodeHex, 16);
        }
        else
            return -1;

        return  intColorFromHex;
    }

    private void setColorCode()
    {
        String[] tokens = null;
        int displayColor = -1;
        boolean colorFound = false;
        StringBuffer stringBuffer = null;

        if(cleanComments == null) return;

        stringBuffer = new StringBuffer( 200 );

        if(cleanComments.indexOf("annotationColor=") > -1)
            tokens = cleanComments.split(";");
        else
            return;
// TODO handle annotationColor without ; separation


        for( int i = 0; i < tokens.length; i++)
        {
            String comment = tokens[i].trim();

            if(comment.startsWith("annotationColor=") )
            {
                if(!colorFound)
                {
                    comment = comment.replaceFirst("annotationColor=", "");
                    displayColor = extractColorIntValueFromColorValuePair(comment);
                    if( displayColor > -1)
                    {
                        this.displayColor = displayColor;
                        colorFound = true;
                    }
                }
            }
            else if(comment != null && comment.length() > 0)
            {
                stringBuffer.append(comment);
                stringBuffer.append("; ");
            }
            else
            { }

        }
        if(stringBuffer.length() > 0)
            cleanComments = stringBuffer.toString();
        else
            cleanComments = null;

        return;
    }


    private void checkForAnnotationAction()
    {
        String[] tokens = null;
        boolean actionFound = false;
        StringBuffer stringBuffer = null;

        if(cleanComments == null) return;

        stringBuffer = new StringBuffer( 200 );

        if(cleanComments.indexOf("annotationAction=") > -1)
            tokens = cleanComments.split(";");
        else
        {
            setAnnotationAction(INSERTANNOTATION);
            return;
        }

        for( int i = 0; i < tokens.length; i++)
        {
            String comment = tokens[i].trim();
            if(comment.startsWith("annotationAction=") )
            {
                if(!actionFound)
                {
                    comment = comment.replaceFirst("annotationAction=", "");
                    if(comment.equalsIgnoreCase("DELETEANNOTATION"))
                    {
                        setAnnotationAction(DELETEANNOTATION);
                        actionFound = true;
                    }
                }
            }
            else
            {
                stringBuffer.append(comment);
                stringBuffer.append("; ");
            }

        }

        if(stringBuffer.length() > 0)
            cleanComments = stringBuffer.toString();
        else
            cleanComments = null;

        return;
    }

    private void checkForAttributeAction()
    {
        String[] tokens = null;
        boolean actionFound = false;
        StringBuffer stringBuffer = null;

        if(cleanComments == null) return;

        stringBuffer = new StringBuffer( 200 );

        if(cleanComments.indexOf("attributeAction=") > -1)
            tokens = cleanComments.split(";");
        else
        {
            setAttributeAction(UPDATEATTRIBUTE);
            return;
        }


        for( int i = 0; i < tokens.length; i++)
        {
            String comment = tokens[i].trim();

            if(comment.startsWith("attributeAction=") )
            {
                if(!actionFound)
                {
                    comment = comment.replaceFirst("attributeAction=", "");
                    if(comment.equalsIgnoreCase("APPENDATTRIBUTE"))
                    {
                        setAttributeAction(APPENDATTRIBUTE);
                        actionFound = true;
                    }
                    else if(comment.equalsIgnoreCase("DELETEATTRIBUTE"))
                    {
                        setAttributeAction(DELETEATTRIBUTE);
                        actionFound = true;
                    }
                }
            }
            else
            {
                stringBuffer.append(comment);
                stringBuffer.append("; ");
            }

        }
        if(stringBuffer.length() > 0)
            cleanComments = stringBuffer.toString();
        else
            cleanComments = null;

        return;
    }

    private void setDisplayCode()
    {
        String[] tokens = null;
        int displayCode = -1;
        boolean displayCodeFound = false;
        StringBuffer stringBuffer = null;

        if(cleanComments == null) return;

        stringBuffer = new StringBuffer( 200 );

        if(cleanComments.indexOf("annotationCode=") > -1)
            tokens = cleanComments.split(";");
        else
            return;
// TODO handle annotationColor without ; separation


        for( int i = 0; i < tokens.length; i++)
        {
            String comment = tokens[i].trim();

            if(comment.startsWith("annotationCode=") )
            {
                if(!displayCodeFound)
                {
                    comment = comment.replaceFirst("annotationCode=", "");
                    displayCode = extractIntValueFormDisplayCode(comment);
                    if(displayCode > -1)
                    {
                        this.displayCode = displayCode;
                        displayCodeFound = true;
                    }
                }
            }
            else
            {
                stringBuffer.append(comment);
                stringBuffer.append("; ");
            }

        }
        if(stringBuffer.length() > 0)
            cleanComments = stringBuffer.toString();
        else
            cleanComments = null;

        return;
    }

/* TODO modify this method when specs are in place 04/11/06 MLGG */
    private int extractIntValueFormDisplayCode(String annotationCode)
    {
        int displayCode = -1;


        if(annotationCode == null || annotationCode.length() < 1)
            displayCode = -1;
        else
            displayCode = Util.parseInt(annotationCode, -1);

        return displayCode;
    }

    private void setExtraClasses()
    {
        String EClasses = null;
        String[] tokens = null;
        String[] classTokens = null;
        StringBuffer stringBuffer = null;
        HashMap results = null;

        if(cleanComments == null) return;

        if(cleanComments.indexOf("aHClasses=") > -1)
        {
            tokens = cleanComments.split(";");
        }
        else
            return;

        results = new HashMap();
        stringBuffer = new StringBuffer( 200 );



        for( int i = 0; i < tokens.length; i++)
        {
            String comment = tokens[i].trim();

            if(comment.startsWith("aHClasses="))
            {
                EClasses = comment.replaceFirst("aHClasses=", "");
                if(EClasses != null)
                {
                    classTokens = EClasses.split(",");
                    if(classTokens != null)
                    {
                        for(int a = 0; a < classTokens.length; a++)
                        {
                            results.put(classTokens[a], classTokens[a]);
                        }
                    }
                }
                comment = null;
            }

            if(comment != null )
                comment = comment.trim();
            if(comment != null && comment.length() > 0 )
            {
                stringBuffer.append(comment);
                stringBuffer.append("; ");
            }
        }

        if(stringBuffer.length() > 0)
            cleanComments = stringBuffer.toString();
        else
            cleanComments = null;


        if(results.isEmpty() )
        {
            extraClasses = null;
        }
        else
        {
            int extraClassCounter = 0;
            extraClasses = new String[results.size()];
            Iterator extraClassIterator = results.entrySet().iterator() ;
            while(extraClassIterator.hasNext())
            {
                Map.Entry extraClassMap = (Map.Entry) extraClassIterator.next() ;
                extraClasses[extraClassCounter] = (String)extraClassMap.getKey();
                extraClassCounter++;
            }
        }
        return;
    }

    private int setValuePairs()
    {
        HashMap results = null;
        String removedExtras = null;
	    boolean commentsLeftOversEmpty = false;

        if(cleanComments != null)
            cleanComments = cleanComments.trim();
        if(cleanComments != null)
            cleanComments = cleanComments.replaceFirst(";\\s;", ";");

        if(cleanComments == null || cleanComments.length() < 2)
        {
            return 1;
        }
        if(!useVP)
        {
            return 2;
        }
        matchRegex2.reset(cleanComments);

        if(matchRegex2.matches())
        {
            removedExtras = matchRegex2.replaceAll("$1");
        }
        else
        {
            removedExtras = cleanComments;
        }

        matchRegex4.reset(cleanComments);

        commentsLeftOvers = matchRegex4.replaceAll("$1");
        if (commentsLeftOvers != null)
            commentsLeftOvers = commentsLeftOvers.trim();
        if(commentsLeftOvers != null && commentsLeftOvers.length() == 1 && commentsLeftOvers.equals(";"))
            commentsLeftOvers = null;
        if(commentsLeftOvers == null || commentsLeftOvers.length() < 1)
            commentsLeftOversEmpty = true;

        if(!commentsLeftOversEmpty)
                return -1;

        results = new HashMap();

        ArrayList matches = splitValuePairs(removedExtras);

        if(matches != null)
        {
            for(int i = 0; i < matches.size(); i++)
            {
                String comment = (String)matches.get(i);
                comment = comment.trim();
                String[] vp = splitValueAndPair(comment);

                if(comment != null && vp.length == 2)
                {
                    String key = vp[0];
                    String value = vp[1];
                    if(value == null) value = "";
                    ArrayList tempValues;
                    if(results.containsKey(key))
                    {
                        tempValues = (ArrayList)results.get(key);
                        tempValues.add(value);

                    }
                    else
                    {
                        tempValues = new ArrayList(10);
                        tempValues.add(value);
                    }
                    results.put(key, tempValues);
                }
            }
        }

        if(results.isEmpty() )
        {
            this.valuePairs = null;
        }
        else
        {
            this.valuePairs = results;
        }
        cleanComments = null;
        commentsEmpty = true;

        return 5;
    }

    public StringBuffer addValuesToUpdateFdata()
    {
        StringBuffer localFdataBuffer = null;
        String[] dataToExport = new String[5];

        dataToExport[0] = "" + fid;
        dataToExport[1] = (targetStart != 0) ? "" + targetStart : "NULL";
        dataToExport[2] = (targetStop != 0) ? "" + targetStop : "NULL";
        dataToExport[3] = (displayCode > -1) ? "" + displayCode : "NULL";
        dataToExport[4] = (displayColor > -1) ? "" + displayColor : "NULL";

        localFdataBuffer = new StringBuffer(200);
        localFdataBuffer.append(" ( ");
        for(int i = 0; i < dataToExport.length; i++)
        {
            if(dataToExport[i] == null || dataToExport[i].equalsIgnoreCase("null"))
                localFdataBuffer.append("NULL");
            else
                localFdataBuffer.append("'").append(GenboreeUtils.mysqlEscapeSpecialChars(dataToExport[i])).append("'");

            if(i < (dataToExport.length -1))
                localFdataBuffer.append(", ");
            else
                localFdataBuffer.append(")");
        }

        return localFdataBuffer;
    }

    public StringBuffer exportComments2Insert()
    {
        StringBuffer localFidTextBuffer = null;
        if(getComments() == null ) return null;

        localFidTextBuffer = new StringBuffer(200);

        localFidTextBuffer.append(" ( ");
        localFidTextBuffer.append(getFid());
        localFidTextBuffer.append(", ");
        localFidTextBuffer.append(getFtypeId());
        localFidTextBuffer.append(", ");
        localFidTextBuffer.append("'").append("t").append("'");
        localFidTextBuffer.append(", ");
        localFidTextBuffer.append("'").append(GenboreeUtils.mysqlEscapeSpecialChars(getComments())).append("'");
        localFidTextBuffer.append(")");

        return localFidTextBuffer;
    }


    public StringBuffer exportSequences2Insert()
    {
        StringBuffer localFidTextBuffer = null;
        if(getSequences() == null ) return null;

        localFidTextBuffer = new StringBuffer(200);

        localFidTextBuffer.append(" ( ");
        localFidTextBuffer.append(getFid());
        localFidTextBuffer.append(", ");
        localFidTextBuffer.append(getFtypeId());
        localFidTextBuffer.append(", ");
        localFidTextBuffer.append("'").append("s").append("'");
        localFidTextBuffer.append(", ");
        localFidTextBuffer.append("'").append(GenboreeUtils.mysqlEscapeSpecialChars(getSequences())).append("'");
        localFidTextBuffer.append(")");

        return localFidTextBuffer;

    }

    private ArrayList splitValuePairs(String inputText)
    {
        ArrayList valuePairsArray = null;
        String capturedText = null;

        if(inputText == null) return null;

        valuePairsArray = new ArrayList();

        matchRegex3.reset(inputText);

        int thePos = 0;
        while(matchRegex3.find(thePos))
        {
            capturedText = inputText.substring(matchRegex3.start(),matchRegex3.end());
            valuePairsArray.add(capturedText);
            thePos = matchRegex3.end();
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



    public LffData parseAnnotationData()
    {
        parseError = false;
        int createValuePairs = 0;

        if( lffLine.length < 10 )
        {
            reportError( "Invalid format of annotation record" );
            return null;
        }

        entryPoint = getMeta( "ref" );
        if(entryPoint == null)
        {
            reportError( "Empty entryPoint field" );
            return null;
        }
        entryPoint = entryPoint.trim();
        if(entryPoint == null || entryPoint.length() < 1)
        {
            reportError( "Empty entryPoint field");
            return null;
        }

        className = getMeta( "class" );

        className = className.trim();

        if(className == null || className.length() < 1)
        {
            reportError( "Empty className field");
            return null;
        }

        groupName = getMeta( "name" );
        if(groupName == null)
        {
            reportError( "Empty annotation name" );
            return null;
        }

        groupName = groupName.trim();

        if(groupName == null || groupName.length() < 1)
        {
            reportError( "Empty annotation name" );
            return null;
        }

        if(groupName.endsWith("_CV"))
            tableId = fdata2_cvTable;
        else if(groupName.endsWith("_GV"))
            tableId = fdata2_gvTable;
        else
            tableId = fdata2Table;

        if(!groupName.endsWith("_CV") && !groupName.endsWith("_GV"))
        {
            String tempString = "";
            boolean processTheComments = false;

            tempString = getMeta( "text" );
            if(tempString != null && tempString.length() > 1)
            {
                tempString = tempString.trim();
                if(tempString != null && tempString.length() > 1)
                    processTheComments = true;
            }

            if(processTheComments)
            {
                StringBuffer tempBuffer = new StringBuffer(200);
                tempBuffer.append(tempString);
                tempBuffer.append(";");
                while((tempBuffer.length() > 1) && (tempBuffer.charAt(0) == ';' || tempBuffer.charAt(0) == ' '))
                    tempBuffer.deleteCharAt(0);
                initialComments = tempBuffer.toString();
                commentsEmpty = Util.isEmpty(initialComments);
                if(!commentsEmpty)
                {
                    initialComments = initialComments.replaceAll("(?:\\s*;\\s*)+", "; ");
                    if(initialComments.equals("null")) initialComments = null;
                }

                commentsEmpty = Util.isEmpty(initialComments);
                if(!commentsEmpty && initialComments.equals("."))
                    commentsEmpty = true;
                else
                    commentsEmpty = false;

                if(!commentsEmpty)
                {
                    comments = initialComments;
                    cleanComments = initialComments;
                }
                else
                {
                    comments = cleanComments = initialComments = null;
                }

                setColorCode();
                setDisplayCode();
                setExtraClasses();
                checkForAnnotationAction();
                checkForAttributeAction();

                if(useVP)
                {
                    createValuePairs = setValuePairs();
                    comments = null;
                    commentsEmpty = true;
                    if(createValuePairs < 0) return null;
                }
                else
                {
                    comments = cleanComments;
                    if(comments == null || comments.length() < 1)
                    {
                        comments = null;
                        commentsEmpty = true;
                    }
                }
            }
            else
            {
                commentsEmpty = true;
                initialComments = null;
            }

            sequences = getMeta( "sequence" );
            sequencesEmpty = Util.isEmpty(sequences);
            if(!sequencesEmpty && sequences.equals("."))
                sequencesEmpty = true;


            freeStyleComments = getMeta("freeStyleComments");
            if(freeStyleComments != null) freeStyleComments = freeStyleComments.trim();
            freeStyleCommentsEmpty = Util.isEmpty(freeStyleComments);
            if(!freeStyleCommentsEmpty && freeStyleComments.equals("."))
                freeStyleCommentsEmpty = true;

            if(!freeStyleCommentsEmpty && useVP)
            {
                comments = freeStyleComments;
                commentsEmpty = false;
            }

        }
        else
        {
            commentsEmpty = true;
            initialComments = null;
            sequencesEmpty = true;
            sequences = null;

        }

        if( commentsEmpty ) initialComments = null;
        if( sequencesEmpty ) sequences = null;

        type = getMeta( "type" );        // ftype.fmethod
        if(type == null)
        {
            reportError( "Empty annotation type field" );
            return null;
        }
        type = type.trim();
        if(type == null || type.length() < 1)
        {
            reportError( "Empty annotation type field");
            return null;
        }
        subType = getMeta( "subtype" );  // ftype.fsource
        if(subType == null)
        {
            reportError( "Empty annotation subtype field");
            return null;
        }
        subType = subType.trim();

        if(subType == null || subType.length() < 1)
        {
            reportError( "Empty annotation subtype field");
            return null;
        }

        String coord = null;
        coord = getMeta("start" );

         if(coord == null)
        {
            reportError( "Empty annotation start field");
            return null;
        }

        coord = coord.trim();

        if(coord == null | coord.length() < 1)
        {
            reportError( "Empty annotation start field");
            return null;
        }

        if(coord.matches("^\\s*(?:\\+|\\-)?\\d+\\s*$"))
        {
            start = Util.parseLong( coord, -1L );
            if(start <= 0) start = 1;
            if( start < 1  )
            {
                reportError("The start value is less that 1 so the annotation is rejected ann name = " + groupName );
                return null;
            }
        }
        else
        {
            reportError( "Start contains unknown values = '" + coord + "'");
            return null;
        }

        coord = null;
        coord = getMeta("stop" );

         if(coord == null)
        {
            reportError( "Empty annotation stop field");
            return null;
        }

        coord = coord.trim();
        if(coord == null | coord.length() < 1)
        {
            reportError( "Empty annotation stop field");
            return null;
        }

        if(coord.matches("^\\s*(?:\\+|\\-)?\\d+\\s*$"))
        {
            stop = Util.parseLong( coord, -1L );
            if(stop == 0) stop = 1;
            if( stop < 1  )
            {
                reportError("The stop value is less that 1 so the annotation is rejected ann name = " + groupName );
                return null;
            }
        }
        else
        {
            reportError( "Stop contains unknown values = '" + coord + "'");
            return null;
        }

        if( start > stop )
        {
            long tempValue = 0;
            tempValue  = start;
            start = stop;
            stop = tempValue;
        }

        strand = getMeta("strand");
        if(strand == null)
        {
            reportError( "Empty annotation strand field");
            return null;
        }
        strand = strand.trim();

        if(strand == null || strand.length() < 1)
        {
            reportError( "Empty annotation strand field");
            return null;
        }


        if(strand.equals("+") || strand.equals("-") ) { }
        else
        {
            reportError( "Strand contains unknown values = '" + strand + "'");
            return null;
        }

        phase = getMeta("phase" );
        if(phase == null)
        {
            reportError("The phase value is less that 1 so the annotation is rejected ann name = " + groupName );
            return null;
        }

         phase = phase.trim();

        if(phase == null || phase.length() < 1)
        {
            reportError( "Empty annotation phase field");
            return null;
        }

        if( phase.matches("^[012\\.]$") == false)
        {
            reportError( "Phase contains unknown values = '" + phase + "'");
            return null;
        }

        scoreStr  = getMeta("score");

        if(scoreStr == null)
        {
            reportError( "Empty annotation score field");
            return null;
        }

        scoreStr = scoreStr.trim();
        if(scoreStr == null | scoreStr.length() < 1)
        {
            reportError( "Empty annotation score field");
            return null;
        }
        if(scoreStr.matches("^(?:\\+|\\-)?\\d*(?:\\d+\\.|\\.\\d+)?(?:[eE](?:\\+|\\-)?\\d+)?$") == false)
        {
            reportError( "Score contains unknown values = '" + scoreStr + "'");
            return null;
        }


        if(scoreStr.startsWith("e") || scoreStr.startsWith("E"))
            scoreStr = "1" + scoreStr;
        else if(scoreStr.startsWith(".") && scoreStr.length() > 1)
        {
            scoreStr = "0" + scoreStr;
        }

        if(scoreStr.equals("."))
        {
            reportError( "Score contains unknown values = '" + scoreStr + "'");
            return null;
        }

        try
        {
            score = Double.parseDouble( scoreStr );
        }
        catch(  Throwable thr )
        {
            reportError(  "Unable to read score field" );
            return null;
        }

        String tempTarget = null;
        tempTarget = getMeta("tstart" );

        if(tempTarget == null)
        {
            tempTarget = ".";
        }

        tempTarget = tempTarget.trim();

        if(tempTarget == null | tempTarget.length() < 1)
        {
            reportError( "Empty annotation targetStart field");
            return null;
        }

        if(tempTarget.equals(".") || tempTarget.matches("^\\s*(?:\\+|\\-)?\\d+\\s*$"))
        {
             targetStart = Util.parseLong( tempTarget, 0L );
             if(targetStart >= maxValueForInt) targetStart = maxValueForInt -1;
             if(targetStart <= minValueForInt) targetStart = minValueForInt +1;
        }
        else
        {
            reportError( "Target Start contains unknown values = '" + tempTarget + "'");
            return null;
        }

        tempTarget = null;
        tempTarget = getMeta("tend" );

         if(tempTarget == null)
        {
            tempTarget = ".";
        }

        tempTarget = tempTarget.trim();

        if(tempTarget == null | tempTarget.length() < 1)
        {
            reportError( "Empty annotation targetStop field");
            return null;
        }

        if(tempTarget.equals(".") || tempTarget.matches("^\\s*(?:\\+|\\-)?\\d+\\s*$"))
        {
            targetStop = Util.parseLong( tempTarget, 0L );
            if(targetStop >= maxValueForInt) targetStop = maxValueForInt -1;
            if(targetStop <= minValueForInt) targetStop = minValueForInt +1;
        }
        else
        {
            reportError( "TargetStop contains unknown values = '" + tempTarget + "'");
            return null;
        }

        if(targetStop == 1 && targetStart == 1)
        {
            targetStop = targetStart = 0;
        }

        sFbin = computeBin( start, stop, minFbinConstant );

        setIndexMd5Key();

        annotationsSuccessfullyParsed = true;

        return this;
    }

    public void printLffLine()
    {
        //#class  name    type    subtype ref     start   stop    strand  phase   score   tstart  tend    attribute Comments      sequence        freestyle comments
        System.err.print(className + "\t" + groupName + "\t" + type + "\t" +
                subType +"\t" +  entryPoint +"\t" + start + "\t" +
                stop + "\t" + strand + "\t" + phase + "\t" + scoreStr + "\t" + targetStart + "\t" + targetStop + "\t");
        if(valuePairs == null || valuePairs.isEmpty() || valuePairs.size() < 2)
        {
            System.err.print(".\t");
        }
        else
        {
          StringBuffer tempBuffer = new StringBuffer( 200 );
            Iterator valuePairIterator = valuePairs.entrySet().iterator() ;
            while(valuePairIterator.hasNext())
            {
                Map.Entry valuePairMap = (Map.Entry) valuePairIterator.next() ;
                String key = (String)valuePairMap.getKey();
                ArrayList value = (ArrayList) valuePairMap.getValue();
                for(int i = 0; i < value.size(); i++)
                {
                    tempBuffer.append(key).append("=").append((String)value.get(i)).append("; ");
                }

            }
            tempBuffer.append("\t");
            System.err.print(tempBuffer.toString());
        }

        if(sequencesEmpty)
            System.err.print(".\t");
        else
            System.err.print(sequences);

        if(freeStyleCommentsEmpty)
            System.err.print(".\n");
        else
            System.err.print(freeStyleComments);

        System.err.println();
        System.err.flush();
    }


    protected String getInsertReadyValuePairs()
    {
        StringBuffer stringBuffer = null;
        int valuePairSize = valuePairs.size();

        if(valuePairs.isEmpty() )
        {
            return null;
        }
        else
        {
            stringBuffer = new StringBuffer( 200 );
            int valuePairsCounter = 0;
            Iterator valuePairIterator = valuePairs.entrySet().iterator() ;
            while(valuePairIterator.hasNext())
            {
                Map.Entry valuePairMap = (Map.Entry) valuePairIterator.next() ;
                String key = (String)valuePairMap.getKey();
                ArrayList value = (ArrayList) valuePairMap.getValue();
                for(int i = 0; i < value.size(); i++)
                {
                    stringBuffer.append("(").append(fidString).append(", ").append(ftypeIdString).append(", ");
                    stringBuffer.append(key).append(", ");
                    stringBuffer.append((String)value.get(i)).append(")");
                }


                if(valuePairsCounter < valuePairSize)
                    stringBuffer.append(", ");

                valuePairsCounter++;
            }
        }
        return stringBuffer.toString();
    }

    public StringBuffer exportFdata2Insert()
    {
        StringBuffer localFdataBuffer = null;
        localFdataBuffer = new StringBuffer(200);

        localFdataBuffer.append(" ( ");
        localFdataBuffer.append(getFid());
        localFdataBuffer.append(", ");
        localFdataBuffer.append(getRid());
        localFdataBuffer.append(", ");
        localFdataBuffer.append(getStart());
        localFdataBuffer.append(", ");
        localFdataBuffer.append(getStop());
        localFdataBuffer.append(", ");
        localFdataBuffer.append("'").append(getsFbin()).append("'");
        localFdataBuffer.append(", ");
        localFdataBuffer.append(getFtypeId());
        localFdataBuffer.append(", ");
        localFdataBuffer.append("'").append(getScore()).append("'");
        localFdataBuffer.append(", ");
        localFdataBuffer.append("'").append(getStrand()).append("'");
        localFdataBuffer.append(", ");
        localFdataBuffer.append("'").append(getPhase()).append("'");
        localFdataBuffer.append(", ");
        if(getTargetStart() != 0)
            localFdataBuffer.append(getTargetStart());
        else
            localFdataBuffer.append("NULL");
        localFdataBuffer.append(", ");

        if(getTargetStop() != 0)
            localFdataBuffer.append(getTargetStop());
        else
            localFdataBuffer.append("NULL");
        localFdataBuffer.append(", ");
        localFdataBuffer.append("'").append(GenboreeUtils.mysqlEscapeSpecialChars(getGroupName())).append("'");
        localFdataBuffer.append(", ");
        if( getDisplayCode() > -1)
            localFdataBuffer.append(getDisplayCode());
        else
            localFdataBuffer.append("NULL");
        localFdataBuffer.append(", ");

        if(getDisplayColor() > -1)
            localFdataBuffer.append(getDisplayColor());
        else
            localFdataBuffer.append("NULL");

        localFdataBuffer.append(")");

        return localFdataBuffer;

    }


    public String[] exportDataToUpdate() {
        String[] dataToExport = new String[5];

        dataToExport[0] = "" + fid;
        dataToExport[1] = (targetStart != 0) ? "" + targetStart : "NULL";
        dataToExport[2] = (targetStop != 0) ? "" + targetStop : "NULL";
        dataToExport[3] = (displayCode > -1) ? "" + displayCode : "NULL";
        dataToExport[4] = (displayColor > -1) ? "" + displayColor : "NULL";

        return dataToExport;

    }


}
