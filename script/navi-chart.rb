#!/usr/bin/env ruby

## Description: Script to parse uos_navigation log, and
#               visualize vslam latency in charts.
#
## Usage:       ruby navi-chart.rb [options] /file/of/navigation/log
#
## Dependency:
#               sudo apt-get install ruby  (recommend ruby2.3 and above)
#               sudo apt-get install ruby2.3-dev
#               sudo apt-get install libmagickcore-dev
#               sudo apt-get install ruby-rmagick
#               sudo gem install gruff
#               sudo gem install descriptive_statistics

require 'gruff'
require 'optparse'
require 'ostruct'
require 'descriptive_statistics'
require 'time'

INDEX_VSLAM_TS_0            = 64
INDEX_VSLAM_TS_1            = 67
INDEX_VSLAM_TS_2            = 135 
INDEX_VSLAM_TS_3            = 151 
INDEX_RECORD_TS             = 68
RECORD_LINE_REGEXPR         = /^navi_log_input_data\:([\-\d\.\s]*)/ 

# --- Define Command Line Options --- #

def parse_options(args)
    options = OpenStruct.new
    options.verbose = false
    options.start = 5000
    options.max_num = 2000
    options.size = 800
    options.boundary = 0.6
    options.baseline = 0.3

    opt_parser = OptionParser.new do | opts |
        opts.banner = "Usage:  navi-chart.rb  [options]  uos_navigation.log"
        opts.separator ""
        opts.separator "Specific options:"

        opts.on("--start X", Integer, "Draw graph starting from the X-th record") do | x |
            options.start = x
        end

        opts.on("--max_num N", Integer, "Draw at most N bars") do | n |
            options.max_num = n
        end

        opts.on("--size S", Integer, "Chart geometry size in width") do | s |
            options.size = s
        end

        opts.on("--boundary B", Float, "Boundary of the latency to draw") do | b |
            options.boundary = b
        end

        opts.on("--baseline T", Float, "Baseline for valid data") do | t |
            options.baseline = t
        end

        opts.on("--verbose", "Output trivial information") do
            options.verbose = true
        end
    end

    opt_parser.parse!(args)
    options
end

# --- Parse and tokenize time measurement records --- #

def parse_tokenize(log_file, enable_flags)
    record_stream = []
    File.readlines(log_file).each do | line |
        begin
            if matched = line.match(RECORD_LINE_REGEXPR)
                data = matched[1].split(' ')
                rec_ts     = data[INDEX_RECORD_TS].to_f
                latency_arr = [INDEX_VSLAM_TS_0,
                               INDEX_VSLAM_TS_1,
                               INDEX_VSLAM_TS_2,
                               INDEX_VSLAM_TS_3].map { | idx |
                        enable_flags[idx] = true if data[idx].to_f > 1.0
                        latency = rec_ts - data[idx].to_f
                        latency = @options.boundary if latency > @options.boundary
                        latency
                    }
                record_stream << { :ts_val => rec_ts,
                                   :vslam_latency => latency_arr }
            end
        rescue Exception => e
            puts e.message
            next
        end
    end
    record_stream
end

def analyze_stream(record_stream, datasets)
    record_stream[@options.start, @options.max_num].each do | rec |
        puts rec if @options.verbose
        (0..3).each do | i |
            datasets[i].last << rec[:vslam_latency][i]
        end
    end
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
@enable_flags = {
    INDEX_VSLAM_TS_0 => false,  # vslam_0
    INDEX_VSLAM_TS_1 => false,  # vslam_1
    INDEX_VSLAM_TS_2 => false,  # vslam_2
    INDEX_VSLAM_TS_3 => false   # vslam_3
}

@record_stream = parse_tokenize(@logFile, @enable_flags)
puts "   Collected #{@record_stream.count} navigation records"
if @options.start > @record_stream.count
    puts "Start value is greater than the total record number!" and exit 0
end

@datasets = [
    [:vslam_0, INDEX_VSLAM_TS_0, []],
    [:vslam_1, INDEX_VSLAM_TS_1, []],
    [:vslam_2, INDEX_VSLAM_TS_2, []],
    [:vslam_3, INDEX_VSLAM_TS_3, []]
]

analyze_stream(@record_stream, @datasets)

puts " ---------------------- Draw VSLAM latency chart -------------------- "
puts "   Start from the #{@options.start}-th record"
puts "   Draw at most #{@options.max_num} records"

@chart = Gruff::Line.new(@options.size)
@chart.title = "VSLAM latency from navigation perspective"
@chart.title_font_size = 32
@chart.legend_font_size = 12
@chart.marker_font_size = 12
@chart.replace_colors(['#FDD84E', '#6886B4', '#72AE6E', '#8A6EAF', '#EFAA43',
                       '#FFE4E1', '#00FF00', 'white',])

@chart.baseline_value = @options.baseline
@max_num = 0 
@datasets.each do |metrics|
    next unless @enable_flags[metrics[1]]
    @chart.data(metrics.first, metrics.last)
    @max_num = metrics.last.count
end
@chart.labels = { 0 => Time.at(@record_stream[@options.start][:ts_val]).to_s,
                  [@max_num-1, 0].max => Time.at(@record_stream[[@options.start + @max_num, @record_stream.count-1].min][:ts_val]).to_s }

@chart.write "#{@logFile}.png"

puts " ---------------------- Print other metrics ------------------------------- "
@datasets.each do |metrics|
    next unless @enable_flags[metrics[1]]
    puts "   #{metrics.first}: mean(#{metrics.last.mean.round(3)}ms), stddev(#{metrics.last.standard_deviation.round(3)}ms)"
end

puts " ---------------------- Finished ------------------------------------------ "
system("xdg-open #{@logFile}.png")
