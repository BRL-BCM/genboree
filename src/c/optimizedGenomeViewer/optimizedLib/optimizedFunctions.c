#include "globals.h"
#include "optimizedGB.h"
#include "optimizedFunctions.h"
#include "map_reader.h"

extern void destroyMyVisibility(void);
extern int returnMyVisibilityValue(char *track_name);

static struct rgbColor GUIDE_COLOR = { 220, 200, 255 };

static struct rgbColor GENE_COLORS[4] = {
{96, 187, 70},
{236, 187, 70},
{208, 71, 153},
{38, 53, 116}
};

static STRINGOUT *stringOut = NULL;

STRINGOUT *getStringOut(void)
{
  return stringOut;
}

static long long startPositionGlobal = 0;
static long long endPositionGloblal = 0;
static int canvasWidthGlobal = 0;
static double universalScaleGlobal = 0.0;
static int labelWidthGlobal = 0;
static int totalWidthGlobal = 0;
static long lengthOfSegmentGlobal = 0;
static GHashTable *attNameHashTemplate = NULL;
static GHashTable *attValueHashTemplate = NULL;
static GHashTable *attNameHashUser = NULL;
static GHashTable *attValueHashUser = NULL;
int urlMemAlloc = 0;
int noOfTracksToDraw = 0 ;
int truncateTracks = 0 ;
static GHashTable *tempTrackHash = NULL ;

void setLengthOfSegmentGlobal(long long length)
{
  lengthOfSegmentGlobal = length;
  setLengthOfSegmentGlobalForDrawingFunction(length);
  setLengthOfSegmentGlobalForHDTrack(length);
}

long long getLengthOfSegment(void)
{
  return lengthOfSegmentGlobal;
}

void setLabelWidth(int width)
{
  labelWidthGlobal = width;
  setLabelWidthGlobalForDrawingFunction(width);
}

void setUniversalScaleGlobal(double myScale)
{
  universalScaleGlobal = myScale;
  setUniversalScaleGlobalForDrawingFunction(myScale);
  setUniversalScaleGlobalForHDTrack(myScale);
}

double getUniversalScale(void)
{
  return universalScaleGlobal;
}

void setTotalWidthGlobal(int width)
{
  totalWidthGlobal = width;
  setTotalWidthGlobalForDrawingFunction(width);
}

void setStartPositionGloblal(long long start)
{
  startPositionGlobal = start;
  setStartPositionGlobalForDrawingFunction(start);
  setStartPositionGlobalForHDTrack(start);
}

void setEndPositionGloblal(long long end)
{
  endPositionGloblal = end;
  setEndPositionGlobalForDrawingFunction(end);
  setEndPositionGlobalForHDTrack(end);
}

void setCanvasWidthGlobal(int myWidth)
{
  canvasWidthGlobal = myWidth;
  setCanvasWidthGlobalForDrawingFunction(myWidth);
  setCanvasWidthGlobalForHDTrack(myWidth);
}

int getCanvasWidth(void)
{
  return canvasWidthGlobal;
}

long long getEndPosition(void)
{
  return endPositionGloblal;
}

long long getStartPosition(void)
{
  return startPositionGlobal;
}

void setStringOut(STRINGOUT * mySout)
{
  stringOut = mySout;
}

char *dec2hex(int originalDec)
{

  int lengthString = 0;
  char newStr[8] = "";
  char tempString[8] = "";
  int dec = 0;
  int max = 16777215;

  if(originalDec < 0)
    return NULL;
  else if(originalDec > max)
    dec = max;
  else
    dec = originalDec;

  snprintf(tempString, 8, "%x", dec);

  lengthString = strlen(tempString);

  switch (lengthString)
  {
    case 0:
      strcpy(newStr, "000000");
      break;
    case 1:
      sprintf(newStr, "00000%s", tempString);
      break;
    case 2:
      sprintf(newStr, "0000%s", tempString);
      break;
    case 3:
      sprintf(newStr, "000%s", tempString);
      break;
    case 4:
      sprintf(newStr, "00%s", tempString);
      break;
    case 5:
      sprintf(newStr, "0%s", tempString);
      break;
    case 6:
      snprintf(newStr, 8, "%s", tempString);
      break;
    default:
      strcpy(newStr, "000000");
      break;
  }

  return strdup(newStr);
}

int hex2dec(const char *hex)
{
  int dec;

  if(hex == NULL)
    return -1;

  sscanf(hex, "%x", &dec);
  return dec;
}

char *returnPartRegEx(const char *myString, int fieldRegexAll)
{
  char *find = NULL;
  pcre *re = NULL;
  char *myRegex = NULL;
  char start[] = "\\$\\{([^:{}]+):(?:[^{}]+)+(?:\\{[^{}]+\\})?(?:[^{}]+)?\\}";
  char end[] = "\\$\\{[^:{}]+:((?:[^{}]+)+(?:\\{[^{}]+\\})?(?:[^{}]+)?)\\}";
  char all[] = "(\\$\\{[^:{}]+:(?:[^{}]+)+(?:\\{[^{}]+\\})?(?:[^{}]+)?\\})";

  if(!myString || strlen(myString) < 1)
    return NULL;

  if(fieldRegexAll == 0)
  {
      myRegex = start;
  }
  else if(fieldRegexAll == 1)
  {
      myRegex = end;
  }
  else if(fieldRegexAll == 2)
  {
      myRegex = all;
  }
  else
  {
      myRegex = NULL;
  }

  if(myRegex)
  {
      find = returnRegExPattern(myRegex, myString, &re);
      free(re);                 /* Release memory used for the compiled pattern */
      re = NULL;
  }

  if(find)
  {
      return find;
  }
  else
  {
      return NULL;
  }
}

int vpHasRegEx(const char *myString)
{
  char tempString[MAXLENGTHOFTEMPSTRING];
  int lengthOfMyString = -1;
  int ii = 0;
  int found = 0;
  int charFound = 0;

  memset(tempString, '\0', MAXLENGTHOFTEMPSTRING);

  if(!myString || strlen(myString) < 1)
    return -1;

  lengthOfMyString = strlen(myString);
  ii = 0;
  while (ii < lengthOfMyString)
  {
      if(myString[ii] == '$' && charFound == 0)
      {
          charFound = 1;
      }
      if(myString[ii] == '{' && charFound == 1)
      {
          charFound = 2;
      }
      if(myString[ii] == '"' && charFound == 2)
      {
          charFound = 3;
      }
      else if(myString[ii] == '"' && charFound == 3)
      {
          charFound = 4;
      }

      if(myString[ii] == '}' && charFound == 4)
      {
          return found;
      }
      else if(myString[ii] == ':' && charFound == 4)
      {
          charFound = 5;
          found = 1;
          break;
      }
      ii++;
  }

  return found;
}

char *cleanUpVP(const char *myString)
{
  char *duplicate = NULL;
  char tempString[MAXLENGTHOFTEMPSTRING];
  int lengthOfMyString = -1;
  int ii = 0;
  int counter = 0;
  int charFound = 0;
  int limitFirstField = 0;

  memset(tempString, '\0', MAXLENGTHOFTEMPSTRING);

  if(!myString || strlen(myString) < 1)
    return NULL;

  lengthOfMyString = strlen(myString);
  ii = counter = 0;
  while (ii < lengthOfMyString)
  {
    if(myString[ii] == '$' && charFound == 0)
    {
        charFound = 1;
    }
    if(myString[ii] == '{' && charFound == 1)
    {
        charFound = 2;
    }
    if(myString[ii] == '"' && charFound == 2)
    {
        charFound = 3;
    }
    else if(myString[ii] == '"' && charFound == 3)
    {
        charFound = 4;
        limitFirstField = ii;
        break;
    }

    ii++;
  }

  if(charFound < 1)
    return NULL;

  ii = counter = 0;
  while (ii < limitFirstField)
  {
    if(myString[ii] != '"')
    {
        tempString[counter] = myString[ii];
        ii++;
        counter++;
    }
    else
    {
        ii++;
    }

  }
  duplicate = strdup(tempString);
  memset(tempString, '\0', MAXLENGTHOFTEMPSTRING);
  ii = counter = 0;
  lengthOfMyString = strlen(duplicate);
  while (ii < lengthOfMyString)
  {
    if(duplicate[ii] != '$' && duplicate[ii] != '{' && duplicate[ii] != '}')
    {
        tempString[counter] = duplicate[ii];
        ii++;
        counter++;
    }
    else
    {
        ii++;
        if(duplicate[ii] == '}')
          ii = lengthOfMyString + 1;
    }
  }
  free(duplicate);
  duplicate = NULL;
  return strdup(tempString);
}

char *returnPartRegExVP(const char *myString, int fieldRegexAll)
{
  char *find = NULL;
  pcre *re = NULL;
  char *myRegex = NULL;
  char start[] = "\\$\\{\"([^\":{}]+)\"[:}](?:[^{}]+)+(?:\\{[^{}]+\\})?(?:[^{}]+)?\\}";
  char end[] = "\\$\\{[^:{}]+:((?:[^{}]+)+(?:\\{[^{}]+\\})?(?:[^{}]+)?)\\}";
  char all[] = "(\\$\\{[^:{}]+:(?:[^{}]+)+(?:\\{[^{}]+\\})?(?:[^{}]+)?\\})";

  if(!myString || strlen(myString) < 1)
    return NULL;

  if(fieldRegexAll == 0)
  {
    myRegex = start;
  }
  else if(fieldRegexAll == 1)
  {
    myRegex = end;
  }
  else if(fieldRegexAll == 2)
  {
    myRegex = all;
  }
  else
  {
    myRegex = NULL;
  }

  if(myRegex)
  {
    find = returnRegExPattern(myRegex, myString, &re);
    free(re);                 /* Release memory used for the compiled pattern */
    re = NULL;
  }

  if(find)
  {
    return find;
  }
  else
  {
    return NULL;
  }
}

char *returnField(const char *myString)
{
  char *field = NULL;
  field = returnPartRegEx(myString, 0);
  return field;
}

char *returnRegex(const char *myString)
{
  char *regex = NULL;
  regex = returnPartRegEx(myString, 1);

  return regex;
}

char *returnNextRegex(const char *myString)
{
  char *regex = NULL;
  regex = returnPartRegEx(myString, 2);

  return regex;
}

int findRegExSize(const char *myString)
{
  char *all = NULL;
  int length = 0;

  all = returnNextRegex(myString);
  if(all)
    length = strlen(all);

  free(all);
  all = NULL;
  return length;
}

char *returnRegExPattern(char *pattern, const char *subject, pcre ** previousRe)
{
  pcre *re = *previousRe;
  int ovector[OVECCOUNT];
  int subject_length = 0;;
  int rc = 0;
  int fullInfo = 0;
  int sizeCompiledExp = 0;
  const char *error = NULL;
  int erroffset = 0;
  char tempString[MAXLENGTHOFTEMPSTRING];
  if(subject == NULL)
    return NULL;
  memset(tempString, '\0', MAXLENGTHOFTEMPSTRING);
  subject_length = (int)strlen(subject);
  if(!subject_length)
  {
      return NULL;
  }

  /*************************************************************************
  * Now we are going to compile the regular expression pattern, and handle *
  * and errors that are detected.                                          *
  *************************************************************************/

  if(!re)
  {
    re = pcre_compile(pattern,        /* the pattern */
                      0,      /* default options */
                      &error, /* for error message */
                      &erroffset,     /* for error offset */
                      NULL);  /* use default character tables */
    if(re)                    /* in Here the compliled pattern is saved */
    {
      fullInfo = pcre_fullinfo(re, NULL, PCRE_INFO_SIZE, &sizeCompiledExp);
      if(fullInfo >= 0)
      {
        *previousRe = (pcre *) calloc((sizeCompiledExp), sizeof(char));
        memcpy((void *)*previousRe, (void *)re, sizeCompiledExp);
      }
      re = *previousRe;
    }
    else  /* Compilation failed: print the error message and exit */
    {
      fprintf(stderr, "PCRE compilation failed at offset %d: %s\n", erroffset, error);
      fprintf(stderr, "line 457 in function returnRegExPattern(%s, %s);\n", pattern, subject);
      fflush(stderr);
      return NULL;
    }
  }

        /*************************************************************************
	* If the compilation succeeded, we call PCRE again, in order to do a     *
	* pattern match against the subject string. This does just ONE match. If *
	* further matching is needed, it will be done below.                     *
	*************************************************************************/

  rc = pcre_exec(re,            /* the compiled pattern */
                 NULL,          /* no extra data - we didn't study the pattern */
                 subject,       /* the subject string */
                 subject_length,        /* the length of the subject */
                 0,             /* start at offset 0 in the subject */
                 0,             /* default options */
                 ovector,       /* output vector for substring information */
                 OVECCOUNT);    /* number of elements in the output vector */

  /* Matching failed: handle error cases */
  if(rc < 0)
  {
    switch (rc)
    {
      case PCRE_ERROR_NOMATCH:
/*				 Debugging Messages  */
        fprintf(stderr, "No match\n");
        fprintf(stderr, "line 489 in function returnRegExPattern(%s, %s);\n", pattern, subject);
        fprintf(stderr, "the Re pointer address is %p\n", re);
        int resize = 0;
        pcre_fullinfo(re, NULL, PCRE_INFO_SIZE, &resize);
        fprintf(stderr, "resize = %d\n", resize);
        fflush(stderr);

        return NULL;
        break;
        /* Handle other special cases if you like */
      default:
        fprintf(stderr, "Matching error %d\n", rc);
        fprintf(stderr, "line 338 in function returnRegExPattern(%s, %s);\n", pattern, subject);
        fflush(stderr);
        return NULL;
        break;
    }
    return NULL;
  }
  else
  {
    const char **substringList;
    const char **currentSubstring;
    /*************************************************************************
    * We have found the first match within the subject string. If the output *
    * vector wasn't big enough, set its size to the maximum. Then output any *
    * substrings that were captured.                                         *
    *************************************************************************/

    /* The output vector wasn't big enough */

    if(rc == 0)
    {
      rc = OVECCOUNT / 3;
      fprintf(stderr, "ovector only has room for %d captured substrings\n", rc - 1);
      fprintf(stderr, "line 361 in function returnRegExPattern(%s, %s);\n", pattern, subject);
      fflush(stderr);
      free(re);             /* Release memory used for the compiled pattern */
      return NULL;
    }

    /* Store substrings in the output vector by number. */

    memset(tempString, '\0', MAXLENGTHOFTEMPSTRING);

    pcre_get_substring_list(subject, ovector, rc, &substringList);
    currentSubstring = substringList;

    if(rc > 1)
      currentSubstring++;

    while (*currentSubstring != NULL)
    {
      int currSubStrLn = strlen(*currentSubstring);

      if(strlen(tempString) + currSubStrLn >= MAXLENGTHOFTEMPSTRING)
      {
        fprintf(stderr, "the temporary string has reach limit of %d\n", MAXLENGTHOFTEMPSTRING);
        fprintf(stderr, "line 384 in function returnRegExPattern(%s, %s);\n", pattern, subject);
        fflush(stderr);
        /* Release memory used for the compiled pattern */
        pcre_free_substring_list(substringList);
        return NULL;
      }

      strncat(tempString, *currentSubstring, currSubStrLn);
      currentSubstring++;
    }
    tempString[MAXLENGTHOFTEMPSTRING - 1] = '\0';

    pcre_free_substring_list(substringList);

    return strdup(tempString);
  }
}

char *trimmedText(char *originalText, int maxSize)
{
  char reusableText[MAXLENGTHOFTEMPSTRING] = "";
  int lengthOfOriginalText = 0;
  int ii = 0;

  memset(reusableText, '\0', MAXLENGTHOFTEMPSTRING);

  if(originalText == NULL || strlen(originalText) < 1)
  {
      return NULL;
  }

  lengthOfOriginalText = strlen(originalText);
  if(lengthOfOriginalText <= maxSize)
  {
      return strdup(originalText);
  }

  if(maxSize > MAXLENGTHOFTEMPSTRING)
  {
      fprintf(stderr, "method trimmedText was unable to handle large limit %d\n", maxSize);
      return NULL;
  }

  strncat(reusableText, originalText, maxSize);
  for (ii = 0; ii < 3; ii++)
  {
      strcat(reusableText, ".");
  }

  return strdup(reusableText);
}

char **returnRegExMatch(char *pattern, const char *subject, int compiled_options, int *numberOfStrings)
{
  pcre *re = NULL;
  int ovector[OVECCOUNT];
  int subject_length = 0;;
  int rc = 0;
  int sizeStrings = 0;
  const char *error = NULL;
  int erroffset = 0;
  int options = 0;
  char tempString[MAXLENGTHOFTEMPSTRING];
  int ii = 0;
  char **temporaryRecords = NULL;

  if(subject == NULL)
  {
      return NULL;
  }
  memset(tempString, '\0', MAXLENGTHOFTEMPSTRING);
  subject_length = (int)strlen(subject);
  if(!subject_length)
  {
      return NULL;
  }

  for (ii = 0; ii < OVECCOUNT; ii++)
  {
      ovector[ii] = -1;
  }

  re = pcre_compile(pattern, compiled_options, &error, &erroffset, NULL);
  if(!re)
  {
      return NULL;
  }

  rc = pcre_exec(re, NULL, subject, subject_length, 0, 0, ovector, OVECCOUNT);

  if(rc <= 0)
  {
      return NULL;
  }

  temporaryRecords = (char **)calloc((MAXNUMBERSUBSTRINGS + 1), sizeof(char *));

  memset(tempString, '\0', MAXLENGTHOFTEMPSTRING);

  if(ovector[3] > -1)
  {
      sprintf(tempString, "%.*s", ovector[3] - ovector[2], subject + ovector[2]);
      temporaryRecords[sizeStrings] = strdup(tempString);
      sizeStrings++;
  }

  while (1)
  {
      int start_offset = ovector[1];    /* Start at end of previous match */
      if(sizeStrings >= MAXNUMBERSUBSTRINGS)
      {
          pcre_free(re);
          *numberOfStrings = sizeStrings;
          return temporaryRecords;

      }
/* If the previous match was for an empty string, we are finished if we are
* at the end of the subject. Otherwise, arrange to run another match at the
* same point to see if a non-empty match can be found. */

      if(ovector[0] == ovector[1])
      {
          if(ovector[0] == subject_length)
            break;
          options = PCRE_NOTEMPTY | PCRE_ANCHORED;
      }

      rc = pcre_exec(re, NULL, subject, subject_length, start_offset, options, ovector, OVECCOUNT);
      if(rc == PCRE_ERROR_NOMATCH)
      {
          if(options == 0)
            break;
          ovector[1] = start_offset + 1;
          continue;             /* Go round the loop again */
      }

      if(rc < 0)
      {
          printf("Matching error %d\n", rc);
          pcre_free(re);        /* Release memory used for the compiled pattern */
          return NULL;
      }

      if(rc == 0)
      {
          rc = OVECCOUNT / 3;
          printf("ovector only has room for %d captured substrings\n", rc - 1);
      }

      memset(tempString, '\0', MAXLENGTHOFTEMPSTRING);
      if(ovector[3] > -1)
      {
          sprintf(tempString, "%.*s", ovector[3] - ovector[2], subject + ovector[2]);
          temporaryRecords[sizeStrings] = strdup(tempString);
          sizeStrings++;
      }

  }

  pcre_free(re);
  *numberOfStrings = sizeStrings;
  return temporaryRecords;

}

char *returnFirstLine(char *paragraph)
{
  int numberOfStrings = 0;
  char **singleLine = NULL;
  int options = 0;
  char *returnValue = NULL;
  char pattern[] =
      "^\\s*(.+?)(?:(?:\\s*[\n\r]+?)|(?:\\s*</?br[^>]*>)|(?:\\s*</?p[^>]*>)|(?:\\s*</?ul[^>]*>)|(?:\\s*</?ol[^>]*>)|(?:\\s*</?table[^>]*>)|(?:\\s*</?div[^>]*>))";

  options = PCRE_CASELESS;

  singleLine = returnRegExMatch(pattern, paragraph, options, &numberOfStrings);

  if(numberOfStrings < 1 || singleLine == NULL)
  {
      return paragraph;
  }
  else
  {
      returnValue = strdup(singleLine[0]);
      destroy_double_pointer(singleLine, numberOfStrings);
      return returnValue;
  }

}

char *stripRegExPattern(char *pattern, const char *subject, int subject_length, int compiled_options)
{
  pcre *re = NULL;
  int ovector[OVECCOUNT];
  int subjectcushioned = subject_length + MAXLENGTHOFTEMPSTRING;
  int rc = 0;
  int sizeOfString = 0;
  int ii = 0;
  const char *error = NULL;
  int erroffset = 0;
  char storingString[subjectcushioned];
  int options = 0;
  int start_offset = 0;
  char tempString[MAXLENGTHOFTEMPSTRING];
  char space[] = " ";
  char postString[subject_length];

  if(subject == NULL)
  {
      return NULL;
  }
  if(!subject_length)
  {
      return NULL;
  }
  memset(storingString, '\0', subjectcushioned);
  memset(tempString, '\0', MAXLENGTHOFTEMPSTRING);
  memset(postString, '\0', subject_length);

  for (ii = 0; ii < OVECCOUNT; ii++)
  {
      ovector[ii] = -1;
  }

  re = pcre_compile(pattern, compiled_options, &error, &erroffset, NULL);
  if(re == NULL)
  {
      return NULL;
  }

  rc = pcre_exec(re, NULL, subject, subject_length, start_offset, options, ovector, OVECCOUNT);

  if(rc <= 0)
  {
      pcre_free(re);
      re = NULL;
      return NULL;
  }

  if(ovector[0] > 0)
  {
      sprintf(tempString, "%.*s", ovector[0], subject);
      strcat(storingString, tempString);
      memset(tempString, '\0', MAXLENGTHOFTEMPSTRING);
  }
  sizeOfString = strlen(storingString);
  sprintf(postString, "%.*s", (int)(strlen(subject) - ovector[1]), subject + ovector[1]);

  while (1)
  {
      start_offset = ovector[1];        /* Start at end of previous match */
      if(sizeOfString >= subjectcushioned)
      {
          pcre_free(re);
          fprintf(stderr, "Fatal Error the resulting string has overgrow the size is %d\n", sizeOfString);
          return NULL;
      }

      if(rc == PCRE_ERROR_NOMATCH)
      {
          fprintf(stderr, "Errors what are the maches %d\n", rc);
          ovector[1] = start_offset + 1;
          continue;             /* Go round the loop again */
      }

      rc = pcre_exec(re, NULL, subject, subject_length, start_offset, options, ovector, OVECCOUNT);

      if(rc <= 0)
      {
          if(strlen(storingString) > 1 && isspace(storingString[strlen(storingString) - 1]) == 0)
          {
              strcat(storingString, space);
          }

          strcat(storingString, postString);
          while (strlen(storingString) > 1 && isspace(storingString[strlen(storingString) - 1]) != 0)
          {
              storingString[strlen(storingString) - 1] = '\0';
          }

          break;
      }

      if(ovector[0] > 0)
      {
          if(strlen(storingString) > 1 && isspace(storingString[strlen(storingString) - 1]) == 0)
          {
              strcat(storingString, space);
          }
          sprintf(tempString, "%.*s", ovector[0] - start_offset, subject + start_offset);
          strcat(storingString, tempString);
          memset(tempString, '\0', MAXLENGTHOFTEMPSTRING);
      }
      sizeOfString = strlen(storingString);

      memset(postString, '\0', subject_length);
      sprintf(postString, "%.*s", (int)(strlen(subject) - ovector[1]), subject + ovector[1]);

  }

  pcre_free(re);
  re = NULL;

  return strdup(storingString);

}

char *stripHtmlTags(char *value)
{
  char *result;
  char pattern[] = "<\\s*/?[^><]+>\\s*";
  int options = 0;
  int lengthOfValue = 0;

  if(!value)
  {
      return NULL;
  }
  lengthOfValue = strlen(value);

  options = PCRE_CASELESS;
  result = stripRegExPattern(pattern, value, lengthOfValue, options);

  if(!result)
  {
      return strdup(value);
  }
  else
  {
      return result;
  }
}

void destroyDoublePointer(char **ptr, int max_hits)
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
      if(ptr)
      {
          free(ptr);
          ptr = NULL;
      }
  }
}

void timeItNow(char *message)
{
  if(getMyDebug())
  {
    struct timeb tp;
    ftime(&tp);
    long totalSec = (long)(1000.0 * tp.time + tp.millitm);
    fprintf(stderr, "%s = %ld ms\n", message, totalSec);
    fflush(stderr);
  }
  return;
}

void resetMyTiming(time_t myStartTime)
{
  myStartTime = (time_t) time(&myStartTime);
}

void accumulateTime(time_t myStartTime, time_t myEndTime)
{
  time_t currentTime;
  time_t diffTime;

  currentTime = (time_t) time(&currentTime);
  diffTime = currentTime - myStartTime;

  myEndTime += diffTime;
}

char *getSequenceFragment(char *fastafile, long long begin_index, long long end_index)
{
  int fd, ii;
  long genomicOffset = getGenomicOffset();
  char *record_p;

  begin_index += genomicOffset;
  end_index += genomicOffset;

  begin_index -= 1;

  if(!fastafile)
  {
      return NULL;
  }

  if(begin_index < 0 || end_index <= begin_index)
  {
      return NULL;
  }

  fd = open64(fastafile, O_RDONLY | O_LARGEFILE);
  if(fd < 0)
  {
      return NULL;
  }

  if((record_p = (char *)malloc(sizeof(char) * (end_index - begin_index + 2))) == NULL)
  {
    return NULL;
  }
  memset(record_p, '\0', (end_index - begin_index + 2));
  ii = pread64(fd, record_p, (size_t) (sizeof(char) * (end_index - begin_index)), (off64_t) begin_index);
  if(ii < 0)
  {
    return NULL;
  }

  *(record_p + ii) = 0;
  close(fd);
  return record_p;
}

int getTextSizeFromFid(int uploadId, long fid, char type, long limit)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  int counter = getDatabasePositionFromUploadId(uploadId);
  int sizeOfText = 0;

  if(counter < 0)
  {
      return 0;
  }

  resetLocalConnection(getDatabaseFromId(counter));
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);

  sprintf(sqlbuff, "SELECT left(text, %ld) FROM fidText WHERE " "fid = %ld and textType = '%c'", limit, fid, type);

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      return 0;
  }

  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult) == 0)
  {
      mysql_free_result(sqlresult);
      return 0;
  }

  if((row = mysql_fetch_row(sqlresult)) != NULL)
  {
      sizeOfText = strlen(row[0]);
  }

  mysql_free_result(sqlresult);
  resetLocalConnection(getDatabaseFromId(0));
  return sizeOfText;
}

int printTextSizeFromFid(gdImagePtr im, gdFontPtr font, int uploadId, long fid,
                         char type, long limit, int sizeToCopy, int x, int y, int colorToUse)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  int counter = getDatabasePositionFromUploadId(uploadId);
  char textResults[255] = "";
  char reusableText[255] = "";

  if(counter < 0)
    return 0;

  resetLocalConnection(getDatabaseFromId(counter));
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);

  sprintf(sqlbuff, "SELECT left(text, %ld) FROM fidText WHERE " "fid = %ld and textType = '%c'", limit, fid, type);

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      return 0;
  }

  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult) == 0)
  {
      return 0;
  }

  if((row = mysql_fetch_row(sqlresult)) != NULL)
  {
      strcpy(textResults, row[0]);
  }

  mysql_free_result(sqlresult);
  resetLocalConnection(getDatabaseFromId(0));

  if(strlen(textResults) < 1)
  {
      return 0;
  }

  strncpy(reusableText, textResults, sizeToCopy);
  if(strlen(textResults) > sizeToCopy)
  {
      reusableText[sizeToCopy - 2] = '.';
      reusableText[sizeToCopy - 1] = '.';
      reusableText[sizeToCopy] = '.';
  }

  gdImageString(im, font, x, y, (unsigned char *)reusableText, colorToUse);
  resetLocalConnection(getDatabaseFromId(0));
  return 1;
}

char *getTextFromFid(int uploadId, long fid, int ftypeid, char type, long limit)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  int counter = getDatabasePositionFromUploadId(uploadId);
  char textResults[2555] = "";
  if(counter < 0)
  {
    return NULL;
  }

  resetLocalConnection(getDatabaseFromId(counter));
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);

  sprintf(sqlbuff, "SELECT left(text, %ld) FROM fidText WHERE "
          "fid = %ld AND textType = '%c' AND ftypeid = %d", limit, fid, type, ftypeid);

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
    return NULL;

  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult) == 0)
  {
    return NULL;
  }

  if((row = mysql_fetch_row(sqlresult)) != NULL)
  {
    strcpy(textResults, row[0]);
  }

  mysql_free_result(sqlresult);
  resetLocalConnection(getDatabaseFromId(counter));
  return strdup(textResults);
}

char *getValueFromAttValueId(int databaseIndex, int attValueId, long limit)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  int counter = databaseIndex;
  char textResults[2555] = "";

  if(counter < 0)
  {
      return NULL;
  }

  resetLocalConnection(getDatabaseFromId(counter));
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);

  sprintf(sqlbuff, "SELECT left(value, %ld) FROM attValues WHERE attValueId  = '%d'", limit, attValueId);

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
    return NULL;

  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult) == 0)
  {
      return NULL;
  }

  if((row = mysql_fetch_row(sqlresult)) != NULL)
  {
      strcpy(textResults, row[0]);
  }

  mysql_free_result(sqlresult);
  resetLocalConnection(getDatabaseFromId(0));
  return strdup(textResults);
}

int getAttNameIdFromName(int databaseIndex, char *name)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  int counter = databaseIndex;
  int attNameId = -20;

  if(counter < 0)
  {
    return attNameId;
  }

  resetLocalConnection(getDatabaseFromId(counter));
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);

  sprintf(sqlbuff, "SELECT attNameId FROM attNames WHERE name = '%s'", name);

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
    return attNameId;
  }

  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult) == 0)
  {
    return attNameId;
  }

  if((row = mysql_fetch_row(sqlresult)) != NULL)
  {
    attNameId = atoi(row[0]);
  }

  mysql_free_result(sqlresult);
  resetLocalConnection(getDatabaseFromId(counter));
  return attNameId;
}

