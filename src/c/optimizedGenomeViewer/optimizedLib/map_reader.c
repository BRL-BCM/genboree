#include "map_reader.h"

static MAP_READER *mapReader = NULL;

STRINGOUT *construct_stringout()
{
  STRINGOUT *sout = (STRINGOUT *) malloc(sizeof(STRINGOUT));
  sout->len = STRINGOUT_INCREMENT * 2;
  sout->buf = (char *)malloc((sout->len) * sizeof(char));
  sout->ptr = sout->buf;
  *(sout->ptr) = '\0';
  sout->sz = 0;
  return sout;
}

void delete_stringout(STRINGOUT * sout)
{
  free(sout->buf);
  sout->buf = NULL;
  free(sout);
  sout = NULL;
}

static void stringout_extend(STRINGOUT * sout)
{
  int l = sout->len + STRINGOUT_INCREMENT;
  sout->buf = (char *)realloc(sout->buf, l * (sizeof(char)));
  sout->len = l;
  sout->ptr = sout->buf + sout->sz;
}

void stringout_printf(STRINGOUT * sout, char *fmt, ...)
{
  va_list vargs;

  if((sout->sz + STRINGOUT_INCREMENT) > sout->len)
    stringout_extend(sout);

  va_start(vargs, fmt);
  vsprintf(sout->ptr, fmt, vargs);
  va_end(vargs);
  sout->sz = strlen(sout->buf);
  sout->ptr = sout->buf + sout->sz;
}

void stringout_append(STRINGOUT * sout, char *str)
{
  int l = strlen(str);
  if((sout->sz + l + 1) > sout->len)
    stringout_extend(sout);
  strcpy(sout->ptr, str);
  sout->ptr += l;
}

MAP_READER *getMapReader(void)
{
  return mapReader;
}

void setMapReader(MAP_READER * myReader)
{
  mapReader = myReader;
}

char *duplicate_string(char *p)
{
  char *rc = NULL;
  if(!p)
    return NULL;
  rc = (char *)malloc(strlen(p) + 1);
  strcpy(rc, p);
  return rc;
}

/* VECTOR support */
VECTOR *construct_vector()
{
  VECTOR *v = (VECTOR *) malloc(sizeof(VECTOR));
  v->length = 64;
  v->elements = (void **)malloc(v->length * (sizeof(void *)));
  v->size = 0;
  return v;
}

void delete_vector(VECTOR * v)
{
  if(!v)
    return;
  free(v->elements);
  free(v);
}

void vector_add_element(VECTOR * v, void *elem)
{
  int l;
  if(v->size >= v->length)
  {
      l = v->length * 2;
      v->elements = (void **)realloc(v->elements, l * (sizeof(void *)));
      v->length = l;
  }
  v->elements[(v->size)++] = elem;
}

void *vector_element_at(VECTOR * v, int idx)
{
  if(idx >= 0 && idx < v->size)
    return v->elements[idx];
  return NULL;
}

/* MAP_ELEMENT support */
MAP_ELEMENT *construct_map_element()
{
  MAP_ELEMENT *m = (MAP_ELEMENT *) malloc(sizeof(MAP_ELEMENT));
  memset(m, 0, sizeof(MAP_ELEMENT));
  return m;
}

char *trimString(double score, int howMany)
{
  char s1[50] = "";
  int initialLength = 0;
  int finalLength = 0;
  int diff = 0;
  char *strPtr = NULL;
  char digits[50] = "";
  char returnValue[100] = "";
  int i = 0;
  int a = 0;
  int lengthChar = howMany + 1;
  char fractions[50] = "";

  sprintf(s1, "%lf", score);
  initialLength = strlen(s1);
  strPtr = strchr(s1, '.');
  finalLength = strlen(strPtr);
  diff = initialLength - finalLength;

  for (i = 0; i < diff; i++)
    digits[i] = s1[i];

  if(initialLength >= (lengthChar + diff))
  {
      for (a = 0, i = diff; i < (lengthChar + diff); i++, a++)
        fractions[a] = s1[i];

  }
  else
  {
      for (a = 0, i = diff; i < initialLength; i++, a++)
        fractions[a] = s1[i];

  }

  sprintf(returnValue, "%s%s", digits, fractions);

  return strdup(returnValue);
}

