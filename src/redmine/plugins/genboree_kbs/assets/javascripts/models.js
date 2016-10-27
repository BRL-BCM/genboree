
// ------------------------------------------------------------------
// Define accordian data models
// ------------------------------------------------------------------
Ext.define('BrowseRecord',
{
  extend : 'Ext.data.Model',
  fields : [ 'browseFuncName', 'url', 'genbKbIconCls' ]
}) ;
Ext.define('ManageRecords',
{
  extend : 'Ext.data.Model',
  fields : [ 'recordFuncName', 'url', 'genbKbIconCls', 'displayStr' ]
}) ;
Ext.define('ManageModels',
{
  extend : 'Ext.data.Model',
  fields : [ 'modelFuncName', 'url', 'genbKbIconCls' , 'displayStr']
}) ;
Ext.define('Queries',
{
  extend : 'Ext.data.Model',
  fields : [ 'queryFuncName', 'url', 'genbKbIconCls' ]
}) ;
Ext.define('ManageViews',
{
  extend : 'Ext.data.Model',
  fields : [ 'viewFuncName', 'url', 'genbKbIconCls' ]
}) ;
Ext.define('AdminCollections',
{
  extend : 'Ext.data.Model',
  fields : [ 'collectionFuncName', 'category', 'url', 'genbKbIconCls' ]
}) ;

// Data Model for record data
Ext.define('Task', {
    extend: 'Ext.data.Model',
    fields: [
        {name: 'name', type: 'string'},
        {name: 'value', type: 'string'},
        {name: 'domain', type: 'string'},
        {name: 'domainOpts', type: 'auto'},
        {name: 'description', type: 'string'},
        {name: 'editable', type: 'boolean', defaultValue: false},
        {name: 'identifier', type: 'boolean', defaultValue: false},
        {name: 'fixed', type: 'boolean', defaultValue: false},
        {name: 'category', type: 'boolean', defaultValue: false},
        {name: 'docAddress', type: 'auto'},
        {name: 'modelAddress', type: 'auto'},
        {name: 'required', type: 'boolean', defaultValue: false},
        {name: 'id', type: 'string'},
        {name: 'editRequired', type: 'boolean', defaultValue: false} // for displaying template docs
    ]
});



Ext.define('Search', {
    extend: 'Ext.data.Model',
    fields: [
      {name: 'text', type: 'string'}
    ]
});

// ------------------------------------------------------------------
// Model-related Helper Functions
// ------------------------------------------------------------------

function defineModelForModelView(fields)
{
  var fieldsToAdd = [] ;
  var ii ;
  for(ii=0; ii<fields.length; ii++)
  {
    var field = fields[ii] ;
    if(nonCoreFields[field])
    {
      fieldsToAdd.push(nonCoreFields[field]) ;
    }
    else
    {
      fieldsToAdd.push(field) ;
    }
  }
  Ext.define('ModelTree', {
    extend: 'Ext.data.Model',
    fields: fieldsToAdd
  });
}

// Performs basic validation of the model
// Fired when user selects a new collection.
function validateModel(docModelObj)
{
  var error = "" ;
  if(!docModelObj['identifier'])
  {
    error = "BAD MODEL: Model for the selected collection does not have an root-levelidentifier." ;
  }
  else
  {
    if(docModelObj['name'] && /\S/.test(docModelObj['name']))
    {
      error = validateChildNodes(docModelObj) ;
    }
    else
    {
      error = "BAD MODEL: Root property does not have a 'name' field in its property definition."
    }
  }
  return error
}

// Create a new JsonStore to hold any search results for this collection
// - populates the searchStoreData global
// - binds search box to new store
// - enables search box (may be disabled if no collection/model yet, etc)
function createSearchStore(docModelObj)
{
  var retVal = false ;
  // Remove items from existing store, if any
  if(searchStoreData && searchStoreData.removeAll)
  {
    searchStoreData.removeAll() ;
  }
  // What the document id property name? This is the "id" for each row in the search results, which Ext wants to know.
  var docId = docModelObj['name'] ;
  // What is the collections name this query is against?
  var collName = Ext.getCmp('collectionSetCombobox').value ;
  var searchModelName = ( 'DocSearchModel-' + (new Date).getTime() + "-" + Math.ceil(Math.random() * 1024 * 1024) ) ;
  Ext.define(searchModelName, {
    extend : 'Ext.data.Model',
    fields : [ 'value' ]
  }) ;
  // Create new JsonStore backed by ajax proxy
  searchStoreData = new Ext.data.JsonStore(
  {
    storeId : 'searchStore',
    model : searchModelName,
    proxy :
    {
      type    : 'ajax',
      url     : 'genboree_kbs/doc/search',
      timeout : 900000,
      reader :
      {
        type  : 'json',
        root  : 'data',
        record : docId,
        idProperty : 'value'
      },
      // ExtJs ajax proxy can send standard things like page, limit, start/end index, filter, and even extra params
      limitParam  : 'limit',
      filterParam : 'searchStr',
      extraParams :
      {
        coll  : collName,
        project_id : projectId
      }
    }
  }) ;
  // Bind the search box to this new store
  var searchBox = Ext.getCmp('searchComboBox') ;
  searchBox.bindStore(searchStoreData) ;
  searchBox.enable() ;
  retVal = true
  return retVal ;
}


// Helper rescursive function for 'validateModel()'
// Validates children nodes of the root node.
// Also collect list of indexed properties: used for views
function validateChildNodes(prop)
{
  var error = "" ;
  var ii, jj ;
  if (prop['index']) {
    indexedProps.push(prop.name) ;
  }
  if (prop['description'] && prop['description'] != "") {
    prop['description'] = prop['description'].replace(/"/g, "'") ;
  }
  if(prop.properties || prop.items)
  {
    if(prop.properties)
    {
      var props = prop.properties ;
      for(ii=0; ii<props.length; ii++)
      {
        error = validateChildNodes(props[ii]) ;
        if(error != "")
        {
          break ;
        }
      }
    }
    else // Make sure items is singly rooted
    {
      var items = prop.items ;
      if(items.length != 1)
      {
        error = "BAD MODEL: Sub-items MUST have just one property definition because they are homogeneous lists. '" + prop.name + "' is either appears to have more than one sub-item definition in its itms list." ;
      }
      else
      {
        error = validateChildNodes(items[0]) ;
      }
    }
  }
  return error ;
}
