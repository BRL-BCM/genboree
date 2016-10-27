//Makes API get response for the table - html content
// format smallHtml || html || largeHtml
function viewGrid(format, documentName, histo)
{
  if(histo)
  {
    var respath = '/REST/v1/grp/'+ gridGrp +'/kb/'+ gridKb +'/coll/' + gridColl + '/doc/' +documentName+ '?transform=http://' + location.host + '&graph=histo&format='+ format ;
  }
  else
  {
    var respath = '/REST/v1/grp/'+ gridGrp +'/kb/'+ gridKb +'/coll/' + gridColl + '/doc/' +documentName+ '?transform=http://' + location.host + '&format='+ format + '&gridType=' + gridType ;
  }  
  Ext.Ajax.request(
  {
    url : '/java-bin/apiCaller.jsp' ,
    timeout : 90000,
    method: 'GET',
    params:
    { 
      rsrcPath : respath, 
      apiMethod : 'GET'
    },
    //callback: function(result, response)
    callback: function(opts, success, response)
    {
        var gridTable = response.responseText ;
        if(response.status >= 200 && response.status < 400 && gridTable)
        {
         if(format == 'html' || histo)
         {
           simplePanel(gridTable) ;
         }
         else
         {
           simplePanel(gridTable) ;
         }
        }
        else
        {
          Ext.Msg.alert("ERROR", "API Failed to get the gridView data " + response.status + ', ' + response.statusText) ;
        }
    }
  }) ;
  return gridTable ; 
}
