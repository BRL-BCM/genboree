// -----------------------------------------------------------------------------
// Convenient Globals
// -----------------------------------------------------------------------------
var form_downloadGM ;
var LONG_SEQ = 100000000 ;
var submitValue ;

//
// Uses extjs library
//
//
Ext.namespace('Ext.genboree');

Ext.genboree = function()
{
  var epSizes = $H() ;
  var sortedEpNames = new Array() ;
  return  {
            init: function()
            {
              // Populate entrypoints drop list and init convenient hash
              if(entryPointSizes.size() > 0) // Currently this is global from the including page (should fix it to use Ext.genboree)
              {
                // Sort the entrypoint names sensibly
                var sortedEpNames = entryPointNames.sort( function(aa, bb)
                                    {
                                      var retVal = 0 ;
                                      var xx = aa.gsub(/^chr/i, '').toLowerCase() ;
                                      var yy = bb.gsub(/^chr/i, '').toLowerCase() ;
                                      if(/^\d/.test(xx) && /^\d/.test(yy))
                                      {
                                        retVal = ( (parseInt(xx) < parseInt(yy)) ? -1 : ((parseInt(xx) > parseInt(yy)) ? 1 : 0) ) ;
                                      }
                                      else if(/^\d/.test(xx))
                                      {
                                        retVal = -1 ;
                                      }
                                      else if(/^\d/.test(yy))
                                      {
                                        retVal = 1 ;
                                      }
                                      else // neither is looking number-able, sort via strings
                                      {
                                        if(/^[xy]/.test(xx) && /^[xy]/.test(yy))
                                        {
                                          retVal = ( (xx < yy) ? -1 : ((xx > yy) ? 1 : 0) ) ;
                                        }
                                        else if(/^[xy]/.test(xx))
                                        {
                                          retVal = -1 ;
                                        }
                                        else if(/^[xy]/.test(yy))
                                        {
                                          retVal = 1 ;
                                        }
                                        else
                                        {
                                          retVal = 0 ;
                                        }
                                      }
                                      // resolve ties if possible
                                      if(retVal == 0)
                                      {
                                        retVal = ( (aa < bb) ? -1 : ((aa > bb) ? 1 : 0) ) ;
                                      }
                                      return retVal ;
                                    }) ;
                for(var ii=0; ii<entryPointSizes.size(); ii++)
                {
                  epSizes[entryPointNames[ii]] = entryPointSizes[ii] ;
                }
                var refNameSelect = $('refName') ;
                for(var ii=0; ii<sortedEpNames.size(); ii++)
                {
                  var option = document.createElement("option") ;
                  Element.extend(option) ;
                  if(sortedEpNames[ii] == annoRefSeq) // annoRefSeq currently a global from the including page
                  {
                    option.selected = true ;
                  option.addClassName('txthilit') ;
                  }
                  option.value = sortedEpNames[ii] ;
                  option.update(sortedEpNames[ii]) ;
                  refNameSelect.appendChild(option) ;
                }
              }
            },
            epSizes: function()
            {
              return epSizes ;
            },
            sortedEpNames: function()
            {
              return sortedEpNames ;
            }
          } ;
}() ;
Ext.onReady(Ext.genboree.init, Ext.genboree, true) ;
Ext.onReady(initUIControls) ;

// -----------------------------------------------------------------------------
// Generic Functions
// - these methods, or variations of these, could be put in a general library
// -----------------------------------------------------------------------------
// Gets an integer value from a form input element
// (or from any element responding to '.value')
function getIntValue( inputObj, def )
{
  var sVal = inputObj.value ;
  var ic = sVal.indexOf(",") ;
  while( ic >= 0 )
  {
    sVal = sVal.substring(0,ic) + sVal.substring(ic+1) ;
    ic = sVal.indexOf(",") ;
  }
  ic = sVal.indexOf(".") ;
  if( ic >= 0 )
  {
    sVal = sVal.substring(0, ic) ;
  }
  var iVal = def ;
  if( sVal != "" && !isNaN(parseInt(sVal)) ) iVal = parseInt(sVal) ;
  return iVal ;
}

