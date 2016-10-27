//
// Uses extjs & prototype library
// Assumes a global "pageContents" data structure variable is present
//
// --------------------------------------------------------------------------
// DESCRIPTION
// --------------------------------------------------------------------------
// This code handles widget creation and their event handlers for dynamic
// elements of the project page editor UI.

// --------------------------------------------------------------------------
// SELECTED EVENT FLOWS
// --------------------------------------------------------------------------
// A) INIT
// ^^^^^^^
// => Ext.genboree.init()
//    => Ext.genboree.initFormPanels()
//       => createEditForm(componentType) // For each componentType

// A) EDIT HANDLE CLICKED
// ^^^^^^^^^^^^^^^^^^^^^^
// => Ext.genboree.editHandleClicked(evtObject, event)
//    A.1) Simple Text Component Handle Clicked (show edit dialog right away)
//         => clearItemSelectionMode()
//            - clears Ext.genboree.currComponentType & Ext.genboree.currIconType
//            => clearActionIcons()
//               - clears Ext.genboree.currIconType
//            => removeSelectableDivListeners()
//            => removeSelectableDivClasses()
//         - set Ext.genboree.currComponentType
//         => Ext.genboree.promptForEdit(componentType) (show the edit dialog--a simple one if called here)
//            => getPageContentObjectIndex(componentType, objectId)
//               - objectId is empty when called from here for simple edit dialogs...this method returns null
//            A.1.1) Add/Edit a Component:
//                   => fillEditForm(compontentType, dataObjectIdx)
//                      - get Ext.genboree.currIconType
//                   => fillHtmlEditor(componentType, dataObjectIdx)
//                      - get Ext.genboree.currIconType
//                   - expand/collapse dialog region to show correct dialog for componentType
//                   - show the dialog
//            A.1.2) Delete a Component:
//                   - show simple confirm delete dialog
//
//    A.2) Complex Component Handle Clicked (show edit toolbar)
//         => clearItemSelectionMode(toolBarElem) // If the toolbar for this componentType is already showing
//            - clears Ext.genboree.currComponentType & Ext.genboree.currIconType
//            => clearActionIcons()
//               - clears Ext.genboree.currIconType
//            => removeSelectableDivListeners()
//            => removeSelectableDivClasses()
//            - hide all toolbars, then re-show toolBarElem
//         |> clearItemSelectionMode() // If the toolbar for this componentType is NOT showing already
//            - clears Ext.genboree.currComponentType & Ext.genboree.currIconType
//            => clearActionIcons()
//               - clears Ext.genboree.currIconType
//            => removeSelectableDivListeners()
//            => removeSelectableDivClasses()
//         - set Ext.genboree.currComponentType
//         - shows a toolbar

// B) TOOLBAR BUTTON CLICKED (activate add/edit/delete)
// ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
// => toolBarBtnDispatcher(iconType, componentType, theBtn)
//    => clearActionIcons() // clear any active toolbar button stylings
//    - set the clicked toolbar button's stylings
//    - activate crosshair cursor
//    => activateComponentSelection(iconType, componentType)
//       - save Ext.genboree.currComponentType & Ext.genboree.currIconType
//       => removeSelectableDivListeners() // remove any existing listeners for previous component selections
//       => removeSelectableDivClasses() // remove any existing stylings for previous component selections
//       - add stylings and listeners to the component divs for componentType
//       - if it's an 'add' then also activate the parent div containing the component divs so can add at end of list

// C) ADD/EDIT DIALOG BUTTON CLICKED: (Submit/Cancel/Yes/No)
// ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
// => dialogBtnDispatcher(btn, evt, theDialog)
//    - get Ext.genboree.currComponentType & Ext.genboree.currDataObjectIdx
//    - get btnText (Submit or Cancel from btn) if available (for Yes/No confirm dialog, btn contains just the text 'Yes' or 'No)
//    |> Submit
//       |> updateSimpleHtmlContent(theDialog) // for straight text components
//          - get Ext.genboree.currComponentType
//          - get info from htmlEditor
//          => submitUpdate(componentType, JSONtext)
//       |> updateComplexComponent(theDialog, dataObjectIdx) // for complex components
//          - get Ext.genboree.currComponentType & Ext.genboree.currIconType
//          - get info from appropriate form fields and/or htmlEditor
//          => submitUpdate(componentType, JSONtext)
//    |> Yes or yes
//       - from a simple confirm dialog (just delete uses that right now)
//       |> deleteDataObject(componentType, dataObjectIdx)
//          => submitUpdate(componentType, JSONtext)
//    |> No or no
//       - from a simple confirm dialog (just delete uses that right now)
//       - do nothing
//    |> else must be a Cancel or something
//       = > closeDialogIfUserConfirms(theDialog, btn)
//    => clearItemSelectionMode() // clear any component selection listeners and stylings
//       - clears Ext.genboree.currIconType & Ext.genboree.currComponentType
//    - stop event bubbling further, we're done
//
// D) COMPONENT/ITEM CLICKED (selected for edit/delete): Ext.genboree.itemClicked(evt, theDiv)
// ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
// => Ext.genboree.itemClicked(evt, theDiv)
//    => Ext.genboree.promptForEdit(componentType, objectId) // show appropriate dialog (complex one if called here)
//       => getPageContentObjectIndex(componentType, objectId)
//          - returns index of selected component
//       - save current component index in Ext.genboree.currDataObjectIdx
//       D.1.1) Add/Edit a Component:
//              => fillEditForm(compontentType, dataObjectIdx)
//                 - get Ext.genboree.currIconType
//              => fillHtmlEditor(componentType, dataObjectIdx)
//                 - get Ext.genboree.currIconType
//              - expand/collapse dialog region to show correct dialog for componentType
//              - show the dialog
//       D.1.2) Delete a Component:
//              - show simple confirm delete dialog
//
// --------------------------------------------------------------------------
// PAGE GLOBALS
// --------------------------------------------------------------------------
var dialogTitlesById = {
  projectTitleImg: "Set the Project's Title Image",
  projectTitle: "Edit Project Title",
  projectDesc: "Edit Project Description",
  projectContent: "Edit Extra Content",
  projectQuickLinks: "Quick Links",
  projectNews: "News",
  projectCustomLinks: "Custom Links",
  projectFiles: "Documents &amp; Files"
} ;

var itemDivClassById = {
  projectTitleImg: "",
  projectTitle: "",
  projectDesc: "",
  projectContent: "",
  projectQuickLinks: "projectQuickLink",
  projectNews: "projectNews",
  projectCustomLinks: "projectCustomLink",
  projectFiles: "projectFile"
} ;


// --------------------------------------------------------------------------
// EXTJS SETUP
// --------------------------------------------------------------------------
// Declare a namespace...this is global in whole page from now on
Ext.namespace('Ext.genboree');

