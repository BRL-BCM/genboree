package org.genboree.svg;

/**
 * This class defines a set of constants that are references
 * in various places in the codes.
 */
public interface Constants {

    /* Main object contains all the info needed by the graphic */

    public static final String GENOMEINFO = "genomeinfo";

    // ------------ Name of the CSS classes used in the SVG doc --------------
    // GN: Genome, CS: Chromosome

    /**
     * The css class used for the genome svg element
     */
    public static final String CSS_GN_SVG = "rootSvg";

    /**
     * The css class used for the chromosome svg element
     */
    public static final String CSS_CS_SVG = "csSvg";

    /**
     * The css class used for the center template svg element
     */
    public static final String CSS_TEMPLATE_IMAGE = "templateImage";

    /**
     * The css class used for the title text of the annotations
     */
    public static final String CSS_ANNOTATION_TITLE = "annotationTitle";

    /**
     * The css class used for the color legend title area
     */
    public static final String CSS_COLOR_LEGEND_TITLE_AREA = "clTitleArea";

    /**
     * The css class used for the color legend title text element
     */
    public static final String CSS_COLOR_LEGEND_TITLE_TEXT = "clTitleText";

    /**
     * The css class used for the color legend legendbox area
     */
    public static final String CSS_COLOR_LEGEND_LEGENDBOX_AREA = "clLegendboxArea";

    /**
     * The css class used for the color legend colorbox
     */
    public static final String CSS_COLOR_LEGEND_COLORBOX = "clColorbox";

    /**
     * The css class used for the color legend colorbox
     */
    public static final String CSS_COLOR_LEGEND_COLORBOX_LABEL = "clColorboxLabel";

    /**
     * The css class used for the "cover" elements when it is visible
     */
    public static final String CSS_COVER_VISIBLE = "coverVisible";

    /**
     * The css class used for the big labels of the chromosomes that are displayed at the global zoooming.
     */
    public static final String CSS_CS_BIGLABEL = "csBigLabel";


    // ------------  Keys used to retrieve the HTTP client request parameter  ------------
    /**
     * Name of the parameter indicates if the output format should be gif format.
     */
    public static final String HTTP_PARAM_FORMAT_GIF = "gif";

    public static final String GENOME_FILTER = "genomeFilter";
    public static final String CHROMOSOME_FILTER = "chromosomeFilter";
    /**
     * A unique identifier to handle the image resolution Added by Manuel 06-10-03.
     */
    public static final String HTTP_PARAM_NEWRESOLUTION = "newResolution";
    public static final String HTTP_PARAM_FORMAT = "imageFormat";
    public static final String HTTP_PARAM_JPEG_QUALITY = "JPEGquality";
    public static final String IMAGE_FILE_ABSOLUTE_NAME = "imageFullName";
    public static final String MAP_FILE_ABSOLUTE_NAME = "mapFullName";
    public static final String SVG_FILE_ABSOLUTE_NAME = "svgFullName";

    /**
     * A unique identifier to retrieve a generated Image object from the session.
     */
    public static final String HTTP_PARAM_UID = "uid";
    /**
     * Name of the parameter indicates if the the browser is capable of displaying SVG images.
     */
    public static final String HTTP_PARAM_SVG_CAPABLE = "svgCapable";
    /**
     * Name of the specieId parameter in the request that the clients sends over.
     */
    public static final String HTTP_PARAM_SPECIEID = "specieId";
    /**
     * Name of the svgType parameter in the request that the clients sends over.
     */
    public static final String HTTP_PARAM_SVGTYPE = "svgType";
    /**
     * Name of the svgType parameter in the request that the clients sends over.
     */
    public static final String HTTP_PARAM_CHROMOSOME = "chromosome";
    /**
     * Indicates that the image type is compact.
     */
    public static final String HTTP_USEROPTION_COMPACT = "compact.user_options";
    /**
     * Indicates that the image type is full.
     */
    public static final String HTTP_USEROPTION_FULL = "full.user_options";
    /**
     * The key used to retrieve cached template SVG data
     */
    public static final String IMAGE_KEY = "image";
    /**
     * The key used to retrieve cached template SVG data
     */
    public static final String TEMPLATE_CACHE_KEY = "cache.templateSVG";

    // ----------- Type of the SVG image that is drawn ----------------
    /**
     * SVG image that contains all chromosomes for a given specie.
     */
    public static final int IMAGE_TYPE_GENOME = 1;
    /**
     * SVG image that contains only the annotations for a given specie.
     */
    public static final int IMAGE_TYPE_ANNOTATIONS_ONLY = 2;


    // ------------ Other constants used ---------------------
    /**
     * The string of the left subtype, which indicates the data should be draw as the left annotation.
     */
    public static final String SUBTYPE_LEFT = "left";
    /**
     * The string of the right subtype, which indicates the data should be draw as the right annotation.
     */
    public static final String SUBTYPE_RIGHT = "right";

    /**
     * The key to keep the generated svg link tree in the session.
     */
    public static final String SVGLINKTREE = "svglinktree";

    /**
     * The type of the image: compact
     */
    public static final String TYPE_COMPACT = "compact";

    /**
     * The type of the image: full
     */
    public static final String TYPE_FULL = "full";
    public static final String TYPE_SINGLE_CHROMOSOME = "singleChromosome";


}
