package org.genboree.svg.compact;

import org.genboree.svg.GenomeData;
import org.genboree.svg.LocalContext;
import org.genboree.svg.SyntenyMapData;
import org.genboree.svg.imagemap.SVGLinkTree;
import org.genboree.svg.imagemap.SVGNode;
import org.genboree.dbaccess.VGPaint;
import java.io.IOException;
import java.util.*;

/**
 * Created By: Alan
 * Date: Apr 12, 2003 10:26:15 PM
 */
public class CompactGenomeData extends GenomeData {

    private int imageViewBoxWidth = 0;
    private int imageViewBoxHeight = 0;
    private CompactImageRequirements cir = null;
    private int sizeLegend = 0;
    private int minimumWidth = 1000;
    private int XpositionLabel = 55;
    private int startXOfBoxes = 0;
    private ArrayList CategoryLabelsInfo = new ArrayList(3);


    /**
     * Generates the SVG data for a specie.
     * localContext
     */

    public CompactGenomeData(HashMap requirements){
        super(requirements);
    }


    public void generateSVG(LocalContext localContext) throws IOException {
        lc = localContext;
        cir = (CompactImageRequirements) lc.getImageRequirements(); //TODO uncaught run time exception

        imageWidth = cir.getImageWidth();
        imageHeight = cir.getImageHeight();
	/* Loads the size and name of the Chromosomes */
        loadChromosomes("compact");
        appendSVGHeader();  // this is the svg generic headers
        imageViewBoxWidth = cir.getImageInternalPaddingLeft() + cir.getImageInternalPaddingRight() +
                cir.getChromosomePanelWidth() * entrypoints.size();

        if(imageViewBoxWidth < minimumWidth)
                imageViewBoxWidth = minimumWidth;
        calculateSizeLegend();
        calculateStartOfBoxes();


        imageViewBoxHeight = cir.getImageInternalPaddingTop() + cir.getImageInternalPaddingBottom() +
                cir.getChromosomePanelHeight() + sizeLegend;
//TODO add space for labels

        //the outmost svg element
        lc.append("<svg");  //do not use the appendTagStart() since no need to indent the root element
        lc.appendTagAttribute("id", "root"); //id is used in the animation
        lc.appendTagAttribute("x", 0);
        lc.appendTagAttribute("y", 0);
        lc.appendTagAttribute("width", imageWidth);
        lc.appendTagAttribute("height", imageHeight);
        lc.appendTagAttribute("viewBox", createViewBoxString(imageViewBoxWidth, imageViewBoxHeight));
        lc.appendTagStartEnd();
        lc.appendLineFeed();
        lc.appendLineFeed();
// TODO remove the tree thing.
        if (lc.willRasterizeGif()) {
            SVGLinkTree linkTree = new SVGLinkTree(
                    new SVGNode(0, 0, imageWidth, imageHeight,
                            0, 0, imageViewBoxWidth, imageViewBoxHeight));
            lc.setSvgLinkTree(linkTree);
        }

        //load style
        appendSVGStyle("image_settings/compact/external_files/style");

        //load script
        appendSVGScript("image_settings/compact/external_files/script");

        //generate SVG for each of the chromosomes

        generateChromosomesSVG();

        //create the ruler
        createLeftRuler();
        createRightRuler();


        //create the color legend box
        createColorLegend();

        //close up the svg document
        lc.appendTagClose("svg");
        //cache the svg doc
//        cacheSVG();
    }



