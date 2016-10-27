function createStatsPanelConfig(scope)
{
  var scale = 220 ;
  var panelTitle = ( scope == 'coll' ? Ext.getCmp('collectionSetCombobox').value+' - Summary' : kbName+' - Summary' ) ;
  var pointStatsTitle = ( scope == 'coll' ? 'Collection Stats' : 'Global Kb Stats' ) ;
  var collapsible = (scope == 'coll' ? false : ( kbDescription == '' ? false : true)) ;
  var statsPanelConfig = {
    title: panelTitle,
    id: 'kbStatsPanel',
    header: false,
    height: panelHeight-35,
    autoScroll: true,
    cls: 'genbKb-toolbarcombobox',
    renderTo:'treeGridContainer-body',
    layout: {
      type: 'vbox',       // Arrange child items vertically
      align: 'stretch',    // Each takes up full width
      padding: 5
    },
  }
  if (scope == 'kb') {
    statsPanelConfig['items'] = // Items are panels arranged horizontally which contains panels to render the graphs
    [
      {
        xtype: 'panel',
        id: 'kbStatsPanel_headerPanel',
        border: false,
        collapsible: collapsible,
        collapsed: true,
        height: 60,
        autoScroll: true,
        title: panelTitle,
        bodyStyle: 'z-index: 100',
        collapseDirection: 'top',
        html: ( kbDescription == '' ? 'No Description Available.' : '<b>Description:</b> '+kbDescription ),
      },
      {
        xtype: 'splitter',
        height: 5
      },
      {
        xtype: 'panel',
        id: 'kbStatsPanel_firstRowPanel',
        border: false,
        padding: '0 0 5 0',
        layout: {
          type: 'hbox'
        },
        items: [
          {
            xtype: 'grid',
            height: scale+20,

            border: false,
            title: pointStatsTitle,
            hideHeaders: true,
            width: scale+90,
            columns: [
              {  dataIndex: 'statname', width: Math.round((scale+30)/2) },
              {  dataIndex: 'statvalue', width: Math.round((scale+140)/2) }
            ],
            viewConfig: {
              enableTextSelection: true
            },
            store: {
              xtype: 'store',
              storeId:'kbPointStatsStore',
              fields:['statname', 'statvalue'],
              data:{'items': [] },
              proxy: {
                type: 'memory',
                reader: {
                    type: 'json',
                    root: 'items'
                }
              }
            },
            id: 'kbStatsPanel_kbPointStatsGrid'
          },
          {
            xtype: 'panel',
            height: scale+20,
            border: false,
            id: 'kbStatsPanel_docsPerCollectionPanel',
            width: scale+130
          }

        ]
      },
      {
        xtype: 'panel',
        id: 'kbStatsPanel_secondRowPanel',
        padding: '0 0 5 0',
        border: false,
        layout: {
          type: 'hbox'
        },
        items: [
          {
            xtype: 'panel',
            height: scale,
            border: false,
            id: 'kbStatsPanel_docCountOverTimePanel',
            width: scale+110
          },
          {
            xtype: 'panel',
            height: scale,
            border: false,
            id: 'kbStatsPanel_activityOverTimePanel',
            width: scale+110
          }
        ]
      },
      {
        xtype: 'panel',
        id: 'kbStatsPanel_thirdRowPanel',
        border: false,
        layout: {
          type: 'hbox'
        },
        items: [
          {
            xtype: 'panel',
            height: scale,
            border: false,
            id: 'kbStatsPanel_createCountOverTimePanel',
            width: scale
          },
          {
            xtype: 'panel',
            height: scale,
            border: false,
            id: 'kbStatsPanel_editCountOverTimePanel',
            width: scale
          },
          {
            xtype: 'panel',
            height: scale,
            border: false,
            id: 'kbStatsPanel_deleteCountOverTimePanel',
            width: scale
          }
        ]
      }
    ] ;
  }
  else {
    statsPanelConfig['items'] = // Items are panels arranged horizontally which contains panels to render the graphs
    [
      {
        xtype: 'panel',
        id: 'kbStatsPanel_headerPanel',
        border: false,
        collapsible: collapsible,
        collapsed: true,
        height: 60,
        autoScroll: true,
        title: panelTitle,
        bodyStyle: 'z-index: 100',
        collapseDirection: 'top',
        html: ( kbDescription == '' ? 'No Description Available.' : '<b>Description:</b> '+kbDescription ),
      },
      {
        xtype: 'splitter',
        height: 5
      },
      {
        xtype: 'panel',
        id: 'kbStatsPanel_firstRowPanel',
        border: false,
        padding: '0 0 5 0',
        layout: {
          type: 'hbox'
        },
        items: [
          {
            xtype: 'grid',
            height: scale+20,

            border: false,
            title: pointStatsTitle,
            hideHeaders: true,
            width: scale+90,
            columns: [
              {  dataIndex: 'statname', width: Math.round((scale+30)/2) },
              {  dataIndex: 'statvalue', width: Math.round((scale+140)/2) }
            ],
            store: {
              xtype: 'store',
              storeId:'kbPointStatsStore',
              fields:['statname', 'statvalue'],
              data:{'items': [] },
              proxy: {
                type: 'memory',
                reader: {
                    type: 'json',
                    root: 'items'
                }
              }
            },
            id: 'kbStatsPanel_kbPointStatsGrid'
          },
          {
            xtype: 'panel',
            height: scale+20,
            border: false,
            id: 'kbStatsPanel_docCountOverTimePanel',
            width: scale+130
          }

        ]
      },
      {
        xtype: 'panel',
        id: 'kbStatsPanel_secondRowPanel',
        padding: '0 0 5 0',
        border: false,
        layout: {
          type: 'hbox'
        },
        items: [
          {
            xtype: 'panel',
            height: scale,
            border: false,
            id: 'kbStatsPanel_activityOverTimePanel',
            width: scale+110
          },
          {
            xtype: 'panel',
            height: scale,
            border: false,
            id: 'kbStatsPanel_createCountOverTimePanel',
            width: scale+110
          }
        ]
      },
      {
        xtype: 'panel',
        id: 'kbStatsPanel_thirdRowPanel',
        border: false,
        layout: {
          type: 'hbox'
        },
        items: [
          {
            xtype: 'panel',
            height: scale,
            border: false,
            id: 'kbStatsPanel_editCountOverTimePanel',
            width: scale+110
          },
          {
            xtype: 'panel',
            height: scale,
            border: false,
            id: 'kbStatsPanel_deleteCountOverTimePanel',
            width: scale+110
          }
        ]
      }
    ] ;
    statsPanelConfig['tbar'] = [
      {
        xtype: 'tbfill'
      },
      {
        xtype: 'tbtext',
        text: "<div class=\"genbKb-menubar-iconText genbKb-menubar-searchText\"></div>"
      },
      {
        xtype       : 'combo',
        id          : 'searchComboBox',
        // store : NO, BOUND AT RUNTIME AS MODEL CHANGES WHEN COLLECTION CHOSEN
        disabled    : true, // enable()'D AT RUNTIME AS MODEL CHANGES WHEN COLLECTION CHOSEN
        width       : 200, // Please sync this with the minWidth of listConfig
        maxHeight   : 22,
        height      : 22,
        minChars    : 1,
        // blankText   : '',
        // allowBlank  : false,
        autoScroll  : true,
        autoSelect  : false,
        checkChangeBuffer : 250,
        queryDelay  : 500,
        //hideTrigger : true,
        matchFieldWidth : false,
        emptyText: 'Type to search...',
        pickerAlign : 'tl-bl?',
        typeAhead   : false,
        queryMode   : 'remote',
        queryParam  : 'searchStr',
        //onListSelectionChange:function(){
        //  //this.picker.getSelectionModel().selectAll();
        //  var aa ;
        //},
        displayField : 'value',
        valueField  : 'value',
        listConfig  :
        {
          emptyText   : 'Search by doc name...',
          loadingText : '( Searching )',
          border      : 1,
          loadMask: true,
          minWidth    : 200  // Please sync this with the search box's width
        },
        tpl         : '<tpl for="."><div class=" x-boundlist-item {[xindex %2 == 0 ? "even" : "odd" ]} "> {value} </div></tpl>',
        valueNotFoundText : '(No matching docs)',
        //pageSize    : searchPageSize, // MAY BE USEFUL TO PROVIDE THIS WHEN API QUERY ALSO SUPPORTS PAGING/INDEXES
        listeners   :
        {
          'select': function(item) {
            docVersion = "" // loading a new doc via the doc search box, reset the docVersion
            //initTreeGrid() ;
            Ext.getCmp('browseDocsGrid').getView().select(0) ;
            loadDocument(item.value, true) ; // defined in ajax.js
          },
          'specialkey': function(field, e, eOpts){
            if(e.getKey() == e.ENTER) {
              if(field.rawValue != "") {
                var val = field.rawValue ;
                this.doQuery(val, false, true) ;
              }
            }
          },
          'beforequery': function(queryPlan, eOpts) {
            if ( queryPlan.query != "") {
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
            else{
              queryPlan.cancel = true ;
              queryPlan.combo.expand() ;
            }
          }
        }
      }
    ]
  }
  return statsPanelConfig ;
}

function displayKbStats(scope)
{
  resetMainPanel() ;
  if (scope == 'kb' && Ext.getCmp('collectionSetCombobox')) {
    Ext.getCmp('collectionSetCombobox').setValue('') ;
    docModel = null ;
    toggleCreateNewDocumentSelector('disable') ;
    toggleViewModel('disable') ;
    var toolbarItems = Ext.getCmp('containerPanelToolbar').items.items ;
    var ii ;
    for (ii=0; ii<toolbarItems.length; ii++) {
      if (toolbarItems[ii].itemId == 'viewInfoDialogBtn' || toolbarItems[ii].itemId == 'uploadDocsBtn' || toolbarItems[ii].itemId == 'downloadCollBtn') {
        toolbarItems[ii].disable() ;
      }
    }
  }
  Ext.getCmp('manageDocsGrid').getSelectionModel().deselectAll() ;
  Ext.getCmp('browseDocsGrid').getSelectionModel().deselectAll() ;
  Ext.getCmp('manageModelsGrid').getSelectionModel().deselectAll() ;

  var statsPanelConfig = createStatsPanelConfig(scope) ;

  var statsPanel = Ext.create('Ext.panel.Panel', statsPanelConfig) ;
  if(statsOK)
  {
    getConfigsDispatcher(scope) ;
  }
  if(scope == 'coll') {
    createSearchStore(docModel) ;
    Ext.getCmp('searchComboBox').setValue('') ;
    // Load up a small list of identifiers for the user to work with
    loadInitialDocList(false) ;
  }
  disablePanelBtn('docHistory') ;
  disablePanelBtn('editDelete') ;
}


function getConfigsDispatcher(scope)
{
  var colls = JSON.parse(collectionList).length ;
  if (scope == 'kb') {
    maskRemoveCounterLimit = 7 ;
    if (colls == 0) {
      maskRemoveCounterLimit = 6 ;
    }
  }
  else{
    maskRemoveCounterLimit = 6 ;
  }
  maskObj.show() ;
  getStatConfig('pointStats', 'kbStatsPanel_pointStatsPanel-body', scope) ;
  getStatConfig('docCountOverTime', '#kbStatsPanel_docCountOverTimePanel-body', scope) ;
  getStatConfig('activityOverTime', '#kbStatsPanel_activityOverTimePanel-body', scope) ;
  getStatConfig('createCountOverTime', '#kbStatsPanel_createCountOverTimePanel-body', scope) ;
  getStatConfig('editCountOverTime', '#kbStatsPanel_editCountOverTimePanel-body', scope) ;
  getStatConfig('deleteCountOverTime', '#kbStatsPanel_deleteCountOverTimePanel-body', scope) ;
  if (scope == 'kb' && colls > 0) {
    getStatConfig('docsPerColl', '#kbStatsPanel_docsPerCollectionPanel-body', scope, false) ;
  }
}

function getStatConfig(statType, renderTo, scope)
{

  var timeout = 900000 ;
  var method = "GET" ;
  var url = 'genboree_kbs/stats/stat'
  var params = {
    "authenticity_token": csrf_token,
    project_id: projectId,
    scope: scope,
    statType: statType,
    collection: Ext.getCmp('collectionSetCombobox').value
  }
  var callback = function(opts, success, response)
  {
    maskRemoveCounter += 1 ;
    if (scope == 'kb') {
      if (maskRemoveCounter == maskRemoveCounterLimit) {
        maskObj.hide() ;
        maskRemoveCounter = 0 ;
      }
    }
    else{
      if (maskRemoveCounter == maskRemoveCounterLimit) {
        maskObj.hide() ;
        maskRemoveCounter = 0 ;
      }
    }
    try
    {
      var apiRespObj  = JSON.parse(response.responseText) ;
      var resp = apiRespObj['data'] ;
      var statusObj   = apiRespObj['status'] ;
      if(response.status >= 200 && response.status < 400 && resp)
      {
        if (statType != 'pointStats')
        {
          if (resp['tooltip'] && resp['tooltip']['pointFormatter']) {
            resp['tooltip']['pointFormatter'] = new Function('a', 'b', resp['tooltip']['pointFormatter']) ;
          }
          $(renderTo).highcharts(resp) ;
        }
        else
        {
          populatePointStatsGrid(resp, scope) ;
        }
      }
      else
      {
        var displayMsg = "The following error was encountered while retrieving stats info:<br><br>" ;
        displayMsg += ( "<b>Error Code:</b> <i>" + (statusObj['statusCode'] ? statusObj['statusCode'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" ) ;
        displayMsg += ( "<b>Error Message:</b> <i>" + (statusObj['msg'] ? statusObj['msg'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" );
        displayMsg += "<br><br>Please contact a project admin to resolve this issue." ;
        Ext.Msg.alert("ERROR", displayMsg) ;
      }
    }
    catch(err)
    {
      // Do not display this error for now till the 'editCountOverTime' stat is fixed
      //Ext.Msg.alert('ERROR', "Bad data returned from server when retrieving the stats data for: "+ statType+".<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
    }
  }
  maskObj.show() ;
  genericAjaxCall(url, timeout, method, params, callback) ;
}

function showStats(scope)
{
  // to-do: this is a stupid way of checking if something's already loaded, need to come up with a better solution
  if (newdocObj || Ext.getCmp('modelTreeGrid') || Ext.getCmp('viewGrid') || Ext.getCmp('docsVersionsGrid') || Ext.getCmp('modelVersionsGrid') ) {
    var msg = "How would you like to view the stats?</br></br>Opening up the stats in the current tab will replace the tab's current contents." ;
    Ext.Msg.show({
      title: "Warning",
      msg: msg,
      width: 500,
      buttonText: {yes: 'Open in current tab', no: 'Open in new tab', cancel: 'Cancel'},
      id: 'displayStatsDialog',
      fn: function(btn){
        if(btn == 'yes')
        {
          displayKbStats(scope) ;
        }
        else if (btn == 'no') {
          var urlLink = "http://"+location.host+kbMount+"/genboree_kbs?project_id="+projectIdentifier ;
          if (scope == 'coll') {
            urlLink += "&coll="+escape(Ext.getCmp('collectionSetCombobox').value) ;
          }
          var win = window.open(urlLink, '_blank') ;
          win.focus() ;
        }
        else
        {
          // Nothing to do
        }
      }
    }) ;
  }
  else
  {
    displayKbStats(scope) ;
  }
}


function populatePointStatsGrid(dataObj, scope)
{
  var dataArr = [] ;
  var stats = dataObj['allPointStats']['properties'] ;
  var fields = Object.keys(stats) ;
  var ii ;
  var field ;
  var statValue ;
  var statName ;
  if (scope == 'kb') {
    dataArr.push( { 'statname' : '# Collections', 'statvalue': JSON.parse(collectionList).length } ) ;
  }
  for(ii=0; ii<fields.length; ii++)
  {
    field = ( kbPointStatsFieldOrderMap[ii] ? kbPointStatsFieldOrderMap[ii] : fields[ii] )  ;
    statValue = ( stats[field]['value'] != null ? stats[field]['value'] : '' ) ;
    if (field == 'avgByteSize' || field == 'byteSize') {
      statValue = Math.round(statValue) ;
      var i = -1;
      var docSize = statValue ;
      var byteUnits = [' KB', ' MB', ' GB', ' TB', 'PB', 'EB', 'ZB', 'YB'];
      do {
        docSize = docSize / 1024;
        i++;
      } while (docSize > 1024);
      statValue =  Math.max(docSize, 0.0).toFixed(1) + byteUnits[i] ;
    }
    if (field.match(/Count/)) {
      statValue = statValue.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",") ;
    }
    statName = ( kbPointStatsFieldNameMap[field] ? kbPointStatsFieldNameMap[field] : field ) ;
    dataArr.push( { 'statname': statName, 'statvalue': statValue } )
  }
  Ext.getCmp('kbStatsPanel_kbPointStatsGrid').getStore().loadData(dataArr) ;
}
