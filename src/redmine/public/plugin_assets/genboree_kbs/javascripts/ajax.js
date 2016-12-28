function loadModel(coll, docIdentifier)
{
  Ext.Ajax.request(
  {
    url : 'genboree_kbs/model/show',
    timeout : 90000,
    method: 'GET',
    params:
    {
      "authenticity_token": csrf_token,
      project_id: projectId,
      collectionSet: coll
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
          var modelError = validateModel(docModelObj) ;
          if(modelError != "")
          {
            Ext.Msg.alert('ERROR', "Bad model document for collection '<i>" + coll + "</i>'. Model validation error: '<i>" + modelError + "</i>'.<br><br>Please contact a project admin to arrange investigation and resolution.") ;
            Ext.getCmp('searchComboBox').disable() ;
          }
          else
          {
            docModel = docModelObj ; // Set the global model variable
            Ext.getCmp('collectionSetCombobox').setValue(coll) ;
            // Check if the model tree is already loaded. If it is, just replace the model tree with the new model
            // Otherwise, we are viewing the document/editor tree grid
            var treeModelLoaded = (Ext.getCmp('modelTreeGrid') ? true : false ) ;
            if (!treeModelLoaded && !showModelTree) {
              // Enable the add new document button if role is author/admin
              if(role && role != 'subscriber')
              {
                enableCreateNewDocumentSelector() ;
              }
              enableViewModel() ;
              // Must create a new JsonStore to hold any search results for this collection
              // - populates the searchStoreData global
              // - binds search box to new store
              // - enables search box (may be disabled if no collection/model yet, etc)
              createSearchStore(docModelObj) ;
              Ext.getCmp('searchComboBox').setValue('') ;
              if(docIdentifier && docIdentifier != "")
              {
                loadDocument(docIdentifier, true) ;
              }
            } 
            else{
              // Enable the add new document button if role is author/admin
              if (showModelTree) {
                if(role && role != 'subscriber')
                {
                  enableCreateNewDocumentSelector() ;
                }
                enableViewModel() ;
                Ext.getCmp('browseDocsGrid').getSelectionModel().deselectAll() ;
                Ext.getCmp('manageModelsGrid').getView().select(0) ;
                showModelTree = false ;
                
              }
              loadModelTree() ;
            }
          }
        }
        else
        {
          var displayMsg = "The following error was encountered while retrieving the model for the collection '<i>" + coll + "</i>' :<br><br>" ;
          displayMsg += ( "<b>Error Code:</b> <i>" + (statusObj['statusCode'] ? statusObj['statusCode'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" ) ;
          displayMsg += ( "<b>Error Message:</b> <i>" + (statusObj['msg'] ? statusObj['msg'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" );
          displayMsg += "<br><br>Please contact a project admin to resolve this issue." ;
          Ext.Msg.alert("ERROR", displayMsg) ;
        }
      }
      catch(err)
      {
        Ext.Msg.alert('ERROR', "Bad data returned from server when retrieving the model for collection '<i>" + coll + "</i>'.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
      }
    }
  }) ;
}

function loadModelTable()
{
  var coll = Ext.getCmp('collectionSetCombobox').value ;
  Ext.Ajax.request(
  {
    url : 'genboree_kbs/model/table',
    timeout : 90000,
    method: 'GET',
    params:
    {
      "authenticity_token": csrf_token,
      project_id: projectId,
      collectionSet: coll
    },
    callback : function(opts, success, response)
    {
      try
      {
        var apiRespObj  = JSON.parse(response.responseText) ;
        var modelTableData = apiRespObj['data'] ;
        var statusObj   = apiRespObj['status'] ;

        if(response.status >= 200 && response.status < 400 && modelTableData)
        {
          renderModelTable(modelTableData) ;
        }
        else
        {
          var displayMsg = "The following error was encountered while retrieving the model table for the collection '<i>" + coll + "</i>' :<br><br>" ;
          displayMsg += ( "<b>Error Code:</b> <i>" + (statusObj['statusCode'] ? statusObj['statusCode'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" ) ;
          displayMsg += ( "<b>Error Message:</b> <i>" + (statusObj['msg'] ? statusObj['msg'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" );
          displayMsg += "<br><br>Please contact a project admin to resolve this issue." ;
          Ext.Msg.alert("ERROR", displayMsg) ;
        }
      }
      catch(err)
      {
        Ext.Msg.alert('ERROR', "Bad data returned from server when retrieving the model table for collection '<i>" + coll + "</i>'.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
      }
    }
  }) ;
}

function loadDocument(value, setSearchBoxValueAsSelf)
{
  Ext.Ajax.request(
  {
    url     : 'genboree_kbs/doc/show',
    timeout : 90000,
    method  : 'GET',
    params  :
    {
      "authenticity_token"  : csrf_token,
      project_id            : projectId,
      itemId                : value,
      collectionSet         : Ext.getCmp('collectionSetCombobox').value
    },
    callback : function(opts, success, response)
    {
      try
      {
        var coll        = Ext.getCmp('collectionSetCombobox').value ;
        var apiRespObj  = JSON.parse(response.responseText) ;
        var docObj      = apiRespObj['data'] ;
        var statusObj   = apiRespObj['status'] ;

        if(response.status >= 200 && response.status < 400 && docObj)
        {
          var docModelObj = docModel ;  // docModel is initialized/updated when a collection set is selected
          newdocObj = docObj ;          // Set the global newdocObj to the selected one
          // Make sure the retrieved document has the identifier
          var docModelName = docModelObj.name ;
          if(newdocObj[docModelName])
          {
            var newdocToShow = createViewableDoc(docModelObj, newdocObj) ; // defined in misc.js
            originalDocumentIdentifier = newdocObj[docModelName].value ;    // Important global in case user renames this doc
            var newstore = Ext.create('Ext.data.TreeStore',
            {
              model : 'Task',
              proxy : 'memory',
              root  :
              {
                expanded: true,
                children: newdocToShow
              }
            }) ;
            clearAndReloadTree(newstore) ;
            registerQtips() ;
            // Disable some of the doc specific btns
            toggleBtn('saveDoc', 'disable') ;
            toggleBtn('addChildRow', 'disable') ;
            toggleBtn('removeRow', 'disable') ;
            toggleBtn('reorder', 'disable') ;
            toggleBtn('discardChanges', 'disable') ;
            // Enable the doc url btn
            toggleBtn('urlBtn', 'enable') ;
            toggleBtn('downloadBtn', 'enable') ;
            toggleDownloadType('JSON', 'enable') ;
            toggleDownloadType('Tabbed - Full Property Names', 'enable') ;
            toggleDownloadType('Tabbed - Compact Property Names', 'enable') ;
            documentEdited = false ;
            freshDocument = false ;
            if(role && role != 'subscriber')
            {
              enableEditDelete() ;
            }
            if(setSearchBoxValueAsSelf)
            {
              Ext.getCmp('searchComboBox').setValue(value) ;
            }
            currentCollection = Ext.getCmp('collectionSetCombobox').value ;
            if (editModeValue)
            {
              Ext.getCmp('mainTreeGrid').setTitle("Edit Mode: ON") ;
            }
            else
            {
              Ext.getCmp('mainTreeGrid').setTitle("Edit Mode: OFF") ;
            }
          }
          else
          {
            Ext.Msg.alert('ERROR', 'Bad document retrieved from server. Retrieved document has different/missing identifier property than the model indicates.<br><br>Please contact a project admin to arrange investigation and resolution.') ;
          }
        }
        else
        {
          var displayMsg = "The following error was encountered while retrieving the document named '<i>" + value + "</i>' from the collection '<i>" + coll + "</i>' :<br><br>" ;
          displayMsg += ( "<b>Error Code:</b> <i>" + (statusObj['statusCode'] ? statusObj['statusCode'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" );
          displayMsg += ( "<b>Error Message:</b> <i>" + (statusObj['msg'] ? statusObj['msg'] : "[ NOT INTELLIGIBLE ]") + "</i>" );
          displayMsg += "<br><br>Please contact a project admin to arrange investigation and resolution." ;
          Ext.Msg.alert("ERROR", displayMsg) ;
        }
      }
      catch(err)
      {
        Ext.Msg.alert('ERROR', "Bad data returned from server when retrieving the document named '<i>" + value + "</i>' from the collection '<i>" + coll + "'.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
      }
    }
  }) ;
}

function deleteDocument(identifier)
{
  Ext.Ajax.request(
  {
    url : 'genboree_kbs/doc/delete',
    timeout : 90000,
    params:
    {
      identifier: originalDocumentIdentifier,
      "authenticity_token": csrf_token,
      project_id: projectId,
      collectionSet: currentCollection 
    },
    callback : function(opts, success, response)
    {
      try
      {
        var apiRespObj  = JSON.parse(response.responseText) ;
        var statusObj   = apiRespObj['status'] ;
        if( response.status >= 200 && response.status < 400 )
        {
          Ext.Msg.alert('Status', 'Document deleted successfully.') ;
          removeFromSearchBox(identifier, true) ;
          // disable the get url btn
          toggleBtn('urlBtn', 'disable') ;
          toggleBtn('discardChanges', 'disable') ;
          Ext.getCmp('mainTreeGrid').setTitle("Edit Mode: ON") ;
          toggleBtn('downloadBtn', 'disable') ;
          toggleDownloadType('JSON', 'disable') ;
          toggleDownloadType('Tabbed - Full Property Names', 'disable') ;
          toggleDownloadType('Tabbed - Compact Property Names', 'disable') ;
        }
        else
        {
          var displayMsg = "The following error was encountered while deleting the document:<br><br>" ;
          displayMsg += ( "<b>Error Code:</b> <i>" + (statusObj['statusCode'] ? statusObj['statusCode'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" );
          displayMsg += ( "<b>Error Message:</b> <i>" + (statusObj['msg'] ? statusObj['msg'] : "[ NOT INTELLIGIBLE ]") + "</i>" );
          displayMsg += "<br><br>Please contact a project admin to arrange investigation and resolution." ;
          Ext.Msg.alert("ERROR", displayMsg) ;
        }
      }
      catch(err)
      {
        Ext.Msg.alert('ERROR', "Bad data returned from server when deleting the document.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
      }
    }
  }) ;
}

function saveDocument(originalName, data)
{
  Ext.Ajax.request(
  {
    url : 'genboree_kbs/doc/save',
    timeout : 90000,
    //method  : 'GET',
    params:
    {
      data: data,
      identifier: originalName,
      "authenticity_token": csrf_token,
      project_id: projectId,
      collectionSet: currentCollection
    },
    callback : function(opts, success, response)
    {
      try
      {
        var apiRespObj  = JSON.parse(response.responseText) ;
        var statusObj   = apiRespObj['status'] ;
        if(response.status >= 200 && response.status < 400)
        {
          Ext.Msg.alert('Status', 'Changes saved successfully.') ;
          toggleBtn('saveDoc', 'disable') ;
          Ext.getCmp('mainTreeGrid').setTitle("Edit Mode: ON") ;
          documentEdited = false ;
          // If the identifier was changed for an existing document, update the search box with the new name
          var identifier = docModel.name ;
          if(originalDocumentIdentifier && originalDocumentIdentifier != newdocObj[identifier].value)
          {
            removeFromSearchBox(originalDocumentIdentifier, false) ;
            addToSearchBox(newdocObj[identifier].value, true) ;
          }
          freshDocument = false ;
          originalDocumentIdentifier = newdocObj[docModel.name].value ;
          var ii ;
          // Commit 'dirty' records to tree to remove the small triangles once the updates have been saved.
          var dirtyRecKeys = Object.keys(dirtyRecords) ;
          for(ii=0; ii<dirtyRecKeys.length; ii++)
          {
            dirtyRecords[dirtyRecKeys[ii]].commit() ;
          }
          dirtyRecords = {} ;
          // Enable the doc url btn
          toggleBtn('urlBtn', 'enable') ;
          toggleBtn('discardChanges', 'disable') ;
          toggleBtn('downloadBtn', 'enable') ;
          toggleDownloadType('JSON', 'enable') ;
          toggleDownloadType('Tabbed - Full Property Names', 'enable') ;
          toggleDownloadType('Tabbed - Compact Property Names', 'enable') ;
        }
        else
        {
          var displayMsg = "The following error was encountered while saving the document:<br><br>" ;
          displayMsg += ( "<b>Error Code:</b> <i>" + (statusObj['statusCode'] ? statusObj['statusCode'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" );
          displayMsg += ( "<b>Error Message:</b> <i>" + (statusObj['msg'] ? statusObj['msg'] : "[ NOT INTELLIGIBLE ]") + "</i>" );
          displayMsg += "<br><br>Please contact a project admin to arrange investigation and resolution." ;
          Ext.Msg.alert("ERROR", displayMsg) ;
        }
      }
      catch(err)
      {
        Ext.Msg.alert('ERROR', "Bad data returned from server when saving the document.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
      }
    }
  }) ;
}

function enableCreateNewDocumentSelector()
{
  toggleBtn('newDocument', 'enable') ;
  // Change the color of the text from gray to black to make it look 'enabled' (for 'Create new Document')
  var ss = document.styleSheets ;
  var ii, jj ;
  for(ii=0; ii<ss.length; ii++)
  {
    if(ss[ii].href && ss[ii].href.match(/funcGrids/))
    {
      var cssRules ;
      if(ss[ii].cssRules)
      {
        cssRules = ss[ii].cssRules ;
      }
      else if(ss[ii].rules) // IE
      {
        cssRules = ss[ii].rules ;
      }
      else
      {
        // Do nothing
      }
      for(jj=0; jj<cssRules.length; jj++)
      {
        if(cssRules[jj].selectorText.match(/genbKb-gray-font-create/))
        {
          cssRules[jj].style.color = '#000000' ;
        }
        else if(cssRules[jj].selectorText.match(/genbKb-gray-font-edit-delete/))
        {
          if(!newdocObj)
          {
            cssRules[jj].style.color = '#CCCCCC' ;
          }
        }
      }
    }
  }
}

function enableViewModel()
{
  var ss = document.styleSheets ;
  var ii, jj ;
  for(ii=0; ii<ss.length; ii++)
  {
    if(ss[ii].href && ss[ii].href.match(/funcGrids/))
    {
      var cssRules ;
      if(ss[ii].cssRules)
      {
        cssRules = ss[ii].cssRules ;
      }
      else if(ss[ii].rules) // IE
      {
        cssRules = ss[ii].rules ;
      }
      else
      {
        // Do nothing
      }
      for(jj=0; jj<cssRules.length; jj++)
      {
        if(cssRules[jj].selectorText.match(/genbKb-gray-font-view-model/))
        {
          cssRules[jj].style.color = '#000000' ;
        }
      }
    }
  }
}
