package org.genboree.svg.full;

import org.genboree.svg.*;
import org.genboree.svg.imagemap.RectangleLinkedArea;
import org.genboree.svg.imagemap.SVGNode;
import org.genboree.dbaccess.VGPaint;
import java.util.HashMap;


public class FullChromosomesSyntenyMapData extends SyntenyMapData {
    protected String csLabelLineOne = null;
    protected String csLabelLineTwo = null;
    private FullChromosomesImageRequirements fir = null;
    private int panelHeight = 0;
    private static final String leftStr = "left";
    private static final String rightStr = "right";

    /* the links are going to be fix so I need to fix this */

    public FullChromosomesSyntenyMapData(HashMap requirements){
        super(requirements);
    }

    /**
     * Generates the SVG data for a single chromosome synteny map.
     * @param localContext
     */
    public void generateSVG(LocalContext localContext){
        lc = localContext;
        fir = (FullChromosomesImageRequirements) lc.getImageRequirements();

        if (lc.singleChromosomeOnly())
            panelHeight = csHeight;
        else
            panelHeight = fir.getChromosomePanelHeight();

        //retrieve the link info
        retrieveLinkInfo();

        //define a svg element for the chromosome
        lc.appendTagStart("svg");
        lc.appendTagAttribute("class", CSS_CS_SVG);
        lc.appendTagAttribute("id", "csNode" + entrypointId);  //the id is used in the animation
        lc.appendTagAttribute("x", csX);
        lc.appendTagAttribute("y", csY);
        lc.appendTagAttribute("width", csWidth);
        lc.appendTagAttribute("height", csHeight);
        lc.appendTagAttribute("viewBox", createViewBoxString(fir.getChromosomePanelWidth(), panelHeight));
//        lc.appendTagAttribute("viewBox", createViewBoxString(fir.getChromosomePanelWidth(), fir.getChromosomePanelHeight()));
//        lc.appendTagAttribute("keepAspectRatio", "xMidYMin slice");
        lc.appendTagStartEnd();

        if (lc.willRasterizeGif()) {
            lc.getSvgLinkTree().moveToChildNode(
                    new SVGNode(csX, csY, csWidth, csHeight,
                            0, 0, fir.getChromosomePanelWidth(), panelHeight));
        }

        //also need to draw a rectangle to capture the mouse click
        lc.appendIndentation(lc.INDENT_PLUS);
        lc.append("<rect");
        lc.appendTagAttribute("x", 0);
        lc.appendTagAttribute("y", 0);
        lc.appendTagAttribute("width", fir.getChromosomePanelWidth());
        lc.appendTagAttribute("height", panelHeight);
        if (lc.isDebug())
            lc.appendTagAttribute("stroke", "maroon");
        lc.appendTagAttribute("fill", "none");
        lc.appendTagAttribute("pointer-events", "visible");
        lc.append("/>");
        lc.appendLineFeed();
        lc.changeIndentation(lc.INDENT_MINUS);

        //generate SVG for the three types placed at the left, center, and the right
        generateTypeDataSVG();

        //define the hot-area: the linkable blocks on the screen
        defineLinkArea();

        //add a "cover" group of elements to hide the linked area and display the global level chromosome names
        if (!lc.singleChromosomeOnly())
            addCover();

        //close up the svg document
        lc.appendIndentation(lc.INDENT_MINUS);
        lc.appendTagClose("svg");

        if (lc.willRasterizeGif())
            lc.getSvgLinkTree().moveUp();
    }

