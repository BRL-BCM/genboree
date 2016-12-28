
// Updates the column editor for the second column based on the domain info of the first column
function updateEditor(fieldDomain, fieldDomainOpts)
{
  // DOMAIN: int, posInt, negINt
  if(fieldDomain == "posInt" || fieldDomain == "negInt" || fieldDomain == "int")
  {
    var edConf = { xtype : 'numberfield', step: 1, allowDecimals: false, allowExponential: false, allowBlank: false, minWidth: editorConfigHash['int']['minWidth'], maxWidth: editorConfigHash['int']['maxWidth'] } ;
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
  // DOMAIN: float, posFloat, negFloat
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
    var edConf = { xtype : 'numberfield', decimalPrecision: prec, step: res, allowBlank: false, minWidth: editorConfigHash['float']['minWidth'], maxWidth: editorConfigHash['float']['maxWidth'] } ;
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
  // DOMAIN: date
  else if(fieldDomain == "date")
  {
    Ext.getCmp('mainTreeGrid').columns[1].setEditor({ xtype: 'datefield', format: "Y/m/d", altFormats: "Y-m-d|M d Y", value: fieldDefaultVal, width: editorConfigHash['date']['width'] }) ;
  }
  // DOMAIN: regexp
  else if(fieldDomain == "regexp")
  {
    Ext.getCmp('mainTreeGrid').columns[1].setEditor({ xtype: 'textfield', value: fieldDomainOpts['value'], regex: new RegExp(fieldDomainOpts["pattern"]) }) ;
  }
  // DOMAIN: enum
  else if(fieldDomain == "enum")
  {
    Ext.getCmp('mainTreeGrid').columns[1].setEditor({ xtype: 'combobox', editable: false, store: fieldDomainOpts["values"], minWidth: editorConfigHash['enum']['minWidth'], maxWidth: editorConfigHash['enum']['maxWidth'] }) ;
  }
  else if(fieldDomain == 'url')
  {
    Ext.getCmp('mainTreeGrid').columns[1].setEditor({ xtype: 'textfield' }) ;
  }
  else if(fieldDomain == 'boolean')
  {
    Ext.getCmp('mainTreeGrid').columns[1].setEditor({xtype: 'checkbox', width: editorConfigHash['boolean']['width']}) ;
  }
  else
  {
    Ext.getCmp('mainTreeGrid').columns[1].setEditor({ xtype: 'textfield' }) ;
  }
}

// Helper function used by many functions to extract domain info of a property
function getDomainInfo(modelEl)
{
  var domainToUse = modelEl.domain || '' ;
  var domainOptsToUse = '' ;
  if(domainToUse.match(/^enum/))
  {
    domainToUse = "enum" ;
    domainOptsToUse = {"values": modelEl.domain.replace('enum(', '').replace(')', '').split(',')} ;
  }
  else if(domainToUse.match(/^regexp/))
  {
    domainToUse = "regexp" ;
    domainOptsToUse = {"pattern": modelEl.domain.replace('regexp(', '').replace(')', '')} ;
  }
  else if (domainToUse.match(/^intRange/)) {
    domainToUse = "int" ;
    var minMax = modelEl.domain.replace('intRange(', '').replace(')', '').split(',') ;
    var min = ( minMax[0] == "" ? undefined : minMax[0] );
    var max = ( minMax[1] == "" ? undefined : minMax[1] ) ;
    domainOptsToUse = { "min": min, "max": max } ;
  }
  else if (domainToUse.match(/^floatRange/)) {
    domainToUse = "float" ;
    var minMax = modelEl.domain.replace('floatRange(', '').replace(')', '').split(',') ;
    var min = ( minMax[0] == "" ? undefined : minMax[0] ) ;
    var max = ( minMax[1] == "" ? undefined : minMax[1] ) ;
    domainOptsToUse = { "min": min, "max": max } ;
  }
  {
    // Nothing to do
  }
  return [domainToUse, domainOptsToUse] ;
}


// Adds a child record to a node (if there are sub-properties available to add)
// Registered to the Add Child btn in the toolbar
function addChildNode()
{
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
      var newRec = Ext.create('Task', {
        name: propToInsert.name,
        value: value,
        id: new Date().getUTCMilliseconds(),
        modelAddress: propToInsert,
        docAddress: '',
        description: propToInsert.description ? propToInsert.description : '',
        leaf: false,
        editable: false,
        fixed: propToInsert.fixed,
        category: propToInsert.category
      }) ;
      selectedNode.appendChild(newRec) ;
      var nameColModel = Ext.getCmp('mainTreeGrid').columns[0] ;
      var valColModel = Ext.getCmp('mainTreeGrid').columns[1] ;
      var origWidthOfNameCol = nameColModel.getWidth() ;
      var origWidthOfValCol = valColModel.getWidth() ;
      Ext.getCmp('mainTreeGrid').columns[0].setEditor({ xtype: 'textfield'}) ;
      Ext.getCmp('mainTreeGrid').getPlugin('rePlugin').startEdit(newRec, 0) ;
      var domainEls = getDomainInfo(propToInsert) ;
      updateEditor(domainEls[0], domainEls[1]) ;
      valColModel.getEditor().setWidth(origWidthOfValCol) ;
      nameColModel.getEditor().setWidth(origWidthOfNameCol) ;
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
          //displayNames.push(fieldModel.name) ;
          var tmpRec = Ext.create('Task', {
            name: fieldModel.name,
            value: fieldModel['default'] ? fieldModel['default'] : '',
            id: new Date().getUTCMilliseconds(),
            modelAddress: fieldModel,
            fixed: fieldModel.fixed,
            description: fieldModel.description ? fieldModel.description : '',
            category: fieldModel.category,
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
      var newRec = Ext.create('Task', {
        name: displayList[0].name,
        fixed: displayList[0].fixed,
        category: displayList[0].category,
        value: value,
        description: displayList[0].description ? displayList[0].description : '',
        id: new Date().getUTCMilliseconds(),
        modelAddress: displayList[0].modelAddress,
        docAddress: '',
        leaf: ( displayList[0].properties || displayList[0].items ) ? false : true,
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
          Ext.getCmp('mainTreeGrid').getPlugin('rePlugin').context.record = recordMap[fieldName] ;
          var domainInfo = domainMap[fieldName] ;
          updateEditor(domainInfo[0], domainInfo[1]) ;
          valColModel.getEditor().setWidth(origWidthOfValCol) ;
          nameColModel.getEditor().setWidth(origWidthOfNameCol) ;
        }) ;
      }
      else
      {
        Ext.getCmp('mainTreeGrid').columns[0].setEditor({ xtype: 'textfield'}) ;
      }
      Ext.getCmp('mainTreeGrid').getPlugin('rePlugin').startEdit(newRec, 0) ;
      updateEditor(displayList[0].domain, displayList[0].domainOpts) ;
      valColModel.getEditor().setWidth(origWidthOfValCol) ;
      nameColModel.getEditor().setWidth(origWidthOfNameCol) ;
    }
  }
}

