## Usage: 
#  cd /path/to/uos_depend/lib
#  ruby symlinker.rb /path/to/uos_depend/lib
#
#  Find duplicated shared object files and make soft links
#  to save space
#

CurrWD = Dir.pwd

puts "<<< Start process duplicated so files >>> "
resolve_folder(CurrWD.dup)
puts "<<< Finished >>>"
Dir.chdir(CurrWD)

##
# @path: {String}  absolute path of the folder
def resolve_folder(path)
  sub_dirs, so_files = [], []

  Dir.entries(path).each do |ent|
    if File.directory?(File.join(path, ent)) && not [".", ".."].include?(ent)
      sub_dirs << ent
    elsif ent.match(/\.so(?:\.\d+)*$/)   # match abc.so, abc.so.1, abc.so.1.10
      so_files << ent
    else
      puts "[INFO] skip #{File.join(path, ent)}"
    end
  end

  resolve_so_files(path, so_files)

  sub_dirs.each { |p| resolve_folder(File.join(path, p)) }
end

##
# @path: {String}  absolute path of the folder that holds so files
# @so_files {[String]}  array of so file names
def resolve_so_files(path, so_files)
  puts "[INFO] change working directory to #{path}"
  Dir.chdir(path)

  # sort the so_files in the order of a.so.1.1, a.so.1, a.so, ...
  so_files.sort!.reverse!

  # symbolic link the later one to the last seen if qualified
  last_seen = "this.never.will.be.seen"
  so_files.each do |f|
    begin
      if last_seen.match(/^#{f}/) && not File.symlink?(f) && File.size(f) == File.size(last_seen)
        # remove the f, then create symbolic link to the object with more specific version
        puts "[REMOVE] #{File.join(path, f)}"
        File.delete(f)
        puts "[SYMLNK] #{f} --> #{last_seen}"
        File.symlink(last_seen, f)
      end
    rescue StandardError => err
      puts "[ERROR] #{File.join(path, f)} failed with #{e.message}"
    ensure
      last_seen = f
    end
  end
end
