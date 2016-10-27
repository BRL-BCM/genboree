
function setHiddenInput(inputId, value)
{
  return $(inputId).value = "" + value ;
}

function setChrDisplay(obj, onload)
{
  if(obj.value == 'singleEP')
  {
    if($('chrList').style.display != 'none')
    {
      Effect.toggle('chrList', 'blind', { duration: 0.5 }) ;
    }
    $('landmark').disabled = false ;
  }
  else
  {
    if($('chrList').style.display == 'none')
    {
      if(onload)
      {
        $('chrList').style.display = 'block' ;
      }
      else
      {
        Effect.toggle('chrList', 'blind', { duration: 0.5 }) ;
      }
    }
    $('landmark').disabled = true ;
  }
}

var optionsByFileFormat = {
  "lff" : [ "showHeader", true, "includeOtherSections", false ],
  "bed" : [ "showHeader", true, "ucscScaling", false ],
  "bedGraph" : [ "showHeader", false ],
  "gff" : [ "showHeader", true, "ucscScaling", false ],
  "gff3" : [ "showHeader", true, "ucscScaling", false ],
  "gtf"  : [ "showHeader", true, "ucscScaling", false ]
} ;
var optionsTemplates = {
  "showHeader" : '<label style="width:50px; float:left;">&nbsp;</label><input id="showHeader_%%FILE_FORMAT%%" name="showHeader_%%FILE_FORMAT%%" value="%%OPTION_VALUE%%" type="checkbox" %%CHECKED%% style="margin:10px 5px 0 0;width:13px;height:13px;overflow:hidden;" onclick="setHiddenInput(\'showHeader\', (this.checked ? true : false))" /><label for="showHeader_%%FILE_FORMAT%%"><b>Include a column header line?</b></label>',
  "includeOtherSections" : '<label style="width:50px; float:left;">&nbsp;</label><input id="includeOtherSections_%%FILE_FORMAT%%" name="includeOtherSections_%%FILE_FORMAT%%" value="%%OPTION_VALUE%%" type="checkbox" %%CHECKED%% style="margin:10px 5px 0 0;width:13px;height:13px;overflow:hidden;" onclick="setHiddenInput(\'includeOtherSections\', (this.checked ? true : false))" /><label for="includeOtherSections_%%FILE_FORMAT%%"><b>Include Chromosome Definitions?</b></label>',
  "ucscScaling" : '<label style="width:50px; float:left;">&nbsp;</label><input id="ucscScaling_%%FILE_FORMAT%%" name="ucscScaling_%%FILE_FORMAT%%" value="%%OPTION_VALUE%%" type="checkbox" %%CHECKED%% style="margin:10px 5px 0 0;width:13px;height:13px;overflow:hidden;" onclick="setHiddenInput(\'ucscScaling\', (this.checked ? true : false))" /><label for="ucscScaling_%%FILE_FORMAT%%"><b>UCSC Scaling? (Scores will be scaled between 0 and 1000)</b></label>'
} ;
var hiddenInputs = [ "showHeader", "includeOtherSections", "ucscScaling" ] ;

function setFileFormat(onload)
{
  // First, clear any leftover settings in the hidden inputs
  resetHiddenInputs()
  // Next create html inputs that can end up populating the hidden inputs
  var fileFormat = $('fileFormat').value  ;
  var optionsList = optionsByFileFormat[fileFormat] ;
  var buff = '' ;
  if(optionsList)
  {
    buff += '<div id="lffOptionsDiv">' ;
    for(var ii=0 ; ii < optionsList.length; ii++)
    {
      var optionName = optionsList[ii] ;
      ii++ ;
      var optionValue = optionsList[ii] ;
      var checkedStr = (optionValue ? "checked=\"checked\"" : "") ;
      var optionTemplate = optionsTemplates[optionName] ;
      var optionHtml = optionTemplate.replace(/%%FILE_FORMAT%%/g, fileFormat) ;
      optionHtml = optionHtml.replace(/%%OPTION_VALUE%%/g, optionValue) ;
      optionHtml = optionHtml.replace(/%%CHECKED%%/g, checkedStr) ;
      buff += optionHtml ;
      if(ii != (optionsList.length - 1))
      {
        buff += "<br>" ;
      }
    }
    buff += "</div>"
  }
  // Update options div's innerHTML:
  $('formatOptionsDiv').innerHTML = buff ;
  // Update hidden fields that pass the actual setting to server, based
  // on initial settings (must do after setting as innerHTML)
  if(optionsList)
  {
    for(var ii=0 ; ii < optionsList.length; ii++)
    {
      var optionName = optionsList[ii] ;
      ii++ ;
      var optionValue = optionsList[ii] ; // don't actually care, just need to advance and be clear about why
      var inputId = optionName + "_" + fileFormat ;
      var inputElem = document.getElementById(inputId) ; // can't use $('') here for some reason related to dynamic add/remove of html
      setHiddenInput(optionName, (inputElem.checked ? true : false)) ;
    }
  }
  return true ;
}

