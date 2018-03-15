
// Logout from a Redmine session. For use in plugins etc.
//   Generally called WITHOUT ANY PARAMETERS and it will figure out
//   both the Rails csrf_token from a form you put on the page (via Rails methods of course)
//   AND  the url "mount" automatically by assuming it's the FIRST DIR in the URL path.
//   Else you can override these. Do avoid hardcoding it, yes?
// @param [String] mount Optional. Override the mount, possibly even supplying just "/".
//   Else it will be figured out automatically (first dir in the path)
// @param [String] csrf_token Optional. The csrf_token or "authenticity_token" that the
//   server generated in order to accept form submissions from the page. Usually this can
//   be AUTOMATICALLY found by finding ANY form you used Rails to put on the page since it
//   will have the needed token in a hidden input element.
function logout( mount, csrf_token, destUri )
{
  // Automatically determine the csrf_token as best we can since not provided.
  if( typeof csrf_token == "undefined" ) {
    var elems = elems = $("[name='authenticity_token']") ;
    if( elems.length > 0 ) {
      csrf_token = elems[0].value ;
    }
  }
  // Automatically determine url "mount" so we can post to Redmine's logout
  if( typeof mount == "undefined" )
  {
    mount = window.location.pathname.split( "/" )[1] ;
  }
  if( !mount.startsWith("/") )
  {
    mount = ( "/" + mount ) ;
  }
  if( mount.endsWith("/") && mount.length > 0 ) {
    mount = mount.slice(0, mount.length - 1) ;
  }
  // @todo FIX: Redmine AccountController#logout responds to this with a REDIRECT, however, in our set up the user can be seeing https
  //   while private redmine machine sees only http. This means Redmine will redirect the user to http in response to https post, which
  //   is a security violation and errors by the browser. Redmine HAS logged out the user, but then responded in an illegal way. The
  //   code below does handle this by causing both success and fail handlers to go to the place.
  // @todo FIX: figure out some solution for making it work as it should. Possibly need Patch modules for AccountController or
  //   even ApplicationController#logout_user. Alternatively, a whole new generic action that works a bit differently.
  var result = $.post(
    mount+"/logout",
    {
      "authenticity_token"  : csrf_token,
      _method: 'post'
    },
    function(respData, status, xhr) {
      // console.log( "DEBUG: status => " + status ) ;
      // console.log( "DEBUG: destUri => " + destUri ) ;
      if( typeof destUri == "undefined" || destUri.length < 1 )
      {
        // console.log( "DEBUG - OK: sending to " + mount ) ;
        window.location.href = mount;
      }
      else {
        // console.log( "DEBUG - OK: sending to " + mount ) ;
        window.location.href = destUri ;
      }
    }
  ).fail(function(respData, status, xhr) {
    // console.log( "DEBUG: status => " + status ) ;
    // console.log( "DEBUG: destUri => " + destUri ) ;
    if( typeof destUri == "undefined" || destUri.length < 1 )
    {
      // console.log( "DEBUG - FAIL: sending to " + mount ) ;
      window.location.href = mount;
    }
    else {
      // console.log( "DEBUG - FAIL: sending to " + destUri ) ;
      window.location.href = destUri ;
    }
  }) ;
}

// Generic sort-children-elements-of-parent-by-child-cdata function. Sorts in-place.
//   Given parent, sort its children elements (as selected by childSelector)
//   using cdata text values extracted from the child (as selected by keySelector)
// @param [Element] parent The element  or CSS selector for an element containing set of child elements to reorder
// @param [String] childSelector A CSS Selector string that, when applied to the parent,
//   will select the child elements that need to be sorted
// @param [String] keySelector A CSS Selector string that, when applied to a child element,
//   will select an element whose cdata (text) content should be used as the sort key for the child.
// @param [boolean] asNum Either true or false to indicate whether the cdata should be cast to a number
//   in order to do the sorting. The text MUST be very number like.
// @param [boolean] ignoreCase Either true or false to indicate whether sorting of cdata should ignore
//   case (should lowercase and uppercase letters be treated the same?)
// @param [boolean] descendingSort Either true or false to indicate whether sorting of cdata should be descending
//   (default is ascending). For example, this option will sort numbers greatest to least, as opposed to least to greatest.
function sortUsingNestedText(parent, childSelector, keySelector, asNum, ignoreCase, descendingSort) {
  var items = $(parent).children(childSelector).sort(function(aa, bb) {
    var vAraw = $(aa).find(keySelector).addBack(keySelector).text() ; // Find, but including aa
    var vA = ( ignoreCase ? vAraw.toLowerCase() : vAraw ) ;
    var vBraw = $(bb).find(keySelector).addBack(keySelector).text() ; // Find, but including bb
    var vB = ( ignoreCase ? vBraw.toLowerCase() : vBraw ) ;
    if(asNum) {
      vA = tryAsNum( vA ) ;
      vB = tryAsNum( vB ) ;
    }
    var sortValue = sortValue = (vA < vB) ? -1 : ( (vA > vB) ? 1 : 0 ) ;
    // Have we got a tie while in ignoreCase mode? Try to resolve with original case-sensitive content
    if( ignoreCase && sortValue == 0 ) {
      sortValue = ( (vAraw < vBraw) ? -1 : ( (vBraw > vAraw) ? 1 : 0 ) )
    }
    // Do we need to reverse the direction of the sort for descendingSort?
    if( descendingSort ) {
      sortValue *= -1 ;
    }
    return sortValue ;
  }) ;
  $(parent).append(items) ;
}

