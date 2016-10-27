#!/usr/bin/env ruby
require 'fileutils'
require "brl/util/textFileUtil"
require "brl/util/util"
require 'roo'

DEBUG = 0

def processArguments()
  # We want to add all the prop_keys as potential command line options
  optsArray = [ ['--inputmatrix','-i', GetoptLong::REQUIRED_ARGUMENT],
    ['--outputFolder','-o', GetoptLong::REQUIRED_ARGUMENT]
  ]
  progOpts = GetoptLong.new(*optsArray)
  usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
  optsHash = progOpts.to_hash
  return optsHash
end

def usage(msg='')
  unless(msg.empty?)
    puts "\n#{msg}\n"
  end
  puts "

  PROGRAM DESCRIPTION:
  Compute svd of input matrix using R

  COMMAND LINE ARGUMENTS:
  --inputmatrix               |  -i => input_matrix_file.txt
  --outputFolder              |  -o => output_folder/



  usage:
  computeSVD.rb -i matrix.txt -o outputFolder

  ";
  exit(113);
end

class SVD
  attr_reader :optsHash, :outputDirectory

  #initialize data elements
  def initialize(settingsHash)
    @optsHash=settingsHash
    @matrixFile = File.expand_path(@optsHash["--inputmatrix"])
    @outputDirectory = File.expand_path(@optsHash["--outputFolder"])
    #create output directory
    FileUtils.mkdir_p @outputDirectory
  end

  def computeSVD()
    rFile = "#{@outputDirectory}/#{File.basename(@matrixFile)}.svd.R"
    uFile = "#{@outputDirectory}/#{File.basename(@matrixFile)}.svd.U.txt"
    dFile = "#{@outputDirectory}/#{File.basename(@matrixFile)}.svd.D.txt"
    vFile = "#{@outputDirectory}/#{File.basename(@matrixFile)}.svd.V.txt"

    ofh = File.open(rFile, "w")
    ofh.puts "
    setwd(\"#{@outputDirectory}\")
    x <- read.table(\"#{@matrixFile}\", row.names=1, header=TRUE, sep=\"\\t\", na.strings= \"NA\")
    mat=as.matrix(x)
    s <- svd(mat)
    U <- s$u
    D <- diag(s$d)
    V <- s$v
    write.table(U,\"#{uFile}\",row.names=FALSE,col.names=FALSE)
    write.table(D,\"#{dFile}\",row.names=FALSE,col.names=FALSE)
    write.table(V,\"#{vFile}\",row.names=FALSE,col.names=FALSE)
    "
    ofh.close()
    #run R command
    rstatus = `R --vanilla < #{rFile}`
    puts $?.inspect
    puts rstatus
    if($?.exitstatus != 0)
      $stderr.debugPuts(__FILE__, __method__, "ERROR", "SVD computation did not succeed\n#{rstatus}\nPlease check logs")
      exit(113)
    end
  end

end

begin
  #check for proper usage and exit if necessary
  settingsHash=processArguments()
  #initialize input data
  svd = SVD.new(settingsHash)
  #perform alpha diversity pipeline via work function
  svd.computeSVD()
  exit 0
rescue => err
  $stderr.debugPuts(__FILE__, __method__, "ERROR", "SVD computation did not succeed\n#{err.message}")
  $stderr.debugPuts(__FILE__, __method__, "ERROR", "#{err.backtrace.join("\n")}")
  exit(113)
end
