package org.genboree.svg.full;

import org.genboree.svg.LocalContext;
import org.genboree.svg.TypeData;
import org.genboree.genome.FType;
import org.genboree.genome.EPoint;
import org.genboree.genome.Category;
import org.genboree.genome.Group;
import org.genboree.util.SmallT;
import java.util.HashMap;
import java.util.ArrayList;
import java.util.TreeMap;
import java.util.Iterator;


abstract public class FullChromosomesTypeData extends TypeData {
    protected FullChromosomesImageRequirements fir = null;
    protected Blocks drawingBlock;


    public FullChromosomesTypeData(HashMap requirements){
        super(requirements);
    }


    abstract int getDataBoxesLeftMargin();
    abstract int getCurelyBracketLeftMargin();
    abstract int getColorLabelInitialX();
    abstract int getColorLabelXIncrement(int stringLength, int currentPosition);
    abstract String getCurelyBracketSymbol();
    abstract String getSmallBracketSymbol();
    abstract ArrayList setLablesOrientation(ArrayList blocks);
    abstract int getBoxX();
    abstract int getBoxWidth();
    abstract int getLabelX();
    abstract boolean atLeftSide();
    abstract String[][] fromTreeToArray(TreeMap colorNames);

    public void generateSVG(LocalContext localContext, String location){
        lc = localContext;
        fir = (FullChromosomesImageRequirements) lc.getImageRequirements();

        int topMargin = !lc.singleChromosomeOnly() ? fir.getChromosomePanelInternalPaddingTop() : fir.isChromosomeLabelVisible() ? fir.getChromosomePanelInternalPaddingTop() : 0;
        int height = fir.getAnnotationBoxesHeight();

        //draw the label
        if (fir.isChromosomeLabelVisible()) {
            drawLabel(getLabelX(), topMargin / 5 * 4, type, CSS_ANNOTATION_TITLE, null);

//TODO add more lables2
        }

        drawingBlock = new Blocks(fir.getMinimumCurlyBracketHeight());
        //for single chromosome, we'd like to truncate the whitespaces
        int viewBoxHeight = lc.singleChromosomeOnly() ? getTemplateBoxSize() : height;
        //draw the container tag <svg>
        lc.appendTagStart("svg");
        lc.appendTagAttribute("x", getBoxX());
        lc.appendTagAttribute("y", topMargin);
        lc.appendTagAttribute("width", getBoxWidth());
        lc.appendTagAttribute("height", viewBoxHeight);
        lc.appendTagAttribute("viewBox", createViewBoxString(getBoxWidth(), viewBoxHeight));
        lc.appendTagAttribute("preserveAspectRatio", "xMidYMin meet");
        lc.appendTagStartEnd();

        //draw the data
        drawDataBoxes(location);


        //draw the curely brackets
        if (fir.isAnnotationSideLabelVisible()) {
//            if(location.equalsIgnoreCase("right")) //TODO erase
            drawColorBoxes(location);
        }

        //TODO height can not be zero! 10/14/03

        //close the starting <svg> tag
        lc.appendTagClose("svg");

        if (lc.isDebug())
            lc.append("<rect x=\"" + getBoxX() + "\" y=\"" + topMargin + "\" width=\"" + getBoxWidth() + "\" height=\"" + viewBoxHeight + "\" stroke=\"blue\" fill=\"none\"/>\n");

    }

    private void drawColorBoxes(String location) {

        ArrayList currentBlock = drawingBlock.getBlocks(location);
        Iterator cbIterator;

        AnnotationBlock currentAnnotation;
        cbIterator = currentBlock.iterator();

        while(cbIterator.hasNext())
        {
            currentAnnotation  =  (AnnotationBlock)cbIterator.next();
            drawSingleBlock(location, currentAnnotation);
        }
    }

