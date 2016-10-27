require 'brl/genboree/rest/data/entity'

module BRL; module Genboree; module REST; module Data
class BatchEntity < AbstractEntity
  SIMPLE_FIELD_NAMES = ["method", "url", "payload", "response"]
  SIMPLE_FIELD_VALUES = [nil, nil, "", ""]
  RESOURCE_TYPE = :BATCH
  FORMATS = [:JSON]

  attr_accessor :method
  attr_accessor :url
  attr_accessor :payload
  attr_accessor :response

  def initialize(doRefs=false, method=nil, url=nil, payload="", response="")
    super(doRefs)
    @method = method
    @url = url
    @payload = payload
    @response = response
  end

  def getFormatableDataStruct()
    retVal = {
      "method" => @method,
      "url" => @url,
      "payload" => @payload,
      "response" => @response
    }
    retVal["refs"] = @refs if(@refs)
    retVal = wrap(retVal) if(@doWrap)
    return retVal
  end
end

class BatchEntityList < BRL::Genboree::REST::Data::EntityList
  RESOURCE_TYPE = :BATCH_LIST
  FORMATS = BatchEntity::FORMATS
  ELEMENT_CLASS = BatchEntity
end
end; end; end; end
