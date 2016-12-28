function displayModelTree()
{
  var msg = "How would you like to view the model?" ;
  
  msg += "</br></br><b>NOTE</b>: Viewing the model in the current tab will replace the current document." ;
  if(documentEdited)
  {
    msg += "</br></br>We advise you to save the current document first before viewing the model." ;
  }
  if(newdocObj) // Render a warning if a document is already loaded
  {
    Ext.Msg.show({
      title: "View Model",
      msg: msg,
      width: 500,
      //buttons: Ext.Msg.YESNO,
      buttonText: {yes: 'Open model in current tab', no: 'Open model in new tab', cancel: 'Cancel'},
      id: 'viewModelMessBox',
      fn: function(btn){
        // Add handlers to the buttons above which will solicit the name of the identifier if the user does decide to start a new document
        if(btn == 'yes')
        {
          editModeValue = false ; // This is returned from the 'before edit' event of the row plugin.
          Ext.getCmp('manageDocsGrid').getSelectionModel().deselectAll() ;
          Ext.getCmp('browseDocsGrid').getSelectionModel().deselectAll() ;
          disableEditDelete() ;
          loadModelTree() ;
        }
        else if (btn == 'no') {
          Ext.getCmp('manageModelsGrid').getSelectionModel().deselectAll() ;
          var urlLink = "http://"+location.host+kbMount+"/genboree_kbs?project_id="+projectIdentifier+"&coll="+Ext.getCmp('collectionSetCombobox').value+"&showModelTree=true" ;
          var win = window.open(urlLink, '_blank') ;
          win.focus() ;
        }
        {
          // Do nothing
        }
      }
    }) ;
  }
  else
  {
    Ext.getCmp('manageDocsGrid').getSelectionModel().deselectAll() ;
    Ext.getCmp('browseDocsGrid').getSelectionModel().deselectAll() ;
    loadModelTree() ;  
  }
}

function loadModelTree()
{
  // Save the document id in case user goes to document viewer after viewing the model
  if (!freshDocument && newdocObj && newdocObj[docModel.name]) {
    prevDocId = newdocObj[docModel.name].value ;
  }
  // Destroy previous instances of model tree/editor tree grid
  destroyEditorTree() ;
  destroyModelTree() ;
  destroyModelTableGrid() ;
  var treeDataStruct = getTreeStructForDataModel(docModel) ;
  var modelTreeStore = Ext.create('Ext.data.TreeStore',
  {
    model : 'ModelTree',
    proxy : 'memory',
    root  :
    {
      expanded: true,
      children: treeDataStruct
    }
  }) ;
  // Remove the fields in the kill list // defined in globals.js
  var columns = [] ;
  var allColumns = [
    {
      xtype: 'treecolumn', //this is so we know which column will show the tree
      text: 'Name',
      flex: 2,
      dataIndex: 'name',
      componentCls: 'modelGridHeader',
      //menuDisabled: true,
      columnWidth: 200,
      sortable: false,
      draggable: false,
      editable: false,
      renderer: function(value, md, rec, ri, ci, store, view){
        var retVal ;
        if(md.record.data.identifier || md.record.data.category)
        {
          retVal = "<span class=\"genbKb-category-font-weight\">"+value+"</span>" ;
        }
        else
        {
          retVal = value ;
        }
        // Add description as tooltip
        if(md.record.data.description)
        {
          md.tdAttr = "data-qtip=\""+md.record.data.description+"\"" ;
        }
        return retVal ;
      }
   },
   {
      text: 'Domain',
      componentCls: 'modelGridHeader',
      sortable: false,
      minWidth: modelFieldsHash['domain']['minWidth'],
      //minWidth: modelFieldsHash['domain']['maxWidth'], // set a minimum for domain. This column will be excluded from auto-sizing.
      flex: 1,
      dataIndex: 'domain',
      renderer: function(value, md, rec, ri, ci, store, view){
        var retVal ;
        // Add domain as tool-tip. This is particularly useful for enums/regexp
        md.tdAttr = "data-qtip=\""+md.record.data.domain+"\"" ;
        return value ;
      }
    },
    {
      text: 'Item List',
      componentCls: 'modelGridHeader',
      sortable: false,
      flex: 1,
      dataIndex: 'itemlist'
    },
    {
      text: 'Identifier',
      componentCls: 'modelGridHeader',
      sortable: false,
      flex: 1,
      dataIndex: 'identifier'
    },
    {
      text: 'Required',
      sortable: false,
      componentCls: 'modelGridHeader',
      flex: 1,
      dataIndex: 'required'
    },
    {
      text: 'Unique',
      componentCls: 'modelGridHeader',
      sortable: false,
      flex: 1,
      dataIndex: 'unique'
    },
    {
      text: 'Category',
      sortable: false,
      componentCls: 'modelGridHeader',
      flex: 1,
      dataIndex: 'category'
    },
    {
      text: 'Fixed',
      componentCls: 'modelGridHeader',
      sortable: false,
      flex: 1,
      dataIndex: 'fixed'
    },
    {
      text: 'Index',
      sortable: false,
      componentCls: 'modelGridHeader',
      flex: 1,
      dataIndex: 'index'
    },
    {
      text: 'Default',
      sortable: false,
      componentCls: 'modelGridHeader',
      flex: 1,
      dataIndex: 'default'
    },
    {
      text: 'Description',
      sortable: false,
      componentCls: 'modelGridHeader',
      flex: 1,
      dataIndex: 'description',
      renderer: function(value, md, rec, ri, ci, store, view){
        md.tdAttr = "data-qtip=\""+md.record.data.description+"\"" ;
        return value ;
      }
    }
  ] ;
  for(ii=0; ii<allColumns.length; ii++)
  {
    if(!modelGridKillList[allColumns[ii].dataIndex])
    {
      columns.push(allColumns[ii]) ;
    }
  }
  initModelTreeToolbar() ; // defined in toolbars.js
  var modelTree = Ext.create('Ext.tree.Panel', {
      title: 'Model Tree',
      //width: let it autoscale
      //width: 1000,
      height: panelHeight-35, // set height to total hight of layout panel - height of menubar
      renderTo: 'treeGridContainer-body',
      collapsible: false,
      useArrows: true,
      id: 'modelTreeGrid',
      tbar: Ext.getCmp('modelTreeToolbar'), // defined in toolbars.js
      store: modelTreeStore,
      rootVisible: false,
      multiSelect: false,
      //overflowX: 'scroll',
      viewConfig: {
        listeners: {
            refresh: function(dataview){
              Ext.each(dataview.panel.columns, function(column){
                if (column.text != 'Domain')
                {
                  column.autoSize() ;
                }
                  
              })
            }
        },
        enableTextSelection: true
      },
      singleExpand: false,
      selType: 'rowmodel',
      //the 'columns' property is now 'headers'   
      columns: columns,
      sortableColumns: false
  });
  documentEdited = false ;
  newdocObj = null ;
  freshDocument = false ;
}



