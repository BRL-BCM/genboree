// enables cell clicks and performs the following:
// if the cell is invalid it throws an error window
// else it shows window with tag properties
function clickCell(cellElId, partitionPath, eviName, metaObj)
{
  partitionPath = unescape(partitionPath);
  var cellCls = document.getElementById(cellElId).className ;
  if(cellCls != "invalid")
  {
    var gridStoreData = [] ;
    if(metaObj && metaObj.docIds)
    {

      var docIds = metaObj.docIds ;
      var subjects = metaObj.subjects ;
      var subIndex = metaObj.subjectIndex ;
      var bioLink ;
      for(var ii=0; ii<docIds.length; ii++){
        for(var jj=0; jj<subjects[ii].length; jj++){
           data = []
           //Link is hardcoded now
           bioLink = '<a href="http://genboree.org/genboreeKB/genboree_kbs?project_id=exrna-metadata-standards&coll=Biosamples&doc='+subjects[ii][jj]+'&docVersion=" target="_blank">'+subjects[ii][jj]+'</a>'
           data.push(bioLink, '<a class="showHisto"  href="#" onclick="showHisto(\''+ subjects[ii][jj] +'\', \''+subIndex[ii][jj] +'\', \''+docIds[ii] +'\' )"></a>');
           gridStoreData.push(data);
        }

      }
    }
    makeCellWindow(partitionPath, gridStoreData) ;
  }
}

// makes the pop up grid for each of the cell
function makeCellWindow(parPath, gridStoreData)
{
  var cellStore = new Ext.data.SimpleStore(
    {
      fields:
      [
        { name : 'biosample'},
        { name : 'grid' }
      ]
    }) ;

  // panel for the cell, with metadata about biosamples in the cell
  var cellGrid = new Ext.grid.GridPanel(
    {
      id: 'cellGrid',
      tip: 'Contains metadata about the biosamples in the cell.<br>',
      listeners: {
              render: function(c) {
                Ext.create('Ext.tip.ToolTip', {
                  target: c.getEl(),
                  html: c.tip
                });
              }
      },
      viewConfig: { forceFit: true },
      //height: 480,
      //width: 730,
      useArrows: true,
      autoScroll: true,
      store: cellStore,
      columns:
      [
       {
          id: 'biosample',
          text: 'Biosample',
          tip: "<b>Biosample</b><br>Biosample Accesion ID. Click to view the Biosample metadata document in GenboreeKB.<br>",
          listeners: {
              render: function(c) {
                Ext.create('Ext.tip.ToolTip', {
                  target: c.getEl(),
                  html: c.tip
                });
              }
          },
          dataIndex: 'biosample',
          width: 180,
          sortable: true
        },
        {
          id: 'grid',
          //text: '<div class="showHisto">&nbsp;</div>',
          text: 'Histogram View',
          tip: "<b>Histogram View</b><br>Click to view a histogram of the RNA profile of this Biosample.<br>",
          listeners: {
              render: function(c) {
                Ext.create('Ext.tip.ToolTip', {
                  target: c.getEl(),
                  html: c.tip
                });
              }
          },
          dataIndex: 'grid',
          width: 120,
          sortable: false,
          resizable: false,
          align: "center",
          tdCls: 'x-change-cell gb-icon-col'
        }
      ],
      stripeRows: true
    }) ;

  // load the store
  var cellStor = Ext.getCmp('cellGrid').store ;
  cellStor.loadData(gridStoreData) ;

  title = 'Metadata about Biosamples:<br><div class="metadata">' + parPath.replace(/\./g, "&nbsp;&raquo;&nbsp;") + '</div>';
  titleLength = (title.length * 5) + 100; // Not best approach, works for now
  // create and show the window.
  Ext.create('Ext.window.Window', {
    height: 500,
    //width: 750,
    width: titleLength, 
    padding: "0px 0px 0px 0px",
    title: title,
    id: 'cellWindow',
    layout: 'fit',
    items:[cellGrid]
  }).show();


}
// not the right way, not working
function getWidth(path)
{
  var winWid ;
  var parlen = path.length ;
  if(parlen < 25) {winWid = 500 ;}
  else if(parlen > 25) { winWid = (parlen * 25) ; }
  Ext.getCmp('cellGrid').setWidth(winWid) ;
  return winWid ;
}
