#include <stdio.h>
#include <stdlib.h>

#include "SelectInconsistentMatepairs.h"

int main(int argc, char* argv[]) {
  int result = 0;
  fprintf(stderr, "Matepair Collector started\n");
  SelectInconsistentMatepairs* matepairSelector= new SelectInconsistentMatepairs();
  result = matepairSelector->parseParams(argc, argv);
  if (!result) {
    result = matepairSelector->analyzeMatePairs();
  }
  delete matepairSelector;
  fprintf(stderr, "Matepair Collector done\n");
  return result;
}

