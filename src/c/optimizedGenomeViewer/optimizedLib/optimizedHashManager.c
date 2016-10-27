#include "optimizedGB.h"
#include "optimizedFunctions.h"
#include "map_reader.h"

static GHashTable *featureTypeHash = NULL;      //contains "fmethod:fsource" as the key and "database:typeid" as the value
static int isFeatureTypeHashInitialized = 0;
static GHashTable *typeId2FeatureTypeHash = NULL;       //contains "database:typeid" as the key and "fmethod:fsource" as the value
static int isTypeId2FeatureTypeHashInitialized = 0;
static GHashTable *typeId2PermissionHash = NULL;        // contains "database:typeid" as the key and 1 for permission to read and 0 for not permission
static int isTypeId2PermissionHashInitialized = 0;
static GHashTable *gClassHash = NULL;   //contains "database:gid" as the key and "gclass" as the value
static int isGClassHashInitialized = 0;
static GHashTable *groupHash = NULL;    //contains "trackName:gclass:groupName" as the key and a unique groupId for the group in the track
static int isGroupHashInitialized = 0;
static GHashTable *groupIds2GroupHash = NULL;   //contains unique groupId as the key and GroupStructure as the value
static int isGroupIds2GroupHashInitialized = 0;
static GHashTable *groupId2groupStartHash = NULL;       //contains unique groupId as the key and start of the group long as the value
static int isGroupId2groupStartHashInitialized = 0;
static GHashTable *trackName2TrackHash = NULL;  // contains trackName as the key and Track Structure as the value
// static int isTrackName2TrackHashInitialized = 0;
static GHashTable *typeIdHash = NULL;   //contains
static int isTypeIdHashInitialized = 0;
static GHashTable *groups2TrackHash = NULL;
static int isGroups2TrackHashInitialized = 0;
static GHashTable *tagHash = NULL;
static int isTagHashInitialized = 0;
static GHashTable *linkInfoHash = NULL;
static int isLinkInfoHashInitialized = 0;
static GHashTable *allFmethodFsource = NULL;
static int isAllFmethodFsourceInitialized = 0;
static GHashTable *allSortedFmethodFsource = NULL;
static int isAllSortedFmethodFsourceInitialized = 0;
static GHashTable *featureToGclassHash = NULL;  //contains trackName as the key and a list colon separated of ClassNames
static int isFeatureToGclassHashInitialized = 0;
static GHashTable *database2HostHash = NULL;    // contains the name of the database as key and the serverName where the db is located 09/13/07
static int isDatabase2HostHashInitialized = 0;
static GHashTable *database2ConnectionHash = NULL;      //contains a connection to a database the key is the databaseName and the vaule is the connection To be implemented 09/14/07
static int isDatabase2ConnectionHashInitialized = 0;
// static GHashTable *ftypeid2AttributeDisplayHash = NULL; // contains attributes associated with the ftypeId
//   static int isFtypeid2AttributeDisplayHashInitialized = 0;
static GHashTable *ftypeid2AttributeHash = NULL;        // contains attributes associated with the ftypeId
static int isFtypeid2AttributeHashInitialized = 0;
static int isAttNameIdHashInitializedTemplate = 0;
static GHashTable *attNameIdHashTemplate = NULL;
static int isAttValueIdHashInitializedTemplate = 0;
static GHashTable *attValueIdHashTemplate = NULL;
static int isAttNameIdHashInitializedUser = 0;
static GHashTable *attNameIdHashUser = NULL;
static int isAttValueIdHashInitializedUser = 0;
static GHashTable *attValueIdHashUser = NULL;


void destroyAllHashesInHashManager(void)
{
  if(isFeatureTypeHashInitialized == 1)
  {
      g_hash_table_destroy(featureTypeHash);
      isFeatureTypeHashInitialized = 0;
  }
  if(isTypeId2FeatureTypeHashInitialized == 1)
  {
      g_hash_table_destroy(typeId2FeatureTypeHash);
      isTypeId2FeatureTypeHashInitialized = 0;
  }
  if(isTypeId2PermissionHashInitialized == 1)
  {
      g_hash_table_destroy(typeId2PermissionHash);
      isTypeId2PermissionHashInitialized = 0;
  }
  if(isGClassHashInitialized == 1)
  {
      g_hash_table_destroy(gClassHash);
      isGClassHashInitialized = 0;
  }
  if(isGroupHashInitialized == 1)
  {
      g_hash_table_destroy(groupHash);
      isGroupHashInitialized = 0;
  }

/*     if(isGroupIds2GroupHashInitialized == 1)
   {
        g_hash_table_destroy(groupIds2GroupHash);
        isGroupIds2GroupHashInitialized = 0;
   }
     if(isGroupId2groupStartHashInitialized == 1)
   {
        g_hash_table_destroy(groupId2groupStartHash);
        isGroupId2groupStartHashInitialized = 0;
   } 
     if(isTrackName2TrackHashInitialized == 1)
   {
        g_hash_table_destroy(trackName2TrackHash);
        isTrackName2TrackHashInitialized = 0;
   }*/
  if(isTypeIdHashInitialized == 1)
  {
      g_hash_table_destroy(typeIdHash);
      isTypeIdHashInitialized = 0;
  }
  if(isGroups2TrackHashInitialized == 1)
  {
      g_hash_table_destroy(groups2TrackHash);
      isGroups2TrackHashInitialized = 0;
  }
  if(isTagHashInitialized == 1)
  {
      g_hash_table_destroy(tagHash);
      isTagHashInitialized = 0;
  }
  if(isLinkInfoHashInitialized == 1)
  {
      g_hash_table_destroy(linkInfoHash);
      isLinkInfoHashInitialized = 0;
  }
  if(isAllFmethodFsourceInitialized == 1)
  {
      g_hash_table_destroy(allFmethodFsource);
      isAllFmethodFsourceInitialized = 0;
  }
  if(isAllSortedFmethodFsourceInitialized == 1)
  {
      g_hash_table_destroy(allSortedFmethodFsource);
      isAllSortedFmethodFsourceInitialized = 0;
  }
  if(isFeatureToGclassHashInitialized == 1)
  {
      g_hash_table_destroy(featureToGclassHash);
      isFeatureToGclassHashInitialized = 0;
  }
  if(isDatabase2HostHashInitialized == 1)
  {
      g_hash_table_destroy(database2HostHash);
      isDatabase2HostHashInitialized = 0;
  }
  if(isDatabase2ConnectionHashInitialized == 1)
  {
      g_hash_table_destroy(database2ConnectionHash);
      isDatabase2ConnectionHashInitialized = 0;
  }
  if(isFtypeid2AttributeHashInitialized == 1)
  {
      g_hash_table_destroy(ftypeid2AttributeHash);
      isFtypeid2AttributeHashInitialized = 0;
  }
}

