#include "optimizedGB.h"
#include "optimizedFunctions.h"
#include "zlib.h"
#define CHUNK 1000000
static char **hdhvQueries = NULL;
static highDensFtypes defaultHighDensData;
static coordinates staticStoreCoord;
static int isHDHVFdataQueryInitialized = 0;
static int isStaticBufferInitialized = 0;
static char *staticBuffer = NULL;
static gulong offsetStaticBuffer = 0;
static gulong limitOfStaticBuffer = 0;
static int currentFD = 0;
static int decompressedBlockSize = 16000000;
static char *decompressedBlock = NULL;
static int decompressedBlockInitialized = 0;
static long staticBufferSize = 16000000;
static int sizeOfElementsUsedToGetMaxNumElements = (int)sizeof(gdouble);
static long maxNumberOfElementsToProcess = 0;
static int hasHighDensityTracks = 0;
static char *fullPathToFile;
static gdouble *bufferToReadDoubles = NULL;
static int isBufferToReadDoublesInitialized = 0;
static int isFullPathToFileSet = 0;
static int isBufferToReadCharsInitialized = 0;
static char *bufferToReadChars = NULL;
static GHashTable *gbTrackVarsHash = NULL;
static int isGbTrackVarsHashInitialized = 0;
static GHashTable *gbTrackRecordTypesHash = NULL;
static int isGbTrackRecordTypesHashInitialized = 0;
static GHashTable *fileId2FileNameHash = NULL;
static GHashTable *fileName2fileIdHash = NULL;
static GHashTable *fileName2FileSizeHash = NULL;
static GHashTable *fids2BlockLevelDataInfoHash = NULL;
static GHashTable *fileName2fileWithFullNameHash = NULL;
static GHashTable *fileToFileHandlerHash = NULL;        //contains "the fileName with path as a sha1" and the file handler
static int isFileToFileHandlerHashInitialized = 0;
static int fileName2fileWithFullNameHashHasBeenInitialized = 0;
static int fileId2FileNameHashInitialized = 0;
static int fids2BlockLevelDataInfoHashInitialized = 0;
static int numberOfBlocksToProcessGlobal = 10000;
static long long startPositionGlobalForHDTrack = 0;
static long long endPositionGlobalForHDTrack = 0;
static int canvasWidthGlobalForHDTrack = 0;
static double universalScaleGlobalForHDTrack = 0.0;
static gdouble basesPerPixelGlobalForHDTrack = 0;
static long lengthOfSegmentGlobalForHDTrack = 0;
static guint64 largest64Value = G_GUINT64_CONSTANT(18410152326737166336);
static guint32 largest32Value = (guint32) 4290772992;
gdouble bpPerPixel;
gdouble valueToUseAsMinScore;
gdouble valueToUseAsMaxScore;
gdouble *tempPixelArray;
gdouble *tempExtraValues;
gdouble *tempNegPixelArray;
gdouble yInt;
int annoEnd;
char *partitioningReq;
static char *gbTrackRecordTypes[] = {
  "doubleScore",
  "floatScore",
  "int8Score",
  "int32Score",
  "int16Score",
  "coordInt8Score",
  ""
};

static char *gbTrackVars[] = {
  "gbTrackWindowingMethod",           /* AVG, MAX or MIN */
  "gbTrackRecordType",                /* doubleScore, floatScore, int8Score, int32Score, int16Score,coordInt8Score */
  "gbTrackFileName",                  /* name of bin file */
  "gbTrackDataSpan",                  /* how many bytes per basepair */
  "gbTrackBpSpan",                    /* how many basepairs per byte */
  "gbTrackBpStep",                    /* how many bp between interval */
  "gbTrackDataMax",                   /* max value global for the entire track */
  "gbTrackDataMin",                   /* min value global for the entire track */
  "gbTrackUseLog",                    /* logaritmic scale true/false */
  "gbTrackFormula",                   /* name of function score = lowerLimit + (scale * ((double)byte/denom)) ; ignore >denom */
  "gbTrackScale",                     /* scale in formula */
  "gbTrackLowLimit",                  /* low limit in formula */
  "gbTrackDenominator",               /* denom in formula */
  "gbTrackHasNullRecords",            /* a flag if the track has null records */
  "gbTrackPxHeight",                  /* a value that control the height of the track */
  "gbTrackUserMax",                   /* a value that control the user's max value */
  "gbTrackUserMin",                   /* a value that control the user's min value */
  "gbTrackPxScoreUpperThreshold",
  "gbTrackPxScoreLowerThreshold",
  "gbTrackPxScoreUpperThresholdColor",
  "gbTrackPxScoreLowerThresholdColor",
  "gbTrackPxScoreUpperNegativeThreshold",
  "gbTrackPxScoreLowerNegativeThreshold",
  "gbTrackPxScoreUpperNegativeThresholdColor",
  "gbTrackPxScoreLowerNegativeThresholdColor",
  "gbTrackNegativeColor",
  "gbTrackYIntercept",
  "gbTrackPartitioning",
  "gbTrackZeroDraw",
  ""
};

// This method delete the static buffers
//[+returns+] no return value
void deleteBuffers(void)
{
  if(isBufferToReadDoublesInitialized == 1)
  {
      free(bufferToReadDoubles);
      bufferToReadDoubles = NULL;
      isBufferToReadDoublesInitialized = 0;
  }

  if(isFullPathToFileSet == 1)
  {
      free(fullPathToFile);
      fullPathToFile = NULL;
  }

  destroyBufferToReadChars();

  if(isStaticBufferInitialized == 1)
  {
      free(staticBuffer);
      staticBuffer = NULL;
      isStaticBufferInitialized = 0;
  }
}

// This method sets the value for the defaultHigh density data, the information is 
//[+highDensFtypes *hdhvTrack+] a pointer to the highDensity track object
//[+returns+] no return value
void setDefaultHighDensData(highDensFtypes * hdhvTrack)
{
  defaultHighDensData.gbTrackWindowingMethod = hdhvTrack->gbTrackWindowingMethod;
  defaultHighDensData.gbTrackRecordType = hdhvTrack->gbTrackRecordType;
  defaultHighDensData.fileName = hdhvTrack->fileName;
  defaultHighDensData.gbTrackDataSpan = hdhvTrack->gbTrackDataSpan;
  defaultHighDensData.bpSpan = hdhvTrack->bpSpan;
  defaultHighDensData.bpStep = hdhvTrack->bpStep;
  defaultHighDensData.gbTrackDataMax = hdhvTrack->gbTrackDataMax;
  defaultHighDensData.gbTrackDataMin = hdhvTrack->gbTrackDataMin;
  defaultHighDensData.gbTrackUseLog = hdhvTrack->gbTrackUseLog;
  defaultHighDensData.gbTrackHasNullRecords = hdhvTrack->gbTrackHasNullRecords;
  defaultHighDensData.gbTrackFormula = hdhvTrack->gbTrackFormula;
  defaultHighDensData.scale = hdhvTrack->scale;
  defaultHighDensData.lowLimit = hdhvTrack->lowLimit;
  defaultHighDensData.gbTrackDenominator = hdhvTrack->gbTrackDenominator;
  defaultHighDensData.offset = hdhvTrack->offset;
  defaultHighDensData.numRecords = hdhvTrack->numRecords;
  defaultHighDensData.annotationFid = hdhvTrack->annotationFid;
  defaultHighDensData.annotationStart = hdhvTrack->annotationStart;
  defaultHighDensData.annotationEnd = hdhvTrack->annotationEnd;
  defaultHighDensData.gbTrackPxHeight = hdhvTrack->gbTrackPxHeight;
  defaultHighDensData.gbTrackUserMax = hdhvTrack->gbTrackUserMax;
  defaultHighDensData.gbTrackUserMin = hdhvTrack->gbTrackUserMin;
  defaultHighDensData.byteLength = hdhvTrack->byteLength;
  defaultHighDensData.gbTrackPxScoreUpperThreshold = hdhvTrack->gbTrackPxScoreUpperThreshold;
  defaultHighDensData.gbTrackPxScoreLowerThreshold = hdhvTrack->gbTrackPxScoreLowerThreshold;
  defaultHighDensData.gbTrackPxScoreUpperThresholdColor = hdhvTrack->gbTrackPxScoreUpperThresholdColor;
  defaultHighDensData.gbTrackPxScoreLowerThresholdColor = hdhvTrack->gbTrackPxScoreLowerThresholdColor;
  defaultHighDensData.gbTrackPxScoreUpperNegativeThreshold = hdhvTrack->gbTrackPxScoreUpperNegativeThreshold;
  defaultHighDensData.gbTrackPxScoreLowerNegativeThreshold = hdhvTrack->gbTrackPxScoreLowerNegativeThreshold;
  defaultHighDensData.gbTrackPxScoreUpperNegativeThresholdColor = hdhvTrack->gbTrackPxScoreUpperNegativeThresholdColor;
  defaultHighDensData.gbTrackPxScoreLowerNegativeThresholdColor = hdhvTrack->gbTrackPxScoreLowerNegativeThresholdColor;
  defaultHighDensData.gbTrackNegativeColor = hdhvTrack->gbTrackNegativeColor;
  defaultHighDensData.gbTrackYIntercept = hdhvTrack->gbTrackYIntercept;
  defaultHighDensData.gbTrackPartitioning = hdhvTrack->gbTrackPartitioning;
  defaultHighDensData.gbTrackZeroDraw = hdhvTrack->gbTrackZeroDraw ;
  return;
}

// This method return the the instatement for regular tracks (no high density) from a database
//[+int databaseToUse+] the index of the database to use (start in 0)
//[+returns+] string with the in statement for example (1,2,3)
char *getInStatementForRegularTracks(int databaseToUse)
{
  GHashTable *myTypeIdHash = getTypeIdHash();
  void *theKey;
  int ii = 0;
  int databaseId = 0;
  char temporaryString[55555] = "(";
  int myFeatureId = 0;
  int visibility = 0;
  GList *listOfTypeIds;
  int *tempFeatureId = 0;
  int *highDensityTracks = NULL;
  int numberOfhighDensityTracks = 0;
  int isHighDensityTrack = 0;
  int aa = 0;

  highDensityTracks = getTrackIdsForHighDensityTracks(databaseToUse, &numberOfhighDensityTracks);

  if(g_hash_table_size(myTypeIdHash) < 1)
  {
    fprintf(stderr, "Database %s appears to be empty\n", getDatabaseFromId(databaseToUse));
    fflush(stderr);
    if(highDensityTracks != NULL)
    {
      free(highDensityTracks);
      highDensityTracks = NULL;
    }
    return NULL;
  }
  listOfTypeIds = g_hash_table_get_keys(myTypeIdHash);
  ii = 0;
  while (listOfTypeIds)
  {
    isHighDensityTrack = 0;
    theKey = (char *)listOfTypeIds->data;
    databaseId = extractDatabaseId((char *)theKey);
    if(databaseId != databaseToUse)
    {
        listOfTypeIds = g_list_next(listOfTypeIds);
        continue;
    }
    tempFeatureId = g_hash_table_lookup(myTypeIdHash, theKey);
    myFeatureId = *tempFeatureId;
    visibility = getVisibilityFromTypeId(databaseToUse, myFeatureId);
    if(visibility == VIS_HIDE)
    {
        myFeatureId = 0;
    }

    if(myFeatureId > 0)
    {
        isHighDensityTrack = 0;
        for (aa = 0; aa < numberOfhighDensityTracks; aa++)
        {
            if(highDensityTracks == NULL)
            {
                isHighDensityTrack = 0;
            }
            else if(myFeatureId == highDensityTracks[aa])
            {
                isHighDensityTrack = 1;
                break;
            }
        }
    }

    if(myFeatureId > 0 && isHighDensityTrack == 0)
    {
        if(ii > 0)
        {
            strcat(temporaryString, ", ");
        }
        sprintf(temporaryString, "%s %d", temporaryString, myFeatureId);
        ii++;
    }

    listOfTypeIds = g_list_next(listOfTypeIds);
  }

  if(strlen(temporaryString) > 1)
  {
    strcat(temporaryString, ")");
    if(highDensityTracks != NULL)
    {
        free(highDensityTracks);
        highDensityTracks = NULL;
    }
    return strdup(temporaryString);
  }
  else
  {
    if(highDensityTracks != NULL)
    {
        free(highDensityTracks);
        highDensityTracks = NULL;
    }
    return NULL;
  }

}

// This method return the the instatement for high density tracks from a database
//[+int databaseToUse+] the index of the database to use (start in 0)
//[+returns+] string with the in statement for example (1,2,3)
char *getInStatementForHighDensityTracks(int databaseToUse)
{
  GHashTable *myTypeIdHash = getTypeIdHash();
  void *theKey;
  int ii = 0;
  int databaseId = 0;
  char temporaryString[55555] = "(";
  int myFeatureId = 0;
  int visibility = 0;
  GList *listOfTypeIds;
  int *tempFeatureId = 0;
  int *highDensityTracks = NULL;
  int numberOfhighDensityTracks = 0;
  int isHighDensityTrack = 0;
  int aa = 0;

  highDensityTracks = getTrackIdsForHighDensityTracks(databaseToUse, &numberOfhighDensityTracks);

  if(highDensityTracks == NULL)
  {
      return NULL;
  }

  if(g_hash_table_size(myTypeIdHash) < 1)
  {
      fprintf(stderr, "Database %s appears to be empty\n", getDatabaseFromId(databaseToUse));
      fflush(stderr);
      return NULL;
  }
  listOfTypeIds = g_hash_table_get_keys(myTypeIdHash);
  ii = 0;
  while (listOfTypeIds)
  {
      isHighDensityTrack = 0;
      theKey = (char *)listOfTypeIds->data;
      databaseId = extractDatabaseId((char *)theKey);
      if(databaseId != databaseToUse)
      {
          listOfTypeIds = g_list_next(listOfTypeIds);
          continue;
      }
      tempFeatureId = g_hash_table_lookup(myTypeIdHash, theKey);
      myFeatureId = *tempFeatureId;
      visibility = getVisibilityFromTypeId(databaseToUse, myFeatureId);
      if(visibility == VIS_HIDE)
        myFeatureId = 0;

      if(myFeatureId > 0)
      {
          for (aa = 0; aa < numberOfhighDensityTracks; aa++)
          {
              if(myFeatureId == highDensityTracks[aa])
              {
                  isHighDensityTrack = 1;
                  break;
              }
          }
      }

      if(myFeatureId > 0 && isHighDensityTrack == 1)
      {
          if(ii > 0)
            strcat(temporaryString, ", ");
          sprintf(temporaryString, "%s %d", temporaryString, myFeatureId);
          ii++;
      }

      listOfTypeIds = g_list_next(listOfTypeIds);
  }

  if(strlen(temporaryString) > 1)
  {
      strcat(temporaryString, ")");
      return strdup(temporaryString);
  }
  else
  {
      return NULL;
  }
}

