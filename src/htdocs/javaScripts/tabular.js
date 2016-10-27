/**
 * The following variables will be set during AJAX apiCaller calls to
 * store necessary information for the new REST API AJAX support.
 */
var grpName = "" ;
var dbName = "" ;

/**
 * This method is used by the dynamic table sizing widgets on the 
 * tabularDisplay.jsp page.  The values are read from the UI components.
 */
function updateTableSize()
{
  var minW = 670 ;
  var minH = 3 * ($(tabularGrid.getTopToolbar().getEl()).getHeight()) +
    $(tabularGrid.getView().getRow(0)).getHeight() * 5 ;
  var w = 670 ;
  var h = 620 ;
  if($('table-width')) w = parseInt($('table-width').value) ;
  if($('table-height')) h = parseInt($('table-height').value) ;

  // Modify values for show all rows / columns
  if($('table-all-rows').checked)
  {
    // The 3 is for the 3 header rows, the +1 is for an added row to fit in a
    // scrollbar, if it is visible (no easy way to tell).
    h = 3 * $(tabularGrid.getTopToolbar().getEl()).getHeight() +
      ((tabularGrid.getTopToolbar().pageSize + 1) * $(tabularGrid.getView().getRow(0)).getHeight()) ;
  }
  if($('table-all-cols').checked)
  {
    // Measure all column widths
    w = 5 ;  // Initial space to ensure no scrollbar
    for(var col = 0; col < tabularGrid.getColumnModel().getColumnCount(); col++)
      w += tabularGrid.getColumnModel().getColumnWidth(col) ;
  }
  if(!w || w < minW) w = minW ;
  if(!h || h < minH) h = minH ;

  // Set real values
  $('table-width').value = w ;
  $('table-height').value = h ;

  // Disable components
  $('table-width').disabled = $('table-all-cols').checked ;
  $('table-height').disabled = $('table-all-rows').checked ;

  // Resize the table
  tabularGrid.setSize({height: h, width: w}) ;
}

/**
 * This method color coordinates the selection of the attribute list elements
 * when they are selected for display, sorting, or both using their associated
 * checkboxes.
 */
function colorCode(liObj)
{
  // Error check for object removed prior to this method call
  if(!$(liObj.id + "-display-check") || !$(liObj.id+"-sort-check")) return ;

  if($(liObj.id+"-display-check").checked && $(liObj.id+"-sort-check").checked)
  {
    $(liObj).addClassName("dispsort") ;
    $(liObj).removeClassName("displayed") ;
    $(liObj).removeClassName("sorted") ;
  }
  else if(!$(liObj.id+"-display-check").checked && $(liObj.id+"-sort-check").checked)
  {
    $(liObj).addClassName("sorted") ;
    $(liObj).removeClassName("displayed") ;
    $(liObj).removeClassName("dispsort") ;
  }
  else if($(liObj.id+"-display-check").checked && !$(liObj.id+"-sort-check").checked)
  {
    $(liObj).addClassName("displayed") ;
    $(liObj).removeClassName("dispsort") ;
    $(liObj).removeClassName("sorted") ;
  }
  else
  {
    $(liObj).removeClassName("dispsort") ;
    $(liObj).removeClassName("displayed") ;
    $(liObj).removeClassName("sorted") ;
  }
}

/**
 * Clear out the list of the layouts (except for the defaults).  This is used
 * when the group is changed and before a database is selected.
 * NOTE: The "writeAccess" variable defined above this function is used as a
 * global variable that affects the enabling / disabling of some of the UI
 * controls depending on read/write/owner access.  Valid values are:
 * r : read
 * w : write
 * o : owner
 * If set to an invalid value, only read permissions are assumed.
 */
var writeAccess = "r";
function clearLayouts()
{
  // Empty the list
  $('layout_name_list').update() ;

  // And put in the defaults
  var group = document.createElement('optgroup') ;
  group.setAttribute("label", "Defaults") ;
  var option = document.createElement('option') ;
  option.setAttribute("value", "default") ;
  option.appendChild(document.createTextNode('Default Grouped Layout')) ;
  group.appendChild(option) ;
  option = document.createElement('option') ;
  option.setAttribute("value", "default2") ;
  option.appendChild(document.createTextNode('Default Ungrouped Layout')) ;
  group.appendChild(option);
  $('layout_name_list').appendChild(group) ;
  group = document.createElement('optgroup') ;
  group.setAttribute("label", "Create") ;
  option = document.createElement('option') ;
  if(writeAccess == "w" || writeAccess == "o")
  {
    option.setAttribute("value", "new") ;
    option.appendChild(document.createTextNode('Create New Layout')) ;
  }
  else
  {
    option.setAttribute("value", "temp") ;
    option.appendChild(document.createTextNode('Create Temporary Layout')) ;
  }
  group.appendChild(option) ;
  $('layout_name_list').appendChild(group) ;
  group = document.createElement('optgroup') ;
  group.setAttribute("label", "Saved") ;
  group.id = "layout_name_list_saved" ;
  $('layout_name_list').appendChild(group) ;

  // Now update the other buttons of the interface
  modifyLayout(false) ;
}

/**
 * Appropriately enable and disable the administrative portions of the layout
 * setup page according to the values passed in.
 * @param isOwner
 *  The current user is the owner (administrator) of the current group.  If
 *  this parameter is true, all options are enabled.
 * @param isAuthor
 *  The current user has write access for the current group.  If this
 *  parameter is true, the user only has Create New, and Update components
 *  enabled (Unless isOwner is also true)
 */
function updateLayoutPermission(isOwner, isAuthor)
{
  // Create / Edit options
  if (isAuthor || isOwner)
    $('layout_edit_options').show() ;
  else
    $('layout_edit_options').hide() ;

  // Delete option
  if (isOwner)
    $('layout_delete').show() ;
  else
    $('layout_delete').hide() ;
}

