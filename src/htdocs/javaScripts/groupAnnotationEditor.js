// ----------------------------------------------------------------------
// Javascript form validation routines.
// Author: Mark Tong
// date: Dec 7th, 2005
// page specific function for form validation on client side
// similar validation also conducted on server side
// Validation are based on annotation editor specification
// ----------------------------------------------------------------------

var  numAnnos = 0;
var  annoNum = 0;
function ask4quit () {
    var list = document.getElementsByTagName("input");
    var count = 0;
    for (var ii=0; ii<list.length; ii++)
    {
    if(list[ii].getAttribute("id") != null && list[ii].getAttribute("id").indexOf("checkBox_") == 0)
    {
    if  (list[ii].checked)
    count ++;
    }
    }
    var cval;
    if ($('changed')) {
    cval =  $('changed').value;
    }
    if (cval && cval == "1") {
    if (count>0) {
    if (confirm("There are changes unsaved. \n\nAbandon changes? ")) {
    $('cancelState').value = 1;
    $('editorForm').submit();
    }
    else {
    $('cancelState').value = 0;
    }
    }
    else {
    $('editorForm').submit();
    }
    }
    else {
    if (count>0) {
    if (confirm("There are changes unsaved. \n\nAbandon changes? ")) {
    $('cancelState').value = 1;
    $('editorForm').submit();
    }
    else {
    $('cancelState').value = 0;
    }
    }
    else {
    $('cancelState').value = 1;
    $('editorForm').submit();
    }
    }
}
/**
validate all annotations
validate all fields
change field label to red if fails annotation
display error message as alert
*/

function markAnnotation (id) {
    if ($(id) != null)
        $(id).checked = true;
    return false;
}
    
function resetAll (x) {
    var form1 = $('editorForm');
    form1.reset();
    if ($("gbmsg"))
    $("gbmsg").innerHTML = "";
    for (n=0; n<x; n++) {
    var ccolor = colorArr[n];
    
    var cc =   "hiddenInputId" + n;
    var labelField = $('gnameLabel'+ n);
    if (labelField != null) {
    labelField.style.color="#403c59";
    var startLabelField
    startLabelField  = $('startLabel'+ n);
    startLabelField.style.color="#403c59";
    var stopLabelField = $('stopLabel'+ n);
    stopLabelField.style.color="#403c59";
    var qstartLabelField = $('qStartLabel'+ n);
    qstartLabelField.style.color="#403c59";
    var qstopLabelField = $('qStopLabel'+ n);
    qstopLabelField.style.color="#403c59";
    
    $(cc).value = ccolor;
    $( "colorImageId" + n).style.backgroundColor = ccolor;
    labelField = $('scoreLabel'+ n);
    labelField.style.color="#403c59";
    $("message_" + n).innerHTML = "";
    }
    }
    }
    
    function validateForm(numAnnos) {
    var x = $("chosenAnno").value;
    var checkAll = true;
    if (x >=0 && x!= numAnnos)
    checkAll = false;
    var message = "";
    var numErrs = 0;
    var success  = false;
    for (ii=0; ii<numAnnos; ii++) {
    message = validateOneAnnotation(ii);
    if (message != null && message !=""){
    if (  $("message_" + ii) != null)
    $("message_" + ii).innerHTML = "<UL class=\"compact2\"> " +  message + "</UL>";;
    if (!checkAll && ii==x){
    numErrs ++;
    }
    else if (checkAll)
    numErrs ++;
    }
    }
    if (numErrs == 0)
    success = true;
    
    if (success && $("chosenAnno")!= null) {
    $("chosenAnno").value = -1;
    $("state").value= "1";
    
    }
    else {
    if ( $("successAll") != null)
    $("successAll").innerHTML = "";
    }
    return success;
}

