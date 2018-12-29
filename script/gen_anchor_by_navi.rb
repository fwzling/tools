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

# --- Define Command Line Options --- #

def parse_options(args)
    options = OpenStruct.new
    options.navilog = "uos_navigation.log"
    options.imgdir  = "image_capturer_X"
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

FileExt = "tiff"
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
@record_stream = parse_tokenize(@options.navilog)
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
@image_list = Dir[@options.imgdir + "/*." + FileExt].sort
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
        if not (selected.nil? || (selected[:ts].to_f - t.to_f).abs > 0.2 || selected[:conf].to_f < 0.5)
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
