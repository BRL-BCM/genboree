#!/usr/bin/env ruby

require 'brl/util/util'
require 'rubygems'
require 'spreadsheet'
require 'logger'
require 'inline'
require "gsl"
require "fileutils"
include GSL
include GSL::Fit


class SearchAtlasSim


  def initialize(infile,target,targetname, cfname, step, roi, bedgraph, tempDir, outfname, log)
  
    @prefix = "searchAtlasSim_"
	@infile = infile
	@target = target
	@targetlist = Array.new()
	@targetname = targetname
	@targettracklist = Array.new()
	@targetversions = Hash.new()
	@targetdescriptions = Hash.new()
	@targetbrowserurls = Hash.new()
	@cfname = cfname
	@step = step
	@roi = roi
	@bedgraph = ( (bedgraph =~ /^(?:true|yes)$/i) ? true : false)
	@tempDir = tempDir
	@outfname = outfname
	@windowsize = 10000		    #10000
	@buffer = 256000000			#the best buffer size
	@log = log
	
	tempTarget = File.open(@target,"r")
	tempTarget.each{ |target|	
			@targetlist.push(target.strip)
	}
	tempTarget.close
	
	tempTname = File.open(@targetname,"r")
	tempTname.each{	|line|
		cols = line.strip.split(/\t/)
		@targettracklist.push(cols[0])
		@targetversions[cols[0]] = cols[1]
		@targetdescriptions[cols[0]] = cols[2]
		@targetbrowserurls[cols[0]] = cols[3]
	}
	tempTname.close
	
	status =  "Initializing parameters -\n"
	status += "infile: #{@infile}\ntarget: #{@target}\ncfname: #{@cfname}\nstep: #{@step}\nroi: #{@roi}\ntempDir: #{@tempDir}\noutfname: #{@outfname}"	
	@log.debug status
	inputs = [@infile, @targetlist, @cfname]
	inputs.each{	|input|
		if input.class == Array
			input.each{	|element|
				unless File.exist?(element)
					puts "Can't find #{element}, please try again"
					@log.error "Can't find #{element}, please try again"
					raise "Can't find #{element}, please try again"
				end
			}
		else
			unless File.exist?(input)
				puts "Can't find #{input}, please try again"
				@log.error "Can't find #{input}, please try again"
				raise "Can't find #{input}, please try again"
			end
		end
	}

	#an instance hash-variable; key and value represent chromosome and size respectly
	@chrom_size = getChromosomeInfo(@cfname);
	

  end  


  def work()
  
	indexInfile = nil
	indexTargets = Array.new()
	
	if @roi == nil      #windows-based regression
		puts "Performing regresson analysis on windows...."
		@log.debug "Performing regresson analysis on windows...."
		if @step == "variable"
			puts "VariableStep"
			@log.debug "VariableStep"
			@log.debug "createVariableSignalWindow for infile!"
			indexInfile = createVariableSignalWindow(@infile);
			@log.debug "indexInfile : #{indexInfile}"
			@log.debug "createVariableSignalWindow for targets!"
			tcount = 1
			@targetlist.each{	|target|
				indexTargets.push(createVariableSignalWindow(target))
				@log.debug "target #{tcount}: #{target}"
			}
		else
			puts "FixedStep"
			@log.debug "FixedStep"
			@log.debug "createFixedSignalWindow for Y!"
			indexInfile = createFixedSignalWindow(@infile);
			@log.debug "indexInfile : #{indexInfile}"
			@log.debug "createFixedSignalWindow for Targets!"
			tcount = 1
			@targetlist.each{	|target|
				indexTargets.push(createFixedSignalWindow(target))
				@log.debug "target #{tcount}: #{target}"
				tcount += 1	
			}
		end
		
		corr = Hash.new()
		tcount = 1
		indexTargets.each{	|tindex|
			tname = (@targetname != nil) ? @targettracklist[tcount-1] : "target#{tcount}"
			corr[tname] = pearsonCorrelation(indexInfile, tindex)
			@log.debug "corr : #{corr[tname]}"
			tcount += 1
		}
		writeResult(corr, @outfname)
		@log.debug "writeResult!"
		createSummary(@outfname)
		@log.debug "createSummary!"

	else				  #interested region

		if @bedgraph
			puts "Performing regresson analysis using bedgraph files...."
			@log.debug "Performing regresson analysis using bedgraph files...."

			@log.debug "createVariableSignalWindow for infile!"
			bedgraphin = @infile;
								
			corr = Hash.new()
			tcount = 1
			@targetlist.each{	|tindex|
				tname = (@targetname != nil) ? @targettracklist[tcount-1] : "target#{tcount}"
				corr[tname] = pearsonCorrelationOnBedGraph(bedgraphin, tindex)
				@log.debug "corr : #{corr[tname]}"
				tcount += 1
			}
			writeResult(corr, @outfname)
			@log.debug "writeResult!"
			createSummary(@outfname)
			@log.debug "createSummary!"
		
		else
			puts "Performing analysis on interested regions...."
			@log.debug "Performing regresson analysis on interested regions...."
			if @step == "variable"
				puts "VariableStep"
				@log.debug "in VariableStep"
				@log.debug "createVariableSignalTarget for infile!"
				indexInfile = createVariableSignalTarget(@infile, @roi);
				@log.debug "indexInfile : #{indexInfile}"
				@log.debug "createVariableSignalTarget for targets!"
				tcount = 1
				@targetlist.each{	|target|
					indexTargets.push(createVariableSignalTarget(target, @roi))
					@log.debug "target#{tcount}: #{target}"
					tcount += 1
				}
			else
				puts "FixedStep"
				@log.debug "FixedStep"
				@log.debug "createFixedSignalTarget for infile!"
				indexInfile = createFixedSignalTarget(@infile, @roi);
				@log.debug "indexInfile : #{indexInfile}"
				@log.debug "createFixedSignalTarget for targes!"
				tcount = 1
				@targetlist.each{	|target|
					indexTargets.push(createFixedSignalTarget(@xfname, @target))
					@log.debug "target #{tcount}: #{target}"	
					tcount += 1
				}
			end

			corr = Hash.new()
			tcount = 1
			indexTargets.each{	|tindex|
				tname = (@targetname != nil) ? @targettracklist[tcount-1] : "target#{tcount}"
				corr[tname] = pearsonCorrelation(indexInfile, tindex)
				@log.debug "corr : #{corr[tname]}"
				tcount += 1
			}
			writeResult(corr, @outfname)
			@log.debug "writeResult!"
			createSummary(@outfname)
			@log.debug "createSummary!"
		end
	end
	
  end


  def createSummary(fname)
		
	tempFname = @tempDir+@prefix+"summary.txt"
	summaryFile = File.open(tempFname,"w")
	infile = File.open(fname,"r")
	lcount = 1
	infile.each{	|line|
		cols = line.strip.split(/\t/)
		summaryFile.puts "    #{cols[0]}\t#{cols[1]}"
		if lcount == 10 
			break
		end
		lcount += 1
	}
	
	summaryFile.close

  end 

  #read chromosome information, which includes two tab-delimited columns representing chromosomes and sizes 
  def getChromosomeInfo(cfname)

	chrom_size = {}
	infile = File.new(cfname,"r")
	infile.each {	|line|
		arr = line.split(/\s+/)
		chrom_size[arr[0]] = arr[1]

	}
	return chrom_size
  end
  
  
  def hasfile?(sfile)

	File.exist?(sfile) ? (return true) : (return false)
	
  end
 
  #write correlations into a file
  def writeResult(corr, outfile)

	puts "writing #{outfile}........."

	temp = outfile + ".tmp"
	out = File.open(temp,"w")
	count = 1
	corr.each{	|key,val|
		out.puts "#{key}\t#{val}\t#{@targetversions[key]}\t#{@targetdescriptions[key]}\t#{@targetbrowserurls[key]}"
		count += 1
	}
	out.close()
	system("sort -t $'\t' -k 2 -n -r #{temp} > #{outfile}")
	
	if count < 65536
		copyTXTtoXLS(outfile)
	end
	
  end
 
 
  def copyTXTtoXLS(fname)

	xlsfile = fname.gsub(".txt",".xls")
	book = Spreadsheet::Workbook.new()
	sheet1 = book.create_worksheet( :name => 'Result' )

	format_0 = Spreadsheet::Format.new :vertical_align => :center, :horizontal_align=>:center, :pattern=>1, :pattern_fg_color=>:red
	sheet1[0,0] = "Track Name"
	sheet1.row(0).set_format(0, format_0)
	sheet1[0,1] = "Pearson Correlation"
	sheet1.row(0).set_format(1, format_0)
	sheet1[0,2] = "Genome Version"
	sheet1.row(0).set_format(2, format_0)
	sheet1[0,3] = "Track Description"
	sheet1.row(0).set_format(3, format_0)
	sheet1[0,4] = "Link to Browser"
	sheet1.row(0).set_format(4, format_0)

	infile = File.open(fname,"r")
	lindex = 1
	infile.each{	|line|
		cols = line.strip.split(/\t/)
		for i in 0..cols.length-1
			sheet1[lindex,i] = (i != (cols.length-1) ) ? "#{cols[i]}" : (Spreadsheet::Link.new "#{cols[i]}", "#{cols[i]}")
		end
		lindex += 1
	}
	infile.close()
	book.write("#{xlsfile}")
		
  end
 
  #estimate coefficient for a regression model
  def pearsonCorrelation(indexY, indexX)

	ys_all = []
	xs_all = []
	ys = []
	xs = []

	puts "indexY : #{indexY}"
	puts "indexX : #{indexX}"
	
	puts "Starting Regression Analysis.........."
	indices = [indexY, indexX]

	#chromes = `ls #{indexX}`	
	@chrom_size.each_key{	|ch|
	#chromes.each{	|ch|
	
		puts "Reading #{ch}.........."
		indices.each{	|index|
			target = index+"/"+ch+"/"+ch+".sta"
			if File.exist?(target)
				stasfile = File.open(target,"r")		
				stasfile.each{ |line|
					arr = line.split(/\s+/)
					if index == indexY
						ys[arr[0].to_i] = arr[1].to_i
					else
						xs[arr[0].to_i] = arr[1].to_i				
					end
				} #end of stas file
			end
		} #end of indices
		
		if @roi == nil
			#define the window
			lindex = (@chrom_size[ch].to_i / @windowsize )
			ys[lindex] = 0 if ys[lindex] == nil
			xs[lindex] = 0 if xs[lindex] == nil
	
			ys.each_index{	|i|
				ys[i] = 0 if ys[i] == nil
				xs[i] = 0 if xs[i] == nil
				if not ( ys[i] == 0 and xs[i] == 0 )
					ys_all.push(ys[i])
					xs_all.push(xs[i])
				end
			}
		else
			#ys_all.push(ys[i])
			#xs_all.push(xs[i])
			ys_all += ys
			xs_all += xs
		end
		ys = []
		xs = []
	}#end of chrom
	
	puts "Computing coefficients and variances.........."
	y = Vector.alloc(ys_all)	
	x = Vector.alloc(xs_all)

	
	p =  GSL::Stats::correlation(x,y)
	printf("# pearson = %g\n", p);
	
	if  p.nan?
		exit(57)
	else
		p = sprintf('%.4f',p).to_f
		return p
	end
	

  end #end of performRegressoin(sdirY, sdirX)
 
 
  def pearsonCorrelationOnBedGraph(indexY, indexX) 

	ys_all = []
	xs_all = []
	ys = getBedGraphHash(indexY)
	xs = getBedGraphHash(indexX)
	
	ys.each{	|key, val|
		if xs.key?(key)
			ys_all.push(val)
			xs_all.push(xs[key])
		end
	}

	puts "Computing coefficients and variances.........."
	y = Vector.alloc(ys_all)	
	x = Vector.alloc(xs_all)

	p =  GSL::Stats::correlation(x,y)
	printf("# pearson = %g\n", p);
	
	if  p.nan?
		exit(57)
	else
		p = sprintf('%.4f',p).to_f
		return p
	end
	 
  end


  def getBedGraphHash(f)
	tmpHash = Hash.new()
	bedfile = File.open(f, "r")		
	bedfile.each{ |line|
		if line =~ /^chr/
			arr = line.split(/\s+/)
			key = arr[0] + ":" + arr[1].to_s + ":" + arr[2].to_s
			tmpHash[key] = arr[3].to_f
		end
	}
	return tmpHash
  end
 
 