function resetHiddenInputs()
{
  for(var ii=0; ii < hiddenInputs.length; ii++)
  {
    $(hiddenInputs[ii]).value = "false" ;
  }
  return true ;
}

function validate()
{
  var trackBoxes = document.getElementsByName('trkId') ;
  var numChecked = 0 ;

  landmarkParts = $('landmark').value.match(/([^: ]+)\s*(?:\:\s*(\d+))?(?:\:?\s*-\s*(\d+))?/) ;
  var ep = landmarkParts[1] ;
  var start = landmarkParts[2] ;
  var stop = landmarkParts[3] ;
  if(chromLengths.size() > 0 && !(chromLengths.get(ep) > 0))
  {
    alert("You must indicate a valid chromosome location.\n\n'" + ep + "' is not a valid chromosome for this database.") ;
    return false ;
  }
  else
  {
    if(start && !(start > 0))
    {
      alert("The chromosome start location must be 1 or greater") ;
      return false ;
    }
    if(stop && stop > chromLengths.get(ep))
    {
      alert("The chromosome stop location can not be greater than " + chromLengths.get(ep) + " for chromosome '" + ep + "'.\nThis will be corrected for you.") ;
      $("landmark").value = ep + ":" + start + "-" + chromLengths.get(ep) ;
      return false;
    }

  }

  for(var ii=0; ii<trackBoxes.length; ii++)
  {
    if(trackBoxes[ii].checked)
    {
      numChecked += 1 ;
    }
  }
  // Is at least one track clicked?
  if(numChecked < 1 && !includeOtherSections.checked)
  {
    alert("You must select at least one track to download.") ;
    return false ;
  }
  else if(numChecked > 5) // Are too many tracks clicked, warn?
  {
    var lotsOK = confirm( "WARNING: you have " +
                          numChecked +
                          " tracks selected for download.\n\nThis could be a large amount of data and may take a while to complete.\n\nContinue anyway?") ;
    if(!lotsOK)
    {
      return false ;
    }
  }
  // Dialog about saving file/browsers.
  alert("NOTE: depending on the amount of data, the download may take some time to start. The download will be throttled.\n\nNOTE: Please 'SAVE' the LFF file rather than opening it, since your computer probably won't have an application for opening LFF files.\n\nDepending on your browser, you should make sure the file name makes sense (e.g. Internet Explorer 6 has a bug where the download file will have an inappropriate name, rather than our suggested name).");
  return true ;
}

function selectCoreChrs()
{
  var chrCneckBoxes = document.getElementsByName('epId') ;
  for(var ii=0; ii<chrCneckBoxes.length; ii++)
  {
    if(!(chrCneckBoxes[ii].value.indexOf("_") > 0))
    {
      chrCneckBoxes[ii].checked = true ;
    }
  }
}

function selectAllChrs(status)
{
  var chrCneckBoxes = document.getElementsByName('epId') ;
  for(var ii=0; ii<chrCneckBoxes.length; ii++)
  {
    chrCneckBoxes[ii].checked = status ;
  }
}

/**
 *
 * Dependencies:
 *   - ExtJS 2.2
 *     Since the popup dialog is an ExtJS dialog, that must be included by
 *     whatever file includes this .js file.
 */
