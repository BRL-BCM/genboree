mouseDrag = false;
oldObjId = null;
startX = 1;
startY = 1;
oldX = startX;
oldY = startY;
curX = startX;
curY = startY;
selectClassName = "cellSelected";
showCellColor = false;
coloredSelect = "#8C92AC";
regularSelect = "#DFE8F6";
colorMap ={
  '#FFDF80':'#FFBF00',
  '#A8C1ED':'#6495ED',
  '#E08E89':'#E03C31',
  '#CBF0BB':'#7BB661'
}
var openId = '';
var geneViewerFile = null;
var gridViewerFile = null;
var downloadDir = null;
var saveWindow;
var panel;
var grid;
var userLogin;
var entityType = null;
var entityTypeForms = null;
var selectedCells = []
metadataWindowId = 'metadataWindow';

var idList = [];
var nValues = [];





var level2 = []
var typeSum = 0
var color = new Boolean (false);
// This is called before each y value is displayed
function yRenderer ( value, meta, record, rowIndex, colIndex, store){
	var index = parseInt(record.get('id'))+1;
	return '<div id="yDiv-'+index+'" style="width:100%;padding-left:5px;cursor:pointer;" onClick="showyDialog('+index+',\''+value+'\');" >'+value+'</div>';
}

// For closing tooltips if any
function tipCloseHandler(evt, toolbar, panel, cfg) {
	var mwin = Ext.getCmp(metadataWindowId);
	if(mwin) {mwin.close();}
	panel.hide();//This is important to close the tooltip if overriding 'close' like in this case
}


function gridxDialog(colIndex,exptName)
{
	tipHTML = "<div><ul><li><span class=\"legend10 toglClass\"onclick=\"toggleColumnSelection(" + colIndex + ")\">Toggle assay selections</span></li>";
	tipHTML += "<li><span class=\"legend10 dbdClass\" onclick=\"dbDetailsDialog(" + (parseInt(colIndex)-1) + ",'column');\">See Database details</span></li>";
	if(downloadDir)
	{
		exptDirName = exptName.replace(/\s/g,"_");
		tipHTML+= "<li><span class=\"legend10 dwnldClass\"><a href=\"http://www.genboree.org/EdaccData/"+downloadDir+"/experiment-sample/"+exptDirName+"\">Download data</a></span></li>";
	}
	tipHTML+= "</ul></div>";
	return tipHTML;
}

function gridyDialog(rowIndex,sampleName)
{
	tipHTML = "<div><ul><li><span class=\"legend10 toglClass\" onclick=\"toggleRowSelection(" + rowIndex + ")\">Toggle sample selections</span></li>";
	tipHTML += "<li><span class=\"legend10 dbdClass\" onclick=\"dbDetailsDialog(" + (parseInt(rowIndex)-1) + ",'row');\">See Database details</span></li>";
	if(downloadDir)
	{
		sampleDirName = sampleName.replace(/\s/g,"_");
		tipHTML+= "<li><span class=\"legend10 dwnldClass\"><a href=\"http://www.genboree.org/EdaccData/"+downloadDir+"/sample-experiment/"+sampleDirName+"\">Download data</a></span></li>";
	}
	tipHTML+= "</ul></div>";
	return tipHTML;
}
//
//function getGrid( data, element, dataType) {
//    var store2 = new Ext.data.ArrayStore({
//      fields: [
//        { name: 'type' },
//        { name: 'count', type: 'int' }
//      ],
//      data: data
//    });
//    var grid2 = new Ext.grid.GridPanel({
//      store: store2,
//      columns: [
//        { id:'dataType', width: 50,   dataIndex: 'type',resizable:true,css: "padding-left:4px;"  },
//        {  width:30, dataIndex: 'count',resizable:true,css: "padding-left:4px;"  }
//      ],
//      columnLines:true,
//      stripeRows: true,
//      autoHeight: true,
//      enableHdMenu: false,
//      border: false      
//      ,viewConfig:{forceFit:true,scrollOffset:0}
//      
//    });
//    element && grid2.render( element);
//    return grid2;
//  }
//  

function getTrackGrid( data, element, dataType) {
	var store4 = new Ext.data.ArrayStore({
fields: [
{ name: 'type' }
//,{ name: 'count', type: 'int' }
],
data: data
});
var grid4 = new Ext.grid.GridPanel({
store: store4,
columns: [
{ id:'dataType', width: 50,   dataIndex: 'type',resizable:true,css: "padding-left:4px;"  }
],
columnLines:true,
stripeRows: true,
autoHeight: true,
enableHdMenu: false,
border: false      
,viewConfig:{forceFit:true,scrollOffset:0}

});
element && grid4.render( element);
return grid4;
}


function getGrid( data, element, dataType,inRow1,inRow2) {
	var store3 = new Ext.data.ArrayStore({
fields: [
{ name: 'type' },
{ name: 'count', type: 'int' }
],
data: data
});

var expander3 = new Ext.ux.grid.RowExpander({
tpl              : '<div class="ux-row-expander-box"></div>',
actAsTree        : true,
treeLeafProperty : 'is_leaf',
listeners        : {
expand : function( expander, record, body, rowIndex) {
getTrackGrid( [mlevel4[inRow1][inRow2][rowIndex]], Ext.get( this.grid.getView().getRow( rowIndex)).child( '.ux-row-expander-box'),"blah");
}
}
});
var grid3 = new Ext.grid.GridPanel({
store: store3,
columns: [
expander3,
{ id:'dataType', width: 50,   dataIndex: 'type',resizable:true,css: "padding-left:4px;"  },
{  width:30, dataIndex: 'count',resizable:true,css: "padding-left:4px;"  }
],
columnLines:true,
stripeRows: true,
autoHeight: true,
enableHdMenu: false,
border: false
,plugins:expander3
,viewConfig:{forceFit:true,scrollOffset:0}

});
element && grid3.render( element);
return grid3;
}



function getMultiGrid( data, element, dataType,inRow) {
	var store2 = new Ext.data.ArrayStore({
fields: [
{ name: 'type' },
{ name: 'count', type: 'int' }
],
data: data
});
xtitle=decodeURIComponent(xlabel);
var expander2 = new Ext.ux.grid.RowExpander({
tpl              : '<div class="ux-row-expander-box"></div>',
actAsTree        : true,
treeLeafProperty : 'is_leaf',
listeners        : {
expand : function( expander, record, body, rowIndex) {
getGrid( mlevel3[inRow][rowIndex], Ext.get( this.grid.getView().getRow( rowIndex)).child( '.ux-row-expander-box'),xtitle,inRow,rowIndex);
}
}
});
var grid2 = new Ext.grid.GridPanel({
store: store2,
columns: [
expander2,
{ id:'dataType', width: 90, dataIndex: 'type',resizable:true,css: "padding-left:4px;"  },
{ width:50, dataIndex: 'count',resizable:true,css: "padding-left:4px;"  }
],
columnLines:true,
stripeRows: true,
autoHeight: true,
enableHdMenu: false,
border: false,
plugins:expander2
,viewConfig:{forceFit:true,scrollOffset:0,headersDisabled:true}

});
element && grid2.render( element);
return grid2;
}