#  def getWindowIndex(location)
#	return location / @windowsize
#  end

  inline do |builder|

	builder.c "
	int getWindowIndex(int location, int windowsize) {
	  return (location / windowsize);
    }"
	
	builder.c "
	double production(double score, int span) {
	  return (score * span);
    }		
	"
  end
    
  
  def createFixedSignalWindow(sfile)

	fsize = File.size(sfile)
	f = File.new(sfile)

	index_score = Hash.new()
	prevContent = ""
	currentPage = 1	
	puts "Reading #{sfile} ....."
	
	while currentContent = f.read(@buffer)

		currentContent = prevContent + currentContent	#the first line must be header

		firstStepPos = currentContent.index(/fixedStep\s+chrom=(\S+)\s+start=(\d+)\sstep=(\d+)(\s+span=(\d+)\n|\n)/)
		chrom = $1
		start = $2.to_i
		step = $3.to_i
		span = $5.to_i
		offset = 0
		
		span  = ($5.to_i < 2 ) ? 1 : $5.to_i
		lastStepPos = currentContent.rindex(/fixedStep\s+chrom=(\S+)\s+start=(\d+)\sstep=(\d+)(\s+span=(\d+)\n|\n)/)
			
		if currentPage*@buffer < fsize			#if not last page

			if firstStepPos == nil				#there is no head in page	
				#puts "The page has to have at least one head."
				puts "Please check if the file format is valid!"
				@log.error "Error: check #{sfile} if the file format is valid!"
				exit
				#prevContent = currentContent   #roll over becuae current content would continue in the next page
				#currentContent = ""
			else
				if firstStepPos == lastStepPos
					prevContent = currentContent   #roll over becuae current content would continue in the next page
					currentContent = ""
				else
					prevContent = currentContent[lastStepPos..currentContent.length]
					currentContent = currentContent[firstStepPos..lastStepPos-1]
				end
			end
		end
		
		
		if currentContent != ""
			currentContent.each{	|line|
				if line =~ /^(\d+|\d+\.\d+)\n/
					cindex = getWindowIndex(start + offset * step, @windowsize)     #ignoring index change while spanning 
					if index_score[chrom].key?(cindex)
						index_score[chrom][cindex] += production($1.to_f, span) #$1.to_f * span
					else
						index_score[chrom][cindex] = production($1.to_f, span) #$1.to_f * span
					end
					offset += 1
				elsif line =~ /^fixedStep\s+chrom=(\S+)\s+start=(\d+)\sstep=(\d+)(\s+span=(\d+)\n|\n)/
					chrom = $1
					start = $2.to_i
					step = $3.to_i
					span = $5.to_i
					offset = 0
					span  = ($5.to_i < 2 ) ? 1 : $5.to_i
					unless index_score.key?(chrom)
						puts "Reading #{chrom}...."	
						index_score[chrom] = Hash.new() 
					end
				end
			}
		end #end of if currentContent != ""
		currentPage += 1

	end #end of while
	
	idir = @tempDir+@prefix+Time.now().to_f.round.to_s + '_' + rand(1000000).to_s.rjust(6, '0') 
	index_score.each{	|key_chrom,window_hash|
		idir_sub = idir+"/#{key_chrom}"
		puts "creating #{@windowsize}bp window in #{idir_sub}....."
		FileUtils.mkdir_p idir_sub
		stasname = idir_sub+"/#{key_chrom}.sta"
		stasfile = File.open(stasname,"w")
		window_hash.each{	|key,value|
			stasfile.puts "#{key}\t#{value}"
		}
		stasfile.close
	}

	return idir
  end #end of createSignalWindow(sfile)



  def createVariableSignalWindow(sfile)

	fsize = File.size(sfile)
	f = File.new(sfile)

	index_score = Hash.new()
	prevContent = ""
	currentPage = 1	
	puts "Reading #{sfile} ....."
	while currentContent = f.read(@buffer)
		currentContent = prevContent + currentContent	#the first line must be header

		firstStepPos = currentContent.index(/variableStep\s+chrom=(\S+)(\s+span=(\d+)\n|\n)/)
		chrom = $1
		span  = ($3.to_i < 2 ) ? 1 : $3.to_i
		lastStepPos = currentContent.rindex(/variableStep\s+chrom=(\S+)(\s+span=(\d+)\n|\n)/)
		
		#puts "currentPage is #{currentPage}"
		if currentPage*@buffer < fsize			#if not last page
			
			if firstStepPos == nil				#there is no head in page	
				
				#puts "The page has to have at least one head."
				puts "Please check if the file format is valid!"
				@log.error "Error: check #{sfile} if the file format is valid!"
				exit
				#prevContent = currentContent   #roll over becuae current content would continue in the next page
				#currentContent = ""

			else
				if firstStepPos == lastStepPos
					prevContent = currentContent   #roll over becuae current content would continue in the next page
					currentContent = ""
				else
					prevContent = currentContent[lastStepPos..currentContent.length]
					currentContent = currentContent[firstStepPos..lastStepPos-1]
				end
			end
		end

		if currentContent != "" and span == 1   # on purpose because the ($2.to_f * span) takes time, i made if..then..end
			currentContent.each{	|line|
				if line =~ /^(\d+)\s+(\d+\.\d+|\d+)\n/
					cindex = getWindowIndex($1.to_i, @windowsize)
					if index_score[chrom].key?(cindex)
						index_score[chrom][cindex] += $2.to_f
					else
						index_score[chrom][cindex] = $2.to_f
					end
				elsif line =~ /^variableStep\s+chrom=(\S+)(\s+span=(\d+)\n|\n)/
					chrom = $1
					unless index_score.key?(chrom)
						puts "Reading #{chrom}...."
						index_score[chrom] = Hash.new()
					end
				end
			}
		elsif currentContent != "" and span <= 1000
			currentContent.each{	|line|
				if line =~ /^(\d+)\s+(\d+\.\d+|\d+)\n/
					cindex = getWindowIndex($1.to_i, @windowsize)
					if index_score[chrom].key?(cindex)
						index_score[chrom][cindex] += production($2.to_f, span) #($2.to_f * span)
					else
						index_score[chrom][cindex] = production($2.to_f, span) #($2.to_f * span)
					end
				elsif line =~ /^variableStep\s+chrom=(\S+)(\s+span=(\d+)\n|\n)/
					chrom = $1
					unless index_score.key?(chrom)
						puts "Reading #{chrom}...."
						index_score[chrom] = Hash.new()
					end
				end
			}		
		elsif currentContent != "" and span > 1000
			nindex = 0
			nindexscore = 0.0
			currentContent.each{	|line|
				if line =~ /^(\d+)\s+(\d+\.\d+|\d+)\n/
					cindex = getWindowIndex($1.to_i, @windowsize)
					nindex = getWindowIndex($1.to_i + span - 1, @windowsize)
					if cindex == nindex
						if index_score[chrom].key?(cindex)
							index_score[chrom][cindex] += production($2.to_f, span) #($2.to_f * span)
						else
							index_score[chrom][cindex] = production($2.to_f, span) #($2.to_f * span)
						end
					else
						
						if nindex > getWindowIndex(@chrom_size[chrom].to_i , @windowsize)  # to deal with last index which is not greater than chrom size
							limit = @chrom_size[chrom].to_i 
							if index_score[chrom].key?(cindex)
								index_score[chrom][cindex] += production($2.to_f, limit - $1.to_i + 1) #($2.to_f * span)
							else
								index_score[chrom][cindex] = production($2.to_f, limit - $1.to_i + 1) #($2.to_f * span)
							end
						else
							limit = nindex * @windowsize
							if index_score[chrom].key?(cindex)
								index_score[chrom][cindex] += production($2.to_f, limit - $1.to_i) #($2.to_f * span)
							else
								index_score[chrom][cindex] = production($2.to_f, limit - $1.to_i) #($2.to_f * span)
							end
							if index_score[chrom].key?(nindex)
								index_score[chrom][nindex] += production($2.to_f, ($1.to_i + span) - limit)
							else
								index_score[chrom][nindex] = production($2.to_f, ($1.to_i + span) - limit)
							end
							
						end								
					end
				elsif line =~ /^variableStep\s+chrom=(\S+)(\s+span=(\d+)\n|\n)/
					chrom = $1
					unless index_score.key?(chrom)
						puts "Reading #{chrom}...."
						index_score[chrom] = Hash.new()
					end
				end
			}
		end
		currentPage += 1

	end #endo of while

	idir = @tempDir+@prefix+Time.now().to_f.round.to_s + '_' + rand(1000000).to_s.rjust(6, '0') 
	index_score.each{	|key_chrom,window_hash|
		idir_sub = idir+"/#{key_chrom}"
		puts "creating #{@windowsize}bp window in #{idir_sub}....."
		FileUtils.mkdir_p idir_sub
		stasname = idir_sub+"/#{key_chrom}.sta"
		stasfile = File.open(stasname,"w")
		window_hash.each{	|key,value|
			stasfile.puts "#{key}\t#{value}"
		}
		stasfile.close
	}

	return idir
  end #end of createVariableSignalWindow(sfile)


  def createFixedSignalTarget(sfile, tfile)
	
	idir = @tempDir+@prefix+Time.now().to_f.round.to_s + '_' + rand(1000000).to_s.rjust(6, '0') 
	targets = File.read(tfile)
	fsize = File.size(sfile)
	f = File.new(sfile)

	prevContent = ""
	currentPage = 1	
	puts "Reading #{sfile} ....."

	#outfile = File.open("page1.txt","w")
	while currentContent = f.read(@buffer)
		currentContent = prevContent + currentContent	#the first line must be header
		
			#if firstStepPos == nil				#there is no head in page	
				#puts "The page has to have at least one head."
				#puts "Please check if the file format is valid!"
				#exit
			#end

		#puts "currentPage is #{currentPage}"
		chrom_content = Hash.new()
		span = 1
		while currentContent != ""

			firstStepPos = currentContent.index(/fixedStep\s+chrom=(\S+)\s+start=(\d+)\sstep=(\d+)(\s+span=(\d+)\n|\n)/)
			f_chrom = $1
			step  = $3.to_i
			span  = ($5.to_i < 2 ) ? 1 : $5.to_i
			lastStepPos = currentContent.rindex(/fixedStep\s+chrom=(\S+)\s+start=(\d+)\sstep=(\d+)(\s+span=(\d+)\n|\n)/)
			l_chrom = $1
			
			if firstStepPos == lastStepPos or f_chrom == l_chrom
				
				if currentPage*@buffer < fsize
					prevContent = currentContent   #roll over becuae current content would continue in the next page
					currentContent = ""
				else
					chrom_content[f_chrom] = currentContent
					currentContent = ""
				end
			else
				endFirstChromPos = currentContent.rindex(/fixedStep\s+chrom=#{f_chrom}\s+start=(\d+)\sstep=(\d+)(\s+span=(\d+)\n|\n)/)
				startNewChromPos = currentContent.index(/fixedStep\s+chrom=(\S+)\s+start=(\d+)\sstep=(\d+)(\s+span=(\d+)\n|\n)/,endFirstChromPos + 1)
				chrom_content[f_chrom] = currentContent[firstStepPos..startNewChromPos-1]
				currentContent = currentContent[startNewChromPos..currentContent.length]
				
			end
		end
		
		chrom_content.each{	|chrom,subcontent|				
			idir_sub = idir+"/#{chrom}"
			FileUtils.mkdir_p idir_sub
			
			subcontent =~ /^fixedStep\s+chrom=(\S+)\s+start=(\d+)\sstep=(\d+)(\s+span=(\d+)\n|\n)/
			start = $2.to_i
			step  = $3.to_i
			span  = ($5.to_i < 2 ) ? 1 : $5.to_i		
			offset = 0 
			myTarray = targets.scan(/^\S+\s+\S+\s+\S+\s+\S+\s+#{chrom}\s+(\S+)\s+(\S+)\s+/)

			index_score = [] 
			cnt = 0
			lastpos = 0
			nextcontentstart = 0
			
			target_position = []
			myTarray.each{	|target|
				if target[1].to_i >= nextcontentstart and subcontent != nil
					tot_score_index = getFixedScoresWithinRange(subcontent, target[0].to_i, target[1].to_i, start, step, span, offset)
					index_score[cnt] = tot_score_index[0]
					target_position[cnt] = "#{target[0].to_i}\t#{target[1].to_i}"
					lastpos = tot_score_index[1]
					subcontent = subcontent[lastpos+1..subcontent.length]
					nextcontentstart = tot_score_index[2]
					start = tot_score_index[3]
					step = tot_score_index[4]
					span = tot_score_index[5]
					offset = tot_score_index[6]
				else
					index_score[cnt] = 0.0
					target_position[cnt] = "#{target[0].to_i}\t#{target[1].to_i}"
				end
				cnt += 1
			}
			
			puts "creating the regions in #{idir_sub}....."
			stasname = idir_sub+"/#{chrom}.sta"
			stasfile = File.open(stasname,"w")
			#index_score.each{	|key,value|
			#	stasfile.puts "#{key}\t#{value}"
			#}
			index_score.each_index{	|i|
				stasfile.puts "#{i}\t#{index_score[i]}\t#{target_position[i]}"
			}
			stasfile.close

		}
		
		currentPage += 1

	end #end of while

	return idir
  end #end of createFixedSignalTarget(sfile)


  def getFixedStartOffset(tstart, start, step)
  
	i = 0
	while	start + (step * i) <= tstart
	 	i += 1
	end  
		
	return i - 1
  
  end
  
  def getFixedStopOffset(tstop, start, step)
  
	i = 0
	while	start + (step * i) <= tstop
	 	i += 1
	end  
		
	return i
  
  end


  def getFixedScoresWithinRange(subcontent, tstart, tstop, start, step, span, offset)
				
		tot_score = 0.0
		lastpos = 0
		nextcontentstart = tstop
		
		trange = (tstart..tstop)
		subcontent.each{	|line|
			if line =~ /^(\d+|\d+\.\d+)\n/
				pos = start + (offset * step)
				if trange.include?(pos)     #ignoring index change while spanning
					#tot_score += production($1.to_f, span)
					#begin new_code
					unless trange.include?(pos + span - 1)
						tot_score += production($1.to_f, (tstop - pos + 1))
					else
						tot_score += production($1.to_f, span)
					end
					#end new_code

				elsif pos > tstop
					nextcontentstart = pos
					break
				end
				offset += 1
			elsif line =~ /^fixedStep\s+chrom=(\S+)\s+start=(\d+)\sstep=(\d+)(\s+span=(\d+)\n|\n)/
				chrom = $1
				start = $2.to_i
				step = $3.to_i
				span = $5.to_i
				offset = 0
				span  = ($5.to_i < 2 ) ? 1 : $5.to_i
			end
			lastpos += line.length
		}


		return tot_score, lastpos, nextcontentstart, start, step, span, offset
		
  end


  def createVariableSignalTarget(sfile, tfile)

	idir = @tempDir+@prefix+Time.now().to_f.round.to_s + '_' + rand(1000000).to_s.rjust(6, '0') 
	targets = File.read(tfile)
	fsize = File.size(sfile)
	f = File.new(sfile)

	prevContent = ""
	currentPage = 1	
	puts "Reading #{sfile} ....."

	#outfile = File.open("page1.txt","w")
	while currentContent = f.read(@buffer)
		currentContent = prevContent + currentContent	#the first line must be header
		
			#if firstStepPos == nil				#there is no head in page	
				#puts "The page has to have at least one head."
				#puts "Please check if the file format is valid!"
				#exit
			#end

		#puts "currentPage is #{currentPage}"
		chrom_content = Hash.new()
		span = 1
		while currentContent != ""

			firstStepPos = currentContent.index(/variableStep\s+chrom=(\S+)(\s+span=(\d+)\n|\n)/)
			f_chrom = $1
			span  = ($3.to_i < 2 ) ? 1 : $3.to_i
			lastStepPos = currentContent.rindex(/variableStep\s+chrom=(\S+)(\s+span=(\d+)\n|\n)/)
			l_chrom = $1
			
			if firstStepPos == lastStepPos or f_chrom == l_chrom
				
				if currentPage*@buffer < fsize
					prevContent = currentContent   #roll over becuae current content would continue in the next page
					currentContent = ""
				else
					chrom_content[f_chrom] = currentContent
					currentContent = ""
				end
			else
				endFirstChromPos = currentContent.rindex(/variableStep\s+chrom=#{f_chrom}(\s+span=(\d+)\n|\n)/)
				startNewChromPos = currentContent.index(/variableStep\s+chrom=(\S+)(\s+span=(\d+)\n|\n)/,endFirstChromPos + 1)
				chrom_content[f_chrom] = currentContent[firstStepPos..startNewChromPos-1]
				currentContent = currentContent[startNewChromPos..currentContent.length]
				
			end
		end

		chrom_content.each{	|chrom,subcontent|

			puts "Reading #{chrom} ...."
			idir_sub = idir+"/#{chrom}"
			FileUtils.mkdir_p idir_sub

			myTarray = targets.scan(/^\S+\s+\S+\s+\S+\s+\S+\s+#{chrom}\s+(\S+)\s+(\S+)\s+/) 

			index_score = [] 
			cnt = 0
			lastpos = 0
			nextcontentstart = 0

			target_position = []
			myTarray.each{	|target|
				if target[1].to_i >= nextcontentstart and subcontent != nil
					tot_score_index = getVariableScoresWithinRange(subcontent, target[0].to_i, target[1].to_i, span)
					index_score[cnt] = tot_score_index[0]
					target_position[cnt] = "#{target[0].to_i}\t#{target[1].to_i}"
					lastpos = tot_score_index[1]
					subcontent = subcontent[lastpos+1..subcontent.length]
					nextcontentstart = tot_score_index[2]
				else
					index_score[cnt] = 0.0
					target_position[cnt] = "#{target[0].to_i}\t#{target[1].to_i}"
				end
				cnt += 1
			}
			
			puts "creating the regions in #{idir_sub}....."
			stasname = idir_sub+"/#{chrom}.sta"
			stasfile = File.open(stasname,"w")
			#index_score.each{	|key,value|
			#	stasfile.puts "#{key}\t#{value}"
			#}
			index_score.each_index{	|i|
				stasfile.puts "#{i}\t#{index_score[i]}\t#{target_position[i]}"
				
			}
			stasfile.close
		}
		currentPage += 1
	end #while end
	return idir
 
  end
  


  def getVariableScoresWithinRange(subcontent, tstart, tstop, span)
	
	tot_score = 0.0
	lastpos = 0
	nextcontentstart = tstop
	
	trange = (tstart..tstop)
	subcontent.each{ |line|
		if line =~ /^(\d+)\s+(\d+\.\d+|\d+)\n/
			if trange.include?($1.to_i)
				#tot_score += production($2.to_f, span)  #($2.to_f * span)
				#begin new_code
				unless trange.include?($1.to_i + span - 1)
					tot_score += production($2.to_f, (tstop - $1.to_i + 1))
				else
					tot_score += production($2.to_f, span)
				end
				#end new_code
			
			elsif $1.to_i > tstop
				nextcontentstart = $1.to_i
				break
			end
		end
		
		lastpos += line.length
	}
	
	return tot_score, lastpos, nextcontentstart

  end


  def SearchAtlasSim.usage(msg='')
	unless(msg.empty?)
		puts "\n#{msg}\n"
	end
	puts "
    == Synopsis
    searchAtlasSim: searches the user's signal data against one or more target signals, and find the target that best matches the user's signal data.

    == Usage

    searchAtlasSim OPTION

     -h, --help:
       shows help
     --input, -i wig_file_path:
       represents x axis
     --target target_wig_files, -t target_wig_files
       describes target_lff_file against which the regression analysis will be performed.
     --chromosomes tab_delimited_file, -c tab_delimited_file:
       the file includes two columns indicating chromosome and size
     --step fixed or variable, -s fixed or variable
       describes wig file format
     --roi region_of_interest, -r region_of_interest
       describes a subtype in lff file
     --bedgraph boolean, -k boolean
       describes using bedgraph file
     --out filename, -o filename :
       generates output file in LFF format

     "
	exit(2);
  end

end


########################################################################################
# MAIN
########################################################################################


optsArray =
[
  [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
  [ '--input', '-i', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--target', '-t', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--target_name', '-n', GetoptLong::OPTIONAL_ARGUMENT ],
  [ '--chromosomes', '-c', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--step', '-s', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--roi', '-r', GetoptLong::OPTIONAL_ARGUMENT ],
  [ '--bedgraph', '-k', GetoptLong::OPTIONAL_ARGUMENT ],  
  [ '--tempDir', '-D', GetoptLong::OPTIONAL_ARGUMENT ], 
  [ '--out', '-o', GetoptLong::REQUIRED_ARGUMENT ]   
]
opts = GetoptLong.new(*optsArray)

cnt = 0
infile = nil
target = nil
targetname = nil
cfname = nil
step = nil
roi = nil
bedgraph = nil
tempDir = nil
outfname = nil

opts.to_hash.each { |opt, arg|
  case opt
	when '--help'
		searchAtlasSim.usage()
	when '--input'
		infile = arg
    when '--target'
		target = arg
	when '--chromosomes'
		cfname = arg
	when '--step'
		step = arg
	when '--target_name'
		(arg == '') ? searchAtlasSim.usage() : targetname = arg
	when '--roi'
		(arg == '') ? searchAtlasSim.usage() : roi = arg
	when '--bedgraph'
		(arg == '') ? SearchSignalSim.usage() : bedgraph = arg
	when '--tempDir'
		(arg == '') ? searchAtlasSim.usage() : tempDir = arg
    when '--out'
		outfname = arg		
  end
}

if tempDir == nil
	tempDir = "tmp/"
	FileUtils.rm_rf(tempDir)
	FileUtils.mkdir_p tempDir
end

logfname = tempDir+"searchAtlasSim_log.txt"
log = Logger.new(logfname)

unless(opts.getMissingOptions().empty?)
	SearchAtlasSim.usage("USAGE ERROR: some required arguments are missing")
	log.error "Missing option (try --help)"
	exit
end


beginning = Time.now
puts "Begin : #{beginning}"

searchAtlasSim =SearchAtlasSim.new(infile,target,targetname, cfname, step, roi, bedgraph, tempDir, outfname, log)

begin
	searchAtlasSim.work()
rescue StandardError => bang
	log.error bang.message
	log.error bang.backtrace.inspect
	print "Error : " +bang.message + "\n";
	print "Error inpect : " +bang.backtrace.inspect + "\n";
	exit
end

log.debug "If you have this line, you have completed running the searchAtlasSim tool!"

puts "Now : #{Time.now}"
puts "Time elapsed #{Time.now - beginning} seconds"
