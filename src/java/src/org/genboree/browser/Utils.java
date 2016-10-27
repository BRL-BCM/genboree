package org.genboree.browser ;


import java.util.regex.Pattern;
import java.util.regex.Matcher;


public class Utils
{
  public static String removeTracks(  String inputText )
  {
    String fullRegexString = "-&amp;nbsp;&lt;a href=.*trackmgr.jsp.*trackName=.*Edit Track Description.*&gt;',"; 
    Pattern compiledRegexTrack = Pattern.compile( fullRegexString , 8); // 40 is 8 (Multiline) + 32(DOTALL)
    Matcher matchRegexTrack= compiledRegexTrack.matcher(inputText);
    String capturedText = matchRegexTrack.replaceAll( "&amp;nbsp;'," );
    return capturedText;
  }

    public static long [] calcEditRange (long chromosomeSize)
  {
    // % Range to view depends on the size of the chromosome;
    // smaller % for very large ones and much larger % for smaller ones.
    // Minimum % is 1%. Maximum $ is 50%.
    // The range model is this:
    //    range = 4260*size^(-0.584)
    // This results in:
    //    250,000,000 => 5%  (view range 12,500,000)
    //     50,000,000 => 15% (view range 7,500,000)
    //      5,000,000 => 50% (view range  2,250,000)
    long[] arr = new long[2] ;
    long midPoint = chromosomeSize / 2 ;
    double rangeSizeFraction = 4260*Math.pow( (double)chromosomeSize, -0.584) ;
    if(rangeSizeFraction < 0.01)
    {
      rangeSizeFraction = 0.01 ;
    }
    else if(rangeSizeFraction > 0.5)
    {
      rangeSizeFraction = 0.5 ;
    }
    // Determine range in bases (rounded up)
    long rangeSize = (long)((chromosomeSize * rangeSizeFraction) + 0.5) ;
    // Determine coords
    long from = midPoint - (rangeSize / 2) ;
    if(from < 1)
    {
      from = 1 ;
    }
    long to = from + rangeSize ;
    if(to > chromosomeSize)
    {
      to = chromosomeSize ;
    }
    arr[0] = from ;
    arr[1] = to ;
    return arr ;
  }

}

