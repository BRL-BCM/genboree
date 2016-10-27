include ../../Makefile.include
UTILS_INCLUDES=$(GLIB_INCLUDE)  -I. -I../include
COMPILE_FLAGS=$(UTILS_INCLUDES) $(COMMON_COMPILE_FLAGS)
TARGETS=libSplitCall.a

all: $(TARGETS)

VPATH=.
libSplitCall_OBJECTS = BRLGenericUtils.o MatePairIndex.o BreakPointInfo.o AnnotationIndex.o \
                      StringCounter.o ExperimentClusters.o

libSplitCall.a: $(libSplitCall_OBJECTS)
	$(AR) -r $@ $+

%.o: %.cc
	$(CXX) $(COMPILE_FLAGS) -o $@ -c $<

clean:
	rm -f *.o $(TARGETS)
