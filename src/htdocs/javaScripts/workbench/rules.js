/**
  * Functions specific to dealing with Workbench rules.
  * - these rules are used primarily to determine what should happen
  *   to any tool buttons when users do a drag-n-drop.
  *
  * Requires ExtJs 2.2 and Prototype 1.6.
*/
/**
 * ASSUMES 'wbHash', 'wbToolSatisfactionHash' global variables from workbench.js are available.
 * Functions will work closely with the contents of those Hashes.
 */

/**
 * Toggles appearance of tool buttons according to whether they are or are
 * not satisfied by the current inputs and outputs selections.
 */
function toggleToolsByRules()
{
  // Update the global map of toolIdStr -> toolRulesSatisfied boolean
  wbToolSatisfactionHash = toolsSatisfiedInfo(true) ;
  // Examine each toolIdStr (keys of wbToolSatisfactionHash) and update
  // its button accordingly.
  
  if(Workbench && Workbench.toolbar && Workbench.toolbar.items)
  { 
    updateToolButtonBySatisfaction(Workbench.toolbar.items) ;
    // the enableOverflow config for Ext.Toolbar creates an item-like button called "more"
    // that needs to be specially dealt with
    toolbarLayoutListener(Workbench.toolbar) ;
    Workbench.toolbar.removeListener('afterlayout', toolbarLayoutListener) ;
    Workbench.toolbar.addListener('afterlayout', toolbarLayoutListener) ;
  }
  return ;
}

// listener to register when the layout is changed (menu is resized, etc.)
// when layout changes we may replace our "more" button with a new one
// so be sure to update that new one
function toolbarLayoutListener(toolbar)
{
  if(toolbar && toolbar.layout && toolbar.layout.lastOverflow)
  {
    var collectionForMore = new Ext.util.MixedCollection() ;
    var more = updateMoreMenu(toolbar) ;
    if(more)
    {
      collectionForMore.add(more) ;
      updateToolButtonBySatisfaction(collectionForMore) ;
    }
  }
}

// define a special tool toggle listener for the more menu
// this is necessary because a new menu is generated every time the more menu arrows are clicked
function moreMenuListener(moreMenuCmp)
{
  updateToolMenuBySatisfaction(moreMenuCmp) ;
  return ;
} ;

// ensure the moreMenu exists, add it as an item to the Ext.Toolbar.items, and
// register listeners so that items in the moreMenu satisfying the rules are
// highlighted in green
function updateMoreMenu(toolbar)
{
  if(toolbar.layout.lastOverflow)
  {
    var moreMenuCmp = toolbar.layout.moreMenu ;
    if(!toolbar.layout.moreMenu.items)
    {
      // then the menu items have not been generated yet, artificially fire a beforeshow event to generate them
      moreMenuCmp.fireEvent('beforeshow', moreMenuCmp) ;
    }
  
    // register listeners
    moreMenuCmp.removeListener('show', moreMenuListener) ;
    moreMenuCmp.addListener('show', moreMenuListener) ;
  
    if(!toolbar.layout.more.toolIds)
    {
     // attach the toolIds for the more button so that we can use updateToolMenuBySatisfaction
      var moreToolIds = new Array() ;
      for(var ii=0; ii<toolbar.layout.more.menu.items.getCount(); ii++)
      {
        var currentMoreMenuButton = toolbar.layout.more.menu.items.itemAt(ii) ;
        moreToolIds = moreToolIds.concat(currentMoreMenuButton.toolIds) ;
      }
      toolbar.layout.more.toolIds = moreToolIds ;
    } 
  }
  
  return toolbar.layout.more;
}

function removeGenboreeClasses(button)
{
  button.removeClass('wbBtnReady') ;
  return ;
}

function updateToolButtonBySatisfaction(items)
{
  if(items)
  {
    // Examine each toolbar button
    var toolbarItemCount = items.getCount() ;
    for(var ii=0; ii<toolbarItemCount; ii++)
    {
      var toolBarButton = items.itemAt(ii) ;
      // Check each toolId for this button. If found one to be highlighted, then highlight this button.
      if(anyToolIdsSatisfied(toolBarButton.toolIds))
      {
        toolBarButton.removeClass('wbToolbarBtn') ;
        toolBarButton.addClass('wbBtnReady') ;
      }
      else
      {
        toolBarButton.removeClass('wbBtnReady') ;
        toolBarButton.addClass('wbToolbarBtn') ;
      }

      // Now recusively visit the menu system under this button.
      var menu = toolBarButton.menu ;
      if(menu)
      {
        updateToolMenuBySatisfaction(menu) ;
      }
    }
  }
  return ;
}

