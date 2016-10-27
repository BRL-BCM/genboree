// page specific javascript

    function   init(mode) {
        if (mode==0) {
        initCreate();
        }
    }


    function processEvent (e) {
        if (e.keyCode == 13 ){

            submitDB('rseq_name');
        }
    }

  function initCreate() {
         var db1 = $("db1");
         db1.style.display = "block";
         var db = $("db0");
         db.style.display = "none";
         var ep_display = $("ep_display");
         ep_display.style.display = "block";
         var ep_edit = $("ep_edit");
         ep_edit.style.display = "none";
         var ep_delete = $("ep_delete");
         ep_delete.style.display = "none";
     }

    function displayEP() {
        var db1 = $("db1");
        db1.style.display = "none";
        var db = $("db0");
        db.style.display = "block";
        var ep_display = $("ep_display");
        ep_display.style.display = "none";
        var ep_edit = $("ep_edit");
        ep_edit.style.display = "block";
        var ep_delete = $("ep_delete");
        ep_delete.style.display = "none";

      var epbuttons = $("button_set1");
      epbuttons.style.display = "none";
    }


    function submitDB(id) {

     if (checkDBName(id)) {

        init(mode);
     }
     else {

        return false;
     }


        var db1 = $("db1");
        var db = $("db0");
        var ep_display = $("ep_display");
        var ep_edit = $("ep_edit");
        var ep_delete = $("ep_delete");

        if (db1)
        db1.style.display = "none";
        if (db)
        db.style.display = "block";
        if (ep_display)
        ep_display.style.display = "block";

        if (ep_edit)
        ep_edit.style.display = "none";
        if (ep_delete)
        ep_delete.style.display = "none";
      return true;
    }

    function updateEP() {

        var db1 = $("db1");
        var db = $("db0");
        var ep_display = $("ep_display");
        var ep_edit = $("ep_edit");
        var ep_delete = $("ep_delete");

        db1.style.display = "none";
        db.style.display = "block";

        ep_display.style.display = "none";
        ep_edit.style.display = "block";
        ep_delete.style.display = "none";
    }

    function deleteEP()
    {
      var db1 = $("db1") ;
      var db = $("db0");
      var ep_display = $("ep_display");
      var ep_edit = $("ep_edit");
      var ep_delete = $("ep_delete");
      db1.style.display = "none";
      db.style.display = "block";
      ep_display.style.display = "none";
      ep_edit.style.display = "none";
      ep_delete.style.display = "block";
      var epbuttons = $("button_set1");
      epbuttons.style.display = "none";
    }


    function displaydb()
    {
      var db1 = $("db1") ;
      db1.style.display = "block" ;
      var db = $("db0") ;
      db.style.display = "none" ;
      var ep_display = $("ep_display") ;
      ep_display.style.display = "block" ;
      var ep_edit = $("ep_edit") ;
      ep_edit.style.display = "none" ;
      var ep_delete = $("ep_delete") ;
      ep_delete.style.display = "none" ;
      var xx = $("updateDBinfo") ;
      xx.style.display = "block" ;
      return false;
    }



  function displayCreate () {
        db0.style.display="none";
        db1.style.display="block";
        btnset2.style.display = "block";
  }


    function cancelEdit(f) {
        f.reset();
        var the_inputs=document.getElementsByTagName("input");
        for(var i = 0; i < the_inputs.length; i++)
        {
            if (the_inputs[i].getAttribute("id") != null && the_inputs[i].getAttribute("id").indexOf("updfref_") == 0)
            the_inputs[i].style.backgroundColor ="white";
        }
        displaytop();
    }


  function displaytop() {

        var db1 = $("db1");
        db1.style.display = "none";
        var db = $("db0");
        db.style.display = "block";
        var ep_display = $("ep_display");
        ep_display.style.display = "block";
        var ep_edit = $("ep_edit");
        ep_edit.style.display = "none";
        var ep_delete = $("ep_delete");
        ep_delete.style.display = "none";

          var epbuttons = $("button_set1");
      epbuttons.style.display = "block";
        return false;
    }


function showWarning()
{
    var showConfirm = false;
    var confirmed = true;
    var the_inputs=document.getElementsByTagName("input");
    for(var i = 0; i < the_inputs.length; i++)
    {
        if(the_inputs[i].type=="checkbox")
        {
            if(the_inputs[i].checked)
            {
              showConfirm = true;
              break;
             }
        }
    }

  if( showConfirm )
  {
    confirmed = confirm( "You are about to delete a large number of annotations, which may take a long time to perform. Do you want to continue?" );
  }
    return confirmed;
}



