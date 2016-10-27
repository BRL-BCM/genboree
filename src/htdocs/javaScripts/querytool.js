
// Assumes these variables are present on including page:
// - attributeList (url-escaped strings)
// - attributeServerList (html-escaped strings)

var datatypes = [ "text", "number", "boolean" ] ;
var textOperations = [ "=", "!=", "is empty", "is not empty", "contains", "not contains", "begins with", "not begins with", "ends with", "not ends with", "is present", "is not present" ];
var numberOperations = [ ">", "<", ">=", "<=", "=", "!=", "between", "not between", "is present", "is not present" ];
var booleanOperations = [ "is true", "is false" ];
var junction = ["and", "or"];
var fixedAttributes = $H({
                        'Anno. Class': 'lffClass',
                        'Anno. Type': 'lffType',
                        'Anno. Subtype': 'lffSubtype',
                        'Anno. Name': 'lffName',
                        'Anno. Chrom.': 'lffChr',
                        'Anno. Start': 'lffStart',
                        'Anno. Stop': 'lffStop',
                        'Anno. Length': 'lffLength',
                        'Anno. Strand': 'lffStrand',
                        'Anno. Phase': 'lffPhase',
                        'Anno. Score': 'lffScore',
                        'Anno. QStart': 'lffQStart',
                        'Anno. QStop': 'lffQStop',
                        'Anno. Seq': 'lffSeq',
                        'Anno. Comments': 'lffFreeComments'
                      });
// An operation was selected, show correct values, etc.
function setOperation(n)
{
  var dataid = 'datatypeId' + n ;
  var datatype = $(dataid).value ;

  // ---- Treating as NUMBER ----
  if(datatype=="number")
  {
    // Show the number-criteria div, hide all the other ones
    $('stropdiv' + n ).style.display = "none" ;
    $('booopdiv' + n ).style.display = "none" ;
    $('checkdivid' + n ).style.display = "none" ;
    $('numopdiv'+ n).style.display = "block" ;

    // Get the operation
    var operation = $("numoperationid" + n).value ;

    // --> BETWEEN-type operation
    if(operation.indexOf('between') >= 0)
    {
      // Show left and right value inputs, plus the static "and" word
      // Hide other value input(s)
      $('operandB' + n ).style.display = "block" ;
      $('operand0A' + n ).style.display = "block" ;
      $('operandAND' + n ).style.display = "block" ;
      $('operandA' + n ).style.display = "none" ;
      $('startValue' + n).style.backgroundColor = "white" ;
      $('valueB' + n).style.backgroundColor = "white" ;
    }
    else // Is not a multi-value type of operation
    {
      // --> IS PRESENT-type operation
      if((operation.indexOf('present') < 0) && (operation.indexOf('empty') < 0 ))
      {
        // Hide all value inputs
        $('valueA' + n).style.backgroundColor =  "white" ;
        $('operandA' + n ).style.display = "block" ;
        $('operandB' + n ).style.display = "none" ;
        $('operand0A' + n ).style.display = "none" ;
        $('operandAND' + n ).style.display = "none" ;
      }
      else // --> a regular operations, show single value input
      {
        $('operandA' + n ).style.display = "none" ;
        $('operandB' + n ).style.display = "none" ;
        $('operand0A' + n ).style.display = "none" ;
        $('operandAND' + n ).style.display = "none" ;
      }
    }
  }
  // ---- Treating as BOOLEAN ----
  else if(datatype=="boolean")
  {
    // Show boolean-criteria div, hide others.
    // Hide values they aren't needed for boolean operations.
    $('stropdiv' + n ).style.display = "none" ;
    $('numopdiv'+ n).style.display = "none" ;
    $('booopdiv' + n ).style.display = "block" ;
    $('operandA' + n ).style.display = "none" ;
    $('operandB' + n ).style.display = "none" ;
    $('operand0A' + n ).style.display = "none" ;
    $('checkdivid' + n ).style.display = "none" ;
    $('operandAND' + n ).style.display = "none" ;
    $('boooperationid' + n).value = "is true" ;
    //   $('valuesid' ).style.display = "none" ;
  }
  // ---- Treating as STRING (the default) ----
  else // (datatype=="text")
  {
    // Show text-criteria div, hide others.
    $('stropdiv' + n ).style.display = "block" ;
    $('numopdiv'+ n).style.display = "none" ;
    if($('booopdiv' + n ))
    {  $('booopdiv' + n ).style.display = "none" ; }

    // Get the operation
    var operation = $('stroperation' + n).value ;

    // --> A regular operations, show single value input
    if((operation.indexOf('present') < 0) && (operation.indexOf('empty') < 0 ))
    {
      if($('operandA' + n ))
      {
        $('operandA' + n ).style.display = "block" ;
        $('checkdivid' + n ).style.display = "block" ;
      }
    }
    else // --> IS PRESENT-type operation
    {
      // Hide all value inputs
      $('operandA' + n ).style.display = "none" ;
      $('checkdivid' + n ).style.display = "none" ;
    }

    // Hide extraneous multi-value inputs.
    if($('valueA' + n))
    { $('valueA' + n).style.backgroundColor =  "white" ; }
    if( $('operandB' + n ))
    { $('operandB' + n ).style.display = "none" ; }
    if($('operand0A' + n ))
    { $('operand0A' + n ).style.display = "none" ; }
    $('operandAND' + n ).style.display = "none" ;
  }
  return ;
}

