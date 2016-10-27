#include <stdio.h>
#include <pthread.h>
#include <time.h>
#include <string.h>
#include <assert.h>
#include <math.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>

#include "generic_debug.h"
#include "UniversalBreakCaller.h"

int main(int argc, char *argv[]) {
  UniversalBreakCaller *breakCaller= new UniversalBreakCaller();
  if (breakCaller->parseParams(argc, argv)) {
		delete breakCaller;
		exit(1);
	}
  breakCaller->callBreaks();
  // delete breakCaller;
  return 0;
}
