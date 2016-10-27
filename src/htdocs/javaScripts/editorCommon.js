var  maxInt =  2147483647;
var  minInt = -2147483648;

function confirmRefresh()
{
  var answer = confirm("Do you want to refresh the graphical/tabular browser window?") ;
  if(answer)
  {
    // try to get handle on open window
    var windowToRefresh = window.open("", "_refreshMe") ;
    if(windowToRefresh && windowToRefresh.refreshMe == true)
    {
      windowToRefresh.location.reload() ;
    }
    else
    {
      alert("Wups! Looks like you closed the window...") ;
      if(windowToRefresh)
      {
        windowToRefresh.close() ;
      }
    }
    window.focus() ;
  }
  return ;
}

function setPage (n, nav) {
    $('navigator').value = nav;
    if ($('editPage')){
    if (! confirm ("The current selections will be lost if not saved. \n Are you sure to proceed? ")) {
    return false; }
    }
    if ( typeof ($('currentPage'))!= undefined)
    $('currentPage').value = n;
    if ($('editorForm')!= null)
    $('editorForm').submit();
}


function setViewPage (n, nav, formid) {
    $('navigator').value = nav;
    if ( typeof ($('currentPage'))!= undefined)
    $('currentPage').value = n;
    if ($(formid)!= null)
    $(formid).submit();
}





function processDisplayChange () {
$('app').value = $('app1').value;
$('editorForm').submit();
}


function processDisplayNumberChange (topAppId, botAppId, f ) {
$(topAppId).value = $(botAppId).value;
f.submit();
}




function setPageInfo (pageId, pageValue, navId, navValue, formId) {
    $(navId).value = navValue;
    if ( typeof ($(pageId))!= undefined)
    $(pageId).value = pageValue;
    if ($(formId)!= null)
    $(formId).submit();
}



function checkAll(state, state2) {
    if ( $('navigator'))
    $('navigator').value = "";
    var list = document.getElementsByTagName("input");
    var count = 0;
    for (var ii=0; ii<list.length; ii++)
    {
    if(list[ii].getAttribute("id") != null && list[ii].getAttribute("id").indexOf("checkBox_") == 0)
    {
    count ++;
    list[ii].checked = state;
    }
    }
    // set hidden value for select All
    if (state2) {
    if ($('selectAllAnnos') != null)
    $('selectAllAnnos').value = state2;
    }
}

function setStateChange (id, state) {
if ($(id))
$(id).value= state;
}

function selectAll(numAnnos) {
if (   $('navigator'))
$('navigator').value = "";
for (ii=0; ii<=numAnnos; ii++) {
if ($("checkBox_" + ii) != null)
$("checkBox_" + ii).checked = true;
}
// set hidden value for select All
if ($('selectAllAnnos') != null)
$('selectAllAnnos').value = "true";
//return false;
}

function unSelectAll(numAnnos) {
    if (   $('navigator'))
    $('navigator').value = "";
    for (ii=0; ii<=numAnnos; ii++) {
    if ($("checkBox_" + ii) != null)
    $("checkBox_" + ii).checked = false;
    }
    // set hidden value for select All
    if ($('selectAllAnnos') != null)
    $('selectAllAnnos').value = "false";
}

// process one field change
function processQuit(val, id, state) {
if (state) {
    if (confirm("Abandon unsaved changes and close window? ")) {
    window.close();
    return ;
    }
    else {
    $('cancelState').value =0;
    return;
    }
}
    else {
    if ($('changed')) {
    var cval =  $('changed').value;
    if (cval && cval == "0") {

    $('cancelState').value = "1";
    $('editorForm').submit();
    }
    else {   // changed

    if (!compareValue(val, id)) {

    if (confirm("There are changes unsaved. \n\nAbandon changes? ")) {
    $('cancelState').value = "1";
    $('editorForm').submit();
    }
    else {
    $('cancelState').value =0;
    }
    }
    else{

    window.close();
    }
    }
    }
    else {

    window.close();
    }  }
}

function compareValue (val, id) {
    if ($(id)){
    var newVal = $(id).value;
    if (newVal == val) {
    return true;
    }
    else
    return false;
    }
    else {
    return false;
    }
}

function confirmQuit () {
    if (confirm("There are changes unsaved. Abandon changes? ")) {
    window.close();
    }
    else {
    $('cancelState').value =0;
    }
    }

    function setChanged (val) {
    if ($('changed')) {
    $('changed').value = val;
    }
}

// process one field change
function processQuit2(val, id) {
    if ($('changed')) {
    var cval =  $('changed').value;
    if (cval && cval == "0") {

    $('cancelState').value = "1";
    $('editorForm').submit();
    }
    else {   // changed
    window.close();
    }
    }
    else {
    window.close();
    }
}