function validateOneAnnotation(n) {
    var message = "";
    var gnameMessage = null;
    if ($("gname_" + n)) {
    var str = $("gname_" + n).value;
    gnameMessage= validateGname (str);
    }
    else
    return message;
    
    var labelField = $('gnameLabel'+ n);
    if (labelField!= null) {
    if (gnameMessage != null ) {
    labelField.style.color="red";
    }
    else  {
    labelField.style.color="#403c59";
    }
    }
    var startMessage = null;
    var startLabelField  = $("annostart_" + n);
    if (startLabelField != null) {
    start = $("annostart_" + n).value;
    startMessage = validateStart(start);
    }
    startLabelField  = $('startLabel'+ n);
    if (startLabelField != null) {
    if (startMessage != null) {
    
    if (startMessage.indexOf("2,147,483,647") <= 0)
    startLabelField.style.color="red";
    if (startMessage.indexOf("2,147,483,647") >0) {  $("annostart_" + n).value = "2,147,483,647";
    startLabelField.style.color="#403c59";
    }
    }
    else {
    startLabelField.style.color="#403c59";
    }
    }
    var stopMessage = null;
    if ($("annostop_" + n) != null) {
    stop = $("annostop_" + n).value;
    stopMessage= validateStop(stop);
    var stopLabelField = $('stopLabel'+ n);
    if (stopMessage != null) {
    
    if (stopMessage.indexOf("2,147,483,647") >0) {
    $("annostop_" + n).value = "2,147,483,647";
    stopLabelField.style.color="#403c59";
    }
    else
    stopLabelField.style.color="red";
    }
    else {
    stopLabelField.style.color="#403c59";
    }
    }
    var cpMessage = null;
    if (startMessage == null && stopMessage == null) {
    if (start  && stop )
    cpMessage =  compareStartStop(start, stop) ;
    }
    var qstartMessage = null;
    if ( $("qStart_" + n) != null) {
    
    qstart = $("qStart_" + n).value;
    qstartMessage = validateQstart(qstart);
    
    var qstartLabelField = $('qStartLabel'+ n);
    if (qstartMessage != null) {
    if (qstartMessage.indexOf("2,147,483,647") >0)  {
    $("qStart_" + n).value = "2,147,483,647";
    qstartLabelField.style.color="#403c59";
    }
    else  if (qstartMessage.indexOf("2,147,483,648") >0)  {
    $("qStart_" + n).value = "-2,147,483,648";
    qstartLabelField.style.color="#403c59";
    }
    
    else  qstartLabelField.style.color="red";
    }
    else {
    qstartLabelField.style.color="#403c59";
    }
    }
    var qstopMessage = null;
    if ($("qStop_" + n) != null) {
    qstop = $("qStop_" + n).value;
    qstopMessage= validateQstop(qstop);
    
    var qstopLabelField = $('qStopLabel'+ n);
    if (qstopMessage != null) {
    if (qstopMessage.indexOf("2,147,483,647") >0)  {
    $("qStop_" + n).value = "2,147,483,647";
    qstopLabelField.style.color="#403c59";
    }
    else   if (qstopMessage.indexOf("2,147,483,648") >0)  {
    $("qStop_" + n).value = "-2,147,483,648";
    qstopLabelField.style.color="#403c59";
    }
    else  qstopLabelField.style.color="red";
    }
    else {
    qstopLabelField.style.color="#403c59";
    }
    }
    var scoreMessage = null;
    if ($("score_" + n) != null) {
    str = $("score_" + n).value;
    scoreMessage= validateScore(str);
    
    labelField = $('scoreLabel'+ n);
    if (scoreMessage != null) {
    labelField.style.color="red";
    }
    else {
    labelField.style.color="#403c59";
    }
    }
    var newTrackMessage = null;
    newTrackMessage = validateTypeAndSubtype (n) ;
    
    if (gnameMessage != null)
    message = gnameMessage +  "\n";
    
    if (message == null)
    message = "";
    
    if (startMessage != null)
    message = message  + startMessage+  "\n";
    
    if (stopMessage != null)
    message = message  + stopMessage+  "\n";
    
    if (cpMessage != null && cpMessage != "switch") {
    startLabelField.style.color="red";
    stopLabelField.style.color="red";
    message = message  + cpMessage+  "\n";
    }
    else if (cpMessage != null && cpMessage == "switch") {
    startLabelField.style.color="black";
    stopLabelField.style.color="black";
    // temp = start;
    if ( $("annostart_" + n))
    $("annostart_" + n).value = stop;
    if ( $("annostop_" + n))
    $("annostop_" + n).value = start;
    }
    if (qstartMessage != null)
    message = message  + qstartMessage+  "\n"
    if (qstopMessage != null)
    message = message  + qstopMessage+  "\n";
    if (scoreMessage != null)
    message = message +  scoreMessage+  "\n";
    if (newTrackMessage != null)
    message = message  + newTrackMessage+  "\n";
    return message;
}