int getFirstAttValueIdForAttId(int databaseIndex, long fid, int ftypeid, int attNameId)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  int counter = databaseIndex;
  int attValueId = -20;

  if(counter < 0)
    return attValueId;

  resetLocalConnection(getDatabaseFromId(counter));
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);

  sprintf(sqlbuff, "SELECT attValueId FROM fid2attribute WHERE fid = %ld AND attNameId = %d", fid, attNameId);

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
    return attValueId;
  }

  sqlresult = mysql_store_result(connection);
  if(mysql_num_rows(sqlresult) == 0)
  {
    mysql_free_result(sqlresult);
    return attValueId;
  }
  if((row = mysql_fetch_row(sqlresult)) != NULL)
  {
    attValueId = atoi(row[0]);
  }
  mysql_free_result(sqlresult);
  resetLocalConnection(getDatabaseFromId(counter));
  return attValueId;
}

char *getVPValueFromFid(int uploadId, long fid, int ftypeid, char *name, long limit)
{
  int counter = -20;
  char *vpValue = NULL;
  int attNameId = -20;
  int attValueId = -20;
  int *nameId;
  int *valueId;
  counter = getDatabasePositionFromUploadId(uploadId);
  if(counter < 0)
  {
    return NULL;
  }
  if(name == NULL || strlen(name) < 1)
  {
    return NULL;
  }
  if(counter == 1){
    attNameHashTemplate = getAttNameIdHashTemplate() ;
    nameId = (int *)g_hash_table_lookup(attNameHashTemplate, name) ;
    attNameId = *nameId ;
  }
  else{
    attNameId = getAttNameIdFromName(counter, name) ;
    attNameHashUser = getAttNameIdHashUser() ;
    nameId = (int *)g_hash_table_lookup(attNameHashUser, name) ;
    attNameId = *nameId ;
  }
  if(attNameId < 1)
  {
    return NULL;
  }
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  resetLocalConnection(getDatabaseFromId(counter));
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);
  sprintf(sqlbuff, "SELECT value FROM attValues, fid2attribute WHERE attValues.attValueId = fid2attribute.attValueId AND fid2attribute.fid = %d AND fid2attribute.attNameId = %d", fid, attNameId);
  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
    return NULL;
  }
  sqlresult = mysql_store_result(connection);
  if(mysql_num_rows(sqlresult) == 0)
  {
    mysql_free_result(sqlresult);
    return NULL;
  }
  if(row = mysql_fetch_row(sqlresult))
  {
    vpValue = strdup(row[0]);
  }
  mysql_free_result(sqlresult);
  resetLocalConnection(getDatabaseFromId(counter));
  return vpValue;
}

int verifyDatabaseId(char *query)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING];
  int newRefSeqId = 0;
  MYSQL *connection = returnLocalConnection(1);
  MYSQL mysql = returnMyMYSQL(1);
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;

  sprintf(sqlbuff, query);

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
    fprintf(stderr, "Error querying the genboree database.\n");
    fprintf(stderr, mysql_error(&mysql));
    fflush(stderr);
    return 0;
  }
  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult) == 0)
  {
    fprintf(stderr, "User does not have permission to access this database #verifyDatabaseId.\n");
    fflush(stderr);
    mysql_free_result(sqlresult);
    return 0;
  }

  if((row = mysql_fetch_row(sqlresult)) != NULL)
  {
    newRefSeqId = atoi(row[0]);
  }

  mysql_free_result(sqlresult);
  return newRefSeqId;
}

void printDatabases(void)
{
  char **databaseName = getDatabaseNames();
  int counter = 0;
  int numberDatabases = getNumberDatabases();

  while (numberDatabases > counter)
  {
    fprintf(stderr, "%s\n", databaseName[counter]);
    fflush(stderr);
    counter++;
  }
  return;
}

int isDatabaseNewFormat(int uploadId)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING];
  int useVP = -2;
  MYSQL *connection = returnLocalConnection(1);
  MYSQL mysql = returnMyMYSQL(1);
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  char *tempResult = NULL;
  char query[2555];

  sprintf(query,
          "SELECT refseq.useValuePairs FROM refseq, upload WHERE upload.databaseName = refseq.databaseName AND uploadId = %d",
          uploadId);

  sprintf(sqlbuff, query);

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      fprintf(stderr, "Error querying the genboree database.\n");
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return -1;
  }
  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult) == 0)
  {
      fprintf(stderr, "User does not have permission to access this database #isDatabaseNewFormat.\n");
      fflush(stderr);
      mysql_free_result(sqlresult);
      return -1;
  }

  if((row = mysql_fetch_row(sqlresult)) != NULL)
  {
      tempResult = row[0];
  }

  if(tempResult == NULL)
  {
      fprintf(stderr, "Error querying the genboree database.\nthe query is %s", query);
      fflush(stderr);
      mysql_free_result(sqlresult);
      return -1;
  }

  if(tempResult[0] == 'y')
  {
      useVP = 1;
  }
  else
  {
      useVP = 0;
  }

  mysql_free_result(sqlresult);
  return useVP;
}

int fetchGenboreeGroup(long refSeqId)
{
  int groupId = 0;
  char sqlbuff[MAXLENGTHOFTEMPSTRING];
  MYSQL *connection = returnLocalConnection(1);
  MYSQL mysql = returnMyMYSQL(1);
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;

  sprintf(sqlbuff,
          "SELECT grouprefseq.groupId FROM grouprefseq, genboreegroup WHERE genboreegroup.groupId = grouprefseq.groupId AND grouprefseq.refSeqId = %ld",
          refSeqId);

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      fprintf(stderr, "Error querying the genboree database.\n");
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return 0;
  }

  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult) == 0)
  {
      fprintf(stderr, "User does not have permission to access this database #fetchGenboreeGroup.\n");
      fflush(stderr);
      mysql_free_result(sqlresult);
      return 0;
  }

  if((row = mysql_fetch_row(sqlresult)) != NULL)
  {
      groupId = atoi(row[0]);
  }

  mysql_free_result(sqlresult);
  return groupId;
}

int validateForm(int refSeqId)
{
  char query[2555];
  int newRefSeqId = 0;
  long theUserId = getMyUserId();
  int groupId = 0;

  groupId = fetchGenboreeGroup(refSeqId);
  if(groupId > 0)
    setGenboreeGroupId(groupId);

  if(theUserId < 1)
  {
      sprintf(query,
              "SELECT distinct(refseq.refSeqId) refSeqId FROM refseq, genboreegroup, usergroup, grouprefseq WHERE genboreegroup.groupId = grouprefseq.groupId and grouprefseq.refSeqId = refseq.refSeqId and genboreegroup.groupName = 'Public' and refseq.refSeqId = %d",
              refSeqId);
  }
  else
  {
      sprintf(query,
              "SELECT distinct(refseq.refSeqId) refSeqId FROM refseq, genboreegroup, usergroup, genboreeuser, grouprefseq where genboreeuser.userId = usergroup.userId and genboreegroup.groupId = usergroup.groupId and genboreegroup.groupId = grouprefseq.groupId and grouprefseq.refSeqId = refseq.refSeqId and genboreeuser.userId = %d and refseq.refSeqId = %d",
              (int)theUserId, refSeqId);
  }

  newRefSeqId = verifyDatabaseId(query);

  if(!newRefSeqId)
  {
      printDatabases();
      fprintf(stderr, "The query is %s\n", query);
      fflush(stderr);
  }

  return newRefSeqId;
}

int returnTagLength(char *myString)
{
  int lengthMyString = strlen(myString);
  int len = 0;
  char *theKey;
  GHashTable *myTagHash = getTagsHash();
  int found = 0;
  int ii = 0;
  GList *listOfTags = g_hash_table_get_keys(myTagHash);

  if(!myString || strlen(myString) < 3)
  {
      return 0;
  }

  if(lengthMyString > 4)
  {
      if(myString[0] == '$' && myString[1] == '{' && myString[2] == '"')
      {
          ii = 3;
          while (ii < lengthMyString && !found)
          {
              if(myString[ii] == '}')
              {
                  found = 1;
              }
              ii++;
          }
          if(found)
          {
              return ii;
          }
      }
  }

  while (listOfTags)
  {
      int *theData = NULL;
      theKey = (char *)listOfTags->data;
      theData = g_hash_table_lookup(myTagHash, theKey);
      len = strlen((char *)theKey);
      if(len > lengthMyString)
      {
          listOfTags = g_list_next(listOfTags);
          continue;
      }

      if(!strncmp(myString, theKey, len))
      {
          if(*theData != 20)
          {
              return len;
          }
          else
          {
              len = findRegExSize(myString);
              return len;
          }
      }
      listOfTags = g_list_next(listOfTags);
  }

  return 0;
}

char **processLinkString(char *myString, int *numberOfStrings)
{
  int ii = 0;
  char *myStringCopy = NULL;
  char **temporaryRecords = NULL;
  char *found;
  char *initialString;
  char *after;
  char tempSave = 0;
  char dollarSign = '$';
  int lengthTag = 0;
  int numberOfEncounters = 0;

  *numberOfStrings = 0;

  if(!myString || strlen(myString) < 1)
  {
      return NULL;
  }

  myStringCopy = strdup(myString);
  initialString = myStringCopy;

  numberOfEncounters = 0;
  while (initialString)
  {
      initialString = strchr(initialString, (int)dollarSign);
      if(initialString)
        initialString++;
      numberOfEncounters++;
  }

  numberOfEncounters *= 2;

  if(!numberOfEncounters)
  {
      return NULL;
  }

  temporaryRecords = (char **)calloc((numberOfEncounters + 6), sizeof(char *));

  initialString = myStringCopy;
  ii = 0;

  while (initialString && strlen(initialString) > 0)
  {
      found = strchr(initialString, (int)dollarSign);
      if(found)
      {
          lengthTag = returnTagLength(found);
          if(!lengthTag)
          {
              lengthTag = 1;
          }
          tempSave = *found;
          *found = '\0';
          if(initialString && strlen(initialString) > 0)
          {
              temporaryRecords[ii] = strdup(initialString);
              ii++;
          }
          *found = tempSave;
          after = found + lengthTag;
          tempSave = *after;
          *after = '\0';
          temporaryRecords[ii] = strdup(found);
          ii++;
          *after = tempSave;
          initialString = after;
          found = NULL;
      }
      else
      {
          temporaryRecords[ii] = strdup(initialString);
          ii++;
          initialString = NULL;
      }
  }
  *numberOfStrings = ii;

  free(myStringCopy);
  myStringCopy = NULL;
  return temporaryRecords;
}

inline int returnTransformedValue(unsigned long theValue)
{
  int b_start = 0;
  double myDValue = 0.0;
  long long initialValue = 0;
  unsigned long myOwnValue = 0;

  if(theValue < startPositionGlobal)
  {
      myOwnValue = startPositionGlobal;
  }
  if(theValue > endPositionGloblal)
  {
      myOwnValue = endPositionGloblal;
  }

  initialValue = theValue - startPositionGlobal;
  myDValue = (double)(initialValue * universalScaleGlobal);
  b_start = (int)ceil(myDValue + labelWidthGlobal);
  if(b_start < labelWidthGlobal)
  {
      b_start = labelWidthGlobal;
  }
  if(b_start > totalWidthGlobal)
  {
      b_start = totalWidthGlobal;
  }

  return b_start;
}

int fillGroupLevel(myTrack * myLocalTrack)
{
  int level = 0;
  int maxLevel = 0;
  long *endsArr = NULL;
  long tempValue = 0;
  int ii;
  myGroup *initialGroup = myLocalTrack->groups;
  myGroup *currentGroup = NULL;
  myAnnotations *currentAnnotation = NULL;
  int groupAware = getGroupAwareness(myLocalTrack->style);
  int numberOfTiers = MAXNUMBERLINESINTRACK;
  int positionValue = 0;
  int addValue = 0;
  int increaseMax = 0;
  int isPieChart = 0;
  int isUsingGroupContextInfo = 0;
  int hasHead = 0;
  int hasTail = 0;
  int isComplete = 0;
  int needAdjustment = 0;
  int modifyGroup = 0;
  unsigned long tempStart = 0;
  unsigned long tempEnd = 0;

  if(myLocalTrack->vis == VIS_DENSEMC || myLocalTrack->vis == VIS_DENSE)
  {
      if(strcasecmp(myLocalTrack->style, "pieChart_draw") == 0)
      {
          free(myLocalTrack->style);
          myLocalTrack->style = NULL;
          myLocalTrack->style = strdup(PIECHARTSUBSTITUTION);
      }
  }
  else if(myLocalTrack->vis == VIS_FULL || myLocalTrack->vis == VIS_FULLNAME || myLocalTrack->vis == VIS_FULLTEXT)
  {
      needAdjustment = 1;
  }

  if(strcasecmp(myLocalTrack->style, "pieChart_draw") == 0)
    isPieChart = 1;

  if(myLocalTrack->vis == VIS_FULLNAME || myLocalTrack->vis == VIS_FULLTEXT)
  {
      addValue = ADDVALUE;
  }

  if((endsArr = (long *)calloc((size_t) (numberOfTiers + 6), sizeof(long))) == NULL)
  {
      fprintf(stderr, "Could not allocate enough memory for fillGroupLevel array.\n");
      fflush(stderr);
      return 0;
  }

  for (ii = 0; ii < numberOfTiers + 5; ii++)
  {
      endsArr[level] = 0;
  }

  if(groupAware)
  {
      maxLevel = 0;
      for (currentGroup = initialGroup; currentGroup; currentGroup = currentGroup->next)
      {
          hasHead = hasTail = isComplete = modifyGroup = 0;

          if(currentGroup->groupContextPresent == 1 && needAdjustment)
          {
              isUsingGroupContextInfo = 1;
              modifyGroup = 1;
              if(currentGroup->hasU)
              {
                  hasHead = hasTail = isComplete = 1;
              }
              else if(currentGroup->hasF && !currentGroup->containsBrokenAnnotationAtStart)
              {
                  hasHead = 1;
                  if(currentGroup->hasL && !currentGroup->containsBrokenAnnotationAtEnd)
                  {
                      hasTail = 1;
                      isComplete = 1;
                  }
              }
              else
              {
                  if(currentGroup->hasL && !currentGroup->containsBrokenAnnotationAtEnd)
                  {
                      hasTail = 1;
                  }
              }
          }

          for (level = 0; level < numberOfTiers; level++)
          {

              if(modifyGroup && !isComplete && !hasHead)
              {
                  tempStart = startPositionGlobal;
              }
              else
              {
                  tempStart = currentGroup->groupStart;
              }

              if(modifyGroup && !isComplete && !hasTail)
              {
                  tempEnd = endPositionGloblal;
              }
              else
              {
                  tempEnd = currentGroup->groupEnd;
              }

              positionValue = returnTransformedValue(tempStart);
              if(positionValue > endsArr[level])
              {
                  currentGroup->level = level;
                  endsArr[level] = returnTransformedValue(tempEnd) + addValue;
                  if(level > maxLevel)
                  {
                      maxLevel = level;
                  }
                  break;
              }
          }
      }

      for (currentGroup = initialGroup; currentGroup; currentGroup = currentGroup->next)
      {
          if(currentGroup->level == -1)
          {
              currentGroup->level = maxLevel + 1;
              increaseMax = 1;
          }
      }
      if(increaseMax)
      {
          maxLevel++;
      }
  }
  else
  {
      for (currentGroup = initialGroup; currentGroup; currentGroup = currentGroup->next)
      {
          currentGroup->level = -1;
          currentAnnotation = currentGroup->annotations;
          while (currentAnnotation)
          {
              for (level = 0; level < numberOfTiers; level++)
              {
                  positionValue = returnTransformedValue(currentAnnotation->start);
                  if(positionValue > endsArr[level])
                  {
                      currentAnnotation->level = level;

                      if(isPieChart)
                      {
                          tempValue = positionValue + addValue + 22;
                          if(tempValue > totalWidthGlobal)
                          {
                              tempValue = totalWidthGlobal;
                          }
                          endsArr[level] = tempValue;
                          tempValue = 0;
                          //Piechart track is a SPECIAL track the image map is generated in a different way
                      }
                      else
                      {
                          endsArr[level] = returnTransformedValue(currentAnnotation->end) + addValue;
                      }
                      if(level > maxLevel)
                      {
                          maxLevel = level;
                      }
                      break;
                  }
              }
              currentAnnotation = currentAnnotation->next;
          }
      }
      for (currentGroup = initialGroup; currentGroup; currentGroup = currentGroup->next)
      {
          currentAnnotation = currentGroup->annotations;
          while (currentAnnotation)
          {
              if(currentAnnotation->level == -1)
              {
                  currentAnnotation->level = maxLevel + 1;
                  increaseMax = 1;
              }
              currentAnnotation = currentAnnotation->next;
          }
      }
      if(increaseMax)
      {
          maxLevel++;
      }
  }

  free(endsArr);
  endsArr = NULL;

  return maxLevel;
}

myGroup *makeGroup(char *groupClass, char *groupName, int groupId, char *allGroupClasses)
{
  myGroup *localmyGroup = NULL;
  if(!groupClass || !groupName || !groupId)
    return NULL;
  if((localmyGroup = (myGroup *) malloc(sizeof(myGroup))) == NULL)
    return NULL;
  localmyGroup->next = NULL;
  localmyGroup->parentTrack = NULL;
  localmyGroup->groupId = groupId;
  localmyGroup->allGroupClasses = allGroupClasses;
  localmyGroup->groupName = strdup(groupName);
  localmyGroup->groupClass = strdup(groupClass);
  localmyGroup->groupStart = 999999999;
  localmyGroup->groupEnd = 0;
  localmyGroup->level = -1;
  localmyGroup->height = TRACK_HEIGHT;
  localmyGroup->numberOfAnnotations = 0;
  localmyGroup->annotations = NULL;
  localmyGroup->lastAnnotation = NULL;
  localmyGroup->hasU = 0;
  localmyGroup->hasL = 0;
  localmyGroup->hasF = 0;
  localmyGroup->groupContextPresent = 0;
  localmyGroup->containsBrokenAnnotationAtStart = 0;
  localmyGroup->containsBrokenAnnotationAtEnd = 0;
  return localmyGroup;
}

void deleteListGroups(myGroup * localmyGroup)
{
  myGroup *nextGroup;

  while (localmyGroup)
  {
      nextGroup = localmyGroup->next;
      deleteGroup(localmyGroup);
      localmyGroup = nextGroup;
  }
  return;
}

void eraseGroup(gpointer data)
{
  myGroup *localmyGroup = (myGroup *) data;
  deleteGroup(localmyGroup);
  return;
}

void deleteGroup(myGroup * localmyGroup)
{
  free(localmyGroup->groupName);
  free(localmyGroup->groupClass);
  free(localmyGroup->allGroupClasses);
  deleteListAnnotations(localmyGroup->annotations);
  free(localmyGroup);
  localmyGroup = NULL;
  return;
}

void deleteListAnnotations(myAnnotations * localAnnotation)
{
  myAnnotations *nextAnnotation;

  while (localAnnotation)
  {
      nextAnnotation = localAnnotation->next;
      deleteAnnotation(localAnnotation);
      localAnnotation = nextAnnotation;
  }
  return;
}

void deleteAnnotation(myAnnotations * localAnnotation)
{
  free(localAnnotation);
  localAnnotation = NULL;
  return;
}

myAnnotations *makeAnnotation(void)
{
  myAnnotations *localAnnotation;
  if((localAnnotation = (myAnnotations *) calloc(1, sizeof(myAnnotations))) == NULL)
  {
      fprintf(stderr, "Could not allocate enough memory for annotation structure.\n");
      return NULL;
  }
  localAnnotation->next = NULL;
  localAnnotation->parentGroup = NULL;
  localAnnotation->id = 0;
  localAnnotation->start = 0;
  localAnnotation->end = 0;
  localAnnotation->uploadId = 0;
  localAnnotation->tstart = 0;
  localAnnotation->tend = 0;
  localAnnotation->ftypeid = 0;
  localAnnotation->level = -1;
  localAnnotation->score = 0.0;
  localAnnotation->height = TRACK_HEIGHT;
  localAnnotation->orientation = (char)0;
  localAnnotation->phase = 0;
  localAnnotation->textExist = 0;
  localAnnotation->sequenceExist = 0;
  localAnnotation->displayCode = -1;
  localAnnotation->displayColor = -1;
  localAnnotation->groupContextCode = (char)0;
  memset(localAnnotation->fidStr, '\0', 55);
  localAnnotation->blockInfo = NULL;
  return localAnnotation;
}

myTrack *makeTrack(void)
{
  myTrack *localTrack;
  if((localTrack = (myTrack *) calloc(1, sizeof(myTrack))) == NULL)
  {
      fprintf(stderr, "Could not allocate enough memory for tracks structure.\n");
      return NULL;
  }
  localTrack->next = NULL;
  localTrack->groups = NULL;
  localTrack->height = 0;
  localTrack->trackName = NULL;
  localTrack->vis = 0;
  localTrack->numberOfGroups = 0;
  localTrack->linkTemplates = NULL;
  localTrack->numberOfTemplates = 0;
  localTrack->style = NULL;
  localTrack->color = NULL;
  localTrack->listOfGroups = NULL;
  localTrack->trackUrlInfo = NULL;
  localTrack->maxLevel = 0;
  localTrack->specialTrack = 0;
  localTrack->maxScore = 0.0;
  localTrack->minScore = 0.0;
  localTrack->isHighDensityTrack = 0;
  localTrack->pixelExtraValues = NULL;
  localTrack->pixelValueForHDT = NULL;
  localTrack->pixelNegativeValueForHDT = NULL;
  localTrack->pixelExtraNegativeValues = NULL;
  localTrack->highDensFtypes = NULL;
  localTrack->annotationsForHDHVTrack = NULL;
  localTrack->numberOfHdhvAnnotations = 0;
  return localTrack;
}

void eraseTrack(gpointer data)
{
  myTrack *localTrack = (myTrack *) data;
  deleteTrack(localTrack);
  return;
}

void deleteTrack(myTrack * localTrack)
{
  free(localTrack->trackName);
  destroyDoublePointer(localTrack->linkTemplates, localTrack->numberOfTemplates);
  free(localTrack->style);
  free(localTrack->color);
  deleteTrackUrlInfo(localTrack->trackUrlInfo);
  deleteListGroups(localTrack->groups);
  free(localTrack);
  localTrack = NULL;
  return;
}

void deleteTrackUrlInfo(myTrackUrlInfo * localTrackInfo)
{
  free(localTrackInfo->url);
  free(localTrackInfo->urlDescription);
  free(localTrackInfo->shortUrlDesc);
  free(localTrackInfo->urlLabel);
  free(localTrackInfo);
  localTrackInfo = NULL;
  return;
}

myTrackUrlInfo *createTrackUrlInfo(void)
{
  myTrackUrlInfo *localTrackUrlInfo;
  localTrackUrlInfo = (myTrackUrlInfo *) calloc(1, sizeof(myTrackUrlInfo));
  if(localTrackUrlInfo == NULL)
  {
      fprintf(stderr, "Could not allocate enough memory for trackUrlInfo structure.\n");
      return NULL;
  }
  localTrackUrlInfo->url = NULL;
  localTrackUrlInfo->urlDescription = NULL;
  localTrackUrlInfo->urlLabel = NULL;
  localTrackUrlInfo->shortUrlDesc = NULL;

  return localTrackUrlInfo;
}

arrayOfStrings *createArrayOfStrings(char **arrayString, int numberOfStrings)
{
  arrayOfStrings *myArrayOfStrings;
  myArrayOfStrings = (arrayOfStrings *) calloc(1, sizeof(arrayOfStrings));
  if(myArrayOfStrings == NULL)
  {
      fprintf(stderr, "Could not allocate enough memory for arrayOfStrings structure.\n");
      return NULL;
  }
  myArrayOfStrings->strings = arrayString;
  myArrayOfStrings->numberOfStrings = numberOfStrings;

  return myArrayOfStrings;
}

groupStartingPoint *createListOfGroups(int lengthOfList)
{
  groupStartingPoint *localListOfGroups = NULL;

  if((localListOfGroups =
      (groupStartingPoint *) calloc((size_t) (lengthOfList + 6), sizeof(groupStartingPoint))) == NULL)
  {
      fprintf(stderr, "Could not allocate enough memory for localListOfGroups array.\n");
      fflush(stderr);
      return NULL;
  }

  return localListOfGroups;
}

long *createListOfGroupStarts(int lengthOfList)
{
  long *localListOfGroupStarts = NULL;

  if((localListOfGroupStarts = (long *)calloc((size_t) (lengthOfList + 6), sizeof(long))) == NULL)
  {
      fprintf(stderr, "Could not allocate enough memory for localListOfGroups array.\n");
      fflush(stderr);
      return NULL;
  }
  return localListOfGroupStarts;
}

void cleanListOfGroups(int *localListOfGroups, int maxSize)
{
  int ii = 0;

  for (ii = 0; ii < maxSize; ii++)
  {
      localListOfGroups[ii] = 0;
  }
}

char *getDatabaseFromId(int databaseNumber)
{
  char **databaseName = getDatabaseNames();

  if(databaseNumber <= getNumberDatabases())
  {
      return databaseName[databaseNumber];
  }
  else
  {
      return NULL;
  }
}

int getDatabasePositionFromUploadId(int uploadId)
{
  int ii = 0;
  int *myArrayUploadIds = getArrayUploadIds();

  while (myArrayUploadIds[ii] != -1)
  {
      if(uploadId == myArrayUploadIds[ii])
      {
          return ii;
      }
      ii++;
  }

  return -1;
}

int returnCompactWidth()
{
  int width = 0;
  int logOfSegment = (int)log10(lengthOfSegmentGlobal);

  if(logOfSegment <= 5)
  {
      width = 4;
  }
  else if(logOfSegment == 6)
  {
      width = 3;
  }
  else if(logOfSegment == 7)
  {
      width = 2;
  }
  else
  {
      width = 1;
  }

  return width;
}

void deleteArrayOfOrderedTracks(void)
{
  int numberOfRecords = getMaxOrder();
  char **myTracksInOrder = getArrayOrderedTracks();
  int ii = 0;

  for (ii = 0; ii <= numberOfRecords; ii++)
  {
      if(myTracksInOrder[ii] != NULL && strlen(myTracksInOrder[ii]) > 0)
      {
          free(myTracksInOrder[ii]);
          myTracksInOrder[ii] = NULL;
      }
  }
  if(myTracksInOrder != NULL)
  {
      free(myTracksInOrder);
      myTracksInOrder = NULL;
  }

}

void eliminateEmptyTracks(void)
{
  myTrack *ptrTrack = NULL;
  myTrack *listTrack = NULL;
  myTrack *newTrackList = NULL;
  myTrack *tempTrack = NULL;
  myTrack *emptyTrack = NULL;
  myTrack *firstNewTrack = NULL;
  myTrack *firstEmptyTrack = NULL;
  int numberOfRecords = getMaxOrder();
  char **myTracksInOrder = getArrayOrderedTracks();
  GHashTable *myTrack2Name = getTrackName2TrackHash();
  int new = 0;
  int empty = 0;
  int ii = 0;

  ptrTrack = getTrackList();
  while (ptrTrack)
  {
    if(ptrTrack->numberOfGroups > 0)
    {
      if(new)
      {
        newTrackList->next = ptrTrack;
        newTrackList = newTrackList->next;
      }
      else
      {
        newTrackList = ptrTrack;
        firstNewTrack = newTrackList;
      }
      tempTrack = ptrTrack->next;
      newTrackList->next = NULL;
      new++;
    }
    else if(ptrTrack->isHighDensityTrack && ptrTrack->vis != VIS_HIDE)
    {
      if(new)
      {
        newTrackList->next = ptrTrack;
        newTrackList = newTrackList->next;
      }
      else
      {
        newTrackList = ptrTrack;
        firstNewTrack = newTrackList;
      }
      tempTrack = ptrTrack->next;
      newTrackList->next = NULL;
      new++;
    }
    else
    {
      if(empty)
      {
        emptyTrack->next = ptrTrack;
        emptyTrack = emptyTrack->next;
      }
      else
      {
        emptyTrack = ptrTrack;
        firstEmptyTrack = emptyTrack;
      }
      tempTrack = ptrTrack->next;
      emptyTrack->next = NULL;
      empty++;
    }

    ptrTrack = tempTrack;
  }

  setTrackList(firstNewTrack);
  setEmptyTrackList(firstEmptyTrack);

  for (ii = 0; ii <= numberOfRecords; ii++)
  {
    if(myTracksInOrder[ii] && strlen(myTracksInOrder[ii]) > 1)
    {
      listTrack = (myTrack *) g_hash_table_lookup(myTrack2Name, myTracksInOrder[ii]);
      if(!listTrack)
      {
        free(myTracksInOrder[ii]);
        myTracksInOrder[ii] = NULL;
      }
      else
      {
        if(listTrack->isHighDensityTrack && listTrack->vis != VIS_HIDE)
        {
//skip the high density tracks
        }
        else if(listTrack->groups == NULL)
        {
          free(myTracksInOrder[ii]);
          myTracksInOrder[ii] = NULL;
          listTrack = NULL;
        }

      }

    }
  }

  setArrayOrderedTracks(myTracksInOrder);

  return;
}

void destroyEmptyTrackList(void)
{
  myTrack *tempTrack = NULL;
  myTrack *emptyTrack = getEmptyTrackList();

  while (emptyTrack)
  {
    tempTrack = emptyTrack->next;
    free(emptyTrack->trackName);
    emptyTrack->trackName = NULL;
    destroyDoublePointer(emptyTrack->linkTemplates, emptyTrack->numberOfTemplates);
    free(emptyTrack->style);
    emptyTrack->style = NULL;
    free(emptyTrack->color);
    emptyTrack->color = NULL;
    free(emptyTrack);
    emptyTrack = NULL;
    emptyTrack = tempTrack;
  }

  return;
}

