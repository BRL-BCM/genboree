# Used to merge various Excel files into one, where each file exists as a different worksheet
require 'win32ole'

# Grab a list of all the data that is present in the current directory
ARGV[0] ? wd = ARGV[0] : wd = Dir.getwd
chr_list = Array.new
Dir.foreach("."){ |ii|
    chr_list.push( ii ) if ii =~ /chr.*_1_fdata/
}

excel = WIN32OLE::new('excel.Application')  # Startup Excel
excel.SheetsInNewWorkbook = chr_list.length  # I want 24 worksheets available to me
#excel.Visible = true  # Make visible
begin

            
    worksheet_index = 1
    # Must load the WIN32OLE constants for use
    # Note, most of these constants are documented as starting with a lower case "x" in actual windows documentation
    # but seem to only work when I set the first letter as uppercase (perhaps because ruby consts start w/ uppercase?)
    WIN32OLE.const_load( excel )    # Necessary for WIN32OLE constant usage
    workbook_final = excel.Workbooks.Add()
    
    chr_list.each{ |f|
        # Creates OLE object to Excel
        workbook = excel.Workbooks.Open( "#{wd}/#{f}" )
        
        worksheet = workbook.Worksheets(1) # get hold of the first worksheet
        worksheet.Select
        
        # Grab the row number of first empty row
        last_row = 1
        while worksheet.Range("A#{last_row}").value  
            last_row += 1
        end
        last_row += 1  # I know that column E is longer by 1, but couldn't loop looknig at column E because not all of its cells are full
        # Copy all the data I want, and store for later use
        data = worksheet.Range( "A1:R#{last_row+3}" ).value
        
        workbook.close
        
        new_worksheet = workbook_final.Worksheets(worksheet_index)
        new_worksheet.Select
        new_worksheet.Range( "A1:R#{last_row+3}" ).value = data   # Effectively "pasting" the data earlier retrieved
        new_worksheet.Name = "#{chr}"      # Rename this worksheet
        
        worksheet_index += 1
        printf "."
    }
    
    workbook_final.SaveAs( "#{wd}/merged.xls", WIN32OLE::XlWorkbookNormal )
    
ensure
    excel.SheetsInNewWorkbook = 3   # Must reset to 3, else all other intances of new Excel woorkbooks seem to have 24 worksheets
    excel.Quit unless (excel == nil )
end