// Returns the checked radio button as an element object,
// if any any such radio button element exists. If no radio buttons labelled
// with the given id, or no radio buttons at all, or no checked radio button,
// it will return null.
function getCheckedRadioButton(formName, radioButtonId)
{
  var retVal = null ;
  var formObj = $(formName) ;
  var radioGroup = formObj.elements[radioButtonId] ;
  if(radioGroup.length)
  {
    for(var ii=0 ; ii < radioGroup.length ; ii++)
    {
      if(radioGroup[ii].checked)
      {
        retVal = radioGroup[ii] ;
        break ;
      }
    }
  }
  else
  {
    retVal = radioGroup ;
  }
  return retVal ;
}

// Returns the first input element whose id and value matches the arguments,
// regardless of its type. This is useful when trying to find a particular
// element amongst a bunch of elements who all have the same id. Eg, finding
// a particular radio button in some cases.
// If no such element exists, it will return null.
function getElementByIdAndValue(formName, elemId, elemValue)
{
  var retVal = null ;
  var formObj = $(formName) ;
  var elems = formObj.elements[elemId] ;
  if(elems && elems.length)
  {
    for(var ii=0 ; ii < elems.length ; ii++)
    {
      if(elems[ii].value == elemValue)
      {
        retVal = elems[ii] ;
        break ;
      }
    }
  }
  else // Maybe not multiple elements with this id, let's try to get the one-and-only.
  {
    retVal = elems ;
  }
  return retVal ;
}

// -----------------------------------------------------------------------------
// Page-Specific Functions
// -----------------------------------------------------------------------------
// Init the UI Controls appropriately. Called via ONLOAD event.
function initUIControls()
{
  form_downloadGM = $('downloadGM') ;
  submitValue = null ;
  // DISABLED: this doesn't appear to be doing the right thing, so it is turned off for now.
    // Use a trick here to see if we're coming back to this page via a "back" button press or something.
    // If we are, then the hidden 'isInit' input will have a value of 'true' and we don't want to reset anything.
    // If we aren't, then it's the first time this page has been loaded in the browser and we need to init everything.
  //  var isInit = $('isInit') ;
  //  if(isInit.value != 'true')
  //  {
    activateRightControls(initialState) ;
    selectStrand(initialStrand) ;
    isInit.value = 'true' ;
  // }
  /*else // already init'd
  {
    var chrName = $('refName').value ;
    if($('atRefName'))
    {
      $('atRefName').innerHTML = chrName ;
    }
    if($('gtRefName'))
    {
      $('gtRefName').innerHTML = chrName ;
    }
    if($('crRefName'))
    {
      $('crRefName').innerHTML = chrName ;
    }
  }*/
  $('chkEntire').checked = false ;
}

function dgdna_reset()
{
  activateRightControls(initialState) ;
  selectStrand(initialStrand) ;
  setLimits(original_from1, original_to1, original_refSeq) ;
  updateChromosomeSelected() ;
}

function setLimits(myFrom, myTo, myChromName)
{
  $('sequenceStart').value = myFrom ;
  $('sequenceEnd').value = myTo ;
  var isInit = $('isInit') ;
  $('refName').value = myChromName ;
}

function activateFields(seq_dis, chrom_dis)
{
  $('refName').disabled = chrom_dis ;
  $('chkEntire').disabled = chrom_dis ;
  $('sequenceStart').disabled = seq_dis ;
  $('sequenceEnd').disabled = seq_dis ;
}

function selectStrand(strand)
{
  var position = 0 ;
  if(strand == "+") { position = 0 ; }
  else if(strand == "-" ) { position = 1 ; }
  document.getElementsByName('strand')[position].checked = true ;
}

function selectSequenceType(sequenceType)
{
  // This approach is more robust than relying on position in an element
  // array, because changes to the pages (eg radio button order) breaks the positions.
  var radioElement = getElementByIdAndValue('downloadGM', 'sequenceType', sequenceType) ;
  radioElement.checked = true ;
}

