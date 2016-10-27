
/** HELPER FUNCTIONS **/

/**
 *
 */
correctCase = function(words)
{
  words = words.split(" ") ;
  for(ii = 0; ii < words.length; ii++)
  {
    var word = words[ii] ;
    var firstLetter = word.substring(0,1).toUpperCase() ;
    var lastLetters = word.substring(1) ;
    words[ii] = firstLetter + lastLetters ;
  }
  return words.join(" ") ;
} ;


ApiUriHelper = 
{
  extractRsrcName: function(uri, rsrcKey)
  {
    var reg = new RegExp('\/' + rsrcKey  + '\/([^\/?\\s]+)') ;
    var matches = uri.match(reg) ;
    return decodeURIComponent(matches[1]) ;
  }
}
