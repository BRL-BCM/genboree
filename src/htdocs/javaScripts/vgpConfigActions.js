/**********************************
* Project: VGP UI Integration
*   This project creates a new User Interface (UI) to assist users in
*   creating parameter files for the Virtual Genome Painter (VGP) v 2.0.
*   The integration also creates a server-side support environment to create
*   necessary configuration files, queue a VGP job with the Genboree environment
*   and then package the VGP output files and notify the user of job completion.
*
* vgpConfigActions.js - This javascript file defines the client-side 
*   actions for any changes made in the UI (vgpConfig.rhtml)
*
* Developed by Bio::Neos, Inc. (BIONEOS)
* under a software consulting contract for:
* Baylor College of Medicine (CLIENT)
* Copyright (c) 2008 CLIENT owns all rights.
* To contact BIONEOS, visit http://bioneos.com
**********************************/

function setSelectedTab(tab)
{
  if(selectedTab == tab || !tabs[tab])
  {
    return ;
  }
  $(selectedTab).toggleClassName('active') ;
  $(tab).toggleClassName('active') ;
  
  // Hide our currently selected content & show our new selected
  if($(tabs[selectedTab].divId) && $(tabs[tab].divId))
  {
    $(tabs[selectedTab].divId).hide() ;
    $(tabs[tab].divId).show() ;
  
    if(tab == 'submitTab')
    {
      updateStatusInfo() ;
    }
  }

  if(tabs[tab].feedbackDivId != '' && $(tabs[tab].feedbackDivId))
  {
    $(tabs[tab].feedbackDivId).update('') ;
  }

  selectedTab = tab ;
}

function updateStatusInfo()
{
  var errors = new Array() ;
  var warnings = new Array() ;
  var errText = '' ;

  if(!$('status') || !$('submitButton'))
  {
    return ;
  }
  
  // Ensure we have entry points, a figure to draw, and columns to create and image labels are valid.
  if(numEpsDrawn == 0)
  {
    $('epsStatus').update('<img alt="Failed" src="/images/vgpFailure.png" />') ;
    errors.push('No entry points in the "Entry Points" tab are marked for drawing, at least one must be drawn') ;
  }
  else
  {
    $('epsStatus').update('<img alt="Satisfied" src="/images/vgpCheckmark.png" />') ;
  }

  // Check to make sure columns exist
  if(columns.count == 0)
  {
    $('colStatus').update('<img alt="Failed" src="/images/vgpFailure.png" />') ;
    $('trackStatus').update('<img alt="Failed" src="/images/vgpFailure.png" />') ;
    errors.push('No data columns have been created.') ;
    errors.push('No tracks have been created.') ;
  }
  else
  {
    var tracksExist = false ;
    var cytobandWarning = false ;

    $('colStatus').update('<img alt="Satisfied" src="/images/vgpCheckmark.png" />') ;
    
    for(var column in columns['cols'])
    {
      if(!cytobandWarning)
      {
        // Loop through all tracks, see if any are cytoband and not ref track
        for(var i = 0 ; i < columns['cols'][column].tracks.length ; i++)
        {
          var tempTrack = columns['cols'][column].tracks[i] ;
          if(tempTrack.drawingStyle == 'cytoband' && (!referenceTrack || (referenceTrack.internalId != tempTrack.internalId)))
          {
            var warning = 'An annotation track has been added with a \'Cytoband\' drawing style but it is not '
              + 'set as the reference track. The banding will not be drawn unless the track is the reference track.' ;

            warnings.push(warning) ;
            cytobandWarning = true ;
            break ;
          }
        }
      }
      
      // Make sure at least one track exists somewhere, in some column
      if(!tracksExist && columns['cols'][column].tracks.length > 0)
      {
        tracksExist = true ;
      }      
    }
    
    if(tracksExist)
    {
      $('trackStatus').update('<img alt="Satisfied" src="/images/vgpCheckmark.png" />') ;
    }
    else
    {
      $('trackStatus').update('<img alt="Failed" src="/images/vgpFailure.png" />') ;
      errors.push('No tracks have been created.') ;
    }
  }

  // Ref-track check
  if(referenceTrack && referenceTrack.drawingStyle != 'cytoband')
  {
    var warning = 'The drawing style of the reference track is set to \'' + referenceTrack.drawingStyle + '\'. '
      + 'If the reference track contains cytoband information the drawing style must be \'Cytoband\' for the bands to draw properly.' ;

    warnings.push(warning) ;
  }

  // Y-Scale format check (if segments && genomeView, then yscale should be individual
  if(numEpSegsDrawn > 0 && $F('imageClass') == 'genomeView' && $F('yAxisScale') != 'individual')
  {
    var warning = 'Entry point segments are specified to be drawn on the Genome View image and the Y-Axis scale ' +
      'is set to \''+ $F('yAxisScale') + '\'. Without individual Y-Axis scales, the positioning of Entry Points on the Genome View ' +
      'might appear confusing.' ;
    warnings.push(warning) ;
  }

  // Update errors list
  var optsErrors = validateOptionsForTab('figures') ;
  var errorListText = '<li class="header">Error</li>' ;
  
  for(var i = 0 ; i < optsErrors.length ; i++)
  {
    errorListText += '<li>' + optsErrors[i]  + '</li>' ;
  }
  errors = errors.concat(optsErrors) ;
  $('errorList').update(errorListText) ;
  $('numErrors').update('Total Errors: ' + errors.length) ;
  (errors.length > 0) ? $('numErrors').addClassName('errorsExist') : $('numErrors').removeClassName('errorsExist') ;


  // Update warnings list
  var warningListText = '<li class="header">Warning</li>' ;
  
  for(var i = 0 ; i < warnings.length ; i++)
  {
    warningListText += '<li>' + warnings[i] + '</li>' ;
  }
  $('warningList').update(warningListText) ;
  $('numWarnings').update('Total Warnings: ' + warnings.length) ;
  (warnings.length > 0) ? $('numWarnings').addClassName('warningsExist') : $('numWarnings').removeClassName('warningsExist') ;

  // Alert user if errors exist
  if(errors.length > 0)
  {
    errText += '<div class="failure">Errors were found with the VGP configuration! ' ;
    errText += 'You must correct the errors listed above before you can submit a VGP job.</div>' ;
    $('submitButton').disabled = true ;
  }
  else
  {
    $('submitButton').disabled = false ;
  }
  
  $('status').update(errText) ;
}

function toggleAdvancedOptions(advancedId, anchor)
{
  if(!$(advancedId) || !anchor)
  {
    return ;  
  }
  
  Effect.toggle(advancedId, 'blind', { afterFinish: function() {
    if($(advancedId).visible())
    {
      anchor.style.backgroundImage = 'url(/images/vgpMinus.gif)' ;
    }
    else
    {
      anchor.style.backgroundImage = 'url(/images/vgpPlus.gif)' ;
    }
  }}) ;
}

function checkLegendPosConflict()
{
  if($('columnLegend').checked && $('trackLegend').checked && $F('cLegendPos') == $F('tLegendPos'))
  {
    Effect.Appear('tLegendSecPos') ;
    Effect.Appear('cLegendSecPos') ;
  }
  else
  {
    // There is no conflict, make sure our secondary pos options are hidden
    if($('cLegendSecPos').visible()) { Effect.Fade('cLegendSecPos') ; }
    if($('tLegendSecPos').visible()) { Effect.Fade('tLegendSecPos') ; }
  }
}

function setColumnSecondaryPosition()
{
  if(!$('tLegendSecPosSelect') || !$('cLegendSecPosSpan'))
  {
    return ;
  }
  
  switch($F('tLegendSecPosSelect').toLowerCase())
  {
    case 'top':
      $('cLegendSecPosSpan').innerHTML = 'Bottom' ;
      break ;
    case 'bottom':
      $('cLegendSecPosSpan').innerHTML = 'Top' ;
      break ;
    case 'left':
      $('cLegendSecPosSpan').innerHTML = 'Right' ;
      break ;
    case 'right':
      $('cLegendSecPosSpan').innerHTML = 'Left' ;
      break ;
  }
}

function toggleImageTypeOptions()
{
  var currVisible = '' ;
  var toMakeVisible = '' ;

  if($('genomeView').visible())
  {
    currVisible = 'genomeView' ;
    toMakeVisible = 'chromView' ;

    // Check to see if any bad values were put into the genome view and clear them.
    // If we don't clear there errors, then an error will appear in the errors table even though
    // we have not marked the genome view for drawing (meaning the errors shouldn't apply)
    var defaults = {'genomeMargin' : '5', 'genomeFontSize' : '12', 'genomeFontColor' : '000000'} ;
    $$('#genomeView .error').each(function(element) {
      $(element).value = defaults[element.id] ;
      $(element).removeClassName('error') ;
    }) ;
  }
  else
  {
    currVisible = 'chromView' ;
    toMakeVisible = 'genomeView' ;
  }

  Effect.toggle(currVisible, 'blind', { afterFinish : function() { Effect.toggle(toMakeVisible, 'blind') ;  }}) ;
}

/** ENTRY POINT METHODS **/
function toggleEPDrawing(epId)
{
  if($(epId) && entryPoints['eps'][epId])
  {
    $(epId).toggleClassName('hidden') ;
    entryPoints['eps'][epId].drawn = $(epId+'_check').checked ;

    if($(epId+'_check').checked)
    {
      numEpsDrawn++ ;
    }
    else
    {
      numEpsDrawn-- ;
    }
    $('epsDrawn').innerHTML = ""+numEpsDrawn ;
  }
}

function addEntryPoint(epName, grpName, rseqName)
{
  // This is the new version that will use the AJAX, this needs to be copied to genboreeproto b/c
  // it was deleted so I could check in a version that could be deployed and this is currently broken
  if(epName == "" || !/\S+/.test(epName))
  {
    return ;
  }
  $('epFeedback').update('') ;

  if(entryPoints['eps']['ep_'+epName.toLowerCase()])
  {
    // This entry point is already in the EPs data struct.
    $('epFeedback').update('<div class="warning">The entry point \'' + epName + '\' has already been added.') ;

    return ;
  }

  // Check to see if the EP exists in the DB
  var escapedRestUri = encodeURIComponent('/REST/v1/grp/' + encodeURIComponent(grpName) + 
    '/db/' + encodeURIComponent(rseqName) + '/ep/' + encodeURIComponent(epName)) ;

  new Ajax.Request('/java-bin/apiCaller.jsp?rsrcPath=' + escapedRestUri + '&method=GET', {
    method : 'get',
    onSuccess : function(transport) {
      var restData = eval('('+transport.responseText+')') ;
      
      if(!restData["data"]["name"] || !restData["data"]["length"])
      {
        // We need the EP name and length, otherwise this request was a bust. The response header 
        // should have been a failure, but as a backup relay the error if we somehow get to this block
        $('epFeedback').update('<div class="failure">The entry point \'' + epName + '\' was not found in the database and could not be added!') ;

        return ;
      }

      // Visuals
      var newEp = document.createElement('option') ;
      newEp.id = 'ep_' + restData['data']['name'] ;
      newEp.value = 'ep_' + restData['data']['name'] ;
      newEp.appendChild(document.createTextNode(restData['data']['name'])) ;
      $('epsList').appendChild(newEp) ;
      $('removeButton').disabled = false ;
      $('epEntry').value = "" ;

      // Add to data structure
      entryPoints['eps']['ep_'+restData['data']['name'].toLowerCase()] = new EntryPoint(restData['data']['name'], parseInt(restData['data']['length'])) ;
      entryPoints['count']++ ;
      numEpsDrawn++ ;
      $('epsDrawn').innerHTML = '' + numEpsDrawn ;
    },
    onFailure : function(transport) {
      // Alert user
      $('epFeedback').update('<div class="failure">The entry point \'' + epName + '\' was not found in the database and could not be added!') ;
    }
  }) ;
}

