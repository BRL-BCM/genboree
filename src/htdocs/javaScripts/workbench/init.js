/** ------------------------------------------------------------------
 * Code For Starting Up the Page Once All the Components are Defined, etc.
 */
Ext.onReady( function()
{
  setTimeout( function() { init() }, 50 ) ;
}) ;

function init()
{
  if(Workbench.allLoaded())
  {
    // Render all Ext widgets
    Workbench.mainTree.render() ;
    Workbench.inputsTree.render() ;
    Workbench.outputsTree.render() ;

    // Now that the trees are the correct size, set the padding
    Workbench.inputsTree.dropZone.setPadding(0, 0, Workbench.inputsTree.getInnerHeight(), 0);
    Workbench.outputsTree.dropZone.setPadding(0, 0, Workbench.outputsTree.getInnerHeight(), 0);

    // To ensure the inner structure is the right size (currently it renders
    // with a small gap on the right of the Panel.  We are making an educated
    // guess as to how long it will take before that first render is finished
    // and then forcing a second render with the GridView.refresh()
    //setTimeout( function() { Ext.ComponentMgr.get("detailsGrid").getView().refresh() ; }, 100 ) ;
    Ext.ComponentMgr.get("wbDetailsGrid").getView().refresh() ;
    
    Ext.Msg.minWidth = 600; /* Required for Chrome compat */

  }
  else
  {
    setTimeout( function() { init() }, 50) ;
  }
}