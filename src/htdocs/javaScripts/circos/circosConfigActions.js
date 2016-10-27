/**********************************
* Project: Circos UI Integration
*   This project creates a User Interface (UI) to assist users in
*   creating parameter files for Circos (v0.49), a data visualization tool.
*   The integration also creates a server-side support environment to create
*   necessary configuration files, queue a Circos job with the Genboree environment
*   and then package the Circos output files and notify the user of job completion.
*
* circosConfigActions.js - This javascript file defines the client-side 
*   actions for any changes made in the UI (circosConfig.rhtml)
*
* Developed by Bio::Neos, Inc. (BIONEOS)
* under a software consulting contract for:
* Baylor College of Medicine (CLIENT)
* Copyright (c) 2009 CLIENT owns all rights.
* To contact BIONEOS, visit http://bioneos.com
**********************************/

/** Entry Point Actions **/
function addEntryPoint(epName, grpName, rseqName)
{
  var feedbackDiv = $(tabs.epTab.feedbackDivId) ;

  if(epName == "" || !/\S+/.test(epName))
  {
    return ;
  }
  feedbackDiv.update('') ;

  if(CircosUI.entryPoints.eps['ep_'+epName.toLowerCase()])
  {
    // This entry point is already in the EPs data struct.
    feedbackDiv.update('<div class="warning">The entry point \'' + epName + '\' has already been added.') ;

    return ;
  }

  // Check to see if the EP exists in the DB
  var escapedRestUri = encodeURIComponent('/REST/v1/grp/' + encodeURIComponent(grpName) +
    '/db/' + encodeURIComponent(rseqName) + '/ep/' + encodeURIComponent(epName)) ;

  new Ajax.Request('/java-bin/apiCaller.jsp?rsrcPath=' + escapedRestUri + '&method=GET', {
    method : 'get',
    onSuccess : function(transport) {
      var restData = eval('('+transport.responseText+')') ;

      if(!restData.data.name || !restData.data.length)
      {
        // We need the EP name and length, otherwise this request was a bust. The response header
        // should have been a failure, but as a backup relay the error if we somehow get to this block
        feedbackDiv.update('<div class="failure">The entry point \'' + epName + '\' was not found in the database and could not be added!') ;

        return ;
      }

      // Visuals
      var newEp = document.createElement('option') ;
      newEp.id = 'ep_' + restData.data.name.toLowerCase() ;
      newEp.value = 'ep_' + restData.data.name.toLowerCase() ;
      newEp.appendChild(document.createTextNode(restData.data.name)) ;
      $('epsList').appendChild(newEp) ;
      $('removeButton').disabled = false ;
      $('epEntry').value = "" ;

      // Add to data structure
      CircosUI.entryPoints.eps['ep_'+restData.data.name.toLowerCase()] = new EntryPoint(restData.data.name, parseInt(restData.data.length)) ;
      CircosUI.entryPoints.count++ ;
      CircosUI.numEpsDrawn++ ;
      $('epsDrawn').innerHTML = '' + CircosUI.numEpsDrawn ;
    },
    onFailure : function(transport) {
      // Alert user
      feedbackDiv.update('<div class="failure">The entry point \'' + epName + '\' was not found in the database and could not be added!') ;
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
        delete(CircosUI.entryPoints.eps['ep_'+$(epsList).options[i - 1].value]) ;
        removeCount++ ;

        // Visuals
        $(epsList).remove(i - 1) ;
      }
    }

    if($(epsList).options.length == 0)
    {
      $('removeButton').disabled = true ;
    }

    CircosUI.numEpsDrawn -= removeCount ;
    CircosUI.entryPoints.count -= removeCount ;
    $('epsDrawn').innerHTML = '' + CircosUI.numEpsDrawn ;
  }
}

function processManualEpSelect(selectEl)
{
  if(selectEl.selectedIndex != -1)
  {
    selectAndShowEpDetails(selectEl.options[selectEl.selectedIndex].id) ;
  }

  return ;
}

function toggleEpDrawing(epId)
{
  if($(epId) && CircosUI.entryPoints.eps[epId])
  {
    $(epId).toggleClassName('hidden') ;
    CircosUI.entryPoints.eps[epId].drawn = $(epId+'_check').checked ;

    if($(epId+'_check').checked)
    {
      CircosUI.numEpsDrawn += 1 ;
    }
    else
    {
      CircosUI.numEpsDrawn-- ;
    }
    $('epsDrawn').innerHTML = '' + CircosUI.numEpsDrawn ;
  }
}

function toggleDrawAllEps(drawn)
{
  for(var ep in CircosUI.entryPoints.eps)
  {
    if($(ep) && (CircosUI.entryPoints.eps[ep].drawn != drawn))
    {
      CircosUI.entryPoints.eps[ep].drawn = drawn ;
      $(ep+'_check').checked = drawn ;
      $(ep).toggleClassName('hidden') ;
    }
  }

  // Update our visual to alert the user
  CircosUI.numEpsDrawn = (drawn) ? CircosUI.entryPoints.count : 0 ;
  $('epsDrawn').innerHTML = '' + CircosUI.numEpsDrawn ;
}

function setSelectedEp(epId)
{
  var epEl = $(epId) ;
  var selectedEpEl = $(selectedEpId) ;

  if(selectedEpId === epId)
  {
    return false ;
  }

  if(epEl && epEl.tagName.toLowerCase() != 'option')
  {
    epEl.addClassName('selected') ;
  }

  if(selectedEpEl && selectedEpEl.tagName.toLowerCase() != 'option')
  {
    selectedEpEl.removeClassName('selected') ;
  }

  // Toggle our epdetails availability - This only happens once, after an EP is seleced
  // there will always be at least one selected EP
  if(selectedEpId === '')
  {
    ['epLabel', 'epLength', 'fullEpDiv', 'breakEpDiv'].each(function(id) {
      var el = $(id) ;
      if(el)
      {
        $(id).removeClassName('disabled') ;
      }
    }) ;

    ['epLabel', 'fullEpRadio', 'breakEpRadio', 'epScaling'].each(function(id) {
      var el = $(id) ;
      if(el)
      {
        $(id).disabled = false ;
      }
    }) ;
  }
  selectedEpId = epId ;

  $('epFeedback').update('') ;
  $$('#eps .error').each(function(input) { $(input).removeClassName('error') ; }) ;

  return true ;
}

function setEpColor(epId)
{
  var prevColor = '' ;
  var currColor = '' ;
  if(!epIsValid(epId))
  {
    return false ;
  }

  prevColor = $F('indEpColor') ;
  // THIS ISN'T GOING TO WORK!
  setDivId('indEpColorSwatch', 'indEpColor', '#000000') ;
  currColor = $F('indEpColor') ;
  if(currColor === prevColor)
  {
    return false ;
  }

  CircosUI.entryPoints.eps[epId].color = currColor ;

  return true ;
}

function selectAndShowEpDetails(epId)
{
  var entryPoints = CircosUI.entryPoints ;

  if(!epIsValid(epId) || !setSelectedEp(epId))
  {
    return ;
  }
  
  // Reset our scale and break states because a new EP was selected
  resetScaleInputs() ;
  resetBreakInputs() ;

  // If no color set and all color selected, show all color selected. 
  var epColor = (entryPoints.eps[epId].color != '') ? entryPoints.eps[epId].color : $F('allEpColor') ;
  $('epLabel').value = entryPoints.eps[epId].label ;
  $('epLength').update(new String(entryPoints.eps[epId].length).commaized()) ;
  $(entryPoints.eps[epId].mode + 'Radio').checked = true ;
  $('epBreaksListId').update(entryPoints.eps[epId].label) ;
  $('epScalesListId').update(entryPoints.eps[epId].label) ;
  $('indEpColor').value = epColor;
  $('indEpColorSwatch').style.backgroundColor = epColor ;

  // Update our scales info
  $('epScalesList').update('') ;
  switch(entryPoints.eps[epId].scale)
  {
    case 'globalScale' :
      setSelectElValue('globalScaleFactor', 'globalScaleFactorOther', entryPoints.eps[epId].globalScale) ;
      $('epScaling').selectedIndex = 1 ;
      break ;
    case 'localScale' :
      // Need to populate our local scales
      for(var scaleId in entryPoints.eps[epId].localScales)
      {
        var scaleObj = entryPoints.eps[epId].localScales[scaleId] ;
        var scaleLi = $(document.createElement('li')) ;
        scaleLi.id = scaleId ;
        scaleLi.addClassName('clickable') ;
        if(scaleLi.attachEvent)
        {
          scaleLi.attachEvent('onclick', function(event) { selectAndShowScaleDetails(selectedEpId, scaleLi.id) ; }) ;
        }
        else
        {
          scaleLi.onclick = function() { selectAndShowScaleDetails(selectedEpId, scaleLi.id) ; }
        }
        
        scaleLi.update('Scale from genomic position ' + scaleObj.start + ' to ' + scaleObj.end + ' by a factor of ' + scaleObj.scale) ;
        $('epScalesList').appendChild(scaleLi) ;
      }
      $('epScaling').selectedIndex = 2 ;
      break ;
    default:
      $('epScaling').selectedIndex = 0 ;
      break ;
  }
  toggleEpScaleSpecs(selectedEpId, $F('epScaling')) ;

  // Now display the breaks for the selected EP
  $('epBreaksList').update('') ;
  for(var i = 0 ; i < entryPoints.eps[epId].breaks.length ; i++)
  {
    var breakObj = entryPoints.eps[epId].breaks[i] ;
    var breakLi = $(document.createElement('li')) ;
    breakLi.id = breakObj.id ;
    breakLi.addClassName('clickable') ;
    if(breakLi.attachEvent)
    {
      breakLi.attachEvent('onclick', function(event) { selectAndShowBreakDetails(selectedEpId, breakLi.id) ; }) ;
    }
    else
    {
      breakLi.onclick = function() { selectAndShowBreakDetails(selectedEpId, breakLi.id) ; }
    }

    breakLi.update('Hide sequence from genomic position ' + breakObj.start + ' to ' + breakObj.end) ;
    $('epBreaksList').appendChild(breakLi) ;
  }
  toggleBreakSpecs(entryPoints.eps[epId].mode === 'breakEp') ;

}

function epIsValid(epId)
{
  epId = epId.toLowerCase() ;
  if(epId === '' || !CircosUI.entryPoints.eps[epId])
  {
    var feedbackDiv = $(tabs.epTab.feedbackDivId) ;
    if(feedbackDiv)
    {
      feedbackDiv.update('<div class=\"failure\">Please select an Entry Point from the \'Available Entry Points\' list above.</div>') ;
      feedbackDiv.scrollTo() ;
    }

    return false ;
  }

  return true ;
}