// This method generates the range query to use in the highDensity tracks (min-max)
//[+int databaseToUse+] the index of the database to use (start in 0)
//[+returns+] string with the query except the in clause
char *generateHDHVFdataQuery(int currentDatabase)
{
  char mainQuery[] = "SELECT fstart, fstop, fileName, offset, gbBlockBpSpan, gbBlockBpStep, gbBlockScale, gbBlockLowLimit, numRecords, byteLength FROM blockLevelDataInfo WHERE ";
  char *resultingQuery = NULL;

  resultingQuery = appendMaxMinBinToQuery(currentDatabase, mainQuery);  
return resultingQuery;
}

// This method retrieves an array of strings with one query per database
//[+returns+] array of string
char **getHDHVFdataQuery(void)
{
  return hdhvQueries;
}

// This method sets the arrays to store the queries to the high density tracks
//[+returns+] no return value
void setHDHVFdataQuery(void)
{
  int counter = 0;
  int numberGenboreeDatabases = 0;

  if(isHDHVFdataQueryInitialized == 0)
  {
      numberGenboreeDatabases = getNumberDatabases();

      hdhvQueries = (char **)calloc((numberGenboreeDatabases + 2 + 2), sizeof(char *));

      while (numberGenboreeDatabases > counter)
      {
          hdhvQueries[counter] = generateHDHVFdataQuery(counter);
          counter++;
      }
      isHDHVFdataQueryInitialized = 1;
  }
}

// This method retrieves an a string with the query to use on a database to get the information about a hdhv track
//[+int currentDatabase+] the index of the database to use (start in 0)
//[+returns+]string with query
char *getHDHVFeatureQuery(int currentDatabase)
{
  int numberGenboreeDatabases = getNumberDatabases();

  if(currentDatabase >= numberGenboreeDatabases)
    return NULL;
  return hdhvQueries[currentDatabase];
}

// This method sets the flag that tell you if the fileName has been initialized
//[+int value+] value of the flat to use
//[+returns+] no return value
void setFileName2fileWithFullNameHashHasBeenInitialized(int value)
{
  fileName2fileWithFullNameHashHasBeenInitialized = value;
}

// This method returns the flag that tell you if the fileName has been initialized
//[+returns+] a flag 0 or 1
int getFileName2fileWithFullNameHashHasBeenInitialized(void)
{
  return fileName2fileWithFullNameHashHasBeenInitialized;
}

// This method sets the number of blocks to process
//[+int numOfBlocks+] the number of blocks to process
//[+returns+] no return value
void setNumberOfBlocksToProcessGlobal(int numOfBlocks)
{
  numberOfBlocksToProcessGlobal = numOfBlocks;
}

// This method gets the number of blocks to process
//[+returns+] number of blocks to process
int getNumberOfBlocksToProcessGlobal(void)
{
  return numberOfBlocksToProcessGlobal;
}

// This method free the memory used by the global hash tables in this file
//[+returns+] no return value
void destroyAllHashesInHDManager(void)
{
  if(isGbTrackVarsHashInitialized == 1)
  {
      g_hash_table_destroy(gbTrackVarsHash);
      isGbTrackVarsHashInitialized = 0;
  }
  if(isGbTrackRecordTypesHashInitialized == 1)
  {
      g_hash_table_destroy(gbTrackRecordTypesHash);
      isGbTrackRecordTypesHashInitialized = 0;
  }
  if(fileId2FileNameHashInitialized == 1)
  {
      g_hash_table_destroy(fileId2FileNameHash);
      g_hash_table_destroy(fileName2fileIdHash);
      g_hash_table_destroy(fileName2FileSizeHash);
      fileId2FileNameHashInitialized = 0;
  }
  if(fids2BlockLevelDataInfoHashInitialized == 1)
  {
      g_hash_table_destroy(fids2BlockLevelDataInfoHash);
      fids2BlockLevelDataInfoHashInitialized = 0;
  }
  if(fileName2fileWithFullNameHashHasBeenInitialized == 1)
  {
      g_hash_table_destroy(fileName2fileWithFullNameHash);
      fileName2fileWithFullNameHashHasBeenInitialized = 0;
  }
  closeFileHandlerHash();
}

// This method sets the length of the segment in bps
//[+long long length+] the length of the segment in bps
//[+returns+] no return value
void setLengthOfSegmentGlobalForHDTrack(long long length)
{
  lengthOfSegmentGlobalForHDTrack = length;
}

// This method sets the bases per pixel
//[+returns+] no return value
void setBasesPerPixel(void)
{
  basesPerPixelGlobalForHDTrack = (gdouble) lengthOfSegmentGlobalForHDTrack / (gdouble) canvasWidthGlobalForHDTrack;
}

// This method return the bases per pixel
//[+returns+] double bases per pixel
gdouble getBasesPerPixel(void)
{
  return basesPerPixelGlobalForHDTrack;
}

// This method sets the segment to canvas scale
//[+double myScale+] global scale
//[+returns+] no return value
void setUniversalScaleGlobalForHDTrack(double myScale)
{
  universalScaleGlobalForHDTrack = myScale;
}

// This method sets the start of the chromosome location
//[+long long start+] start position of the chromosome from the selected region
//[+returns+] no return value
void setStartPositionGlobalForHDTrack(long long start)
{
  startPositionGlobalForHDTrack = start;
}

// This method sets the end of the chromosome location
//[+long long end+] end position of the chromosome from the selected region
//[+returns+] no return value
void setEndPositionGlobalForHDTrack(long long end)
{
  endPositionGlobalForHDTrack = end;
}

// This method returns the size of the canvas
//[+int myWidth+] number of pixels in the canvas
//[+returns+] no return value
void setCanvasWidthGlobalForHDTrack(int myWidth)
{
  canvasWidthGlobalForHDTrack = myWidth;
}

// This method returns the size of the canvas
//[+returns+] the canvas size
int getCanvasWidthGlobalForHDTrack(void)
{
  return canvasWidthGlobalForHDTrack;
}

// This method returns the gbTrackVarsHash hash
//[+returns+] a hash table
char **getGbTrackVars(void)
{
  return gbTrackVars;
}

// This method returns and initialize the gbTrackVarsHash hash
//[+returns+] a hash table
GHashTable *getGbTrackVarsHash(void)
{
  if(isGbTrackVarsHashInitialized == 0)
  {
      setGbTrackVarsHash();
  }
  return gbTrackVarsHash;
}

// This method generates a small hash with the values of the gbTrack records values and an id.
//[+returns+] no return value
void setGbTrackVarsHash(void)
{
  int gbTrackId = 0;
  char **gbTrackVars = getGbTrackVars();

  if(isGbTrackVarsHashInitialized == 0)
  {
      gbTrackVarsHash = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);

      for (gbTrackId = 0; gbTrackVars[gbTrackId][0] != '\0'; gbTrackId++)
      {
          g_hash_table_insert(gbTrackVarsHash, g_strdup(gbTrackVars[gbTrackId]), intdup(gbTrackId));
      }
      isGbTrackVarsHashInitialized = 1;
  }

  return;
}

// This method returns the gbtrackRecordTypes
//[+returns+] a array of strings
char **getGbTrackRecordTypes(void)
{
  return gbTrackRecordTypes;
}

// This method returns and initialize the gbtrackRecords hash
//[+returns+] a hash table
GHashTable *getGbTrackRecordTypesHash(void)
{
  if(isGbTrackRecordTypesHashInitialized == 0)
  {
      setGbTrackRecordTypesHash();
  }
  return gbTrackRecordTypesHash;
}

// This method generates a small hash with the values of the gbTrack records values
//[+returns+] no return value
void setGbTrackRecordTypesHash(void)
{
  int gbRecordTypeId = 0;
  char **gbTrackRecordTs = getGbTrackRecordTypes();

  if(isGbTrackRecordTypesHashInitialized == 0)
  {
      gbTrackRecordTypesHash = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);

      for (gbRecordTypeId = 0; gbTrackRecordTs[gbRecordTypeId][0] != '\0'; gbRecordTypeId++)
      {
          g_hash_table_insert(gbTrackRecordTypesHash, g_strdup(gbTrackRecordTypes[gbRecordTypeId]), intdup(gbRecordTypeId));
      }
      isGbTrackRecordTypesHashInitialized = 1;
  }

  return;
}

// This method initialize three hashes fileId 2 fileName, fileName to fileId, and fileName to fileSize
//[+returns+] no return value
void setFileId2FileNameHash(void)
{
  if(fileId2FileNameHashInitialized == 0)
  {
      fileId2FileNameHash = g_hash_table_new_full(g_int_hash, g_int_equal, g_free, g_free);
      fileName2fileIdHash = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
      fileName2FileSizeHash = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
      fileId2FileNameHashInitialized = 1;
  }
}

// This method initialize the full path
//[+returns+] no return value
void setFullPathToFile(void)
{
  char query[] = "SELECT fvalue from fmeta where fname = 'RID_SEQUENCE_DIR'";
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection = NULL;
  MYSQL mysql;
  MYSQL_RES *sqlresult = NULL;
  MYSQL_ROW row = NULL;

  resetLocalConnection(getDatabaseFromId(0));
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);
  memset(sqlbuff, '\0', 2555);
  sprintf(sqlbuff, "%s", query);

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      fprintf(stderr, "Error querying the searchConfig table in function setGenomicFileName 2nd query.\n");
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return;
  }
  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult))
  {
      if((row = mysql_fetch_row(sqlresult)))
      {
          fullPathToFile = strdup(row[0]);
          isFullPathToFileSet = 1;
      }
  }

  mysql_free_result(sqlresult);

  return;
}

// This method initialize and return the full path
//[+returns+] full path
char *getFullPathToFile(void)
{
  if(isFullPathToFileSet == 0)
    setFullPathToFile();

  return fullPathToFile;
}

// This method initialize a hash of fileName to fileWithFullName
//[+returns+] no return value
void setFileName2fileWithFullNameHash(void)
{
  if(fileName2fileWithFullNameHashHasBeenInitialized == 0)
  {
      fileName2fileWithFullNameHash = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
      fileName2fileWithFullNameHashHasBeenInitialized = 1;
  }
}

// This method appends the path to a file
//[+char *fileName+]  file name
//[+returns+] the fileName with the path
char *returnFileWithFullPath(char *fileName)
{
  char *pathName = NULL;
  char *fullName = NULL;

  if(isFullPathToFileSet == 0)
    setFullPathToFile();

  pathName = fullPathToFile;

  if(fileName == NULL || strlen(fileName) < 1)
  {
      fprintf(stderr, "fileName is empty\n");
      return NULL;
  }

  if(pathName == NULL || strlen(pathName) < 1)
  {
      fprintf(stderr, "Full Path is empty");
      return NULL;
  }

  if(fileName2fileWithFullNameHashHasBeenInitialized == 0)
  {
      setFileName2fileWithFullNameHash();
  }

  fullName = (char *)g_hash_table_lookup(fileName2fileWithFullNameHash, fileName);
  if(fullName == NULL || strlen(fullName) < 1)
  {
      fullName = addFullPathToFile(fileName, pathName);
      g_hash_table_insert(fileName2fileWithFullNameHash, g_strdup(fileName), g_strdup(fullName));
  }

  return fullName;
}

// This method appends the path to a file
//[+char *fileName+]  file name
//[+char *pathName+]  path name
//[+returns+] the fileName with the path
char *addFullPathToFile(char *fileName, char *pathName)
{
  int lengthFileName = strlen(fileName);
  int lengthPathName = 0;
  char *fullName = NULL;
  int sizeFullName = 0;

  lengthPathName = strlen(pathName);

  if((lengthFileName + lengthPathName) <= 1)
    return NULL;

  sizeFullName = lengthFileName + lengthPathName + 5;

  fullName = getstring(sizeFullName);
  sprintf(fullName, "%s/%s", pathName, fileName);

  return fullName;
}

// This method returns the ftypeAttrNames.name as a comma separated list to use in a query
//[+returns+] returns the ftypeAttrnames.name comma separated and with quotations ready to use in a query
char *returnTrackVarsAsAString(void)
{
  char trackVarsBuff[MAXLENGTHOFTEMPSTRING] = "";
  int gbTrackId = 0;
  int numberOfTrackVars = 0;
  char **gbTrackVars = getGbTrackVars();

  for (numberOfTrackVars = 0; gbTrackVars[numberOfTrackVars][0] != '\0'; numberOfTrackVars++) ;

  numberOfTrackVars--;

  for (gbTrackId = 0; gbTrackVars[gbTrackId][0] != '\0'; gbTrackId++)
  {
      strcat(trackVarsBuff, "'");
      strcat(trackVarsBuff, gbTrackVars[gbTrackId]);
      strcat(trackVarsBuff, "'");
      if(gbTrackId < numberOfTrackVars)
      {
          strcat(trackVarsBuff, ", ");
      }
  }

  return strdup(trackVarsBuff);
}

// This method free a hdhv structure
//[+highDensFtypes * localBlockLevel+]  Structure with the information from the block
//[+returns+] no return value
void deleteHighDensFtypes(highDensFtypes * localBlockLevel)
{
  free(localBlockLevel->fileName);
  localBlockLevel->fileName = NULL;
  free(localBlockLevel);
  localBlockLevel = NULL;
  return;
}

