// Uses prototype.js standard library file
// Uses util.js genboree library file

// STANDARD HELPER FUNCTIONS are at the bottom. Generally they don't need
// changing unless you've mis-named standard fields or something else
// bad/special.

//-------------------------------------------------------------------
// INITIALIZE your page/javascript once it loads if needed.
//-------------------------------------------------------------------
addEvent(window, "load", init_toolPage) ;
function init_toolPage()
{
  var buildRadio = getElementByIdAndValue(TOOL_PARAM_FORM, 'buildOrApply', 'build') ;
  var applyRadio = getElementByIdAndValue(TOOL_PARAM_FORM, 'buildOrApply', 'apply') ;
  if(!buildRadio.checked && !applyRadio.checked)
  {
    buildRadio.checked = true ;
  }
  return
}

//-------------------------------------------------------------------
// RESET implementation
//-------------------------------------------------------------------
// OPTIONAL: Implement a toolReset() function that will correctly reset your
// tool's form to its initial state.
function toolReset()
{
  $('expname').value = '' ;
  $('trueClass_lff').selectedIndex = 0 ;
  $('falseClass_lff').selectedIndex = 0 ;
  $('binaryOption').value = '0' ;
  $('kmerSize').value = '6' ;
  $('cvFold').value = '5' ;
  
  getElementByIdAndValue(TOOL_PARAM_FORM, 'buildOrApply', 'build').checked = true ;
  getElementByIdAndValue(TOOL_PARAM_FORM, 'buildOrApply', 'apply').checked = false ;
}

//-------------------------------------------------------------------
// VALIDATE *WHOLE* FORM
// - Call *each* specific validator method from here
//-------------------------------------------------------------------
// REQUIRED: Implement a validate() function that will validate your form and
// decide whether to submit (return true) or not (return false).
function validate()
{
  // Standard validations:
  if(validate_expname() == false) { return false; }
  if(unique_expname() == false) { return false; }
  if(validate_track() == false) { return false; }  
  // Custom validations: 
  if(validate_binaryOption() == false) { return false; }
  if(validate_kmerSize() == false) { return false; }
  if(validate_cvFold() == false) { return false ; }

  return true;
}

//-------------------------------------------------------------------
// IMPLEMENT EACH VALIDATION
// - keep each validation method focused to 1 field...maybe 2 for special validations
//-------------------------------------------------------------------


