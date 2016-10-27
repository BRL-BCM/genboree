var maxInt =  2147483647;
var direction = "";
var distance  = 0;
function confirmShift () {   
    var  field5 = $("direction5");
    var  field3 = $("direction3");
    var direction5 = field5.checked;
    var direction3 = field3.checked;
    if (!direction5 && !direction3) {
    $("directionLabel").style.color="red";
    alert ("Please choose a direction for the annotation.");
    return false;
    }
    else {
    $("directionLabel").style.color="#403c59";
    }
    
    if (direction5)
    direction = "5'";
    else if (direction3)
    direction = "3'";
    
    var distance  = $("distance").value;
    if (confirm ("You are about to shift this annotation toward "  +  direction + " end for " + distance + " bp. Are you sure?") ){
    $("okShift").value="1";
    editorForm.submit();
    }
    else {
    $("okShift").value="0";
    return false;
    }
    return true;
}

    function   displayWarn (ii) {
    $("checkBox_" + ii).checked = true;
    alert ("WARNING: because this annotation group is so large, you can only shift the group as a whole, not in part. \n\nDeselection of individual annotation is dispabled.");
    }

    function validateGroupAnnos(chLength, start, stop) {
    var distance  = $("distance").value;
    var labelField = $("distanceLabel");
    var errDir  = false;
    var errDs = false;
    var dsMsg = "";
    var dirMsg = "";    
    if (!validateNum(distance)) {
    labelField.style.color = "red";
    errDs = true;
    dsMsg ="<li>&middot;&nbsp;Distance must be an integer greater than or equal to 1." ;
    }
    else {
    labelField.style.color="#403c59";
    }    
    if (distance > maxInt){
    labelField.style.color = "red";    errDs = true;
    dsMsg ="<li>&middot;&nbsp;Distance exceeded chromosome length " +  chLength + ".";
    }    
    if (distance <0){
    
    errDs = true;
    labelField.style.color = "red";
    dsMsg = "<li>&middot;&nbsp;Distance must be an integer greater than or equal to 1.";
    }   
    var direction = 0;
    var field5 = $("direction5");
    var field3 = $("direction3");
        var direction5 = field5.checked;
    var direction3 = field3.checked;    
    if (direction3)
    direction = 3;   
    if (direction5)
    direction = 5;   
    if (!direction5 && !direction3) {
    errDir = true;
    dirMsg = "<li>&middot;&nbsp;Please choose a direction for this annotation." ;
    $("directionLabel").style.color="red";
    }
    else {
    $("directionLabel").style.color="#403c59";
    }    
    var d = parseInt(distance);
    var istop = parseInt(stop);
    var istart = parseInt(start);
    var length  = parseInt(chLength);
    var n = 0;   
    if ((direction== 3) )  {
    n = d + istop  ;
    if ((n) > chLength) {
    labelField.style.color = "red";
    errDs = true;
    var newDist = length - istop;
    dsMsg = "<li>&middot;&nbsp;Stop will exceed chromosome length(" + chLength+ ") after shift." ;
    $("distance").value = newDist;
    }
    }   
    if ( (direction == 5)) {
    n = -d + istart;
    if (n < 0) {
    labelField.style.color = "red";
    errDs  = true;
    var newDist =  istart -1;
    $("distance").value = "";
    dsMsg = "<li>&middot;&nbsp;Start will be 0 or negative after shift."
    $("distance").value = newDist;
    }
    }    
    var success = false;
    if(errDs && errDir){
    message = dsMsg + "\n" +  dirMsg;
    $("messageid").innerHTML = "<UL class=\"compact2\">" + message+  "</UL>";
    $("msg").innerHTML ="";
    }
    else if (errDs && !errDir) {
    message = dsMsg;
    $("messageid").innerHTML = "<UL class=\"compact2\">" + message+  "</UL>";
    $("msg").innerHTML ="";
    }
    else if (!errDs && errDir) {
    message = dirMsg;
    $("messageid").innerHTML = "<UL class=\"compact2\">" + message+  "</UL>";
    $("msg").innerHTML ="";
    }
    else {
    $("messageid").innerHTML ="";
    $("directionLabel").style.color="#403c59";
    $("distanceLabel").style.color="#403c59";
    success = true;
    }
    return success;
    }
