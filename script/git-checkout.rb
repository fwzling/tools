#!/usr/bin/env ruby

## Description: Script to checkout uos_[*] branch in catkin workspace
#
## Usage:       git-checkout.rb --br BranchName [options]
#
## Dependency:
#               sudo apt-get install ruby  (recommend ruby2.3 and above)

require 'optparse'
require 'ostruct'
require 'open3'

# --- Define Command Line Options --- #

def parse_options(args)
    options = OpenStruct.new
    options.br = ""
    options.reset = false
    options.stash = false
    options.verb = false

    opt_parser = OptionParser.new do | opts |
        opts.banner = "Usage:  git-checkout.rb --br BranchName [options]"
        opts.separator ""
        opts.separator "Specific options:"

	    opts.on("--br BranchName", String, "Branch name") do | name |
            options.br = name
        end

	    opts.on("--reset", "Reset hard to origin/Branch/HEAD") do
            options.reset = true
        end

	    opts.on("--stash", "Auto stash uncommited changes") do
            options.stash = true
        end

        opts.on("--verb", "Output trivial information") do
            options.verb = true
        end
    end

    opt_parser.parse!(args)
    options
end


# --- Execute command --- #

def exec_capture(cmdline)
    puts "[EXEC CMD] #{cmdline}" if @options.verb

    stdout_msg, stderr_msg, status = Open3.capture3(cmdline)

    if @options.verb
        puts "#{cmdline} completed with (#{status.to_s})"
        puts "#{stdout_msg}"
    end

    puts "#{stderr_msg}" unless stderr_msg.empty?

    return status.exitstatus
end

def repo_status_ok?(dir)
    ok = false
    this_dir = Dir.pwd
    Dir.chdir(dir)
    puts "[EXEC CMD] git status" if @options.verb
    stdout_msg, stderr_msg, status = Open3.capture3("git status")
    puts "#{stderr_msg}" unless stderr_msg.empty?
    if status.success?
        if not stdout_msg.match(/working directory clean/).nil?
            ok = true
        elsif not stdout_msg.match(/Changes not staged for commit/).nil?
            ok = @options.stash ? true : false
        elsif not stdout_msg.match(/Untracked files/).nil?
            ok = true
        else
            puts "#{stdout_msg}"
        end
    end
    Dir.chdir(this_dir)
    return ok
end

def repo_reset_ok?(dir)
    ok = false
    this_dir = Dir.pwd
    Dir.chdir(dir)
    puts "[EXEC CMD] git status" if @options.verb
    stdout_msg, stderr_msg, status = Open3.capture3("git status")
    if status.success?
        if not stdout_msg.match(/can be fast-forwarded/).nil?
            ok = true
        else
            puts "#{stdout_msg}"
        end
    end
    Dir.chdir(this_dir)
    return ok
end

def branch_exist?(dir, brname)
    ok = false
    this_dir = Dir.pwd
    Dir.chdir(dir)
    puts "[EXEC CMD] git branch -r" if @options.verb
    stdout_msg, stderr_msg, status = Open3.capture3("git branch -r")
    puts "#{stderr_msg}" unless stderr_msg.empty?
    if status.success? and (not stdout_msg.empty?)
        ok = true unless stdout_msg.match(/origin\/#{brname}\n/).nil?
    end
    Dir.chdir(this_dir)
    puts "Branch: #{brname} does not exist in #{dir}" unless ok
    return ok
end


# -------------------- main --------------------- #

UosProjectDirs = ["/home/weif/Workspace/vtracker_dev",
                  "/home/weif/Workspace/vwo_dev",
                  "/home/weif/Workspace/cv_dev",
                  "/home/weif/Workspace/ai_dev"]

UosComponents = ["uos_3rdparty", "uos_admin", "uos_base", "uos_core",
                 "uos_chassis_gacu", "uos_camera", "uos_cv_framework",
                 "uos_hmi", "uos_io", "uos_lidar", "uos_lidar_framework",
                 "uos_lslam", "uos_map", "uos_rcslib", "uos_utility",
                 "uos_cv_perception", "vtracker"]

CurrentWD = Dir.pwd
SrcDir = CurrentWD + "/src"

@options = parse_options(ARGV)

if not UosProjectDirs.include?(CurrentWD)
    puts "Unknown UOS project directory: #{CurrentWD}"
    exit(1)
end

if @options.br.empty?
    puts "Specify a branch name via --br"
    exit(1)
end

puts ">>> Working on directory: #{CurrentWD}"

repos_found = []
repos_done = []

UosComponents.each do |repo|
    repo_path = SrcDir + "/" + repo
    branch = @options.br
    next unless Dir.exist?(repo_path)

    puts "[CHDIR] #{repo_path}"
    Dir.chdir(repo_path)

    repos_found << repo

    next unless repo_status_ok?(repo_path)

    next if exec_capture("git fetch") != 0

    next unless branch_exist?(repo_path, branch)

    if @options.stash
        next if exec_capture("git stash") != 0
        puts ">>> Auto stash to #{repo} done."
    end

    next if exec_capture("git checkout #{branch}") != 0

    if @options.reset and repo_reset_ok?(repo_path)
        next if exec_capture("git reset --hard origin/#{branch}") != 0
        puts ">>> Reset hard to #{repo} done."
    end

    puts ">>> Checkout #{repo} to #{branch} succeeded.\n"
    repos_done << repo
end

puts "-=-=-=- #{repos_found.count} repos found -=-=-=-"
repos_found.each {|repo| puts "   #{repo}"}

puts "-=-=-=- #{repos_done.count} repos done -=-=-=-"
repos_done.each {|repo| puts "   #{repo}"}
