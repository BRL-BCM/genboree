package org.genboree.svg.imagemap;

import java.util.HashMap;

/**
 * Created By: Alan
 * Date: May 21, 2003 9:59:16 PM
 */
public class SVGLinkTree {
    private SVGNode location = null;
    private HashMap areas = new HashMap();

    public SVGLinkTree(SVGNode root) {
        location = root;
    }

    public void moveToChildNode(SVGNode node) {
        node.setParent(location);
        location = node;
    }

    public void moveUp() {
        location = location.getParent();
    }

    public void addLinkedArea(LinkedArea la) {
        areas.put(la, location);
    }

    public HashMap getLinkedAreas() {
        return areas;
    }
}
