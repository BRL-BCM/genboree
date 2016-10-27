package org.genboree.util;

import java.io.*;
import java.util.*;
import java.awt.*;
import java.awt.image.*;

import javax.swing.*;

public class ProgressIndicator
{
    protected int width = 400;
    public int getWidth() { return width; }
    public void setWidth( int width ) { this.width = width; }
    protected int height = 40;
    public int getHeight() { return height; }
    public void setHeight( int height ) { this.height = height; }
    protected boolean ruler = true;
    public boolean getRuler() { return ruler; }
    public void setRuler( boolean ruler ) { this.ruler = ruler; }
    protected Color bkColor = Color.white;
    public Color getBackground() { return bkColor; }
    public void setBackground( Color bkg ) { bkColor = bkg; }
    protected Color fgColor = Color.black;
    public Color getForeground() { return fgColor; }
    public void setForeground( Color fgd ) { fgColor = fgd; }
    protected Color invColor = Color.white;
    public Color getInverseForeground() { return invColor; }
    public void setInverseForeground( Color ifgd ) { invColor = ifgd; }
    protected Color brightColor = new Color(0x66,0x60,0xAA);
    public Color getBright() { return brightColor; }
    public void setBright( Color br ) { brightColor = br; }
    protected Color darkColor = new Color(0,0,0x66);
    public Color getDark() { return darkColor; }
    public void setDark( Color dk ) { darkColor = dk; }
    protected Color shdColor = new Color(0xDD,0xDD,0xFF);
    public Color getShadow() { return shdColor; }
    public void setShadow( Color shd ) { shdColor = shd; }
    protected Font percFont = new Font( "dialoginput", Font.BOLD, 16 );
    public Font getPercentageFont() { return percFont; }
    public void setPercentageFont( Font f ) { percFont = f; }
    protected Font font = new Font( "dialog", Font.BOLD, 12 );
    public Font getFont() { return font; }
    public void setFont( Font f ) { font = f; }

    public ProgressIndicator()
    {
    }

    protected static final String p0 = "0%";
    protected static final String p50 = "50";
    protected static final String p100 = "100";

    protected void drawRuler( Graphics2D g, int h )
    {
        int w = getWidth();
        g.setColor( getBackground() );
        g.fillRect( 0, 0, w, h );
        g.setColor( getForeground() );
        for( int i=0; i<=1000; i+=100 )
        {
            int x = (i * w)/1001;
            int l = h / 8;
            if( (i%500) == 0 ) l = h / 4;
            g.drawLine( x, h, x, h - l );
        }

        Font f = getFont();
        g.setFont( f );
        FontMetrics fm = g.getFontMetrics();
        int th = fm.getHeight();
        int y0 = (h - th) / 2 + fm.getAscent() - 1;
        g.drawString( p0, 1, y0 );
        int tw = fm.stringWidth( p50 );
        g.drawString( p50, (w - tw)/2, y0 );
        tw = fm.stringWidth( p100 );
        g.drawString( p100, w - tw - 1, y0 );
    }

    protected void drawSlider( Graphics2D g, int p10, int y0 )
    {
        int w = getWidth();
        int h = getHeight() - y0;
        int x1 = (p10 * w) / 1000;

        GradientPaint gp = new GradientPaint(
            (float)(0), (float)(y0 + h/3), getBright(),
            (float)(0), (float)(y0 - h/3), getDark(), true );
        g.setPaint( gp );
        g.fillRect( 0, y0, x1-1, h );

        g.setColor( getShadow() );
        g.fillRect( x1, y0, w-x1, h );

        g.setColor( getForeground() );
        g.drawRect( 0, y0, w-1, h-1 );

        String pa = ""+(p10/10)+"."+(p10%10)+"%";
        Font f = getPercentageFont();
        g.setFont( f );
        FontMetrics fm = g.getFontMetrics();
        int th = fm.getHeight();
        int ty0 = y0 + (h + th)/2 - fm.getDescent();;
        int tw = fm.stringWidth( pa );
        int tx0 = (w - tw) / 2;

        g.setClip( 0, y0, x1, h );
        g.setColor( getBackground() );
        g.drawString( pa, tx0, ty0 );

        g.setClip( x1, y0, w-x1, h );
        g.setColor( getForeground() );
        g.drawString( pa, tx0, ty0 );
    }

    /**
     * @param perc10 Percent*10; 0 for 0%, 1000 for 100%, 548 for 54.8% etc.
     */
    public BufferedImage createImage( int perc10 )
    {
        BufferedImage rc = new BufferedImage( getWidth(), getHeight(),
            BufferedImage.TYPE_BYTE_INDEXED );
        Graphics2D g = rc.createGraphics();
        int sliderh = getHeight();
        int slidery = 0;
        int rulerh = 0;
        if( getRuler() )
        {
            rulerh = getHeight()/2;
            sliderh -= rulerh;
            slidery = rulerh;
            drawRuler( g, rulerh );
        }
        drawSlider( g, perc10, rulerh );
        return rc;
    }

/*
    public static void main( String[] args )
    {
        ProgressIndicator pi = new ProgressIndicator();
        JFrame jfr = new JFrame( "Test Progress Indicator" );
        ImageIcon ico = new ImageIcon( pi.createImage(0) );
        JLabel jl = new JLabel( ico );
        jfr.getContentPane().add( jl );
        jfr.pack();
        jfr.setVisible( true );

        for( int i=0; i<=1000; i+=50 )
        {
            ico.setImage( pi.createImage(i) );
            jl.repaint();
            try{ Thread.sleep(500); } catch( Throwable thr ) {}
            if( !jfr.isVisible() ) break;
        }

        while( jfr.isVisible() )
        try{ Thread.sleep(200); } catch( Throwable thr1 ) {}

        System.exit(0);
    }
*/
}
