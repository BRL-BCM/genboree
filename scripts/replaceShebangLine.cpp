#include <iostream>
#include <fstream>
#include <string>
#include <cctype>
#include <cstring>

bool isPrefix(const std::string& prefix, const std::string& str) {
    if (prefix.size() > str.size()) return false;
    return ( str.substr(0,prefix.size()) == prefix );
}

int main(int argc, char ** argv)
{
    for ( unsigned i = 1; i < argc; ++i ) {
        std::string const filename = argv[i];
        if (filename[0] == '-') {
            if (filename == "-h" || filename == "--help") {
                std::cout << "Program opens all files given as command line parameters and change their first line if it starts from #!/" << std::endl;
            } else {
                std::cerr << "ERROR: Unknown option: " << filename << ", try -h" << std::endl;
            }
            continue;
        }
        std::ifstream file(filename.c_str());
        if (! file.good()) {
            std::cerr << "ERROR: Cannot open file " << filename << std::endl;
            continue;
        }
        char buf[512];
        file.getline(buf,512);
        if ( file.eof() || buf[0] != '#' || buf[1] != '!' || buf[2] != '/' || strlen(buf) > 500 ) {
            file.close();
            continue;
        }
        if (! file.good()) {
            std::cerr << "ERROR: Cannot read file " << filename << std::endl;
            file.close();
            continue;
        }
        std::string line = buf;
        if ( isPrefix("#!/usr/bin/env",line) ) continue;
        unsigned firstLetterOfCommand = 3;
        for ( unsigned j = 3;  j < line.size();  ++j ) {
            if ( isspace(line[j]) ) {
                break;
            }
            if ( line[j] == '/' ) {
                firstLetterOfCommand = j+1;
            }
        }
        std::string const newFirstLine = "#!/usr/bin/env " + line.substr(firstLetterOfCommand);
        std::string newFile = newFirstLine;
        while ( file.good() ) {
            std::getline(file, line);
            newFile += "\n" + line;
        }
        if (! file.eof()) {
            std::cerr << "ERROR: Cannot read(2) file " << filename << std::endl;
            file.close();
            continue;
        }
        file.close();
        std::ofstream file2(filename.c_str());
        file2 << newFile << std::flush;
        file2.close();
        std::cout << "File " << filename << " was changed" << std::endl;
    }
    return 0;
}
