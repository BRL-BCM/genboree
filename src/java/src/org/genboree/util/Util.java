package org.genboree.util ;

import java.lang.* ;
import java.lang.management.* ;
import java.net.* ;
import java.util.* ;
import java.lang.reflect.Method ;
import java.security.MessageDigest;
import javax.servlet.http.Cookie ;
import org.apache.commons.lang.StringEscapeUtils ;    // ARJ -> from the apache commons-lang jar. http://commons.apache.org/lang/
import org.apache.commons.codec.digest.DigestUtils ;  // ARJ -> From the apache commons-codec jar. http://commons.apache.org/codec/

public class Util
{
  // ------------------------------------------------------------------
  // CLASS VARIABLES - shared throughout web server!
  // ------------------------------------------------------------------
  public static final String smtpHost = GenboreeConfig.getConfigParam("gbSmtpHost") ;
  public static long globalSaltCounter = 0 ;

  protected static Method mEncode = null, mDecode = null ;
  protected static int npars = 0 ;
  protected static final String alpha = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/ ";
  protected static String qchars = "\"&<>" ;
  protected static String[] qents = { "&quot;", "&amp;", "&lt;", "&gt;" } ;
  static
  {
    Class[] fps1 = { String.class } ;
    Class[] fps2 = { String.class, String.class } ;
    try
    {
      mEncode = URLEncoder.class.getMethod( "encode", fps2 ) ;
      mDecode = URLDecoder.class.getMethod( "decode", fps2 ) ;
      npars = 2 ;
    }
    catch(Exception ex1)
    {
      try
      {
        mEncode = URLEncoder.class.getMethod( "encode", fps1 ) ;
        mDecode = URLDecoder.class.getMethod( "decode", fps1 ) ;
        npars = 1 ;
      }
      catch( Exception ex ) {}
    }
  }

  public static void sleep(long duration) throws InterruptedException
  {
    Thread.sleep(duration) ;
  }

  // Test if right now (Calendar.getInstance()) is within the provided
  // time period. The time period is a Calendar[] with two entries:
  // the start time and the end time.
  public static boolean isCurrTimeWithinTimePeriod(Calendar[] timePeriod)
  {
    boolean retVal = false ;
    Calendar now = Calendar.getInstance() ;
    if( (now.equals(timePeriod[0])) ||
        (now.equals(timePeriod[1])) ||
        (now.after(timePeriod[0]) && now.before(timePeriod[1])))
    {
      retVal = true ;
    }
    return retVal ;
  }

  /**
   * Makes MD5 hexdigest string from input String.
   * - ARJ: use apache commons version of this. Old Genboree java code for this was slow, odd, and memory inefficient.
   *   Also was repeated over and over everywhere.
   * @param stringToDigest String The string to MD5 digest
   * @return String the hexdigest of the arg or null if arg == null
   */
  public static String generateMD5(String stringToDigest)
  {
    return DigestUtils.md5Hex(stringToDigest) ;
  }

  /**
   * Attempts to make a ~unique sting. Should NOT be used where uniqueness is REQUIRED (db ids or names).
   */
  public static String generateUniqueString()
  {
    return generateUniqueString("") ;
  }
  public static String generateUniqueString(String salt)
  {
    // Mod salt further (also ensures some sort of changing salt thing is used even if dev used no-arg version)
    salt = salt + globalSaltCounter ;
    globalSaltCounter += 1 ;
    // Get time in millis (not small enough resolution on its own, but may help)
    Calendar nowCal = Calendar.getInstance() ;
    long nowMillis = nowCal.getTimeInMillis() ;
    // Get ~Process Id (java-style but should separate from other processes also generating a unique string in this same time window)
    String processName = ManagementFactory.getRuntimeMXBean().getName() ;
    // Get a random number
    Random rand = new Random() ;
    long aRandNum = rand.nextLong() ;
    // Return above concatenated and then normalized as SHA1 string.
    return DigestUtils.shaHex("" + nowMillis + processName + aRandNum) ;
  }

