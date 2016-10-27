package org.genboree.svg.full;

import org.genboree.genome.Genome;

import java.util.*;


/**
 * Created By: alan
 * Date: Mar 12, 2003 10:06:33 PM
 */
public class FullChromosomesTypeDataRight extends FullChromosomesTypeData {


    public FullChromosomesTypeDataRight(HashMap requirements){
        super(requirements);
    }

    protected int getDataBoxesLeftMargin() {
        return fir.getAnnotationBoxInternalPaddingInside();
    }

    protected int getCurelyBracketLeftMargin() {
        return fir.getAnnotationBoxInternalPaddingInside() + fir.getAnnotationBarWidth() + 8; //the curly bracket's width is 12
    }

    protected int getColorLabelInitialX() {
        return getCurelyBracketLeftMargin() + 20 + 5; //20: width of the curelybracket, 5 is the padding
    }

    int getColorLabelXIncrement(int stringLength, int currentPosition) {
          return currentPosition + (stringLength * 5)  + 5;
    }

        public String[][] fromTreeToArray(TreeMap colorNames){
        int numberColors = colorNames.size();
        Comparator comp = new Genome.EntryPointComparatorByAbb(){
            public int compare( Object object1, Object object2 )
            {
                String first = ((String [])object1)[0];
                String second = ((String [])object2)[0];
                return compareStrings(first, second);
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

        public int returnYValue(int originalValue){
        return originalValue + 25;
    }


    public int getInitialY(int startBlock, int heightBlock, int numberLines ){
        if(numberLines == 1)
            return startBlock + (heightBlock/2) - (8 * numberLines);
        else
            return startBlock + (heightBlock/2) - (6 * numberLines);
    }

    protected ArrayList setLablesOrientation(ArrayList blocks) {
         ArrayList newListBlocks = new ArrayList();
            for (int i = blocks.size() - 1; i >= 0; i--) {
                AnnotationBlock block = (AnnotationBlock) blocks.get(i);
                newListBlocks.add(block);
            }
        return newListBlocks;
    }


    protected String getCurelyBracketSymbol() {
        return "#rightCurlyBracket";
    }

    protected String getSmallBracketSymbol() {
       return "#rightSmallBracket";
    }

    protected int getBoxX() {
        return fir.getChromosomePanelInternalPaddingLeft() + fir.getAnnotationBoxWidthLeft() + fir.getAnnotationBoxWidthCenter();
    }

    protected int getBoxWidth() {
        return fir.getAnnotationBoxWidthRight();
    }

    protected int getLabelX() {
        return fir.getChromosomePanelInternalPaddingLeft() + fir.getAnnotationBoxWidthLeft() +
                fir.getAnnotationBoxWidthCenter() +
                (fir.getChromosomePanelWidth() - fir.getChromosomePanelInternalPaddingLeft() - fir.getAnnotationBoxWidthLeft() - fir.getAnnotationBoxWidthCenter()) / 2;
    }

    protected boolean atLeftSide() {
        return false;
    }
}