function dbMultiDetailsDialog()
{
  collectCells();
  if(anyCellsChecked())
  {
  getDBMultiSum(valIndices);
  var store1 = new Ext.data.ArrayStore({
      fields: [
        { name: 'database' },
        { name: 'count', type: 'int' }
      ],
      data: mlevel1
    });
  
  curRow = ""
  ytitle=decodeURIComponent(ylabel);
  var expander1 = new Ext.ux.grid.RowExpander({
      tpl              : '<div class="ux-row-expander-box"></div>',
      actAsTree        : true,
      treeLeafProperty : 'is_leaf',
      listeners        : {
        expand : function( expander, record, body, rowIndex) {
          getMultiGrid( mlevel2[rowIndex], Ext.get( this.grid.getView().getRow( rowIndex)).child( '.ux-row-expander-box'),ytitle,rowIndex);
        }
      }
    });
  
  var grid1 = new Ext.grid.GridPanel({
      store: store1,
      columns: [
        expander1,
        { header: 'Database', width: 90, sortable: false, dataIndex: 'database',resizable:true,css: "padding-left:2px;"  },
        { header: 'Count', width: 38, sortable: false, dataIndex: 'count',resizable:true,css: "padding-left:2px;"  }
      ],
      columnLines:true,
      autoexpand:'database',
      stripeRows: true,
      autoHeight:true,
      stateful: true,
      enableHdMenu: false,
      stateId: 'grid',
      plugins: expander1,
      border: false
       ,viewConfig:{forceFit:true,scrollOffset:0}
    });

  delete dbDetailsWindow;
  dbDetailsWindow = new Ext.Window({
    id: 'dbDetailsWin',
    bodyCssClass:'extColor',
    modal: true,
    autoScroll: false,
    title: 'Database Details',
    stateful: false,
    height: 400,
    width: 500,
    layout: 'border',
    constrainHeader: true,
    items: [{
      region: 'center',
      html: '<div id="multi-grid-box" style="margin:0 auto;overflow:auto;width:100%;height:100%;"></div>',
      layout:'fit'
    }, {
      region: 'north',
      layout: 'fit',
      frame: true,
      border: false,
      split: false,
      collapsible: false,
      html: "<div class=\"legendBold11\" style=\"padding:5px; padding-left:10px;\">Details</div>"
    }, {
      region: 'south',
      layout: 'fit',
      frame: true,
      border: false,
      split: false,
      collapsible: false,
      html: "<div class=\"legendBold11\" style=\"padding:5px;padding-left:10px;width:100%;text-align:center;\">"+
      "<input type=\"button\" id=\"ok\" value=\"OK\" style=\"width:150px;cursor:pointer;\" onClick=\"dbDetailsWindow.close();\">"+
      "</div>"
    }]
  });
  dbDetailsWindow.show();
  dbDetailsWindow.center();
  dbDetailsWindow.show();
   var panel = new Ext.Panel({
    autoHeight : true,
    items      : [grid1],
    applyTo    : 'multi-grid-box'
  });
  }
  else showNoEntitiesMessage();
}
function dbDetailsDialog(index,type)
{
  if(type=="row") getDBRowSum(index); else getDBColSum(index);
  var store1 = new Ext.data.ArrayStore({
      fields: [
        { name: 'database' },
        { name: 'count', type: 'int' }
      ],
      data: level1
    });
  title = "";
  if(type=="row") title = decodeURIComponent(xlabel); else title=decodeURIComponent(ylabel);


  var expander = new Ext.ux.grid.RowExpander({
      tpl              : '<div class="ux-row-expander-box"></div>',
      actAsTree        : true,
      treeLeafProperty : 'is_leaf',
      listeners        : {
        expand : function( expander, record, body, rowIndex) {
          getGrid( level2[rowIndex], Ext.get( this.grid.getView().getRow( rowIndex)).child( '.ux-row-expander-box'),title);
        }
      }
    });
  
  var grid1 = new Ext.grid.GridPanel({
      store: store1,
      columns: [
        expander,
        { header: 'Database', width: 90, sortable: false, dataIndex: 'database',resizable:true,css: "padding-left:2px;" },
        { header: 'Count', width: 50, sortable: false, dataIndex: 'count',resizable:true,css: "padding-left:2px;"  }
      ],
      autoexpand:'database',
      stripeRows: true,
      autoHeight:true,
      stateful: true,
      enableHdMenu: false,
      stateId: 'grid',
      plugins: expander,
       border: false
       ,viewConfig:{forceFit:true,scrollOffset:0}
    });
  
  typeName = "";
  if(type=="row") typeName = yvals[index]; else typeName = xvals[index];
  
  delete dbDetailsWindow;
  dbDetailsWindow = new Ext.Window({
    id: 'dbDetailsWin',
    bodyCssClass:'extColor',
    modal: true,
    autoScroll: false,
    title: 'Database Details',
    stateful: false,
    height: 400,
    width: 300,
    layout: 'border',
    constrainHeader: true,
    items: [{
      region: 'center',
      html: '<div id="grid-box" style="margin:0 auto;overflow:auto;width:100%;height:100%;"></div>'
    }, {
      region: 'north',
      layout: 'fit',
      frame: true,
      border: false,
      split: false,
      collapsible: false,
      html: "<div class=\"legendBold11\" style=\"padding:5px; padding-left:10px;\">"+typeName+"</div>"
    }, {
      region: 'south',
      layout: 'fit',
      frame: true,
      border: false,
      split: false,
      collapsible: false,
      html: "<div class=\"legendBold11\" style=\"padding:5px;padding-left:10px;width:100%;text-align:center;\">"+
      "<input type=\"button\" id=\"ok\" value=\"OK\" style=\"width:150px;cursor:pointer;\" onClick=\"dbDetailsWindow.close();\">"+
      "</div>"
    }]
  });
  dbDetailsWindow.show();
  dbDetailsWindow.center();
  dbDetailsWindow.show();
   var panel = new Ext.Panel({
    autoHeight : true,
    items      : [grid1],
    applyTo    : 'grid-box'
  });
}


function getDBRowSum(index)
{
  level1 = [];
  level2 = [];
  for(ii=0;ii<=dbShow.length-1;ii++)
  {
    if(dbShow[ii]=="true")
    {
      level2temp = []
      dbSum = 0
      text = ""
      curr = dbTree[ii][index];
      if(curr)
        for(kk=0;kk<=curr.length-1;kk++)
          if(curr[kk]>0)
          {
          level2temp.push([xvals[kk],curr[kk]])
          dbSum+=curr[kk]
          }
      if(dbSum!=0){
      level1.push([dbNames[ii],dbSum]);
      level2.push(level2temp);
      }
    }
  }
}




