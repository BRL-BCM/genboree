package org.genboree.upload;

/**
 * User: tong Date: Aug 3, 2005 Time: 1:52:45 PM
 */
public interface RefSeqParams {
    public static final String[] metaReferencePoints =
    {
        "id", "class", "length"
    };
    public static final String[] metaAssembly =
    {
        "id", "start", "end", "class", "name", "tstart", "tend"
    };
    public static final String[] metaAnnotations =
    {
        "class", "name", "type", "subtype", "ref", "start", "stop",
        "strand", "phase", "score", "tstart", "tend", "text", "sequence", "freeStyleComments"
    };

    public static final int ANNO_CLASS = 0;
    public static final int ANNO_NAME = 1;
    public static final int ANNO_TYPE = 2;
    public static final int ANNO_SUBTYPE = 3;
    public static final int ANNO_REF = 4;
    public static final int ANNO_START = 5;
    public static final int ANNO_STOP = 6;
    public static final int ANNO_STRAND = 7;
    public static final int ANNO_PHASE = 8;
    public static final int ANNO_SCORE = 9;
    public static final int ANNO_TSTART = 10;
    public static final int ANNO_TEND = 11;
    public static final int ANNO_TEXT = 12;
    public static final int ANNO_SEQUENCE = 13;



    public static final int REF_NAME = 0;
    public static final int REF_GNAME = 1;
    public static final int REF_LENGTH = 2;


    public static final int ASSEM_ID = 0;
    public static final int ASSEM_START = 1;
    public static final int ASSEM_END = 2;
    public static final int ASSEM_CLASS = 3;
    public static final int ASSEM_NAME = 4;
    public static final int ASSEM_TSTART = 5;
    public static final int ASSEM_TEND = 6;


}
