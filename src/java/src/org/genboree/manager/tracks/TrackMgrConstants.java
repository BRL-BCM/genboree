package org.genboree.manager.tracks;

/**
 * User: tong Date: Jul 19, 2005 Time: 3:10:37 PM
 */
public class TrackMgrConstants
{
    public static final int MODE_DEFAULT = -1 ;
    public static final int MODE_RENAME = 0 ;
    public static final int MODE_DELETE = 1 ;
    public static final int MODE_ORDER = 2 ;
    public static final int MODE_STYLES = 3 ;
    public static final int MODE_URL = 4 ;
    public static final int MODE_CLASSIFY = 5 ;
    public static final int MODE_ACCESS = 6 ;
    public static final int MODE_FILES = 7 ;

    public static final String[] btnApply = {"submit", "btnApply", " Save ", null};
    public static final String[] btnReset = {"reset", "btnReset", " Reset ", null};
    public static final String[] btnDelete = {"submit", "btnDelete", " Delete ", null};
    public static final String[] btnPreview = {"submit", "btnPreview", "Preview", null};
    public static final String[] btnSetDefault = {"submit", "btnSetDefault", "Set As Default", null};
    public static final String[] btnLoadDefault = {"submit", "btnLoadDefault", "Load Default", null};
    public static final String[] sampleStyleUrls =
    {
      "/images/AnchoredArrows.gif",
      "/images/Barbed-WireRectangle.gif",
      "/images/Barbed-WireRectangle_noLine.gif",
      "/images/BoxedAnnotations.gif",
      "/images/HalfPaired-EndAnnotation.gif",
      "/images/LabelWithinRectangle.gif",
      "/images/Line-LinkedAnnotations.gif",
      "/images/Line-LinkedAnnotationsWithSeq.gif",
      "/images/Line-Linked(gaptags).gif",
      "/images/Paired-EndAnnotations.gif",
      "/images/Score-BasedBarchart(big).gif",
      "/images/Score-BasedBarchart(small).gif",
      "/images/Score-BasedBarchart(big).gif",
      "/images/Score-BasedBarchart(small).gif",
      "/images/ScoreColored(fadetowhite).gif",
      "/images/ScoreColored(fadetogray).gif",
      "/images/ScoreColored(fadetoblack).gif",
      "/images/ScoreColored(fix).gif",
      "/images/SimpleRectangle.gif",
      "/images/SimpleRectangle(gaptags).gif",
      "/images/chart.gif",
      "/images/BidirectionalBarChart.png",
      "/images/BidirectionalBarChart.png"
    };

    public static final String[] sampleStyleIds =
    {
      "tag_draw",
      "barbed_wire_draw",
      "barbed_wire_noLine_draw",
      "cdna_draw",
      "singleFos_draw",
      "chromosome_draw",
      "gene_draw",
      "sequence_draw",
      "groupNeg_draw",
      "bes_draw",
      "largeScore_draw",
      "scoreBased_draw",
      "local_largeScore_draw",
      "local_scoreBased_draw",
      "fadeToWhite_draw",
      "fadeToGray_draw",
      "fadeToBlack_draw",
      "differentialGradient_draw",
      "simple_draw",
      "negative_draw",
      "pieChart_draw",
      "bidirectional_draw_large",
      "bidirectional_local_draw_large"
    };

    public static final String[] modeIds =
    {
      "Rename", "Delete", "Order", "Styles", "URL", "Classify", "Access", "Files"
    } ;

    public static final String[] modeLabs =
    {
      "Rename", "Delete", "Order", "Style&nbsp;Setup", "URL", "Classify", "Access", "&quot;Big*&quot;&nbsp;Files"
    } ;
} ;
