function confirmAddAVPSelected(n, total, state) {
 if (!checkAVP())
   return false; 
 
    var count = countSelectedAnnotations( "checkBox_");   
    n = n + count;       
    var x;      
    if (state)
        n = total;
    // this change should warn user for possible deletion of existing attribute value pairs for th ewhole group    
    if (!$("replaceComm").checked ) {        
        if (confirm ("You are about to add new attribute:value pair to the " + n + " selected annotation(s). \nAre you sure?") ){
            $("okdupSelected").value="1";
              $("doSelected").value="doSelected";
            getAVPValues('globalAVPValues');            
            $('editorForm').submit();
        }
        else { 
            $("okdupSelected").value = "0";
        }    
    }
    else {    
        getAVPValues('globalAVPValues');  
        var s = $('globalAVPValues').value;        
        var x = 0; 
        if (s) {
           var obj = s.parseJSON (); 
           if (obj) 
             x = obj.length; 
        } 
        
        var message =   "Warning:    You are about to replace **ALL**  the existing attributes with the " + 
        x +  " attributes in ALL the selected annotations.\n\n  Are you sure?" ;
               
       if (x ==0 )
         message =  "Warning: You are about to permenantly remove **ALL** the existing attributes\n from the selected annotations.\n\n  Are you sure?" ;
           
        if (confirm (message)){
            $("okdupSelected").value="1";
              $("doSelected").value="doSelected";
             
             $('editorForm').submit();
        }
        else { 
            $("okdupSelected").value="0";
        }    
    }
}


function  checkAVP() {
    var hasDup = false;    	
    var success = false; 
    if ($("index")) {
        var index  = $("index").value; 
  
        var iindex = -1; 
        if (index) 
        iindex = parseInt(index); 
        var avpNames = new Array();
        var avpNameCount = new Array();
        var i=0;  
        var count = 0;  
        if (iindex >-1){
            for (i=0; i<=iindex; i++) {
                var name = $('atttxtName' + i).value;   
                if (name && name != ""  && avpNameCount[name]) {
                    avpNameCount[name] += 1;      
                }
                else if (name && name != ""  && !avpNameCount[name]) {
                    avpNameCount[name] = 1;  
                    avpNames[count] = name;
                    count ++;       
                }
            }        
        }      
        
        
           var  count = 0; 
        for (i=0; i<=iindex; i++) {
              var name = $('atttxtName' + i).value; 
              if (name && name != "") 
               count = avpNameCount[name];  
               else 
               continue;   
            if (count >1){    
                hasDup = true; 
                 $('atttxtName' + i).style.backgroundColor = "red";                   
            }
            else {
               $('atttxtName' + i).style.backgroundColor = "white";    
            
            }
        }
    }
    if (!hasDup ) 
        success = true;  
    else {
          alert (" Some of the attribute names are identical (marked in RED).  \n\n\t -- Please use a different name for each attribute. ");     
      return false;     
    }    
    
    return success; 
}