// This method creates a global hdhv structure
//[+returns+] the newly created highDensFtypes structure.
highDensFtypes *makeHighDensFtypes(void)
{
  highDensFtypes *localHighDensFtypes;
  if((localHighDensFtypes = (highDensFtypes *) calloc(1, sizeof(highDensFtypes))) == NULL)
  {
      fprintf(stderr, "Could not allocate enough memory for highDensFtypes structure.\n");
      return NULL;
  }
  localHighDensFtypes->gbTrackWindowingMethod = MAXIMUM;        //default 0 AVG
  localHighDensFtypes->gbTrackRecordType = -1;
  localHighDensFtypes->fileName = NULL;
  localHighDensFtypes->gbTrackDataSpan = 1;     //default 1
  localHighDensFtypes->bpSpan = 1;      // default 1
  localHighDensFtypes->bpStep = 1;      //default 1
  localHighDensFtypes->gbTrackDataMax = 1.0;    //default 1.0
  localHighDensFtypes->gbTrackDataMin = 0.0;    // default 0.0
  localHighDensFtypes->gbTrackUseLog = 0;       //default 0
  localHighDensFtypes->gbTrackHasNullRecords = 0;       //default false 0
  localHighDensFtypes->gbTrackFormula = WIGGLE;
  localHighDensFtypes->scale = 0.0;
  localHighDensFtypes->lowLimit = 0.0;
  localHighDensFtypes->gbTrackDenominator = 0.0;
  localHighDensFtypes->offset = -1;
  localHighDensFtypes->numRecords = 0;
  localHighDensFtypes->annotationFid = 0;
  localHighDensFtypes->annotationStart = 0;
  localHighDensFtypes->annotationEnd = 0;
  localHighDensFtypes->gbTrackPxHeight = TALLSCORE;
  localHighDensFtypes->gbTrackUserMax = 1.0;
  localHighDensFtypes->gbTrackUserMin = 0.0;
  localHighDensFtypes->byteLength = 0;
  localHighDensFtypes->gbTrackPxScoreUpperThreshold = (gdouble)-4290772992.0;
  localHighDensFtypes->gbTrackPxScoreLowerThreshold = (gdouble)4290772992.0;
  localHighDensFtypes->gbTrackPxScoreUpperThresholdColor = NULL;
  localHighDensFtypes->gbTrackPxScoreLowerThresholdColor = NULL;
  localHighDensFtypes->gbTrackPxScoreUpperNegativeThreshold = (gdouble)-4290772992.0;
  localHighDensFtypes->gbTrackPxScoreLowerNegativeThreshold = (gdouble)4290772992.0;
  localHighDensFtypes->gbTrackPxScoreUpperNegativeThresholdColor = NULL;
  localHighDensFtypes->gbTrackPxScoreLowerNegativeThresholdColor = NULL;
  localHighDensFtypes->gbTrackNegativeColor = NULL;
  localHighDensFtypes->gbTrackYIntercept = 0.0;
  localHighDensFtypes->gbTrackPartitioning = NULL;
  localHighDensFtypes->gbTrackZeroDraw = "true" ;
  return localHighDensFtypes;
}

// This method complements the getTrackIdsForHighDensityTracks method fill up one field of the hdhv structure from a track value pair
//[+highDensFtypes *highDensityTrackInfo+]  Structure with the information from the block
//[+char *ftypeAttName+] the ftype attribute name
//[+char *ftypeAttValue+] the ftype attribute value
//[+returns+] 1 or 0.
int populateHDTI(highDensFtypes * highDensityTrackInfo, char *ftypeAttName, char *ftypeAttValue)
{
  GHashTable *gbTrackVarsHash = getGbTrackVarsHash();
  GHashTable *gbTrackRecordTyHash = getGbTrackRecordTypesHash();
  int *gbTrackId = NULL;
  int caseNumber = -1;
  double temp = 0.0;
  int windValue = -1;
  int dataType = -1;
  int *recordType = NULL;
  int recordTypeId = -1;
  int formula = 0;
  int useLog = 0;
  int hasNulls = 0;
  struct rgbColor *upperColor;
  struct rgbColor *lowerColor;
  if(isFullPathToFileSet == 0)
  {
      setFullPathToFile();
  }

  gbTrackId = (int *)g_hash_table_lookup(gbTrackVarsHash, ftypeAttName);
  //fprintf(stderr, "attrName: %s, id: %d\n\n", ftypeAttName, gbTrackId);
  if(!gbTrackId)
  {
    printf("1");
    fprintf(stderr, "error in function populateHDTI the value of the ftypeAttName %s is not in the gbTrackVarsHash\n", ftypeAttName);
    return 0;
  }
  else
    caseNumber = *gbTrackId;
    //printf("attrName: %s, id: %d\n", ftypeAttName, caseNumber);
  switch (caseNumber)
  {
    case 0:
      if(ftypeAttValue == NULL)
      {
          windValue = MAXIMUM;
      }
      else if(g_ascii_strncasecmp(ftypeAttValue, "AVG", 3) == 0)
      {
          windValue = AVERAGE;
      }
      else if(g_ascii_strncasecmp(ftypeAttValue, "MAX", 3) == 0)
      {
          windValue = MAXIMUM;
      }
      else if(g_ascii_strncasecmp(ftypeAttValue, "MIN", 3) == 0)
      {
          windValue = MINIMUM;
      }
      else
      {
          windValue = MAXIMUM;
      }
      highDensityTrackInfo->gbTrackWindowingMethod = windValue;
      break;
    case 1:
      recordType = (int *)g_hash_table_lookup(gbTrackRecordTyHash, ftypeAttValue);
      if(!recordType)
      {
          fprintf(stderr, "error in function populateHDTI the value of the ftypeAttValue %s is not in the gbTrackRecordType hash\n", ftypeAttValue);
          return 0;
      }
      else
        recordTypeId = *recordType;

      highDensityTrackInfo->gbTrackRecordType = recordTypeId;
      break;
    case 2:
      if(ftypeAttValue != NULL && strlen(ftypeAttValue) > 0)
      {
          highDensityTrackInfo->fileName = returnFileWithFullPath(ftypeAttValue);
      }
      break;
    case 3:
      highDensityTrackInfo->gbTrackDataSpan = atoi(ftypeAttValue);
      break;
    case 4:
      highDensityTrackInfo->bpSpan = atoi(ftypeAttValue);
      break;
    case 5:
      highDensityTrackInfo->bpStep = atoi(ftypeAttValue);
      break;
    case 6:
      temp = 0.0;
      sscanf(ftypeAttValue, "%lf", &temp);
      highDensityTrackInfo->gbTrackDataMax = temp;
      break;
    case 7:
      temp = 0.0;
      sscanf(ftypeAttValue, "%lf", &temp);
      highDensityTrackInfo->gbTrackDataMin = temp;
      break;
    case 8:
      if(g_ascii_strncasecmp(ftypeAttValue, "true", 4) == 0)
      {
          useLog = 1;
      }
      highDensityTrackInfo->gbTrackUseLog = useLog;
      break;
    case 9:
      if(ftypeAttValue == NULL)
      {
          formula = WIGGLE;
      }
      else if(g_ascii_strncasecmp(ftypeAttValue, "wiggle", 6) == 0)
      {
          formula = WIGGLE;
      }
      else
      {
          formula = WIGGLE;
      }
      highDensityTrackInfo->gbTrackUseLog = formula;
      break;
    case 10:
      temp = 0.0;
      sscanf(ftypeAttValue, "%lf", &temp);
      highDensityTrackInfo->scale = temp;
      break;
    case 11:
      temp = 0.0;
      sscanf(ftypeAttValue, "%lf", &temp);
      highDensityTrackInfo->lowLimit = temp;
      break;
    case 12:
      temp = 0.0;
      sscanf(ftypeAttValue, "%lf", &temp);
      highDensityTrackInfo->gbTrackDenominator = temp;
      break;
    case 13:
      if(g_ascii_strncasecmp(ftypeAttValue, "true", 4) == 0)
      {
          hasNulls = 1;
      }
      highDensityTrackInfo->gbTrackHasNullRecords = hasNulls;
      break;
    case 14:
      highDensityTrackInfo->gbTrackPxHeight = atoi(ftypeAttValue);
      break;
    case 15:
      temp = 0.0;
      sscanf(ftypeAttValue, "%lf", &temp);
      highDensityTrackInfo->gbTrackUserMax = temp;
      break;
    case 16:
      temp = 0.0;
      sscanf(ftypeAttValue, "%lf", &temp);
      highDensityTrackInfo->gbTrackUserMin = temp;
      break;
    case 17:
      temp = 0.0;
      sscanf(ftypeAttValue, "%lf", &temp);
      highDensityTrackInfo->gbTrackPxScoreUpperThreshold = temp;
      break;
    case 18:
      temp = 0.0;
      sscanf(ftypeAttValue, "%lf", &temp);
      highDensityTrackInfo->gbTrackPxScoreLowerThreshold = temp;
      break;
    case 19:
      highDensityTrackInfo->gbTrackPxScoreUpperThresholdColor = strdup(ftypeAttValue);
      break;
    case 20:
      highDensityTrackInfo->gbTrackPxScoreLowerThresholdColor = strdup(ftypeAttValue);
      break;
    case 21:
      temp = 0.0;
      sscanf(ftypeAttValue, "%lf", &temp);
      highDensityTrackInfo->gbTrackPxScoreUpperNegativeThreshold = temp;
      break;
    case 22:
      temp = 0.0;
      sscanf(ftypeAttValue, "%lf", &temp);
      highDensityTrackInfo->gbTrackPxScoreLowerNegativeThreshold = temp;
      break;
    case 23:
      highDensityTrackInfo->gbTrackPxScoreUpperNegativeThresholdColor = strdup(ftypeAttValue);
      break;
    case 24:
      highDensityTrackInfo->gbTrackPxScoreLowerNegativeThresholdColor = strdup(ftypeAttValue);
      break;
    case 25:
      highDensityTrackInfo->gbTrackNegativeColor = strdup(ftypeAttValue);
      break;
    case 26:
      temp = 0.0;
      //sscanf(ftypeAttValue, "%lf", &temp);
      // fix the y intercept to 0 since we now have partitioning option
      highDensityTrackInfo->gbTrackYIntercept = temp;
      break;
    case 27:
      if(ftypeAttValue == NULL)
      {
        highDensityTrackInfo->gbTrackPartitioning = strdup("false");
      }
      else if(g_ascii_strncasecmp(ftypeAttValue, "true", 4) == 0)
      {
        highDensityTrackInfo->gbTrackPartitioning = strdup("true");
      }
      else if(g_ascii_strncasecmp(ftypeAttValue, "false", 5) == 0)
      {
        highDensityTrackInfo->gbTrackPartitioning = strdup("false");
      }
      else
      {
        highDensityTrackInfo->gbTrackPartitioning = strdup("false") ;
      }
      fprintf(stderr, "set partition: %s", highDensityTrackInfo->gbTrackPartitioning);
      break;
    case 28: //gbTrackZeroDraw
      if(ftypeAttValue == NULL)
      {
        highDensityTrackInfo->gbTrackZeroDraw = strdup("true") ;
      }
      else if(g_ascii_strncasecmp(ftypeAttValue, "true", 4) == 0)
      {
        highDensityTrackInfo->gbTrackZeroDraw = strdup("true") ;
      }
      else if(g_ascii_strncasecmp(ftypeAttValue, "false", 5) == 0)
      {
        highDensityTrackInfo->gbTrackZeroDraw = strdup("false") ;
      }
      else
      {
        highDensityTrackInfo->gbTrackZeroDraw = strdup("true") ;
      }
      break ;
    default:
      fprintf(stderr, "error in function populateHDTI the value of the ftypeAttName %s is not in the gbTrackVarsHash\n", ftypeAttName);
      return 0;
      break;
  }

  return 1;
}

// This method return an int array with the track is for the hdhv tracks
//[+int databaseId+] the database index
//[+int *numberOfHighDensityTracks+] gets the number of hdhv tracks found it in this method
//[+returns+] the int array with ftype ids.
int *getTrackIdsForHighDensityTracks(int databaseId, int *numberOfHighDensityTracks)
{
  char sqlbuff[] =
      "SELECT ftype_id FROM ftype2attributes, ftypeAttrNames, ftypeAttrValues WHERE ftype2attributes.ftypeAttrName_id = ftypeAttrNames.id AND ftype2attributes.ftypeAttrValue_id = ftypeAttrValues.id AND ftypeAttrNames.name = 'gbTrackRecordType'";
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  int *listOfFtypeIds = NULL;
  int numberOfRecords = 0;
  int counter = 0;

  if(databaseId < 0)
    return NULL;

  resetLocalConnection(getDatabaseFromId(databaseId));
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      fprintf(stderr, "Error querying the ftype2attributes table in function getTrackIdsForHighDensityTracks.\n");
      fprintf(stderr, "The query is %s\n", sqlbuff);
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return NULL;
  }
  sqlresult = mysql_store_result(connection);

  numberOfRecords = mysql_num_rows(sqlresult);
  *numberOfHighDensityTracks = numberOfRecords;

  listOfFtypeIds = (int *)malloc((numberOfRecords) * sizeof(int));

  if(numberOfRecords > 0)
  {
      listOfFtypeIds = (int *)malloc((numberOfRecords) * sizeof(int));
      while ((row = mysql_fetch_row(sqlresult)) != NULL)
      {
          listOfFtypeIds[counter] = atoi(row[0]);
          counter++;
      }
  }

  mysql_free_result(sqlresult);

  return listOfFtypeIds;
}

