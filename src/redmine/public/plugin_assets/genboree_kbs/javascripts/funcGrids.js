var browseFuncStore = Ext.create('Ext.data.Store',
{
  storeId    : 'recordFunc',
  model      : 'BrowseRecord',
  data       :
  [
    { browseFuncName : 'As Dynamic tree', genbKbIconCls : 'genbKb-dynamicTree', selected: true },
    { browseFuncName : 'As Plain HTML', genbKbIconCls : 'genbKb-plainHTML'},
    { browseFuncName : 'Using a View', genbKbIconCls : 'genbKb-usingView' }
  ]
}) ;
// RECORDS
var recordsFuncStore = Ext.create('Ext.data.Store',
{
  storeId    : 'recordFunc',
  model      : 'ManageRecords',
  data       :
  [
    { recordFuncName : 'Create new Document', genbKbIconCls : 'genbKb-createRecord' },
    { recordFuncName : 'Edit Document', genbKbIconCls : 'genbKb-editRecord' },
    { recordFuncName : 'Delete Document', genbKbIconCls : 'genbKb-deleteRecord' },
    { recordFuncName : 'Bulk Document upload', genbKbIconCls : 'genbKb-bulkUpload' },
    { recordFuncName : 'Document history', genbKbIconCls : 'genbKb-recordHistory' }
  ]
}) ;
// Models
var modelsFuncStore = Ext.create('Ext.data.Store',
{
  storeId    : 'modelFunc',
  model      : 'ManageModels',
  data       :
  [
    { modelFuncName : 'View Model (Tree)', genbKbIconCls : 'genbKb-dynamicTree' },
    { modelFuncName : 'View Model (Grid)', genbKbIconCls : 'genbKb-runQuery' },
    { modelFuncName : 'Create new Model', genbKbIconCls : 'genbKb-createRecord' }
  ]
}) ;
// QUERIES
var queriesFuncStore = Ext.create('Ext.data.Store',
{
  storeId    : 'queryFunc',
  model      : 'Queries',
  data       :
  [
    { queryFuncName : 'Run existing Query', genbKbIconCls : 'genbKb-runQuery'},
    { queryFuncName : 'Create new Query', genbKbIconCls : 'genbKb-createQuery' },
    { queryFuncName : 'Edit/copy Query', genbKbIconCls : 'genbKb-editQuery' },
    { queryFuncName : 'Delete Queries', genbKbIconCls : 'genbKb-deleteQuery' }
  ]
}) ;
// MANAGE VIEWS
var viewsFuncStore = Ext.create('Ext.data.Store',
{
  storeId    : 'viewsFunc',
  model      : 'ManageViews',
  data       :
  [
    { viewFuncName : 'Create new View', genbKbIconCls : 'genbKb-createView' },
    { viewFuncName : 'Edit/copy exiting View', genbKbIconCls : 'genbKb-editView' },
    { viewFuncName : 'Delete a View', genbKbIconCls : 'genbKb-deleteView' }
  ]
}) ;
// MANAGE DATASETS
var collectionFuncStore = Ext.create('Ext.data.Store',
{
  storeId    : 'collectionFunc',
  model      : 'AdminCollections',
  groupers   :
  [
    { property : 'category', sorterFn : function(aa, bb) {} }
  ],
  data       :
  [
    { category : 'All Users', collectionFuncName : 'Browse Collections & Models',  genbKbIconCls : 'genbKb-browseCollections' },
    { category : 'All Users', collectionFuncName : 'Download Collections', genbKbIconCls : 'genbKb-downloadCollection' },
    { category : 'All Users', collectionFuncName : 'View Model history', genbKbIconCls : 'genbKb-viewModelHistory' },
    { category : 'Admin Only', collectionFuncName : 'Create new Collection', genbKbIconCls : 'genbKb-createCollection' },
    { category : 'Admin Only', collectionFuncName : 'Edit a Collection\'s Model', genbKbIconCls : 'genbKb-editCollectionModel' },
    { category : 'Admin Only', collectionFuncName : 'Archive a Collection', genbKbIconCls : 'genbKb-archiveCollection' }
  ]
}) ;

var collectionFuncGroupingFeature = Ext.create('Ext.grid.feature.Grouping',
{
  id                : 'selectCollectionFuncGrouping',
  groupHeaderTpl    : '{name}:',
  hideGroupedHeader : true,
  startCollapsed    : true
}) ;

