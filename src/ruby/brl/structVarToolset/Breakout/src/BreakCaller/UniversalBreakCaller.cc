#include <stdio.h>
#include <glib.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <getopt.h>
#include <strings.h>
#include <sys/types.h>
#include <unistd.h>


#include "generic_debug.h"
#include "someConstants.h"
#include "BRLGenericUtils.h"
#include "UniversalBreakCaller.h"

#define DEB_MATE_READ 1
#define DEB_CLUSTER 1

#define DEB_TRACE_BKP_ALLOCS 0
#define DEB_BKP_REPEAT 0

#define DEB_REFINE_BKPS 1

/** Constructor.*/
UniversalBreakCaller::UniversalBreakCaller() {
	strcpy(inputInconsistentFile,"");
	strcpy(outputFile, "");
	matePairIndex = NULL;
	breakpointsCapacity = 10;
	numberOfAllegedBreakpoints = 0;
   numberOfRefinedBreakpoints = 0;
   refinedBreakpointsCapacity = 10;
	allegedBreakPoints = (BreakPointInfo**) malloc(sizeof(BreakPointInfo*)*breakpointsCapacity);
   refinedBreakpoints = (BreakPointInfo**) malloc(sizeof(BreakPointInfo*)*refinedBreakpointsCapacity);
	xDEBUG(1, fprintf(stderr, "allocated allegedBreakPoints %p\n", allegedBreakPoints));
   xDEBUG(1, fprintf(stderr, "allocated allegedBreakPoints %p\n", refinedBreakpointsCapacity));
	repeatsIndex = NULL;
}

/** Destructor.*/
UniversalBreakCaller::~UniversalBreakCaller() {
	xDEBUG(1, fprintf(stderr, "UniversalBreakCaller destructor START\n"));
	delete matePairIndex;
	xDEBUG(1, fprintf(stderr, "deleted matePairIndex\n"));
	xDEBUG(1, fprintf(stderr, "about to free %p\n", allegedBreakPoints));
	// free(allegedBreakPoints);
	xDEBUG(1, fprintf(stderr, "deleted alleged breakpoints\n"));
	xDEBUG(1, fprintf(stderr, "UniversalBreakCaller destructor STOP\n"));
}

/** Parse user command line.
 * @return 0 if successful, 1 if not
 */
int UniversalBreakCaller::parseParams(int argc, char* argv[]) {
static struct option long_options[] = {
    {"matePairsFile", required_argument, 0, 'm'},
    {"output", required_argument, 0, 'o'},
		{"maxInsertSize", required_argument, 0, 'I'},
		{"repeatDupFile", required_argument, 0, 'R'},
    {"help", no_argument, 0, 'h'},
    {0, 0, 0, 0}
  };

	strcpy(inputInconsistentFile, "");
	strcpy(repeatDupFile, "");
	strcpy(outputFile, "");

	  // setup params
  if (argc==1) {
		usage();
		exit(0);
	}
	if (!strcmp(argv[1], "--help") || !strcmp(argv[1], "-help") ||
      !strcmp(argv[1],"-h") || !strcmp(argv[1],"--h")) {
		usage();
		exit(0);
	}

	int option_index = 0;
  char opt;
	maxInsertSize = 0;

	while((opt=getopt_long(argc,argv,
                         "m:o:hI:R:",
                         long_options, &option_index))!=-1) {
    switch(opt) {
    case 'm':
      strncpy(inputInconsistentFile, optarg, MAX_FILE_NAME);
      break;
    case 'o':
      strncpy(outputFile, optarg, MAX_FILE_NAME);
      break;
		case 'I':
			maxInsertSize = strtoul(optarg, NULL, 10);
			break;
		case 'R':
			strncpy(repeatDupFile, optarg, MAX_FILE_NAME);
			break;
    case 'h':
      usage();
      exit(2);
    default:
      fprintf(stderr, "unknown option %s \n", optarg);
      usage();
      exit(2);
    }
  }

	// verify that critical parameters names have been supplied
	if (!strcmp(outputFile, "")) {
		fprintf(stderr, "The output file was not specified");
		return 1;
	}

	if (!strcmp(inputInconsistentFile, "")) {
		fprintf(stderr, "The input file was not specified");
		return 1;
	}

	if (maxInsertSize==0 || maxInsertSize>=100000) {
		fprintf(stderr, "The insert size needs to be an integer greater than zero\n");
		return 1;
	}

	return 0;
}


