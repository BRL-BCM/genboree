
#ifndef _optimizedGB_h
#define _optimizedGB_h

#define _ISOC9X_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <time.h>
#include <assert.h>
#include <math.h>
#include <string.h>
#include <libgen.h>
#include <fcntl.h>
#include <dirent.h>
#include <unistd.h>
#include <getopt.h>
#include <zlib.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/timeb.h>
#include <search.h>
#include <ctype.h>
#include <stdbool.h>
#include "/usr/local/brl/local/include/gd.h"
#include "/usr/local/brl/local/include/gdfontt.h"
#include "/usr/local/brl/local/include/gdfonts.h"
#include "/usr/local/brl/local/include/gdfontmb.h"
#include "/usr/local/brl/local/include/gdfontl.h"
#include "/usr/local/brl/local/include/gdfontg.h"
#include "myTest.h"
#include <pcre.h>
#include "/usr/local/brl/local/include/glib-2.0/glib.h"
#include "/usr/local/brl/local/include/glib-2.0/glib/gchecksum.h"
#include "/usr/local/brl/local/include/glib-2.0/glib/gtypes.h"
#include <fcntl.h>
#include <sys/mman.h>
#include "/usr/local/brl/local/mysql/include/mysql/my_global.h"
#include "/usr/local/brl/local/mysql/include/mysql/mysql.h" /* Include the main mysql include */
#include "/usr/local/brl/local/mysql/include/mysql/m_string.h" /* Include the  mysql string */

#ifndef USEODIRECTFLAG
    #define USEODIRECTFLAG 0
#endif
#ifndef PROVIDE_ADVICE
    #define PROVIDE_ADVICE 0
#endif

#define MAXLENGTHOFTEMPSTRING 1024 * 1024 
#define OVECCOUNT 300    /* should be a multiple of 3 */
#define BIGBUFFER 555555
#define TRACK_HEIGHT           5
#define GENE_HEIGHT     8
#define RIGHT_PANEL_SIZE	60
#define MAXCHARACTERSTOUSE	15
#define NUMBEROFDOTS	0
#define SPACEBEFORETEXT    5

#define  MAXNUMBERLINESINTRACK   60
#define  ADDVALUE 80
#define MAXNUMBERSUBSTRINGS 20
#define TRACKPERMISSION 0002
#define MAXSPACEBEFOREBORDER 5
#define ADDSPACETOPIECHARTLINK 0
#define MAXLENGTHFTYPEATTTEXT 21
#define SPACEAFTERTRACKNAME 20
#define SPACEBETWEENFTYPEATT 11
#define SPACEFORTINYFONT 8
#define LOCALUSER 0x01
#define LOCALDEFAULT 0x02
#define SHAREDUSER 0x03
#define SHAREDDEFAULT 0x04
#define isLocalDb(X)  ((X & LOCALUSER ) == LOCALUSER)  ^ (( X & LOCALDEFAULT ) == LOCALDEFAULT)
#define isSharedDb(X) ((X & SHAREDUSER) == SHAREDUSER)  ^ (( X & SHAREDDEFAULT) == SHAREDDEFAULT)


#define TOWIGGLE(LOWERLIMIT, SCALE, VALUE, DENOM) ((VALUE -LOWERLIMIT) / SCALE) * DENOM
#define WIGGLEFORMULA(LOWERLIMIT, SCALE, BYTE, DENOM) LOWERLIMIT + (SCALE * ((double)BYTE/DENOM))
#define OPTWIGGLEFORMULA(LOWERLIMIT, PRECALC, BYTE) LOWERLIMIT + (PRECALC * (double)BYTE)
#define xDEBUG(flag, code) if (flag) {code;}