void setFtypeid2AttributeHash(void)
{
  if(isFtypeid2AttributeHashInitialized == 0)
  {
      ftypeid2AttributeHash = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, eraseDoubleHash);
      isFtypeid2AttributeHashInitialized = 1;
  }
}

GHashTable *getFtypeid2AttributeHash(void)
{
  if(isFtypeid2AttributeHashInitialized == 0)
    setFtypeid2AttributeHash();

  return ftypeid2AttributeHash;
}

void setFtypeid2AttributeDisplayHash(void)
{
  ftypeid2AttributeHash = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, eraseDoubleHash);
}

GHashTable *getFtypeid2AttributeDisplayHash(void)
{
  return ftypeid2AttributeHash;
}

void setFeatureTypeHash(void)
{
  if(isFeatureTypeHashInitialized == 0)
  {
      featureTypeHash = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
      isFeatureTypeHashInitialized = 1;
  }
}

GHashTable *getFeatureTypeHash(void)
{
  if(isFeatureTypeHashInitialized == 0)
    setFeatureTypeHash();
  return featureTypeHash;
}

GHashTable *getTypeId2FeatureTypeHash(void)
{
  if(isTypeId2FeatureTypeHashInitialized == 0)
    setTypeId2FeatureTypeHash();
  return typeId2FeatureTypeHash;
}

void setTypeId2FeatureTypeHash(void)
{
  if(isTypeId2FeatureTypeHashInitialized == 0)
  {
      typeId2FeatureTypeHash = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
      isTypeId2FeatureTypeHashInitialized = 1;
  }
}

GHashTable *getTypeId2PermissionHash(void)
{
  if(isTypeId2PermissionHashInitialized == 0)
    setTypeId2PermissionHash();

  return typeId2PermissionHash;
}

void setTypeId2PermissionHash(void)
{
  if(isTypeId2PermissionHashInitialized == 0)
  {
      typeId2PermissionHash = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
      isTypeId2PermissionHashInitialized = 1;
  }
}

void setGclassHash(void)
{
  if(isGClassHashInitialized == 0)
  {
      gClassHash = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
      isGClassHashInitialized = 1;
  }
}

GHashTable *getGclassHash(void)
{
  if(isGClassHashInitialized == 0)
    setGclassHash();

  return gClassHash;
}

GHashTable *getAttNameIdHashTemplate(void)
{
  if(isAttNameIdHashInitializedTemplate == 0)
  {
    setAttNameIdHashTemplate();
  }
  return attNameIdHashTemplate;
}

GHashTable *getAttValueIdHashTemplate(void)
{
  if(isAttValueIdHashInitializedTemplate == 0)
  {
    setAttValueIdHashTemplate();
  }
  return attValueIdHashTemplate;
}

GHashTable *getAttNameIdHashUser(void)
{
  if(isAttNameIdHashInitializedUser == 0)
  {
    setAttNameIdHashUser();
  }
  return attNameIdHashUser;
}

GHashTable *getAttValueIdHashUser(void)
{
  if(isAttValueIdHashInitializedUser == 0)
  {
    setAttValueIdHashUser();
  }
  return attValueIdHashUser;
}

GHashTable *getFeatureToGclassHash(void)
{
  if(isFeatureToGclassHashInitialized == 0)
    setFeatureToGclassHash();

  return featureToGclassHash;
}

void setFeatureToGclassHash(void)
{
  GHashTable *myFeatureTypeHash;
  char *theKey;
  char *tempGclassNames = NULL;
  GList *listOfTracks;

  myFeatureTypeHash = getFeatureTypeHash();

  if(isFeatureToGclassHashInitialized == 0)
  {
      featureToGclassHash = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
      isFeatureToGclassHashInitialized = 1;
  }

  listOfTracks = g_hash_table_get_keys(myFeatureTypeHash);

  while (listOfTracks)
  {
      theKey = (char *)listOfTracks->data;
      tempGclassNames = getClassesArrayFmethodFsourceMainDatabase(theKey);
      if(tempGclassNames == NULL)
        tempGclassNames = strdup(" ");

      g_hash_table_insert(featureToGclassHash, g_strdup(theKey), g_strdup(tempGclassNames));

      free(tempGclassNames);
      tempGclassNames = NULL;
      listOfTracks = g_list_next(listOfTracks);
  }

  return;
}

