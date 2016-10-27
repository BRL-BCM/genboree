/** ------------------------------------------------------------------
 * Code Related to Panels on the Page and their Contents.
 */
Ext.onReady( function()
{
  // Requires availability of the globals and ajax functions (in particular, the wbLoader methods):
  setTimeout( function() { initPanels() }, 50 ) ;
}) ;

function firstToolActivation()
{
  if(Workbench && Workbench.toolbar && Workbench.toolbar.items)
  {
    toggleToolsByRules() ;
  }
  else
  {
    setTimeout( function() { firstToolActivation() }, 50) ;
  }
}

function initPanels()
{
  // Requires availability of the globals and ajax functions (in particular, the wbLoader methods):
  if(Workbench.globalsLoaded && Workbench.ajaxLoaded) // then have dependencies
  {
    // Initialize Tooltips & configure defaults
    Ext.QuickTips.init() ;
    Ext.apply(Ext.QuickTips.getQuickTip(), {
      dismissDelay  : 10000,
      showDelay     : 1000
    });
    // Define a singular DefaultSelectionModel to share
    var selModel = new Ext.tree.DefaultSelectionModel() ;
    selModel.on("selectionchange", function(selModel, node)
    {
      if(node)
      {
        // First clear out old data
        var detailsStore = Ext.ComponentMgr.get('wbDetailsGrid').store ;
        detailsStore.removeAll() ;

        if(node && node.attributes.detailsPath && node.attributes.rsrcType)
        {
          /**
           * Based on the node type call the appropriate handler
           * that will translate the response into a details panel array
           *
           * This allows us to customize the translation between API response and details array for each resource.
           * Some values may need to be formatted, some hidden, etc...
           */
          var loaderObj = NodeHelperSelector.getNodeHelper(node) ;
          loaderObj.updateDetails(node) ;
        }
        else
        {
          //alert('detailsPath ('+node.attributes.detailsPath+') or rsrcType ('+node.attributes.rsrcType+') is not set, can\'t get details') ;
        }
      }
    }) ;
    var wbTreePanelToolBar = new Ext.Toolbar({
      width:'auto',
      items: [
        {
          text: 'Refresh',
          id: "wbRefreshButton",
          ctCls: "wbToolbarBtn",
          tooltip: "<b>Refresh the Tree</b><br><br>Use this button to refresh the resource tree to show any newly created resources.<br><br>Or, you can refresh an individual resource in the tree by double clicking on it.",
          iconCls: 'wbRefresh',
          handler: refreshMainTree

        }
      ]
    }) ;
    //wbTreePanelToolBar.add() ;

    var wbTreeFilterStore = new Ext.data.ArrayStore({
      fields: ['rsrcList', 'FilterBy'],
      data : [
        ['', 'No Filter'],
        ['/grps/grp', 'Groups'],
        ['/grps/grp/dbs/db', 'Databases'],
        ['/grps/grp/dbs/db/cls/trks/trk', 'Tracks'],
        ['/grps/grp/dbs/db/sampleSets/sampleSet', 'Sample Sets'],
        ['/grps/grp/dbs/db/bioSamples/sample', 'Samples'],
        ['/grps/grp/dbs/db/files/file', 'Files'],
        //['/grps/grp/dbs/db/queries/query', 'Queries'],
        ['/grps/grp/prjs/prj', 'Projects']
      ]
    });

    var wbTreeFilterCombo = new Ext.form.ComboBox({
      id: 'treeFilter',
      store: wbTreeFilterStore,
      displayField: 'FilterBy',
      valueField: 'rsrcList',
      typeAhead: true,
      mode: 'local',
      triggerAction: 'all',
      emptyText: 'Select a filter...',
      selectOnFocus: true,
      width: 135,
      getListParent: function() {
          return this.el.up('.x-menu');
      },
      iconCls: 'no-icon',
      listeners: {
        select: function(combo, record, index){
          filterTree(record.data.rsrcList) ;
        }
      }
    });
    wbTreePanelToolBar.addFill() ; /* Causes the next fields to be floated to the right */
    wbTreePanelToolBar.add('Data Filter:') ;
    wbTreePanelToolBar.addField(wbTreeFilterCombo) ;

    /**
     * Define the main resource tree
     */
    Workbench.mainTree = new Tree.TreePanel(
    {
      id: 'wbMainTree',
      title: '<div ext:qtip="Contains data entities on which Workbench tools operate. <br>See <b>Help</b> &raquo; <b>Legend</b> for the types of entities appearing here.">Data Selector</div>',
      loader: Workbench.wbMainTreeLoader,
      selModel: selModel,
      //selModel: new Ext.tree.MultiSelectionModel(),
      height: 455,
      useArrows: true,
      autoScroll: true,
      animate: false,
      ddGroup: 'wbDDGroup',
      enableDrag: true,
      enableDrop: false,
      cls: 'wbTree',
      containerScroll: true,
      rootVisible: false,
      tbar: wbTreePanelToolBar,
      root: new Ext.tree.AsyncTreeNode(
      {
        text: 'Groups',             // Doesn't matter, root not visible
        iconCls: 'wbGrpsTreeNode',  // Doesn't matter, root not visible
        rsrcPath: '/REST/v1/usr/' + encodeURIComponent(userLogin) + '/hosts?connect=yes',
        refsUri: 'http://' + serverName + '/REST/v1/usr/' + encodeURIComponent(userLogin) + '/grps?',
        rsrcType: 'hosts',
        id: 'wbMainTreeRoot',
        expanded: true
      })
     }) ;

    Workbench.mainTreeFilter = new Ext.tree.TreeFilter(Workbench.mainTree, {autoClear: false})
//    Workbench.mainTree.on("expandnode", function() { filterTree(Ext.ComponentMgr.get('treeFilter').getValue()); } ) ;
    Workbench.mainTree.on("load", function() {  filterTree(Ext.ComponentMgr.get('treeFilter').getValue()); } ) ;

    // explicitly create a Container so that the TreePanel resizes with the window
    var mainTreeContainer = new Ext.Container(
    {
      renderTo: 'wbMainTreeDiv',
      layout: 'fit',
      monitorResize: true,
      items: [
        Workbench.mainTree
      ]
    }) ;


    //------------------------------------------------------------------
    // Define Inputs Tree (?)
    Workbench.inputsTree = new Tree.TreePanel(
    {
      id: 'wbInputsTree',
      title: '<div ext:qtip="Workbench tools operate on data entities like tracks, files, folders, samples, and entity lists of files or tracks, which are dragged over from the <b>Data Selector</b> to this panel">Input Data</div>',
      selModel: selModel,
      height: 140,
      tbar:
      [
        {
          tooltip:"Move Up",
          cls:"x-btn-icon",
          icon: "/images/workbench/up_arrow.gif",
          handler: function() { trackMod("up", 'wbInputsTree') }
        },
        {
          tooltip: "Move Down",
          cls:"x-btn-icon",
          icon: "/images/workbench/down_arrow.gif",
          handler: function() { trackMod("down", 'wbInputsTree') }
        },
        {
          tooltip: "Remove",
          cls:"x-btn-icon",
          icon: "/images/workbench/delete.png",
          handler: function() { trackMod("delete", 'wbInputsTree') }
        },
        {
          tooltip: "Remove All Inputs",
          cls:"x-btn-icon",
          icon: "/images/eraser.png",
          handler: function() { removeAllChildNodes('wbInputsTree') }
        }
      ],
      useArrows: true,
      autoScroll: true,
      animate: true,
      enableDD: true,
      cls: 'wbSeltree',
      containerScroll: true,
      root: new Ext.tree.TreeNode(
      {
        text: 'Input Data',
        id: 'wbInputsDataRoot'
      }),
      ddGroup: 'wbDDGroup',
      dropConfig:
      {
        ddGroup: 'wbDDGroup',
        allowContainerDrop: true,
        notifyEnter: function(source, evnt, data)
        {
          if(source.tree == this.tree)
          {
            // This is a "rearrangement" from the same tree
            delete this.tree.dropZone.notifyDrop ;
          }
          else
          {
            this.tree.dropZone.notifyDrop = this.tree.dropZone.onContainerDrop ;
          }
        },
        notifyOut: removeFromPanel,
        onContainerDrop: inputsOutputsOnDrop,
        onContainerOver: function(source, e, data)
        {
          return "x-dd-drop-ok-add" ;
        }
      },
      rootVisible: false
    }) ;

    Workbench.inputsTree.root.on("append", function() { updateDataset("wbInputsTree") ; }) ;
    Workbench.inputsTree.root.on("insert", function() { updateDataset("wbInputsTree") ; }) ;
    Workbench.inputsTree.root.on("remove", function() { updateDataset("wbInputsTree") ; }) ;

    // explicitly create a Container so that the Inputs Tree Panel resizes with the window
    var inputsContainer = new Ext.Container(
    {
      renderTo: 'wbInputsTreeDiv',
      layout: 'fit',
      monitorResize: true,
      items: [
        Workbench.inputsTree
      ]
    }) ;

    //------------------------------------------------------------------
    // Define Outputs Tree (?)
    Workbench.outputsTree = new Tree.TreePanel(
    {
      id: 'wbOutputsTree',
      title: '<div ext:qtip="Workbench tools deposit analysis results in the output targets such as Databases and Projects, which are dragged over from the <b>Data Selector</b> to this panel.">Output Targets</div>',
      selModel: selModel,
      height: 140,
      tbar:
      [
        {
          tooltip:"Move Up",
          cls:"x-btn-icon",
          icon: "/images/workbench/up_arrow.gif",
          handler: function() { trackMod("up", 'wbOutputsTree') }
        },
        {
          tooltip: "Move Down",
          cls:"x-btn-icon",
          icon: "/images/workbench/down_arrow.gif",
          handler: function() { trackMod("down", 'wbOutputsTree') }
        },
        {
          tooltip: "Remove",
          cls:"x-btn-icon",
          icon: "/images/workbench/delete.png",
          handler: function() { trackMod("delete", 'wbOutputsTree') }
        },
        {
          tooltip: "Remove All Outputs",
          cls:"x-btn-icon",
          icon: "/images/eraser.png",
          handler: function() { removeAllChildNodes('wbOutputsTree') }
        }
      ],
      useArrows: true,
      autoScroll: true,
      animate: true,
      enableDD: true,
      cls: 'wbSeltree',
      containerScroll: true,
      root: new Ext.tree.TreeNode(
      {
        text: 'Output Targets',
        id: 'wbOutputsDataRoot'
      }),
      ddGroup: 'wbDDGroup',
      dropConfig:
      {
        ddGroup: 'wbDDGroup',
        allowContainerDrop: true,
        notifyEnter: function(source, evnt, data)
        {
          if(source.tree == this.tree)
          {
            // This is a "rearrangement" from the same tree
            delete this.tree.dropZone.notifyDrop ;
          }
          else
          {
            this.tree.dropZone.notifyDrop = this.tree.dropZone.onContainerDrop ;
          }
        },
        notifyOut: removeFromPanel,
        onContainerDrop: inputsOutputsOnDrop,
        onContainerOver: function(source, e, data)
        {
          return "x-dd-drop-ok-add" ;
        }
      },
      rootVisible: false
    }) ;
    Workbench.outputsTree.root.on("append", function() { updateDataset("wbOutputsTree") ; }) ;
    Workbench.outputsTree.root.on("insert", function() { updateDataset("wbOutputsTree") ; }) ;
    Workbench.outputsTree.root.on("remove", function() { updateDataset("wbOutputsTree") ; }) ;

    // explicitly create a Container so that the Inputs Tree Panel resizes with the window
    var outputsContainer = new Ext.Container(
    {
      renderTo: 'wbOutputsTreeDiv',
      layout: 'fit',
      monitorResize: true,
      items: [
        Workbench.outputsTree
      ]
    }) ;

    // Initialize Grid for details
    Workbench.store = new Ext.data.SimpleStore(
    {
      fields:
      [
        { name : 'attribute' },
        { name : 'value' }
      ]
    }) ;

    // Set up a Grid in which to display selected item's details.
    Workbench.detailsGrid = new Ext.grid.GridPanel(
    {
      id: 'wbDetailsGrid',
      title: '<div ext:qtip="Contains information on any data entity represented as Attribute-Value pair, if it is highlighted in <b>Data Selector</b> or dragged into <b>Input Data</b> or <b>Output Targets</b>.">Details</div>',
      viewConfig: { forceFit: true },
      height: 155,
      store: Workbench.store,
      columns:
      [
        { id: 'attribute', header: '<div ext:qtip="Description of data entity being defined. Click arrow on right corner to sort this column.">Attribute</div>', dataIndex: 'attribute', width: 125, sortable: true },
        { id: 'value', header: '<div ext:qtip="Entry associated with an attribute. Click arrow on right corner to sort this column.">Value</div>', dataIndex: 'value', sortable: true }
      ],
      stripeRows: true,
      autoExpandColumn: 'value'
    }) ;

    // explicitly create a Container so that the Inputs Tree Panel resizes with the window
    var detailsContainer = new Ext.Container(
    {
      renderTo: 'wbDetailsGridDiv',
      layout: 'fit',
      monitorResize: true,
      items: [
        Workbench.detailsGrid
      ]
    }) ;

    // Try to activate any tools upon page load (eg tools independent of inputs/outputs) ;
    setTimeout( function() { firstToolActivation() }, 50) ;
    // Panels loaded, let others know.
    Workbench.panelsLoaded = true ;
  }
  else // don't have dependencies, try again in a very short while
  {
    setTimeout( function() { initPanels() }, 50) ;
  }
}

