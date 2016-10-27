
Extjs MINIMUM JavaScript AND MINIFIED CODE PACKAGES
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The files here contain Javascript code in minified format (no extra spaces or
newlines, etc) that support a very *specific* functionality.

By using a minimum set of Extjs code, page rendering and file download times are
both increased significantly.

Do NOT use 'ext-all.js' on production machine(s)!!! You can use it to develop,
and then use the packaging tool to get what only what you need.

Build an appropriate package instead and refer to that in an appropriate
<script> tag on your html/jsp/rhtml page instead (after appropriate Prototype &
Scriptaculous and the extjs adapter of course).

A) BUILDING PACKAGES
^^^^^^^^^^^^^^^^^^^^

To build a package that contains ONLY what you need:

1) Go to:
  http://extjs.com/download/build

2) Choose "Prototype/Scriptaculous" radio button. Genboree uses these.
Hit Next.

3) Select ONLY those components you need. Watch carefully for dependencies.
   Start with TOO FEW compoents. Then rebuild the package with an extra needed
   component until Firebug tells you that you have no errors when using your
   page's widget(s).

   - "Ext Core" is required.
   - "Core - Utilities" is almost always needed.
   - "Core - Layers" is almost always needed.
   - If you choose "QuickTips", you probably want "Core - Drag and Drop" (but
     without the Overflow Scrolling Support unless you know you need it)

4) *Document* your package below!!
  Describe what went into it so others can use it too.

B) PACKAGE CONTENTS
^^^^^^^^^^^^^^^^^^^

1)  PACKAGE: ext-menuBtn-only-pkg.js
    DESCRIPTION:  Support for simple drop-menu buttons. With tool tips that can
                  be dragged and closed.
    COMPONENT LIST:
      Ext Core
      Core - Utilities
      Core - Drag and Drop
      QuickTips - Tooltip Widget
      Button Widget
        . Button Quicktips optional feature selected also
      Menu Widget



2)  PACKAGE: ext-msgbox-only-pkg.js
    DESCRIPTION:  Support for Ext.Message functions
    COMPONENT LIST:
      Ext Core
      Core - Utilities
      Core - Drag and Drop
      core-layers
      diaglog - basic
      dialog - messagebox
      Button Widget

3) PACKAGE: ext-projectManagement-only-pkg.js
   DESCRIPTION: Support for htmlEditor, confirm dialogs, masks, borderlayoutdialogs, etc of the project pages
   COMPONENT LIST:
      Ext Core
      Core - Utilities
      Core - Date Parsing and Formatting
      Core - Layers
      Core - State Management
      Resizable
      QuickTips - Tooltip Widget
        Button QuickTips
      Button Widget
      Tabs Widget
      SplitBar Widget
      Menu Widget
      Loading Mask Widget
      Date Picker Popup (DateMenu)
      Color Picker Popup (ColorMenu)
      Border Layout Widget
      Toolbar Widget
      Dialog - Basic Widget
        Dialog Resize Support
      Dialog - MessageBox
      Data - Core
      Data - JSON Support
      Form - Basic Fields
      Form - ComboBox Widget
      Form - Date Field
      Form - HtmlEditor
      Form - Dynamic Rendering