function removeEntryPoints(epsList)
{
  var removeCount = 0 ;
  if($(epsList) && $(epsList).selectedIndex != -1)
  {
    for(var i = $(epsList).options.length ; i > 0 ; i--)
    {
      if($(epsList).options[i - 1].selected)
      {
        // Remove from data structure
        delete(entryPoints['eps']['ep_'+$(epsList).options[i - 1].value]) ;
        removeCount++ ;        
        
        // Visuals
        $(epsList).remove(i - 1) ;
      }
    }

    if($(epsList).options.length == 0)
    {
      $('removeButton').disabled = true ;
    }
    
    numEpsDrawn -= removeCount ;
    entryPoints['count'] -= removeCount ;
    $('epsDrawn').innerHTML = '' + numEpsDrawn ;
  }
}

function drawAllEps(drawn)
{
  for(var ep in entryPoints['eps'])
  {
    if($(ep) && (entryPoints['eps'][ep].drawn != drawn))
    {
      entryPoints['eps'][ep].drawn = drawn ;
      $(ep+'_check').checked = drawn ;
      $(ep).toggleClassName('hidden') ;
    }
  }

  // Update our visual to alert the user
  numEpsDrawn = (drawn) ? entryPoints['count'] : 0 ;
  $('epsDrawn').innerHTML = ""+numEpsDrawn ;
}

function toggleSegOptsVis(show, epId)
{
  if(show && !$('segOpts').visible())
  {
    Effect.BlindDown('segOpts', {queue : 'end', afterFinish: function() { $('epSegStart').focus() ; }}) ;
    if(epId && entryPoints['eps'][epId])
    {
      numEpSegsDrawn += entryPoints['eps'][epId].segments.length ;
      if(numEpSegsDrawn > 0 && $('yAxisScale'))
      {
        $('yAxisScale').options[4].selected = true ;
      }
    }
  }
  else if(!show && $('segOpts').visible())
  {
    Effect.BlindUp('segOpts', {queue : 'end'}) ;

    if(epId && entryPoints['eps'][epId])
    {
      entryPoints['eps'][epId].mode = 'full' ;
      numEpSegsDrawn -= entryPoints['eps'][epId].segments.length ;
      if(numEpSegsDrawn == 0 && $('yAxisScale'))
      {
        $('yAxisScale').options[1].selected = true ;
      }
    }
  }

  $('epFeedback').update('') ;
  $$('#eps .error').each(function(input) { $(input).removeClassName('error') ; }) ;
}

function setSegOrderForEp(epId, order)
{
  if(!entryPoints['eps'][epId])
  {
    return false ;
  }

  entryPoints['eps'][epId].segOrder = order ;

  return true ;
}

function setSelectedEp(epId)
{
  if(selectedEpId == epId)
  {
    return false ;
  }  
  
  if(epId != '' && $(epId) && $(epId).tagName.toLowerCase() != 'option')
  {
    $(epId).addClassName('selected') ;
  }

  if(selectedEpId != '' && $(selectedEpId) && $(selectedEpId).tagName.toLowerCase() != 'option')
  {
    $(selectedEpId).removeClassName('selected') ;
  }
 
  // Toggle our epdetails availability - This only happens once, after an EP is seleced
  // There will always be at least one selected EP
  if(selectedEpId == '')
  {
    ['epName', 'epLength', 'fullDiv', 'fullAndSegsDiv', 'segsOnlyDiv'].each(function(id) {
      var el = $(id) ;
      if(el)
      {
        //(epId != '') ? $(id).removeClassName('disabled') : $(id).addClassName('disabled') ;
        $(id).removeClassName('disabled') ;
      }
    }) ;

    ['full', 'fullAndSegs', 'segsOnly'].each(function(id) {
      var el = $(id) ;
      if(el)
      {
        //(epId!= '') ? $(id).disabled = false : $(id).disabled = true ;
        $(id).disabled = false ;
      }
    }) ;
  }
  
  selectedEpId = epId ;
  $('epFeedback').update('') ;
  $$('#eps .error').each(function(input) { $(input).removeClassName('error') ; }) ;
  epId = null ;
  
  return true ;
}

function selectAndShowEpDetails(epId)
{
  epId = epId.toLowerCase() ;
  if(!entryPoints['eps'][epId] || !setSelectedEp(epId))
  {
    return ;
  }

  $('epName').update(entryPoints['eps'][epId].name) ;
  $('epLength').update(entryPoints['eps'][epId].length) ;
  $(entryPoints['eps'][epId].mode).checked = true ;

  // Now update the drawing mode and any segments
  $('epSegsListId').update(entryPoints['eps'][epId].name) ;
  $('epSegsList').update('') ;
  for(var i = 0 ; i < entryPoints['eps'][epId].segments.length ; i++)
  {
    var seg = entryPoints['eps'][epId].segments[i] ;
    var segLi = document.createElement('li') ;
    segLi.id = seg.id ;
    $(segLi).addClassName('clickable') ;
    if(segLi.attachEvent)
    {
      segLi.attachEvent('onclick', function() { selectAndShowSegDetails(selectedEpId, segLi.id) ; }) ;
    }
    else
    {
      segLi.onclick = function() { selectAndShowSegDetails(selectedEpId, segLi.id) ; }
    }
    segLi.appendChild(document.createTextNode('Segment: Base pairs ' + seg.start + ' - ' + seg.end)) ;
    $('epSegsList').appendChild(segLi) ;
  }
  
  toggleSegOptsVis(entryPoints['eps'][epId].mode == 'segsOnly' || entryPoints['eps'][epId].mode == 'fullAndSegs') ;

  return ;
}

function checkEpRange(epId, inputEl)
{
  if(epId == '' || !entryPoints['eps'][epId])
  {
    return ;
  }

  if($F('epSegStart') == $F('epSegEnd'))
  {
    $(inputEl).addClassName('error') ;
    return ;
  }
  else
  {
    $('epSegStart').removeClassName('error') ;
    $('epSegEnd').removeClassName('error') ;
  }

  checkIntRange(inputEl, 0, entryPoints['eps'][epId].length) ;
}

function checkEpSelected(epId)
{
  // EPs might have been added manually, so to be safe, convert id to lower to 
  // avoid any discrepancy in what is displayed and what was typed
  epId = epId.toLowerCase() ;
  if(epId == '' || !entryPoints['eps'][epId])
  {
    $('epFeedback').update('<div class=\"failure\">Please select an Entry Point from the \'Available Entry Points\' list above.</div>') ;
    $('epFeedback').scrollTo() ;

    return false ;
  }

  return true ;
}

function processManualEpSelect(selectEl)
{
  if(selectEl.selectedIndex != -1)
  {
    selectAndShowEpDetails(selectEl.options[selectEl.selectedIndex].id) ;
  }

  return ;
}

function addSegmentToEp(epId)
{
  $('epFeedback').update('') ;

  if(!checkEpSelected(epId))
  {
    return ;
  }

  if($F('epSegStart') == '')
  {
    $('epSegStart').addClassName('error') ;
  }

  if($F('epSegEnd') == '')
  {
    $('epSegEnd').addClassName('error') ;
  }

  var optsErrors = validateOptionsForTab('eps') ;
  if(optsErrors.length > 0)
  {
    reportErrors(optsErrors, $('epFeedback')) ;
    return false ;
  } 

  // Add the segment to the EP data struct
  entryPoints['eps'][epId].segments.push({"id" : 'seg_' + entryPoints['eps'][epId].nextSegId, "start" : $F('epSegStart'), "end" : $F('epSegEnd')}) ;
  ($('fullAndSegs').checked) ? entryPoints['eps'][epId].mode = 'fullAndSegs' : entryPoints['eps'][epId].mode = 'segsOnly' ;

  // Add the segment to the UI
  var segLi = document.createElement('li') ;
  var segText = 'Segment: Base pairs ' + $F('epSegStart') + ' - ' +$F('epSegEnd') ;
  segLi.id = 'seg_' + entryPoints['eps'][epId].nextSegId ;
  $(segLi).addClassName('clickable') ;
  segLi.style.display = 'none' ;
  if(segLi.attachEvent)
  {
    segLi.attachEvent('onclick', function() { selectAndShowSegDetails(selectedEpId, segLi.id) ; }) ;
  }
  else
  {
    segLi.onclick = function() { selectAndShowSegDetails(selectedEpId, segLi.id) ; }
  }    
  segLi.appendChild(document.createTextNode(segText)) ;
  $('epSegsList').appendChild(segLi) ;
  Effect.Appear(segLi, {queue : 'end'}) ;

  resetSegOptionInputs() ;
  
  if(numEpSegsDrawn == 0 && $('yAxisScale'))
  {
    $('yAxisScale').options[4].selected = true ;
  }
  
  numEpSegsDrawn++ ;
  entryPoints['eps'][epId].nextSegId++ ;

  return ;
}

function updateSegmentInEp(epId, segId)
{
  $('epFeedback').update('') ;

  if(!checkEpSelected(epId))
  {
    return ;
  }
  
  if(segId == '')
  {
    $('epFeedback').update('<div class="failure">First select a segment from the \'Current Segments List\' to update</div>') ;
    $('epFeedback').scrollTo() ;

    return false ;
  }

  var optsErrors = validateOptionsForTab('eps') ;
  if(optsErrors.length > 0)
  {
    reportErrors(optsErrors, $('epFeedback')) ;
    return false ;
  }

  // Find our segment
  var segment = entryPoints['eps'][epId].getSegment(segId) ;
  if(segment == null)
  {
    return ;
  }

  segment.start = $('epSegStart').value;
  segment.end = $('epSegEnd').value;
  
  // Visuals
  $(segId).update('Segment: Base pairs ' + $F('epSegStart') + ' - ' +$F('epSegEnd')) ;
  new Effect.Highlight(segId, {startcolor: '#EAE6FF', duration: 1.5}) ;
  resetSegOptionInputs() ;
}

