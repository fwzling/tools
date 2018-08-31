#!/usr/bin/env ruby

## Description: Script to analyze tegra_stats.log 
#
## Usage:       ruby vtracker-stat.rb vtracker.log

## Interesting line example:
# I0829 15:55:35.171044  3266 common.h:33] Time for track_localmap: 579.742ms 

## sudo gem install descriptive_statistics
require 'descriptive_statistics'
require 'time'

DEBUG_PRINT = false                # default off
RegExpPattern = /Time for ([\d\s\S]+)\:\s([\d\.]+)ms/ 

# -------------------- main ---------------------- #
logFile = ARGV[0]
logFile = "vtracker.log" if logFile.nil?

if not File.exist?(logFile)
    puts "#{logFile} does not exist"
    exit 1
end

measureCategory = {} 

File.readlines(logFile).each do | line |
    if matched = line.match(RegExpPattern)
        begin
            puts "Time for #{matched[1]}:  #{matched[2]} ms" if DEBUG_PRINT
            measure, value = matched[1], matched[2]
            measureCategory[measure] = [] if measureCategory[measure].nil? 
            measureCategory[measure] << value.to_i
        rescue Exception => e
            puts e.message
            next
        end
    end
end

measureCategory.each do | subject, measurements |
    puts "#{subject}: [#{measurements.count}]" 
    puts "  Max:                #{measurements.sort.last.round(3)}"
    puts "  Min:                #{measurements.sort.first.round(3)}"
    puts "  P90:                #{measurements.percentile(90).round(3)}"
    puts "  P10:                #{measurements.percentile(10).round(3)}"
    puts "  Average:            #{measurements.mean.round(3)}"
    puts "  StdDev:             #{measurements.standard_deviation.round(3)}"
end
