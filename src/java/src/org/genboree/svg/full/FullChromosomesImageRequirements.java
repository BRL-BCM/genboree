package org.genboree.svg.full;

import org.genboree.svg.GlobalContext;
import org.genboree.svg.ImageRequirements;

import java.util.HashMap;

/**
 * Created By: Alan
 * Date: Apr 12, 2003 3:11:37 PM
 */
public class FullChromosomesImageRequirements extends ImageRequirements {

    // ----------- Width and Height settings ------------------
//    public static final int GN_SVG_WIDTH = 530;
//    public static final int GN_SVG_HEIGHT = 632;

    private static final int CS_SVG_WIDTH = 530;
    private static final int CS_SVG_HEIGHT = 632;

    private static final int CS_INT_MARGIN_LEFT = 30;
    private static final int CS_INT_MARGIN_TOP = 100;  //top margin before the start of the annotation boxes

    private static final int ANNO_BOX_WIDTH_LEFT = 150;
    private static final int ANNO_BOX_WIDTH_CENTER = 150;
    private static final int ANNO_BOX_WIDTH_RIGHT = 150;
    private static final int ANNO_BOX_INT_MARGIN_TOP = 35;   //top margin of the annotation boxes

    private static final int ANNO_BOX_SIDE_BOX_INT_MARGIN_SIDE = 105;  //the margin between the drawing in the sidebox and its outside box edge
    private static final int ANNO_BOX_SIDE_BOX_INT_MARGIN_CENTER = 20;
    private static final int ANNO_BOX_ALL_BOX_HEIGHT = 500;

    private static final int ANNO_BAR_WIDTH = 25;
    private static final int ANNO_MINIMUM_CURLY_BRACKET_HEIGHT = 50;

    private static final int COLOR_LEGEND_WIDTH = 130;
    private static final int COLOR_LEGEND_HEIGHT = 120;
    private static final int COLOR_LEGEND_LEGENDBOX_HEIGHT = 100;
    private static final int COLOR_LEGEND_COLORBOX_SIZE = 10;
    private static final int COLOR_LEGEND_LEGENDBOX_INT_PADDING = 5;
    private static final int COLOR_LEGEND_EXT_PADDING = 5;

    private static final int ANNO_COLOR_SIDEBOX_COLUMN_WIDTH = 15;

    public FullChromosomesImageRequirements(HashMap userOptions) {
        this.userOptions = userOptions;
        this.config = GlobalContext.getInstance().lookupConfigElement("image_settings/full/user_options");
    }

    public int getImageWidth() {
        return getUserOptionInt("image_width");
    }

    public int getImageHeight() {
        return getUserOptionInt("image_height");
    }

    public int getChromosomePanelWidth() {
        return CS_SVG_WIDTH;
    }

    public int getChromosomePanelHeight() {
        return CS_SVG_HEIGHT;
    }

    public int getChromosomePanelInternalPaddingTop() {
        return CS_INT_MARGIN_TOP;
    }

    public int getChromosomePanelInternalPaddingLeft() {
        return CS_INT_MARGIN_LEFT;
    }

    public int getAnnotationBoxWidthLeft() {
        return ANNO_BOX_WIDTH_LEFT;
    }

    public int getAnnotationBoxWidthCenter() {
        return ANNO_BOX_WIDTH_CENTER;
    }

    public int getAnnotationBoxWidthRight() {
        return ANNO_BOX_WIDTH_RIGHT;
    }

    public int getAnnotationBoxInternalPaddingTop() {
        return ANNO_BOX_INT_MARGIN_TOP;
    }

    public int getAnnotationBoxInternalPaddingOutside() {
        return ANNO_BOX_SIDE_BOX_INT_MARGIN_SIDE;
    }

    public int getAnnotationBoxInternalPaddingInside() {
        return ANNO_BOX_SIDE_BOX_INT_MARGIN_CENTER;
    }

    public int getAnnotationBoxesHeight() {
        return ANNO_BOX_ALL_BOX_HEIGHT;
    }

    public int getAnnotationBarWidth() {
        return ANNO_BAR_WIDTH;
    }

    public int getMinimumCurlyBracketHeight() {
        return ANNO_MINIMUM_CURLY_BRACKET_HEIGHT;
    }

    public int getColorSideboxColumnWidth() {
        return ANNO_COLOR_SIDEBOX_COLUMN_WIDTH;
    }

    public int getColorLegendWidth() {
        return COLOR_LEGEND_WIDTH;
    }

    public int getColorLegendHeight() {
        return COLOR_LEGEND_HEIGHT;
    }

    public int getColorLegendLegendBoxHeight() {
        return COLOR_LEGEND_LEGENDBOX_HEIGHT;
    }

    public int getColorLegendColorboxSize() {
        return COLOR_LEGEND_COLORBOX_SIZE;
    }

    public int getColorLegendLegendBoxInternalPadding() {
        return COLOR_LEGEND_LEGENDBOX_INT_PADDING;
    }

    public int getColorLegendExternalPadding() {
        return COLOR_LEGEND_EXT_PADDING;
    }

    public String getColorLegendTitleText() {
        return getUserOptionString("color_legend_title_text");
    }

    public boolean isColorLegendVisible() {
        return getUserOptionBoolean("color_legend_visible");
    }

    public boolean isChromosomeLabelVisible() {
        return getUserOptionBoolean("chromosome_label_visible");
    }

    public boolean isAnnotationSideLabelVisible() {
        return getUserOptionBoolean("anno_side_label_visible");
    }
}
