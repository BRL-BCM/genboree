/**********************************
* Project: Circos UI Integration
*   This project creates a User Interface (UI) to assist users in
*   creating parameter files for Circos (v0.49), a data visualization tool.
*   The integration also creates a server-side support environment to create
*   necessary configuration files, queue a Circos job with the Genboree environment
*   and then package the Circos output files and notify the user of job completion.
*
* circosConfigUtilities.js - This javascript file defines the client-side 
*   methods that are not directly related to any Circos content or info 
*   (data checks, OO-style data structs, etc)
*
* Developed by Bio::Neos, Inc. (BIONEOS)
* under a software consulting contract for:
* Baylor College of Medicine (CLIENT)
* Copyright (c) 2009 CLIENT owns all rights.
* To contact BIONEOS, visit http://bioneos.com
**********************************/

var selectedEpId = '' ;
var selectedTrackId = '' ;
var selectedTickId = '' ;
var selectedBreakId = '' ;
var selectedScaleId = '' ;
var selectedTab = 'epTab' ;
var nextTrackIndex = 1 ;
var nextTickIndex = 1 ;
var nextRuleIndex = 1 ;
var nextBreakIndex = 1 ;
var nextScaleIndex = 1 ;
var nextHeatmapIndex = 1 ;

/** The following hash represents our tabs and their corresponding divs **/
var tabs = 
{
  'epTab' : {'divId' : 'eps', 'feedbackDivId' : 'epFeedback'},
  'ideoTab' : {'divId' : 'ideo', 'feedbackDivId' : 'ideoFeedback'},
  'annotTab' : {'divId' : 'annotation', 'feedbackDivId' : 'annotFeedback'},
  'submitTab' : {'divId' : 'submit', 'feedbackDivId' : 'submitFeedback'}
} ;

/** These options must have a valid value set **/
var nonNullOptions = 
{
  'epScaleStart' : 'The start of the entry point scaling',
  'epScaleEnd' : 'The end of the entry point scaling',
  'localScaleFactorOther' : 'The scale factor for the entry point',
  'globalScaleFactorOther' : 'The scale factor for the entry point',
  'epBreakStart' : 'The start of the entry point break',
  'epBreakEnd' : 'The end of the entry point break',
  'units' : 'Chromosome units',
  'ideoSpacing' : 'Ideogram spacing',
  'ideoRadiusOther' : 'The ideogram radius',
  'tickUserSpacing' : 'The spacing for the tick mark group',
  'sizeOther' : 'The size of the tick mark',
  'labelSizeOther' : 'The size of the tick labels for the tick mark',
  'gridStart' : 'The start of the grid line',
  'gridEnd' : 'The end of the grid line',
  'r0' : 'The start radius position',
  'r1' : 'The end radius position',
  'layersOther' : 'The number of layers for the tiles track',
  'thicknessOther' : 'The thickness of the tiles',
  'radius' : 'The radial position for the link',
  'recordLimitOther' : 'The record limit for the links track',
  'bezierRadiusOther' : 'The bezier radius for the links track'
} ;

/** The following object keeps track of our available rule conditions and editable type options **/
var ruleSpecs = 
{
  'conditions' : 
  [
    {'value' : '>', 'desc' : 'greater than'},
    {'value' : '<', 'desc' : 'less than'},
    {'value' : '==', 'desc' : 'equal to'}
  ],
  'typeOpts' : 
  {
    'scatter' : 
    {
      'visibility' : {'type' : 'select', 'opts' : ['show', 'hide']},
      'glyph' : {'type' : 'select', 'opts' : ['circle', 'rectangle', 'triangle']},
      'glyphSize' : {'type' : 'text'},
      'fillColor' : {'type' : 'color'},
      'strokeColor' : {'type' : 'color'}
    },
    'line' :
    {
      'visibility' : {'type' : 'select', 'opts' : ['show', 'hide']},
      'color' : {'type' : 'color'},
      'thickness' : {'type' : 'text'}
    },
    'histogram' :
    {
      'visibility' : {'type' : 'select', 'opts' : ['show', 'hide']},
      'lineColor' : {'type' : 'color'},
      'fillArea' : {'type' : 'select', 'opts' : ['yes', 'no']},
      'fillColor' : {'type' : 'color'},
      'orientation' : {'type' : 'select', 'opts' : ['out', 'in']}
    },
    'tile' :
    {
      'visibility' : {'type' : 'select', 'opts' : ['show', 'hide']}
    },
    'heatmap' :
    {
      'visibility' : {'type' : 'select', 'opts' : ['show', 'hide']}
    },
    'link' :
    {
      'visibility' : {'type' : 'select', 'opts' : ['show', 'hide']},
      'ribbon' : {'type' : 'select', 'opts' : ['yes', 'no']},
      'bezierRadius' : {'type' : 'text'}
    }
  }
} ;

