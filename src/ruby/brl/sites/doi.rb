require 'brl/sites/abstractSite'
module BRL; module Sites

  # Functions for resolving DOIs and obtaining metadata for registered DOIs
  class DOI < AbstractSite
    DOI_RESOLVE_SERV = "http://dx.doi.org"
    DOI_META_SERV = "https://api.crossref.org/v1/works"

    # Generate URL for DOI resolution service
    # @param [String] doi
    # @return [String] url where GET requests will resolve the DOI
    #   e.g. http://dx.doi.org/10.1093/nar/gkv1275
    def self.resolverUrl(doi)
      "#{DOI_RESOLVE_SERV}/#{doi}"
    end

    # Generate URL for DOI metadata service
    # @param [String] doi
    # @return [String] url where GET requests will yield metadata for DOI
    #   e.g. https://api.crossref.org/v1/works/http://dx.doi.org/10.1093/nar/gkv1275
    def self.metaUrl(doi)
      "#{DOI_META_SERV}/#{resolverUrl(doi)}"
    end
  end
end; end
