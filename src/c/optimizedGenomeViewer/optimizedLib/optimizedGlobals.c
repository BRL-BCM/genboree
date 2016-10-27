#include "optimizedGB.h"
#include "optimizedFunctions.h"
#include "map_reader.h"

static char **ftypeIdsStatementByDatabaseId = NULL;
static int *arrayUploadIds = NULL;
static int *arrayDBWithTrackPermissions = NULL;
static long *arrayRecordsInfidText = NULL;
static char **arrayOrderedTracks = NULL;
static int numberOfItemsInArrayOrderedTracks = 0;
static char **databaseNames = NULL;
static int numberOfDatabases = 0;
static long refSeqId = 0;
static int genboreeGroupId = 0;
static int numberOfTracks = 0;
static myTrack *trackList = NULL;
static myTrack *emptyTrackList = NULL;
static char **featureQueries = NULL;
static int groupCounter = 0;
static int initialGroupId = 0;
static int finalGroupId = 0;
static char *entrypointName = NULL;
static int *entrypointId = NULL;
static long long *entrypointLength = NULL;
static int universalCounter = 0;
static int PNG = 0;
static int preserveDefaultTrackOrder = 0;
static char **inStatements = NULL;
static int maxOrder = 0;
static int spaceBetweenTracks = SMALL_TRACK_SEP;
static long myUserId = 0;
static int startFirstTrack = 0;
static int trackWidth = 0;
static gdouble *bufferToReadValueOfAPixel = NULL;
static int isBufferToReadValueOfAPixelInitialized = 0;
static int displayEmptyTracks = 0;
static int displayTrackDescriptions = 0;
static int totalImageHeight = 0;
static int numberOfAllFeatures = 0;
static int useMargins = 0;
static char specialTrack[] = "scoreBased_draw";
static time_t globalStartTime;
static int myDebug = 0;
static MYSQL *genboreeConnection = NULL;
static MYSQL genboreeMysql;
static MYSQL *specificConnection = NULL;
static MYSQL specificMysql;
static char *myDatabaseToUse = NULL;
static char *gifFileName = NULL;
static char *imageMapFileName = NULL;
static FILE *mapPointerFile;
static int groupOrderUsingXml = 0;
static int printXML = 0;
static long offset = 0;
static char *genomicFileName = NULL;
static char *genboreeUserName = NULL;
static char *genboreePassword = NULL;
static char *dbHost = NULL;
static char *browserNumberStaticLinks = NULL;
static int numberStaticLinks = 10;
static PROPERTIES *properties = NULL;
static char encodeStr[] = "@*/+";
static char encodeURIStr[] = "~!@#$&*()=:/,;?+'";
static char encodeURIComponentStr[] = "~!*()'";
static char *encodeSchema = NULL;
static char *tags[] = {
  "$stripNameLong=0",           /* 0 */
  "$stripName=1",               /* 1 */
  "$name=2",                    /* 2 */
  "$class=3",                   /* 3 */
  "$type=4",                    /* 4 */
  "$subtype=5",                 /* 5 */
  "$reference=6",               /* 6 */
  "$start=7",                   /* 7 */
  "$end=8",                     /* 8 */
  "$stop=9",                    /* 9 */
  "$strand=10",                 /* 10 */
  "$phase=11",                  /* 11 */
  "$score=12",                  /* 12 */
  "$tstart=13",                 /* 13 */
  "$tend=14",                   /* 14 */
  "$targetstart=15",            /* 15 */
  "$targetstop=16",             /* 16 */
  "$entryPoint=17",             /* 17 */
  "$from=18",                   /* 18 */
  "$to=19",                     /* 19 */
  "${=20",                      /* 20 */
  "$comments=21",               /* 21 */
  "$sequence=22",               /* 22 */
  "$entrypoint=23",             /* 23 */
  "$qstart=24",                 /* 24 */
  "$qstop=25",                  /* 25 */
  "$genboreeAnnotId=32",        /* 32 */
  "$genboreeAnnotGroupId=33",   /* 33 */
  "$genboreeDbId=34",           /* 34 */
  "$genboreeRefSeqId=35",       /* 35 */
  "$genboreeUserId=36",         /* 36 */
  "$genboreeGroupId=37",        /* 37 */
  ""
};

char **getTags(void)
{
  return tags;
}

char *fieldValue(myAnnotations * currentAnnotation, char *substring)
{
  GHashTable *myTagHash = getTagsHash();
  int *myTag = NULL;
  int caseNumber = -1;
  char *groupName = currentAnnotation->parentGroup->groupName;
  char *groupClass = currentAnnotation->parentGroup->groupClass;
  char *trackName = currentAnnotation->parentGroup->parentTrack->trackName;
  char *firstString = NULL;
  char tempString[255] = "";
  char *field = NULL;
  char *value = NULL;
  char *pattern = NULL;
  char openBracket = '{';
  char quotations = '"';
  char *valuePair = NULL;
  int isDatabaseUsingVP = -20;
  int hasRegex = 0;

  myTag = (int *)g_hash_table_lookup(myTagHash, substring);

  if(!myTag)
    caseNumber = -20;
  else
    caseNumber = *myTag;

  if(caseNumber == -20)
  {
      if(substring[1] == openBracket)
      {
          if(substring[2] == quotations)
          {
              hasRegex = vpHasRegEx(substring);
              if(hasRegex < 1)
                caseNumber = 30;
              else
                caseNumber = 31;
          }
          else
            caseNumber = 20;
      }
  }

  switch (caseNumber)
  {
    case 0:
    case 1:
      firstString = returnStripedName(groupName);
      break;
    case 2:
      if(groupName)
        firstString = strdup(groupName);
      break;
    case 3:
      if(groupClass)
        firstString = strdup(groupClass);
      break;
    case 4:
      firstString = returnType(trackName, 0);
      break;
    case 5:
      firstString = returnType(trackName, 1);
      break;
    case 6:
    case 17:
    case 23:
      if(getEntrypointName())
        firstString = strdup(getEntrypointName());
      break;
    case 7:
      sprintf(tempString, "%ld", currentAnnotation->start);
      if(strlen(tempString))
        firstString = strdup(tempString);
      break;
    case 8:
    case 9:
      sprintf(tempString, "%ld", currentAnnotation->end);
      if(strlen(tempString))
        firstString = strdup(tempString);
      break;
    case 10:
      sprintf(tempString, "%c", currentAnnotation->orientation);
      if(strlen(tempString))
        firstString = strdup(tempString);
      break;
    case 11:
      sprintf(tempString, "%d", currentAnnotation->phase);
      if(strlen(tempString))
        firstString = strdup(tempString);
      break;
    case 12:
      sprintf(tempString, "%f", currentAnnotation->score);
      if(strlen(tempString))
        firstString = strdup(tempString);
      break;
    case 13:
    case 15:
    case 24:
      sprintf(tempString, "%ld", currentAnnotation->tstart);
      if(strlen(tempString))
        firstString = strdup(tempString);
      break;
    case 14:
    case 16:
    case 25:
      sprintf(tempString, "%ld", currentAnnotation->tend);
      if(strlen(tempString))
        firstString = strdup(tempString);
      break;
    case 18:
      sprintf(tempString, "%ld", currentAnnotation->start);
      if(strlen(tempString))
        firstString = strdup(tempString);
      break;
    case 19:
      sprintf(tempString, "%ld", currentAnnotation->end);
      if(strlen(tempString))
        firstString = strdup(tempString);
      break;
    case 20:
      field = returnField(substring);
      pattern = returnRegex(substring);
      if(field != NULL && strlen(field) > 2 && field[0] == '$')
      {
          value = fieldValue(currentAnnotation, field);
          free(field);
          field = NULL;
          field = value;
      }
      firstString = returnResultExtractingField(currentAnnotation, pattern, field);
      free(field);
      field = NULL;
      free(pattern);
      pattern = NULL;
      break;
    case 21:
      firstString =
          getTextFromFid(currentAnnotation->uploadId, currentAnnotation->id, currentAnnotation->ftypeid, 't',
                         MAXLENGTHOFTEMPSTRING);
      break;
    case 22:
      firstString =
          getTextFromFid(currentAnnotation->uploadId, currentAnnotation->id, currentAnnotation->ftypeid, 's',
                         MAXLENGTHOFTEMPSTRING);
      break;
    case 30:
      isDatabaseUsingVP = isDatabaseNewFormat(currentAnnotation->uploadId);
      if(isDatabaseUsingVP != 1)
        return NULL;

      field = cleanUpVP(substring);

      firstString =
          getVPValueFromFid(currentAnnotation->uploadId, currentAnnotation->id, currentAnnotation->ftypeid, field,
                            MAXLENGTHOFTEMPSTRING);
      free(field);
      field = NULL;
      break;
    case 31:
      isDatabaseUsingVP = isDatabaseNewFormat(currentAnnotation->uploadId);
      if(isDatabaseUsingVP != 1)
        return NULL;
      field = extractNameFromField(substring);
      pattern = extractPatternFromField(substring);

      valuePair =
          getVPValueFromFid(currentAnnotation->uploadId, currentAnnotation->id, currentAnnotation->ftypeid, field,
                            MAXLENGTHOFTEMPSTRING);
      if(pattern != NULL && strlen(pattern) > 0)
      {
          firstString = extractInfoFromValuePairValue(pattern, valuePair);
          free(valuePair);
          valuePair = NULL;
      }
      else
      {
          firstString = valuePair;
      }
      free(field);
      field = NULL;
      free(pattern);
      pattern = NULL;

      break;
    case 32:
      sprintf(tempString, "%ld", currentAnnotation->id);
      if(strlen(tempString))
        firstString = strdup(tempString);
      break;
    case 33:
      sprintf(tempString, "%d", currentAnnotation->parentGroup->groupId);
      if(strlen(tempString))
        firstString = strdup(tempString);
      break;
    case 34:
      sprintf(tempString, "%d", currentAnnotation->uploadId);
      if(strlen(tempString))
        firstString = strdup(tempString);
      break;
    case 35:
      sprintf(tempString, "%ld", getRefSeqId());
      if(strlen(tempString))
        firstString = strdup(tempString);
      break;
    case 36:
      sprintf(tempString, "%ld", getMyUserId());
      if(strlen(tempString))
        firstString = strdup(tempString);
      break;
    case 37:
      sprintf(tempString, "%d", getGenboreeGroupId());
      if(strlen(tempString))
        firstString = strdup(tempString);
      break;

    default:
      firstString = NULL;
      break;
  }

  return firstString;
}

