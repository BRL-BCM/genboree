package org.genboree.browser ;

import java.util.* ;
import java.io.* ;
import java.util.regex.* ;
import org.genboree.util.* ;
import org.genboree.dbaccess.* ;

// Given location of special map data file from C program,
// writes out <map> and var linkNames files for use on gbrowser.jsp page.
// . rawMapDataFile   -> File object for raw map file from C program
// . finalMapFile     -> File object for file to write out to for <map></map>
// . linkNameFile     -> File object for file to write out to for links
// . trackName2Ftype  -> HashMap of track name -> DbFtype object (already filled out)
public class MapLinkFile
{
  // Buffers, etc, for -reuse- during processing
  protected StringBuffer coords = new StringBuffer() ;
  // Data structures for holding unique linkUrls and names. Maps linkUrl => urlIndex and linkName => nameIndex:
  HashMap<String,Integer> linkUrls = new HashMap<String,Integer>() ;
  HashMap<String,Integer> linkNames = new HashMap<String,Integer>() ;
  // Input from caller
  protected File rawMapDataFile ;
  protected File finalMapFile ;
  protected File finalLinkFile ;
  protected HashMap trackName2Ftype ;
  protected boolean i_am_owner ;
  protected boolean userCanEdit ;

  // CONSTRUCTOR.
  public MapLinkFile(File rawMapDataFile, File finalMapFile, File finalLinkFile, HashMap trackName2Ftype, boolean userCanEdit)
  {
    this.rawMapDataFile = rawMapDataFile ;
    this.finalMapFile = finalMapFile ;
    this.finalLinkFile = finalLinkFile ;
    this.trackName2Ftype = trackName2Ftype ;
    this.i_am_owner = userCanEdit ; // stupid name for this field...leftover from a bad design; use "userCanEdit" instead
    this.userCanEdit = userCanEdit ;
    // Prime linkNames (order is important...will be recorded in the Map):
    addUniqWithIndexToLinkNames("Too Dense. Zoom In to See Links.") ;
    addUniqWithIndexToLinkNames( "Overlapped Data. Please Expand.") ;
    addUniqWithIndexToLinkNames( "Center &amp; Zoom To Annotation.") ;
  }

