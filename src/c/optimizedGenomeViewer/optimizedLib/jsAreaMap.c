#include "jsAreaMap.h"

void jsAreaMap_init(char * baseName, char * fileName)
{
  char * jsAreaMapFileName = getstring( 12 + strnlen(baseName, 1024*1024) + strnlen(fileName, 1024*1024) ) ;
  sprintf(jsAreaMapFileName, "%s/%s.areamap.js", baseName, fileName) ;
  fprintf(stderr, "jsAreaMapFileName: %s\n", jsAreaMapFileName) ;
  if((jsAreaMapFile = fopen(jsAreaMapFileName, "w+")) == NULL)
  {
    fprintf(stderr, "unable to open the js areamap file%s\n", jsAreaMapFileName) ;
  }
  else
  {
    fprintf(jsAreaMapFile, "var areaMap = new Array() ;\n") ;
    fprintf(stderr, "OK: jsAreaMapFile handle created\n") ;
  }
  free(jsAreaMapFileName) ; // all done with this string
  fprintf(stderr, "OK: freed js area map file name string\n") ;
  return ;
}

void jsAreaMap_cleanup()
{
  if(jsAreaMapFile)
  {
    fclose(jsAreaMapFile) ;
  }
  return ;
}

// Print the map element rectangle and the position in the map file
// where we wrote the data above. Uses the jsAreaMapFile GLOBAL.
void jsAreaMap_printRegion(MAP_ELEMENT * me, off_t mapFileRecPos, long mapFileRecSize)
{
  fprintf(jsAreaMapFile, "areaMap.push( [ %d, %d, %d, %d, %ld, %ld ] ) ;\n", me->x1, me->y1, me->x2, me->y2, mapFileRecPos, mapFileRecSize) ;
  return ;
}
