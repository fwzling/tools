#!/usr/bin/env ruby

## Description: Script to detect frame skip in dumped images with N-skipped-frames threshold 
#
## Usage:       ruby frame_skip_det.rb [options] /path/to/dump_images/image/image_capturer_X
#
## Dependency:
#               sudo apt-get install ruby  (recommend ruby2.3 and above)

require 'time'
require 'optparse'
require 'ostruct'

# --- Define Command Line Options --- #

def parse_options(args)
    options = OpenStruct.new
    options.verbose = false
    options.max_skip = 10
    options.dump_interval = 1

    opt_parser = OptionParser.new do | opts |
        opts.banner = "Usage:  frame_skip_det.rb  [options]  /path/to/dump_images/image/image_capturer_X"
        opts.separator ""
        opts.separator "Specific options:"

        opts.on("--max_skip N", Integer, "The max threshold to accept normal for frame skip") do | n |
            options.max_skip = n
        end

        opts.on("--dump_interval T", Integer, "Camera dump interval setting") do | t |
            options.dump_interval = t
        end

        opts.on("--verbose", "Output trivial information") do
            options.verbose = true
        end
    end

    opt_parser.parse!(args)
    options
end

# -------------------- main ---------------------- #

FileExt = "tiff"
@options = parse_options(ARGV)
@imgDir = ARGV[0]

exit 1 if @imgDir.nil?

if not File.exist?(@imgDir)
    puts "ERROR: #{@imgDir} not found"
    exit 1
end

@imgFiles = Dir[@imgDir + "/*." + FileExt].sort

@seqMarker = 0

@imgFiles.each do | fn |
    if matched = fn.match(/(\d+)\.\d+_(\d+)\.tiff/)
        seq = matched[2].to_i
        if seq - @seqMarker - @options.dump_interval > @options.max_skip
            puts "Detected #{seq - @seqMarker - @options.dump_interval} frames skipped at #{fn}"
        end
        @seqMarker = seq
    end
end
