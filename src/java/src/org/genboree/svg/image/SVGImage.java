package org.genboree.svg.image;

import org.genboree.svg.Constants;
import org.genboree.svg.imagemap.SVGLinkTree;

import javax.servlet.http.HttpServletResponse;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.io.FileOutputStream;
import java.util.HashMap;
import java.util.zip.GZIPOutputStream;

/**
 * Created By: Alan
 * Date: May 22, 2003 9:53:17 PM
 */
public class SVGImage implements Image, Constants {

    private String svg = null;
    private SVGLinkTree tree = null;
    private int imageWidth = 0;
    private int  imageHeight = 0;

    public SVGImage(String svg, SVGLinkTree tree) {
        this.svg = svg;
        this.tree = tree;
    }

    public SVGLinkTree getSVGLinkTree(){
        return tree;
    }

    public void serveImage(HttpServletResponse response, HashMap options) throws IOException {
        boolean compress = "svgz".equalsIgnoreCase((String) options.get("format"));
        response.setContentType("image/svg+xml");
        if (compress) {
            ByteArrayOutputStream bout = new ByteArrayOutputStream();
            GZIPOutputStream gzout = new GZIPOutputStream(bout);
            gzout.write(svg.getBytes());
            gzout.flush();
            gzout.close();
            bout.close();

            response.setContentLength(bout.size());
            bout.writeTo(response.getOutputStream());
            response.getOutputStream().flush();
        } else {
            response.setContentLength(svg.length());
            response.getWriter().write(svg);
        }

        //debug: output the image into a disk file as well
//        FileOutputStream fout = new FileOutputStream("m:\\genome.svg");
//        serveImage(fout, options);
//        fout.close();

    }

    public void serveImage(OutputStream outstream, HashMap options) throws IOException {
        boolean compress = "svgz".equalsIgnoreCase((String) options.get("format"));
        if (compress) {
            ByteArrayOutputStream bout = new ByteArrayOutputStream();
            GZIPOutputStream gzout = new GZIPOutputStream(bout);
            gzout.write(svg.getBytes());
            gzout.flush();
            gzout.close();
            bout.close();

            bout.writeTo(outstream);
            outstream.flush();
        } else {
            outstream.write(svg.getBytes());
        }
    }

    public void setImageWidth(int imageWidth) {
        this.imageWidth = imageWidth;
    }

    public void setImageHeight(int imageHeight) {
        this.imageHeight = imageHeight;
    }

    public int getImageWidth() {
        return imageWidth;
    }

    public int getImageHeight() {
        return imageHeight;
    }
}