#define DEB_ADDHDANNOTATIONTOPIXELMAP 0
#define DEB_ADDHDANNOTATIONTOPIXELMAP4 0
#define DEB_ADDHDANNOTATIONTOPIXELMAP5 0
#define DEB_ADDHDANNOTATIONTOPIXELMAP_RUNLOOP 0
#define DEB_MAINDRAW 0
#define DEB_GETBLOCKLEVELDATAINFO 0
#define DEB_WIGLARGE_DRAWGD_LOOP 0
#define DEB_WIGLARGE_DRAWGD_LOOP1 0
#define DEB_TRANSFORMBLOCKTOSCORES 0
#define DEB_DRAWTRACKSGD 0
#define DEB_MAKEIMAGEMAP 0
#define DEB_ADDHDANNOTATIONTOPIXELMAP1 0
#define DEB_ADDHDANNOTATIONTOPIXELMAP2 0
#define DEB_ADDHDANNOTATIONTOPIXELMAP3 0
#define DEB_POPULATEPIXELS 0
#define DEB_TIMINGINFO 0

#define WIGGLE 0
#define AVERAGE 0
#define MAXIMUM 1
#define MINIMUM 2
#define genomeBased 0
#define blockBased 1
#define GLOBALSMALLHISTOGRAM "scoreBased_draw"
#define GLOBALLARGEHISTOGRAM "largeScore_draw"
#define LOCALSMALLHISTOGRAM "local_scoreBased_draw"
#define LOCALLARGEHISTOGRAM "local_largeScore_draw"
#define BIDIRECTIONALGLOBALHISTOGRAMLARGE "bidirectional_draw_large"
#define BIDIRECTIONALLOCALHISTOGRAMLARGE "bidirectional_local_draw_large"
#define FADETOWHITE "fadeToWhite_draw"
#define FADETOGRAY "fadeToGray_draw"
#define FADETOBLACK "fadeToBlack_draw"
#define DIFFGRADIENT "differentialGradient_draw"
#define CHROMOSOMEDRAW "chromosome_draw"
#define MAXRECONNECTATTEMPTS 8

GTimer *transformBlockToScoresTimer;
GTimer *readElementsFromFilePointerTimer;
GTimer *addHDAnnotationToPixelMapTimer;
GTimer *updateAPixelLoopTimer ;
GTimer *quickTransformBlockTimer ;
GTimer *addBlockLevelDataInfoToAnnotationsTimer;
GTimer *fillBlockLevelDataInfoTimer;
GTimer *getBlockLevelDataInfoTimer;


typedef struct coordinates {
    long firstPixel;
    long lastPixel;
}coordinates;


 typedef struct coordInt8Score {
   guint32  position;
   guint8 value;
}coordInt8Score;


typedef unsigned char Color;

// doing this so that calculation of 'bp with scores' for high density tracks is possible from 'optimizedFunctions.c'
// some of these globals are also required for the zoom levels calculation
int rid;
char *ridName;
int glob_ftypeId;
gdouble globBpPerPixel;

// This structure is used not just by high density tracks but also by other tracks to access the track attributes
typedef struct highDensFtypes {
  guint8 gbTrackWindowingMethod;
  guint8 gbTrackRecordType;
  char *fileName;
  guint gbTrackDataSpan;
  guint bpSpan;
  guint bpStep;
  gdouble gbTrackDataMax;
  gdouble gbTrackDataMin;
  guint8 gbTrackUseLog;
  guint8 gbTrackHasNullRecords;
  guint8 gbTrackFormula;
  gdouble scale;
  gdouble lowLimit;
  gdouble gbTrackDenominator;
  glong offset;
  glong byteLength;
  guint numRecords;
  gulong annotationFid;
  gulong annotationStart;
  gulong annotationEnd;
  guint  gbTrackPxHeight;
  gdouble gbTrackUserMax;
  gdouble gbTrackUserMin;
  // track attributes used for multi-color bar-charts
  gdouble gbTrackPxScoreUpperThreshold;
  gdouble gbTrackPxScoreLowerThreshold;
  char *gbTrackPxScoreUpperThresholdColor;
  char *gbTrackPxScoreLowerThresholdColor;
  // track attributes used for bi-directional bar-charts
  gdouble gbTrackPxScoreUpperNegativeThreshold;
  gdouble gbTrackPxScoreLowerNegativeThreshold;
  char *gbTrackPxScoreUpperNegativeThresholdColor;
  char *gbTrackPxScoreLowerNegativeThresholdColor;
  char *gbTrackNegativeColor;
  char *gbTrackPartitioning;
  gdouble gbTrackYIntercept;
  char *gbTrackZeroDraw ; // attribute for toggling scaling from 0 or from the 'real' low limit/upper limit (default: true)
 }highDensFtypes;

