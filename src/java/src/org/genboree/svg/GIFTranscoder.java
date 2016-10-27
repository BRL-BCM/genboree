package org.genboree.svg;

import org.apache.batik.transcoder.image.ImageTranscoder;
import org.apache.batik.transcoder.TranscoderOutput;
import org.apache.batik.transcoder.TranscoderException;
import org.apache.batik.transcoder.TranscoderInput;
import org.genboree.svg.GIFEncoder;
import java.awt.image.BufferedImage;
import java.awt.*;
import java.io.*;


/**
 * Created By: Alan
 * Date: May 14, 2003 9:30:27 PM
 *
 * Modified by: Andrei
 * Date: 10/14/2003 12:30PM
 */
public class GIFTranscoder extends ImageTranscoder
{
    public static Object lock = new Object();

    public GIFTranscoder() {};

    public static GIFTranscoder getInstance() { return new GIFTranscoder(); }

    public BufferedImage createImage(int width, int height) {
        return new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB);
        //return new BufferedImage(width, height, BufferedImage.TYPE_BYTE_INDEXED, SyntenyColorMap.getColorModel() );
    }

    public void writeImage(BufferedImage img, TranscoderOutput output)
        throws TranscoderException
    {
        GIFEncoder enc = new GIFEncoder(output.getOutputStream());
        try {
            enc.encode(img);
        } catch (IOException e) {
            e.printStackTrace();
        }

    }

/*
    public static void main(String[] args) throws Exception{
        GIFTranscoder gif = new GIFTranscoder();
        gif.addTranscodingHint(KEY_BACKGROUND_COLOR, new Color(255,255,255,255));
        gif.addTranscodingHint(KEY_PIXEL_UNIT_TO_MILLIMETER, new Float((2.54f / 360) * 10));
        gif.setImageSize(2500, 938);


        File f = new File("genome.svg");
        FileReader fr = new FileReader(f);
        char[] buffer = new char[1024];
        int count = 0;
        StringBuffer sb = new StringBuffer();
        while( (count = fr.read(buffer)) >= 0){
            sb.append(buffer, 0, count);
        }
        fr.close();
        StringReader sr = new StringReader(sb.toString());
//        TranscoderInput ti = new TranscoderInput(f.toURL().toString());
        TranscoderInput ti = new TranscoderInput(sr);
        FileOutputStream fos = new FileOutputStream("genome.gif");
        TranscoderOutput to = new TranscoderOutput(fos);
        gif.transcode(ti, to);
        fos.close();
    }
*/
}
