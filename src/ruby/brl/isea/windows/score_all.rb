# Inserts NCBI hyperlinks in the Excel file, the first column, save row 1 (the header)
require 'win32ole'

module Util
    def Util::arr_to_hash( in_arr, *default )
        hsh = Hash.new
        if( in_arr == nil)
            return hsh
        elsif( in_arr[0].type == Array )
        in_arr.each_index{ |i|
            hsh.store( in_arr[i][0], in_arr[i][1] )
        }
        else
            val = default.first
            in_arr.each { |i|
                hsh.store( i, val )
            }
        end
        return hsh
    end
end

module Math
    ########################################################################
    # * *Function*: Determines the standard deviation of the given data.
    #
    # * *Usage*   : <tt>  myMath.stdev( [1, 2, 3] )  </tt>
    # * *Args*    :
    #   - +val_array+ -> Of type Array, contains the values for which we wish to know the standard deviation
    # * *Returns* :
    #   - +result+ -> The standard deviation of the given numbers
    # * *Throws* :
    #   - +none+
    ########################################################################
    def Math.stdev( val_array )
        n   = val_array.length
        return nil if n == 0
        sum = 0.0
        val_array.each{ |val|
            sum += val
        }
        avg = sum/n

        sum_squares = 0.0
        val_array.each{ |val|
            sum_squares += ( val - avg ) * ( val - avg )
        }
        result = sqrt( (sum_squares/n).abs )
    end
end




# Creates OLE object to Excel
excel = WIN32OLE::new('excel.Application')
excel.visible = false   # Make visible -- *NOTE* runs _much_ slower
WIN32OLE.const_load( excel )
        
# Grab a list of all the data that is present in the current directory
wd = Dir.getwd
chr_list = Array.new
Dir.foreach("."){ |ii|
    chr_list.push( ii ) if ii =~ /chr.*_1_fdata/
}