function validateDGDNAForm()
{
  // Get the user's chromosome
  var chrName = $('refName').value ;
  // Get the start/stop of this chromosome
  var absStart = 1 ; // start of a chromosome is always 1
  var absStop = Ext.genboree.epSizes[chrName] ; // This hash is filled in on the .jsp page.
  //alert('chrName: ' + chrName + "\nabsStop: " + absStop) ;
  var sequenceStartObj = $('sequenceStart') ;
  var sequenceEndObj = $('sequenceEnd') ;

  // Check the from value ; warn if illegal
  var iFrom = getIntValue( sequenceStartObj, -1 ) ;
  if( iFrom < absStart || iFrom > absStop )
  {
    alert( '"From" value must be an integer number\nin the range '+ absStart +" to "+ absStop ) ;
    sequenceStartObj.value = absStart ;
    sequenceStartObj.focus() ;
    return false ;
  }

  // Check the to value ; warn if illegal
  var iTo = getIntValue( sequenceEndObj, -1 ) ;
  //alert('iFrom: ' + iFrom + "\niTo: " + iTo + "\nabsStart: " + absStart + "\nabsStop: " + absStop) ;
  if( iTo < absStart || iTo > absStop )
  {
    alert( '"To" value must be an integer number\nin the range '+ absStart+" to "+ absStop ) ;
    sequenceEndObj.value = absStop ;
    sequenceEndObj.focus() ;
    return false ;
  }

  if( iFrom > iTo )
  {
    alert( '"From" value must be less or equal than "To" value.' ) ;
    sequenceEndObj.value = iFrom ;
    sequenceStartObj.value = iTo ;
    sequenceEndObj.focus() ;
    return false ;
  }
  // Do we want to make a warning about lengthy download time?
  var proceed = (submitValue && submitValue=="View DNA") ? !isLongDownload() : true ;

  // IF start/END disabled, then set start/end to be enabled just before submitting
  // this ensures they are submitted.

  original_from1 ;
  return proceed ;
}

// Guess whether the download could take a long time or not.
function isLongDownload()
{
  var seqStart = $('sequenceStart').value ;
  var seqEnd = $('sequenceEnd').value ;
  var isLong = false ;

  var seqType = getCheckedRadioButton('downloadGM', 'sequenceType').value ;   // Which sequenceType radio button is checked?

  if(submitValue == 'View DNA')
  {
    if(seqType == 'stAnnTrack' || seqType == 'stAnnTrackConcat')
    {
      isLong = !confirm("WARNING:\nYou selected 'View DNA' rather than 'Save DNA' for ALL the annotations across one or more entire chromsomes.\n\nThe download could be massive and take a long time. Displaying such a huge file in your browser is NOT recommended.\n\nConsider 'Save DNA' instead.\n\nProceed anyway?\n") ;
    }
    else if(seqType == 'stGroupTrack')
    {
      isLong = !confirm("WARNING:\nYou have selected to 'View DNA' rather than 'Save DNA' for ALL the groups across one or more entire chromosomes.\n\nThe download could be massive and take a long time.\n\nConsider 'Save DNA' instead.\n\nDisplaying such a huge file in your browser is NOT recommended\n\nProceed anyway?\n") ;
    }
    else if(Math.abs(seqEnd - seqStart) > LONG_SEQ )
    {
      isLong = !confirm("WARNING:\nYou have selected to 'View DNA' for a very long segment of DNA.\n\nThe download will be large and take a long time. Displaying such a huge file in your browser is NOT recommended\n\nProceed anyway?\n") ;
    }
    else
    {
      isLong = false ;
    }
  }
  return isLong ;
}

