require 'refrepo/hash/hash'

def g5kchecks_importer(sourcedir)
  puts "Importing source files from #{sourcedir} into input directory..."
  net_adapter_names_mapping = YAML::load_file(File.dirname(__FILE__) + "/net_names_mapping.yaml")

  if (net_adapter_names_mapping == false)
    puts "failed to load net adapters mappings 'net_names_mapping.yaml'"
    exit 1
  end

  list_of_yaml_files = Dir["#{sourcedir}/*.y*ml"].sort_by { |x| -x.count('/') }
  list_of_yaml_files.each do |filename|
    begin
      file     = File::basename(filename)
      node_uid = file.split(".")[0]
      site_uid = file.split(".")[1]
      cluster_uid = node_uid.split("-")[0]

      hash = YAML::load_file(filename)
      if hash == false
        puts "Unable to load YAML file #{filename}"
        next
      end

      puts "Post-processing node uid = #{node_uid}"

      hash["storage_devices"]  = hash["storage_devices"].sort_by_array(["sda", "sdb", "sdc", "sdd", "sde","sdf"])
      hash["storage_devices"].each {|k, v| v.delete("device") }

      remaped_net_names = []
      hash['network_adapters'].each { |net_name, net_adapter|
        net_adapter.delete("enabled")
        net_adapter.delete("mounted")
        net_adapter.delete("mountable")
        net_adapter.delete("rate") if net_adapter["rate"] == 0

        if (net_adapter_names_mapping[node_uid] && net_adapter_names_mapping[node_uid][net_name])
          #Priority of node-specific mapping instead of default cluster mapping
          remaped_net_names << [net_name, net_adapter_names_mapping[node_uid][net_name]]
        elsif (net_adapter_names_mapping[cluster_uid] && net_adapter_names_mapping[cluster_uid][net_name])
          remaped_net_names << [net_name, net_adapter_names_mapping[cluster_uid][net_name]]
        end
      }

      # Changing net_adapter key from predictable name to legacy name
      remaped_net_names.each { |arr|
        hash['network_adapters'][arr[1]] = hash['network_adapters'][arr[0]]
        hash['network_adapters'].delete(arr[0])
      }

      hash["network_adapters"] = hash["network_adapters"].sort_by_array(["eth0", "eth1", "eth2", "eth3", "eth4", "eth5", "eth6", "ib0", "ib1", "ib2", "ib3", "bmc"])

      hash = {node_uid => hash}

      new_filename = Pathname("input/grid5000/sites/#{site_uid}/clusters/#{cluster_uid}/nodes/" + node_uid + ".yaml")

      new_filename.dirname.mkpath()

      write_yaml(new_filename, hash)

      contents = File.read(new_filename)
      File.open(new_filename, 'w') do |fd|
        fd.write("# Generated by g5k-checks (g5k-checks -m api)\n")
        fd.write(contents) 
      end

    rescue StandardError => e
      puts "#{node_uid} - #{e.class}: #{e.message}\nError: #{e.backtrace}"
    end
  end
end