// Show right-hand value (operand) for numerical operations.
function displayOperand(n)
{
  var operation = $('numoperationid'+n).value ;

  // --> BETWEEN-type operation
  if(operation && operation.indexOf('between') >= 0 )
  {
    // Show left and right value inputs, plus the static "and" word
    // Hide other value input(s)
    $('operandA' + n ).style.display = "none" ;
    $('operand0A' + n ).style.display = "block" ;
    $('operandB' + n ).style.display = "block" ;
    $('operandAND' + n ).style.display = "block" ;
  }
  else
  {
    // A regular operation, show one value input
    if((operation.indexOf('present') < 0) && (operation.indexOf('empty') < 0 ))
    {
      $('operandA' + n ).style.display = "block" ;
      $('operand0A' + n ).style.display = "none" ;
      $('operandB' + n ).style.display = "none" ;
      $('operandAND' + n ).style.display = "none" ;
    }
    else // An IS PRESENT type operation, show no value inputs
    {
      $('operandA' + n ).style.display = "none" ;
      $('operand0A' + n ).style.display = "none" ;
      $('operandB' + n ).style.display = "none" ;
      $('operandAND' + n ).style.display = "none" ;
    }
  }
  return ;
}

// Adds a new rule to the list of rules on the interface
function addRule()
{
  var div = document.createElement('div') ;
  var myCurrentIndex = $('myCurrentIndex').value ;

  if(myCurrentIndex)
  {
    var index = parseInt(myCurrentIndex) ;
    var ii = index + 1 ;
    var attributeid = "attributeId" + ii ;

    // New div name
    var mainDivId = 'divid' + ii ;
    div.setAttribute('id', mainDivId) ;
    div.setAttribute('name', mainDivId) ;
    div.className = "rowdiv" ;
    div.style.display = "block" ;
    div.style.width = "100%" ;
    var junctionid = "junctionId" + ii ; // Not going to use this right now though
    var attridivid = "attrDivId" + ii ;
    var datatypedivid = "datatypeDivId" + ii ;
    var datatypeName = "datatypeName"+ ii ;
    var datatypeId = "datatypeId" + ii ;
    var operationId = "operation" + ii ;
    var selectedValues = new Array(5) ;
    var newattributeid = "newAttribute" + ii ;

    // Try to grow inner html as string rather than via DOM
    var innerStr = "" ;

    // ---- ATTRIBUTE DIV ----
    innerStr += "<div id=\"" + attridivid + "\" class=\"celldiv\" style=\"width:22%; display:block;\">\n" +
                "  <input type=\"hidden\" name=\"" + newattributeid + "\" id=\"" + newattributeid + "\" value= \"\">\n" +
                "  <select name=\"" + attributeid + "\" id=\"" + attributeid + "\" class=\"txt\" style=\"width:100%;\" onChange=\"checkManualInput(" + ii + ")\" >\n" ;
    // Add each attribute to select list
    // - attributeList is a global Array from the HTML page (what will be sent to server)
    //   . already cgi-escaped
    // - attributeServerList is a global Array from HTML page (matches index-for-index with attributeList, but is what is displayed to user)
    //   . already html-escaped

    for(var jj=0; jj<attributeList.length; jj++)
    {
      var attname = attributeList[jj] ;
      var attDisplay = unescape(attname).escapeHTML() ;
      var selected = (jj == 0 ? "selected" : "") ;
      innerStr += "    <option value=\"" + attname + "\" " + selected + ">" + attDisplay + "</option>\n"
    }
    innerStr += "    <option value=\"**User Entered**\">**User Entered**</option>\n"
    innerStr += "  </select>\n</div>\n\n"

    // ---- DATATYPE DIV ----
    innerStr += "<div id=\"" + datatypedivid + "\" class=\"celldiv\" style=\"width:14%; display:block;\">\n" +
                "  <select name=\"" + datatypeId + "\" id=\"" + datatypeId + "\" class=\"txt\" style=\"width:100%;\" onChange=\"setOperation(" + ii + ")\" >\n";
    for(var jj=0; jj<datatypes.length; jj++)
    {
      var myId = datatypes[jj] ;
      var selected = (jj == 0 ? "selected" : "") ;
      innerStr += "    <option value=\"" + myId + "\" " + selected + "> " + myId.escapeHTML() + "</option>\n" ;
    }
    innerStr += "  </select>\n</div>\n\n" ;

    // ---- STRING OP DIV ----
    innerStr += "<div id=\"stropdiv" + ii + "\" class=\"celldiv\" style=\"width:22%; display:block;\">\n" +
                "  <select name=\"str" + operationId + "\" id=\"str" + operationId + "\" class=\"txt\" style=\"width:100%\" onChange=\"setOperation(" + ii + ")\" >\n" ;

    for(var jj=0; jj<textOperations.length; jj++ )
    {
      var myId = textOperations[jj];
      var selected = (jj == 0 ? "selected" : "") ;
      innerStr += "    <option value=\"" + myId + "\" " + selected + "> " + myId.escapeHTML() + "</option>\n" ;
    }
    innerStr += "</select>\n</div>\n\n" ;

    // ----- NUMBER OP DIV ----
    innerStr += "<div id=\"numopdiv" + ii + "\" class=\"hiddencelldiv\" style=\"width:22%; display:none;\">\n" +
                "  <select name=\"numoperationid" + ii + "\" id=\"numoperationid" + ii + "\" class=\"txt\" style=\"width:100%\" onChange=\"displayOperand(" + ii + ")\" >\n" ;
    for(var jj=0; jj<numberOperations.length; jj++ )
    {
      var myId = numberOperations[jj] ;
      var selected = (jj == 0 ? "selected" : "") ;
      innerStr += "    <option value=\"" + myId + "\" " + selected + "> " + myId.escapeHTML() + "</option>\n" ;
    }
    innerStr += "</select>\n</div>\n\n" ;

    // ----- BOOLEAN OP DIV ----
    innerStr += "<div name=\"booopdiv" + ii + "\" id=\"booopdiv" + ii + "\" class=\"hiddencelldiv\" style=\"width:22%; display:none;\">\n" +
                "  <select name=\"boooperationid" + ii + "\" id=\"boooperationid" + ii + "\" class=\"txt\" style=\"width:100%\">\n" ;
    for(var jj=0; jj<booleanOperations.length; jj++ )
    {
      var myId = booleanOperations[jj];
      var selected = "";
      innerStr += "    <option value=\"" + myId + "\" " + selected + "> " + myId.escapeHTML() + "</option>\n" ;
    }
    innerStr += "</select>\n</div>\n\n" ;

    // VALUE and CHECKBOX divs
    innerStr += "<div id=\"operandA" + ii + "\" class=\"celldiv\" style=\"display:block; width:15%;\">\n" +
                "  <input name=\"valueA" + ii + "\" type=\"text\" id=\"valueA" + ii + "\" value=\"\" class=\"txt\" style=\"width:100%\" onChange=\"validateRule(" + ii + ");\">\n" +
                "</div>\n" +
                "<div name=\"checkdivid" + ii + "\" id=\"checkdivid" + ii + "\" style=\"float:left; display:block; width:20%;\" >\n" +
                "  <nobr>\n" +
                "    <input type=\"checkbox\" name=\"checkboxId" + ii + "\" id=\"checkboxId" + ii + "\" checked=\"checked\" class=\"txt\">Case Sensitive\n" +
                "  </nobr>\n" +
                "</div>\n" +
                "<div id=\"operand0A" + ii + "\" class=\"hiddencelldiv\" style=\"display:none; width:15%;\">\n" +
                "  <input name=\"startValue" + ii + "\" type=\"text\" id=\"startValue" + ii + "\" value=\"\" class=\"txt\" style=\"width:100%;\" onChange=\"validateRule(" + ii + ");\">\n" +
                "</div>\n" +
                "<div id=\"operandAND" + ii + "\" class=\"hiddencelldiv\" style=\"display:none; width:4%;\">\n" +
                "  and\n" +
                "</div>\n" +
                "<div id=\"operandB" + ii + "\" class=\"hiddencelldiv\" style=\"display:none; width:15%;\">\n" +
                "  <input name=\"valueB" + ii + "\" id=\"valueB" + ii + "\" type=\"text\" value=\"\" class=\"txt\" style=\"width:100%;\" onChange=\"validateRule(" + ii + ");\">\n" +
                "</div>\n"

    // Add innerStr as HTML
    div.innerHTML = innerStr ;
    // Add div to rule list div
    var qdiv = $('qtooldiv') ;
    qdiv.appendChild(div) ;

    $('myCurrentIndex').value = ii ;
  }
  return ;
}

