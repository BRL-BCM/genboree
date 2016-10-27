package org.genboree.editor;

import org.genboree.upload.RefSeqParams;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;


public class AnnotationData implements RefSeqParams {
    private long start;
    private long stop;
    private String strand;
    private String phase;
    private double score;
    private String className;
    private String groupName;
    private String sequences;
    private String comments;
    private long targetStart;
    private long targetStop;
    private int displayColor;
    private int displayCode;
    private int rid;
    private int ftypeId;
    private int tableId;
    private String fbin;
    private boolean commentsEmpty = false;
    private boolean sequencesEmpty = false;
    private String type;
    private String subType;
    private String key;
    private String md5Key;
    private long id = -1;

    public String  getGroupContextCode(){
        return groupContextCode;
    }

    public void setGroupContextCode(String  groupContextCode) {
       this.groupContextCode = groupContextCode;
    }

    String  groupContextCode;
    public AnnotationData() {

    }

    public AnnotationData(int tableId, String className, String fbin, int rid, int ftypeId, long start, long stop, double score, String strand, String phase,
                          long targetStart, long targetStop, String groupName, String type, String subType, String comments, boolean commentsEmpty, String sequences,
                          boolean sequencesEmpty) {
        setTableId(tableId);
        setClassName(className);
        setFbin(fbin);
        setRid(rid);
        setFtypeId(ftypeId);
        setStart(start);
        setStop(stop);
        setScore(score);
        setStrand(strand);
        setPhase(phase);
        setTargetStart(targetStart);
        setTargetStop(targetStop);
        setGroupName(groupName);
        setCommentsEmpty(commentsEmpty);
        setComments(comments);
        setSequences(sequences);
        setSequencesEmpty(sequencesEmpty);
        setType(type);
        setSubType(subType);
        setDisplayColor(-1);
        setDisplayCode(-1);
    }

    public String getSubType() {
        return subType;
    }

    public int getDisplayColor() {
        return displayColor;
    }

    public void setDisplayColor(int displayColor) {
        this.displayColor = displayColor;
    }

    public int getDisplayCode() {
        return displayCode;
    }

    public void setDisplayCode(int displayCode) {
        this.displayCode = displayCode;
    }

    public void setKey() {
        String mykey = null;

        mykey = new StringBuffer().append(fbin).append("-").append(rid).append("-").append(start).append("-").append(stop).append("-").append(ftypeId).append("-").append(groupName).append("-").append(score).append("-").append(strand).append("-").append(phase).toString();

        key = mykey;

    }

    public void setMd5Key() {
        MessageDigest md = null;
        byte[] dg = null;
        String outc = null;
        String hc = null;

        try {
            md = MessageDigest.getInstance("MD5");
            md.update(key.getBytes());
            dg = md.digest();
            outc = "";
            for (int i = 0; i < dg.length; i++) {
                hc = Integer.toHexString((int) dg[i] & 0xFF);
                while (hc.length() < 2) hc = "0" + hc;
                outc = outc + hc;
            }
            md5Key = outc;
        } catch (NoSuchAlgorithmException ex) {
            System.err.println("fail to generate md5 key in setMd5key AnnotationData.java");
            System.err.flush();
        }
    }

    public String getKey() {
        return key;
    }

    public String getMd5Key() {
        return md5Key;
    }

    public void setSubType(String subType) {
        this.subType = subType;
    }

    public String getType() {
        return type;
    }

    public void setType(String type) {
        this.type = type;
    }

    public long getId() {
        return id;
    }

    public void setId(long id) {
        this.id = id;
    }

    public boolean isCommentsEmpty() {
        return commentsEmpty;
    }

    public void setCommentsEmpty(boolean commentsEmpty) {
        this.commentsEmpty = commentsEmpty;
    }

    public boolean isSequencesEmpty() {
        return sequencesEmpty;
    }

    public void setSequencesEmpty(boolean sequencesEmpty) {
        this.sequencesEmpty = sequencesEmpty;
    }


    public String getFbin() {
        return fbin;
    }

    public void setFbin(String fbin) {
        this.fbin = fbin;
    }

    public int getFtypeId() {
        return ftypeId;
    }

    public void setFtypeId(int ftypeId) {
        this.ftypeId = ftypeId;
    }

    public int getRid() {
        return rid;
    }

    public void setRid(int rid) {
        this.rid = rid;
    }

    public int getTableId() {
        return tableId;
    }

    public void setTableId(int tableId) {
        this.tableId = tableId;
    }

    public String getClassName() {
        return className;
    }

    public void setClassName(String className) {
        this.className = className;
    }


    public String getGroupName() {
        return groupName;
    }

    public void setGroupName(String groupName) {
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

    public String getStrand() {
        return strand;
    }

    public void setStrand(String strand) {
        this.strand = strand;
    }

    public String getPhase() {
        return phase;
    }

    public void setPhase(String phase) {
        this.phase = phase;
    }

    public double getScore() {
        return score;
    }

    public void setScore(double score) {
        this.score = score;
    }

    public long getTargetStart() {
        return targetStart;
    }

    public void setTargetStart(long targetStart) {
        this.targetStart = targetStart;
    }

    public long getTargetStop() {
        return targetStop;
    }

    public void setTargetStop(long targetStop) {
        this.targetStop = targetStop;
    }

    public String getComments() {
        return comments;
    }

    public void setComments(String comments) {
        this.comments = comments;
    }

    public String getSequences() {
        return sequences;
    }

    public void setSequences(String sequences) {
        this.sequences = sequences;
    }

    public String[] exportDataToUpdate() {
        String[] dataToExport = new String[5];

        dataToExport[0] = "" + id;
        dataToExport[1] = (targetStart != 0) ? "" + targetStart : "NULL";
        dataToExport[2] = (targetStop != 0) ? "" + targetStop : "NULL";
        dataToExport[3] = (displayCode > -1) ? "" + displayCode : "NULL";
        dataToExport[4] = (displayColor > -1) ? "" + displayColor : "NULL";

        return dataToExport;

    }


}
