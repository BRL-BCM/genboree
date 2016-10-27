function loadModelVersions()
{
  maskObj.show() ;
  Ext.Ajax.request(
  {
    url : 'genboree_kbs/versions/all',
    timeout : 90000,
    method: 'GET',
    params:
    {
      "authenticity_token": csrf_token,
      project_id: projectId,
      collectionSet: Ext.getCmp('collectionSetCombobox').value,
      'type': 'model'
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
          renderModelVersionsGrid(dataObj) ;  
        }
        else
        {
          var displayMsg = "The following error was encountered while getting model versions:<br><br>" ;
          displayMsg += ( "<b>Error Code:</b> <i>" + (statusObj['statusCode'] ? statusObj['statusCode'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" );
          displayMsg += ( "<b>Error Message:</b> <i>" + (statusObj['msg'] ? statusObj['msg'] : "[ NOT INTELLIGIBLE ]") + "</i>" );
          displayMsg += "<br><br>Please contact a project admin to arrange investigation and resolution." ;
          Ext.Msg.alert("ERROR", displayMsg) ;
        }
      }
      catch(err)
      {
        Ext.Msg.alert('ERROR', "Bad data returned from server when getting versions for this model.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
      }
    }
  }) ;
}



function displayLinkOptsForModel(ver)
{
  modelVersion = ver ;
  modelLinkClick = true ;
  Ext.getCmp('manageModelsGrid').getView().select(0) ;
  return false ;
}

function renderModelVersionsGrid(dataObj)
{
  resetMainPanel() ;
  Ext.getCmp('manageDocsGrid').getSelectionModel().deselectAll() ;
  Ext.getCmp('browseDocsGrid').getSelectionModel().deselectAll() ;
  Ext.getCmp('manageModelsGrid').getView().deselect(0) ;
  disablePanelBtn('docHistory') ;
  disablePanelBtn('editDelete') ;
  var ii ;
  var versionsStoreData = [] ;
  var pos = dataObj.length ;
  for(ii=(dataObj.length-1); ii>=0; ii--)
  {
    var verObj = dataObj[ii] ;
    versionsStoreData.push( { 'position': pos,  'version': verObj['version'], 'author': verObj['author'], 'email': verObj['email'], 'date': verObj['date']   } ) ;
    pos -- ;
  }
  var cols = [
    {
      text: "<b>#</b>",
      flex: 1,
      dataIndex: 'position'
    },
    {
      text: "<b>Version Id</b>",
      flex: 1,
      dataIndex: 'version',
      renderer: function(value, md, rec, ri, ci, store, view){
        var retVal = "<span data-qtip='This number indicates a global counter used by all documents. A higher number indicates that the version is more recent.'>" ;
        var coll = Ext.getCmp('collectionSetCombobox').value ; 
        var urlLink = "http://"+location.host+kbMount+"/genboree_kbs?project_id="+projectIdentifier+"&coll="+escape(coll)+"&modelVersion="+escape(value)+"&showModelTree=true" ;
        var docLink = "<a target=\"_blank\" onclick=\"return displayLinkOptsForModel('"+escape(value)+"'); \" href=\""+urlLink+"\">"+value+"</a>" ;
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
    storeId: 'modelVersionsStore',
    fields: [ 'position', 'version', 'author', 'email', 'date'],
    data: versionsStoreData,
    proxy: {
      type: 'memory',
      reader: {
        type: 'json'
      }
    }
  }) ;
  initModelVersionsGridToolbar() ;
  Ext.create('Ext.grid.Panel', {
    store: Ext.data.StoreManager.lookup('modelVersionsStore'),
    columns: cols,
    id: 'modelVersionsGrid',
    //width: panelWidth,
    title: 'Model History',
    tbar: Ext.getCmp('modelVersionsGridToolbar'), // defined in toolbars.js
    //autoScroll: true,
    height: panelHeight-35, // set height to total hight of layout panel - height of menubar
    renderTo: 'treeGridContainer-body',
    collapsible: false,
    viewConfig: {
      listeners: {
        refresh: function(dataview){
          Ext.each(dataview.panel.columns, function(column){
            if (column.dataIndex == 'position' || column.dataIndex == 'version') {
              column.autoSize() ;  
            }  
          })
        }
      },
      enableTextSelection: true
    },
    listeners: {
      select: function(thisObj, record, index, eOpts){
        var numEntries = Ext.data.StoreManager.lookup('modelVersionsStore').data.items.length ;
        if (role == 'administrator' && numEntries > 1) {
          var btns = Ext.getCmp('modelVersionsGrid').getDockedItems()[1].items.items ;
          var ii ;
          for(ii=0; ii<btns.length; ii++)
          {
            if (btns[ii].itemId == 'restoreModel') {
              btns[ii].enable() ;
            }
          }
          modelVersionsGridSelectedRecord = record ;
        }
      }
    }
  });
  Ext.getCmp('browseDocsGrid').getSelectionModel().deselectAll() ;
}


function getSelectedModelVersion()
{
  maskObj.show() ;
  Ext.Ajax.request(
  {
    url : 'genboree_kbs/versions/show',
    timeout : 90000,
    method: "GET",
    params:
    {
      "authenticity_token": csrf_token,
      project_id: projectId,
      collectionSet: Ext.getCmp('collectionSetCombobox').value,
      version: modelVersionsGridSelectedRecord.data.version,
      'type': 'model'
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
          var docToSave = dataObj['versionNum']['properties']['content']['value']['name']['properties']['model']['value'] ;
          saveSelectedModelVersion(docToSave) ;
        }
        else
        {
          var displayMsg = "The following error was encountered while restoring model versions:<br><br>" ;
          displayMsg += ( "<b>Error Code:</b> <i>" + (statusObj['statusCode'] ? statusObj['statusCode'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" );
          displayMsg += ( "<b>Error Message:</b> <i>" + (statusObj['msg'] ? statusObj['msg'] : "[ NOT INTELLIGIBLE ]") + "</i>" );
          displayMsg += "<br><br>Please contact a project admin to arrange investigation and resolution." ;
          Ext.Msg.alert("ERROR", displayMsg) ;
        }
      }
      catch(err)
      {
        Ext.Msg.alert('ERROR', "Bad data returned from server when getting versions for this model.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
      }
    }
  }) ;
}

function saveSelectedModelVersion(doc)
{
  var dataObj = { "data": doc, "status": {"msg": "OK"}} ;
  var data = JSON.stringify(dataObj) ;
  maskObj.show() ;
  Ext.Ajax.request(
  {
    url : 'genboree_kbs/model/save',
    timeout : 90000,
    params:
    {
      data: data,
      "authenticity_token": csrf_token,
      project_id: projectId,
      collectionSet: Ext.getCmp('collectionSetCombobox').value
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
          loadModelVersions() ;
          docModel = doc ;
        }
        else
        {
          var displayMsg = "The following error was encountered while saving the selected model as the current model:<br><br>" ;
          displayMsg += ( "<b>Error Code:</b> <i>" + (statusObj['statusCode'] ? statusObj['statusCode'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" );
          displayMsg += ( "<b>Error Message:</b> <i>" + (statusObj['msg'] ? statusObj['msg'] : "[ NOT INTELLIGIBLE ]") + "</i>" );
          displayMsg += "<br><br>Please contact a project admin to arrange investigation and resolution." ;
          Ext.Msg.alert("ERROR", displayMsg) ;
        }
      }
      catch(err)
      {
        Ext.Msg.alert('ERROR', "Bad data returned from server when saving the selected model document as the current model.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
      }
    }
  }) ;
}