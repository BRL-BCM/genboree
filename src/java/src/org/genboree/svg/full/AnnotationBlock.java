package org.genboree.svg.full;


import java.util.TreeMap;
import java.util.Comparator;
import org.genboree.util.SmallT;

public class  AnnotationBlock {


    private String nameId = null;
    private String colorCode = null;
    private int start = -1;
    private int stop = -1;
    private TreeMap listNameColors;



    public AnnotationBlock(String name, String color, int begin, int end){
        this.nameId = name;
        this.colorCode = color;
        this.start = begin;
        this.stop = end;
        setlistNameColors(name, color);
    }

    public AnnotationBlock(String name, String color, int begin, int end, TreeMap myTree){
         this.nameId = name;
         this.colorCode = color;
         this.start = begin;
         this.stop = end;
         this.listNameColors = myTree;
     }


    private class AnnotationBlockComparator implements Comparator{

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

    public AnnotationBlock(){
        this.nameId = null;
        this.colorCode = null;
        this.start = 0;
        this.stop = 0;
    }

    public String getNameId(){
        return this.nameId;
    }

    public void setNameId(String name){
        this.nameId = name;
    }

    public void copyListNameColors(TreeMap myMap){
        listNameColors = myMap;
    }

    public void setlistNameColors(String name, String color){
        if(SmallT.getDebug() > 0){
            System.err.println("THE NAME AND COLOR ARE " + name + " " + color);
            System.err.flush();
        }
        if(listNameColors == null){
            listNameColors = new TreeMap(new AnnotationBlockComparator());
            listNameColors.put( name, color );
        }
        else
            listNameColors.put( name, color );
    }

    public TreeMap getListNameColors(){
        return listNameColors;
    }

    public void setColorCode(String color){
        this.colorCode = color;
    }

    public void setStart(int begin){
        this.start = begin;
    }

    public void setStop(int end){
        this.stop = end;
    }

    public String getColorCode(){
        return this.colorCode;
    }

    public int getStart(){
        return this.start;
    }

    public int getStop(){
        return this.stop;
    }

}
