#ifndef __MatePairIndex__H___
#define __MatePairIndex__H___

#include <glib.h>
#include "MateMappingStatus.h"

#define READ_NAME_PREFIX 50 

struct MatePairInfo {
	guint32 pos1;
	guint32 strand1;
	guint32 mismatches1;
	guint32 chr2;
	guint32 pos2;
	guint32 strand2;
	guint32 mismatches2;
	MateMappingStatus mateType;
	char mateId[READ_NAME_PREFIX+2];
};

struct MatePairContainer {
	MatePairContainer();
	~MatePairContainer();
	int addMatePair(guint32 pos1, guint32 strand1, guint32 mismatches1,
						guint32 chr2, guint32 pos2, guint32 strand2, guint32 mismatches2,
						MateMappingStatus mateType, char* mateId);
	void reset();
	MatePairInfo *matePairContainer;
	guint32 numberOfMatePairs;
	guint32 containerCapacity;
};

/** Class that builds an efficient in-memory index of genomic targets,
 * and offers the service of retrieving all targets that overlap
 * with a user provided location.*/
struct MatePairIndex {
	/** Constructor.*/
	MatePairIndex(guint32 _chromosomeSize=300000000, guint32 _windowSize=100000);
	/** Destructor.*/
	~MatePairIndex();
	/** Add individual matepair to the annotation index.*/
	int addMatePair(guint32 pos1, guint32 strand1, guint32 mismatches1,
					guint32 chr2, guint32 pos2, guint32 strand2, guint32 mismatches2,
					MateMappingStatus mateType, char* mateId);

	guint32 numberOfContainers;
	guint32 windowSize;
	guint32 chromosomeSize;
	MatePairContainer* matePairContainers;
};

#endif

