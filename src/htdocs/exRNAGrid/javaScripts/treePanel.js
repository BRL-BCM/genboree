// renders the panel - with toolbar and tree panel with a 
// null tree panel store.
function makePanel()
{

// get the store for the document search combo box
// implemented in ajax.js
var docStore =  getAnalysisComboStore() ;
  //ToolBar
  var toolBar = new Ext.Toolbar({
    cls: 'gvToolBar',
    items: [
    {
      text:'Clear Grid',
      id: "gvRefreshButton",
      tooltip: "<b>Clear the Grid</b><br><br>Use this button to clear the grid and select new analysis document to visualize.",
      iconCls: 'gvRefresh',
      handler: function()
      {
       var treeStore = Ext.getCmp('anGrid').store ;
       treeStore.removeAll();
       //clear combo
       Ext.getCmp('geneCombo').clearValue() ;
      }
     },

      '->',
    {
      xtype: 'combo',
      store: docStore,
      id: 'geneCombo',
      displayField: 'value',
      typeAhead: false,
      hideTrigger:true,
      minChars : 1,
      width: 200,
      autoScroll: true,
      forceSelection: true,
      anchor: '100%',
      emptyText: 'Type Analyses Document Name...',
      queryMode   : 'remote',
      listConfig: {
        loadingText: 'Searching...',
        emptyText: 'Search Document',
        //Custom rendering template for each item
        getInnerTpl: function() {
          return '<div class="search-item">' +
            '<span>{value}</span>' +
            '</div>';
          }
       },
       valueNotFoundText : '(No matching docs)',
       // override default onSelect to do redirect
       listeners: {
         select: function(combo, selection) {
            var post = selection[0];
            if (post) {
              anDoc = post.get('value') ;
              fillAnalysisGrid(anDoc) ;
            }
         }
      }
     }]
    });
 
  // store for the analysis grid
  var analysisStore = new Ext.data.SimpleStore(
    {
      fields:
      [
        { name : 'property' },
        { name : 'value' }
      ]
    }) ;

  // analysis grid definition
  var analysisGrid = new Ext.grid.GridPanel(
    {
      id: 'anGrid',
      width: 890,
      viewConfig: { forceFit: true },
      autoScroll: true,
      store: analysisStore,
      columns:
      [
        {
          id: 'property',
          text: 'Property',
          tip: "<b>Property</b><br>Description of the property being defined. Click arrow on right corner to sort this column.",
          listeners: {
              render: function(c) {
                Ext.create('Ext.tip.ToolTip', {
                  target: c.getEl(),
                  html: c.tip
                });
              }
          },
          dataIndex: 'property',
          width: 350,
          sortable: true
        },
        {
          id: 'value',
          text: 'Value',
          tip: "<b>Value</b><br>The value associated with each of the property on the left. Use the arrow on the corner to sort this column.",
          listeners: {
              render: function(c) {
                Ext.create('Ext.tip.ToolTip', {
                  target: c.getEl(),
                  html: c.tip
                });
              }
          },
          dataIndex: 'value',
          width: 250,
          sortable: true
        }
      ],
      stripeRows: true
    }) ;



  //Make the treePanel
  tree = new Ext.tree.TreePanel({
        border: true,
        cls: 'mainPanel',
        bodyCls: 'colPanel',
        title: 'RNA PROFILE GRID',
        id: 'gvTree',
        width: 600,
        height: 250,
        useArrows: true,
        autoScroll: true,
        enableDD: true,
        draggable: false,
        tbar: toolBar,
        items: [analysisGrid],
        rootVisible: false,
        renderTo: 'panel'
    });  
}


function makeGridPage(docName)
{
   var url = 'http://' + location.host + '/java-bin/exRNAGrid.jsp?format=html&anDoc='+ docName ;
   window.open(url, '_blank'); 
}