// Put page-specific stuff in this namespace.
// We will coordinate certain variables and behaviors through this namespace.
// Can refer to this namespace within .js file that follow this one or on the
// page itself.
//
// NOTE: this namespace requires two global javascript variables be defined on
// the JSP/html page:
// - isEditMode (boolean)
// - pageContents (hash of keys to data file contents)
Ext.genboree = function()
{
  // STATE VARIABLES
  var dialog ; // The dialog for add/edit components
  var dialogSubmitBtn ;
  var dialogCloseBtn ;
  var activeDialog ;
  var formPanels ; // The hash of formPanels for each component type (added in North region)
  var forms ;  // The hash of forms for each component type
  var htmlEditor ;
  var currIconType ;
  var currComponentType ;
  var currDataObjectIdx ;

/**
 * Configuration for progress bar
 *  barMaxWidth
 *  progressUrl
 *
 */
  var progressIntervalObj ; // Used for managing the upload progress requests
  var lastReceivedSize = 0;
  var sameSizeCount = 0;
  var statusUpdateInterval = 2000 /* milliseconds */
  var activityTimeOut = 60000 /* milliseconds */


  // NAMESPACE FUNCTIONS
  // Return a hash of named-functions for altering state and such
  return  {
    dialog: function(aDialog)
    {
      return (aDialog ? dialog = aDialog : dialog) ;
    },
    activeDialog: function(actDialog)
    {
      return (actDialog ? activeDialog = actDialog : activeDialog) ;
    },
    formPanels: function()
    {
      return formPanels ;
    },
    forms: function()
    {
      return forms ;
    },
    htmlEditor: function(anHtmlEditor)
    {
      return (anHtmlEditor ? htmlEditor = anHtmlEditor : htmlEditor) ;
    },
    currIconType: function(anIconType)
    {
      return (anIconType ? currIconType = anIconType : currIconType) ;
    },
    currComponentType: function(componentType)
    {
      return (componentType ? currComponentType = componentType : currComponentType) ;
    },
    currDataObjectIdx: function(aDataObjectIdx)
    {
      return (aDataObjectIdx ? currDataObjectIdx = aDataObjectIdx : currDataObjectIdx) ;
    },
    srcEditBtn: function()
    {
      var retVal = null ;
      if(htmlEditor)
      {
        var tb = htmlEditor.tb ;
        var srcEditIdx = tb.items.keys.indexOf('sourceedit') ;
        retVal = tb.items.items[srcEditIdx] ;
      }
      return retVal ;
    },
    init: function()
    {
      // Initialize namespace variables
      currComponentType = currIconType = null ;
      formPanels = {} ;
      forms = {} ;
      dialog = dialogSubmitBtn = dialogCloseBtn = activeDialog = htmlEditor = null ;
      Ext.QuickTips.init() ;
      // Turn on ExtJS-mediated validation errors beside the field globally
      Ext.form.Field.prototype.msgTarget = 'side' ;
      // ---------------------------------
      // Display edit handles for each component type
      // ---------------------------------
      if(isEditMode)
      {
        var editButtonDivs = Ext.select('div.editButtonDiv', true, 'pageContentTd') ;
        editButtonDivs.on('click', Ext.genboree.editHandleClicked) ;
        var editToolBarBtnDivs = Ext.select('div.editToolBarButtonDiv', true, 'pageContentTd') ;
        editToolBarBtnDivs.on('click', Ext.genboree.editHandleClicked) ;
      }
      if(Ext.isOpera) // Opera has a couple of issues creating new elements. Gets confused about where the browser should scroll to after loading, so it jumps to the bottom.
      {
        Ext.get(document.body.firstChild).scrollIntoView() ;
      }
      return ;
    },
    initDialog: function()
    {
      if(!dialog)
      {
        dialog = new Ext.LayoutDialog('editorDialog',
                                      {
                                        autoCreate: true,
                                        modal: true,
                                        collapsible: false,
                                        //resizable: false,
                                        width: 580,
                                        height: 280,
                                        shadow: true,
                                        minWidth: 300,
                                        minHeight: 50,
                                        proxyDrag: true,
                                        north: // extra form elements go here
                                        {
                                          animate: false,
                                          split: false,
                                          initialSize: 75,
                                          animate: false,
                                          titlebar: false,
                                          alwaysShowTabs: false,
                                          diableTabTips: true,
                                          hideTabs: true,
                                          preservePanels: true,
                                          collapsible: true,
                                          margins:
                                          {
                                            top: 1,
                                            left: 1,
                                            right: 1,
                                            bottom: 1
                                          }
                                        },
                                        center: // htmlEditor goes here
                                        {
                                          animate: false,
                                          split: false,
                                          autoScroll: true,
                                          animate: false,
                                          titlebar: false,
                                          alwaysShowTabs: false,
                                          diableTabTips: true,
                                          hideTabs: true,
                                          collapsible: true
                                        },
                                        listeners:
                                        {
                                          'resize': function(component)
                                                    {
                                                      if(component.northOnly) // Make north take up whole thing
                                                      {
                                                        Ext.genboree.showNorthOnly() ;
                                                      }
                                                      else // Adjust htmlEditor appropriately
                                                      {
                                                        Ext.genboree.resizeHtmlEditor() ;
                                                      }
                                                      return true ;
                                                    }
                                        }
                                      }) ;
        // Special property to handle resize when only want North
        dialog.northOnly = false ;
        dialog.northRegionSize = 0 ;
        layout = dialog.getLayout() ;
        layout.beginUpdate() ;
        // Add Submit button to dialog
        dialogSubmitBtn = dialog.addButton( 'Submit',
                                            function(btn, evt, theDialog) // Handler normally only called with btn and evt args...we're adding 2 more args which we'll call with dialog
                                            {
                                              dialogBtnDispatcher(btn, evt, theDialog) ;
                                            }.createDelegate(this, [dialog], true) ) ;
        // Add Cancel button to dialog
        dialogCloseBtn = dialog.addButton('Cancel',
                                          function(btn, evt, theDialog)
                                          {
                                            dialogBtnDispatcher(btn, evt, theDialog) ;
                                          }.createDelegate(this, [dialog], true) ) ;
        // Esc key closes dialog
        dialog.addKeyListener(27, dialog.hide, dialog) ;
        layout.endUpdate() ;
      }
      // ---------------------------------
      // Init reusable HTML editor
      // ---------------------------------
      if(!htmlEditor)
      {
        // Add the htmlEditor to a panel in the Center region
        var htmlPanel = new Ext.ContentPanel( 'htmlPanel',
                                              {
                                                autoScroll: false,
                                                autoCreate: true,
                                                fitToFrame: true,
                                                fitContainer: true,
                                                closeOnTab: false,
                                                closable: false,
                                                alwaysShowTabs: false,
                                                width: 550,
                                                height: 200
                                              } ) ;
        layout.beginUpdate() ;
        layout.add('center', htmlPanel) ;
        // Add forms for complex components to North Region
        Ext.genboree.initFormPanels() ;
        htmlEditor =  new Ext.form.HtmlEditor(
                    {
                      id: 'html_editor',
                      fieldLabel: 'Text',
                      width: 500,
                      height: 200
                    }) ;
        htmlEditor.render(htmlPanel.el) ;
        htmlEditor.enableFont = true ;
        htmlEditor.enable() ;
        htmlEditor.srcEditBtnClickedOnce = false ;
        Ext.genboree.resizeHtmlEditor() ;
        var toolbar = htmlEditor.tb ;
        var srcEditIdx = toolbar.items.keys.indexOf('sourceedit') ;
        var srcEditBtn = toolbar.items.items[srcEditIdx] ;
        if(typeof(srcEditBtn) != 'undefined') {
          srcEditBtn.addListener( 'click',
                                srcEditWarn) ;
        }
        layout.endUpdate() ;
      }
      return ;
    },
    initFormPanels: function()
    {
      var layout = dialog.getLayout() ;
      var iconType = currIconType ;
      // Add a form for each component type for use in the North Region
      Ext.each( ['projectTitle', 'projectDesc', 'projectContent', 'projectNews', 'projectQuickLinks', 'projectCustomLinks', 'projectFiles'],
                function(componentType, ii, allComponentTypes)
                {
                  switch(componentType)
                  {
                    case 'projectTitle':
                    case 'projectDesc':
                    case 'projectContent':
                      formPanels[componentType] = null ;
                      break ;
                    case 'projectNews':
                    case 'projectQuickLinks':
                    case 'projectCustomLinks':
                    case 'projectFiles':
                      layout.beginUpdate() ;
                      var panel = new Ext.ContentPanel( componentType + '_formPanel',
                                                        {
                                                          autoCreate: true,
                                                          fitToFrame: true,
                                                          fitContainer: true,
                                                          closeOnTab: false,
                                                          closable: false,
                                                          alwaysShowTabs: false
                                                        }) ;
                      panel.el.setStyle('padding', '2') ;
                      formPanels[componentType] = panel ;
                      var form = createEditForm(componentType) ;
                      forms[componentType] = form ;
                      form.render(panel.el) ;
                      layout.add('north', panel) ;
                      layout.endUpdate() ;
                      break ;
                  } ;
                  return true ;
                }) ;
    },
    resizeHtmlEditor: function()
    {
      var theDialog = Ext.genboree.dialog() ;
      var theLayout = theDialog.getLayout() ;
      var theViewSize = theLayout.getViewSize() ;
      var theEditor = Ext.genboree.htmlEditor() ;
      var heWidth = theViewSize.width-2 ;
      var heHeight = theViewSize.height-6-theDialog.northRegionSize ;
      layout.beginUpdate() ;
      theEditor.setSize(heWidth, (heHeight > 0 ? heHeight : 1)) ;
      layout.endUpdate() ;
      return ;
    },
    showNorthOnly: function()
    {
      var theDialog = Ext.genboree.dialog() ;
      var theLayout = theDialog.getLayout() ;
      var theViewSize = theLayout.getViewSize() ;
      var northRegion = theLayout.getRegion('north') ;
      layout.beginUpdate() ;
      northRegion.resizeTo(theViewSize.height) ;
      layout.endUpdate() ;
      return ;
    },
    editHandleClicked: function(event, evtObject)
    {
      // Figure out componentType based on id of handle clicked
      var evtTarget = Ext.get(event.getTarget()) ;
      var evtTargetId = evtTarget.id ;
      var componentType = evtTargetId.replace(/EBtn$/, "") ;
      // Get title and data based on componentType
      var title = dialogTitlesById[componentType] ;
      var textData = pageContents[componentType] ;

      // Simple editor dialog is all that is needed for these:
      if(componentType == 'projectTitle' || componentType == 'projectDesc' || componentType == 'projectContent')
      {
        clearItemSelectionMode() ; // hide the other type of toolbar
        // save current componentType
        currComponentType = componentType ;
        currIconType = componentType + "_handle" ;
        Ext.genboree.promptForEdit(componentType) ; // show the edit dialog immediately
      }
      else if(componentType == 'none')
      {
        // then do nothing
      }
      else // Custom editor dialog is needed, based on toolbar icon clicked (add/edit/delete) and component type
      {
        var toolBarElemId = "editToolBarDiv_" + componentType ;
        var toolBarElem = Ext.get(toolBarElemId) ;
        if(toolBarElem)
        {
          clearItemSelectionMode(toolBarElem) ; // toggle display of current toolbar
          // save current componentType
          currComponentType = componentType ;
        }
        else
        {
          clearItemSelectionMode() ; // hide any toolbar already showing
          // save current componentType
          currComponentType = componentType ;
          toolBarElem = Ext.DomHelper.append( document.body,
                                              {
                                                id: toolBarElemId,
                                                tag: "div",
                                                cls: "editToolBarDiv",
                                                children:
                                                [
                                                  {
                                                    id: "addImg",
                                                    tag: "img",
                                                    src: "/images/project_pencil_add_rBorder.png",
                                                    cls: "toolBarIcon",
                                                    width: "19",
                                                    height: "18",
                                                    title: "Add",
                                                    alt: "Add",
                                                    onmouseover: 'toggleIconHover(this, true)',
                                                    onmouseout: 'toggleIconHover(this, false)',
                                                    onclick: "return toolBarBtnDispatcher('add', '" + componentType + "', this)"
                                                  },
                                                  {
                                                    id: "editImg",
                                                    tag: "img",
                                                    src: "/images/project_pencil_rBorder.png",
                                                    cls: "toolBarIcon",
                                                    width: "19",
                                                    height: "18",
                                                    title: "Edit",
                                                    alt: "Edit",
                                                    onmouseover: 'toggleIconHover(this, true)',
                                                    onmouseout: 'toggleIconHover(this, false)',
                                                    onclick: "return toolBarBtnDispatcher('edit', '" + componentType + "', this)"
                                                  },
                                                  {
                                                    id: "delImg",
                                                    tag: "img",
                                                    src: "/images/project_pencil_delete.png",
                                                    cls: "toolBarIconLast",
                                                    width: "18",
                                                    height: "18",
                                                    title: "Delete",
                                                    alt: "Delete",
                                                    onmouseover: 'toggleIconHover(this, true)',
                                                    onmouseout: 'toggleIconHover(this, false)',
                                                    onclick: "return toolBarBtnDispatcher('delete', '" + componentType + "', this)"
                                                  }
                                                ]
                                              },
                                              true) ;
        }
        toolBarElem.setStyle("position", 'absolute') ;
        toolBarElem.setStyle("white-space", 'nowrap') ;
        toolBarElem.setStyle("width", 19*2+18+2) ;
        toolBarElem.setStyle("height", 18) ;
        toolBarElem.setXY([evtTarget.getRight() + 1, evtTarget.getY()] ) ;
      }
      return ;
    },
    promptForEdit: function(componentType, objectId) // show appropriate edit dialog
    {
      // Init dialog if needed:
      Ext.genboree.initDialog() ;
      // Set cursor to normal, in case coming from selection mode
      document.body.style.cursor = 'default' ;
      // Get some key informdation
      var iconType = currIconType ;
      var title = dialogTitlesById[componentType] ; // Get title based on evtTargetId
      var data = pageContents[componentType] ;  // Get text data based on evtTargetId
      var dataObjectIdx = getPageContentObjectIndex(componentType, objectId) ;
      var focusElem = null ;
      // Save current data object index
      currDataObjectIdx = dataObjectIdx ;
      if(iconType != 'delete' && iconType != 'none')
      {
        var layout = dialog.getLayout() ;
        var viewSize = layout.getViewSize() ;
        var northRegion = layout.getRegion('north') ;
        var centerRegion = layout.getRegion('center') ;
        var northRegionSize = 0 ;
        // Set the title
        dialog.setTitle(title) ;
        dialog.northOnly = false ;
        // Fill or clear form fields, as appropriate
        fillEditForm(componentType, dataObjectIdx) ;
        fillHtmlEditor(componentType, dataObjectIdx) ;
        // Adjust layout of dialog and show correct form panel
        layout.beginUpdate() ;
        switch(componentType)
        {
          case 'projectTitle':
          case 'projectDesc':
          case 'projectContent':
            northRegion.resizeTo(northRegionSize = 1) ;
            dialog.northRegionSize = northRegionSize  ;
            dialog.setContentSize(570, 285) ;
            focusElem = htmlEditor ;
            Ext.genboree.resizeHtmlEditor() ;
            break ;
          case 'projectQuickLinks':
            // Select panel for north
            northRegion.showPanel(formPanels[componentType]) ;
            northRegion.resizeTo(northRegionSize = 64) ;
            dialog.northOnly = true ;
            dialog.northRegionSize = northRegionSize - 2 ;
            dialog.setContentSize(560, 64) ;
            focusElem = forms[componentType].findField(componentType + "_url") ;
            Ext.genboree.showNorthOnly() ;
            break ;
          case 'projectCustomLinks':
            // Select panel for north
            northRegion.showPanel(formPanels[componentType]) ;
            northRegion.resizeTo(northRegionSize = 58) ;
            dialog.setContentSize(560, 350) ;
            dialog.northRegionSize = northRegionSize - 2;
            focusElem = forms[componentType].findField(componentType + "_url") ;
            Ext.genboree.resizeHtmlEditor() ;
            break ;
          case 'projectNews':
            // Select panel for north
            northRegion.showPanel(formPanels[componentType]) ;
            northRegion.resizeTo(northRegionSize = 30) ;
            dialog.setContentSize(560, 325) ;
            dialog.northRegionSize = northRegionSize - 2 ;
            focusElem = forms[componentType].findField(componentType + "_date") ;
            Ext.genboree.resizeHtmlEditor() ;
            break ;
          case 'projectFiles':
            // Select panel for north
            northRegion.showPanel(formPanels[componentType]) ;
            northRegion.resizeTo(northRegionSize = 144) ;
            dialog.setContentSize(560, 325) ;
            dialog.northRegionSize = northRegionSize - 2 ;
            focusElem = (false) ? forms[componentType].findField(componentType + "_upload") : forms[componentType].findField(componentType + "_label") ;
            Ext.genboree.resizeHtmlEditor() ;
            break ;
        }
        layout.endUpdate() ;
        dialog.show() ;
        //focusElem.focus(true) ;
      }
      else if(iconType == 'none')
      {
        // then do nothing
      }
      else // it's delete, we just need to ask if it's ok
      {
        activeDialog = Ext.MessageBox.confirm(title,
                                              'Are you sure you want to delete that page element?',
                                              function(btn, evt, theDialog)
                                              {
                                                dialogBtnDispatcher(btn, evt, theDialog) ;
                                              }.createDelegate(this, [this], true)) ;
      }
      if(Ext.isOpera) // Opera has a couple of issues creating new elements. Gets confused about where the browser should scroll to after -first- time MessageBoxes are displayed, so it jumps to the bottom.
      {
        (new Ext.util.DelayedTask()).delay(100, Ext.genboree.scrollToActiveDialog) ;
      }
      return ;
    },
    scrollToActiveDialog: function()
    {
      if(activeDialog)
      {
        activeDialog.getDialog().el.scrollIntoView() ;
        Ext.get(document.body).scroll("up", 30) ;
      }
      return true ;
    },
    hoverItem: function(evt, theDiv)
    {
      return Ext.genboree.toggleHoverItem(evt, theDiv, true) ;
    },
    unhoverItem: function(evt, theDiv)
    {
      return Ext.genboree.toggleHoverItem(evt, theDiv, false) ;
    },
    toggleHoverItem: function(evt, theDiv, isHover)
    {
      var eDiv = Ext.get(theDiv) ;
      var oldClass = (isHover ? "Item" : "Hover") ;
      var newClass = (isHover ? "Hover" : "Item") ;
      if(eDiv.hasClass("itemListParent")) // then we have the parent container of the item list
      {
        if(eDiv.hasClass("insertable" + oldClass + "Parent"))
        {
          eDiv.replaceClass("insertable" + oldClass + "Parent", "insertable" + newClass + "Parent") ;
        }
      }
      else // we have the item div itself or an element within it
      {
        if(!eDiv.hasClass(itemDivClassById[currComponentType])) // then we got a child-elem...find the parent div
        {
          eDiv = eDiv.findParent('div.' + itemDivClassById[currComponentType], document.body, true) ;
        }
        // Got the appropriate eDiv
        if(eDiv != null && typeof(eDiv) != 'undefined')
        {
          if(eDiv.hasClass("insertable" + oldClass))
          {
            eDiv.replaceClass("insertable" + oldClass, "insertable" + newClass) ;
          }
          else
          {
            eDiv.replaceClass("selectable" + oldClass, "selectable" + newClass) ;
          }
        }
      }
      return ;
    },
    // A component was clicked via a toolbar-activated feature
    itemClicked: function(evt, theDiv)
    {
      // Need to get the generic id of the item clicked, but the item clicked may be one of the
      // child elements within the generic item div. Extract the generic part of the id.
      if(theDiv)
      {
        var divId = theDiv.id ;
        var idMatch = divId.match(/^([^_]+)_([^_]+(?:_\d+)?)/) ;
        if(idMatch == null) // then probably some child that has no id assigned by us...find selectableItem parent and use that
        {
          theDiv = Ext.get(divId).findParentNode('div.selectableHover', 10) ;
          if(theDiv == null || theDiv == undefined)
          {
            theDiv = Ext.get(divId).findParentNode('div.insertableHover', 10) ;
          }
          divId = theDiv.id ;
          idMatch = divId.match(/^([^_]+)_([^_]+(?:_\d+)?)/) ;
        }
        var componentType = idMatch[1] ;
        var objectId = idMatch[2] ;
        Ext.genboree.promptForEdit(componentType, objectId) ;
      }
      return ;
    },
    removeMask: function()
    {
      // ---------------------------------
      // Page initialization mask
      // ---------------------------------
      var loading = Ext.get('genboree-loading') ; // Name of page loading div
      var mask = Ext.get('genboree-loading-mask') ; // Name of page loading mask div
      if((loading.getStyle('display') != 'none') && (mask.getStyle('display') != 'none'))
      {
        mask.setOpacity(0.5) ;
        mask.shift(
        {
          remove: true,
          duration: 1,
          opacity: 0.5,
          callback:   function()
                      {
                        loading.fadeOut( { duration: 0.2, remove: true} ) ;
                      }
        }) ;
      }
    }
  } ;
}() ;

