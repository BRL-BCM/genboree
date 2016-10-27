include ../../Makefile.include
TARGETS=genericMappingsSplitter.exe insertCollector.exe selectInconsistentMatepairs.exe
COMPILE_FLAGS= $(COMMON_COMPILE_FLAGS) -Wall  $(GLIB_INCLUDE) -D_LARGEFILE64_SOURCE -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -I. -I../include
all: $(TARGETS)

VPATH=. 
genericFrontEnd_OBJECTS= genericFrontEnd.o FrontEndSplitter.o
solidMatepairAnalyzer_OBJECTS= solidMatepairs.o SolidMatepairsAnalyzer.o
insertCollector_OBJECTS= insertCollector.o InsertCollector.o
selectInconsistentMatepairs_OBJECTS = selectInconsistentMatepairs.o SelectInconsistentMatepairs.o

genericMappingsSplitter.exe: $(genericFrontEnd_OBJECTS) 
	$(CXX) $(COMPILE_FLAGS) -o $@ $+ -L../libs -lSplitCall $(GLIB_LIB) -lpthread  -lm
	cp -f $@ ../../bin
  
solidMatepairAnalyzer.exe: $(solidMatepairAnalyzer_OBJECTS) 
	$(CXX) $(COMPILE_FLAGS) -o $@ $+ -L../libs -lSplitCall $(GLIB_LIB) -lpthread  -lm
	cp -f $@ ../../bin
  
insertCollector.exe: $(insertCollector_OBJECTS) 
	$(CXX) $(COMPILE_FLAGS) -o $@ $+ -L../libs -lSplitCall $(GLIB_LIB) -lpthread  -lm
	cp -f $@ ../../bin
  
selectInconsistentMatepairs.exe: $(selectInconsistentMatepairs_OBJECTS)
	$(CXX) $(COMPILE_FLAGS) -o $@ $+ -L../libs -lSplitCall $(GLIB_LIB) -lpthread  -lm
	cp -f $@ ../../bin

%.o: %.cc
	$(CXX) $(COMPILE_FLAGS) -o $@ -c $< 

clean:
	rm -f *.o $(TARGETS)
