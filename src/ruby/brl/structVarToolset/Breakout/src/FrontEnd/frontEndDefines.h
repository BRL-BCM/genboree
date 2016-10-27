#ifndef __frontEnd__defs
#define __frontEnd__defs

typedef enum {BEDFile, SAMFile, BAMFile, PashFile, UndefinedFileType} InputFileType;

/** Solid mapping in a nutshell.*/
typedef struct {
	guint32 chromosome;
	guint32 position;
	/** Strand: 0 for +, 1 for -.*/
	guint32 strand; 
} IndividualMapping;

#endif