// Register initialization of namespace once page fully loads.
Ext.onReady(Ext.genboree.init, Ext.genboree, true) ;
Ext.onReady(Ext.genboree.removeMask, Ext.genboree, true) ;

// --------------------------------------------------------------------------
// EXTJS HELPERS
// --------------------------------------------------------------------------
// Get the index of a particular component (by id) within its data structure.
// - if the component is a simple on (html test only) then objId will be invalid and this returns null
function getPageContentObjectIndex(componentType, objId)
{
  var retVal = null ;
  if(objId != undefined && objId != null && pageContents)
  {
    var itemId = componentType + "_" + objId ;
    var recs = pageContents[componentType] ;
    if(recs)
    {
      if(objId == 'list') // then the parent container of all the items was clicked...insert new ones at end
      {
        retVal = recs.length ;
      }
      else // an item was clicked, find its index in the list
      {
        Ext.each( recs,
                  function(rec, index, allRecs)
                  {
                    var keepIterating = true ;
                    if(rec.editableItemId == itemId)
                    {
                      retVal = index ;
                      keepIterating = false ;
                    }
                    return keepIterating ;
                  },
                  this) ;
      }
    }
  }
  return retVal ;
}

function srcEditWarn(btn, evt, theDialog)
{
  var srcBtn = Ext.genboree.srcEditBtn() ;
  var he = Ext.genboree.htmlEditor() ;
  if(srcBtn && srcBtn.pressed && !he.srcEditBtnClickedOnce)
  {
    he.srcEditBtnClickedOnce = true ;
    Ext.genboree.activeDialog(Ext.Msg.alert("WARNING",
                                            "WARNING: editing the HTML directly can be<br>dangerous. Be sure to write well-formatted HTML to reduce the<br>chance of adverse effects."  ) ) ;
    (new Ext.util.DelayedTask()).delay( 50,
                                        function()
                                        {
                                          Ext.genboree.activeDialog().getDialog().toFront() ;
                                        }) ;
    if(Ext.isOpera) // Opera has a couple of issues creating new elements. Gets confused about where the browser should scroll to after -first- time MessageBoxes are displayed, so it jumps to the bottom.
    {
      (new Ext.util.DelayedTask()).delay(150, Ext.genboree.scrollToActiveDialog) ;
    }
  }
  return false ;
}

