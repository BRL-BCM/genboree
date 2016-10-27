addEvent(window, "load", showtext_init);

var commentsWrapped = false ;
var origComments = null ;

function showtext_init()
{
  // wrap the comments and setup "restore"
  var defaultElemName = 'commentContent' ;
  roughFormatText(defaultElemName, $('commentDelims').value) ;
  $('commentFormatBtn').value = "Restore Comments" ;
  commentsWrapped = true ;
}




function processDisplayChange () {
$('app').value = $('app1').value;
$('editorForm').submit();
}



function dispatchWrapComments(elementName, delims)
{
  if(commentsWrapped) // then user already wrapped the comments, restore via reload
  {
    var elems = document.getElementsByName(elementName) ;
    for(var ii = 0; ii < elems.length; ii++)
    {
      elems[ii].innerHTML = origComments[ii] ;
    }
    $('commentFormatBtn').value = "Wrap Comments" ;
    commentsWrapped = false ;
    // OLD WAY: // window.location.reload() ;
  }
  else // wrap the comments and setup "restore"
  {
    roughFormatText(elementName, delims) ;
    $('commentFormatBtn').value = "Restore Comments" ;
    commentsWrapped = true ;
  }
}

// This function gets the inner HTML for all tags with name and id attributes
// equal to elementName and puts a <BR> after each delimiter character found.
// Then it replaces the inner HTML.
// NOTE: use on the last layer of HTML tags only, because it will replace *all*
// delimiters in the inner HTML, even those that are part of HTML tags!
// NOTE: for portability, make sure to provide name= AND id= attributes for the
// tags! This works around a bug in IE implementation of getElementsByName().
// NOTE: to process multiple bits of text this way, you can use <SPAN> tags and
// give each <SPAN> the same name= and id= as the others. (This is how all
// comments are processed on the Annotation Group Details page).
function roughFormatText(elementName, delims)
{
  // Create the Regular Expression
  if(delims == "") return;
  var delimsREstr = delims.replace(/(.)/g, "(?:\\$1\\s?)") ;
  delimsREstr = "(" + delimsREstr.replace(/\)\(/g, ")|(") + ")" ;
  var re = new RegExp(delimsREstr, "g") ;

  // Apply the Regular Expression to each element named elementName.
  var elems = document.getElementsByName(elementName) ;
  origComments = new Array(elems.length) // Place to save original comments
  
  for(var ii = 0; ii < elems.length; ii++)
  {
    var elem = elems[ii] ;
    origComments[ii] = elem.innerHTML ;
    
    var innerHtml = elem.innerHTML ;
    // Freeze common parsed entities (eg &gt;, &lt;, &nbsp;)
    innerHtml = freezeParsedEntities(innerHtml);
    // Apply newlines at the delimiters
    innerHtml = innerHtml.replace(re, "$1<BR>") ;
    // Unfreeze common parsed entities
    innerHtml = unfreezeParsedEntities(innerHtml) ;
    elem.innerHTML = innerHtml ;
  }
}

// Tags parsed entities to make it unlikely the arbitrary string replacements
// will modify them. Use unfreezeParsedEntities to restore them after string
// maniuplation.
// Note: this is VERY simple and geared mainly toward protecting parsed entities from
// being modified as common delimiters (mainly punctuation like ';')
function freezeParsedEntities(htmlText)
{
  htmlText = htmlText.replace(/&gt;/g, "\t\t\001\t\t") ;
  htmlText = htmlText.replace(/&lt;/g, "\t\t\002\t\t") ;
  htmlText = htmlText.replace(/&nbsp;/g, "\t\t\003\t\t") ;
  htmlText = htmlText.replace(/&quot;/g, "\t\t\004\t\t") ;
  return htmlText ;
}

function unfreezeParsedEntities(frozenText)
{
  frozenText = frozenText.replace(/\t\t\001\t\t/, "&gt;") ;
  frozenText = frozenText.replace(/\t\t\002\t\t/, "&lt;") ;
  frozenText = frozenText.replace(/\t\t\003\t\t/, "&nbsp;") ;
  frozenText = frozenText.replace(/\t\t\004\t\t/, "&quot;") ;
  return frozenText ;
}

