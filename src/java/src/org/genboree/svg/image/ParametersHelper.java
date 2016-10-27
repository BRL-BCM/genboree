package org.genboree.svg.image;

import org.genboree.svg.Constants;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpSession;
import java.util.HashMap;

/**
 * Created By: Alan
 * Date: May 22, 2003 10:31:08 PM
 */
public class ParametersHelper implements Constants {

    /**
     * All parameters are retrieved from the request object first, then the session object. If the
     * value is found from the requrest object, it is used to update the session value.
     * @param request
     * @param session
     * @param key
     * @return
     */
    private static String getParam(HttpServletRequest request, HttpSession session, String key) {
        String value = request.getParameter(key);
        if (value == null || "".equals(value)) {
            value = (String) session.getAttribute(key);
        } else {
            session.setAttribute(key, value);
        }
        return "".equals(value) ? null : value;
    }

    private static void addParam(HashMap requirements, HttpServletRequest request, HttpSession session, String key) {
        requirements.put(key, getParam(request, session, key));
    }

    public static HashMap createReqirements(HttpServletRequest request) {
        HttpSession session = request.getSession();
        HashMap requirements = new HashMap();

        //the specieId parameter
        addParam(requirements, request, session, HTTP_PARAM_SPECIEID);

        //the debug parameter
        addParam(requirements, request, session, "debug");

        //the gif parameter: gif == true/false, if missing, check the HTTP_PARAM_SVG_CAPABLE attribute
        //in the session object to auto determine if a gif image should be generated.
        String gifOption = getParam(request, session, HTTP_PARAM_FORMAT_GIF);
        if (gifOption == null) {
            gifOption = "true".equalsIgnoreCase((String) session.getAttribute(HTTP_PARAM_SVG_CAPABLE))
                    ? "false" : "true";
            session.setAttribute(HTTP_PARAM_FORMAT_GIF, gifOption);
        }
        requirements.put(HTTP_PARAM_FORMAT_GIF, gifOption);

        //the svgType parameter: compact, full
        addParam(requirements, request, session, HTTP_PARAM_SVGTYPE);

        //the chromosome parameter: with "full" svgType, determine if only one chromosome is drawn.
        session.removeAttribute(HTTP_PARAM_CHROMOSOME);
        addParam(requirements, request, session, HTTP_PARAM_CHROMOSOME);

        return requirements;
    }

    public static HashMap getUserOptions(HttpSession session, HashMap requirements) {
        String type = (String) requirements.get(HTTP_PARAM_SVGTYPE);
        if (TYPE_COMPACT.equalsIgnoreCase(type)) {
            return (HashMap) session.getAttribute(HTTP_USEROPTION_COMPACT);
        } else {
            return (HashMap) session.getAttribute(HTTP_USEROPTION_FULL);
        }
    }
}
