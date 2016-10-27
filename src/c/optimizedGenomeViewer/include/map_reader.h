
#ifndef _map_reader_h
#define _map_reader_h

#include "globals.h"

#define STRINGOUT_INCREMENT 0x1000

typedef struct tag_STRINGOUT
{
    int len;
    char *buf;
    char *ptr;
    int sz;
} STRINGOUT;

typedef struct tag_VECTOR
{
    void **elements;
    int length;
    int size;
} VECTOR;

typedef struct tag_MAP_ELEMENT
{
    int etype;
    char *gclass, *gname, *score, *trackname, *links;
    void *userdata;
    int x1, y1, x2, y2;
    long from, to;
    char *upfid;
} MAP_ELEMENT;

#define MAP_ETYPE_ANNOTATION 0
#define MAP_ETYPE_GROUP 1
#define MAP_ETYPE_TRACK 2
#define stringout_clear(sout) { (sout)->ptr = (sout)->buf; *((sout)->ptr) = '\0'; (sout)->sz = 0; }
#define stringout_getstring(sout) ((sout)->buf)

typedef struct tag_MAP_READER
{
    int MIN_WIDTH, GAP, GROUP_WIDTH, MAX_WIDTH;

    char gName[512];
    int gx1, gy1, gx2, gy2;
    long gFrom, gTo;
    int gcnt;
    int small_group;

    MAP_ELEMENT *lastm;
    int rx1, ry1, rx2, ry2;
    long rFrom, rTo;
    int rcnt;
    long gMaxTo;
    int has_overlaps;

    MAP_ELEMENT *trackm;

    VECTOR *vBuf;
    VECTOR *tBuf;
} MAP_READER;

/* function prototypes */
char *duplicate_string( char *p );
VECTOR *construct_vector();
void delete_vector( VECTOR *v );
void vector_add_element( VECTOR *v, void *elem );
void *vector_element_at( VECTOR *v, int idx );
MAP_ELEMENT *construct_map_element();
void delete_map_element( MAP_ELEMENT *m );

MAP_READER *construct_map_reader();
void delete_map_reader( MAP_READER *mr );
MAP_ELEMENT *map_reader_add_annotation( MAP_READER *mr,
    int x1, int y1, int x2, int y2,
    char *gclass, char *gname, long from, long to, char *score);
void map_reader_add_group( MAP_READER *mr,
    char *gname, int x1, int y1, int x2, int y2, long from, long to );
MAP_ELEMENT *map_reader_add_track( MAP_READER *mr,
    char *trackname, int x1, int y1, int x2, int y2 );
MAP_ELEMENT *map_reader_add_track( MAP_READER *mr,
    char *trackname, int x1, int y1, int x2, int y2 );
void print_map_element( MAP_ELEMENT *m, FILE *fout );

#define map_reader_get_count(mr) (mr->vBuf->size)
#define map_reader_element_at(mr,idx) ((MAP_ELEMENT *)((mr->vBuf->elements)[idx]))

void map_reader_purge( MAP_READER *mr );
int break_string_by( char *buf, char sep, char **tgt, int maxn );
char *trim_new_line( char *buf );
MAP_READER *getMapReader(void);
void setMapReader(MAP_READER *myReader);
void processMap(FILE *mapFile, FILE *rawFile);
STRINGOUT *construct_stringout();
void delete_stringout( STRINGOUT *sout );
void stringout_printf( STRINGOUT *sout, char *fmt, ... );
void stringout_append( STRINGOUT *sout, char *str );
char *trimString(double score, int howMany);

#endif /* _map_reader_h */