char *extractPropertyName(char *line)
{
  int sizeLine = strlen(line);
  int ii = 0;
  int end = 0;
  char *newName = NULL;

  for (ii = 0; ii < sizeLine; ii++)
  {
      if(line[ii] == '=' || line[ii] == ':')
      {
          end = ii;
      }
  }

  newName = getstring(ii + 5);
  strncpy(newName, line, end);

  return newName;
}

char *extractPropertyValue(char *line)
{
  int sizeLine = strlen(line);
  int ii = 0;
  int found = 0;
  char *temporaryString = NULL;

  for (ii = 0; ii < sizeLine; ii++)
  {
      if(found)
      {
          temporaryString = line + ii;
          break;
      }

      if(line[ii] == '=' || line[ii] == ':')
        found = 1;
  }

  return strdup(temporaryString);
}

void destroy_double_pointer(char **ptr, int max_hits)
{
  int ii;
  if(ptr && max_hits)
  {
      for (ii = 0; ii < max_hits; ii++)
      {
          if(ptr[ii] != NULL && strlen(ptr[ii]) > 0)
          {
              free(ptr[ii]);
              ptr[ii] = NULL;
          }
      }
      if(ptr)
      {
          free(ptr);
          ptr = NULL;
      }
  }
}

void destroyProperties(void)
{
  if(properties)
  {
      destroy_double_pointer(properties->name, (properties->numberOfProps));
      destroy_double_pointer(properties->value, (properties->numberOfProps));

      free(properties);
      properties = NULL;
  }
  return;
}

int loadPreferencesFile(char *fileName)
{
  char line[25555] = { "\0" };
  FILE *original_file = NULL;
  int ii = 0;
  int numberOfLines = 0;

  original_file = fopen(fileName, "r");
  if(original_file == NULL)
  {
      return 0;
  }

  while (!feof(original_file))
  {
      if(fgets(line, 20000, original_file) != NULL)
      {
          numberOfLines++;
      }
  }

  if(!numberOfLines)
  {
      return 0;
  }
  else
  {
      rewind(original_file);
  }

  if((properties = (PROPERTIES *) malloc(sizeof(PROPERTIES))) == NULL)
  {
      perror("problems creating properties");
      return 0;
  }

  properties->numberOfProps = numberOfLines;

  if((properties->name = (char **)malloc((properties->numberOfProps + 1) * sizeof(char *))) == NULL)
  {
      perror("problems with properties->name");
      return 0;
  }

  if((properties->value = (char **)malloc((properties->numberOfProps + 1) * sizeof(char *))) == NULL)
  {
      perror("problems with properties->name");
      return 0;
  }

  ii = 0;
  while (!feof(original_file))  /* Reading the text file until end of file */
  {
      if(fgets(line, 20000, original_file) != NULL)
      {
          line[strlen(line) - 1] = '\0';
          if(line[0] == ' ')
          {
              char *tempLine = strdup(line);
              tempLine = g_strchug(tempLine);
              memset(line, '\0', 25555);
              strcpy(line, tempLine);
              free(tempLine);
              tempLine = NULL;
          }
          if(line != NULL && strlen(line) > 0 && line[0] != '#')
          {
              properties->name[ii] = extractPropertyName(line);
              properties->value[ii] = extractPropertyValue(line);
              memset(line, '\0', 25555);
              ii++;
          }
      }
  }

  properties->numberOfProps = ii;
  fclose(original_file);
  return 1;
}

int returnKeyValue(char *preferenceName)
{
  int equalStrings = -23;
  int ii = 0;
  if(properties)
  {
      for (ii = 0; ii < properties->numberOfProps; ii++)
      {
          if(!properties->name[ii])
          {
              continue;
          }
          equalStrings = strcmp(preferenceName, properties->name[ii]);
          if(equalStrings == 0)
          {
              return ii;
          }
      }
  }

  return -1;
}

char *getDbHost(void)
{
  if(!dbHost)
    setGenboreeDbNameUserNameAndPassword();

  return dbHost;
}

void setDbHost(char *databaseName)
{
  dbHost = databaseName;
}

void deleteDbHost(void)
{
  free(dbHost);
  dbHost = NULL;
}

void setNumberStaticLinks(char *staticLinks)
{
  if(staticLinks != NULL)
  {
      browserNumberStaticLinks = staticLinks;
      numberStaticLinks = atoi(staticLinks);
  }
}

int getNumberStaticLinks(void)
{
  return numberStaticLinks;
}

void setGenboreeUserName(char *userName)
{
  genboreeUserName = userName;
}

void setGenboreePassword(char *password)
{
  genboreePassword = password;
}

void deleteGenboreeUserNameAndPassWord(void)
{
  free(genboreeUserName);
  genboreeUserName = NULL;
  free(genboreePassword);
  genboreePassword = NULL;
}

void setGenboreeDbNameUserNameAndPassword(void)
{
  char *tempUserName = NULL;
  char *tempPassword = NULL;
  char *tempDbHost = NULL;
  char *tempNumberStaticLinks = NULL;
  int key = -1;
  char *bufferSizeString = NULL;
  long bufferSizeLong = 0;

  if(!loadPreferencesFile(DATABASEPREF))
  {
      fprintf(stderr, "file %s is not existent, empty or using the wrong format\n", DATABASEPREF);
      fflush(stderr);
      setGenboreeUserName("dvirk");
      setGenboreePassword("dvirk");
      setDbHost("localhost");
      return;
  }

  key = returnKeyValue("userName");
  if(key > -1)
    tempUserName = properties->value[key];
  else
  {
      fprintf(stderr, "Error userName not defined in %s\n", DATABASEPREF);
      fflush(stderr);
  }
  key = -1;
  key = returnKeyValue("passwd");
  if(key > -1)
    tempPassword = properties->value[key];
  else
  {
      fprintf(stderr, "Error passwd not defined in %s\n", DATABASEPREF);
      fflush(stderr);
  }
  key = -1;
  key = returnKeyValue("dbHost");
  if(key > -1)
    tempDbHost = properties->value[key];
  else
  {
      fprintf(stderr, "Error dbHost not defined in %s\n", DATABASEPREF);
      fflush(stderr);
  }
  key = -1;
  key = returnKeyValue("browserNumberStaticLinks");
  if(key > -1)
    tempNumberStaticLinks = properties->value[key];

  if(tempNumberStaticLinks)
    setNumberStaticLinks(tempNumberStaticLinks);

  if(tempUserName && tempPassword && tempDbHost)
  {
      setGenboreeUserName(strdup(tempUserName));
      setGenboreePassword(strdup(tempPassword));
      setDbHost(strdup(tempDbHost));
  }
  else
  {
      setGenboreeUserName(strdup("dvirk"));
      setGenboreePassword(strdup("dvirk"));
      setDbHost(strdup("localhost"));
  }
  key = -1;
  key = returnKeyValue("browserBufferSize");
  if(key > -1)
  {
      bufferSizeString = properties->value[key];
  }

  if(bufferSizeString != NULL && strlen(bufferSizeString) > 0)
  {
      bufferSizeLong = atol(bufferSizeString);
      if(bufferSizeLong > getStaticBufferSize())
      {
          setStaticBufferSize(bufferSizeLong);
      }
  }
  destroyProperties();

  return;
}

char *getGenboreeUserName(void)
{
  if(!genboreeUserName)
  {
      setGenboreeDbNameUserNameAndPassword();
  }

  return genboreeUserName;
}

char *getGenboreePassword(void)
{
  if(!genboreePassword)
  {
      setGenboreeDbNameUserNameAndPassword();
  }

  return genboreePassword;
}

char *getGenomicFileName(void)
{
  return genomicFileName;
}

void setGenomicFileName(void)
{
  setGenomicFileNameWithExtension(NULL);
}

