#ifndef __Solid_MappingsSplitter___H__
#define __Solid_MappingsSplitter___H__
#include <wordexp.h>
#include <glib.h>
#include "someConstants.h"
#include "frontEndDefines.h"

class MappingsSplitter {
	char outputDirectory[MAX_FILE_NAME];
	char outputFileRoot[MAX_FILE_NAME];
	
  wordexp_t inputFiles;
	guint32 numberOfParts;
	FILE** splitOutputFiles;
  char ** splitOutputFilesBuffers;
  guint32 *splitOutputFilesBufferSize;
  guint32 suffix;
  InputFileType inputFileType;
public:
	MappingsSplitter();
	~MappingsSplitter();
	int parseParams(int argc, char* argv[]);
	int split();
private:	
	void usage();
	int prepareOutputFiles();
	int traverseInputFile(char* inputFile);
	void finalizeOutputFiles();
};


#endif

