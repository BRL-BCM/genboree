package org.genboree.svg.compact;

import org.genboree.svg.ImageDrawingFactory;
import org.genboree.svg.LocalContext;
import org.genboree.svg.SyntenyMapData;
import org.genboree.svg.TypeData;
import org.genboree.svg.imagemap.RectangleLinkedArea;
import org.genboree.svg.imagemap.SVGNode;
import org.genboree.dbaccess.VGPaint;
import org.genboree.genome.EPoint;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.HashMap;


/**
 * Created By: Alan
 * Date: Apr 12, 2003 10:44:57 PM
 */
public class CompactSyntenyMapData extends SyntenyMapData{

    private String leftLabel = null;
    private String rightLabel = null;
    private CompactImageRequirements cir = null;
    private static final String leftStr = "left";
    private static final String rightStr = "right";

   public CompactSyntenyMapData(HashMap requirements) {
       super(requirements);
    }


    /**
     * Generates the SVG data for a single chromosome synteny map.
     * @param localContext
     */
    public void generateSVG(LocalContext localContext){
        lc = localContext;
        cir = (CompactImageRequirements) lc.getImageRequirements();

        //retrieve the link info
//        retrieveLinkInfo();

        //define a svg element for the chromosome
        lc.appendTagStart("svg");
        lc.appendTagAttribute("class", CSS_CS_SVG);
//        lc.appendTagAttribute("id", "csNode" + entrypointId);  //the id is used in the animation
        lc.appendTagAttribute("x", csX);
        lc.appendTagAttribute("y", csY);
        lc.appendTagAttribute("width", csWidth);
        lc.appendTagAttribute("height", csHeight);
        lc.appendTagAttribute("viewBox", createViewBoxString(cir.getChromosomePanelWidth(), cir.getChromosomePanelHeight()));

//        lc.appendTagAttribute("keepAspectRatio", "xMidYMin slice");
        lc.appendTagStartEnd();

        if (lc.willRasterizeGif()) {
            lc.getSvgLinkTree().moveToChildNode(
                    new SVGNode(csX, csY, csWidth, csHeight,
                            0, 0, cir.getChromosomePanelWidth(), cir.getChromosomePanelHeight()));
        }
        //generate SVG for the two types of annotations placed at the left and the right
        generateTypeDataSVG();
        defineLinkableFrame();
         // TODO maybe here
        //add label for each annotation
        addAnnotationLabels();

        //close up the svg document
        lc.appendIndentation(lc.INDENT_MINUS);
        lc.appendTagClose("svg");
//        lc.printContent();

        if (lc.willRasterizeGif())
            lc.getSvgLinkTree().moveUp();


    }

    protected void generateTypeDataSVG() {
        TypeData left = null;
        TypeData right = null;
        VGPaint tempVGPInfo = null;

        tempVGPInfo = genomeInfo.getVgp();
        int ftCategory = tempVGPInfo.getFcategoryCount();
        for(int fc = 0; fc < ftCategory; fc++){
            VGPaint.VGPFcategory myFcategory = tempVGPInfo.getFcategoryAt(fc);
            if(myFcategory.getOrientation().equalsIgnoreCase("right")){
                    right = ImageDrawingFactory.getTypeDataRightObject(lc.getImageType(), requirements);
                    right.setTypeId(fc);
                    right.setType(myFcategory.getName());
//Todo find if the right abbreviation is used
                    right.setSubtype(myFcategory.getOrientation());

//                    rightLabel = myFcategory.getName().substring(0, 1).toUpperCase();
                    rightLabel = myFcategory.getAbbreviation();
            }
            else if(myFcategory.getOrientation().equalsIgnoreCase("left")){
                    left = ImageDrawingFactory.getTypeDataRightObject(lc.getImageType(), requirements);
                    left.setTypeId(fc);
                    left.setType(myFcategory.getName());
                    left.setSubtype(myFcategory.getOrientation());
//                    leftLabel = myFcategory.getName().substring(0, 1).toUpperCase();
                    leftLabel = myFcategory.getAbbreviation();
            }
            else{
                System.err.println("Problems selecting category at CompactSyntenyMapData.java 111");
                System.err.flush();
            }
        }

     //delegate the drawings to the TypeData classes
        if (left != null) {
            setFields(left);
            wrapTypeDataWithSVG(left, getLeftAnnotationX(), cir.getExtraTopPadding(), cir.getAnnotationBoxWidth(), cir.getAnnotationBoxesHeight(), leftStr);
        }
        if (right != null) {
            setFields(right);
            wrapTypeDataWithSVG(right, getRightAnnotationX(), cir.getExtraTopPadding(), cir.getAnnotationBoxWidth(), cir.getAnnotationBoxesHeight(), rightStr);
        }
    }