    private void drawSingleBlock(String location, AnnotationBlock currentBlock) {

        int x = getCurelyBracketLeftMargin();
        int y = currentBlock.getStart();
        int stop = currentBlock.getStop();
        int width = 12;

        int height = stop - y;
        if(height  < 1){
             if(SmallT.getDebug() > 0){
                System.err.println("The height is wrong " + height);
                System.err.flush();
             }
            return;
        }

        if(SmallT.getDebug() > 0){
            System.err.println("The start, stop and height are " + y + " " + stop + " "+ height);
            System.err.flush();
        }

        lc.appendTagStart("svg");
        lc.appendTagAttribute("x", x);
        lc.appendTagAttribute("y", y);
        lc.appendTagAttribute("width", width);
        lc.appendTagAttribute("height", height);
        if(height >= fir.getMinimumCurlyBracketHeight())
            lc.appendTagAttribute("viewBox", "0 0 12 160");
        else
            lc.appendTagAttribute("viewBox", "0 0 2.632 14.392");
        lc.appendTagAttribute("preserveAspectRatio", "none");
        lc.appendTagStartEnd();
        lc.changeIndentation(lc.INDENT_PLUS);
        lc.appendIndentation();
        lc.append("<use");
        if(height >= fir.getMinimumCurlyBracketHeight())
            lc.appendTagAttribute("xlink:href", getCurelyBracketSymbol());
        else
            lc.appendTagAttribute("xlink:href", getSmallBracketSymbol());

        lc.append("/>");
        lc.appendLineFeed();
        lc.changeIndentation(lc.INDENT_MINUS);
        lc.appendTagClose("svg");

        drawASetOfBoxes(location, y, height, currentBlock.getListNameColors());
    }

    private int calculateNumberLines(String abbColor[][], int initialValue){
        int start = initialValue;
        int numberLines = 1;
        int nameLength;

        for(int a = 0; a < abbColor.length; a++){
            nameLength = abbColor[a][0].length();
            if(nameLength < 2)
                nameLength = 2;
            start = start  - 5 - (nameLength * 5);
            if(start < 5 && a < (abbColor.length - 1)){
                numberLines++;
                start = initialValue;
            }
        }
        return numberLines;
    }

    private int getRemaining(int nameLength, int lineCounter, int initialValue){
        int start = lineCounter;
        start = start  - 5 - (nameLength * 5) ;
        if(start < 5){
            start = initialValue;
        }

        return start;
    }

    abstract int getInitialY(int startBlock, int heightBlock, int numberLines );

    abstract int returnYValue(int originalValue);

    public void drawASetOfBoxes(String location, int startBlock, int heightBlock, TreeMap colorNames){
        int x = getColorLabelInitialX();
        int initialValue = 60;
        int lineCounter = initialValue;
        String abbColor[][] = fromTreeToArray(colorNames);
        int numberLines = calculateNumberLines(abbColor, initialValue);
        int y = getInitialY(startBlock, heightBlock, numberLines);


        for(int a = 0; a < abbColor.length; a++){
            int nameLength =  abbColor[a][0].length();
            if(nameLength < 2)
                nameLength = 2;

            lineCounter = getRemaining(nameLength, lineCounter, initialValue);
            drawColorBoxLabel(abbColor[a][0], abbColor[a][1], x, y);
            x = getColorLabelXIncrement(nameLength, x);
            if (lineCounter == initialValue) {
                y = returnYValue(y);  //17 + 8, where 8 is the font height - font descent
                x = getColorLabelInitialX();
            }
        }
    }

    private void drawColorBoxLabel(String nameId, String colorCode, int x, int y) {
        int size = fir.getColorLegendColorboxSize();
        drawLabel(x + size / 2, y, nameId, CSS_COLOR_LEGEND_COLORBOX_LABEL, null);
        lc.appendTagStart("rect");
        lc.appendTagLocationSizeAttributes(x, y + 3, size, size);
        lc.appendTagAttribute("class", CSS_COLOR_LEGEND_COLORBOX);
        lc.appendTagAttribute("style", "fill:" + colorCode);
        lc.appendTagStartEnd();
        lc.appendTagClose("rect");
    }