int requestFtypeIdFromDB(char *fmethod, char *fsource, int databaseId)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  char *end;
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  int ftypeId = 0;
  int numberOfFtypes = 0;
  char *blackList = getTrackBlackList(databaseId);

  resetLocalConnection(getDatabaseFromId(databaseId));
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);

  end = strmov(sqlbuff, "SELECT ftypeid FROM ftype WHERE fmethod = ");
  *end++ = '\'';
  end += mysql_real_escape_string(connection, end, fmethod, strlen(fmethod));
  *end++ = '\'';
  end = strmov(end, " and fsource = ");
  *end++ = '\'';
  end += mysql_real_escape_string(connection, end, fsource, strlen(fsource));
  *end++ = '\'';
  strcat(sqlbuff, blackList);

  if(mysql_real_query(connection, sqlbuff, (unsigned int)(end - sqlbuff)))
  {
      fprintf(stderr, "Error querying the ftype table in function requestFtypeIdFromDB.\n");
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return 0;
  }

  sqlresult = mysql_store_result(connection);

  numberOfFtypes = mysql_num_rows(sqlresult);
  if(numberOfFtypes)
  {
      if((row = mysql_fetch_row(sqlresult)))
        ftypeId = atoi(row[0]);
  }

  mysql_free_result(sqlresult);
  resetLocalConnection(getDatabaseFromId(0));
  return ftypeId;
}

float requestMinScore(int ftypeId, int counter, int localRange)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  float minScore = 0.0;
  char *queryWithBin = NULL;
  char baseQuery[] = "SELECT MIN(fscore) FROM fdata2 WHERE";

  resetLocalConnection(getDatabaseFromId(counter));
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);

  if(localRange)
  {
    queryWithBin = appendMaxMinBinToQuery(counter, baseQuery);
    sprintf(sqlbuff, "%s (%d)", queryWithBin, ftypeId);
    free(queryWithBin);
    queryWithBin = NULL;
  }
  else
  {
    sprintf(sqlbuff, "%s ftypeId = %d", baseQuery, ftypeId);
  }

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
    fprintf(stderr, "Error querying the genboree database (getData).\n");
    fprintf(stderr, mysql_error(&mysql));
    fflush(stderr);
    return 0;
  }
  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult) == 0)
  {
    fprintf(stderr, "No records found \n");
    fflush(stderr);
    return 0;
  }

  if((row = mysql_fetch_row(sqlresult)) != NULL)
  {
    if(row[0])
      minScore = atof(row[0]) ;
  }
  mysql_free_result(sqlresult);
  resetLocalConnection(getDatabaseFromId(0));
  return minScore;
}

float requestMaxScore(int ftypeId, int counter, int localRange)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  char sqlbuffer[MAXLENGTHOFTEMPSTRING] = ""; // for querying user max
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  float maxScore = 0.0;
  char *queryWithBin = NULL;
  char baseQuery[] = "SELECT MAX(fscore) FROM fdata2 WHERE";

  resetLocalConnection(getDatabaseFromId(counter));
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);

  if(localRange)
  {
    queryWithBin = appendMaxMinBinToQuery(counter, baseQuery);
    sprintf(sqlbuff, "%s (%d)", queryWithBin, ftypeId);
    free(queryWithBin);
    queryWithBin = NULL;
  }
  else
  {
    // Check the 'gbTrackUserMax' attribute first
    char userMaxQuery[] = "select ftypeAttrValues.value from ftypeAttrValues, ftype2attributes, ftypeAttrNames where ftype2attributes.ftype_id = " ;
    sprintf(sqlbuffer, "%s %d and ftypeAttrNames.name = 'gbTrackUserMax' and ftypeAttrNames.id = ftype2attributes.ftypeAttrName_id and ftypeAttrValues.id = ftype2attributes.ftypeAttrValue_id", userMaxQuery, ftypeId) ;
    if(mysql_real_query(connection, sqlbuffer, strlen(sqlbuffer)) != 0)
    {
      fprintf(stderr, "Error querying the genboree database (getData).\n");
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return 0;
    }
    sqlresult = mysql_store_result(connection);
    if(mysql_num_rows(sqlresult) == 0) // No User max set. Get the actual data max
    {
      sprintf(sqlbuff, "%s ftypeId = %d", baseQuery, ftypeId);
    }
    else
    {
      if((row = mysql_fetch_row(sqlresult)) != NULL)
      {
        if(row[0])
          maxScore = atof(row[0]);
      }
      mysql_free_result(sqlresult);
      resetLocalConnection(getDatabaseFromId(0));
      return maxScore;
    }
  }

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
    fprintf(stderr, "Error querying the genboree database (getData).\n");
    fprintf(stderr, mysql_error(&mysql));
    fflush(stderr);
    return 0;
  }
  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult) == 0)
  {
    fprintf(stderr, "No records found \n");
    fflush(stderr);
    return 0;
  }

  if((row = mysql_fetch_row(sqlresult)) != NULL)
  {
    if(row[0])
      maxScore = atof(row[0]);
  }

  mysql_free_result(sqlresult);

  resetLocalConnection(getDatabaseFromId(0));
  return maxScore;
}

float generateMaxScoreFromTrackName(char *trackName, int localRange)
{
  int counter = 0;
  int numberGenboreeDatabases = getNumberDatabases();
  char fmethod[MAXLENGTHOFTEMPSTRING] = "";
  char fsource[MAXLENGTHOFTEMPSTRING] = "";
  char *feature = NULL;
  char *occurance;
  float theMaxScore = 0.0;
  float currentMaxScore = 0.0;
  int theFtypeId = 0;

  if(trackName && strlen(trackName) > 1)
  {
    feature = strdup(trackName);
    occurance = strstr(feature, ":");
    *occurance = '\0';
    strcpy(fmethod, feature);
    occurance++;
    strcpy(fsource, occurance);
    free(feature);
    feature = NULL;
  }
  else
  {
    return 0.0;
  }

  counter = 0;
  while (numberGenboreeDatabases > counter)
  {
    theFtypeId = requestFtypeIdFromDB(fmethod, fsource, counter);
    if(theFtypeId > 0)
    {
      currentMaxScore = requestMaxScore(theFtypeId, counter, localRange);
      theMaxScore = currentMaxScore;
    }
    counter++;
  }
  return theMaxScore;
}

float generateMinScoreFromTrackName(char *trackName, int localRange)
{
  int counter = 0;
  int numberGenboreeDatabases = getNumberDatabases();
  char fmethod[MAXLENGTHOFTEMPSTRING] = "";
  char fsource[MAXLENGTHOFTEMPSTRING] = "";
  char *feature = NULL;
  char *occurance;
  float theMinScore = 0.0;
  float currentMinScore = 0.0;
  int theFtypeId = 0;

  if(trackName && strlen(trackName) > 1)
  {
      feature = strdup(trackName);
      occurance = strstr(feature, ":");
      *occurance = '\0';
      strcpy(fmethod, feature);
      occurance++;
      strcpy(fsource, occurance);
      free(feature);
      feature = NULL;
  }
  else
  {
      return 0.0;
  }

  counter = 0;
  while (numberGenboreeDatabases > counter)
  {
      theFtypeId = requestFtypeIdFromDB(fmethod, fsource, counter);
      if(theFtypeId > 0)
      {
        theMinScore = requestMinScore(theFtypeId, counter, localRange);
      }
      counter++;
  }
  return theMinScore;
}

long long getMetaInfo(int currentDatabase, int isMax)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  long long theValue = 0;
  char minBin[] = "MIN_BIN";
  char maxBin[] = "MAX_BIN";
  char *theBin = NULL;

  if(isMax)
    theBin = maxBin;
  else
    theBin = minBin;

  resetLocalConnection(getDatabaseFromId(currentDatabase));
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);

  sprintf(sqlbuff, "SELECT fvalue FROM fmeta WHERE fname = '%s'", theBin);

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      fprintf(stderr, "Error querying the %s database in function getMetaInfo.\n", getDatabaseFromId(currentDatabase));
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return 0;
  }
  sqlresult = mysql_store_result(connection);

  // No records were found, so report an error and exit.
  if(mysql_num_rows(sqlresult) == 0)
  {
      fprintf(stderr, "No records found \n");
      fflush(stderr);
      return 0;
  }

  if((row = mysql_fetch_row(sqlresult)) != NULL)
  {
      theValue = atoll(row[0]);
  }

  resetLocalConnection(getDatabaseFromId(0));

  mysql_free_result(sqlresult);
  //closeLocalConnection(2);
  return theValue;
}

char *returnFractionOfBin(long valueRequested, long long tier)
{
  long myNum;
  char newStr[255] = "";
  char tempString[255] = "";
  int lengthString = 0;

  myNum = valueRequested / tier;
  sprintf(tempString, "%ld", myNum);

  lengthString = strlen(tempString);

  switch (lengthString)
  {
    case 0:
      strcpy(newStr, "000000");
      break;
    case 1:
      sprintf(newStr, "00000%s", tempString);
      break;
    case 2:
      sprintf(newStr, "0000%s", tempString);
      break;
    case 3:
      sprintf(newStr, "000%s", tempString);
      break;
    case 4:
      sprintf(newStr, "00%s", tempString);
      break;
    case 5:
      sprintf(newStr, "0%s", tempString);
      break;
    case 6:
      sprintf(newStr, "%s", tempString);
      break;
    default:
      sprintf(newStr, "%s", tempString);
      break;
  }

  return strdup(newStr);
}

char *generateFeatureQuery(int currentDatabase)
{
  char mainQuery[] =
      "SELECT fstart, fstop, fscore, fstrand, fphase, ftarget_start, ftarget_stop, gname, ftypeid,fid,rid, displayCode, displayColor, groupContextCode FROM fdata2 USE INDEX (primary) WHERE ";
  char *resultingQuery = NULL;

  resultingQuery = appendMaxMinBinToQuery(currentDatabase, mainQuery);
  return resultingQuery;
}

char *appendMaxMinBinToQuery(int currentDatabase, char *baseQuery)
{
  char theQuery[2500] = "";
  char firstArg[255] = "";
  char secondArg[255] = "";
  char *startFormat = NULL;
  char *stopFormat = NULL;
  int first = 1;
  char middleQuery[255] = "";
  long long maxBin = getMetaInfo(currentDatabase, 1);
  long long minBin = getMetaInfo(currentDatabase, 0);
  long long tier = maxBin;

  strcat(theQuery, baseQuery);

  sprintf(middleQuery,
          "AND (fstop >= %lld AND fstart <= %lld) AND rid = %d and ftypeid in ",
          startPositionGlobal, endPositionGloblal, getEntrypointId(currentDatabase));

  if(tier >= minBin)
  {
      strcat(theQuery, "(");
  }

  while (tier >= minBin)
  {
      if(!first)
      {
          strcat(theQuery, " OR ");
      }
      startFormat = returnFractionOfBin(startPositionGlobal, tier);
      sprintf(firstArg, "%lld.%s", tier, startFormat);
      free(startFormat);
      startFormat = NULL;
      stopFormat = returnFractionOfBin(endPositionGloblal, tier);
      sprintf(secondArg, "%lld.%s", tier, stopFormat);
      free(stopFormat);
      stopFormat = NULL;

      if(strcmp(firstArg, secondArg) == 0)
      {
          sprintf(theQuery, "%sfbin = %s", theQuery, firstArg);
      }
      else
      {
          sprintf(theQuery, "%sfbin BETWEEN %s AND %s", theQuery, firstArg, secondArg);
      }

      first = 0;
      tier = tier / 10;
  }
  if(!first)
  {
      sprintf(theQuery, "%s ) %s", theQuery, middleQuery);
  }
  return strdup(theQuery);
}

char *getTheStyleUsed(char *databaseFtypeId)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection = NULL;
  MYSQL mysql;
  MYSQL_RES *sqlresult = NULL;
  MYSQL_ROW row = NULL;
  int ftypeid = 0;
  int databaseId = 0;
  int theStyleId = 0;
  char styleCode[MAXLENGTHOFTEMPSTRING] = "";
  char *databaseIdStr = strdup(databaseFtypeId);
  char *ftypeidStr = strdup(databaseFtypeId);
  char *occurance = NULL;

  occurance = strstr(databaseIdStr, ":");
  *occurance = '\0';
  databaseId = atoi(databaseIdStr);
  free(databaseIdStr);
  databaseIdStr = NULL;

  occurance = strstr(ftypeidStr, ":");
  occurance++;
  ftypeid = atoi(occurance);
  free(ftypeidStr);
  ftypeidStr = NULL;

  resetLocalConnection(getDatabaseFromId(databaseId));
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);

  sprintf(sqlbuff, "SELECT styleId FROM featuretostyle WHERE ftypeid = %d " "AND userid = %ld", ftypeid, getMyUserId());

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      fprintf(stderr,
              "Error querying the featuretostyle table in database %s in function getTheStyleUsed and userId = %ld.\n",
              getDatabaseFromId(databaseId), getMyUserId());
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return NULL;
  }
  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult))
  {
      if((row = mysql_fetch_row(sqlresult)))
      {
          theStyleId = atoi(row[0]);
      }
  }
  else
  {
      mysql_free_result(sqlresult);
      sprintf(sqlbuff, "SELECT styleId FROM featuretostyle WHERE ftypeid = %d " "AND userid = 0", ftypeid);

      if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
      {
          fprintf(stderr,
                  "Error querying the featuretostyle table in database %s in function getTheStyleUsed and userId = 0.\n",
                  getDatabaseFromId(databaseId));
          fprintf(stderr, mysql_error(&mysql));
          fflush(stderr);
          return NULL;
      }
      sqlresult = mysql_store_result(connection);

      if(mysql_num_rows(sqlresult))
      {
          if((row = mysql_fetch_row(sqlresult)))
          {
              theStyleId = atoi(row[0]);
          }
      }
      else
      {
          return NULL;
      }
  }

  mysql_free_result(sqlresult);

  sprintf(sqlbuff, "SELECT name FROM style WHERE styleId = %d", theStyleId);

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      fprintf(stderr, "Error querying the style database in function getTheStyleUsed.\n");
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return NULL;
  }
  sqlresult = mysql_store_result(connection);
  if(mysql_num_rows(sqlresult))
  {
      if((row = mysql_fetch_row(sqlresult)))
      {
          strcpy(styleCode, row[0]);
      }
  }
  else
  {
      return NULL;
  }

  mysql_free_result(sqlresult);
  resetLocalConnection(getDatabaseFromId(0));
  return strdup(styleCode);
}

void eraseGlistWithAttValues(gpointer data)
{
  GList *attValues = (GList *) data;
  while (attValues)
  {
      char *tempData = (char *)attValues->data;
      free(tempData);
      tempData = NULL;
      attValues = g_list_next(attValues);
  }
  g_list_free(attValues);
}

char *getFtypeAttNameFromNameId(int databaseIndex, int ftypeAttrName_id)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  int counter = databaseIndex;
  char *ftypeAttName = NULL;

  if(counter < 0)
  {
      return ftypeAttName;
  }

  resetLocalConnection(getDatabaseFromId(counter));
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);

  sprintf(sqlbuff, "SELECT name FROM ftypeAttrNames WHERE id = %d;", ftypeAttrName_id);

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      return ftypeAttName;
  }

  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult) == 0)
  {
      return ftypeAttName;
  }

  if((row = mysql_fetch_row(sqlresult)) != NULL)
  {
      ftypeAttName = strdup(row[0]);
  }

  mysql_free_result(sqlresult);
  resetLocalConnection(getDatabaseFromId(0));
  return ftypeAttName;
}

char *getValueFromFtypeAttrValueId(int databaseIndex, int ftypeAttrValue_id, long limit)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  int counter = databaseIndex;
  char textResults[2555] = "";

  if(counter < 0)
  {
      return NULL;
  }

  resetLocalConnection(getDatabaseFromId(counter));
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);

  sprintf(sqlbuff, "SELECT left(value, %ld) FROM ftypeAttrValues WHERE id  = '%d'", limit, ftypeAttrValue_id);

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      return NULL;
  }

  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult) == 0)
  {
      return NULL;
  }

  if((row = mysql_fetch_row(sqlresult)) != NULL)
  {
      strcpy(textResults, row[0]);
  }

  mysql_free_result(sqlresult);
  resetLocalConnection(getDatabaseFromId(0));
  return strdup(textResults);
}

void fillFtype2Attributes(void)
{
  char query[] =
      "SELECT ftype_id, ftypeAttrName_id, ftypeAttrValue_id FROM ftype2attributes order by ftype_id, ftypeAttrName_id";
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  GHashTable *ftypeid2AttributeHash;
  GHashTable *attributeNameHash2AttValue;
  int counter = 0;
  int numberGenboreeDatabases = getNumberDatabases();
  char *ftypeAttrName_id = NULL;
  char *ftype_id = NULL;
  char *ftypeAttrValue_id = NULL;
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  char tempString[MAXLENGTHOFTEMPSTRING] = "";

  setFtypeid2AttributeHash();
  ftypeid2AttributeHash = getFtypeid2AttributeHash();

  counter = 0;
  while (numberGenboreeDatabases > counter)
  {
      resetLocalConnection(getDatabaseFromId(counter));
      connection = returnLocalConnection(2);
      mysql = returnMyMYSQL(2);

      sprintf(sqlbuff, query, getMyUserId());

      if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
      {
          fprintf(stderr, "Error querying the ftypeAttrDisplay table in function fillFtypeAttrDisplay.\n");
          fprintf(stderr, "The query is %s\n", sqlbuff);
          fprintf(stderr, mysql_error(&mysql));
          fflush(stderr);
          return;
      }
      sqlresult = mysql_store_result(connection);

      if(mysql_num_rows(sqlresult) > 0)
      {
          while ((row = mysql_fetch_row(sqlresult)) != NULL)
          {
              memset(tempString, '\0', 55);
              ftype_id = row[0];
              sprintf(tempString, "%d:%s", counter, ftype_id);
              ftypeAttrName_id = row[1];
              ftypeAttrValue_id = row[2];

              attributeNameHash2AttValue = (GHashTable *) g_hash_table_lookup(ftypeid2AttributeHash, tempString);
              if(attributeNameHash2AttValue == NULL)
              {
                  GList *attValues = NULL;
                  attributeNameHash2AttValue =
                      g_hash_table_new_full(g_str_hash, g_str_equal, g_free, eraseGlistWithAttValues);
                  attValues = g_list_append(attValues, g_strdup(ftypeAttrValue_id));
                  g_hash_table_insert(attributeNameHash2AttValue, g_strdup(ftypeAttrName_id), attValues);
                  g_hash_table_insert(ftypeid2AttributeHash, g_strdup(tempString), attributeNameHash2AttValue);
              }
              else
              {
                  GList *attValues = (GList *) g_hash_table_lookup(attributeNameHash2AttValue,
                                                                   ftypeAttrName_id);
                  if(attValues == NULL)
                  {
                      attValues = g_list_append(attValues, g_strdup(ftypeAttrValue_id));
                      g_hash_table_insert(attributeNameHash2AttValue, g_strdup(ftypeAttrName_id), attValues);
                  }
                  else
                  {
                      attValues = g_list_append(attValues, g_strdup(ftypeAttrValue_id));
                  }

              }
          }
          mysql_free_result(sqlresult);
      }
      counter++;
  }

  resetLocalConnection(getDatabaseFromId(0));
  return;
}

trackAttDisplays *makeTrackAttDisplays(char *ftypeAttrName_id, char *valueId,
                                       char *color, int rank, int flags, int databaseIndexId, int userId)
{
  trackAttDisplays *localAttDisplays = NULL;
  char *tAttName = NULL;
  char *tAttValue = NULL;
  char tempText[2555] = "";
  char *textToPrint = NULL;
  long limit = 3000;

  tAttValue = getValueFromFtypeAttrValueId(databaseIndexId, atoi(valueId), limit);
  if(flags)
  {
      tAttName = getFtypeAttNameFromNameId(databaseIndexId, atoi(ftypeAttrName_id));
      sprintf(tempText, "%s = %s", tAttName, tAttValue);
  }
  else
  {
      sprintf(tempText, "%s", tAttValue);
  }
  textToPrint = trimmedText(tempText, MAXLENGTHFTYPEATTTEXT);

  if(!rank || !textToPrint)
    return NULL;
  if((localAttDisplays = (trackAttDisplays *) malloc(sizeof(trackAttDisplays))) == NULL)
    return NULL;

  localAttDisplays->rank = rank;
  if(userId > 0 && databaseIndexId == 0)
  {
      localAttDisplays->flaglocal = LOCALUSER;
  }
  else if(userId == 0 && databaseIndexId == 0)
  {
      localAttDisplays->flaglocal = LOCALDEFAULT;
  }
  else if(userId > 0 && databaseIndexId > 0)
  {
      localAttDisplays->flaglocal = SHAREDUSER;
  }
  else
  {
      localAttDisplays->flaglocal = SHAREDDEFAULT;
  }

  localAttDisplays->color = strdup(color);
  localAttDisplays->textToPrint = textToPrint;
  localAttDisplays->sourceDb = databaseIndexId;

  return localAttDisplays;
}

void updateTrackAttDisplays(trackAttDisplays * localAttDisplays,
                            char *ftypeAttrName_id, char *valueId, char *color,
                            int rank, int flags, int databaseIndexId, int userId)
{
  char *tAttName = NULL;
  char *tAttValue = NULL;
  char tempText[2555] = "";
  char *textToPrint = NULL;
  long limit = 3000;

  tAttValue = getValueFromFtypeAttrValueId(databaseIndexId, atoi(valueId), limit);
  if(flags)
  {
      tAttName = getFtypeAttNameFromNameId(databaseIndexId, atoi(ftypeAttrName_id));
      sprintf(tempText, "%s = %s", tAttName, tAttValue);
  }
  else
  {
      sprintf(tempText, "%s", tAttValue);
  }
  textToPrint = trimmedText(tempText, MAXLENGTHFTYPEATTTEXT);

  if(!rank || !textToPrint)
  {
      return;
  }

  free(localAttDisplays->color);
  localAttDisplays->color = NULL;
  localAttDisplays->color = strdup(color);

  localAttDisplays->rank = rank;

  if(userId > 0 && databaseIndexId == 0)
  {
      localAttDisplays->flaglocal = LOCALUSER;
  }
  else if(userId == 0 && databaseIndexId == 0)
  {
      localAttDisplays->flaglocal = LOCALDEFAULT;
  }
  else if(userId > 0 && databaseIndexId > 0)
  {
      localAttDisplays->flaglocal = SHAREDUSER;
  }
  else
  {
      localAttDisplays->flaglocal = SHAREDDEFAULT;
  }

  localAttDisplays->sourceDb = databaseIndexId;

  free(localAttDisplays->textToPrint);
  localAttDisplays->textToPrint = NULL;
  localAttDisplays->textToPrint = textToPrint;

}

void deleteTrackAttDisplays(trackAttDisplays * localAttDisplays)
{
  free(localAttDisplays->color);
  localAttDisplays->color = NULL;
  free(localAttDisplays->textToPrint);
  localAttDisplays->textToPrint = NULL;
  free(localAttDisplays);
  localAttDisplays = NULL;
  return;
}

void eraseTrackAttDisplays(gpointer data)
{
  trackAttDisplays *localAttDisplays = (trackAttDisplays *) data;
  deleteTrackAttDisplays(localAttDisplays);
  return;
}

void fillFtypeAttrDisplay(void)
{
  char query[] =
      "select ftypeAttrName_id, rank, ftype_id, flags, color, genboreeuser_id from ftypeAttrDisplays "
      "where genboreeuser_id in (0,%ld) order by ftype_id, genboreeuser_id";
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  GHashTable *ftypeid2AttributeDisplayHash;
  GHashTable *attributeHash2TrackAttDisplays;
  GHashTable *trackHasData;
  int counter = 0;
  int numberGenboreeDatabases = getNumberDatabases();
  char *ftypeAttrName_id = NULL;
  int rank = 0;
  char *ftype_id = NULL;
  char *color = NULL;
  int flags = 0;
  int genboreeuser_id = -1;
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  GHashTable *attributeNameHash2AttValue = NULL;
  GHashTable *ftypeid2AttributeHash = getFtypeid2AttributeHash();
  char tempString[55] = "";
  char key[255] = "";
  GHashTable *typeId2FeatureTypeHash = getTypeId2FeatureTypeHash();
  char *trackName = NULL;
  char *inDb = NULL;
  int inDbInt = -1;

  setFtypeid2AttributeDisplayHash();
  ftypeid2AttributeDisplayHash = getFtypeid2AttributeDisplayHash();
  trackHasData = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);

  counter = numberGenboreeDatabases - 1;
  while (counter >= 0)
  {
      resetLocalConnection(getDatabaseFromId(counter));
      connection = returnLocalConnection(2);
      mysql = returnMyMYSQL(2);

      sprintf(sqlbuff, query, getMyUserId());

      if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
      {
          fprintf(stderr, "Error querying the ftypeAttrDisplay table in function fillFtypeAttrDisplay.\n");
          fprintf(stderr, "The query is %s\n", sqlbuff);
          fprintf(stderr, mysql_error(&mysql));
          fflush(stderr);
          return;
      }
      sqlresult = mysql_store_result(connection);

      if(mysql_num_rows(sqlresult) > 0)
      {
          while ((row = mysql_fetch_row(sqlresult)) != NULL)
          {
              GList *attValues = NULL;
              ftype_id = row[2];

              memset(tempString, '\0', 55);
              sprintf(tempString, "%d:%s", counter, ftype_id);
              attributeNameHash2AttValue = (GHashTable *) g_hash_table_lookup(ftypeid2AttributeHash, tempString);
              trackName = (char *)g_hash_table_lookup(typeId2FeatureTypeHash, tempString);
              if(trackName == NULL)
              {
                  continue;
              }
              inDb = (char *)g_hash_table_lookup(trackHasData, trackName);
              if(inDb != NULL)
              {
                  inDbInt = atoi(inDb);
              }
              else
              {
                  char newNumber[55] = "";
                  sprintf(newNumber, "%d", counter);
                  inDbInt = counter;
                  g_hash_table_insert(trackHasData, g_strdup(trackName), g_strdup(newNumber));
              }
              rank = atoi(row[1]);
              ftypeAttrName_id = row[0];
              attValues = (GList *) g_hash_table_lookup(attributeNameHash2AttValue, ftypeAttrName_id);
              flags = atoi(row[3]);
              color = row[4];
              genboreeuser_id = atoi(row[5]);

              attributeHash2TrackAttDisplays =
                  (GHashTable *) g_hash_table_lookup(ftypeid2AttributeDisplayHash, trackName);
              if(attributeHash2TrackAttDisplays == NULL)
              {
                  attributeHash2TrackAttDisplays =
                      g_hash_table_new_full(g_str_hash, g_str_equal, g_free, eraseTrackAttDisplays);
                  g_hash_table_insert(ftypeid2AttributeDisplayHash,
                                      g_strdup(trackName), attributeHash2TrackAttDisplays);

                  while (attValues)
                  {
                      memset(key, '\0', 255);
                      trackAttDisplays *tempAttDisp = NULL;
                      char *valueId = (char *)attValues->data;
                      char *attName = getFtypeAttNameFromNameId(counter,
                                                                atoi(ftypeAttrName_id));
                      sprintf(key, "%s-%s", trackName, attName);
                      tempAttDisp =
                          makeTrackAttDisplays(ftypeAttrName_id, valueId, color, rank, flags, counter, genboreeuser_id);
                      g_hash_table_insert(attributeHash2TrackAttDisplays, g_strdup(key), tempAttDisp);
                      attValues = g_list_next(attValues);
                  }

              }
              else
              {
                  if(counter != inDbInt)
                  {
                      g_hash_table_insert(trackHasData, g_strdup(trackName), g_strdup(inDb));
                  }
                  while (attValues)
                  {
                      memset(key, '\0', 255);
                      trackAttDisplays *tempAttDisp = NULL;
                      char *valueId = (char *)attValues->data;
                      char *attName = getFtypeAttNameFromNameId(counter,
                                                                atoi(ftypeAttrName_id));
                      sprintf(key, "%s-%s", trackName, attName);
                      tempAttDisp = (trackAttDisplays *) g_hash_table_lookup(attributeHash2TrackAttDisplays, key);
                      if(tempAttDisp == NULL)
                      {
                          tempAttDisp =
                              makeTrackAttDisplays(ftypeAttrName_id, valueId,
                                                   color, rank, flags, counter, genboreeuser_id);
                          g_hash_table_insert(attributeHash2TrackAttDisplays, g_strdup(key), tempAttDisp);
                      }
                      else
                      {
                          updateTrackAttDisplays(tempAttDisp, ftypeAttrName_id,
                                                 valueId, color, rank, flags, counter, genboreeuser_id);
                      }
                      attValues = g_list_next(attValues);
                  }
              }

          }
          mysql_free_result(sqlresult);
      }
      else
      {
          mysql_free_result(sqlresult);
      }
      counter--;
  }
  resetLocalConnection(getDatabaseFromId(0));
  if(0)
  {
      GHashTableIter iter;
      gpointer key, value;
      g_hash_table_iter_init(&iter, ftypeid2AttributeDisplayHash);

      while (g_hash_table_iter_next(&iter, &key, &value))
      {
          GHashTableIter iter2;
          gpointer key2, value2;
          trackName = (char *)g_hash_table_lookup(typeId2FeatureTypeHash, (char *)key);
          GHashTable *attValue = (GHashTable *) value;

          g_hash_table_iter_init(&iter2, attValue);

          while (g_hash_table_iter_next(&iter2, &key2, &value2))
          {
              trackAttDisplays *tempAttDisplay = (trackAttDisplays *) value2;
              fprintf(stderr,
                      "the first key = %s, key is %s and the rank is %d the color is %s and the textToPrint is %s\n",
                      (char *)key, (char *)key2, tempAttDisplay->rank,
                      tempAttDisplay->color, tempAttDisplay->textToPrint);
          }
      }
  }

  return;
}

