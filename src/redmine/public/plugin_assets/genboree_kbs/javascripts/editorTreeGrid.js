
Ext.onReady(function() {
  Ext.require([
    'Ext.data.*',
    'Ext.grid.*',
    'Ext.tree.*'
  ]);
  
  // Required override for fixing bug with row-editing plugin now allowing setEditor() function.
  Ext.grid.plugin.RowEditing.override({
    setColumnField: function(column, field) {
      var me = this,
          editor = me.getEditor();

      editor.removeColumnEditor(column);
      Ext.grid.plugin.RowEditing.superclass.setColumnField.apply(this, arguments);
      me.getEditor().addFieldsForColumn(column, true);
      me.getEditor().insertColumnEditor(column);
    }
  });
  Ext.tip.QuickTipManager.init();
  Ext.tip.QuickTipManager.getQuickTip().addCls('genbKb-tooltip-wordwrap') ;
  // Prepare the collection list store
  if(httpResponse != "OK")
  {
    Ext.Msg.alert('ERROR', 'The following HTTP error was encountered while retrieving the KB collection list:</br></br>'+httpResponse+'.</br></br>Please contact the administrator to resolve this issue.') ;
    collectionSetStore = Ext.create('Ext.data.Store', {
          fields: ['name', 'value'],
          data : []
        }) ;
  }
  else
  {
    var collectionObj = JSON.parse(collectionList) ;
    var collData = []
    var ii ;
    for(ii=0; ii<collectionObj.length; ii++)
    {
      collData.push( { 'name': collectionObj[ii].text.value, 'value': collectionObj[ii].text.value } ) ;
    }
    collectionSetStore = Ext.create('Ext.data.Store', {
      fields: ['name', 'value'],
      data : collData
    }) ;
    // Try to get the Genboree role of the user 
    getRole() ;
  }
  
  // Initialize the tool bar for the main wrapping panel
  var containerPanelToolbar = new Ext.Toolbar({
    width:'auto',
    id: 'containerPanelToolbar',
    items:
    [
      {
        xtype: 'tbtext',
        text: '<b style="font-size:13px;">Collection:</b>'
      },
      {
        xtype: 'combobox',
        displayField: 'name',
        valueField: 'value',
        id: 'collectionSetCombobox',
        width: 200,
        queryMode: 'local',
        emptyText: 'Select data set',
        editable: false,
        // load up the appropriate the data
        listeners: {
          select: function(e){
            // Load up the right model
            loadModel(Ext.getCmp('collectionSetCombobox').value, false) ; // defined in ajax.js
          }
        },
        store: collectionSetStore
      },
      {
        xtype: 'tbfill'
      },
      {
        itemId: 'helpInfo',
        //text: 'Remove',
        icon: 'plugin_assets/genboree_kbs/images/silk/help.png',
        tooltip: {
          title: 'Help',
          text: 'To browse documents, select a collection from the <b>Collection</b> drop-down. Next, start typing in the search text box on the grid tool bar to see available documents. Select a document to visualize/edit it.'
        }
      }
    ]
  }) ;
  
  // This is the panel which houses the functionality tool bar (in the west panel) and the editable tree grid (in the central panel).
  var westPanelWidth = panelWidth - 715 ;
  Ext.create('Ext.panel.Panel', {
    width: panelWidth,
    height: panelHeight, // Add pixels for tool bar
    //title: 'Genboree KB - Tree Grid Editor',
    tbar: containerPanelToolbar,
    //header: true,
    layout: 'border',
    items: [{
        region:'west',
        header: false,
        xtype: 'panel',
        margins: '5 0 0 5',
        width: westPanelWidth,
        id: 'west-region-container',
        layout:
        {
          type  : 'vbox',
          pack  : 'start',
          align : 'stretch'
        },
        items: funcGrids // defined in funcGrids.js
    },{
        title: 'Editable Tree Grid',
        header: false,
        region: 'center',     // center region is required, no width/height specified
        xtype: 'panel',
        layout: 'fit',
        id: 'treeGridContainer',
        overflowX: 'auto',
        margins: '5 5 0 0'
    }],
    renderTo: 'layoutContainerDiv'
  });
  // Initialize the tree grid
  initTreeGrid() ;
  // Initialize the page with the 'As Dynamic tree' option selected on the left panel
  Ext.getCmp('browseDocsGrid').getView().select(0) ;
  // If the collection and/or the document idenitfier has already been provided in the URL, load up the model and the document
  if(collection != "" && httpResponse == "OK")
  {
    loadModel(collection, docIdentifier) ; // defined in ajax.js
  }
  Ext.getCmp('manageDocsGrid').on('beforeselect', function(aa, bb){
    var retVal = true ;
    var funcName = bb.data.recordFuncName ;
    if(funcName == 'Bulk Document upload' || funcName == 'Document history' || role == null || role == 'subscriber')
    {
      retVal = false ;
    }
    else
    {
      if(funcName == 'Create new Document')
      {
        if(docModel) // model has been loaded
        {
          Ext.getCmp('browseDocsGrid').getSelectionModel().deselectAll() ;
          Ext.getCmp('manageModelsGrid').getSelectionModel().deselectAll() ;
          createNewDocument() ;
        }
        else
        {
          retVal = false ;
        }
      }
      else
      {
        if(newdocObj) // document has been loaded
        {
          if(funcName == 'Edit Document')
          {
            editModeValue = true ; // This is returned from the 'before edit' event of the row plugin.
            if(documentEdited)
            {
              Ext.getCmp('mainTreeGrid').setTitle(getModifiedTitle(editModeValue)) ;
            }
            else
            {
              Ext.getCmp('mainTreeGrid').setTitle('Edit Mode: ON') ;  
            }
            toggleNodeOperBtn(true) ;
          }
          else
          {
            Ext.Msg.show({
              title: "Delete Document",
              msg: "This will permanently delete the document. Are you sure you want to continue?",
              buttons: Ext.Msg.YESNO,
              id: 'deleteDocumentMessBox',
              fn: function(btn){
                var selModel = Ext.getCmp('manageDocsGrid').getSelectionModel() ;
                if(btn == 'yes')
                {
                  clearAndReloadTree(null) ;
                  disableEditDelete() ;
                  selModel.deselectAll() ;
                  Ext.getCmp('mainTreeGrid').setTitle('Edit Mode: OFF') ;
                  editModeValue = false ; // This is returned from the 'before edit' event of the row plugin.
                  toggleNodeOperBtn(false) ;
                  newdocObj = null ;
                  // delete the document from the database/server
                  if(!freshDocument)
                  {
                    var identifier = Ext.getCmp('searchComboBox').value
                    deleteDocument(identifier) ; // defined in ajax.js
                  }
                }
                else
                {
                  selModel.deselect(selModel.store.data.items[2]) ;
                  selModel.select(selModel.store.data.items[1]) ;
                }
              }
            }) ;
          }
          Ext.getCmp('browseDocsGrid').getSelectionModel().deselectAll() ;
          Ext.getCmp('manageModelsGrid').getSelectionModel().deselectAll() ;
        }
        else
        {
          retVal = false ;
        }
      }
      
    }
    return retVal ;
  }) ;
});