/**
 * Update the layout names in the drop down menu according to the currently
 * selected group / refseq in the session.
 */
function updateLayouts(name)
{ 
  // Update the database select, fill with our new values
  new Ajax.Request("/java-bin/ajax/tabular.jsp?action=list_layouts", 
    {
      onComplete: function(transport)
      {
        // Get the Javascript object using eval()
        var response = eval('(' + transport.responseText + ')') ;

        // Credentials problem, reload our page
        if(response['refresh']) 
        {
          window.location.reload(true) ;
          return ;
        }

        // Put the new layouts in the list
        clearLayouts() ;
        for(var num = 0; num < response.length; num++)
        {
          var option = document.createElement("option") ;
          option.setAttribute("value", "saved-" + response[num].name) ;
          option.appendChild(document.createTextNode(response[num].name)) ;
          $('layout_name_list_saved').appendChild(option) ;
        }
        if(name)
        {
          $('layout_name_list').value = "saved-" + name;
          applyLayout(name) ;
        }
        else
        {
          applyLayout("default") ;
        }
      }
    }
  ) ;
}

/**
 * Handle the state of the group settings when the checkbox for using groups
 * clicked.  We will disable the verbose/terse mode radio buttons unless the
 * use groups checkbox is checked.
 * @param checkbox
 *   The useGroupMode checkbox.
 */
function handleGroupClick(checkbox)
{
  if ($('verboseGroupMode')) $('verboseGroupMode').disabled = !checkbox.checked ;
  if ($('terseGroupMode')) $('terseGroupMode').disabled = !checkbox.checked ;
  modifyLayout(true) ;
}

/**
 * Handle the deletion of a layout using AJAX.
 */
function handleLayoutDelete()
{
  var layoutName = $('layout_name_list').value ;
  if(layoutName == "default" || layoutName == "default2")
  {
    alert("You cannot delete the default layouts.") ;
    return ;
  }
  else if(layoutName == "new" || layoutName == "temp")
  {
    alert("You cannot delete an unsaved layout.") ;
    return ;
  }
  else if(layoutName.match(/^saved-.*/))
  {
    layoutName = layoutName.substring(6) ;
  }

  var del = confirm("Are you should you want to delete the layout '" + layoutName + "'?") ;
  if(del)
  {
    new Ajax.Request("/java-bin/ajax/tabular.jsp?action=delete_layout&layoutName=" + escape(layoutName),
      {
        onComplete: function(transport)
        {
          // Get the Javascript object using eval()
          var response = eval('(' + transport.responseText + ')') ;

          // Credentials problem, reload our page
          if(response['refresh'])
          {
            window.location.reload(true) ;
            return ; 
          }

          // Redo the layout drop down
          updateLayouts() ;
        }
      }
    ) ;
  }
}

/**
 * Handle the click of the 'Save / Update' button from the UI.
 */
function handleLayoutSave()
{
  var layoutName = $('layout_name_list').value ;
  
  // Check for invalid save / updates
  if(layoutName == "default" || layoutName == "default2")
  {
    alert("You cannot save the default layouts.") ;
    return false ;
  }
  else if(layoutName == "temp")
  {
    alert("You cannot save a temporary layout.") ;
    return false ;
  }

  // Now get a proper layout name
  if(layoutName == "new") layoutName = $('layout_create_name').value ;
  if(layoutName.match(/^\s*$/))
  {
    alert("You must specify a name for this layout") ;
    $('layout_create_name').focus() ;
    $('layout_create_name').select() ;
    return false ;
  }
  else if(layoutName.match(/^saved-.*/))
  {
    // Update an existing layout only when changed
    if(modifiedLayout)
    {
      layoutName = layoutName.substring(6) ;
    }
    else
    {
      alert("You have not made any changes to this layout.") ;
      return false ;
    }
  }

  // Finally perform the save
  if($("layout_name_feedback").visible())
    Effect.BlindUp("layout_name_feedback", 
      { 
        duration: .5,
        queue: 'end',
        afterFinish: function() { doHandleLayoutSave(layoutName) }
      }
    ) ;
  else
    doHandleLayoutSave(layoutName) ;
}

/**
 * Helper method to allow for proper event timing when hiding the feedback
 * div if it is visible before the call to this method.
 */
function doHandleLayoutSave(layoutName)
{
  new Ajax.Request("/java-bin/ajax/tabular.jsp?action=save_layout&" + generateParams(),
    {
      onFailure: function(transport)
      {
        $('layout_name_feedback').update("<div class='failure'>Problem saving the layout<br>" +
          transport.responseText + "</div>") ;
        Effect.BlindDown("layout_name_feedback", { queue: 'end'} ) ;
      },
      onSuccess: function(transport)
      {
        // Get the Javascript object using eval()
        var response = eval('(' + transport.responseText + ')') ;

        if(response['success'] == "update")
        {
          $('layout_name_feedback').update("<div class='success'>The layout '" +
            layoutName + "' was updated successfully.</div>") ;
          Effect.BlindDown("layout_name_feedback", { queue: 'end'}) ;
          modifyLayout(false) ;
        }
        else if(response['success'])
        {
          $('layout_name_feedback').update("<div class='success'>The layout '" +
            layoutName + "' was saved successfully.</div>") ;
          Effect.BlindDown("layout_name_feedback", { queue: 'end'}) ;

          // Add the new layout to the list (assume others have not changed)
          var option = document.createElement("option") ;
          option.setAttribute("value", "saved-" + layoutName) ;
          option.appendChild(document.createTextNode(layoutName)) ;
          $('layout_name_list_saved').appendChild(option) ;
          $('layout_name_list').value = "saved-" + layoutName ;
          modifyLayout(false) ;
        }
        else if(response['error'])
        {
          $('layout_name_feedback').update("<div class='failure'>There was a problem " +
            "while saving the layout:<br><br>" + response['error']) ;
          Effect.BlindDown("layout_name_feedback", { queue: 'end'}) ;
        }
        else
        {
          $('layout_name_feedback').update("<div class='failure'>There was an " +
            "unknown problem while trying to save the layout.  Please try again " +
            "later.  If this problem persists, please contact the System Administrator.") ;
          Effect.BlindDown("layout_name_feedback", { queue: 'end'}) ;
        }
      }
    }
  ) ;
}

