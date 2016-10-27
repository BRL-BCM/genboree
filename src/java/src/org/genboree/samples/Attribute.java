package org.genboree.samples;

/**
 * A Entity class desgined for samples attributes
 * each attribute has a name, id, value and an index for setting  view display order
 * User: tong
 * Date: Nov 9, 2006
 * Time: 4:32:08 PM
 */
public class Attribute {    
    private int attributeId ;
    private String attributeName;
    private String attributeValue;
    private int index; 
       public int getIndex() {
           return index;
       }

       public void setIndex(int index) {
           this.index = index;
       }

       public int getAttributeId() {
           return attributeId;
       }

       public void setAttributeId(int attributeId) {
           this.attributeId = attributeId;
       }

       public String getAttributeName() {
           return attributeName;
       }

       public void setAttributeName(String attributeName) {
           this.attributeName = attributeName;
       }

       public String getAttributeValue() {
           return attributeValue;
       }

       public void setAttributeValue(String attributeValue) {
           this.attributeValue = attributeValue;
       }
}