function removeSegmentFromEp(epId, segId)
{
  $('epFeedback').update('') ;
  
  if(!checkEpSelected(epId))
  {
    return ;
  }
  
  if(segId == '')
  {
    $('epFeedback').update('<div class="failure">First select a segment from the \'Current Segments List\' to remove</div>') ;
    $('epFeedback').scrollTo() ;

    return false ;
  }

  var optsErrors = validateOptionsForTab('eps') ;
  if(optsErrors.length > 0)
  {
    reportErrors(optsErrors, $('epFeedback')) ;
    return false ;
  }
  
  // Remove our segment
  if(!entryPoints['eps'][epId].removeSegmentById(segId))
  {
    return false ;
  }

  if(entryPoints['eps'][epId].segments.length == 0)
  {
    entryPoints['eps'][epId].mode = 'full' ;
  }
  
  // Visuals
  new Effect.Fade(segId, {startcolor: '#EAE6FF', duration: 1.5}) ;
  $('epSegsList').removeChild($(segId)) ;
  resetSegOptionInputs() ;
  numEpSegsDrawn-- ;
  if(numEpSegsDrawn == 0 && $('yAxisScale'))
  {
    $('yAxisScale').options[1].selected = true ;
  }
}

function setSelectedSeg(segId)
{
  if(selectedSegId == segId)
  {
    return false ;
  }  

  if(segId != '' && $(segId))
  {
    $(segId).addClassName('selected') ;
  }

  if(selectedSegId != '' && $(selectedSegId))
  {
    $(selectedSegId).removeClassName('selected') ;
  }
  selectedSegId = segId ;

  $('epFeedback').update('') ;
  $$('#eps .error').each(function(input) { $(input).removeClassName('error') ; }) ;
  
  return true ;
}

function selectAndShowSegDetails(epId, segId)
{
  if(!setSelectedSeg(segId) || !checkEpSelected(epId))
  {
    return false ;
  }

  var segment = entryPoints['eps'][epId].getSegment(segId) ;
  if(segment == null)
  {
    return false ;
  }

  $('epSegStart').value = segment.start ;
  $('epSegEnd').value = segment.end ;
  
  return true ;
}

function resetSegOptionInputs()
{
  $('epSegStart').value = '' ;
  $('epSegEnd').value = '' ;
  setSelectedSeg('') ;

  return ;
}
/** END ENTRY POINT METHODS **/

/** DATA COLUMN METHODS **/
function addDataColumn()
{
  // Note: If we update to prototype v1.6, Element.insert can be used
  // Add to the columns data structure
  var columnObj = new DataColumn() ;
  if(!setDataColumnOptions(columnObj))
  {
    return ;
  }
  columns['cols']['column_'+nextColumnId] = columnObj ;
  
  // Visuals
  var col = document.createElement('li') ;
  col.id = 'column_' + nextColumnId ;
  col.style.display = 'none' ;
  if(col.attachEvent)
  {
    col.attachEvent('onclick', function() {
      $('drawColumnTitle').focus() ; selectAndShowDataColumnDetails(col.id) ;
    }) ;
  }
  else
  {
    col.onclick = function() {
      $('drawColumnTitle').focus() ; selectAndShowDataColumnDetails(col.id) ;
    }
  }    
  $(col).addClassName('movable') ;
  
  var titleText = '' ;
  if($F('columnTitleText') != '')
  {
    titleText += '- ' + $F('columnTitleText').substring(0, 60) ;
    titleText += ($F('columnTitleText').length > 60) ? '...' : '' ;
  }
  var columnInfo = '<div style="overflow: auto ;">' ;
  columnInfo += '  <span id="' + col.id + '_pos" style="float: left ;">Column 1</span>' ;
  columnInfo += '  <span id="' + col.id + '_title" style="float: left ; margin-left: 5px ;">' + titleText + '</span>' ;
  columnInfo += '  <span id="' + col.id + '_tracks" style="float: right ; margin-left: 10px ;">0 tracks</span>' ;
  columnInfo += '</div>' ;

  $(col).update(columnInfo) ;
  $('dataColumnsSortable').appendChild(col) ;
  
  if(columns.count == 0)
  {
    $('emptyMsg').remove() ;
    $('dataColumnSelect').up().update('<select id="dataColumnSelect" onchange="showTracksForDataColumn($F(this)) ;"></select>') ;
  }
  else
  {
    setDataColumnPositions() ;
  }
  
  // After any operation, we start with a clean slate, nothing selected, no options set
  resetDataColumnOptionInputs() ;
  Effect.Appear(col) ;
  
  nextColumnId++ ;
  columns.count++ ;
  
  // Update our columns select for the tracks tab
  updateDataColumnSelect() ;
  showTracksForDataColumn($F('dataColumnSelect')) ;
  
  // Recreate our Sortable with the new columns
  Sortable.create('dataColumnsSortable', {onUpdate: setDataColumnPositions}) ;
}

function removeDataColumn(columnId)
{
  if(!columns['cols'][columnId])
  {
    return ;
  }
  
  // Remove column from columns data structure
  delete(columns['cols'][columnId]) ;
  columns.count-- ;
  
  // Visuals
  if($(columnId).hasClassName('reference'))
  {
    referenceTrack = null ;
  }
  $('dataColumnsSortable').removeChild($(columnId)) ;
  
  if(columns.count > 0)
  { 
    setDataColumnPositions() ;
    
    // Cleanup the column select in the tracks tab
    updateDataColumnSelect() ;
    showTracksForDataColumn($F('dataColumnSelect')) ;
  }
  else
  {
    // We have removed all columns - disable our button
    $('annotTracks').update('') ;
    
    // All columns and tracks are deleted, nothing should be selected
    resetTrackOptionInputs() ;
    resetTrackTabState() ;
    
    // No columns left, remove select
    $('dataColumnSelect').up().update('<em id="dataColumnSelect">No columns defined - <a href="#" onclick="setSelectedTab(\'colTab\', \'columns\') ;">Add a column</a> first</em>') ;
    var emptyMsg = document.createElement('em') ;
    emptyMsg.id = 'emptyMsg' ;
    emptyMsg.appendChild(document.createTextNode('[List empty - Please add a column]')) ;
    $('dataColumns').appendChild(emptyMsg) ;
    
    // If no columns exist, that means all tracks will be available to be added when a column is created, repopulate...
    $('tracksSelect').options.length = 0 ;
    var option = document.createElement('option') ;
    option.value = 'default' ;
    option.appendChild(document.createTextNode('--- Select a track to add to this column ---')) ;
    $('tracksSelect').appendChild(option) ;
    for(var i = 0 ; i < allTracks.length ; i++)
    { 
      var option = document.createElement('option') ;
      option.value = allTracks[i] ;
      option.appendChild(document.createTextNode(allTracks[i])) ;
      $('tracksSelect').appendChild(option) ;
    }
  }
  
  // After any operation, we start with a clean slate, nothing selected, no options set
  resetDataColumnOptionInputs() ;
  
  Sortable.create('dataColumnsSortable', {onUpdate: setDataColumnPositions}) ;
}

function updateDataColumnOptions(columnId)
{
  if(!columns['cols'][columnId])
  {
    return ;
  }
  
  // Set the options to the data column object
  if(!setDataColumnOptions(columns['cols'][columnId]))
  {
    return ;
  }
  
  // Update our visual element that represents the column
  if($(columnId + '_title') && columns['cols'][columnId].title != '')
  {
    var titleText = '- ' + columns['cols'][columnId].title.substring(0, 60) ;
    titleText += (columns['cols'][columnId].title.length > 60) ? '...' : '' ;
    $(columnId + '_title').innerHTML = titleText ;
  }
  else if($(columnId + '_title'))
  {
    $(columnId + '_title').innerHTML = '' ;
  }
  
  new Effect.Highlight(columnId, {afterFinish: function() { $(columnId).setStyle({backgroundColor: ''}) ; }, 
    startcolor: '#EAE6FF', duration: 1.5}) ;

  // Update the data columns select in the tracks tab
  updateDataColumnSelect() ;
  
  // After any operation, we start with a clean slate, nothing selected, no options set
  resetDataColumnOptionInputs() ;
}

function setSelectedDataColumn(columnId)
{
  if(selectedColumnId == columnId)
  {
    return false ;
  }  
  
  if(columnId != '' && $(columnId))
  {
    $(columnId).toggleClassName('selected') ;
  }

  if(selectedColumnId != '' && $(selectedColumnId))
  {
    $(selectedColumnId).toggleClassName('selected') ;
  }
  selectedColumnId = columnId ;
  
  // When a new selected col is set, clear our colFeedback of any info for the old selected col
  // Also clear out the errored inputs for the old selected col, if any
  $('colFeedback').update('') ;
  $$('#columns .error').each(function(input) { $(input).removeClassName('error') ; }) ;

  var disabled = (columnId == '') ? true : false ;
  $('updateColumnButton').disabled = disabled ;
  $('removeColumnButton').disabled = disabled ;
  
  return true ;
}

function setDataColumnOptions(columnObj)
{
  if(!columnObj)
  {
    return false ;
  }
  
  $('colFeedback').update('') ;
  var optsErrors = validateOptionsForTab('columns') ;
  if(optsErrors.length > 0)
  {
    reportErrors(optsErrors, $('colFeedback')) ;
    return false ;
  }  
  
  columnObj.title = $F('columnTitleText') ;
  columnObj.drawTitle = $('drawColumnTitle').checked ;
  columnObj.drawLabel = $('drawColumnLabel').checked ;
  columnObj.titleSize = parseInt($F('columnTitleFontSize')) ;
  columnObj.titleFont = $F('columnTitleFont') ;
  columnObj.titleColor = $F('columnTitleFontColor') ;
  columnObj.labelSize = parseInt($F('columnLabelFontSize')) ;
  columnObj.labelFont = $F('columnLabelFont') ;
  columnObj.labelColor = $F('columnLabelFontColor') ;
  
  return true ;
}