/**
 * Handle the selection of a layout from the drop-down list.
 */
function handleLayoutChange()
{
  if($('layout_name_list').value.match(/^saved-.*/))
  {
    applyLayout($('layout_name_list').value.substring(6)) ;
  }
  else if($('layout_name_list').value.match(/^default.?/))
  {
    applyLayout($('layout_name_list').value) ;
  }
  else
  {
    // New or temp layout
    modifyLayout(true) ;
  }
}

/**
 * This method manages the attribute lists and the associated display and sort
 * order lists.  When (de)selecting an attribute for display or sorting, this
 * method will add or remove that attribute from the appropiate list and mark
 * the current layout as 'modified'.
 *
 * If this change was made internally (by a layout change or page load), the
 * layoutChange variable should be set to true in order to keep the layout from
 * getting marked as 'modified' and also skipping the visual cue normally
 * made when the user clicks a selected check box.
 *
 * @param list
 *   The list to add / remove this attribute from.  Tabular.js ensures that the
 *  correct list is passed to this function.
 * @param chk
 *   The checkbox associated with the attribute to change.
 * @param layoutChange
 *   A flag used internally to disable the default behavior of marking the
 *   current layout as modified whenever this method is called.
 */
function control(list, chk, layoutChange)
{
  // Determine our values
  var id = $(chk).value + "-" + $(list).id;
  var value = $(chk).value;
  var name = $(chk).value.substring(1) ;
  var rent = $(chk).up() ;

  if($(chk).checked)
  {
    var li = document.createElement('li') ;

    if($(rent).hasClassName("empty"))
    {
      $(li).addClassName("empty") ;
      name = "( " + name + " )" ;
      $(chk).disabled = false ;
    }
    li.setAttribute('id', id) ;
    li.appendChild(document.createTextNode(name)) ;
    if(document.all)
    {
      li.onmouseover = function() { $(this).addClassName("hover") ; } ;
      li.onmouseout = function() { $(this).removeClassName("hover") ; } ;
    }

    var input = document.createElement('input') ;
    input.setAttribute('type', 'hidden') ;
    input.setAttribute('value', value.replace(/,/g, "\\,")) ;

    // Only add the element to the lists if it isn't already there (bug)
    if(!($(id)))
    {
      $(li).appendChild(input) ;
      $(list).appendChild(li) ;
    }
  }
  else if(!$(chk).checked && $(rent).hasClassName("empty"))
  {
    // Check if parent is empty, and unselected (then remove it)
    var children = $(rent).childNodes ;
    var isUnchecked = true ;
    for(var kid = 0; kid < children.length; kid++)
      if(children[kid].checked)
        isUnchecked = false ;
    if(isUnchecked) $(rent).remove() ;
    else $(chk).disabled = true ;

    // Remove attribute
    if($(id)) $(id).remove() ;
  }
  else
  {
    // Remove attribute
    if($(id)) $(id).remove() ;
  }

  // Update the Sortables
  // NOTE: Could use onUpdate if li's ids are changed to conform to 
  // script.aculo.us Sortable.serialize
  Sortable.create(list, { onChange : function(container) { modifyLayout(true) ; }}) ;

  // Visual cue
  if(!layoutChange)
  {
    modifyLayout(true) ;
    new Effect.Highlight(list, {queue: {scope: list, limit: 1}}) ;
  }
}

/**
 * Setup the specialized checklists used by tabular.jsp.  These checklists are
 * unordered lists, but meant to function more list a multi-select.  They
 * provide a hover highlight, and vertical scrollbar all through CSS.
 */
function initChecklists() 
{
  if(document.all && document.getElementById) 
  {
    // Get all unordered lists of type checklist
    var lists = $$("ul.checklist") ;
        
    for(i = 0; i < lists.length; i++) 
    {
      var items = lists[i].getElementsByTagName("li") ;
              
      // Assign event handlers to labels within
      for(var j = 0; j < items.length; j++) 
      {
        items[j].onmouseover = function() { $(this).addClassName("hover") ; } ;
        items[j].onmouseout = function() { $(this).removeClassName("hover") ; } ;
      }
    }
  }
}

/**
 * Handle the modification status of the active layout.
 * NOTE: The "modifiedLayout" variable defined above this function is used as a
 * global variable that allows for temporary layouts when the user doesn't have
 * access to save layouts, or chooses not to save their settings.
 */
