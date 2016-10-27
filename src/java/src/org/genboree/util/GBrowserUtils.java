
package org.genboree.util ;

import java.sql.* ;
import java.util.* ;
import org.genboree.dbaccess.* ;
import org.genboree.dbaccess.util.*;
import org.genboree.browser.* ;

public class GBrowserUtils
{
  // Extract unique list of classes found amongst entries in a DbFtype[].
  // - Note that DbFtype[] argument can contain a given track name more than once;
  //   e.g. one entry from template database (first) and then later an entry for the track from the local database
  public static String[] extractClassNameArray(DbFtype[] dbFtypes)
  {
    HashMap<String, Boolean> classHash = new HashMap<String, Boolean>() ;
    String[] classes = null ;
    DBAgent db = DBAgent.getInstance() ;

    if(dbFtypes != null)
    {
      try
      {
        // Examine each DbFtype track object
        for(DbFtype currDbFtype : dbFtypes)
        {
          // Get all the classes this track is in for its database
          Connection conn = db.getConnection(currDbFtype.getDatabaseName()) ;
          ArrayList<String> classList = GClassTable.getClassListByTrackName(currDbFtype.getFmethod(), currDbFtype.getFsource(), conn) ;
          // String[] dbFtypeClasses = currDbFtype.getBelongToAllThisGclasses() ;
          // Add each class to the hash
          for(String currClass : classList)
          {
            classHash.put(currClass, true) ;
          }
        }
        // Get unique classes array (the keys of classHash)
        Set<String> keys = classHash.keySet() ;
        classes = new String[keys.size()] ;
        classes = keys.toArray(classes) ;
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: GBrowserUtils#extractClassNameArray(D[]) => exception getting connection to a user database") ;
        ex.printStackTrace(System.err) ;
        classes = null ;
      }
    }
    return classes ;
  }

  // Extract unique list of track names found amongst entries in a DbFtype[].
  // - Note that DbFtype[] argument can contain a given track name more than once;
  //   e.g. one entry from template database (first) and then later an entry for the track from the local database
  public static String[] extractTrackNameArray(DbFtype[] dbFtypes)
  {
    HashMap<String, Boolean> trackNameHash = new HashMap<String, Boolean>() ;
    String[] trackNames = null ;

    if(dbFtypes != null)
    {
      // Examine each DbFtype track object
      for(DbFtype currDbFtype : dbFtypes)
      {
        String currTrackName = currDbFtype.toString() ;
        // Add track name to hash
        trackNameHash.put(currTrackName, true) ;
      }
      // Get unique track name array (keys of trackNameHash)
      Set<String> keys = trackNameHash.keySet() ;
      trackNames = new String[keys.size()] ;
      trackNames = keys.toArray(trackNames) ;
    }
    return trackNames ;
  }

  // Create HashMap of class->ArrayList of DbFtypes in that class
  // using all the DbFtype objects in dbFtypes (has shared, then locally mentioned tracks) and the classes in classes
  public static HashMap<String, ArrayList<DbFtype>> getCompleteTracksByClassHashMap(DbFtype[] dbFtypes)
  {
    HashMap<String, ArrayList<DbFtype>> uniqueTrackListByClass = null ;
    if(dbFtypes != null)
    {
      try
      {
        DBAgent db = DBAgent.getInstance() ;
        uniqueTrackListByClass = new HashMap<String, ArrayList<DbFtype>>() ;
        // Collect the tracks in each class in a hash of hashes (class->trackName->DbFtype) (too get unique track name lists for each class)
        HashMap<String, HashMap<String, DbFtype>> hashOfTracksByClass = new HashMap<String, HashMap<String, DbFtype>>() ;
        // Examine each track object
        for(DbFtype currDbFtype : dbFtypes)
        {
          // Get databaseName that track came from
          String databaseName = currDbFtype.getDatabaseName() ;
          // Get track name
          String currTrackType = currDbFtype.getFmethod() ;
          String currTrackSubtype = currDbFtype.getFsource() ;
          String currTrackName = currDbFtype.toString() ;
          // Get classes for this track from the database this dbFtype object is based on
          // (We don't rely on however DbFtype class tries to get this class list; we get from db cleanly)
          Connection conn = db.getConnection(databaseName) ;
          ArrayList<String> currClassList = GClassTable.getClassListByTrackName(currTrackType, currTrackSubtype, conn) ;
          // Go through each class
          for(String currClass : currClassList)
          {
            HashMap<String, DbFtype> trackHash = hashOfTracksByClass.get(currClass) ;
            // Ensure an entry for this class in hash
            if(trackHash == null)
            {
              trackHash = new HashMap<String, DbFtype>() ;
              hashOfTracksByClass.put(currClass, trackHash) ;
            }
            // For each class->track->dbFtype, we only store 1 dbFtype. Because local dbFtype objects
            // are LAST in the dbFtypes array, local track objects will be preferentially stored instead of shared ones. Yay.
            trackHash.put(currTrackName, currDbFtype) ;
          }
        }
        // Convert hash->hashes to hash->arrayList
        for(String currClass : hashOfTracksByClass.keySet())
        {
          ArrayList<DbFtype> trackList = new ArrayList<DbFtype>() ;
          uniqueTrackListByClass.put(currClass, trackList) ;
          HashMap<String, DbFtype> trackHash = hashOfTracksByClass.get(currClass) ;
          trackList.addAll(trackHash.values()) ;
        }
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: GBrowserUtils#getCompleteTracksByClassHashMap(D[]) => DB connection exception getting class->tracks map") ;
        ex.printStackTrace(System.err) ;
        uniqueTrackListByClass = null ;
      }
    }
    return uniqueTrackListByClass ;
  }

