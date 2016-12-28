
// Helper function used by many functions to extract domain info of a property
function getDomainInfo(modelEl)
{
  var domainToUse = modelEl.domain || '' ;
  var domainOptsToUse = '' ;
  if(domainToUse.match(/^enum/))
  {
    domainToUse = "enum" ;
    domainOptsToUse = {"values": modelEl.domain.replace(/^enum\(/, '').replace(/\)$/, '').split(',')} ;
  }
  else if(domainToUse.match(/^regexp/))
  {
    domainToUse = "regexp" ;
    domainOptsToUse = {"pattern": modelEl.domain.replace(/^regexp\(/, '').replace(/\)$/, '')} ;
  }
  else if (domainToUse.match(/^bioportalTerms\(/)) {
    domainToUse = "bioportalTerm" ;
    domainOptsToUse = {"url": modelEl.domain.replace(/^bioportalTerms\(/, '').replace(/\)$/, '')} ;
  }
  else if (domainToUse.match(/^bioportalTerm\(/)) {
    domainToUse = "bioportalTerm" ;
    domainOptsToUse = {"url": modelEl.domain.replace(/^bioportalTerm\(/, '').replace(/\)$/, '')} ;
  }
  else if(domainToUse.match(/^measurement/))
  {
    domainToUse = "measurement" ;
  }
  else if (domainToUse.match(/^intRange/))
  {
    domainToUse = "int" ;
    var minMax = modelEl.domain.replace('intRange(', '').replace(')', '').split(',') ;
    var min = ( minMax[0] == "" ? undefined : minMax[0] );
    var max = ( minMax[1] == "" ? undefined : minMax[1] ) ;
    domainOptsToUse = { "min": min, "max": max } ;
  }
  else if (domainToUse.match(/^floatRange/))
  {
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
  documentEdited = true ;
  // Enable the save btn
  toggleBtn('saveDoc', 'enable') ;
  // If its a document that already existed, enable the 'discard changes' button
  if(!freshDocument)
  {
    toggleBtn('discardChanges', 'enable') ;
  }
  Ext.getCmp('mainTreeGrid').setTitle(getModifiedTitle(true)) ;
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
// First creates the root node and calls constructChildrenObj() which recursively constructs the nested tree object required by ExtJS to render the tree-grid
function createViewableDoc(docModelObj, newdocObj, isTemplateDoc)
{
  var identifier = docModelObj.name ;
  var editRequired = isTemplateDoc ;
  var modelProperties = docModelObj.properties ;
  var newdocProperties = null ;
  var children = [] ;
  var ii, jj ;
  var rootProp = docModelObj ;
  var el ;
  if (modelProperties) {
    newdocProperties = newdocObj[identifier].properties ;
    if (newdocProperties) {
      for(ii=0; ii<modelProperties.length; ii++)
      {
        el = modelProperties[ii] ;
        if(!newdocProperties[el.name])
        {
          continue ;
        }
        children.push(constructChildrenObj(el, newdocProperties[el.name], isTemplateDoc)) ;
      }
    }
  }
  var domainEls = getDomainInfo(rootProp) ;
  var domain = domainEls[0] ;
  var domainOpts = domainEls[1] ;
  return {
    name: identifier,
    value: newdocObj[identifier].value,
    category: true, // make the identifier bold
    iconCls: 'task-folder',
    expanded: true,
    children: children,
    identifier: true,
    domain: domain,
    domainOpts: domainOpts,
    required: true,
    description: rootProp.description,
    editRequired: editRequired,
    docAddress: newdocObj[identifier],
    modelAddress: rootProp
  } ;

}

// Recursive function to traverse nested data and construct all children nodes (descendence) for the root node
// This nested object is required by ExtJS to render the tree-grid view.
// Each node is asssociated with all the attributes of a property which can be used for customized rendering (bold font/different icons for leaf/non leaf nodes, etc)
// The attributes 'docAddress' and 'modelAddress' are actually pointers to the real values in 'newDocObj' and 'docModel' objects respectively
//       which allows for relatively simple syncing of values that are displayed in the tree and the values stored in the actual document object.
function constructChildrenObj(el, newdocProperty, isTemplateDoc)
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
      children.push(constructChildrenObj(el.properties[ii], newdocProperty.properties[el.properties[ii].name], isTemplateDoc)) ;
    }
    var editRequired = isEditRequired(el, newdocProperty, isTemplateDoc) ;
    var retObj = { name: el.name, value: newdocProperty.value, description: el.description, category: el.category, iconCls: 'task-folder', domain: domain, children: children, docAddress: newdocProperty, domainOpts: domainOpts, required: el.required, modelAddress: el, fixed: el.fixed, editRequired: editRequired } ;
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

    // 'items' is NOT required to be present (even if the property having 'items' itself is required,
    // there may be no items [at all, not even empty list!] UNDER that required property)
    // - Thus need to check to see if it's there before returning it.
    // - BUG: if missing we set items=>[] the empty list. But this is probably not smart because
    //   "null/missing" is NOT THE SAME AS ASSERTING THE LIST IS present BUT **empty**
    // - BUG: the UI code should be fixed, but as a workaround we'll set null items to be items >[]
    //   because otherwise it crashes.
    if(typeof items == 'undefined' || items == null)
    {
      items = [] ;
    }

    for(ii=0; ii<items.length; ii++)
    {
      var subchildren = [] ;
      var item = items[ii] ;
      if(!item[rootProp.name])
      {
        continue ;
      }
      var rootPropValue = item[rootProp.name].value ;
      if (rootProp.properties) {
        var itemProps = item[rootProp.name].properties ;
        for(jj=0; jj<rootProp.properties.length; jj++)
        {
          var modelEl = rootProp.properties[jj] ;
          if(!itemProps || !itemProps[modelEl.name])
          {
            continue ;
          }
          subchildren.push(constructChildrenObj(modelEl, itemProps[modelEl.name], isTemplateDoc)) ;
        }
      }
      else if (rootProp.items) {
        subchildren.push(constructChildrenObj(rootProp, item[rootProp.name], isTemplateDoc)) ;
      }
      var editRequired = isEditRequired(rootProp, item[rootProp.name], isTemplateDoc) ;
      var nodeObj = { name: rootProp.name, value: rootPropValue, description: rootProp.description, fixed: rootProp.fixed, category: rootProp.category, domain: domainOfRoot, required: rootProp.required, children: subchildren, docAddress: item[rootProp.name], domainOpts: domainOptsOfRoot, modelAddress: rootProp, editRequired: editRequired } ;
      if (rootProp.properties || rootProp.items) {
        nodeObj['iconCls'] = 'task-folder' ;
      }
      else{
        nodeObj['iconCls'] = 'task' ;
        nodeObj['leaf'] = true ;
      }
      children.push(nodeObj) ;
    }
    var editRequired = isEditRequired(el, newdocProperty, isTemplateDoc) ;
    return { name: el.name, value: newdocProperty.value, fixed: el.fixed, description: el.description, category: el.category, iconCls: 'task-folder', domain: domain, children: children, docAddress: newdocProperty, domainOpts: domainOpts, required: el.required, modelAddress: el, editRequired: editRequired } ;
  }
  else
  {
    var editRequired = isEditRequired(el, newdocProperty, isTemplateDoc) ;
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
              fixed: el.fixed,
              editRequired: editRequired
            } ;
  }
}