void fillTypeIdHash()
{
  fprintf(stderr, "in fillTypeIdHash()") ;
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  int counter = 0;
  int numberGenboreeDatabases = getNumberDatabases();
  char **listOfFtypeIds = NULL;

  fprintf(stderr, "in fillTypeIdHash() 2\n") ;
  setTypeIdHash();

  fprintf(stderr, "in fillTypeIdHash() 3\n") ;
  setTypeIdsStatementByDatabaseId();
  fprintf(stderr, "in fillTypeIdHash() 4\n") ;

  listOfFtypeIds = getTypeIdsStatementByDatabaseId();
  fprintf(stderr, "in fillTypeIdHash() 5\n") ;

  counter = 0;
  while (numberGenboreeDatabases > counter)
  {
      resetLocalConnection(getDatabaseFromId(counter));
      connection = returnLocalConnection(2);
      mysql = returnMyMYSQL(2);

      sprintf(sqlbuff, "SELECT distinct(ftypeid) from ftype where ftypeid in %s", listOfFtypeIds[counter]);
      fprintf(stderr, "sqlbuff%s\n", sqlbuff) ;
      if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
      {
          fprintf(stderr, "Error querying the fdata2 database in function fillTypeIdHash.\n");
          fprintf(stderr, "The query is %s\n", sqlbuff);
          fprintf(stderr, mysql_error(&mysql));
          fflush(stderr);
          return;
      }
      fprintf(stderr, "in fillTypeIdHash() 6\n") ;
      sqlresult = mysql_store_result(connection);
      fprintf(stderr, "in fillTypeIdHash() 7\n") ;

      if(mysql_num_rows(sqlresult) > 0)
      {
          while ((row = mysql_fetch_row(sqlresult)) != NULL)
          {
            addTypeIdHash(row[0], counter);
          }
          fprintf(stderr, "in fillTypeIdHash() 8\n") ;
          mysql_free_result(sqlresult);
          fprintf(stderr, "in fillTypeIdHash() 9\n") ;
      }
      fprintf(stderr, "in fillTypeIdHash() 10\n") ;
      counter++;
  }
  fprintf(stderr, "in fillTypeIdHash() 11\n") ;

  resetLocalConnection(getDatabaseFromId(0));
  fprintf(stderr, "in fillTypeIdHash() 12\n") ;
  return;
}

int extractDatabaseId(char *databaseFeature)
{
  char *feature = NULL;
  char *occurance;
  int databaseId = -1;

  if(databaseFeature && strlen(databaseFeature) > 1)
  {
      feature = strdup(databaseFeature);
      occurance = strstr(feature, ":");
      *occurance = '\0';
      databaseId = atoi(feature);
      free(feature);
      feature = NULL;
  }
  else
  {
      return -1;
  }

  return databaseId;
}

int getVisibilityFromTypeId(int database, int typeId)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  char textResults[555] = "";
  int visibility = 0;

  if(database < 0)
  {
      return 0;
  }

  resetLocalConnection(getDatabaseFromId(database));
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);

  sprintf(sqlbuff, "SELECT CONCAT(fmethod, ':', fsource) FeatureTypeId " "FROM ftype WHERE ftypeid = %d", typeId);

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      return 0;
  }

  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult) == 0)
  {
      return 0;
  }

  if((row = mysql_fetch_row(sqlresult)) != NULL)
  {
      strcpy(textResults, row[0]);
  }

  mysql_free_result(sqlresult);
  resetLocalConnection(getDatabaseFromId(0));
  visibility = returnMyVisibilityValue(textResults);

  return visibility;

}

char *createInStatement(int databaseToUse)
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

char *getTheColorUsed(char *databaseFtypeId)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection = NULL;
  MYSQL mysql;
  MYSQL_RES *sqlresult = NULL;
  MYSQL_ROW row = NULL;
  int ftypeid = 0;
  int databaseId = 0;
  int theColorId = 0;
  char colorCode[MAXLENGTHOFTEMPSTRING] = "";
  char *databaseIdStr = strdup(databaseFtypeId);
  char *ftypeidStr = strdup(databaseFtypeId);
  char *occurance = NULL;

  occurance = strstr(databaseIdStr, ":");
  *occurance = '\0';
  databaseId = atoi(databaseIdStr);
  free(databaseIdStr);
  databaseIdStr = NULL;

  occurance = strstr(ftypeidStr, ":");
  occurance++;
  ftypeid = atoi(occurance);
  free(ftypeidStr);
  ftypeidStr = NULL;

  resetLocalConnection(getDatabaseFromId(databaseId));
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);

  sprintf(sqlbuff, "SELECT colorId FROM featuretocolor WHERE ftypeid = %d " "AND userid = %ld", ftypeid, getMyUserId());

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      fprintf(stderr, "Error querying the featuretocolor database in function getTheColorUsed.\n");
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return NULL;
  }
  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult))
  {
      if((row = mysql_fetch_row(sqlresult)))
      {
          theColorId = atoi(row[0]);
      }
  }
  else
  {
      mysql_free_result(sqlresult);
      sprintf(sqlbuff, "SELECT colorId FROM featuretocolor WHERE ftypeid = %d " "AND userid = 0", ftypeid);

      if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
      {
          fprintf(stderr, "Error querying the featuretocolor database in function getTheColorUsed.\n");
          fprintf(stderr, mysql_error(&mysql));
          fflush(stderr);
          return NULL;
      }
      sqlresult = mysql_store_result(connection);

      if(mysql_num_rows(sqlresult))
      {
          if((row = mysql_fetch_row(sqlresult)))
          {
              theColorId = atoi(row[0]);
          }
      }
      else
      {
          return NULL;
      }
  }

  mysql_free_result(sqlresult);

  sprintf(sqlbuff, "SELECT value FROM color WHERE colorId = %d", theColorId);
  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      fprintf(stderr, "Error querying the color database in function getTheColorUsed.\n");
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return NULL;
  }
  sqlresult = mysql_store_result(connection);
  if(mysql_num_rows(sqlresult))
  {
      if((row = mysql_fetch_row(sqlresult)))
      {
          strcpy(colorCode, row[0]);
      }
  }
  else
  {
      return NULL;
  }

  mysql_free_result(sqlresult);
  resetLocalConnection(getDatabaseFromId(0));
  return strdup(colorCode);
}

void fix_coords(long long *start, long long *stop, long long size)
{
  long long range = 0;
  long long temp = 0;

  if(1 > *start && *stop > 1)
  {
      range = *stop + abs((int)*start);
      *start = 1;
      *stop = range;
  }
  else if(1 > *stop && *start > 1)
  {
      range = *start + abs((int)*stop);
      *stop = *start + range;
  }
  else if(1 > *start && 1 > *stop)
  {
      *start = 1;
      *stop = size;
      range = size;
  }
  else
    range = *stop - *start;

  if(*start > *stop)
  {
      temp = *start;
      *start = *stop;
      *stop = temp;
  }

  if(range < MIN_COORD_RANGE)
  {
      range = MIN_COORD_RANGE;
      *stop = *start + range;
      if(*stop > size)
        *stop = size;
  }
  else if(range > size)
  {
      *start = 1;
      *stop = size;
  }

  if(*stop > size)
  {
      *stop = size;
      *start = size - range;
      if(1 > *start)
        *start = 1;
  }

  return;
}

char *getLinkNames(char *databaseFtypeId)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection = NULL;
  MYSQL mysql;
  MYSQL_RES *sqlresult = NULL;
  MYSQL_ROW row = NULL;
  int ftypeid = 0;
  int databaseId = 0;
  int ii = 0;
  char bigLinkString[BIGBUFFER] = "";
  char theLinks[2555] = "(";
  char *databaseIdStr = strdup(databaseFtypeId);
  char *ftypeidStr = strdup(databaseFtypeId);
  char *occurance = NULL;

  occurance = strstr(databaseIdStr, ":");
  *occurance = '\0';
  databaseId = atoi(databaseIdStr);
  free(databaseIdStr);
  databaseIdStr = NULL;

  occurance = strstr(ftypeidStr, ":");
  occurance++;
  ftypeid = atoi(occurance);
  free(ftypeidStr);
  ftypeidStr = NULL;

  resetLocalConnection(getDatabaseFromId(databaseId));
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);

  sprintf(sqlbuff,
          "SELECT distinct(linkId) FROM featuretolink WHERE ftypeid = %d "
          "AND userid in (0, %ld) order by linkId", ftypeid, getMyUserId());

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      fprintf(stderr, "Error querying the featuretolink database in function getLinkNames.\n");
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return NULL;
  }
  sqlresult = mysql_store_result(connection);

  if(!mysql_num_rows(sqlresult))
    return NULL;

  ii = 0;
  while ((row = mysql_fetch_row(sqlresult)) != NULL)
  {
      if(ii > 0)
        strcat(theLinks, ", ");
      strcat(theLinks, row[0]);
      ii++;
  }

  strcat(theLinks, ")");
  mysql_free_result(sqlresult);

  sprintf(sqlbuff, "SELECT concat(name, '\\t', description) myLink FROM link WHERE linkId in %s", theLinks);
  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      fprintf(stderr, "Error querying the link database in function getLinkNames.\n");
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return NULL;
  }
  sqlresult = mysql_store_result(connection);

  if(!mysql_num_rows(sqlresult))
  {
      return NULL;
  }

  ii = 0;
  while ((row = mysql_fetch_row(sqlresult)) != NULL)
  {
      if(ii > 0)
      {
          strcat(bigLinkString, "\t");
      }
      if((strlen(row[0]) + strlen(bigLinkString)) >= BIGBUFFER)
      {
          break;
      }
      strcat(bigLinkString, row[0]);
      ii++;
  }

  mysql_free_result(sqlresult);
  resetLocalConnection(getDatabaseFromId(0));
  return strdup(bigLinkString);
}

int verifyDatabases(void)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection = NULL;
  MYSQL mysql;
  MYSQL_RES *sqlresult = NULL;
  MYSQL_ROW row = NULL;
  int counter = 0;
  int numberGenboreeDatabases = getNumberDatabases();
  char fixString[] = "featuresort";
  int lengthFixString = strlen(fixString);
  int correctDatabase = 0;

  while (numberGenboreeDatabases > counter)
  {
      resetLocalConnection(getDatabaseFromId(counter));
      connection = returnLocalConnection(2);
      mysql = returnMyMYSQL(2);

      sprintf(sqlbuff, "SHOW TABLES");

      if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
      {
          fprintf(stderr, "Error verifying the database in function verifyDatabases.\n");
          fprintf(stderr, mysql_error(&mysql));
          fflush(stderr);
          return 0;
      }
      sqlresult = mysql_store_result(connection);

      // No records were found, so report an error and exit.
      if(mysql_num_rows(sqlresult) == 0)
      {
          fprintf(stderr, "No records found 740\n");
          fflush(stderr);
          return 0;
      }

      while ((row = mysql_fetch_row(sqlresult)) != NULL)
      {
          if(strlen(row[0]) == lengthFixString)
          {
              if(strcmp(fixString, row[0]) == 0)
              {
                  correctDatabase = 1;
                  break;
              }
          }
      }
      mysql_free_result(sqlresult);
      counter++;
      if(!correctDatabase)
        return 0;
      correctDatabase = 0;
  }

  resetLocalConnection(getDatabaseFromId(0));

  return 1;
}

char *getRawLink(char *featureType)
{
  GHashTable *myFeatureTypeHash;
  char *theData;
  char *linksInfo = NULL;

  myFeatureTypeHash = getFeatureTypeHash();
  theData = (char *)g_hash_table_lookup(myFeatureTypeHash, featureType);
  if(!theData)
  {
      return NULL;
  }

  linksInfo = getMD5LinksCheckingAllDatabases(featureType);
  return linksInfo;
}

char *getFeatureTypeColor(char *featureType)
{
  GHashTable *myFeatureTypeHash;
  char *theData;
  char *colorInfo = NULL;

  myFeatureTypeHash = getFeatureTypeHash();

  theData = (char *)g_hash_table_lookup(myFeatureTypeHash, featureType);
  if(!theData)
  {
      return NULL;
  }

  colorInfo = getTheColorUsed(theData);

  return colorInfo;
}

char *getFeatureTypeStyle(char *featureType)
{
  GHashTable *myFeatureTypeHash;
  char *theData;
  char *styleInfo = NULL;

  myFeatureTypeHash = getFeatureTypeHash();

  theData = (char *)g_hash_table_lookup(myFeatureTypeHash, featureType);
  if(!theData)
  {
      return NULL;
  }

  styleInfo = getTheStyleUsed(theData);

  return styleInfo;
}

void fillTracks(void)
{
  // Fields from 0 to 10
  // fstart(0), fstop(1), fscore(2), fstrand(3), fphase(4), ftargetstart(5), ftargetstop(6), gname(7), ftypeid(8), fid(9), rid(10), displayCode(11), displayColor(12), groupContextCode(13)
  myAnnotations *ilgPtr = NULL;
  myAnnotations *theLastAnnotation = NULL;
  myGroup *currentGroup = NULL;
  int numberOfRecords;
  int groupId = 0;
  int counter = 0;
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  int numberGenboreeDatabases = getNumberDatabases();
  char **databaseName = getDatabaseNames();
  char classKey[255] = "";
  int done = 0;
  int localInitialGroupId = 0;
  int localFinalGroupId = 0;
  char *myClass = NULL;
  int *myUploads = getArrayUploadIds();
  char *allClassNames = NULL;
  int annotationColor = -1;
  char *trackName = NULL;
  char *statement = NULL;

  timeItNow("C-DONE - Before setgroups2TrackHash() in fillTracks");

  setgroups2TrackHash();

  timeItNow("C-DONE - Generating hash tables");

  while (numberGenboreeDatabases > counter)
  {
      statement = NULL;
      statement = getInStatementForRegularTracks(counter);

      if(statement == NULL)
      {
          counter++;
          continue;
      }

      resetLocalConnection(getDatabaseFromId(counter));
      connection = returnLocalConnection(2);
      mysql = returnMyMYSQL(2);
      sprintf(sqlbuff, "%s %s", getFeatureQuery(counter), statement);
      timeItNow("C-DONE - Query preparation done");
      if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
      {
          fprintf(stderr, "Error querying the fdata2 database in function fillTrack.\n");
          fprintf(stderr, mysql_error(&mysql));
          fflush(stderr);
          return;
      }
      timeItNow("C-DONE - Finish the query");
      sqlresult = mysql_store_result(connection);
      timeItNow("C-DONE - done mysql_store_result");
      numberOfRecords = mysql_num_rows(sqlresult);
      timeItNow("C-DONE - done mysql_num_row");
      if(getMyDebug())
      {
          fprintf(stderr, "C-DONE - Query used in database %s is %s\n", databaseName[counter], sqlbuff);
          fprintf(stderr, "C-DONE - Number of records = %d\n", numberOfRecords);
          fflush(stderr);
      }
      timeItNow("C-DONE - Storing results from query");
      if(numberOfRecords)
      {
          while ((row = mysql_fetch_row(sqlresult)) != NULL)
          {
              trackName = getTrackNameFromTypeId(counter, atoi(row[8]));
              myClass = returnFirstClassName(trackName);

              allClassNames = returnAllClassNames(trackName);
              if(!myClass)
              {
                  fprintf(stderr, "problems with the class %s\n", classKey);
                  fflush(stderr);
                  return;
              }

              groupId = returnGroupId(myClass, row[7], trackName);
              if(!done)
              {
                  localInitialGroupId = groupId;
                  done = 1;
              }
              if(!groupId)
              {
                  fprintf(stderr, "problems with the groupId  class = %s and gname = %s\n", classKey, row[7]);
                  fflush(stderr);
                  return;
              }

              currentGroup = returnGroupFromGroupId(groupId);

              if(!currentGroup)
              {
                  currentGroup = makeGroup(myClass, row[7], groupId, allClassNames);
                  addGroup2GroupIds2GroupHash(currentGroup, groupId);
                  increaseUniversalCounter();
              }

              if(!currentGroup->annotations)
              {
                  currentGroup->annotations = makeAnnotation();
                  currentGroup->lastAnnotation = currentGroup->annotations;
                  ilgPtr = currentGroup->annotations;
              }
              else
              {
                  theLastAnnotation = currentGroup->lastAnnotation;
                  ilgPtr = theLastAnnotation;
                  while (ilgPtr)
                  {
                      ilgPtr = ilgPtr->next;
                      if(ilgPtr)
                      {
                          theLastAnnotation = ilgPtr;
                      }
                  }

                  if(!ilgPtr)
                  {
                      theLastAnnotation->next = makeAnnotation();
                      ilgPtr = theLastAnnotation->next;
                      currentGroup->lastAnnotation = ilgPtr;
                  }
              }
              ilgPtr->parentGroup = currentGroup;
              ilgPtr->uploadId = myUploads[counter];
              ilgPtr->id = atol(row[9]);
              strcat(ilgPtr->fidStr, row[9]);
              ilgPtr->start = atol(row[0]);
              ilgPtr->end = atol(row[1]);
              ilgPtr->ftypeid = atoi(row[8]);
              if(ilgPtr->start < endPositionGloblal && ilgPtr->end > endPositionGloblal)
                currentGroup->containsBrokenAnnotationAtEnd = 1;
              if(ilgPtr->start < startPositionGlobal && ilgPtr->end > startPositionGlobal)
              {
                  currentGroup->containsBrokenAnnotationAtStart = 1;
              }
              if(row[11])
              {
                  ilgPtr->displayCode = atoi(row[11]);
              }
              if(row[12] && atoi(row[12]) > -1)
              {
                  annotationColor = atoi(row[12]);
                  if(annotationColor < 0)
                  {
                      ilgPtr->displayColor = 0;
                  }
                  else if(annotationColor > MAXVALUEINCOLOR)
                  {
                      ilgPtr->displayColor = MAXVALUEINCOLOR;
                  }
                  else
                  {
                      ilgPtr->displayColor = annotationColor;
                  }
              }
              else
              {
                  ilgPtr->displayColor = -1;
              }

              if(row[13] && strlen(row[13]) > 0)
              {
                  char tempGroupContext = (char)(row[13][0]);
                  if(tempGroupContext == 'F')
                  {
                      currentGroup->hasF = 1;
                      if(!currentGroup->groupContextPresent)
                        currentGroup->groupContextPresent = 1;
                  }
                  else if(tempGroupContext == 'L')
                  {
                      currentGroup->hasL = 1;
                      if(!currentGroup->groupContextPresent)
                      {
                          currentGroup->groupContextPresent = 1;
                      }
                  }
                  else if(tempGroupContext == 'U')
                  {
                      currentGroup->hasU = 1;
                      if(!currentGroup->groupContextPresent)
                      {
                          currentGroup->groupContextPresent = 1;
                      }
                  }
                  else if(tempGroupContext == 'M')
                  {
                      if(!currentGroup->groupContextPresent)
                      {
                          currentGroup->groupContextPresent = 1;
                      }
                  }
                  else
                  {
                      currentGroup->groupContextPresent = 2;
                  }

                  ilgPtr->groupContextCode = tempGroupContext;
              }
              if(ilgPtr->start < currentGroup->groupStart)
              {
                  currentGroup->groupStart = ilgPtr->start;
              }
              if(ilgPtr->end > currentGroup->groupEnd)
              {
                  currentGroup->groupEnd = ilgPtr->end;
              }
              ilgPtr->score = atof(row[2]);
              if(row[3] && strlen(row[3]) > 0)
              {
                  ilgPtr->orientation = (char)(row[3][0]);
              }
              else
              {
                  ilgPtr->orientation = '.';
              }
              if(row[4] && strlen(row[4]) > 0)
              {
                  ilgPtr->phase = atoi(row[4]);
              }
              if(row[5] && strlen(row[5]) > 0)
              {
                  ilgPtr->tstart = atol(row[5]);
              }
              if(row[6] && strlen(row[6]) > 0)
              {
                  ilgPtr->tend = atol(row[6]);
              }
              currentGroup->numberOfAnnotations++;
              addGroup2TrackHash(counter, atoi(row[8]), groupId);
          }
      }
      mysql_free_result(sqlresult);
      counter++;
      if(getMyDebug())
      {
          fprintf(stderr, "****\n");
          fflush(stderr);
      }
      free(statement);
      statement = NULL;
  }
  timeItNow("C-DONE - Retrieving results from main query and filling structures");

  localFinalGroupId = getGroupCounter();

  setInitialGroupId(localInitialGroupId);
  setFinalGroupId(localFinalGroupId);

  resetLocalConnection(getDatabaseFromId(0));

  timeItNow("C-DONE - Assigning groups to structs");

  return;
}

int myCmpSP(const void *first, const void *second)
{
  groupStartingPoint aa;
  groupStartingPoint bb;
  aa = *(groupStartingPoint *) first;
  bb = *(groupStartingPoint *) second;
  return ((aa.groupStart < bb.groupStart) ? -1 : ((aa.groupStart > bb.groupStart) ? 1 : 0));
}

int compareToSpecialTrack(char *realNameTrack)
{
  char *mySpecialTrack = getMySpecialTrack();
  if(realNameTrack == NULL || strlen(realNameTrack) < 1)
  {
      return 0;
  }

  if(strncmp(realNameTrack, mySpecialTrack, strlen(mySpecialTrack)) == 0)
  {
      return 1;
  }
  else
  {
      return 0;
  }
}

char *getstring(int size)
{
  int corrected_size = size + 5;
  char *name = NULL;

  if(size == 0)
  {
      return NULL;
  }

  if((name = (char *)malloc(corrected_size * sizeof(char))) == NULL)
  {
      perror("problems with allocating memory using malloc");
      return NULL;
  }
  memset(name, '\0', corrected_size);

  return name;
}

int generateNames(char *baseName, char *fileName)
{

  int sizeOfBaseName = strlen(baseName);
  int sizeOfFileName = strlen(fileName);
  int addSize = 10;
  int sizeOfAllString = 0;
  char *theGifName = NULL;
  char *theMapName = NULL;

  sizeOfAllString = sizeOfBaseName + sizeOfFileName + addSize;

  theGifName = getstring(sizeOfAllString);

  if(getPNG())
  {
      sprintf(theGifName, "%s/%s.png", baseName, fileName);
  }
  else
  {
      sprintf(theGifName, "%s/%s.gif", baseName, fileName);
  }

  setGifFileName(theGifName);

  theMapName = getstring(sizeOfAllString) ;
  sprintf(theMapName, "%s/%s.map", baseName, fileName) ;
  setMapFileName(theMapName) ;

  return 1;

}

myTrack *createNewHead(void)
{
  myTrack *ptrTrack = NULL;
  myTrack *newTrackList = NULL;
  myTrack *tempTrack = NULL;
  myTrack *firstNewTrack = NULL;
  int counter = 0;

  ptrTrack = getTrackList();
  while (ptrTrack)
  {
      if(ptrTrack->numberOfGroups > 0)
      {
          if(!counter)
          {
              newTrackList = ptrTrack;
              firstNewTrack = newTrackList;
          }
          else
          {
              newTrackList->next = ptrTrack;
              newTrackList = newTrackList->next;
          }
          tempTrack = ptrTrack->next;
          newTrackList->next = NULL;
          counter++;
      }
      else
      {
          tempTrack = ptrTrack->next;
      }

      ptrTrack = tempTrack;
  }

  return firstNewTrack;
}

void myDecodeQuantum(unsigned char *dest, const char *src)
{
  unsigned int x = 0;
  int ii;
  for (ii = 0; ii < 4; ii++)
  {
      if(src[ii] >= 'A' && src[ii] <= 'Z')
      {
          x = (x << 6) + (unsigned int)(src[ii] - 'A' + 0);
      }
      else if(src[ii] >= 'a' && src[ii] <= 'z')
      {
          x = (x << 6) + (unsigned int)(src[ii] - 'a' + 26);
      }
      else if(src[ii] >= '0' && src[ii] <= '9')
      {
          x = (x << 6) + (unsigned int)(src[ii] - '0' + 52);
      }
      else if(src[ii] == '+')
      {
          x = (x << 6) + 62;
      }
      else if(src[ii] == '/')
      {
          x = (x << 6) + 63;
      }
      else if(src[ii] == '=')
      {
          x = (x << 6);
      }
  }

  dest[2] = (unsigned char)(x & 255);
  x >>= 8;
  dest[1] = (unsigned char)(x & 255);
  x >>= 8;
  dest[0] = (unsigned char)(x & 255);
}

/*
* Curl_base64_decode()
*
* Given a base64 string at src, decode it into the memory pointed to by
* dest. Returns the length of the decoded data.
*/
size_t myBase64_decode(const char *src, char *dest)
{
  int length = 0;
  int equalsTerm = 0;
  int ii;
  int numQuantums;
  unsigned char lastQuantum[3];
  size_t rawlen = 0;

  while ((src[length] != '=') && src[length])
  {
      length++;
  }
  while (src[length + equalsTerm] == '=')
  {
      equalsTerm++;
  }

  numQuantums = (length + equalsTerm) / 4;

  rawlen = (numQuantums * 3) - equalsTerm;

  for (ii = 0; ii < numQuantums - 1; ii++)
  {
      myDecodeQuantum((unsigned char *)dest, src);
      dest += 3;
      src += 4;
  }

  myDecodeQuantum(lastQuantum, src);
  for (ii = 0; ii < 3 - equalsTerm; ii++)
  {
      dest[ii] = lastQuantum[ii];
  }

  return rawlen;
}

