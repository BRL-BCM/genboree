// Solicits identifier name of new doc from user and creates a template document for the currently loaded model
function createNewDocument()
{
  if(newdocObj || Ext.getCmp('questionnaireGrid'))
  {
    var msg = "Creating a new document will remove the document/model being currently viewed." ;
    if(documentEdited)
    {
      msg += "</br></br>We advise you to save the current document first before starting a new document." ;
    }
    msg += "</br></br>Are you sure you want to continue?" ;
    Ext.Msg.show({
      title: "Create New Document",
      msg: msg,
      buttons: Ext.Msg.YESNO,
      id: 'createNewDocumentMessBox',
      fn: function(btn){
        // Add handlers to the buttons above which will solicit the name of the identifier if the user does decide to start a new document
        if(btn == 'yes')
        {
          solicitNameOfNewDoc() ;
        }
        else
        {
          funcGridsBtnToggler('manageDocsGrid', 'Create new Document', 'deselect') ;
          if (Ext.getCmp('questionnaireGrid')) {
            funcGridsBtnToggler('manageDocsGrid', 'Create new Document with Questionnaire', 'select') ;
          }
          else{
            funcGridsBtnToggler('manageDocsGrid', 'Edit Document', 'select') ;
          }
        }
      }
    }) ;
  }
  else
  {
    solicitNameOfNewDoc() ;
  }
}

function createNewDocumentWithTemplate()
{
  if(newdocObj || Ext.getCmp('questionnaireGrid'))
  {
    var msg = "Creating a new document will remove the document/model being currently viewed." ;
    if(documentEdited)
    {
      msg += "</br></br>We advise you to save the current document first before starting a new document." ;
    }
    msg += "</br></br>Are you sure you want to continue?" ;
    Ext.Msg.show({
      title: "Create New Document (Templates)",
      msg: msg,
      buttons: Ext.Msg.YESNO,
      id: 'createNewDocumentTemplateMessBox',
      fn: function(btn){
        if(btn == 'yes')
        {
          loadTemplates() ;
        }
        else
        {
          funcGridsBtnToggler('manageDocsGrid', 'Create new Document with Template', 'deselect') ;
          if (Ext.getCmp('questionnaireGrid')) {
            funcGridsBtnToggler('manageDocsGrid', 'Create new Document with Questionnaire', 'select') ;
          }
          else{
            funcGridsBtnToggler('manageDocsGrid', 'Edit Document', 'select') ;
          }
        }
      }
    }) ;
  }
  else
  {
    loadTemplates() ;
  }
}

