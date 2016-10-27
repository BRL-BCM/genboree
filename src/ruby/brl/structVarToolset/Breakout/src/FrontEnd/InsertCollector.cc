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
#include "InsertCollector.h"
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
#define DEB_SPLIT_INPUT 0
#define DEB_CHROM_NUMBER 0

#define SPLIT_FILE_BUFFER_SIZE 8*1024

void destroyGintSlice(gpointer data) {
	g_slice_free(gint, data);
}


/** Constructor.*/
InsertCollector::InsertCollector() {
  strcpy(inputFileOne, "");
  strcpy(inputFileTwo, "");
  strcpy(outputFile, "");
  outputFilePtr = NULL;
  mappingsHash = g_hash_table_new(g_str_hash, g_str_equal);
	insertSizeHash = g_hash_table_new_full(g_int_hash, g_int_equal, destroyGintSlice, NULL);
	chromosomeNameToNumberHash= g_hash_table_new(g_str_hash, g_str_equal);
	forwardMappings = NULL;
	numberOfForwardMappings = 0;
	/** Storage for the reverse mappings.*/
	reverseMappings = NULL;
	numberOfReverseMappings = 0;
	nextChromNumber = 1;
	maximumInsertSize = 100000;
} // InsertCollector::InsertCollector

/** Destructor.*/
InsertCollector::~InsertCollector() {
	if (forwardMappings != NULL) {
		free(forwardMappings);
	}
	if (reverseMappings != NULL) {
		free(reverseMappings);
	}
	
  g_hash_table_destroy(mappingsHash);
	g_hash_table_destroy(insertSizeHash);	
} // InsertCollector::~InsertCollector

