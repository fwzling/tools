#!/usr/bin/env ruby

## Description: Script to parse vtracker internal logging output, collect time records, and
#               generates stat. for the amount of time spent on each major step, and
#               visualize the data in stacked bar chart.
#
## Usage:       ruby vtracker-perf.rb /file/of/vtracker/log 
#
## Dependency:
#               sudo apt-get install ruby
#               sudo gem install descriptive_statistics
#               sudo gem install gruff 

require 'gruff'
require 'time'

DEBUG_Print = false  # default off

# ----------------- Check Command Line Arguments ------------------- #
@logFile = ARGV[0]
    
if not File.exist?(@logFile)
    puts "ERROR: #{@logFile} not found"
    exit 1
end

VTRACKER_RECORD_LOAD_IMAGE = /Time for load_image\:\s([\d\.]+)ms/ 
VTRACKER_RECORD_ORB = /Time for orb\: ([\d\.]+)ms/
VTRACKER_RECORD_LOAD_CHUNK = /Time for Load Chunk \d+\:\s([\d\.]+)ms/
VTRACKER_RECORD_TRACK_MOTION = /Time for track_motion\:\s([\d\.]+)ms/
VTRACKER_RECORD_TRACK_LOCALMAP = /Time for track_localmap\:\s([\d\.]+)ms/
VTRACKER_RECORD_UPDATE_LOCALMAP = /Time for update_localmap\:\s([\d\.]+)ms/
VTRACKER_RECORD_SEARCH_MAPPOINTS = /Time for search_mappoints\:\s([\d\.]+)ms/
VTRACKER_RECORD_LOCALMAP_POSE_OPT = /Time for localmap pose_optimize\:\s([\d\.]+)ms/
VTRACKER_RECORD_STATE_OK = /\sstate\:\sOK$/
VTRACKER_RECORD_STATE_LOST = /\sstate\:\sLOST$/ 

@record_stream = []

def parse_tokenize
    File.readlines(@logFile).each do | line |
        begin
            if matched = line.match(VTRACKER_RECORD_LOAD_IMAGE)
                @record_stream << { :label => "load_image", :cost => matched[1].to_i }
            elsif matched = line.match(VTRACKER_RECORD_ORB)
                @record_stream << { :label => "orb", :cost => matched[1].to_i }
            elsif matched = line.match(VTRACKER_RECORD_LOAD_CHUNK)
                @record_stream << { :label => "load_chunk", :cost => matched[1].to_i }
            elsif matched = line.match(VTRACKER_RECORD_TRACK_MOTION)
                @record_stream << { :label => "track_motion", :cost => matched[1].to_i }
            elsif matched = line.match(VTRACKER_RECORD_TRACK_LOCALMAP)
                @record_stream << { :label => "track_localmap", :cost => matched[1].to_i }
            elsif matched = line.match(VTRACKER_RECORD_UPDATE_LOCALMAP)
                @record_stream << { :label => "update_localmap", :cost => matched[1].to_i }
            elsif matched = line.match(VTRACKER_RECORD_SEARCH_MAPPOINTS)
                @record_stream << { :label => "search_mappoints", :cost => matched[1].to_i }
            elsif matched = line.match(VTRACKER_RECORD_LOCALMAP_POSE_OPT)
                @record_stream << { :label => "localmap_pose_opt", :cost => matched[1].to_i }
            elsif matched = line.match(VTRACKER_RECORD_STATE_OK)
                @record_stream << { :label => "ok", :cost => 0 }
            elsif matched = line.match(VTRACKER_RECORD_STATE_LOST)
                @record_stream << { :label => "lost", :cost => 0 }
            else
                next
            end
        rescue Exception => e
            puts e.message
            next
        end 
    end
end

@datasets = [
    [:load_image, []],
    [:track_motion, []],
    [:update_localmap, []],
    [:search_mappoints, []],
    [:localmap_pose_opt, []]
]
@labels = { }

@group_count = 0

@orb_cost_sum = 0
@orb_times = 0
@load_chunk_cost_sum = 0
@load_chunk_times = 0

def analyze_stream
    group = []
    @record_stream.each do |rec|
        puts rec if DEBUG_Print
        group << rec
        if ["ok", "lost"].include? rec[:label]
            process_group(group)
        end
    end
end

def process_group(group)
    load_image, track_motion, update_localmap, search_mappoints, localmap_pose_opt = 0, 0, 0, 0, 0
    state = group.pop
    raise "internal fatal error" if state.nil?
    while not group.empty?
        rec = group.pop
        case rec[:label]
        when "load_image"
            puts "ERROR: load_image more than once in group #{@group_count}" if load_image.nonzero?
            load_image = rec[:cost]
        when "track_motion"
            puts "ERROR: track_motion more than once in group #{@group_count}" if load_image.nonzero?
            track_motion = rec[:cost]
        when "update_localmap"
            puts "ERROR: update_localmap more than once in group #{@group_count}" if load_image.nonzero?
            update_localmap = rec[:cost]
        when "search_mappoints"
            puts "ERROR: search_mappoints more than once in group #{@group_count}" if load_image.nonzero?
            search_mappoints = rec[:cost]
        when "localmap_pose_opt"
            puts "ERROR: localmap_pose_opt more than once in group #{@group_count}" if load_image.nonzero?
            localmap_pose_opt = rec[:cost]
        when "orb"
            @orb_times += 1 and @orb_cost_sum += rec[:cost]
        when "load_chunk"
            @load_chunk_times += 1 and @load_chunk_cost_sum += rec[:cost]
        end
    end
    @labels.merge!({ @group_count => if state[:label] == "ok" then "V" else "X" end })
    @datasets[0].last << load_image
    @datasets[1].last << track_motion 
    @datasets[2].last << update_localmap
    @datasets[3].last << search_mappoints
    @datasets[4].last << localmap_pose_opt
    @group_count += 1
end

# -------------------- main --------------------- #

puts " ---------------------- Processing vtracker log --------------------------- "

parse_tokenize
analyze_stream

puts " ---------------------- Draw vtracker activation chart -------------------- "
START_AT = 10
MAX_BARS_NUM = 2000
puts " Start from the #{START_AT}th track, and draw at most #{MAX_BARS_NUM} bars" 

@chart = Gruff::StackedBar.new(1600)
@chart.title = "Vtracker internal metrics"
@chart.title_font_size = 32
@chart.legend_font_size = 12
@chart.marker_font_size = 12
@chart.labels = @labels
@datasets.each do |data|
    @chart.data(data.first, data.last[START_AT, MAX_BARS_NUM])
end
@chart.write "#{@logFile}.png"

puts " ---------------------- Print other metrics ------------------------------- "
puts " ORB extract average time: #{ @orb_cost_sum / @orb_times }ms"
puts " Load single chunk average time: #{ @load_chunk_cost_sum / @load_chunk_times }ms"

puts " ---------------------- Finished ------------------------------------------ "
system("xdg-open #{@logFile}.png")
