#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "generic_debug.h"
#include "StringCounter.h"

int myStrcmp(void* p1, void* p2) {
  return strcmp((char*)p1, (char*)p2);
}

/** Constructor.*/
StringCounter::StringCounter() {
 labelsHash = g_hash_table_new(g_str_hash, g_str_equal);
 /*labelsTree = g_tree_new((GCompareFunc)myStrcmp);
  if (labelsTree==NULL) {
    fprintf(stderr, "could not allocate labels hash table\n");
    exit(2);
  }*/
  occurencesCapacity = 11;
  numberOfOccurences = 0;
  stringOccurences = (StringOccurences*) malloc(sizeof(StringOccurences)*occurencesCapacity);
  if (stringOccurences==NULL) {
    fprintf(stderr, "could not allocate string occurences array\n");
    exit(2);
  }
}

/** Destructor, free up resources.*/
StringCounter::~StringCounter() {
  free(stringOccurences);
  g_hash_table_destroy(labelsHash);
}

/** Check if a string was already observed and return its index.
* By convention, no string can have index 0.*/
guint32 StringCounter::stringExists(char* label) {
  guint32* indexPtr =  (guint32*) g_hash_table_lookup(labelsHash, label);
  /*StringOccurences* lookupResult =  (StringOccurences*) g_tree_lookup(labelsTree, label);*/
  if (indexPtr==NULL) {
    return 0;
  } else {
    return *indexPtr;
  }
  /*
  guint32 i;
  for (i=1;  i<numberOfOccurences; i++) {
    if (!strcmp(stringOccurences[i].label, label)) {
      return i;
    }
  }
  */
  return 0;
}

/** Add an occurence of a string to the StringCounter.
@return index for the current label
*/
guint32 StringCounter::addString(char* label, guint32 count) {
  guint32* indexPtr =  (guint32*) g_hash_table_lookup(labelsHash, label); 
  
  if (indexPtr==NULL) {
    numberOfOccurences++;
    if (numberOfOccurences>=(occurencesCapacity-1)) {
      occurencesCapacity = occurencesCapacity*5/4;
      stringOccurences = (StringOccurences*) realloc(stringOccurences, sizeof(StringOccurences)*occurencesCapacity);
      if (stringOccurences==NULL) {
        fprintf(stderr, "could not reallocate stringOccurences \n");
        exit(2);
      }
    }
    stringOccurences[numberOfOccurences].label= g_strdup(label);
    if (stringOccurences[numberOfOccurences].label==NULL) {
      fprintf(stderr, "null label %s!\n", label);
      exit(2);
    }
    stringOccurences[numberOfOccurences].count = count;
    stringOccurences[numberOfOccurences].index = numberOfOccurences;
    indexPtr = (guint32*) malloc(sizeof(guint32));
    *indexPtr = numberOfOccurences;
    g_hash_table_insert(labelsHash, g_strdup(label), indexPtr);
    return stringOccurences[numberOfOccurences].index ;
  } else {
    stringOccurences[*indexPtr].count += count;
    return stringOccurences[*indexPtr].index;
  }
}

int StringCounter::checkForCorruption() {
  guint32 i;
  return 0;
  for (i=1; i<=numberOfOccurences; i++) {
    if (stringOccurences[i].index>2000) {
      // fprintf(stderr, "check for corruption at index %d read index %d\n", i,  stringOccurences[i].index);
      // fflush(stderr);
      return 1;
    }
  }
  return 0;
}


/** Add an occurence of a string to the StringCounter.
@return index for the current label
*/
guint32 StringCounter::addStringDebug(char* label, guint32 count) {
  // StringOccurences* lookupResult =  (StringOccurences*) g_hash_table_lookup(labelsHash, label);
  /*if (!strcmp(label, "B4A")) {
    fprintf(stderr, "adding B4A\n");
  }*/
  guint32 i, index;
  for (i=1, index=0;  i<=numberOfOccurences; i++) {
    fprintf(stderr, "[%d] comparing %s to %s\n", i, stringOccurences[i].label, label);
    if (!strcmp(stringOccurences[i].label, label)) {
      index=i;
      break;
    }
  }
  
  //StringOccurences* lookupResult =  (StringOccurences*) g_tree_lookup(labelsTree, label);
  if (index==0) {
    numberOfOccurences++;
    if (numberOfOccurences>=(occurencesCapacity-1)) {
      occurencesCapacity = occurencesCapacity*5/4;
      stringOccurences = (StringOccurences*) realloc(stringOccurences, sizeof(StringOccurences)*occurencesCapacity);
      if (stringOccurences==NULL) {
        fprintf(stderr, "could not reallocate stringOccurences \n");
        exit(2);
      }
    }
    stringOccurences[numberOfOccurences].label= g_strdup(label);
    if (stringOccurences[numberOfOccurences].label==NULL) {
      fprintf(stderr, "null label %s!\n", label);
      exit(2);
    }
    stringOccurences[numberOfOccurences].count = count;
    stringOccurences[numberOfOccurences].index = numberOfOccurences;
    if (stringOccurences[numberOfOccurences].index >10000 ) {
      fprintf(stderr, "corruption in stringCounter %s:%d\n", __FILE__, __LINE__);
    }
    /*if (!strcmp(label, "B4A")) {
      fprintf(stderr, "[%x] added B4A at address %x, index %d\n",
              this,
              &stringOccurences[numberOfOccurences], numberOfOccurences);
    }
    */
    return stringOccurences[numberOfOccurences].index ;
  } else {
    stringOccurences[index].count += count;
    /*if (!strcmp(label, "B4A")) {
      fprintf(stderr, "found B4A in StringCounterat   (%x,%x) index %d\n",
              &stringOccurences[0],
              &stringOccurences[occurencesCapacity-1],
              stringOccurences[index].index);
    }
    */
    if (stringOccurences[index].index >10000 ) {
      fprintf(stderr, "corruption in stringCounter %s:%d at   (%x,%x) index %d %d\n",
              __FILE__, __LINE__,
              &stringOccurences[0],
              &stringOccurences[occurencesCapacity-1],
              index, stringOccurences[index].index);
    }
    return stringOccurences[index].index;
  }
}


void StringCounter::reset(guint32 value) {
  guint32 idx;
  for (idx=1; idx<=numberOfOccurences; idx++) {
    stringOccurences[idx].count = value; 
  }
}

/** Set the value of an individual string entry.*/
void StringCounter::setStringValue(guint32 index, guint32 value) {
  if (index>=1 && index<=numberOfOccurences) {
    stringOccurences[index].count = value;
  }
}