int InsertCollector::parseParams(int argc, char* argv[]) {
  static struct option long_options[] = {
    {"forwardMappings", required_argument, 0, 'f'},
    {"reverseMappings", required_argument, 0, 'r'},
		{"histogramFile",   required_argument, 0, 'o'},
    {"maxInsertSize", 	required_argument, 0, 'M'},
    {"forwardSuffix", 	required_argument, 0, 'F'},
    {"reverseSuffix", 	required_argument, 0, 'R'},
		{"relativeStrand", 	required_argument, 0, 'S'},
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

  strcpy(inputFileOne, "");
  strcpy(inputFileTwo, "");
  strcpy(outputFile, "");
	maximumInsertSize = 100000;
  strcpy(forwardReadSuffix, "");
	strcpy(reverseReadSuffix, "");
	relativeStrand = 0;
	
	while((opt=getopt_long(argc,argv,
                         "f:r:o:M:hc:F:R:S:T:", 
                         long_options, &option_index))!=-1) {
    switch(opt) {
    case 'f':
      strncpy(inputFileOne, optarg, MAX_FILE_NAME);
      break;
    case 'r':
      strncpy(inputFileTwo, optarg, MAX_FILE_NAME);
      break;
		case 'o':
      strncpy(outputFile, optarg, MAX_FILE_NAME);
      break;
    case 'M':
      maximumInsertSize= strtol(optarg, NULL, 10);
      xDEBUG(DEB_PARSE_PARAMS, fprintf(stderr, "maximum insert size %d\n",
                                       maximumInsertSize));
      break;
		case 'F':
			strcpy(forwardReadSuffix, optarg);
			break;
		case 'R':
			strcpy(reverseReadSuffix, optarg);
			break;
		case 'S':
			if (!strcasecmp(optarg, "same")) {
				relativeStrand = 0;
			} else {
				relativeStrand = 1;
			}
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
	if (!strcmp(inputFileOne, "")) {
		fprintf(stderr, "The forward mappings file was not specified.\n");
		return 1;
	}
	
	if (!strcmp(inputFileTwo, "")) {
		fprintf(stderr, "The reverse mappings file was not specified.\n");
		return 1;
	}


	if (!strcmp(outputFile, "")) {
		fprintf(stderr, "The output histogram file was not specified.\n");
		return 1;
	}
	
	
	if (strlen(forwardReadSuffix) != strlen(reverseReadSuffix)) {
		fprintf(stderr, "The reverse and forward read suffix have different lengths \n");
		return 1;
	}
	suffixLength = strlen(forwardReadSuffix);
  if (maximumInsertSize<=0) {
    fprintf(stderr, "The maximum insert size should be an integer greater than zero.\n");
    return 1;
  }
	return 0;  
} // InsertCollector::parseParams

int InsertCollector::collectInserts() {
  int result = 0;
  BRLGenericUtils::printNow(stderr);
  // prepare output files
	result = prepareOutputFile();
  if (result) {
		return result;
	}
	
  BRLGenericUtils::printNow(stderr);
  // load up first file
  result = hashInputFileOne();
  if (!result ) {
    // traverse the second file and check for consistent matepairs
    traverseInputFileTwo();
    // close the output files
    BRLGenericUtils::printNow(stderr);
    finalizeHistogram();
	}
	BRLGenericUtils::printNow(stderr);
  return result;
} // InsertCollector::analyze


void InsertCollector::usage() {
  fprintf(stderr, 
"  PROGRAM DESCRIPTION:\n"
"  Build an insert size histogram for matepairs mapping on the same chromosome.\n"
"\n"
"COMMAND LINE ARGUMENTS:\n"
"  --forwardMappings        | -f   => file containing forward mappings\n"
"  --reverseMappings        | -r   => file containing reverse mappings\n"
"  --histogramFile          | -o   => insert size histogram \n"
"  --maxInsertSize          | -M   => maximum insert size to consider (default 100,000)\n"
"  --histogramFile          | -o   => insert size histogram \n"
"  --inputFileType          | -T   => Input file type; accepted values are bed, sam, bam, pash \n"
"  --forwardSuffix          | -F   => Suffix of forward mate pairs ends \n"
"  --reverseSuffix          | -R   => Suffix of reverse mate pairs ends  \n"
"  --relativeStrand         | -S   => Relative strand orientation of matepairs: same, opposite  \n"
"  --help                   | -h   => [optional flag] Output this usage info and exit\n"
  );
} // InsertCollector::usage


int InsertCollector::prepareOutputFile() {
	outputFilePtr = fopen(outputFile, "wt");
	if (outputFilePtr==NULL) {
		fprintf(stderr, "could not open output file %s\n", outputFile);
		return 1;
	}
  
  return 0;
} // InsertCollector::prepareOutputFiles



/** Traverse the first input file and hash the mappings based on read id
 * @return 0 if success, 1 otherwise
 * */
int InsertCollector::hashInputFileOne() {
 FILE* tmpFilePtr;
  char buffer[DEFAULT_BUFFER_SIZE];
  guint32 bufferPos;
  guint32 bufferSize = DEFAULT_BUFFER_SIZE/2;
  guint maxLineSize;
  
  guint32 dataSize, transferSize;
  guint32 startingPos;
  guint32 bPos;
  char readName[MAX_LINE_LENGTH];
  char chromName[MAX_LINE_LENGTH];
  guint32 chromStart, chromStop;
	guint32 keepIndex;
	guint32 readStart, readStop;
  char cStrand;
	guint32 strand;
  
	tmpFilePtr = BRLGenericUtils::openTextGzipBzipFile(inputFileOne);
  if (tmpFilePtr==NULL){
		fprintf(stderr, "could not open temporary file %s\n", inputFileOne);
    return 1;
	}
  bufferPos = 0;
	keepIndex = 0;
	guint hashKey;
  strand = 0;
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
              chromStop = chromStart + 25;
              if (bamFlag & 0x0010) {
                strand = 1;
              } else {
                strand = 0;
              }
            }
            break;
          case BEDFile:
            sscanf(&buffer[startingPos], "%s %d %d %s %c", chromName, &chromStart, &chromStop, readName, &cStrand);
            if (cStrand =='+') {
							strand = 0; 
						} else {
							strand = 1;
						}
						break;
          case PashFile:
            sscanf(&buffer[startingPos], "%s %d %d %s %d %d %c",
                   chromName, &chromStart, &chromStop, readName, &readStart, &readStop, &cStrand);
            if (cStrand =='+') {
							strand = 0; 
						} else {
							strand = 1;
						}
						break;
          default:
            exit(0);
            break;
        }
				// process only forward reads
        if (strcmp(forwardReadSuffix, &readName[strlen(readName)-strlen(forwardReadSuffix)])) {
					skipFlag=1;
				}
				guint32 chromosomeIndex = getChromosomeNumber(chromName);
				if (chromosomeIndex>24) {
					skipFlag=1;
				}
        if (!skipFlag) {
          readName[strlen(readName)-suffixLength]='\0';
          xDEBUG(DEB_SPLIT_INPUT, fprintf(stderr, "Read %s hash %d index %d\n",
                                              readName, hashKey, keepIndex));
          IndividualMapping *readMapping=(IndividualMapping*)g_slice_alloc(sizeof(IndividualMapping));
					readMapping->chromosome = chromosomeIndex;
					readMapping->position = chromStart;
					readMapping->strand = strand;
					g_hash_table_insert(mappingsHash, g_strdup(readName), readMapping);
					xDEBUG(DEB_HASH_FILE_ONE, fprintf(stderr, "hashed %s %d %d %d\n",
																						readName, readMapping->chromosome,
																						readMapping->position, readMapping->strand));
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
} // InsertCollector::hashInputFileOne


/** Traverse the second input file and look for consistent matepairs
 * @return 0 if success, 1 otherwise
 * */
int InsertCollector::traverseInputFileTwo() {
	FILE* tmpFilePtr;
  char buffer[DEFAULT_BUFFER_SIZE];
  guint32 bufferPos;
  guint32 bufferSize = DEFAULT_BUFFER_SIZE/2;
  guint maxLineSize;
  
  guint32 dataSize, transferSize;
  guint32 startingPos;
  guint32 bPos;
  char readName[MAX_LINE_LENGTH];
  char chromName[MAX_LINE_LENGTH];
  guint32 chromStart, chromStop;
	guint32 keepIndex;
	guint32 readStart, readStop;
  guint32 strand=0;
	char cStrand;  
	tmpFilePtr = BRLGenericUtils::openTextGzipBzipFile(inputFileTwo);
  if (tmpFilePtr==NULL){
		fprintf(stderr, "could not open second file %s\n", inputFileTwo);
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
              chromStop = chromStart + 25;
              if (bamFlag & 0x0010) {
                strand = 1;
              } else {
                strand = 0;
              }
            }
            break;
          case BEDFile:
            sscanf(&buffer[startingPos], "%s %d %d %s %c", chromName, &chromStart, &chromStop, readName, &cStrand);
						if (cStrand =='+') {
							strand = 0; 
						} else {
							strand = 1;
						}
            break;
          case PashFile:
            sscanf(&buffer[startingPos], "%s %d %d %s %d %d %c",
                   chromName, &chromStart, &chromStop, readName, &readStart, &readStop, &cStrand);
            if (cStrand =='+') {
							strand = 0; 
						} else {
							strand = 1;
						}
						break;
          default:
            exit(0);
            break;
        }
				// process only forward reads
        if (strcmp(reverseReadSuffix, &readName[strlen(readName)-strlen(reverseReadSuffix)])) {
					skipFlag=1;
				}
				guint32 chromosomeIndex = getChromosomeNumber(chromName);
				if (chromosomeIndex>24) {
					skipFlag=1;
				}
				xDEBUG(DEB_SPLIT_INPUT, fprintf(stderr, "skipFlag %d chromIndex %d\n", skipFlag, chromosomeIndex));

        if (!skipFlag) {
          readName[strlen(readName)-suffixLength]='\0';
          xDEBUG(DEB_SPLIT_INPUT, fprintf(stderr, "Read %s hash %d index %d\n",
                                              readName, hashKey, keepIndex));
					
          IndividualMapping *readMapping=(IndividualMapping*)g_hash_table_lookup(mappingsHash, readName);
					if (readMapping !=NULL) {
						chromosomeIndex = getChromosomeNumber(chromName);
						guint32 position = chromStart;
						xDEBUG(DEB_TRAVERSE_FILE_TWO, fprintf(stderr, "reverse %s %d %d hashed %d %d %d\n",
							readName, chromosomeIndex, strand,
							readMapping->chromosome,
							readMapping->position, readMapping->strand));
						if (chromosomeIndex==readMapping->chromosome &&
								( (readMapping->strand==strand && !relativeStrand) ||
							  (readMapping->strand!=strand && relativeStrand) ))  {
							xDEBUG(DEB_TRAVERSE_FILE_TWO, fprintf(stderr, "candidate for insert size collection\n"));
							glong distance;
							if (position>readMapping->position) {
								distance = position-readMapping->position;
							} else {
								distance = readMapping->position-position;
							}
							xDEBUG(DEB_TRAVERSE_FILE_TWO, fprintf(stderr, "Distance: %ld\n", distance));
							if (distance<maximumInsertSize) {
								gint*keyPointer = (gint*)g_slice_alloc(sizeof(gint));
								*keyPointer = distance;
								glong count = (glong) g_hash_table_lookup(insertSizeHash, (gpointer)keyPointer);
								xDEBUG(DEB_TRAVERSE_FILE_TWO, fprintf(stderr, "count %ld\n", count));	
								if (count>0) {
									count +=1;
									xDEBUG(DEB_TRAVERSE_FILE_TWO, fprintf(stderr, "about to replace distance %ld %ld\n",
																										distance,
																										(glong) g_hash_table_lookup(insertSizeHash, (gpointer)keyPointer)));
									g_hash_table_replace(insertSizeHash, (gpointer)keyPointer, (gpointer)count);
									xDEBUG(DEB_TRAVERSE_FILE_TWO, fprintf(stderr, "replaced distance %ld %ld\n",
																										distance,
																										(glong) g_hash_table_lookup(insertSizeHash, (gpointer)keyPointer)));
								} else {
									count = 1;
									gint*keyPointer = (gint*)g_slice_alloc(sizeof(gint));
									*keyPointer = distance;
									g_hash_table_insert(insertSizeHash, (gpointer)keyPointer, (gpointer)count);
									xDEBUG(DEB_TRAVERSE_FILE_TWO, fprintf(stderr, "inserted distance %ld %d\n",
																										distance, 13));
																										// (gint) g_hash_table_lookup(insertSizeHash, (gpointer)keyPointer);
								}
							} 
						}
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
  
	return 0;
} // InsertCollector::traverseInputFileTwo


void traverseFunction(gpointer key, gpointer value, gpointer info) {
	FILE * outputFilePtr = (FILE*) info;
	fprintf(outputFilePtr, "%d\t%ld\n",  *((gint*) key), (glong) value);
}


/** Report the insert size histogram. */
void InsertCollector::finalizeHistogram() {
	//
	g_hash_table_foreach(insertSizeHash, traverseFunction, outputFilePtr);
	fclose(outputFilePtr);
} // InsertCollector::finalizeHistogram


/** Convert a chromosome name to a number */
gulong InsertCollector::getChromosomeNumber(char* chromosomeName) {
	gulong chromosomeNumber=(gulong)g_hash_table_lookup(chromosomeNameToNumberHash, chromosomeName);
	if (chromosomeNumber==0) {
		xDEBUG(DEB_CHROM_NUMBER, fprintf(stderr, "New chromosome number : %s %ld\n", chromosomeName, nextChromNumber));
		g_hash_table_insert(chromosomeNameToNumberHash, g_strdup(chromosomeName), (gpointer)nextChromNumber);
		chromosomeNumber = nextChromNumber;
		nextChromNumber += 1;
	}
	return chromosomeNumber;
}