// Remove the last rule
function removeOneRule()
{
  var qtooldiv = $('qtooldiv') ;
  // remove elem from DOM entirely
  var kids = qtooldiv.childNodes ;
  if(kids.length > 0)
  {
    qtooldiv.removeChild(kids[kids.length-1]) ;
    var newIdx = parseInt($('myCurrentIndex').value) ;
    newIdx -= 1;
    $('myCurrentIndex').value = (newIdx < 0 ? -1 : newIdx) ;
  }
}

function resetQueryUI()
{
  var qtooldiv = $('qtooldiv') ;
  // remove elems from DOM entirely so don't get submitted
  var kids = qtooldiv.childNodes ;
  for(var jj=kids.length-1; jj >= 0; jj--)
  {
    if($(kids[jj]).remove)
    {
      $(kids[jj]).remove() ;
    }
  }
  qtooldiv.innerHTML = "" ;
  $('myCurrentIndex').value = -1 ;
  initAttributeList() ;
  attributeList.length = staticAttributeList.length ;
  addRule() ;
  rebuildAttributeLists() ;
}

// Send only the query AVP input field
// - removes the dynamically added widgets before form submission,
//   thereby cleaning up and reducing what is sent to the server.
function prepAVPsubmit(formId, inputFieldName)
{
  // First, turn UI into JSON
  var x =  getQueryUIJson(inputFieldName);
  // Determine whether all or any rules required
  var allAny = $F('selectAllAny') ;
  $('allAny').value = allAny ;
  // Can we submit the form?
  var retVal = false ;
  if(validateForm(formId))
  {
    $('myCurrentIndex').value = -1 ; // in case user hits back button
    // Remove unneeded form widgets, so don't get submitted:
    Element.remove($('selectAllAny')) ;
    Element.remove($('myCurrentIndex')) ;
    var qtooldiv = $('qtooldiv') ;
    var kids = qtooldiv.childNodes ;
    for(var jj=kids.length-1; jj >= 0; jj--)
    {
      qtooldiv.removeChild(kids[jj]);
    }
    qtooldiv.innerHTML = "" ;
    retVal = true ;
  }
  // Clean escaped track names back to unescaped so can be used to download annos
  for(var ii=0; ii<numTracks; ii++)
  {
    var checkbx = $('trackName_' + ii + '_chkbx') ;
    // If checked, add that track's attributes to the list
    if(checkbx && checkbx.checked)
    {
      checkbx.value = unescape(checkbx.value) ;
    }
  }
  return retVal ;
}

