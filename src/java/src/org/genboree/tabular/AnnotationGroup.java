package org.genboree.tabular;

import org.genboree.editor.Chromosome;
import org.genboree.editor.AnnotationDetail;
import org.genboree.dbaccess.DbFtype;

import java.util.HashMap;

/**
 * User: tong
 * Date: Jun 13, 2007
 * Time: 1:17:37 PM
 */
public class AnnotationGroup  extends AnnotationDetail  {    
  
        Chromosome chromosome;  // chromosome start and end and length and id 
        DbFtype track;  // track type, subtype, id, trackname  
        long groupLength;  // calculated from max - min +1
        AnnotationDetail [] annos;   
        HashMap groupAttribute; // concatened from all member annotation, 
        HashMap groupName2Fids ;  


    public long getGroupLength() {
        return groupLength;
    }

    public void setGroupLength(long groupLength) {
        this.groupLength = groupLength;
    }

    public AnnotationDetail[] getAnnos() {
        return annos;
    }

    public void setAnnos(AnnotationDetail[] annos) {
        this.annos = annos;
    }

    public HashMap getGroupAttribute() {
        return groupAttribute;
    }

    public void setGroupAttribute(HashMap groupAttribute) {
        this.groupAttribute = groupAttribute;
    }

  
    public HashMap getGroupName2Fids() {
        return groupName2Fids;
    }

    public void setGroupName2Fids(HashMap groupName2Fids) {
        this.groupName2Fids = groupName2Fids;
    }

  
}