void setGenomicFileNameWithExtension(char *extension)
{
  char theQuery[] =
      "select rs.seqFileName from ridSequence as rs, fref, rid2ridSeqId where fref.rid = rid2ridSeqId.rid and rs.ridSeqId = rid2ridSeqId.ridSeqId and fref.refname";
  char secondQuery[] = "SELECT fvalue from fmeta where fname = 'RID_SEQUENCE_DIR'";
  char thirdQuery[] = "SELECT r.offset FROM rid2ridSeqId as r, fref as f  WHERE r.rid = f.rid  AND f.refname";
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection = NULL;
  MYSQL mysql;
  char *seqFileName = NULL;
  int extSize = 0;
  int lengthSeqFileName = 0;
  char *pathName = NULL;
  int lengthPathName = 0;
  char *fullName = NULL;
  int sizeFullName = 0;
  MYSQL_RES *sqlresult = NULL;
  MYSQL_ROW row = NULL;

  resetLocalConnection(getDatabaseFromId(0));
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);

  if(extension != NULL)
  {
      extSize = strlen(extension);
  }

  memset(sqlbuff, '\0', 2555);
  sprintf(sqlbuff, "%s = '%s'", theQuery, getEntrypointName());

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      fprintf(stderr, "Error querying the searchConfig table in function setGenomicFileName.\n");
      fprintf(stderr, "the offending query is %s = '%s'\n", theQuery, getEntrypointName());
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return;
  }
  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult))
  {
      if((row = mysql_fetch_row(sqlresult)))
      {
          if(row[0] != NULL && strlen(row[0]) > 1)
          {
              seqFileName = strdup(row[0]);
              lengthSeqFileName = strlen(seqFileName);
          }
          else
          {
              return;
          }
      }
  }
  mysql_free_result(sqlresult);

  memset(sqlbuff, '\0', 2555);
  sprintf(sqlbuff, "%s", secondQuery);

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
          pathName = strdup(row[0]);
          lengthPathName = strlen(pathName);
      }
  }

  mysql_free_result(sqlresult);

  if((lengthSeqFileName + lengthPathName) <= 1)
  {
      return;
  }

  sizeFullName = lengthSeqFileName + lengthPathName + extSize + 5;

  fullName = getstring(sizeFullName);
  sprintf(fullName, "%s/%s", pathName, seqFileName);
  if(extension != NULL)
  {
      sprintf(fullName, "%s.%s", fullName, extension);
  }

  genomicFileName = fullName;

  free(pathName);
  pathName = NULL;
  free(seqFileName);
  seqFileName = NULL;

  memset(sqlbuff, '\0', 2555);
  sprintf(sqlbuff, "%s = '%s'", thirdQuery, getEntrypointName());

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      fprintf(stderr, "Error querying the searchConfig table in function setGenomicFileName 3rd query.\n");
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return;
  }
  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult))
  {
      if((row = mysql_fetch_row(sqlresult)))
      {
          offset = atol(row[0]);
      }
  }

  mysql_free_result(sqlresult);

  return;
}

long getGenomicOffset(void)
{
  return offset;
}

void destroyBufferToReadValueOfAPixel(void)
{
  free(bufferToReadValueOfAPixel);
  bufferToReadValueOfAPixel = NULL;
}

void setBufferToReadValueOfAPixel(gdouble lowLimit)
{
  long bpPerPixelLong = (long)ceil(getBasesPerPixel() + 1.0);
  int d = 0;

  if(isBufferToReadValueOfAPixelInitialized == 0)
  {
      bufferToReadValueOfAPixel = (gdouble *) malloc(bpPerPixelLong * sizeof(gdouble));
      for (d = 0; d < bpPerPixelLong; d++)
      {
          bufferToReadValueOfAPixel[d] = lowLimit - 1.0;
      }
      isBufferToReadValueOfAPixelInitialized = 1;
  }
  else
  {
      for (d = 0; d < bpPerPixelLong; d++)
      {
          bufferToReadValueOfAPixel[d] = lowLimit - 1.0;
      }
  }
}

gdouble *getBufferToReadValueOfAPixel(gdouble lowLimit)
{
  setBufferToReadValueOfAPixel(lowLimit);
  return bufferToReadValueOfAPixel;
}

gdouble *getCurrentBufferToReadValueOfAPixel(void)
{
  return bufferToReadValueOfAPixel;
}

int getPrintXML(void)
{
  return printXML;
}

void setPrintXML(int yesNo)
{
  printXML = yesNo;
}

int getUseMargins(void)
{
  return useMargins;
}

void setUseMargins(int yesNo)
{
  useMargins = yesNo;
}

void setGroupOrderUsingXml(int yesNo)
{
  groupOrderUsingXml = yesNo;
}

int getGroupOrderUsingXml(void)
{
  return groupOrderUsingXml;
}

void setMapPointerFile(FILE * thisPointer)
{
  mapPointerFile = thisPointer;
}

FILE *getMapPointerFile(void)
{
  return mapPointerFile;
}

char *getMapFileName(void)
{
  return imageMapFileName;
}

void setMapFileName(char *theIMAPName)
{
  imageMapFileName = theIMAPName;
}

void destroyIMAPName(void)
{
  free(imageMapFileName);
  imageMapFileName = NULL;
}

char *getGifFileName(void)
{
  return gifFileName;
}

void setGifFileName(char *theGifName)
{
  gifFileName = theGifName;
}

void destroyGifName(void)
{
  free(gifFileName);
  gifFileName = NULL;
}

char *getMyDatabaseToUse(void)
{
  return myDatabaseToUse;
}

void setMyDatabaseToUse(char *theDatabaseName)
{
  myDatabaseToUse = theDatabaseName;
}

int resetLocalConnection(char *theDatabaseToUse)
{
  GHashTable *database2HostHash = getDatabase2HostHash();
  char *hostName = (char *)g_hash_table_lookup(database2HostHash, theDatabaseToUse);

  if(!hostName)
  {
    fprintf(stderr,
            "\nDATABASE %s is not in table database2host please Add the database to database2host and try again\n",
            theDatabaseToUse);
    fflush(stderr);
    exit(112);

  }
  closeLocalConnection(2);
  if(mysql_init(&specificMysql) == NULL)
  {
    fprintf(stderr, "Could not initialize MySQL\n");
    fflush(stderr);
    exit(112);
  }
  else
  {
    int optionsError;
    optionsError = mysql_options(&specificMysql, MYSQL_OPT_COMPRESS, 0);
    if(optionsError != 0){
      fprintf(stderr, "the return value from mysql_options() in resetLocalConnection: %d\n", optionsError);
    }
  }

  if((specificConnection =
    mysql_real_connect(&specificMysql, hostName, getGenboreeUserName(), getGenboreePassword(), theDatabaseToUse, 0, 0,
                         0)) == NULL)
  {
    fprintf(stderr, "Could not connect to MySQL Server in function resetLocalConnection with database = %s\n",
            theDatabaseToUse);
    fprintf(stderr, mysql_error(&specificMysql));
    // try to reconnect if the connection has gone away
    int connCount = 0;
    // try to reconnect
    while(connCount < MAXRECONNECTATTEMPTS){
      connCount ++;
      fprintf(stderr, "Reconnection attempt no = %d in resetLocalConnection()\n", (connCount));
      int mysql_optionsError;
      mysql_optionsError = mysql_options(&specificMysql, MYSQL_OPT_COMPRESS, 0);
      if(mysql_optionsError != 0){
        fprintf(stderr, "the return value from mysql_options(): %d in resetLocalConnection()", mysql_optionsError);
      }
      if((specificConnection = mysql_real_connect(&specificMysql, hostName, getGenboreeUserName(), getGenboreePassword(), theDatabaseToUse, 0, 0,
                       0)) == NULL){
        sleep(2 * connCount);
        continue;
      }
      // got the connection, break out of loop
      else{
        break;
      }
    }
    if(connCount >= MAXRECONNECTATTEMPTS){
      fprintf(stderr, "Could not reconnect with database = %s even after trying %d times in resetLocalConnection(). Qutting...",
            theDatabaseToUse, MAXRECONNECTATTEMPTS);
      fflush(stderr);
      exit(112);
    }
  }
  return 1;
}

