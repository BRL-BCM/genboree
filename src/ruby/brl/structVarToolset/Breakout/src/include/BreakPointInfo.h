#ifndef BreakPointInfo_H______
#define BreakPointInfo_H______

#include "MatePairIndex.h"

struct BreakPointInfo {
	MatePairContainer *matePairsContainer;

	BreakPointInfo();
	~BreakPointInfo();
	int addMatePair(MatePairInfo* mateInfo);
	int addMatePair(guint32 pos1, guint32 strand1, guint32 mismatches1,
						guint32 _chr2, guint32 pos2, guint32 strand2, guint32 mismatches2,
						MateMappingStatus mateType, char* mateId);
	void dumpBreakPoint( guint32 chr1, FILE* outFilePtr, int flag=1);
	guint32 getNumberOfMatepairs();
	void reset();
	guint32 chr1;
	guint32 pos1Start;
	guint32 pos1Stop;
	guint32 pos2Start;
	guint32 pos2Stop;
	guint32 chr2;
	guint32 experimentId;
	guint32 minInsert;
	guint32 maxInsert;
	int sameStrand;
};


struct BreakPointContainer {
	GSList** globalBreakPointPool;
	BreakPointContainer (GSList** _globalBreakPointPool);
	~BreakPointContainer ();
	int addBreakPoint(BreakPointInfo* breakpointInfo);
	guint32 pos1Start;
	guint32 pos1Stop;
	guint32 pos2Start;
	guint32 pos2Stop;
	void reset();
	BreakPointInfo **breakpointArray;
	guint32 numberOfBreakPoints;
	guint32 containerCapacity;
	void dumpContainer(FILE* outFilePtr);
};

#endif
