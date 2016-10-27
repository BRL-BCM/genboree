// ----------------------------------------------------------------------
// Javascript form validation routines.
// Author: Mark Tong
// date: Feb 7th, 2005
// page specific function for form validation on client side
// similar validation also conducted on server side
// Validation are based on annotation editor specification
// ----------------------------------------------------------------------
var tablecells;
var maxInt =  2147483647;
var minInt = -2147483648;
var messageStart = "<li>&middot;&nbsp;";
var tooSmall = " is too small. Will be set to -2,147,483,648.";
var tooBig = " is too big. Will be set to 2,147,483,647.";
var xx ;

function validateForm() {
    var state = "0";
    if (document.getElementById("vstate")  != null)
    state =  document.getElementById("vstate").value;
    if (state=="0")
    return false;
    
    count = document.getElementById("counter").value;
    var icount = parseInt(count);
    icount++;
    document.getElementById("counter").value = icount;   
     var numErrs =0;
     var success = false;
     var message ="";
     var labelField
     var startLabelField = document.getElementById("startLabel");
     var startValueField = document.getElementById("startValue");
     var stopLabelField =  document.getElementById("stopLabel");
     var stopValueField =  document.getElementById("stopValue");
       field = document.getElementById('gname') ;
      var newname = field.value;
      field = document.getElementById('className') ;
     var oldname = field.value;    
    if (newname == oldname && state == "1") {
    if (!confirm ("You are about to insert a new annotation into group \""  + oldname + "\". Are you sure?")){
    state = document.getElementById("vstate");
    state.value = "0";
    document.getElementById('errorMsgid').innerHTML = "";
    document.getElementById("messageid").innerHTML = "";
    return success;
    }
     }
    field = document.getElementById('track')
    field.style.color="#403c59";
    
    if (field = document.getElementById('ch1'))
    field.style.color="#403c59";
    
    if(field = document.getElementById('ch2'))
    field.style.color="#403c59";
    
    if(field = document.getElementById('ch0'))
    field.style.color="#403c59";
    
    field = document.getElementById('strandLabel')
    field.style.color="#403c59";
    
    field = document.getElementById('phaseLabel')
    field.style.color="#403c59";
    document.getElementById('errorMsgid').innerHTML = "";

     if (validateGname())
         {
          var newTrackMessage = null;
          var trackName = document.getElementById("tracks").value;

         if (trackName.indexOf("New Track") >0) {

          var newTrackMessage = validateTypeAndSubtype();
          if (newTrackMessage != null && newTrackMessage != ""){
              message = message + "<li>&middot;&nbsp;" + newTrackMessage + "\n ";
              numErrs++;
            }
       }
     startErrorCode  =  validateStart();
      if (  startErrorCode ==10 ||  startErrorCode ==20) {
          numErrs++;
          message = message +  messageStart + "Start must be an integer greater than or equal to 1.\n";
      }
      else if (startErrorCode ==30) {
          message = message +  messageStart +  "Start" + tooBig;
      }

      stopErrorCode  =  validateStop () ;
      if (  stopErrorCode ==10 ||  stopErrorCode ==20) {
          numErrs++;
          message = message +  messageStart + "Stop must be an integer greater than or equal to 1.\n";
      }
      else if (stopErrorCode ==30) {
          message = message +  messageStart +"Stop"+tooBig;
      }
      if (startErrorCode ==0 && stopErrorCode==0) {
          var start = startValueField.value;
          var stop = stopValueField.value;
          var cpErrorCode = compareStartNStop(start, stop);
          if (cpErrorCode ==40) {
                 message = message + "<li>&middot;&nbsp;Start must be less than or equal to stop.\n";
          }
      }
                  // validating query start and end: a;llow n/a or N/A, or . allow negative numbers and empty string
      var qstartErrorCode = validateQstart () ;
      if ( qstartErrorCode ==10) {
          numErrs++;
          message = message +  messageStart +"Query start must be an integer.";
        }
      else if (qstartErrorCode ==20) {
           message = message +  messageStart +"Query start" + tooSmall
      }
      else if (qstartErrorCode ==30) {
         message = message + messageStart +"Query start" + tooBig;
      }
     var qstopErrorCode = validateQstop () ;

      if ( qstopErrorCode ==10) {
          numErrs++;
         message = message +messageStart + "Query stop must be an integer.";

        }
      else if (qstopErrorCode ==20) {
        message = message +   messageStart +"Query stop" + tooSmall;
      }
      else if (qstopErrorCode ==30) {
          message = message + messageStart + "Query stop" + tooBig;
      }
         var scoreErrorCode =  validateScore();
         if (scoreErrorCode ==10) {
            numErrs++;
            message = message + messageStart +"Score must be a valid number.";
         }

           if (message != null && message !=""){
                document.getElementById("errorMsgid").innerHTML ="<UL class=\"compact2\" >" +  message + "</UL>";
                numErrs ++;
              }
           else {
                document.getElementById("errorMsgid").innerHTML = "";
         }
         if (numErrs == 0) {
                   success = true;
         }
    }
        return success;
   }

    // validating annotation name : length <=200 no tabs, newlines
    function validateGname() {
        var field = document.getElementById("gname");
        var str = field.value;
        labelField = document.getElementById('annoname')
        if (str.length <=200){
        var reg1 = /[\t\v\n\f\r]/;
        if (!reg1.test(str) ) {
        labelField.style.color="#403c59";
        return true;
        }
        }
        
        labelField.style.color="red";
        alert("\"" + str + "\" is an invalid annotation name ! "); // this is also optional
        field.focus();
        field.select();
        return false;
    }
    
    function validateString(s) {
        var reg1 = /[\t\v\n\f\r]/;
        if (!reg1.test(s) ) {
        return true;
        }
        return false;
    }