function toggleEpScaleSpecs(epId, scaleStyle)
{
  var specs = undefined ;
  if(!(specs = $('scaleSpecs')) || !epIsValid(epId))
  {
    return ;
  }

  CircosUI.entryPoints.eps[epId].scale = scaleStyle ;
  if(scaleStyle === 'noScale')
  {
    Effect.BlindUp(specs, { queue: 'end', duration: 0.5 }) ;
  }
  else 
  {
    if(scaleStyle === 'globalScale')
    {
      setEpGlobalScaleFactor(epId, $F('globalScaleFactor')) ;
      $('global').show() ;
      $('local').hide() ;
    }
    else
    {
      $('global').hide() ;
      $('local').show() ;
    }

    if(!specs.visible())
    {
      Effect.BlindDown(specs, { queue: 'end', duration: 0.5 }) ;
    }
  }

  return ;
}

function processGlobalScaleChange(factor)
{
  setOtherOptVis('globalScaleFactor', 'globalScaleFactorOther') ;
  if(factor != 'other')
  {
    setEpGlobalScaleFactor(selectedEpId, factor) ;
  }

  return ;
}

function setEpGlobalScaleFactor(epId, factor)
{
  if(!epIsValid(epId) || !factor || factor == 'other')
  {
    return false ;
  }
  CircosUI.entryPoints.eps[epId].globalScale = factor ;

  return true ;
}

function setScaleButtonsStatus(scaleId)
{
  var start = $F('epScaleStart') ;
  var end = $F('epScaleEnd') ;
  
  // TODO: Add epRangeCheck
  if(start && end)
  {
    // Valid start and end values were entered
    if(!scaleId)
    {
      // If we do not have a scale selected, then we are in add mode
      $('addScaleButton').disabled = false ;
      $('updateScaleButton').disabled = true ;
      $('removeScaleButton').disabled = true ;
    }
    else
    {
      // Else, we are in update/remove mode
      $('addScaleButton').disabled = true ;
      $('updateScaleButton').disabled = false ;
      $('removeScaleButton').disabled = false ;
    }
  }
  else
  {
    // Not valid, don't enter
    $('addScaleButton').disabled = true ;
    $('updateScaleButton').disabled = true ;
    $('removeScaleButton').disabled = true ;
  }
}

function addLocalScaleToEp(epId)
{
  if(!epIsValid(epId))
  {
    return false ;
  }

  var start = $F('epScaleStart') ;
  var end = $F('epScaleEnd') ;
  var scale = $F('localScaleFactor') ;
  if(scale === 'other')
  {
    scale = $F('localScaleFactorOther') ;

    if(!scale)
    {
      // Display error message?
      return false ;
    }
  }

  // Create our new scale HTML element
  var scaleLi = document.createElement('li') ;
  $(scaleLi).addClassName('clickable') ;
  scaleLi.style.display = 'none' ;
  scaleLi.id = 'scale_'+ nextScaleIndex ;
  if(scaleLi.attachEvent)
  {
    scaleLi.attachEvent('onclick', function(event) { selectAndShowScaleDetails(selectedEpId, scaleLi.id) ; }) ;
  }
  else
  {
    scaleLi.onclick = function() { selectAndShowScaleDetails(selectedEpId, scaleLi.id) ; }
  }

  scaleLi.update('Scale from genomic position ' + start + ' to ' + end + ' by a factor of ' + scale) ;
  $('epScalesList').appendChild(scaleLi) ;

  // Add our new scale object to our entry point
  CircosUI.entryPoints.eps[epId].localScales[scaleLi.id] = {'start' : start, 'end' : end, 'scale' : scale} ;
  CircosUI.entryPoints.eps[epId].scale = 'localScale' ;
  nextScaleIndex += 1 ;
  
  // Make it visible
  Effect.Appear(scaleLi, { queue: 'end', duration: 0.5 }) ;
  resetScaleInputs() ;

  return true ;
}

function updateLocalScaleInEp(epId, scaleId)
{
  if(!epIsValid(epId) || !CircosUI.entryPoints.eps[epId].localScales[scaleId])
  {
    return false ;
  }

  // We have our scale and everything is valid, update our settings
  var scaleObj = CircosUI.entryPoints.eps[epId].localScales[scaleId] ;
  var scale = $F('localScaleFactor') ;
  scaleObj.start = $F('epScaleStart') ;
  scaleObj.end = $F('epScaleEnd') ;
  if(scale === 'other')
  {
    scale = $F('localScaleFactorOther') ;

    // Display error message?
    if(!scale)
    {
      return false ;
    }
  }
  scaleObj.scale = scale ;

  // Alert the user, visually
  $(scaleId).update('Scale from genomic position ' + scaleObj.start + ' to ' + scaleObj.end + ' by a factor of ' + scaleObj.scale) ;
  new Effect.Highlight(scaleId, { queue: 'end', startcolor: '#EAE6FF', duration: 1.5 }) ;
  resetScaleInputs() ;

  return true ;
}

function removeLocalScaleFromEp(epId, scaleId)
{
  if(!epIsValid(epId) || !CircosUI.entryPoints.eps[epId].localScales[scaleId])
  {
    return false ;
  }

  // Remove scale object from data struct
  delete(CircosUI.entryPoints.eps[epId].localScales[scaleId]) ;

  // Scale removed from data struct, remove from UI
  new Effect.Fade(scaleId, { queue: 'end',  duration: 0.5, afterFinish: function() { $('epScalesList').removeChild($(scaleId)) ; } }) ;
  resetScaleInputs() ;

  return true ;
}

function setSelectedScale(scaleId)
{
  if(!selectElement(scaleId, selectedScaleId))
  {
    return false ;
  }
  selectedScaleId = scaleId ;

  // Clear the EP feedback
  /*$('epFeedback').update('') ;
  $$('#eps .error').each(function(input) { $(input).removeClassName('error') ; }) ;*/

  return true ;
}

function selectAndShowScaleDetails(epId, scaleId)
{
  if(!epIsValid(epId) || !CircosUI.entryPoints.eps[epId].localScales[scaleId] || !setSelectedScale(scaleId))
  {
    return false ;
  }

  $('epScaleStart').value = CircosUI.entryPoints.eps[epId].localScales[scaleId].start ;
  $('epScaleEnd').value = CircosUI.entryPoints.eps[epId].localScales[scaleId].end ;

  // Handle the scale factor
  setSelectElValue('localScaleFactor', 'localScaleFactorOther', CircosUI.entryPoints.eps[epId].localScales[scaleId].scale) ;
  setScaleButtonsStatus(scaleId) ;

  return true ;
}

function resetScaleInputs()
{
  $('epScaleStart').value = '' ;
  $('epScaleEnd').value = '' ;
  $('localScaleFactor').selectedIndex = 1 ;
  $('localScaleFactorOther').update('') ;
  $('localScaleFactorOther').hide() ;
  $('globalScaleFactor').selectedIndex = 0 ;
  $('globalScaleFactorOther').value = '' ;
  $('globalScaleFactorOther').hide() ;
  setSelectedScale('') ;
  setScaleButtonsStatus() ;

  return ;
}
/** END Entry Point Actions **/

/** START Break Actions **/
function toggleBreakSpecs(show)
{
  var breakDiv = $('epBreakSpecs') ;
  if(!breakDiv)
  {
    return ;
  }

  if(show && !breakDiv.visible())
  {
    Effect.BlindDown(breakDiv, { queue: 'end', duration: 0.5 }) ;
    if(selectedEpId && CircosUI.entryPoints.eps[selectedEpId])
    {
     CircosUI.entryPoints.eps[selectedEpId].mode = 'breakEp' ;
    }
  }
  else if(!show && breakDiv.visible())
  {
    Effect.BlindUp(breakDiv, { queue: 'end', duration: 0.5 }) ;
    if(selectedEpId && CircosUI.entryPoints.eps[selectedEpId])
    {
      CircosUI.entryPoints.eps[selectedEpId].mode = 'fullEp' ;
    }
  }

  return ;
}

function addBreakToEp(epId)
{
  if(!epIsValid(epId))
  {
    return false ;
  }

  var start = $F('epBreakStart') ;
  var end = $F('epBreakEnd') ;

  // Create our new break
  var breakLi = document.createElement('li') ;
  $(breakLi).addClassName('clickable') ;
  breakLi.style.display = 'none' ;
  breakLi.id = 'break_'+ nextBreakIndex ;
  if(breakLi.attachEvent)
  {
    breakLi.attachEvent('onclick', function(event) { selectAndShowBreakDetails(selectedEpId, breakLi.id) ; }) ;
  }
  else
  {
    breakLi.onclick = function() { selectAndShowBreakDetails(selectedEpId, breakLi.id) ; }
  }

  breakLi.update('Hide sequence from genomic position ' + start + ' to ' + end) ;
  $('epBreaksList').appendChild(breakLi) ;

  // Add our new break object to our entry point
  CircosUI.entryPoints.eps[epId].breaks.push({'id' : 'break_' + nextBreakIndex, 'start' : start, 'end' : end}) ;
  CircosUI.entryPoints.eps[epId].mode = 'breakEp' ; // Possibly redundant, but a simple safeguard
  nextBreakIndex += 1 ;
  
  // Make it visible
  Effect.Appear(breakLi, { queue: 'end', duration: 0.5 }) ;
  resetBreakInputs() ;

  return true ;
}

function updateBreakInEp(epId, breakId)
{
  if(!epIsValid(epId))
  {
    return false ;
  }

  var breakObj = CircosUI.entryPoints.eps[epId].getBreak(breakId) ;
  if(breakObj === null)
  {
    return false ;
  }

  // We have our breakObj and everything is valid, update our settings
  breakObj.start = $F('epBreakStart') ;
  breakObj.end = $F('epBreakEnd') ;

  // Alert the user, visually
  $(breakId).update('Hide sequence from genomic position ' + breakObj.start + ' to ' +breakObj.end) ;
  new Effect.Highlight(breakId, { queue: 'end', startcolor: '#EAE6FF', duration: 1.5 }) ;
  resetBreakInputs() ;

  return true ;
}

