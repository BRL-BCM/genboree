package org.genboree.upload;

public interface LffConstants{

    public static int bufferDelta = 10;
    public static int fdata2Table = 0;
    public static int fdata2_cvTable = 1;
    public static int fdata2_gvTable = 2;
    public static int fidTextTable = 3;
    public static int defaultNumberOfInserts = 15000 ; //TODO original value was 20000 now 5000
    public static int defaultMaxSizeOfBufferInBytes = 8 * 1024 * 1024; //TODO original value was 16 now 8
    public static int uploaderSleepTime = 1000 ;
    public static int webUploaderSleepTime = 1000;
    public static String[] specialCommentValuePairs = {"aHClasses=", "annotationColor=", "annotationCode="};
    public static long minFbinConstant = 1000L;
    public static long maxFbinConstant = 100000000L;
    public static long maxValueForInt = 2147483647;
    public static long minValueForInt = -2147483647;
    public static final int UPDATEATTRIBUTE = 0;
    public static final int APPENDATTRIBUTE = 1;
    public static final int DELETEATTRIBUTE = 2;
    public static final int INSERTANNOTATION = 4;
    public static final int DELETEANNOTATION = 5;
    public static final String TEMPLOGDIRLOCATION = "/tmp/uploaderDir";
    public static final String ROOTDIR_ANNOTATION_TABLE_VIEW = "/usr/local/brl/data/genboree";


}