  /**
   * Build a landmark String from base components
   *
   * @param chrom String the chromosome name
   * @param start int the start coord
   * @param stop int the stop coord
   * @return landmark String
   */
  public static String makeLandmark(String chrom, int start, int stop)
  {
    return Util.makeLandmark(chrom, "" + start, "" + stop) ;
  }
  /**
   * Build a landmark String from base components
   *
   * @param chrom String the chromosome name
   * @param start String the start coord
   * @param stop STring the stop coord
   * @return landmark String
   */
  public static String makeLandmark(String chrom, String start, String stop)
  {
    return chrom.trim() + ":" + start + "-" + stop ;
  }

  /**
   * encodes java string with UTF-8 characters
   * Note:  Java URLEncoder encode space (' ') with character '+', this is
   * not consistent with javascript's encode function named escape().
   * To make the encoded string consistent in both languages,
   * the occurances of '+' are  replaced with  "%20".

   * @param s  String to be encoded
   * @return s  String encoded
   *
  */
  public static String urlEncode( String s )
  {
    if(s != null)
    {
      try
      {
        Object[] pars = new Object[ npars ] ;
        if( npars > 1 )
        {
          pars[1] = "UTF-8" ;
        }
        pars[0] = s ;
        s =  (String) mEncode.invoke( URLEncoder.class, pars ) ;
        s = s.replaceAll("\\+", "%20") ;
        s = s.replaceAll("'", "%27") ;
      }
      catch( Exception ex )
      {
        ex.printStackTrace() ;
      }
    }
    return s ;
  }

  /**
   * REBUILDs the request params found in paramMap; encodes java string with UTF-8 characters
   * Additional parameters (e.g. userId, groupId, etc, if not already present) can be
   * added to the paramMap prior to calling this method.
   *
   * @param paramMap  paramMap from request...all the name value pairs (key=>String[])
   * @return postContentBuff   rebuilt query string
   *
  */
    public static String rebuildQueryString( Map paramMap )
    {
      StringBuffer postContentBuff = new StringBuffer() ;
      // 1.b Loop over request key-value pairs, append them to rhtml request:
      Iterator paramIter = paramMap.entrySet().iterator() ;
      while(paramIter.hasNext())
      {
        Map.Entry paramPair = (Map.Entry) paramIter.next() ;
        String pName = Util.urlEncode((String) paramPair.getKey()) ;
        String[] pValues = (String[]) paramPair.getValue() ; // <-- Array!
        postContentBuff.append("&") ;
        if(pValues != null) // then there is 1+ actual values
        {
          // Add all of the values to the POST
          for(int ii = 0; ii < pValues.length; ii++)
          {
            postContentBuff.append(pName).append("=").append(Util.urlEncode(pValues[ii])) ;
          }
        }
        else // no value, just a key? ok...
        {
          postContentBuff.append("&").append(pName).append("=") ;
        }
      }
      // 1.c Get the string we will post IF that's what we will be doing
      String postContentStr = postContentBuff.toString() ;
      return postContentStr ;
    }