function removeBreakFromEp(epId, breakId)
{
  // Attempt to remove our break from the EP
  if(!epIsValid(epId) || !CircosUI.entryPoints.eps[epId].removeBreakById(breakId))
  {
    return false ;
  }

  // Break removed from data struct, remove from UI
  new Effect.Fade(breakId, { queue: 'end', duration: 0.5, afterFinish: function() { $('epBreaksList').removeChild($(breakId)) ; } }) ;
  resetBreakInputs() ;

  return true ;
}

function setSelectedBreak(breakId)
{
  if(!selectElement(breakId, selectedBreakId))
  {
    return false ;
  }
  selectedBreakId = breakId ;

  /*$('epFeedback').update('') ;
  $$('#eps .error').each(function(input) { $(input).removeClassName('error') ; }) ;*/

  return true ;
}

function selectAndShowBreakDetails(epId, breakId)
{
  if(!setSelectedBreak(breakId) || !CircosUI.entryPoints.eps[epId])
  {
    return false ;
  }

  var breakObj = CircosUI.entryPoints.eps[epId].getBreak(breakId) ;
  if(breakObj === null)
  {
    return false ;
  }

  $('epBreakStart').value = breakObj.start ;
  $('epBreakEnd').value = breakObj.end ;
  setBreakButtonsStatus() ;

  return true ;
}

function setBreakButtonsStatus()
{
  var start = $F('epBreakStart') ;
  var end = $F('epBreakEnd') ;
  
  // TODO: Add epRangeCheck
  if(start && end)
  {
    if(!selectedBreakId)
    {
      $('addBreakButton').disabled = false ;
      $('updateBreakButton').disabled = true ;
      $('removeBreakButton').disabled = true ;
    }
    else
    {
      $('addBreakButton').disabled = true ;
      $('updateBreakButton').disabled = false ;
      $('removeBreakButton').disabled = false ;
    }
  }
  else
  {
    $('addBreakButton').disabled = true ;
    $('updateBreakButton').disabled = true ;
    $('removeBreakButton').disabled = (selectedBreakId) ? false : true ;
  }
}

function resetBreakInputs()
{
  $('epBreakStart').value = '' ;
  $('epBreakEnd').value = '' ;
  setSelectedBreak('') ;
  setBreakButtonsStatus() ;

  return ;
}
/** END Break Actions **/

/** START Tick Actions **/
function addTickMark()
{
  // Create our tick and set options
  var tickObj = new TickMark('tick_' + nextTickIndex) ;
  if(!setTickOptions(tickObj))
  {
    return false ;
  }
  CircosUI.ticks.tickObjs[tickObj.id] = tickObj ;
  CircosUI.ticks.count += 1 ;
  nextTickIndex += 1 ;

  // Create the HTML element
  var tickLi = $(document.createElement('li')) ;
  tickLi.id = tickObj.id ;
  tickLi.addClassName('clickable') ;
  tickLi.style.display = 'none' ;
  if(tickLi.attachEvent)
  {
    tickLi.attachEvent('onclick', function(event) { selectAndShowTickDetails(tickLi.id) ; }) ;
  }
  else
  {
    tickLi.onclick = function() { selectAndShowTickDetails(tickLi.id) ; }
  }

  // Show our element
  tickLi.update(tickObj.toString()) ;
  $('ticks').appendChild(tickLi) ;
  Effect.Appear(tickLi, { queue: 'end', duration: 0.5 }) ;

  resetTickOptionInputs() ;
  resetTickTab() ;

  return true ;
}

function updateTickMark(tickId)
{
  if(!tickId || !CircosUI.ticks.tickObjs[tickId] || !setTickOptions(CircosUI.ticks.tickObjs[tickId]))
  {
    return false ;
  }

  $(tickId).update(CircosUI.ticks.tickObjs[tickId].toString()) ;
  new Effect.Highlight(tickId, { queue: 'end', startcolor: '#EAE6FF', duration: 1.5 }) ;
  resetTickOptionInputs() ;
  resetTickTab() ;

  return true ;
}

function removeTickMark(tickId)
{
  if(!tickId || !CircosUI.ticks.tickObjs[tickId])
  {
    return false ;
  }

  delete(CircosUI.ticks.tickObjs[tickId]) ;

  // Remove from the DOM and hide visually
  Effect.Fade(tickId, { queue: 'end', duration: 0.5, afterFinish: function() { $('ticks').removeChild($(tickId)) ; } }) ;
  resetTickOptionInputs() ;
  resetTickTab() ;

  return true ;
}

function resetTickOptionInputs()
{
  $('showTick').checked = true ;
  $('showLabel').checked = true ;
  $('suffix').checked = true ;
  $('tickLabelSuffixEx').update('e.g. 100Mb') ;
  $('tickUserSpacing').value = '' ;
  $('tickSpacingScale').selectedIndex = 2 ;
  $('size').selectedIndex = 1 ;
  $('sizeOther').update('') ;
  $('sizeOther').hide() ;
  $('labelSize').selectedIndex = 1 ;
  $('labelSizeOther').update('') ;
  $('labelSizeOther').hide() ;
  $('grid').checked = false ;
  $('gridStart').update('') ;
  $('gridEnd').update('') ;
}

function resetTickTab()
{
  $('tracksSelect').selectedIndex = 0 ;
  setSelectedTick('') ;
  setTickButtonsStatus() ;
}

function setTickOptions(tickObj)
{
  if(!tickObj)
  {
    return false ;
  }

  // reset tick feedback? - probably ideo tab feedback
  tickObj.userSpacing = $F('tickUserSpacing') ;
  tickObj.units = $F('tickSpacingScale') ;
  tickObj.setSpacingParams($F('units')) ;
  tickObj.options.suffix = ($('suffix').checked) ? tickObj.units : '' ;

  var manuallySet = {'tickUserSpacing' : true, 'tickSpacingScale' : true, 'suffix' : true} ;
  $('ideo').getElementsBySelector('#tickOpts input').each(function(el)
  {
    if(manuallySet[el.id])
    {
      return ;
    }

    if(el.type === 'text' && $F(el) != '')
    {
      tickObj.options[el.id] = $F(el) ;
    }
    else if(el.type === 'checkbox')
    {
      tickObj.options[el.id] = el.checked ;
    }
  }) ;

  $('ideo').getElementsBySelector('#tickOpts select').each(function(el)
  {
    if(manuallySet[el.id])
    {
      return ;
    }

    var val = $F(el) ;
    if(val === 'other')
    {
      tickObj.options[el.id] = $F(el.id + 'Other') ;
    }
    else
    {
      tickObj.options[el.id] = $F(el) ;
    }
  }) ;

  return true ;
}

function setSelectedTick(tickId)
{
  if(!selectElement(tickId, selectedTickId))
  {
    return false ;
  }
  selectedTickId = tickId ;
  
  if(tickId != '')
  {
    $('addTickButton').disabled = true ;
    $('updateTickButton').disabled = false ;
    $('removeTickButton').disabled = false ;
  
    // Our sel. track has been changed/cleared, clear out errors from previous track
    $(tabs.ideoTab.feedbackDivId).update('') ;
  }

  return true ;
}

function selectAndShowTickDetails(tickId)
{
  var ticks = CircosUI.ticks ;

  if(!ticks.tickObjs[tickId] || !setSelectedTick(tickId))
  {
    return false ;
  }

  // Some special processing of a few options is necessary
  $('suffix').checked = (ticks.tickObjs[tickId].options.labelSuffix != '') ? true : false ;
  $('tickUserSpacing').value = ticks.tickObjs[tickId].userSpacing ;
  var spacingScale = $('tickSpacingScale') ;
  for(var i = 0 ; i < spacingScale.options.length ; i++)
  {
    if(spacingScale.options[i].value === ticks.tickObjs[tickId].units)
    {
      spacingScale.options[i].selected = true ;
      break ;
    }
  }

  for(var option in ticks.tickObjs[tickId].options)
  {
    var optionEl = $(option) ;
    if(!optionEl)
    {
      continue ;
    }

    if(optionEl.type === 'text')
    {
      optionEl.value = ticks.tickObjs[tickId].options[option] ;

    }
    else if(optionEl.type === 'checkbox')
    {
      optionEl.checked = ticks.tickObjs[tickId].options[option] ;
    }
    else if(optionEl.type === 'select-one')
    {
      setSelectElValue(option, option + 'Other', ticks.tickObjs[tickId].options[option]) ;
    }
  }

  return true ;
}

function updateTickLabelSuffixEx(unitLabel)
{
  var suffixEl = $('tickLabelSuffixEx') ;
  if(!suffixEl)
  {
    return ;
  }
  suffixEl.update('(e.g. 100' + unitLabel.capitalize() + ')') ;
  
  return ;
}

function setTickButtonsStatus()
{
  var spacing = $F('tickUserSpacing') ;
  
  if(spacing)
  {
    if(!selectedTickId)
    {
      $('addTickButton').disabled = false ;
      $('updateTickButton').disabled = true ;
      $('removeTickButton').disabled = true ;
    }
    else
    {
      $('addTickButton').disabled = true ;
      $('updateTickButton').disabled = false ;
      $('removeTickButton').disabled = false ;
    }
  }
  else
  {
    $('addTickButton').disabled = true ;
    $('updateTickButton').disabled = true ;
    $('removeTickButton').disabled = (selectedTickId) ? false : true ;
  }
}

function toggleGridInputs(enabled)
{
  if(!CircosUI.gridStartSpinner || !CircosUI.gridEndSpinner)
  {
    return ;
  }

  if(enabled)
  {
    CircosUI.gridStartSpinner.enable() ;
    CircosUI.gridEndSpinner.enable() ;
  }
  else
  {
    CircosUI.gridStartSpinner.disable() ;
    CircosUI.gridEndSpinner.disable() ;
  }

}
/** END Tick Actions **/

