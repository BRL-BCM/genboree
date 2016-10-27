/**
 * Sets input elements to values that were submitted
 */
function initFormFromPayload()
{
  if(payloadStr != '')
  {
    payloadObj = Ext.util.JSON.decode(payloadStr) ;
    $('newGroupName').value = payloadObj.newGroupName ;
    $('targetGroupId').value = payloadObj.targetGroupId ;
    if($('targetGroupId').value == 'new')
    {
      $('newGroupDiv').setStyle({display: 'inline'}) ;
    }
    for(var ii=0; ii<payloadObj.users.length; ii++)
    {
      $('userIds['+payloadObj.users[ii].userId+']').checked = true ;
      $('userTargetRoles['+payloadObj.users[ii].userId+']').value = payloadObj.users[ii].role ;
      $('targetRoleDiv_userIds['+payloadObj.users[ii].userId+']').setStyle({display: 'block'}) ;
      $('notSelected_userIds['+payloadObj.users[ii].userId+']').setStyle({display: 'none'}) ;
    }
  }
}

function toggleTargetRole(obj) 
{
  selectDivId = 'targetRoleDiv_' + obj.name ;
  textDivId = 'notSelected_' + obj.name ;
  selectDisplayStyle = (obj.checked) ? 'block' : 'none' ;
  textDisplayStyle = (obj.checked) ? 'none' : 'block' ;
  $(selectDivId).setStyle({display: selectDisplayStyle}) ;
  $(textDivId).setStyle({display: textDisplayStyle}) ;
}

function updateTargetRoles(obj) {
  for(var ii=0; ii<userTargetRoleSelects.length; ii++)
  {
    if(userCheckboxes[ii].checked == true)
    {
      userTargetRoleSelects[ii].value = (obj.value == 'same') ? userCurrentRoles[ii] : userTargetRoleSelects[ii].value = obj.value ;
    }
  }
}

/**
 * Build Object to be POSTed
 */
function makePayloadFromInput()
{
  var users = [] ;
  for(var ii=0; ii<userCheckboxes.length; ii++)
  {
    if(userCheckboxes[ii].checked == true)
    {
      users[ii] = {"userId" : userCheckboxes[ii].value, "role" : userTargetRoleSelects[ii].value}
    }
  }
  var payload = { "users" : users,
                  "targetGroupId" : $("targetGroupId").value,
                  "newGroupName"  : $("newGroupName").value
                } ;
  return payload ;
}

/**
 * This is executed onSubmit
 * Adds the payload object to the form 
 */ 
function valid(formObj)
{
  if(!validateUsers()) { return false ; }
  if(!validateGroup()) { return false ; }
  payloadObj = makePayloadFromInput() ;
  /* Add the payload to the form as a hidden input element */
  $('payload').value = Ext.util.JSON.encode(payloadObj) ;
  return true ;
}

function validateGroup()
{
  var groupId = $('targetGroupId').value ;
  if(groupId == '')
  {
    return showFormError('targetGroupIdLabel', 'targetGroupId', "Please select a destination group.") ;
  }
  else if(groupId == 'new') 
  {
    if($('newGroupName').value == '')
    {
      return showFormError('targetGroupIdLabel', 'newGroupName', "If you would like to create a new group, please specify the name of the new group.") ;  
    }
    for (var ii=0; ii<targetGroups.length; ii++)
    {
      if ($('newGroupName').value.match(new RegExp("^"+targetGroups[ii]+"$", "i"))) {
        return showFormError('targetGroupIdLabel', 'newGroupName', "That group name is already in use, please specify a new name.") ;
      }
    }
  }
  else
  {
    unHighlight('targetGroupIdLabel') ;
  }
  return true ;
}

function validateUsers()
{
  usersCheckedCount = 0 ;
  userCheckboxes.each(function(e){ if(e.checked) { usersCheckedCount++; }}) ;
  if(usersCheckedCount == 0)
  {
    alert("Please select at least one user to copy to the destination group.") ;
    return false ;
  }
  return true ;
}

function showFormError(labelId, elemId, msg)
{
  alert(msg) ;
  highlight(labelId) ;
  var elem = $(elemId) ;
  if(elem)
  {
    if(elem.focus)
    {
      elem.focus() ;
    }
    if(elem.select)
    {
      elem.select() ;
    }
  }
  return false ;
}

function highlight( id )
{
  $(id).style["color"] = "#FF0000" ;
}

function unHighlight( id )
{
  $(id).style["color"] = "#000000" ;
}

/**
 *
 * Dependencies:
 *   - ExtJS 2.2
 *     Since the popup dialog is an ExtJS dialog, that must be included by
 *     whatever file includes this .js file.
 */
var helpMessages = {
  'targetGroup' : {
    'title' : 'Help: Destination Group',
    'text' : '<ul class="extHelpPopup">' +
             '  <li>Select the group where the users will be copied to.</li>' +
             '  <li>Only groups in which you are Administrator are listed.</li>' +
             '  <li>To create a new group, select "New Group" and enter the name of the group.</li>' +
             '</ul>' 
  },
  'assignPermission' : {
    'title' : 'Help: Assign Permission',
    'text' : '<ul class="extHelpPopup">' +
             '  <li>This dropdown is used to assign a specified Permission Level to all of the users selected above.</li>' +
             '  <li>Selecting \"Same as this group\" will set the permission levels of the members in the destination group to be the same as this group.</li>' +
             '</ul>'
  }  
} ;

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
  if (!title) title = "Help" ;

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


