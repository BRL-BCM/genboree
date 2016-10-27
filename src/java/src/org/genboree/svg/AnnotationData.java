package org.genboree.svg;

/**
 * Base class for the chromosome annotation column classes. Chromosome annotation column is the
 * vertical boxes on the chromosome panel that displays the mouse/rat/human chromosomes.
 * Created By: alan
 * Date: Mar 25, 2003 7:03:12 PM
 */
abstract public class AnnotationData extends SVGData {
    protected int entrypointSize = 0;
    protected int entrypointId = 0;

    protected double scale = 0;
    protected int maxEntrypointSize = 0;
    protected int maxTemplateSize = 0;
    protected int templateBoxSize = 0;


    public int getEntrypointId() {
        return entrypointId;
    }

    public void setEntrypointId(int entrypointId) {
        this.entrypointId = entrypointId;
    }

    public int getEntrypointSize() {
        return entrypointSize;
    }

    public void setEntrypointSize(int entrypointSize) {
        this.entrypointSize = entrypointSize;
    }

    public double getScale() {
        return scale;
    }

    public void setScale(double scale) {
        this.scale = scale;
    }

    public int getMaxEntrypointSize() {
        return maxEntrypointSize;
    }

    public void setMaxEntrypointSize(int maxEntrypointSize) {
        this.maxEntrypointSize = maxEntrypointSize;
    }

    public int getMaxTemplateSize() {
        return maxTemplateSize;
    }

    public void setMaxTemplateSize(int maxTemplateSize) {
        this.maxTemplateSize = maxTemplateSize;
    }

    public int getTemplateBoxSize() {
        return templateBoxSize;
    }

    public void setTemplateBoxSize(int templateBoxSize) {
        this.templateBoxSize = templateBoxSize;
    }


}