function dgdna_overlibEg(sequenceType)
{
  var chrName = $('refName').value ;
  var overlibCloseText = '<FONT COLOR=white><B>X&nbsp ;</B></FONT>' ;
  var leadingStr = '&nbsp ;<BR>' ;
  var trailingStr = '<BR>&nbsp ;' ;
  var example1title = '<B>Example 1:</B><BR>' ;
  var example1body ;
  var example2title = '<P><B>Example 2:</B><BR>' ;
  var example2body ;

  if(sequenceType == "stAnnOnly")
  {
    overlibTitle = 'Ex: Annotation Only' ;
    example1body = "If the clicked annotation is an exon within a gene, this will retrieve the DNA at the exon's genomic coordinates." ;
    example2body = "If the annotation you clicked is a mapped BAC, this will retrieve the DNA at the mapped location within the genome." ;
  }
  else if(sequenceType == "stGroupRange" )
  {
    overlibTitle = "Ex: Annotation's Entire Group" ;
    example1body = "If the clicked annotation is an exon within a gene, this will retrieve the DNA spanning the <U>gene's</U> genomic coordinates." ;
    example2body = "If the annotation you clicked is uniquely-named (not part of a group), then this will retrieve the DNA spanning the annotation's genomic coordinates." ;
  }
  else if(sequenceType == "stAnnoGroup" )
  {
    overlibTitle = 'Ex: Each Annotation In Group' ;
    example1body = "If the clicked annotation is an exon within a gene, this will retrieve DNA sequences corresponding to the genomic coordinates of <U>each exon</U> within the gene." ;
    example2body = "If the annotation you clicked is one of the reads in a PGI index, this will retrieve genomic DNA sequences underlying the mapped location of <U>each read</U> within the PGI index." ;
  }
  else if(sequenceType == "stAnnConcat" )
  {
    overlibTitle = 'Ex: Concatenate Sequences' ;
    example1body = "If the clicked annotation is an exon within a gene, this will retrieve DNA sequences corresponding to the <u>genomic</u> coordinates of each exon within the gene, and <u>concatenate</u> them all together. Exon order and sequence subject to your <i>Strand:</i> selection below. Useful if you want a sequence to translate." ;
    example2body = "If you know your gene is on the reverse strand (relative to the reference sequence), select <i><nobr>minus (-)</nobr></i> below as well. Otherwise, you will get the plus strand sequence." ;
  }
  else if(sequenceType == "stAnnTrackConcat" )
  {
    overlibTitle = 'Ex: Concatenate Sequences For 1+ Groups' ;
    example1body = "If the clicked annotation is an exon within a gene, this will retrieve a DNA sequence for <u>each gene</u> on '" + chrName + "'. The sequence for the gene will be the result of concatenating the <i>genomic</i> sequence corresponding to each exon within the gene. Exon order and sequence subject to your <i>Strand:</i> selection below. Useful if you want a sequence to translate." ;
    example2body = "If you know your genes are on the reverse strand (relative to the reference sequence), select <i><nobr>minus (-)</nobr></i> below as well. Otherwise, you will get the plus strand sequence." ;
  }
  else if(sequenceType == "stAnnTrack" )
  {
    overlibTitle = 'Ex: ALL Annotations in Track On Chr' ;
    example1body = "If the clicked annotation is an exon within a gene, this will retrieve DNA sequences corresponding to the genomic coordinates of <U>ALL exons</U> on '" + chrName + "'." ;
    example2body = "If the annotation you clicked is one of the reads in a PGI index, this will retrieve genomic DNA sequences underlying the mapped location of <U>ALL reads</U> on '" + chrName + "'." ;
  }
  else if(sequenceType == "stGroupTrack" )
  {
    overlibTitle = 'Ex: ALL Groups in Track On Chr' ;
    example1body = "If the clicked annotation is an exon within a gene, this will retrieve DNA sequences spanning the genomic coordinates of <U>ALL genes</U> on '" + chrName + "'." ;
    example2body = "If the annotation you clicked is one of the reads in a PGI index, this will retrieve genomic DNA sequences spanning the genomic coordinates of <U>ALL PGI Indices</U> on '" + chrName + "'." ;
  }
  else if(sequenceType == "stCustomRange")
  {
    overlibTitle = 'Ex: Custom Range' ;
    example1body = "None -- you select the chromosome/entrypoint and the coordinates of the DNA sequence you want."
    example2body = "None." ;
  }
  else if(sequenceType == "titleExample" )
  {
    overlibTitle = 'Ex: Genomic Sequence Download' ;
    example1title = '<B>For example:</B><BR>' ;
    example1body = "Say we mapped some cow contigs onto the human genome and uploaded the mappings as annotations.<P>This service would retrieve genomic sequence corresponding to where contigs are mapped, not the sequence of the contigs themselves." ;
    example2title = example2body = '' ;
  }
  overlibBody = leadingStr + example1title + example1body + example2title + example2body + trailingStr ;
  return overlib( overlibBody, STICKY, DRAGGABLE, CLOSECLICK, FGCOLOR, '#CCF8FF', BGCOLOR, '#9F833F',
                  CAPTIONFONTCLASS, 'capFontClass', CAPTION, overlibTitle, CLOSEFONTCLASS, 'closeFontClass',
                  CLOSETEXT, overlibCloseText, WIDTH, '300') ;
}