//Window to display the small grid
// Not used. 
function makeSmallWindow(tree)
{
  smallGridWindow = new Ext.Window({
    id: 'smallView',
    modal: true,
    stateful: false,
    //autoHeight: true,
    //autoWidth: true,
    layout: 'border',
    items: [{
      region: 'center',
      layout: 'fit',
      frame: false,
      border: true,
      autoHeight: true,
      autoWidth: true,
      split: false,
      html: tree
    }]
  });
  smallGridWindow.show();
  smallGridWindow.hide();
  smallGridWindow.center();
  smallGridWindow.show()
}

// display grid on a window
function makeLargeWindow(table)
{
  largeGridWindow = new Ext.Window({
    id: 'largeView',
    cls: 'largeWin',
    modal: true,
    stateful: false,
    layout: 'border',
    items: [{
      region: 'center',
      layout: 'fit',
      frame: false,
      border: true,
      autoHeight: true,
      autoWidth: true,
      //width: 1200,
      autoScroll: true,
      split: false,
      html: table
      }],
      tools: [{
        type: 'expand',
        itemId: 'expand',
        tip: "<b>Expand & View Metadata</b><br><br>Use this button to view metadata for row and column headers.",
        // tool tip somehow not working, version related??? 
        listeners: {
          render: function(c) {
            Ext.create('Ext.tip.ToolTip', {
              target: c.getEl(),
              html: c.tip
            });
          }
        },
       
        handler: function (evt, toolEl, owner, tool) {
          toggleAll(owner, true) ;
        }
      },{
      type: 'collapse',
      itemId: 'collapse',
      hidden: true,
      tip: "<b>Collapse & Hide Metadata</b><br><br>Use this button to view metadata for row and column headers.",
      listeners: {
      render: function(c) {
        Ext.create('Ext.tip.ToolTip', {
          target: c.getEl(),
          html: c.tip
          });
        }
      },
      handler: function (evt, toolEl, owner, tool) {
        toggleAll(owner, false) ;
      }
    }]
  });
  largeGridWindow.show();
  largeGridWindow.hide();
  largeGridWindow.center();
  largeGridWindow.show() ;

  // tool tip for histogram icons
  var histElements = document.getElementsByClassName('hist');
  for(var ii=0; ii<histElements.length; ii++)
  {
   targetObj = 'hist'+ii ;
   // histElements[ii].title = 'Click to view histogram' ;
  Ext.create('Ext.tip.ToolTip', {
            target: targetObj,
            html: '<b>View Histogram</b><br><br>Click this button to view histogram for the corresponding biosample.'
        });
 }
 originalHt = Ext.getCmp('largeView').getSize().height ;
}

// display grid on a panel - this is a better option for rendering large tables
// instead of using a pop-up window
function viewGridInPanel(table)
{
  Ext.onReady(function(){
    new Ext.Panel({
      id: 'largeView',
      cls: 'largeWin',
      modal: true,
      stateful: false,
      layout: 'border',
      title: 'Grid with RNA Profile of Biosamples',
      items: [{
        region: 'center',
        layout: 'fit',
        frame: false,
        border: true,
        height: 600,
        width: 900,
        autoScroll: true,
        split: false,
        html: table
      }],
      renderTo: 'panel',
      tools: [{
        type: 'expand',
        itemId: 'expand',
        tip: "<b>Expand & View Metadata</b><br><br>Use this button to view metadata for row and column headers.",
        // tool tip somehow not working, version related??? 
        listeners: {
          render: function(c) {
            Ext.create('Ext.tip.ToolTip', {
              target: c.getEl(),
              html: c.tip
            });
          }
        },
        handler: function (evt, toolEl, owner, tool) {
          toggleAll(owner, true) ;
        }
      },
      {
        type: 'collapse',
        itemId: 'collapse',
        hidden: true,
        tip: "<b>Collapse & Hide Metadata</b><br><br>Use this button to view metadata for row and column headers.",
        listeners: {
        render: function(c) {
          Ext.create('Ext.tip.ToolTip', {
            target: c.getEl(),
            html: c.tip
            });
          }
        },
        handler: function (evt, toolEl, owner, tool) {
          toggleAll(owner, false) ;
        }
      }]
    });
    // tool tip for histogram icons
    var histElements = document.getElementsByClassName('hist');
    for(var ii=0; ii<histElements.length; ii++)
    {
      targetObj = 'hist'+ii ;
      // histElements[ii].title = 'Click to view histogram' ;
      Ext.create('Ext.tip.ToolTip', {
        target: targetObj,
        html: '<b>View Histogram</b><br><br>Click this button to view histogram for the corresponding biosample.'
      });
    }
    originalHt = Ext.getCmp('largeView').getSize().height ;
  });  
}

