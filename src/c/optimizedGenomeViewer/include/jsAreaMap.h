
#ifndef _jsAreaMap_h
#define _jsAreaMap_h

#include "globals.h"
#include "optimizedFunctions.h"
#include "map_reader.h"

// ------------------------------------------------------------------
// GLOBALS (real ones, not static, not ones needing get/set functions, geez...)
// ------------------------------------------------------------------
FILE * jsAreaMapFile ;

// ------------------------------------------------------------------
// FUNCTIONS
// ------------------------------------------------------------------
void jsAreaMap_init() ;
void jsAreaMap_cleanup() ;
void jsAreaMap_printRegion(MAP_ELEMENT * me, off_t mapFileRecPos, long mapFileRecSize) ;

#endif /* _jsAreaMap_h */
