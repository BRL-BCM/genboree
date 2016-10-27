var browseFuncStore = Ext.create('Ext.data.Store',
{
  storeId    : 'recordFunc',
  model      : 'BrowseRecord',
  data       :
  [
    { browseFuncName : 'As Dynamic tree', genbKbIconCls : 'genbKb-dynamicTree' },
    //{ browseFuncName : 'As Plain HTML', genbKbIconCls : 'genbKb-plainHTML', hidden: true},
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
    { recordFuncName : 'Create new Document', genbKbIconCls : 'genbKb-createRecord', displayStr: 'Create Document' },
    { recordFuncName : 'Create new Document with Template', genbKbIconCls : 'genbKb-createRecord', displayStr: 'Create Document (Template)' },
    { recordFuncName : 'Create new Document with Questionnaire', genbKbIconCls : 'genbKb-createRecord', displayStr: 'Create Document (Questionnaire)' },
    { recordFuncName : 'Edit Document', genbKbIconCls : 'genbKb-editRecord', displayStr: 'Edit Document' },
    { recordFuncName : 'Delete Document', genbKbIconCls : 'genbKb-deleteRecord', displayStr: 'Delete Document' },
    { recordFuncName : 'History', genbKbIconCls : 'genbKb-recordHistory', displayStr: 'Document History' }
  ]
}) ;
// Models
var modelsFuncStore = Ext.create('Ext.data.Store',
{
  storeId    : 'modelFunc',
  model      : 'ManageModels',
  data       :
  [
    { modelFuncName : 'View Model (Tree)', genbKbIconCls : 'genbKb-dynamicTree', displayStr: 'View Model' },
    { modelFuncName : 'History', genbKbIconCls : 'genbKb-recordHistory', displayStr: 'Model History' },
    { modelFuncName : 'Create new Model', genbKbIconCls : 'genbKb-createRecord', displayStr: 'Create Model' }
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
                  if(!mainPanelInUse()) {
                    renderDocTreeGrid() ;
                  }
                  else{
                    var msg = "How would you like to browse the documents?</br></br><b>NOTE</b>: Opening the document browser in the current tab will replace the tab's contents." ;
                    if (documentEdited) {
                      msg = msg + "</br></br><b>Warning</b>: You have unsaved changes for the current document. We would advise you to save the document in case you want to open in the same tab." ;
                    }
                    Ext.Msg.show({
                      title: "Document Browser",
                      width: 500,
                      msg: msg,
                      buttonText: {yes: 'Open in current tab', no: 'Open in new tab', cancel: 'Cancel'},
                      id: 'viewModelMessBox',
                      fn: function(btn){
                        // Add handlers to the buttons above which will solicit the name of the identifier if the user does decide to start a new document
                        if(btn == 'yes')
                        {
                          renderDocTreeGrid() ; // defined in editorTreeGrid.js
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
            listeners: {
              'beforeselect': function(aa, bb){
                var retVal = true ;
                var funcName = bb.data.recordFuncName ;
                if(funcName == 'Create new Document' || funcName == 'Create new Document with Template' || funcName == 'Create new Document with Questionnaire')
                {
                  if(role == null || role == 'subscriber'){
                    retVal = false ;                    
                  }
                  else{
                    if(docModel) // model has been loaded
                    {
                      Ext.getCmp('browseDocsGrid').getSelectionModel().deselectAll() ;
                      Ext.getCmp('manageModelsGrid').getSelectionModel().deselectAll() ;
                      if (funcName == 'Create new Document with Template') {
                        createNewDocumentWithTemplate() ;
                      }
                      else if (funcName == 'Create new Document with Questionnaire') {
                        if (!Ext.getCmp('questionnaireGrid')) {
                          createNewDocumentWithQuestionnaire() ;
                        }
                      }
                      else{
                        createNewDocument()  ;
                      }
                    }
                    else
                    {
                      retVal = false ;
                    }
                  }
                }
                else
                {
                  if(funcName == 'Edit Document')
                  {
                    if(role == null || role == 'subscriber'){
                      retVal = false ;                    
                    }
                    else{
                      if (newdocObj) {
                        editModeValue = true ; // This is returned from the 'before edit' event of the row plugin.
                        if(documentEdited)
                        {
                          Ext.getCmp('mainTreeGrid').setTitle(getModifiedTitle(editModeValue)) ;
                        }
                        else
                        {
                          var title = 'Edit Mode: ON' ;
                          title = addDocVerStr(title) ;
                          Ext.getCmp('mainTreeGrid').setTitle(title) ;  
                        }
                        toggleNodeOperBtn(true) ;
                        Ext.getCmp('browseDocsGrid').getSelectionModel().deselectAll() ;
                        Ext.getCmp('manageModelsGrid').getSelectionModel().deselectAll() ;
                      }
                      else{
                        retVal = false ;
                      }  
                    }
                  }
                  else if (funcName == 'Delete Document') 
                  {
                    if(role == null || role == 'subscriber'){
                      retVal = false ;                    
                    }
                    else{
                      if (newdocObj) {
                        Ext.Msg.show({
                          title: "Delete Document",
                          msg: "This will permanently delete the document. Are you sure you want to continue?</br></br><b>NOTE</b>: This will delete the current version of the document.",
                          buttons: Ext.Msg.YESNO,
                          id: 'deleteDocumentMessBox',
                          fn: function(btn){
                            if(btn == 'yes')
                            {
                              clearAndReloadTree(null) ;
                              disablePanelBtn('editDelete') ;
                              Ext.getCmp('manageDocsGrid').getSelectionModel().deselectAll() ;
                              Ext.getCmp('mainTreeGrid').setTitle('Edit Mode: OFF') ;
                              editModeValue = false ; // This is returned from the 'before edit' event of the row plugin.
                              toggleNodeOperBtn(false) ;
                              newdocObj = null ;
                              // delete the document from the database/server
                              if(!freshDocument)
                              {
                                var identifier = Ext.getCmp('searchComboBox').value
                                deleteDocument(identifier) ; // defined in ajax.js
                              }
                            }
                            else
                            {
                              funcGridsBtnToggler('manageDocsGrid', 'Delete Document', 'deselect') ;
                              funcGridsBtnToggler('manageDocsGrid', 'Edit Document', 'select') ;
                            }
                            Ext.getCmp('browseDocsGrid').getSelectionModel().deselectAll() ;
                            Ext.getCmp('manageModelsGrid').getSelectionModel().deselectAll() ;
                          }
                        }) ;
                      }
                      else{
                        retVal = false ;
                      }
                    }
                  }
                  else if (funcName == 'History') {
                    if (newdocObj && !freshDocument)
                    {
                      Ext.Msg.show({
                        title: "Warning",
                        msg: "How would you like to view the document's history?</br></br><b>NOTE: </b>Opening the grid in the current tab will replace the tab's current contents.",
                        buttonText: {yes: 'Open in current tab', no: 'Open in new tab', cancel: 'Cancel'},
                        fn: function(btn){
                          if(btn == 'yes')
                          {
                            loadDocVersions() ; // defined in versions.js
                            Ext.getCmp('browseDocsGrid').getSelectionModel().deselectAll() ;
                            Ext.getCmp('manageModelsGrid').getSelectionModel().deselectAll() ;
                          }
                          else if (btn == 'no')
                          {
                            var urlLink = "http://"+location.host+kbMount+"/genboree_kbs?project_id="+projectIdentifier+"&coll="+escape(currentCollection)+"&showDocsVersionsGrid=true"+"&doc="+escape(originalDocumentIdentifier) ;
                            var win = window.open(urlLink, '_blank') ;
                            win.focus() ;
                            funcGridsBtnToggler('manageDocsGrid', 'History', 'deselect') ;
                            // Set Edit Mode: true if user was editing the document
                            if (editModeValue) {
                              funcGridsBtnToggler('manageDocsGrid', 'Edit Document', 'select') ;
                            }
                          }
                          else
                          {
                            funcGridsBtnToggler('manageDocsGrid', 'History', 'deselect') ;
                            // Set Edit Mode: true if user was editing the document
                            if (editModeValue) {
                              funcGridsBtnToggler('manageDocsGrid', 'Edit Document', 'select') ;
                            }
                          }
                        }
                      }) ;
                    }
                    else
                    {
                      if (showDocsVersionsGrid) {
                        loadDocVersions() ; // defined in docVersions.js
                        showDocsVersionsGrid = false ;
                      }
                      else{
                        retVal = false ;
                      }
                    }
                    
                  }
                }
                return retVal ;
              }
            },
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
                  if(recName == 'Create new Document' || recName == 'Create new Document with Template' || recName == 'Create new Document with Questionnaire')
                  {
                    return 'genbKb-gray-font-create' ;
                  }
                  else if (recName == 'History')
                  {
                    return 'genbKb-gray-font-doc-history' ;
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
              { flex : 1, dataIndex : 'recordFuncName', sortable : false, hideable : false, cls : "genbKb-accordion-item", renderer : function(value, metaData, record, row, col, store, view) { return Ext.String.format('<div class="genbKb-accordion-item {2}">{1}</div>', record.data.url, record.data.displayStr, record.data.genbKbIconCls); } }
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
                    if (bb.data.modelFuncName == 'View Model (Tree)')
                    {
                      displayModelTree() ;
                    }
                    else if (bb.data.modelFuncName == 'History') {
                      if (Ext.getCmp('modelTreeGrid') || newdocObj || Ext.getCmp('docsVersionsGrid') || Ext.getCmp('viewGrid') || Ext.getCmp('questionnaireGrid'))
                      {
                        Ext.Msg.show({
                          title: "Warning",
                          msg: "How would you like to view the model history?</br></br><b>NOTE: </b>Opening the history in the current tab will replace the tab's current contents.",
                          buttonText: {yes: 'Open in current tab', no: 'Open in new tab', cancel: 'Cancel'},
                          fn: function(btn){
                            if(btn == 'yes')
                            {
                              loadModelVersions() ; 
                            }
                            else if (btn == 'no')
                            {
                              var urlLink = "http://"+location.host+kbMount+"/genboree_kbs?project_id="+projectIdentifier+"&coll="+escape(Ext.getCmp('collectionSetCombobox').value)+"&showModelVersionsGrid=true" ;
                              var win = window.open(urlLink, '_blank') ;
                              win.focus() ;
                              Ext.getCmp('manageModelsGrid').getView().deselect(1) ;
                              // GO back to viewing the model tree if we are coming from there
                              if (Ext.getCmp('modelTreeGrid')) {
                                Ext.getCmp('manageModelsGrid').getView().select(0) ;
                              }
                            }
                            else
                            {
                              Ext.getCmp('manageModelsGrid').getView().deselect(1) ;
                              // GO back to viewing the model tree if we are coming from there
                              if (Ext.getCmp('modelTreeGrid')) {
                                Ext.getCmp('manageModelsGrid').getView().select(0) ;
                              }
                            }
                          }
                        }) ;
                      }
                      else
                      {
                        loadModelVersions() ; // defined in modelVersions.js
                      }
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
                if(recName == 'Create new Model')
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
              { flex : 1, dataIndex : 'modelFuncName', sortable : false, hideable : false, cls : "genbKb-accordion-item", renderer : function(value, metaData, record, row, col, store, view) { return Ext.String.format('<div class="genbKb-accordion-item {2}">{1}</div>', record.data.url, record.data.displayStr, record.data.genbKbIconCls); } }
            ]
          })
        ]
      },
      // MANAGE QUERIES
      {
        title  : 'Manage Queries',
        layout : 'fit',
        frame  : true,
        hidden: true,
        bodyStyle : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
        style : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
        items  :
        [
          Ext.create('Ext.grid.Panel',
          {
            header      : false,
            disabled    : true,
            hideHeaders : true,
            id          : 'manageQueriesGrid',
            collapsed   : true,
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
        hidden: true,
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
            collapsed   : true,
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
        hidden: true,
        bodyStyle : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
        style : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
        items  :
        [
          Ext.create('Ext.grid.Panel',
          {
            header      : false,
            hideHeaders : true,
            collapsed   : true,
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


function mainPanelInUse()
{
  retVal = true ;
  if(!Ext.getCmp('viewGrid') && !Ext.getCmp('modelTreeGrid') && !Ext.getCmp('docsVersionsGrid') && !Ext.getCmp('modelVersionsGrid') && !newdocObj && !Ext.getCmp('questionnaireGrid'))
  {
    retVal = false ;    
  }
  return retVal ;
}

function funcGridsBtnToggler(section, btnName, action)
{
  var selModel = Ext.getCmp(section).getSelectionModel() ;
  var btns = selModel.store.data.items ;
  var ii ;
  for(ii=0; ii<btns.length; ii++)
  {
    var btn = btns[ii] ;
    if (btn.data.recordFuncName == btnName) {
      if (action == 'select') {
        selModel.select(btn) ;
      }
      else{
        selModel.deselect(btn) ;
      }
      break ;
    }
  }
}