// Removes a node and its children nodes(if present)
// Registered to the Remove btn on the tool bar
function removeNode()
{
  var selectedNode = Ext.getCmp('mainTreeGrid').getSelectionModel().getSelection()[0] ;
  var ii ;
  var idx ;
  // Remove the property from the document as well
  if(selectedNode.parentNode.data.docAddress.properties)
  {
    delete selectedNode.parentNode.data.docAddress.properties[selectedNode.data.name] ;
  }
  else
  {
    // Get the index of the node in the list
    var childNodes = selectedNode.parentNode.childNodes ;
    for(ii=0; ii<childNodes.length; ii++)
    {
      if(childNodes[ii].id == selectedNode.id)
      {
        idx = ii ;
        break ;
      }
    }
    selectedNode.parentNode.data.docAddress.items.splice(idx, 1) ;
  }
  selectedNode.removeAll() ;
  selectedNode.remove() ;
  // disable the add and remove button since nothing will be selected at this point.
  var btns = Ext.getCmp('mainTreeGrid').getDockedItems()[1].items.items ;
  var addChild ;
  var remove ;
  for(ii=0; ii<btns.length; ii++)
  {
    if(btns[ii].itemId == 'addChildRow')
    {
      addChild = btns[ii] ;
    }
    else if(btns[ii].itemId == 'removeRow')
    {
      remove = btns[ii] ;
    }
    else
    {
      // Nothing to do
    }
  }
  addChild.disable() ;
  remove.disable() ;
}

function removeFromSearchBox(identifier, clearBox)
{
  var searchBox = Ext.getCmp('searchComboBox') ;
  if(clearBox)
  {
    searchBox.setValue("") ;
  }
  searchBox.store.removeAt(searchBox.store.find('value', identifier)) ;
}