/** Load repeats and duplications on the target chromosomes.
 * @return 0 if successful, 1 otherwise
*/
int
UniversalBreakCaller::loadRepeatsAndDuplicationsOnTargetChromosomes() {
	repeatsIndex = new AnnotationIndex();
	repeatsIndex->addReference(chromosomeString1, 300000000);
  repeatsIndex->addReference(chromosomeString2, 300000000);
        if (strcmp(repeatDupFile,"")) {
		FILE* repFile = BRLGenericUtils::openTextGzipBzipFile(repeatDupFile);
		char line[MAX_LINE_LENGTH];
		char chrom[MAX_LINE_LENGTH];
		guint32 start, stop;
		guint32 repeatId =0;
		while (fgets(line, MAX_LINE_LENGTH-1, repFile)!=NULL) {
			sscanf(line, "%s %d %d", chrom, &start, &stop);
			if (!strcmp(chrom, chromosomeString1) || !strcmp(chrom, chromosomeString2)) {
				repeatsIndex->addAnnotation(repeatId,	chrom, start, stop, NULL);
				repeatId++;
			}
		}
	
		fclose(repFile);
        }
	return 0;
}

/** Cluster breakpoints; report clusters of breakpoints
 * @return 0 if successful, 1 otherwise.*/
int UniversalBreakCaller::callBreaks() {
	matePairIndex = new MatePairIndex();
	// load all mates and build matepair index
	if (loadMatePairIndex()) {
		return 1;
	}
	// load all repeats on the target chromosomes
	loadRepeatsAndDuplicationsOnTargetChromosomes();
	// traverse matepair index and cluster matepairs
	if (clusterMatepairs()) {
		return 1;
	}
	return 0;
}

/** Build matepair index
 * @return 0 if successful, 1 otherwise.*/
int UniversalBreakCaller::loadMatePairIndex() {
	guint32 numberOfMates=0;
	BRLGenericUtils::printNow(stderr);
	fprintf(stderr, "loading matePairs...");
	FILE* matePairFileReader = BRLGenericUtils::openTextGzipBzipFile(inputInconsistentFile);
	if (matePairFileReader==NULL) {
		fprintf(stderr, "could not open input file %s\n", inputInconsistentFile);
		return 1;
	}
	char matePairLine[2048];
	guint32 chrom1, chrom2;
	guint32 pos1, pos2;
	char strand1, strand2;
	char readId[2048];
	guint32 mismatches1, mismatches2;
	MateMappingStatus mateType=(MateMappingStatus)0;
	int chr1Set = 0;

	while (fgets(matePairLine, 2048-1, matePairFileReader) != NULL) {
		sscanf(matePairLine, " %d %d %c %d %d %d %c %d %s",
					 &chrom1, &pos1, &strand1, &mismatches1,
					 &chrom2, &pos2, &strand2, &mismatches2, readId);
		xDEBUG(DEB_MATE_READ, fprintf(stderr, "read mate %s: %d(%d,%c,%d)-%d(%d,%c,%d) of type %d\n",
																	readId,
																	chrom1, pos1, strand1, mismatches1,
																	chrom2, pos2, strand2, mismatches2,
																	mateType));
		if (chr1Set) {
			if (chrom1 != chr1) {
				fprintf(stderr, "different first chrom %d vs previous value %d\n", chrom1, chr1);
				return 1;
			}
		}  else {
			chr1Set= 1;
			chr1 = chrom1;
			sprintf(chromosomeString1, "%d", chr1);
			sprintf(chromosomeString2, "%d", chrom2);
			fprintf(stderr, "set first chrom to %d \n", chr1);
		}
		matePairIndex->addMatePair(pos1, strand1=='+'?0:1, mismatches1,
					chrom2, pos2, strand2=='+'?0:1, mismatches2, mateType, readId);
		numberOfMates++;
	}

	fclose(matePairFileReader);
	fprintf(stderr, "done! Loaded %d mates\n", numberOfMates);
	BRLGenericUtils::printNow(stderr);
	return 0;
}


