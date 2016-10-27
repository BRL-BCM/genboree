CC=gcc
AROPTIONS = -rcs
CFLAGS =  -O3
#CFLAGS =  -pg -O0
#CFLAGS = -g -Wall
VALAC = valac -C
SOURCES = generatingTrackDefaults.vala
LIBS = --pkg json-glib-1.0 --pkg gee-1.0
ADVICEFLAG=-DPROVIDE_ADVICE=0
DIRECTFLAG=-DUSEODIRECTFLAG=0
VALAOBJ=generatingTrackDefaults.o
#JSONINCLUDES=`pkg-config --cflags gee-1.0`
#GEEINCLUDES=`pkg-config --cflags json-glib-1.0`
ESFLAGS= -D_GNU_SOURCE $(ADVICEFLAG) $(DIRECTFLAG)
GLIB_INCLUDE=`pkg-config --cflags glib-2.0`
BIGFLAG = -D_LARGEFILE64_SOURCE -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -D_LFS_LARGEFILE -D_LFS64_LARGEFILE -D_LFS64_STDIO -D_LFS64_ASYNCHRONOUS_IO
INCLUDES = -I../include

#OBJECTS = optimizedHashManager.o optimizedFunctions.o optimizedGlobals.o visibilityParser.o map_reader.o drawFunctions.o highDensityTracks.o generatingTrackDefaults.o
OBJECTS = optimizedHashManager.o optimizedFunctions.o optimizedGlobals.o visibilityParser.o map_reader.o drawFunctions.o highDensityTracks.o jsAreaMap.o

COMPILE = $(CC) $(CFLAGS)  $(ESFLAGS) $(CPPFLAGS) $(GLIB_INCLUDE) $(BIGFLAG) $(INCLUDES)

#libgenboree.a: valaobject $(OBJECTS)
libgenboree.a: $(OBJECTS)
	ar $(AROPTIONS) liboptimizedGB.a $(OBJECTS)
	mv liboptimizedGB.a ../lib
	$(RM) *.o

.c.o:
	$(COMPILE) -c $<

#valaobject: $(SOURCES)
#	$(VALAC) $(LIBS) $^ -o $(VALAOBJ)

clean:
	$(RM) *.o *.a
 