function resetForm () {
// validate annotation name first
var  field = document.getElementById('annoname')
    field.style.color="#403c59";
    field = document.getElementById('startLabel')
    field.style.color="#403c59";
    field = document.getElementById('stopLabel')
    field.style.color="#403c59";
    field = document.getElementById('qstartLabel')
    field.style.color="#403c59";
    field = document.getElementById('qstopLabel')
    field.style.color="#403c59";
    field = document.getElementById('track')
    field.style.color="#403c59";
    if (field = document.getElementById('ch1'))
    field.style.color="#403c59";
    if(field = document.getElementById('ch2'))
    field.style.color="#403c59";
    if(field = document.getElementById('ch0'))
    field.style.color="#403c59";
    field = document.getElementById('strandLabel')
    field.style.color="#403c59";
    field = document.getElementById('phaseLabel')
    field.style.color="#403c59";
    field = document.getElementById('scoreLabel')
    field.style.color="#403c59";
    field = document.getElementById('labelcomment')
    field.style.color="#403c59";
    field = document.getElementById('sequences')
    field.style.color="#403c59";
    document.getElementById('errorMsgid').innerHTML = "";
    var form1 = document.getElementById("annotation");
    form1.reset();
    var state = document.getElementById("vstate");
    state.value = "0";
    form1.submit();
    return true;
}


    function checkNewTrack () {
       var trackRowId    = document.getElementById("trackRow");
       var newTrackRowId = document.getElementById( "newTrackRow");

        var trackName = document.getElementById("tracks").value;
       if (trackName.indexOf("New Track") >0) {
         if( confirm(" You are about to create a new Track. Are you sure? ")) {
          newTrackRowId.style.display = trackRowId.style.display;
             var typeLabel =  document.getElementById("newTypeLabel");
             var subtypeLabel =  document.getElementById("newSubtypeLabel");
               typeLabel.style.color="#403c59";
              subtypeLabel.style.color = "#403c59";
           }
       }
       else
       {
         newTrackRowId.style.display = "none";
         document.getElementById("messageid").innerHTML = "";
       }
    }

  function validateTypeAndSubtype () {
       var message = null;
       var type = document.getElementById("new_type").value;
       var subtype = document.getElementById("new_subtype").value;
       var trackRowID = "trackRow";
       var newTrakRowID = "newTrackRow";
       var trackRow = document.getElementById (trackRowID);
       var newTrackRow = document.getElementById(newTrakRowID);
       var typeLabel =  document.getElementById("newTypeLabel");
       var subtypeLabel =  document.getElementById("newSubtypeLabel");
        var trackName = document.getElementById("tracks").value;

        if (trackName.indexOf("New Track") <0) {
         newTrackRow.style.display = "none";
          return null;
       }
       else {
       if (type != null && subtype!= null && (type.length + subtype.length>=19)) {
           type = trimString(type);
           subtype = trimString(subtype);
          if (confirm("The name for type and subtype are too long and may get truncated. Accept anyway? ")){

                  newTrackRow.style.display = "none";
                    typeLabel.style.color="#403c59";
                      subtypeLabel.style.color = "#403c59";
                  return null;
          }
          else {
               newTrackRow.style.display = trackRow.style.display;
             message =  "Please reenter type and subtype name.";
              typeLabel.style.color = "red";
              subtypeLabel.style.color = "red";
          }
        }
       else if ((type == null || type == "") && (subtype != null && subtype != "") )
          {       typeLabel.style.color = "red";
                    subtypeLabel.style.color = "#403c59";
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
               newTrackRow.style.display = trackRow.style.display;
             message =  "Type and subtype name can not be empty.";
              typeLabel.style.color = "red";
              subtypeLabel.style.color = "red";
         }
       }
      return message;
  }