void delete_map_element(MAP_ELEMENT * m)
{
  if(!m)
    return;
  if(m->gclass)
  {
      free(m->gclass);
      m->gclass = NULL;
  }
  if(m->gname)
  {
      free(m->gname);
      m->gname = NULL;
  }
  if(m->score)
  {
      free(m->score);
      m->score = NULL;
  }
  if(m->links)
  {
      free(m->links);
      m->links = NULL;
  }
  if(m->upfid)
  {
      free(m->upfid);
      m->upfid = NULL;
  }
  if(m->etype == MAP_ETYPE_TRACK && m->trackname)
  {
      free(m->trackname);
      m->trackname = NULL;
  }
  m->userdata = NULL;
  free(m);
  m = NULL;
}

/* MAP_READER support */
MAP_READER *construct_map_reader()
{
  MAP_READER *mr = (MAP_READER *) malloc(sizeof(MAP_READER));
  memset(mr, 0, sizeof(MAP_READER));

  mr->MIN_WIDTH = 3;
  mr->GAP = 3;
  mr->GROUP_WIDTH = 10;
  mr->MAX_WIDTH = 100;

  mr->gcnt = 0;
  mr->small_group = 0;
  mr->rcnt = 0;
  mr->gMaxTo = 0L;
  mr->has_overlaps = 0;

  mr->vBuf = construct_vector();
  mr->tBuf = construct_vector();
  return mr;
}

void map_reader_flush(MAP_READER * mr)
{
  MAP_ELEMENT *m;

  if(mr->rcnt == 0)
    return;
  if(mr->rcnt == 1)
  {
      if(mr->lastm)
      {
          vector_add_element(mr->vBuf, mr->lastm);
          mr->lastm = NULL;
      }
  }
  else if(mr->gcnt)
  {
      m = construct_map_element();
      m->etype = MAP_ETYPE_GROUP;
      m->gname = duplicate_string(mr->gName);
      if(mr->gcnt > 1 || (mr->gx2 - mr->gx1) >= mr->MAX_WIDTH)
      {
          m->x1 = mr->rx1;
          m->y1 = mr->ry1;
          m->x2 = mr->rx2;
          m->y2 = mr->ry2;
          m->from = mr->rFrom;
          m->to = mr->rTo;
      }
      else
      {
          m->x1 = mr->gx1;
          m->y1 = mr->gy1;
          m->x2 = mr->gx2;
          m->y2 = mr->gy2;
          m->from = mr->gFrom;
          m->to = mr->gTo;
      }
      vector_add_element(mr->vBuf, m);
  }

  mr->rcnt = 0;

  if(mr->lastm)
  {
      delete_map_element(mr->lastm);
      mr->lastm = NULL;
  }
}

void delete_map_reader(MAP_READER * mr)
{
  if(!mr)
    return;
  map_reader_flush(mr);
  delete_vector(mr->vBuf);
  mr->vBuf = NULL;
  delete_vector(mr->tBuf);
  mr->tBuf = NULL;
  if(mr->trackm)
  {
      delete_map_element(mr->trackm);
      mr->trackm = NULL;
  }
  free(mr);
  mr = NULL;
}

void clear_map_elements(VECTOR * v)
{
  int n = v->size;
  int i;
  for (i = 0; i < n; i++)
    delete_map_element((MAP_ELEMENT *) vector_element_at(v, i));
  v->size = 0;
}

MAP_ELEMENT *map_reader_add_annotation(MAP_READER * mr,
                                       int x1, int y1, int x2, int y2,
                                       char *gclass, char *gname, long from, long to, char *score)
{
  MAP_ELEMENT *m = construct_map_element();
  m->etype = MAP_ETYPE_ANNOTATION;
  m->x1 = x1;
  m->y1 = y1;
  m->x2 = x2;
  m->y2 = y2;
  m->gclass = duplicate_string(gclass);
  m->gname = duplicate_string(gname);
  m->from = from;
  m->to = to;
  m->score = duplicate_string(score);
  vector_add_element(mr->tBuf, m);
  return m;
}

void map_reader_consume(MAP_READER * mr, MAP_ELEMENT * m)
{
  int dx, dy;

  dx = m->x2 - m->x1;
  dy = m->y1 - mr->ry1;
  if(dy < 0)
    dy = -dy;
//Modified by Andrei 10/20/04 Overlapping annotations by 1 base TODO
  if(dy > 3)
    mr->gMaxTo = 0L;
  else if((m->from + 0L) <= mr->gMaxTo)
    mr->has_overlaps = 1;
  if(mr->gMaxTo < m->to)
    mr->gMaxTo = m->to;

  if(dx > mr->MIN_WIDTH ||
     ((mr->rx2 - mr->rx1) >= mr->GROUP_WIDTH && !mr->small_group) || (m->x1 - mr->rx2) >= mr->GAP || dy > 3)
  {
      if(mr->rcnt && m->x2 > mr->rx2)
        map_reader_flush(mr);
  }

  mr->ry1 = m->y1;
  mr->ry2 = m->y2;

  if(mr->rcnt)
  {
      if(mr->lastm)
      {
          delete_map_element(mr->lastm);
          mr->lastm = NULL;
      }
      if(mr->rx2 < m->x2)
        mr->rx2 = m->x2;
      if(mr->rTo < m->to)
        mr->rTo = m->to;
      (mr->rcnt)++;
  }
  else
  {
      mr->lastm = m;
      mr->rx1 = m->x1;
      mr->rx2 = m->x2;
      mr->rFrom = m->from;
      mr->rTo = m->to;
      mr->rcnt = 1;
  }
}

