package org.genboree.svg.full;

import org.genboree.svg.GenomeData;
import org.genboree.svg.LocalContext;
import org.genboree.svg.SyntenyMapData;
import org.genboree.svg.imagemap.SVGLinkTree;
import org.genboree.svg.imagemap.SVGNode;
import java.io.IOException;
import java.util.HashMap;
import org.genboree.util.SmallT;
import org.genboree.genome.ChromosomeTemplate;


/**
 * Created By: Alan
 * Date: Apr 12, 2003 10:25:24 PM
 */
public class FullChromosomesGenomeData extends GenomeData {

    private static final int PANELS_PER_ROW = 5;
    private FullChromosomesImageRequirements fir = null;
    /* this query is part of the genome class */
    private int templateBoxSize = 0;
    private  ChromosomeTemplate temporaryTemplate = null;
    private long tempEPSize = 0;
    public FullChromosomesGenomeData(HashMap requirements){
        super(requirements);
    }

    /**
     * Generates the SVG data for a specie.
     * @param localContext
     */
    public void generateSVG(LocalContext localContext) throws IOException {
        lc = localContext;
        fir = (FullChromosomesImageRequirements) lc.getImageRequirements();
        imageWidth = fir.getImageWidth();
        imageHeight = fir.getImageHeight();

        loadChromosomes("full");
        if (lc.singleChromosomeOnly()) {
            //pre-fetch the templateBoxSize so we can determine the height of the whole SVG image
            //TODO set default value
            retrieveTemplateBoxSize();
            int padding = fir.isChromosomeLabelVisible() ? fir.getChromosomePanelInternalPaddingTop() : 0;
            imageHeight = templateBoxSize + padding + fir.getAnnotationBoxInternalPaddingTop();
        }
        appendSVGHeader();

        //the outmost svg element
        lc.append("<svg");  //do not use the appendTagStart() since no need to indent the root element
        lc.appendTagAttribute("id", "root"); //id is used in the animation
        lc.appendTagAttribute("x", 0);
        lc.appendTagAttribute("y", 0);
        lc.appendTagAttribute("width", imageWidth);
        lc.appendTagAttribute("height", imageHeight);
//        lc.appendTagAttribute("height", fir.getImageHeight());
        lc.appendTagAttribute("viewBox", createViewBoxString(imageWidth, imageHeight));
        lc.appendLineFeed();

        if (lc.willRasterizeGif()) {
            SVGLinkTree linkTree = new SVGLinkTree(
                    new SVGNode(0, 0, imageWidth, imageHeight,
                            0, 0, imageWidth, imageHeight));
            lc.setSvgLinkTree(linkTree);
        }

        if (!lc.singleChromosomeOnly()) //animation is only when all chromosomes are displayed
            lc.append(" onmousedown='startAnimation()'");

        lc.appendTagStartEnd();
        lc.appendLineFeed();

        //append the includes, which are some statically defined svg elements
        lc.appendLineFeed();
        lc.append(lc.getFileContentAsString(lc.getConfigValue("image_settings/full/external_files/includes")));
        lc.appendLineFeed();
        lc.appendLineFeed();
/*
//append the custom menu
if (!lc.willRasterizeGif()) {
lc.appendLineFeed();
lc.append(lc.getFileContentAsString(lc.getConfigValue("image_settings/full/external_files/menu")));
lc.appendLineFeed();
lc.appendLineFeed();
}
*/

        //load style
        appendSVGStyle("image_settings/full/external_files/style");

        //add the script tag
        appendSVGScript("image_settings/full/external_files/script");

        //generate SVG for each of the chromosomes
        generateChromosomesSVG();

        //create the color legend box
        createColorLegend();

        //close up the svg document
        lc.appendTagClose("svg");

        //cache the svg doc
//        cacheSVG();
    }

    private void retrieveTemplateBoxSize(){
        String chrom = lc.getChromosome();


        try{
            temporaryTemplate = genomeInfo.getEpointFromAbb(chrom).getChromosomeTemplate();
        }catch( Exception ex1 ) {
           System.err.println("Exeption on FullChromosomesGenomeData line 114");
           System.err.flush();
        }

        if(temporaryTemplate != null)
            templateBoxSize = temporaryTemplate.getChromosomeTemplateBoxSize();
        else{
            templateBoxSize = 490;//550;
            tempEPSize = this.getEpointSize(chrom);
            setScale((double)(templateBoxSize - 50)/tempEPSize);
//            System.err.println("the size of " + chrom + " is " + tempEPSize);
      //      templateBoxSize = (int)(genomeInfo.getEpointFromAbb(chrom).getSize() * scale) + 50;
//            System.err.println("In here the temporary template is null the scale is " + getScale() + " and the templateBoxSize is " + templateBoxSize);
//            System.err.flush();
 // TODO something like this --->     templateBoxSize = 550;
        }
    }


