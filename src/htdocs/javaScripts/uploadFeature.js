//
// Uses extjs library
//
//
// Make a namespace where our functions will live (like a module)
Ext.namespace('Ext.genboree');

// Define the module, its internal variables, and functions
Ext.genboree = function()
{
  var xtraParams =  [ "blat", "blast", "agilent", "wig" ] ;
  var xtraRow ; // Prepared row with extra parameters
  var xtraCell ; // Prepared cell with extra parametes
  var confirmBox ;
  var waitingForDialog = false ;
  var confirmedLongTrackOK = false ;
  var confirmedExistingTrackOK = false ;
  var needAnswer = 'no' ; // Or 'longTrackName', 'existingTrackName'

  // Return a hash of named-functions for adding a new record or getting the whole reocrd array
  return  {
            init: function()
            {
              // Init the special param row
              Ext.genboree.createXtraRow() ;
              // Init the body for masking
              var bodyElem = Ext.get('wholePage') ;
              if(bodyElem)
              {
                bodyElem.className = "ext-gecko x-body-masked";
              }
            },
            createXtraRow: function()
            {
              // Pre-create the extra table row that has the format-specific parameters.
              // The whole extra row:
              xtraRow = document.createElement("tr") ;
              xtraRow.id = xtraRow.name = "paramsRow" ;
              Element.extend(xtraRow) ;
              xtraRow.hide() ;
              // The header cell for the row:
              var xtraHeader = document.createElement("td") ;
              Element.extend(xtraHeader)
              xtraHeader.addClassName('form_body') ;
              xtraHeader.style.width = "18%" ;
              xtraHeader.update('<b>Format Conversion Parameters</b>') ;
              xtraRow.appendChild(xtraHeader) ;
              // The parameter cell:
              xtraCell = document.createElement("td") ;
              Element.extend(xtraCell) ;
              xtraCell.id = xtraCell.name = 'paramCell' ;
              xtraCell.addClassName('form_body') ;
              xtraCell.style.width = "81%" ;
              // The parameter div (actually removed then re-added as options are clicked)
              var xtraDiv = document.createElement("div") ;
              Element.extend(xtraDiv) ;
              xtraDiv.id = xtraDiv.name = "paramDiv" ;
              xtraCell.appendChild(xtraDiv) ;
              xtraRow.appendChild(xtraCell) ;
              // Add the xtraRow to the table (should be invisible)
              var tbody = $('uploadUItable') ;
              tbody.appendChild(xtraRow) ;
            },
            setWaitingForDialog: function(answer)
            {
              return (waitingForDialog = answer) ;
            },
            getWaitingForDialog: function()
            {
              return waitingForDialog ;
            },
            setConfirmedExistingTrackOK:  function(answer)
            {
              Ext.genboree.setWaitingForDialog(false) ;
              confirmedExistingTrackOK = (answer == 'yes') ;
            },
            getConfirmExistingTrackOK:  function(answer)
            {
              return confirmedExistingTrackOK ;
            },
            setConfirmedLongTrackOK:  function(answer)
            {
              Ext.genboree.setWaitingForDialog(false) ;
              confirmedLongTrackOK = (answer == 'yes') ;
            },
            getConfirmLongTrackOK:  function(answer)
            {
              return confirmedLongTrackOK ;
            },
            getNeedAnswer: function()
            {
              return needAnswer ;
            },
            setNeedAnswer: function(need)
            {
              return (needAnswer = need) ;
            },
            showAlert: function(title, msg, activateElement)
            {
              var callBack ;
              if(activateElement)
              {
                callBack =  function()
                            {
                              Ext.genboree.setWaitingForDialog(false) ;
                              activateElement.activate() ;
                            } ;
              }
              else
              {
                callBack =  function()
                            {
                              Ext.genboree.setWaitingForDialog(false) ;
                            } ;
              }

              Ext.Msg.show( {
                              title: title,
                              msg: msg,
                              buttons: Ext.Msg.OK,
                              width: 375,
                              fn: callBack
                            }
                          );
              Ext.genboree.setWaitingForDialog(true) ;
            }
          };
}();
// When most of the document resources are ready, call the init() function
// of the Ext.genboree module
Ext.onReady(Ext.genboree.init, Ext.genboree, true);

