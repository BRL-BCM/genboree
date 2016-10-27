
Ext.onReady(function()
{
  // Requires availability of the globals and Workbench namespace.
  setTimeout( function() { initMisc() }, 50 ) ;
}) ;

function initMisc()
{
  if(Workbench.globalsLoaded)
  {
    // Handle window resizing specially w.r.t. the GridPanel
    Ext.EventManager.onWindowResize( function()
    {
      Ext.ComponentMgr.get("wbDetailsGrid").getView().refresh() ;
    }, null, null) ;

    // Misc stuff loaded, let others know.
    Workbench.miscLoaded = true ;
  }
  else // don't have dependencies, try again in a very short while
  {
    setTimeout( function() { initMisc() }, 50 ) ;
  }
}

function programmaticRefreshMainTree(doRefresh)
{
  if(doRefresh && (doRefresh == true || doRefresh.match(/(?:true)|(?:yes)/)))
  {
    refreshMainTree() ;
  }
}


// Removes nodes from the Inputs area based on kill list
function removeNodesFromInputsPanel(killList)
{
  var tree = Ext.ComponentMgr.get('wbInputsTree') ;
  var root = tree.getRootNode() ;
  var mainTree = Ext.ComponentMgr.get('wbMainTree')
  var mainRoot = mainTree.getRootNode() ;
  var ii = 0 ;

  for(ii = 0; ii < killList.size(); ii ++)
  {
    var node = root.findChild('refsUri', killList[ii]) ;
    root.removeChild(node) ;
  }

}

// Removes nodes from 'Data Selector' based on killList on resource type
function removeNodesFromMainPanel(killList, rcscType)
{
  if(rcscType == 'sampleSets')
  {
    // STUPID and WAY complex and WAY too much coding for every entity type. Use Andrew's removeTreeNode() generic approach
    removeSampleSetNodesFromMainPanel(killList) ;
  }
  else if(rcscType == 'files')
  {
    // STUPID and WAY complex and WAY too much coding for every entity type. Use Andrew's removeTreeNode() generic approach
    removeFileNodesFromMainPanel(killList) ;
  }
  else if(rcscType == "trackEntityLists")
  {
    // STUPID and WAY complex and WAY too much coding for every entity type. Use Andrew's removeTreeNode() generic approach
    removeTrackEntityListNodesFromMainPanel(killList) ;
  }
  else
  {
    var mainTree = Ext.ComponentMgr.get('wbMainTree') ;
    var mainRoot = mainTree.getRootNode() ;
    removeTreeNode(mainRoot, killList) ;
  }
}

// Special function for supporting radio btn selection in warnings dialog
function toggleWarningsSelectRadioBtnValue(value, btnName)
{
  wbFormSettings.set(btnName, value) ;
}

function renameTreeNode(treeRootNodeId, renameList)
{
  /* The first element in the rename list is always the full URI of the element to be renamed */
  /* The second element is the new name of the node */
  var treeRoot = Ext.ComponentMgr.get(treeRootNodeId) ;
  var treeRootNode = treeRoot.getRootNode() ;
  var numRenamed = 0 ;
  var refsUri = renameList[0] ;
  var newName = renameList[1] ;
  var nodeToRename = treeRootNode.findChild('refsUri', refsUri, true) ;
  if(nodeToRename)
  {
    var oldName = nodeToRename.text ;
    nodeToRename.setText(newName) ;
    var newRefsUri = refsUri.replace(escape(oldName), escape(newName)) ;
    nodeToRename.attributes.refsUri = newRefsUri ;
    nodeToRename.attributes.name = newName ;
    nodeToRename.attributes.detailsPath = newRefsUri ;
    numRenamed += 1 ;
    parentNode = nodeToRename.parentNode ;
    if(parentNode.attributes.rsrcType != undefined)
    {
      Workbench.wbMainTreeLoader.load(parentNode) ;
      parentNode.expand() ;
    }
  }
  return numRenamed ;
}

