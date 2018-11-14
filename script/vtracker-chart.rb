#!/usr/bin/env ruby

## Description: Script to parse vtracker internal logging output, and
#               collect time records, and generates stat. each major step, and
#               visualize the data in charts.
#
## Usage:       ruby vtracker-chart.rb [options] /file/of/vtracker/log
#
## Dependency:
#               sudo apt-get install ruby
#               sudo gem install gruff

require 'gruff'
require 'optparse'
require 'ostruct'
require 'time'


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


# --- Define Command Line Options --- #

def parse_options(args)
    options = OpenStruct.new
    options.verbose = false
    options.start = 10
    options.max_num = 1000
    options.size = 800

    opt_parser = OptionParser.new do | opts |
        opts.banner = "Usage:  vtracker-chart.rb  [options]  vtracker.log"
        opts.separator ""
        opts.separator "Specific options:"

        opts.on("--start X", Integer, "Draw graph starting from the X-th tracking") do | x |
            options.start = x
        end

        opts.on("--max_num N", Integer, "Draw at most N tracking bars") do | n |
            options.max_num = n
        end

        opts.on("--size S", Integer, "Chart geometry size in width") do | s |
            options.size = s
        end

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
            if matched = line.match(VTRACKER_RECORD_LOAD_IMAGE)
                record_stream << { :label => "load_image", :cost => matched[1].to_i }
            elsif matched = line.match(VTRACKER_RECORD_ORB)
                record_stream << { :label => "orb", :cost => matched[1].to_i }
            elsif matched = line.match(VTRACKER_RECORD_LOAD_CHUNK)
                record_stream << { :label => "load_chunk", :cost => matched[1].to_i }
            elsif matched = line.match(VTRACKER_RECORD_TRACK_MOTION)
                record_stream << { :label => "track_motion", :cost => matched[1].to_i }
            elsif matched = line.match(VTRACKER_RECORD_TRACK_LOCALMAP)
                record_stream << { :label => "track_localmap", :cost => matched[1].to_i }
            elsif matched = line.match(VTRACKER_RECORD_UPDATE_LOCALMAP)
                record_stream << { :label => "update_localmap", :cost => matched[1].to_i }
            elsif matched = line.match(VTRACKER_RECORD_SEARCH_MAPPOINTS)
                record_stream << { :label => "search_mappoints", :cost => matched[1].to_i }
            elsif matched = line.match(VTRACKER_RECORD_LOCALMAP_POSE_OPT)
                record_stream << { :label => "localmap_pose_opt", :cost => matched[1].to_i }
            elsif matched = line.match(VTRACKER_RECORD_STATE_OK)
                record_stream << { :label => "ok", :cost => 0 }
            elsif matched = line.match(VTRACKER_RECORD_STATE_LOST)
                record_stream << { :label => "lost", :cost => 0 }
            else
                next
            end
        rescue Exception => e
            puts e.message
            next
        end
    end
    record_stream
end

# --- Analyze metrics by group time measurements of the same tracking --- #

def analyze_stream(record_stream)
    group = []
    record_stream.each do |rec|
        puts rec if @options.verbose
        group << rec
        if ["ok", "lost"].include? rec[:label]
            process_group(group)
        end
    end
end

# --- Analyze a group of one tracking --- #
# Generate side effective to globals

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
            puts "ERROR: track_motion more than once in group #{@group_count}" if track_motion.nonzero?
            track_motion = rec[:cost]
        when "update_localmap"
            puts "ERROR: update_localmap more than once in group #{@group_count}" if update_localmap.nonzero?
            update_localmap = rec[:cost]
        when "search_mappoints"
            puts "ERROR: search_mappoints more than once in group #{@group_count}" if search_mappoints.nonzero?
            search_mappoints = rec[:cost]
        when "localmap_pose_opt"
            puts "ERROR: localmap_pose_opt more than once in group #{@group_count}" if localmap_pose_opt.nonzero?
            localmap_pose_opt = rec[:cost]
        when "orb"
            @orb_costs << rec[:cost]
        when "load_chunk"
            @load_chunk_costs << rec[:cost]
        end
    end

    puts "[#{@group_count}]: #{state[:label]}, #{load_image}, #{track_motion}, #{update_localmap}, #{search_mappoints}, #{localmap_pose_opt}" if @options.verbose

    @labels.merge!({ @group_count => if state[:label].eql? "ok" then 'V' else 'X' end })
    @datasets[0].last << load_image
    @datasets[1].last << track_motion
    @datasets[2].last << update_localmap
    @datasets[3].last << search_mappoints
    @datasets[4].last << localmap_pose_opt
    @group_count += 1
end

# -------------------- main --------------------- #

@options = parse_options(ARGV)
@logFile = ARGV[0]

if not File.exist?(@logFile)
    puts "ERROR: #{@logFile} not found"
    exit 1
end

puts " ---------------------- Processing vtracker log --------------------------- "

@datasets = [
    [:load_image, []],
    [:track_motion, []],
    [:update_localmap, []],
    [:search_mappoints, []],
    [:localmap_pose_opt, []]
]
@labels = { }
@group_count = 0
@orb_costs = []
@load_chunk_costs = []

analyze_stream(parse_tokenize(@logFile))
puts "   Analyzed #{@group_count} tracking activations"
if @options.start > @group_count
    puts "Start value is greater than the total activations number!" and exit 0
end

puts " ---------------------- Draw vtracker activation chart -------------------- "
puts "   Start from the #{@options.start}-th tracking"
puts "   Draw at most #{@options.max_num} activations"

@chart = Gruff::StackedBar.new(@options.size)
@chart.title = "Vtracker internal metrics"
@chart.title_font_size = 32
@chart.legend_font_size = 12
@chart.marker_font_size = 12
label_pos = 0
(@options.start..[@group_count, @options.start + @options.max_num].min).each do | i |
    @chart.labels.merge!({ label_pos => @labels[i] })
    label_pos += 1
end
@datasets.each do |data|
    @chart.data(data.first, data.last[@options.start, @options.max_num])
end
@chart.write "#{@logFile}.png"

puts " ---------------------- Print other metrics ------------------------------- "

puts " ---------------------- Finished ------------------------------------------ "
system("xdg-open #{@logFile}.png")