int startLocalConnection(int type)
{
  char *theDatabaseToUse = getMyDatabaseToUse();
  GHashTable *database2HostHash = getDatabase2HostHash();
  char *hostName;

  if(type == 1)
  {
    if(mysql_init(&genboreeMysql) == NULL)
    {
      fprintf(stderr, "Could not initialize MySQL\n");
      fflush(stderr);
      return 0;
    }
    else
    {
      int optionsError = mysql_options(&genboreeMysql, MYSQL_OPT_COMPRESS, 0);
      if(optionsError != 0){
        fprintf(stderr, "the return value from mysql_options(): %d in function startLocalConnection()\n", optionsError);
      }
    }

    if((genboreeConnection =
      mysql_real_connect(&genboreeMysql, getDbHost(), getGenboreeUserName(), getGenboreePassword(), "genboree", 0,
                           0, 0)) == NULL)
    {
      fprintf(stderr,
              "Could not connect to MySQL Server in function startLocalConnection type of connection = %d\n", type);
      fprintf(stderr, mysql_error(&genboreeMysql));
      // try to reconnect
      int connCount = 0;
      while(connCount < MAXRECONNECTATTEMPTS){
        connCount ++;
        fprintf(stderr, "Reconnection attempt no = %d in startLocalConnection()\n", (connCount));
        int mysql_optionsError;
        mysql_optionsError = mysql_options(&genboreeMysql, MYSQL_OPT_COMPRESS, 0);
        if(mysql_optionsError != 0){
          fprintf(stderr, "the return value from mysql_options(): %d in startLocalConnection()\n", mysql_optionsError);
        }
        if((genboreeConnection = mysql_real_connect(&genboreeMysql, getDbHost(), getGenboreeUserName(), getGenboreePassword(), "genboree", 0, 0,
                         0)) == NULL){
          sleep(2 * connCount);
          continue;
        }
        // got the connection, break out of loop
        else{
          break;
        }
      }
      if(connCount >= MAXRECONNECTATTEMPTS){
        fprintf(stderr, "Could not reconnect with database = %s even after trying %d times in startLocalConnection(). Qutting...",
              "genboree", MAXRECONNECTATTEMPTS);
        fflush(stderr);
      }
      return 0;
    }
  }
  else
  {
    if(mysql_init(&specificMysql) == NULL)
    {
      fprintf(stderr, "Could not initialize MySQL\n");
      fflush(stderr);
      return 0;
    }
    else
    {
      int optionsError = mysql_options(&specificMysql, MYSQL_OPT_COMPRESS, 0);
      if(optionsError != 0){
        fprintf(stderr, "the return value from mysql_options(): %d\n", optionsError);
      }
    }
    hostName = (char *)g_hash_table_lookup(database2HostHash, theDatabaseToUse);
    if((specificConnection =
        mysql_real_connect(&specificMysql, hostName, getGenboreeUserName(), getGenboreePassword(), theDatabaseToUse,
                           0, 0, 0)) == NULL)
    {
      fprintf(stderr, "Could not connect to MySQL Server in function startLocalConnection databaseName  = %s\n",
              theDatabaseToUse);
      fprintf(stderr, mysql_error(&specificMysql));
      int connCount = 0;
      // try to reconnect
      while(connCount < MAXRECONNECTATTEMPTS){
        connCount ++;
        fprintf(stderr, "Reconnection attempt no = %d in startLocalConnection()\n", (connCount));
        int mysql_optionsError;
        mysql_optionsError = mysql_options(&specificMysql, MYSQL_OPT_COMPRESS, 0);
        if(mysql_optionsError != 0){
          fprintf(stderr, "the return value from mysql_options(): %d in startLocalConnection()\n", mysql_optionsError);
        }
        if((specificConnection = mysql_real_connect(&specificMysql, hostName, getGenboreeUserName(), getGenboreePassword(), theDatabaseToUse, 0, 0,
                         0)) == NULL){
          sleep(2 * connCount);
          continue;
        }
        // got the connection, break out of loop
        else{
          break;
        }
      }
      if(connCount >= MAXRECONNECTATTEMPTS){
        fprintf(stderr, "Could not reconnect with database = %s even after trying %d times in startLocalConnection(). Qutting...",
              theDatabaseToUse, MAXRECONNECTATTEMPTS);
        fflush(stderr);
      }
      return 0;
    }
  }

  return 1;
}

int closeLocalConnection(int type)
{
  if(type == 1)
    mysql_close(genboreeConnection);
  else
    mysql_close(specificConnection);

  return 1;
}

MYSQL *returnLocalConnection(int type)
{
  if(type == 1)
    return genboreeConnection;
  else
    return specificConnection;
}

MYSQL returnMyMYSQL(int type)
{
  if(type == 1)
    return genboreeMysql;
  else
    return specificMysql;
}

void setMyDebug(int yesno)
{
  myDebug = yesno;
}

int getMyDebug(void)
{
  return myDebug;
}

void setGlobalStartTime(time_t theTime)
{
  globalStartTime = theTime;
}

time_t getGlobalStartTime(void)
{
  return globalStartTime;
}

char *getEncodeSchema(void)
{
  return encodeSchema;
}

void setEncodeSchema(int encodePref)
{
  if(encodePref == 0)           // all special characters
    encodeSchema = NULL;
  else if(encodePref == 1)      //similar to JavaScript 1.0 encode method
    encodeSchema = encodeStr;
  else if(encodePref == 2)      //similar to JavaScript 1.5 encodeURI method
    encodeSchema = encodeURIStr;
  else if(encodePref == 3)      // similar to JavaScript 1.5 encodeURIComponent() method
    encodeSchema = encodeURIComponentStr;
  else
    encodeSchema = NULL;
}

char *getMySpecialTrack(void)
{
  return specialTrack;
}

void setNumberOfAllFeatures(int myNumber)
{
  numberOfAllFeatures = myNumber;
}

int getNumberOfAllFeatures(void)
{
  return numberOfAllFeatures;
}

int getTotalHeight(void)
{
  return totalImageHeight;
}

void setTotalHeight(int myHeight)
{
  totalImageHeight = myHeight;
}

void setDisplayEmptyTracks(int NoYes)
{
  displayEmptyTracks = NoYes;
}

void setDisplayTrackDescriptions(int NoYes)
{
  displayTrackDescriptions = NoYes;
}

int getDisplayTrackDescriptions(void)
{
  return displayTrackDescriptions;
}

int getDisplayEmptyTracks(void)
{
  return displayEmptyTracks;
}

void setTrackWidth(int width)
{
  trackWidth = width;
}

int getTrackWidth(void)
{
  return trackWidth;
}

void setStartFirstTrack(int start)
{
  startFirstTrack = start;
}

int getStartFirstTrack(void)
{
  return startFirstTrack;
}

long getMyUserId(void)
{
  return myUserId;
}

void setMyUserId(long theUserId)
{
  myUserId = theUserId;
}

void setSpaceBetweenTracks(int myWidth)
{
  spaceBetweenTracks = myWidth;
}

int getSpaceBetweenTracks(void)
{
  return spaceBetweenTracks;
}

void setPNG(int yesno)
{
  PNG = yesno;
}

int getPNG(void)
{
  return PNG;
}

void setPreserveDefaultTrackOrder(int yesno)
{
  preserveDefaultTrackOrder = yesno;
}

int getPreserveDefaultTrackOrder(void)
{
  return preserveDefaultTrackOrder;
}

void setMaxOrder(int maxNumber)
{
  maxOrder = maxNumber;
}

int getMaxOrder(void)
{
  return maxOrder;
}

char **getInStatements(void)
{
  return inStatements;
}

char *getSingleInStatement(int databaseId)
{
  if(inStatements[databaseId] != NULL)
    return inStatements[databaseId];
  else
    return NULL;
}

void setInStatements(void)
{
  int counter = 0;
  int numberGenboreeDatabases = getNumberDatabases();

  inStatements = (char **)calloc((numberGenboreeDatabases + 6), sizeof(char *));

  while (numberGenboreeDatabases > counter)
  {
      inStatements[counter] = createInStatement(counter);
//              if(inStatements[counter] != NULL)
//                      inStatements[counter] = createInStatement(counter);
      counter++;
  }
  return;

}

void increaseUniversalCounter(void)
{
  universalCounter++;
}

long long getEntrypointLength(int databaseId)
{
  return entrypointLength[databaseId];
}

char *getEntrypointName(void)
{
  return entrypointName;
}

void setEntryPointNameProperties(char *myEntrypointName)
{
  int counter = 0;
  int numberGenboreeDatabases = getNumberDatabases();
  int success = 0;
  int ii = 0;

  entrypointId = (int *)malloc((numberGenboreeDatabases) * sizeof(int));
  for (ii = 0; ii < numberGenboreeDatabases; ii++)
  {
      entrypointId[ii] = -1;
  }
  entrypointLength = (long long *)malloc((numberGenboreeDatabases) * sizeof(long long));
  for (ii = 0; ii < numberGenboreeDatabases; ii++)
  {
      entrypointLength[ii] = -1;
  }

  entrypointName = strdup(myEntrypointName);

  while (numberGenboreeDatabases > counter)
  {
      success = setEPProperties(myEntrypointName, counter);
      counter++;
  }
  return;
}

void setInitialGroupId(int myInitialId)
{
  initialGroupId = myInitialId;
}

int getInitialGroupId(void)
{
  return initialGroupId;
}

void setFinalGroupId(int myFinalId)
{
  finalGroupId = myFinalId;
}

int getFinalGroupId(void)
{
  return finalGroupId;
}

void setGroupCounter(int myCounter)
{
  groupCounter = myCounter;
}

int getGroupCounter(void)
{
  return groupCounter;
}

char **getFeatureQueries(void)
{
  return featureQueries;
}

void setFeatureQueries(void)
{
  int counter = 0;
  int numberGenboreeDatabases = getNumberDatabases();

  featureQueries = (char **)calloc((numberGenboreeDatabases + 2), sizeof(char *));

  while (numberGenboreeDatabases > counter)
  {
      featureQueries[counter] = generateFeatureQuery(counter);
      counter++;
  }
}

char *getFeatureQuery(int currentDatabase)
{
  int numberGenboreeDatabases = getNumberDatabases();

  if(currentDatabase >= numberGenboreeDatabases)
    return NULL;

  return featureQueries[currentDatabase];
}

int getEntrypointId(int databaseId)
{
  return entrypointId[databaseId];
}