/** START Annotation Track Methods **/
function addTrack(trackName)
{
  if(trackName === '')
  {
    return false ;
  }

  // The track ID needs to follow track_X format for Scriptaculous Sortables to work
  var trackObj = new Track('track_' + nextTrackIndex, trackName) ;
  if(!setTrackOptions(trackObj))
  {
    return false ;
  }
  CircosUI.tracks.trackObjs['track_' + nextTrackIndex] = trackObj ;
  CircosUI.tracks.count += 1 ;
  nextTrackIndex += 1 ;

  // Track options are set and added to data struct, now add visuals
  var trackLi = $(document.createElement('li')) ;
  trackLi.id = trackObj.id ;
  trackLi.addClassName('movable') ;
  trackLi.style.display = 'none' ;
  if(trackLi.attachEvent)
  {
    trackLi.attachEvent('onclick', function() { selectAndShowTrackDetails(trackLi.id) ; }) ;
  }
  else
  {
    trackLi.onclick = function() { selectAndShowTrackDetails(trackLi.id) ; }
  }

  var trackHtml = '<div style="overflow: auto ;">' ;
  trackHtml += '  <span id="' + trackObj.id + '_zindex" style="float: left ;">Layer </span>' ;
  trackHtml += '  <span id="' + trackObj.id + '_display" style="float: right ;">' + trackName + '</span>' ;
  trackHtml += '</div> ' ;
  $(trackLi).update(trackHtml + '<script>setZIndicesForTracks() ;</script>') ;

  // Show our newly added track
  $('addedTracks').appendChild(trackLi) ;
  Effect.Appear(trackLi, { queue: 'end', duration: 0.5 }) ;

  // Always need to make the Sortable reflect the contents of our list
  Sortable.create('addedTracks', { onUpdate : function() { setZIndicesForTracks() ; } }) ;

  // Reset our inputs and state so nothing is selected
  resetTrackOptionInputs() ;
  resetTrackTab() ;

  return true ;
}

function updateTrack(trackId)
{
  if(trackId === '' || !CircosUI.tracks.trackObjs[trackId] || !setTrackOptions(CircosUI.tracks.trackObjs[trackId]))
  {
    return false ;
  }
  
  new Effect.Highlight(trackId, { queue: 'end', startcolor: '#EAE6FF', duration: 1.5 }) ;

  // Reset our inputs and state so nothing is selected
  resetTrackOptionInputs() ;
  resetTrackTab() ;

  return true ;
}

function removeTrack(trackId)
{
  if(trackId === '' || !CircosUI.tracks.trackObjs[trackId])
  {
    return false ;
  }

  // Remove from our data struct
  delete(CircosUI.tracks.trackObjs[trackId]) ;
  CircosUI.tracks.count-- ;

  // Hide and remove from DOM
  Effect.Fade(trackId, { queue: 'end', duration: 0.5, afterFinish : function() { $('addedTracks').removeChild($(trackId)) ; setZIndicesForTracks() ;} }) ;
  
  // Always need to make the Sortable reflect the contents of our list
  Sortable.create('addedTracks', {onUpdate : function() { setZIndicesForTracks() ; }}) ;

  // Reset our inputs and state so nothing is selected
  resetTrackOptionInputs() ;
  resetTrackTab() ;
  
  return true ;
}

function addRuleEl(firstRule)
{
  var ruleId = 'rule_' + nextRuleIndex ;
  var addRuleLink = undefined ;
  var rulesUl = undefined ;
  var ruleLi = undefined ;

  if(!(rulesUl = $('rules')))
  {
    return false ;
  }

  // Create our rule el
  ruleLi = createRuleEl(ruleId, $F('type')) ;
  rulesUl.appendChild(ruleLi) ;

  var prevRule = ruleLi.previous() ;
  var prevAdd = undefined ;
  if(prevRule && (prevAdd = $(prevRule.id + 'Add')))
  {
    prevAdd.hide() ;
    prevRule.style.paddingLeft = '22px' ;
  }
  
  if(firstRule && (addRuleLink = $('addRuleLink')))
  {
    Effect.Fade(addRuleLink, { queue: 'end', duration: 0.5, afterFinish : function() { Effect.Appear(ruleId, { queue: 'end', duration: 0.5 }) ; } }) ;
    addRuleLink.hide() ;
  }
  else
  {
    Effect.Appear(ruleId, { queue: 'end', duration: 0.5 }) ;
  }
  nextRuleIndex += 1 ;

  return true ;
}

function removeRuleEl(ruleId)
{
  // if no rules left, add rule link
  // else make remove button appear
  var ruleEl = undefined ;
  var prevRules = undefined ;
  var nextRules = undefined ;

  // Get rule element
  if(!(ruleEl = $(ruleId)))
  {
    return false ;
  }
  prevRules = ruleEl.previousSiblings() ;
  nextRules = ruleEl.nextSiblings() ;

  // Hide and remove from UI
  Effect.Fade(ruleEl, { queue: 'end', duration: 0.5, afterFinish : function() 
    { 
      ruleEl.remove() ;
      if(prevRules.length === 0 && nextRules.length === 0)
      {
        // If we were the only rule, we need to add our AddRuleLink back
        $('addRuleLink').show() ;
      }
      else if(nextRules.length === 0)
      {
        // If we were the last rule in the list, make the + symbol in our 
        // first sibling visible again so new rules can be added
        var prevRuleAddBtn = $(prevRules[0].id + 'Add') ;
        if(prevRuleAddBtn)
        {
          prevRules[0].style.paddingLeft = '3px' ;
          prevRuleAddBtn.show() ;
        }
      }
    }
  }) ;

  return true ;
}

function createRuleEl(ruleId, trackType, opts)
{
  // Create our rule el
  var ruleLiContent = new Array() ;
  var ruleLi = $(document.createElement('li')) ;
  
  ruleLi.id = ruleId ;
  ruleLi.style.display = 'none' ;
  ruleLi.style.overflow = 'auto' ;
  ruleLiContent.push('<div style="float: left ;">') ;
  ruleLiContent.push('<a href="#" id="' + ruleId + 'Add" onclick="addRuleEl(false) ; return false ;" class="smallBttn"><span>+</span></a>') ;
  ruleLiContent.push('<a href="#" id="' + ruleId + 'Remove" onclick="removeRuleEl(\'' + ruleId + '\') ; return false ;" class="smallBttn"><span>-</span></a>') ;
  ruleLiContent.push('<span style="margin: 0 3px 0 5px ;">If score is</span>') ;
  
  // Setup our conditions
  ruleLiContent.push('<select id="' + ruleId + 'Condition" style="margin-right: 3px ;">') ;
  ruleSpecs.conditions.each(function(condition)
  {
    var optionEl = ['  <option value="' + condition.value + '"'] ;
    optionEl.push((opts && opts.condition === condition.value) ? ' selected="selected">' : '>') ;
    optionEl.push(condition.desc + '</option>') ;
    ruleLiContent.push(optionEl.join('')) ;
  }) ;
  ruleLiContent.push('</select>') ;

  ruleLiContent.push('<input type="text" id="' + ruleId + 'Value" style="width: 3em ;"' + ((opts && opts.value) ? ' value="' + opts.value + '"' : '') + '>') ;
  ruleLiContent.push('<span>, change </span>') ;

  // Setup our available options
  var selectedOpt = '' ;
  ruleLiContent.push('<select id="' + ruleId + 'Opt" onchange="updateRuleOptVal(\'' + ruleId +'\') ;">') ;
  for(var opt in ruleSpecs.typeOpts[trackType])
  {
    if((opts && opts.opt === opt) || selectedOpt === '')
    {
      selectedOpt = opt ;
    }

    var optionEl = ['  <option value="' + opt + '"' + ((opts && opts.opt === opt) ? ' selected="selected">' : '>')] ;
    optionEl.push(opt.underscore().replace(/_/g, ' ') + '</option>') ;
    ruleLiContent.push(optionEl.join('')) ;
  }
  ruleLiContent.push('</select>') ;
  
  ruleLiContent.push('<span> to </span></div>') ;
  ruleLiContent.push('<div style="float: left ; margin-left: 5px ;">') ;
  ruleLiContent.push(generateRuleOptsHtml(ruleId, ruleSpecs.typeOpts[trackType][selectedOpt], (opts != undefined) ? opts.optVal : '')) ;
  ruleLiContent.push('</div>') ;
  
  // Finally update our content
  ruleLi.update(ruleLiContent.join('')) ;

  return ruleLi ;
}

function updateRuleOptVal(ruleId)
{
  var valEl = undefined ;
  var parentEl = undefined ;
  var newValHtml = '' ;

  if(!(valEl = $(ruleId + 'OptVal')) || !(parentEl = valEl.up()))
  {
    return false ;
  }

  // When the option to manipulate is changed, we need to update our possible values
  parentEl.remove() ;
  parentEl = $(document.createElement('div')) ;
  parentEl.style.marginLeft = '5px' ;
  parentEl.style.cssFloat = 'left' ;
  parentEl.update(generateRuleOptsHtml(ruleId, ruleSpecs.typeOpts[$F('type')][$F(ruleId + 'Opt')])) ;
  $(ruleId).appendChild(parentEl) ;
}

function generateRuleOptsHtml(ruleId, prop, propVal)
{
  var optHtml = [] ;
  propVal = (propVal === undefined) ? '' : propVal ;

  // Setup our opt values
  switch(prop.type)
  {
    case 'text' :
      optHtml.push('<input type="text" id="' + ruleId + 'OptVal" style="width: 3em ;" value="' + propVal + '">') ;
      break ;
    case 'select' :
      optHtml.push('<select id="' + ruleId +'OptVal">') ;
      prop.opts.each(function(val)
      {
        var selected = (propVal === val) ? ' selected="selected"' : '' ;
        optHtml.push('<option value="' + val + '"' + selected + '>' + val + '</option>') ;
      }) ;
      optHtml.push('</select>') ;
      break ;
    case 'color' :
      var color = (propVal.indexOf('#') != -1) ? propVal : '#000000' ;
      optHtml.push('  <input id="' + ruleId + 'OptVal" type="hidden" value="' + color + '">') ;
      optHtml.push('  <a href="#" onclick="setDivId(\'' + ruleId + 'OptColor\', \'' + ruleId + 'OptVal\', \'' + color + '\') ; return false ;">') ;
      optHtml.push('    <span id="' + ruleId + 'OptColor" class="swatch" style="background-color: ' + color + ' ;"></span>') ;
      optHtml.push('  </a>') ;
      break ;
  }

  return optHtml.join('') ;
}

