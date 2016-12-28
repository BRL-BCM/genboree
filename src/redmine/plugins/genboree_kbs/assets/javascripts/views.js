// Wrapper function for getting the list of available queries followed by getting the list of available views and
//    ultimately displaying the form for solicting information from user to render the selected view
function initViewInfoDialog()
{
  getQueries() ;
}


// Displays the form for solicting information to generate view
// Upon success, generates the 'view' based on the result
function displaySolicitViewInfoDialog(queries, views)
{
  Ext.regModel('viewFormComboModel', {
    fields: [
        {type: 'string', name: 'name'},
        {type: 'string', name: 'tip'}
    ]
  });
  var qstore ;
  var qvalue ;
  var ii ;
  // Set up special tool-tips for individual query options
  if (indexedProps.length == 0) {
    qstore = Ext.create('Ext.data.Store', {
      model: 'viewFormComboModel',
      data: [ { 'name': 'Document Id', 'tip': 'The model for this collection has no indexed properties. You can only search against the document identifier property values.' } ]
    }) ;
    qvalue = 'Document Id' ;
  }
  else
  {
    var qdata = [] ;
    for(ii=0; ii<queries.length; ii++)
    {
      var query = queries[ii] ;
      if (query == 'Document Id') {
        qdata.push({ 'name': query, 'tip': 'Search against the document identifier values.'}) ;
      }
      else if (query == 'Indexed Properties') {
        qdata.push( {'name': query, 'tip': 'You can search against the following indexed properties: '+indexedProps.join(", ")}) ;
      }
      else
      {
        // Nothing for now.
      }
    }
    qstore = Ext.create('Ext.data.Store', {
      model: 'viewFormComboModel',
      data: qdata 
    }) ;
    qvalue = 'Document Id' ;
  }
  qvalue = (matchQuery == "" ? qvalue : matchQuery) ; // Replace query with the user provided one, if exists.
  var modeData = [
                    { 'name': 'Exact', 'tip': 'Return documents where the entered search term exactly matches the target property value via case sensitive matching.' },
                    { 'name': 'Full', 'tip': 'Return documents where the entered search term fully matches the target property value via case <b>IN</b>sensitive matching.'},
                    { 'name': 'Keyword', 'tip': 'Return documents where the entered search term can be found <i>anywhere</i> in the target property value via case <b>IN</b>sensitive matching.'},
                    { 'name': 'Prefix', 'tip': 'Return documents that have target property values starting with the entered search term.'}
                ] ;
  var modeStore = Ext.create('Ext.data.Store', {
    model: 'viewFormComboModel',
    data: modeData
  }) ;
  var modeValue = ( matchMode == '' ? 'Prefix' : matchMode ) ;
  var viewValue = ( matchView == '' ? views[0] : matchView ) ;
  Ext.create('Ext.window.Window', {
    title: 'Generate View',
    height: 175,
    width: 355,
    id: 'solicitViewInfoDisplayWindow',
    modal: true,
    autoScroll: true,
    layout: 'fit',
    items: {  
      xtype: 'form',
      frame: true,
      items:
      [
        {
          xtype: 'combobox',
          editable: false,
          fieldLabel: '<span id=\'queryLabelSpanId\'><b>Query</b></span>',
          store: qstore,
          value: qvalue,
          width: 330,
          id: 'viewFormQuery',
          displayField: 'name',
          valueField: 'name',
          queryMode: 'local',
          listConfig: {
            getInnerTpl: function(){
              return '<div data-qtip="{tip}">{name}</div>';
            }
          }
        },
        {
          xtype: 'combobox',
          editable: false,
          fieldLabel: '<span id=\'modeLabelSpanId\'><b>Mode</b></span>',
          store: modeStore,
          value: modeValue,
          displayField: 'name',
          valueField: 'name',
          queryMode: 'local',
          width: 330,
          id: 'viewFormMode',
          listConfig: {
            getInnerTpl: function(){
              return '<div data-qtip="{tip}">{name}</div>';
            }
          }
        },
        {
          xtype: 'combobox',
          editable: false,
          fieldLabel: '<span id=\'viewLabelSpanId\'><b>View</b></span>',
          store: views,
          value: viewValue,
          width: 330,
          id: 'viewFormView'
        },
        {
          xtype: 'textfield',
          fieldLabel: '<span id=\'termLabelSpanId\'><b>Term</b></span>',
          width: 330,
          id: 'viewFormTerm',
          name: 'viewFormTerm',
          value : matchValue,
          allowBlank: false
        },
        {
          xtype: 'hiddenfield',
          name: 'authenticity_token',
          value: csrf_token
        },
        {
          xtype: 'hiddenfield',
          name: 'gbGroup',
          value: gbGroup
        },
        {
          xtype: 'hiddenfield',
          name: 'kbName',
          value: kbName
        },
        {
          xtype: 'hiddenfield',
          name: 'project_id',
          value: projectId
        },
        {
          xtype: 'hiddenfield',
          name: 'collectionSet',
          value: Ext.getCmp('collectionSetCombobox').value
        }
      ],
      buttons:
      [
        {
          text: 'Submit',
          handler: function() {
            var form = this.up('form').getForm();
            if(form.isValid()){
              form.submit({
                url: 'genboree_kbs/view/generateview',
                timeout: 600,
                waitMsg: 'Searching matches...',
                success: function(form, action) {
                  viewDocs = JSON.parse(action.response.responseText)['data'] ; // Why is this a global??
                  if(viewDocs.length == 0)
                  {
                    Ext.Msg.alert('NO RESULTS', 'Unfortunately, your query did not result in any matches. Please try again with different parameter values.') ;
                  }
                  else
                  {
                    // Next get the view definition itself to get the order of the columns right
                    var currView = Ext.getCmp('viewFormView').getValue() ;
                    var formEls = [Ext.getCmp('viewFormQuery').getValue(), Ext.getCmp('viewFormMode').getValue(), Ext.getCmp('viewFormView').getValue(), Ext.getCmp('viewFormTerm').getValue()]
                    Ext.getCmp('solicitViewInfoDisplayWindow').close() ; 
                    getView(currView, formEls) ;
                  }
                },
                failure: function(form, action){
                  var msg = 'Your view could not be generated.' ;
                  try {
                    msg = msg + "</br></br>" + JSON.parse(action.response.responseText)['msg'] ;
                  }
                  catch(err)
                  {
                    // Can't parse the response. Just show the default error message.
                  }
                  msg += "</br></br>Please contact the project administrator to resolve the issue."
                  var msgBox = Ext.create('Ext.window.MessageBox', {
                    overflowY: 'auto',
                  }).show({
                    title: 'ERROR',
                    msg: msg,
                    width: 400,
                    //height: 500,
                    buttons: Ext.Msg.OK
                  }) ;
                  Ext.getCmp('solicitViewInfoDisplayWindow').close() ;
                }
              });
            }
          }
        }
      ]
      
    }
  }).show();
  regToolTipsForForm() ;
}

