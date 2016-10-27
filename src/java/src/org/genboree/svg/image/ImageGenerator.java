package org.genboree.svg.image;

import org.genboree.svg.Constants;
import java.util.HashMap;
import java.util.ArrayList;
import java.util.Iterator;
import java.io.FileOutputStream;
import java.io.IOException;
import java.sql.SQLException;

import org.genboree.genome.Genome;
import org.genboree.genome.EPoint;
import org.genboree.dbaccess.VGPaint;
import org.xml.sax.SAXException;
import javax.xml.parsers.ParserConfigurationException;



public class ImageGenerator implements Constants{
    private String dir = null;
    private String chromosome = null;
    private String xmlFile = null;
    private String graphicFileName = null;
    private String format = null;
    private Genome genomeInfo = null;
    private String baseName = null;
    private String svgFileName = null;
    private HashMap requirements;
    private ArrayList chromosomeList;
    private Image image = null;
    private FileOutputStream fout = null;
    private Iterator epIterat;
    /* Use the regularDisplay flag to run all the displays = true or only one chromosome = false*/
    private boolean regularDisplay = true;
    private boolean onlyGenomic = false;
    private String specificChromosomeName = "16";
    private static final String FS = System.getProperty("file.separator");

    public ImageGenerator(Genome genomeInfo, String directory){
        setDir(directory);
        setGenomeInfo(genomeInfo);
        generateVGPS();
    }
    public ImageGenerator(VGPaint myvgp, int userPid, String directory) throws SQLException {
        this(new Genome(myvgp, userPid), directory);
    }

    public ImageGenerator(int userPid, String xmlFileName, String directory) throws SAXException, IOException, ParserConfigurationException, SQLException{
        this(new Genome(userPid, xmlFileName), directory);
    }


     public ImageGenerator(int userPid, String xmlFileName, String directory, boolean genomeOnly) throws SAXException, IOException, ParserConfigurationException, SQLException{
        setOnlyGenomic(genomeOnly);
        setDir(directory);
        setGenomeInfo(new Genome(userPid, xmlFileName));
        generateVGPS();
    }

    public ImageGenerator(int userPid, String xmlFileName, String directory, boolean regular, String chromToSee)throws SAXException, IOException, ParserConfigurationException, SQLException{
        setRegularDisplay(regular);
        setSpecificChromosomeName(chromToSee);
        setDir(directory);
        setGenomeInfo(new Genome(userPid, xmlFileName));
        generateVGPS();
    }

    public void setSpecificChromosomeName(String myName){
        specificChromosomeName = myName;
    }

    public void setOnlyGenomic(boolean genomicOnly){
        onlyGenomic = genomicOnly;
    }

    public boolean getOnlyGenomic(){
        return onlyGenomic;
    }

    public void setRegularDisplay(boolean regular){
        regularDisplay = regular;
    }

    public void setDir(String theDirectory){
        this.dir = theDirectory;
    }


    public void setGenomeInfo(Genome myGenomeInfo){
        this.genomeInfo = myGenomeInfo;
    }


    public void setFormat(String theFormat){
        this.format = theFormat;
    }

    public void setBaseName(){
        this.baseName = this.dir + (this.dir.endsWith("\\") ? "" : FS);
    }


    public void generateVGPS(){

        this.requirements = new HashMap();


        if(this.genomeInfo == null){
            return;
        }
        else
            this.requirements.put(GENOMEINFO, this.genomeInfo);


        setFormat("svg");
        setBaseName();

        this.baseName = this.dir + (this.dir.endsWith("\\") ? "" : FS);
        this.graphicFileName = this.baseName + "refSeq.svg";
        this.requirements.put(SVG_FILE_ABSOLUTE_NAME, this.svgFileName);
        this.requirements.put(HTTP_PARAM_SVGTYPE, TYPE_COMPACT);
        this.requirements.put(GENOME_FILTER, "_GV");
        this.requirements.put(CHROMOSOME_FILTER, "_CV");
//         this.requirements.put(GENOME_FILTER, "");
//         this.requirements.put(CHROMOSOME_FILTER, "");
        if(regularDisplay){
            try {
                this.image = ImageFactory.generateImage(this.requirements);
                this.fout = new FileOutputStream(this.graphicFileName);
                this.image.serveImage(this.fout, this.requirements);
                this.fout.close();
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
        if(getOnlyGenomic())
            return;

        chromosomeList = genomeInfo.getEPoints();
        epIterat = chromosomeList.iterator();


        while(epIterat.hasNext())
        {
            EPoint epoint   =  (EPoint)epIterat.next();
            if(epoint.getDisplay())
            {
                this.graphicFileName = this.baseName + "EP" + epoint.getAbbreviation()  + ".svg";
                this.requirements.remove(SVG_FILE_ABSOLUTE_NAME);
                this.requirements.put(SVG_FILE_ABSOLUTE_NAME, this.svgFileName);
                this.chromosome = epoint.getAbbreviation();
                this.requirements.put(HTTP_PARAM_CHROMOSOME, this.chromosome);
                this.requirements.remove(HTTP_PARAM_SVGTYPE);
                this.requirements.put(HTTP_PARAM_SVGTYPE, TYPE_SINGLE_CHROMOSOME);

                if(regularDisplay){
                    try {
                        this.image = ImageFactory.generateImage(this.requirements);
                        this.fout = new FileOutputStream(this.graphicFileName);
                        this.image.serveImage(this.fout, this.requirements);
                        this.fout.close();
                    } catch (IOException e1) {
                        e1.printStackTrace();
                    }
                }
                else {
                    if( epoint.getAbbreviation().compareToIgnoreCase(specificChromosomeName) == 0){
                        try {
                            this.image = ImageFactory.generateImage(this.requirements);
                            this.fout = new FileOutputStream(this.graphicFileName);
                            this.image.serveImage(this.fout, this.requirements);
                            this.fout.close();
                        } catch (IOException e1) {
                            e1.printStackTrace();
                        }
                    }
                }
            }
        }
    }

}