int
UniversalBreakCaller::overlapsWithRepeatOrSegDup(char* chromosome, guint32 startPos, guint32 stopPos) {
	AbbreviatedAnnotationContainer *annotationContainer, *currentContainer;
	guint32 numberOfContainers;
	guint32 containerIndex, overlappedAnnotationId;
	AbbreviatedAnnotation *currentAnnotation;
	guint32 annoStartPos, annoStopPos;
	int ovlFound=0;

	annotationContainer = repeatsIndex->lookupElement(chromosome, startPos, stopPos, &numberOfContainers);
	for(containerIndex = 0; !ovlFound && containerIndex<numberOfContainers; containerIndex++) {
		// current container
		currentContainer = &annotationContainer[containerIndex];
		for ( overlappedAnnotationId=0;
					!ovlFound && overlappedAnnotationId<currentContainer->numberOfAnnotations;
					overlappedAnnotationId++) {
			currentAnnotation = &currentContainer->annotationContainer[overlappedAnnotationId];
			annoStartPos = currentAnnotation->startPos;
			annoStopPos = currentAnnotation->stopPos;
			xDEBUG(DEB_BKP_REPEAT, fprintf(stderr, "[%d] comparing against lffAnno %d-%d\n",
																					 overlappedAnnotationId, annoStartPos, annoStopPos));
			if (annoStartPos<= stopPos &&
									 annoStopPos>= startPos) {
				ovlFound = 1;
				break;
			}
		}
	}
	return ovlFound;
}

/** Traverse matepair index and cluster matepairs.
 * @return 0 if successful, 1 otherwise.*/