function validateTypeAndSubtype (i) {
    var message = null;
    if ($("type_" + i ))
    var type = $("type_" + i ).value;
    if ($("subtype_" + i))
    var subtype = $("subtype_" + i).value;
    
    var trackRowID = "trackRow_" + i;
    var newTrakRowID = "newTrackRow_" + i;
    var trackRow = $ (trackRowID);
    
    var newTrackRow = $(newTrakRowID);
    var typeLabel =  $("typeLabel_" + i);
    var subtypeLabel =  $("subtypeLabel_" + i);
    
    if ($("track_" + i))
    var trackName = $("track_" + i).value;
    
    if (trackName != null && trackName.indexOf("New Track") <0) {
    newTrackRow.style.display = "none";
    return null;
    }
    else  if (trackName != null && trackName.indexOf("New Track") >=0) {
    if (type != null && subtype!= null && (type.length + subtype.length>=19)) {
    type = trimString(type);
    subtype = trimString(subtype);
    if (confirm("The name for type and subtype are too long and may get chopped. Verification? ")){
    newTrackRow.style.display = "none";
    typeLabel.style.color="#403c59";
    subtypeLabel.style.color = "#403c59";
    return null;
    }
    else {
    newTrackRow.style.display = trackRow.style.display;
    message =  "<li>&middot;&nbsp;Please reenter type and subtype name.";
    typeLabel.style.color = "red";
    subtypeLabel.style.color = "red";
    
    }
    }
    else if ((type == null || type == "") && (subtype != null && subtype != "") ) {
    if ( typeLabel != null)
    typeLabel.style.color = "red";
    
    if (subtypeLabel != null)
    subtypeLabel.style.color = "#403c59";
    
    if (newTrackRow != null && trackRow != null)
    newTrackRow.style.display = trackRow.style.display;
    message =  "Type name can not be empty.";
    }
    else if ((type != null && type != "") && (subtype == null || subtype == ""))
    {       subtypeLabel.style.color = "red";
    typeLabel.style.color="#403c59";
    newTrackRow.style.display = trackRow.style.display;
    message =  "Subtype name can not be empty.";
    }
    else if ((type == null || type == "") && (subtype == null || subtype == "")) {
    if (newTrackRow != null) {
    newTrackRow.style.display = trackRow.style.display;
    message =  "Type and subtype name can not be empty.";
    }
    
    if (typeLabel!= null)
    typeLabel.style.color = "red";
    if (subtypeLabel!= null)
    subtypeLabel.style.color = "red";
    }
    }
    return message;
}

/** validating annotation name : length <=200 no tabs, newlines */
function validateGname(str) {
    if (str.length >200) {
    return   "\"" + str + "\" exceeded maximum length of 200.";
    }
    else {
    var reg1 = /[\t\v\n\f\r]/;
    if (!reg1.test(str) ) {
    return  null;
    }
    return "<li>&middot;&nbsp; \"" + str + "\" is an invalid annotation name!\Please remove newline caracters. ";
}

return null;
}

function validateStart(fstart){
    var message
    fstart = trimString(fstart);
    fstart = stripString(fstart);
    var reg = /^[+-]?\d+(\d+)?$/
    if (!reg.test(fstart) ) {
    return  "<li>&middot;&nbsp;Start must be an integer greater or equals to 1.\n";
    }
    
    if (fstart <= 0) {
    return  "<li>&middot;&nbsp;Start must be an integer greater or equals to 1.\n";
    }
    
    if ( fstart > maxInt) {
    return "<li>&middot;&nbsp;Start is too big. Will be set to 2,147,483,647.";
}
return  null;
}  // end of start validation

function validateStop (fstop) {
    fstop= trimString(fstop);
    fstop = stripString(fstop);
    var reg = /^[+-]?\d+(\d+)?$/
    if (!reg.test(fstop) ) {
    return "<li>&middot;&nbsp;Stop must be an integer greater or equals to 1.";
    }
    if (fstop <= 0) {
    return  "<li>&middot;&nbsp;Stop must be an integer greater or equals to 1.";
    }
    if ( fstop > maxInt) {
    return "<li>&middot;&nbsp;Stop is too big. Will be set to 2,147,483,647.";
}
return null;
}

function compareStartStop (start, stop) {
    var  start1 = new String (start);
    start1 = stripString(start1);
    var  stop1  = new String(stop);
    stop1 = stripString (stop1);
    var istart = parseInt(start1);
    var istop = parseInt(stop1);
    
    if (istop < istart){
    var warnMessage = " You have entered start: " + start + " stop: " + stop ;
    warnMessage = warnMessage + "\n My guess is: start: " + stop + "; stop: "+ start + "\n Is this right?";
    if (!confirm(warnMessage)) {
    return  "Start must be less than or equal to stop.\n";
    }
    else {
    return "switch";
    }
    }
    return null;
}

function validateQstart(qstart){
    qstart = trimString(qstart);
    qstart =  stripString(qstart);
    reg = /^[-+]?\d+(\.\d+)?$/
    qstart = qstart.toLowerCase();
    if (!reg.test(qstart) && qstart.indexOf("n/a") < 0 && qstart.length>0 ) {
    return "<li>&middot;&nbsp;Query start must be an integer.";
    }
    if (qstart < minInt )
    return "<li>&middot;&nbsp;Query start is too small. Will be set to -2,147,483,648.";
    else if  ( qstart > maxInt) {
    return "<li>&middot;&nbsp;Query start is too big. Will be set to 2,147,483,647.";
    }
    if (qstart.indexOf("n/a")>=0 && qstart.length>3) {
    return "<li>&middot;&nbsp;Query start must be an integer.";
    }
    return  null;
}

