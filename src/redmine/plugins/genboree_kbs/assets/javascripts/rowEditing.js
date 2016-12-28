function initRowEditingPlugin()
{
  var rowEditing = Ext.create('Ext.grid.plugin.RowEditing', {
    clicksToEdit: 2,
    id: 'editorGridRowPlugin',
    pluginId: 'rePlugin',
    listeners: {
      edit: function(editor, context, eOpts)
      {
        
        // Set the new values to be the current values in the tree
        var propName = context.newValues.name ;
        var propValue = context.newValues.value ;
        context.record.data.value = propValue ;
        context.record.raw.value = propValue ;
        if(addingChild)
        {
          if(childType == 'properties')
          {
            // Add the domain info for the record that was just added
            var domainEls = domainMap[propName] ;
            context.record.data.domain = domainEls[0] ;
            context.record.data.domainOpts = domainEls[1] ;
            propValue = castPropValue(domainEls[0], domainEls[1], propValue, context) ;
            context.record.data.modelAddress = recordMap[propName].data.modelAddress ;
            context.record.data.leaf = recordMap[propName].data.leaf ;
            if(recordToReplace)
            {
              if(propName != recordToReplace.data.name)
              {
                selectedRecord.replaceChild(recordMap[propName], recordToReplace) ;
              }
              recordToReplace = null ;
            }
            docPropOfSelectedNode[propName] = {'value': propValue } ;
            if(context.record.data.modelAddress.properties)
            {
              docPropOfSelectedNode[propName]['properties'] = {} ;
            }
            else if(context.record.data.modelAddress.items)
            {
              docPropOfSelectedNode[propName]['items'] = [] ;
            }
            else
            {
              // Nothing to do
            }
            context.record.data.docAddress = docPropOfSelectedNode[propName] ;
          }
          else // items
          {
            propValue = castPropValue(context.record.data.domain, context.record.data.domainOpts, propValue, context) ;
            var newItem = {} ;
            newItem[propName] = {'value': propValue } ;
            if(context.record.data.modelAddress.properties)
            {
              newItem[propName]['properties'] = {} ;
            }
            else if(context.record.data.modelAddress.items)
            {
              newItem[propName]['items'] = [] ;
            }
            else
            {
              // Nothing to do
            }
            // Shove the new record in the items list of the parent node
            if(!docPropOfSelectedNode)
            {
              docPropOfSelectedNode = [] ;
            }
            docPropOfSelectedNode.push(newItem) ;
            context.record.data.docAddress = newItem[propName] ;
            // This is required because for some reason the newly added 'item' does not automatically become the selected record as is the case for properties.
            // To-do: need to figure out why...
            selectedRecord = context.record ; 
          }
          addingChild = false ;
          // Create required children nodes if the prop we just added has any 'required' sub-props
          // Skip adding child nodes if prop is one of the 'Auto Content Generation' domains.
          // Handling of 'Auto Content Generation' props will be done as the last operation of this event handler.
          if (!contentGenDomains[context.record.data.domain]) {
            var children = addSubChildrenForNewDocument(context.record.data.modelAddress, context.record.data.docAddress) ; 
            insertChildNode(context.record, children) ;
          }
          postEditOperation(context, recordMap, propName) ;
        }
        else
        {
          var domain = context.record.data.domain ;
          var domainOpts = context.record.data.domainOpts
          propValue = castPropValue(domain, domainOpts, propValue, context) ;
          context.record.data.docAddress['value'] = propValue ;
        }
        // Make the first column un-editable for future row editing operations.
        context.record.data.editable = false ;
        // Set editRequired to false. The property has been updated. No need to display the warning icon anymore
        context.record.data.editRequired = false ;
        // Enable the save btn
        toggleBtn('saveDoc', 'enable') ;
        documentEdited = true ;
        var mainTreeObj = Ext.getCmp('mainTreeGrid') ;
        mainTreeObj.setTitle(getModifiedTitle(true)) ;
        // Do a node interface operation just to refresh the column rendering since I do not know how else to rerender the Value column
        // Just calling the renderer() function for the second column DOES NOT work! (Maybe something else listens to the renderer() and performs required updates depending on what it returns)
        // This is required for URL type values which need to show the hyperlink immediately after the editing is finished.
        // This just replaces the recently edited record with itself, i.e, a No-OP
        context.record.parentNode.replaceChild(context.record, context.record) ;
        dirtyRecords[context.record.id] = context.record ;
        if(!freshDocument)
        {
          toggleBtn('discardChanges', 'enable') ;
        }
        // If the property is one of 'Auto Content Generation' properties, we will need to make an AJAX request to fill in the childrren props of this property
        //if (contentGenDomains[context.record.data.domain]) {
        //  generateAutoContent(context.record.data.domain) ;
        //}
      },
      validatedit: function(editor, context, eOpts)
      {
        var aa ;
      },
      canceledit: function(editor, context, eOpts)
      {
        // Remove newly added record from tree
        if(addingChild)
        {
          var parentNode = context.record.parentNode ;
          parentNode.removeChild(context.record) ;
          addingChild = false ;
        }
      },
      beforeedit: function(editor, context, eOpts)
      {
        // Cancel any previous editing instance
        var rowEditPlugin = Ext.getCmp('mainTreeGrid').getPlugin('rePlugin') ;
        if (rowEditPlugin.editing) {
          rowEditPlugin.cancelEdit() ;
        }
        // If the user is trying to edit the identifier, display a warning message
        if(editModeValue && !freshDocument && context.record.data['identifier'])
        {
          Ext.Msg.show({
            title: "Warning",
            msg: 'You are trying to change the document identifier. What would you like to do?',
            buttonText: {yes: 'Rename identifier for current document', no: 'Create new document with updated identifier', cancel: 'Cancel'},
            height: 100,
            width: 550,
            fn: function(btn)
            {
              // We will mimic a 'freshDocument' as if the doc was created using the 'Create new document' btn.
              if(btn == 'no')
              {
                originalDocumentIdentifier = null ;
                freshDocument = true ;
              }
              else if (btn == 'cancel') {
                Ext.getCmp('mainTreeGrid').getPlugin('rePlugin').cancelEdit() ;
              }
            }
          }) ;
        }
        var attrCM = context.grid.columns[0] ;
        var origWidthCM = attrCM.getWidth() ;
        var valCM = context.grid.columns[1] ;
        var origWidthVal = valCM.getWidth() ;
        var fieldName       = context.record.data['name'] ;
        var fieldDefaultVal = context.record.data['value'] ;
        var fieldDomain     = context.record.data['domain'] ;
        var fieldDomainOpts = context.record.data['domainOpts'] ;
        var fieldEditable   = context.record.data['editable'] ;
        var valueFixed      = context.record.data['fixed'] ;
        var textFieldObj ;
        if(!addingChild)
        {
          attrCM.setEditor({ xtype: 'textfield'}) ;
        }
        // Disable the tree column if its not part of  a 'new' record or there is only one child property that can be added to a node
        if(fieldEditable)
        {
          this.editor.form.findField('name').enable() ;
        }
        else
        {
          this.editor.form.findField('name').disable() ;  
        }
        updateEditor(fieldDomain, fieldDomainOpts) ;
        var valueEditor = valCM.getEditor() ;
        attrCM.getEditor().setWidth(origWidthCM) ;
        valueEditor.setWidth(origWidthVal) ;
        // Under certain conditions, the value column should be disabled:
        // value is fixed (cannot be changed) or domain is 'fileUrl' which requires two inputs (file to be uploaded and target of the file to be uploaded)
        if(valueFixed)
        {
          this.editor.form.findField('value').disable() ;
        }
        else
        {
          this.editor.form.findField('value').enable() ;
        }
        if (!editModeValue) {
          if (role == 'subscriber') {
            Ext.Msg.alert("Warning", "Subscribers are not allowed to edit/delete/save.") ;
          }
          else
          {
            var msg = "Edit mode is set to OFF. You can enable the edit mode by clicking on 'Edit "+singularLabel+"' under 'Manage "+pluralLabel+"' in the left panel."
            Ext.Msg.alert("Warning", msg) ;
          }
        }
        return editModeValue ;
      }
    }
  }) ;
  return rowEditing ;
}

