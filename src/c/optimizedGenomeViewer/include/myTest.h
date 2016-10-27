
#ifndef _myTest_h
#define _myTest_h

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>

#define VIS_FULL  0
#define VIS_DENSE 1
#define VIS_HIDE  2
#define VIS_DENSEMC 3
#define VIS_FULLNAME 4
#define VIS_FULLTEXT 5
#define MAXTEXTSIZE 16
#define	MAXARR	2
#define MAXVALUEINCOLOR 16777215

#define MAX_HEIGHT_PER_TRACK 500
#define arr_size(a) (sizeof(a)/sizeof((a)[0]))
#define round(a) ((int)((a)+0.5))


#define getAlpha(c) (((c) & 0x7F000000) >> 24)
#define getRed(c) (((c) & 0xFF0000) >> 16)
#define getGreen(c) (((c) & 0x00FF00) >> 8)
#define getBlue(c) ((c) & 0x0000FF)


#define GT(x, y) (strcmp((x),(y)) > 0)
#define LT(x, y) (strcmp((x),(y)) < 0)
#define GE(x, y) (strcmp((x),(y)) >= 0)
#define LE(x, y) (strcmp((x),(y)) <= 0)
#define EQ(x, y) (strcmp((x),(y)) == 0)
#define NE(x, y) (strcmp((x),(y)) != 0)

#define SWAP(x, y) temp = (x); (x) = (y); (y) = temp

#ifndef CUTOFF
#  define CUTOFF 15
#endif



typedef enum { full  = VIS_FULL, dense = VIS_DENSE,  hide = VIS_HIDE, denseMC = VIS_DENSEMC, fullWithName = VIS_FULLNAME, fullWithText = VIS_FULLTEXT } visibility;




typedef struct hash_t {
  struct hash_t * next;
  char            key[20];
  char            value[255];
} hash;

typedef struct chrom_info_t {
  struct chrom_info_t * next;
  char                  name[255];
  hash                * info;
} chrom_info;


 typedef struct STYLESUSED{
	int numberOfStyles;
	int *id;
	char **featureType;
	char **name;
	char **description;
	char **color;
 }STYLESUSED;


 typedef struct TVIS{
	int numberOfTracks;
	char **name;
	int *value;
	char **className;
	int *order;
 }TVIS;

 typedef struct rgbColorStruct {
	int r;
	int g;
	int b;
 } rgbColorStruct;


 typedef struct rgbColor {
	int r;
	int g;
	int b;
 } rgbColor;

 typedef struct PROPERTIES{
	int numberOfProps;
	char **name;
	char **value;
 }PROPERTIES;

#define GENBOREEURL	"127.0.0.1"
#define EXPIRES		"+1h"
#define COOKIEPATH	"/"
#define LOGINFILE	"/usr/local/brl/local/apache/htdocs/login.html"
#define USERDATA	"userdata"
#define BASEDIR		"/usr/local/brl/local/apache/htdocs/graphics"
//#define DATABASEPREF    "/usr/local/brl/local/apache/dbaccess.properties"
#define DATABASEPREF    "/usr/local/brl/local/apache/genboree.config.properties"
#define PIECHARTSUBSTITUTION	"fadeToGray_draw"
#define TITLE   "Genboree"
#define WEB_ROOT "http://www.hgsc.brl.tmc.edu"
#define NO_ANNOTATIONS_FOUND "No annotations found in the specified range"

#define LOG_FILE "./genboree.log"
#define TMP_PATH "tmp"
#define GB_PATH "work"
#define GB_BASE_NAME "/java-bin/index.jsp"
#define BASE_NAME "genboree.cgi"
#define MAX_COORD_DIGITS 9
//#define MIN_COORD_RANGE  500
#define MIN_COORD_RANGE  10
#define IMG_WIDTH  620
#define IMG_HEIGHT 300
#define MAP_NAME "genomeimap"
#define GIF_PFX "gbimg"
#define IMG_BORDER    1
#define LABEL_WIDTH 120
#define NUM_SHADES  10
#define TRACK_WIDTH IMG_WIDTH-IMG_BORDER-LABEL_WIDTH
#define REFSEQ_HEIGHT 10
#define TRACK_SEP     18
#define SMALL_TRACK_SEP 5
#define SUBTRACK_HEIGHT 10
#define DEF_SHIFT     2000
#define DEF_ZOOM      2
#define GUIDE_SEPARATION   10
#define arr_size(a) (sizeof(a)/sizeof((a)[0]))
#define round(a) ((int)((a)+0.5))
#define SIZEDIRFILES      1024
#define GRAPHICS_REPOSITORY "/usr/local/brl/local/apache/htdocs/graphics"
#define	REGULARHEIGHT 9
#define	SPECIALHEIGHT 13
#define	TALLSCORE 100
#define	MIDIUMHEIGHT 25

