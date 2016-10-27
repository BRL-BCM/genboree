 var avphtmlHead = '<TABLE  width="100%" border="0px" cellpadding="0" cellspacing="0">' +
        '<TR width="100%">' + 
        '<TD  width="30%"  class="form_body">' +
        '<div align="center" class="annotation3" style="width:90%" >' + 
        'Attribute Name' + 
        '</div></TD><TD width="70%">' + 
        '<div  align="center" class="annotation3" style="width:90%" >' + 
        'Attribute Value</div></TD></TR>' ; 




function removeAtt(i) {
        var attributeName = $("atttxtName" + i ).value ;
        if (attributeName) {
           if (!confirm("Remove attribute \"" + $("atttxtName" + i ).value +  "\" from annotation?"))
            return;
        }

        var current = $("attributePairsDiv").innerHTML;
      
        if (current != null) {
            var index1  = current.indexOf ('attRowId'+ i);
            var part1 = current.substring(0, index1 - 8);
          
            var n = i + 1;
            var index2 = current.indexOf('attRowId'+ n);
            var part2  = "";
            if (index2 > index1)   {
                part2  =   current.substring(index2-8, current.length  );
                
          
                part2 = updatePart2(part2, i);
              
            }
            else   {
                if (part1.indexOf('tbody') >=0 || part1.indexOf('TBODY') >=0)
                     part2  =  "</tbody></table>";
                  else
                  part2  =  "</table>";
            }
            var index = $("index").value;
            var indexi = parseInt(index);
            indexi--;
            $("index").value = indexi;

            var allstr  = part1 + part2;
        
            $("attributePairsDiv").innerHTML = part1 + part2;
        }
}


function removeGrpAtt(annoid, attid) {
         markAnnotation('checkBox_' + annoid); 
      //  var attributeId = (); 
        var attributeName = $("atttxtName_" + annoid+ "_" + attid ).value ;
        if (attributeName) {
           if (!confirm("Remove attribute \"" + attributeName +  "\" from annotation?"))
            return;
        }

        var current = $("attributePairsDiv_" + annoid).innerHTML;
        if (current != null) {
            var index1  = current.indexOf ('attRowId_'+ annoid + "_" + attid);
            var part1 = current.substring(0, index1 - 8);
            var n = attid + 1;
            var index2   = current.indexOf ('attRowId_'+ annoid + "_" + n);
            var part2  = "";
            if (index2 > index1)   {
                part2  =   current.substring(index2-8, current.length  );
                part2 = updateGrpPart2(part2, annoid, attid);
            }
            else   {
                if (part1.indexOf('tbody') >=0 || part1.indexOf('TBODY') >=0)
                     part2  =  "</tbody></table>";
                  else
                  part2  =  "</table>";
            }
            var index = $("index_"+ annoid).value;
            var indexi = parseInt(index);
            indexi--;
            $("index_"+ annoid).value = indexi;

            var allstr  = part1 + part2;
            $("attributePairsDiv_"+ annoid).innerHTML = part1 + part2;
        }    
}




  function hideAVP () {
   var str =    $('changeAVPDiv').innerHTML;

   str = str.replace("Hide AVP", "Show AVP");
    str = str.replace("hideAVP", "showAVP");
     $('changeAVPDiv').innerHTML = str;


    var current = $("attributePairsDiv").innerHTML;
    if (current != null) {
      current = "<!--" + current + "-->";
      $("attributePairsDiv").innerHTML = current;
   }
}



