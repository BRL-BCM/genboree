package org.genboree.svg.image;

import org.genboree.svg.Constants;

import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;
import java.io.IOException;

/**
 * Created By: Alan
 * Date: May 22, 2003 11:17:38 PM
 */
public class ImageServlet extends HttpServlet {
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws IOException {
        doPost(request, response);
    }

    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws IOException {
        serveSpecieSVG(request, response);
    }

    private void serveSpecieSVG(HttpServletRequest request, HttpServletResponse response) throws IOException {
        HttpSession session = request.getSession();
//        String uid = request.getParameter(Constants.HTTP_PARAM_UID);
        String uid = Constants.IMAGE_KEY;
        Image image = null;
        if (uid != null)
            image = (Image) session.getAttribute(uid);
        if (image != null){
            image.serveImage(response, ParametersHelper.createReqirements(request));
            //can not remove the image from the session after serving it because IE will
            //make two requests when display the image and if the second request does not
            //return the image data, it will not display the svg.
//            session.removeAttribute(uid);
        }
    }
}
