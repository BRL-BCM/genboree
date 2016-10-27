function validate_nameField(fieldName)
{
  if(!validate_string(fieldName))
  {
    return(false);
  }
  retVal =  validate_formFields()
  return (retVal);
}

function validate_filledField(fieldName)
{
  var retVal = true;
  if(!(/\S/.test(fieldName.value)))
    {
      alert("This field cannot be empty");
      fieldName.focus();
      fieldName.select();
      retVal = false;
    }
  return(retVal);
}

function validate_noSpecialChars(fieldName)
{
  var retVal = true;
  if(/"|<|>|{|}/.test(fieldName.value))
    {
      alert("This field must have printable characters. It cannot contain \",< , >, { or }");
      fieldName.focus();
      fieldName.select();
      retVal = false;
    }
  return(retVal);
}


function validate_formFields()
{
  with(document.forms[0])
  {
    return (validate_stringFormFields() && validate_numericFields());
  }
}

function validate_stringFormFields()
{  
  var inputs = document.getElementsByTagName('input');
  var retVal = true;
  for(var i=0;i<inputs.length;i++)
  {
    if(inputs[i].type=='text' && !(/^DNC/.test(inputs[i].name)) && !validate_string(inputs[i]))
    {
      inputs[i].focus();
      inputs[i].select();
      retVal = false;
      return(retVal);
    }
    
  }
  var inputs = document.getElementsByTagName('textarea');
  var retVal = true;
  for(var i=0;i<inputs.length;i++)
  {
    if(!validate_string(inputs[i]))
    {
      inputs[i].focus();
      inputs[i].select();
      retVal = false;
      return(retVal);
    }
    
  }
  return(retVal);

}


function validate_string(fieldName)
{
  return(validate_filledField(fieldName) && validate_noSpecialChars(fieldName));
}


function validate_nonNegativeInteger(field)
{
  return /^(\+)?[0-9]+$/.test(field.value)  
}


function validate_positiveInteger(field)
{
  return /^(\+)?[1-9]+$/.test(field.value)
}


function validate_dateField(fieldName)
{

  var retVal = true
  if(!(/^\d{4}\-\d{2}\-\d{2}$/.test(fieldName.value)))
    {
      alert("The run date must be in the format YYYY-MM-DD");
      fieldName.focus();
      fieldName.select();
      retVal = false;      
    }        
    return(retVal);
}


function validate_timeField(fieldName)
{
  var retVal = true
  if(!(/^\d{2}\:\d{2}\:\d{2}$/.test(fieldName.value)))
    {
      alert("The run time must be in the format HH:mm:ss");
      fieldName.focus();
      fieldName.select();
      retVal = false;      
    }        
    return(retVal);
}