function addToSearchBox(identifier, setToNewValue)
{
  var searchBox = Ext.getCmp('searchComboBox') ;
  searchBox.store.add({'value': identifier}) ;
  if(setToNewValue)
  {
    searchBox.setValue(identifier) ;
  }
}

// Enables or disables the addChild btn basedon if there are any available sub-properties
function toggleAddChildBtn(record, addChildBtn)
{
  if(record.data.modelAddress.properties)
  {
    var modProp = record.data.modelAddress.properties ;
    var docAddress = record.data.docAddress ;
    if(!docAddress || !docAddress.properties) // document has no children
    {
      addChildBtn.enable() ;
    }
    else // loop over all model properties. If even one is missing in the doc, enable the btn
    {
      var ii ;
      var docProp = docAddress.properties ;
      var enableBtn = false ;
      for(ii=0; ii<modProp.length; ii++)
      {
        if(!docProp[modProp[ii].name])
        {
          enableBtn = true ;
          break ;
        }
      }
      if(enableBtn)
      {
        addChildBtn.enable() ;
      }
      else
      {
        addChildBtn.disable() ;
      }
    }

  }
  else if(record.data.modelAddress.items)
  {
    addChildBtn.enable() ;
  }
}

// Create the appropriate structure from the new document based on the model for the tree-grid
function createViewableDoc(docModelObj, newdocObj)
{
  // To-do: replace model[0] with Andrew's updated response
  var identifier = docModelObj.name ;
  var identifierValue = newdocObj[identifier].value ;
  var modelProperties = docModelObj.properties ;
  var modelItems = docModelObj.items ;
  var newdocProperties = null ;
  var newdocItems = null ;
  var children = [] ;
  var ii, jj ;
  // The top level node will have either items or properties. Cannot have both (for now)
  if(modelProperties)
  {
    var rootProp = docModelObj ;
    newdocProperties = newdocObj[identifier].properties ;
    var el ;
    for(ii=0; ii<modelProperties.length; ii++)
    {
      el = modelProperties[ii] ;
      if(!newdocProperties[el.name])
      {
        continue ;
      }
      children.push(constructChildrenObj(el, newdocProperties[el.name])) ;
    }
    var domainEls = getDomainInfo(rootProp) ;
    var domain = domainEls[0] ;
    var domainOpts = domainEls[1] ;
    return {
      name: identifier,
      value: identifierValue,
      category: true, // make the identifier bold
      iconCls: 'task-folder',
      expanded: true,
      children: children,
      identifier: true,
      domain: domain,
      domainOpts: domainOpts,
      required: true,
      description: rootProp.description,
      docAddress: newdocObj[identifier],
      modelAddress: rootProp
    } ;
  }
  else if(modelItems)
  {
    var items = newdocObj[identifier].items ;
    // items must be singly rooted
    if(items.length != 1)
    {
      Ext.Msg.Alert('Status', 'Error: Items MUST be singly rooted. '+identifier+' is either multi-rooted or does not have a root property. This is a bug with the model of this collection.') ;
    }
    var rootProp = modelItems[0] ;
    var domainElsOfRoot = getDomainInfo(rootProp) ;
    var domainOfRoot = domainElsOfRoot[0] ;
    var domainOptsOfRoot = domainElsOfRoot[1] ;
    for(ii=0; ii<items.length; ii++)
    {
      var subchildren = [] ;
      var item = items[ii] ;
      if(!item[rootProp.name])
      {
        continue ;
      }
      var itemProps = item[rootProp.name].properties ;
      var rootPropValue = item[rootProp.name].value ;
      for(jj=0; jj<rootProp.properties.length; jj++)
      {
        var modelEl = rootProp.properties[jj] ;
        if(!itemProps[modelEl.name])
        {
          continue ;
        }
        subchildren.push(constructChildrenObj(modelEl, itemProps[modelEl.name])) ;
      }
      children.push({ name: rootProp.name, value: rootPropValue, fixed: rootProp.fixed, category: rootProp.category, iconCls: 'task-folder', domain: domainOfRoot, required: rootProp.required, children: subchildren, docAddress: item[rootProp.name], domainOpts: domainOptsOfRoot, modelAddress: rootProp }) ;
    }
    var rootEl = docModelObj ;
    var domainEls = getDomainInfo(rootEl) ;
    var domain = domainEls[0] ;
    var domainOpts = domainEls[1] ;
    return {
      name: identifier,
      value: identifierValue,
      category: true,// make the identifier bold
      iconCls: 'task-folder',
      domain: domain,
      domainOpts: domainOpts,
      children: children,
      description: rootEl.description,
      docAddress: newdocProperty[identifer],
      required: true,
      modelAddress: rootEl
    } ;
  }
  else
  {
    Ext.Msg.alert('Status', 'Error: Model contains neither items nor property for identifier.') ;
  }

}