// TODO may be a redo MLGG 11/12/08
char *getClassesArrayFmethodFsourceMainDatabase(char *fmethodFsource)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection = NULL;
  MYSQL mysql;
  MYSQL_RES *sqlresult = NULL;
  MYSQL_ROW row = NULL;
  int ftypeid = 0;
  char *databaseName = NULL;
  char *fmethod = NULL;
  char *fsource = NULL;
  long num_rows = 0;
  char **listOfGclasses = NULL;
  int ii = 0;
  int totalLength = 0;
  char *finalArrayWithGclasses = NULL;
  int numberGenboreeDatabases = getNumberDatabases();
  int counter = 0;
  databaseName = getDatabaseFromId(0);
  if(databaseName == NULL)
    return NULL;

  fmethod = getNameSemicolonSeparatedWord(fmethodFsource, 0);
  fsource = getNameSemicolonSeparatedWord(fmethodFsource, 1);

  if(!fmethod || !fsource)
  {
      fprintf(stderr, "Unable to split fmethod from fsource in function "
              "getClassesArrayFmethodFsourceMainDatabase! fmethodFsource = %s\n", fmethodFsource);
      fflush(stderr);
      return NULL;
  }
  while (numberGenboreeDatabases > counter)
  {
      ftypeid = getftypeidFromFmethodFsource(getDatabaseFromId(counter), fmethod, fsource);

      if(ftypeid < 1)
      {
          counter++;
          continue;
      }
      else
        break;
  }

  if(ftypeid < 1)
  {
      free(fmethod);
      fmethod = NULL;
      free(fsource);
      fsource = NULL;
      return NULL;
  }
  databaseName = getDatabaseFromId(counter);
  resetLocalConnection(databaseName);
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);

  sprintf(sqlbuff, "SELECT gclass.gclass FROM gclass, ftype2gclass where ftype2gclass.ftypeid = %d "
          "AND gclass.gid = ftype2gclass.gid", ftypeid);

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
      fprintf(stderr, "Error querying the gclass table in database %s in function getgidFromGclassNameDatabaseName.\n",
              databaseName);
      fprintf(stderr, mysql_error(&mysql));
      fflush(stderr);
      return 0;
  }
  sqlresult = mysql_store_result(connection);

  if(!sqlresult)
  {
      if(mysql_field_count(&mysql) == 0)
      {
          num_rows = mysql_affected_rows(&mysql);
      }
      else                      // mysql_store_result() should have returned data
      {
          fprintf(stderr, "mysql_store is returning nothing in database %s with query:\n", databaseName);
          fprintf(stderr, "the query is \n%s\n", sqlbuff);
          fprintf(stderr, "Error: %s\n", mysql_error(&mysql));
          fflush(stderr);
          return NULL;
      }
  }

  num_rows = (long)mysql_num_rows(sqlresult);
  if(num_rows)
  {
      listOfGclasses = (char **)malloc((num_rows + 6) * sizeof(char *));
      if(listOfGclasses == NULL)
      {
          fprintf(stderr, "The number of rows in the query is unexpected in database %s with query:\n", databaseName);
          fprintf(stderr, "number of rows = %ld and the query is \n%s\n", num_rows, sqlbuff);
          fflush(stderr);
          return NULL;
      }
      for (ii = 0; ii < (num_rows + 6); ii++)
      {
          listOfGclasses[ii] = NULL;
      }
  }
  else
  {
      mysql_free_result(sqlresult);
      free(fmethod);
      fmethod = NULL;
      free(fsource);
      fsource = NULL;
      return NULL;
  }
  if(mysql_num_rows(sqlresult))
  {
      ii = 0;
      while ((row = mysql_fetch_row(sqlresult)) != NULL)
      {
          listOfGclasses[ii] = strdup(row[0]);
          ii++;
      }

  }

  for (ii = 0; ii < num_rows; ii++)
  {
      if(listOfGclasses[ii])
      {
          totalLength += strlen(listOfGclasses[ii]);
      }
  }

  finalArrayWithGclasses = (char *)malloc((totalLength + (ii * 3) + 2) * sizeof(char));
  memset(finalArrayWithGclasses, '\0', (totalLength + (ii * 3) + 2));

  if(finalArrayWithGclasses == NULL)
  {
      fprintf(stderr, "The final Array is null in database %s where the totalLength is %d:\n", databaseName,
              totalLength);
      fprintf(stderr, "number of rows = %ld and the query is \n%s\n", num_rows, sqlbuff);
      fflush(stderr);
      return NULL;
  }

  for (ii = 0; ii < num_rows; ii++)
  {
      strcat(finalArrayWithGclasses, listOfGclasses[ii]);
      if(ii < (num_rows - 1))
      {
          strcat(finalArrayWithGclasses, ":");
      }
  }

  mysql_free_result(sqlresult);
  destroy_double_pointer(listOfGclasses, num_rows);
  free(fmethod);
  fmethod = NULL;
  free(fsource);
  fsource = NULL;

  return finalArrayWithGclasses;
}

inline long *longdup(long numb)
{
  long *theLong = 0;
  theLong = (long *)malloc(sizeof(long));
  *theLong = numb;
  return theLong;
}

inline int *intdup(int numb)
{
  int *theInt = 0;
  theInt = (int *)malloc(sizeof(int));
  *theInt = numb;
  return theInt;
}

void setGroupHash(void)
{
  if(isGroupHashInitialized == 0)
  {
      groupHash = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
      isGroupHashInitialized = 1;
  }
}

GHashTable *getGroupHash(void)
{
  if(isGroupHashInitialized == 0)
    setGroupHash();

  return groupHash;
}

int returnGroupId(char *gClass, char *groupName, char *trackName)
{
  int *theGroup = 0;
  char theKeyGroup[556];

  sprintf(theKeyGroup, "%s:%s:%s", trackName, gClass, groupName);
  theGroup = (int *)g_hash_table_lookup(groupHash, theKeyGroup);

  if(!theGroup)
  {
      setGroupCounter(getGroupCounter() + 1);
      g_hash_table_insert(groupHash, g_strdup(theKeyGroup), intdup(getGroupCounter()));
      return getGroupCounter();
  }
  else
  {
      return *theGroup;
  }
}

void setTypeIdHash(void)
{
  if(isTypeIdHashInitialized == 0)
  {
      typeIdHash = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
      isTypeIdHashInitialized = 1;
  }
}

GHashTable *getTypeIdHash(void)
{
  if(isTypeIdHashInitialized == 0)
  {
      setTypeIdHash();
  }

  return typeIdHash;
}

int addTypeIdHash(char *typeIdStr, int databaseId)
{
  char theTypeHashKey[556];
  if(typeIdStr == NULL)
  {
      return -1;
  }

  sprintf(theTypeHashKey, "%d:%s", databaseId, typeIdStr);
  g_hash_table_insert(typeIdHash, g_strdup(theTypeHashKey), intdup(atoi(typeIdStr)));

  return 1;
}

void print_entry(gpointer key, gpointer val, gpointer data)
{
  fprintf(stderr, "key =\"%s\" value = \"%s\"\n", (gchar *) key, (gchar *) val);
}

    // Example   g_hash_table_foreach(tempSortedSharedOrderIdHash, print_entry_with_intValues, NULL);
void print_entry_with_intValues(gpointer key, gpointer val, gpointer data)
{
  int *value = (int *)val;
  int raw = 0;

  if(value != NULL)
  {
      raw = *value;
  }

  fprintf(stderr, "key = \"%s\" value = %d\n", (gchar *) key, raw);
}

void print_entry_with_intKeys(gpointer key, gpointer val, gpointer data)
{
  int *value = (int *)key;
  int raw = 0;

  if(value != NULL)
  {
      raw = *value;
  }

  printf("key = \"%d\" value = %s\n", raw, (gchar *) val);
}

char *getTrackNameFromTypeId(int database, int typeId)
{
  char tempKey[255] = "";
  char *myNewTrackName = NULL;

  sprintf(tempKey, "%d:%d", database, typeId);
  myNewTrackName = (char *)g_hash_table_lookup(typeId2FeatureTypeHash, tempKey);
  return myNewTrackName;
}

void setgroups2TrackHash(void)
{
  if(isGroups2TrackHashInitialized == 0)
  {
      groups2TrackHash = g_hash_table_new_full(g_int_hash, g_int_equal, g_free, g_free);
      isGroups2TrackHashInitialized = 1;
  }
}

GHashTable *getGroups2TrackHash(void)
{
  if(isGroups2TrackHashInitialized == 0)
  {
      setgroups2TrackHash();
  }

  return groups2TrackHash;
}

int addGroup2TrackHash(int database, int typeId, int groupId)
{
  char tempKey[255] = "";
  char *trackName = NULL;
  char *myNewTrackName = NULL;

  sprintf(tempKey, "%d:%d", database, typeId);
  myNewTrackName = g_hash_table_lookup(typeId2FeatureTypeHash, tempKey);
  if(myNewTrackName)
  {
      trackName = (char *)g_hash_table_lookup(groups2TrackHash, &groupId);
      if(!trackName || strlen(trackName) < 1)
      {
          g_hash_table_insert(groups2TrackHash, intdup(groupId), g_strdup(myNewTrackName));
          return 1;
      }
  }

  return 0;
}

