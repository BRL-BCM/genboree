#include <stdio.h>
#include <time.h>
#include <string.h>
#include <libgen.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/file.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <ctype.h>
#include <sys/errno.h>
#include "expat.h"
#include "optimizedGB.h"
#include "optimizedFunctions.h"

size_t myBase64_decode(const char *src, char *dest);

#define BUFFSIZE	8192
#define	STACKSIZE	1024

typedef enum {
  START,
  GENBOREETRACKS,
  TRACKVIS,
  END
} visualizationEnum;

static int stack;
static int tagCounter = 0;
static char tagName[555] = "";
static int numberTimesTrackAppears = 0;
static TVIS *trackUsed = NULL;
static TVIS *myVisibility = NULL;

void setMyVisibility(TVIS * myVisibilityUsed)
{
  myVisibility = myVisibilityUsed;
}

void destroyMyVisibility(void)
{
  if(myVisibility)
  {
      destroyDoublePointer(myVisibility->name, (myVisibility->numberOfTracks));
      free(myVisibility->value);
      myVisibility->value = NULL;

      free(myVisibility);
      myVisibility = NULL;
  }
  return;
}

void destroyAllVisibility(void)
{
  destroyLocalTvis(trackUsed);
  destroyLocalTvis(myVisibility);
}

void destroyLocalTvis(TVIS * tvis)
{
  if(!tvis || !tvis->numberOfTracks)
    return;
  destroy_double_Local_pointer(tvis->name, (tvis->numberOfTracks));
  destroy_double_Local_pointer(tvis->className, (tvis->numberOfTracks));
  free(tvis->name);
  tvis->name = NULL;
  free(tvis->className);
  tvis->className = NULL;
  free(tvis->value);
  tvis->value = NULL;
  free(tvis->order);
  tvis->order = NULL;

  free(tvis);
  tvis = NULL;
  return;
}

static char *extractName(char *token)
{
  int sizeToken = strlen(token);
  int ii = 0;
  int end = 0;
  char *newName = NULL;

  for (ii = 0; ii < sizeToken; ii++)
    if(token[ii] == '=')
      end = ii;

  newName = getstring(ii + 5);
  strncpy(newName, token, end);

  return newName;
}

static int extractValue(char *token)
{
  int sizeToken = strlen(token);
  int ii = 0;
  int found = 0;
  int aa = 0;
  int returnValue = 0;
  char temporaryString[255] = "";

  for (ii = 0; ii < sizeToken; ii++)
  {
      if(found)
      {
          temporaryString[aa] = token[ii];
          aa++;
      }
      if(token[ii] == '=')
        found = 1;
  }
  returnValue = atoi(temporaryString);

  return returnValue;
}

void createMyVisibility(char *theTracks)
{
  char *token;
  char *separator = "#";
  int numberOfOccurances = 1;
  int ii = 0;
  int sizeString = 0;

  if(!theTracks)
  {
      return;
  }

  sizeString = strlen(theTracks);

  for (ii = 0; ii < sizeString; ii++)
  {
      if(theTracks[ii] == '#')
      {
          numberOfOccurances++;
      }
  }

  if(numberOfOccurances)
  {
      if((myVisibility = (TVIS *) malloc(sizeof(TVIS))) == NULL)
      {
          perror("problems creating myVisibility");
          return;
      }

      myVisibility->numberOfTracks = numberOfOccurances;

      if((myVisibility->name = (char **)malloc((myVisibility->numberOfTracks + 1) * sizeof(char *))) == NULL)
      {
          perror("problems with myVisibility->name");
          return;
      }

      if((myVisibility->value = (int *)malloc((myVisibility->numberOfTracks + 1) * sizeof(int))) == NULL)
      {
          perror("problems with myVisibility->value");
          return;
      }

      /* first call to strtok() */
      token = strtok(theTracks, separator);
      ii = 0;
      while (token != NULL)
      {
          myVisibility->name[ii] = extractName(token);
          myVisibility->value[ii] = extractValue(token);
          token = strtok(NULL, separator);
          ii++;
      }
  }

  return;
}

char *returnMyVisibilityClassName(char *track_name)
{
  int equalStrings = -23;
  int ii = 0;
  if(myVisibility)
  {
      for (ii = 0; ii < myVisibility->numberOfTracks; ii++)
      {
          equalStrings = strcmp(track_name, myVisibility->name[ii]);
          if(equalStrings == 0)
          {
              return strdup(myVisibility->className[ii]);
          }
      }
  }

  return NULL;
}

int returnMyVisibilityValue(char *track_name)
{
  int equalStrings = -23;
  int ii = 0;
  if(myVisibility)
  {
      for (ii = 0; ii < myVisibility->numberOfTracks; ii++)
      {
          equalStrings = strcmp(track_name, myVisibility->name[ii]);
          if(equalStrings == 0)
          {
              return myVisibility->value[ii];
          }
      }
  }

  return 1;
}