function initTreeGrid()
{
  if(Ext.getCmp('mainTreeGrid'))
  {
    Ext.getCmp('mainTreeGrid').destroy() ;
  }
  initTreeGridToolbar() ;
  var rowEditing = initRowEditingPlugin() ;
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
        select: toggleBtns,
        itemclick: function(view, record, item, index, e){
          selectedRecord = record ;
        },
        afteritemexpand: function(thisObj, eOpts){
          registerQtips() ; // defined in misc.js
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
            var retVal ;
            if(md.record.data.category)
            {
              retVal = "<span class=\"genbKb-category-font-weight\">"+value+"</span>" ;
            }
            else
            {
              retVal = value ;
            }
            // Add description as tooltip
            if(md.record.data.description)
            {
              md.tdAttr = 'data-qtip='+'"'+md.record.data.description+'"' ;
            }
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
                    value = "<a target=\"_blank\" onclick=\"return displayLinkOpts(this.href); \" href=\""+urlLink+"\">"+value+"</a>" ;
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
                    value = "<a target=\"_blank\" onclick=\"return displayLinkOpts(this.href); \" href=\""+urlLink+"\">"+value+"</a>" ;
                  }
                }
                else if(path.match(relativePathCollDocRegExp))
                {
                  var mm = path.match(relativePathCollDocRegExp) ;
                  linkIdentifier = unescape(mm[4]) ;
                  linkCollection = unescape(mm[2]) ;
                  var urlLink = "http://"+location.host+kbMount+ "/genboree_kbs?project_id="+projectIdentifier+"&coll="+mm[2]+"&doc="+mm[4] ;
                  value = "<a target=\"_blank\" onclick=\"return displayLinkOpts(this.href); \" href=\""+urlLink+"\">"+value+"</a>" ;
                }
                else if(path.match(relativePathDocRegExp))
                {
                  var mm = path.match(relativePathDocRegExp) ;
                  linkIdentifier = unescape(mm[2]) ;
                  // Assume collection is the current one
                  linkCollection = Ext.getCmp('collectionSetCombobox').value ;
                  var urlLink = "http://"+location.host+kbMount+"/genboree_kbs?project_id="+projectIdentifier+"&coll="+escape(linkCollection)+"&doc="+mm[2] ;
                  value = "<a target=\"_blank\" onclick=\"return displayLinkOpts(this.href); \" href=\""+urlLink+"\">"+value+"</a>" ;
                }
                else // Assume just the doc identifier
                {
                  linkIdentifier = unescape(value) ;
                  // Assume collection is the current one
                  linkCollection = Ext.getCmp('collectionSetCombobox').value ;
                  var urlLink = "http://"+location.host+kbMount+"/genboree_kbs?project_id="+projectIdentifier+"&coll="+escape(linkCollection)+"&doc="+value ;
                  value = "<a target=\"_blank\" onclick=\"return displayLinkOpts(this.href); \" href=\""+urlLink+"\">"+value+"</a>" ;
                }
              }
              else
              {
                value = "<a target=\"_blank\" href=\""+value+"\">"+value+"</a>" ;
              }
            }
            else
            {
              var id = Math.random() ;
              var origVal = value ;
              value = "<div"+" id="+id+">"+value+"</div>" ;
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
      ]
  });
  
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
        }
        else
        {
          var displayMsg = "The following error was encountered while retrieving the genboree role for the current user:<br><br>" ;
          displayMsg += ( "<b>Error Code:</b> <i>" + (statusObj['statusCode'] ? statusObj['statusCode'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" );
          displayMsg += ( "<b>Error Message:</b> <i>" + (statusObj['msg'] ? statusObj['msg'] : "[ NOT INTELLIGIBLE ]") + "</i>" );
          displayMsg += "<br><br>Please contact a project admin to arrange investigation and resolution." ;
          Ext.Msg.alert("ERROR", displayMsg) ;
        }
      }
      catch(err)
      {
        Ext.Msg.alert('ERROR', "Bad data returned from server when retrieving the role.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
      }
    }
  }) ;
}

