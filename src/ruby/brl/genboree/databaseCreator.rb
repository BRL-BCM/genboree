#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED LIBRARIES
# #############################################################################

module BRL ; module Genboree

  # Wrapper class for the Java utility for creating Genboree databases
  class DatabaseCreator
    attr_accessor :userId, :groupId, :databaseName

    # [+userId+]        The userId of the user that's creating the database
    # [+groupId+]       The groupId of the group that the database will be added to
    # [+databaseName+]  The name of the new database that will be created
    def initialize(userId, groupId, databaseName)
      @userId, @groupId, @databaseName = userId, groupId, databaseName
    end

    # Creates an empty database, i.e. Not from a template
    #
    # [+desciption+]  The description of the database (refseq.description)
    # [+species+]     The species (refseq.refseq_species)
    # [+version+]     The version (refseq.refseq_version)
    # [+returns+]     Exit status of the DatabaseCreator command
    def createEmptyDb(description='', version='', species='')
      cmd = "java -classpath $CLASSPATH org.genboree.upload.DatabaseCreator -u #{@userId} -g #{@groupId} -n \"#{@databaseName}\" -d \"#{description}\" -e \"#{species}\" -v \"#{version}\""
      cmdOut = `#{cmd}`
      # Check exit status
      cmdExitStatus = ($? ? $?.exitstatus : nil)
      return cmdExitStatus
    end

    # Creates a database from a template
    # description, species and version will default to the template values
    #
    # [+templateId+]  The Id of the template genome that will be used to create the database (genomeTemplate.genomeTemplate_id)
    # [+returns+]     Exit status of the DatabaseCreator command
    def createDbFromTemplate(templateId, version=nil, species=nil, description=nil)
      cmd = "java -classpath #{ENV['CLASSPATH']} org.genboree.upload.DatabaseCreator -u #{@userId} -g #{@groupId} -t #{templateId} -n \"#{@databaseName}\"  "
      cmd << " -v \"#{version}\" " if(version)
      cmd << " -e \"#{species}\" " if(species)
      cmd << " -d \"#{description}\" " if(description)
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Launching cmd: #{cmd}")
      cmdOut = `#{cmd}`
      # Check exit status
      cmdExitStatus = ($? ? $?.exitstatus : nil)
      return cmdExitStatus
    end

  end # class DatabaseCreator
end ; end # module BRL ; module Genboree
