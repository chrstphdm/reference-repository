#!/usr/bin/ruby

# This script is used to script manual changes over nodes yaml files
# It copy files from input/ for a specific site and cluster and apply custom modifications and copy back transformed files to input/

require 'optparse'
require 'pp'
require 'erb'
require 'fileutils'
require 'pathname'
require 'yaml'
require '../lib/hash/hash'

if RUBY_VERSION < "2.1"
  puts "This script requires ruby >= 2.1"
  exit
end

puts 'Manual postprocessing of existing yaml files.'

#TODO use non-relative file paths everywhere...

options = {
  :site => "",
  :clusters => [],
  :rm_output => false
}

OptionParser.new do |opts|
  opts.banner = "Usage: [options]"

  opts.separator ""

  opts.separator "Filters:"

  opts.on('-s', '--site a', String, 'Select site(s)') do |s|
    options[:site] = s
  end

  opts.on('-c', '--clusters a,b,c', Array, 'Select clusters(s). Default: none') do |s|
    options[:clusters] = s
  end

  opts.on('--clean', 'Remove content from output/ after execution') do |s|
    options[:rm_output] = true
  end

end.parse!

if options[:site].empty? || options[:clusters].empty?
  puts "Not copying anything, post-processing file from 'output'"
else
  options[:clusters].each{ |cluster_uid|
    node_files = Dir["../../input/grid5000/sites/#{options[:site]}/clusters/#{cluster_uid}/nodes/*.yaml"]
    node_files.each{|f|
      filename = [f.split("/").last.split(".").first, options[:site], "grid5000", "fr", "yaml"].join(".")
      puts "Copying #{filename} to output/"
      FileUtils.cp(f, "./output/#{filename}")
    }
  }
end

##Modify node yaml hash here
def modify_node_data(hash, node_uid, cluster_uid, site_uid) #rubocop:disable Lint/UnusedMethodArgument

  #example content:
  hash["network_adapters"].each{ |na_id, na|
    if (na_id == "ib0" && na["firmware_version"] != "2.7.700")
      puts "#{node_uid}" + na.inspect
      na["firmware_version"] = "2.7.700"
      # na["mac"] = "80:00:02:0a:fe:" + na["mac"].split(":")[5..20].join(":")
    end
  }
  hash
end

list_of_yaml_files = Dir['output/*.y*ml'].sort_by { |x| -x.count('/') }
list_of_yaml_files.each { |filename|
  begin
    file     = filename.split("/")[1]
    node_uid = file.split(".")[0]
    site_uid = file.split(".")[1]
    cluster_uid = node_uid.split("-")[0]

    hash = YAML::load_file(filename)
    if hash == false
      puts "Unable to load YAML file #{filename}"
      next
    end

    hash = hash[node_uid]

    # Adapt content of modify_node_data
    hash = modify_node_data(hash, node_uid, cluster_uid, site_uid)
    #

    hash = {node_uid => hash}

    new_filename = Pathname("../../input/grid5000/sites/#{site_uid}/clusters/#{cluster_uid}/nodes/" + node_uid + ".yaml")

    new_filename.dirname.mkpath()

    write_yaml(new_filename, hash)

    contents = File.read(new_filename)
    File.open(new_filename, 'w') { |fd|
      fd.write("# Generated by g5k-checks (g5k-checks -m api)\n")
      fd.write(contents) 
    }

  rescue StandardError => e
    puts "#{node_uid} - #{e.class}: #{e.message}"
    puts e.backtrace
  end
}

if options[:rm_output]
  puts "Cleaning up output directory"
  FileUtils.rm Dir.glob("./output/*")
end