char *getTagName()
{
  return tagName;
}

char *returnMap(char *filename, int *filePointer)
{

  struct stat info;
  size_t sizeFile = 0;
  char *fileBase;

  if(g_file_test(filename, G_FILE_TEST_EXISTS) == 0)
  {
      fprintf(stderr,
              "Error in function returnMap the file %s WAS NOT FOUND, may be you give the wrong name to the program\n Sorry the program has to exit\n",
              filename);
      exit(50);
  }

  if((*filePointer = open(filename, O_RDWR)) < 0)
  {
      perror("Open Error");
      return NULL;
  }

  stat(filename, &info);
  sizeFile = info.st_size;

  fileBase = mmap(0, sizeFile, PROT_READ, MAP_SHARED, *filePointer, 0);
  if(fileBase == NULL)
  {
      perror("Mmap Error");
      return NULL;
  }

  return fileBase;
}

int dropMap(char *fileBase, int filePointer)
{
  munmap(fileBase, strlen(fileBase));
  close(filePointer);
  return 1;
}

void counterStart(void *data, const char *el, const char **attr)
{
  if(tagName == NULL)
    return;

  if(strncmp(el, tagName, strlen(tagName)) == 0)
    tagCounter++;
  return;
}

void fillStyleFeatures(int tracknumber, int nameId, char *value)
{
  unsigned char buffer[555] = "";
  size_t size = 0;

  switch (nameId)
  {
    case 0:
      size = myBase64_decode(value, (char *)buffer);
      buffer[size] = 0;
      trackUsed->name[tracknumber] = strdup((char *)buffer);
      break;
    case 1:
      trackUsed->value[tracknumber] = atoi(value);
      break;
    case 2:
      trackUsed->className[tracknumber] = strdup(value);
      break;
    case 3:
      trackUsed->order[tracknumber] = atoi(value);
      break;
    default:
      fprintf(stderr, "the value %s for the tracknumber %d and nameid %d was not found\n", value, tracknumber, nameId);
      break;
  }

  return;
}

void startStyleParsing(void *data, const char *el, const char **attr)
{
  int ii = 0;
  int jj = 0;
  int flag = 0;
  int len = 0;
  char *track = getTagName();
  char *attriburesNames[] = { "trackName", "visibility", "className", "order", "" };
  char *tempName;

  if(!track)
    return;

  if(strncmp(el, track, strlen(track)) == 0)
  {

      if(stack == START)
      {
          stack = GENBOREETRACKS;
      }

      if(stack == GENBOREETRACKS)
      {
          stack = TRACKVIS;
      }

      for (ii = 0; attr[ii]; ii = ii + 2)
      {
          len = strlen(attr[ii]);
          for (jj = 0; attriburesNames[jj][0] != '\0' && !flag; jj++)
          {
              if(strncmp(attr[ii], attriburesNames[jj], len) == 0)
              {
                  flag = 1;
                  tempName = strdup(attr[ii + 1]);
                  fillStyleFeatures(numberTimesTrackAppears, jj, tempName);
                  free(tempName);
                  tempName = NULL;
              }
          }
          flag = 0;
      }
  }

  return;
}

void end(void *data, const char *el)
{

  if(stack == TRACKVIS)
  {
      stack = GENBOREETRACKS;
      numberTimesTrackAppears++;
  }
  else if(stack == GENBOREETRACKS)
    stack = END;

  return;
}

int returnNumberVisTagsOccurances(char *tag, char *fileBase, int totalLen)
{
  XML_Parser parser = NULL;

  strcpy(tagName, tag);
  tagCounter = 0;
  parser = XML_ParserCreate("UTF-8");

  if(!parser)
  {
      fprintf(stderr, "Couldn't allocate memory for parser\n");
      return -1;
  }

  XML_SetElementHandler(parser, counterStart, end);

  if(!XML_Parse(parser, fileBase, totalLen, 0))
  {
      fprintf(stderr, "XML parser error:\t%s at line %d\n", XML_ErrorString(XML_GetErrorCode(parser)),
              (int)XML_GetCurrentLineNumber(parser));
      fflush(stderr);
      XML_ParserFree(parser);
      return 0;
  }

  XML_ParserFree(parser);

  return tagCounter;
}

void destroy_double_Local_pointer(char **ptr, int max_hits)
{
  int ii;
  if(ptr && max_hits)
  {
      for (ii = 0; ii < max_hits; ii++)
      {
          if(ptr[ii] && strlen(ptr[ii]) > 1)
          {
              free(ptr[ii]);
              ptr[ii] = NULL;
          }
      }

      free(ptr);
      ptr = NULL;
  }
}

