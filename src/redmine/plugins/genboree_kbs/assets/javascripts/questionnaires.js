var templatesToPropPathsToDomain  ;
var fullPropPaths  ;
var templateToRelPaths  ;
var propPathsToDefMap ;
var fullPropPathToQPropPathMap ;

function createNewDocumentWithQuestionnaire()
{
  if(newdocObj)
  {
    var msg = "Creating a new document will remove the document/model being currently viewed." ;
    if(documentEdited)
    {
      msg += "</br></br>We advise you to save the current document first before starting a new document." ;
    }
    msg += "</br></br>Are you sure you want to continue?" ;
    Ext.Msg.show({
      title: "Create New Document (Questionnaire)",
      msg: msg,
      buttons: Ext.Msg.YESNO,
      id: 'createNewDocumentQuestionnaireMessBox',
      fn: function(btn){
        if(btn == 'yes')
        {
          loadQuestionnaires() ;
        }
        else
        {
          funcGridsBtnToggler('manageDocsGrid', 'Create new Document with Questionnaire', 'deselect') ;
          funcGridsBtnToggler('manageDocsGrid', 'Edit Document', 'select') ;
        }
      }
    }) ;
  }
  else
  {
    loadQuestionnaires() ;
  }
}

function loadQuestionnaires()
{
  var url = 'genboree_kbs/questionnaires/all' ;
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
      if( response.status >= 200 && response.status < 400 && apiRespObj['data'].length > 0 )
      {
        var questionnaires = apiRespObj['data'] ;
        var quesIds = [] ;
        var ii ;
        // If we have been give a questionnaire to load, check to see if it's in the list of questionnaires we just retrieved
        //    - If loadQuestionnaire is null, we'll display the form to the user for questionnaire selection.
        if (questionnaireId != "") {
          var questionnaire = null ;
          for( ii=0; ii<questionnaires.length; ii++ ){
            if (questionnaires[ii]['Questionnaire']['value'] == questionnaireId) {
              questionnaire = questionnaires[ii] ;
            }
          }
          if (questionnaire != null) {
            if (questionnaireValid(questionnaire)) {
              loadQuestionnaireInEditor(questionnaire) ;  
            }
            else{
              Ext.Msg.alert('Invalid Questionnaire', "The questionnaire "+questionnaireId+" cannot be used to generate a document because it either contains sections that deal with editin/adding items or does not use a template document with the identifier property as its root.") ;
              resetPriorStateIfQuestionnaireRejected() ;
              questionnaireId = '' ;
            }
          }
          else{
            Ext.Msg.alert('Questionnaire Not Found', "There is no questionnaire called "+questionnaireId+" in the selected collection.") ;
            resetPriorStateIfQuestionnaireRejected() ;
            questionnaireId = '' ;
          }
        }
        else{
          // Go through the list and select only the 'valid' questionnaires.
          for( ii=0; ii<questionnaires.length; ii++ ){
            if (questionnaireValid(questionnaires[ii])) {
              quesIds.push(questionnaires[ii]) ;  
            }
          }
          if (quesIds.length > 0) {
            displayQuestionnairesForm(quesIds) ;
          }
          else{
            Ext.Msg.alert('Invalid Questionnaires', "None of the questionnaires in this collection can be used to generate a document because they either contain sections that deal with editing/adding items or do not use a template document with the identifier property as its root.") ;
            resetPriorStateIfQuestionnaireRejected() ;
          }
        }
      }
      else{
        Ext.Msg.alert('No Questionnaires', "This collection does not have any questionnaires.<br><br>Please contact a project admin to create one or more questionnaires for this collection.") ;
        resetPriorStateIfQuestionnaireRejected() ;
        questionnaireId = '' ;
      }
      
    }
    catch(err)
    {
      Ext.Msg.alert('ERROR: '+err, "Bad data returned from server when loading the questionnaires list.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
    }
  }
  genericAjaxCall(url, timeout, method, params, callback) ; 
}