/* ---- Base64 Encoding --- */
static char table64[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

/*
* Curl_base64_encode()
*
* Returns the length of the newly created base64 string. The third argument
* is a pointer to an allocated area holding the base64 data. If something
* went wrong, -1 is returned.
*
*/
size_t myBase64_encode(const char *inp, size_t insize, char **outptr)
{
  unsigned char ibuf[3];
  unsigned char obuf[4];
  int ii;
  int inputparts;
  char *output;
  char *base64data;

  char *indata = (char *)inp;

  *outptr = NULL;               /* set to NULL in case of failure before we reach the end */

  if(0 == insize)
    insize = strlen(indata);

  base64data = output = (char *)malloc(insize * 4 / 3 + 4);
  if(NULL == output)
  {
      return 0;
  }

  while (insize > 0)
  {
      for (ii = inputparts = 0; ii < 3; ii++)
      {
          if(insize > 0)
          {
              inputparts++;
              ibuf[ii] = *indata;
              indata++;
              insize--;
          }
          else
          {
              ibuf[ii] = 0;
          }
      }

      obuf[0] = (ibuf[0] & 0xFC) >> 2;
      obuf[1] = ((ibuf[0] & 0x03) << 4) | ((ibuf[1] & 0xF0) >> 4);
      obuf[2] = ((ibuf[1] & 0x0F) << 2) | ((ibuf[2] & 0xC0) >> 6);
      obuf[3] = ibuf[2] & 0x3F;

      switch (inputparts)
      {
        case 1:                /* only one byte read */
          snprintf(output, 5, "%c%c==", table64[obuf[0]], table64[obuf[1]]);
          break;
        case 2:                /* two bytes read */
          snprintf(output, 5, "%c%c%c=", table64[obuf[0]], table64[obuf[1]], table64[obuf[2]]);
          break;
        default:
          snprintf(output, 5, "%c%c%c%c", table64[obuf[0]], table64[obuf[1]], table64[obuf[2]], table64[obuf[3]]);
          break;
      }
      output += 4;
  }
  *output = 0;
  *outptr = base64data;         /* make it return the actual data memory */

  return strlen(base64data);    /* return the length of the new data */
}


/* ---- End of Base64 Encoding ---- */

void key_destroyed(gpointer data) {
 // destroy key: data
}

void updateTrackInfoHash(int userId, char *databaseName)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection = NULL;
  MYSQL mysql;
  MYSQL_ROW row = NULL;
  MYSQL_RES *sqlresult = NULL ;
  resetLocalConnection(databaseName);
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);
  char *tempTrackName ;
  // first do it for default user
  sprintf(sqlbuff,
         "select distinct CONCAT(ftype.fmethod, ':',  ftype.fsource) AS trackName, color.value AS color, style.name AS style, featureurl.url, featureurl.description, featureurl.label FROM ftype LEFT JOIN featuretocolor ON (ftype.ftypeid = featuretocolor.ftypeid) LEFT JOIN featuretostyle on (ftype.ftypeid = featuretostyle.ftypeid) LEFT JOIN featureurl on (ftype.ftypeid = featureurl.ftypeid) LEFT JOIN color on (featuretocolor.colorId = color.colorId) LEFT JOIN style on (featuretostyle.styleId = style.styleId) and featuretocolor.userid = %d", userId) ;
  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
    fprintf(stderr,
            "Error doing left join query in database = %s in updateTrackInfoHash.\n",
            databaseName);
    fprintf(stderr, mysql_error(&mysql));
    fflush(stderr);
  }
  sqlresult = mysql_store_result(connection) ;
  while ((row = mysql_fetch_row(sqlresult)) != NULL)
  {
    tempTrackName = row[0] ;
    if(g_hash_table_lookup(tempTrackHash, tempTrackName) == NULL)
      continue ;
    char *currentColor = g_hash_table_lookup(g_hash_table_lookup(tempTrackHash, tempTrackName), "color") ;
    char *currentStyle = g_hash_table_lookup(g_hash_table_lookup(tempTrackHash, tempTrackName), "style") ;
    myTrackUrlInfo *currentUrl = g_hash_table_lookup(g_hash_table_lookup(tempTrackHash, tempTrackName), "urlInfo") ;
    if(row[1] != NULL)
      currentColor = row[1] ;
    if(row[2] != NULL)
      currentStyle = row[2] ;
    if(row[4] != NULL)
    {
      currentUrl->urlDescription = row[4] ;
      currentUrl->shortUrlDesc = stripHtmlTags(returnFirstLine(row[4])) ;
      if(row[3] != NULL)
        currentUrl->url = row[3] ;
      if(row[5] != NULL)
        currentUrl->urlLabel = row[5] ;
    }
    // first fill up the inner hash //
    GHashTable *infoHash = g_hash_table_new_full(g_str_hash, g_str_equal, NULL, NULL) ;
    g_hash_table_insert(infoHash, g_strdup("color"), g_strdup(currentColor)) ;
    g_hash_table_insert(infoHash, g_strdup("style"), g_strdup(currentStyle)) ;
    g_hash_table_insert(infoHash, g_strdup("urlInfo"), currentUrl) ;
    // remove the previous entry for the track
    g_hash_table_remove(tempTrackHash, tempTrackName) ;
    // enter the new value for the track
    g_hash_table_insert(tempTrackHash, g_strdup(tempTrackName), infoHash);
  }
  mysql_free_result(sqlresult) ;
  closeLocalConnection(2) ;
}
void generateTracks(void)
{
  char **myTracksInOrder = getArrayOrderedTracks() ;
  int numberOfRecords = getMaxOrder() ;
  int ii = 0 ;
  char *tempLinkString = NULL ;
  myTrack *navigationTrack = NULL ;
  myTrack *parentTrack = NULL ;
  char *defaultColor = "#000000" ;
  char *defaultStyle = "simple_draw" ;
  int loadFirstTrack = 1 ;
  char *className = NULL ;
  int visibility = 1 ;
  GHashTable *trackHash = NULL ;
  size_t size ;
  char *base64 = NULL ;
  int printEncripted = 1 ;
  int numberOfTemplates = 0 ;
  int lengthOfStyleName = 0 ;
  bool isHistogram = false ;
  timeItNow("C-DONE - starting filling up track info: color, style, url");
  if(myTracksInOrder == NULL)
    return;
  // Initialize hash
  trackHash = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free) ;
  tempTrackHash = g_hash_table_new_full(g_str_hash, g_str_equal, (GDestroyNotify)key_destroyed, (GDestroyNotify)key_destroyed) ;
  // fill up hash with default values first
  for(ii = 0; ii <= numberOfRecords ; ii ++)
  {
    if(!(myTracksInOrder[ii]) || strlen(myTracksInOrder[ii]) < 1)
      continue ;
    char *dupTrack = strdup(myTracksInOrder[ii]) ;
    char *fmethod = strtok(dupTrack, ":") ;
    char *fsource = strtok(NULL, ":") ;
    if(g_hash_table_lookup(tempTrackHash, myTracksInOrder[ii]) == NULL)
    {
      GHashTable *infoHash = g_hash_table_new_full(g_str_hash, g_str_equal, NULL, NULL) ;
      g_hash_table_insert(infoHash, g_strdup("color"), g_strdup("#000000")) ;
      g_hash_table_insert(infoHash, g_strdup("style"), g_strdup("simple_draw")) ;
      int isHighDens = isHighDensityTrack(myTracksInOrder[ii]) ;
      myTrackUrlInfo *localUrlInfo = createDefaultTrackInfo(fmethod, fsource, isHighDens) ;
      g_hash_table_insert(infoHash, g_strdup("urlInfo"), localUrlInfo) ;
      g_hash_table_insert(tempTrackHash, g_strdup(myTracksInOrder[ii]), infoHash) ;
    }
  }
  setTrackName2TrackHash();
  if(numberOfRecords)
    navigationTrack = makeTrack();
  if(getPrintXML())
    fprintf(stderr, "<GENBOREETRACKS>\n");

  int counter = 0;
  int numberGenboreeDatabases = getNumberDatabases();
  counter = numberGenboreeDatabases - 1 ;
  char *tempTrackName ;
  // go though template and user db
  // first set defaults, then group defaults and finally user defaults
  while(counter >= 0)
  {
    char *databaseName = getDatabaseFromId(counter) ;
    // do it for the default settings first
    updateTrackInfoHash(0, databaseName) ;
    // Now do it for the user settings
    updateTrackInfoHash(getMyUserId(), databaseName) ;
    counter -- ;
  }
  for (ii = 0; ii <= numberOfRecords; ii++)
  {

    if(myTracksInOrder[ii] && strlen(myTracksInOrder[ii]) > 1)
    {

      g_hash_table_insert(trackHash, g_strdup(myTracksInOrder[ii]), g_strdup(myTracksInOrder[ii]));
      visibility = returnMyVisibilityValue(myTracksInOrder[ii]);

      if(getPrintXML())
      {
        className = returnMyVisibilityClassName(myTracksInOrder[ii]);
        if(className == NULL || strlen(className) < 1)
        {
            className = strdup("ThisClass");
        }
        size = myBase64_encode(myTracksInOrder[ii], strlen(myTracksInOrder[ii]), &base64);
        if(printEncripted)
        {
            fprintf(stderr, "<TRACKVIS trackName=\"%s\" "
                    "visibility=\"%d\" order=\"%d\" className=\"%s\"> "
                    "</TRACKVIS>\n", base64, visibility, ii, className);
        }
        else
        {
            fprintf(stderr, "<TRACKVIS trackName=\"%s\" "
                    "visibility=\"%d\" order=\"%d\" className=\"%s\"> "
                    "</TRACKVIS>\n", myTracksInOrder[ii], visibility, ii, className);
        }
        free(base64);
        base64 = NULL;
        free(className);
        className = NULL;
      }

      if(visibility == VIS_HIDE && !getDisplayEmptyTracks())
      {
        continue;
      }
      navigationTrack->trackName = strdup(myTracksInOrder[ii]);
      navigationTrack->isHighDensityTrack = isHighDensityTrack(myTracksInOrder[ii]);
      // Set it always even for non high density tracks
      // Can be used for drawing multicolor barcharts for non high density tracks
      setHasHighDensityTracks(navigationTrack->isHighDensityTrack);
      navigationTrack->highDensFtypes = fillUpHighDensFtypes(myTracksInOrder[ii]);

      navigationTrack->vis = visibility;
      tempLinkString = getRawLink(myTracksInOrder[ii]);
      navigationTrack->linkTemplates = processLinkString(tempLinkString, &numberOfTemplates);       //TODO check this function

      navigationTrack->numberOfTemplates = numberOfTemplates;
      free(tempLinkString);
      tempLinkString = NULL;
      /*navigationTrack->color = getFeatureTypeColorCheckingAllDatabases(myTracksInOrder[ii]);
      if(!navigationTrack->color)
      {
        navigationTrack->color = strdup(defaultColor);
      }*/
      navigationTrack->color = g_hash_table_lookup(g_hash_table_lookup(tempTrackHash, myTracksInOrder[ii]), "color") ;
     /* navigationTrack->style = getTheStyleUsedCheckingAllDatabases(myTracksInOrder[ii]);
      if(!navigationTrack->style)
      {
        navigationTrack->style = strdup(defaultStyle);
      }*/
      navigationTrack->style = g_hash_table_lookup(g_hash_table_lookup(tempTrackHash, myTracksInOrder[ii]), "style") ;
      //navigationTrack->trackUrlInfo = getTrackURLCheckingAllDatabases(myTracksInOrder[ii]);
      navigationTrack->trackUrlInfo = g_hash_table_lookup(g_hash_table_lookup(tempTrackHash, myTracksInOrder[ii]), "urlInfo") ;

      lengthOfStyleName = strlen(navigationTrack->style);

      if(!strncmp
          (navigationTrack->style, GLOBALSMALLHISTOGRAM, lengthOfStyleName)
          || !strncmp(navigationTrack->style, GLOBALLARGEHISTOGRAM, lengthOfStyleName)
          || !strncmp(navigationTrack->style, LOCALSMALLHISTOGRAM, lengthOfStyleName)
          || !strncmp(navigationTrack->style, LOCALLARGEHISTOGRAM, lengthOfStyleName)
          || !strncmp(navigationTrack->style, BIDIRECTIONALGLOBALHISTOGRAMLARGE, lengthOfStyleName)
          || !strncmp(navigationTrack->style, BIDIRECTIONALLOCALHISTOGRAMLARGE, lengthOfStyleName)
        )
      {
        isHistogram = true;
      }
      else
      {
        isHistogram = false;
      }

      if(navigationTrack->isHighDensityTrack == 1 && !isHistogram)
      {
        navigationTrack->isHighDensityTrack = 0;
      }

      if(isHistogram)
      {
        if(!strncmp(navigationTrack->style, GLOBALSMALLHISTOGRAM, lengthOfStyleName))
        {
            if(navigationTrack->isHighDensityTrack == 0)
            {
              navigationTrack->maxScore = generateMaxScoreFromTrackName(navigationTrack->trackName, 0);
              navigationTrack->minScore = generateMinScoreFromTrackName(navigationTrack->trackName, 0);
            }
//bypass the normal visibility settings largeScore_draw always look compact 032408
            navigationTrack->vis = VIS_DENSE;
        }
        else if(!strncmp(navigationTrack->style, GLOBALLARGEHISTOGRAM, lengthOfStyleName))
        {
            if(navigationTrack->isHighDensityTrack == 0)
            {
              navigationTrack->maxScore = generateMaxScoreFromTrackName(navigationTrack->trackName, 0);
              navigationTrack->minScore = generateMinScoreFromTrackName(navigationTrack->trackName, 0);
//bypass the normal visibility settings largeScore_draw always look compact 032408
            }
            navigationTrack->vis = VIS_DENSE;
        }
        else if(!strncmp(navigationTrack->style, BIDIRECTIONALGLOBALHISTOGRAMLARGE, lengthOfStyleName)){
          if(navigationTrack->isHighDensityTrack == 0){
            navigationTrack->maxScore = generateMaxScoreFromTrackName(navigationTrack->trackName, 0);
            navigationTrack->minScore = generateMinScoreFromTrackName(navigationTrack->trackName, 0);
          }
          navigationTrack->vis = VIS_DENSE;
        }
        else if(!strncmp(navigationTrack->style, BIDIRECTIONALLOCALHISTOGRAMLARGE, lengthOfStyleName)){
          if(navigationTrack->isHighDensityTrack == 0){
            navigationTrack->maxScore = generateMaxScoreFromTrackName(navigationTrack->trackName, 0);
            navigationTrack->minScore = generateMinScoreFromTrackName(navigationTrack->trackName, 0);
          }
          navigationTrack->vis = VIS_DENSE;
        }
        else if(!strncmp(navigationTrack->style, LOCALSMALLHISTOGRAM, lengthOfStyleName))
        {
            if(navigationTrack->isHighDensityTrack == 0)
            {
              navigationTrack->maxScore = generateMaxScoreFromTrackName(navigationTrack->trackName, 1);
              navigationTrack->minScore = generateMinScoreFromTrackName(navigationTrack->trackName, 1);
            }
//bypass the normal visibility settings largeScore_draw always look compact 032408
            navigationTrack->vis = VIS_DENSE;
        }
        else if(!strncmp(navigationTrack->style, LOCALLARGEHISTOGRAM, lengthOfStyleName))
        {
            if(navigationTrack->isHighDensityTrack == 0)
            {
              navigationTrack->maxScore = generateMaxScoreFromTrackName(navigationTrack->trackName, 1);
              navigationTrack->minScore = generateMinScoreFromTrackName(navigationTrack->trackName, 1);
            }
//bypass the normal visibility settings largeScore_draw always look compact 032408
            navigationTrack->vis = VIS_DENSE;
        }
      }
      else
      {
        if(!strncmp(navigationTrack->style, FADETOWHITE, lengthOfStyleName))
        {
          navigationTrack->maxScore = generateMaxScoreFromTrackName(navigationTrack->trackName, 0);
          navigationTrack->minScore = generateMinScoreFromTrackName(navigationTrack->trackName, 0);
        }
        else if(!strncmp(navigationTrack->style, FADETOGRAY, lengthOfStyleName))
        {
          navigationTrack->maxScore = generateMaxScoreFromTrackName(navigationTrack->trackName, 0);
          navigationTrack->minScore = generateMinScoreFromTrackName(navigationTrack->trackName, 0);
        }
        else if(!strncmp(navigationTrack->style, FADETOBLACK, lengthOfStyleName))
        {
          navigationTrack->maxScore = generateMaxScoreFromTrackName(navigationTrack->trackName, 0);
          navigationTrack->minScore = generateMinScoreFromTrackName(navigationTrack->trackName, 0);
        }
        else if(!strncmp(navigationTrack->style, DIFFGRADIENT, lengthOfStyleName))
        {
          navigationTrack->maxScore = generateMaxScoreFromTrackName(navigationTrack->trackName, 0);
          navigationTrack->minScore = generateMinScoreFromTrackName(navigationTrack->trackName, 0);
        }
//This else statement bypass the normal visibility settings making chromosome_draw always look like vis = compact 030405
        else if(!strncmp(navigationTrack->style, CHROMOSOMEDRAW, lengthOfStyleName))
        {
          navigationTrack->vis = VIS_DENSE;
        }
      }

      if(loadFirstTrack)
      {
        setTrackList(navigationTrack);
        loadFirstTrack = 0;
      }
      insertTrackInTrackName2TrackHash(navigationTrack);
      if(ii < numberOfRecords)
      {
        parentTrack = navigationTrack;
        navigationTrack->next = makeTrack();
        navigationTrack = navigationTrack->next;
      }
    }
  }
  timeItNow("C-DONE - done filling track info") ;
  if(getPrintXML())
  {
    fprintf(stderr, "</GENBOREETRACKS>\n");
  }
  if(parentTrack && parentTrack->next && !parentTrack->next->trackName)
  {
    free(parentTrack->next);
    parentTrack->next = NULL;
  }
  timeItNow("C-DONE - Before fillTracks() in function generateTracks");

  fillTracks();

  fillTrackListOfGroups();
  timeItNow("C-DONE - After fillTrackListOfGroups() in function generateTracks");

  if(!getDisplayEmptyTracks())
  {
    eliminateEmptyTracks();
  }
  g_hash_table_destroy(trackHash);
  g_hash_table_destroy(tempTrackHash);
  return;
}

int initializeProcess(long refSeqId, char *myEntrypointName, long long from, long long to)
{
  MAP_READER *myReader = NULL;
  startLocalConnection(1);
  if(!validateForm(refSeqId))
    return 0;
  setRefSeqId(refSeqId);
  setDatabaseNames(refSeqId);
  setDatabase2HostHash();
  setDatabase2ConnectionHash();
  setMyDatabaseToUse(getDatabaseFromId(0));
  startLocalConnection(2);
  if(!verifyDatabases())
    return 0;
  myReader = construct_map_reader();
  setFileToFileHandlerHash();
  setMapReader(myReader);
  setTagsHash();
  setGbTrackVarsHash();
  setGbTrackRecordTypesHash();
  setEntryPointNameProperties(myEntrypointName);
  fix_coords(&from, &to, getEntrypointLength(0));
  setStartPositionGloblal(from);
  setEndPositionGloblal(to);
  setMaxNumberOfElementsToProcess((int)sizeof(gdouble));
  setSizeOfElementsUsedToGetMaxNumElements((int)sizeof(gdouble));
  fillTypeIdHash();
  setInStatements();
  setAllFmethodFsource();
  setAllSortFmethodFsource();
  setTotalWidthGlobal(labelWidthGlobal + getTrackWidth());
  setCanvasWidthGlobal(getTrackWidth());
  setLengthOfSegmentGlobal(endPositionGloblal - startPositionGlobal);   //if I add the + 1 in here the old tracks do not get to the end
  setUniversalScaleGlobal((double)(canvasWidthGlobal) / (double)(lengthOfSegmentGlobal));
  setBasesPerPixel();
  setFeatureQueries();
  setFeatureHash();
  setLinkInfoHash();
  fillGclassHash();
  fillAttNameIdForTemplateDb();
  fillAttNameIdForUserDb();
  setFeatureToGclassHash();
  if(!getGroupOrderUsingXml())
    if(!createArrayOrderedTracks())
      return 0;
  setGroupHash();
  setGroupCounter(0);
  setGroupIds2GroupHash();
  fillFtype2Attributes();
  fillFtypeAttrDisplay();
  generateTracks();
  setGenomicFileName();

  return 1;
}

void finalizeProcess(int newSchema)
{
  char *tempString = NULL;
  int *myArrayUploadIds = NULL;

  myArrayUploadIds = getArrayUploadIds();

  if(newSchema)
  {
    destroyAllHashesInHashManager();
    destroyAllHashesInHDManager();

    if(getArrayOrderedTracks() != NULL)
    {
        destroyDoublePointer(getArrayOrderedTracks(), getNumberOfTracks());
    }
    destroyDoublePointer(getFeatureQueries(), getNumberDatabases());
    destroyDoublePointer(getInStatements(), getNumberDatabases());
    free(myArrayUploadIds);
    myArrayUploadIds = NULL;
    tempString = getEntrypointName();
    free(tempString);
    tempString = NULL;
  }
  destroyBufferToReadChars();
  destroyBufferToReadDoubles();
  destroyBufferToReadValueOfAPixel();

  delete_map_reader(getMapReader());
  destroyGifName();
  destroyIMAPName();
  destroyDoublePointer(getDatabaseNames(), getNumberDatabases());
  eraseFtypeIdsStatementByDatabaseId();
  deleteDbHost();
  deleteGenboreeUserNameAndPassWord();
//       deleteArrayOfOrderedTracks(); // Trying to clean memory but this array is double free() ??

  closeLocalConnection(1);
  closeLocalConnection(2);
  deleteBuffers();
  return;
}

char *returnType(char *trackName, int whichToReturn)
{
  char fmethod[MAXLENGTHOFTEMPSTRING] = "";
  char fsource[MAXLENGTHOFTEMPSTRING] = "";
  char *feature = NULL;
  char *occurance = NULL;

  if(!trackName || strlen(trackName) < 1)
  {
      return NULL;
  }

  feature = strdup(trackName);
  occurance = strstr(feature, ":");
  *occurance = '\0';
  if(!whichToReturn)
  {
      strcpy(fmethod, feature);
      free(feature);
      feature = NULL;
      return strdup(fmethod);
  }
  else
  {
      occurance++;
      strcpy(fsource, occurance);
      free(feature);
      feature = NULL;
      return strdup(fsource);
  }

  return NULL;
}

char *returnStripedName(char *geneName)
{
  char name[MAXLENGTHOFTEMPSTRING] = "";
  char *feature = NULL;
  char *occurance = NULL;

  if(!geneName || strlen(geneName) < 1)
  {
      return NULL;
  }

  feature = strdup(geneName);
  occurance = strstr(feature, ".");
  if(occurance)
  {
      *occurance = '\0';
      strcpy(name, feature);
      free(feature);
      feature = NULL;
      return strdup(name);
  }
  else
  {
      free(feature);
      feature = NULL;
      return strdup(geneName);
  }
}

char *URLUTF8Encoder(char *data)
{
  char hexString[] = {
    "%00%01%02%03%04%05%06%07%08%09%0a%0b%0c%0d%0e%0f%10%11%12%13%14%15%16%17%18%19%1a%1b%1c%1d%1e%1f%20%21%22%23%24%25%26%27%28%29%2a%2b%2c%2d%2e%2f%30%31%32%33%34%35%36%37%38%39%3a%3b%3c%3d%3e%3f%40%41%42%43%44%45%46%47%48%49%4a%4b%4c%4d%4e%4f%50%51%52%53%54%55%56%57%58%59%5a%5b%5c%5d%5e%5f%60%61%62%63%64%65%66%67%68%69%6a%6b%6c%6d%6e%6f%70%71%72%73%74%75%76%77%78%79%7a%7b%7c%7d%7e%7f%80%81%82%83%84%85%86%87%88%89%8a%8b%8c%8d%8e%8f%90%91%92%93%94%95%96%97%98%99%9a%9b%9c%9d%9e%9f%a0%a1%a2%a3%a4%a5%a6%a7%a8%a9%aa%ab%ac%ad%ae%af%b0%b1%b2%b3%b4%b5%b6%b7%b8%b9%ba%bb%bc%bd%be%bf%c0%c1%c2%c3%c4%c5%c6%c7%c8%c9%ca%cb%cc%cd%ce%cf%d0%d1%d2%d3%d4%d5%d6%d7%d8%d9%da%db%dc%dd%de%df%e0%e1%e2%e3%e4%e5%e6%e7%e8%e9%ea%eb%ec%ed%ee%ef%f0%f1%f2%f3%f4%f5%f6%f7%f8%f9%fa%fb%fc%fd%fe%ff"
};
  int len = strlen(data);
  char *escapedString = (char *)calloc((len * 3) + 6, sizeof(char));
  int escapedPosition = 0;
  int dataPosition = 0;
  int hexStringPosition = 0;

  while (len--)
  {
      if('A' <= data[dataPosition] && data[dataPosition] <= 'Z')
      {
        escapedString[escapedPosition] = data[dataPosition];
        escapedPosition++;
      }
      else if('a' <= data[dataPosition] && data[dataPosition] <= 'z')
      {
        escapedString[escapedPosition] = data[dataPosition];
        escapedPosition++;
      }
      else if('0' <= data[dataPosition] && data[dataPosition] <= '9')
      {
        escapedString[escapedPosition] = data[dataPosition];
        escapedPosition++;
      }
      else if(data[dataPosition] == ' ')
      {
        escapedString[escapedPosition] = '+';
        escapedPosition++;
      }
      else if(data[dataPosition] == '-' || data[dataPosition] == '_'
        || data[dataPosition] == '.' || data[dataPosition] == '!'
        || data[dataPosition] == '~' || data[dataPosition] == '*'
        || data[dataPosition] == '\'' || data[dataPosition] == '(' || data[dataPosition] == ')')
      {
        escapedString[escapedPosition] = data[dataPosition];
        escapedPosition++;
      }
      else
      {
        hexStringPosition = data[dataPosition] * 3;
        escapedString[escapedPosition] = hexString[hexStringPosition];
        escapedPosition++;
        hexStringPosition++;
        escapedString[escapedPosition] = hexString[hexStringPosition];
        escapedPosition++;
        hexStringPosition++;
        escapedString[escapedPosition] = hexString[hexStringPosition];
        escapedPosition++;
      }
      dataPosition++;
  }

  return escapedString;
}

char *returnResultExtractingField(myAnnotations * currentAnnotation, char *pattern, char *fieldName)
{
  char *value = NULL;
  char tempString[MAXLENGTHOFTEMPSTRING];
  pcre *re = NULL;
  char *result;
  int useField = -20;
  GHashTable *myTagHash = getTagsHash();
  int *myTag = NULL;

  if(fieldName == NULL || strlen(fieldName) < 1)
  {
      return NULL;
  }

  memset(tempString, '\0', MAXLENGTHOFTEMPSTRING);

  tempString[0] = '$';
  strcat(tempString, fieldName);

  myTag = (int *)g_hash_table_lookup(myTagHash, tempString);
  if(myTag)
  {
      useField = *myTag;
  }

  if(useField > 0)
  {
      value = fieldValue(currentAnnotation, tempString);
  }
  else
  {
    memset(tempString, '\0', MAXLENGTHOFTEMPSTRING);
    strcat(tempString, fieldName);
    value = strdup(tempString);
  }

  result = returnRegExPattern(pattern, value, &re);

  free(re);                     /* Release memory used for the compiled pattern */
  re = NULL;
  free(value);
  value = NULL;

  return result;
}

char *extractInfoFromValuePairValue(char *pattern, char *valuePairValue)
{
  pcre *re = NULL;
  char *result;

  fprintf(stderr,
          "inside extractInfoFromValuePairValue  the pattern is %s and the valuePairValue = %s\n",
          pattern, valuePairValue);
  fflush(stderr);

  result = returnRegExPattern(pattern, valuePairValue, &re);

  fprintf(stderr, "inside extractInfoFromValuePairValue the result is %s\n", result);
  fflush(stderr);

  free(re);                     /* Release memory used for the compiled pattern */
  re = NULL;

  return result;
}

char *extractPatternFromField(char *substring)
{
  char *regex = NULL;
  regex = returnPartRegExVP(substring, 1);
  return regex;
}

char *extractNameFromField(char *substring)
{
  char *field = NULL;
  field = returnPartRegExVP(substring, 0);
  return field;
}

char *transformLinkTemplate(myAnnotations * currentAnnotation)
{
  char *linkLine = NULL;
  int i = 0;
  char *firstString = NULL;
  char *urlSafeString = NULL;
  char **linkTemplate = currentAnnotation->parentGroup->parentTrack->linkTemplates;
  STRINGOUT *myLocalStringOut = getStringOut();
  urlMemAlloc += 1;

  if(!linkTemplate)
  {
    return NULL;
  }

  stringout_clear(myLocalStringOut);

  if(!linkTemplate)
  {
    return NULL;
  }

  linkLine = linkTemplate[0];
  i = 0;
  while (linkLine)
  {
    if(linkLine[0] != '$')
    {
      stringout_append(myLocalStringOut, linkLine);
      i++;
      linkLine = linkTemplate[i];
      continue;
    }

    firstString = fieldValue(currentAnnotation, linkLine);

    if(firstString)
    {
      urlSafeString = g_uri_escape_string(firstString, getEncodeSchema(), TRUE);
      free(firstString);
      firstString = NULL;
    }
    if(urlSafeString)
    {
      stringout_append(myLocalStringOut, urlSafeString);
      free(urlSafeString);
      urlSafeString = NULL;
    }
    i++;
    linkLine = linkTemplate[i];
  }

  if(strlen(myLocalStringOut->buf))
  {
    return strdup(myLocalStringOut->buf);
  }
  else
  {
    return NULL;
  }
}

void processLinksGroupAware(int initialHeight, int visibility, int theHeight,
                            int mid, float thick, int maxLevel, myGroup * initialGroup)
{
  int b_start = 0;
  int b_width = 0;
  int b_end = 0;
  int y1 = 0;
  int y2 = 0;
  myGroup *currentGroup = initialGroup;
  myAnnotations *currentAnnotation = NULL;
  long groupStart = 0;
  long groupEnd = 0;
  int ii = 0;
  MAP_ELEMENT *m;
  MAP_READER *mr = getMapReader();
  long fixGroupEnd = 0;
  char scoreStr[555] = "";

  for (ii = 0; ii <= maxLevel; ii++)
  {
    currentGroup = initialGroup;
    while (currentGroup)
    {
      if(currentGroup->level == ii)
      {
        if(visibility == VIS_FULL || visibility == VIS_FULLNAME || visibility == VIS_FULLTEXT)
        {
          y1 = initialHeight + mid + (currentGroup->level * theHeight) - thick;
        }
        else if(visibility == VIS_DENSE || visibility == VIS_DENSEMC)
        {
          y1 = initialHeight + mid - thick;
        }
        else
        {
          y1 = 0;
        }

        y2 = y1 + (2 * thick);

        groupStart = currentGroup->groupStart;
        groupEnd = currentGroup->groupEnd;
        fixGroupEnd = currentGroup->groupEnd;
        if(groupEnd < startPositionGlobal || groupStart > endPositionGloblal)
        {
          continue;
        }
        b_start = calculateStart(groupStart, 0);
        b_end = calculateEnd(groupStart, b_start, groupEnd, 0);

        b_width = b_end - b_start;
        b_end = returnEndOfText(visibility, currentGroup->groupName, b_end, currentGroup->level);

        map_reader_add_group(mr, currentGroup->groupName, b_start, y1, b_end, y2, groupStart, fixGroupEnd);

        currentAnnotation = currentGroup->annotations;
        while (currentAnnotation)
        {
          if(currentAnnotation->end < startPositionGlobal || currentAnnotation->start > endPositionGloblal)
          {
            continue;
          }

          b_start = calculateStart(currentAnnotation->start, 0);
          b_end = calculateEnd(currentAnnotation->start, b_start, currentAnnotation->end, 0);
          b_end = returnEndOfText(visibility, currentGroup->groupName, b_end, currentAnnotation->level);
          sprintf(scoreStr, "%.*lf", 2, currentAnnotation->score);
          m = map_reader_add_annotation(mr, b_start, y1, b_end, y2,
                                        currentGroup->groupClass,
                                        currentGroup->groupName,
                                        currentAnnotation->start, currentAnnotation->end, scoreStr);
          m->userdata = currentAnnotation;
          memset(scoreStr, '\0', 555);
          currentAnnotation = currentAnnotation->next;
        }
      }
      currentGroup = currentGroup->next;
    }
  }
}