void setGroupId2groupStartHash(void)
{
  if(isGroupId2groupStartHashInitialized == 0)
  {
      groupId2groupStartHash = g_hash_table_new_full(g_int_hash, g_int_equal, g_free, g_free);
      isGroupId2groupStartHashInitialized = 1;
  }
}

GHashTable *getGroupId2groupStartHash(void)
{
  if(isGroupId2groupStartHashInitialized == 0)
  {
      setGroupId2groupStartHash();
  }

  return groupId2groupStartHash;
}

int insertGroupStart(int groupId, long groupStart)
{
  if(groupId < 0 || groupStart < 0)
  {
      return -1;
  }

  g_hash_table_insert(groupId2groupStartHash, intdup(groupId), longdup(groupStart));
  return 1;
}

long getGroupStartForGroupId(int groupId)
{
  long *theGroupStart = NULL;

  theGroupStart = (long *)g_hash_table_lookup(groupId2groupStartHash, &groupId);

  return *theGroupStart;
}

GHashTable *getLinkInfoHash(void)
{
  if(isLinkInfoHashInitialized == 0)
  {
      setLinkInfoHash();
  }

  return linkInfoHash;
}

void setLinkInfoHash(void)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  int numberGenboreeDatabases = getNumberDatabases();
  int i = 0;
  char theKey[255];

  memset(theKey, '\0', 255);

  if(isLinkInfoHashInitialized == 0)
  {
      linkInfoHash = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
      isLinkInfoHashInitialized = 1;
  }

  for (i = (numberGenboreeDatabases - 1); i > -1; i--)
  {
      resetLocalConnection(getDatabaseFromId(i));
      connection = returnLocalConnection(2);
      mysql = returnMyMYSQL(2);
      sprintf(sqlbuff, "SELECT linkId, concat(name, '\\t', description) myLink FROM link");

      if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
      {
          fprintf(stderr, "Error querying the link Table in database %s function setLinkInfoHash.\n",
                  getDatabaseFromId(i));
          fprintf(stderr, mysql_error(&mysql));
          fflush(stderr);
          return;
      }
      sqlresult = mysql_store_result(connection);

      if(mysql_num_rows(sqlresult) != 0)
      {
          while ((row = mysql_fetch_row(sqlresult)) != NULL)
          {
              g_hash_table_insert(linkInfoHash, g_strdup(row[0]), g_strdup(row[1]));
          }
      }
      mysql_free_result(sqlresult);
  }

  resetLocalConnection(getDatabaseFromId(0));
  return;
}

void setFeatureHash(void)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  int counter = 0;
  int numberGenboreeDatabases = getNumberDatabases();
  char tempData[55] = "";
  char **listOfFtypeIds = getTypeIdsStatementByDatabaseId();

  memset(tempData, '\0', 55);
  setFeatureTypeHash();
  setTypeId2FeatureTypeHash();

  while (numberGenboreeDatabases > counter)
  {
      if(!getSingleInStatement(counter))
      {
          counter++;
          continue;
      }
      resetLocalConnection(getDatabaseFromId(counter));
      connection = returnLocalConnection(2);
      mysql = returnMyMYSQL(2);

      sprintf(sqlbuff, "SELECT CONCAT(fmethod, ':', fsource) FeatureTypeId, "
              "ftypeid FROM ftype WHERE ftypeid in %s AND fsource NOT IN ('Chromosome', 'Sequence')",
              listOfFtypeIds[counter]);

      if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
      {
          fprintf(stderr, "Error querying the ftype database in function setFeatureHash.\n");
          fprintf(stderr, mysql_error(&mysql));
          fflush(stderr);
          return;
      }
      sqlresult = mysql_store_result(connection);

      if(mysql_num_rows(sqlresult) == 0)
      {
          counter++;
          continue;
      }

      while ((row = mysql_fetch_row(sqlresult)) != NULL)
      {
          memset(tempData, '\0', 55);
          sprintf(tempData, "%d:%s", counter, row[1]);
          g_hash_table_insert(featureTypeHash, g_strdup(row[0]), g_strdup(tempData));
          g_hash_table_insert(typeId2FeatureTypeHash, g_strdup(tempData), g_strdup(row[0]));
      }
      mysql_free_result(sqlresult);
      counter++;
  }

  setNumberOfAllFeatures(g_hash_table_size(featureTypeHash));
  resetLocalConnection(getDatabaseFromId(0));
  return;
}

void fillGclassHash(void)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  int counter = 0;
  int numberGenboreeDatabases = getNumberDatabases();
  char tempKey[255] = "";

  setGclassHash();

  while (numberGenboreeDatabases > counter)
  {
      resetLocalConnection(getDatabaseFromId(counter));
      connection = returnLocalConnection(2);
      mysql = returnMyMYSQL(2);

      strcpy(sqlbuff, "SELECT gid, gclass FROM gclass");

      if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
      {
          fprintf(stderr, "Error querying the database gclass in function fillGclassHash.\n");
          fprintf(stderr, mysql_error(&mysql));
          fflush(stderr);
          return;
      }
      sqlresult = mysql_store_result(connection);

      if(mysql_num_rows(sqlresult) == 0)
      {
          fprintf(stderr, "Database %s appears to be empty\n", getDatabaseFromId(counter));
          fflush(stderr);
          counter++;
          continue;
      }

      while ((row = mysql_fetch_row(sqlresult)) != NULL)
      {
          sprintf(tempKey, "%d:%d", counter, atoi(row[0]));
          g_hash_table_insert(gClassHash, g_strdup(row[1]), g_strdup(tempKey));
      }
      mysql_free_result(sqlresult);
      counter++;
  }

  resetLocalConnection(getDatabaseFromId(0));

  return;
}

// sets up the hash for storing attNames for template db
void setAttNameIdHashTemplate(void)
{
  if(isAttNameIdHashInitializedTemplate == 0)
  {
      attNameIdHashTemplate = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
      isAttNameIdHashInitializedTemplate = 1;
  }
}

void setAttValueIdHashTemplate(void)
{
  if(isAttValueIdHashInitializedTemplate == 0)
  {
      attValueIdHashTemplate = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
      isAttValueIdHashInitializedTemplate = 1;
  }
}