function confirmCreate( ) {
    var gname = document.getElementById("gname").value;
    if (confirm ("You are about to create a annotation based on " + gname + ". Are you sure?") ){
    document.getElementById("vstate").value="1";
    getAVPValues('avpvalues');
    }
    else {
    document.getElementById("vstate").value="0";
    }
}
function validateStart() {
    var startLabelField =  document.getElementById("startLabel");
    var startValueField =  document.getElementById("startValue");   
    var startError = false;
    var start  = 1 ;
    var stop  = 1 ;
    var errorCode = 0;   
    var s = startValueField.value;
    s = stripString(s) ;
    var reg = /^[+-]?\d+(\d+)?$/
    
    if (!reg.test(s) ) {
    startError = true;
    errorCode = 10;
    }
    
    if (!startError) {
    start = s;
    if (start <= 0) {
    errorCode = 20;
    startError = true;
    }
    else if (start> maxInt) {
    startValueField.value = "2,147,483,647";
    errorCode = 30;
    }
    }    
    if (!startError) {
    startLabelField.style.color="#403c59";
    }
    else
    {
    startLabelField.style.color="red";
    }    
    return errorCode;
}


function validateStop () {
    var stopLabelField =  document.getElementById("stopLabel");
    var stopValueField =  document.getElementById("stopValue");
    var s = stopValueField.value;
    s = stripString(s) ;
    var  stopError = false;
    var reg = /^[+-]?\d+(\d+)?$/
    var errorCode = 0;
    if (!reg.test(s)) {
    stopError = true;
    errorCode =  10;
    }
    if (!stopError) {
    stop = s;
    if (stop <= 0) {
    stopError = true;
    errorCode =  20;                       //field.value = 1;
    }
    else if (stop > maxInt) {
    stopValueField.value = "2,147,483,647";
    errorCode =  30;
    }
    }
    if (!stopError) {
    stopLabelField.style.color="#403c59";
    }
    else{
    stopLabelField.style.color="red";
    }
    return errorCode ;
}