function inputsOutputsOnDrop(source, e, data)
{
  var root = this.tree.root ;
  // Check if this node is already in the tree
  if(!root.findChild("id", data.node.id))
  {
    // Not already in tree - create a new node
    var newNode = new Ext.tree.TreeNode(
    {
      id: data.node.id,
      text: data.node.text,
      draggable: true,
      allowDrop: false,
      leaf: data.node.leaf
    } ) ;
    // Add some data to the node for further operations
    // We need refsUri, rsrcType
    if(data.node.attributes.refsUri == undefined)
    {
      alert('refsUri is undefined');
      return false;
    }
    else
    {
      newNode.attributes.rsrcType = data.node.attributes.rsrcType;
      newNode.attributes.refsUri = data.node.attributes.refsUri;
      newNode.attributes.detailsPath = data.node.attributes.detailsPath;
      newNode.attributes.iconCls = data.node.attributes.iconCls;
    }
    /**
     * Check whether the node already exists in tree.
     * Do this by checking the ref URI
     */
    var existsInTree = false;
    if(root.hasChildNodes())
    {
      root.eachChild( function(n)
      {
        if(newNode.attributes.refsUri == n.attributes.refsUri)
        {
          existsInTree = true ;
        }
      }) ;
    }
    if(existsInTree)
    {
      return false ;
    }
    // Check if this is an insert or an append
    var target = this.getTargetFromEvent(e) ;
    if(target)
    {
      // TODO - when inserting into the tree, the insert line never disappears
      // TODO - right now always appends before node even if supposed to go after
      root.insertBefore(newNode, target.node) ;
    }
    else
    {
      root.appendChild(newNode) ;
    }
  }
  else
  {
    // Already in tree - perform a repair
    return false ;
  }
  updateWorkbenchObj() ;
  toggleToolsByRules() ;
  // Don't display the repair action
  return true ;
}

