package org.genboree.util;

import java.util.*;
import java.io.*;

/*
1 through 195869683, width=500

group	Rp1h	131	31	133	38	4350104	4366354
131	31	132	38	Gene	Rp1h	4350104	4356053	0.00	UCSC.RefSeq.mm3	http://genome.ucsc.edu/cgi-bin/hgTracks?org=Mouse&amp;db=mm3&amp;position=Rp1h
131	31	132	38	Gene	Rp1h	4357871	4358043	0.00	UCSC.RefSeq.mm3	http://genome.ucsc.edu/cgi-bin/hgTracks?org=Mouse&amp;db=mm3&amp;position=Rp1h
131	31	132	38	Gene	Rp1h	4358163	4358799	0.00	UCSC.RefSeq.mm3	http://genome.ucsc.edu/cgi-bin/hgTracks?org=Mouse&amp;db=mm3&amp;position=Rp1h
131	31	132	38	Gene	Rp1h	4366161	4366354	0.00	UCSC.RefSeq.mm3	http://genome.ucsc.edu/cgi-bin/hgTracks?org=Mouse&amp;db=mm3&amp;position=Rp1h
group	Sox17	131	31	133	38	4500150	4505635
131	31	132	38	Gene	Sox17	4500150	4501890	0.00	UCSC.RefSeq.mm3	http://genome.ucsc.edu/cgi-bin/hgTracks?org=Mouse&amp;db=mm3&amp;position=Sox17
131	31	132	38	Gene	Sox17	4502321	4502688	0.00	UCSC.RefSeq.mm3	http://genome.ucsc.edu/cgi-bin/hgTracks?org=Mouse&amp;db=mm3&amp;position=Sox17
131	31	132	38	Gene	Sox17	4502993	4503085	0.00	UCSC.RefSeq.mm3	http://genome.ucsc.edu/cgi-bin/hgTracks?org=Mouse&amp;db=mm3&amp;position=Sox17
131	31	132	38	Gene	Sox17	4504357	4505164	0.00	UCSC.RefSeq.mm3	http://genome.ucsc.edu/cgi-bin/hgTracks?org=Mouse&amp;db=mm3&amp;position=Sox17
131	31	132	38	Gene	Sox17	4505512	4505635	0.00	UCSC.RefSeq.mm3	http://genome.ucsc.edu/cgi-bin/hgTracks?org=Mouse&amp;db=mm3&amp;position=Sox17
group	Mrpl15	132	31	134	38	4780457	4792958
132	31	133	38	Gene	Mrpl15	4780457	4781763	0.00	UCSC.RefSeq.mm3	http://genome.ucsc.edu/cgi-bin/hgTracks?org=Mouse&amp;db=mm3&amp;position=Mrpl15
132	31	133	38	Gene	Mrpl15	4784770	4784894	0.00	UCSC.RefSeq.mm3	http://genome.ucsc.edu/cgi-bin/hgTracks?org=Mouse&amp;db=mm3&amp;position=Mrpl15
132	31	133	38	Gene	Mrpl15	4789813	4789979	0.00	UCSC.RefSeq.mm3	http://genome.ucsc.edu/cgi-bin/hgTracks?org=Mouse&amp;db=mm3&amp;position=Mrpl15
132	31	133	38	Gene	Mrpl15	4791198	4791353	0.00	UCSC.RefSeq.mm3	http://genome.ucsc.edu/cgi-bin/hgTracks?org=Mouse&amp;db=mm3&amp;position=Mrpl15
132	31	133	38	Gene	Mrpl15	4792820	4792958	0.00	UCSC.RefSeq.mm3	http://genome.ucsc.edu/cgi-bin/hgTracks?org=Mouse&amp;db=mm3&amp;position=Mrpl15
track	.Gene:RefSeq.Mm3	120	31	619	46
*/