typedef struct minHighDensFtype {
  guint bpSpan;
  guint bpStep;
  gdouble scale;
  gdouble lowLimit;
  guint numRecords;
 }minHighDensFtype;

typedef struct hdhvAnnotations {
	unsigned long	fid;
	unsigned long	start;
	unsigned long	end;
  char fidStr[55];
}hdhvAnnotations;

typedef struct blockLevelDataInfo {
  unsigned long fid;
  int fileId;
  unsigned long offset;
  long byteLength;
  int gbBlockBpSpan;
  int gbBlockBpStep;
  int gbBlockScale;
  int gbBlockLowLimit;
  int numRecords;
}blockLevelDataInfo;

typedef struct myAnnotations {
	struct myAnnotations	*next;
	struct myGroup		*parentGroup;
	unsigned long			id;
	unsigned long			start;
	unsigned long			end;
	unsigned long			tstart;
	unsigned long			tend;
	int				ftypeid;
	float			score;
	int			height;
	char			orientation;
	int			level;
	int			phase;
	int			uploadId;
	int			textExist;
	int			sequenceExist;
	int			displayCode;
	int			displayColor;
	char			groupContextCode;
  char    fidStr[55];
  highDensFtypes *blockInfo;
} myAnnotations;



typedef struct myGroup {
	struct myGroup	*next;
	struct myTrack		*parentTrack;
	int	groupId;
	char	*allGroupClasses;
	char	*groupClass;
	char	*groupName;
	int	level;
	unsigned long	groupStart;
	unsigned long	groupEnd;
	int	height;
	int	numberOfAnnotations;
	int	hasU;
	int	hasL;
	int	hasF;
	int	groupContextPresent;
	int	containsBrokenAnnotationAtEnd;
	int	containsBrokenAnnotationAtStart;
	myAnnotations	*annotations;
	myAnnotations	*lastAnnotation;
} myGroup;


typedef struct groupStartingPoint {
  int     groupId;
  long    groupStart;
} groupStartingPoint;

typedef struct myTrackUrlInfo {
   char *url;
   char *urlDescription;
   char *urlLabel;
   char *shortUrlDesc;
} myTrackUrlInfo;

typedef struct arrayOfStrings {
  int    numberOfStrings;
	char	**strings;
} arrayOfStrings;

typedef struct myTrack {
	struct myTrack	*next;
	myGroup		*groups;
	int             height;
	char		*trackName;
	visibility	vis;
	int		numberOfGroups;
	char	**linkTemplates;
        int     numberOfTemplates;
	char	*style;
	char	*color;
        myTrackUrlInfo *trackUrlInfo;
	groupStartingPoint *listOfGroups;
	int maxLevel;
	float maxScore;
	float minScore;
	int specialTrack;
        int isHighDensityTrack;
        gdouble *pixelValueForHDT;
        gdouble *pixelExtraValues;
        gdouble *pixelNegativeValueForHDT;
        gdouble *pixelExtraNegativeValues;
        highDensFtypes *highDensFtypes;
        hdhvAnnotations *annotationsForHDHVTrack;
        int numberOfHdhvAnnotations;
} myTrack;

typedef struct trackAttDisplays {
  int rank;
  char *color;
  char *textToPrint;
  int sourceDb;
  int flaglocal;
} trackAttDisplays;



#endif /* _optimizedGB_h */