int setEPProperties(char *entrypointName, int databaseId)
{
  char theQuery[] = "SELECT rid, rlength FROM fref WHERE refname";
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection = NULL;
  MYSQL mysql;
  MYSQL_RES *sqlresult = NULL;
  MYSQL_ROW row = NULL;
  ridName = entrypointName;
  sprintf(sqlbuff, "%s = '%s'", theQuery, entrypointName);

  resetLocalConnection(getDatabaseFromId(databaseId));
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      fprintf(stderr, "Error querying the fref database in function setEPProperties.\n");
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return 0;
  }
  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult))
  {
      if((row = mysql_fetch_row(sqlresult)))
      {
          entrypointId[databaseId] = atoi(row[0]);
          rid = entrypointId[databaseId];
          entrypointLength[databaseId] = atol(row[1]);
          mysql_free_result(sqlresult);
          return 1;
      }
  }

  mysql_free_result(sqlresult);
  return 0;
}

void setEmptyTrackList(myTrack * firstTrack)
{
  emptyTrackList = firstTrack;
}

myTrack *getEmptyTrackList(void)
{
  return emptyTrackList;
}

void setTrackList(myTrack * firstTrack)
{
  trackList = firstTrack;
}

myTrack *getTrackList(void)
{
  return trackList;
}

int getNumberOfTracks(void)
{
  return numberOfTracks;
}

void setNumberOfTracks(int myNumberOfTracks)
{
  numberOfTracks = myNumberOfTracks;
}

int getNumberDatabases(void)
{
  return numberOfDatabases;
}

void setNumberDatabases(int myNumber)
{
  numberOfDatabases = myNumber;
}

long getRefSeqId(void)
{
  return refSeqId;
}

void setRefSeqId(long myRefSeqId)
{
  refSeqId = myRefSeqId;
}

int getGenboreeGroupId(void)
{
  return genboreeGroupId;
}

void setGenboreeGroupId(int myGroupId)
{
  genboreeGroupId = myGroupId;
}

char **getDatabaseNames(void)
{
  return databaseNames;
}

void setDatabaseNames(long refSeqId)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection = returnLocalConnection(1);
  MYSQL mysql = returnMyMYSQL(1);
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  int ii = 0;
  char myQuery[] = "SELECT databaseName from upload WHERE uploadId =";
  int *myArrayUploadIds = NULL;
  int numberOfUploads = 0;

  myArrayUploadIds = getArrayUploadIds();

  if(!myArrayUploadIds)
  {
      setArrayUploadIds(refSeqId);
      myArrayUploadIds = getArrayUploadIds();
  }

  numberOfUploads = 0;
  while (myArrayUploadIds[numberOfUploads] != -1)
    numberOfUploads++;

  setNumberDatabases(numberOfUploads);

  if(!databaseNames)
    databaseNames = (char **)calloc((numberOfUploads + 6), sizeof(char *));

  ii = 0;
  while (myArrayUploadIds[ii] != -1)
  {
      sprintf(sqlbuff, "%s %d", myQuery, myArrayUploadIds[ii]);

      if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
      {
          fprintf(stderr, "Error querying the genboree database in getUploadIdArray.\n");
          fprintf(stderr, mysql_error(&mysql));
          fflush(stderr);
          return;
      }
      sqlresult = mysql_store_result(connection);

      // No records were found, so report an error and exit.
      if(mysql_num_rows(sqlresult) == 0)
      {
          fprintf(stderr, "No records found 316 for refseqId = %ld\n", refSeqId);
          fflush(stderr);
          return;
      }

      if((row = mysql_fetch_row(sqlresult)) != NULL)
        databaseNames[ii] = strdup(row[0]);

      mysql_free_result(sqlresult);
      ii++;
  }

  return;
}

char **getArrayOrderedTracks(void)
{
  return arrayOrderedTracks;
}

void setArrayOrderedTracks(char **myArray)
{
  arrayOrderedTracks = myArray;
}

void setNumberOfItemsInArrayOrderedTracks(int items)
{
  numberOfItemsInArrayOrderedTracks = items;
}

int getNumberOfItemsInArrayOrderedTracks(void)
{
  return numberOfItemsInArrayOrderedTracks;
}

void destroyArrayOrderedTracks(void)
{
  int ii = 0;
  char *ptr = NULL;
  int maxNumber = getNumberOfItemsInArrayOrderedTracks();

  if(arrayOrderedTracks == NULL)
    return;

  for (ii = 0; ii < maxNumber; ii++)
  {
      ptr = arrayOrderedTracks[ii];
      if(ptr != NULL)
      {
          free(ptr);
          ptr = NULL;
      }
  }
  free(arrayOrderedTracks);
  arrayOrderedTracks = NULL;
}

int *getArrayUploadIds(void)
{
  return arrayUploadIds;
}

void setArrayUploadIds(long refSeqId)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection = returnLocalConnection(1);
  MYSQL mysql = returnMyMYSQL(1);
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  int *uploadIds = NULL;
  int ii = 0;
  char beginingPart[] = "SELECT upload.uploadId";
  char beginingPartCount[] = "SELECT count(upload.uploadId) myCounter";
  char theFromPart[] =
      "FROM upload, refseq2upload, refseq  WHERE upload.uploadId = refseq2upload.uploadId AND refseq.refSeqId=refseq2upload.refSeqId AND";
  char headerPart[] = "refseq.databaseName = upload.databaseName AND";
  char remainingPart[] = "refseq.databaseName != upload.databaseName AND";
  char theEnd[] = "refseq2upload.refSeqId=";
  int numberOfRecords = 0;

  sprintf(sqlbuff, "%s %s %s %ld", beginingPartCount, theFromPart, theEnd, refSeqId);

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      fprintf(stderr, "Error querying the genboree database in getUploadIdArray.\n");
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return;
  }
  sqlresult = mysql_store_result(connection);

  // No records were found, so report an error and exit.
  if(mysql_num_rows(sqlresult) == 0)
  {
      fprintf(stderr, "No records found 196 for refseqId = %ld\n", refSeqId);
      fflush(stderr);
      return;
  }

  if((row = mysql_fetch_row(sqlresult)) != NULL)
  {

      numberOfRecords = atoi(row[0]) + 5;
      if((uploadIds = (int *)malloc((numberOfRecords) * sizeof(int))) == NULL)
      {
          perror("problems with values");
          return;
      }

  }
  mysql_free_result(sqlresult);

  for (ii = 0; ii < numberOfRecords; ii++)
  {
      uploadIds[ii] = -1;
  }

  sprintf(sqlbuff, "%s %s %s %s %ld", beginingPart, theFromPart, headerPart, theEnd, refSeqId);
  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      fprintf(stderr, "Error querying the genboree database in getUploadIdArray.\n");
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return;
  }
  sqlresult = mysql_store_result(connection);

  // No records were found, so report an error and exit.
  if(mysql_num_rows(sqlresult) == 0)
  {
      fprintf(stderr, "No records found 230 for refseqId = %ld\n", refSeqId);
      fflush(stderr);
      return;
  }
  if((row = mysql_fetch_row(sqlresult)) != NULL)
  {
      uploadIds[0] = atoi(row[0]);
  }

  mysql_free_result(sqlresult);

  sprintf(sqlbuff, "%s %s %s %s %ld", beginingPart, theFromPart, remainingPart, theEnd, refSeqId);
  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      fprintf(stderr, "Error querying the genboree database in getUploadIdArray.\n");
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return;
  }
  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult) > 0)
  {
      ii = 1;
      while ((row = mysql_fetch_row(sqlresult)) != NULL)
      {
          uploadIds[ii] = atoi(row[0]);
          ii++;
      }
  }

  mysql_free_result(sqlresult);

  arrayUploadIds = uploadIds;

  return;
}

// FROM HERE

char **getTypeIdsStatementByDatabaseId(void)
{
  return ftypeIdsStatementByDatabaseId;
}

void eraseFtypeIdsStatementByDatabaseId(void)
{
  int numberGenboreeDatabases = getNumberDatabases();
  int ii = 0;
  char *typeIdsInDb = NULL;

  for (ii = 0; ii < numberGenboreeDatabases; ii++)
  {
      typeIdsInDb = ftypeIdsStatementByDatabaseId[ii];
      free(typeIdsInDb);
      typeIdsInDb = NULL;
  }
  free(ftypeIdsStatementByDatabaseId);
  ftypeIdsStatementByDatabaseId = NULL;

}

// ERROR ERROR
void setTypeIdsStatementByDatabaseId(void)
{
  int numberGenboreeDatabases = getNumberDatabases();
  int *ftypeIds = NULL;
  int ii = 0;
  char *listOfFtypeIds = NULL;
  char myFtype[255] = "";
  int sizeCalculator = 5;
  int numberFtypes = 0;
  int bb = 0;

  if((ftypeIdsStatementByDatabaseId = (char **)malloc((numberGenboreeDatabases + 1) * sizeof(char *))) == NULL)
  {
      perror("problems with properties->name");
      return;
  }

  for (bb = 0; bb < numberGenboreeDatabases; bb++)
  {
      listOfFtypeIds = NULL;
      ftypeIds = fetchArrayOfFtypeIds(bb);

      numberFtypes = 0;
      sizeCalculator = 5;
      while (ftypeIds[numberFtypes] > 0)
      {
          memset(myFtype, '\0', 255);
          sprintf(myFtype, "%d, ", ftypeIds[numberFtypes]);
          sizeCalculator += strlen(myFtype);
          numberFtypes++;
      }

      listOfFtypeIds = getstring(sizeCalculator);
      strcat(listOfFtypeIds, "(");

      ii = 0;
      while (ftypeIds[ii] > 0)
      {
          memset(myFtype, '\0', 255);
          if(ii < numberFtypes)
          {
              sprintf(myFtype, "%d, ", ftypeIds[ii]);
          }
          else
          {
              sprintf(myFtype, "%d", ftypeIds[ii]);
          }

          strcat(listOfFtypeIds, myFtype);
          ii++;
      }

      strcat(listOfFtypeIds, "-1 )");
      ftypeIdsStatementByDatabaseId[bb] = listOfFtypeIds;

      free(ftypeIds);
      ftypeIds = NULL;
  }

}