function setTrackOptions(trackObj)
{
  if(!trackObj)
  {
    return false ;
  }

  $(tabs.annotTab.feedbackDivId).update('') ;
  var optsErrors = validateOptionsForTab('annotation') ;
  if(optsErrors.length > 0)
  {
    reportErrors(optsErrors, $(tabs.annotTab.feedbackDivId)) ;
    return false ;
  }

  // Now set our options based on the type of track -- Collect all input/select objects and 
  // place the value into track object based on id. This assumes the id of the input el. corresponds 
  // to a circos option (e.g. id="stroke_thickness"). NOTE: PrototypeJS#getElementsBySelector deprecrated in 1.6
  // Always clear out our options first
  trackObj.options = {} ;
  trackObj.options.type = $F('type') ;
  if(trackObj.options.type === 'heatmap')
  {
    trackObj.options.color = {} ;
  }

  $('annotation').getElementsBySelector('#annoStdOpts input', '#annoAdvOpts input').each(function(el)
  {
    if((el.type === 'text' || el.type === 'hidden') && $F(el) != '')
    {
      if(/(color\d+)Input/.test(el.id))
      {
        // We want any heatmap colors in the colors object
        trackObj.options.color[RegExp.$1] = $F(el) ;
      }
      else
      {
        trackObj.options[el.id] = $F(el) ;
      }
    }
    else if(el.type === 'checkbox')
    {
      trackObj.options[el.id] = (el.checked) ? 'yes' : 'no' ;
    }
  }) ;

  $('annotation').getElementsBySelector('#annoStdOpts select', '#annoAdvOpts select').each(function(el)
  {
    trackObj.options[el.id] = $F(el) ;
  }) ;

  // Next add the rules -- We add rules based on what UI objects exist, this is so 
  // that we don't commit any rule changes until a user hits "Add" or "Update" track
  var rulesUl = undefined ;
  if(rulesUl = $('rules'))
  {
    // We are always started from scratch
    trackObj.rules = new Array() ;
    var ignored = 0 ;

    // NOTE: Prototype#getElementsBySelector deprecated in v1.6.0
    var rules = rulesUl.getElementsBySelector('li') ;
    rules.each(function(ruleEl)
    {
      // For a rule to be added, we need a valid value set in the condition text input
      var ruleValue = undefined ;
      if(!(ruleValue = $(ruleEl.id + 'Value')) || !ruleValue.value)
      {
        ignored += 1 ;
        return ;
      }

      var rule = {} ;
      rule.id = ruleEl.id ;
      rule.condition = $F(ruleEl.id + 'Condition') ;
      rule.value = ruleValue.value ;
      rule.opt = $F(ruleEl.id + 'Opt') ;
      rule.optVal = $F(ruleEl.id + 'OptVal') ;
      trackObj.rules.push(rule) ;
    }) ;

    if(ignored > 0)
    {
      var ignoredRules = '<div class="warning">' + ignored + ' rule' + ((ignored === 1) ? ' was' : 's were') +
        ' not added because a valid condition value was not set!' ;
      
      $(tabs.annotTab.feedbackDivId).update(ignoredRules) ;
    }
    else
    {
      $(tabs.annotTab.feedbackDivId).update('') ;
    }
  }

  return true ;
}

function setZIndicesForTracks()
{
  var tracksList = $('addedTracks') ;
  
  if(!tracksList)
  {
    return false ;
  }

  // Z-Index is dictacted by the order in the DOM
  for(var i = 0 ; i < tracksList.childNodes.length ; i++)
  {
    var trackId = tracksList.childNodes.item(i).id ;
    var trackObj = CircosUI.tracks.trackObjs[trackId] ;

    if(!$(trackId + '_zindex') || !trackObj)
    {
      continue ;
    }

    trackObj.options.z = (i + 1) ;
    $(trackId + '_zindex').update('Layer ' + (i + 1)) ;
  }

  return true ;
}

function setTrackButtonsStatus(radialIds)
{
  var validPos = true ;
  var selectedTrack = $F('tracksSelect') ;
  var buttonsDisabled = [true, true, true] ; // [add, update, remove]
  var rIds = (radialIds instanceof Array) ? radialIds : [radialIds] ;

  rIds.each(function(id) {
    var el = undefined ;
    if(!(el = $(id)))
    {
      return ;
    }

    if(!el.value)
    {
      validPos = false ;
    }
  }) ;

  if(validPos)
  {
    if(selectedTrackId)
    {
      // Inputs valid, with an already created track selected (update/remove mode)
      buttonsDisabled[1] = false ;
    }
    else if(selectedTrack)
    {
      // Inputs valid, no track selected, going to add a track
      buttonsDisabled[0] = false ;
    }
  }

  $('addTrackButton').disabled = buttonsDisabled[0] ;
  $('updateTrackButton').disabled = buttonsDisabled[1] ;

  // Remove track button should always be enabled if we have a track selected
  $('removeTrackButton').disabled = (selectedTrackId) ? false : true ;
}

function setSelectedTrack(trackId)
{
  if(!selectElement(trackId, selectedTrackId))
  {
    return false ;
  }
  selectedTrackId = trackId ;

  $$('#' + tabs.annotTab.divId + ' .error').each(function(input)
  {
    $(input).removeClassName('error') ;
  }) ;

  // If a track was selected, update button state
  if(trackId != '')
  {
    $('addTrackButton').disabled = true ;
    $('updateTrackButton').disabled = false ;
    $('removeTrackButton').disabled = false ;
    $('tracksSelect').selectedIndex = 0 ;    
  
    // Our sel. track has been changed/cleared, clear out errors from previous track
    $(tabs.annotTab.feedbackDivId).update('') ;
  }

  return true ;
}

function selectAndShowTrackDetails(trackId)
{
  var tracks = CircosUI.tracks ;

  if(!tracks.trackObjs[trackId] || !setSelectedTrack(trackId))
  {
    return false ;
  }

  // Show our option widgets for this track type
  showTypeOptions(tracks.trackObjs[trackId].options.type, tracks.trackObjs[trackId]) ;
  
  for(var opt in tracks.trackObjs[trackId].options)
  {
    if(tracks.trackObjs[trackId].options.type === 'heatmap' && opt === 'color')
    {
      // We handle heatmap colors special because we need to add widgets to the UI,
      // so add our widgets, setting the color appropriately then continue
      for(var colorId in tracks.trackObjs[trackId].options.color)
      {
        addHeatmapColor(tracks.trackObjs[trackId].options.color[colorId], colorId) ;
      }
      continue ;
    }

    var optEl = $(opt) ;
    if(!optEl)
    {
      continue ;
    }

    // The input elements must have IDs that are the option names (eg, option = fillColor, el must have id = fillColor)
    if(optEl.type === 'text' || optEl.type === 'hidden')
    {
      optEl.value = tracks.trackObjs[trackId].options[opt] ;

      var swatch = undefined ;
      if(/color/i.test(opt) && (swatch = $(opt + 'Swatch')))
      {
        swatch.style.backgroundColor = tracks.trackObjs[trackId].options[opt] ;
      }
    }
    else if(optEl.type === 'checkbox')
    {
      optEl.checked = (tracks.trackObjs[trackId].options[opt] === 'yes') ? true : false ;
    }
    else if(optEl.type === 'select-one')
    {
      setSelectElValue(opt, opt + 'Other', tracks.trackObjs[trackId].options[opt]) ;
    }
  }

  // Now show our rules
  var rules = $('rules') ;
  if(rules)
  {
    rules.update('') ;
    if(tracks.trackObjs[trackId].rules.length === 0)
    {
      $('addRuleLink').show() ;
    }
    else
    {
      $('addRuleLink').hide() ;
      tracks.trackObjs[trackId].rules.each(function(rule, index)
      {
        var ruleEl = createRuleEl(rule.id, tracks.trackObjs[trackId].options.type, rule) ;
        
        // We will need to hide the '+' button if we are not the last rule in the display
        if(index != tracks.trackObjs[trackId].rules.length - 1)
        {
          // li --> [0]containing div -- > [1]'+' button --> [2]'-' button, etc
          ruleEl.down(1).hide() ;
          ruleEl.style.paddingLeft = '22px' ;
        }

        // By default our ruleEl is hidden, so show it
        ruleEl.style.display = 'block' ;
        rules.appendChild(ruleEl) ;
      }) ;
    }
  }

  return true ;
}

function processTrackChange()
{
  // If a track is selected, deselect it and clear options
  // If a track is not selected, keep the options set so a user doesn't waste effort
  if(selectedTrackId != '')
  {
    resetTrackOptionInputs() ;
    setSelectedTrack('') ;
  }

  var ids = ($F('type') === 'link') ? ['radius'] : ['r0', 'r1'] ;
  setTrackButtonsStatus(ids) ;
}

function toggleRadiusInputs(disabled)
{
  if(!CircosUI.rZeroSpinner || !CircosUI.rOneSpinner)
  {
    return ;
  }

  if(disabled)
  {
    CircosUI.rZeroSpinner.disable() ;
    CircosUI.rOneSpinner.disable() ;
  }
  else
  {
    CircosUI.rZeroSpinner.enable() ;
    CircosUI.rOneSpinner.enable() ;
  }
}

function resetTrackOptionInputs()
{
  $('type').selectedIndex = 0 ;
//  $('r0').value = '' ;
//  $('r1').value = '' ;
  $('rules').update('') ;
  $('addRuleLink').show() ;
  showTypeOptions('highlight') ;
}

function resetTrackTab()
{
  $('tracksSelect').selectedIndex = 0 ;
  setSelectedTrack('') ;
  
  $('addTrackButton').disabled = true ;
  $('updateTrackButton').disabled = true ;
  $('removeTrackButton').disabled = true ;
}

