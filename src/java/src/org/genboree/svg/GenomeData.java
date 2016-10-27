package org.genboree.svg;

import java.io.IOException;
import java.util.*;
import org.genboree.genome.Genome;
import org.genboree.genome.EPoint;
import org.genboree.dbaccess.VGPaint;
import org.genboree.util.SmallT;




/**
 * This class is responsible to generate the SVG image panel, which contains all the chromosomes
 * for a specific genome. The process of actually generating the SVG image for each of the chromosomes
 * are delegated to the SyntenyMapData class.
 */
abstract public class GenomeData extends SVGData {
    protected Genome genomeInfo;
    protected HashMap requirements;
    protected int refseqId = 1;
    protected double scale = 1.8107379353324962E-6;
    protected ArrayList colors = new ArrayList(24);
    protected ArrayList entrypoints = new ArrayList(24);
    protected int imageWidth = 0;
    protected int imageHeight = 0;
    protected double scaleFactor = 1.0;


    public GenomeData(HashMap requirements) {
        this.requirements = requirements;
        this.genomeInfo = (Genome)requirements.get(GENOMEINFO);
    }

    public double getScale(){
        return scale;
    }

    public void setScale(double myScale){
          scale = myScale;
    }

    protected void cacheColors() {
        //cache the color codes
        VGPaint tempVGPInfo = null;
        int ftCount = 0;
        String categoryAbb = null;
        colors.clear();
        tempVGPInfo = genomeInfo.getVgp();
        ftCount = tempVGPInfo.getFtypeCount();
        for(int ft = 0; ft < ftCount; ft++){
            VGPaint.VGPFtype myFtype = tempVGPInfo.getFtypeAt(ft);
            if(myFtype ==null)
                continue;
            String nameId = "" + ft;
            lc.putColorValue(nameId, myFtype.getAbbreviation());
            lc.putColorCode(nameId, myFtype.getColor());
            categoryAbb= tempVGPInfo.getFcategoryAt(myFtype.getOrientation()).getAbbreviation();
            lc.putColorCategory(nameId, categoryAbb);
            colors.add(nameId);
        }

    }

    public long getEpointSize(String abb){
        Iterator epIterat;
        epIterat =  genomeInfo.getEPoints().iterator();

        while(epIterat.hasNext())
        {
             EPoint epoint   =  (EPoint)epIterat.next();
            if(epoint.getAbbreviation().equalsIgnoreCase(abb))
                return epoint.getSize();
        }
         return 0;
    }


    protected void loadChromosomes(String typeLoad){
        long maxEntrypointSize = 0;
        long  maxTemplateSize = 444;
        String refseqSpecie = null;
        ArrayList epoints;
        boolean templateExist = false;
        Iterator epIterat;
        if(SmallT.getDebug() > 0){
//        if(typeLoad.equalsIgnoreCase("full"))
//            maxEntrypointSize = genomeInfo.getSizeBiggestEntryPoint();
//        else
        System.err.println("Before the getBiggestVissibleEntryPoint()");
        System.err.flush();
        }
        maxEntrypointSize = genomeInfo.getSizeBiggestVisibleEntryPoint();
        if(SmallT.getDebug() > 0){
        System.err.println("When type = " + typeLoad +" the maxEntryPointSize =" + maxEntrypointSize);
        System.err.flush();
        }

        try{
            if(typeLoad.equalsIgnoreCase("full"))
                maxTemplateSize = genomeInfo.getSizeBiggestVisibleChromosomeTemplate();
            else
                maxTemplateSize = genomeInfo.getGenomeTemplate().getMaxTemplateLength();
        if(SmallT.getDebug() > 0){
            System.err.println("When type = " + typeLoad +" the maxTemplateSize =" + maxTemplateSize);
            System.err.flush();
        }
            if(maxTemplateSize > 0)
                templateExist = true;
        }    catch (Exception ex) {
            System.err.println("The template is problably null ");
            ex.printStackTrace();
        }
        refseqSpecie = genomeInfo.getSpecies();
        cacheColors();

        if(!templateExist)
            maxTemplateSize = 444;

        setScale((double)(maxTemplateSize * scaleFactor / maxEntrypointSize));

        if(SmallT.getDebug() > 0){
            System.err.println("The scale is " + scale);
            System.err.println("the maxTemplateSize is " + maxTemplateSize);
            System.err.println("the maxEntryPointSize is " + maxEntrypointSize);
            System.err.flush();
        }
         //TODO test this method 010603
        //TODO set default for the scale maybe 1.8088782437005135E-6   need to recalculate

        epoints = genomeInfo.getEPoints();
        epIterat = epoints.iterator();

        while(epIterat.hasNext())
        {
            SyntenyMapData entrypoint = ImageDrawingFactory.getSyntenyMapDataObject(lc.getImageType(),requirements);
            EPoint epoint   =  (EPoint)epIterat.next();
            if(epoint.getDisplay())
            {
                entrypoint.setEntrypointId(epoint.getId());
                entrypoint.setEntrypointName(epoint.getName());
                entrypoint.setEntryPointAbb(epoint.getAbbreviation());
                entrypoint.setEntrypointType(epoint.getEntryPointType());
                entrypoint.setEntrypointSize((int)epoint.getSize());
                entrypoint.setLinkId(1);
                entrypoint.setRefseqId(epoint.getGenome().getRefSeqId());
                entrypoint.setRefseqSpecies(refseqSpecie);
                //also pass the max entrypoint size, max template sie, and the scale calculated
                entrypoint.setMaxEntrypointSize((int)maxEntrypointSize);
                entrypoint.setMaxTemplateSize((int)maxTemplateSize);
                entrypoint.setScale(scale);

                entrypoints.add(entrypoint);
            }
        }
    }

    public String getEPAbFromName(String name){
        Iterator epIterat;

        ArrayList epoints = genomeInfo.getEPoints();
        epIterat = epoints.iterator();

        while(epIterat.hasNext())
        {

            EPoint epoint   =  (EPoint)epIterat.next();
            String tempName = epoint.getName();
//            System.err.println("The name is " + tempName + " and the abb is " + epoint.getAbbreviation());
            if(tempName.equalsIgnoreCase(name))
                return epoint.getAbbreviation();
        }

        return null;
    }

    protected void appendSVGHeader() {
        //svg header
        lc.appendConfigValue("image_settings/common/svg_header");
        lc.appendLineFeed();
        lc.appendLineFeed();
    }

    protected void appendSVGStyle(String path) throws IOException {
        //add the style tag
        lc.appendLineFeed();
        lc.append("<style type=\"text/css\"><![CDATA[");
        lc.appendLineFeed();
        lc.append(lc.getFileContentAsString(lc.getConfigValue(path)));
        lc.appendLineFeed();
        lc.append("]]></style>");
        lc.appendLineFeed();
    }

    protected void appendSVGScript(String path) throws IOException {
        lc.appendLineFeed();
        lc.append("<script type=\"text/ecmascript\"><![CDATA[");
        lc.appendLineFeed();
        lc.append(lc.getFileContentAsString(lc.getConfigValue(path)));
        lc.appendLineFeed();
        lc.append("]]></script>");
        lc.appendLineFeed();
    }

    public int getRefseqId() {
        return refseqId;
    }

    public void setRefseqId(int refseqId) {
        this.refseqId = refseqId;
    }

    public int getImageWidth() {
        return imageWidth;
    }

    public int getImageHeight() {
        return imageHeight;
    }
}