function setDataColumnPositions()
{
  var offset = 0 ;
  
  if(($$('.reference').length > 0))
  {
    for(var i = 0 ; i < $('dataColumnsSortable').childNodes.length ; i++)
    {
      var columnEl = $('dataColumnsSortable').childNodes.item(i) ;
      if($(columnEl).hasClassName('reference'))
      {
        offset = (i * -1) ;
        break ;
      }
    }
  }
  
  // Now set the positions for the columns
  // This again uses an old method to update the dataColumnSelect, see the
  // method 'updateDataColumnSelect' for explanation
  var dataColSelected = $F('dataColumnSelect') ;
  $('dataColumnSelect').options.length = 0 ;
  for(var i = 0 ; i < $('dataColumnsSortable').childNodes.length ; i++)
  {
    var columnObj = $('dataColumnsSortable').childNodes.item(i) ;
    if(!columns['cols'][columnObj.id])
    {
      continue ;
    }
    
    // Data structure columnObj gets the position from the offset
    columns['cols'][columnObj.id].position = i + offset ;
    if($(columnObj.id + '_pos'))
    {
      // Visual just gets incremented in the order it is drawn
      $(columnObj.id + '_pos').innerHTML = 'Column ' + (i + 1) ;
    }
    
    // Check our tracks, see if any tracks are score based and update drawing direction if necessary -- Perhaps this is not desired action...
    for(var m = 0 ; m < columns['cols'][columnObj.id].tracks.length ; m++)
    {
      if((/score/i.test(columns['cols'][columnObj.id].tracks[m].drawingStyle)) && $('direction'))
      {
        if((i + offset) < 0)
        {
          $('direction').selectedIndex = 1 ;
          columns['cols'][columnObj.id].tracks[m].styleOptions.direction = "left" ;
        }
        else
        {
          $('direction').selectedIndex = 0 ;
          columns['cols'][columnObj.id].tracks[m].styleOptions.direction = "right" ;
        }
      }      
    }
    
    // Since we are already looping through the columns, do a manual update of the select on the tracks tab
    var optionText = '' ;
    var option = document.createElement('option') ;
    option.value = columnObj.id ;
    option.selected = (dataColSelected == columnObj.id) ? true : false ;
    optionText += 'Column ' + (i + 1) ;
    if(columns['cols'][columnObj.id].title != '')
    {
      optionText += ' - ' + columns['cols'][columnObj.id].title.replace(/\n/g, ' ').substring(0, 20) ;
      optionText += (columns['cols'][columnObj.id].title.length > 20) ? '...' : '' ;  
    }
    option.appendChild(document.createTextNode(optionText)) ;
    $('dataColumnSelect').appendChild(option) ;
  }
}

function resetDataColumnOptionInputs()
{
  // Set the data column option defaults
  $('columnTitleText').value = '' ;
  $('drawColumnTitle').checked = true ;
  $('drawColumnLabel').checked = false ;
  $('columnTitleFontSize').value = '14' ;
  $('columnLabelFontSize').value = '12' ;
  $('columnTitleFontColor').value = '#000000' ;
  $('columnTitleFontSwatch').setStyle({ backgroundColor : '#000000' }) ;
  $('columnLabelFontColor').value = '#000000' ;
  $('columnLabelFontSwatch').setStyle({ backgroundColor : '#000000' }) ;
  
  for(var i = 0 ; i < $('columnTitleFont').options.length ; i++ )
  {
    if($('columnTitleFont').options[i].value == defaultFont)
    {
      $('columnTitleFont').selectedIndex = i ;
      break ;
    }
  }  
  
  for(var i = 0 ; i < $('columnLabelFont').options.length ; i++ )
  {
    if($('columnLabelFont').options[i].value == defaultFont)
    {
      $('columnLabelFont').selectedIndex = i ;
      break ;
    }
  }
  
  setSelectedDataColumn('') ;
}

function selectAndShowDataColumnDetails(columnId)
{
  if(!$(columnId) || !setSelectedDataColumn(columnId))
  {
    return ;
  }
  
  if(!columns['cols'][columnId])
  {
    // Problem finding our column object, return
    return ;
  }
  
  // Update our column fields to reflect the changes
  $('drawColumnTitle').checked = columns['cols'][columnId].drawTitle ;
  $('drawColumnLabel').checked = columns['cols'][columnId].drawLabel ;
  $('columnTitleText').value = columns['cols'][columnId].title ;
  $('columnTitleFontSize').value = columns['cols'][columnId].titleSize ;
  for(var i = 0 ; i < $('columnTitleFont').options.length ; i++ )
  {
    if($('columnTitleFont').options[i].value == columns['cols'][columnId].titleFont)
    {
      $('columnTitleFont').selectedIndex = i ;
      break ;
    }
  }
  $('columnTitleFontColor').value = columns['cols'][columnId].titleColor ;
  $('columnTitleFontSwatch').setStyle({ backgroundColor : columns['cols'][columnId].titleColor }) ;
  
  $('columnLabelFontSize').value = columns['cols'][columnId].labelSize ;
  for(var i = 0 ; i < $('columnLabelFont').options.length ; i++ )
  {
    if($('columnLabelFont').options[i].value == columns['cols'][columnId].labelFont)
    {
      $('columnLabelFont').selectedIndex = i ;
      break ;
    }
  }
  $('columnLabelFontColor').value = columns['cols'][columnId].labelColor ;
  $('columnLabelFontSwatch').setStyle({ backgroundColor : columns['cols'][columnId].labelColor }) ;
}

function updateDataColumnSelect()
{
  // This method previously used Prototype.Element.update() to update the options for
  // the dataColumnSelect. Unfortunately an error was occurring in IE with Prototype v1.5
  // which is installed on Genboree. With an update to Prototype, the update method might be used
  if($('dataColumnSelect') && columns.count > 0)
  {
    var dataColSelected = $F('dataColumnSelect') ;
    $('dataColumnSelect').options.length = 0 ;
    for(var i = 0 ; i < $('dataColumnsSortable').childNodes.length ; i++)
    {
      var columnEl = $('dataColumnsSortable').childNodes.item(i) ;
      var optionText = '' ;
      var option = document.createElement('option') ;
      option.value = columnEl.id ;
      option.selected = (dataColSelected == columnEl.id) ? true : false ;
      optionText += 'Column ' + (i + 1) ;
      if(columns['cols'][columnEl.id].title != '')
      {
        optionText += ' - ' + columns['cols'][columnEl.id].title.replace(/\n/g, ' ').substring(0, 20) ;
        optionText += (columns['cols'][columnEl.id].title.length > 20) ? '...' : '' ;  
      }
      
      option.appendChild(document.createTextNode(optionText)) ;
      $('dataColumnSelect').appendChild(option) ;
    }
  }
}
/** END DATA COLUMN METHODS **/

/** TRACK METHODS **/
function addTrackToDataColumn(trackName, columnId)
{
  if(trackName == '' || columnId == '')
  {
    return ;
  }
  
  // Add our track to our column object data structure
  var trackObj = new Track('track_' + nextTrackId, trackName)
  if(!setTrackOptions(trackObj))
  {
    return ;
  }
  columns['cols'][columnId].addTrack(trackObj) ;
  
  
  var trackEl = createTrackHTML('track_' + nextTrackId, trackName) ;
  $('annotTracksSortable').appendChild(trackEl) ;
  if($('emptyTrackMsg'))
  {
    $('emptyTrackMsg').remove() ;
  }
  nextTrackId++ ;
  
  // Set some final visuals then show the track
  setZIndicesForDataColumn(columnId) ;
  $('tracksSelect').remove($('tracksSelect').selectedIndex) ;
  
  // After any operation, we start with a clean slate, nothing selected, no options set
  resetTrackOptionInputs() ;
  resetTrackTabState() ;
  Effect.Appear(trackEl, {queue : 'end'}) ;
  
  // Update our track count in the columns tab
  if($(columnId + '_tracks'))
  {
    $(columnId + '_tracks').innerHTML = columns['cols'][columnId].tracks.length + ' tracks' ;
  }
  
  Sortable.create('annotTracksSortable', {onUpdate : function() { setZIndicesForDataColumn(columnId) ; }}) ;
  
  return ;
}

function removeTrackFromDataColumn(trackId, columnId)
{
  if(!$(trackId) || columnId == '' || !columns['cols'][columnId])
  {
    return ;
  }

  // Update our columns data structure & columns object in column tab
  if(!columns['cols'][columnId].removeTrack(trackId))
  {
    return ;
  }
  
  // Update our columns track count
  if($(columnId + '_tracks'))
  {
    $(columnId + '_tracks').update(columns['cols'][columnId].tracks.length + ' tracks') ;
  }
  
  // Visuals
  var option = document.createElement('option') ;
  option.value = $(trackId + '_display').innerHTML ;
  option.innerHTML = $(trackId + '_display').innerHTML ;
  
  // Remove and add track back to the availabled select
  Effect.Fade(trackId) ;
  $('annotTracksSortable').removeChild($(trackId)) ;
  $('tracksSelect').appendChild(option) ;
  setZIndicesForDataColumn(columnId) ;
  if(referenceTrack && referenceTrack.internalId == trackId)
  {
    // If deleting the reference track, get rid of the reference style from the containing column
    $$('.reference').each(function(el) {
      el.removeClassName('reference') ;
    }) ;
    referenceTrack = null ;
  }
  
  if(columns['cols'][columnId].tracks.length == 0)
  {
    var emptyMsg = document.createElement('em') ;
    emptyMsg.id = 'emptyTrackMsg' ;
    emptyMsg.appendChild(document.createTextNode('[List empty - Please add a track]')) ;
    $('annotTracks').appendChild(emptyMsg) ;
  }

  // After any operation, we start with a clean slate, nothing selected, no options set
  resetTrackOptionInputs() ;
  resetTrackTabState() ;
  
  Sortable.create('annotTracksSortable', {onUpdate : function() { setZIndicesForDataColumn(columnId) ; }}) ;
}

function updateTrackInDataColumn(trackId, columnId)
{
  if(!trackId || !columnId || !columns['cols'][columnId])
  {
    return ;
  }
  
  if(setTrackOptions(columns['cols'][columnId].getTrack(trackId)))
  {
    new Effect.Highlight(trackId, {startcolor: '#EAE6FF', duration: 1.5}) ;
  
    // After any operation, we start with a clean slate, nothing selected, no options set
    resetTrackOptionInputs() ;
    resetTrackTabState() ;
  }
}

