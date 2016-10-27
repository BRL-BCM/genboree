#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include "AnnotationIndex.h"
#include "generic_debug.h"
#include "StringCounter.h"

#define DEB_ADD_ANNOTATION 0

AbbreviatedAnnotationContainer::AbbreviatedAnnotationContainer() {
	numberOfAnnotations = 0;
	containerCapacity=10;
  annotationContainer = (AbbreviatedAnnotation*) malloc(sizeof(AbbreviatedAnnotation)*containerCapacity);	
}

/** Add another annotation to the current container.
 * @return 0 for success, 1 otherwise
 * */
guint32 AbbreviatedAnnotationContainer::addAnnotation(guint32 id, guint32 startPos, guint32 stopPos) {
	numberOfAnnotations ++;
  if (numberOfAnnotations>=(containerCapacity-1)) {
		containerCapacity = containerCapacity*5/4;
    annotationContainer =
		  (AbbreviatedAnnotation*) realloc(annotationContainer,
                                       sizeof(AbbreviatedAnnotation)*containerCapacity);
    if (annotationContainer==NULL) {
     fprintf(stderr, "could not allocate memory for the allocation container\n");
     return 1;
    }
	}
  
  annotationContainer[numberOfAnnotations-1].id = id;
  annotationContainer[numberOfAnnotations-1].startPos = startPos;
  annotationContainer[numberOfAnnotations-1].stopPos  = stopPos;
  return 0;	
}	

/** Releases the memory for the annotation container.*/
AbbreviatedAnnotationContainer::~AbbreviatedAnnotationContainer() {
	if (numberOfAnnotations > 0) {
		free(annotationContainer);
		numberOfAnnotations = 0;
	}
}

SingleReferenceIndex::SingleReferenceIndex(guint32 _size, guint32 _numberOfContainers) {
  size = _size;
  numberOfContainers = _numberOfContainers;
  annotationContainers = new AbbreviatedAnnotationContainer[numberOfContainers];
  if (annotationContainers==NULL) {
    fprintf(stderr, "could not allocate annotation container for the single reference index\n");
    exit(2);
  }
}

SingleReferenceIndex::~SingleReferenceIndex() {
  delete annotationContainers;  
}

/** Load reference information: chromosomes and lengths.
@return 0 if success, 1 otherwise
*/
int AnnotationIndex::addReference(char* referenceName, guint32 referenceSize){
  // TODO: more thorough validation
  guint32 numberOfContainers= referenceSize/windowSize+1;
  SingleReferenceIndex* singleReferenceIndex = new SingleReferenceIndex(referenceSize, numberOfContainers);
	g_hash_table_insert(referenceHash, g_strdup(referenceName), (gpointer)singleReferenceIndex);
  xDEBUG(DEB_ADD_ANNOTATION, fprintf(stderr, "added reference %s of size %d with %d containers \n",
                                     referenceName, referenceSize, numberOfContainers));
  return 0;
}

AnnotationIndex::AnnotationIndex(guint32 _windowSize) {
	// free up resources
	windowSize = _windowSize;
  referenceHash = g_hash_table_new(g_str_hash, g_str_equal);
  if (referenceHash == NULL ) {
    fprintf(stderr,
            "could not allocate reference hash in the AnnotationIndex class at %s:%d\n",
            __FILE__,
            __LINE__);
    exit(2);
  }
}

AnnotationIndex::~AnnotationIndex() {
	// free up resources
  g_hash_table_destroy(referenceHash);
}

/** Add individual annotations to the annotation index.
@return 0 if success, 1 otherwise
@param id  annotation id
*/
int AnnotationIndex::addAnnotation(guint32 id, char* entryPoint, guint32 startPos, guint32 stopPos, void *stringCounterCheck=NULL) {
	guint32 i;
  xDEBUG(DEB_ADD_ANNOTATION, fprintf(stderr, "requested to add annotation %s: %d-%d \n",
                                     entryPoint, startPos, stopPos));
  
  // obtain the Single reference index
  SingleReferenceIndex* singleReferenceIndex =
    (SingleReferenceIndex*) g_hash_table_lookup(referenceHash, entryPoint);
  if (singleReferenceIndex == NULL) {
    fprintf(stderr, "could not retrieve the information for entry point %s\n", entryPoint);
    return 1;
  }
  guint32 startSlice = startPos/windowSize;
  guint32 stopSlice = stopPos/windowSize;
  if (stopSlice>=singleReferenceIndex->numberOfContainers) {
    fprintf(stderr, "number of containers %d: tried to add (%s,%d,%d) to container %d\n",
            singleReferenceIndex->numberOfContainers, entryPoint, startPos, stopPos, stopSlice);
    if (startSlice<singleReferenceIndex->numberOfContainers) {
			stopSlice = singleReferenceIndex->numberOfContainers-1;
		} else {
			return 1;
		}
  }
  
  // TODO : check that the addition return successfully for each container
  xDEBUG(DEB_ADD_ANNOTATION, fprintf(stderr, "attempt to add annotation %s: %d-%d on reference index %x, slices %d to %d\n",
                                     entryPoint, startPos, stopPos, singleReferenceIndex, startSlice, stopSlice));
  
	for (i=startSlice; i<=stopSlice; i++) {
    if (singleReferenceIndex->annotationContainers[i].addAnnotation(id, startPos, stopPos)) {
      return 1;
    }
  }
	
  xDEBUG(DEB_ADD_ANNOTATION, fprintf(stderr, "added annotation %s: %d-%d on reference index %x, slices %d to %d\n",
                                     entryPoint, startPos, stopPos, singleReferenceIndex, startSlice, stopSlice));
  return 0;
}

/** Return a rudimentary iterator to the collection of containers
 * that overlap with the
 * genomic location presented as argument.*/
AbbreviatedAnnotationContainer* AnnotationIndex::lookupElement(char* entryPoint,
                                                               guint32 startPos, guint32 stopPos,
                                                               guint32 *numberOfContainers) {
	// obtain the Single reference index
  SingleReferenceIndex* singleReferenceIndex = (SingleReferenceIndex*) g_hash_table_lookup(referenceHash, entryPoint);
  if (singleReferenceIndex == NULL) {
    fprintf(stderr, "could not retrieve the information for entry point %s\n", entryPoint);
    return NULL;
  }
  guint32 startSlice = startPos/windowSize;
  guint32 stopSlice = stopPos/windowSize;
  if (startSlice>=singleReferenceIndex->numberOfContainers) {
    return NULL;
  } else { 
    if (stopSlice >=singleReferenceIndex->numberOfContainers) {
      stopSlice = singleReferenceIndex->numberOfContainers-1; 
    }
    *numberOfContainers = (stopSlice-startSlice+1);
    return &singleReferenceIndex->annotationContainers[startSlice];
  }
  return NULL;
}

