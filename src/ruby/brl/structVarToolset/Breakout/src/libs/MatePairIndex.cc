#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <string.h>

#include "MatePairIndex.h"
#include "generic_debug.h"

#define DEB_DESTRUCTOR_MP_INDEX 0
#define DEB_ADD_MATEPAIR 0

MatePairContainer::MatePairContainer() {
	numberOfMatePairs = 0;
	containerCapacity=1;
	matePairContainer = (MatePairInfo*) malloc(sizeof(MatePairInfo)*containerCapacity);
	xDEBUG(DEB_DESTRUCTOR_MP_INDEX, fprintf(stderr, "allocated matepair container of capacity %d %p\n",
																					containerCapacity, matePairContainer));
}

/** Add another annotation to the current container.
 * @return 0 for success, 1 otherwise
 * */
int MatePairContainer::addMatePair(guint32 pos1, guint32 strand1, guint32 mismatches1,
										guint32 chr2, guint32 pos2, guint32 strand2, guint32 mismatches2,
										MateMappingStatus mateType, char* mateId) {
	numberOfMatePairs ++;
	if (numberOfMatePairs>=(containerCapacity-1)) {
		containerCapacity = containerCapacity*5/4+1;
		matePairContainer =
		  (MatePairInfo*) realloc(matePairContainer,
								  sizeof(MatePairInfo)*containerCapacity);
		if (matePairContainer==NULL) {
		 fprintf(stderr, "could not allocate memory for the allocation container\n");
		 return 1;
		}
	}
  
  matePairContainer[numberOfMatePairs-1].pos1= pos1;
  matePairContainer[numberOfMatePairs-1].strand1 = strand1;
  matePairContainer[numberOfMatePairs-1].mismatches1  = mismatches1;
  matePairContainer[numberOfMatePairs-1].chr2 = chr2;
	matePairContainer[numberOfMatePairs-1].pos2= pos2;
  matePairContainer[numberOfMatePairs-1].strand2 = strand2;
  matePairContainer[numberOfMatePairs-1].mismatches2  = mismatches2;
  matePairContainer[numberOfMatePairs-1].mateType  = mateType;
	strncpy(matePairContainer[numberOfMatePairs-1].mateId, mateId, READ_NAME_PREFIX);
  if (strlen(mateId) > READ_NAME_PREFIX) {
    matePairContainer[numberOfMatePairs-1].mateId[READ_NAME_PREFIX]='\0';
  }
  
  return 0;	
}	

/** Reset the container, setting the number of items to zero, but keeping the capacity.*/
void MatePairContainer::reset() {
  numberOfMatePairs = 0;
}

/** Releases the memory for the annotation container.*/
MatePairContainer::~MatePairContainer() {
	xDEBUG(DEB_DESTRUCTOR_MP_INDEX, fprintf(stderr, "deleting a matepair container %p\n",
																					matePairContainer));
	if (numberOfMatePairs > 0) {
		xDEBUG(DEB_DESTRUCTOR_MP_INDEX, fprintf(stderr, "having actual matepairs %d in %p\n",
																					numberOfMatePairs, matePairContainer));
	
		free(matePairContainer);
		numberOfMatePairs = 0;
		containerCapacity = 0;
	}
	xDEBUG(DEB_DESTRUCTOR_MP_INDEX, fprintf(stderr, "done freeing matePair container %p -> %p\n",
																					this, matePairContainer));
	
}

MatePairIndex::MatePairIndex(guint32 _chromosomeSize, guint32 _windowSize) {
	// free up resources
	chromosomeSize = _chromosomeSize;
	windowSize = _windowSize;
	numberOfContainers = chromosomeSize/windowSize+1;
	xDEBUG(DEB_DESTRUCTOR_MP_INDEX, fprintf(stderr, "about to allocate %d containers\n", numberOfContainers));
  matePairContainers = new MatePairContainer[numberOfContainers];
  if (matePairContainers==NULL) {
    fprintf(stderr, "could not allocate matePairContainers\n");
    exit(2);
  }
}

MatePairIndex::~MatePairIndex() {
	// free up resources
	xDEBUG(DEB_DESTRUCTOR_MP_INDEX, fprintf(stderr, "deleting mate pair index\n"));
  delete [] matePairContainers;
	xDEBUG(DEB_DESTRUCTOR_MP_INDEX, fprintf(stderr, "DONE deleting mate pair index\n"));
}

/** Add individual matePair to the matepair index.
@return 0 if success, 1 otherwise
@param id  annotation id
*/
int MatePairIndex::addMatePair(guint32 pos1, guint32 strand1, 
				guint32 mismatches1, guint32 chr2, 
				guint32 pos2, guint32 strand2,
				guint32 mismatches2,
                      		MateMappingStatus mateType, char* mateId) {
  xDEBUG(DEB_ADD_MATEPAIR, fprintf(stderr, "requested to add annotation %s: %d-%d \n",
                                     mateId, pos1, pos2));
  
  guint32 slice = pos1/windowSize;
  if (slice>=numberOfContainers) {
    fprintf(stderr, "number of mate containers %d: tried to add (%s,%d) to container %d\n",
            numberOfContainers,  mateId, pos1, slice);
		return 1;
  }
  
  // TODO : check that the addition return successfully for each container
  xDEBUG(DEB_ADD_MATEPAIR, fprintf(stderr, "attempt to add mate %s: %d on slices %d \n",
                                     mateId, pos1, slice));
  
  return matePairContainers[slice].addMatePair(pos1, strand1, mismatches1, chr2, pos2, strand2, mismatches2, mateType, mateId);
}