function showAVP () {
   var str =    $('changeAVPDiv').innerHTML;
   str = str.replace("Show AVP", "Hide AVP");
    str = str.replace("showAVP", "hideAVP");
     $('changeAVPDiv').innerHTML = str;
    var current = $("attributePairsDiv").innerHTML;


    if (current != null) {
      current = current.substring(4, current.length-3);
      $("attributePairsDiv").innerHTML = current;
   }
}


 function updatePart2 (str, currentIndex) {
        var index = $("index").value;
        var indexi = parseInt(index);

        var i=0;
        for (i=currentIndex+1; i<=indexi; i++) {
            var findStr = "attRowId" + i;

            var temp = i-1;
            var replaceStr = "attRowId" + temp;
            str =  str.replace(findStr, replaceStr );

            findStr = "minusDiv" + i;
            replaceStr = "minusDiv" + temp;
             str =  str.replace(findStr, replaceStr );

            findStr = "btnMinus" + i;
            replaceStr = "btnMinus" + temp;
            str =   str.replace(findStr, replaceStr );

            findStr = 'removeAtt('+ i;
            replaceStr = 'removeAtt('+ temp;
            str =   str.replace(findStr, replaceStr );


            findStr = "nameInputDiv"+ i;
            replaceStr = "nameInputDiv" + temp;
             str =  str.replace(findStr, replaceStr );


            findStr = "atttxtName" + i+ "\"";
            replaceStr =  "atttxtName" + temp + "\"";
             str =  replaceAll(str, findStr, replaceStr );


            findStr = "valueInputDiv"+ i;
            replaceStr = "valueInputDiv" + temp;
              str = str.replace(findStr, replaceStr );

        findStr = "atttxtValues" + i + "\"";
        replaceStr =  "atttxtValues" + temp + "\"";
        str = replaceAll(str, findStr, replaceStr );
   }

   return str;
 }




 function updateGrpPart2 (str, annoid, currentIndex) {
        var index = $("index_" + annoid).value;
        var indexi = parseInt(index);

        var i=0;
        for (i=currentIndex+1; i<=indexi; i++) {
            var findStr = "attRowId_" + annoid + "_" + i;

            var temp = i-1;
            var replaceStr = "attRowId_" + annoid + "_" + temp;
            str =  str.replace(findStr, replaceStr );

            findStr = "minusDiv_" + annoid + "_" + i;
            replaceStr = "minusDiv_" + annoid + "_" + temp;
             str =  str.replace(findStr, replaceStr );

            findStr = "btnMinus_" + annoid + "_" + i;
            replaceStr = "btnMinus_" + annoid + "_" + temp;
            str =   str.replace(findStr, replaceStr );

            findStr = 'removeGrpAtt(' + annoid + ", " + i;
            replaceStr = 'removeGrpAtt('+ annoid + ", " + temp;
            str =   str.replace(findStr, replaceStr );


            findStr = "nameInputDiv_"+ annoid + "_" + i;
            replaceStr = "nameInputDiv" + annoid + "_" + temp;
             str =  str.replace(findStr, replaceStr );


            findStr = "atttxtName_" +annoid + "_" + i;
            replaceStr =  "atttxtName_" +annoid + "_" +  temp;
             str =  replaceAll(str, findStr, replaceStr );


            findStr = "valueInputDiv_"+ annoid + "_" + i;
            replaceStr = "valueInputDiv_" +annoid + "_" +  temp;
              str = str.replace(findStr, replaceStr );

        findStr = "atttxtValues_" +annoid + "_" +  i;
        replaceStr =  "atttxtValues_" + annoid + "_" + temp;
        str = replaceAll(str, findStr, replaceStr );
   }

   return str;
 }