// --------------------------------------------------------------------------
// Helper functions
// --------------------------------------------------------------------------
// When user finishes entering type:subtype, this function is called to update the
// track name hint text, and color it red if too long
function updateTrackName()
{
  var paramDiv = $('paramDiv') ;
  if(paramDiv)
  {
    var lffType = $('type') ;
    var lffSubtype = $('subtype') ;
    var trackSpan = $('trackNameSpan') ;
    if( (lffSubtype.value.length + lffType.value.length > 18) || (lffSubtype.value.indexOf(":") >= 0) || (lffType.value.indexOf(":") >= 0))
    {
      trackSpan.style.color = 'red' ;
    }
    else
    {
      trackSpan.style.color = 'black' ;
    }
    trackSpan.update( lffType.value + ':' + lffSubtype.value ) ;
  }
  // Regardless, clear any OK about the entered track
  Ext.genboree.setConfirmedExistingTrackOK(false) ;
  Ext.genboree.setConfirmedLongTrackOK(false) ;
  return ;
}

// For formats needing track names
function makeTrackDivStr(classDef, typeDef, subtypeDef)
{
  return  '<div width="100%" style="white-space: nowrap;" >' +
            'Track&nbsp;Class&nbsp;<input id="class" name="class" type="text" size="4" value="' + classDef + '">&nbsp;&nbsp;&nbsp;' +
            'Track&nbsp;Type&nbsp;<input id="type" name="type" type="text" size="6" value="' + typeDef + '" onchange="updateTrackName();">&nbsp;&nbsp;&nbsp;' +
            'Track&nbsp;Subtype&nbsp;<input id="subtype" name="subtype" type="text" size="6" value="' + subtypeDef + '" onchange="updateTrackName();">&nbsp;' +
          '</div>' +
          '<div width="100%" style="margin-top: 5px; white-space: nowrap; text-align: center; ">' +
            '(track name will be: <span id="trackNameSpan" name="trackNameSpan" style="font-weight: bold;">' + typeDef + ':' + subtypeDef + '</span>)' +
          '</div>' ;
}

// For wiggle uploader
function makeTrackDivStrForWig(typeDef, subtypeDef)
{
  return  '<div width="100%" style="white-space: nowrap;" >' +
            'Track&nbsp;Type&nbsp;<input id="type" name="type" type="text" size="10" value="' + typeDef + '" onchange="updateTrackName();">&nbsp;&nbsp;&nbsp;' +
            'Track&nbsp;Subtype&nbsp;<input id="subtype" name="subtype" type="text" size="10" value="' + subtypeDef + '" onchange="updateTrackName();">&nbsp;' +
          '</div>' +
          '<div width="100%" style="margin-top: 5px; white-space: nowrap; text-align: center; ">' +
            '(track name will be: <span id="trackNameSpan" name="trackNameSpan" style="font-weight: bold;">' + typeDef + ':' + subtypeDef + '</span>)' +
          '</div>' ;
}