function dialogBtnDispatcher(btn, evt, theDialog)
{
  var componentType = Ext.genboree.currComponentType() ;
  var dataObjectIdx = Ext.genboree.currDataObjectIdx() ;
  var uploadOk = false ;
  var btnText = btn ; // If btn doesn't have getText(), then it's probably just a string resulting from a confirm dialog (i.e. a delete), not an actual button
  if(btn.getText)     // <-- so test for presence of a getText() method
  {
    btnText = btn.getText() ; // if it is a 'Submit' or 'Cancel', get that text from the button
  }
  // Is this a (a) Submit click, (b) a Cancel click, or (c) a Yes/Now click from a confirm dialog?
  if(btnText == 'Submit')
  {
    switch(componentType) // Submit new/changed content according to component type
    {
      case 'projectTitle':
      case 'projectDesc':
      case 'projectContent':
        uploadOk = updateSimpleHtmlContent(theDialog) ;
        break ;
      case 'projectNews':
      case 'projectCustomLinks':
      case 'projectQuickLinks':
      case 'projectFiles':
        uploadOk = updateComplexComponent(theDialog, dataObjectIdx) ;
        break ;
      case 'none': // do nothing
        uploadOK = true ;
        break ;
      default:
        Ext.Msg.alert('ERROR: Bad Subject of Edit', "The subject '" + componentType + "' is not editable.") ;
    }
    if(uploadOk == true)
    {
      theDialog.hide() ;
      clearItemSelectionMode() ; // reset any edit toolbars showing
    }
    else // not valid or something
    {
      Ext.Msg.alert('ERROR: Invalid Entry ', 'ERROR: ' + uploadOk) ;
    }
  }
  else if(btnText == 'Yes' || btnText == 'yes') // From a confirm dialog...right now only 'delete' uses that
  {
    switch(componentType) // Delete component
    {
      case 'projectNews':
      case 'projectCustomLinks':
      case 'projectQuickLinks':
        deleteDataObject(componentType, dataObjectIdx) ;
        break ;
      case 'projectFiles':
        deleteProjectFile(theDialog, dataObjectIdx) ;
        uploadOK = true ;
        break ;
      case 'none': // do nothing
        break ;
      default:
        Ext.Msg.alert('ERROR: Bad Subject of Delete', "The subject '" + componentType + "' is not deletable.") ;
    }
    clearItemSelectionMode() ; // reset any edit toolbars showing
  }
  else if(btnText == 'No' || btnText == 'no') // From a confirm dialog...right now only 'delete' uses that
  {
    // Nothing to do, dialog should auto-close
    clearItemSelectionMode() ; // reset any edit toolbars showing
  }
  else // Cancel btn or similar
  {
    closeDialogIfUserConfirms(theDialog, btn) ; // This is asyncronous!
  }

  // Just to be sure no bubbling or event handling by browser.
  if(evt && evt.stopEvent())
  {
    evt.stopEvent() ;
  }
  return false ;
}

