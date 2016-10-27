require 'brl/util/util'
require 'brl/extensions/bson'
require 'brl/extensions/simpleDelegator'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/validators/docValidator'
require 'brl/genboree/kb/producers/abstractNestedTabbedProducer'
require 'brl/genboree/kb/propSelector'

module BRL ; module Genboree ; module KB ; module Producers
  class NestedTabbedDocProducer < AbstractNestedTabbedProducer

    # The core columns associated with a nested tabbed doc are "property" and "value"
    COLUMNS       = [ 'property', 'value' ]
    # The column associated with our property name is "property"
    PROP_NAME_COL = 'property'

    attr_accessor :model, :relaxedRootValidation

    def initialize(model, *args)
      super()
      @model = model
      @modelsHelper = BRL::Genboree::KB::Helpers::ModelsHelper.new(nil)
    end

    # ------------------------------------------------------------------
    # ABSTRACT INTERFACE METHODS - to be implemented in sub-classes
    # ------------------------------------------------------------------

    # This method returns the current doc
    # @param [KbDoc] doc current doc
    # @return [KbDoc] current doc
    def getSubDoc(doc)
      return doc
    end

    # This method creates a validator for validating a document against our model
    # @return [DocValidator] validator for checking document against model
    def makeValidator()
      # We create a DocValidator (unless one has already been created) and return it
      @validator ||= BRL::Genboree::KB::Validators::DocValidator.new()
      @validator.relaxedRootValidation = @relaxedRootValidation
      return @validator
    end

    # This method validates a given document against our model
    # @param [KbDoc] document that will be checked
    # @return [boolean] boolean that tells us whether doc is valid (true if it is, false if it isn't)
    def validateDoc(doc)
      # Unless the doc has already been checked and is valid (or if we overrode @docValid because we don't want to use a model :)), we proceed
      unless(@docValid)
        # We create a validator to check our document
        makeValidator()
        # We check to see whether our doc is valid against @model
        valid = @validator.validateDoc(doc, @model)
        # If modelValid is true--or :CONTENT_NEEDED (??), then we set @docValid to be true
        if(valid)
          @docValid = true
        # Otherwise, we set @docValid to be false
        else
          @docValid = false
        end
      end
      # Finally, we return @docValid (to tell us whether doc is valid or not)
      return @docValid
    end

    # This method converts our columns (found in @columns) into a header line for our nested tabbed doc
    # @return [String] header line for nested tabbed doc
    def header()
      # We add a # in front of the line if @headerIsComment is true and then list our columns tab-separated in a single line
      # This will be our header line
      return "#{@headerIsComment ? '#' : ''}#{@columns.join("\t")}"
    end

    # This method will create the tabbed line for a particular property / value pair (held in rec)
    # @return [String] tabbed line containing particular property / value pair
    def dump(subDoc, propName, nesting)
      # rec will initially contain the property name (with no nesting) and no value (nil)
      rec = [ propName, nil ]
      # We go into our sub document and retrieve the value object associated with our property name
      valObj = subDoc[propName]
      # If valObj exists, we proceed.
      if(valObj)
        # We grab the value associated with that value object.
        value = valObj['value']
        # If the value is not nil, then we proceed.
        if(!value.nil?)
          # Value could be boolean type
          if(value == false)
            value = 'false'
          elsif(value == true)
            value = 'true'
          # Otherwise, we don't have to do anything (value = value)
          else
            if(value.class == String)
              value.gsub!("\t", "\\t")
              value.gsub!("\n", "\\n")
            end
          end
          # Finally, we set the previously nil element of our rec array to be the value we retrieved.
          rec[1] = value
        end
      end
      # We add nesting using the addNesting method, then transform our rec array into tabbed format and return our transformed line.
      rec = addNesting(rec, nesting)
      retVal = rec.join("\t")
      return retVal
    end

    # This method will create the nested tabbed doc (recursively) by visiting each sub document and dumping contents of each property into own tabbed line
    # @param [Hash or Array] subDoc current sub document
    # @param [String] nesting current nesting
    # @param [String] previousPath the previous path (used for updating nesting accurately)
    # @return [String] converted document
    def visit(subDoc, nesting=nil, previousPath=nil)
      previousPath = nil unless(previousPath)
      propDef = nil
      # If subDoc acts as a hash, we proceed (otherwise, we can't!)
      if(subDoc.acts_as?(Hash))
        # If subDoc responds to the method :ordered_keys, then we will grab the ORDERED keys from the hash.
        # I think this only works with BSON::OrderedHash, so not regular hash.
        if(subDoc.respond_to?(:ordered_keys))
          subDocKeys = subDoc.ordered_keys
        # Otherwise, we just have a regular hash, so we just grab its (unordered) keys.
        else
          subDocKeys = subDoc.keys
          # If we have unordered keys, we cannot guarantee properties will appear in the same order from one production to the next.
          # This is a problem because we want our document to come out the same way every single time!
          if(nesting.nil?)
            $stderr.puts "WARNING: The doc object does not support maintenance of hash-key order. Cannot guarantee properties will appear in the same order from one production to the next. (Underlying class is likely a Hash instead of, say, a BSON::OrderedHash)"
          end
        end
        # We traverse each of the keys gathered above for our sub document - each is a sub property of that document!
        subDocKeys.each { |subProp|
          # Skip sub property if it's a Mongo ID (messes up bulkUpload in AbstractHelper)
          next if(subProp == '_id')
          # We grab the value object associated with the current sub property
          valObj = subDoc[subProp]
          # We update the nesting for the sub property (note that, for root property, nesting = nil)
          if(@model)
            if(previousPath)
              propDef = @modelsHelper.findPropDef("#{previousPath}.#{subProp}", @model)
              newPreviousPath = "#{previousPath}.#{subProp}"
            else
              propDef = @modelsHelper.findPropDef(subProp, @model)
              newPreviousPath = subProp
            end
          end
          newNesting = updateNesting(valObj, nesting, propDef)
          # We create a tabbed string for the current record (property and value)
          recStr = dump(subDoc, subProp, newNesting)
          # If we managed to create a tabbed string for the current record (it's not empty!), we proceed.
          if(recStr)
            # If a block is given to our visit method, we yield the tabbed string to the block.
            if(block_given?)
              yield recStr
            # Otherwise, we just add it to our @result array.
            else
              @result << recStr
            end
          end
          # Now, we've created the result string for the current sub property (with proper nesting) and added it to our @result array.
          # Next, we need to try to visit sub-props / sub-items, recursively, using our visit method.
          # We traverse each sub property key (here, "properties" and "items").
          self.class::SUBPROP_KEYS.each_key { |subpropField|
            # We grab the nesting character associated with the current sub property key.
            nestChar = self.class::SUBPROP_KEYS[subpropField]
            # We then check to see whether our value object contains the current sub property key.
            if(valObj.key?(subpropField))
              # If it does, then we grab the content associated with that sub property key and set it equal to subPropContent.
              # This will be fed into our visit method, recursively, as our new sub document.
              subPropContent = valObj[subpropField]
              if(block_given?) # Create yield-chain back to calling method's block
                visit(subPropContent, newNesting, newPreviousPath) { |line| yield line }
              else
                # Otherwise, just feed subPropContent into our visit method with the new nesting (found in newNesting)
                visit(subPropContent, newNesting, newPreviousPath)
              end
            end
          }
        }
      # Otherwise, if our sub document acts as an array instead of a hash (items!), we proceed down this branch.
      elsif(subDoc.acts_as?(Array))
        if(block_given?)
          subDoc.each { |subDocElem| # Create yield-chain back to calling method's block
            visit(subDocElem, nesting, previousPath) { |line| yield line }
          }
        else
          subDoc.each { |subDocElem|
            visit(subDocElem, nesting, previousPath)
          }
        end
      end
      # At the end of our "visit", we return @result with new, additional elements consisting of tabbed lines (property / value pairs).
      return @result
    end

    # This method will process multiple docs into a more condensed nested tabbed format (one column for each doc's values)
    # @param [Array] docs array of KbDocs that will be processed into one nested tabbed document
    # @return [String] nested multi-tabbed version of docs
    def processMultipleDocs(docs)
      if(@model == nil)
        @errMsg = "You did not supply a model! You need to supply a model in order to produce a multi-column tabbed file."
        raise @errMsg
      end
      # totalVals will hold the total number of documents we'll be traversing
      totalVals = docs.size
      # If totalVals is 0, that means there are no documents to process.
      if(totalVals == 0)
        finalDoc = "\nThere are no documents in this collection."
      else
        # index will keep track of which document we're currently traversing
        index = 0
        # megaDoc will be a "mega document" that will hold the values of all the different individual documents
        megaDoc = BRL::Genboree::KB::KbDoc.new()
        # producer will be used to generate a full path tabbed document for each KbDoc
        producer = BRL::Genboree::KB::Producers::FullPathTabbedDocProducer.new(@model)
        # modelProducer will be used to generate a full path tabbed model for the kbDocs
        modelProducer = BRL::Genboree::KB::Producers::FullPathTabbedModelProducer.new(@model)
        fullPathedModel = modelProducer.produce(@model, true).join("\n")
        # We will also generate a nested pathed model for fixing #MISSING# values in finalDoc
        modelProducer = BRL::Genboree::KB::Producers::NestedTabbedModelProducer.new(@model)
        nestedPathedModel = modelProducer.produce(@model, true).join("\n")
        # Connect full paths to domains for easy access while building megaDoc
        domainHashFullPath = {}
        # We'll grab the respective indices of property path and domain for the model
        # These same indices will be used for nested pathed model (doesn't matter if model is nested or full, columns will be in same order!)
        columnNames = fullPathedModel.lines.first().chomp.split("\t")
        pathIdx = columnNames.index("#name")
        domainIdx = columnNames.index("domain")
        fullPathedModel.each_line { |line|
          next if(line =~ /^\s*#/ or line !~ /\S/)
          tokens = line.split("\t")
          path = tokens[pathIdx]
          domain = tokens[domainIdx]
          domainHashFullPath[path] = domain
        }
        # Connect nested paths to domains for easy access while fixing #MISSING# values for finalDoc
        domainHashNestedPath = {}
        nestedPathedModel.each_line { |line|
          next if(line =~ /^\s*#/ or line !~ /\S/)
          tokens = line.split("\t")
          path = tokens[pathIdx]
          domain = tokens[domainIdx]
          domainHashNestedPath[path] = domain
        }
        # We traverse every document, one at a time
        index = 0
        docs.each { |doc|
          # We create a full pathed doc for each doc
          fullPathedDoc = producer.produce(doc).join("\n")
          # Grab respective indices for property path and value for current doc
          columnNames = fullPathedDoc.lines.first().chomp.split("\t")
          pathDocIdx = columnNames.index("#property")
          valueIdx = columnNames.index("value")
          # We traverse each line of our full pathed document
          fullPathedDoc.each_line { |line|
            # Create PropSelector object on megaDoc - this will be useful for checking whether different property paths from our individual docs
            # exist in megaDoc
            megaDocPropSelector = BRL::Genboree::KB::PropSelector.new(megaDoc)
            # We skip to the next line of our document if it's commented (begins with a #) or is empty
            next if(line =~ /^\s*#/ or line !~ /\S/)
            # We divide the current line into individual tokens
            tokens = line.split("\t")
            # Our property path will be the first token
            path = tokens[pathDocIdx]
            # Our value associated with the property path will be the second token
            value = ""
            unless(tokens[valueIdx].nil?)
              value = tokens[valueIdx].chomp
            end
            # If the value is blank, then we need to make sure that we record that this value is PRESENT (and blank) in our multi-doc
            if(value=="")
              # The model does not have [0], [1], etc. to refer to a given item, so we remove indices to get the shortened path
              shortenedPath = path.gsub(/\.\[\d+\]/, "")
              # Find domain associated with this path
              currentDomain = domainHashFullPath[shortenedPath]
              # value is set to #FOUND# if currentDomain is one of the acceptable domains
              if(currentDomain == "string" or currentDomain == "[valueless]" or currentDomain.include?("regexp") or currentDomain == "url" or currentDomain == "fileUrl" or currentDomain.include?("autoID"))
                value = "#FOUND#"
              end
            end
            # Let's use PropSelector to see whether our current path exists / what value is associated with it
            begin
              checkForPath = megaDocPropSelector.getMultiPropValues(path)
            rescue ArgumentError => aerr
            end
            # exit code associated with error will tell us what we need to do to our mega doc
            exitCode = megaDocPropSelector.exitCode
            # We will use the exit code associated with PropSelector to figure out whether our current path exists
            # PATH DOESN'T EXIST AT ALL AND IT'S A PROPERTY
            if(exitCode == 35 or exitCode == 30 or exitCode == 33)
              # Create new Array to hold all values associated with different documents
              newVals = Array.new(docs.size)
              # Set value in array at appropriate index to value in doc
              newVals[index] = value
              # Update value at path to be newVals
              megaDoc.setPropVal(path, newVals)
            # ITEM LIST DOESN'T YET EXIST OR PATH POINTS TO ELEMENT THAT DOESN'T YET EXIST IN ITEM LIST
            elsif(exitCode == 40 or exitCode == 37)
              # Create new Array to hold all values associated with different documents
              newVals = Array.new(docs.size)
              # Set value in array at appropriate index to value in doc
              newVals[index] = value
              # Add item
              itemHash = {path[path.rindex(".") + 1..-1]=>{"value"=>newVals, "properties"=>{}}}
              shortenedPath = path[0...(path.rindex("[") - 1)]
              megaDoc.addPropItem(shortenedPath, itemHash)
            # PATH ALREADY EXISTS
            elsif(exitCode == 0)
              checkForPath[index] = value
              megaDoc.setPropVal(path, checkForPath)
            else
              @errMsg = "Didn't handle a situation properly for our doc! The exit code #{exitCode} occurred."
              raise @errMsg
            end
          }
          # We increment index each time so that the appropriate element in the value arrays will be updated
          index += 1
        }
        # Create multi-column tabbed document
        finalDoc = produce(megaDoc)
        # Earlier, we put "#FOUND#" for blank values (if the domain was appropriate).  This is because we couldn't update "#MISSING#" for fields actively while filling out the document.
        # We will now replace blank values with "#MISSING#" (and "#FOUND#" with blank values).
        # missingFlag is an array that will tell us for a particular doc whether a previous, parent value had #MISSING#.
        # If a parent has the value of #MISSING#, then we want to ignore putting any #MISSING# values for children (it's not necessary, since all children of #MISSING# parent are ignored by converter)
        missingFlag = [false] * finalDoc[1].split("\t").size
        # We also want to record the depth for which a parent has #MISSING# - that way, we can keep track of what its children are
        depthFlag = [0] * finalDoc[1].split("\t").size
        # We use map! to traverse each element of our finalDoc array (created from produce method) - each element corresponds to a single line of our multitabbed file
        finalDoc.map! { |element|
          # We go to the next element if it begins with a "#" or doesn't have any non-blank chars
          next if(element =~ /^\s*#/ or element !~ /\S/)
          # We split the current element into individual tokens
          tokens = element.split("\t")
          # Because split deleted the tab characters at the end of the string (Example: "\tblah\t\t" will become ["", "blah"]), we need to put associated "" elements back into tokens
          index = -1
          while(element[index].chr == "\t")
            tokens.push("")
            index = index - 1
          end
          # We grab the property path associated with the current element
          path = tokens[0]
          # We also grab the nesting associated with the current element, and calculate the length of that nesting
          nesting = tokens[0].split()[0]
          nestingLength = tokens[0].split()[0].length
          # We cut off any item indices because we want to check the current path against the model (which does not contain item indices)
          shortenedPath = path.gsub(/\.\[\d+\]/, "")
          # We grab the domain associated with the current path
          currentDomain = domainHashNestedPath[shortenedPath]
          # If the currentDomain is one which requires the "#MISSING#" clarification, we proceed.
          #puts "path: #{path}"
          #puts "nesting: #{nesting}"
          #puts "nestingLength: #{nestingLength}"
          #puts "shortenedPath: #{shortenedPath}"
          #puts "currentDomain: #{currentDomain}"
          if(currentDomain == "string" or currentDomain == "[valueless]" or currentDomain.include?("regexp") or currentDomain == "url" or currentDomain == "fileUrl" or currentDomain.include?("autoID"))
            # We'll go ahead and traverse all indices present in our tokens array (contains property and all values as separate elements)
            tokens.each_index { |currentIndex|
              # We skip the property
              next if(index == 0)
              # If the missing flag is currently on and the nesting length of the current property is equal to the nesting length of the #MISSING# property, then we proceed.
              if(missingFlag[currentIndex] and nestingLength == depthFlag[currentIndex])
                # If the current property is just another item in an item list, then it's missing as well so we set it equal to #MISSING#
                if(nestingLength >= 2 and nesting[-2].chr == "*")
                  tokens[currentIndex] = "#MISSING#"
                # Otherwise, it's a new property so we set our missing flag to false and reset our depth flag
                else
                  missingFlag[currentIndex] = false
                  depthFlag[currentIndex] = 0
                end
              end
              # If the missing flag is currently on and the nesting length of the current property is less than the nesting length of the #MISSING# property,
              # then we set our missing flag to false and reset our depth flag
              if(missingFlag[currentIndex] and nestingLength < depthFlag[currentIndex])
                missingFlag[currentIndex] = false
                depthFlag[currentIndex] = 0
              end
              # If the current value is empty and missing flag is false, that means we need to insert #MISSING# and update our missing flag / depth flag
              if(tokens[currentIndex] == "" and missingFlag[currentIndex] == false)
                tokens[currentIndex] = "#MISSING#"
                missingFlag[currentIndex] = true
                depthFlag[currentIndex] = nestingLength
              end
              # If we find #FOUND#, we need to remove it
              if(tokens[currentIndex] == "#FOUND#")
                tokens[currentIndex] = ""
              end
            }
          end
          # After we are done fixing the line, we update element by joining tokens with "\t"
          element = tokens.join("\t")
          # Add domain value to end of line
          element << "\t#{currentDomain}"
        }
        # Because we deleted the first line of finalDoc above in our map!, we set it again (with correct number of value columns and domain column)
        finalDoc[0] = "#property\t" << "value\t" * (totalVals - 1) << "value" << "\tdomain"
        # Finally, we join finalDoc so that it's a string
        finalDoc = finalDoc.join("\n")
      end
      # We return finalDoc as our multi-column tabbed string
      return finalDoc
    end
  end # class NestedTabbedModelProducer < AbstractNestedTabbedProducer
end ; end ; end ; end
