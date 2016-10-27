package org.genboree.svg.image;

import org.genboree.svg.Constants;

import java.util.HashMap;

/**
 * Created By: Alan
 * Date: May 22, 2003 11:24:42 PM
 */
public class UID implements Constants{

    public static String generateUID(HashMap requirements){
        StringBuffer sb = new StringBuffer();
        sb.append(requirements.get(HTTP_PARAM_SPECIEID)).
                append(requirements.get(HTTP_PARAM_SVGTYPE)).
                append(requirements.get(HTTP_PARAM_CHROMOSOME)).
                append(requirements.get(HTTP_PARAM_FORMAT_GIF)).
                append(System.currentTimeMillis());
        return sb.toString();
    }
}