// Generic sort-children-elements-of-parent-by-child-attribute-value function. Sorts in-place.
//   Given parent, sort its children elements (as selected by childSelector)
//   using values of a specific attribute present within elements of the child (as selected by innerSelector)
// @param [Element] parent The element or CSS selector for an element containing set of child elements to reorder
// @param [String] childSelector A CSS Selector string that, when applied to the parent,
//   will select the child elements that need to be sorted
// @param [String] keySelector A CSS Selector string that, when applied to a child element,
//   will select an element whose attribute value should be used as the sort key for the child.
// @param [String] attrName The name of the attribute whose value (text) should be used as a sort key.
// @param [boolean] asNum Either true or false to indicate whether the cdata should be cast to a number
//   in order to do the sorting. The text MUST be very number like.
// @param [boolean] ignoreCase Either true or false to indicate whether sorting of cdata should ignore
//   case (should lowercase and uppercase letters be treated the same?)
// @param [boolean] descendingSort Either true or false to indicate whether sorting of cdata should be descending
//   (default is ascending). For example, this option will sort numbers greatest to least, as opposed to least to greatest.
function sortUsingNestedAttrVals(parent, childSelector, keySelector, attrName, asNum, ignoreCase, descendingSort ) {
  var items = $(parent).children(childSelector).sort(function(aa, bb) {
    var innerA = $(aa).find(keySelector).addBack(keySelector) ; // Find, but including aa
    var innerB = $(bb).find(keySelector).addBack(keySelector) ; // Find, bug including bb
    var vAraw = $(innerA).attr(attrName) ;
    var vBraw = $(innerB).attr(attrName) ;
    var vA = ( ignoreCase ? vAraw.toLowerCase() : vAraw ) ;
    var vB = ( ignoreCase ? vBraw.toLowerCase() : vBraw ) ;
    if(asNum) {
      vA = tryAsNum( vA ) ;
      vB = tryAsNum( vB ) ;
    }
    var sortValue = sortValue = (vA < vB) ? -1 : ( (vA > vB) ? 1 : 0 ) ;
    // Have we got a tie while in ignoreCase mode? Try to resolve with original case-sensitive content
    if( ignoreCase && sortValue == 0 ) {
      sortValue = ( (vAraw < vBraw) ? -1 : ( (vBraw > vAraw) ? 1 : 0 ) )
    }
    // Do we need to reverse the direction of the sort for descendingSort?
    if( descendingSort ) {
      sortValue *= -1 ;
    }
    return sortValue ;
  }) ;
  $(parent).append(items) ;
}

// Generic reverse children within parent.
//   Given parent element or CSS selector for the parent element, reverses the order of
//   the child elements (as selected by childSelector CSS string).
// @param [Element] parent The element or CSS selector for an element containing set of child elements of which to reverse the order.
// @param [String] childSelector A CSS Selector string that, when applied to the parent,
//   will select the child elements that need to in reverse order.
function reverseChildren( parent, childSelector ) {
  var childElems = $(parent).children(childSelector) ;
  $(parent).append(  childElems.get().reverse() ) ;
}

// Really a helper for the 2 fancy element sorting functions above.
// Trys to employ Javascript casting to convert str to a number via pretty decent auto-casting done by
//   +(str). But if that fails--Javascript returns NaN if doesn't look like any kind of number--then this
//   function falls back on extracting the first INTEGER sequence (\d+) in the string and returning that.
//   This fallback is pretty useful to rescue common value strings like "id_7" that fail Javascript's own +("id_7"),
//   so sensible sorting can be done.
// @param [String] str The string to try to convert to some kind of number.
// @return [Integer, Float, String] The converted number or the original string if all attempts to convert failed.
function tryAsNum( str ) {
  // If things go poorly we return str uncasted, as original [string] value.
  var retVal = str ;
  var strtmp = +(str.replace(",", "")) ;
  if( isNaN(strtmp) )
  { // Try a fallback to extracting first integer-like sequence
    var mm = /(\d+)/.exec( str );
    // If the fallback didn't work either, we'll just use as leave str alone and return it
    // else we'll return the extracted integer since javascript casting didn't work
    if( typeof mm[1] !== 'undefined' )
    {
      retVal = +(mm[1]);
    }
  }
  else {
    retVal = strtmp ;
  }

  return retVal ;
}

// Polyfill for using endsWith(). This is not supported in certain older versions of IE
// And hence the polyfill
if (!String.prototype.endsWith) {
  String.prototype.endsWith = function(search, this_len) {
    if (this_len === undefined || this_len > this.length) {
      this_len = this.length;
    }
    return this.substring(this_len - search.length, this_len) === search;
  };
}
