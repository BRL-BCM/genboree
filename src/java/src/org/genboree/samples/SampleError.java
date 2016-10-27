package org.genboree.samples;

import java.util.HashMap;

/**
 * User: tong
 * Date: Nov 30, 2006
 * Time: 1:49:42 PM
 */
public class SampleError {
    String fileName;

    public String getFileName() {
        return fileName;
    }

    public void setFileName(String fileName) {
        this.fileName = fileName;
    }

    public int getNumSamples() {
        return numSamples;
    }

    public void setNumSamples(int numSamples) {
        this.numSamples = numSamples;
    }

    public HashMap getError2Line() {
        return error2Line;
    }

    public void setError2Line(HashMap error2Line) {
        this.error2Line = error2Line;
    }

    public int getErrStatus() {
        return errStatus;
    }

    public void setErrStatus(int errStatus) {
        this.errStatus = errStatus;
    }

    public int getNumInserted() {
        return numInserted;
    }

    public void setNumInserted(int numInserted) {
        this.numInserted = numInserted;
    }

    public int getNumUpdated() {
        return numUpdated;
    }

    public void setNumUpdated(int numUpdated) {
        this.numUpdated = numUpdated;
    }

    int numSamples; 
    HashMap error2Line; 
    int errStatus;  
    int numInserted; 
    int numUpdated;
    String startTime; 
    String finishTime;

    public String getStartTime() {
        return startTime;
    }

    public void setStartTime(String startTime) {
        this.startTime = startTime;
    }

    public String getFinishTime() {
        return finishTime;
    }

    public void setFinishTime(String finishTime) {
        this.finishTime = finishTime;
    }


    public SampleError (String fName ) {
        this.fileName = fName;
        this.error2Line = new HashMap ();          
    } 
     
    public static final int NO_ERROR = 0; 
    public static final int NO_FILE = 100; 
    public static final int BLANK_FILE = 110; 
    public static final int HAS_ERROR = 300; 
 
}