function addNewAnnoAttribute(annoOrder) {  
 markAnnotation('checkBox_' + annoOrder); 
     var index = $('index_'+ annoOrder).value;  
     if ( !$('index_'+ annoOrder)) 
      return false;  
     var indexi = parseInt(index);          
        var i= 0;
        var current = ""; 
            var name ; 
            var value ; 
        if (indexi >=0 ) {            
        for (i=0; i<=indexi; i++) {
            name =   $('atttxtName_' + annoOrder + '_' +i ).value;
            value =  $('atttxtValues_' + annoOrder + '_' + i).value;
            current =  current +    '<TR id="attRowId_' + annoOrder+'_' +i + '"  width="100%">' +
            '<TD  width="30%"  class="form_body">' +
            '<div id="minusDiv_' + annoOrder+'_' +i + '" class="minusButton" >' +
            '<input type="button" id="btnMinus_' + annoOrder+'_' +i + 
            '" class="btn1" value="-" onClick="removeGrpAtt(' + annoOrder+', '+ i + ');">' +
            '</div>' +                                                                                                                                                             
            '<div id="nameInputDiv_' + annoOrder+'_' +i + '"  class="attributeName" style="display:block;">' +
            '<input type="text"   class="longInput1" name="atttxtName_' + annoOrder+'_' +i + '" id="atttxtName_' + annoOrder+'_' +i 
            + '" BGCOLOR="white" value="' + name + '" onChange="markAnnotation(checkBox_' +  annoOrder + '); ">' +
            '</div>' +
            '</TD><TD width="70%">' +
            '<div id="valueInputDiv_' + annoOrder+'_' +i + '" class="attributeValue" style="display:block;">' +
            '<input type="text"  class="longInput1"  name="atttxtValues_' + annoOrder+'_' +i + '" id="atttxtValues_'+ annoOrder+'_' +i  +
            '" BGCOLOR="white" value="' + value + '"  onChange="markAnnotation(checkBox_' +  annoOrder + '); ">' +
            '</div>' +
            '</TD>' +
            '</TR>';                                
        }}
        
       indexi++;
      var newAttribute = '<TR id="attRowId_' + annoOrder+'_' +indexi + '"  width="100%">' +
           '<TD  width="30%"  class="form_body">' +
            '<div id="minusDiv_' + annoOrder+'_' +indexi + '" class="minusButton" >' +
            '<input type="button" id="btnMinus_' + annoOrder+'_' +indexi + 
            '" class="btn1" value="-" onClick="removeGrpAtt(' + annoOrder+', '+ indexi + ');">' +
            '</div>' +                                                                                                                                                             
           '<div id="nameInputDiv_' + annoOrder+'_' +indexi + '"  class="attributeName" style="display:block;">' +
            '<input type="text"   class="longInput1" name="atttxtName_' + annoOrder+'_' +indexi + '" id="atttxtName_' + annoOrder+'_' +indexi + '" BGCOLOR="white" value="" onChange="markAnnotation(checkBox_' +  annoOrder + '); ">' +
            '</div>' +
            '</TD><TD width="70%">' +
            '<div id="valueInputDiv_' + annoOrder+'_' +indexi + '" class="attributeValue" style="display:block;">' +
            '<input type="text"  class="longInput1"  name="atttxtValues_' + annoOrder+'_' +indexi + '" id="atttxtValues_'+ annoOrder+'_' +indexi  + '" BGCOLOR="white" value=""  onChange="markAnnotation(checkBox_' +  annoOrder + '); ">' +
            '</div>' +
            '</TD>' +
      '</TR></TABLE>';
         // firefox convert html to lowcase, while ie is case sensitive   
        currentHtml = avphtmlHead + current + newAttribute;  
        $("attributePairsDiv_"+annoOrder).innerHTML = currentHtml;      
        $("index_"+ annoOrder).value=indexi;
 }


    function addNewAttribute() {   
        var index = $("index").value; 
        var indexi = parseInt(index);
        var arr = new Array ();
        var i= 0;
        var current = ""; 
            var name ; 
            var value ; 
        if (indexi >=0 ) {            
            for (i=0; i<=indexi; i++) {
                name =  $('atttxtName' + i ).value;
                value =   $('atttxtValues' + i ).value;
                current =  current +  '<TR id="attRowId' + i + '"  width="100%">' +
                '<TD  width="30%"  class="form_body">' +
                '<div id="minusDiv' + i  + '" class="minusButton" >' +
                '<input type="button" id="btnMinus' + i  +
                '" class="btn1" value="-" onClick="removeAtt(' + i + ');">' +
                '</div>' +
                '<div id="nameInputDiv' + i  + '"  class="attributeName" style="display:block;">' +
                '<input type="text"  class="longInput1" name="atttxtName' +i+ '" id="atttxtName' + i+'" BGCOLOR="white" value="' + name + '" onChange="checkAttributeName(' + i  + '); ">' +
                '</div>' +
                '</TD><TD width="70%">' +
                '<div id="valueInputDiv' + i  + '" class="attributeValue" style="display:block;">' +
                '<input type="text"  class="longInput1"  name="atttxtValues' + i  + '" id="atttxtValues' + i + '" BGCOLOR="white" value="' + value + '" onChange="checkAttributeValues(' + i  + '); ">' +
                '</div>' +
                '</TD>' +
                '</TR>';
            }
        }
        
       indexi++;
        var newAttribute = '<TR id="attRowId' + indexi + '"  width="100%">' +
        '<TD  width="30%"  class="form_body">' +
        '<div id="minusDiv' + indexi  + '" class="minusButton" >' +
        '<input type="button" id="btnMinus' + indexi  +
        '" class="btn1" value="-" onClick="removeAtt(' + indexi + ');">' +
        '</div>' +
        '<div id="nameInputDiv' + indexi  + '"  class="attributeName" style="display:block;">' +
        '<input type="text"   class="longInput1" name="atttxtName' + indexi  + '" id="atttxtName' + indexi  + '" BGCOLOR="white" value="" onChange="checkAttributeName(' + indexi  + '); ">' +
        '</div>' +
        '</TD><TD width="70%">' +
        '<div id="valueInputDiv' + indexi  + '" class="attributeValue" style="display:block;">' +
        '<input type="text"  class="longInput1"  name="atttxtValues' + indexi  + '" id="atttxtValues' + indexi  + '" BGCOLOR="white" value="" onChange="checkAttributeValues(' + indexi  + '); ">' +
        '</div>' +
        '</TD>' +
        '</TR>' + 
        '</TABLE>';
        
          // firefox convert html to lowcase, while ie is case sensitive   
               
            currentHtml = avphtmlHead + current + newAttribute;  
              $("attributePairsDiv").innerHTML = currentHtml;             
       
        $("index").value=indexi;
    }


 function validateAVP () {
   // if not use AVP, return true;
    if (!$('avpvalues'))
      return true;

     var hasErr = false;
    var currentIndex = $('index').value;
    if (!currentIndex || currentIndex<0)
      currentIndex = 0;
     var numErr = 0;
    for (i=0; i<=currentIndex; i++) {
      if (i==0 && !$('atttxtName' + i)) 
         break;
       var name =  $('atttxtName' + i).value
       var value = $('atttxtValues' + i).value;

       if (name!= null)
        name = trim(name);


        if (value != null)
        value = trim(value);

        if (name &&  name.length>0 && (!value || value.length==0)){
                 $('atttxtValues' + i).value= '';
          //  hasErr = true;
          //  $('atttxtValues' + i).style.backgroundColor= 'red';
           // numErr ++;
        }
        
        
        if (value &&  value.length>0 && (!name || name.length==0))
           { $('atttxtName' + i).style.backgroundColor= 'red';
             hasErr = true;
              numErr ++;
            }
       if (name &&  name.length>0 )
        $('atttxtName' + i).style.backgroundColor= 'white';

        if (value &&  value.length>0 )
        $('atttxtValues' + i).style.backgroundColor= 'white';

    }

     if (hasErr){
          var field = numErr >1? "fields": "field";
         alert ('Please correct the ' + field + ' marked in red. ');
         return false;
       }
       else
       return true;

 }


