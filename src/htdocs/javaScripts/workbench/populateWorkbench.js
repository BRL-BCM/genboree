// functions specific to populating the workbench panels (Input Data and Output Targets)
// automatically (from an external source).
// For example, Atlas grid is an external source.
// The urls that are to be populated should be available from a global
// variable, posted from the respective source to workbench.jsp

function popWorkbenchNow()

{

  if(popWorkbench.populateOutputs)
  {
    populateWb(popWorkbench.populateOutputs, Ext.getCmp('wbOutputsTree')) ;
  }

  if(popWorkbench.populateInputs)
  {
   populateWb(popWorkbench.populateInputs, Ext.getCmp('wbInputsTree')) ;
  }

}


function populateWb(inputs, tree)
{ 
   var rsClass = {
    grp: 'wbGrpTreeNode',
    db: 'wbDbTreeNode',
    prj: 'wbPrjTreeNode',
    trk: 'wbTrackTreeNode'
  } ;
  var entities = inputs.split(',') ;

  for(var ent=0; ent<entities.length; ent++)
    {
      var data = {}
       var splitRes = entities[ent].split("/") ;
       data.node = {
         // This is not correct REVISIT!!!!!!!!!!!!!!!!1
         id : 'xnode-' + ent,
         text: decodeURIComponent(getEntityName(entities[ent])),
         leaf: true,
         attributes: {
           rsrcType : splitRes[splitRes.length-2],
           refsUri : entities[ent]+'?',
           detailsPath : entities[ent]+'?detailed=ooMaxDetails',
           iconCls: rsClass[splitRes[splitRes.length-2]]
       }
      };
      //var inputsTree = Ext.getCmp('wbInputsTree') ;
      inputsOnDrop(null, null, data, tree) ;

    }

}

function inputsOnDrop(source, e, data, tree)
{
  var root = tree.root ;
  // Check if this node is already in the tree
  if(!root.findChild("id", data.node.id))
  {
    // Not already in tree - create a new node
    var newNode = new Ext.tree.TreeNode(
    {
      id: data.node.id,
      text: data.node.text,
      draggable: true,
      allowDrop: false,
      leaf: data.node.leaf
    } ) ;
    // Add some data to the node for further operations
    // We need refsUri, rsrcType
    if(data.node.attributes.refsUri == undefined)
    {
      alert('refsUri is undefined');
      return false;
    }
    else
    {
      newNode.attributes.rsrcType = data.node.attributes.rsrcType;
      newNode.attributes.refsUri = data.node.attributes.refsUri;
      newNode.attributes.detailsPath = data.node.attributes.detailsPath;
      newNode.attributes.iconCls = data.node.attributes.iconCls;
    }
    /**
     * Check whether the node already exists in tree.
     * Do this by checking the ref URI
     */
    var existsInTree = false;
    if(root.hasChildNodes())
    {
      root.eachChild( function(n)
      {
        if(newNode.attributes.refsUri == n.attributes.refsUri)
        {
          existsInTree = true ;
        }
      }) ;
    }
    if(existsInTree)
    {
      return false ;
    }
    // Check if this is an insert or an append
      root.appendChild(newNode) ;
  }
  else
  {
    return false ;
  }
  updateWorkbenchObj() ;
  toggleToolsByRules() ;
  return true ;
} 

 function getEntityName(uri)
  {
    var retVal = '' ;
    if(uri)
    {
      qsIndex = uri.indexOf('?') ;
      partialUri = (qsIndex >= 0 ? uri.slice(0, qsIndex) : uri) ;
      match = partialUri.match(/\/([^\/]+)$/)
      if(match)
      {
        retVal = match[1] ;
      }
    }
    return retVal ;
  }