// A quick method that identify if a track is hdhv
//[+int databaseId+] the database index
//[+int ftypeId+] the ftypeid
//[+returns+] 1 or 0
int isTrackHighDensity(int databaseId, int ftypeId)
{
  char query1[] = "SELECT ftypeAttrValues.value FROM ftype2attributes, ftypeAttrNames, ftypeAttrValues WHERE ftype2attributes.ftype_id = ";
  char query2[] =
      " AND ftype2attributes.ftypeAttrName_id = ftypeAttrNames.id AND ftype2attributes.ftypeAttrValue_id = ftypeAttrValues.id AND ftypeAttrNames.name = 'gbTrackRecordType'";
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  int isHDT = 0;

  sprintf(sqlbuff, "%s %d %s", query1, ftypeId, query2);
  resetLocalConnection(getDatabaseFromId(databaseId));
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      fprintf(stderr, "Error querying the ftype2attributes table in function isTrackHighDensity.\n");
      fprintf(stderr, "The query is %s\n", sqlbuff);
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return 0;
  }
  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult) > 0)
  {
      if((row = mysql_fetch_row(sqlresult)) != NULL)
      {
          if(row[0] != NULL)
            isHDT = 1;
      }
  }
  mysql_free_result(sqlresult);

  return isHDT;
}

// A quick method that identify if a track is hdhv
//[+char *featureType+] the trackName
//[+returns+] 1 or 0
int isHighDensityTrack(char *featureType)
{
  char query1[] = "SELECT ftypeAttrValues.value FROM ftype2attributes, ftypeAttrNames, ftypeAttrValues WHERE ftype2attributes.ftype_id = ";
  char query2[] =
      " AND ftype2attributes.ftypeAttrName_id = ftypeAttrNames.id AND ftype2attributes.ftypeAttrValue_id = ftypeAttrValues.id AND ftypeAttrNames.name = 'gbTrackRecordType'";
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  int databaseId = -1;
  int ftypeId = -1;
  int error = 0;

  ftypeId = returnftypeId(featureType, &databaseId);

  sprintf(sqlbuff, "%s %d %s", query1, ftypeId, query2);
  resetLocalConnection(getDatabaseFromId(databaseId));
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);

  error = mysql_real_query(connection, sqlbuff, strlen(sqlbuff));
  if(error != 0)
  {
      fprintf(stderr, "Error %d querying the ftype2attributes table in function isHighDensityTrack.\n", error);
      fprintf(stderr, "The query is %s\n", sqlbuff);
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return 0;
  }
  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult) > 0)
  {
      if((row = mysql_fetch_row(sqlresult)) != NULL)
      {
          if(row[0] != NULL)
          {
              mysql_free_result(sqlresult);
              return 1;
          }
      }
  }
  mysql_free_result(sqlresult);

  return 0;
}

// This method fill up the track specific structure that will be used as a
// template to fill up the blockLevelDataInfo.
//[+char *featureType+] the trackName
//[+returns+] the structure with information about the hdhv track
highDensFtypes *fillUpHighDensFtypes(char *featureType)
{
  char query1[] = "SELECT ftypeAttrNames.name, ftypeAttrValues.value FROM ftype2attributes, ftypeAttrNames, ftypeAttrValues WHERE ftype2attributes.ftype_id = ";
  char query2[] = " AND ftype2attributes.ftypeAttrName_id = ftypeAttrNames.id AND ftype2attributes.ftypeAttrValue_id = ftypeAttrValues.id AND ftypeAttrNames.name in (";
  char *HDFtypeVar = returnTrackVarsAsAString();
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  int databaseId = -1;
  int ftypeId = -1;
  int error = 0;

  ftypeId = returnftypeId(featureType, &databaseId);

  highDensFtypes *highDensityTrackInfo = makeHighDensFtypes();

  sprintf(sqlbuff, "%s %d %s %s)", query1, ftypeId, query2, HDFtypeVar);
  resetLocalConnection(getDatabaseFromId(databaseId));
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);
  error = mysql_real_query(connection, sqlbuff, strlen(sqlbuff));
  if(error != 0)
  {
      fprintf(stderr, "Error querying the ftype2attributes table in function fillUpHighDensFtypes.\n");
      fprintf(stderr, "The query is %s\n", sqlbuff);
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return NULL;
  }
  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult) > 0)
  {
      while ((row = mysql_fetch_row(sqlresult)) != NULL)
      {
          populateHDTI(highDensityTrackInfo, row[0], row[1]);
      }
  }
  mysql_free_result(sqlresult);
  free(HDFtypeVar);
  HDFtypeVar = NULL;

  return highDensityTrackInfo;
}

// This function calculates the remaining elements in a block and if the
// size of the first block only used if step and span are different.
//[+long annotationLenght+] the difference between the track start and the annotation start
//[+int bpStep+]  the bp step
//[+int bpSpan+]  the number of pixels per base
//[+int *sizeOfFirstFragment+] gets the size of the first fragment
//[+int *sizeOfFirstGap+]  gets the size of the first gap
//[+returns+] the number of spans in a block
int returnNumberOfSpansInRegion(long annotationLenght, int bpStep, int bpSpan, int *sizeOfFirstFragment, int *sizeOfFirstGap)
{
  int numberOfSpansInAnnotation = 0;
  double value1 = (double)annotationLenght / (double)bpStep;
  long value2 = (long)floor(value1);
  double fraction = value1 - value2;
  long sizeOfLeftOver = 0;
  int sizeOfGap = 0;
  numberOfSpansInAnnotation = value2;

  if(fraction > 0.000)
  {
      long basesFrac = lround(fraction * (double)bpStep);
      if(basesFrac >= bpSpan)
      {
          numberOfSpansInAnnotation += 1;
          sizeOfGap = bpStep - basesFrac;
          sizeOfLeftOver = bpSpan;
      }
      else
      {
          sizeOfLeftOver = bpSpan - basesFrac;
      }
  }

  *sizeOfFirstFragment = sizeOfLeftOver;
  *sizeOfFirstGap = sizeOfGap;
  return numberOfSpansInAnnotation;
}

// Inline function for updating the reusable pixel structure
//[+long locationToUpdate+]  chromosome location
//[+int canvasSize+]  the number of pixels in the canvas
//[+returns+] no return value
inline void updatePixelStruct(long locationToUpdate, int canvasSize)
{
  long firstPixelLong = (long)((locationToUpdate - 1) / bpPerPixel);
  long lastPixelLong =  bpPerPixel < 1 ? (long)(firstPixelLong + (1.0 / bpPerPixel)) : (long)((locationToUpdate - 1) / bpPerPixel);
  if(lastPixelLong > canvasSize)
  {
    lastPixelLong = canvasSize - 1;
  }
  else if(lastPixelLong < 0)
  {
    lastPixelLong = 0;
  }

  if(firstPixelLong < 0)
  {
    firstPixelLong = 0;
  }
  else if(firstPixelLong > canvasSize)
  {
    firstPixelLong = canvasSize - 1;
  }
  staticStoreCoord.firstPixel = firstPixelLong;
  staticStoreCoord.lastPixel = lastPixelLong;
}

// Inline function that updates the pixel in the track pixel array
//[+long firstPixel+]  The initial pixel to update in the range
//[+long lastPixel+]  the last pixel to update in the range
//[+int windowingMethod+]  the type of method to use to update the pixel eg. average, max or min
//[+double currentValue+]  the value to use to update the pixel
//[+double trackMinValue+]  the minimum value to use in the track
//[+double **pv+]  track array that stores the values to draw the hdhv track
//[+double **pe+]  track array to store extra values most common the count of values i the average
//[+returns+] no return value
inline void updatePixelValue(long firstPixel, long lastPixel, int windowingMethod, double currentValue, double *pixelValueForHDT, double *pixelExtras)
{
  long j = 0;
  if(strcasecmp(partitioningReq, "false") == 0)
  {
    // for average widowing method
    if(windowingMethod == 0)
    {
      for(j = firstPixel; j <= lastPixel; j++)
      {
        if(pixelValueForHDT[j] == valueToUseAsMinScore){
          pixelValueForHDT[j] = currentValue;
          pixelExtras[j] = 1.0;
        }
        else{
          pixelValueForHDT[j] += currentValue;
          pixelExtras[j] += 1.0;
        }
      }
    }
    // for max windowing method
    else if(windowingMethod == 1)
    {
      for(j = firstPixel; j <= lastPixel; j++)
      {
        if(currentValue > pixelValueForHDT[j])
        {
          pixelValueForHDT[j] = currentValue;
        }
        // done for the sake of bi directional bar chart
        if(currentValue < tempNegPixelArray[j])
        {
          tempNegPixelArray[j] = currentValue;
        }
      }
      
    }
    // for min windowing method
    else if(windowingMethod == 2)
    {
      for(j = firstPixel; j <= lastPixel; j++)
      {
        if(pixelValueForHDT[j] == valueToUseAsMinScore)
        {
          pixelValueForHDT[j] = currentValue;
        }
        else
        {
          if(currentValue < pixelValueForHDT[j])
          {
            pixelValueForHDT[j] = currentValue;
          }
        }
        // done for the sake of bi directional bar chart
        if(tempNegPixelArray[j] == valueToUseAsMaxScore)
        {
          tempNegPixelArray[j] = currentValue;
        }
        else
        {
          if(currentValue > tempNegPixelArray[j])
          {
            tempNegPixelArray[j] = currentValue;
          }
        }
      }
    } 
  }
  else
  {
    // for 'AVG' windowing method
    // note that 0 will be used as the y intercept from now as a fixed value
    if(windowingMethod == 0)
    {
      for(j = firstPixel; j <= lastPixel; j++)
      {
        if(pixelValueForHDT[j] == valueToUseAsMinScore || pixelValueForHDT[j] == valueToUseAsMaxScore)
        {
          pixelValueForHDT[j] = currentValue;
          pixelExtras[j] = 1.0;  
        }
        else
        {
          pixelValueForHDT[j] += currentValue;
          pixelExtras[j] += 1.0;
        }
      }  
    }
    // for 'MAX' windowing method
    else if(windowingMethod == 1)
    {
      if(currentValue > 0.0)
      {
        for(j = firstPixel; j <= lastPixel; j++)
        {
          if(currentValue > pixelValueForHDT[j])
          {
            pixelValueForHDT[j] = currentValue;
          }  
        }
      }
      else if(currentValue < 0.0)
      {
        for(j = firstPixel; j <= lastPixel; j++)
        {
          if(currentValue < pixelValueForHDT[j])
          {
            pixelValueForHDT[j] = currentValue;
          }  
        }
      }
    }
    // for 'MIN' windowing method
    else if(windowingMethod == 2)
    {
      if(currentValue > 0.0)
      {
        for(j = firstPixel; j <= lastPixel; j++)
        {
          if(pixelValueForHDT[j] == valueToUseAsMinScore)
          {
            pixelValueForHDT[j] = currentValue;
          }
          else
          {
            if(currentValue < pixelValueForHDT[j])
            {  
              pixelValueForHDT[j] = currentValue;
            }
          }
        }  
      }
      else if(currentValue < 0.0)
      {
        for(j = firstPixel; j <= lastPixel; j++)
        {
          if(pixelValueForHDT[j] == valueToUseAsMaxScore)
          {
            pixelValueForHDT[j] = currentValue;
          }
          else
          {
            if(currentValue > pixelValueForHDT[j])
            {  
              pixelValueForHDT[j] = currentValue;
            }
          }
        }
      }
    }
  }
}

// This function sets the number of elements to use used by the method that reads the configuration file.
//[+int value+]  the size of elements to use
//[+returns+] no return value
void setSizeOfElementsUsedToGetMaxNumElements(int value)
{
  sizeOfElementsUsedToGetMaxNumElements = value;
}

// This function returns the number of elemets to process
//[+returns+] return the number of elements to process
int getSizeOfElementsUsedToGetMaxNumElements(void)
{
  return sizeOfElementsUsedToGetMaxNumElements;
}

// This function return the reusable string buffer
//[+returns+] return the string buffer
char *getCurrentBufferToReadChars(void)
{
  return bufferToReadChars;
}

// This function return the reusable string buffer if the alternative size is larger that the current size the buffer is increased
//[+int alternativeStructSize+]  the new size of the buffer
//[+int dataSpan+]  the size of the dataSpan
//[+returns+] return the string buffer
char *getBufferToReadChars(int alternativeStructSize, int dataSpan)
{
  setBufferToReadChars(alternativeStructSize, dataSpan);
  return bufferToReadChars;
}

// This function return the static string buffer
//[+returns+] return the string buffer
char *getDefaultBufferToReadChars(void)
{
  if(isBufferToReadCharsInitialized == 0)
    setBufferToReadChars(getCurrentMaxNumberOfElementsToProcess(), sizeof(gdouble));
  return bufferToReadChars;
}

// This function initializes the reusable string buffer only once if the size of the buffer needs to be increase a reallocation of memory will be perform
//[+int newSize+]  the new size of the buffer
//[+int dataSpan+]  the size of the dataSpan
//[+returns+] no return
void setBufferToReadChars(int newSize, int dataSpan)
{
  int needToRealloc = 0;
  long maxCurrentNumberElementsToProcess = getCurrentMaxNumberOfElementsToProcess();
  long sizeOfbufferRequested = newSize * dataSpan;
  long currentBufferUsed = maxCurrentNumberElementsToProcess * sizeof(gdouble);

  if(sizeOfbufferRequested > currentBufferUsed)
  {
      setMaxNumberOfElementsToProcess(newSize);
      needToRealloc = 1;
  }

  if(isBufferToReadCharsInitialized == 0)
  {
      bufferToReadChars = (char *)calloc(currentBufferUsed, sizeof(char));
      isBufferToReadCharsInitialized = 1;
  }
  else
  {
      if(needToRealloc == 1)
      {
          bufferToReadChars = (char *)realloc(bufferToReadChars, sizeOfbufferRequested);
          memset(bufferToReadChars, '\0', sizeOfbufferRequested);
      }
      else
      {
          memset(bufferToReadChars, '\0', newSize);
      }
  }
}

// This function free the reusable string buffer
//[+returns+] no return value
void destroyBufferToReadChars(void)
{
  if(isBufferToReadCharsInitialized == 1)
  {
      free(bufferToReadChars);
      bufferToReadChars = NULL;
      isBufferToReadCharsInitialized = 0;
  }
}

// This function sets a global variable to know if the database has high density tracks
//[+int yesNo+]  the flag
//[+returns+] no return value
void setHasHighDensityTracks(int yesNo)
{
  hasHighDensityTracks = yesNo;
}

