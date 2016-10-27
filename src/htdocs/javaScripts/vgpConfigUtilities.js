/**********************************
* Project: VGP UI Integration
*   This project creates a new User Interface (UI) to assist users in
*   creating parameter files for the Virtual Genome Painter (VGP) v 2.0.
*   The integration also creates a server-side support environment to create
*   necessary configuration files, queue a VGP job with the Genboree environment
*   and then package the VGP output files and notify the user of job completion.
*
* vgpConfigUtilities.js - This javascript file defines the client-side 
*   utility methods (for data checks) and come basic data structures (OO-style classes)
*
* Developed by Bio::Neos, Inc. (BIONEOS)
* under a software consulting contract for:
* Baylor College of Medicine (CLIENT)
* Copyright (c) 2008 CLIENT owns all rights.
* To contact BIONEOS, visit http://bioneos.com
**********************************/

/** Utility vars **/
var selectedEpId = '' ;
var selectedSegId = '' ;
var selectedColumnId = '' ;
var selectedTrackId = '' ;
var nextColumnId = 1 ;
var nextTrackId = 1 ;
var numEpSegsDrawn = 0 ;
var referenceTrack = null ;
var selectedTab = 'epTab' ;

/** The following options MUST be set to some value (i.e. Not an empty string) **/
var nonNullOptions = {
  'genomeMargin' : 'Margin for the genome view image',
  'genomeFontSize' : 'Font size for the chromosome labels of the genome view',
  'genomeFontColor' : 'Font color for the chromosome labels of the genome view',
  'tLegendColNum' : 'Number of columns in the track-based legend',
  'tLegendFontSize' : 'Font size for the track-based legend',
  'tLegendFontColor' : 'Font color for the track-based legend',
  'cLegendColNum' : 'Number of columns in the column-based legend',
  'cLegendFontSize' : 'Font size for the column-based legend',
  'cLegendFontColor' : 'Font color for the column-based legend',
  'titleFontSize' : 'Font size for the image title',
  'titleFontColor' : 'Font color for the image title',
  'subtitleFontSize' : 'Font size for the image subtitle',
  'subtitleFontColor' : 'Font color for the image subtitle',
  'xAxisFontSize' : 'Font size for the x-axis label',
  'xAxisFontColor' : 'Font color for the x-axis label',
  'yAxisFontSize' : 'Font size for the y-axis label',
  'yAxisFontColor' : 'Font color for the y-axis label',
  'yAxisScaleFontSize' : 'Font size for the y-axis scale label',
  'yAxisScaleFontColor' : 'Font color for the y-axis scale label',
  'columnTitleFontSize' : 'Font size for the column label',
  'columnTitleFontColor' : 'Font color for the column label',
  'columnLabelFontSize' : 'Font size for the column label',
  'columnLabelFontColor' : 'Font color for the column label',
  'trackColor' : 'Track color for the annotation track',
  'trackWidth' : 'Track width for the annotation track',
  'trackMargin' : 'Track margin for the annotation track',
  'trackDisplayName' : 'The display name for the annotation track',
  'fillColor' : 'The box fill color for the annotation track',
  'transparency' : 'The transparency for the annotation track',
  'fontSize' : 'The font size for the annotation track',
  'fontColor' : 'The font color for the annotation track',
  'calloutLength' : 'The number of characters in the callout text',
  'epSegStart' : 'The start value for the segment',
  'epSegEnd' : 'The end value for the segment'
} ;

/** The following hash represents our tabs and their corresponding divs **/
var tabs = {
  'epTab' : {'divId' : 'eps', 'feedbackDivId' : 'epFeedback'},
  'imgTab' : {'divId' : 'figures', 'feedbackDivId' : ''},
  'colTab' : {'divId' : 'columns', 'feedbackDivId' : 'colFeedback'},
  'annotTab' : {'divId' : 'tracks', 'feedbackDivId' : 'trackFeedback'},
  'submitTab' : {'divId' : 'submit', 'feedbackDivId' : ''}
}

/** Utility Methods **/
/** Validate methods - Ensure no disallowed characters can be entered into the input **/
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
  var input = '' ;

  if(e.which)
  {
    code = e.which ;
  }
  else if(window.event)
  {
    code = e.keyCode ;
  }

  if(code < 32 || code > 126) return true ;
  if(e.ctrlKey || e.altKey) return true ;
  input = String.fromCharCode(code) ;
  
  /** If the entered char was a digit, a period with no existing periods, or a dash at the start, then we are good **/
  return !/\D+/.test(input) || (input == '.' && !/.*\..*/.test(text.value)) || (input == '-' && text.value.length == 0) ;
}