var funcGrids =
[
  // ************************
  // Accordion config placed into the west border is here
  // ************************
  {
    layout :
    {
      type             : 'accordion',
      animate          : true,
      collapsible      : true,
      titleCollapse    : true,
      multi            : true,
      hideCollapseTool : false
    },
    padding  : '0 0 30 0',
    border   : 0,
    defaults : { bodyStyle : 'padding: 10px 5px 10px 5px; background-color: #FFFFFF', style : 'background-color: #FFFFFF' },
    items:
    [  
      {
        title  : 'Browse Documents',
        layout : 'fit',
        frame  : true,
        bodyStyle : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
        style : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
        items  :
        [
          Ext.create('Ext.grid.Panel',
          {
            header      : false,
            hideHeaders : true,
            collapsed   : false,
            collapsible : true,
            sortableColumns : false,
            id: 'browseDocsGrid',
            stateful    : false,
            enableColumnResize : false,
            rowLines    : false,
            frame       : false,
            viewConfig  : {
              stripeRows : false,
              getRowClass: function(record, index){
                if(record.get('browseFuncName') != 'As Dynamic tree')
                {
                  return 'genbKb-gray-background' ;
                }
              }  
            },
            border      : 0,
            bodyCls     : 'noHeaderGridCls',
            tpl         : '<i>{recordFuncName}</i>',
            bodyStyle   : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
            style       : 'background-color: #FFFFFF',
            store       : browseFuncStore,
            resizable   : false,
            columns     :
            [
              {
                flex : 1,
                dataIndex : 'browseFuncName',
                sortable : false,
                hideable : false,
                renderer : function(value, metaData, record, row, col, store, view)
                {
                  return Ext.String.format('<div class="genbKb-accordion-item {2}">{1}</div>', record.data.url, record.data.browseFuncName, record.data.genbKbIconCls);
                }
              }
            ],
            listeners: {
              'beforeselect': function(aa, bb){
                var retVal = true ;
                if(bb.data.browseFuncName != 'As Dynamic tree')
                {
                  retVal = false ;
                }
                else
                {
                  if(!Ext.getCmp('modelTreeGrid')) {
                    renderDocTreeGrid() ;
                  }
                  else{
                    Ext.Msg.show({
                      title: "View Document",
                      width: 500,
                      msg: "How would you like to view the documents?</br></br><b>NOTE</b>: Viewing the document in the current tab will replace the model view.",
                      buttonText: {yes: 'Open document viewer in current tab', no: 'Open document viewer in new tab', cancel: 'Cancel'},
                      id: 'viewModelMessBox',
                      fn: function(btn){
                        // Add handlers to the buttons above which will solicit the name of the identifier if the user does decide to start a new document
                        if(btn == 'yes')
                        {
                          renderDocTreeGrid() ;
                        }
                        else if (btn == 'no') {
                          Ext.getCmp('browseDocsGrid').getSelectionModel().deselectAll() ;
                          var urlLink = "http://"+location.host+kbMount+"/genboree_kbs?project_id="+projectIdentifier+"&coll="+Ext.getCmp('collectionSetCombobox').value ;
                          var win = window.open(urlLink, '_blank') ;
                          win.focus() ;
                          Ext.getCmp('browseDocsGrid').getSelectionModel().deselectAll() ;
                        }
                        else
                        {
                          Ext.getCmp('browseDocsGrid').getSelectionModel().deselectAll() ;
                        }
                      }
                    }) ;
                  }
                  
                }
                return retVal ;
              }
            }
          })
        ]
      },
      // MANAGE RECORDS
      {
        title  : 'Manage Documents',
        layout : 'fit',
        frame  : true,
        bodyStyle : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
        style : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
        items  :
        [
          Ext.create('Ext.grid.Panel',
          {
            header      : false,
            hideHeaders : true,
            collapsed   : false,
            id          : 'manageDocsGrid',
            sortableColumns : false,
            stateful    : false,
            enableColumnResize : false,
            rowLines    : false,
            frame       : false,
            viewConfig  : {
              stripeRows : false,
              getRowClass: function(record, index){
                var recName = record.get('recordFuncName') ;
                if(recName == 'Bulk Document upload' || recName == 'Document history')
                {
                  return 'genbKb-gray-background' ;
                }
                else
                {
                  if(recName == 'Create new Document')
                  {
                    return 'genbKb-gray-font-create' ;
                  }
                  else
                  {
                    return 'genbKb-gray-font-edit-delete' ;
                  }
                
                }
              }  
            },
            border      : 0,
            bodyCls     : 'noHeaderGridCls',
            tpl         : '<i>{collectionFuncName}</i>',
            bodyStyle   : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
            style       : 'background-color: #FFFFFF',
            store       : recordsFuncStore,
            resizable   : false,
            columns     :
            [
              { flex : 1, dataIndex : 'recordFuncName', sortable : false, hideable : false, cls : "genbKb-accordion-item", renderer : function(value, metaData, record, row, col, store, view) { return Ext.String.format('<div class="genbKb-accordion-item {2}">{1}</div>', record.data.url, record.data.recordFuncName, record.data.genbKbIconCls); } }
            ]
          })
        ]
      },
      // MANAGE MODELS
      {
        title  : 'Manage Models',
        layout : 'fit',
        frame  : true,
        bodyStyle : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
        style : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
        items  :
        [
          Ext.create('Ext.grid.Panel',
          {
            header      : false,
            hideHeaders : true,
            collapsed   : false,
            id          : 'manageModelsGrid',
            sortableColumns : false,
            stateful    : false,
            enableColumnResize : false,
            rowLines    : false,
            frame       : false,
            listeners: {
              'beforeselect': function(aa, bb){
                var retVal = true ;
                if(bb.data.modelFuncName == 'Create new Model' || bb.data.modelFuncName == 'View Model (Grid)')
                {
                  retVal = false ;
                }
                else
                {
                  if(docModel)
                  {
                    //editModeValue = false ; // This is returned from the 'before edit' event of the row plugin.
                    //Ext.getCmp('manageDocsGrid').getSelectionModel().deselectAll() ;
                    //Ext.getCmp('browseDocsGrid').getSelectionModel().deselectAll() ;
                    //disableEditDelete() ;
                    if (bb.data.modelFuncName == 'View Model (Grid)')
                    {
                      displayModelTable() ;
                    }
                    else
                    {
                      displayModelTree() ;
                    }
                    
                  }
                  else
                  {
                    retVal = false ;
                  }
                }
                return retVal ;
              }
            },
            viewConfig  : {
              stripeRows : false,
              getRowClass: function(record, index){
                var recName = record.get('modelFuncName') ;
                if(recName == 'Create new Model' || recName == 'View Model (Grid)')
                {
                  return 'genbKb-gray-background' ;
                }
                else
                {
                  return 'genbKb-gray-font-view-model' ;
                }
              }  
            },
            border      : 0,
            bodyCls     : 'noHeaderGridCls',
            tpl         : '<i>{modelFuncName}</i>',
            bodyStyle   : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
            style       : 'background-color: #FFFFFF',
            store       : modelsFuncStore,
            resizable   : false,
            columns     :
            [
              { flex : 1, dataIndex : 'modelFuncName', sortable : false, hideable : false, cls : "genbKb-accordion-item", renderer : function(value, metaData, record, row, col, store, view) { return Ext.String.format('<div class="genbKb-accordion-item {2}">{1}</div>', record.data.url, record.data.modelFuncName, record.data.genbKbIconCls); } }
            ]
          })
        ]
      },
      // MANAGE QUERIES
      {
        title  : 'Manage Queries',
        layout : 'fit',
        frame  : true,
        bodyStyle : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
        style : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
        items  :
        [
          Ext.create('Ext.grid.Panel',
          {
            header      : false,
            disabled    : true,
            hideHeaders : true,
            collapsed   : false,
            sortableColumns : false,
            stateful    : false,
            enableColumnResize : false,
            rowLines    : false,
            frame       : false,
            viewConfig  : { stripeRows : false },
            border      : 0,
            bodyCls     : 'noHeaderGridCls',
            tpl         : '<i>{collectionFuncName}</i>',
            bodyStyle   : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
            style       : 'background-color: #FFFFFF',
            store       : queriesFuncStore,
            resizable   : false,
            columns     :
            [
              { flex : 1, dataIndex : 'queryFuncName', sortable : false, hideable : false, cls : "genbKb-accordion-item", renderer : function(value, metaData, record, row, col, store, view) { return Ext.String.format('<div class="genbKb-accordion-item {2}">{1}</div>', record.data.url, record.data.queryFuncName, record.data.genbKbIconCls); } }
            ]
          })
        ]
      },
      // MANAGE VIEWS
      {
        title  : 'Manage Views',
        layout : 'fit',
        frame  : true,
        bodyStyle : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
        style : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
        items  :
        [
          Ext.create('Ext.grid.Panel',
          {
            header      : false,
            hideHeaders : true,
            disabled    : true,
            collapsed   : false,
            sortableColumns : false,
            stateful    : false,
            enableColumnResize : false,
            rowLines    : false,
            frame       : false,
            viewConfig  : { stripeRows : false },
            border      : 0,
            bodyCls     : 'noHeaderGridCls',
            tpl         : '<i>{collectionFuncName}</i>',
            bodyStyle   : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
            style       : 'background-color: #FFFFFF',
            store       : viewsFuncStore,
            resizable   : false,
            columns     :
            [
              { flex : 1, dataIndex : 'viewFuncName', sortable : false, hideable : false, cls : "genbKb-accordion-item", renderer : function(value, metaData, record, row, col, store, view) { return Ext.String.format('<div class="genbKb-accordion-item {2}">{1}</div>', record.data.url, record.data.viewFuncName, record.data.genbKbIconCls); } }
            ]
          })
        ]
      },
      // MANAGE DATA SETS
      {
        title  : 'Manage Collections',
        layout : 'fit',
        frame  : true,
        bodyStyle : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
        style : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
        items  :
        [
          Ext.create('Ext.grid.Panel',
          {
            header      : false,
            hideHeaders : true,
            collapsed   : false,
            sortableColumns : false,
            stateful    : false,
            enableColumnResize : false,
            disabled    : true,
            rowLines    : false,
            frame       : false,
            viewConfig  : { stripeRows : false },
            border      : 0,
            bodyCls     : 'noHeaderGridCls',
            tpl         : '<i>{collectionFuncName}</i>',
            bodyStyle   : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
            style       : 'background-color: #FFFFFF',
            store       : collectionFuncStore,
            resizable   : false,
            features    : collectionFuncGroupingFeature,
            columns     :
            [
              { text : 'Category', flex : 1, dataIndex : 'category', sortable : false, hideable : false },
              { flex : 1, dataIndex : 'collectionFuncName', sortable : false, hideable : false, cls : "genbKb-accordion-item", renderer : function(value, metaData, record, row, col, store, view) { return Ext.String.format('<div class="genbKb-accordion-item {2}">{1}</div>', record.data.url, record.data.collectionFuncName, record.data.genbKbIconCls); } }
            ],
            listeners :
            {
              // Expand first group (public projects) once grid is viewable
              viewready :
              {
                el : 'el',
                fn : function(grid, width, height, eOpts) {
                  grid.features[0].expand('All Users', false) ;
                  return true ;
                }
              },
              refresh :
              {
                fn : function(grid, eOpts) { grid.features[0].expand('', true) ; }
              }
            }
          })
        ]
      }
    ]
  }
] ;

function renderDocTreeGrid()
{
  destroyModelTableGrid() ;
  destroyModelTree() ;
  if(!Ext.getCmp('mainTreeGrid'))
  {
    initTreeGrid() ;
  }
  editModeValue = false ; // This is returned from the 'before edit' event of the row plugin.
  if(documentEdited) {
    Ext.getCmp('mainTreeGrid').setTitle(getModifiedTitle(editModeValue)) ;
  }
  else
  {
    Ext.getCmp('mainTreeGrid').setTitle('Edit Mode: OFF') ;  
  }
  
  toggleNodeOperBtn(false) ;  
  Ext.getCmp('manageDocsGrid').getSelectionModel().deselectAll() ;
  Ext.getCmp('manageModelsGrid').getSelectionModel().deselectAll() ;
  if(docModel) {
    Ext.getCmp('searchComboBox').enable() ;
    if (prevDocId) {
      Ext.getCmp('searchComboBox').setValue(prevDocId) ;
      //oadDocument(prevDocId) ;
      prevDocId = null ;
    }
  }
}