/** START utility methods **/
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
 
    if(tab === 'submitTab')
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

function setOtherOptVis(selectId, otherId)
{
  var selectEl = undefined ;
  var otherEl = undefined ;

  if(!(selectEl = $(selectId)) || !(otherEl = $(otherId)))
  {
    return ;
  }

  if($F(selectEl) === 'other')
  {
    Effect.Appear(otherEl, {queue: 'end', afterFinish: function() { otherEl.focus() ; }, duration: 0.5}) ;
  }
  else if(otherEl.visible())
  {
    Effect.Fade(otherEl, {queue: 'end', afterFinish: function() { selectEl.focus() ; }, duration: 0.5}) ;
  }
}

function selectElement(elId, selectedElId)
{
  var el = undefined ;
  var selectedEl = undefined ;

  if(selectedElId == elId)
  {
    return false ;
  }

  el = $(elId) ;
  selectedEl = $(selectedElId) ;

  if(el)
  {
    el.addClassName('selected') ;
  }

  if(selectedEl)
  {
    selectedEl.removeClassName('selected') ;
  }

  return true ;
}

function setSelectElValue(selectEl, otherEl, selectedValue)
{
  selectEl = $(selectEl) ;
  otherEl = $(otherEl) ;
  var otherSelected = true ;

  if(!selectEl)
  {
    return false ;
  }

  for(var i = 0 ; i < selectEl.options.length ; i++)
  {
    if(selectEl.options[i].value == selectedValue)
    {
      selectEl.selectedIndex = i ;
      otherSelected = false ;
      break ;
    }
  }

  if(otherSelected && otherEl)
  {
    selectEl.selectedIndex = selectEl.options.length - 1 ;
    otherEl.value = selectedValue ;
    otherEl.show() ;
  }
  else if(otherEl)
  {
    otherEl.hide() ;
  }

  return true ;
}