function setTrackOptions(trackObj)
{
  if(!trackObj)
  {
    return false ;
  }
  
  $('trackFeedback').update('') ;
  var optsErrors = validateOptionsForTab('tracks') ;
  if(optsErrors.length > 0)
  {
    reportErrors(optsErrors, $('trackFeedback')) ;
    return false ;
  }
  
  // Set all common options -- zIndex is set on the drop event of the Sortable
  trackObj.drawingStyle = $F('drawingStyle') ;
  trackObj.width = parseInt($F('trackWidth')) ;
  trackObj.color = $F('trackColor') ;
  trackObj.annoColorOverride = $('trackColorOverride').checked ;
  trackObj.displayName = $F('trackDisplayName') ;
  trackObj.margin = parseInt($F('trackMargin')) ;
  trackObj.border = $('trackBorder').checked ;
  if($F('trackLegendOrder') != '') { trackObj.legendOrder = parseInt($F('trackLegendOrder')) ; }
  if($('referenceTrack').checked) 
  { 
    setReferenceTrack(trackObj) ; 
  }
  else if(referenceTrack && referenceTrack.internalId == trackObj.internalId)
  {
    // If we used to be the reference track, clear out our reference
    clearReferenceTrack() ;
  }
 
  // Drawing style specific options - First clear out our old style specific options
  trackObj.styleOptions = {} ;

  if(trackObj.drawingStyle != 'cytoband')
  {
    if($('threshAboveScore') && $F('threshAboveScore') != '')
    {
      trackObj.styleOptions.threshAboveScore = parseFloat($F('threshAboveScore')) ;
      trackObj.styleOptions.threshAboveColor = $F('threshAboveColor') ;
    }

    if($('threshBelowScore') && $F('threshBelowScore') != '')
    {
      trackObj.styleOptions.threshBelowScore = parseFloat($F('threshBelowScore')) ;
      trackObj.styleOptions.threshBelowColor = $F('threshBelowColor') ;
    }
  }

  switch(trackObj.drawingStyle)
  {
    case 'box' :
      trackObj.styleOptions.fillColor = $F('fillColor') ;
      trackObj.styleOptions.transparency = parseInt($F('transparency')) ;
      break ;
    case 'score' :
      trackObj.styleOptions.drawScoreAxis = $('drawScoreAxis').checked ;
      trackObj.styleOptions.direction = $F('direction') ;
      trackObj.styleOptions.drawGrid = $('drawGrid').checked ;
      trackObj.styleOptions.font = $F('font') ;
      trackObj.styleOptions.fontSize = parseInt($F('fontSize')) ;
      trackObj.styleOptions.fontColor = $F('fontColor') ;
      trackObj.styleOptions.scoreOverlap = $F('scoreOverlap') ;
      if($F('minScore') != '') { trackObj.styleOptions.minScore = parseFloat($F('minScore')) ; }
      if($F('maxScore') != '') { trackObj.styleOptions.maxScore = parseFloat($F('maxScore')) ; }
      if($F('threshold') != '') { trackObj.styleOptions.threshold = parseFloat($F('threshold')) ; }
      if($F('scoreAxisIncrement') != '') { trackObj.styleOptions.scoreAxisIncrement = parseInt($F('scoreAxisIncrement')) ; }
      break ;
    case 'doubleSidedScore' :
      trackObj.styleOptions.drawScoreAxis = $('drawScoreAxis').checked ;
      trackObj.styleOptions.drawGrid = $('drawGrid').checked ;
      trackObj.styleOptions.font = $F('font') ;
      trackObj.styleOptions.fontSize = parseInt($F('fontSize')) ;
      trackObj.styleOptions.fontColor = $F('fontColor') ;
      trackObj.styleOptions.scoreOverlap = $F('scoreOverlap') ;
      if($F('minScore') != '') { trackObj.styleOptions.minScore = parseFloat($F('minScore')) ; }
      if($F('maxScore') != '') { trackObj.styleOptions.maxScore = parseFloat($F('maxScore')) ; }
      if($F('positiveThreshold') != '') { trackObj.styleOptions.positiveThreshold = parseFloat($F('positiveThreshold')) ; }
      if($F('negativeThreshold') != '') { trackObj.styleOptions.negativeThreshold = parseFloat($F('negativeThreshold')) ; }
      if($F('scoreAxisIncrement') != '') { trackObj.styleOptions.scoreAxisIncrement = parseInt($F('scoreAxisIncrement')) ; }
      break ;
    case 'callout' :
      trackObj.styleOptions.font = $F('font') ;
      trackObj.styleOptions.fontSize = parseInt($F('fontSize')) ;
      trackObj.styleOptions.fontColor = $F('fontColor') ;
      trackObj.styleOptions.calloutLength = parseInt($F('calloutLength')) ;
      trackObj.styleOptions.calloutField = $F('calloutField') ;
      break ;
  }
  
  return true ;
}

function setDisplayName(select)
{
  if($('trackDisplayName'))
  {
    $('trackDisplayName').value = ($F(select) == 'default') ? '' : $F(select) ;
  }
}

function processTrackChange(select)
{
  setDisplayName(select) ;
  if($F('drawingStyle') == 'callout' && selectedTrackId == '' && $F(select) != 'default')
  {
    updateCalloutAttribs($F(select), 'name') ;
  }

  // If a track is selected, deselect it and clear options
  // If a track is not selected, we want to keep the options set so a user doesn't waste effort
  if(selectedTrackId != '')
  {
    resetTrackOptionInputs() ;
    setSelectedTrack('') ;
  }
  
  // Activate our buttons properly
  $('updateTrackButton').disabled = true ;
  $('removeTrackButton').disabled = true ;
  if($F(select) == 'default')
  {
    $('addTrackButton').disabled = true ;
  }
  else if(columns.count > 0)
  {
    $('addTrackButton').disabled = false ;
  }
}

function setSelectedTrack(trackId)
{
  if(selectedTrackId == trackId)
  {
    return false ;
  }  
  
  if(trackId != '' && $(trackId))
  {
    $(trackId).addClassName('selected') ;
  }

  if(selectedTrackId != '' && $(selectedTrackId))
  {
    $(selectedTrackId).removeClassName('selected') ;
  }
  selectedTrackId = trackId ;
  
  // When a new selected track is set, clear our trackFeedback of any info for the old selected track
  // Also clear out the errored inputs for the old selected track, if any
  $('trackFeedback').update('') ;
  $$('#tracks .error').each(function(input) { $(input).removeClassName('error') ; }) ;
 
  if(trackId != '')
  {
    // If a track has been selected, then we need to set the state of buttons and select
    $('addTrackButton').disabled = true ;
    $('updateTrackButton').disabled = false ;
    $('removeTrackButton').disabled = false ;
    $('tracksSelect').selectedIndex = 0 ;
  }
  
  return true ;
}

function setReferenceTrack(trackObj)
{
  // Always clear our old ref track
  if(referenceTrack)
  {
    clearReferenceTrack() ;
  }
  
  trackObj.isRefTrack = true ;
  referenceTrack = trackObj ;
  if($($F('dataColumnSelect')))
  {
    $($F('dataColumnSelect')).addClassName('reference') ;
  }
  
  // Update our column positions b/c the reference track has been changed
  setDataColumnPositions() ;
}

function clearReferenceTrack()
{
  $$('#dataColumnsSortable .reference').each(function(el) {
    el.removeClassName('reference') ;
    el.setStyle({ backgroundColor: '' }) ;
  }) ;
  referenceTrack.isRefTrack = false ;
  referenceTrack = null ;
}

function setZIndicesForDataColumn(columnId)
{
  // This method updates the visual zIndex indicator AND updates the data model
  // so the track must be in the columns data structure prior to calling this method
  if(!$('annotTracksSortable') || !columns['cols'][columnId])
  {
    return ;
  }
  
  for(var i = 0 ; i < $('annotTracksSortable').childNodes.length ; i++)
  {
    var trackId = $('annotTracksSortable').childNodes.item(i).id ;
    if(!$(trackId + '_display'))
    {
      continue ;
    }
    var trackObj = columns['cols'][columnId].getTrack(trackId)
    if(trackObj)
    {
      trackObj.zIndex = (i + 1) ;
      $(trackId + '_zindex').innerHTML = 'Layer ' + (i + 1) ;
    }
  }
  
  // Sort our columns tracks array to ensure the order is preserved when drawing
  columns['cols'][columnId].tracks.sort(function(a, b) { return a.zIndex - b.zIndex ; }) ;
}

function resetTrackOptionInputs()
{
  // Set the track option defaults
  $('referenceTrack').checked = false ;
  $('trackWidth').value = '75' ;
  $('trackColor').value = '#000000' ;
  $('trackSwatch').style.backgroundColor = '#000000' ;
  $('trackColorOverride').checked = true ;
  $('trackMargin').value = '0' ;
  $('trackBorder').checked = false ;
  $('trackLegendOrder').value = '' ;
  $('drawingStyle').selectedIndex = 0 ;
  setDisplayName($('tracksSelect')) ;
  showDisplayOptions('block') ;  
}

function resetTrackTabState()
{
  setSelectedTrack('') ;
  $('tracksSelect').selectedIndex = 0 ;

  // In this state, all buttons are disabled
  $('addTrackButton').disabled = true ;
  $('updateTrackButton').disabled = true ;
  $('removeTrackButton').disabled = true ;
}

function createTrackHTML(id, trackName)
{
  var trackHtml = '<div style="overflow: auto ;">' ;
  trackHtml += '  <span id="' + id + '_zindex" style="float: left ;">Layer </span>' ;
  trackHtml += '  <span id="' + id + '_display" style="float: right ;">' + trackName + '</span>' ;
  trackHtml += '</div> ' ;  
  
  var trackLi = document.createElement('li') ;
  trackLi.id = id ;
  $(trackLi).addClassName('movable') ;
  trackLi.style.display = 'none' ;
  if(trackLi.attachEvent)
  {
    trackLi.attachEvent('onclick',
      function() { $('drawingStyle').focus() ; selectAndShowTrackDetails(trackLi.id, $F('dataColumnSelect')) ; }
    ) ;
  }
  else
  {
    trackLi.onclick = function() {
      $('drawingStyle').focus() ; selectAndShowTrackDetails(trackLi.id, $F('dataColumnSelect')) ;
    }
  }    
  $(trackLi).update(trackHtml) ;
  
  return trackLi ;
}

function showTracksForDataColumn(columnId)
{
  // Here we completely destroy all existing track HTML elements and completely
  // construct it new from the selected data column... The annotTracksSortable ul
  // is needed so that the 'New track' li cannot be moved and is not taken into
  // account for the z-index
  var trackLis = '' ;
  var usedTracks = {} ;
  var trackIdToSel = '' ;
  selectedTrackId = '' ;
 
  var tracksStruct = '<li style="border: none ; padding: 0 ; margin: 0 ; background-color: transparent ;"><ul id="annotTracksSortable"></ul></li>' ;
  $('annotTracks').update(tracksStruct) ;
  if(columns['cols'][columnId].tracks.length == 0)
  {
    var emptyMsg = document.createElement('em') ;
    emptyMsg.id = 'emptyTrackMsg' ;
    emptyMsg.appendChild(document.createTextNode('[List empty - Please add a track]')) ;
    $('annotTracks').appendChild(emptyMsg) ;
  }
  else
  {
    for(var i = 0 ; i < columns['cols'][columnId].tracks.length ; i++)
    {
      var id = columns['cols'][columnId].tracks[i].internalId ;
      var name = columns['cols'][columnId].tracks[i].trackName ;
      var track = createTrackHTML(id, name) ;
      $('annotTracksSortable').appendChild(track) ;
      Effect.Appear(track) ;
      usedTracks[name] = 1 ;
    }
    
    setZIndicesForDataColumn(columnId) ;
    Sortable.create('annotTracksSortable', {onUpdate : function() { setZIndicesForDataColumn(columnId) ; }}) ;
  }
  resetTrackOptionInputs() ;
  resetTrackTabState() ;
  
  // Repopulate our tracks select
  // Using a manual method to populate the list, see updateDataColumnSelect for explanation
  $('tracksSelect').options.length = 0 ;
  var option = document.createElement('option') ;
  option.value = 'default' ;
  option.appendChild(document.createTextNode('--- Select a track to add to this column ---')) ;
  $('tracksSelect').appendChild(option) ;
  
  for(var i = 0 ; i < allTracks.length ; i++)
  {
    if(usedTracks[allTracks[i]])
    {
      continue ;
    }
    
    var option = document.createElement('option') ;
    option.value = allTracks[i] ;
    option.appendChild(document.createTextNode(allTracks[i])) ;
    $('tracksSelect').appendChild(option) ;
  }
}

