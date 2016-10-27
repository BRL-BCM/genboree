package org.genboree.svg.full;

import org.genboree.svg.LocalContext;
import org.genboree.svg.TemplateData;
import org.genboree.genome.Genome;
import org.genboree.genome.EPoint;
import org.genboree.genome.ChromosomeTemplate;
import java.util.HashMap;

/**
 * Created By: Alan
 * Date: Apr 12, 2003 10:26:45 PM
 */
public class FullChromosomesTemplateData extends TemplateData {
    private FullChromosomesImageRequirements fir = null;
    private HashMap requirements;

    public FullChromosomesTemplateData(HashMap requirements){
        this.requirements = requirements;
    }


    public void generateSVG(LocalContext localContext) {
        lc = localContext;
        fir = (FullChromosomesImageRequirements) lc.getImageRequirements();

        int templateX = fir.getChromosomePanelInternalPaddingLeft() + fir.getAnnotationBoxWidthLeft();
        int topMargin = !lc.singleChromosomeOnly() ? fir.getChromosomePanelInternalPaddingTop() : fir.isChromosomeLabelVisible() ? fir.getChromosomePanelInternalPaddingTop() : 0;
        String chromName = null;
        boolean templateExist = false;

        /*
        ftemplate_length, ftemplate_box_size
        */
        int chromLength = 0;
        int boxLength = 0;
//        int lowerMargin = 15;
//        String bigTemplate = null;
        String templateData = null;
        String symbolId = "defaultChromosome";
        //draw the label
        if (fir.isChromosomeLabelVisible()) {
            int labelX = fir.getChromosomePanelInternalPaddingLeft() + fir.getAnnotationBoxWidthLeft() + fir.getAnnotationBoxWidthCenter() / 2;
            drawLabel(labelX, fir.getChromosomePanelInternalPaddingTop() / 5 * 4, labelLineOne, CSS_ANNOTATION_TITLE, null);
//TODO add more lables
//           drawLabel(labelX, fir.getChromosomePanelInternalPaddingTop() / 5 * 4, labelLineTwo, CSS_ANNOTATION_TITLE, null);
        }
                //retrieve the center SVG data
        Genome genomeInfo = (Genome)requirements.get(GENOMEINFO);
        EPoint currentEP =  genomeInfo.getEpoint(this.getEntrypointId());
        try{
            ChromosomeTemplate currentChTempl = currentEP.getChromosomeTemplate();
            if(currentChTempl != null){
                templateExist = true;
                templateData = currentChTempl.getChromosomeTemplateData();
                symbolId = currentChTempl.getChromosomeTemplateSymbolId();
                chromName = currentChTempl.getChromosomeTemplateChromName();
                chromLength = currentChTempl.getChromosomeTemplateLength();
                boxLength = currentChTempl.getChromosomeTemplateBoxSize();
            }
            else{
                    templateExist = false;
                    boxLength = (int)(currentEP.getSize() * scale) + 50;
                    chromLength = (int)(currentEP.getSize() * scale);
                }
        }catch( Exception ex1 ) {
            System.err.println("Catched exception in FullChromosome");
            System.err.flush();
        }


         int viewBoxPosition = 600 - boxLength;
        //append the template SVG
        int width = fir.getAnnotationBoxWidthCenter(), height = fir.getAnnotationBoxesHeight();
        //for single chromosome, we'd like to truncate the whitespaces
        int viewBoxHeight = lc.singleChromosomeOnly() ? getTemplateBoxSize() : height;

        lc.appendTagStart("svg");
        lc.appendTagLocationSizeAttributes(templateX, topMargin, width, viewBoxHeight);
        lc.appendTagAttribute("viewBox", createViewBoxString(width, viewBoxHeight));
        lc.appendTagAttribute("preserveAspectRatio", "xMidYMin meet");
        lc.appendTagStartEnd();

        lc.appendTagStart("svg");
        lc.appendTagAttribute("width", 150);
        lc.appendTagAttribute("height", boxLength);
        lc.appendTagAttribute("viewBox", createViewBoxString(0,viewBoxPosition, 150, boxLength));
        lc.appendTagStartEnd();

        lc.append(templateData);
        lc.appendTagStart("defs");
        lc.appendTagStartEnd();
        lc.appendTagStart("clipPath");
        lc.appendTagAttribute("id", "rectClip");
        lc.appendTagStartEnd();

        int clipYPosition =  (600 - (chromLength + 15 + 2));
        if(clipYPosition > 130 && clipYPosition < 137)
            clipYPosition = 130;
        else if(clipYPosition > 221 && clipYPosition < 228)
            clipYPosition = 220;
        else if(clipYPosition > 310 && clipYPosition < 317)
            clipYPosition = 310;
        else if(clipYPosition > 401 && clipYPosition < 408)
            clipYPosition = 400;
        else if(clipYPosition > 491 && clipYPosition < 498)
            clipYPosition = 490;


        lc.appendTagStart("rect");
        lc.appendTagAttribute("x", 0);
        lc.appendTagAttribute("y", clipYPosition);
        lc.appendTagAttribute("width", 150);
        lc.appendTagAttribute("height", (chromLength + 15));
        lc.appendTagAttribute("style", "stroke:gray; fill:none;");
        lc.append(" /");
        lc.appendTagStartEnd();

        lc.appendTagClose("clipPath");
        lc.appendTagClose("defs");

        lc.appendTagStart("g");
        lc.appendTagAttribute("style", "clip-path:url(#rectClip);");
        lc.appendTagStartEnd();

        lc.appendTagStart("use");
        //TODO need a method to draw a ruler
        if(currentEP.getSize() <= 500000)
            lc.appendTagAttribute("xlink:href", "#ruler05MB");
        else if(currentEP.getSize() <= 3200000 && currentEP.getSize() > 500000)
            lc.appendTagAttribute("xlink:href", "#ruler3MB");
        else if(currentEP.getSize() <= 5000000 && currentEP.getSize() > 3200000)
            lc.appendTagAttribute("xlink:href", "#ruler5MB");
        else if(currentEP.getSize() <= 7000000 && currentEP.getSize() > 5000000)
            lc.appendTagAttribute("xlink:href", "#ruler7MB");
        else if(currentEP.getSize() <= 11000000 && currentEP.getSize() > 7000000)
            lc.appendTagAttribute("xlink:href", "#ruler9MB");
        else if(currentEP.getSize() <= 13000000 && currentEP.getSize() > 11000000)
            lc.appendTagAttribute("xlink:href", "#ruler12MB");
        else if(currentEP.getSize() <= 190000000 && currentEP.getSize() > 13000000)
            lc.appendTagAttribute("xlink:href", "#ruler150MB");
        else
            lc.appendTagAttribute("xlink:href", "#ruler");
        lc.appendTagAttribute("x", 10);
        lc.appendTagAttribute("y", 0);
        lc.appendTagAttribute("width", 60);
        lc.appendTagAttribute("height", 600);
        lc.append(" /");
        lc.appendTagStartEnd();
//TODO for templates
        if(templateExist){
            lc.appendTagStart("use");
            lc.appendTagAttribute("xlink:href", "#" + symbolId);
            lc.appendTagAttribute("x", 70);
            lc.appendTagAttribute("y", 0);
            lc.appendTagAttribute("width", 60);
            lc.appendTagAttribute("height", 600);
            lc.append(" /");
            lc.appendTagStartEnd();
        }

        lc.appendTagClose("g");
        lc.appendTagClose("svg");
        lc.appendTagClose("svg");

    if (lc.isDebug())
            lc.append("<rect x=\"" + templateX + "\" y=\"" + fir.getChromosomePanelInternalPaddingTop() + "\" width=\"" + width + "\" height=\"" + viewBoxHeight + "\" stroke=\"blue\" fill=\"none\"/>\n");

    }
}