void processLinksGroupUnaware(int initialHeight, int visibility, int theHeight,
                              int mid, float thick, int maxLevel, myGroup * initialGroup)
{
  int b_start = 0;
  int b_width = 0;
  int b_end = 0;
  int y1 = 0;
  int y2 = 0;
  myGroup *currentGroup = initialGroup;
  myAnnotations *currentAnnotation = NULL;
  long groupStart = 0;
  long groupEnd = 0;
  int i = 0;
  gdFontPtr font = gdFontTiny;
  MAP_ELEMENT *m;
  MAP_READER *mr = getMapReader();
  long fixGroupEnd = 0;
  myTrack *groupTrack = initialGroup->parentTrack;
  int isPieChart = 0;
  long long length = lengthOfSegmentGlobal + 1;
  long long canvasWidth = canvasWidthGlobal;
  float boxSize = (float)canvasWidth / (float)length;
  int middleFactor = 0;
  int extraSpaceStart = 0;
  int extra_width = 0;
  int extraSpaceEnd = 0;
  char scoreStr[555] = "";

  middleFactor = round((boxSize / 2) - (font->w / 2));

  if(groupTrack->vis != VIS_DENSEMC && groupTrack->vis != VIS_DENSE)
  {
    if(strcasecmp(groupTrack->style, "pieChart_draw") == 0)
    {
      isPieChart = 1;
    }
  }

  for (i = 0; i <= maxLevel; i++)
  {
    currentGroup = initialGroup;
    while (currentGroup)
    {
      groupStart = currentGroup->groupStart;
      fixGroupEnd = currentGroup->groupEnd;
      groupEnd = currentGroup->groupEnd + 1;
      if(groupEnd < startPositionGlobal || groupStart > endPositionGloblal)
      {
        continue;
      }

      if(groupStart < startPositionGlobal)
      {
        groupStart = startPositionGlobal;
      }
      if(groupEnd > endPositionGloblal)
      {
        groupEnd = endPositionGloblal;
      }

      b_start = calculateStart(groupStart, 0);
      b_end = calculateEnd(groupStart, b_start, groupEnd, 0);

      b_width = b_end - b_start;
      b_end = returnEndOfText(visibility, currentGroup->groupName, b_end, currentGroup->level);

      if(isPieChart && (visibility == VIS_FULLNAME || visibility == VIS_FULLTEXT || visibility == VIS_FULL))
      {
        extraSpaceStart = b_start + (middleFactor / 2);
        extra_width = b_end - b_start;
        extraSpaceEnd = extraSpaceStart + extra_width + ADDSPACETOPIECHARTLINK;
        map_reader_add_group(mr, currentGroup->groupName, extraSpaceStart,
                             y1 + 5, extraSpaceEnd, y2 + 5, groupStart, fixGroupEnd);
      }
      else
      {
        map_reader_add_group(mr, currentGroup->groupName, b_start, y1, b_end, y2, groupStart, fixGroupEnd);
      }
      currentAnnotation = currentGroup->annotations;
      while (currentAnnotation)
      {
        if(currentAnnotation->end < startPositionGlobal || currentAnnotation->start > endPositionGloblal)
        {
            continue;
        }
        if(visibility == VIS_FULL || visibility == VIS_FULLNAME || visibility == VIS_FULLTEXT)
        {
            y1 = initialHeight + mid + (currentAnnotation->level * theHeight) - thick;
        }
        else if(visibility == VIS_DENSE || visibility == VIS_DENSEMC)
        {
            y1 = initialHeight + mid - thick;
        }
        else
        {
            y1 = 0;
        }

        y2 = y1 + (2 * thick);
        if(currentAnnotation->level == i)
        {
          if(currentAnnotation->end < startPositionGlobal || currentAnnotation->start > endPositionGloblal)
          {
            continue;
          }

          b_start = calculateStart(currentAnnotation->start, 0);
          b_end = calculateEnd(currentAnnotation->start, b_start, currentAnnotation->end, 0);
          b_end = returnEndOfText(visibility, currentGroup->groupName, b_end, currentAnnotation->level);
          sprintf(scoreStr, "%.*lf", 2, currentAnnotation->score);
          if(isPieChart && (visibility == VIS_FULLNAME || visibility == VIS_FULLTEXT || visibility == VIS_FULL))
          {
            m = map_reader_add_annotation(mr, extraSpaceStart, y1 + 5,
                                            extraSpaceEnd, y2 + 5,
                                            currentGroup->groupClass,
                                            currentGroup->groupName,
                                            currentAnnotation->start, currentAnnotation->end, scoreStr);
            //Piechart track is a SPECIAL track the image map is generated in a different way
          }
          else
          {
            m = map_reader_add_annotation(mr, b_start, y1, b_end, y2,
                currentGroup->groupClass,
                currentGroup->groupName,
                currentAnnotation->start, currentAnnotation->end, scoreStr);
          }

          m->userdata = currentAnnotation;
          memset(scoreStr, '\0', 555);
        }
        currentAnnotation = currentAnnotation->next;
      }
      currentGroup = currentGroup->next;
    }
  }
}

void newClickThrough(int trackStart, myTrack * localTrack)
{
  int theHeight = 0;
  int visibility = localTrack->vis;
  float thickness = 0.8;
  float thick = 0;
  int mid = 0;
  int maxLevel = 0;
  int initialHeight = trackStart;

  if(!localTrack->groups)
    return;

  if((strcasecmp(localTrack->style, "negative_draw") == 0) || (strcasecmp(localTrack->style, "groupNeg_draw") == 0))
  {
    initialHeight += 4;
  }

  theHeight = getImageMapHeight(localTrack->style);
  mid = theHeight / 2;
  thick = (theHeight * thickness) / 2;
  maxLevel = localTrack->maxLevel;

  if(getGroupAwareness(localTrack->style))
  {
    processLinksGroupAware(initialHeight, visibility, theHeight, mid, thick, maxLevel, localTrack->groups);
  }
  else
  {
    processLinksGroupUnaware(initialHeight, visibility, theHeight, mid, thick, maxLevel, localTrack->groups);
  }
}

void makeImageMapForStaticTracks(char *trackName, int initialHeight, int hightOfTrack)  //TALLSCORE
{
  int numberOfLinks = getNumberStaticLinks();
  long startPosition = startPositionGlobal;
  long stopPosition = endPositionGloblal;
  FILE *myMapPointerFile = getMapPointerFile();
  long lengthInBps = stopPosition - startPosition;
  int pixelLenght = totalWidthGlobal - labelWidthGlobal;
  double bpsInPixel = (double)lengthInBps / (double)pixelLenght;
  int segmentLengthInbps = lengthInBps / numberOfLinks;
  int segmentLengthInPixels = (int)((double)segmentLengthInbps / bpsInPixel);
  int Ystart = initialHeight;
  int Yend = initialHeight + hightOfTrack;
  int currentStart = labelWidthGlobal;
  int currentEnd = currentStart + segmentLengthInPixels;
  long initialbpPosition = startPositionGlobal;
  long endBpPosition = initialbpPosition + segmentLengthInbps;
  int ii = 0;

  for (ii = 0; ii < numberOfLinks; ii++)
  {
    fprintf(myMapPointerFile, "hdhv\t%s\t%d\t%d\t%d\t%d\t%ld\t%ld\t+\n",
            trackName, currentStart, Ystart, currentEnd, Yend, initialbpPosition, endBpPosition);
    currentStart = currentEnd + 1;
    currentEnd = currentStart + segmentLengthInPixels;
    initialbpPosition = endBpPosition + 1;
    endBpPosition = initialbpPosition + segmentLengthInbps;
  }

}

void makeImageMap(void)
{
  timeItNow("C-DONE - starting makeImageMap()");
  char **myTracksInOrder = getArrayOrderedTracks();
  GHashTable *myTrack2Name = getTrackName2TrackHash();
  int numberOfRecords = getMaxOrder();
  int yy = getStartFirstTrack();
  int previousY = 0;
  int nn = 0;
  int bb = 0;
  myTrack *ptrTrack = NULL;
  FILE *myMapPointerFile = getMapPointerFile();
  int ii = 0;
  MAP_ELEMENT *me;
  MAP_READER *mr = getMapReader();
  STRINGOUT *localStringOut = construct_stringout();
  int sizeOfNewText = 0;
  myAnnotations *temporaryAnnotation = NULL;
  int visibility = 0;
  int commentsPresent = 0;
  char upfid[255] = "";
  int additionalFactor = 0;
  long *recordsInFidtext = getArrayRecordsInfidText();
  long tempNumberRecords = 0;
  int recordsInDatabase = 0;
  int noTracksDrawn = 0 ;
  if(recordsInFidtext == NULL)
  {
    setArrayRecordsInfidText();
    recordsInFidtext = getArrayRecordsInfidText();
    if(recordsInFidtext != NULL)
    {
      recordsInDatabase = 1;
    }
  }
  else
  {
    recordsInDatabase = 1;
  }

  setStringOut(localStringOut); // This is a vector structure used by Andrei to store the information about links
  if(myTracksInOrder == NULL)
  {
    return;
  }

  if(!mr)
  {
    return;
  }

  for (ii = 0; ii <= numberOfRecords; ii++)
  {
    if(myTracksInOrder[ii] && strlen(myTracksInOrder[ii]) > 1)
    {
      if(truncateTracks == 1 && noOfTracksToDraw == noTracksDrawn)
      {
        break ;
      }
      ptrTrack = (myTrack *) g_hash_table_lookup(myTrack2Name, myTracksInOrder[ii]);
      visibility = ptrTrack->vis;
      if(!getDisplayEmptyTracks())
      {
        if(!ptrTrack)
        {
          continue;
        }
        else if(ptrTrack->isHighDensityTrack && ptrTrack->vis != VIS_HIDE)
        {
          // avoid deleting the high density tracks
        }
        else if(ptrTrack->groups == NULL)
        {
          continue;
        }
      }
      // skip if visibility is hidden
      if(!ptrTrack || visibility == VIS_HIDE)
      {
        continue;
      }
      // Use static map if high density track
      if(ptrTrack->isHighDensityTrack != 0)
      {
        highDensFtypes *localHDInfo = ptrTrack->highDensFtypes;
        makeImageMapForStaticTracks(ptrTrack->trackName, yy, localHDInfo->gbTrackPxHeight);
        yy += ptrTrack->height;
        yy += getSpaceBetweenTracks();
        noTracksDrawn += 1 ;
        continue;
      }
      timeItNow(ptrTrack->trackName);
      fprintf(stderr, "track: %s, style: %s\n", ptrTrack->trackName, ptrTrack->style) ;
      previousY = yy;
      newClickThrough(yy, ptrTrack);
      yy += ptrTrack->height;
      me = map_reader_add_track(mr, ptrTrack->trackName, labelWidthGlobal, previousY, totalWidthGlobal, yy);
      print_map_element(me, myMapPointerFile) ;
      nn = map_reader_get_count(mr);
      for (bb = 0; bb < nn; bb++)
      {
        me = map_reader_element_at(mr, bb);
        if(me->etype == MAP_ETYPE_ANNOTATION)
        {
          temporaryAnnotation = (myAnnotations *) me->userdata;
          me->links = transformLinkTemplate(temporaryAnnotation);
          sprintf(upfid, "%cY%d:%ld",
                      temporaryAnnotation->orientation, temporaryAnnotation->uploadId, temporaryAnnotation->id);
          me->x2 += additionalFactor;
          me->upfid = strdup(upfid);
        }
        print_map_element(me, myMapPointerFile);
      }
      yy += getSpaceBetweenTracks();
      map_reader_purge(mr);
      noTracksDrawn += 1 ;
    }
  }
  delete_stringout(getStringOut());
  return;
}

rgbColorStruct *fromHexaToRGB(char *hexavalue)
{
  rgbColorStruct *colors;
  char hexaChar[10];
  int aa = 0;
  int bb[3];
  int xx = 0;
  int ii = 0;

  if(strlen(hexavalue) < 7 || hexavalue[0] != '#')
  {
    fprintf(stderr, "There is a problem with the color string should be #dddddd but is %s\n", hexavalue);
    return NULL;
  }

  if((colors = (rgbColorStruct *) malloc(1 * sizeof(rgbColorStruct))) == NULL)
  {
    perror("problems with allocating memory using malloc");
    return NULL;
  }

  for (ii = 0, xx = 0; ii < 3; ii++)
  {
    memset(hexaChar, '\0', 10);
    xx++;
    hexaChar[0] = (char)(tolower((int)(hexavalue[xx])));
    xx++;
    hexaChar[1] = (char)tolower((int)(hexavalue[xx]));
    sscanf(hexaChar, "%x", &aa);
    bb[ii] = aa;
  }

  colors->r = bb[0];
  colors->g = bb[1];
  colors->b = bb[2];

  return colors;
}

struct rgbColor *fromrgbMyStruct2rgbColor(rgbColorStruct * myColor)
{
  struct rgbColor *colorUsed;
  if((colorUsed = (struct rgbColor *)malloc(1 * sizeof(struct rgbColor))) == NULL)
  {
    perror("problems with allocating memory using malloc");
    return NULL;
  }

  colorUsed->r = (Color) myColor->r;
  colorUsed->g = (Color) myColor->g;
  colorUsed->b = (Color) myColor->b;

  return colorUsed;

}

struct rgbColor *transformColor(char *colorUsed)
{
  rgbColorStruct *myColor;
  struct rgbColor *theColorUsed;

  myColor = fromHexaToRGB(colorUsed);
  theColorUsed = fromrgbMyStruct2rgbColor(myColor);
  free(myColor);
  myColor = NULL;
  return theColorUsed;
}

void mainDraw(gdImagePtr im, int trackStart, myTrack * localTrack)
{
  myGroup *currentGroup = NULL;
  struct rgbColor *color, *upperColor, *lowerColor;
  struct rgbColor *negativeColor, *upperNegativeColor, *lowerNegativeColor;
  int allocatedColor;
  // For multicolor bar-charts
  int allocatedUpperColor = 0, allocatedLowerColor = 0;
  // For bidirectional bar-charts
  int allocatedUpperNegativeColor = 0, allocatedLowerNegativeColor = 0, allocatedNegativeColor = 0;
  int *multicolor = NULL;
  int numberMultiColors = 5;
  int initialHeight = trackStart;
  int theHeight = 0;
  int visibility = localTrack->vis;
  if(localTrack->isHighDensityTrack && localTrack->vis != VIS_HIDE)
  {
//do not skip the high density tracks
  }
  else
  {
    currentGroup = localTrack->groups;

    if(!currentGroup)
      return;
  }
  multicolor = (int *)calloc(numberMultiColors, sizeof(int));

  if(!multicolor)
  {
    perror("problems with multiColors");
    return;
  }

  if(localTrack->vis == VIS_DENSEMC || localTrack->vis == VIS_DENSE)
  {
    if(strcasecmp(localTrack->style, "pieChart_draw") == 0)
    {
        free(localTrack->style);
        localTrack->style = NULL;
        localTrack->style = strdup(PIECHARTSUBSTITUTION);
    }
  }

  if(localTrack->isHighDensityTrack && localTrack->vis != VIS_HIDE)
  {
    highDensFtypes *localHDInfo = localTrack->highDensFtypes;
    theHeight = localHDInfo->gbTrackPxHeight;
  }
  else if(!(localTrack->isHighDensityTrack) && localTrack->vis != VIS_HIDE)
  {
    if(strcasecmp(localTrack->style, "bidirectional_draw_large") == 0 || strcasecmp(localTrack->style, "bidirectional_local_draw_large") == 0){
      highDensFtypes *localHDInfo = localTrack->highDensFtypes;
      theHeight = localHDInfo->gbTrackPxHeight;
    }
    else{
      theHeight = getMyTrackHeight(localTrack->style);
    }
  }

  color = transformColor(localTrack->color);
  allocatedColor = gdImageColorResolve(im, color->r, color->g, color->b);
  free(color);
  color = NULL;

  if(localTrack->vis == VIS_DENSEMC || localTrack->vis == VIS_DENSE)
  {
      multicolor[0] = gdImageColorResolve(im, GENE_COLORS[0].r, GENE_COLORS[0].g, GENE_COLORS[0].b);
      multicolor[1] = gdImageColorResolve(im, GENE_COLORS[1].r, GENE_COLORS[1].g, GENE_COLORS[1].b);
      multicolor[2] = gdImageColorResolve(im, GENE_COLORS[2].r, GENE_COLORS[2].g, GENE_COLORS[2].b);
      multicolor[3] = gdImageColorResolve(im, GENE_COLORS[3].r, GENE_COLORS[3].g, GENE_COLORS[3].b);
  }

  // For barchart styles, check if zoom levels are available for the region
  // if there are zoom levels, get them and return 1 from the function, else
  // return 0
  if(strcasecmp(localTrack->style, GLOBALSMALLHISTOGRAM) == 0 ||
    strcasecmp(localTrack->style, GLOBALLARGEHISTOGRAM) == 0 ||
    strcasecmp(localTrack->style, LOCALSMALLHISTOGRAM) == 0 ||
    strcasecmp(localTrack->style, LOCALLARGEHISTOGRAM) == 0 ||
    strcasecmp(localTrack->style, BIDIRECTIONALGLOBALHISTOGRAMLARGE) == 0 ||
    strcasecmp(localTrack->style, BIDIRECTIONALLOCALHISTOGRAMLARGE) == 0
    )
  {
    int zoomLevels = getZoomLevels(localTrack);
    if(zoomLevels != 1 && localTrack->isHighDensityTrack){
      processHighDensityBlocks(localTrack);
      timeItNow("C-DONE - processHighDensityBlocks");
      fprintf(stderr, "   trackName: %s\n", localTrack->trackName) ;
    }
    else if(zoomLevels != 1 && !localTrack->isHighDensityTrack)
    {
      localTrack->pixelValueForHDT = NULL;
      localTrack->pixelNegativeValueForHDT = NULL;
    }
  }
  // get the attributes (used also for non high density tracks)
  highDensFtypes *localHDInfo = localTrack->highDensFtypes;
  // Check if multicolor drawing is required
  // Check for 'gbTrackPxScoreUpperThreshold' and 'gbTrackPxScoreUpperThresholdColor' first.
  if(localHDInfo->gbTrackPxScoreUpperThresholdColor != NULL && localHDInfo->gbTrackPxScoreUpperThreshold != (gdouble)-4290772992.0){
    // Make sure color is not bogus (not full proof. Cross your fingers!)
    if(strlen(localHDInfo->gbTrackPxScoreUpperThresholdColor) == 7 && localHDInfo->gbTrackPxScoreUpperThresholdColor[0] == '#'){
      upperColor = transformColor(localHDInfo->gbTrackPxScoreUpperThresholdColor);
      allocatedUpperColor = gdImageColorResolve(im, upperColor->r, upperColor->g, upperColor->b);
      free(upperColor);
      upperColor = NULL;
    }
    // As good as NULL
    else{
      localHDInfo->gbTrackPxScoreUpperThresholdColor = NULL;
      allocatedUpperColor = 0;
    }
  }
  else{
    allocatedUpperColor = 0;
  }
  // Check for 'gbTrackPxScoreLowerThreshold' and 'gbTrackPxScoreLowerThresholdColor.
  if(localHDInfo->gbTrackPxScoreLowerThresholdColor != NULL && localHDInfo->gbTrackPxScoreLowerThreshold != (gdouble)4290772992.0){
    // Check color is not bogus
    if(strlen(localHDInfo->gbTrackPxScoreLowerThresholdColor) == 7 && localHDInfo->gbTrackPxScoreLowerThresholdColor[0] == '#'){
      lowerColor = transformColor(localHDInfo->gbTrackPxScoreLowerThresholdColor);
      allocatedLowerColor = gdImageColorResolve(im, lowerColor->r, lowerColor->g, lowerColor->b);
      free(lowerColor);
      lowerColor = NULL;
    }
    else{
      localHDInfo->gbTrackPxScoreLowerThresholdColor = NULL;
      allocatedLowerColor = 0;
    }
  }
  else{
    allocatedLowerColor = 0;
  }
  // Check for 'gbTrackPxScoreUpperNegativeThreshold' and 'gbTrackPxScoreUpperNegativeThresholdColor'
  if(localHDInfo->gbTrackPxScoreUpperNegativeThresholdColor != NULL && localHDInfo->gbTrackPxScoreUpperNegativeThreshold != (gdouble)-4290772992.0){
    // Make sure color is not bogus (not full proof. Cross your fingers!)
    if(strlen(localHDInfo->gbTrackPxScoreUpperNegativeThresholdColor) == 7 && localHDInfo->gbTrackPxScoreUpperNegativeThresholdColor[0] == '#'){
      upperNegativeColor = transformColor(localHDInfo->gbTrackPxScoreUpperNegativeThresholdColor);
      allocatedUpperNegativeColor = gdImageColorResolve(im, upperNegativeColor->r, upperNegativeColor->g, upperNegativeColor->b);
      free(upperNegativeColor);
      upperNegativeColor = NULL;
    }
    // As good as NULL
    else{
      localHDInfo->gbTrackPxScoreUpperNegativeThresholdColor = NULL;
      allocatedUpperNegativeColor = 0;
    }
  }
  else{
    allocatedUpperNegativeColor = 0;
  }
  // Check for 'gbTrackPxScoreLowerNegativeThreshold' and 'gbTrackPxScoreLowerNegativeThresholdColor.
  if(localHDInfo->gbTrackPxScoreLowerNegativeThresholdColor != NULL && localHDInfo->gbTrackPxScoreLowerNegativeThreshold != (gdouble)4290772992.0){
    // Check color is not bogus
    if(strlen(localHDInfo->gbTrackPxScoreLowerNegativeThresholdColor) == 7 && localHDInfo->gbTrackPxScoreLowerNegativeThresholdColor[0] == '#'){
      lowerNegativeColor = transformColor(localHDInfo->gbTrackPxScoreLowerNegativeThresholdColor);
      allocatedLowerNegativeColor = gdImageColorResolve(im, lowerNegativeColor->r, lowerNegativeColor->g, lowerNegativeColor->b);
      free(lowerNegativeColor);
      lowerNegativeColor = NULL;
    }
    else{
      localHDInfo->gbTrackPxScoreLowerNegativeThresholdColor = NULL;
      allocatedLowerNegativeColor = 0;
    }
  }
  else{
    allocatedLowerNegativeColor = 0;
  }
  // Check for 'gbTrackNegativeColor'. If it does not exist, set it as the default track color
  if(localHDInfo->gbTrackNegativeColor != NULL && strlen(localHDInfo->gbTrackNegativeColor) == 7 && localHDInfo->gbTrackNegativeColor[0] == '#'){
    negativeColor = transformColor(localHDInfo->gbTrackNegativeColor);
    allocatedNegativeColor = gdImageColorResolve(im, negativeColor->r, negativeColor->g, negativeColor->b);
    free(negativeColor);
    negativeColor = NULL;
  }
  else{
    allocatedNegativeColor = allocatedColor;
  }
  // For High density tracks
  if(localTrack->isHighDensityTrack)
  {
    // Check if bidirectional drawing is required or regular drawing is required
    if(strcasecmp(localTrack->style, BIDIRECTIONALGLOBALHISTOGRAMLARGE) == 0 || strcasecmp(localTrack->style, BIDIRECTIONALLOCALHISTOGRAMLARGE) == 0){
      bidirectional_drawGD(im, localTrack, visibility, multicolor, initialHeight, theHeight, allocatedColor, localHDInfo->gbTrackDataMax, localHDInfo->gbTrackDataMin, allocatedUpperColor, allocatedLowerColor, allocatedNegativeColor, allocatedUpperNegativeColor, allocatedLowerNegativeColor);
    }
    else{
      wigLarge_drawGD(im, localTrack, visibility, multicolor, initialHeight,
                    theHeight, allocatedColor,
                    localHDInfo->gbTrackDataMax, localHDInfo->gbTrackDataMin, allocatedUpperColor, allocatedLowerColor);
    }
  }
  // For non high density tracks
  else
  {
    if(strcasecmp(localTrack->style, BIDIRECTIONALLOCALHISTOGRAMLARGE) == 0 || strcasecmp(localTrack->style, BIDIRECTIONALGLOBALHISTOGRAMLARGE) == 0){
      bidirectional_drawGD_nonHighDensityTracks(im, localTrack, visibility, multicolor, initialHeight, theHeight, allocatedColor, localTrack->maxScore, localTrack->minScore, allocatedUpperColor, allocatedLowerColor, allocatedNegativeColor, allocatedUpperNegativeColor, allocatedLowerNegativeColor, currentGroup);
    }
    else{
      drawDispatcherGD(im, currentGroup, visibility, multicolor, allocatedColor,
                     initialHeight, theHeight, localTrack->style, localTrack->maxScore, localTrack->minScore, allocatedUpperColor, allocatedLowerColor, localTrack);
    }
  }
  free(multicolor);
  multicolor = NULL;
  return;

}


// get zoom levels for tracks if present
// returns 1 if zoom levels found, 0 otherwise
int getZoomLevels(myTrack * localTrack)
{
  int retVal = 0;
  // get the appropriate zoom levels
  highDensFtypes *localHDInfo = localTrack->highDensFtypes;
  int windowingMethod = localHDInfo->gbTrackWindowingMethod;
  // get only average scores per window
  if(windowingMethod == 0){
    gdouble bpPerPixel = ((gdouble)(endPositionGloblal - startPositionGlobal) + 1) / (gdouble)canvasWidthGlobal;
    retVal = getAvgZoomLevels(bpPerPixel, localTrack);
  }
  // get only max scores per window
  else if(windowingMethod == 1){
    gdouble bpPerPixel = ((gdouble)(endPositionGloblal - startPositionGlobal) + 1) / (gdouble)canvasWidthGlobal;
    retVal = getMaxZoomLevels(bpPerPixel, localTrack);
  }
  // get only min scores per window
  else if(windowingMethod == 2){
    gdouble bpPerPixel = ((gdouble)(endPositionGloblal - startPositionGlobal) + 1) / (gdouble)canvasWidthGlobal;
    retVal = getMinZoomLevels(bpPerPixel, localTrack);
  }
  return retVal;
}

// get the zoom level records for the required region
// get only the max score for the region
int getMaxZoomLevels(gdouble bpPerPixel, myTrack * localTrack)
{
  int retValue = 0;
  // set up required info
  highDensFtypes *localHDInfo = localTrack->highDensFtypes;
  int res = (int)log10(bpPerPixel);
  // Immediately return if resolution is lower than 4
  if(res < 4)
  {
    fprintf(stderr, "res smaller than 4. Will have to read the bin file/fdata2 \n");
    fflush(stderr);
    return 0 ;
  }
  char mainQuery[] =
      "SELECT fstart, fstop, scoreMax, scoreMin FROM zoomLevels WHERE ";
  char *resultingQuery = NULL;
  char finalQuery[MAXLENGTHOFTEMPSTRING] = "";
  resultingQuery = appendMaxMinBinToQuery(0, mainQuery);
  char *track = strdup(localTrack->trackName);
  char *fmethod = strtok(track, ":");
  char *fsource = strtok(NULL, ":");
  int numRows;
  int ftypeid = getftypeidFromFmethodFsource(getDatabaseFromId(0), fmethod, fsource);
  sprintf(finalQuery, "%s(%d) and level = %d", resultingQuery, ftypeid, res);
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  resetLocalConnection(getDatabaseFromId(0));
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);
  if(mysql_real_query(connection, finalQuery, strlen(finalQuery)) != 0)
  {
    fprintf(stderr, "Error querying the zoomLevels table in local database\n");
    fprintf(stderr, mysql_error(&mysql));
    fflush(stderr);
    return 0;
  }

  sqlresult = mysql_store_result(connection);
  if(mysql_num_rows(sqlresult) == 0)
  {
    fprintf(stderr, "No records found in zoomLevels table. Will have to read the bin file/fdata2 records \n");
    fflush(stderr);
    return 0;
  }
  else{
    numRows = mysql_num_rows(sqlresult);
  }
  localTrack->pixelValueForHDT = (gdouble *) calloc(canvasWidthGlobal + 2, sizeof(gdouble));
  localTrack->pixelNegativeValueForHDT = (gdouble *) calloc(canvasWidthGlobal + 2, sizeof(gdouble));
  int numberOfRecords;
  gdouble trackMin ;
  gdouble trackMax ;
  if(localTrack->isHighDensityTrack)
  {
    trackMin = localHDInfo->gbTrackDataMin ;
    trackMax = localHDInfo->gbTrackDataMax ;
  }
  else
  {
    trackMin = requestMinScore(ftypeid, 0, 0) ;
    trackMax = requestMaxScore(ftypeid, 0, 0) ;
  }
  for(numberOfRecords = 0; numberOfRecords < (canvasWidthGlobal + 2); numberOfRecords ++){
    localTrack->pixelValueForHDT[numberOfRecords] = trackMin - 1.0;
    localTrack->pixelNegativeValueForHDT[numberOfRecords] = trackMax + 1.0;
  }
  int annotationStart;
  int annotationEnd;
  long trackStart = getStartPosition();
  long trackStop = getEndPosition();
  int start;
  int end;
  int currentLocation;
  int numberOfBasesToProcess;
  float temporaryScore;
  float negTemporaryScore;
  double lastPixel;
  double firstPixel;
  long lastPixelLong;
  long firstPixelLong;
  long j, i;
  int locationToUpdate;
  gdouble yIntercept = localHDInfo->gbTrackYIntercept;
  int canvasSize = canvasWidthGlobal;
  // collect all scores
  while ((row = mysql_fetch_row(sqlresult)) != NULL){
    temporaryScore = atof(row[2]);
    // Get start and stop for the annotation/record.
    annotationStart = atoi(row[0]);
    annotationEnd = atoi(row[1]);
    negTemporaryScore = atof(row[3]);
    // Set start and stop for the block
    if(annotationStart < trackStart){
      currentLocation = trackStart;
    }
    else{
      currentLocation = annotationStart;
    }
    firstPixel = -1;
    lastPixel = -1;
    locationToUpdate = (currentLocation - trackStart) + 1;
    firstPixelLong = (long)((locationToUpdate - 1) / bpPerPixel);
    lastPixelLong =  bpPerPixel < 1 ? (long)(firstPixelLong + (1.0 / bpPerPixel)) : (long)((locationToUpdate - 1) / bpPerPixel);
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
    j = 0;
    if(strcasecmp(localTrack->style, BIDIRECTIONALLOCALHISTOGRAMLARGE) == 0 || strcasecmp(localTrack->style, BIDIRECTIONALGLOBALHISTOGRAMLARGE) == 0)
    {
      // for values above the y intercept
      if(temporaryScore > yIntercept){
        for (j = firstPixelLong; j <= lastPixelLong; j++){
          if(temporaryScore > localTrack->pixelValueForHDT[j]){
            localTrack->pixelValueForHDT[j] = temporaryScore;
          }
        }
      }
      // for values below the y intercept
      // for the values below y intercept, the min values are actually the 'max' values when the drawing method is 'MAX'
      if(negTemporaryScore < yIntercept){
        for (j = firstPixelLong; j <= lastPixelLong; j++){
          if(negTemporaryScore < localTrack->pixelNegativeValueForHDT[j]){
            localTrack->pixelNegativeValueForHDT[j] = negTemporaryScore;
          }
        }
      }
    }
    else
    {
      for (j = firstPixelLong; j <= lastPixelLong; j++){
        if(temporaryScore > localTrack->pixelValueForHDT[j]){
          localTrack->pixelValueForHDT[j] = temporaryScore;
        }
      }
    }

  }
  mysql_free_result(sqlresult);
  resetLocalConnection(getDatabaseFromId(0));
  closeLocalConnection(2) ;
  return 1;
}