function toolBarBtnDispatcher(iconType, componentType, theBtn)
{
  clearActionIcons() ; // Clear current active icon
  // Set this icon with active background color
  Ext.get(theBtn).addClass("toolBarActiveIcon") ;
  document.body.style.cursor = 'crosshair' ;
  activateComponentSelection(iconType, componentType) ;
  return false ;
}

function clearActionIcons()
{
  // Unset any active icon backgrounds
  var iconBtns = Ext.select('img.toolBarIconHover, img.toolBarIcon, img.toolBarIconLast') ;
  iconBtns.removeClass("toolBarIconHover") ;
  iconBtns.removeClass("toolBarActiveIcon") ;
  iconBtns.setStyle('background-color', null) ;
  Ext.genboree.currIconType("none") ;
  return ;
}

function activateComponentSelection(iconType, componentType)
{
  // Set current componentType (we don't want to pass it via a delegate because we need to UNregister these functions by name)
  Ext.genboree.currComponentType(componentType) ;
  Ext.genboree.currIconType(iconType) ;
  removeSelectableDivListeners() ;  // Removes listeners from both the items and their parent containers
  removeSelectableDivClasses() ;    // Removes special div classes from both the items and their parent containers
  var actionClass = (iconType == 'add' ? 'insertableItem' : 'selectableItem') ;
  // Activate individual items first
  var itemDivs = Ext.select('div.' + itemDivClassById[componentType], true) ;
  itemDivs.addClass(actionClass) ;
  itemDivs.on('mouseover',
              Ext.genboree.hoverItem,
              this,
              {
                stopEvent: true
              } ) ;
  itemDivs.on('mouseout',
              Ext.genboree.unhoverItem,
              this,
              {
                stopEvent: true
              }  ) ;
  itemDivs.on('click',
              Ext.genboree.itemClicked,
              document.body) ;
  // If it's an 'add', activate their parent container div next to allow adding to end of list
  if(iconType == 'add')
  {
    // Find parent
    var itemListParent = null ;
    if(itemDivs.length > 0)
    {
      itemListParent = itemDivs.elements[0].findParentNode('div.itemListParent', document.body, true) ;
    }
    else // no itemDivs found...must be no items of this kind yet
    {
      // Try to get by adding '_list' to componentType
      itemListParent = Ext.get(componentType + "_list") ;
    }
    itemListParent.addClass('insertableItemParent') ;
    itemListParent.on('mouseover',
                      Ext.genboree.hoverItem,
                      this,
                      {
                        stopEvent: true
                      } ) ;
    itemListParent.on('mouseout',
                      Ext.genboree.unhoverItem,
                      this,
                      {
                        stopEvent: true
                      }  ) ;
    itemListParent.on('click',
                      Ext.genboree.itemClicked,
                      this ,
                      {
                        stopEvent: true
                      } ) ;
  }
  return ;
}

function clearItemSelectionMode(clickedToolBar)
{
  // Clear active icons
  clearActionIcons() ;
  // Close any open edit toolbars (treat the clicked one special):
  if(clickedToolBar)
  {
    var isClickedToolBarVisible = clickedToolBar.isVisible() ;
  }
  var toolBarDivs = Ext.select('div.editToolBarDiv') ;
  toolBarDivs.hide() ; // Hide all
  if(clickedToolBar)
  {
    // Restore clicked toolbar appropriately
    if(isClickedToolBarVisible)
    {
      clickedToolBar.hide() ;
    }
    else
    {
      clickedToolBar.show() ;
    }
  }
  // Unset current componentType, iconType
  Ext.genboree.currComponentType("none") ;
  Ext.genboree.currIconType("none") ;
  // Restore default cursor
  document.body.style.cursor = 'default' ;
  removeSelectableDivListeners() ;
  removeSelectableDivClasses() ;
  // Clear active dialog
  var activeDialog = Ext.genboree.activeDialog(null) ;
  return ;
}

function removeSelectableDivClasses()
{
  var itemDivs = Ext.each(  ['selectableItem', 'selectableHover', 'selectClick', 'insertableItem', 'insertableHover'],
                            function(itemClass, ii, allItems)
                            {
                              var itemDivs = Ext.select("." + itemClass) ;
                              itemDivs.removeClass(itemClass) ;
                              if(itemClass.indexOf('insert') == 0)
                              {
                                itemDivs = Ext.select("." + itemClass + 'Parent') ;
                                itemDivs.removeClass(itemClass + 'Parent') ;
                              }
                              return true ;
                            } ) ;
  return ;
}

function removeSelectableDivListeners()
{
  Ext.each( ['selectableItem', 'selectableHover', 'selectClick', 'insertableItem', 'insertableHover' ],
            function(itemClass, ii, allItems)
            {
              var itemDivs = Ext.select('.' + itemClass) ;
              if(itemDivs.elements.length > 0)
              {
                itemDivs.removeListener('mouseover', Ext.genboree.hoverItem) ;
                itemDivs.removeListener('mouseout', Ext.genboree.unhoverItem) ;
                itemDivs.removeListener('click', Ext.genboree.itemClicked) ;
                itemDivs.removeAllListeners() ;
              }
              if(itemClass.indexOf('insert') == 0)
              {
                var itemListParentClass = itemClass + 'Parent' ;
                var itemListParent = Ext.select("." + itemListParentClass) ;
                itemListParent.removeListener('mouseover', Ext.genboree.hoverItem) ;
                itemListParent.removeListener('mouseout', Ext.genboree.unhoverItem) ;
                itemListParent.removeListener('click', Ext.genboree.itemClicked) ;
                itemListParent.removeAllListeners() ;
              }
              return true ;
            } ) ;
  return ;
}

