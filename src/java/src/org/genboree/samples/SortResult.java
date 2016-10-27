package org.genboree.samples;

import java.util.HashMap;

/**
 * User: tong
 * Date: Dec 14, 2006
 * Time: 1:00:42 PM
 */
 public     class SortResult  {
       int dataType = 0;

    public int getDataType() {
        return dataType;
    }

    public void setDataType(int dataType) {
        this.dataType = dataType;
    }

    public int[] getSampleOrder() {
        return sampleOrder;
    }

    public void setSampleOrder(int[] sampleOrder) {
        this.sampleOrder = sampleOrder;
    }

    public HashMap getValue2Samples() {
        return value2Samples;
    }

    public void setValue2Samples(HashMap value2Samples) {
        this.value2Samples = value2Samples;
    }

    public HashMap getDataType2sortedData() {
        return dataType2sortedData;
    }

    public void setDataType2sortedData(HashMap dataType2sortedData) {
        this.dataType2sortedData = dataType2sortedData;
    }

    int [] sampleOrder;   
       HashMap value2Samples; 
       HashMap dataType2sortedData;          
    }
       