    protected void addCover() {
        //first add a group
        lc.appendTagStart("g");
        lc.appendTagAttribute("id", "cover");
        lc.appendTagAttribute("class", CSS_COVER_VISIBLE);
        lc.appendTagStartEnd();

        //a rectangle box that hides the underline linked area
        int x = fir.getChromosomePanelInternalPaddingLeft() + fir.getAnnotationBoxInternalPaddingOutside();
        int y = fir.getChromosomePanelInternalPaddingTop() + fir.getAnnotationBoxInternalPaddingTop();
        int width = (fir.getAnnotationBarWidth() + fir.getAnnotationBoxInternalPaddingInside()) * 2 +
                fir.getAnnotationBoxWidthCenter();
        int height = (int) (entrypointSize * scale);
        lc.appendTagStart("rect");
        lc.appendTagLocationSizeAttributes(x, y, width, height);
        if (lc.isDebug())
            lc.appendTagAttribute("stroke", "green");
        lc.appendTagAttribute("fill", "none");
        lc.appendTagAttribute("pointer-events", "visible");
        lc.append("/>"); //closed the "rect" element
        lc.appendLineFeed();
        lc.changeIndentation(lc.INDENT_MINUS);

        //a rectangle box that shield the chromosome title
        x = 0;
        y = 0;
        width = fir.getChromosomePanelWidth();
        height = fir.getChromosomePanelInternalPaddingTop();
        lc.appendTagStart("rect");
        lc.appendTagLocationSizeAttributes(x, y, width, height);
        lc.appendTagAttribute("fill", "white");
        lc.appendTagAttribute("pointer-events", "visible");
        lc.append("/>"); //closed the "rect" element
        lc.appendLineFeed();
        lc.changeIndentation(lc.INDENT_MINUS);

        //a big label that is visible at the global zooming level
        drawLabel(fir.getChromosomePanelWidth() / 2, 60, csLabelLineOne, CSS_CS_BIGLABEL, null);
        drawLabel(fir.getChromosomePanelWidth() / 2, 110, csLabelLineTwo, CSS_CS_BIGLABEL, null);

        lc.appendTagClose("g");
    }

    protected void defineLinkArea() {
        int x = fir.getChromosomePanelInternalPaddingLeft() + fir.getAnnotationBoxInternalPaddingOutside();
        int y = fir.getChromosomePanelInternalPaddingTop() + fir.getAnnotationBoxInternalPaddingTop();
        int width = (fir.getAnnotationBarWidth() + fir.getAnnotationBoxInternalPaddingInside()) * 2 +
                fir.getAnnotationBoxWidthCenter();
        int sizePerLinkBox = entrypointSize / linkTimes;
        int height = (int) (sizePerLinkBox * scale);

        int start = entrypointSize;
        int stop = entrypointSize - sizePerLinkBox;
        //define the bottom of the last link area so it always cover the whole chromosome (offset the rounding errors)
        int lastLinkAreaEndingY = y + (int) (entrypointSize * scale);
        for (int i = 0; i < linkTimes; i++) {
            if (i == linkTimes - 1) {
                height = lastLinkAreaEndingY - y;
                stop = 1;
            }

            String link = formLinkHref(linkHref, stop, start);
            //the link
            lc.appendTagStart("a");
            //define id for the linked areas to prevent the animation when a link is clicked.
//            lc.appendTagAttribute("id", "genboreeLink");
//            lc.appendTagAttribute("xlink:href", "javascript:");
//            lc.appendTagAttribute("onclick", "openLink('" + link + "')");
            lc.appendTagAttribute("xlink:href", link);
            lc.appendTagStartEnd();
            //enclosed rectangle link area
            lc.appendTagStart("rect");
            lc.appendTagLocationSizeAttributes(x, y, width, height);
            lc.appendTagAttribute("fill", "none");
            lc.appendTagAttribute("stroke", lc.isDebug() ? "red" : "none");
            lc.appendTagAttribute("pointer-events", "visible");
            lc.append("/>");
            lc.appendLineFeed();

            if (lc.willRasterizeGif()) {
                lc.getSvgLinkTree().addLinkedArea(
                        new RectangleLinkedArea(x, y, width, height, link)
                );
            }

            lc.changeIndentation(lc.INDENT_MINUS);
            //close the link
            lc.appendTagClose("a");
            y += height;
            start = stop;
            stop -= sizePerLinkBox;

        }
    }

    protected void retrieveLinkInfo() {
            linkHref = "/java-bin/gbrowser.jsp?entryPointId="
                    + this.getEntrypointName() +
                    "&refSeqId=" + this.getGenomeInfo().getRefSeqId() +
                    "&from=$start" +
                    "&to=$stop";// +
//                    "&amp;isPublic=YES";
    }

