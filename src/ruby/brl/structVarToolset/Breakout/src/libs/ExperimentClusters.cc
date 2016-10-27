#include <stdio.h>
#include <stdlib.h>

#include "ExperimentClusters.h"
#include "generic_debug.h"
#include "someConstants.h"
#include "BRLGenericUtils.h"

#define DEB_ADVANCE 0
#define DEB_ADVANCE1 0
#define DEB_ADVANCE2 0

BreakPointInfo* ExperimentClusters::getTopBreakpoint() {
	return topBreakpoint;
}


BreakPointInfo* ExperimentClusters::advanceBreakPoint() {
	// get a line
	// parse matepairs
	// populate breakpoints

	guint32 numberOfMatePairs;
	char avgMismatches[MAX_LINE_LENGTH];
	guint32 chrom1, chrom2;
	guint32 start1, stop1, start2, stop2;
	char mpcLabel[MAX_LINE_LENGTH];
	char readId[MAX_LINE_LENGTH];
  guint32 matePos1, matePos2, mismatches1, mismatches2;
	char strand1, strand2;
	MateMappingStatus mateType;
	guint32 i;
	int numItems;
	int invalidCluster;

	do {
		topBreakpoint = NULL;
		invalidCluster = 0;
		numItems = fscanf(fileStream, " %s %d %s %d %d %d %d %d %d",
					 mpcLabel, &numberOfMatePairs, avgMismatches,
					 &chrom1, &start1, &stop1, &chrom2, &start2, &stop2);
		if (numItems<=0) {
			break;
		}
		xDEBUG(DEB_ADVANCE, fprintf(stderr, "items %d %s %d mp avg %s %d(%d,%d) %d(%d,%d)\n",
						numItems, mpcLabel, numberOfMatePairs, avgMismatches,
						chrom1, start1, stop1,
						chrom2, start2, stop2));
		if (start1<=stop2 && start2<=stop1) {
			invalidCluster = 1;
			topBreakpoint = NULL;
			// set up a new breakpoint
		} else {
			invalidCluster = 0;
			if (*breakpointPool == NULL) {
				// preallocate 100 breakpoints
				BreakPointInfo* breakpointInfo = new BreakPointInfo();
				*breakpointPool = g_slist_prepend (*breakpointPool, (gpointer) breakpointInfo);
			}
			topBreakpoint = (BreakPointInfo*) (*breakpointPool)->data;
			*breakpointPool = g_slist_remove(*breakpointPool, topBreakpoint);
			topBreakpoint->pos1Start = start1;
			topBreakpoint->pos1Stop = stop1;
			topBreakpoint->pos2Start = start2;
			topBreakpoint->pos2Stop = stop2;
			topBreakpoint->experimentId = experimentId;
			topBreakpoint->minInsert = minInsert;
			topBreakpoint->maxInsert = maxInsert;
			topBreakpoint->chr1=chrom1;
			topBreakpoint->chr2=chrom2;

		}
		// consume all matepairs
		for (i=0; i<numberOfMatePairs; i++) {
			fscanf(fileStream, "%s %d %c %d %d %c %d %d",
				readId, &matePos1, &strand1, &mismatches1,
				&matePos2, &strand2, &mismatches2, &mateType);
			xDEBUG(DEB_ADVANCE1, fprintf(stderr, "got %s: (%d %c %d - %d %c %d)[%d]\n",
				readId,
				matePos1, strand1, mismatches1,
				matePos2, strand2, mismatches2,
				mateType));
			if (!invalidCluster) {
				topBreakpoint->addMatePair(matePos1, strand1=='+'?1:0, mismatches1,
																	 chrom2, matePos2, strand2=='+'?1:0, mismatches2,
																	 mateType, readId);
			}
		}
	} while (topBreakpoint==NULL && numItems>0);
	xDEBUG(DEB_ADVANCE2, fprintf(stderr, "advance return bkp %p\n", topBreakpoint));
	return topBreakpoint;
}

ExperimentClusters::ExperimentClusters(char* _fileName, guint32 _experimentId,
										 guint32 _minInsert, guint32 _maxInsert, GSList** _breakpointPool) {
	fileName = g_strdup(_fileName);
	minInsert = _minInsert;
	maxInsert = _maxInsert;
	experimentId = _experimentId;
	setupClusterFile();
	topBreakpoint = NULL;
	breakpointPool = _breakpointPool;
}

ExperimentClusters::~ExperimentClusters() {
	fclose(fileStream);
}

int ExperimentClusters::setupClusterFile() {
	fileStream = BRLGenericUtils::openTextGzipBzipFile(fileName);
	if (fileStream==NULL) {
		fprintf(stderr, "could not open clusters file %s\n", fileName);
		exit(2);
	}
	return 0;
}
