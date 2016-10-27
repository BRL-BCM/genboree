package org.genboree.svg.full;


import org.genboree.util.SmallT;

import java.util.*;


public class  Blocks {
    private ArrayList leftBlocks;
    private ArrayList rightBlocks;
    private int minimumBracketSize;
    private int minimumLeftStart;
    private int minimumRightStart;
    private int maxRightEnd;
    private int maxLeftEnd;

    public int getMaxStop(String orientation){
        if(orientation.equalsIgnoreCase("right"))
            return maxRightEnd;
        else
            return maxLeftEnd;
    }

    public int getMinimumStart(String orientation){
        if(orientation.equalsIgnoreCase("right"))
            return minimumRightStart;
        else
            return minimumLeftStart;
    }

    public Blocks(int minSize){
        leftBlocks = new ArrayList(10);
        rightBlocks = new ArrayList(10);
        this.minimumBracketSize = minSize;
        if(SmallT.getDebug() > 0)
            System.err.println("The minimum size is " + minSize);
    }

    public ArrayList getBlocks(String orientation){
        if(orientation.equalsIgnoreCase("right"))
            return rightBlocks;
        else
            return leftBlocks;
    }

    private class FTypesComparator implements Comparator {

        public int compare( Object object1, Object object2 )
        {
            int comparator = 0;
            // cast the objects
            AnnotationBlock firstBlock = ( AnnotationBlock) object1;
            AnnotationBlock secondBlock = ( AnnotationBlock ) object2;
            comparator = firstBlock.getStart() - secondBlock.getStart();
            if(comparator == 0)
                comparator = firstBlock.getStop() - secondBlock.getStop();
            return comparator;
        }

    }

    public void   addAnnotation(AnnotationBlock block, String orientation){
        if(orientation.equalsIgnoreCase("right")){
            this.rightBlocks.add(block);
        }
        else{
            this.leftBlocks.add(block);
        }
    }

    public void addToInitialBlock(String nameId, int start, int stop, String colorCode, String orientation) {

        AnnotationBlock block = null;

        block = new AnnotationBlock(nameId, colorCode, start, stop);
        if(SmallT.getDebug() > 0)
        {
            System.err.print("Inside the addToInitialBlock values nameId, start, stop, colorCode and orientation ");
            System.err.println(nameId + " " +  colorCode + " " + start + " " + stop + " " + orientation);
            System.err.flush();
        }
        addAnnotation(block, orientation);

    }

    public AnnotationBlock mergeBlocks(AnnotationBlock target, AnnotationBlock source){

        TreeMap listNameColors = source.getListNameColors();
        Set set = listNameColors.entrySet();
        Iterator tempIterator;
        tempIterator = set.iterator();
        while(tempIterator.hasNext())
        {
            Map.Entry entry = (Map.Entry)tempIterator.next();
            String myNameId   = (String)entry.getKey();
            String myColorCode = (String)entry.getValue();
            target.setlistNameColors(myNameId, myColorCode);
        }
        if(target.getStop() < source.getStop()){
            target.setStop(source.getStop());
            target.setNameId(source.getNameId());
        }
        return target;
    }