char *getTrackBlackList(databaseId)
{
  int *tracksWithPermission = NULL;
  int t = 0;
  int trackId = -1;
  int haveAccessToTrack = 0;
  char blackList[555] = "";

  memset(blackList, '\0', 555);

  if(!hasDBTrackAccessControl(databaseId))
  {
      return strdup(blackList);
  }

  tracksWithPermission = whichFtypeIdsHaveAccessControl(databaseId);
  t = 0;
  strcat(blackList, " AND ftypeid not in (");
  while (tracksWithPermission[t] > 0)
  {
      trackId = tracksWithPermission[t];
      haveAccessToTrack = doIHaveAccessToTrack(databaseId, trackId);
      if(!haveAccessToTrack)
      {
          sprintf(blackList, "%s %d, ", blackList, trackId);
      }
      t++;
  }
  strcat(blackList, "-1 )");

  free(tracksWithPermission);
  tracksWithPermission = NULL;

  return strdup(blackList);
}

void setDBTrackAccessControl(void)
{
  int numberGenboreeDatabases = getNumberDatabases();
  int ii = 0;
  int numberOfRecords = numberGenboreeDatabases + 2;

  if((arrayDBWithTrackPermissions = (int *)malloc((numberOfRecords) * sizeof(int))) == NULL)
  {
      perror("problems with values");
      return;
  }

  for (ii = 0; ii < numberOfRecords; ii++)
  {
      arrayDBWithTrackPermissions[ii] = -1;
  }

  for (ii = 0; ii < numberGenboreeDatabases; ii++)
  {
      arrayDBWithTrackPermissions[ii] = hasDBTrackAccessControl(ii);
  }

}

int hasDBTrackAccessControl(int databaseId)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection = NULL;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  char counter[] = "select count(*) from ftypeAccess";
  int numberOfRecords = 0;

  resetLocalConnection(getDatabaseFromId(databaseId));
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);

  sprintf(sqlbuff, "%s", counter);

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      fprintf(stderr, "Error querying the main database %s in isTrackAccessControl .\n", getDatabaseFromId(databaseId));
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return 0;
  }
  sqlresult = mysql_store_result(connection);

  // No records were found, so report an error and exit.
  if(mysql_num_rows(sqlresult) == 0)
  {
      numberOfRecords = 0;
      return numberOfRecords;
  }

  if((row = mysql_fetch_row(sqlresult)) != NULL)
    numberOfRecords = atoi(row[0]);

  mysql_free_result(sqlresult);
  return numberOfRecords;
}

int *whichFtypeIdsHaveAccessControl(int databaseId)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection = NULL;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  int *ftypeIds = NULL;
  int ii = 0;
  char query[] = "select distinct(ftypeid) from ftypeAccess where permissionBits > 0";
  int numberOfRecords = 0;
  int numberOfFTypeIds = hasDBTrackAccessControl(databaseId);

  if(numberOfFTypeIds > 0)
  {
      numberOfRecords = numberOfFTypeIds + 5;
      if((ftypeIds = (int *)malloc((numberOfRecords) * sizeof(int))) == NULL)
      {
          perror("problems with values");
          return NULL;
      }

  }
  else
    return NULL;

  for (ii = 0; ii < numberOfRecords; ii++)
  {
      ftypeIds[ii] = -1;
  }

  resetLocalConnection(getDatabaseFromId(databaseId));
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);

  sprintf(sqlbuff, "%s", query);
  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      fprintf(stderr, "Error querying the genboree database in whichFtypeIdsHaveAccessControl.\n");
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return NULL;
  }
  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult) > 0)
  {
      ii = 0;
      while ((row = mysql_fetch_row(sqlresult)) != NULL)
      {
          ftypeIds[ii] = atoi(row[0]);
          ii++;
      }
  }

  mysql_free_result(sqlresult);

  return ftypeIds;
}

int doIHaveAccessToTrack(int databaseId, int ftypeId)
{
  long theUserId = getMyUserId();
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection = NULL;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  int permissionBits = 0;
  char query[] = "SELECT permissionBits FROM ftypeAccess WHERE userId = ";
  //2 and ftypeid = 6";

  resetLocalConnection(getDatabaseFromId(databaseId));
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);

  sprintf(sqlbuff, "%s%ld AND ftypeid = %d", query, theUserId, ftypeId);
  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      fprintf(stderr, "Error querying the genboree database in whichFtypeIdsHaveAccessControl.\n");
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return 0;
  }
  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult) > 0)
  {
      if((row = mysql_fetch_row(sqlresult)) != NULL)
      {
          permissionBits = atoi(row[0]);
//                      fprintf(stderr, "In database %d the ftypeId = %s\n",databaseId, row[0]);
      }
  }

  mysql_free_result(sqlresult);

  if(permissionBits & TRACKPERMISSION)
    return 1;
  else
    return 0;
}

// ERROR ERROR
int *fetchArrayOfFtypeIds(int databaseId)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection = NULL;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  int *ftypeIds = NULL;
  int ii = 0;
  char *blackList = getTrackBlackList(databaseId);
  char counter[] = "SELECT count(*) FROM ftype WHERE fsource NOT IN ('Chromosome', 'Sequence') ";
  //       char counter[] = "SELECT count(*) FROM ftypeCount WHERE ftypeid > 0 ";
  char query[] = "SELECT ftypeid FROM ftype WHERE fsource NOT IN ('Chromosome', 'Sequence') ";
//        char query[] = "SELECT ftypeid FROM ftypeCount WHERE ftypeid > 0 ";
  int numberOfRecords = 0;

  resetLocalConnection(getDatabaseFromId(databaseId));
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);

  sprintf(sqlbuff, "%s %s", counter, blackList);

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      fprintf(stderr, "Error querying the main database %s in fetchArrayOfFtypeIds using query %s.\n",
              getDatabaseFromId(databaseId), sqlbuff);
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return NULL;
  }
  sqlresult = mysql_store_result(connection);

  // No records were found, so report an error and exit.
  if(mysql_num_rows(sqlresult) == 0)
  {
      fprintf(stderr, "No records found 345 for ftypeid\n");
      fflush(stderr);
      return NULL;
  }

  if((row = mysql_fetch_row(sqlresult)) != NULL)
  {

      numberOfRecords = atoi(row[0]) + 5;
      if((ftypeIds = (int *)malloc((numberOfRecords) * sizeof(int))) == NULL)
      {
          perror("problems with values");
          return NULL;
      }

  }
  mysql_free_result(sqlresult);

  for (ii = 0; ii < numberOfRecords; ii++)
  {
      ftypeIds[ii] = -1;
  }

  sprintf(sqlbuff, "%s %s order by ftypeid", query, blackList);

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      fprintf(stderr, "Error querying the genboree database in fetchArrayOfFtypeIds.\n");
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return NULL;
  }
  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult) > 0)
  {
      ii = 0;
      while ((row = mysql_fetch_row(sqlresult)) != NULL)
      {
          ftypeIds[ii] = atoi(row[0]);
          ii++;
      }
  }

  free(blackList);
  blackList = NULL;
  mysql_free_result(sqlresult);

  return ftypeIds;

}

// UNTIL HERE HERE

long *getArrayRecordsInfidText(void)
{
  return arrayRecordsInfidText;
}

void setArrayRecordsInfidText(void)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection = NULL;
  MYSQL mysql;
  MYSQL_RES *sqlresult = NULL;
  MYSQL_ROW row = NULL;
  int counter = 0;
  int numberOfGenboreeDatabases = getNumberDatabases();
  int ii = 0;
  resetLocalConnection(getDatabaseFromId(0));
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);

  counter = 0;

  if((arrayRecordsInfidText = (long *)malloc((numberOfGenboreeDatabases + 5) * sizeof(long))) == NULL)
  {
      perror("problems with values");
      return;
  }

  for (ii = 0; ii < numberOfGenboreeDatabases + 5; ii++)
  {
      arrayRecordsInfidText[ii] = 0;
  }

  while (numberOfGenboreeDatabases > counter)
  {
      resetLocalConnection(getDatabaseFromId(counter));
      connection = returnLocalConnection(2);
      mysql = returnMyMYSQL(2);

      sprintf(sqlbuff, "SELECT count(*) from fidText");

      if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
      {
          counter++;
          continue;
      }
      sqlresult = mysql_store_result(connection);

      if(mysql_num_rows(sqlresult) == 0)
      {
          counter++;
          continue;
      }

      if((row = mysql_fetch_row(sqlresult)))
        arrayRecordsInfidText[counter] = atol(row[0]);

      mysql_free_result(sqlresult);

      counter++;
  }
  return;
}