function getDBMultiSum(valIndices)
{
  mlevel1 = [];
  mlevel2 = [];
  mlevel3 = [];
  mlevel4 = [];
  for(ii=0;ii<=dbShow.length-1;ii++)
  {
    if(dbShow[ii]=="true")
    {
      dbSum = 0
      text = ""
      level4 = []
      level3 = []
      level2 = []
      level2Sum = []
      level2Temp = []
      level3Temp = []
      for(jj=0;jj<=valIndices.length-1;jj++)
      {
        
        yy=valIndices[jj][0];
        xx=valIndices[jj][1];
        if(!level2Sum[yy])
        {
          level2Sum[yy] = 0
          level2Temp[yy] = []
        }
        
        if(!level3Temp[yy])
        {
          level3Temp[yy] = []
        }
      curr = dbTree[ii][yy];
      if(curr)
      {
          if(curr[xx].length>0)
        {
          level2Sum[yy]+=curr[xx].length
          level2Temp[yy].push([xvals[xx],curr[xx].length])
          dbSum += curr[xx].length
          level3Temp[yy].push(curr[xx])
        }
      }
    }
      for(kk=0;kk<=level2Sum.length-1;kk++)
      {
        if(level2Sum[kk] > 0)
        {
          level2.push([yvals[kk],level2Sum[kk]])
          level3.push(level2Temp[kk])
          level4.push(level3Temp[kk])
        }
      }
      if(dbSum!=0){
      mlevel1.push([dbNames[ii],dbSum]);
      mlevel2.push(level2)
      mlevel3.push(level3)
      mlevel4.push(level4)
      }
    
    }
  }
}

function getDBColSum(index)
{
  level1=[];
  level2=[];
  for(ii=0;ii<=dbShow.length-1;ii++)
  {
    if(dbShow[ii]=="true")
    {
      level2temp=[];
      dbSum = 0
      text = ""
      curr = dbTree[ii];
      if(curr)
      for(kk=0;kk<=curr.length-1;kk++)
          if(curr[kk] && curr[kk][index]>0)
          {
          level2temp.push([yvals[kk],curr[kk][index]]);
          dbSum+=curr[kk][index];
          }
      if(dbSum!=0){
      level1.push([dbNames[ii],dbSum]);
      level2.push(level2temp);
      }
    }
  }
}


function toggleAdvancedSettings(spanId, tableId) {
  var spanElem = Ext.get(spanId);
  var tableElem = Ext.get(tableId);
  var state = spanElem.getAttribute("collapseState");
  if (state == "collapsed") {
    spanElem.setStyle("background-image", "url('/images/bullet_toggle_minus.png')");
    spanElem.setStyle("background-position", "left center");
    tableElem.setStyle("display", "block");
    spanElem.set({
      collapseState: "expanded"
    });
  } else {
    spanElem.setStyle("background-image", "url('/images/bullet_toggle_plus.png')");
    tableElem.setStyle("display", "none");
    spanElem.set({
      collapseState: "collapsed"
    });
  }
  return true;
}
function dbShowColumn(index)
{  
  sum = 0;
  fullText = ""
  dbText= ""
  for(ii=0;ii<=dbShow.length-1;ii++)
  {
    if(dbShow[ii]=="true")
    {
      dbSum = 0
      text = ""
      curr = dbTree[ii];
      if(curr)
      {
        for(kk=0;kk<=curr.length-1;kk++)
        {
          if(curr[kk] && curr[kk][index]>0)
          {
            
          text += "\n"+yvals[kk]+"\t"+curr[kk][index];
          dbSum+=curr[kk][index];
          }
        }
      }
      dbText += "\n"+dbNames[ii]+"\t"+dbSum+text;
      sum += dbSum
    }
  }
  fullText=xvals[index]+"\t"+sum+dbText;
  alert(fullText);
}

//This determines what happens when an x value in the header row is clicked
function showxDialog(colIndex,xval)
{
  if(typeof(gridxDialog)!='undefined'){ //Is this edacc?
  tipId = 'xTip-'+colIndex;
  var tt = Ext.getCmp(tipId);
  if(!tt)
  {
    tipHTML = gridxDialog(colIndex,xval)
    tt = new Ext.ToolTip({id:tipId
        ,title: xval
        ,target:'xdiv-'+colIndex
        ,html:tipHTML
        ,autoHide:false
        ,closable:true
        ,anchor:'bottom'
        ,showDelay: 3600000
        //Effectively disable tooltip on mouseover
      });
  }
    openTip = Ext.getCmp(openId);
    if(openTip) openTip.hide();
  openId = tipId;
  tt.show();
}  //If not do nothing
}

//Same idea as x dialog for the y values (first column)
function showyDialog(rowIndex,yval)
{
  if(typeof(gridyDialog)!='undefined'){
  tipId = 'yTip-'+rowIndex;
  var tt = Ext.getCmp(tipId);
  if(!tt)
  {
    tipHTML = gridyDialog(rowIndex,yval)
    tt = new Ext.ToolTip({id:tipId
        ,title:yval
        ,target:'yDiv-'+rowIndex
        ,html:tipHTML
        ,autoHide:false
        ,closable:true
        ,anchor:'right'
        ,showDelay: 3600000
        //Effectively disable tooltip on mouseover
        ,tools: [{
          id: 'close',
          qtip: 'Close',
          handler: tipCloseHandler
        }]
      });
  }
    openTip = Ext.getCmp(openId);
    if(openTip) openTip.hide();
  openId = tipId;
  tt.show();
  }
}

//This renderer is called before each cell value is displayed. It adds the correct js functions for a cell to behave when part of drag selection
function dataRenderer ( value, meta, record, rowIndex, colIndex, store){
divString = '<div id="td-'+colIndex+'-'+(parseInt(record.get('id'))+1)+'" style="width:24px !important;height:100%;text-align:center;border-left:1px solid #D0D0D0 !important;" onmouseup="stopDrag(this);" onmousedown="startDrag(this);"  onmouseover="mouseHover(this);" '
if(value.toString().match(/\d/))
{
  divString += ' class="filled"';
}
else
{
  divString += ' class="empty"';
}
  divString += ' ><div style="margin:0 auto;width:100%;height:100%;">'+value+'</div></div>';
  return divString;
}

function addOrReplaceBackgroundColor(styleString,bgColor)
{
  if(styleString.match(/background-color:[^;]+;/))
    styleString = styleString.replace(/background-color:[^;]+;/,'background-color:'+ bgColor+';');
     else
    styleString += 'background-color:'+ bgColor+';';
    return styleString
}

function removeBackgroundColor(styleString)
{
  styleString = styleString.replace(/background-color:[^;]+;/,'')
  return styleString;
}



function olddeselect(cell)
{
  cell.className = cell.className.replace(' '+selectClassName, "");
  cellId = cell.childNodes[0].childNodes[0].id
  cellIndex = selectedCells.indexOf(cellId)
  if(cellIndex != -1) selectedCells.splice(cellIndex,1)
}

function deselect(cell)
{
  cell.className = cell.className.replace(' '+selectClassName, "");
  cellChild = cell.childNodes[0].childNodes[0]
  cellColor = cellChild.getAttribute("cellColor")
  cellStyle = cellChild.getAttribute("style")
    if(showCellColor && cellColor)
      cellStyle = addOrReplaceBackgroundColor(cellStyle,cellColor);
      else
    cellStyle = removeBackgroundColor(cellStyle)
      cellChild.setAttribute("style",cellStyle)
  cellId = cellChild.id
  cellIndex = selectedCells.indexOf(cellId)
  if(cellIndex != -1) selectedCells.splice(cellIndex,1)
}

