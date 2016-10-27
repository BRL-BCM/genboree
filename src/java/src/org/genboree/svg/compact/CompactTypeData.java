package org.genboree.svg.compact;

import org.genboree.svg.LocalContext;
import org.genboree.svg.TypeData;
import org.genboree.genome.EPoint;
import org.genboree.genome.Category;
import org.genboree.genome.FType;
import org.genboree.genome.Group;
import java.util.HashMap;

/**
 * Created By: Alan
 * Date: Apr 12, 2003 10:29:30 PM
 */
public class CompactTypeData extends TypeData{

    private CompactImageRequirements cir = null;
    private int debug = 0;

    public CompactTypeData(HashMap requirements){
        super(requirements);
    }

    public void generateSVG(LocalContext localContext, String location){

        lc = localContext;
        cir = (CompactImageRequirements) lc.getImageRequirements();
        if(debug > 0){
            System.err.println("Calling the drawDataBoxes");
            System.err.flush();
        }
        drawDataBoxes(location);
    }

    //draw the databoxes from bottom up
    protected void drawDataBoxes(String location){
        int barWidth = this.cir.getAnnotationBoxWidth();
        int start = 0;
        int stop = 0;
        int height = 0;
        String colorCode = null;

        //all margins are handled at the chromosome level
        int boxHeight = cir.getAnnotationBoxesHeight();
        String leftPosition = "0";

        int blockStart = 0;
        int blockEnd = 0;
        int lastStart = 0;
        int lastHeight = 0;
        String lastColorCode = null;
        int numberCategories;
        int numberFtypes;
        int numberGroups;
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
//TODO maybe here the ftype display  can be analyzed
                for(int a = 0; a < numberFtypes; a++){
                    currentFtype = currentCategory.getFtypeAt(a);
                     if(currentFtype == null)
                        continue;
                    if(currentFtype.getDisplay()){
                        numberGroups = (int)currentFtype.getNumberGroups();
                        for(int b = 0; b < numberGroups; b++){
                            currentGroup = currentFtype.getGroupAt(b);
                            /* TODO activate this */
                            if(!currentGroup.getName().endsWith(genomeFilter))
                                continue;
/*
                            else{
        				if(debug > 0){
                                		System.err.println("the genome group name is " + currentGroup.getName());
                                		System.err.flush();
					}
                            }
*/
                           /* Until here */
                            blockStart = (int)currentGroup.getEPointStartPosition();
                            blockEnd = (int)currentGroup.getEpointStopPosition();
                            colorCode = currentFtype.getColor();
                            start = boxHeight - (int) (blockEnd * scale);
                            stop = boxHeight - (int) (blockStart * scale);
                            height = stop == start ? 1 : (stop - start); //make sure it is at least 1 pixel of height

                            //if the bar is exactly the same as the previous one (the data falls into the
                            //same location, which same height and same color code), we can skip it then.
                            if (start == lastStart && height == lastHeight &&
                                    colorCode != null && colorCode.equals(lastColorCode))
                                continue;
                            if(height < 0)
                                  continue;

                             //TODO check for better quality on data
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
                            lastStart = start;
                            lastHeight = height;
                            lastColorCode = colorCode;
                        }
                    }
                }
            }
        }
    }
}