// fills up the attNameIdHashTemplate hash with the ids for the attribute names (for the template database)
// this helps avoid too many sql queries
void fillAttNameIdForTemplateDb(void)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  char tempKey[255] = "";
  char *dbName = NULL;
  dbName = getDatabaseFromId(1);
  if(dbName == NULL)
  {
    return ;
  }
  resetLocalConnection(dbName); // set connection to template db
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);
  setAttNameIdHashTemplate();
  strcpy(sqlbuff, "SELECT attNameId, name FROM attNames");

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
    fprintf(stderr, "Error querying the table attNames in function fillAttNameIdForTemplateDb.\n");
    fprintf(stderr, mysql_error(&mysql));
    fflush(stderr);
    return;
  }
  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult) == 0)
  {
    fprintf(stderr, "Database %s appears to be empty\n", getDatabaseFromId(1));
    fflush(stderr);
    return;
  }

  while ((row = mysql_fetch_row(sqlresult)) != NULL)
  {
    g_hash_table_insert(attNameIdHashTemplate, g_strdup(row[1]), intdup(atoi(row[0])));
  }
  mysql_free_result(sqlresult);
  resetLocalConnection(getDatabaseFromId(1));
  return;
}

void fillAttValueIdForTemplateDb(void)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  char tempKey[255] = "";
  char *dbName = NULL;
  dbName = getDatabaseFromId(1);
  if(dbName == NULL)
  {
    return ;
  }
  resetLocalConnection(dbName); // set connection to template db
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);
  setAttValueIdHashTemplate();
  strcpy(sqlbuff, "SELECT attValueId, value FROM attValues ");

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
    fprintf(stderr, "Error querying the table attValues in function fillAttValueIdForTemplateDb.\n");
    fprintf(stderr, mysql_error(&mysql));
    fflush(stderr);
    return;
  }
  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult) == 0)
  {
    fprintf(stderr, "Database %s appears to be empty\n", getDatabaseFromId(1));
    fflush(stderr);
    return;
  }
  timeItNow("C-DONE - before filling value hash");
  while ((row = mysql_fetch_row(sqlresult)) != NULL)
  {
    g_hash_table_insert(attValueIdHashTemplate, g_strdup(row[0]), g_strdup(row[1]));
  }
  timeItNow("C-DONE - after filling value hash");
  mysql_free_result(sqlresult);
  resetLocalConnection(getDatabaseFromId(1));
  return;
}

// sets up the hash for storing attNames for template db
void setAttNameIdHashUser(void)
{
  if(isAttNameIdHashInitializedUser == 0)
  {
      attNameIdHashUser = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
      isAttNameIdHashInitializedUser = 1;
  }
}

void setAttValueIdHashUser(void)
{
  if(isAttValueIdHashInitializedUser == 0)
  {
      attValueIdHashUser = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
      isAttValueIdHashInitializedUser = 1;
  }
}

// fills up the attNameIdHashUser hash with the ids for the attribute names (for the user database)
// this helps avoid too many sql queries
void fillAttNameIdForUserDb(void)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  char tempKey[255] = "";
  char *dbName = NULL;
  dbName = getDatabaseFromId(0);
  if(dbName == NULL)
  {
    return ;
  }
  resetLocalConnection(dbName); // set connection to user db
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);
  setAttNameIdHashUser();
  strcpy(sqlbuff, "SELECT * FROM attNames");

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
    fprintf(stderr, "Error querying the table attNames in function fillAttNameIdForUserDb.\n");
    fprintf(stderr, mysql_error(&mysql));
    fflush(stderr);
    return;
  }
  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult) == 0)
  {
    fprintf(stderr, "Database %s appears to be empty\n", getDatabaseFromId(0));
    fflush(stderr);
    return;
  }

  while ((row = mysql_fetch_row(sqlresult)) != NULL)
  {
    g_hash_table_insert(attNameIdHashUser, g_strdup(row[1]), intdup(atoi(row[0])));
  }
  mysql_free_result(sqlresult);
  resetLocalConnection(getDatabaseFromId(0));
  return;
}

void fillAttValueIdForUserDb(void)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  char tempKey[255] = "";
  char *dbName = NULL;
  dbName = getDatabaseFromId(0);
  if(dbName == NULL)
  {
    return ;
  }
  resetLocalConnection(dbName); // set connection to template db
  connection = returnLocalConnection(2);
  mysql = returnMyMYSQL(2);
  setAttValueIdHashUser();
  strcpy(sqlbuff, "SELECT attValueId, value FROM attValues");

  if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
  {
    fprintf(stderr, "Error querying the table attValues in function fillAttValueIdForUserDb.\n");
    fprintf(stderr, mysql_error(&mysql));
    fflush(stderr);
    return;
  }
  sqlresult = mysql_store_result(connection);

  if(mysql_num_rows(sqlresult) == 0)
  {
    fprintf(stderr, "Database %s appears to be empty\n", getDatabaseFromId(0));
    fflush(stderr);
    return;
  }

  while ((row = mysql_fetch_row(sqlresult)) != NULL)
  {
    g_hash_table_insert(attValueIdHashUser, g_strdup(row[0]), g_strdup(row[1]));
  }
  mysql_free_result(sqlresult);
  resetLocalConnection(getDatabaseFromId(0));
  return;
}


void setGroupIds2GroupHash(void)
{
  if(isGroupIds2GroupHashInitialized == 0)
  {
      groupIds2GroupHash = g_hash_table_new_full(g_int_hash, g_int_equal, g_free, eraseGroup);
      isGroupIds2GroupHashInitialized = 1;
  }
}

GHashTable *getGroupIds2GroupHash(void)
{
  if(isGroupIds2GroupHashInitialized == 0)
  {
      setGroupIds2GroupHash();
  }

  return groupIds2GroupHash;
}

int addGroup2GroupIds2GroupHash(myGroup * currentGroup, int groupId)
{
  if(returnGroupFromGroupId(groupId))
  {
      return 0;
  }

  g_hash_table_insert(groupIds2GroupHash, intdup(groupId), currentGroup);
  return 1;
}

myGroup *returnGroupFromGroupId(int groupId)
{
  myGroup *theGroup = NULL;
  theGroup = (myGroup *) g_hash_table_lookup(groupIds2GroupHash, &groupId);
  return theGroup;
}

void setTrackName2TrackHash(void)
{
  trackName2TrackHash = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, eraseTrack);
}

GHashTable *getTrackName2TrackHash(void)
{
  return trackName2TrackHash;
}

myTrack *returnTrackFromTrackName(char *trackName)
{
  myTrack *theTrack = NULL;
  if(trackName && strlen(trackName) > 1)
  {
      theTrack = (myTrack *) g_hash_table_lookup(trackName2TrackHash, trackName);
  }

  return theTrack;
}

