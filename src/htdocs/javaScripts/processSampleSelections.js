entityType = 'sample';
entityTypeForms = ['sample','samples','Sample','Samples','samples'];
// This MUST be initialized to the correct version of the incoming database to allow gene viewing to work
supportedVersion = "fakeVersion"

function anyCellsChecked()
{
    if(!(document.getElementById('xattrVals').value.match(/\S/) && document.getElementById('yattrVals').value.match(/\S/)))
    {
    return false;
    }
    else
    {
      return true;
    }
}


function sortVals(a,b)
{
  if(a[0] == b[0])
  return(a[1]-b[1]);
  else
  return a[0]-b[0];
}

function saveSampleSelections(rsrcPath,samplesToSave,saveName,dbName)
{
  Ext.Ajax.request({
    url: '/genboree/createSampleSetAndCopySamples.rhtml',
    params: {
      userId:userId,
      samples:samplesToSave.join(','),
      sampleSet:fullEscape(rsrcPath),
      saveName:saveName,
      dbName:dbName,
      sourceDb:sourceDb
    },
    method: 'GET',
    success: sampleSaveSuccess,
    failure: saveFailureDialog
  });
}

function sampleSaveSuccess(result, request)
{
  var jsonData = Ext.util.JSON.decode(result.responseText) ;

  if(jsonData.status.statusCode == "Created")
  {
    Ext.MessageBox.show({
      title: 'Save successful',
      msg: "<div style=\"margin:0 auto;width:350px;text-align:center;\">Your Selections have been saved!</div>"+
       "<div style=\"margin:0 auto;width:350px;\">View your SampleSet in the <a target=\"_blank\"  href=\"/java-bin/workbench.jsp\">Workbench Data Selector</a> within your database:&nbsp;"+
        "\""+request.params.dbName+"\"<br>&nbsp;&nbsp;&rArr;&nbsp;\"SampleSets\"<br>&nbsp;&nbsp;&nbsp;&nbsp;&rArr;&nbsp;\""+request.params.saveName+"\"</div>",
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


// Accumulate all the cells which have been checked/selected. Before this point every cell handles its own display of off/on
// The resulting data structure is an array of arrays where each array contains a track.
function collectCells()
{
  document.getElementById('xattrVals').value = "";
  document.getElementById('yattrVals').value = "";
  var cellsArray = document.getElementsByClassName('filled');
  xattrVals = []
  yattrVals = []
  valIndices = []
  for (i = 0; i <= cellsArray.length - 1; i++) {
    divCell = cellsArray[i].parentNode.parentNode;
    if (divCell.className.match(selectClassName)){
    arr = cellsArray[i].id.split(/-/);
    valIndices.push([arr[2]-1,arr[1]-1]);
    //xattrVals.push(fullUrlEscape(xvals[arr[1]-1]));
    //yattrVals.push(fullUrlEscape(yvals[arr[2]-1]));
    }
  }
  valIndices.sort(sortVals)
  for(i=0;i<=valIndices.length-1;i++)
  {
    yattrVals.push(fullEscape(yvals[valIndices[i][0]]));
    xattrVals.push(fullEscape(xvals[valIndices[i][1]]));
  }
  document.getElementById('xattrVals').value = xattrVals.join(',');
  document.getElementById('yattrVals').value = yattrVals.join(',');
}

function sendToGeneBrowser(item)
{
  collectCells();
  if(anyCellsChecked())
  {
    if(genome == supportedVersion)
    {
    if(inGenbSession)
    {
      createGeneViewerDigest();
    }
    else
    {
    var myForm = document.createElement("form");
    myForm.method = "post";
    myForm.action = geneViewerFile;
    myForm.target = "_blank"
    formAppend(myForm,document.createElement("input") ,"xattrVals", document.getElementById("xattrVals").value);
    formAppend(myForm,document.createElement("input") ,"yattrVals", document.getElementById("yattrVals").value);
    formAppend(myForm,document.createElement("input") ,"gbGridYAttr", yattr);
    formAppend(myForm,document.createElement("input") ,"gbGridXAttr", xattr);
    formAppend(myForm,document.createElement("input") ,"sampledbList",dbList);
    formAppend(myForm,document.createElement("input") ,"mbwAnnotationType",mbwAnnotationType);
//    formAppend(myForm,document.createElement("input") ,"roiTrack","http%253A%252F%252F10.15.5.109%252FREST%252Fv1%252Fgrp%252FMicorbiome%2520ROI%2520Data%252Fdb%252FDataViewer%2520ROI%252Ftrk%252FGene%253ACollection");
    if(genome!="hg19")
    {
      formAppend(myForm,document.createElement("input") ,"genome", genome);
    }
    document.body.appendChild(myForm);
    myForm.submit();
    document.body.removeChild(myForm);
    }
    }
    else
    {
      showBrowserNotSupportedMessage(mbwAnnotationType,genome);
    }
  }
  else
  {
    showNoEntitiesMessage();
  }
}


function digestSuccessDialog(result, request)
{
  var jsonData = Ext.util.JSON.decode(result.responseText) ;
  digestKey = jsonData.data.url.replace(/.+\//,"");
  window.location = geneViewerFile+'?genbSession=true&digestKey='+digestKey;
}


function digestFailureDialog(result,request)
{
      message = "Unable to generate digestKey<br>"
      resultText = (result.responseText) ? result.responseText : "No response from server.";
      message += resultText;
    Ext.MessageBox.show({
      title: 'Error sending to gene browser',
      msg: message,
      buttons: Ext.MessageBox.OK,
      animEl: 'elId',
      icon: Ext.MessageBox.ERROR
    });
}


function createGeneViewerDigest()
{
   var jsonData = {};
      jsonData["xattrVals"] = document.getElementById("xattrVals").value;
      jsonData["yattrVals"] = document.getElementById("yattrVals").value;
      jsonData["gbGridYAttr"] = yattr;
      jsonData["gbGridXAttr"] = xattr;
      jsonData["sampledbList"] = dbList;
      jsonData["mbwAnnotationType"] = mbwAnnotationType;
//      jsonData["roiTrack"] = "http://10.15.5.109/REST/v1/grp/Microbiome%20ROI%20Data/db/DataViewer%20ROI/trk/Gene%3ACollection";
      if(genome!="hg19") jsonData["genome"] = genome
    rsrcPath = '/REST/v1/digests';
    payload={}
    payload["data"] = {}
    payload["data"]["text"] = Ext.util.JSON.encode(jsonData);
    Ext.Ajax.request(
  {
    url : '/java-bin/apiCaller.jsp' ,
    timeout : 90000,
    params:
    {
      rsrcPath: rsrcPath,
      apiMethod : 'PUT',
      payload:Ext.util.JSON.encode(payload)
    },
    method: 'POST',
    success: digestSuccessDialog,
    failure: digestFailureDialog
  }) ;
}