void fillTrackListOfGroups(void)
{
  int ii = 0;
  int localInitialGroupId = 0;
  int localFinalGroupId = 0;
  char *myTrackName = NULL;
  int sizeGroupIds = 0;
  myTrack *ptrTrack = NULL;
  myGroup *currentGroup = NULL;
  GHashTable *groups2TrackHash = getGroups2TrackHash();
  GHashTable *trackName2trackObjHash = getTrackName2TrackHash();
  size_t myStructureSize = sizeof(groupStartingPoint);
  int (*compare_func) (const void *, const void *);
  int extraSize = 0;

  compare_func = &myCmpSP;

  ptrTrack = getTrackList();
  setGroupId2groupStartHash();

  localInitialGroupId = getInitialGroupId();
  localFinalGroupId = getFinalGroupId();
  sizeGroupIds = (localFinalGroupId - localInitialGroupId) + 2;

  for (ii = localInitialGroupId; ii <= localFinalGroupId; ii++)
  {
      currentGroup = returnGroupFromGroupId(ii);
      if(currentGroup)
      {
          myTrackName = (char *)g_hash_table_lookup(groups2TrackHash, &ii);
          ptrTrack = (myTrack *) g_hash_table_lookup(trackName2trackObjHash, myTrackName);
          currentGroup->parentTrack = ptrTrack;
          insertGroupStart(ii, currentGroup->groupStart);
          if(currentGroup && myTrackName && ptrTrack)
            ptrTrack->numberOfGroups++;
      }
  }

  ptrTrack = getTrackList();
  while (ptrTrack)
  {
      ptrTrack->listOfGroups = createListOfGroups(ptrTrack->numberOfGroups + 2);
      ptrTrack->numberOfGroups = 0;
      ptrTrack = ptrTrack->next;
  }

  for (ii = localInitialGroupId; ii <= localFinalGroupId; ii++)
  {
      currentGroup = returnGroupFromGroupId(ii);
      if(currentGroup == NULL)
      {
          continue;
      }
      myTrackName = (char *)g_hash_table_lookup(groups2TrackHash, &ii);
      ptrTrack = (myTrack *) g_hash_table_lookup(trackName2trackObjHash, myTrackName);

      if(currentGroup && myTrackName && ptrTrack)
      {
          ptrTrack->listOfGroups[ptrTrack->numberOfGroups].groupId = ii;
          ptrTrack->listOfGroups[ptrTrack->numberOfGroups].groupStart = getGroupStartForGroupId(ii);
          ptrTrack->numberOfGroups++;
      }
  }

  ptrTrack = getTrackList();
  while (ptrTrack)
  {
      qsort((void *)(ptrTrack->listOfGroups), (size_t) (ptrTrack->numberOfGroups), myStructureSize, compare_func);

      ptrTrack->groups = returnGroupFromGroupId(ptrTrack->listOfGroups[0].groupId);

      currentGroup = ptrTrack->groups;
      for (ii = 1; ii < ptrTrack->numberOfGroups; ii++)
      {
          currentGroup->next = returnGroupFromGroupId(ptrTrack->listOfGroups[ii].groupId);
          currentGroup = currentGroup->next;
      }
      ptrTrack->maxLevel = fillGroupLevel(ptrTrack);
      ptrTrack->specialTrack = compareToSpecialTrack(ptrTrack->style);

      if(ptrTrack->isHighDensityTrack && ptrTrack->vis != VIS_HIDE)
      {
         highDensFtypes *localHDInfo = ptrTrack->highDensFtypes;
         ptrTrack->height = localHDInfo->gbTrackPxHeight + 6;
      }
      else
      {
        // In case of any (big) barchart drawing, use height from 'gbTrackPxHeight' instead of the constant
        if(strcasecmp(ptrTrack->style, BIDIRECTIONALLOCALHISTOGRAMLARGE) == 0 || strcasecmp(ptrTrack->style, BIDIRECTIONALGLOBALHISTOGRAMLARGE) == 0 || strcasecmp(ptrTrack->style, GLOBALLARGEHISTOGRAM) == 0 || strcasecmp(ptrTrack->style, LOCALLARGEHISTOGRAM) == 0){
          highDensFtypes *localHDInfo = ptrTrack->highDensFtypes;
          ptrTrack->height = localHDInfo->gbTrackPxHeight + 6;
        }
        else{
          if(ptrTrack->vis == VIS_DENSE || ptrTrack->vis == VIS_DENSEMC)
          {
            ptrTrack->height = getMyTrackHeight(ptrTrack->style) + 6;
          }
          else
          {
            ptrTrack->height = (ptrTrack->maxLevel + 1) * getMyTrackHeight(ptrTrack->style) + 6;
          }
        }
      }

      extraSize = getSizeNeededByTrackAttributes(ptrTrack);

      if(extraSize > ptrTrack->height)
      {
          ptrTrack->height = extraSize;
      }

      ptrTrack = ptrTrack->next;
  }
  timeItNow("C-DONE - Sorting and organizing Groups");

  return;
}

void fillSortHashTableWithFtypeIds(GHashTable * tempSortHash, char *databaseName, int databaseId, long currentUserId,
                                   char *arrayOfTypeIds, int currentValue)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  int ftypeid = 0;
  char tempBuffer[55] = "";
  int tempValue = 0;
  int *previousValue = NULL;
  resetLocalConnection(databaseName);
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);

  sprintf(sqlbuff, "SELECT ftype.ftypeId, featuresort.sortkey FROM "
          "ftype, featuresort WHERE featuresort.userId = %ld and featuresort.ftypeid in %s "
          "AND ftype.ftypeid = featuresort.ftypeid ORDER BY featuresort.sortkey", currentUserId, arrayOfTypeIds);

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
    return;
  }
  sqlresult = mysql_store_result(connection);
  if(mysql_num_rows(sqlresult) == 0)
  {
    mysql_free_result(sqlresult);
    return;
  }
  while ((row = mysql_fetch_row(sqlresult)) != NULL)
  {
    ftypeid = atoi(row[0]);
    sprintf(tempBuffer, "%d:%d", databaseId, ftypeid);
    tempValue = atoi(row[1]) + currentValue;
    previousValue = g_hash_table_lookup(tempSortHash, tempBuffer);
    if(previousValue == NULL)
      g_hash_table_insert(tempSortHash, g_strdup(tempBuffer), intdup(tempValue));

  }
  mysql_free_result(sqlresult);
  return;
}

int findNextAvailableLocation(int *temporaryOrder, int startPosition, int endPosition)
{
  int position = 0;

  for (position = startPosition; position < endPosition; position++)
  {
      if(temporaryOrder[position] == 0)
        return position;
  }
  return -1;
}

void fillSortHashTable(GHashTable * tempSortHash, char *databaseName, long currentUserId, char *arrayOfTypeIds,
                       int currentValue)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  int tempValue = 0;

  resetLocalConnection(databaseName);
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);

  sprintf(sqlbuff, "SELECT CONCAT(ftype.fmethod,':', ftype.fsource) myftype, featuresort.sortkey FROM "
          "ftype, featuresort WHERE featuresort.userId = %ld and featuresort.ftypeid in %s "
          "AND ftype.ftypeid = featuresort.ftypeid ORDER BY featuresort.sortkey", currentUserId, arrayOfTypeIds);

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      return;
  }
  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult) == 0)
  {
      return;
  }

  while ((row = mysql_fetch_row(sqlresult)) != NULL)
  {
      tempValue = atoi(row[1]) + currentValue;
      g_hash_table_insert(tempSortHash, g_strdup(row[0]), intdup(tempValue));
  }
  mysql_free_result(sqlresult);

  return;
}

int fetchMaxValueFromHash(GHashTable * tempSortHash, int currentId)
{
  int maxValue = 0;
  int tempValue = 0;
  int *theOrderId = NULL;
  GList *listOfKeys = g_hash_table_get_keys(tempSortHash);

  while (listOfKeys)
  {
      char *tempTrackKey = (char *)(listOfKeys->data);
      theOrderId = (int *)g_hash_table_lookup(tempSortHash, tempTrackKey);
      tempValue = *theOrderId;
      if(tempValue > maxValue)
      {
          maxValue = tempValue;
      }
      listOfKeys = g_list_next(listOfKeys);
  }

  maxValue += currentId;
  return maxValue;
}

int fetchMaxSortKeyFromDb(char *databaseName, long currentUserId, char *arrayOfTypeIds, int currentId)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  int maxNumberOfRecords = 0;

  resetLocalConnection(databaseName);
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);

  sprintf(sqlbuff, "SELECT MAX(sortkey) MAX FROM featuresort WHERE userId = %ld"
          " AND featuresort.ftypeid IN %s", currentUserId, arrayOfTypeIds);

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {

      fprintf(stderr, "Error querying the featuresort table.\n");
      fprintf(stderr, "the database is %s and the query is %s\n", databaseName, sqlbuff);
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return -1;
  }
  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult) == 0)
  {
      return -1;
  }

  while ((row = mysql_fetch_row(sqlresult)) != NULL)
  {
      maxNumberOfRecords = atoi(row[0]);
  }
  maxNumberOfRecords = maxNumberOfRecords + currentId;
  mysql_free_result(sqlresult);

  return maxNumberOfRecords;
}

