package org.genboree.svg.imagemap;

/**
 * Created By: Alan
 * Date: May 21, 2003 10:00:49 PM
 */
abstract public class LinkedArea {
    protected String url = null;

    abstract String getShape();

    abstract String getTransformedCoords(SVGNode node, CoordinatesTransformer transformer);

    public String getUrl() {
        return url;
    }

    public void setUrl(String url) {
        this.url = url;
    }
}