function dgdna_overlibHelp(sequenceType)
{
  var chrName = $('refName').value ;
  var overlibCloseText = '<FONT COLOR=white><B>X&nbsp ;</B></FONT>' ;
  var leadingStr = '&nbsp ;<BR>' ;
  var trailingStr = '<BR>&nbsp ;' ;
  var helpText ;

  if(sequenceType == "stAnnOnly")
  {
    overlibTitle = "Help: Annotation Only" ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Retrieves the genomic DNA corresponding to the coordinates of the annotation you clicked.</LI>\n" ;
    helpText += "  <LI>Some annotations have their own sequences (eg. contigs) ; this will <U>not</U> retrieve such annotation-specific sequence, only the underlying <U>genomic</U> sequence.</LI>\n" ;
    helpText += "  <LI>This option returns a single sequence in FASTA format.</LI>\n" ;
    helpText += "  <LI>You may adjust the coordinates manually using the Start/End fields.</LI>\n" ;
    helpText += "</UL>\n\n" ;
  }
  else if(sequenceType == "stGroupRange" )
  {
    overlibTitle = "Help: Annotation's Entire Group" ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Retrieves the genomic DNA spanning the entire annotation group.</LI>\n" ;
    helpText += "  <LI>While you may have only clicked a single annotation within a set of grouped annotations, this option will retrieve the DNA sequence from the group start to the group end.</LI>\n" ;
    helpText += "  <LI>This option returns a single sequence in FASTA format.</LI>\n" ;
    helpText += "  <LI>You may adjust the coordinates manually using the Start/End fields.</LI>\n" ;
    helpText += "</UL>\n\n" ;
  }
  else if(sequenceType == "stAnnoGroup" )
  {
    overlibTitle = 'Help: Each Annotation In Group' ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Retrieves the genomic DNA sequences corresponding to <U>each annotation</U> in a group.</LI>\n" ;
    helpText += "  <LI>Some annotations have their own sequences (eg. contigs) ; this will <U>not</U> retrieve such annotation-specific sequence, only the underlying <U>genomic</U> sequences.</LI>\n" ;
    helpText += "  <LI>This option returns multiple sequences in FASTA format.</LI>\n" ;
    helpText += "</UL>\n\n" ;
  }
  else if(sequenceType == "stAnnTrack" )
  {
    overlibTitle = 'Help: ALL Annotations in Track On Chr' ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Retrieves the genomic DNA sequences corresponding to <U>ALL annotations</U> in the indicated track on '" + chrName + "'.</LI>\n" ;
    helpText += "  <LI>Some annotations have their own sequences (eg. contigs) ; this will <U>not</U> retrieve such annotation-specific sequence, only the underlying <U>genomic</U> sequences.</LI>\n" ;
    helpText += "  <LI>This option returns multiple sequences in FASTA format.</LI>\n" ;
    helpText += "  <LI>The 'Save DNA' button is recommended for this option because there may be 100,000's of annotations in this track on '" + chrName + "'.</LI>\n" ;
    helpText += "</UL>\n\n" ;
  }
  else if(sequenceType == "stGroupTrack" )
  {
    overlibTitle = 'Help: ALL Groups in Track On Chr' ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Retrieves the genomic DNA sequences corresponding to <U>ALL groups</U> in the indicated track on '" + chrName + "'.</LI>\n" ;
    helpText += "  <LI>For each set of grouped annotations (eg. exons in a gene), the start and stop of the group (eg. start/stop of a gene) will be used as genomic coordinates.</LI>\n" ;
    helpText += "  <LI>This option returns multiple sequences in FASTA format.</LI>\n" ;
    helpText += "  <LI>The 'Save DNA' button is recommended for this option because there may be 100,000's of annotation groups in this track on '" + chrName + "'.</LI>\n" ;
    helpText += "</UL>\n\n" ;
  }
  else if(sequenceType == "stCustomRange" )
  {
    overlibTitle = 'Help: Custom Range' ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Retrieves a genomic DNA sequence corresponding to coordinates on a chromosome/entrypoint of your choosing.</LI>\n" ;
    helpText += "  <LI>This option returns a single sequence in FASTA format.</LI>\n" ;
    helpText += "  <LI>If the length of your region is large, then the 'Save DNA' button is recommended for this option, because many web browsers cannot handle many MB of text easily.</LI>\n" ;
    helpText += "</UL>\n\n" ;
  }
  else if(sequenceType == "strand" )
  {
    overlibTitle = 'Help: Strand' ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Indicate which strand to read the DNA from.</LI>"
    helpText += "  <LI>The reference sequence is always considered the <i><nobr>plus (+)</nobr></i> strand.</LI>"
    helpText += "  <LI>NOTE: if you choose <i>minus (-)</i>, the annotation order and sequence will be read in the expected 5' to 3' order on the reverse strand. This is useful for negative-strand genes, for example.</LI>"
    helpText += "  <LI>NOTE: if you choose <i>use 'strand' field</i>, the annotation order ALWAYS will be taken from the <i><nobr>plus (+)</nobr></i> strand ; but the sequence of each annotation will be reverse complemented or not, according to its strand field in the database. This is useful for mate-pairs, for example.</LI>"
  }
  else if(sequenceType == "stAnnConcat" )
  {
    overlibTitle = 'Help: Concatenate Sequences' ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>The genomic DNA sequence of <u>each annotation</u> in the group will be concatenated together into a single sequence.</LI>"
    helpText += "  <LI>Some annotations have their own sequences (eg. mapped reads or cDNAs) ; this will <u>not</u> use such seqeunces, rather this uses the underlying <u>genomic</u> sequences.</LI>"
    helpText += "  <LI>This option returns a sequence in FASTA format.</LI>\n"
    helpText += "  <LI>NOTE: the concatenated sequence is subject to the <i>Strand:</i> option below.</LI>"
    helpText += "</UL>\n\n" ;
  }
  else if(sequenceType == "stAnnTrackConcat" )
  {
    overlibTitle = 'Help: Concatenate Sequences' ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>The genomic DNA sequence of <u>each annotation</u> in <u>each group</u> on the selected chromosome will be concatenated together into a single sequence for that group.</LI>"
    helpText += "  <LI>If you check <i>Select All Entry Points</i>, then this will be done for each annotations group in the whole genome.</LI>\n"
    helpText += "  <LI>Some annotations have their own sequences (eg. mapped reads or cDNAs) ; this will <u>not</u> use such seqeunces, rather this uses the underlying <u>genomic</u> sequences.</LI>"
    helpText += "  <LI>This option returns multiple sequences in FASTA format.</LI>\n"
    helpText += "  <LI>NOTE: the concatenated sequence is subject to the <i>Strand:</i> option below.</LI>"
    helpText += "</UL>\n\n" ;
  }
  else if(sequenceType == "hardRepMask" )
  {
    overlibTitle = 'Help: Repeatmasking' ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Checking this (if available) will give you <i>hard masked</i> repeats (with Ns) in the output sequence.</LI>" ;
    helpText += "  <LI>Most genomic templates within Genboree are already <i>soft masked</i> for repeats (lower case), and hard masked sequence is similarly available.</LI>" ;
    helpText += "  <LI>If no hard masked sequence is available for your database, please contact <a href='mailto:genboree_admin@genboree.org'>genboree_admin@genboree.org</a> to see what can be done.</LI>" ;
    helpText += "</UL>\n\n" ;
  }
  overlibBody = helpText ;
  return overlib( overlibBody, STICKY, DRAGGABLE, CLOSECLICK, FGCOLOR, '#CCF8FF', BGCOLOR, '#9F833F',
                  CAPTIONFONTCLASS, 'capFontClass', CAPTION, overlibTitle, CLOSEFONTCLASS, 'closeFontClass',
                  CLOSETEXT, overlibCloseText, WIDTH, '300') ;
}