// This function tells whether of not the database has high density tracks
//[+returns+] return the flag
int getHasHighDensityTracks(void)
{
  return hasHighDensityTracks;
}

// This function sets and return the number of elemets to process
//[+int dataSpan+]  the size of the dataSpan
//[+returns+] return the number of elements to process
long getMaxNumberOfElementsToProcess(int dataSpan)
{
  setMaxNumberOfElementsToProcess(dataSpan);
  return maxNumberOfElementsToProcess;
}

// This function sets the the number of elements to use.
//[+int dataSpan+]  the size of the dataSpan
//[+returns+] no return value
void setMaxNumberOfElementsToProcess(int dataSpan)
{
  int structSize = sizeof(gdouble);
  long tempValue = 0;
  if(dataSpan > structSize)
  {
      structSize = dataSpan;
  }

  setSizeOfElementsUsedToGetMaxNumElements(structSize);
  tempValue = (long)floor((gdouble) staticBufferSize / (gdouble) structSize);
  maxNumberOfElementsToProcess = tempValue;     //  / 2; // I found not necessary to reduce the number of elements no change in speed MLGG
}

// This function return the number of elemets to process
//[+returns+] return the number of elements to process
long getCurrentMaxNumberOfElementsToProcess(void)
{
  return maxNumberOfElementsToProcess;
}

// This function sets the size of the static buffer
//[+long myBuffer+]  the size of the buffer
//[+returns+] no return value
void setStaticBufferSize(long myBuffer)
{
  staticBufferSize = myBuffer;
}

// This function return the size of the static buffer
//[+returns+] return the double buffer
long getStaticBufferSize(void)
{
  return staticBufferSize;
}

// This function free the reusable double buffer
//[+returns+] no return value
void destroyBufferToReadDoubles(void)
{
  free(bufferToReadDoubles);
  bufferToReadDoubles = NULL;
}

// This function initializes the reusable double buffer only once if the size of the buffer needs to be increase a reallocation of memory will be perform
//[+double lowLimit+]  the value to use to initialize the elements in the array
//[+int newSize+]  the new size of the buffer
//[+returns+] return the double buffer
void setBufferToReadDoubles(gdouble lowLimit, int newSize)
{
  long sizeOfBufferForDoubleArray = 0;
  int needToRealloc = 0;
  gdouble valueToUse = lowLimit - 1.0;
  int ii = 0;
  long sizeOfbufferRequested = newSize * sizeof(gdouble);

  sizeOfBufferForDoubleArray = getMaxNumberOfElementsToProcess(sizeof(gdouble)) * sizeof(gdouble);

  if(sizeOfbufferRequested > sizeOfBufferForDoubleArray)
  {
      setMaxNumberOfElementsToProcess(newSize);
      needToRealloc = 1;
  }

  if(isBufferToReadDoublesInitialized == 0)
  {
      bufferToReadDoubles = (gdouble *) calloc(getMaxNumberOfElementsToProcess(sizeof(gdouble)), sizeof(gdouble));
      isBufferToReadDoublesInitialized = 1;
  }
  else
  {
      if(needToRealloc == 1)
      {
          bufferToReadDoubles = (gdouble *) realloc(bufferToReadDoubles, sizeOfbufferRequested);
          for (ii = 0; ii < newSize; ii++)
          {
              bufferToReadDoubles[ii] = valueToUse;
          }
      }
      else
      {
          for (ii = 0; ii < newSize; ii++)
          {
              bufferToReadDoubles[ii] = valueToUse;
          }
      }
  }
}

// This function return the reusable double buffer
//[+returns+] return the double buffer
gdouble *getCurrentBufferToReadDoubles(void)
{
  return bufferToReadDoubles;
}

// This function return the reusable double buffer if the alternative size is larger that the current size the buffer is increased
//[+double lowLimit+]  the value to use to initialize the elements in the array
//[+int alternativeStructSize+]  the new size of the buffer
//[+returns+] return the double buffer
gdouble *getBufferToReadDoubles(double lowLimit, int alternativeStructSize)
{
  setBufferToReadDoubles(lowLimit, alternativeStructSize);
  return bufferToReadDoubles;
}

// This function return the reusable double buffer if the buffer was not initialized the method initializes the buffer only one time
//[+returns+] return the double buffer
gdouble *getDefaultBufferToReadDoubles(void)
{
  gdouble lowLimit = 0.f;
  int alternativeStructSize = maxNumberOfElementsToProcess;
  if(isBufferToReadDoublesInitialized == 0)
  {
      setBufferToReadDoubles(lowLimit, alternativeStructSize);
      isBufferToReadDoublesInitialized = 1;
  }

  return bufferToReadDoubles;
}

// This function initialize the fileHandler hash only one time
//[+returns+] no return value
void setFileToFileHandlerHash(void)
{
  if(isFileToFileHandlerHashInitialized == 0)
  {
      fileToFileHandlerHash = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
      isFileToFileHandlerHashInitialized = 1;
  }
}

// This function is used in case other methods outside the scope of this file want to have access the fileHash
//[+returns+] return the hash table
GHashTable *getFileToFileHandlerHash(void)
{
  if(isFileToFileHandlerHashInitialized == 0)
  {
      setFileToFileHandlerHash();
  }
  return fileToFileHandlerHash;
}

// This function close all the file handlers in a hash
//[+returns+] no return value
void closeFileHandlerHash(void)
{
  GHashTableIter iter;
  gpointer key, value;
  int *theFileHandler = 0;
  int fd;
  if(isFileToFileHandlerHashInitialized == 1)
  {
      g_hash_table_iter_init(&iter, fileToFileHandlerHash);
      while (g_hash_table_iter_next(&iter, &key, &value))
      {
          theFileHandler = (int *)value;
          fd = *theFileHandler;
          close(fd);
      }
      g_hash_table_destroy(fileToFileHandlerHash);
      isFileToFileHandlerHashInitialized = 0;
  }
}

// This function open a file and add the file handler to a hash table
//[+char *fileName+]  The file name to add to the hash
//[+int flag+]  the flag to use to open the file
//[+returns+] return the file handler 0 means no file was open
int returnFileHandler(char *fileName, int flag)
{
  int *theFileHandler = 0;
  int fd = 0;

  if(isFileToFileHandlerHashInitialized == 0)
  {
      setFileToFileHandlerHash();
  }

  theFileHandler = (int *)g_hash_table_lookup(fileToFileHandlerHash, fileName);

  if(!theFileHandler)
  {
      if(g_file_test(fileName, G_FILE_TEST_EXISTS) == 0)
      {
          fprintf(stderr, "Error in function returnFileHandler the file %s WAS NOT FOUND the function exit\n", fileName);
          return -50;
      }
      if(PROVIDE_ADVICE)
      {
          int adviceAccepted = posix_fadvise(fd, 0, 0, POSIX_FADV_SEQUENTIAL);
          if(adviceAccepted != 0)
          {
              fprintf(stderr, "Failed to advice the system using POSIX_FADV_SEQUENTIAL call !!! %d\n", adviceAccepted);
              perror(strerror(adviceAccepted));
          }
      }
      fd = open(fileName, flag);
      g_hash_table_insert(fileToFileHandlerHash, g_strdup(fileName), intdup(fd));
      return fd;
  }
  else
  {
      return *theFileHandler;
  }
}

// This function is experimental currently I am testing if a sha1 is a good idea in this case
//[+char *fileName+]  The file name to add to the hash
//[+int flag+]  the flag to use to open the file
//[+returns+] return the file handler 0 means no file was open
int returnFileHandlerUsingSha1(char *fileName, int flag)
{
  int *theFileHandler = 0;
  int fd = 0;
  char *fileNameAsSha1 = g_compute_checksum_for_string(G_CHECKSUM_SHA1, fileName, strlen(fileName));

  if(isFileToFileHandlerHashInitialized == 0)
  {
      setFileToFileHandlerHash();
  }

  theFileHandler = (int *)g_hash_table_lookup(fileToFileHandlerHash, fileNameAsSha1);

  if(!theFileHandler)
  {
      if(g_file_test(fileName, G_FILE_TEST_EXISTS) == 0)
      {
          fprintf(stderr, "Error in function returnFileHandlerUsingSha1 the file %s WAS NOT FOUND the function exit\n", fileName);
          return -50;
      }
      fd = open64(fileName, flag);
      g_hash_table_insert(fileToFileHandlerHash, g_strdup(fileNameAsSha1), intdup(fd));
      return fd;
  }
  else
  {
      return *theFileHandler;
  }
}

// This function initialize (only one time) a reusable structure and fillit up with the information necessary
//[+minHighDensFtype minimumHDInfo+]  Structure with the minimum information needed to update the defaultHighDensData structure
//[+unsigned long fid+]  the id for the fdata table // TODO need to be removed before deploying
//[+int fileId+]  the file id //TODO need to be removed after testing the experimental changes
//[+unsigned long offset+]  offset to read from the file
//[+int gbBlockBpSpan+]  the span of the annotation
//[+int gbBlockBpStep+]  the step for the annotations
//[+int gbBlockScale+]  the scale to use in the wiggle formula
//[+int gbBlockLowLimit+]  the low limit to use in the wiggle formula
//[+int numRecords+]  number of records in the block
//[+long annotationStart+]  the chromosome start
//[+long annotationStop+]  the chromosome stop
//[+long byteLength+] length of the block after compressing using zlib
//[+returns+] return 1 or 0
int fillDataHDHV(minHighDensFtype minimumHDInfo, unsigned long fid, int fileId,
                 unsigned long offset, int gbBlockBpSpan, int gbBlockBpStep, int gbBlockScale, int gbBlockLowLimit, int numRecords, long annotationStart, long annotationStop, long byteLength)
{
  char *fileName = NULL;
  int fileNameId = -1;

  if(fileId2FileNameHashInitialized == 0)
  {
      setFileId2FileNameHash();
  }

  if(isFullPathToFileSet == 0)
    setFullPathToFile();

  if(fileName2fileWithFullNameHashHasBeenInitialized == 0)
    setFileName2fileWithFullNameHash();
  if(fileId > 0)
  {
      fileNameId = fileId;
      fileName = (char *)g_hash_table_lookup(fileId2FileNameHash, &fileNameId);
      if(fileName == NULL)
      {
          fprintf(stderr, "in function fillDataHDHV UNABLE to retrieve file from id = %d\n", fileId);
          return -1;
      }
      else
      {
          defaultHighDensData.fileName = fileName;
      }
  }

  if(offset >= 0)
    defaultHighDensData.offset = offset;
  else
    defaultHighDensData.offset = -1;

  if(gbBlockBpSpan > 0)
    defaultHighDensData.bpSpan = gbBlockBpSpan;
  else
    defaultHighDensData.bpSpan = minimumHDInfo.bpSpan;

  if(gbBlockBpStep > 0)
    defaultHighDensData.bpStep = gbBlockBpStep;
  else
    defaultHighDensData.bpStep = minimumHDInfo.bpStep;

  if(gbBlockScale > 0)
    defaultHighDensData.scale = (gdouble) gbBlockScale;
  else
    defaultHighDensData.scale = minimumHDInfo.scale;

  if(gbBlockLowLimit >= 0)
    defaultHighDensData.lowLimit = (gdouble) gbBlockLowLimit;
  else
    defaultHighDensData.lowLimit = minimumHDInfo.lowLimit;

  if(numRecords > 0)
    defaultHighDensData.numRecords = numRecords;
  else
    defaultHighDensData.numRecords = minimumHDInfo.numRecords;
    
  if(byteLength > 0)
    defaultHighDensData.byteLength = byteLength;
  else
    defaultHighDensData.byteLength = 0;

  defaultHighDensData.annotationFid = fid;
  defaultHighDensData.annotationStart = annotationStart;
  defaultHighDensData.annotationEnd = annotationStop;
  return 1;
}

// This function initialize (only one time) a reusable buffer or clean it up if necessary
//[+int cleanIt+]  a flag to clean the static buffer with '\0'
//[+returns+] no return value a global static buffer string is initialized if necessary
void setStaticBuffer(int cleanIt)
{
  int ret = 0;
  void *initialBuffer = NULL;
  if(isStaticBufferInitialized == 0)
  {
      if(USEODIRECTFLAG)
      {
          //printf("staticBufferSize = %d", staticBufferSize);
          ret = posix_memalign(&initialBuffer, 4096, staticBufferSize);  
          if(ret)
          {
              printf("Unable to allocate aligned memory: %s", strerror(ret));
              exit(-5);
          }
          else
          {
              staticBuffer = (char *)initialBuffer;
              memset(staticBuffer, '\0', staticBufferSize);
              isStaticBufferInitialized = 1;
          }
      }
      else
      {
          staticBuffer = (char *)calloc(staticBufferSize, sizeof(char));
          isStaticBufferInitialized = 1;
      }
  }

  if(cleanIt > 0)
  {
      memset(staticBuffer, '\0', staticBufferSize);
  }
}

// This function initialize (only one time) a reusable buffer and fill up the buffer by reading from the file
//[+int fd+]  the file handler to avoid reopening the file and minimize io
//[+off64_t offset+]  Offset to start reading the file
//[+off_t fileSize+] The size of the file in bytes minimize io
//[+returns+] no return value a global static buffer string is filled
void fillStaticBuffer(int fd, off64_t offset, off_t fileSize)
{
  long byteLength = defaultHighDensData.byteLength;
  // Set staticBufferSize to byteLength if byteLength is larger. 
  if(byteLength > staticBufferSize){
    staticBufferSize = byteLength;
  }
  off64_t blockOffset = offset + staticBufferSize;
  off64_t totalSize = staticBufferSize;
  long long bufferRead = 0;

  if(isStaticBufferInitialized == 0)
  {
      setStaticBuffer(0);
  }

  //offsetStaticBuffer = offset;

  if(blockOffset > fileSize)
  {
      totalSize = fileSize - offset;
  }
  limitOfStaticBuffer = offset + totalSize;
  bufferRead = pread(fd, staticBuffer, totalSize, offset);
  if(PROVIDE_ADVICE)
  {
      int adviceAccepted = posix_fadvise(fd, offset, bufferRead, POSIX_FADV_DONTNEED);
      if(adviceAccepted != 0)
      {
          fprintf(stderr, "Failed to advice the system using do not need call !!! %d\n", adviceAccepted);
          perror(strerror(adviceAccepted));
      }
  }
}

