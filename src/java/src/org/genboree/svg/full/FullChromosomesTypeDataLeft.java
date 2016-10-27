package org.genboree.svg.full;

import org.genboree.genome.Genome;

import java.util.*;


/**
 * Created By: alan
 * Date: Mar 12, 2003 10:06:41 PM
 */
public class FullChromosomesTypeDataLeft extends FullChromosomesTypeData {

    public FullChromosomesTypeDataLeft(HashMap requirements){
        super(requirements);
    }

    protected int getDataBoxesLeftMargin() {
        return fir.getAnnotationBoxInternalPaddingOutside();
    }

    protected int getCurelyBracketLeftMargin() {
        return fir.getAnnotationBoxInternalPaddingOutside() - 20; //the curly bracket's width is 12
    }

    protected int getColorLabelInitialX() {
        return getCurelyBracketLeftMargin() - 5 - fir.getColorSideboxColumnWidth(); //5 is the padding
    }

    int getColorLabelXIncrement(int stringLength, int currentPosition) {
        return currentPosition - (stringLength * 5) - 5;
    }


    public String[][] fromTreeToArray(TreeMap colorNames){
        int numberColors = colorNames.size();
        Comparator comp = new Genome.EntryPointComparatorByAbb(){
            public int compare( Object object1, Object object2 )
            {
                String first = ((String [])object1)[0];
                String second = ((String [])object2)[0];
                return compareStrings(second, first);
            }
        };

        String abbColor[][] = new String[numberColors][2];
        Iterator annotationIterator = colorNames.keySet().iterator();
        int counter = 0;
        while(annotationIterator.hasNext())
        {
            abbColor[counter][0]   = (String)annotationIterator.next(); //nameId
            abbColor[counter][1] = (String)colorNames.get(abbColor[counter][0]); //colorCode
            counter++;
        }
        java.util.Arrays.sort(abbColor, comp);
        return abbColor;
    }

    public int getInitialY(int startBlock, int heightBlock, int numberLines ){
        if(numberLines == 1)
            return startBlock + (heightBlock/2) - (8 * numberLines);
        else
            return startBlock + (heightBlock/2) + (4 * numberLines);
    }


    public int returnYValue(int originalValue){
        return originalValue - 25;
    }

    protected String getCurelyBracketSymbol() {
        return "#leftCurlyBracket";
    }

    protected String getSmallBracketSymbol() {
        return "#leftSmallBracket";
    }

    protected int getBoxX() {
        return fir.getChromosomePanelInternalPaddingLeft();
    }

    protected ArrayList setLablesOrientation(ArrayList blocks) {
        return blocks;
    }


    protected int getBoxWidth() {
        return fir.getAnnotationBoxWidthLeft();
    }

    protected int getLabelX() {
        return (fir.getChromosomePanelInternalPaddingLeft() + fir.getAnnotationBoxWidthLeft()) / 2;
    }

    protected boolean atLeftSide() {
        return true;
    }


}