int map_element_compare(const void *elem1, const void *elem2)
{
  long ml, mr;
  ml = (*((MAP_ELEMENT **) elem1))->from;
  mr = (*((MAP_ELEMENT **) elem2))->from;
  if(ml == mr)
    return 0;
  return (ml < mr) ? -1 : 1;
}

void map_reader_finish_group(MAP_READER * mr)
{
  VECTOR *v = mr->tBuf;
  int i, sz = v->size;

  if(sz > 0)
  {
      qsort(v->elements, sz, sizeof(void *), map_element_compare);
      for (i = 0; i < sz; i++)
        map_reader_consume(mr, (MAP_ELEMENT *) ((v->elements)[i]));
      v->size = 0;
  }
}

void map_reader_add_group(MAP_READER * mr, char *gname, int x1, int y1, int x2, int y2, long from, long to)
{
  int dx, dy;

  map_reader_finish_group(mr);

  dx = x2 - x1;
  dy = y1 - mr->gy1;
  if(dy < 0)
    dy = -dy;

  if(dx > mr->MIN_WIDTH || (mr->gx2 - mr->gx1) >= mr->GROUP_WIDTH || (x1 - mr->gx2) >= mr->GAP || dy > 3)
  {
      map_reader_flush(mr);
      mr->gcnt = 0;
  }

  mr->small_group = (dx <= mr->MIN_WIDTH);

  if(mr->gcnt)
  {
      if(mr->gx2 < x2)
        mr->gx2 = x2;
      if(mr->gTo < to)
        mr->gTo = to;
      (mr->gcnt)++;
  }
  else
  {
      mr->gx1 = x1;
      mr->gy1 = y1;
      mr->gx2 = x2;
      mr->gy2 = y2;
      mr->gFrom = from;
      mr->gTo = to;
      strcpy(mr->gName, gname);
      mr->gcnt = 1;
  }
}

MAP_ELEMENT *map_reader_add_track(MAP_READER * mr, char *trackname, int x1, int y1, int x2, int y2)
{
//    fprintf(stderr, "calling map_reader_add_track with trackName = %s\n", trackname);
  int i, sz;
  VECTOR *v;
  MAP_ELEMENT *m, *rc = construct_map_element();

  rc->etype = MAP_ETYPE_TRACK;
  rc->trackname = duplicate_string(trackname);
  rc->x1 = x1;
  rc->y1 = y1;
  rc->x2 = x2;
  rc->y2 = y2;

  map_reader_finish_group(mr);
  map_reader_flush(mr);
  mr->gcnt = 0;

  if(mr->trackm)
    delete_map_element(mr->trackm);
  mr->trackm = rc;

  if(mr->has_overlaps)
  {
      v = mr->vBuf;
      sz = v->size;
      for (i = 0; i < sz; i++)
      {
          m = (MAP_ELEMENT *) vector_element_at(v, i);
          if(m->etype == MAP_ETYPE_GROUP)
            m->trackname = rc->trackname;
      }
  }

  mr->gMaxTo = 0L;
  mr->has_overlaps = 0;

  return rc;
}

void map_reader_purge(MAP_READER * mr)
{
  clear_map_elements(mr->vBuf);
  clear_map_elements(mr->tBuf);
  if(mr->trackm)
  {
      delete_map_element(mr->trackm);
      mr->trackm = NULL;
  }
  mr->gcnt = 0;
  mr->rcnt = 0;
}