function removeFromPanel(source, e, data)
{
  // Only enable the remove operation for the inputsTree and outputsTree and when moving
  // the mouse, not releasing it as well.
  if(e.type == "mousemove" && data.node.ownerTree.id == source.tree.id && (source.tree.id == 'wbInputsTree' || source.tree.id == 'wbOutputsTree'))
  {
    source.proxy.savedId = data.node.id ;
    source.beforeInvalidDrop = function(target, evnt, id)
    {
      // Flag this as a delete event
      this.proxy.removeFlag = true ;
      this.proxy.afterRepair = function()
      {
        // Make sure we still do the original afterRepair magic
        // NOTE: This is original Ext-JS code, I do not know its purpose, but
        //  it is necessary for proper DD functionality.
        this.hide(true);
        if(typeof this.callback == "function")
        {
          this.callback.call(this.scope || this) ;
        }
        this.callback = null;
        this.scope = null;

        // Now perform our special logic
        if(this.removeFlag && this.savedId)
        {
          var savedId = this.savedId ;
          var child = source.tree.root.findChild("id", savedId) ;
          if(child) source.tree.root.removeChild(child) ;
          delete this.removeFlag ;
          delete this.savedId ;
        }
        updateWorkbenchObj() ;
        toggleToolsByRules() ;
      } ;
      this.proxy.animRepair = false ;
      return true ;
    } ;
  }
}

