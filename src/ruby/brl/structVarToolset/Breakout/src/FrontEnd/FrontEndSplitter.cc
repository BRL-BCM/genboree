#include <stdlib.h>
#include <stdio.h>
#include <getopt.h>
#include <string.h>
#include <strings.h>
#include <sys/types.h>
#include <unistd.h>
#include <wordexp.h>

#include "generic_debug.h"
#include "someConstants.h"
#include "FrontEndSplitter.h"
#include "BRLGenericUtils.h"

// debug flags
#define DEB_SPLIT_INPUT 0
#define DEB_FREAD 0
#define DEB_BUFFER_FREAD 0
#define DEB_CLEANUP 0
#define DEB_BYTES 0
#define SPLIT_FILE_BUFFER_SIZE 32*1024

/*
class MappingsSplitter {
	char inputMappingFile[MAX_FILE_NAME];
public:
	MappingsSplitter();
	~MappingsSplitter();
	int parseParams(int argc, char* argv[]);
	int split();
private:	
	void usage();
};
*/

MappingsSplitter::MappingsSplitter() {
	strcpy(outputDirectory, "");
	strcpy(outputFileRoot, "");
	numberOfParts = 0;
	splitOutputFiles = NULL;
  splitOutputFilesBuffers= NULL;
  splitOutputFilesBufferSize  = NULL;
  suffix = 2;
  inputFileType=UndefinedFileType;
}

MappingsSplitter::~MappingsSplitter() {
	if (splitOutputFiles!=NULL) {
		free(splitOutputFiles);
	}
	if (splitOutputFilesBuffers!=NULL) {
		free(splitOutputFilesBuffers);
	}
	if (splitOutputFilesBufferSize!=NULL) {
		free(splitOutputFilesBufferSize);
	}
  
  wordfree(&inputFiles);
}


int MappingsSplitter::parseParams(int argc, char* argv[]) {
	  static struct option long_options[] = {
    {"mapFile", required_argument, 0, 'm'},
    {"outputDirectory", required_argument, 0, 'o'},
		{"outputFileRoot", required_argument, 0, 'r'},
    {"numberOfParts", required_argument, 0, 'n'},
    {"suffix", required_argument, 0, 'S'},
    {"inputFileType", required_argument, 0, 'T'},
    {"help", no_argument, 0, 'h'},
    {0, 0, 0, 0}
  };
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
  suffix = 2;
  
	while((opt=getopt_long(argc,argv,
                         "m:o:n:r:S:T:h", 
                         long_options, &option_index))!=-1) {
    switch(opt) {
    case 'm':
      //strncpy(inputMappingFile, optarg, MAX_FILE_NAME);
      wordexp(optarg, &inputFiles, WRDE_NOCMD | WRDE_SHOWERR | WRDE_UNDEF | WRDE_SYNTAX);
      unsigned int i;
      for (i=0; i<inputFiles.we_wordc; i++) {
        fprintf(stderr, "Acknowledging input file %s\n", inputFiles.we_wordv[i]);
      }
      break;
    case 'o':
      strncpy(outputDirectory, optarg, MAX_FILE_NAME);
      break;
		case 'r':
      strncpy(outputFileRoot, optarg, MAX_FILE_NAME);
      break;
    case 'n':
      numberOfParts = strtoul(optarg, NULL, 10);
      break;
    case 'S':
      suffix = strtoul(optarg, NULL, 10);
      break;
    case 'T':
      if (!strcasecmp(optarg, "bed")) {
        inputFileType=BEDFile;
      } else if (!strcasecmp(optarg, "sam")) {
        inputFileType=SAMFile;
      } if (!strcasecmp(optarg, "bam")) {
        inputFileType=BAMFile;
      } if (!strcasecmp(optarg, "pash")) {
        inputFileType=PashFile;
      }
      break;
    case 'h':
      usage();
      return 1;
    default:
      fprintf(stderr, "unknown option %c \n", opt);
      usage();
      return 1;
    }
  }
	// validate the parameters
	if (!strcmp(outputDirectory, "")) {
		fprintf(stderr, "The output directory was not specified.\n");
		return 1;
	}
		
	if (numberOfParts<2 || numberOfParts>1024) {
		fprintf(stderr, "the number of output parts should be an integer between 2 and 1024.\n");
		return 1;	
	}
  
  if (inputFileType==UndefinedFileType) {
    fprintf(stderr, "Need to specify input file type\n");
  }
  
	return 0;
} // MappingsSplitter::parseParams

/** Split the input file.
 * @return 0 if success, 1 otherwise.*/
