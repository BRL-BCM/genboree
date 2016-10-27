/**
 * File:
 *   ajax.js
 * Description:
 *   This file provides a collection of functions for the AJAX enabled widgets
 *   (mostly the files in /java-bin/includes/ajax/*.incl).  The functions 
 *   communicate with various providers (in java-bin/ajax/*.jsp) to perform
 *   actions, modify session state, and access data.  The data payload of the 
 *   communication between the widgets and the providers is intended to be 
 *   encapsulated in JSON objects to simplify management and data transfer.
 *   Many of the providers handle errors by sending { 'refresh' : true } as a
 *   response.  This is intended to cause the page that contains the AJAX
 *   widget to perform a full page refresh in order to regenerate its data.
 * Dependancies:
 *   prototype.js
 *   json.js
 *
 * June 27, 2008
 * sgdavis@bioneos.com
 */

/**
 * Set the group in the session to a new value.  If a label is provided,
 * update the html of the label to reflect the new access level.
 * @param groupId
 *   The id of the group to change into.
 * @param label
 *   The id of the container to update.
 */
function updateGroup(groupId, label)
{
  if(!groupId) return ;

  // TODO: What should we do to handle errors during the ajax communication?
  //   we could just force a page refresh, but that would not be very
  //   informative for the users...  SGD
  if ($(label)) $(label).update("") ;
  new Ajax.Request("/java-bin/ajax/group.jsp?action=update&groupId="+groupId,
    {
      onComplete : function(transport)
      {
        // Get the Javascript object using eval()
        var response = eval('(' + transport.responseText + ')') ;

        // Credentials problem, reload our page
        if(response['refresh'])
        {
          window.location.reload(true) ;
          return ;
        }

        // Success!  update the label
        if($(label))
        {
          if (response['accessLevel'] == 'o') $(label).update('ADMINISTRATOR') ;
          else if (response['accessLevel'] == 'w') $(label).update('AUTHOR') ;
          else if (response['accessLevel'] == 'r') $(label).update('SUBSCRIBER') ;

          grpName = response['name'] ;
          // NOTE: this is only used on the tabular layout page, but is
          // necessary for proper function.
          writeAccess = response['accessLevel'] ;
        }

        // Now get the new DB names
        updateDatabases() ;

        // Note: This is only needed on the tabular layout pages, so check for
        // the function definition first
        if(clearLayouts) 
          clearLayouts() ;
        if(applyLayout)
          applyLayout("default") ;
        if(updateLayoutPermission) 
          updateLayoutPermission(response['accessLevel'] == 'o', response['accessLevel'] == 'w') ;
      }
    }
  ) ;
}

/**
 * Update the dropdown of database names to reflect the current databases
 * associated with the active group.  This action is only performed if the
 * AJAX database bar widget (databaseBar.incl) has been inserted into the
 * currently loaded webpage.
 */
function updateDatabases()
{
  if($('rseq_id'))
  {
    // Clear all labels
    if($('databaseAccessLabel')) $('databaseAccessLabel').update("") ;
    if($('trackNumberLabel')) $('trackNumberLabel').update("Please select a database...") ;
    if($('track_names')) $('track_names').update("") ;
    if($('all_attributes')) $('all_attributes').update("") ;
    if($('entry_point_min')) $('entry_point_min').hide() ;
    if($('entry_point_max')) $('entry_point_max').hide() ;
    clearEntryPoints() ;
    if($('entry_point'))
    {
      var option = document.createElement('option') ;
      option.appendChild(document.createTextNode('Please select a database first...')) ;
      $('entry_point').update() ;
      $('entry_point').appendChild(option) ;
    }

    // Update the database select, fill with our new values
    new Ajax.Request("/java-bin/ajax/database.jsp?action=list",
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

          // Put the new database names in the select
          $('rseq_id').update() ;
          var option = document.createElement('option') ;
          option.appendChild(document.createTextNode('--- Please select ---')) ;
          option.setAttribute('value', '') ;
          $('rseq_id').appendChild(option) ;
          for(var num = 0; num < response.length; num++)
          {
            option = document.createElement('option') ;
            option.setAttribute('value', response[num]['id']) ;
            option.appendChild(document.createTextNode(response[num]['name'])) ;
            $('rseq_id').appendChild(option) ;
          }
        }
      }
    ) ;
  }
}

/**
 * Set the database in the session to a new value.  If a label is provided,
 * update the html of the label to reflect the access level of the database.
 * @param refSeqId
 *   The id of the database to change to in the session.
 * @param label
 *   The id of the container to update with an access level description.
 */
