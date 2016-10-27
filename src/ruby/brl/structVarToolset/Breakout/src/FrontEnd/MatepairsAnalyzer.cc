#include <stdlib.h>
#include <stdio.h>
#include <getopt.h>
#include <string.h>
#include <strings.h>
#include <sys/types.h>
#include <unistd.h>
#include <glib.h>

#include "generic_debug.h"
#include "someConstants.h"
#include "SolidMatepairsAnalyzer.h"
#include "BRLGenericUtils.h"
#include "MateMappingStatus.h"

#define DEB_PARSE_PARAMS    0
#define DEB_OUTPUT_SETUP    0
#define DEB_CLEANUP         0
#define DEB_BUFFER_FREAD    0
#define DEB_FREAD           0
#define DEB_BYTES           0
#define DEB_HASH_FILE_ONE   0
#define DEB_TRAVERSE_FILE_TWO 0
#define DEB_VALID_MATES  0
#define DEB_PARSE_MAPPINGS 0
#define DEB_DUMP_INVALID_MAPPINGS 0
#define DEB_DUMP_VALID_MAPPINGS 0

#define SPLIT_FILE_BUFFER_SIZE 8*1024

/** Constructor.*/
SolidMatepairsAnalyzer::SolidMatepairsAnalyzer() {
  strcpy(inputFileOne, "");
  strcpy(inputFileTwo, "");
  strcpy(outputFileRoot, "");
  strcpy(consistentMatepairsFile, "");
  
  
  numberOfChromosomes = 0;
  lowerBound = 0;
  upperBound = 0;
  
  numberOfParts = 0;
  splitOutputFiles = NULL;
  splitOutputFilesBuffers= NULL;
  splitOutputFilesBufferSize  = NULL;

  consistentOutputFiles = NULL;
  consistentOutputFilesBuffers = NULL;
  consistentOutputFilesBufferSize = NULL;


  mappingsHash = g_hash_table_new(g_str_hash, g_str_equal);

	// initialize report variables
	consistentMatesUniqueUnique = 0;
	consistentMatesUniqueMultiple = 0;
	multipleMultipleMates = 0;
	inconsistentUniqueUniqueMates = 0;
	inconsistentUniqueMultipleMates = 0;
	numberOfReadsInFileOne = 0;
	numberOfReadsInFileTwo = 0;

	forwardMappings = NULL;
	numberOfForwardMappings = 0;
	/** Storage for the reverse mappings.*/
	reverseMappings = NULL;
	numberOfReverseMappings = 0;
} // SolidMatepairsAnalyzer::SolidMatepairsAnalyzer


/** Destructor.*/
SolidMatepairsAnalyzer::~SolidMatepairsAnalyzer() {
  guint32 i;
  if (splitOutputFiles!=NULL) {
		free(splitOutputFiles);
	}
	if (splitOutputFilesBuffers!=NULL) {
    for (i=0; i<numberOfParts; i++) {
      free(splitOutputFilesBuffers[i]);
    }
		free(splitOutputFilesBuffers);
	}
	if (splitOutputFilesBufferSize!=NULL) {
		free(splitOutputFilesBufferSize);
	}
  
  if (consistentOutputFiles!=NULL) {
		free(consistentOutputFiles);
	}
	if (consistentOutputFilesBuffers!=NULL) {
    for (i=0; i<numberOfChromosomes; i++) {
      free(consistentOutputFilesBuffers[i]);
    }
		free(consistentOutputFilesBuffers);
	}
	if (consistentOutputFilesBufferSize!=NULL) {
		free(consistentOutputFilesBufferSize);
	}

	if (forwardMappings != NULL) {
		free(forwardMappings);
	}
	if (reverseMappings != NULL) {
		free(reverseMappings);
	}
	
  g_hash_table_destroy(mappingsHash);
} // SolidMatepairsAnalyzer::~SolidMatepairsAnalyzer