// Recursive function to traverse nested data and construct children for the root node
function constructChildrenObj(el, newdocProperty)
{
  var ii, jj ;
  var children = [] ;
  var domainEls = getDomainInfo(el) ;
  var domain = domainEls[0] ;
  var domainOpts = domainEls[1] ;
  if(el.properties)
  {
    for(ii=0; ii<el.properties.length; ii++)
    {
      if(!newdocProperty.properties || !newdocProperty.properties[el.properties[ii].name])
      {
        continue ;
      }
      children.push(constructChildrenObj(el.properties[ii], newdocProperty.properties[el.properties[ii].name])) ;
    }
    var retObj = { name: el.name, value: newdocProperty.value, description: el.description, category: el.category, iconCls: 'task-folder', domain: domain, children: children, docAddress: newdocProperty, domainOpts: domainOpts, required: el.required, modelAddress: el, fixed: el.fixed } ;
    return retObj ;
  }
  else if(el.items)
  {
    var items = newdocProperty.items ;
    // items must be singly rooted
    if(el.items.length != 1)
    {
      Ext.Msg.Alert('Status', 'Error: Items MUST be singly rooted. '+el.name+' is either multi-rooted or does not have a root property. This is a bug with the model of this collection.') ;
    }
    var rootProp = el.items[0] ;
    var domainElsOfRoot = getDomainInfo(rootProp) ;
    var domainOfRoot = domainElsOfRoot[0] ;
    var domainOptsOfRoot = domainElsOfRoot[1] ;
    for(ii=0; ii<items.length; ii++)
    {
      var subchildren = [] ;
      var item = items[ii] ;
      if(!item[rootProp.name])
      {
        continue ;
      }
      var itemProps = item[rootProp.name].properties ;
      var rootPropValue = item[rootProp.name].value ;
      if (rootProp.properties) {
        for(jj=0; jj<rootProp.properties.length; jj++)
        {
          var modelEl = rootProp.properties[jj] ;
          if(!itemProps[modelEl.name])
          {
            continue ;
          }
          subchildren.push(constructChildrenObj(modelEl, itemProps[modelEl.name])) ;
        }
      }
      var nodeObj = { name: rootProp.name, value: rootPropValue, description: rootProp.description, fixed: rootProp.fixed, category: rootProp.category, domain: domainOfRoot, required: rootProp.required, children: subchildren, docAddress: item[rootProp.name], domainOpts: domainOptsOfRoot, modelAddress: rootProp } ;
      if (rootProp.properties) {
        nodeObj['iconCls'] = 'task-folder' ;
      }
      else{
        nodeObj['iconCls'] = 'task' ;
        nodeObj['leaf'] = true ;
      }
      children.push(nodeObj) ;
    }
    return { name: el.name, value: newdocProperty.value, fixed: el.fixed, description: el.description, category: el.category, iconCls: 'task-folder', domain: domain, children: children, docAddress: newdocProperty, domainOpts: domainOpts, required: el.required, modelAddress: el } ;
  }
  else
  {
    return {
              name: el.name,
              value: newdocProperty.value,
              category: el.category,
              leaf: true,
              iconCls: 'task',
              domain: domain,
              docAddress: newdocProperty,
              description: el.description,
              domainOpts: domainOpts,
              required: el.required,
              fixed: el.fixed
            } ;
  }
}


