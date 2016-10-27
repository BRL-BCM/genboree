package org.genboree.svg.compact;

import org.genboree.svg.GlobalContext;
import org.genboree.svg.ImageRequirements;

import java.util.HashMap;

/**
 * Created By: Alan
 * Date: Apr 12, 2003 3:12:08 PM
 */
public class CompactImageRequirements extends ImageRequirements {

    // ----------- Width and Height settings ------------------
//    public static final int GN_SVG_WIDTH = 1000;
//    public static final int GN_SVG_HEIGHT = 350;
    private static final int GN_SVG_INT_PADDING_TOP = 20;
    private static final int GN_SVG_INT_PADDING_LEFT = 100;
    private static final int GN_SVG_INT_PADDING_BOTTOM = 50;
    private static final int GN_SVG_INT_PADDING_RIGHT = 106;

    //extra top padding so the top of the frame line can be separated from the top of the annotation data
    //if the annotation data is has hits at the top.
    private static final int CS_EXTRA_TOP_PADDING = 10;

    private static final int CS_SVG_HEIGHT = 600;
    private static final int ANNO_BOX_ALL_BOX_HEIGHT = 500;

    public CompactImageRequirements(HashMap userOptions) {
        this.userOptions = userOptions;
        this.config = GlobalContext.getInstance().lookupConfigElement("image_settings/compact/user_options");
    }

    public int getImageWidth() {
        return getUserOptionInt("image_width");
    }

    public int getImageHeight() {
        return getUserOptionInt("image_height");
    }

    public int getImageInternalPaddingTop() {
        return GN_SVG_INT_PADDING_TOP;
    }

    public int getImageInternalPaddingLeft() {
        return GN_SVG_INT_PADDING_LEFT;
    }

    public int getImageInternalPaddingBottom() {
        return GN_SVG_INT_PADDING_BOTTOM;
    }

    public int getImageInternalPaddingRight() {
        return GN_SVG_INT_PADDING_RIGHT;
    }

    public int getChromosomePanelWidth() {
        return (getAnnotationBoxWidth() + getChromosomePanelInternalPaddingSide()) * 2 +
                getChromosomePanelInternalPaddingCenter();
    }

    public int getAnnotationFrameBorderWidth() {
        return getUserOptionInt("anno_frame_border_width");
    }

    public String getAnnotationFrameBorderColor() {
        return getUserOptionString("anno_frame_border_color");
    }

    public int getAnnotationToFrameDistance() {
        return getUserOptionInt("anno_to_frame_distance");
    }

    public int getChromosomePanelHeight() {
        return CS_SVG_HEIGHT;
    }

    public int getChromosomePanelInternalPaddingSide() {
        return getUserOptionInt("chromosome_panel_int_padding_side");
    }

    public int getChromosomePanelInternalPaddingCenter() {
        return getUserOptionInt("chromosome_panel_int_padding_center");
    }

    public int getAnnotationBoxWidth() {
        return getUserOptionInt("anno_bar_width");
    }

    public int getAnnotationBoxesHeight() {
        return ANNO_BOX_ALL_BOX_HEIGHT;
    }

    public int getExtraTopPadding() {
        return CS_EXTRA_TOP_PADDING;
    }

    public String getLinkUrl() {
        return getUserOptionString("link_url");
    }

    public int getLegendBoxToTextSpace() {
        return getUserOptionInt("legend_box_text_space");
    }

    public int getLegendTextToBoxSpace() {
        return getUserOptionInt("legend_text_box_space");
    }

    public int getLegendBoxSize() {
        return getUserOptionInt("legend_box_size");
    }

    public double getLegendTextCharWidth() {
        return getUserOptionDouble("legend_char_width");
    }

    public int getLegendLineSpacing() {
        return getUserOptionInt("legend_line_spacing");
    }

    public boolean isLegendVisible() {
        return getUserOptionBoolean("legend_box_visible");
    }

    public boolean isChromosomeLabelVisible() {
        return getUserOptionBoolean("chromosome_label_visible");
    }

    public boolean isAnnotationLabelVisible() {
        return getUserOptionBoolean("anno_label_visible");
    }

}
