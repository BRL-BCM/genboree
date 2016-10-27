function validateForm (n) {
   var  numErrs = 0;
     for ( k=0; k<n; k++) {
                var  field = document.getElementById("emptyClassName_" + k );
                if (field != null) {
                    var className = field.value;
                    if (className != null && className.indexOf("select a class") >=0) {
                        document.getElementById ("emptyClassNameLabel_" + k).style.color="red";
                         numErrs ++;
                    }
                    else  {
                        document.getElementById ("emptyClassNameLabel_" + k).style.color="#403c59";
                    }
                }
         }
       

        if (numErrs == 0 )  {

           document.getElementById("success").value = "y";
            return true;
        }
        else {
             document.getElementById("success").value = "n";
            alert ("Please select a class name for each track. ");
            return false;
        }


}
