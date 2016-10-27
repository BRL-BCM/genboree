
// This file requires the following globals to be available on the web page:
// - trackAccessData
// This file makes use of the following 3rd party libraries:
// - prototype.js
// - json2.js


String.prototype.trim = function() {
	return this.replace(/^\s+|\s+$/g,"");
}

String.prototype.isEmpty = function() {
  return (this.trim() == "")
}

function trackChanged(selectObj, trackAccessData)
{
  var classRe = new RegExp("\\s*userCheck\\s*") ;
  var selectIdx = selectObj.selectedIndex;
  var selectOption = selectObj.options[selectIdx] ;
  var selectOptionValue = selectOption.value ;
  var inputs = document.getElementsByTagName('input') ;
  if(selectOptionValue == '----Select a Track----') // then clear & disable checkboxes
  {
    for(var ii=0; ii < inputs.length; ii++)
    {
      if(classRe.test(inputs[ii].className))
      {
        inputs[ii].checked = false ;
        inputs[ii].disabled = true ;
      }
    }
  }
  else // real track selected
  {
    // get track name (needs to be url escaped for trackAccessData) ?
    var trackName = selectOptionValue.unescapeHTML() ;
    var escTrackName = escape(trackName) ;
    // do we have any users with specific access to this?
    var someUserRestrictions = false ;
    trackAccessData[escTrackName].each( function(entry)
                                        {
                                          if(entry.value == true)
                                          {
                                            someUserRestrictions = true ;
                                            throw $break ;
                                          }
                                          return ;
                                        }
                                      ) ;
    for(var ii=0;ii < inputs.length; ii++)
    {
      if(classRe.test(inputs[ii].className))
      {
        // go through each input, get username, look up access and set accordingly
        inputs[ii].disabled = false ;
        if(someUserRestrictions) // check users according to trackAccessData entry
        {
          var userName = inputs[ii].value.unescapeHTML() ;
          var escUserName = escape(userName) ;
          inputs[ii].checked = trackAccessData[escTrackName][escUserName] ;
        }
        else // no user restrictions, all have access; so check all the inputs
        {
          inputs[ii].checked = true ;
        }
      }
    }
  }
  return true ;
}

function selectUsers(doCheck)
{
  var classRe = new RegExp("\\s*userCheck\\s*") ;
  var selectObj = $('trackName') ;
  var selectIdx = selectObj.selectedIndex ;
  var selectOption = selectObj.options[selectIdx] ;
  var selectOptionValue = selectOption.value ;
  var inputs = document.getElementsByTagName('input') ;

  if(selectOptionValue != '----Select a Track----') // then ok to alter user selections
  {
    for(var ii=0; ii < inputs.length; ii++)
    {
      if(classRe.test(inputs[ii].className))
      {
        inputs[ii].checked = doCheck ;
        inputs[ii].disabled = false ;
      }
    }
  }
  return true ;
}

function selectNoUsers()
{
  return selectUsers(false) ;
}

function selectAllUsers()
{
  return selectUsers(true) ;
}

function submitForm(form, event)
{
  var retVal = true ;
  var classRe = new RegExp("\\s*userCheck\\s*") ;
  var selectObj = $('trackName') ;
  var selectIdx = selectObj.selectedIndex ;
  var selectOption = selectObj.options[selectIdx] ;
  var selectOptionValue = selectOption.value ;
  var trackName = selectOptionValue.unescapeHTML() ;

  if(selectOptionValue == '----Select a Track----')
  {
    alert("ERROR: Please select a track and determine appropriate accesses before submitting.") ;
    retVal = false ;
  }
  else
  {
    // Check that at least one checkbox is checked
    var numUsersSelected = 0 ;
    var numUsers = 0 ;
    var classRe = new RegExp("\\s*userCheck\\s*") ;
    var inputs = document.getElementsByTagName('input') ;
    for(var ii=0; ii < inputs.length; ii++)
    {
      if(classRe.test(inputs[ii].className))
      {
        numUsers += 1 ;
        if(inputs[ii].checked)
        {
          numUsersSelected += 1 ;
        }
      }
    }

    if(numUsersSelected <= 0)
    {
      alert("ERROR: At least one user must have access to the track.\n(Delete the track if you don't want it any more).") ;
      retVal = false ;
    }
    else
    {
      // Are all selected? If so, pass special flag for removing all access limits to track.
      var removeAllLimits = false ;
      var allSelected = (numUsersSelected == numUsers) ;
      if(allSelected)
      {
        removeAllLimits = confirm("You have given all users access to this track.\nThis will remove ALL access limits on the track.\n\nProceed?") ;
      }
      // Proceed if some selected or removing all limits
      if(!allSelected || (allSelected && removeAllLimits))
      {
        var accessForm = $('trackAccessControl') ;
        var userCheckDataObj = $('userCheckData') ;
        var accessJson = makeAccessDataJSON(trackName, removeAllLimits) ;
        userCheckDataObj.value = accessJson ;
        // Remove buttons and all check boxes and then submit
        cleanForm() ;
        accessForm.submit() ;
      }
      else
      {
        retVal = false ;
      }
    }
  }
  return retVal ;
}

function makeAccessDataJSON(trackName, removeAllLimits)
{
  var classRe = new RegExp("\\s*userCheck\\s*") ;
  var selectObj = $('trackName') ;
  var escTrackName = encodeURIComponent(trackName) ;
  var inputs = document.getElementsByTagName('input') ;
  var dataObj = {} ;
  dataObj.track = escTrackName ;
  dataObj.removeAllAccessLimits = removeAllLimits ;
  dataObj.userAccess = [] ;
  for(var ii=0; ii < inputs.length; ii++)
  {
    if(classRe.test(inputs[ii].className))
    {
      var userName = inputs[ii].value.unescapeHTML() ;
      var escUserName = encodeURIComponent(userName) ;
      dataObj.userAccess.push(  {
                                  'userName' : escUserName,
                                  'access' : inputs[ii].checked
                                }) ;
    }
  }
  return JSON.stringify(dataObj) ;
}

function cleanForm()
{
  // Buttons
  Element.remove('all') ;
  Element.remove('none') ;
  // User checkboxes
  var classRe = new RegExp("\\s*userCheck\\s*") ;
  var inputs = document.getElementsByTagName('input') ;
  var inputIds = [] ;
  for(var ii=0; ii < inputs.length; ii++)
  {
    if(classRe.test(inputs[ii].className))
    {
      inputIds.push(inputs[ii].id) ;
    }
  }
  inputIds.each(  function(item)
                  {
                    Element.remove(item) ;
                  }) ;
  return true ;
}