    //Rulers are marked at 25Mb and 50Mb normalized using the calculated scale value
    private void createLeftRuler() {
        int width = cir.getImageInternalPaddingLeft(), height = cir.getChromosomePanelHeight();
        //first need to create a svg element which is the same size as the chromosomes in the left padding area
        lc.appendTagStart("svg");
        lc.appendTagAttribute("x", 0);
        lc.appendTagAttribute("y", cir.getImageInternalPaddingTop() + cir.getExtraTopPadding());
        lc.appendTagAttribute("width", width);
        lc.appendTagAttribute("height", height);
        lc.appendTagAttribute("viewBox", createViewBoxString(width, height));
        lc.appendTagStartEnd();
        lc.appendLineFeed();

        int x = width * 4 / 5, y = 500;
        lc.changeIndentation(lc.INDENT_PLUS);
        //draw the vertical line first
        lc.append("<path");
        StringBuffer sb = new StringBuffer();
        sb.append("m");
        sb.append(x);
        sb.append(" 0 l0 500");
        lc.appendTagAttribute("d", sb.toString());
        lc.appendTagAttribute("stroke", "black");
        lc.appendTagAttribute("stroke-width", "4px");
        lc.append("/>");
        lc.appendLineFeed();

        //mark the ticks from the bottom up
        int decrementY = (int) (25000000 * getScale());
        boolean isMajorTick = true;
        int tickWidth = width / 5 - 5;
        int count = 0;
        while (y > 20) { //the text needs about 20px to display
            drawTick(x, y, tickWidth, isMajorTick);
            String mark = Integer.toString(count * 25) + " Mb";
            drawLabel(width * 4 / 5 - 10, y, mark, null, "font-size:20px;text-anchor:end;");
            y -= decrementY;
            isMajorTick = !isMajorTick;
            count++;
        }
        lc.changeIndentation(lc.INDENT_MINUS);

        lc.appendTagClose("svg");
    }

    private void createRightRuler() {
        int width = cir.getImageInternalPaddingRight(), height = cir.getChromosomePanelHeight();
        //first need to create a svg element which is the same size as the chromosomes in the left padding area
        lc.appendTagStart("svg");
        lc.appendTagAttribute("x", imageViewBoxWidth - cir.getImageInternalPaddingRight());
        lc.appendTagAttribute("y", cir.getImageInternalPaddingTop() + cir.getExtraTopPadding());
        lc.appendTagAttribute("width", width);
        lc.appendTagAttribute("height", height);
        lc.appendTagAttribute("viewBox", createViewBoxString(width, height));
        lc.appendTagStartEnd();
        lc.appendLineFeed();

        int x = width * 1 / 5, y = 500;
        lc.changeIndentation(lc.INDENT_PLUS);
        //draw the vertical line first
        lc.append("<path");
        StringBuffer sb = new StringBuffer();
        sb.append("m");
        sb.append(x);
        sb.append(" 0 l0 500");
        lc.appendTagAttribute("d", sb.toString());
        lc.appendTagAttribute("stroke", "black");
        lc.appendTagAttribute("stroke-width", "4px");
        lc.append("/>");
        lc.appendLineFeed();

        //mark the ticks from the bottom up
        int decrementY = (int) (25000000 * scale);
        boolean isMajorTick = true;
        int tickWidth = width / 5 - 5;
        int count = 0;
        while (y > 20) { //the text needs about 20px to display
            drawTick(x - tickWidth, y, tickWidth, isMajorTick);
            String mark = Integer.toString(count * 25) + " Mb";
            drawLabel(width * 1 / 5 + 10, y, mark, null, "font-size:20px;text-anchor:start;");
            y -= decrementY;
            isMajorTick = !isMajorTick;
            count++;
        }
        lc.changeIndentation(lc.INDENT_MINUS);

        lc.appendTagClose("svg");
    }

    private void drawTick(int x, int y, int tickWidth, boolean isMajorTick) {
        StringBuffer sb = new StringBuffer();
        lc.append("<path");
        sb.append("m");
        sb.append(x);
        sb.append(' ');
        sb.append(y);
        sb.append(" l");
        sb.append(tickWidth);
        sb.append(" 0");
        lc.appendTagAttribute("d", sb.toString());
        lc.appendTagAttribute("stroke", "black");
        lc.appendTagAttribute("stroke-width", isMajorTick ? "4px" : "2px");
        lc.appendTagAttribute("stroke-linecap", "round");
        lc.append("/>");
        lc.appendLineFeed();
    }