// Function to log error messages on the console 
// this is useful to quickly look at errors in the browser console
// to check the issue and locate the JS file which raises the error
function logErr(err) {
  var msgText = "FATAL ERROR MSG: " + err.message + "\n  FILE: " +
     err.fileName + "\n  LINE: " + err.lineNumber + "\n  STACKTRACE: " +
     err.stack + "\n\n";
  if(window.console) {
    window.console.log(msgText) ;
  }
}

function isEditRequired(el, newdocProperty, isTemplateDoc)
{
  var editRequired = false  ;
  if (el.domain && el.domain == '[valueless]') {
    editRequired = false ;
  }
  else{
    if (isTemplateDoc) {
      if (newdocProperty['value'] == '') {
        editRequired = true ;
      }
      else if(el['unique'] != undefined && el['unique'] == true){
        editRequired = true ;
      }
      else{
        editRequired = false ;
      }
    }
  }
  return editRequired ;
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

// provides functionality to reorder items in an items list
// Only available if there are at least 2 items in the list
// Registered to the reorder btn in the property context menu
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




// Returns default values for certain domain types when creating a new document.
// This is required since the row editing plugin complains and does not allow editing if field has invalid values
function returnDefaultDomainValue(domain, domainOpts)
{
  var retVal ;
  if(domain == 'int')
  {
    retVal = 0 ;
    // Set the appropriate value for range domains
    if (domainOpts && domainOpts['min'] != undefined) {
      retVal = parseInt(domainOpts['min']) ;
    }
    if (domainOpts && domainOpts['max'] != undefined) {
      retVal = parseInt(domainOpts['max']) ;
    }
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
    // Set the appropriate value for range domains
    if (domainOpts && domainOpts['min'] != undefined) {
      retVal = parseFloat(domainOpts['min']) ;
    }
    if (domainOpts && domainOpts['max'] != undefined) {
      retVal = parseFloat(domainOpts['max']) ;
    }
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
    retVal = dd.getFullYear()+'/'+(parseInt(dd.getMonth())+1).toString()+'/'+dd.getDate() ;
  }
  else if(domain == 'boolean')
  {
    retVal = true ;
  }
  else if (domain == 'enum') {
    retVal = domainOpts['values'][0] ;
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
  edit = addDocVerStr(edit) ;
  var paddingLeft = editMode ? 305 : 300 ;
  return "Edit Mode: "+edit+"<span style=\"padding-left:"+paddingLeft.toString()+"px;\">(Modified)</span>"
}

function addDocVerStr(title)
{
  if (docVersion != "") {
    title = title + "<span style=\"padding-left:150px;\">Version: "+docVersion+"</span>" ;
  }
  else{
    title = title + "<span style=\"padding-left:150px;\">Version: Current</span>" ;
  }
  return title ;
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
function destroyModelTree()
{
  if(Ext.getCmp('modelTreeGrid'))
  {
    Ext.getCmp('modelTreeGrid').destroy() ;
  }
}

function destroyEditorTree()
{
  if(Ext.getCmp('mainTreeGrid'))
  {
    Ext.getCmp('mainTreeGrid').destroy() ;
  }
  newdocObj = null ;
  documentEdited = false ;
  freshDocument = false ;
}

function destroyViewGrid()
{
  if(Ext.getCmp('viewGrid'))
  {
    Ext.getCmp('viewGrid').destroy() ;
  }
}

function destroyDocsVersionsGrid()
{
  if(Ext.getCmp('docsVersionsGrid'))
  {
    Ext.getCmp('docsVersionsGrid').destroy() ;
  }
}


function destroyModelVersionsGrid()
{
  if(Ext.getCmp('modelVersionsGrid'))
  {
    Ext.getCmp('modelVersionsGrid').destroy() ;
  }
}

function destroyKbStatsPanel()
{
  if (Ext.getCmp('kbStatsPanel')) {
    Ext.getCmp('kbStatsPanel').destroy() ;
  }
}

function fullUrlEscape(str)
{
  return (escape(str).gsub(/'/, "%27").gsub(/\//, "%2F").gsub(/\+/, "%20")) ;
}

function registerQtips(showDelay, hideDelay, dismissDelay)
{
  var ii ;
  var toolTips = Object.keys(toolTipMap) ;
  for(ii=0; ii<toolTips.length; ii++)
  {
    Ext.tip.QuickTipManager.register({
      target: toolTips[ii],
      text: toolTipMap[toolTips[ii]],
      showDelay: showDelay,
      hideDelay: hideDelay,
      dismissDelay: dismissDelay
    }) ;
  }
  toolTipMap = {} ;
}

// Adds iframe for downloading files via browser
function appendIframe(src)
{
  Ext.DomHelper.append(document.body, {
    tag: 'iframe',
    frameBorder: 0,
    width: 0,
    height: 0,
    css: 'display:none;visibility:hidden;height:1px;',
    src: src
  });
}

function capitaliseFirstLetter(string)
{
  return string.charAt(0).toUpperCase() + string.slice(1);
}


function getDocToolBarBtn(itemId)
{
  var btns = Ext.getCmp('mainTreeGrid').getDockedItems()[1].items.items ;
  var ii ;
  var retVal ;
  for(ii=0; ii<btns.length; ii++)
  {
    if(btns[ii].itemId == itemId)
    {
      retVal = btns[ii] ;
      break ;
    }
  }
  return retVal ;
}


function enablePanelBtn(btn)
{
  // Change the color of the text from gray to black to make it look 'enabled' (for 'Create new Document')
  var ss = document.styleSheets ;
  var ii, jj ;
  var regexp ;
  if (btn == 'editDelete') {
    regexp = /genbKb-gray-font-edit-delete/ ;
  }
  else if (btn == 'docHistory') {
    regexp = /genbKb-gray-font-doc-history/ ;
  }
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
        if(cssRules[jj].selectorText.match(regexp))
        {
          cssRules[jj].style.color = '#000000' ;
        }
      }
    }
  }
}

function disablePanelBtn(btn)
{
  // Change the color of the text from gray to black to make it look 'enabled' (for 'Create new Document')
  var ss = document.styleSheets ;
  var ii, jj ;
  var regexp ;
  if (btn == 'editDelete') {
    regexp = /genbKb-gray-font-edit-delete/ ;
  }
  else if (btn == 'docHistory') {
    regexp = /genbKb-gray-font-doc-history/ ;
  }
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
        if(cssRules[jj].selectorText.match(regexp))
        {
          cssRules[jj].style.color = '#CCCCCC' ;
        }
      }
    }
  }
}