/* Function for renaming multiple nodes of a tree */
/* nameMapObj is a json Obj which is an array of hashes with each hash having 'oldRefsUri' and 'newName' */
function renameTreeNodes(treeRootNodeId, nameMapObj)
{
  var treeRoot = Ext.ComponentMgr.get(treeRootNodeId) ;
  var treeRootNode = treeRoot.getRootNode() ;
  var numRenamed = 0 ;
  var ii ;
  var newName ;
  var refsUri ;
  for(ii=0; ii<nameMapObj.length; ii++)
  {
    refsUri = nameMapObj[ii]['oldRefsUri'] ;
    newName = nameMapObj[ii]['newName'] ;
    var nodeToRename = treeRootNode.findChild('refsUri', refsUri, true) ;
    if(nodeToRename)
    {
      var oldName = nodeToRename.text ;
      nodeToRename.setText(newName) ;
      var newRefsUri = refsUri.replace(escape(oldName), escape(newName)) ;
      nodeToRename.attributes.refsUri = newRefsUri ;
      nodeToRename.attributes.name = newName ;
      nodeToRename.attributes.detailsPath = newRefsUri ;
      numRenamed += 1 ;
      if(ii == (nameMapObj.length - 1))
      {
	var parentNode = nodeToRename.parentNode ;
	if(parentNode.attributes.rsrcType != undefined)
	{
	  Workbench.wbMainTreeLoader.load(parentNode) ;
	  parentNode.expand() ;
	}
      }
    }
  }
  return numRenamed ;
}

function removeTreeNode(treeRootNodeId, killList)
{
  var treeRoot = Ext.ComponentMgr.get(treeRootNodeId) ;
  var treeRootNode = treeRoot.getRootNode() ;
  var numDeleted = 0 ;
  for(var ii = 0;  ii < killList.size(); ii ++)
  {
    var nodeToDelete = treeRootNode.findChild('refsUri', killList[ii], true) ;
    if(nodeToDelete)
    {
      treeRootNode.removeChild(nodeToDelete) ;
      numDeleted += 1 ;
    }
  }
  return numDeleted ;
}


function removeAllChildNodes(treeId)
{
  var tree = Ext.ComponentMgr.get(treeId) ;
  var selectionModel = tree.getSelectionModel() ;
  selectionModel.suspendEvents() ;
  var root = tree.getRootNode() ;
  root.removeAll();
  updateWorkbenchObj() ;
  toggleToolsByRules() ;
  // Don't forget to resume events
  selectionModel.resumeEvents() ;
}


