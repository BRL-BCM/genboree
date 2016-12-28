function genericAjaxCall(url, timeout, method, params, callback)
{
  Ext.Ajax.request(
  {
    url : url,
    timeout : timeout,
    params: params,
    method: method,
    callback : callback
  }) ;
}


function loadModel(coll, docIdentifier)
{
  maskObj.show() ;
  var url = "genboree_kbs/model/show" ;
  var timeout = 90000 ;
  var method = "GET" ;
  var params = {
    "authenticity_token": csrf_token,
    project_id: projectId,
    collectionSet: coll,
    version: ''
  } ;
  var callback = function(opts, success, response)
  {
    maskObj.hide() ;
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
          loadCollDetails(coll, docIdentifier, docModelObj) ;
          Ext.getCmp('collectionSetCombobox').setValue(coll) ;
          // Enable the collection level buttons
          var toolbarBtns = Ext.getCmp('containerPanelToolbar').items.items ;
          var ii ;
          for(ii=0; ii<toolbarBtns.length; ii++)
          {
            if (toolbarBtns[ii].itemId == 'downloadCollBtn' || toolbarBtns[ii].itemId == 'uploadDocsBtn' || toolbarBtns[ii].itemId == 'viewInfoDialogBtn') {
              if (toolbarBtns[ii].itemId == 'uploadDocsBtn') {
                if(role != 'subscriber'){
                  toolbarBtns[ii].enable() ;  
                }
              }
              else{
                toolbarBtns[ii].enable() ;  
              }
            }
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
  genericAjaxCall(url, timeout, method, params, callback) ;
  
}

// Loads up metadata info about the selection collection
// Mainly required for getting the labels for a selection collection.
function loadCollDetails(coll, docIdentifier, docModelObj)
{
  maskObj.show() ;
  var url = 'genboree_kbs/model/collshow' ;
  var timeout = 90000 ;
  var method = "GET" ;
  var params = {
    "authenticity_token": csrf_token,
    project_id: projectId,
    collectionSet: coll
  } 
  var callback = function(opts, success, response)
  {
    maskObj.hide() ;
    try
    {
      var apiRespObj  = JSON.parse(response.responseText) ;
      var collObj = apiRespObj['data'] ;
      var statusObj   = apiRespObj['status'] ;
      if(response.status >= 200 && response.status < 400 && collObj)
      {
        var slabel = 'Document' ;
        var plabel = 'Documents' ;
        if (collObj['name']['properties']['labels'] && collObj['name']['properties']['labels']['properties']) {
          slabel = collObj['name']['properties']['labels']['properties']['singular']['value'] ;
          plabel = collObj['name']['properties']['labels']['properties']['plural']['value'] ;
        }
        setWesternPanelTitles(slabel, plabel) ;
        /* todo: re-enable registering of coll and doc level tools to toolbars 
        registerToolNames(collObj) ;
        */
        satisfyURLParams( docIdentifier, docModelObj) ;
      }
      else
      {
        var displayMsg = "The following error was encountered while retrieving the coll info for the collection '<i>" + coll + "</i>' :<br><br>" ;
        displayMsg += ( "<b>Error Code:</b> <i>" + (statusObj['statusCode'] ? statusObj['statusCode'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" ) ;
        displayMsg += ( "<b>Error Message:</b> <i>" + (statusObj['msg'] ? statusObj['msg'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" );
        displayMsg += "<br><br>Please contact a project admin to resolve this issue." ;
        Ext.Msg.alert("ERROR", displayMsg) ;
      }
    }
    catch(err)
    {
      Ext.Msg.alert('ERROR', "Bad data returned from server when retrieving the collection info for collection '<i>" + coll + "</i>'.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
    }
  }
  genericAjaxCall(url, timeout, method, params, callback) ;
}


function registerToolNames(collObj) {
  var containerPanelToolbar = Ext.getCmp('containerPanelToolbar') ;
  var mainTreeGridToolbar = Ext.getCmp('mainTreeGridToolbar') ;
  var collToolsBtn ;
  var docToolsBtn ;
  // Get the collection level tool btn
  var items = containerPanelToolbar.items.items ;
  for(ii=0; ii<items.length; ii++)
  {
    var item = items[ii] ;
    if (item['itemId'] == 'collToolsBtn') {
      collToolsBtn = item ;
      break ;
    }
  }
  // Get the document level tool btn
  var items = mainTreeGridToolbar.items.items ;
  for(ii=0; ii<items.length; ii++)
  {
    var item = items[ii] ;
    if (item['itemId'] == 'docToolsBtn') {
      docToolsBtn = item ;
      break ;
    }
  }
  // Try populating the btn menu for collection level
  try{
    var collTools = collObj['name']['properties']['tools']['properties']['collection']['items'] ;
    var ii ;
    var menu = [] ;
    for(ii=0; ii<collTools.length; ii++)
    {
      var toolObj = collTools[ii]['tool']['properties'] ;
      menu.push( { text: toolObj['shortLabel']['value'], itemId: toolObj['toolIdStr']['value'], handler: function(){ launchTool('collection', toolObj['toolIdStr']['value']) }} ) ;
    }
    collToolsBtn.menu.removeAll() ;
    collToolsBtn.menu.add(menu) ;
    if (menu.length > 0) {
      collToolsBtn.enable() ;
    }
  }
  catch(err){
    collToolsBtn.disable() ;
  }
  // Try populating the btn menu for document level
  try{
    docLevelTools = [] ;
    var docTools = collObj['name']['properties']['tools']['properties']['doc']['items'] ;
    var ii ;
    var menu = [] ;
    for(ii=0; ii<docTools.length; ii++)
    {
      var toolObj = docTools[ii]['tool']['properties'] ;
      var menuObj = { text: toolObj['shortLabel']['value'], itemId: toolObj['toolIdStr']['value'], handler: function(){ launchTool('doc', toolObj['toolIdStr']['value']) }} ; 
      menu.push( menuObj ) ;
      docLevelTools.push(menuObj) ;
    }
    docToolsBtn.menu.removeAll() ;
    docToolsBtn.menu.add(menu) ;
  }
  catch(err){
    docLevelTools = [] ;
  }
}

function launchTool(scope, toolIdStr) {
  maskObj.show() ;
  var url = 'genboree_kbs/tools/run' ;
  var timeout = 90000 ;
  var method = 'GET' ;
  var params = {
    "authenticity_token": csrf_token,
    project_id: projectId,
    collectionSet: coll
  } ;
  var callback = function(opts, success, response)
  {
    maskObj.hide() ;
    try
    {
      var apiRespObj  = JSON.parse(response.responseText) ;
      var toolResp = apiRespObj['data'] ;
      var statusObj   = apiRespObj['status'] ;
      if(response.status >= 200 && response.status < 400 && toolResp)
      {
        
      }
      else
      {
        var displayMsg = "The following error was encountered when trying to run the tool '<i>" + toolIdStr + "</i>' :<br><br>" ;
        displayMsg += ( "<b>Error Code:</b> <i>" + (statusObj['statusCode'] ? statusObj['statusCode'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" ) ;
        displayMsg += ( "<b>Error Message:</b> <i>" + (statusObj['msg'] ? statusObj['msg'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" );
        displayMsg += "<br><br>Please contact a project admin to resolve this issue." ;
        Ext.Msg.alert("ERROR", displayMsg) ;
      }
    }
    catch(err)
    {
      Ext.Msg.alert('ERROR', "Bad data returned from server when trying to run the tool'<i>" + toolIdStr + "</i>'.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
    }
  }
  genericAjaxCall(url, timeout, method, params, callback) ;
}


// Sets the titles for variuos grid panels in the western panel based on the collection labels
// Called as a callback to loadCollDetails()
function setWesternPanelTitles(slabel, plabel)
{
  Ext.getCmp('browseDocsGrid').ownerCt.setTitle('Browse '+plabel) ;
  Ext.getCmp('manageDocsGrid').ownerCt.setTitle('Manage '+plabel) ;
  // Do not change the 'recordFuncName' value. These values are used for event handling.
  // 'displayStr' is used for dsplaying content.
  var manageDocsData =
  [
    { recordFuncName : 'Create new Document', genbKbIconCls : 'genbKb-createRecord', displayStr: 'Create '+slabel },
    { recordFuncName : 'Create new Document with Template', genbKbIconCls : 'genbKb-createRecord', displayStr: 'Create '+slabel+" (Template)" },
    { recordFuncName : 'Edit Document', genbKbIconCls : 'genbKb-editRecord', displayStr: 'Edit '+slabel },
    { recordFuncName : 'Delete Document', genbKbIconCls : 'genbKb-deleteRecord', displayStr: 'Delete '+slabel },
    { recordFuncName : 'History', genbKbIconCls : 'genbKb-recordHistory', displayStr: slabel+' History' }
  ] ;
  Ext.getCmp('manageDocsGrid').getStore().loadData(manageDocsData) ;
  var manageModelsData =
  [
    { modelFuncName : 'View Model (Tree)', genbKbIconCls : 'genbKb-dynamicTree', displayStr: 'View '+slabel+' Model' },
    { modelFuncName : 'History', genbKbIconCls : 'genbKb-recordHistory', displayStr: slabel+' Model History' },
    { modelFuncName : 'Create new Model', genbKbIconCls : 'genbKb-createRecord', displayStr: 'Create Model' }
  ] ;
  Ext.getCmp('manageModelsGrid').getStore().loadData(manageModelsData) ;
  singularLabel = slabel ;
  pluralLabel = plabel ;
}



// Helper function to aid with user supplied URL parameters
// Called as a callback to loadModel()
// to-do: I don't like how the URL params are being handled here. Need to design a better approach
function satisfyURLParams( docIdentifier, docModelObj )
{
  var treeModelLoaded = (Ext.getCmp('modelTreeGrid') ? true : false ) ;
  if (showModelTree) {
    if(role && role != 'subscriber')
    {
      toggleCreateNewDocumentSelector('enable') ;
    }
    toggleViewModel('enable') ;
    Ext.getCmp('browseDocsGrid').getSelectionModel().deselectAll() ;
    Ext.getCmp('manageModelsGrid').getView().select(0) ;
    showModelTree = false ;
  }
  else if (treeModelLoaded) {
    loadModelTree() ;
  }
  else if(showViewGrid){
    // If any of the form values is not provided, open up the form dialog
    if (matchQuery == "" || matchView == "" || matchMode == "" || matchValue == "") {
      initViewInfoDialog() ;
    }
    else
    {
      getViewDocs() ; // defined in views.js  
    }
    showViewGrid = false ;
    // Enable the add new document button if role is author/admin
    if(role && role != 'subscriber')
    {
      toggleCreateNewDocumentSelector('enable') ;
    }
    toggleViewModel('enable') ;
  }
  else if (showModelVersionsGrid) {
    if(role && role != 'subscriber')
    {
      toggleCreateNewDocumentSelector('enable') ;
    }
    toggleViewModel('enable') ;
    Ext.getCmp('browseDocsGrid').getSelectionModel().deselectAll() ;
    Ext.getCmp('manageModelsGrid').getView().select(1) ;
    showModelVersionsGrid = false ;
  }
  else{
    // Enable the add new document button if role is author/admin
    if(role && role != 'subscriber')
    {
      toggleCreateNewDocumentSelector('enable') ;
    }
    toggleViewModel('enable') ;
    if ((docIdentifier && docIdentifier != "") || createNewDoc || createNewDocWithTemplate) {
      initTreeGrid() ;
      // Must create a new JsonStore to hold any search results for this collection
      // - populates the searchStoreData global
      // - binds search box to new store
      // - enables search box (may be disabled if no collection/model yet, etc)
      createSearchStore(docModelObj) ;
      Ext.getCmp('searchComboBox').setValue('') ;
      if(docIdentifier && docIdentifier != "")
      {
        if (showDocsVersionsGrid) {
          enablePanelBtn('docHistory') ;
          currentCollection = Ext.getCmp('collectionSetCombobox').value ;
          originalDocumentIdentifier = docIdentifier ;
          Ext.getCmp('manageDocsGrid').getView().select(4) ;
        }
        else
        {
          Ext.getCmp('browseDocsGrid').getSelectionModel().select(0) ;
          loadDocument(docIdentifier, true) ;  
        }
      }
      else if (createNewDoc) {
        Ext.getCmp('manageDocsGrid').getView().select(0) ;
        createNewDoc = false ;
      }
      else if (createNewDocWithTemplate) {
        if (templateId == '') {
          Ext.getCmp('manageDocsGrid').getView().select(1) ;
        }
        else{
          if (role && role != 'subscriber') {
            loadTemplates() ;
          }
        }
        createNewDocWithTemplate = false ;
        
      }
    }
    else // Just show the collection stats
    {
      displayKbStats('coll') ;
      createSearchStore(docModelObj) ;
      Ext.getCmp('searchComboBox').setValue('') ;
      
    }
  }
}

function loadInitialDocList(appendData)
{
  //var url = 'genboree_kbs/collection/initialDocList' ;
  var url = 'genboree_kbs/doc/search' ;
  var timeout = 900000 ;
  var method = "GET" ;
  var params = {
    "authenticity_token"  : csrf_token,
    project_id            : projectId,
    //collectionSet         : Ext.getCmp('collectionSetCombobox').value
    coll                   : Ext.getCmp('collectionSetCombobox').value,
    limit: 25,
    searchStr: ""
  } ;
  var callback = function(opts, success, response)
  {
    try
    {
      var coll        = Ext.getCmp('collectionSetCombobox').value ;
      var apiRespObj  = JSON.parse(response.responseText) ;
      if( response.status >= 200 && response.status < 400 )
      {
        var docList = apiRespObj['data'] ;
        if (docList.length > 0) {
          var ii ;
          var searchBoxData = [] ;
          var rootProp = docModel['name']
          for(ii=0; ii<docList.length; ii++){
            searchBoxData.push({ "value": docList[ii][rootProp]['value']}) ;
          }
          Ext.getCmp('searchComboBox').getStore().loadData(searchBoxData, appendData) ;
        }
      }
    }
    catch(err)
    {
      Ext.Msg.alert('ERROR: '+err, "Bad data returned from server when loading the initial list of documents in the search box.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
    }
  }
  genericAjaxCall(url, timeout, method, params, callback) ;
}

function loadDocument(value, setSearchBoxValueAsSelf)
{
  maskObj.show() ;
  var url = 'genboree_kbs/doc/show' ;
  var timeout = 900000 ;
  var method = "GET" ;
  var params = {
    "authenticity_token"  : csrf_token,
    project_id            : projectId,
    itemId                : value,
    docVersion            : docVersion,
    collectionSet         : Ext.getCmp('collectionSetCombobox').value
  } ;
  var callback = function(opts, success, response)
  {
    maskObj.hide() ;
    try
    {
      var coll        = Ext.getCmp('collectionSetCombobox').value ;
      var apiRespObj  = JSON.parse(response.responseText) ;
      var docObj      = apiRespObj['data'] ;
      var statusObj   = apiRespObj['status'] ;
      if(response.status >= 200 && response.status < 400 && docObj)
      {
        loadDocumentInEditor(docObj, setSearchBoxValueAsSelf, value, false) // defined in docHelper.js
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
      Ext.Msg.alert('ERROR: '+err, "Bad data returned from server when retrieving the document named '<i>" + value + "</i>' from the collection '<i>" + coll + "'.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
    }
  }
  genericAjaxCall(url, timeout, method, params, callback) ;
}


function saveDocument(originalName, data)
{
  var payloadDocName = newdocObj[docModel['name']].value ;
  if (freshDocument) {
    originalName = payloadDocName ;
  }
  maskObj.show() ;
  var url = "genboree_kbs/doc/save"
  var timeout = 900000 ;
  var params = {
    data: data,
    identifier: originalName,
    "authenticity_token": csrf_token,
    project_id: projectId,
    collectionSet: currentCollection
  } ;
  var callback = function(opts, success, response)
  {
    maskObj.hide() ;
    try
    {
      var apiRespObj  = JSON.parse(response.responseText) ;
      var statusObj   = apiRespObj['status'] ;
      if(response.status >= 200 && response.status < 400)
      {
        toggleBtn('saveDoc', 'disable') ;
        var title = "Edit Mode: ON" ;
        docVersion = "" ; // This is now the current version of the document.
        title = addDocVerStr(title) ;
        Ext.getCmp('mainTreeGrid').setTitle(title) ;
        var identifier = docModel.name ;
        // When the identifier value for an existing document is changed, we get back {} in the data field in the response.
        //   -- In that case, just the identifier value that the user had set.
        var identifierValue = (apiRespObj['data'][identifier]  ? apiRespObj['data'][identifier]['value'] : newdocObj[identifier].value  ) ;
        //   if the identifier was changed for an existing (already in mongoDB) document, remove the old value and add the new one.
        if(originalDocumentIdentifier && originalDocumentIdentifier != newdocObj[identifier].value)
        {
          removeFromSearchBox(originalDocumentIdentifier, false) ;
          addToSearchBox(newdocObj[identifier].value, true) ;
        }
        // -- Add to search box if document was fresh
        if (freshDocument) {
          addToSearchBox(newdocObj[identifier].value, false) ;
        }
        // Load the document again since it could have had properties for which content was generated on the API side.
        loadDocument(identifierValue, true) ;
        Ext.Msg.alert('Status', 'Changes saved successfully.') ;
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
      Ext.Msg.alert('ERROR: '+err, "Bad data returned from server when saving the document.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
    }
  }
  var method = "POST" ;
  if (payloadDocName == '' && !getDomainInfo(docModel)[0].match(/^autoID/))
  {
    Ext.Msg.alert('ERROR', "Empty identifier property values are only allowed for autoID domain.") ;
  }
  else
  {
    genericAjaxCall(url, timeout, method, params, callback) ;
  }
}


function deleteDocument(identifier)
{
  maskObj.show() ;
  var url = 'genboree_kbs/doc/delete' ;
  var timeout = 900000 ;
  var params = {
    identifier: originalDocumentIdentifier,
    "authenticity_token": csrf_token,
    project_id: projectId,
    collectionSet: currentCollection 
  } ;
  var callback = function(opts, success, response)
  {
    maskObj.hide() ;
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
        toggleBtn('docVersionsBtn', 'disable') ;
        toggleDownloadType('JSON', 'disable') ;
        toggleBtn('docToolsBtn', 'disable') ;
        disablePanelBtn('docHistory') ;
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
      Ext.Msg.alert('ERROR: '+err, "Bad data returned from server when deleting the document.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
    }
  }
  var method = "POST" ;
  genericAjaxCall(url, timeout, method, params, callback) ;
}


function toggleCreateNewDocumentSelector(type)
{
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
      if (type == 'enable') {
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
      else{
        for(jj=0; jj<cssRules.length; jj++)
        {
          if(cssRules[jj].selectorText.match(/genbKb-gray-font-create/))
          {
            cssRules[jj].style.color = '#CCCCCC' ;
          }
        }
      }
    }
  }
}

function toggleViewModel(type)
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
      if (type == 'enable') {
        for(jj=0; jj<cssRules.length; jj++)
        {
          if(cssRules[jj].selectorText.match(/genbKb-gray-font-view-model/))
          {
            cssRules[jj].style.color = '#000000' ;
          }
        }
      }
      else{
        for(jj=0; jj<cssRules.length; jj++)
        {
          if(cssRules[jj].selectorText.match(/genbKb-gray-font-view-model/))
          {
            cssRules[jj].style.color = '#CCCCCC' ;
          }
        }
      }
    }
  }
}


/*
 * DEPRECATED METHODS 
 * */

function loadModelTable()
{
  var coll = Ext.getCmp('collectionSetCombobox').value ;
  maskObj.show() ;
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
      maskObj.hide() ;
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