package org.genboree.svg.compact;

import org.genboree.svg.Constants;
import java.util.*;
import org.genboree.genome.Genome;
import org.genboree.genome.EPoint;
import org.genboree.genome.Category;
import org.genboree.genome.FType;



public class CompactLabel implements Constants{
    private int categoryIndex;
    private TreeMap listNameColors;
    private Genome genomeInfo;
    private String name;
    private String orientation;
    private String abbreviation;
    private String description;
    private  String abbColor[][];

    public CompactLabel(HashMap requirements, int myCategoryIndex) {
        this.genomeInfo = (Genome)requirements.get(GENOMEINFO);
        this.categoryIndex = myCategoryIndex;
        this.name = genomeInfo.getVgp().getFcategoryAt(this.categoryIndex).getName();
        this.orientation = genomeInfo.getVgp().getFcategoryAt(this.categoryIndex).getOrientation();
        this.abbreviation = genomeInfo.getVgp().getFcategoryAt(this.categoryIndex).getAbbreviation();
        this.description = genomeInfo.getVgp().getFcategoryAt(this.categoryIndex).getDescription();
        setVisFtypes();
    }

    public String getName(){
          return this.name;
    }

    public String getOrientation(){
        return this.orientation;
    }

    public String getAbbreviation(){
        return abbreviation;
    }

    public String getDescription(){
        return description;
    }

    public String[][] getAbbColor(){
        return abbColor;
    }

    public void setAbbColor(){
        int numberColors = listNameColors.size();
        Comparator comp = new Genome.EntryPointComparatorByAbb(){
            public int compare( Object object1, Object object2 )
            {
                String first = ((String [])object1)[0];
                String second = ((String [])object2)[0];
                return compareStrings(first, second);
            }
        };

        abbColor = new String[numberColors][2];
        Iterator annotationIterator = listNameColors.keySet().iterator();
        int counter = 0;
        while(annotationIterator.hasNext())
        {
            abbColor[counter][0]   = (String)annotationIterator.next(); //nameId
            abbColor[counter][1] = (String)listNameColors.get(abbColor[counter][0]); //colorCode
            counter++;
        }
        java.util.Arrays.sort(abbColor, comp);

    }



    private class GenomeListComparator implements Comparator{

        public int compare(Object o1, Object o2){
            String s1 = (String)o1;
            String s2 = (String)o2;
            return s1.toUpperCase().compareTo(s2.toUpperCase());
        }
        public boolean equals(Object o){
            String s = (String)o;
            return compare(this,o)==0;
        }
    }


    public void setVisFtypes(){
        ArrayList epoints = genomeInfo.getEPoints();
        Iterator epIterat = epoints.iterator();
        int numberCategories;
        while(epIterat.hasNext())
        {
            EPoint epoint   =  (EPoint)epIterat.next();
            if(epoint.getDisplay())
            {
                numberCategories = epoint.getNumberCategories();
                for(int i = 0; i < numberCategories; i++)
                    setvisibleFtypesCat();
            }
        }
       setAbbColor();
    }

    public void setvisibleFtypesCat(){
        ArrayList epoints = genomeInfo.getEPoints();
        Iterator epIterat = epoints.iterator();
        Category currentCategory;
        ArrayList ftypes;
        int numberCategories;
        int i;


        while(epIterat.hasNext())
        {
            EPoint epoint   =  (EPoint)epIterat.next();
            if(epoint.getDisplay())
            {
                numberCategories = epoint.getNumberCategories();
                for(i = 0; i < numberCategories; i++){
                    if(i == categoryIndex){
                        currentCategory = epoint.getCategoryAt(i);
                        ftypes = currentCategory.getFTypes();
                        generateTree(ftypes);
                    }
                }

            }
        }

    }

    public void generateTree(ArrayList ftypes){
        Iterator ftypesIterat = ftypes.iterator();
        FType currentFtype;
        if(listNameColors == null)
            listNameColors = new TreeMap(new GenomeListComparator());

        while(ftypesIterat.hasNext())
        {
            currentFtype =  (FType)ftypesIterat.next();
            if(currentFtype.getDisplay()){
                listNameColors.put(currentFtype.getAbbreviation(), currentFtype.getColor());
            }
        }
        return;
    }






}