function updateToolMenuBySatisfaction(menuObj)
{
  if(menuObj && menuObj.items && !Ext.isEmpty(menuObj.items))
  {
    // Check each item of this menu (menuObj.items is a MixedCollection instance!)
    var menuItemCount = menuObj.items.getCount() ;
    for(var ii=0; ii<menuItemCount; ii++)
    {
      var menuItem = menuObj.items.itemAt(ii) ;
      if(menuItem.toolIds) // then menuItem is a submenu; check toolIds and recurse into the submenu items
      {
        if(anyToolIdsSatisfied(menuItem.toolIds))
        {
          menuItem.addClass('wbToolReady_menuItem') ;
        }
        else
        {
          menuItem.removeClass('wbToolReady_menuItem') ;
        }
        // Recurse into the items of this submenu
        updateToolMenuBySatisfaction(menuItem.menu) ;
      }
      else // not a submenu; actual tool menu item, is the tool indicated by its id satisfied?
      {
        if(wbToolSatisfactionHash.get(menuItem.id))
        {
          menuItem.addClass('wbToolReady_menuItem') ;
          toolActivated.set(menuItem.id, true) ;
          var helpWindowToolSettingBtn = Ext.ComponentMgr.get(menuItem.id + '_toolSettingsBtn') ;
          if(helpWindowToolSettingBtn)
          {
            helpWindowToolSettingBtn.addClass('wbHelpWindowBtnReady') ;
            helpWindowToolSettingBtn.removeClass('wbHelpWindowBtn') ;
            helpWindowToolSettingBtn.addClass('x-btn-text-icon') ;
            helpWindowToolSettingBtn.enable() ;
            helpWindowToolSettingBtn.setTooltip('This button is now enabled. Clicking it will bring up the settings/configuration dialog.') ;
            helpWindowToolSettingBtn.setIcon('/images/silk/accept.png') ;
            helpWindowToolSettingBtn.show() ;
          }
        }
        else
        {
          menuItem.removeClass('wbToolReady_menuItem') ;
          toolActivated.set(menuItem.id, false) ;
          var helpWindowToolSettingBtn = Ext.ComponentMgr.get(menuItem.id + '_toolSettingsBtn') ;
          if(helpWindowToolSettingBtn)
          {
            helpWindowToolSettingBtn.removeClass('wbHelpWindowBtnReady') ;
            helpWindowToolSettingBtn.addClass('wbHelpWindowBtn') ;
            helpWindowToolSettingBtn.removeClass('x-btn-text-icon') ;
            helpWindowToolSettingBtn.setIcon('') ;
            helpWindowToolSettingBtn.disable() ;
            helpWindowToolSettingBtn.setTooltip('This button is currently disabled. Upon activation of the tool, this button will turn green and a checkmark will appear.') ;
          }
        }
      }
    }
  }
  return ;
}

function anyToolIdsSatisfied(toolIds)
{
  var retVal = false ;
  if(toolIds)
  {
    for(var ii=0; ii<toolIds.length; ii++)
    {
      if(wbToolSatisfactionHash.get(toolIds[ii])) // then at least one tool under here is satisfied
      {
        retVal = true ;
        break ;
      }
    }
  }
  return retVal ;
}


/**
 * Examine current contents of wbHash in context of the wbRulesHash
 * and compile Hash of tool->true|false where true means the inputs/outputs
 * satisfy the tool's rules and false means they don't.
 * - wbRulesHash for matching Arrays (inputs, outputs) is structured as a Hash of Hash to Array of Arrays:
 *     'toolIdStr'->'inputs'|'outputs'->rulesArray of [ regexpStr, minCount, maxCount ]
 * - ruleshash for matching Hashes (context, settings) is sturctures as a Hash of Hash to Hash of Strings:
 *     'toolIdStr'->'context'|'settings'->wbRulesHash of 'field' -> regexpStr
 *
 * NOTE NOTE: there is an analogous RUBY version of this function in
 * brl/genboree/tools/workbenchRulesHelper.rb called rulesSatisfied?(). Fixes
 * here and there should be kept in sync as appropriate when bugs or speedups are addressed.
 *
 * Returns a hash of 'toolIdStr' -> boolean
 */
