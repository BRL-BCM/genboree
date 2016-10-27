function processSubmit(formId, mode) {     
   recordOrder(); 
   if ( !validateForm())            
       return false;  
  
   var target = "mySamples.jsp"; 
   if (mode == 1) 
        target = "viewSamples.jsp";  
   else if ( mode == 2){
        target = "downloadSamples.jsp"; 
        if (!isAdmin) {
          //  target = "mySamples.jsp"; 
          //  $('download').value="1";    
        }    
    }  
      submitForm2Target (formId, target);        
}
 
 function clearAllDisplay(n){   
    var trackName = null;    
    for(var ii=0; ii<n; ii++){          
        $('item_' + ii+ '_chkdiv').style.backgroundPosition = "0px 0px" ;
        trackName = $('item_' + ii + '_trackName').value;
        if (trackName) 
        $(trackName).value = "0";               
    }    
 }
 
  function selectAllDisplay(n){
    for(var ii=0; ii<n; ii++){                
        $('item_' + ii+ '_chkdiv').style.backgroundPosition = "-10px 0px" ;
         trackName = $('item_' + ii + '_trackName').value;
        if (trackName) 
        $(trackName).value = "1";                 
    }                  
  }
  
   function clearAllSort(n){   
    var trackName ;
    $("saName_sort").value = "0";     
    $('sortitem_chkdiv').style.backgroundPosition = "0px 0px" ;     
    for(var ii=0; ii<n; ii++){
       trackName = $('sortitem_' + ii + '_trackName').value;
        if (trackName) 
        $(trackName ).value = "0";     
        $('sortItem_' + ii+ '_chkdiv').style.backgroundPosition = "0px 0px" ;                     
    }
   
 }
 
 
 function isSelected (displayNames) {
  
   var ststus = 0; 
   var isChecked = false; 
     
   for (i=0; i<displayNames.length; i++) {
       status = displayNames[i][2];  
          if (status == 1) 
       {
           isChecked = true;
           break;
       } 
   
   } 
 
   return isChecked; 
 }
 
 
     
function validateForm () {
    if ($('rseq_id').value == "" ) { 
        alert(" Please select a database "); 
        return false;  
    }
    var ii=0; 
    var checked = 0;
     
    var  jsparams =  $("jsparams").value;
    var displayNames = eval ('(' + jsparams + ')').rearrange_list_1; 
    var sortNames =  eval ('(' + jsparams + ')').rearrange_list2; 
         
    if (!displayNames || displayNames.length ==0) { 
    alert("There is no attribute name for display. ");
    //    alert(" Please select some attribute name for display. ");
    return false;  
    }
    
    if (!isSelected(displayNames)) {         
        alert(" Please select some attribute name for display. ");
        return false;      
    }   
 
    var hasError  = false; 
    	var trackNames = new Array(displayNames.length) ;  
      for (ii=0; ii<displayNames.length; ii++){  
          var thisname = displayNames[ii][2]; 
     
         if (!trackNames [thisname]) 
          trackNames [thisname] = 1;
         }
           
          var  numSelectedSortNames=0;
          if (sortNames && sortNames.length >0) {
               for (ii=0; ii<sortNames.length; ii++){    
                  var sortName = sortNames [ii][2];
                     if (sortName=="saName") 
                   continue;
                  var sortNameSelected =(sortNames[ii][3] == 1);   
                  if (sortNameSelected && !trackNames[sortName]) { 
                    hasError = true;                
                      alert ("\n\nPlease select \"" + sortName + "\" in the \"What to Display\"  list."); 
                    break;
               }                     
                  
                  if (sortNameSelected)  
                      numSelectedSortNames ++;                     
        }  
    }
    if (hasError) 
       return false;    
    return true; 
}



