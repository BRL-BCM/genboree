function validate(){
    
  if(validate_expname() == false){ 
    return false; 
  } 
  
  if(unique_expname() == false){ 
    return false; 
  }
  
  if(validate_track() == false){ 
    return false; 
  }   
  
  if(validate_upstreamPadding() == false){ 
    return false; 
  } 
  
  if(validate_downstreamPadding() == false){ 
    return false; 
  }
  
  if(validate_primerSizeMin() == false){ 
    return false; 
  } 
  
  if(validate_primerSizeMax() == false){ 
    return false; 
  } 
  
  if(validate_primerSizeOpt() == false){ 
    return false; 
  } 
  
  if(validate_primerTmMin() == false){ 
    return false; 
  } 
  
  if(validate_primerTmMax() == false){ 
    return false; 
  } 
  
  if(validate_primerTmOpt() == false){ 
    return false; 
  } 
  
  if(validate_ampliconTmMin() == false){ 
    return false; 
  } 
  
  if(validate_ampliconTmMax() == false){ 
    return false; 
  } 
  
  if(validate_ampliconTmOpt() == false){ 
    return false; 
  } 
  
  if(validate_primerGcMin() == false){ 
    return false; 
  } 
  
  if(validate_primerGcMax() == false){ 
    return false; 
  } 
  
  if(validate_primerGcOpt() == false){ 
    return false; 
  } 
  
  if(validate_maxSelfComp() == false){ 
    return false; 
  } 
  
  if(validate_ampliconSizeRanges() == false){ 
    return false; 
  } 
  
  if(validate_genboreeTrack() == false){ 
    return false; 
  } 

  return true;
}

