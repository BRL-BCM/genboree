#ifndef Cluster__File__
#define Cluster__File__
#include <stdio.h>
#include "BreakPointInfo.h"

#define MAX_CLUSTER_SIZE 16*1024

class ExperimentClusters {
	char* fileName;
	FILE* fileStream;
	GSList** breakpointPool;
	BreakPointInfo* topBreakpoint;
	int experimentId;
	guint32 minInsert, maxInsert;
	char* buffer;
public:
	BreakPointInfo* getTopBreakpoint();
	BreakPointInfo* advanceBreakPoint();
	ExperimentClusters(char* fileName, guint32 _experimentId,
										 guint32 _minInsert, guint32 _maxInsert,
										 GSList** _breakpointPool);
	~ExperimentClusters();
	int setupClusterFile();
};

#endif
