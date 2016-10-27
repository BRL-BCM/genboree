package org.genboree.svg.imagemap;

import java.util.HashMap;
import java.util.Iterator;

/**
 * Created By: Alan
 * Date: May 21, 2003 11:40:39 PM
 */
public class ImageMapCreator {

    private SVGLinkTree svgLinkTree = null;

    public String getMapAreas() {
        if (svgLinkTree == null)
            return "";

        CoordinatesTransformer transformer = new CoordinatesTransformer();
        StringBuffer sb = new StringBuffer();

        HashMap areas = svgLinkTree.getLinkedAreas();
        Iterator iter = areas.keySet().iterator();
        while (iter.hasNext()) {
            LinkedArea la = (LinkedArea) iter.next();
            SVGNode node = (SVGNode) areas.get(la);
            sb.append("<AREA SHAPE=\"").
		    append(la.getShape()).
		    append("\" COORDS=\"").
                    append(la.getTransformedCoords(node, transformer)).
                    append("\" HREF=\"").
//                    append("javascript:void(0);\" onClick=\"openLink('").
                    append(la.getUrl()).
//		    append("')").
		    append("\">\n");
        }
        return sb.toString();
    }

    public SVGLinkTree getSvgLinkTree() {
        return svgLinkTree;
    }

    public void setSvgLinkTree(SVGLinkTree svgLinkTree) {
        this.svgLinkTree = svgLinkTree;
    }

}
