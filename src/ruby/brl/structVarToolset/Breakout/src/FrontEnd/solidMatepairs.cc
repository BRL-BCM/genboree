#include <stdio.h>

#include "SolidMatepairsAnalyzer.h"

int main(int argc, char *argv[]) {
  SolidMatepairsAnalyzer* solidMatepairsAnalyzer = new SolidMatepairsAnalyzer();
  int result = 0;
  
  result = solidMatepairsAnalyzer->parseParams(argc, argv);
  
  if (!result) {
    result = solidMatepairsAnalyzer->analyze();
  }
  
  delete solidMatepairsAnalyzer;
  return result;
}