/* Validate the expname */
function validate_expname()
{
  var expname = $F('expname');
  if( !expname || expname.length == 0 )
  {
    alert("You must enter an experiment name!" );
    highlight( 'expnameLabel' );
    $('expname').focus()
    return false;
  }
  else
  {
    newExpname = expname.replace(/\\|\!|\@|\#|\$|\%|\^|\&|\*|\(|\)|\+|\=|\||\;|\'|\>|\<|\/|\?/g, '_')
    if(newExpname != expname)
    {
      alert("Unacceptable letters in Experiment Name have been replaced with '_'.\n\nNew Experiment Name is: '" + newExpname + "'.\n");
      $('expname').value = newExpname ;
      highlight( 'expnameLabel' );
      $('expname').focus() ;
      return false;
    }
    else
    {
      unHighlight( 'expnameLabel' ); 
    }
  }
}

/* Validate that a track is selected */
function validate_track()
{
  if( $F('template_lff') == "selectATrack" )
  {
    alert( "You must select a track for primer design!" );
    highlight( 'trackLabel' );
    $('template_lff').focus()
    return false;
  }
  else
  {
    unHighlight( 'trackLabel' ); 
  }
}

/* Validate upstream padding */
function validate_upstreamPadding()
{
  if( validatePositiveInteger($F('upstreamPadding')) == false )
  {
    alert( "Upstream padding must be a positive integer!" );
    highlight( 'paddingLabel' );
    var upPad = $('upstreamPadding') ;
    upPad.focus()
    upPad.select()
    return false;
  }
  else
  {
    unHighlight( 'paddingLabel' ); 
  }
}

/* Validate downstream padding */
function validate_downstreamPadding()
{
  if( validatePositiveInteger($F('downstreamPadding')) == false )
  {
    alert( "Downstream padding must be a positive integer!" );
    highlight( 'paddingLabel' );
    var downPad = $('downstreamPadding') ;
    downPad.focus()
    downPad.select()
    return false;
  }
  else
  {
    unHighlight( 'paddingLabel' ); 
  }
}

/* Validate primerSizeMin */
function validate_primerSizeMin()
{
  if( validatePositiveInteger($F('primerSizeMin')) == false )
  {
    alert( "Primer Size Minimum must be a positive integer!" );
    highlight( 'primerLabel' );
    pSizeMin = $('primerSizeMin') ; 
    pSizeMin.focus() ;
    pSizeMin.select()
    return false;
  }
  else
  {
    unHighlight( 'primerLabel' ); 
  }
}

/* Validate primerSizeMax */
function validate_primerSizeMax()
{
  if( validatePositiveInteger($F('primerSizeMax')) == false )
  {
    alert( "Primer Size Maximum must be a positive integer!" );
    highlight( 'primerLabel' );
    var pSizeMax = $('primerSizeMax') ;
    pSizeMax.focus() ;
    pSizeMax.select() ;
    return false;
  }
  else
  {
    unHighlight( 'primerLabel' ); 
  }
}

/* Validate primerSizeOpt */
function validate_primerSizeOpt()
{
  if( validatePositiveInteger($F('primerSizeOpt')) == false )
  {
    alert( "Primer Size Optimum must be a positive integer!" );
    highlight( 'primerLabel' );
    var pSizeOpt = $('primerSizeOpt')
    pSizeOpt.focus()
    pSizeOpt.select()
    return false;
  }
  else
  {
    unHighlight( 'primerLabel' ); 
  }
}

/* Validate primerTmMin */
function validate_primerTmMin()
{
  if( validatePositiveNumber($F('primerTmMin')) == false )
  {
    alert( "Primer Tm Minimum must be a positive number!" );
    highlight( 'primerLabel' );
    var pTmMin = $('primerTmMin') ;
    pTmMin.focus()
    pTmMin.select()
    return false;
  }
  else
  {
    unHighlight( 'primerLabel' ); 
  }
}


/* Validate primerTmMax */
function validate_primerTmMax()
{  
  if( validatePositiveNumber($F('primerTmMax')) == false )
  {
    alert( "Primer Tm Maximum must be a positive number!" );
    highlight( 'primerLabel' );
    var primerTmMax = $('primerTmMax') ;
    primerTmMax.focus() ;
    primerTmMax.select() ;
    return false;
  }
  else
  {
    unHighlight( 'primerLabel' ); 
  }
}

/* Validate primerTmOpt */
function validate_primerTmOpt()
{  
  if( validatePositiveNumber($F('primerTmOpt')) == false )
  {
    alert( "Primer Tm Optimum must be a positive number!" );
    highlight( 'primerLabel' );
    var primerTmOpt = $('primerTmOpt') ;
    primerTmOpt.focus() ;
    primerTmOpt.select() ;
    return false;
  }
  else
  {
    unHighlight( 'primerLabel' ); 
  }
}

/* Validate ampliconTmMin */
function validate_ampliconTmMin()
{
  var ampliconTmMin = $F('ampliconTmMin')
  if(( ampliconTmMin.length > 0 ) && (validatePositiveNumber(ampliconTmMin) == false))
  {
    alert( "Amplicon Tm Minimum must be a positive number!" );
    highlight( 'primerLabel' );
    var ampliconTmMin = $('ampliconTmMin') ;
    ampliconTmMin.focus() ;
    ampliconTmMin.select() ;
    return false;
  }
  else
  {
    unHighlight( 'primerLabel' ); 
  }
}

/* Validate ampliconTmMax */
function validate_ampliconTmMax(){
  var ampliconTmMax = $F('ampliconTmMax')
  if(( ampliconTmMax.length > 0 ) && (validatePositiveNumber(ampliconTmMax) == false))
  {
    alert( "Amplicon Tm Maximum must be a positive number!" );
    highlight( 'primerLabel' );
    var ampliconTmMax = $('ampliconTmMax') ;
    ampliconTmMax.focus() ;
    ampliconTmMax.select() ;
    return false;
  }
  else
  {
    unHighlight( 'primerLabel' ); 
  }
}

/* Validate ampliconTmOpt */
function validate_ampliconTmOpt(){
  var ampliconTmOpt = $F('ampliconTmOpt')
  if(( ampliconTmOpt.length > 0 ) && (validatePositiveNumber(ampliconTmOpt) == false))
  {
    alert( "Amplicon Tm Optimum must be a positive number!" );
    highlight( 'primerLabel' );
    var ampliconTmOpt = $('ampliconTmOpt') ;
    ampliconTmOpt.focus() ;
    ampliconTmOpt.select() ;
    return false;
  }
  else
  {
    unHighlight( 'primerLabel' ); 
  }
}

/* Validate primerGcMin */
function validate_primerGcMin()
{
  var primerGcMin = $F('primerGcMin')
  if(( primerGcMin.length > 0 ) && (validatePositiveNumber(primerGcMin) == false))
  {
    alert( "Primer Minimum GC% must be a positive number!" );
    highlight( 'primerLabel' );
    var primerGcMin = $('primerGcMin') ;
    primerGcMin.focus() ;
    primerGcMin.select() ;
    return false;
  }
  else
  {
    unHighlight( 'primerLabel' ); 
  }
}


/* Validate primerGcMax */
function validate_primerGcMax()
{
  var primerGcMax = $F('primerGcMax')
  if(( primerGcMax.length > 0 ) && (validatePositiveNumber(primerGcMax) == false))
  {
    alert( "Primer Maximum GC% must be a positive number!" );
    highlight( 'primerLabel' );
    var primerGcMax = $('primerGcMax') ;
    primerGcMax.focus() ;
    primerGcMax.select() ;
    return false;
  }
  else
  {
    unHighlight( 'primerLabel' ); 
  }
}

/* Validate primerGcOpt */
function validate_primerGcOpt(){
  var primerGcOpt = $F('primerGcOpt')
  if(( primerGcOpt.length > 0 ) && (validatePositiveNumber(primerGcOpt) == false))
  {
    alert( "Primer Optimum GC% must be a positive number!" );
    highlight( 'primerLabel' );
    var primerGcOpt = $('primerGcOpt') ;
    primerGcOpt.focus() ;
    primerGcOpt.select() ;
    return false;
  }
  else
  {
    unHighlight( 'primerLabel' ); 
  }
}

/* Validate maxSelfComp */
function validate_maxSelfComp()
{  
  if( validatePositiveNumber($F('maxSelfComp')) == false )
  {
    alert( "Primer Maximum Self Complementarity must be a positive number!" );
    highlight( 'primerLabel' );
    var maxSelfComp = $('maxSelfComp') ;
    maxSelfComp.focus() ;
    maxSelfComp.select() ;
    return false;
  }
  else
  {
    unHighlight( 'primerLabel' ); 
  }
}

/* Validate ampliconSizeRange */
function validate_ampliconSizeRanges()
{
  var splitSizeRanges = $F('ampliconSizeRange').split(' ')
  var maxPrimerSize = $F('primerSizeMax') ;
  for(ii=0; ii<splitSizeRanges.length; ii++)
  {
    if( ! validateRange(splitSizeRanges[ii]) )
    {
      alert( "Amplicon Size Range must be in the form number-number (eg 50-1000)!\n\nSeparate multiple ranges with a SINGLE space.\n\n" );
      highlight( 'primerLabel' );
      var ampliconSizeRange = $('ampliconSizeRange') ;
      ampliconSizeRange.focus() ;
      ampliconSizeRange.select() ;
      return false;
    }
    else if( ! validate_ampliconSizeRange( splitSizeRanges[ii], maxPrimerSize ))
    {
      alert("The minimum amplicon size cannot be less than then maximum primer size!") ;
      highlight( 'primerLabel' );
      var ampliconSizeRange = $('ampliconSizeRange') ;
      ampliconSizeRange.focus() ;
      ampliconSizeRange.select() ;
      return false ;
    }  
    else
    {
      unHighlight( 'primerLabel' ); 
    }
  }
  return true ;
}

/* Validate Genboree track name if to be uploaded */
function validate_genboreeTrack()
{
  // Validate Primer Track
  if($('makeGenboreeTrack').checked)
  {
    var trackTypeName = $F('trackTypeName');
    if( !trackTypeName || trackTypeName.length == 0 )
    {
      alert("You must enter a Genboree primer track type!" );
      highlight( 'primerTrack' );
      var trackTypeName = $('trackTypeName') ;
      trackTypeName.focus() ;
      trackTypeName.select() ;
      return false;
    }
    else
    {
      unHighlight( 'primerTrack' ); 
    }
      
    var trackSubtypeName = $F('trackSubtypeName');
    if( !trackSubtypeName || trackSubtypeName.length == 0 )
    {
      alert("You must enter a Genboree primer track name!" );
      highlight( 'primerTrack' );
      var trackSubtypeName = $('trackSubtypeName') ;
      trackSubtypeName.focus() ;
      trackSubtypeName.select() ;
      return false;
    }
    else
    {
      unHighlight( 'primerTrack' ); 
    }
  }
  
  // Validate Amplicon Track
  if($('makeGenbAmpTrack').checked)
  {
    var ampTypeName = $F('ampTypeName');
    if( !ampTypeName || ampTypeName.length == 0 )
    {
      alert("You must enter a Genboree amplicon track type!" );
      highlight( 'ampTrack' );
      var ampTypeName = $('ampTypeName') ;
      ampTypeName.focus() ;
      ampTypeName.select() ;
      return false;
    }
    else
    {
      unHighlight( 'ampTrack' ); 
    }
      
    var ampSubtypeName = $F('ampSubtypeName');
    if( !ampSubtypeName || ampSubtypeName.length == 0 )
    {
      alert("You must enter a Genboree amplicon track subtype!" );
      highlight( 'ampTrack' );
      var ampSubtypeName = $('ampSubtypeName') ;
      ampSubtypeName.focus() ;
      ampSubtypeName.select() ;
      return false;
    }
    else
    {
      unHighlight( 'ampTrack' ); 
    }
  }
}

/* Below pertains to input validation */
function validatePositiveInteger( strValue )
{
  var objRegExp  = /^\d+$/;

  //check for integer characters
  return objRegExp.test(strValue);
}

function  validatePositiveNumber( strValue )
{
  var objRegExp  =  /^(\d+\.\d*)|(\d+)|(\.\d+)$/;
  //check for numeric characters
  return objRegExp.test(strValue);
}

function validate_ampliconSizeRange( strValue, maxPrimerSize)
{
  var reObj = /^(\d+)\-(\d+)$/ ;
  var matches = reObj.exec(strValue) ;
  var rangeMin = matches[1] ;
  var rangeMax = matches[2] ;
  if( matches.index == 0 )
  {
    if( rangeMin <= maxPrimerSize)
    {
      return false ;
    }
    return true ;
  }
  else
  {
    return false ;
  }
}

function  validateRange( strValue )
{
  var objRegExp  =  /^\d+\-\d+$/;
  //check for numeric characters
  return objRegExp.test(strValue);
}

function highlight( id ){ 
  $(id).style["color"] = "#FF0000";
}

function unHighlight( id ){ 
  $(id).style["color"] = "#000000";
}

function primer3_overlibHelp(primer3Parameter)
{
  var overlibCloseText = '<FONT COLOR=white><B>X&nbsp;</B></FONT>' ;
  var leadingStr = '&nbsp;<BR>' ;
  var trailingStr = '<BR>&nbsp;' ;
  var helpText;
  
  if(primer3Parameter == "expname")
  {
    overlibTitle = "Help: Experiment Name" ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Give this primer3 experiment a name.</LI>" ;
    helpText += "  <LI>You will use this name to retrieve your results later!</LI>" ;
    helpText += "</UL>\n\n" ;
  }
  else if(primer3Parameter == "template_track")
  {
    overlibTitle = "Help: Template Track" ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Select an annotation track to design primers against.</LI>" ;
    helpText += "  <LI>Each annotation in the track will be treated as a template for which primers are desired.</LI>" ;
    helpText += "  <LI>Primer3 may output multiple primer-pairs for each template.</LI>" ;
    helpText += "</UL>\n\n" ;
  }
  else if(primer3Parameter == "padding")
  {
    overlibTitle = "Help: Annotation Padding" ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Indicate the number of upstream and downstream basepairs to add ('pad') around each annotation." ;
    helpText += "  <LI>These basepairs will part of the template." ;
    helpText += "  <LI>You can choose to design primers ONLY in the padded regions, to help obtain primer pairs that span the annotations."
    helpText += "</UL>\n\n";
  }
  else if(primer3Parameter == "primerSize" )
  {
    overlibTitle = "Help: Primer Size" ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Minimum, Optimum, and Maximum lengths (bp) of a primer oligo.</LI>\n" ;
    helpText += "  <LI>Primer3 will not pick primers shorter than Min or longer than Max, and will attempt to pick primers close to the Optimal size.</LI>\n" ;
    helpText += "  <LI>Min cannot be smaller than 1.</LI>\n" ;
    helpText += "  <LI>Max cannot be larger than 36.</LI>\n" ;
    helpText += "</UL>\n\n";  
  }
  else if(primer3Parameter == "primerTm" )
  {
    overlibTitle = 'Help: Primer Tm' ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Minimum, Optimum, and Maximum melting temperatures (Celsius) for a primer oligo.</LI>\n" ;
    helpText += "  <LI>Primer3 will not pick oligos with Tm smaller than Min or larger than Max, and will try to pick primers with melting temperatures close to Optimal Tm.</LI>\n" ;
    helpText += "</UL>\n\n";  
  }
  else if(primer3Parameter == "ampliconTm" )
  {
    overlibTitle = 'Help: Amplicon Tm' ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>The Minimum, Optimum, and Maximum melting temperature of the amplicon.</LI>\n" ;
    helpText += "  <LI>Primer3 will not pick a product with melting temperature less than Min or greater than Max, and close to Optimal.</LI>\n" ;
    // helpText += "  <LI>If Optimal is supplied and the Penalty Weights for Product Size are non-0 Primer3 will attempt to pick an amplicon with melting temperature close to Opt.</LI>\n" ;
    helpText += "  <LI>These are optional parameters and are not required.</LI>\n" ;
    helpText += "</UL>\n\n";  
  }
  else if(primer3Parameter == "primerGc" )
  {
    overlibTitle = 'Help: Primer GC%' ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Minimum, Optimum, and Maximum percentage of Gs and Cs in any primer..</LI>\n" ;
    helpText += "  <LI>These are optional parameters and are not required.</LI>\n" ;
    helpText += "</UL>\n\n";  
  }
   else if(primer3Parameter == "ampliconSizeRange" )
  {
    overlibTitle = 'Help: Amplicon Size Range' ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>A list of product size ranges, separated by a SINGLE space.</LI>\n" ;
    helpText += "  <LI>For example:<BR>&nbsp;&nbsp; 150-250 100-300 301-400</LI>\n" ;
    helpText += "  <LI>Primer3 tries to pick primers in the first range.</LI>\n" ;
    helpText += "  <LI>If not possible, it tries each successive range.</LI>\n" ;
    helpText += "</UL>\n\n";  
  }
  else if(primer3Parameter == "maxSelfComp" )
  {
    overlibTitle = 'Help: Primer Maximum Self Complementarity' ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>The maximum allowable local alignment score when testing a single primer for (local) self-complementarity.</LI>\n" ;
    helpText += "  <LI>Also the maximum allowable local alignment score when testing for complementarity between left and right primers.</LI>\n" ;
    helpText += "</UL>\n\n";
  }
  else if(primer3Parameter == "primerTrack" )
  {
    overlibTitle = 'Help: Primer Track' ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>If 'Upload Primers as Genboree Track' is checked, a track containing the primers will be created to Genboree.</LI>\n" ;
    helpText += "  <LI>A Track 'Type' and Track 'Subytpe' must be provided for this option.</LI>\n" ;
    helpText += "  <LI>The track name will look like:<BR>&nbsp;&nbsp;  Type:Subtype</LI>\n" ;
    helpText += "</UL>\n\n";
  }
  else if(primer3Parameter == "ampTrack" )
  {
    overlibTitle = 'Help: Amplicon Track' ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>If 'Upload Amplicons as Genboree Track' is checked, a track containing the amplicons will be created to Genboree.</LI>\n" ;
    helpText += "  <LI>A Track 'Type' and Track 'Subytpe' must be provided for this option.</LI>\n" ;
    helpText += "  <LI>The track name will look like:<BR>&nbsp;<BR>&nbsp;&nbsp;Type:Subtype</LI>\n" ;
    helpText += "</UL>\n\n";
  }
  overlibBody = helpText;
  return overlib( overlibBody, STICKY, DRAGGABLE, CLOSECLICK, FGCOLOR, '#CCF8FF', BGCOLOR, '#9F833F', 
                  CAPTIONFONTCLASS, 'capFontClass', CAPTION, overlibTitle, CLOSEFONTCLASS, 'closeFontClass',
                  CLOSETEXT, overlibCloseText, WIDTH, '300');
    
}

function makeGenboreeTrackHandler(chkbox, event)
{
  var primerTrackChkbox = $('makeGenboreeTrack') ;
  var ampTrackChkbox = $('makeGenbAmpTrack') ;
  
  if(chkbox == primerTrackChkbox)
  {
    if(chkbox.checked)
    {
      $('trackTypeName').disabled = "" ;
      $('trackSubtypeName').disabled = "" ;
    }
    else
    {
      $('trackTypeName').disabled = "disabled" ;
      $('trackSubtypeName').disabled = "disabled" ;
    }
  }
  else if(chkbox == ampTrackChkbox)
  {
    if(chkbox.checked)
    {
      $('ampTypeName').disabled = "" ;
      $('ampSubtypeName').disabled = "" ;
    }
    else
    {
      $('ampTypeName').disabled = "disabled" ;
      $('ampSubtypeName').disabled = "disabled" ;
    }
  }
  return ;
}