// Initialize the Form objects for component types needing extra fields
function createEditForm(componentType)
{
  var iconType = Ext.genboree.currIconType() ;
  // Create a Form for this componentType
  var form =  new Ext.form.Form(componentType + "_form",
              {
                labelAlign: 'right',
                labelWidth: 35
              }) ;
  switch(componentType)
  {
    case 'projectNews':
      var dateField = new Ext.form.DateField( // The Update DATE
                  {
                    fieldLabel: 'Date',
                    name: (componentType + "_date"),
                    allowBlank: false,
                    blankText: 'A date is required.',
                    format: 'Y/m/d',
                    value: (new Date()).format('Y/m/d'),
                    width: 125
                  }) ;
      form.add(dateField) ;
      break ;
    case 'projectQuickLinks':
    case 'projectCustomLinks': // these differ only at display time (no htmlEditor for quick links b/c no description)
      form.add( new Ext.form.TextField(
                {
                  fieldLabel: 'URL',
                  name: (componentType + "_url"),
                  allowBlank: false,
                  value: '',
                  vtype: 'url',
                  width: 420
                })) ;
      form.add( new Ext.form.TextField(
                {
                  fieldLabel: 'Label',
                  name: (componentType + '_label'),
                  allowBlank: false,
                  regex: /\S/,
                  regexText: 'Label cannot be blank.',
                  value: '',
                  width: 420
                })) ;
      break ;
    case 'projectFiles':
      var uploadField = new Ext.form.TextField(
                {
                  inputType: 'file',
                  fileUpload: true,
                  fieldLabel: 'File',
                  name: (componentType + '_upload'),
                  allowBlank: false,
                  regex: /\S/,
                  regexText: 'File cannot be blank.',
                  value: '',
                  width: 420
                }) ;

      form.add(uploadField) ;
      form.add( new Ext.form.TextField(
                {
                  fieldLabel: 'Label',
                  name: (componentType + '_label'),
                  allowBlank: false,
                  regex: /\S/,
                  regexText: 'Label cannot be blank.',
                  value: '',
                  width: 420
                })) ;
      var dateField = new Ext.form.DateField( // The Update DATE
                  {
                    fieldLabel: 'Date',
                    name: (componentType + "_date"),
                    allowBlank: false,
                    blankText: 'A date is required.',
                    format: 'Y/m/d',
                    value: (new Date()).format('Y/m/d'),
                    width: 125
                  }) ;
      form.add(dateField) ;
      form.add( new Ext.form.Checkbox({
                  fieldLabel: 'Hide',
                  name: (componentType + '_hide')
                })) ;
      form.add( new Ext.form.Checkbox({
                  fieldLabel: 'Archived',
                  name: (componentType + '_archived')
                })) ;
      form.add( new Ext.form.Checkbox({
                  fieldLabel: 'Auto Archive',
                  name: (componentType + '_autoArchive')
                  })) ;
      break ;
  }
  return form ;
}

// Fill in an existing Form, based on selected component and type
function fillEditForm(componentType, dataObjectIdx)
{
  var recs = pageContents[componentType] ;
  var dataObject = recs[dataObjectIdx] ;
  var iconType = Ext.genboree.currIconType() ;
  var clearField = ( dataObject == undefined || dataObject == null || iconType == 'add' ) ; // No dataObject at the given index; clear current field values
  var forms = Ext.genboree.forms() ;
  var form = forms[componentType] ;
  switch(componentType)
  {
    case 'projectNews':
      var dateField = form.findField(componentType + "_date") ;
      dateField.setValue( (clearField ? (new Date()).format('Y/m/d') : Date.parseDate(dataObject.date, 'Y/m/d')) ) ;
      break ;
    case 'projectQuickLinks':
    case 'projectCustomLinks': // these differ only at display time (no htmlEditor for quick links b/c no description)
      var urlField = form.findField(componentType + "_url") ;
      urlField.setValue( (clearField ? '' : dataObject.url) ) ;
      var labelField = form.findField(componentType + "_label") ;
      labelField.setValue( (clearField ? '' : dataObject.linkText) ) ;
      break ;
    case 'projectFiles':
      var dateField = form.findField(componentType + "_date") ;
      var dateValue;
      if(clearField) {
        dateValue = (new Date()).format('Y/m/d');
      } else {
        if(dataObject.date.s > 0) {
          dateValue = (new Date(dataObject.date.s*1000)).format('Y/m/d');
        } else {
          dateValue = Date.parseDate(dataObject.date, 'Y/m/d');
        }
      }
      dateField.setValue( dateValue ) ;
      var labelField = form.findField(componentType + "_label") ;
      labelField.setValue( (clearField) ? '' : dataObject.label ) ;
      var hideField = form.findField(componentType + "_hide") ;
      hideField.setValue( (clearField) ? false : dataObject.hide ) ;
      var archivedField = form.findField(componentType + "_archived") ;
      archivedField.setValue( (clearField) ? false : dataObject.archived ) ;
      var autoArchiveField = form.findField(componentType + "_autoArchive") ;
      autoArchiveField.setValue( (clearField) ? true : dataObject.autoArchive ) ;
      var uploadField = form.findField(componentType + "_upload") ;
      if(clearField)
      {
        form.fileUpload = true;
        uploadField.el.up('.x-form-item').setDisplayed(true);
        uploadField.enable() ;
        // Add onchange(ifLabelIsEmptySetLabelToFileName)
        // Couldn't get this to work, onchange not supported for 'file' textFields in ExtJS 1.1.  Booo
        //uploadField.on('change', function(){
        //   labelField.setValue(uploadField.dom.value) ;
        //});
      }
      else
      {
        form.fileUpload = false;
        uploadField.el.up('.x-form-item').setDisplayed(false);
        uploadField.disable() ;
      }
      break ;
  }
  return form ;
}

// Fill in existing HTMLEditor content, using selected component
function fillHtmlEditor(componentType, dataObjectIdx)
{
  var recs = pageContents[componentType] ;
  var dataObject = recs[dataObjectIdx] ;
  var iconType = Ext.genboree.currIconType() ;
  var clearField = ( dataObject == undefined || dataObject == null || iconType == 'add' ) ; // No dataObject at the given index; clear current field values
  var htmlEditor = Ext.genboree.htmlEditor() ;
  switch(componentType)
  {
    case 'projectTitle':
    case 'projectDesc':
    case 'projectContent':
      htmlEditor.setValue(recs) ;
      break ;
    case 'projectNews':
      htmlEditor.setValue( (clearField ? '' : dataObject.updateText) ) ;
      break ;
    case 'projectCustomLinks':
      htmlEditor.setValue( (clearField ? '' : dataObject.linkDesc) ) ;
      break ;
    case 'projectFiles':
      htmlEditor.setValue( (clearField ? '' : dataObject.description) ) ;
      break ;
    default: // should just be 'projectQuickLinks' right now, which doesn't need the editor
      htmlEditor.setValue('') ;
  }
  htmlEditor.enable() ;
}

//--------------------------------------------------------------------------
// UPDATER FUNCTIONS
//--------------------------------------------------------------------------
function updateSimpleHtmlContent(theDialog)
{
  var retVal = true ;
  var componentType = Ext.genboree.currComponentType() ;
  // Get HTML text from HtmlEditor
  var htmlEditor = Ext.genboree.htmlEditor() ;
  var value = htmlEditor.getValue() ;
  var strippedValue = Ext.util.Format.stripTags(value) ;
  // Validate content appropriately & set displayComponentType
  var displayComponentType = 'unknown' ;
  var displayErrorMsg = null ;
  var valueOk = true ;
  switch(componentType)
  {
    case 'projectTitle':
      // Make sure it's not empty
      valueOk = (strippedValue.match(/\S/) && !strippedValue.match(/^\s*(?:&nbsp;\s*)+$/)) ;
      displayComponentType = 'title' ;
      break ;
    case 'projectDesc':
      // Make sure it's not empty
      valueOk = (strippedValue.match(/\S/) && !strippedValue.match(/^\s*(?:&nbsp;\s*)+$/)) ;
      displayComponentType = 'description' ;
      break ;
    case 'projectContent':
      displayComponentType = 'extra content' ;
      break ;
  }

  if(valueOk)
  {
    // Save the new contents
    pageContents[componentType] = value ;
    // Sumbit new content to server
    submitUpdate(componentType, value) ;
  }
  else // value didn't check out (currently, all errors are the same: title and desc can't be empty here)
  {
    retVal = "The " + displayComponentType + " cannot be empty." ;
  }
  return retVal ;
}

