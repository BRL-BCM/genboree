package org.genboree.svg.image;

import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.io.OutputStream;
import java.util.HashMap;

/**
 * Created By: Alan
 * Date: May 22, 2003 9:51:32 PM
 */
public interface Image {

    public void serveImage(HttpServletResponse response, HashMap options) throws IOException;

    public void serveImage(OutputStream outstream, HashMap options) throws IOException;
}