myTrack *returnTrackFromDatabaseIdTypeId(int databaseId, int typeId)
{
  char *trackName = NULL;
  char key[255] = "";
  myTrack *navigationTrack = NULL;

  memset(key, '\0', 255);
  sprintf(key, "%d:%d", databaseId, typeId);

  trackName = (char *)g_hash_table_lookup(typeId2FeatureTypeHash, key);
  if(trackName == NULL)
  {
      return NULL;
  }

  navigationTrack = (myTrack *) g_hash_table_lookup(trackName2TrackHash, trackName);

  return navigationTrack;
}

void insertTrackInTrackName2TrackHash(myTrack * myLocalTrack)
{
  char *trackName = NULL;
  myTrack *theTrack = NULL;

  if(!myLocalTrack)
    return;

  trackName = myLocalTrack->trackName;

  if(!trackName || strlen(trackName) < 1)
  {
      return;
  }

  theTrack = (myTrack *) g_hash_table_lookup(trackName2TrackHash, trackName);
  if(!theTrack)
  {
      g_hash_table_insert(trackName2TrackHash, g_strdup(trackName), myLocalTrack);
  }
  return;
}

GHashTable *getTagsHash(void)
{
  if(isTagHashInitialized == 0)
  {
      setTagsHash();
  }

  return tagHash;
}

void setTagsHash(void)
{
  int tagId = 0;
  char **splitMyTag = NULL;
  char *tempTag = NULL;
  char *tempValue = NULL;
  int tempIntValue = -1;
  char **tags = getTags();

  if(isTagHashInitialized == 0)
  {
      tagHash = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
      isTagHashInitialized = 1;
  }

  for (tagId = 0; tags[tagId][0] != '\0'; tagId++)
  {
      int resultingTags = 0;
      splitMyTag = splitLargeStringIntoSubstringsUsingSeparator(tags[tagId], "=", &resultingTags);
      tempTag = splitMyTag[0];
      tempValue = splitMyTag[1];
      tempIntValue = atoi(tempValue);
      if(tempTag == NULL || tempIntValue < 0)
      {
          fprintf(stderr, "Error in setTagsHash the tags[%d] has wrong values = %s\n", tagId, tags[tagId]);
          fflush(stderr);
          continue;
      }
      g_hash_table_insert(tagHash, g_strdup(tempTag), intdup(tempIntValue));
      destroy_double_pointer(splitMyTag, resultingTags);
  }

  return;
}

/* Create a Hash with fmethod:fsource key and value */
void setAllFmethodFsource(void)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection;
  MYSQL mysql;
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  int counter = 0;
  int numberGenboreeDatabases = getNumberDatabases();
  int realQueryResult = -1;

  if(isAllFmethodFsourceInitialized == 0)
  {
      allFmethodFsource = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
      isAllFmethodFsourceInitialized = 1;
  }

  while (numberGenboreeDatabases > counter)
  {
      resetLocalConnection(getDatabaseFromId(counter));
      connection = returnLocalConnection(2);
      mysql = returnMyMYSQL(2);

      sprintf(sqlbuff,
              "SELECT CONCAT(fmethod, ':', fsource) FeatureTypeId FROM ftype WHERE fsource NOT IN ('Chromosome', 'Sequence')");

      realQueryResult = mysql_real_query(connection, sqlbuff, strlen(sqlbuff));
      if(realQueryResult != 0)
      {
          continue;
      }
      sqlresult = mysql_store_result(connection);

      if(mysql_num_rows(sqlresult) == 0)
      {
          counter++;
          continue;
      }

      while ((row = mysql_fetch_row(sqlresult)) != NULL)
      {
          g_hash_table_insert(allFmethodFsource, g_strdup(row[0]), g_strdup(row[0]));
      }
      mysql_free_result(sqlresult);
      counter++;
  }
  resetLocalConnection(getDatabaseFromId(0));
  return;
}

GHashTable *getAllFmethodFsource(void)
{
  if(isAllFmethodFsourceInitialized == 0)
  {
      setAllFmethodFsource();
  }

  return allFmethodFsource;
}

void eraseDoubleHash(gpointer data)
{
  GHashTable *doubleHash = NULL;
  doubleHash = (GHashTable *) data;
  g_hash_table_destroy(doubleHash);

  return;
}

char **getArrayFromStringHashes(GHashTable * unSortedStingHash, int *sortedCounter)
{
  int size = g_hash_table_size(unSortedStingHash);
  GList *listOfKeys;
  char *tempTrackName = NULL;
  int counter = 0;
  char **sortedTracks = NULL;

  if(size > 0)
  {
      listOfKeys = g_hash_table_get_keys(unSortedStingHash);
      listOfKeys = g_list_sort(listOfKeys, compare_stringPointers);
      counter = 0;
      sortedTracks = (char **)malloc((size + 1) * sizeof(char *));
      while (listOfKeys)
      {
          tempTrackName = (char *)listOfKeys->data;
          sortedTracks[counter] = strdup(tempTrackName);
          counter++;
          listOfKeys = g_list_next(listOfKeys);
      }
      *sortedCounter = counter;
  }
  return sortedTracks;
}

char **getArrayFromNumericSortedHashes(GHashTable * sortedHash, int *sortedCounter)
{
  int size = g_hash_table_size(sortedHash);
  GList *listOfKeys;
  char *tempTrackName = NULL;
  int counter = 0;
  char **sortedTracks = NULL;
  GHashTable *typeId2FeatureTypeHash = getTypeId2FeatureTypeHash();

  if(size > 0)
  {
      listOfKeys = g_hash_table_get_keys(sortedHash);
      listOfKeys = g_list_sort(listOfKeys, compare_intPointers);
      counter = 0;
      sortedTracks = (char **)malloc((size + 1) * sizeof(char *));
      while (listOfKeys)
      {
          int *sortedKey = (int *)listOfKeys->data;
          char *theCodeKey = (char *)g_hash_table_lookup(sortedHash, sortedKey);
          tempTrackName = (char *)g_hash_table_lookup(typeId2FeatureTypeHash, theCodeKey);
          sortedTracks[counter] = strdup(tempTrackName);
          counter++;
          listOfKeys = g_list_next(listOfKeys);
      }
      *sortedCounter = counter;
  }
  return sortedTracks;
}

