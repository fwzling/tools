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
#               sudo gem install descriptive_statistics

require 'gruff'
require 'optparse'
require 'ostruct'
require 'descriptive_statistics'
require 'time'


VTRACKER_RECORD_LOAD_IMAGE = /^I(\d+\s[\d\:\.]+).*Time for load_image\:\s([\d\.]+)ms$/
VTRACKER_RECORD_ORB = /^I(\d+\s[\d\:\.]+).*Time for orb\: ([\d\.]+)ms$/
VTRACKER_RECORD_LOAD_CHUNK = /^I(\d+\s[\d\:\.]+).*Time for Load Chunk \d+\:\s([\d\.]+)ms$/
VTRACKER_RECORD_RELOCATE = /^I(\d+\s[\d\:\.]+).*Time for relocate\:\s([\d\.]+)ms$/
VTRACKER_RECORD_TRACK_MOTION = /^I(\d+\s[\d\:\.]+).*Time for track_motion\:\s([\d\.]+)ms$/
VTRACKER_RECORD_TRACK_LOCALMAP = /^I(\d+\s[\d\:\.]+).*Time for track_localmap\:\s([\d\.]+)ms$/
VTRACKER_RECORD_UPDATE_LOCALMAP = /^I(\d+\s[\d\:\.]+).*Time for update_localmap\:\s([\d\.]+)ms$/
VTRACKER_RECORD_SEARCH_MAPPOINTS = /^I(\d+\s[\d\:\.]+).*Time for search_mappoints\:\s([\d\.]+)ms$/
VTRACKER_RECORD_LOCALMAP_POSE_OPT = /^I(\d+\s[\d\:\.]+).*Time for localmap pose_optimize\:\s([\d\.]+)ms$/
VTRACKER_RECORD_STATE_OK = /^I(\d+\s[\d\:\.]+).*state\:\sOK$/
VTRACKER_RECORD_STATE_LOST = /^I(\d+\s[\d\:\.]+).*state\:\sLOST$/


# --- Define Command Line Options --- #

def parse_options(args)
    options = OpenStruct.new
    options.verbose = false
    options.start = 10
    options.max_num = 1000
    options.size = 800
    options.max_y = 200

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

        opts.on("--max_y Y", Integer, "Max value showed in Y axis") do | y |
            options.max_y = y
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
                record_stream << { :label => "load_image", :timestamp => Time.parse(matched[1]), :cost => matched[2].to_i }
            elsif matched = line.match(VTRACKER_RECORD_ORB)
                record_stream << { :label => "orb", :timestamp => Time.parse(matched[1]), :cost => matched[2].to_i }
            elsif matched = line.match(VTRACKER_RECORD_LOAD_CHUNK)
                record_stream << { :label => "load_chunk", :timestamp => Time.parse(matched[1]), :cost => matched[2].to_i }
            elsif matched = line.match(VTRACKER_RECORD_RELOCATE)
                record_stream << { :label => "relocate", :timestamp => Time.parse(matched[1]), :cost => matched[2].to_i }
            elsif matched = line.match(VTRACKER_RECORD_TRACK_MOTION)
                record_stream << { :label => "track_motion", :timestamp => Time.parse(matched[1]), :cost => matched[2].to_i }
            elsif matched = line.match(VTRACKER_RECORD_TRACK_LOCALMAP)
                record_stream << { :label => "track_localmap", :timestamp => Time.parse(matched[1]), :cost => matched[2].to_i }
            elsif matched = line.match(VTRACKER_RECORD_UPDATE_LOCALMAP)
                record_stream << { :label => "update_localmap", :timestamp => Time.parse(matched[1]), :cost => matched[2].to_i }
            elsif matched = line.match(VTRACKER_RECORD_SEARCH_MAPPOINTS)
                record_stream << { :label => "search_mappoints", :timestamp => Time.parse(matched[1]), :cost => matched[2].to_i }
            elsif matched = line.match(VTRACKER_RECORD_LOCALMAP_POSE_OPT)
                record_stream << { :label => "localmap_pose_opt", :timestamp => Time.parse(matched[1]), :cost => matched[2].to_i }
            elsif matched = line.match(VTRACKER_RECORD_STATE_OK)
                record_stream << { :label => "ok", :timestamp => Time.parse(matched[1]), :cost => 0 }
            elsif matched = line.match(VTRACKER_RECORD_STATE_LOST)
                record_stream << { :label => "lost", :timestamp => Time.parse(matched[1]), :cost => 0 }
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
    load_image, track_motion, update_localmap, search_mappoints, localmap_pose_opt, relocate, load_mapchunk = 0, 0, 0, 0, 0, 0, 0
    state = group.pop
    raise "internal fatal error" if state.nil?
    last_ts, first_ts = state[:timestamp], Time.now
    while not group.empty?
        rec = group.pop
        first_ts = rec[:timestamp] - rec[:cost] / 1000.0
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
            search_mappoints += rec[:cost]
        when "localmap_pose_opt"
            localmap_pose_opt += rec[:cost]
        when "relocate"
            puts "ERROR: relocate more than once in group #{@group_count}" if relocate.nonzero?
            relocate = rec[:cost]
        when "load_chunk"
            load_mapchunk += rec[:cost]
        when "orb"
            @orb_costs << rec[:cost]
        end
    end

    misc = (last_ts - first_ts) * 1000 - load_image - track_motion - update_localmap - search_mappoints - localmap_pose_opt - relocate - load_mapchunk
    misc = [misc.to_i, 0].max

    puts "[#{@group_count}]: #{state[:label]}, #{load_image}, #{track_motion}, #{update_localmap}, #{search_mappoints}, #{localmap_pose_opt}, #{relocate}, #{load_mapchunk}, #{misc}" if @options.verbose

    y_reminder = @options.max_y
    [:load_image, :track_motion, :update_localmap, :search_mappoints, :localmap_pose_opt, :relocate, :load_mapchunk, :misc].each do | var |
        if binding.local_variable_get(var) <= y_reminder
            y_reminder -= binding.local_variable_get(var)
        else
            binding.local_variable_set(var, y_reminder)
            y_reminder = 0
        end
    end

    @labels.merge!({ @group_count => if state[:label].eql? "ok" then 'V' else 'X' end })
    @datasets[0].last << load_image
    @datasets[1].last << track_motion
    @datasets[2].last << update_localmap
    @datasets[3].last << search_mappoints
    @datasets[4].last << localmap_pose_opt
    @datasets[5].last << relocate
    @datasets[6].last << load_mapchunk
    @datasets[7].last << misc
    @datasets[8].last << y_reminder 
    @group_count += 1
end

# -------------------- main --------------------- #

@options = parse_options(ARGV)
@logFile = ARGV[0]

exit 1 if @logFile.nil?

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
    [:localmap_pose_opt, []],
    [:relocate, []],
    [:load_mapchunk, []],
    [:misc, []],
    [:hiden, []],
]
@labels = { }
@group_count = 0
@orb_costs = []

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
@chart.replace_colors(['#FDD84E', '#6886B4', '#72AE6E', '#D1695E', '#8A6EAF', '#EFAA43',
                       '#FFE4E1', '#00FF00', 'black',])
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
[ ["ORB extract", @orb_costs], ["Load image frame", @datasets[0].last] ].each do | subject, data |
    puts "   #{subject}: mean(#{data.mean.round(3)}ms), stddev(#{data.standard_deviation.round(3)}ms)"
end

puts " ---------------------- Finished ------------------------------------------ "
system("xdg-open #{@logFile}.png")