    public static boolean hasUnwantedCharacters(String str)
    {
        char[] chars = str.toCharArray();
        for(int i = 0; i < chars.length; i++){
            if(!Character.isDigit(chars[i])){
                return true;
            }
        }
        return false;
    }
    public static String stripNonNumericCharacters(String str)
    {
        StringBuffer buffer = new StringBuffer();

        char[] chars = str.toCharArray();
        for(int i = 0; i < chars.length; i++){
            if(Character.isDigit(chars[i])){
                buffer.append(chars[i]);
            }
        }
        return buffer.toString();
    }
    public static String urlDecode( String s )
    {
      if(s != null)
      {
        try
        {
          Object[] pars = new Object[ npars ];
          if( npars > 1 ) pars[1] = "UTF-8";
          pars[0] = s;
          return (String) mDecode.invoke( URLDecoder.class, pars );
        }
        catch( Exception ex )
        {}
      }
      return s;
    }
    public static String base64decode( String src )
    {
        if( src == null ) return "";
        StringBuffer sb = new StringBuffer();
        char[] cc = src.toCharArray();
        int acc = 0;
        int nb = 0;
        for( int i=0; i<cc.length; i++ )
        {
            int idx = alpha.indexOf( cc[i] );
            if( idx >= 0 )
            {
                acc = (acc << 6) | idx;
                nb += 6;
                while( nb >= 8 )
                {
                    sb.append( (char)((acc >> (nb-8)) & 0xFF) );
                    nb -= 8;
                }
            }
        }
        return sb.toString();
    }
    public static String base64encode( String src )
    {
        if( src == null ) return "";
        StringBuffer sb = new StringBuffer();
        byte[] bb = null;
        try{ bb = src.getBytes( "iso-8859-1" ); }
        catch( Exception ex ) { bb = new byte[0]; }
        int acc = 0;
        int nb = 0;
        for( int i=0; i<bb.length; i++ )
        {
            acc = (acc << 8) | (((int)bb[i]) & 0xFF);
            nb += 8;
            while( nb >= 6 )
            {
                int idx = (acc >> (nb-6)) & 0x3F;
                sb.append( alpha.charAt(idx) );
                nb -= 6;
            }
        }
        if( nb != 0 )
        {
            sb.append( alpha.charAt( (acc<<(6-nb))&0x3F ) );
            sb.append( '=' );
            if( nb == 2 ) sb.append( '=' );
        }
        return sb.toString();
    }
    public static boolean isEmpty( String s )
    {
        if( s == null ) return true;
        else if( s.length() == 0 ) return true;
        else if (s.equalsIgnoreCase("null") ) return true;
        else return false;
    }
    public static int decodeNumber( String s )
    {
        if( s == null ) return 0;
        StringBuffer src = new StringBuffer( s );
        StringBuffer tgt = new StringBuffer();
        for( int i=0; i<src.length(); i++ )
        {
            char c = src.charAt(i);
            if( Character.isDigit(c) ) tgt.append( c );
        }
        int rc = 0;
        try
        {
            rc = Integer.parseInt( tgt.toString() );
        } catch( Exception ex ) {}
        return rc;
    }
    public static int parseInt( String s, int defv )
    {
        try
        {
            int rc = Integer.parseInt( s );
            return rc;
        } catch( Exception ex ) {}
        return defv;
    }
    public static long parseLong( String s, long defv )
    {
        try
        {
            long rc = Long.parseLong( s );
            return rc;
        } catch( Exception ex ) {}
        return defv;
    }
    public static double parseDouble( String s, double defv )
    {
        try
        {
            double rc = Double.parseDouble( s );
            return rc;
        } catch( Exception ex ) {}
        return defv;
    }
    public static String getXMLCompliantString (String s)
    {
        String retVal = " ";
        if (s==null) retVal = " ";
        else{
            retVal = Util.simpleJsQuote(Util.htmlQuote(s));
        }

        return retVal;
    }
    public static String htmlQuote( String s )
    {
        if( s == null ) s = "";
        StringBuffer sb = new StringBuffer( s );
        StringBuffer rc = new StringBuffer();
        for( int i=0; i<sb.length(); i++ )
        {
            char c = sb.charAt(i);
            int idx = qchars.indexOf( c );
            if( idx >= 0 ) rc.append( qents[idx] );
            else rc.append( c );
        }
        return rc.toString();
    }
    public static String htmlUnQuote( String s )
    {
        if( s == null ) s = "";
        for( int i=0; i<qents.length; i++ )
        {
            int idx = -1;
            String qent = qents[i];
            int l = qent.length();
            while( (idx = s.indexOf(qent)) >= 0 )
            {
                s = s.substring(0,idx) + qchars.charAt(i) + s.substring(idx+l);
            }
        }
        return s;
    }
    // Really this is for use with jsQuote to double-quote a string. They do it in 2 different ways though.
    // It ought to be safe to just call jsQuote twice than do this...(jsQuote(jsQuote(str)))
    public static String simpleJsQuote( String s )
    {
        return StringEscapeUtils.escapeJavaScript(s) ; // ARJ -> from apache commons-lang.
    }
    public static String doubleJsQuote(String ss)
    {
      return StringEscapeUtils.escapeJavaScript(StringEscapeUtils.escapeJavaScript(ss)) ;
    }
    public static String jsQuote( String s )
    {
        return StringEscapeUtils.escapeJavaScript(s) ; // ARJ -> from apache commons-lang.
    }
    public static String escapeHtml(String ss)
    {
      return StringEscapeUtils.escapeHtml(ss) ;
    }
    // ARJ => COMPLAINT: wtf is this.
    // - this is DUMB, use String#split("<regexp>")...faster, shorter, less to maintain
    // - this approach is none too sophisticated anyway...plus should be using ArrayList anyway.
    public static String[] parseString( String s, char delimiter )
    {
      s = s + delimiter ;
      int idx = 0 ;
      Vector v = new Vector() ;
      while((idx=s.indexOf(delimiter)) >= 0)
      {
        if(idx > 0)
        {
          String ss = s.substring(0, idx); //.trim();
          v.addElement(ss) ;
        }
        s = s.substring(idx+1) ;
      }
      String[] rc = new String[v.size()] ;
      v.copyInto(rc) ;
      return rc ;
    }
    public static String[] getUserInfo( Cookie cc )
    {
        if( cc == null ) return null;
        String[] rc = new String[ 3 ];
        String[] uinf = parseString( cc.getValue(), '&' );
        for( int j=0; j<uinf.length-1; j+=2 )
        {
            String key = uinf[j];
            String val = urlDecode( uinf[j+1] );
            if( key.equals("pass") ) rc[1] = val;
            else if( key.equals("username") ) rc[0] = val;
            else if( key.equals("id") ) rc[2] = val;
        }
        if( rc[0]!=null && rc[1]!=null && rc[2]!=null ) return rc;
        return null;
    }
    public static Cookie setUserInfo( String[] user_info )
    {
        if( user_info == null ) return null;
        String cval = "pass&"+urlEncode(user_info[1])+
                "&id&"+urlEncode(user_info[2])+
                "&username&"+urlEncode(user_info[0]);
        Cookie rc = new Cookie( "userdata", cval );
        return rc;
    }
    // ARJ => COMPLAIN: wtf...um, how about a HashMap for storing unique things?
    // . adding N items to a list this way involves N^2 iterations
    // . Just use a HashMap and store as the value of current (pre-put()) HashMap#.size() ...arrrrrghhh....
    public static int addUniqueToVector( Vector v, Object val )
    {
        int idx = v.indexOf( val );
        if( idx < 0 )
        {
            v.addElement( val );
            idx = v.size() - 1;
        }
        return idx;
    }

    public static String commify(long src)
    {
      return Util.commify("" + src) ;
    }
    public static String commify(int src)
    {
      return Util.commify("" + src) ;
    }
    public static String commify( String src )
    {
        if( src == null ) return null;
        int l = src.length() - 3;
        while( l > 0 )
        {
            src = src.substring(0,l) + "," + src.substring(l);
            l -= 3;
        }
        return src;
    }
    public static String putCommas(String src)
    {
      return Util.commify(src) ;
    }


    public static String remCommas( String src )
    {
        if( src == null ) return null;
        int idx = src.indexOf( ',' );
        while( idx >= 0 )
        {
            src = src.substring(0,idx) + src.substring(idx+1);
            idx = src.indexOf( ',' );
        }
        idx = src.indexOf( '.' );
        if( idx >= 0 ) src = src.substring( 0, idx );
        return src;
    }
    public static boolean areEqual( String s1, String s2 )
    {
        if( s1 == null && s2 == null ) return true;
        if( s1 == null || s2 == null ) return false;
        return s1.equals(s2);
    }

    public static String getMemString()
    {
        return "" + (Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory()) + " / " + Runtime.getRuntime().maxMemory();
    }

}