   private int getEPSize(int entryPointId){
        ArrayList epoints;
        Iterator epIterat;
        epoints = genomeInfo.getEPoints();
        epIterat = epoints.iterator();

        while(epIterat.hasNext())
        {
            EPoint epoint   =  (EPoint)epIterat.next();
            if(epoint.getId() == entryPointId){
                return (int)epoint.getSize();
            }

        }
        return 0;
    }

    private void defineLinkableFrame() {
        //query the max fdata_stop value
        int maxStop = getEPSize(entrypointId);

        //draw a rectangle box around the annotations, also enable the link here
        StringBuffer urlsb = new StringBuffer(cir.getLinkUrl());
        urlsb.append("EP=");
        urlsb.append(entryPointAbb);
        String url = urlsb.toString();
        lc.appendTagStart("a");
 //     lc.appendTagAttribute("xlink:href", "javascript:");
        lc.appendTagAttribute("pointer-events", "visible");
//        lc.appendTagAttribute("onclick", "openLink('" + url + "')");
       lc.appendTagAttribute("xlink:href", url);
        lc.appendTagStartEnd();

        //add extra 10 pixcels on the top to make the frame looks nicer
        int height = (int) (maxStop * scale) + 5;
        //make sure the height is less than or equal to the annotation box height.
        int maxHeight = cir.getAnnotationBoxesHeight() + cir.getExtraTopPadding();
        height = height > maxHeight ? maxHeight : height;

        int width = (cir.getAnnotationBoxWidth() + cir.getAnnotationToFrameDistance()) * 2 + cir.getChromosomePanelInternalPaddingCenter();
        int x = getLeftAnnotationX() - cir.getAnnotationToFrameDistance();
        int y = cir.getAnnotationBoxesHeight() - height + cir.getExtraTopPadding();
        lc.appendIndentation(lc.INDENT_PLUS);
        lc.append("<rect");
        lc.appendTagAttribute("x", x);
        lc.appendTagAttribute("y", y);
        lc.appendTagAttribute("width", width);
        lc.appendTagAttribute("height", height);
        lc.appendTagAttribute("stroke", cir.getAnnotationFrameBorderColor());
        lc.appendTagAttribute("stroke-width", cir.getAnnotationFrameBorderWidth());
        lc.appendTagAttribute("fill", "none");
        lc.append("/>");
        lc.appendLineFeed();
        lc.changeIndentation(lc.INDENT_MINUS);

        if (lc.willRasterizeGif()) {
            lc.getSvgLinkTree().addLinkedArea(
                    new RectangleLinkedArea(x, y, width, height, url)
            );
        }

        lc.appendTagClose("a");
    }

    private void wrapTypeDataWithSVG(TypeData tdata, int x, int y, int width, int height, String orientation) {
        //define a svg element for the chromosome
        lc.appendTagStart("svg");
        lc.appendTagAttribute("x", x);
        lc.appendTagAttribute("y", y);
        lc.appendTagAttribute("width", width);
        lc.appendTagAttribute("height", height);
        lc.appendTagAttribute("viewBox", createViewBoxString(width, height));
//        lc.appendTagAttribute("keepAspectRatio", "xMidYMin slice");
        lc.appendTagStartEnd();
        tdata.generateSVG(lc, orientation);

        lc.appendTagClose("svg");

    }

    private void addAnnotationLabels() {
        int x = 0, y = 0;
        int diff = cir.getChromosomePanelHeight() - cir.getAnnotationBoxesHeight();

        if (cir.isAnnotationLabelVisible()) {
            //draw the annotation type abbreviation
            if (leftLabel != null) {
                x = getLeftAnnotationX() + cir.getAnnotationBoxWidth() / 2;
                y = cir.getAnnotationBoxesHeight() + diff / 3 + cir.getExtraTopPadding();
                drawLabel(x, y, leftLabel, null, "font-size:22px;");
            }
            if (rightLabel != null) {
                x = getRightAnnotationX() + cir.getAnnotationBoxWidth() / 2;
                y = cir.getAnnotationBoxesHeight() + diff / 3 + cir.getExtraTopPadding();
                drawLabel(x, y, rightLabel, null, "font-size:22px;");
            }
        }
        if (cir.isChromosomeLabelVisible()) {
            //draw the chromosome abbreviation
            x = cir.getChromosomePanelWidth() / 2;
            y = cir.getAnnotationBoxesHeight() + diff * 2 / 3 + cir.getExtraTopPadding();
            drawLabel(x, y, entryPointAbb.toUpperCase(), null, "font-size:22px;");
            //TODO find it!
        }
    }

    private int getLeftAnnotationX() {
        return cir.getChromosomePanelInternalPaddingSide();
    }

    private int getRightAnnotationX() {
        return cir.getChromosomePanelInternalPaddingSide() + cir.getAnnotationBoxWidth() + cir.getChromosomePanelInternalPaddingCenter();
    }
}