int SolidMatepairsAnalyzer::parseParams(int argc, char* argv[]) {
  static struct option long_options[] = {
    {"forwardMappings", required_argument, 0, 'f'},
    {"reverseMappings", required_argument, 0, 'r'},
		{"inconsistentFileRoot", required_argument, 0, 'o'},
    {"consistentFileRoot", required_argument, 0, 'c'},
    {"numberOfChromosomes", required_argument, 0, 'n'},
    {"lowerBound", required_argument, 0, 'l'},
    {"upperBound", required_argument, 0, 'u'},
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

  strcpy(inputFileOne, "");
  strcpy(inputFileTwo, "");
  strcpy(outputFileRoot, "");
  strcpy(consistentMatepairsFile, "");
    
  lowerBound = 0;
  upperBound = 0;
  numberOfChromosomes = 0;
  
	while((opt=getopt_long(argc,argv,
                         "f:r:o:n:l:u:hc:", 
                         long_options, &option_index))!=-1) {
    switch(opt) {
    case 'f':
      strncpy(inputFileOne, optarg, MAX_FILE_NAME);
      break;
    case 'r':
      strncpy(inputFileTwo, optarg, MAX_FILE_NAME);
      break;
		case 'o':
      strncpy(outputFileRoot, optarg, MAX_FILE_NAME);
      break;
    case 'c':
      strncpy(consistentFileRoot, optarg, MAX_FILE_NAME);
      break;
    case 'n':
      numberOfChromosomes = strtoul(optarg, NULL, 10);
      xDEBUG(DEB_PARSE_PARAMS, fprintf(stderr, "number of chromosomes %d\n",
                                       numberOfChromosomes));
      break;
    case 'l':
      lowerBound = strtol(optarg, NULL, 10);
      xDEBUG(DEB_PARSE_PARAMS, fprintf(stderr, "lower bound %d\n",
                                       lowerBound));
      break;
    case 'u':
      upperBound = strtol(optarg, NULL, 10);
      xDEBUG(DEB_PARSE_PARAMS, fprintf(stderr, "upper bound %d\n",
                                       upperBound));
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
	if (!strcmp(inputFileOne, "")) {
		fprintf(stderr, "The forward mappings file was not specified.\n");
		return 1;
	}
	
	if (!strcmp(inputFileTwo, "")) {
		fprintf(stderr, "The reverse mappings file was not specified.\n");
		return 1;
	}


	if (!strcmp(outputFileRoot, "")) {
		fprintf(stderr, "The output file root for inconsistent matepairs was not specified.\n");
		return 1;
	}
	
  if (!strcmp(consistentFileRoot, "")) {
		fprintf(stderr, "The output file root for consistent mate pairs was not specified.\n");
		return 1;
	}
  
	if (numberOfChromosomes==0  || numberOfChromosomes>24) {
		fprintf(stderr, "The number of chromosomes should be an integer between 1 and 24.\n");
		return 1;	
	}
  
  if (lowerBound<=0) {
    fprintf(stderr, "The lower bound should be an integer greater than zero.\n");
    return 1;
  }
  
  if (upperBound<=0) {
    fprintf(stderr, "The upperBound bound should be an integer greater than zero.\n");
    return 1;
  }
	return 0;  
} // SolidMatepairsAnalyzer::parseParams

int SolidMatepairsAnalyzer::analyze() {
  int result = 0;
  BRLGenericUtils::printNow(stderr);
  // prepare output files
	result = prepareOutputFiles();
  if (!result) {
    BRLGenericUtils::printNow(stderr);
    // load up first file
    result = hashInputFileOne();
    if (!result ) {
      // traverse the second file and check for consistent matepairs
      traverseInputFileTwo();
    }
    // close the output files
    BRLGenericUtils::printNow(stderr);
    finalizeOutputFiles();
		reportStatistics(stderr);
	}
	BRLGenericUtils::printNow(stderr);
  return result;
} // SolidMatepairsAnalyzer::analyze


void SolidMatepairsAnalyzer::usage() {
  fprintf(stderr, 
"  PROGRAM DESCRIPTION:\n"
"  Check matepairs in deconvoluted SOLID mappings.\n"
"\n"
"COMMAND LINE ARGUMENTS:\n"
"  --forwardMappings        | -f   => file containing forward mappings\n"
"  --reverseMappings        | -r   => file containing reverse mappings\n"
"  --lowerBound             | -l   => lower bound for the insert size\n"
"  --upperBound             | -u   => upper bound for the insert size\n"
"  --inconsistentFileRoot   | -o   => output file root, containing inconsistent mappings\n"
"  --consistentFileRoot     | -c   => output file root, containing consistent mappings\n"
"  --matePairsFile          | -M   => file for the consistent matepairs\n"
"  --numberOfChromosomes    | -n   => number of chromosomes (max 24)\n"
"  --help                   | -h   => [optional flag] Output this usage info and exit\n"
  );
} // SolidMatepairsAnalyzer::usage


int SolidMatepairsAnalyzer::prepareOutputFiles() {
	char partOutputFileName[2*MAX_LINE_LENGTH+1];
	guint32 i, chrom1, chrom2;
	
  numberOfParts = numberOfChromosomes*(numberOfChromosomes+1)/2;
  
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
    if (splitOutputFilesBuffers[i]==NULL) {
      fprintf(stderr, "Could not allocate split output file buffer # %d.\n", i);
      return 1;
    }  
    splitOutputFilesBufferSize[i]=0;
  }
	
	for (i=0, chrom1=1; chrom1<=numberOfChromosomes; chrom1++) {
    for (chrom2=chrom1; chrom2 <= numberOfChromosomes; chrom2++) {
      sprintf(partOutputFileName, "%s.inconsistent.chromPair.%d.%d",
              outputFileRoot, chrom1, chrom2);
      splitOutputFiles[i] = fopen(partOutputFileName, "at");
      if (splitOutputFiles[i]==NULL) {
        fprintf(stderr, "could not open temporary file %s\n", partOutputFileName);
        return 1;
      }
      xDEBUG(DEB_OUTPUT_SETUP, fprintf(stderr, "opened file %d p=%p\n", i, splitOutputFiles[i]));
      i++;
    }
	}
  
  
  consistentOutputFiles = (FILE**) malloc(sizeof(FILE*)*numberOfChromosomes);
	if (consistentOutputFiles==NULL) {
		fprintf(stderr, "Could not allocate consistent output file handles.\n");
		return 1;
	}
	consistentOutputFilesBuffers = (char **) malloc(sizeof(char*)*numberOfChromosomes);
  if (consistentOutputFilesBuffers==NULL) {
		fprintf(stderr, "Could not allocate consistent output file buffers.\n");
		return 1;
	}
	consistentOutputFilesBufferSize = (guint32 *) malloc(sizeof(guint32)*numberOfChromosomes);
	if (consistentOutputFilesBufferSize==NULL) {
		fprintf(stderr, "Could not allocate consistent output file buffer sizes.\n");
		return 1;
	}
  for (i=0; i<numberOfChromosomes; i++) {
    consistentOutputFilesBuffers[i] = (char*) malloc(sizeof(char)*SPLIT_FILE_BUFFER_SIZE);
    if (consistentOutputFilesBuffers[i]==NULL) {
      fprintf(stderr, "Could not allocate consistent output file buffer # %d.\n", i);
      return 1;
    }  
    consistentOutputFilesBufferSize[i]=0;
  }
  
  for ( chrom1=1; chrom1<=numberOfChromosomes; chrom1++) {
      sprintf(partOutputFileName, "%s.consistent.chrom.%d",
              consistentFileRoot, chrom1);
      consistentOutputFiles[chrom1-1] = fopen(partOutputFileName, "at");
      if (consistentOutputFiles[chrom1-1]==NULL) {
        fprintf(stderr, "could not open temporary file %s\n", partOutputFileName);
        return 1;
      }
      xDEBUG(DEB_OUTPUT_SETUP, fprintf(stderr, "opened file %d p=%p\n", chrom1, splitOutputFiles[chrom1-1]));
	}
  
  
  
  return 0;
} // SolidMatepairsAnalyzer::prepareOutputFiles



/** Traverse the first input file and hash the mappings based on read id
 * @return 0 if success, 1 otherwise
 * */
int SolidMatepairsAnalyzer::hashInputFileOne() {
  FILE* tmpFilePtr;
  char *buffer;
  buffer=(char*)malloc(sizeof(char)*10*DEFAULT_BUFFER_SIZE);
  guint32 bufferPos;
  guint32 bufferSize = 10*DEFAULT_BUFFER_SIZE/2;
  guint maxLineSize;
  
  guint32 dataSize, transferSize;
  guint32 startingPos;
  guint32 bPos;
  char readId[MAX_LINE_LENGTH];
  char *readMappings = (char*)malloc(sizeof(char)*DEFAULT_BUFFER_SIZE/2);
  guint32 readLen;

	
	tmpFilePtr = fopen(inputFileOne, "rt");
  if (tmpFilePtr==NULL){
		fprintf(stderr, "could not open temporary file %s\n", inputFileOne);
    return 1;
	}
  bufferPos = 0;
	
  maxLineSize = 0;
  
	while (1) {
    // fill up array using a heap discipline
    xDEBUG(DEB_BUFFER_FREAD, fprintf(stderr, "about to read mappings of size %d at position %d\n",
                              bufferSize, bufferPos));
    transferSize = fread(&buffer[bufferPos], sizeof(char), bufferSize, tmpFilePtr);
    xDEBUG(DEB_BUFFER_FREAD, fprintf(stderr, "read %d elements\n", transferSize));
                              
    
    if (transferSize == 0) {
      if (bufferPos>0) {
        buffer[bufferPos]='\0';
        xDEBUG(DEB_BYTES,fprintf(stderr, "last line \n%s\n", &buffer[0]));
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


        guint lineSize=strlen(&buffer[startingPos]);
        if(lineSize<=1000) {
        // the current read has mappings
        // determine the index of the output file
        sscanf(&buffer[startingPos], "%s %s", readId, readMappings);
        xDEBUG(DEB_HASH_FILE_ONE,
               fprintf(stderr, "Read id %s mappings %s\n",
                  readId, readMappings));
        guint commaIdx=0;
        guint nCommas = 0; 	
        guint32 pos;
        for (commaIdx=0,pos=startingPos; commaIdx<lineSize; pos++,commaIdx++) {
           if (buffer[commaIdx]==',') {
             nCommas ++;
           }
        }
        readLen = strlen(readId);
        if (readLen<8) {
          fprintf(stderr, "Dubious read id %s\n", readId);
        } else {
         
        readId[readLen-3]='\0';
        xDEBUG(DEB_HASH_FILE_ONE,
               fprintf(stderr, "Truncated read id %s\n",
                  readId));
        char * label = (char*) malloc(sizeof(char)*(strlen(readId)+1));
        char * value = (char*) malloc(sizeof(char)*(strlen(readMappings)+1));
        if (label == NULL || value == NULL) {
          perror("");
          fprintf(stderr, "NULL label or value\n");
          return 1;
        }
        strcpy(label, readId);
        strcpy(value, readMappings);
				g_hash_table_insert(mappingsHash, label, value);
				numberOfReadsInFileOne += 1;
        // dump it there
        }
        }
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
  free(buffer);
  free(readMappings); 
  return 0;
} // SolidMatepairsAnalyzer::hashInputFileOne


/** Traverse the second input file and look for consistent matepairs
 * @return 0 if success, 1 otherwise
 * */
int SolidMatepairsAnalyzer::traverseInputFileTwo() {
  FILE* tmpFilePtr;
  char buffer[DEFAULT_BUFFER_SIZE];
  guint32 bufferPos;
  guint32 bufferSize = DEFAULT_BUFFER_SIZE/2;
  guint maxLineSize;
  
  guint32 dataSize, transferSize;
  guint32 startingPos;
  guint32 bPos;
  char readId[MAX_LINE_LENGTH];
  char readMappings[8192];
  guint32 readLen;
	char* mateMappings;
	
	tmpFilePtr = fopen(inputFileTwo, "rt");
  if (tmpFilePtr==NULL){
		fprintf(stderr, "could not open temporary file %s\n", inputFileTwo);
    return 1;
	}
  bufferPos = 0;
	
  maxLineSize = 0;
  
	while (1) {
    // fill up array using a heap discipline
    xDEBUG(DEB_BUFFER_FREAD, fprintf(stderr, "about to read mappings of size %d at position %d\n",
                              bufferSize, bufferPos));
    transferSize = fread(&buffer[bufferPos], sizeof(char), bufferSize, tmpFilePtr);
    xDEBUG(DEB_BUFFER_FREAD, fprintf(stderr, "read %d elements\n", transferSize));
                              
    
    if (transferSize == 0) {
      if (bufferPos>0) {
        buffer[bufferPos]='\0';
        xDEBUG(DEB_BUFFER_FREAD,fprintf(stderr, "last line \n%s\n", &buffer[0]));
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
        // the current read has mappings
        // determine the index of the output file
        sscanf(&buffer[startingPos], "%s %s", readId, readMappings);
        xDEBUG(DEB_HASH_FILE_ONE,
               fprintf(stderr, "Read id %s mappings %s\n",
                  readId, readMappings));

        readLen = strlen(readId);
        if (readLen<8) {
          fprintf(stderr, "Dubious read id %s\n", readId);
          return 1;
        }
        readId[readLen-3]='\0';
        xDEBUG(DEB_TRAVERSE_FILE_TWO,
               fprintf(stderr, "Truncated read id %s\n",
                  readId));
      
			
				mateMappings = (char*) g_hash_table_lookup  (mappingsHash, readId);
				numberOfReadsInFileTwo += 1;
				
				if (mateMappings == NULL) {
					xDEBUG(DEB_TRAVERSE_FILE_TWO, fprintf(stderr, "read %s doesn't have mate mappings \n", readId));
				} else {
					xDEBUG(DEB_TRAVERSE_FILE_TWO, fprintf(stderr, "going to investigate mappings for %s: |%s| %p vs |%s| %p\n",
																								readId, readMappings, readMappings,
																								mateMappings, mateMappings));
					lookForConsistentMatesMappings(readId, mateMappings, readMappings);
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
   
	return 0;
} // SolidMatepairsAnalyzer::traverseInputFileTwo


void SolidMatepairsAnalyzer::finalizeOutputFiles() {
	guint32 i;
  xDEBUG(DEB_CLEANUP, fprintf(stderr, "started closing files\n"));
  // TODO: also finish writing buffers to disk
	for (i=0; i<numberOfParts; i++) {
    if (splitOutputFilesBufferSize[i]>0) {
      fprintf(splitOutputFiles[i], "%s", splitOutputFilesBuffers[i]);
      splitOutputFilesBufferSize[i]=0;
    }
    xDEBUG(DEB_CLEANUP, fprintf(stderr, "about to close file %d %p\n", i, splitOutputFiles[i]));	
		fclose(splitOutputFiles[i]);
    xDEBUG(DEB_CLEANUP, fprintf(stderr, "closed file %d\n", i));	
	}
  
  for (i=0; i<numberOfChromosomes; i++) {
    xDEBUG(DEB_CLEANUP, fprintf(stderr, "about to close consistent output file %d %p\n", i, consistentOutputFiles[i]));	
		if (consistentOutputFilesBufferSize[i]>0) {
      fprintf(consistentOutputFiles[i], "%s", consistentOutputFilesBuffers[i]);
      consistentOutputFilesBufferSize[i]=0;
    }  
    fclose(consistentOutputFiles[i]);
    xDEBUG(DEB_CLEANUP, fprintf(stderr, "closed consistentOutputFiles file %d\n", i));	
	}
  
  xDEBUG(DEB_CLEANUP, fprintf(stderr, "finished closing files\n"));	  
} // SolidMatepairsAnalyzer::finalizeOutputFiles


/** Look for consistent matches
@param mappingOne mappings of the "forward" mate
@param mappingTwo mappings of the "reverse" mate
@return 0 if consistent mapping found, 1 otherwise
*/
int SolidMatepairsAnalyzer::lookForConsistentMatesMappings(char* readId, char* mappingOne, char* mappingTwo) {
	// determine number of mappings for each mate
	int result = 1;
	guint32 numberOfMappingsOne, numberOfMappingsTwo;
	guint32 idx, mappingsOneLen, mappingsTwoLen;
	
	mappingsOneLen = strlen(mappingOne);
	mappingsTwoLen = strlen(mappingTwo);
	
	for (idx=0, numberOfMappingsOne=1; idx<mappingsOneLen; idx++ ) {
		if (mappingOne[idx]==',') {
			numberOfMappingsOne+=1;
		}
	}
	for (idx=0, numberOfMappingsTwo=1; idx<mappingsTwoLen; idx++ ) {
		if (mappingTwo[idx]==',') {
			numberOfMappingsTwo+=1;
		}
	}
	
	xDEBUG(DEB_VALID_MATES, fprintf(stderr, "#Map1=%d #Map2=%d\n",
																	numberOfMappingsOne, numberOfMappingsTwo));

	if (numberOfMappingsTwo>1 && numberOfMappingsOne>1) {
		multipleMultipleMates += 1;
	} else {
		// make sure we have enough storage
		if (numberOfMappingsOne>numberOfForwardMappings) {
			forwardMappings = (SolidMapping*) realloc(forwardMappings, numberOfMappingsOne*sizeof(SolidMapping));
			if (forwardMappings == NULL) {
				fprintf(stderr, "could not reallocate forward mappings \n");
				return 1;
			} else {
				numberOfForwardMappings = numberOfMappingsOne;
			}
		}
		
		if (numberOfMappingsTwo>numberOfReverseMappings) {
			reverseMappings = (SolidMapping*) realloc(reverseMappings, numberOfMappingsTwo*sizeof(SolidMapping));
			if (reverseMappings == NULL) {
				fprintf(stderr, "could not reallocate reverse mappings \n");
				return 1;
			} else {
				numberOfReverseMappings = numberOfMappingsTwo;
			}
		}
		
		parseMappings(mappingOne, forwardMappings, numberOfMappingsOne);
		parseMappings(mappingTwo, reverseMappings, numberOfMappingsTwo);
		
		// check if we have a consistent mapping
		// if not, dump inconsistent mappings in UMA  (_U_niversal _M_atepair _A_nalysis) format
		int validMappingsFound = 0;
		guint32 idx1, idx2;
		guint32 distance;
		
		for (idx1=0; idx1<numberOfMappingsOne && !validMappingsFound; idx1++) {
			for (idx2=0; idx2 < numberOfMappingsTwo && !validMappingsFound; idx2 ++) {
				// check valid mate
				if (forwardMappings[idx1].chromosome == reverseMappings[idx2].chromosome &&
						forwardMappings[idx1].strand  == reverseMappings[idx2].strand) {
					if (forwardMappings[idx1].position < reverseMappings[idx2].position) {
						distance = reverseMappings[idx2].position - forwardMappings[idx1].position ;
					} else {
						distance =  - reverseMappings[idx2].position + forwardMappings[idx1].position ;
					}
					if (distance>=(guint32)lowerBound && distance<=(guint32)upperBound) {
						validMappingsFound = 1;
						xDEBUG(DEB_VALID_MATES, fprintf(stderr, "found valid mapping on chrom %d: %d-%d\n",
																						forwardMappings[idx1].chromosome,
																						forwardMappings[idx1].position,
																						reverseMappings[idx2].position));
						dumpValidMapping(readId, &forwardMappings[idx1], numberOfMappingsOne, &reverseMappings[idx2], numberOfMappingsTwo);
						if (numberOfMappingsOne==1 && numberOfMappingsTwo ==1) {
							consistentMatesUniqueUnique += 1;
						} else {
							consistentMatesUniqueMultiple += 1;
						}
					}
				}
				// inline this function; inlining lookForConsistentMatesMappings would be too cumbersome
			}
		}
		if (!validMappingsFound) {
			dumpInvalidMappings(readId, forwardMappings, numberOfMappingsOne, reverseMappings, numberOfMappingsTwo);
			if (numberOfMappingsOne==1 && numberOfMappingsTwo ==1) {
				inconsistentUniqueUniqueMates += 1;
			} else {
				inconsistentUniqueMultipleMates += 1;
			}
		}
	}

  return result;
} // SolidMatepairsAnalyzer::lookForConsistentMatesMappings


/** Report analysis statistics */
void SolidMatepairsAnalyzer::reportStatistics(FILE* outFile) {
	guint32 strandedMates = 0;
	
	fprintf(outFile, "Number of reads in file one: %d\n", numberOfReadsInFileOne);
	fprintf(outFile, "Number of reads in file two: %d\n", numberOfReadsInFileTwo);
	fprintf(outFile, "consistent matepairs with unique-unique mappings %d\n", consistentMatesUniqueUnique);
	fprintf(outFile, "consistent matepairs with unique-multiple mappings %d\n", consistentMatesUniqueMultiple);
	fprintf(outFile, "matepairs with multiple-multiple mappings %d\n", multipleMultipleMates);
	
	fprintf(outFile, "inconsistent matepairs with unique-unique mappings %d\n", inconsistentUniqueUniqueMates);
	fprintf(outFile, "inconsistent matepairs with unique-multiple mappings %d\n", inconsistentUniqueMultipleMates);
	strandedMates = numberOfReadsInFileOne + numberOfReadsInFileTwo - 2* (consistentMatesUniqueUnique+consistentMatesUniqueMultiple +
									  inconsistentUniqueUniqueMates + inconsistentUniqueMultipleMates + multipleMultipleMates);
	fprintf(outFile, "stranded mates %d\n", strandedMates);
} // SolidMatepairsAnalyzer::reportStatistics

/** Parse a set of SOLID mappings
*/
void SolidMatepairsAnalyzer::parseMappings(char* mappingString, SolidMapping* solidMappings, guint32 expectedNumberOfMappings) {
	
  guint32 idx, startIdx;
  guint32 mappingStringLen = strlen(mappingString);
  guint32 chromosome, position;
  guint32 strand, mismatches;
  guint32 mappingIdx = 0;
  
  for (startIdx=0; startIdx<mappingStringLen; ) {
    for (idx=startIdx+1; idx<mappingStringLen && mappingString[idx]!='_'; idx++);
    if (idx>=mappingStringLen) {
      fprintf(stderr, "malformed mapping string %s\n", mappingString);
      exit(1);
    }
    mappingString[idx]='\0';
    chromosome = strtoul(&mappingString[startIdx], NULL, 0);
    mappingString[idx]='\0';
    startIdx = idx+1;
    if (mappingString[startIdx]=='-') {
      strand = 1;
      startIdx += 1;
    } else {
      strand = 0;
    }
    for (idx=startIdx+1; idx<mappingStringLen && mappingString[idx]!='.'; idx++);
    if (idx>=mappingStringLen) {
      fprintf(stderr, "malformed mapping string %s\n", mappingString);
      exit(1);
    }
    mappingString[idx]='\0';
    position = strtoul(&mappingString[startIdx], NULL, 0);
    mappingString[idx]='\0';
    startIdx = idx+1;
    for (idx=startIdx+1; idx<mappingStringLen && mappingString[idx]!=','; idx++);
    if (idx<mappingStringLen) {
      mappingString[idx]='\0';
      mismatches = strtoul(&mappingString[startIdx], NULL, 10);
      mappingString[idx]=',';
    } else {
      mismatches = strtoul(&mappingString[startIdx], NULL, 10);
    }
    xDEBUG(DEB_PARSE_MAPPINGS, fprintf(stderr, "c %d strand %c pos %d mis %d\n", chromosome, strand==0 ? '+':'-', position, mismatches));
    startIdx = idx+1;
		if (chromosome<25) {
			solidMappings[mappingIdx].chromosome = chromosome;
			solidMappings[mappingIdx].position = position;
			solidMappings[mappingIdx].strand = strand;
			solidMappings[mappingIdx].mismatches = mismatches;
			mappingIdx += 1;
		}
  }
  /*if (mappingIdx != expectedNumberOfMappings) {
    fprintf(stderr, "expected %d mappings, got %d\n", expectedNumberOfMappings, mappingIdx);
    exit(1);
  }
	*/
} // SolidMatepairsAnalyzer::parseMappings

/** Dump invalid mappings in the UMA format
 * @param forwardMappings array containing the forward mappings
 * @param reverseMappings array containing the reverse mappings
 * @param numberOfMappingsOne number of forward mappings
 * @param numberOfMappingsOne number of reverse mappings
 */
void SolidMatepairsAnalyzer::dumpInvalidMappings(char* readId, 
                                      SolidMapping* forwardMappings, guint32 numberOfMappingsOne,
				      SolidMapping* reverseMappings, guint32 numberOfMappingsTwo) {
  
  if (numberOfMappingsOne>50 || numberOfMappingsTwo>50) {
    return;
  }
  MateMappingStatus directStatus, reverseStatus;
  if (numberOfMappingsOne==1) {
    if (numberOfMappingsTwo==1) {
      directStatus = UniqueUniqueMateStatus;
      reverseStatus = UniqueUniqueMateStatus;
    } else {
      directStatus = UniqueMultipleMateStatus;
      reverseStatus = MultipleUniqueMateStatus;
    }
  } else {
    if (numberOfMappingsTwo==1) {
      directStatus = MultipleUniqueMateStatus;
      reverseStatus = UniqueMultipleMateStatus;
    } else {
      directStatus = MultipleMultipleMateStatus;
      reverseStatus = MultipleMultipleMateStatus;
    }
  }
  
  guint32 idx1, idx2;
  guint32 inconsistentMatePairOutputIndex;
  guint32 chrom1, position1, chrom2, position2;
  
  for (idx1 = 0; idx1<numberOfMappingsOne ; idx1++)  {
    chrom1 = forwardMappings[idx1].chromosome;
		if (chrom1>24) {
			continue;
		}
    position1 = forwardMappings[idx1].position;
    for (idx2 =0; idx2<numberOfMappingsTwo; idx2++) {
      chrom2 = reverseMappings[idx2].chromosome;
			 if (chrom2>24) {
				continue;
			}
		  position2 = reverseMappings[idx2].position;
      if (chrom1 < chrom2 || (chrom1==chrom2 && position1 < position2)) {
        inconsistentMatePairOutputIndex = (2*numberOfChromosomes-chrom1+2)*(chrom1-1)/2 + (chrom2-chrom1);
        
        xDEBUG(DEB_DUMP_INVALID_MAPPINGS, fprintf(stderr, "dim (%d,%d,%c,%d) - (%d,%d,%c,%d) to dimIdx %d\n",
                                  chrom1, position1, forwardMappings[idx1].strand==0 ? '+':'-', forwardMappings[idx1].mismatches,
                                  chrom2, position2, reverseMappings[idx2].strand==0 ? '+':'-', reverseMappings[idx2].mismatches,
                                  inconsistentMatePairOutputIndex));


        sprintf(&splitOutputFilesBuffers[inconsistentMatePairOutputIndex][splitOutputFilesBufferSize[inconsistentMatePairOutputIndex]],
                "%d\t%d\t%c\t%d\t%d\t%d\t%c\t%d\t%d\t%s\n",
                chrom1, position1, forwardMappings[idx1].strand==0 ? '+':'-', forwardMappings[idx1].mismatches,
                chrom2, position2, reverseMappings[idx2].strand==0 ? '+':'-', reverseMappings[idx2].mismatches,
                directStatus, readId);
      } else {
        inconsistentMatePairOutputIndex = (2*numberOfChromosomes-chrom2+2)*(chrom2-1)/2 + (chrom1-chrom2);;
        
        xDEBUG(DEB_DUMP_INVALID_MAPPINGS, fprintf(stderr, "dim (%d,%d,%c,%d) - (%d,%d,%c,%d) to dimIdx %d\n",
                                  chrom2, position2, reverseMappings[idx2].strand==0 ? '+':'-', reverseMappings[idx2].mismatches,
                                  chrom1, position1, forwardMappings[idx1].strand==0 ? '+':'-', forwardMappings[idx1].mismatches,
                                  inconsistentMatePairOutputIndex));

        sprintf(&splitOutputFilesBuffers[inconsistentMatePairOutputIndex][splitOutputFilesBufferSize[inconsistentMatePairOutputIndex]],
                "%d\t%d\t%c\t%d\t%d\t%d\t%c\t%d\t%d\t%s\n",
                chrom2, position2, reverseMappings[idx2].strand==0 ? '+':'-', reverseMappings[idx2].mismatches,
                chrom1, position1, forwardMappings[idx1].strand==0 ? '+':'-', forwardMappings[idx1].mismatches,
                reverseStatus, readId);
      }
      splitOutputFilesBufferSize[inconsistentMatePairOutputIndex] = strlen(splitOutputFilesBuffers[inconsistentMatePairOutputIndex]);
      if (splitOutputFilesBufferSize[inconsistentMatePairOutputIndex] >= SPLIT_FILE_BUFFER_SIZE/2) {
          fprintf(splitOutputFiles[inconsistentMatePairOutputIndex], "%s", splitOutputFilesBuffers[inconsistentMatePairOutputIndex]);
          splitOutputFilesBufferSize[inconsistentMatePairOutputIndex]=0;
      }
    }
  }
	
} // SolidMatepairsAnalyzer::dumpInvalidMappings

/** Dump valid mappings in the UMA format
 * @param forwardMappings array containing the forward mappings
 * @param reverseMappings array containing the reverse mappings
 * @param numberOfMappingsOne number of forward mappings
 * @param numberOfMappingsOne number of reverse mappings
*/
void SolidMatepairsAnalyzer::dumpValidMapping(char* readId, 
                                        SolidMapping* forwardMapping, guint32 numberOfMappingsOne,
					SolidMapping* reverseMapping, guint32 numberOfMappingsTwo) {
  MateMappingStatus directStatus, reverseStatus;
  if (numberOfMappingsOne==1) {
    if (numberOfMappingsTwo==1) {
      directStatus = UniqueUniqueMateStatus;
      reverseStatus = UniqueUniqueMateStatus;
    } else {
      directStatus = UniqueMultipleMateStatus;
      reverseStatus = MultipleUniqueMateStatus;
    }
  } else {
    if (numberOfMappingsTwo==1) {
      directStatus = MultipleUniqueMateStatus;
      reverseStatus = UniqueMultipleMateStatus;
    } else {
      directStatus = MultipleMultipleMateStatus;
      reverseStatus = MultipleMultipleMateStatus;
    }
  }

  guint32 consistentMatePairOutputIndex;
  guint32 chrom1, position1, chrom2, position2;
  
  chrom1 = forwardMapping->chromosome;
  position1 = forwardMapping->position;
  chrom2 = reverseMapping->chromosome;
  position2 = reverseMapping->position;
  consistentMatePairOutputIndex = chrom1-1;
  if (position1 < position2) {
    xDEBUG(DEB_DUMP_VALID_MAPPINGS, fprintf(stderr, "dim (%d,%d,%c,%d) - (%d,%d,%c,%d) to dimIdx %d\n",
                              chrom1, position1, forwardMapping->strand==0 ? '+':'-', forwardMapping->mismatches,
                              chrom2, position2, reverseMapping->strand==0 ? '+':'-', reverseMapping->mismatches,
                              consistentMatePairOutputIndex));

    sprintf(&consistentOutputFilesBuffers[consistentMatePairOutputIndex][consistentOutputFilesBufferSize[consistentMatePairOutputIndex]],
            "%d\t%d\t%c\t%d\t%d\t%d\t%c\t%d\t%d\t%s\n",
            chrom1, position1, forwardMappings->strand==0 ? '+':'-', forwardMapping->mismatches,
            chrom2, position2, reverseMappings->strand==0 ? '+':'-', reverseMapping->mismatches,
            directStatus, readId);
  } else {
    xDEBUG(DEB_DUMP_INVALID_MAPPINGS, fprintf(stderr, "dim (%d,%d,%c,%d) - (%d,%d,%c,%d) to dimIdx %d\n",
                              chrom2, position2, reverseMapping->strand==0 ? '+':'-', reverseMappings->mismatches,
                              chrom1, position1, forwardMapping->strand==0 ? '+':'-', forwardMappings->mismatches,
                              consistentMatePairOutputIndex));

    sprintf(&consistentOutputFilesBuffers[consistentMatePairOutputIndex][consistentOutputFilesBufferSize[consistentMatePairOutputIndex]],
            "%d\t%d\t%c\t%d\t%d\t%d\t%c\t%d\t%d\t%s\n",
            chrom2, position2, reverseMapping->strand==0 ? '+':'-', reverseMapping->mismatches,
            chrom1, position1, forwardMapping->strand==0 ? '+':'-', forwardMapping->mismatches,
            reverseStatus, readId);
  }
  consistentOutputFilesBufferSize[consistentMatePairOutputIndex] = strlen(consistentOutputFilesBuffers[consistentMatePairOutputIndex]);
  if (consistentOutputFilesBufferSize[consistentMatePairOutputIndex] >= SPLIT_FILE_BUFFER_SIZE/2) {
      fprintf(consistentOutputFiles[consistentMatePairOutputIndex], "%s", consistentOutputFilesBuffers[consistentMatePairOutputIndex]);
      consistentOutputFilesBufferSize[consistentMatePairOutputIndex]=0;
  }
    
} // SolidMatepairsAnalyzer::dumpValidMappings