  public boolean createMapAndLinkFile()
  {
    long startTime = System.currentTimeMillis() ;
    boolean retVal = true ;
    // We intentionally will buffer ALL the <area> tag HTML content in memory
    // and then dump it out at the very end.
    StringBuffer outBuff = new StringBuffer() ;
    // Other, intermediate buffers:
    StringBuffer jsParams = new StringBuffer() ;
    StringBuffer mUrl = new StringBuffer() ;

    try
    {
      // Map file writer:
      FileWriter mapFileWriter = new FileWriter(this.finalMapFile) ;
      PrintWriter mapWriter = new PrintWriter(new BufferedWriter(mapFileWriter)) ;
      // Start the <map> tag in the map file.
      mapWriter.println( "<map name=\"genomeimap\" id=\"genomeimap\" class=\"crosshair\" >" ) ;
      // Now need to construct <area> tags...read from special file from C program and transform
      if(rawMapDataFile.exists()) // then we have special file from C program
      {
        String cLine = null ;
        String[] cFields = null ;
        String curTrackName = "#" ;
        int mIdx = -1 ;
        boolean hdhvFlag = false ;
        // Go through rawMapDataFile file line-by-line. We will suck the whole file into memory and create a StringReader around that.
        int mapFileSize = (int)this.rawMapDataFile.length() ;
        BufferedReader mapFileReader = new BufferedReader(new FileReader(this.rawMapDataFile)) ;
        char[] mapFileContentArray = new char[mapFileSize] ;
        int numCharsRead = mapFileReader.read(mapFileContentArray, 0, mapFileSize) ;
        String mapFileContent = new String(mapFileContentArray) ;
        mapFileReader.close() ;
        BufferedReader mapFileStrReader = new BufferedReader(new StringReader(mapFileContent)) ;

        System.err.println("    TIMING createMapAndLinkFile: all set up to start reading the raw map data made by C program = " + (System.currentTimeMillis() - startTime)) ;
        startTime = System.currentTimeMillis() ;

        // - Go through each found line with find()
        while( (cLine = mapFileStrReader.readLine()) != null )
        {
          // Parse and process the line
          cFields = cLine.split("\t") ;
          if(cFields[0] != null)
          {
            cFields[0] = cFields[0].trim() ;
            // Process line based on 'record type' info found in first column
            if(cFields[0].equals("track"))
            {
              curTrackName = cFields[1] ;
              continue ;
            }
            else if(cFields[0].equals("URL"))
            {
              DbFtype currDbFtype =  null ;
              if(trackName2Ftype.get(cFields[1]) != null)
              {
                currDbFtype = (DbFtype)trackName2Ftype.get(cFields[1]) ;
              }

              hdhvFlag = currDbFtype.isHighDensityTrack() ;
              String accessibleTrkName = makeTrackPopUpParamStr(currDbFtype, this.userCanEdit, hdhvFlag) ;
              if( accessibleTrkName != null )
              {
                String coordsStr = makeCoordsCSV(cFields, false) ;
                outBuff.append("<area href=\"javascript:void(0);\" ONCLICK=\"return popTrack(").append(accessibleTrkName) ;
                outBuff.append(");\" SHAPE=\"rect\" coords=\"").append(coordsStr).append("\">" ) ;
              }
              continue ;
            }
            else if(cFields[0].equals("group"))
            {
              long mFrom, mTo ;
              mFrom = Util.parseLong( cFields[6], -1L ) ;
              mTo = Util.parseLong( cFields[7], -1L ) ;
              long mRange20 = (mTo - mFrom) / 7 ;
              mFrom -= mRange20 ;
              mTo += mRange20 ;
              if(mFrom < 1L)
              {
                mFrom = 1L ;
              }
              mUrl.setLength(0) ;
              mUrl.append("handleNav(").append(mFrom).append(",").append(mTo).append(");") ;
              mIdx = addUniqWithIndexToLinkUrls(mUrl.toString()) ;

              // Make the params to the onclick Javascript call, as string (escpae as HTML here, since onclick='{sometext}')
              jsParams.setLength(0) ;
              jsParams.append("'").append(Util.escapeHtml(Util.jsQuote(curTrackName))).append("','").append(Util.escapeHtml(Util.jsQuote(cFields[1]))).append("',") ;
              jsParams.append(cFields[6]).append(",").append(cFields[7]).append(",'0','").append(cFields[8]).append("','N',0,").append(mIdx) ;
              if(cFields.length > 9)
              {
                mUrl.setLength(0) ;
                mUrl.append("expandTrack(\"").append(Util.doubleJsQuote(cFields[9])).append("\");") ;
                mIdx = addUniqWithIndexToLinkUrls(mUrl.toString()) ;
                jsParams.append(",1,").append(mIdx) ;
              }
              jsParams.append(",-1") ;
              String coordsStr = makeCoordsCSV(cFields, false) ;
              outBuff.append("<area href=\"javascript:void(0);\" ONCLICK=\"return popl(") ;
              outBuff.append(jsParams.toString()).append(");\" SHAPE=\"rect\" coords=\"").append(coordsStr).append("\">") ;
            }
            else if(cFields[0].equals("hdhv"))
            {
              long mFrom, mTo ;
              mFrom = Util.parseLong( cFields[6], -1L ) ;
              mTo = Util.parseLong( cFields[7], -1L ) ;
              long mRange20 = (mTo - mFrom) / 7 ;
              mFrom -= mRange20 ;
              mTo += mRange20 ;
              if(mFrom < 1L)
              {
                mFrom = 1L ;
              }
              mUrl.setLength(0) ;
              mUrl.append("handleNav(").append(mFrom).append(",").append(mTo).append(");") ;
              mIdx = addUniqWithIndexToLinkUrls(mUrl.toString()) ;

              // Make the params to the onclick Javascript call, as string (escpae as HTML here, since onclick='{sometext}')
              jsParams.setLength(0) ;
              jsParams.append("'").append(Util.escapeHtml(Util.jsQuote(curTrackName))).append("','").append(Util.escapeHtml(Util.jsQuote(cFields[1]))).append("',") ;
              jsParams.append(cFields[6]).append(",").append(cFields[7]).append(",'0','").append(cFields[8]).append("','N',2,").append(mIdx) ;


              jsParams.append(",-1") ;
              String coordsStr = makeCoordsCSV(cFields, false) ;
              outBuff.append("<area href=\"javascript:void(0);\" ONCLICK=\"return popl(") ;
              outBuff.append(jsParams.toString()).append(");\" SHAPE=\"rect\" coords=\"").append(coordsStr).append("\">") ;
            }
            else // some other kind of line in the special map file from C program
            {
              boolean need_hr = true ;
              // Make image coords CSV string
              String coordsStr = makeCoordsCSV(cFields, true) ;
              // Make and store the URL
              mUrl.setLength(0) ;
              mUrl.append("centerAnnotation(\"").append(Util.escapeHtml(cFields[4].replaceAll("'", "\\\\\\\\'"))).append("\",\"") ;
              mUrl.append(Util.escapeHtml(cFields[5]).replaceAll("'", "\\\\\\\\'")).append("\",\"") ;
              mUrl.append(Util.escapeHtml(curTrackName.replaceAll("'", "\\\\\\\\'"))).append("\");") ;
              mIdx = addUniqWithIndexToLinkUrls(mUrl.toString()) ;
              // Make the params to the onclick Javascript call, as string (escpae as HTML here, since onclick='{sometext}')
              jsParams.setLength(0) ;
              jsParams.append("\"").append(Util.escapeHtml(Util.jsQuote(curTrackName))).append("\",\"").append(Util.escapeHtml(Util.jsQuote(cFields[5]))) ;
              jsParams.append("\",").append(cFields[6]).append(",").append(cFields[7]).append(",\"") ;
              jsParams.append(cFields[8]).append("\",\"").append(cFields[9]).append("\",'L',") ;
              jsParams.append("2,").append(mIdx).append(",") ;
              // - do DB specific links
              ArrayList vLnk = new ArrayList() ;
              for( int ii=10; ii<cFields.length-1; ii+=2 )
              {
                // make link string to go in the Javascript linkNames and linkUrls objects
                DbLink lnk = new DbLink() ;
                lnk.setName(Util.jsQuote(cFields[ii])) ; // a name for the URL, could be anything, so escape it
                lnk.setDescription(cFields[ii+1]) ; // should just be a URL...already quoted if stored in DB properly, so don't quote
                vLnk.add(lnk) ;
              }
              DbLink[] popLinks = new DbLink[ vLnk.size() ] ;
              vLnk.toArray( popLinks ) ;
              Arrays.sort( popLinks ) ; // sort alphabetically (ascii?)
              for( int ii=0; ii<popLinks.length; ii++ )
              {
                if( need_hr )
                {
                  jsParams.append("-2,") ;
                  need_hr = false ;
                }
                DbLink lnk = popLinks[ii] ;
                int i1 = addUniqWithIndexToLinkNames(lnk.getName()) ;
                int i2 = addUniqWithIndexToLinkUrls(lnk.getDescription()) ;
                jsParams.append(i1).append(",").append(i2).append(",") ;
              }
              jsParams.append("-1") ;
              outBuff.append("<area href=\"javascript:void(0);\" ONCLICK=\"return popl(") ;
              outBuff.append(Util.escapeHtml(jsParams.toString())).append(");\" SHAPE=\"rect\" coords=\"").append(coordsStr).append("\">") ;
            }
          }
        }
        System.err.println("    TIMING createMapAndLinkFile: done line-by-line read of map file = " + (System.currentTimeMillis() - startTime)) ;
        startTime = System.currentTimeMillis() ;
        // Clean up memory mapped file and such
        mapFileStrReader.close() ;
        mapFileContent = null ;
        mapFileContentArray = null ;
        System.err.println("    TIMING createMapAndLinkFile: done freeing mem-mapped raw map file = " + (System.currentTimeMillis() - startTime)) ;
        startTime = System.currentTimeMillis() ;
        // Dump <area> tag HTML content and clear out the buffer.
        mapWriter.println(outBuff.toString()) ;
        outBuff.setLength(0) ;
        outBuff.trimToSize() ;
        System.err.println("    TIMING createMapAndLinkFile: done writing out accumulated <area> tag content = " + (System.currentTimeMillis() - startTime)) ;
        startTime = System.currentTimeMillis() ;
        //  end of special map file reading
        // Done writing <area> tags to map file.
        mapWriter.println( "</map>" ) ;
        mapWriter.close() ;
        System.err.println("    TIMING createMapAndLinkFile: all done producing <area> tag content = " + (System.currentTimeMillis() - startTime)) ;
        startTime = System.currentTimeMillis() ;

        // Now prep the links file, which stores the javascript hash/associative-array of unique linkNames
        FileWriter linkNameWriter = new FileWriter(finalLinkFile) ;
        PrintWriter linkNameFileWriter = new PrintWriter(new BufferedWriter(linkNameWriter)) ;
        // Write out unique linkNames by iterating over HashMap's entries in order of the VALUES
        // - first, declare the linkNames javascript object:
        outBuff.append("var linkNames = new Object(").append(this.linkNames.size()).append(");\n") ;
        // - second, we will store link entries by value (the index) using an auto-sorting set
        TreeSet<Map.Entry<String,Integer>> sortedLinkEntries =
          new TreeSet(  new Comparator<Map.Entry<String,Integer>>()
                        {
                          public int compare(Map.Entry<String,Integer> entryA, Map.Entry<String,Integer> entryB)
                          {
                            return (entryA.getValue().equals(entryB.getValue()) ? 0 : (entryA.getValue() > entryB.getValue() ? 1 : -1)) ;
                          }
                        }) ;
        // - third, add all the linkNames entries to the auto-sorting set
        sortedLinkEntries.addAll(linkNames.entrySet()) ;
        // - fourth, iterate over sorted linkNames entries
        Iterator linkNameIter = sortedLinkEntries.iterator() ;
        while(linkNameIter.hasNext())
        {
          Map.Entry<String,Integer> entry = (Map.Entry<String,Integer>)linkNameIter.next() ;
          int ii = entry.getValue() ;
          String lName = entry.getKey() ;
          outBuff.append("linkNames[").append(ii).append("] = '").append(lName).append("';\n") ;
        }
        // Clean up
        linkNames = null ;
        linkNameIter = null ;
        sortedLinkEntries.clear() ; // will reuse this sorted set belowIter = null ;
        System.err.println("    TIMING createMapAndLinkFile: done getting link data ; about to write out unique link info = " + (System.currentTimeMillis() - startTime)) ;
        startTime = System.currentTimeMillis() ;

        // Write out unique linkUrls by iterating over HashMap's entries in order of the VALUES
        // - first, declare the linkUrls javascript object:
        outBuff.append("var linkUrls = new Object(").append(linkUrls.size()).append(");\n") ;
        // - seocond, add all the linkUrls entries to the auto-sorting set
        sortedLinkEntries.addAll(linkUrls.entrySet()) ;
        // - second, iterate over sorted linkUrls entries
        Iterator linkUrlIter = sortedLinkEntries.iterator() ;
        while(linkUrlIter.hasNext())
        {
          Map.Entry<String,Integer> entry = (Map.Entry<String,Integer>)linkUrlIter.next() ;
          int ii = entry.getValue() ;
          String lUrl = entry.getKey() ;
          outBuff.append("linkUrls[").append(ii).append("] = \"").append(Util.escapeHtml(lUrl)).append("\";\n") ;
        }
        // Clean up
        //linkUrls = null ;
        sortedLinkEntries = null ;
        linkUrlIter = null ;
        // Done constructing output line, write out and clear buffer.
        linkNameFileWriter.println(outBuff.toString()) ;
        outBuff.setLength(0) ;
        outBuff.trimToSize() ;
        // Done writing to link file.
        linkNameFileWriter.close() ;
        System.err.println("    TIMING createMapAndLinkFile: done writing out unique link info = " + (System.currentTimeMillis() - startTime)) ;
        startTime = System.currentTimeMillis() ;
      }
      else
      {
        System.err.println("Unable to find the rawMapDataFile file =  " +  rawMapDataFile.getAbsolutePath()) ;
        retVal = false ;
      }
    }
    catch( Exception ex05 )
    {
      System.err.println("Exception gbrower.jsp: Probably unable to find the rawMapDataFile file =  " +  rawMapDataFile.getAbsolutePath() + "  **OR OTHER EXCEPTION**\n") ;
      ex05.printStackTrace(System.err) ;
      retVal = false ;
    }
    System.err.println("    TIMING createMapAndLinkFile: all finished = " + (System.currentTimeMillis() - startTime)) ;
    startTime = System.currentTimeMillis() ;
    return retVal ;
  }