function toggleColoring(checked)
{
  if(checked) 
  {
   colorCells();
   color = true;
  } 
   else {
    uncolorCells();
    color = false;
    }
}

function select(cell)
{
  if (!cell.className.match(selectClassName))
  {
    cell.className += ' '+selectClassName;
    cellChild = cell.childNodes[0].childNodes[0]
    cellColor = cellChild.getAttribute("cellColor")
    cellStyle = cellChild.getAttribute("style")
    if(showCellColor && cellColor)
    {
      cellStyle = addOrReplaceBackgroundColor(cellStyle,coloredSelect);
    }
    else
    {
      cellStyle = addOrReplaceBackgroundColor(cellStyle,regularSelect);
    }
    cellChild.setAttribute("style",cellStyle)
  }
  cellId = cellChild.id;
  if(selectedCells.indexOf(cellId) == -1) selectedCells.push(cellId);  
}



//turn off cellColoring
function uncolorCells()
{
  for(var index in cellColors)
  {
    var coords = index.split(/,/);
    var i = parseInt(coords[0]) + 1;
    var j = parseInt(coords[1]) + 1;
    var cell = document.getElementById("td-" + i + "-" + j);
    var cellStyle = cell.getAttribute("style");
    if(cell.parentNode.parentNode.className.match(selectClassName))
      cellStyle = addOrReplaceBackgroundColor(cellStyle,regularSelect);
    else
    cellStyle = removeBackgroundColor(cellStyle);
    cell.setAttribute("style",cellStyle);
  }
  showCellColor = false;
}


function colorCells()
{
  for(var index in cellColors)
  {
    //alert(index);
    var coords = index.split(/,/) ;
    var i = parseInt(coords[0]) + 1 ;
    var j = parseInt(coords[1]) + 1 ;
    var cellId = "td-" + i + "-" + j ;
    var cell = document.getElementById(cellId);
    if( !((typeof cell === 'undefined') || (cell == null)) )
    {
      var cellStyle = cell.getAttribute("style");
      if(cell.parentNode.parentNode.className.match(selectClassName))
      {
        cellStyle = addOrReplaceBackgroundColor(cellStyle,coloredSelect) ;
      }
      else
      {
        cellStyle = addOrReplaceBackgroundColor(cellStyle,cellColors[index]) ;
      }
      cell.setAttribute("style",cellStyle) ;
      cell.setAttribute("cellColor",cellColors[index]) ;
    }
  }
  showCellColor = true;
}

//turn on cell coloring
function olddataRenderer ( value, meta, record, rowIndex, colIndex, store)
{
  var divString = '<div id="td-'+colIndex+'-'+(parseInt(record.get('id'))+1)+'" onmouseup="stopDrag(this);" onmousedown="startDrag(this);"  onmouseover="mouseHover(this);"'
  //colors = ['#FFBF00','#6495ED','#E03C31','#7BB661']

  var colors = ['#FFDF80','#A8C1ED','#E08E89','#CBF0BB'];
  var colorInd = Math.floor(Math.random()*(colors.length+3));
  var styleString = 'width:24px !important;height:100%;text-align:center;border-left:1px solid #D0D0D0 !important;';
if(value.toString().match(/\d/))
{
  divString += ' class="filled"'
  var cellColor = cellColors[colIndex-1+','+parseInt(record.get('id'))];
  var backStr = '';
  if(cellColor)
  {
    divString += 'cellColor="'+cellColor+'"';
    backStr = ' background-color: '+ cellColor +';'
  }
  styleString += backStr;
}
else
{
  divString += ' class="empty"';
}
  divString += ' style="'+styleString+'"><div style="margin:0 auto;width:100%;height:100%;">'+value+'</div></div>';
  return divString;
}

function selectColumn(obj)
{
  alert(obj);
}


function filterColumns(value)
{
  if(value.match(/\S/))
  {
  hideAllColumns();
  chosenColumns = new Array;
  exptStore.filter('name',value,true,false);
  exptStore.each(function(record)
{
    columnModel.setHidden(parseInt(record.get('id'))+1,false);
}, this);

  }
  else
  {
    showAllColumns();
  }
}

//Simple filter for yvalues
function filterRows(value,fieldName)
{
  if(value.match(/\S/)){
    ystore.filter('name',value,true,false,false);
    colorCells();
  }
  else
  {
    ystore.clearFilter();
    if(color){colorCells();}
  }
  restoreSelectedCells();
 
}

function resetValue(field,value)
{
  field.value = value;
}

function handleOnSelect(combo, record, index){
 var onTerm = combo.getValue();
 filterRowsByOntology(onTerm);
}


// functions to enable filtering the rows
// by ontology terms via the combo box
function filterRowsByOntology(value)
{
  if(value.match(/\S/))
  {
    ystore.filter('search',value,true,false,false);
    colorCells();
  }
  else
  {
    ystore.clearFilter();
    colorCells();
  }
  restoreSelectedCells();
}

function resetColumns()
{
  exptStore.clearFilter();
  for(var ii=1;ii<=columnModel.columns.length-1;ii++) {columnModel.setHidden(ii,false);}
}

function hideAllColumns()
{
  for(var ii=1;ii<=columnModel.columns.length-1;ii++) {columnModel.setHidden(ii,true);}
}

function showAllColumns()
{
  for(var ii=1;ii<=columnModel.columns.length-1;ii++) {columnModel.setHidden(ii,false);}
}

// These take care of the visual aspects of drag selection

function mouseHover(obj) {
  if (mouseDrag) {
    arr = obj.id.split(/\-/);
    curX = arr[1];
    curY = arr[2];
    for (i = Math.min(startX, oldX); i <= Math.max(startX, oldX); i++) {
      for (j = Math.min(startY, oldY); j <= Math.max(startY, oldY); j++) {
        divCell = document.getElementById("td-" + i + "-" + j).parentNode.parentNode;
        swapState(divCell);
      }
    }

    for (i = Math.min(startX, curX); i <= Math.max(startX, curX); i++) {
      for (j = Math.min(startY, curY); j <= Math.max(startY, curY); j++) {
        divCell = document.getElementById("td-" + i + "-" + j).parentNode.parentNode;
        swapState(divCell);
      }
    }
    oldX = curX;
    oldY = curY;
  }
}

function startDrag(obj) {
  if(mouseDrag) stopDrag(obj);
  mouseDrag = true;
  arr = obj.id.split(/\-/);
  startX = arr[1];
  startY = arr[2];
  oldX = startX;
  oldY = startY;
  divCell = document.getElementById("td-" + startX + "-" + startY).parentNode.parentNode;
  swapState(divCell);
//  enableButtons();
}

// if you let go of mouse outside main grid area
function stopDragOutside()
{
  if(mouseDrag)
  {
  mouseDrag = false;
  for (i = Math.min(startX, curX); i <= Math.max(startX, curX); i++) {
    for (j = Math.min(startY, curY); j <= Math.max(startY, curY); j++) {
      cell = document.getElementById("td-" + i + "-" + j);
      if (cell.className.match(/empty/)) {
        deselect(cell.parentNode.parentNode);
      }
    }
  }

  }
}