function showTypeOptions(type, selectedTrack)
{
  /** Now that we are using ExtJS more exclusively, this could probably be cleaned up using Ext.DomHelper **/
  var std = new Array() ;
  var adv = new Array() ;
  var stdDiv = $('annoStdOpts') ;
  var advDiv = $('annoAdvOpts') ;
  var valIntCB = 'onkeypress="return validateInt(event) ;"' ;
  var valFloatCB = 'onkeypress="return validateFloat(event, this) ;"' ;
  var checkFloatCB = 'onblur="checkPosFloat(this) ;"' ;
  var radiusCheck = 'onkeyup="setTrackButtonsStatus([\'r0\', \'r1\']) ;"' ;

  /** Defaults **/
  var radiusZero = (selectedTrack && selectedTrack.options.r0) ? selectedTrack.options.r0 : '0.25' ;
  var radiusOne = (selectedTrack && selectedTrack.options.r1) ? selectedTrack.options.r1 : '0.75' ;
  var radius = (selectedTrack && selectedTrack.options.radius) ? selectedTrack.options.radius : '0.95' ;
  var linked = (selectedTrack && selectedTrack.options.linkedBy) ? selectedTrack.options.linkedBy : '' ;

  if(!stdDiv || !advDiv)
  {
    return false ;
  }
  
  switch(type)
  {
    case 'highlight' :
      std.push(generateOptString('text', 'r0', 'Inner radius*:', [valFloatCB, checkFloatCB, radiusCheck])) ;
      std.push(generateOptString('text', 'r1', 'Outer radius*:', [valFloatCB, checkFloatCB, radiusCheck])) ;
      std.push(generateOptString('checkbox', 'ideogram', 'Draw the highlight on the ideogram:', ['onclick="toggleRadiusInputs(this.checked) ;"'])) ;
      std.push(generateOptString('color', 'fillColor', 'Highlight fill color:')) ;
      std.push('<script>CircosUI.rZeroSpinner = createTrackSpinner(\'r0\', \'' + radiusZero + '\') ;') ;
      std.push(' CircosUI.rOneSpinner = createTrackSpinner(\'r1\', \'' + radiusOne + '\') ;</script>') ;
      adv.push(generateOptString('color', 'strokeColor', 'Highlight stroke color:')) ;
      break ;
    case 'scatter' :
      var glyphs = [{'text' : 'Circle', 'value' : 'circle', 'selected' : true}] ;
      glyphs.push({'text' : 'Rectangle', 'value' : 'rectangle', 'selected' : false}) ;
      glyphs.push({'text' : 'Triangle', 'value' : 'triangle', 'selected' : false}) ;
      var glyphSizes = [{'text' : '2 pixels', 'value' : 2, 'selected' : false}] ;
      glyphSizes.push({'text' : '4 pixels', 'value' : 4, 'selected' : false}) ;
      glyphSizes.push({'text' : '8 pixels', 'value' : 8, 'selected' : true}) ;
      glyphSizes.push({'text' : '16 pixels', 'value' : 16, 'selected': false}) ;
      glyphSizes.push({'text' : 'Other:', 'value' : 'other', 'selected' : false}) ;
      var axisLines = [{'text' : '2 lines', 'value' : 2, 'selected' : false}] ;
      axisLines.push({'text' : '4 lines', 'value' : 4, 'selected' : true}) ;
      axisLines.push({'text' : '6 lines', 'value' : 6, 'selected' : false}) ;
      axisLines.push({'text' : '8 lines', 'value' : 8, 'selected' : false}) ;
      axisLines.push({'text' : 'Other:', 'value' : 'other', 'selected' : false}) ;
      std.push(generateOptString('select', 'glyph', 'Glyph:', glyphs)) ;
      std.push(generateOptString('text', 'r0', 'Inner radius*:', [valFloatCB, checkFloatCB, radiusCheck])) ;
      std.push(generateOptString('text', 'r1', 'Outer radius*:', [valFloatCB, checkFloatCB, radiusCheck])) ;
      std.push('<script>CircosUI.rZeroSpinner = createTrackSpinner(\'r0\', \'' + radiusZero + '\') ;') ;
      std.push(' CircosUI.rOneSpinner = createTrackSpinner(\'r1\', \'' + radiusOne + '\') ;</script>') ;
      adv.push(generateOptString('select-other', 'glyphSize', 'Glyph size:', glyphSizes)) ;
      adv.push(generateOptString('color', 'fillColor', 'Glyph color:')) ;
      adv.push(generateOptString('color', 'strokeColor', 'Glyph stroke color:')) ;
      adv.push(generateOptString('checkbox', 'axis', 'Draw plot axis:')) ;
      adv.push(generateOptString('select-other', 'axisLines', 'Number of axis lines:', axisLines)) ;
      break ;
    case 'line' :
      var lineSizes = [{'text' : '1 pixel', 'value' : 1, 'selected' : false}] ;
      lineSizes.push({'text' : '2 pixels', 'value' : 2, 'selected' : true}) ;
      lineSizes.push({'text' : '4 pixels', 'value' : 4, 'selected' : false}) ;
      lineSizes.push({'text' : '8 pixels', 'value' : 8, 'selected': false}) ;
      lineSizes.push({'text' : 'Other:', 'value' : 'other', 'selected' : false}) ;
      var axisLines = [{'text' : '2 lines', 'value' : 2, 'selected' : false}] ;
      axisLines.push({'text' : '4 lines', 'value' : 4, 'selected' : true}) ;
      axisLines.push({'text' : '6 lines', 'value' : 6, 'selected' : false}) ;
      axisLines.push({'text' : '8 lines', 'value' : 8, 'selected' : false}) ;
      axisLines.push({'text' : 'Other:', 'value' : 'other', 'selected' : false}) ;
      std.push(generateOptString('text', 'r0', 'Inner radius*:', [valFloatCB, checkFloatCB, radiusCheck])) ;
      std.push(generateOptString('text', 'r1', 'Outer radius*:', [valFloatCB, checkFloatCB, radiusCheck])) ;
      std.push(generateOptString('color', 'color', 'Line color:')) ;
      std.push('<script>CircosUI.rZeroSpinner = createTrackSpinner(\'r0\', \'' + radiusZero + '\') ;') ;
      std.push(' CircosUI.rOneSpinner = createTrackSpinner(\'r1\', \'' + radiusOne + '\') ;</script>') ;
      adv.push(generateOptString('select-other', 'thickness', 'Line thickness:', lineSizes)) ;
      adv.push(generateOptString('checkbox', 'axis', 'Draw plot axis:')) ;
      adv.push(generateOptString('select-other', 'axisLines', 'Number of axis lines:', axisLines)) ;
      break ;
    case 'histogram' :
      var orientations = [{'text' : 'Out', 'value' : 'out', 'selected' : true}, {'text' : 'In', 'value' : 'in', 'selected' : false}] ;
      var axisLines = [{'text' : '2 lines', 'value' : 2, 'selected' : false}] ;
      axisLines.push({'text' : '4 lines', 'value' : 4, 'selected' : true}) ;
      axisLines.push({'text' : '6 lines', 'value' : 6, 'selected' : false}) ;
      axisLines.push({'text' : '8 lines', 'value' : 8, 'selected' : false}) ;
      axisLines.push({'text' : 'Other:', 'value' : 'other', 'selected' : false}) ;
      std.push(generateOptString('text', 'r0', 'Inner radius*:', [valFloatCB, checkFloatCB, radiusCheck])) ;
      std.push(generateOptString('text', 'r1', 'Outer radius*:', [valFloatCB, checkFloatCB, radiusCheck])) ;
      std.push(generateOptString('color', 'color', 'Histogram line color:')) ;
      std.push('<script>CircosUI.rZeroSpinner = createTrackSpinner(\'r0\', \'' + radiusZero + '\') ;') ;
      std.push(' CircosUI.rOneSpinner = createTrackSpinner(\'r1\', \'' + radiusOne + '\') ;</script>') ;
      adv.push(generateOptString('checkbox', 'fillUnder', 'Fill histogram area:')) ;
      adv.push(generateOptString('color', 'fillColor', 'Histogram area fill color:')) ;
      adv.push(generateOptString('select', 'orientation', 'Histogram orientation:', orientations)) ;
      adv.push(generateOptString('checkbox', 'axis', 'Draw plot axis:')) ;
      adv.push(generateOptString('select-other', 'axisLines', 'Number of axis lines:', axisLines)) ;
      break ;
    case 'tile' :
      var orientations = [{'text' : 'Out', 'value' : 'out', 'selected' : true}] ;
      orientations.push({'text' : 'In', 'value' : 'in', 'selected' : false}) ;
      orientations.push({'text' : 'Center', 'value' : 'center', 'selected' : false}) ;
      var thickness = [{'text' : '5 pixels', 'value' : 5, 'selected' : true}] ;
      thickness.push({'text' : ' 10 pixels', 'value' : 10, 'selected' : false}) ;
      thickness.push({'text' : '15 pixels', 'value' : 15, 'selected' : false}) ;
      thickness.push({'text' : '20 pixels', 'value' : 20, 'selected' : false}) ;
      thickness.push({'text' : 'Other:', 'value' : 'other', 'selected' : false}) ;
      var overflow = [{'text' : 'Hide', 'value' : 'hide', 'selected' : false}] ;
      overflow.push({'text' : 'Collapse', 'value' : 'collapse', 'selected' : true}) ;
      var layers = [{'text' : '5 layers', 'value' : 5, 'selected' : false}] ;
      layers.push({'text' : '10 layers', 'value' : 10, 'selected' : true}) ;
      layers.push({'text' : '15 layers', 'value' : 15, 'selected' : false}) ;
      layers.push({'text' : '20 layers', 'value' : 20, 'selected' : false}) ;
      layers.push({'text' : 'Other:', 'value' : 'other', 'selected' : false}) ;
      var axisLines = [{'text' : '2 lines', 'value' : 2, 'selected' : false}] ;
      axisLines.push({'text' : '4 lines', 'value' : 4, 'selected' : true}) ;
      axisLines.push({'text' : '6 lines', 'value' : 6, 'selected' : false}) ;
      axisLines.push({'text' : '8 lines', 'value' : 8, 'selected' : false}) ;
      axisLines.push({'text' : 'Other:', 'value' : 'other', 'selected' : false}) ;
      std.push(generateOptString('text', 'r0', 'Inner radius*:', [valFloatCB, checkFloatCB, radiusCheck])) ;
      std.push(generateOptString('text', 'r1', 'Outer radius*:', [valFloatCB, checkFloatCB, radiusCheck])) ;
      std.push(generateOptString('color', 'color', 'Tile color:')) ;
      std.push(generateOptString('select', 'orientation', 'Tile orientation:', orientations)) ; 
      std.push(generateOptString('select-other', 'layers', 'Number of tile layers to draw:', layers)) ;
      std.push('<script>CircosUI.rZeroSpinner = createTrackSpinner(\'r0\', \'' + radiusZero + '\') ;') ;
      std.push(' CircosUI.rOneSpinner = createTrackSpinner(\'r1\', \'' + radiusOne + '\') ;</script>') ;
      adv.push(generateOptString('color', 'strokeColor', 'Stroke color:')) ;
      adv.push(generateOptString('select-other', 'thickness', 'Tile thickness:', thickness)) ;
      adv.push(generateOptString('select', 'layersOverflow', 'Display for overflow tiles:', overflow)) ;
      adv.push(generateOptString('color', 'layersOverflowColor', 'Overflow tiles color:')) ;
      adv.push(generateOptString('checkbox', 'axis', 'Draw plot axis:')) ;
      adv.push(generateOptString('select-other', 'axisLines', 'Number of axis lines:', axisLines)) ;
      break ;
    case 'heatmap' :
      var axisLines = [{'text' : '2 lines', 'value' : 2, 'selected' : false}] ;
      axisLines.push({'text' : '4 lines', 'value' : 4, 'selected' : true}) ;
      axisLines.push({'text' : '6 lines', 'value' : 6, 'selected' : false}) ;
      axisLines.push({'text' : '8 lines', 'value' : 8, 'selected' : false}) ;
      axisLines.push({'text' : 'Other:', 'value' : 'other', 'selected' : false}) ;
      std.push(generateOptString('text', 'r0', 'Inner radius*:', [valFloatCB, checkFloatCB, radiusCheck])) ;
      std.push(generateOptString('text', 'r1', 'Outer radius*:', [valFloatCB, checkFloatCB, radiusCheck])) ;
      std.push('<script>CircosUI.rZeroSpinner = createTrackSpinner(\'r0\', \'' + radiusZero + '\') ;') ;
      std.push(' CircosUI.rOneSpinner = createTrackSpinner(\'r1\', \'' + radiusOne + '\') ;</script>') ;

      // Create our heatmap special UI - fieldset with a list of colors. 
      // We will always require at least one color to be set.
      std.push('<fieldset><legend>Heatmap Colors</legend><ul id="heatmapColors"></ul></fieldset>') ;
      if(!selectedTrack)
      {
        std.push('<script>addHeatmapColor(\'#000000\') ;</script>') ;
      }
      adv.push(generateOptString('checkbox', 'axis', 'Draw plot axis:')) ;
      adv.push(generateOptString('select-other', 'axisLines', 'Number of axis lines:', axisLines)) ;
      break ;
    case 'link' :
      var bezierStyles = [{'text' : 'Straight line', 'value' : 0, 'selected' : false}] ;
      bezierStyles.push({'text' : '0.25r', 'value' : 0.25, 'selected' : false}) ;
      bezierStyles.push({'text' : '0.50r', 'value' : 0.5, 'selected' : true}) ;
      bezierStyles.push({'text' : '0.75r', 'value' : 0.75, 'selected' : false}) ;
      bezierStyles.push({'text' : 'Other:', 'value' : 'other', 'selected' : false}) ;
      var limits = [{'text' : 'Draw all links', 'value' : '', 'selected' : true}] ;
      limits.push({'text' : '100 links', 'value' : 100, 'selected' : false}) ;
      limits.push({'text' : '500 links', 'value' : 500, 'selected' : false}) ;
      limits.push({'text' : '1000 links', 'value' : 1000, 'selected' : false}) ;
      limits.push({'text' : 'Other:', 'value' : 'other', 'selected' : false}) ;
      var axisLines = [{'text' : '2 lines', 'value' : 2, 'selected' : false}] ;
      axisLines.push({'text' : '4 lines', 'value' : 4, 'selected' : true}) ;
      axisLines.push({'text' : '6 lines', 'value' : 6, 'selected' : false}) ;
      axisLines.push({'text' : '8 lines', 'value' : 8, 'selected' : false}) ;
      axisLines.push({'text' : 'Other:', 'value' : 'other', 'selected' : false}) ;
      std.push(generateOptString('select', 'linkedTo', 'Link this track to:', CircosUI.allTracks)) ;
      std.push(generateOptString('select', 'linkedBy', 'Link tracks when values are equal in:', [])) ;
      std.push(generateOptString('text', 'radius', 'Start & end radius*:', [valFloatCB, checkFloatCB, 'onkeyup="setTrackButtonsStatus(\'radius\') ;"'])) ;
      std.push(generateOptString('select-other', 'recordLimit', 'Maximum number of links to draw:', limits)) ;
      std.push(generateOptString('color', 'color', 'Link color:')) ;
      std.push('<script>updateLinkField($F(\'linkedTo\'), \'' + linked + '\') ;') ;
      std.push('$(\'linkedTo\').observe(\'change\', function() { updateLinkField($F(\'linkedTo\'), \'\') ; }) ;') ;
      std.push('createTrackSpinner(\'radius\', \'' + radius + '\') ;</script>') ;
      adv.push(generateOptString('checkbox', 'ribbon', 'Draw links as ribbons:')) ;
      adv.push(generateOptString('select-other', 'bezierRadius', 'Bezier radius for links:', bezierStyles)) ;
      break ;
  }

  // We need to always show
  stdDiv.update(std.join('')) ;
  advDiv.update(adv.join('')) ;

  // If the track type switched, we need to update any rules
  var rules = undefined ;
  if(rules = $('rules'))
  {
    if(type === 'highlight')
    {
      $('annoAdvRules').hide() ;
    }
    else
    {
      $('annoAdvRules').show() ;
      for(var i = 0 ; i < rules.childNodes.length ; i++)
      {
        var ruleId = rules.childNodes.item(i).id ;
        var ruleOptSelEl = undefined ;
        
        if(!(ruleOptSelEl = $(ruleId + 'Opt')))
        {
          continue ;
        }

        // We have our rule opt select, clear out the options and add them based on selected track type
        ruleOptSelEl.options.length = 0 ;
        for(var opt in ruleSpecs.typeOpts[type])
        {
          var optEl = document.createElement('option') ;
          optEl.value = opt ;
          optEl.appendChild(document.createTextNode(opt.underscore().replace(/_/g, ' '))) ;
          ruleOptSelEl.appendChild(optEl) ;
        }

        // Now that the select is populated with our options, change the widget for the option value
        updateRuleOptVal(ruleId) ;
      }
    }
  }

  return true ;
}