    private void generateChromosomesSVG(){
        int csWidth = cir.getChromosomePanelWidth();
        int csHeight = cir.getChromosomePanelHeight();
        int x = cir.getImageInternalPaddingLeft(), y = cir.getImageInternalPaddingTop();
        for (int i = 0; i < entrypoints.size(); i++) {
            SyntenyMapData entrypoint = (SyntenyMapData) entrypoints.get(i);
            entrypoint.setCsX(x);
            entrypoint.setCsY(y);
            entrypoint.setCsWidth(csWidth);
            entrypoint.setCsHeight(csHeight);
            entrypoint.generateSVG(lc);
            x += csWidth;
        }
    }

    private void calculateStartOfBoxes() {
        if (!cir.isLegendVisible())
            return;

        int numberCategories = genomeInfo.getNumCategories();
        int localStartBoxes = 0;
        String categoryLegend = null;
        double charWidth = cir.getLegendTextCharWidth();
        int margin = 5;

        for(int i = 0; i < numberCategories; i++){
            categoryLegend = genomeInfo.getVgp().getFcategoryAt(i).getDescription();
            localStartBoxes = XpositionLabel + ((int)(categoryLegend.length() * charWidth) * 2) + margin;
            if(localStartBoxes > startXOfBoxes)
                startXOfBoxes = localStartBoxes;
        }

    }

    private void calculateSizeLegend() {
        if (!cir.isLegendVisible())
            return;

        int numberCategories = genomeInfo.getNumCategories();
        int numberFtypes =  genomeInfo.getVgp().getFtypeCount();
        int numberElementsPerCategory = 0;
        int sizeLabels[] = null;
        int a = -1;
        VGPaint.VGPFtype currentFtype;

        for(int i = 0; i < numberCategories; i++){
            numberElementsPerCategory = elementsPerCategory(i);
            sizeLabels = new int[numberElementsPerCategory];

            for(int j = 0; j < numberFtypes; j++){
                currentFtype = genomeInfo.getVgp().getFtypeAt(j);
                int singleFtype  =  currentFtype.getOrientation();
                if(singleFtype == i && currentFtype.getDisplay()){
                    a++;
                    sizeLabels[a] = currentFtype.getAbbreviation().length();
                }
            }

            sizeLegend += getLegendSize(a, sizeLabels);
            a = -1;
            sizeLabels = null;
        }
        sizeLegend += 50;
    }

    private int getLegendSize(int numberFtypes, int sizeLabels[]) {
        int btt = cir.getLegendBoxToTextSpace();
        int ttb = cir.getLegendTextToBoxSpace();
        int size = cir.getLegendBoxSize();
        int space = btt + ttb + size;
        int availableLineWidth = imageViewBoxWidth * 7 / 8;
        int startXOfBoxes = 0;
        int continueDrawing = 0;
        int height = 0;

        while(continueDrawing <  numberFtypes){
            continueDrawing = getNextBox(continueDrawing, sizeLabels, space, availableLineWidth, startXOfBoxes);
            height += (size *2);
        }

        return height;
    }

    private int getNextBox(int elementToDraw, int sizeLabels[], int space, int availableLineWidth, int startBoxes) {
        double charWidth = cir.getLegendTextCharWidth();
        int i = elementToDraw ;
        int lineWidthUsed = startBoxes + space + sizeLabels[i];

        while(lineWidthUsed <= availableLineWidth){
           if( i < sizeLabels.length){
            lineWidthUsed += (space + sizeLabels[i] * charWidth);
            i++;
           }
           else break;
        }

        return i;
    }

    private int elementsPerCategory(int categoryId){
        VGPaint.VGPFtype currentFtype;

        int numberFtypes =  genomeInfo.getVgp().getFtypeCount();
        int counter = 0;
        for(int j = 0; j < numberFtypes; j++){
            currentFtype = genomeInfo.getVgp().getFtypeAt(j);
            int singleFtype  =  currentFtype.getOrientation();
            if(singleFtype == categoryId && currentFtype.getDisplay()){
                counter++;
            }
        }
        return counter;
    }