function stopDrag(obj) {
  arr = obj.id.split(/\-/);
    curX = arr[1];
    curY = arr[2];
  if(mouseDrag)
  {
  mouseDrag = false;
  for (i = Math.min(startX, curX); i <= Math.max(startX, curX); i++) {
    for (j = Math.min(startY, curY); j <= Math.max(startY, curY); j++) {
      cell = document.getElementById("td-" + i + "-" + j)
      if (cell.className.match(/empty/)) {
        deselect(cell.parentNode.parentNode);
      }
    }
  }
  }
}


function getDBsForGroup()
{
  group = document.getElementById("grpSelector").value;
  if(group != "0")
  {
    Ext.Ajax.request(
  {
    url : '/java-bin/apiCaller.jsp' ,
    timeout : 90000,
    params:
    {
      rsrcPath: '/REST/v1/grp/'+fullEscape(group)+'/dbs',
      apiMethod : 'GET'
    },
    method: 'GET',
    success: dbSuccessDialog,
    failure: displayFailureDialog
  }) ;
  }
  else
  checkState();
}

function getGroupsForUser(user)
{
  Ext.Ajax.request(
  {
    url : '/java-bin/apiCaller.jsp' ,
    timeout : 90000,
    params:
    {
      rsrcPath: '/REST/v1/usr/'+user+'/grps',
      apiMethod : 'GET'
    },
    method: 'GET',
    success: groupSuccessDialog,
    failure: displayFailureDialog
  }) ;
}


function dbSuccessDialog(result, request)
{
  removeOptions("dbSelector");
  var jsonData = Ext.util.JSON.decode(result.responseText) ;
  if(jsonData.data.length == 0)
  {
     Ext.MessageBox.show({
      title: 'No Databases Found',
      msg: "No databases exist for this group. Please choose a different group.",
      buttons: Ext.MessageBox.OK,
       animEl: 'elId',
      icon: Ext.MessageBox.ERROR
    });
    checkState();
  }
  else
  {
  addOptions(jsonData.data,"dbSelector");
  checkState();
  }
}

function saveFailureDialog(result,request)
{
  var message = "";
    var jsonData = Ext.util.JSON.decode(result.responseText) ;
    if(result.status == 403)
    {
      message += "You do not have sufficient permissions to write to this database. Please choose a different database.<br>"
    }
    else
    {
      message += "An unexpected error has occurred.<br>"
      resultText = (result.responseText) ? result.responseText : "No response from server.";
      message += resultText;
    }
    Ext.MessageBox.show({
      title: 'Error saving selections',
      msg: message,
      buttons: Ext.MessageBox.OK,
      animEl: 'elId',
      icon: Ext.MessageBox.ERROR
    });
    checkState();
}

function groupSuccessDialog(result, request)
{
  var jsonData = Ext.util.JSON.decode(result.responseText) ;
  if(jsonData.data.length == 0)
  {
    Ext.MessageBox.show({
      title: 'No Groups Found',
      msg: "No groups exist for this user",
      buttons: Ext.MessageBox.OK,
      cls: "wbDialogAlert",
      ctCls: "wbDialogAlert"
    });
    //document.getElementById("dbSelector").disabled = "disabled";
    //checkState();
  }
  else
  {
  addOptions(jsonData.data,"grpSelector");
  checkState();
  }
}

function removeOptions(id)
{
  var opEl = Ext.get(id).dom;
    for(var i = opEl.options.length -1 ;i>=1;i--)
    {
      opEl.remove(i);
    }
}

function resetOptions(id, index)
{
  var opEl = Ext.get(id).dom;
  opEl.selectedIndex = 0;
}

function addOptions(dataList, id)
{
  var opEl = Ext.get(id).dom;
    for(var i = opEl.options.length -1 ;i>=1;i--)
    {
      opEl.remove(i);
    }
    for(var i=0;i<=dataList.length-1;i++)
    {

      opEl.options.add(new Option(dataList[i].text,dataList[i].text));
    }
}

// Proceed to UCSC only if user hits OK
function grpDialogClose(btnId, text, opt) {
  saveWindow.close();
}


function addParentHeight(window,maxHeight,addHeight,parentDiv,childDiv)
{
  parHeight = window.container.child(parentDiv).getComputedHeight();
  childHeight = window.container.child(childDiv).getComputedHeight();
  var heightDiff = parHeight - childHeight
  if(heightDiff > maxHeight ) {window.setHeight(window.height-heightDiff + addHeight)};
}

function dbSelectDialog()
{
  var dbString = ""
  for(ii=0;ii<=dbNames.length-1;ii++)
  {
    dbString += "<li><table style=\"border-spacing:5px;\"><tr><td><input type=\"checkbox\" style=\"vertical-align:bottom;\" id=\"db-"+ii+"\"";
    if(dbShow[ii] == "true" && hosts[ii] == "true") {
      dbString += "checked=\"true\""
    }
    else if(hosts[ii] == "false") {
      dbString += "disabled=\"disabled\""
    }
    dbString += "></td><td style=\"border:1px solid black;height:10px;width:10px;background-color:"+ dbColors[ii%dbColors.length]+";\"></td><td style=\"cursor:default;font:11px verdana;"
    if(hosts[ii] == "false") {
      dbString += " text-decoration:line-through; "
    }  
    dbString += "\" ext:hide=\"user\" ext:qtitle=\""+dbNames[ii]+"\"ext:qtip=\""+unescape(dbDescs[ii])+"\">"+dbNames[ii]+"</td></tr></table></li>";
    
  }
  delete dbSelectWindow;
  dbSelectWindow = new Ext.Window({
    id: 'dbSelectWin',
    bodyCssClass:'extColor',
    modal: true,
    autoScroll: false,
    title: 'Select databases to view in grid',
    stateful: false,
    height: 400,
    width: 250,
    layout: 'border',
    constrainHeader: true,
    items: [{
      region: 'center',
      layout: 'fit',
      frame: false,
      border: true,
      html:"<div id=\"outerContainer\" class=\"extColor\" style=\"overflow:auto;height:100%;\">"+
        "<div id=\"elementContainer\" class=\"extColor\" >"+
        "<ul>"+dbString+"</ul>"+
        "</div></div>"
    }, {
      region: 'north',
      layout: 'fit',
      frame: true,
      border: false,
      split: false,
      collapsible: false,
      html: "<div class=\"legendBold12\" style=\"padding:5px; padding-left:10px;\">Select databases to view in grid:</div>"
    }, {
      region: 'south',
      layout: 'fit',
      frame: true,
      border: false,
      split: false,
      collapsible: false,
      html: "<div class=\"legendBold12\" style=\"padding:5px;padding-left:10px;display:table;width:90%;margin:0 auto;\">"+
      "<input type=\"button\" name=\"dbSelectButton\" id=\"dbSelectButton\" style=\"width:45%;float:left;cursor:pointer;\" value=\"Update grid\" onClick=\"updateDbList()\">"+
      "<input type=\"button\" id=\"cancel\" value=\"Cancel\" style=\"width:40%;float:right;cursor:pointer;\" onClick=\"dbSelectWindow.close();\">"+
      "</div>"
    }]
  });
  dbSelectWindow.show();
  dbSelectWindow.center();
  resizeHeight(dbSelectWindow, 10, '#outerContainer', '#elementContainer');
  dbSelectWindow.show();
  colorCells()
}