function generateOptString(type, id, labelText, opts)
{
  var optStrings = new Array() ;
  
  if(!type || !id || !labelText || type === '' || id === '' || labelText === '')
  {
    return '' ;
  }

  optStrings.push('<div class="option"><label for="' + id + '">' + labelText + ' </label>') ;
  switch(type)
  {
    case 'text' :
      var callbacks = '' ;
      if(opts instanceof Array)
      {
        opts.each(function(cb) 
        {
          if(typeof(cb) === 'string')
          {
            callbacks += ' ' + cb ;
          }
        }) ;
      }

      optStrings.push('<div class="optionInput"><span><input id="' + id + '" type="text" size="6" ' + callbacks + '></span></div>') ;
      break ;
    case 'color' :
      optStrings.push('<div class="optionInput colorInput"><div id="' + id + 'Swatch" class="swatch" style="background-color: #000 ;"></div>') ;
      optStrings.push('<input type="hidden" id="' + id + '" value="#000000"><div style="float: left ; width: 50% ;">') ;
      optStrings.push('<a class="colorLink" href="#" onclick="setDivId(\'' + id + 'Swatch\', \'' + id + '\', \'#000000\') ; return false ;">Change Color</a>') ;
      optStrings.push('</div></div>') ;
      break ;
    case 'checkbox' :
      var callbacks = '' ;
      var check = (typeof(opts) === 'boolean' && opts) ? ' checked="checked" ' : '' ;
      
      if(opts instanceof Array)
      {
        opts.each(function(cb)
        {
          if(typeof(cb) === 'string')
          {
            callbacks += ' ' + cb ;
          }
        }) ;
      }

      optStrings.push('<div class="optionInput"><input id="' + id + '" type="checkbox"' + check + 'style="margin: 0 ;" ' + callbacks +'></div>') ;
      break ;
    case 'select' :
    case 'select-other' :
      if(opts instanceof Array)
      {
        var onChange = (type === 'select-other') ? ' onchange="setOtherOptVis(\'' + id  + '\', \'' + id  + 'Other\') ;"' : '' ;
        optStrings.push('<div class="optionInput"><select id="' + id + '"' + onChange + '>') ;
        opts.each(function(opt)
        {
          if(!opt.text || opt.text === '')
          {
            return ;
          }
          
          optStrings.push('<option value="' + opt.value + '"' + ((opt.selected) ? ' selected="selected"' : '') + '>' + opt.text  + '</option>') ;
        }) ;
        optStrings.push('</select>') ;
        if(type === 'select-other')
        {
          optStrings.push('<span><input id="' + id + 'Other" type="text" style="margin-left: 10px ; display: none ;" onkeypress="return validateInt(event) ;"></span>') ;
        }
        optStrings.push('</div>') ;
      }
      break ;
  }
  optStrings.push('</div>') ;

  return optStrings.join('') ;
}

function addHeatmapColor(hexColor, id)
{
  var heatmapColors = undefined ;
  if(!(heatmapColors = $('heatmapColors')))
  {
    return false ;
  }

  if(!id)
  {
    id = 'color' + nextHeatmapIndex ;
  }

  // Create our LI for the heatmap color widget
  var colorLi = $(document.createElement('li')) ;
  colorLi.id = 'color' + nextHeatmapIndex ;
  colorLi.style.overflow = 'auto' ;
  colorLi.style.display = 'none' ;
  colorLi.update(createHeatmapWidgetHtml('color' + nextHeatmapIndex, hexColor, (heatmapColors.childNodes.length === 0))) ;
  heatmapColors.appendChild(colorLi) ;

  // Attempt to adjust our widget UI to only allow one '+' button
  var prevColor = colorLi.previous() ;
  var prevAdd = undefined ;
  if(prevColor && (prevAdd = $(prevColor.id + 'Add')))
  {
    prevAdd.hide() ;
    prevColor.style.paddingLeft = '22px' ;
  }

  // Finally show our new heatmap widget
  Effect.Appear(colorLi, { queue: 'end', duration: 0.5 }) ;
  nextHeatmapIndex += 1 ;

  return true ;
}

function removeHeatmapColor(widgetId)
{
  var colorEl = undefined ;
  if(!(colorEl = $(widgetId)))
  {
    return false ;
  }

  // We get our siblings to see which '+' button to enable
  var prevColors = colorEl.previousSiblings() ;
  var nextColors = colorEl.nextSiblings() ;

  // Hide and then remove our color widget from the UI
  Effect.Fade(colorEl, { queue: 'end', duration: 0.5, afterFinish : function() 
    {
      colorEl.remove() ;
      // We will always have at least one color widget, because we require
      // at least one color specified.
      if(nextColors.length === 0)
      {
        var prevColorAddBtn = $(prevColors[0].id + 'Add') ;
        if(prevColorAddBtn)
        {
          prevColors[0].style.paddingLeft = '3px' ;
          prevColorAddBtn.show() ;
        }
      }
    }
  }) ;
  
  return true ;
}

