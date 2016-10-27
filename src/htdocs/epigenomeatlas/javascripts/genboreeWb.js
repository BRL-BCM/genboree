

// Resource Urls for input and output panels are send via post
function sendToWorkbench(outputsToDisplay)
{
  var cellsArray = document.getElementsByClassName('filled');
  var trkUrlsToDisplay = [];
  var divCell = '' ;
  // Get the tracks selected
  // This is for the Input Data panel 
  collectCells() ;
  if(anyCellsChecked())
  {
    //get the track Urls from each selected cell 
    for (var i = 0; i <= cellsArray.length - 1; i++)
    {
      divCell = cellsArray[i].parentNode.parentNode ;
      if (divCell.className.match(selectClassName))
      {
        arr = cellsArray[i].id.split(/-/) ;
        // trackList global made at multiGrid rhtml!
        var tt = trackList[arr[2]-1][arr[1]-1]
        for(var j =0; j<=tt.length-1; j++)
        {
          trkUrlsToDisplay.push(tt[j]) ;
        }
      }
    }

    // make a post to workbench.jsp
    var wbForm = document.createElement("form") ;
    wbForm.method = "post" ;
    wbForm.action = gridToWorkbenchFile ;
    wbForm.target = "_blank" ;
    formAppend(wbForm, document.createElement("input") ,"populateWorkbench", true) ;
    formAppend(wbForm, document.createElement("input") ,"populateInputs", trkUrlsToDisplay) ;
    // Other resource Urls that are specific to Output Targets in the workbench.
    if(outputsToDisplay.length > 0)
    {
      formAppend(wbForm, document.createElement("input") ,"populateOutputs", outputsToDisplay) ;
    }
    document.body.appendChild(wbForm) ;
    wbForm.submit() ;
  }
  else
  {
    // cannot proceed with no track selections
    showNoEntitiesMessage();
  }


}


// Moves the public grid to private via multiGridViewer.jsp
// Pops the activate tool window to fetch the resource information
// required to populate the Output targets
function activateTools(item)
{
  var toolId = item.getId();
  collectCells();
  if(anyCellsChecked())
  {
    newLoc=gridViewerFile+"?"+
    "showWindow=getOutputUrls&"+
    "toolId="+fullEscape(toolId)+
    "&dbList="+fullEscape(dbList)+
    "&yattrVals="+fullEscape(document.getElementById("yattrVals").value)+
    "&xattrVals="+fullEscape(document.getElementById("xattrVals").value)+
    "&gbGridYAttr="+fullEscape(yattr)+"&gbGridXAttr="+fullEscape(xattr)+
    "&ylabel="+fullEscape(ylabel)+"&xlabel="+fullEscape(xlabel)+
    "&ytype="+fullEscape(ytype)+"&xtype="+fullEscape(xtype)+"&defaultMode="+defaultMode+
    "&gridTitle="+fullEscape(gridTitle)+"&pageTitle="+fullEscape(pageTitle)+"&dbShow="+fullEscape(dbShow.join(","));
   window.location=newLoc;
  }
  else
  {
    showNoEntitiesMessage();
  }
}

function getResources(toolId)

{
  var tools = {
    findERChromHMM : ["grpSelector","dbSelector", "prjSelector"],
    createHub : ["grpSelector"]
  };
  var nvalues = [];
  var idlist = tools[toolId] ;
  for (ii = 0; ii < tools[toolId].length-1; ii++) {
    nvalues.push("0") ;
  }
  nvalues.push("");
  return [idlist, nvalues]
}