function setEntryPointId()
{
  if($('chkEntire').checked)
  {
    $('refName').selectedIndex = 0 ;
    $('chkEntire').value = "y" ;
    $('chkEntire').disabled = false ;
    updateChromosomeSelected(false) ;
  }
  else
  {
    $('refName').value = defaultValue ;
    $('chkEntire').value = "n" ;
    $('chkEntire').disabled = false ;
    updateChromosomeSelected(false) ;
  }
  return ;
}

function updateChromosomeSelected(updateCheckBox)
{
  if($('stCustomRange').checked && $('refName').selectedIndex == 0)
  {
    alert(  "You cannot specify a custom range across multiple entrypoints/chromsomes.\nThat doesn't make sense.\n\n" +
            "You will need to select a specific entrypoint/chromosme (we reset it to the first one).") ;
    $('refName').selectedIndex = 1 ;
  }
  var chrName = $('refName').value ;
  if($('atRefName'))
  {
    $('atRefName').innerHTML = chrName ;
  }
  if($('gtRefName'))
  {
    $('gtRefName').innerHTML = chrName ;
  }
  if($('crRefName'))
  {
    $('crRefName').innerHTML = chrName ;
  }
  // Clear checkbox if needed
  if(updateCheckBox)
  {
    if($('refName').selectedIndex == 0)
    {
      $('chkEntire').checked = true ;
    }
    else
    {
      $('chkEntire').checked = false ;
    }
  }
  return ;
}