/**
validate file name and database name; 
return true if both vlid
false if either db or fileName is black */
function validateUpload () {
    if ($('rseq_id').value == "" ) {
     $('rseq_id').style.backgroundColor = "#ff6574"; 
      alert(" Please select a database ");
      return false;  
    }
    else {
         $('rseq_id').style.backgroundColor = "white"; 
    }
   
   var fileName = $('sampleFileName').value; 
   fileName = trimString(fileName);  
    if (fileName == "") {
      alert ("Please select a file for uploading"); 
       $('sampleFileName').style.backgroundColor = "#ff6574";
      return false; 
    }
     else {
       $('sampleFileName').style.backgroundColor = "white"; 
    }
        return true; 
}

                                                                
      function updateUpload() {
             var fileName = $('sampleFileName').value; 
         fileName = trimString(fileName);  
          if (fileName == "") {
            alert ("Please select a file for uploading"); 
             $('sampleFileName').style.backgroundColor = "#ff6574";   
             return;  
          }
          else {
             $('sampleFileName').style.backgroundColor = "white"; 
          }
      
       $('uploadFileName').value= $('sampleFileName').value; 
      
      }
                                       
   var TOOL_PARAM_FORM = 'pdw' ;
   var tmpGlobalVal = false ;var tmpChecked = null ;
   
   function doCheckToggle(divId,  ckId){
 
     var divElem = $(divId) ;        // Div with image backgroup to adjust
     var value =  $(ckId).value ;  // Input tag (usually hidden) where to record the "un/checked" fact    
     if(value == '1'){
        $(ckId).value = '0' ;
       divElem.style.backgroundPosition = "0px 0px" ;   
     }
     else if(value == '0'){
        $(ckId).value = '1' ;
       divElem.style.backgroundPosition = "-10px 0px" ;     
     }  
     
  
       return ;      
   } ;
   
 
                                  
       function recordOrder(){   
           /* Sortable lists data structure */  
           var sLists = $H() ;  /* Get any 
           regular sortable lists */  
           var lists = document.getElementsByClassName('sortableList1') ;  
           for(var ii=0, lLen = lists.length ; ii<lLen ; ii++)  {   
              var currSList = sLists[lists[ii].id] = $A() ;
               /* Get all the <li> in this list */   
              var listItems = lists[ii].getElementsByTagName("div") ;   
              var count = 0;           
              for(var jj=0, iLen = listItems.length ; jj<iLen ; jj++)   {      
                   var currItemRec = $A() ;       
                   var currItem = listItems[jj] ;    
                   currItemRec.push(currItem.id) ; 
                   
                   
              if (jj %2 ==0) {                                         
                       var trackNameInput = $(currItem.id + '_trackName') ;                      
                       var itemChecked ;                         
                       if (trackNameInput && trackNameInput.value)  {   
                            var trackName =   trackNameInput.value;
                            
                           currItemRec.push(trackName) ;     
                           itemChecked = $(trackName).value;
                       
                       }
                            
                      if(itemChecked && itemChecked=='1')       
                          currItemRec.push('1') ;    
                      else   
                          currItemRec.push('0') ;    
                      currSList.push(currItemRec) ;      
                           
               }                      
                            
             }
           }  
          $('jsparams').value = sLists.toJSONString() ; 
           return ;
       } ;       


function    parseJSParams (s,  isSort) {
     var  elements =  s.split("]");
  var  names = null;     
           
    if (elements && elements.length >0) 
     var  arr = new Array(elements.length);  
        var count = 0;  
    if (s != null)  {
        elements[0] = "," + elements[0];
        for (var j=0; j<elements.length; j++){           
            var  items = elements[j].split(",");   
             if (items != null && items.length ==4) {   
                 var  booValue = items[3];
                if (items[2] != null) 
                    items[2] = items[2].substring(1, items[2].length-1);
                if (isSort) 
                    items[2] = items[2].substring(0, items[2].length-5);
                    
                if (booValue != null && booValue.indexOf("1")>=0){
                    arr[j] = (items[2]);
                    count++; 
                    }
                else 
                   arr[j] = null;      
            }
        }        
    }
     names = new Array(count);
     var counter = 0; 
     for (var i=0; i<elements.length; i++) 
     if (arr[i] != null) {
        names [counter] = arr[i];      
         counter ++; 
    }   
                
    return names;   
}