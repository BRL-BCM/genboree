
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// PAGE-SPECIFIC JAVASCRIPT
// ---------------------------------------------------------------------------

function valid(form)
{
  var user = $("addusers") ;
  var new_user = $("addnewusers");
  if(user && user.visible())
  {
    var field = $("member_name") ;
    var str = field.value ;
    if(str.length<1)
    {
      alert(" invalid user name or email address." )  ;
      field.focus() ;
      field.select() ;
      return false ;
    }

    if(!validateEmail2(str))
    {
      var b = validateName1(str) ;
      if(!b)
      {
        field.focus() ;
        field.select() ;
        return false ;
      }
      else
      {
        return true ;
      }
    }
    else
    { // valid email
      return true ;
    }
    return true ;
  }

  if(new_user && new_user.visible())
  {
    if(!validateName())
    {
      return false ;
    }
    else
    {
      return validateEmail() ;
    }
    return false ;
  }
  return true ;
}

function handleCancel()
{
  if( $('gbmsg') && $('gbmsg').innerHTML)
  {
    $('gbmsg').innerHTML = "" ;
  }
  toggle() ;
}

function toggle()
{
  var addusers = $("addusers") ;
  var addnewusers = $("addnewusers") ;
  var adduserindex = $("adduserindex") ;
  var new_username = $("new_username") ;
  var email = $("email") ;
  var institution = $("institution") ;
  addusers.style.display = 'none' ;
  addnewusers.style.display = 'none' ;
  adduserindex.style.display ='block' ;
  new_userfname.value = "" ;
  new_userlname.value = "" ;
  email.value = "" ;
  institution.value = "" ;

  var xx = document.forms.usrgrp.initPage ;
  xx.value = 'no' ;
  document.forms.usrgrp.submit() ;
}

function toggle2()
{
  var addusers = $("addusers") ;
  var addnewusers = $("addnewusers") ;
  var adduserindex = $("adduserindex") ;
  var username = $("member_name") ;
  var access = $("member_access") ;
  addusers.style.display = 'none' ;
  addnewusers.style.display = 'none' ;
  adduserindex.style.display = 'block' ;
  username.value = "" ;
  access.value = "SUBSCRIBER" ;
  var xx = document.forms.usrgrp.initPage ;
  xx.value = 'no'   ;
}

function toggleUseSelectVsContinueAdding()
{
  var userNotInListRadios = $$('input.userNotInList') ;
  if(userNotInListRadios.length && userNotInListRadios.length > 0)
  {
    var userNotInListRadio = userNotInListRadios[0] ;
    var useSelectedButton = $('addSelected') ;
    var continueAddingButton = $('continueAdd') ;
    if(userNotInListRadio.checked)
    {
      useSelectedButton.disable() ;
      continueAddingButton.enable() ;
    }
    else
    {
      useSelectedButton.enable() ;
      continueAddingButton.disable() ;
    }
  }
  return true ;
}

function validateEmail2()
{
  var field = $("member_name") ;
  var str = field.value ;
  var reg1 = /(@.*@)|(\.\.)|(@\.)|(\.@)|(^\.)/ ; // not valid
  var reg2 = /^.+\@(\[?)[a-zA-Z0-9\-\.]+\.([a-zA-Z]{2,3}|[0-9]{1,3})(\]?)$/ ; // valid
  if(!reg1.test(str) && reg2.test(str))
  { // if syntax is valid
    return true ;
  }
  return false ;
}

function validateEmail()
{
  var field = $("email") ;
  var str = field.value ;
  if(str.length > 255)
  {
    alert("The email address is too long to be valid.") ;
    field.focus() ;
    field.select() ;
    return false ;
  }
  else
  {
    var reg1 = /(@.*@)|(\.\.)|(@\.)|(\.@)|(^\.)/ ; // not valid
    var reg2 = /^.+\@(\[?)[a-zA-Z0-9\-\.]+\.([a-zA-Z]{2,3}|[0-9]{1,3})(\]?)$/ ; // valid
    if(!reg1.test(str) && reg2.test(str))
    { // if syntax is valid
      return true;
    }
    alert("\"" + str + "\" is an invalid e-mail!") ; // this is also optional
    field.focus() ;
    field.select() ;
    return false ;
  }
}

function validateName()
{
  var field = $("new_userfname") ;
  var str = field.value ;
  str = str.strip() ;

  // Check first name:
  if(str.length < 1)
  {
    alert("First name can not be blank.") ;
    field.focus() ;
    field.select() ;
    return false ;
  }

  if(str.length > 255)
  {
    alert("First name is too long.") ;
    field.focus() ;
    field.select() ;
    return false ;
  }

  if(/[\'\";%\*<>\`\\\/]/.test(str))
  {
    alert("The characters * % ' \" ; > < ` \\ / are not allowed in names.") ;
    field.focus() ;
    field.select() ;
    return false ;
  }

  // Check last name:
  var field1 = $("new_userlname") ;
  var str1 = field1.value ;
  str1 = str1.strip() ;

  if(str1.length < 1 )
  {
    alert("Last name can not be blank.") ;
    field1.focus() ;
    field1.select() ;
    return false ;
  }

  if(str1.length > 255 )
  {
    alert("Last name is too long.") ;
    field1.focus() ;
    field1.select() ;
    return false ;
  }

  if(/[\'\";%\*<>\`\\\/]/.test(str1))
  {
    alert("The characters * % ' \" ; > < ` \\ / are not allowed in names.") ;
    field1.focus() ;
    field1.select() ;
    return false ;
  }

  // Check institution:
  var institElem = $('institution') ;
  if(institElem)
  {
    var instit = field1.value ;
    instit = instit.strip() ;
    // Inistitution can be blank
    if(instit.length > 255 )
    {
      alert("Institution name is too long.") ;
      field1.focus() ;
      field1.select() ;
      return false ;
    }
    if(/[\'\";%\*<>\`\\\/]/.test(instit))
    {
        alert("The characters * % ' \" ; > < ` \\ / are not allowed in the institution name.") ;
        field1.focus() ;
        field1.select() ;
        return false ;
    }
  }
  return true ;
}

function validateName1()
{
  var field = $("member_name") ;
  var str = field.value ;
  if(str.length == 0)
  {
    alert("User name can not be empty !") ;
    field.focus() ;
    field.select() ;
    return false ;
  }

  var reg1 = /^([A-Za-z0-9_\.\-]{1,200})$/ ;
  if(reg1.test(str) )
  {
    return true;
  }
  alert("\"" + str + "\" is an invalid user name ! \n please enter a username of at least 1 letter or numbers ") ;
  field.focus() ;
  field.select() ;
  return false ;
}