function showSaveSelectionDialog()
{
//Global variables
idList = ["grpSelector","dbSelector","selName","selSaveButton"];
nValues = ["0","0", ""];



  if(!entityType)
  {
    entityType = 'track';
    entityTypeForms = ['track','tracks','Track','Tracks'];
  }
   delete saveWindow;
  saveWindow = new Ext.Window({
    id: 'saveWin',
    cls:'masked',
    bodyCssClass:'extColor',
    modal: true,
    autoScroll: false,
    title: 'Save '+entityTypeForms[2]+' Selections',
    stateful: false,
    height: 400,
    width: 300,
    layout: 'border',
    constrainHeader: true,
    items: [{
      region: 'center',
      layout: 'fit',
      frame: false,
      border: true,
      html:"<div class =\"extColor\" style=\"height:100%;width:100%;\"><div class =\"legendBold11\" style=\"display:table;padding:5px;padding-left:10px;height:100%;width:100%;\">"+
            "<div style=\"display:table-row;height:8px;\"><span style=\"width:80%;\">Select a Group:</span></div>"+
            "<div style=\"display:table-row;height:8px;\"  class=\"legend11\"><span style=\"width:80%;\">This is the group where your selections will be saved</span></div>"+
            "<div style=\"display:table-row;height:15px;\" id=\"groupDiv\" >"+
            "<select id=\"grpSelector\" name=\"grpSelector\" ext:qtip=\"Group to save selections in\" style=\"width:80%;\" class=\"legend10\" onChange=\"getDBsForGroup();\">"+
            "<option name=\"default\" value=\"0\"  selected=\"true\"> -- Please select a group -- </option>"+
            //"<option name=\"brlMirror\" value=\"grp1\">grp1</option>"+
            "</select></div>"+
            "<div style=\"display:table-row;height:8px;\"><span style=\"width:80%;\">Select a Database:</span></div>"+
            "<div style=\"display:table-row;height:8px;\"  class=\"legend11\"><span style=\"width:80%;\">Choose a database within your group to save to</span></div>"+
            "<div style=\"display:table-row;height:15px;\" id=\"dbDiv\" >"+
            "<select id=\"dbSelector\" name=\"dbSelector\" ext:qtip=\"Database to save selections in\" style=\"width:80%;\" class=\"legend10\" disabled=\"disabled\" onChange=\"checkState();checkDbVersion();\">"+
            "<option name=\"default\" value=\"0\"  selected=\"true\"> -- Please select a database -- </option>"+
            //"<option name=\"brlMirror\" value=\"0\"  selected=\"true\">dbNames</option>"+
            //"<option name=\"brlMirror\" value=\"db1\">db1</option>"+
            "</select></div>"+
            "<div style=\"display:table-row;height:8px;\"><span style=\"width:80%;\">Save Selection as:</span></div>"+
            "<div style=\"display:table-row;height:8px;\" class=\"legend11\";><span style=\"width:80%;\">Enter a name to identify this set of selections</span></div>"+
            "<div style=\"display:table-row;height:15px;\" ><input type=\"text\" ext:qtip=\"Name to save selections under\" id=\"selName\" name=\"selName\" style=\"width:80%;\" disabled=\"true\" onkeyup=\"checkState();\"></div>"+
            "</div></div>"
    }, {
      region: 'north',
      layout: 'fit',
      frame: true,
      border: false,
      split: false,
      collapsible: false,
      html: "<div class=\"legendBold12\" style=\"padding:5px; padding-left:10px;\">Choose a group and database to save selections in:</div>"
    }, {
      region: 'south',
      layout: 'fit',
      frame: true,
      border: false,
      split: false,
      collapsible: false,
      html: "<div class=\"legendBold12\" style=\"padding:5px;padding-left:10px;display:table;width:90%;margin:0 auto;\">"+
      "<input type=\"button\" name=\"selSaveButton\" id=\"selSaveButton\" ext:qtip=\"Save selections as a 'List of "+entityTypeForms[3]+"' for further analysis using Workbench Tools\" disabled=\"disabled\" readonly=\"true\" style=\"width:45%;float:left;cursor:pointer;\" value=\"Save Selections\" onClick=\"startSaveSelections();\">"+
      "<input type=\"button\" id=\"cancel\" value=\"Cancel\" style=\"width:40%;float:right;cursor:pointer;\" onClick=\"saveWindow.close();\">"+
      "</div>"
    }]
  });
  saveWindow.show();
  getGroupsForUser(userLogin);

}





function startSaveSelections()
{

  rsrcPath = '/REST/v1/grp/'+fullEscape(Ext.get('grpSelector').dom.value)+'/db/'+fullEscape(Ext.get('dbSelector').dom.value)+'/'+entityTypeForms[4]+'/entityList/'+fullEscape(Ext.get('selName').dom.value)
  if(entityType == 'sample')
  {
    rsrcPath = '/REST/v1/grp/'+fullEscape(Ext.get('grpSelector').dom.value)+'/db/'+fullEscape(Ext.get('dbSelector').dom.value)+'/sampleSet/'+fullEscape(Ext.get('selName').dom.value)
  }


  Ext.Ajax.request(
  {
    url : '/java-bin/apiCaller.jsp' ,
    timeout : 90000,
    params:
    {
      rsrcPath: rsrcPath,
      apiMethod : 'GET'
    },
    method: 'GET',
    success: nameExistsDialog,
    failure: nameExistsFailureDialog
  }) ;
}



function nameExistsFailureDialog(result, request) {
  if(result.statusText =="Not Found")
  saveSelections();
  else
  {
  var message;
  windowTitle = 'An error has occurred.';
  resultText = (result.responseText) ? result.responseText : "No response from server.";
   message = '<div id="failureContainer" class="extColor" style="height:auto;width:auto;overflow:auto;">'+
'<div id="failureDiv" class="msg fail" style="height:80%;width:80%;margin:0 auto;margin-left:150px;">'+
resultText+
'</div></div>'

  //  '  <b>Message:</b><br><div style="margin-bottom:10px; ' + cssHeight + '">' + statusMsg + "</div>" ;
  //message = '<div class="wbDialog" style="height:auto; width:auto;"><div class="wbDialogFeedback wbDialogFail">' + '  <div class="wbDialogFeedbackTitle">There has been an error.<br>' + resultText + '<br>' + '  Please try again later.<br>' + '</div></div>';
  //Ext.MessageBox.show({
  //  title: windowTitle,
  //  msg: message,
  //  buttons: Ext.MessageBox.OK,
  //  cls: "wbDialogAlert",
  //  ctCls: "wbDialogAlert"
  //});
   Ext.MessageBox.show(
    {
      title: 'Warnings',
      msg: message,
      buttons: Ext.MessageBox.OK
    }) ;
  }
}



