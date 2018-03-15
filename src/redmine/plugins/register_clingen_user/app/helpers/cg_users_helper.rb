module CgUsersHelper
  # Recursive function that sends nested calls one by one 
  # in order determined by two variables: @rsrcPath and @plc as initialized in the putRequestInit
  def nestedCall(n,rackEnv,&callback)
    if(n != (@pls.length))
      $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ CGUSER DOC ASYNC PUT: call: #{n}")
      putDocAsync(rackEnv, @rsrcPaths[n], @pls[n]){ |result|
        begin
           $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ CGUSER DOC ASYNC PUT: Inside callback no: #{n} results are: #{result.inspect}")
           if( result[:obj] )
            nestedCall( n+1, rackEnv){|result|
              callback.call( result )
            }
           else
            callback.call( result )
           end
        rescue
          #result = Hash.new()
          result[:err] = result[:err] or "begin rescued from putAsync call #{result.inspect}"
          callback.call( result )
        end
      }
    else
      result = Hash.new()
      result[:obj] = "All registration calls succeded!"
      callback.call( result )
    end
  end

  # This is what called from the main controller to give access to registry/calculator related resources
  def giveAccessToRegistry(rackEnv, username , &callback)

    # Initialize variables
    putRequestInit(username)

    # Start nested calls
    nestedCall(0,rackEnv){|result|
     begin
      if(result[:obj])
        callback.call( result )
      else
        callback.call( result )
      end
     rescue
      result[:err] = result[:err] or "Error in the first callback of nested async calls"
      callback.call(result)
     end
    }
  end

  def rest_to_group rest_path
    group_name_index = rest_path.split("/").index("grp") + 1
    return(rest_path.split("/")[group_name_index])
  end

  def putRequestInit username
    # Initialize variables
    # Piotr: This will change based on deployment. 
    # You might need to copy from our createUser.rb file
    @username = username

    @rsrcPaths = [
                   "/REST/v1/grp/#{@project_settings.registry_grp}/usr/#{@username}/role",
                   "/REST/v1/grp/#{@project_settings.configuration_group}/usr/#{@username}/role",
                   "/REST/v1/grp/#{@username}",
                   "/REST/v1/grp/#{@username}/usr/#{@username}/role",
                   "/REST/v1/grp/#{@username}/usr/#{@project_settings.gb_public_tool_user}/role",
                   "/REST/v1/grp/#{@username}/usr/#{@project_settings.gb_cache_user}/role",
                   "/REST/v1/grp/#{@username}/kb/#{@username}",
                   "/REST/v1/grp/#{@username}/kb/#{@username}/coll/SourceRegistry/model",
                   "/REST/v1/grp/#{@username}/kb/#{@username}/coll/Evidence/model"      ,
                   "/REST/v1/grp/#{@username}/kb/#{@username}/coll/Evidence/template/newEviTempEvidence1Evidence",
                   "/REST/v1/grp/#{@username}/kb/#{@username}/coll/Evidence/quest/newEviEvidence1Evidence"       ,
                   "/REST/v1/grp/#{@username}/kb/#{@username}/coll/SourceRegistry/doc/user_registry",
                   "/REST/v1/grp/#{@project_settings.configuration_group}/kb/#{@project_settings.configuration_kb}/coll/Configuration/doc/#{@username}",
                   "/REST/v1/grp/#{@project_settings.cache_group}/usr/#{@username}/role",
                   "/REST/v1/grp/#{rest_to_group @project_settings.acmg_guideline_rest}/usr/#{@username}/role",
                   "/REST/v1/grp/#{rest_to_group @project_settings.acmg_allowed_tags_rest}/usr/#{@username}/role",
                   "/REST/v1/grp/#{rest_to_group @project_settings.acmg_transformation_rest}/usr/#{@username}/role",
                   "/REST/v1/grp/#{@username}/kb/#{@username}/coll/GeneSummary/model" 
                 ]

     @pls = [
               {"role"=>"subscriber", "permissionBits"=>""}.to_json,
               {"role"=>"author", "permissionBits"=>""}.to_json,
               nil,
               {"role"=>"author", "permissionBits"=>""}.to_json,
               {"role"=>"author", "permissionBits"=>""}.to_json,
               {"role"=>"author", "permissionBits"=>""}.to_json,
               nil    ,
               get_source_registry_model_json.to_json,
               get_evidence_model_json.to_json,
               get_template_doc.to_json,
               get_questionnair_doc.to_json,
               (get_source_registry_doc_json @username).to_json,
               (get_configuration_doc @username).to_json,
               {"role"=>"author", "permissionBits"=>""}.to_json,
               {"role"=>"subscriber", "permissionBits"=>""}.to_json,
               {"role"=>"subscriber", "permissionBits"=>""}.to_json,
               {"role"=>"subscriber", "permissionBits"=>""}.to_json,
               get_gene_summary_model.to_json
           ]
  end

  def putDocAsync(rackEnv,rsrcPath, pl, &callback)
    $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ CGUSER DOC ASYNC PUT: will initiate SimpleAsynApiRequest with host: #{@gbHost}, project #{@project}, super_login: #{@great_honor.inspect}, thePath will be #{rsrcPath}")
    # Key variables to collect information from from respCallBack
    @body = ''
    @status = ''
    @headers = ''

    @apiReq = GbApi::SimpleAsyncApiRequester.new(rackEnv, 
                                                     @gbHost, 
                                                     @project,
                                                     @great_honor)
    @apiReq.notifyWebServer = false

    @apiReq.respCallback { |array|
       $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++  DOC ASYNC PUT: Inside respCallbak of AYNC PUT \n\n")
       @status = array[0]
       @headers = array[1]
       array[2].each { |chunk|
         @body += chunk
       }
    }

    @apiReq.bodyFinish {
      send_back = Hash.new()
      $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ DOC ASYNC PUT: in bodyFinish callback")
      begin
        if(@status.to_i < 400)
          $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ DOC ASYNC PUT: success")
          send_back[:obj] = @body
        else
          $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ DOC ASYNC PUT: the request resulted in error status: #{@body}")
          send_back[:err] = "ERROR: Could not put #{pl} to #{rsrcPath} ERROR: status: #{@status} #{@body}"
        end
      rescue Exception => err
        $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ DOC ASYNC PUT: error raised from previous calls")
        send_back[:err] = "ERROR: Could not put #{pl} to #{rsrcPath}. The error message is: #{err.message}"
      ensure
        callback.call( send_back )
      end
    }
    @apiReq.put(rsrcPath,{ },payload=pl) 
    # NO CODE HERE. Async.
  end


  # The following function sets up the payload for put request
  # If the Evidence/Source registry is updated the following function need to be modified to match the latest models

  def get_configuration_doc username
    # If the source registry model changes please replace value of model 
    document ="
        {
          \"Configuration\": {
            \"value\": \"#{username}\",
            \"properties\": {
              \"ConclusionCache\": {
                \"value\": \"http://#{@project_settings.gb_host}/REST/v1/grp/#{@project_settings.cache_group}/kb/#{@project_settings.cache_kb}/coll/ConclusionCache\"
              },
              \"CA2EvidenceCache\": {
                \"value\": \"http://#{@project_settings.gb_host}/REST/v1/grp/#{@project_settings.cache_group}/kb/#{@project_settings.cache_kb}/coll/EvidenceCache\"
              },
              \"EvidenceSource\": {
                \"value\": \"http://#{@project_settings.gb_host}/REST/v1/grp/#{username}/kb/#{username}/coll/SourceRegistry\"
              },
              \"GeneSummary\": {
                \"value\": \"http://#{@project_settings.gb_host}/REST/v1/grp/#{username}/kb/#{username}/coll/GeneSummary\"
              }
            }
          }
        }
      "
      return JSON.parse(document)
  end

  def get_evidence_model_json
    # If the source registry model changes please replace value of model 
    model='{
              "required": true,
              "name": "Allele evidence",
              "domain": "autoID(CLI,uniqAlphaNum,EV)",
              "unique": true,
              "identifier": true,
              "properties": [
                {
                  "required": true,
                  "name": "Subject",
                  "domain": "url",
                  "index": true,
                  "unique": true,
                  "properties": [
                    {
                      "required": true,
                      "name": "Phenotype",
                      "domain": "string"
                    },
                    {
                      "required": true,
                      "name": "Mode of inheritance",
                      "default": "Unknown",
                      "domain": "enum(Autosomal Dominant, Autosomal Recessive, X-linked Dominant, X-linked Recessive, Mitochondrial, Multifactorial, Other, Unknown)"
                    },
                    {
                      "items": [
                        {
                          "required": true,
                          "name": "Evidence Tag",
                          "category": true,
                          "domain": "autoID(EV,uniqAlphaNum,TAG)",
                          "index": true,
                          "unique": true,
                          "identifier": true,
                          "properties": [
                            {
                              "name": "Tag",
                              "category": true,
                              "default": "CHOOSE_ONE",
                              "domain": "enum(CHOOSE_ONE,PVS1, PS1, PS2, PS3, PS4, PM1, PM2, PM3, PM4, PM5, PM6, PP1, PP2, PP3, PP4, PP5, BP1, BP2, BP3, BP4, BP5, BP6, BP7, BS1, BS2, BS3, BS4, BA1, BS1-Supporting, BS2-Supporting, BP1-Strong, BP3-Strong, BP4-Strong, BP7-Strong, BS3-Supporting, BS4-Supporting, BP2-Strong, BP6-Strong, BP5-Strong, PM2-Supporting, PS4-Supporting, PM4-Supporting, PM5-Supporting, PS1-Supporting, PVS1-Supporting, PM1-Supporting, PS3-Supporting, PM6-Supporting, PS2-Supporting, PM3-Supporting, PS4-Moderate, PP3-Moderate, PS1-Moderate, PVS1-Moderate, PP2-Moderate, PS3-Moderate, PP1-Moderate, PS2-Moderate, PP5-Moderate, PP4-Moderate, PM2-Strong, PP3-Strong, PM4-Strong, PM5-Strong, PVS1-Strong, PM1-Strong, PP2-Strong, PP1-Strong, PM6-Strong, PM3-Strong, PP5-Strong, PP4-Strong, PM2-Very Strong, PS4-Very Strong, PS1-Very Strong, PM4-Very Strong, PM5-Very Strong, PP3-Very Strong, PP2-Very Strong, PM1-Very Strong, PS3-Very Strong, PP1-Very Strong, PM6-Very Strong, PS2-Very Strong, PM3-Very Strong, PP5-Very Strong, PP4-Very Strong)",
                              "properties": [
                                {
                                  "required": true,
                                  "name": "Status",
                                  "default": "On",
                                  "domain": "enum(On, Off)"
                                },
                                {
                                  "name": "Summary",
                                  "domain": "string"
                                },
                                {
                                  "required": true,
                                  "name": "Pathogenicity",
                                  "default": "CHOOSE_ONE",
                                  "domain": "enum(CHOOSE_ONE, Pathogenic, Benign)"
                                },
                                {
                                  "required": true,
                                  "name": "Strength",
                                  "default": "CHOOSE_ONE",
                                  "domain": "enum(CHOOSE_ONE, Strong, Very Strong, Moderate, Supporting, Stand Alone)"
                                },
                                {
                                  "required": true,
                                  "name": "Type",
                                  "default": "CHOOSE_ONE",
                                  "domain": "enum(CHOOSE_ONE, Computational And Predictive Data, Functional Data, Population Data, Allelic Data, De novo Data, Segregation Data, Other Data, Other Database)"
                                },
                                {
                                  "items": [
                                    {
                                      "required": true,
                                      "name": "Link",
                                      "domain": "url",
                                      "index": true,
                                      "unique": true,
                                      "identifier": true,
                                      "properties": [
                                        {
                                          "name": "Comment",
                                          "domain": "string"
                                        },
                                        {
                                          "name": "Link Code",
                                          "default": "Unknown",
                                          "domain": "enum(Supports, Disputes, Unknown)"
                                        }
                                      ]
                                    }
                                  ],
                                  "name": "Links",
                                  "domain": "numItems"
                                }
                              ]
                            }
                          ]
                        }
                      ],
                      "name": "Evidence Tags",
                      "domain": "numItems"
                    },
                    {
                      "name": "FinalCall",
                      "default": "Undetermined",
                      "index": true,
                      "description": "Final assertion/call made by the reasoner"
                    },
                    {
                      "name": "Type",
                      "default": "ACMG"
                    }
                  ]
                }
              ]
            }'
      return JSON.parse(model)
  end

  def get_questionnair_doc
    # If the source registry model changes please replace value of model 
    document ='{
         "data": {
           "Questionnaire": {
             "value": "newEviEvidence1Evidence",
             "properties": {
               "Coll": {
                 "value": "Evidence"
               },
               "Sections": {
                 "items": [
                   {
                     "SectionID": {
                       "value": "SEC1",
                       "properties": {
                         "Text": {
                           "value": "Key properties of the subject"
                         },
                         "Questions": {
                           "items": [
                             {
                               "QuestionID": {
                                 "value": "QUE1",
                                 "properties": {
                                   "Question": {
                                     "value": "What is the Evidence document ID?",
                                     "properties": {
                                       "PropPath": {
                                         "value": "",
                                         "properties": {
                                           "Domain": {
                                             "value": "autoID(CLI,uniqAlphaNum,EV)",
                                             "properties": {
                                             }
                                           }
                                         }
                                       }
                                     }
                                   }
                                 }
                               }
                             },
                             {
                               "QuestionID": {
                                 "value": "QUE2",
                                 "properties": {
                                   "Question": {
                                     "value": "The Evidence requires a valid subject url",
                                     "properties": {
                                       "PropPath": {
                                         "value": "Subject",
                                         "properties": {
                                           "Domain": {
                                             "value": "url",
                                             "properties": {
                                             }
                                           }
                                         }
                                       }
                                     }
                                   }
                                 }
                               }
                             },
                             {
                               "QuestionID": {
                                 "value": "QUE3",
                                 "properties": {
                                   "Question": {
                                     "value": "Evidence will be provided for which condition?",
                                     "properties": {
                                       "PropPath": {
                                         "value": "Subject.Phenotype",
                                         "properties": {
                                           "Domain": {
                                             "value": "string",
                                             "properties": {
                                             }
                                           }
                                         }
                                       }
                                     }
                                   }
                                 }
                               }
                             },
                             {
                               "QuestionID": {
                                 "value": "QUE4",
                                 "properties": {
                                   "Question": {
                                     "value": "What is the Mode of Inheritance?",
                                     "properties": {
                                       "PropPath": {
                                         "value": "Subject.Mode of inheritance",
                                         "properties": {
                                           "Domain": {
                                             "value": "enum(Autosomal Dominant,Autosomal Recessive,X-linked Dominant,X-linked Recessive,Mitochondrial,Multifactorial,Other,Unknown)",
                                             "properties": {
                                             }
                                           }
                                         }
                                       }
                                     }
                                   }
                                 }
                               }
                             }
                           ],
                           "value": null
                         },
                         "Template": {
                           "value": "newEviTempEvidence1Evidence"
                         },
                         "Type": {
                           "value": "modifyProp"
                         }
                       }
                     }
                   }
                 ],
                 "value": null
               }
             }
           }
         },
         "status": {
           "msg": "OK",
           "statusCode": "OK"
         }
       }
      '
      return JSON.parse(document)
  end

  def get_source_registry_doc_json username
    # If the source registry document changes please replace value of document
    document="
     {
       \"SourceRegistry\": {
         \"value\": \"user_registry\",
         \"properties\": {
           \"EvidenceSources\": {
             \"value\": 1,
             \"items\": [
               {
                 \"EvidenceSource\": {
                   \"value\": \"#{username}\",
                   \"properties\": {
                     \"Evidence\": {
                       \"value\": \"http://#{@project_settings.gb_host}/REST/v1/grp/#{username}/kb/#{username}/coll/Evidence\"
                     },
                     \"Tags\": {
                       \"value\": \"http://#{@project_settings.gb_host}#{@project_settings.acmg_allowed_tags_rest}\"
                     },
                     \"Transform\": {
                       \"value\": \"http://#{@project_settings.gb_host}#{@project_settings.acmg_transformation_rest}\"
                     },
                     \"Questionnaire\": {
                       \"value\": \"http://#{@project_settings.gb_host}/REST/v1/grp/#{username}/kb/#{username}/coll/Evidence/quest/newEviEvidence1Evidence\"
                     },
                     \"Guidelines\": {
                       \"value\": 1,
                       \"items\": [
                         {
                           \"Guideline\": {
                             \"value\": \"http://#{@project_settings.gb_host}#{@project_settings.acmg_guideline_rest}\",
                             \"properties\": {
                               \"type\": {
                                 \"value\": \"ACMG\"
                               },
                               \"displayName\": {
                                 \"value\": \"#{username}\"
                               }
                             }
                           }
                         }
                       ]
                     }
                   }
                 }
               }
             ]
           }
         }
       }
     }
    "

    JSON.parse(document)

  end

  def get_source_registry_model_json
    # If the source registry model changes please replace value of model 
    model='
        {
          "identifier": true,
          "properties": [
            {
              "items": [
                {
                  "identifier": true,
                  "properties": [
                    {
                      "required": true,
                      "description": "where is the evidence collection ?",
                      "name": "Evidence",
                      "domain": "url"
                    },
                    {
                      "required": true,
                      "description": "where to find allowed tags for this source",
                      "name": "Tags",
                      "domain": "url"
                    },
                    {
                      "required": true,
                      "description": "where to find transform for this source",
                      "name": "Transform",
                      "domain": "url"
                    },
                    {
                      "required": true,
                      "description": "where to find the questionnaire for this source",
                      "name": "Questionnaire",
                      "domain": "url"
                    },
                    {
                      "items": [
                        {
                          "identifier": true,
                          "properties": [
                            {
                              "required": true,
                              "description": "Is the assertions generated by rules ACMG based?",
                              "default": "ACMG",
                              "name": "type",
                              "domain": "enum(ACMG, Other)"
                            },
                            {
                              "required": true,
                              "description": "what should be the display name when shown at calculator interface",
                              "name": "displayName",
                              "domain": "string"
                            },
                            {
                              "description": "Genboree KB UI link",
                              "name": "redmineProject",
                              "domain": "url"
                            }
                          ],
                          "index": true,
                          "required": true,
                          "description": "URL to guideline",
                          "unique": true,
                          "name": "Guideline",
                          "domain": "url"
                        }
                      ],
                      "description": "if different set of rules are used to make assertions then how manu rules are there?",
                      "name": "Guidelines",
                      "domain": "numItems"
                    }
                  ],
                  "index": true,
                  "required": true,
                  "description": "Name/Identifier of the source",
                  "unique": true,
                  "name": "EvidenceSource",
                  "domain": "string"
                }
              ],
              "description": "Evidence source is list and this stores current number of sources",
              "name": "EvidenceSources",
              "domain": "numItems"
            }
          ],
          "index": true,
          "required": true,
          "description": "Identifier for this document",
          "unique": true,
          "name": "SourceRegistry",
          "domain": "string"
        }'
      return JSON.parse(model)
  end

  def get_template_doc
    # If the source registry model changes please replace value of model 
    document ='
      {
        "data": {
          "id": {
            "value": "newEviTempEvidence1Evidence",
            "properties": {
              "coll": {
                "value": "Evidence"
              },
              "root": {
                "value": "Allele evidence"
              },
              "template": {
                "value": {
                  "properties": {
                    "Subject": {
                      "value": "http://clingenkb.org/canonical_allele/CA046823540661565",
                      "properties": {
                        "Phenotype": {
                          "value": ""
                        },
                        "Mode of inheritance": {
                          "value": "Unknown"
                        }
                      }
                    }
                  }
                }
              },
              "internal": {
                "value": false
              }
            }
          }
        },
        "status": {
          "msg": "OK",
          "statusCode": "OK"
        }
      }'
      return JSON.parse(document)
  end

  def get_gene_summary_model
    model = '{
       "name": "Gene",
       "domain": "string",
       "unique": true,
       "identifier": true,
       "properties": [
         {
           "name": "ReasonerCalls",
           "items": [
             {
               "name": "ReasonerCall",
               "index": true,
               "unique": true,
               "identifier": true,
               "properties": [
                 {
                   "name": "CAIDs",
                   "items": [
                     {
                       "name": "CAID",
                       "index": true,
                       "identifier": true
                     }
                   ],
                   "domain": "numItems"
                 },
                 {
                   "name": "Type"
                 }
               ]
             }
           ]
         }
       ]
      }'
     return JSON.parse(model)
  end

end