function validateQstop (qstop) {
    qstop= trimString(qstop);
    qstop =  stripString(qstop);
    var reg = /^[+-]?\d+(\d+)?$/
    qstop = qstop.toLowerCase();
    if (!reg.test(qstop) && qstop.indexOf("n/a") < 0 && qstop.length>0) {
    return "<li>&middot;&nbsp;Query stop must be an integer.";
    }
    if (qstop < minInt)
    return "<li>&middot;&nbsp;Query stop is too small. Will be set to -2,147,483,648.";
    else if  ( qstop > maxInt)
    return "<li>&middot;&nbsp;Query stop is too big. Will be set to 2,147,483,647.";
    if (qstop.indexOf("n/a") >=0  && qstop.length>3)
    return "<li>&middot;&nbsp;Query stop must be an integer.";
    return null;
}

function validateScore(score) {
    if (score == null || score == "")
    score = 0.0;
    score = trimString(score);
    score = stripString(score);
    if ((score.indexOf("e") == 0 || score.indexOf("E") == 0) && score.length==1)
    score = "1" + score + "1";
    else if ((score.indexOf("e") == 0 || score.indexOf("E") == 0) && score.length > 1)
    score = "1" + score;
    else if ( score.length > 1 && (score.indexOf("e") == (score.length-1) || score.indexOf("E") == (score.length-1)))
    score = score + "1" ;
    reg =  /^[-+]?[0-9]*[.]?[0-9]*([eE][-+]?[0-9]+)?$/;
    if (!reg.test(score) ) {
    return "<li>&middot;&nbsp;Score must be a valid number.";
    }
    return null;
}

function resetAForm(n, ccolor ) {
    var cc =   "hiddenInputId" + n;
    var form1 = $("editorForm");
    if (form1 != null)
    form1.reset();
    if ($("gbmsg"))
        $("gbmsg").innerHTML = "";
    $(cc).value = ccolor;
    $( "colorImageId" + n).style.backgroundColor = ccolor;
    var msg = validateOneAnnotation(n);
    if ( msg== null || msg == "") {
        var labelField = $('gnameLabel'+ n);
        if (labelField != null) {
        labelField.style.color="#403c59";
        var startLabelField
        startLabelField  = $('startLabel'+ n);
        startLabelField.style.color="#403c59";
        var stopLabelField = $('stopLabel'+ n);
        stopLabelField.style.color="#403c59";
        var qstartLabelField = $('qStartLabel'+ n);
        qstartLabelField.style.color="#403c59";
        var qstopLabelField = $('qStopLabel'+ n);
        qstopLabelField.style.color="#403c59";
        labelField = $('scoreLabel'+ n);
        labelField.style.color="#403c59";
        $("message_" + n).innerHTML = "";
    }
}
return true;
}

function checkNewTrack (num, id) {
    markAnnotation(id);
    var trackRowId    = $("trackRow_" + num);
    var newTrackRowId = $( "newTrackRow_" + num);
    if ($("track_" + num) != null) {
        var trackName = $("track_" + num).value;
        if (trackName.indexOf("New Track") >0) {
            if( confirm(" You are about to create a new Track. Are you sure? ")) {
                newTrackRowId.style.display = trackRowId.style.display;
                var typeLabel =  $("typeLabel_" + num);
                var subtypeLabel =  $("subtypeLabel_" + num);
                typeLabel.style.color="#403c59";
                subtypeLabel.style.color = "#403c59";
            }
        }
        else
        {  
            $("message_" + num).innerHTML = "";
            newTrackRowId.style.display = "none";
        }
        return true;
    }
}

function choseAnno(ii)
{
  
  getAnnotationAVPValues ('avpvalues_'+ii, ii);
    if ( $("chosenAnno") != null) {
    $("chosenAnno").value= ii;
    if ($('navigator')){
    $('navigator').value = "none";
    }
    if(  $("successAll")!= null)
    $("successAll").innerHtml= "";
    }
        
}

function choseAllAnno(num)
{
    if ( $("chosenAnno") != null) {
        $("chosenAnno").value= num;
      
        if ($('navigator')){
        $('navigator').value = "none";
        }
        if(  $("successAll")!= null)
        $("successAll").innerHtml= "";
      var i=0;   
        for (i=0; i<num; i++) {
             getAnnotationAVPValues ('avpvalues_'+i, i);
            
        }
    }
}

