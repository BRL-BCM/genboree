//
// Uses extjs library
//

// Declare a namespace...this is global in whole page from now on
Ext.namespace('Ext.genboree');

// Put page-specific stuff in this namespace.
// We will coordinate certain variables and behaviors through this namespace.
// Can refer to this namespace within .js file that follow this one or on the
// page itself.
//
// NOTE: this namespace requires two global javascript variables be defined on
// the JSP/html page:
// (a) tooFewForMenuBtn
// (b) tooManyForMenuBtn
Ext.genboree = function()
{
  var annoRecords = [] ; // Array of objects with uploadId and fid properties. Filled in by JSP.
  var lastRecordClicked = null ; // Keeps track of what record last had its Edit button clicked (actually the little menu arrow)
  var delayExec = null ; // Stores a Prototype PeriodicExecutor object so can delay adding the Edit buttons when there are lots

  // Namespace Functions:
  // Return a hash of named-functions for adding a new record or getting the whole reocrd array
  return  {
            addRecord: function(uploadId, fid) // add a record to annoRecords
            {
              annoRecords.push(
                                {
                                  uploadId: uploadId,
                                  fid: fid
                                }
                             );
              return ;
            },
            getRecords: function() // get annoRecords Array
            {
              return annoRecords ;
            },
            setLastRec: function(recNum) // set last record clicked for later referral
            {
              return lastRecordClicked = recNum ;
            },
            getLastRec: function() // get the last record clicked
            {
              return lastRecordClicked ;
            },
            setDelayExec: function(pe) // set the PeriodicalExecution object for later referral
            {
              return delayExec = pe ;
            },
            getDelayExec: function() // get the PeriodiclExecution object
            {
              return delayExec ;
            },
            init: function()
            {
              if(annoRecords.length >= tooFewForMenuBtn && annoRecords.length <= tooManyForMenuBtn) // Then we'll be using a page-load mask. Else not needed or too many anyway and we do something else

              {
                // For the page initialization mask
                var loading = Ext.get('genboree-loading'); // Name of page loading div
                var mask = Ext.get('genboree-loading-mask'); // Name of page loading mask div
                mask.setOpacity(0.5);
                mask.shift(
                            {
                              remove: true,
                              duration: 1,
                              opacity: 0.3,
                              callback:   function()
                                          {
                                            loading.fadeOut( { duration: 0.2, remove: true} );
                                          }
                            });
              }
            }
          };
}();

// Register initialization of namespace once page fully loads.
Ext.onReady(Ext.genboree.init, Ext.genboree, true);

// Register a periodical executor (from Prototype) with the page.
// This allows the page mask above to be displayed if needed.
//
// NOTE: this namespace requires two global javascript variables be defined on
// the JSP/html page:
// (a) tooFewForMenuBtn
// (b) tooManyForMenuBtn
Ext.onReady(
  function()
  {
    var recs = Ext.genboree.getRecords() ;
    if(recs.length <= tooManyForMenuBtn) // if too many, we will use a link to the edit menu page
    {
      Ext.genboree.setDelayExec(new PeriodicalExecuter(addEditButtons, 0.1)) ;
    }
  }
);

