package org.genboree.upload;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;


public class GroupData {
    private int groupDataId;
    private String fid;
    private long start;
    private long stop;
    private String groupName;
    private String groupContextCode;
    private String ftypeId;
    private String rid;



    public GroupData(String fid, long fstart, long fstop, String myGroupName, String myGroupContextCode, String myFtypeId, String myRid, int groupDataId)
    {
        this.fid = fid;
        this.start = fstart;
        this.stop = fstop;
        this.groupName = myGroupName;
        this.groupContextCode = myGroupContextCode;
        this.ftypeId = myFtypeId;
        this.rid = myRid;
        this.groupDataId = groupDataId;
    }

    public GroupData()
    {
        this.clear();
    }

    public void clear()
    {
        this.fid = null;
        this.start = -1;
        this.stop = -1;
        this.groupName = null;
        this.groupContextCode = null;
        this.ftypeId = null;
        this.rid = null;
        this.groupDataId = -1;
    }

    public void populateWithData(String id, long fstart, long fstop, String myGroupName, String myGroupContextCode, String myFtypeId, String myRid, int groupDataId)
    {
        this.fid = id;
        this.start = fstart;
        this.stop = fstop;
        this.groupName = myGroupName;
        this.groupContextCode = myGroupContextCode;
        this.ftypeId = myFtypeId;
        this.rid = myRid;
        this.groupDataId = groupDataId;
    }

    public int getGroupDataId()
    {
        return groupDataId;
    }

    public void setGroupDataId(int groupDataId)
    {
        this.groupDataId = groupDataId;
    }

    public String getGroupContextCode()
    {
        return groupContextCode;
    }

    public void setGroupContextCode(String groupContextCode)
    {
        this.groupContextCode = groupContextCode;
    }

    public String getFid()
    {
        return fid;
    }

    public void setFid(String fid)
    {
        this.fid = fid;
    }

    public String getFtypeId()
    {
        return ftypeId;
    }

    public void setFtypeId(String ftypeId)
    {
        this.ftypeId = ftypeId;
    }

    public String getRid()
    {
        return rid;
    }

    public void setRid(String rid)
    {
        this.rid = rid;
    }

    public String getGroupName()
    {
        return groupName;
    }

    public void setGroupName(String groupName)
    {
        this.groupName = groupName;
    }

    public long getStart() {
        return start;
    }

    public void setStart(long start) {
        this.start = start;
    }

    public long getStop() {
        return stop;
    }

    public void setStop(long stop) {
        this.stop = stop;
    }



}
