
 
var thisbox; 
var ok = false; 
Ext.onReady(function(){
if (Ext.get('saveConfig'))  
Ext.get('saveConfig').on('click',
    function(e){   
      
    if ($('msgbody')) 
    $('msgbody').className = "ext-gecko x-body-masked";            
    Ext.MessageBox.prompt('Layout Input', 'Please enter layout name:', saveView);});
    }
);


function saveView(btn, text) {
	var viewForm = $('viewForm'); 
	var selectionForm = $('selectionForm'); 
	
if (btn == 'cancel') {
 
    return false;  
 }
 else {   // btn == 'ok'
        text = trim(text); 
        if (!text|| text.length ==0 ) {
            Ext.Msg.show({
            title: 'Layout Input',
            msg: '<font color="red">Error: <br> &nbsp; &nbsp; entered layout name is empty.</font>' + '<br><br>Please enter layout name again: ',
            width: 300,
            buttons: Ext.MessageBox.OKCANCEL,
            prompt: true,
            fn: saveView}); 
        }
        else {
            var  encodedText = escape (text); 
          if (!isAdmin && layoutNames[encodedText]) { 
           alert ("Subscriber is not allowed to change existing layout." ); 
            return ; 
          } 
           
	 if (text.indexOf("Default All Anno") >=0 || text.indexOf ("Default Group") >= 0 ) { 
           alert ("This layout name is reserved.  Please choose a different name." ); 
            return ; 
          } 
			
			if ( encodedText && layoutNames[encodedText]  ) {
                if (!confirm('Are you sure you want to overwrite layout \"'  + text  + '\" that already exists?', showResult))            
                return false;  
            } 
             
			
			   $('dfviewStatus').value = "1";
			   $('dfviewInput').value =encodedText; 
			//document.getElementById("viewStatus").value = "1";
			 viewForm.viewStatus.value  = "1";
             viewForm.viewInput.value =encodedText;  
			 // for IE specific bug:
			$('chrSelNames').value = $('chrName').value;  
			$('chrStop').value =  $('chrStops').value;
	$('chrStart').value =  $('chrStarts').value;   
			
			
			recordOrder();  
			
			
			var target = "displaySelection.jsp"; 
            var viewData = $('viewData').value ;  
		       
			if (viewData == '1') {
				target = "viewAnnotation.jsp";
				if ($('showGroup') && $('showGroup').checked) {
					target = "viewGroupAnnotations.jsp" ; 
					if (!showAllChromosome) 
					target = "viewGroupAnnotationsByRegion.jsp"; 
				}
			}
            else {                               
                viewForm.action = target; 
           }
			
			
	  
		 viewForm.submit(); 
				   
		// submitForm2Target ("viewForm", target);      

        }    
    }
}


function showResult(btn){
    if (btn== 'yes')         
        ok = true; 
    else 
        ok = false;   
 };
     
