#ifndef __Generic_Utils___H_
#define __Generic_Utils___H_

#include <stdio.h>
#include <glib.h>

class BRLGenericUtils {
public:
  static FILE* openTextGzipBzipFile(char* fileName);
  static void printNow(FILE* outPtr);
  static int parseCommaSeparatedList(char* commaSeparatedList,
                                     char*** stringArray, guint32 *numberOfStrings);
};


#endif
