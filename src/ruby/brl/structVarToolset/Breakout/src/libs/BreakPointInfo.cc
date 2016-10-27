#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "generic_debug.h"
#include "BreakPointInfo.h"

#define DEB_EXTEND_CLUSTER 0
#define DEB_RESET 0

BreakPointInfo::BreakPointInfo() {
	matePairsContainer = new MatePairContainer();
	pos1Start = 400000000;
	pos1Stop = 0;
	pos2Start = 400000000;
	pos2Stop = 0;
}


BreakPointInfo::~BreakPointInfo() {
	delete matePairsContainer;
}

void BreakPointInfo::reset() {
	pos1Start = 400000000;
	pos1Stop = 0;
	pos2Start = 400000000;
	pos2Stop = 0;
	matePairsContainer->reset();
}

int BreakPointInfo::addMatePair(MatePairInfo* mateInfo) {
	if (matePairsContainer->numberOfMatePairs==0 ){
		  reset();
	}
	xDEBUG(DEB_EXTEND_CLUSTER, fprintf(stderr, "extending bkp (%d,%d)-%d(%d,%d) with (%d)-%d(%d)\n",
																		 pos1Start, pos1Stop, chr2, pos2Start, pos2Stop,
																		 mateInfo->pos1, mateInfo->chr2, mateInfo->pos2));
	if (mateInfo->pos1>pos1Stop) {
		pos1Stop = mateInfo->pos1;
	}
	if (mateInfo->pos1<pos1Start) {
		pos1Start = mateInfo->pos1;
	}
	if (mateInfo->pos2>pos2Stop) {
		pos2Stop = mateInfo->pos2;
	}
	if (mateInfo->pos2<pos2Start) {
		pos2Start = mateInfo->pos2;
	}
	chr2 = mateInfo->chr2;
	int result = matePairsContainer->addMatePair(mateInfo->pos1, mateInfo->strand1, mateInfo->mismatches1,
																	mateInfo->chr2, mateInfo->pos2,
																	mateInfo->strand2, mateInfo->mismatches2,
																	mateInfo->mateType, mateInfo->mateId);

	return result;
}

int BreakPointInfo::addMatePair(guint32 pos1, guint32 strand1, guint32 mismatches1,
						guint32 _chr2, guint32 pos2, guint32 strand2, guint32 mismatches2,
						MateMappingStatus mateType, char* mateId) {
	xDEBUG(DEB_EXTEND_CLUSTER, fprintf(stderr, "extending bkp (%d,%d)-%d(%d,%d) with (%d)-%d(%d)\n",
																		 pos1Start, pos1Stop, chr2, pos2Start, pos2Stop,
																		 pos1, chr2, pos2));
	if (pos1>pos1Stop) {
		pos1Stop = pos1;
	}
	if (pos1<pos1Start) {
		pos1Start = pos1;
	}
	if (pos2>pos2Stop) {
		pos2Stop = pos2;
	}
	if (pos2<pos2Start) {
		pos2Start = pos2;
	}
	chr2 = _chr2;
	int result = matePairsContainer->addMatePair(pos1, strand1, mismatches1,
																	chr2, pos2,
																	strand2, mismatches2,
																	mateType, mateId);

	return result;
}

/** Write current breakpoint to a file stream
 * @param chrom1 first chromosome
 * @param outFilePtr file stream
 * @flag  if 1, write current breakpoint followed by a newline
 *        if 0, write current breakpoint followed by a tab
 */
void BreakPointInfo::dumpBreakPoint(guint32 chrom1, FILE* outFilePtr, int flag) {
	// TODO
	if (matePairsContainer->numberOfMatePairs<2) {
		return;
	}
        // check for redundant bkp
        int diff=0;
	MatePairInfo* mateInfo;
        guint32 p1=matePairsContainer->matePairContainer[0].pos1;
	guint32 i;
        guint32 p2=matePairsContainer->matePairContainer[0].pos1;
       	for (i=0; i<matePairsContainer->numberOfMatePairs; i++) {
	  mateInfo = &matePairsContainer->matePairContainer[i];
          if (mateInfo->pos1!=p1 &&mateInfo->pos2!=p2) {
            diff=1;
            break;
          }
	}
        if (!diff) {
          return;
        }
	double avgMismatches=0;
	for (i=0; i<matePairsContainer->numberOfMatePairs; i++) {
		mateInfo = &matePairsContainer->matePairContainer[i];
		avgMismatches += mateInfo->mismatches1 + mateInfo->mismatches2;
	}
	avgMismatches = avgMismatches/matePairsContainer->numberOfMatePairs;
	fprintf(outFilePtr, "MPC:\t%d\t%5.2lf\t%d\t%d\t%d\t%d\t%d\t%d\t",
					matePairsContainer->numberOfMatePairs,
					avgMismatches,
					chrom1, pos1Start, pos1Stop,
					chr2, pos2Start, pos2Stop);

	for (i=0; i<matePairsContainer->numberOfMatePairs; i++) {
		mateInfo = &matePairsContainer->matePairContainer[i];
		fprintf(outFilePtr, "%s\t%d\t%c\t%d\t%d\t%c\t%d\t%d\t\t",
							mateInfo->mateId,
							mateInfo->pos1, mateInfo->strand1>0?'+':'-', mateInfo->mismatches1,
							mateInfo->pos2, mateInfo->strand2>0?'+':'-', mateInfo->mismatches2,
							mateInfo->mateType);
	}
	if (flag) {
		fprintf(outFilePtr, "\n");
	} else {
		fprintf(outFilePtr, "\t");
	}
} // void BreakPointInfo::dumpBreakPoint