function selectAndShowTrackDetails(trackId, columnId)
{
  if(!trackId || !columnId || !columns['cols'][columnId] || !setSelectedTrack(trackId))
  {
    return ;
  }
  
  // Set the track details -- find our exact track
  var track = columns['cols'][columnId].getTrack(trackId) ;
  if(track == null)
  {
    return ;
  }
  
  // Set options value that are present for all tracks
  $('referenceTrack').checked = track.isRefTrack ;
  $('trackWidth').value = track.width ;
  $('trackColor').value = track.color ;
  $('trackSwatch').style.backgroundColor = track.color ;
  $('trackColorOverride').checked = track.annoColorOverride ;
  $('trackDisplayName').value = track.displayName ;
  $('trackMargin').value = track.margin ;
  $('trackBorder').checked = track.border ;
  $('trackLegendOrder').value = (track.legendOrder > 0) ? track.legendOrder : '' ;
  for(var i = 0 ; i < $('drawingStyle').options.length ; i++)
  {
    if($('drawingStyle').options[i].value == track.drawingStyle)
    {
      $('drawingStyle').selectedIndex = i ;
      break ;
    }
  }
  showDisplayOptions(track.drawingStyle) ;
  
  // Set style specific options value
  for(var option in track.styleOptions)
  {
    if(!$(option))
    {
      continue ;
    }
    
    // The input elements must have IDs that are the option names (eg, option = fillColor, el must have id = fillColor)
    if($(option).type == 'text' || $(option).type == 'hidden')
    {
      $(option).value = track.styleOptions[option] ;
      
      if(/color/i.test(option) && $(option + 'Swatch'))
      {
        $(option + 'Swatch').style.backgroundColor = track.styleOptions[option] ;
      }
    }
    else if($(option).type == 'checkbox')
    {
      $(option).checked = track.styleOptions[option] ;
    }
    else if($(option).type == 'select-one')
    {
      for(var i = 0 ; i < $(option).options.length ; i++ )
      {
        if($(option).options[i].value == track.styleOptions[option])
        {
          $(option).selectedIndex = i ;
          break ;
        }
      }
    }
  }
}

function changeDrawingStyle(drawingStyle)
{
  if(drawingStyle == 'cytoband')
  {
    var refTrack = $('referenceTrack') ;
    if(refTrack)
    {
      refTrack.checked = true ;
    }
  }

  showDisplayOptions(drawingStyle) ;
}

