
/**
 * For use with pathway2genomeWrapper.rhtml.
 * Assumes refSeqId and isPublicStr globals are available.
 * Uses prototype and scriptaculous.
 */
function showLinkBacks(event, keggIds, geneNames)
{
  // Cursor pos:
  var cursorX = event.clientX ;
  var cursorY = event.clientY ;
  if(self.pageYOffset)
  {
    relX = self.pageXOffset;
    relY = self.pageYOffset;
  }
  else if(document.documentElement && document.documentElement.scrollTop)
  {
    relX = document.documentElement.scrollLeft ;
    relY = document.documentElement.scrollTop ;
  }
  else if(document.body)
  {
    relX = document.body.scrollLeft ;
    relY = document.body.scrollTop ;
  }

  // Get linkback <div>
  var linkBackDiv = $("gbLinkBackDiv") ;
  // Build inner HTML for it
  var htmlBuff =  "<div class=\"availLinks\">" +
                  "<div class=\"availLinksTitle\">Gene Links:</div>" +
                  "<div class=\"availLinksClose\"><a href=\"\" onclick=\"$('gbLinkBackDiv').hide() ; return false ;\">[X]</a></div>" +
                  "</div><ul class=\"linkBack\"> ";
  for(var ii=0; ii < keggIds.length; ii++)
  {
    var keggId = keggIds[ii] ;
    var geneName = geneNames[ii] ;
    htmlBuff += (
                  "<li><div class=\"linkGeneName\">" + geneName + "</div>" +
                  "<ul class=\"linkBack\"><li><span class=\"linkBack\"><a href=\"/genboree/genboreeSearchWrapper.rhtml?refSeqID=" + refSeqId + "&query=" + geneName + "&Submit=Search&doUCSC=no" + isPublicStr + "\">Find Gene In Genboree</a></span></li>" +
                  "<li><span class=\"linkBack\"><a href=\"http://www.genome.jp/dbget-bin/www_bget?hsa:" + keggId + "\">Original Kegg Link</a></span></li>" +
                  "</ul></li>"
                ) ;
  }
  htmlBuff += "</ul></div>" ;
  linkBackDiv.update(htmlBuff) ;
  linkBackDiv.setStyle( { left: cursorX + relX + 2, top: cursorY + relY + 2, height: 26 + keggIds.length * 48 } ) ;
  linkBackDiv.setOpacity( 0.95 ) ;
  linkBackDiv.show() ;
  return true ;
}