function createHeatmapWidgetHtml(widgetId, hexColor, firstColor)
{
  var widgetHtml = ['<a href="#" id="' + widgetId + 'Add" onclick="addHeatmapColor(\'#000000\') ; return false ;" class="smallBttn"><span>+</span></a>'] ;
  if(!firstColor)
  {
    widgetHtml.push('<a href="#" id="' + widgetId + 'Remove" onclick="removeHeatmapColor(\'' + widgetId + '\') ; return false ;" class="smallBttn"><span>-</span></a>') ;
  }
  widgetHtml.push('<div class="optionInput colorInput">') ;
  widgetHtml.push('<div id="' + widgetId + 'Swatch" class="swatch" style="background-color: ' + hexColor + ' ;"></div>') ;
  widgetHtml.push('<input type="hidden" id="' + widgetId + 'Input" value="' + hexColor + '">') ;
  widgetHtml.push('<a class="colorLink" href="#" onclick="setDivId(\'' + widgetId + 'Swatch\', \'' + widgetId + 'Input\', \'' + hexColor + '\') ; return false ;">Change Color</a>') ;
  widgetHtml.push('</div>') ;

  return widgetHtml.join('') ;
}

function  updateLinkField(trackName, field)
{
  var linkedBy = undefined ;
  if(trackName === '' || !(linkedBy = $('linkedBy')))
  {
    return false ;
  }

  // Our trackName has already been URI encoded when it was placed in the value, so we just pass it on
  // Had it no been encoded previously, we would need to encode it like we do the group and rseq names
  var escapedRestUri = encodeURIComponent('/REST/v1/grp/' + encodeURIComponent(CircosUI.groupName) +
    '/db/' + encodeURIComponent(CircosUI.rseqName) + '/trk/' + trackName + '/annoAttributes') ;

/*  if($('calloutFieldLoading'))
  {
    $('calloutFieldLoading').show() ;
  }*/

  linkedBy.options.length = 0 ;
  new Ajax.Request('/java-bin/apiCaller.jsp?rsrcPath=' + escapedRestUri + '&method=GET', {
    method : 'get',
    onComplete : function(transport) {
      var linkedBy = undefined ;
      if(!(linkedBy = $('linkedBy')))
      {
        return false ;
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
        if(field === standardFields[i].value)
        {
          option.selected = true ;
        }
        option.appendChild(document.createTextNode(standardFields[i].name)) ;
        linkedBy.appendChild(option) ;
      }

      if(transport.status >= 200 && transport.status < 300)
      {
        var restData = eval('('+transport.responseText+')') ;
        restData.data.sort(function(a, b) {
          if(a.text < b.text)  { return -1 ; }
          if(a.text > b.text)  { return 1 ; }
          if(a.text === b.text) { return 0 ; }
        }) ;

        for(var i = 0 ; i < restData.data.length ; i++)
        {
          var option = document.createElement('option') ;
          option.value = restData.data[i].text ;
          if(field === restData.data[i].text)
          {
            option.selected = true ;
          }
          option.appendChild(document.createTextNode(restData.data[i].text)) ;
          linkedBy.appendChild(option) ;
        }
      }

      /*if($('calloutFieldLoading'))
      {
        $('calloutFieldLoading').hide() ;
      }*/
    }
  }) ;
}
/** END Annotation Track Methods **/

/** Job Processing Methods **/
function updateStatusInfo()
{
  var errors = [] ;
  var warnings = [] ;
  var errText = '' ;
  var submitFeedbackEl = undefined ;
  var submitButton = undefined ;

  if(!(submitFeedbackEl = $(tabs.submitTab.feedbackDivId)) || !(submitButton = $('submitButton')))
  {
    return false ;
  }

  // Ensure we have at least one entry point drawn
  if(CircosUI.numEpsDrawn === 0)
  {
    $('epsStatus').update('<img alt="Failed" src="/images/vgpFailure.png" />') ;
    errors.push('No entry points in the "Entry Points" tab are marked for drawing, at least one must be drawn') ;
  }
  else
  {
    $('epsStatus').update('<img alt="Satisfied" src="/images/vgpCheckmark.png" />') ;
  }

  // We need to ensure that chromsome units, spacing and a radius is set
  if($('units').hasClassName('error'))
  {
    $('unitsStatus').update('<img alt="Failed" src="/images/vgpFailure.png" />') ;
    errors.push('The chromosome units must have a non-zero value specified') ;
  }
  else
  {
    $('unitsStatus').update('<img alt="Satisfied" src="/images/vgpCheckmark.png" />') ;
  }
  
  if($('ideoSpacing').hasClassName('error'))
  {
    $('spacingStatus').update('<img alt="Failed" src="/images/vgpFailure.png" />') ;
    errors.push('A non-zero spacing value must be specified for the ideogram spacing') ;
  }
  else
  {
    $('spacingStatus').update('<img alt="Satisfied" src="/images/vgpCheckmark.png" />') ;
  }
  
  if($('ideoRadiusOther').visible() && $('ideoRadiusOther').hasClassName('error'))
  {
    $('radiusStatus').update('<img alt="Failed" src="/images/vgpFailure.png" />') ;
    errors.push('A non-zero radius value must be specified for the ideogram radius') ;
  }
  else
  {
    $('radiusStatus').update('<img alt="Satisfied" src="/images/vgpCheckmark.png" />') ;
  }

  for(var epId in CircosUI.entryPoints.eps)
  {
    if(CircosUI.entryPoints.eps[epId].drawn && CircosUI.entryPoints.eps[epId].label.length >= CircosUI.maxEpLabelLength)
    {
      warnings.push('The label \'' + CircosUI.entryPoints.eps[epId].label + '\' might be drawn off the image, consider shortening the label') ;
      break ;
    }
  }

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
    submitButton.disabled = true ;
  }
  else
  {
    submitButton.disabled = false ;
  }

  submitFeedbackEl.update(errText) ;
}

function requestJob()
{
  new Ajax.Updater('submitFeedback', '/genboree/circos/circosConfigRequestHandler.rhtml', {parameters: {options: createParamsObject()}}) ;
}

function createParamsObject()
{
  // Evaluate migrating to Ext.util.JSON.encode(<object>)
  // Create our parameters object that represents the options for creating a circos image
  var params = ["{"] ;
  
  // Ideogram to start
  params.push('"ideogram" : {') ;

  // First, chromosome units
  params.push('"units" : '+$F('units')) ;
  params.push(', "spacing" : '+$F('ideoSpacing')) ;
  params.push(', "radius" : ' + (($F('ideoRadius') === 'other') ? $F('ideoRadiusOther') : $F('ideoRadius'))) ;
  params.push(', "axis_break_style" : '+$F('breakStyle')) ;
  params.push(', "fill_bands" : '+ (($('epColoring').checked) ? '"no"' : '"yes"')) ;
  params.push(', "color" : "' + (($('epColoring').checked) ? $F('allEpColor') : '#FFFFFF') + '"') ;
  params.push(', "show_label" : '+(($('drawLabels') && $('drawLabels').checked) ? '"yes"' : '"no"')) ;
  params.push(', "banding" : "' + (($('epBanding').checked) ? $F('globalBand') : '') + '"') ;
  params.push(', "closed" : '+$('closedIdeo').checked) ;

  // Next the entryPoints to be drawn
  var epsString = new Array() ;
  params.push(', "entry_points" : [') ;
  for(var chromosome in CircosUI.entryPoints.eps)
  {
    // We send all EPs so that Circos doesn't die when an annotation file
    // references an EP that will not be drawn. Visibility of EPs is handled in the back end.
    epsString.push(CircosUI.entryPoints.eps[chromosome].marshal("json")) ;
  }
  params.push(epsString.join(',') + ']}') ; // Close the entryPoints array and ideo object

  // Add all of our tracks - tracks can be added more than once, data struct:
  // "tracks" : { "Track:Name" : [{track1}, {track2}], "Track2:Name" : [{track1}]}
  var allTrackStrings = {} ;
  var trackTypeStrings = new Array() ;
  params.push(', "tracks" : {') ;
  
  // Build our struct
  for(var trackId in CircosUI.tracks.trackObjs)
  {
    if(!allTrackStrings[CircosUI.tracks.trackObjs[trackId].trackName])
    {
      allTrackStrings[CircosUI.tracks.trackObjs[trackId].trackName] = new Array(CircosUI.tracks.trackObjs[trackId].marshal('json')) ;
    }
    else
    {
      allTrackStrings[CircosUI.tracks.trackObjs[trackId].trackName].push(CircosUI.tracks.trackObjs[trackId].marshal('json')) ;
    }
  }

  // Write out our struct
  for(var trackName in allTrackStrings)
  {
    trackTypeStrings.push('"' + escapeJson(trackName) + '" : [ ' + allTrackStrings[trackName].join(', ') + ']') ;
  }

  params.push(trackTypeStrings.join(',')) ;
  params.push('}') ; // Close the tracks object

  // Add our tick marks
  params.push(', "ticks" : [') ;
  
  count = 0 ;
  for(var tick in CircosUI.ticks.tickObjs)
  { 
    if(CircosUI.ticks.tickObjs[tick].options.spacing === -1)
    {
      // Should never happen, but spacing is not set so we skip this tick
      continue ;
    }

    count += 1 ;
    params.push(CircosUI.ticks.tickObjs[tick].marshal("json")) ;
    if(count < CircosUI.ticks.count) 
    {
      params.push(", ") ; 
    }
  }
  params.push("]") ; // Close the ticks array

  // Pass our config options to create the Circos job
  params.push(', "config" : {') ;
  params.push('"userId" : ' + CircosUI.userId + ', "groupId" : ' + CircosUI.groupId + ', "groupName" : "' + CircosUI.groupName + '", "rseqId" : ' + CircosUI.rseqId + ', "rseqName" : "' + CircosUI.rseqName + '", ') ;
  params.push('"userLogin" : "' + escapeJson(CircosUI.userLogin) + '", "userEmail" : "'+ escapeJson(CircosUI.userEmail) + '"') ;
  params.push('}') ; // Close the config object

  // Close our JSON object -- we have alread used a comma as our delimiter, so simply join
  params.push('}') ;

  return params.join("") ;
}

function setEpLabel(epId)
{
  if(epId)
  {
    CircosUI.entryPoints['eps'][epId].label = $F('epLabel') ;
  }
}

function changeIdeoRadius()
{
  setOtherOptVis('ideoRadius', 'ideoRadiusOther') ;
  displayIdeoSize(parseInt(($F('ideoRadius') === 'other') ? $F('ideoRadiusOther') : $F('ideoRadius'))) ;
}

function displayIdeoSize(diameter)
{
  var text = (diameter) ? 'Resulting image size: ' + (diameter * 2) + ' x ' + (diameter * 2) + ' pixels' : 'Resulting image size: ' ;
  $('imageSize').update(text) ;
}