// get the zoom level records for the required region
// get only the min scores for the region
int getMinZoomLevels(gdouble bpPerPixel, myTrack * localTrack)
{
  int retValue = 0;
  // set up required info
  highDensFtypes *localHDInfo = localTrack->highDensFtypes;
  int res = (int)log10(bpPerPixel);
  // Immediately return if resolution is lower than 4
  if(res < 4)
  {
    fprintf(stderr, "res smaller than 4. Will have to read the bin file/fdata2 \n");
    fflush(stderr);
    return 0 ;
  }
  char mainQuery[] =
      "SELECT scoreMin, fstart, fstop, scoreMax FROM zoomLevels WHERE ";
  char *resultingQuery = NULL;
  char finalQuery[MAXLENGTHOFTEMPSTRING] = "";
  resultingQuery = appendMaxMinBinToQuery(0, mainQuery);
  char *track = strdup(localTrack->trackName);
  char *fmethod = strtok(track, ":");
  char *fsource = strtok(NULL, ":");
  int ftypeid = getftypeidFromFmethodFsource(getDatabaseFromId(0), fmethod, fsource);
  sprintf(finalQuery, "%s(%d) and level = %d %s", resultingQuery, ftypeid, res, "order by fstart");
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  resetLocalConnection(getDatabaseFromId(0));
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);
  if(mysql_real_query(connection, finalQuery, strlen(finalQuery)) != 0)
  {
    fprintf(stderr, "Error querying the zoomLevels table in local database\n");
    fprintf(stderr, mysql_error(&mysql));
    fflush(stderr);
    return 0;
  }
  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult) == 0)
  {
    fprintf(stderr, "No records found in zoomLevels table. Will have to read the bin file/fdata2 \n");
    fflush(stderr);
    return 0;
  }
  localTrack->pixelValueForHDT = (gdouble *) calloc(canvasWidthGlobal + 2, sizeof(gdouble));
  localTrack->pixelNegativeValueForHDT = (gdouble *)calloc(canvasWidthGlobal + 2, sizeof(gdouble));
  int numberOfRecords;
  gdouble trackMin ;
  gdouble trackMax ;
  if(localTrack->isHighDensityTrack)
  {
    trackMin = localHDInfo->gbTrackDataMin ;
    trackMax = localHDInfo->gbTrackDataMax ;
  }
  else
  {
    trackMin = requestMinScore(ftypeid, 0, 0) ;
    trackMax = requestMaxScore(ftypeid, 0, 0) ;
  }
  for(numberOfRecords = 0; numberOfRecords < (canvasWidthGlobal + 2); numberOfRecords ++){
    localTrack->pixelValueForHDT[numberOfRecords] = trackMax + 1.0;
    localTrack->pixelNegativeValueForHDT[numberOfRecords] = trackMin - 1.0;
  }
  int annotationStart;
  int annotationEnd;
  long trackStart = getStartPosition();
  long trackStop = getEndPosition();
  int start;
  int end;
  int currentLocation;
  int numberOfBasesToProcess;
  float temporaryScore;
  float negTemporaryScore;
  double lastPixel;
  double firstPixel;
  long lastPixelLong;
  long firstPixelLong;
  long j, i;
  int locationToUpdate;
  gdouble yIntercept = localHDInfo->gbTrackYIntercept;
  int canvasSize = canvasWidthGlobal;
  // collect all scores
  while ((row = mysql_fetch_row(sqlresult)) != NULL){
    temporaryScore = atof(row[0]);
    // Get start and stop for the annotation/record.
    annotationStart = atoi(row[1]);
    annotationEnd = atoi(row[2]);
    negTemporaryScore = atof(row[3]);
    // Set start and stop for the block
    if(annotationStart < trackStart){
      start = trackStart;
      currentLocation = start;
    }
    else{
      start = annotationStart;
      currentLocation = start;
    }
    if(annotationEnd > trackStop){
      end = trackStop;
    }
    else{
      end = annotationEnd;
    }
    // The following code has been copied from the updatePixelStruct function in highDensityTracks.c
    firstPixel = -1;
    lastPixel = -1;
    locationToUpdate = (currentLocation - trackStart) + 1;
    firstPixelLong = (long)((locationToUpdate - 1) / bpPerPixel);
    lastPixelLong =  bpPerPixel < 1 ? (long)(firstPixelLong + (1.0 / bpPerPixel)) : (long)((locationToUpdate - 1) / bpPerPixel);
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
    } // end of updatePixelStruct()
    // The following code has been copied from the updatePixelValue function in highDensityTracks.c
    j = 0;
    if(strcasecmp(localTrack->style, BIDIRECTIONALLOCALHISTOGRAMLARGE) == 0 || strcasecmp(localTrack->style, BIDIRECTIONALGLOBALHISTOGRAMLARGE) == 0)
    {
      if(temporaryScore > yIntercept){
        for (j = firstPixelLong; j <= lastPixelLong; j++){
          if(temporaryScore < localTrack->pixelValueForHDT[j]){
            localTrack->pixelValueForHDT[j] = temporaryScore;
          }
        }
      }
      // for values below the y intercept
      // for the values below y intercept, the max values are actually the 'min' values when the drawing method is 'MIN'
      if(negTemporaryScore < yIntercept){
        for (j = firstPixelLong; j <= lastPixelLong; j++){
          if(negTemporaryScore > localTrack->pixelNegativeValueForHDT[j]){
            localTrack->pixelNegativeValueForHDT[j] = negTemporaryScore;
          }
        }
      }
    }
    else
    {
      for (j = firstPixelLong; j <= lastPixelLong; j++){
        if(temporaryScore < localTrack->pixelValueForHDT[j]){
          localTrack->pixelValueForHDT[j] = temporaryScore;
        }
      }
    }
  }
  mysql_free_result(sqlresult);
  resetLocalConnection(getDatabaseFromId(0));
  return 1;
}


// get the zoom level records for the required region
// get only the avg scores for the region
int getAvgZoomLevels(gdouble bpPerPixel, myTrack * localTrack)
{
  // set up required info
  highDensFtypes *localHDInfo = localTrack->highDensFtypes;
  int res = (int)log10(bpPerPixel);
  // Immediately return if resolution is lower than 4
  if(res < 4)
  {
    fprintf(stderr, "res smaller than 4. Will have to read the bin file/fdata2 \n");
    fflush(stderr);
    return 0 ;
  }
  char mainQuery[] =
      "SELECT fstart, fstop, scoreCount, scoreSum, negScoreCount, negScoreSum FROM zoomLevels WHERE ";
  char *resultingQuery = NULL;
  char finalQuery[MAXLENGTHOFTEMPSTRING] = "";
  resultingQuery = appendMaxMinBinToQuery(0, mainQuery);
  char *track = strdup(localTrack->trackName);
  char *fmethod = strtok(track, ":");
  char *fsource = strtok(NULL, ":");
  int ftypeid = getftypeidFromFmethodFsource(getDatabaseFromId(0), fmethod, fsource);
  sprintf(finalQuery, "%s(%d) and level = %d %s", resultingQuery, ftypeid, res, "order by fstart");
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  resetLocalConnection(getDatabaseFromId(0));
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);
  if(mysql_real_query(connection, finalQuery, strlen(finalQuery)) != 0)
  {
    fprintf(stderr, "Error querying the zoomLevels table in local database\n");
    fprintf(stderr, mysql_error(&mysql));
    fflush(stderr);
    return 0;
  }
  sqlresult = mysql_store_result(connection);
  if(mysql_num_rows(sqlresult) == 0)
  {
    fprintf(stderr, "No records found in zoomLevels table. Will have to read the bin file/fdata2 \n");
    fflush(stderr);
    return 0;
  }
  localTrack->pixelValueForHDT = (gdouble *) calloc(canvasWidthGlobal + 2, sizeof(gdouble));
  localTrack->pixelExtraValues = (gdouble *) calloc(canvasWidthGlobal + 2, sizeof(gdouble));
  localTrack->pixelNegativeValueForHDT = (gdouble *) calloc(canvasWidthGlobal + 2, sizeof(gdouble));
  localTrack->pixelExtraNegativeValues = (gdouble *) calloc(canvasWidthGlobal + 2, sizeof(gdouble));
  int numberOfRecords;
  gdouble minValueToUse ;
  if(localTrack->isHighDensityTrack)
    minValueToUse = (gdouble)(localHDInfo->gbTrackDataMin - 1.0);
  else
    minValueToUse = (gdouble)(requestMinScore(ftypeid, 0, 0) - 1.0) ;
  for(numberOfRecords = 0; numberOfRecords < (canvasWidthGlobal + 2); numberOfRecords ++){
    localTrack->pixelValueForHDT[numberOfRecords] = minValueToUse;
    localTrack->pixelNegativeValueForHDT[numberOfRecords] = minValueToUse;
  }
  int annotationStart;
  int annotationEnd;
  long trackStart = getStartPosition();
  long trackStop = getEndPosition();
  int start;
  int end;
  int currentLocation;
  int numberOfBasesToProcess;
  gdouble temporaryScore;
  gdouble temporarySum;
  gdouble temporaryCount;
  gdouble negTemporarySum;
  gdouble negTemporaryCount;
  gdouble totalSum;
  gdouble totalCount;
  double lastPixel;
  double firstPixel;
  long lastPixelLong;
  long firstPixelLong;
  long j, i;
  int locationToUpdate;
  gdouble yIntercept = localHDInfo->gbTrackYIntercept;
  int canvasSize = canvasWidthGlobal;
  gdouble pixelsPerBlock;
  int partitioningReq ;
  if(localHDInfo->gbTrackPartitioning == NULL)
  {
    partitioningReq = 0;
  }
  else if(strcasecmp(localHDInfo->gbTrackPartitioning, "true") == 0)
  {
    partitioningReq = 1;
  }
  else if(strcasecmp(localHDInfo->gbTrackPartitioning, "false") == 0)
  {
    partitioningReq = 0;
  }
  else
  {
    partitioningReq = 0;
  }
  // collect all scores
  while ((row = mysql_fetch_row(sqlresult)) != NULL){
    temporarySum = (gdouble)atof(row[3]);
    temporaryCount = (gdouble)atof(row[2]);
    // Get start and stop for the annotation/record.
    annotationStart = atoi(row[0]);
    annotationEnd = atoi(row[1]);
    negTemporaryCount = (gdouble)atof(row[4]);
    negTemporarySum = (gdouble)atof(row[5]);
    // Set start and stop for the block
    if(annotationStart < trackStart){
      start = trackStart;
      currentLocation = start;
    }
    else{
      start = annotationStart;
      currentLocation = start;
    }
    if(annotationEnd > trackStop){
      end = trackStop;
    }
    else{
      end = annotationEnd;
    }
    // The following code has been copied from the updatePixelStruct function in highDensityTracks.c
    firstPixel = -1;
    lastPixel = -1;
    locationToUpdate = (currentLocation - trackStart) + 1;
    firstPixelLong = (long)((locationToUpdate - 1) / bpPerPixel);
    lastPixelLong =  bpPerPixel < 1 ? (long)(firstPixelLong + (1.0 / bpPerPixel)) : (long)((locationToUpdate - 1) / bpPerPixel);
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
    } // end of updatePixelStruct()
    // The following code has been copied from the updatePixelValue function in highDensityTracks.c
    j = 0;
    totalSum = temporarySum + negTemporarySum;
    totalCount = temporaryCount + negTemporaryCount;
    if(strcasecmp(localTrack->style, BIDIRECTIONALLOCALHISTOGRAMLARGE) == 0 || strcasecmp(localTrack->style, BIDIRECTIONALGLOBALHISTOGRAMLARGE) == 0)
    {
      if(partitioningReq == 0)
      {
        if((gdouble)(totalSum / totalCount) > yIntercept){
          for(j = firstPixelLong; j <= lastPixelLong; j++){
            if(localTrack->pixelValueForHDT[j] == minValueToUse){
              localTrack->pixelValueForHDT[j] = totalSum;
              localTrack->pixelExtraValues[j] = totalCount;
            }
            else{
              localTrack->pixelValueForHDT[j] += totalSum;
              localTrack->pixelExtraValues[j] += totalCount;
            }
          }
        }
        else if((gdouble)(totalSum / totalCount) < yIntercept){
          for(j = firstPixelLong; j <= lastPixelLong; j++){
            if(localTrack->pixelNegativeValueForHDT[j] == minValueToUse){
              localTrack->pixelNegativeValueForHDT[j] = totalSum;
              localTrack->pixelExtraNegativeValues[j] = totalCount;
            }
            else{
              localTrack->pixelNegativeValueForHDT[j] += totalSum;
              localTrack->pixelExtraNegativeValues[j] += totalCount;
            }
          }
        }
      }
      else
      {
        if((gdouble)(temporarySum / temporaryCount) > yIntercept)
        {
          for(j = firstPixelLong; j <= lastPixelLong; j++){
            if(localTrack->pixelValueForHDT[j] == minValueToUse){
              localTrack->pixelValueForHDT[j] = temporarySum;
              localTrack->pixelExtraValues[j] = temporaryCount;
            }
            else{
              localTrack->pixelValueForHDT[j] += temporarySum;
              localTrack->pixelExtraValues[j] += temporaryCount;
            }
          }
        }
        if((gdouble)(negTemporarySum / negTemporaryCount) < yIntercept)
        {
          if(localTrack->pixelNegativeValueForHDT[j] == minValueToUse)
          {
            localTrack->pixelNegativeValueForHDT[j] = negTemporarySum;
            localTrack->pixelExtraNegativeValues[j] = negTemporaryCount;
          }
          else
          {
            localTrack->pixelNegativeValueForHDT[j] += negTemporarySum;
            localTrack->pixelExtraNegativeValues[j] += negTemporaryCount;
          }
        }
      }
    }
    else
    {
      gdouble minValue = (gdouble)(localHDInfo->gbTrackDataMin - 1.0);
      for(j = firstPixelLong; j <= lastPixelLong; j++){
        if(localTrack->pixelValueForHDT[j] == minValue){
          localTrack->pixelValueForHDT[j] = totalSum;
          localTrack->pixelExtraValues[j] = totalCount;
        }
        else{
          localTrack->pixelValueForHDT[j] += totalSum;
          localTrack->pixelExtraValues[j] += totalCount;
        }

      }
    }
  }
  mysql_free_result(sqlresult);
  resetLocalConnection(getDatabaseFromId(0));
  return 1;
}



void printUsingTTFonts(gdImagePtr im, int y)
{
  int length = 0;
  int hight = 0;
  int brect[8];
  char *err;
  char *font1 = "/usr/local/brl/data/genboree/resources/fonts/ttf/timess.ttf:bold:italic";
  double sz = 8.;
  char tempString[MAXLENGTHOFTEMPSTRING];
  int extra = 0;
  int labelLength = 0;
  int startingLabel = 0;
  int red = gdImageColorResolve(im, 255, 0, 0);
  gdFTUseFontConfig(1);

  memset(tempString, '\0', MAXLENGTHOFTEMPSTRING);
  sprintf(tempString, "UCSF-UBC");
  err = gdImageStringFT(NULL, &brect[0], 0, font1, sz, 0., 0, 0, tempString);
  labelLength = brect[2] - brect[0];
  hight = brect[1] - brect[7];
  fprintf(stderr, "the length = %d and the hight = %d\n", length, hight);
  startingLabel = labelWidthGlobal - labelLength;
  extra = y + hight + 20;
  err = gdImageStringFT(im, &brect[0], red, font1, sz, 0., startingLabel, extra, tempString);

}

int getSizeNeededByTrackAttributes(myTrack * ptrTrack)
{
  GHashTable *ftypeid2AttributeDisplayHash = getFtypeid2AttributeDisplayHash();
  GHashTable *attributeHash2TrackAttDisplays;
  GHashTableIter iter;
  gpointer key, value;
  int space = 0;

  attributeHash2TrackAttDisplays =
      (GHashTable *) g_hash_table_lookup(ftypeid2AttributeDisplayHash, ptrTrack->trackName);

  if(attributeHash2TrackAttDisplays == NULL)
  {
      return 0;
  }
  g_hash_table_iter_init(&iter, attributeHash2TrackAttDisplays);
  if(g_hash_table_size(attributeHash2TrackAttDisplays) > 0)
  {
      space = SPACEAFTERTRACKNAME;
  }

  while (g_hash_table_iter_next(&iter, &key, &value))
  {
      space += SPACEBETWEENFTYPEATT;
  }

  return space;

}

gint rankTrackAttr(gconstpointer a, gconstpointer b)
{
  trackAttDisplays *aTrack = (trackAttDisplays *) a;
  trackAttDisplays *bTrack = (trackAttDisplays *) b;

  if(aTrack->flaglocal < bTrack->flaglocal)
    return -1;

  if(aTrack->flaglocal > bTrack->flaglocal)
    return 1;

  if(aTrack->sourceDb < bTrack->sourceDb)
    return -1;

  if(aTrack->sourceDb > bTrack->sourceDb)
    return 1;

  if(aTrack->rank < bTrack->rank)
    return -1;

  if(aTrack->rank > bTrack->rank)
    return 1;

  return 0;
}

void printTracksVPs(gdImagePtr im, int ycoord, myTrack * ptrTrack)
{
  GHashTable *ftypeid2AttributeDisplayHash = getFtypeid2AttributeDisplayHash();
  GHashTable *attributeHash2TrackAttDisplays;
  int extra = 0;
  int labelLength = 0;
  int startingLabel = 0;
  struct rgbColor *color;
  int allocatedColor = 0;
  GHashTableIter iter;
  gpointer key, value;
  int sizeOfHash = 0;
  GList *listOfTrackDisplay = NULL;

  attributeHash2TrackAttDisplays =
      (GHashTable *) g_hash_table_lookup(ftypeid2AttributeDisplayHash, ptrTrack->trackName);

  if(attributeHash2TrackAttDisplays == NULL)
  {
      return;
  }

  g_hash_table_iter_init(&iter, attributeHash2TrackAttDisplays);
  sizeOfHash = g_hash_table_size(attributeHash2TrackAttDisplays);

  if(sizeOfHash > 0)
  {
      extra = ycoord + SPACEAFTERTRACKNAME;
  }

  while (g_hash_table_iter_next(&iter, &key, &value))
  {
      trackAttDisplays *tempAttDisp = (trackAttDisplays *) value;
      listOfTrackDisplay = g_list_append(listOfTrackDisplay, tempAttDisp);
  }

  listOfTrackDisplay = g_list_sort(listOfTrackDisplay, rankTrackAttr);

  while (listOfTrackDisplay)
  {
      trackAttDisplays *sortedTrack = (trackAttDisplays *) listOfTrackDisplay->data;
      labelLength = strlen(sortedTrack->textToPrint);
      startingLabel = labelWidthGlobal - (labelLength * gdFontTiny->w);
      color = transformColor(sortedTrack->color);

      allocatedColor = gdImageColorResolve(im, color->r, color->g, color->b);
      gdImageString(im, gdFontTiny, startingLabel, extra, (unsigned char *)sortedTrack->textToPrint, allocatedColor);

      extra += SPACEBETWEENFTYPEATT;
      listOfTrackDisplay = g_list_next(listOfTrackDisplay);
  }
  g_list_free(listOfTrackDisplay);

}

void drawTracksGD(gdImagePtr im, struct rgbColor colorLeftPanel)
{
  long canvasWidth = canvasWidthGlobal ;
  char **myTracksInOrder = getArrayOrderedTracks() ;
  GHashTable *myTrack2Name = getTrackName2TrackHash() ;
  int numberOfRecords = getMaxOrder() ;
  int ii = 0 ;
  int yy = getStartFirstTrack() ;
  myTrack *ptrTrack = NULL ;
  int black = gdImageColorResolve(im, 0, 0, 0) ;
  int darkRed = gdImageColorResolve(im, 139, 0, 0) ;
  int labelLength = 0;
  int startingLabel = 0;
  char *temporaryLabel = NULL;
  int maxLength = 18;
  int startDrawing = labelWidthGlobal;
  int initialLength = 0;
  int finalLength = 0;
  int numOfTracksDrawn = 0 ;
  gdFontPtr font = gdFontMediumBold ;
  int fontHight = font->h + 2;
  int leftColor = gdImageColorResolve(im, colorLeftPanel.r, colorLeftPanel.g,
                                      colorLeftPanel.b);
  FILE *myMapPointerFile = getMapPointerFile();
  if(myTracksInOrder == NULL)
    return;

  if(getUseMargins())
    gdImageFilledRectangle(im, 0, IMG_BORDER, 8, getTotalHeight() + getStartFirstTrack(), leftColor);

  for (ii = 0; ii <= numberOfRecords; ii++)
  {
    if(myTracksInOrder[ii] && strlen(myTracksInOrder[ii]) > 1)
    {
      if(truncateTracks == 1) //This means we cannot draw all tracks because there are too many. To see how this was generated, go to calculateImageHeight()
      {
        if(numOfTracksDrawn == noOfTracksToDraw)
        {
          temporaryLabel = "NOTE: Skipping the remaining tracks." ;
          labelLength = strlen(temporaryLabel) * font->w;
          startingLabel = startDrawing + (canvasWidth - labelLength) / 2;
          gdImageString(im, font, startingLabel, (yy - fontHight) + 30, (unsigned char *)temporaryLabel, darkRed);
          temporaryLabel = "Due to bugs in popular browsers such as Internet Explorer and" ;
          labelLength = strlen(temporaryLabel) * font->w;
          startingLabel = startDrawing + (canvasWidth - labelLength) / 2;
          gdImageString(im, font, startingLabel, (yy - fontHight) + 50, (unsigned char *)temporaryLabel, darkRed);
          temporaryLabel = "Firefox, images taller than 32,000 pixels cannot be drawn properly." ;
          labelLength = strlen(temporaryLabel) * font->w;
          startingLabel = startDrawing + (canvasWidth - labelLength) / 2;
          gdImageString(im, font, startingLabel, (yy - fontHight) + 60, (unsigned char *)temporaryLabel, darkRed);
          temporaryLabel = "If you need to see some of the skipped tracks, please" ;
          labelLength = strlen(temporaryLabel) * font->w;
          startingLabel = startDrawing + (canvasWidth - labelLength) / 2;
          gdImageString(im, font, startingLabel, (yy - fontHight) + 80, (unsigned char *)temporaryLabel, darkRed);
          temporaryLabel = "select just those ones for viewing." ;
          labelLength = strlen(temporaryLabel) * font->w;
          startingLabel = startDrawing + (canvasWidth - labelLength) / 2;
          gdImageString(im, font, startingLabel, (yy - fontHight) + 90, (unsigned char *)temporaryLabel, darkRed);
          temporaryLabel = NULL;
          break ;
        }
      }
      ptrTrack = (myTrack *) g_hash_table_lookup(myTrack2Name, myTracksInOrder[ii]);
      if(ptrTrack != NULL)
      {
        if(!getDisplayEmptyTracks())
        {
          if(!ptrTrack)
          {
            continue;
          }
          else if(!ptrTrack->groups && !ptrTrack->isHighDensityTrack)
          {
            continue;
          }
        }
        if(!ptrTrack || ptrTrack->vis == VIS_HIDE)
          continue;
        if(getDisplayTrackDescriptions())
        {
          drawTrackTitle(im, yy, ptrTrack);
        }
        mainDraw(im, yy, ptrTrack);

        yy += ptrTrack->height;
        yy += getSpaceBetweenTracks();
        numOfTracksDrawn++;
      }
    }
  }

  // If the user doesn't have any annotation in this range, draw some text instead
  if(!numOfTracksDrawn)
  {
    gdImageString(im, gdFontSmall, labelWidthGlobal + 50, yy, (unsigned char *)NO_ANNOTATIONS_FOUND, black);
    return;
  }

  if(getUseMargins())
    gdImageFilledRectangle(im, 8, IMG_BORDER, labelWidthGlobal, getTotalHeight() + getStartFirstTrack(), leftColor);    /*   End New */
  else
    gdImageFilledRectangle(im, 0, IMG_BORDER, labelWidthGlobal, getTotalHeight() + getStartFirstTrack(), leftColor);    /* End Original */

  yy = getStartFirstTrack();

  int noLabelsDrawn = 0 ;
  for (ii = 0; ii <= numberOfRecords; ii++)
  {
    if(myTracksInOrder[ii] && strlen(myTracksInOrder[ii]) > 1)
    {
      if(noLabelsDrawn == noOfTracksToDraw && truncateTracks == 1)
      {
        break ;
      }
      ptrTrack = (myTrack *) g_hash_table_lookup(myTrack2Name, myTracksInOrder[ii]);
      if(!getDisplayEmptyTracks())
      {
        if(!ptrTrack)
        {
          continue;
        }
        else if(ptrTrack->isHighDensityTrack && ptrTrack->vis != VIS_HIDE)
        {
// avoid deleting the high density tracks
        }
        else if(ptrTrack->groups == NULL)
        {
          continue;
        }
      }

      if(!ptrTrack || ptrTrack->vis == VIS_HIDE)
        continue;
      initialLength = strlen(ptrTrack->trackName);
      if(initialLength >= maxLength)
        finalLength = maxLength;
      else
        finalLength = initialLength;
      temporaryLabel = getstring(finalLength + 2);
      strncpy(temporaryLabel, ptrTrack->trackName, finalLength);
      labelLength = strlen(temporaryLabel);
      startingLabel = labelWidthGlobal - (labelLength * gdFontSmall->w);
      gdImageString(im, gdFontSmall, startingLabel, yy, (unsigned char *)temporaryLabel, black);    //TODO NEWURLTAG
      fprintf(myMapPointerFile, "URL\t%s\t%d\t%d\t%d\t%d\n",
              ptrTrack->trackName, startingLabel, yy,
              startingLabel + (labelLength * gdFontSmall->w), yy + gdFontSmall->h);
      free(temporaryLabel);
      temporaryLabel = NULL;
      printTracksVPs(im, yy, ptrTrack);
      yy += ptrTrack->height;
      yy += getSpaceBetweenTracks();
      noLabelsDrawn += 1 ;
    }
  }

  return;
}

int drawTrackTitle(gdImagePtr im, int initialHeight, myTrack * localTrack)
{
  char reusableText[555] = "";
  long long canvasWidth = canvasWidthGlobal;
  gdFontPtr font = gdFontSmall;
  int startDrawing = labelWidthGlobal;
  int black = gdImageColorResolve(im, 0, 0, 0);
  int gray = gdImageColorResolve(im, 215, 215, 215);
  int fontHight = font->h + 2;
  int fontWidth = font->w;
  int colorToUse = 0;
  int labelLength = 0;
  int startingLabel = 0;
  int maxNumberOfChar = 0;
  char trackName[MAXLENGTHOFTEMPSTRING] = "";
  int lengthOfTrackName = 0;
  int maxLengthOfTrack = 25;
  char staticText[] =
      "----abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789----abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789----abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789----abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789----abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  char *tempTrackDescription = NULL;

  if(localTrack->trackUrlInfo->shortUrlDesc == NULL)
    tempTrackDescription = localTrack->trackUrlInfo->urlDescription;
  else
    tempTrackDescription = localTrack->trackUrlInfo->shortUrlDesc;

  maxNumberOfChar = (canvasWidth / fontWidth) - 6;

  lengthOfTrackName = strlen(localTrack->trackName);
  if(lengthOfTrackName > maxLengthOfTrack)
    lengthOfTrackName = maxLengthOfTrack;

  strncpy(trackName, localTrack->trackName, lengthOfTrackName);

  memset(reusableText, '\0', 555);

  if(tempTrackDescription != NULL)
    strncpy(reusableText, tempTrackDescription, maxNumberOfChar);
  else
    strncpy(reusableText, staticText, maxNumberOfChar);

  if(strlen(staticText) > maxNumberOfChar)
  {
      reusableText[maxNumberOfChar - 2] = '.';
      reusableText[maxNumberOfChar - 1] = '.';
      reusableText[maxNumberOfChar] = '.';
  }

  labelLength = strlen(reusableText) * font->w;
  startingLabel = startDrawing + (canvasWidth - labelLength) / 2;
  colorToUse = gray;

  gdImageString(im, font, startingLabel, initialHeight - fontHight, (unsigned char *)reusableText, black);

  return 1;
}

long long getTickSpan(long long totalLength, int maxNumTicks)
// Figure out whether ticks on ruler should be 1, 5, 10, 50, 100, 500,
        //  * 1000, etc. units apart.
{
  long long roughTickLen = totalLength / maxNumTicks;
  int ii;
  long long tickLen = 1;

  for (ii = 0; ii < 9; ++ii)
  {
      if(roughTickLen < tickLen)
        return tickLen;
      tickLen *= 5;
      if(roughTickLen < tickLen)
        return tickLen;
      tickLen *= 2;
  }
  return 1000000000;
}

size_t commifyInt(char *strBuff, size_t size, long long argnum)
{
  size_t count = 0;
  int ii = 0;
  int triad = 1;
  long long num = argnum;
  long long kludge = 1;

  if(num < 0)
    count += snprintf(strBuff, size, "-");

  num = llabs(argnum);
  while (num >= 1000)
  {
      num /= 1000;
      triad++;
      kludge *= 1000;
  }

  num = llabs(argnum);

  for (ii = 0; triad > 0; ii++, triad--)
  {
      if(ii == 0)
        if(triad == 1)
          count += snprintf(strBuff + count, size - count, "%lld", num);
        else
          count += snprintf(strBuff + count, size - count, "%lld,", (num ? num / kludge : num));
      else if(triad == 1)
        count += snprintf(strBuff + count, size - count, "%03lld", (num ? num / kludge : num));
      else
        count += snprintf(strBuff + count, size - count, "%03lld,", num ? num / kludge : num);

      if(num)
        num %= kludge;

      kludge /= 1000;
  }

  return count;
}

void drawRulerTextGD(gdImagePtr im, int xOff, int yOff, int width,
                     long long startNum, long long range, int bumpX, int bumpY, int color)
{
  long long tickSpan;
  long long tickPos;
  double scale;
  int firstTick;
  int remainder;
  gdFontPtr font = gdFontTiny;
  long long end = startNum + range;
  int xx;
  char tbuf[56] = "";
  int numWid;
  int numberOfCommifiedVersion = 0;
  int goodNumTicks;
  int niceNumTicks = width / 35;
  int Xseparation = 2;
  int lengthTick = 4;
  int lastCoordinate = 0;
  int flagPrinted = 0;

  numberOfCommifiedVersion = commifyInt(tbuf, 52, end);
  numWid = (strlen(tbuf) * font->w) + bumpX;
  goodNumTicks = width / numWid;
  if(goodNumTicks < 1)
    goodNumTicks = 1;
  if(goodNumTicks > niceNumTicks)
    goodNumTicks = niceNumTicks;

  tickSpan = getTickSpan(range, goodNumTicks);

  scale = (double)width / range;

  firstTick = startNum + tickSpan;
  remainder = firstTick % tickSpan;
  firstTick -= remainder;
  for (tickPos = firstTick; tickPos < end; tickPos += tickSpan)
  {
      numberOfCommifiedVersion = commifyInt(tbuf, 52, tickPos);
      numWid = (strlen(tbuf) * font->w) + Xseparation;
      xx = (int)((tickPos - startNum) * scale) + xOff;
      gdImageLine(im, xx, yOff, xx, (yOff + lengthTick), color);

      if(xx - numWid >= xOff)
      {
          if(!lastCoordinate)
          {
              gdImageString(im, font, xx - numWid, yOff, (unsigned char *)tbuf, color);
              flagPrinted = 1;
          }
          else if(xx - numWid > (lastCoordinate + 4))
          {
              gdImageString(im, font, xx - numWid, yOff, (unsigned char *)tbuf, color);
              flagPrinted = 1;
          }
          else
            flagPrinted = 0;
      }
      if(flagPrinted)
        lastCoordinate = xx;
  }
  return;
}

