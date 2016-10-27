#ifndef _SolidMatepairsAnalyzer____H_
#define _SolidMatepairsAnalyzer____H_

#include <glib.h>
#include "someConstants.h"

/** Solid mapping in a nutshell.*/
typedef struct {
	guint32 chromosome;
	guint32 position;
	guint32 mismatches;
	/** Strand: 0 for +, 1 for -.*/
	guint32 strand; 
} SolidMapping;

class SolidMatepairsAnalyzer{
	/** Forward mappings.*/
  char inputFileOne[MAX_FILE_NAME];
  /** Reverse mappings.*/
	char inputFileTwo[MAX_FILE_NAME];
  /** Root of the output file.*/
	char outputFileRoot[MAX_FILE_NAME];
	
	/** Root of the output file.*/
	char consistentFileRoot[MAX_FILE_NAME];
	
  /** File containing the consistent matepairs.*/
	char consistentMatepairsFile[MAX_FILE_NAME];
  /** File stream for the consistent matepairs.*/
  FILE* consistantMatepairsFilePtr;
  
  /** Number of chromosomes of the reference genome.*/
	guint32 numberOfChromosomes;
	/** Number of split output files.*/
  FILE** splitOutputFiles;
  /** Output buffers.*/
  char ** splitOutputFilesBuffers;
  /** Usage information for the output buffers.*/
  guint32 *splitOutputFilesBufferSize;
  /** Insert size lower bound.*/
  gint32 lowerBound;
  /** Insert size upper bound.*/
  gint32 upperBound;
  /** Number of output file parts.*/
  guint32 numberOfParts;
  
	FILE** consistentOutputFiles;
  /** Output buffers.*/
  char ** consistentOutputFilesBuffers;
  /** Usage information for the output buffers.*/
  guint32 *consistentOutputFilesBufferSize;
  /** Read mappings hash.*/
  GHashTable *mappingsHash;
	/** Reporting variables.*/
	guint32 consistentMatesUniqueUnique;
	guint32 consistentMatesUniqueMultiple;
	guint32 multipleMultipleMates;
	guint32 inconsistentUniqueUniqueMates;
	guint32 inconsistentUniqueMultipleMates;
	guint32 numberOfReadsInFileOne;
	guint32 numberOfReadsInFileTwo;


	/** Storage for the forward mappings.*/
	SolidMapping* forwardMappings;
	guint32 numberOfForwardMappings;
	/** Storage for the reverse mappings.*/
	SolidMapping* reverseMappings;
	guint32 numberOfReverseMappings;
public:
  /** Constructor.*/
	SolidMatepairsAnalyzer();
  /** Destructor.*/
	~SolidMatepairsAnalyzer();
	/** Parse command line arguments.*/
  int parseParams(int argc, char* argv[]);
  /** Perform the matepair analysis.*/
	int analyze();
private:
  /** Display usage information.*/
	void usage();
  /** Initialize output files.*/
	int prepareOutputFiles();
  /** Load up first mappings file.*/
	int hashInputFileOne();
  /** Traverse the second mapping file and look for consistent/inconsistent mappings.*/
  int traverseInputFileTwo();
	/** Look for consistent matches.*/
	int lookForConsistentMatesMappings(char* readId, char* mappingOne, char* mappingTwo);
  /** Flush buffers and close output files.*/
	void finalizeOutputFiles();
	/** Report analysis statistics.*/
	void reportStatistics(FILE* outFile);
	/** Parse a set of SOLID mappings.*/
	void parseMappings(char* mappingString, SolidMapping *solidMappings,guint32 expectedNumberOfMappings);
	/** Dump invalid mappings in the UMA format.*/
	void dumpInvalidMappings(char* readId, SolidMapping* forwardMappings, guint32 numberOfMappingsOne,
													 SolidMapping* reverseMappings, guint32 numberOfMappingsTwo);
	/** Dump valid mappings in the UMA format.*/
	void dumpValidMapping(char* readId, SolidMapping* forwardMapping, guint32 numberOfMappingsOne,
												 SolidMapping* reverseMapping, guint32 numberOfMappingsTwo);
};

#endif