function validateOptionsForTab(tabId)
{
  var errors = new Array() ;

  $$('#' + tabId + ' .error').each(function(input) {
    if(nonNullOptions[input.id])
    {
      errors.push(nonNullOptions[input.id] + ' must have a valid value set') ;
    }
  }) ;
  
  return errors ;
}

function restrictWhitespace(e)
{
  // TODO: Regexps better here?
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

/** Check Methods - ensure the input entered meets the required criteria for the option **/
function checkPosInt(inputEl)
{
  /** onkeypress ensures only integer values are entered, must make sure a value
      is set and that value is not zero **/
  var intVal = parseInt(inputEl.value) ;
  if(isNaN(intVal) || (intVal == 0))
  {
    $(inputEl).addClassName('error') ;
  }
  else
  {
    $(inputEl).removeClassName('error') ;
  }
}

function checkIntRange(inputEl, start, stop)
{
  var intVal = parseInt(inputEl.value) ;
  if((intVal < 0) || !$R(start, stop).include(intVal))
  {
    $(inputEl).addClassName('error') ;
  }
  else
  {
    $(inputEl).removeClassName('error') ;
  }
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

function checkNegFloat(inputEl)
{
  var floatVal = parseFloat(inputEl.value) ;
  if(isNaN(floatVal) || (floatVal > 0))
  {
    $(inputEl).addClassName('error') ;
  }
  else
  {
    $(inputEl).removeClassName('error') ;
  }
}

function checkEmptyOption(inputEl)
{
  /** The onkeypress event handlers ensure only approriate characters can be entered into the
      input for that option. So we only have to ensure that the input has some non-null value **/
  if(inputEl.value == '' || !/\S+/.test(inputEl.value))
  {
    $(inputEl).addClassName('error') ;
  }
  else
  {
    $(inputEl).removeClassName('error') ;
  }
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

function escapeJson(str)
{
  str = str.replace(/\\/g, '\\\\');    // escape slashes
  str = str.replace(/\//g, '\\\/');    // escape slashes
  str = str.replace(/'/g, '\\\'');     // escape single quotes
  str = str.replace(/"/g, '\\\"');     // escape double quotes
  
  // escape control characters
  str = str.replace(/\n/g, '\\n') ;
  str = str.replace(/\t/g, '\\t') ;
  str = str.replace(/\r/g, '\\r') ;
  
  return str;
}
/** END utility methods **/

/** Extend our String object to add the trim method **/
String.prototype.trim = function() {
  return this.replace(/^\s+|\s+$/, '') ;
}

/** VGP 'objects' - some basic OOP for convenience... **/
EntryPoint = function(name, length, drawn)
{
  this.name = name ;
  this.length = length ;
  this.drawn = (drawn == null) ? true : drawn ;
  this.mode = 'full' ;
  this.segOrder = 'startOrder' ;
  this.segments = new Array() ;
  this.nextSegId = 1 ;
}

EntryPoint.prototype.getSegment = function(segId)
{
  for(var i = 0 ; i < this.segments.length ; i++)
  {
    if(this.segments[i].id == segId)
    {
      return this.segments[i] ;
    }
  }
  
  return null ;
}

EntryPoint.prototype.removeSegmentById = function(segId)
{
  var segIndex = -1 ;

  for(var i = 0 ; i < this.segments.length ; i++)
  {
    if(this.segments[i].id == segId)
    {
      segIndex = i ;
      break ;
    }
  }
  
  if(segIndex == -1)
  {
    return false ;
  }

  this.segments.splice(segIndex, 1) ;

  return true ;
}

EntryPoint.prototype.marshal = function(format)
{
  var data = '' ;

  if(format == 'json')
  {
    data += '{"name" : "'+this.name+'", "length" : '+this.length+', "drawn" : '+this.drawn+'}' ;
  }

  return data ;
}

EntryPoint.prototype.marshalSegs = function(format)
{
  var data = '' ;

  if(format == 'json')
  {
    data += '{"'+this.name+'" : [' ;
    if(this.mode == 'fullAndSegs')
    {
      data += '{"start" : 0, "end" : ' + this.length + '}' ;
      if(this.segments.length > 0) { data += ', ' ; }
    }

    for(var i = 0 ; i < this.segments.length ; i++)
    {
      data += '{"start" : ' + this.segments[i].start + ', "end" : ' + this.segments[i].end + '}' ;
      if(i < (this.segments.length - 1)) { data += ', ' ; }
    }
    data += '], "segOrder" : "'+this.segOrder+'"}' ;
  }

  return data ;
}

DataColumn = function()
{
  this.title = '' ;
  this.position = 0 ;
  this.drawTitle = true ;
  this.drawLabel = true ;
  this.titleFont = 'arial' ;
  this.titleSize = 14 ;
  this.titleColor = '000000' ;
  this.labelFont = 'arial' ;
  this.labelSize = 12 ;  
  this.labelColor = '000000' ;
  this.tracks = new Array() ;
}

DataColumn.prototype.marshal = function(format)
{
  var data = '' ;
  
  if(format == 'json')
  {
    // This JSON object represents an entry in the ['columns']['titles'] array...
    data += '{' ;
    data += '"position" : ' + this.position + ', "title" : "' + escapeJson(this.title).trim() + '", "drawTitle" : ' + this.drawTitle + ', ' ;
    data += '"drawLabel" : ' + this.drawLabel + ', "font" : "' + this.titleFont + '", "fontColor" : "' + this.titleColor + '", ' ;
    data += '"labelFont" : "' + this.labelFont + '", "labelFontColor" : "' + this.labelColor + '", ' ;
    data += '"fontSize" : ' + this.titleSize + ', "labelFontSize" : ' + this.labelSize
    data += '}' ;
  }
  
  return data ;
}

DataColumn.prototype.addTrack = function(track)
{
  this.tracks.push(track) ;
  track.zIndex = this.tracks.length ;
}

DataColumn.prototype.removeTrack = function(trackId)
{
  for(var i = 0 ; i < this.tracks.length ; i++)
  {
    if(trackId == this.tracks[i].internalId)
    {
      this.tracks.splice(i, 1) ;
      return true ;
    }
  }
  
  return false ;
}

DataColumn.prototype.getTrack = function(trackId)
{
  for(var i = 0 ; i < this.tracks.length ; i++)
  {
    if(trackId == this.tracks[i].internalId)
    {
      return this.tracks[i] ;
    }
  }

  return null ;
}

Track = function(trackId, trackName)
{
  // trackName = Genboree track name (eg GC:CpGIslands)
  // internalId = id used for DOM events (eg track_3)
  this.trackName = trackName ;
  this.internalId = trackId ;
  this.drawingStyle = 'block' ;
  this.displayName = trackName ;
  this.position = 0 ;
  this.margin = 5 ;
  this.width = 75 ;
  this.color = '000000' ;
  this.zIndex = 0 ;
  this.legendOrder = -1 ;
  this.border = false ;
  this.isRefTrack = false ;
  this.annoColorOverride = true ;
  this.styleOptions = {} ;
}

Track.prototype.marshal = function(format)
{
  var data = '' ;
  
  if(format == 'json')
  {
    data += '{' ;
    data += '"drawingStyle" : "' + this.drawingStyle + '", "position" : ' + this.position + ', ' ;
    data += '"width" : ' + this.width + ', "margin" : ' + this.margin + ', "zIndex" : ' + this.zIndex + ', ' ;
    data += '"annoColorOverridesTrackColor" : ' + this.annoColorOverride + ', "border" : ' +this.border + ', ';
    data += '"displayName" : "' + escapeJson(this.displayName).trim() + '", "color" : "' + this.color + '"' ;
    if(this.legendOrder > 0)
    {
      data += ', "legendOrder" : ' + this.legendOrder ;
    }
    
    for(var option in this.styleOptions)
    {
      data += ', "' + option + '" : ' ;
      if(/color/i.test(option))
      {
        data += '"' + this.styleOptions[option] + '"' ;
      }
      else
      {
        data += (typeof(this.styleOptions[option]) == 'string') ? '"' + this.styleOptions[option] + '"' : this.styleOptions[option] ;
      }
    }
    data += '}' ;
  }
  
  return data ;
}
/** END VGP Objects **/