var modifiedLayout = false ;
function modifyLayout(changed)
{
  modifiedLayout = changed ;
  if(changed && writeAccess == "r")
  {
    $('layout_name_list').value = "temp" ;
  }
  else if(changed)
  {
    if($('layout_name_list').value.match(/^default.?/))
    {
      if(!$('layout_create_name_label').visible())
        Effect.Appear("layout_create_name_label") ;
      $('layout_name_list').value = "new" ;
      $("layout_modified").hide() ;
    }
    else if($('layout_name_list').value.match(/^saved-.*/))
    {
      if($('layout_create_name_label').visible())
        Effect.Fade('layout_create_name_label') ;
      $("layout_create_name").value = "" ;
      $("layout_modified").show() ;
    }
    else
    {
      if(!$('layout_create_name_label').visible())
        Effect.Appear("layout_create_name_label") ;
      $("layout_modified").hide() ;
    }
  }
  else
  {
    if($('layout_name_list').value == "new" && !$('layout_create_name_label').visible())
    {
      Effect.Appear('layout_create_name_label') ;
    }
    else if($('layout_name_list').value != "new" && $('layout_create_name_label').visible())
    {
      Effect.Fade('layout_create_name_label') ;
      $("layout_create_name").value = "" ;
    }
    $("layout_modified").hide() ;
  }

  // Now the save / update, delete buttons
  if(writeAccess == "o")
  {
    if($('layout_name_list').value.match(/^default.?/))
      $('layout_save_update').setAttribute("disabled", "disabled") ;
    else
      $('layout_save_update').removeAttribute("disabled") ;
    if($('layout_name_list').value.match(/^saved-.*/))
      $('layout_delete').removeAttribute("disabled") ;
    else
      $('layout_delete').setAttribute("disabled", "disabled") ;
  }
  else if(writeAccess == "w")
  {
    if($('layout_name_list').value.match(/^default.?/))
      $('layout_save_update').setAttribute("disabled", "disabled") ;
    else
      $('layout_save_update').removeAttribute("disabled") ;
    $('layout_delete').setAttribute("disabled", "disabled") ;
  }
  else
  {
    $('layout_save_update').setAttribute("disabled", "disabled") ;
    $('layout_delete').setAttribute("disabled", "disabled") ;
  }

  // Feedback is now stale
  if($("layout_name_feedback").visible())
    Effect.BlindUp("layout_name_feedback", { queue: 'end'});
}

/**
 * Using the two JSON arrays, update the buttons of the layout controls to
 * reflect the this particular layout setup.
 * NOTE: The default and default2 layouts are defined globally in this file.
 */
var defaultLayout = new Object();
defaultLayout['columns'] = "lName,lType,lSubtype,lEntry Point,lStart,lStop" ;
defaultLayout['sort'] = "lEntry Point,lStart" ;
defaultLayout['groupMode'] = "terse" ;
var defaultLayout2 = new Object();
defaultLayout2['columns'] = "lName,lType,lSubtype,lEntry Point,lStart,lStop" ;
defaultLayout2['sort'] = "lEntry Point,lStart" ;
function applyLayout(name)
{
  if(name == "default")
  {
    doApplyLayout(defaultLayout) ;
  }
  else if(name == "default2")
  {
    doApplyLayout(defaultLayout2) ;
  }
  else
  {
    // Read the layout from the server
    new Ajax.Request("/java-bin/ajax/tabular.jsp?action=read_layout&layoutName=" + escape(name),
      {
        onComplete: function(transport)
        {
          // Get the Javascript object using eval()
          var response = eval('(' + transport.responseText + ')') ;

          // Credentials problem, reload our page
          if(response['refresh'])
          {
            window.location.reload(true) ;
            return ; 
          }

          doApplyLayout(response) ;
        }
      }
    ) ;
  }
}

/**
 * Helper function to actually apply a layout after it is read from the server.
 */
function doApplyLayout(layout)
{
  // Apply the group mode of the layout
  $('useGroups').checked = (layout['groupMode'] == "terse" || layout['groupMode'] == "verbose") ;
  $('terseGroupMode').disabled = !($('useGroups').checked) ;
  $('verboseGroupMode').disabled = !($('useGroups').checked) ;
  if(layout['groupMode'])
  {
    $('terseGroupMode').checked = (layout['groupMode'] == "terse") ;
    $('verboseGroupMode').checked = (layout['groupMode'] == "verbose") ;
  }

  // Remove all currently checked options
  items = $('default_attributes').getElementsByTagName("li") ;
  for(var li = 0; li < items.length; li++)
  {
    $(items[li].id + "-display-check").checked = false ;
    $(items[li].id + "-sort-check").checked = false ;
    colorCode(items[li]) ;
  }
  items = $('all_attributes').getElementsByTagName("li") ;
  for(var li = items.length - 1; li >= 0; li--)
  {
    $(items[li].id + "-display-check").checked = false ;
    $(items[li].id + "-sort-check").checked = false ;
    colorCode(items[li]) ;
    if($(items[li]).hasClassName("empty")) $(items[li]).remove() ;
  }

  // Apply the columns and sort of the layout
  $('display_order').update() ;
  $('sorting_order').update() ;
  var display = layout['columns'].split(",") ;
  for(var num = 0; num < display.length; num++)
  {
    if(!$(display[num]))
      addUserAttribute(display[num], true) ;
    $(display[num] + '-display-check').checked = true ;
    control('display_order', $(display[num] + '-display-check'), true) ;
  }

  if(layout["sort"])
  {
    var sort = layout['sort'].split(",") ;
    for(var num = 0; num < sort.length; num++)
    {
      if(!$(sort[num]))
        addUserAttribute(sort[num], true) ;
      $(sort[num] + '-sort-check').checked = true ;
      control('sorting_order', $(sort[num] + '-sort-check'), true) ;
    }
  }

  // Reset the modification status
  modifyLayout(false) ;
}

/**
 * Initialize the page to its defaults (mainly the Step 2 inputs and settings)
 */
function initTabularSetup(write)
{
  writeAccess = write ;
  Position.includeScrollOffsets = true ;
  Sortable.create('display_order') ;
  Sortable.create('sorting_order') ;
  initChecklists() ;

  if($('layout_name_list').value.match(/^default.?/))
    applyLayout($('layout_name_list').value) ;
  else if($('layout_name_list').value.match(/^saved-.*/))
    applyLayout($('layout_name_list').value.substring(6)) ;
  else
    modifyLayout(true) ;
}

