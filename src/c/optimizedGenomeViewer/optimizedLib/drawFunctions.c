#include "optimizedGB.h"
#include "optimizedFunctions.h"
#include "map_reader.h"

static long long startPositionGlobalForDrawingFunction = 0;
static long long endPositionGlobalForDrawingFunction = 0;
static int canvasWidthGlobalForDrawingFunction = 0;
static double universalScaleGlobalForDrawingFunction = 0.0;
static int labelWidthGlobalForDrawingFunction = 0;
static int totalWidthGlobalForDrawingFunction = 0;
static long lengthOfSegmentGlobalForDrawingFunction = 0;
static double factorToDrawPixelsWithBackground = 0.000;

void setLengthOfSegmentGlobalForDrawingFunction(long long length)
{
  lengthOfSegmentGlobalForDrawingFunction = length;
}

void setTotalWidthGlobalForDrawingFunction(int width)
{
  totalWidthGlobalForDrawingFunction = width;
}

void setLabelWidthGlobalForDrawingFunction(int width)
{
  labelWidthGlobalForDrawingFunction = width;
}

void setStartPositionGlobalForDrawingFunction(long long start)
{
  startPositionGlobalForDrawingFunction = start;
}

void setEndPositionGlobalForDrawingFunction(long long end)
{
  endPositionGlobalForDrawingFunction = end;
}

void setCanvasWidthGlobalForDrawingFunction(int myWidth)
{
  canvasWidthGlobalForDrawingFunction = myWidth;
}

void setUniversalScaleGlobalForDrawingFunction(double myScale)
{
  universalScaleGlobalForDrawingFunction = myScale;
}

int drawRefSeqGD(gdImagePtr im, struct rgbColor colorRefSeq, char *Name)
{
  int i = 0;
  long long startSequence = startPositionGlobalForDrawingFunction;
  long long endSequence = endPositionGlobalForDrawingFunction;
  char *fastafile = NULL;
  char *genomicFragment = NULL;
  int currentChar = 0;
  long long length = lengthOfSegmentGlobalForDrawingFunction + 1;
  long long canvasWidth = canvasWidthGlobalForDrawingFunction;
  float boxSize = (float)canvasWidth / (float)length;
  gdFontPtr tiny = gdFontTiny;
  int startDraw = 0;
  double currentPosition = 0;
  int refSeqColor = gdImageColorResolve(im, colorRefSeq.r, colorRefSeq.g, colorRefSeq.b);
  int black = gdImageColorResolve(im, 0, 0, 0);
  int gray = gdImageColorResolve(im, 215, 215, 215);
  int white = gdImageColorResolve(im, 255, 255, 255);
  int colorToUse = 0;
  int middleFactor = 0;
  int labelLength = 0;
  int startingLabel = 0;
  int backgroundColor = gdImageColorAllocate(im, 211, 207, 230);
  double myDValue = 0.0;

  myDValue = (double)(0.00 * universalScaleGlobalForDrawingFunction);
  startDraw = (int)ceil(myDValue + labelWidthGlobalForDrawingFunction);
  middleFactor = round((boxSize / 2) - (tiny->w / 2));

  if(boxSize < 4)
    colorToUse = refSeqColor;
  else
    colorToUse = gray;
  gdImageFilledRectangle(im, labelWidthGlobalForDrawingFunction, IMG_BORDER, totalWidthGlobalForDrawingFunction,
                         REFSEQ_HEIGHT, colorToUse);

  if(boxSize >= 4)
  {
      fastafile = getGenomicFileName();
      genomicFragment = getSequenceFragment(fastafile, startSequence, endSequence);
      if(genomicFragment)
      {
          for (i = 0; i < length; i++)
          {
              currentPosition = ceil((float)startDraw + (float)(i * boxSize));
              currentChar = (int)genomicFragment[i];
//                      gdImageRectangle(im,(int)currentPosition,IMG_BORDER , (int)(currentPosition +boxSize) ,REFSEQ_HEIGHT , black);
              gdImageChar(im, tiny, (int)currentPosition + middleFactor, IMG_BORDER + 1, currentChar, black);
          }
      }
  }

  labelLength = strlen(getEntrypointName());
  startingLabel = labelWidthGlobalForDrawingFunction - (labelLength * gdFontSmall->w);
  gdImageString(im, gdFontSmall, startingLabel, IMG_BORDER, (unsigned char *)getEntrypointName(), black);
  if(boxSize < 4){
    gdImageString(im, tiny, totalWidthGlobalForDrawingFunction / 2, IMG_BORDER + 1, "DRAG HERE TO SELECT", white);
  }
  // use one or the other for the height          IMG_BORDER  or REFSEQ_HEIGHT

  if(!getUseMargins())
    gdImageFilledRectangle(im, totalWidthGlobalForDrawingFunction, 0,
                           totalWidthGlobalForDrawingFunction + RIGHT_PANEL_SIZE,
                           getTotalHeight() + getStartFirstTrack(), backgroundColor);

  if(boxSize >= 4)
  {
      free(genomicFragment);
      genomicFragment = NULL;
  }

  return 1;
}

int getMyTrackHeight(char *theTrackName)
{
//TODO newScore
  if(!theTrackName || strlen(theTrackName) < 1)
    return 0;
  char *mySpecialTrack = getMySpecialTrack();
  if(strncmp(theTrackName, mySpecialTrack, strlen(mySpecialTrack)) == 0)
    return SPECIALHEIGHT;
  else if(strncmp(theTrackName, "chromosome_draw", 15) == 0)
    return 12;
  else if(strncmp(theTrackName, "sequence_draw", 13) == 0)
    return 12;
  else if(strncmp(theTrackName, "largeScore_draw", 15) == 0)
    return TALLSCORE;
  else if(strncmp(theTrackName, "local_largeScore_draw", 21) == 0)
    return TALLSCORE;
  else if(strncmp(theTrackName, "fadeToWhite_draw", 16) == 0)
    return MIDIUMHEIGHT;
  else if(strncmp(theTrackName, "fadeToGray_draw", 15) == 0)
    return MIDIUMHEIGHT;
  else if(strncmp(theTrackName, "fadeToBlack_draw", 16) == 0)
    return MIDIUMHEIGHT;
  else if(strncmp(theTrackName, "pieChart_draw", 13) == 0)
    return MIDIUMHEIGHT;
  else if(strncmp(theTrackName, "differentialGradient_draw", 25) == 0)
    return MIDIUMHEIGHT;
  else if(strncmp(theTrackName, "bidirectional_draw_large", 24) == 0)
    return TALLSCORE ;
  else if(strncmp(theTrackName, "bidirectional_local_draw_large", 30) == 0)
    return TALLSCORE ;
  else
    return REGULARHEIGHT;
}

int getImageMapHeight(char *theTrackName)
{
//TODO newScore
  if(!theTrackName || strlen(theTrackName) < 1)
    return 0;
  char *mySpecialTrack = getMySpecialTrack();
  if(strncmp(theTrackName, mySpecialTrack, strlen(mySpecialTrack)) == 0)
    return SPECIALHEIGHT;
  else if(strncmp(theTrackName, "chromosome_draw", 15) == 0)
    return 12;
  else if(strncmp(theTrackName, "sequence_draw", 13) == 0)
    return 12;
  else if(strncmp(theTrackName, "fadeToWhite_draw", 16) == 0)
    return MIDIUMHEIGHT;
  else if(strncmp(theTrackName, "fadeToGray_draw", 15) == 0)
    return MIDIUMHEIGHT;
  else if(strncmp(theTrackName, "fadeToBlack_draw", 16) == 0)
    return MIDIUMHEIGHT;
  else if(strncmp(theTrackName, "pieChart_draw", 13) == 0)
    return MIDIUMHEIGHT;
  else if(strncmp(theTrackName, "differentialGradient_draw", 25) == 0)
    return MIDIUMHEIGHT;
  else if(strncmp(theTrackName, "largeScore_draw", 15) == 0)
    return TALLSCORE;
  else if(strncmp(theTrackName, "local_largeScore_draw", 21) == 0)
    return TALLSCORE;
  else if(strncmp(theTrackName, "bidirectional_draw_large", 24) == 0)
    return TALLSCORE ;
  else if(strncmp(theTrackName, "bidirectional_local_draw_large", 30) == 0)
    return TALLSCORE ;
  else
    return REGULARHEIGHT;
}

int calculateStart(long start, int special)
{
  long groupStart = 0;
  int b_start = 0;
  double myDValue = 0.0;
  long long initialValue = 0;
  long long length = lengthOfSegmentGlobalForDrawingFunction + 1;
  long long canvasWidth = canvasWidthGlobalForDrawingFunction;
  float boxSize = (float)canvasWidth / (float)length;
  int boxSizeLimit = 4;

  if(special)
    boxSizeLimit = special;

  if(start < startPositionGlobalForDrawingFunction)
    groupStart = startPositionGlobalForDrawingFunction;
  else
    groupStart = start;

  //Setting up the start and end of the group
  initialValue = groupStart - startPositionGlobalForDrawingFunction;
  if(initialValue < 1)
    initialValue = 0;           // Checking the border
  if(boxSize >= boxSizeLimit)   // Check the scale and allows to make a decision of drawing text
    b_start = ceil(labelWidthGlobalForDrawingFunction + (float)(initialValue * boxSize));
  else
  {
      myDValue = (double)(initialValue * universalScaleGlobalForDrawingFunction);
      b_start = (int)ceil(myDValue + labelWidthGlobalForDrawingFunction);
  }
  if(b_start < labelWidthGlobalForDrawingFunction)
    b_start = labelWidthGlobalForDrawingFunction;
  return b_start;
}

void drawScoreLables(gdImagePtr im, int initialHeight, float maxScore, float minScore, int trackHeight, int isLogarithmic)
{
  char maxScoreStr[255] = "";
  char minScoreStr[255] = "";
  int lengthOfMaxScoreStr = 0;
  int lengthOfMinScoreStr = 0;
  int widthOfMaxBox = 0;
  int widthOfMinBox = 0;
  int heightOfBox = 0;
  int maxLabelStart = 0;
  int minLabelStart = 0;
  gdFontPtr font = gdFontTiny;
  int black = 0;
  int white = 0;
  int blue = 0;
  int minimumHeight = 0;
  char log[] = " LOG ";
  int lengthLog = strlen(log) * font->w;
  black = gdImageColorResolve(im, 0, 0, 0);
  white = gdImageColorResolve(im, 255, 255, 255);
  blue = gdImageColorResolve(im, 0, 0, 180);

  // lables (upper value)
  if(abs(maxScore) < 10 && abs(maxScore) >= 0)
  {
    sprintf(maxScoreStr, "%.4f", maxScore);
  }
  else if(abs(maxScore) < 100 && abs(maxScore) >= 10)
  {
    sprintf(maxScoreStr, "%.3f", maxScore);
  }
  else if(abs(maxScore) < 1000 && abs(maxScore) >= 100)
  {
    sprintf(maxScoreStr, "%.2f", maxScore);
  }
  else if(abs(maxScore) < 10000 && abs(maxScore) >= 1000)
  {
    sprintf(maxScoreStr, "%.1f", maxScore);
  }
  else if(abs(maxScore) >= 10000)
  {
    sprintf(maxScoreStr, "%.5g", maxScore);
  }

  // labels (lower value)
  if(abs(minScore) < 10 && abs(minScore) >= 0)
  {
    sprintf(minScoreStr, "%.4f", minScore);
  }
  else if(abs(minScore) < 100 && abs(minScore) >= 10)
  {
    sprintf(minScoreStr, "%.3f", minScore);
  }
  else if(abs(minScore) < 1000 && abs(minScore) >= 100)
  {
    sprintf(minScoreStr, "%.2f", minScore);
  }
  else if(abs(minScore) < 10000 && abs(minScore) >= 1000)
  {
    sprintf(minScoreStr, "%.1f", minScore);
  }
  else if(abs(minScore) >= 10000)
  {
    sprintf(minScoreStr, "%.5g", minScore);
  }


  if(isLogarithmic)
  {
     strcat(maxScoreStr, log);
  }
  lengthOfMaxScoreStr = strlen(maxScoreStr);
  lengthOfMinScoreStr = strlen(minScoreStr);
  widthOfMaxBox = (lengthOfMaxScoreStr * font->w) + labelWidthGlobalForDrawingFunction + 4;
  widthOfMinBox = (lengthOfMinScoreStr * font->w) + labelWidthGlobalForDrawingFunction + 4;
  heightOfBox = font->h + 4;
  maxLabelStart = labelWidthGlobalForDrawingFunction + 3;
  minLabelStart = maxLabelStart;

  minimumHeight = (heightOfBox * 2) + 2;

  if(trackHeight < minimumHeight)
      return;

  // lables

  // Drawing maximum score
  gdImageFilledRectangle(im, labelWidthGlobalForDrawingFunction + 1, initialHeight, widthOfMaxBox,
                         initialHeight + heightOfBox, white);
  gdImageRectangle(im, labelWidthGlobalForDrawingFunction + 1, initialHeight, widthOfMaxBox,
                   initialHeight + heightOfBox, blue);
  gdImageString(im, font, maxLabelStart, initialHeight + (font->h / 2), (unsigned char *)maxScoreStr, black);
  // Drawing minimum score
  gdImageFilledRectangle(im, labelWidthGlobalForDrawingFunction + 1, (initialHeight + 1 + trackHeight - heightOfBox),
                         widthOfMinBox, initialHeight + trackHeight, white);
  gdImageRectangle(im, labelWidthGlobalForDrawingFunction + 1, (initialHeight + 1 + trackHeight - heightOfBox),
                   widthOfMinBox, initialHeight + trackHeight, blue);
  gdImageString(im, font, minLabelStart, (initialHeight + trackHeight - font->h), (unsigned char *)minScoreStr, black);
}

int calculateEnd(long rawStart, long start, long end, int special)
{
  long groupEnd = 0;
  int b_end = 0;
  int b_width = 0;
  double myDValue = 0.0;
  long long initialValue = 0;
  long long length = lengthOfSegmentGlobalForDrawingFunction + 1;
  long long canvasWidth = canvasWidthGlobalForDrawingFunction;
  float boxSize = (float)canvasWidth / (float)length;
  int oneBaseGroup = 0;
  int specialFactor = 0;
  int boxSizeLimit = 4;

  if(special)
    boxSizeLimit = special;

  if(end > endPositionGlobalForDrawingFunction)
    groupEnd = endPositionGlobalForDrawingFunction;
  else
    groupEnd = end;

  initialValue = groupEnd - startPositionGlobalForDrawingFunction;

  /*
   * if(boxSize >= 4) // Check the scale and allows to make a decision of drawing text
   * b_end = ceil(labelWidthGlobalForDrawingFunction + (float)(initialValue * boxSize));
   * else
   * {
   */
  myDValue = (double)(initialValue * universalScaleGlobalForDrawingFunction);
  b_end = round(myDValue) + labelWidthGlobalForDrawingFunction;
//      }

  b_width = b_end - start;
  if((groupEnd - rawStart) <= 1)
    oneBaseGroup = 1;           // the start and stop do not work very well for snps need this variable

  if(oneBaseGroup)              // dealing with snps 1 base annotations
  {
      specialFactor = 1;
      if(boxSize >= boxSizeLimit)
        specialFactor = (int)ceil(boxSize);
      b_width = specialFactor;
      b_end = start + b_width;
  }

  if(b_end > totalWidthGlobalForDrawingFunction)
    b_end = totalWidthGlobalForDrawingFunction; // this checking may not be necessary but do not do any harm

  if(b_end - start < 0.5)
    b_end = start + 0.5;

  return b_end;
}

int returnEndOfText(int visibility, char *name, int b_end, int currentLevel)
{
  int textStart = 0;
  int normalLevel = 0;
  int spaceBeforeBorder = 0;
  gdFontPtr font = gdFontTiny;  //INCLUDE TEXT
  char reusableText[55] = "";   //INCLUDE TEXT
  int sizeToCopy = 15;          //INCLUDE TEXT
  int sizeOfName = 0;
  int deltaToDrawEnd = 0;
  int endOfText = 0;
  int drawText = 0;
  int lengthOfPanel = totalWidthGlobalForDrawingFunction;

  if(visibility == VIS_FULLNAME || visibility == VIS_FULLTEXT)
  {
      memset(reusableText, '\0', 55);
      strncpy(reusableText, name, sizeToCopy);

      if(strlen(name) > sizeToCopy)
      {
          reusableText[sizeToCopy - 2] = '.';
          reusableText[sizeToCopy - 1] = '.';
          reusableText[sizeToCopy] = '.';
      }

      if(getUseMargins())
        lengthOfPanel += RIGHT_PANEL_SIZE;

      sizeOfName = strlen(name);
      if(sizeOfName > 15)
        sizeOfName = 15;
      endOfText = (sizeOfName * font->w) + 5;
      spaceBeforeBorder = lengthOfPanel - (b_end + endOfText);

      deltaToDrawEnd = (spaceBeforeBorder > MAXSPACEBEFOREBORDER);
      normalLevel = (currentLevel < MAXNUMBERLINESINTRACK);
      drawText = (normalLevel && deltaToDrawEnd);

      if(deltaToDrawEnd)
      {
          textStart = b_end + SPACEBEFORETEXT;
          if(drawText)
            return (textStart + endOfText);
      }

      if(!deltaToDrawEnd && normalLevel && getUseMargins())
      {
          textStart = totalWidthGlobalForDrawingFunction + SPACEBEFORETEXT;
          return (textStart + endOfText);
      }

  }
  return b_end;

}

void printNameOfAnnotation(gdImagePtr im, int visibility, char *name, int b_end, int hight, int color, int currentLevel)
{
  int textStart = 0;
  int normalLevel = 0;
  int spaceBeforeBorder = 0;
  gdFontPtr font = gdFontTiny;  //INCLUDE TEXT
  char reusableText[55] = "";   //INCLUDE TEXT
  int sizeToCopy = 15;          //INCLUDE TEXT
  int sizeOfName = 0;
  int deltaToDrawEnd = 0;
  int endOfText = 0;
  int drawText = 0;
  int lengthOfPanel = totalWidthGlobalForDrawingFunction;

  if(visibility == VIS_FULLNAME || visibility == VIS_FULLTEXT)
  {
      memset(reusableText, '\0', 55);
      strncpy(reusableText, name, sizeToCopy);

      if(strlen(name) > sizeToCopy)
      {
          reusableText[sizeToCopy - 2] = '.';
          reusableText[sizeToCopy - 1] = '.';
          reusableText[sizeToCopy] = '.';
      }

      if(getUseMargins())
        lengthOfPanel += RIGHT_PANEL_SIZE;

      sizeOfName = strlen(name);
      if(sizeOfName > 15)
        sizeOfName = 15;
      endOfText = (sizeOfName * font->w) + 5;
      spaceBeforeBorder = lengthOfPanel - (b_end + endOfText);

      deltaToDrawEnd = (spaceBeforeBorder > MAXSPACEBEFOREBORDER);
      normalLevel = (currentLevel < MAXNUMBERLINESINTRACK);
      drawText = (normalLevel && deltaToDrawEnd);

      if(deltaToDrawEnd)
      {
          textStart = b_end + SPACEBEFORETEXT;
          if(drawText)
          {
              gdImageString(im, font, textStart, hight - 1, (unsigned char *)reusableText, color);
              return;
          }
      }

      if(!deltaToDrawEnd && normalLevel && getUseMargins())
      {
          textStart = totalWidthGlobalForDrawingFunction + SPACEBEFORETEXT;
          gdImageString(im, font, textStart, hight - 1, (unsigned char *)reusableText, color);
      }

  }

  return;
}

/////   DRAWING FUNCTIONS HERE

void Nnegative_drawGD(gdImagePtr im, myGroup * theGroup, int visibility, int *multicolor, int initialHeight,
                      int theHeight, int allocatedColor)
{
  int csel = 0;
  int y1 = 0;
  int y2 = 0;
  int start = 0;
  int end = 0;
  int width = 0;
  int white = 0;
  int mid = theHeight / 2;
  float thickness = 0.5;
  float thick = 0;
  int x = 0;
  int guideColor = 0;
  int annotationSet = 0;
  int black = 0;                //INCLUDE TEXT
  gdFontPtr font = gdFontTiny;  //INCLUDE TEXT
  int sizeToCopy = 15;          //INCLUDE TEXT
  myAnnotations *currentAnnotation = NULL;
  myGroup *currentGroup = theGroup;
  int annotationColor = 0;

  thick = (theHeight * thickness) / 2;
  black = gdImageColorResolve(im, 0, 0, 0);     //INCLUDE TEXT

  guideColor = gdImageColorResolve(im, 200, 200, 255);
  white = gdImageColorResolve(im, 255, 255, 255);

  gdImageLine(im, labelWidthGlobalForDrawingFunction, (initialHeight + 2), totalWidthGlobalForDrawingFunction,
              (initialHeight + 2), allocatedColor);

  while (currentGroup)
  {
    currentAnnotation = currentGroup->annotations;
    while (currentAnnotation)
    {
      if(csel > 3)
        csel = 0;

      if(currentAnnotation->displayColor > -1)
        annotationColor =
        gdImageColorResolve(im, getRed(currentAnnotation->displayColor),
                                getGreen(currentAnnotation->displayColor),
                                getBlue(currentAnnotation->displayColor));
      else
        annotationColor = allocatedColor;

      if(currentAnnotation->level == -1)
      {
        currentAnnotation = currentAnnotation->next;
        continue;
      }

      if(visibility == VIS_FULL || visibility == VIS_FULLNAME || visibility == VIS_FULLTEXT)
      {
        y1 = initialHeight + 4 + mid + (currentAnnotation->level * theHeight) - thick;
      }
      else if(visibility == VIS_DENSE || visibility == VIS_DENSEMC)
      {
        y1 = initialHeight + 4 + mid - thick;
      }
      else
      {
        y1 = 0 + 4;
      }

      y2 = y1 + (2 * thick);
      annotationSet = 0;

      start = calculateStart(currentAnnotation->start, 0);
      end = calculateEnd(currentAnnotation->start, start, currentAnnotation->end, 0);
      width = end - start;
      if(width < 1)
      {
          width = 1;
      }
      if(width > 1)
      {
        gdImageLine(im, start, (initialHeight + 2), end, (initialHeight + 2), white);
        for (x = labelWidthGlobalForDrawingFunction + 1; x <= totalWidthGlobalForDrawingFunction + 2;
             x += GUIDE_SEPARATION)
        {
            if(x >= start && x <= end)
              gdImageLine(im, x, (initialHeight + 2), x, (initialHeight + 2), guideColor);
        }
      }
      // For 'expand with comments', check if comments are present.
      if(visibility == VIS_FULLTEXT && currentAnnotation->level < MAXNUMBERLINESINTRACK)
      {
        int fidText = printTextSizeFromFid(im, font, currentAnnotation->uploadId, currentAnnotation->id, 't', MAXTEXTSIZE,
                             sizeToCopy, end + SPACEBEFORETEXT, y1 - 1, black);
        // if not, just draw the name
        if(fidText == 0){
          printNameOfAnnotation(im, visibility, currentGroup->groupName, end, y1, black, currentAnnotation->level);
        }
      }
      // just draw the names
      else{
        printNameOfAnnotation(im, visibility, currentGroup->groupName, end, y1, black, currentAnnotation->level);
      }
      if(visibility == VIS_FULL || visibility == VIS_DENSE || visibility == VIS_FULLNAME
         || visibility == VIS_FULLTEXT)
      {
        gdImageFilledRectangle(im, start, y1, start + width, y2, annotationColor);
      }
      else if(visibility == VIS_DENSEMC)
      {
        gdImageFilledRectangle(im, start, y1, start + width, y2, multicolor[csel]);
      }

      currentAnnotation = currentAnnotation->next;
      csel++;
    }
    currentGroup = currentGroup->next;
  }
  return;
}

