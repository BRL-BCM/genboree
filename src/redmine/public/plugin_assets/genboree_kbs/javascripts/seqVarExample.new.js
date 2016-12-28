var seqVariantEx = {
  name: "<b>VARIANT-PHENOTYPE ID</b>",
  value: "<b>rs11540652 - Li Fraumeni syndrome 1</b>",
  iconCls:'task-folder',
  expanded: true,
  children:
  [
    {
      name: "<b>Allele Information</b>",
      value: "",
      expanded: true,
      iconCls: 'task-folder',
      children:
      [
        {
          name: "dbSNP ID",
          iconCls: 'task-folder',
          value: "rs11540652",
          domain: 'regexp',
          domainOpts: { "pattern" : "^rs\d+$" },
          children:
          [
            {
              name: "Build",
              value: "SNP137",
              leaf: true,
              iconCls: 'task'
            },
            {
              name: "Source",
              value: "in-house-pipeline",
              leaf: true,
              iconCls: 'task'
            }
          ]
        },
        {
          name: "Phenotype",
          value: "Li Fraumeni syndrome 1",
          iconCls: 'task-folder',
          children:
          [
            {
              name: "Source",
              value: "Clinvar",
              leaf: true,
              iconCls: 'task'
            }
          ]
        },
        {
          name: "Genomic Location",
          value: "chr17:7577538-7577538",
          iconCls: 'task-folder',
          domain: 'regexp',
          domainOpts: { "pattern" : "^\s*[^:\t\n ]+\s*:\s*\d+\s*-\s*\d+\s*$" },
          children:
          [
            {
              name: "Assembly version",
              value: "hg19",
              leaf: true,
              iconCls: 'task'
            },
            {
              name: "Source",
              value: "ClinVar",
              leaf: true,
              iconCls: 'task'
            }
          ]
        },
        {
          name: "Gene",
          value: "TP53",
          iconCls: 'task-folder',
          children:
          [
            {
              name: "Source",
              value: "refSeq",
              leaf: true,
              iconCls: 'task'
            }
          ]
        },
        {
          name: "Variant type",
          iconCls: 'task-folder',
          value : "SNP",
          domain: 'enum',
          domainOpts: { "values" : [ "SNP", "Indel", "CNV" ] },
          children:
          [
            {
              name: "Source",
              value: "ClinVar",
              leaf: true,
              iconCls: 'task'
            }
          ]
        },
        {
          name: "Ref allele",
          value: "C",
          iconCls: 'task-folder',
          domain: 'regexp',
          domainOpts: { "pattern" : "^[ATGCatgc]$" },
          children:
          [
            {
              name: "Source",
              value: "ClinVar",
              leaf: true,
              iconCls: 'task'
            }
          ]
        },
        {
          name: "Alt allele",
          value: "T",
          iconCls: 'task-folder',
          domain: 'regexp',
          domainOpts: { "pattern" : "^[ATGCatgc]$" },
          children:
          [
            {
              name: "Source",
              value: "ClinVar",
              leaf: true,
              iconCls: 'task'
            }
          ]
        },
        {
          name: "Seq changes",
          value: "",
          iconCls: 'task-folder',
          children:
          [
            {
              name: "Change",
              value: "TP53:NM_001126115:exon3:c.G347A:p.R116Q",
              iconCls: 'task-folder',
              children:
              [
                {
                  name: "Seq type",
                  value: "SNP",
                  domain: 'enum',
                  domainOpts: { "pattern" : [ "SNP", "Indel", "CNV" ] },
                  leaf: true,
                  iconCls: 'task'
                },
                {
                  name: "Source",
                  value: "refseq",
                  leaf: true,
                  iconCls: 'task'
                }
              ]
            },
            {
              name: "Change",
              value: "TP53:NM_001126116:exon3:c.G347A:p.R116Q",
              iconCls: 'task-folder',
              children:
              [
                {
                  name: "Seq type",
                  value: "SNP",
                  domain: 'enum',
                  domainOpts: { "pattern" : [ "SNP", "Indel", "CNV" ] },
                  leaf: true,
                  iconCls: 'task'
                },
                {
                  name: "Source",
                  value: "refseq",
                  leaf: true,
                  iconCls: 'task'
                }
              ]
            },
            {
              name: "Change",
              value: "TP53:NM_001126117:exon3:c.G347A:p.R116Q",
              iconCls: 'task-folder',
              children:
              [
                {
                  name: "Seq type",
                  value: "SNP",
                  domain: 'enum',
                  domainOpts: { "pattern" : [ "SNP", "Indel", "CNV" ] },
                  leaf: true,
                  iconCls: 'task'
                },
                {
                  name: "Source",
                  value: "refseq",
                  leaf: true,
                  iconCls: 'task'
                }
              ]
            },
            {
              name: "Change",
              value: "TP53:NM_001276697:exon3:c.G266A:p.R89Q",
              iconCls: 'task-folder',
              children:
              [
                {
                  name: "Seq type",
                  value: "SNP",
                  domain: 'enum',
                  domainOpts: { "pattern" : [ "SNP", "Indel", "CNV" ] },
                  leaf: true,
                  iconCls: 'task'
                },
                {
                  name: "Source",
                  value: "refseq",
                  leaf: true,
                  iconCls: 'task'
                }
              ]
            },
            {
              name: "Change",
              value: "TP53:NM_001276698:exon3:c.G266A:p.R89Q",
              iconCls: 'task-folder',
              children:
              [
                {
                  name: "Seq type",
                  value: "SNP",
                  domain: 'enum',
                  domainOpts: { "pattern" : [ "SNP", "Indel", "CNV" ] },
                  leaf: true,
                  iconCls: 'task'
                },
                {
                  name: "Source",
                  value: "refseq",
                  leaf: true,
                  iconCls: 'task'
                }
              ]
            },
            {
              name: "Change",
              value: "TP53:NM_001276699:exon3:c.G266A:p.R89Q",
              iconCls: 'task-folder',
              children:
              [
                {
                  name: "Seq type",
                  value: "SNP",
                  domain: 'enum',
                  domainOpts: { "pattern" : [ "SNP", "Indel", "CNV" ] },
                  leaf: true,
                  iconCls: 'task'
                },
                {
                  name: "Source",
                  value: "refseq",
                  leaf: true,
                  iconCls: 'task'
                }
              ]
            }
          ]
        }
      ]
    },
    {
      name: "<b>Evidence</b>",
      value: "",
      iconCls: "task-folder",
      expanded: true,
      children:
      [
        {
          name: "<b>Evidence</b>",
          value: "ClinVar Assertion",
          iconCls: "task-folder",
          children:
          [
            {
              name: "Assertion",
              value: "pathogenic",
              domain: 'enum',
              domainOpts: { "values" : [ "pathogenic", "likely pathogenic", "vus", "benign" ,"likely benign" ] },
              iconCls: "task-folder",
              children:
              [
                {
                  name: 'Source',
                  value: 'ClinVar',
                  leaf: true,
                  iconCls: 'task'
                }
              ]
            }
          ]
        },
        {
          name: "<b>Evidence</b>",
          value: "Population Study",
          iconCls: "task-folder",
          children:
          [
            {
              name: "<b>Evidence</b>",
              value: "Frequency of variant",
              iconCls: "task-folder",
              children:
              [
                {
                  name: 'ESP 6500',
                  value: 0.000077,
                  domain: 'float',
                  domainOpts: { "res" : 0.00001 },
                  iconCls: 'task-folder',
                  children:
                  [
                    {
                      name: "description",
                      value: "http://evs.gs.washington.edu/EVS/",
                      leaf: true,
                      iconCls: 'task'
                    },
                    {
                      name: "Import date",
                      value: "Jan 01 2014",
                      domain: 'date',
                      domainOpts: {},
                      leaf: true,
                      iconCls: 'task'
                    },
                    {
                      name: "Source",
                      value: "in-house-pipeline",
                      leaf: true,
                      iconCls: 'task'
                    }
                  ]
                },
                {
                  name: "NC160",
                  value: 0.041,
                  domain: 'float',
                  domainOpts: { "res" : 0.00001 },
                  iconCls: 'task-folder',
                  children:
                  [
                    {
                      name: "description",
                      value: "http://cancerres.aacrjournals.org/content/73/14/4372.full",
                      leaf: true,
                      iconCls: 'task'
                    },
                    {
                      name: "Import date",
                      value: "Jan 01 2014",
                      domain: 'date',
                      domainOpts: {},
                      leaf: true,
                      iconCls: 'task'
                    },
                    {
                      name: "Source",
                      value: "in-house-pipeline",
                      leaf: true,
                      iconCls: 'task'
                    }
                  ]
                },
                {
                  name: "COSMIC",
                  value: "",
                  iconCls: 'task-folder',
                  children:
                  [
                    {
                      name: "Tissue",
                      value: "lung",
                      leaf: true,
                      iconCls: 'task'
                    },
                    {
                      name: "Allele frequency",
                      value: 0.0179,
                      domain: 'float',
                      domainOpts: { "res" : 0.00001 },
                      leaf: true,
                      iconCls: 'task'
                    },
                    {
                      name: "Size",
                      value: 168,
                      domain: 'posInt',
                      domainOpts: { "min" : 0 },
                      leaf: true,
                      iconCls: 'task'
                    },
                    {
                      name: "Carrier",
                      value: 3,
                      domain: 'posInt',
                      domainOpts: { "min" : 0 },
                      leaf: true,
                      iconCls: 'task'
                    },
                    {
                      name: "Build",
                      value: "v66",
                      leaf: true,
                      iconCls: 'task'
                    },
                    {
                      name: "Description",
                      value: "http://cancer.sanger.ac.uk/cancergenome/projects/cosmic/about",
                      leaf: true,
                      iconCls: 'task'
                    },
                    {
                      name: "Import date",
                      value: "Jan 01 2014",
                      domain: 'date',
                      domainOpts: {},
                      leaf: true,
                      iconCls: 'task'
                    },
                    {
                      name: "Source",
                      value: "in-house-pipeline",
                      leaf: true,
                      iconCls: 'task'
                    }
                  ]
                }
              ]
            }
          ]
        },
        {
          name: "<b>Evidence</b>",
          value: "Computational Prediction",
          iconCls: 'task-folder',
          children:
          [
            {
              name: "<b>Evidence</b>",
              value: "<b>Protein effect of variant</b>",
              iconCls: 'task-folder',
              children:
              [
                {
                  name: "<b>Evidence</b>",
                  value: "<b>Protein function impact</b>",
                  iconCls: "task-folder",
                  children:
                  [
                    {
                      name: "SIFT",
                      value: 0.01,
                      domain: 'posInt',
                      domainOpts: { "res" : 0.001 },
                      iconCls: "task-folder",
                      children:
                      [
                        {
                          name: "Source",
                          value: "in-house-pipeline",
                          iconCls: "task",
                          leaf: true
                        }
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        }
      ]
    },
    {
      name: "<b>Conclusions</b>",
      value: "",
      expanded: true,
      iconCls: "task-folder",
      children:
      [
        {
          name: "<b>Conclusions</b>",
          value: "<b>Computational Predictions</b>",
          iconCls: "task-folder",
          children:
          [
            {
              name: "Predictions",
              value: "",
              iconCls: "task-folder",
              children:
              [
                {
                  name: "Software name",
                  value: "DT-alg-x",
                  leaf: true,
                  iconCls: "task"
                },
                {
                  name: "Algorithmic basis",
                  value: "decision tree",
                  leaf: true,
                  iconCls: "task"
                },
                {
                  name: "Prediction",
                  value: "pathogenic",
                  domain: 'enum',
                  domainOpts: { "values" : [ "pathogenic", "likely pathogenic", "vus", "benign" ,"likely benign" ] },
                  leaf: true,
                  iconCls: "task"
                }
              ]
            }
          ]
        },
        {
          name: "<b>Conclusions</b>",
          value: "<b>Working group</b>",
          iconCls: "task-folder",
          children:
          [
            {
              name: "Predictions",
              value: "",
              iconCls: "task-folder",
              children:
              [
                {
                  name: "WG",
                  value: "WG1",
                  leaf: true,
                  iconCls: "task"
                },
                {
                  name: "Conclusion",
                  value: "pathogenic",
                  domain: 'enum',
                  domainOpts: { "values" : [ "pathogenic", "likely pathogenic", "vus", "benign" ,"likely benign" ] },
                  leaf: true,
                  iconCls: "task"
                },
                {
                  name: "Date",
                  value: "Jan 01 2014",
                  domain: 'date',
                  domainOpts: {},
                  leaf: true,
                  iconCls: "task"
                },
                {
                  name: "Source",
                  value: "authorized WG curator",
                  leaf: true,
                  iconCls: 'task'
                }
              ]
            }
          ]
        }
      ]
    }
  ]
} ;