function showDisplayOptions(drawingStyle)
{
  var standard = '' ;
  var advanced = '' ;
  
  if(!$('displaySpecificOptions') || !$('displaySpecificAdvancedOptions'))
  {
    return ;
  }
 
  if(drawingStyle != 'cytoband')
  {
    var optStrings = new Array() ;
    optStrings.push('<div class="option">') ;
    optStrings.push('  <label for="threshAboveScore">') ;
    optStrings.push('    Draw annotation with a score above:') ;
    optStrings.push('  </label>') ;
    optStrings.push('  <div class="optionInput">') ;
    optStrings.push('    <span style="float: left ;"><input type="text" id="threshAboveScore" size="6" onkeypress="return validateFloat(event, this) ;" /></span>') ;
    optStrings.push('    <span style="float: left ; margin: 0.65em 0.5em 0 0.5em ;">with color</span>') ;
    optStrings.push('    <div class="colorInput" style="float: left ; width: 50% ;">') ;
    optStrings.push('      <div id="threshAboveColorSwatch" class="swatch" style="background-color: #000000 ;"></div>') ;
    optStrings.push('      <input type="hidden" id="threshAboveColor" value="#000000">') ;
    optStrings.push('      <div style="float: left ;">') ;
    optStrings.push('        <a class="colorLink" href="#" onclick="setDivId(\'threshAboveColorSwatch\', \'threshAboveColor\', \'#000000\') ; return false ;">Change Color</a>') ;
    optStrings.push('      </div>') ;
    optStrings.push('    </div>') ;
    optStrings.push('  </div>') ;
    optStrings.push('</div>') ;
    optStrings.push('<div class="option">') ;
    optStrings.push('  <label for="threshBelowScore">') ;
    optStrings.push('    Draw annotation with a score below:') ;
    optStrings.push('  </label>') ;
    optStrings.push('  <div class="optionInput">') ;
    optStrings.push('    <span style="float: left ;"><input type="text" id="threshBelowScore" size="6" onkeypress="return validateFloat(event, this) ;" /></span>') ;
    optStrings.push('    <span style="float: left ; margin: 0.65em 0.5em 0 0.5em ;">with color</span>') ;
    optStrings.push('    <div class="colorInput" style="float: left ; width: 50% ;">') ;
    optStrings.push('      <div id="threshBelowColorSwatch" class="swatch" style="background-color: #000000 ;"></div>') ;
    optStrings.push('      <input type="hidden" id="threshBelowColor" value="#000000">') ;
    optStrings.push('      <div style="float: left ;">') ;
    optStrings.push('        <a class="colorLink" href="#" onclick="setDivId(\'threshBelowColorSwatch\', \'threshBelowColor\', \'#000000\') ; return false ;">Change Color</a>') ;
    optStrings.push('      </div>') ;
    optStrings.push('    </div>') ;
    optStrings.push('  </div>') ;
    optStrings.push('</div>') ;

    advanced = optStrings.join('\n') ;
  }
  
  switch(drawingStyle)
  {
    case 'box' :      
      standard += '<div class="option">'
               +  '  <label for="fillColor">'
               +  '    Box fill color:' 
               +  '  </label>'
               +  '  <div class="optionInput colorInput">'
               +  '    <div id="fillColorSwatch" class="swatch" style="background-color: #000000 ;"></div>'
               +  '    <input type="hidden" id="fillColor" value="#000000">'
               +  '    <div style="float: left ; width: 50% ;">'
               +  '      <a class="colorLink" href="#" onclick="setDivId(\'fillColorSwatch\', \'fillColor\', \'#000000\') ; return false ;">Change Color</a>'
               +  '    </div>'
               +  '  </div>'
               +  '</div>'
               +  '<div class="option">'
               +  '  <label for="transparency">'
               +  '    Box transparency:'
               +  '  </label>'
               +  '  <div class="optionInput">'
               +  '    <span>'
               +  '      <input type="text" id="transparency" size="6" value="0" onkeypress="return validateInt(event) ;" onblur="checkIntRange(this, 0, 100)"/>'
               +  '    </span>'
               +  '    [0 - 100]'
               +  '  </div>'
               +  '</div>' ;
      break ;
    case 'score' :
      standard += '<div class="option">'
               +  '  <label for="minScore">'
               +  '    Minimum annotation score:'
               +  '  </label>'
               +  '  <div class="optionInput">'
               +  '    <span>'
               +  '      <input type="text" id="minScore" size="6" onkeypress="return validateFloat(event, this) ;" />'
               +  '    </span>'
               +  '  </div>'
               +  '</div>'
               +  '<div class="option">'
               +  '  <label for="maxScore">'
               +  '    Maximum annotation score:'
               +  '  </label>'
               +  '  <div class="optionInput">'
               +  '    <span>'
               +  '      <input type="text" id="maxScore" size="6" onkeypress="return validateFloat(event, this) ;" />'
               +  '    </span>'
               +  '  </div>'
               +  '</div>'
               +  '<div class="option">'
               +  '  <label for="drawScoreAxis">'
               +  '    Draw axis?'
               +  '  </label>'
               +  '  <div class="optionInput">'
               +  '    <input type="checkbox" class="checkbox" id="drawScoreAxis" />'
               +  '  </div>'
               +  '</div>'
               +  '<div class="option">'
               +  '  <label for="threshold">'
               +  '    Threshold line:'
               +  '  </label>'
               +  '  <div class="optionInput">'
               +  '    <span>'
               +  '      <input type="text" id="threshold" size="6" onkeypress="return validateFloat(event, this) ;" />'
               +  '    </span>'
               +  '  </div>'
               +  '</div>'
               +  '<div class="option">'
               +  '  <label for="direction">'
               +  '    Annotation drawing direction:'
               +  '  </label>'
               +  '  <div class="optionInput">'
               +  '    <select id="direction" >'
               +  '      <option value="right">Right</option>'
               +  '      <option value="left">Left</option>'
               +  '    </select>'
               +  '  </div>'
               +  '</div>' ;

      advanced += '<div class="option">'
               +  '  <label for="drawGrid">'
               +  '    Draw grid?'
               +  '  </label>'
               +  '  <div class="optionInput">'
               +  '    <input type="checkbox" class="checkbox" id="drawGrid" />'
               +  '  </div>'
               +  '</div>'
               +  '<div class="option">'
               +  '  <label for="scoreOverlap">'
               +  '    Score overlap mode: '
               +  '  </label>'
               +  '  <div class="optionInput">'
               +  '    <select id="scoreOverlap">'
               +  '      <option value="max" selected="selected">Maximum Value</option>'
               +  '      <option value="min">Minimum Value</option>'
               +  '      <option value="average">Average Value</option>'
               +  '      <option value="median">Median Value</option>'
               +  '    </select>'
               +  '  </div>'
               +  '</div>'
               +  '<div class="option">'
               +  '  <label for="scoreAxisIncrement">'
               +  '    Axis increment:'
               +  '  </label>'
               +  '  <div class="optionInput">'
               +  '    <span>'
               +  '      <input type="text" id="scoreAxisIncrement" size="6" onkeypress="return validateInt(event, this) ;" />'
               +  '    </span>'
               +  '    (positive integer)'
               +  '  </div>'
               +  '</div>'
               +  '<div class="option">'
               +  '  <label for="fontSize">'
               +  '    Axis label font size:'
               +  '  </label>'
               +  '  <div class="optionInput">'
               +  '    <span>'
               +  '      <input type="text" id="fontSize" size="6" value="10" onkeypress="return validateInt(event) ;" onblur="checkPosInt(this) ;" />'
               +  '    </span>'
               +  '    (point units)'
               +  '  </div>'
               +  '</div>'
               +  '<div class="option">'
               +  '  <label for="font">'
               +  '    Axis label font:'
               +  '  </label>'
               +  '  <div class="optionInput">'
               +  '    <select id="font">' ;
      for(var i = 0 ; i < fonts.length ; i++)
      {
        selected = '' ;
        if(fonts[i].value.toLowerCase() == defaultFont)
        {
          selected = ' selected="selected"' ;
        }
        advanced += '    <option value="'+fonts[i].value+'" style="font-family: \''+fonts[i].value+'\', sans-serif ;"'+selected+'>'+fonts[i].name+'</option>' ;
      }
      advanced += '    </select>'
               +  '  </div>'
               +  '</div>'
               +  '<div class="option">'
               +  '  <label for="fontColor">'
               +  '    Axis label font color:'
               +  '  </label>'
               +  '  <div class="optionInput colorInput">'
               +  '    <div id="fontColorSwatch" class="swatch" style="background-color: #000000 ;"></div>'
               +  '    <input type="hidden" id="fontColor" value="#000000">'
               +  '    <div style="float: left ; width: 50% ;">'
               +  '      <a class="colorLink" href="#" onclick="setDivId(\'fontColorSwatch\', \'fontColor\', \'#000000\') ; return false ;">Change Color</a>'
               +  '    </div>'
               +  '  </div>'
               +  '</div>' ;
      break ;
    case 'doubleSidedScore' :
      standard += '<div class="option">'
               +  '  <label for="minScore">'
               +  '    Minimum annotation score:'
               +  '  </label>'
               +  '  <div class="optionInput">'
               +  '    <span>'
               +  '      <input type="text" id="minScore" size="6" onkeypress="return validateFloat(event, this) ;" />'
               +  '    </span>'
               +  '  </div>'
               +  '</div>'
               +  '<div class="option">'
               +  '  <label for="maxScore">'
               +  '    Maximum annotation score:'
               +  '  </label>'
               +  '  <div class="optionInput">'
               +  '    <span>'
               +  '      <input type="text" id="maxScore" size="6" onkeypress="return validateFloat(event, this) ;" />'
               +  '    </span>'
               +  '  </div>'
               +  '</div>'
               +  '<div class="option">'
               +  '  <label for="drawScoreAxis">'
               +  '    Draw axis?'
               +  '  </label>'
               +  '  <div class="optionInput">'
               +  '    <input type="checkbox" class="checkbox" id="drawScoreAxis" />'
               +  '  </div>'
               +  '</div>'
               +  '<div class="option">'
               +  '  <label for="positiveThreshold">'
               +  '    Positive threshold line:'
               +  '  </label>'
               +  '  <div class="optionInput">'
               +  '    <span>'
               +  '      <input type="text" id="positiveThreshold" size="6" onkeypress="return validateFloat(event, this) ;" />'
               +  '    </span>'
               +  '    (positive float)'
               +  '  </div>'
               +  '</div>'
               +  '<div class="option">'
               +  '  <label for="negativeThreshold">'
               +  '    Negative threshold line:'
               +  '  </label>'
               +  '  <div class="optionInput">'
               +  '    <span>'
               +  '      <input type="text" id="negativeThreshold" size="6" onkeypress="return validateFloat(event, this) ;" />'
               +  '    </span>'
               +  '    (negative float)'
               +  '  </div>'
               +  '</div>' ;

      advanced += '<div class="option">'
               +  '  <label for="drawGrid">'
               +  '    Draw grid?'
               +  '  </label>'
               +  '  <div class="optionInput">'
               +  '    <input type="checkbox" class="checkbox" id="drawGrid" />'
               +  '  </div>'
               +  '</div>'
               +  '<div class="option">'
               +  '  <label for="scoreOverlap">'
               +  '    If scores overlap, use the: '
               +  '  </label>'
               +  '  <div class="optionInput">'
               +  '    <select id="scoreOverlap">'
               +  '      <option value="max" selected="selected">Maximum Value</option>'
               +  '      <option value="min">Minimum Value</option>'
               +  '      <option value="average">Average Value</option>'
               +  '      <option value="median">Median Value</option>'
               +  '    </select>'
               +  '  </div>'
               +  '</div>'
               +  '<div class="option">'
               +  '  <label for="scoreAxisIncrement">'
               +  '    Axis increment:'
               +  '  </label>'
               +  '  <div class="optionInput">'
               +  '    <span>'
               +  '      <input type="text" id="scoreAxisIncrement" size="6" onkeypress="return validateInt(event, this) ;" />'
               +  '    </span>'
               +  '    (positive integer)'
               +  '  </div>'
               +  '</div>'
               +  '<div class="option">'
               +  '  <label for="fontSize">'
               +  '    Axis label font size:'
               +  '  </label>'
               +  '  <div class="optionInput">'
               +  '    <span>'
               +  '      <input type="text" id="fontSize" size="6" value="10" onkeypress="return validateInt(event) ;" onblur="checkPosInt(this) ;" />'
               +  '    </span>'
               +  '    (point units)'
               +  '  </div>'
               +  '</div>'
               +  '<div class="option">'
               +  '  <label for="font">'
               +  '    Axis label font:'
               +  '  </label>'
               +  '  <div class="optionInput">'
               +  '    <select id="font">' ;
      for(var i = 0 ; i < fonts.length ; i++)
      {
        selected = '' ;
        if(fonts[i].value.toLowerCase() == defaultFont)
        {
          selected = ' selected="selected"' ;
        }
        advanced += '    <option value="'+fonts[i].value+'" style="font-family: \''+fonts[i].value+'\', sans-serif ;"'+selected+'>'+fonts[i].name+'</option>' ;
      }
      advanced += '    </select>'
               +  '  </div>'
               +  '</div>'
               +  '<div class="option">'
               +  '  <label for="fontColor">'
               +  '    Axis label font color:'
               +  '  </label>'
               +  '  <div class="optionInput colorInput">'
               +  '    <div id="fontColorSwatch" class="swatch" style="background-color: #000000 ;"></div>'
               +  '    <input type="hidden" id="fontColor" value="#000000">'
               +  '    <div style="float: left ; width: 50% ;">'
               +  '      <a class="colorLink" href="#" onclick="setDivId(\'fontColorSwatch\', \'fontColor\', \'#000000\') ; return false ;">Change Color</a>'
               +  '    </div>'
               +  '  </div>'
               +  '</div>' ;
      break ;
    case 'callout' :
      advanced += '<div class="option">'
               +  '  <label for="calloutLength">'
               +  '    Number of characters to show: '
               +  '  </label>'
               +  '  <div class="optionInput">'
               +  '    <span>'
               +  '      <input type="text" id="calloutLength" size="6" value="20" onkeypress="return validateInt(event) ;" onblur="checkIntRange(this, 1, 100)"/>'
               +  '    </span>'
               +  '  [1, 100]'
               +  '  </div>'
               +  '</div>'
               +  '<div class="option">'
               +  '  <label for="calloutField">'
               +  '    Attribute value for callout text: '
               +  '  </label>'
               +  '  <div class="optionInput">'
               +  '    <select id="calloutField">'
               +  '    </select>'
               +  '    <img id="calloutFieldLoading" src="/images/ajaxLoader.gif" alt="Loading..." style="display: none ;" />'
               +  '  </div>'
               +  '</div>'
               +  '<div class="option">'
               +  '  <label for="fontSize">'
               +  '    Callout font size:'
               +  '  </label>'
               +  '  <div class="optionInput">'
               +  '    <span>'
               +  '      <input type="text" id="fontSize" size="6" value="12" onkeypress="return validateInt(event) ;" onblur="checkPosInt(this) ;" />'
               +  '    </span>'
               +  '    (point units)'
               +  '  </div>'
               +  '</div>'
               +  '<div class="option">'
               +  '  <label for="font">'
               +  '    Callout text font:'
               +  '  </label>'
               +  '  <div class="optionInput">'
               +  '    <select id="font">' ;
      for(var i = 0 ; i < fonts.length ; i++)
      {
        selected = '' ;
        if(fonts[i].value.toLowerCase() == defaultFont)
        {
          selected = ' selected="selected"' ;
        }
        advanced += '    <option value="'+fonts[i].value+'" style="font-family: \''+fonts[i].value+'\', sans-serif ;"'+selected+'>'+fonts[i].name+'</option>' ;
      }
      advanced += '    </select>'
               +  '  </div>'
               +  '</div>'
               +  '<div class="option">'
               +  '  <label for="fontColor">'
               +  '    Callout text color:'
               +  '  </label>'
               +  '  <div class="optionInput colorInput">'
               +  '    <div id="fontColorSwatch" class="swatch" style="background-color: #000000 ;"></div>'
               +  '    <input type="hidden" id="fontColor" value="#000000">'
               +  '    <div style="float: left ; width: 50% ;">'
               +  '      <a class="colorLink" href="#" onclick="setDivId(\'fontColorSwatch\', \'fontColor\', \'#000000\') ; return false ;">Change Color</a>'
               +  '    </div>'
               +  '  </div>'
               +  '</div>' ;
      break ;
  }
  
  $('displaySpecificOptions').update(standard) ;
  $('displaySpecificAdvancedOptions').update(advanced) ;
      
  // If we are a callout style, we must update the attributes available to us for callout fields - Has to be done after the update
  if(drawingStyle == 'callout')
  {
    if(selectedTrackId == '' && $F('tracksSelect') != 'default')
    {
      updateCalloutAttribs($F('tracksSelect'), 'name') ;
    }
    else if(selectedTrackId != '')
    {
      // If we are showing options for an added track, make sure we display the appropriate options
      var tmpTrack = columns['cols'][$F('dataColumnSelect')].getTrack(selectedTrackId) ;
      
      if(tmpTrack)
      {
        updateCalloutAttribs(tmpTrack.trackName, tmpTrack.styleOptions.calloutField) ;
      }
    }
  }
}

function updateCalloutAttribs(trackName, selected)
{
  var escapedRestUri = encodeURIComponent('/REST/v1/grp/' + encodeURIComponent(groupName) +
    '/db/' + encodeURIComponent(rseqName) + '/trk/' + encodeURIComponent(trackName) + '/annoAttributes') ;
  
  if($('calloutFieldLoading'))
  {
    $('calloutFieldLoading').show() ;
  }

  $('calloutField').options.length = 0 ;
  new Ajax.Request('/java-bin/apiCaller.jsp?rsrcPath=' + escapedRestUri + '&method=GET', {
    method : 'get',
    onComplete : function(transport) {
      if(!$('calloutField'))
      {
        return ;
      }
      
      // Fill with our standard LFF files
      var standardFields = [
        {"value" : "class", "name" : "Anno. Class"},
        {"value" : "name", "name" : "Anno. Name"},
        {"value" : "type", "name" : "Anno. Type"},
        {"value" : "subtype", "name" : "Anno. Subtype"},
        {"value" : "chrom", "name" : "Anno. Chrom."},
        {"value" : "start", "name" : "Anno. Start"},
        {"value" : "stop", "name" : "Anno. Stop"},
        {"value" : "length", "name" : "Anno. Length"},
        {"value" : "strand", "name" : "Anno. Strand"},
        {"value" : "phase", "name" : "Anno. Phase"},
        {"value" : "score", "name" : "Anno. Score"},
        {"value" : "tstart", "name" : "Anno. QStart"},
        {"value" : "tend", "name" : "Anno. QStop"},
        {"value" : "sequence", "name" : "Anno. Sequence"},
        {"value" : "comments", "name" : "Anno. Comments"}
      ] ;
      
      for(var i = 0 ; i < standardFields.length ; i++)
      {
        var option = document.createElement('option') ;
        option.value = standardFields[i].value ;
        if(selected == standardFields[i].value)
        {
          option.selected = true ;
        }
        option.appendChild(document.createTextNode(standardFields[i].name)) ;
        $('calloutField').appendChild(option) ;
      }
      
      if(transport.status >= 200 && transport.status < 300)
      {
        var restData = eval('('+transport.responseText+')') ;
        restData.data.sort(function(a, b) {
          if(a.text < b.text)  { return -1 ; }
          if(a.text > b.text)  { return 1 ; }
          if(a.text == b.text) { return 0 ; }
        }) ;
        
        for(var i = 0 ; i < restData.data.length ; i++)
        {
          var option = document.createElement('option') ;
          option.value = restData.data[i].text ;
          if(selected == restData.data[i].text)
          {
            option.selected = true ;
          }
          option.appendChild(document.createTextNode(restData.data[i].text)) ;
          $('calloutField').appendChild(option) ;
        }
      }
      
      if($('calloutFieldLoading'))
      {
        $('calloutFieldLoading').hide() ;
      }
    }
  }) ;
}