// Recursive function to generate nodes for the tree view of the data model.
function getTreeStructForDataModel(node)
{
  var ii ;
  var children = [] ;
  var retVal ;
  if (node.properties) {
    for(ii=0; ii<node.properties.length; ii++)
    {
      var prop = node.properties[ii] ;
      children.push(getTreeStructForDataModel(prop)) ;
    }
    retVal = getModelTreeNode(node, children) ;
  }
  else if (node.items) {
    // Items must be singly rooted
    var prop = node.items[0] ;
    children.push(getTreeStructForDataModel(prop)) ;
    retVal = getModelTreeNode(node, children) ;
  }
  else{
    retVal = getModelTreeNode(node, children) ;
  }
  return retVal ;
}

function getModelTreeNode(node, children)
{
  var retObj = {
    name: node.name,
    domain: node.domain ? node.domain : 'string',
    itemlist: node.items ? 'true': '',
    identifier: node.identifier ? 'true': '',
    required: node.required ? 'true': '',
    unique: node.unique ? 'true': '',
    category: node.category ? 'true': '',
    fixed: node.fixed ? 'true': '',
    index: node.index ? 'true': '',
    'default': node['default'] ? node['default'] : '',
    description: node.description ? node.description : '',
  }
  if (children.length > 0) {
    retObj['children'] = children ;
    retObj['iconCls'] = 'task-folder' ;
  }
  else{
    retObj['iconCls'] = 'task' ;
    retObj['leaf'] = true ;
  }
  if (node.identifier) {
    retObj['expanded'] = true ;
  }
  return retObj ;
}

// Clears the panel of any documents (if any) and loads up the data model grid for viewing
function displayModelTable()
{
  var msg = "Viewing the model will remove the document being currently viewed." ;
  if(documentEdited)
  {
    msg += "</br></br>We advise you to save the current document first before viewing the model." ;
  }
  msg += "</br></br>Are you sure you want to continue?" ;
  if(newdocObj) // Render a warning if a document is already loaded
  {
    Ext.Msg.show({
      title: "View Model",
      msg: msg,
      buttons: Ext.Msg.YESNO,
      id: 'viewModelMessBox',
      fn: function(btn){
        // Add handlers to the buttons above which will solicit the name of the identifier if the user does decide to start a new document
        if(btn == 'yes')
        {
          clearAndReloadTree(null) ;
          loadModelTable() ;
        }
        else
        {
          // Do nothing
        }
      }
    }) ;
  }
  else
  {
    clearAndReloadTree(null) ;
    loadModelTable() ;  
  }
}




