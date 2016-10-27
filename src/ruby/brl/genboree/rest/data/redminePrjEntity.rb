require 'brl/genboree/rest/data/entity'

module BRL; module Genboree; module REST; module Data
class RedminePrjEntity < AbstractEntity
  RESOURCE_TYPE = :RedmineProject
  REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"
  SIMPLE_FIELD_NAMES = ["url", "projectId"]

  attr_accessor :url
  attr_accessor :projectId

  def initialize(doRefs=true, url='', projectId='')
    super(doRefs)
    update(url, projectId)
  end

  def update(url, projectId)
    @url = url
    @projectId = projectId
  end

  def getFormatableDataStruct()
    data =  {
      "url" => @url,
      "projectId" => @projectId
    }
    data['refs'] = @refs if(@refs)

    retVal = self.wrap(data)  # Wrap the data content in standard Genboree JSON envelope
    return retVal
  end
end

class RedminePrjEntityList < EntityList
  RESOURCE_TYPE = :RedmineProjectList
  REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}" 
  ELEMENT_CLASS = RedminePrjEntity
end
end; end; end; end
