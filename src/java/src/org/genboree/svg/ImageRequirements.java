package org.genboree.svg;

import org.genboree.util.XmlConfig;

import java.util.HashMap;

/**
 * A ImageRequirements object contains critical information on how the SVG image should be
 * rendered, such as margins, positions, etc. The application gets the ImageRequirement object
 * by query the ImageRequirementFactory class with the interested image type.
 *
 * Created By: Alan
 * Date: Apr 12, 2003 3:11:00 PM
 */
abstract public class ImageRequirements {

    protected HashMap userOptions = null;
    protected XmlConfig config = null;

    /**
     * The width of the SVG image.
     * @return
     */
    abstract public int getImageWidth();

    /**
     * The height of the SVG image.
     * @return
     */
    abstract public int getImageHeight();

    protected String getUserOptionString(String key) {
        return getUserOption(key);
    }

    protected int getUserOptionInt(String key) {
        return Integer.parseInt(getUserOption(key)); //the returned value won't be null;
    }

    protected double getUserOptionDouble(String key) {
        return Double.parseDouble(getUserOption(key)); //the returned value won't be null
    }

    protected boolean getUserOptionBoolean(String key) {
        String value = getUserOption(key);
        return "true".equalsIgnoreCase(value) || "yes".equalsIgnoreCase(value);
    }

    private String getUserOption(String key) {
        if (userOptions == null)
            return getDefaultUserOption(key);
        String value = (String) userOptions.get(key);
        return value == null ? getDefaultUserOption(key) : value;
    }

    private String getDefaultUserOption(String key) {
        return config.lookupConfigElement(key).getConfigValue();
    }


}