// This function read a binary file and return a large string
//[+int fd+]  the file handler to avoid reopening the file and minimize io
//[+int numberOfElements+]  Number of elements to get
//[+int sizeOfElements+]  The sizeof the element
//[+off64_t seekTo+]  Offset to start reading the file
//[+off_t fileSize+] The size of the file in bytes minimize io
//[+returns+] a large string with the region from the file
char *returnAnnotationsFromFilePointer(int fd, int numberOfElements, int sizeOfElements, off64_t seekTo, off_t fileSize)
{
  char *pointerLocation;
  off64_t totalSize = numberOfElements * sizeOfElements;
  int newFile = 0;
  off64_t limit = seekTo + totalSize;
  long initialPointer = 0;

  if(fd != currentFD)
  {
      currentFD = fd;
      newFile = 1;
      offsetStaticBuffer = seekTo;
      limitOfStaticBuffer = seekTo + staticBufferSize;
      fillStaticBuffer(fd, seekTo, fileSize);
      initialPointer = 0;
  }
  else
  {
      if(limit > limitOfStaticBuffer)
      {
          fillStaticBuffer(fd, seekTo, fileSize);
          initialPointer = 0;
      }
      else
      {
          initialPointer = seekTo - offsetStaticBuffer;
      }

      if(seekTo < offsetStaticBuffer)
      {
          fprintf(stderr, "ERROR in function returnAnnotationsFromFilePointer offset is smaller that static offset\n");
          exit(90);
      }

  }

  pointerLocation = staticBuffer + initialPointer;
  return pointerLocation;
}