// Criteria for 'valid' questionnaires:
//   -- All sections have been defined using a template.
//   -- do not have any section that have the type other than "modifyProp". No item edit/add sections are supported currently. 
function questionnaireValid(qdoc)
{
  
  var ii ;
  var valid = true ;
  var sections = qdoc['Questionnaire']['properties']['Sections']['items']
  for(ii=0; ii<sections.length; ii++)
  {
    var section = sections[ii] ;
    if (section['SectionID']['properties']['Type']['value'] != 'modifyProp' || section['SectionID']['properties']['Template']['value'] == '') {
      valid = false ;
    }
  }
  return valid ;
}

function resetPriorStateIfQuestionnaireRejected()
{
  funcGridsBtnToggler('manageDocsGrid', 'Create new Document with Questionnaire', 'deselect') ;
  // If there was no document loaded, go back to the previous state
  if(!newdocObj)
  {
    if (!Ext.getCmp('modelTreeGrid') && !Ext.getCmp('viewGrid') &&  !Ext.getCmp('docsVersionsGrid') && !Ext.getCmp('modelVersionsGrid')) {
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
  else{
    if (!editModeValue && !Ext.getCmp('viewGrid') && Ext.getCmp('mainTreeGrid')) {
      Ext.getCmp('browseDocsGrid').getView().select(0) ;
    }
  }
}


function loadQuestionnaireInEditor(questionnaire)
{
  resetMainPanel() ;
  var store = createQuestionnaireStore(questionnaire, null) ;
  renderQuestionnaireGrid(store) ;
  if (questionnaireId != "") {
    questionnaireId = "" ;
    funcGridsBtnToggler('manageDocsGrid', 'Create new Document with Questionnaire', 'select') ;
  }
}

function renderQuestionnaireGrid(store)
{
  var tbar = initQuestionnaireToolbar() ;
  Ext.create('Ext.grid.Panel', {
    title: 'Questionnaire',
    store: Ext.data.StoreManager.lookup('questionnaireStore'),
    columns: [
      { text: 'Question', dataIndex: 'question', flex: 1 },
      { text: 'Answer', dataIndex: 'answer', flex: 1 }
    ],
    viewConfig: {
      listeners: {
        refresh: function(dataview){
          if (newdocObj) {
            Ext.each(dataview.panel.columns, function(column){
              column.autoSize() ;  
            })
          }
        }
      },
      enableTextSelection: true
    },
    tbar: tbar ,
    plugins: [getQuestionnaireRowEditorPlugin()],
    id: 'questionnaireGrid',
    features: [{ftype:'grouping'}],
    height: panelHeight-35, // set height to total hight of layout panel - height of menubar
    renderTo: 'treeGridContainer-body',
  });
  if (Ext.getCmp('questionnairesDisplayWindow')) {
    Ext.getCmp('questionnairesDisplayWindow').close() ;
  }
}


function getDefaultAnswers(questionnaire)
{
  var sections = questionnaire['Questionnaire']['properties']['Sections']['items'] ;
  var ii ;
  templatesToPropPathsToDomain = {} ;
  fullPropPaths = [] ;
  templateToRelPaths = {} ;
  fullPropPathToQPropPathMap = {} ;
  var templatesRetrieved = 0 ;
  for(ii=0; ii<sections.length; ii++)
  {
    var section = sections[ii] ;
    var questions = section['SectionID']['properties']['Questions']['items'] ;
    var jj ;
    var templateId = section['SectionID']['properties']['Template']['value'] ;
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
        var statusObj = apiRespObj['status'] ;
        if (response.status >= 200 && response.status < 400 && apiRespObj) {
          var templateDoc = apiRespObj['data'] ;
          templatesRetrieved += 1 ;
          templateToRelPaths[templateId] = {} ;
          var templateRoot = templateDoc['id']['properties']['root']['value'] ;
          templatesToPropPathsToDomain[templateId] = {} ;
          for(jj=0; jj<questions.length; jj++)
          {
            var question = questions[jj] ;
            var propPath = "" ;
            var qPropPath = question['QuestionID']['properties']['Question']['properties']['PropPath']['value'] ;
            var domain = question['QuestionID']['properties']['Question']['properties']['PropPath']['properties']['Domain']['value'] ;
            if (qPropPath == "" || qPropPath == templateRoot) {
              if (templateRoot == "" ) {
                propPath = docModel['name'] ;
                templateToRelPaths[templateId][propPath] = propPath ;
              }
              else{
                propPath = templateRoot ;
                var propPathArr = propPath.split(".") ;
                var relPath = propPathArr[propPathArr.length-1] ;
                templateToRelPaths[templateId][relPath] = propPath ;
              }
            }
            else{
              if (templateRoot == "") {
                propPath = docModel['name']+"."+qPropPath ;
                templateToRelPaths[templateId][propPath] = propPath ;
              }
              else{
                var rpArr = templateRoot.split(".") ;
                var rp = rpArr[rpArr.length-1] ;
                propPath = templateRoot+'.'+qPropPath ;
                var relTemplPath = rp+"."+qPropPath ;
                templateToRelPaths[templateId][relTemplPath] = propPath ;
              }
            }
            fullPropPathToQPropPathMap[propPath] = qPropPath ;
            fullPropPaths.push(propPath) ;
            templatesToPropPathsToDomain[templateId][propPath] = domain ;
            
          }
          if (templatesRetrieved == sections.length) {
            getDefaultsFromModel(questionnaire) ;
          }
        }
        else
        {
          var displayMsg = "The following error was encountered while retrieving the template definitions  :<br><br>" ;
          displayMsg += ( "<b>Error Code:</b> <i>" + (statusObj['statusCode'] ? statusObj['statusCode'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" );
          displayMsg += ( "<b>Error Message:</b> <i>" + (statusObj['msg'] ? statusObj['msg'] : "[ NOT INTELLIGIBLE ]") + "</i>" );
          displayMsg += "<br><br>Please contact a project admin to arrange investigation and resolution." ;
          Ext.Msg.alert("ERROR", displayMsg) ;
        }
      }
      catch(err)
      {
        Ext.Msg.alert('ERROR: '+err, "Bad data returned from server when retrieving the template definition.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
      }
    }
    genericAjaxCall(url, timeout, method, params, callback) ;   
  }
  
}

function getDefaultsFromModel(questionnaire)
{
 
  var url = 'genboree_kbs/model/propDefs' ;
  var timeout = 900000 ;
  var method = "GET" ;
  var params = {
    "authenticity_token"  : csrf_token,
    project_id            : projectId,
    collectionSet         : Ext.getCmp('collectionSetCombobox').value,
    propPaths             : fullPropPaths.join()
  } ;
  var callback = function(opts, success, response)
  {
    try
    {
      var apiRespObj  = JSON.parse(response.responseText) ;
      var statusObj = apiRespObj['status'] ;
      if (response.status >= 200 && response.status < 400 && apiRespObj) {
        var propDefs = apiRespObj['data'] ;
        propPathsToDefMap = {} ;
        var ii ;
        for(ii=0; ii<propDefs.length; ii++)
        {
          var propDefObj = propDefs[ii] ;
          var propPath = Object.keys(propDefObj)[0] ;
          var propDef = propDefObj[propPath] ;
          propPathsToDefMap[propPath] = propDef ;
        }
        getDefaultsFromTemplate(questionnaire) ;
      }
      else
      {
        var displayMsg = "The following error was encountered while retrieving the property definitions  :<br><br>" ;
        displayMsg += ( "<b>Error Code:</b> <i>" + (statusObj['statusCode'] ? statusObj['statusCode'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" );
        displayMsg += ( "<b>Error Message:</b> <i>" + (statusObj['msg'] ? statusObj['msg'] : "[ NOT INTELLIGIBLE ]") + "</i>" );
        displayMsg += "<br><br>Please contact a project admin to arrange investigation and resolution." ;
        Ext.Msg.alert("ERROR", displayMsg) ;
      }
    }
    catch(err)
    {
      Ext.Msg.alert('ERROR: '+err, "Bad data returned from server when retrieving the property definition list.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
    }
  }
  genericAjaxCall(url, timeout, method, params, callback) ;
  
}

function getDefaultsFromTemplate(questionnaire)
{
  var ii ;
  var templates = Object.keys(templatesToPropPathsToDomain) ;
  var totalTemplates = templates.length ;
  var propPathToDefaultValMap = {} ;
  var templatesIterated = 0 ;
  for(ii=0; ii<templates.length; ii++){
    var templateId = templates[ii] ;
    propPathToDefaultValMap[templateId] = {} ;
    var propPaths = Object.keys(templateToRelPaths[templateId])
    var url = 'genboree_kbs/templates/propVals' ;
    var timeout = 900000 ;
    var method = "GET" ;
    var params = {
      "authenticity_token"  : csrf_token,
      project_id            : projectId,
      collectionSet         : Ext.getCmp('collectionSetCombobox').value,
      propPaths             : propPaths.join(),
      templateId            : templateId
    } ;
    var callback = function(opts, success, response)
    {
      try
      {
        var apiRespObj  = JSON.parse(response.responseText) ;
        var statusObj = apiRespObj['status'] ;
        if (response.status >= 200 && response.status < 400 && apiRespObj) {
          templatesIterated += 1
          var templateVals = apiRespObj['data'] ;
          var jj ;
          for (jj=0; jj<propPaths.length; jj++) {
            var relPropPath = propPaths[jj] ; // contains the relative paths
            var fullPropPath = templateToRelPaths[templateId][relPropPath] ;
            var propDef = propPathsToDefMap[fullPropPath] ;
            // Replace domain with one from questionnaire
            var ans ;
            propDef['domain'] = templatesToPropPathsToDomain[templateId][fullPropPath] ;
            if (propDef['domain'] && propDef['domain'] == 'autoID') {
              ans = propDef['autoIDValue'] ;
            }
            else{
              if (templateVals[relPropPath] == null || templateVals[relPropPath] == undefined) {
                var domainInfo = getDomainInfo({ 'domain': propDef['domain'] }) ;
                ans = (  propDef['default'] ? propDef['default'] : returnDefaultDomainValue(domainInfo[0]. domainInfo[1]) ) ;
              }
              else{
                ans = templateVals[relPropPath] ;
              }
            }
            var qPropPath = fullPropPathToQPropPathMap[fullPropPath] ;
            propPathToDefaultValMap[templateId][qPropPath] = ans ;
          }
          if (templatesIterated == totalTemplates) {
            createQuestionnaireStore(questionnaire, propPathToDefaultValMap) ;
          }
        }
        else{
          var displayMsg = "The following error was encountered while retrieving the values from the template  :<br><br>" ;
          displayMsg += ( "<b>Error Code:</b> <i>" + (statusObj['statusCode'] ? statusObj['statusCode'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" );
          displayMsg += ( "<b>Error Message:</b> <i>" + (statusObj['msg'] ? statusObj['msg'] : "[ NOT INTELLIGIBLE ]") + "</i>" );
          displayMsg += "<br><br>Please contact a project admin to arrange investigation and resolution." ;
          Ext.Msg.alert("ERROR", displayMsg) ;
        }
      }
      catch(err)
      {
        Ext.Msg.alert('ERROR: '+err, "Bad data returned from server when retrieving the template values.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
      }
    }
    genericAjaxCall(url, timeout, method, params, callback) ;
  }
}


function createQuestionnaireStore(questionnaire, propPathToDefaultValMap)
{
  var data = [] ;
  var ii ;
  var sections = questionnaire['Questionnaire']['properties']['Sections']['items'] ;
  
  for(ii=0; ii<sections.length; ii++)
  {
    var section = sections[ii] ;
    var questions = section['SectionID']['properties']['Questions']['items'] ;
    var jj ;
    for(jj=0; jj<questions.length; jj++)
    {
      var record = {} ;
      record['Section'] = section['SectionID']['value'] ;  
      var question = questions[jj] ;
      record['questionID'] = question['QuestionID']['value'] ;
      record['question'] = question['QuestionID']['properties']['Question']['value'] ;
      var propPath = question['QuestionID']['properties']['Question']['properties']['PropPath']['value'] ;
      var answer = "" ;
      if (question['QuestionID']['properties']['Question']['properties']['Default']) {
        answer = question['QuestionID']['properties']['Question']['properties']['Default']['value'] ;
      }
      record['propPath'] = propPath ;
      record['domain'] = question['QuestionID']['properties']['Question']['properties']['PropPath']['properties']['Domain']['value'] ;
      record['answer'] = answer ;
      record['qid'] = questionnaire['Questionnaire']['value'] ;
      data.push(record) ;
    }
  }
  var store = Ext.create('Ext.data.Store', {
    storeId:'questionnaireStore',
    fields:['question', 'answer', 'Section'],
    groupField: 'Section',
    data: data,
    proxy: {
      type: 'memory',
      reader: {
        type: 'json'
      }
    }
  });
  return store ;
}


function saveQuestionnaire()
{
  var qstoreItems = Ext.getCmp('questionnaireGrid').store.data.items ;
  var ansDoc = {} ;
  var qid = qstoreItems[0].raw['qid'] ;
  ansDoc['Answer'] = { 'value': "", "properties": { 'Questionnaire': { "value": qid }, "Sections": { "items": [], "value": null } } } ;
  var ii ;
  var prevSection = null ;
  var sectionObj = null ;
  var ansItems = [] ;
  var sectionItems = [] ;
  for(ii=0; ii<qstoreItems.length; ii++)
  {
    var raw = qstoreItems[ii].raw ;
    var data = qstoreItems[ii].data ;
    var sectionId = raw.Section ;
    var answer = ( ( raw.domain == 'string' || raw.domain.match(/^regexp/) || raw.domain.match(/^autoID/) ) ? data.answer : ( data.answer == "" ? null : data.answer ) ) ;
    var ansItem = { "QuestionID": { "value": raw.questionID , "properties": { "PropPath": { "value": raw.propPath, "properties": { "PropValue": { "value": answer } } } }  } } ;
    if (prevSection) {
      if (prevSection != sectionId) {
        sectionObj['SectionID']['properties']['Answers']['items'] = ansItems ;
        sectionItems.push(sectionObj) ;
        sectionObj = { "SectionID": { "value": raw.Section, "properties": { "Answers": { "items": [], "value": null } } } } ;
        ansItems = [ansItem] ;
      }
      else{
        ansItems.push(ansItem) ;
      }
    }
    else{
      prevSection = sectionId ;
      sectionObj = { "SectionID": { "value": raw.Section, "properties": { "Answers": { "items": [], "value": null } } } } ;
      ansItems.push(ansItem) ;
    }
  }
  sectionObj['SectionID']['properties']['Answers']['items'] = ansItems ;
  sectionItems.push(sectionObj) ;
  ansDoc['Answer']['properties']['Sections']['items'] = sectionItems ;
  postAnsDoc(ansDoc) ;
}

function postAnsDoc(ansDoc)
{
  var url = 'genboree_kbs/questionnaires/answer' ;
  var timeout = 900000 ;
  var method = "POST" ;
  var params = {
    "authenticity_token"  : csrf_token,
    project_id            : projectId,
    collectionSet         : Ext.getCmp('collectionSetCombobox').value,
    answerDoc             : JSON.stringify(ansDoc),
    questionnaireId       : ansDoc['Answer']['properties']['Questionnaire']['value']
  } ;
  var callback = function(opts, success, response)
  {
    try
    {
      var apiRespObj  = JSON.parse(response.responseText) ;
      var statusObj = apiRespObj['status'] ;
      if (response.status >= 200 && response.status < 400 && apiRespObj) {
        // need to load up the newly created document
        var resultDoc = apiRespObj['data'] ;
        var docId = resultDoc[docModel['name']]['value'] ;
        var currentSearchBoxData = getCurrentSearchBoxData() ;
        resetMainPanel() ;
        if(!Ext.getCmp('mainTreeGrid'))
        {
          initTreeGrid(currentSearchBoxData) ;
        }
        loadDocument(docId, true, true) ;
        
      }
      else
      {
        var displayMsg = "The following error was encountered while trying to save the answer document  :<br><br>" ;
        displayMsg += ( "<b>Error Code:</b> <i>" + (statusObj['statusCode'] ? statusObj['statusCode'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" );
        displayMsg += ( "<b>Error Message:</b> <i>" + (statusObj['msg'] ? statusObj['msg'] : "[ NOT INTELLIGIBLE ]") + "</i>" );
        displayMsg += "<br><br>Please contact a project admin to arrange investigation and resolution." ;
        Ext.Msg.alert("ERROR", displayMsg) ;
      }
    }
    catch(err)
    {
      Ext.Msg.alert('ERROR: '+err, "Bad data returned from server when trying to save the answer document.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
    }
  }
  genericAjaxCall(url, timeout, method, params, callback) ;
}

function displayQuestionnairesForm(questionnaires)
{
  var qids = {} ;
  var ii ;
  for(ii=0; ii<questionnaires.length; ii++)
  {
    qids[questionnaires[ii]['Questionnaire']['value']] = questionnaires[ii] ;
  }
  Ext.create('Ext.window.Window', {
    title: 'Select Questionnaire',
    height: 110,
    width: 355,
    id: 'questionnairesDisplayWindow',
    modal: true,
    layout: 'fit',
    listeners: {
      close: function(){
        if (!Ext.getCmp('questionnaireGrid')) {
          resetPriorStateIfQuestionnaireRejected() ;
        }
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
          fieldLabel: '<b>Questionnaire</b>',
          store: Object.keys(qids),
          value: Object.keys(qids)[0],
          width: 330,
          id: 'questionnairesid'
        }
      ],
      buttons:
      [
        {
          text: 'Load',
          handler: function() {
            var form = this.up('form').getForm();
            loadQuestionnaireInEditor(qids[form.monitor.items.items[0].rawValue]) ;
          }
        }
      ]
    }
  }).show();
}

function getQuestionnaireRowEditorPlugin()
{
  var rowEditing = Ext.create('Ext.grid.plugin.RowEditing', {
    clicksToEdit: 2,
    id: 'questionnaireRowPlugin',
    pluginId: 'rePlugin',
    listeners: {
      edit: function(editor, context, eOpts)
      {
      },
      validatedit: function(editor, context, eOpts)
      {
      },
      canceledit: function(editor, context, eOpts)
      {
      },
      beforeedit: function(editor, context, eOpts)
      {
        var domainInfo = getDomainInfo({ 'domain': context.record.raw['domain']}) ;
        var valCM = context.grid.columns[1] ;
        var origWidth = valCM.getWidth() ;
        updateEditor(domainInfo[0], domainInfo[1], 'questionnaireGrid') ;
        var valueEditor = valCM.getEditor() ;
        valueEditor.setWidth(origWidth) ;
      }
    }
  }) ;
  return rowEditing ;
}