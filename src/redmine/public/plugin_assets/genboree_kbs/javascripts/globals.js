var defaultNonLeafRecord = {name: 'attribute', value: 'value', editable: true } ;
var defaultLeafRecord = {name: 'attribute', value: 'value', leaf: true, editable: true } ;
var panelHeight = 662 ;
var panelWidth = 900 ;
var collectionSetStore ;
var freshDocument = false ;
var editModeValue = false ;
var selectedRecord = null ;
var linkIdentifier = null ;
var linkCollection = null ;
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
// Number of search items to return/display
var searchPageSize = 20 ;
var domainMap ;
var recordMap ;
var childType ;
var docPropOfSelectedNode ;
var originalDocumentIdentifier = null ;
var documentEdited = false ;
var newdoc ;
var prevDocId = null ;
var dirtyRecords = {} ;
var role = null ;
var toolTipMap = {} ;
var currentCollection = null ;
var loadingMask = {
  xtype: 'loadmask',
  message: 'Loading...'
};
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
var editorConfigHash = {
  'int': {'minWidth': 150, 'maxWidth':200},
  'float': {'minWidth': 150, 'maxWidth':200},
  'enum': {'minWidth': 200, 'maxWidth':300},
  'boolean': {'width': 30},
  'date': {'width': 150}
} ;
var modelGridKillList = {'index': true } ; // key should match the 'dataIndex' of the field to kill