function activateRightControls(sequenceType)
{
  var refNameInput = $('refName') ;
  chrName = refNameInput.value ;
  fieldRadio = getElementByIdAndValue('downloadGM', 'strand', 'field') ;
  fieldRadio.disabled = false ;

  if(sequenceType == "stAnnOnly")
  {
    setLimits(original_from1, original_to1, original_refSeq) ;
    activateFields(false, true) ;
    selectSequenceType(sequenceType) ;
    $('chkEntire').checked = false ;
  }
  else if(sequenceType == "stAnnoGroup" )
  {
    setLimits(original_from2, original_to2, original_refSeq) ;
    activateFields(true, true) ;
    selectSequenceType(sequenceType) ;
    $('chkEntire').checked = false ;
  }
  else if(sequenceType == "stAnnConcat" )
  {
    setLimits(original_from2, original_to2, original_refSeq) ;
    activateFields(true, false) ;
    selectSequenceType(sequenceType) ;
    fieldRadio.disabled = true ;
    fieldRadio.checked = false ;
    plusRadio = getElementByIdAndValue('downloadGM', 'strand', 'plus') ;
    plusRadio.checked = true ;
    setEntryPointId() ;
    setEntryPointId() ;
    $('chkEntire').disabled = true ;
  }
  else if(sequenceType == "stAnnTrackConcat" )
  {
    setLimits(original_from2, original_to2, original_refSeq) ;
    // disable seq start/stop and chrom droplist/checkbox?
    activateFields(true, false) ;
    selectSequenceType(sequenceType) ;
    fieldRadio.disabled = true ;
    fieldRadio.checked = false ;
    plusRadio = getElementByIdAndValue('downloadGM', 'strand', 'plus') ;
    plusRadio.checked = true ;
    setEntryPointId() ;
  }
  else if(sequenceType == "stGroupRange" )
  {
    setLimits(original_from2, original_to2, original_refSeq) ;
    activateFields(false, true) ;
    selectSequenceType(sequenceType) ;
    fieldRadio.disabled = true ;
    fieldRadio.checked = false ;
    plusRadio = getElementByIdAndValue('downloadGM', 'strand', 'plus') ;
    plusRadio.checked = true ;
    $('chkEntire').checked = false ;
  }
  else if(sequenceType == "stAnnTrack" )
  {
    setLimits(from3, to3, refName ) ;
    activateFields(true, false) ;
    selectSequenceType(sequenceType) ;
    setEntryPointId() ;
  }
  else if(sequenceType == "stGroupTrack" )
  {
    setLimits(from3, to3, refName) ;
    activateFields(true, false) ;
    selectSequenceType(sequenceType) ;
    fieldRadio.disabled = true ;
    fieldRadio.checked = false ;
    plusRadio = getElementByIdAndValue('downloadGM', 'strand', 'plus') ;
    plusRadio.checked = true ;
    setEntryPointId() ;
  }
  else if(sequenceType == "stCustomRange")
  {
    var seqStart = $('sequenceStart').value ;
    var seqEnd = $('sequenceEnd').value ;
    setLimits(seqStart, seqEnd, refNameInput.value) ;
    refName = chrName
    activateFields(false, false) ;
    selectSequenceType(sequenceType) ;
    fieldRadio.disabled = true ;
    fieldRadio.checked = false ;
    plusRadio = getElementByIdAndValue('downloadGM', 'strand', 'plus') ;
    plusRadio.checked = true ;
    if($('chkEntire').checked)
    {
      alert(  "You cannot specify a custom range across multiple entrypoints/chromsomes.\nThat doesn't make sense.\n\n" +
              "You will need to select a specific entrypoint/chromosme (we reset it to the first one).") ;
      $('chkEntire').checked = false ;
      $('refName').selectedIndex = 1 ;
      updateChromosomeSelected(false) ;
    }
    $('chkEntire').disabled = true ;
  }
}