  // Makes the string args passed to popl() for a track pop-up. The 3 string args are quoted in '' and
  // are the track name, the track url, the track label (html links & text), and the track description (html).
  public String makeTrackPopUpParamStr(DbFtype dbFtype)
  {
    return MapLinkFile.makeTrackPopUpParamStr(dbFtype, this.userCanEdit) ;
  }

  // --------------------------------------------------------------------------
  // Helpers
  // --------------------------------------------------------------------------
  // Non-replacing insert, index as key value.
  // - returns index (insert order index) of key
  // - if key NOT IN Map, then inserts key with proper index; return index
  // - if key IN Map, then returns index for that key
  protected int addUniqWithIndexToMap(HashMap<String,Integer> map, String key)
  {
    int retVal = -1 ;
    if(map.containsKey(key))
    {
      retVal = map.get(key) ;
    }
    else // key not stored yet
    {
      retVal = map.size() ;
      map.put(key, retVal) ;
    }
    return retVal ;
  }
  // addUniqWithIndexToMap for linkUrls
  protected int addUniqWithIndexToLinkUrls(String key)
  {
    return addUniqWithIndexToMap(this.linkUrls, key) ;
  }
  // addUniqWithIndexToMap for linkNames
  protected int addUniqWithIndexToLinkNames(String key)
  {
    return addUniqWithIndexToMap(this.linkNames, key) ;
  }