function toggleAdvancedOptions(advancedId, anchor)
{
  if(!$(advancedId) || !anchor)
  {
    return ;
  }

  Effect.toggle(advancedId, 'blind', { duration: 0.5, afterFinish: function() {
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

function createSpinner(elId, defaultVal)
{
  var el = undefined ;
  if(!elId || !(el = $(elId)))
  {
    return false ;
  }

  var spinner = new Ext.ux.form.Spinner({
    strategy: new Ext.ux.form.Spinner.NumberStrategy({minValue:0.01, maxValue: 1.5, incrementValue:0.01, alternateIncrementValue:0.1})
  }) ;
  spinner.applyToMarkup(elId) ;
  spinner.addListener('spin', function() { 
    if(this.getEl().hasClass('error')) 
    {
      this.getEl().removeClass('error') ; 
    }
  }) ;

  // Set a default value
  if(defaultVal)
  {
    el.value = defaultVal ;
  }

  return spinner ;
}

function createTrackSpinner(elId, defaultVal)
{
  return createSpinner(elId, defaultVal).addListener('spin', function() {
    setTrackButtonsStatus((elId === 'r0' || elId === 'r1') ? ['r0', 'r1'] : 'radius') ; 
  }) ;
}

function escapeJson(str)
{
  str = str.replace(/\\/g, '\\\\') ;    // escape slashes
  str = str.replace(/\//g, '\\\/') ;    // escape slashes
  str = str.replace(/'/g, '\\\'') ;     // escape single quotes
  str = str.replace(/"/g, '\\\"') ;     // escape double quotes

  // escape control characters
  str = str.replace(/\n/g, '\\n') ;
  str = str.replace(/\t/g, '\\t') ;
  str = str.replace(/\r/g, '\\r') ;

  return str ;
}

/** Extend our String object to add the trim method **/
String.prototype.trim = function() {
  return this.replace(/^\s+|\s+$/, '') ;
}

String.prototype.commaized = function() {
  var commaStr = '' ;
  var expression = /^(\d+)(\d{3})/ ;

  if(expression.exec(this))
  {
    while(RegExp.$1.length > 3)
    {
      commaStr += ',' + RegExp.$2 ;
      expression.exec(RegExp.$1) ;
    }

    commaStr = RegExp.$1 + ',' + RegExp.$2 + commaStr ;
  }
  else
  {
    commaStr = this ;
  }

  return commaStr ;
}

/** END utility methods **/

/** START data validation and check methods **/
function checkPosInt(inputEl)
{
  var intVal = parseInt(inputEl.value) ;
  if(isNaN(intVal) || (intVal === 0))
  {
    $(inputEl).addClassName('error') ;
  }
  else
  {
    $(inputEl).removeClassName('error') ;
  }
}

function validateInt(e)
{
  var code = 0 ;

  if(e.which)
  {
    code = e.which ;
  }
  else if(window.event)
  {
    code = e.keyCode ;
  }

  if((code > 31 && code < 48) || (code > 57)) return false ;

  return true ;
}

function validateFloat(e, text)
{ 
  var code = 0 ;

  if(e.which)
  {
    code = e.which ;
  }
  else if(window.event)
  {
    code = e.keyCode ;
  }

  if(((code > 31 && code < 48) || (code > 57)) && (code != 46)) return false ;
  if((code == 46) && (text.value.indexOf('.') != -1)) return false ;

  return true ;
}

function checkPosFloat(inputEl)
{
  var floatVal = parseFloat(inputEl.value) ;
  if(isNaN(floatVal) || (floatVal < 0))
  {
    $(inputEl).addClassName('error') ;
  }
  else
  {
    $(inputEl).removeClassName('error') ;
  }
}

function validateOptionsForTab(id)
{
  var errors = new Array() ;

  $$('#' + id + ' .error').each(function(input) {
    if(nonNullOptions[input.id])
    {
      errors.push(nonNullOptions[input.id] + ' must have a valid value set') ;
    }
  }) ;

  return errors ;
}

function restrictWhitespace(e)
{
  // Circos does not support spaces in labels
  var code = 0 ;
  if(e.which)
  {
    code = e.which
  }
  else if(window.event)
  {
    code = e.keyCode ;
  }

  // No whitespace allowed
  if(code == 32) return false ;

  return true ;
}

function reportErrors(errorsArray, elToUpdate)
{
  if(!elToUpdate)
  {
    return ;
  }

  var feedback = '<div class="failure">\n' ;
  feedback += '  The following errors were found when trying to complete the desired action.<br>\n' ;
  feedback += '  Please correct the errors below before continuing:<br>\n' ;
  feedback += '  <ul>' ;
  for(var i = 0 ; i < errorsArray.length ; i++)
  {
    feedback += '    <li>' + errorsArray[i] + '</li>\n' ;
  }
  feedback += '  </ul>' ;
  feedback += '</div>\n' ;
  elToUpdate.update(feedback) ;
}

function checkSubmitKey(e)
{
  var code = 0 ;
  if(e.which)
  {
    code = e.which ;
  }
  else if(window.event)
  {
    code = e.keyCode ;
  }

  if(code == 13) { return true ; }
  return false ;
}
/** END validate and check methods **/

/** START data structures **/
EntryPoint = function(name, length, position, drawn)
{
  this.name = name ;
  this.length = length ;
  this.position = position ;
  this.drawn = drawn ;
  this.color = '' ;
  this.label = name ;
  this.mode = 'fullEp' ;
  this.scale = 'noScale' ;
  this.globalScale = 1 ;
  this.localScales = {} ;
  // TODO: Make this an object instead of an array
  this.breaks = new Array() ;
}

EntryPoint.prototype.getBreak = function(breakId)
{
  if(!breakId || breakId == '')
  {
    return null ;
  }

  for(var i = 0 ; i < this.breaks.length ; i++)
  {
    if(this.breaks[i].id == breakId)
    {
      return this.breaks[i] ;
    }
  }

  return null ;
}

EntryPoint.prototype.removeBreakById = function(breakId)
{
  var breakIndex = -1 ;

  for(var i = 0 ; i < this.breaks.length ; i++)
  {
    if(this.breaks[i].id == breakId)
    {
      breakIndex = i ;
      break ;
    }
  }

  if(breakIndex == -1)
  {
    return false ;
  }

  this.breaks.splice(breakIndex, 1) ;
  if(this.breaks.length == 0)
  {
    this.mode = 'fullEp' ;
  }

  return true ;
}

EntryPoint.prototype.marshal = function(format) 
{
  var data = '' ;

  if(format === 'json')
  {
    var jsonStrings = new Array() ;
    jsonStrings.push('{') ;
    jsonStrings.push('"id":"'+this.name+'", "label":"'+this.label+'", "length":'+this.length+', ') ;
    jsonStrings.push('"position":'+this.position+', "drawn":'+this.drawn+', "scale":"'+this.scale.underscore()+'"') ;
    if(this.scale === 'globalScale')
    {
      jsonStrings.push(', "global_scale_factor":'+this.globalScale) ;
    }
    else if(this.scale === 'localScale')
    {
      var scaleStrings = new Array() ;
      jsonStrings.push(', "local_scales" : {') ;
      for(var scaleId in this.localScales)
      {
        var scaleObj = this.localScales[scaleId] ;
        scaleStrings.push('"' + scaleId + '" : {"start" : ' + scaleObj.start + ', "end" : ' + scaleObj.end + ', "scale" : ' + scaleObj.scale + '}') ;
      }
      jsonStrings.push(scaleStrings.join(',') + '}') ;
    }

    if(this.color != "")
    {
      jsonStrings.push(', "color":"'+this.color+'"') ;
    }
   
    if(this.mode === 'breakEp')
    {
      jsonStrings.push(', "breaks" : [') ;
      var breaksString = new Array() ;
      for(var i = 0 ; i < this.breaks.length ; i++)
      {
        breaksString.push('{"start": ' + this.breaks[i].start + ', "end": ' + this.breaks[i].end + '}') ;
      }
      jsonStrings.push(breaksString.join(',') + ']') ;
    }
    jsonStrings.push('}') ;

    data = jsonStrings.join('') ;
  }

  return data ;
}

EntryPoint.prototype.toString = function() 
{
  return "Entry Point "+this.name+"["+this.position+"]: starts @ 0, ends @ "+this.length+" and drawn="+this.drawn ;
}

// This is a simple container class for everything else: Plots, Highlights, Links
// The individual options for each type are specified in the options object
Track = function(id, trackName)
{
  this.id = id ;
  this.trackName = trackName ;
  this.annoColorOverride = true ;
  this.rules = new Array() ;
  this.options = {}
}

Track.prototype.marshal = function(format)
{
  var data = '' ;

  // If Prototype 1.5.1 is deployed, #toJSON(obj) can be used instead
  if(format === 'json')
  {
    var jsonStrings = new Array() ;
    var rulesStrings = new Array() ;

    for(var optKey in this.options)
    {
      // Ignore any option that has a blank value. Also skip any 'Other' values (thicknessOther) b/c we will need to 
      // get rid of the other option and just assign it to the property name (thickness = thicknessOther)
      if(this.options[optKey] === '' || /\S+Other$/.test(optKey))
      {
        continue ;
      }

      // This method will simplify adding options by making it possible to just add an HTML component for a 
      // track style and it will be added to the JS track object (see circosConfigActions.js#setTrackOptions)
      if(this.options.type === 'heatmap' && optKey === 'color')
      {
        var color = [] ;
        for(var clr in this.options.color)
        {
          color.push(this.options.color[clr]) ;
        }
        jsonStrings.push('"color" : "' + color.join(',') + '"') ;
      }
      else
      {
        var value = (this.options[optKey] === 'other') ? this.options[optKey + 'Other'] : this.options[optKey] ;
        if(optKey === 'r0' || optKey === 'r1' || optKey === 'radius')
        {
          value += 'r' ;
        }

        if(typeof(value) === 'string')
        {
          value = '"' + escapeJson(value) + '"' ;
        }
        jsonStrings.push('"' + optKey.underscore() + '" : ' + value) ;
      }
    }

    for(var i = 0 ; i < this.rules.length ; i++)
    {
      var ruleOpts = [] ;
      var value = (typeof(this.rules[i].optVal) === 'string') ? '"' + this.rules[i].optVal + '"' : this.rules[i].optVal ;
      ruleOpts.push('"condition" : "_VALUE_ ' + this.rules[i].condition + ' ' + this.rules[i].value + '"') ;
      ruleOpts.push('"' + this.rules[i].opt.underscore() + '" : ' + value) ;
      rulesStrings.push('{' + ruleOpts.join(',') + '}') ;
    }

    data += '{ "rules" : [' + rulesStrings.join(',')  + '], "properties" : {' + jsonStrings.join(',') + '} }' ;
  }

  return data ;
}

TickMark = function(id)
{
  this.id = id ;
  this.userSpacing = '' ;
  this.units = '' ;

  // Our options object contains properties that specify Circos config options and will automatically be
  // passed to the backed during the marshal method. Any options that are not recognized by Circos and 
  // are to be used solely in the UI should not go in the options object but defined like above instead
  this.options = {} ;

  // Set some default values for options
  this.options.spacing = '1u' ;
  this.options.size = '6p' ;
  this.options.showTick = true ;
  this.options.showLabel = false ;
  this.options.grid = false ;
}

TickMark.prototype.toString = function() 
{
  return 'Tick marks spaced every ' + this.userSpacing + this.units.capitalize() + ', drawn ' + this.options.size + ' pixel' + ((this.options.size == 1) ? 's ' : ' ') + 'long' ;
}

TickMark.prototype.setSpacingParams = function(chrUnits)
{
  var multiplier = 1.0 ;
  var spacing = parseFloat(this.userSpacing) ;
  var chrUnits = parseFloat(chrUnits) ;

  if(isNaN(spacing) || isNaN(chrUnits))
  {
    this.options.spacing = -1 ;
    return ;
  }

  switch(this.units)
  {
    case 'kb' :
      this.options.multiplier = '1e-3' ;
      multiplier = 1000.0 ;
      break ;
    case 'mb' :
      this.options.multiplier = '1e-6' ;
      multiplier = 1000000.0 ;
      break ;
    default :
      this.options.multiplier = '1' ;
      multiplier = 1.0 ;
      break ;
  }
  this.options.spacing = ((spacing * multiplier) / (chrUnits)) + 'u' ;

  return ;
}

TickMark.prototype.marshal = function(format)
{
  var data = '' ;

  if(format == 'json')
  {
    var jsonStrings = new Array() ;
    
    for(var optKey in this.options)
    {
      // Ignore any option that has a blank value
      if(this.options[optKey] === '' || /\S+Other$/.test(optKey))
      {
        continue ;
      }

      var value = (this.options[optKey] === 'other') ? this.options[optKey + 'Other'] : this.options[optKey] ;
      if(/grid[StartEnd]/.test(optKey))
      {
        // grid_start and grid_end need to have the 'r' appeneded to specify units
        value += 'r' ;
      }

      if(typeof(value) === 'string')
      {
        value = '"' + escapeJson(value) + '"' ;
      }
      jsonStrings.push('"' + optKey.underscore() + '" : ' + value) ;
    }

    data += '{' + jsonStrings.join(',') + '}' ;
  }

  return data ;
}
/** END data structures **/
