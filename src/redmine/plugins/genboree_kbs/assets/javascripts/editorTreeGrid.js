function getCurrentSearchBoxData()
{
  var retVal = null ;
  if (Ext.getCmp('searchComboBox')) {
    var storeItems = Ext.getCmp('searchComboBox').store.data.items ;
    var ii ;
    var searchBoxData =[] ;
    for(ii=0; ii<storeItems.length; ii++){
      var value = storeItems[ii].raw.value ;
      searchBoxData.push( { "value": value } ) ;
    }
    retVal = searchBoxData ;
  }
  return retVal ;
}


// Initializes editor tree grid for editing documents
// Will and should destroy other ExtJS structures/objects which are displayed in the same panel as the editor tree grid.
function initTreeGrid(currentSearchBoxData)
{
  
  resetMainPanel() ;
  initTreeGridToolbar() ;
  var rowEditing = initRowEditingPlugin() ;
  disablePanelBtn('docHistory') ;
  if(docModel)
  {
    createSearchStore(docModel) ;
    Ext.getCmp('searchComboBox').setValue('') ;
  }
  var tree = Ext.create('Ext.tree.Panel', {
      title: 'Edit Mode: OFF',
      //width: let it autoscale
      height: panelHeight-35, // set height to total hight of layout panel - height of menubar
      renderTo: 'treeGridContainer-body',
      collapsible: false,
      useArrows: true,
      id: 'mainTreeGrid',
      rootVisible: false,
      listeners: {
        select: function(thisObj, record, index, eOpts){
          toggleBtns('mainTreeGrid', record) ;
        },
        itemclick: function(view, record, item, index, e){
          selectedRecord = record ;
        },
        itemmouseenter: function(thisObj, record, item, index, e, eOpts){
          registerQtips(1500, 0, 5000) ; // defined in misc.js
          selectedRecord = record ;
        },
        itemcontextmenu: function(thisObj, record, item, index, e, eOpts){
          displayPropMenu(e, true)
        },
        beforeitemexpand: function(node, eOpts) {
          if (newdocObj) {
            Ext.suspendLayouts() ;
          }
        },
        afteritemexpand: function(node, index, item , eOpts){
          // We were given a property path to find and expand.
          // This should already be selected and expanded.
          // The block below is required to scroll to the selected node and set displayPropPath back to empty.
          if (displayPropPath != "") {
            var tree = Ext.getCmp('mainTreeGrid') ;
            var rowNum = tree.getSelectionModel().getCurrentPosition().row ;
            tree.scrollByDeltaY(rowNum*20) ;
            displayPropPath = '' ;
          }
          if (newdocObj) {
            Ext.resumeLayouts(true) ;
          }
        }
      },
      multiSelect: false,
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
      tbar: Ext.getCmp('mainTreeGridToolbar'), // defined in toolbars.js
      singleExpand: false,
      selType: 'rowmodel',
      plugins: [rowEditing], // defined in rowEditing.js
      //the 'columns' property is now 'headers'
      columns:
      [
        {
          xtype: 'treecolumn', //this is so we know which column will show the tree
          text: 'Name',
          flex: 2,
          //minWidth: 300,
          dataIndex: 'name',
          menuDisabled: true,
          sortable: false,
          //editable: false
          editor: {
            xtype: 'textfield'
          },
          renderer: function(value, md, rec, ri, ci, store, view){
            var retVal = "<span ";
            if(md.record.data.description)
            {
              retVal = retVal + 'data-qtip='+'"'+md.record.data.description+'"' ;
            }
            if(md.record.data.category)
            {
              retVal = retVal +" class=\"genbKb-category-font-weight\">"+value ;
            }
            else
            {
              retVal = retVal + ">"+value ;
            }
            retVal = retVal + "</span>" ;
            var id = Math.random() ;
            var menuBtnLink = "<a id="+id+" data-qtip='Click to open context menu.' href=\"\" onclick=\"return displayPropMenu(this.id, false)\">"+"<img class=\"genbKb-prop-menu-default\" src='plugin_assets/genboree_kbs/images/silk/application_view_list.png'>"+"</a>" ;
            //var menuBtnLink = "<a style=\"float:left;\" href=\"javascript:showPropMenu()\">"+"menu"+"</a>" ;
            retVal = retVal + menuBtnLink ;
            return retVal ;
          }
       },
       {
          text: 'Value',
          sortable: false,
          menuDisabled: true,
          flex: 1,
          minWidth: 300,
          dataIndex: 'value',
          editor: {
            xtype: 'textfield'
          },
          renderer: function(value, md, rec, ri, ci, store, view){
            var retVal ;
            var grpKbCollDocRegExp = /\/REST\/v1\/grp\/([^/\?]+)\/kb\/([^/\?]+)\/coll\/([^/\?]+)\/doc\/([^/\?]+)/ ;
            var grpKbCollRegExp = /\/REST\/v1\/grp\/([^/\?]+)\/kb\/([^/\?]+)\/coll\/([^/\?]+)/ ;
            var relativePathCollDocRegExp = /\/coll(ection)?\/([^/\?]+)\/doc(ument)?\/([^/\?]+)/ ;
            var relativePathDocRegExp = /\/doc(ument)?\/([^/\?]+)/ ;
            if(md.record.data.domain && md.record.data.domain == 'url')
            {
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
            }
            else if (md.record.data.domain && md.record.data.domain == 'fileUrl') {
              if (value.match(/\/REST\/v1\/grp/))
              {
                value = "<a href=\"javascript:downloadFile('"+escape(value)+"')\">"+unescape(value)+"</a>" ;
              }
              else
              {
                value = "<a target=\"_blank\" href=\""+value+"\">"+value+"</a>" ;
              }
            }
            else if (md.record.data.domain && md.record.data.domain == 'labelUrl') {
              // Extract the label and the URL parts from the value
              if (value != '') {
                var valCompts = value.split("|") ;
                var labelVal = valCompts[0] ;
                var urlVal = valCompts[1] ;
                value = "<a target=\"_blank\" href=\""+urlVal+"\">"+labelVal+"</a>" ;
              }
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
            if (md.record.data.domain && md.record.data.domain.match(/autoID/)) {
              if (md.record.data.value == "" ) {
                retVal += "<span data-qtip=\"This property is tagged as an autoID property. You can leave it empty and an appropriate value will be set when you save the document.\"><img  src=\"../images/silk/pencil_go.png\" width=\"12\" height=\"12\"></span>"
              }
            }
            else{
              if (md.record.data.editRequired && md.record.data.editRequired == true) {
                retVal += "<span data-qtip=\"It is recommended that this property be edited before saving.\"><img  src=\"../images/silk/pencil.png\" width=\"12\" height=\"12\"></span>"
              }
            }
            return retVal ;
          }
        }
      ]
  });
  // Load up the contents of the previous contents of search box. We don't want to lose that.
  if (currentSearchBoxData) {
    Ext.getCmp('searchComboBox').getStore().loadData(currentSearchBoxData) ;
  }
  else{
    // Looks like we have not been been provided with any list of docs to load in search box. Load a fresh set if a collection is already selected
    if (Ext.getCmp('collectionSetCombobox') && Ext.getCmp('collectionSetCombobox').value != "") {
      loadInitialDocList(false) ;
    }
  }
}


// Displays the property-menu when a property is right clicked or small icon adjacent (which pops when a row is hovered over) is clicked
// Provides functionality to add child properties, remove property (and its sub-properties), expand, collapse and reorder (for items)
// If showAt = true, e will be the event which will be used to get the x-y coordinates to place the menu, otherwise it will be the id of the element *by* which the menu will be displayed
function displayPropMenu(e, showAt)
{
  var record = selectedRecord ;
  // Destroy the previous menu if present
  if (Ext.getCmp('propertyContextMenu')) {
    Ext.getCmp('propertyContextMenu').close() ;
  }
  if (showAt) {
    e.preventDefault() ;
  }
  var propMenu = Ext.create('Ext.menu.Menu', {
    id: 'propertyContextMenu',
    plain: true,
    floating: true,
    draggable: true,
    items: [
      {
        itemId: 'addChildRow',
        disabled: true,
        text: 'Add',
        icon: 'plugin_assets/genboree_kbs/images/silk/add.png',
        tooltip: {
          title: 'Add Child',
          text: 'Add child records (sub-properties) to existing properties.'
        },
        handler : addChildNode // defined in misc.js
      },
      {
        itemId: 'removeRow',
        text: 'Remove',
        icon: 'plugin_assets/genboree_kbs/images/silk/delete.png',
        tooltip: {
          title: 'Remove',
          text: 'Remove properties. Removing a property with sub-properties will remove all its children properties.'
        },
        handler: removeNode, // defined in misc.js
        disabled: true
      },
      
      {
        itemId: 'expandPropBtn',
        disabled: true,
        text: 'Fully Expand',
        icon: 'plugin_assets/genboree_kbs/images/silk/arrow_out.png',
        tooltip: {
          title: 'Expand',
          text: 'Recursively expand the selected property. Only enabled if property has sub-properties and the total number of sub-properties is less than 5,000.'
        },
        handler : function(){
          record.expand(true) ;
        }
      },
      {
        itemId: 'collapsePropBtn',
        disabled: true,
        text: 'Fully Collapse',
        icon: 'plugin_assets/genboree_kbs/images/silk/arrow_in.png',
        tooltip: {
          title: 'Collapse',
          text: 'Recursively collapse the selected property. Only available for properties with sub-properties.'
        },
        handler : function(){
          record.collapse(true) ;
        }
      },
      {
        itemId: 'reorder',
        disabled: true,
        text: "Reorder",
        handler: function(){
          this.showMenu() ;
        },
        tooltip: {
          title: 'Reorder items',
          text: 'Reorder one or more items in a list. Button only active when a list item is selected and there are at least 2 records in the list.'
        },
        icon: 'plugin_assets/genboree_kbs/images/Up-down.png',
        xtype: 'splitbutton',
        arrowAlign: 'right',
        menu: [
          { text: 'Move to bottom', handler: function(aa, bb){
              reorderItems(aa.text, selectedRecord) ; // defined in misc.js
          }},
          { text: 'Move to top', handler: function(aa, bb){
              reorderItems(aa.text, selectedRecord) ;
          }},
          { text: 'Move one record down', handler: function(aa, bb){
              reorderItems(aa.text, selectedRecord) ;
          }},
          { text: 'Move one record up', handler: function(aa, bb){
              reorderItems(aa.text, selectedRecord) ;
          }}
        ]
      }
    ]
  }) ;
  if (showAt) {
    propMenu.showAt(e.getXY()) ;
  }
  else{
    propMenu.showBy(e) ;
  }
  toggleBtns('propertyContextMenu', record) ;
  return false ;
}

// Downloads file for a 'fileUrl' property
function downloadFile(fileUrl)
{
  checkFile(fileUrl) ;
}

function checkFile(fileUrl)
{
  maskObj.show() ;
  var url = 'genboree_kbs/doc/checkFile' ;
  var timeout = 900000 ;
  var params = {
    "authenticity_token": csrf_token,
    project_id: projectId,
    fileUrl: fileUrl
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
        appendIframe('genboree_kbs/doc/downloadfile?authenticity_token='+csrf_token+'&project_id='+projectId+'&fileUrl='+escape(fileUrl)) ;
      }
      else
      {
        var displayMsg = "The following error was encountered while downloading the file:<br><br>" ;
        displayMsg += ( "<b>Error Code:</b> <i>" + (statusObj['statusCode'] ? statusObj['statusCode'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" );
        displayMsg += ( "<b>Error Message:</b> <i>" + (statusObj['msg'] ? statusObj['msg'] : "[ NOT INTELLIGIBLE ]") + "</i>" );
        displayMsg += "<br><br>Please contact a project admin to arrange investigation and resolution." ;
        Ext.Msg.alert("ERROR", displayMsg) ;
      }
    }
    catch(err)
    {
      Ext.Msg.alert('ERROR: '+err, "Bad data returned from server when checking the existence of the file.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
    }
  }
  var method = "GET" ;
  genericAjaxCall(url, timeout, method, params, callback) ;
}

// Get the role of the user
// Only authors and admins are allowed to edit/save/delete
// This role is the Genboree role
function getRole()
{
  Ext.Ajax.request(
  {
    url     : 'genboree_kbs/role',
    timeout : 90000,
    method  : 'GET',
    params  :
    {
      "authenticity_token"  : csrf_token,
      project_id            : projectId
    },
    callback : function(opts, success, response)
    {
      try
      {
        var apiRespObj  = JSON.parse(response.responseText) ;
        var roleObj      = apiRespObj['data'] ;
        var statusObj   = apiRespObj['status'] ;

        if(response.status >= 200 && response.status < 400 && roleObj)
        {
          role = roleObj['role'] ;
          if (role == 'subscriber') {
            Ext.Msg.alert('Warning', "As a subscriber of this Genboree KB, you are only allowed to view documents. Operations involving editing/deleting/saving are only allowed for authors and administrators.")
          }
          activateJobSummaryBtn() ;
        }
        else
        {
          var displayMsg = "The following error was encountered while retrieving the genboree role for the current user:<br><br>" ;
          displayMsg += ( "<b>Error Code:</b> <i>" + (statusObj['statusCode'] ? statusObj['statusCode'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" );
          displayMsg += ( "<b>Error Message:</b> <i>" + (statusObj['msg'] ? statusObj['msg'] : "[ NOT INTELLIGIBLE ]") + "</i>" );
          displayMsg += "<br><br>Please contact a project admin to arrange investigation and resolution." ;
          // Force role to be subscriber since the target group can be public and the user may not be required to be a member of the group.
          role = 'subscriber' ;
          activateJobSummaryBtn() ;
          Ext.Msg.alert('Warning', "As a subscriber of this Genboree KB, you are only allowed to view documents. Operations involving editing/deleting/saving are only allowed for authors and administrators.") ;
          //Ext.Msg.alert("ERROR", displayMsg) ;
        }
      }
      catch(err)
      {
        Ext.Msg.alert('ERROR', "Bad data returned from server when retrieving the role.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
      }
    }
  }) ;
}

function activateJobSummaryBtn()
{
  var containerToolbar = Ext.getCmp('containerPanelToolbar') ;
  var items = containerToolbar.items.items ;
  var ii ;
  for (ii=0; ii<items.length; ii++) {
    if (items[ii].itemId == 'jobSummaryBtn') {
      items[ii].enable() ;
      break ;
    }
  }
}

function addDocTools()
{
  var docToolBtns = Ext.getCmp('mainTreeGridToolbar').items.items ;
  var docToolBtn ;
  for(ii=0; ii<docToolBtns.length; ii++)
  {
    if (docToolBtns[ii].itemId == 'docToolsBtn') {
      docToolBtn = docToolBtns[ii] ;
    }
  }
  try {
    docToolBtn.menu.removeAll() ;
    for(ii=0; ii<docTools.length; ii++)
    {
      docToolBtn.menu.add(docTools[ii]) ;
    }
  }
  catch(err){
    docToolBtn.disable() ;
  }
}

// AJAX call to get the 'Genboree' database the kb is associated with
// This database is used when files are uploaded/downloaded for certain properties of documents.
// If the kb is not associated with a KB, the rest of the functionality will still work but file uploads won't.
function getGenboreeDb()
{
  Ext.Ajax.request(
  {
    url     : 'genboree_kbs/user/getdb',
    timeout : 90000,
    method  : 'GET',
    params  :
    {
      "authenticity_token"  : csrf_token,
      project_id            : projectId
    },
    callback : function(opts, success, response)
    {
      try
      {
        var apiRespObj  = JSON.parse(response.responseText) ;
        var kbObj      = apiRespObj['data'] ;
        var statusObj   = apiRespObj['status'] ;

        if(response.status >= 200 && response.status < 400 && kbObj)
        {
          kbDb = kbObj['name']['properties']['kbDbName']['value'] ;
        }
        else
        {
          var displayMsg = "The following error was encountered while retrieving the kb information (to get the database the kb is associated with) for the current user:<br><br>" ;
          displayMsg += ( "<b>Error Code:</b> <i>" + (statusObj['statusCode'] ? statusObj['statusCode'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" );
          displayMsg += ( "<b>Error Message:</b> <i>" + (statusObj['msg'] ? statusObj['msg'] : "[ NOT INTELLIGIBLE ]") + "</i>" );
          displayMsg += "<br><br>Please contact a project admin to arrange investigation and resolution." ;
          Ext.Msg.alert("ERROR", displayMsg) ;
        }
      }
      catch(err)
      {
        // This is not a critical error. Having no associated db just means files cannot be uploaded.
      }
    }
  }) ;
}

function renderDocTreeGrid()
{
  var currentSearchBoxData = getCurrentSearchBoxData() ;
  resetMainPanel() ;
  disablePanelBtn('editDelete') ;
  disablePanelBtn('docHistory') ;
  initTreeGrid(currentSearchBoxData) ;
  editModeValue = false ; // This is returned from the 'before edit' event of the row plugin.
  Ext.getCmp('mainTreeGrid').setTitle('Edit Mode: OFF') ;
  toggleNodeOperBtn(false) ;
  // Make sure the other grids are deselected
  Ext.getCmp('manageDocsGrid').getSelectionModel().deselectAll() ;
  Ext.getCmp('manageModelsGrid').getSelectionModel().deselectAll() ;
  if(docModel) {
    Ext.getCmp('searchComboBox').enable() ;
    if (prevDocId) {
      Ext.getCmp('searchComboBox').setValue(prevDocId) ;
      prevDocId = null ;
    }
  }
}

// Give the user options when a link is clicked
// Options include staying on the same tab, opening a new tab and canceling
function displayLinkOpts(url, initTreeGridFlag, linkColl, linkId, ver)
{
  var retVal = false ;
  var linkCollection = unescape(linkColl) ;
  var linkIdentifier = ( linkId ? unescape(linkId) : linkId ) ;
  Ext.Msg.show({
    title: "Select link option",
    msg: 'What would you like to do with the link?</br><b>NOTE</b>: Opening the link in the current tab will replace the tab\'s contents.',
    buttonText: {yes: 'Open link in current tab', no: 'Open link in new tab', cancel: 'Cancel'},
    height: 130,
    width: 400,
    fn: function(btn)
    {
      if(btn == 'yes')
      {
        if (initTreeGridFlag) {
          renderDocTreeGrid() ;
          Ext.getCmp('browseDocsGrid').getSelectionModel().select(0) ;
        }
        var currentColl = Ext.getCmp('collectionSetCombobox').value ;
        if(currentColl != linkCollection)
        {
          loadModel(linkCollection, linkIdentifier) ; // defined in ajax.js
        }
        else
        {
          if(linkIdentifier)
          {
            if (ver && ver != "") {
              docVersion = ver ;
            }
            loadDocument(linkIdentifier, false) ; // defined in ajax.js
          }
        }
      }
      else if(btn == 'no')
      {
        var win = window.open(url, '_blank') ;
        win.focus() ;
      }
    }
  }) ;
  return retVal ;
}




// Enable the 'addChild', 'addSibling' and remove btns depending on the selected row
// This function is utilized by both the editor-treegrid toolbar and the floating menu for a property
function toggleBtns(elId, record)
{
  // Skip enabling any button if edit mode if off
  var btns ;
  if (elId == 'mainTreeGrid') {
    btns = Ext.getCmp(elId).getDockedItems()[1].items.items ;
  }
  else
  {
    btns = Ext.getCmp(elId).items.items ;
  }
  var addChildBtn  ;
  var removeBtn ;
  var reorder ;
  var expandProp ;
  var collapseProp ;
  var ii ;
  for(ii=0; ii<btns.length; ii++)
  {
    if(btns[ii].itemId == 'addChildRow')
    {
      addChildBtn = btns[ii] ;
    }
    else if(btns[ii].itemId == 'removeRow')
    {
      removeBtn = btns[ii] ;
    }
    else if(btns[ii].itemId == 'reorder')
    {
      reorder = btns[ii] ;
    }
    else if (btns[ii].itemId == 'expandPropBtn') {
      expandProp = btns[ii] ;
    }
    else if (btns[ii].itemId == 'collapsePropBtn') {
      collapseProp = btns[ii] ;
    }
    else
    {
      // Nothing to do
    }
  }
  // Disable the delete button only if the prop is required and not the root prop of an item list
  // Note that the root prop of an item list is implicitly required. However, since an item list can have 0 or more items, the user should be able to remove an item
  if(record.data.required && !record.parentNode.data.modelAddress.items)
  {
    removeBtn.disable()
  }
  else
  {
    if (editModeValue) {
      removeBtn.enable() ;  
    }
  }
  if(record.data.leaf) // Disable addChild btn if node is a leaf node
  {
    addChildBtn.disable() ;
    if (elId != 'mainTreeGrid') {
      
      expandProp.disable() ;
      collapseProp.disable() ;
    }
  }
  else
  {
    if (elId != 'mainTreeGrid') {
      // Make sure the node doesn't have too many nodes: this can cause the browser to hang
      var nnodes = getNoOfAllChildNodes(record) ;
      if (nnodes < 5000) {
        expandProp.enable() ;
      }
      collapseProp.enable() ;
    }
    if (editModeValue) {
      toggleAddChildBtn(record, addChildBtn) ; // defined in misc.js
    }
  }
  // Check if the reorder btn can be enabled
  if(record.parentNode.data.docAddress.items && record.parentNode.data.docAddress.items.length > 1 && editModeValue)
  {
    reorder.enable() ;
  }
  else
  {
    reorder.disable() ;
  }
}

getNoOfAllChildNodes = function(Mynode){
 var totalNodesCount = 0;
 recurFunc = function(Node){
  if(Node.hasChildNodes() == false){
   return 0;
  }else if(Node.hasChildNodes()){
   totalNodesCount += Node.childNodes.length;
   Node.eachChild(recurFunc);
  }
 }

 if(Mynode.hasChildNodes() == false){
  return 0;
 }else if(Mynode.hasChildNodes()){
  totalNodesCount += Mynode.childNodes.length;
  Mynode.eachChild(recurFunc);
 }
 return totalNodesCount;
}

// Closes all open grids and cleans the main panel
function resetMainPanel()
{
  docTools = [] ;
  showModelTree = false ;
  destroyModelTree() ;
  destroyEditorTree() ;
  destroyViewGrid() ;
  destroyModelVersionsGrid() ;
  destroyDocsVersionsGrid() ;
  destroyKbStatsPanel() ;
  destroyQuestionnaireGrid() ;
}
