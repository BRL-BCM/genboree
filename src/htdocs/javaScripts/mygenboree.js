function setUserName (userName) {

if ($('usr_user_name') && userName!=null)
$('usr_user_name').value = userName;

}


   function validateEmail(){

    var field = $("usr_email");
    if (!field)
    return null;
    var str = field.value;


    var reg1 = /(@.*@)|(\.\.)|(@\.)|(\.@)|(^\.)/; // not valid
    var reg2 = /^.+\@(\[?)[a-zA-Z0-9\-\.]+\.([a-zA-Z]{2,3}|[0-9]{1,3})(\]?)$/; // valid
    if (!reg1.test(str) && reg2.test(str)) { // if syntax is valid

      return true;
    }
    alert("\"" + str + "\" is an invalid e-mail!"); // this is also optional
    field.focus();
    field.select();
    return false;
  }



  function validGenboree(form) {
      var field = $("usr_user_name");

      var loginName = null;
      if (!field )
      return null;


      if (field)
      loginName = field.value;




      if (loginName.length<1)
      {
      alert ("User name can not be blank." );
      field.focus();
      field.select();
      return false;
      }


      if (!validateName(loginName, 'User', "usr_user_name"))  {
      alert (" invalid user name." );
      return false;  }



       field = $("usr_first_name");
      var field1 = $("usr_last_name");

      if (!field) {
      return null;
      }

      if (!field1)  {
      return null;
      }

      var b = false;
      var firstName = field.value;
      var lastName = field1.value;

      if (!validateName(firstName, 'First ',"usr_first_name" ))  {

      return false;
      };


      if (!validateName(lastName, 'Last', "usr_last_name"))  {

      return false;
      };


      return validateEmail();

      return false;
  }





     function validateName( name , label, fieldId ) {


         var b = false;
        var field = $(fieldId);
         var restrictedChars= new Array(9)
         restrictedChars[0]="'";
         restrictedChars[1]="\"";
         restrictedChars[2]=";";
         restrictedChars[3]="%";
         restrictedChars[4]="*";
         restrictedChars[5]="<";
         restrictedChars[6]=">";
         restrictedChars[7]="`";
         restrictedChars[8]="\\";
         name = name.replace( /^\s+/g, "" );// strip leading
         name = name.replace( /\s+$/g, "" );// strip trailing


         if (name.length < 1) {
           alert("" + label + " name can not be blank."); // this is also optional
           field.focus();
           field.select();

          return false;
         }

         if (name.length >200) {
             alert(label + " name is too long."); // this is also optional
             field.focus();
             field.select();

            return false;
          }


         b = true;
         var x=0;
         for (x=0; x<9; x++)
         {
             if (name.indexOf(restrictedChars[x]) >=0) {
                 alert("Characters * % ' \" ; > < ` \\  are not allowed in first name."); // this is also optional

                 field.focus();
                 field.select();
                 b = false;
                 return false;
             }
         }


         return true;
     }