/**
 * Build the global variable
 */
function updateWorkbenchObj()
{
  inputsArr = [] ;
  outputsArr = [] ;
  /**
   * Get the 'refsUri' attribute from the node containing the API URI for the resource
   * and append it to the inputsArr
   */
  var inputRoot = Ext.ComponentMgr.get("wbInputsTree").root ;
  for(var child = 0; child < inputRoot.childNodes.length; child++)
  {
    inputsArr.push(inputRoot.childNodes[child]['attributes']['refsUri']) ;
  }
  var outputsRoot = Ext.ComponentMgr.get("wbOutputsTree").root ;
  for(var child = 0; child < outputsRoot.childNodes.length; child++)
  {
    outputsArr.push(outputsRoot.childNodes[child]['attributes']['refsUri']) ;
  }
  wbHash.set('inputs', inputsArr) ;
  wbHash.set('outputs', outputsArr) ;
}


/**
 * Perform some bookeeping for the workbench whenever the dataset
 * is changed.
 */
function updateDataset(treeId)
{
  // First handle resizing the drop zone for the dataset .  In order to
  // do this properly, we must wait for the nodes that were added, or removed,
  // to be rendered.  Since there is no event for this, we have to set a
  // timeout that will wait until the rendering occurs.  Of course, we can only
  // take an educated guess as to how long the rendering will take.  At this
  // point in time, I have determined that 50ms is a safe value. SGD
  setTimeout(function()
  {
    var inputsTree = Ext.ComponentMgr.get(treeId) ;
    inputsTree.dropZone.setPadding(0, 0, inputsTree.getInnerHeight() - inputsTree.dropZone.el.getHeight(), 0);
  }, 50) ;
}