function nameExistsDialog(result, request)
{
  var jsonData = Ext.util.JSON.decode(result.responseText) ;
  //Change this to check for status code of Ok so the result can be trusted and also that an array not a hash was returned
  if(jsonData.status.statusCode == 'OK' && jsonData.data instanceof Array && jsonData.data.length == 0)
  {
    saveSelections();
  }
  else
  {
    msg = "A selection list of this name already exists in this database.<br>Click Yes to append to it, No to use a different name."
    title = 'Append to existing list?'
    if(entityType == 'sample')
    {
      msg = "A SampleSet of this name already exists in this database.<br>Click Yes to overwrite it, No to use a different name."
      title = 'Overwrite existing SampleSet?'
    }
     Ext.MessageBox.show({
      title: title,
      msg: msg,
      buttons: Ext.MessageBox.YESNO,
      animEl: 'elId',
      icon: Ext.MessageBox.QUESTION,
      fn: handleAppend
    });
  }
}

function dbVersionDialog(result, request)
{
  var jsonData = Ext.util.JSON.decode(result.responseText) ;
  if(jsonData.data.text.toLowerCase() == genome.toLowerCase())
  {
    checkState();
  }
  else
  {
     Ext.MessageBox.show({
      title: 'Version mismatch',
      msg: "You cannot save to this database because its version '"+jsonData.data.text+"' doesn't match the selections '"+genome+"'",
      buttons: Ext.MessageBox.OK,
      animEl: 'elId',
      icon: Ext.MessageBox.ERROR
    });
     resetOptions("dbSelector",0);
     checkState();
  }
}


function handleAppend(btnId, text, opt) {
  if (btnId == 'yes') saveSelections(); else Ext.MessageBox.hide();
}

function saveSelections()
{
   rsrcPath = '/REST/v1/grp/'+fullEscape(Ext.get('grpSelector').dom.value)+'/db/'+fullEscape(Ext.get('dbSelector').dom.value)+'/'+entityTypeForms[4]+'/entityList/'+fullEscape(Ext.get('selName').dom.value);
     if(entityType == 'sample')
  {
    rsrcPath = '/REST/v1/grp/'+fullEscape(Ext.get('grpSelector').dom.value)+'/db/'+fullEscape(Ext.get('dbSelector').dom.value)+'/sampleSet/'+fullEscape(Ext.get('selName').dom.value)
  }
   var entitiesToSave = []
  var cellsArray = document.getElementsByClassName('filled');
  for (i = 0; i <= cellsArray.length - 1; i++) {
    divCell = cellsArray[i].parentNode.parentNode;
    if (divCell.className.match(selectClassName)){
    arr = cellsArray[i].id.split(/-/);
    var tt = trackList[arr[2]-1][arr[1]-1]
    for(var j =0;j<=tt.length-1;j++)
    {
      if(entityType == 'sample')
      entitiesToSave.push(fullEscape(tt[j]))
      else
      entitiesToSave.push({"url":tt[j]});
    }
    }
  }
  if(entityType  == 'sample')
  saveSampleSelections(rsrcPath,entitiesToSave,Ext.get('selName').dom.value,Ext.get('dbSelector').dom.value);
  else
    Ext.Ajax.request(
  {
    url : '/java-bin/apiCaller.jsp' ,
    timeout : 90000,
    params:
    {
      rsrcPath: rsrcPath,
      apiMethod : 'PUT',
      payload:entitiesToSave.toJSON(),
      saveName:Ext.get('selName').dom.value,
      dbName:Ext.get('dbSelector').dom.value
    },
    method: 'POST',
    success: saveSuccessDialog,
    failure: saveFailureDialog
  }) ;
}

function saveSuccessDialog(result, request)
{
  var jsonData = Ext.util.JSON.decode(result.responseText) ;

  if(jsonData.status.statusCode == "OK")
  {
    Ext.MessageBox.show({
      title: 'Save successful',
      msg: "<div style=\"margin:0 auto;width:350px;text-align:center;\">Your Selections have been saved!</div>"+
       "<div style=\"margin:0 auto;width:350px;\">View your saved "+entityTypeForms[1]+" in the <a target=\"_blank\"  href=\"/java-bin/workbench.jsp\">Workbench Data Selector</a> within your database:&nbsp;"+
        "\""+request.params.dbName+"\"<br><br>\"List of Selections\"<br>&nbsp;&nbsp;&rArr;&nbsp;\"List of "+entityTypeForms[1]+"\"<br>&nbsp;&nbsp;&nbsp;&nbsp;&rArr;&nbsp;\""+request.params.saveName+"\"</div>",
      buttons: Ext.MessageBox.OK,
      minWidth:400,
      fn:function(){ saveWindow.close();}
    });
  }
  else
  {
    Ext.MessageBox.show({
      title: 'Error Saving selections',
      msg: jsonData.status.msg,
      buttons: Ext.MessageBox.OK
    });
  }
}


function checkState()
{
  prevState = true
  for(var i =0;i<=idList.length - 2;i++)
  {
    var dd = document.getElementById(idList[i])
    var nn = document.getElementById(idList[i+1])
    if(prevState && dd.value != nValues[i])
    {
      nn.disabled = "";
      Element.setStyle(nn,{backgroundColor:''});
    }
    else
    {
      prevState = false;
      nn.disabled = "disabled";
      Element.setStyle(nn,{backgroundColor:'#ddd'});
    }
  }
}

function checkDbVersion()
{
  rsrcPath = '/REST/v1/grp/'+fullEscape(Ext.get('grpSelector').dom.value)+'/db/'+fullEscape(Ext.get('dbSelector').dom.value)+'/version';
    Ext.Ajax.request(
  {
    url : '/java-bin/apiCaller.jsp' ,
    timeout : 90000,
    params:
    {
      rsrcPath: rsrcPath,
      apiMethod : 'GET'
    },
    method: 'GET',
    success: dbVersionDialog,
    failure: displayFailureDialog
  }) ;
}



function changeElementState(curId,nullValue,enableList, disableList)
{
  if(document.getElementById(curId).value != nullValue)
  {
    disabledState = "";
    for(var i=0;i<=enableList.length-1;i++) setDisabledState(enableList[i],disabledState);
  }
  else
  {
    disabledState = "disabled";
    for(var i=0;i<=disableList.length-1;i++) setDisabledState(disableList[i],disabledState);
  }
}


function enableElement(curId,elementIds,nullValue)
{
  if(document.getElementById(curId).value != nullValue)
    disabledState = "";
  else
    disabledState = "disabled";
  for(var i=0;i<=elementIds.length-1;i++) setDisabledState(elementIds[i],disabledState);

}

function setDisabledState(element,state)
{
  document.getElementById(element).disabled = state;
}

function showWindow(window, waitForCells, toolId)
{
  if(window == "saveSelection")
  {
    collectCells();
    if(anyCellsChecked())
    showSaveSelectionDialog();
    else
    {
    if(waitForCells)
    setTimeout(function(){showWindow(window,true, toolId)},50);
    else
    showNoEntitiesMessage();
    }
  }
  else if(window == "getOutputUrls")
   {
    collectCells();
    if(anyCellsChecked())
    showActivateToolDialog(toolId);
    else
    {
    if(waitForCells)
    setTimeout(function(){showWindow(window,true, toolId)},50);
    else
    showNoEntitiesMessage();
    }
   }
}



// switch cell from off to on or vice-versa (visually)
function swapState(cell) {
  if (cell.className.match(selectClassName)) {
    deselect(cell);
  } else {
    select(cell);
  }
}