function toggleNodeOperBtn(enable)
{
  var btns = Ext.getCmp('mainTreeGrid').getDockedItems()[1].items.items ;
  var ii ;
  var addChild ;
  var remove ;
  var reorder ;
  var save ;
  for(ii=0; ii<btns.length; ii++)
  {
    if(btns[ii].itemId == 'addChildRow')
    {
      addChild = btns[ii] ;
    }
    else if(btns[ii].itemId == 'removeRow')
    {
      remove = btns[ii] ;
    }
    else if(btns[ii].itemId == 'saveDoc')
    {
      save = btns[ii] ;
    }
    else if(btns[ii].itemId == 'reorder')
    {
      reorder = btns[ii] ;
    }
    else
    {
      // Nothing to do
    }
  }
  if(enable)
  {
    if(documentEdited)
    {
      save.enable() ;
    }
    if(selectedRecord)
    {
      remove.enable() ;
      // Check if the addChild btn can be enabled
      if(selectedRecord.raw.leaf)
      {
        addChild.disable() ;
      }
      else
      {
        toggleAddChildBtn(selectedRecord, addChild) ; // defined in misc.js
      }
      // Check if the reorder btn can be enabled
      if(selectedRecord.parentNode && selectedRecord.parentNode.data.docAddress.items && selectedRecord.parentNode.data.docAddress.items.length > 1)
      {
        reorder.enable() ;
      }
      else
      {
        reorder.disable() ;
      }
    }
  }
  else
  {
    addChild.disable() ;
    remove.disable() ;
    save.disable() ;
    reorder.disable() ;
  }
}

// Gets the index of the selected node/record in the parent node items list
// Useful for shuffling nodes in the tree/document
function getSelectedRecordIndex(selectedRecord)
{
  var childNodes = selectedRecord.parentNode.childNodes ;
  var ii, idx ;
  for(ii=0; ii<childNodes.length; ii++)
  {
    if(childNodes[ii].id == selectedRecord.id)
    {
      idx = ii ;
      break ;
    }
  }
  return idx ;
}

// propvides functionality to reorder items in an items list
// Only available if there are at least 2 items in the list
// Registered to the reorder btn on the grid toolbar
function reorderItems(type, selectedRecord)
{
  var idx = getSelectedRecordIndex(selectedRecord) ;
  documentEdited = true ;
  var parentNode = selectedRecord.parentNode ;
  if(type == 'Move to bottom')
  {
    // This shuffles the tree structure
    parentNode.removeChild(selectedRecord) ;
    parentNode.insertChild(parentNode.childNodes.length, selectedRecord) ;
    // Now shuffle the document
    var itemToShuffle = parentNode.data.docAddress.items[idx] ;
    parentNode.data.docAddress.items.splice(idx, 1) ;
    parentNode.data.docAddress.items.push(itemToShuffle) ;
  }
  else if(type == 'Move to top')
  {
    parentNode.removeChild(selectedRecord) ;
    parentNode.insertBefore(selectedRecord, parentNode.childNodes[0]) ;
    // Now shuffle the document
    var itemToShuffle = parentNode.data.docAddress.items[idx] ;
    parentNode.data.docAddress.items.splice(idx, 1) ;
    parentNode.data.docAddress.items.splice(0, 0, itemToShuffle) ;
  }
  else if(type == 'Move one record down')
  {
    parentNode.removeChild(selectedRecord) ;
    parentNode.insertChild(idx+1, selectedRecord) ;
    // Now shuffle the document
    var itemToShuffle = parentNode.data.docAddress.items[idx] ;
    parentNode.data.docAddress.items.splice(idx, 1) ;
    parentNode.data.docAddress.items.splice(idx+1, 0, itemToShuffle) ;
  }
  else // Move one record up
  {
    parentNode.removeChild(selectedRecord) ;
    parentNode.insertChild(idx-1, selectedRecord) ;
    // Now shuffle the document
    var itemToShuffle = parentNode.data.docAddress.items[idx] ;
    parentNode.data.docAddress.items.splice(idx, 1) ;
    parentNode.data.docAddress.items.splice(idx-1, 0, itemToShuffle) ;
  }
  // Enable the save btn
  toggleBtn('saveDoc', 'enable') ;
  // Disable the add and remove btns
  toggleBtn('addChildRow', 'disable') ;
  toggleBtn('removeRow', 'disable') ;
  toggleBtn('reorder', 'disable') ;
}

// Solicits identifier name of new doc from user and creates a template document for the currently loaded model
function createNewDocument()
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
          var selModel = Ext.getCmp('manageDocsGrid').getSelectionModel() ;
          selModel.deselect(selModel.store.data.items[0]) ;
          selModel.select(selModel.store.data.items[1]) ;
        }
      }
    }) ;
  }
  else
  {
    solicitNameOfNewDoc() ;
  }
}