// Called when user selects a new format...displays appropriate UI.
function formatChanged(selectObj)
{
  // See which options what selected
  var options = selectObj.options ;
  var selectedIdx = selectObj.selectedIndex ;
  var selectedValue = options[selectedIdx].value ;
  // Get whole paramsRow
  var paramsRow = $('paramsRow') ;
  // Get paramCell
  var paramCell = $('paramCell') ;
  // Remove existing paramDiv
  var paramDiv = $('paramDiv')
  if(paramDiv)
  {
    paramDiv.remove() ;
  }
  // Dispatch based on what option was selected
  if(selectedValue == 'lff')
  {
    paramsRow.hide() ;
  }
  else if(selectedValue == 'blat')
  {
    // Make a new paramDiv with correct form fields and such
    paramDiv = document.createElement("div") ;
    Element.extend(paramDiv) ;
    paramDiv.id = paramDiv.name = 'paramDiv' ;
    paramDiv.update( makeTrackDivStr('Hits', 'Blat', 'Hit') ) ;
  }
  else if(selectedValue == 'wig')
  {
    // Make a new paramDiv with correct form fields and such
    paramDiv = document.createElement("div") ;
    Element.extend(paramDiv) ;
    paramDiv.id = paramDiv.name = 'paramDiv' ;
    paramDiv.update(makeTrackDivStrForWig('hdhvTrack', '1'));

  }
  else if(selectedValue == 'blast')
  {
    // Make a new paramDiv with correct form fields and such
    paramDiv = document.createElement("div") ;
    Element.extend(paramDiv) ;
    paramDiv.id = paramDiv.name = 'paramDiv' ;
    paramDiv.update( makeTrackDivStr('Hits', 'Blast', 'Hit') ) ;
  }
  else if(selectedValue == 'agilent')
  {
    // Make a new paramDiv with correct form fields and such
    paramDiv = document.createElement("div") ;
    Element.extend(paramDiv) ;
    paramDiv.id = paramDiv.name = 'paramDiv' ;
    paramDiv.update(
                    makeTrackDivStr('Agilent', 'Agilent', 'Probe') +
                    // format-specific params:
                    '<hr width="100%">' +
                    '<div width="100%" style="white-space: nowrap;" >' +
                      '<div style="float: left; width: 60%; height: 22px; padding-top: 2px; margin-right: 5px;">Auto-create histogram tracks?</div>' +
                      '<div style="float: left; width: 20%; height: 22px;"><input id="histChk" name="histChk" type="checkbox" style="margin-left: 0px;"></div>' +
                      '<input id="throttleChk" name="throttleChk" type="checkbox" checked="yes" style="visibility: hidden;">' +
                      '<br clear="all">' +
                      '<div style="float: left; width: 60%; height: 22px; padding-top: 2px; margin-right: 5px;">Perform segmentation analysis?</div>' +
                      '<div style="float: left; width: 20%; height: 22px;"><input id="doSeg" name="doSeg" type="checkbox" onchange="toggleSegmentation(this);" style="margin-left: 0px;"></div>' +
                      '<br clear="all">' +
                      '<div style="float: left; width: 60%; height: 22px; padding-top: 2px; margin-right: 5px;">Minimum # probes per segment:</div>' +
                      '<div style="float: left; width: 12%; height: 22px;"><input id="minProbes" name="minProbes" type="text" value="" size="3" onchange="checkMinProbes();" disabled></div>' +
                      '<br clear="all">' +
                      '<div style="float: left; width: 60%; height: 22px; margin-right: 5px;">Segment Log-Ratio Threshold:</div>' +
                      '<div style="float: left; width: 12%; height: 22px; "><input id="segment" name="segment" type="text" value="" size="3" onchange="checkSegmentRatio();" disabled></div>' +
                      '<br clear="all">' +
                      '<div style="float:left; width:5%; vertical-align:top; font-size: 7pt;">' +
                        '<input type="radio" id="thresholdType" name="thresholdType" value="stdev" checked disabled>' +
                        '<br>&nbsp;<br>' +
                        '<input type="radio" id="thresholdType" name="thresholdType" value="absolute" disabled>' +
                      '</div>' +
                      '<div style="float:left; width:94%; line-height:135%; font-size: 7pt;">' +
                        'as how many standard deviations from the global average log-ratio<br>the segment must be <i>OR</i><p>' +
                        'as an absolute threshold the mean log-ratio must exceed' +
                      '</div>' +
                      // ARJ: not providing this for now: '<div style="float: left; width: 60%; height: 22px; margin-right: 5px;">Probe Log-Ratio Threshold:</div>' +
                      // '<div style="float: left; width: 12%; height 22px; "><input id="gainloss" name="gainloss" type="text" size="3" onchange="checkLogRatioField();" ></div>' +
                    '</div>' +
                    '<input type="hidden" id="segmentThresh" name="segmentThresh" value="">' +
                    '<input type="hidden" id="segmentStddev" name="segmentStddev" value="">'
                  ) ;
  }
  else if(selectedValue == 'pash')
  {
    // Make a new paramDiv with correct form fields and such
    paramDiv = document.createElement("div") ;
    Element.extend(paramDiv) ;
    paramDiv.id = paramDiv.name = 'paramDiv' ;
    paramDiv.update( makeTrackDivStr('Hits', 'Pash', 'Hit') ) ;
  }

  paramCell.appendChild(paramDiv) ;
  var coverDiv = document.createElement("div") ;
  Element.extend(coverDiv) ;
  coverDiv.id = coverDiv.name = 'coverDiv' ;
  paramCell.appendChild(coverDiv) ;
  coverDiv.hide() ;
  if(selectedValue != 'lff')
  {
    paramsRow.show() ;
  }
  // Regardless, clear any OK about the entered track
  Ext.genboree.setConfirmedExistingTrackOK(false) ;
  Ext.genboree.setConfirmedLongTrackOK(false) ;
  return ;
}

