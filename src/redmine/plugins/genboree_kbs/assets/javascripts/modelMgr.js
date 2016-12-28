function displayModelTree()
{
  // Determine if we reached here  via the link on the model versions grid or the 'View Model (tree)' buttn
  if (modelLinkClick) {
    modelLinkClick = false ;
  }
  else
  {
    if (!showModelTree) {
      modelVersion = "" ;
    }
  }
  var msg = "How would you like to view the model? This will display the current version of the model." ;
  msg += "</br></br><b>NOTE</b>: Viewing the model in the current tab will replace the tab's contents." ;
  if(documentEdited)
  {
    msg += "</br></br>We advise you to save the current document first before viewing the model." ;
  }
  if(newdocObj || Ext.getCmp('viewGrid') || Ext.getCmp('docsVersionsGrid') || Ext.getCmp('modelVersionsGrid')) // Render a warning if a document is already loaded
  {
    Ext.Msg.show({
      title: "View Model",
      msg: msg,
      width: 500,
      //buttons: Ext.Msg.YESNO,
      buttonText: {yes: 'Open model in current tab', no: 'Open model in new tab', cancel: 'Cancel'},
      id: 'viewModelMessBox',
      fn: function(btn){
        if(btn == 'yes')
        {
          editModeValue = false ; // This is returned from the 'before edit' event of the row plugin.
          Ext.getCmp('manageDocsGrid').getSelectionModel().deselectAll() ;
          Ext.getCmp('browseDocsGrid').getSelectionModel().deselectAll() ;
          disablePanelBtn('editDelete') ;
          disablePanelBtn('docHistory') ;
          loadModelTree() ;
        }
        else if (btn == 'no') {
          Ext.getCmp('manageModelsGrid').getView().deselect(0) ;
          var urlLink = "http://"+location.host+kbMount+"/genboree_kbs?project_id="+projectIdentifier+"&coll="+escape(Ext.getCmp('collectionSetCombobox').value)+"&showModelTree=true&modelVersion="+escape(modelVersion) ;
          var win = window.open(urlLink, '_blank') ;
          win.focus() ;
          // GO back to viewing the model history if we are coming from there
          if (Ext.getCmp('modelVersionsGrid')) {
            Ext.getCmp('manageModelsGrid').getView().select(1) ;
          }
        }
        else
        {
          // The user has cancelled the selection
          Ext.getCmp('manageModelsGrid').getView().deselect(0) ;
          // GO back to viewing the model history if we are coming from there
          if (Ext.getCmp('modelVersionsGrid')) {
            Ext.getCmp('manageModelsGrid').getView().select(1) ;
          }
        }
      }
    }) ;
  }
  else
  {
    Ext.getCmp('manageDocsGrid').getSelectionModel().deselectAll() ;
    Ext.getCmp('browseDocsGrid').getSelectionModel().deselectAll() ;
    disablePanelBtn('docHistory') ;
    loadModelTree() ;  
  }
}

function loadModelTree()
{
  // Save the document id in case user goes to document viewer after viewing the model
  var ii ;
  var displayFields = [] ;
  if (!freshDocument && newdocObj && newdocObj[docModel.name]) {
    prevDocId = newdocObj[docModel.name].value ;
  }
  resetMainPanel() ;
  var treeDataStruct ;
  // Load a specific version of the model if not empty
  if (modelVersion != "")
  {
    loadSpecificModelVer() ;
  }
  else // use the currently loaded one
  {
    treeDataStruct = getTreeStructForDataModel(docModel) ;
    renderModelTree(treeDataStruct) ;
  }
  
}