  protected String makeCoordsCSV(String[] cFields, boolean alt)
  {
    this.coords.setLength(0) ;
    if(alt)
    {
      coords.append(cFields[0]).append(",").append(cFields[1]).append(",").append(cFields[2]).append(",").append(cFields[3]) ;
    }
    else
    {
      coords.append(cFields[2]).append(",").append(cFields[3]).append(",").append(cFields[4]).append(",").append(cFields[5]) ;
    }
    return coords.toString() ;
  }

  // Wrapper for the regular method that do not need the hdhv flag.
  public static String makeTrackPopUpParamStr(DbFtype dbFtype, boolean userCanEdit)
  {
    return makeTrackPopUpParamStr(dbFtype, userCanEdit, dbFtype.isHighDensityTrack());
  }

  // Makes the string args passed to popl() for a track pop-up. The 3 string args are quoted in '' and
  // are the track name, the track url, the track label (html links & text), and the track description (html).
  public static String makeTrackPopUpParamStr(DbFtype dbFtype, boolean userCanEdit, boolean isHDHVTrack)
  {
    String retVal = null ;
    int maxSizeDescription = 1000 ;
    StringBuffer outBuff = new StringBuffer() ;
    StringBuffer tmpBuff = new StringBuffer() ;
    if(dbFtype != null)
    {
      // Get key track information
      String trackName = dbFtype.toString() ;
      String urlDescr = dbFtype.getUrlDescription() ;
      urlDescr = (urlDescr == null ? "" : urlDescr.trim()) ;
      String trackUrl = dbFtype.getUrl() ;
      trackUrl = (trackUrl == null ? "" : trackUrl.trim()) ;
      String urlLabel = dbFtype.getUrlLabel() ;
      urlLabel = (urlLabel == null ? "" : urlLabel.trim()) ;

      if(trackName != null)
      {
        // track name for use in urls:
        String escTrackName = Util.urlEncode(trackName) ;
        // FIRST PARAM, the track name:
        // backslash remains a problem. Here's a hack:
        trackName = trackName.replaceAll("\\\\", "\\\\\\\\") ;
        outBuff.append("'").append(Util.escapeHtml(Util.jsQuote(trackName))).append("','") ;
        // SECOND PARAM, the track url:
        if(trackUrl.length() == 0)
        {
          trackUrl = "''" ;
        }
        outBuff.append(Util.escapeHtml(Util.jsQuote(trackUrl))).append("','") ;
        // THIRD PARAM, the track label html & text:
        // do we need to display a URL: link?
        tmpBuff.setLength(0) ;
        if(!Util.isEmpty(urlLabel))
        {
          tmpBuff.append("<b>URL:</b> ") ;
          tmpBuff.append("<a onclick=\\'return winPopFocus(\"").append(trackUrl).append("\", \"_newWin\") ;\\'>") ;
          tmpBuff.append(Util.jsQuote(urlLabel.trim())).append("</a><br><hr>") ;
        }
        // link to tabular view of this track

        if(!isHDHVTrack)
        {
          tmpBuff.append("-&nbsp;<A HREF=\\'displaySelection.jsp?trackName=").append(escTrackName).append("\\'>Tabular View of Track Annotations</a><br>") ;
        }
        else
        {
          tmpBuff.append("-&nbsp;NO Tabular View available for HDHV Tracks<br>");
        }
        // link to edit this track's info (if allowed to edit)
        if(userCanEdit)
        {
          tmpBuff.append("-&nbsp;<a href=\\'/java-bin/trackmgr.jsp?mode=URL&trackName=" + escTrackName + "\\'>Edit Track Description</a>") ;
        }
        outBuff.append(Util.escapeHtml(tmpBuff.toString())) ;
        outBuff.append("','") ;
        // FOURTH PARAM, the formated track description
        tmpBuff.setLength(0) ;
        if(urlDescr.length() == 0)
        {
          urlDescr = "&nbsp;" ;
        }
        else
        {
          urlDescr.replaceAll("'", "\\'") ;
          String additionalText = "" ;
          if(urlDescr.length() > maxSizeDescription)
          {
            additionalText =  ( "<BR><BR>...<A HREF=showAllTrackDescription.jsp?uploadId=" +
                                dbFtype.getUploadId() + "&trackName=" + escTrackName + " target='trackDesc' >[MORE]</A>..."
                              ) ;
            urlDescr = urlDescr.substring(0, maxSizeDescription);
          }
          // make newlines in desc actual <br>
          tmpBuff.setLength(0) ;
          tmpBuff.append("<B>Description:</B><BR>") ;
          String[] descLines = urlDescr.split("\\n") ;
          for(int ii=0; ii<descLines.length; ii++ )
          {
            String descLine = descLines[ii].trim() ;
            tmpBuff.append(descLine).append("<br>") ;
          }
          // tmpBuff.append("</font>") ;
          urlDescr = Util.jsQuote(tmpBuff.toString() + additionalText) ;
        }
        outBuff.append(Util.escapeHtml(urlDescr)).append("'") ;
      }
      retVal = outBuff.toString() ;
    }
    return retVal ;
  }