function updateComplexComponent(theDialog, dataObjectIdx)
{
  var retVal = true ;
  var value = null ;
  var componentType = Ext.genboree.currComponentType() ;
  var itemsArray = pageContents[componentType] ;
  if(dataObjectIdx != 0 && !dataObjectIdx)
  {
    dataObjectIdx = itemsArray.length ;
  }
  var dataObject = itemsArray[dataObjectIdx] ;
  var oldDataObject = dataObject ;
  var idStr = null ;
  var urlField = null ;
  var labelField = null ;
  var dateField = null ;
  var newText = null ;
  var newUrl = null ;
  var newLabel = null ;
  var newDate = null ;
  var forms = Ext.genboree.forms() ;

  // Check if fields on form are all valid
  var dialogForm = forms[componentType] ;
  if(dialogForm.isValid())
  {
    var htmlEditor = Ext.genboree.htmlEditor() ;
    newText = htmlEditor.getValue() ;

    // Get current iconType so we know if this is an 'add' or an 'edit' (delete handled elsewhere)
    var iconType = Ext.genboree.currIconType() ;
    if(iconType == 'add') // then create a new dataObject
    {
      // oldDataObject is the clicked one...we'll be adding an item BEFORE that one
      idStr = componentType + "_item" ;
      switch(componentType)
      {
        case 'projectQuickLinks':
          dataObject =  {
                          editableItemId : idStr,
                          url : null,
                          linkText : null
                        } ;
          break ;
        case 'projectCustomLinks':
          dataObject =  {
                          editableItemId : idStr,
                          url : null,
                          linkText : null,
                          linkDesc : null
                        } ;
          break ;
        case 'projectNews':
          dataObject =  {
                          editableItemId : idStr,
                          date : null ,
                          updateText : null
                        } ;
          break ;
        case 'projectFiles':
          dataObject =  {
                          editableItemId: idStr,
                          date: null ,
                          label: null,
                          hide: false,
                          archived: false,
                          autoArchive: true
                        } ;
          break ;
      }
      // Insert the new dataObject in the right place in itemsArray
      if(itemsArray.length > 0)
      {
        itemsArray.splice(dataObjectIdx, 0, dataObject) ;
      }
      else // No items of this type yet
      {
        itemsArray = [] ;
        itemsArray[0] = dataObject ;
        pageContents[componentType] = itemsArray ;
      }
    }

    // Fill in dataObject (new or existing) from the form
    switch(componentType)
    {
      case 'projectQuickLinks':
        urlField = dialogForm.findField(componentType + "_url") ;
        labelField = dialogForm.findField(componentType + "_label") ;
        // Get content from form
        dataObject.url = urlField.getValue() ;
        dataObject.linkText = labelField.getValue() ;
        break ;
      case 'projectCustomLinks':
        urlField = dialogForm.findField(componentType + "_url") ;
        labelField = dialogForm.findField(componentType + "_label") ;
        // Get content from form
        dataObject.url = urlField.getValue() ;
        dataObject.linkText = labelField.getValue() ;
        dataObject.linkDesc = newText ;
        break ;
      case 'projectNews':
        dateField = dialogForm.findField(componentType + "_date") ;
        dataObject.date = dateField.getValue().format('Y/m/d') ; ;
        dataObject.updateText = newText ;
        break ;
      case 'projectFiles':
        labelField = dialogForm.findField(componentType + "_label") ;
        dateField = dialogForm.findField(componentType + "_date") ;
        hideField = dialogForm.findField(componentType + "_hide") ;
        archivedField = dialogForm.findField(componentType + "_archived") ;
        autoArchiveField = dialogForm.findField(componentType + "_autoArchive") ;
        // Get the fileName of the item to upload and append it to the dataObject
        uploadField = dialogForm.findField(componentType + "_upload") ;
        // Get content from form
        dataObject.label = labelField.getValue() ;
        dataObject.date = dateField.getValue() ;
        dataObject.hide = hideField.getValue() ;
        dataObject.archived = archivedField.getValue() ;
        dataObject.autoArchive = autoArchiveField.getValue() ;
        dataObject.description = newText ;
        if(iconType == 'add')
        {
          // IE 6 appends the full path and IE 7/8 might append "C:\fakepath\" to the file name, get rid
          var fileName = uploadField.getValue();
          var fileNameCharLoc = fileName.lastIndexOf('\\');
          if (fileNameCharLoc > -1)
          {
            fileName = fileName.substring(fileNameCharLoc + 1);
          }
          // NO: need raw file name => dataObject.fileName = encodeURIComponent(fileName);
          dataObject.fileName = fileName ;
          dataObject.uploadPending = true ;
        }
        break ;
    }

    // Submit the new content for the componentType to the server.
    if(itemsArray.length > 0) // then we're all set up to submit non-empty list of dataObjects
    {
      value = JSON.stringify(pageContents[componentType]) ;
    }
    else // we've deleted the last item of this type it looks like
    {
      value = null ;
    }
    submitUpdate(componentType, value) ;

    // If this is a project file that's being added, upload the file first.
    if(componentType == 'projectFiles' && iconType == 'add') {
      displayLoadingMsg(ProgressUpload.getLoadingMsgDiv());
      var encProjectName = encodeURIComponent($('projectName').value);
      var actionUrl = '/genbUpload/java-bin/projectFileUpload.jsp?projectName=' + encProjectName;
      //var redirectUrl = location.protocol + '//' + location.host + location.pathname + ("?projectName=" + encProjectName)
      ProgressUpload.startUpload(dialogForm.el.dom, actionUrl);
    }

  }
  else // one or more fields invalid
  {
    retVal = "Please correct the errors indicated on the form before sumbitting." ;
  }
  return retVal ;
}



// Deletes an item from updates, quick links, custom links
function deleteDataObject(componentType, dataObjectIdx)
{
  // Get array of current update items
  var itemsArray = pageContents[componentType] ;
  var dataObject = itemsArray[dataObjectIdx] ;
  // Delete the selected object
  itemsArray.remove(dataObject) ;
  // Update the pageContents data structure with new array of update items for consistency
  pageContents[componentType] = itemsArray ;
  // Submit the new updates content to the server
  submitUpdate(componentType, JSON.stringify(itemsArray)) ;
  return ;
}


// Deletes a project file using the [unique] fileName
function deleteProjectFile(theDialog, dataObjectIdx)
{
  var retVal = true ;
  var value = null ;
  var componentType = Ext.genboree.currComponentType() ;
  // Get the fileName of the item to delete:
  var fileName = $(pageContents[componentType][dataObjectIdx].editableItemId + "_fileName").value ;
  // Construct API rsrcPath
  var urlTemplate = new Template('/REST/v1/grp/#{grp}/prj/#{prj}/file/#{fileName}') ;
  var projectName = $('projectName').value ;
  var groupName = $('groupName').value ;
  var apiRsrcPath = urlTemplate.evaluate( {grp: encodeURIComponent(groupName), prj: encodeURIComponent(projectName), fileName: encodeURIComponent(fileName)}) ;
  // TODO: add 'processing animation'
  var loadingMsg = 'File is being deleted...<br><br>Please be patient.  The page will refresh when complete.';
  displayLoadingMsg(loadingMsg);

  makeProxiedAPIRequest(apiRsrcPath, 'delete',
    function(transport) { // success (2xx response)
      // parse JSON response
      var respData = JSON.parse(transport.responseText) ;
      var statusCode = respData['status']['statusCode'] ;
      var statusMsg = respData['status']['msg'] ;
      var statusCodeElem = $('lastApiStatusCode') ;
      statusCodeElem.value = statusCode ;
      var statusMsgElem = $('lastApiStatusMsg') ;
      statusMsgElem.value = statusMsg ;
      // show error div if problem
      var loadingMsg = 'File deletion successfully completed. Will refresh page to reflect new contents.';
      displayLoadingMsg(loadingMsg);
      if(statusCode == 'OK')
      {
        (new Ext.util.DelayedTask()).delay(
          3000,
          function()
          {
            window.location.reload(true) ;
          }) ;
      }
      return ;
    },
    function(transport) { // failure (non-2xx response)
      // parse JSON response, if any
      var respData = JSON.parse(transport.responseText) ;
      var statusCode = null ;
      var statusMsg =  null ;
      var explanationText = 'File deletion failed! Server could not delete the file and replied with:<br>' ;
      var statusCodeElem = $('lastApiStatusCode') ;
      var statusMsgElem = $('lastApiStatusMsg') ;
      if(respData['status']) // then we got back a structured reply from web server
      {
        statusCode = respData['status']['statusCode'] ;
        statusMsg = respData['status']['msg'] ;
        explanationText += ('<ul><li><b>Error code:</b> ' + statusCode + '</li><li><b>Error message:</b> ' + statusMsg + '</li></ul>') ;
      }
      else // we got back unstructured reply from web server; probably some HTML error message
      {
        statusCode = transport.status ;
        statusMsg = transport.responseText ;
        explanationText += ('a ' + statusCode + ' HTTP response code and an error page:<br><pre>' + statusMsg + '</pre>') ;
      }
      // Save status info somewhere
      statusCodeElem.value = statusCode ;
      statusMsgElem.value = statusMsg ;

      // show error div if problem
      updateStatusDiv('', explanationText, statusCode) ;

      // Clear the loading dialog
      clearLoadingMsg();
    }) ;
  return retVal ;
}