/**
 * Clear out all elements of the data set.
 */
function clearDataSet()
{
  var inputsTreeRoot = Ext.ComponentMgr.get('wbInputsTree').getRootNode() ;
  // To avoid calling the updateToolbar for each removed item, disable events
  inputsTreeRoot.suspendEvents() ;

  // Remove all items that were selected
  while (inputsTreeRoot.firstChild)
  {
    inputsTreeRoot.removeChild(inputsTreeRoot.firstChild) ;
  }

  // And resume the events
  updateDataset("wbInputsTree") ;
  inputsTreeRoot.resumeEvents() ;
}




/**
 * TODO - DOCU
 */
function trackMod(action, treeId)
{
  var tree = Ext.ComponentMgr.get(treeId) ;
  var selectionModel = tree.getSelectionModel() ;
  var node = selectionModel.getSelectedNode() ;
  if(node && tree.getNodeById(node.id) && node.getOwnerTree().id == treeId)
  {
    // Pause events so that no grid updating is attempted
    selectionModel.suspendEvents() ;

    var root = tree.getRootNode() ;
    if( action == 'up' || action == 'down' && node != null)
    {
      var pos = root.indexOf(node) ;
      if( action == 'up' && pos > 0)
      {
        var swapNode = node.previousSibling ;
        root.insertBefore(node, swapNode) ;
        selectionModel.select(node) ;
      }
      if( action == 'down' && !(node.nextSibling == null))
      {
        var swapNode = node.nextSibling ;
        root.insertBefore(swapNode, node) ;
        selectionModel.select(node) ;
      }
    }
    if( node!= null && action == 'delete')
    {
      root.removeChild(node) ;
    }

    updateWorkbenchObj() ;
    toggleToolsByRules() ;
    // Don't forget to resume events
    selectionModel.resumeEvents() ;
  }
}

