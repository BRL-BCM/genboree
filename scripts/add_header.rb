#!/usr/bin/env ruby

# parameters
# - file with texts
# - list of directories to visit
if ARGV.size < 2
    puts "Parameters:  text_file_with_header  list_of_directories_to_scan" 
    exit 1
end

$header = File.readlines(ARGV[0])

# recursive function
def process_directory(path)
    dirs = []
    Dir.foreach(path) do |item|
        next if item =~ /^\./
        full_path = File.join(path, item)
        if File.directory?(full_path)
            dirs << full_path
            next
        end
        next if not File.file?(full_path)
        # check file type
        first_line = "/*\n"
        last_line = "*/\n"
        if full_path =~ /\.rb$/
            first_line = "=begin\n"
            last_line  = "=end\n"
        elsif full_path =~ /\.java$/
            # ok
        else
            next
        end
        # add header
        content = File.readlines(full_path)
        puts "Process file #{full_path} ..."
        next if content.size == 0
        if content[0] =~ /^#!/
            content = [content[0]] + [first_line] + $header + [last_line, "\n"] + content[1..-1]
        else
            content = [first_line] + $header + [last_line, "\n"] + content[0..-1]
        end
        File.open(full_path, "w") do |f|
            f.write(content.join(''))
        end
    end
    # go to subdirectories
    dirs.each { |dirname|
        process_directory(dirname)
    }
end


ARGV[1..-1].each { |path|
    process_directory(path)
}

