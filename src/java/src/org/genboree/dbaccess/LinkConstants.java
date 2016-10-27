package org.genboree.dbaccess;

/**
 * User: tong Date: Jul 27, 2005 Time: 10:10:37 AM
 */
public class LinkConstants {

    public static final String[] modeIds =
            {
                "classCreate", "classUpdate", "classDelete", "classAssign", "classHelp", "classDefault"
            };

    public static final String[] modeLabs =
            {
                "Create", "Update", "Delete", "Assign", "Help"
            };

    public static final int MODE_DEFAULT = 15;
    public static final int MODE_CREATE = 10;
    public static final int MODE_UPDATE = 11;
    public static final int MODE_DELETE = 12;
    public static final int MODE_ASSIGN = 13;
    public static final int MODE_HELP = 14;

    public static final String[] btnCreate = {"submit", "btnCreate", " Create ", null};
    public static final String[] btnApply = {"submit", "btnApply", " Save ", null};
    public static final String[] btnDelete = {"submit", "btnDelete", " Delete ", null};
    public static final String[] btnAssign = {"submit", "btnAssign", " Assign ", null};
    public static final String[] btnClear = {"button", "btnClear", "Help", "clearAll();"};

}