begin
puts Time.now
    chr_list.each{ |chr|
        puts chr
        str = "#{wd}/#{chr}"
        windowed = true if ARGV.include?( "-w" )    # Detects if this data is in sliding window mode (we don't want to hyperlink window numbers)
        # Must load the WIN32OLE constants for use
        # Note, most of these constants are documented as starting with a lower case "x" in actual windows documentation
        # but seem to only work when the first letter as uppercase (perhaps because ruby consts start w/ uppercase?)
        begin
            workbook = excel.Workbooks.Open( str )
        rescue 
            puts "Unable to open file\n\t'#{str}'\nCheck path, filename, and permissions."
            excel.quit()
            exit()
        end
        
        worksheet_index = 1
        worksheet_count = workbook.Worksheets.count
        # Loop through each worksheet
        while( worksheet_index <= worksheet_count ) do
            worksheet = workbook.Worksheets(worksheet_index)
            worksheet.Select    
            line = 1
            while worksheet.Range("A#{line}").value
                line+= 1
            end #line now holds row number of first empty row
            length = line + 2
            
            data = worksheet.Range( String.new( "a1:a#{line}" ) ).value
            # Hyplerlink the accession numbers
            unless windowed
                2.upto(line-1) { |i|
                    cell = "a#{i}"
                    val = "(\"http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=nucleotide&cmd=search&term=#{data[i-1]}\", \"#{data[i-1]}\")"
                    worksheet.Range( cell ) ['Formula'] = "=HYPERLINK#{val}"
                }
            end
            
            # Create the borders for readability
            worksheet.Range( "A1:T1" ).borders( WIN32OLE::XlEdgeBottom).weight = WIN32OLE::XlMedium
            worksheet.Range( String.new( "E1:E#{line + 3}" ) ).borders( WIN32OLE::XlEdgeRight).weight = WIN32OLE::XlMedium
            worksheet.Range( String.new( "I1:I#{line + 3}" ) ).borders( WIN32OLE::XlEdgeRight).weight = WIN32OLE::XlMedium
            worksheet.Range( String.new( "M1:M#{line + 3}" ) ).borders( WIN32OLE::XlEdgeRight).weight = WIN32OLE::XlMedium
            
            # Wrap the text in row 1 (column headers) for readability
            worksheet.Range( String.new( "A1:U1" ) )['WrapText'] = true
            
            # Autofit column A
            worksheet.Columns("A").AutoFit
            
            # Filter rows that contain all 0's in the first 2 histological columns (ie the first 8 columns)
            line = 2
            while worksheet.Range("A#{line}").value
                data = worksheet.Range( String.new( "B#{line}:Q#{line}" ) ).value
                break if data[0][0]==nil
                sum = 0
                data.each { |cell|
                    # I don't understand why I need this.  It is as if data is doubly nested in an array
                    cell.each { |i|     
                        sum += i.to_i
                    }
                }
                if ( sum == 0 )
                    worksheet.Range( String.new( "A#{line}:Q#{line}" ) ).delete( WIN32OLE::XlShiftUp )
                    length -= 1
                end
                line += 1
            end
            
            # Process the scores columns (E, I, M, Q)
            ["E", "I", "M", "Q"].each{ |column|
                data = worksheet.Range( "#{column}2:#{column}#{line-1}" ).value
                cell_index = 2
                
                data.each{ |cell|
                    cell.each{ |i|
                        if( i == 0 || i == nil )
                            worksheet.Range( "#{column}#{cell_index}" ).value = "0.0/0.0"
                            next
                        end
                        index = 0
                        indiv_scores = i.scan( /[\d]*\/[\d]*/ )
                        separated_scores = Array.new( indiv_scores.length )
                        separated_scores.each_index{ |i|
                            separated_scores[i] = Array.new
                        }
            
                        indiv_scores.each { |score|
                            separated_scores[index].concat( score.split( /\// ) )
                            index += 1
                        }
                        sum = 0
                        ratio_arr = Array.new       # For use in later determining STDEV
                        separated_scores.each{ |num|
                            next if( num[1] == nil || num[0] == nil )
                            next if( num[1].to_f < 10 )     # Minimum library size requirement
                            sum += num[0].to_f/num[1].to_f
                            ratio_arr.push( num[0].to_f/num[1].to_f )
                        }
                        average = sum/separated_scores.length
                        # I want to use stdev later only if there were 5+ libraries.  Otherwise, stdev is not useful.
                        # In this case, I will be using a strict ratio for comparison, such that A << B if A is 1/2 B, or if A >> B, A = 2B
                        stdev = Math.stdev( ratio_arr )
                        stdev = average * .2 unless( ratio_arr.length >= 5 )   # An arbitrary value for evaluation when N in stdev is too small
                        worksheet.Range( "#{column}#{cell_index}" ).value = String.new( "#{average}/#{stdev}" )
                    }
                    cell_index += 1
                }
            }
            
            rank_hsh = Hash.new
            rank2_hsh = Hash.new
            rank3_hsh = Hash.new
            worksheet.Range( "R1" ).value = "E >> I AND M ~= Q"
            worksheet.Range( "S1" ).value = "E >> I AND M >> Q"
            worksheet.Range( "T1" ).value = "A/possible >> B/possible"
            
            2.upto(line-1) { |num|
                avg_A, stdev_A = worksheet.Range( "E#{num}" ).value.split( "/" )
                avg_B, stdev_B = worksheet.Range( "I#{num}" ).value.split( "/" )
                avg_C, stdev_C = worksheet.Range( "M#{num}" ).value.split( "/" )
                avg_D, stdev_D = worksheet.Range( "Q#{num}" ).value.split( "/" )
                
                # IF A >> B AND C ~= D, score = A - (B + stdev(B) ) where D-stdev(D) < C < D + stdev(D)
                worksheet.Range( "R#{num}" ).formula = "=IF(AND(#{avg_A} > #{avg_B} + #{stdev_B}*3, #{avg_C} > (#{avg_D}-#{stdev_D}), #{avg_C} < (#{avg_D}+#{stdev_D})), #{avg_A} - (#{avg_B} + #{stdev_B}*3), 0 )"
                # IF A >> B AND C >> D, score = A - (B + stdev(B) ) + C - (D + stdev(D) )
                worksheet.Range( "S#{num}" ).formula = "=IF(AND(#{avg_A} > #{avg_B} + #{stdev_B}*3, #{avg_C} > #{avg_D} + #{stdev_D}*3), (#{avg_A} - #{avg_B} + #{stdev_B}*3) + #{avg_C} - (#{avg_D} + #{stdev_D}*3), 0 )"
                # IF A.hits/possible 3X B.hits/possible, score = A.hits/possible / (b.hits/possible)
                
                if( worksheet.Range( "F#{num}" ).value / worksheet.Range( "I#{length}" ).value != 0 && 
                    worksheet.Range( "B#{num}" ).value / worksheet.Range( "E#{length}" ).value != 0 )
                    worksheet.Range( "T#{num}" ).formula = "=IF(B#{num}/$E$#{length} > F#{num}/$I$#{length}*3, B#{num}/$E$#{length}/(F#{num}/$I$#{length}), 0)"
                elsif( worksheet.Range( "B#{num}" ).value / worksheet.Range( "E#{length}" ).value != 0 )
                    worksheet.Range( "T#{num}" ).formula = "=IF(B#{num}/$E$#{length} > F#{num}/$I$#{length}*3, 10, 0)"
                else
                    worksheet.Range( "T#{num}" ).value = 0
                end
    
                rank_hsh.store(  worksheet.Range( "A#{num}" ).value, worksheet.Range( "R#{num}" ).value )
                rank2_hsh.store( worksheet.Range( "A#{num}" ).value, worksheet.Range( "S#{num}" ).value )
            }
    
            # Once all the "scoring" is done, lets rank them based on each given criteria
            # For example, given criteria A, B, and C, rank where the refgene with the best overall ABC first, etc.    aa = rank_hsh.sort{ |a,b| a[1]<=> b[1] }
            aa = rank_hsh.sort{ |a,b| a[1]<=> b[1] }
            bb = rank2_hsh.sort{ |a,b| a[1]<=> b[1] }
            
            aa.reverse!
            bb.reverse!
            
            aa.each_index{ |i|
                aa[i][1] = i + 1
            }
            
            bb.each_index{ |i|
                bb[i][1] = i + 1
            }    
    
            aa = Util.arr_to_hash( aa )
            bb = Util.arr_to_hash( bb )
            
            2.upto(line-1) { |num|
                worksheet.Range( "R#{num}" ).value = aa[worksheet.Range( "A#{num}" ).value]
                worksheet.Range( "S#{num}" ).value = bb[worksheet.Range( "A#{num}" ).value]
                # Sum of scores R, S
    #            worksheet.Range( "U#{num}" ).formula = "=R#{num} + S#{num} + T#{num}"
            }
            
            printf "."
            worksheet_index += 1
        end
    
        
        workbook.SaveAs( "#{chr}_scored", WIN32OLE::XlWorkbookNormal ) 
        workbook.Close(1)
    }
    excel.Quit
    excel = nil
    puts Time.now
ensure
    if( excel != nil )
        excel.displayAlerts = false # if its doing this, then something is wrong, and I don't want to save, so just quit, no alerts!
        excel.Quit
    end
end