// ######################################################################
// Andrew Jackson
// andrewj@bcm.edu
// Macro to Decide if I need to use white or black in a given hvs
// color background
#define NEED_WHITE(hh,vv,ss)                                           \
  (vv <= 0.6 ?                                                         \
    1 :                                                                \
    (ss <= 0.5 ?                                                       \
      0 :                                                              \
      ((hh <= 0.55 && hh >= 0.1) ?                                     \
        0 :                                                            \
        1                                                              \
      )                                                                \
    )                                                                  \
  )



// ######################################################################
// Adapted from:
// T. Nathan Mundhenk
// mundhenk@usc.edu
// C/C++ Macro RGB to HSV
#define PIX_RGB_TO_HSV_COMMON(R,G,B,H,S,V)                             \
if((B > G) && (B > R))                                                 \
{                                                                      \
  V = B;                                                               \
  if(V != 0)                                                           \
  {                                                                    \
    double min;                                                        \
    if(R > G) min = G;                                                 \
    else      min = R;                                                 \
    const double delta = V - min;                                      \
    if(delta != 0)                                                     \
      { S = (delta/V); H = 4 + (R - G) / delta; }                      \
    else                                                               \
      { S = 0;         H = 4 + (R - G); }                              \
    H *=   60; if(H < 0) H += 360;  H /= 360;                          \
    V =  (V/255);                                                      \
  }                                                                    \
  else                                                                 \
    { S = 0; H = 0;}                                                   \
}                                                                      \
else if(G > R)                                                         \
{                                                                      \
  V = G;                                                               \
  if(V != 0)                                                           \
  {                                                                    \
    double min;                                                        \
    if(R > B) min = B;                                                 \
    else      min = R;                                                 \
    const double delta = V - min;                                      \
    if(delta != 0)                                                     \
      { S = (delta/V); H = 2 + (B - R) / delta; }                      \
    else                                                               \
      { S = 0;         H = 2 + (B - R); }                              \
    H *=   60; if(H < 0) H += 360; H /= 360;                           \
    V =  (V/255);                                                      \
  }                                                                    \
  else                                                                 \
    { S = 0; H = 0;}                                                   \
}                                                                      \
else                                                                   \
{                                                                      \
  V = R;                                                               \
  if(V != 0)                                                           \
  {                                                                    \
    double min;                                                        \
    if(G > B) min = B;                                                 \
    else      min = G;                                                 \
    const double delta = V - min;                                      \
    if(delta != 0)                                                     \
      { S = (delta/V); H = (G - B) / delta; }                          \
    else                                                               \
      { S = 0;         H = (G - B); }                                  \
    H *=   60; if(H < 0) H += 360; H /= 360;                           \
    V =  (V/255);                                                      \
  }                                                                    \
  else                                                                 \
    { S = 0; H = 0;}                                                   \
}


// ######################################################################
// T. Nathan Mundhenk
// mundhenk@usc.edu
// C/C++ Macro HSV to RGB
#define PIX_HSV_TO_RGB_COMMON(H,S,V,R,G,B)                          \
if( V == 0 )                                                        \
{ R = 0; G = 0; B = 0; }                                            \
else if( S == 0 )                                                   \
{                                                                   \
  R = V;                                                            \
  G = V;                                                            \
  B = V;                                                            \
}                                                                   \
else                                                                \
{                                                                   \
  const double hf = (H*60)  ;                                       \
  const int    i  = (int) floor( hf );                              \
  const double f  = hf - i;                                         \
  const double pv  = V * ( 1 - S );                                 \
  const double qv  = V * ( 1 - S * f );                             \
  const double tv  = V * ( 1 - S * ( 1 - f ) );                     \
  switch( i )                                                       \
    {                                                               \
    case 0:                                                         \
      R = V;                                                        \
      G = tv;                                                       \
      B = pv;                                                       \
      break;                                                        \
    case 1:                                                         \
      R = qv;                                                       \
      G = V;                                                        \
      B = pv;                                                       \
      break;                                                        \
    case 2:                                                         \
      R = pv;                                                       \
      G = V;                                                        \
      B = tv;                                                       \
      break;                                                        \
    case 3:                                                         \
      R = pv;                                                       \
      G = qv;                                                       \
      B = V;                                                        \
      break;                                                        \
    case 4:                                                         \
      R = tv;                                                       \
      G = pv;                                                       \
      B = V;                                                        \
      break;                                                        \
    case 5:                                                         \
      R = V;                                                        \
      G = pv;                                                       \
      B = qv;                                                       \
      break;                                                        \
    case 6:                                                         \
      R = V;                                                        \
      G = tv;                                                       \
      B = pv;                                                       \
      break;                                                        \
    case -1:                                                        \
      R = V;                                                        \
      G = pv;                                                       \
      B = qv;                                                       \
      break;                                                        \
    default:                                                        \
      LFATAL("i Value error in Pixel conversion, Value is %d",i);   \
      break;                                                        \
    }                                                               \
}                                                                   \
R *= 255.0F;                                                        \
G *= 255.0F;                                                        \
B *= 255.0F;

#endif /* _myTest_h */
