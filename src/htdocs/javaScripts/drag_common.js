function selectAllDisplay(n){
    for(var ii=0; ii<n; ii++){                
        $('item_' + ii+ '_chkdiv').style.backgroundPosition = "-10px 0px" ;
         trackName = $('item_' + ii + '_trackName').value;
        if (trackName) 
        $(trackName).value = "1";                 
    }                  
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
 
 
  
     
function clearAllSort(n){   
    var trackName ;
     
    for(var ii=0; ii<n; ii++){
     trackName = $('sortitem_' + ii + '_trackName').value;
      if (trackName) 
      $(trackName ).value = "0";     
      $('sortItem_' + ii+ '_chkdiv').style.backgroundPosition = "0px 0px" ;                     
    }
}
        
 var TOOL_PARAM_FORM = 'pdw' ;
  var tmpGlobalVal = false ;
  var tmpChecked = null ;                       
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


