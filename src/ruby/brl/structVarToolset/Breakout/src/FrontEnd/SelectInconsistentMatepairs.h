#ifndef _SolidMatepairsAnalyzer____H_
#define _SolidMatepairsAnalyzer____H_

#include <glib.h>
#include "someConstants.h"
#include "frontEndDefines.h"

class SelectInconsistentMatepairs {
	/** Forward mappings.*/
  char inputFileOne[MAX_FILE_NAME];
  /** Reverse mappings.*/
	char inputFileTwo[MAX_FILE_NAME];
  /** Output file.*/
	char outputFile[MAX_FILE_NAME];
	FILE* outputFilePtr;
	char outputConsistentMatepairs[MAX_FILE_NAME];
	FILE* outputConsistentPtr;
	
  GHashTable *mappingsHash;
	/** Storage for the forward mappings.*/
	IndividualMapping* forwardMappings;
	guint32 numberOfForwardMappings;
	/** Storage for the reverse mappings.*/
	IndividualMapping* reverseMappings;
	guint32 numberOfReverseMappings;
	// maximum insert size to consider
	gint maximumInsertSize;
	// minimum insert size to consider
	gint minimumInsertSize;
	// minimum non chimeric insert size to consider
	gint minimumNonChimericInsertSize;
	// suffix of forward reads
	char forwardReadSuffix[MAX_LINE_LENGTH];
	// suffix of reverse reads
	char reverseReadSuffix[MAX_LINE_LENGTH];
	// length of forward/reverse suffix
	guint32 suffixLength;
	// relative strand for consistent matepairs: 0 same, 1 diff
	int relativeStrand;
	// input file type
	InputFileType inputFileType;
	// chromosome name to number hash
	GHashTable* chromosomeNameToNumberHash;
	// chromosome name to number correspondence file
	char chromosomeNameToNumberFile[MAX_FILE_NAME];
	
	guint32 consistentPairs;
	guint32 inconsistentPairs;
	guint32 singletons;
	guint32 totalReads;
public:
  /** Constructor.*/
	SelectInconsistentMatepairs();
  /** Destructor.*/
	~SelectInconsistentMatepairs();
	/** Parse command line arguments.*/
  int parseParams(int argc, char* argv[]);
  /** Perform the matepair analysis.*/
	int analyzeMatePairs();
private:
  /** Display usage information.*/
	void usage();
  /** Initialize output files.*/
	int prepareOutputFile();
  /** Load up first mappings file.*/
	int hashInputFileOne();
  /** Traverse the second mapping file and look for consistent/inconsistent mappings.*/
  int traverseInputFileTwo();
	/** Report the insert size histogram. */
	void finalizeHistogram();
	/** Convert a chromosome name to a number */
	gulong getChromosomeNumber(char* chromosomeName);
	/** Load the correspondence between chromosome names and numbers.*/
	int loadChromosomeNumberHash();
};

#endif