/**
 * Update the selected Entry Point and query for and display the minimum
 * and maximum Start and Stop positions that can be used.
 */
function updateEntryPoint(epName)
{
  if(epName == "all")
  {
    $("entry_point_min").hide() ;
    $("entry_point_max").hide() ;
    $("ep_start").value = "" ;
    $("ep_stop").value = "" ;
    $("ep_start").disable() ;
    $("ep_stop").disable() ;
  }
  else
  {
    // Use API Caller to get the max start/stop
    var escapedRestUri = encodeURIComponent('/REST/v1/grp/' + encodeURIComponent(grpName) + 
      '/db/' + encodeURIComponent(dbName) + '/ep/' + encodeURIComponent(epName)) ;

    new Ajax.Request('/java-bin/apiCaller.jsp?rsrcPath=' + escapedRestUri + '&method=GET', {
      method : 'get',
      onSuccess : function(transport) {
        var restData = eval('('+transport.responseText+')') ;
        
        if(restData["data"]["length"])
        {
          $("entry_point_min").update("Min: 1") ;
          $("entry_point_min").show() ;
          $("ep_start").value = "1" ;
          $("ep_start").enable() ;
          $("entry_point_max").update("Max: " + restData["data"]["length"]) ;
          $("entry_point_max").show() ;
          $("ep_stop").value = restData["data"]["length"] ;
          $("ep_stop").enable() ;
        }
      }
    }) ;
  }
}

/**
 * Update the list of selected tracks in the session (tabularTracks) and
 * query the AJAX provider for a list of all attributes for all of the
 * selected tracks, for the User-Defined attribute list.
 * @param select
 *   The multi-select box used to select the track names in the UI.
 */
function updateTrack(select)
{
  // Build the URL with the selected track list
  var url = "/java-bin/ajax/tabular.jsp?action=update_track_selection" ;
  if (getTrackNameString()) url += "&" + getTrackNameString();

  // Now get the new attribute list
  if($('all_attributes'))
  {
    $('all_attributes').update("") ;
    var myMask = new Ext.LoadMask(Ext.get('all_attributes'), {msg: "Loading..."}) ;
    myMask.show() ;
  }
  new Ajax.Request(url,
    {
      onComplete: function(transport)
      {
        // Get the Javascript object using eval()
        var response = eval('(' + transport.responseText + ')') ;

        // Credentials problem, reload our page
        if(response['refresh'])
        {
          window.location.reload(true) ;
          return ; 
        }

        // Put the new attribute names in the ul.checklist
        var attrs = response['attributes'] ;
        var options = "" ;
        for(var num = 0; num < attrs.length; num++)
        {
          options += "<li id='a" + attrs[num] + "' onclick='colorCode(this)'>\n" ;
          options += "<input type='checkbox' title='Display' id='a" + attrs[num] + "-display-check' " ;
          if($("a" + attrs[num] + "-display_order")) options += "checked " ;
          options += "onclick='control(\"display_order\", this)'" ;
          options += "value='a" + attrs[num] + "'>\n" ;
          options += "<input type='checkbox' title='Sort' id='a" + attrs[num] + "-sort-check' " ;
          if($("a" + attrs[num] + "-sorting_order")) options += "checked " ;
          options += "onclick='control(\"sorting_order\", this)'" ;
          options += "value='a" + attrs[num] + "'>\n" ;
          options += attrs[num] + "\n</li>\n" ;
        }
        if($('all_attributes')) $('all_attributes').update(options) ;

        // Now ensure the display_order and sorting_order lists are in sync
        // First mark items for deletion
        var items = $('display_order').getElementsByTagName("li") ;
        var removedItems = new Array() ;
        for(var loop = 0; loop < 2; loop++)
        {
          for(var li = 0; li < items.length; li++)
          {
            var hidden = items[li].getElementsByTagName("input") ;
            if(hidden.length != 1) continue ;
            if(hidden[0].value.charAt(0) == "l") continue ;
            var found = false ;
            for(var num = 0; num < attrs.length; num++)
            {
              if(("a" + attrs[num]) == hidden[0].value) found = true ;
            }

            // Handle switching from "empty" to "normal"
            if(!found)
            {
              $(items[li]).addClassName("empty") ;
              var newText = "( " + hidden[0].value.substring(1) + " )" ;
              $(items[li]).replaceChild(document.createTextNode(newText), $(items[li]).firstChild) ;

              // Check for already existing item
              if(removedItems.indexOf(hidden[0].value) == -1)
                removedItems.push(hidden[0].value) ;
            }
            else if($(items[li]).hasClassName("empty"))
            {
              $(items[li]).removeClassName("empty") ;
              var newText = hidden[0].value.substring(1) ;
              $(items[li]).replaceChild(document.createTextNode(newText), $(items[li]).firstChild) ;
            }
          }
          items = $('sorting_order').getElementsByTagName("li") ;
        }

        // Now restore removedItems with the "empty" class
        for(var num = 0; num < removedItems.length; num++)
        {
          addUserAttribute(removedItems[num], true) ;
        }
          
        // Hide mask (because the update method didn't destroy it)
        var myMask = new Ext.LoadMask(Ext.get('all_attributes')) ;
        myMask.hide() ;
      }
    }
  ) ;
}

/**
 * Helper function to add a User-Defined attribute with proper <li> to the 
 * $("all_attributes") unordered list (checklist).  This is done in several
 * places so it is useful to have a single function to create these elements.
 * @param attribute
 *   The name of the attribute (encoded with leading "a")
 * @param empty
 *   Boolean. True if you want the User-Defined Attribute to be "empty"
 */