function validateForm(chLength) {
var distance  = $("distance").value;
var labelField = $("distanceLabel");
var errDir  = false;
var errDs = false;
var dsMsg = "";
var dirMsg = "";
if (!validateNum(distance)) {
labelField.style.color = "red";
errDs = true;
dsMsg ="<li>&middot;&nbsp;Distance must be an integer greater than or equal to 1." ;
}
else {
labelField.style.color="#403c59";
}

if (distance > maxInt){
labelField.style.color = "red";    errDs = true;
dsMsg ="<li>&middot;&nbsp;Distance exceeded chromosome length " +  chLength + ".";
}
if (distance <0){
errDs = true;
labelField.style.color = "red";
dsMsg = "<li>&middot;&nbsp;Distance must be an integer greater than or equal to 1.";
}
var field = $("ep_Start");
if (field != null)
start = field.value;

field = $("ep_Stop");
if (field != null)
stop =  field.value;
var direction = 0;
var  field5 = $("direction5");
var  field3 = $("direction3");
var direction5 = field5.checked;
var direction3 = field3.checked;
if (direction3)
direction = 3;
if (direction5)
direction = 5;
if (!direction5 && !direction3) {
errDir = true;
dirMsg = "<li>&middot;&nbsp;Please choose a direction for this annotation." ;
$("directionLabel").style.color="red";
}
else {
$("directionLabel").style.color="#403c59";
}

var d = parseInt(distance);
var istop = parseInt(stop);
var istart = parseInt(start);
var length  = parseInt(chLength);
var n = 0;
if ((direction== 3) )  {
n = d + istop  ;
if ((n) > chLength) {
labelField.style.color = "red";
errDs = true;
var newDist = length - istop;
dsMsg = "<li>&middot;&nbsp;Stop will exceed chromosome length(" + chLength+ ") after shift." ;
$("distance").value = newDist;
}
}
if ( (direction == 5)) {
n = -d + istart;
if (n < 0) {
labelField.style.color = "red";
errDs  = true;
var newDist =  istart -1;
$("distance").value = "";
dsMsg = "<li>&middot;&nbsp;Start will be 0 or negative after shift."
$("distance").value = newDist;
}
}

var success = false;
if(errDs && errDir){
message = dsMsg + "\n" +  dirMsg;
$("messageid").innerHTML = "<UL class=\"compact2\">" + message+  "</UL>";
}
else if (errDs && !errDir) {
message = dsMsg;
$("messageid").innerHTML = "<UL class=\"compact2\">" + message+  "</UL>";
}
else if (!errDs && errDir) {
message = dirMsg;
$("messageid").innerHTML = "<UL class=\"compact2\">" + message+  "</UL>";
}
else{
$("messageid").innerHTML ="";
$("directionLabel").style.color="#403c59";
$("distanceLabel").style.color="#403c59";
success = true;
}
return success;
}
function validateNum(s) {
s = trimString(s) ;
var reg = /^[+-]?\d+(\d+)?$/
if (!reg.test(s) ) {
return false;
}
return true;
}

function confirmShiftSelected(n, total, state, direction ) {
    if ($("direction5") != null)
        if ($("direction5").checked)
            direction =" 5" ;
    if ($("direction3") != null)
        if ($("direction3").checked)
            direction =" 3" ;
    var list = document.getElementsByTagName("input");
    var count = 0;
    for (var ii=0; ii<list.length; ii++){
        if(list[ii].getAttribute("id") != null && list[ii].getAttribute("id").indexOf("checkBox_") == 0)
        {   if (list[ii].checked)
        count ++;
        }
    }
    n = n + count;
    if (state)
        n = total;
    var annos = " annotation ";
    if (n>1)
        annos = " annotations ";
    var msg = "Are you sure you want to shift the " + n + " selected " + annos + " toward  " + direction + "' end ? ";
    if (confirm (msg)){
        $("okState").value="1";
           $("doSelected").value="doSelected";
            $('editorForm').submit();
    }
    else {
        $("okState").value="0";
    }
}

function shiftCoord(chrLength) {
    confirmShift ();
}