function toolsSatisfiedInfo(checkToolMenuItemNotHidden)
{
  // Will return Hash of 'toolIdStr' -> boolean (true if tool's rules satisfied, false if not)
  var toolInfo = new Hash() ;
  // Examine the rules set for each section.
  wbRulesHash.each( function(wbRulesHashRec)
  {
    var toolIdStr = wbRulesHashRec.key ;
    var toolEnabled = true ;
    // If tool is hidden or disabled, automatically no rules can be satisfied.
    if(checkToolMenuItemNotHidden)
    {
      var toolMenuItem = Ext.getCmp(toolIdStr) ;
      if( toolMenuItem && (toolMenuItem.hidden || toolMenuItem.disabled))
      {
        toolEnabled = false ;
      }
    }

    // Check tools' rules as appropriate
    var toolRulesSatisfied = false ;
    if(toolEnabled)
    {
      var toolRules = wbRulesHashRec.value ;
      // Visit each section in the rule set and see if it's satisfied
      toolRules.each( function(rulesetRec)
      {
        // Current section being evaluated:
        var sectionSatisfied = false ;
        var section = rulesetRec.key ;
        var sectionRules = rulesetRec.value ;
        // Workbench JSON contents for that section:
        var wbSectionContents = wbHash.get(section) ;
        // Evaluate "inputs" and "outputs" sections differently than "context" and "settings"
        if(section == "inputs" || section == "outputs")
        {
          // Do we satisfy overall item count in this section?
          var minItemCount = sectionRules.get("minItemCount") ;
          var maxItemCount = sectionRules.get("maxItemCount") ;
          if(wbSectionContents.length < minItemCount || (maxItemCount != null && wbSectionContents.length > maxItemCount)) // NO, not right number of items
          {
            sectionSatisfied = false ;
          }
          else // YES, have right number of items...
          {
            // BUT:
            // a. are they acceptable KINDS of items?
            // b. is every item covered by one of the rules?
            // c. is every rule satified?

            // The item rules:
            var rulesArray = sectionRules.get("ruleSet") ;
            // If no rules, then this section is satisfied (enforcing empty is done already via minItemCount, maxItemCount)
            // else, section not satisfied unless all rules satisfied
            if(rulesArray.length <= 0)
            {
              sectionSatisfied = true ;
            }
            else
            {
              sectionSatisfied = false ;
              // Create array of same size as contents, but with booleans indicating
              // if the item at that index has already been matched by a rule yet or not.
              var wbContentsMatched = wbSectionContents.map( function(xx) { return false; } ) ;
              // Loop over each rule record in the "ruleSet" array and try to match it against
              // as-yet UNMATCHED items in the wbSectionContents.
              // (Could Array#each() but it's slower than using the regular for-loop approach)
              for(var ii=0; ii<rulesArray.length; ii++)
              {
                var ruleRecSatisfied = false ;
                var ruleRec = rulesArray[ii] ;
                // Get the regexp that the item would need to match:
                var ruleRE = ruleRec[0] ;
                // Get the min and max counts for this rule... need to satisfy these by the end of examining each item in wbSectionContents
                var minCount = ruleRec[1] ;
                var maxCount = ruleRec[2] ;
                // Examine each as-yet UNMATCHED item in wbSectionContents and see if the current rule matches it.
                var itemsMatchingCount = 0 ;
                for(var jj=0; jj<wbSectionContents.length; jj++)
                {
                  if(!wbContentsMatched[jj]) // only looking at as-yet unmached items
                  {
                    // Get the actual item to examine
                    var wbSectionItem = wbSectionContents[jj] ;
                    // If it matches the current rule, mark it as matched (so it's skipped when evaluating subsequent rule records)
                    // and increment the count of items matching this rule.
                    if(wbSectionItem.match(ruleRE))
                    {
                      wbContentsMatched[jj] = true ;
                      itemsMatchingCount += 1 ;
                    }
                  }
                }
                // Done: All as-yet unmatched items examined against the current rule record.
                // Did we satisfy the minimum for this rule? (null means there is no minimum; same as minimum of 0)
                if(itemsMatchingCount >= minCount)
                {
                  // Minimum satisfied.
                  // Did we satisfy the maximum for this rule? (null means there is no maximum; "infinity")
                  if(maxCount == null || itemsMatchingCount <= maxCount)
                  {
                    // Both min and max satisfied. This rule record is satisfied.
                    ruleRecSatisfied = true ;
                  }
                }
                // If this rule record wasn't satisfied we might as well stop (by breaking from this loop)
                // looking at the other rules, since all rules must be satisfied for the ruleset to be satisfied.
                if(ruleRecSatisfied) // then good for this rule in this section
                {
                  sectionSatisfied = true ;
                }
                else // this rule rec failed
                {
                  sectionSatisfied = false ;
                  break ; // out of for-loop
                }
              }
              // Done: evaluating each rule in this rule section (assuming there were any).
              if(sectionSatisfied) // so far, so good for this section
              {
                // But, was EVERY item in this section matched by a rule?
                for(var ii=0; ii<wbContentsMatched.length; ii++)
                {
                  if(!wbContentsMatched[ii])
                  {
                    // Item not covered by a rule. Failed. Stop looking.
                    sectionSatisfied = false ;
                    break ; // out of for-loop
                  }
                }
              }
            } // if(rulesArray.length <= 0)
          } // if(wbSectionContents.length < minItemCount || wbSectionContents.length > maxItemCount) // NO, not right number of items
        }
        else // section is "context" or "settings"
        {
          sectionSatisfied = true ;
        } // if(section == "inputs" || section == "outputs")
        // Completely done with this rule section.
        // Was the rule section completely satisfied? If not, stop (by returning early from the ruleset.each() callback)
        // and don't bother evaluating other rule sections since all rule sections must be satisfied for the ruleset to be satisfied.
        if(sectionSatisfied) // section looks ok
        {
          toolRulesSatisfied = true ;
        }
        else
        {
          toolRulesSatisfied = false ;
          toolInfo.set(toolIdStr, false) ;
          throw $break ; // return early from callback & iteration (this is proper Prototype way to quit iteration early).
        }
      }) ; // END: ruleset.each( function(rulesetRec)
    }
    // Done evaluating this tool.
    toolInfo.set(toolIdStr, toolRulesSatisfied) ;
    return toolRulesSatisfied ;
  }) ; // END: wbRulesHash.each( function(wbRulesHashRec)

  return toolInfo ;
}
