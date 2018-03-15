module BRL; module Genboree; module Evb

  # Functions for migrating all documents in a collection
  class CollMigrator

    # @param [BRL::Genboree::Evb::DocMigrator] docMigrator
    # @param [Hash] templateForm
    # @param [Hash] templateTo
    # @raise [Errno::*] system errors associated with directory creation attempts
    def migrateColl(docMigrator, mappingDoc, migrationDoc, additionDoc, templateFrom, templateTo)
      reqFields = [:host, :grp, :kb, :coll]
      Util.errIfMissingKey(__method__, templateFrom, reqFields)
      Util.errIfMissingKey(__method__, templateTo, reqFields)

      # prepare directory for generated documents, report of valid ones, and directory for 
      #   validation errors
      genDocsDir = "#{templateFrom[:coll]}_#{templateTo[:coll]}"
      begin
        FileUtils.mkdir_p(genDocsDir)
      rescue Errno.constants.map { |const| Errno.const_get(const) } => err
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Unable to create directory #{genDocsDir.inspect} due to system error")
        raise err
      end
      failFh = File.open(File.join(genDocsDir, "fail.tsv"), "w")
      reportFh = File.open(File.join(genDocsDir, "report.tsv"), "w")
      idMapFh = File.open(File.join(genDocsDir, "idMap.tsv"), "w")

      # retrieve models and documents to transform
      mah = BRL::Genboree::Evb::MigratorApiHelper.new()
      modelFrom = mah.getModel(templateFrom)
      modelTo = mah.getModel(templateTo)
      docsFrom = mah.getDocs(templateFrom)

      # prepare additions
      # @todo interface
      dataFrom = {
        :template => templateFrom,
        :model => modelFrom
      }
      dataTo = {
        :template => templateTo,
        :model => modelTo
      }

      # map from old doc
      nInvalid = 0
      docsFrom.each { |docFrom|
        docFrom = BRL::Genboree::KB::KbDoc.new(docFrom)
        docIdFrom = docFrom.getRootPropVal()
        templateFrom[:doc] = docIdFrom

        # generate document version of model to model mapping doc
        docMap = docMigrator.generateDocMap(mappingDoc, modelFrom, modelTo, docFrom)
        
        # directly copy document values according to the map
        docTo = docMigrator.applyMappingDoc(docMap, docFrom)
  
        # transform the value of specific properties
        docTo = docMigrator.applyMigrationDoc(migrationDoc, mappingDoc, docTo, dataFrom, dataTo)
  
        # add new values, finalize generated document
        docTo = docMigrator.applyAdditionDoc(docTo, additionDoc)

        # process generated doc: save it, validate it, save validation results
        docIdTo = docTo.getRootPropVal()
        idMapFh.puts [docIdFrom, docIdTo].join("\t")
        File.open(File.join(genDocsDir, docIdTo), "w") { |fh|
          fh.puts(JSON.pretty_generate(docTo))
        }
        dv = BRL::Genboree::KB::Validators::DocValidator.new()
        isValid = dv.validateDoc(docTo, modelTo)
        unless(isValid)
          nInvalid += 1
          errors = dv.buildErrorMsgs( { :propPrefix => '', :propSuffix => ' ERROR LIST: ', :errorPrefix => '', :errorSuffix => ' ; '} )
          failFh.puts([docIdTo, errors.join('')].map { |xx| xx.gsub(/[\t\n]/, ' ')}.join("\t"))
          failFh.flush
        end
        reportFh.puts([docIdTo, isValid.to_s].join("\t"))
      }
      failFh.close
      reportFh.close
      idMapFh.close

      return nInvalid
    end

    # private

    def mkdir(path)
      if(!File.exists?(path))
        # @todo mkdir fail?
        Dir.mkdir(path)
      elsif(File.directory?(path))
      else
        raise EvbError.new("Cannot mkdir #{path.inspect}")
      end
      nil
    end

    def collTemplateToString(template)
      [template[:host], template[:grp], template[:kb], template[:coll]].join("_")
    end
  end
end; end; end