// Removes file/folder nodes from 'Data Selector' panel based on kill list
// The kill list is the API URI for the resource.
// The nodes are removed by matching the 'refsUri' attribute with the ones in the kill list
function removeFileNodesFromMainPanel(killList)
{
  var mainTree = Ext.ComponentMgr.get('wbMainTree') ;
  var mainRoot = mainTree.getRootNode() ;
  var ii = 0 ;
  var jj = 0 ;
  for(ii = 0; ii < killList.size(); ii ++)
  {
    // Get the host, grp, db and file node objects
    var hostUri = killList[ii].split("/grp/")[0].concat('/usr/' + userLogin + '/grps?') ;
    var hostNode = mainRoot.findChild('refsUri', hostUri) ;
    var dbUri = killList[ii].split(/\/files?\//)[0].concat('?') ;
    var grpUri = killList[ii].split("/db/")[0].concat('?') ;
    var grpNode = hostNode.findChild('refsUri', grpUri) ;
    var mainDbUri = killList[ii].split("/db/")[0].concat('/dbs?') ;
    var mainDbNode = grpNode.findChild('refsUri', mainDbUri) ;
    var dbUri = killList[ii].split(/\/files?\//)[0].concat('?') ;
    var dbNode = mainDbNode.findChild('refsUri', dbUri) ;
    var filesUri = killList[ii].split(/\/files?\//)[0].concat('/files?') ;
    var filesNode = dbNode.findChild('refsUri', filesUri) ;

    // Next we need to loop over all the sub folders till we reach the terminal resource
    // This could either be a file or a folder
    var filePath = killList[ii].split(/\/files?\//)[1].replace('?', '') ;
    var folderList = filePath.split('/') ;
    folderListSize = folderList.size() ;
    for(jj = 0; jj < folderListSize; jj++)
    {
      // Terminal resource (file/folder): use uri from kill list to find the child node
      if(jj == folderListSize - 1)
      {
        fileFolderNode = filesNode.findChild('refsUri', killList[ii]) ;
        mainRoot.removeChild(fileFolderNode) ;
      }
      // This HAS to be a sub folder. We need the node object to access the child node.
      else
      {
        var filesUri = filesUri.replace('?', '/').concat(folderList[jj]).concat('?') ;
        var filesNode = filesNode.findChild('refsUri', filesUri) ;
      }
    }
  }
}

// Removes sampleset nodes from 'Data Selector' panel based on kill list
function removeSampleSetNodesFromMainPanel(killList)
{
  var mainTree = Ext.ComponentMgr.get('wbMainTree')
  var mainRoot = mainTree.getRootNode() ;
  var ii = 0 ;

  var nodeHash = new Hash() ; // key is db uri and value is the sample set node object
  for(ii = 0; ii < killList.size(); ii ++)
  {
    var dbUri = killList[ii].split('/sampleSet/')[0].concat('?') ;
    if(nodeHash.get(dbUri) === undefined)
    {
      var hostUri = killList[ii].split("/grp/")[0].concat('/usr/' + userLogin + '/grps?') ;
    	var hostNode = mainRoot.findChild('refsUri', hostUri) ;
      var grpUri = killList[ii].split("/db/")[0].concat('?') ;
      var grpNode = hostNode.findChild('refsUri', grpUri) ;
      var mainDbUri = killList[ii].split("/db/")[0].concat('/dbs?') ;
      mainDbNode = grpNode.findChild('refsUri', mainDbUri) ;
      var dbUri = killList[ii].split("/sampleSet/")[0].concat('?') ;
      dbNode = mainDbNode.findChild('refsUri', dbUri) ;
      var mainSampleSetUri = killList[ii].split("/sampleSet/")[0].concat('/sampleSets?') ;
      mainSampleSetNode = dbNode.findChild('refsUri', mainSampleSetUri) ;
      sampleSetNode = mainSampleSetNode.findChild('refsUri', killList[ii]) ;
      mainRoot.removeChild(sampleSetNode) ;
      nodeHash[dbUri] = mainSampleSetNode ;
    }
    else
    {
      mainSampleSetNode = nodeHash[dbUri] ;
      sampleSetNode = mainSampleSetNode.findChild('refsUri', killList[ii]) ;
      mainRoot.removeChild(sampleSetNode) ;
    }
  }
}

function moveEntity(widgetId, value, moveTo)
{
  // Get the inputs array first
  // Always get the inputs array from the inputs tree panel since it may not be the first 'submit' from the user
  // and in that case the inputs[] in wbHash is polluted with our prior edit
  var inputs = new Array() ;
  var inputsCount = 0 ;
  var tree = Ext.ComponentMgr.get('wbInputsTree') ;
  var root = tree.getRootNode() ;
  root.eachChild( function(currentNode)
                  {
                    inputs[inputsCount] = currentNode.attributes.refsUri ;
                    inputsCount ++ ;
                  }
                ) ;
  var ii ;
  for(ii = 0; ii < inputs.length; ii++)
  {
    if(inputs[ii] == value)
    {
      // Remove it from its current position
      inputs.splice(ii, 1) ;
      break ;
    }
  }
  // Add it to its new location
  if(moveTo == 'top')
  {
    inputs[0] = value ;
  }
  else
  {
    inputs[inputs.length - 1] = value ;
  }
  // Update the inputs array
  wbHash.set('inputs', inputs) ;
}
function moveEntities(widgetId, moveTo)
{
  // Get the inputs array first
  // Always get the inputs array from the inputs tree panel since it may not be the first 'submit' from the user
  // and in that case the inputs[] in wbHash is polluted with our prior edit
  var inputs = new Array() ;
  var inputsCount = 0 ;
  var tree = Ext.ComponentMgr.get('wbInputsTree') ;
  var root = tree.getRootNode() ;
  root.eachChild( function(currentNode)
                  {
                    inputs[inputsCount] = currentNode.attributes.refsUri ;
                    inputsCount ++ ;
                  }
                ) ;
  var multiSelectList = Ext.get(widgetId).dom ;
  var selectedOptionsLength = multiSelectList.options.length ;
  var idxArray = new Array() ; // Array for storing indices of the selected values
  var idxArrayCount = 0 ;
  var ii, jj, value ;
  for(ii = 0; ii < selectedOptionsLength; ii ++)
  {
    value = multiSelectList.options[ii] ;
    for(jj = 0; jj < inputs.length; jj ++)
    {
      if(value == inputs[jj])
      {
        idxArray[idxArrayCount] = jj ;
        idxArrayCount ++ ;
      }
    }
  }
  // Now loop over the idxArray and remove the selected values
  var valueToMove ;
  for(ii = 0; ii < idxArray.length; ii ++)
  {
    valueToMove = inputs[idxArray[ii]] ;
    inputs.splice(idxArray[ii], 1) ;
    if(moveTo == 'top')
    {
      inputs[ii] = valueToMove ;
    }
    else
    {
      inputs[ii + selectedOptionsLength] = valueToMove ;
    }
  }
  // Overwrite the inputs array with the new one
  wbHash.set('inputs', inputs) ;
}

// Remove element from input array depending on user selection
// widgetId: Id of widget having ROI track selection. Must have a "setAs attribute configured
function removeSelectedEntity(widgetId)
{
  // Get setAs field name
  var multiSelectList = Ext.get(widgetId).dom ;
  var value = multiSelectList.value ;
  // Can't use this since 'setAs' is assigned 'roiTrkSelect' which is just the widgetId and not the value for 'setAs'. Hence passing it into the function as a parameter:
  var setAs = multiSelectList.attributes["setAs"].nodeValue ;
  // Get the inputs array first
  // Always get the inputs array from the inputs tree panel since it may not be the first 'submit' from the user
  // and in that case the inputs[] in wbHash is polluted with our prior edit
  var inputs = new Array() ;
  var inputsCount = 0 ;
  var tree = Ext.ComponentMgr.get('wbInputsTree') ;
  var root = tree.getRootNode() ;
  root.eachChild( function(currentNode)
                  {
                    inputs[inputsCount] = currentNode.attributes.refsUri ;
                    inputsCount ++ ;
                  }
                ) ;
  // This should be replacable by one method. I don't know...
  var idx = inputs.indexOf(value) ;
  while(idx > -1)
  {
    inputs.splice(idx, 1) ;
    idx = inputs.indexOf(value) ;
  }
  // OLD:
  //for(var ii = 0; ii < inputs.length; ii++)
  //{
  //  if(inputs[ii] == value)
  //  {
  //    inputs.splice(ii, 1)
  //    break ;
  //  }
  //}
  // Overwrite the inputs array with the new one
  wbHash.set('inputs', inputs) ;
  // Finally set the required attribute-value in the settings
  wbHash.get('settings').set(setAs, value) ;
  // Set a tag so that the rules helper won't complain about changing the number of inputs
  wbHash.get('settings').set('positionalInputsTool', 'true') ;
  // For some reason, the rules helper checks the 'wbFormSettings' instead of settings in wbHash, so make changes here as well
  wbFormSettings.set(setAs, value) ;
  wbFormSettings.set('positionalInputsTool', 'true') ;
}

// Remove elements from input array depending on user selection
// widgetId
// setAs: set as this setting in 'settings'
function removeSelectedEntities(widgetId)
{
  // Get setAs field name
  var multiSelectList = Ext.get(widgetId).dom ;
  var setAs = multiSelectList.attributes.item("setAs").nodeValue ;
  // Get the inputs array first
  // Always get the inputs array from the inputs tree panel since it may not be the first 'submit' from the user
  // and in that case the inputs[] in wbHash is polluted with our prior edit
  var inputs = new Array() ;
  var inputsCount = 0 ;
  var tree = Ext.ComponentMgr.get('wbInputsTree') ;
  var root = tree.getRootNode() ;
  root.eachChild( function(currentNode)
                  {
                    inputs[inputsCount] = currentNode.attributes.refsUri ;
                    inputsCount ++ ;
                  }
                ) ;
  var multiSelectList = Ext.get(widgetId).dom ;
  var selectedOptionsLength = multiSelectList.options.length ;
  var valueArray = new Array() ; // Array for storing removed values
  var valueArrayCount = 0 ;
  var ii, jj, value ;
  for(ii = 0; ii < selectedOptionsLength; ii ++)
  {
    value = multiSelectList.options[ii] ;
    for(jj = 0; jj < inputs.length; jj ++)
    {
      if(value == inputs[jj])
      {
        valueArray[valueArrayCount] = value ;
        valueArrayCount ++ ;
        inputs.splice(jj, 1) ;
      }
    }
  }
  // Add a new setting
  wbHash.set('inputs', inputs) ;
  wbHash.get('settings').set(setAs, valueArray) ;
  // Set a tag so that the rules helper won't complain about changing the number of inputs
  wbHash.get('settings').set('positionalInputsTool', 'true') ;
  wbFormSettings.set(setAs, valueArray) ;
  wbFormSettings.set('positionalInputsTool', 'true') ;
}