function compareStartNStop (start, stop) {
    var stopLabelField =  document.getElementById("stopLabel");
    var stopValueField =  document.getElementById("stopValue");
    var startLabelField =  document.getElementById("startLabel");
    var startValueField =  document.getElementById("startValue");
    var startError = false;
    var stopError = false;
  var istart = parseInt(start);
  var istop = parseInt(stop);
  if (istop < istart){
     var errorCode = 0;
     var warnMessage = "You have entered start: " + istart + " stop: " + istop
     + "\n My guess is: start: " + istop + "; stop: "+ istart + "\n Is this right?";
     if (!confirm(warnMessage))  {
          errorCode = 40;
          stopError = true;
          startError = true;
        }
     else {
       stopValueField.value = start;
       startValueField.value = stop;
      }
 }

  if (!startError) {
      startLabelField.style.color="#403c59";
    }
  else
   {
      startLabelField.style.color="red";
   }

 if (!stopError) {
    stopLabelField.style.color="#403c59";
    }
 else
    {
    stopLabelField.style.color="red";
 }
 return errorCode;
}


function validateQstart () {                
    var qstartValueField =  document.getElementById("qstart");            
    var qstartLabelField =  document.getElementById("qstartLabel");
    var errorCode = 0;
    var qstartError = false;
    var s = qstartValueField.value;
    var s1 =  stripString(s);
    s1 = s1.toLowerCase();
    reg = /^[-+]?\d+(\.\d+)?$/
    if (!reg.test(s1) && s1.indexOf("n/a") < 0 && s1.length>0 ) {
    errorCode = 10;
    qstartError = true;
    }
    
    if (s1.indexOf("n/a")>=0 && s1.length>3){
    errorCode = 10;
    qstartError = true;
    }    
    var ltstart = parseInt(s1);
    if (ltstart > maxInt) {
    errorCode = 30;
    qstartError = false;
    qstartValueField.value = "2,147,483,647";
    }
    else if (ltstart < minInt) {
    errorCode = 20;
    qstartError = false;
    qstartValueField.value= "-2,147,483,648";
    }
    
    if (!qstartError) {
    qstartLabelField.style.color="#403c59";
    }
    else
    {
    qstartLabelField.style.color="red";
    }
    return errorCode;
}


function validateQstop () {
    var qstopValueField =  document.getElementById("qstop");
    var qstopLabelField =  document.getElementById("qstopLabel");
    var errorCode = 0;
    var qstopError = false;
    var s = qstopValueField.value;
    var s1 =  stripString(s);

    s1 = s1.toLowerCase();
    reg = /^[-+]?\d+(\.\d+)?$/
    if (!reg.test(s1) && s1.indexOf("n/a") < 0 && s1.length>0 ) {
    errorCode = 10;
    qstopError = true;
    }
    
    else if (s1.indexOf("n/a")>=0 && s1.length>3){
    errorCode = 10;
    qstopError = true;
    }
    
    var ltstop = parseInt(s1);
    if (ltstop > maxInt) {
    errorCode = 30;
    qstopError = false;
    qstopValueField.value = "2,147,483,647";
    }
    else if (ltstop < minInt) {
    errorCode = 20;
    qstopError = false;
    qstopValueField.value= "-2,147,483,648";
    }
    
    if (!qstopError) {
    qstopLabelField.style.color="#403c59";
    }
    else
    {
    qstopLabelField.style.color="red";
    }
    return errorCode;
}

/** validating score: number allows scientific expression  */
function validateScore () {
    var scoreLabelField =  document.getElementById("scoreLabel");
    var scoreValueField =  document.getElementById("score");
    var errorCode = 0;
    var s =  scoreValueField.value;    
    s = stripString(s) ;
    if ((s.indexOf("e") == 0 || s.indexOf("E") == 0) && s.length==1)
    s = "1" + s+ "1";
    else if ((s.indexOf("e") == 0 || s.indexOf("E") == 0) && s.length > 1)
    s = "1" + s;
    else if ( s.length > 1 && (s.indexOf("e") == (s.length-1) || s.indexOf("E") == (s.length-1)))
    {  s = s + "1" ;
    }
    
    reg =  /^[-+]?[0-9]*[.]?[0-9]*([eE][-+]?[0-9]+)?$/;
    if (!reg.test(s) ) {
    scoreLabelField.style.color="red";
    errorCode = 10;
    }
    else
    scoreLabelField.style.color="#403c59";    
    return errorCode;
}

function resetCounter (id) {
    $(id).value = 0;
}