int *createOrderArrayFromHash(GHashTable * tempSortHash)
{
  int *temporaryOrder = NULL;
  int maxValue = 0;
  int tempValue = 0;
  int ii = 0;
  int *theOrderId = NULL;
  GList *listOfKeys = g_hash_table_get_keys(tempSortHash);

  while (listOfKeys)
  {
      char *tempTrackKey = (char *)(listOfKeys->data);
      theOrderId = (int *)g_hash_table_lookup(tempSortHash, tempTrackKey);
      tempValue = *theOrderId;
      if(tempValue > maxValue)
        maxValue = tempValue;
      listOfKeys = g_list_next(listOfKeys);
  }

  maxValue += 55;
  if((temporaryOrder = (int *)malloc((maxValue) * sizeof(int))) == NULL)
  {
      perror("problems with values");
      return NULL;
  }
  for (ii = 0; ii < maxValue; ii++)
  {
      temporaryOrder[ii] = 0;
  }
  return temporaryOrder;
}

int *fillUpOrderArrayFromHash(int *temporaryOrder, GHashTable * tempSortHash)
{
  int *theOrderId = NULL;
  int tempValue = 0;
  GList *listOfKeys = g_hash_table_get_keys(tempSortHash);

  while (listOfKeys)
  {
      char *tempTrackKey = (char *)(listOfKeys->data);
      theOrderId = (int *)g_hash_table_lookup(tempSortHash, tempTrackKey);
      tempValue = *theOrderId;
      if(tempValue > 0)
        temporaryOrder[tempValue] = tempValue + 1;
      listOfKeys = g_list_next(listOfKeys);
  }

  return temporaryOrder;
}

GHashTable *createHashWithNewOrder(int *temporaryOrder, GHashTable * allSortedHash, int maxValue)
{
  GHashTable *tempSortHash = NULL;
  int *theOrderId = NULL;
  int tempValue = 0;
  int *sortOrder = NULL;
  GList *listOfKeys = g_hash_table_get_keys(allSortedHash);
  tempSortHash = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);

  while (listOfKeys)
  {
      char *tempTrackKey = (char *)(listOfKeys->data);
      theOrderId = (int *)g_hash_table_lookup(allSortedHash, tempTrackKey);
      tempValue = *theOrderId;
      if(!(sortOrder = (int *)malloc(sizeof(int))))
        return NULL;
      *sortOrder = temporaryOrder[tempValue];
      g_hash_table_insert(tempSortHash, g_strdup(tempTrackKey), sortOrder);
      listOfKeys = g_list_next(listOfKeys);
  }

  return tempSortHash;
}

void printAllArrays(void)
{
  int counter = 0;
  int numberGenboreeDatabases = getNumberDatabases();
  char *databaseName = NULL;
  char *arrayOfTypeIds = NULL;
  while (numberGenboreeDatabases > counter)
  {
      databaseName = getDatabaseFromId(counter);
      fprintf(stderr, "looping in database = %s\n", databaseName);
      arrayOfTypeIds = getArrayOfTypeIds(databaseName);
      fprintf(stderr, "%s\n", arrayOfTypeIds);
      counter++;
  }
  return;
}

char *getArrayOfTypeIds(char *databaseName)
{
  GHashTable *allFmFs = NULL;
  char *fmethodfsource = NULL;
  char *fmethod = NULL;
  char *fsource = NULL;
  int ftypeid = 0;
  int counter = 0;
  int sizeOfAllFmFs = 0;
  char arrayOfTypeIds[2555] = "";
  GList *listOfTracks;

  allFmFs = getAllFmethodFsource();
  if(allFmFs == NULL)
    return NULL;

  sizeOfAllFmFs = g_hash_table_size(allFmFs);

  if(!sizeOfAllFmFs)
    return NULL;
  listOfTracks = g_hash_table_get_keys(allFmFs);

  while (listOfTracks)
  {
      fmethodfsource = (char *)listOfTracks->data;
      if(fmethodfsource)
      {
          fmethod = getNameSemicolonSeparatedWord(fmethodfsource, 0);
          fsource = getNameSemicolonSeparatedWord(fmethodfsource, 1);
          ftypeid = getftypeidFromFmethodFsource(databaseName, fmethod, fsource);
          if(ftypeid)
          {
              if(!counter)
                sprintf(arrayOfTypeIds, "(");
              sprintf(arrayOfTypeIds, "%s %d, ", arrayOfTypeIds, ftypeid);
              counter++;
          }
      }
      listOfTracks = g_list_next(listOfTracks);
  }

  strcat(arrayOfTypeIds, " -1)");

  return strdup(arrayOfTypeIds);
}

char **returnSortedListOfRecordsFromDBIDFtypeId(char **initialArray, int lengthArray)
{
  GHashTable *typeId2FeatureTypeHash;
  char **unsortedArray = NULL;
  char **sortedArray = NULL;
  int ii = 0;
  int counter = 0;
  char *trackName = NULL;

  if(initialArray == NULL)
    return NULL;

  typeId2FeatureTypeHash = getTypeId2FeatureTypeHash();

  unsortedArray = (char **)calloc((lengthArray + 2), sizeof(char *));

  for (ii = 0; ii < lengthArray; ii++)
  {
      if(initialArray[ii] != NULL)
      {
          trackName = g_hash_table_lookup(typeId2FeatureTypeHash, initialArray[ii]);
      }
      else
      {
          trackName = NULL;
      }

      if(trackName != NULL)
      {
          unsortedArray[counter] = strdup(trackName);
          counter++;
      }
  }
  if(counter)
  {
      sortedArray = sedgesort(unsortedArray, counter);
      destroy_double_pointer(unsortedArray, counter);
  }

  return sortedArray;
}

gint compare_intPointers(gconstpointer a, gconstpointer b)
{
  int *aa = (int *)a;
  int *bb = (int *)b;

  if(*aa > *bb)
    return 1;
  else if(*aa == *bb)
    return 0;
  else
    return -1;
}

gint compare_stringPointers(gconstpointer c1, gconstpointer c2)
{
  return strcmp((const char *)c1, (const char *)c2);
}

char *returnFirstClassName(char *trackName)
{
  char *tempGclassNames = NULL;
  GHashTable *myFeatureToGclassHash;
  int numberClasses = 0;
  char **alltheClasses = NULL;
  char *tempClass = NULL;

  if(trackName == NULL)
  {
      fprintf(stderr, "The trackName in returnFirstClassName is empty\n");
      fflush(stderr);
      return NULL;
  }
  myFeatureToGclassHash = getFeatureToGclassHash();
  if(myFeatureToGclassHash == NULL)
  {
      fprintf(stderr, "The myFeatureToGclassHash in returnFirstClassName is empty\n");
      fflush(stderr);
      return NULL;
  }

  tempGclassNames = (char *)g_hash_table_lookup(myFeatureToGclassHash, trackName);
  if(tempGclassNames)
  {
      numberClasses = countNumberSeparatorsInWord(tempGclassNames, ":");
      if(!numberClasses)
        return tempGclassNames;
      else
      {
          int resultingClasses = 0;
          alltheClasses = splitLargeStringIntoSubstringsUsingSeparator(tempGclassNames, ":", &resultingClasses);
          tempClass = strdup(alltheClasses[0]);
          destroy_double_pointer(alltheClasses, resultingClasses);
          return tempClass;
      }

  }
  else
  {
      fprintf(stderr, "The tempGclassNames is NULL in function returnFirstClassName\n");
      return NULL;
  }
  return NULL;

}

char *returnAllClassNames(char *trackName)
{
  char *tempGclassNames = NULL;
  GHashTable *myFeatureToGclassHash;

  myFeatureToGclassHash = getFeatureToGclassHash();

  tempGclassNames = (char *)g_hash_table_lookup(myFeatureToGclassHash, trackName);
  if(tempGclassNames)
    return tempGclassNames;
  else
  {
      fprintf(stderr, "The tempGclassNames is NULL in function returnAllClassNames\n");
      return NULL;
  }
  return NULL;
}

int returnftypeId(char *featureType, int *databaseId)
{
  GHashTable *myFeatureTypeHash = getFeatureTypeHash();
  char *theData;
  int ftypeId = -1;
  char *databaseIdStr = NULL;
  char *ftypeidStr = NULL;
  char *occurance = NULL;
  int tempDatabaseId = -1;

  theData = (char *)g_hash_table_lookup(myFeatureTypeHash, featureType);
  if(!theData)
  {
      *databaseId = -1;
      return -1;
  }

  databaseIdStr = strdup(theData);
  occurance = strstr(databaseIdStr, ":");
  *occurance = '\0';
  tempDatabaseId = atoi(databaseIdStr);
  free(databaseIdStr);
  databaseIdStr = NULL;
  *databaseId = tempDatabaseId;

  ftypeidStr = strdup(theData);
  occurance = strstr(ftypeidStr, ":");
  occurance++;
  ftypeId = atoi(occurance);
  free(ftypeidStr);
  ftypeidStr = NULL;

  return ftypeId;
}
