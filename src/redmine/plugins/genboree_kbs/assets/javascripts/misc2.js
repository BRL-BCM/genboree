function seekAndDisplayProp(propPath)
{
  try
  {
    var selModel = Ext.getCmp('mainTreeGrid').getSelectionModel() ;
    selModel.select(0) ;
    var rootProp = selModel.getSelection()[0] ;
    var viewTable = Ext.getCmp('mainTreeGrid').getView() ;
    findRequiredProp(propPath, rootProp, selModel) ;
  }
  catch(err)
  {
    Ext.Msg.alert('ERROR', err) ;
  }
}

function findRequiredProp(propPath, propNode, selModel)
{
  var paths = propPath.split(".") ;
  var prop = paths[0] ;
  var nodeOfInterest = null ;
  if (docModel['name'] == prop) {
    nodeOfInterest = propNode ;
  }
  else{
    var childNodes = propNode.childNodes ;
    var ii ;
    if (prop.match(/^\[/)) {
      var extractIdxRegExp =  /\[\s*(FIRST|LAST|(\d+))\s*\](?:$|\.((?!\.).)*$)/ ;
      var extractedIdx = prop.match(extractIdxRegExp)[1] ;
      if (extractedIdx == 'FIRST') {
        extractedIdx = 0 ;
      }
      else if (extractedIdx == 'LAST') {
        extractedIdx = childNodes.length - 1 ;
      }
      else
      {
        extractedIdx = parseInt(extractedIdx) ;
      }
      nodeOfInterest = childNodes[extractedIdx] ;
      // For items, we don't need to pass along the '[]' part if further recursion is required.
      paths = paths.slice(1, paths.length) ;
    }
    else
    {
      for(ii=0; ii<childNodes.length; ii++){
        if (childNodes[ii].data.name == prop) {
          nodeOfInterest = childNodes[ii] ;
          break ;
        }
      }
    }
  }
  if(nodeOfInterest)
  {
    selModel.select(nodeOfInterest) ;
    nodeOfInterest.expand() ;
    if (paths.length > 1) {
      findRequiredProp(paths.slice(1, paths.length).join("."), nodeOfInterest, selModel )
    }
  }
  else
  {
    throw("Could not find property: "+prop+ " in the provided property path. Please make sure that the property path you provided exists in the document.") ;
  }
}

