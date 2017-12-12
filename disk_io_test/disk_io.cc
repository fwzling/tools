/**
 * Test large file read performance
 * INPUT: binary file on either hard driver or SSD
**/

#include <iostream>
#include <fstream>
#include <string>
#include <sstream>
#include <boost/program_options.hpp>
#include <cstring>
#include <cstdlib>

#define MAX_FILENAME_LEN 512

char filename[MAX_FILENAME_LEN];
static void pp_arguments(int argc, char** argv);

int main(int argc, char** argv) {
    pp_arguments(argc, argv);
    std::ifstream istrm(filename, std::ios::binary);
    if (!istrm.is_open()) {
        std::cout << "failed to open " << filename << '\n';
    } else {
        auto ss = std::ostringstream{};
        ss << istrm.rdbuf();
        auto s = ss.str();
        std::cout << "File Size: " << s.size() << " Bytes" << std::endl;
    }

    return 0;
}

void pp_arguments(int argc, char** argv)
{
    namespace po = boost::program_options;
    po::options_description desc("Test file read performance");
    desc.add_options()
        ("help", "print command usage")
        ("path", po::value<std::string>(), "binary file path");

    po::variables_map vm;
    po::store(po::parse_command_line(argc, argv, desc), vm);
    po::notify(vm);    

    if (vm.count("help"))
    {
        std::cout << desc << std::endl;
        std::exit(0);    
    }

    if (vm.count("path"))
    {
        strncpy(filename, vm["path"].as<std::string>().c_str(), MAX_FILENAME_LEN);
        std::cout << "path is set to " << filename << std::endl;
    } 
    else 
    {
        std::cout << "path is not set." << std::endl;
        std::exit(1);
    }
}