// Validate binary option 
function validate_binaryOption()
{
  var binaryOption = $F('binaryOption') ;
    var buildRadio = getElementByIdAndValue(TOOL_PARAM_FORM, 'buildOrApply', 'build') ;
    if( buildRadio.checked && (!binaryOption || !validatePositiveInteger(binaryOption) || binaryOption>0 )
    {
      return showFormError( 'binaryOption_lbl', 'binaryOption', "The binary option must be selected from one of the available choices" );
    }
    
    else
    {
      unHighlight( 'binaryOption_lbl' ); 
    }
  
  return true ;
}

// Validate kmer size
function validate_kmerSize()
{
  var kmerSize = $F('kmerSize') ;
  if( !kmerSize || !validatePositiveInteger(kmerSize)  || kmerSize < 1 )
  {
    return showFormError('kmerSize_lbl', 'kmerSize', "The kmer size must be a positive non-zero integer!") ;
  }
  else
  {
    unHighlight( 'kmerSize_lbl' ); 
  }
  return true ;
}

// Validate cross validation fold
function validate_cvFold()
{
  var cvFold = $F('cvFold') ;
  if( !cvFold || !validatePositiveInteger(cvFold))
  {
    return showFormError('cvFold_lbl', 'cvFold', "The cvFold must be a integer!") ;
  }
  else
  {
    unHighlight( 'cvFold_lbl' ); 
  }
  return true ;
}

//-----------------------------------------------------------------------------
// POP-UP HELP: in this function, make a pop-up help for each parameter/field in the form.
// This is done by supplying a helpSection arg indicating what help info to display.
//-----------------------------------------------------------------------------
function overlibHelp(helpSection)
{
  var overlibCloseText = '<FONT COLOR=white><B>X&nbsp;</B></FONT>' ;
  var leadingStr = '&nbsp;<BR>' ;
  var trailingStr = '<BR>&nbsp;' ;
  var helpText;
  
  if(helpSection == "expname")
  {
    overlibTitle = "Help: Job Name" ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Give this classification job a name.</LI>" ;
    helpText += "  <LI>You will use this name to retrieve your results later!</LI>" ;
    helpText += "</UL>\n\n" ;
  }
  else if(helpSection == "trueClass_lff")
  {
    overlibTitle = "Help: true class samples" ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Select a track containing the true calss samples.</LI>" ;
    helpText += "  <LI>'true class' &  'false class' represent two different classes of samples (e.g. cancer vs. normal).</LI>" ;
    helpText += "</UL>\n\n" ;
  }

 else if(helpSection == "falseClass_lff")
  {
    overlibTitle = "Help: false class samples" ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Select a track containing the false calss samples.</LI>" ;
    helpText += "</UL>\n\n" ;
  }

 else if(helpSection == "binaryOption")
  {
    overlibTitle = "Help: The binary representation of the samples" ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>0---basic kmer analysis.</LI>" ;
    helpText += "</UL>\n\n";
  }
  else if(helpSection == "kmerSize")
  {
    overlibTitle = "Help: The kmer size for binary representation of a sequence" ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>The ensemble of each kmer's presence or absence will be used as features to represent each sequence.</LI>" ;
    helpText += "</UL>\n\n";
  }
  else if(helpSection == "cvFold" )
  {
    overlibTitle = "Help: Fold number of cross validation" ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Default is 5 fold; put in '0' here will perform leave-one-out cross validation.</LI>\n" ;
    helpText += "</UL>\n\n";  
  }
 
  else if(helpSection == "buildOrApply" )
  {
    overlibTitle = "Help: Define the job is to build a new Winnow model or apply an exist Winnow model" ;
    helpText = "\n<UL>\n" ;
    helpText += "</UL>\n\n";  
  }
  overlibBody = helpText;
  return overlib( overlibBody, STICKY, DRAGGABLE, CLOSECLICK, FGCOLOR, '#CCF8FF', BGCOLOR, '#9F833F', 
                  CAPTIONFONTCLASS, 'capFontClass', CAPTION, overlibTitle, CLOSEFONTCLASS, 'closeFontClass',
                  CLOSETEXT, overlibCloseText, WIDTH, '300');
}

//-----------------------------------------------------------------------------
// HELPERS: These are standard and should be left alone. Unless you need
// some special changes for your tool.
//-----------------------------------------------------------------------------
// Displays an error msg and highlights/selects the problem field and label.
function showFormError(labelId, elemId, msg)
{
  alert(msg) ;
  highlight(labelId) ;
  var elem = $(elemId) ;
  if(elem.focus) elem.focus() ;
  if(elem.select) elem.select() ;
  return false ;
}

function highlight( id )
{ 
  $(id).style["color"] = "#FF0000";
}

function unHighlight( id )
{ 
  $(id).style["color"] = "#000000";
}

// Verify that expname is unique.
function unique_expname()
{
   var expname = $F('expname') ;
   for( var ii=0; ii<=USED_EXP_NAMES.length; ii++ )
   {
     if(expname == USED_EXP_NAMES[ii])
     {
       return showFormError( 'expnameLabel', 'expname', ( "'" + expname + "' is already used as an experiment name in this group.\nPlease select another.") );
     }
   }
   return true;
}

// Verify the expname looks ok.. 
function validate_expname()
{
  var expname = $F('expname');
  if( !expname || expname.length == 0 )
  {
    return showFormError( 'expnameLabel', 'expname', "You must enter a job name!" ) ;
  }
  else
  {
    var newExpname = expname.replace(/\`|\|\!|\@|\#|\$|\%|\^|\&|\*|\(|\)|\+|\=|\||\;|\'|\>|\<|\/|\?/g, '_')
    if(newExpname != expname)
    {
      $('expname').value = newExpname ;
      return showFormError( 'expnameLabel', 'expname', "Unacceptable letters in Experiment Name have been replaced with '_'.\n\nNew Experiment Name is: '" + newExpname + "'.\n");
    }
    else
    {
      unHighlight( 'expnameLabel' ); 
    }
  }
  return true ;
}

// Validate that a track is selected. 

//-----------------------------------------------------------------------------
