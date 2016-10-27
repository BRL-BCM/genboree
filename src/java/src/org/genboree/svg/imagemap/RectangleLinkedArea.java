package org.genboree.svg.imagemap;

/**
 * Created By: Alan
 * Date: May 21, 2003 10:06:51 PM
 */
public class RectangleLinkedArea extends LinkedArea {
    public int x;
    public int y;
    public int width;
    public int height;

    public RectangleLinkedArea(int x1, int y1, int width, int height, String url) {
        this.x = x1;
        this.y = y1;
        this.width = width;
        this.height = height;
        this.url = url;
    }

    String getShape() {
        return "RECT";
    }

    String getTransformedCoords(SVGNode node, CoordinatesTransformer transformer) {
        Rect r = transformer.transformRect(new Rect(x, y, width, height), node);
//System.out.println("Exiting the RectangleLinkedArea");
//System.out.println( new StringBuffer().append(r.x).append(',').append(r.y).append(','). append(r.x + r.width).append(',').append(r.y + r.height).toString());
        return new StringBuffer().append(r.x).append(',').append(r.y).append(',').
                append(r.x + r.width).append(',').append(r.y + r.height).toString();
    }

}