function renderModelTree(treeDataStruct)
{
  var extraFields = Object.keys(nonCoreFields) ;
  defineModelForModelView(Object.keys(corePropFields).concat(extraFields)) ;
  var modelTreeStore = Ext.create('Ext.data.TreeStore',
  {
    model : 'ModelTree',
    proxy : 'memory',
    root  :
    {
      expanded: true,
      children: [treeDataStruct]
    },
  }) ;
  var columns = getDisplayColumns(extraFields) ;
  initModelTreeToolbar() ; // defined in toolbars.js
  var mver = ( modelVersion == "" ? "Current" : modelVersion ) ;
  var modelTree = Ext.create('Ext.tree.Panel', {
      title: 'Model Tree (Version: '+mver+')',
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
          },
          itemcontextmenu: function(thisObj, record, item, index, e, eOpts){
            displayPropMenuForModelTree(e, true)
          },
          itemmouseenter: function(thisObj, record, item, index, e, eOpts){
            selectedModelTreeRecord = record ;
          },
          
        },
        enableTextSelection: true
      },
      listeners: {
        beforeitemexpand: function(node, eOpts) {
          Ext.suspendLayouts() ;
          
        },
        afteritemexpand: function(node, index, item , eOpts){
          Ext.resumeLayouts(true) ;
          
        }
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

// Gets the 'modelVersion' version of the model.
// Required for getting specific version of a model to support the model versions grid
function loadSpecificModelVer()
{
  var coll = Ext.getCmp('collectionSetCombobox').value ;
  Ext.Ajax.request(
  {
    url : 'genboree_kbs/model/show',
    timeout : 90000,
    method: 'GET',
    params:
    {
      "authenticity_token": csrf_token,
      project_id: projectId,
      collectionSet: coll,
      version: modelVersion
    },
    callback : function(opts, success, response)
    {
      try
      {
        var apiRespObj  = JSON.parse(response.responseText) ;
        var docModelObj = apiRespObj['data'] ;
        var statusObj   = apiRespObj['status'] ;

        if(response.status >= 200 && response.status < 400 && docModelObj)
        {
          
          var treeDataStruct = getTreeStructForDataModel(docModelObj['versionNum']['properties']['content']['value']['name']['properties']['model']['value']) ;
          renderModelTree(treeDataStruct) ;
          //Ext.getCmp('manageModelsGrid').getView().select(0) ;
        }
        else
        {
          var displayMsg = "The following error was encountered while retrieving the specific version of model for the collection '<i>" + coll + "</i>' :<br><br>" ;
          displayMsg += ( "<b>Error Code:</b> <i>" + (statusObj['statusCode'] ? statusObj['statusCode'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" ) ;
          displayMsg += ( "<b>Error Message:</b> <i>" + (statusObj['msg'] ? statusObj['msg'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" );
          displayMsg += "<br><br>Please contact a project admin to resolve this issue." ;
          Ext.Msg.alert("ERROR", displayMsg) ;
        }
      }
      catch(err)
      {
        Ext.Msg.alert('ERROR', "Bad data returned from server when retrieving specific version of model for collection '<i>" + coll + "</i>'.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
      }
    }
  }) ;
}


// returns only the columns to be displayed in the tree-grid
// Adds the core columns followed by any extra columns and finally removes any columns that are in the kill list
function getDisplayColumns(extraFields)
{
  var ii ;
  var columns = [] ;
  // First add the core columns
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
        var retVal = "<span ";
        if(md.record.data.description)
        {
          retVal = retVal + 'data-qtip='+'"'+md.record.data.description+'"' ;
        }
        if(md.record.data.category)
        {
          retVal = retVal +" class=\"genbKb-category-font-weight\">"+value ;
        }
        else
        {
          retVal = retVal + ">"+value ;
        }
        retVal = retVal + "</span>" ;
        var id = Math.random() ;
        var menuBtnLink = "" ;
        if (!md.record.data.leaf) {
          menuBtnLink = "<a id="+id+" data-qtip='Click to open context menu.' href=\"\" onclick=\"return displayPropMenuForModelTree(this.id, false)\">"+"<img class=\"genbKb-prop-menu-default\" src='plugin_assets/genboree_kbs/images/silk/application_view_list.png'>"+"</a>" ;
        }
        retVal = retVal + menuBtnLink ;
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
      dataIndex: 'itemList'
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
      dataIndex: 'index_field'
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
  // Add any non-core columns
  for(ii=0; ii<extraFields.length; ii++)
  {
    var fieldName = extraFields[ii] ;
    allColumns.push({
      //text: capitaliseFirstLetter(fieldName),
      text: fieldName,
      sortable: false,
      componentCls: 'modelGridHeader',
      flex: 1,
      dataIndex: nonCoreFields[fieldName]
    }) ;
  }
  // Only keep the columns that are not in the kill list
  for(ii=0; ii<allColumns.length; ii++)
  {
    if(!modelGridKillList[allColumns[ii].dataIndex])
    {
      columns.push(allColumns[ii]) ;
    }
  }
  return columns ;
}

// Displays the property-menu when a property is right clicked or small icon adjacent (which pops when a row is hovered over) is clicked
// Provides functionality to expand and collapse
// If showAt = true, e will be the event which will be used to get the x-y coordinates to place the menu, otherwise it will be the id of the element *by* which the menu will be displayed
function displayPropMenuForModelTree(e, showAt)
{
  var record = selectedModelTreeRecord ;
  // Destroy the previous menu if present
  if (Ext.getCmp('propertyContextMenu')) {
    Ext.getCmp('propertyContextMenu').close() ;
  }
  if (showAt) {
    e.preventDefault() ;
  }
  var disabled = (record.data.leaf ? true : false ) ;
  var modelTreePropMenu = Ext.create('Ext.menu.Menu', {
    id: 'propertyContextMenu',
    plain: true,
    floating: true,
    draggable: true,
    items: [
      {
        itemId: 'expandModelPropBtn',
        disabled: disabled,
        text: 'Fully Expand',
        icon: 'plugin_assets/genboree_kbs/images/silk/arrow_out.png',
        tooltip: {
          title: 'Expand',
          text: 'Fully expand the selected property. Only available for properties with sub-properties.'
        },
        handler : function(){
          //Ext.suspendLayouts() ;
          record.expand(true) ;
          //Ext.resumeLayouts(true) ;
        }
      },
      {
        itemId: 'collapseModelPropBtn',
        disabled: disabled,
        text: 'Fully Collapse',
        icon: 'plugin_assets/genboree_kbs/images/silk/arrow_in.png',
        tooltip: {
          title: 'Collapse',
          text: 'Fully collapse the selected property. Only available for properties with sub-properties.'
        },
        handler : function(){
          record.collapse(true) ;
        }
      }
    ]
  }) ;
  if (showAt) {
    modelTreePropMenu.showAt(e.getXY()) ;
  }
  else{
    modelTreePropMenu.showBy(e) ;
  }
  return false ;
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

// Creates the appropriate structure required by ExtJS to render the grid
// Adds the 'core' fields and also any extra non-core fields the model might have
function getModelTreeNode(node, children)
{
  var retObj = {} ;
  var ii ;
  var coreFields = Object.keys(corePropFields) ;
  var field ;
  for(ii=0; ii<coreFields.length; ii++)
  {
    field = coreFields[ii] ;
    if (field == 'itemList') // There is no actual field called itemList
    {
      retObj['itemList'] = ( node.items ? 'true': '' ) ;
    }
    else if (field == 'default') {
      retObj[field] = node[field] ? node[field] : ""
    }
    else // for other fields
    {
       // ExtJS has some issues with using 'index' as dataIndex. Add index_field with the same value
      if (field == 'index_field')
      {
        retObj['index_field'] = ( node['index'] ? corePropFields['index_field']['value'] : corePropFields['index_field']['default'] );
      }
      else
      {
        if(node[field])
        {
          retObj[field] =  ( ( field == 'name' || field == 'domain' || field == 'description' ) ? node[field] : corePropFields[field]['value'] ) ;
        }
        else
        {
          retObj[field] = corePropFields[field]['default']  ;
        }
      }
     
    }
  }
  // Next add any 'non-core' keys the model might have
  var nodeKeys = Object.keys(node) ;
  var nodekey ;
  for(ii=0; ii<nodeKeys.length; ii++)
  {
    nodeKey = nodeKeys[ii] ;
    if (!corePropFields[nodeKey] && nodeKey != 'properties' && nodeKey != 'index' && nodeKey != 'items') {
      var randStr
      if (!nonCoreFields[nodeKey]) {
        randStr = Math.random().toString(36).substring(7) ;
        nonCoreFields[nodeKey] = randStr ;
      }
      else
      {
        randStr = nonCoreFields[nodeKey] ;
      }
      retObj[randStr] = node[nodeKey] ;
    }
  }
  // If node is identifier, set unique and and required as true
  if (node.identifier) {
    retObj['required'] = 'true' ;
    retObj['unique'] = 'true' ;
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
  retObj['text'] = retObj['name'] ;
  return retObj ;
}