var helpMessages = {
  'entryPoints' : {
    'title' : 'Help: Entry Points',
    'text' : '<p>Indicate the region that you would like to download.</p>' +
             '<p class="helpWindow">For a single chromosome, use a landmark to specify a region of a chromosome. </p>' +
             'Landmark Examples: <ul>' +
             '<li>chr1</li>' +
             '<li>chr1:100000000</li>' +
             '<li>chr1:100000000-</li>' +
             '<li>chr1:-200000000</li>' +
             '<li>chr1:100000000-200000000</li>' +
             '</ul>' +
             '<p class="helpWindow">If a database contains a small number of entry points, all entry points will be listed. Check the checkbox to download a specific entry point. </p>' +
             '<p class="helpWindow">If a database contains a large set of entry points, you may download All the entrypoints.</p>   '




  },
  'fileFormat' : {
    'title' : 'Help: File Format',
    'text' : '<p class="helpWindow">Select the desired annotation file format. ' +
             'Some track types may not support the chosen format and will be disabled below if there is a conflict. </p>' +
             '<p class="helpWindow">For more information about the file formats, see the links below.</p>' +
             '<ul>' +
             '<li><a HREF="showHelp.jsp?topic=lffFileFormat" target="_helpWin">LFF Annotation Format</a></li>' +
             '<li><a href="http://genome.ucsc.edu/FAQ/FAQformat#format1" target="_helpWin">Bed</a></li>' +
             '<li><a href="http://genome.ucsc.edu/goldenPath/help/bedgraph.html" target="_helpWin">BedGraph</a></li>' +
             '<li><a href="http://genome.ucsc.edu/goldenPath/help/wiggle.html" target="_helpWin">Wiggle</a></li>' +
             '</ul>'

  },
  'availableTracks' : {
    'title' : 'Help: Available Tracks',
    'text' : '<p class="helpWindow">Below is the list of tracks which are available for download.</p>' +
             '<p class="helpWindow">Some tracks may not be available for certain annotation file fomats and will be disabled.</p>'
  }
} ;

function checkAll()
{
	var elems = document.getElementsByName('trkId') ;
	var i ;
	for( i=0 ; i<elems.length ; i++ )
	{
    if(!elems[i].disabled)
    {
      elems[i].checked = true ;
    }
	}
}

function clearAll()
{
	var elems = document.getElementsByName('trkId') ;
	var i ;
	for( i=0 ; i<elems.length ; i++ )
	{
		elems[i].checked = false ;
	}
}

function setHdhvTracks(disable, msg)
{
  setTracks(trkTypesHdhv, disable, msg) ;
}

function setFdataTracks(disable, msg)
{
  setTracks(trkTypesFdata, disable, msg) ;
}

function setTracks(trackArr, disable, msg)
{
  for(var ii=0; ii<trackArr.length; ii++)
  {
    if(disable)
    {
      disableTrack(trackArr[ii], msg) ;
    }
    else
    {
      enableTrack(trackArr[ii], msg) ;
    }
  }
}

function enableTrack(id, msg)
{
  $(id).disabled = false ;
  $(id + '_div').onclick = "" ;
  $(id + '_div').style.color = '#403C59' ;
}

function disableTrack(id, msg)
{
  $(id).checked = false ;
  $(id).disabled = true ;
  fnc = "alert('" + msg + "')" ;
  $(id + '_div').onclick = Function(fnc) ;
  $(id + '_div').style.color = '#AAAAAA' ;
}

/**
 * Display a popup dialog with the specified title and help string.  The title
 * will default to "Help" if it was not passed to the function.
 * @param button
 *   The button that was pressed to generate this dialog (for position).
 * @param text
 *   The help text to display in the main body of the dialog.
 * @param title
 *   (optional) The title of the help dialog.  Defaults to "Help".
 */
function displayHelpPopup(button, text, title)
{
  if(!title)
  {
    title = "Help" ;
  }

  Ext.Msg.show(
  {
    title: title,
    msg : text,
    height: 120,
    width: 385,
    minHeight: 100,
    minWidth: 150,
    modal: false,
    proxyDrag: true
  }) ;
  Ext.Msg.getDialog().setPagePosition(Ext.get(button).getX() + 25, Ext.get(button).getY() + 25) ;
  return false ;
}