// displays metadata for row and column headers of the table(grid) 
// display is enabled by setting the style for a specific div class
function toggleAll(owner, increase) 
{
  var divElements = document.getElementsByClassName("toggleText");
  var ii ;
  for(ii=0; ii<divElements.length; ii++)
  {
    if(divElements[ii].style.display == 'block')
    {
      divElements[ii].style.display = 'none' ;
      owner.child('#expand').show() ;
      owner.child('#collapse').hide() ;
    }
    else
    {
      divElements[ii].style.display = 'block' ;
      owner.child('#collapse').show() ;
      owner.child('#expand').hide() ;
    }
  }
  var win =  Ext.getCmp('largeView') ;
  var width = win.getSize().width ;
  //resize window
  if(increase == true)
  {
    var newheight = divElements.length*26 ;
    win.setSize(width, originalHt + newheight);
  }
  else
   {
     win.setSize(width, originalHt);
   }
} 
 


function maketipForGridIcon() 
{
   Ext.create('Ext.tip.ToolTip', {
     target: 'viewIcon',
     html: '<b>View Grid</b><br><br>Click this button to view mapped reads profile for each RNA type on a grid.'
   });

}

// get the property-value pair from the selected analysis doc
function getAnalysisData(result, request)
{
  var resObj  = JSON.parse(result.responseText) ;
  var anDoc = resObj['data'];
  var statusObj = resObj['status']
  if(result.status >= 200 && result.status < 400 && anDoc)
  {
    var retVal = [] ;
    var docLink ;
    var docName = anDoc['Analysis']['value'] ;
    docLink = '<a href="http://genboree.org/genboreeKB/genboree_kbs?project_id=exrna-metadata-standards&coll='+gridColl+'&doc='+docName+'&docVersion=" target="_blank">'+docName+'</a>' ;
    retVal.push(['&nbsp;<b>Analysis</b>', docLink]);
    retVal.push(['&nbsp;<b>Genome Version</b>', anDoc['Analysis']['properties']['Data Analysis Level']['properties']['Type']['properties']['Level 1 Reference Alignment']['properties']['Genome Version']['value']]) ;
    if('Data Analysis Level' in anDoc['Analysis']['properties'] && 'Type' in anDoc['Analysis']['properties']['Data Analysis Level']['properties'])
      {
        retVal.push(['&nbsp;<b>Type</b>', anDoc['Analysis']['properties']['Data Analysis Level']['properties']['Type']['value']]);
        if('Level 1 Reference Alignment' in anDoc['Analysis']['properties']['Data Analysis Level']['properties']['Type']['properties'] && 'Alignment Method' in anDoc['Analysis']['properties']['Data Analysis Level']['properties']['Type']['properties']['Level 1 Reference Alignment']['properties'])
          {retVal.push(['&nbsp;<b>Alignment Method</b>', anDoc['Analysis']['properties']['Data Analysis Level']['properties']['Type']['properties']['Level 1 Reference Alignment']['properties']['Alignment Method']['value']]);}
      }
    else
    {
      retVal.push(['&nbsp;<b>Type</b>', 'No Data']) ;
    }
    retVal.push(['&nbsp;<b>Grid View</b>', '<a class="showHigh"  href="#" onclick="makeGridPage(\''+ docName +'\')"></a>']) ;
    var anStor = Ext.getCmp('anGrid').store ;
    anStor.loadData(retVal) ; 
  }   
  else
  {
    displayFailureDialog(result, request) ;
  }
}

