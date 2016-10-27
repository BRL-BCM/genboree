#ifndef __AnnotationIndex__H___
#define __AnnotationIndex__H___

#include <glib.h>

struct AbbreviatedAnnotation {
public:	
	guint32 id;
	guint32 startPos;
	guint32 stopPos;
	guint32 padding;
};

class AbbreviatedAnnotationContainer {
public:
	AbbreviatedAnnotationContainer();
	~AbbreviatedAnnotationContainer();
	guint32 addAnnotation(guint32 id, guint32 startPos, guint32 stopPos);
	AbbreviatedAnnotation *annotationContainer;
	guint32 numberOfAnnotations;
	guint32 containerCapacity;
};


class SingleReferenceIndex {
public:
	guint32 size;
	guint32 numberOfContainers;
	AbbreviatedAnnotationContainer* annotationContainers;
public:
	SingleReferenceIndex(guint32 _size, guint32 _numberOfContainers);
	~SingleReferenceIndex();
};

/** Class that builds an efficient in-memory index of genomic targets,
 * and offers the service of retrieving all targets that overlap
 * with a user provided location.*/
class AnnotationIndex {
	guint32 windowSize;
	GHashTable* referenceHash;
public:
	/** Constructor.*/
	AnnotationIndex(guint32 _windowSize=100000);
	/** Destructor.*/
	~AnnotationIndex();
	/** Add reference information: chromosomes and lengths.*/
	int addReference(char* referenceName, guint32 referenceSize);
	/** Add individual annotations to the annotation index.*/
	int addAnnotation(guint32 id, char* entryPoint, guint32 startPos, guint32 stopPos, void *stringCounterCheck);
	/** Return a rudimentary iterator to the collection of annotations that overlap with the
	 * genomic location presented as argument.*/
	AbbreviatedAnnotationContainer* lookupElement(char* entryPoint,
																								guint32 startPos, guint32 stopPos,
																								guint32* numberOfContainers);
		
};

#endif

