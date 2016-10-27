package org.genboree.tabular;

import org.genboree.editor.Chromosome;
import org.genboree.util.Util;

/**
 * User: tong
 * Date: Jun 27, 2007
 * Time: 10:36:19 AM
 */
public class URLParams {
    String chr ; 
    String trackNames; 
    String layoutName; 
    String chrStart; 
    String chrStop;   
    String [] trackNameArr; 
    Chromosome chromosome;
    String groupId;

    public String getGroupId() {
        return groupId;
    }

    public void setGroupId(String groupId) {
        this.groupId = groupId;
    }

    public String getRefseqId() {
        return refseqId;
    }

    public void setRefseqId(String refseqId) {
        this.refseqId = refseqId;
    }

    String refseqId; 
    

    public Chromosome getChromosome() {
        return chromosome;
    }

    public void setChromosome(Chromosome chromosome) {
        this.chromosome = chromosome;
    }

    public boolean isHasError() {
        return hasError;
    }

    public void setHasError(boolean hasError) {
        this.hasError = hasError;
    }

    public String getErrorMessage() {
        return errorMessage;
    }

    public void setErrorMessage(String errorMessage) {
        this.errorMessage = errorMessage;
    }

    boolean hasError ; 
    String errorMessage; 
    
    public URLParams () {
        
      }
        
    
    
    public URLParams (String layout, String tracks, String chr, String chrStart, String chrStop) {
        this.chr = chr; 
        this.chrStart = chrStart; 
        this.chrStop = chrStop; 
       // this.chromosome  = new Chromosome (chr, chrStart, chrStop);         
        this.layoutName = layout; 
        if (tracks != null) {
        this.trackNames = tracks; 
        parseTracks (tracks); 
        }        
    }
    
     
    public void parseTracks (String tracks ) {    
        this.trackNameArr = trackNames.split(",");
    }
        
  
    public String getChr() {
        return chr;
    }

    public void setChr(String chr) {
        this.chr = chr;
    }

    public String getTrackNames() {
        return trackNames;
    }

    public void setTrackNames(String trackNames) {
        this.trackNames = trackNames;
    }

    public String getLayoutName() {
        return layoutName;
    }

    public void setLayoutName(String layoutName) {
        this.layoutName = layoutName;
    }

    public String getChrStart() {
        return chrStart;
    }

    public void setChrStart(String chrStart) {
        this.chrStart = chrStart;
    }

    public String getChrStop() {
        return chrStop;
    }

    public void setChrStop(String chrStop) {
        this.chrStop = chrStop;
    }

 
    public String[] getTrackNameArr() {
        return trackNameArr;
    }

    public void setTrackNameArr(String[] trackNameArr) {
        this.trackNameArr = trackNameArr;
    }

    
  public  void decode () {
     
    if ( this.chr != null) {
        this.chr = Util.urlDecode(this.chr); 
        this.chr.trim(); 
    }
      
    if (this.chrStart != null) {
        this.chrStart = Util.urlDecode(this.chrStart);  
        this.chrStart.trim(); 
        this.chrStart.replaceAll(",", ""); 
   
    } 
    
    if (this.chrStop != null) {
        this.chrStop = Util.urlDecode(this.chrStop); 
        this.chrStop.trim();
        this.chrStop.replaceAll(",", ""); 
    }
      
    if (  this.layoutName != null) {
        this.layoutName = Util.urlDecode(this.layoutName); 
        this.layoutName.trim();
    }
    
    if (this.trackNames != null) {
        this.trackNames = Util.urlDecode(this.trackNames); 
        this.trackNames.trim();
        parseTracks (this.trackNames); 
    } 
  }
 
}
