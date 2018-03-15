// Misc globals
var defaultNonLeafRecord = {name: 'attribute', value: 'value', editable: true } ;
var defaultLeafRecord = {name: 'attribute', value: 'value', leaf: true, editable: true } ;
var panelHeight = 662 ;
var panelWidth = 930 ;
var collectionSetStore ;
var freshDocument = false ;
var editModeValue = false ;
var selectedRecord = null ;
var maskObj ;
var selectedModelTreeRecord = null ;
var modelVersionsGridSelectedRecord = null ;
var modelLinkClick = false ;
// docModel - Javascript OBJECT (not string!) containing the model for the selected collection
var docModel = null ;
var newdocObj = null ;
var scriptToEval ;
var recordToReplace = null ;
var addingChild = false ;

// Set to a new Ext.data.JsonStore when a new colleciton's model is loaded
// - collection model will determine some aspects of the JsonStore, so search results are
//   easily parsed by Ext (API JSON is ExtJs compatible as-is)
var searchStoreData = null ;
// Store for handling bioportal specific data
var bioportalStoreData = null ;
// Number of search items to return/display
var searchPageSize = 20 ;
var domainMap ;
var recordMap ;
var childType ;
var docPropOfSelectedNode ;
var originalDocumentIdentifier = null ;
var documentEdited = false ;
var tempRecordForRowEditor = null ;
var fileUrlToDownload = null ;
var newdoc ;
var prevDocId = null ;
var dirtyRecords = {} ;
var viewDocs = null ;
var role = null ;
var toolTipMap = {} ;
var indexedProps = [] ;
// flag for indicating whether the tool tips for the bio-ontology terms have been added in the drop list
// will be set to false every time a new query is done.
var bioportalToolTipsAdded = false ;
var currentCollection = null ;
var prevCollection = null ;
var loadingMask = {
  xtype: 'loadmask',
  message: 'Loading...'
};
var editorConfigHash = {
  'int': {'minWidth': 150, 'maxWidth':200},
  'float': {'minWidth': 150, 'maxWidth':200},
  'enum': {'minWidth': 200, 'maxWidth':300},
  'boolean': {'width': 30},
  'date': {'width': 150}
} ;

// globals for the model viewer
var modelFieldsHash = {
  'name': {
    'minWidth': 50,
    'maxWidth': 200
  },
  'description': {
    'minWidth': 50,
    'maxWidth': 250
  },
  'domain': {
    'minWidth': 150,
    'maxWidth': 200
  }
} ;
var modelGridKillList = {'items': true, 'index': true,  'properties': true } ; // key should match the 'dataIndex' of the field to kill
var corePropFields = {
  'name': { 'default': '' },
  'domain': { 'default': 'string' },
  'itemList': {'default': '', 'value': 'true'},
  'identifier': { 'default': '', 'value': 'true' },
  'required': { 'default': '', 'value': 'true' },
  'unique': { 'default': '', 'value': 'true' },
  'category': { 'default': '', 'value': 'true' },
  'fixed': { 'default': '', 'value': 'true' },
  'index_field': { 'default': '', 'value': 'true' },
  'default': { 'default': '', 'value': 'true' },
  'description': { 'default': '' }
} ;
var nonCoreFields = {} ;
// Content Generation related globals
var contentGenDomains = { 'pmid': true, 'omim': true } ;
// Collection metadata related globals
var singularLabel ;
var pluralLabel  ;
var docLevelTools = [] ;
// Stats related globals
var kbPointStatsFieldNameMap = {
  'deleteCount': "# Doc deletions",
  'docCount': "# Docs",
  'versionCount': '# Doc version records',
  'lastEditAuthor': 'Last edited by',
  'createCount': '# Doc creations',
  'avgByteSize': 'Avg doc storage size',
  'lastEditTime': 'Last edited at',
  'byteSize': 'Total storage size',
  'editCount': '# Doc edits'
} ;
var kbPointStatsFieldOrderMap = {
  0: 'docCount',
  1: 'createCount',
  2: 'editCount',
  3: 'versionCount',
  4: 'lastEditTime',
  5: 'lastEditAuthor',
  6: 'avgByteSize',
  7: 'byteSize',
  8: 'deleteCount'
} ;
var maskRemoveCounter = 0 ;
var maskRemoveCounterLimit = 0 ;