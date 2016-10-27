package org.genboree.svg.imagemap;

/**
 * Created By: Alan
 * Date: May 21, 2003 9:59:31 PM
 */
public class SVGNode {
    public int parentX = 0;
    public int parentY = 0;
    public int parentWidth = 0;
    public int parentHeight = 0;
    public int vbX = 0;
    public int vbY = 0;
    public int vbWidth = 0;
    public int vbHeight = 0;

    private SVGNode parent = null;


    public SVGNode(int parentX, int parentY, int parentWidth, int parentHeight,
                   int vbX, int vbY, int vbWidth, int vbHeight) {
        this.parentX = parentX;
        this.parentY = parentY;
        this.parentWidth = parentWidth;
        this.parentHeight = parentHeight;
        this.vbX = vbX;
        this.vbY = vbY;
        this.vbWidth = vbWidth;
        this.vbHeight = vbHeight;
    }

    public SVGNode getParent() {
        return parent;
    }

    public void setParent(SVGNode parent) {
        this.parent = parent;
    }
}
