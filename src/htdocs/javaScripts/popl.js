// Uses prototype.js
// Uses gbrowser.js
// Requires hasSequence, allowToEdit, rootUploadId globals to be defined by JSP page
// Requires linkNames and linkUrls globals to be defined by JSP page

function popl(trackName, annoName, from, to, score, upfid, tgt)
{
  // alert("\ntrackName: " + trackName +
  //      "\nannoName: " + annoName) ;
  // These often arrive HTML escaped because they can be buried in javascript string arg to function that's in a tag.
  // Unescape it for general use and then re-escape for tags that need it (avoid double escaping!! == messy on screen)
  trackName = trackName.unescapeHTML() ;
  annoName = annoName.unescapeHTML() ;
  var argv = popl.arguments ; // To get 8th, 9th, etc, variable arguments
  // Begin the HTML contents of the popup div, and a list of links
  var divContents = "<TABLE BORDER='0' WIDTH='100%' CELLSPACING='0' CELLPADDING='2'>" ;
  var linksContent = ""
  // Make the Length text
  var lengthText = commify("" + (Math.abs(from-to) + 1)) ;
  // Make the Caption (aka pop-up Title) Text
  var captionText = ("&nbsp;" + annoName.escapeHTML() + ":&nbsp; " + commify("" + from) + "-" + commify("" + to)) ;
  // Extract Strand string to display
  var strandText = "" ;
  var strandCode = upfid.substring(0,1) ;     // Get the strand code from 6th arg
  upfid = upfid.substring(1) ;          // Strip off first character (strand) of upfid code
  if(strandCode=="+" || strandCode=="-")
  {
    strandText = "&nbsp;&nbsp; Strand: " + strandCode ;
  }
  // Do we have a Y/N for txt (i.e. are there comments?)
  var hasTxt = upfid.substring(0,1) ;   // Get the comments yes-or-no code from the 6th arg
  if(hasTxt=="Y" || hasTxt=="N")
  {
    upfid = upfid.substring(1) ;        // Strip off the 2nd character of upfid code (Y|N...now in hasTxt)
  }

  // Now we need to make all the links that go in the pop-up
  if(tgt=='L') // We have a single anno; make its score/length/strand string
  {
    divContents += ("<TR><TD NOWRAP><DIV style='font-size:7pt;'>Scr: " +
                    score + "&nbsp;&nbsp;&nbsp;Len: " + lengthText + strandText + "<hr></DIV></TD></TR>") ;
    // If have genomic sequence for this database (hasSequence defined by including JSP page)
    if(hasSequence) // then add a link for getting the genomic sequence for the clicked anno
    {
      var onClickStr = ("winPopFocus('downloadGenomicDNA.jsp?upfid=" + encodeURIComponent(upfid) + "&refName=" +
                        fullUrlEscape(referenceSequenceName) + "&trackName=" + fullUrlEscape(trackName) + "', '_newWin');") ;
      linksContent +=  ("<TR><TD NOWRAP><DIV style='font-size:8pt;'>" +
                        "- <span class='browserPopupLink' onclick=\"" + onClickStr + "\">Get Genomic DNA</span></DIV></TD></TR>" );
    }
  }

  // Do we want to show the Annotation Detail Links?
  if((upfid.indexOf(":") > 0) && (hasTxt != "N"))
  {
    // Add link for Annotation Details:
    var onClickStr = ("winPopFocus('showtext.jsp?upfid=" + encodeURIComponent(upfid) + "', '_newWin');") ;
    linksContent +=  ("<TR><TD NOWRAP><DIV style='font-size:8pt;'>- <span class='browserPopupLink' onclick=\"" +
                      onClickStr + "\" >Annotation Details</span></DIV></TD></TR>") ;
    // Add link for Annotation Group Details:
    onClickStr = ("winPopFocus('showAllAnotations.jsp?upfid=" + encodeURIComponent(upfid) + "', '_newWin');") ;
    linksContent +=  ("<TR><TD NOWRAP><DIV style='font-size:8pt;'>- <span class='browserPopupLink' onclick=\"" +
                      onClickStr + "\" >Annotation Group Details</span></DIV></TD></TR>") ;
  }

  // We allowing edit annotation? Check allowToEdit global, set by including JSP page
  if(allowToEdit) // then add a link to Edit annotation
  {
    var ii = upfid.indexOf(":") ;
    if(ii>0) // then we can extract an uploadId to use in the Edit Annotation link
    {
      var uploadId = upfid.substring(0,ii) ;
      if(uploadId == rootUploadId) // check that uploadId extracted matches the upload id for the current user database
      {
        // Add Edit Annotation link:
        var onClickStr = ("winPopFocus('annotationEditorMenu.jsp?upfid=" + encodeURIComponent(upfid) + "', '_newWin');") ;
        linksContent +=  ("<TR><TD NOWRAP><DIV style='font-size:8pt;'>- <span class='browserPopupLink' onclick=\"" +
                          onClickStr + "\">Edit Annotation</span></DIV></TD></TR>") ;
      }
    }
  }

  // Add *User* Links...but keep watch for the special "Center & Zoom" or Expand links, which will in here as well.
  // - At this point, strandText contains the score/length/strand row, addLnks contains the non-user links (expect for Center & Zoom, or Expand, etc)
  var hr = "" ;
  var linkBuff = "" ; // To store whether the link is normal or in a new window.
  for(var ii=7; ii<argv.length && (argv[ii] != -1) ; ii+=2) // Loop over rest of args which are indices to user links. Last arg is always -1.
  {
    var textIdx = argv[ii] ;              // Link text index
    var urlIdx = argv[ii+1] ;             // Link url index
    var linkText =  linkNames[textIdx] ;  // Get link text
    var linkUrl =   linkUrls[urlIdx] ;    // Get link url
    // What type of link are we adding? Create appropriate link for it
    if(tgt == 'N') // N means add special links for "too dense"
    {
      linkBuff = "<span class='browserPopupLink' onclick=\"" + linkUrl + "\">" ;
      hr = "" ;
    }
    else if((argv[ii+2] == -2) || (ii == 7 && argv[ii+2] == -1))  // adding Genboree proprietary link(s), not User Link
    {                                                             // If i+2 is -2, then we have custom links and need to draw a line under the genboree-links
                                                                  // If i=7 AND i+2 is -1, then we don't have any custom links, and thus DON'T need a line
      if(argv[ii+2] == -2) // Only draw a line under the genboree links if we have custom links.
      {
        if(linksContent != "")
        {
          linksContent += "<TR><TD><HR></TD></TR>" ;
        }
        else // Add a line under the non-user links
        {
          hr = "<HR>" ;
        }
        ii++ ; // so we advance past the extra -2 to get to the next name/url pair
      }
      linkBuff = "<span class='browserPopupLink' onclick=\"" + linkUrl + "\">" ;
    }
    else // Should be a *User* link, so we want a new window
    {
      // First, does it look like a URL-escaped URL?
      if(linkUrl.match(/^\s*%23\s*$/)) // then is pound (#, %23) only
      {
        linkBuff = "<span class='browserPopupLink' onclick=\"alert('This link is to the current view.')\">" ;
      }
      else // not pound only
      {
        // If looks like URL-escaped URL, unescape before using it
        // This is a special case where the user has put a whole URL as an attribute value.
        if(linkUrl.match(/^\s*http%3[aA]%2[fF]%2[fF]/)) //
        {
          linkUrl = unescape(linkUrl) ;
        }
        linkBuff = ("<span class='browserPopupLink' onclick=\"winPopFocus('" + linkUrl + "', '_newWin');\">") ;
      }
    }

    // Now add the link to the link list in the div content, and close the span that openned it
    divContents += ("<TR><TD NOWRAP><DIV style='font-size:8pt;'>- " + linkBuff + linkText + "</span>" + hr + "</DIV></TD></TR>") ;
    // If -2, this will add the appropriate "Center & Zoom" etc links after the score/length/strand line.
    // If not -2, this adds the next *user* link in the argument list.
    // Depending on which it is doing it will add a <HR> if appropriate.
    if((argv[ii+1] == -2) || (ii == 7 && argv[ii+2] == -1)) // Then we are still adding the standard "Center & Zoom" etc links and haven't gotten to any *User* links yet
    {
      if(linksContent != "")            // We still have non-user links buffered
      {
        divContents += linksContent ;   // So add the non-user links after the standard "Center & Zoom" etc links
        linksContent = "" ;             // Clear the non-user links buffer.
      }
      hr = "" ;                         // Don't put any more <HR> lines in, since we'll be adding *User* links from now on.
    }
  }

  // Add draggable hint
 	// First: what key will be be pressing?
 	var dragKeyStr = 'ALT' ;	// The default for Windows and unknown platforms
 	if(navigator.platform)		// Then the navigator object works ok
 	{
 		var osStr = navigator.platform.toLowerCase() ;
 		if(osStr.indexOf('mac') != -1) // Then we have some sort of Mac
 		{
 			dragKeyStr = 'ALT or OPTION' ;
 		}
 		else if(osStr.indexOf('linux') != -1) // Then we have some sort of Linux
 		{
 			dragKeyStr = 'ALT-SHIFT' ;
 		}
 	}

  divContents += ("<TR><TD ALIGN='right'><FONT SIZE='-3'>[ Hold " + dragKeyStr + " to Drag ]</FONT></TD></TR></TABLE>") ;

	// Uses overlib, overlib_hide, overlib_cssstyle, and overlib_draggable.
	// The title bar style is set in a defined class--see jsp.css.
	return overlib( divContents, STICKY, DRAGGABLE, DRAGIMG, '', CLOSECLICK, FGCOLOR, '#CCF8FF', BGCOLOR, '#9F833F',
                  CAPTIONFONTCLASS, 'capFontClass', CAPTION, captionText, CLOSEFONTCLASS, 'closeFontClass',
                  CLOSETEXT, '&nbsp;&nbsp;<FONT COLOR="white">X</FONT>&nbsp;', WIDTH, '320' );
}