// failure dialogs for ajax
function displayFailureDialog(result, request)
{
  var resObj  = JSON.parse(result.responseText) ;
  var anDoc = resObj['data'];
  var statusObj = resObj['status']
  var message = statusObj['msg'] ;
  var statusCode = statusObj.statusCode ;
  Ext.Msg.alert("ERROR", "API Failed to get the analysis document " + result.status + ", " + result.statusText + ". Details: " + message + " " + statusCode) ;
}

// gets the subdocument
function showHisto(partitionName, index, docname)
{
 // anDoc is global
 if(docname){anDoc = docname ;}
  var prop = "Analysis.Data Analysis Level.Type.Level 1 Reference Alignment.Biosamples.["+index+"].Biosample ID.Read Counts at Various Stages" ;
  var propPath = '/REST/v1/grp/'+ gridGrp +'/kb/'+ gridKb +'/coll/' + gridColl + '/doc/' +anDoc+ '/prop/'+ escape(prop) ; 
Ext.Ajax.request(
  {
    url : '/java-bin/apiCaller.jsp' ,
    timeout : 90000,
    params:
    {
      rsrcPath: propPath,
      bioname: partitionName,
      apiMethod : 'GET'
    },
    method: 'GET',
    success: makeChart,
    failure: displayFailureDialog
  }) ;


}

// draws chart
function makeChart(result, request)
  {
  var resObj  = JSON.parse(result.responseText) ;
  var bioDoc = resObj['data'];
  var statusObj = resObj['status']
  if(result.status >= 200 && result.status < 400 && bioDoc)
  {
    var bioname = result.request.options.params.bioname; 
    //1. remove unwanted keys
    if('Pipeline Result Files' in bioDoc['properties'])
    {
      delete bioDoc['properties']['Pipeline Result Files'] ;
    }
    // 2. make data
    var data = [];
    var cat = [];
    for (prop in bioDoc['properties']){
      cat.push(prop);
      data.push(bioDoc['properties'][prop]['value']);
    }
    makeHighChart(cat, data, bioname);
  }
  else
  {
    displayFailureDialog(result, request) ;
  }
}

//
function makeChartWindow()
{
  smallGridWindow = new Ext.Window({
    id: 'chartView',
    modal: true,
    stateful: false,
    width: 600,
    bodyStyle: 'padding: 4px;',
    layout: 'border',
    items: [{
      region: 'center',
      layout: 'fit',
      frame: false,
      border: true,
      autoHeight: true,
      split: false,
      html: '<div id="chartContainer"></div>'
    }]
  });
  smallGridWindow.show();
  smallGridWindow.hide();
  smallGridWindow.center();
  smallGridWindow.show()
}

function makeHighChart(xaxis, data, parname)
{
  makeChartWindow() ;
  $(function () {
    $('#chartContainer').highcharts({
      chart: {
        spacingTop: 2,
        spacingLeft: 2,
        spacingBottom: 10,
        spacingRight: 20,
        type: "column"
      },
      title: {
        text: 'Read Counts'
      },
      xAxis: {
        categories: xaxis,
          labels : {
            enabled : false
          }
      },
      yAxis: {
        type: 'logarithmic',
        minorTickInterval: 0.1
      },
      tooltip: {
        headerFormat: '<span style="font-size:10px">{point.key}</span><table>',
        pointFormat: '<tr><td style="color:{series.color};padding:0">{series.name}: </td>' +
                '<td style="padding:0"><b>{point.y:.1f} mm</b></td></tr>',
        footerFormat: '</table>',
        shared: true,
        useHTML: true
      },
      plotOptions: {
        column: {
          pointPadding: 0.2,
          borderWidth: 0
          }
      },
      series: [{
        name: parname,
        data: data
      }]
    });
});
}
