var type;
var subtype;
var state;
function checkNewTrack () {
   setChanged(1);
    var trackRowId    =$("rgTrackRow");
    var newTrackRowId1 =$( "rgnewTrackRow1");
    var newTrackRowId2 =$( "rgnewTrackRow2");
    var classTrkName =$("rggroupTrackName").value;
    $("rgtrackLabel").style.color="#403c59";
    var trackName =$("rgnewTrackName").value;
    if (trackName.indexOf("New Track") >0) {
        if( confirm(" You are about to create a new Track. Are you sure? ")) {
            newTrackRowId1.style.display = trackRowId.style.display;
            newTrackRowId2.style.display = trackRowId.style.display;
            var typeLabel = $("rgtypeLabel");
            var subtypeLabel = $("rgsubtypeLabel");
            typeLabel.style.color="#403c59";
            subtypeLabel.style.color = "#403c59";
            $("rgtrackLabel").style.color="#403c59";
        }
        else {
            $("rgmessage1").innerHTML = "";
            newTrackRowId1.style.display = "none";
            newTrackRowId2.style.display = "none";
            $("rgtrackLabel").style.color="#403c59";
            $("rgnewTrackName").value = classTrkName;
        }
    }
    else
        {
        $("rgmessage1").innerHTML = "";
        $("rgtrackLabel").style.color="#403c59";
        newTrackRowId1.style.display = "none";
        newTrackRowId2.style.display = "none";
    }
  // if (trackName.indexOf("New Track") <0)
    //editorForm.submit();
}

function confirmSelected(n, total, state) {
   var count =  countSelectedAnnotations( "checkBox_");   
   n = n + count;
   if (state)
    n = total;

    if (n==0)  {      $("okState").value="0";
       alert ("No annotation was selected.");
       return false;
    }
    var typeField = $("rgtype");
    if (typeField!= null)
    type = typeField.value;

    var field = $("rgsubtype")
    if (field != null)
    subtype = field.value;
    var trackName =$("rgnewTrackName").value;

    if (trackName.indexOf("New Track") < 0) {
        var x = trackName.indexOf (":");
        type = trackName.substr(0, x);
        subtype = trackName.substr (x+1 );
    }
     var  msg = "Are you sure you want to reassign the " + n + " selected annotations to the track \"" + type + ":" + subtype + "\"? \nNOTE: annotation(s) will be MOVED to the new track.";
    
    if (typeof $('copytrack') != undefined)   {
    if (! $('copytrack').checked)
    msg = "Are you sure you want to reassign the " + n + " selected annotations to the track \"" + type + ":" + subtype + "\"? \nNOTE: annotation(s) will be MOVED to the new track.";
    else
     msg = "Are you sure you want to reassign the " + n + " selected annotations to the track \"" + type + ":" + subtype + "\"? \nNOTE: annotation(s) will be COPIED to the new track.";
   }
    if (confirm (msg)){
        $("okState").value="1";
        $("doSelected").value = "doSelected"; 
        $('editorForm').submit();
    }
    else {
        $("okState").value="0";
        return false;
    }
}

function setOK () {
   $("okState").value="1"; 
}


function validateTrackDup()
{
    var i;
    var typeField =$("rgtype");
    if (typeField!= null)
    type = typeField.value;
    var field = $("rgsubtype")
    if (field != null)
    subtype = field.value;
    var trkLookup = new Object();
    for( i=0; i<numTrks; i++ )
    {
    var trkName = trkArr[i];
    trkLookup[ trkName ] = ""+ i;
    }

    var celem = trkLookup[ type+":"+subtype ];
    if( typeof celem != 'undefined' )
    {
    return false;
    }
    return true;
}

function isChecked (n) {
    var checked1  = false;
    for (ii=0; ii<n; ii++) {
        var  field = $("checkBox_" + ii)
        if (field != null)
            checked1 =  $("checkBox_" + ii).checked;
        if (checked1)  {
             return  true;
        }
    }
    return false;
}

function validTrackName () {
 var success = false;
    var message = null;
    var typeField =$("rgtype");
    if (typeField!= null)
        type = typeField.value;
    var field = $("rgsubtype")
    if (field != null)
        subtype = field.value;
    var trackRowId  =$("rgTrackRow");
    var newTrackRowId1 =$( "rgnewTrackRow1");
    var newTrackRowId2 =$( "rgnewTrackRow2");
    var typeLabel = $("rgtypeLabel");
    var subtypeLabel = $("rgsubtypeLabel");
    var trackName =$("rgnewTrackName").value;
    var classTrkName =$("rggroupTrackName").value;
    if (trackName.indexOf("New Track") <0) {
        newTrackRowId1.style.display = "none";
        newTrackRowId2.style.display = "none";
        subtypeLabel.style.color = "#403c59";
        typeLabel.style.color = "#403c59";
    }
    else {
        if (type != null)
        type = trimString(type);
        if (subtype!= null)
        subtype = trimString(subtype);
        if (type != null && subtype!= null  && (type.length + subtype.length>=19 )) {
            if (confirm("The name for type and subtype are too long and may get chopped. Verification? ")){
                newTrackRow.style.display = "none";
                typeLabel.style.color="#403c59";
                subtypeLabel.style.color = "#403c59";
                return true;
            }
            else {
                newTrackRowId1.style.display =trackRowId.style.display;
                newTrackRowId2.style.display = trackRowId.style.display;
               $("rgmessage1").innerHTML = "<li>&middot;Please reenter type and subtype name.";
                typeLabel.style.color = "red";
                subtypeLabel.style.color = "red";
                return false;
            }
        }
        else if ((type == null || type == "") && (subtype != null && subtype != "") ) {
            typeLabel.style.color = "red";
            subtypeLabel.style.color = "#403c59";
            newTrackRowId1.style.display =trackRowId.style.display;
            newTrackRowId2.style.display = trackRowId.style.display;
           $("rgmessage1").innerHTML = "<li>&middot;Type name can not be empty.";
            return false;
        }
        else if ((type != null && type != "") && (subtype == null || subtype == ""))
        {
            subtypeLabel.style.color = "red";
            typeLabel.style.color="#403c59";
            newTrackRowId1.style.display =trackRowId.style.display;
            newTrackRowId2.style.display = trackRowId.style.display;
           $("rgmessage1").innerHTML ="<li>&middot;Subtype name can not be empty.";
            return false;
        }
        else if ((type == null || type == "") && (subtype == null || subtype == "")) {
            newTrackRowId1.style.display =trackRowId.style.display;
            newTrackRowId2.style.display = trackRowId.style.display;
           $("rgmessage1").innerHTML = "<li>&middot;Type and subtype name can not be empty.";
            typeLabel.style.color = "red";
            subtypeLabel.style.color = "red";
            return false;
        }
        if (!validateTrackDup()) {
            newTrackRowId1.style.display =trackRowId.style.display;
            newTrackRowId2.style.display = trackRowId.style.display;
           $("rgmessage1").innerHTML = "<li>&middot;Track name already exist.";
            typeLabel.style.color = "red";
            subtypeLabel.style.color = "red";
            return false;
        }
}
return true;
}
