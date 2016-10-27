#!/usr/bin/env ruby
require 'json'
require 'fileutils'
require 'cgi'
require 'brl/util/util'
require 'brl/util/emailer'
require 'gsl'
require 'brl/genboree/rest/apiCaller'


include GSL
include BRL::Genboree::REST

class LimmaGeneList

  def initialize(optsHash)
    @inputFile     = File.expand_path(optsHash['--file'])
    @genome        = File.expand_path(optsHash['--genome'])
    @host          = optsHash['--host']
    @db            = optsHash['--db']
    @grp           = optsHash['--grp']
    @userFirstName = optsHash['--userfirst']
    @userLastName  = optsHash['--userlast']
    @geneArray     = ""
  end
   
  ##Convert limma input into lff format
  def intoLff()
    skipFirst = false
    counter = 1
    fileWrite = File.open("#{File.basename(@inputFile)}.lff","w+")
    fileRead  = File.open(@inputFile)
    fileRead.each{|line|
      if(skipFirst == true)
        column  = line.split(/\t/)
        info    = column[0].split(/\_/)
        chr     = info[0]
        startP  = info[1].to_i
        endP    = info[2].to_i
        fileWrite.puts "Class\tname#{counter}\ttype\tsub-type\t#{chr}\t#{startP}\t#{endP}\t+\t.\t0"
        counter += 1
      end
      skipFirst = true
    }
    fileRead.close
    fileWrite.close
    
    cmd ="ruby /home/tandon/test_area/mirna_association/gene_mirna.rb -f #{@genome} -s #{File.basename(@inputFile)}.lff "
    puts cmd
    #system(cmd)
    cmd = "ruby ~/test_area/mirna_association/new/merging.rb output"
    puts cmd
    #system(cmd)
    geneList()
    makeLink()
    writeIndexHtmlFile()
  end
  
  ##creating genelist
  def geneList()
    file1 = File.open("temp_output2")
    file2 = File.open("geneList.lff" , "w+")
    file1.each {|line|
      line.strip!
      c = line.split(/\t/)
      unless(c[12] =~ /\_SELF/ )
        if(c[1] !~ /\,/)
          @geneArray << "#{CGI.escape(c[12])},"
        else
          noOfGenes = c[12].split(/,/)
          noOfGenes.each {|gene|
            @geneArray << "#{CGI.escape(gene)},"
          }
        end
        
        file2.puts "#{c[0]}\t#{c[1]}\t#{c[2]}\t#{c[3]}\t#{c[4]}\t#{c[13]}\t#{c[14]}\t#{c[7]}\t#{c[8]}\t#{c[9]}\t#{c[10]}\t#{c[11]}\t#{c[12]}\t"
      end
      }
    file2.close
    file1.close
    #puts @geneArray.chomp!(",")
    @geneArray = "MIR197,MAPK8IP3.2,MAPK8IP3,PDHX.2,PDHX.3,PDHX,MIR130A,MIR198,FSTL1,MIR450B,MIR130B"
  end
  
  
  ##building page to see gene list in gene browser
  def makeLink()
    
    trkString = ""
    list = %x{cut -f1 metadata.txt}
    trkArray = list.split(/\n/)
    trkArray.shift
    trkArray.each {|trk|
      trk = trk.gsub(/\./,':')
      trkString << "#{CGI.escape(trk)},"
      }
    trkString.chomp!(',')
    @httplLink = "http://#{@host}/epigenomeatlas/geneViewer.rhtml?trackNames=#{trkString}"
    @httplLink << "&gbGridYAttr=eaSampleType&gbGridXAttr=eaAssayType&grpName=#{CGI.escape(@grp)}"
    @httplLink << "&dbName=#{CGI.escape(@db)}&geneNames=#{@geneArray}"
    puts @httplLink
  end
  
  # Creates index html file
  # [+returns+] nil
  def writeIndexHtmlFile()
    @userFirstName = "arpit"
    @userLastName = "tandon"
    $stderr.puts "Writing out index html page"
    plotsIndexWriter = File.open("./plotsIndex.html", "w+")
    plotBuff = "<html>
                  <body style=\"background-color:#C6DEFF\">
                      <table cellspacing=\"0\" style=\"margin:10px auto 10px auto;\">
                        <tr>
                          <th colspan=\"1\" style=\"border-bottom:2px solid black;width:100%;\">Table of Content: Epigenomic ToolSet</th>
                        </tr>
                "
    plotBuff << "
                  <tr style=\"background-color:white;\">
                    <td style=\"border-left:2px solid black;border-right:2px solid black;\">
                      <table cellspacing=\"0\" border=\"0\" style=\"padding-left:35px;padding-top:15px;padding-bottom:10px;\">
                        <tr>
                          <td style=\"background-color:white\"><b>Study Name:</b></td><td style=\"background-color:white\">#{@studyName}</td>
                        </tr>
                        <tr>
                          <td style=\"background-color:white\"><b>User:</b></td><td style=\"background-color:white\">#{@userFirstName.capitalize} #{@userLastName.capitalize}</td>
                        </tr>
                        <tr>
                          <td style=\"background-color:white\"><b>Date:</b></td><td style=\"background-color:white\">#{Time.now.localtime.strftime("%Y/%m/%d %R %Z")}</td>
                        </tr>
                      </table>
                    </td>
                  </tr>
                "
  
    plotBuff << "
                  <tr style=\"background-color:white;\">
                    <td style=\"border-left:2px solid black;border-right:2px solid black;border-bottom:2px solid black;\">
                      <table  border=\"0\" cellspacing=\"0\" style=\"padding:15px 35px;\">
                        <tr>
                          <th colspan=\"1\" style=\"border-bottom:1px solid black; width:300px;background-color:white;\">Epigenomic Changes Plots</th>
                        </tr>
                        
                "
    
          plotBuff <<
                  "
                    <tr>
                      <td style=\"vertical-align:top;border-right:1px solid black;border-left: 1px solid black;background-color:white;\">
                         <a href=\'#{@httplLink}'\">Genes</a>
                      </td>
                    </tr>
                    <tr>
                      <td style=\"vertical-align:top;border-right:1px solid black;border-left:1px solid black;border-bottom:1px solid black;background-color:white\">
                         <a href=\'#{@httplLink}'\">Genes</a>
                      </td>
                    </tr>
       "
      
    plotBuff << "
                            </table>
                          </td>
                        </tr>
                      </table>
                    </body>
                  </html>
                "
    plotsIndexWriter.print(plotBuff)
    plotBuff = ""
    plotsIndexWriter.close()
    
  end

  ##help section defined
  def LimmaGeneList.usage(msg='')
    unless(msg.empty?)
      puts "\n#{msg}\n"
    end
    puts "
      PROGRAM DESCRIPTION:
        epigenome attribute values retiever
      COMMAND LINE ARGUMENTS:
        --file         | -f => Input limma tsv file
        --genome       | -G => ROI for intersection
        --db           | -d => database
        --grp          | -g => group
        --host         | -H => host
        --userfirst    | -u => user first name
        --userlast     | -l => user last name
        --help         | -h => [Optional flag]. Print help info and exit.
      usage:
            
        ";
      exit;
  end # 
      
  # Process Arguements form the command line input
  def LimmaGeneList.processArguements()
    # We want to add all the prop_keys as potential command line options
    optsArray = [ 
                  ['--file'       ,'-f', GetoptLong::REQUIRED_ARGUMENT],
                  ['--genome'     ,'-G', GetoptLong::REQUIRED_ARGUMENT],
                  ['--host'       ,'-H', GetoptLong::REQUIRED_ARGUMENT],
                  ['--db'         ,'-d', GetoptLong::REQUIRED_ARGUMENT],
                  ['--grp'        ,'-g', GetoptLong::REQUIRED_ARGUMENT],
                  ['--userfirst'  ,'-u', GetoptLong::REQUIRED_ARGUMENT],
                  ['--userlast'   ,'-l', GetoptLong::REQUIRED_ARGUMENT],
                  ['--help'       ,'-h', GetoptLong::NO_ARGUMENT]
                ]
    progOpts = GetoptLong.new(*optsArray)
    LimmaGeneList.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
    optsHash = progOpts.to_hash
    Coverage if(optsHash.empty? or optsHash.key?('--help'));
    return optsHash
  end 
  
end

begin
optsHash = LimmaGeneList.processArguements()
performQCUsingFindPeaks = LimmaGeneList.new(optsHash)
performQCUsingFindPeaks.intoLff()
rescue => err
      $stderr.puts "Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
end