    protected void generateTypeDataSVG() {
        TypeData left = null;
        TypeData right = null;
        VGPaint tempVGPInfo = null;
        VGPaint.VGPFentrypoint vgpEpoint = null;

        tempVGPInfo = genomeInfo.getVgp();
        vgpEpoint = tempVGPInfo.findEntryPoint(this.getEntrypointName());
        int ftCategory = vgpEpoint.getFcategoryCount();
        for(int fc = 0; fc < ftCategory; fc++){
            VGPaint.VGPFcategory myFcategory = vgpEpoint.getFcategoryAt(fc);

            if(myFcategory.getOrientation().equalsIgnoreCase("right")){
                    right = ImageDrawingFactory.getTypeDataRightObject(lc.getImageType(), requirements);
                    right.setTypeId(fc);
//                    right.setType(myFcategory.getName());
                    right.setType(myFcategory.getDescription());
                    right.setSubtype(myFcategory.getOrientation());
            }
            else if(myFcategory.getOrientation().equalsIgnoreCase("left")){
                    left = ImageDrawingFactory.getTypeDataLeftObject(lc.getImageType(), requirements);
                    left.setTypeId(fc);
                    left.setType(myFcategory.getDescription());
                    left.setSubtype(myFcategory.getOrientation());
            }
            else{
                System.err.println("Invalid subtype: entrypointId = " + entrypointId);
                System.err.flush();
            }
        }

        //need the specie name as the label
        StringBuffer sb = new StringBuffer();
        sb.append(entrypointType);
        sb.append(' ');
        sb.append(entrypointName);
        String centerLabelTwo = sb.toString();

        TemplateData templateData = ImageDrawingFactory.getTemplateDataObject(lc.getImageType(), requirements);
        templateData.setLabelLineOne(vgpEpoint.getCenter_header());
//        templateData.setLabelLineOne(refseqSpecies);
//        templateData.setLabelLineTwo(centerLabelTwo);

        //also used as the big label of the chromosome
        csLabelLineOne = refseqSpecies;
        csLabelLineTwo = centerLabelTwo;

//        System.out.println("refid="+refseqId+", entrypointId="+entrypointId+", left="+left+", right="+right+", template="+templateData);
        //set the fentrypointId, fentrypoint_size, and scale for the TypeData objects
        //and delegate the drawings to the TypeData classes
        if (left != null) {
            setFields(left);
            left.setTemplateBoxSize(templateBoxSize);
            left.generateSVG(lc, leftStr);
        }
        if (templateData != null) {
            setFields(templateData);
            templateData.setTemplateBoxSize(templateBoxSize);
            templateData.generateSVG(lc);
        }
        if (right != null) {
            setFields(right);
            right.setTemplateBoxSize(templateBoxSize);
            right.generateSVG(lc, rightStr);
        }
    }

    protected String formLinkHref(String href, int start, int end) {
        StringBuffer sb = new StringBuffer();
        href = href.replaceAll("&", "&amp;");
        int idxStart = href.indexOf(LINK_START_PATTERN);
        int idxEnd = href.indexOf(LINK_END_PATTERN);
        if (idxStart == -1 || idxEnd == -1)
            return href;
        if (idxStart < idxEnd) {
            sb.append(href.substring(0, idxStart));
            sb.append(start);
            sb.append(href.substring(idxStart + LINK_START_PATTERN.length(), idxEnd));
            sb.append(end);
            int endPosition = idxEnd + LINK_END_PATTERN.length();
            if (endPosition < href.length())
                sb.append(href.substring(endPosition));
        } else {
            sb.append(href.substring(0, idxEnd));
            sb.append(end);
            sb.append(href.substring(idxEnd + LINK_END_PATTERN.length(), idxStart));
            sb.append(start);
            int endPosition = idxStart + LINK_START_PATTERN.length();
            if (endPosition < href.length())
                sb.append(href.substring(endPosition));
        }
        return sb.toString();
    }
}
