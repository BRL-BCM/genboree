#!/usr/bin/env ruby



module BRL ; module Genboree ; module KB ; module Questions 
  class DocBuildHelper

    attr_reader :root
    attr_reader :buildErrors
    

    def initialize(kbDatabase, collName, docOrTemplate={})
        @root = docOrTemplate
        @collectionName = collName
        @buildErrors = []
        @mh = kbDatabase.modelsHelper()
    end

    def add(path)
        retVal = nil
        begin
           cleanPath = path[:path].join(".")
           cleanPath = cleanPath.gsub(/(\.(\[.*?\]))/, "") 
           docPath = @mh.modelPath2DocPath(cleanPath, @collectionName)
           $stderr.debugPuts(__FILE__, __method__, "DEBUG", "DOCPATH::: #{docPath} ")
           # This version of the builder addsItem as the first Item only.
           pathValue = path[:value].is_a?(Array) ? path[:value].first : path[:value] 
           buildDoc(@root, docPath.split(".").dup, pathValue) if(docPath)
    
           return @root
        rescue => err
          @buildErrors << "Failed to get the document path from the path #{path[:path].join(".")}. Details #{err}"
          return retVal
        end
    end

    private

    
    def buildDoc(docObj, docPath, value)
        #r_add(h[propName], h[propName]['properties'], path, value)
        return if(docPath.empty?)
        while(!docPath.empty?)
          propName = docPath.shift
          field = docPath.shift
          dataEl = docObj.find(){|hh, kk| hh == propName} rescue nil
          if(field == "value")
            docObj[propName] = {} unless(dataEl)
            docObj[propName]['value'] = value
            return 
          elsif(field == 'properties')
            docObj[propName] = {} unless(dataEl)
            docObj[propName][field] = {} if(docObj.key?(propName) and !docObj[propName].key?(field))
            buildDoc(docObj[propName][field], docPath, value)
          elsif(field == 'items') # this is not right has to be rewritten for items. 
            docObj[propName] = {} unless(dataEl)
            (docObj[propName][field] = [] and docObj[propName][field] << {}) if(docObj.key?(propName) and !docObj[propName].key?(field))
            buildDoc(docObj[propName][field].first, docPath, value)
          else
            @buildErrors << "INVAID_FIELD: Field : #{field.inspect} for the path #{docPath.inspect} is not valid!"
            return nil
          end
        end
    end

  end

end; end; end; end