    public void generateBlocks(String location){
        ArrayList currentBlock;
        ArrayList newBlock;
        AnnotationBlock aBlock;
        int sizeOfAccumulatedBlock = 0;
        AnnotationBlock toBeAddedBlock = null;
        int blockSize;
        int currentPosition = 0;
        int minimumPosition = 0;
        int maxPosition = 0;
        Iterator blIterator;
        int i = 0;
        int minimumSizeBlock = 300;//original value 3000;
        boolean sameName = true;




        if(location.equalsIgnoreCase("right")){
            currentBlock = rightBlocks;
        }
        else{
            currentBlock = leftBlocks;
        }
        blockSize = currentBlock.size();
        if(blockSize == 0 )
            return;


        if(SmallT.getDebug() > 0){
            blIterator = currentBlock.iterator();
            while(blIterator.hasNext())
            {
                aBlock   =  (AnnotationBlock)blIterator.next();
                System.err.println("Before sorting Start = " + aBlock.getStart() + " Stop = " + aBlock.getStop() + " NameId = " + aBlock.getNameId());
                System.err.flush();
            }

        }

        Collections.sort(currentBlock, new Blocks.FTypesComparator());

        newBlock = new ArrayList(blockSize + 5);
        i = 1;
        blIterator = currentBlock.iterator();

        while(blIterator.hasNext())
        {
/*          Loop for debugging only to select a fragment to check Manuel 011204
            if(i > 100){
                i++;
                if(i == blockSize)
                    break;
                else
                    continue;
            }

*/

            aBlock   =  (AnnotationBlock)blIterator.next();
            currentPosition = i;

            if(toBeAddedBlock == null){
                toBeAddedBlock = new AnnotationBlock(aBlock.getNameId(), aBlock.getColorCode(), aBlock.getStart(), aBlock.getStop());
                minimumPosition = aBlock.getStart();
                maxPosition = aBlock.getStop();
            }
            else{

                if(aBlock.getStart() < minimumPosition)
                    minimumPosition = aBlock.getStart();

                if(aBlock.getStop() > maxPosition)
                    maxPosition = aBlock.getStop();

                sizeOfAccumulatedBlock += toBeAddedBlock.getStop() - toBeAddedBlock.getStart();
                sameName = toBeAddedBlock.getNameId().equalsIgnoreCase(aBlock.getNameId() );
                if(sizeOfAccumulatedBlock > minimumSizeBlock && !sameName){
                    if(aBlock.getStop() >= toBeAddedBlock.getStop()){
                        newBlock.add(toBeAddedBlock);
                        toBeAddedBlock = null;
                        sizeOfAccumulatedBlock = 0;
                        toBeAddedBlock = new AnnotationBlock(aBlock.getNameId(), aBlock.getColorCode(), aBlock.getStart(), aBlock.getStop());
                        minimumPosition = aBlock.getStart();
                        maxPosition = aBlock.getStop();
                    }
                    else{
                        toBeAddedBlock.setNameId(aBlock.getNameId());
                        toBeAddedBlock.setlistNameColors(aBlock.getNameId(), aBlock.getColorCode());
                    }
                }
                else{

                    if(toBeAddedBlock.getStop() < aBlock.getStop())
                        toBeAddedBlock.setStop(aBlock.getStop());
                    toBeAddedBlock.setNameId(aBlock.getNameId());
                    toBeAddedBlock.setlistNameColors(aBlock.getNameId(), aBlock.getColorCode());

                }

                // In here I try to fix the last block

                if(currentPosition == blockSize && sizeOfAccumulatedBlock > minimumSizeBlock)
                {
                    newBlock.add(toBeAddedBlock);
                    toBeAddedBlock = null;
                    sizeOfAccumulatedBlock = 0;
                    minimumPosition = aBlock.getStart();
                    maxPosition = aBlock.getStop();
                }
                else if(currentPosition == blockSize && sizeOfAccumulatedBlock <= minimumSizeBlock){
                    int lastNewBlock = newBlock.size() -1;
                    if(lastNewBlock > -1){
                        if(toBeAddedBlock == null){
                            toBeAddedBlock = (AnnotationBlock)(newBlock.get(lastNewBlock));
                            if(toBeAddedBlock == null){
                                System.err.println("The block is null");
                                System.err.flush();
                            }
                            newBlock.remove(lastNewBlock);
                            if(toBeAddedBlock == null){
                                System.err.println("The block is null after the remove");
                                System.err.flush();
                            }
                        }
                        else{
                            AnnotationBlock tempBlock = (AnnotationBlock)(newBlock.get(lastNewBlock));
                            toBeAddedBlock = mergeBlocks(tempBlock, toBeAddedBlock);
                            newBlock.remove(lastNewBlock);
                            tempBlock = null;
                        }
                    }

                    if(toBeAddedBlock.getStop() < aBlock.getStop())
                        toBeAddedBlock.setStop(aBlock.getStop());
                    toBeAddedBlock.setNameId(aBlock.getNameId());
                    newBlock.add(toBeAddedBlock);
                    toBeAddedBlock = null;
                    sizeOfAccumulatedBlock = 0;
                }
            }
            i++;
        }

        if(newBlock.isEmpty()  && toBeAddedBlock != null ){
            newBlock.add(toBeAddedBlock);
            toBeAddedBlock = null;
        }


        if(location.equalsIgnoreCase("right")){
            rightBlocks = null;
            rightBlocks = newBlock;
            this.minimumRightStart = minimumPosition;
            this.maxRightEnd = maxPosition;
        }
        else{
            leftBlocks = null;
            leftBlocks = newBlock;
            this.minimumLeftStart = minimumPosition;
            this.maxLeftEnd = maxPosition;
        }
    }
}
