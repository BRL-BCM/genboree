
function initTreeGridToolbar()
{
  var treeGridToolbar = new Ext.Toolbar({
    width:'auto',
    id: 'mainTreeGridToolbar',
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
        handler : addChildNode // defined in misc.js
      },
      {
        itemId: 'removeRow',
        //text: 'Remove',
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
              Ext.DomHelper.append(document.body, {
                tag: 'iframe',
                frameBorder: 0,
                width: 0,
                height: 0,
                css: 'display:none;visibility:hidden;height:1px;',
                src: 'genboree_kbs/doc/download?authenticity_token='+csrf_token+'&collectionSet='+escape(Ext.getCmp('collectionSetCombobox').value)+'&itemId='+escape(newdocObj[docModel.name].value)+'&project_id='+projectId+'&download_format=json'
              });
              
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
              Ext.DomHelper.append(document.body, {
                tag: 'iframe',
                frameBorder: 0,
                width: 0,
                height: 0,
                css: 'display:none;visibility:hidden;height:1px;',
                src: 'genboree_kbs/doc/download?download_format=tabbed_prop_path&authenticity_token='+csrf_token+'&collectionSet='+escape(Ext.getCmp('collectionSetCombobox').value)+'&itemId='+escape(newdocObj[docModel.name].value)+'&project_id='+projectId
              });
              
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
             
              Ext.DomHelper.append(document.body, {
                tag: 'iframe',
                frameBorder: 0,
                width: 0,
                height: 0,
                css: 'display:none;visibility:hidden;height:1px;',
                src: 'genboree_kbs/doc/download?download_format=tabbed_prop_nesting&authenticity_token='+csrf_token+'&collectionSet='+escape(Ext.getCmp('collectionSetCombobox').value)+'&itemId='+escape(newdocObj[docModel.name].value)+'&project_id='+projectId
              });
              
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
        icon: 'plugin_assets/genboree_kbs/images/silk/application_link.png',
        xtype: 'splitbutton',
        disabled: true,
        arrowAlign: 'right',
        menu: [
          { text: 'Get URL', handler: function(){
            Ext.create('Ext.window.Window', {
              title: 'Document URL',
              height: 120,
              width: 600,
              autoScroll: true,
              html: "You can copy the following URL to your clipboard:</br><div style=\"width:auto; height:auto; background-color: white; padding-left:3px; padding-right:3px;\"><p>"+location.origin+location.pathname+'?project_id='+projectIdentifier+'&coll='+currentCollection+'&doc='+escape(newdocObj[docModel.name].value)+"</p></div>"
            }).show() ;
          }},
          { text: 'Get URL with state', disabled: true, tooltip: { text: 'This functionality is still being developed and is not yet available.' } }
        ]
      },
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
        width       : 200,
        maxHeight   : 20,
        minChars    : 1,
        // blankText   : '',
        // allowBlank  : false,
        autoScroll  : true,
        autoSelect  : false,
        checkChangeBuffer : 100,
        queryDelay  : 250,
        hideTrigger : true,
        matchFieldWidth : false,
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
          border      : 1
        },
        tpl         : '<tpl for="."><div class=" x-boundlist-item {[xindex %2 == 0 ? "even" : "odd" ]} "> {value} </div></tpl>',
        valueNotFoundText : '(No matching docs)',
        //pageSize    : searchPageSize, // MAY BE USEFUL TO PROVIDE THIS WHEN API QUERY ALSO SUPPORTS PAGING/INDEXES
        listeners   :
        {
          'select': function(item) {
            loadDocument(item.value, false) ; // defined in ajax.js
          },
          'specialkey': function(field, e, eOpts){
            
            if (e.getKey() == e.ENTER) {
              if (field.rawValue != "") {
                var val = field.rawValue ;
                this.doQuery(val, false, true) ;
              }
            }
          },
          'beforequery': function(aa, bb){
            var cc ;
          }
        }
      }
    ]
  }) ;
}

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
        disabled: false,
        icon: 'plugin_assets/genboree_kbs/images/download.png',
        xtype: 'splitbutton',
        arrowAlign: 'right',
        menu: [
          { text: 'JSON', itemId: 'jsonModelTreeDownloadBtn', handler: function(){
            Ext.DomHelper.append(document.body, {
              tag: 'iframe',
              frameBorder: 0,
              width: 0,
              height: 0,
              css: 'display:none;visibility:hidden;height:1px;',
              src: 'genboree_kbs/model/download?download_format=json&authenticity_token='+csrf_token+'&collectionSet='+escape(Ext.getCmp('collectionSetCombobox').value)+'&project_id='+projectId
            });
          }},
          { text: 'Tabbed - Full Property Names', itemId: 'tbdFPNModelTreeDownloadBtn',
            tooltip: {
              title: 'Tabbed - Full Property Names',
              text: '&#149;&nbsp;The property name column contains the full property-path.</br>&#149;&nbsp;Each record/line has the complete nesting context of the property.</br>&#149;&nbsp;More complete, but very long & redundant property names.'
            },
            handler: function(){
            Ext.DomHelper.append(document.body, {
              tag: 'iframe',
              frameBorder: 0,
              width: 0,
              height: 0,
              css: 'display:none;visibility:hidden;height:1px;',
              src: 'genboree_kbs/model/download?download_format=tabbed_prop_path&authenticity_token='+csrf_token+'&collectionSet='+escape(Ext.getCmp('collectionSetCombobox').value)+'&project_id='+projectId
            });
          }},
          { text: 'Tabbed - Compact Property Names', itemId: 'tbdCPNModelTreeDownloadBtn',
            tooltip: {
              title: 'Tabbed - Compact Property Names',
              text: '&#149;&nbsp;The property name column contains a prefix summarizing of the relative nesting context and then the actual property name.</br>&#149;&nbsp;The nesting prefix also indicates whether the property contains sub-props (ends with -) or a list of sub-items (ends with +).</br>&#149;&nbsp;Each record/line can only be understood in context of the records/line before it.</br>&#149;&nbsp;Less complete, but shorter summary, less redundancy, and compact.'
            },
            handler: function(){
            Ext.DomHelper.append(document.body, {
              tag: 'iframe',
              frameBorder: 0,
              width: 0,
              height: 0,
              css: 'display:none;visibility:hidden;height:1px;',
              src: 'genboree_kbs/model/download?download_format=tabbed_prop_nesting&authenticity_token='+csrf_token+'&collectionSet='+escape(Ext.getCmp('collectionSetCombobox').value)+'&project_id='+projectId
            });
          }}
        ]
      }
      
    ]
  }) ;
}