public class MapReader
{
  public static boolean isEmpty( String s )
  {
    if( s == null ) return true;
    return (s.length() == 0);
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

  public static String[] parseString( String s, char del )
  {
    s = s + del;
    int idx = 0;
    Vector v = new Vector();
    while( (idx=s.indexOf(del)) >= 0 )
    {
      if( idx > 0 )
      {
        String ss = s.substring(0,idx); //.trim();
        v.addElement( ss );
      }
      s = s.substring(idx+1);
    }
    String[] rc = new String[ v.size() ];
    v.copyInto( rc );
    return rc;
  }

    public static final int MIN_WIDTH = 3;
    public static final int GAP = 3;
    public static final int GROUP_WIDTH = 10;
    public static final int MAX_WIDTH = 100;

    protected long lFrom = 1L;
    protected long lTo = 195869683L;
    protected int x0 = 120;
    protected int pWidth = 500;

    protected BufferedReader in;

    public MapReader( InputStream instr )
    {
        in = new BufferedReader( new InputStreamReader(instr) );
    }

    protected Vector vBuf = new Vector();

    public String[] readLine()
    {
        try
        {
            while( vBuf.size() == 0 )
            {
                String s = in.readLine();
                if( s == null )
                {
                    flush();
                    break;
                }
                consumeLine( s );
            }
            if( vBuf.size() == 0 ) return null;
            String[] rc = (String[]) vBuf.elementAt(0);
            vBuf.removeElementAt(0);
            return rc;
        } catch( Exception ex ) {}
        return null;
    }

    protected void consumeLine( String s )
    {
        String[] ss = parseString( s, '\t' );
        if( ss==null || ss.length<5 ) return;
        if( ss[0].equals("group") ) consumeGroup( ss );
        else if( ss[0].equals("track") ) consumeTrack( ss );
        else if( parseInt(ss[0], -1) >= 0 ) consumeRecord0( ss );
    }

    protected Vector tBuf = new Vector();

    protected String gName;
    protected int gx1, gy1, gx2, gy2;
    protected long gFrom, gTo;
    protected int gcnt = 0;
    protected boolean small_group = false;

    protected void consumeGroup( String[] ss )
    {
        flushRecord0();
        int x1 = parseInt( ss[2], -1 );
        if( x1 < 0 ) return;
        int y1 = parseInt( ss[3], -1 );
        int x2 = parseInt( ss[4], -1 );
        int y2 = parseInt( ss[5], -1 );
        long from = parseLong( ss[6], -1L );
        long to = parseLong( ss[7], -1L );

        int dx = x2 - x1;
        int dy = (y1 - gy1);
        if( dy < 0 ) dy = -dy;

        if( dx>MIN_WIDTH || (gx2 - gx1)>=GROUP_WIDTH || (x1-gx2)>=GAP || dy>3 )
        {
            flush();
        }

        small_group = (dx<=MIN_WIDTH);

        if( gcnt == 0 )
        {
            gx1 = x1;
            gy1 = y1;
            gx2 = x2;
            gy2 = y2;
            gFrom = from;
            gTo = to;
            gName = ss[1];
            gcnt = 1;
        }
        else
        {
            if( gx2 < x2 ) gx2 = x2;
            if( gTo < to ) gTo = to;
            gcnt++;
        }
    }


    protected static class StartPosComparator implements Comparator
    {
        public int compare( Object o1, Object o2 )
        {
            String[] ss1 = (String[]) o1;
            String[] ss2 = (String[]) o2;
            long from1 = parseLong( ss1[6], 0L );
            long from2 = parseLong( ss2[6], 0L );
            if( from1 == from2 ) return 0;
            return (from1 < from2) ? -1 : 1;
        }
    }
    protected StartPosComparator spComparator = new StartPosComparator();

    Vector vRec = new Vector();
    protected void consumeRecord0( String[] ss )
    {
        vRec.addElement( ss );
    }
    protected void flushRecord0()
    {
        if( vRec.size() == 0 ) return;
        String[][] sss = new String[ vRec.size() ][];
        vRec.copyInto( sss );
        vRec.clear();
        Arrays.sort( sss, spComparator );
        for( int i=0; i<sss.length; i++ ) consumeRecord( sss[i] );
    }

    protected String[] lastss;
    protected int rx1, ry1, rx2, ry2;
    protected long rFrom, rTo;
    protected int rcnt = 0;

    protected long gMaxTo = 0L;
    protected boolean has_overlaps = false;

    protected void consumeRecord( String[] ss )
    {
        int x1 = parseInt( ss[0], -1 );
        if( x1 < 0 ) return;
        int y1 = parseInt( ss[1], -1 );
        int x2 = parseInt( ss[2], -1 );
        int y2 = parseInt( ss[3], -1 );
        long from = parseLong( ss[6], -1L );
        long to = parseLong( ss[7], -1L );

        int dx = x2 - x1;

        int dy = (y1 - ry1);
        if( dy < 0 ) dy = -dy;

        if( dy>5 ) gMaxTo = 0L;
        else if( (from+1L)<gMaxTo ) has_overlaps = true;

        if( gMaxTo < to ) gMaxTo = to;

        if( dx>MIN_WIDTH ||
            ((rx2-rx1)>=GROUP_WIDTH && !small_group) ||
            (x1-rx2)>=GAP || dy>5 )
        {
            if( rcnt>0 && x2>rx2 )
                flushRecord();
        }

        ry1 = y1;
        ry2 = y2;

        if( rcnt == 0 )
        {
            lastss = ss;
            rx1 = x1;
            rx2 = x2;
            rFrom = from;
            rTo = to;
            rcnt = 1;
        }
        else
        {
            if( rx2 < x2 ) rx2 = x2;
            if( rTo < to ) rTo = to;
            rcnt++;
        }
    }

    protected void flushRecord()
    {
        if( rcnt == 0 ) return;
        if( rcnt == 1 )
        {
            tBuf.addElement( lastss );
        }
        else if( gcnt > 0 )
        {
            Vector v = new Vector();
            v.addElement( "group" );
            v.addElement( gName );
            if( gcnt>1 || (gx2 - gx1)>=MAX_WIDTH )
            {
                v.addElement( ""+rx1 );
                v.addElement( ""+ry1 );
                v.addElement( ""+rx2 );
                v.addElement( ""+ry2 );
                v.addElement( ""+rFrom );
                v.addElement( ""+rTo );
            }
            else
            {
                v.addElement( ""+gx1 );
                v.addElement( ""+gy1 );
                v.addElement( ""+gx2 );
                v.addElement( ""+gy2 );
                v.addElement( ""+gFrom );
                v.addElement( ""+gTo );
            }
            tBuf.addElement( v );
        }
        rcnt = 0;
    }

    protected void consumeTrack( String[] ss )
    {
        vBuf.addElement( ss );
        flush();
        String trackName = ss[1];
        for( int i=0; i<tBuf.size(); i++ )
        {
            String[] sss = null;
            Object o = tBuf.elementAt(i);
            if( o instanceof Vector )
            {
                Vector v = (Vector) o;
                if( has_overlaps ) v.addElement( trackName );
                sss = new String[ v.size() ];
                v.copyInto( sss );
            }
            else sss = (String[]) o;
            vBuf.addElement( sss );
        }
        tBuf.clear();

        gMaxTo = 0L;
        has_overlaps = false;
    }

    protected void flush()
    {
        flushRecord0();
        flushRecord();
        if( gcnt == 0 ) return;
        gcnt = 0;
    }

/*
    public static void main( String[] args )
        throws Exception
    {
        long from = 1L;
        long to = 195869683;
        int width = 500;
        FileInputStream fIn = new FileInputStream( "genb45215.map" );

        MapReader mr = new MapReader( fIn );
        String[] ss;
        while( (ss=mr.readLine()) != null )
        {
            String s = "";
            for( int i=0; i<ss.length; i++ ) s = s + "\t" + ss[i];
            System.out.println( s.substring(1) );
        }

        fIn.close();
    }
*/
}