TVIS *createTVISfromXML(int numberOfOccurances)
{
  TVIS *tvis = NULL;

  if(numberOfOccurances)
  {
      if((tvis = (TVIS *) malloc(sizeof(TVIS))) == NULL)
      {
          perror("problems creating tvis");
          return 0;
      }

      tvis->numberOfTracks = numberOfOccurances;

      if((tvis->name = (char **)malloc((tvis->numberOfTracks + 1) * sizeof(char *))) == NULL)
      {
          perror("problems with tvis->name");
          return 0;
      }

      if((tvis->value = (int *)malloc((tvis->numberOfTracks + 1) * sizeof(int))) == NULL)
      {
          perror("problems with tvis->value");
          return 0;
      }

      if((tvis->className = (char **)malloc((tvis->numberOfTracks + 1) * sizeof(char *))) == NULL)
      {
          perror("problems with tvis->ClassName");
          return 0;
      }

      if((tvis->order = (int *)malloc((tvis->numberOfTracks + 1) * sizeof(int))) == NULL)
      {
          perror("problems with tvis->order");
          return 0;
      }

  }

  return tvis;
}

int returnTracksUsed(char *tag, char *fileBase, int totalLen)
{
  XML_Parser parser = XML_ParserCreate("UTF-8");

  XML_SetElementHandler(parser, startStyleParsing, end);

  stack = START;

  if(!XML_Parse(parser, fileBase, totalLen, 0))
  {
      fprintf(stderr, "XML parser error:\t%s at line %d\n", XML_ErrorString(XML_GetErrorCode(parser)),
              (int)XML_GetCurrentLineNumber(parser));
      fflush(stderr);
      XML_ParserFree(parser);
      return 0;
  }

  XML_ParserFree(parser);

  return 1;
}

void generateVisDataFromXml(char *xmlFileName)
{
  int filePointer = 0;
  int totalLen = 0;
  char tag[] = "TRACKVIS";
  int numberOcurrances = 0;
  char *fileBase = NULL;
  char *name = xmlFileName;
  int ii = 0;
  int maxOrder = 0;
  char **temporaryRecords = NULL;
  int someSpecialDebugCase = 0; // use this tag to print the xml file in a readable way
  int numberOfAssignedRecords = 0;

  fileBase = returnMap(name, &filePointer);
  totalLen = strlen(fileBase);

  numberOcurrances = returnNumberVisTagsOccurances(tag, fileBase, totalLen);

  if(numberOcurrances)
  {

    setNumberOfTracks(numberOcurrances);
    timeItNow("DEBUG: before createTVISfromXML()\n");
    trackUsed = createTVISfromXML(numberOcurrances);
   timeItNow("DEBUG: after createTVISfromXML()\n");
    returnTracksUsed(tag, fileBase, totalLen);

    for (ii = 0; ii < numberOcurrances; ii++)
    {
        if(trackUsed->order[ii] > maxOrder)
          maxOrder = trackUsed->order[ii];
    }

    if(numberOcurrances > maxOrder)
      maxOrder = numberOcurrances;

    numberOfAssignedRecords = maxOrder + 6;
    timeItNow("DEBUG: before setNumberOfItemsInArrayOrderedTracks()\n");
    setNumberOfItemsInArrayOrderedTracks(numberOfAssignedRecords);
    timeItNow("DEBUG: after setNumberOfItemsInArrayOrderedTracks()\n");
    temporaryRecords = (char **)calloc(numberOfAssignedRecords, sizeof(char *));
    for (ii = 0; ii < numberOcurrances; ii++)
    {
      temporaryRecords[trackUsed->order[ii]] = strdup(trackUsed->name[ii]);
    }
    if(someSpecialDebugCase)
    {
        fprintf(stderr, "<GENBOREETRACKS>\n");
        for (ii = 0; ii < trackUsed->numberOfTracks; ii++)
        {
          fprintf(stderr,
                  "	<TRACKVIS trackName=\"%s\" visibility=\"%d\" order=\"%d\" className=\"%s\"> </TRACKVIS>\n",
                  trackUsed->name[ii], trackUsed->value[ii], trackUsed->order[ii], trackUsed->className[ii]);
        }
        fprintf(stderr, "</GENBOREETRACKS>\n");
        fflush(stderr);
    }

  }
  setArrayOrderedTracks(temporaryRecords);
  setMaxOrder(maxOrder);
  dropMap(fileBase, filePointer);

  if(trackUsed && trackUsed->numberOfTracks > 0)
  {
    setMyVisibility(trackUsed);
  }
  else
  { 
    destroyLocalTvis(trackUsed);
  }
  return;
}
