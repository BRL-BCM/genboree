# Used to merge various Excel files into one, where each file exists as a different worksheet
require 'win32ole'


excel = WIN32OLE::new('excel.Application')  # Startup Excel
excel.Visible = true  # Make visible
begin
    # Must load the WIN32OLE constants for use
    # Note, most of these constants are documented as starting with a lower case "x" in actual windows documentation
    # but seem to only work when I set the first letter as uppercase (perhaps because ruby consts start w/ uppercase?)
    WIN32OLE.const_load( excel )    # Necessary for WIN32OLE constant usage
    workbook_final = excel.Workbooks.Add()
    new_worksheet = workbook_final.Worksheets(1)
    new_worksheet.Select
    
    workbook = excel.Workbooks.Open( "C:\\Documents and Settings\\ml142326\\Desktop\\#{ARGV[0]}" )
    1.upto(24){ |worksheet_index|
        puts "again: #{worksheet_index}"
        
        worksheet = workbook.Worksheets(worksheet_index) # get hold of the first worksheet
        worksheet.Select
        
        # Grab the row number of first empty row
        last_row = 1
        while worksheet.Range("A#{last_row}").value  
            last_row += 1
        end
        last_row += 1  # I know that column E is longer by 1, but couldn't loop looknig at column E because not all of its cells are full
        puts "1: #{last_row}"
        # Copy all the data I want, and store for later use
        data = worksheet.Range( "A2:R#{last_row+3}" ).value

        new_last_row = 1
        while new_worksheet.Range("A#{new_last_row}").value  
            new_last_row += 1
        end
        puts "2: #{new_last_row}"
        new_worksheet.Range( "A#{new_last_row}:R#{last_row+3}" ).value = data   # Effectively "pasting" the data earlier retrieved
        
        printf "."
    }
    
    workbook_final.SaveAs( "C:\\Documents and Settings\\ml142326\\Desktop\\merged_new.xls", WIN32OLE::XlWorkbookNormal )
    
ensure
    excel.SheetsInNewWorkbook = 3   # Must reset to 3, else all other intances of new Excel woorkbooks seem to have 24 worksheets
    excel.Quit unless (excel == nil )
end
