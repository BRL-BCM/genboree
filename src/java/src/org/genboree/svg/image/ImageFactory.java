package org.genboree.svg.image;

import org.genboree.svg.Constants;
import org.genboree.svg.GenomeData;
import org.genboree.svg.ImageDrawingFactory;
import org.genboree.svg.LocalContext;
import org.genboree.svg.imagemap.SVGLinkTree;
import java.io.IOException;
import java.util.HashMap;


/**
 * This class is responsible for generating a SVG or GIF image and
 * Created By: Alan
 * Date: May 22, 2003 9:46:38 PM
 */
public class ImageFactory implements Constants {

    public static Image generateImage(HashMap requirements) throws IOException {
        boolean gifOption = "true".equalsIgnoreCase((String) requirements.get(HTTP_PARAM_FORMAT_GIF));
        if (gifOption)
            return generateGIFImage(requirements);
        else
            return generateSVGImage(requirements);
    }

    private static Image generateGIFImage(HashMap requirements) throws IOException{
        return new GIFImage((SVGImage) generateSVGImage(requirements));
    }


    private static Image generateSVGImage(HashMap requirements) throws IOException {

        //create the local context for this SVG image generation request.
        LocalContext lContext = new LocalContext();
        lContext.setDebug(requirements.get("debug") != null);

        //check if the svg image will be rasterized later
        boolean willRasterize = "true".equals(requirements.get(HTTP_PARAM_FORMAT_GIF));
        if (willRasterize) {
            //do things differently if the svg will be rasterized to gif format
            //such as no custom menu
            lContext.setRasterizeGif(true);
        }


        //decide the type of the image that will be drawn
        String type = (String) requirements.get(HTTP_PARAM_SVGTYPE);
        if (TYPE_COMPACT.equalsIgnoreCase(type)) {
            lContext.setImageType(IMAGE_TYPE_ANNOTATIONS_ONLY);
        } else {
            lContext.setImageType(IMAGE_TYPE_GENOME);
            //test if only display one chromosome
            String chromosome = (String) requirements.get(HTTP_PARAM_CHROMOSOME);
            if (chromosome != null && !chromosome.equals("")) {
                //only display the specific chromosome
                lContext.setChromosome(chromosome);
            }
        }


        String svg = null;
        SVGLinkTree tree = null;
        GenomeData genomeData = null;

        //top level entry point for generating the SVG image
        genomeData = ImageDrawingFactory.getGenomeDataObject(lContext.getImageType(), requirements);
        genomeData.generateSVG(lContext);
        svg = lContext.getSVGContent();
        if (willRasterize)
            tree = lContext.getSvgLinkTree();
        lContext.cleanup();


        SVGImage svgImage = new SVGImage(svg, tree);
        svgImage.setImageWidth(genomeData.getImageWidth());
        svgImage.setImageHeight(genomeData.getImageHeight());
        return svgImage;
    }


}
