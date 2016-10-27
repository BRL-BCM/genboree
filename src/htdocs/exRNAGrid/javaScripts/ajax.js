// Load the store for the document search Combobox
// record values is now hardcoded
// should be fetched from the respective collection model 'name'
function getAnalysisComboStore()
{
 var searchPath = '/REST/v1/grp/'+ gridGrp +'/kb/'+ gridKb +'/coll/' + gridColl + '/docs?' ;
 Ext.define('docBox', {
            extend: 'Ext.data.Model',
            proxy: {
              type: 'ajax',
              url : '/java-bin/apiCaller.jsp?',
              timeout : 90000,
              reader: {
                type: 'json',
                root: 'data',
                record: 'Analysis',
                idProperty: 'value'
              },
              extraParams :{
                rsrcPath : searchPath
              }
            },
            fields: [ {name: 'value'}]
          });

          var documentStore = Ext.create('Ext.data.Store', {
          model: 'docBox'
          });

return documentStore ;
}



//Makes API get response for the table - html content
// format smallHtml || html || largeHtml
function viewGrid(format, documentName)
{
  var message ;
  var respath = '/REST/v1/grp/'+ gridGrp +'/kb/'+ gridKb +'/coll/' + gridColl + '/doc/' +documentName+ '?transform='+trRulesDoc+'&format='+ format + '&showHisto=true';
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
           // makeLargeWindow(gridTable) ; // not a good option for large tables
           viewGridInPanel(gridTable) ;
          }
          else if(format == 'smallhtml')
          {
            makeSmallWindow(gridTable, documentName) ;
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

// get request for the selected document
function fillAnalysisGrid(docName)
{
  var docPath = '/REST/v1/grp/'+ gridGrp +'/kb/'+ gridKb +'/coll/' + gridColl + '/doc/' +docName ;
  Ext.Ajax.request(
  {
    url : '/java-bin/apiCaller.jsp' ,
    timeout : 90000,
    params:
    {
      rsrcPath: docPath,
      apiMethod : 'GET'
    },
    method: 'GET',
    success: getAnalysisData,
    failure: displayFailureDialog
  }) ;
}