int MappingsSplitter::split() {
	int result;
	BRLGenericUtils::printNow(stderr);
	result = prepareOutputFiles();
  unsigned int inputIndex;
  if (!result) {
    for (inputIndex = 0; inputIndex < inputFiles.we_wordc; inputIndex++) {
      fprintf(stderr, "about to traverse the input %s\n", inputFiles.we_wordv[inputIndex]);	
      result=traverseInputFile(inputFiles.we_wordv[inputIndex]);
      fprintf(stderr, "finished traversing the input %s\n", inputFiles.we_wordv[inputIndex]);	
    }
    xDEBUG(DEB_SPLIT_INPUT, fprintf(stderr, "finished traversing the input\n"));	
  	finalizeOutputFiles();
    xDEBUG(DEB_SPLIT_INPUT, fprintf(stderr, "finished closing output files\n"));	
	}
  xDEBUG(DEB_SPLIT_INPUT, fprintf(stderr, "finished w/ splitting\n"));
  BRLGenericUtils::printNow(stderr);
	return result;
} // MappingsSplitter::split

void MappingsSplitter::usage() {
	  fprintf(stderr,
"Utility that takes as input a SOLID/Illumina mappings file, in bed, sam, bam, or pash format, "
"and splits it into  multiple output files based on read id. The program attempts to balance the size\n"
"of the split output files. \n"
"  --mapFile          | -m    ===> SOLID/Illumina mappings file(s) to split\n"
"  --numberOfParts    | -n    ===> number of output parts (between 10 and 1024)\n"
"  --outputDirectory  | -o    ===> output directory\n"
"  --outputFileRoot   | -r    ===> output file root"
"                                  The output file names are going to be \n"
"                                  <output file root>.part.<part number>.\n"
"  --suffix           | -S    ===> Read name suffix size used to distinguish between \n"
"                                  the reads in the matepairs; default 2\n"
"                                  Illumina uses the convention <readname>/(1|2) \n"
"                                  SOLID uses the convention <readname>_(R|F)3 \n"
"  --inputFileType    | -T    ===> Input file type; accepted values are bed, sam, bam, pash \n"
"  --help             | -h    ===> print this help and exit\n"
);
} // MappingsSplitter::usage() {

int MappingsSplitter::prepareOutputFiles() {
	char partOutputFileName[2*MAX_LINE_LENGTH+1];
	guint32 i;
	
	splitOutputFiles = (FILE**) malloc(sizeof(FILE*)*numberOfParts);
	if (splitOutputFiles==NULL) {
		fprintf(stderr, "Could not allocate split output file handles.\n");
		return 1;
	}
	splitOutputFilesBuffers = (char **) malloc(sizeof(char*)*numberOfParts);
  if (splitOutputFilesBuffers==NULL) {
		fprintf(stderr, "Could not allocate split output file buffers.\n");
		return 1;
	}
	splitOutputFilesBufferSize = (guint32 *) malloc(sizeof(guint32)*numberOfParts);
	if (splitOutputFilesBufferSize==NULL) {
		fprintf(stderr, "Could not allocate split output file buffer sizes.\n");
		return 1;
	}
  for (i=0; i<numberOfParts; i++) {
    splitOutputFilesBuffers[i] = (char*) malloc(sizeof(char)*SPLIT_FILE_BUFFER_SIZE);
    splitOutputFilesBufferSize[i]=0;
  }
	
	for (i=0; i<numberOfParts; i++) {
		sprintf(partOutputFileName, "%s/%s.part.%d", outputDirectory, outputFileRoot, i);
		splitOutputFiles[i] = fopen(partOutputFileName, "wt");
    if (splitOutputFiles[i]==NULL) {
      fprintf(stderr, "could not open temporary file %s\n", partOutputFileName);
      return 1;
    }
	}
	
	return 0;
} // MappingsSplitter::prepareOutputFiles()