// Adds a child record to a node (if there are sub-properties available to add)
// Registered to the Add Child btn in the toolbar
// Cancels any previous row editing operation going on.
function addChildNode()
{
  var rowEditPlugin = Ext.getCmp('mainTreeGrid').getPlugin('rePlugin') ;
  if (rowEditPlugin.editing) {
    rowEditPlugin.cancelEdit() ;
  }
  var selectedNode = Ext.getCmp('mainTreeGrid').getSelectionModel().getSelection()[0] ;
  // Collect the list of properties that can be added
  if(selectedNode)
  {
    selectedNode.expand() ;
    addingChild = true ;
    var displayList = [] ;
    var displayNames = [] ;
    var ii ;
    var modelItems ;
    domainMap = {} ;
    recordMap = {} ;
    var docAddress = selectedNode.data.docAddress ;
    if(selectedNode.data.modelAddress.items) // selected node has items
    {
      childType = 'items' ;
      modelItems = selectedNode.data.modelAddress.items ;
      docPropOfSelectedNode = docAddress.items ;
      // Items must be singly rooted
      var propToInsert = modelItems[0] ;
      var value = '' ;
      if(propToInsert['default'])
      {
        value = propToInsert['default'] ;
      }
      var domainEls = getDomainInfo(propToInsert) ;
      var newRec = Ext.create('Task', {
        name: propToInsert.name,
        value: value,
        id: new Date().getUTCMilliseconds(),
        modelAddress: propToInsert,
        docAddress: '',
        domain: domainEls[0],
        domainOpts: domainEls[1],
        'default': value,
        description: propToInsert.description ? propToInsert.description : '',
        leaf: ( ( propToInsert.properties || propToInsert.items ) ? false : true ),
        editable: false,
        fixed: propToInsert.fixed,
        category: propToInsert.category
      }) ;
      recordMap[propToInsert.name] = newRec ;
      selectedNode.appendChild(newRec) ;
      var nameColModel = Ext.getCmp('mainTreeGrid').columns[0] ;
      var valColModel = Ext.getCmp('mainTreeGrid').columns[1] ;
      var origWidthOfNameCol = nameColModel.getWidth() ;
      var origWidthOfValCol = valColModel.getWidth() ;
      Ext.getCmp('mainTreeGrid').columns[0].setEditor({ xtype: 'textfield'}) ;
      Ext.getCmp('mainTreeGrid').getPlugin('rePlugin').startEdit(newRec, 0) ;
      updateEditor(domainEls[0], domainEls[1]) ;
      valColModel.getEditor().setWidth(origWidthOfValCol) ;
      nameColModel.getEditor().setWidth(origWidthOfNameCol) ;
      // Disable the value column if the property is 'fixed'
      if (propToInsert.fixed) {
        rowEditPlugin.editor.form.findField('value').disable() ;
      }
      else
      {
        rowEditPlugin.editor.form.findField('value').enable() ;
      }
    }
    else // selected node has properties
    {
      childType = 'properties' ;
      var modelProp = selectedNode.data.modelAddress.properties ;
      docPropOfSelectedNode = docAddress.properties ;
      if(!docPropOfSelectedNode)
      {
        selectedNode.data.docAddress['properties'] = {} ;
        docPropOfSelectedNode = selectedNode.data.docAddress.properties ;
      }
      // Check how many properpties can be added from the model
      // This needs to be done twice since the record instances need to know if the first column can be edited or not
      var selectableProps = 0 ;
      for(ii=0; ii<modelProp.length; ii++)
      {
        if(!docPropOfSelectedNode[modelProp[ii].name])
        {
          selectableProps += 1 ;
        }
      }
      for(ii=0; ii<modelProp.length; ii++)
      {
        var fieldModel = modelProp[ii] ;
        if(!docPropOfSelectedNode[fieldModel.name])
        {
          var domainEls = getDomainInfo(fieldModel) ;
          displayList.push( {'name': fieldModel.name, 'fixed': fieldModel.fixed, 'items': fieldModel['items'], 'description': fieldModel['description'], 'default': fieldModel['default'], 'properties': fieldModel.properties, 'domain': domainEls[0], 'domainOpts': domainEls[1], 'modelAddress': fieldModel  } ) ;
          domainMap[fieldModel.name] = [domainEls[0], domainEls[1]] ;
          displayNames.push({ 'name': fieldModel.name, 'description': (fieldModel.description ? fieldModel.description : '')}) ;
          var tmpRec = Ext.create('Task', {
            name: fieldModel.name,
            value: fieldModel['default'] ? fieldModel['default'] : '',
            id: new Date().getUTCMilliseconds(),
            modelAddress: fieldModel,
            fixed: fieldModel.fixed,
            description: fieldModel.description ? fieldModel.description : '',
            category: fieldModel.category,
            'default': fieldModel['default'],
            docAddress: '',
            leaf: ( fieldModel.properties || fieldModel.items)  ? false : true,
            editable: selectableProps > 1 ? true : false
          }) ;
          recordMap[fieldModel.name] = tmpRec ;
        }
      }
      // Initialize the row editor with the first element.
      // If only one element remaining, not much to do.
      // If more than one element, create a drop list with the remaining properties and register an event
      // with the combobox which changes the column editor of the second column corresponding to the domain of the selected item in the first column.
      var value = '' ;
      if(displayList[0]['default'])
      {
        value = displayList[0]['default'] ;
      }
      var elToInsert = displayList[0] ;
      var newRec = Ext.create('Task', {
        name: elToInsert.name,
        fixed: elToInsert.fixed,
        category: elToInsert.category,
        value: value,
        domain: domainMap[elToInsert.name][0],
        domainOpts: domainMap[elToInsert.name][1],
        description: elToInsert.description ? elToInsert.description : '',
        id: new Date().getUTCMilliseconds(),
        modelAddress: elToInsert.modelAddress,
        docAddress: '',
        leaf: ( elToInsert.properties || elToInsert.items ) ? false : true,
        editable: displayList.length > 1 ? true : false
      }) ;
      selectedNode.appendChild(newRec) ;
      var nameColModel = Ext.getCmp('mainTreeGrid').columns[0] ;
      var valColModel = Ext.getCmp('mainTreeGrid').columns[1] ;
      var origWidthOfNameCol = nameColModel.getWidth() ;
      var origWidthOfValCol = valColModel.getWidth() ;
      if(displayList.length > 1)
      {
        Ext.regModel('NewNodeComboModel', {
            fields: [
                {type: 'string', name: 'name'},
                {type: 'string', name: 'description'}
            ]
        });

        // The data store holding the states
        var newNodeStore = Ext.create('Ext.data.Store', {
            model: 'NewNodeComboModel',
            data: displayNames
        });
        var newNodeComboCfg = {
                                xtype: 'combobox',
                                editable: true,
                                store: newNodeStore ,
                                id: 'newNodeCombo',
                                displayField: 'name',
                                valueField: 'name',
                                queryMode: 'local',
                                listConfig: {
                                  getInnerTpl: function(){
                                    return '<div data-qtip="{description}">{name}</div>';
                                  }
                                }
                              } ;
        nameColModel.setEditor(newNodeComboCfg) ;
        recordToReplace = newRec ;
        var combo =  Ext.getCmp('newNodeCombo') ;
        combo.on('select', function(cb, records, eOpts){
          var fieldName = records[0].data.name ;
          // Need tempRecordForRowEditor as global (initialized in globals.js)
          tempRecordForRowEditor = Ext.getCmp('mainTreeGrid').getPlugin('rePlugin').context.record ;
          var parentNode = tempRecordForRowEditor.parentNode ;
          tempRecordForRowEditor = recordMap[fieldName] ;
          tempRecordForRowEditor.parentNode = parentNode ;
          var domainInfo = domainMap[fieldName] ;
          updateEditor(domainInfo[0], domainInfo[1]) ;
          valColModel.getEditor().setWidth(origWidthOfValCol) ;
          nameColModel.getEditor().setWidth(origWidthOfNameCol) ;
          // Set the default value for the currently selected property
          var value = tempRecordForRowEditor.data['value'] ? tempRecordForRowEditor.data['value'] : "" ;
          Ext.getCmp('mainTreeGrid').getPlugin('rePlugin').editor.form.findField('value').setValue(value) ;
          tempRecordForRowEditor.raw.value = value ;
          // Disable the value column if the property is 'fixed'
          if (recordMap[fieldName].data.fixed) {
            Ext.getCmp('mainTreeGrid').getPlugin('rePlugin').editor.form.findField('value').disable() ;
          }
          else
          {
            Ext.getCmp('mainTreeGrid').getPlugin('rePlugin').editor.form.findField('value').enable() ;
          }
        }) ;
      }
      else
      {
        nameColModel.setEditor({ xtype: 'textfield'}) ;
      }
      rowEditPlugin.startEdit(newRec, 0) ;
      //updateEditor(displayList[0].domain, displayList[0].domainOpts) ;
      valColModel.getEditor().setWidth(origWidthOfValCol) ;
      nameColModel.getEditor().setWidth(origWidthOfNameCol) ;
    }
  }
}

