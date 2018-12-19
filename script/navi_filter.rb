#!/usr/bin/env ruby

## Description: Script to extract interesting fields in navigation log
#
## Usage:       ruby navi_filter.rb navigation.log

MeasurementInputFlags_Prefix = "measurement input flags"

Inputrd_Prefix = "navi_log_input_data:"
OutputRecord_Prefix = "navi_log_output_data:"



DEBUG_PRINT = false                 # default off
RECORD_PREFIX = "navi_log_input_data:"
FIELDS_NUM = 131 
INDEX_VSLAM_TS_0 = 64
INDEX_VSLAM_TS_1 = 67
INDEX_RECORD_TS = 68

# -------------------- main ---------------------- #
naviLogFile = ARGV[0]

if not File.exist?(naviLogFile)
  puts "#{naviLogFile} does not exist"
  exit 1
end

recLineNum = 0
vslam0_latency = []
vslam1_latency = []

File.readlines(naviLogFile).each do | line |
    next unless line.match(/^#{RECORD_PREFIX}/)
    fields = line.slice(RECORD_PREFIX.length, line.length).split(' ')
    next unless fields.count == FIELDS_NUM
    vslam0_ts, vslam1_ts, rec_ts = fields[INDEX_VSLAM_TS_0].to_f, fields[INDEX_VSLAM_TS_1].to_f, fields[INDEX_RECORD_TS].to_f
    la_0 = rec_ts - vslam0_ts
    la_1 = rec_ts - vslam1_ts
    puts "Processing record: [#{la_0}] [#{la_1}]" if DEBUG_PRINT
    recLineNum += 1
    vslam0_latency << la_0 if la_0 < MAX_LATENCY_FOR_ERROR_STATE 
    vslam1_latency << la_1 if la_1 < MAX_LATENCY_FOR_ERROR_STATE 
end

puts "Number of records: [#{recLineNum}, #{vslam0_latency.count}, #{vslam1_latency.count}]"

[ [vslam0_latency, "VSLAM_0 Latency"], [vslam1_latency, "VSLAM_1 Latency"] ].each do | stat, subject |
    next if stat.empty?
    puts subject 
    puts "  Max:                #{stat.sort.last.round(3)}"
    puts "  P95:                #{stat.percentile(95).round(3)}"
    puts "  P90:                #{stat.percentile(90).round(3)}"
    puts "  Average:            #{stat.mean.round(3)}"
    puts "  StandardDeviation:  #{stat.standard_deviation.round(3)}"
    puts "  %[<#{MAX_DATA_LOSS_TIME_VSLAM}]:            #{stat.percentile_rank(MAX_DATA_LOSS_TIME_VSLAM).round(3)}"
    puts "  Range:              #{stat.range.round(3)}"
end