//NEW NEW TODO 
int createArrayOrderedTracks(void)
{
  GHashTable *myFeatureTypeHash;
  GHashTable *myOrderHash;
  GHashTable *typeId2FeatureTypeHash;
  GHashTable *localSortedHash = NULL;
  GHashTable *localUnsortedHash = NULL;
  GHashTable *sharedSortedTrackHash = NULL;
  GHashTable *sharedUnsortedTrackHash = NULL;
  GHashTable *allNameOfTrackHash = NULL;
  GHashTable *tempSharedSortedTrackHash = NULL;
  GHashTable *tempLocalSortedTrackHash = NULL;
  GHashTable *tempSortedSharedOrderIdHash = NULL;
  char **newListTracks = NULL;
  int numberOfRecords = 0;
  int numberOfAllFeatures = 0;
  int numberOfSortedFtypeId = 0;
  int ii = 0;
  int size = 0;
  int orderKey = 0;
  int tempChar = 0;
  char **localSortedTracks = NULL;
  char **shareSortedTracksNoLocal = NULL;
  char **localUnsortedTracks = NULL;
  char **shareUnsortedTracksNoLocal = NULL;
  int localSortedCounter = 0;
  int shareSortedCounterNoLocal = 0;
  int localUnsortedCounter = 0;
  int shareUnsortedCounterNoLocal = 0;
  GHashTableIter iter;
  gpointer key, value;
  char *tempTrackName = NULL;
  int lastCount = 0;
  char *inAllTracks = NULL;
  GList *listOfArrayOfStrings = NULL;
  arrayOfStrings *localSortedArray = NULL;
  arrayOfStrings *localUnsortedArray = NULL;
  arrayOfStrings *sharedSortedArray = NULL;
  arrayOfStrings *sharedUnsortedArray = NULL;

  myFeatureTypeHash = getFeatureTypeHash();
  myOrderHash = getAllSortedFmethodFsource();

  typeId2FeatureTypeHash = getTypeId2FeatureTypeHash();

  numberOfAllFeatures = g_hash_table_size(typeId2FeatureTypeHash);
  numberOfSortedFtypeId = g_hash_table_size(myOrderHash);
  numberOfRecords = numberOfAllFeatures;

  localSortedHash = g_hash_table_new_full(g_int_hash, g_int_equal, g_free, g_free);
  localUnsortedHash = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
  allNameOfTrackHash = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
  sharedSortedTrackHash = g_hash_table_new_full(g_int_hash, g_int_equal, g_free, g_free);
  sharedUnsortedTrackHash = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
  tempSharedSortedTrackHash = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
  tempLocalSortedTrackHash = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
  tempSortedSharedOrderIdHash = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);

  g_hash_table_iter_init(&iter, typeId2FeatureTypeHash);

  while (g_hash_table_iter_next(&iter, &key, &value))
  {
      char *typeIdKey = (char *)(key);
      tempTrackName = (char *)value;
      int *myOrderKey = (int *)g_hash_table_lookup(myOrderHash, typeIdKey);
      if(myOrderKey != NULL)
      {
          orderKey = *myOrderKey;
      }
      else
      {
          orderKey = -1;
      }

      tempChar = (unsigned char)typeIdKey[0];
      if(tempChar == '0')
      {
          if(orderKey > 0)
          {
              g_hash_table_insert(localSortedHash, intdup(orderKey), g_strdup(typeIdKey));
              g_hash_table_insert(tempLocalSortedTrackHash, g_strdup(tempTrackName), NULL);
          }
          else
          {
              g_hash_table_insert(localUnsortedHash, g_strdup(tempTrackName), NULL);
          }
      }
      else
      {

          if(orderKey > 0)
          {
              g_hash_table_insert(tempSortedSharedOrderIdHash, g_strdup(tempTrackName), intdup(orderKey));
              g_hash_table_insert(sharedSortedTrackHash, intdup(orderKey), g_strdup(typeIdKey));
              g_hash_table_insert(tempSharedSortedTrackHash, g_strdup(tempTrackName), NULL);
          }
          else
          {
              g_hash_table_insert(sharedUnsortedTrackHash, g_strdup(tempTrackName), NULL);
          }
      }
  }

  g_hash_table_iter_init(&iter, tempSharedSortedTrackHash);
  while (g_hash_table_iter_next(&iter, &key, &value))
  {
      g_hash_table_remove(localUnsortedHash, key);
  }

  g_hash_table_iter_init(&iter, tempLocalSortedTrackHash);
  while (g_hash_table_iter_next(&iter, &key, &value))
  {
      int *tempOrderId = (int *)g_hash_table_lookup(tempSortedSharedOrderIdHash, key);
      if(tempOrderId != NULL && *tempOrderId > 0)
        g_hash_table_remove(sharedSortedTrackHash, tempOrderId);
      g_hash_table_remove(sharedUnsortedTrackHash, key);
  }

  localSortedTracks = getArrayFromNumericSortedHashes(localSortedHash, &localSortedCounter);
  localSortedArray = createArrayOfStrings(localSortedTracks, localSortedCounter);
  localUnsortedTracks = getArrayFromStringHashes(localUnsortedHash, &localUnsortedCounter);
  localUnsortedArray = createArrayOfStrings(localUnsortedTracks, localUnsortedCounter);
  shareSortedTracksNoLocal = getArrayFromNumericSortedHashes(sharedSortedTrackHash, &shareSortedCounterNoLocal);
  sharedSortedArray = createArrayOfStrings(shareSortedTracksNoLocal, shareSortedCounterNoLocal);
  shareUnsortedTracksNoLocal = getArrayFromStringHashes(sharedUnsortedTrackHash, &shareUnsortedCounterNoLocal);
  sharedUnsortedArray = createArrayOfStrings(shareUnsortedTracksNoLocal, shareUnsortedCounterNoLocal);

  listOfArrayOfStrings = g_list_append(listOfArrayOfStrings, sharedUnsortedArray);
  listOfArrayOfStrings = g_list_append(listOfArrayOfStrings, localUnsortedArray);
  listOfArrayOfStrings = g_list_append(listOfArrayOfStrings, sharedSortedArray);
  listOfArrayOfStrings = g_list_append(listOfArrayOfStrings, localSortedArray);

  size = localSortedCounter + localUnsortedCounter + shareSortedCounterNoLocal + shareUnsortedCounterNoLocal + 2;
  setNumberOfItemsInArrayOrderedTracks(size + 1);
  newListTracks = (char **)malloc((size + 1) * sizeof(char *));
  for (ii = 0; ii < size; ii++)
  {
      newListTracks[ii] = NULL;
  }

  lastCount = 0;
  while (listOfArrayOfStrings)
  {
      arrayOfStrings *arrayStr = (arrayOfStrings *) listOfArrayOfStrings->data;
      char **stringWithTracks = arrayStr->strings;
      int numberOfStrings = arrayStr->numberOfStrings;
      for (ii = 0; ii < numberOfStrings; ii++)
      {
          inAllTracks = (char *)g_hash_table_lookup(allNameOfTrackHash, stringWithTracks[ii]);
          if(inAllTracks == NULL)
          {
              newListTracks[lastCount] = strdup(stringWithTracks[ii]);
              g_hash_table_insert(allNameOfTrackHash, g_strdup(stringWithTracks[ii]), g_strdup(stringWithTracks[ii]));
              lastCount++;

          }
      }
      listOfArrayOfStrings = g_list_next(listOfArrayOfStrings);
  }

  setNumberOfTracks(lastCount);
  setMaxOrder(lastCount);
  setArrayOrderedTracks(newListTracks);

  while (listOfArrayOfStrings)
  {
      arrayOfStrings *arrayStr = (arrayOfStrings *) listOfArrayOfStrings->data;
      char **stringWithTracks = arrayStr->strings;
      int numberOfStrings = arrayStr->numberOfStrings;

      for (ii = 0; ii < numberOfStrings; ii++)
      {
          free(stringWithTracks[ii]);
          stringWithTracks[ii] = NULL;
      }
      free(stringWithTracks);
      stringWithTracks = NULL;
      lastCount += ii;
      listOfArrayOfStrings = g_list_next(listOfArrayOfStrings);
  }
  g_list_free_1(listOfArrayOfStrings);

  g_hash_table_destroy(localSortedHash);
  g_hash_table_destroy(localUnsortedHash);
  g_hash_table_destroy(allNameOfTrackHash);
  g_hash_table_destroy(sharedSortedTrackHash);
  g_hash_table_destroy(sharedUnsortedTrackHash);
  g_hash_table_destroy(tempSharedSortedTrackHash);
  g_hash_table_destroy(tempLocalSortedTrackHash);
  g_hash_table_destroy(tempSortedSharedOrderIdHash);

  return 1;
}