function addUserAttribute(attribute, empty)
{
  var li = document.createElement("li") ;
  if(empty) $(li).addClassName("empty") ;
  li.id = attribute ;
  li.setAttribute("onclick", "colorCode(this)") ;
  var input = document.createElement("input") ;
  input.type = "checkbox" ;
  input.id = attribute + "-display-check" ;
  input.onclick = function() { control("display_order", this) } ;
  input.value = attribute ;
  li.appendChild(input) ;
  if($(attribute + "-display_order"))
    $(input).checked = true ;
  else if(empty)
    input.disabled = true ;
  li.appendChild(document.createTextNode(" ")) ;
  var input2 = document.createElement("input") ;
  input2.type = "checkbox" ;
  input2.id = attribute + "-sort-check" ;
  input2.onclick = function() { control("sorting_order", this) } ;
  input2.value = attribute ;
  li.appendChild(input2) ;
  if($(attribute + "-sorting_order"))
    $(input2).checked = true ;
  else if(empty)
    input2.disabled = true ;
  var text = " " + attribute.substring(1) ;
  li.appendChild(document.createTextNode(text)) ;
  if($('all_attributes')) $('all_attributes').appendChild(li) ;
}

/**
 * Begin a download of the file representing the tabular layout that was
 * just defined using the UI.  This method will always first clear any existing
 * tabular layout that was cached in the session to ensure that the generated
 * file represents the current UI specifications.  This method will notify the
 * user if the number of annotations for the selected tracks is expected to take
 * a significant amount of time to generate the requested file.
 */
function downloadTabularLayout()
{
  var url = generateUrl() ;
  if(!url) return false ;
  url += "&download=true" ;

  new Ajax.Request("/java-bin/ajax/tabular.jsp?action=get_annotation_count&" + getTrackNameString(),
    {
      onComplete: function(transport)
      {
        // Get the Javascript object using eval()
        var response = eval('(' + transport.responseText + ')') ;

        // numAnnotationForWarning and tabularMaxRows get set in the JSP file
        // that included this Javascript code.
        if (response['count'] > tabularMaxRows)
        {
          alert("***WARNING***:\n" +
          "You will not be receiving all of your data!\n\n" +
          "Because of the size of the dataset that you have\n" +
          "selected, we cannot provide the full file for\n" +
          "download.  It will be truncated at " + tabularMaxRows + "\n" +
          "annotations.\n\n" +
          "Please be patient and do not cancel the download,\n" +
          "it will be completed after the table is generated\n" +
          "and sorted.");
        }
        else if (response['count'] > numAnnosForTabularWarning)
        {
          alert("***NOTE***:\n" +
          "Because of the size of the dataset that you have\n" +
          "selected, preparing and sorting the tabular layout\n" +
          "may take some time. Even after your download starts,\n" +
          "it may take some time before the file is transferred\n" +
          "to your system.\n\n" +
          "Please be patient and do not cancel the download,\n" +
          "it will be completed after the table is generated\n" +
          "and sorted.");
        }

        // Perform the download
        document.location = url ;
      }
    }
  ) ;
}

/**
 * Generate the tabular layout that is specified by the UI components.  This
 * method will always clear any cached tabular layout in the session to ensure
 * the generated table is reflecting what was specified by the UI.  This method
 * will warn the user if the selected tracks contain a large enough ammount of
 * annotations that the Table generation is expected to take a significant
 * amount of time.
 */
function generateTabularLayout()
{
  // Check for modified layout and warn user
  if(modifiedLayout && $('layout_name_list').value != "temp")
  {
    Ext.Msg.show(
    {
      title: "Continue Without Saving Layout Modifications?",
      msg: "You have made changes to the layout, but you have not yet<br>" +
        "saved those changes.  Are you sure you would like to continue<br>" +
        "<strong>without saving your changes</strong>?<br><br>" +
        "(In order to save your changes, press 'Cancel' and then use the<br>" +
        "'Save / Update' button in the 'Layout Name' group)",
      buttons: 
      {
        ok: "Continue",
        cancel: "Cancel"
      },
      fn: unsavedLayoutOnDisplay,
      icon: Ext.Msg.QUESTION
    }) ;

    // Exit the method because the Ext message box is async
    return false ;
  }

  // Actually generate the table
  doGenerateTabularLayout()
}

/**
 * Actually perform the generation of the tabular layout table.  This method
 * bypasses the warning displayed by the user when not saving layout
 * modifications.
 */
function doGenerateTabularLayout()
{
  var url = generateUrl() ;
  if(!url) return false ;

  new Ajax.Request("/java-bin/ajax/tabular.jsp?action=get_annotation_count&" + getTrackNameString(),
    {
      onComplete: function(transport)
      {
        // Get the Javascript object using eval()
        var response = eval('(' + transport.responseText + ')') ;

        if(response['refresh']) 
        {
          window.location.reload(true) ;
          return ;
        }

        // numAnnotationForWarning and tabularMaxRows get set in the JSP file
        // that included this Javascript code.
        if (response['count'] > tabularMaxRows)
        {
          alert("***WARNING***:\n" +
          "You will not be viewing all of your data!\n\n" +
          "Because of the size of the dataset that you have\n" +
          "selected, we cannot provide the full Table for\n" +
          "viewing.  It will be truncated at " + tabularMaxRows + "\n" +
          "annotations.\n\n" +
          "Please be patient, your data will appear soon.");
        }
        else if (response['count'] > numAnnosForTabularWarning)
        {
          alert("***NOTE***:\n" +
          "Because of the size of the dataset that you have\n" +
          "selected, preparing and sorting the tabular layout\n" +
          "may take some time. Even after the next page\n" +
          "appears, it may take a few seconds to a few minutes\n" +
          "before your data will appear in the table.\n\n" +
          "Please be patient, your data will appear soon.\n") ;
        }

        // Generate the table
        document.location = url ;
      }
    }
  ) ;
}

