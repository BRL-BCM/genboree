function validateAnnotationName() {
    var str = null;
    var msg = "";
    var field = $("newGroupName");
    var   labelField = document.getElementById('newGrpNameLabel')
    if (field != null)
    str = field.value;
    var state = "0";
    if ($("okDuplicate")!= null)
        state = $("okDuplicate").value;

    if (str == null && state == "1")  {
        if ( labelField != null)
        labelField.style.color="red";
        if ($('errormessage')!= null)
        $('errormessage').innerHTML = "&middot; Please enter a valid group name less than 200 characters.";
        return false;
    }
    else {
    if ($('errormessage')!= null)
    $('errormessage').innerHTML = "";
    str = trimString(str);
     }

    if ( (state == "1") && (str == "" || str.length  ==0)) {
        if ($('errormessage')!= null)
        $('errormessage').innerHTML ="";
           if ( labelField != null)
        labelField.style.color="red";

        return false;
    }
    else {
        if (labelField != null)
            labelField.style.color="#403c59";
        if ( $('errormessage')!= null)
            $('errormessage').innerHTML = "";
    }

    if (str.length <=200){
        var reg1 = /[\t\v\n\f\r]/;
        if (!reg1.test(str) ) {
            labelField = $('newGrpNameLabel');
            labelField.style.color="#403c59";
            if ($('errormessage')!= null)
               $('errormessage').innerHTML = "";
            return true;
        }
        else
            msg = "Annotation name is an invalid! "; // this is also optional
    }
    else
        msg = "Annotation name exceeded name length  limit(200)! ";

    if ($('errormessage')!= null)
        $('errormessage').innerHTML = "&middot; Please enter a valid group name less than 200 characters.";
   
    if ( labelField != null)
        labelField.style.color="red";

    return false;
}

function confirmDuplication () {
    var gname = $("newGroupName").value;
    if (confirm ("You are about to duplicate the annotation with new name " + gname + ". Are you sure?") ){
       $("okDuplicate").value="1";      
        $("doSelected").value="doSelected";
        $('editorForm').submit();       
    }
    else
    {
      $("okDuplicate").value="0";
    }
}

function confirmDupSelected(n, total, state) {
    if ( $("newGroupName") != null)
    var gname = $("newGroupName").value;
    var count =  countSelectedAnnotations( "checkBox_");   
     n = n + count;
   if (state)
    n = total;

    if (gname == null || gname.length==0) {
        $("okdupSelected").value="0";
       alert ("New annotation name can not be empty.");
       return;
    }
    else {
        if (confirm ("You are about to duplicate the " + n + " selected annotations with group name \"" + gname + "\". \nAre you sure?") ){
            $("okdupSelected").value="1";
            $("doSelected").value="doSelected";
            $('editorForm').submit();
        } 
        else {
            $("okdupSelected").value="0";
        }    
   }
}

function confirmRenameSelected(n, total, state) { 
        var count =  countSelectedAnnotations( "checkBox_");   
        n = n + count;

        if (state)
        n = total;

        var gname = $("newGroupName").value;
        var oldName = $("newGroupName").value;
        var annos = "annotation";
        if (n>1)
        annos ="annotations";
        if (gname == null || gname.length==0) {
            alert ("New annotation name can not be empty.");
            $('okState').value="0";
            return false;
        }
        else if (confirm (
        "Warning: You are about to rename the " + n + " selected " + annos + "  with new group name \"" + gname
        + "\". \n The annotation(s) will be moved from current group to the new group. \nAre you sure?"
        ) ){
         $('okState').value="1";
             $("doSelected").value="doSelected";
            $('editorForm').submit();
        }
        else {
          $('okState').value="0";
        }
}