    public void setVisLegendsData(){
        int numberCategories = genomeInfo.getNumCategories();
        int i = 0;
        for(i = 0; i < numberCategories; i++){
            CategoryLabelsInfo.add(new CompactLabel(requirements, i));
        }
      return;
    }

    //The size of the color labels are propotional to the image size
    private void createColorLegend() {
        if (!cir.isLegendVisible())
            return;

        String categoryLegend = null;
        String abbColor[][] = null;
        int latestHeight =  cir.getImageInternalPaddingTop()  +  cir.getChromosomePanelHeight();

        setVisLegendsData();
        Iterator labels = CategoryLabelsInfo.iterator();

        while(labels.hasNext())
        {
               CompactLabel currentLabel =  (CompactLabel)labels.next();
               abbColor = currentLabel.getAbbColor();
               categoryLegend = currentLabel.getDescription();
               if(abbColor != null && categoryLegend != null)
                    latestHeight = drawCategoryLegend(abbColor, categoryLegend, latestHeight);
        }
    }

    protected int  drawCategoryLegend(String abbColor[][], String categoryLegend, int initialY){
//TODO exception null point
        int btt = cir.getLegendBoxToTextSpace();
        int ttb = cir.getLegendTextToBoxSpace();
        int size = cir.getLegendBoxSize();
        int space = btt + ttb + size;
        int availableLineWidth = imageViewBoxWidth * 7 / 8;
        int continueDrawing = 0;
        int height = initialY;
        int centerLocation = 0;
        int yLocation = 0;


        while(continueDrawing <  abbColor.length){
            continueDrawing = drawLineBoxes(continueDrawing, abbColor, space, availableLineWidth, startXOfBoxes, height);
            height += (size *2); //TODO By increasing this number the image decrease
        }
        centerLocation = (height - initialY)/2;
        yLocation = initialY + centerLocation;

        drawLabel(XpositionLabel , yLocation ,categoryLegend, null, "font-size:30px;text-anchor:start;");

        height += 20;
        return height;

    }

    private int drawLineBoxes(int elementToDraw, String abbColor[][], int space, int availableLineWidth, int startBoxes, int  height) {
        int btt = cir.getLegendBoxToTextSpace();
        int size = cir.getLegendBoxSize();
        double charWidth = cir.getLegendTextCharWidth();
        int i = elementToDraw ;
        int lineWidthUsed = startBoxes + space + abbColor[i][0].length();
        int x = startBoxes;
        /* In here the small boxes for the label are generated */
        while(lineWidthUsed <= availableLineWidth){
           if( i < abbColor.length){
                drawColorLegendColorBox(abbColor[i][0], abbColor[i][1], x, height, size, btt);

            lineWidthUsed += (space + abbColor[i][0].length() * charWidth);
            x +=  space + (abbColor[i][0].length() * charWidth);
            i++;
           }
           else break;
        }

        return i;
    }


    protected void drawColorLegendColorBox(String name, String colorCode, int x, int y, int size, int boxTextSpacing) {
        //the box TODO null point exception
        lc.appendTagStart("rect");
        lc.appendTagLocationSizeAttributes(x, y, size, size);
        lc.appendTagAttribute("class", CSS_COLOR_LEGEND_COLORBOX);
        lc.appendTagAttribute("style", "fill:" + colorCode);
        lc.appendTagStartEnd();
        lc.appendTagClose("rect");
//TODO check here for the genomic labels

        drawLabel(x + size + boxTextSpacing, y + (int) (size * 0.85), name, null, "font-size:22px;text-anchor:start;");
//       drawLabel(x + size + boxTextSpacing, y + (int) (size * 0.85), nameId, null, "font-size:22px;text-anchor:start;");
    }

}