/**
 * Generate the GET parameter query string for a call to the layout setup
 * intermediary page, or the tabular AJAX provider.
 */
function generateParams()
{
  // Setup the column definition
  var columns = "" ;
  var items = $('display_order').getElementsByTagName("li") ;
  for(var li = 0; li < items.length; li++)
  {
    var hidden = items[li].getElementsByTagName("input") ;
    if (hidden.length != 1) continue ;
    columns += (li == 0 ? "" : ",") + hidden[0].value ;
  }

  // Setup the sort definition
  var sort = "" ;
  items = $('sorting_order').getElementsByTagName("li") ;
  for(var li = 0; li < items.length; li++)
  {
    var hidden = items[li].getElementsByTagName("input") ;
    if (hidden.length < 1) continue ;
    sort += (li == 0 ? "" : ",") + hidden[0].value ;
  }

  // Group support
  var group = "" ;
  if($('useGroups').checked)
    group = ($('verboseGroupMode').checked ? "verbose" : "terse") ;

  // Layout name
  var layout = $('layout_name_list').value ;
  var update = false ;
  if(layout == "new")
  {
    layout = $('layout_create_name').value ;
  }
  else if(layout.match(/^saved-.*/))
  {
    layout = $('layout_name_list').value.substring(6) ;
    update = true ;
  }

  // Return our values
  var params = "layoutName=" + escape(layout) ;
  if(update) params += "&update=true" ;
  params += "&columns=" + escape(columns) + "&sort=" + escape(sort) ;
  if(group) params += "&groupMode=" + escape(group) ;
  return params ;
}

/**
 * Helper method to generate the query portion of a URL string that represents
 * the tracks that are currently selected by the tabular layout UI.
 */
function getTrackNameString()
{
  // Get the selected tracks
  var tracks = new Array() ;
  for(var opt = 0; opt < $('track_names').length; opt++)
    if($('track_names')[opt].selected)
      tracks.push($('track_names')[opt].value) ;

  // Return the properly formatted string
  var str = "";
  for(var track = 0; track < tracks.length; track++)
    str += (str.length > 0 ? "&" : "") + "trackName=" + escape(tracks[track]) ;
  return str ;
}

/**
 * Generate the URL that can be used to create a tabular layout according to
 * the currently selected options in the UI.
 */
function generateUrl()
{
  var url = "/java-bin/tabularSetup.jsp" ;

  // Setup the layout definition (column / sort / group) 
  var columns = "" ;
  var sort = "" ;
  var group = "" ;
  var layout = "" ;
  if($('layout_name_list').value == "default")
  {
    // Default layout
    columns = defaultLayout['columns'] ;
    sort = defaultLayout['sort'] ;
    group = defaultLayout['groupMode'] ;
  }
  else if($('layout_name_list').value == "default2")
  {
    // Default Ungrouped layout
    columns = defaultLayout2['columns'] ;
    sort = defaultLayout2['sort'] ;
    group = defaultLayout2['group'] ;
  }
  else if($('layout_name_list').value.match(/^saved-.*/) && !modifiedLayout)
  {
    // Handle a saved layout
    layout = $('layout_name_list').value.substring(6) ;
  }
  else
  {
    // Must be either a temporary layout, or modified layout (also temp)
    var items = $('display_order').getElementsByTagName("li") ;
    for(var li = 0; li < items.length; li++)
    {
      var hidden = items[li].getElementsByTagName("input") ;
      if (hidden.length < 1) continue ;
      columns += (li == 0 ? "" : ",") + hidden[0].value ;
    }

    items = $('sorting_order').getElementsByTagName("li") ;
    for(var li = 0; li < items.length; li++)
    {
      var hidden = items[li].getElementsByTagName("input") ;
      if (hidden.length < 1) continue ;
      sort += (li == 0 ? "" : ",") + hidden[0].value ;
    }

    if($('useGroups').checked)
      group = ($('verboseGroupMode').checked ? "verbose" : "terse") ;
  }

  // Entry Point (landmark) specification
  var ep = "" ;
  if($('entry_point_text').value != "all")
  {
    if(!isInteger($('ep_start').value) || !isInteger($('ep_stop').value))
    {
      alert('Entry Point Start and Stop must be positive integers') ;
      if(!isInteger($('ep_start').value))
      {
        $('ep_start').select() ;
        $('ep_start').focus() ;
      }
      else
      {
        $('ep_stop').select() ;
        $('ep_stop').focus() ;
      }
      return false ;
    }
    else if($('ep_start').value > $('ep_stop').value)
    {
      alert('Entry Point Start must be less than Entry Point Stop') ;
      $('ep_start').select() ;
      $('ep_start').focus() ;
      return false ;
    }

    ep = $('entry_point_text').value + ":" + $('ep_start').value + "-" + $('ep_stop').value ;
  }

  // Check for bad values
  if(getTrackNameString().length == 0) 
  {
    // No tracks selected
    $('track_names').scrollTo() ;
    $('track_names').focus() ;
    alert("You must select at least one track first") ;
    return false ;
  }
  if(!columns && !layout)
  {
    // No columns displayed
    $('tabular_columns').scrollTo() ;
    $('tabular_columns').focus() ;
    alert("You must select either a saved layout, or at least one column for display") ;
    return false ;
  }

  // Setup the URL
  url += "?" + getTrackNameString() ;
  if(ep) url += "&landmark=" + escape(ep) ;
  if(columns)
  {
    url += "&columns=" + columns ;
    if (sort)  url += "&sort=" + escape(sort);
    if (group) url += "&groupMode=" + escape(group) ;
  }
  else
  {
    url += "&layoutName=" + escape(layout) ;
  }

  // Return the complete URL
  return url ;
}