int UniversalBreakCaller::clusterMatepairs() {
	guint32 windowIndex;
	guint32 mateIndex;
	guint32 numberOfContainers = matePairIndex->numberOfContainers;
	guint32 windowSize = matePairIndex->windowSize;
	guint32 newBkpIndex, bkpIndex;
	guint32 dist1, dist2;
	BreakPointInfo* bkpInfo;

	outFilePtr=fopen(outputFile, "w");
	if (outFilePtr==NULL) {
		fprintf(stderr, "Could not open output file %s\n", outputFile);
		return 1;
	}
	// initialize the breakpoint pool w/ a fixed number of breakpoints
	numberOfAllocatedBreakpoints = 1;
	breakPointsPoolList = NULL;
	for (newBkpIndex=0; newBkpIndex<numberOfAllocatedBreakpoints; newBkpIndex++) {
		BreakPointInfo* breakpointInfo = new BreakPointInfo();
		breakPointsPoolList = g_slist_prepend (breakPointsPoolList, (gpointer) breakpointInfo);
	}

	for (windowIndex=0; windowIndex<numberOfContainers; windowIndex++) {
		// dump all bkps from last by one window
		if (windowIndex>2) {
			guint32 cutoffBound = (windowIndex-1)*windowSize+1;
			guint32 dumpBkpIndex, bkpToDump;
			for(dumpBkpIndex=0, bkpToDump = 0; dumpBkpIndex<numberOfAllegedBreakpoints; dumpBkpIndex++) {
				if(allegedBreakPoints[dumpBkpIndex]->pos1Start>=cutoffBound) {
					break;
				} else {
					bkpToDump += 1;
				}
			}
			if (bkpToDump>0) {
				for (dumpBkpIndex=0; dumpBkpIndex<bkpToDump; dumpBkpIndex++) {
					bkpInfo = allegedBreakPoints[dumpBkpIndex];
					// determine the number of matepairs that have at least one end
					// overlapping with repeats or duplications
					guint32 repeatMates = 0;
					guint32 numberOfMatepairs = bkpInfo->matePairsContainer->numberOfMatePairs;
					if (numberOfMatepairs>1) {
						guint32 mateIdx = 0;
						for (mateIdx=0;
							mateIdx<numberOfMatepairs;
							mateIdx++) {
							MatePairInfo* mateInfo = &bkpInfo->matePairsContainer->matePairContainer[mateIdx];
							if (overlapsWithRepeatOrSegDup(chromosomeString1, mateInfo->pos1, mateInfo->pos1+25) ||
									overlapsWithRepeatOrSegDup(chromosomeString2, mateInfo->pos2, mateInfo->pos2+25)) {
								repeatMates++;
							}
						}

						if (numberOfMatepairs-repeatMates>=2) {
							xDEBUG(DEB_BKP_REPEAT, fprintf(stderr, "current break [%d,%d]-[%d,%d] has %d/%d ovl w/ repeats mates\n",
							bkpInfo->pos1Start, bkpInfo->pos1Stop,
							bkpInfo->pos2Start, bkpInfo->pos2Stop,
							repeatMates, numberOfMatepairs));
							xDEBUG(DEB_REFINE_BKPS, fprintf(stderr, "evaluate refine bkp [%d,%d]:%d  [%d,%d]:%d\n",
																							bkpInfo->pos1Start, bkpInfo->pos1Stop, bkpInfo->pos1Stop-bkpInfo->pos1Start,
																							bkpInfo->pos2Start, bkpInfo->pos2Stop, bkpInfo->pos2Stop-bkpInfo->pos2Start))
							if ( (bkpInfo->pos1Stop-bkpInfo->pos1Start)<maxInsertSize &&
                        (bkpInfo->pos2Stop-bkpInfo->pos2Start)<maxInsertSize) {
													xDEBUG(DEB_REFINE_BKPS, fprintf(stderr, "just dump it\n"));
                           bkpInfo->dumpBreakPoint(chr1, outFilePtr);   
                     } else {
                        //
												xDEBUG(DEB_REFINE_BKPS, fprintf(stderr, "just refine it\n"));
                        refineMatepairClusters(bkpInfo->matePairsContainer);
                     }
						} else {
							xDEBUG(DEB_BKP_REPEAT, fprintf(stderr, "current bkp [%d,%d]-[%d,%d] fails  %d/%d ovl w/ repeat mates\n",
																						 bkpInfo->pos1Start, bkpInfo->pos1Stop,
																						 bkpInfo->pos2Start, bkpInfo->pos2Stop,
																						 repeatMates, numberOfMatepairs); bkpInfo->dumpBreakPoint(chr1, stderr));
						}
					}
					// now reclaim bkpInfo
					bkpInfo->reset();
					breakPointsPoolList = g_slist_prepend (breakPointsPoolList, (gpointer) bkpInfo);
				}
				// then shift the remaining breakpoints;
				numberOfAllegedBreakpoints = numberOfAllegedBreakpoints-bkpToDump;
				for (dumpBkpIndex=0; dumpBkpIndex<numberOfAllegedBreakpoints; dumpBkpIndex++) {
					allegedBreakPoints[dumpBkpIndex] = allegedBreakPoints[dumpBkpIndex+bkpToDump];
				}
			}
		}
		MatePairContainer* mateContainer = &matePairIndex->matePairContainers[windowIndex];
		xDEBUG(DEB_CLUSTER, fprintf(stderr, "Processing window %d [%d, %d) containing %d mates\n",
																windowIndex,
																windowIndex*windowSize, (windowIndex+1)*windowSize,
																mateContainer->numberOfMatePairs));
		// compare current mate with all previous breakpoints
		for (mateIndex = 0; mateIndex<mateContainer->numberOfMatePairs; mateIndex++) {
			MatePairInfo* mateInfo = &mateContainer->matePairContainer[mateIndex];
			int bkpFound = 0;
			int sameStrand = (mateInfo->strand1==mateInfo->strand2);
			for (bkpIndex =0; bkpIndex<numberOfAllegedBreakpoints &&!bkpFound; bkpIndex++) {
				bkpInfo = allegedBreakPoints[bkpIndex];
				xDEBUG(DEB_CLUSTER, fprintf(stderr, "comparing current mate [%d] %d(%d)-%d(%d) %s vs bkp %d(%d-%d)-%d(%d,%d)\n",
																		mateIndex, chr1, mateInfo->pos1, mateInfo->chr2, mateInfo->pos2, mateInfo->mateId,
																		chr1, bkpInfo->pos1Start, bkpInfo->pos1Stop,
																		bkpInfo->chr2, bkpInfo->pos2Start, bkpInfo->pos2Stop));
				if (bkpInfo->chr2 == mateInfo->chr2 && bkpInfo->sameStrand==sameStrand) {
					xDEBUG(DEB_CLUSTER, fprintf(stderr, "same chrom\n"));
					if (mateInfo->pos1>bkpInfo->pos1Stop) {
						dist1 =mateInfo->pos1- bkpInfo->pos1Stop+1;
					} else if (mateInfo->pos1<bkpInfo->pos1Start) {
						dist1 = bkpInfo->pos1Start-mateInfo->pos1+1;
					} else {
						//dist1 = bkpInfo->pos1Stop- bkpInfo->pos1Start+1;
                                                dist1 = maxInsertSize;
					}
					if (mateInfo->pos2>bkpInfo->pos2Stop) {
						dist2 =mateInfo->pos2- bkpInfo->pos2Stop+1;
					} else if (mateInfo->pos2<bkpInfo->pos2Start) {
						dist2 = bkpInfo->pos2Start-mateInfo->pos2+1;
					} else {
						//dist2 = bkpInfo->pos2Stop- bkpInfo->pos2Start+1;
						dist2 = maxInsertSize;
					}
				        xDEBUG(DEB_CLUSTER, fprintf(stderr, "comparing current mate d1 %d d2 %d\n", dist1, dist2));
					if ( (dist1>3*maxInsertSize/2) || (dist2>3*maxInsertSize/2) ||
							  (chr1==mateInfo->chr2 && ! (mateInfo->pos1<bkpInfo->pos2Stop &&
																						mateInfo->pos2>bkpInfo->pos1Start))
							) {
						continue;
					} else {
						// extended a current breakpoint
						bkpFound = 1;
						bkpInfo->addMatePair(mateInfo);
					}
				}
			}
			if (!bkpFound) {
				// allocate new breakpoint
				if (breakPointsPoolList == NULL) {
					// extend number of allocated breakpoints by 25%
					guint32 numberOfAdditionalBkps = numberOfAllocatedBreakpoints*5/4+1-numberOfAllocatedBreakpoints;
					for (newBkpIndex=0; newBkpIndex<numberOfAdditionalBkps; newBkpIndex++) {
						BreakPointInfo* breakpointInfo = new BreakPointInfo();
						breakPointsPoolList = g_slist_prepend (breakPointsPoolList, (gpointer) breakpointInfo);
					}
					numberOfAllocatedBreakpoints += numberOfAdditionalBkps;
					xDEBUG(DEB_TRACE_BKP_ALLOCS, fprintf(stderr, "increased # of allocated bkps to %d\n",
																							 numberOfAllocatedBreakpoints));
				}
				bkpInfo = (BreakPointInfo*) breakPointsPoolList->data;
				breakPointsPoolList = g_slist_remove(breakPointsPoolList, bkpInfo);
				bkpInfo->reset();
            bkpInfo->addMatePair(mateInfo);
				numberOfAllegedBreakpoints += 1;
				if (breakpointsCapacity<=numberOfAllegedBreakpoints) {
					breakpointsCapacity = breakpointsCapacity*5/4+1;
					allegedBreakPoints = (BreakPointInfo**) realloc(allegedBreakPoints,
																													sizeof(BreakPointInfo*)*breakpointsCapacity);
				}
				allegedBreakPoints[numberOfAllegedBreakpoints-1] = bkpInfo;
				if(mateInfo->strand1==mateInfo->strand2) {
					bkpInfo->sameStrand =  1;
				} else {
					bkpInfo->sameStrand =  0;
				}
			}
		}
	}
	fclose(outFilePtr);
	return 0;
}