// Give the user options when a link is clicked
// Options include staying on the same tab, opening a new tab and canceling
function displayLinkOpts(url)
{
  var retVal = false ;
  Ext.Msg.show({
    title: "Select link option",
    msg: 'What would you like to do with the link?</br><b>NOTE</b>: Opening the link in the current tab will replace the current document.',
    buttonText: {yes: 'Open link in current tab', no: 'Open link in new tab', cancel: 'Cancel'},
    height: 130,
    width: 400,
    fn: function(btn)
    {
      if(btn == 'yes')
      {
        var currentColl = Ext.getCmp('collectionSetCombobox').value ;
        if(currentColl != linkCollection)
        {
          loadModel(linkCollection, linkIdentifier) ; // defined in ajax.js
        }
        else
        {
          if(linkIdentifier)
          {
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
function toggleBtns(view, record)
{
  
  //debugger ;
  if(editModeValue)
  {
    var btns = Ext.getCmp('mainTreeGrid').getDockedItems()[1].items.items ;
    var addChildBtn  ;
    var removeBtn ;
    var reorder ;
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
      else
      {
        // Nothing to do
      }
    }
    if(record.raw.required)
    {
      removeBtn.disable()
    }
    else
    {
      removeBtn.enable() ;  
    }
    if(record.raw.leaf) // Disable addChild btn if node is a leaf node
    {
      addChildBtn.disable() ;
    }
    else
    {
      toggleAddChildBtn(record, addChildBtn) ; // defined in misc.js
    }
    // Check if the reorder btn can be enabled
    if(record.parentNode.data.docAddress.items && record.parentNode.data.docAddress.items.length > 1)
    {
      reorder.enable() ;
    }
    else
    {
      reorder.disable() ;
    }
  }
}