// Helper function for createNewDocument()
// If user gives the go-ahead for starting a new document, the currently loaded document (if any) will be nuked
function solicitNameOfNewDoc()
{
  Ext.Msg.show({
    title: "Create New Document",
    msg: 'Enter the identifier for a new document in the <i>'+Ext.getCmp('collectionSetCombobox').value+'</i> collection:',
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
        if(text == '')
        {
          msg = "Identifier cannot be blank for a document" ;
          conditionSatisfied = false ;
        }
        else
        {
          var domainEls = getDomainInfo(rootProp) ;
          var domain = domainEls[0] ;
          var domainOpts = domainEls[1] ;
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
              collectionSet: Ext.getCmp('collectionSetCombobox').value
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
      else
      {
        selModel.deselect(selModel.store.data.items[0]) ;
        // If there was no document loaded, go back to the previous state
        if(!newdocObj)
        {
          if (!Ext.getCmp('modelTreeGrid')) {
            disableEditDelete() ;
            Ext.getCmp('mainTreeGrid').setTitle('Edit Mode: OFF') ;
            editModeValue = false ; // This is returned from the 'before edit' event of the row plugin.
            toggleNodeOperBtn(false) ;
          }
        }
        else
        {
          selModel.select(selModel.store.data.items[1]) ;
        }
        // Reselect the model view if we came from there
        if (Ext.getCmp('modelTreeGrid')) {
          Ext.getCmp('manageModelsGrid').getView().select(0) ;
        }
      }
    }
  }) ;
}

function initNewDoc(text, selModel)
{
  // Its possible we are coming from the 'model grid' view.
  // In this case, destroy the model grid and reinitialize the editor tree
  destroyModelTableGrid() ;
  destroyModelTree() ;
  if(!Ext.getCmp('mainTreeGrid'))
  {
    initTreeGrid() ;
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
  registerQtips() ;
  freshDocument = true ; // global variable for differentiating between document loaded from db and a new document.
  selModel.deselect(selModel.store.data.items[0]) ;
  // If there was no document loaded, go back to the previous state
  if(!newdocObj)
  {
    disableEditDelete() ;
    Ext.getCmp('mainTreeGrid').setTitle('Edit Mode: OFF') ;
    editModeValue = false ; // This is returned from the 'before edit' event of the row plugin.
    toggleNodeOperBtn(false) ;
  }
  else
  {
    selModel.select(selModel.store.data.items[1]) ;
  }
  enableEditDelete() ;
  // Enable the save btn
  toggleBtn('saveDoc', 'enable') ;
  // disable the get url btn
  toggleBtn('urlBtn', 'disable') ;
  toggleBtn('downloadBtn', 'enable') ;
  toggleDownloadType('JSON', 'enable') ;
  toggleDownloadType('Tabbed - Full Property Names', 'enable') ;
  toggleDownloadType('Tabbed - Compact Property Names', 'enable') ;
  documentEdited = true ;
  originalDocumentIdentifier = null ;
  currentCollection = Ext.getCmp('collectionSetCombobox').value ;
  Ext.getCmp('searchComboBox').enable() ;
  Ext.getCmp('mainTreeGrid').setTitle(getModifiedTitle(true)) ;
}

// Helper function for createNewDocument()
function createTemplateDoc(text)
{
  var modelObj = docModel ;
  var rootProp = modelObj ;
  var identifierProp = rootProp.name ;
  newdocObj = {} ;
  newdocObj[identifierProp] = { "value": text }  ;
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
        var subpropName = subprop.name ;
        var domainEls = getDomainInfo(subprop) ;
        var domain = domainEls[0] ;
        var domainOpts = domainEls[1] ;
        var value = subprop['default'] ? subprop['default'] : returnDefaultDomainValue(domain) ;
        if(!docObj['properties'])
        {
          docObj['properties'] = {} ;
          
        }
        docObj['properties'][subpropName] = {"value": value}  ;
        var iconCls ;
        if(subprop.properties || subprop.items)
        {
          iconCls = 'task-folder' ;
          if(subprop.properties)
          {
            docObj['properties'][subpropName]['properties'] = {} ;
          }
          else
          {
            docObj['properties'][subpropName]['items'] = [] ;
          }
        }
        else
        {
          iconCls = 'task' ;
        }
        var leaf = (iconCls == 'task' ? true : false) ;
        var subchildren = addSubChildrenForNewDocument(subprop, docObj['properties'][subpropName]) ;
        children.push({
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
          docAddress: docObj['properties'][subpropName]
        }) ;
      }
    }
  }
  return children ;
}