void setAllSortFmethodFsource(void)
{
  int counter = 0;
  int ii = 0;
  int numberGenboreeDatabases = getNumberDatabases();
  char *databaseName = NULL;
  char *arrayOfTypeIds = NULL;
  char **listOfFtypeIds = getTypeIdsStatementByDatabaseId();
  int nextValue = 0;
  int *ftypeIds = NULL;
  char theKeyTemp[556];
  int preserveDefaultTrackOrder = getPreserveDefaultTrackOrder();
  int *previousValue = NULL;

  if(isAllSortedFmethodFsourceInitialized == 0)
  {
    allSortedFmethodFsource = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
    isAllSortedFmethodFsourceInitialized = 1;
  }
  while (numberGenboreeDatabases > counter)
  {
    nextValue = 0;
    databaseName = getDatabaseFromId(counter);
    arrayOfTypeIds = listOfFtypeIds[counter];
    
    if(preserveDefaultTrackOrder)
    {
      fillSortHashTableWithFtypeIds(allSortedFmethodFsource, databaseName, counter, 0, arrayOfTypeIds, nextValue);
      nextValue = fetchMaxValueFromHash(allSortedFmethodFsource, nextValue);
      fillSortHashTableWithFtypeIds(allSortedFmethodFsource, databaseName, counter, getMyUserId(), arrayOfTypeIds,
                                    nextValue);
    }
    else
    {
      fillSortHashTableWithFtypeIds(allSortedFmethodFsource, databaseName, counter, getMyUserId(), arrayOfTypeIds,
                                    nextValue);
      nextValue = fetchMaxValueFromHash(allSortedFmethodFsource, nextValue);
      fillSortHashTableWithFtypeIds(allSortedFmethodFsource, databaseName, counter, 0, arrayOfTypeIds, nextValue);
    }
    ftypeIds = fetchArrayOfFtypeIds(counter) ;
    ii = 0 ;
    while (ftypeIds[ii] > -1)
    {
      sprintf(theKeyTemp, "%d:%d", counter, ftypeIds[ii]);
      previousValue = g_hash_table_lookup(allSortedFmethodFsource, theKeyTemp);
      if(previousValue == NULL)
      {
        g_hash_table_insert(allSortedFmethodFsource, g_strdup(theKeyTemp), intdup(-1));
      }
      memset(theKeyTemp, '\0', 555);
      ii++;
    }
    free(ftypeIds);
    ftypeIds = NULL;

    counter++;
  }

  return;
}

GHashTable *getAllSortedFmethodFsource(void)
{
  if(isAllSortedFmethodFsourceInitialized == 0)
    setAllSortFmethodFsource();

  return allSortedFmethodFsource;
}

GHashTable *getDatabase2HostHash(void)
{
  if(isDatabase2HostHashInitialized == 0)
    setDatabase2HostHash();

  return database2HostHash;
}

void setDatabase2HostHash(void)
{
  char sqlbuff[MAXLENGTHOFTEMPSTRING] = "";
  MYSQL *connection = returnLocalConnection(1);
  MYSQL mysql = returnMyMYSQL(1);
  MYSQL_RES *sqlresult;
  MYSQL_ROW row;
  int counter = 0;
  int numberGenboreeDatabases = getNumberDatabases();
  char *hostName;
  char *databaseName;
  char mainDb[255] = "";

  memset(mainDb, '\0', 255);
  strcpy(mainDb, "genboree");

  if(isDatabase2HostHashInitialized == 0)
  {
      database2HostHash = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
      isDatabase2HostHashInitialized = 1;
  }

  hostName = (char *)g_hash_table_lookup(database2HostHash, mainDb);
  if(hostName == NULL)
  {
      hostName = g_strdup(getDbHost());
      g_hash_table_insert(database2HostHash, g_strdup(mainDb), hostName);
  }

  while (numberGenboreeDatabases > counter)
  {
      databaseName = getDatabaseFromId(counter);

      sprintf(sqlbuff, "SELECT databaseHost FROM database2host WHERE databaseName = '%s'", databaseName);

      if(mysql_real_query(connection, sqlbuff, strlen(sqlbuff)) != 0)
      {
          fprintf(stderr, "Error querying the genboree database in getUploadIdArray.\n");
          fprintf(stderr, mysql_error(&mysql));
          fflush(stderr);
          return;
      }
      sqlresult = mysql_store_result(connection);

      // No records were found, so report an error and exit.
      if(mysql_num_rows(sqlresult) == 0)
      {
          fprintf(stderr,
                  "DATABASE %s is not in table database2host please Add the database to database2host and try again\n",
                  databaseName);
          fflush(stderr);
          exit(112);
      }

      if((row = mysql_fetch_row(sqlresult)) != NULL)
      {
          g_hash_table_insert(database2HostHash, g_strdup(databaseName), g_strdup(row[0]));
      }
      mysql_free_result(sqlresult);
      counter++;
  }

  return;

}

GHashTable *getDatabase2ConnectionHash(void)
{
  if(isDatabase2ConnectionHashInitialized == 0)
    setDatabase2ConnectionHash();

  return database2ConnectionHash;
}

void setDatabase2ConnectionHash(void)
{
  if(isDatabase2ConnectionHashInitialized == 0)
  {
      database2ConnectionHash = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
      isDatabase2ConnectionHashInitialized = 1;
  }
}