// Currently functionable for any tools that require a database resource and a project resource
// in the Output Targets
function showActivateToolDialog(toolId)
{
  // List of the div elements in the window
  var resourceLists = getResources(toolId) ;
  idList = resourceLists[0] ; 
  nValues = resourceLists[1] ; 
  idList.push("selSaveButton") ;
  
  var winHeight = idList.length * 100 ;
  var windowBodyHtml = {
  dbSelector: "<option name=\"default\" value=\"0\"  selected=\"true\"> -- Please select a group -- </option>"+
            "</select></div>"+
            "<div style=\"display:table-row;height:8px;\"><span style=\"width:80%;\">Select a Database:</span></div>"+
            "<div style=\"display:table-row;height:8px;\"  class=\"legend11\"><span style=\"width:80%;\">Choose a database within your group.</span></div>"+
            "<div style=\"display:table-row;height:15px;\" id=\"dbDiv\" >"+
            "<select id=\"dbSelector\" name=\"dbSelector\" ext:qtip=\"Database to run the tool.\" style=\"width:80%;\" class=\"legend10\" disabled=\"disabled\" onChange=\"checkState();checkDbVersion();getPrjsForGroup();\">"+
            "<option name=\"default\" value=\"0\"  selected=\"true\"> -- Please select a database -- </option>"+
            "</select></div>",
  grpSelector: "<div style=\"display:table-row;height:8px;\"><span style=\"width:80%;\">Select a Group:</span></div>"+
            "<div style=\"display:table-row;height:15px;\" id=\"groupDiv\" >"+
            "<select id=\"grpSelector\" name=\"grpSelector\" ext:qtip=\"Group to activate tools.\" style=\"width:80%;\" class=\"legend10\" onChange=\"checkWriteGrpPermissions();getDBsForGroup();\">",
  prjSelector: "<div style=\"display:table-row;height:8px;\"><span style=\"width:80%;\">Select a Project:</span></div>"+
            "<div style=\"display:table-row;height:8px;\"  class=\"legend11\"><span style=\"width:80%;\">Choose a project within your group.</span></div>"+
            "<div style=\"display:table-row;height:15px;\" id=\"dbDiv\" >"+
            "<select id=\"prjSelector\" name=\"prjSelector\" ext:qtip=\"Project to run the tool.\" style=\"width:80%;\" class=\"legend10\" disabled=\"disabled\" onChange=\"checkState();checkDbVersion();\">"+
            "<option name=\"default\" value=\"0\"  selected=\"true\"> -- Please select a project -- </option>"+
            "</select></div>"
 } ;

 //windowBodyHtml.grpSelector+windowBodyHtml.dbSelector+windowBodyHtml.prjSelector+
 var htmlbody = "" ;
 for (ii = 0; ii < idList.length-1; ii++) { 
    htmlbody += windowBodyHtml[idList[ii]];
 }

 if(!entityType)
  {
    entityType = 'track';
    entityTypeForms = ['track','tracks','Track','Tracks'];
  }
  delete saveWindow;
  saveWindow = new Ext.Window({
    id: 'activeWin',
    cls:'masked',
    bodyCssClass:'extColor',
    modal: true,
    autoScroll: false,
    title: 'Activate Tool ' +toolId.toUpperCase()+ ' in Genboree Workbench',
    height: winHeight,
    width: 300,
    layout: 'border',
    constrainHeader: true,
    items: [{
      region: 'center',
      layout: 'fit',
      frame: false,
      border: true,
      html:"<div class =\"extColor\" style=\"height:100%;width:100%;\"><div class =\"legendBold11\" style=\"display:table;padding:5px;padding-left:10px;height:100%;width:100%;\">"+
           //windowBodyHtml.grpSelector+windowBodyHtml.dbSelector+windowBodyHtml.prjSelector+
           htmlbody+
           "</div></div>"
    }, {
    }, {
      region: 'north',
      layout: 'fit',
      frame: true,
      border: false,
      split: false,
      collapsible: false,
      html: "<div class=\"legendBold12\"  ext:qtip=\"<b>Choose the resources</b><br>Choose the resources - group, database and project to poplulate the workbench. This will envoke the tool and will be highlighted as green in the workbench tool menu.\" style=\"padding:5px; padding-left:10px;\">Choose the resources below to populate the Genboree Workbench \"Output Targets\" field.</div>"
    }, {
      region: 'south',
      layout: 'fit',
      frame: true,
      border: false,
      split: false,
      collapsible: false,
      html: "<div class=\"legendBold12\" style=\"padding:5px;padding-left:10px;display:table;width:90%;margin:0 auto;\">"+
      "<input type=\"button\" name=\"selSaveButton\" id=\"selSaveButton\" ext:qtip=\"This opens the Genboree Workbench in a separate tab with the chosen resources populated in the workbench.\" disabled=\"disabled\" readonly=\"true\" style=\"width:45%;float:left;cursor:pointer;\" value=\"Activate Tool\" onClick=\"getOutputUrls(\'"+toolId+"\');saveWindow.close();\">"+ 
      "<input type=\"button\" id=\"cancel\" value=\"Cancel\" style=\"width:40%;float:right;cursor:pointer;\" onClick=\"saveWindow.close();\">"+
      "</div>"
    }]
  });
  saveWindow.show();
  getGroupsForUser(userLogin);
}



function checkWriteGrpPermissions()
{
  rsrcPath = '/REST/v1/grp/'+fullEscape(Ext.get('grpSelector').dom.value)+'/usr/'+userLogin+'/role?connect=no'
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
    success: roleSuccess,
    failure: saveFailureDialog
  }) ;

}


// Sends the resource Urls for the Output targets
function getOutputUrls(toolId)
{
  outputUrls = [] ;
  if(toolId == 'findERChromHMM')
  {
    outputUrls.push('http://'+location.host+'/REST/v1/grp/'+fullEscape(Ext.get('grpSelector').dom.value)+'/db/'+fullEscape(Ext.get('dbSelector').dom.value)) ;
    outputUrls.push('http://'+location.host+'/REST/v1/grp/'+fullEscape(Ext.get('grpSelector').dom.value)+'/prj/'+fullEscape(Ext.get('prjSelector').dom.value)) ;
  }
  else if(toolId == 'createHub')
  {
    outputUrls.push('http://'+location.host+'/REST/v1/grp/'+fullEscape(Ext.get('grpSelector').dom.value));
  }
  sendToWorkbench(outputUrls) ; 
}


function roleSuccess(result, request)
{

  var jsonData = Ext.util.JSON.decode(result.responseText) ;
  var message = "" ;
  if(jsonData.data.role == "subscriber")
  {
      message = "You do not have sufficient permissions to write to this group/database. Please choose a different group/database.<br>"
      resetOptions("grpSelector",0);
      checkState();
    Ext.MessageBox.show({
      title: 'Error activating tool in Genboree Workbench',
      msg: message,
      buttons: Ext.MessageBox.OK,
      animEl: 'elId',
      icon: Ext.MessageBox.ERROR
    });
   }
}



function getPrjsForGroup()
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
      rsrcPath: '/REST/v1/grp/'+fullEscape(group)+'/prjs',
      apiMethod : 'GET'
    },
    method: 'GET',
    success: prjSuccessDialog,
    failure: displayFailureDialog
  }) ;
  }
  else
  checkState();
}



function prjSuccessDialog(result, request)
{
  removeOptions("prjSelector");
  var jsonData = Ext.util.JSON.decode(result.responseText) ;
  if(jsonData.data.length == 0)
  {
     Ext.MessageBox.show({
      title: 'No projects Found',
      msg: "No projects exist for this group. Please choose a different group.",
      buttons: Ext.MessageBox.OK,
       animEl: 'elId',
      icon: Ext.MessageBox.ERROR
    });
    checkState();
  }
  else
  {
  addOptions(jsonData.data,"prjSelector");
  checkState();
  }
}