// This function fill up the pixel map for a track by using the information on the block
//[+myTrack *localTrack+]  Structure with information from the track
//[+int fileHandler+]  the file handler to avoid reopening the file and minimize io
//[+off_t fileSize+] The size of the file in bytes minimize io
//[+char *theStyle+] display style for the track
//[+returns+] no return value
void addHDAnnotationToPixelMap(gdouble * pixelValueForHDT, gdouble * pixelExtras, gdouble *pixelNegativeValueForHDT, gdouble *pixelNegativeExtras, int fileHandler, off_t fileSize, char *theStyle)
{
  int bpSpan = defaultHighDensData.bpSpan;
  gdouble trackMinValue = defaultHighDensData.gbTrackDataMin;
  valueToUseAsMinScore = trackMinValue - 1.0;
  valueToUseAsMaxScore = defaultHighDensData.gbTrackDataMax + 1.0;
  int bpStep = defaultHighDensData.bpStep;
  int dataSpan = defaultHighDensData.gbTrackDataSpan;
  long offset = defaultHighDensData.offset;
  long byteLength = defaultHighDensData.byteLength;
  long annotationStart = defaultHighDensData.annotationStart;
  long annotationStop = defaultHighDensData.annotationEnd;
  guint8 windowingMethod = defaultHighDensData.gbTrackWindowingMethod;
  int numRecords = defaultHighDensData.numRecords;
  int recordType = (int)defaultHighDensData.gbTrackRecordType;
  int hasNullRecords = (int)defaultHighDensData.gbTrackHasNullRecords;
  gdouble yIntercept = defaultHighDensData.gbTrackYIntercept;
  if(defaultHighDensData.gbTrackPartitioning == NULL)
  {
    partitioningReq = "false";
  }
  else
  {
    partitioningReq = defaultHighDensData.gbTrackPartitioning;
  }
  yInt = defaultHighDensData.gbTrackYIntercept;
  long trackStart = startPositionGlobalForHDTrack;
  long trackStop = endPositionGlobalForHDTrack;
  int canvasSize = canvasWidthGlobalForHDTrack;
  int numRecordsProcessed;
  long startTrim = 0;
  long numberOfElementsToProcess = maxNumberOfElementsToProcess;
  int ii = 0;
  int aa = 0;
  long elementsToProcess = numberOfElementsToProcess;
  long blockOffset = 0;
  long start = 0;
  long stop = 0;
  long size = 0;
  long currentLocation = 0;
  int gapSize = bpStep - bpSpan;
  int numberOfFirstBlock = 0;
  int sizeOfFirstBlock = 0;
  int sizeOfFirstGap = 0;
  int sizeOfBlock = 0;
  int reachEnd = 0;
  long initTransf = 0;
  bpPerPixel = basesPerPixelGlobalForHDTrack;
  gdouble pixelsPerBase = universalScaleGlobalForHDTrack;
  int firstPixel = 0;
  int lastPixel = 0;
  int pixelCounter = 0;
  int sizeInPixels = 0;
  long bpHolder = 0;
  int bpForPixelProcessed = 0;
  long bpInsideTrack = 0;
  long numberOfProcessed = 0;
  long deltaOffset = 0;
  long bpResolutionToCompressData = 10;
  long numberToProcess = 0;
  int loopCounter = 0;
  long locationToUpdate = 0;
  long bufferProcessed = 0;
  char *pointerToLocation = NULL;
  // variables for reading zlib streams
  int ret, flush, fileHandlerStat, bytesProcessed = 0;
  int sizeOfUncompressedBlock = dataSpan * numRecords;
  int numberOfRecordsToProcess, totalNumberOfRecordsToProcess, blankSpace;
  int totalNumberOfRecordsProcessed = 0;
  unsigned have;
  z_stream strm;
  //unsigned char in[byteLength];  
  //unsigned char out[CHUNK];
  long decompressedBlockCounter = 0;
  // Get stuff for the wiggle formula
  gdouble lowLimit = defaultHighDensData.lowLimit;
  gdouble denom = defaultHighDensData.gbTrackDenominator;
  gdouble scale = defaultHighDensData.scale;
  off64_t limit = offset + byteLength;
  // Sameer's new stuff
  // If new file/track
  // Remember one track CAN have multiple have binary files
  if(fileHandler != currentFD){
    fillStaticBuffer(fileHandler, offset, fileSize);
    pointerToLocation = staticBuffer;
    offsetStaticBuffer = offset;
    currentFD = fileHandler;
  }
  // if old file
  else{
    // check if block is contained in the buffer read before
    // If not make new buffer with the new block
    if(limit > limitOfStaticBuffer){
      fillStaticBuffer(fileHandler, offset, fileSize);
      pointerToLocation = staticBuffer;
      offsetStaticBuffer = offset;
    }
    else{
      pointerToLocation = staticBuffer + (offset - offsetStaticBuffer);
    }
  }
  // Initialize buffer to collect uncompressed data
  if(decompressedBlockInitialized == 0){
    decompressedBlock = (char *)malloc(decompressedBlockSize);
    decompressedBlockInitialized = 1;
  }
  // Initialize zlib variables
  strm.zalloc = Z_NULL;
  strm.zfree = Z_NULL;
  strm.opaque = Z_NULL;
  strm.avail_in = 0;
  strm.next_in = Z_NULL;
  ret = inflateInit(&strm);
  if(ret != Z_OK){
    fprintf(stderr, "zlib_Error_1: %d", ret);
    exit(EXIT_FAILURE);
  }
  // Check if the block after decompressing can fit in the buffer allocated.
  // If it can, call decompressing function once, otherwise keep on calling till the whole block is processed
  if(sizeOfUncompressedBlock <= decompressedBlockSize){
    // Inflate zlib stream
    // decompress until deflate stream ends or end of file
    do {
      strm.avail_in = byteLength;
      strm.next_in = pointerToLocation;
      // run inflate() on input until output buffer not full
      do {
        strm.avail_out = decompressedBlockSize;
        strm.next_out = decompressedBlock;
        ret = inflate(&strm, Z_NO_FLUSH);
        assert(ret != Z_STREAM_ERROR);  //state not clobbered
        switch (ret) {
          case Z_NEED_DICT:
            ret = Z_DATA_ERROR;     // and fall through 
          case Z_DATA_ERROR:
          case Z_MEM_ERROR:
            (void)inflateEnd(&strm);
          fprintf(stderr, "zlib_Error_2: %d", ret);
          exit(EXIT_FAILURE);
        }
      } while (strm.avail_out == 0);
    } while (ret != Z_STREAM_END);
    (void)inflateEnd(&strm);
    // Go through the uncompressed buffer and draw scores
    // Set start and stop for the block
    if(annotationStart < trackStart){
      start = trackStart;
      startTrim = abs(annotationStart - trackStart);
      deltaOffset = (long)(startTrim * dataSpan);
      currentLocation = start;
    }
    else{
      start = annotationStart;
      deltaOffset = 0;
      currentLocation = start; 
    }
    if(annotationStop > trackStop){
      stop = trackStop;
    }
    else{
      stop = annotationStop;
    }
    numberOfRecordsToProcess = (stop - start) + 1;
    // Cast output buffer appropriately and get scores
    // For in8Score
    if(dataSpan == 1){
      guint8 yIntCept = (guint8)yIntercept;
      guint8 *int8Score = (guint8 *)(decompressedBlock + deltaOffset);
      guint8 denomPlusOne = (guint8)(defaultHighDensData.gbTrackDenominator + 1);
      // Check what kind of style is to be drawn.
      // Update the pixel value accordingly
      if(strcasecmp(theStyle, BIDIRECTIONALGLOBALHISTOGRAMLARGE) == 0 || strcasecmp(theStyle, BIDIRECTIONALLOCALHISTOGRAMLARGE) == 0){
        // check if partitioning is required
        // do not partition
        if(strcasecmp(partitioningReq, "false") == 0)
        {
          for(ii = 0; ii < numberOfRecordsToProcess; ii++){
            if(*int8Score != denomPlusOne){
              staticStoreCoord.firstPixel = -1;
              staticStoreCoord.lastPixel = -1;
              locationToUpdate = (currentLocation - trackStart) + 1;
              updatePixelStruct(locationToUpdate, canvasSize);
              updatePixelValue(staticStoreCoord.firstPixel, staticStoreCoord.lastPixel, windowingMethod, (guint8)round((lowLimit + scale * (*int8Score / denom))), tempPixelArray, tempExtraValues);
            }
            currentLocation ++;
            int8Score ++;
          }  
        }
        // partition the values w.r.t to 0 (y intercept)
        else
        {
          for(ii = 0; ii < numberOfRecordsToProcess; ii++){
            if(*int8Score != denomPlusOne){
              staticStoreCoord.firstPixel = -1;
              staticStoreCoord.lastPixel = -1;
              locationToUpdate = (currentLocation - trackStart) + 1;
              updatePixelStruct(locationToUpdate, canvasSize);
              if(*int8Score > yIntCept){
                updatePixelValue(staticStoreCoord.firstPixel, staticStoreCoord.lastPixel, windowingMethod, (guint8)round((lowLimit + scale * (*int8Score / denom))), pixelValueForHDT, pixelExtras);  
              }
              else if(*int8Score < yIntCept){
                updatePixelValue(staticStoreCoord.firstPixel, staticStoreCoord.lastPixel, windowingMethod, (guint8)round((lowLimit + scale * (*int8Score / denom))), pixelNegativeValueForHDT, pixelNegativeExtras);
              }
            }
            currentLocation ++;
            int8Score ++;
          }
        }
      }
      else{
        for(ii = 0; ii < numberOfRecordsToProcess; ii++){
          if(*int8Score != denomPlusOne){
            staticStoreCoord.firstPixel = -1;
            staticStoreCoord.lastPixel = -1;
            locationToUpdate = (currentLocation - trackStart) + 1;
            updatePixelStruct(locationToUpdate, canvasSize);
            updatePixelValue(staticStoreCoord.firstPixel, staticStoreCoord.lastPixel, windowingMethod, (guint8)round((lowLimit + scale * (*int8Score / denom))), pixelValueForHDT, pixelExtras);
          }
          currentLocation ++;
          int8Score ++;
        }
      }
    }
    // For floatScore
    else if(dataSpan == 4){
      gfloat yIntCept = (gfloat)yIntercept;
      guint32 *nullCheck32 = (guint32 *)(decompressedBlock + deltaOffset);
      gfloat *gfloatScore = (gfloat *)(decompressedBlock + deltaOffset);
      // Check what kind of style is to be drawn.
      // Update the pixel value accordingly
      if(strcasecmp(theStyle, BIDIRECTIONALLOCALHISTOGRAMLARGE) == 0 || strcasecmp(theStyle, BIDIRECTIONALGLOBALHISTOGRAMLARGE) == 0){
        if(strcasecmp(partitioningReq, "false") == 0)
        {
          for(ii = 0; ii < numberOfRecordsToProcess; ii++){
            if(*nullCheck32 != largest32Value)
            {
              staticStoreCoord.firstPixel = -1;
              staticStoreCoord.lastPixel = -1;
              locationToUpdate = (currentLocation - trackStart) + 1;
              annoEnd = stop;
              updatePixelStruct(locationToUpdate, canvasSize);
              updatePixelValue(staticStoreCoord.firstPixel, staticStoreCoord.lastPixel, windowingMethod, *gfloatScore, tempPixelArray, tempExtraValues);
            }
            currentLocation ++;
            nullCheck32 ++;
            gfloatScore ++;
          }  
        }
        else
        {
          for(ii = 0; ii < numberOfRecordsToProcess; ii++){
            if(*nullCheck32 != largest32Value)
            {
              staticStoreCoord.firstPixel = -1;
              staticStoreCoord.lastPixel = -1;
              locationToUpdate = (currentLocation - trackStart) + 1;
              annoEnd = stop;
              updatePixelStruct(locationToUpdate, canvasSize);
              if(*gfloatScore > 0.0){
                updatePixelValue(staticStoreCoord.firstPixel, staticStoreCoord.lastPixel, windowingMethod, *gfloatScore, pixelValueForHDT, pixelExtras);  
              }
              else if(*gfloatScore < 0.0){
                updatePixelValue(staticStoreCoord.firstPixel, staticStoreCoord.lastPixel, windowingMethod, *gfloatScore, pixelNegativeValueForHDT, pixelNegativeExtras);
              }
            }
            currentLocation ++;
            nullCheck32 ++;
            gfloatScore ++;
          }
        }
        
      }
      else{
        for(ii = 0; ii < numberOfRecordsToProcess; ii++){
          if(*nullCheck32 != largest32Value)
          {
            staticStoreCoord.firstPixel = -1;
            staticStoreCoord.lastPixel = -1;
            locationToUpdate = (currentLocation - trackStart) + 1;
            updatePixelStruct(locationToUpdate, canvasSize);
            updatePixelValue(staticStoreCoord.firstPixel, staticStoreCoord.lastPixel, windowingMethod, *gfloatScore, pixelValueForHDT, pixelExtras);
          }
          currentLocation ++;
          nullCheck32 ++;
          gfloatScore ++;
        }  
      }
    }
    // For doubleScore
    else if(dataSpan == 8){
      guint64 *nullCheck64 = (guint64 *)(decompressedBlock + deltaOffset);
      gdouble *gdoubleScore = (gdouble *)(decompressedBlock + deltaOffset);
      if(strcasecmp(theStyle, BIDIRECTIONALGLOBALHISTOGRAMLARGE) == 0 || strcasecmp(theStyle, BIDIRECTIONALLOCALHISTOGRAMLARGE) == 0){
        if(strcasecmp(partitioningReq, "false") == 0)
        {
          for(ii = 0; ii < numberOfRecordsToProcess; ii++){
            if(*nullCheck64 != largest64Value)
            {
              staticStoreCoord.firstPixel = -1;
              staticStoreCoord.lastPixel = -1;
              locationToUpdate = (currentLocation - trackStart) + 1;
              updatePixelStruct(locationToUpdate, canvasSize);
              updatePixelValue(staticStoreCoord.firstPixel, staticStoreCoord.lastPixel, windowingMethod, *gdoubleScore, tempPixelArray, tempExtraValues);
              
            }
            currentLocation ++;
            nullCheck64 ++;
            gdoubleScore ++;
          }  
        }
        else
        {
          for(ii = 0; ii < numberOfRecordsToProcess; ii++){
            if(*nullCheck64 != largest64Value)
            {
              staticStoreCoord.firstPixel = -1;
              staticStoreCoord.lastPixel = -1;
              locationToUpdate = (currentLocation - trackStart) + 1;
              updatePixelStruct(locationToUpdate, canvasSize);
              if(*gdoubleScore > yIntercept){
                updatePixelValue(staticStoreCoord.firstPixel, staticStoreCoord.lastPixel, windowingMethod, *gdoubleScore, pixelValueForHDT, pixelExtras);  
              }
              else if(*gdoubleScore < yIntercept){
                updatePixelValue(staticStoreCoord.firstPixel, staticStoreCoord.lastPixel, windowingMethod, *gdoubleScore, pixelNegativeValueForHDT, pixelNegativeExtras);
              }
            }
            currentLocation ++;
            nullCheck64 ++;
            gdoubleScore ++;
          }
        }
        
      }
      else{
        for(ii = 0; ii < numberOfRecordsToProcess; ii++){
          if(*nullCheck64 != largest64Value)
          {
            staticStoreCoord.firstPixel = -1;
            staticStoreCoord.lastPixel = -1;
            locationToUpdate = (currentLocation - trackStart) + 1;
            updatePixelStruct(locationToUpdate, canvasSize);
            updatePixelValue(staticStoreCoord.firstPixel, staticStoreCoord.lastPixel, windowingMethod, *gdoubleScore, pixelValueForHDT, pixelExtras);
          }
          currentLocation ++;
          nullCheck64 ++;
          gdoubleScore ++;
        } 
      }
    }
  }
  // If size of block is larger than the size of the buffer allocated
  else{
    // Declare all required pointers and variables;
    guint8 *int8Score;
    guint32 *nullCheck32;
    guint64 *nullCheck64;
    gfloat *gfloatScore;
    gdouble *gdoubleScore;
    guint8 denomPlusOneForInt8Score = (guint8)(defaultHighDensData.gbTrackDenominator + 1);
    // Calculate delta offset before we start decompressing since it may or may not be present
    // in the first iteration of the decompressed block
    if(annotationStart < trackStart){
      start = trackStart;
      startTrim = abs(annotationStart - trackStart);
      deltaOffset = (long)(startTrim * dataSpan);
      currentLocation = start;
    }
    else{
      start = annotationStart;
      deltaOffset = 0;
      currentLocation = start; 
    }
    if(annotationStop > trackStop){
      stop = trackStop;
    }
    else{
      stop = annotationStop;
    }
    totalNumberOfRecordsToProcess = (stop - start) + 1;
    // keep on inflating till entire block is inflated
    do {
      strm.avail_in = byteLength;
      strm.next_in = pointerToLocation;
      // run inflate() on input until output buffer not full
      do {
        strm.avail_out = decompressedBlockSize;
        strm.next_out = decompressedBlock;
        ret = inflate(&strm, Z_NO_FLUSH);
        assert(ret != Z_STREAM_ERROR);  //state not clobbered
        switch (ret) {
          case Z_NEED_DICT:
            ret = Z_DATA_ERROR;     // and fall through 
          case Z_DATA_ERROR:
          case Z_MEM_ERROR:
            (void)inflateEnd(&strm);
            fprintf(stderr, "zlib_Error_2: %d", ret);
            exit(EXIT_FAILURE);
        }
        bytesProcessed += decompressedBlockSize;
        // output buffer is a multiple of 1, 4 and 8, so we are safe!
        // all the records will be complete
        // Check if deltaOffset is contained in the uncompressed region of the block
        // If not, decompress the next chunk
        if(bytesProcessed > deltaOffset){
          //Calculate number of records to process
          if(totalNumberOfRecordsProcessed == 0){
            if((totalNumberOfRecordsToProcess - totalNumberOfRecordsProcessed) <= (bytesProcessed - deltaOffset) / dataSpan){
              numberOfRecordsToProcess = totalNumberOfRecordsToProcess - totalNumberOfRecordsProcessed;
            }
            else{
              numberOfRecordsToProcess = (bytesProcessed - deltaOffset) / dataSpan;
            } 
          }
          else{
            if((totalNumberOfRecordsToProcess - totalNumberOfRecordsProcessed) <= decompressedBlockSize / dataSpan){
              numberOfRecordsToProcess = totalNumberOfRecordsToProcess - totalNumberOfRecordsProcessed;
            }
            else{
              numberOfRecordsToProcess = decompressedBlockSize / dataSpan;
            }
          }
          // For int8Score
          if(dataSpan == 1){
            guint8 yIntCept = (guint8)yIntercept;
            if((decompressedBlockSize - (bytesProcessed - deltaOffset)) >= 0){
              int8Score = (guint8 *)(decompressedBlock + (decompressedBlockSize - (bytesProcessed - deltaOffset)));
            }
            else{
              int8Score = (guint8 *)decompressedBlock;
            }
            if(strcasecmp(theStyle, BIDIRECTIONALLOCALHISTOGRAMLARGE) == 0 || strcasecmp(theStyle, BIDIRECTIONALGLOBALHISTOGRAMLARGE) == 0){
              if(strcasecmp(partitioningReq, "false") == 0)
              {
                // Draw all required records
                for(ii = 0; ii < numberOfRecordsToProcess; ii++){
                  if(*int8Score != denomPlusOneForInt8Score)
                  {
                    staticStoreCoord.firstPixel = -1;
                    staticStoreCoord.lastPixel = -1;
                    locationToUpdate = (currentLocation - trackStart) + 1;
                    updatePixelStruct(locationToUpdate, canvasSize);
                    updatePixelValue(staticStoreCoord.firstPixel, staticStoreCoord.lastPixel, windowingMethod, (guint8)round((lowLimit + scale * (*int8Score / denom))), tempPixelArray, tempExtraValues);
                  }
                  totalNumberOfRecordsProcessed ++;
                  currentLocation ++;
                  int8Score ++;
                }  
              }
              else
              {
                // Draw all required records
                for(ii = 0; ii < numberOfRecordsToProcess; ii++){
                  if(*int8Score != denomPlusOneForInt8Score)
                  {
                    staticStoreCoord.firstPixel = -1;
                    staticStoreCoord.lastPixel = -1;
                    locationToUpdate = (currentLocation - trackStart) + 1;
                    updatePixelStruct(locationToUpdate, canvasSize);
                    if(*int8Score > yIntCept){
                      updatePixelValue(staticStoreCoord.firstPixel, staticStoreCoord.lastPixel, windowingMethod, (guint8)round((lowLimit + scale * (*int8Score / denom))), pixelValueForHDT, pixelExtras); 
                    }
                    else if(*int8Score < yIntCept){
                      updatePixelValue(staticStoreCoord.firstPixel, staticStoreCoord.lastPixel, windowingMethod, (guint8)round((lowLimit + scale * (*int8Score / denom))), pixelNegativeValueForHDT, pixelNegativeExtras);
                    }
                  }
                  totalNumberOfRecordsProcessed ++;
                  currentLocation ++;
                  int8Score ++;
                }
              }
              
            }
            else{
              // Draw all required records
              for(ii = 0; ii < numberOfRecordsToProcess; ii++){
                if(*int8Score != denomPlusOneForInt8Score)
                {
                  staticStoreCoord.firstPixel = -1;
                  staticStoreCoord.lastPixel = -1;
                  locationToUpdate = (currentLocation - trackStart) + 1;
                  updatePixelStruct(locationToUpdate, canvasSize);
                  updatePixelValue(staticStoreCoord.firstPixel, staticStoreCoord.lastPixel, windowingMethod, (guint8)round((lowLimit + scale * (*int8Score / denom))), pixelValueForHDT, pixelExtras);
                }
                totalNumberOfRecordsProcessed ++;
                currentLocation ++;
                int8Score ++;
              } 
            }
          }
          // For floatScore
          else if(dataSpan == 4){
            gfloat yIntCept = (gfloat)yIntercept;
            if((decompressedBlockSize - (bytesProcessed - deltaOffset)) >= 0){
              nullCheck32 = (guint32 *)(decompressedBlock + (decompressedBlockSize - (bytesProcessed - deltaOffset)));
              gfloatScore = (gfloat *)(decompressedBlock + (decompressedBlockSize - (bytesProcessed - deltaOffset)));
            }
            else{
              nullCheck32 = (guint32 *)(decompressedBlock);
              gfloatScore = (gfloat *)(decompressedBlock);
            }
            // Check what kind of style is to be drawn.
            // Update the pixel value accordingly
            if(strcasecmp(theStyle, BIDIRECTIONALLOCALHISTOGRAMLARGE) == 0 || strcasecmp(theStyle, BIDIRECTIONALGLOBALHISTOGRAMLARGE) == 0){
              if(strcasecmp(partitioningReq, "false") == 0)
              {
                for(ii = 0; ii < numberOfRecordsToProcess; ii++){
                  if(*nullCheck32 != largest32Value)
                  {
                    staticStoreCoord.firstPixel = -1;
                    staticStoreCoord.lastPixel = -1;
                    locationToUpdate = (currentLocation - trackStart) + 1;
                    annoEnd = stop;
                    updatePixelStruct(locationToUpdate, canvasSize);
                    updatePixelValue(staticStoreCoord.firstPixel, staticStoreCoord.lastPixel, windowingMethod, *gfloatScore, tempPixelArray, tempExtraValues); 
                  }
                  currentLocation ++;
                  nullCheck32 ++;
                  gfloatScore ++;
                  totalNumberOfRecordsProcessed ++;
                } 
              }
              else
              {
                for(ii = 0; ii < numberOfRecordsToProcess; ii++){
                  if(*nullCheck32 != largest32Value)
                  {
                    staticStoreCoord.firstPixel = -1;
                    staticStoreCoord.lastPixel = -1;
                    locationToUpdate = (currentLocation - trackStart) + 1;
                    annoEnd = stop;
                    updatePixelStruct(locationToUpdate, canvasSize);
                    if(*gfloatScore > yIntCept){
                      updatePixelValue(staticStoreCoord.firstPixel, staticStoreCoord.lastPixel, windowingMethod, *gfloatScore, pixelValueForHDT, pixelExtras);  
                    }
                    else if(*gfloatScore < yIntCept){
                      updatePixelValue(staticStoreCoord.firstPixel, staticStoreCoord.lastPixel, windowingMethod, *gfloatScore, pixelNegativeValueForHDT, pixelNegativeExtras);
                    }
                  }
                  currentLocation ++;
                  nullCheck32 ++;
                  gfloatScore ++;
                  totalNumberOfRecordsProcessed ++;
                }
              }
            }
            else{
              for(ii = 0; ii < numberOfRecordsToProcess; ii++){
                if(*nullCheck32 != largest32Value)
                {
                  staticStoreCoord.firstPixel = -1;
                  staticStoreCoord.lastPixel = -1;
                  locationToUpdate = (currentLocation - trackStart) + 1;
                  updatePixelStruct(locationToUpdate, canvasSize);
                  updatePixelValue(staticStoreCoord.firstPixel, staticStoreCoord.lastPixel, windowingMethod, *gfloatScore, pixelValueForHDT, pixelExtras);
                }
                currentLocation ++;
                nullCheck32 ++;
                gfloatScore ++;
                totalNumberOfRecordsProcessed ++;
              }  
            }
          }
          // For doubleScore
          else if(dataSpan == 8){
            if((decompressedBlockSize - (bytesProcessed - deltaOffset)) >= 0){
              nullCheck64 = (guint64 *)(decompressedBlock + (decompressedBlockSize - (bytesProcessed - deltaOffset)));
              gdoubleScore = (gdouble *)(decompressedBlock + (decompressedBlockSize - (bytesProcessed - deltaOffset)));
            }
            else{
              nullCheck64 = (guint64 *)decompressedBlock;
              gdoubleScore = (gdouble *)decompressedBlock;
            }
            if(strcasecmp(theStyle, BIDIRECTIONALLOCALHISTOGRAMLARGE) == 0 || strcasecmp(theStyle, BIDIRECTIONALGLOBALHISTOGRAMLARGE) == 0){
              if(strcasecmp(partitioningReq, "false") == 0)
              {
                // Draw all required records
                for(ii = 0; ii < numberOfRecordsToProcess; ii++){
                  if(*nullCheck64 != largest64Value)
                  {
                    staticStoreCoord.firstPixel = -1;
                    staticStoreCoord.lastPixel = -1;
                    locationToUpdate = (currentLocation - trackStart) + 1;
                    updatePixelStruct(locationToUpdate, canvasSize);
                    updatePixelValue(staticStoreCoord.firstPixel, staticStoreCoord.lastPixel, windowingMethod, *gdoubleScore, tempPixelArray, tempExtraValues); 
                  }    
                  currentLocation ++;
                  nullCheck64 ++;
                  gdoubleScore ++;
                  totalNumberOfRecordsProcessed ++;
                }  
              }
              else
              {
                // Draw all required records
                for(ii = 0; ii < numberOfRecordsToProcess; ii++){
                  if(*nullCheck64 != largest64Value)
                  {
                    staticStoreCoord.firstPixel = -1;
                    staticStoreCoord.lastPixel = -1;
                    locationToUpdate = (currentLocation - trackStart) + 1;
                    updatePixelStruct(locationToUpdate, canvasSize);
                    if(*gdoubleScore > yIntercept){
                      updatePixelValue(staticStoreCoord.firstPixel, staticStoreCoord.lastPixel, windowingMethod, *gdoubleScore, pixelValueForHDT, pixelExtras);  
                    }
                    else if(*gdoubleScore < yIntercept){
                      updatePixelValue(staticStoreCoord.firstPixel, staticStoreCoord.lastPixel, windowingMethod, *gdoubleScore, pixelNegativeValueForHDT, pixelNegativeExtras);
                    } 
                  }    
                  currentLocation ++;
                  nullCheck64 ++;
                  gdoubleScore ++;
                  totalNumberOfRecordsProcessed ++;
                }
              }
            }
            else{
              // Draw all required records
              for(ii = 0; ii < numberOfRecordsToProcess; ii++){
                if(*nullCheck64 != largest64Value)
                {
                  staticStoreCoord.firstPixel = -1;
                  staticStoreCoord.lastPixel = -1;
                  locationToUpdate = (currentLocation - trackStart) + 1;
                  updatePixelStruct(locationToUpdate, canvasSize);
                  updatePixelValue(staticStoreCoord.firstPixel, staticStoreCoord.lastPixel, windowingMethod, *gdoubleScore, pixelValueForHDT, pixelExtras);
                }
                totalNumberOfRecordsProcessed ++;
                currentLocation ++;
                nullCheck64 ++;
                gdoubleScore ++;
              } 
            }  
          }
        }
      } while (strm.avail_out == 0);
      // Check if all required records have been drawn
      if(totalNumberOfRecordsProcessed == totalNumberOfRecordsToProcess){
        break;
      }
    } while (ret != Z_STREAM_END);
  }
}

