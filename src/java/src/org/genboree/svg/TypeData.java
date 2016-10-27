package org.genboree.svg;

import org.genboree.genome.Genome;

import java.util.HashMap;

abstract public class TypeData extends AnnotationData {
     protected int typeId = 0;
    protected String type = null;
    protected String subtype = null;
    private HashMap requirements;
    protected Genome genomeInfo;
    protected String genomeFilter = null;
    protected String chromosomeFilter = null;


    public  TypeData(HashMap requirements){
            this.requirements = requirements;
            this.genomeInfo = (Genome)requirements.get(GENOMEINFO);
            this.genomeFilter = (String)requirements.get(GENOME_FILTER);
            this.chromosomeFilter = (String)requirements.get(CHROMOSOME_FILTER);
    }



    public int getTypeId() {
        return typeId;
    }

    public void setTypeId(int typeId) {
        this.typeId = typeId;
    }

    public String getType() {
        return type;
    }

    public void setType(String type) {
        this.type = type;
    }

    public String getSubtype() {
        return subtype;
    }

    public void setSubtype(String subtype) {
        this.subtype = subtype;
    }

    public void generateSVG(LocalContext localContext){
    }

    public void generateSVG(LocalContext localContext, String location){

    }

}
