package org.genboree.dbaccess;

import java.awt.*;
import java.sql.*;
import java.util.*;

public class Style
    implements Comparable
{
    public String styleId;
    public String featureType;
    public String name;
    public String description;
    public String color;
    public String fmethod;
    public String fsource;
    public int ftypeid;
    public int colorid;
    public String databaseName;

    public Style()
    {
        styleId = "0";
        ftypeid = -1;
        colorid = -1;
    }

    public int compareTo( Object o )
    {
        Style s = (Style) o;
        int rc = fmethod.compareTo( s.fmethod );
        if( rc == 0 ) rc = fsource.compareTo( s.fsource );
        return rc;
    }


    public static class HSBColor
        implements Comparable
    {
        public int r;
        public int g;
        public int b;
        public float h;
        public float s;
        public float br;
        public Style obj;
        public HSBColor( Style st )
        {
            obj = st;
            int rgb = 0;
            try
            {
                String sRgb = st.color;
                if( sRgb.startsWith("#") ) sRgb = sRgb.substring(1);
                rgb = Integer.parseInt( sRgb, 16 );
            } catch( Exception ex ) {}
            b = rgb & 0xFF; rgb >>= 8;
            g = rgb & 0xFF; rgb >>= 8;
            r = rgb & 0xFF;
            float[] hsbComp = Color.RGBtoHSB( r, g, b, null );
            h = hsbComp[0];
            s = hsbComp[1];
            br = hsbComp[2];
        }
        public int compareTo( Object o )
        {
            HSBColor hc = (HSBColor)o;
            if( s != hc.s ) return (s < hc.s) ? 1 : -1;
            if( br != hc.br ) return (br > hc.br) ? 1 : -1;
            if( h != hc.h ) return (h > hc.h) ? 1 : -1;
            return 0;
        }
    }

    public static class H_Comparator implements Comparator
    {
        public int compare( Object o1, Object o2 )
        {
            HSBColor hc1 = (HSBColor)o1;
            HSBColor hc2 = (HSBColor)o2;

            if( hc1.h != hc2.h ) return (hc1.h > hc2.h) ? 1 : -1;

            double ds = (double)(hc1.s - hc2.s);
            double db = (double)(hc1.br - hc2.br);
            if( ds < 0. ) ds = - ds;
            if( db < 0. ) db = -db;

            if( ds > db*2. )
                if( hc1.s != hc2.s ) return (hc1.s < hc2.s) ? 1 : -1;
            if( hc1.br != hc2.br ) return (hc1.br > hc2.br) ? 1 : -1;

            return 0;
        }
    }

    public static class B_Comparator implements Comparator
    {
        public int compare( Object o1, Object o2 )
        {
            HSBColor hc1 = (HSBColor)o1;
            HSBColor hc2 = (HSBColor)o2;
            double ds = (double)(hc1.s - hc2.s);
            double db = (double)(hc1.br - hc2.br);
            if( ds < 0. ) ds = - ds;
            if( db < 0. ) db = -db;
            if( ds > db*2. )
                if( hc1.s != hc2.s ) return (hc1.s < hc2.s) ? 1 : -1;
            if( hc1.br != hc2.br ) return (hc1.br > hc2.br) ? 1 : -1;
            return 0;
        }
    }

    public static Style[] fetchColors( Connection conn )
    {
        Vector v = new Vector();
        if( conn != null ) try
        {
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery( "SELECT colorId, value FROM color" );
            while( rs.next() )
            {
                Style st = new Style();
                st.colorid = rs.getInt(1);
                st.color = rs.getString(2);
                v.addElement( st );
            }
            stmt.close();
        } catch( Exception ex ) {}
        Style[] rc = new Style[ v.size() ];
        v.copyInto( rc );
        return rc;
    }

    public static Style[] sortByColors( Style[] scolors, int w )
    {
        int nc = scolors.length;
        if( nc < 12 || w < 3 ) return scolors;
        int h = nc / w;

        int i, row, col;
        H_Comparator h_c = new H_Comparator();
        B_Comparator b_c = new B_Comparator();
        HSBColor[] hc = new HSBColor[ scolors.length ];
        for( i=0; i<nc; i++ ) hc[i] = new HSBColor( scolors[i] );
        Arrays.sort( hc );

        for( row=0; row<h; row++ )
        {
            int i2 = (row + 1)*w - 1;
            if( i2 >= nc ) break;
            if( hc[i2].s < 0.12 ) break;
        }
        h = row;
        int ncc = h * w;

        HSBColor[] hc1 = new HSBColor[ ncc ];
        System.arraycopy( hc, 0, hc1, 0, ncc );
        Arrays.sort( hc1, 0, ncc, h_c );

        for( col=0; col<w; col++ )
        {
            int i1 = col * h;
            int i2 = (col + 1) * h;
            Arrays.sort( hc1, i1, i2, b_c );
            for( row=0; row<h; row++ )
            {
                hc[row*w + col] = hc1[i1 + row];
            }
        }

        for( i=0; i<nc; i++ ) scolors[i] = hc[i].obj;
        return scolors;
    }

    public static Style[] fetchAll( DBAgent db, String[] dbNames, int userId )
    {
        int i;
        Vector v = new Vector();
        String defStyleId = "0";
        String defColor = "#000000"; // "#2D7498";
        Connection conn = null;
        Statement stmt = null;
        DbResourceSet dbRes = null;
        ResultSet rs = null;
        try
        {
            for( i=0; i<dbNames.length; i++ )
            {
                dbRes = db.executeQuery( dbNames[i], "SELECT styleId FROM style WHERE name='simple_draw'" );
                rs = dbRes.resultSet;
                if( rs!=null && rs.next() )
                    defStyleId = rs.getString(1);
                dbRes.close();

                conn = db.getConnection( dbNames[i] );
                if( conn == null ) continue;
                stmt = conn.createStatement();

                PreparedStatement styleStmt = conn.prepareStatement(
                    "SELECT s.styleId, s.name, s.description "+
                    "FROM featuretostyle fs, style s "+
                    "WHERE fs.styleId=s.styleId AND fs.userId=? AND fs.ftypeid=?" );

                PreparedStatement colorStmt = conn.prepareStatement(
                    "SELECT c.colorId, c.value FROM featuretocolor fc, color c "+
                    "WHERE fc.colorId=c.colorId AND fc.userId=? AND fc.ftypeid=?" );

                rs = stmt.executeQuery( "SELECT ftypeid, fmethod, fsource FROM ftype" );
                while( rs.next() )
                {
                    Style s = new Style();

                    s.ftypeid = rs.getInt(1);
                    String ftypeid = ""+s.ftypeid;
                    s.fmethod = rs.getString(2);
                    s.fsource = rs.getString(3);

                    s.featureType = s.fmethod+":"+s.fsource;
                    s.styleId = defStyleId;
                    s.name = "simple_draw";
                    s.description = "Simple Rectangle";
                    s.color = defColor;
                    s.databaseName = dbNames[i];

                    v.addElement( s );

                    styleStmt.setInt( 1, userId );
                    styleStmt.setString( 2, ftypeid );
                    ResultSet rs1 = styleStmt.executeQuery();
                    if( !rs1.next() )
                    {
                        styleStmt.setInt( 1, 0 );
                        styleStmt.setString( 2, ftypeid );
                        rs1 = styleStmt.executeQuery();
                        if( !rs1.next() ) rs1 = null;
                    }
                    if( rs1 != null )
                    {
                        s.styleId = rs1.getString(1);
                        s.name = rs1.getString(2);
                        s.description = rs1.getString(3);
                    }

                    colorStmt.setInt( 1, userId );
                    colorStmt.setString( 2, ftypeid );
                    rs1 = colorStmt.executeQuery();
                    if( !rs1.next() )
                    {
                        colorStmt.setInt( 1, 0 );
                        colorStmt.setString( 2, ftypeid );
                        rs1 = colorStmt.executeQuery();
                        if( !rs1.next() ) rs1 = null;
                    }
                    if( rs1 != null )
                    {
                        s.colorid = rs1.getInt(1);
                        s.color = rs1.getString(2);
                    }
                }

                Style[] rc = new Style[ v.size() ];
                v.copyInto( rc );
                Arrays.sort( rc );
                return rc;
            }

        } catch( Exception ex )
        {
		    if( ex instanceof SQLException && ((SQLException)ex).getErrorCode()==1146 )
		        return fetchAllS( db, dbNames, userId );

            db.reportError( ex, "Style.fetchAll()" );
        }
        return new Style[0];
    }

    public static Style[] fetchAllS( DBAgent db, String[] dbNames, int userId )
    {
        int i;
        DbResourceSet dbRes = null;
        ResultSet rs = null;
        Hashtable ht = new Hashtable();
        String defStyleId = "0";
        String defColor = "#2D7498";
        Connection conn;
        Statement stmt;
        try
        {
            dbRes = db.executeQuery( "SELECT styleId FROM style WHERE name='gene_draw'" );
            rs = dbRes.resultSet;
            if( rs!=null && rs.next() )
                defStyleId = rs.getString(1);
            dbRes.close();
            for( i=0; i<dbNames.length; i++ )
            {
                conn = db.getConnection( dbNames[i] );
                if( conn == null ) continue;
                stmt = conn.createStatement();
                rs = stmt.executeQuery( "SELECT fmethod, fsource FROM ftype" );
                while( rs.next() )
                {
                    Style s = new Style();
                    s.fmethod = rs.getString(1);
                    s.fsource = rs.getString(2);
                    s.featureType = s.fmethod+":"+s.fsource;
                    s.styleId = defStyleId;
                    s.name = "gene_draw";
                    s.description = "Gene/exon";
                    s.color = defColor;
                    ht.put( s.featureType, s );
                }
                rs.close();
                stmt.close();
            }
            conn = db.getConnection();

            PreparedStatement ps0 = conn.prepareStatement(
                "SELECT featureTypeId FROM featuretype WHERE name=?" );
            PreparedStatement pss0 = conn.prepareStatement(
                "SELECT s.styleId, s.name, s.description "+
                "FROM defaultuserfeaturetypestyle dt, style s "+
                "WHERE dt.styleId=s.styleId AND featureTypeId=?" );
            PreparedStatement pss1 = null;
            PreparedStatement psc0 = conn.prepareStatement(
                "SELECT c.value "+
                "FROM color c, defaultColor dc "+
                "WHERE c.colorId=dc.colorId AND dc.featureTypeId=?" );
            PreparedStatement psc1 = null;

            if( userId > 0 )
            {
                pss1 = conn.prepareStatement(
                    "SELECT s.styleId, s.name, s.description "+
                    "FROM userfeaturetypestyle dt, style s "+
                    "WHERE dt.styleId=s.styleId AND featureTypeId=? "+
                    "AND dt.userId="+userId );
                psc1 = conn.prepareStatement(
                    "SELECT c.value "+
                    "FROM color c, userColor dc "+
                    "WHERE c.colorId=dc.colorId AND dc.featureTypeId=? "+
                    "AND dc.userId="+userId );
            }

            Style[] rc = new Style[ ht.size() ];
            int j = 0;
            for( Enumeration en=ht.keys(); en.hasMoreElements(); )
            {
                Style s = (Style) ht.get( en.nextElement() );
                rc[j++] = s;

                ps0.setString( 1, s.featureType );
                rs = ps0.executeQuery();
                if( !rs.next() ) continue;

                String ftid = rs.getString(1);

                rs = null;
                if( userId > 0 )
                {
                    pss1.setString( 1, ftid );
                    rs = pss1.executeQuery();
                    if( !rs.next() ) rs = null;
                }
                if( rs == null )
                {
                    pss0.setString( 1, ftid );
                    rs = pss0.executeQuery();
                    if( !rs.next() ) rs = null;
                }
                if( rs != null )
                {
                    s.styleId = rs.getString( 1 );
                    s.name = rs.getString( 2 );
                    s.description = rs.getString( 3 );
                }

                rs = null;
                if( userId > 0 )
                {
                    psc1.setString( 1, ftid );
                    rs = psc1.executeQuery();
                    if( !rs.next() ) rs = null;
                }
                if( rs == null )
                {
                    psc0.setString( 1, ftid );
                    rs = psc0.executeQuery();
                    if( !rs.next() ) rs = null;
                }
                if( rs != null )
                {
                    s.color = rs.getString( 1 );
                }
            }

            ps0.close();
            pss0.close();
            psc0.close();
            if( pss1 != null ) pss1.close();
            if( psc1 != null ) psc1.close();

            Arrays.sort( rc );
            return rc;
        } catch( Exception ex )
        {
            db.reportError( ex, "Style.fetchAll()" );
        }
        return new Style[0];
    }


    public static boolean setStyleMap(Connection con , DBAgent db, Style[] styleMap, int userId) throws SQLException {
        boolean success = false; 
         int i;
               PreparedStatement psColorIns = null;
                PreparedStatement psStyleIns = null;
                PreparedStatement psFeatureColorDel = null;
                PreparedStatement psFeatureStyleDel = null;
                PreparedStatement psFeatureColorIns = null;
                PreparedStatement psFeatureStyleIns = null;
                HashMap  htStyle = new HashMap ();
                HashMap htColor = new HashMap ();
        
            String sqlStyle = "SELECT styleId, name FROM style"; 
            String sqlColor = "SELECT colorId, value FROM color";
             String sqlLastId = "SELECT LAST_INSERT_ID()"; 
          try {   
                PreparedStatement  stms = con.prepareStatement(sqlStyle); 
                PreparedStatement  stms1 = con.prepareStatement(sqlColor); 
                PreparedStatement  stms2 = con.prepareStatement( sqlLastId ); 
                psFeatureColorDel = con.prepareStatement("DELETE FROM featuretocolor WHERE userId=? AND ftypeid=?");
                psFeatureStyleDel = con.prepareStatement("DELETE FROM featuretostyle WHERE userId=? AND ftypeid=?");
                psFeatureColorIns = con.prepareStatement("INSERT INTO featuretocolor (userId, ftypeid, colorId) VALUES (?, ?, ?)");
                psFeatureStyleIns = con.prepareStatement("INSERT INTO featuretostyle (userId, ftypeid, styleId) VALUES (?, ?, ?)");
                psStyleIns = con.prepareStatement("INSERT INTO style (name, description) VALUES (?, ?)");
                psColorIns = con.prepareStatement("INSERT INTO color (value) VALUES (?)");
                                                    
                ResultSet rs = stms.executeQuery();
               // pop style hash
                while (rs.next()) {
                    String val = rs.getString(1);
                    String key = rs.getString(2);
                    htStyle.put(key, val);
                }
                
              // pop color hash 
                rs = stms1.executeQuery(sqlColor);
                while (rs.next()) {
                    String val = rs.getString(1);
                    String key = rs.getString(2);
                    htColor.put(key, val);
                }

              
                for (i = 0; i < styleMap.length; i++) {
                        Style st = styleMap[i];   
                        updateFtype (con, st); 
                        String styleId = (String) htStyle.get(st.name);
                        // if new style, update db 
                        if (styleId == null) {                       
                            psStyleIns.setString(1, st.name);
                            psStyleIns.setString(2, st.description);
                            if (psStyleIns.executeUpdate() > 0) {
                                rs = stms2.executeQuery();
                                if (rs.next()) {
                                st.styleId = styleId = rs.getString(1);
                                htStyle.put(st.name, styleId);
                                }
                            }
                        }
                    
                    
                    // delete old 
                    psFeatureStyleDel.setInt(1, userId);
                    psFeatureStyleDel.setInt(2, st.ftypeid);
                    psFeatureStyleDel.executeUpdate();
                    
                    // update new 
                    if (styleId != null) {
                        psFeatureStyleIns.setInt(1, userId);
                        psFeatureStyleIns.setInt(2, st.ftypeid);
                        psFeatureStyleIns.setString(3, styleId);
                        psFeatureStyleIns.executeUpdate();
                    }

                    if (st.color != null)
                        st.color = st.color.toUpperCase();
                    String colorId = (String) htColor.get(st.color);
                  
                   // if new color, update db 
                    if (colorId == null) {
                        psColorIns.setString(1, st.color);
                        if (psColorIns.executeUpdate() > 0) {
                            rs = stms2.executeQuery();
                            if (rs.next()) {
                                st.colorid = rs.getInt(1);
                                colorId = "" + st.colorid;
                                htColor.put(st.color, colorId);
                            }
                        }
                    }

                    // delete old mapping
                    psFeatureColorDel.setInt(1, userId);
                    psFeatureColorDel.setInt(2, st.ftypeid);
                    psFeatureColorDel.executeUpdate();
                    // insert new 
                    if (colorId != null) {
                        psFeatureColorIns.setInt(1, userId);
                        psFeatureColorIns.setInt(2, st.ftypeid);
                        psFeatureColorIns.setString(3, colorId);
                        psFeatureColorIns.executeUpdate();
                    }
              }
              success = true; 
        } catch (Exception ex) {
             ex.printStackTrace();
            db.reportError(ex, "style.setStyleMap");
        }
        return success;
    }

        public static Style  updateFtype (Connection con, Style st) {
            boolean inlocalDb = false; 
            if (st == null) 
            return st;
        try {           
            PreparedStatement stms = con.prepareStatement("select * from ftype where fmethod = ? and fsource = ? ");
            stms.setString (1, st.fmethod); 
            stms.setString(2, st.fsource);
            ResultSet rs = stms.executeQuery();
            // pop style hash
            if  (rs.next()) {
            inlocalDb = true;        
            }
            
            if (!inlocalDb) {
             PreparedStatement    stmsIns = con.prepareStatement("insert into ftype (fmethod, fsource) values (?, ? ) ;");
            stmsIns.setString (1, st.fmethod); 
            stmsIns.setString(2, st.fsource);
            int n = stmsIns.executeUpdate(); 
            
            // pop style hash
            if  (n>0) {
            inlocalDb = true;
            String sqlLastId = "SELECT LAST_INSERT_ID()";
            stms = con.prepareStatement( sqlLastId  );
            
            rs = stms.executeQuery();
            if  (rs.next()) {
            st.ftypeid = rs.getInt(1);   
            }
            }
            stmsIns.close();     
            }
            rs.close();
            stms.close();
         }
        catch (Exception e) {
            e.printStackTrace();        
        }              
        return st; 
        }




}