package org.genboree.svg.image;

import org.apache.batik.transcoder.TranscoderInput;
import org.apache.batik.transcoder.TranscoderOutput;
import org.genboree.svg.GIFTranscoder;
import org.genboree.svg.imagemap.SVGLinkTree;
import org.genboree.svg.imagemap.ImageMapCreator;
import org.genboree.svg.Constants;
import javax.servlet.ServletOutputStream;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpServletResponseWrapper;
import java.awt.*;
import java.io.*;
import java.util.HashMap;
import java.lang.Integer;

/**
 * Created By: Alan
 * Date: May 22, 2003 9:54:10 PM
 */
public class GIFImage implements Image, Constants {
    private static int DPI = 72;

    private SVGImage svgImage = null;

    public GIFImage(SVGImage svgImage) {
        this.svgImage = svgImage;
    }

    public String getImageMap(String mapName){
        SVGLinkTree tree = svgImage.getSVGLinkTree();
        ImageMapCreator imap = new ImageMapCreator();
        imap.setSvgLinkTree(tree);
        StringBuffer sb = new StringBuffer("<map name=\"").append(mapName).append("\">\n");
        sb.append(imap.getMapAreas());
        sb.append("</map>");
        return sb.toString();
    }

    public void serveImage(final HttpServletResponse response, HashMap options) throws IOException {

        final StringWriter sw = new StringWriter();
        final PrintWriter pw = new PrintWriter(sw);
        HttpServletResponse wrappedResp = new HttpServletResponseWrapper(response) {
            public PrintWriter getWriter() {
                return pw;
            }

            public ServletOutputStream getOutputStream() {
                return null;
            }

            public void setContentType(String type) {
                if (type.equals("image/svg+xml"))
                    response.setContentType("image/gif");
                else
                    response.setContentType(type);
            }
        };

        svgImage.serveImage(wrappedResp, options);
        StringReader sr = new StringReader(sw.toString());
        ByteArrayOutputStream baos = new ByteArrayOutputStream();

        serve(sr, baos);
        sr.close();

        //must set the content length, or the output maybe truncated!
        response.setContentLength(baos.size());
        response.getOutputStream().write(baos.toByteArray());

        //debug: output the image into a disk file as well
//        FileOutputStream fout = new FileOutputStream("m:\\genome.gif");
//        fout.write(baos.toByteArray());
//        fout.close();

        return;
    }

public void serveImage(OutputStream outstream, HashMap options) throws IOException 
{
/* Added by Manuel to get the resolution */
	Integer thevalue = (Integer)options.get(HTTP_PARAM_NEWRESOLUTION);
	if(thevalue.intValue() > 72)
		DPI = thevalue.intValue();

/*This part could be replaced by Andrei code */
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        svgImage.serveImage(baos, options);
        StringReader sr = new StringReader(baos.toString());

        serve(sr, outstream);
        return;
    }

    private void serve(StringReader sr, OutputStream outstream){
        //pass the generated svg contents to the gif converter
        //only allow one instance of the gif transcoder so we can save some resouce.
        synchronized (GIFTranscoder.lock) {
            GIFTranscoder gif = GIFTranscoder.getInstance();
            gif.addTranscodingHint(gif.KEY_BACKGROUND_COLOR, new Color(255, 255, 255, 255));
            gif.addTranscodingHint(gif.KEY_PIXEL_UNIT_TO_MILLIMETER, new Float((2.54f / DPI) * 10));
	    float factor = (float) DPI / 72;
            gif.addTranscodingHint(gif.KEY_WIDTH, new Float(svgImage.getImageWidth() * factor));
            gif.addTranscodingHint(gif.KEY_HEIGHT, new Float(svgImage.getImageHeight() * factor));
            TranscoderInput ti = new TranscoderInput(sr);
            TranscoderOutput to = new TranscoderOutput(outstream);
            try {
                gif.transcode(ti, to);
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
    }
}




/*Added by Andrei to use a file to generate the image 
System.out.println("Inside the serveImage method second " + DPI);
	File faos = File.createTempFile( "xxx", ".xxx" );
	faos.deleteOnExit();
	FileOutputStream fout = new FileOutputStream( faos );

//        ByteArrayOutputStream baos = new ByteArrayOutputStream();
System.out.println("Before the svgImage.serveImage");
System.out.flush();
        svgImage.serveImage(fout, options);
System.out.println("After the svgImage.serveImage");
System.out.flush();
//        String sBaos = baos.toString();
//	StringReader sr = new StringReader(sBaos);
// System.out.println( "baos.length="+sBaos.length() );	
	fout.close();
	FileReader fin = new FileReader( faos );
System.gc();
        serve(fin, outstream);
	fin.close();
        return;
    }

    private void serve(Reader sr, OutputStream outstream){
*/