void NgroupNeg_drawGD(gdImagePtr im, myGroup * theGroup, int visibility, int *multicolor, int initialHeight,
                      int theHeight, int allocatedColor)
{
  int csel = 0;
  int y1 = 0;
  int y2 = 0;
  long long groupStart = 0;
  long long groupEnd = 0;
  long long groupBegin = 0;
  long long groupFinish = 0;
  long long minGroupStart = endPositionGlobalForDrawingFunction;
  long long maxGroupEnd = 0;
  int b_start = 0;
  int b_end = 0;
  int b_width = 0;
  int start = 0;
  int end = 0;
  int width = 0;
  int red = 0;
  int blue = 0;
  int black = 0;
  int white = 0;
  int gray = 0;
  int mid = theHeight / 2;
  float thickness = 0.5;
  float thick = 0;
  double myDValue = 0.0;
  long long initialValue = 0;
  int b_groupStart = 0;
  int b_groupEnd = 0;
  int x = 0;
  int guideColor = 0;
  int groupSet = 0;
  myAnnotations *currentAnnotation = NULL;
  myGroup *currentGroup = theGroup;
  myGroup *copyGroup = theGroup;
  int annotationColor = 0;

  thick = (theHeight * thickness) / 2;

  black = gdImageColorResolve(im, 0, 0, 0);
  white = gdImageColorResolve(im, 255, 255, 255);
  red = gdImageColorResolve(im, 255, 0, 0);
  blue = gdImageColorResolve(im, 0, 0, 255);
  gray = gdImageColorResolve(im, 150, 150, 150);
  guideColor = gdImageColorResolve(im, 200, 200, 255);

  while (copyGroup)
  {
    groupBegin = copyGroup->groupStart;
    groupFinish = copyGroup->groupEnd;

    if(groupFinish < startPositionGlobalForDrawingFunction || groupBegin > endPositionGlobalForDrawingFunction)
    {
      continue;
    }

    if(groupBegin < startPositionGlobalForDrawingFunction)
    {
      groupBegin = startPositionGlobalForDrawingFunction;
    }
    if(groupFinish > endPositionGlobalForDrawingFunction)
    {
      groupFinish = endPositionGlobalForDrawingFunction;
    }

    if(minGroupStart > groupBegin)
    {
      minGroupStart = groupBegin;
    }
    if(maxGroupEnd < groupFinish)
    {
      maxGroupEnd = groupFinish;
    }

    copyGroup = copyGroup->next;
  }

  if(minGroupStart >= endPositionGlobalForDrawingFunction)
  {
    minGroupStart = startPositionGlobalForDrawingFunction;
  }
  if(maxGroupEnd <= startPositionGlobalForDrawingFunction)
  {
    maxGroupEnd = endPositionGlobalForDrawingFunction;
  }

  initialValue = minGroupStart - startPositionGlobalForDrawingFunction;
  myDValue = (double)(initialValue * universalScaleGlobalForDrawingFunction);
  b_groupStart = round(myDValue) + labelWidthGlobalForDrawingFunction;
  if(b_groupStart < labelWidthGlobalForDrawingFunction)
  {
    b_groupStart = labelWidthGlobalForDrawingFunction;
  }

  initialValue = maxGroupEnd - startPositionGlobalForDrawingFunction;
  myDValue = (double)(initialValue * universalScaleGlobalForDrawingFunction);
  b_groupEnd = round(myDValue) + labelWidthGlobalForDrawingFunction;
  if(b_groupEnd > totalWidthGlobalForDrawingFunction)
  {
    b_groupEnd = totalWidthGlobalForDrawingFunction;
  }

  gdImageLine(im, labelWidthGlobalForDrawingFunction, (initialHeight + 2), b_groupStart, (initialHeight + 2), gray);
  gdImageLine(im, b_groupEnd, (initialHeight + 2), totalWidthGlobalForDrawingFunction, (initialHeight + 2), gray);
  gdImageLine(im, b_groupStart, (initialHeight + 2), b_groupEnd, (initialHeight + 2), allocatedColor);

  while (currentGroup)
  {
      groupSet = 0;
      if(csel > 3)
      {
          csel = 0;
      }

      if(currentGroup->level == -1)
      {
          currentGroup = currentGroup->next;
          continue;
      }

      if(visibility == VIS_FULL || visibility == VIS_FULLNAME || visibility == VIS_FULLTEXT)
      {
          y1 = initialHeight + 4 + mid + (currentGroup->level * theHeight) - thick;
      }
      else if(visibility == VIS_DENSE || visibility == VIS_DENSEMC)
      {
          y1 = initialHeight + 4 + mid - thick;
      }
      else
      {
          y1 = 0 + 4;
      }

      y2 = y1 + (2 * thick);

      groupStart = currentGroup->groupStart;
      groupEnd = currentGroup->groupEnd;
      if(groupEnd < startPositionGlobalForDrawingFunction || groupStart > endPositionGlobalForDrawingFunction)
      {
          continue;
      }
      b_start = calculateStart(groupStart, 0);
      b_end = calculateEnd(groupStart, b_start, groupEnd, 0);
      b_width = b_end - b_start;
      printNameOfAnnotation(im, visibility, currentGroup->groupName, b_end, y1, black, currentGroup->level);

      if(b_width > 1)
      {
          gdImageLine(im, b_start, (initialHeight + 2), b_end, (initialHeight + 2), white);
          for (x = labelWidthGlobalForDrawingFunction + 1; x <= totalWidthGlobalForDrawingFunction + 2;
               x += GUIDE_SEPARATION)
          {
              if(x >= b_start && x <= b_end)
              {
                  gdImageLine(im, x, (initialHeight + 2), x, (initialHeight + 2), guideColor);
              }
          }
      }

      if(visibility == VIS_FULL || visibility == VIS_DENSE || visibility == VIS_FULLNAME || visibility == VIS_FULLTEXT)
      {
          gdImageLine(im, b_start, (y1 + y2) / 2, b_end, (y1 + y2) / 2, allocatedColor);
      }
      else if(visibility == VIS_DENSEMC)
      {
          gdImageLine(im, b_start, (y1 + y2) / 2, b_end, (y1 + y2) / 2, multicolor[csel]);
      }

// START Draw groupContext lines
      drawGroupContextLines(im, currentGroup, visibility, b_start, y1, b_end, y2, allocatedColor);
// END Draw groupContext lines

      currentAnnotation = currentGroup->annotations;
      while (currentAnnotation)
      {
          if(currentAnnotation->displayColor > -1)
          {
              annotationColor =
                  gdImageColorResolve(im, getRed(currentAnnotation->displayColor),
                                      getGreen(currentAnnotation->displayColor),
                                      getBlue(currentAnnotation->displayColor));
          }
          else
          {
              annotationColor = allocatedColor;
          }

          start = calculateStart(currentAnnotation->start, 0);
          end = calculateEnd(currentAnnotation->start, start, currentAnnotation->end, 0);
          width = end - start;
          if(width < 1)
          {
              width = 1;
          }

          if(visibility == VIS_FULL || visibility == VIS_DENSE || visibility == VIS_FULLNAME
             || visibility == VIS_FULLTEXT)
          {
              gdImageFilledRectangle(im, start, y1, start + width, y2, annotationColor);
          }
          else if(visibility == VIS_DENSEMC)
          {
              gdImageFilledRectangle(im, start, y1, start + width, y2, multicolor[csel]);
          }

          currentAnnotation = currentAnnotation->next;
      }
      csel++;
      currentGroup = currentGroup->next;
  }
  return;
}