// This function is called one time for each track the function initialize the pixel arrays and fill them
//[+myTrack *localTrack+]  Structure with information from the track
//[+returns+] no return value
void processHighDensityBlocks(myTrack * localTrack)
{
  long lengthOfTrackInPixels = canvasWidthGlobalForHDTrack + 2;
  int numberOfRecords = 0;
  
  localTrack->pixelValueForHDT = (gdouble *) calloc(lengthOfTrackInPixels, sizeof(gdouble));
  localTrack->pixelExtraValues = (gdouble *) calloc(lengthOfTrackInPixels, sizeof(gdouble));
  tempPixelArray = (gdouble *)calloc(lengthOfTrackInPixels, sizeof(gdouble));
  tempNegPixelArray = (gdouble *)calloc(lengthOfTrackInPixels, sizeof(gdouble));
  localTrack->pixelNegativeValueForHDT = (gdouble *) calloc(lengthOfTrackInPixels, sizeof(gdouble));
  localTrack->pixelExtraNegativeValues = (gdouble *) calloc(lengthOfTrackInPixels, sizeof(gdouble));
  tempExtraValues = (gdouble *) calloc(lengthOfTrackInPixels, sizeof(gdouble));
  numberOfRecords = fillBlockLevelDataInfo(localTrack);
  
}

// This function is called one time for each track a single query is perform to fill up all the blockLevelData and during the result set the pixel array is filled
//[+myTrack *localTrack+]  Structure with information from the track
//[+returns+] number of records processed  
int fillBlockLevelDataInfo(myTrack * localTrack)
{
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  char *featureType = localTrack->trackName;
  int numberOfRecords = 0;
  unsigned long fid = -1;
  int fileId;
  unsigned long offset;
  int gbBlockBpSpan;
  int gbBlockBpStep;
  int gbBlockScale;
  int gbBlockLowLimit;
  int numRecords;
  long byteLength;
  int databaseId = -1;
  int ftypeId = -1;
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  char orderBy[] = " order by fileName, offset";
  highDensFtypes *highDensFtypes = localTrack->highDensFtypes;
  // Initialize the pixel array with value: gbTrackDataMin - 1
  for(numberOfRecords = 0; numberOfRecords < (canvasWidthGlobalForHDTrack + 2); numberOfRecords ++){
    localTrack->pixelValueForHDT[numberOfRecords] = (gdouble)(highDensFtypes->gbTrackDataMin - 1.0);
    localTrack->pixelNegativeValueForHDT[numberOfRecords] = (gdouble)(highDensFtypes->gbTrackDataMax + 1.0);
    tempPixelArray[numberOfRecords] = (gdouble)(highDensFtypes->gbTrackDataMin - 1.0);
    tempNegPixelArray[numberOfRecords] = (gdouble)(highDensFtypes->gbTrackDataMax + 1.0);
  }
  numberOfRecords = 0;
  gdouble *pixelValueForHDT = localTrack->pixelValueForHDT;
  gdouble *pixelExtras = localTrack->pixelExtraValues;
  gdouble *pixelNegativeValueForHDT = localTrack->pixelNegativeValueForHDT;
  gdouble *pixelNegativeExtras = localTrack->pixelExtraNegativeValues;
  int numberOfRecordProcessed = 0;
  char statementForHDensityTracks[255] = "";
  long annotationStart = 0;
  long annotationStop = 0;
  struct stat buffer;
  int status = -1;
  int fd = -1;
  int *tempFd = NULL;
  int odflag = O_RDONLY | O_DIRECT;
  int regflag = O_RDONLY;
  int flag = 0;
  off64_t fileSize = -1;
  off64_t *off64 = 0;
  char *fullPath = NULL;
  int i;
  minHighDensFtype minimumHDInfo;
  setHDHVFdataQuery();
  setFileId2FileNameHash();
  setFileToFileHandlerHash();
  setDefaultHighDensData(highDensFtypes);
  minimumHDInfo.bpSpan = highDensFtypes->bpSpan;
  minimumHDInfo.bpStep = highDensFtypes->bpStep;
  minimumHDInfo.scale = highDensFtypes->scale;
  minimumHDInfo.lowLimit = highDensFtypes->lowLimit;
  minimumHDInfo.numRecords = highDensFtypes->numRecords;
  if(USEODIRECTFLAG)
  {
    flag = odflag;
  }
  else
  {
    flag = regflag;
  }
  if(isFullPathToFileSet == 0)
    setFullPathToFile();
  if(fileName2fileWithFullNameHashHasBeenInitialized == 0)
  {
    setFileName2fileWithFullNameHash();
  }
  ftypeId = returnftypeId(featureType, &databaseId);
  sprintf(statementForHDensityTracks, " ( %d )", ftypeId);
  sprintf(sqlbuff, "%s %s %s", getHDHVFeatureQuery(databaseId), statementForHDensityTracks, orderBy);
  //printf("the new query is \n%s\n", sqlbuff);
  resetLocalConnection(getDatabaseFromId(databaseId));
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);
  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
    fprintf(stderr, "Error querying the blockLevelDataInfo table in function fillBlockLevelDataInfo.\n");
    fprintf(stderr, "The query is %s\n", sqlbuff);
    fprintf(stderr, mysql_error(&mysql));
    fflush(stderr);
    return 0;
  }
  sqlresult = mysql_store_result(connection);
  //fprintf(stderr, " the query is \n%s\n", sqlbuff);
  numberOfRecords = mysql_num_rows(sqlresult);
  while ((row = mysql_fetch_row(sqlresult)) != NULL)
  {
    if(row[0] != NULL && strlen(row[0]) > 0)
    {
        annotationStart = atol(row[0]);
    }
    else
    {
        annotationStart = -1;
    }

    if(row[1] != NULL && strlen(row[1]) > 0)
    {
        annotationStop = atol(row[1]);
    }
    else
    {
        annotationStop = -1;
    }

    if(row[2] != NULL && strlen(row[2]) > 0)
    {
        fullPath = (char *)g_hash_table_lookup(fileName2fileWithFullNameHash, row[2]);
        if(fullPath == NULL || strlen(fullPath) < 1)
        {
            fullPath = addFullPathToFile(row[2], fullPathToFile);
            g_hash_table_insert(fileName2fileWithFullNameHash, g_strdup(row[2]), g_strdup(fullPath));
        }
        int *idFromHash = (int *)g_hash_table_lookup(fileName2fileIdHash, fullPath);
        off64 = (off64_t *) g_hash_table_lookup(fileName2FileSizeHash, fullPath);
        tempFd = (int *)g_hash_table_lookup(fileToFileHandlerHash, fullPath);
        if(idFromHash != NULL)
        {
            fileId = *idFromHash;
            fileSize = *off64;
            fd = *tempFd;
        }
        else
        {
            fileId = g_hash_table_size(fileId2FileNameHash) + 1;
            g_hash_table_insert(fileName2fileIdHash, g_strdup(fullPath), intdup(fileId));
            g_hash_table_insert(fileId2FileNameHash, intdup(fileId), g_strdup(fullPath));
            fd = returnFileHandler(fullPath, flag);
            if(fd == -50)
            {
              return 0 ;
            }
            status = fstat(fd, &buffer);
            if(status != 0)
            {
              return 0 ;
            }
            fileSize = buffer.st_size;
            off64 = (off64_t *) malloc(sizeof(off64_t));
            *off64 = fileSize;
            g_hash_table_insert(fileName2FileSizeHash, g_strdup(fullPath), off64);
        }
    }
    else
    {
        fileId = -1;
    }

    if(row[3] != NULL && strlen(row[3]) > 0)
    {
        offset = atol(row[3]);
    }
    else
    {
        offset = -1;
    }

    if(row[4] != NULL && strlen(row[4]) > 0)
    {
        gbBlockBpSpan = atoi(row[4]);
    }
    else
    {
        gbBlockBpSpan = -1;
    }

    if(row[5] != NULL && strlen(row[5]) > 0)
    {
        gbBlockBpStep = atoi(row[5]);
    }
    else
    {
        gbBlockBpStep = -1;
    }

    if(row[6] != NULL && strlen(row[6]) > 0)
    {
        gbBlockScale = atoi(row[6]);
    }
    else
    {
        gbBlockScale = -1;
    }

    if(row[7] != NULL && strlen(row[7]) > 0)
    {
        gbBlockLowLimit = atoi(row[7]);
    }
    else
    {
        gbBlockLowLimit = -1;
    }

    if(row[8] != NULL && strlen(row[8]) > 0)
    {
        numRecords = atoi(row[8]);
    }
    else
    {
        numRecords = -1;
    }
    
    if(row[9] != NULL && strlen(row[9]) > 0)
    {
      byteLength = atol(row[9]);
    }
    else
    {
      byteLength = 0;
    }
    if(fileId > 0 && annotationStart > 0 && annotationStop > 0)
    {
        fillDataHDHV(minimumHDInfo, fid, fileId, offset, gbBlockBpSpan, gbBlockBpStep, gbBlockScale, gbBlockLowLimit, numRecords, annotationStart, annotationStop, byteLength);
        addHDAnnotationToPixelMap(pixelValueForHDT, pixelExtras, pixelNegativeValueForHDT, pixelNegativeExtras, fd, fileSize, localTrack->style);
    }
    numberOfRecordProcessed++;
  }
  guint8 windowingMethod = defaultHighDensData.gbTrackWindowingMethod;
  // if drawing bi directional bar chart, fill up the 'up' and 'down' arrays
  if(numberOfRecords > 0 && (strcasecmp(localTrack->style, BIDIRECTIONALLOCALHISTOGRAMLARGE) == 0 || strcasecmp(localTrack->style, BIDIRECTIONALGLOBALHISTOGRAMLARGE) == 0))
  {
    if(strcasecmp(partitioningReq, "false") == 0)
    {
      // for AVG
      if(windowingMethod == 0)
      {
        for(i = 0; i < (canvasWidthGlobalForHDTrack + 2); i ++){
          if((gdouble)(tempPixelArray[i] / tempExtraValues[i]) > yInt)
          {
            pixelValueForHDT[i] = tempPixelArray[i];
            pixelExtras[i] = tempExtraValues[i];
          }
          else if((gdouble)(tempPixelArray[i] / tempExtraValues[i]) < yInt)
          {
            pixelNegativeValueForHDT[i] = tempPixelArray[i];
            pixelNegativeExtras[i] = tempExtraValues[i];
          }
        }  
      }
      // for MAX and MIN
      else if(windowingMethod == 1 || windowingMethod == 2) 
      {
        for(i = 0; i< (canvasWidthGlobalForHDTrack + 2); i++)
        {
          if(tempPixelArray[i] > yInt)
          {
            pixelValueForHDT[i] = tempPixelArray[i];
          }
          if(tempNegPixelArray[i] < yInt)
          {
            pixelNegativeValueForHDT[i] = tempNegPixelArray[i]; 
          }
        }
      }  
    }
  }
  mysql_free_result(sqlresult);
  return numberOfRecordProcessed;
}