/** Return number of matepairs spanning the breakpoint*/
guint32 BreakPointInfo::getNumberOfMatepairs() {
	return matePairsContainer->numberOfMatePairs;
} // void BreakPointInfo::getNumberOfMatepairs


BreakPointContainer::BreakPointContainer(GSList** _globalBreakPointPool) {
	numberOfBreakPoints = 0;
	containerCapacity = 0;
	pos1Start = 4000000000;
	pos1Stop = 0;
	pos2Start = 4000000000;
	pos2Stop = 0;
	globalBreakPointPool = _globalBreakPointPool;
	breakpointArray = NULL;
}

BreakPointContainer::~BreakPointContainer () {
	guint32 i;
	for (i=0; i<numberOfBreakPoints; i++) {
		*globalBreakPointPool = g_slist_prepend(*globalBreakPointPool, breakpointArray[i]);
	}
	free(breakpointArray);
}


void BreakPointContainer::reset() {
	guint32 i;
	for (i=0; i<numberOfBreakPoints; i++) {
		breakpointArray[i]->reset();
		*globalBreakPointPool = g_slist_prepend(*globalBreakPointPool, breakpointArray[i]);
		xDEBUG(DEB_RESET, fprintf(stderr, "freeing bkp %p\n"));
	}
	numberOfBreakPoints = 0;
	pos1Start = 4000000000;
	pos1Stop = 0;
	pos2Start = 4000000000;
	pos2Stop = 0;

}

int BreakPointContainer::addBreakPoint(BreakPointInfo* breakpointInfo) {
	numberOfBreakPoints ++;
	if (numberOfBreakPoints>containerCapacity) {
		containerCapacity = containerCapacity*5/4+1;
		breakpointArray = (BreakPointInfo**) realloc(breakpointArray, containerCapacity*sizeof(BreakPointInfo*));
		if (breakpointArray==NULL) {
			return 1;
		}
	}
	breakpointArray[numberOfBreakPoints-1] = breakpointInfo;
	if (numberOfBreakPoints==1) {
		pos1Start = breakpointInfo->pos1Start;
		pos1Stop = breakpointInfo->pos1Stop;
		pos2Start = breakpointInfo->pos2Start;
		pos2Stop = breakpointInfo->pos2Stop;
	} else {
		if (breakpointInfo->pos1Stop>pos1Stop) {
			pos1Stop = breakpointInfo->pos1Stop;
		}
		if (breakpointInfo->pos1Start<pos1Start) {
			pos1Start = breakpointInfo->pos1Start;
		}
		if (breakpointInfo->pos2Stop>pos2Stop) {
			pos2Stop = breakpointInfo->pos2Stop;
		}
		if (breakpointInfo->pos2Start<pos2Start) {
			pos2Start = breakpointInfo->pos2Start;
		}
	}

	if (pos1Start>300000000 || pos2Start>300000000) {
		*(int*)NULL=1;
	}
	return 0;
}


void BreakPointContainer::dumpContainer(FILE* outFilePtr) {
	if (pos1Start <= pos2Stop && pos2Start<=pos1Stop) {
		return;
	}
	guint32 i, bkpIndex, mateIndex;
	guint32 matePairsInCurrentBreakpoint;
	// compute overall average mismatches, estimated insert size (if same chromosome), and uniqueness coefficient
	float mismatches, uniqueMatePairs, numberOfMatePairs, estimatedInsertSum;
	mismatches = 0;
	uniqueMatePairs=0;
	numberOfMatePairs = 0;
	estimatedInsertSum = 0;
	int sameChrom = breakpointArray[0]->chr1 == breakpointArray[0]->chr2;
	for (bkpIndex=0; bkpIndex<numberOfBreakPoints; bkpIndex++) {
		BreakPointInfo* currentBreak = breakpointArray[bkpIndex];
		double maxInsert = currentBreak->maxInsert;
		MatePairInfo*  matePairsArray = currentBreak->matePairsContainer->matePairContainer;
		matePairsInCurrentBreakpoint = currentBreak->matePairsContainer->numberOfMatePairs;
		for (mateIndex = 0; mateIndex<matePairsInCurrentBreakpoint; mateIndex++) {
			mismatches += matePairsArray[mateIndex].mismatches1 + matePairsArray[mateIndex].mismatches2;
			numberOfMatePairs += 1;
			if (matePairsArray[mateIndex].mateType==0) {
				uniqueMatePairs++;
			}
			if (sameChrom) {
				estimatedInsertSum += (matePairsArray[mateIndex].pos2-matePairsArray[mateIndex].pos1)-maxInsert;
			}
		}
	}
	float avgMismatches, avgUniqueMatepairs, avgInsert;
	avgMismatches = mismatches/numberOfMatePairs;
	avgUniqueMatepairs = uniqueMatePairs/numberOfMatePairs;
	avgInsert = estimatedInsertSum/numberOfMatePairs;

	fprintf(outFilePtr, "MetaBKP\t%d\t%6.0f\t%5.2f\t%5.3f\t%11.0f\t%d\t%d\t%d\t%d\t%d\t%d\t",
					numberOfBreakPoints, numberOfMatePairs,
					avgMismatches, avgUniqueMatepairs, floor(avgInsert),
					breakpointArray[0]->chr1,
					pos1Start, pos1Stop,
					breakpointArray[0]->chr1, pos2Start, pos2Stop);
	for (i=0; i<numberOfBreakPoints; i++) {
		fprintf(outFilePtr, "%d\t", breakpointArray[i]->maxInsert);
		breakpointArray[i]->dumpBreakPoint(breakpointArray[i]->chr1, outFilePtr, 0);
	}
	fprintf(outFilePtr, "\n");
}