  // TODO: convert trackView to typed HashMap
  public static String generateMenus(HashMap<String, ArrayList<DbFtype>> dbFtypesByClass, Hashtable trackView, boolean userRoleCanEdit)
  {
    String finalString = null ;
    StringBuffer htmlBuff = new StringBuffer(200) ;

    // Loop over each class
    List<String> sortedClasses = new ArrayList<String>(dbFtypesByClass.keySet()) ;
    Collections.sort(sortedClasses, String.CASE_INSENSITIVE_ORDER) ;
    String imgStyle = " style=\"width: 16px; height: 16px; float: left; display: inline; padding:0.1em 0em; margin:0.1em 0em;\" " ;
    String imgDivStyle = " style=\"white-space:nowrap; float:right; width:114px; margin:0em 0em; padding: 0em 0em; display:none;\" " ;
    for(String currClass : sortedClasses)
    {
      String urlEscClass = Util.urlEncode(currClass) ;
      // Start the row for this class
      htmlBuff.append("<tr>\n") ;
      htmlBuff.append("  <td bgcolor=\"#847AB9\" colspan=\"4\" width=\"100%\" align=\"center\" valign=\"middle\">\n") ;
      // Add div for button that hides/shows tracks
      htmlBuff.append("    <div id=\"genb_trackDisplayDiv_").append(urlEscClass).append("\" style=\"float:left; width:16px; margin-left:1px; margin-right:auto; padding-top:1px; padding-bottom:1px;\"><!--\n") ;
      htmlBuff.append("      --><img id=\"genb_hideTracksBtn_").append(urlEscClass).append("\" src=\"/images/icon_minus16x16.png\" width=\"16\" height=\"16\" alt=\"Hide Tracks\" title=\"Hide Tracks\" onclick=\"trackDisplayToggle('").append(urlEscClass).append("', 'hideTracks');\"><!--\n") ;
      htmlBuff.append("      --><img id=\"genb_showTracksBtn_").append(urlEscClass).append("\" src=\"/images/icon_plus16x16.png\" width=\"16\" height=\"16\" style=\"display:none;\" alt=\"Show Tracks\" title=\"Show Tracks\" onclick=\"trackDisplayToggle('").append(urlEscClass).append("', 'showTracks');\"><!--\n") ;
      htmlBuff.append("    --></div>") ;
      // Add div to contain Class text in middle
      htmlBuff.append("    <div id=\"genb_classDiv_").append(urlEscClass).append("\" style=\"float:left; width:600px; margin-left:auto; margin-right:auto; padding-top:2px; font-weight:bold; color:white; white-space:nowrap; \"><!--\n") ;
      htmlBuff.append("      -->" + Util.htmlQuote(currClass)).append("&nbsp;&nbsp;") ;
      htmlBuff.append("    </div>") ;
      // Add the 2 button divs
      // First only has the show button and is displayed by default
      htmlBuff.append("    <div id=\"genb_classDisplayNoBtnsDiv_").append(urlEscClass).append("\" style=\"float:right; width:16px; margin-right:1px; padding-top:1px; padding-bottom:1px; \"><!--\n") ;
      htmlBuff.append("      --><img src=\"/images/icon_arrowLeft1.png\"").append(imgStyle).append("alt=\"Show Quick-Sets\" title=\"Show Quick-Sets\" onclick=\"classDisplayToggle('").append(urlEscClass).append("', 'showBtns');\"><!--\n") ;
      htmlBuff.append("    --></div><!--\n") ;
      // Second has all the buttons, including one to retract button, and is not displayed by default
      htmlBuff.append("    --><div id=\"genb_classDisplayAllBtnsDiv_").append(urlEscClass).append("\"").append(imgDivStyle).append("><!--\n") ;
      htmlBuff.append("      --><img src=\"/images/icon_arrowRight1.png\"").append(imgStyle).append("alt=\"Hide Quick-Sets\" title=\"Hide Quick-Sets\" onclick=\"classDisplayToggle('").append(urlEscClass).append("', 'hideBtns');\"><!--\n") ;
      htmlBuff.append("      --><img src=\"/images/icon_expand1.png\"").append(imgStyle).append("alt=\"Expand\" title=\"Expand\" onclick=\"classDisplayToggle('").append(urlEscClass).append("', 'expand');\"><!--\n") ;
      htmlBuff.append("      --><img src=\"/images/icon_compact1.png\"").append(imgStyle).append("alt=\"Compact\" title=\"Compact\" onclick=\"classDisplayToggle('").append(urlEscClass).append("', 'compact');\"><!--\n") ;
      htmlBuff.append("      --><img src=\"/images/icon_x1.png\"").append(imgStyle).append("alt=\"Hide\" title=\"Hide\" onclick=\"classDisplayToggle('").append(urlEscClass).append("', 'hide');\"><!--\n") ;
      htmlBuff.append("      --><img src=\"/images/icon_multiColor1.png\"").append(imgStyle).append("alt=\"Multicolor\" title=\"Multicolor\" onclick=\"classDisplayToggle('").append(urlEscClass).append("', 'multicolor');\"><!--\n") ;
      htmlBuff.append("      --><img src=\"/images/icon_nameExpand1.png\"").append(imgStyle).append("alt=\"Expand with Names\" title=\"Expand with Names\" onclick=\"classDisplayToggle('").append(urlEscClass).append("', 'nameExpand');\"><!--\n") ;
      htmlBuff.append("      --><img src=\"/images/icon_expandComments1.png\"").append(imgStyle).append("alt=\"Expand with Comments\" title=\"Expand with Comments\" onclick=\"classDisplayToggle('").append(urlEscClass).append("', 'commentExpand');\"><!--\n") ;
      htmlBuff.append("    --></div><!--\n") ;
      htmlBuff.append("  --></td>\n") ;
      htmlBuff.append("</tr>\n") ;
      // Start the rows for each track in this class ; each row has a class-specific CSS class so we can hide/show via javascript
      htmlBuff.append("<tr class=\"genb_trackRow_").append(urlEscClass).append("\">\n") ;
      int columnCount = 0 ;
      ArrayList<DbFtype> currTrackList = dbFtypesByClass.get(currClass) ;
      // Sort the DbFtypes by their track names
      Collections.sort((List)currTrackList, new Comparator()
      {
        public int compare(Object aa, Object bb)
        {
          DbFtype xx = (DbFtype)aa ;
          DbFtype yy = (DbFtype)bb ;
          return (xx.toString().compareToIgnoreCase(yy.toString())) ;
        }
      } ) ;

      for(DbFtype currDbFtype : currTrackList)
      {
        if(columnCount > 3)
        {
          htmlBuff.append("                   ") ;
          htmlBuff.append("<tr class=\"genb_trackRow_").append(urlEscClass).append("\">\n") ;
          columnCount = 0 ;
        }
        String myCurrentTrack = currDbFtype.toString() ;
        String qTrackName = Util.htmlQuote(myCurrentTrack) ;
        int curv = Util.parseInt((String)trackView.get(myCurrentTrack), 1) ;
        String jsParams = MapLinkFile.makeTrackPopUpParamStr(currDbFtype, userRoleCanEdit) ;
        // Put a <td> for the track text
        htmlBuff.append("  <td align=\"right\">\n");
        if(jsParams != null)
        {
          htmlBuff.append("    <a href=\"javascript:void(0);\" onclick=\"return popTrack(").append(jsParams).append(");\">\n<font color=\"#0044AA\">") ;
          htmlBuff.append(     qTrackName).append("</font>\n</a>\n") ;
        }
        else
        {
          htmlBuff.append("    <b>").append(qTrackName).append("<\b>\n") ;
        }
        htmlBuff.append("  </td>\n") ;
        // Put a <td> for the track display drop-list; make sure drop list has a CSS class for finding via javascript
        htmlBuff.append("  <td>\n") ;
        htmlBuff.append("    <select name=\"").append(qTrackName).append("\" id=\"").append(qTrackName) ;
        htmlBuff.append("    \" onChange=\"syncTrackVisibility(this)\" class=\"txt genb_trackSelect_").append(urlEscClass).append("\">\n") ;
        for(int jj=0; jj<GbrowserConstants.tvValues.length; jj++ )
        {
          htmlBuff.append("    <option value=\"").append(jj).append((curv == jj) ? "\" selected >" : "\" >") ;
          htmlBuff.append(       GbrowserConstants.tvValues[jj]) ;
          htmlBuff.append("    </option>\n") ;
        }
        htmlBuff.append("    </select>\n") ;
        htmlBuff.append("  </td>\n");
        columnCount += 2 ;
      }
      if(columnCount == 2)
      {
        htmlBuff.append("  <td>&nbsp;</td>\n<td>&nbsp;</td>\n") ;
      }
      htmlBuff.append("</tr>\n") ;
    }
    finalString = htmlBuff.toString() ;
    return finalString ;
  }
}