function toggleSegmentation(checkbox)
{
  var status = !checkbox.checked ;
  $('segment').disabled = status ;
  $('minProbes').disabled = status ;
  var radios = document.getElementsByName('thresholdType') ;
  for(var ii=0; ii<radios.length; ii++)
  {
    radios[ii].disabled = status;
  }
  $('minProbes').value = (checkbox.checked ? "2" : "") ;
  $('segment').value = (checkbox.checked ? "2.0" : "") ;
  return ;
}

function checkLogRatioField()
{
  var logRatio = $('gainloss') ;
  if(logRatio)
  {
    logRatio.style.color = 'black' ;
    if(! /^\s*$/.test(logRatio.value) )
    {
      var logRatioValue = logRatio.value.strip() ;

      if( ! /^\+?\d*(?:\.\d+)?(?:(?:e|E)(?:\+|\-)?\d+)?$/.test(logRatioValue))
      {
        logRatio.style.color = 'red' ;
        return false ;
      }
    }
  }
  return true ;
}

function checkMinProbes()
{
  var minProbes = $('minProbes') ;
  if(minProbes)
  {
    var minProbesValue = minProbes.value.strip() ;
    if( (minProbesValue.length > 0) && (! /^\+?\d+$/.test(minProbesValue)))
    {
      minProbes.style.color = 'red' ;
      return false ;
    }
    else
    {
      minProbes.style.color = 'black' ;
    }
  }
  return true ;
}

function checkSegmentRatio()
{
  var segRatio = $('segment') ;
  if(segRatio)
  {
    var segRatioValue = segRatio.value.strip() ;

    if( ! /^\+?\d*(?:\.\d+)?(?:(?:e|E)(?:\+|\-)?\d+)?$/.test(segRatioValue) || /^\s+$/.test(segRatio.value))
    {
      segRatio.style.color = 'red' ;
      return false ;
    }
    else
    {
      segRatio.style.color = 'black' ;
    }
  }
  return true ;
}

// Functions for wig uploading
function checkTrackName()
{
  var trackName = $('trackName') ;
  if(!trackName.match(":"))
  {
    return false;
  }
  else{
    return true;
  }
}

function checkRecordType()
{
  var recordType = $('recordType') ;
  if(recordType.match("int8Score") != null || recordType.match("int16Score") != null || recordType.match("floatScore") != null || recordType.match("doubleScore") != null)
  {
    return true;
  }
  else
  {
    return false;
  }
}

function toggleWiggle(checkbox)
{
  var status = !checkbox.checked ;
  $('trackName').disabled = status ;
  $('recordType').disabled = status ;
  $('trackName').value = (checkbox.checked ? "hdhvTrack:1" : "") ;
  $('recordType').value = (checkbox.checked ? "floatScore" : "") ;
  return ;
}

