#ifndef __StringCounter__H_
#define __StringCounter__H_

#include <glib.h>

struct StringOccurences {
  char* label;
  guint32 count;
  guint32 index;
};


class StringCounter {
protected:
  GHashTable *labelsHash;
  // GTree *labelsTree;
  guint32 occurencesCapacity;
public:
  StringOccurences* stringOccurences;
  guint32 numberOfOccurences;
public:
  /** Constructor.*/
  StringCounter();
  /** Destructor, free up resources.*/
  ~StringCounter();
  /** Check if a string was already observed and return its index.
   * By convention, no string can have index 0.*/
  guint32 stringExists(char* label);
  /** Add an occurence of a string to the StringCounter.*/
  guint32 addString(char* label, guint32 count);
  
  guint32 addStringDebug(char* label, guint32 count);
  int checkForCorruption();
  /** Reset occurences value for all strings in the StringCounter.*/
  void reset(guint32 value);
  /** Set the value of an individual string entry.*/
  void setStringValue(guint32 index, guint32 value);
};

#endif

