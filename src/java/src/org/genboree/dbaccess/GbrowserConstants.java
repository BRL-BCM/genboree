package org.genboree.dbaccess;

import org.genboree.util.Constants;

import java.io.File;

public class GbrowserConstants
{
    public static final String genboreeRoot = Constants.GENBOREE_HTDOCS;
    public static final File graphicsDir = new File( genboreeRoot, "graphics" );
    public static final File templateDir = new File( genboreeRoot, "xmlTemplates" );
    public static final String[] tvValues = { "Expand", "Compact", "Hidden", "Multicolor", "Expand with Names", "Expand with Comments" };
    public static final int PICT_BORDER_WIDTH = 120;
    public static final int MIN_PICT_WIDTH = 620;
    public static final int MAX_PICT_WIDTH = 3000;
    public static String[] zoomLabs = { "1.5X", "2X", "3X", "5X", "10X", "1.5X", "2X", "3X", "5X", "10X" };
    public static String[] zoomIds = { "in1_5X", "in2X", "in3X", "in5X", "in10X", "out1_5X", "out2X", "out3X", "out5X", "out10X" };
    public static long[] zoomNoms = { 2L, 1L, 1L, 1L, 1L, 3L, 2L, 3L, 5L, 10L };
    public static long[] zoomDens = { 3L, 2L, 3L, 5L, 10L, 2L, 1L, 1L, 1L, 1L };

}