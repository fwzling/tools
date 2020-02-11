#!/usr/bin/env ruby

## Description: Script to parse uos_navigation log, and
#               generate a pose list in time order for VSLAM mapping
#
## Usage:       ruby gen_anchor_by_navi.rb [options] --navilog /path/to/navi/log --imgdir /path/to/img/dir
#
## Dependency:
#               sudo apt-get install ruby  (recommend ruby2.3 and above)

require 'optparse'
require 'ostruct'
require 'time'

RECORD_LINE_REGEXPR = /^navi_log_output_data\:([\-\d\.]+)\s([\-\d\.]+)\s([\-\d\.]+)\s([\-\d\.]+)\s([\-\d\.]+)\s([\-\d\.]+)\s([\-\d\.]+)\s([\-\d\.]+)\s([\-\d\.]+)/
RAW_RECORD_LINE_REGEXPR = /^navi_log_input_data\:([\-\d\.\s[a-z]_]*)/
LOG_VERSION_REGEXPR = /log version\:\s+([\d\.]+)/

# --- Return GPS raw data index --- #
def get_gps_index(log_ver, field_name)
    case field_name
    when "GPS_TS"
        (log_ver.to_f < 0.2) ? 68 : 7
    when "GPS_EAST"
        (log_ver.to_f < 0.2) ? 17 : 22
    when "GPS_NORTH"
        (log_ver.to_f < 0.2) ? 18 : 23
    when "GPS_HEIGHT"
        (log_ver.to_f < 0.2) ? 81 : 25
    when "GPS_THETA"
        (log_ver.to_f < 0.2) ? 19 : 24
    when "GPS_STATE"
        (log_ver.to_f < 0.2) ? 20 : 37
    when "GPS_CONF"
        (log_ver.to_f < 0.2) ? 130 : 28
    when "GPS_ALPHA"
        (log_ver.to_f < 0.2) ? 82 : 26
    when "GPS_BETA"
        (log_ver.to_f < 0.2) ? 83 : 27
    else
        -1
    end
end

# --- Define Command Line Options --- #

def parse_options(args)
    options = OpenStruct.new
    options.navilog = "uos_navigation.log"
    options.imgdir  = "image_capturer_X"
    options.gps     = false
    options.verbose = false

    opt_parser = OptionParser.new do | opts |
        opts.banner = "Usage:  gen_anchor_by_navi.rb  [options]  --navilog uos_navigation.log --imgdir image_capturer_X"
        opts.separator ""
        opts.separator "Specific options:"

	    opts.on("--navilog f", String, "Path to uos_navigation") do | f |
            options.navilog = f
        end

	    opts.on("--imgdir d", String, "Dumpped image directory") do | d |
            options.imgdir = d
        end

        opts.on("--gps", "Use gps raw input") do
            options.gps = true
        end

        opts.on("--verbose", "Output trivial information") do
            options.verbose = true
        end
    end

    opt_parser.parse!(args)
    options
end

# --- Parse and tokenize time measurement records --- #
def parse_tokenize_raw(log_file)
    record_stream = []
    log_ver = "0.1"
    File.readlines(log_file).each do | line |
        begin
            if matched = line.match(RAW_RECORD_LINE_REGEXPR)
                data = matched[1].split(' ')
                record_stream << { :east   => data[get_gps_index(log_ver, "GPS_EAST")],
                                   :north  => data[get_gps_index(log_ver, "GPS_NORTH")],
                                   :height => data[get_gps_index(log_ver, "GPS_HEIGHT")],
                                   :alpha  => data[get_gps_index(log_ver, "GPS_ALPHA")],
                                   :beta   => data[get_gps_index(log_ver, "GPS_BETA")],
                                   :theta  => data[get_gps_index(log_ver, "GPS_THETA")],
                                   :state  => data[get_gps_index(log_ver, "GPS_STATE")],
                                   :conf   => data[get_gps_index(log_ver, "GPS_CONF")],
                                   :ts     => data[get_gps_index(log_ver, "GPS_TS")] }
            elsif matched = line.match(LOG_VERSION_REGEXPR)
                log_ver = matched[1]
            end
        rescue Exception => e
            puts e.message
            next
        end
    end
    record_stream
end

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

FileExts = ["tiff", "png"]
@options = parse_options(ARGV)

exit 1 if @options.navilog.nil? || @options.imgdir.nil?

if not File.exist?(@options.navilog)
    puts "ERROR: #{@options.navilog} not found"
    exit 1
end

if not File.exist?(@options.imgdir)
    puts "ERROR: #{@options.imgdir} not found"
    exit 1
end

puts " ---------------------- Processing navigation log --------------------------- "
if @options.gps
    @record_stream = parse_tokenize_raw(@options.navilog)
else
    @record_stream = parse_tokenize(@options.navilog)
end
puts "   Collected #{@record_stream.count} navigation records"
@record_dict = {}
@record_stream.each do | rec |
    k = rec[:ts].match(/(\d{10})/)[1]
    if not @record_dict.has_key?(k)
        @record_dict[k] = []
    end
    @record_dict[k] << rec
end

puts " ---------------------- Processing image directory --------------------------- "
@image_list = []
FileExts.each do | ext |
  @image_list += Dir[@options.imgdir + "/*." + ext]
end
@image_list.sort!
@image_ts_list = @image_list.map{ |p| p.match(/(\d{10}\.\d{3})/)[1] }
puts "   Collected #{@image_ts_list.count} image files"

puts " ---------------------- Generate anchor list --------------------------- "
@anchor_cnt = 0
open('cube_gps.txt', 'w') do | f |
    @image_ts_list.each do | t |
        k = t.match(/(\d{10})/)[1]
        navi_rec_candi = @record_dict[k]
        if not (navi_rec_candi.nil? || navi_rec_candi.empty?)
            selected = navi_rec_candi.min_by{ |r| (r[:ts].to_f - t.to_f).abs }
            if @options.verbose
                puts "--- #{t} ---"
                puts "- navi_rec_candi -"
                puts navi_rec_candi
                puts "- selected -"
                puts selected
            end
        end
        if not (selected.nil? || (selected[:ts].to_f - t.to_f).abs > 0.3 || selected[:conf].to_f < 0.5)
            yaw = 3.1415926 / 2.0 - selected[:theta].to_f
            anchor_line = "#{t} #{selected[:east]} #{selected[:north]} #{selected[:height]} #{yaw.round(3)} 0.0 0.0 1.0"
        else
            anchor_line = "#{t} 0.0 0.0 0.0 0.0 0.0 0.0 0.0"
        end
        puts "anchor_line: #{anchor_line}" if @options.verbose
        f << "#{anchor_line}\n" and @anchor_cnt += 1
    end
end
puts "   Collected #{@anchor_cnt} anchors"

puts " ---------------------- Finished ------------------------------------------ "
