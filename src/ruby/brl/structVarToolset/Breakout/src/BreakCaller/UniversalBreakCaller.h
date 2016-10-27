#ifndef __Universal_Break__Caller_H__
#define __Universal_Break__Caller_H__

#include <glib.h>
#include "someConstants.h"
#include "MatePairIndex.h"
#include "BreakPointInfo.h"
#include "AnnotationIndex.h"

class UniversalBreakCaller {
	char inputInconsistentFile[MAX_FILE_NAME];
	char outputFile[MAX_FILE_NAME];
	char repeatDupFile[MAX_FILE_NAME];
	MatePairIndex *matePairIndex;
	AnnotationIndex * repeatsIndex;
	BreakPointInfo** allegedBreakPoints;
   BreakPointInfo** refinedBreakpoints;
   guint32 numberOfRefinedBreakpoints;
	guint32 breakpointsCapacity;
   guint32 refinedBreakpointsCapacity;
	guint32 numberOfAllegedBreakpoints;
	GSList *breakPointsPoolList;
	guint32 numberOfAllocatedBreakpoints;
	guint32 maxInsertSize;
	guint32 chr1;
	FILE* outFilePtr;
	char chromosomeString1[MAX_FILE_NAME];
	char chromosomeString2[MAX_FILE_NAME];
public:
	/** Constructor.*/
	UniversalBreakCaller();
	/** Destructor.*/
	~UniversalBreakCaller();
	/** Parse user command line.*/
	int parseParams(int argc, char* argv[]);
	/** Cluster breakpoints; report clusters of breakpoints.*/
	int callBreaks();
private:
	/** Display program usage.*/
	void usage();
	/** Build matepair index.*/
	int loadMatePairIndex();
	/** Traverse matepair index and cluster matepairs.*/
	int clusterMatepairs();
   /** Refine hotspots of matepairs clusters.*/
   int refineMatepairClusters(MatePairContainer* mateContainer );
	/** Load repeats and duplications on the target chromosomes.*/
	int loadRepeatsAndDuplicationsOnTargetChromosomes();
	int overlapsWithRepeatOrSegDup(char* chromosome, guint32 start, guint32 stop);
};


#endif
