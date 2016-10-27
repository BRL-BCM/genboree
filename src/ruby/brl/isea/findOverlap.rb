#!/usr/bin/env ruby

# * *Author*: Matthew Linnell
# * *Desc*: Main driver for finding the overlap domains of different ftype annotations based on histology, tissue type
require 'brl/isea/segmentOverlap'
require 'brl/isea/formatData'
require 'brl/isea/table'
require 'brl/isea/util'
require 'brl/util/propTable' # for PropTable class

module BRL ; module ISEA 

    begin
        time_it = false    # Show timings if true
        $stdout.puts "Stage: #{stage = 0} (#{Time.now})" if time_it
        
        query    = SegmentOverlap.new( "~/.dbrc", "andrewj_keyword" )
        ftypes   = query.ftype_types
        subtypes = query.ftype_subtypes
        
        #==========================================================================#
        # HANDLE INPUT                                                             #
        #==========================================================================#
        # --help information
        hsh = Util::pair_options( ARGV )
        if !ARGV.empty? && ( ARGV.include?( "-h" ) || ARGV.include?( "--h" ) || ARGV.include?( "-help" ) || ARGV.include?( "--help" ) )
            if ARGV.include?( "tissue" )
                tissue_list = query.expand_column( "libTissue" )
                puts "Valid tissue types:"
                puts tissue_list
            elsif ARGV.include?( "histology" )
                histology_list = query.expand_column( "libHistology" )
                puts "Valid histologies:"
                puts histology_list
            elsif ARGV.include?( "ftype" )
                puts "Valid ftypes: #{ftypes.join( ", " )}"
                puts "Valid ftype_subtypes: #{subtypes.join( ", " )}"
            else
                printf "\nFindOverlap invocation syntax:\n"
                printf "\truby FindOverlap.rb -p <properties_file>\n\n"
                printf "The following will override their corresponding value in the property file if provided at the command line:\n"
                printf "\tArgument\t\tMeaning\n"
                printf "\t--------\t\t-------\n"
                printf "\t-h\t\t\tHelp\n"
                printf "\t-h tissue\t\tList possible tissue types.\n"
                printf "\t-h histology\t\tList possible histology types.\n"
                printf "\t-h ftype\t\tList possible ftypes and ftype_subtypes.\n"
                printf "\t-tissue_1\t\tTissue type (e.g. 'ovary' or 'liver' )\n"
                printf "\t-tissue_2\t\tTissue type (e.g. 'ovary' or 'liver' )\n"
                printf "\t-histology_1\t\tTissue type (e.g. 'normal' or 'normal' )\n"
                printf "\t-histology_2\t\tTissue type (e.g. 'normal' or 'normal' )\n"
                printf "\t-target_chromosome\tSpecify target chromosome.\n"
                printf "\t-file_name\t\tSpecify output file name, overwriting the old file if present\n"
                printf "\t-window_specs [window_size, boundary_overlap]\tTurns on Absolute genomic positioning( Sliding window )( default window_size/overlap: 25000,0 )\n\n"
            end 
            query.disconnect
            terminate_ok = true
            Kernel.exit
        end
        
        # Load properties file, command line arguments
        begin
            PROP_KEYS = %w{
                target_chromosome
                mode
                window_specs
                tissue_group_A
                tissue_group_B
                histology_group_A
                histology_group_B
                library_ftype
                target_ftype
                file_name
                filter_all
                filter_tissue_A
                filter_tissue_B
                filter_histology_A
                filter_histology_B
            }
            
            optsHash = Hash.new
            ARGV.each_index{ |i|
                optsHash.store( ARGV[i], ARGV[i+1] )
                i += 1
            }
            
            unless ARGV.include?( "--help" )
                @propTable = BRL::Util::PropTable.new( File.open( optsHash["-p"] ) )
                PROP_KEYS.each { |propName|
                    argPropName = "-#{propName}"   # <-- or whatever works
                    unless( optsHash[argPropName].nil? )
                        @propTable[propName] = optsHash[argPropName]
                    end
                }
                
                @propTable.verify( PROP_KEYS )
            end
        rescue => e
            $stderr.puts e.message
        end
        
        # Parse chromosome list.  Standardize all input (1, chr2, y, chr3_1_fdata) to look like chr1_1_fdata)
        full_list = query.get_chromosome_list()
        if( @propTable["target_chromosome"].type == String )
            @propTable["target_chromosome"].upcase == "ALL" ? @propTable["target_chromosome"] = full_list : @propTable["target_chromosome"] = [ @propTable["target_chromosome"] ]
        end
        if( @propTable["target_chromosome"].type == Array )
            chr_list = @propTable["target_chromosome"]
            chr_list.each_index{ |ii|
                next if( chr_list[ii] =~ /chr[xymXYM0-9]{1,2}_1_fdata/ )
                if( chr_list[ii] =~ /chr[xymXYM0-9]{1,2}/ )
                    chr_list[ii] = chr_list[ii][0..-2] << chr_list[ii][-1,1].upcase << "_1_fdata"
                elsif chr_list[ii] =~ /[xymXYM0-9]{1,2}/
                    chr_list[ii] = "chr" << chr_list[ii].upcase << "_1_fdata"
                end
            }
        end
        # Check to see if all these chromosomes/fdata tables exist, warn user if one does not
        chr_list.each{ |cc|
            if( !full_list.include?( cc ) )
                $stdout.puts "**WARNING: Unknown chromosome or fdata file: #{cc}.  Ignoring"
                chr_list.delete( cc )
            end
        }
        
        # Establish constants
        LIB_KEYWORDS = "libKeywords"
        @propTable["filter_all"]         == nil ? filter_all         = nil : filter_all         = Regexp.compile( @propTable["filter_all"] )
        @propTable["filter_tissue_A"]    == nil ? filter_tissue_1    = nil : filter_tissue_1    = Regexp.compile( @propTable["filter_tissue_A"] )
        @propTable["filter_tissue_B"]    == nil ? filter_tissue_2    = nil : filter_tissue_2    = Regexp.compile( @propTable["filter_tissue_B"] )
        @propTable["filter_histology_A"] == nil ? filter_histology_1 = nil : filter_histology_1 = Regexp.compile( @propTable["filter_histology_A"] )
        @propTable["filter_histology_B"] == nil ? filter_histolgoy_2 = nil : filter_histology_2 = Regexp.compile( @propTable["filter_histology_B"] )
        
        # Process command line arguments
        # The final form has everything in an Hash, where the key is the tissue type, the value is boolean and is whether it should be present (1), or not (0)
        tissue_1_type = Hash.new
        tissue_2_type = Hash.new
        @propTable["tissue_group_A"].type == String ? tissue_1_type[@propTable["tissue_group_A"]] =  1 : @propTable["tissue_group_A"].each{ |tt| tissue_1_type[tt] = 1 }
        if @propTable["tissue_group_B"].type == String
            if @propTable["tissue_group_B"].upcase == "OTHER" 
                tissue_2_type = tissue_1_type.dup
                tissue_2_type.each_key{ |k| tissue_2_type[k] = 0 }
            else
                tissue_2_type[@propTable["tissue_group_B"]] = 1
            end
        else
            @propTable.each{ |tt| tissue_2_type[tt] = 1 }
        end 
        # The final form has everything in an Hash, where the key is the histology type, the value is boolean and is whether it should be present (1), or not (0)
        histology_1_type = Hash.new
        histology_2_type = Hash.new
        @propTable["histology_group_A"].type == String ? histology_1_type[@propTable["histology_group_A"]] =  1 : @propTable["histology_group_A"].each{ |tt| histology_1_type[tt] = 1 }
        if @propTable["histology_group_B"].type == String
            if @propTable["histology_group_B"].upcase == "OTHER" 
                histology_2_type = histology_1_type.dup
                histology_2_type.each_key{ |k| histology_2_type[k] = 0 }
            else
                histology_2_type[@propTable["histology_group_B"]] = 1
            end
        else
            @propTable.each{ |tt| histology_2_type[tt] = 1 }
        end 
        
        ftype_type_library      = @propTable["library_ftype"][0]
        ftype_subtype_library   = @propTable["library_ftype"][1]
        ftype_type_target       = @propTable["target_ftype"][0]
        ftype_subtype_target    = @propTable["target_ftype"][1]
        if @propTable["mode"] != "refseq"
            $stdout.puts "Unknown Window Specificiations: #{@propTable["window_specs"]}.  Exiting." if @propTable["window_specs"] == nil
            window_size, boundary_size = @propTable["window_specs"].map!{ |ii| ii.to_i }
            left_column_name = "Window #"
        else
            left_column_name = "refGene Accession #"
        end
        
        #==========================================================================#
        # BEGIN EXECUTION OF MAPPING (begin looping over each chromosome)          #
        #==========================================================================#
        chr_list.each{ |chr|
            begin
            $stdout.puts "Starting: #{chr} (#{Time.now})"
            # File IO management
            begin
                file = File.open( "#{chr}_#{@propTable["file_name"]}", File::CREAT|File::TRUNC|File::RDWR )
            rescue => e
                $stderr.puts "Problem opening #{chr}_#{@propTable["file_name"]} for write.  Advancing to next chromosome"
                $stderr.puts e.message
                $stderr.puts e.backtrace
                next
            end
                
            
            # Cache the fdatatoc_id of this chr for future reference
            fdatatoc_id = query.get_fdatatoc_id( chr )
            
            $stdout.puts "Stage: #{stage = 1} (#{Time.now})" if time_it
            # Send acquired data to SegmentOverlap for comparison
            if @propTable["mode"] == "refseq"
                # First, get basic fdata/fgroup information
                data = query.compare( ftype_type_library, ftype_subtype_library, ftype_type_target, ftype_subtype_target, chr )
                # With these hits, we now need to extract keyword_id, fname_id, and fname_value
                keyword_ids = Array.new
                fname_values = Array.new
                data.each_row { |row|
                    begin
                        keyword_ids.push( query.getLibraryId( chr, row[ data.columns.index( "est_fdata_id" ) ], fdatatoc_id ) )
                        fname_values.push( query.get_fname_info( chr, row[ data.columns.index( "target_fdata_id" ) ] ) )
                    rescue => e
                        $stderr.puts "ERROR"
                        $stderr.puts "C:#{chr} :: R:#{row[ data.columns.index( "est_fdata_id")]} :: F:#{fdatatoc_id}"
                        $stderr.puts e.message
                        $stderr.puts e.backtrace
                    end
                        
                }
                keyword_ids.reverse!
                fname_values.reverse!
                data.addColumn!( "est_keyword_id", keyword_ids )
                data.addColumn!( "fname_value", fname_values )
                
                group_by = "est_keyword_id"     # Which field to group the libraries by
                processed_column_names = query.unique_group_names( ftype_type_target, ftype_subtype_target, chr )
            else
                data = query.compareAbsolute( ftype_type_library, ftype_subtype_library, chr, window_size, boundary_size ) if data == nil
                keyword_ids = Array.new
                fname_values = Array.new
                data.each_row { |row|
                    keyword_ids.push( query.getLibraryId( chr, row[ data.columns.index( "est_fdata_id" ) ], fdatatoc_id ) )
                    fname_values.push( row[ data.columns.index( "fname_value" ) ] )
                }
                keyword_ids.reverse!
                fname_values.reverse!
                data.addColumn!( "est_keyword_id", keyword_ids )
                group_by = "est_keyword_id"    # AKA window_number in this case
                
                max_windows = query.total_windows( chr, window_size, boundary_size )
                processed_column_names = Array.new
                index = 1
                while( index <= max_windows )
                    processed_column_names.push( index )
                    index += 1
                end
            end
            
            histology = query.compareToKeywords( "cgap" )
            
            # Format our results
            f = FormatData.new
            $stdout.puts "Stage: #{stage = 2} (#{Time.now})" if time_it
            format_data = f.format_for_hits( data, group_by, processed_column_names, "normal" )
            $stdout.puts "Stage: #{stage = 3} (#{Time.now})" if time_it
            format_histology = f.format_for_hits( histology, "keyword_id", histology.columns, "keyword" )
            
            $stdout.puts "Stage: #{stage = 4} (#{Time.now})" if time_it
            # Find the keyword_ids( libraries ) who are labeled as "cancer" or whatever other tissue/histology we are looking for
            # Since each group could have more than one tissue or histology, we have to loop over, and add from each group
            ovarian_keywords = Table.new
            tissue_1_type.each_pair{ |k,v|
                ovarian_keywords += Util.filter_table( format_histology, k, v )
            }
            non_ovarian_keywords = Table.new
            tissue_2_type.each_pair{ |k,v|
                non_ovarian_keywords += Util.filter_table( format_histology, k, v )
            }
            cancerous_keywords = Table.new
            histology_1_type.each_pair{ |k,v|
                cancerous_keywords += Util.filter_table( format_histology, k, v )
            }
            non_cancerous_keywords = Table.new
            histology_2_type.each_pair{ |k,v|
                non_cancerous_keywords += Util.filter_table( format_histology, k, v )
            }
            
            
            # Grab keywords which fit {filter_*} criteria
            filter_all.nil?         ? filter_all_table         = Table.new : filter_all_table         = Util.filter_table( format_histology, LIB_KEYWORDS, filter_all,         "keep" )
            filter_tissue_1.nil?    ? filter_tissue_1_table    = Table.new : filter_tissue_1_table    = Util.filter_table( format_histology, LIB_KEYWORDS, filter_tissue_1,    "keep" )
            filter_tissue_2.nil?    ? filter_tissue_2_table    = Table.new : filter_tissue_2_table    = Util.filter_table( format_histology, LIB_KEYWORDS, filter_tissue_2,    "keep" )
            filter_histology_1.nil? ? filter_histology_1_table = Table.new : filter_histology_1_table = Util.filter_table( format_histology, LIB_KEYWORDS, filter_histology_1, "keep" )
            filter_histology_2.nil? ? filter_histology_2_table = Table.new : filter_histology_2_table = Util.filter_table( format_histology, LIB_KEYWORDS, filter_histology_2, "keep" )
            
            # And, finally, reduce our keywords to fit the (above) filtered criteria
            cancerous_keywords     = Util.arr_to_hash( ( ( cancerous_keywords     - filter_all_table ) - filter_histology_1_table ).getColumn( 1 ) )
            ovarian_keywords       = Util.arr_to_hash( ( ( ovarian_keywords       - filter_all_table ) - filter_tissue_1_table ).getColumn( 1 ) )
            non_ovarian_keywords   = Util.arr_to_hash( ( ( non_ovarian_keywords   - filter_all_table ) - filter_tissue_2_table ).getColumn( 1 ) )
            non_cancerous_keywords = Util.arr_to_hash( ( ( non_cancerous_keywords - filter_all_table ) - filter_histology_2_table ).getColumn( 1 ) )
            
            # Find those keywords which match different pairs of these criteria (i.e. are _both_ ovarian and cancerous, or _both_ ovarian and non_cancerous
            ovarian_cancer_keywords         = Hash.new
            ovarian_non_cancer_keywords     = Hash.new
            non_ovarian_cancer_keywords     = Hash.new
            non_ovarian_non_cancer_keywords = Hash.new
            cancerous_keywords.each_key { |keyword|
                ovarian_cancer_keywords.store( keyword, true) if ovarian_keywords.has_key?( keyword )
                non_ovarian_cancer_keywords.store( keyword, true ) if non_ovarian_keywords.has_key?( keyword )
            }
            non_cancerous_keywords.each_key { |keyword|
                non_ovarian_non_cancer_keywords.store( keyword, true ) if non_ovarian_keywords.has_key?( keyword )
                ovarian_non_cancer_keywords.store( keyword, true ) if ovarian_keywords.has_key?( keyword )
            }
            
            # Calculate hits based on library
            $stdout.puts "Stage: #{stage = 4.5} (#{Time.now})" if time_it
            ovarian_cancer_set         = f.total_refgene_hits( format_data, ovarian_cancer_keywords )           # A hash who key=refGene and value=#hits
            ovarian_non_cancer_set     = f.total_refgene_hits( format_data, ovarian_non_cancer_keywords )       # A hash who key=refGene and value=#hits
            non_ovarian_cancer_set     = f.total_refgene_hits( format_data, non_ovarian_cancer_keywords )       # A hash who key=refGene and value=#hits
            non_ovarian_non_cancer_set = f.total_refgene_hits( format_data, non_ovarian_non_cancer_keywords )   # A hash who key=refGene and value=#hits
            
            $stdout.puts "Stage: #{stage = 5} (#{Time.now})" if time_it
            assoc = [ ovarian_cancer_set, ovarian_non_cancer_set, non_ovarian_cancer_set, non_ovarian_non_cancer_set ]
            score = Array.new( 4 ){ Hash.new }  # For generating #EST/Lib_Total
            score.each_index { |i|
                score[i] = Util.arr_to_hash( fname_values )
                score[i].each_key{ |key|
                    score[i][key] = Array.new
                }
            }
            
            $stdout.puts "Stage: #{stage = 6} (#{Time.now})" if time_it
            # Calculate the total possible EST count per library
            global_count_index = 0
            global_count = Array.new( 4 ){ Hash.new }
            
            library_member_count = Hash.new
            assoc.each { |a|
                a[1].each_pair { |key, val|
                    # Sum the total possible EST values for each library
                    sum = 0
                    val.each{ |lib|
                        library_member_count.store( lib, query.member_count( chr, lib, fdatatoc_id ) ) unless library_member_count.has_key?( lib )
                        temp = library_member_count[lib]
                        sum += temp
                        global_count[global_count_index].store( lib, temp )
                        score[global_count_index][key].push( "#{a[0][key][lib]}/#{temp}:" )
                    }
                    a[2][key] = sum
                }
                global_count_index += 1
            }
            
            $stdout.puts "Stage: #{stage = 7} (#{Time.now})" if time_it
            score.each_index{ |i|
               score[i].each_key{ |key|
                   score[i][key] == nil ? score[i][key] = "0" : score[i][key] = score[i][key].join 
               }
            }
            
            $stdout.puts "Stage: #{stage = 8} (#{Time.now})" if time_it
            # Calculate the total possible possible EST for _all_ the possible libraries that could have hit (not just those that did)
            ovarian_cancer_possible_ests = 0
            ovarian_non_cancer_possible_ests = 0
            non_ovarian_cancer_possible_ests = 0
            non_ovarian_non_cancer_possible_ests = 0
            ovarian_cancer_keywords.each_key{ |i|
                members = query.member_count( chr, i, fdatatoc_id )
                ovarian_cancer_possible_ests += members 
            }
            ovarian_non_cancer_keywords.each_key{ |i| 
                members = query.member_count( chr, i, fdatatoc_id )
                ovarian_non_cancer_possible_ests += members
            }
            non_ovarian_cancer_keywords.each_key{ |i| 
                members = query.member_count( chr, i, fdatatoc_id )
                non_ovarian_cancer_possible_ests += members 
            }
            non_ovarian_non_cancer_keywords.each_key{ |i| 
                members = query.member_count( chr, i, fdatatoc_id )
                non_ovarian_non_cancer_possible_ests += members
            }
            
            $stdout.puts "Stage: #{stage = 9} (#{Time.now})" if time_it
            # Calculate the total possible EST hits per column (which has multiple libraries)
            global_count_index = 0
            possible_est_count = Array.new( 4, 0 )
            possible_est_count.each { |count_i|
                global_count[global_count_index].each_value { |val|
                    possible_est_count[global_count_index] += val
                }
                global_count_index += 1
            }
            
            $stdout.puts "Stage: #{stage = 10} (#{Time.now})" if time_it
            # Retrive total EST hits information
            est_hit_set = Array.new( 4 ) { Hash.new }
            index = 0
            assoc.each { |set|
                set[0].each_key { |key|
                    sum = 0
                    if set[0][key].type == Hash
                        set[0][key].each_pair{ |k, v|
                            sum += v
                        }
                    end
                    est_hit_set[index].store( key, sum )
                }
                index += 1
            }
            
            #======================================================================#
            # MERGE RESULTS, PREPARE FOR OUTPUT                                    #
            #======================================================================#
            $stdout.puts "Stage: #{stage = 11} (#{Time.now})" if time_it
            # Prepare tables for output
            tbl_1S = Util.hash_to_table( score[0] )
            tbl_2S = Util.hash_to_table( score[1] )
            tbl_3S = Util.hash_to_table( score[2] )
            tbl_4S = Util.hash_to_table( score[3] )
            
            tissue_1_names = ""
            tissue_1_type.each_key{ |k| tissue_1_names << k << "/" }
            tissue_2_names = ""
            tissue_2_type.each_key{ |k| tissue_2_names << k << "/" }
            histology_1_names = ""
            histology_1_type.each_key{ |k| histology_1_names << k << "/" }
            histology_2_names = ""
            histology_2_type.each_key{ |k| histology_2_names << k << "/" }
            
            # Merging tables -> EX. {A , B} merge with {A, C} to produce {A, B, C}
            tbl_1  = Util.hash_to_table( est_hit_set[0] )
            tbl_1A = Util.merge_tables( tbl_1, Util.merge_tables(Util.hash_to_table(ovarian_cancer_set[1]), Util.hash_to_table( ovarian_cancer_set[2]) ) )
            tbl_1A = Util.merge_tables( tbl_1A, tbl_1S)
            tbl_1A.setColumnNames( ["#{left_column_name}", "#{tissue_1_names[0..-2]} #{histology_1_names[0..-2]}", "#{tissue_1_names[0..-2]} #{histology_1_names[0..-2]} (unique libraries)", "#{tissue_1_names[0..-2]} #{histology_1_names[0..-2]} (possible est's)", "Score"] )
            
            tbl_2 = Util.hash_to_table( est_hit_set[1] )
            tbl_2A = Util.merge_tables( tbl_2, Util.merge_tables(Util.hash_to_table(ovarian_non_cancer_set[1]), Util.hash_to_table( ovarian_non_cancer_set[2]) ) )
            tbl_2A = Util.merge_tables( tbl_2A, tbl_2S)
            tbl_2A.setColumnNames( ["#{tissue_1_names[0..-2]} Non-#{histology_2_names[0..-2]}",  "#{tissue_1_names[0..-2]} Non-#{histology_2_names[0..-2]} (unique libraries)", "#{tissue_1_names[0..-2]} Non-#{histology_2_names[0..-2]} (possible est's)", "Score"] )
            
            tbl_3 = Util.hash_to_table( est_hit_set[2] )
            tbl_3A = Util.merge_tables( tbl_3, Util.merge_tables(Util.hash_to_table(non_ovarian_cancer_set[1]), Util.hash_to_table( non_ovarian_cancer_set[2]) ) )
            tbl_3A = Util.merge_tables( tbl_3A, tbl_3S)
            tbl_3A.setColumnNames( ["Non-#{tissue_2_names[0..-2]} #{histology_1_names[0..-2]}",  "Non-#{tissue_2_names[0..-2]} #{histology_1_names[0..-2]} (unique libraries)", "Non-#{tissue_2_names[0..-2]} #{histology_1_names[0..-2]} (possible est's)", "Score"] )
            
            tbl_4 = Util.hash_to_table( est_hit_set[3] )
            tbl_4A = Util.merge_tables( tbl_4, Util.merge_tables(Util.hash_to_table(non_ovarian_non_cancer_set[1]), Util.hash_to_table( non_ovarian_non_cancer_set[2]) ) )
            tbl_4A = Util.merge_tables( tbl_4A, tbl_4S)
            tbl_4A.setColumnNames( ["Non-#{tissue_2_names[0..-2]} Non-#{histology_2_names[0..-2]}",  "Non-#{tissue_2_names[0..-2]} Non-#{histology_2_names[0..-2]} (unique libraries)", "Non-#{tissue_2_names[0..-2]} Non-#{histology_2_names[0..-2]} (possible est's)", "Score"] )
            
            $stdout.puts "Stage: #{stage = 11.2} (#{Time.now})" if time_it
            # Merge the tables into the final product.
            tbl_5 = Util.merge_tables( tbl_1A, tbl_2A )
            tbl_6 = Util.merge_tables( tbl_5,  tbl_3A )
            tbl_7 = Util.merge_tables( tbl_6,  tbl_4A )
            tbl_7.push( [ "", "", "", "Possible ESTs from Hit Libs", possible_est_count[0], "", "", "Possible ESTs from Hit Libs", possible_est_count[1], "", "", "Possible ESTs from Hit Libs",possible_est_count[2], "", "", "Possible ESTs from Hit Libs",possible_est_count[3] ] )
            tbl_7.push( [ "", "", "", "Possible Libraries", ovarian_cancer_keywords.length, "", "", "Possible Libraries", ovarian_non_cancer_keywords.length, "", "", "Possible Libraries", non_ovarian_cancer_keywords.length, "", "", "Possible Libraries", non_ovarian_non_cancer_keywords.length ] )
            tbl_7.push( [ "", "", "", "Possible ESTs from _ALL_ Libs", ovarian_cancer_possible_ests, "", "", "Possible ESTs from _ALL_ Libs", ovarian_non_cancer_possible_ests, "", "", "Possible ESTs from _ALL_ Libs", non_ovarian_cancer_possible_ests, "", "", "Possible ESTs from _ALL_ Libs", non_ovarian_non_cancer_possible_ests ] )
            # Output data to file
            file << tbl_7.to_s
            file.close
            $stdout.puts "Finished: #{chr} (#{Time.now})\n"
            rescue => e
                $stderr.puts "Program terminated abormally during #{chr} in stage #{stage}.  Attempting next chromosome."
                $stderr.puts e.message
                $stderr.puts e.backtrace
                next
            end
        }
        query.disconnect
        terminate_ok = true
    ensure
        $stdout.puts "Program terminated abnormally in Stage: #{stage} #{Time.now}." if terminate_ok != true
    end

end ; end # end module ISEA ; end module BRL
