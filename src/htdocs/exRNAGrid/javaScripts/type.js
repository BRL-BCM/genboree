function makeType(type)
{
  var typeName ;
  var title; 
  var wid ;
  var hig ;
  var panelName;
  var extElement = 'htmltable';
  if(type == "fluidVsExp")
  {
    typeName = type +'.json';
    title = 'BioFluid vs Experiment Types';
    wid = 600 ;
    hig = 250 ;
  }
  
  if(type == "fluidVsDis")
  {
    typeName = type +'.json';
    title = 'BioFluid vs Diseases';
    wid = 1400 ;
    hig = 350;
  }
  Ext.create('Ext.panel.Panel', {
    title: title,
    id: extElement,
    cls: 'mainPanel',
    bodyCls: 'colPanel',
    width: wid,
    height: hig,
    html: '',
    autoScroll: true,
    renderTo: 'panel'
  });
  viewType('html', typeName, extElement);
}

function viewType(format, typeName, extElement)
{
  //Now from a static file
  var respath = '/REST/v1/grp/'+gridGrp+'/kb/'+gridKb+'/coll/'+gridColl+'/doc/EXR-DGALA1GUTPLASM-AN?transformed=true&transform='+typeName+'&format='+ format + '&onClick=true';
  Ext.Ajax.request(
  {
    url : '/java-bin/apiCaller.jsp' ,
    timeout : 1200000,
    method: 'GET',
    params:
    {
      rsrcPath : respath,
      apiMethod : 'GET'
    },
    callback: function(opts, success, response)
    {
        var gridTable = response.responseText ;
        if(response.status >= 200 && response.status < 400 && gridTable)
        {
          if(format == 'html')
          {
            Ext.getCmp(extElement).body.update(gridTable);
          }
          else
          {
            Ext.Msg.alert("ERROR", "INVALID format for gridView requested!") ;
          }
        }
        else
        {
          if(gridTable)
          {
            var grObj  = JSON.parse(gridTable) ;
            var grStatusObj   = grObj['status'] ;
            message = grStatusObj['msg'] + "<br>" ;
          }
          message = message + "API Failed to get the grid data" + response.status + ', ' + response.statusText;
          Ext.Msg.alert("ERROR",  message) ;
        }
    }
  }) ;
}

// Display biofluid vs experiment type/diseases grid in a panel

function makeGridForType(buttonId, type)
{
  var typeName ;
  var title; 
  var wid ;
  var hig ;
  var extElement = 'gvTree';
  
  var button = Ext.get(buttonId);
  var thisPanel = Ext.get(extElement);
  // Destroy existing content in the panel
  thisPanel.destroy();

  if (button.hasCls("clicked")) {
    // When button is already clicked, then reset buttons
    // and display welcome text
    button.removeCls("clicked");
    button.addCls("unclicked") ;
    welcomeText();
  } else {
    // Remove any clicked classes
    var buttons = Ext.DomQuery.select(".button-link") ;
    for(var ii=0; ii<buttons.length; ii++)
    {
      var extObj = Ext.get(buttons[ii]);
      extObj.removeCls("clicked");
      extObj.addCls("unclicked");
    }
    button.addCls("clicked") ;
    button.removeCls("unclicked");
    
    // Check grid type and modify settings accordingly
    if(type == "fluidVsExp")
    {
      typeName = type +'.json';
      title = 'BioFluids vs Experiment Types';
      wid = 600 ;
      hig = 250 ;
    }
    else if(type == "fluidVsDis")
    {
      typeName = type +'.json';
      title = 'BioFluids vs Diseases';
      wid = 900 ;
      hig = 350;
    }

    // Panel to render biofluid vs experiment type/diseases grid
    // NOTE: All grids as well as welcome text are rendered into the same div with id "mainDivPanel"
    // and same Ext.Panel with id "gvTree"   
    Ext.create('Ext.panel.Panel', {
      title: title,
      id: extElement,
      cls: 'mainPanel',
      bodyCls: 'colPanel',
      width: wid,
      height: hig,
      html: '',
      autoScroll: true,
      renderTo: 'mainDivPanel'
    });
    viewType('html', typeName, extElement);
  }  
}