function getAVPValues (inputFieldId) {
   if ($('index')) {
    var myCurrentIndex = $('index').value;
    var index = parseInt(myCurrentIndex);
   
    var filterArray = new  Array(index+1);
    var avp = "";
    for (i=0; i<= index; i++){
        var attributeName = $('atttxtName' + i ).value;
      var attributeValue = $('atttxtValues' + i).value;
       if (attributeValue != null)
            attributeValue = trim(attributeValue);
    //    if ( !attributeValue || attributeValue.length ==0)
      //     continue;


        if (attributeName != null)
            attributeName = trim(attributeName);

         if (!attributeName || attributeName.length==0 )
            continue;
            
            
          if ( !attributeValue || attributeValue.length ==0)
          attributeValue  = ''; 
                              
            

        var attributes = new Array(2);
        attributes[0] = attributeName;
        attributes[1] = attributeValue;
        filterArray[i] = attributes;
           
      // avp = avp +  attributeName+ "=" + attributeValue + "; ";
    }
    
    
    var validNum = 0; 
   for (i=0; i<= index; i++) {
      if ( filterArray[i]) 
        validNum ++;    
   }
    
  if (validNum >0) 
  {
  var validAtt = new Array(validNum); 
  var n = 0;  
   for (i=0; i<= index; i++) {
      if ( filterArray[i]) {
        validAtt[n]=  filterArray[i];
        n ++;        
        }
   }
       
                
    $(inputFieldId).value =  validAtt.toJSONString();
 
   }  
  } 
 
}



function getAnnotationAVPValues (inputFieldId, orderNum) {
    var myCurrentIndex = $('index_'+ orderNum).value;
    var index = parseInt(myCurrentIndex);      
    var filterArray = new  Array(index+1);
    var avp = "";         
    for (i=0; i<= index; i++){
        var attributeName; 
        if ( $('atttxtName_' +orderNum + "_" + i )) 
         attributeName =   $('atttxtName_' +orderNum + '_' + i ).value;
       
        var attributeValue;
        if ($('atttxtValues_' +orderNum + "_" + i )) 
         attributeValue= $('atttxtValues_' +orderNum + "_" + i ).value;
     
       if (attributeValue != null)
            attributeValue = trim(attributeValue);
      
        if (attributeName != null)
            attributeName = trim(attributeName);

         if (!attributeName || attributeName.length==0 )
            continue;

  if ( !attributeValue || attributeValue.length ==0)
           attributeValue = ''; 


        var attributes = new Array(2);
        attributes[0] = attributeName;
        attributes[1] = attributeValue;
        filterArray[i] = attributes;           
      // avp = avp +  attributeName+ "=" + attributeValue + "; ";
    }
    
    
    var validNum = 0; 
   for (i=0; i<= index; i++) {
      if ( filterArray[i]) 
        validNum ++;    
   }
    
  if (validNum >0) 
  {
  var validAtt = new Array(validNum); 
  var n = 0;  
   for (i=0; i<= index; i++) {
      if ( filterArray[i]) {
        validAtt[n]=  filterArray[i];
        n ++;        
        }
   }
   
    
    
    $(inputFieldId).value =  validAtt.toJSONString();
   }  
    //$(inputFieldId).value =  avp;

}

function checkAttributeName (id) {}

function checkAttributeValues (id) {
//alert("  value changed " + $('atttxtValues' + id).value);



}



