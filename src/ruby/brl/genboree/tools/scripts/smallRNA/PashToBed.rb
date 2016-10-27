#!/usr/bin/env ruby
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/db/dbrc'
require 'brl/util/emailer'
require 'cgi'
require 'brl/genboree/rest/apiCaller'
require 'brl/util/expander'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/tools/scripts/uploadTrackAnnos/uploadTrackAnnosWrapper'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
include BRL::Genboree::REST

## Accepts a pash file and convert it into BED file and then converts that BED file into wig file and upload
## it into genboree database

class PashToWig

	def initialize(optsHash)
		@optsHash = optsHash
		@pashFile  = File.expand_path(@optsHash['--pashFile'])
		@outputDir = File.expand_path(@optsHash['--outputDir'])
		@scratch   = File.expand_path(@optsHash['--scratch'])
		@chrRef = File.expand_path(@optsHash['--chrRef'])
		@outputPath = @optsHash['--outputPath']
		@gbConfFile = @optsHash['--gbConfFile']
		@apiDBRCkey = @optsHash['--apiDbrcKey']
		@trk = @optsHash['--trk']
		@jobId = @optsHash['--jobId'] || "job.#{Time.now.to_f}"
		@userId = @optsHash['--userId']

		@grph = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new(@gbConfFile)
		@dbhelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new(@gbConfFile)
		@outputPath = @outputPath.chomp('?')
		uriOutput = URI.parse(@outputPath)
		@hostOutput = uriOutput.host
		@pathOutput = uriOutput.path
		@dbOutput = @dbhelper.extractName(@outputPath)
		@grpOutput = @grph.extractName(@outputPath)

		dbrc = BRL::DB::DBRC.new(nil, @apiDBRCkey)
		@pass = dbrc.password
		@user = dbrc.user

	end

	##Converts pash file into bed file
	def pashToBed()

		writeHandle = File.open("#{@outputDir}/#{File.basename(@pashFile)}.bed","w+")
		fileHandle = File.open(@pashFile)
		fileHandle.each { |line|
			columns = line.split(/\t/)
			score = columns[3].split(/__/)[1].to_f/columns[4].to_f
			writeHandle.puts "#{columns[0]}\t#{columns[1]}\t#{columns[2]}\t#{columns[3]}\t#{score}\t#{columns[6]}"
		}
		writeHandle.close
		system("gzip -f #{@outputDir}/#{File.basename(@pashFile)}.bed")
	end

	##Converts bed file to wig file
	def bedToWig()
		 Dir.chdir(@scratch)
		begin
			Dir.chdir(@outputDir)
			system("gunzip  #{File.basename(@pashFile)}.bed.gz")
			system("removeRedundantReads.rb -i #{File.basename(@pashFile)}.bed -f bed -o #{File.basename(@pashFile)}.sorted.bed --onlySort -n")
			system("coverage.rb -i #{File.basename(@pashFile)}.sorted.bed -f bed -o #{File.basename(@pashFile)}.wig -t cov:1 -u")

			#system("bedToWig.rb #{@outputDir}/#{File.basename(@pashFile)}.bed.gz #{@scratch} BCM sample mark #{@chrRef} #{@outputDir}/#{File.basename(@pashFile)}.wig")
			if(!$?.success?)
				raise "Wig file not created"
			end
			Dir.chdir(@scratch)
			system("gzip -f #{@outputDir}/#{File.basename(@pashFile)}.wig")
			#File.delete("#{@outputDir}/#{File.basename(@pashFile)}.bed.gz")
			##uploading wig file to speciifed database
			apicaller = ApiCaller.new(@hostOutput,"",@user,@pass)
			#unless trackExist?(@trk)
			#	$stderr.puts "creating track"
		#		createEmptyTrack(@trk)
		#	end
			#restPath = "/REST/v1/grp/#{CGI.escape(@grpOutput)}/db/#{CGI.escape(@dbOutput)}/annos?format=wig&trackName=#{CGI.escape(@trk)}&userId=#{@userId}"


			#inFile = File.open("#{@outputDir}/#{File.basename(@pashFile)}.wig.gz")
			#$stdout.puts "uploading #{@outputDir}/#{File.basename(@pashFile)}.wig.gz"
			#apicaller.put(inFile)
      restPath = "/REST/v1/grp/#{CGI.escape(@grpOutput)}/db/#{CGI.escape(@dbOutput)}?"
      restPath << "&gbKey=#{@dbhelper.extractGbKey(@outputPath)}" if(@dbhelper.extractGbKey(@outputPath))
      apicaller.setRsrcPath(restPath)
      apicaller.get()
      resp = JSON.parse(apicaller.respBody)
      uploadAnnosObj = BRL::Genboree::Tools::Scripts::UploadTrackAnnosWrapper.new()
      uploadAnnosObj.refSeqId = resp['data']['refSeqId']
      uploadAnnosObj.groupName = @grph.extractName(@outputPath)
      uploadAnnosObj.userId = @userId
      uploadAnnosObj.jobId = @jobId
      uploadAnnosObj.trackName = @trk
      uploadAnnosObj.outputs = [@outputPath]
      exp = BRL::Util::Expander.new("#{@outputDir}/#{File.basename(@pashFile)}.wig.gz")
      exp.extract()
      begin
        uploadAnnosObj.uploadWig(CGI.escape(File.expand_path(exp.uncompressedFileName)), false)
        $stdout.puts "successfully uploaded #{exp.uncompressedFileName}"
        `rm -f #{exp.uncompressedFileName}`
      rescue => uploadErr
        $stderr.puts "Error: #{uploadErr}"
        $stderr.puts "Error Backtrace:\n\n#{uploadErr.backtrace.join("\n")}"
        @errUserMsg = "FATAL ERROR: Could not upload result wig file to target database."
        if(uploadAnnosObj.outFile and File.exists?(uploadAnnosObj.outFile))
          @errUserMsg << "\n\n#{File.read(uploadAnnosObj.outFile)}"
        end
        raise @errUserMsg
      end

		rescue =>err

			$stderr.puts "Details: #{err.message}"
			$stderr.puts err.backtrace.join("\n")
			exit(1)
		end

	end

	##checks if track exist or not
	def trackExist?(trackname)

		resource = "/REST/v1/grp/#{CGI.escape(@grpOutput)}/db/#{CGI.escape(@dbOutput)}/trk/#{CGI.escape(@trk)}"
		resource << "?gbKey=#{@dbhelper.extractGbKey(@outputPath)}" if(@dbhelper.extractGbKey(@outputPath))
    apiCaller = ApiCaller.new(
         @hostOutput,
         resource,
         @user,
         @pass)

		httpResp = apiCaller.get()
		return apiCaller.succeeded?
	end

	##create track
	def createEmptyTrack(trackname)
		resource = "/REST/v1/grp/#{CGI.escape(@grpOutput)}/db/#{CGI.escape(@dbOutput)}/trk/#{CGI.escape(@trk)}"
		resource << "?gbKey=#{@dbhelper.extractGbKey(@outputPath)}" if(@dbhelper.extractGbKey(@outputPath))
		apiCaller = ApiCaller.new(
			    @hostOutput,
			    resource,
			    @user,
			    @pass)


		httpResp = apiCaller.put()
		if apiCaller.succeeded?
			$stderr.puts " track created "
		    return true
	       else
		     # Can't access apiCaller.apiStatusObj without first parsing the response
		    $stderr.puts apiCaller.parseRespBody()
		    $stderr.puts "ERRROR"
		    $stderr.puts "API response; statusCode: #{apiCaller.apiStatusObj['statusCode']}, message: #{apiCaller.apiStatusObj['msg']}"
		   return nil
	       end
	end


	##Process Arguements form the command line input
	  def PashToWig.processArguements()
	    # We want to add all the prop_keys as potential command line options
	      optsArray = [ ['--pashFile'  ,    '-p', GetoptLong::REQUIRED_ARGUMENT],
			    ['--outputDir' ,    '-o', GetoptLong::REQUIRED_ARGUMENT],
			    ['--scratch'   ,    '-s', GetoptLong::REQUIRED_ARGUMENT],
			    ['--chrRef'    ,    '-c', GetoptLong::REQUIRED_ARGUMENT],
			    ['--outputPath',    '-O', GetoptLong::OPTIONAL_ARGUMENT],
			    ['--gbConfFile',    '-g', GetoptLong::OPTIONAL_ARGUMENT],
			    ['--apiDbrcKey',    '-a', GetoptLong::OPTIONAL_ARGUMENT],
			    ['--userId'    ,    '-u', GetoptLong::OPTIONAL_ARGUMENT],
			    ['--trk'       ,    '-t', GetoptLong::OPTIONAL_ARGUMENT],
			    ['--jobId'       ,    '-j', GetoptLong::OPTIONAL_ARGUMENT],
			    ['--help'      ,    '-h', GetoptLong::NO_ARGUMENT]
			  ]
	      progOpts = GetoptLong.new(*optsArray)
	      PashToWig.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
	      optsHash = progOpts.to_hash

	      PashToWig.usage() if( optsHash.key?('--help'));
	      return optsHash
	  end

	   # Display usage info and quit.
	  def PashToWig.usage(msg='')
	    unless(msg.empty?)
	      puts "\n#{msg}\n"
	    end
	    puts "

	  PROGRAM DESCRIPTION:
	  Convert pash file into bed file and then into wig file and upload in genboree

	  COMMAND LINE ARGUMENTS:
	    --pashFile        | -p => PashFile
	    --outputDir       | -o => Output Directory
	    --scratch         | -s => Scratch Directory
	    --chrRef          | -c => chromosome referece
	    --outputPath      | -O => [optional] online databse location
	    --gbConfFile      | -g => [optional] gbconfig file location
	    --apiDbrcKey      | -a => [optional] api dbrc key
	    --userId          | -u => [optional] userId
	    --trk             | -t => [optional] trk name
	    --help            | -h => [Optional flag]. Print help info and exit.




	 usage:

	 PashToBed.rb -d input -o output -s /scratch -c hg18.ref -O  'http://10.15.4.44/REST/v1/grp/arpit_group/db/small%20rna_output?' -g file_location
	 -a prolineAPI -u 1234 -t track:name"
	    exit(2);
	  end

end

optsHash = PashToWig.processArguements()
wigConvertor = PashToWig.new(optsHash)
wigConvertor.pashToBed()
wigConvertor.bedToWig()
