package org.genboree.svg.imagemap;

/**
 * Created By: Alan
 * Date: May 21, 2003 11:50:58 PM
 */
public class CoordinatesTransformer {

    private static final int precision = 10000;
    public Point transformPoint(Point p, SVGNode node) {
        return null;
    }

    public Rect transformRect(Rect r, SVGNode node) {
        if (node.getParent() == null)
            return r;
        int x = r.x, y = r.y, width = r.width, height = r.height;
        while (node != null) {
            //All generated drawings so far uses the same width/height values for both
            //svg width/height and viewbox width/height
            if (node.parentWidth == node.vbWidth && node.parentHeight == node.vbHeight) {
                //no scaling, just transform the x/y values
                x += node.parentX;
                y += node.parentY;
            } else {
                //needs to do the transform + scaling
                double scalex = (double) node.parentWidth / (double) node.vbWidth;
                double scaley = (double) node.parentHeight / (double) node.vbHeight;
                double vbRatio = (double)node.vbWidth / (double)node.vbHeight;
                double ratio = (double) node.parentWidth / (double) node.parentHeight;
                //adjusts the scalex and scaley to keep the vbRatio as the images are
                //automatically shrinked during gif generation if the ratio != vbRatio
                double adjustedScalex = 0, adjustedScaley = 0;
                long roundedVbRatio = Math.round(vbRatio * precision);
                long roundedRatio = Math.round(ratio * precision);
                boolean shrinkx = false, shrinky = false;
                if(roundedVbRatio > roundedRatio) {
                    //shrink scaley to keep the vbRatio
                    adjustedScalex = scalex;
                    adjustedScaley = scaley * ratio / vbRatio;
                    shrinky = true;
                } else if (roundedVbRatio == roundedRatio){
                    adjustedScalex = scalex;
                    adjustedScaley = scaley;
                } else {
                    //shrink the scalex to keep the vbRatio
                    adjustedScalex = scalex * vbRatio / ratio;
                    adjustedScaley = scaley;
                    shrinkx = true;
                }
                //if the width or the height of the image is shrinked during the gif generation,
                //the element is automatically placed at the center. Therefore, we need to
                //introduce an offset values.
                int offsetx = shrinkx ? (int) Math.round(width * (scalex - adjustedScalex) / 2) : 0;
                int offsety = shrinky ? (int) Math.round(height * (scaley - adjustedScaley) / 2) : 0;
                x = (int) Math.round((x * scalex) + node.parentX) + offsetx;
                y = (int) Math.round((y * scaley) + node.parentY) + offsety;
                width = (int) Math.round(width * adjustedScalex);
                height = (int) Math.round(height * adjustedScaley);
            }
            node = node.getParent();
        }
        return new Rect(x, y, width, height);
    }
}
