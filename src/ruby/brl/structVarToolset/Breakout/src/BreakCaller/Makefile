include ../../Makefile.include
TARGETS=breakCaller.exe
COMPILE_FLAGS= $(COMMON_COMPILE_FLAGS) -Wall  $(GLIB_INCLUDE) -D_LARGEFILE64_SOURCE -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -I. -I../include
all: $(TARGETS)

VPATH=. 
breakCaller_OBJECTS=breakCaller.o UniversalBreakCaller.o 

 
breakCaller.exe: $(breakCaller_OBJECTS) 
	$(CXX) $(COMPILE_FLAGS) -o $@ $+ -L../libs -lSplitCall $(GLIB_LIB) -lpthread  -lm
	cp -f $@ ../../bin
  
%.o: %.cc
	$(CXX) $(COMPILE_FLAGS) -o $@ -c $< 

clean:
	rm -f *.o $(TARGETS)
