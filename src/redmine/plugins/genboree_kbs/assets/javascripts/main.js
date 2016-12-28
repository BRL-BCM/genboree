Ext.onReady(function() {
  Ext.require([
    'Ext.data.*',
    'Ext.grid.*',
    'Ext.tree.*'
  ]);
  maskObj = new Ext.LoadMask(Ext.getBody(), {msg:"Loading..."});
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
    var forbiddenPatt = /^FORBIDDEN/ ;
    var collErrMsg = httpResponse ;
    if (httpResponse.match(forbiddenPatt))
    {
      collErrMsg = "<font color=\"red\"><b>"+httpResponse+"</b></font>" ;
    }
    var errMsg = "Error encountered while retrieving the Collection list:</br></br>"+collErrMsg+"</br></br>Please contact a project administrator for help resolving this issue." ;
    Ext.Msg.show({
      title:'ERROR',
      msg: errMsg,
      buttons: Ext.Msg.OK,
      icon: Ext.Msg.ERROR
    });
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
    // Also try to get the genboree database the kb is associated with
    getGenboreeDb() ;
  }
  /*
   * Start preparing the all-encapsulating panel.
   * This will contain all the grid/tables etc.
   */
  initContainerPanelToolbar() ;
  var westPanelWidth = panelWidth - 715 ;
  Ext.create('Ext.panel.Panel', {
    width: panelWidth,
    height: panelHeight, // Add pixels for tool bar
    //title: 'Genboree KB - Tree Grid Editor',
    tbar: Ext.getCmp('containerPanelToolbar'),
    //header: true,
    layout: 'border',
    items:
    [
      {
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
      },
      {
        title: 'Editable Tree Grid',
        header: false,
        region: 'center',     // center region is required, no width/height specified
        xtype: 'panel',
        layout: 'fit',
        id: 'treeGridContainer',
        overflowX: 'auto',
        margins: '5 5 0 0'
      }
    ],
    renderTo: 'layoutContainerDiv'
  });
  if (httpResponse == "OK") {
    if (collection != "") {
      // Load up the model
      //   - depending on what kind of URL params have been provided, do the needful
      loadModel(collection, docIdentifier) ;
    }
    else{
      displayKbStats('kb') ;  
    }
  }
});