function updateStatusDiv(successText, failureText, statusCode)
{
  var statusDiv = $('status') ;
  if(statusCode == 'OK' || statusCode == 'Accepted')
  {
    statusDiv.update('<div class="success">' + successText + '</div>') ;
    statusDiv.show() ;
    statusDiv.scrollIntoView() ;
  }
  else // some kind of error
  {
    statusDiv.update('<div class="failure">' + failureText + '</div>') ;
    statusDiv.show() ;
    statusDiv.scrollIntoView() ;
  }
  return ;
}

function makeProxiedAPIRequest(rsrcPath, method, successCallback, failureCallback)
{
  var statusDiv = $('status') ;
  statusDiv.hide() ;
  var escRsrcPath = encodeURIComponent(rsrcPath) ;
  var proxyUrl = '/java-bin/apiCaller.jsp?rsrcPath=' + escRsrcPath + '&apiMethod=' + method.toUpperCase() ;
  new Ajax.Request(proxyUrl, {
    method : method.toLowerCase(),
    onSuccess : successCallback,
    onFailure : failureCallback
  }) ;
}


function getInnerHTMLByIdPlusSuffix(idStr, suffix)
{
  var retVal = null ;
  var fullId = idStr + suffix ;
  var elem = $(fullId) ;
  if(elem)
  {
    retVal = elem.innerHTML ;
  }
  return retVal ;
}

// Handle changing edit/view modes and the special revert button (that one is done behind the scenes)
function modeButtonClicked(btn)
{
  var btnLabel = btn.value ;
  var formParams = {} ;
  var projectName = encodeURIComponent(Ext.get('projectName').getValue()) ;
  // Create URL that has projectName parameter. Required for posting forms or for window.location redirects.
  var actionUrl = location.protocol + '//' + location.host + location.pathname + ("?projectName=" + projectName) ;
  // Redirect the window location appropriately, after a background form submission
  // in the case of revert.
  if(btnLabel == 'View Mode')
  {
    window.location = actionUrl ;
  }
  else // activating edit or doing a revert while in edit mode
  {
    formParams.edit = 'yes' ;
    if(btnLabel == "Undo Last") // doing revert
    {
      formParams.revert = 'yes' ;
      // Create a form we will submit in the background
      var eForm = new Ext.form.Form() ;
      // Add form object to actual page element
      var submitFormDiv = Ext.get('submitForm') ;
      submitFormDiv.setStyle('display', 'block') ;
      eForm.render('submitForm') ;
      // Background submit form
      eForm.doAction('submit', { url: actionUrl, method: 'POST', params: formParams }) ;
    }
    else if(btnLabel == "Publish" || btnLabel == "Retract") // doing a publish/retract of project
    {
      formParams.publishMode = btnLabel ;
      // Create a form we will submit in the background
      var eForm = new Ext.form.Form() ;
      // Add form object to actual page element
      var submitFormDiv = Ext.get('submitForm') ;
      submitFormDiv.setStyle('display', 'block') ;
      eForm.render('submitForm') ;
      // Background submit form
      eForm.doAction('submit', { url: actionUrl, method: 'POST', params: formParams }) ;
    }
    // After a slight pause (to let any background submit go first), refresh page into edit mode
    (new Ext.util.DelayedTask()).delay( 750,
                                        function()
                                        {
                                          window.location = actionUrl + "&edit=yes" ;
                                        }) ;
  }
  // Handler will pass this up to form, which will cancel the browser-mediated submit
  return false ;
}

// Submitting actual changes to the page via ExtJS dialog
function submitUpdate(compName, compValue)
{
  var projectName = encodeURIComponent(Ext.get('projectName').getValue()) ;
  var actionUrl = location.protocol + '//' + location.host + location.pathname + ("?projectName=" + projectName) ;


  var formParams =  {
                      edit: 'yes',
                      postChanges: 'yes',
                      componentType: compName,
                      componentValue: compValue
                    } ;
  // Create a form we will submit in the background, add it to actual page element
  var eForm = new Ext.form.Form() ;
  var submitFormDiv = Ext.get('submitForm') ;
  submitFormDiv.setStyle('display', 'block') ;
  eForm.render('submitForm') ;
  // Background submit form
  eForm.doAction('submit', { url: actionUrl, method: 'POST', params: formParams }) ;
  // After a slight pause (to let any background submit go first), refresh page into edit mode
  // don't do reload for file upload, the upload call back will do it.
  // Get current iconType so we know if this is an 'add' or an 'edit' (delete handled elsewhere)
  var iconType = Ext.genboree.currIconType() ;
  if(!(compName == 'projectFiles' && iconType == 'add')) {
    (new Ext.util.DelayedTask()).delay( 750,
                                        function()
                                        {
                                          window.location = actionUrl + "&edit=yes" ;
                                        }) ;
  }
  // Handler will pass this up to form, which will cancel the browser-mediated submit
  return false ;
}

function closeDialogIfUserConfirms(theDialog, theBtn)
{
  var retVal = true ;
  Ext.Msg.confirm('Abandon Changes?',
                  'Are you sure you want to abandon any changes?',
                  function(answer, otherInfo, dialog) // Normally just has btn's text/value and other info (eg prompt text if any) but we want handler to close dialog also (or not)
                  {
                    if(answer == 'yes')
                    {
                      clearItemSelectionMode() ; // reset any edit toolbars showing
                      dialog.hide() ;
                    }
                    // else you said no, leave dialog in place
                    return ;
                  }.createDelegate(this, [theDialog], true) ) ;
  return retVal ;
}

function toggleIconHover(elem, forceHover)
{
  var eElem = Ext.get(elem) ;
  if(forceHover)
  {
    eElem.addClass('toolBarIconHover') ;
  }
  else
  {
    eElem.toggleClass('toolBarIconHover') ;
  }
  return ;
}

function toggleDiv(divId, anchor)
{
  if(!$(divId) || !anchor) // then nothing to do or called wrong
  {
    return ;
  }
  else
  {
    Effect.toggle(  divId,
                    'blind',
                    {
                      afterFinish: function()
                      {
                        if($(divId).visible())
                        {
                          anchor.style.backgroundImage = 'url(/images/vgpMinus.gif)' ;
                        }
                        else
                        {
                          anchor.style.backgroundImage = 'url(/images/vgpPlus.gif)' ;
                        }
                      }
                    }) ;
    return ;
  }
}


function displayLoadingMsg(loadingMsg) {
  isEditMode = true ;
  var maskDiv = document.createElement('div') ;
  maskDiv.setAttribute('id', 'genboree-loading-mask') ;
  maskDiv.setAttribute('name', 'genboree-loading-mask') ;
  var loadMsgDiv = document.createElement('div') ;
  loadMsgDiv.setAttribute('id', 'genboree-loading') ;
  loadMsgDiv.setAttribute('name', 'genboree-loading') ;
  loadMsgDiv.innerHTML = '<div class="genboree-loading-indicator" style="height:100px;">'+loadingMsg+'</div>';
  loadMsgDiv.style.width = "430px" ;
  loadMsgDiv.style.left = "30%" ;

  var bodyElems = document.getElementsByTagName('body') ;
  var bodyElem = bodyElems[0] ;
  bodyElem.insertBefore(loadMsgDiv, bodyElem.firstChild) ;
  bodyElem.insertBefore(maskDiv, bodyElem.firstChild) ;
  maskDiv.style.width = "100%" ;
  maskDiv.style.height = "100%" ;
  maskDiv.style.background = "#e1c4ff" ;
  maskDiv.style.position = "absolute" ;
  maskDiv.style['z-index'] = "20000" ;
  maskDiv.style.left = "0px" ;
  maskDiv.style.top = "0px" ;
  maskDiv.style.opacity = "0.5" ;
}

function clearLoadingMsg() {
  $('genboree-loading-mask').style.display = 'none';
  $('genboree-loading').style.display = 'none';
}