function checkEntryPoint (f) {
        var ii ;

        var list = document.getElementsByTagName("input");
        var numEP  = 0;
        var entryPointNames = new Array() ;
         var entryPointIds = new Array() ;
        for (var ii=0; ii<list.length; ii++)
        {
            if(list[ii].getAttribute("id") != null && list[ii].getAttribute("id").indexOf("updfref_") == 0)
            {
              var id = list[ii].getAttribute("id");
               entryPointNames[numEP] =  $(id).value;
                entryPointIds[numEP] = id;
               numEP ++;
            }
        }

      	var retVal = true ;
        var hasBlankEntry = false ;
        var hasDuplicates = false ;
        var existName = false;

        var errors = new Array() ;
        var duplicateEp= $H(new Array()) ;
      	// FirstGet all track names
       if (entryPointNames.length <1)
       return true;

       var epNames = new Object() ;



      	for(ii=0; ii <  entryPointNames.length; ii++)
      	{
     		var epName = entryPointNames[ii];

      		if(epNames[epName]) {// count number times each track occurs
      		  epNames[epName] += 1 ;
      		  }
      		else {
      		  epNames[epName] = 1 ;
      		  }
      	}

      	var epNamesHash = $H(epNames) ;


        var redColor = "#F0C0C0";

        // Collect errors and warnings for later display.
      	for( ii=0; ii < entryPointNames.length; ii++ )
      	{
              var hasBlankTypes1 = false ;
              var hasBlankSubtypes1 = false ;
              var hasDuplicates1 = false ;
              var hasTooLongNames1 = false ;
          // Is track type empty string or all whitespace? Error.
      		if( entryPointNames[ii].match(/^\s*$/) )
      		{
      		 $(entryPointIds[ii]).style.backgroundColor = redColor;
      		  $(entryPointIds[ii]).focus() ;
      		  if(!hasBlankEntry)
      		    errors.push(" - Some of new names is empty or blank.") ;
      		  hasBlankEntry = true ;
      		}

    		// Are there duplicates for this track? Confirm OK.
      		var trkCount = epNames[entryPointNames[ii]] ;

      		if( (typeof(trkCount) != 'undefined') && (trkCount > 1)) // Look for duplicate track names
      		{
      		    $(entryPointIds[ii]).style.backgroundColor = redColor;
      			 $(entryPointIds[ii]).focus();
      			if(!hasDuplicates)
      			  errors.push(" - Some of the new names are duplicate.") ;
      			hasDuplicates = true ;
      		}

      	}


      	if(hasBlankEntry  || hasDuplicates)
      	{
      	  var errorStr = errors.join("\n") ;
      	  alert("ERROR: there are problems with your new entry point names highlighted in RED:\n" + errorStr ) ;
          return false;
      	}


      	$(f).submit();

      }




    function cancelDBEdit(f, id)
    {
     f.reset();
     if ($(id))
           $(id).style.backgroundColor = "white";
     displaytop();
    }

   function checkDBName2(f, id, oldName)
   {
    var newName ;

    if ($(id))
       newName = $(id).value;
       else
       return false;

           var redColor = "#F0C0C0";
       if (newName.match(/^\s*$/) ){

          $(id).style.backgroundColor = redColor;
             alert("ERROR:  database name is blank." );
              if ($("validDBName"))
     $("validDBName").value = "0";
           return false;
       }
     var isDup = false;

    if (dbNames && oldName != newName) {
     for (i=0; i<dbNames.length; i++) {
       if (dbNames[i]== newName)
       {

         isDup = true;
         break;
       }   }
       if (isDup)
       {
       alert("ERROR:    \nThe selected database name '" + newName + "' is not available.  \nPlease try a different name. ");
        $(id).style.backgroundColor = redColor;

         if ($("validDBName"))
     $("validDBName").value = "0";
       return false;
       }

   }

   if ($("validDBName"))
     $("validDBName").value = "1";

   }


  function checkState () {
   var success = true;
   if ($("validDBName")) {
      if ($("validDBName").value =="0")
       success = false;
   }

  return success;
  }




  function checkDBName(id)
  {
        var newName ;

   if ($(id))
      newName = $(id).value;
      else
      return false;

          var redColor = "#F0C0C0";
      if (newName.match(/^\s*$/) ){

         $(id).style.backgroundColor = redColor;
          alert("ERROR:   database name is blank  " );
          return false;
      }
    var isDup = false;

   if (dbNames) {
    for (i=0; i<dbNames.length; i++) {
      if (dbNames[i]== newName)
      {

        isDup = true;
        break;
      }   }
      if (isDup)
      {
      alert("ERROR:    \nThe selected database name '" + newName + "' is not available.  \nPlease try a different name. ");
       $(id).style.backgroundColor = redColor;


      return false;
      }

  }
    return true;
  }

 function trimString(sInString) {
    sInString = sInString.replace( /^\s+/g, "" );// strip leading
    return sInString.replace( /\s+$/g, "" );// strip trailing
}

function uploadFormSubmitIt(uploadForm)
{
  if (uploadForm.upload_file.value == "" )
  {
    alert("You didn't specify upload file!");
    uploadForm.upload_file.focus();
    return false;
  }
  
  displayLoadingMsg(ProgressUpload.getLoadingMsgDiv());
  var redirectUrl = location.protocol + '//' + location.host + '/java-bin/merger.jsp?fileName=' + encodeURIComponent(uploadForm.upload_file.value);
  ProgressUpload.startUpload(uploadForm, null, redirectUrl);  
    
  return false;
}

function displayLoadingMsg(loadingMsg) {
  maskDiv = $('genboree-loading-mask') ;
  maskDiv.style.visibility = "visible" ;
  loadMsgDiv = $('genboree-loading') ;
  loadMsgDiv.innerHTML = '<div class="genboree-loading-indicator" style="height:100px;">'+loadingMsg+'</div>';
  loadMsgDiv.style.visibility = "visible" ;
  loadMsgDiv.style.width = "430px" ;
  loadMsgDiv.style.left = "30%" ;
}