function loadTemplates()
{
  
  var url = 'genboree_kbs/templates/templates' ;
  var timeout = 900000 ;
  var method = "GET" ;
  var params = {
    "authenticity_token"  : csrf_token,
    project_id            : projectId,
    collectionSet         : Ext.getCmp('collectionSetCombobox').value
  } ;
  var callback = function(opts, success, response)
  {
    try
    {
      var apiRespObj  = JSON.parse(response.responseText) ;
      if( response.status >= 200 && response.status < 400 )
      {
        var templates = apiRespObj['data'] ;
        var templIds = [] ;
        var ii ;
        // If we have been give a template to load, check to see if it's in the list of templates we just retrieved
        //    - If loadTemplate is null, we'll display the form to the user for template selection.
        if (templateId != "") {
          var templateFound = false ;
          for( ii=0; ii<templates.length; ii++ ){
            if (templates[ii]['text']['value'] == templateId) {
              templateFound = true ;
            }
          }
          if (templateFound) {
            loadTemplate(templateId) ;
            templateId = '' ;
          }
          else{
            Ext.Msg.alert('Template Not Found', "There is no template called "+templateId+" in the selected collection.") ;
            resetPriorStateIfTemplateRejected() ;
            templateId = '' ;
          }
        }
        else{
          for( ii=0; ii<templates.length; ii++ ){
            templIds.push(templates[ii]['text']['value']) ;
          }
          displayTemplatesForm(templIds) ;
        }
      }
      else{
        Ext.Msg.alert('No Templates', "This collection does not have any templates.<br><br>Please contact a project admin to create one or more templates for this collection.") ;
        resetPriorStateIfTemplateRejected() ;
        templateId = '' ;
      }
      
    }
    catch(err)
    {
      Ext.Msg.alert('ERROR: '+err, "Bad data returned from server when loading the templates list.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
    }
  }
  genericAjaxCall(url, timeout, method, params, callback) ; 
  
}

function resetPriorStateIfTemplateRejected()
{
  funcGridsBtnToggler('manageDocsGrid', 'Create new Document with Template', 'deselect') ;
  // If there was no document loaded, go back to the previous state
  if(!newdocObj)
  {
    if (!Ext.getCmp('modelTreeGrid') && !Ext.getCmp('viewGrid') &&  !Ext.getCmp('docsVersionsGrid') && !Ext.getCmp('modelVersionsGrid') && !Ext.getCmp('questionnaireGrid')) {
      if (Ext.getCmp('mainTreeGrid')) {
        disablePanelBtn('editDelete') ;
        Ext.getCmp('mainTreeGrid').setTitle('Edit Mode: OFF') ;
        editModeValue = false ; // This is returned from the 'before edit' event of the row plugin.
        toggleNodeOperBtn(false) ;
      }
    }
  }
  else
  {
    funcGridsBtnToggler('manageDocsGrid', 'Edit Document', 'select') ;
  }
  // Reselect the existing setting
  if (Ext.getCmp('modelTreeGrid')) {
    Ext.getCmp('manageModelsGrid').getView().select(0) ;
  }
  else if (Ext.getCmp('modelVersionsGrid')) {
    Ext.getCmp('manageModelsGrid').getView().select(1) ;
  }
  else if (Ext.getCmp('docsVersionsGrid')) {
    showDocsVersionsGrid = true ;
    funcGridsBtnToggler('manageDocsGrid', 'History', 'select') ;
  }
  else if (Ext.getCmp('questionnaireGrid')) {
    funcGridsBtnToggler('manageDocsGrid', 'Create new Document with Questionnaire', 'select') ;
  }
  else{
    if (!editModeValue && !Ext.getCmp('viewGrid') && Ext.getCmp('mainTreeGrid')) {
      Ext.getCmp('browseDocsGrid').getView().select(0) ;
    }
  }
}

function displayTemplatesForm(templates)
{
  Ext.create('Ext.window.Window', {
    title: 'Select Template',
    height: 110,
    width: 355,
    id: 'templatesDisplayWindow',
    modal: true,
    layout: 'fit',
    listeners: {
      close: function(){
        resetPriorStateIfTemplateRejected() ;
      }
    },
    items: {  
      xtype: 'form',
      frame: true,
      items:
      [
        {
          xtype: 'combobox',
          editable: false,
          fieldLabel: '<b>Select template</b>',
          store: templates,
          value: templates[0],
          width: 330,
          id: 'templateId'
        }
      ],
      buttons:
      [
        {
          text: 'Load',
          handler: function() {
            var form = this.up('form').getForm();
            loadTemplate(form.monitor.items.items[0].rawValue) ;
          }
        }
      ]
    }
  }).show();
}

function loadTemplate(templateId)
{
  var url = 'genboree_kbs/templates/template' ;
  var timeout = 900000 ;
  var method = "GET" ;
  var params = {
    "authenticity_token"  : csrf_token,
    project_id            : projectId,
    collectionSet         : Ext.getCmp('collectionSetCombobox').value,
    templateId            : templateId
  } ;
  var callback = function(opts, success, response)
  {
    try
    {
      var apiRespObj  = JSON.parse(response.responseText) ;
      if( response.status >= 200 && response.status < 400 )
      {
        var template = apiRespObj['data'] ;
        if (Ext.getCmp('templatesDisplayWindow')) {
          Ext.getCmp('templatesDisplayWindow').close() ;
        }
        loadTemplateInEditor(template) ;
      }
      else{
        var displayMsg = "The following error was encountered while retrieving the template named '<i>" + templateId + "</i>' from the collection '<i>" + Ext.getCmp('collectionSetCombobox').value + "</i>' :<br><br>" ;
        displayMsg += ( "<b>Error Code:</b> <i>" + (statusObj['statusCode'] ? statusObj['statusCode'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" );
        displayMsg += ( "<b>Error Message:</b> <i>" + (statusObj['msg'] ? statusObj['msg'] : "[ NOT INTELLIGIBLE ]") + "</i>" );
        displayMsg += "<br><br>Please contact a project admin to arrange investigation and resolution." ;
        Ext.Msg.alert("ERROR", displayMsg) ;
      }
    }
    catch(err)
    {
      Ext.Msg.alert('ERROR: '+err, "Bad data returned from server when loading template document.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
    }
  }
  genericAjaxCall(url, timeout, method, params, callback) ; 
}

function loadTemplateInEditor(template)
{
  var actualDoc = {} ;
  var templateDoc = template['id']['properties']['template']['value'] ;
  actualDoc[docModel['name']] =  normalizeTemplateDoc(templateDoc) ;
  var currentSearchBoxData = getCurrentSearchBoxData() ;
  resetMainPanel() ;
  if(!Ext.getCmp('mainTreeGrid'))
  {
    initTreeGrid(currentSearchBoxData) ;
  }
  loadDocumentInEditor(actualDoc, false, "", true) ;
  funcGridsBtnToggler('manageDocsGrid', 'Edit Document', 'select') ;
  enableToolbarBtnsForNewDoc() ;
  // Expand the tree so that all props that need to be edited are displayed
  var rootNode = Ext.getCmp('mainTreeGrid').store.tree.root ;
  rootNode.expand(true) ;
}

// function to add the "value" field in case it is missing
function normalizeTemplateDoc(templateDocObj)
{
  if (templateDocObj['value'] == undefined) {
    if (templateDocObj['properties'] == undefined && templateDocObj['items'] == undefined) {
      templateDocObj = { "value": "" } ;
    }
    else{
      templateDocObj['value'] = "" ;
    }
  }
  if (templateDocObj['properties']) {
    var props = Object.keys(templateDocObj['properties']) ;
    var ii ;
    for(ii=0; ii<props.length; ii++){
      templateDocObj['properties'][props[ii]] = normalizeTemplateDoc(templateDocObj['properties'][props[ii]]) ;
    }
  }
  else if (templateDocObj['items']) {
    var items = templateDocObj['items'] ;
    if (items.length > 0) {
      var ii ;
      for(ii=0; ii<items.length; ii++){
        var item = items[ii] ;
        var rootProp = Object.keys(item)[0] ; // item lists are singly rooted
        var rootPropValueObj = item[rootProp]
        var normValObj = normalizeTemplateDoc(rootPropValueObj) ;
        var normProp = {} ;
        normProp[rootProp] = normValObj ;
        templateDocObj['items'][ii] = normProp ;
      }
    }
  }
  return templateDocObj
}


function loadDocumentInEditor(docObj, setSearchBoxValueAsSelf, value, isTemplateDoc, setEditMode)
{
  var docModelObj = docModel ;  // docModel is initialized/updated when a collection set is selected
  // Make sure the retrieved document has the identifier
  var docModelName = docModelObj.name ;
  if(docObj[docModelName])
  {
    var newdocToShow = createViewableDoc(docModelObj, docObj, isTemplateDoc) ; // defined in misc.js
    originalDocumentIdentifier = docObj[docModelName].value ;    // Important global in case user renames this doc
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
    newdocObj = docObj ;          // Set the global newdocObj to the selected one
    toggleBtn('saveDoc', 'disable') ;
    toggleBtn('addChildRow', 'disable') ;
    toggleBtn('removeRow', 'disable') ;
    toggleBtn('reorder', 'disable') ;
    toggleBtn('discardChanges', 'disable') ;
    toggleBtn('urlBtn', 'enable') ;
    toggleBtn('downloadBtn', 'enable') ;
    toggleBtn('docVersionsBtn', 'enable') ;
    toggleBtn('collStatsBtn', 'enable') ;
    toggleDownloadType('JSON', 'enable') ;
    toggleDownloadType('Tabbed - Full Property Names', 'enable') ;
    toggleDownloadType('Tabbed - Compact Property Names', 'enable') ;
    enablePanelBtn('docHistory') ;
    documentEdited = false ;
    freshDocument = false ;
    currentCollection = Ext.getCmp('collectionSetCombobox').value ;
    // Set Edit Mode in title
    var title = ( editModeValue ? "Edit Mode: ON" : "Edit Mode: OFF" ) ;
    title = addDocVerStr(title) ;
    Ext.getCmp('mainTreeGrid').setTitle(title) ;
    if(role && role != 'subscriber')
    {
      enablePanelBtn('editDelete') ;
    }
    if(setSearchBoxValueAsSelf)
    {
      Ext.getCmp('searchComboBox').setValue(value) ;
    }
    if (docLevelTools.length > 0)
    {
      toggleBtn('docToolsBtn', 'enable') ;
    }
    // displayPropPath comes from index.html.erb which is the property path provided in the URL to expand and display  
    if (displayPropPath != '') {
      seekAndDisplayProp(displayPropPath) ;
      // displayPropPath will be set back to empty by the 'afteritemexpand' event of the tree
    }
    if (setEditMode != undefined && setEditMode != null && setEditMode) {
      funcGridsBtnToggler('manageDocsGrid', 'Edit Document', 'select') ;
    }
  }
  else
  {
    Ext.Msg.alert('ERROR', 'Bad document retrieved from server. Retrieved document has different/missing identifier property than the model indicates.<br><br>Please contact a project admin to arrange investigation and resolution.') ;
  }
}

// Helper function for createNewDocument()
// If user gives the go-ahead for starting a new document, the currently loaded document (if any) will be nuked
function solicitNameOfNewDoc()
{
  Ext.Msg.show({
    title: "Create "+singularLabel,
    msg: 'Enter the identifier for a new '+ singularLabel +' in the <i>'+Ext.getCmp('collectionSetCombobox').value+'</i> collection:',
    buttons: Ext.Msg.OKCANCEL,
    icon: Ext.window.MessageBox.INFO,
    prompt: true,
    width: 300,
    fn: function(btn, text, opt){
      var selModel = Ext.getCmp('manageDocsGrid').getSelectionModel() ;
      if(btn == 'ok'){
        var modelObj = docModel ;
        var rootProp = modelObj ;
        var conditionSatisfied  = true ;
        var msg ;
        var domainEls = getDomainInfo(rootProp) ;
        var domain = domainEls[0] ;
        var domainOpts = domainEls[1] ;
        if(text == '' && !domain.match(/^autoID/))
        {
          msg = "Identifier cannot be blank" ;
          conditionSatisfied = false ;
        }
        else
        {
          if(domain == 'int')
          {
            if(!text.match(/^(?:\+|\-)?\d+$/))
            {
              msg = "Identifier must be an integer" ;
              conditionSatisfied = false ;
            }
          }
          else if(domain == 'posInt')
          {
            if(!text.match(/^\+?\d+$/))
            {
              msg = "Identifier must be a positive integer" ;
              conditionSatisfied = false ;
            }
          }
          else if(domain == 'negInt')
          {
            if(!text.match(/^-\d+$/))
            {
              msg = "Identifier must be a negative integer" ;
              conditionSatisfied = false ;
            }
          }
          else if(domain == 'float')
          {
            if(!text.match(/^(?:-|\+)?[0-9]*\.?[0-9]+(e(?:-|\+)?[0-9]+)?$/i))
            {
              msg = "Identifier must be a float" ;
              conditionSatisfied = false ;
            }
          }
          else if(domain == 'posFloat')
          {
            if(!text.match(/^(?:\+)?[0-9]*\.?[0-9]+(e(?:-|\+)?[0-9]+)?$/i))
            {
              msg = "Identifier must be a positive float" ;
              conditionSatisfied = false ;
            }
          }
          else if(domain == 'negFloat')
          {
            if(!text.match(/^(?:-)?[0-9]*\.?[0-9]+(e(?:-|\+)?[0-9]+)?$/i))
            {
              msg = "Identifier must be a negative float" ;
              conditionSatisfied = false ;
            }
          }
          else if(domain == 'regexp')
          {
            var regexpToMatch = new RegExp(domainOpts["pattern"]) ;
            if(!text.match(regexpToMatch))
            {
              msg = "Identifier must be of type: "+domainOpts['pattern'] ;
              conditionSatisfied = false ;
            }
          }
          else if(domain == 'enum')
          {
            var valueFound = false ;
            for(var ii=0; ii<domainOpts["values"].length; ii++)
            {
              if(text == domainOpts['value'][ii])
              {
                valueFound = true ;
                break ;
              }
            }
            if(!valueFound)
            {
              msg = "Identifier is not part of the enum list: "+domainOpts['values'].join() ;
              conditionSatisfied = false ;
            }
          }
          else
          {
            // Skip for now
          }
        }
        if(!conditionSatisfied)
        {
          Ext.Msg.show({
            title: "Status",
            msg: msg,
            buttons: Ext.Msg.OK,
            fn: function(btn){
              solicitNameOfNewDoc() ;
            }
          }) ;
        }
        else
        {
          // Check if a document with the provided identifier already exists
          //  -- If provided ident prop val is empty AND domain is autoID, no need to check against DB.
          if (text == '' && domain.match(/^autoID/)) {
            // No checks required
            initNewDoc(text, selModel) ;
          }
          else
          {
            Ext.Ajax.request(
            {
              url : 'genboree_kbs/doc/show',
              timeout : 90000,
              method: 'GET',
              params:
              {
                "authenticity_token": csrf_token,
                project_id: projectId,
                itemId: text,
                collectionSet: Ext.getCmp('collectionSetCombobox').value,
                docVersion: ''
              },
              success: function(response, eopts)
              {
                if(response.status >= 200 && response.status < 400)
                {
                  Ext.Msg.show({
                    title: "Status",
                    msg: "A document with this identifier already exists. Please enter a different identifier.",
                    buttons: Ext.Msg.OK,
                    fn: function(btn){
                      solicitNameOfNewDoc() ;
                    }
                  }) ;
                }
                else
                {
                  initNewDoc(text, selModel) ;
                }
              },
              failure: function(response, eopts)
              {
                initNewDoc(text, selModel) ;
              }
            }) ;
          }
        }
      }
      else
      {
        funcGridsBtnToggler('manageDocsGrid', 'Create new Document', 'deselect') ;
        // If there was no document loaded, go back to the previous state
        if(!newdocObj)
        {
          if (!Ext.getCmp('modelTreeGrid') && !Ext.getCmp('viewGrid') &&  !Ext.getCmp('docsVersionsGrid') && !Ext.getCmp('modelVersionsGrid') && !Ext.getCmp('questionnaireGrid')) {
            if (Ext.getCmp('mainTreeGrid')) {
              disablePanelBtn('editDelete') ;
              Ext.getCmp('mainTreeGrid').setTitle('Edit Mode: OFF') ;
              editModeValue = false ; // This is returned from the 'before edit' event of the row plugin.
              toggleNodeOperBtn(false) ;
            }
          }
        }
        else
        {
          funcGridsBtnToggler('manageDocsGrid', 'Edit Document', 'select') ;
        }
        // Reselect the model view if we came from there
        if (Ext.getCmp('modelTreeGrid')) {
          Ext.getCmp('manageModelsGrid').getView().select(0) ;
        }
        else if (Ext.getCmp('modelVersionsGrid')) {
          Ext.getCmp('manageModelsGrid').getView().select(1) ;
        }
        else if (Ext.getCmp('docsVersionsGrid')) {
          showDocsVersionsGrid = true ;
          funcGridsBtnToggler('manageDocsGrid', 'History', 'select') ;
        }
        else if (Ext.getCmp('questionnaireGrid')) {
          funcGridsBtnToggler('manageDocsGrid', 'Create new Document with Questionnaire', 'select') ;
        }
        else{
          if (!editModeValue && !Ext.getCmp('viewGrid') && Ext.getCmp('mainTreeGrid')) {
            Ext.getCmp('browseDocsGrid').getView().select(0) ;
          }
        }
      }
    }
  }) ;
}

function initNewDoc(text, selModel)
{
  var currentSearchBoxData = getCurrentSearchBoxData() ;
  resetMainPanel() ;
  if(!Ext.getCmp('mainTreeGrid'))
  {
    initTreeGrid(currentSearchBoxData) ;
  }
  editModeValue = true ; // This is returned from the 'before edit' event of the row plugin.
  toggleNodeOperBtn(true) ;
  var templateDoc = createTemplateDoc(text) ;
  var newstore = Ext.create('Ext.data.TreeStore', {
    model: 'Task',
    proxy: 'memory',
    root: {
      expanded: true,
      children: templateDoc
    }
  });
  clearAndReloadTree(newstore) ;
  funcGridsBtnToggler('manageDocsGrid', 'Create new Document', 'deselect') ;
  // If there was no document loaded, go back to the previous state
  if(!newdocObj)
  {
    disablePanelBtn('editDelete') ;
    Ext.getCmp('mainTreeGrid').setTitle('Edit Mode: OFF') ;
    editModeValue = false ; // This is returned from the 'before edit' event of the row plugin.
    toggleNodeOperBtn(false) ;
  }
  else
  {
    funcGridsBtnToggler('manageDocsGrid', 'Edit Document', 'select') ;
  }
  enableToolbarBtnsForNewDoc() ;
}

function enableToolbarBtnsForNewDoc()
{
  enablePanelBtn('editDelete') ;
  // Enable the save btn
  toggleBtn('saveDoc', 'enable') ;
  // disable the get url btn
  toggleBtn('urlBtn', 'disable') ;
  // disable the versions btn
  toggleBtn('docVersionsBtn', 'disable') ;
  toggleBtn('docToolsBtn', 'disable') ;
  toggleBtn('downloadBtn', 'enable') ;
  toggleBtn('collStatsBtn', 'enable') ;
  toggleDownloadType('JSON', 'enable') ;
  toggleDownloadType('Tabbed - Full Property Names', 'enable') ;
  disablePanelBtn('docHistory') ;
  toggleDownloadType('Tabbed - Compact Property Names', 'enable') ;
  freshDocument = true ; // global variable for differentiating between document loaded from db and a new document.
  documentEdited = true ;
  originalDocumentIdentifier = null ;
  currentCollection = Ext.getCmp('collectionSetCombobox').value ;
  Ext.getCmp('searchComboBox').enable() ;
  Ext.getCmp('mainTreeGrid').setTitle(getModifiedTitle(true)) ;
}


function getDomainInfoFromPropPath(path)
{
  var paths = path.split(".") ;
  var ii ;
  var modelProp = docModel ;
  for(ii=0; ii<paths.length; ii++)
  {
    var prop = paths[ii] ;
    if (ii != 0) {
      var childProps = modelProp['properties'] ;
      var jj ;
      var matchedChildProp = null ;
      for(jj=0; jj<childProps.length; jj++)
      {
        var childProp = childProps[jj] ;
        if (childProp.name == prop) {
          matchedChildProp = childProp ;
          break ;
        }
      }
      if (matchedChildProp) {
        modelProp = matchedChildProp ;
      }
      else{
        throw("Could not find one or more property paths defined in the view in the document model. Either the view is badly defined or the view is incompatible with the selected collection.") ;
      }
    }
  }
  var domainEls = getDomainInfo(modelProp) ;
  return domainEls ;
}

// Helper function for createNewDocument()
function createTemplateDoc(text)
{
  var modelObj = docModel ;
  var rootProp = modelObj ;
  var identifierProp = rootProp.name ;
  newdocObj = {} ;
  newdocObj[identifierProp] = { "value": castRootVal(text, modelObj) }  ;
  var children = [] ;
  var ii ;
  // Add the required sub-properties
  var children = addSubChildrenForNewDocument(rootProp, newdocObj[identifierProp]) ;
  var domainElsOfRoot = getDomainInfo(rootProp) ;
  var domainOfRoot = domainElsOfRoot[0] ;
  var domainOptsOfRoot = domainElsOfRoot[1] ;
  return {
      name: rootProp.name,
      value: text,
      expanded: true,
      category: true,
      description: rootProp.description,
      identifier: true,
      domain: domainOfRoot,
      domainOpts: domainOptsOfRoot,
      iconCls: 'task-folder',
      children: children,
      docAddress: newdocObj[identifierProp],
      required: true,
      modelAddress: rootProp
  } ;
}

// Cast the root val appropriately. Only works for string, int and float type values for now
// todo: add support for other types of domains.
function castRootVal(val, dm)
{
  var domain = getDomainInfo(dm)[0] ;
  var retVal  ;
  if (domain === '') {
    retVal = val  ;
  }
  else if(domain.match(/^autoID/)){
    retVal = "" ; // value will be generated on the server side
  }
  else if (domain.match(/int/i)) {
    retVal = parseInt(val) ;
  }
  else if (domain.match(/float/i)) {
    retVal = parseFloat(val) ;
  }
  else
  {
    retVal = val ;
  }
  return retVal ;
}

// Helper function to add all children nodes to the node to which children need to be added
// Used when generating a new document or when adding a child node containing *required* child nodes.
function addSubChildrenForNewDocument(prop, docObj)
{
  var children = [] ;
  var ii ;
  if(prop.properties)
  {
    for(ii=0; ii<prop.properties.length; ii++)
    {
      var subprop = prop.properties[ii] ;
      if(subprop.required)
      {
        children.push(addRequiredSubProp(subprop, docObj, 'properties')) ;
      }
    }
  }
  else if (prop.items) {
    var subprop = prop.items[0] ;
    if (subprop.required) {
      children.push(addRequiredSubProp(subprop, docObj, 'items')) ;
    }
  }
  return children ;
}

function addRequiredSubProp(subprop, docObj, type)
{
  var subpropName = subprop.name ;
  var domainEls = getDomainInfo(subprop) ;
  var domain = domainEls[0] ;
  var domainOpts = domainEls[1] ;
  var value = subprop['default'] ? subprop['default'] : returnDefaultDomainValue(domain, domainOpts) ;
  if (type == 'properties') {
    if(!docObj['properties'])
    {
      docObj['properties'] = {} ;

    }
    docObj['properties'][subpropName] = {"value": value}  ;
  }
  else
  {
    if(!docObj['items'])
    {
      docObj['items'] = [] ;

    }
    docObj['items'][0] = {} ;
    docObj['items'][0][subpropName] = { 'value': value } ;
  }
  var iconCls ;
  if(subprop.properties || subprop.items)
  {
    iconCls = 'task-folder' ;
    if (type == 'properties') {
      if(subprop.properties)
      {
        docObj['properties'][subpropName]['properties'] = {} ;
      }
      else
      {
        docObj['properties'][subpropName]['items'] = [] ;
      }
    }
    else{
      if(subprop.properties)
      {
        docObj['items'][0][subpropName]['properties'] = {} ;
      }
      else
      {
        docObj['items'][0][subpropName]['items'] = [] ;
      }
    }
  }
  else
  {
    iconCls = 'task' ;
  }
  var leaf = (iconCls == 'task' ? true : false) ;
  var subchildren = ( type == 'properties' ?  addSubChildrenForNewDocument(subprop, docObj['properties'][subpropName]) : addSubChildrenForNewDocument(subprop, docObj['items'][0][subpropName]) )
  return {
    name: subpropName,
    value: value,
    fixed: subprop.fixed,
    leaf: leaf,
    domain: domain,
    domainOpts: domainOpts,
    children: subchildren,
    category: subprop.category,
    description: subprop.description,
    iconCls: iconCls,
    required: true,
    modelAddress: subprop,
    docAddress: ( type == 'properties' ? docObj['properties'][subpropName] : docObj['items'][0][subpropName] )
  } ;
}