// Stores the JSON-ified query into an specified [hidden] input
function getQueryUIJson(elemId)
{
  if(!elemId)
  { elemId = 'rulesJson' ; }

  populateAVP( elemId );
  // var formObj = $(formId);
  return $(elemId).value ;
}

// Do the actual AVP submission (for testing only, usually)...to
// prepare the page for submission, call prepAVPsubmit() and then
// submit your form yourself.
function submitAVP(formId, inputFieldName)
{
  // Prep AVP criteria form
  var submitOk = prepAVPsubmit(formId, inputFieldName) ;
  if(submitOk)
  {
    // Submit form
    $(formId).submit() ;
  }
}

// Build a data structure for the query contents that will be
// turned into JSON string.
function populateAVP(inputFieldId)
{
  var myCurrentIndex = $('myCurrentIndex').value ;
  var index = parseInt(myCurrentIndex) ;

  if(index < 0)
  {
    $(inputFieldId).value = ""
    return ;
  }
  var filterArray = new Array(index+1) ; // Array of rules

  for(i=0; i<= index; i++)
  {
    // The rule hash:
    var FilterObject = new Object();
    if(i==0)
    {
      FilterObject.junction = null ;
    }
    else
    {
      // ARJ: not doing this junction stuff right now.
      // ARJ: either ALL rules must pass or ANY rule must pass
      // ARJ: later we will add ( ) and then be able to support AND/OR
      //      in a sensible way.
      //
      //FilterObject.junction = $('junctionId' + i).value ;
      FilterObject.junction = null ;
    }

    // Attribute name:
    var attrId = 'attributeId' + i ;
    FilterObject.attribute = unescape($(attrId).value) ;
    if(fixedAttributes.get(FilterObject.attribute)) // then map back to a tag the rule engine knows about
    {
      FilterObject.attribute = fixedAttributes.get(FilterObject.attribute) ;
    }
    // Or is it a manually entered attribute because there are so many?
    //var newAttrId = 'newAttribute' + i ;
    //if($(newAttrId) && $(newAttrId).value != "")
    //{
    //  FilterObject.attribute = unescape($(newAttrId).value) ;
    //}

    // Attribute datatype:
    FilterObject.datatype = $('datatypeId' + i ).value ;

    // Declare operation (fill it in later):
    FilterObject.operation = '' ;

    // Values array:
    // - currently 0 to 2 values, but in the future maybe more?
    FilterObject.values = new Array() ;
    FilterObject.caseSensitive = false ;
    if($('numopdiv'+ i).style.display == "block") // --> Number type data
    {
      // Get the operation
      FilterObject.operation = $('numoperationid' + i).value ;

      var valueA = $('valueA' + i).value ;
      if( valueA != "" )
      { FilterObject.values.push(parseFloat(valueA)) ; }

      // If the operation is actually a BETWEEN type op then get the 2 range ends
      if(FilterObject.operation.indexOf('between') >= 0 )
      {
        FilterObject.values[0] = parseFloat($('startValue' + i).value) ;
        // if($('valueB' + i))
        FilterObject.values.push(parseFloat($('valueB' + i).value)) ;
      }
    }
    else if( $('stropdiv' + i).style.display == "block") // --> String type data
    {
      // Get the operation
      FilterObject.operation = $('stroperation' + i).value ;

      var strValue = $('valueA' + i).value ;

      if(strValue != "")
      { FilterObject.values.push(strValue) ; }
      // else // leave values empty
      // { FilterObject.values[0] = null ; }

      FilterObject.caseSensitive = $('checkboxId'+i).checked ;
    }
    else if($('booopdiv' + i).style.display == "block") // --> Boolean type data
    { FilterObject.operation  = $('boooperationid'+i).value ; }
    filterArray[i] = FilterObject;
  }

  $(inputFieldId).value =  filterArray.toJSONString() ;
  return ;
}