void Nsimple_drawGD(gdImagePtr im, myGroup * theGroup, int visibility, int *multicolor, int initialHeight,
                    int theHeight, int allocatedColor)
{
  int csel = 0;
  int y1 = 0;
  int y2 = 0;
  int start = 0;
  int end = 0;
  int mid = theHeight / 2;
  int width = 0;
  float thickness = 0.8;
  float thick = 0;
  int black = 0;                //INCLUDE TEXT
  gdFontPtr font = gdFontTiny;  //INCLUDE TEXT
  int sizeToCopy = 15;          //INCLUDE TEXT
  myAnnotations *currentAnnotation = NULL;
  myGroup *currentGroup = theGroup;
  int annotationColor = 0;

  thick = (theHeight * thickness) / 2;
  black = gdImageColorResolve(im, 0, 0, 0);     //INCLUDE TEXT

  while (currentGroup)
  {
      currentAnnotation = currentGroup->annotations;
      while (currentAnnotation)
      {
          if(csel > 3)
          {
              csel = 0;
          }

          if(currentAnnotation->displayColor > -1)
          {
              annotationColor =
                  gdImageColorResolve(im, getRed(currentAnnotation->displayColor),
                                      getGreen(currentAnnotation->displayColor),
                                      getBlue(currentAnnotation->displayColor));
          }
          else
          {
              annotationColor = allocatedColor;
          }

          if(currentAnnotation->level == -1)
          {
              currentAnnotation = currentAnnotation->next;
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

          start = calculateStart(currentAnnotation->start, 0);
          end = calculateEnd(currentAnnotation->start, start, currentAnnotation->end, 0);
          width = end - start;
          if(width < 1)
          {
              width = 1;
          }
          ;
          // For 'expand with comments' check ti see if there are comments present for
          // the annotations to be drawn
          if(visibility == VIS_FULLTEXT && currentAnnotation->level < MAXNUMBERLINESINTRACK)
          {
              int fidText = printTextSizeFromFid(im, font, currentAnnotation->uploadId, currentAnnotation->id, 't', MAXTEXTSIZE,
                                   sizeToCopy, end + SPACEBEFORETEXT, y1 - 1, black);

              // draw only name if comments were not present
              if(fidText == 0){
                printNameOfAnnotation(im, visibility, currentGroup->groupName, end, y1, black, currentAnnotation->level);
              }
          }
          // For other visibility options, just draw the name
          else if(visibility != VIS_FULLTEXT){
            printNameOfAnnotation(im, visibility, currentGroup->groupName, end, y1, black, currentAnnotation->level);
          }
//TODO END INCLUDE TEXT

          if(visibility == VIS_FULL || visibility == VIS_DENSE || visibility == VIS_FULLNAME
             || visibility == VIS_FULLTEXT)
          {
              gdImageFilledRectangle(im, start, y1, start + width, y2, annotationColor);
          }
          else if(visibility == VIS_DENSEMC)
          {
              gdImageFilledRectangle(im, start, y1, start + width, y2, multicolor[csel]);
          }

          currentAnnotation = currentAnnotation->next;
          csel++;
      }
      currentGroup = currentGroup->next;
  }
  return;
}

void sequence_drawGD(gdImagePtr im, myGroup * theGroup, int visibility, int *multicolor, int initialHeight,
                     int theHeight, int allocatedColor)
{
  int currentChar = 0;
  int drawSequence = 0;
  int gray = gdImageColorResolve(im, 215, 215, 215);
  gdFontPtr tiny = gdFontTiny;
  int middleFactor = 0;
  double currentPosition = 0;
  int i = 0;
  int csel = 0;
  int y1 = 0;
  int y2 = 0;
  long groupStart = 0;
  long groupEnd = 0;
  int b_start = 0;
  int b_end = 0;
  int b_width = 0;
  int start = 0;
  int end = 0;
  int width = 0;
  int mid = theHeight / 2;
  float thickness = 0.5;
  float thick = 0;
  int black = 0;                //INCLUDE TEXT
  myAnnotations *currentAnnotation = NULL;
  myGroup *currentGroup = theGroup;
  int annotationColor = 0;
  char *sequenceString = NULL;
  int sizeOfAnnotation = -1;
  int lengthOfSequence = -1;
  int trimBegining = 0;
  int trimEnd = 0;
  int a = 0;
  long long length = lengthOfSegmentGlobalForDrawingFunction + 1;
  long long canvasWidth = canvasWidthGlobalForDrawingFunction;
  float boxSize = (float)canvasWidth / (float)length;
  int textColor = 0;

  thick = (theHeight * thickness) / 2;
  black = gdImageColorResolve(im, 0, 0, 0);     //INCLUDE TEXT

  middleFactor = round((boxSize / 2) - (tiny->w / 2));

  while (currentGroup)
  {
      if(csel > 3)
      {
          csel = 0;
      }

      if(currentGroup->level == -1)
      {
          currentGroup = currentGroup->next;
          continue;
      }

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
      if(groupEnd < startPositionGlobalForDrawingFunction || groupStart > endPositionGlobalForDrawingFunction)
      {
          continue;
      }
      b_start = calculateStart(groupStart, 0);
      b_end = calculateEnd(groupStart, b_start, groupEnd, 0);
      b_width = b_end - b_start;
      printNameOfAnnotation(im, visibility, currentGroup->groupName, b_end, y1, black, currentGroup->level);

      if(visibility == VIS_FULL || visibility == VIS_DENSE || visibility == VIS_FULLNAME || visibility == VIS_FULLTEXT)
      {
          gdImageLine(im, b_start, (y1 + y2) / 2, b_end, (y1 + y2) / 2, allocatedColor);
      }
      else if(visibility == VIS_DENSEMC)
      {
          gdImageLine(im, b_start, (y1 + y2) / 2, b_end, (y1 + y2) / 2, multicolor[csel]);
      }

// START Draw groupContext lines
      drawGroupContextLines(im, currentGroup, visibility, b_start, y1, b_end, y2, allocatedColor);
// END Draw groupContext lines

      currentAnnotation = currentGroup->annotations;    // start drawing the annotation
      while (currentAnnotation)
      {
          trimBegining = 0;     // size of text to be ignored when the annotation is not in the browser window
          trimEnd = 0;          // size of be ignored at the end
          // calculate the text to be ignored from the start
          if(currentAnnotation->start < startPositionGlobalForDrawingFunction)
          {
              trimBegining = startPositionGlobalForDrawingFunction - currentAnnotation->start;
          }
          // calculate the text to be ingored from the end
          if(currentAnnotation->end > endPositionGlobalForDrawingFunction)
          {
              trimEnd = currentAnnotation->end - endPositionGlobalForDrawingFunction;
          }

          sizeOfAnnotation = (currentAnnotation->end + 1) - currentAnnotation->start;
          start = calculateStart(currentAnnotation->start, 0);
          end = calculateEnd(currentAnnotation->start, start, currentAnnotation->end, 0);
          width = end - start;
          if(width < 1)
          {
              width = 1;
          }

          // setting the color of the annotation from the annotationColor value pair
          if(currentAnnotation->displayColor > -1)
          {
              annotationColor =
                  gdImageColorResolve(im, getRed(currentAnnotation->displayColor),
                                      getGreen(currentAnnotation->displayColor),
                                      getBlue(currentAnnotation->displayColor));
              textColor = annotationColor;      // experimental setting color of text in the sequence display
          }
          else                  // setting default colors
          {
              annotationColor = allocatedColor;
              textColor = black;
          }

          if(visibility == VIS_FULLNAME || visibility == VIS_FULLTEXT || visibility == VIS_FULL)        // allowing sequence to be printed
          {
              if(boxSize >= 4)  // only display sequence if the size of the window is small enough to draw sequences
              {
                  // retrieving the sequence from the sequence field
                  sequenceString =
                      getTextFromFid(currentAnnotation->uploadId, currentAnnotation->id, currentAnnotation->ftypeid,
                                     's', MAXLENGTHOFTEMPSTRING);
                  if(sequenceString)
                  {
                      lengthOfSequence = strlen(sequenceString);
                  }

                  if(sizeOfAnnotation == lengthOfSequence)
                  {
                      drawSequence = 1;
                      annotationColor = gray;
                  }

              }
          }

          if(visibility == VIS_FULL || visibility == VIS_DENSE || visibility == VIS_FULLNAME
             || visibility == VIS_FULLTEXT)
          {
              gdImageFilledRectangle(im, start, y1, start + width, y2, annotationColor);
          }
          else if(visibility == VIS_DENSEMC)
          {
              gdImageFilledRectangle(im, start, y1, start + width, y2, multicolor[csel]);
          }

          // drawing the sequences
          if(drawSequence)
          {
              for (a = 0; a < trimBegining; a++) ;      // ignoring text not in browser view
              sizeOfAnnotation = sizeOfAnnotation - trimEnd;    // ignore text behond end or browser view

              for (i = 0; i < sizeOfAnnotation; i++, a++)
              {
                  currentPosition = ceil((float)start + (float)(i * boxSize));
                  currentChar = (int)sequenceString[a];
                  if(currentPosition < end)
                  {
                      gdImageChar(im, tiny, (int)currentPosition + middleFactor, y1, currentChar, textColor);   //drawing text
//                        gdImageRectangle(im,(int)currentPosition, y1 , (int)(currentPosition +boxSize) ,y2 , black); // for debugging only
                  }
              }
              free(sequenceString);
              sequenceString = NULL;
          }

          currentAnnotation = currentAnnotation->next;
      }
      csel++;
      currentGroup = currentGroup->next;
  }
  return;

}

void Ngene_drawGD(gdImagePtr im, myGroup * theGroup, int visibility, int *multicolor, int initialHeight, int theHeight,
                  int allocatedColor)
{
  int csel = 0;
  int y1 = 0;
  int y2 = 0;
  long groupStart = 0;
  long groupEnd = 0;
  int b_start = 0;
  int b_end = 0;
  int b_width = 0;
  int start = 0;
  int end = 0;
  int width = 0;
  int mid = theHeight / 2;
  float thickness = 0.5;
  float thick = 0;
  int black = 0;                //INCLUDE TEXT
  myAnnotations *currentAnnotation = NULL;
  myGroup *currentGroup = theGroup;
  int annotationColor = 0;

  thick = (theHeight * thickness) / 2;
  black = gdImageColorResolve(im, 0, 0, 0);     //INCLUDE TEXT

  while (currentGroup)
  {
      if(csel > 3)
      {
          csel = 0;
      }

      if(currentGroup->level == -1)
      {
          currentGroup = currentGroup->next;
          continue;
      }

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
      if(groupEnd < startPositionGlobalForDrawingFunction || groupStart > endPositionGlobalForDrawingFunction)
      {
          continue;
      }
      b_start = calculateStart(groupStart, 0);
      b_end = calculateEnd(groupStart, b_start, groupEnd, 0);
      b_width = b_end - b_start;
      printNameOfAnnotation(im, visibility, currentGroup->groupName, b_end, y1, black, currentGroup->level);

      if(visibility == VIS_FULL || visibility == VIS_DENSE || visibility == VIS_FULLNAME || visibility == VIS_FULLTEXT)
      {
          gdImageLine(im, b_start, (y1 + y2) / 2, b_end, (y1 + y2) / 2, allocatedColor);
      }
      else if(visibility == VIS_DENSEMC)
      {
          gdImageLine(im, b_start, (y1 + y2) / 2, b_end, (y1 + y2) / 2, multicolor[csel]);
      }
// START Draw groupContext lines
      drawGroupContextLines(im, currentGroup, visibility, b_start, y1, b_end, y2, allocatedColor);
// END Draw groupContext lines

      currentAnnotation = currentGroup->annotations;
      while (currentAnnotation)
      {
          if(currentAnnotation->displayColor > -1)
          {
              annotationColor =
                  gdImageColorResolve(im, getRed(currentAnnotation->displayColor),
                                      getGreen(currentAnnotation->displayColor),
                                      getBlue(currentAnnotation->displayColor));
          }
          else
          {
              annotationColor = allocatedColor;
          }

          start = calculateStart(currentAnnotation->start, 0);
          end = calculateEnd(currentAnnotation->start, start, currentAnnotation->end, 0);
          width = end - start;
          if(width < 1)
          {
              width = 1;
          }
          if(visibility == VIS_FULL || visibility == VIS_DENSE || visibility == VIS_FULLNAME
             || visibility == VIS_FULLTEXT)
          {
              gdImageFilledRectangle(im, start, y1, start + width, y2, annotationColor);
          }
          else if(visibility == VIS_DENSEMC)
          {
              gdImageFilledRectangle(im, start, y1, start + width, y2, multicolor[csel]);
          }

          currentAnnotation = currentAnnotation->next;
      }
      csel++;
      currentGroup = currentGroup->next;
  }
  return;
}

void Nbes_drawGD(gdImagePtr im, myGroup * theGroup, int visibility, int *multicolor, int initialHeight, int theHeight,
                 int allocatedColor)
{
  int csel = 0;
  int y1 = 0;
  int y2 = 0;
  long groupStart = 0;
  long groupEnd = 0;
  int b_start = 0;
  int b_end = 0;
  int b_width = 0;
  int start = 0;
  int end = 0;
  int mid = theHeight / 2;
  int width = 0;
  float thickness = 0.8;
  float thick = 0;
  int compactWidth = returnCompactWidth();
  int black = 0;
  int orangeBox = 0;
  int greenBox = 0;
  int white = 0;
  int blockStart = 0;
  int blockEnd = 0;

  myAnnotations *currentAnnotation = NULL;
  myGroup *currentGroup = theGroup;

  black = gdImageColorResolve(im, 0, 0, 0);
  white = gdImageColorResolve(im, 215, 215, 215);
  orangeBox = gdImageColorResolve(im, 255, 189, 22);
  greenBox = gdImageColorResolve(im, 91, 217, 2);

  thick = (theHeight * thickness) / 2;

  while (currentGroup)
  {
      if(csel > 3)
      {
          csel = 0;
      }

      if(currentGroup->level == -1)
      {
          currentGroup = currentGroup->next;
          continue;
      }

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
      if(groupEnd < startPositionGlobalForDrawingFunction || groupStart > endPositionGlobalForDrawingFunction)
      {
          continue;
      }
      b_start = calculateStart(groupStart, 0);
      b_end = calculateEnd(groupStart, b_start, groupEnd, 0);
      b_width = b_end - b_start;
      printNameOfAnnotation(im, visibility, currentGroup->groupName, b_end, y1, black, currentGroup->level);

      if(visibility == VIS_FULL || visibility == VIS_DENSE || visibility == VIS_FULLNAME || visibility == VIS_FULLTEXT)
      {
          gdImageLine(im, (b_start + (compactWidth / 2)), (y1 + y2) / 2, (b_end - (compactWidth / 2)), (y1 + y2) / 2,
                      allocatedColor);
      }
// START Draw groupContext lines
      drawGroupContextLines(im, currentGroup, visibility, b_start, y1, b_end, y2, allocatedColor);
// END Draw groupContext lines

      currentAnnotation = currentGroup->annotations;
      while (currentAnnotation)
      {
          start = calculateStart(currentAnnotation->start, 0);
          end = calculateEnd(currentAnnotation->start, start, currentAnnotation->end, 0);
          width = end - start;
          if(width < 1)
          {
              width = 1;
          }

          if(visibility == VIS_FULL || visibility == VIS_DENSE || visibility == VIS_FULLNAME
             || visibility == VIS_FULLTEXT)
          {
              if(!currentAnnotation->orientation || currentAnnotation->orientation == '+')
              {
                  blockStart = greenBox;
                  if(!currentAnnotation->phase)
                  {
                      blockEnd = orangeBox;
                  }
                  else
                  {
                      blockEnd = greenBox;
                  }
              }
              else if(currentAnnotation->orientation == '-')
              {
                  blockStart = orangeBox;
                  if(!currentAnnotation->phase)
                  {
                      blockEnd = greenBox;
                  }
                  else
                  {
                      blockEnd = orangeBox;
                  }
              }

              gdImageFilledRectangle(im, start, y1, start + compactWidth, y2, blockStart);
              gdImageFilledRectangle(im, (end - compactWidth), y1, end, y2, blockEnd);

          }
          else if(visibility == VIS_DENSEMC)
          {
              gdImageFilledRectangle(im, start, y1, start + width, y2, multicolor[csel]);
          }

          currentAnnotation = currentAnnotation->next;
      }
      csel++;
      currentGroup = currentGroup->next;
  }
  return;
}

void NsingleFos_drawGD(gdImagePtr im, myGroup * theGroup, int visibility, int *multicolor, int initialHeight,
                       int theHeight, int allocatedColor)
{
  int csel = 0;
  int y1 = 0;
  int y2 = 0;
  long groupStart = 0;
  long groupEnd = 0;
  int b_start = 0;
  int b_end = 0;
  int b_width = 0;
  int start = 0;
  int end = 0;
  int mid = theHeight / 2;
  int width = 0;
  float thickness = 0.8;
  float thick = 0;
  int compactWidth = returnCompactWidth();
  int black;
  int orangeBox;
  int greenBox;
  int white;
  int blockStart;
  int blockEnd;
  myAnnotations *currentAnnotation = NULL;
  myGroup *currentGroup = theGroup;

  black = gdImageColorResolve(im, 0, 0, 0);
  white = gdImageColorResolve(im, 215, 215, 215);
  orangeBox = gdImageColorResolve(im, 255, 189, 22);
  greenBox = gdImageColorResolve(im, 91, 217, 2);

  thick = (theHeight * thickness) / 2;

  while (currentGroup)
  {
      if(csel > 3)
      {
          csel = 0;
      }
      if(currentGroup->level == -1)
      {
          currentGroup = currentGroup->next;
          continue;
      }

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
      if(groupEnd < startPositionGlobalForDrawingFunction || groupStart > endPositionGlobalForDrawingFunction)
      {
          continue;
      }
      b_start = calculateStart(groupStart, 0);
      b_end = calculateEnd(groupStart, b_start, groupEnd, 0);
      b_width = b_end - b_start;
      printNameOfAnnotation(im, visibility, currentGroup->groupName, b_end, y1, black, currentGroup->level);
      if(visibility == VIS_FULL || visibility == VIS_DENSE || visibility == VIS_FULLNAME || visibility == VIS_FULLTEXT)
      {
          gdImageLine(im, (b_start + (compactWidth / 2)), (y1 + y2) / 2, (b_end - (compactWidth / 2)), (y1 + y2) / 2,
                      allocatedColor);
      }
// START Draw groupContext lines
      drawGroupContextLines(im, currentGroup, visibility, b_start, y1, b_end, y2, allocatedColor);
// END Draw groupContext lines

      currentAnnotation = currentGroup->annotations;
      while (currentAnnotation)
      {
          start = calculateStart(currentAnnotation->start, 0);
          end = calculateEnd(currentAnnotation->start, start, currentAnnotation->end, 0);
          width = end - start;
          if(width < 1)
          {
              width = 1;
          }

          if(visibility == VIS_FULL || visibility == VIS_DENSE || visibility == VIS_FULLNAME
             || visibility == VIS_FULLTEXT)
          {
              if(!currentAnnotation->orientation || currentAnnotation->orientation == '+')
              {
                  if(!currentAnnotation->phase)
                  {
                      blockStart = greenBox;
                      gdImageFilledRectangle(im, start, y1, start + compactWidth, y2, blockStart);
                  }
                  else
                  {
                      blockEnd = greenBox;
                      gdImageFilledRectangle(im, (end - compactWidth), y1, end, y2, blockEnd);
                  }
              }
              else if(currentAnnotation->orientation == '-')
              {
                  if(!currentAnnotation->phase)
                  {
                      blockEnd = orangeBox;
                      gdImageFilledRectangle(im, (end - compactWidth), y1, end, y2, blockEnd);
                  }
                  else
                  {
                      blockStart = orangeBox;
                      gdImageFilledRectangle(im, start, y1, start + compactWidth, y2, blockStart);
                  }
              }
          }
          else if(visibility == VIS_DENSEMC)
          {
              gdImageFilledRectangle(im, start, y1, start + width, y2, multicolor[csel]);
          }

          currentAnnotation = currentAnnotation->next;
      }
      csel++;
      currentGroup = currentGroup->next;
  }
  return;
}

void Ncdna_drawGD(gdImagePtr im, myGroup * theGroup, int visibility, int *multicolor, int initialHeight, int theHeight,
                  int allocatedColor)
{
  int csel = 0;
  int y1 = 0;
  int y2 = 0;
  int yE1 = 0;
  int yE2 = 0;
  long groupStart = 0;
  long groupEnd = 0;
  int b_start = 0;
  int b_end = 0;
  int b_width = 0;
  int start = 0;
  int end = 0;
  int width = 0;
  int mid = theHeight / 2;
  float thickness = 0.3;
  float thick = 0;
  int black = 0;                //INCLUDE TEXT
  myAnnotations *currentAnnotation = NULL;
  myGroup *currentGroup = theGroup;
  int annotationColor = 0;

  thick = (theHeight * thickness) / 2;
  black = gdImageColorResolve(im, 0, 0, 0);     //INCLUDE TEXT

  while (currentGroup)
  {
      if(csel > 3)
      {
          csel = 0;
      }

      if(currentGroup->level == -1)
      {
          currentGroup = currentGroup->next;
          continue;
      }

      if(visibility == VIS_FULL || visibility == VIS_FULLNAME || visibility == VIS_FULLTEXT)
      {
          y1 = initialHeight + mid + (currentGroup->level * theHeight) - thick;
          yE1 = y1 - 3;
      }
      else if(visibility == VIS_DENSE || visibility == VIS_DENSEMC)
      {
          y1 = initialHeight + mid - thick;
          yE1 = y1 - 3;
      }
      else
      {
          y1 = 0;
      }

      y2 = y1 + (2 * thick);
      yE2 = y2 + 3;

      groupStart = currentGroup->groupStart;
      groupEnd = currentGroup->groupEnd;
      if(groupEnd < startPositionGlobalForDrawingFunction || groupStart > endPositionGlobalForDrawingFunction)
      {
          continue;
      }
      b_start = calculateStart(groupStart, 0);
      b_end = calculateEnd(groupStart, b_start, groupEnd, 0);
      b_width = b_end - b_start;
      printNameOfAnnotation(im, visibility, currentGroup->groupName, b_end, y1, black, currentGroup->level);

      if(visibility == VIS_FULL || visibility == VIS_DENSE || visibility == VIS_FULLNAME || visibility == VIS_FULLTEXT)
      {
          gdImageRectangle(im, b_start, yE1, b_end, yE2, allocatedColor);
      }
      else if(visibility == VIS_DENSEMC)
      {
          gdImageLine(im, b_start, (y1 + y2) / 2, b_end, (y1 + y2) / 2, multicolor[csel]);
      }
// START Draw groupContext lines
      drawGroupContextLines(im, currentGroup, visibility, b_start, y1, b_end, y2, allocatedColor);
// END Draw groupContext lines

      currentAnnotation = currentGroup->annotations;
      while (currentAnnotation)
      {
          if(currentAnnotation->displayColor > -1)
          {
              annotationColor =
                  gdImageColorResolve(im, getRed(currentAnnotation->displayColor),
                                      getGreen(currentAnnotation->displayColor),
                                      getBlue(currentAnnotation->displayColor));
          }
          else
          {
              annotationColor = allocatedColor;
          }

          start = calculateStart(currentAnnotation->start, 0);
          end = calculateEnd(currentAnnotation->start, start, currentAnnotation->end, 0);
          width = end - start;
          if(width < 1)
          {
              width = 1;
          }

          if(visibility == VIS_FULL || visibility == VIS_DENSE || visibility == VIS_FULLNAME
             || visibility == VIS_FULLTEXT)
          {
              gdImageFilledRectangle(im, start, y1, start + width, y2, annotationColor);
          }
          else if(visibility == VIS_DENSEMC)
          {
              gdImageFilledRectangle(im, start, y1, start + width, y2, multicolor[csel]);
          }

          currentAnnotation = currentAnnotation->next;
      }
      csel++;
      currentGroup = currentGroup->next;
  }
  return;
}

/******************************************************************************/

void pie_drawGD(gdImagePtr im, myGroup * theGroup, int visibility, int *multicolor, int initialHeight, int theHeight,
                int allocatedColor, float maxScore, int maxFactor)
{
  int csel = 0;
  int y1 = 0;
  int y2 = 0;
  int i = 0;
  int start = 0;
  int width = 0;
  int end = 0;
  int mid = theHeight / 2;
  float thickness = 0.4;
  float thick = 0;
  int levelSize = 20;
  int redPositive = 0;
  int greenPositive = 0;
  int bluePositive = 0;
  int *theLevels;
  float temporaryScore = 0.0;
  float normalized = 0.0;
  float tmpMyScore = 0.0;
  int degrees = 0;
  int correctedDegrees = 0;
  int maxColor = 255;
  int incrementalGradient = 0;
  int a = 0;
  int d = 0;
  int black = 0;                //INCLUDE TEXT
  gdFontPtr font = gdFontTiny;  //INCLUDE TEXT
  char reusableText[55] = "";   //INCLUDE TEXT
  int sizeToCopy = 15;          //INCLUDE TEXT
  myAnnotations *currentAnnotation = NULL;
  myGroup *currentGroup = theGroup;
  float greenFactor = 0.0;
  float redFactor = 0.0;
  float blueFactor = 0.0;
  int R = 0;
  int G = 0;
  int B = 0;
  int colorPointer = 0;
  int colorLevel = 0;
  int red = 0;
  int green = 0;
  int blue = 0;
  int myColor = 0;
  int myBackGroundColor = 0;
  int tempR = 0;
  int tempG = 0;
  int tempB = 0;
  int whiteLimit = 200;
  int middleFactor = 0;
  long long length = lengthOfSegmentGlobalForDrawingFunction + 1;
  long long canvasWidth = canvasWidthGlobalForDrawingFunction;
  float boxSize = (float)canvasWidth / (float)length;

  middleFactor = round((boxSize / 2) - (font->w / 2));

  thick = (theHeight * thickness) / 2;
  black = gdImageColorResolve(im, 0, 0, 0);     //INCLUDE TEXT

  red = gdImageRed(im, allocatedColor);
  green = gdImageGreen(im, allocatedColor);
  blue = gdImageBlue(im, allocatedColor);
  if(red > whiteLimit && green > whiteLimit && blue > whiteLimit)
  {
      tempR = tempG = tempB = whiteLimit;
  }
  else
  {
      tempR = red;
      tempG = green;
      tempB = blue;
  }

  myColor = gdImageColorResolve(im, tempR, tempG, tempB);
  tempR = abs(255 - red);
  tempG = abs(255 - green);
  tempB = abs(255 - blue);

  if(tempR > whiteLimit && tempG > whiteLimit && tempB > whiteLimit)
  {
      tempR = tempG = tempB = whiteLimit;
  }
  myBackGroundColor = gdImageColorResolve(im, tempR, tempG, tempB);

  if(red > maxFactor)
  {
      redPositive = 0;
  }
  else
  {
      redPositive = 1;
  }

  if(green > maxFactor)
  {
      greenPositive = 0;
  }
  else
  {
      greenPositive = 1;
  }

  if(blue > maxFactor)
  {
      bluePositive = 0;
  }
  else
  {
      bluePositive = 1;
  }

  if(getMyDebug())
  {
      fprintf(stderr, "red = %d, green = %d, blue = %d and redPositive = %d"
              ", greenPositive = %d and bluePositive = %d\n", red, green, blue, redPositive, greenPositive,
              bluePositive);
  }

  if((theLevels = (int *)malloc((levelSize) * sizeof(int))) == NULL)
  {
      perror("problems with theLevels");
      return;
  }

  if(maxFactor >= red)
  {
      redFactor = (float)((maxFactor - red) / levelSize);
  }
  else
  {
      redFactor = (float)((red - maxFactor) / levelSize);
  }

  if(maxFactor >= green)
  {
      greenFactor = (float)((maxFactor - green) / levelSize);
  }
  else
  {
      greenFactor = (float)((green - maxFactor) / levelSize);
  }

  if(maxFactor >= blue)
  {
      blueFactor = (float)((maxFactor - blue) / levelSize);
  }
  else
  {
      blueFactor = (float)((blue - maxFactor) / levelSize);
  }

  if(getMyDebug())
  {
      fprintf(stderr, "redFactor = %f, greenFactor = %f" ", blueFactor = %f\n", redFactor, greenFactor, blueFactor);
  }

  for (a = levelSize - 1, i = 0; i < levelSize; i++, a--)
  {
      if(redPositive)
      {
          R = red + (int)nearbyint(redFactor * i);
      }
      else
      {
          R = red - (int)nearbyint(redFactor * i);
      }
      if(R > maxColor)
      {
          R = maxColor;
      }
      if(R < 0)
      {
          R = 0;
      }
      if(greenPositive)
      {
          G = green + (int)nearbyint(greenFactor * i);
      }
      else
      {
          G = green - (int)nearbyint(greenFactor * i);
      }
      if(G > maxColor)
      {
          G = maxColor;
      }
      if(G < 0)
      {
          G = 0;
      }
      if(bluePositive)
      {
          B = blue + (int)nearbyint(blueFactor * i);
      }
      else
      {
          B = blue - (int)nearbyint(blueFactor * i);
      }
      if(B > maxColor)
      {
          B = maxColor;
      }
      if(B < 0)
      {
          B = 0;
      }

      if(getMyDebug())
      {
          fprintf(stderr, "R = %d, G = %d, B = %d\n", R, G, B);
          fprintf(stderr, "levelSize = %d, a = %d, i = %d\n", levelSize, a, i);
      }

      if(incrementalGradient)
      {
          d = i;
      }
      else
      {
          d = a;
      }

      theLevels[d] = gdImageColorResolve(im, R, G, B);
  }

  if(getMyDebug())
  {
      fflush(stderr);
  }

  while (currentGroup)
  {
      currentAnnotation = currentGroup->annotations;
      while (currentAnnotation)
      {
          if(csel > 3)
          {
              csel = 0;
          }

          if(currentAnnotation->level == -1)
          {
              currentAnnotation = currentAnnotation->next;
              continue;
          }

          if(visibility == VIS_FULL || visibility == VIS_FULLNAME || visibility == VIS_FULLTEXT)
          {
              y1 = initialHeight + mid + (currentAnnotation->level * theHeight) - thick;
          }

          y2 = y1 + (2 * thick);

          start = calculateStart(currentAnnotation->start, 0);
          end = calculateEnd(currentAnnotation->start, start, currentAnnotation->end, 0);
          width = end - start;
          if(width < 1)
          {
              width = 1;
          }

          if(currentAnnotation->score < 0.0000000000)
          {
              temporaryScore = 0.0;
          }
          else
          {
              temporaryScore = currentAnnotation->score;
          }

          if(maxScore > 0.000)
          {
              normalized = (float)(temporaryScore / maxScore);
              colorLevel = round(normalized * (levelSize - 1) + 0.51);
              if(colorLevel >= levelSize)
              {
                  colorLevel = levelSize - 1;
              }
          }
          else
          {
              normalized = 0.0;
              colorLevel = 0;
          }

//TODO INCLUDE TEXT

          if(visibility == VIS_FULLNAME)
          {
//                                int textStart = 0;
            memset(reusableText, '\0', 55);
            strncpy(reusableText, currentGroup->groupName, sizeToCopy);
            if(strlen(currentGroup->groupName) > sizeToCopy)
            {
                reusableText[sizeToCopy - 2] = '.';
                reusableText[sizeToCopy - 1] = '.';
                reusableText[sizeToCopy] = '.';
            }
            if(currentAnnotation->level < MAXNUMBERLINESINTRACK)
            {
                gdImageString(im, font, (start + middleFactor + 15), ((y1 + 10) - (font->h / 2)),
                              (unsigned char *)reusableText, black);
            }
          }
          else if(visibility == VIS_FULLTEXT)
          {
            if(currentAnnotation->level < MAXNUMBERLINESINTRACK)
            {
              int fidText = printTextSizeFromFid(im, font, currentAnnotation->uploadId, currentAnnotation->id, 't', MAXTEXTSIZE,
                                   sizeToCopy, (start + 22), ((y1 + 10) - (font->h / 2)), black);
              if(fidText == 0){
                memset(reusableText, '\0', 55);
                strncpy(reusableText, currentGroup->groupName, sizeToCopy);
                if(strlen(currentGroup->groupName) > sizeToCopy)
                {
                    reusableText[sizeToCopy - 2] = '.';
                    reusableText[sizeToCopy - 1] = '.';
                    reusableText[sizeToCopy] = '.';
                }
                if(currentAnnotation->level < MAXNUMBERLINESINTRACK)
                {
                    gdImageString(im, font, (start + middleFactor + 15), ((y1 + 10) - (font->h / 2)),
                                  (unsigned char *)reusableText, black);
                }
              }
            }
          }
          //TODO END INCLUDE TEXT

          if(visibility == VIS_FULL || visibility == VIS_DENSE || visibility == VIS_FULLNAME
             || visibility == VIS_FULLTEXT)
          {
              colorPointer = theLevels[colorLevel];
          }
          else
          {
              colorPointer = multicolor[csel];
          }

          if(currentAnnotation->level < MAXNUMBERLINESINTRACK)
          {
              if(visibility == VIS_FULL || visibility == VIS_FULLNAME || visibility == VIS_FULLTEXT)
              {
                  tmpMyScore = currentAnnotation->score;
                  if(tmpMyScore >= 1.0)
                  {
                      tmpMyScore = 0.99;
                  }
                  else if(tmpMyScore < 0)
                  {
                      tmpMyScore = 0.0;
                  }

                  degrees = (int)ceil(tmpMyScore * 360);
                  if(degrees > 0 && degrees <= 90)
                  {
                      correctedDegrees = degrees + 270;
                  }
                  else if(degrees > 90 && degrees <= 360)
                  {
                      correctedDegrees = degrees - 90;
                  }
                  else
                  {
                      correctedDegrees = 270;
                  }

                  //                      gdImageFilledEllipse(im, start + middleFactor, y1 + 10, 20, 20, myBackGroundColor);
                  gdImageFilledArc(im, start + middleFactor, y1 + 10, 20, 20, 270, 269, myBackGroundColor, gdPie);
                  gdImageFilledArc(im, start + middleFactor, y1 + 10, 20, 20, 270, correctedDegrees, myColor, gdPie);
              }
          }
          else
          {
              gdImageFilledRectangle(im, start, y1, start + width, y2, colorPointer);
          }

          currentAnnotation = currentAnnotation->next;
          csel++;
      }
      currentGroup = currentGroup->next;
  }
  return;
}

/******************************************************************************** */
void NgradientScore_drawGD(gdImagePtr im, myGroup * theGroup, int visibility, int *multicolor, int initialHeight,
                           int theHeight, int allocatedColor, float maxScore, int maxFactor)
{
  int csel = 0;
  int y1 = 0;
  int y2 = 0;
  int i = 0;
  int start = 0;
  int width = 0;
  int end = 0;
  int mid = theHeight / 2;
  int red = 0;
  int green = 0;
  int blue = 0;
  float greenFactor = 0.0;
  float redFactor = 0.0;
  float blueFactor = 0.0;
  int R = 0;
  int G = 0;
  int B = 0;
  int colorPointer = 0;
  int colorLevel = 0;
  float thickness = 0.4;
  float thick = 0;
  int levelSize = 20;
  int redPositive = 0;
  int greenPositive = 0;
  int bluePositive = 0;
  int *theLevels;
  float temporaryScore = 0.0;
  float normalized = 0.0;
  int maxColor = 255;
  int incrementalGradient = 0;
  int a = 0;
  int d = 0;
  int black = 0;                //INCLUDE TEXT
  gdFontPtr font = gdFontTiny;  //INCLUDE TEXT
  int sizeToCopy = 15;          //INCLUDE TEXT
  myAnnotations *currentAnnotation = NULL;
  myGroup *currentGroup = theGroup;

  thick = (theHeight * thickness) / 2;
  black = gdImageColorResolve(im, 0, 0, 0);     //INCLUDE TEXT

  red = gdImageRed(im, allocatedColor);
  green = gdImageGreen(im, allocatedColor);
  blue = gdImageBlue(im, allocatedColor);

  if(red > maxFactor)
  {
      redPositive = 0;
  }
  else
  {
      redPositive = 1;
  }

  if(green > maxFactor)
  {
      greenPositive = 0;
  }
  else
  {
      greenPositive = 1;
  }

  if(blue > maxFactor)
  {
      bluePositive = 0;
  }
  else
  {
      bluePositive = 1;
  }

  if(getMyDebug())
  {
      fprintf(stderr, "red = %d, green = %d, blue = %d and redPositive = %d"
              ", greenPositive = %d and bluePositive = %d\n", red, green, blue, redPositive, greenPositive,
              bluePositive);
  }

  if((theLevels = (int *)malloc((levelSize) * sizeof(int))) == NULL)
  {
      perror("problems with theLevels");
      return;
  }

  if(maxFactor >= red)
  {
      redFactor = (float)((maxFactor - red) / levelSize);
  }
  else
  {
      redFactor = (float)((red - maxFactor) / levelSize);
  }

  if(maxFactor >= green)
  {
      greenFactor = (float)((maxFactor - green) / levelSize);
  }
  else
  {
      greenFactor = (float)((green - maxFactor) / levelSize);
  }

  if(maxFactor >= blue)
  {
      blueFactor = (float)((maxFactor - blue) / levelSize);
  }
  else
  {
      blueFactor = (float)((blue - maxFactor) / levelSize);
  }

  for (a = levelSize - 1, i = 0; i < levelSize; i++, a--)
  {
      if(redPositive)
      {
          R = red + (int)nearbyint(redFactor * i);
      }
      else
      {
          R = red - (int)nearbyint(redFactor * i);
      }
      if(R > maxColor)
      {
          R = maxColor;
      }
      if(R < 0)
      {
          R = 0;
      }
      if(greenPositive)
      {
          G = green + (int)nearbyint(greenFactor * i);
      }
      else
      {
          G = green - (int)nearbyint(greenFactor * i);
      }
      if(G > maxColor)
      {
          G = maxColor;
      }
      if(G < 0)
      {
          G = 0;
      }
      if(bluePositive)
      {
          B = blue + (int)nearbyint(blueFactor * i);
      }
      else
      {
          B = blue - (int)nearbyint(blueFactor * i);
      }
      if(B > maxColor)
      {
          B = maxColor;
      }
      if(B < 0)
      {
          B = 0;
      }

      if(incrementalGradient)
      {
          d = i;
      }
      else
      {
          d = a;
      }

      theLevels[d] = gdImageColorResolve(im, R, G, B);
  }

  if(getMyDebug())
  {
      fflush(stderr);
  }

  while (currentGroup)
  {
      currentAnnotation = currentGroup->annotations;
      while (currentAnnotation)
      {
          if(csel > 3)
          {
              csel = 0;
          }

          if(currentAnnotation->level == -1)
          {
              currentAnnotation = currentAnnotation->next;
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

// TODO fix the normalized value

          if(currentAnnotation->score < 0.0000000000)
          {
              temporaryScore = 0.0;
          }
          else
          {
              temporaryScore = currentAnnotation->score;
          }

          if(maxScore > 0.000)
          {
              normalized = (float)(temporaryScore / maxScore);
              colorLevel = round(normalized * (levelSize - 1) + 0.51);
              if(colorLevel >= levelSize)
                colorLevel = levelSize - 1;
          }
          else
          {
              normalized = 0.0;
              colorLevel = 0;
          }

          start = calculateStart(currentAnnotation->start, 0);
          end = calculateEnd(currentAnnotation->start, start, currentAnnotation->end, 0);
          width = end - start;
          if(width < 1)
          {
              width = 1;
          }

          if(visibility == VIS_FULLTEXT && currentAnnotation->level < MAXNUMBERLINESINTRACK){
            int fidText = printTextSizeFromFid(im, font, currentAnnotation->uploadId, currentAnnotation->id, 't', MAXTEXTSIZE,
                                 sizeToCopy, end + SPACEBEFORETEXT, y1 - 1, black);
            if(fidText == 0){
              printNameOfAnnotation(im, visibility, currentGroup->groupName, end, y1, black, currentAnnotation->level);
            }
          }
          else if(visibility != VIS_FULLTEXT){
            printNameOfAnnotation(im, visibility, currentGroup->groupName, end, y1, black, currentAnnotation->level);
          }
          //TODO END INCLUDE TEXT

          if(visibility == VIS_FULL || visibility == VIS_DENSE || visibility == VIS_FULLNAME
             || visibility == VIS_FULLTEXT)
          {
              colorPointer = theLevels[colorLevel];
          }
          else
          {
              colorPointer = multicolor[csel];
          }

          if(visibility == VIS_FULL || visibility == VIS_DENSE || visibility == VIS_FULLNAME
             || visibility == VIS_FULLTEXT)
          {
              gdImageFilledRectangle(im, start, y1, start + width, y2, colorPointer);
          }
          else if(visibility == VIS_DENSEMC)
          {
              gdImageFilledRectangle(im, start, y1, start + width, y2, multicolor[csel]);
          }

          currentAnnotation = currentAnnotation->next;
          csel++;
      }
      currentGroup = currentGroup->next;
  }
  return;
}

void NDifferentialgradientScore_drawGD(gdImagePtr im, myGroup * theGroup, int visibility, int *multicolor,
                                       int initialHeight, int theHeight, int allocatedColor, float maxScore,
                                       int incrementalGradient)
{
  int csel = 0;
  int y1 = 0;
  int y2 = 0;
  int i = 0;
  int start = 0;
  int width = 0;
  int end = 0;
  int mid = theHeight / 2;
  int R[] = { 241, 241, 241, 198, 80, 0, 0, 0, 0, 96 };
  int G[] = { 0, 178, 241, 238, 198, 164, 174, 98, 0, 0 };
  int B[] = { 0, 0, 0, 0, 0, 0, 136, 241, 241, 148 };
  int colorPointer = 0;
  int colorLevel = 0;
  float thickness = 0.4;
  float thick = 0;
  int levelSize = 10;
  int *theLevels;
  float temporaryScore = 0.0;
  double normalized = 0.0;
  int a = 0;
  int d = 0;
  int black = 0;                //INCLUDE TEXT
  gdFontPtr font = gdFontTiny;  //INCLUDE TEXT
  int sizeToCopy = 15;          //INCLUDE TEXT
  myAnnotations *currentAnnotation = NULL;
  myGroup *currentGroup = theGroup;

  thick = (theHeight * thickness) / 2;
  black = gdImageColorResolve(im, 0, 0, 0);     //INCLUDE TEXT

  if((theLevels = (int *)malloc((levelSize) * sizeof(int))) == NULL)
  {
      perror("problems with theLevels");
      return;
  }

  for (a = levelSize - 1, i = 0; i < levelSize; i++, a--)
  {

      if(incrementalGradient)
      {
          d = i;
      }
      else
      {
          d = a;
      }

      theLevels[d] = gdImageColorResolve(im, R[i], G[i], B[i]);
  }

  while (currentGroup)
  {
      currentAnnotation = currentGroup->annotations;
      while (currentAnnotation)
      {
          if(csel > 3)
          {
              csel = 0;
          }

          if(currentAnnotation->level == -1)
          {
              currentAnnotation = currentAnnotation->next;
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

          if(currentAnnotation->score < 0.0000000000)
          {
              temporaryScore = 0.0;
          }
          else
          {
              temporaryScore = currentAnnotation->score;
          }

          if(maxScore > 0.000)
          {
              normalized = temporaryScore / maxScore;
              colorLevel = round(normalized * (levelSize - 1) + 0.51) - 1;
              if(colorLevel > levelSize)
              {
                  colorLevel = levelSize - 1;
              }
          }
          else
          {
              normalized = 0.0;
              colorLevel = 0;
          }

          start = calculateStart(currentAnnotation->start, 0);
          end = calculateEnd(currentAnnotation->start, start, currentAnnotation->end, 0);
          width = end - start;
          if(width < 1)
          {
              width = 1;
          }

          if(visibility == VIS_FULL || visibility == VIS_DENSE || visibility == VIS_FULLNAME
             || visibility == VIS_FULLTEXT)
          {
              colorPointer = theLevels[colorLevel];
          }
          else
          {
              colorPointer = multicolor[csel];
          }

          if(visibility == VIS_FULLTEXT && currentAnnotation->level < MAXNUMBERLINESINTRACK)
          {
              int fidText = printTextSizeFromFid(im, font, currentAnnotation->uploadId, currentAnnotation->id, 't', MAXTEXTSIZE,
                                   sizeToCopy, end + SPACEBEFORETEXT, y1 - 1, black);
              if(fidText == 0){
                printNameOfAnnotation(im, visibility, currentGroup->groupName, end, y1, black, currentAnnotation->level);
              }
          }
          else if(visibility != VIS_FULLTEXT){
            printNameOfAnnotation(im, visibility, currentGroup->groupName, end, y1, black, currentAnnotation->level);
          }
          if(visibility == VIS_FULL || visibility == VIS_DENSE || visibility == VIS_FULLNAME
             || visibility == VIS_FULLTEXT)
          {
              gdImageFilledRectangle(im, start, y1, start + width, y2, colorPointer);
          }
          else if(visibility == VIS_DENSEMC)
          {
              gdImageFilledRectangle(im, start, y1, start + width, y2, multicolor[csel]);
          }

          currentAnnotation = currentAnnotation->next;
          csel++;
      }
      currentGroup = currentGroup->next;
  }
  return;
}

void NscoreBased_drawGD(gdImagePtr im, myGroup * theGroup, int visibility, int *multicolor, int initialHeight,
                        int theHeight, int allocatedColor, float maxScore, float minScore)
{
  int csel = 0;
  int y1 = 0;
  int y2 = 0;
  int i = 0;
  int start = 0;
  int end = 0;
  int width = 0;
  int black = 0;
  int white = 0;
  int blue = 0;
  int colorPointer = 0;
  float thickness = 0.4;
  float thick = 0;
  int levelSize = 210;
  int *theLevels;
  int level = 0;
  int maxlevel = 0;
  float temporaryScore = 0.0;
  float normalized = 0.0;
  float height = theHeight;
  myAnnotations *currentAnnotation = NULL;
  myGroup *currentGroup = theGroup;
  float span = 0.0;

  span = fabs(maxScore) + fabs(minScore);

  if((theLevels = (int *)malloc((levelSize) * sizeof(int))) == NULL)
  {
      perror("problems with theLevels");
      return;
  }
  for (i = 0; i < levelSize; i++)
  {
      theLevels[i] = i;
  }

  black = gdImageColorResolve(im, 0, 0, 0);
  white = gdImageColorResolve(im, 215, 215, 215);
  blue = gdImageColorResolve(im, 0, 0, 180);

  thick = (theHeight * thickness) / 2;

  theLevels[0] = -1;
  if(visibility == VIS_FULL || visibility == VIS_FULLNAME || visibility == VIS_FULLTEXT)
  {
      while (currentGroup)
      {
          level = currentGroup->level;

          if(level > maxlevel)
          {
              maxlevel = level;
          }

          if(theLevels[level] == level)
          {
              gdImageLine(im, labelWidthGlobalForDrawingFunction, (initialHeight + (level * SPECIALHEIGHT)),
                          totalWidthGlobalForDrawingFunction, (initialHeight + (level * SPECIALHEIGHT)), blue);
              theLevels[level] = -1;
          }

          currentGroup = currentGroup->next;
      }

  }
  maxlevel++;
  currentGroup = theGroup;
  while (currentGroup)
  {
      if(csel > 3)
        csel = 0;

      if(currentGroup->level == -1)
      {
          currentGroup = currentGroup->next;
          continue;
      }

      y1 = initialHeight + (currentGroup->level * theHeight);

      currentAnnotation = currentGroup->annotations;
      while (currentAnnotation)
      {
          start = calculateStart(currentAnnotation->start, 2);
          end = calculateEnd(currentAnnotation->start, start, currentAnnotation->end, 2);
          width = end - start;
          if(width < 1)
          {
              width = 1;
          }
          temporaryScore = currentAnnotation->score + fabs(minScore);

          normalized = (float)(temporaryScore / span);
          height = round(normalized * SPECIALHEIGHT);

          if(visibility == VIS_FULL || visibility == VIS_DENSE || visibility == VIS_FULLNAME
             || visibility == VIS_FULLTEXT)
          {
              colorPointer = allocatedColor;
          }
          else
          {
              colorPointer = multicolor[csel];
          }

          if(visibility == VIS_FULL || visibility == VIS_FULLNAME || visibility == VIS_FULLTEXT)
          {
              y1 = initialHeight + (currentGroup->level * SPECIALHEIGHT);
              y1 = y1 + (SPECIALHEIGHT - height);
              y2 = y1 + height;
          }
          else if(visibility == VIS_DENSE || visibility == VIS_DENSEMC)
          {
              y1 = initialHeight;
              y1 = y1 + (SPECIALHEIGHT - height);
              y2 = y1 + height;
          }

          gdImageFilledRectangle(im, start, y1, start + width, y2, colorPointer);

          currentAnnotation = currentAnnotation->next;
      }
      csel++;
      currentGroup = currentGroup->next;
  }
  gdImageRectangle(im, labelWidthGlobalForDrawingFunction + 1, initialHeight, totalWidthGlobalForDrawingFunction - 1,
                   (initialHeight + (maxlevel * SPECIALHEIGHT)), black);
  free(theLevels);
  theLevels = NULL;

  return;
}


// Method for drawing bidirectional bar-charts.
// Useful for drawing tracks with +ve and -ve values
void bidirectional_drawGD(gdImagePtr im, myTrack *localTrack, int visibility, int *multicolor, int initialHeight, int theHeight, int allocatedColor, float maxScore, float minScore, int allocatedUpperColor, int allocatedLowerColor, int negativeColor, int allocatedUpperNegativeColor, int allocatedLowerNegativeColor){
  int csel = 0;
  int y1 = 0;
  int y2 = 0;
  int i = 0;
  int start = 0;
  int black = 0;
  int white = 0;
  int blue = 0;
  int colorPointer = 0, negativeColorPointer = 0;
  int yInterceptHeight = 0;
  gdouble temporaryScore = 0.0, negativeTemporaryScore = 0.0;
  long height = theHeight;
  highDensFtypes *localHDInfo = localTrack->highDensFtypes;
  gdouble maximumScore = localHDInfo->gbTrackDataMax;
  gdouble minimumScore = localHDInfo->gbTrackDataMin;
  gdouble upperPxValue = localHDInfo->gbTrackPxScoreUpperThreshold;
  gdouble lowerPxValue = localHDInfo->gbTrackPxScoreLowerThreshold;
  gdouble upperNegativePxValue = localHDInfo->gbTrackPxScoreUpperNegativeThreshold;
  gdouble lowerNegativePxValue = localHDInfo->gbTrackPxScoreLowerNegativeThreshold;
  gdouble logUpperPxValue, logLowerPxValue;
  gdouble logUpperNegativePxValue, logLowerNegativePxValue;
  gdouble yIntercept = localHDInfo->gbTrackYIntercept;
  int annotationColor = 0;
  gdouble span = 0.0;
  int numberOfPixels = canvasWidthGlobalForDrawingFunction;
  gdouble *pixelValueForHDT = localTrack->pixelValueForHDT;
  gdouble *pixelExtraValues = localTrack->pixelExtraValues;
  gdouble *pixelNegativeValueForHDT = localTrack->pixelNegativeValueForHDT;
  gdouble *pixelExtraNegativeValues = localTrack->pixelExtraNegativeValues;
  char *theStyle = localTrack->style;
  int windowingMethod = (int)localHDInfo->gbTrackWindowingMethod;
  gdouble factor = 0.0;
  long maxRangeTrans = 0;
  long minRangeTrans = 0;
  gdouble maximumLocal = 0.0;
  gdouble minimumLocal = 0.0;
  int useLocalScore = 0;
  int scaleToUse = 0;
  gdouble valueToAddToMinimum = 0.0;
  bool useLog = (int)localHDInfo->gbTrackUseLog;
  int draw0 ;
  if(strcmp(localHDInfo->gbTrackZeroDraw, "true") == 0)
    draw0 = 1 ;
  else
    draw0 = 0 ;
  // Check if 'local' drawing is required
  if(strcmp(theStyle, "bidirectional_local_draw_large") == 0 || strcmp(theStyle, "bidirectional_local_draw_small") == 0)
  {
    useLocalScore = 1;
  }
  if(useLog)
  {
    minimumLocal = log10(localHDInfo->gbTrackDataMax);
    maximumLocal = log10(localHDInfo->gbTrackDataMin);
  }
  else
  {
    maximumLocal = localHDInfo->gbTrackDataMin;
    minimumLocal = localHDInfo->gbTrackDataMax;
  }
  gdouble minValToSkip = localHDInfo->gbTrackDataMin - 1.0 ;
  gdouble maxValToSkip = localHDInfo->gbTrackDataMax + 1.0 ;
  // In case of 'small' barcharts, use fixed height.
  if((strcmp(theStyle, "bidirectional_local_draw_small") == 0) || (strcmp(theStyle, "bidirectional_draw_small") == 0))
  {
    scaleToUse = SPECIALHEIGHT;
  }
  else
  {
    scaleToUse = (int)localHDInfo->gbTrackPxHeight;
  }
  // Calculate the min and max for local bidir bar chart drawing
  if(useLocalScore)
  {
    for (i = 0; i < numberOfPixels; i++)
    {
      temporaryScore = 0.0;
      // For 'AVG' windowing
      if(windowingMethod == 0)
      {
        // For 'up' values
        if(pixelValueForHDT[i] >= localHDInfo->gbTrackDataMin)
          temporaryScore = pixelValueForHDT[i] / pixelExtraValues[i] ;
        else
          temporaryScore = minValToSkip ;
        // For 'down' values
        if(pixelNegativeValueForHDT[i] >= localHDInfo->gbTrackDataMin)
          negativeTemporaryScore = pixelNegativeValueForHDT[i] / pixelExtraNegativeValues[i] ;
        else
          negativeTemporaryScore = minValToSkip ;
      }
      // For 'MAX' and 'MIN' windowing
      else
      {
        // For 'up' values
        if(pixelValueForHDT[i] >= localHDInfo->gbTrackDataMin)
          temporaryScore = pixelValueForHDT[i] ;
        else
          temporaryScore = minValToSkip ;
        // For 'down' values
        if(pixelNegativeValueForHDT[i] <= localHDInfo->gbTrackDataMax)
          negativeTemporaryScore = pixelNegativeValueForHDT[i];
        else
          negativeTemporaryScore = minValToSkip ;
      }
      if(useLog)
      {
        // For 'up' values
        if(!isnan(temporaryScore) && !isinf(temporaryScore) && temporaryScore > 0.0)
        {
          temporaryScore = log10(temporaryScore);
        }
        else
        {
          temporaryScore = 0.0;
        }
        // For down 'values'
        if(!isnan(negativeTemporaryScore) && !isinf(negativeTemporaryScore) && negativeTemporaryScore > 0.0)
        {
          negativeTemporaryScore = log10(negativeTemporaryScore);
        }
        else
        {
          negativeTemporaryScore = 0.0;
        }
      }
      if(!isnan(temporaryScore) && !isinf(temporaryScore) && !isnan(negativeTemporaryScore) && !isinf(negativeTemporaryScore))
      {
        // The local 'min' and 'max' should apply to both the 'up' and the 'down' values
        if(temporaryScore != minValToSkip)
        {
          if(temporaryScore > maximumLocal)
          {
            maximumLocal = temporaryScore;
          }
          else if(temporaryScore < minimumLocal)
          {
            minimumLocal = temporaryScore;
          }
        }
        if(negativeTemporaryScore != minValToSkip)
        {
          if(negativeTemporaryScore > maximumLocal){
            maximumLocal = negativeTemporaryScore;
          }
          else if(negativeTemporaryScore < minimumLocal){
            minimumLocal = negativeTemporaryScore;
          }
        }
      }
      else
      {
        fprintf(stderr, "Error during hdhv drawing the temp score[%d]:%lf and neg temp score[%d]:%lf", i, temporaryScore, i, negativeTemporaryScore) ;
      }
    }
  }
  if(useLocalScore && !useLog)
  {
    maximumScore = maximumLocal ;
    minimumScore = minimumLocal ;
  }
  else if(useLocalScore && useLog)
  {
    maximumScore = maximumLocal ;
    minimumScore = minimumLocal ;
    if(upperPxValue != (gdouble)-4290772992.0){
      logUpperPxValue = log10(upperPxValue);
    }
    if(lowerPxValue != (gdouble)4290772992){
      logLowerPxValue = log10(lowerPxValue);
    }
    if(upperNegativePxValue != (gdouble)-4290772992.0){
      logUpperNegativePxValue = log10(upperNegativePxValue);
    }
    if(lowerNegativePxValue != (gdouble)4290772992){
      logLowerNegativePxValue = log10(lowerNegativePxValue);
    }
  }
  else if(!useLocalScore)
  {
    maximumScore = localHDInfo->gbTrackUserMax ;
    minimumScore = localHDInfo->gbTrackUserMin ;
  }
  if(useLog && !useLocalScore)
  {
    if(maximumScore >= 0.0)
    {
      maximumScore = log10(maximumScore);
    }
    else
    {
      maximumScore = 0;
    }
    if(minimumScore >= 0.0)
    {
      minimumScore = log10(minimumScore);
    }
    else
    {
      minimumScore = 0;
    }
    if(upperPxValue != (gdouble)-4290772992.0){
      logUpperPxValue = log10(upperPxValue);
    }
    if(lowerPxValue != (gdouble)4290772992){
      logLowerPxValue = log10(lowerPxValue);
    }
    if(upperNegativePxValue != (gdouble)-4290772992.0){
      logUpperNegativePxValue = log10(upperNegativePxValue);
    }
    if(lowerNegativePxValue != (gdouble)4290772992){
      logLowerNegativePxValue = log10(lowerNegativePxValue);
    }
  }
  if(minimumScore > maximumScore)
  {
    gdouble tempValue = maximumScore;
    maximumScore = minimumScore;
    minimumScore = tempValue;
    // do not use 'real' scaling
    if(draw0 == 1)
    {
      if(maximumScore >= 0.0 && minimumScore >= 0.0)
      {
        minimumScore = 0.0 ;
        maximumScore = maximumScore ;
      }
      else if(maximumScore <= 0.0 && minimumScore <= 0.0)
      {
        maximumScore = 0.0 ;
        minimumScore = minimumScore ;
      }
      else
      {
        maximumScore = maximumScore ;
        minimumScore = minimumScore ;
      }
    }
  }
  else if(minimumScore == maximumScore)
  {
    if(minimumScore > 0)
    {
      minimumScore = 0.0;
    }
    else if(minimumScore < 0)
    {
      maximumScore = 0.0;
    }

  }
  else
  {
    // do not use 'real' scaling
    if(draw0 == 1)
    {
      if(maximumScore >= 0.0 && minimumScore >= 0.0)
      {
        minimumScore = 0.0 ;
        maximumScore = maximumScore ;
      }
      else if(maximumScore <= 0.0 && minimumScore <= 0.0)
      {
        maximumScore = 0.0 ;
        minimumScore = minimumScore ;
      }
      else
      {
        maximumScore = maximumScore ;
        minimumScore = minimumScore ;
      }
    }
  }
  black = gdImageColorResolve(im, 0, 0, 0);
  white = gdImageColorResolve(im, 255, 255, 255);
  blue = gdImageColorResolve(im, 0, 0, 180);
  span = maximumScore - minimumScore;
  factor = (double)scaleToUse / span;
  y1 = initialHeight + theHeight;
  if(useLog)
  {
    maxRangeTrans = (long)round((maximumScore - minimumScore) * factor);
  }
  else
  {
    maxRangeTrans = (long)ceil((maximumScore - minimumScore) * factor);
  }
  minRangeTrans = -1;
  valueToAddToMinimum = span * factorToDrawPixelsWithBackground;
  // Get the height for the y-intercept
  if(useLog)
  {
    yInterceptHeight = (long)round((yIntercept - minimumScore) * factor);
  }
  else
  {
    yInterceptHeight = (long)ceil((yIntercept - minimumScore) * factor);
  }

  if(yInterceptHeight > maxRangeTrans)
  {
    yInterceptHeight = maxRangeTrans;
  }

  if(yInterceptHeight < minRangeTrans)
  {
    yInterceptHeight = minRangeTrans;
  }
  double tempSpan = maximumScore - yIntercept;
  double tempFactor = (double)(scaleToUse - yInterceptHeight) / tempSpan;
  double negativeTempSpan = yIntercept - minimumScore;
  double negativeTempFactor = (double)((scaleToUse) - (scaleToUse - yInterceptHeight)) / negativeTempSpan;
  int negativeHeight = 0;
  if(useLog)
  {
    if(minValToSkip >= 0.0)
      minValToSkip = log10(minValToSkip) ;
    else
      minValToSkip = 0.0 ;

    if(maxValToSkip >= 0.0)
      maxValToSkip = log10(maxValToSkip) ;
    else
      maxValToSkip = 0.0 ;
  }
  // Go through all the pixels and draw them
  for (i = 0; i < numberOfPixels; i++)
  {
    annotationColor = allocatedColor;

    start = labelWidthGlobalForDrawingFunction + i;

    if(windowingMethod == 0)
    {
      temporaryScore = pixelValueForHDT[i] / pixelExtraValues[i];
      negativeTemporaryScore = pixelNegativeValueForHDT[i] / pixelExtraNegativeValues[i];
    }
    else
    {
      temporaryScore = pixelValueForHDT[i];
      negativeTemporaryScore = pixelNegativeValueForHDT[i];
    }

    if(useLog)
    {
      if(!isnan(temporaryScore) || !isinf(temporaryScore))
      {
        temporaryScore = log10(temporaryScore);
      }
      else
      {
        temporaryScore = 0.0;
      }
      if(!isnan(negativeTemporaryScore) || !isinf(negativeTemporaryScore))
      {
        negativeTemporaryScore = log10(negativeTemporaryScore);
      }
      else
      {
        negativeTemporaryScore = 0.0;
      }
    }

    if(temporaryScore >= yIntercept && temporaryScore <= maximumScore && temporaryScore != minValToSkip
      && temporaryScore != maxValToSkip)
    {
      if(useLog)
      {
        height = (long)round((temporaryScore - yIntercept) * tempFactor);
      }
      else
      {
        height = (long)ceil((temporaryScore - yIntercept) * tempFactor);
      }
    }
    else
    {
      height = 0;
    }
    if(negativeTemporaryScore >= minimumScore && negativeTemporaryScore <= yIntercept && negativeTemporaryScore != minValToSkip
      && negativeTemporaryScore != maxValToSkip)
    {
      if(useLog)
      {
        negativeHeight = (long)round((yIntercept - negativeTemporaryScore) * negativeTempFactor);
      }
      else
      {
        negativeHeight = (long)ceil((yIntercept - negativeTemporaryScore) * negativeTempFactor);
      }
    }
    else
    {
      negativeHeight = 0;
    }
    if(visibility == VIS_FULL || visibility == VIS_DENSE || visibility == VIS_FULLNAME || visibility == VIS_FULLTEXT)
    {
      colorPointer = annotationColor;
      negativeColorPointer = negativeColor;
    }
    else
    {
      colorPointer = multicolor[csel];
      negativeColorPointer = multicolor[csel];
    }
    if(useLog){
      // For windowingMethod = MAAX or MIN
      if(windowingMethod == 1 || windowingMethod == 2){
        // Set color according to pixel value (if required). (For 'up' values)
        if(localHDInfo->gbTrackPxScoreUpperThresholdColor != NULL && localHDInfo->gbTrackPxScoreUpperThreshold != (gdouble)-4290772992.0 && log10(pixelValueForHDT[i]) >= logUpperPxValue){
          colorPointer = allocatedUpperColor;
        }
        else if(localHDInfo->gbTrackPxScoreLowerThresholdColor != NULL && localHDInfo->gbTrackPxScoreLowerThreshold != (gdouble)4290772992.0 && log10(pixelValueForHDT[i]) <= logLowerPxValue){
          colorPointer = allocatedLowerColor;
        }
        // Set color according to pixel value (if required). (For 'down' values)
        if(localHDInfo->gbTrackPxScoreUpperNegativeThresholdColor != NULL && localHDInfo->gbTrackPxScoreUpperNegativeThreshold != (gdouble)-4290772992.0 && log10(pixelNegativeValueForHDT[i]) >= logUpperNegativePxValue){
          negativeColorPointer = allocatedUpperNegativeColor;
        }
        else if(localHDInfo->gbTrackPxScoreLowerNegativeThresholdColor != NULL && localHDInfo->gbTrackPxScoreLowerNegativeThreshold != (gdouble)4290772992.0 && log10(pixelNegativeValueForHDT[i]) <= logLowerNegativePxValue){
          negativeColorPointer = allocatedLowerNegativeColor;
        }
      }
      else if(windowingMethod == 0){
        // For 'up' values
        if(localHDInfo->gbTrackPxScoreUpperThresholdColor != NULL && localHDInfo->gbTrackPxScoreUpperThreshold != (gdouble)-4290772992.0 && log10(pixelValueForHDT[i] / pixelExtraValues[i]) >= logUpperPxValue){
          colorPointer = allocatedUpperColor;
        }
        else if(localHDInfo->gbTrackPxScoreLowerThresholdColor != NULL && localHDInfo->gbTrackPxScoreLowerThreshold != (gdouble)4290772992.0 && log10(pixelValueForHDT[i] / pixelExtraValues[i]) <= logLowerPxValue){
          colorPointer = allocatedLowerColor;
        }
        // For 'down' values
        if(localHDInfo->gbTrackPxScoreUpperNegativeThresholdColor != NULL && localHDInfo->gbTrackPxScoreUpperNegativeThreshold != (gdouble)-4290772992.0 && log10(pixelNegativeValueForHDT[i] / pixelExtraNegativeValues[i]) >= logUpperNegativePxValue){
          negativeColorPointer = allocatedUpperNegativeColor;
        }
        else if(localHDInfo->gbTrackPxScoreLowerNegativeThresholdColor != NULL && localHDInfo->gbTrackPxScoreLowerNegativeThreshold != (gdouble)4290772992.0 && log10(pixelNegativeValueForHDT[i] / pixelExtraNegativeValues[i]) <= logLowerNegativePxValue){
          negativeColorPointer = allocatedLowerNegativeColor;
        }
      }
    }
    else{
      // For Windowing Method = MAX or MIN
      if(windowingMethod == 1 || windowingMethod == 2){
        // For 'up' values
        if(localHDInfo->gbTrackPxScoreUpperThresholdColor != NULL && localHDInfo->gbTrackPxScoreUpperThreshold != (gdouble)-4290772992.0 && pixelValueForHDT[i] >= upperPxValue){
          colorPointer = allocatedUpperColor;
        }
        else if(localHDInfo->gbTrackPxScoreLowerThresholdColor != NULL && localHDInfo->gbTrackPxScoreLowerThreshold != (gdouble)4290772992.0 && pixelValueForHDT[i] <= lowerPxValue){
          colorPointer = allocatedLowerColor;
        }
        // For 'down' values
        if(localHDInfo->gbTrackPxScoreUpperNegativeThresholdColor != NULL && localHDInfo->gbTrackPxScoreUpperNegativeThreshold != (gdouble)-4290772992.0 && pixelNegativeValueForHDT[i] >= upperNegativePxValue){
          negativeColorPointer = allocatedUpperNegativeColor;
        }
        else if(localHDInfo->gbTrackPxScoreLowerNegativeThresholdColor != NULL && localHDInfo->gbTrackPxScoreLowerNegativeThreshold != (gdouble)4290772992.0 && pixelNegativeValueForHDT[i] <= lowerNegativePxValue){
          negativeColorPointer = allocatedLowerNegativeColor;
        }
      }
      // For windowing method = AVG
      else if(windowingMethod == 0){
        // For 'up' values
        if(localHDInfo->gbTrackPxScoreUpperThresholdColor != NULL && localHDInfo->gbTrackPxScoreUpperThreshold != (gdouble)-4290772992.0 && (gdouble)(pixelValueForHDT[i] / pixelExtraValues[i]) >= upperPxValue){
          colorPointer = allocatedUpperColor;
        }
        else if(localHDInfo->gbTrackPxScoreLowerThresholdColor != NULL && localHDInfo->gbTrackPxScoreLowerThreshold != (gdouble)4290772992.0 && (gdouble)(pixelValueForHDT[i] / pixelExtraValues[i]) <= lowerPxValue){
          colorPointer = allocatedLowerColor;
        }
        // For 'down' values
        if(localHDInfo->gbTrackPxScoreUpperNegativeThresholdColor != NULL && localHDInfo->gbTrackPxScoreUpperNegativeThreshold != (gdouble)-4290772992.0 && (gdouble)(pixelNegativeValueForHDT[i] / pixelExtraNegativeValues[i]) >= upperNegativePxValue){
          negativeColorPointer = allocatedUpperNegativeColor;
        }
        else if(localHDInfo->gbTrackPxScoreLowerNegativeThresholdColor != NULL && localHDInfo->gbTrackPxScoreLowerNegativeThreshold != (gdouble)4290772992.0 && (gdouble)(pixelNegativeValueForHDT[i] / pixelExtraNegativeValues[i]) <= lowerNegativePxValue){
          negativeColorPointer = allocatedLowerNegativeColor;
        }
      }
    }
    y1 = (initialHeight + scaleToUse) - (yInterceptHeight + height);
    y2 = y1 + height;
    // draw up values
    gdImageLine(im, start, y1, start, y2, colorPointer);
    y1 = (initialHeight + scaleToUse) - yInterceptHeight;
    // draw down values
    gdImageLine(im, start, y1, start, y1 + negativeHeight, negativeColorPointer);
  }
  gdImageRectangle(im, labelWidthGlobalForDrawingFunction + 1, initialHeight, totalWidthGlobalForDrawingFunction,
                   (initialHeight + scaleToUse), black);

  // draw labels
  char yScoreStr[255] = "";
  int lengthOfYScoreStr = 0;
  int widthOfYBox = 0;
  int heightOfBox = 0;
  int yLabelStart = 0;
  int trackHeight = scaleToUse;
  char maxScoreStr[255] = "";
  char minScoreStr[255] = "";
  int lengthOfMaxScoreStr = 0;
  int lengthOfMinScoreStr = 0;
  int widthOfMaxBox = 0;
  int widthOfMinBox = 0;
  int maxLabelStart = 0;
  int minLabelStart = 0;
  gdFontPtr font = gdFontTiny;
  int minimumHeight = 0;
  char log[] = " LOG ";
  int lengthLog = strlen(log) * font->w;
  // lables
  if(abs(maximumScore) < 10 && abs(maximumScore) >= 0)
  {
    sprintf(maxScoreStr, "%.4f", maximumScore);
  }
  else if(abs(maximumScore) < 100 && abs(maximumScore) >= 10)
  {
    sprintf(maxScoreStr, "%.3f", maximumScore);
  }
  else if(abs(maximumScore) < 1000 && abs(maximumScore) >= 100)
  {
    sprintf(maxScoreStr, "%.2f", maximumScore);
  }
  else if(abs(maximumScore) < 10000 && abs(maximumScore) >= 1000)
  {
    sprintf(maxScoreStr, "%.1f", maximumScore);
  }
  else
  {
    sprintf(maxScoreStr, "%.5g", maximumScore);
  }
  if(useLog)
  {
     strcat(maxScoreStr, log);
  }
  lengthOfMaxScoreStr = strlen(maxScoreStr);
  sprintf(minScoreStr, "%.3f", minimumScore);
  lengthOfMinScoreStr = strlen(minScoreStr);
  widthOfMaxBox = (lengthOfMaxScoreStr * font->w) + labelWidthGlobalForDrawingFunction + 4;
  widthOfMinBox = (lengthOfMinScoreStr * font->w) + labelWidthGlobalForDrawingFunction + 4;
  heightOfBox = font->h + 4;
  maxLabelStart = labelWidthGlobalForDrawingFunction + 3;
  minLabelStart = maxLabelStart;
  sprintf(yScoreStr, "%.3f", yIntercept);
  lengthOfYScoreStr = strlen(yScoreStr);
  widthOfYBox = (lengthOfYScoreStr * font->w) + labelWidthGlobalForDrawingFunction + 4;
  yLabelStart = labelWidthGlobalForDrawingFunction + 3;
  minimumHeight = (heightOfBox * 2) + 2;
  if(scaleToUse < minimumHeight){
      return;
  }
  // draw max label if label box can be fit inside the rectangle
  if((initialHeight + heightOfBox) < (initialHeight + scaleToUse))
  {
    gdImageFilledRectangle(im, labelWidthGlobalForDrawingFunction + 1, initialHeight, widthOfMaxBox,
                         initialHeight + heightOfBox, white);
    gdImageRectangle(im, labelWidthGlobalForDrawingFunction + 1, initialHeight, widthOfMaxBox,
                   initialHeight + heightOfBox, blue);
    gdImageString(im, font, maxLabelStart, initialHeight + (font->h / 2), (unsigned char *)maxScoreStr, black);
  }

  // draw min label if does not clash with max label
  if((initialHeight + heightOfBox) < (initialHeight + 1 + scaleToUse - heightOfBox))
  {
    gdImageFilledRectangle(im, labelWidthGlobalForDrawingFunction + 1, (initialHeight + 1 + trackHeight - heightOfBox),
                         widthOfMinBox, initialHeight + trackHeight, white);
    gdImageRectangle(im, labelWidthGlobalForDrawingFunction + 1, (initialHeight + 1 + trackHeight - heightOfBox),
                   widthOfMinBox, initialHeight + trackHeight, blue);
    gdImageString(im, font, minLabelStart, (initialHeight + trackHeight - font->h), (unsigned char *)minScoreStr, black);
  }
  if(yIntercept < maximumScore && yIntercept > minimumScore)
  {
    // draw y intercept
    if(((initialHeight + scaleToUse) - yInterceptHeight) <= (initialHeight + heightOfBox))
    {
      gdImageLine(im, widthOfMaxBox, (initialHeight + scaleToUse) - yInterceptHeight, totalWidthGlobalForDrawingFunction, (initialHeight + scaleToUse) - yInterceptHeight, black);
    }
    else if(((initialHeight + scaleToUse) - yInterceptHeight) >= (initialHeight + 1 + scaleToUse - heightOfBox))
    {
      gdImageLine(im, widthOfMinBox, (initialHeight + scaleToUse) - yInterceptHeight, totalWidthGlobalForDrawingFunction, (initialHeight + scaleToUse) - yInterceptHeight, black);
    }
    else{
      gdImageLine(im, labelWidthGlobalForDrawingFunction +1, (initialHeight + scaleToUse) - yInterceptHeight, totalWidthGlobalForDrawingFunction, (initialHeight + scaleToUse) - yInterceptHeight, black);
    }
    // draw y label if doesn't clash woth either min or max labels
    if(((initialHeight + scaleToUse) - (yInterceptHeight + heightOfBox) > initialHeight + heightOfBox) && ((initialHeight + scaleToUse) - (yInterceptHeight) < (initialHeight + 1 + scaleToUse - heightOfBox)))
    {
      gdImageFilledRectangle(im, labelWidthGlobalForDrawingFunction + 1, (initialHeight + scaleToUse) - (yInterceptHeight + heightOfBox), widthOfYBox,
                           (initialHeight + scaleToUse) - (yInterceptHeight), white);
      gdImageRectangle(im, labelWidthGlobalForDrawingFunction + 1, (initialHeight + scaleToUse) - (yInterceptHeight + heightOfBox), widthOfYBox,
                    (initialHeight + scaleToUse) - (yInterceptHeight), blue);
      gdImageString(im, font, yLabelStart, (initialHeight + scaleToUse) - (yInterceptHeight + font->h), (unsigned char *)yScoreStr, black);
    }
  }
  return;
}


void bidirectional_drawGD_nonHighDensityTracks(gdImagePtr im, myTrack *localTrack, int visibility, int *multicolor, int initialHeight, int theHeight, int allocatedColor, float maxScore, float minScore, int allocatedUpperColor, int allocatedLowerColor, int negativeColor, int allocatedUpperNegativeColor, int allocatedLowerNegativeColor, myGroup *theGroup){
  int csel = 0;
  int y1 = 0;
  int y2 = 0;
  int i = 0;
  int start = 0, annotationStart = 0;
  int end = 0, annotationEnd = 0;
  int width = 0;
  int black = 0;
  int white = 0;
  int blue = 0;
  int colorPointer = 0;
  float thickness = 0.4;
  float thick = 0;
  int levelSize = 210;
  int *theLevels;
  int level = 0;
  int maxlevel = 0;
  gdouble temporaryScore = 0.0, negativeTemporaryScore = 0.0;
  float normalized = 0.0;
  float height = theHeight;
  myAnnotations *currentAnnotation = NULL;
  myGroup *currentGroup = theGroup;
  char maxScoreStr[255] = "";
  char minScoreStr[255] = "";
  int lengthOfMaxScoreStr = 0;
  int lengthOfMinScoreStr = 0;
  gdFontPtr font = gdFontTiny;
  int widthOfMaxBox = 0;
  int widthOfMinBox = 0;
  int heightOfBox = 0;
  int maxLabelStart = 0;
  int minLabelStart = 0;
  int annotationColor = 0;
  float span = 0.0;
  black = gdImageColorResolve(im, 0, 0, 0);
  white = gdImageColorResolve(im, 215, 215, 215);
  blue = gdImageColorResolve(im, 0, 0, 180);
  long j;
  span = fabs(maxScore) + fabs(minScore);
  int scaleToUse = 0;
  // This part has been copied from the high density track drawing.
  // Some of the variables have the same names as those for high density track drawing.
  int lengthOfTrackInPixels = canvasWidthGlobalForDrawingFunction + 2;
  highDensFtypes *localHDInfo = localTrack->highDensFtypes;
  int windowingMethod = (int)localHDInfo->gbTrackWindowingMethod;
  int draw0 ;
  if(strcmp(localHDInfo->gbTrackZeroDraw, "true") == 0)
    draw0 = 1 ;
  else
    draw0 = 0 ;
  int zoomLevelsPresent = 0;
  gdouble *tempPixelArray = NULL;
  gdouble *tempExtraValues = NULL;
  gdouble *tempNegPixelArray = NULL;
  if(localTrack->pixelValueForHDT == NULL && localTrack->pixelNegativeValueForHDT == NULL)
  {
    localTrack->pixelValueForHDT = (gdouble *) calloc(lengthOfTrackInPixels, sizeof(gdouble));
    localTrack->pixelExtraValues = (gdouble *) calloc(lengthOfTrackInPixels, sizeof(gdouble));
    localTrack->pixelNegativeValueForHDT = (gdouble *) calloc(lengthOfTrackInPixels, sizeof(gdouble));
    localTrack->pixelExtraNegativeValues = (gdouble *) calloc(lengthOfTrackInPixels, sizeof(gdouble));
    tempPixelArray = (gdouble *) calloc(lengthOfTrackInPixels, sizeof(gdouble));
    tempExtraValues = (gdouble *) calloc(lengthOfTrackInPixels, sizeof(gdouble));
    tempNegPixelArray = (gdouble *)calloc(lengthOfTrackInPixels, sizeof(gdouble));
    // Set pixel array to minScore - 1
    for(i = 0; i < lengthOfTrackInPixels; i++){
      localTrack->pixelValueForHDT[i] = (gdouble)(minScore - 1.00);
      localTrack->pixelNegativeValueForHDT[i] = (gdouble)(maxScore + 1.00);
      tempPixelArray[i] = (gdouble)(minScore - 1.00);
      tempNegPixelArray[i] = (gdouble)(maxScore + 1.00);
    }
  }
  else{
    zoomLevelsPresent = 1;
  }
  long trackStart = getStartPosition();
  long trackStop = getEndPosition();
  long currentLocation = 0, numberOfBasesToProcess = 0, numberOfBasesProcessed = 0;
  long firstPixel, lastPixel;
  int numberOfPixels = canvasWidthGlobalForDrawingFunction;
  int canvasSize = canvasWidthGlobalForDrawingFunction;
  int locationToUpdate;
  gdouble bpPerPixel = (gdouble) lengthOfSegmentGlobalForDrawingFunction / (gdouble) canvasWidthGlobalForDrawingFunction;
  gdouble pixelsPerBase = universalScaleGlobalForDrawingFunction;
  char *theStyle = localTrack->style;
  gdouble upperPxValue = localHDInfo->gbTrackPxScoreUpperThreshold;
  gdouble lowerPxValue = localHDInfo->gbTrackPxScoreLowerThreshold;
  gdouble upperNegativePxValue = localHDInfo->gbTrackPxScoreUpperNegativeThreshold;
  gdouble lowerNegativePxValue = localHDInfo->gbTrackPxScoreLowerNegativeThreshold;
  int partitioningReq ;
  if(localHDInfo->gbTrackPartitioning == NULL)
  {
    partitioningReq = 0;
  }
  else if(strcasecmp(localHDInfo->gbTrackPartitioning, "false") == 0)
  {
    partitioningReq = 0;
  }
  else if(strcasecmp(localHDInfo->gbTrackPartitioning, "true") == 0)
  {
    partitioningReq = 1;
  }
  else
  {
    partitioningReq = 0;
  }
  gdouble logUpperPxValue, logLowerPxValue;
  gdouble logUpperNegativePxValue, logLowerNegativePxValue;
  gdouble yIntercept = localHDInfo->gbTrackYIntercept;
  long maxRangeTrans = 0;
  long minRangeTrans = 0;
  gdouble valueToAddToMinimum = 0.0;
  int useLocalScore = 0;
  gdouble factor = 0.0;

  gdouble *pixelValueForTrack = localTrack->pixelValueForHDT;
  gdouble *pixelExtraValues = localTrack->pixelExtraValues;
  gdouble *pixelNegativeValueForTrack = localTrack->pixelNegativeValueForHDT;
  gdouble *pixelExtraNegativeValues = localTrack->pixelExtraNegativeValues;
  bool useLog = (int)localHDInfo->gbTrackUseLog;

  // Check Levels
  if((theLevels = (int *)malloc((levelSize) * sizeof(int))) == NULL)
  {
    perror("problems with theLevels");
    return;
  }
  for (i = 0; i < levelSize; i++)
  {
    theLevels[i] = i;
  }
  thick = (theHeight * thickness) / 2;
  theLevels[0] = -1;
  if(visibility == VIS_FULL || visibility == VIS_FULLNAME || visibility == VIS_FULLTEXT)
  {
    while (currentGroup)
    {
      level = currentGroup->level;
      if(level > maxlevel)
      {
        maxlevel = level;
      }
      if(theLevels[level] == level)
      {
        gdImageLine(im, labelWidthGlobalForDrawingFunction, (initialHeight + (level * TALLSCORE)),
                      totalWidthGlobalForDrawingFunction, (initialHeight + (level * TALLSCORE)), blue);
        theLevels[level] = -1;
      }
      currentGroup = currentGroup->next;
    }
  }
  maxlevel++;
  currentGroup = theGroup;
  if(zoomLevelsPresent != 1)
  {
    // Go thorugh all the records in 'fdata2' and collect all the scores to draw
    // This concept is copied from the high density track drawing
    while (currentGroup)
    {
      if(csel > 3)
      {
        csel = 0;
      }
      y1 = initialHeight + (currentGroup->level * theHeight);
      currentAnnotation = currentGroup->annotations;
      while (currentAnnotation)
      {
        if(currentAnnotation->displayColor > -1)
        {
          annotationColor = gdImageColorResolve(im, getRed(currentAnnotation->displayColor),
                            getGreen(currentAnnotation->displayColor),
                            getBlue(currentAnnotation->displayColor));
        }
        else
        {
          annotationColor = allocatedColor;
        }
        // Get start and stop for the annotation/record.
        annotationStart = currentAnnotation->start;
        annotationEnd = currentAnnotation->end;
        temporaryScore = (gdouble)currentAnnotation->score;
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
        numberOfBasesToProcess = (end - start) + 1;
        double lastPixel;
        double firstPixel;
        long lastPixelLong;
        long firstPixelLong;
        gdouble minValueToUse = (gdouble)(minScore - 1.0);
        gdouble maxValueToUse = (gdouble)(maxScore + 1.0);
        for(i = 0; i < numberOfBasesToProcess; i++){
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
          if(partitioningReq == 0)
          {
            for(j = firstPixelLong; j <= lastPixelLong; j++)
            {
              if(windowingMethod == 0)
              {
                if(tempPixelArray[j] == minValueToUse)
                {
                  tempPixelArray[j] = temporaryScore;
                }
                else
                {
                  tempPixelArray[j] += temporaryScore;
                }
                tempExtraValues[j] += 1.0;
              }
              else if(windowingMethod == 1)
              {
                if(temporaryScore > tempPixelArray[j])
                {
                  tempPixelArray[j] = temporaryScore;
                }
                if(temporaryScore < tempNegPixelArray[j])
                {
                  tempNegPixelArray[j] = temporaryScore;
                }
              }
              else if(windowingMethod == 2)
              {
                if(tempPixelArray[j] == minValueToUse)
                {
                  tempPixelArray[j] = temporaryScore;
                }
                else
                {
                  if(temporaryScore < tempPixelArray[j])
                  {
                    tempPixelArray[j] = temporaryScore;
                  }
                }
                if(tempNegPixelArray[j] == maxValueToUse)
                {
                  tempNegPixelArray[j] = temporaryScore;
                }
                else
                {
                  if(temporaryScore > tempNegPixelArray[j])
                  {
                    tempNegPixelArray[j] = temporaryScore;
                  }
                }
              }
            }
          }
          else
          {
            if(temporaryScore > yIntercept){
              for (j = firstPixelLong; j <= lastPixelLong; j++){
                if(windowingMethod == 0)
                {
                  if(pixelValueForTrack[j] == minValueToUse)
                  {
                    pixelValueForTrack[j] = temporaryScore;
                  }
                  else
                  {
                    pixelValueForTrack[j] += temporaryScore;
                  }
                  pixelExtraValues[j] += 1.0;
                }
                else if(windowingMethod == 1)
                {
                  if(temporaryScore > pixelValueForTrack[j]){
                    pixelValueForTrack[j] = temporaryScore;
                  }
                }
                else if(windowingMethod == 2)
                {
                  if(temporaryScore < pixelValueForTrack[j]){
                    pixelValueForTrack[j] = temporaryScore;
                  }
                }
              }
            }
            else if(temporaryScore < yIntercept){
              for (j = firstPixelLong; j <= lastPixelLong; j++){
                if(windowingMethod == 0)
                {
                  if(pixelNegativeValueForTrack[j] == maxValueToUse)
                  {
                    pixelNegativeValueForTrack[j] = temporaryScore;
                  }
                  else
                  {
                    pixelNegativeValueForTrack[j] += temporaryScore;
                  }
                  pixelExtraNegativeValues[j] += 1.0;
                }
                // for windowing method max, min will be actually max for values below the y intercept
                else if(windowingMethod == 1)
                {
                  if(temporaryScore < pixelNegativeValueForTrack[j]){
                    pixelNegativeValueForTrack[j] = temporaryScore;
                  }
                }
                // for windowing method min, max will be actually min for value below the y intercept
                else if(windowingMethod == 2)
                {
                  if(pixelNegativeValueForTrack[j] == maxValueToUse)
                  {
                    pixelNegativeValueForTrack[j] = temporaryScore;
                  }
                  else
                  {
                    if(temporaryScore > pixelNegativeValueForTrack[j]){
                      pixelNegativeValueForTrack[j] = temporaryScore;
                    }
                  }
                }
              }
            }
          }
          currentLocation ++;
        }

        currentAnnotation = currentAnnotation->next;
      }
      csel++;
      currentGroup = currentGroup->next;
    }
  }
  if(zoomLevelsPresent != 1 && partitioningReq == 0)
  {
    if(windowingMethod == 0)
    {
      for(j = 0; j < lengthOfTrackInPixels; j++)
      {
        if((gdouble)(tempPixelArray[j] / tempExtraValues[j]) > 0.0) // since y intercept is now fixed to 0
        {
          pixelValueForTrack[j] = tempPixelArray[j];
          pixelExtraValues[j] = tempExtraValues[j];
        }
        else if((gdouble)(tempPixelArray[j] / tempExtraValues[j]) < 0.0)
        {
          pixelNegativeValueForTrack[j] = tempPixelArray[j];
          pixelExtraNegativeValues[j] = tempExtraValues[j];
        }
      }
    }
    else if(windowingMethod == 1)
    {
      for(j = 0; j < lengthOfTrackInPixels; j++)
      {
        if(tempPixelArray[j] > yIntercept)
        {
          if(tempPixelArray[j] > pixelValueForTrack[j])
          {
            pixelValueForTrack[j] = tempPixelArray[j];
          }
        }
        if(tempNegPixelArray[j] < yIntercept)
        {
          if(tempNegPixelArray[j] < pixelNegativeValueForTrack[j])
          {
            pixelNegativeValueForTrack[j] = tempNegPixelArray[j];
          }
        }
      }
    }
    else if(windowingMethod == 2)
    {
      if(tempPixelArray[j] > yIntercept)
      {
        if(pixelValueForTrack[j] == minScore - 1.0)
        {
          pixelValueForTrack[j] = tempPixelArray[j];
        }
        else
        {
          if(tempPixelArray[j] < pixelValueForTrack[j])
          {
            pixelValueForTrack[j] = tempPixelArray[j];
          }
        }
      }
      if(tempNegPixelArray[j] < yIntercept)
      {
        if(pixelNegativeValueForTrack[j] == maxScore + 1.0)
        {
          pixelNegativeValueForTrack[j] = tempNegPixelArray[j];
        }
        else
        {
          if(tempNegPixelArray[j] > pixelNegativeValueForTrack[j])
          {
            pixelNegativeValueForTrack[j] = tempNegPixelArray[j];
          }
        }
      }
    }
  }
  // Now draw the collected pixel values
  // Check if the drawing style is 'local'
  if(strcasecmp(theStyle, "bidirectional_local_draw_large") == 0)
  {
    useLocalScore = 1;
  }
  gdouble minimumScore, maximumScore;
  gdouble maximumLocal, minimumLocal;
  // Check if log scaling is required
  if(useLog)
  {
    minimumLocal = log10(maxScore);
    maximumLocal = log10(minScore);
  }
  else
  {
    maximumLocal = minScore;
    minimumLocal = maxScore;
  }
  scaleToUse = localHDInfo->gbTrackPxHeight;
  gdouble minValToSkip = minScore - 1.0 ;
  gdouble maxValToSkip = maxScore + 1.0 ;
  // For local score barchart
  temporaryScore = 0.0;
  if(useLocalScore)
  {
    for (i = 0; i < numberOfPixels; i++)
    {
      temporaryScore = 0.0;
      negativeTemporaryScore = 0.0;
      if(windowingMethod == 0)
      {
        if(pixelValueForTrack[i] >= minScore)
          temporaryScore = pixelValueForTrack[i] / pixelExtraValues[i];
        else
          temporaryScore = minValToSkip ;
        if(pixelNegativeValueForTrack[i] <= maxScore)
          negativeTemporaryScore = pixelNegativeValueForTrack[i] / pixelExtraNegativeValues[i];
        else
          negativeTemporaryScore = minValToSkip ;
      }
      else
      {
        if(pixelValueForTrack[i] >= minScore)
          temporaryScore = pixelValueForTrack[i];
        else
          temporaryScore = minValToSkip ;
        if(pixelNegativeValueForTrack[i] <= maxScore)
          negativeTemporaryScore = pixelNegativeValueForTrack[i];
        else
          negativeTemporaryScore = minValToSkip ;
      }
      if(useLog)
      {
        // For 'up' values
        if(!isnan(temporaryScore) && !isinf(temporaryScore) && temporaryScore > 0.0)
          temporaryScore = log10(temporaryScore) ;
        else
          temporaryScore = 0.0 ;
        // For 'down' values
        if(!isnan(negativeTemporaryScore) && !isinf(negativeTemporaryScore) && negativeTemporaryScore > 0.0)
          negativeTemporaryScore = log10(negativeTemporaryScore) ;
        else
          negativeTemporaryScore = 0.0;
      }
      if(!isnan(temporaryScore) && !isinf(temporaryScore))
      {
        // For 'up' values
        if(temporaryScore != minValToSkip)
        {
          if(temporaryScore > maximumLocal)
          {
            maximumLocal = temporaryScore;
          }
          else if(temporaryScore < minimumLocal)
          {
            minimumLocal = temporaryScore;
          }
        }
        // For 'down' values
        if(negativeTemporaryScore != minValToSkip)
        {
          if(negativeTemporaryScore > maximumLocal)
          {
            maximumLocal = negativeTemporaryScore;
          }
          else if(negativeTemporaryScore < minimumLocal)
          {
            minimumLocal = negativeTemporaryScore;
          }
        }
      }
      else
      {
        fprintf(stderr, "Error during hdhv drawing. The 'up': %lf and 'down': %lf are not numbers.\n", temporaryScore, negativeTemporaryScore);
      }
    }
  }

  if(useLocalScore && !useLog)
  {
    maximumScore = maximumLocal;
    minimumScore = minimumLocal;
  }
  else if(useLocalScore && useLog)
  {
    maximumScore = maximumLocal ;
    minimumScore = minimumLocal ;
    // for 'up' values
    if(upperPxValue != (gdouble)-4290772992.0){
      logUpperPxValue = log10(upperPxValue);
    }
    if(lowerPxValue != (gdouble)4290772992){
      logLowerPxValue = log10(lowerPxValue);
    }
    // for 'down' values
    if(upperNegativePxValue != (gdouble)-4290772992.0){
      logUpperNegativePxValue = log10(upperNegativePxValue);
    }
    if(lowerNegativePxValue != (gdouble)4290772992.0){
      logLowerNegativePxValue = log10(lowerNegativePxValue);
    }
  }
  else if(!useLocalScore)
  {
    maximumScore = maxScore;
    minimumScore = minScore;
  }
  // Set log related stuff
  if(useLog && !useLocalScore)
  {
    if(maximumScore >= 0.0)
    {
      maximumScore = log10(maximumScore);
    }
    else
    {
      maximumScore = 0;
    }
    if(minimumScore >= 0.0)
    {
      minimumScore = log10(minimumScore);
    }
    else
    {
      minimumScore = 0;
    }
    if(upperPxValue != (gdouble)-4290772992.0){
      logUpperPxValue = log10(upperPxValue);
    }
    if(lowerPxValue != (gdouble)4290772992){
      logLowerPxValue = log10(lowerPxValue);
    }
    if(upperNegativePxValue != (gdouble)-4290772992.0){
      logUpperNegativePxValue = log10(upperNegativePxValue);
    }
    if(lowerNegativePxValue != (gdouble)4290772992.0){
      logLowerNegativePxValue = log10(lowerNegativePxValue);
    }
  }
  if(minimumScore > maximumScore)
  {
    gdouble tempValue = maximumScore;
    maximumScore = minimumScore;
    minimumScore = tempValue;
    // do not use 'real' scaling
    if(draw0 == 1)
    {
      if(maximumScore >= 0.0 && minimumScore >= 0.0)
      {
        minimumScore = 0.0 ;
        maximumScore = maximumScore ;
      }
      else if(maximumScore <= 0.0 && minimumScore <= 0.0)
      {
        maximumScore = 0.0 ;
        minimumScore = minimumScore ;
      }
      else
      {
        maximumScore = maximumScore ;
        minimumScore = minimumScore ;
      }
    }
  }
  else if(minimumScore == maximumScore)
  {
    if(minimumScore > 0)
    {
      minimumScore = 0.0;
    }
    else if(minimumScore < 0)
    {
      maximumScore = 0.0;
    }
  }
  else
  {
    // do not use 'real' scaling
    if(draw0 == 1)
    {
      if(maximumScore >= 0.0 && minimumScore >= 0.0)
      {
        minimumScore = 0.0 ;
        maximumScore = maximumScore ;
      }
      else if(maximumScore <= 0.0 && minimumScore <= 0.0)
      {
        maximumScore = 0.0 ;
        minimumScore = minimumScore ;
      }
      else
      {
        maximumScore = maximumScore ;
        minimumScore = minimumScore ;
      }
    }
  }


  black = gdImageColorResolve(im, 0, 0, 0);
  white = gdImageColorResolve(im, 255, 255, 255);
  blue = gdImageColorResolve(im, 0, 0, 180);
  span = maximumScore - minimumScore;
  factor = (double)scaleToUse / span;
  y1 = initialHeight + theHeight;
  if(useLog)
  {
    maxRangeTrans = (long)round((maximumScore - minimumScore) * factor);
  }
  else
  {
    maxRangeTrans = (long)ceil((maximumScore - minimumScore) * factor);
  }
  minRangeTrans = -1;
  valueToAddToMinimum = span * factorToDrawPixelsWithBackground;

  // Set the height for the y intercept
  int yInterceptHeight = 0;
  if(useLog)
    yInterceptHeight = (long)round((yIntercept - minimumScore) * factor);
  else
    yInterceptHeight = (long)ceil((yIntercept - minimumScore) * factor);


  if(yInterceptHeight > maxRangeTrans)
    yInterceptHeight = maxRangeTrans;


  if(yInterceptHeight < minRangeTrans)
    yInterceptHeight = minRangeTrans;

  double tempSpan = maximumScore - yIntercept;
  double tempFactor = (double)(scaleToUse - yInterceptHeight) / tempSpan;
  double negativeTempSpan = yIntercept - minimumScore;
  double negativeTempFactor = (double)((scaleToUse) - (scaleToUse - yInterceptHeight)) / negativeTempSpan;
  int negativeHeight = 0, negativeColorPointer;
  if(useLog)
  {
    if(minValToSkip >= 0.0)
      minValToSkip = log10(minValToSkip) ;
    else
      minValToSkip = 0.0 ;

    if(maxValToSkip >= 0.0)
      maxValToSkip = log10(maxValToSkip) ;
    else
      maxValToSkip = 0.0 ;
  }
  for (i = 0; i < numberOfPixels; i++)
  {
    annotationColor = allocatedColor;
    start = labelWidthGlobalForDrawingFunction + i;
    // Check windowing method: MAX, AVG or MIN
    if(windowingMethod == 0)
    {
      temporaryScore = pixelValueForTrack[i] / pixelExtraValues[i];
      negativeTemporaryScore = pixelNegativeValueForTrack[i] / pixelExtraNegativeValues[i];
    }
    else
    {
      temporaryScore = pixelValueForTrack[i];
      negativeTemporaryScore = pixelNegativeValueForTrack[i];
    }
    if(useLog)
    {
      // For 'up' values
      if(!isnan(temporaryScore) || !isinf(temporaryScore))
      {
        temporaryScore = log10(temporaryScore);
      }
      else
      {
        temporaryScore = 0.0;
      }
      // For 'down' values
      if(!isnan(negativeTemporaryScore) || !isinf(negativeTemporaryScore))
      {
        negativeTemporaryScore = log10(negativeTemporaryScore);
      }
      else
      {
        negativeTemporaryScore = 0.0;
      }
    }
    if(temporaryScore >= yIntercept && temporaryScore <= maximumScore
       && temporaryScore != minValToSkip && temporaryScore != maxValToSkip)
    {
      if(useLog)
      {
        height = (long)round((temporaryScore - yIntercept) * tempFactor);
      }
      else
      {
        height = (long)ceil((temporaryScore - yIntercept) * tempFactor);
      }
    }
    else
    {
      height = 0;
    }
    if(negativeTemporaryScore >= minimumScore && negativeTemporaryScore <= yIntercept
       && negativeTemporaryScore != minValToSkip && negativeTemporaryScore != maxValToSkip)
    {
      if(useLog)
      {
        negativeHeight = (long)round((yIntercept - negativeTemporaryScore) * negativeTempFactor);
      }
      else
      {
        negativeHeight = (long)ceil((yIntercept - negativeTemporaryScore) * negativeTempFactor);
      }
    }
    else
    {
      negativeHeight = 0;
    }
    if(visibility == VIS_FULL || visibility == VIS_DENSE || visibility == VIS_FULLNAME || visibility == VIS_FULLTEXT)
    {
      colorPointer = annotationColor;
      negativeColorPointer = negativeColor;
    }
    else
    {
      colorPointer = multicolor[csel];
      negativeColorPointer = multicolor[csel];
    }
    if(useLog){
      // For windowingMethod = MAX or MIN
      if(windowingMethod == 1 || windowingMethod == 2){
        // Set color according to pixel value (if required)
        // For 'up' values
        if(localHDInfo->gbTrackPxScoreUpperThresholdColor != NULL && localHDInfo->gbTrackPxScoreUpperThreshold != (gdouble)-4290772992.0 && log10(pixelValueForTrack[i]) >= logUpperPxValue){
          colorPointer = allocatedUpperColor;
        }
        else if(localHDInfo->gbTrackPxScoreLowerThresholdColor != NULL && localHDInfo->gbTrackPxScoreLowerThreshold != (gdouble)4290772992.0 && log10(pixelValueForTrack[i]) <= logLowerPxValue){
          colorPointer = allocatedLowerColor;
        }
        // For 'down' values
        if(localHDInfo->gbTrackPxScoreUpperNegativeThresholdColor != NULL && localHDInfo->gbTrackPxScoreUpperNegativeThreshold != (gdouble)-4290772992.0 && log10(pixelNegativeValueForTrack[i]) >= logUpperNegativePxValue){
          negativeColorPointer = allocatedUpperNegativeColor;
        }
        else if(localHDInfo->gbTrackPxScoreLowerNegativeThresholdColor != NULL && localHDInfo->gbTrackPxScoreLowerNegativeThreshold != (gdouble)4290772992.0 && log10(pixelNegativeValueForTrack[i]) <= logLowerNegativePxValue){
          negativeColorPointer = allocatedLowerNegativeColor;
        }
      }
      else if(windowingMethod == 0){
        // For 'up' values
        if(localHDInfo->gbTrackPxScoreUpperThresholdColor != NULL && localHDInfo->gbTrackPxScoreUpperThreshold != (gdouble)-4290772992.0 && log10(pixelValueForTrack[i] / pixelExtraValues[i]) >= logUpperPxValue){
          colorPointer = allocatedUpperColor;
        }
        else if(localHDInfo->gbTrackPxScoreLowerThresholdColor != NULL && localHDInfo->gbTrackPxScoreLowerThreshold != (gdouble)4290772992.0 && log10(pixelValueForTrack[i] / pixelExtraValues[i]) <= logLowerPxValue){
          colorPointer = allocatedLowerColor;
        }
        // For 'down' values
        if(localHDInfo->gbTrackPxScoreUpperNegativeThresholdColor != NULL && localHDInfo->gbTrackPxScoreUpperNegativeThreshold != (gdouble)-4290772992.0 && log10(pixelNegativeValueForTrack[i] / pixelExtraNegativeValues[i]) >= logUpperNegativePxValue){
          negativeColorPointer = allocatedUpperNegativeColor;
        }
        else if(localHDInfo->gbTrackPxScoreLowerNegativeThresholdColor != NULL && localHDInfo->gbTrackPxScoreLowerNegativeThreshold != (gdouble)4290772992.0 && log10(pixelNegativeValueForTrack[i] / pixelExtraNegativeValues[i]) <= logLowerNegativePxValue){
          negativeColorPointer = allocatedLowerNegativeColor;
        }
      }
    }
    else{
      // For Windowing Method = MAX or MIN
      // For 'up' values
      if(windowingMethod == 1 || windowingMethod == 2){
        if(localHDInfo->gbTrackPxScoreUpperThresholdColor != NULL && localHDInfo->gbTrackPxScoreUpperThreshold != (gdouble)-4290772992.0 && pixelValueForTrack[i] >= upperPxValue){
          colorPointer = allocatedUpperColor;
        }
        else if(localHDInfo->gbTrackPxScoreLowerThresholdColor != NULL && localHDInfo->gbTrackPxScoreLowerThreshold != (gdouble)4290772992.0 && pixelValueForTrack[i] <= lowerPxValue){
          colorPointer = allocatedLowerColor;
        }
        // For 'down' values
        if(localHDInfo->gbTrackPxScoreUpperNegativeThresholdColor != NULL && localHDInfo->gbTrackPxScoreUpperNegativeThreshold != (gdouble)-4290772992.0 && pixelNegativeValueForTrack[i] >= upperNegativePxValue){
          negativeColorPointer = allocatedUpperNegativeColor;
        }
        else if(localHDInfo->gbTrackPxScoreLowerNegativeThresholdColor != NULL && localHDInfo->gbTrackPxScoreLowerNegativeThreshold != (gdouble)4290772992.0 && pixelNegativeValueForTrack[i] <= lowerNegativePxValue){
          negativeColorPointer = allocatedLowerNegativeColor;
        }
      }
      // For windowing method = AVG
      else if(windowingMethod == 0){
        // For 'up' values
        if(localHDInfo->gbTrackPxScoreUpperThresholdColor != NULL && localHDInfo->gbTrackPxScoreUpperThreshold != (gdouble)-4290772992.0 && (gdouble)(pixelValueForTrack[i] / pixelExtraValues[i]) >= upperPxValue){
          colorPointer = allocatedUpperColor;
        }
        else if(localHDInfo->gbTrackPxScoreLowerThresholdColor != NULL && localHDInfo->gbTrackPxScoreLowerThreshold != (gdouble)4290772992.0 && (gdouble)(pixelValueForTrack[i] / pixelExtraValues[i]) <= lowerPxValue){
          colorPointer = allocatedLowerColor;
        }
        // For 'down' values
        if(localHDInfo->gbTrackPxScoreUpperNegativeThresholdColor != NULL && localHDInfo->gbTrackPxScoreUpperNegativeThreshold != (gdouble)-4290772992.0 && (gdouble)(pixelNegativeValueForTrack[i] / pixelExtraNegativeValues[i]) >= upperNegativePxValue){
          negativeColorPointer = allocatedUpperNegativeColor;
        }
        else if(localHDInfo->gbTrackPxScoreLowerNegativeThresholdColor != NULL && localHDInfo->gbTrackPxScoreLowerNegativeThreshold != (gdouble)4290772992.0 && (gdouble)(pixelNegativeValueForTrack[i] / pixelExtraNegativeValues[i]) <= lowerNegativePxValue){
          negativeColorPointer = allocatedLowerNegativeColor;
        }
      }
    }
    y1 = (initialHeight + scaleToUse) - (yInterceptHeight + height);
    y2 = y1 + height;
    // draw up values
    gdImageLine(im, start, y1, start, y2, colorPointer);
    y1 = (initialHeight + scaleToUse) - yInterceptHeight;
    // draw down values
    gdImageLine(im, start, y1, start, y1 + negativeHeight, negativeColorPointer);
  }
  gdImageRectangle(im, labelWidthGlobalForDrawingFunction + 1, initialHeight, totalWidthGlobalForDrawingFunction,
      (initialHeight + scaleToUse), black);
  gdImageLine(im, labelWidthGlobalForDrawingFunction +1, (initialHeight + scaleToUse) - yInterceptHeight, totalWidthGlobalForDrawingFunction, (initialHeight + scaleToUse) - yInterceptHeight, black);

  // draw labels
  char yScoreStr[255] = "";
  int lengthOfYScoreStr = 0;
  int widthOfYBox = 0;
  int yLabelStart = 0;
  int trackHeight = scaleToUse;
  sprintf(maxScoreStr, "%.3f", maximumScore);
  sprintf(minScoreStr, "%.3f", minimumScore);
  lengthOfMaxScoreStr = strlen(maxScoreStr);
  lengthOfMinScoreStr = strlen(minScoreStr);
  widthOfMaxBox = (lengthOfMaxScoreStr * font->w) + labelWidthGlobalForDrawingFunction + 4;
  widthOfMinBox = (lengthOfMinScoreStr * font->w) + labelWidthGlobalForDrawingFunction + 4;
  heightOfBox = font->h + 4;
  maxLabelStart = labelWidthGlobalForDrawingFunction + 3;
  minLabelStart = maxLabelStart;
  int minimumHeight = 0;
  char log[] = " LOG ";
  int lengthLog = strlen(log) * font->w;
  // lables
  if(abs(maximumScore) < 10 && abs(maximumScore) >= 0)
  {
    sprintf(maxScoreStr, "%.4f", maximumScore);
  }
  else if(abs(maximumScore) < 100 && abs(maximumScore) >= 10)
  {
    sprintf(maxScoreStr, "%.3f", maximumScore);
  }
  else if(abs(maximumScore) < 1000 && abs(maximumScore) >= 100)
  {
    sprintf(maxScoreStr, "%.2f", maximumScore);
  }
  else if(abs(maximumScore) < 10000 && abs(maximumScore) >= 1000)
  {
    sprintf(maxScoreStr, "%.1f", maximumScore);
  }
  else
  {
    sprintf(maxScoreStr, "%.5g", maximumScore);
  }
  if(useLog)
  {
     strcat(maxScoreStr, log);
  }
  lengthOfMaxScoreStr = strlen(maxScoreStr);
  sprintf(minScoreStr, "%.3f", minimumScore);
  lengthOfMinScoreStr = strlen(minScoreStr);
  widthOfMaxBox = (lengthOfMaxScoreStr * font->w) + labelWidthGlobalForDrawingFunction + 4;
  widthOfMinBox = (lengthOfMinScoreStr * font->w) + labelWidthGlobalForDrawingFunction + 4;
  heightOfBox = font->h + 4;
  maxLabelStart = labelWidthGlobalForDrawingFunction + 3;
  minLabelStart = maxLabelStart;
  sprintf(yScoreStr, "%.3f", yIntercept);
  lengthOfYScoreStr = strlen(yScoreStr);
  widthOfYBox = (lengthOfYScoreStr * font->w) + labelWidthGlobalForDrawingFunction + 4;
  yLabelStart = labelWidthGlobalForDrawingFunction + 3;
  minimumHeight = (heightOfBox * 2) + 2;
  if(scaleToUse < minimumHeight){
      return;
  }
  // draw max label if label box can be fit inside the rectangle
  if((initialHeight + heightOfBox) < (initialHeight + scaleToUse))
  {
    gdImageFilledRectangle(im, labelWidthGlobalForDrawingFunction + 1, initialHeight, widthOfMaxBox,
                         initialHeight + heightOfBox, white);
    gdImageRectangle(im, labelWidthGlobalForDrawingFunction + 1, initialHeight, widthOfMaxBox,
                   initialHeight + heightOfBox, blue);
    gdImageString(im, font, maxLabelStart, initialHeight + (font->h / 2), (unsigned char *)maxScoreStr, black);
  }

  // draw min label if does not clash with max label
  if((initialHeight + heightOfBox) < (initialHeight + 1 + scaleToUse - heightOfBox))
  {
    gdImageFilledRectangle(im, labelWidthGlobalForDrawingFunction + 1, (initialHeight + 1 + trackHeight - heightOfBox),
                         widthOfMinBox, initialHeight + trackHeight, white);
    gdImageRectangle(im, labelWidthGlobalForDrawingFunction + 1, (initialHeight + 1 + trackHeight - heightOfBox),
                   widthOfMinBox, initialHeight + trackHeight, blue);
    gdImageString(im, font, minLabelStart, (initialHeight + trackHeight - font->h), (unsigned char *)minScoreStr, black);
  }
  if(yIntercept < maximumScore && yIntercept > minimumScore)
  {
    // draw y intercept
    if(((initialHeight + scaleToUse) - yInterceptHeight) <= (initialHeight + heightOfBox))
    {
      gdImageLine(im, widthOfMaxBox, (initialHeight + scaleToUse) - yInterceptHeight, totalWidthGlobalForDrawingFunction, (initialHeight + scaleToUse) - yInterceptHeight, black);
    }
    else if(((initialHeight + scaleToUse) - yInterceptHeight) >= (initialHeight + 1 + scaleToUse - heightOfBox))
    {
      gdImageLine(im, widthOfMinBox, (initialHeight + scaleToUse) - yInterceptHeight, totalWidthGlobalForDrawingFunction, (initialHeight + scaleToUse) - yInterceptHeight, black);
    }
    else{
      gdImageLine(im, labelWidthGlobalForDrawingFunction +1, (initialHeight + scaleToUse) - yInterceptHeight, totalWidthGlobalForDrawingFunction, (initialHeight + scaleToUse) - yInterceptHeight, black);
    }
    // draw y label if doesn't clash woth either min or max labels
    if(((initialHeight + scaleToUse) - (yInterceptHeight + heightOfBox) > initialHeight + heightOfBox) && ((initialHeight + scaleToUse) - (yInterceptHeight) < (initialHeight + 1 + scaleToUse - heightOfBox)))
    {
      gdImageFilledRectangle(im, labelWidthGlobalForDrawingFunction + 1, (initialHeight + scaleToUse) - (yInterceptHeight + heightOfBox), widthOfYBox,
                           (initialHeight + scaleToUse) - (yInterceptHeight), white);
      gdImageRectangle(im, labelWidthGlobalForDrawingFunction + 1, (initialHeight + scaleToUse) - (yInterceptHeight + heightOfBox), widthOfYBox,
                    (initialHeight + scaleToUse) - (yInterceptHeight), blue);
      gdImageString(im, font, yLabelStart, (initialHeight + scaleToUse) - (yInterceptHeight + font->h), (unsigned char *)yScoreStr, black);
    }

  }
  free(theLevels);
  theLevels = NULL;
  return;
}

void wigLarge_drawGD(gdImagePtr im, myTrack * localTrack, int visibility, int *multicolor, int initialHeight,
                     int theHeight, int allocatedColor, float maxScore, float minScore, int allocatedUpperColor, int allocatedLowerColor)
{
  int csel = 0;
  int y1 = 0;
  int y2 = 0;
  int i = 0;
  int start = 0;
  int black = 0;
  int white = 0;
  int blue = 0;
  int colorPointer = 0;
  gdouble temporaryScore = 0.0;
  long height = theHeight;
  highDensFtypes *localHDInfo = localTrack->highDensFtypes;
  gdouble maximumScore = localHDInfo->gbTrackDataMax;
  gdouble minimumScore = localHDInfo->gbTrackDataMin;
  gdouble upperPxValue = localHDInfo->gbTrackPxScoreUpperThreshold;
  gdouble lowerPxValue = localHDInfo->gbTrackPxScoreLowerThreshold;
  gdouble logUpperPxValue, logLowerPxValue;
  int annotationColor = 0;
  gdouble span = 0.0;
  int numberOfPixels = canvasWidthGlobalForDrawingFunction;
  gdouble *pixelValueForHDT = localTrack->pixelValueForHDT;
  gdouble *pixelExtraValues = localTrack->pixelExtraValues;
  char *theStyle = localTrack->style;
  int windowingMethod = (int)localHDInfo->gbTrackWindowingMethod;
  int draw0 ;
  if(strcmp(localHDInfo->gbTrackZeroDraw, "true") == 0)
    draw0 = 1 ;
  else
    draw0 = 0 ;

  gdouble factor = 0.0;
  long maxRangeTrans = 0;
  long minRangeTrans = 0;
  gdouble maximumLocal = 0.0;
  gdouble minimumLocal = 0.0;
  int useLocalScore = 0;
  int scaleToUse = 0;
  gdouble valueToAddToMinimum = 0.0;
  bool useLog = (int)localHDInfo->gbTrackUseLog;

  if(!strncmp(theStyle, "local_", 6))
  {
    useLocalScore = 1;
  }

  if(useLog)
  {
    minimumLocal = log10(localHDInfo->gbTrackDataMax);
    maximumLocal = log10(localHDInfo->gbTrackDataMin);
  }
  else
  {
    maximumLocal = localHDInfo->gbTrackDataMin;
    minimumLocal = localHDInfo->gbTrackDataMax;
  }
  if((strcmp(theStyle, "scoreBased_draw") == 0) || (strcmp(theStyle, "local_scoreBased_draw") == 0))
  {
    scaleToUse = SPECIALHEIGHT;
  }
  else
  {
    scaleToUse = localHDInfo->gbTrackPxHeight;
  }
  if(useLocalScore)
  {
    for (i = 0; i < numberOfPixels; i++)
    {
      temporaryScore = 0.0;
      if(windowingMethod == 0)
      {
        if(pixelValueForHDT[i] >= localHDInfo->gbTrackDataMin)
        {
          temporaryScore = pixelValueForHDT[i] / pixelExtraValues[i];
          if(useLog)
          {
            if(!isnan(temporaryScore) && !isinf(temporaryScore) && temporaryScore > 0.0)
            {
              temporaryScore = log10(temporaryScore);
            }
            else
            {
              temporaryScore = 0.0;
            }
          }
          if(!isnan(temporaryScore) && !isinf(temporaryScore))
          {
            if(temporaryScore > maximumLocal)
            {
              maximumLocal = temporaryScore;
            }
            else if(temporaryScore < minimumLocal)
            {
              minimumLocal = temporaryScore;
            }
          }
          else
          {
            fprintf(stderr, "Error during hdhv drawing the temp score[%d] is not a number %lf\n", i,temporaryScore);
          }
        }
      }
      else
      {
        if(pixelValueForHDT[i] >= localHDInfo->gbTrackDataMin){
          temporaryScore = pixelValueForHDT[i];
          if(useLog)
          {
            if(!isnan(temporaryScore) && !isinf(temporaryScore) && temporaryScore > 0.0)
            {
              temporaryScore = log10(temporaryScore);
            }
            else
            {
              temporaryScore = 0.0;
            }
          }
          if(!isnan(temporaryScore) && !isinf(temporaryScore))
          {
            if(temporaryScore > maximumLocal)
            {
              maximumLocal = temporaryScore;
            }
            else if(temporaryScore < minimumLocal)
            {
              minimumLocal = temporaryScore;
            }
          }
          else
          {
            fprintf(stderr, "Error during hdhv drawing the temp score[%d] is not a number %lf\n", i,temporaryScore);
          }
        }
      }
    }
  }
  // Make sure the scales make sense
  if(useLocalScore && !useLog)
  {
    maximumScore = maximumLocal ;
    minimumScore = minimumLocal ;
  }
  // for log drawing and local scaling
  else if(useLocalScore && useLog)
  {
    maximumScore = maximumLocal ;
    minimumScore = minimumLocal ;
    if(upperPxValue != (gdouble)-4290772992.0){
      logUpperPxValue = log10(upperPxValue) ;
    }
    if(lowerPxValue != (gdouble)4290772992){
      logLowerPxValue = log10(lowerPxValue) ;
    }
  }
  // for global scaling
  else if(!useLocalScore)
  {
    maximumScore = localHDInfo->gbTrackUserMax ;
    minimumScore = localHDInfo->gbTrackUserMin ;
  }
  // for log drawing and global scaling
  if(useLog && !useLocalScore)
  {
    if(maximumScore >= 0.0)
      maximumScore = log10(maximumScore);
    else
      maximumScore = 0;

    if(minimumScore >= 0.0)
      minimumScore = log10(minimumScore);
    else
      minimumScore = 0;
    if(upperPxValue != (gdouble)-4290772992.0)
      logUpperPxValue = log10(upperPxValue) ;

    if(lowerPxValue != (gdouble)4290772992)
      logLowerPxValue = log10(lowerPxValue) ;

  }
  if(minimumScore > maximumScore)
  {
    gdouble tempValue = maximumScore ;
    maximumScore = minimumScore ;
    minimumScore = tempValue ;
  }
  else if(minimumScore == maximumScore)
  {
    if(minimumScore > 0)
    {
      minimumScore = 0.0;
    }
    else if(minimumScore < 0)
    {
      maximumScore = 0.0;
    }
  }
  else
  {
    // do not use 'real' scaling
    if(draw0 == 1)
    {
      if(maximumScore >= 0.0 && minimumScore >= 0.0)
      {
        minimumScore = 0.0 ;
        maximumScore = maximumScore ;
      }
      else if(maximumScore <= 0.0 && minimumScore <= 0.0)
      {
        maximumScore = 0.0 ;
        minimumScore = minimumScore ;
      }
      else
      {
        maximumScore = maximumScore ;
        minimumScore = minimumScore ;
      }
    }

  }

  if(DEB_WIGLARGE_DRAWGD_LOOP1)
  {
    printf("INSIDE THE DRAWING METHOD\n");

    for (i = 0; i < numberOfPixels; i++)
    {
      if(pixelValueForHDT[i] > 0.00)
      {
        fprintf(stdout, "[%d]=%lf / %lf  with a min of %lf and a max of %lf\n", i, pixelValueForHDT[i],
                pixelExtraValues[i], minimumScore, maximumScore);
      }
      else
      {
        fprintf(stdout, "[%d]=%lf\n", i, 0.00);
      }
    }
    fprintf(stdout, "\n");
  }

  black = gdImageColorResolve(im, 0, 0, 0);
  white = gdImageColorResolve(im, 215, 215, 215);
  blue = gdImageColorResolve(im, 0, 0, 180);

  span = maximumScore - minimumScore;
  factor = (double)scaleToUse / span;

  y1 = initialHeight + theHeight;

  if(useLog)
  {
    maxRangeTrans = (long)round((maximumScore - minimumScore) * factor);
  }
  else
  {
    maxRangeTrans = (long)ceil((maximumScore - minimumScore) * factor);
  }
  minRangeTrans = -1;
  valueToAddToMinimum = span * factorToDrawPixelsWithBackground ;
  gdouble minValToSkip = localHDInfo->gbTrackDataMin - 1 ;
  gdouble maxValToSkip = localHDInfo->gbTrackDataMax + 1 ;
  if(useLog)
  {
    if(minValToSkip >= 0.0)
      minValToSkip = log10(minValToSkip) ;
    else
      minValToSkip = 0.0 ;

    if(maxValToSkip >= 0.0)
      maxValToSkip = log10(maxValToSkip) ;
    else
      maxValToSkip = 0.0 ;
  }
  for (i = 0; i < numberOfPixels; i++)
  {
    annotationColor = allocatedColor;
    start = labelWidthGlobalForDrawingFunction + i;
    if(windowingMethod == 0)
      temporaryScore = pixelValueForHDT[i] / pixelExtraValues[i];
    else
      temporaryScore = pixelValueForHDT[i];


    if(useLog)
    {
      if(!isnan(temporaryScore) || !isinf(temporaryScore))
        temporaryScore = log10(temporaryScore) ;
      else
        temporaryScore = 0.0 ;
    }

    if(temporaryScore >= minimumScore && temporaryScore <= maximumScore &&
      temporaryScore != minValToSkip && temporaryScore != maxValToSkip) // added to include zeros in drawing even when the min value > 0
    {
      if(useLog)
      {
        height = (long)round((temporaryScore - minimumScore) * factor) ;
      }
      else
      {
        height = (long)ceil((temporaryScore - minimumScore) * factor) ;
      }
    }
    else
    {
      height = 0;
    }

    if(DEB_WIGLARGE_DRAWGD_LOOP1)
    {
      if(pixelValueForHDT[i] > 0.00f)
      {
        fprintf(stdout,
                  "[%d]=%lf minScore = %lf and transformed to hight %ld where the max is %lf and the scaleToUse is %d and factor = %lf\n",
                  i, temporaryScore, minimumScore, height, maximumScore, scaleToUse, factor);
      }
      else
      {
        fprintf(stdout,
                  "[%d]=%lf and transformed to hight %ld where the max is %lf and the scaleToUse is %d and factor = %lf\n",
                  i, 0.0, height, maximumScore, scaleToUse, factor);
      }

      fflush(stdout);
    }

    if(visibility == VIS_FULL || visibility == VIS_DENSE || visibility == VIS_FULLNAME || visibility == VIS_FULLTEXT)
    {
      colorPointer = annotationColor;
    }
    else
    {
      colorPointer = multicolor[csel];
    }
    if(useLog){
      // For windowingMethod = MAAX or MIN
      if(windowingMethod == 1 || windowingMethod == 2){
        // Set color according to pixel value (if required)
        if(localHDInfo->gbTrackPxScoreUpperThresholdColor != NULL && localHDInfo->gbTrackPxScoreUpperThreshold != (gdouble)-4290772992.0 && log10(pixelValueForHDT[i]) >= logUpperPxValue){
          colorPointer = allocatedUpperColor;
        }
        else if(localHDInfo->gbTrackPxScoreLowerThresholdColor != NULL && localHDInfo->gbTrackPxScoreLowerThreshold != (gdouble)4290772992.0 && log10(pixelValueForHDT[i]) <= logLowerPxValue){
          colorPointer = allocatedLowerColor;
        }
      }
      else if(windowingMethod == 0){
        if(localHDInfo->gbTrackPxScoreUpperThresholdColor != NULL && localHDInfo->gbTrackPxScoreUpperThreshold != (gdouble)-4290772992.0 && log10(pixelValueForHDT[i] / pixelExtraValues[i]) >= logUpperPxValue){
          colorPointer = allocatedUpperColor;
        }
        else if(localHDInfo->gbTrackPxScoreLowerThresholdColor != NULL && localHDInfo->gbTrackPxScoreLowerThreshold != (gdouble)4290772992.0 && log10(pixelValueForHDT[i] / pixelExtraValues[i]) <= logLowerPxValue){
          colorPointer = allocatedLowerColor;
        }
      }
    }
    else{
      // For Windowing Method = MAX or MIN
      if(windowingMethod == 1 || windowingMethod == 2){
        if(localHDInfo->gbTrackPxScoreUpperThresholdColor != NULL && localHDInfo->gbTrackPxScoreUpperThreshold != (gdouble)-4290772992.0 && pixelValueForHDT[i] >= upperPxValue){
          colorPointer = allocatedUpperColor;
        }
        else if(localHDInfo->gbTrackPxScoreLowerThresholdColor != NULL && localHDInfo->gbTrackPxScoreLowerThreshold != (gdouble)4290772992.0 && pixelValueForHDT[i] <= lowerPxValue){
          colorPointer = allocatedLowerColor;
        }
      }
      // For windowing method = AVG
      else if(windowingMethod == 0){
        if(localHDInfo->gbTrackPxScoreUpperThresholdColor != NULL && localHDInfo->gbTrackPxScoreUpperThreshold != (gdouble)-4290772992.0 && (gdouble)(pixelValueForHDT[i] / pixelExtraValues[i]) >= upperPxValue){
          colorPointer = allocatedUpperColor;
        }
        else if(localHDInfo->gbTrackPxScoreLowerThresholdColor != NULL && localHDInfo->gbTrackPxScoreLowerThreshold != (gdouble)4290772992.0 && (gdouble)(pixelValueForHDT[i] / pixelExtraValues[i]) <= lowerPxValue){
          colorPointer = allocatedLowerColor;
        }
      }
    }
    y1 = initialHeight;
    y1 = y1 + (scaleToUse - height);
    y2 = y1 + height;
    gdImageLine(im, start, y1, start, y2, colorPointer);
  }

  if((strcmp(theStyle, "largeScore_draw") == 0) || (strcmp(theStyle, "local_largeScore_draw") == 0))
  {
    drawScoreLables(im, initialHeight, maximumScore, minimumScore, scaleToUse, useLog);
  }

  gdImageRectangle(im, labelWidthGlobalForDrawingFunction + 1, initialHeight, totalWidthGlobalForDrawingFunction,
                   (initialHeight + scaleToUse), black);

  return;
}


void NlargeScore_drawGD(gdImagePtr im, myGroup * theGroup, int visibility, int *multicolor, int initialHeight,
                        int theHeight, int allocatedColor, float maxScore, float minScore, int allocatedUpperColor, int allocatedLowerColor, myTrack *localTrack){
  int csel = 0;
  int y1 = 0;
  int y2 = 0;
  int i = 0;
  int start = 0, annotationStart = 0;
  int end = 0, annotationEnd = 0;
  int width = 0;
  int black = 0;
  int white = 0;
  int blue = 0;
  int colorPointer = 0;
  float thickness = 0.4;
  float thick = 0;
  int levelSize = 210;
  int *theLevels;
  int level = 0;
  int maxlevel = 0;
  gdouble temporaryScore = 0.0;
  float normalized = 0.0;
  float height = theHeight;
  myAnnotations *currentAnnotation = NULL;
  myGroup *currentGroup = theGroup;
  char maxScoreStr[255] = "";
  char minScoreStr[255] = "";
  int lengthOfMaxScoreStr = 0;
  int lengthOfMinScoreStr = 0;
  gdFontPtr font = gdFontTiny;
  int widthOfMaxBox = 0;
  int widthOfMinBox = 0;
  int heightOfBox = 0;
  int maxLabelStart = 0;
  int minLabelStart = 0;
  int annotationColor = 0;
  float span = 0.0;
  black = gdImageColorResolve(im, 0, 0, 0);
  white = gdImageColorResolve(im, 215, 215, 215);
  blue = gdImageColorResolve(im, 0, 0, 180);
  sprintf(maxScoreStr, "%.3f", maxScore);
  sprintf(minScoreStr, "%.3f", minScore);
  lengthOfMaxScoreStr = strlen(maxScoreStr);
  lengthOfMinScoreStr = strlen(minScoreStr);
  widthOfMaxBox = (lengthOfMaxScoreStr * font->w) + labelWidthGlobalForDrawingFunction + 4;
  widthOfMinBox = (lengthOfMinScoreStr * font->w) + labelWidthGlobalForDrawingFunction + 4;
  heightOfBox = font->h + 4;
  maxLabelStart = labelWidthGlobalForDrawingFunction + 3;
  minLabelStart = maxLabelStart;
  span = fabs(maxScore) + fabs(minScore);
  int scaleToUse = 0 ;

  // This part has been copied from the high density track drawing.
  // Some of the variables have the same names as those for high density track drawing.
  int lengthOfTrackInPixels = canvasWidthGlobalForDrawingFunction + 2;
  highDensFtypes *localHDInfo = localTrack->highDensFtypes;
  int windowingMethod = (int)localHDInfo->gbTrackWindowingMethod;
  int zoomLevelsPresent = 0;
  if(localTrack->pixelValueForHDT == NULL)
  {
    localTrack->pixelValueForHDT = (gdouble *) calloc(lengthOfTrackInPixels, sizeof(gdouble));
    localTrack->pixelExtraValues = (gdouble *) calloc(lengthOfTrackInPixels, sizeof(gdouble));
    // Set pixel array to minScore - 1
    for(i = 0; i < lengthOfTrackInPixels; i++){
      localTrack->pixelValueForHDT[i] = (gdouble)(minScore - 1.00);
    }
  }
  else
  {
    zoomLevelsPresent = 1;
  }
  long trackStart = getStartPosition();
  long trackStop = getEndPosition();
  long currentLocation = 0, numberOfBasesToProcess = 0, numberOfBasesProcessed = 0;
  long firstPixel, lastPixel;
  int numberOfPixels = canvasWidthGlobalForDrawingFunction;
  int canvasSize = canvasWidthGlobalForDrawingFunction;
  int locationToUpdate;
  gdouble bpPerPixel = (gdouble) lengthOfSegmentGlobalForDrawingFunction / (gdouble) canvasWidthGlobalForDrawingFunction;
  gdouble pixelsPerBase = universalScaleGlobalForDrawingFunction;
  char *theStyle = localTrack->style;
  gdouble upperPxValue = localHDInfo->gbTrackPxScoreUpperThreshold;
  gdouble lowerPxValue = localHDInfo->gbTrackPxScoreLowerThreshold;
  int draw0 ;
  if(strcmp(localHDInfo->gbTrackZeroDraw, "true") == 0)
    draw0 = 1 ;
  else
    draw0 = 0 ;

  gdouble logUpperPxValue, logLowerPxValue;
  long maxRangeTrans = 0;
  long minRangeTrans = 0;
  gdouble valueToAddToMinimum = 0.0;
  int useLocalScore = 0;
  gdouble factor = 0.0;
  gdouble *pixelValueForTrack = localTrack->pixelValueForHDT;
  gdouble *pixelExtraValues = localTrack->pixelExtraValues;
  bool useLog = (int)localHDInfo->gbTrackUseLog;

  // Check Levels
  if((theLevels = (int *)malloc((levelSize) * sizeof(int))) == NULL)
  {
    perror("problems with theLevels");
    return;
  }
  for (i = 0; i < levelSize; i++)
  {
    theLevels[i] = i;
  }
  thick = (theHeight * thickness) / 2;
  theLevels[0] = -1;
  if(visibility == VIS_FULL || visibility == VIS_FULLNAME || visibility == VIS_FULLTEXT)
  {
    while (currentGroup)
    {
      level = currentGroup->level;
      if(level > maxlevel)
      {
        maxlevel = level;
      }
      if(theLevels[level] == level)
      {
        gdImageLine(im, labelWidthGlobalForDrawingFunction, (initialHeight + (level * TALLSCORE)),
                      totalWidthGlobalForDrawingFunction, (initialHeight + (level * TALLSCORE)), blue);
        theLevels[level] = -1;
      }
      currentGroup = currentGroup->next;
    }
  }
  maxlevel++;
  currentGroup = theGroup;
  if(zoomLevelsPresent != 1)
  {
    // Go thorugh all the records in 'fdata2' and collect all the scores to draw
    // This concept is copied from the high density track drawing
    while (currentGroup)
    {
      if(csel > 3)
      {
        csel = 0;
      }
      y1 = initialHeight + (currentGroup->level * theHeight);
      currentAnnotation = currentGroup->annotations;
      while (currentAnnotation)
      {
        if(currentAnnotation->displayColor > -1)
        {
          annotationColor = gdImageColorResolve(im, getRed(currentAnnotation->displayColor),
                            getGreen(currentAnnotation->displayColor),
                            getBlue(currentAnnotation->displayColor));
        }
        else
        {
          annotationColor = allocatedColor;
        }
        // Get start and stop for the annotation/record.
        annotationStart = currentAnnotation->start;
        annotationEnd = currentAnnotation->end;
        temporaryScore = (gdouble)currentAnnotation->score;
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
        numberOfBasesToProcess = (end - start) + 1;
        double lastPixel;
        double firstPixel;
        long lastPixelLong;
        long firstPixelLong;
        long j;
        for(i = 0; i < numberOfBasesToProcess; i++){
          // The following code has been copied from the updatePixelStruct function in highDensityTracks.c
          locationToUpdate = (currentLocation - trackStart) + 1 ;
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
          for (j = firstPixelLong; j <= lastPixelLong; j++){
            if(windowingMethod == 0)
            {
              if(pixelValueForTrack[j] == (gdouble)(minScore - 1.00))
              {
                pixelValueForTrack[j] = temporaryScore;
                pixelExtraValues[j] = 1.0;
              }
              else
              {
                pixelValueForTrack[j] += temporaryScore;
                pixelExtraValues[j] += 1.0;
              }
            }
            else if(windowingMethod == 1)
            {
              if(temporaryScore > pixelValueForTrack[j]){
                pixelValueForTrack[j] = temporaryScore ;
              }
            }
            else if(windowingMethod == 2)
            {
              if(temporaryScore < pixelValueForTrack[j]){
                pixelValueForTrack[j] = temporaryScore;
              }
            }
          } // end of updatePixelValue()
          currentLocation ++;
        }

        currentAnnotation = currentAnnotation->next;
      }
      csel++;
      currentGroup = currentGroup->next;
    }
  }
  // Now draw the collected pixel values
  // Check if the drawing style is 'local'
  if(!strncmp(theStyle, "local_", 6))
  {
    useLocalScore = 1;
  }
  gdouble minimumScore, maximumScore;
  gdouble maximumLocal, minimumLocal;
  // Check if log scaling is required
  if(useLog)
  {
    minimumLocal = log10(maxScore);
    maximumLocal = log10(minScore);
  }
  else
  {
    maximumLocal = minScore ;
    minimumLocal = maxScore ;
  }
  if((strcmp(theStyle, "scoreBased_draw") == 0) || (strcmp(theStyle, "local_scoreBased_draw") == 0))
  {
    scaleToUse = SPECIALHEIGHT;
  }
  else
  {
    scaleToUse = localHDInfo->gbTrackPxHeight;
  }
  gdouble minValToSkip = minScore - 1 ;
  gdouble maxValToSkip = maxScore + 1 ;
  // For local score barchart
  temporaryScore = 0.0 ;
  if(useLocalScore)
  {
    for (i = 0; i < numberOfPixels; i++)
    {
      if(windowingMethod == 0)
      {
        if(pixelValueForTrack[i] >= minScore)
          temporaryScore = pixelValueForTrack[i] / pixelExtraValues[i];
        else
          temporaryScore = minValToSkip ;
      }
      else
      {
        if(pixelValueForTrack[i] >= minScore)
          temporaryScore = pixelValueForTrack[i];
        else
          temporaryScore = minValToSkip ;
      }
      if(useLog)
      {
        if(!isnan(temporaryScore) && !isinf(temporaryScore) && temporaryScore > 0.0 && temporaryScore != minValToSkip)
        {
          temporaryScore = log10(temporaryScore);
        }
        else
        {
          temporaryScore = 0.0;
        }
      }
      if(!isnan(temporaryScore) && !isinf(temporaryScore) && temporaryScore != minValToSkip)
      {
        if(temporaryScore > maximumLocal)
        {
          maximumLocal = temporaryScore ;
        }
        else if(temporaryScore < minimumLocal)
        {
          minimumLocal = temporaryScore ;
        }
      }
      else
      {
        //fprintf(stderr, "Error during hdhv drawing the temp score[%d] is not a number %lf\n", i,temporaryScore); not needed anymore
      }
    }
  }
  if(useLocalScore && !useLog) // local scaling and no log scaling
  {
    maximumScore = maximumLocal ;
    minimumScore = minimumLocal ;
  }
  else if(useLocalScore && useLog) // log with local scaling
  {
    maximumScore = maximumLocal ;
    minimumScore = minimumLocal ;
    if(upperPxValue != (gdouble)-4290772992.0){
      logUpperPxValue = log10(upperPxValue);
    }
    if(lowerPxValue != (gdouble)4290772992){
      logLowerPxValue = log10(lowerPxValue);
    }
  }
  else if(!useLocalScore) // global scaling
  {
    maximumScore = maxScore ;
    minimumScore = minScore ;
  }
  // log with global scaling
  if(useLog && !useLocalScore)
  {
    if(maximumScore >= 0.0)
    {
      maximumScore = log10(maximumScore);
    }
    else
    {
      maximumScore = 0;
    }
    if(minimumScore >= 0.0)
    {
      minimumScore = log10(minimumScore);
    }
    else
    {
      minimumScore = 0;
    }
    if(upperPxValue != (gdouble)-4290772992.0){
      logUpperPxValue = log10(upperPxValue);
    }
    if(lowerPxValue != (gdouble)4290772992){
      logLowerPxValue = log10(lowerPxValue);
    }
  }
  if(minimumScore > maximumScore)
  {
    gdouble tempValue = maximumScore;
    maximumScore = minimumScore;
    minimumScore = tempValue;
  }
  else if(minimumScore == maximumScore)
  {
    if(minimumScore > 0)
    {
      minimumScore = 0.0;
    }
    else if(minimumScore < 0)
    {
      maximumScore = 0.0;
    }
  }
  else
  {
    // do not use 'real' scaling
    if(draw0 == 1)
    {
      if(maximumScore >= 0.0 && minimumScore >= 0.0)
      {
        minimumScore = 0.0 ;
        maximumScore = maximumScore ;
      }
      else if(maximumScore <= 0.0 && minimumScore <= 0.0)
      {
        maximumScore = 0.0 ;
        minimumScore = minimumScore ;
      }
      else
      {
        maximumScore = maximumScore ;
        minimumScore = minimumScore ;
      }
    }
  }
  if(DEB_WIGLARGE_DRAWGD_LOOP1)
  {
    printf("INSIDE THE DRAWING METHOD\n");
    for (i = 0; i < numberOfPixels; i++)
    {
      if(pixelValueForTrack[i] > 0.00)
      {
        fprintf(stdout, "[%d]=%lf / %lf  with a min of %lf and a max of %lf\n", i, pixelValueForTrack[i],
              pixelExtraValues[i], minimumScore, maximumScore);
      }
      else
      {
        fprintf(stdout, "[%d]=%lf\n", i, 0.00);
      }
    }
    fprintf(stdout, "\n");
  }
  black = gdImageColorResolve(im, 0, 0, 0);
  white = gdImageColorResolve(im, 215, 215, 215);
  blue = gdImageColorResolve(im, 0, 0, 180);
  span = maximumScore - minimumScore;
  factor = (double)scaleToUse / span;
  y1 = initialHeight + theHeight;
  if(useLog)
  {
    maxRangeTrans = (long)round((maximumScore - minimumScore) * factor);
  }
  else
  {
    maxRangeTrans = (long)ceil((maximumScore - minimumScore) * factor);
  }
  minRangeTrans = -1;
  valueToAddToMinimum = span * factorToDrawPixelsWithBackground;
  if(useLog)
  {
    if(minValToSkip >= 0.0)
      minValToSkip = log10(minValToSkip) ;
    else
      minValToSkip = 0.0 ;

    if(maxValToSkip >= 0.0)
      maxValToSkip = log10(maxValToSkip) ;
    else
      maxValToSkip = 0.0 ;
  }
  for (i = 0; i < numberOfPixels; i++)
  {
    annotationColor = allocatedColor;
    start = labelWidthGlobalForDrawingFunction + i;
    // Check windowing method: MAX, AVG or MIN
    if(windowingMethod == 0)
    {
      temporaryScore = pixelValueForTrack[i] / pixelExtraValues[i];
    }
    else
    {
      temporaryScore = pixelValueForTrack[i];
    }
    if(temporaryScore == minimumScore)
    {
      temporaryScore = minimumScore + valueToAddToMinimum;
    }
    if(useLog)
    {
      if(!isnan(temporaryScore) || !isinf(temporaryScore))
      {
        temporaryScore = log10(temporaryScore) ;
      }
      else
      {
        temporaryScore = 0.0 ;
      }
    }
    if(temporaryScore >= minimumScore &&  temporaryScore != minValToSkip && temporaryScore != maxValToSkip)
    {
      if(temporaryScore <= maximumScore)
      {
        if(useLog)
        {
          height = (long)round((temporaryScore - minimumScore) * factor) ;
        }
        else
        {
          height = (long)ceil((temporaryScore - minimumScore) * factor) ;
        }
      }
      else // temporaryScore > maximumScore
      {
        height = maxRangeTrans ;
      }
    }
    else
    {
      height = 0;
    }
    if(height > maxRangeTrans)
    {
      height = maxRangeTrans ;
    }
    if(height < minRangeTrans)
    {
      height = minRangeTrans ;
    }
    if(DEB_WIGLARGE_DRAWGD_LOOP1)
    {
      if(pixelValueForTrack[i] > 0.00f)
      {
        fprintf(stdout,
                "[%d]=%lf minScore = %lf and transformed to hight %ld where the max is %lf and the scaleToUse is %d and factor = %lf\n",
                i, temporaryScore, minimumScore, height, maximumScore, scaleToUse, factor);
      }
      else
      {
        fprintf(stdout,
                "[%d]=%lf and transformed to hight %ld where the max is %lf and the scaleToUse is %d and factor = %lf\n",
                i, 0.0, height, maximumScore, scaleToUse, factor);
      }
      fflush(stdout);
    }
    if(visibility == VIS_FULL || visibility == VIS_DENSE || visibility == VIS_FULLNAME || visibility == VIS_FULLTEXT)
    {
      colorPointer = annotationColor;
    }
    else
    {
      colorPointer = multicolor[csel];
    }
    if(useLog){
      // For windowingMethod = MAX or MIN
      if(windowingMethod == 1 || windowingMethod == 2){
        // Set color according to pixel value (if required)
        if(localHDInfo->gbTrackPxScoreUpperThresholdColor != NULL && localHDInfo->gbTrackPxScoreUpperThreshold != (gdouble)-4290772992.0 && log10(pixelValueForTrack[i]) >= logUpperPxValue){
          colorPointer = allocatedUpperColor;
        }
        else if(localHDInfo->gbTrackPxScoreLowerThresholdColor != NULL && localHDInfo->gbTrackPxScoreLowerThreshold != (gdouble)4290772992.0 && log10(pixelValueForTrack[i]) <= logLowerPxValue){
          colorPointer = allocatedLowerColor;
        }
      }
      else if(windowingMethod == 0){
        if(localHDInfo->gbTrackPxScoreUpperThresholdColor != NULL && localHDInfo->gbTrackPxScoreUpperThreshold != (gdouble)-4290772992.0 && log10(pixelValueForTrack[i] / pixelExtraValues[i]) >= logUpperPxValue){
          colorPointer = allocatedUpperColor;
        }
        else if(localHDInfo->gbTrackPxScoreLowerThresholdColor != NULL && localHDInfo->gbTrackPxScoreLowerThreshold != (gdouble)4290772992.0 && log10(pixelValueForTrack[i] / pixelExtraValues[i]) <= logLowerPxValue){
          colorPointer = allocatedLowerColor;
        }
      }
    }
    else{
      // For Windowing Method = MAX or MIN
      if(windowingMethod == 1 || windowingMethod == 2){
        if(localHDInfo->gbTrackPxScoreUpperThresholdColor != NULL && localHDInfo->gbTrackPxScoreUpperThreshold != (gdouble)-4290772992.0 && pixelValueForTrack[i] >= upperPxValue){
          colorPointer = allocatedUpperColor;
        }
        else if(localHDInfo->gbTrackPxScoreLowerThresholdColor != NULL && localHDInfo->gbTrackPxScoreLowerThreshold != (gdouble)4290772992.0 && pixelValueForTrack[i] <= lowerPxValue){
          colorPointer = allocatedLowerColor;
        }
      }
      // For windowing method = AVG
      else if(windowingMethod == 0){
        if(localHDInfo->gbTrackPxScoreUpperThresholdColor != NULL && localHDInfo->gbTrackPxScoreUpperThreshold != (gdouble)-4290772992.0 && (gdouble)(pixelValueForTrack[i] / pixelExtraValues[i]) >= upperPxValue){
          colorPointer = allocatedUpperColor;
        }
        else if(localHDInfo->gbTrackPxScoreLowerThresholdColor != NULL && localHDInfo->gbTrackPxScoreLowerThreshold != (gdouble)4290772992.0 && (gdouble)(pixelValueForTrack[i] / pixelExtraValues[i]) <= lowerPxValue){
          colorPointer = allocatedLowerColor;
        }
      }
    }
    y1 = initialHeight;
    y1 = y1 + (scaleToUse - height);
    y2 = y1 + height;
    gdImageLine(im, start, y1, start, y2, colorPointer);
  }
  if((strcmp(theStyle, "largeScore_draw") == 0) || (strcmp(theStyle, "local_largeScore_draw") == 0))
  {
    drawScoreLables(im, initialHeight, maximumScore, minimumScore, scaleToUse, useLog);
  }
  gdImageRectangle(im, labelWidthGlobalForDrawingFunction + 1, initialHeight, totalWidthGlobalForDrawingFunction,
      (initialHeight + scaleToUse), black);
  free(theLevels);
  theLevels = NULL;
  return;
}

void Ntag_drawGD(gdImagePtr im, myGroup * theGroup, int visibility, int *multicolor, int initialHeight, int theHeight,
                 int allocatedColor)
{
  int csel = 0;
  int y1 = 0;
  int y2 = 0;
  int start = 0;
  int end = 0;
  int mid = theHeight / 2;
  int middle = 0;
  int width = 0;
  float thickness = 0.8;
  float thick = 0;
  int compactWidth = returnCompactWidth();
  int black;
  int white;
  gdFontPtr font = gdFontTiny;  //INCLUDE TEXT
  int sizeToCopy = 15;          //INCLUDE TEXT
  myAnnotations *currentAnnotation = NULL;
  myGroup *currentGroup = theGroup;
  int annotationColor = 0;

  black = gdImageColorResolve(im, 0, 0, 0);
  white = gdImageColorResolve(im, 215, 215, 215);
  thick = (theHeight * thickness) / 2;

  while (currentGroup)
  {

      currentAnnotation = currentGroup->annotations;
      while (currentAnnotation)
      {
          if(csel > 3)
          {
              csel = 0;
          }

          if(currentAnnotation->displayColor > -1)
          {
              annotationColor =
                  gdImageColorResolve(im, getRed(currentAnnotation->displayColor),
                                      getGreen(currentAnnotation->displayColor),
                                      getBlue(currentAnnotation->displayColor));
          }
          else
          {
              annotationColor = allocatedColor;
          }

          if(currentAnnotation->level == -1)
          {
              currentAnnotation = currentAnnotation->next;
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

          if((y2 - y1 + 1) % 2 == 0)
          {
              y2++;
          }

          start = calculateStart(currentAnnotation->start, 0);
          end = calculateEnd(currentAnnotation->start, start, currentAnnotation->end, 0);
          width = end - start;
          if(width < 1)
          {
              width = 1;
          }


          if(visibility == VIS_FULLTEXT && currentAnnotation->level < MAXNUMBERLINESINTRACK)
          {
              int fidText = printTextSizeFromFid(im, font, currentAnnotation->uploadId, currentAnnotation->id, 't', MAXTEXTSIZE,
                                   sizeToCopy, end + SPACEBEFORETEXT, y1 - 1, black);
              if(fidText == 0){
                printNameOfAnnotation(im, visibility, currentGroup->groupName, end, y1, black, currentAnnotation->level);
              }
          }
          else if(visibility != VIS_FULLTEXT){
            printNameOfAnnotation(im, visibility, currentGroup->groupName, end, y1, black, currentAnnotation->level);
          }

          if(visibility == VIS_FULL || visibility == VIS_DENSE || visibility == VIS_FULLNAME
             || visibility == VIS_FULLTEXT)
          {
              middle = (y1 + y2) / 2;
              gdImageLine(im, start, middle, start + width, middle, annotationColor);

              if(!currentAnnotation->orientation || currentAnnotation->orientation == '+')
              {
                  gdImageLine(im, ((start + width) - compactWidth), y1, start + width, middle, annotationColor);
                  gdImageLine(im, ((start + width) - compactWidth), y2, start + width, middle, annotationColor);
                  gdImageLine(im, start, y2, start, y1, annotationColor);
              }
              else if(currentAnnotation->orientation == '-')
              {
                  gdImageLine(im, start, middle, (start + compactWidth), y1, annotationColor);
                  gdImageLine(im, start, middle, (start + compactWidth), y2, annotationColor);
                  gdImageLine(im, (start + width), y2, (start + width), y1, annotationColor);
              }
          }
          else if(visibility == VIS_DENSEMC)
          {
              gdImageFilledRectangle(im, start, y1, start + width, y2, multicolor[csel]);
          }

          currentAnnotation = currentAnnotation->next;
          csel++;
      }
      currentGroup = currentGroup->next;
  }
  return;
}

void Nbarbed_wireGD(gdImagePtr im, myGroup * theGroup, int visibility, int *multicolor, int initialHeight,
                    int theHeight, int allocatedColor, int drawGroupLine)
{
  int csel = 0;
  int y1 = 0;
  int y2 = 0;
  int i = 0;
  long groupStart = 0;
  long groupEnd = 0;
  int b_start = 0;
  int b_end = 0;
  int b_width = 0;
  int start = 0;
  int end = 0;
  int mid = theHeight / 2;
  int width = 0;
  float thickness = 0.8;
  float thick = 0;
  int black = 0;
  int white = 0;
  int separator = 0;
  int limit = 0;
  int middle = 0;
  myAnnotations *currentAnnotation = NULL;
  myGroup *currentGroup = theGroup;
  int annotationColor = 0;
  int backGroundColor = 0;
  int red = 0;
  int green = 0;
  int blue = 0;
  double h = 0.0;
  double s = 0.0;
  double v = 0.0;
  int needWhite = 0;

  black = gdImageColorResolve(im, 0, 0, 0);
  white = gdImageColorResolve(im, 215, 215, 215);
  red = gdImageRed(im, allocatedColor);
  green = gdImageGreen(im, allocatedColor);
  blue = gdImageBlue(im, allocatedColor);

  PIX_RGB_TO_HSV_COMMON((double)red, (double)green, (double)blue, h, s, v);
  needWhite = NEED_WHITE(h, v, s);
  if(needWhite)
  {
      backGroundColor = white;
  }
  else
  {
      backGroundColor = black;
  }

  thick = (theHeight * thickness) / 2;

  while (currentGroup)
  {
      if(csel > 3)
      {
          csel = 0;
      }

      if(currentGroup->level == -1)
      {
          currentGroup = currentGroup->next;
          continue;
      }

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
      if(groupEnd < startPositionGlobalForDrawingFunction || groupStart > endPositionGlobalForDrawingFunction)
      {
          continue;
      }
      b_start = calculateStart(groupStart, 0);
      b_end = calculateEnd(groupStart, b_start, groupEnd, 0);
      b_width = b_end - b_start;
      printNameOfAnnotation(im, visibility, currentGroup->groupName, b_end, y1, black, currentGroup->level);

      if(visibility == VIS_FULL || visibility == VIS_DENSE || visibility == VIS_FULLNAME || visibility == VIS_FULLTEXT)
      {
          if(drawGroupLine)
          {
              gdImageLine(im, b_start, (y1 + y2) / 2, b_end, (y1 + y2) / 2, allocatedColor);
          }
      }
      else if(visibility == VIS_DENSEMC)
      {
          if(drawGroupLine)
          {
              gdImageLine(im, b_start, (y1 + y2) / 2, b_end, (y1 + y2) / 2, multicolor[csel]);
          }
      }

      if(drawGroupLine)
      {
          drawGroupContextLines(im, currentGroup, visibility, b_start, y1, b_end, y2, allocatedColor);
      }

      currentAnnotation = currentGroup->annotations;
      while (currentAnnotation)
      {
          start = calculateStart(currentAnnotation->start, 0);
          end = calculateEnd(currentAnnotation->start, start, currentAnnotation->end, 0);
          width = end - start;
          if(width < 1)
          {
              width = 1;
          }
          separator = 6;

          if(visibility == VIS_FULL || visibility == VIS_DENSE || visibility == VIS_FULLNAME
             || visibility == VIS_FULLTEXT)
          {
              if(currentAnnotation->displayColor > -1)
              {
                  red = getRed(currentAnnotation->displayColor);
                  green = getGreen(currentAnnotation->displayColor);
                  blue = getBlue(currentAnnotation->displayColor);
                  annotationColor = gdImageColorResolve(im, red, green, blue);

                  PIX_RGB_TO_HSV_COMMON((double)red, (double)green, (double)blue, h, s, v);
                  needWhite = NEED_WHITE(h, v, s);
                  if(needWhite)
                  {
                      backGroundColor = white;
                  }
                  else
                  {
                      backGroundColor = black;
                  }

              }
              else
              {
                  annotationColor = allocatedColor;
              }
              gdImageFilledRectangle(im, start, y1, start + width, y2, annotationColor);
              if(width >= separator)
              {
                  if(!currentAnnotation->orientation || currentAnnotation->orientation == '+')
                  {
                      limit = end;
                      if(!limit)
                      {
                          continue;
                      }
                      for (i = start; i < limit; i = i + separator)
                      {
                          middle = (y2 - y1) / 2 - 1;
                          gdImageLine(im, i, y1 + 1, i + middle, y1 + 1 + middle, backGroundColor);
                          gdImageLine(im, i, y2 - 1, i + middle, y2 - 1 - middle, backGroundColor);
                      }

                  }
                  else if(currentAnnotation->orientation == '-')
                  {
                      limit = start;
                      if(!limit)
                      {
                          continue;
                      }
                      for (i = end; i > limit; i = i - separator)
                      {
                          middle = (y2 - y1) / 2 - 1;
                          gdImageLine(im, i, y1 + 1, i - middle, y1 + 1 + middle, backGroundColor);
                          gdImageLine(im, i, y2 - 1, i - middle, y2 - 1 - middle, backGroundColor);
                      }
                  }
              }
          }
          else if(visibility == VIS_DENSEMC)
          {
              gdImageFilledRectangle(im, start, y1, start + width, y2, multicolor[csel]);
          }

          currentAnnotation = currentAnnotation->next;
      }
      csel++;
      currentGroup = currentGroup->next;
  }
  return;
}

void Nchromosome_drawGD(gdImagePtr im, myGroup * theGroup, int visibility, int *multicolor, int initialHeight,
                        int theHeight, int allocatedColor)
{
  int y1 = 0;
  int y2 = 0;
  gdFontPtr font = gdFontTiny;
  long groupStart = 0;
  char *theName = NULL;
  long groupEnd = 0;
  int b_start = 0;
  int b_end = 0;
  int b_width = 0;
  int stalk_acen = 0;
  int gvar_gpos100 = 0;
  int gneg = 0;
  int gpos25 = 0;
  int gpos50 = 0;
  int gpos75 = 0;
  int black = 0;
  int white = 0;
  int blockColor = 0;
  int textColor = 0;
  int yellow = 0;
  int blue = 0;
  int mid = theHeight / 2;
  float thickness = 0.8;
  float thick = 0;
  int labelLength = 0;
  int startingLabel = 0;
  myAnnotations *currentAnnotation = NULL;
  myGroup *currentGroup = theGroup;

  black = gdImageColorResolve(im, 0, 0, 0);
  white = gdImageColorResolve(im, 255, 255, 255);
  stalk_acen = gdImageColorResolve(im, 148, 52, 49);
  gneg = gdImageColorResolve(im, 222, 226, 222);
  gpos25 = gdImageColorResolve(im, 139, 141, 139);
  gpos50 = gdImageColorResolve(im, 82, 85, 82);
  gpos75 = gdImageColorResolve(im, 57, 56, 57);
  gvar_gpos100 = gdImageColorResolve(im, 0, 0, 0);
  blue = gdImageColorResolve(im, 0, 0, 180);
  yellow = gdImageColorResolve(im, 255, 252, 49);

  thick = (theHeight * thickness) / 2;

  while (currentGroup)
  {
      y1 = initialHeight + mid - thick;
      y2 = y1 + (2 * thick);

      currentAnnotation = currentGroup->annotations;
      while (currentAnnotation)
      {
          if(currentAnnotation->score < 0.0)
          {
              blockColor = stalk_acen;
              textColor = white;
          }
          else if(currentAnnotation->score == 0.0)
          {
              blockColor = gneg;
              textColor = black;
          }
          else if(currentAnnotation->score > 0.0 && currentAnnotation->score <= 0.25)
          {
              blockColor = gpos25;
              textColor = black;
          }
          else if(currentAnnotation->score > 0.25 && currentAnnotation->score <= 0.5)
          {
              blockColor = gpos50;
              textColor = white;
          }
          else if(currentAnnotation->score > 0.5 && currentAnnotation->score <= 0.75)
          {
              blockColor = gpos75;
              textColor = white;
          }
          else if(currentAnnotation->score > 0.75 && currentAnnotation->score <= 1.0)
          {
              blockColor = gvar_gpos100;
              textColor = white;
          }
          else
          {
              blockColor = yellow;
              textColor = blue;
          }
          currentAnnotation = currentAnnotation->next;
      }

      groupStart = currentGroup->groupStart;
      groupEnd = currentGroup->groupEnd;
      if(groupEnd < startPositionGlobalForDrawingFunction || groupStart > endPositionGlobalForDrawingFunction)
      {
          continue;
      }
      b_start = calculateStart(groupStart, 0);
      b_end = calculateEnd(groupStart, b_start, groupEnd, 0);
      b_width = b_end - b_start;
      if(b_width < 1)
      {
          b_width = 1;
      }

      gdImageFilledRectangle(im, b_start, y1, b_start + b_width, y2, blockColor);

      theName = currentGroup->groupName;
      labelLength = strlen(theName) * font->w;
      startingLabel = b_width - labelLength;
      if(startingLabel > 0)
      {
          startingLabel /= 2;
          startingLabel += b_start;
          gdImageString(im, font, startingLabel, y1 + 1, (unsigned char *)theName, textColor);
      }

      currentGroup = currentGroup->next;
  }
  return;
}

void drawDispatcherGD(gdImagePtr im, myGroup * currentGroup, int visibility, int *multicolor, int allocatedColor,
                      int initialHeight, int theHeight, char *functionName, float maxScore, float minScore, int allocatedUpperColor, int allocatedLowerColor, myTrack *localTrack)
{
  if(!strcasecmp(functionName, "simple_draw"))
  {
      Nsimple_drawGD(im, currentGroup, visibility, multicolor, initialHeight, theHeight, allocatedColor);
  }
  else if(strcasecmp(functionName, "bes_draw") == 0)
  {
      Nbes_drawGD(im, currentGroup, visibility, multicolor, initialHeight, theHeight, allocatedColor);
  }
  else if(strcasecmp(functionName, "cdna_draw") == 0)
  {
      Ncdna_drawGD(im, currentGroup, visibility, multicolor, initialHeight, theHeight, allocatedColor);
  }
  else if(strcasecmp(functionName, "gene_draw") == 0)
  {
      Ngene_drawGD(im, currentGroup, visibility, multicolor, initialHeight, theHeight, allocatedColor);
  }
  else if(strcasecmp(functionName, "sequence_draw") == 0)
  {
      sequence_drawGD(im, currentGroup, visibility, multicolor, initialHeight, theHeight, allocatedColor);
  }
  else if(strcasecmp(functionName, "mtp_draw") == 0)
  {
      Nsimple_drawGD(im, currentGroup, visibility, multicolor, initialHeight, theHeight, allocatedColor);
  }
  else if(strcasecmp(functionName, "singleFos_draw") == 0)
  {
      NsingleFos_drawGD(im, currentGroup, visibility, multicolor, initialHeight, theHeight, allocatedColor);
  }
  else if(strcasecmp(functionName, "largeScore_draw") == 0)
  {
      NlargeScore_drawGD(im, currentGroup, visibility, multicolor, initialHeight, theHeight, allocatedColor, maxScore,
                         minScore, allocatedUpperColor, allocatedLowerColor, localTrack);
  }
  else if(strcasecmp(functionName, "local_largeScore_draw") == 0)
  {
      NlargeScore_drawGD(im, currentGroup, visibility, multicolor, initialHeight, theHeight, allocatedColor, maxScore,
                         minScore, allocatedUpperColor, allocatedLowerColor, localTrack);
  }
  else if(strcasecmp(functionName, "local_scoreBased_draw") == 0)
  {
    NlargeScore_drawGD(im, currentGroup, visibility, multicolor, initialHeight, theHeight, allocatedColor, maxScore,
                         minScore, allocatedUpperColor, allocatedLowerColor, localTrack);
  }
  else if(strcasecmp(functionName, "scoreBased_draw") == 0)
  {
    NlargeScore_drawGD(im, currentGroup, visibility, multicolor, initialHeight, theHeight, allocatedColor, maxScore,
                         minScore, allocatedUpperColor, allocatedLowerColor, localTrack);
  }
  else if(strcasecmp(functionName, "pieChart_draw") == 0)
  {
      if(visibility == VIS_DENSE || visibility == VIS_DENSEMC)
      {
          NgradientScore_drawGD(im, currentGroup, visibility, multicolor, initialHeight, theHeight, allocatedColor, 1.0,
                                80);
      }
      else
      {
          pie_drawGD(im, currentGroup, visibility, multicolor, initialHeight, theHeight, allocatedColor, 1.0, 80);
      }
  }
  else if(strcasecmp(functionName, "fadeToWhite_draw") == 0)
  {
      NgradientScore_drawGD(im, currentGroup, visibility, multicolor, initialHeight, theHeight, allocatedColor,
                            maxScore, 255);
  }
  else if(strcasecmp(functionName, "fadeToGray_draw") == 0)
  {
      NgradientScore_drawGD(im, currentGroup, visibility, multicolor, initialHeight, theHeight, allocatedColor,
                            maxScore, 80);
  }
  else if(strcasecmp(functionName, "fadeToBlack_draw") == 0)
  {
      NgradientScore_drawGD(im, currentGroup, visibility, multicolor, initialHeight, theHeight, allocatedColor,
                            maxScore, 20);
  }
  else if(strcasecmp(functionName, "differentialGradient_draw") == 0)
  {
      NDifferentialgradientScore_drawGD(im, currentGroup, visibility, multicolor, initialHeight, theHeight,
                                        allocatedColor, maxScore, 0);
  }
  else if(strcasecmp(functionName, "barbed_wire_draw") == 0)
  {
      Nbarbed_wireGD(im, currentGroup, visibility, multicolor, initialHeight, theHeight, allocatedColor, 1);
  }
  else if(strcasecmp(functionName, "barbed_wire_noLine_draw") == 0)
  {
      Nbarbed_wireGD(im, currentGroup, visibility, multicolor, initialHeight, theHeight, allocatedColor, 0);
  }
  else if(strcasecmp(functionName, "negative_draw") == 0)
  {
      Nnegative_drawGD(im, currentGroup, visibility, multicolor, initialHeight, theHeight, allocatedColor);
  }
  else if(strcasecmp(functionName, "groupNeg_draw") == 0)
  {
      NgroupNeg_drawGD(im, currentGroup, visibility, multicolor, initialHeight, theHeight, allocatedColor);
  }
  else if(strcasecmp(functionName, "tag_draw") == 0)
  {
      Ntag_drawGD(im, currentGroup, visibility, multicolor, initialHeight, theHeight, allocatedColor);
  }
  else if(strcasecmp(functionName, "chromosome_draw") == 0)
  {
      Nchromosome_drawGD(im, currentGroup, visibility, multicolor, initialHeight, theHeight, allocatedColor);
  }
  else
  {
      Nsimple_drawGD(im, currentGroup, visibility, multicolor, initialHeight, theHeight, allocatedColor);
  }
}

int getGroupAwareness(char *functionName)
{
  if(!strcasecmp(functionName, "simple_draw"))
  {
      return 0;
  }
  else if(strcasecmp(functionName, "mtp_draw") == 0)
  {
      return 0;
  }
  else if(strcasecmp(functionName, "pieChart_draw") == 0)
  {
      return 0;
  }
  else if(strcasecmp(functionName, "scoreBased_draw") == 0)
  {
      return 1;
  }
  else if(strcasecmp(functionName, "largeScore_draw") == 0)
  {
      return 1;
  }
  else if(strcasecmp(functionName, "bidirectional_draw_large") == 0)
  {
      return 1;
  }
  else if(strcasecmp(functionName, " bidirectional_local_draw_large") == 0)
  {
      return 1;
  }
  else if(strcasecmp(functionName, "local_scoreBased_draw") == 0)
  {
      return 1;
  }
  else if(strcasecmp(functionName, "local_largeScore_draw") == 0)
  {
      return 1;
  }
  else if(strcasecmp(functionName, "fadeToWhite_draw") == 0)
  {
      return 0;
  }
  else if(strcasecmp(functionName, "fadeToGray_draw") == 0)
  {
      return 0;
  }
  else if(strcasecmp(functionName, "fadeToBlack_draw") == 0)
  {
      return 0;
  }
  else if(strcasecmp(functionName, "differentialGradient_draw") == 0)
  {
      return 0;
  }
  else if(strcasecmp(functionName, "negative_draw") == 0)
  {
      return 0;
  }
  else if(strcasecmp(functionName, "tag_draw") == 0)
  {
      return 0;
  }
  else if(strcasecmp(functionName, "bes_draw") == 0)
  {
      return 3;
  }
  else if(strcasecmp(functionName, "cdna_draw") == 0)
  {
      return 3;
  }
  else if(strcasecmp(functionName, "gene_draw") == 0)
  {
      return 3;
  }
  else if(strcasecmp(functionName, "sequence_draw") == 0)
  {
      return 3;
  }
  else if(strcasecmp(functionName, "singleFos_draw") == 0)
  {
      return 3;
  }
  else if(strcasecmp(functionName, "barbed_wire_draw") == 0)
  {
      return 3;
  }
  else if(strcasecmp(functionName, "barbed_wire_noLine_draw") == 0)
  {
      return 3;
  }
  else if(strcasecmp(functionName, "groupNeg_draw") == 0)
  {
      return 3;
  }
  else if(strcasecmp(functionName, "chromosome_draw") == 0)
  {
      return 1;
  }
  else
  {
      return 0;
  }
}

void drawGroupContextLines(gdImagePtr im, myGroup * currentGroup, int visibility, int x1, int y1, int x2, int y2,
                           int selectedColor)
{
  int red = 0;
  int drawLineToStart = 0;
  int drawLineToEnd = 0;
  int styleDotted[4];
  int compactWidth = 0;
  int white = 0;
  int drawLineToStartX1 = 0;
  int drawLineToStartX2 = 0;
  int drawLineCenterY = 0;
  int drawLineArrowUpY = 0;
  int drawLineArrowDownY = 0;
  int drawLineToStartArrowX = 0;
  int drawLineToEndX1 = 0;
  int drawLineToEndX2 = 0;
  int drawLineToEndArrowX = 0;
  int sizeOfName = 0;
  int endOfText = 0;
  long long initialValue = 0;
  double myDValue = 0.0;
  int newX2 = 0;
  int goToEnd = 0;
  int deltaToDrawEnd = 0;
  int brokenAnnotationAtEnd = currentGroup->containsBrokenAnnotationAtEnd;
  int brokenAnnotationAtStart = currentGroup->containsBrokenAnnotationAtStart;

  initialValue = currentGroup->groupEnd + 1 - startPositionGlobalForDrawingFunction;
  myDValue = (double)(initialValue * universalScaleGlobalForDrawingFunction);
  newX2 = (int)ceil(myDValue + labelWidthGlobalForDrawingFunction);
  if(newX2 >= (totalWidthGlobalForDrawingFunction - 5))
  {
      newX2 = totalWidthGlobalForDrawingFunction;
  }

  compactWidth = returnCompactWidth();
  drawLineCenterY = (y1 + y2) / 2;
  drawLineArrowUpY = drawLineCenterY - 4;
  drawLineArrowDownY = drawLineCenterY + 4;

  if(x1 <= (labelWidthGlobalForDrawingFunction + 10) && !brokenAnnotationAtStart)
  {                           /* Start New */
      drawLineToStartX1 = 0;
      drawLineToStartX2 = x1;
      drawLineToStartArrowX = drawLineToStartX1 + compactWidth;
  }                           /*   End New */
  else
  {                           /* Start Original */
      drawLineToStartX1 = labelWidthGlobalForDrawingFunction + 2;
      drawLineToStartX2 = (x1 + (compactWidth / 2)) + 2;
      drawLineToStartArrowX = drawLineToStartX1 + compactWidth;
  }                           /* End Original */

  drawLineToEndX1 = newX2;
  if(getUseMargins() && !brokenAnnotationAtEnd)
  {
      drawLineToEndX2 = totalWidthGlobalForDrawingFunction + RIGHT_PANEL_SIZE - 4;
  }
  else
  {
      drawLineToEndX2 = totalWidthGlobalForDrawingFunction;
  }

  drawLineToEndArrowX = drawLineToEndX2 - compactWidth;

  if(visibility == VIS_FULLNAME || visibility == VIS_FULLTEXT)
  {
      sizeOfName = strlen(currentGroup->groupName);
      if(sizeOfName > 15)
      {
          sizeOfName = 15;
      }
      endOfText = (sizeOfName * gdFontTiny->w) + 5;

      deltaToDrawEnd = totalWidthGlobalForDrawingFunction - (drawLineToEndX1 + endOfText);
      if(deltaToDrawEnd > 1 || (getUseMargins() && !brokenAnnotationAtEnd))
      {
          drawLineToEndX1 += endOfText;
      }
  }

  white = gdImageColorResolve(im, 215, 215, 215);
  red = gdImageColorResolve(im, 255, 0, 0);
  styleDotted[0] = red;
  styleDotted[1] = red;
  styleDotted[2] = white;
  styleDotted[3] = white;
  gdImageSetStyle(im, styleDotted, 4);

  if(currentGroup->groupContextPresent == 1)
  {
      if(currentGroup->hasU || currentGroup->hasF)
      {
          if(currentGroup->groupStart < startPositionGlobalForDrawingFunction)
          {
              drawLineToStart = 1;
          }
          else
          {
              drawLineToStart = 0;
          }
      }
      else
      {
          drawLineToStart = 1;
      }

      if(currentGroup->hasU || currentGroup->hasL)
      {
          if(currentGroup->groupEnd > endPositionGlobalForDrawingFunction)
          {
              drawLineToEnd = 1;
          }
          else
          {
              drawLineToEnd = 0;
          }
      }
      else
      {
          drawLineToEnd = 1;
      }

      deltaToDrawEnd = totalWidthGlobalForDrawingFunction - drawLineToEndX1;

      if(deltaToDrawEnd > 8)
      {
          goToEnd = 1;
      }
      if(getUseMargins())
      {
          goToEnd = 1;
      }

      if(visibility != VIS_HIDE)
      {
          if(drawLineToStart)
          {
              if(getUseMargins() && !brokenAnnotationAtStart)
              {
                  gdImageLine(im, drawLineToStartX1, drawLineCenterY, drawLineToStartArrowX, drawLineArrowUpY, red);
                  gdImageLine(im, drawLineToStartX1, drawLineCenterY, drawLineToStartArrowX, drawLineArrowDownY, red);
                  gdImageLine(im, drawLineToStartX1, drawLineCenterY, drawLineToStartX2, drawLineCenterY, gdStyled);
              }
              else
              {
                  gdImageLine(im, drawLineToStartX1, drawLineCenterY, drawLineToStartX2, drawLineCenterY,
                              selectedColor);
              }
          }
          if(drawLineToEnd)
          {
              if(getUseMargins() && !brokenAnnotationAtEnd)
              {
                  gdImageLine(im, drawLineToEndArrowX, drawLineArrowUpY, drawLineToEndX2, drawLineCenterY, red);
                  gdImageLine(im, drawLineToEndArrowX, drawLineArrowDownY, drawLineToEndX2, drawLineCenterY, red);
                  gdImageLine(im, drawLineToEndX1, drawLineCenterY, drawLineToEndX2, drawLineCenterY, gdStyled);
              }
              else
              {
                  gdImageLine(im, drawLineToEndX1, drawLineCenterY, drawLineToEndX2, drawLineCenterY, selectedColor);
              }
          }
      }
  }
}
