CC=gcc
STATICFLAGS = -fPIC -O3 --static
CFLAGS =  -O3 -fPIC
#STATICFLAGS =  -pg --static
#CFLAGS =  -pg -O0
#STATICFLAGS = -g -Wall --static
#CFLAGS = -g -Wall
ADVICEFLAG=-DPROVIDE_ADVICE=0
DIRECTFLAG=-DUSEODIRECTFLAG=0
ESFLAGS= -D_GNU_SOURCE $(ADVICEFLAG) $(DIRECTFLAG)
#########################################################
# TCMALLOC RELATED SETTINGS
#########################################################
# If this is used during compilation (default is TMICROMALLOC), you will get a heap checker and heap profiler (slower?)
# - if your tcmalloc library was installed outside of your LD_LIBRARY_PATH, you'll need a -L<dir> here as well
#   . eg TMALLOC = -L/usr/lib64  -ltcmalloc
TMALLOC = -ltcmalloc
# This will just use tcmalloc without the heap checker/profiler (may/may not be faster allocs; default uses this)
# - if your tcmalloc library was installed outside of your LD_LIBRARY_PATH, you'll need a -L<dir> here as well
#   . eg TMICROMALLOC = -L/usr/lib64  -ltcmalloc_minimal
TMICROMALLOC = -ltcmalloc_minimal
# Use this for google's CPU profiler (default no)
# - if your tcmalloc library was installed outside of your LD_LIBRARY_PATH, you'll need a -L<dir> here as well
#   . eg PROFILE = -L/usr/lib64  -lprofiler
PROFILE = -lprofiler
#########################################################

BIGFLAG = -D_LARGEFILE64_SOURCE -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -D_LFS_LARGEFILE -D_LFS64_LARGEFILE -D_LFS64_STDIO -D_LFS64_ASYNCHRONOUS_IO
GLIB_INCLUDE=`pkg-config --cflags glib-2.0`
GLIB_LIB=`pkg-config --libs glib-2.0`
#JSONINCLUDES=`pkg-config --cflags gee-1.0`
#GEEINCLUDES=`pkg-config --cflags json-glib-1.0`
#JSONLIBS=`pkg-config --libs gee-1.0`
#GEELIBS=`pkg-config --libs json-glib-1.0`
#INCLUDEDIR= -I./include $(JSONINCLUDES) $(GEEINCLUDES)  $(GLIB_INCLUDE)  
INCLUDEDIR= -I./include $(GLIB_INCLUDE)  
LIBMYSQLDIR=/usr/local/brl/local/mysql/lib
# Decide what libs to link against (eg for tcmalloc use, profiling, etc)
LIBGENBOREE=-L./lib -loptimizedGB
#LIBGENBOREE= $(TMALLOC) -L./lib -loptimizedGB
#LIBGENBOREE= $(TMICROMALLOC) -L./lib -loptimizedGB
#LIBGENBOREE= $(PROFILE) -L./lib -loptimizedGB

# If compiling against any Intel-ICC special libraries, point to them here.
# NOTE: won't work on AMD!
#LIBICC=/usr/local/brl/local/lib/intel-icc

#LIBS = $(LDFLAGS) $(JSONLIBS) $(GEELIBS) $(LIBGENBOREE) -lmysys -lmystrings -lmyisam -lmysqlclient -lpcre -lexpat -lgd -lfreetype -lpng -ljpeg -lglib-2.0 -liconv -lz -lm -lc 
LIBS = $(LDFLAGS) $(LIBGENBOREE) -lmysys -lmystrings -lmyisam -lmysqlclient -lpcre -lexpat -lgd -lfreetype -lpng -ljpeg -lglib-2.0 -liconv -lz -lm -lc 

all: libs myTest 

myTest:	myTest.c
	$(CC) $(CFLAGS) $(ESFLAGS) $(BIGFLAG) $(INCLUDEDIR) $(CPPFLAGS) -o myTest.exe myTest.c $(LIBS) 

static: libs
	$(CC) $(STATICFLAGS) $(ESFLAGS) $(BIGFLAG) $(INCLUDEDIR) $(CPPFLAGS) -o static_myTest.exe myTest.c $(LIBS) 

install:
	cp myTest.exe /usr/local/brl/local/apache/htdocs/webapps/java-bin/WEB-INF/myTest.exe
	$(RM) *.o *.gif *.map core*

libs:
	cd optimizedLib;make

clean:
	$(RM) *.o  *.gif *.map  *.raw core core.*

cleanall:
	$(RM) *.o  *.gif *.map *.raw myTest.exe core core.*

runtest:
	./myTest.exe -i 12 -t 600000000000 -r 77 -u 7 -e chr1 -a -n test -b ./ 