// Validate fields are filled in and have sensible values
function validateForm(formId)
{
  var formObj = $(formId) ;
  var myCurrentIndex = $('myCurrentIndex').value ;
  var index = parseInt(myCurrentIndex) ;
  var success = true ;
  var numerr = 0 ;
  var numErrMsg = "" ;
  var strErrMsg = "" ;
  var globalErrMsg = "" ;

  if(index < 0) // No rules on form!
  {
    numerr++ ;
    globalErrMsg = "- there are no selection conditions to apply!\n" ;
  }
  else // There are some rules to look at
  {
    for(i=0; i<=index; i++)
    {
      var datatype = formObj.elements['datatypeId' + i ].value ;

      if(!datatype || datatype == "boolean")
      { continue ; }

      var operation = "" ;

      // NUMBER type data
      if(datatype=="number")
      {
        operation = formObj.elements['numoperationid' + i].value ;
        // Is BETWEEN type operation
        if(operation.indexOf('between') >= 0 )
        {
          // check start/stop
          var startVal = formObj.elements['startValue' + i].value ;
          var stopVal = formObj.elements['valueB' + i].value ;

          if(!isNum(startVal))
          {
            numerr++ ;
            formObj.elements['startValue' + i].style.backgroundColor ="red" ;
            numErrMsg = "- value not a number\n" ;
          }
          else
          { formObj.elements['startValue' + i].style.backgroundColor =  "white" ; }

          if(!isNum(stopVal))
          {
            numerr ++;
            formObj.elements['valueB' + i].style.backgroundColor = "red" ;
            numErrMsg = "- value not a number\n" ;
          }
          else
          { formObj.elements['valueB' + i].style.backgroundColor =  "white" ; }
        }
        // Unless it's the value-less IS PRESENT type operation
        else if(operation.indexOf ('present') < 0)
        {
          var startVal = formObj.elements['valueA' + i].value ;
          if(!isNum(startVal))
          {
            numerr ++;
            formObj.elements['valueA' + i].style.backgroundColor = "red" ;
            numErrMsg = "- value not a number\n" ;
          }
          else
          { formObj.elements['valueA' + i].style.backgroundColor =  "white" ; }
        }
      }
      else if(datatype=="text")
      {
        operation = formObj.elements['stroperation' + i].value ;
        // Unless it's the IS PRESENT type operation:
        if((operation.indexOf ('present') < 0) && (operation.indexOf('empty') < 0))
        {
          var strValue = formObj.elements['valueA' + i].value ;

          if(strValue && strValue != null)
          {
            strValue = trimString(strValue) ;
            if(strValue == "")
            {
              numerr++ ;
              formObj.elements['valueA' + i].style.backgroundColor = "red" ;
              strErrMsg = "- 1+ text values are empty\n" ;
            }
            else
            { formObj.elements['valueA' + i].style.backgroundColor = "white" ; }
          }
          else
          {
            numerr++ ;
            formObj.elements['valueA' + i].style.backgroundColor = "red" ;
            strErrMsg = "- 1+ text values are missing\n" ;
          }
        }
      }
    } // end of for
  }

  if(numerr>0)
  {
    var fieldVal = numerr==1 ? "field" : "fields" ;
    var errVal = numerr>1 ? "these types of errors" : "an error" ;
    if(globalErrMsg != "")
    {
      alert("Your query has a problem:\n\n" + globalErrMsg ) ;
    }
    else
    {
      alert(" Please correct the " + fieldVal +  " marked in red.\n" +
            "\nYour query has " + errVal + ":\n" +
            numErrMsg + strErrMsg ) ;
    }
    success = false;
  }
  return success;
}

