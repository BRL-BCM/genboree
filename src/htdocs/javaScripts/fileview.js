 
function submitForm(id, numAnno, maxLimit, total, numAtt, mode) {
  recordOrder();
  
    var  jsparams =  $("jsparams").value;
    var  sortNames  = null; 
if (jsparams) {     
        if (jsparams.length >0) {
            var index0 = jsparams.indexOf ("[["); 
            var  index1 = jsparams.indexOf ("]]"); 
            var  displayParams = jsparams.substring(index0+1, index1+1);  
            var  names = parseJSParams(displayParams, false);            
            var index3 = jsparams.indexOf ("[[", index1+2); 
            var index4 = jsparams.indexOf ("]]", index3); 
            var  sortParams = jsparams.substring(index3+ 1, index4+1);     
     
             sortNames  = parseJSParams(sortParams, true); 
        }
      }       
      
   
     if (!names || names.length ==0) { 
            alert(" Please select some attribute Name for display. ");
            return false;  
        }
         
            var hasError  = false; 
       $('jsparams').value = names;           
  	var trackNames = new Array(names.length) ;  
    for (ii=0; ii<names.length; ii++){  
        var thisname = names[ii]; 
   
       if (!trackNames [thisname]) 
        trackNames [thisname] = 1;   
       }
         
       var numChosenSort=0;
              if (sortNames && sortNames.length >0) {
           $('jssortparams').value = sortNames;   
                numChosenSort= sortNames.length;
        for (ii=0; ii<sortNames.length; ii++){    
              var sortName = sortNames [ii];  
                     
                 if (sortName=="saName") 
                   continue;
                if (!trackNames[sortName]) { 
                    hasError = true;                
                      alert ("\n\nPlease select \"" + sortName + "\" in the \"What to Display\"  list."); 
                    break;
               }                     
        }  
    }
    if (hasError) 
       return false;    
       
            
    if (numAnno >= maxLimit  && numChosenSort >1) {
    alert(" Due to the large number of annotations (" + total + "), \nplease select only one attribute to sort. ")    
    return false; 
    } 
    else  if (numChosenSort > 5 )  {
    alert("Please select up to five attributes to sort.")    
    return false;     
    } 
   
    $(id).value = "1";    
    
    // submit form       
    var x=document.getElementById("viewFileForm") 
    if (mode == 1) 
        x.action="viewFileAnnotations.jsp" 
    else 
       x.action="downLoadFileAnnotations.jsp" 
       
    x.submit()  
    return;
}


/*
function validateTracks(formid, ckboxName, mode) {      
    var count =0 ;  
    var list = document.getElementsByTagName("input");
    var count = 0;
    for (var ii=0; ii<list.length; ii++)
    {
    if(list[ii].getAttribute("id") != null && list[ii].getAttribute("id").indexOf(ckboxName) == 0)
    {
    if (list[ii].checked){
    count ++;
    break;
    }
    }
    }
    if (count ==0) {
    alert ("Please select some tracks."); 
    return;
    }
    else if (count >0)   {  
    $("currentMode").value= mode;        
    $(formid).submit();      
    }       
  }
  */     
  
    
  function checkTrack( mode) {         
    var trackName = $("dbTrackNames").value;   
    if (!trackName) {    
        alert ("Please select some tracks."); 
        return;
    }
    else {  
       var mode =  $("trkCommand").value;        
       if (mode == 1){ 
            $("trkCommand").value = "viewTrack";
         }
      else if (mode ==0) {
         $("trkCommand").value = "downloadTrack";   
         }       
      $("selectionForm").submit();  
      $("currentMode").value= mode;      
    }                                       
  }
  
    
                     