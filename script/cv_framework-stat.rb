#!/usr/bin/env ruby

## Description: Script to analyze uos_cv_framework.log 
#
## Usage:       ruby cv_framework-stat.rb uos_cv_framework.log

## Interesting line example:
# [20180818 16:04:54.762:INFO:uos_cv_framework] <uos_cv_vslam_wrapper.cc:691 vslam_callback()> cv_worker_0 vslam: X[-77173.6470] Y[4389742.5561] Z[-0.3944] Theta[4.3762] alpha[0.0248] beta[0.0132] Confidence[1.00] Stream[0] ret[0] tstamp[1534579494.762] FPS[12] Clocks[147 ms] Latency[0.152]
#

## sudo gem install descriptive_statistics
require 'descriptive_statistics'

DEBUG_PRINT = false                # default off
RegExpPattern = /vslam.*Stream\[(\d)\].*FPS\[(\d+)\].*Clocks\[(\d+)\sms\].*Latency\[([\d\.]+)\]$/

# -------------------- main ---------------------- #
logFile = ARGV[0]
logFile = "uos_cv_framework.log" if logFile.nil?

if not File.exist?(logFile)
  puts "#{logFile} does not exist"
  exit 1
end

fpsStream_0,     fpsStream_1     = [], []
clockStream_0,   clockStream_1   = [], []
latencyStream_0, latencyStream_1 = [], []

File.readlines(logFile).each do | line |
    if matched = line.match(RegExpPattern)
        begin
            puts "Stream_#{matched[1]}: FPS[#{matched[2]} Clock[#{matched[3]}] Latency[#{matched[4]}]" if DEBUG_PRINT

            stream_id = matched[1].to_i
            fps       = matched[2].to_i
            clock     = matched[3].to_i
            latency   = matched[4].to_f

            if stream_id == 0
                fpsStream_0 << fps
                clockStream_0 << clock
                latencyStream_0 << latency
            elsif stream_id == 1
                fpsStream_1 << fps
                clockStream_1 << clock
                latencyStream_1 << latency
            else
                puts "[ERROR] unexpected stream number"
                exit 1
            end
        rescue Exception => e
            puts e.message
            next
        end
    else
        next
    end
end

puts "Number of records:"
puts "    Stream[0]: #{fpsStream_0.count}"
puts "    Stream[1]: #{fpsStream_1.count}"

[ [fpsStream_0, "Stream[0].FPS"],
  [clockStream_0, "Stream[0].Clock"],
  [latencyStream_0, "Stream[0].Latency"],
  [fpsStream_1, "Stream[1].FPS"],
  [clockStream_1, "Stream[1].Clock"],
  [latencyStream_1, "Stream[1].Latency"],
].each do | stat, subject |
    next if stat.empty?
    puts ""
    puts subject 
    puts "  P10:                #{stat.percentile(10).round(3)}"
    puts "  P50:                #{stat.percentile(50).round(3)}"
    puts "  P90:                #{stat.percentile(90).round(3)}"
    puts "  Average:            #{stat.mean.round(3)}"
    puts "  StdDev:             #{stat.standard_deviation.round(3)}"
end