// Validate rule when it changes (on the fly)
function validateRule(i)
{
  var numerr = 0 ;
  var datatype = $('datatypeId' + i ).value ;

  // Nothing to validate for boolean data type
  if(!datatype || datatype == "boolean")
  { return ; }

  var operation = "" ;

  // NUMBER type data
  if(datatype=="number")
  {
    // Get selected operation for this rule
    operation = $('numoperationid' + i).value ;

    // Is BETWEEN type operation
    if(operation.indexOf('between') >=0 )
    {
      var startVal = $('startValue' + i).value ;
      var stopVal = $('valueB' + i).value ;

      if(!isNum(startVal))
      {
        numerr++ ;
        $('startValue' + i).style.backgroundColor ="red" ;
      }
      else
      { $('startValue' + i).style.backgroundColor =  "white" ; }

      if(!isNum(stopVal))
      {
        numerr++ ;
        $('valueB' + i).style.backgroundColor = "red" ;
      }
      else
      { $('valueB' + i).style.backgroundColor =  "white" ; }
    }
    // Some other type of numeric operation, not an 'is present' one though
    else if((operation.indexOf('present') < 0) && (operation.indexOf('empty') < 0))
    {
      var startVal = $('valueA' + i).value ;
      if (!isNum(startVal))
      {
        numerr++ ;
        $('valueA' + i).style.backgroundColor = "red" ;
      }
      else
      { $('valueA' + i).style.backgroundColor =  "white" ; }
    }
  }
  // STRING type data
  else if(datatype=="text")
  {
    // Get operation
    operation = $('stroperation' + i).value ;

    // Check value as long as is not 'is present' type operation
    if((operation.indexOf ('present') < 0)  && (operation.indexOf('empty') < 0))
    {
      var strValue = $('valueA' + i).value ;
      if(strValue && strValue != null)
      {
        strValue = trimString(strValue) ;
        if(strValue == "")
        {
          numerr++ ;
          $('valueA' + i).style.backgroundColor = "red" ;
        }
        else
        { $('valueA' + i).style.backgroundColor = "white" ; }
      }
      else
      {
        numerr++ ;
        $('valueA' + i).style.backgroundColor = "red" ;
      }
    }
  }
  return ;
}

