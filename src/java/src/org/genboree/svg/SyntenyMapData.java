package org.genboree.svg;

import org.genboree.genome.Genome;
import java.util.HashMap;

/**
 * This class is responsible for generating the SVG for a specific chromosome.
 */
abstract public class SyntenyMapData extends SVGData {

    protected static final String LINK_START_PATTERN = "$start";
    protected static final String LINK_END_PATTERN = "$stop";
    protected int templateBoxSize = 0;
    protected Genome genomeInfo;
    protected HashMap requirements;

    public SyntenyMapData(HashMap requirements) {
        this.requirements = requirements;
        this.genomeInfo = (Genome)requirements.get(GENOMEINFO);
    }

    //columns defined in the fentrypoint table
    protected int entrypointId = 0;
    protected String entrypointName = null;
    protected String entrypointType = null;
    protected String entryPointAbb = null;
    protected int entrypointSize = 0;
    protected int linkId = 0;
    protected int refseqId = 0;
    protected String refseqSpecies = null;

    protected int csX = 0;
    protected int csY = 0;
    protected int csWidth = 0;
    protected int csHeight = 0;

    protected double scale = 0;
    protected int maxEntrypointSize = 0;
    protected int maxTemplateSize = 0;

    protected String linkName = "Link Name";
    protected String linkHref = null;
    protected int linkTimes = 4;

    /**
     * Generates the SVG data for a single chromosome synteny map.
     * @param localContext
     */
    abstract public void generateSVG(LocalContext localContext);

    protected void setFields(AnnotationData typeData) {
        typeData.setEntrypointId(entrypointId);
        typeData.setEntrypointSize(entrypointSize);
        typeData.setScale(scale);
        typeData.setMaxEntrypointSize(maxEntrypointSize);
        typeData.setMaxTemplateSize(maxTemplateSize);
    }

    public Genome getGenomeInfo(){
        return genomeInfo;
    }

    public HashMap getRequirements(){
        return requirements;
    }

    public int getEntrypointId() {
        return entrypointId;
    }

    public String getEntryPointAbb(){
        return this.entryPointAbb;
    }

    public void setEntryPointAbb(String abbreviation){
        this.entryPointAbb = abbreviation;
    }

    public void setEntrypointId(int entrypointId) {
        this.entrypointId = entrypointId;
    }

    public String getEntrypointName() {
        return entrypointName;
    }

    public void setEntrypointName(String entrypointName) {
        this.entrypointName = entrypointName;
    }

    public String getEntrypointType() {
        return entrypointType;
    }

    public void setEntrypointType(String entrypointType) {
        this.entrypointType = entrypointType;
    }

    public int getEntrypointSize() {
        return entrypointSize;
    }

    public void setEntrypointSize(int entrypointSize) {
        this.entrypointSize = entrypointSize;
    }

    public int getLinkId() {
        return linkId;
    }

    public void setLinkId(int linkId) {
        this.linkId = linkId;
    }

    public double getScale() {
        return scale;
    }

    public void setScale(double scale) {
        this.scale = scale;
    }

    public int getMaxEntrypointSize() {
        return maxEntrypointSize;
    }

    public void setMaxEntrypointSize(int maxEntrypointSize) {
        this.maxEntrypointSize = maxEntrypointSize;
    }

    public int getMaxTemplateSize() {
        return maxTemplateSize;
    }

    public void setMaxTemplateSize(int maxTemplateSize) {
        this.maxTemplateSize = maxTemplateSize;
    }

    public int getRefseqId() {
        return refseqId;
    }

    public void setRefseqId(int refseqId) {
        this.refseqId = refseqId;
    }

    public String getRefseqSpecies() {
        return refseqSpecies;
    }

    public void setRefseqSpecies(String refseqSpecies) {
        this.refseqSpecies = refseqSpecies;
    }

    public int getCsX() {
        return csX;
    }

    public void setCsX(int csX) {
        this.csX = csX;
    }

    public int getCsY() {
        return csY;
    }

    public void setCsY(int csY) {
        this.csY = csY;
    }

    public int getCsWidth() {
        return csWidth;
    }

    public void setCsWidth(int csWidth) {
        this.csWidth = csWidth;
    }

    public int getCsHeight() {
        return csHeight;
    }

    public void setCsHeight(int csHeight) {
        this.csHeight = csHeight;
    }

    public void setTemplateBoxSize(int templateBoxSize) {
        this.templateBoxSize = templateBoxSize;
    }
}
