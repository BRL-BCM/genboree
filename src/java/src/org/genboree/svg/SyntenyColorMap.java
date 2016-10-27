package org.genboree.svg ;

import java.util.* ;
import java.sql.* ;
import java.awt.image.* ;
import org.genboree.dbaccess.* ;

public class SyntenyColorMap
{
  private static IndexColorModel cm = null ;

  public static final IndexColorModel getColorModel()
  {
    if( cm == null )
    {
      createColorModel() ;
    }
    return cm ;
  }

  protected static final byte[] d_r =
  {
    (byte)0x00, (byte)0xF5, (byte)0xEE, (byte)0xEF, (byte)0x39, (byte)0x77,
    (byte)0x2F, (byte)0x16, (byte)0x99, (byte)0xF5, (byte)0x9B, (byte)0x98,
    (byte)0xCE, (byte)0xA6, (byte)0x66, (byte)0xDE, (byte)0x99, (byte)0xEF,
    (byte)0xCF, (byte)0xF6, (byte)0x99, (byte)0xCB, (byte)0x9C, (byte)0xE5
  } ;
  protected static final byte[] d_g =
  {
    (byte)0x00, (byte)0x3C, (byte)0xB4, (byte)0xF0, (byte)0x9B, (byte)0xBC,
    (byte)0x63, (byte)0x09, (byte)0x66, (byte)0xCB, (byte)0x97, (byte)0x0F,
    (byte)0x12, (byte)0xA6, (byte)0x66, (byte)0x97, (byte)0xC8, (byte)0x13,
    (byte)0xEC, (byte)0xF8, (byte)0x99, (byte)0xEA, (byte)0x2E, (byte)0xE5
  } ;
  protected static final byte[] d_b =
  {
    (byte)0x00, (byte)0x1D, (byte)0x12, (byte)0x64, (byte)0x2B, (byte)0xB3,
    (byte)0xAB, (byte)0x67, (byte)0x11, (byte)0x99, (byte)0xC8, (byte)0x08,
    (byte)0x83, (byte)0xA6, (byte)0x66, (byte)0xC5, (byte)0x32, (byte)0x85,
    (byte)0xEE, (byte)0xB2, (byte)0x0F, (byte)0xAD, (byte)0x93, (byte)0xE5
  } ;

  protected static final int nr = 6 ;
  protected static final int ng = 7 ;
  protected static final int nb = 6 ;
  protected static final int[] comp_r = new int[ 256 ] ;
  protected static final int[] comp_g = new int[ 256 ] ;
  protected static final int[] comp_b = new int[ 256 ] ;

  static
  {
    int sc_r = ng * nb ;
    int sc_g = nb ;
    for( int i=0 ; i<256 ; i++ )
    {
      comp_r[i] = ((i * (nr - 1))/0xFF) * sc_r ;
      comp_g[i] = ((i * (ng - 1))/0xFF) * sc_g ;
      comp_b[i] = (i * (nb - 1)) / 0xFF ;
    }
  }

  public static final void createColorModel()
  {
    ResultSet rs = null ;
    DbResourceSet dbRes = null;
    try
    {
      DBAgent db = DBAgent.getInstance() ;
      dbRes = db.executeQuery( null, "SELECT value FROM color" ) ;
      rs =  dbRes.resultSet;
      Vector v = new Vector() ;
      while(rs.next())
      {
        String s = rs.getString(1) ;
        if( s.startsWith("#") )
        {
          s = s.substring(1) ;
        }
        v.addElement(s) ;
      }

      dbRes.close();
      int n = v.size() ;
      byte[] r = new byte[n] ;
      byte[] g = new byte[n] ;
      byte[] b = new byte[n] ;

      for( int i=0 ; i<n ; i++ )
      {
        int c = 0x888888 ;
        String s = (String) v.elementAt(i) ;
        try
        {
          c = Integer.parseInt(s,16) ;
        }
        catch( Exception ex1 )
        {
          System.err.println("ERROR: SyntenyColorMap.createColorModel() (VGP) => can't parse '" + s + "' to an integer; bad value from color table.") ;
        }
        b[i] = (byte)( c & 0xFF ) ; c >>= 8 ;
        g[i] = (byte)( c & 0xFF ) ; c >>= 8 ;
        r[i] = (byte)( c & 0xFF ) ;
      }
      createDefaultColorModel( r, g, b ) ;
    }
    catch( Exception ex )
    {
      createDefaultColorModel( d_r, d_g, d_b ) ;
    }
    finally
    {
      DBAgent.safelyCleanup(rs, null) ;
    }
    return ;
  }

  public static final int rgbToIndex( int r, int g, int b )
  {
    return comp_r[r] + comp_g[g] + comp_b[b] ;
  }

  protected static final void createDefaultColorModel( byte[] _r, byte[] _g, byte[] _b )
  {
    byte[] r = new byte[256] ;
    byte[] g = new byte[256] ;
    byte[] b = new byte[256] ;
    int ir=0, ig=0, ib=0 ;
    int idx = 0 ;

    for( ir=0 ; ir<nr ; ir++ )
    {
      for( ig=0 ; ig<ng ; ig++ )
      {
        for( ib=0 ; ib<nb ; ib++ )
        {
          r[idx] = (byte) ((ir * 0xFF)/(nr - 1)) ;
          g[idx] = (byte) ((ig * 0xFF)/(ng - 1)) ;
          b[idx] = (byte) ((ib * 0xFF)/(nb - 1)) ;
          idx++ ;
        }
      }
    }
    int ncolors = idx ;

    for( int i=0 ; i<_r.length ; i++ )
    {
      int cr = ((int)_r[i]) & 0xFF ;
      int cg = ((int)_g[i]) & 0xFF ;
      int cb = ((int)_b[i]) & 0xFF ;
      idx = rgbToIndex( cr, cg, cb ) ;
      r[idx] = (byte) cr ;
      g[idx] = (byte) cg ;
      b[idx] = (byte) cb ;
    }
    cm = new IndexColorModel( 8, ncolors, r, g, b ) ;
  }
}
