function loadDocVersions()
{
  maskObj.show() ;
  Ext.Ajax.request(
  {
    url : 'genboree_kbs/versions/all',
    timeout : 90000,
    method: 'GET',
    params:
    {
      identifier: originalDocumentIdentifier,
      "authenticity_token": csrf_token,
      project_id: projectId,
      collectionSet: currentCollection,
      'type': 'doc'
    },
    callback : function(opts, success, response)
    {
      maskObj.hide() ;
      try
      {
        var apiRespObj  = JSON.parse(response.responseText) ;
        var statusObj   = apiRespObj['status'] ;
        var dataObj   = apiRespObj['data'] ;
        if( response.status >= 200 && response.status < 400 && dataObj )
        {
          // No version exists. Ask the user if he/she wants to create one with this one
          if (dataObj.length == 0) {
            Ext.Msg.show({
              title: "NO VERSIONS",
              msg: "No versions were found for this document.</br></br>This is most likely because this document was uploaded as part of a bulk upload which had a bug of not keeping track of the first version of a document.</br></br>You can however, generate a version with the saved copy of this document.",
              buttonText: {yes: 'Create version (Recommended)', cancel: 'Cancel'},
              fn: function(btn){
                if(btn == 'yes')
                {
                  getSavedDocCopy() ;
                }
              }
            }) ;
          }
          else
          {
            renderDocVersionsGrid(dataObj) ;  
          }
        }
        else
        {
          var displayMsg = "The following error was encountered while getting doc versions:<br><br>" ;
          displayMsg += ( "<b>Error Code:</b> <i>" + (statusObj['statusCode'] ? statusObj['statusCode'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" );
          displayMsg += ( "<b>Error Message:</b> <i>" + (statusObj['msg'] ? statusObj['msg'] : "[ NOT INTELLIGIBLE ]") + "</i>" );
          displayMsg += "<br><br>Please contact a project admin to arrange investigation and resolution." ;
          Ext.Msg.alert("ERROR", displayMsg) ;
        }
      }
      catch(err)
      {
        Ext.Msg.alert('ERROR', "Bad data returned from server when getting versions of this document.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
      }
    }
  }) ;
}

function getSavedDocCopy()
{
  maskObj.show() ;
  Ext.Ajax.request(
  {
    url     : 'genboree_kbs/doc/show',
    timeout : 90000,
    method  : 'GET',
    params  :
    {
      "authenticity_token"  : csrf_token,
      project_id            : projectId,
      itemId                : originalDocumentIdentifier,
      docVersion            : "",
      collectionSet         : currentCollection
    },
    callback : function(opts, success, response)
    {
      maskObj.hide() ;
      try
      {
        var apiRespObj  = JSON.parse(response.responseText) ;
        var docObj      = apiRespObj['data'] ;
        var statusObj   = apiRespObj['status'] ;
        if(response.status >= 200 && response.status < 400 && docObj)
        {
          saveSelectedDocVersion(docObj) ;
        }
        else
        {
          var displayMsg = "The following error was encountered while retrieving the document named '<i>" + originalDocumentIdentifier + "</i>' from the collection '<i>" + currentCollection + "</i>' :<br><br>" ;
          displayMsg += ( "<b>Error Code:</b> <i>" + (statusObj['statusCode'] ? statusObj['statusCode'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" );
          displayMsg += ( "<b>Error Message:</b> <i>" + (statusObj['msg'] ? statusObj['msg'] : "[ NOT INTELLIGIBLE ]") + "</i>" );
          displayMsg += "<br><br>Please contact a project admin to arrange investigation and resolution." ;
          Ext.Msg.alert("ERROR", displayMsg) ;
        }
      }
      catch(err)
      {
        Ext.Msg.alert('ERROR', "Bad data returned from server when retrieving the document named '<i>" + originalDocumentIdentifier + "</i>' from the collection '<i>" + currentCollection + "'.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
      }
    }
  }) ;
}


function renderDocVersionsGrid(dataObj)
{
  var title = "Document History" ;
  if (newdocObj) {
    title = title + ' - ' + newdocObj[docModel.name]['value'] ;
  }
  destroyEditorTree() ;
  destroyDocsVersionsGrid() ;
  destroyViewGrid() ;
  destroyModelVersionsGrid() ;
  Ext.getCmp('manageModelsGrid').getSelectionModel().deselectAll() ;
  Ext.getCmp('browseDocsGrid').getSelectionModel().deselectAll() ;
  disablePanelBtn('editDelete') ;
  var ii ;
  var versionsStoreData = [] ;
  var pos = dataObj.length ;
  for(ii=(dataObj.length-1); ii>=0; ii--)
  {
    var verObj = dataObj[ii] ;
    versionsStoreData.push( { 'position': pos, 'version': verObj['version'], 'author': verObj['author'], 'email': verObj['email'], 'date': verObj['date']   } ) ;
    pos -- ;
  }
  var cols = [
    {
      text: "<b>#</b>",
      flex: 1,
      dataIndex: 'position',
      width: 50,
    },
    {
      text: "<b>Version Id</b>",
      flex: 1,
      dataIndex: 'version',
      renderer: function(value, md, rec, ri, ci, store, view){
        var linkIdentifier = originalDocumentIdentifier ;
        var retVal = "<span data-qtip='This number indicates a global counter used by all documents. A higher number indicates that the version is more recent.'>" ;
        var linkCollection = currentCollection ;
        var urlLink = "http://"+location.host+kbMount+"/genboree_kbs?project_id="+projectIdentifier+"&coll="+escape(linkCollection)+"&docVersion="+escape(value)+"&doc="+escape(originalDocumentIdentifier) ;
        var docLink = "<a target=\"_blank\" onclick=\"return displayLinkOpts(this.href, true,'"+escape(linkCollection)+"','"+escape(linkIdentifier)+"','"+escape(value)+"'); \" href=\""+urlLink+"\">"+value+"</a>" ;
        retVal = retVal + docLink + "</span>" ;
        return retVal ;
      }
    },
    {
      text: "<b>Author</b>",
      flex: 1,
      dataIndex: 'author'
    },
    {
      text: "<b>Author Email</b>",
      flex: 1,
      dataIndex: 'email'
    },
    {
      text: "<b>Date</b>",
      flex: 1,
      dataIndex: 'date'
    }
  ]
  Ext.create('Ext.data.Store', {
    storeId: 'docsVersionsStore',
    fields: [ 'position', 'version', 'author', 'email', 'date'],
    data: versionsStoreData,
    proxy: {
      type: 'memory',
      reader: {
        type: 'json'
      }
    }
  }) ;
  initDocsVersionsGridToolbar() ;
  Ext.create('Ext.grid.Panel', {
    store: Ext.data.StoreManager.lookup('docsVersionsStore'),
    columns: cols,
    id: 'docsVersionsGrid',
    //width: panelWidth+5,
    title: title,
    tbar: Ext.getCmp('docsVersionsGridToolbar'), // defined in toolbars.js
    //autoScroll: true,
    height: panelHeight-35, // set height to total hight of layout panel - height of menubar
    renderTo: 'treeGridContainer-body',
    collapsible: false,
    selModel: {
      mode: 'MULTI'
    },
    viewConfig: {
      listeners: {
        refresh: function(dataview){
          Ext.each(dataview.panel.columns, function(column){
            if (column.dataIndex == 'position'|| column.dataIndex == 'version') {
              column.autoSize() ;  
            }
          })
        }
      },
      enableTextSelection: true
    },
    listeners: {
      // This select event handler basically handles which buttons will be activated when.
      //   restore button is only active if user role > subscriber and number of entries in store > 1 and only 1 row is selected
      //   diff button is only active if number of entries in store > 1 and only 2 rows are selected. Since diffing is a read-only operation,
      //    a higher role is not required.
      select: function(thisObj, record, index, eOpts){
        var numEntries = Ext.data.StoreManager.lookup('docsVersionsStore').data.items.length ;
        var selModel = Ext.getCmp('docsVersionsGrid').getSelectionModel() ;
        var numSelectedItems = selModel.selected.items.length ;
        if (numEntries > 1) {
          toggleDocVersionsGridBtns(numSelectedItems) ;
        }
      },
      deselect: function(thisObj, record, index, eOpts){
        var numEntries = Ext.data.StoreManager.lookup('docsVersionsStore').data.items.length ;
        var selModel = Ext.getCmp('docsVersionsGrid').getSelectionModel() ;
        var numSelectedItems = selModel.selected.items.length ;
        if (numEntries > 1) {
          toggleDocVersionsGridBtns(numSelectedItems)
        }
      }
    }
  });
  Ext.getCmp('browseDocsGrid').getSelectionModel().deselectAll() ;
}

function toggleDocVersionsGridBtns(numSelectedItems)
{
  var btns = Ext.getCmp('docsVersionsGrid').getDockedItems()[1].items.items ;
  var ii ;
  for(ii=0; ii<btns.length; ii++)
  {
    var btn = btns[ii] ;
    if (btn.itemId == 'restoreDoc') {
      if (numSelectedItems > 1) {
        btn.disable() ;  
      }
      else if(numSelectedItems == 1) {
        if (role && role != 'subscriber') {
          btn.enable() ;
        }
      }
    }
    else if (btn.itemId == 'udiffDocs') {
      if (numSelectedItems != 2) {
        btn.disable() ;  
      }
      else {
        btn.enable() ;  
      }
    }
  }
}

function getSelectedDocVersion()
{
  maskObj.show() ;
  Ext.Ajax.request(
  {
    url : 'genboree_kbs/versions/show',
    timeout : 900000,
    method: "GET",
    params:
    {
      identifier: originalDocumentIdentifier,
      "authenticity_token": csrf_token,
      project_id: projectId,
      collectionSet: currentCollection,
      version: Ext.getCmp('docsVersionsGrid').getSelectionModel().selected.items[0].raw.version,
      'type': 'doc'
    },
    callback : function(opts, success, response)
    {
      maskObj.hide() ;
      try
      {
        var apiRespObj  = JSON.parse(response.responseText) ;
        var statusObj   = apiRespObj['status'] ;
        var dataObj     = apiRespObj['data'] ;
        if( response.status >= 200 && response.status < 400 && dataObj ) 
        {
          var docToSave = dataObj['versionNum']['properties']['content']['value'] ;
          saveSelectedDocVersion(docToSave) ;
        }
        else
        {
          var displayMsg = "The following error was encountered while restoring doc versions:<br><br>" ;
          displayMsg += ( "<b>Error Code:</b> <i>" + (statusObj['statusCode'] ? statusObj['statusCode'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" );
          displayMsg += ( "<b>Error Message:</b> <i>" + (statusObj['msg'] ? statusObj['msg'] : "[ NOT INTELLIGIBLE ]") + "</i>" );
          displayMsg += "<br><br>Please contact a project admin to arrange investigation and resolution." ;
          Ext.Msg.alert("ERROR", displayMsg) ;
        }
      }
      catch(err)
      {
        Ext.Msg.alert('ERROR', "Bad data returned from server when getting versions of this document.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
      }
    }
  }) ;
}

function saveSelectedDocVersion(doc)
{
  var dataObj = { "data": doc, "status": {"msg": "OK"}} ;
  var data = JSON.stringify(dataObj) ;
  maskObj.show() ;
  Ext.Ajax.request(
  {
    url : 'genboree_kbs/doc/save',
    timeout : 900000,
    params:
    {
      data: data,
      identifier: originalDocumentIdentifier,
      "authenticity_token": csrf_token,
      project_id: projectId,
      collectionSet: currentCollection
    },
    callback : function(opts, success, response)
    {
      maskObj.hide() ;
      try
      {
        var apiRespObj  = JSON.parse(response.responseText) ;
        var statusObj   = apiRespObj['status'] ;
        if(response.status >= 200 && response.status < 400)
        {
          loadDocVersions() ;
        }
        else
        {
          var displayMsg = "The following error was encountered while saving the selected document as the current document:<br><br>" ;
          displayMsg += ( "<b>Error Code:</b> <i>" + (statusObj['statusCode'] ? statusObj['statusCode'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" );
          displayMsg += ( "<b>Error Message:</b> <i>" + (statusObj['msg'] ? statusObj['msg'] : "[ NOT INTELLIGIBLE ]") + "</i>" );
          displayMsg += "<br><br>Please contact a project admin to arrange investigation and resolution." ;
          Ext.Msg.alert("ERROR", displayMsg) ;
        }
      }
      catch(err)
      {
        Ext.Msg.alert('ERROR', "Bad data returned from server when saving the selected document as the current document.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
      }
    }
  }) ;
}


function performDiff()
{
  var selModel = Ext.getCmp('docsVersionsGrid').getSelectionModel() ;
  var selectedItems = selModel.selected.items ;
  // Get the versions of the selected records
  var ver = selectedItems[0].raw.version ;
  var diffVer = selectedItems[1].raw.version ;
  maskObj.show() ;
  Ext.Ajax.request(
  {
    url : 'genboree_kbs/versions/diff',
    timeout : 900000,
    method: 'GET',
    params:
    {
      identifier: originalDocumentIdentifier,
      "authenticity_token": csrf_token,
      project_id: projectId,
      collectionSet: currentCollection,
      version: ver,
      diffVersion: diffVer
    },
    callback : function(opts, success, response)
    {
      maskObj.hide() ;
      try
      {
        var apiRespObj  = JSON.parse(response.responseText) ;
        var statusObj   = apiRespObj['status'] ;
        var diffContent = apiRespObj['data'] ;
        if(response.status >= 200 && response.status < 400 )
        {
          renderDiffDialog(diffContent) ;
        }
        else
        {
          var displayMsg = "The following error was encountered while getting the diff content for the selected documents:<br><br>" ;
          displayMsg += ( "<b>Error Code:</b> <i>" + (statusObj['statusCode'] ? statusObj['statusCode'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" );
          displayMsg += ( "<b>Error Message:</b> <i>" + (statusObj['msg'] ? statusObj['msg'] : "[ NOT INTELLIGIBLE ]") + "</i>" );
          displayMsg += "<br><br>Please contact a project admin to arrange investigation and resolution." ;
          Ext.Msg.alert("ERROR", displayMsg) ;
        }
      }
      catch(err)
      {
        Ext.Msg.alert('ERROR', "Bad data returned from server when getting the diff content for the selected documents.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
      }
    }
  }) ;
}

function renderDiffDialog(diffContent)
{
  var noDiffPatt = /No differences found/ ;
  if (diffContent.match(noDiffPatt)) {
    Ext.Msg.show({
      title: originalDocumentIdentifier+' - Full Diff',
      msg: 'No differences were found between the selected versions of the document.',
      height: 130,
      buttons: Ext.Msg.OK,
      width: 400
    }) ;
  }
  else{
    Ext.create('Ext.window.Window', {
      title: originalDocumentIdentifier+' - Full Diff',
      height: 600,
      width: 800,
      layout: 'fit',
      html: diffContent,
      modal: true,
      autoScroll: true
    }).show();
  }
}