    public static void printUsage()
  {
    System.out.print( "usage: MapLinkfile " );
    System.out.println(
            "-f fileName -r refseqId \n ");
    return;
  }

   public static void main( String[] args )
  {
    String fileName = null;
    String baseFileName = null;
    String refseqId = null;
    boolean madeMapAndLinkFile = false;
    boolean userCanEdit = true;
    String databaseName = null;
    HashMap trackName2Ftype = null;
    File finalMapFile = null;
    String linkNameString = null;
    String finalMapFileName = null;
    MapLinkFile mapLinkFile = null;
    File rawMapDataFile = null;
    File linkNameFile =  null;

    if( args.length < 4 )
    {
      printUsage();
      System.exit( -1 );
    }


    if( args.length >= 1 )
    {

      for( int i = 0; i < args.length; i++ )
      {
        if( args[ i ].compareToIgnoreCase( "-f" ) == 0 )
        {
          i++;
          if( args[ i ] != null )
          {
            fileName = args[ i ];
          }
        }  else if( args[ i ].compareToIgnoreCase( "-r" ) == 0 )
        {
          i++;
          if( args[ i ] != null )
          {
            refseqId = args[ i ];
          }
        } else
        {
          printUsage();
          System.exit( -1 );
        }
      }
    }

    baseFileName = fileName.replaceAll( "\\.\\S*", "" );
    finalMapFileName = baseFileName + "_final.map";
    linkNameString = baseFileName + ".links";

    System.err.println( "The file Name = " + fileName + "\nThe baseFileName = " + baseFileName + "\n the finalMapfilename = " + finalMapFileName + "\n the linkFileName = " + linkNameString  );



    rawMapDataFile = new File(fileName);
    finalMapFile = new File( rawMapDataFile.getParentFile(), finalMapFileName );
    linkNameFile =  new File(  rawMapDataFile.getParentFile(), linkNameString );
    databaseName = GenboreeUtils.fetchMainDatabaseName( refseqId, false);
    trackName2Ftype = GenboreeUtils.getTrackName2FtypeObject( refseqId, databaseName, false);
    mapLinkFile = new MapLinkFile(rawMapDataFile, finalMapFile, linkNameFile, trackName2Ftype, userCanEdit) ;
    madeMapAndLinkFile = mapLinkFile.createMapAndLinkFile();

    }


}