// Helper function for registering tool tips to form elements
// Registers tool-tips to both input labels and the input elements. 
function regToolTipsForForm()
{
  var tip = "" ;
  if (indexedProps.length == 0)
  {
    tip = "The model of this collection does not have any indexed properties.</br>You can only search using Document Ids." ;
  }
  else
  {
    tip = "The model of this collection has the following indexed properties:</br>" ;
    tip = tip + indexedProps.join(", ") ; 
  }
  Ext.tip.QuickTipManager.register({
    target: 'queryLabelSpanId',
    text: 'Select a predefined or one of the custom queries. A query defines what to search against (Target) in the database.'
  }) ;  
  Ext.tip.QuickTipManager.register({
    target: 'viewLabelSpanId',
    text: 'Select a predefined or one of the custom views. A view defines a specific set of properties to show for the documents that match the search criteria.'
  }) ;
  Ext.tip.QuickTipManager.register({
    target: 'modeLabelSpanId',
    text: 'Select a search mode.'
  }) ;
  Ext.tip.QuickTipManager.register({
    target: 'termLabelSpanId',
    text: 'Enter a search term to search the database.'
  }) ;
}


// Gets the definition of the view and calls the function to render the view grid as a success callback
function getView(view, formEls)
{
  maskObj.show() ;
  Ext.Ajax.request(
  {
    url : 'genboree_kbs/view/getview',
    timeout : 90000,
    method: 'GET',
    params:
    {
      "authenticity_token": csrf_token,
      project_id: projectId,
      view:  view
    },
    callback : function(opts, success, response)
    {
      maskObj.hide() ;
      try
      {
        var apiRespObj  = JSON.parse(response.responseText) ;
        var viewDataObj = apiRespObj['data'] ;
        var statusObj   = apiRespObj['status'] ;
        if(response.status >= 200 && response.status < 400 && viewDataObj)
        {
          var items = viewDataObj['name']['properties']['viewProps']['items'] ;
          var props = [] ;
          var ii ;
          props.push({ 'name': docModel.name, 'indexName': docModel.name, 'label': docModel.name, 'domain': getDomainInfo(docModel)}) ;
          for(ii=0; ii<items.length; ii++)
          {
            var path = items[ii]['prop']['value'] ;
            var indexName = path ;
            var pathEls = path.split(".") ;
            // Get domain info for the property in the view.
            // Useful for special rendering of the value like URL properties having links, etc
            var domainEls = getDomainInfoFromPropPath(path) ;
            var label = pathEls[pathEls.length-1] ;
            // Check for labels. If a label exists for a property, override the default name in the grid column header
            if(items[ii]['prop']['properties'] && items[ii]['prop']['properties']['label'] && items[ii]['prop']['properties']['label']['value'])
            {
              label = items[ii]['prop']['properties']['label']['value'] ;
              indexName = label ;
            }
            props.push({ 'name': path, 'domain': domainEls[0], 'label': label, 'indexName': indexName.replace(/\./g, "") }) ;
          }
          if (props.length == 0) {
            Ext.Msg.alert('ERROR', 'The selected view does not have any \'prop\' listed under items. It looks like an empty view.') ; 
          }
          else{
            initViewGridRenderDialog(props, formEls) ;
          }
        }
        else
        {
          var displayMsg = "The following error was encountered while retrieving the view:<br><br>" ;
          displayMsg += ( "<b>Error Code:</b> <i>" + (statusObj['statusCode'] ? statusObj['statusCode'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" ) ;
          displayMsg += ( "<b>Error Message:</b> <i>" + (statusObj['msg'] ? statusObj['msg'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" );
          displayMsg += "<br><br>Please contact a project admin to resolve this issue." ;
          Ext.Msg.alert("ERROR", displayMsg) ;
        }
      }
      catch(err)
      {
        if (Ext.getCmp('solicitViewInfoDisplayWindow')) {
          Ext.getCmp('solicitViewInfoDisplayWindow').close() ;
        }
        Ext.Msg.alert('ERROR', "Bad data returned from server when retrieving the view doc (definition of view).<br><br>"+err+"<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
      }
    }
  }) ;
}

function initViewGridRenderDialog(props, formEls) {
  var msg = "How would you like to view the results?" ;
  msg += "</br></br><b>NOTE</b>: Viewing the results in the current tab will replace the tab's contents." ;
  if(documentEdited)
  {
    msg += "</br></br>We advise you to save the current document first before viewing the results." ;
  }
  if(newdocObj || Ext.getCmp('modelTreeGrid') || Ext.getCmp('docsVersionsGrid')) // Render a warning if something is already being displayed
  {
    Ext.Msg.show({
      title: "Generate View",
      msg: msg,
      width: 500,
      buttonText: {yes: 'Open in current tab', no: 'Open in new tab', cancel: 'Cancel'},
      id: 'genViewMessBox',
      fn: function(btn){
        if(btn == 'yes')
        {
          editModeValue = false ; // This is returned from the 'before edit' event of the row plugin.
          Ext.getCmp('manageDocsGrid').getSelectionModel().deselectAll() ;
          Ext.getCmp('browseDocsGrid').getSelectionModel().deselectAll() ;
          Ext.getCmp('manageModelsGrid').getSelectionModel().deselectAll() ;
          disablePanelBtn('editDelete') ;
          initViewGrid(props, formEls) ;
        }
        else if (btn == 'no') {
          var urlLink = "http://"+location.host+kbMount+"/genboree_kbs?project_id="+projectIdentifier+"&coll="+Ext.getCmp('collectionSetCombobox').value+"&showViewGrid=true" ;
          urlLink = urlLink + "&matchQuery="+escape(formEls[0])+"&matchView="+escape(formEls[2])+"&matchMode="+escape(formEls[1])+"&matchValue="+escape(formEls[3]) ;
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
    Ext.getCmp('manageModelsGrid').getSelectionModel().deselectAll() ;
    initViewGrid(props, formEls) ;  
  }
}

function getViewDocs()
{
  maskObj.show() ;
  Ext.Ajax.request(
  {
    url : 'genboree_kbs/view/generateview',
    timeout : 90000,
    method: 'POST',
    params:
    {
      "authenticity_token": csrf_token,
      project_id: projectId,
      collectionSet: Ext.getCmp('collectionSetCombobox').value,
      'viewFormQuery-inputEl': matchQuery,
      'viewFormView-inputEl': matchView,
      'viewFormMode-inputEl': matchMode,
      'viewFormTerm': matchValue
    },
    success: function(response, opts) {
      maskObj.hide() ;
      viewDocs = JSON.parse(response.responseText)['data'] ;
      if(viewDocs.length == 0)
      {
        Ext.Msg.alert('NO RESULTS', 'Unfortunately, your query did not result in any matches. Please try again with different parameter values.') ;
      }
      else
      {
        // Next get the view definition itself to get the order of the columns right
        getView(matchView, [matchQuery, matchMode, matchView, matchValue]) ;
      }
    },
    failure: function(response, opts){
      maskObj.hide() ;
      var msg = 'Your view could not be generated.' ;
      try {
        msg = msg + "</br></br>" + JSON.parse(response.responseText)['msg'] ;
      }
      catch(err)
      {
        // Can't parse the response. Just show the default error message.
      }
      msg += "</br></br>Please contact the project administrator to resolve the issue."
      var msgBox = Ext.create('Ext.window.MessageBox', {
        overflowY: 'auto',
      }).show({
        title: 'ERROR',
        msg: msg,
        width: 400,
        //height: 500,
        buttons: Ext.Msg.OK
      }) ;
    }
  }) ;  
}


// Iterates over 'viewDocs' and constructs object required for ExtJS to render grid
function initViewGrid(props, formEls)
{
  // Destroy any other grids/tree-grids/views being shown currently
  resetMainPanel() ;
  disablePanelBtn('docHistory') ;
  docVersion = "" ; // Set docVersion to current. Links on the view grid should open the current version of a document.
  // Create the column model that the grid will use
  var colModel = [] ;
  var ii ;
  for(ii=0; ii<props.length; ii++)
  {
    var colObj = {
      text: "<b>"+props[ii]['label']+"</b>",
      sortable: true,
      flex: 1,
      dataIndex: props[ii]['indexName']
    } ;
    if (props[ii]['name'] == docModel.name) {
      colObj['renderer'] = function(value, md, rec, ri, ci, store, view){
        var linkIdentifier = value ;
        var retVal = "<span data-qtip='"+value+"'>" ;
        var linkCollection = Ext.getCmp('collectionSetCombobox').value ;
        var urlLink = "http://"+location.host+kbMount+"/genboree_kbs?project_id="+projectIdentifier+"&coll="+escape(linkCollection)+"&doc="+escape(value) ;
        var docLink = "<a target=\"_blank\" onclick=\"return displayLinkOpts(this.href, true,'"+escape(linkCollection)+"','"+escape(linkIdentifier)+"'); \" href=\""+urlLink+"\">"+value+"</a>" ;
        retVal = retVal + docLink + "</span>" ;
        return retVal ;
      }
    }
    else if (props[ii]['domain'] == 'url') {
      colObj['renderer'] = function(value, md, rec, ri, ci, store, view){
        var retVal ;
        var grpKbCollDocRegExp = /\/REST\/v1\/grp\/([^/\?]+)\/kb\/([^/\?]+)\/coll\/([^/\?]+)\/doc\/([^/\?]+)/ ;
        var grpKbCollRegExp = /\/REST\/v1\/grp\/([^/\?]+)\/kb\/([^/\?]+)\/coll\/([^/\?]+)/ ;
        var relativePathCollDocRegExp = /\/coll(ection)?\/([^/\?]+)\/doc(ument)?\/([^/\?]+)/ ;
        var relativePathDocRegExp = /\/doc(ument)?\/([^/\?]+)/ ;
        // Create an 'a' element to get the individual URL components
        var urlInfo = document.createElement('a') ;
        urlInfo.href = value ;
        // Check if its a link to one of our collection/document
        if(location.host == urlInfo.hostname || urlInfo.hostname == '') // IE gives back '' as host for relative URLs
        {
          var path = urlInfo.pathname ;
          if(!path.match(/^\//)) // IE fix
          {
            path = '/'+path ;
          }
          // Does the URL all the componenets including the doc?
          if(path.match(grpKbCollDocRegExp))
          {
            var mm = path.match(grpKbCollDocRegExp) ;
            // Check if grp and kb match
            if(unescape(mm[1]) == gbGroup && unescape(mm[2]) == kbName)
            {
              var urlLink = "http://"+location.host+kbMount+"/genboree_kbs?project_id="+projectIdentifier+"&coll="+mm[3]+"&doc="+mm[4] ;
              linkIdentifier = unescape(mm[4]) ;
              linkCollection = unescape(mm[3]) ;
              value = "<a target=\"_blank\" onclick=\"return displayLinkOpts(this.href, false,'"+escape(linkCollection)+"','"+escape(linkIdentifier)+"'); \" href=\""+urlLink+"\">"+value+"</a>" ;
            }
          }
          else if(path.match(grpKbCollRegExp)) // Maybe the URL only has collections
          {
            var mm = path.match(grpKbCollRegExp) ;
            // Check if grp and kb match
            if(unescape(mm[1]) == gbGroup && unescape(mm[2]) == kbName)
            {
              linkCollection = unescape(mm[3]) ;
              linkIdentifier = null ;
              var urlLink = "http://"+location.host+kbMount+ "/genboree_kbs?project_id="+projectIdentifier+"&coll="+mm[3] ;
              value = "<a target=\"_blank\" onclick=\"return displayLinkOpts(this.href, false,'"+escape(linkCollection)+"',null); \" href=\""+urlLink+"\">"+value+"</a>" ;
            }
          }
          else if(path.match(relativePathCollDocRegExp))
          {
            var mm = path.match(relativePathCollDocRegExp) ;
            linkIdentifier = unescape(mm[4]) ;
            linkCollection = unescape(mm[2]) ;
            var urlLink = "http://"+location.host+kbMount+ "/genboree_kbs?project_id="+projectIdentifier+"&coll="+mm[2]+"&doc="+mm[4] ;
            value = "<a target=\"_blank\" onclick=\"return displayLinkOpts(this.href, false,'"+escape(linkCollection)+"','"+escape(linkIdentifier)+"'); \" href=\""+urlLink+"\">"+value+"</a>" ;
          }
          else if(path.match(relativePathDocRegExp))
          {
            var mm = path.match(relativePathDocRegExp) ;
            linkIdentifier = unescape(mm[2]) ;
            // Assume collection is the current one
            linkCollection = Ext.getCmp('collectionSetCombobox').value ;
            var urlLink = "http://"+location.host+kbMount+"/genboree_kbs?project_id="+projectIdentifier+"&coll="+escape(linkCollection)+"&doc="+mm[2] ;
            value = "<a target=\"_blank\" onclick=\"return displayLinkOpts(this.href, false,'"+escape(linkCollection)+"','"+escape(linkIdentifier)+"'); \" href=\""+urlLink+"\">"+value+"</a>" ;
          }
          else // Assume just the doc identifier or genboree URL pointing to a non KB resource (like file)
          {
            // If the value has a '/' in it, it is probably not URL pointing to a doc and just a straight up genboree URL to some other resource
            if (unescape(value).match(/\//)) {
              value = "<a target=\"_blank\" href=\""+value+"\">"+value+"</a>" ;
            }
            else {
              linkIdentifier = unescape(value) ;
              // Assume collection is the current one
              linkCollection = Ext.getCmp('collectionSetCombobox').value ;
              var urlLink = "http://"+location.host+kbMount+"/genboree_kbs?project_id="+projectIdentifier+"&coll="+escape(linkCollection)+"&doc="+value ;
              value = "<a target=\"_blank\" onclick=\"return displayLinkOpts(this.href, false,'"+escape(linkCollection)+"','"+escape(linkIdentifier)+"'); \" href=\""+urlLink+"\">"+value+"</a>" ;
            }
          }
        }
        else
        {
          value = "<a target=\"_blank\" href=\""+value+"\">"+value+"</a>" ;
        }
        // The tool-tips for the value column have a custom delay
        // The values in toolTipMap will be registered separately
        var id = Math.random() ;
        var origVal = value ;
        var menuBtnLink = "<a  data-qtip: \"Click to open properties context menu.\" style=\"padding-left:20px;font-weight:normal;\" href=\"javascript:showPropMenu()\">"+"<img style=\"margin-top:-3px; margin-bottom:-4px;\"  src='plugin_assets/genboree_kbs/images/silk/note_edit.png'>"+"</a>" ;
        value = "<span"+" id="+id+">"+value+"</span>" ;
        if (origVal && origVal != "") {
          toolTipMap[id] = origVal ;
        }
        if(md.record.data.category)
        {
          retVal = "<span class=\"genbKb-category-font-weight\">"+value+"</span>" ;
        }
        else
        {
          retVal = value ;
        }
        return retVal ;
      }
    }
    else if (props[ii]['domain'] == 'fileUrl') {
      colObj['renderer'] = function(value, md, rec, ri, ci, store, view){
        if (value.match(/\/REST\/v1\/grp/))
        {
          fileUrlToDownload = value ;
          value = "<a href=\"javascript:downloadFile()\">"+unescape(value)+"</a>" ;
        }
        else
        {
          value = "<a target=\"_blank\" href=\""+value+"\">"+value+"</a>" ;
        }
        // The tool-tips for the value column have a custom delay
        // The values in toolTipMap will be registered separately
        var id = Math.random() ;
        var origVal = value ;
        var menuBtnLink = "<a  data-qtip: \"Click to open properties context menu.\" style=\"padding-left:20px;font-weight:normal;\" href=\"javascript:showPropMenu()\">"+"<img style=\"margin-top:-3px; margin-bottom:-4px;\"  src='plugin_assets/genboree_kbs/images/silk/note_edit.png'>"+"</a>" ;
        value = "<span"+" id="+id+">"+value+"</span>" ;
        if (origVal && origVal != "") {
          toolTipMap[id] = origVal ;
        }
        if(md.record.data.category)
        {
          retVal = "<span class=\"genbKb-category-font-weight\">"+value+"</span>" ;
        }
        else
        {
          retVal = value ;
        }
        return retVal ;
      }
    }
    else
    {
      colObj['renderer'] = function(value, md, rec, ri, ci, store, view){
        linkIdentifier = value ;
        var retVal = "<span data-qtip='"+value+"'>"+value+"</span>" ;
        return retVal ;
      }
    }
    colModel.push(colObj) ;
  }
  // Convert viewDocs into something that the grid can understand
  var viewStoreData = [] ;
  var doc ;
  var fields = [] ;
  for(ii=0; ii<viewDocs.length; ii++)
  {
    doc = viewDocs[ii] ;
    var rec = {} ;
    var keys = Object.keys(doc) ;
    var jj ;
    for(jj=0; jj<keys.length; jj++)
    {
      var prop = keys[jj]  ;
      var field = prop.replace(/\./g, "") ;
      rec[field] = doc[prop]['value'] ;
      if (ii == 0) {
        fields.push(field) ;
      }
    }
    viewStoreData.push(rec) ;
  }
  
  
  Ext.create('Ext.data.Store', {
    storeId: 'viewStore',
    fields: fields,
    data: viewStoreData,
    proxy: {
      type: 'memory',
      reader: {
        type: 'json'
      }
    }
  }) ;
  renderViewGrid(colModel, formEls) ;
}

function renderViewGrid(colModel, formEls)
{
  initViewGridToolbar(formEls) ;
  Ext.create('Ext.grid.Panel', {
    store: Ext.data.StoreManager.lookup('viewStore'),
    columns: colModel,
    id: 'viewGrid',
    //width: panelWidth,
    title: 'Query Results Grid ('+viewDocs.length+' matches found)',
    tbar: Ext.getCmp('viewGridToolbar'), // defined in toolbars.js
    //autoScroll: true,
    height: panelHeight-35, // set height to total hight of layout panel - height of menubar
    renderTo: 'treeGridContainer-body',
    collapsible: false,
    viewConfig: {
      listeners: {
          refresh: function(dataview){
            Ext.each(dataview.panel.columns, function(column){
              column.autoSize() ;  
            })
          }
      },
      enableTextSelection: true
    }
  });
}


// Makes AJAX call to retrieve the list of available views in the KB.
// Called as a callback of getQueries()
// Calls displaySolicitViewInfoDialog() as callback if view list if returned successfully.
function getViews(queries)
{
  maskObj.show() ;
  Ext.Ajax.request(
  {
    url : 'genboree_kbs/view/getviews',
    timeout : 90000,
    method: 'GET',
    params:
    {
      "authenticity_token": csrf_token,
      project_id: projectId,
    },
    callback : function(opts, success, response)
    {
      maskObj.hide() ;
      try
      {
        var apiRespObj  = JSON.parse(response.responseText) ;
        var viewsDataObj = apiRespObj['data'] ;
        var statusObj   = apiRespObj['status'] ;
        if(response.status >= 200 && response.status < 400 && viewsDataObj)
        {
          var ii ;
          var views = [] ;
          for(ii=0; ii<viewsDataObj.length; ii++)
          {
            views.push(viewsDataObj[ii]['text']['value']) ;
          }
          // Render form for solicting view-related info from user
          displaySolicitViewInfoDialog(queries, views) ;
        }
        else
        {
          var displayMsg = "The following error was encountered while retrieving the views list for this KB:<br><br>" ;
          displayMsg += ( "<b>Error Code:</b> <i>" + (statusObj['statusCode'] ? statusObj['statusCode'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" ) ;
          displayMsg += ( "<b>Error Message:</b> <i>" + (statusObj['msg'] ? statusObj['msg'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" );
          displayMsg += "<br><br>Please contact a project admin to resolve this issue." ;
          Ext.Msg.alert("ERROR", displayMsg) ;
        }
      }
      catch(err)
      {
        Ext.Msg.alert('ERROR', "Bad data returned from server when retrieving the view list.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
      }
    }
  }) ;
}

// Makes AJAX call to retrieve the list of available queries in the KB.
// Gets the list of available views as callback
function getQueries()
{
  maskObj.show() ;
  Ext.Ajax.request(
  {
    url : 'genboree_kbs/view/getqueries',
    timeout : 90000,
    method: 'GET',
    params:
    {
      "authenticity_token": csrf_token,
      project_id: projectId,
    },
    callback : function(opts, success, response)
    {
      maskObj.hide() ;
      try
      {
        var apiRespObj  = JSON.parse(response.responseText) ;
        var queriesDataObj = apiRespObj['data'] ;
        var statusObj   = apiRespObj['status'] ;
        if(response.status >= 200 && response.status < 400 && queriesDataObj)
        {
          var ii ;
          var queries = [] ;
          for(ii=0; ii<queriesDataObj.length; ii++)
          {
            queries.push(queriesDataObj[ii]['text']['value']) ;
          }
          // Get the list of views
          getViews(queries) ;
        }
        else
        {
          var displayMsg = "The following error was encountered while retrieving the query list:<br><br>" ;
          displayMsg += ( "<b>Error Code:</b> <i>" + (statusObj['statusCode'] ? statusObj['statusCode'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" ) ;
          displayMsg += ( "<b>Error Message:</b> <i>" + (statusObj['msg'] ? statusObj['msg'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" );
          displayMsg += "<br><br>Please contact a project admin to resolve this issue." ;
          Ext.Msg.alert("ERROR", displayMsg) ;
        }
      }
      catch(err)
      {
        Ext.Msg.alert('ERROR', "Bad data returned from server when retrieving the list of queries for this KB.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
      }
    }
  }) ;
}