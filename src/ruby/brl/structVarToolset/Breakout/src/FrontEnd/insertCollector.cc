#include <stdio.h>
#include <stdlib.h>

#include "InsertCollector.h"

int main(int argc, char* argv[]) {
  int result = 0;
  fprintf(stderr, "Insert Collector started\n");
  InsertCollector* insertCollector = new InsertCollector();
  result = insertCollector->parseParams(argc, argv);
  if (!result) {
    result = insertCollector->collectInserts();
  }
  delete insertCollector;
  fprintf(stderr, "Insert Collector done\n");
  return result;
}