    private void generateChromosomesSVG() {
//        int size = entrypoints.size();
//        int rows = size / PANELS_PER_ROW + (size % PANELS_PER_ROW > 0 ? 1 : 0);

        int csWidth = 0, csHeight = 0;
        if (lc.singleChromosomeOnly()) {
            csWidth = fir.getImageWidth();
            csHeight = imageHeight;
        } else {
            csWidth = fir.getImageWidth() / PANELS_PER_ROW;
//        int csHeight = fir.getImageHeight() / rows;
            csHeight = fir.getImageHeight() / 5;
        }
        int x = 0, y = 0;
        for (int i = 0; i < entrypoints.size(); i++) {
            SyntenyMapData entrypoint = (SyntenyMapData) entrypoints.get(i);
            if (lc.singleChromosomeOnly() && !entrypoint.getEntryPointAbb().equals(lc.getChromosome()))
                continue;
            entrypoint.setTemplateBoxSize(templateBoxSize);
            if(temporaryTemplate == null){
                entrypoint.setScale(getScale());
            }
            entrypoint.setCsX(x);
            entrypoint.setCsY(y);
            entrypoint.setCsWidth(csWidth);
            entrypoint.setCsHeight(csHeight);
            entrypoint.generateSVG(lc);
            x += csWidth;
            if (x > csWidth * (PANELS_PER_ROW - 1)) { //advance to the next line
                x = 0;
                y += csHeight;
            }
        }
    }

    protected void createColorLegend() {
        //create a svg element for the color legend
        lc.appendTagStart("svg");
        lc.appendTagAttribute("id", "colorLegend");
        lc.appendTagAttribute("x", fir.getImageWidth() - fir.getColorLegendExternalPadding() - fir.getColorLegendWidth());
        lc.appendTagAttribute("y", imageHeight - fir.getColorLegendExternalPadding() - fir.getColorLegendHeight());
        lc.appendTagAttribute("width", fir.getColorLegendWidth());
        lc.appendTagAttribute("height", fir.getColorLegendHeight());
        lc.appendTagAttribute("viewBox", createViewBoxString(fir.getColorLegendWidth(), fir.getColorLegendHeight()));
        lc.appendTagStartEnd();

        if (fir.isColorLegendVisible() && !lc.willRasterizeGif()) {
//draw the title bar
            drawColorLegendTitle();

//draw the color boxes
            drawColorLegendLegendbox();
        }

        lc.appendTagClose("svg");
    }

    protected void drawColorLegendLegendbox() {
        //group together
        lc.appendTagStart("g");
        lc.appendTagAttribute("id", "clLegendboxArea");
        lc.appendTagAttribute("style", "display: none;");
        lc.appendTagStartEnd();

        lc.appendTagStart("rect");
        lc.appendTagLocationSizeAttributes(0, 0, fir.getColorLegendWidth(), fir.getColorLegendLegendBoxHeight());
        lc.appendTagAttribute("class", CSS_COLOR_LEGEND_LEGENDBOX_AREA);
        lc.appendTagStartEnd();
        lc.appendTagClose("rect");

        int x = fir.getColorLegendLegendBoxInternalPadding(),
                y = fir.getColorLegendLegendBoxInternalPadding();
        int incrementX = (fir.getColorLegendWidth() - fir.getColorLegendLegendBoxInternalPadding()) / 5,
                incrementY = (fir.getColorLegendLegendBoxHeight() - fir.getColorLegendLegendBoxInternalPadding()) / 5;
//loop through all the colors
        for (int i = 0; i < colors.size(); i++) {
            if (i != 0 && i % 5 == 0) {
                x = fir.getColorLegendLegendBoxInternalPadding();
                y += incrementY;
            }
            String nameId = (String) colors.get(i);
            drawColorLegendColorBox(nameId, x, y);
            x += incrementX;
        }

        lc.appendTagClose("g");
    }

    protected void drawColorLegendTitle() {
        //group together
        lc.appendTagStart("g");
        lc.appendTagAttribute("onclick", "toggleColorLegend()");
        lc.appendTagAttribute("onmouseover", "highlightCLButton()");
        lc.appendTagAttribute("onmouseout", "unhighlightCLButton()");
        lc.appendTagStartEnd();

        lc.appendTagStart("rect");
        lc.appendTagAttribute("id", "clTitleArea");
        lc.appendTagAttribute("style", "fill:url(#button);");
        lc.appendTagLocationSizeAttributes(0, fir.getColorLegendLegendBoxHeight(),
                fir.getColorLegendWidth(), fir.getColorLegendHeight() - fir.getColorLegendLegendBoxHeight());
        lc.appendTagAttribute("class", CSS_COLOR_LEGEND_TITLE_AREA);
        lc.appendTagStartEnd();
        lc.appendTagClose("rect");


//the title text
        int titleboxHeight = fir.getColorLegendHeight() - fir.getColorLegendLegendBoxHeight();
        drawLabel(fir.getColorLegendWidth() / 2,
                fir.getColorLegendLegendBoxHeight() + titleboxHeight * 3 / 4,
                fir.getColorLegendTitleText(), CSS_COLOR_LEGEND_TITLE_TEXT, null);

        lc.appendTagClose("g");
    }

    protected void drawColorLegendColorBox(String nameId, int x, int y) {
        //the box
        lc.appendTagStart("rect");
        lc.appendTagLocationSizeAttributes(x, y, fir.getColorLegendColorboxSize(), fir.getColorLegendColorboxSize());
        lc.appendTagAttribute("class", CSS_COLOR_LEGEND_COLORBOX);
        lc.appendTagAttribute("style", "fill:" + lc.getColorCode(nameId));
        lc.appendTagStartEnd();
        lc.appendTagClose("rect");
//the text I am not sure what this method is doing?
        //TODO check what this method is doing
        drawLabel(x + fir.getColorLegendColorboxSize() + 7, y + fir.getColorLegendColorboxSize(),lc.getColorValue(nameId), CSS_COLOR_LEGEND_COLORBOX_LABEL, null);
    }


}