/**
 * Helper method to handle the Ext-JS message box for unsaved layout alerts.
 * This method is specifically for displaying (not downloading) a table,
 * since the Table downloading does not cause a page refresh and thus would
 * not cause a user to lose their layout changes.
 */
function unsavedLayoutOnDisplay(buttonId, text, opt)
{
  if(buttonId == "ok")
  {
    doGenerateTabularLayout() ;
  }
  else if(buttonId == "cancel")
  {
    // Do nothing
    return false ;
  }
}

/**
 * Helper method for validating the entry Point inputs.
 * Returns true for any positive integer strings.
 */
function isInteger(s) 
{
  return (s.toString().search(/^[0-9]+$/) == 0);
}

/**
 * Clear the cached Tabular Layout from the Session so that it can be garbage
 * collected, if needed.
 */
function clearCachedTable()
{
  new Ajax.Request("/java-bin/ajax/tabular.jsp?action=clear_cached_table", {asynchronous: false}) ;
}

/**
 * Edit button support.  This method was heavily adapted from the original
 * tabular layout implementation.  It has been compacted and stream-lined, and
 * no longer builds all buttons after the page has loded.  Buttons are now
 * built on request and inserted into the page inline.  Also, this method
 * has been updated for Ext 2.2.
 */
function buildEditButton(buttonDiv, upfid, group)
{
  var menuItems = new Array() ;
  upfid = "?upfid=" + upfid ;

  // Add the link to the edit menu page first
  menuItems.push(
    {
      text: 'Edit Menu Page',
      handler: function() { newWin("/java-bin/annotationEditorMenu.jsp" + upfid) ; }
    }
  ) ;

  // Unless group mode, add the individual edit links
  if(!group)
  {
    menuItems.push(
      '-',
      {
        text: '(Re)Assign Anno.',
        handler: function() { newWin("/java-bin/reassignAnnotation.jsp" + upfid) ; }
      },
      {
        text: 'Create Anno.',
        handler: function() { newWin("/java-bin/createAnnotation.jsp" + upfid) ; }
      },
      {
        text: 'Delete Anno.',
        handler: function() { newWin("/java-bin/delAnnotationEditor.jsp" + upfid) ; }
      },
      {
        text: 'Duplicate Anno.',
        handler: function() { newWin("/java-bin/duplicateAnnotation.jsp" + upfid) ; }
      },
      {
        text: 'Edit Anno.',
        handler: function() { newWin("/java-bin/annotationEditor.jsp" + upfid) ; }
      },
      {
        text: 'Shift Anno.',
        handler: function() { newWin("/java-bin/annotationShift.jsp" + upfid) ; }
      }
    ) ;
  }
  // Regardless, add the group edit links
  menuItems.push(
    '-',
    {
      text: '(Re)Assign Group ',
      handler: function() { newWin("/java-bin/reassignGroupAnnotation.jsp" + upfid) ; }
    },
    {
      text: 'Delete Group ',
      handler: function() { newWin("/java-bin/delAnnotationGroup.jsp" + upfid) ; }
    },
    {
      text: 'Duplicate Group ',
      handler: function() { newWin("/java-bin/duplicateGroupAnnotation.jsp" + upfid) ; }
    },
    {
      text: 'Edit Group ',
      handler: function() { newWin("/java-bin/annotationGroupEditor.jsp" + upfid) ; }
    },
    {
      text: 'Rename Group ',
      handler: function() { newWin("/java-bin/renameGroupAnnotation.jsp" + upfid) ; }
    },
    {
      text: 'Shift Group ',
      handler: function() { newWin("/java-bin/annotationGroupShift.jsp" + upfid) ; }
    },
    {
      text: 'Set Group Color ',
      handler: function() { newWin("/java-bin/changeGroupColor.jsp" + upfid) ; }
    },
    '-',
    {
      text: 'Add Attributes to Group ',
      handler: function() { newWin("/java-bin/addGroupAVP.jsp" + upfid) ; }
    },
    {
      text: 'Add Comments to Group ',
      handler: function() { newWin("/java-bin/commentGroupAnnotations.jsp" + upfid) ; }
    }
  ) ;
  // Now create menu object using the menuItems array
  var menu =  new Ext.menu.Menu(
    {
      items: menuItems
    }) ;
  
  // Create the button
  if(Ext.get(buttonDiv))
  {
    new Ext.SplitButton(
      {
        renderTo: buttonDiv,
        text: '<span class="x-btn-text-span">Edit</span>',
        handler: function() 
        {
          if(group)
            newWin("/java-bin/annotationGroupEditor.jsp" + upfid) ;
          else
            newWin("/java-bin/annotationEditor.jsp" + upfid) ;
        },
        cls: 'x-btn-text-icon blist',
        menu: menu
      }
    ) ;
  }
}

/**
 * Helper method to open a new window and grab focus.  Copied from the original
 * tabular layout implementation.
 */
var trgWinHdl = null ;
function newWin(trgWinUrl, trgWinName)
{
  if(trgWinName == null) trgWinName = "_newWin" ;

  // Open the new window or tab
  if(!trgWinHdl || trgWinHdl.closed)
    trgWinHdl = window.open(trgWinUrl, trgWinName, '') ;
  else
    trgWinHdl.location = trgWinUrl;

  // Focus the window
  if(trgWinHdl && window.focus)
    trgWinHdl.focus() ;

  return false ;
}
