function initRowEditingPlugin()
{
  var rowEditing = Ext.create('Ext.grid.plugin.RowEditing', {
    clicksToEdit: 2,
    id: 'editorGridRowPlugin',
    pluginId: 'rePlugin',
    listeners: {
      edit: function(editor, context, eOpts)
      {
        // Change the value in the document.
        // 'docAdress' points to the object in the actual document
        var propName = context.record.data.name ;
        var propValue = context.record.data.value ;
        if(addingChild)
        {
          if(childType == 'properties')
          {
            if(recordToReplace)
            {
              if(propName != recordToReplace.data.name)
              {
                selectedRecord.replaceChild(recordMap[propName], recordToReplace) ;
              }
              recordToReplace = null ;
            }
            docPropOfSelectedNode[propName] = {'value': propValue } ;
            if(context.record.data.modelAddress.properties)
            {
              docPropOfSelectedNode[propName]['properties'] = {} ;
            }
            else if(context.record.data.modelAddress.items)
            {
              docPropOfSelectedNode[propName]['items'] = [] ;
            }
            else
            {
              // Nothing to do
            }
            context.record.data.docAddress = docPropOfSelectedNode[propName] ;
          }
          else // items
          {
            var newItem = {} ;
            newItem[propName] = {'value': propValue } ;
            if(context.record.data.modelAddress.properties)
            {
              newItem[propName]['properties'] = {} ;
            }
            else if(context.record.data.modelAddress.items)
            {
              newItem[propName]['items'] = [] ;
            }
            else
            {
              // Nothing to do
            }
            // Shove the new record in the items list of the parent node
            if(!docPropOfSelectedNode)
            {
              docPropOfSelectedNode = [] ;
            }
            docPropOfSelectedNode.push(newItem) ;
            context.record.data.docAddress = newItem[propName] ;
            // This is required because for some reason the newly added 'item' does not automatically become the selected record as is the case for properties.
            // To-do: need to figure out why...
            selectedRecord = context.record ; 
          }
          addingChild = false ;
          // Add the domain info for the record that was just added
          var domainEls = getDomainInfo(context.record.data.modelAddress) ;
          context.record.data.domain = domainEls[0] ;
          context.record.data.domainOpts = domainEls[1] ;
          // Create required children nodes
          if(context.record.data.modelAddress.properties)
          {
            var children = addSubChildrenForNewDocument(context.record.data.modelAddress, context.record.data.docAddress) ; 
            insertChildNode(context.record, children) ;
          }
        }
        else
        {
          context.record.data.docAddress['value'] = context.record.data.value ;
        }
        // Make the first column un-editable for future row editing operations.
        context.record.data.editable = false ;
        // Enable the save btn
        toggleBtn('saveDoc', 'enable') ;
        documentEdited = true ;
        var mainTreeObj = Ext.getCmp('mainTreeGrid') ;
        mainTreeObj.setTitle(getModifiedTitle(true)) ;
        // Do a node interface operation just to refresh the column rendering since I do not know how else to rerender the Value column
        // Just calling the renderer() function for the second column DOES NOT work! (Maybe something else listens to the renderer() and performs required updates depending on what it returns)
        // This is required for URL type values which need to show the hyperlink immediately after the editing is finished.
        // This just replaces the recently edited record with itself, i.e, a No-OP
        context.record.parentNode.replaceChild(context.record, context.record) ;
        dirtyRecords[context.record.id] = context.record ;
        if(!freshDocument)
        {
          toggleBtn('discardChanges', 'enable') ;
        }
      }
      ,
      canceledit: function(editor, context, eOpts)
      {
        // Remove newly added record from tree
        if(addingChild)
        {
          var parentNode = context.record.parentNode ;
          parentNode.removeChild(context.record) ;
          addingChild = false ;
        }
      },
      beforeedit: function(editor, context, eOpts)
      {
        // If the user is trying to edit the identifier, display a warning message
        if(editModeValue && !freshDocument && context.record.data['identifier'])
        {
          Ext.Msg.alert('Warning', 'You are changing the identifier value of the document. Once saved with the updated identifier value, this document will no longer be referable by the existing identifier value.') ;
        }
        var attrCM = context.grid.columns[0] ;
        var origWidthCM = attrCM.getWidth() ;
        var valCM = context.grid.columns[1] ;
        var origWidthVal = valCM.getWidth() ;
        var fieldName       = context.record.data['name'] ;
        var fieldDefaultVal = context.record.data['value'] ;
        var fieldDomain     = context.record.data['domain'] ;
        var fieldDomainOpts = context.record.data['domainOpts'] ;
        var fieldEditable   = context.record.data['editable'] ;
        var valueFixed      = context.record.data['fixed'] ;
        var textFieldObj ;
        if(!addingChild)
        {
          attrCM.setEditor({ xtype: 'textfield'}) ;
        }
        updateEditor(fieldDomain, fieldDomainOpts) ; // defined in misc.js
        var valueEditor = valCM.getEditor() ;
        attrCM.getEditor().setWidth(origWidthCM) ;
        valueEditor.setWidth(origWidthVal) ;
        // disable the tree column if its not part of  a 'new' record
        if(fieldEditable)
        {
          this.editor.form.findField('name').enable() ;
        }
        else
        {
          this.editor.form.findField('name').disable() ;  
        }
        if(valueFixed)
        {
          this.editor.form.findField('value').disable() ;
        }
        else
        {
          this.editor.form.findField('value').enable() ;
        }
        return editModeValue ;
      }
    }
  }) ;
  return rowEditing ;
}

// Recursively appends child nodes to given node
// This is required since appending nested children nodes doesn't seem to work
function insertChildNode(node, children)
{
  var ii ;
  for(ii=0; ii<children.length; ii++)
  {
    if(children[ii].children && children[ii].children.length > 0)
    {
      var subchildren = children[ii].children ;
      children[ii].children = [] ;
      var insertedNode = node.appendChild(children[ii]) ;
      insertChildNode(insertedNode, subchildren) ;
    }
    else
    {
      node.appendChild(children[ii]) ;  
    }
  }
}