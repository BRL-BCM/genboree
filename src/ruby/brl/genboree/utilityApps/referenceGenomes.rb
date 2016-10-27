#!/usr/bin/env ruby

require 'brl/script/scriptDriver'
require 'brl/util/util'
require 'brl/db/dbrc'
require 'brl/genboree/rest/apiCaller'


# Write sub-class of BRL::Script::ScriptDriver
module BRL ; module Script
  class ReferenceGenomesManager < ScriptDriver
    # ------------------------------------------------------------------
    # SUB-CLASS INTERFACE
    # - replace values for constants and implement abstract methods
    # ------------------------------------------------------------------
    # INTERFACE: provide version string
    VERSION = "1.0"
    # INTERFACE provide *specific* command line argument info
    # - Hash of '--longName' arguments to Array of: arg type, one-char arg name, description.
    COMMAND_LINE_ARGS = {
      "--show" =>  [ :NO_ARGUMENT, "-s", "Show summary about installed genomes" ],
    #  "--threads" =>  [ :REQUIRED_ARGUMENT, "-t", "Number of threads (cores) to use" ],
      "--install" =>  [ :OPTIONAL_ARGUMENT, "-i", "Install genome with given name" ]
    }
    # INTERFACE: Provide general program description, author list (you...), and 1+ example usages.
    DESC_AND_EXAMPLES = {
      :description => "Script to install reference genomes and build their indexes.",
      :authors      => [ "Piotr Pawliczek (Piotr.Pawliczek@bcm.edu)"],
      :examples => [
        "#{File.basename(__FILE__)} -s",
        "#{File.basename(__FILE__)} -i hg19",
        "#{File.basename(__FILE__)} --help"
      ]
    }
    # ------------------------------------------------------------------
    # IMPLEMENTED INTERFACE METHODS
    # ------------------------------------------------------------------
    # run()
    #  . MUST return a numerical exitCode (20-126). Program will exit with that code. 0 means success.
    #  . Command-line args will already be parsed and checked for missing required values
    #  . @optsHash contains the command-line args, keyed by --longName
    def run() 
      validateAndProcessArgs()
      if(@mode_show)
        print_current_conf()
      end
      if(@mode_install)
        install_genome(@genome)
      end
      return EXIT_OK
    rescue StandardError => e
      puts "Program failed!"
      puts e.message
      puts e.backtrace.join("\n")
      return 20
    end
    
    # ------------------------------------------------------------------
    # SCRIPT-SPECIFIC METHODS
    # ------------------------------------------------------------------
    # - stuff needed to do actual program or drive 3rd party tools, etc
    # - repeatedly-used generic stuff is in library classes of course...
    
    def validateAndProcessArgs
      @dataTypes = [ 'raw', 'bowtie', 'bowtie2', 'BWA', 'geneSpliceJunc', 'bowtie2RoiGrp' ] # 'raw' must be first, others use files from 'raw'
      @genomes   = [ 'hg18', 'hg19' ]
      #@cores = @optsHash['--threads']
      @mode_show    = @optsHash.has_key?('--show'   )
      @mode_install = @optsHash.has_key?('--install')
      if (@mode_install)
        @genome = @optsHash['--install']
        raise "Incorrect genome name: #{@genome}" if not @genomes.include?(@genome)
      end
      if (@mode_show and @mode_install) or not (@mode_show or @mode_install)
        raise "You have to use -s or -i option (but not both at the same time). See '#{File.basename(__FILE__)} --help' for details."
      end
    end
    
    # install whole stuff for given genome
    def install_genome(genome)
      @dataTypes.each { |dt|
        next if send('check_' + dt, genome)
        puts "=====================> INSTALLATION OF #{dt} for genome #{genome}"
        send('install_' + dt, genome) 
      }
      puts "=====================> INSTALLATION COMPLETE <====================="
    end
    
    # help function for print_current_conf()
    def format_label(label, min_size)
      return label if label.size() >= min_size
      prefix = ' ' * ( (min_size - label.size()) / 2 )
      suffix = ' ' * ( (min_size - label.size() + 1) / 2 )
      return (prefix + label + suffix)
    end

    # prints table with current configuration
    def print_current_conf()
      min_col_size = 8
      cols_sizes = [ ]
      @dataTypes.each { |dt|
        cols_sizes << [ min_col_size, dt.size() ].max()
      }
      puts ""
      line = (' ' * min_col_size)
      @dataTypes.each { |dt|
        line << '|' << format_label(dt, min_col_size)
      }
      puts line
      @genomes.each { |g|
        line1 = '-' * min_col_size
        line2 = format_label(g, min_col_size)
        @dataTypes.each_with_index { |dt,i|
          result = 'x'
          result = 'YES' if send('check_' + dt, g) # call one of the check_... methods
          line1 << '+' << ('-' * cols_sizes[i])
          line2 << '|' << format_label(result, cols_sizes[i])
        }
        puts line1
        puts line2
      }
      puts ""
    end
    
    # returns path to directory with given genome and data type
    def pathToDirectory(genome, dataType)
      base_dir = ENV['DIR_ADD']
      raise "You have to run this program as a genboree user!" if base_dir.nil? 
      return (base_dir + '/referenceGenomes/' + dataType + '/' + genome)
    end
    
    # run command in shell (with pipes, not used)
    def run_command_with_pipes(cmd)
      # Create child process
      pipe_out_read, pipe_out_write = IO.pipe()
      pipe_err_read, pipe_err_write = IO.pipe()
      pid = fork()
      if(pid == nil)
        # this is executed in the child process only  
        pipe_out_read.close()
        pipe_err_read.close()
        STDOUT.reopen(pipe_out_write)
        STDERR.reopen(pipe_err_write)
        exec("/bin/bash -c '#{cmd}'")
        # end of child process
      end
      # Parent process
      pipe_out_write.close()
      pipe_err_write.close()
      pid, exitCode = Process.waitpid2(pid)
      out = pipe_out_read.read()
      err = pipe_err_read.read()
      if exitCode != 0
        raise "Commands [#{cmd}] failed! Exit code = #{exitCode}. Errors stream:\n#{err}\nOutput stream:\n#{out}"
      end
      if err != ""
        puts "Error stream from [#{cmd}]:\n#{err}"
      end
      return out
    end

    # run command in shell
    def run_command(cmd)
      # Create child process
      pid = fork()
      if(pid == nil)
        # this is executed in the child process only  
        exec("/bin/bash -c '#{cmd}'")
        # end of child process
      end
      # Parent process
      puts "COMMAND: #{cmd}"
      pid, exitCode = Process.waitpid2(pid)
      if exitCode != 0
        raise "Commands [#{cmd}] failed! Exit code = #{exitCode}."
      end
    end

    # create ApiCaller object
    def getApiCallerForObject(resource)
      dbrc = BRL::DB::DBRC.new()
      dbrcRec = dbrc.getRecordByHost("localhost", :api)
      apiCaller = BRL::Genboree::REST::ApiCaller.new( "localhost", '/REST/v1/usr/genbadmin?', dbrcRec[:user], dbrcRec[:password] )
      resp = apiCaller.get()
      if(not apiCaller.succeeded?())
        raise "Api call failed (get), details:\n  uri=#{uriPath}\n  response=#{resp} fullResponse=#{apiCaller.respBody()}"
      end
      apiCaller.parseRespBody()
      dbs = apiCaller.apiDataObj
      apiCaller = BRL::Genboree::REST::ApiCaller.new( "localhost", resource, dbs['login'], dbs['password'] )
      return apiCaller
    end
    
    # - general function to check if given object exists by sending "get" request
    # - returns true/false
    # - raise exception when error occurs
    def checkIfExists(uriPath)
      apiCaller = getApiCallerForObject(uriPath)
      resp = apiCaller.get()
      #puts "Api call, details: uri=#{uriPath}  fullResponse=#{apiCaller.respBody()}" 
      return false if(resp.kind_of?(::Net::HTTPNotFound))
      return true  if(apiCaller.succeeded?())
      raise "Api call failed (get), details:\n  uri=#{uriPath}\n  response=#{resp} fullResponse=#{apiCaller.respBody()}"   
    end
    
    # - check if user group exists, returns true/false
    # - raise exception when error occurs
    def checkIfGroupExists(groupName)
      return checkIfExists('/REST/v1/grp/' + CGI::escape(groupName) + '?')
    end
    
    # - check if database exists, returns true/false
    # - raise exception when error occurs
    def checkIfDatabaseExists(groupName, databaseName)
      return checkIfExists('/REST/v1/grp/' + CGI::escape(groupName) + '/db/' + CGI::escape(databaseName) + '/name?')
    end
    
    # - general function to create object by sending "put" request
    # - raise exception when error occurs
    def createObject(uriPath)
      apiCaller = getApiCallerForObject(uriPath)
      resp = apiCaller.put()
      #puts "Api call, details: uri=#{uriPath}  fullResponse=#{apiCaller.respBody()}" 
      raise "Api call failed (put), details:\n  uri=#{uriPath}\n  fullResponse=#{apiCaller.respBody()}" if(apiCaller.failed?())  
    end  
    
    # - create group
    # - raise exception when error occurs
    def createGroup(groupName, groupDescription)
      createObject('/REST/v1/grp/' + CGI::escape(groupName) + '?')
    end
    
    # - create database
    # - raise exception when error occurs
    def createDatabase(groupName, databaseName, templateVersion)
      templateName = nil
      if templateVersion == "hg19" or templateVersion == "hg18"
        templateName = "Template: Human (#{templateVersion})"
      else
        raise "Unsupported version of template: " + templateVersion
      end
      createObject('/REST/v1/grp/' + CGI::escape(groupName) + '/db/' + CGI::escape(databaseName) + '?templateName=' + CGI::escape(templateName))
    end
    
    def createFile(groupName, databaseName, fileName, fileWithData)
      fileUri = '/REST/v1/grp/' + CGI::escape(groupName) + '/db/' + CGI::escape(databaseName) + '/file/' + fileName
      createObject(fileUri + '?')
      apiCaller = getApiCallerForObject(fileUri + '/data')
      apiCaller.put( File.open(fileWithData,"r") )
    end
    
    # ------------------------ functions for raw -----------------------
    
    # returns true if raw files for given genome exist
    def check_raw(genome)
      dir = pathToDirectory(genome, 'raw')
      return false if not File.directory?(dir)
      files = [ 'knownGene.txt','knownIsoforms.txt', "#{genome}.2bit", "#{genome}.fa" ] 
      files.each { |f|
        return false if not File.file?(dir + '/' + f)
      }
      return true
    end
    
    # download raw files
    def install_raw(genome)
      dir = pathToDirectory(genome,'raw')
      tmp_dir = dir + '/tmp'
      run_command("mkdir -p #{tmp_dir}")
      begin
        puts "The following files will be downloaded:"
        puts "  ftp://hgdownload.cse.ucsc.edu/goldenPath/#{genome}/bigZips/#{genome}.2bit"
        puts "  ftp://hgdownload.cse.ucsc.edu/goldenPath/#{genome}/database/knownIsoforms.txt.gz (and unzip)"
        puts "  ftp://hgdownload.cse.ucsc.edu/goldenPath/#{genome}/database/knownGene.txt.gz (and unzip)"
        run_command("cd #{tmp_dir}; wget ftp://hgdownload.cse.ucsc.edu/goldenPath/#{genome}/bigZips/#{genome}.2bit")
        run_command("cd #{tmp_dir}; wget ftp://hgdownload.cse.ucsc.edu/goldenPath/#{genome}/database/knownGene.txt.gz    ; gunzip knownGene.txt.gz    ")
        run_command("cd #{tmp_dir}; wget ftp://hgdownload.cse.ucsc.edu/goldenPath/#{genome}/database/knownIsoforms.txt.gz; gunzip knownIsoforms.txt.gz")
        # ------------- build fasta
        run_command("twoBitInfo  #{tmp_dir}/#{genome}.2bit  #{tmp_dir}/temp_all_chr.txt")
        run_command("cat #{tmp_dir}/temp_all_chr.txt | cut -f 1 | grep chr[0-9]$      | sort >  #{tmp_dir}/temp_chr.txt")
        run_command("cat #{tmp_dir}/temp_all_chr.txt | cut -f 1 | grep chr[0-9][0-9]$ | sort >> #{tmp_dir}/temp_chr.txt")
        run_command("cat #{tmp_dir}/temp_all_chr.txt | cut -f 1 | grep chr[XY]$       | sort >> #{tmp_dir}/temp_chr.txt")
        run_command("cat #{tmp_dir}/temp_all_chr.txt | cut -f 1 | grep chr[^0-9XY]$   | sort >> #{tmp_dir}/temp_chr.txt")
        run_command("twoBitToFa  -seqList=#{tmp_dir}/temp_chr.txt  #{tmp_dir}/#{genome}.2bit  #{tmp_dir}/#{genome}.fa")
        run_command("rm #{tmp_dir}/temp_*chr.txt")
        run_command("mv #{tmp_dir}/* #{dir}")   # move files to target directory when they are ready
      ensure
        run_command("rm -rf #{tmp_dir}")
      end
    end
    
    # ------------------------ functions for bowtie --------------------
    
    # returns true if bowtie indexes for given genome exist
    def check_bowtie(genome)
      dir = pathToDirectory(genome, 'bowtie')
      files_suffixes = ['1.ebwt', '2.ebwt', '3.ebwt', '4.ebwt', 'rev.1.ebwt', 'rev.2.ebwt']
      return false if not File.directory?(dir)
      files_suffixes.each { |fs|
        return false if not File.file?(dir + '/' + genome + '.' + fs)
      }
      return true
    end
    
    # install bowtie indexes
    def install_bowtie(genome)
      dir = pathToDirectory(genome,'bowtie')
      tmp_dir = dir + '/tmp'
      ref_file = pathToDirectory(genome,'raw') + '/' + genome + '.fa'
      run_command("mkdir -p #{tmp_dir}")
      begin
        run_command("module load bowtie;  bowtie-build  --offrate 1  #{ref_file}  #{tmp_dir}/#{genome}")
        run_command("mv #{tmp_dir}/* #{dir}/")   # move files to target directory when they are ready
      ensure
        run_command("rm -rf #{tmp_dir}")
      end
    end
    
    # ------------------------ functions for bowtie2 -------------------
    
    # returns true if bowtie2 indexes for given genome exist
    def check_bowtie2(genome)
      dir = pathToDirectory(genome, 'bowtie2')
      return false if not File.directory?(dir)
      files_suffixes = ['1.bt2', '2.bt2', '3.bt2', '4.bt2', 'rev.1.bt2', 'rev.2.bt2']
      files_suffixes.each { |fs|
        return false if not File.file?(dir + '/' + genome + '.' + fs)
      }
      return true
    end
    
    # build indexes for bowtie2
    def install_bowtie2(genome)
      dir = pathToDirectory(genome,'bowtie2')
      tmp_dir = dir + '/tmp'
      ref_file = pathToDirectory(genome,'raw') + '/' + genome + '.fa'
      run_command("mkdir -p #{tmp_dir}")
      begin
        run_command("module load bowtie2;  bowtie2-build  #{ref_file}  #{tmp_dir}/#{genome}")
        run_command("mv #{tmp_dir}/* #{dir}/")   # move files to target directory when they are ready
      ensure
        run_command("rm -rf #{tmp_dir}")
      end
    end
    
    # ------------------------ functions for BWA -----------------------
    
    def check_BWA(genome)
      dir = pathToDirectory(genome, 'BWA')
      return false if not File.directory?(dir)
      files_suffixes = ['amb', 'ann', 'bwt', 'pac', 'sa']
      return true
    end

    def install_BWA(genome)
      dir = pathToDirectory(genome,'BWA')
      tmp_dir = dir + '/tmp'
      ref_file = pathToDirectory(genome,'raw') + '/' + genome + '.fa'
      run_command("mkdir -p #{tmp_dir}")
      begin
        run_command("module load bwa;  bwa  index  -p  #{tmp_dir}/#{genome}  #{ref_file}")
        run_command("mv #{tmp_dir}/* #{dir}/")   # move files to target directory when they are ready
      ensure
        run_command("rm -rf #{tmp_dir}")
      end
    end
    
    # ------------------ functions for geneSpliceJunc ------------------
    
    def check_geneSpliceJunc(genome)
      dir = pathToDirectory(genome, 'geneSpliceJunc')
      return false if not File.directory?(dir)
      files_suffixes = ['1.ebwt', '2.ebwt', '3.ebwt', '4.ebwt', 'rev.1.ebwt', 'rev.2.ebwt']
      files_suffixes.each { |fs|
        return false if not File.file?(dir + "/#{genome}_knownGene_2x20_spliceJunctions." + fs)
      }
      return false if not File.file?(dir + "/knownGene_composite.interval")
      return true
    end

    def install_geneSpliceJunc(genome)
      dir = pathToDirectory(genome,'geneSpliceJunc')
      tmp_dir = dir + '/tmp'
      ref_dir = pathToDirectory(genome,'raw') 
      ref_file = ref_dir + '/' + genome + '.2bit'
      run_command("mkdir -p #{tmp_dir}")
      begin
        run_command("cut -f1,2,3,4,5,8,9,10 #{ref_dir}/knownGene.txt > #{tmp_dir}/knownGene.interval")
        run_command("module load RSeqTools; mergeTranscripts #{ref_dir}/knownIsoforms.txt #{tmp_dir}/knownGene.interval compositeModel > #{tmp_dir}/knownGene_composite.interval")
        run_command("module load RSeqTools; createSpliceJunctionLibrary #{ref_file} #{tmp_dir}/knownGene.interval 20 > #{tmp_dir}/knownGene_2x20_spliceJunctions.fa")
        run_command("module load bowtie; bowtie-build -f #{tmp_dir}/knownGene_2x20_spliceJunctions.fa #{tmp_dir}/#{genome}_knownGene_2x20_spliceJunctions")
        # move files to target directory when they are ready
        run_command("mv #{tmp_dir}/knownGene_composite.interval #{dir}/")
        run_command("mv #{tmp_dir}/*.ebwt #{dir}/")
      ensure
        run_command("rm -rf #{tmp_dir}")
      end
    end
    
    # ------------------------ functions for bowtie2RoiGrp -------------------
    
    # returns true if bowtie2 indexes are uploaded in ROI group
    def check_bowtie2RoiGrp(genome)
      rsc = "/REST/v1/grp/" + CGI::escape("ROI Repository") + "/db/" + CGI::escape("ROI Repository - #{genome}") + "/file/indexFiles/bowtie/wholeGenome/#{genome}_bowtie2.tar.gz/label"
      return checkIfExists(rsc)
    end
    
    # upload bowtie2 indexes to ROI group
    def install_bowtie2RoiGrp(genome)
      dir = pathToDirectory(genome,'bowtie2')
      tmp_dir = dir + '/tmp_roi'
      run_command("mkdir -p #{tmp_dir}")
      begin
        run_command("cd #{dir}; tar czf #{tmp_dir}/#{genome}_bowtie2.tar.gz *.bt2")
        group = 'ROI Repository'
        db = "ROI Repository - #{genome}"
        # create group ROI if not exists
        createGroup(group,'A group for maintaining Regions Of interest (ROI) Tracks') unless(checkIfGroupExists(group))
        # create DB for genome if not exists
        createDatabase(group,db,genome) unless(checkIfDatabaseExists(group,db))
        # upload the file
        createFile(group,db,"indexFiles/bowtie/wholeGenome/#{genome}_bowtie2.tar.gz","#{tmp_dir}/#{genome}_bowtie2.tar.gz")
      ensure
        run_command("rm -rf #{tmp_dir}")
      end
    end
    
    # ------------------------------------------------------------------
    
  end
end ; end # module BRL ; module Script

########################################################################
# MAIN - Provided in the scripts that implement ScriptDriver sub-classes
# - but would look exactly like this ONE LINE:
########################################################################
# IF we are running this file (and not using it as a library), run it:

if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Script::main(BRL::Script::ReferenceGenomesManager)
end