// Renders the model in a grid/table format
function renderModelTable(modelTableData)
{
  var ii ;
  var killList = [] ;
  for(ii=0; ii<modelTableData.length; ii++)
  {
    if(modelTableData[ii]['name'].match(/^(-|\*)*\s/))
    {
      var beforeSpace = modelTableData[ii]['name'].match(/^(-|\*)*\s/)[0].replace(/-/g, "&mdash; ").replace(/ \*/g, "&#42;").replace(/ $/, "") ;
      modelTableData[ii]['name'] = beforeSpace+modelTableData[ii]['name'].match(/\s(?:(.)*)$/)[0] ;
    }
  }
  var fieldsToDisplay = ['name', 'domain', 'identifier', 'required', 'unique', 'category', 'fixed', 'index', 'default', 'description'] ;
  Ext.create('Ext.data.Store', {
    storeId: 'modelGridStore',
    fields: fieldsToDisplay,
    data: modelTableData,
    proxy: {
      type: 'memory',
      reader: {
        type: 'json'
      }
    }
  }) ;
  var allColumns = [ {text: "Name", dataIndex: 'name', componentCls: 'modelGridHeader', renderer: function(value, md, rec, ri, ci, store, view){
    var retVal ;
    //retVal = "<span style=\"font-family:Monospace;\">"+value+"</span>" ;
    retVal = value ;
    // Add description as tooltip
    if(md.record.data.description)
    {
      md.tdAttr = 'data-qtip='+'"'+md.record.data.description+'"' ;
    }
    return retVal ;
  }, sortable: false, minWidth: modelFieldsHash['name']['minWidth'], maxWidth: modelFieldsHash['name']['maxWidth'], draggable: false},
    {text: "Domain", dataIndex: 'domain', componentCls: 'modelGridHeader', minWidth: modelFieldsHash['domain']['minWidth'], maxWidth: modelFieldsHash['domain']['maxWidth'], sortable: false},
    {text: "identifier", dataIndex: 'identifier', componentCls: 'modelGridHeader', sortable: false},
    {text: "Required", dataIndex: 'required', componentCls: 'modelGridHeader', sortable: false},
    {text: "Unique", dataIndex: 'unique', componentCls: 'modelGridHeader', sortable: false},
    {text: "Category", dataIndex: 'category', componentCls: 'modelGridHeader', sortable: false},
    {text: "Fixed", dataIndex: 'fixed', componentCls: 'modelGridHeader', sortable: false},
    {text: "Index", dataIndex: 'index', componentCls: 'modelGridHeader'},
    {text: "Default", dataIndex: 'default', sortable: false, componentCls: 'modelGridHeader'},
    {text: "Description", dataIndex: 'description', minWidth: modelFieldsHash['description']['minWidth'], sortable: false, componentCls: 'modelGridHeader'}
  ]
  // Remove the fields in the kill list // defined in globals.js
  var columns = [] ;
  for(ii=0; ii<allColumns.length; ii++)
  {
    if(!modelGridKillList[allColumns[ii].dataIndex])
    {
      columns.push(allColumns[ii]) ;
    }
  }
  destroyEditorTree() ;
  destroyModelTree() ;
  Ext.create('Ext.grid.Panel', {
    title: 'Model Grid',
    id: 'modelTableGrid',
    store: Ext.data.StoreManager.lookup('modelGridStore'),
    columns: columns,
    height: panelHeight-35, // set height to total hight of layout panel - height of menubar
    renderTo: 'treeGridContainer-body',
    viewConfig: {
      listeners: {
        refresh: function(dataview){
          Ext.each(dataview.panel.columns, function(column){
            column.autoSize() ;  
          })
        }
      }
    }
    //renderTo: 'mainTreeGrid'
  }) ;
  documentEdited = false ;
  newdocObj = null ;
}

function destroyModelTableGrid()
{
  if(Ext.getCmp('modelTableGrid'))
  {
    Ext.getCmp('modelTableGrid').destroy() ;
  }
}

function destroyModelTree()
{
  if(Ext.getCmp('modelTreeGrid'))
  {
    Ext.getCmp('modelTreeGrid').destroy() ;
  }
}

function destroyEditorTree()
{
  if(Ext.getCmp('mainTreeGrid'))
  {
    Ext.getCmp('mainTreeGrid').destroy() ;
  }
}