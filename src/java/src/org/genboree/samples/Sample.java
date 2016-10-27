package org.genboree.samples;

/**
 * Entity Java class for sample upload, download and view
 * A sample contains a name, an id, and a set of attributes, which has name, id, and values
 * User: tong
 * Date: Nov 9, 2006
 * Time: 4:31:19 PM
 * @see Attribute class 
 */
public class Sample {
    private int sampleId;
    private String sampleName;
    private Attribute [] attributes;  
        
    public int getSampleId() {
    return sampleId;
    }
    
    public void setSampleId(int sampleId) {
    this.sampleId = sampleId;
    }
    
    public String getSampleName() {
    return sampleName;
    }
    
    public void setSampleName(String sampleName) {
    this.sampleName = sampleName;
    }
    
    public Attribute[] getAttributes() {
    return attributes;
    }
    
    public void setAttributes(Attribute[] attributes) {
    this.attributes = attributes;
    }                   
}
