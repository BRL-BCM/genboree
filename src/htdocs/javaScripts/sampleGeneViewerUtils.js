entityType = "sample";


function handleQuery(qEvent)
{
  qEvent.query += '%';
}


function generateURL() {
  var jsonColl = {};
  jsonColl["geneNames"] = geneNames;
  jsonColl["geneDetails"] = Ext.util.JSON.encode(geneDetails);
  jsonColl["dbList"] = Ext.util.JSON.encode(dbList);
  jsonColl["yattr"] = yattr;
  jsonColl["xattr"] = xattr;
  jsonColl["roiTrack"] = roiTrack;
  jsonColl["yattrVals"] = Ext.util.JSON.encode(yattrVals);
  jsonColl["xattrVals"] = Ext.util.JSON.encode(xattrVals);
  if(templateGeneInfo){jsonColl["templateGeneInfo"] = Ext.util.JSON.encode(templateGeneInfo);}
  Ext.Ajax.request({
    url: '/epigenomeatlas/textDigester.rhtml',
    params: {
      digestString: Ext.util.JSON.encode(jsonColl)
    },
    method: 'POST',
    success: urlSuccess,
    failure: handleFailure
  });
}


// Create a new ExtJS combobox which serves as the drop down box for gene selection
function createComboBox(numSuffix) {
  return new Ext.form.ComboBox({
    store: ds,
    displayField: 'text',
    queryParam: 'pattern',
    forceSelect: true,
    loadingText: 'Searching...',
    fieldLabel: mbwAnnotationType,
    //tpl: resultTpl,
    triggerAction: 'query',
    preventMark:true,
    width: 100,
    listEmptyText: 'No matching '+mbwAnnotationType+' found',
    title: mbwAnnotationType+' List',
    shadow: 'drop',
    minChars: 1,
    allowBlank: false,
    id: "searchBox_" + numSuffix,
    triggerConfig: {
      tag: "img",
      src: Ext.BLANK_IMAGE_URL,
      cls: this.triggerClass
    },
    listeners: {
      select: handleSelect,
      beforequery:handleQuery
    }
  });
}

function handleSelect(combo, record, index) {
  var comboIndex = combo.id.split(/_/)[1];
  var geneName = record.data.text;
  geneNames[comboIndex] = geneName;
  getApplyRefresh(geneName,comboIndex);
}


function downloadGeneElementData(item) {
  var geneStrings = [];
  var trackStrings = [];
  var configStrings = [];
  for (var ii = 0; ii <= geneNames.length - 1; ii++) {
    if (geneNames[ii] != 0 && geneNames[ii] != '') {
      geneStrings.push(fullEscape(geneNames[ii]));
      configStrings.push(writeOutJSON(ii));
    }
  }

  if (geneStrings.length > 0) {
    var myForm = document.createElement("form");
    myForm.method = "post";
    myForm.action = "/epigenomeatlas/multiGeneElementScores.rhtml";
    formAppend(myForm,document.createElement("input") ,"geneNames", geneStrings.join(","));
    formAppend(myForm,document.createElement("input") ,"dbList", Ext.util.JSON.encode(dbList));
    formAppend(myForm,document.createElement("input") ,"yattrVals", Ext.util.JSON.encode(yattrVals));
    formAppend(myForm,document.createElement("input") ,"xattrVals", Ext.util.JSON.encode(xattrVals));
    formAppend(myForm,document.createElement("input") ,"gbGridYAttr", yattr);
    formAppend(myForm,document.createElement("input") ,"gbGridXAttr", xattr);
    formAppend(myForm,document.createElement("input") ,"format", item.text.replace(/\./,""));
    formAppend(myForm,document.createElement("input") ,"config", Ext.util.JSON.encode(configStrings));
    formAppend(myForm,document.createElement("input") ,"roiTrack", roiTrack);
    formAppend(myForm,document.createElement("input") ,"userId", userId);
    document.body.appendChild(myForm);
    myForm.submit();
    document.body.removeChild(myForm);
  } else {
    Ext.MessageBox.show({
      title: 'No Genes Entered',
      msg: "Atleast one gene must be chosen to view track data",
      buttons: Ext.MessageBox.OK,
      cls: "wbDialogAlert",
      ctCls: "wbDialogAlert"
    });
  }
}
