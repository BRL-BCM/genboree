package org.genboree.svg;


/**
 * This class is responsible to draw the SVG graphics that are retrieved from the database directly. These include
 * both the center box and the color label box.
 * Created By: alan
 * Date: Mar 12, 2003 10:07:56 PM
 */
abstract public class TemplateData extends AnnotationData {

    protected int templateId = 0;
    protected String labelLineOne = null;
    protected String labelLineTwo = null;

    public void generateSVG(LocalContext localContext){
    }

    /**
     * Retrieve the width and height info from the template data, which is needed for fit the template
     * into the available viewport.
     * @param templateData
     */
    private int[] retrieveWidthHeight(String templateData) {
        int width = 0, height = 0;
        String data = templateData.toLowerCase();
        //need to find out the width and height info, which is stored in the svg tag
        int idx = data.indexOf("<svg");
        if (idx < 0)
            throw new IllegalArgumentException("No <SVG> tag defined in the template data: ftemplateId = " + templateId);
        //the width
        int i = data.indexOf("width=\"", idx);
        if (i > 0) {
            int j = data.indexOf('"', i + 7);
            if (j > 0) {
                String s = data.substring(i + 7, j);
                width = (int) Math.round(Double.parseDouble(s));
            }
        }
        //the height
        i = data.indexOf("height=\"", idx);
        if (i > 0) {
            int j = data.indexOf('"', i + 8);
            if (j > 0) {
                String s = data.substring(i + 8, j);
                height = (int) Math.round(Double.parseDouble(s));
            }
        }
        return new int[]{width, height};
    }

    public int getTemplateId() {
        return templateId;
    }

    public void setTemplateId(int templateId) {
        this.templateId = templateId;
    }

    public String getLabelLineOne() {
        return labelLineOne;
    }

    public void setLabelLineOne(String labelLineOne) {
        this.labelLineOne = labelLineOne;
    }

    public String getLabelLineTwo() {
        return labelLineTwo;
    }

    public void setLabelLineTwo(String labelLineTwo) {
        this.labelLineTwo = labelLineTwo;
    }
}