function refreshMainTree()
{
  Workbench.wbMainTreeLoader.load(Workbench.mainTree.root) ;
  Workbench.mainTree.root.expand() ;
}

function filterTree(rsrcList)
{
  if(rsrcList != '')
  {
    Workbench.mainTreeFilter.filterBy(
      function()
      {
        return( this.attributes.rsrcType == 'empty' || this.attributes.rsrcType == 'host' || rsrcList.indexOf((this.attributes.rsrcType == 'fileFolder' ? 'file' : this.attributes.rsrcType)) > 0) ;
      }
    ) ;
  }
  else
  {
    Workbench.mainTreeFilter.clear() ;
  }
}

DetailsLoader = function(detailsPath, hiddenAttrs, attrDisplayOrder, attrFormatters, loaderSettings)
{
  selfObject = this ;
  this.detailsPath = detailsPath ;
  /**
   * Use this array to hide certain attributes.
   */
  this.hiddenAttrs = (hiddenAttrs == undefined) ? [] : hiddenAttrs ;
  /**
   * Use this array to configure the display order of attributes.
   * Array can contain a subset of the attributes in the API response.
   * Attributes not in this array will be appended to the end.
   */
  this.attrDisplayOrder = (attrDisplayOrder == undefined) ? [] : attrDisplayOrder ;
  /**
   * Use object to reformat certain attribute,
   * example:  { attrKey: function(attrValue) { return formatValue(attrValue); } }
   */
  this.attrFormatters = (attrFormatters == undefined) ? [] : attrFormatters ;
  /**
   * Use object to set certain limits and other constants for rendering details.
   **/
  this.settings = (loaderSettings == undefined) ? [] : loaderSettings ;

  /**
   * Try to get the name of the entity in a REST API URL
   */
  this.getEntityName = function(uri)
  {
    var retVal = '' ;
    if(uri)
    {
      qsIndex = uri.indexOf('?') ;
      partialUri = (qsIndex >= 0 ? uri.slice(0, qsIndex) : uri) ;
      match = partialUri.match(/\/([^\/]+)$/)
      if(match)
      {
        retVal = match[1] ;
      }
    }
    return retVal ;
  }


  this.getFromAPI = function(successFunction, failureFunction)
  {
    if(failureFunction == undefined)
    {
      failureFunction = this.handleFailure ;
    }
    // Now request all of the details from the object
    Ext.Ajax.request(
    {
      url: '/java-bin/apiCaller.jsp',
      method: 'POST',
      params:
      {
        rsrcPath: this.detailsPath,
        apiMethod: 'GET'
      },
      success: successFunction,
      failure: failureFunction,
      scope: this
    }) ;
  } ;

  this.loadFromAPI = function(successFunction, replace)
  {
    if(successFunction == undefined || successFunction == null)
    {
      if(replace == undefined || replace == null || replace == false)
      {
        successFunction = this.appendRespToGrid ;
      }
      else
      {
        successFunction = this.replaceRespToGrid ;
      }
    }
    // Now request all of the details from the object
    Ext.Ajax.request(
    {
      url: '/java-bin/apiCaller.jsp',
      method: 'POST',
      params:
      {
        rsrcPath: this.detailsPath,
        apiMethod: 'GET'
      },
      success: successFunction,
      failure: this.handleFailure,
      scope: this
    }) ;
  } ;

  this.appendRespToGrid = function(transport)
  {
    return this.loadRespToGrid(transport, false) ;
  } ;
  this.replaceRespToGrid = function(transport)
  {
    return this.loadRespToGrid(transport, true) ;
  } ;

  /**
   * This is the callback function for the ajax request made to detailsPath
   *
   * From the API response create an array that will be displayed in the details panel.
   */
  this.loadRespToGrid = function(transport, replace)
  {
    if(replace == undefined || replace == null || replace == false)
    {
      replace = false ;
    }
    else
    {
      replace = true ;
    }
    try
    {
      var respObj = Ext.util.JSON.decode(transport.responseText) ;
      var attrArray = this.translateRespForDetails(respObj.data) ;
      this.addDataToGrid(attrArray, replace) ;
      // Make the grid selectable
      var divEls = $$("#wbDetailsGrid .x-grid3-cell-inner") ;
      var ii ;
      for(ii=0; ii<divEls.length; ii++)
      {
        if(divEls[ii].attributes)
        {
          divEls[ii].removeAttribute("unselectable") ;
        }
      }
    }
    catch(err)
    {
      alert("Problem with REST API response") ;
    }
  } ;

  this.addDataToGrid = function(attrArray, replace)
  {
    var detailsStore = Ext.ComponentMgr.get('wbDetailsGrid').store ;
    detailsStore.loadData(attrArray, !replace) ;
  }

  /**
   * This is the default method for translating the API request for resouce details
   * to the attribute array of data displated in the Details Grid.
   * The various configuration objects are handled here or this can be overridden for cusomizable Details
   */
  this.translateRespForDetails = function(respDataObj)
  {
    var attrArray = new Array() ;
    var formattedAttr = null ;
    // Do we have the special "gbFullDetailsFormatter", which can be used
    // to process whole details payload itself?
    if(this.attrFormatters['gbFullDetailsFormatter'] != undefined)
    {
      attrArray = this.attrFormatters['gbFullDetailsFormatter'](respDataObj, detailsPath, this)
    }
    else // Try to find field-specific formaters or fallback to default formatting
    {
      for(var attr in respDataObj)
      {
        formattedAttr = null ;
        if(this.attrFormatters[attr] != undefined)
        {
          /* There's a formatter function defined */
          formattedAttr = this.attrFormatters[attr](respDataObj[attr], respDataObj) ;
        }
        else /* No formatter, do default */
        {
          /* attribute is not to be hidden */
          formattedAttr = [correctCase(attr), respDataObj[attr]] ;
        }

        if(formattedAttr != null)
        {
          /** Did the formatter (if there was one) return just a single row or several rows?
           * If just 1 row, turn it into 1-row table, and then process either situation the same */
          if(!Object.isArray(formattedAttr.first()))
          {
            formattedAttr = [ formattedAttr ] ;
          }
          /** Add each row as appropriate */
          for(var ii=0; ii<formattedAttr.length; ii++)
          {
            var row = formattedAttr[ii] ;
            if(row.length > 0) // Only if this is a non-empty row
            {
              var attrName = row[0] ;
              if(typeof(attrName) !== 'undefined')
              {
                if(this.hiddenAttrs.indexOf(attrName) == -1)
                {
                  attrArray.push(row) ;
                }
              }
            }
          }
        }
      }
      /* Sort details according to this.attrDisplayOrder and then alphabetically. */
      attrArray = attrArray.sort(this.detailRowComparator) ;
    }

    return attrArray ;
  } ;

  this.detailRowComparator = function(aa,bb)
  {
    var retVal = 0 ;
    var aaAttr = aa[0] ;
    var bbAttr = bb[0] ;
    var aaOrder = selfObject.attrDisplayOrder.indexOf(aaAttr) ;
    var bbOrder = selfObject.attrDisplayOrder.indexOf(bbAttr) ;
    if(aaOrder > -1 && bbOrder > -1)
    {
      retVal = (aaOrder < bbOrder ? -1 : (aaOrder > bbOrder ? 1 : 0)) ;
    }
    else if(aaOrder > -1)
    {
      retVal = -1 ;
    }
    else if(bbOrder > -1)
    {
      retVal = 1 ;
    }
    else
    {
      var aaLc = aaAttr.toLowerCase() ;
      var bbLc = bbAttr.toLowerCase() ;
      retVal = (aaLc < bbLc ? -1 : (aaLc > bbLc ? 1 : 0)) ;
    }
    return retVal ;
  } ;

  this.handleFailure = function(response)
  {
    displayFailureDialog(response, 'Problem loading details') ;
  } ;
}