int drawRulerGD(gdImagePtr im, char *legend, int from, int to)
{
  int y = IMG_BORDER + REFSEQ_HEIGHT;
  int relNumOff = from;
  int black = gdImageColorResolve(im, 0, 0, 0);
  drawRulerTextGD(im, labelWidthGlobal, y, canvasWidthGlobal, relNumOff, (to - from + 1), 0, 1, black);
  return 1;
}

gdImagePtr initializeCanvasGD(char *Name)
{
  int black = 0;
  int white = 0;
  int guideColor = 0;
  int x = 0;
  int backgroundColor = 0;
  gdImagePtr im = NULL;
  int height = 0;

  height = getTotalHeight() + getStartFirstTrack();

  if(getPNG())
    im = gdImageCreateTrueColor(totalWidthGlobal + RIGHT_PANEL_SIZE, height);
  else
    im = gdImageCreate(totalWidthGlobal + RIGHT_PANEL_SIZE, height);

  white = gdImageColorAllocate(im, 255, 255, 255);

  gdImageFilledRectangle(im, 0, 0, totalWidthGlobal + RIGHT_PANEL_SIZE, height, white);
  black = gdImageColorAllocate(im, 0, 0, 0);
  backgroundColor = gdImageColorAllocate(im, 211, 207, 230);
  guideColor = gdImageColorAllocate(im, GUIDE_COLOR.r, GUIDE_COLOR.g, GUIDE_COLOR.b);
  for (x = labelWidthGlobal + 1; x <= totalWidthGlobal + 2; x += GUIDE_SEPARATION)
    gdImageRectangle(im, x, IMG_BORDER, 1, height, guideColor);

  gdImageFilledRectangle(im, totalWidthGlobal, 0,
                         totalWidthGlobal + RIGHT_PANEL_SIZE, getTotalHeight() + getStartFirstTrack(), backgroundColor);

  return im;
}

void calculateImageHeight(void)
{
  char **myTracksInOrder = getArrayOrderedTracks() ;
  GHashTable *myTrack2Name = getTrackName2TrackHash() ;
  int numberOfRecords = getMaxOrder() ;
  myTrack *navigationTrack = NULL ;
  int img_height = IMG_BORDER * 2 + REFSEQ_HEIGHT * 2 + getSpaceBetweenTracks() ;
  int prevImgHeight = IMG_BORDER * 2 + REFSEQ_HEIGHT * 2 + getSpaceBetweenTracks() ;
  int ii = 0;

  if(myTracksInOrder == NULL)
    return;

  for (ii = 0; ii <= numberOfRecords; ii++)
  {
    if(myTracksInOrder[ii] && strlen(myTracksInOrder[ii]) > 1)
    {
      navigationTrack = (myTrack *) g_hash_table_lookup(myTrack2Name, myTracksInOrder[ii]);
      if(!getDisplayEmptyTracks())
      {
        if(!navigationTrack)
        {
          continue;
        }
        else if(navigationTrack->vis != VIS_HIDE)
        {
          // avoid deleting the high density tracks
        }
        else if(navigationTrack->groups == NULL)
        {
          continue;
        }
      }
      img_height = img_height + navigationTrack->height + getSpaceBetweenTracks();
      // break if the image height is >= 31K pixels
      // set it to prevImgHeight to be safe
      if(img_height >= 31000)
      {
        truncateTracks = 1 ;
        img_height = prevImgHeight + 100 ;
        break ;
      }
      noOfTracksToDraw += 1 ;
      prevImgHeight = img_height ;
    }
  }
  setTotalHeight(img_height);
}

char *getStyleNameFromStyleId(char *databaseName, int styleId)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection = NULL;
  MYSQL mysql;
  MYSQL_RES *sqlresult = NULL;
  MYSQL_ROW row = NULL;
  char styleCode[MAXLENGTHOFTEMPSTRING] = "";

  resetLocalConnection(databaseName);
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);
  sprintf(sqlbuff, "SELECT name FROM style WHERE styleId = %d", styleId);

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
    fprintf(stderr, "Error querying the style database in function getStyleNameFromStyleId.\n");
    fprintf(stderr, mysql_error(&mysql));
    fflush(stderr);
    return NULL;
  }
  sqlresult = mysql_store_result(connection);
  if(mysql_num_rows(sqlresult))
  {
    if((row = mysql_fetch_row(sqlresult)))
      strcpy(styleCode, row[0]);
  }
  else
    return NULL;
  mysql_free_result(sqlresult);
  closeLocalConnection(2);
  return strdup(styleCode);
}

int getftypeidFromFmethodFsource(char *databaseName, char *fmethod, char *fsource)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  char *end;
  MYSQL *connection = NULL;
  MYSQL mysql;
  MYSQL_RES *sqlresult = NULL;
  MYSQL_ROW row = NULL;
  int ftypeid = 0;

  if(databaseName == NULL || fmethod == NULL || fsource == NULL)
    return 0;

  resetLocalConnection(databaseName);
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);

  end = strmov(sqlbuff, "SELECT ftypeid FROM ftype WHERE fmethod = ");
  *end++ = '\'';
  end += mysql_real_escape_string(connection, end, fmethod, strlen(fmethod));
  *end++ = '\'';
  end = strmov(end, " and fsource = ");
  *end++ = '\'';
  end += mysql_real_escape_string(connection, end, fsource, strlen(fsource));
  *end++ = '\'';

  if(mysql_real_query(connection, sqlbuff, (unsigned int)(end - sqlbuff)))
  {
      fprintf(stderr,
              "Error querying the featuretostyle in database %s in function getftypeidFromFmethodFsource.\n",
              databaseName);
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return 0;
  }
  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult))
  {
      if((row = mysql_fetch_row(sqlresult)))
        ftypeid = atoi(row[0]);
  }

  mysql_free_result(sqlresult);
  closeLocalConnection(2);
  return ftypeid;
}

int getStyleIdFromFtypeidUserid(char *databaseName, int ftypeid, long userid)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection = NULL;
  MYSQL mysql;
  MYSQL_RES *sqlresult = NULL;
  MYSQL_ROW row = NULL;
  int styleid = 0;
  glob_ftypeId = ftypeid;
  resetLocalConnection(databaseName);
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);
  sprintf(sqlbuff, "SELECT styleId FROM featuretostyle WHERE ftypeid = %d " "AND userid = %ld", ftypeid, userid);

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      fprintf(stderr,
              "Error querying the featuretostyle table in database %s in function getStyleIdFromFtypeidUserid.\n",
              databaseName);
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return 0;
  }
  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult))
  {
      if((row = mysql_fetch_row(sqlresult)))
        styleid = atoi(row[0]);
  }
  mysql_free_result(sqlresult);
  closeLocalConnection(2);
  return styleid;
}

char *getNameSemicolonSeparatedWord(char *semicolonSeparatedWord, int getLast)
{
  char *occurance = NULL;
  char *first = NULL;
  char *localWord = NULL;

  if(semicolonSeparatedWord == NULL)
    return NULL;

  localWord = strdup(semicolonSeparatedWord);
  occurance = strstr(localWord, ":");
  if(!occurance)
    return NULL;
  if(!getLast)
  {
      *occurance = '\0';
      first = strdup(localWord);
  }
  else
  {
      occurance++;
      first = strdup(occurance);
  }
  free(localWord);
  localWord = NULL;

  return first;

}

myTrackUrlInfo *fillTrackURL(char *databaseName, int ftypeid)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection = NULL;
  MYSQL mysql;
  MYSQL_RES *sqlresult = NULL;
  MYSQL_ROW row = NULL;
  char *url = NULL;
  char *urlDescription = NULL;
  char *urlLabel = NULL;
  myTrackUrlInfo *localTrackUrlInfo = NULL;

  resetLocalConnection(databaseName);
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);
  sprintf(sqlbuff, "select url, description, label from featureurl where ftypeid = %d", ftypeid);

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      fprintf(stderr,
              "Error querying the featuretostyle table in database %s in function fillTrackURL.\n", databaseName);
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return 0;
  }
  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult))
  {
      if((row = mysql_fetch_row(sqlresult)))
      {
          if(row[0] != NULL && strlen(row[0]) > 1)
          {
              url = strdup(row[0]);
          }
          if(row[1] != NULL && strlen(row[1]) > 1)
          {
              urlDescription = strdup(row[1]);
          }
          if(row[2] != NULL && strlen(row[2]) > 1)
          {
              urlLabel = strdup(row[2]);
          }
      }
  }
  mysql_free_result(sqlresult);

  if(urlDescription)
  {
      localTrackUrlInfo = createTrackUrlInfo();
      localTrackUrlInfo->url = url;
      localTrackUrlInfo->urlDescription = urlDescription;
      localTrackUrlInfo->urlLabel = urlLabel;
  }
  closeLocalConnection(2);
  return localTrackUrlInfo;
}

// Creates default track info for displaying in browser
// for high density tracks, displays the 'number of bases with scores'
// for regular tracks, displays the number of annotations in fdata2
myTrackUrlInfo *createDefaultTrackInfo(char *fmethod, char *fsource, int isHighDens)
{
  int counter = 0;
  int numberGenboreeDatabases = getNumberDatabases();
  char *databaseName = NULL;
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  char sqlBuffForHD[MAXLENGTHOFTEMPSTRING] = "";
  int hdFtypeid;
  MYSQL *connection = NULL;
  MYSQL mysql;
  MYSQL_ROW row = NULL;
  char urlDescription[555] = "";
  long numberOfAnnotations = 0;
  myTrackUrlInfo *localTrackUrlInfo = NULL;
  int ftypeid = 0;
  char tbuf[255] = "";
  while (numberGenboreeDatabases > counter)
  {
    MYSQL_RES *sqlresult = NULL ;
    databaseName = getDatabaseFromId(counter);
    ftypeid = getftypeidFromFmethodFsource(databaseName, fmethod, fsource);
    if(counter == 0){
      hdFtypeid = ftypeid;
    }
    if(!ftypeid)
    {
      counter++;
      continue;
    }
    resetLocalConnection(databaseName);
    connection = returnLocalConnection(2);
    mysql = returnMyMYSQL(2);

    sprintf(sqlbuff, "select numberOfAnnotations from ftypeCount where ftypeId = %d", ftypeid);
    if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
    {
      fprintf(stderr,
              "Error querying the ftypeCount table in database %s in function createDefaultTrackInfo.\n", databaseName);
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return 0;
    }
    sqlresult = mysql_store_result(connection);
    if(mysql_num_rows(sqlresult))
    {
      if((row = mysql_fetch_row(sqlresult)))
      {
        if(row[0] != NULL && strlen(row[0]) > 0)
        {
          numberOfAnnotations += atol(row[0]);
        }
      }
    }
    counter ++ ;
  }
  commifyInt(tbuf, 52, numberOfAnnotations);
  memset(urlDescription, '\0', 555);
  if(isHighDens == 1)
    sprintf(urlDescription, "Track \"%s:%s\" (%s bp with scores)", fmethod, fsource, tbuf);
  else
    if(numberOfAnnotations == 1)
      sprintf(urlDescription, "Track \"%s:%s\" (%s annotation)", fmethod, fsource, tbuf);
    else
      sprintf(urlDescription, "Track \"%s:%s\" (%s annotations)", fmethod, fsource, tbuf);
  localTrackUrlInfo = createTrackUrlInfo();
  localTrackUrlInfo->urlDescription = strdup(urlDescription);
  localTrackUrlInfo->shortUrlDesc = localTrackUrlInfo->urlDescription;
  return localTrackUrlInfo;
}

myTrackUrlInfo *getTrackURLCheckingAllDatabases(char *fmethodFsource)
{
  int counter = 0;
  int numberGenboreeDatabases = getNumberDatabases();
  int ftypeid = 0;
  char *fmethod = NULL;
  char *fsource = NULL;
  myTrackUrlInfo *localTrackUrlInfo = NULL;
  char *databaseName = NULL;
  char *previousDB = NULL;
  char *tempString = NULL;
  int isHighDensTrack = isHighDensityTrack(fmethodFsource);

  if(fmethodFsource == NULL)
    return NULL;

  fmethod = getNameSemicolonSeparatedWord(fmethodFsource, 0);
  fsource = getNameSemicolonSeparatedWord(fmethodFsource, 1);

  if(!fmethod || !fsource)
  {
    fprintf(stderr, "Unable to split fmethod from fsource in function "
            "getTheStyleUsedCheckingAllDatabases! fmethodFsource = %s\n", fmethodFsource);
    fflush(stderr);
    return NULL;
  }
  while (numberGenboreeDatabases > counter)
  {
    previousDB = databaseName;
    databaseName = getDatabaseFromId(counter);
    ftypeid = getftypeidFromFmethodFsource(databaseName, fmethod, fsource);
    if(!ftypeid)
    {
        counter++;
        continue;
    }
    else
      previousDB = databaseName;

    localTrackUrlInfo = fillTrackURL(databaseName, ftypeid);

    if(localTrackUrlInfo == NULL)
    {
        counter++;
        continue;
    }
    else
      break;
  }
  if(localTrackUrlInfo == NULL)
    localTrackUrlInfo = createDefaultTrackInfo(fmethod, fsource, isHighDensTrack);
  else
  {
    tempString = returnFirstLine(localTrackUrlInfo->urlDescription);
    localTrackUrlInfo->shortUrlDesc = stripHtmlTags(tempString);
  }
  free(fmethod);
  fmethod = NULL;
  free(fsource);
  fsource = NULL;
  free(tempString);
  tempString = NULL;

  return localTrackUrlInfo;
}

char *getTheStyleUsedCheckingAllDatabases(char *fmethodFsource)
{
  int counter = 0;
  int numberGenboreeDatabases = getNumberDatabases();
  int ftypeid = 0;
  int theStyleId = 0;
  char *styleCode = NULL;
  char *fmethod = NULL;
  char *fsource = NULL;

  if(fmethodFsource == NULL)
    return NULL;

  fmethod = getNameSemicolonSeparatedWord(fmethodFsource, 0);
  fsource = getNameSemicolonSeparatedWord(fmethodFsource, 1);

  if(!fmethod || !fsource)
  {
      fprintf(stderr, "Unable to split fmethod from fsource in function "
              "getTheStyleUsedCheckingAllDatabases! fmethodFsource = %s\n", fmethodFsource);
      fflush(stderr);
      return NULL;
  }

  while (numberGenboreeDatabases > counter)
  {
      ftypeid = getftypeidFromFmethodFsource(getDatabaseFromId(counter), fmethod, fsource);
      if(!ftypeid)
      {
          counter++;
          continue;
      }

      theStyleId = getStyleIdFromFtypeidUserid(getDatabaseFromId(counter), ftypeid, getMyUserId());
      if(!theStyleId)
        theStyleId = getStyleIdFromFtypeidUserid(getDatabaseFromId(counter), ftypeid, 0);

      if(!theStyleId)
      {
          counter++;
          continue;
      }
      else
        break;
  }

  if(theStyleId)
    styleCode = getStyleNameFromStyleId(getDatabaseFromId(counter), theStyleId);

  free(fmethod);
  fmethod = NULL;
  free(fsource);
  fsource = NULL;

  return styleCode;
}

char *getColorCodeFromColorId(char *databaseName, int colorId)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection = NULL;
  MYSQL mysql;
  MYSQL_RES *sqlresult = NULL;
  MYSQL_ROW row = NULL;
  char colorCode[MAXLENGTHOFTEMPSTRING] = "";

  resetLocalConnection(databaseName);
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);
  sprintf(sqlbuff, "SELECT value FROM color WHERE colorId = %d", colorId);

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      fprintf(stderr, "Error querying the style database in function getColorCodeFromColorId.\n");
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return NULL;
  }
  sqlresult = mysql_store_result(connection);
  if(mysql_num_rows(sqlresult))
  {
      if((row = mysql_fetch_row(sqlresult)))
        strcpy(colorCode, row[0]);
  }
  else
    return NULL;

  mysql_free_result(sqlresult);
  closeLocalConnection(2);
  return strdup(colorCode);
}

int getColorIdFromFtypeidUserid(char *databaseName, int ftypeid, long userid)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection = NULL;
  MYSQL mysql;
  MYSQL_RES *sqlresult = NULL;
  MYSQL_ROW row = NULL;
  int colorid = 0;

  resetLocalConnection(databaseName);
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);
  sprintf(sqlbuff, "SELECT colorId FROM featuretocolor WHERE ftypeid = %d " "AND userid = %ld", ftypeid, userid);

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      fprintf(stderr,
              "Error querying the featuretostyle table in database = %s in function getColorIdFromFtypeidUserid.\n",
              databaseName);
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return 0;
  }
  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult))
  {
      if((row = mysql_fetch_row(sqlresult)))
        colorid = atoi(row[0]);
  }

  mysql_free_result(sqlresult);
  closeLocalConnection(2);
  return colorid;
}

char *getFeatureTypeColorCheckingAllDatabases(char *fmethodFsource)
{
  int counter = 0;
  int numberGenboreeDatabases = getNumberDatabases();
  int ftypeid = 0;
  int theColorId = 0;
  char *colorCode = NULL;
  char *fmethod = NULL;
  char *fsource = NULL;

  if(fmethodFsource == NULL)
    return NULL;

  fmethod = getNameSemicolonSeparatedWord(fmethodFsource, 0);
  fsource = getNameSemicolonSeparatedWord(fmethodFsource, 1);

  if(!fmethod || !fsource)
  {
      fprintf(stderr, "Unable to split fmethod from fsource in function "
              "getTheStyleUsedCheckingAllDatabases! fmethodFsource = %s\n", fmethodFsource);
      fflush(stderr);
      return NULL;
  }

  while (numberGenboreeDatabases > counter)
  {
      ftypeid = getftypeidFromFmethodFsource(getDatabaseFromId(counter), fmethod, fsource);
      if(!ftypeid)
      {
          counter++;
          continue;
      }

      theColorId = getColorIdFromFtypeidUserid(getDatabaseFromId(counter), ftypeid, getMyUserId());
      if(!theColorId)
        theColorId = getColorIdFromFtypeidUserid(getDatabaseFromId(counter), ftypeid, 0);

      if(!theColorId)
      {
          counter++;
          continue;
      }
      else
        break;
  }

  if(theColorId)
    colorCode = getColorCodeFromColorId(getDatabaseFromId(counter), theColorId);

  free(fmethod);
  fmethod = NULL;
  free(fsource);
  fsource = NULL;

  if(colorCode)
    return colorCode;
  else
    return strdup("#000000");
}

char *getMD5LinksCheckingAllDatabases(char *fmethodFsource)
{
  int counter = 0;
  int numberGenboreeDatabases = getNumberDatabases();
  int ftypeid = 0;
  int numberOfMD5 = 0;
  char bigLinkString[BIGBUFFER] = "";
  char *fmethod = getNameSemicolonSeparatedWord(fmethodFsource, 0);
  char *fsource = getNameSemicolonSeparatedWord(fmethodFsource, 1);
  GHashTable *myMD5s = NULL;
  GHashTable *md5ToInfo = getLinkInfoHash();
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection = NULL;
  MYSQL mysql;
  MYSQL_RES *sqlresult = NULL;
  MYSQL_ROW row = NULL;
  GList *listOfMD5s;
  void *theKey = NULL;
  char *currentMD5 = NULL;

  myMD5s = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);

  if(!fmethod || !fsource)
  {
      fprintf(stderr, "Unable to split fmethod from fsource in function "
              "getTheStyleUsedCheckingAllDatabases! fmethodFsource = %s\n", fmethodFsource);
      fflush(stderr);
      return NULL;
  }
  counter = numberGenboreeDatabases - 1;

  while (counter > -1)
  {
      ftypeid = getftypeidFromFmethodFsource(getDatabaseFromId(counter), fmethod, fsource);

      if(!ftypeid)
      {
          counter--;
          continue;
      }

      resetLocalConnection(getDatabaseFromId(counter));
      connection = returnLocalConnection(2);
      mysql = returnMyMYSQL(2);
      sprintf(sqlbuff, "SELECT linkId FROM featuretolink WHERE ftypeid = %d "
              "AND userid in (0, %ld)", ftypeid, getMyUserId());
      if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
      {
          fprintf(stderr,
                  "Error querying the featuretolink table in database = %s in "
                  "function getMD5CheckingAllDatabases.\n", getDatabaseFromId(counter));
          fprintf(stderr, mysql_error(&mysql));
          fflush(stderr);
          return NULL;
      }
      sqlresult = mysql_store_result(connection);

      if(mysql_num_rows(sqlresult) != 0)
      {
          while ((row = mysql_fetch_row(sqlresult)) != NULL)
          {
              g_hash_table_insert(myMD5s, g_strdup(row[0]), g_strdup(row[0]));
          }
          mysql_free_result(sqlresult);
      }
      else
      {
          mysql_free_result(sqlresult);
      }
      counter--;
  }
  resetLocalConnection(getDatabaseFromId(0));
  numberOfMD5 = g_hash_table_size(myMD5s);

  listOfMD5s = g_hash_table_get_keys(myMD5s);

  if(numberOfMD5)
  {
      while (listOfMD5s)
      {
          theKey = (char *)(listOfMD5s->data);
          currentMD5 = (char *)g_hash_table_lookup(md5ToInfo, theKey);
          if(currentMD5)
          {
              if(bigLinkString != NULL && strlen(bigLinkString) > 0)
                strcat(bigLinkString, "\t");
              if((strlen(currentMD5) + strlen(bigLinkString)) >= BIGBUFFER)
                break;
              strcat(bigLinkString, currentMD5);
          }
          listOfMD5s = g_list_next(listOfMD5s);
      }
  }

  if(myMD5s)
    g_hash_table_destroy(myMD5s);
  free(fmethod);
  fmethod = NULL;
  free(fsource);
  fsource = NULL;
  return strdup(bigLinkString);
}

char *getSubstringsFromWord(const char *specialWord, int substring, const char *selectedSeparator)
{
  char *occurance = NULL;
  char *first = NULL;
  char *last = NULL;
  char *localWord = NULL;
  int ii = 0;
  int lengthWord = 0;
  int sizeOfSeparator = 0;

  sizeOfSeparator = strlen(selectedSeparator);
  if(sizeOfSeparator < 1)
    return NULL;
  if(specialWord == NULL)
    return NULL;
  lengthWord = strlen(specialWord);
  if(!lengthWord)
    return NULL;
  if(substring < 0)
    return NULL;

  localWord = strdup(specialWord);
  occurance = localWord;
  ii = -1;
  do
  {
      last = occurance;
      occurance = strstr(occurance, selectedSeparator);
      if(!occurance)
      {
          ii++;
          break;
      }
      *occurance = '\0';
      occurance += sizeOfSeparator;
      ii++;
  }
  while (ii < substring && occurance && strlen(occurance) > 0);

  if(last != NULL && strlen(last) > 0 && ii == substring)
    first = strdup(last);
  else
    first = NULL;

  free(localWord);
  localWord = NULL;

  return first;
}

int countNumberSeparatorsInWord(const char *specialWord, const char *selectedSeparator)
{
  char *occurance = NULL;
  char *localWord = NULL;
  int ii = 0;
  int lengthWord = 0;
  int sizeOfSeparator = 0;

  sizeOfSeparator = strlen(selectedSeparator);
  if(sizeOfSeparator < 1)
    return 0;
  if(specialWord == NULL)
    return 0;

  lengthWord = strlen(specialWord);
  if(!lengthWord)
    return 0;
  localWord = strdup(specialWord);
  occurance = localWord;
  ii = 0;
  do
  {
      occurance = strstr(occurance, selectedSeparator);
      if(occurance)
      {
          occurance += sizeOfSeparator;
          ii++;
      }
  }
  while (occurance && strlen(occurance) > 0);

  free(localWord);
  localWord = NULL;

  return ii;
}

int *generateIntArrayFromStringAndSeparator(const char *list, const char *selectedSeparator)
{
  int *theIntList = NULL;
  int numberSeparators = 0;
  char *temporarySubstring = NULL;
  int intValue = 0;
  int ii = 0;

  numberSeparators = countNumberSeparatorsInWord(list, selectedSeparator);

  if(!numberSeparators)
    return NULL;

  theIntList = (int *)malloc((numberSeparators + 2) * sizeof(int));
  if(theIntList == NULL)
    return NULL;

  for (ii = 0; ii <= numberSeparators; ii++)
    theIntList[ii] = 0;

  for (ii = 0; ii <= numberSeparators; ii++)
  {
      temporarySubstring = getSubstringsFromWord(list, ii, selectedSeparator);
      if(temporarySubstring)
      {
          intValue = 0;
          if(strlen(temporarySubstring) > 0)
          {
              sscanf(temporarySubstring, "%d", &intValue);
              if(intValue < 1)
                intValue = 0;
          }
          theIntList[ii] = intValue;
          free(temporarySubstring);
          temporarySubstring = NULL;
      }
  }

  return theIntList;
}

char **splitLargeStringIntoSubstringsUsingSeparator(const char *list, const char
                                                    *selectedSeparator, int *numberOfResults)
{
  char **theresultingList = NULL;
  int numberSeparators = 0;
  char *temporarySubstring = NULL;
  int intValue = 0;
  int ii = 0;
  int allocatedChar = 0;

  numberSeparators = countNumberSeparatorsInWord(list, selectedSeparator);

  if(!numberSeparators)
    return NULL;

  allocatedChar = numberSeparators + 1;

  *numberOfResults = allocatedChar;
  theresultingList = (char **)malloc(allocatedChar * sizeof(char *));
  if(theresultingList == NULL)
    return NULL;

  for (ii = 0; ii <= numberSeparators; ii++)
    theresultingList[ii] = NULL;

  for (ii = 0; ii <= numberSeparators; ii++)
  {
      temporarySubstring = getSubstringsFromWord(list, ii, selectedSeparator);
      if(temporarySubstring)
      {
          intValue = 0;
          if(strlen(temporarySubstring) > 0)
          {
              theresultingList[ii] = temporarySubstring;
          }
      }
  }

  return theresultingList;
}

int getgidFromGclassNameDatabaseName(char *databaseName, char *gclassName)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection = NULL;
  MYSQL mysql;
  MYSQL_RES *sqlresult = NULL;
  MYSQL_ROW row = NULL;
  int gid = 0;

  if(databaseName == NULL || gclassName == NULL)
    return 0;

  resetLocalConnection(databaseName);
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);

  sprintf(sqlbuff, "SELECT gid FROM gclass where gclass = '%s'", gclassName);

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      fprintf(stderr,
              "Error querying the gclass table in database %s in function getgidFromGclassNameDatabaseName.\n",
              databaseName);
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return 0;
  }
  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult))
  {
      if((row = mysql_fetch_row(sqlresult)))
        gid = atoi(row[0]);
  }

  mysql_free_result(sqlresult);
  closeLocalConnection(2);
  return gid;
}

char *getgidFromGclassName(char *gclassName)
{
  int counter = 0;
  int numberGenboreeDatabases = getNumberDatabases();
  int gid = -1;
  char databaseIdGid[255];

  if(gclassName == NULL)
    return NULL;

  while (numberGenboreeDatabases > counter)
  {
      gid = getgidFromGclassNameDatabaseName(getDatabaseFromId(counter), gclassName);
      if(gid < 1)
      {
          counter++;
          continue;
      }
      else
      {
          memset(databaseIdGid, '\0', 55);
          sprintf(databaseIdGid, "%d:%d", counter, gid);
          return strdup(databaseIdGid);
      }
  }

  return NULL;
}

void insort(register char **array, register int len)
{
  register int ii = 0;
  register int jj = 0;
  register char *temp = NULL;

  for (ii = 1; ii < len; ii++)
  {
      jj = ii;
      temp = array[jj];
      while (jj > 0 && GT(array[jj - 1], temp))
      {
          array[jj] = array[jj - 1];
          jj--;
      }
      array[jj] = temp;
  }
}

void partial_quickersort(register char **array, register int lower, register int upper)
{
  register int ii = 0;
  register int jj = 0;
  register char *temp = NULL;
  register char *pivot = NULL;

  if(upper - lower > CUTOFF)
  {
      SWAP(array[lower], array[(upper + lower) / 2]);
      ii = lower;
      jj = upper + 1;
      pivot = array[lower];
      while (1)
      {
          do
            ii++;
          while (LT(array[ii], pivot));
          do
            jj--;
          while (GT(array[jj], pivot));
          if(jj < ii)
            break;
          SWAP(array[ii], array[jj]);
      }
      SWAP(array[lower], array[jj]);
      partial_quickersort(array, lower, jj - 1);
      partial_quickersort(array, ii, upper);
  }
}

char **sedgesort(char **array, int len)
{
  char sentinel[] =
      "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz";
  register char **myLocalArray = NULL;
  int ii = 0;
  register int myLen = len;

  myLocalArray = (char **)calloc((len + 2), sizeof(char *));
  for (ii = 0; ii < len; ii++)
  {
      myLocalArray[ii] = strdup(array[ii]);
  }

  myLocalArray[len] = strdup(sentinel);
  myLen++;
  partial_quickersort(myLocalArray, 0, myLen - 1);
  insort(myLocalArray, myLen);
  free(myLocalArray[myLen - 1]);
  myLocalArray[myLen - 1] = NULL;

  return myLocalArray;

}