void UniversalBreakCaller::usage() {
	fprintf(stderr,
"Utility that cluster inconsistent mate pair mappings with the same starting chromosome\n"
"and the same ending chromosome.\n"
"  --matePairsFile    | -m    ===> inconsistent mate pairs\n"
"  --output           | -o    ===> matepairs clusters output file\n"
"  --maxInsertSize    | -I    ===> maximum insert size\n"
"  --repeatDupFile    | -R    ===> file containing repeats and segmental duplications in BED format\n"
"  --help             | -h    ===> print this help and exit\n"
);
}


// sort routine
int cmpMatePairs (const void *p1, const void *p2) {
   if (((MatePairInfo*)p1)->pos1<((MatePairInfo*)p2)->pos1) {
      return -1;
   } else {
      return (((MatePairInfo*)p1)->pos1>((MatePairInfo*)p2)->pos1);
   }
}

/** Refine hotspots of matepairs clusters
@param mateContainer matepairs container
@return 0 for success, 1 otherwise
*/
int UniversalBreakCaller::refineMatepairClusters(MatePairContainer* mateContainer ) {
   qsort(mateContainer->matePairContainer, mateContainer->numberOfMatePairs, sizeof(MatePairInfo), cmpMatePairs);
   guint32 mateIndex;
   int bkpIndex;
   BreakPointInfo* bkpInfo;
   int bkpFound;
   guint32 dist1, dist2;
   numberOfRefinedBreakpoints = 0;
   xDEBUG(DEB_REFINE_BKPS, fprintf(stderr, "refining %d mps\n", mateContainer->numberOfMatePairs));
   for (mateIndex = 0; mateIndex<mateContainer->numberOfMatePairs; mateIndex++) {
      MatePairInfo* mateInfo = &mateContainer->matePairContainer[mateIndex];
      xDEBUG(DEB_REFINE_BKPS, fprintf(stderr, "sorted matepair [%d]=%d:%d %d:%d %s\n",
            mateIndex, chr1, mateInfo->pos1, mateInfo->chr2, mateInfo->pos2,  mateInfo->mateId));
      bkpFound = 0;
      int sameStrand = (mateInfo->strand1==mateInfo->strand2);
      for (bkpIndex =numberOfRefinedBreakpoints-1; bkpIndex>=0 && !bkpFound; bkpIndex--) {
         bkpInfo = refinedBreakpoints[bkpIndex];
         xDEBUG(DEB_REFINE_BKPS, fprintf(stderr, "comparing current mate [%d] %d(%d)-%d(%d) %s vs bkp %d(%d-%d)-%d(%d,%d)\n",
                                                   mateIndex, chr1, mateInfo->pos1, mateInfo->chr2, mateInfo->pos2, mateInfo->mateId,
                                                   chr1, bkpInfo->pos1Start, bkpInfo->pos1Stop,
                                                   bkpInfo->chr2, bkpInfo->pos2Start, bkpInfo->pos2Stop));
         if (bkpInfo->chr2 == mateInfo->chr2 && bkpInfo->sameStrand==sameStrand) {
            xDEBUG(DEB_REFINE_BKPS, fprintf(stderr, "same chrom\n"));
            if (mateInfo->pos1>bkpInfo->pos1Stop) {
               dist1 =mateInfo->pos1- bkpInfo->pos1Start+1;
            } else if (mateInfo->pos1<bkpInfo->pos1Start) {
               dist1 = bkpInfo->pos1Stop-mateInfo->pos1+1;
            } else {
               dist1 = bkpInfo->pos1Stop- bkpInfo->pos1Start+1;
            }
            if (mateInfo->pos2>bkpInfo->pos2Stop) {
               dist2 =mateInfo->pos2- bkpInfo->pos2Start+1;
            } else if (mateInfo->pos2<bkpInfo->pos2Start) {
               dist2 = bkpInfo->pos2Stop-mateInfo->pos2+1;
            } else {
               dist2 = bkpInfo->pos2Stop- bkpInfo->pos2Start+1;
            }
            xDEBUG(DEB_REFINE_BKPS, fprintf(stderr, "comparing current mate d1 %d d2 %d\n", dist1, dist2));
            if ( (dist1>maxInsertSize) || (dist2>maxInsertSize) ||
                 (chr1==mateInfo->chr2 && ! (mateInfo->pos1<bkpInfo->pos2Stop &&
															mateInfo->pos2>bkpInfo->pos1Start))) {
               continue;
            } else {
               // extended a current breakpoint
               bkpFound = 1;
               xDEBUG(DEB_REFINE_BKPS, fprintf(stderr, "extend bkp! with %d mps\n", bkpInfo->matePairsContainer->numberOfMatePairs));
               bkpInfo->addMatePair(mateInfo);
            }
         }
      }
      guint32 newBkpIndex;
      if (!bkpFound) {
         xDEBUG(DEB_REFINE_BKPS, fprintf(stderr, "start new bkp!\n"));
         // allocate new breakpoint
         if (breakPointsPoolList == NULL) {
            // extend number of allocated breakpoints by 25%
            guint32 numberOfAdditionalBkps = numberOfAllocatedBreakpoints*5/4+1-numberOfAllocatedBreakpoints;
            for (newBkpIndex=0; newBkpIndex<numberOfAdditionalBkps; newBkpIndex++) {
               BreakPointInfo* breakpointInfo = new BreakPointInfo();
               breakPointsPoolList = g_slist_prepend (breakPointsPoolList, (gpointer) breakpointInfo);
            }
            numberOfAllocatedBreakpoints += numberOfAdditionalBkps;
            xDEBUG(DEB_TRACE_BKP_ALLOCS, fprintf(stderr, "increased # of allocated bkps to %d\n",
                                                                   numberOfAllocatedBreakpoints));
         }
         bkpInfo = (BreakPointInfo*) breakPointsPoolList->data;
         breakPointsPoolList = g_slist_remove(breakPointsPoolList, bkpInfo);
         bkpInfo->reset();
         xDEBUG(DEB_REFINE_BKPS, fprintf(stderr, "undefined bkp %d(%d-%d)-%d(%d,%d)\n",
                                                   chr1, bkpInfo->pos1Start, bkpInfo->pos1Stop,
                                                   bkpInfo->chr2, bkpInfo->pos2Start, bkpInfo->pos2Stop));
         bkpInfo->addMatePair(mateInfo);
         xDEBUG(DEB_REFINE_BKPS, fprintf(stderr, "new bkp %d(%d-%d)-%d(%d,%d)\n",
                                                   chr1, bkpInfo->pos1Start, bkpInfo->pos1Stop,
                                                   bkpInfo->chr2, bkpInfo->pos2Start, bkpInfo->pos2Stop));
         numberOfRefinedBreakpoints+= 1;
         if (refinedBreakpointsCapacity<=numberOfRefinedBreakpoints) {
            refinedBreakpointsCapacity= refinedBreakpointsCapacity*5/4+1;
            refinedBreakpoints= (BreakPointInfo**) realloc(refinedBreakpoints,
                                                sizeof(BreakPointInfo*)*refinedBreakpointsCapacity);
         }
         refinedBreakpoints[numberOfRefinedBreakpoints-1] = bkpInfo;
         bkpInfo = refinedBreakpoints[numberOfRefinedBreakpoints-1] ;
         xDEBUG(DEB_REFINE_BKPS, fprintf(stderr, "yet again bkp %d(%d-%d)-%d(%d,%d)\n",
                                                   chr1, bkpInfo->pos1Start, bkpInfo->pos1Stop,
                                                   bkpInfo->chr2, bkpInfo->pos2Start, bkpInfo->pos2Stop));

         if(mateInfo->strand1==mateInfo->strand2) {
            bkpInfo->sameStrand =  1;
         } else {
            bkpInfo->sameStrand =  0;
         }
      }
   }
   for (bkpIndex=0; bkpIndex<numberOfRefinedBreakpoints; bkpIndex++) {
      bkpInfo = refinedBreakpoints[bkpIndex];
      // determine the number of matepairs that have at least one end
      // overlapping with repeats or duplications
      guint32 repeatMates = 0;
      guint32 numberOfMatepairs = bkpInfo->matePairsContainer->numberOfMatePairs;
      if (numberOfMatepairs>1) {
         guint32 mateIdx = 0;
         for (mateIdx=0;
            mateIdx<numberOfMatepairs;
            mateIdx++) {
            MatePairInfo* mateInfo = &bkpInfo->matePairsContainer->matePairContainer[mateIdx];
            if (overlapsWithRepeatOrSegDup(chromosomeString1, mateInfo->pos1, mateInfo->pos1+25) ||
                  overlapsWithRepeatOrSegDup(chromosomeString2, mateInfo->pos2, mateInfo->pos2+25)) {
               repeatMates++;
            }
         }

         if (numberOfMatepairs-repeatMates>=2) {
            xDEBUG(DEB_BKP_REPEAT, fprintf(stderr, "current break [%d,%d]-[%d,%d] has %d/%d ovl w/ repeats mates\n",
            bkpInfo->pos1Start, bkpInfo->pos1Stop,
            bkpInfo->pos2Start, bkpInfo->pos2Stop,
            repeatMates, numberOfMatepairs));
            bkpInfo->dumpBreakPoint(chr1, outFilePtr);   
         } else {
            xDEBUG(DEB_BKP_REPEAT, fprintf(stderr, "current bkp [%d,%d]-[%d,%d] fails  %d/%d ovl w/ repeat mates\n",
                                                          bkpInfo->pos1Start, bkpInfo->pos1Stop,
                                                          bkpInfo->pos2Start, bkpInfo->pos2Stop,
                                                          repeatMates, numberOfMatepairs); bkpInfo->dumpBreakPoint(chr1, stderr));
         }
      }
      // now reclaim bkpInfo
      bkpInfo->reset();
      breakPointsPoolList = g_slist_prepend (breakPointsPoolList, (gpointer) bkpInfo);
   }
   return 0;
}
