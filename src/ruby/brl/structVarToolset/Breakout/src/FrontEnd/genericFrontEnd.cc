#include <stdio.h>
#include <stdlib.h>

#include "FrontEndSplitter.h"

int main(int argc, char* argv[]) {
	int result = 0;
  MappingsSplitter * mappingsSplitter = new MappingsSplitter();
	result = mappingsSplitter->parseParams(argc, argv);
	if (!result) {
		result = mappingsSplitter->split();
	}
	delete mappingsSplitter;
  fprintf(stderr, "SOLID front end\n");
  return result;
}