function updateDatabase(refSeqId, label)
{
  // Deselect the database when refseqId is missing
  if(!refSeqId)
  {
    if($('trackNumberLabel')) $('trackNumberLabel').update("&nbsp;") ;
    if($('track_names')) $('track_names').update() ;
    if($('all_attributes')) $('all_attributes').update("") ;
    clearEntryPoints() ;
    if(updateLayouts) updateLayouts() ;
    return ;
  }

  // Update the database select, fill with our new values
  new Ajax.Request("/java-bin/ajax/database.jsp?action=update&refSeqId=" + refSeqId,
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

        // Set our access label
        if($(label))
        {
          if(response['id'])
          {
            $(label).update(response['accessLevel'].toUpperCase()) ;
            dbName = response['name'] ;
          }
          else
          {
            $(label).update("") ;
            if ($('rseq_id')) $('rseq_id').descendants()[0].selected = 'true' ;
          }
        }

        // Now update the track and entry point names
        updateTracks() ;
        updateEntryPoints() ;

        // Note: This is only needed on the tabular layout pages, so check for
        // the function definition first
        if(updateLayouts) updateLayouts() ;
      }
    }
  ) ;
}

/**
 * Update the track listing in the multiple select with id='track_names'.  If
 * this element cannot be found, this method does nothing.  Additionally,
 * if an element with exists with id='trackNumberLabel', the html for this
 * label will be updated with the number of tracks loaded.
 */
function updateTracks()
{
  if($('track_names'))
  {
    // Clear the current track list
    if($('trackNumberLabel')) $('trackNumberLabel').update("&nbsp;") ;
    if($('all_attributes')) $('all_attributes').update("") ;
    if($('track_names') && $('track_names_mask'))
    {
      try
      {
        $('track_names').update("") ;
        var myMask = new Ext.LoadMask(Ext.get('track_names_mask'), {msg: "Loading..."}) ;
        myMask.show() ;
      }
      catch(e) { alert(e); }
    }

    // Update the track multi-select, fill with our new values
    new Ajax.Request("/java-bin/ajax/track.jsp?action=list",
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

          // Put the new track names in the select
          if($('trackNumberLabel')) $('trackNumberLabel').update(response.length + " tracks:") ;
          for(var num = 0; num < response.length; num++)
          {
            var option = document.createElement('option') ;
            if(response[num]['empty']) 
              $(option).setStyle({color: '#BBBBBB'}) ;
            option.setAttribute('value', response[num]['name']) ;
            option.appendChild(document.createTextNode(response[num]['name'])) ;
            $('track_names').appendChild(option);
          }

          // Hide mask (because the update method didn't destroy it)
          var myMask = new Ext.LoadMask(Ext.get('track_names_mask')) ;
          myMask.hide() ;
        }
      }
    ) ;
  }
}

/**
 * Remove all of the previously loaded Entry Point information from the user
 * interface components related to EP.
 */
function clearEntryPoints()
{
  if($('entry_point'))
  {
    // Clear the current options
    $('entry_point').update() ;
    $('entry_point').show() ;
    if($('entry_point_text'))
    {
      $('entry_point_text').hide() ;
      $('entry_point_text').clear() ;
      $('entry_point_text').value = 'all' ;
    }
    if($('ep_start'))
    {
      $('ep_start').disable() ;
      $('ep_start').clear() ;
    }
    if($('ep_stop'))
    {
      $('ep_stop').disable() ;
      $('ep_stop').clear() ;
    }
  }
}

/**
 * Query the ajax providers for entry points for the currently selected RefSeq
 * (database).  This information is then loaded into the user interface.
 */
function updateEntryPoints()
{
  if($('entry_point'))
  {
    clearEntryPoints() ;
    if($("entry_point_min")) $("entry_point_min").hide() ;
    if($("entry_point_max")) $("entry_point_max").hide() ;

    // Update the Entry Points select, fill with our new values
    new Ajax.Request("/java-bin/ajax/database.jsp?action=list_entrypoints",
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

          // Use a text field instead of a dropdown
          if(response['toomany']) 
          {
            if ($('entry_point')) $('entry_point').hide() ;
            if ($('entry_point_text')) $('entry_point_text').show() ;
            if ($('ep_start'))  $('ep_start').enable() ;
            if ($('ep_stop'))  $('ep_stop').enable() ;
            return ;
          }

          // Put the new entry points in the select
          var option = document.createElement('option') ;
          option.setAttribute('value', 'all') ;
          option.appendChild(document.createTextNode('All Entry Points')) ;
          $('entry_point').appendChild(option) ;
          for(var num = 0; num < response.length; num++)
          {
            option = document.createElement('option') ;
            option.setAttribute('value', response[num]) ;
            option.appendChild(document.createTextNode(response[num])) ;
            $('entry_point').appendChild(option) ;
          }
          if ($('ep_start'))  $('ep_start').disable() ;
          if ($('ep_stop'))  $('ep_stop').disable() ;
        }
      }
    ) ;
  }
}