void print_map_element(MAP_ELEMENT * m, FILE * fout)
{
  off_t mapFileRecPos = ftello(fout) ;
  long mapFileRecSize = 0L ;

  if(m->etype == MAP_ETYPE_TRACK)
  {
    mapFileRecSize += fprintf(fout, "track\t%s\t%d\t%d\t%d\t%d\n", m->trackname, m->x1, m->y1, m->x2, m->y2) ;
  }
  else
  {
      if(m->x1 == m->x2)
      {
        m->x2++ ;
      }
      if(m->etype == MAP_ETYPE_GROUP)
      {
        mapFileRecSize += fprintf(fout, "group\t%s\t", m->gname) ;
      }
      mapFileRecSize += fprintf(fout, "%d\t%d\t%d\t%d", m->x1, m->y1, m->x2, m->y2);

      if(m->etype == MAP_ETYPE_ANNOTATION)
      {
        mapFileRecSize += fprintf(fout, "\t%s\t%s", m->gclass, m->gname);
      }
      mapFileRecSize += fprintf(fout, "\t%ld\t%ld", m->from, m->to);

      if(m->etype == MAP_ETYPE_ANNOTATION)
      {
        mapFileRecSize += fprintf(fout, "\t%s\t%s", m->score, m->upfid);
      }
      if(m->etype == MAP_ETYPE_GROUP)
      {
        mapFileRecSize += fprintf(fout, "\t-");
      }
      if(m->etype == MAP_ETYPE_GROUP && m->trackname)
      {
        mapFileRecSize += fprintf(fout, "\t%s", m->trackname);
      }
      if(m->etype == MAP_ETYPE_ANNOTATION && m->links)
      {
        mapFileRecSize += fprintf(fout, "\t%s", m->links);
      }
      mapFileRecSize += fprintf(fout, "\n");
  }
  // Print the map element rectangle and the position in the map file
  // where we wrote the data above. Uses the jsAreaMapFile GLOBAL.
  jsAreaMap_printRegion(m, mapFileRecPos, mapFileRecSize) ;
}

int break_string_by(char *buf, char sep, char **tgt, int maxn)
{
  int l = 0;
  char *p0 = buf, *p;
  while (l < maxn)
  {
      p = strchr(p0, sep);
      tgt[l++] = p0;
      if(!p || l == maxn)
        break;
      *p++ = 0;
      p0 = p;
  }
  return l;
}

char *trim_new_line(char *buf)
{
  char *p = strchr(buf, '\n');
  if(p)
    *p = '\0';
  p = strchr(buf, '\r');
  if(p)
    *p = '\0';
  return buf;
}

/*
void processMap(FILE *mapFile, FILE *rawFile)
{
	MAP_ELEMENT *m;
	char *ss[10];
	char *buf = NULL;
	int i, l, n;
	int x1, y1, x2, y2;
	long from, to;
	char *gclass, *gname, *score, *trackname;
	MAP_READER *mr = getMapReader();

	if(!mr)
		return;

	buf = (char *) malloc( 0x4000 );
	while( fgets(buf, 0x4000, rawFile) )
	{
		trim_new_line( buf );
		l = break_string_by( buf, '\t', ss, 10 );

		if( !strcmp(ss[0],"track") && l>=2 )
		{
			// Process track record

			trackname = ss[1];
			x1 = y1 = x2 = y2 = 0;
	   		if( l>=6 )
			{
				x1 = atoi( ss[2] );
				y1 = atoi( ss[3] );
				x2 = atoi( ss[4] );
				y2 = atoi( ss[5] );
			}
			m = map_reader_add_track( mr, trackname, x1, y1, x2, y2 );

			// print track element at the beginning of the track, not at the end
			print_map_element( m, mapFile );

			  // print the other elements in this track
			n = map_reader_get_count( mr );
			for( i=0; i<n; i++ )
			{
				m = map_reader_element_at( mr, i );

				print_map_element( m, mapFile );
			}

			// Purge map elements from the map reader
			map_reader_purge( mr );
		}
		else if( !strcmp(ss[0],"group") && l>=8 )
		{
			// Process group record

			gname = ss[1];
			x1 = atoi( ss[2] );
			y1 = atoi( ss[3] );
			x2 = atoi( ss[4] );
			y2 = atoi( ss[5] );
			from = atol( ss[6] );
			to = atol( ss[7] );

			map_reader_add_group( mr, gname, x1, y1, x2, y2, from, to );
		}
		else if( atoi(ss[0])>0 && l>=9 )
		{
			// process annotation record

			x1 = atoi( ss[0] );
			y1 = atoi( ss[1] );
			x2 = atoi( ss[2] );
			y2 = atoi( ss[3] );
			gclass = ss[4];
			gname = ss[5];
			from = atol( ss[6] );
			to = atol( ss[7] );
			score = ss[8];

			m = map_reader_add_annotation( mr, x1, y1, x2, y2, gclass, gname, from, to, ss[8]);

			// Instead of setting links here set m->userdata to point to your own
			// object containing the info about this annotation record,
			// for later use to decode the links before printing - since not all
			// annotation records will be actually printed.

			if( l > 9 ) m->links = duplicate_string( ss[9] );
		}
	}
}
*/
