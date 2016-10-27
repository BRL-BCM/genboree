/**
 * This class is responsible for returning the correct sub-class objects that are
 * suitable for a given SVG image type needs to be drawn.
 * Created By: Alan
 * Date: Apr 12, 2003 5:25:47 PM
 */
package org.genboree.svg;

import org.genboree.svg.compact.*;
import org.genboree.svg.full.*;

import java.util.HashMap;

public class ImageDrawingFactory {

    private static final int FULL = Constants.IMAGE_TYPE_GENOME;
    private static final int COMPACT = Constants.IMAGE_TYPE_ANNOTATIONS_ONLY;

    private ImageDrawingFactory() {
    }


    public static ImageRequirements getImageRequirements(int imageType, HashMap userOptions) {
        if (imageType == FULL)
            return new FullChromosomesImageRequirements(userOptions);
        if (imageType == COMPACT)
            return new CompactImageRequirements(userOptions);
        return null;
    }

    public static GenomeData getGenomeDataObject(int imageType, HashMap requirements) {
        if (imageType == FULL)
            return new FullChromosomesGenomeData(requirements);
        if (imageType == COMPACT)
            return new CompactGenomeData(requirements);
        return null;
    }

    public static SyntenyMapData getSyntenyMapDataObject(int imageType, HashMap requirements) {
        if (imageType == FULL)
            return new FullChromosomesSyntenyMapData(requirements);
        if (imageType == COMPACT)
            return new CompactSyntenyMapData(requirements);
        return null;
    }

    public static TemplateData getTemplateDataObject(int imageType, HashMap requirements) {
        if (imageType == FULL)
            return new FullChromosomesTemplateData(requirements);
        if (imageType == COMPACT)
            return new CompactTemplateData(requirements);
        return null;
    }

    public static TypeData getTypeDataLeftObject(int imageType, HashMap requirements) {
        if (imageType == FULL)
            return new FullChromosomesTypeDataLeft(requirements);
        if (imageType == COMPACT)
            return new CompactTypeData(requirements);
        return null;
    }

    public static TypeData getTypeDataRightObject(int imageType, HashMap requirements) {
        if (imageType == FULL)
            return new FullChromosomesTypeDataRight(requirements);
        if (imageType == COMPACT)
            return new CompactTypeData(requirements);
        return null;
    }

}

