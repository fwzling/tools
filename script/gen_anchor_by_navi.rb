#!/usr/bin/env ruby

## Description: Script to parse uos_navigation log, and
#               generate a pose list in time order for VSLAM mapping 
#
## Usage:       ruby gen_anchor_by_navi.rb [options] /file/of/navigation/log
#
## Dependency:
#               sudo apt-get install ruby  (recommend ruby2.3 and above)

require 'optparse'
require 'ostruct'
require 'time'

RECORD_LINE_REGEXPR = /^navi_log_output_data\:([\-\d\.]+)\s([\-\d\.]+)\s([\-\d\.]+)\s([\-\d\.]+)\s([\-\d\.]+)\s([\-\d\.]+)\s([\-\d\.]+)\s([\-\d\.]+)\s([\-\d\.]+)/

# --- Define Command Line Options --- #

def parse_options(args)
    options = OpenStruct.new
    options.verbose = false

    opt_parser = OptionParser.new do | opts |
        opts.banner = "Usage:  gen_anchor_by_navi.rb  [options]  uos_navigation.log"
        opts.separator ""
        opts.separator "Specific options:"

        opts.on("--verbose", "Output trivial information") do
            options.verbose = true
        end
    end

    opt_parser.parse!(args)
    options
end

# --- Parse and tokenize time measurement records --- #

def parse_tokenize(log_file)
    record_stream = []
    File.readlines(log_file).each do | line |
        begin
            if matched = line.match(RECORD_LINE_REGEXPR)
                record_stream << { :east   => matched[1],
                                   :north  => matched[2], 
                                   :height => matched[3], 
                                   :alpha  => matched[4], 
                                   :beta   => matched[5], 
                                   :theta  => matched[6], 
                                   :state  => matched[7], 
                                   :conf   => matched[8], 
                                   :ts     => matched[9] }
            end
        rescue Exception => e
            puts e.message
            next
        end
    end
    record_stream
end

# -------------------- main --------------------- #

@options = parse_options(ARGV)
@logFile = ARGV[0]

exit 1 if @logFile.nil?

if not File.exist?(@logFile)
    puts "ERROR: #{@logFile} not found"
    exit 1
end

puts " ---------------------- Processing navigation log --------------------------- "
@record_stream = parse_tokenize(@logFile)
puts "   Collected #{@record_stream.count} navigation records"

@anchor_cnt = 0
puts " ---------------------- Generate anchor list --------------------------- "
open('cube_gps.txt', 'w') do | f |
    @record_stream.each do | rec |
        if 1.0 - rec[:conf].to_f < 0.01
            anchor_line = "#{rec[:ts]} #{rec[:east]} #{rec[:north]} #{rec[:height]} #{rec[:theta]} 0.0 0.0 1.0"
            puts anchor_line if @options.verbose
            f << "#{anchor_line}\n" and @anchor_cnt += 1
        end
    end
end
puts "   Collected #{@anchor_cnt} anchors"

puts " ---------------------- Finished ------------------------------------------ "