function preSelectCells(ycoords,xcoords)
{
  for(var i=0;i<=ycoords.length-1;i++)
  {
    y=ycoords[i]+1;
    x=xcoords[i]+1;
    selectCellByCoords(x,y);
  }
}

function selectCellByCoords(y,x)
{
  cell = document.getElementById("td-" + y + "-" + x);
  if(cell) select(cell.parentNode.parentNode); else setTimeout(function(){selectCellByCoords(y,x)},50);
}


function restoreSelectedCells()
{
  
  for(i=0;i<=selectedCells.length-1;i++)
{
    xy = selectedCells[i].split(/-/);
    selectCellByCoords(xy[1],xy[2])
  }
  
}

// which ucsc browser to use
function checkForUCSC(select)
{
  if(select.options[select.selectedIndex].value.match("ucsc"))
  {
    Element.setStyle(document.getElementById("ucscHistory"),{visibility:'visible'});
  }
  else
  {
    Element.setStyle(document.getElementById("ucscHistory"),{visibility:'hidden'});
  }
}


// select entire row of grid (All filled cells in row)
function toggleRowSelection(row)
{

  for (i = 1; i <= maxColumns; i++) {
    cell = document.getElementById("td-" + i + "-" + row);
    if (!cell.className.match(/empty/)) {
      swapState(cell.parentNode.parentNode);
      }
  }

  var openTip = Ext.getCmp(openId);
  if(openTip) openTip.hide();
}
// ditto for column
function toggleColumnSelection(column)
{
  for (j = 1; j <= maxRows; j++) {
    cell = document.getElementById("td-" + column + "-" + j);
    if (!cell.className.match(/empty/))
    {
      swapState(cell.parentNode.parentNode);
    }
  }
  var openTip = Ext.getCmp(openId);
  if(openTip) openTip.hide();
}

function showNoEntitiesMessage()
{
          Ext.MessageBox.show(
        {
          title: 'No '+entityTypeForms[3]+' Selected',
          msg: "Please <b>select</b> one or more "+entityTypeForms[1]+" to view or save/go to the workbench.",
          buttons: Ext.MessageBox.OK,
          cls: "wbDialogAlert",
          ctCls: "wbDialogAlert"
        }) ;
}

function showBrowserNotSupportedMessage(type, version)
{
          Ext.MessageBox.show(
        {
          title: type+' Browser unavailable for '+version,          
          msg: "<div style=\"margin:0 auto;width:350px;\">The "+type.toLowerCase()+" browser functionality is currently not supported for databases with version "+version+
          ". This feature is in a beta stage and only available for specific databases and versions.<br>Please <a href=\"mailto:genboree_admin@genboree.org\">contact us</a> to request support for your specific version.</div>",          
          buttons: Ext.MessageBox.OK,
          width:400,
          cls: "wbDialogAlert",
          ctCls: "wbDialogAlert"
        }) ;
}


// Goes with selecting everything in a row
function clearRowCheckBoxes()
{
  var rows=document.getElementById("maxRows").value;
  for (j = 1; j <= rows; j++) {
    document.getElementById("rowBox_"+j).checked = false;
  }
}
// Goes with selecting everything in a column
function clearColumnCheckBoxes()
{
  var columns=document.getElementById("maxColumns").value;
  for (i = 1; i <= columns; i++) {
    document.getElementById("columnBox_"+i).checked = false;
  }
}
// clear all selected cells in the grid
function clearSelections() {
  var cellsArray = document.getElementsByClassName('filled');
  for (i = 0; i <= cellsArray.length - 1; i++) {
    divCell = cellsArray[i].parentNode.parentNode;
    if (divCell.className.match(selectClassName)) {
      deselect(divCell);
    }
  }
document.getElementById('xattrVals').value = "EA_EMPTY_FIELD";
document.getElementById('yattrVals').value = "EA_EMPTY_FIELD";
}




// shows the data access and download window
// Some policies and download link are not available, those are directed to 
// atlas home page instead.
function showDataAccess()
{
  var policies = ["http://www.nida.nih.gov/about/roadmap/epigenomics/data_access_policies.html", "http://genboree.org/epigenomeatlas/index.rhtml", "http://www.epigenomes.ca/data_access_policy.html", "http://www.cbrc.jp/index.eng.html"];
  var download = ["http://genboree.org/EdaccData/Current-Release/experiment-sample/Expression_Array/", "http://genboree.org/epigenomeatlas/index.rhtml", "http://www.epigenomes.ca/downloads.html", "http://www.cbrc.jp/index.eng.html"];
  var info = ["http://www.ncbi.nlm.nih.gov/geo/roadmap/epigenomics/"]
  var dbString = ""
  dbString = "<li><table style=\"border-spacing:5px;\">";
  for(ii=0;ii<=dbNames.length-1;ii++)
  {
    dbString += "<tr><td><style=\"vertical-align:bottom;\" id=\"db-"+ii+"\"></td>";
    dbString += "<td style=\"border:1px solid black; height:10px; width:10px;background-color:"+ dbColors[ii%dbColors.length]+";\"></td>";
    dbString += "<td style=\"cursor:default;font:11px verdana;\" ext:hide=\"user\" ext:qtitle=\""+dbNames[ii]+"\"ext:qtip=\""+unescape(dbDescs[ii])+"\">"+dbNames[ii]+"</td>";
    dbString += "<td style=\"text-align: center;padding: 5px\"><a href=" +policies[ii]+ " target=\"_blank\"><img src='/images/silk/help.png'></a></td>";
    dbString += "<td style=\"text-align: center;padding: 5px\"><a href=" +download[ii]+ " target=\"_blank\"><img src='/epigenomeatlas/images/download.png'></a></td></tr>";
  }
  dbString += "</table></li>";
  delete dbSelectWindow;
  dbSelectWindow = new Ext.Window({
    id: 'dbSelectWin',
    bodyCssClass:'extColor',
    modal: true,
    autoScroll: false,
    title: '',
    stateful: false,
    height: 400,
    width: 300,
    layout: 'border',
    constrainHeader: true,
    items: [{
      region: 'center',
      layout: 'fit',
      frame: false,
      border: true,
      html:"<div id=\"outerContainer\" class=\"extColor\" style=\"overflow:auto;height:100%;\">"+
        "<div id=\"elementContainer\" class=\"extColor\" >"+
        "<ul>"+dbString+"</ul>"+
        "</div></div>"
    }, {
      region: 'north',
      layout: 'fit',
      frame: true,
      border: false,
      split: false,
      collapsible: false,
      html: "<div class=\"legendBold12\" style=\"padding:5px; padding-left:10px;\">Data Access Policies and Download</div>"
    }, {
      region: 'south',
      layout: 'fit',
      frame: true,
      border: false,
      split: false,
      collapsible: false,
      html: "<div class=\"legendBold12\" style=\"padding:5px;padding-left:10px;display:table;width:90%;margin:0 auto;\">"+
      "</div>"
    }]
  });
  dbSelectWindow.show();
  dbSelectWindow.center();
  resizeHeight(dbSelectWindow, 10, '#outerContainer', '#elementContainer');
  dbSelectWindow.show();
  colorCells()
}


