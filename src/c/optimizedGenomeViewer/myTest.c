#include "globals.h"
#include "optimizedGB.h"
#include "optimizedFunctions.h"
#include "jsAreaMap.h"

//static struct rgbColor REFSEQ_COLOR = { 0, 200, 0 };
static struct rgbColor REFSEQ_COLOR = { 98, 154, 125 };

//static struct rgbColor REFSEQ_COLOR = { 98, 215, 125 };

int main(int argc, char **argv)
{
  char *genericString = NULL;
  long myRefSeq = 77;
  int newSchema = 0;
  char option = 0;
  char *entryPointName;
  struct rgbColor colorLeftPanel = { 235, 235, 235 };
  char name[] = "Reference";
  char legend[] = "Base Position";
  long long from = 0;
  long long to = 0;
  gdImagePtr im;
  long theUserId = 0;
  FILE *out;
  FILE *localMapPointerFile;
//      FILE *localRawPointerFile;
  int theTrackWidth = TRACK_WIDTH;
  int tempTrackWidth = 0;
  char baseDir[1024] = ".";
  char nameFile[1024] = "";
  char *gif_file = NULL;
  char *map_file = NULL;
  char xmlFile[1024] = "";
  int debug = 0;
  int portNumber = 5;
  int printMap = 0;
  int useXMLToOrder = 0;
  int defaultCompression = 5;
  int compression = defaultCompression;
  static int verbose_flag = 0;

  while (1)
    {
      static struct option long_options[] = {
        /* These options set a flag. */
        {"verbose", no_argument, &verbose_flag, 1},
        {"brief", no_argument, &verbose_flag, 0},
        /* These options don't set a flag.
           We distinguish them by their indices. */
        {"from", required_argument, 0, 'i'},
        {"to", required_argument, 0, 't'},
        {"refseqId", required_argument, 0, 'r'},
        {"widthOfTrack", required_argument, 0, 'w'},
        {"userId", required_argument, 0, 'u'},
        {"graphicCompression", required_argument, 0, 's'},
        {"entryPointName", required_argument, 0, 'e'},
        {"debug", no_argument, 0, 'd'},
        {"preserveDefaultTrackOrder", no_argument, 0, 'a'},
        {"printXML", no_argument, 0, 'm'},
        {"printInMargins", no_argument, 0, 'y'},
        {"useXMLToOrder", no_argument, 0, 'c'},
        {"displayEmptyTracks", no_argument, 0, 'l'},
        {"displayTrackDescriptions", no_argument, 0, 'g'},
        {"pngFormat", no_argument, 0, 'p'},
        {"nameOfFileBase", required_argument, 0, 'n'},
        {"fileHandler", required_argument, 0, 'f'},
        {"xmlFileName", required_argument, 0, 'x'},
        {"baseDir", required_argument, 0, 'b'},
        {"help", no_argument, 0, '?'},
        {0, 0, 0, 0}
      };

      /* getopt_long stores the option index here. */
      int option_index = 0;

      option = getopt_long(argc, argv, "i: t: r: w: u: s: e: damyclgpn: f: x: b: ?", long_options, &option_index);

      /* Detect the end of the options. */
      if(option == -1)
        break;

      switch (option)
        {
        case 'i':
          genericString = optarg;
          if(genericString && strlen(genericString) > 0)
            sscanf(genericString, "%lld", &from);
          else
            from = 1;
          genericString = NULL;
          break;
        case 't':
          genericString = optarg;
          if(genericString && strlen(genericString) > 1)
            sscanf(genericString, "%lld", &to);
          else
            {
              printf("The value for the option -t have to be a number\n");
              exit(0);
            }
          if(to < 1)
            {
              printf("The value for the option -t have to be a positive number\n");
              exit(0);
            }
          genericString = NULL;
          break;
        case 'r':
          genericString = optarg;
          if(genericString && strlen(genericString) > 1)
            {
              sscanf(genericString, "%ld", &myRefSeq);
            }
          else
            {
              fprintf(stderr, "The value for the option -r have to be a number\n");
              fflush(stderr);
              exit(0);
            }
          if(myRefSeq < 1)
            {
              fprintf(stderr, "The value for the option -r have to be a positive number\n");
              fflush(stderr);
              exit(0);
            }
          genericString = NULL;
          break;
        case 'w':
          genericString = optarg;
          if(genericString && strlen(genericString) > 1)
            {
              sscanf(genericString, "%d", &tempTrackWidth);
              if(tempTrackWidth <= theTrackWidth)
                {
                  fprintf(stderr, "The value for the option -w have to be a number larger than %d\n", theTrackWidth);
                  fflush(stderr);
                  exit(0);
                }
              else
                {
                  theTrackWidth = tempTrackWidth;
                }
            }
          else
            {
              fprintf(stderr, "The value for the option -w have to be a number larger than %d\n", theTrackWidth);
              fflush(stderr);
              exit(0);
            }
          if(theTrackWidth < 1)
            {
              fprintf(stderr, "The value for the option -w have to be a positive number larger than %d\n",
                      theTrackWidth);
              fflush(stderr);
              exit(0);
            }
          genericString = NULL;
          break;
        case 's':
          genericString = optarg;
          if(genericString && strlen(genericString) > 0)
            {
              sscanf(genericString, "%d", &compression);
              if(compression > 9 || compression < -1)
                {
                  fprintf(stderr, "The value for the option -s have to be a number between 0 (no compression)"
                          " and 9 (full compression) the value has been set to the default value %d\n",
                          defaultCompression);
                  fflush(stderr);
                  compression = defaultCompression;
                }
            }
          else
            {
              fprintf(stderr, "The value for the option -s have to be a number between 0 and 9\n");
              fflush(stderr);
              exit(0);
            }
          genericString = NULL;
          break;
        case 'u':
          genericString = optarg;
          if(genericString && strlen(genericString) > 0)
            {
              sscanf(genericString, "%ld", &theUserId);
              if(theUserId < 0)
                {
                  printf("The value for the option -u have to be a positive number\n");
                  exit(0);
                }
              setMyUserId(theUserId);
            }
          else
            {
              printf("The value for the option -u have to be a number\n");
              exit(0);
            }
          genericString = NULL;
          break;
        case 'e':
          entryPointName = optarg;
          if(!entryPointName)
            {
              printf("You need to provide a chromosome name or EntryPoint with the -e option\n");
              exit(0);
            }
          break;
        case 'b':
          genericString = optarg;
          if(genericString && strlen(genericString) > 1)
            strcpy(baseDir, genericString);
          if(baseDir == NULL || strlen(baseDir) < 2)
            strcpy(baseDir, BASEDIR);
          genericString = NULL;
          break;
        case 'l':
          setDisplayEmptyTracks(1);
          break;
        case 'g':
          setDisplayTrackDescriptions(1);
          break;
        case 'y':
          setUseMargins(1);
          break;
        case 'c':
          useXMLToOrder = 1;
          break;
        case 'f':
          genericString = optarg;
          if(genericString && strlen(genericString) > 0)
            {
              sscanf(genericString, "%d", &portNumber);
              if(portNumber > 2)
                {
                  fprintf(stderr,
                          "The value for the option -f is the port Number have to be 0 = no port, 1 = STDOUT 2 = regularFile\n");
                  fflush(stderr);
                  exit(0);
                }
            }

          break;
        case 'a':
          setPreserveDefaultTrackOrder(1);
          break;
        case 'n':
          genericString = optarg;
          if(genericString && strlen(genericString) > 1)
            {
              strcpy(nameFile, genericString);
            }
          else
            {
              printf("You need to provide a base name for the output file with the  -n option\n");
              exit(0);
            }
          genericString = NULL;
          break;
        case 'x':
          genericString = optarg;
          if(genericString && strlen(genericString) > 1)
            strcpy(xmlFile, genericString);
          else
            {
              printf
                  ("You need to provide the name of the file containing visibility options in xml format with -x option\n");
              exit(0);
            }
          genericString = NULL;
          break;
        case 'd':
          debug = 1;
          break;
        case 'p':
          setPNG(1);
          break;
        case 'm':
          setPrintXML(1);
          break;
        case '?':
          printf("Usage: %s\n"
                 "ARGUMENTS:\n"
                 "-i START = Start position\n"
                 "-t STOP = Stop position\n"
                 "-r REFSEQID = The reference Sequence Id\n"
                 "-u USERID = The user Id\n"
                 "-f FILE HANDLER = the file handler to print the imageMap 0 = noMap, 1 = STDOUT, 2 = regular file\n"
                 "-w WIDTH = The width > 499 \n"
                 "-e ENTRYPOINT = The entrypoint name\n"
                 "-b BASEDIR = The name of the destination directory\n"
                 "-l DISPLAYEMPTYTRACKS = Display Tracks without annotations\n"
                 "-n FILENAME = The name of the file without extensions\n"
                 "-x XMLFILENAME = The name of the file with visibilities options\n"
                 "-d DEBUGON = Set debug on\n"
                 "-c USE XML to sort tracks\n"
                 "-m PRINTXML = print XML file\n"
                 "-y PRINTINMARGINS = set print outside drawing box\n"
                 "-p PNG = change the drawing from gif to a png\n"
                 "-s Compression for PNG value between 0 and 9\n"
                 "-a Preserve default's track order\n" "-g Display Track Descriptions", argv[0]);
          exit(1);
        }
    }

  if(optind <= 12)
    {
      printf
          ("Usage: %s -i START -t STOP -r REFSEQID -u USERID -e ENTRYPOINT -n FILENAME [-b BASEDIR][-f FILE HANDLER] [-l] [ -d ] [-g] [-c] [-y PRINTINMARGINS ]  [ -p PNG ] [ -s Compression for PNG ] [-a PRESERVE DEFAULT's TRACK ORDER] [-w WIDTH > 499] [-x XMLFILE-WITH-VISIBILITIES-OPTIONS] [-m PRINT XMLFILE]\n",
           argv[0]);
      exit(1);
    }

  {
    time_t startTime;
    startTime = (time_t) time(&startTime);
    setGlobalStartTime(startTime);
    setMyDebug(debug);
  }

  if(baseDir == NULL || strlen(baseDir) < 2)
    strcpy(baseDir, BASEDIR);
  if(nameFile == NULL)
    {
      printf
          ("Usage: %s -i START -t STOP -r REFSEQID -u USERID -e ENTRYPOINT -n FILENAME [-b BASEDIR][-f FILE HANDLER] [-l] [ -d ][-g] [-c] [-y PRINTINMARGINS ]  [ -p PNG ] [ -s Compression for PNG ] [-a PRESERVE DEFAULT's TRACK ORDER] [-w WIDTH > 499] [-x XMLFILE-WITH-VISIBILITIES-OPTIONS] [-m PRINT XMLFILE]\n",
           argv[0]);
      return 1;
    }
  generateNames(baseDir, nameFile);
  gif_file = getGifFileName();
  map_file = getMapFileName();

  timeItNow("DRAWING PROGRAM TIMING REPORT:\n(timings are *cummulative*)\n-----------------------------");

  if(!portNumber)
    {
      printMap = 0;
    }
  else if(portNumber == 1)
    {
      setMapPointerFile(stdout);
      printMap = 1;
    }
  else if(portNumber > 1)
  {
    if((localMapPointerFile = fopen(map_file, "w+")) == NULL)
    {
      printf("unable to open the file %s\n", map_file) ;
      return 0 ;
    }
    setMapPointerFile(localMapPointerFile) ;
    // For js areaMap rectangles
    jsAreaMap_init(baseDir, nameFile) ;
    fprintf(stderr, "DEBUG: done jsAreaMap_init\n") ;
    printMap = 1 ;
  }

  if(xmlFile != NULL && strlen(xmlFile) > 2)
  {
    fprintf(stderr, "DEBUG: before generate vis data from xml\n") ;
    generateVisDataFromXml(xmlFile);
  }
  else
  {
    fprintf(stderr, "DEBUG: not using xml to order\n") ;
    useXMLToOrder = 0;
  }

  fprintf(stderr, "DEBUG: about to set  widths and stuff\n") ;
  setGroupOrderUsingXml(useXMLToOrder);
  setStartFirstTrack(IMG_BORDER + REFSEQ_HEIGHT + TRACK_SEP + 10);
  setLabelWidth(LABEL_WIDTH);
  setTrackWidth(theTrackWidth); //TRACK_WIDTH);
  fprintf(stderr, "DEBUG: done setting widths and stuff\n") ;

  newSchema = initializeProcess(myRefSeq, entryPointName, from, to);

  if(!newSchema)
    {
      fprintf(stderr, "Fail using refseqId = %ld\n"
              "Problems accessing DATABASE content, probable causes: empty database,"
              " OLD SCHEMA  or user permissions\n", myRefSeq);
      exit(1);
    }

  if(getDisplayTrackDescriptions())
    {
      setSpaceBetweenTracks(TRACK_SEP);
    }
  else
    {
      setSpaceBetweenTracks(SMALL_TRACK_SEP);
    }

  calculateImageHeight();
  /* Open output file in binary mode */
  out = fopen(gif_file, "wb");
  timeItNow("C-DONE - Various Calculations");
  im = initializeCanvasGD(name);

  drawRulerGD(im, legend, getStartPosition(), getEndPosition());
  timeItNow("C-DONE - drawRulerGD");
  drawTracksGD(im, colorLeftPanel);
  timeItNow("C-DONE - drawTracksGD");
  drawRefSeqGD(im, REFSEQ_COLOR, name);
  timeItNow("C-DONE - drawRefSeqGD");
  if(getPNG())
    {
      gdImagePngEx(im, out, compression);
    }
  else
    {
      gdImageGif(im, out);
    }
  timeItNow("C-DONE - outputing the gif");
  fclose(out);
  timeItNow("C-DONE - close the gif");
  timeItNow("C-DONE - Drawing Generation");
  fflush(stderr);
  if(printMap)
    {
      makeImageMap();
    }
  timeItNow("C-DONE - ImageMap Generation");
  gdImageDestroy(im);
  timeItNow("C-DONE - destroy im");
  finalizeProcess(newSchema);
  timeItNow("After deleting Structures");
/*	if(portNumber == 1)
	{
		fclose(localRawPointerFile);
	}
	else */
  if(portNumber > 1)
  {
    fclose(localMapPointerFile) ;
    jsAreaMap_cleanup() ;
  }

  timeItNow("C-DONE - Cleaning structures and removing temporary files");

  return 0;
}