// Add Edit buttons to each <div> we set aside on the page
// NOTE: If there is a global 'groupMode' variable (say, on the jsp including this file)
// set to non-null, non-false, then this function will ONLY display group-editing edit items.
// Otherwise, if there is no such variable, then all edit items.
function addEditButtons()
{
  // Create a single menu object that will get reused in each MenuButton
  var groupItemsOnly = ((typeof(groupMode) != 'undefined') && (groupMode)) ;
  var menuItems = new Array() ;
  // Add the link to the edit menu page first
  menuItems.push(
                  {
                    text: 'Edit Menu Page ', handler: onItemClick, actionVal: 'menu'
                  }
                ) ;
  // Unless group mode, add the individual edit links
  if(!groupItemsOnly)
  {
    menuItems.push(
                    '-',
                    {
                      text: '(Re)Assign Anno.', handler: onItemClick, actionVal: 'assign'
                    },
                    {
                      text: 'Create Anno.', handler: onItemClick, actionVal: 'create'
                    },
                    {
                      text: 'Delete Anno.', handler: onItemClick, actionVal: 'delete'
                    },
                    {
                      text: 'Duplicate Anno.', handler: onItemClick, actionVal: 'duplicate'
                    },
                    {
                      text: 'Edit Anno.', handler: onItemClick, actionVal: 'edit'
                    },
                    {
                      text: 'Shift Anno.', handler: onItemClick, actionVal: 'shift'
                    }
                  ) ;
  }
  // Regardless, add the group edit links
  menuItems.push(
                  '-',
                  {
                    text: '(Re)Assign Group ', handler: onItemClick, actionVal: 'assignGroup'
                  },
                  {
                    text: 'Delete Group ', handler: onItemClick, actionVal: 'deleteGroup'
                  },
                  {
                    text: 'Duplicate Group ', handler: onItemClick, actionVal: 'duplicateGroup'
                  },
                  {
                    text: 'Edit Group ', handler: onItemClick, actionVal: 'editGroup'
                  },
                  {
                    text: 'Rename Group ', handler: onItemClick, actionVal: 'renameGroup'
                  },
                  {
                    text: 'Shift Group ', handler: onItemClick, actionVal: 'shiftGroup'
                  },
                  {
                    text: 'Set Group Color ', handler: onItemClick, actionVal: 'colorGroup'
                  },
                  '-',
                  {
                    text: 'Add Attributes to Group ', handler: onItemClick, actionVal: 'addAttrGroup'
                  },
                  {
                    text: 'Add Comments to Group ', handler: onItemClick, actionVal: 'addCommGroup'
                  }
                ) ;
  // Now create menu object using the menuItems array
  var menu =  new Ext.menu.Menu(
              {
                items: menuItems
              }) ;
  // For each annotation record in Ext.genboree.getRecords,
  // add an appropriate edit button to the correct <div>
  var recs = Ext.genboree.getRecords() ;
  for(var ii=0; ii<recs.length; ii++)
  {
    // Name of the correct <div>
    var btnDivName = 'editBtnDiv_' + ii ;

    // Create the button and put it the <div> (but only if we can find the right div!)
    if(Ext.get(btnDivName))
    {
      var btnActionStr = (groupItemsOnly ? 'editGroupBtn' : 'editBtn') ;
      var sb =  new Ext.MenuButton(
                  btnDivName,
                  {
                    text: '<span class="x-btn-text-span">Edit</span>',
                    handler: onItemClick,
                    arrowHandler: onMenuArrowClick, // we need this to record which record's arrow was clicked (so we know what record the menu item is evoked for)
                    actionVal: btnActionStr,
                    cls: 'x-btn-text-icon blist',
                    menu: menu
                  }
                ) ;
    }
  }

  // Record the index of the record whose arrow was clicked.
  // When a menu item is clicked (after this), we will have saved the correct record's index
  // so we can retrieve it from Ext.genboree.
  function onMenuArrowClick(btn)
  {
    var editDiv = btn.getEl().findParentNode('div.editBtnDiv') ; // This gets the editBtnDiv we set aside for the MenuButton
    var recNum = editDiv.id.split('_')[1] ;
    Ext.genboree.setLastRec(recNum) ;
  }

  // Handler: When a menu item is click or when the button is clicked, open the correct editor tool page.
  function onItemClick(btn)
  {
    var actionStr = btn.actionVal ;
    // If the button itself (not the arrow) was clicked, look for this and set the record index accordingly.
    if(actionStr.match(/Btn$/))
    {
      var editDiv = btn.getEl().findParentNode('div.editBtnDiv') ;
      var recNum = editDiv.id.split('_')[1] ;
      Ext.genboree.setLastRec(recNum) ;
    }
    // else menu arrow already clicked as recNum was set then

    // Retrieve the index of the last clicked record from Ext.genboree
    var idx = Ext.genboree.getLastRec() ;
    // Get the anno. record with the needed info to make a new window.location
    var records = Ext.genboree.getRecords() ;
    var annoRec = records[idx] ;
    // Use record to make correct upfid= name-value pair
    var upfidStr = '?upfid=' + annoRec.uploadId + ":" + annoRec.fid ;
    // Dispatch to correct page based on which button was clicked.
    switch(actionStr)
    {
      case 'menu':
        newWin('/java-bin/annotationEditorMenu.jsp' + upfidStr, null) ;
        break ;
      case 'editBtn':
      case 'edit':
        newWin('/java-bin/annotationEditor.jsp' + upfidStr, null) ;
        break ;
      case 'assign':
        newWin('/java-bin/reassignAnnotation.jsp' + upfidStr, null) ;
        break ;
      case 'create':
        newWin('/java-bin/createAnnotation.jsp' + upfidStr, null) ;
        break ;
      case 'delete':
        newWin('/java-bin/delAnnotationEditor.jsp' + upfidStr, null) ;
        break ;
      case 'duplicate':
        newWin('/java-bin/duplicateAnnotation.jsp' + upfidStr, null) ;
        break ;
      case 'shift':
        newWin('/java-bin/annotationShift.jsp' + upfidStr, null) ;
        break ;
      case 'editGroupBtn':
      case 'editGroup':
        newWin('/java-bin/annotationGroupEditor.jsp' + upfidStr, null) ;
        break ;
      case 'assignGroup':
        newWin('/java-bin/reassignGroupAnnotation.jsp' + upfidStr, null) ;
        break ;
      case 'deleteGroup':
        newWin('/java-bin/delAnnotationGroup.jsp' + upfidStr, null) ;
        break ;
      case 'duplicateGroup':
        newWin('/java-bin/duplicateGroupAnnotation.jsp' + upfidStr, null) ;
        break ;
      case 'renameGroup':
        newWin('/java-bin/renameGroupAnnotation.jsp' + upfidStr, null) ;
        break ;
      case 'shiftGroup':
        newWin('/java-bin/annotationGroupShift.jsp' + upfidStr, null) ;
        break ;
      case 'colorGroup':
        newWin('/java-bin/changeGroupColor.jsp' + upfidStr, null) ;
        break ;
      case 'addAttrGroup':
        newWin('/java-bin/addGroupAVP.jsp' + upfidStr, null) ;
        break ;
      case 'addCommGroup':
        newWin('/java-bin/commentGroupAnnotations.jsp' + upfidStr, null) ;
        break ;
    }
  };
  // Make sure this setup function is only run ONCE. Turn off PeriodicalExecutor.
  var pe = Ext.genboree.getDelayExec() ;
  pe.stop() ;
  // Remove mask now that we are set up.
  var bt = Ext.Element.get(document.body) ;
  if(bt.isMasked())
  {
    bt.unmask() ;
  }
}

// --------------------------------------------------------------------------
// HELPERS
// -------------------------------------------------------------------------
var trgWinHdl = null ;
function newWin(trgWinUrl, trgWinName) // This will do the actual popping up when the link is clicked
{
  if(!trgWinName)
  {
    trgWinName = '_newWin' ;
  }
  if(!trgWinHdl || trgWinHdl.closed)
  {
    trgWinHdl = window.open(trgWinUrl, trgWinName, '');
  }
  else
  {
    // winHandle not null AND not closed
    trgWinHdl.location = trgWinUrl;
  }

  if(trgWinHdl && window.focus)
  {
    trgWinHdl.focus() ;
  }
  return false ;
}