function generateAutoContent(domain)
{
  var coll = Ext.getCmp('collectionSetCombobox') ;
  Ext.Ajax.request(
  {
    url : 'genboree_kbs/doc/contentgen',
    timeout : 90000,
    method: 'GET',
    params:
    {
      "authenticity_token": csrf_token,
      project_id: projectId,
      collectionSet: coll,
      doc: newdocObj,
    },
    callback : function(opts, success, response)
    {
      try
      {
        var apiRespObj  = JSON.parse(response.responseText) ;
        var editedSubDoc = apiRespObj['data'] ;
        var statusObj   = apiRespObj['status'] ;
        if(response.status >= 200 && response.status < 400 && editedSubDoc)
        {
          
        }
        else
        {
          var displayMsg = "The following error was encountered while trying to generate auto content for the document '<i>" + coll + "</i>' :<br><br>" ;
          displayMsg += ( "<b>Error Code:</b> <i>" + (statusObj['statusCode'] ? statusObj['statusCode'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" ) ;
          displayMsg += ( "<b>Error Message:</b> <i>" + (statusObj['msg'] ? statusObj['msg'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" );
          displayMsg += "<br><br>Please contact a project admin to resolve this issue." ;
          Ext.Msg.alert("ERROR", displayMsg) ;
        }
      }
      catch(err)
      {
        Ext.Msg.alert('ERROR', "Bad data returned from server when trying to generate auto content for the document '<i>" + coll + "</i>'.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
      }
    }
  }) ;
}

// Recursively appends child nodes to given node
// This is required since appending nested children nodes doesn't seem to work
function insertChildNode(node, children)
{
  var ii ;
  for(ii=0; ii<children.length; ii++)
  {
    if(children[ii].children && children[ii].children.length > 0)
    {
      var subchildren = children[ii].children ;
      children[ii].children = [] ;
      var insertedNode = node.appendChild(children[ii]) ;
      insertChildNode(insertedNode, subchildren) ;
    }
    else
    {
      node.appendChild(children[ii]) ;  
    }
  }
}

// Sets some of the property specific attributes to the node obj.
// This is required when adding child properties of properties that have more than 1 child properties
//  since swapping nodes does not replace all the attributes of the node that was inserted initially.
function postEditOperation(context, recordMap, propName)
{
  context.record.data.category = recordMap[propName].data.category ;
  context.record.data.fixed = recordMap[propName].data.fixed ;
  context.record.data.description = recordMap[propName].data.description ;
  context.record.data['default'] = recordMap[propName].data['default'] ;
}

// Casts the edited values appropriately to store in the document object (newdocObj)
// This is important so that the documents can be saved without issues.
function castPropValue(domain, domainOpts, propValue, context)
{
  if(domain == 'boolean')
  {
    propValue = ( propValue == 'true' ? true : false ) ;
  }
  else if (domain == 'date') {
    var dateObj ;
    if (propValue && propValue != "") {
      dateObj = new Date(propValue) ;
    }
    else{
      dateObj = new Date() ;      
    }
    var month = parseInt(dateObj.getMonth()) + 1 ;
    propValue = dateObj.getFullYear()+'/'+month.toString()+'/'+dateObj.getDate() ;
    context.record.data.value = propValue ; // Change how it is displayed on the tree-grid
  }
  else if (domain.match(/int/i)) {
    if (propValue == null || propValue === "") {
      propValue = 0 ;
      // Set the appropriate value for range domains
      if (domainOpts && domainOpts['min'] != undefined) {
        propValue = parseInt(domainOpts['min']) ;
      }
      if (domainOpts && domainOpts['max'] != undefined) {
        propValue = parseInt(domainOpts['max']) ;
      }
    }
    
    context.record.data.value = propValue ; // Change how it is displayed on the tree-grid
  }
  else if (domain.match(/float/i)) {
    if (propValue == null || propValue === "") {
      propValue = 1.0 ;
      // Set the appropriate value for range domains
      if (domainOpts && domainOpts['min'] != undefined) {
        propValue = parseFloat(domainOpts['min']) ;
      }
      if (domainOpts && domainOpts['max'] != undefined) {
        propValue = parseFloat(domainOpts['max']) ;
      }
    }
    
    context.record.data.value = propValue ; // Change how it is displayed on the tree-grid
  }
  else if (domain == 'enum') {
    if (propValue == null || propValue == "") {
      propValue = domainOpts['values'][0] ;
    }
    context.record.data.value = propValue ; // Change how it is displayed on the tree-grid
  }
  else
  {
    // No-op
  }
  return propValue ;
}

// Updates the column editor for the second column based on the domain info of the first column
// For special domains such as fileUrl, displays a dialog/window for uploading file
function updateEditor(fieldDomain, fieldDomainOpts)
{
  if(fieldDomain == "posInt" || fieldDomain == "negInt" || fieldDomain == "int" || fieldDomain == 'pmid')
  {
    var edConf = { xtype : 'numberfield', step: 1, allowDecimals: false, allowExponential: false, allowBlank: true, minWidth: editorConfigHash['int']['minWidth'], maxWidth: editorConfigHash['int']['maxWidth'] } ;
    if(fieldDomainOpts && fieldDomainOpts["min"] != undefined)
    {
      edConf.minValue = fieldDomainOpts["min"] ;
    }
    if(fieldDomainOpts && fieldDomainOpts["max"] != undefined)
    {
      edConf.maxValue = fieldDomainOpts["max"] ;
    }
    // Set min/max valued for posInt/negInt
    if(fieldDomain == 'posInt')
    {
      edConf.minValue = 0 ;
    }
    if(fieldDomain == 'negInt')
    {
      edConf.maxValue = 0 ;
    }
    Ext.getCmp('mainTreeGrid').columns[1].setEditor(edConf) ;
  }
  else if(fieldDomain == "posFloat" || fieldDomain == "negFloat" || fieldDomain == "float")
  {
    var res  = 0.001 ;
    var prec = 4 ;
    if(fieldDomainOpts && fieldDomainOpts["res"] != undefined)
    {
      res = fieldDomainOpts["res"] ;
    }
    if(fieldDomainOpts && fieldDomainOpts["prec"] != undefined)
    {
      prec = fieldDomainOpts["prec"] ;
    }
    var edConf = { xtype : 'numberfield', decimalPrecision: prec, step: res, allowBlank: true, minWidth: editorConfigHash['float']['minWidth'], maxWidth: editorConfigHash['float']['maxWidth'] } ;
    if(fieldDomainOpts && fieldDomainOpts["min"] != undefined)
    {
      edConf.minValue = fieldDomainOpts["min"] ;
    }
    if(fieldDomainOpts && fieldDomainOpts["max"] != undefined)
    {
      edConf.maxValue = fieldDomainOpts["max"] ;
    }
    // Set min/max valued for posFloat/negFloat
    if(fieldDomain == 'posFloat')
    {
      edConf.minValue = 0.0 ;
    }
    if(fieldDomain == 'negFloat')
    {
      edConf.maxValue = 0.0 ;
    }
    Ext.getCmp('mainTreeGrid').columns[1].setEditor(edConf) ;
  }
  else if(fieldDomain == "date")
  {
    Ext.getCmp('mainTreeGrid').columns[1].setEditor({ xtype: 'datefield', emptyText: 'YYYY/MM/DD', format: "Y/m/d", altFormats: "Y-m-d|m d Y",  width: editorConfigHash['date']['width'] }) ;
  }
  else if(fieldDomain == "regexp")
  {
    Ext.getCmp('mainTreeGrid').columns[1].setEditor({ xtype: 'textfield', regex: new RegExp(fieldDomainOpts["pattern"]) }) ;
  }
  else if (fieldDomain == 'measurement') {
    Ext.getCmp('mainTreeGrid').columns[1].setEditor({ xtype: 'textfield', emptyText: 'Number Units (Example: 20 ml)', regex:  /^((?:-|\+)?[0-9]*\.?[0-9]+(e(?:-|\+)?[0-9]+)?)\s+(?:([A-Z]|'|#|%|"|1)+)$/i }) ;
  }
  else if(fieldDomain == "enum")
  {
    var fieldOpts = fieldDomainOpts['values'] ;
    var enumVals = []  ;
    var ii ;
    for(ii=0; ii<fieldOpts.length; ii++)
    {
      enumVals.push(fieldOpts[ii].trim()) ;
    }
    Ext.getCmp('mainTreeGrid').columns[1].setEditor({ xtype: 'combobox', editable: false, store: enumVals, minWidth: editorConfigHash['enum']['minWidth'], maxWidth: editorConfigHash['enum']['maxWidth'] }) ;
  }
  else if(fieldDomain == 'url')
  {
    Ext.getCmp('mainTreeGrid').columns[1].setEditor({ xtype: 'textfield' }) ;
  }
  else if (fieldDomain == 'fileUrl')
  {
    Ext.getCmp('mainTreeGrid').columns[1].setEditor({ xtype: 'textfield' }) ;
    if (editModeValue) {
      initFileUploadDialog() ;  
    }
  }
  else if(fieldDomain == 'boolean')
  {
    Ext.getCmp('mainTreeGrid').columns[1].setEditor({xtype: 'checkbox', width: editorConfigHash['boolean']['width']}) ;
  }
  else if (fieldDomain == 'bioportalTerm') {
    Ext.getCmp('mainTreeGrid').columns[1].setEditor({
      xtype       : 'combo',
      id          : 'bioPSearchBox',
      width       : 200,
      maxHeight   : 20,
      minChars    : 3,
      autoScroll  : true,
      autoSelect  : false,
      checkChangeBuffer : 100,
      queryDelay  : 250,
      hideTrigger : true,
      matchFieldWidth : false,
      emptyText: 'Type 3 chars to start search...',
      pickerAlign : 'tl-bl?',
      typeAhead   : false,
      queryMode   : 'remote',
      queryParam  : 'searchStr',
      displayField : 'prefLabel',
      valueField  : 'prefLabel',
      listConfig  : 
      {
        emptyText   : 'Search by ontology term...',
        loadingText : '( Searching )',
        border      : 1,
        minWidth    : 100,
        loadMask     : true,
        getInnerTpl: function(){
          return "<div id=\"{divId}\" data-tooltipcontent=\"<b>definition</b>: {definition}</br><b>synonym</b>: {synonym}</br>\" class=\"bioportalClass\" >{prefLabel}</div>" ;
        },
        listeners: {
          'beforeitemmouseenter': function(){ 
            if (!bioportalToolTipsAdded) {
              var els = Ext.select('.bioportalClass').elements ;
              var ii ;
              for(ii=0; ii<els.length; ii++)
              {
                var el = els[ii] ;
                Ext.tip.QuickTipManager.register({
                  target: el.id,
                  text: el.dataset.tooltipcontent,
                  dismissDelay: 1000000
                }) ;
              }
              bioportalToolTipsAdded = true ;
              this.refresh() ;
            }
          }
          
        }
      },
      valueNotFoundText : '(No matching docs)',
      listeners: {
        'beforequery': function(queryPlan, eOpts) {
            // BUG FIX: Without this, the search can show WRONG RESULTS. i.e. show results for the older,
            //   first search(es) that use only a few letters (because they return last!) and not those that
            //   are longer and return faster. i.e. Successive queries can return FASTER than older ones because
            //   (a) the search is more specific (more letters!), (b) relevant disk pages likely
            //   to be in memory on server now.
            Ext.Ajax.abort() ; // aborts last Ajax call.
            // May need to get medieval and cancel all, for safety:
            // Ext.Ajax.abortAll() ;
            this.store.removeAll() ;
          }
      }
    }) ;
    bindBioPortalStore(fieldDomainOpts['url']) ;
  }
  else
  {
    Ext.getCmp('mainTreeGrid').columns[1].setEditor({ xtype: 'textfield' }) ;
  }
}


// Creates and binds store to the bioportal combo box
function bindBioPortalStore(url)
{
  var retVal = false ;
  // Remove items from existing store, if any
  if(bioportalStoreData && bioportalStoreData.removeAll)
  {
    bioportalStoreData.removeAll() ;
  }
  var searchModelName = ( 'BioPSearchModel-' + (new Date).getTime() + "-" + Math.ceil(Math.random() * 1024 * 1024) ) ;
  Ext.define(searchModelName, {
    extend : 'Ext.data.Model',
    fields : [ 'prefLabel', 'definition', 'synonym', 'divId' ]
  }) ;
  // Create new JsonStore backed by ajax proxy
  bioportalStoreData = new Ext.data.JsonStore(
  {
    storeId : 'bioPSearchStore',
    model : searchModelName,
    proxy :
    {
      type    : 'ajax',
      url     : 'genboree_kbs/doc/biopsearch',
      timeout : 90000,
      reader :
      {
        type  : 'json',
      },
      // ExtJs ajax proxy can send standard things like page, limit, start/end index, filter, and even extra params
      filterParam : 'searchStr',
      extraParams :
      {
        url  : url,
        project_id : projectId,
        "authenticity_token"  : csrf_token
      }
    },
    listeners: {
      'datachanged': function(thisObj, eOpts){
        bioportalToolTipsAdded = false ;
      }
    }
  }) ;
  // Bind the search box to this new store
  var searchBox = Ext.getCmp('bioPSearchBox') ;
  searchBox.bindStore(bioportalStoreData) ;
  searchBox.enable() ;
  retVal = true ;
  return retVal ;
}

// Displays dialog for uploading file from user's machine
// Upon submission of form, uploads file to server (rails controller)
function displayFileUrlDialog()
{
  Ext.create('Ext.window.Window', {
    title: 'Upload File',
    height: 145,
    width: 355,
    id: 'fileUrlDisplayWindow',
    modal: true,
    listeners: {
      'close': function(){
        var rowEditorPlgn = Ext.getCmp('mainTreeGrid').getPlugin('rePlugin') ;
        rowEditorPlgn.cancelEdit() ;
      }
    },
    layout: 'fit',
    items: {  
      xtype: 'form',
      frame: true,
      items:
      [
        {
          xtype: 'filefield',
          name: 'file',
          fieldLabel: '<b>File</b>',
          labelWidth: 100,
          allowBlank: false,
          msgTarget: 'side',
          anchor: '100%',
          buttonText: 'Select File...'
        },
        {
          xtype: 'textfield',
          fieldLabel: '<b>Folder</b>',
          allowBlank: true,
          id: 'displayTargetFolderSelector',
          value: 'KBFiles'
        }
      ],
      buttons:
      [
        {
          text: 'Upload',
          handler: function() {
            var form = this.up('form').getForm();
            if(form.isValid()){
              var fileBaseName = form.monitor.items.items[0].rawValue.split("\\").reverse()[0] ;
              var folder = form.monitor.items.items[1].rawValue
              // Contruct the action URL with all the form elements EXCEPT the file itself which we will de-encode using Event Machine. 
              var actionUrl = 'genboree_kbs/doc/uploadfile?'+ 'authenticity_token='+encodeURIComponent(csrf_token)+'&kbDb='+escape(kbDb)+'&project_id='+escape(projectId)+'&fileBaseName='+escape(fileBaseName)+'&gbGroup='+escape(gbGroup)+'&displayTargetFolderSelector='+escape(folder)  ;
              form.submit({
                url: actionUrl,
                waitMsg: 'Uploading your file...',
                success: function(aa, bb) {
                  Ext.Msg.alert('Success', 'Your file has been accepted.</br><b>Upload is in progress.</b></br>If your file is large, it may take some time for the upload to complete.</br></br><b>NOTE:</b> Please save the document to commit the changes.');
                  setFileUrlValue(aa) ;
                  Ext.getCmp('fileUrlDisplayWindow').close() ;
                },
                failure: function(){
                  Ext.Msg.alert('ERROR', 'Your file could not be uploaded. Please try again or contact the project administrator to try to resolve the issue.');
                }
              });
            }
          }
        }
      ]
    }
  }).show();
  
}

// Programtically sets the value for the 'Value' column in the row editor plugin after file is uploaded
// Completes the row editing operation after the value is set. 
function setFileUrlValue(formObj)
{
  var formItems = formObj.monitor.items.items ;
  var file ;
  var folder = null ;
  var ii ;
  for(ii=0; ii<formItems.length; ii++)
  {
    if (formItems[ii].name == 'file') {
      file = formItems[ii].value ;
    }
    else if (formItems[ii].name == 'displayTargetFolderSelector-inputEl') {
      folder = formItems[ii].value ;
    }
    else{
      // Do nothing
    }
  }
  var filePath ;
  var fileName = file.split("\\") ;
  fileName = fileName[fileName.length-1] ;
  if (folder != null && folder != '') {
    filePath = escape(folder.replace(/^\//, '').replace(/\/$/, '')) + '/' + escape(fileName) ;  
  }
  else{
    filePath = escape(fileName) ;
  }
  var fileUrlVal = 'http://'+gbHost+'/REST/v1/grp/'+escape(gbGroup)+'/db/'+escape(kbDb)+'/file/'+filePath ;
  var rowEditorPlgn = Ext.getCmp('mainTreeGrid').getPlugin('rePlugin') ;
  rowEditorPlgn.editor.items.items[1].setValue(fileUrlVal) ;
  rowEditorPlgn.completeEdit() ;
}

// Initializes rendering of file upload dialog
// Ask the user if a file is to be uploaded otherwise reverts back to the row editing plugin for manually entering a URL
function initFileUploadDialog()
{
  Ext.Msg.show({
    title: "Select File Option",
    msg: 'Would you like to upload a file from your machine or manually enter a URL?',
    buttonText: {yes: 'Upload File', no: 'Enter URL'},
    id: 'initFileUploadDialog',
    height: 130,
    width: 400,
    scope: this,
    fn: function(btn, text, opt)
    {
      if(btn == 'yes')
      {
        if (kbDb == null || kbDb == '' || kbDb == 'NULL')
        {
          Ext.Msg.alert('NO Database', 'This KB is not associated with any database and therefore files cannot be uploaded. You can still enter URLs manually which are publicly accessible.</br></br>If you would like to have the file upload functionality, please contact a project admin to set up a database for this kb.') ;  
        }
        else
        {
          checkExistenceOfKbDb('fileUrl') ;
        }
      }
      else if(btn == 'no')
      {
      }
      else if (btn == 'cancel') {
        Ext.getCmp('mainTreeGrid').getPlugin('rePlugin').cancelEdit() ;
      }
      else{
        // No-op
      }
    }
  }) ;
}
