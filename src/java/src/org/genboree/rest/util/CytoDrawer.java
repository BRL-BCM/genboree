package org.genboree.rest.util ;

import java.io.* ;
import java.sql.* ;
import org.genboree.util.* ;
import org.genboree.dbaccess.* ;
import org.genboree.dbaccess.util.* ;

public class CytoDrawer
{
  private static final String[] CYTOBAND_TRACK_ALIASES = { "Cyto:Band" } ;
  private static final int HORIZONTAL = 0 ;
  private static final int VERTICAL = 1 ;

  // Public fields/properties (when will Java get real properties like other langs?)
  public int orientation = HORIZONTAL ;
  public int pxHeight = 15 ;
  public int pxWidth = 300 ;
  public int topMargin = 0 ;
  public int rightMargin = 0 ;
  public int bottomMargin = 0 ;
  public int leftMargin = 0 ;

  // CONSTRUCTORS
  public CytoDrawer()
  {
    this(HORIZONTAL, 15, 300, 5, 5, 5, 5) ;
  }
  public CytoDrawer(int orientation, int pxHeight, int pxWidth, int topMargin, int rightMargin, int bottomMargin, int leftMargin)
  {
    this.orientation = orientation ;
    this.pxHeight = pxHeight ;
    this.pxWidth = pxWidth ;
    this.topMargin = topMargin ;
    this.rightMargin = rightMargin ;
    this.bottomMargin = bottomMargin ;
    this.leftMargin = leftMargin ;
  }

  // ------------------------------------------------------------------
  // BY SELECTING A SPECIFIC TRACK NAME (via /trk/{trk}/annos api resource)
  // ------------------------------------------------------------------
  // Create cytoband drawing URL, suitable wrapped via Genboree apiCaller.jsp
  public String createCytobandImageUrl(String[] allTrackNames, int currGrpId, int currDbId, String landmark, Connection conn)
  {
    return createCytobandImageUrl(allTrackNames, "" + currGrpId, "" + currDbId, landmark, conn) ;
  }
  public String createCytobandImageUrl(String[] allTrackNames, GenboreeGroup currGrp, Refseq currDb, String landmark, Connection conn)
  {
    return createCytobandImageUrl(allTrackNames, currGrp.getGroupId(), currDb.getRefSeqId(), landmark, conn) ;
  }
  public String createCytobandImageUrl(String[] allTrackNames, String currGrpId, String currDbId, String landmark, Connection conn)
  {
    // Find Cyto:Band track
    String cytoBandTrackName = null ;
    for(String cytoBandAlias : CYTOBAND_TRACK_ALIASES)
    {
      for(String trackName : allTrackNames)
      {
        if(cytoBandAlias.equalsIgnoreCase(trackName))
        {
          cytoBandTrackName = trackName ;
          break ;
        }
      }
    }

    return createCytobandImageUrl(cytoBandTrackName, currGrpId, currDbId, landmark, conn) ;
  }

  // ------------------------------------------------------------------
  // FOR A CHROMOSOME, WITHOUT TRACK LIST (via /ep/{ep} api resource--let api find cytoband track, if any)
  // ------------------------------------------------------------------
  // Create cytoband drawing URL, suitable wrapped via Genboree apiCaller.jsp
  public String createCytobandImageUrl(int currGrpId, int currDbId, String landmark, Connection conn)
  {
    String trackName = null ;
    return createCytobandImageUrl(trackName, "" + currGrpId, "" + currDbId, landmark, conn) ;
  }
  public String createCytobandImageUrl(GenboreeGroup currGrp, Refseq currDb, String landmark, Connection conn)
  {
    String trackName = null ;
    return createCytobandImageUrl(trackName, currGrp.getGroupId(), currDb.getRefSeqId(), landmark, conn) ;
  }
  public String createCytobandImageUrl(String currGrpId, String currDbId, String landmark, Connection conn)
  {
    String trackName = null ;
    return createCytobandImageUrl(trackName, currGrpId, currDbId, landmark, conn) ;
  }

  // ------------------------------------------------------------------
  // HELPER METHODS
  // ------------------------------------------------------------------
  public String createCytobandImageUrl(String cytoBandTrackName, String currGrpId, String currDbId, String landmark, Connection conn)
  {
    String urlStr = null ;
    // Have we been given a track name?
    boolean haveTrackName = (cytoBandTrackName != null) ;
    // Get group and database names
    String currGroupName = GenboreegroupTable.getGroupNameById(currGrpId, conn) ;
    String currDbName =  RefSeqTable.getRefSeqNameByRefSeqId(currDbId, conn) ;
    // Get chromName if needed for /ep/ type api resource
    String chromName = null ;
    if(!haveTrackName)
    {
      int colonIdx = landmark.indexOf(":") ;
      if(colonIdx < 0)
      {
        colonIdx = (landmark.length() - 1) ;
      }
      else if((colonIdx >= landmark.length() - 1))
      {
        colonIdx = (landmark.length() - 2) ;
      }
      chromName = landmark.substring(0, colonIdx + 1) ;
    }

    // Compose URL.
    // Note in call to apiCaller.jsp:
    // - tell the JSP we are expecting a binary (non text) payload, so don't do normal String-based IO streams/writers
    // - tell the JSP that error payload texts are NOT acceptable (we want PNG data or nothing)
    String restURI =  "/REST/v1/grp/" + Util.urlEncode(currGroupName) +
                      "/db/" + Util.urlEncode(currDbName) +
                      (haveTrackName ? ("/trk/" + Util.urlEncode(cytoBandTrackName) + "/annos") : ("/ep/" + Util.urlEncode(chromName))) +
                      "?format=chr_band_png" +
                      "&landmark=" + Util.urlEncode(landmark) +
                      "&orientation=" + (this.orientation == HORIZONTAL ? "horz" : "vert") +
                      "&pxHeight=" + this.pxHeight +
                      "&pxWidth=" + this.pxWidth +
                      "&topMargin=" + this.topMargin +
                      "&rightMargin=" + this.rightMargin +
                      "&bottomMargin=" + this.bottomMargin +
                      "&leftMargin=" + this.leftMargin ;

    urlStr =  "apiCaller.jsp?method=GET&binMode=true&errorRespTextOk=false&rsrcPath=" + Util.urlEncode(restURI) ;
    return urlStr ;
  }
}
