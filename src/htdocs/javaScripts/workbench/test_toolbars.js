
Ext.onReady(function()
{
  // Requires availability of the globals and Workbench namespace.
  setTimeout( function() { initToolbars() }, 50 ) ;
}) ;

function initToolbars()
{
  Ext.QuickTips.init() ;

  // Requires availability of the globals and Workbench namespace.
  if(Workbench.globalsLoaded)
  {
    // Setup the workbench toolbar
    Workbench.toolbar = new Ext.Toolbar(
    {
      id: 'wbToolbar',
      enableOverflow: true,
      renderTo: "wbToolbarDiv",
      items:
      [
        new Ext.Toolbar.Spacer(),new Ext.Toolbar.Spacer(),
        {
          id: 'wbDataToolbarBtn',
          text: "Data",
          iconCls: "wbDataToolMenu",
          ctCls: "wbToolbarBtn",
          toolIds: [ 'uploadDbFile', 'editDbFileAttributes', 'editTrkAttributes', 'fileCopier', 'samplesImporter', 'sampleFileLinker' ],
          menu:
          {
            id: "wbDataMenu",
            ownerToolbarBtnId: 'wbDataToolbarBtn',
            ignoreParentClicks: true,
            items:
            [
              {
                text: "Files",
                iconCls: "wbFilesMenu",
                ctCls: "wbToolbarBtn",
                toolIds: [ 'uploadDbFile', 'editDbFileAttributes' ],
                menu:
                {
                  ignoreParentClicks: true,
                  items:
                  [
                    {
                      text: "Transfer File",
                      tooltip: {
                        title: "Transfer Raw File",
                        html: "<br>Transfer a raw file to Genboree for storage, sharing, and/or subsequent analysis.<br>&nbsp;<br>Will not be automatically processed following transfer; rather, just stored at Genboree as-is.",
                        showDelay: 1500,
                        dismissDelay: 10000
                        //trackMouse: false,
                        // autoHide: false,
                        // tools: [ {id: 'close', handler: function(evt, toolbar, panel, cfg) { panel.hide() ; } }]
                      },
                      id: 'uploadDbFile',
                      ctCls: "wbToolbarBtn",
                      icon: "/images/silk/page_add.png",
                      disabled: false,
                      listeners:
                      {
                        'click':      { fn: function() { showDialogWindow(this.id) ; } },
                        'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                        'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                      }
                    },
                    {
                      text: "File Copy/Move",
                      tooltip: "copy/move files",
                      id: 'fileCopier',
                      cls: "x-btn-text-icon",
                      ctCls: "wbToolbarBtn",
                      icon: "/images/workbench/tableIcon16.png",
                      disabled: false,
                      listeners:
                      {
                        'click':      { fn: function() { showDialogWindow(this.id) ; } },
                        'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                        'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                      }
                    },
                    {
                      text: "Edit Attributes",
                      tooltip: "Edit Attributes of the file",
                      id: 'editDbFileAttributes',
                      ctCls: "wbToolbarBtn",
                      icon: "/images/silk/page_edit.png",
                      disabled: true,
                      listeners:
                      {
                        'click':      { fn: function() { showDialogWindow(this.id) ; } },
                        'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                        'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                      }
                    },
                    {
                      text: "Tabbed File Viewer",
                      tooltip: "View tabbed files",
                      id: 'tabbedFileViewer',
                      cls: "x-btn-text-icon",
                      ctCls: "wbToolbarBtn",
                      icon: "/images/workbench/tableIcon16.png",
                      disabled: false,
                      listeners:
                      {
                        'click':      { fn: function() { showDialogWindow(this.id) ; } },
                        'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                        'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                      }
                    }
                  ]
                }
              },
              {
                text: "Samples",
                iconCls: "wbSamplesMenu",
                ctCls: "wbToolbarBtn",
                toolIds: [ 'samplesImporter', 'sampleFileLinker' ],
                menu:
                {
                  ignoreParentClicks: true,
                  items:
                  [
                    {
                      text: "Import Samples",
                      tooltip: "Import Samples in Genboree via tab delemited files",
                      id: 'samplesImporter',
                      cls: "x-btn-text-icon",
                      ctCls: "wbToolbarBtn",
                      icon: "/images/workbench/sampleAddIcon16.png",
                      disabled: false,
                      listeners:
                      {
                        'click':      { fn: function() { showDialogWindow(this.id) ; } },
                        'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                        'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                      }
                    },
                    {
                      text: "Sample - File Linker",
                      tooltip: "Tool for linking samples to data files",
                      id: 'sampleFileLinker',
                      cls: "x-btn-text-icon",
                      ctCls: "wbToolbarBtn",
                      icon: "/images/workbench/sampleAddIcon16.png",
                      disabled: false,
                      listeners:
                      {
                        'click':      { fn: function() { showDialogWindow(this.id) ; } },
                        'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                        'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                      }
                    }
                  ]
                }
              },
              {
                text: "Tracks",
                iconCls: "wbTracksMenu",
                ctCls: "wbToolbarBtn",
                disabled: false,
                toolIds: ['editTrkAttributes', 'arrayDataImporter'],
                menu:
                {
                  ignoreParentClicks: true,
                  items:
                  [
                    '<span class="menu-title">Import:</span>',
                    {
                      text: "Array Data",
                      tooltip: "Import Array Data into Genboree as a high density track",
                      id: 'arrayDataImporter',
                      cls: "x-btn-text-icon",
                      ctCls: "wbToolbarBtn",
                      icon: "/images/silk/table_edit.png",
                      disabled: false,
                      listeners:
                      {
                        'click':      { fn: function() { showDialogWindow(this.id) ; } },
                        'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                        'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                      }
                    },
                    {
                      text: "Upload Annotations",
                      tooltip: "Upload data as Annotations into a Genboree Track",
                      id: 'uploadAnnotations',
                      cls: "x-btn-text-icon",
                      ctCls: "wbToolbarBtn",
                      icon: "/images/silk/cog_go.png",
                      disabled: true,
                      hidden: true,
                      listeners:
                      {
                        'click':      { fn: function() { showDialogWindow(this.id) ; } },
                        'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                        'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                      }
                    },
                    {
                      text: "Edit Attributes",
                      tooltip: "Edit Attributes of the track",
                      id: 'editTrkAttributes',
                      ctCls: "wbToolbarBtn",
                      icon: "/images/silk/table_edit.png",
                      disabled: true,
                      hidden: true,
                      listeners:
                      {
                        'click':      { fn: function() { showDialogWindow(this.id) ; } },
                        'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                        'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                      }
                    }
                  ]
                }
              }
            ]
          }
        },
        new Ext.Toolbar.Spacer(),new Ext.Toolbar.Spacer(),
        {
          id: 'wbAnalysisToolbarBtn',
          text: "Analysis",
          iconCls: "wbAnalysisToolMenu",
          ctCls: "wbToolbarBtn",
          toolIds: [ 'epigenomePercentileQC', 'epigenomeAtlasSimilaritySearch', 'spark', 'signalSimilaritySearch', 'signalDataComparison', 'coverage',
                    'filterReads', 'smallRNAPashMapper', 'combinedCoverage', 'signalDataComparisonAtlas', 'sparkEpigenomeAtlas', 'seqImport', 'qiime',
                    'machineLearning', 'alphaDiversity', 'machineLearningManual', 'rdp', 'atlasSNP2', 'atlasSNP2Genotyper', 'atlasIndel2', 'compEpigenomicsROILifter',
                    'comparativeSignalDataComparison', 'comparativeSignalDataComparisonAtlas', 'comparativeSignalSimilaritySearch', 'comparativeEpigenomeAtlasSimilaritySearch', 'svd'  ],
          menu:
          {
            id: "wbAnalysisMenu",
            ownerToolbarBtnId: 'wbAnalysisToolbarBtn',
            ignoreParentClicks: true,
            items:
            [
              {
                text: "Epigenomics",
                iconCls: "wbEpigenomicsMenu",
                ctCls: "wbToolbarBtn",
                toolIds: [ 'epigenomePercentileQC', 'epigenomeAtlasSimilaritySearch', 'spark', 'signalSimilaritySearch', 'signalDataComparison', 'compEpigenomicsROILifter', 'comparativeSignalDataComparisonAtlas',
                          'comparativeSignalSimilaritySearch', 'comparativeSignalDataComparisonAtlas', 'comparativeEpigenomeAtlasSimilaritySearch', 'svd'],
                menu:
                {
                  ignoreParentClicks: true,
                  items:
                  [
                    '<span class="menu-title">QC Tools:</span>',
                    {
                      text: "Epigenomic Percentile-Based QC",
                      tooltip: { title: "Epigenomic Percentile-Based QC", html: "<br>Performs QC of epigenomic methylation data via a percentile-based method.<br>&nbsp;<br>Mapped reads are provided by specifying a BED file which already has been transferred to Genboree.", showDelay: 1500, dismissDelay: 10000 },
                      id: 'epigenomePercentileQC',
                      ctCls: "wbToolbarBtn",
                      iconCls: "wbEpigenomePercentileQCMenuItem",
                      disabled: false,
                      listeners:
                      {
                        'click':      { fn: function() { showDialogWindow(this.id) ; } },
                        'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                        'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                      }
                    },
                    '<span class="menu-title">Analysis &amp; Search Tools:</span>',
                    {
                      text: "Spark Analysis",
                      tooltip: {
                        title: "Spark Analysis",
                        html: "<br>Perform the preprocessing and clustering steps of Cydney Nielson's Spark tool on signal data found in tracks or files you specify.<br>&nbsp;<br>Once complete, view the results in Spark's stand-alone GUI.",
                        showDelay: 1500,
                        dismissDelay: 10000 //,
                        //trackMouse: false,
                        // autoHide: false,
                        // tools: [ {id: 'close', handler: function(evt, toolbar, panel, cfg) { panel.hide() ; } }, { id: 'save'}]
                      },
                      id: 'spark',
                      ctCls: "wbToolbarBtn",
                      iconCls: "wbSparkMenuItem",
                      disabled: false,
                      listeners:
                      {
                        'click':      { fn: function() { showDialogWindow(this.id) ; } },
                        'mouseover':  {
                          fn: function() {
                            removeGenboreeClasses(this) ;
                            }
                        },
                        'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                      }
                    },
                    {
                      text: "Signal Search",
                      tooltip: { title: "Signal Similarity Search", html: "<br>Find the correlation of a query track containing signal data with each of the target tracks you indicate.", showDelay: 1500, dismissDelay: 10000 },
                      id: 'signalSimilaritySearch',
                      ctCls: "wbToolbarBtn",
                      iconCls: "wbSignalSimilaritySearchMenuItem",
                      disabled: false,
                      listeners:
                      {
                        'click':      { fn: function() { showDialogWindow(this.id) ; } },
                        'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                        'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                      }
                    },
                    {
                      text: "Signal Comparison",
                      tooltip: { title: "Signal Comparison", html: "<br>Compare the signals in two tracks via positional linear regression, generating an output track containing the level of agreement at each annotation, as well goodness-of-fit metrics.", showDelay: 1500, dismissDelay: 10000 },
                      id: 'signalDataComparison',
                      cls: "x-btn-text-icon",
                      ctCls: "wbToolbarBtn",
                      iconCls: "wbCompareMenuItem",
                      disabled: false,
                      listeners:
                      {
                        'click':      { fn: function() { showDialogWindow(this.id) ; } },
                        'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                        'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                      }
                    },
                    {
                      text: "Singular Value Decomposition",
                      tooltip: { title: "Single Value Decomposition", html: "<br>Perform Singular Value Decomposition on data tracks.", showDelay: 1500, dismissDelay: 10000 },
                      id: 'svd',
                      cls: "x-btn-text-icon",
                      ctCls: "wbToolbarBtn",
                      iconCls: "wbSVDMenuItem",
                      disabled: false,
                      listeners:
                      {
                        'click':      { fn: function() { showDialogWindow(this.id) ; } },
                        'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                        'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                      }
                    },
                    '<span class="menu-title">Comparative Epigenomics Analysis:</span>',
                    {
                      text: "ROI-Lifter",
                      tooltip: { title: "ROI Lifter", html: "<br>Lift a Regions Of Interest (ROI) track from one genome to another, in preparation for cross-genome signal analysis.", showDelay: 1500, dismissDelay: 10000 },
                      id: 'compEpigenomicsROILifter',
                      ctCls: "wbToolbarBtn",
                      iconCls: "wbCompEpigenomicsROILifterMenuItem",
                      disabled: false,
                      listeners:
                      {
                        'click':      { fn: function() { showDialogWindow(this.id) ; } },
                        'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                        'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                      }
                    },
                    {
                      text: "Cross-Genome Signal Search",
                      tooltip: { title: "Cross - Genome Signal Search", html: "<br>Search a query track on one genome, against multiple signal tracks on another genome using a matching pair of ROI tracks.", showDelay: 1500, dismissDelay: 10000 },
                      id: 'comparativeSignalSimilaritySearch',
                      ctCls: "wbToolbarBtn",
                      iconCls: "wbSignalSimilaritySearchMenuItem",
                      disabled: false,
                      listeners:
                      {
                        'click':      { fn: function() { showDialogWindow(this.id) ; } },
                        'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                        'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                      }
                    },
                    {
                      text: "Cross-Genome Signal Comparison",
                      tooltip: { title: "Cross-Genome Signal Comparison", html: "<br>Compare two signal-containing tracks, each on different genome, using a matching pair of ROI tracks.", showDelay: 1500, dismissDelay: 10000 },
                      id: 'comparativeSignalDataComparison',
                      ctCls: "wbToolbarBtn",
                      iconCls: "wbCompareMenuItem",
                      disabled: false,
                      listeners:
                      {
                        'click':      { fn: function() { showDialogWindow(this.id) ; } },
                        'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                        'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                      }
                    },
                    '<span class="menu-title">Epigenome Atlas:</span>',
                    {
                      text: "Epigenome Atlas-Aware Tools",
                      iconCls: "wbEpigenomeAtlasMenu",
                      ctCls: "wbToolbarBtn",
                      toolIds: [ 'epigenomeAtlasSimilaritySearch', 'sparkEpigenomeAtlas', 'signalDataComparisonAtlas', 'comparativeSignalDataComparisonAtlas', 'comparativeEpigenomeAtlasSimilaritySearch' ],
                      tooltip: {
                        title: "Epigenome Atlas-Aware Tools",
                        html: "<br>Use these tools directly on Epigenome Atlas data. The tools here are the same as provided more generically, but the tool interfaces are Atlas-aware and can allow you to easily select input data from the Epigenomic Atlas. This can be useful for comparing your own data against data in the Epigenome Atlas or for exploring the data in the Atlas data freeze.",
                        showDelay: 1500,
                        dismissDelay: 10000
                        //trackMouse: false,
                        // autoHide: false,
                        // tools: [ {id: 'close', handler: function(evt, toolbar, panel, cfg) { panel.hide() ; } }]
                      },
                      menu:
                      {
                        ignoreParentClicks: true,
                        items:
                        [
                          '<span class="menu-title">Analysis & Search Tools:</span>',
                          {
                            text: "Spark Analysis - Epigenomic Atlas",
                            tooltip: {
                              title: "Spark Analysis - Epigenomic Atlas",
                              html: "<br>Perform the preprocessing and clustering steps of Cydney Nielson's Spark tool on tracks from the Epigenome Atlas with or without signal data found in tracks or files you specify.",
                              showDelay: 1500,
                              dismissDelay: 10000
                              //trackMouse: false,
                              // autoHide: false,
                              // tools: [ {id: 'close', handler: function(evt, toolbar, panel, cfg) { panel.hide() ; } }]
                            },
                            id: 'sparkEpigenomeAtlas',
                            ctCls: "wbToolbarBtn",
                            iconCls: "wbSparkMenuItem",
                            disabled: false,
                            listeners:
                            {
                              'click':      { fn: function() { showDialogWindow(this.id) ; } },
                              'mouseover':  {
                                fn: function() {
                                  removeGenboreeClasses(this) ;
                                  }
                              },
                              'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                            }
                          },
                          {
                            text: "Signal Search - Epigenome Atlas",
                            tooltip: {
                              title: "Epigenome Atlas Search",
                              html: "<br>Find the correlation between your own query signal data and each of the <i>Epigenome Atlas</i> tracks, to find samples and marks highly correlated with your own methylation data.",
                              showDelay: 1500,
                              dismissDelay: 10000
                              //trackMouse: false,
                              // autoHide: false,
                              // tools: [ {id: 'close', handler: function(evt, toolbar, panel, cfg) { panel.hide() ; } }]
                            },
                            id: 'epigenomeAtlasSimilaritySearch',
                            ctCls: "wbToolbarBtn",
                            iconCls: "wbSignalSimilaritySearchMenuItem",
                            disabled: false,
                            listeners:
                            {
                              'click':      { fn: function() { showDialogWindow(this.id) ; } },
                              'mouseover':  {
                                fn: function() {
                                  removeGenboreeClasses(this) ;
                                  }
                              },
                              'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                            }
                          },
                          {
                            text: "Signal Comparison - Epigenome Atlas",
                            tooltip: { title: "Signal Comparison", html: "<br>Compare the signals in your own track against a track in the Epigenome Atlas, or compare the signals in two tracks from the Atlas. Uses positional linear regression, generating an output track containing the level of agreement at each annotation, as well goodness-of-fit metrics.", showDelay: 1500, dismissDelay: 10000 },
                            id: 'signalDataComparisonAtlas',
                            cls: "x-btn-text-icon",
                            ctCls: "wbToolbarBtn",
                            iconCls: "wbCompareMenuItem",
                            disabled: false,
                            listeners:
                            {
                              'click':      { fn: function() { showDialogWindow(this.id) ; } },
                              'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                              'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                            }
                          },
                          '<span class="menu-title">Comparative Epigenomics - Epigenome Atlas-Aware:</span>',
                          {
                            text: "Cross-Genome Signal Search - Epigenomic Atlas",
                            tooltip: { title: "Cross - Genome Signal Search - Epigenomic Atlas", html: "<br>Search a query track on one genome, against multiple signal tracks on another genome using a matching pair of ROI tracks.", showDelay: 1500, dismissDelay: 10000 },
                            id: 'comparativeEpigenomeAtlasSimilaritySearch',
                            ctCls: "wbToolbarBtn",
                            iconCls: "wbSignalSimilaritySearchMenuItem",
                            disabled: false,
                            listeners:
                            {
                              'click':      { fn: function() { showDialogWindow(this.id) ; } },
                              'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                              'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                            }
                          },
                          {
                            text: "Cross-Genome Signal Comparison - Epigenomic Atlas",
                            tooltip: { title: "Cross-Genome Signal Comparison - Epigenomic Atlas", html: "<br><br>Compare two signal-containing tracks, each on different genome, using a matching pair of ROI tracks.", showDelay: 1500, dismissDelay: 10000 },
                            id: 'comparativeSignalDataComparisonAtlas',
                            ctCls: "wbToolbarBtn",
                            iconCls: "wbCompareMenuItem",
                            disabled: false,
                            listeners:
                            {
                              'click':      { fn: function() { showDialogWindow(this.id) ; } },
                              'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                              'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                            }
                          }
                        ]
                      }
                    }
                  ]
                }
              },
              {
                text: "Track Tools",
                iconCls: "wbTrackToolsMenu",
                ctCls: "wbToolbarBtn",
                disabled: false,
                toolIds: ['coverage'],
                menu:
                {
                  ignoreParentClicks: true,
                  items:
                  [
                    '<span class="menu-title">Tools:</span>',
                    {
                      text: "Coverage Computation",
                      tooltip: { title: "Coverage", html: "<br>Find the base level coverage of a track/file of Interest.", showDelay: 1500, dismissDelay: 10000 },
                      id: 'coverage',
                      ctCls: "wbToolbarBtn",
                      iconCls: "wbCoverageMenuItem",
                      disabled: false,
                      listeners:
                      {
                        'click':      { fn: function() { showDialogWindow(this.id) ; } },
                        'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                        'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                      }
                    }
                  ]
                }
              },
              {
                text: "Small RNA",
                iconCls: "wbSmallRNAMenu",
                ctCls: "wbToolbarBtn",
                disabled: false,
                toolIds: ['filterReads', 'smallRNAPashMapper', 'combinedCoverage'],
                menu:
                {
                  ignoreParentClicks: true,
                  items:
                  [
                    '<span class="menu-title">Tools:</span>',
                    {
                      text: "Filter Reads",
                      tooltip: { title: "Filter Reads", html: "<br>Tool for filtering reads", showDelay: 1500, dismissDelay: 10000 },
                      id: 'filterReads',
                      ctCls: "wbToolbarBtn",
                      iconCls: "wbFilterReadsMenuItem",
                      disabled: false,
                      listeners:
                      {
                        'click':      { fn: function() { showDialogWindow(this.id) ; } },
                        'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                        'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                      }
                    },
                    {
                      text: "Small RNA Pash Mapping",
                      tooltip: { title: "Small RNA Pash Mapping", html: "<br>Tool for mapping FASTQ sequence file(s) using pash-3.0", showDelay: 1500, dismissDelay: 10000 },
                      id: 'smallRNAPashMapper',
                      ctCls: "wbToolbarBtn",
                      iconCls: "wbFilterReadsMenuItem",
                      disabled: false,
                      listeners:
                      {
                        'click':      { fn: function() { showDialogWindow(this.id) ; } },
                        'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                        'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                      }
                    },
                    {
                      text: "Combined Coverage Profiler",
                      tooltip: { title: "Combined Coverage Profiler", html: "<br>Tool for generating combined miRNA profile from Pash-3.0 generated LFF files", showDelay: 1500, dismissDelay: 10000 },
                      id: 'combinedCoverage',
                      ctCls: "wbToolbarBtn",
                      iconCls: "wbFilterReadsMenuItem",
                      disabled: false,
                      listeners:
                      {
                        'click':      { fn: function() { showDialogWindow(this.id) ; } },
                        'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                        'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                      }
                    }
                  ]
                }
              },
              {
                text: "Microbiome Workbench",
                iconCls: "wbMicrobiomeMenu",
                ctCls: "wbToolbarBtn",
                disabled: false,
                toolIds: ['seqImport', 'qiime', 'machineLearning', 'rdp', 'alphaDiversity', 'machineLearningManual'],
                menu:
                {
                  ignoreParentClicks: true,
                  items:
                  [
                    '<span class="menu-title">Data Initialization:</span>',
                    {
                      text: "Microbiome Sequence Import",
                      tooltip: { title: "Microbiome Sequence Import", html: "<br>Tool for importing samples", showDelay: 1500, dismissDelay: 10000 },
                      id: 'seqImport',
                      ctCls: "wbToolbarBtn",
                      iconCls: "wbMBWSeqExtractMenuItem",
                      disabled: false,
                      listeners:
                      {
                        'click':      { fn: function() { showDialogWindow(this.id) ; } },
                        'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                        'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                      }
                    },
                    '<span class="menu-title">Data Analysis:</span>',
                    {
                      text: "RDP",
                      tooltip: { title: "RDP", html: "<br>Run RDP For Microbiome", showDelay: 1500, dismissDelay: 10000 },
                      id: 'rdp',
                      ctCls: "wbToolbarBtn",
                      iconCls: "wbMBWRdpMenuItem",
                      disabled: false,
                      listeners:
                      {
                        'click':      { fn: function() { showDialogWindow(this.id) ; } },
                        'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                        'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                      }
                    },
                    {
                      text: "QIIME",
                      tooltip: { title: "Qiime", html: "<br>Creates sample groups, generates OTU table, generates sample metadata", showDelay: 1500, dismissDelay: 10000 },
                      id: 'qiime',
                      ctCls: "wbToolbarBtn",
                      iconCls: "wbMBWQiimeMenuItem",
                      disabled: false,
                      listeners:
                      {
                        'click':      { fn: function() { showDialogWindow(this.id) ; } },
                        'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                        'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                      }
                    },
                    {
                      text: "Alpha Diversity",
                      tooltip: { title: "Alpha Diversity", html: "<br>", showDelay: 1500, dismissDelay: 10000 },
                      id: 'alphaDiversity',
                      ctCls: "wbToolbarBtn",
                      iconCls: "wbMBWAlphaDivMenuItem",
                      disabled: false,
                      listeners:
                      {
                        'click':      { fn: function() { showDialogWindow(this.id) ; } },
                        'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                        'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                      }
                    },
                    {
                      text: "Machine Learning",
                      tooltip: { title: "Machine Learning", html: "<br>Run Machine Learning For Microbiome", showDelay: 1500, dismissDelay: 10000 },
                      id: 'machineLearning',
                      ctCls: "wbToolbarBtn",
                      iconCls: "wbMBWMachineLearningMenuItem",
                      disabled: false,
                      listeners:
                      {
                        'click':      { fn: function() { showDialogWindow(this.id) ; } },
                        'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                        'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                      }
                    },
                    '<span class="menu-title">Manual Data Analysis:</span>',
                    {
                      text: "Machine Learning - Manual",
                      tooltip: { title: "Machine Learning - Manual", html: "<br>Run Machine Learning Manually (without having to follow the workbench pipeline)", showDelay: 1500, dismissDelay: 10000 },
                      id: 'machineLearningManual',
                      ctCls: "wbToolbarBtn",
                      iconCls: "wbMBWMachineLearningMenuItem",
                      disabled: false,
                      listeners:
                      {
                        'click':      { fn: function() { showDialogWindow(this.id) ; } },
                        'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                        'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                      }
                    }
                  ]
                }
              },
              {
                text: "SNPs",
                iconCls: "wbSNPsMenu",
                ctCls: "wbToolbarBtn",
                toolIds: [ 'atlasSNP2', 'atlasSNP2Genotyper', 'atlasIndel2' ],
                menu:
                {
                  ignoreParentClicks: true,
                  items:
                  [
                    '<span class="menu-title">Atlas2 Suite Tools - SNP Calling</span>',
                    {
                      text: "Atlas-SNP2",
                      tooltip: { title: "Atlas-SNP2 SNP calling program", html: "<br>Runs Atlas-SNP2 on a SAM or BAM file in order to detect SNP from whole genome resequencing data.", showDelay: 1500, dismissDelay: 10000 },
                      id: 'atlasSNP2',
                      ctCls: 'wbToolbarBtn',
                      iconCls: 'wbAtlasSNP2MenuItem',
                      disabled: false,
                      listeners:
                      {
                        'click':      { fn: function() { showDialogWindow(this.id) ; } },
                        'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                        'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                      }
                    },
                    {
                      text: "Atlas-Indel2",
                      tooltip: { title: "Atlas-Indel2", html: "<br>Runs the Atlas-Indel2 suite of indel-calling tools based on logistic regression models on pertinent sequencing data variables. This version is trained and optimized for Illumina Exome Capture data.", showDelay: 1500, dismissDelay: 10000 },
                      id: 'atlasIndel2',
                      ctCls: 'wbToolbarBtn',
                      iconCls: 'wbAtlasIndel2MenuItem',
                      disabled: false,
                      listeners:
                      {
                        'click':      { fn: function() { showDialogWindow(this.id) ; } },
                        'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                        'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                      }
                    },
                    '<span class="menu-title">Atlas2 Suite Tools - Re-Genotyping</span>',
                    {
                      text: "Atlas-SNP2 Re-Genotyper",
                      tooltip: { title: "Atlas-SNP2 Genotyper", html: "<br>Runs the Atlas-SNP2 Genotyper program for re-genotyping data produced from an Atlas-SNP2 run or a custom .snp file (If you have a different minimum coverage and/or cutoff setting).", showDelay: 1500, dismissDelay: 10000 },
                      id: 'atlasSNP2Genotyper',
                      ctCls: 'wbToolbarBtn',
                      iconCls: 'wbAtlasSNP2GenotyperMenuItem',
                      disabled: false,
                      listeners:
                      {
                        'click':      { fn: function() { showDialogWindow(this.id) ; } },
                        'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                        'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                      }
                    }
                  ]
                }
              }
            ]
          }
        },
        new Ext.Toolbar.Spacer(),new Ext.Toolbar.Spacer(),
        {
          id: 'wbQueryToolbarBtn',
          text: "Query/Search",
          iconCls: "wbQueryToolMenu",
          ctCls: "wbToolbarBtn",
          toolIds: [ 'createQuery', 'manageQuery', 'applyQuery' ],
          menu:
          {
            id: "wbQueryMenu",
            ignoreParentClicks: true,
            items:
            [
              {
                text: "Boolean Querying",
                iconCls: "wbBooleanQueryMenu",
                ctCls: "wbToolbarBtn",
                toolIds: [ 'createQuery', 'manageQuery', 'applyQuery' ],
                menu:
                {
                  ignoreParentClicks: true,
                  items:
                  [
                    {
                      text: "Create Query",
                      tooltip: { title: "Design a New Boolean Query", html: "<br>Design and save a new boolean query. Query can be reused and applied to differing types of data entities. Nested boolean queries are supported.", showDelay: 1500, dismissDelay: 10000 },
                      id: 'createQuery',
                      ctCls: "wbToolbarBtn",
                      icon: "/images/silk/cog_add.png",
                      disabled: false,
                      listeners:
                      {
                        'click':      { fn: function() { showDialogWindow(this.id) ; } },
                        'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                        'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                      }
                    },
                    {
                      text: "Manage Query",
                      tooltip: { title: "Manage Query", html: "<br>Edit an existing query.", showDelay: 1500, dismissDelay: 10000 },
                      id: 'manageQuery',
                      ctCls: "wbToolbarBtn",
                      icon: "/images/silk/cog_edit.png",
                      disabled: false,
                      listeners:
                      {
                        'click':      { fn: function() { showDialogWindow(this.id) ; } },
                        'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                        'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                      }
                    },
                    {
                      text: "Apply Query",
                      tooltip: { title: "Run Query on Data", html: "<br>Run an existing query on data you indicate.", showDelay: 1500, dismissDelay: 10000 },
                      id: 'applyQuery',
                      ctCls: "wbToolbarBtn",
                      icon: "/images/silk/cog_go.png",
                      disabled: false,
                      listeners:
                      {
                        'click':      { fn: function() { showDialogWindow(this.id) ; } },
                        'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                        'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                      }
                    }
                  ]
                }
              }
            ]
          }
        },
        new Ext.Toolbar.Spacer(),new Ext.Toolbar.Spacer(),
        {
          id: 'wbTrackToolbarBtn',
          text: "Track Manipulation",
          iconCls: "wbTrackToolMenu",
          ctCls: "wbToolbarBtn",
          toolIds: [ 'trackCopier', 'trkIntersect', 'trkNonIntersect', 'trkCombine', 'trkSegment' ],
          menu:
          {
            id: "wbTrackMenu",
            ignoreParentClicks: true,
            items:
            [
              {
                text: "Track Copy/Move",
                tooltip: { title: "Track Copy/Move", html: "<br>Copy/Move tracks to a destination database.", showDelay: 1500, dismissDelay: 10000 },
                id: 'trackCopier',
                ctCls: "wbToolbarBtn",
                icon: "/images/silk/page_copy.png",
                disabled: false,
                listeners:
                {
                  'click':      { fn: function() { showDialogWindow(this.id) ; } },
                  'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                  'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                 }
              },
              '-',
              {
                text: "Track Intersection",
                tooltip: { title: "Intersect Tracks", html: "<br>Find all the annotations in a query track that have an intersection with all/any annotations of one or more other tracks.", showDelay: 1500, dismissDelay: 10000 },
                id: 'trkIntersect',
                ctCls: "wbToolbarBtn",
                icon: "/images/workbench/trackIntersectButton16.png",
                disabled: true,
                listeners:
                {/*
                  'click':      { fn: function() { showDialogWindow(this.id) ; } },
                  'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                  'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                 */}
              },
              {
                text: "Track Non-Intersection",
                tooltip: { title: "Non-Intersecting Annotations", html: "<br>Find all the annotations in a query track that <i>do not</i> have an intersection with all/any annotations of one or more other tracks.", showDelay: 1500, dismissDelay: 10000 },
                id: 'trkNonIntersect',
                ctCls: "wbToolbarBtn",
                icon: "/images/workbench/trackIntersectButton16.png",
                disabled: true,
                listeners:
                {/*
                  'click':      { fn: function() { showDialogWindow(this.id) ; } },
                  'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                  'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                 */}
              },
              {
                text: "Combine Tracks",
                tooltip: { title: "Combine Tracks", html: "<br>Combine the annotations from two or more tracks into a new track.", showDelay: 1500, dismissDelay: 10000 },
                id: 'trkCombine',
                ctCls: "wbToolbarBtn",
                icon: "/images/workbench/trackCombine.png",
                disabled: true,
                listeners:
                {/*
                  'click':      { fn: function() { showDialogWindow(this.id) ; } },
                  'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                  'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                 */}
              },
              '-',
              {
                text: "Track Segmentation",
                tooltip: { title: "Perform Track Segmentation", html: "<br>Perform a track segmentation analysis on selected track.", showDelay: 1500, dismissDelay: 10000 },
                id: 'trkSegment',
                ctCls: "wbToolbarBtn",
                icon: "/images/workbench/trackIntersectButton16.png",
                disabled: true,
                listeners:
                {/*
                  'click':      { fn: function() { showDialogWindow(this.id) ; } },
                  'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                  'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                 */}
              }
            ]
          }
        },
        new Ext.Toolbar.Spacer(),new Ext.Toolbar.Spacer(),
        {
          id: 'wbVisualizationToolbarBtn',
          text: "Visualization",
          iconCls: "wbVisualizationToolsMenu",
          ctCls: "wbToolbarBtn",
          toolIds: [ 'vgpTool', 'circosTool', 'genbBrowser' ],
          menu:
          {
            id: "wbVisualizationMenu",
            ignoreParentClicks: true,
            items:
            [
              {
                text: "VGP",
                tooltip: { title: "Visual Genome Painting (VGP)", html: "<br>Configure and draw a VGP visualization of genomic annotations.", showDelay: 1500, dismissDelay: 10000 },
                id: 'vgpTool',
                ctCls: "wbToolbarBtn",
                icon: "/images/workbench/vgpButton16.png",
                disabled: true,
                listeners:
                {/*
                  'click':      { fn: function() { showDialogWindow(this.id) ; } },
                  'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                  'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                 */}
              },
              {
                text: "Circos",
                tooltip: { title: "Circos", html: "<br>Configure and draw a Circos visualization of genomic annotations.", showDelay: 1500, dismissDelay: 10000 },
                id: 'circosTool',
                ctCls: "wbToolbarBtn",
                icon: "/images/workbench/circosButton16.png",
                disabled: true,
                listeners:
                {/*
                  'click':      { fn: function() { showDialogWindow(this.id) ; } },
                  'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                  'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                 */}
              },
              {
                text: "Genboree Browser",
                tooltip: { title: "Genboree Browser", html: "<br>Configure and draw genomic annotations in the Genboree browser.", showDelay: 1500, dismissDelay: 10000 },
                id: 'genbBrowser',
                ctCls: "wbToolbarBtn",
                icon: "/images/workbench/circosButton16.png",
                disabled: true,
                listeners:
                {/*
                  'click':      { fn: function() { showDialogWindow(this.id) ; } },
                  'mouseover':  { fn: function() { removeGenboreeClasses(this) ; } },
                  'mouseout':   { fn: function() { updateToolButtonBySatisfaction(this.id, this) ; } }
                 */}
              }
            ]
          }
        }
      ]
    }) ;
    // Toolbars loaded, let others know.
    Workbench.toolbarsLoaded = true ;
  }
  else // don't have dependencies, try again in a very short while
  {
    setTimeout( function() { initToolbars() }, 50) ;
  }
}