function ignoreCaseCmp(aa, bb)
{
  var xx = aa.toLowerCase() ;
  var yy = bb.toLowerCase() ;
  return (xx < yy ) ? -1 : (xx > yy ? 1 : 0) ;
}

// Init the attribute list with just the static members
// - these won't be added or deleted dynamically from attribute select lists
// Uses these globals from including page:
// - staticAttributeList
// - attributeList
// - attributeMap
function initAttributeList()
{
  if(attributeList)
  {
    attributeList.clear() ;
  }
  else
  {
    attributeList = $A([]) ;
  }
  for(var ii=0; ii<staticAttributeList.length; ii++)
  {
    var staticAttr = staticAttributeList[ii] ;
    attributeList.push(staticAttr) ;
    attributeMap[staticAttr] = true ;
  }
  return ;
}

// Rebuild attribute list--called initially, and then whenever:
// (a) track is checked/unchecked
// (b) User-defined attribute is entered
// Uses these globals from the including page:
// - numTracks
// - jsAttrMap
// - attributeList
// - staticAttributeList
// - customAttributeList
function rebuildAttributeLists()
{
  var attributeMap = $H({}) ; // To track uniqueness
  // FIRST: Clear existing attribute list except for statics
  attributeList.length = staticAttributeList.length ;
  // SECOND: Clear attribute map & add statics
  attributeMap = $H({}) ;
  for(var ii=0; ii<staticAttributeList.length; ii++)
  {
    attributeMap[staticAttributeList[ii]] = true ;
  }
  // THIRD: Add attributes from each selected track
  // Go through each track checkbox
  var dynamAttributeList = $A([]) ;
  for(var ii=0; ii<numTracks; ii++)
  {
    var checkbx = $('trackName_' + ii + '_chkbx') ;
    // If checked, add that track's attributes to the list
    if(checkbx && checkbx.checked)
    {
      var escTrackName = checkbx.value ;
      var attrArray = jsAttrMap.get(escTrackName) ;
      if(attrArray)
      {
        for(var jj=0; jj<attrArray.length; jj++)
        {
          var attrItem = attrArray[jj] ;
          if(!attributeMap[attrItem])
          {
            dynamAttributeList.push(attrItem) ;
            attributeMap[attrItem] = true ;
          }
        }
      }
    }
  }
  // FOURTH: Sort the track-specific attributes and add to the global list
  dynamAttributeList =  dynamAttributeList.sort(ignoreCaseCmp) ;
  for(var ii=0; ii<dynamAttributeList.length; ii++)
  {
    attributeList.push(dynamAttributeList[ii]) ;
  }
  // FIFTH: Add user-defined attributes
  for(var ii=0; ii<customAttributeList.length; ii++)
  {
    var customAttr = customAttributeList[ii] ;
    if(!attributeMap[customAttr])
    {
      attributeList.push(customAttr) ;
      attributeMap[customAttr] = true ;
    }
  }
  // SIXTH: Update each drop-list in Attribute column
  // -- Add **User Entered** after all the rest
  updateAttributeLists() ;
  return true ;
}

