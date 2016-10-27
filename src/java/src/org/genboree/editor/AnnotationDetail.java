package org.genboree.editor;
import org.genboree.tabular.LffConstants;

import java.io.Serializable;
import java.text.DecimalFormat;
import java.text.NumberFormat;
import java.util.HashMap;

/**
 * User: tong Date: Oct 17, 2005 Time: 12:01:36 AM
 */
public class AnnotationDetail extends AnnotationData implements Serializable {
    String fmethod;
    String fsource;
    String trackName;
    String gname;
    String tstart;
    String tstop;
    String chromosome;
    long length;
    int fid;
    boolean isShare;
    
    
    
    public AnnotationDetail () {
        
        super();
        
    }

    public boolean isShare() {
        return isShare;
    }

    public void setShare(boolean share) {
        isShare = share;
    }

    String gclassName;
    HashMap lff2value;

   
    public void setlff2value() {
         this.lff2value = new HashMap();
        lff2value.put(LffConstants.LFF_COLUMNS[0], gname); 
        lff2value.put(LffConstants.LFF_COLUMNS[1], this.getGclassName()); 
        lff2value.put(LffConstants.LFF_COLUMNS[2], fmethod); 
        lff2value.put(LffConstants.LFF_COLUMNS[3], fsource); 
        lff2value.put(LffConstants.LFF_COLUMNS[4], chromosome); 
        lff2value.put(LffConstants.LFF_COLUMNS[5], "" + this.getStart()); 
        lff2value.put(LffConstants.LFF_COLUMNS[6], "" + this.getStop()); 
        lff2value.put(LffConstants.LFF_COLUMNS[7], this.getStrand());         
        lff2value.put(LffConstants.LFF_COLUMNS[8], this.getPhase()); 
        double score = this.getScore();
        NumberFormat formatter = new DecimalFormat("#,##0.0000");
            
        fscore = formatter.format(score);
            
        lff2value.put(LffConstants.LFF_COLUMNS[9], "" + fscore); 
        lff2value.put(LffConstants.LFF_COLUMNS[10], this.tstart); 
        lff2value.put(LffConstants.LFF_COLUMNS[11], this.tstop); 
        lff2value.put(LffConstants.LFF_COLUMNS[12], this.getSequences()); 
        lff2value.put(LffConstants.LFF_COLUMNS[13], this.getComments()); 
    }
    

   
   
    public HashMap getLff2value() {
        return lff2value;
    }

    public void setLff2value(HashMap lff2value) {
        this.lff2value = lff2value;
    }


    String fscore;
    HashMap avp;

    public HashMap getAvp() {
        return avp;
    }

    public void setAvp(HashMap avp) {
        this.avp = avp;
    }

    public boolean isFlagged() {
        return flagged;
    }

    public void setFlagged(boolean flagged) {
        this.flagged = flagged;
    }
   
    boolean flagged;

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    String message;

    public String getHexAnnoColor() {
        return hexAnnoColor;
    }

    public void setHexAnnoColor(String hexAnnoColor) {
        this.hexAnnoColor = hexAnnoColor;
    }

    String hexAnnoColor;

    /**
     * String start and stop obtained from user input in jsp page
     */    

    String fstart;

    public String getFstart() {
        return fstart;
    }

    public void setFstart(String fstart) {
        this.fstart = fstart;
    }

    public String getFstop() {
        return fstop;
    }

    public void setFstop(String fstop) {
        this.fstop = fstop;
    }

    String fstop;


    int displayCode;
    int displayColor;
    char flag;

    public AnnotationDetail(int fid) {
        this.fid = fid;
        super.setStrand("+");
        super.setPhase("0");
        super.setSequences("");
        super.setComments("");
        super.setFtypeId(fid);
        trackName = "";
        gname = "";
        tstart = "n/a";
        tstop = "n/a";
        chromosome = "";
        fscore = "";
        avp = new HashMap(); 
    }

    public int getGid() {
        return gid;
    }

    public void setGid(int gid) {
        this.gid = gid;
    }

    int gid;


    public String getTrackName() {
        return trackName;
    }

    public void setTrackName(String trackName) {
        this.trackName = trackName;
    }


    public String toString() {

        return "fid " + fid + "\n"
                + "start " + getStart() + " <br>"
                + "stop " + getStop() + " <br>"
                + "strand " + getStrand() + " <br>"
                + "phase " + getPhase() + " <br>"
                + "score" + getScore() + " <br>"

                + "ftype id " + getFtypeId() + " <br>"
                + "tstart " + getTstart() + " <br>"
                + " tstop " + getTstop() + " <br>"
                + "track name " + trackName + " <br>"
                + " seq " + getSequences() + " <br>"
                + " comments " + getComments() + " <br>"
                + " fbin " + getFbin();

    }


    public int getFid() {
        return fid;
    }

    public void setFid(int fid) {
        this.fid = fid;
    }


    public String getFmethod() {
        return fmethod;
    }

    public void setFmethod(String fmethod) {
        this.fmethod = fmethod;
    }

    public String getFsource() {
        return fsource;
    }

    public void setFsource(String fsource) {
        this.fsource = fsource;
    }

    public String getGname() {
        return gname;
    }

    public void setGname(String gname) {
        this.gname = gname;
    }


    public String getTstart() {
        return tstart;
    }

    public void setTstart(String tstart) {
        this.tstart = tstart;
    }

    public String getTstop() {
        return tstop;
    }

    public void setTstop(String tstop) {
        this.tstop = tstop;
    }


    public String getFscore() {
        return fscore;
    }

    public void setFscore(String fscore) {
        this.fscore = fscore;
    }


    public String getChromosome() {
        return chromosome;
    }

    public void setChromosome(String chromosome) {
        this.chromosome = chromosome;
    }


    public long getLength() {
        return length;
    }

    public void setLength(long length) {
        this.length = length;
    }

    public int getDisplayCode() {
        return displayCode;
    }

    public void setDisplayCode(int displayCode) {
        this.displayCode = displayCode;
    }


    public int getDisplayColor() {
        return displayColor;
    }

    public void setDisplayColor(int displayColor) {
        this.displayColor = displayColor;
    }

    public char getFlag() {
        return flag;
    }

    public void setFlag(char flag) {
        this.flag = flag;
    }

 public String getGclassName() {
        return gclassName;
    }

    public void setGclassName(String gclassName) {
        this.gclassName = gclassName;
    }
    public String toXml() {
        if (message == null)
        message = "";


        StringBuffer xml = new StringBuffer();
        xml.append("<?xml version=\"1.0\"?>\n");
        xml.append("<annotation>\n");

        xml.append("<start>");
        xml.append(this.getStart());
        xml.append("</start>\n");

        xml.append("<stop>");
        xml.append(this.getStop());
        xml.append("</stop>\n");

        xml.append("<message>");
        xml.append(this.getMessage());
        xml.append("</message>\n");

        xml.append("</annotation>\n");
        return xml.toString();

    }




}