function assignCytobandStyle(checked)
{
  if(checked && $('drawingStyle').selectedIndex != 2)
  {
    $('drawingStyle').selectedIndex = 2 ;
    if($('drawingStyle').onchange)
    {
      $('drawingStyle').onchange() ;
    }
  }
}
/** END TRACK METHODS **/

/** JOB CREATION METHODS **/
function requestJob()
{
  // No need to do error checks here because the submit button is only enabled when no
  // errors are present. So if we get here, by design we must be error free.
  $('status').update('') ;
  new Ajax.Updater('status', '/genboree/vgpConfigRequestHandler.rhtml', {parameters: {options: createParamsObject()}}) ;
}

function createParamsObject()
{
  var epWidth = 0 ;
  var params = '{' ;
  var columnsObj = '"columns" : {' ;
  
  // First, establish the entryPoints that need to be drawn, only POST those that are marked for drawing...
  params += '"entryPoints" : [' ;
  var epsString = new Array() ;
  var segsString = new Array() ;
  for(var ep in entryPoints['eps'])
  {
    if(entryPoints['eps'][ep].drawn)
    {
      epsString.push(entryPoints['eps'][ep].marshal("json")) ;

      if(entryPoints['eps'][ep].mode != 'full')
      {
        segsString.push(entryPoints['eps'][ep].marshalSegs('json')) ;
      }
    }
  }
  params += epsString.join(',') + ']' ;

  if(segsString.length > 0)
  {
    params += ', "segments" : [' + segsString.join(',') + ']' ;
  }
  
  // Next, setup the image annotation options
  if($F('title') != '')
  {
    params += ', "figureTitle" : "' + escapeJson($F('title')).trim() + '"' ;
    params += ', "titleFormat" : {' ;
    params += '"font" : "' + $F('titleFont') + '", "fontSize" : ' + $F('titleFontSize') + ', "fontColor" : "' + $F('titleFontColor') + '"' ;
    params += '}' ;
  }
  
  if($F('subtitle') != '')
  {
    params += ', "subtitle" : "' + escapeJson($F('subtitle')).trim() + '"' ;
    params += ', "subtitleFormat" : {' ;
    params += '"font" : "' + $F('subtitleFont') + '", "fontSize" : ' + $F('subtitleFontSize') + ', "fontColor" : "' + $F('subtitleFontColor') + '"' ;
    params += '}' ;
  }
  
  if($F('xAxisLabel') != '')
  {
    params += ', "xAxisLabel" : "' + escapeJson($F('xAxisLabel')).trim() + '"' ;
    params += ', "xAxisLabelFormat" : {' ;
    params += '"font" : "' + $F('xAxisFont') + '", "fontSize" : ' + $F('xAxisFontSize') + ', "fontColor" : "' + $F('xAxisFontColor') + '"' ;
    params += '}' ;
  }
  
  if($F('yAxisLabel') != '')
  {
    params += ', "yAxisLabel" : "' + escapeJson($F('yAxisLabel')).trim() + '"' ;
    params += ', "yAxisLabelFormat" : {' ;
    params += '"font" : "' + $F('yAxisFont') + '", "fontSize" : ' + $F('yAxisFontSize') + ', "fontColor" : "' + $F('yAxisFontColor') + '"' ;
    params += '}' ;
  }  
  
  // Always specify the axis scale
  params += ', "yAxisScaleFormat" : {' ;
  params += '"position" : "' + $F('yAxisScale') + '"' ;
  if($F('yAxisScale') != 'none')
  {
    params += ', "font" : "' + $F('yAxisScaleFont') + '", "fontSize" : ' + $F('yAxisScaleFontSize') + ', "fontColor" : "' + $F('yAxisScaleFontColor') + '"' ;
  }
  params += '}' ;

  // Column data - titles
  if(columns.count > 0)
  {
    var numTrackTypes = 0 ;
    var titleStrings = new Array() ;
    var allTracksStrings = {} ;
    
    columnsObj += '"titles" : [' ;
    for(var col in columns['cols'])
    {
      var colWidth = 0 ;
      titleStrings.push(columns['cols'][col].marshal('json')) ;
      
      // Annotation tracks 
      // In the JS, we represent tracks as being a PART of a data column, however in VGP param file
      // columns and tracks are completely separate. So we replicate the param file structure here
      // to make the output of the client a valid VGP JSON param object
      // - NOTE: If proc. time is an issue, this can be migrated to the server
      // 'tracks' : {"Track1Name" : [{track1[0].marshal}, {track1[1].marshal}], "Track2Name" : [{track2[0].marshal}]}
      for(var i = 0 ; i < columns['cols'][col].tracks.length ; i++)
      {
        // Find the max track width for this column
        if(columns['cols'][col].tracks[i].width > colWidth)
        {
          colWidth = columns['cols'][col].tracks[i].width ;
        }
        
        var trackName = columns['cols'][col].tracks[i].trackName ;
        columns['cols'][col].tracks[i].position = columns['cols'][col].position ;
        if(columns['cols'][col].tracks[i].isRefTrack)
        {
          continue ;
        }
        
        if(!allTracksStrings[trackName])
        {
          numTrackTypes++ ;
          allTracksStrings[trackName] = new Array(columns['cols'][col].tracks[i].marshal('json')) ;
        }
        else
        {
          allTracksStrings[trackName].push(columns['cols'][col].tracks[i].marshal('json')) ;
        }
      }
      
      epWidth += colWidth ;
    }
    columnsObj += titleStrings.join(',') ;
    columnsObj += ']' ; // Close our titles array
    
    // Now create our tracks object
    var count = 0 ;
    for(var trackName in allTracksStrings)
    {
      count++ ;
      if(count == 1)
      {
        params += ', "tracks" : {' ;
      }
      params += '"' + escapeJson(trackName) + '" : [' ;
      params += allTracksStrings[trackName].join(',') ;
      params += ']' ;
      if(count < numTrackTypes)
      {
        params += ', ' ;
      }
    }
    if(count > 0 )
    {
      // We might not have had any tracks besides a reference track...
      params += '}' ;
    }
  }

  // Establish the figures that need to be created and specify the options
  if($F('imageClass') == 'genomeView')
  {
    params += ', "genomeView" : {' ;
    if(epWidth > 0 && numEpsDrawn > 0)
    {
      params += '"width" : ' + (epWidth * numEpsDrawn) + ', ' ;
    }
    params += '"margin" : '+ $F('genomeMargin')+', "chromosomeBorder" : ' + $('genomeBorders').checked + ', ' ;
    params += '"chrLabelFont" : "' + $F('genomeFont') + '", "chrLabelFontColor" : "'+$F('genomeFontColor') + '", ' ;
    params += '"chrLabelFontSize" : ' + $F('genomeFontSize') ;
    params += '}' ;
    params += ', "chromosomesLabels" : ' + $('genomeChrLabels').checked ;
    params += ', "drawEmptyCytobands" : ' + $('drawEmptyCytobandsGV').checked ;
  }
  else
  {
    params += ', "chromosomeView" : {' ;
    params += '"border" : ' + $('chromBorder').checked + ', "labelPosition" : "' + $F('chromXLabelPos') + '"' ;
    params += '}' ;
    params += ', "drawEmptyCytobands" : ' + $('drawEmptyCytobandsCV').checked ;
  }

  // Legends
  if($('trackLegend').checked)
  {
    var tLegendPos = $F('tLegendPos') ;
    if($('columnLegend').checked && ($F('cLegendPos') == tLegendPos))
    {
      tLegendPos += '-' + $F('tLegendSecPosSelect') ;
    }
    
    params += ', "legend" : {' ;
    params += '"position" : "' + tLegendPos + '", "border" : ' + $('tLegendBorder').checked + ', ' ;
    params += '"columns" : ' + $F('tLegendColNum') + ', "font" : "' + $F('tLegendFont') + '", ' ;
    params += '"fontSize" : ' + $F('tLegendFontSize') + ', "fontColor" : "' + $F('tLegendFontColor') + '"' ;
    params += '}' ;
  }
  
  if($('columnLegend').checked)
  {
    var cLegendPos = $F('cLegendPos') ;
    if($('trackLegend').checked && ($F('tLegendPos') == cLegendPos))
    {
      cLegendPos += '-' + $('cLegendSecPosSpan').innerHTML.toLowerCase() ;
    }
    
    columnsObj += ',  "legend" : {' ;
    columnsObj += '"position" : "' + cLegendPos + '", "border" : ' + $('cLegendBorder').checked + ', ' ;
    columnsObj += '"columns" : ' + $F('cLegendColNum') + ', "font" : "' + $F('cLegendFont') + '", ' ;
    columnsObj += '"fontSize" : ' + $F('cLegendFontSize') + ', "fontColor" : "' + $F('cLegendFontColor') + '"' ;
    columnsObj += '}' ;
  }  
  
  // Finally, our reference track if we have one
  if(referenceTrack)
  {
    params += ', "referenceTrack" : {' ;
    params += '"' + escapeJson(referenceTrack.trackName) + '" : [' + referenceTrack.marshal('json') + ']';
    params += '}' ;
  }
  
  columnsObj += '}' ;
  params += ', ' + columnsObj ;
  
  // The very last thing we do is set our config values for the VGP run
  params += ', "config" : {' ;
  params += '"userId" : '+ userId +', "groupId" : '+ groupId + ', "groupName" : "' + groupName + '", "rseqId" : '+ rseqId + ', "rseqName" : "' + rseqName + '", ' ;
  params += '"userLogin" : "' + escapeJson(userLogin) + '", "userEmail" : "'+ escapeJson(userEmail) + '"' ;
  params += '}' ;
  
  // Close our one large object that contains all these parameters
  params += '}' ;

  return params ;
}
/** END JOB CREATION METHODS **/