function returnDefaultDomainValue(domain)
{
  var retVal ;
  if(domain == 'int')
  {
    retVal = 0 ;
  }
  else if(domain == 'posInt')
  {
    retVal = 1 ;
  }
  else if(domain == 'negInt')
  {
    retVal = - 1 ;
  }
  else if(domain == 'float')
  {
    retVal = 0.0 ;
  }
  else if(domain == 'posFloat')
  {
    retVal = 1.0 ;
  }
  else if(domain == 'negFloat')
  {
    retVal = -1.0 ;
  }
  else if(domain == 'date')
  {
    var dd = new Date() ;
    retVal = dd.getFullYear()+'/'+dd.getMonth()+1+'/'+dd.getDate() ;
  }
  else if(domain == 'boolean')
  {
    retVal = true ;
  }
  else
  {
    retVal = '' ;
  }
  return retVal ;
}

function toggleDownloadType(format, toggleType)
{
  var btns = Ext.getCmp('mainTreeGrid').getDockedItems()[1].items.items ;
  var ii ;
  for(ii=0; ii<btns.length; ii++)
  {
    if(btns[ii].itemId == 'downloadBtn')
    {
      var items = btns[ii].menu.items.items ;
      var jj ;
      for(jj=0; jj<items.length; jj++)
      {
        if (items[jj].text == format) {
          if (toggleType == 'enable') {
            items[jj].enable() ;
          }
          else
          {
            items[jj].disable() ;
          }
        }
      }
    }
  }
}

function toggleBtn(itemId, toggleType)
{
  var btns = Ext.getCmp('mainTreeGrid').getDockedItems()[1].items.items ;
  var ii ;
  for(ii=0; ii<btns.length; ii++)
  {
    if(btns[ii].itemId == itemId)
    {
      if(toggleType == 'enable')
      {
        btns[ii].enable() ;
      }
      else
      {
        btns[ii].disable() ;
        if (itemId == 'saveBtn') {
          //btns[ii].addCls('genbKb-save-btn-disable') ;
        }
      }
      break ;
    }
  }
}

function getModifiedTitle(editMode)
{
  var edit = editMode ? "ON" : "OFF" ;
  var paddingLeft = editMode ? 545 : 540 ;
  return "Edit Mode: "+edit+"<span style=\"padding-left:"+paddingLeft.toString()+"px;\">(Modified)</span>"
}

function enableEditDelete()
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
      for(jj=0; jj<cssRules.length; jj++)
      {
        if(cssRules[jj].selectorText.match(/genbKb-gray-font-edit-delete/))
        {
          cssRules[jj].style.color = '#000000' ;
        }
      }
    }
  }
}

function disableEditDelete()
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
      for(jj=0; jj<cssRules.length; jj++)
      {
        if(cssRules[jj].selectorText.match(/genbKb-gray-font-edit-delete/))
        {
          cssRules[jj].style.color = '#CCCCCC' ;
        }
      }
    }
  }
}

// Replace the tree-grid store with the newly recieved document
function clearAndReloadTree(newstore)
{
  if(Ext.getCmp('mainTreeGrid'))
  {
    Ext.getCmp('mainTreeGrid').getStore().getRootNode().removeAll() ;
    Ext.getCmp('mainTreeGrid').getStore().getRootNode().remove() ;
  }
  
  if(newstore && Ext.getCmp('mainTreeGrid'))
  {
    Ext.getCmp('mainTreeGrid').getStore().setRootNode(newstore.getRootNode().copy(null, true)) ;
  }
}


// ------------------------------------------------------------------
// UTILITY FUNCTIONS
// ------------------------------------------------------------------
function fullUrlEscape(str)
{
  return (escape(str).gsub(/'/, "%27").gsub(/\//, "%2F").gsub(/\+/, "%20")) ;
}

function registerQtips()
{
  var ii ;
  var toolTips = Object.keys(toolTipMap) ;
  for(ii=0; ii<toolTips.length; ii++)
  {
    Ext.tip.QuickTipManager.register({
      target: toolTips[ii],
      text: toolTipMap[toolTips[ii]],
      showDelay: 1500,
      hideDelay: 0
    }) ;
  }
  toolTipMap = {} ;
}

