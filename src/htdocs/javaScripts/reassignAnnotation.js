function checkRGNewTrack () {
     if ($('changed'))
    $('changed').value="1";
    var trackRowId    = $("rgTrackRow");
    var newTrackRowId1 = $( "rgnewTrackRow1");
    var newTrackRowId2 = $( "rgnewTrackRow2");
    var classTrkName = $("rggroupTrackName").value;
    $("rgtrackLabel").style.color="#403c59";
    var trackName = $("rgnewTrackName").value;

    if (trackName.indexOf("New Track") >0) {

      if( confirm(" You are about to create a new Track. Are you sure? ")) {
       newTrackRowId1.style.display = trackRowId.style.display;
       newTrackRowId2.style.display = trackRowId.style.display;
          var typeLabel =  $("rgtypeLabel");
             var subtypeLabel =  $("rgsubtypeLabel");
               typeLabel.style.color="#403c59";
              subtypeLabel.style.color = "#403c59";
              $("rgtrackLabel").style.color="#403c59";
      }
      else {
           $("rgmessage").innerHTML = "";
           newTrackRowId1.style.display = "none";
           newTrackRowId2.style.display = "none";
          $("rgtrackLabel").style.color="#403c59";

          $("rgnewTrackName").value = classTrkName;
      }
    }
    else
    {  $("rgmessage").innerHTML = "";
       $("rgtrackLabel").style.color="#403c59";
       newTrackRowId1.style.display = "none";
       newTrackRowId2.style.display = "none";
    }
}
function selectAll(numAnnos) {
     for (ii=0; ii<numAnnos; ii++) {
      $("checkBox_" + ii).checked = true;
    }
}

function unSelectAll(numAnnos) {
 for (ii=0; ii<numAnnos; ii++) {
    $("checkBox_" + ii).checked = false;
  }
}

function confirmReassign() {
  if (confirm ("You are about reassign this annotation to a new track . Are you sure?\nNOTE: annotation will be MOVED to the new track.") ){
     $("okReassign").value="1";
   }
   else {
      $("okReassign").value="0";
   }
 }

function confirmReassignSelected() {
   if (confirm ("You are about reassign the selected annotations to a new track . Are you sure?") ){
          $("okReassignGroup").value="1";
   }
}

function validTrackName () {
     var state = "0";
     if ($("okReassign") != null)
     state = $("okReassign").value;

     if (state =="0")
      return false;
       var message = null;
       var typeField = $("rgtype");
       var type;
       var subtype;
       var success = false;
       if (typeField!= null)
         type = typeField.value;
       var field =  $("rgsubtype")
       if (field != null)
         subtype = field.value;

       var trackRowId    = $("rgTrackRow");
       var newTrackRowId1 = $( "rgnewTrackRow1");
       var newTrackRowId2 = $( "rgnewTrackRow2");
       var typeLabel =  $("rgtypeLabel");
       var subtypeLabel =  $("rgsubtypeLabel");
       var trackName = $("rgnewTrackName").value;
       var classTrkName = $("rggroupTrackName").value;
       var state =  $("okReassign").value;

      if (trackName.indexOf("New Track") <0) {
         newTrackRowId1.style.display = "none";
         newTrackRowId2.style.display = "none";
         subtypeLabel.style.color = "#403c59";
         typeLabel.style.color = "#403c59";
         if (trackName == classTrkName && state == "1") {
              $("rgmessage").innerHTML = "<UL class=\"compact2\"><li>&middot;&nbsp;You are already in this group.<\UL><BR>";
             return false;
         }
         else {
              $("rgtrackLabel").style.color="#403c59";
              $("rgmessage").innerHTML = "";
              return true;
         }
      }
  else {
        if (type != null)
            type = trimString(type);
         if (subtype!= null)
            subtype = trimString(subtype);
       if (type != null && subtype!= null && (type.length + subtype.length>=19 )) {
              if (confirm("The name for type and subtype are too long and may get chopped. Verification? ")){
                  newTrackRow.style.display = "none";
                  typeLabel.style.color="#403c59";
                  subtypeLabel.style.color = "#403c59";
                  return true;
              }
              else {
              newTrackRowId1.style.display =trackRowId.style.display;
              newTrackRowId2.style.display = trackRowId.style.display;
              $("rgmessage").innerHTML = "<li>&middot;&nbsp;Please reenter type and subtype name.<BR>";
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
                 $("rgmessage").innerHTML = "Type name can not be empty.<BR><BR>";
                 return false;
      }
       else if ((type != null && type != "") && (subtype == null || subtype == ""))
      {
           subtypeLabel.style.color = "red";
           typeLabel.style.color="#403c59";
          newTrackRowId1.style.display =trackRowId.style.display;
         newTrackRowId2.style.display = trackRowId.style.display;
         $("rgmessage").innerHTML =  "Subtype name can not be empty.<BR><BR>";
           return false;
      }
     else if ((type == null || type == "") && (subtype == null || subtype == "")) {
          newTrackRowId1.style.display =trackRowId.style.display;
          newTrackRowId2.style.display = trackRowId.style.display;
          $("rgmessage").innerHTML = "Type and subtype name can not be empty.<BR><BR>";
          typeLabel.style.color = "red";
          subtypeLabel.style.color = "red";
         return false;
      }
    if (!validateTrackDup()) {
        newTrackRowId1.style.display =trackRowId.style.display;
        newTrackRowId2.style.display = trackRowId.style.display;
        $("rgmessage").innerHTML = "<li>&middot;Track name already exist.<BR><BR>";
        typeLabel.style.color = "red";
        subtypeLabel.style.color = "red";
        return false;
    }
   }
  return true;
}

function validateTrackDup()
{
    var i;
    var typeField = $("rgtype");
    var type;
    var subtype;
    if (typeField!= null)
        type = typeField.value;
    var field =  $("rgsubtype")
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
