Ext.onReady(function(){
    
    Ext.require([
      'Ext.data.*',
      'Ext.grid.*',
      'Ext.tree.*'
    ]);

    Ext.onReady(function() {
      
      // ------------------------------------------------------------------
      // Define accordian data models
      // ------------------------------------------------------------------
      Ext.define('BrowseRecord',
      {
        extend : 'Ext.data.Model',
        fields : [ 'browseFuncName', 'url', 'genbKbIconCls' ]
      }) ;
      Ext.define('ManageRecords',
      {
        extend : 'Ext.data.Model',
        fields : [ 'recordFuncName', 'url', 'genbKbIconCls' ]
      }) ;
      Ext.define('Queries',
      {
        extend : 'Ext.data.Model',
        fields : [ 'queryFuncName', 'url', 'genbKbIconCls' ]
      }) ;
      Ext.define('ManageViews',
      {
        extend : 'Ext.data.Model',
        fields : [ 'viewFuncName', 'url', 'genbKbIconCls' ]
      }) ;
      Ext.define('AdminDatasets',
      {
        extend : 'Ext.data.Model',
        fields : [ 'datasetFuncName', 'category', 'url', 'genbKbIconCls' ]
      }) ;
      
      var browseFuncStore = Ext.create('Ext.data.Store',
      {
        storeId    : 'recordFunc',
        model      : 'BrowseRecord',
        data       :
        [
          { browseFuncName : 'Dynamic tree', url : 'http://google.com', genbKbIconCls : 'genbKb-dynamicTree' },
          { browseFuncName : 'Plain HTML', url : 'http://yahoo.com', genbKbIconCls : 'genbKb-plainHTML' },
          { browseFuncName : 'Using a View', url : 'http://yahoo.com', genbKbIconCls : 'genbKb-usingView' }
        ]
      }) ;
      // RECORDS
      var recordsFuncStore = Ext.create('Ext.data.Store',
      {
        storeId    : 'recordFunc',
        model      : 'ManageRecords',
        data       :
        [
          { recordFuncName : 'Create new Record', url : 'http://yahoo.com', genbKbIconCls : 'genbKb-createRecord' },
          { recordFuncName : 'Edit Record', url : 'http://yahoo.com', genbKbIconCls : 'genbKb-editRecord' },
          { recordFuncName : 'Delete Record', url : 'http://yahoo.com', genbKbIconCls : 'genbKb-deleteRecord' },
          { recordFuncName : 'Bulk Record upload', url : 'http://yahoo.com', genbKbIconCls : 'genbKb-bulkUpload' },
          { recordFuncName : 'Record history', url : 'http://yahoo.com', genbKbIconCls : 'genbKb-recordHistory' }
        ]
      }) ;
      // QUERIES
      var queriesFuncStore = Ext.create('Ext.data.Store',
      {
        storeId    : 'queryFunc',
        model      : 'Queries',
        data       :
        [
          { queryFuncName : 'Run existing Query', url : 'http://google.com', genbKbIconCls : 'genbKb-runQuery' },
          { queryFuncName : 'Create new Query', url : 'http://yahoo.com', genbKbIconCls : 'genbKb-createQuery' },
          { queryFuncName : 'Edit/copy Query', url : 'http://yahoo.com', genbKbIconCls : 'genbKb-editQuery' },
          { queryFuncName : 'Delete Queries', url : 'http://yahoo.com', genbKbIconCls : 'genbKb-deleteQuery' }
        ]
      }) ;
      // MANAGE VIEWS
      var viewsFuncStore = Ext.create('Ext.data.Store',
      {
        storeId    : 'viewsFunc',
        model      : 'ManageViews',
        data       :
        [
          { viewFuncName : 'Create new View', url : 'http://yahoo.com', genbKbIconCls : 'genbKb-createView' },
          { viewFuncName : 'Edit/copy exiting View', url : 'http://yahoo.com', genbKbIconCls : 'genbKb-editView' },
          { viewFuncName : 'Delete a View', url : 'http://yahoo.com', genbKbIconCls : 'genbKb-deleteView' }
        ]
      }) ;
      // MANAGE DATASETS
      var datasetFuncStore = Ext.create('Ext.data.Store',
      {
        storeId    : 'datasetFunc',
        model      : 'AdminDatasets',
        groupers   :
        [
          { property : 'category', sorterFn : function(aa, bb) {} }
        ],
        data       :
        [
          { category : 'All Users', datasetFuncName : 'Browse Datasets & Models', url : 'http://yahoo.com', genbKbIconCls : 'genbKb-browseDatasets' },
          { category : 'All Users', datasetFuncName : 'Download Datasets', url : 'http://yahoo.com', genbKbIconCls : 'genbKb-downloadDataset' },
          { category : 'All Users', datasetFuncName : 'View Model history', url : 'http://yahoo.com', genbKbIconCls : 'genbKb-viewModelHistory' },
          { category : 'Admin Only', datasetFuncName : 'Create new Dataset', url : 'http://google.com', genbKbIconCls : 'genbKb-createDataset' },
          { category : 'Admin Only', datasetFuncName : 'Edit a Dataset\'s Model', url : 'http://google.com', genbKbIconCls : 'genbKb-editDatasetModel' },
          { category : 'Admin Only', datasetFuncName : 'Archive a Dataset', url : 'http://google.com', genbKbIconCls : 'genbKb-archiveDataset' }
        ]
      }) ;
      var datasetFuncGroupingFeature = Ext.create('Ext.grid.feature.Grouping',
      {
        id                : 'selectDatasetFuncGrouping',
        groupHeaderTpl    : '{name}:',
        hideGroupedHeader : true,
        startCollapsed    : true
      }) ;
        
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
      
      var panelHeight = 600 ;
      var panelWidth = 845 ;
      // Create 'border' layout to house the tree-grid interface.
      var containerPanelToolbar = new Ext.Toolbar({
        width:'auto',
        items: [
                {
                  xtype: 'tbtext',
                  text: 'Data Set:'
                },
                {
                  xtype: 'combobox',
                  displayField: 'name',
                  valueField: 'value',
                  queryMode: 'local',
                  value: 'varPheno',
                  // load up the appropriate the data
                  listeners: {
                    select: function(e){
                      tree.getStore().getRootNode().removeAll() ;
                      tree.getStore().getRootNode().remove() ;
                      if(e.value == 'varPheno')
                      {
                        //store.setRootNode({children: seqVariantEx, expanded: true}) ;
                        tree.getStore().setRootNode(seqVarstore.getRootNode().copy(null, true)) ;
                      }
                      else
                      {
                        //store.setRootNode({children: clinVarEx, expanded: true}) ;
                        tree.getStore().setRootNode(clinVarstore.getRootNode().copy(null, true)) ;
                      }
                      //debugger ;
                    }
                  },
                  store: Ext.create('Ext.data.Store', {
                    fields: ['name', 'value'],
                    data : [
                        {"name":"Variants (ClinVar)", "value": "varClinVar"},
                        {"name":"Variant-Phenotype", "value": "varPheno"}
                    ]
                  })
                }
              ]
      }) ;
      Ext.create('Ext.panel.Panel', {
        width: panelWidth,
        height: panelHeight, // Add pixels for tool bar
        //title: 'Genboree KB - Tree Grid Editor',
        tbar: containerPanelToolbar,
        //header: true,
        layout: 'border',
        items: [{
            // xtype: 'panel' implied by default
            title: 'Functionality listing',
            region:'west',
            header: false,
            xtype: 'panel',
            margins: '5 0 0 5',
            width: 185,
            //collapsible: false,   // make collapsible
            //spilt: true,
            id: 'west-region-container',
            //layout: 'fit'
            layout:
            {
              type  : 'vbox',
              pack  : 'start',
              align : 'stretch'
            },
            items:
            [
              // ************************
                  // Accordion config placed into the west border is here
                  // ************************
                  {
                    layout :
                    {
                      type             : 'accordion',
                      animate          : true,
                      collapsible      : true,
                      titleCollapse    : true,
                      multi            : true,
                      hideCollapseTool : false
                    },
                    padding  : '0 0 30 0',
                    border   : 0,
                    defaults : { bodyStyle : 'padding: 10px 5px 10px 5px; background-color: #FFFFFF', style : 'background-color: #FFFFFF' },
                    items    :
                    [
                      // BROWSE RECORDS
                      {
                        title  : 'Browse Records',
                        layout : 'fit',
                        frame  : true,
                        bodyStyle : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
                        style : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
                        items  :
                        [
                          Ext.create('Ext.grid.Panel',
                          {
                            header      : false,
                            hideHeaders : true,
                            collapsed   : false,
                            collapsible : true,
                            sortableColumns : false,
                            stateful    : false,
                            enableColumnResize : false,
                            rowLines    : false,
                            frame       : false,
                            viewConfig  : { stripeRows : false },
                            border      : 0,
                            bodyCls     : 'noHeaderGridCls',
                            tpl         : '<i>{recordFuncName}</i>',
                            bodyStyle   : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
                            style       : 'background-color: #FFFFFF',
                            store       : browseFuncStore,
                            resizable   : false,
                            columns     :
                            [
                              { flex : 1, dataIndex : 'browseFuncName', sortable : false, hideable : false, renderer : function(value, metaData, record, row, col, store, view) { return Ext.String.format('<div class="genbKb-accordion-item {2}"><a href="{0}">{1}</a></div>', record.data.url, record.data.browseFuncName, record.data.genbKbIconCls); } }
                            ]
                          })
                        ]
                      },
                      // MANAGE RECORDS
                      {
                        title  : 'Manage Records',
                        layout : 'fit',
                        frame  : true,
                        bodyStyle : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
                        style : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
                        items  :
                        [
                          Ext.create('Ext.grid.Panel',
                          {
                            header      : false,
                            hideHeaders : true,
                            collapsed   : false,
                            sortableColumns : false,
                            stateful    : false,
                            enableColumnResize : false,
                            rowLines    : false,
                            frame       : false,
                            viewConfig  : { stripeRows : false },
                            border      : 0,
                            bodyCls     : 'noHeaderGridCls',
                            tpl         : '<i>{datasetFuncName}</i>',
                            bodyStyle   : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
                            style       : 'background-color: #FFFFFF',
                            store       : recordsFuncStore,
                            resizable   : false,
                            columns     :
                            [
                              { flex : 1, dataIndex : 'recordFuncName', sortable : false, hideable : false, cls : "genbKb-accordion-item", renderer : function(value, metaData, record, row, col, store, view) { return Ext.String.format('<div class="genbKb-accordion-item {2}"><a href="{0}">{1}</a></div>', record.data.url, record.data.recordFuncName, record.data.genbKbIconCls); } }
                            ]
                          })
                        ]
                      },
                      // MANAGE QUERIES
                      {
                        title  : 'Manage Queries',
                        layout : 'fit',
                        frame  : true,
                        bodyStyle : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
                        style : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
                        items  :
                        [
                          Ext.create('Ext.grid.Panel',
                          {
                            header      : false,
                            hideHeaders : true,
                            collapsed   : false,
                            sortableColumns : false,
                            stateful    : false,
                            enableColumnResize : false,
                            rowLines    : false,
                            frame       : false,
                            viewConfig  : { stripeRows : false },
                            border      : 0,
                            bodyCls     : 'noHeaderGridCls',
                            tpl         : '<i>{datasetFuncName}</i>',
                            bodyStyle   : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
                            style       : 'background-color: #FFFFFF',
                            store       : queriesFuncStore,
                            resizable   : false,
                            columns     :
                            [
                              { flex : 1, dataIndex : 'queryFuncName', sortable : false, hideable : false, cls : "genbKb-accordion-item", renderer : function(value, metaData, record, row, col, store, view) { return Ext.String.format('<div class="genbKb-accordion-item {2}"><a href="{0}">{1}</a></div>', record.data.url, record.data.queryFuncName, record.data.genbKbIconCls); } }
                            ]
                          })
                        ]
                      },
                      // MANAGE VIEWS
                      {
                        title  : 'Manage Views',
                        layout : 'fit',
                        frame  : true,
                        bodyStyle : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
                        style : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
                        items  :
                        [
                          Ext.create('Ext.grid.Panel',
                          {
                            header      : false,
                            hideHeaders : true,
                            collapsed   : false,
                            sortableColumns : false,
                            stateful    : false,
                            enableColumnResize : false,
                            rowLines    : false,
                            frame       : false,
                            viewConfig  : { stripeRows : false },
                            border      : 0,
                            bodyCls     : 'noHeaderGridCls',
                            tpl         : '<i>{datasetFuncName}</i>',
                            bodyStyle   : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
                            style       : 'background-color: #FFFFFF',
                            store       : viewsFuncStore,
                            resizable   : false,
                            columns     :
                            [
                              { flex : 1, dataIndex : 'viewFuncName', sortable : false, hideable : false, cls : "genbKb-accordion-item", renderer : function(value, metaData, record, row, col, store, view) { return Ext.String.format('<div class="genbKb-accordion-item {2}"><a href="{0}">{1}</a></div>', record.data.url, record.data.viewFuncName, record.data.genbKbIconCls); } }
                            ]
                          })
                        ]
                      },
                      // MANAGE DATA SETS
                      {
                        title  : 'Manage Datasets',
                        layout : 'fit',
                        frame  : true,
                        bodyStyle : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
                        style : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
                        items  :
                        [
                          Ext.create('Ext.grid.Panel',
                          {
                            header      : false,
                            hideHeaders : true,
                            collapsed   : false,
                            sortableColumns : false,
                            stateful    : false,
                            enableColumnResize : false,
                            rowLines    : false,
                            frame       : false,
                            viewConfig  : { stripeRows : false },
                            border      : 0,
                            bodyCls     : 'noHeaderGridCls',
                            tpl         : '<i>{datasetFuncName}</i>',
                            bodyStyle   : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
                            style       : 'background-color: #FFFFFF',
                            store       : datasetFuncStore,
                            resizable   : false,
                            features    : datasetFuncGroupingFeature,
                            columns     :
                            [
                              { text : 'Category', flex : 1, dataIndex : 'category', sortable : false, hideable : false },
                              { flex : 1, dataIndex : 'datasetFuncName', sortable : false, hideable : false, cls : "genbKb-accordion-item", renderer : function(value, metaData, record, row, col, store, view) { return Ext.String.format('<div class="genbKb-accordion-item {2}"><a href="{0}">{1}</a></div>', record.data.url, record.data.datasetFuncName, record.data.genbKbIconCls); } }
                            ],
                            listeners :
                            {
                              // Expand first group (public projects) once grid is viewable
                              viewready :
                              {
                                el : 'el',
                                fn : function(grid, width, height, eOpts) {
                                  grid.features[0].expand('All Users', false) ;
                                  return true ;
                                }
                              },
                              refresh :
                              {
                                fn : function(grid, eOpts) { grid.features[0].expand('', true) ; }
                              }
                            }
                          })
                        ]
                      }
                    ]
                  }
            ]
        },{
            title: 'Editable Tree Grid',
            header: false,
            region: 'center',     // center region is required, no width/height specified
            xtype: 'panel',
            layout: 'fit',
            id: 'treeGridContainer',
            margins: '5 5 0 0'
        }],
        renderTo: 'layoutContainerDiv'
      });
      
      Ext.define('Task', {
          extend: 'Ext.data.Model',
          fields: [
              {name: 'name', type: 'string'},
              {name: 'value', type: 'string'}
          ]
      });
      
      Ext.create('Ext.panel.Panel', {
        //height: panelHeight-32,
        layout :
        {
          type             : 'accordion',
          animate          : true,
          collapsible      : true,
          titleCollapse    : true,
          multi            : true,
          hideCollapseTool : false
        },
        padding  : '0 0 0 0',
        border   : 0,
        defaults : { bodyStyle : 'padding: 10px 5px 10px 5px; background-color: #FFFFFF', style : 'background-color: #FFFFFF' },
        items    :
        [
          // BROWSE RECORDS
          {
            title  : 'Browse Records',
            layout : 'fit',
            frame  : true,
            bodyStyle : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
            style : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
            items  :
            [
              Ext.create('Ext.grid.Panel',
              {
                header      : false,
                hideHeaders : true,
                collapsed   : false,
                collapsible : true,
                sortableColumns : false,
                stateful    : false,
                enableColumnResize : false,
                rowLines    : false,
                frame       : false,
                viewConfig  : { stripeRows : false },
                border      : 0,
                bodyCls     : 'noHeaderGridCls',
                tpl         : '<i>{recordFuncName}</i>',
                bodyStyle   : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
                style       : 'background-color: #FFFFFF',
                store       : browseFuncStore,
                resizable   : false,
                columns     :
                [
                  { flex : 1, dataIndex : 'browseFuncName', sortable : false, hideable : false, renderer : function(value, metaData, record, row, col, store, view) { return Ext.String.format('<div class="genbKb-accordion-item {2}"><a href="{0}">{1}</a></div>', record.data.url, record.data.browseFuncName, record.data.genbKbIconCls); } }
                ]
              })
            ]
          },
          // MANAGE RECORDS
          {
            title  : 'Manage Records',
            layout : 'fit',
            frame  : true,
            bodyStyle : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
            style : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
            items  :
            [
              Ext.create('Ext.grid.Panel',
              {
                header      : false,
                hideHeaders : true,
                collapsed   : false,
                sortableColumns : false,
                stateful    : false,
                enableColumnResize : false,
                rowLines    : false,
                frame       : false,
                viewConfig  : { stripeRows : false },
                border      : 0,
                bodyCls     : 'noHeaderGridCls',
                tpl         : '<i>{datasetFuncName}</i>',
                bodyStyle   : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
                style       : 'background-color: #FFFFFF',
                store       : recordsFuncStore,
                resizable   : false,
                columns     :
                [
                  { flex : 1, dataIndex : 'recordFuncName', sortable : false, hideable : false, cls : "genbKb-accordion-item", renderer : function(value, metaData, record, row, col, store, view) { return Ext.String.format('<div class="genbKb-accordion-item {2}"><a href="{0}">{1}</a></div>', record.data.url, record.data.recordFuncName, record.data.genbKbIconCls); } }
                ]
              })
            ]
          },
          // MANAGE QUERIES
          {
            title  : 'Manage Queries',
            layout : 'fit',
            frame  : true,
            bodyStyle : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
            style : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
            items  :
            [
              Ext.create('Ext.grid.Panel',
              {
                header      : false,
                hideHeaders : true,
                collapsed   : false,
                sortableColumns : false,
                stateful    : false,
                enableColumnResize : false,
                rowLines    : false,
                frame       : false,
                viewConfig  : { stripeRows : false },
                border      : 0,
                bodyCls     : 'noHeaderGridCls',
                tpl         : '<i>{datasetFuncName}</i>',
                bodyStyle   : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
                style       : 'background-color: #FFFFFF',
                store       : queriesFuncStore,
                resizable   : false,
                columns     :
                [
                  { flex : 1, dataIndex : 'queryFuncName', sortable : false, hideable : false, cls : "genbKb-accordion-item", renderer : function(value, metaData, record, row, col, store, view) { return Ext.String.format('<div class="genbKb-accordion-item {2}"><a href="{0}">{1}</a></div>', record.data.url, record.data.queryFuncName, record.data.genbKbIconCls); } }
                ]
              })
            ]
          },
          // MANAGE VIEWS
          {
            title  : 'Manage Views',
            layout : 'fit',
            frame  : true,
            bodyStyle : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
            style : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
            items  :
            [
              Ext.create('Ext.grid.Panel',
              {
                header      : false,
                hideHeaders : true,
                collapsed   : false,
                sortableColumns : false,
                stateful    : false,
                enableColumnResize : false,
                rowLines    : false,
                frame       : false,
                viewConfig  : { stripeRows : false },
                border      : 0,
                bodyCls     : 'noHeaderGridCls',
                tpl         : '<i>{datasetFuncName}</i>',
                bodyStyle   : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
                style       : 'background-color: #FFFFFF',
                store       : viewsFuncStore,
                resizable   : false,
                columns     :
                [
                  { flex : 1, dataIndex : 'viewFuncName', sortable : false, hideable : false, cls : "genbKb-accordion-item", renderer : function(value, metaData, record, row, col, store, view) { return Ext.String.format('<div class="genbKb-accordion-item {2}"><a href="{0}">{1}</a></div>', record.data.url, record.data.viewFuncName, record.data.genbKbIconCls); } }
                ]
              })
            ]
          },
          // MANAGE DATA SETS
          {
            title  : 'Manage Datasets',
            layout : 'fit',
            frame  : true,
            bodyStyle : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
            style : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
            items  :
            [
              Ext.create('Ext.grid.Panel',
              {
                header      : false,
                hideHeaders : true,
                collapsed   : false,
                sortableColumns : false,
                stateful    : false,
                enableColumnResize : false,
                rowLines    : false,
                frame       : false,
                viewConfig  : { stripeRows : false },
                border      : 0,
                bodyCls     : 'noHeaderGridCls',
                tpl         : '<i>{datasetFuncName}</i>',
                bodyStyle   : 'padding: 0px 0px 0px 0px; background-color: #FFFFFF',
                style       : 'background-color: #FFFFFF',
                store       : datasetFuncStore,
                resizable   : false,
                features    : datasetFuncGroupingFeature,
                columns     :
                [
                  { text : 'Category', flex : 1, dataIndex : 'category', sortable : false, hideable : false },
                  { flex : 1, dataIndex : 'datasetFuncName', sortable : false, hideable : false, cls : "genbKb-accordion-item", renderer : function(value, metaData, record, row, col, store, view) { return Ext.String.format('<div class="genbKb-accordion-item {2}"><a href="{0}">{1}</a></div>', record.data.url, record.data.datasetFuncName, record.data.genbKbIconCls); } }
                ],
                listeners :
                {
                  // Expand first group (public projects) once grid is viewable
                  viewready :
                  {
                    el : 'el',
                    fn : function(grid, width, height, eOpts) {
                      grid.features[0].expand('All Users', false) ;
                      return true ;
                    }
                  },
                  refresh :
                  {
                    fn : function(grid, eOpts) { grid.features[0].expand('', true) ; }
                  }
                }
              })
            ]
          }
        ]
        //renderTo: 'west-region-container-body'
      });
      
      var defaultNonLeafRecord = {name: 'attribute', value: 'value' } ;
      var defaultLeafRecord = {name: 'attribute', value: 'value', leaf: true } ;
      // Tree for the western panel of the layout
      var storeWesternPanel = Ext.create('Ext.data.TreeStore', {
        root: {
            expanded: true,
            children: [
                { text: "detention", leaf: true },
                { text: "homework", expanded: true, children: [
                    { text: "book report", leaf: true },
                    { text: "algebra", leaf: true}
                ] },
                { text: "buy lottery tickets", leaf: true }
            ]
        }
      });
      
      
      var seqVarstore = Ext.create('Ext.data.TreeStore', {
          model: 'Task',
          proxy: 'memory',
          root: {
            expanded: true,
            children: seqVariantEx
          }
      });
      
      var clinVarstore = Ext.create('Ext.data.TreeStore', {
          model: 'Task',
          proxy: 'memory',
          root: {
            expanded: true,
            children: clinVarEx
          }
      });
      
       // Main TreeGrid for the central panel.
      var selectStore = Ext.create('Ext.data.Store', {
          fields: ['name'],
          data : [
              {"name":"Display text widget"},
              {"name":"Display date widget"},
              {"name":"Display checkbox widget"}
              //...
          ]
      });
      
      var searchboxStore = Ext.create('Ext.data.Store', {
          fields: ['svalue'],
          data : [
              {"svalue":"RCV00003"},
              {"svalue":"RCV000031"},
              {"svalue":"RCV00003654"},
              {"svalue":"RCV000037626"},
              {"svalue":"RCV000037650"}
              
              //...
          ]
      });
      
      var combo = Ext.create('Ext.form.ComboBox', {
                                                  store: selectStore,
                                                  queryMode: 'local',
                                                  displayField: 'name',
                                                  valueField: 'name'
                                              }) ;
      var editModeValue = true ;
      var rowEditing = Ext.create('Ext.grid.plugin.RowEditing', {
        clicksToEdit: 2,
        listeners: {
          beforeedit : function(editor, context, eOpts){
            var attrCM = context.grid.columns[0] ;
            var origWidthCM = attrCM.getWidth() ;
            var valCM = context.grid.columns[1] ;
            var origWidthVal = valCM.getWidth() ;
            //debugger ;
            var fieldName = context.record.data['name'] ;
            var domain = context.record.data['domain'] ;
            if(fieldName == 'Allele frequency' || fieldName == 'start' || fieldName == 'end' || fieldName == "Size" || fieldName == "Carrier")
            {
              valCM.setEditor('numberfield') ;
            }
            else if(fieldName == 'Date' || fieldName == "Import date")
            {
              valCM.setEditor('datefield') ;
            }
            else if(domain == 'enum')
            {
              var enumVals = context.record.data['domainOpts']['values'] ;
              var storeData = [] ;
              var ii ;
              for(ii=0; ii<enumVals.length; ii++)
              {
                storeData.push({"name": enumVals[ii], "value": enumVals[ii]}) ;
              }
              valCM.setEditor({
                xtype: 'combobox', store: storeData, queryMode: 'local', displayField: 'name', valueField: 'name' 
              }) ;
              debugger ;
            }
            else
            {
              var textFieldObj ;
              if(fieldName == 'rsID' || fieldName == 'dbSNP ID')
              {
                textFieldObj = { xtype: 'textfield', regex: /^rs\d+$/} ;
              }
              else if(fieldName == 'rcvID')
              {
                textFieldObj = { xtype: 'textfield', regex: /^RCV\d+$/} ;
              }
              else
              {
                textFieldObj = {xtype: 'textfield'}
              }
              valCM.setEditor(textFieldObj) ;
            }
            var valueEditor = valCM.getEditor() ;
            valueEditor.setWidth(origWidthVal) ;
            //attrCM.disable() ;
            //cm.setEditor({xtype: 'combobox', store: selectStore, queryMode: 'local', displayField: 'name', valueField: 'name' }) ;
            //var comboBoxEditor = cm.getEditor() ;
            ////debugger ;
            //comboBoxEditor.setWidth(origWidth) ;
            //comboBoxEditor.on('select', function(e){
            //  if(e.value == 'Display text widget')
            //  {
            //    context.grid.columns[1].setEditor('textfield') ;
            //  }
            //  else if(e.value == 'Display checkbox widget')
            //  {
            //    context.grid.columns[1].setEditor('checkbox') ;
            //  }
            //  else if(e.value == 'Display date widget')
            //  {
            //    context.grid.columns[1].setEditor('datefield') ;
            //  }
            //  else
            //  {
            //    context.grid.columns[1].setEditor('textfield') ;
            //  }
            //}) ;
            return editModeValue ;
          }
        }
      }) ;
      var selectedNodeIndex ;
      var treeGridToolbar = new Ext.Toolbar({
        width:'auto',
        items: [
                  {
                    itemId: 'addChildRow',
                    disabled: true,
                    text: 'Add child',
                    icon: '/plugin_assets/genboree_kbs/images/silk/add.png',
                    handler : function() {
                      rowEditing.cancelEdit();
                      var selectedNode = tree.getSelectionModel().getSelection()[0] ;
                      var nodeConfig ;
                      if(selectedNode)
                      {
                        selectedNode.appendChild(defaultLeafRecord) ;
                      }
                    }
                  },
                  {
                    itemId: 'addSiblingRow',
                    disabled: true,
                    text: 'Add sibling',
                    icon: '/plugin_assets/genboree_kbs/images/silk/table_row_insert.png',
                    handler: function(){
                      var rootNode = tree.getRootNode() ;
                      var selectedNode = tree.getSelectionModel().getSelection()[0] ;
                      var nodeDepth = selectedNode.getDepth() ;
                      var nodeIndex = rootNode.indexOf(selectedNode) ;
                      var parentNode = selectedNode.parentNode ;
                      if(selectedNode.raw.leaf)
                      {
                        parentNode.appendChild(defaultLeafRecord) ;
                      }
                      else
                      {
                        parentNode.appendChild(defaultNonLeafRecord) ;
                      }
                    }
                  },
                  {
                    itemId: 'removeRow',
                    text: 'Remove',
                    icon: '/plugin_assets/genboree_kbs/images/silk/delete.png',
                    handler: function() {
                      var selectedNode = tree.getSelectionModel().getSelection()[0] ;
                      selectedNode.removeAll() ;
                      selectedNode.remove() ;
                    },
                    disabled: true
                  },
                  {
                    itemId: 'editMode',
                    icon: '/plugin_assets/genboree_kbs/images/silk/table_edit.png',
                    text: 'Edit Mode',
                    xtype: 'splitbutton',
                    arrowAlign: 'right',
                    menu: [
                      {
                        text: 'On', handler: function(){
                          var treeGridComponent = Ext.getCmp('mainTreeGrid') ;
                          treeGridComponent.setTitle('Edit Mode: ON') ;
                          editModeValue = true ; // This is returned from the 'before edit' event of the row plugin. 
                        }
                      },
                      {
                        text: 'Off', handler: function(){
                          var treeGridComponent = Ext.getCmp('mainTreeGrid') ;
                          treeGridComponent.setTitle('Edit Mode: OFF') ;
                          editModeValue = false ;
                        }
                      }
                    ]
                  },
                  {
                    itemId: 'downloadBtn',
                    text: 'Download',
                    icon: '/plugin_assets/genboree_kbs/images/download.png',
                    xtype: 'splitbutton',
                    arrowAlign: 'right',
                    menu: [
                      {text: 'text'}
                    ]
                  },
                  {
                    text: 'Save',
                    icon: '/images/save.png'
                  },
                  {
                    xtype: 'tbfill'
                  },
                  {
                    xtype: 'tbtext',
                    text: 'Search:'
                  },
                  {
                    xtype: 'combobox',
                    width: 100,
                    hideTrigger: true,
                    store: searchboxStore,
                    queryMode: 'local',
                    displayField: 'svalue',
                    valueField: 'svalue' 
                  }
              ]
      }) ;
      var tree = Ext.create('Ext.tree.Panel', {
          title: 'Edit Mode: ON',
          //width: let it autoscale
          height: panelHeight-32, // set height to total hight of layout panel - height of menubar
          renderTo: 'treeGridContainer-body',
          collapsible: false,
          useArrows: true,
          id: 'mainTreeGrid',
          //header: false,
          rootVisible: false,
          store: seqVarstore, // XXXX Replace with the right store
          listeners: {
            select: function(){
              // Enable the 'add child row' and 'add sibling row' btns
              addRowsBtns = tree.getDockedItems()[1].items.items ;
              addRowsBtns[1].enable() ;
              addRowsBtns[2].enable() ;
            },
            itemclick: function(view, record, item, index, e){
              selectedNodeIndex = index ;
              addChildBtn = tree.getDockedItems()[1].items.items[0] ;
              if(record.raw.leaf) // Disable addChild btn if node is a leaf node
              {
                addChildBtn.disable() ;
              }
              else
              {
                addChildBtn.enable() ;
              }
            }
          },
          multiSelect: false,
          tbar: treeGridToolbar,
          singleExpand: false,
          selType: 'rowmodel',
          plugins: [rowEditing],
          //the 'columns' property is now 'headers'
          columns: [{
              xtype: 'treecolumn', //this is so we know which column will show the tree
              text: 'Attribute',
              flex: 2,
              width: 350,
              dataIndex: 'name',
              //editable: false
              editor: {
                xtype: 'textfield'
              }
          },
          {
              text: 'Value',
              flex: 1,
              width: 270,
              dataIndex: 'value',
              editor: {
                xtype: 'textfield'
              }
          }]
      });
    });
  }) ;