int MappingsSplitter::traverseInputFile(char* inputMappingFile) {
	FILE* tmpFilePtr;
  char buffer[DEFAULT_BUFFER_SIZE];
  guint32 bufferPos;
  guint32 bufferSize = DEFAULT_BUFFER_SIZE/2;
  guint maxLineSize;
  
  guint32 dataSize, transferSize;
  guint32 startingPos;
  guint32 bPos;
  char readName[MAX_LINE_LENGTH];
	char stripReadName[MAX_LINE_LENGTH];
  char chromName[MAX_LINE_LENGTH];
  guint32 chromStart, chromStop;
	guint32 keepIndex;
  guint32 i;
	guint32 readStart, readStop;
  char strand;
  
	tmpFilePtr = BRLGenericUtils::openTextGzipBzipFile(inputMappingFile);
  if (tmpFilePtr==NULL){
		fprintf(stderr, "could not open temporary file %s\n", inputMappingFile);
    return 1;
	}
  bufferPos = 0;
	keepIndex = 0;
	guint hashKey;
  
  maxLineSize = 0;
  chromStart = 0;
  chromStop  = 0;
  
  guint32 bamFlag;
  
	while (1) {
    // fill up array using a heap discipline
    xDEBUG(DEB_BUFFER_FREAD, fprintf(stderr, "about to read mappings of size %d at position %d\n",
                              bufferSize, bufferPos));
    transferSize = fread(&buffer[bufferPos], sizeof(char), bufferSize, tmpFilePtr);
    xDEBUG(DEB_BUFFER_FREAD, fprintf(stderr, "read %d elements\n", transferSize));
                              
    
    if (transferSize == 0) {
      if (bufferPos>0) {
        buffer[bufferPos]='\0';
        fprintf(stderr, "last line \n%s\n", &buffer[0]);
      }
      break;
    }
		
    dataSize = bufferPos+transferSize;
    xDEBUG(DEB_BUFFER_FREAD, fprintf(stderr,"current buffer\n");
           for (bPos=0; bPos<dataSize; bPos++) { fprintf(stderr, "%c", buffer[bPos]);}; fprintf(stderr, "\n"););
    startingPos = 0;
    
    for (bPos=0; bPos<dataSize; bPos++) {
      if (buffer[bPos]=='\n') {
        buffer[bPos]='\0';
        xDEBUG(DEB_FREAD, fprintf(stderr, "found line %s\n", &buffer[startingPos]));
        if ( strlen(&buffer[startingPos])>maxLineSize) {
          maxLineSize = strlen(&buffer[startingPos]);
          xDEBUG(DEB_BYTES, fprintf(stderr, "max line size upgraded to %d\n", maxLineSize));
        }
        int skipFlag = 0;
				switch(inputFileType) {
          case SAMFile:
          case BAMFile:
            if (buffer[startingPos]=='@') {
              skipFlag=1;
            } else {
              sscanf(&buffer[startingPos], "%s %d %s %d", readName, &bamFlag, chromName, &chromStart);
	      if (chromName[0]=='*'){ 
                skipFlag = 1; 
              } else {
                char* search1 = strstr(&buffer[startingPos], "NH:i:1");
                char* search2 = strstr(&buffer[startingPos], "NH:i:1 ");
                char* search3 = strstr(&buffer[startingPos], "NH:i:1\t");
                if (search1==NULL) {
                  skipFlag=1;
                } else if (search2 == NULL && search3==NULL && !strcmp(search1, "NH:i:1")) {
                  skipFlag=1;
                } else {  
                  chromStop = chromStart + 25;
                  if (bamFlag & 0x0010) {
                    strand = '-';
                  } else {
                    strand = '+';
                  }
		}
              }
            }
            break;
          case BEDFile:
            sscanf(&buffer[startingPos], "%s %d %d %s %c", chromName, &chromStart, &chromStop, readName, &strand);
            break;
          case PashFile:
            sscanf(&buffer[startingPos], "%s %d %d %s %d %d %c",
                   chromName, &chromStart, &chromStop, readName, &readStart, &readStop, &strand);
            break;
          default:
            exit(0);
            break;
        }
        
        if (!skipFlag) {
					strcpy(stripReadName, readName);
          stripReadName[strlen(readName)-suffix]='\0';
          hashKey = g_str_hash(stripReadName);
          keepIndex = hashKey%numberOfParts;
          xDEBUG(DEB_SPLIT_INPUT, fprintf(stderr, "Read %s hash %d index %d\n",
                                              readName, hashKey, keepIndex));
          
          sprintf(&splitOutputFilesBuffers[keepIndex][splitOutputFilesBufferSize[keepIndex]],
                   "%s\t%d\t%d\t%s\t%c\n", chromName, chromStart, chromStop, readName, strand);
          splitOutputFilesBufferSize[keepIndex] = strlen(splitOutputFilesBuffers[keepIndex]);
          if (splitOutputFilesBufferSize[keepIndex]>SPLIT_FILE_BUFFER_SIZE/2) {
            fprintf(splitOutputFiles[keepIndex], "%s", splitOutputFilesBuffers[keepIndex]);
            splitOutputFilesBufferSize[keepIndex] = 0;
            splitOutputFilesBuffers[keepIndex][0] = '\0';
          }
        }
        // dump it there
        startingPos = bPos+1;
      }
    }
    if (startingPos<dataSize) {
      if (startingPos>0) {
        memcpy(&buffer[0], &buffer[startingPos],(dataSize-startingPos)*sizeof(char));
      }
      bufferPos = dataSize-startingPos;
    } else {
      bufferPos = 0;
    }
  }
  fclose(tmpFilePtr);
  
  
  for (i=0; i<numberOfParts; i++) {
    if (splitOutputFilesBufferSize[i]>0) {
      fprintf(splitOutputFiles[i], "%s", splitOutputFilesBuffers[i]);
      splitOutputFilesBufferSize[i]=0;
    }
  }
	return 0;
} // MappingsSplitter::traverseInputFile





void MappingsSplitter::finalizeOutputFiles() {
	guint32 i;
  xDEBUG(DEB_CLEANUP, fprintf(stderr, "started closing files\n"));	
	for (i=0; i<numberOfParts; i++) {
    xDEBUG(DEB_CLEANUP, fprintf(stderr, "about to close file %d %p\n", i, splitOutputFiles[i]));	
		fclose(splitOutputFiles[i]);
    xDEBUG(DEB_CLEANUP, fprintf(stderr, "closed file %d\n", i));	
	}
  xDEBUG(DEB_CLEANUP, fprintf(stderr, "finished closing files\n"));	
}