// --------------------------------------------------------------------------
// Older code for uploadFeature.jsp page.
// --------------------------------------------------------------------------
upload_started = false ; // global

function reallyCheck(chkBox, dialogMessage)
{
  var retVal = true ;
  if(chkBox.checked)
  {
    retVal = confirm(dialogMessage) ;
    if(!retVal) // Uncheck the box because they said 'no'
    {
      chkBox.checked = false ;
    }
  }
  return retVal ;
}

function uploadFormSubmitIt()
{
            
  var uploadForm = $('norm') ;
  var waitingForDialog = Ext.genboree.getWaitingForDialog() ;
  var needAnswer ;
  var confirmedLongTrackOK ;
  var confirmedExistingTrackOK ;
  // If we're waiting on an answer from a confirm dialog still, return after setting polling.
  if(waitingForDialog)
  {
    // Check again to see it's answered in a little bit.
    return false ;
  }
  else // We either are calling this the first time or may have the answer we need to proceed further in this function
  {
    needAnswer = Ext.genboree.getNeedAnswer() ;
    confirmedLongTrackOK = Ext.genboree.getConfirmLongTrackOK() ;
    confirmedExistingTrackOK = Ext.genboree.getConfirmExistingTrackOK() ;
  }

  // Make sure we have a file to upload, etc.
  if( (needAnswer == 'no') && (uploadForm.upload_file.value == "") && (uploadForm.paste_data.value == "") )
  {
    Ext.genboree.showAlert( "Error", "You didn't specify upload file!", $('upload_file') ) ;
    return false;
  }
  // Validate extra params if present
  var paramDiv = Ext.get('paramDiv') ;
  if(paramDiv && paramDiv.dom.innerHTML != null && paramDiv.dom.innerHTML != "" )
  {

    // ALL extra formats: Check that track name not too long.
    var lffType = $('type') ;
    var lffSubtype = $('subtype') ;
    var nameLen = lffType.value.length + lffSubtype.value.length ;
    
    if( (needAnswer == 'no') && (nameLen > 18) && !confirmedExistingTrackOK )
    {
      var trackSpan = $('trackNameSpan') ;
      trackSpan.style.color = 'red' ;
      // If so, show dialog asking if it's ok to load data into track with too long a name
      // We need to block going any further until answer is given.
      Ext.Msg.show( {
                      title:  'Track Exists',
                      msg:    "Your track name is too long.<br><br>" +
                              "It is " + nameLen + " letters long and will be truncated.<br>" +
                              "A track name length under 19 letters is recommended.<br><br>" +
                              "Do you want to proceed anyway?",
                      buttons: Ext.Msg.YESNO,
                      width: 375,
                      fn: function(btn)
                          {
                            Ext.genboree.setConfirmedLongTrackOK(btn) ;
                            if(btn == 'no')
                            {
                              $('type').activate() ;
                            }
                            // Call submit-validation function, which has been waiting for us
                            uploadFormSubmitIt() ;
                          }
                    }
                  );
      // Now waiting on an answer to this dialog
      Ext.genboree.setWaitingForDialog(true) ;
      // We need an answer to our question before proceeding further
      Ext.genboree.setNeedAnswer('longTrackName') ;
      return false ;
    }
    else if(lffType.value.indexOf(":") >= 0)
    {
      Ext.genboree.showAlert( "Error",
                              "The track type cannot contain the ':' character, which is the track type:subtype separator.",
                              $('type')
                              );
      return false ;
    }
    else if(lffSubtype.value.indexOf(":") >= 0)
    {
      Ext.genboree.showAlert( "Error",
                              "The track subtype cannot contain the ':' character, which is the track type:subtype separator.",
                              $('subtype')
                              );
      return false ;
    }
    else if( needAnswer == 'longTrackName' ) // then we've been waiting on this answer
    {
      Ext.genboree.setNeedAnswer('no') ;
      if(!confirmedLongTrackOK)
      {
        return false ;
      }
    }

    // Format type selected?
    var options = $('ifmt').options ;
    var selectedIdx = $('ifmt').selectedIndex ;
    var selectedValue = options[selectedIdx].value ;
    

     //See which options what selected
  
    // Check stuff common to all non-LFF upload formats
    if(selectedValue != 'lff')
    {
      if(needAnswer == 'existingTrackName') // We've been waiting on this answer
      {
        Ext.genboree.setNeedAnswer('no') ;
        // If Yes, continue; else stop validating and return to page.
        if(!confirmedExistingTrackOK)
        {
          return false ;
        }
      }
      else // Not waiting on an answer, check if track exists
      {
        // Get the track name they chose, URL Encoded.
        var userTrackEncoded = escape(lffType.value).gsub(/\+/, "%2B") + ":" + escape(lffSubtype.value).gsub(/\+/, "%2B") ;
        // Check if track name is already present.
        // -- ASSUMES the page has the variable 'jsTrackMap' set up as a Prototype Hash
        // For non-wig uploads
        if(selectedValue != 'wig')
        {  
          if( (needAnswer == 'no') && jsTrackMap[userTrackEncoded] && !confirmedExistingTrackOK )
          {
            // If so, show dialog asking if it's ok to load data into existing track.
            // We need to block going any further until answer is given.
            Ext.Msg.show( {
                            title:  'Track Exists',
                            msg:    "The track you provided, '" + unescape(userTrackEncoded) + "', already exists.<br><br>" +
                                    "Do you want to add this data to the existing track?",
                            buttons: Ext.Msg.YESNO,
                            width: 375,
                            fn: function(btn)
                                {
                                  Ext.genboree.setConfirmedExistingTrackOK(btn) ;
                                  if(btn == 'no')
                                  {
                                    $('type').activate() ;
                                  }
                                  // Call submit-validation function, which has been waiting for us
                                  uploadFormSubmitIt() ;
                                }
                          }
                        );
            // Now waiting on an answer to this dialog
            Ext.genboree.setWaitingForDialog(true) ;
            // We need an answer to our question before proceeding further
            Ext.genboree.setNeedAnswer('existingTrackName') ;
            return false ;
          }
        }
        // Adding data to an existing track for wig data not allowed for now
        // Throw exception if track exists 
        else
        {
          if( (needAnswer == 'no') && jsTrackMap[userTrackEncoded] && !confirmedExistingTrackOK )
          {
            Ext.genboree.showAlert( "Error",
                              "The track you provided, '" + unescape(userTrackEncoded) + "',  already exists. <br><br>" +
                              "Adding data to an existing track is not allowed."
                              );
            return false ;
          } 
        }
      }
    }

    // Check agilent-specific sutff
    if(selectedValue == 'agilent')
    {
      // Validate minProbes
      var minProbesOK = checkMinProbes() ;
      var minProbesValueLength = $('minProbes').value.strip().length ;
      var doSeg = $('doSeg').checked ;
      if($('minProbes') && doSeg)
      {
        if(!minProbesOK || minProbesValueLength <= 0 || $('minProbes').value < 2)
        {
          Ext.genboree.showAlert( "Error",
                                  "The Mininum # Probes Per Segment must be non-blank and must be a positive integer greater than 2 (at least 2 are needed for a segment).",
                                  $('minProbes')
                                );
          return false ;
        }
      }
      // Validate gainloss
      var probeRatioOk = checkLogRatioField() ;
      if($('gainloss'))
      {
        if(!probeRatioOk)
        {
          Ext.genboree.showAlert( "Error",
                                  "The Probe Log-Ratio Threshold defining the gain/loss log-ratio magnitude " +
                                  "must be a positive integer or positive real number.",
                                  $('gainloss')
                                );
          return false ;
        }
      }
      // Validate segment
      var segmentRatioOk = checkSegmentRatio() ;
      var segmentValueLength = $('segment').value.strip().length  ;
      if($('segment') && doSeg)
      {
        if(!segmentRatioOk || segmentValueLength <= 0 || $('segment').value < 2)
        {
          Ext.genboree.showAlert( "Error",
                                  "The Segment Log-Ratio Threshold defining the minimum mean log ratio " +
                                  "must be non-blank and must be a positive integer or positive real number.",
                                  $('segment')
                                );
          return false ;
        }
      }
      // If everything ok, remove blank text inputs...REQUIRED!!
      if(minProbesOK && probeRatioOk && segmentRatioOk)
      {
        // ARJ: Probe filtering turned off right now
        // var logRatioValue = $('gainloss').value ;
        // if(logRatioValue == '')
        // {
        //   $('gainloss').remove() ; // it's blank, don't send it at all
        // }
        var logRatioValue = $('segment').value ;
        if(logRatioValue == '')
        {
          $('segment').remove() ; // it's blank, don't send it at all
        }
      }
      // Set histogram, remove chkbox from form
      var histChkbx = $('histChk') ;
      if(histChkbx)
      {
        if(histChkbx.checked)
        {
          // Replace the check box with a new special element.
          histChkbx.replace('<input id="histogram" name="histogram" type="hidden" value="genbCheckboxOn">') ;
        }
      }
      // Setup throttle hidden flag to send to converter
      var throttleChkbx = $('throttleChk') ;
      if(throttleChkbx)
      {
        // Replace the check box with a new special element
        throttleChkbx.replace("<input id='throttle' name='throttle' type='hidden' value='genbCheckboxOn' />") ;
      }

      if(segmentValueLength > 0 && segmentRatioOk)
      {
        // Based on thresholdType, remove the 'segment' element and put value in either
        // segmentThresh or segmentStddev hidden input, removing the other & the segment field
        var segmentValue = $('segment').value ;
        // Find the threshold type
        var thresholdType ;
        var radios = document.getElementsByName('thresholdType') ;
        for(var ii=0; ii<radios.length; ii++)
        {
          if(radios[ii].checked)
          {
            thresholdType = radios[ii].value ;
            break ;
          }
        }
        if(thresholdType == 'absolute') // then using regular thresholding
        {
          $('segmentThresh').value = segmentValue ;
          $('segmentStddev').remove() ;
        }
        else // using stddev default
        {
          $('segmentStddev').value = segmentValue ;
          $('segmentThresh').remove() ;
        }
        $('segment').remove() ;
        // Warn about maybe no segments.
        Ext.genboree.showAlert( "Error",
                                "NOTE: it is possible NO segments will be detected, " +
                                "depending on the uploaded data &amp; parameters." );
      }
    }
    
    // Now, hide the paramDiv to avoid people getting confused by UI changes
    paramDiv.hide() ;
    paramDiv.applyStyles('height: 0px;') ;
    var coverDiv = Ext.get('coverDiv') ;
    coverDiv.update("<i>Parameters Sent to Server.</i>") ;
    coverDiv.show() ;
    coverDiv.applyStyles('width: 100%; text-align: center;') ;
    coverDiv.center(Ext.get('paramCell')) ;
  }
  // Get ready to upload the file...
  uploadForm.origFileName.value = uploadForm.upload_file.value;
  if( upload_started )
  {
    return true;
  }
  upload_started = true ;
  
  displayLoadingMsg(ProgressUpload.getLoadingMsgDiv());
  var redirectUrl = location.protocol + '//' + location.host + '/java-bin/merger.jsp?fileName=' + encodeURIComponent(uploadForm.upload_file.value);    
  ProgressUpload.startUpload(document.norm, null, redirectUrl);  
  
  return false;
}

function displayLoadingMsg(loadingMsgDiv) {
  maskDiv = $('genboree-loading-mask') ;
  maskDiv.style.visibility = "visible" ;
  loadMsgDiv = $('genboree-loading') ;
  loadMsgDiv.innerHTML = '<div class="genboree-loading-indicator" style="height:100px;">'+loadingMsgDiv+ '</div>';
  loadMsgDiv.style.visibility = "visible" ;
  loadMsgDiv.style.width = "430px" ;
  loadMsgDiv.style.left = "30%" ;
}

