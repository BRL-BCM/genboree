package org.genboree.tabular;

import java.util.Date;
import java.util.HashMap;

/**
 * User: tong
 * Date: Apr 19, 2007
 * Time: 11:23:40 AM
 */
public class ParseResult {
Date startTime; 
Date endTime;
long fileSize;
String [] trackNames;

    public String[] getTrackNames() {
        return trackNames;
    }

    public void setTrackNames(String[] trackNames) {
        this.trackNames = trackNames;
    }

    public long getFileSize() {
        return fileSize;
    }

    public void setFileSize(long fileSize) {
        this.fileSize = fileSize;
    }


    public Date getStartTime() {
        return startTime;
    }

    public void setStartTime(Date startTime) {
        this.startTime = startTime;
    }

    public Date getEndTime() {
        return endTime;
    }

    public void setEndTime(Date endTime) {
        this.endTime = endTime;
    }

    public HashMap getFid2annos() {
        return fid2annos;
    }

    public void setFid2annos(HashMap fid2annos) {
        this.fid2annos = fid2annos;
    }

    public String[] getAvpAttributes() {
        return avpAttributes;
    }

    public void setAvpAttributes(String[] avpAttributes) {
        this.avpAttributes = avpAttributes;
    }

    public boolean isSuccess() {
        return success;
    }

    public void setSuccess(boolean success) {
        this.success = success;
    }

    public String getErrorMsg() {
        return errorMsg;
    }

    public void setErrorMsg(String errorMsg) {
        this.errorMsg = errorMsg;
    }

    public String getFileName() {
        return fileName;
    }

    public void setFileName(String fileName) {
        this.fileName = fileName;
    }

    HashMap fid2annos; 
String [] avpAttributes; 
boolean success; 
String errorMsg; 
String fileName;     





}
