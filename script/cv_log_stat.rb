#!/usr/bin/env ruby

## Description: Script to analyze uos_cv_framework.log 
#
## Usage:       ruby cv_log_stat.rb uos_cv_framework.log

## Interesting line example:
# [20180818 16:04:54.762:INFO:uos_cv_framework] <uos_cv_vslam_wrapper.cc:691 vslam_callback()> cv_worker_0 vslam: X[-77173.6470] Y[4389742.5561] Z[-0.3944] Theta[4.3762] alpha[0.0248] beta[0.0132] Confidence[1.00] Stream[0] ret[0] tstamp[1534579494.762] FPS[12] Clocks[147 ms] Latency[0.152]
# [20180818 16:04:54.778:INFO:uos_cv_framework] <uos_cv_perception_wrapper.cc:1054 cv_perc_once()> detect&tracking time: 0.0637 , lock&copy : 1534579494.0000
# [20180818 16:04:54.785:INFO:uos_cv_framework] <uos_cv_perception_wrapper.cc:928 cv_perc_once()> pop_wf_elem once: X[-77173.6470] Y[4389742.5561] Z[-0.3944] Theta[4.3762] DealLatency[0.176]
#

## sudo gem install descriptive_statistics
require 'descriptive_statistics'

DEBUG_PRINT = false                # default off

# -------------------- main ---------------------- #
cvLogFile = ARGV[0]
cvLogFile = "uos_cv_framework.log" if cvLogFile.nil?

if not File.exist?(cvLogFile)
  puts "#{cvLogFile} does not exist"
  exit 1
end

fps_stream_0,     fps_stream_1     = [], []
clocks_stream_0,  clocks_stream_1  = [], []
latency_stream_0, latency_stream_1 = [], []
perc_detect_time                   = []
perc_deal_latency                  = []


File.readlines(cvLogFile).each do | line |
    if matched = line.match(/vslam_callback.*Stream\[(\d)\].*FPS\[(\d+)\].*Clocks\[(\d+)\sms\].*Latency\[([\d\.]+)\]$/)
        puts "VSLAM RECORD: #{line}" if DEBUG_PRINT
        stream_id, fps, clocks, latency = matched[1].to_i, matched[2].to_i, matched[3].to_i, matched[4].to_f
        if stream_id == 0
            fps_stream_0 << fps
            clocks_stream_0 << clocks
            latency_stream_0 << latency
        elsif stream_id == 1
            fps_stream_1 << fps
            clocks_stream_1 << clocks
            latency_stream_1 << latency
        else
            puts "[ERROR] unexpected stream number"
            exit 1
        end
    elsif matched = line.match(/cv_perc_once.*tracking\stime\:\s([\d\.]+)/)
        puts "PERCE RECORD: #{line}" if DEBUG_PRINT
        perc_detect_time << matched[1].to_f
    elsif matched = line.match(/pop_wf_elem.*DealLatency\[([\d\.]+)\]/)
        puts "WORKFLOW RECORD: #{line}" if DEBUG_PRINT
        perc_deal_latency << matched[1].to_f
    else
        next
    end
end

puts "Number of records:"
puts "    Stream[0]: #{fps_stream_0.count}"
puts "    Stream[1]: #{fps_stream_1.count}"
puts "    Perc_dect: #{perc_detect_time.count}"
puts "    Wflow_pop: #{perc_deal_latency.count}"

[ [fps_stream_0, "Stream[0].FPS"],
  [clocks_stream_0, "Stream[0].Clocks"],
  [latency_stream_0, "Stream[0].Latency"],
  [fps_stream_1, "Stream[1].FPS"],
  [clocks_stream_1, "Stream[1].Clocks"],
  [latency_stream_1, "Stream[1].Latency"],
  [perc_detect_time, "Detection.Clocks"],
  [perc_deal_latency, "Detection.Deal.Latency"]
].each do | stat, subject |
    next if stat.empty?
    puts ""
    puts subject 
    puts "  Min:                #{stat.sort.first.round(4)}"
    puts "  Max:                #{stat.sort.last.round(4)}"
    puts "  P10:                #{stat.percentile(10).round(4)}"
    puts "  P90:                #{stat.percentile(90).round(4)}"
    puts "  Average:            #{stat.mean.round(4)}"
    puts "  StandardDeviation:  #{stat.standard_deviation.round(4)}"
end
