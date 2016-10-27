// Initializes tool bar for the editor tree grid

function initTreeGridToolbar()
{
  var disableCollStatsBtn = true ;
  if (Ext.getCmp('collectionSetCombobox') && Ext.getCmp('collectionSetCombobox').value != '' && Ext.getCmp('collectionSetCombobox').value != null ) {
    disableCollStatsBtn = false ;
  }
  var treeGridToolbar = new Ext.Toolbar({
    width:'auto',
    id: 'mainTreeGridToolbar',
    height: 40,
    cls: 'genbKb-toolbarcombobox',
    items:
    [
      {
        itemId: 'addChildRow',
        disabled: true,
        //text: 'Add',
        icon: 'plugin_assets/genboree_kbs/images/silk/add.png',
        tooltip: {
          title: 'Add Child',
          text: 'Add child records (sub-properties) to existing properties.'
        },
        handler : addChildNode, // defined in misc.js
        hidden: true
      },
      {
        itemId: 'removeRow',
        //text: 'Remove',
        hidden: true,
        icon: 'plugin_assets/genboree_kbs/images/silk/delete.png',
        tooltip: {
          title: 'Remove',
          text: 'Remove properties. Removing a property with sub-properties will remove all its children properties.'
        },
        handler: removeNode, // defined in misc.js
        disabled: true
      },
      {
        itemId: 'reorder',
        disabled: true,
        hidden: true,
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
      },
      {
        icon: 'plugin_assets/genboree_kbs/images/save.png',
        itemId: 'saveDoc',
        disabled: true,
        tooltip: {
          title: 'Save',
          text: 'Save the document to the database.'
        },
        handler: function(){
          var dataObj = { "data": newdocObj, "status": {"msg": "OK"}} ;
          var data = JSON.stringify(dataObj) ;
          var originalName ;
          var identifier = docModel.name ;
          if(originalDocumentIdentifier)
          {
            originalName = originalDocumentIdentifier ;
          }
          else
          {
            originalName = newdocObj[identifier].value ;
          }
          // If the identifier was changed for an existing document, generate a warning

          if(originalDocumentIdentifier && originalDocumentIdentifier != newdocObj[identifier].value)
          {
            Ext.Msg.show({
              title: "Warning",
              msg: "You have changed the identifier of this document.</br></br>This document will no longer be linked to the original identifier if you save it.</br></br>Are you sure you want to save the changes?",
              buttons: Ext.Msg.YESNO,
              fn: function(btn){
                if(btn == 'yes')
                {
                  saveDocument(originalName, data) ;
                }
              }
            }) ;
          }
          else
          {
            saveDocument(originalName, data) ;
          }
        }
      },
      {
        icon: 'plugin_assets/genboree_kbs/images/silk/pencil_delete.png',
        itemId: 'discardChanges',
        disabled: true,
        tooltip: {
          title: 'Discard',
          text: 'Discard any changes/updates made to the document.'
        },
        handler: function(){
          Ext.Msg.show({
            title: "Warning",
            msg: "This will discard any changes you have made to the document.</br></br>Are you sure you want to proceed?",
            buttons: Ext.Msg.YESNO,
            fn: function(btn){
              if(btn == 'yes')
              {
                loadDocument(newdocObj[docModel.name].value, false) ;
              }
            }
          }) ;
        }
      },
      {
        itemId: 'downloadBtn',
        tooltip: {
          title: 'Download',
          text: 'Download the document in any of the available formats. '
        },
        disabled: true,
        icon: 'plugin_assets/genboree_kbs/images/download.png',
        xtype: 'splitbutton',
        handler: function(){
          this.showMenu() ;
        },
        arrowAlign: 'right',
        menu: [
          { text: 'HTML (fragment)', disabled: true, hidden: true},
          { text: 'JSON', disabled: true, itemId: 'jsonDownloadBtn', handler: function(){
            if (documentEdited || freshDocument) {
              var msg ;
              if (freshDocument)
              {
                msg = "This is a fresh document. You must save it before you can download it." ;
              }
              else
              {
                msg = "You must save or discard changes before you can download the document." ;
              }
              Ext.Msg.show({
               title: "Alert",
               msg: msg,
               buttons: Ext.Msg.OK
             }) ;
            }
            else
            {
              // appendIframe() is defined in misc.js
              appendIframe('genboree_kbs/doc/download?authenticity_token='+csrf_token+'&collectionSet='+escape(Ext.getCmp('collectionSetCombobox').value)+'&itemId='+escape(newdocObj[docModel.name].value)+'&project_id='+projectId+'&download_format=json'+"&docVersion="+escape(docVersion)) ;
            }
          }},
          { text: 'Tabbed - Full Property Names', disabled: true, itemId: 'tbdFPNDownloadBtn',
            tooltip: {
              title: 'Tabbed - Full Property Names',
              text: '&#149;&nbsp;The property name column contains the full property-path.</br>&#149;&nbsp;Each record/line has the complete nesting context of the property.</br>&#149;&nbsp;More complete, but very long & redundant property names.'
            },
            handler: function(){
            if (documentEdited || freshDocument) {
              var msg ;
              if (freshDocument)
              {
                msg = "This is a fresh document. You must save it before you can download it." ;
              }
              else
              {
                msg = "You must save or discard changes before you can download the document." ;
              }
              Ext.Msg.show({
               title: "Alert",
               msg: msg,
               buttons: Ext.Msg.OK
             }) ;
            }
            else
            {
              // appendIframe() is defined in misc.js
              appendIframe('genboree_kbs/doc/download?download_format=tabbed_prop_path&authenticity_token='+csrf_token+'&collectionSet='+escape(Ext.getCmp('collectionSetCombobox').value)+'&itemId='+escape(newdocObj[docModel.name].value)+'&project_id='+projectId+"&docVersion="+escape(docVersion)) ;
            }
          }},
          { text: 'Tabbed - Compact Property Names', disabled: true, itemId: 'tbdCPNDownloadBtn',
            tooltip: {
              title: 'Tabbed - Compact Property Names',
              text: '&#149;&nbsp;The property name column contains a prefix summarizing of the relative nesting context and then the actual property name.</br>&#149;&nbsp;The nesting prefix also indicates whether the property contains sub-props (ends with -) or a list of sub-items (ends with +).</br>&#149;&nbsp;Each record/line can only be understood in context of the records/line before it.</br>&#149;&nbsp;Less complete, but shorter summary, less redundancy, and compact.'
            },
            handler: function(){
            if (documentEdited || freshDocument) {
              var msg ;
              if (freshDocument)
              {
                msg = "This is a fresh document. You must save it before you can download it." ;
              }
              else
              {
                msg = "You must save or discard changes before you can download the document." ;
              }
              Ext.Msg.show({
               title: "Alert",
               msg: msg,
               buttons: Ext.Msg.OK
             }) ;
            }
            else
            {
              // appendIframe() is defined in misc.js
              appendIframe('genboree_kbs/doc/download?download_format=tabbed_prop_nesting&authenticity_token='+csrf_token+'&collectionSet='+escape(Ext.getCmp('collectionSetCombobox').value)+'&itemId='+escape(newdocObj[docModel.name].value)+'&project_id='+projectId+"&docVersion="+escape(docVersion)) ;
            }
          }},
          { text: 'YAML', disabled: true, hidden: true }
        ]
      },
      {
        itemId: 'issueBtn',
        tooltip: {
          title: 'Issues',
          text: 'Register/Update an issue with the model or the document. This functionality is still being developed and is not yet available.'
        },
        icon: 'plugin_assets/genboree_kbs/images/silk/comments_add.png',
        xtype: 'splitbutton',
        disabled: true,
        hidden: true,
        arrowAlign: 'right',
        menu: [
          { text: 'Add Doc. Issue', icon: '../images/silk/comment_add.png' },
          { text: 'Add Model Issue', icon: '../images/silk/comment_add.png' }
        ]
      },
      {
        itemId: 'urlBtn',
        tooltip: {
          title: '',
          text: 'Get the URL of the current document.'
        },
        handler: function(){
          this.showMenu() ;
        },
        icon: 'plugin_assets/genboree_kbs/images/silk/application_link.png',
        xtype: 'splitbutton',
        disabled: true,
        arrowAlign: 'right',
        menu: [
          { text: 'Get URL', handler: function(){
            Ext.create('Ext.window.Window', {
              title: 'Document URL',
              height: 150,
              width: 600,
              autoScroll: true,
              html: "<b>You can copy the following URL to your clipboard</b>:</br><div style=\"width:auto; height:auto; background-color: white; padding-left:3px; padding-right:3px;\"><p>"+"http://"+location.host+kbMount+'/genboree_kbs?project_id='+projectIdentifier+'&coll='+escape(currentCollection)+'&doc='+escape(newdocObj[docModel.name].value)+"&docVersion="+escape(docVersion)+"</p></div>"
            }).show() ;
          }},
          { text: 'Get URL with state', disabled: true, hidden: true, tooltip: { text: 'This functionality is still being developed and is not yet available.' } }
        ]
      },
      {
        itemId: 'docToolsBtn',
        tooltip: {
          title: 'Tools',
          text: "Run tools configured for the selected document. Button only active if one or more document level tools have been configured for this collection and a saved document is being viewed."
        },
        handler: function(){
          this.showMenu() ;
        },
        hidden: true,
        disabled: true,
        icon: 'plugin_assets/genboree_kbs/images/silk/cog_go.png',
        xtype: 'splitbutton',
        arrowAlign: 'right',
        menu: docLevelTools // defined in globals.js : starts off as empty. Populated when user selects a collection
      },
      {
        xtype: 'tbfill'
      },
      {
        itemId: 'collStatsBtn',
        tooltip: {
          title: 'Collection Stats',
          text: "Display various collection wide statistics for the selected collection including total number of docs, docs created over time, activity over time, etc."
        },
        handler: function(){
          showStats('coll') ;
        },
        disabled: disableCollStatsBtn,
        hidden: false,
        icon: 'plugin_assets/genboree_kbs/images/silk/chart_bar.png',
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
        width       : 250, // Please sync this with the minWidth of listConfig
        maxHeight   : 23,
        height      : 23,
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
          minWidth    : 250  // Please sync this with the search box's width
        },
        tpl         : '<tpl for="."><div class=" x-boundlist-item {[xindex %2 == 0 ? "even" : "odd" ]} "> {value} </div></tpl>',
        valueNotFoundText : '(No matching docs)',
        //pageSize    : searchPageSize, // MAY BE USEFUL TO PROVIDE THIS WHEN API QUERY ALSO SUPPORTS PAGING/INDEXES
        listeners   :
        {
          'select': function(item) {
            docVersion = "" // loading a new doc via the doc search box, reset the docVersion
            loadDocument(item.value, false) ; // defined in ajax.js
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
  }) ;
}

function initQuestionnaireToolbar()
{
  var qtoolbar  = new Ext.Toolbar({
    width:'auto',
    id: 'questionnaireToolbar',
    items:
    [
      {
        icon: 'plugin_assets/genboree_kbs/images/save.png',
        itemId: 'saveQDoc',
        disabled: false,
        tooltip: {
          title: 'Save',
          text: 'Save the questionnaire document to generate a new document in the collection.'
        },
        handler: function(){
          saveQuestionnaire() ; // defined in questionnaire.js
        }
      }
    ]
  }) ;
  return qtoolbar ;
}

// Initializes tool bar for the model view
function initModelTreeToolbar()
{
  var modelTreeToolbar = new Ext.Toolbar({
    width:'auto',
    id: 'modelTreeToolbar',
    items:
    [
      {
        itemId: 'downloadModelTreeBtn',
        tooltip: {
          title: 'Download',
          text: 'Download the model in any of the available formats.'
        },
        handler: function(){
          this.showMenu() ;
        },
        disabled: false,
        icon: 'plugin_assets/genboree_kbs/images/download.png',
        xtype: 'splitbutton',
        arrowAlign: 'right',
        menu: [
          {
            text: 'JSON', itemId: 'jsonModelTreeDownloadBtn', handler: function(){
              // appendIframe() is defined in misc.js
              appendIframe('genboree_kbs/model/download?download_format=json&authenticity_token='+csrf_token+'&collectionSet='+escape(Ext.getCmp('collectionSetCombobox').value)+'&project_id='+projectId+'&modelVersion='+escape(modelVersion)) ;
            }
          },
          {
            text: 'Tabbed - Full Property Names', itemId: 'tbdFPNModelTreeDownloadBtn',
            tooltip: {
              title: 'Tabbed - Full Property Names',
              text: '&#149;&nbsp;The property name column contains the full property-path.</br>&#149;&nbsp;Each record/line has the complete nesting context of the property.</br>&#149;&nbsp;More complete, but very long & redundant property names.'
            },
            handler: function(){
              appendIframe('genboree_kbs/model/download?download_format=tabbed_prop_path&authenticity_token='+csrf_token+'&collectionSet='+escape(Ext.getCmp('collectionSetCombobox').value)+'&project_id='+projectId+'&modelVersion='+escape(modelVersion)) ;
            }
          },
          {
            text: 'Tabbed - Compact Property Names', itemId: 'tbdCPNModelTreeDownloadBtn',
            tooltip: {
              title: 'Tabbed - Compact Property Names',
              text: '&#149;&nbsp;The property name column contains a prefix summarizing of the relative nesting context and then the actual property name.</br>&#149;&nbsp;The nesting prefix also indicates whether the property contains sub-props (ends with -) or a list of sub-items (ends with +).</br>&#149;&nbsp;Each record/line can only be understood in context of the records/line before it.</br>&#149;&nbsp;Less complete, but shorter summary, less redundancy, and compact.'
            },
            handler: function(){
              appendIframe('genboree_kbs/model/download?download_format=tabbed_prop_nesting&authenticity_token='+csrf_token+'&collectionSet='+escape(Ext.getCmp('collectionSetCombobox').value)+'&project_id='+projectId+'&modelVersion='+escape(modelVersion)) ;
            }
          }
        ]
      },
      {
        itemId: 'urlBtnModelTree',
        tooltip: {
          title: '',
          text: 'Get the URL of the current model view.'
        },
        handler: function(){
          this.showMenu() ;
        },
        icon: 'plugin_assets/genboree_kbs/images/silk/application_link.png',
        xtype: 'splitbutton',
        arrowAlign: 'right',
        menu: [
          { text: 'Get URL', handler: function(){
            Ext.create('Ext.window.Window', {
              title: 'Document URL',
              height: 150,
              width: 600,
              autoScroll: true,
              html: "<b>You can copy the following URL to your clipboard</b>:</br><div style=\"width:auto; height:auto; background-color: white; padding-left:3px; padding-right:3px;\"><p>"+"http://"+location.host+kbMount+'/genboree_kbs?project_id='+projectIdentifier+'&showModelTree=true&coll='+escape(Ext.getCmp('collectionSetCombobox').value)+"&modelVersion="+escape(modelVersion)+"</p></div>"
            }).show() ;
          }},
          { text: 'Get URL with state', disabled: true, hidden: true, tooltip: { text: 'This functionality is still being developed and is not yet available.' } }
        ]
      }

    ]
  }) ;
}


// Initializes tool bar for the model view
function initViewGridToolbar(formEls)
{
  var viewGridToolbar = new Ext.Toolbar({
    width:'auto',
    id: 'viewGridToolbar',
    items:
    [
      {
        itemId: 'downloadViewGridBtn',
        tooltip: {
          title: 'Download',
          text: 'Download the result in any of the available formats.'
        },
        handler: function(){
          this.showMenu() ;
        },
        disabled: false,
        icon: 'plugin_assets/genboree_kbs/images/download.png',
        xtype: 'splitbutton',
        arrowAlign: 'right',
        menu: [
          {
            text: 'JSON', itemId: 'jsonViewGridDownloadBtn', handler: function(){
              // appendIframe() is defined in misc.js
              appendIframe('genboree_kbs/view/download?download_format=json&authenticity_token='+csrf_token+'&collectionSet='+escape(Ext.getCmp('collectionSetCombobox').value)+'&project_id='+projectId+'&matchQuery='+escape(formEls[0])+'&matchMode='+escape(formEls[1])+'&matchView='+escape(formEls[2])+'&matchValue='+escape(formEls[3])) ;
            }
          },
          {
            text: 'JSON_PRETTY', itemId: 'jsonPrettyViewGridDownloadBtn', handler: function(){
              // appendIframe() is defined in misc.js
              appendIframe('genboree_kbs/view/download?download_format=json_pretty&authenticity_token='+csrf_token+'&collectionSet='+escape(Ext.getCmp('collectionSetCombobox').value)+'&project_id='+projectId+'&matchQuery='+escape(formEls[0])+'&matchMode='+escape(formEls[1])+'&matchView='+escape(formEls[2])+'&matchValue='+escape(formEls[3])) ;
            }
          },
          {
            text: 'Tabbed', itemId: 'tabbedViewGridDownloadBtn',
            handler: function(){
              appendIframe('genboree_kbs/view/download?download_format=tabbed&authenticity_token='+csrf_token+'&collectionSet='+escape(Ext.getCmp('collectionSetCombobox').value)+'&project_id='+projectId+'&matchQuery='+escape(formEls[0])+'&matchMode='+escape(formEls[1])+'&matchView='+escape(formEls[2])+'&matchValue='+escape(formEls[3])) ;
            }
          }
        ]
      },
      {
        itemId: 'urlBtnViewGrid',
        tooltip: {
          title: '',
          text: 'Get the URL of the current view grid.'
        },
        handler: function(){
          this.showMenu() ;
        },
        icon: 'plugin_assets/genboree_kbs/images/silk/application_link.png',
        xtype: 'splitbutton',
        arrowAlign: 'right',
        menu: [
          { text: 'Get URL', handler: function(){
            Ext.create('Ext.window.Window', {
              title: 'View URL',
              height: 150,
              width: 600,
              autoScroll: true,
              html: "<b>You can copy the following URL to your clipboard</b>:</br><div style=\"width:auto; height:auto; background-color: white; padding-left:3px; padding-right:3px;\"><p>"+"http://"+location.host+kbMount+'/genboree_kbs?project_id='+projectIdentifier+'&showViewGrid=true&coll='+escape(Ext.getCmp('collectionSetCombobox').value)+'&matchQuery='+escape(formEls[0])+'&matchMode='+escape(formEls[1])+'&matchView='+escape(formEls[2])+'&matchValue='+escape(formEls[3])+"</p></div>"
            }).show() ;
          }},
          { text: 'Get URL with state', disabled: true, hidden: true, tooltip: { text: 'This functionality is still being developed and is not yet available.' } }
        ]
      }

    ]
  }) ;
}

// Initializes tool bar for the model view
function initDocsVersionsGridToolbar()
{
  var docsVersionsGridToolbar = new Ext.Toolbar({
    width:'auto',
    id: 'docsVersionsGridToolbar',
    items:
    [
      {
        itemId: 'downloadDocsVerionsGridBtn',
        tooltip: {
          title: 'Download',
          text: 'Download the grid result in any of the available formats.'
        },
        handler: function(){
          this.showMenu() ;
        },
        disabled: false,
        icon: 'plugin_assets/genboree_kbs/images/download.png',
        xtype: 'splitbutton',
        arrowAlign: 'right',
        menu: [
          {
            text: 'JSON', itemId: 'jsonDocsVersionsGridDownloadBtn', handler: function(){
              // appendIframe() is defined in misc.js
              appendIframe('genboree_kbs/versions/download?type=doc&download_format=json&authenticity_token='+csrf_token+'&collectionSet='+escape(currentCollection)+'&project_id='+projectId+'&identifier='+escape(originalDocumentIdentifier)) ;
            }
          }
        ]
      },
      {
        icon: 'plugin_assets/genboree_kbs/images/silk/arrow_redo.png',
        itemId: 'restoreDoc',
        disabled: true,
        tooltip: {
          title: 'Restore',
          text: 'Set the selected version to be the current version of the document.'
        },
        handler: function(){
          Ext.Msg.show({
            title: "Warning",
            msg: "This will set the selected version to be the current document version.</br></br>Are you sure you want to continue?",
            buttons: Ext.Msg.YESNO,
            fn: function(btn){
              if(btn == 'yes')
              {
                getSelectedDocVersion() ; // defined in docVersions.js
              }
            }
          }) ;
        }
      },
      {
        icon: 'plugin_assets/genboree_kbs/images/silk/application_tile_horizontal.png',
        itemId: 'udiffDocs',
        disabled: true,
        tooltip: {
          title: 'Diff',
          text: 'Generate a diff for the selected versions and compare changes between the two versions of a document.</br><b>TIP:</b> Hold ctrl to select multiple records.'
        },
        handler: function(){
          performDiff() ;
        }
      },
      {
        itemId: 'docsVersionsGridUrlBtn',
        tooltip: {
          title: '',
          text: 'Get the URL of this grid.'
        },
        handler: function(){
          this.showMenu() ;
        },
        icon: 'plugin_assets/genboree_kbs/images/silk/application_link.png',
        xtype: 'splitbutton',
        arrowAlign: 'right',
        menu: [
          { text: 'Get URL', handler: function(){
            Ext.create('Ext.window.Window', {
              title: 'View URL',
              height: 150,
              width: 600,
              autoScroll: true,
              html: "<b>You can copy the following URL to your clipboard</b>:</br><div style=\"width:auto; height:auto; background-color: white; padding-left:3px; padding-right:3px;\"><p>"+"http://"+location.host+kbMount+'/genboree_kbs?project_id='+projectIdentifier+'&showDocsVersionsGrid=true&coll='+escape(currentCollection)+'&doc='+escape(originalDocumentIdentifier)+"</p></div>"
            }).show() ;
          }},
          { text: 'Get URL with state', disabled: true, hidden: true, tooltip: { text: 'This functionality is still being developed and is not yet available.' } }
        ]
      }

    ]
  }) ;
}


function initModelVersionsGridToolbar()
{
  var docsVersionsGridToolbar = new Ext.Toolbar({
    width:'auto',
    id: 'modelVersionsGridToolbar',
    items:
    [
      {
        itemId: 'downloadModelVerionsGridBtn',
        tooltip: {
          title: 'Download',
          text: 'Download the grid result in any of the available formats.'
        },
        handler: function(){
          this.showMenu() ;
        },
        disabled: false,
        icon: 'plugin_assets/genboree_kbs/images/download.png',
        xtype: 'splitbutton',
        arrowAlign: 'right',
        menu: [
          {
            text: 'JSON', itemId: 'jsonModelVersionsGridDownloadBtn', handler: function(){
              // appendIframe() is defined in misc.js
              appendIframe('genboree_kbs/versions/download?type=model&download_format=json&authenticity_token='+csrf_token+'&collectionSet='+escape(Ext.getCmp('collectionSetCombobox').value)+'&project_id='+projectId) ;
            }
          }
        ]
      },
      {
        icon: 'plugin_assets/genboree_kbs/images/silk/arrow_redo.png',
        itemId: 'restoreModel',
        disabled: true,
        hidden: true,
        tooltip: {
          title: 'Restore',
          text: 'Set the selected version to be the current version of the model.'
        },
        handler: function(){
          Ext.Msg.show({
            title: "<b>Warning</b>",
            msg: "This will set the selected version to be the current model version.</br></br>Changing the model of a collection without careful consideration can result in documents becoming incompatible with the model.</br></br>Are you sure you want to continue?",
            buttons: Ext.Msg.YESNO,
            fn: function(btn){
              if(btn == 'yes')
              {
                getSelectedModelVersion() ; // defined in modelVersions.js
              }
            }
          }) ;
        }
      },
      {
        itemId: 'modelVersionsGridUrlBtn',
        tooltip: {
          title: '',
          text: 'Get the URL of this grid.'
        },
        handler: function(){
          this.showMenu() ;
        },
        icon: 'plugin_assets/genboree_kbs/images/silk/application_link.png',
        xtype: 'splitbutton',
        arrowAlign: 'right',
        menu: [
          { text: 'Get URL', handler: function(){
            Ext.create('Ext.window.Window', {
              title: 'View URL',
              height: 150,
              width: 600,
              autoScroll: true,
              html: "You can copy the following URL to your clipboard:</br><div style=\"width:auto; height:auto; background-color: white; padding-left:3px; padding-right:3px;\"><p>"+"http://"+location.host+kbMount+'/genboree_kbs?project_id='+projectIdentifier+'&showModelVersionsGrid=true&coll='+escape(Ext.getCmp('collectionSetCombobox').value)+"</p></div>"
            }).show() ;
          }},
          { text: 'Get URL with state', disabled: true, hidden: true, tooltip: { text: 'This functionality is still being developed and is not yet available.' } }
        ]
      }

    ]
  }) ;
}

function initStatsPanelToolbar()
{
  var statsPanelToolbar = new Ext.Toolbar({
    width:'auto',
    height: 40,
    cls: 'genbKb-toolbarcombobox',
    id: 'statsPanelToolbar',
    items:
    [
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
        width       : 250, // Please sync this with the minWidth of listConfig
        maxHeight   : 23,
        height      : 23,
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
          minWidth    : 250  // Please sync this with the search box's width
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
  }) ;
}
function initContainerPanelToolbar()
{
  // Initialize the tool bar for the main wrapping panel
  var containerPanelToolbar = new Ext.Toolbar({
    width:'auto',
    height: 40,
    cls: 'genbKb-toolbarcombobox',
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
        height: 23,
        queryMode: 'local',
        emptyText: 'Select data set',
        
        editable: false,
        // load the model for the selected collection.
        // Also enable the 'download all docs' button.
        listeners: {
          beforeselect: function(cb, record, index, eOpts){

          },
          select: function(e){
            // Show a warning message if something is already loaded in the panel
            if (newdocObj || Ext.getCmp('modelTreeGrid') || Ext.getCmp('viewGrid') || Ext.getCmp('docsVersionsGrid') || Ext.getCmp('modelVersionsGrid') ) {
              var msg = "Selecting a new collection will remove any content you are currently viewing.</br></br>Are you sure you want to continue?" ;
              Ext.Msg.show({
                title: "Change collection",
                msg: msg,
                width: 500,
                buttons: Ext.Msg.YESNO,
                //buttonText: {yes: 'Open model in current tab', no: 'Open model in new tab', cancel: 'Cancel'},
                id: 'changeSelectionDialog',
                fn: function(btn){
                  if(btn == 'yes')
                  {
                    changeCollection() ;
                  }
                  else
                  {
                    Ext.getCmp('collectionSetCombobox').setValue(prevCollection) ;
                  }
                }
              }) ;
            }
            else
            {
              changeCollection() ;
            }
          }
        },
        store: collectionSetStore
      },
      {
        itemId: 'downloadCollBtn',
        tooltip: {
          title: 'Download',
          text: "Download all documents in the selected collection in any of the available formats.</br></br><b>Warning</b>: A collection may have thousands of documents. Downloading all of them may take a long time."
        },
        handler: function(){
          this.showMenu() ;
        },
        disabled: true,
        //hidden: true,
        icon: 'plugin_assets/genboree_kbs/images/download.png',
        xtype: 'splitbutton',
        arrowAlign: 'right',
        menu: [
          {
            text: 'JSON', itemId: 'jsonCollDownloadBtn', handler: function(){
              // appendIframe() is defined in misc.js
              appendIframe('genboree_kbs/collection/download?download_format=json&authenticity_token='+csrf_token+'&collectionSet='+escape(Ext.getCmp('collectionSetCombobox').value)+'&project_id='+projectId) ;
            }
          },
          {
            text: 'JSON_PRETTY', itemId: 'jsonPrettyCollDownloadBtn', handler: function(){
              // appendIframe() is defined in misc.js
              appendIframe('genboree_kbs/collection/download?download_format=json_pretty&authenticity_token='+csrf_token+'&collectionSet='+escape(Ext.getCmp('collectionSetCombobox').value)+'&project_id='+projectId) ;
            }
          },
          {
            text: 'Tabbed - Full Property Names', itemId: 'tbdFPNCollDownloadBtn',
            tooltip: {
              title: 'Tabbed - Full Property Names',
              text: '&#149;&nbsp;The property name column contains the full property-path.</br>&#149;&nbsp;Each record/line has the complete nesting context of the property.</br>&#149;&nbsp;More complete, but very long & redundant property names.'
            },
            handler: function(){
              appendIframe('genboree_kbs/collection/download?download_format=tabbed_prop_path&authenticity_token='+csrf_token+'&collectionSet='+escape(Ext.getCmp('collectionSetCombobox').value)+'&project_id='+projectId) ;
            }
          },
          {
            text: 'Tabbed - Compact Property Names', itemId: 'tbdCPNCollDownloadBtn',
            tooltip: {
              title: 'Tabbed - Compact Property Names',
              text: '&#149;&nbsp;The property name column contains a prefix summarizing of the relative nesting context and then the actual property name.</br>&#149;&nbsp;The nesting prefix also indicates whether the property contains sub-props (ends with -) or a list of sub-items (ends with +).</br>&#149;&nbsp;Each record/line can only be understood in context of the records/line before it.</br>&#149;&nbsp;Less complete, but shorter summary, less redundancy, and compact.'
            },
            handler: function(){
              appendIframe('genboree_kbs/collection/download?download_format=tabbed_prop_nesting&authenticity_token='+csrf_token+'&collectionSet='+escape(Ext.getCmp('collectionSetCombobox').value)+'&project_id='+projectId) ;
            }
          },
          {
            text: 'Tabbed (Multi) - Compact Property Names', itemId: 'tbdMultiCPNCollDownloadBtn',
            tooltip: {
              title: 'Tabbed (Multi) - Compact Property Names',
              text: '&#149;&nbsp;The property name column contains a prefix summarizing of the relative nesting context and then the actual property name.</br>&#149;&nbsp;The nesting prefix also indicates whether the property contains sub-props (ends with -) or a list of sub-items (ends with +).</br>&#149;&nbsp;Each record/line can only be understood in context of the records/line before it.</br>&#149;&nbsp;Less complete, but shorter summary, less redundancy, and compact.</br>&#149;&nbsp;There can be more than one value column in the file and each value column will correspond to a single document. '
            },
            handler: function(){
              appendIframe('genboree_kbs/collection/download?download_format=tabbed_multi_prop_nesting&authenticity_token='+csrf_token+'&collectionSet='+escape(Ext.getCmp('collectionSetCombobox').value)+'&project_id='+projectId) ;
            }
          }
        ]
      },
      {
        itemId: 'uploadDocsBtn',
        tooltip: {
          title: 'Upload Documents',
          text: "Upload documents into the selected collection as a job on our cluster."
        },
        handler: function(){
          if (kbDb == null || kbDb == '' || kbDb == 'NULL') {
            Ext.Msg.alert('NO Database', 'This KB is not associated with any database and therefore files cannot be uploaded. Please contact a project admin to set up a database for this kb.') ;  
          }
          else{
            // Check if regesitered db exists. If it does, we will present the user with the file upload form
            checkExistenceOfKbDb('kbDocsUpload') ;
          }
        },
        disabled: true,
        icon: 'plugin_assets/genboree_kbs/images/silk/page_white_get.png',
        //xtype: 'splitbutton',
        arrowAlign: 'right'
      },
      {
        itemId: 'viewInfoDialogBtn',
        tooltip: {
          title: 'Query Collection',
          text: 'Query selected collection using a pre defined or a custom query and view the results in one of the available view formats.'
        },
        disabled: true,
        hidden: false,
        icon: 'plugin_assets/genboree_kbs/images/silk/application_view_detail.png',
        handler: function(){
          initViewInfoDialog() ; // defined in views.js
        }
      },
      {
        itemId: 'collToolsBtn',
        tooltip: {
          title: 'Tools',
          text: "Run tools configured for this collection. Button only active if one or more tools have been configured for the selected collection."
        },
        handler: function(){
          this.showMenu() ;
        },
        hidden: true,
        disabled: true,
        icon: 'plugin_assets/genboree_kbs/images/silk/cog_go.png',
        xtype: 'splitbutton',
        arrowAlign: 'right',
        menu: [
          
        ]
      },
      {
        xtype: 'tbfill'
      },
      {
        itemId: 'kbStatsBtn',
        tooltip: {
          title: 'Kb Stats',
          text: "Display various KB wide statistics including docs per collection, docs created over time, activity over time, etc."
        },
        handler: function(){
          showStats('kb') ;
        },
        disabled: false,
        hidden: false,
        icon: 'plugin_assets/genboree_kbs/images/silk/chart_bar.png'
      },
      {
        itemId: 'jobSummaryBtn',
        tooltip: {
          title: 'Job Summary',
          text: "Generate a summary/status of all the 'Upload Documents' jobs you have submitted."
        },
        handler: function(){
          getJobSummary(false) ;
        },
        disabled: true,
        hidden: false,
        icon: 'plugin_assets/genboree_kbs/images/silk/application_view_list.png'
      },
      {
        itemId: 'helpInfo',
        //text: 'Remove',
        icon: 'plugin_assets/genboree_kbs/images/silk/help.png',
        style: {
          marginRight: '10px'
        },
        tooltip: {
          title: 'Help',
          text: 'To browse documents, select a collection from the <b>Collection</b> drop-down. Next, start typing in the search text box on the grid tool bar to see available documents. Select a document to visualize/edit it.'
        }
      }
    ]
  }) ;
}

function checkExistenceOfKbDb(context)
{
  maskObj.show() ;
  Ext.Ajax.request(
  {
    url : 'genboree_kbs/user/checkDb',
    timeout : 90000,
    method: 'GET',
    params:
    {
      "authenticity_token": csrf_token,
      project_id: projectId,
      kbDb: kbDb
    },
    callback : function(opts, success, response)
    {
      maskObj.hide() ;
      try
      {
        var apiRespObj  = JSON.parse(response.responseText) ;
        var statusObj   = apiRespObj['status'] ;
        if( response.status >= 200 && response.status < 400 )
        {
          if ( context && context == 'kbDocsUpload') {
            displayDocsUploadDialog() ;
          }
          else if(context && context == 'fileUrl'){
            displayFileUrlDialog() ;
          }
          else{
            // Do nothing. We should not be reaching here in any case
          }
        }
        else
        {
          Ext.Msg.alert("No Database", "The database: "+kbDb+" registered with this KB does not exist. Please create it first before uploading documents.") ;
        }
      }
      catch(err)
      {
        Ext.Msg.alert('ERROR', "Bad data returned from server when retrieving database info.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
      }
    }
  }) ;
}

function getJobSummary(reloading)
{
  maskObj.show() ;
  Ext.Ajax.request(
  {
    url : 'genboree_kbs/tools/summary',
    timeout : 90000,
    method: 'GET',
    params:
    {
      "authenticity_token": csrf_token,
      project_id: projectId,
      tool: 'kbBulkUpload',
      kbName: kbName
    },
    callback : function(opts, success, response)
    {
      maskObj.hide() ;
      try
      {
        var apiRespObj  = JSON.parse(response.responseText) ;
        var statusObj   = apiRespObj['status'] ;
        if( response.status >= 200 && response.status < 400 )
        {
          var jobRecs = apiRespObj['data'] ;
          if (jobRecs.length == 0) {
            Ext.Msg.alert('No Jobs', "You have not submitted any jobs to this KB.") ;
          }
          else{
            if (reloading) {
              reloadJobSummaryGrid(jobRecs) ;  
            }
            else {
              renderJobSummaryGrid(jobRecs) ;
            }
          }
        }
        else
        {
          var displayMsg = "The following error was encountered while getting the job summary:<br><br>" ;
          displayMsg += ( "<b>Error Code:</b> <i>" + (statusObj['statusCode'] ? statusObj['statusCode'] : "[ NOT INTELLIGIBLE ]") + "</i><br>" );
          displayMsg += ( "<b>Error Message:</b> <i>" + (statusObj['msg'] ? statusObj['msg'] : "[ NOT INTELLIGIBLE ]") + "</i>" );
          displayMsg += "<br><br>Please contact a project admin to arrange investigation and resolution." ;
          Ext.Msg.alert("ERROR", displayMsg) ;
        }
      }
      catch(err)
      {
        Ext.Msg.alert('ERROR', "Bad data returned from server when getting the job summary.<br><br>Please contact a project admin to arrange investigation and resolution." ) ;
      }
    }
  }) ;
}

function reloadJobSummaryGrid(respArr)
{
  var jobData = prepareJobSummaryStoreObject(respArr) ;
  Ext.getCmp('jobSummaryGrid').getStore().loadData(jobData) ;
}


function renderJobSummaryGrid(respArr)
{
  var jobData = prepareJobSummaryStoreObject(respArr) ;
  Ext.create('Ext.data.Store', {
    storeId: 'jobSummaryStore',
    fields: [ 'jobName', 'tool', 'submitDate', 'completedDate', 'status', 'timeInCurrentStatus'],
    data: jobData,
    proxy: {
      type: 'memory',
      reader: {
        type: 'json'
      }
    }
  }) ;
  var cols = [
    {header: 'Job Name', dataIndex: 'jobName', width: 250, sortable: true},
    {header: 'Tool', dataIndex: 'tool', width: 130, sortable: true},
    {header: 'Submit Date', dataIndex: 'submitDate', width: 110, sortable: true},
    {header: 'Completed Date', dataIndex: 'completedDate', width: 110, sortable: true},
    {header: 'Status', dataIndex: 'status', width: 80, sortable: true},
    {header: 'Time Spent', dataIndex: 'timeInCurrentStatus', width: 140, sortable: true}
  ]
  Ext.create('Ext.grid.Panel', {
    store: Ext.data.StoreManager.lookup('jobSummaryStore'),
    columns: cols,
    id: 'jobSummaryGrid',
    header: false,
    tbar:
    [
      {
        xtype: 'button',
        tooltip: {
          title: 'Refresh',
          text: "Refresh the contents of the job summary grid with the latest information."
        },
        icon: 'plugin_assets/genboree_kbs/images/silk/arrow_refresh.png',
        handler: function() { getJobSummary(true) ; }
      }
    ],
    height: 350, 
    width: 800,
    collapsible: false,
    viewConfig: {
      enableTextSelection: true
    }
  });
  Ext.create('Ext.window.Window', {
    title: 'Job Summary/Status Grid',
    id: 'solicitViewInfoDisplayWindow',
    modal: true,
    autoScroll: true,
    layout: 'fit',
    items: Ext.getCmp('jobSummaryGrid')
  }).show();
  
}

function prepareJobSummaryStoreObject(respArr)
{
  var jobData = [] ;
  var ii ;
  for(ii=0; ii<respArr.length; ii++)
  {
    var submitDateObj = new Date(respArr[ii]['submitDate'])  ;
    var completedDateObj = new Date(respArr[ii]['completedDate'])  ;
    var month = submitDateObj.getMonth() + 1
    var submitDateStr = submitDateObj.getFullYear()+'/'+(submitDateObj.getMonth()+1)+'/'+submitDateObj.getDate()+ ' '+submitDateObj.getHours()+':'+submitDateObj.getMinutes()+':'+submitDateObj.getSeconds() ;
    var completedDateStr ;
    if(completedDateObj.getFullYear() != '1969')
    {
      completedDateStr = completedDateObj.getFullYear()+'/'+(completedDateObj.getMonth()+1)+'/'+completedDateObj.getDate()+ ' '+completedDateObj.getHours()+':'+completedDateObj.getMinutes()+':'+completedDateObj.getSeconds() ;
    }
    else /* Year is 1969. This indicates that the job is still in process*/
    {
      completedDateStr = '-' ;
    }
    var jobName = respArr[ii]['jobName'] ;
    var tool = respArr[ii]['tool'] ;
    var status = respArr[ii]['status'] ;
    if (status == 'wait4deps') {
      status = 'Wait on Deps' ;
    }
    var timeInCurrentStatus = respArr[ii]['timeInCurrentStatus'] ;
    if (timeInCurrentStatus != 'N/A') {
      timeInCurrentStatus = secondsToString(timeInCurrentStatus)
    }
    jobData.push({'jobName': jobName, 'tool': tool, 'submitDate': submitDateStr, 'completedDate': completedDateStr, 'status':  status, 'timeInCurrentStatus': timeInCurrentStatus }) ;
  }
  return jobData ;
}


// Copied from the 'jobAccepted/rhtml' page of the Job Summary tool in the workbench.
function secondsToString(seconds)
{
  var numdays = Math.floor((seconds % 31536000) / 86400);
  var numhours = Math.floor(((seconds % 31536000) % 86400) / 3600);
  var numminutes = Math.floor((((seconds % 31536000) % 86400) % 3600) / 60);
  return numdays + " days " + numhours + " hours " + numminutes + " min " ;
}

function changeCollection()
{
  // Nuke any existing non-core fields. These may differ from model to model
  nonCoreFields = {} ;
  // Load up the right model
  resetMainPanel() ;
  //initTreeGrid() ;
  //Ext.getCmp('browseDocsGrid').getView().select(0) ;
  loadModel(Ext.getCmp('collectionSetCombobox').value, false) ; // defined in ajax.js
  prevCollection = Ext.getCmp('collectionSetCombobox').value ;
}

// Displays dialog for uploading file from user's machine.
// Upon submission of form, uploads file to server (rails controller) which makes an API call to Genboree to upload the docs.
function displayDocsUploadDialog()
{
  Ext.create('Ext.window.Window', {
    title: 'Upload Documents',
    height: 170,
    width: 400,
    id: 'uploadDocsDisplayWindow',
    modal: true,
    autoScroll: true,
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
          style: {
            marginTop: '10px',
            marginRight: '3px',
            marginLeft: '3px'
            
          },
          buttonText: 'Select File...'
        },
        {
          xtype: 'combobox',
          editable: false,
          fieldLabel: '<b>Format</b>',
          store: ['JSON', 'TABBED - Compact Property Names', 'Tabbed (Multi) - Compact Property Names'],
          value: 'JSON',
          width: 330,
          style: {
            marginRight: '3px',
            marginLeft: '3px'
            
          },
          id: 'format'
        }
      ],
      buttons:
      [
        {
          text: 'Upload',
          handler: function() {
            var form = this.up('form').getForm();
            var fileBaseName = form.monitor.items.items[0].rawValue.split("\\").reverse()[0] ;
            var format = form.monitor.items.items[1].rawValue
            // Contruct the action URL with all the form elements EXCEPT the file itself which we will de-encode using Event Machine.
            var actionUrl = 'genboree_kbs/collection/uploaddocs?'+'authenticity_token='+encodeURIComponent(csrf_token)+'&kbName='+escape(kbName)+'&kbDb='+escape(kbDb)+'&project_id='+escape(projectId)+'&collectionSet='+escape( Ext.getCmp('collectionSetCombobox').value)+'&format='+escape(form.monitor.items.items[1].value)+'&fileBaseName='+escape(fileBaseName)+'&format-inputEl='+escape(format)  ;
            if(form.isValid()){
              form.submit({
                url: actionUrl,
                waitMsg: 'Uploading your file...',
                success: function(form, action) {
                  //var jobId = JSON.parse(action.response.responseText)['msg'] ;
                  //var msg = "Your job: <b>"+jobId+"</b> has been submitted on our cluster.</br></br>You should receive an email once the job has finished running." ;
                  var msg = "Your file has been accepted.</br><b>Upload is in progress</b>.</br>A Kb Bulk Upload job will be submitted on your behalf once the file has finished uploading."
                  var msgBox = Ext.create('Ext.window.MessageBox', {
                    overflowY: 'auto',
                  }).show({
                    title: 'SUCCESS',
                    msg: msg,
                    width: 400,
                    buttons: Ext.Msg.OK
                  }) ;
                  Ext.getCmp('uploadDocsDisplayWindow').close() ;
                },
                failure: function(form, action){
                  var msg = 'Your document(s) could not be uploaded.' ;
                  try {
                    msg = msg + "</br></br>" + JSON.parse(action.response.responseText)['msg'].replace(/{linebreak}/g, "</br></br>") ;
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
                    buttons: Ext.Msg.OK
                  }) ;
                  Ext.getCmp('uploadDocsDisplayWindow').close() ;
                }
              });
            }
          }
        }
      ]
    }
  }).show();

}