    protected void drawDataBoxes(String location){
        int barWidth = fir.getAnnotationBarWidth();
        int start = 0;
        int stop = 0;
        int height = 0;
        int sizeOfTempBox = getTemplateBoxSize();
        String nameId = null;
        String colorCode = null;
        //should not include the EXT_MARGIN's because the coordinations is relative to the current SVG tag.
        int leftOffset = getDataBoxesLeftMargin();
        String leftPosition = Integer.toString(leftOffset);

        int blockStart = 0;
        int blockEnd = 0;
        int lastStart = 0;
        int lastHeight = 0;
        int numberCategories;
        int numberFtypes;
        int numberGroups;
        String lastColorCode = null;
        EPoint currentEP =  genomeInfo.getEpoint(this.getEntrypointId());
        numberCategories = currentEP.getNumberCategories();
        Category currentCategory;
        FType currentFtype;
        Group currentGroup;
        String orientation;

        for(int i = 0; i < numberCategories; i++)
        {
            currentCategory = currentEP.getCategoryAt(i);
            orientation = currentCategory.getOrientation();
            if(orientation.equalsIgnoreCase(location)){
                numberFtypes = currentCategory.getNumberFtypes();
                for(int a = 0; a < numberFtypes; a++){
//TODO Maybe here the ftype display can be controled
                    currentFtype = currentCategory.getFtypeAt(a);
                    if(currentFtype == null)
                        continue;
                    if(currentFtype.getDisplay()){
                        nameId = currentFtype.getAbbreviation();
                        numberGroups = (int)currentFtype.getNumberGroups();
                        for(int b = 0; b < numberGroups; b++){
                            currentGroup = currentFtype.getGroupAt(b);
                            /* TODO activate this */
                            if(!currentGroup.getName().endsWith(chromosomeFilter))
                                continue;
/*
                            else{
                                System.err.println("the chromosome group name is " + currentGroup.getName());
                                System.err.flush();
                            }
*/
                            /* Until here */
                            blockStart = (int)currentGroup.getEPointStartPosition();
                            blockEnd = (int)currentGroup.getEpointStopPosition();
                            start = sizeOfTempBox - (15 + (int) (blockEnd  * scale));
                            stop = sizeOfTempBox - (15 + (int) (blockStart * scale));
                            height = stop == start ? 1 : (stop - start); //make sure it is at least 1 pixel of height
                            colorCode = currentFtype.getColor();
//TODO check the max size of block
                            /*
                    if((stop - start) > 20 ){
                        System.err.println("-----------The value is too big for start and stop " + start + " " + stop +"---------");
                        System.err.flush();
                    }
                    else
                        continue;
*/

                            //if the bar is exactly the same as the previous one (the data falls into the
                            //same location, which same height and same color code), we can skip it then.
                            if (start == lastStart && height == lastHeight &&
                                    colorCode != null && colorCode.equals(lastColorCode))
                                continue;


                           if(height < 0)
                                  continue;

                            //add the data to the svg
                            lc.appendIndentation();
                            lc.append("<rect"); //can not use the appendTagStart() since it will increase the indentation
                            lc.appendTagAttribute("x", leftPosition);
                            lc.appendTagAttribute("y", start);
                            lc.appendTagAttribute("width", barWidth); //width is the same
                            lc.appendTagAttribute("height", height);
                            lc.appendTagAttribute("fill", colorCode);
                            lc.append("/>");
                            lc.appendLineFeed();
                            if(SmallT.getDebug() > 0){
                                System.err.println("Name Id = " + nameId + " start =  " +  start + " stop = " + stop);
                                System.err.println(" colorCode = " + colorCode + " location =  " +  location);
                                System.err.flush();
                            }
                            drawingBlock.addToInitialBlock(nameId, start, stop, colorCode, location);
                            lastStart = start;
                            lastHeight = height;
                            lastColorCode = colorCode;
                        }
                    }
                }
 //               if(location.equalsIgnoreCase("right")) //TODO erase
                drawingBlock.generateBlocks(location);
            }
        }
    }


}
