#!/usr/bin/env ruby

## Description: Script to generate anchor poses for fisheye VSLAM mapping 
#               INPUT:  vtracker_test-log-1 [required]
#                       vtracker_test-log-2 [optional]
#                       path to image directory for mapping
#               OUTPUT: anchors list for each image
#
## Usage:       ruby gen_anchor_by_vtracker.rb [options]
#
## Dependency:
#               sudo apt-get install ruby  (recommend ruby2.3 and above)

require 'optparse'
require 'ostruct'
require 'time'

##
#  1:"1545900579.316" 2:"1" 3:"3.306" 4:"18.195" 5:"-1.584" 6:"1.583" 7:"-0.011" 8:"0.003" 9:"296"
#
#  Timestamp, State, X, Y, Z, Yaw, Pitch, Roll, Matches 
##
VTRACKER_TEST_RESULT_LINE = /testing result.*(\d{10}\.\d{3})[\d\_]+\.tiff (\d) (-?\d+\.\d+) (-?\d+\.\d+) (-?\d+\.\d+) (-?\d+\.\d+) (-?\d+\.\d+) (-?\d+\.\d+) (\d+)/ 

# --- Define Command Line Options --- #

def parse_options(args)
    options = OpenStruct.new
    options.log1 = "vtracker_test.log"
    options.log2 = ""
    options.imgdir  = "image_capturer_X"
    options.verbose = false

    opt_parser = OptionParser.new do | opts |
        opts.banner = "Usage:  gen_anchor_by_vtracker.rb  [options]"
        opts.separator ""
        opts.separator "Specific options:"
        
	    opts.on("--log1 f", String, "File path to vtracker_test.log") do | f |
            options.log1 = f
        end
        
	    opts.on("--log2 f", String, "File path to vtracker_test.log") do | f |
            options.log2 = f
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

# --- Parse and generate vtracker test result records --- #

def parse_and_generate_dict(log_file)
    record_stream = []
    File.readlines(log_file).each do | line |
        begin
            if matched = line.match(VTRACKER_TEST_RESULT_LINE)
                record_stream << { :ts      => matched[1],
                                   :state   => matched[2], 
                                   :x       => matched[3], 
                                   :y       => matched[4], 
                                   :z       => matched[5], 
                                   :yaw     => matched[6], 
                                   :pitch   => matched[7], 
                                   :roll    => matched[8], 
                                   :matches => matched[9] }
            end
        rescue Exception => e
            puts e.message
            next
        end
    end
    puts "   Collected #{record_stream.count} records from #{log_file}"
    dict = {}
    record_stream.each do | rec |
        k = rec[:ts].match(/(\d{10})/)[1].to_i
        if not dict.has_key?(k)
            dict[k] = []
        end
        dict[k] << rec
    end
    dict
end

#--- Check if the vtracker_test record a good anchor to the image timestamp

def pose_record_effective?(rec, img_ts)
    return false if rec.nil? || (rec[:ts].to_f - img_ts).abs > 0.2 || rec[:matches].to_i < 30
    true
end

# -------------------- main --------------------- #

FileExt = "tiff"
@options = parse_options(ARGV)

if not File.exist?(@options.log1)
    puts "ERROR: #{@options.log1} not found" and exit 1
end

if not @options.log2.empty?
    puts "ERROR: #{@options.log2} not found" and exit 1 unless File.exist?(@options.log2)
end

if not File.exist?(@options.imgdir)
    puts "ERROR: #{@options.imgdir} not found" and exit 1
end

puts " ---------------------- Processing vtracker_test log --------------------------- "
@pose_dict_1 = parse_and_generate_dict(@options.log1)
@pose_dict_2 = parse_and_generate_dict(@options.log2) if not @options.log2.empty?

puts " ---------------------- Processing image directory --------------------------- "
@image_list = Dir[@options.imgdir + "/*." + FileExt].sort
@image_ts_list = @image_list.map{ |p| p.match(/(\d{10}\.\d{3})/)[1] }
puts "   Collected #{@image_ts_list.count} image files"

puts " ---------------------- Generate anchor list --------------------------- "
@anchor_cnt = 0
@lost_cnt = 0
open('cube_gps.txt', 'w') do | f |
    @image_ts_list.each do | t |
        k = t.match(/(\d{10})/)[1].to_i
        pose_candidates_1 = (@pose_dict_1[k-1] || []) +
                            (@pose_dict_1[k]   || []) +
                            (@pose_dict_1[k+1] || [])
        selected = pose_candidates_1.min_by{ |r| (r[:ts].to_f - t.to_f).abs } unless pose_candidates_1.empty?

        if not pose_record_effective?(selected, t.to_f)
            pose_candidates_2 = (@pose_dict_2[k-1] || []) +
                                (@pose_dict_2[k]   || []) +
                                (@pose_dict_2[k+1] || [])
            selected = pose_candidates_2.min_by{ |r| (r[:ts].to_f - t.to_f).abs } unless pose_candidates_2.empty?
        end

        if pose_record_effective?(selected, t.to_f)
            yaw = (3.1415926 / 2.0 - selected[:yaw].to_f).round(3)
            anchor_line = "#{t} #{selected[:x]} #{selected[:y]} #{selected[:z]} #{yaw} #{selected[:pitch]} #{selected[:roll]} 1.0"
        else
            anchor_line = "#{t} 0.0 0.0 0.0 0.0 0.0 0.0 0.0"
            @lost_cnt += 1
        end
        puts "anchor_line: #{anchor_line}" if @options.verbose
        f << "#{anchor_line}\n" and @anchor_cnt += 1
    end
end
puts "   Collected #{@anchor_cnt} anchors and #{@lost_cnt} of them are LOST record"

puts " ---------------------- Finished ------------------------------------------ "
