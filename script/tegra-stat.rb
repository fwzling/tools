#!/usr/bin/env ruby

## Description: Script to analyze tegra_stats.log 
#
## Usage:       ruby tegra-stat.rb tegra_stats.log

## Interesting line example:
# [2018-08-23 16:30:36] : RAM 4923/7850MB (lfb 360x4MB) CPU [33%@2034,42%@2033,100%@2036,22%@2035,61%@2034,43%@2035] EMC_FREQ 14%@1600 GR3D_FREQ 22%@1300 APE 150 MTS fg 0% bg 0% BCPU@53C MCPU@53C GPU@59C PLL@53C AO@50.5C Tboard@48C Tdiode@49.5C PMIC@100C thermal@52.1C VDD_IN 9273/9056 VDD_CPU 3716/3302 VDD_GPU 1430/1586 VDD_SOC 714/705 VDD_WIFI 0/0 VDD_DDR 1148/1198

## sudo gem install descriptive_statistics
require 'descriptive_statistics'
## sudo gem install daru
# require 'daru'
## sudo gem install gnuplotrb
# require 'gnuplotrb'

require 'time'

DEBUG_PRINT = false                # default off
RegExpPattern = /^\[([\d\s:-]*).*CPU\s\[(\d*)\%@\d+,(\d*)\%@\d+,(\d*)\%@\d+,(\d*)\%@\d+,(\d*)\%@\d+,(\d*)\%@\d+\].*GR3D_FREQ\s(\d+)/
## TimeRangeStart = '2018-8-20'
## TimeRangeEnd = '2018-8-25'
## TimeRangeInterval = '5S'          # 5 seconds

# -------------------- main ---------------------- #
logFile = ARGV[0]
logFile = "tegra_stats.log" if logFile.nil?

if not File.exist?(logFile)
    puts "#{logFile} does not exist"
    exit 1
end

## index = Daru::DateTimeIndex.date_range(:start => TimeRangeStart,
##                                       :end => TimeRangeEnd,
##                                       :freq => TimeRangeInterval)

usageCPUAll = []
usageGPUAll = []

File.readlines(logFile).each do | line |
    if matched = line.match(RegExpPattern)
        begin
            puts "Timestamp[#{matched[1]}] CPU-0[#{matched[2]}] CPU-1[#{matched[3]}] CPU-2[#{matched[4]}] CPU-3[#{matched[5]}] CPU-4[#{matched[6]}] CPU-5[#{matched[7]}] GPU[#{matched[8]}]" if DEBUG_PRINT

            timestamp  = Time.parse(matched[1])
            usage_CPU0 = matched[2].to_i
            usage_CPU1 = matched[3].to_i
            usage_CPU2 = matched[4].to_i
            usage_CPU3 = matched[5].to_i
            usage_CPU4 = matched[6].to_i
            usage_CPU5 = matched[7].to_i
            usage_GPU  = matched[8].to_i

            usageCPUAll << (usage_CPU0 + usage_CPU1 + usage_CPU2 + usage_CPU3 + usage_CPU4 + usage_CPU5).to_f / 600
            usageGPUAll << usage_GPU.to_f
        rescue Exception => e
            puts e.message
            next
        end
    end
end

puts "CPU or GPU data empty" and exit 1 if usageCPUAll.empty? || usageGPUAll.empty?

puts "Analyzed #{usageCPUAll.count} CPU recrods and #{usageGPUAll.count} GPU records"
[["CPU Stat.", usageCPUAll], ["GPU Stat.", usageGPUAll]].each do | subject, stat |
    next if stat.empty?
    puts subject 
    puts "  Max:                #{stat.sort.last.round(3)}"
    puts "  P95:                #{stat.percentile(95).round(3)}"
    puts "  P90:                #{stat.percentile(90).round(3)}"
    puts "  Average:            #{stat.mean.round(3)}"
    puts "  StdDev:             #{stat.standard_deviation.round(3)}"
end
