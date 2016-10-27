package org.genboree.svg;

import java.io.IOException;
import org.genboree.util.Util;


abstract public class SVGData implements Constants {

    /**
     * Generates the SVG data to the local context. The data is generated in
     * a sequencial fashion. That is, several class will generate the relavant
     * SVG contents one by one and each of them is responsible for generating
     * only part of the SVG data.
     * Since database operations are involved, the method throws SQLException.
     * All the generated SVG contents are stored
     * in the local context object.
     * @param localContext
     */
    abstract public void generateSVG(LocalContext localContext) throws  IOException;

    //the reference to the local context object. It is passed in in
    //the genereateSVG() method.
    protected LocalContext lc = null;

    protected String createViewBoxString(int x, int y, int width, int height) {
        StringBuffer sb = new StringBuffer();
        sb.append(x);
        sb.append(' ');
        sb.append(y);
        sb.append(' ');
        sb.append(width);
        sb.append(' ');
        sb.append(height);
        return sb.toString();
    }

    protected String createViewBoxString(int width, int height) {
        StringBuffer sb = new StringBuffer();
        sb.append("0 0 ");
        sb.append(width);
        sb.append(' ');
        sb.append(height);
        return sb.toString();
    }

    /**
     * The x coordinate is the middle point of the text that will be rendered. while the y coordinate
     * is the baseline.
     * @param x
     * @param y
     * @param text
     */
    protected void drawLabel(int x, int y, String text, String cssClass, String inlineStyle) {
        lc.appendTagStart("text"); //TODO uncaught run time exception
        lc.appendTagAttribute("x", x);
        lc.appendTagAttribute("y", y);
        if (cssClass != null)
            lc.appendTagAttribute("class", cssClass);
        if (inlineStyle != null)
            lc.appendTagAttribute("style", inlineStyle);
        lc.appendTagAttribute("text-anchor", "middle");
        lc.appendTagStartEnd();
        lc.appendIndentation(lc.INDENT_PLUS);
        lc.append(Util.htmlQuote(text));
        lc.appendLineFeed();
        lc.changeIndentation(lc.INDENT_MINUS);
        lc.appendTagClose("text");
    }

}