function updateAttributeLists()
{
  var myCurrentIndex = $('myCurrentIndex').value ;
  var ruleIdx = parseInt(myCurrentIndex) ;
  // Go through each attribute select list for each rule
  for(var ii=0; ii<=ruleIdx; ii++)
  {
    var attrSelect = $('attributeId' + ii) ;
    if(attrSelect)
    {
      var options = attrSelect.options ;
      // Save the currently selected item (idx + name)
      var currSelectIdx = attrSelect.selectedIndex ;
      var currSelectValue = options[currSelectIdx].value ;
      // Clear the options array (force remove to try to work around browser GC/mem-leaks)
      options.length = staticAttributeList.length ; // Just trim off stuff that can change
      // Go through each attribute after the static ones
      var newSelectIdx = 0 ;
      for(var jj=staticAttributeList.length; jj<attributeList.length; jj++)
      {
        var attrItem = attributeList[jj] ;
        // Add new option element for attribute
        var newOption = new Option(unescape(attrItem).escapeHTML(), attrItem) ;
        options[jj] = newOption ;
        // Is this attribute that was selected before?
        if(currSelectValue == attrItem)
        {
          attrSelect.selectedIndex = jj ;
        }
      }
      // Add **User Entered**
      options[options.length] = new Option('**User Entered**', '**User Entered**') ;
    }
  }
  return ;
}

// Check if adding a attribute manually in case there are too many to list in drop list.
function checkManualInput(i)
{
  var attrId = 'attributeId' + i ;
  var selAttrId = $(attrId) ;
  var attribute = unescape(selAttrId.value) ;
  var newAttribute = null ;
  if(attribute.indexOf('**User Entered**') >= 0)
  {
    newAttribute = prompt("Please enter attribute name:") ;
    if(newAttribute)
    {
      // CGI escape it so it's like the ones from the server
      newAttribute = escape(newAttribute) ;
      // Add the attribute to the custom list, if really new
      if(!attributeMap[newAttribute])
      {
        customAttributeList.push(newAttribute) ;
        attributeMap[newAttribute] = true ;
        // Rebuild all the Attribute droplists
        rebuildAttributeLists() ;
        // Select the recently added user-defined attr in the current list (it will be -2 from the bottom)
        selAttrId.selectedIndex = selAttrId.options.length - 2
      }
      else
      {
        alert("The attribute '" + unescape(newAttribute) + "' is already present.") ;
        $(attrId).selectedIndex = 0 ;
      }
    }
    else
    {
      $(attrId).selectedIndex = 0 ;
    }
  }
  return ;
}

// Adds newAttribute at end of existing attribute lists, except
// for the rule that has just changed.
function updateRuleAttrs(n , newAttribute, newAttributeDisplay)
{
  var myCurrentIndex = $('myCurrentIndex').value ;
  if(myCurrentIndex)
  {
    var index = parseInt(myCurrentIndex) ;
    for(var ii=0; ii<index; ii++)
    {
      if(ii != n)
      {
        var attrListSelect = $('attributeId' + ii) ;
        // First, replace selected option (the User Entered one) with
        // the new attribute name.
        var optionArr = attrListSelect.options ;
        optionArr[optionArr.length-1].value = newAttribute ;
        optionArr[optionArr.length-1].innerHTML = newAttributeDisplay ;
        // Now re-add the user Entered option
        optionArr[optionArr.length] = new Option('**User Entered**', '**User Entered**') ;
      }
    }
  }
  return ;
}
