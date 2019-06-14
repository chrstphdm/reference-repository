# coding: utf-8

require 'hashdiff'
require 'refrepo/data_loader'
require 'net/ssh'
require 'refrepo/gpu_ref'

class MissingProperty < StandardError; end

MiB = 1024**2

############################################
# Functions related to the "TABLE" operation
############################################

def export_rows_as_formated_line(generated_hierarchy)
  # Display header
  puts "+#{'-' * 10} + #{'-' * 20} + #{'-' * 5} + #{'-' * 5} + #{'-' * 8} + #{'-' * 4} + #{'-' * 20} + #{'-' * 30} + #{'-' * 30}+"
  puts "|#{'cluster'.rjust(10)} | #{'host'.ljust(20)} | #{'cpu'.ljust(5)} | #{'core'.ljust(5)} | #{'cpuset'.ljust(8)} | #{'gpu'.ljust(4)} | #{'gpudevice'.ljust(20)} | #{'cpumodel'.ljust(30)} | #{'gpumodel'.ljust(30)}|"
  puts "+#{'-' * 10} + #{'-' * 20} + #{'-' * 5} + #{'-' * 5} + #{'-' * 8} + #{'-' * 4} + #{'-' * 20} + #{'-' * 30} + #{'-' * 30}+"

  # Display rows
  generated_hierarchy[:rows].each do |row|
    cluster = row[:cluster].to_s
    host = row[:host].to_s
    cpu = row[:cpu].to_s
    core = row[:core].to_s
    cpuset = row[:cpuset].to_s
    gpu = row[:gpu].to_s
    gpudevice = row[:gpudevice].to_s
    cpumodel = row[:cpumodel].to_s
    gpumodel = row[:gpumodel].to_s
    puts "|#{cluster.rjust(10)} | #{host.ljust(20)} | #{cpu.ljust(5)} | #{core.ljust(5)} | #{cpuset.ljust(8)} | #{gpu.ljust(4)} | #{gpudevice.ljust(20)} | #{cpumodel.ljust(30)} | #{gpumodel.ljust(30)}|"
  end
  # Display footer
  puts "+#{'-' * 10} + #{'-' * 20} + #{'-' * 5} + #{'-' * 5} + #{'-' * 8} + #{'-' * 4} + #{'-' * 20} + #{'-' * 30} + #{'-' * 30}+"
end

############################################
# Functions related to the "PRINT" operation
############################################

# Generates an ASCII separator
def generate_separators()
  command = "echo '================================================================================'"
  return command + "\n"
end

def generate_create_disk_cmd(host, disk)
  disk_exist = "disk_exist '#{host}' '#{disk}'"
  command = "echo; echo 'Adding disk #{disk} on host #{host}:'\n"
  command += "#{disk_exist} && echo '=> disk already exists'\n"
  command += "#{disk_exist} || oarnodesetting -a -h '' -p host='#{host}' -p type='disk' -p disk='#{disk}'"
  return command + "\n\n"
end

def generate_set_node_properties_cmd(host, default_properties)
  if not default_properties.nil?
    return '' if default_properties.size == 0
    command  = "echo; echo 'Setting properties for #{host}:'; echo\n"
    command += "oarnodesetting --sql \"host='#{host}' and type='default'\" -p "
    command += properties_internal(default_properties)
    return command + "\n\n"
  else
    return "echo ; echo 'Not setting properties for #{host}: node is not available in ref-api (retired?)'; echo\n\n"
  end
end

def generate_set_disk_properties_cmd(host, disk, disk_properties)
  return '' if disk_properties.size == 0
  command = "echo; echo 'Setting properties for disk #{disk} on host #{host}:'; echo\n"
  command += "oarnodesetting --sql \"host='#{host}' and type='disk' and disk='#{disk}'\" -p "
  command += disk_properties_internal(disk_properties)
  return command + "\n\n"
end

def generate_create_oar_property_cmd(properties_keys)
  command = ''
  ignore_keys_list = ignore_default_keys()
  properties_keys.each do |key, key_type|
    if ignore_keys_list.include?(key)
      next
    end
    if key_type == Fixnum # rubocop:disable Lint/UnifiedInteger
      command += "property_exist '#{key}' || oarproperty -a #{key}\n"
    elsif key_type == String
      command += "property_exist '#{key}' || oarproperty -a #{key} --varchar\n"
    else
      raise "Error: the type of the '#{key}' property is unknown (Integer/String). Cannot generate the corresponding 'oarproperty' command. You must create this property manually ('oarproperty -a #{key} [--varchar]')"
    end
  end
  return command
end


# Generates helper functions:
#   - property_exist : check if a property exists
#   - node_exist : check if a node exists
#   - disk_exist : check if a disk exists
#
# and variables which help to add nex resources:
#   - NEXT_AVAILABLE_CPU_ID : the next identifier that can safely be used for a new cpi
#   - NEXT_AVAILABLE_CORE_ID : the next identifier that can safely be used for a new core
def generate_oar_commands_header()
  return %Q{
#! /usr/bin/env bash

set -eu
set -x
set -o pipefail

echo '================================================================================'

property_exist () {
  [[ $(oarproperty -l | grep -e "^$1$") ]]
}

node_exist () {
  [[ $(oarnodes --sql "host='$1' and type='default'") ]]
}

disk_exist () {
  [[ $(oarnodes --sql "host='$1' and type='disk' and disk='$2'") ]]
}


# if [ $(oarnodes -Y | grep " cpu:" | awk '{print $2}' | sort -nr | wc -c) == "0" ]; then
#   NEXT_AVAILABLE_CPU_ID=0
# else
#   MAX_CPU_ID=$(oarnodes -Y | grep " cpu:" | awk '{print $2}' | sort -nr | head -n1)
#   let "NEXT_AVAILABLE_CPU_ID=MAX_CPU_ID+1"
# fi
#
# if [ $(oarnodes -Y | grep " core:" | awk '{print $2}' | sort -nr | wc -c) == "0" ]; then
#   NEXT_AVAILABLE_CORE_ID=0
# else
#   MAX_CORE_ID=$(oarnodes -Y | grep " core:" | awk '{print $2}' | sort -nr | head -n1)
#   let "NEXT_AVAILABLE_CORE_ID=MAX_CORE_ID+1"
# fi
}
end


# Ensures that all required OAR properties exists.
# OAR properties can be divided in two sets:
#   - properties that were previously created by 'oar_resources_add'
#   - remaining properties that can be generated from API
def generate_oar_property_creation(site_name)

  #############################################
  # Create properties that were previously created
  # by 'oar_resources_add'
  ##############################################
  commands = %Q{
#############################################
# Create OAR properties that were created by 'oar_resources_add'
#############################################
property_exist 'host' || oarproperty -a host --varchar
property_exist 'cpu' || oarproperty -a cpu
property_exist 'core' || oarproperty -a core
property_exist 'gpudevice' || oarproperty -a gpudevice
property_exist 'gpu' || oarproperty -a gpu
property_exist 'gpu_model' || oarproperty -a gpu_model --varchar

}

  #############################################
  # Create remaining properties (from API)
  #############################################
  commands += %Q{
#############################################
# Create OAR properties if they don't exist
#############################################

}

  # Fetch oar properties from ref repo
  global_hash = load_data_hierarchy
  site_properties = get_oar_properties_from_the_ref_repo(global_hash, {
      :sites => [site_name]
  })[site_name]
  property_keys = get_property_keys(site_properties)

  # Generate OAR commands for creating properties
  commands += generate_create_oar_property_cmd(property_keys)

  return commands
end


# Exports a description of OAR ressources as a bunch of "self contained" OAR
# commands. Basically it does the following:
#   (0) * It adds an header containing helper functions and detects the next
#         CPU and CORE IDs that could be used by new OAR resources
#         (cf "generate_oar_commands_header()")
#   (0) * It creates OAR properties if they don't already exist (cf "generate_oar_property_creation()")
#   (1) * It iterates over nodes contained in the 'generated_hierarchy' hash-table
#   (2)    > * It iterates over the oar resources of the node
#   (3)         > * If the resource already exists, the CPU and CORE associated to the resource is detected
#   (4)           * The resource is exported as an OAR command
#   (5)      * If applicable, create/update the storage devices associated to the node
def export_rows_as_oar_command(generated_hierarchy, site_name, site_properties)

  result = ""

  # Generate helper functions and detect the next available CPU and CORE IDs for
  # non exisiting resources
  result += generate_oar_commands_header()

  # Ensure that OAR properties exist before creating/updating OAR resources
  result += generate_oar_property_creation(site_name)

  # Iterate over nodes of the generated resource hierarchy
  generated_hierarchy[:nodes].each do |node|
    result += %Q{

###################################
# #{node[:fqdn]}
###################################
}

    # Iterate over the resources of the OAR node
    node[:oar_rows].each do |oar_ressource_row|
      # host = oar_ressource_row[:host].to_s
      host = oar_ressource_row[:fqdn].to_s
      cpu = oar_ressource_row[:cpu].to_s
      core = oar_ressource_row[:core].to_s
      cpuset = oar_ressource_row[:cpuset].to_s
      gpu = oar_ressource_row[:gpu].to_s
      gpudevice = oar_ressource_row[:gpudevice].to_s
      gpumodel = oar_ressource_row[:gpumodel].to_s
      gpudevicepath = oar_ressource_row[:gpudevicepath].to_s
      resource_id = oar_ressource_row[:resource_id]

      if resource_id == -1 or resource_id.nil?
        # Add the resource to the OAR DB
        if gpu == ''
          result += "oarnodesetting -a -h '#{host}' -p host='#{host}' -p cpu=#{cpu} -p core=#{core} -p cpuset=#{cpuset}\n"
        else
          result += "oarnodesetting -a -h '#{host}' -p host='#{host}' -p cpu=#{cpu} -p core=#{core} -p cpuset=#{cpuset} -p gpu=#{gpu} -p gpu_model='#{gpumodel}' -p gpudevice=#{gpudevice} # This GPU is mapped on #{gpudevicepath}\n"
        end
      else
        # Update the resource
        if gpu == ''
          result += "oarnodesetting --sql \"host='#{host}' AND resource_id='#{resource_id}' AND type='default'\" -p host='#{host}' -p cpu=#{cpu} -p core=#{core} -p cpuset=#{cpuset}\n"
        else
          result += "oarnodesetting --sql \"host='#{host}' AND resource_id='#{resource_id}' AND type='default'\" -p host='#{host}' -p cpu=#{cpu} -p core=#{core} -p cpuset=#{cpuset} -p gpu=#{gpu} -p gpu_model='#{gpumodel}' -p gpudevice=#{gpudevice} # This GPU is mapped on #{gpudevicepath}\n"
        end
      end
    end

    # Set the OAR properties of the OAR node
    result += generate_set_node_properties_cmd(node[:fqdn], node[:default_description])

    # Iterate over storage devices
    node[:description]["storage_devices"].select {|k, v| v["reservation"]}.each do |storage_device|
      # As <storage_device> is an Array, where the first element is the device name (i.e. sda, sdb, ...),
      # and the second element is a dictionnary containing information about the storage device,
      # thus two variables are created:
      #    - <storage_device_name> : variable that contains the device name (sda, sdb, ...)
      #    - <storage_device_name_with_hostname> : variable that will be the ID of the storage. It follows this
      #       pattern : "sda1.ecotype-48"
      storage_device_name = storage_device[0]
      storage_device_name_with_hostname = "#{storage_device_name}.#{node[:name]}"

      # Retried the site propertie that corresponds to this storage device
      storage_device_oar_properties_tuple = site_properties["disk"].select { |keys| keys.include?(storage_device_name_with_hostname) }.first

      if storage_device_oar_properties_tuple.nil? or storage_device_oar_properties_tuple.size < 2
        raise "Error: could not find a site properties for disk #{storage_device_name_with_hostname}"
      end
      storage_device_oar_properties = storage_device_oar_properties_tuple[1]

      result += generate_separators()

      # Ensure that the storage device exists
      result += generate_create_disk_cmd(node[:fqdn], storage_device_name_with_hostname)

      # Set the OAR properties associated to this storage device
      result += generate_set_disk_properties_cmd(node[:fqdn], storage_device_name_with_hostname, storage_device_oar_properties)
    end

    result += generate_separators()
  end

  return result
end

############################################
# Functions related to the "DIFF" operation
############################################

def get_ids(host)
  node_uid, site_uid, grid_uid, _tdl = host.split('.')
  cluster_uid, node_num = node_uid.split('-')
  ids = { 'node_uid' => node_uid, 'site_uid' => site_uid, 'grid_uid' => grid_uid, 'cluster_uid' => cluster_uid, 'node_num' => node_num }
  return ids
end

# Get all node properties of a given site from the reference repo hash
# See also: https://www.grid5000.fr/mediawiki/index.php/Reference_Repository
def get_ref_default_properties(_site_uid, site)
  properties = {}
  site['clusters'].each do |cluster_uid, cluster|
    cluster['nodes'].each do |node_uid, node|
      begin
        properties[node_uid] = get_ref_node_properties_internal(cluster_uid, cluster, node_uid, node)
      rescue MissingProperty => e
        puts "Error (missing property) while processing node #{node_uid}: #{e}"
      rescue StandardError => e
        puts "FATAL ERROR while processing node #{node_uid}: #{e}"
        puts "Description of the node is:"
        pp node
        raise
      end
    end
  end
  return properties
end

def get_ref_disk_properties(site_uid, site)
  properties = {}
  site['clusters'].each do |cluster_uid, cluster|
    cluster['nodes'].each do |node_uid, node|
      begin
        properties.merge!(get_ref_disk_properties_internal(site_uid, cluster_uid, node_uid, node))
      rescue MissingProperty => e
        puts "Error while processing node #{node_uid}: #{e}"
      end
    end
  end
  return properties
end

# Generates the properties of a single node
def get_ref_node_properties_internal(cluster_uid, cluster, node_uid, node)
  h = {}

  if node['status'] == 'retired'
    # For dead nodes, additional information is most likely missing
    # from the ref-repository: just return the state
    h['state'] = 'Dead'
    return h
  end

  main_network_adapter = node['network_adapters'].find { |na| /^eth[0-9]*$/.match(na['device']) && na['enabled'] && na['mounted'] && !na['management'] }

  raise MissingProperty, "Node #{node_uid} does not have a main network_adapter (ie. an ethernet interface with enabled=true && mounted==true && management==false)" unless main_network_adapter

  h['ip'] = main_network_adapter['ip']
  raise MissingProperty, "Node #{node_uid} has no IP" unless h['ip']
  h['cluster'] = cluster_uid
  h['nodemodel'] = cluster['model']
  h['switch'] = main_network_adapter['switch']
  h['besteffort'] = node['supported_job_types']['besteffort']
  h['deploy'] = node['supported_job_types']['deploy']
  h['virtual'] = node['supported_job_types']['virtual']
  h['cpuarch'] = node['architecture']['platform_type']
  h['cpucore'] = node['architecture']['nb_cores'] / node['architecture']['nb_procs']
  h['cputype'] = [node['processor']['model'], node['processor']['version']].join(' ')
  h['cpufreq'] = node['processor']['clock_speed'] / 1_000_000_000.0
  h['disktype'] = (node['storage_devices'].first || {})['interface']

  # ETH
  ni_mountable = node['network_adapters'].select { |na| /^eth[0-9]*$/.match(na['device']) && (na['enabled'] == true && (na['mounted'] == true || na['mountable'] == true)) }
  ni_fastest   = ni_mountable.max_by { |na| na['rate'] || 0 }

  h['eth_count'] = ni_mountable.length
  h['eth_rate']  = ni_fastest['rate'] / 1_000_000_000

  puts "#{node_uid}: Warning - no rate info for the eth interface" if h['eth_count'] > 0 && h['eth_rate'] == 0

  # INFINIBAND
  ni_mountable = node['network_adapters'].select { |na| /^ib[0-9]*(\.[0-9]*)?$/.match(na['device']) && (na['interface'] == 'InfiniBand' and na['enabled'] == true && (na['mounted'] == true || na['mountable'] == true)) }
  ni_fastest   = ni_mountable.max_by { |na| na['rate'] || 0 }
  ib_map = { 0 => 'NO', 10 => 'SDR', 20 => 'DDR', 40 => 'QDR', 56 => 'FDR' }

  h['ib_count'] = ni_mountable.length
  h['ib_rate']  = ni_mountable.length > 0 ? ni_fastest['rate'] / 1_000_000_000 : 0
  h['ib'] = ib_map[h['ib_rate']]

  puts "#{node_uid}: Warning - no rate info for the ib interface" if h['ib_count'] > 0 && h['ib_rate'] == 0

  # OMNIPATH
  ni_mountable = node['network_adapters'].select { |na| /^ib[0-9]*(\.[0-9]*)?$/.match(na['device']) && (na['interface'] == 'Omni-Path' and na['enabled'] == true && (na['mounted'] == true || na['mountable'] == true)) }
  ni_fastest   = ni_mountable.max_by { |na| na['rate'] || 0 }

  h['opa_count'] = ni_mountable.length
  h['opa_rate']  = ni_mountable.length > 0 ? ni_fastest['rate'] / 1_000_000_000 : 0
  h['opa'] = h['opa_count'] > 0

  puts "#{node_uid}: Warning - no rate info for the opa interface" if h['opa_count'] > 0 && h['opa_rate'] == 0


  # MYRINET
  ni_mountable = node['network_adapters'].select { |na| /^myri[0-9]*$/.match(na['device']) && (na['enabled'] == true && (na['mounted'] == true || na['mountable'] == true)) }
  ni_fastest   = ni_mountable.max_by { |na| na['rate'] || 0 }
  myri_map = { 0 => 'NO', 2 => 'Myrinet-2000', 10 => 'Myri-10G' }

  h['myri_count'] = ni_mountable.length
  h['myri_rate']  = ni_mountable.length > 0 ? ni_fastest['rate'] / 1_000_000_000 : 0
  h['myri'] = myri_map[h['myri_rate']]

  puts "#{node_uid}: Warning - no rate info for the myri interface" if h['myri_count'] > 0 && h['myri_rate'] == 0

  h['memcore'] = node['main_memory']['ram_size'] / node['architecture']['nb_cores']/MiB
  h['memcpu'] = node['main_memory']['ram_size'] / node['architecture']['nb_procs']/MiB
  h['memnode'] = node['main_memory']['ram_size'] / MiB

  if node.key?('gpu_devices')
    # This forbids a node to host different GPU models ...
    h['gpu_model'] = GPURef.getGrid5000LegacyNameFor(node['gpu_devices'].values[0]['model'])
    h['gpu_count'] = node['gpu_devices'].length
  else
    h['gpu_model'] = false
    h['gpu_count'] = 0
  end

  h['mic'] = if node['mic']
               'YES'
             else
               'NO'
             end

  node['monitoring'] ||= {}
  h['wattmeter'] = case node['monitoring']['wattmeter']
                   when "true" then true
                   when "false" then false
                   when nil then false
                   else node['monitoring']['wattmeter'].upcase
                   end

  h['cluster_priority'] = (cluster['priority'] || Time.parse(cluster['created_at'].to_s).strftime('%Y%m')).to_i

  h['max_walltime'] = 0 # default
  h['max_walltime'] = node['supported_job_types']['max_walltime'] if node['supported_job_types'] && node['supported_job_types'].has_key?('max_walltime')

  h['production'] = get_production_property(node)
  h['maintenance'] = get_maintenance_property(node)

  # Disk reservation
  h['disk_reservation_count'] = node['storage_devices'].select { |v| v['reservation'] }.length

  # convert booleans to YES/NO string
  h.each do |k, v|
    if v == true
      h[k] = 'YES'
    elsif v == false
      h[k] = 'NO'
    elsif v.is_a? Float
      h[k] = v.to_s
    end
  end

  return h
end

def get_production_property(node)
  production = false # default
  production = node['supported_job_types']['queues'].include?('production') if node['supported_job_types'] && node['supported_job_types'].has_key?('queues')
  production = production == true ? 'YES' : 'NO'
  return production
end

def get_maintenance_property(node)
  maintenance = false # default
  maintenance = node['supported_job_types']['queues'].include?('testing') if node['supported_job_types'] && node['supported_job_types'].has_key?('queues')
  maintenance = maintenance == true ? 'YES' : 'NO'
  return maintenance
end

# Return a list of properties as a hash: { property1 => String, property2 => Fixnum, ... }
# We detect the type of the property (Fixnum/String) by looking at the existing values
def get_property_keys(properties)
  properties_keys = {}
  properties.each do |type, type_properties|
    properties_keys.merge!(get_property_keys_internal(type, type_properties))
  end
  return properties_keys
end

def properties_internal(properties)
  str = properties
            .to_a
            .select{|k, v| not ignore_default_keys.include? k}
            .map do |(k, v)|
                v = "YES" if v == true
                v = "NO"  if v == false
                !v.nil? ? "#{k}=#{v.inspect.gsub("'", "\\'").gsub("\"", "'")}" : nil
            end.compact.join(' -p ')
  return str
end

def disk_properties_internal(properties)
  str = properties
            .to_a
            .select{|k, v| not v.nil? and not v==""}
            .map do |(k, v)|
    v = "YES" if v == true
    v = "NO"  if v == false
    !v.nil? ? "#{k}=#{v.inspect.gsub("'", "\\'").gsub("\"", "'")}" : nil
  end.compact.join(' -p ')
  return str
end

# Returns the expected properties of the reservable disks. These
# properties are then compared with the values in OAR database, to
# generate a diff.
# The key is of the form [node, disk]. In the following example
# we list the different disks (from sdb to sdf) of node grimoire-1.
# {["grimoire-1", "sdb.grimoire-1"]=>
#  {"cluster"=>"grimoire",
#  "host"=>"grimoire-1.nancy.grid5000.fr",
#  "network_address"=>"",
#  "available_upto"=>0,
#  "deploy"=>"YES",
#  "production"=>"NO",
#  "maintenance"=>"NO",
#  "disk"=>"sdb.grimoire-1",
#  "diskpath"=>"/dev/disk/by-path/pci-0000:02:00.0-scsi-0:0:1:0",
#  "cpuset"=>-1},
#  ["grimoire-1", "sdc.grimoire-1"]=> ...
def get_ref_disk_properties_internal(site_uid, cluster_uid, node_uid, node)
  properties = {}
  node['storage_devices'].each_with_index do |device, index|
    disk = [device['device'], node_uid].join('.')
    if index > 0 && device['reservation'] # index > 0 is used to exclude sda
      key = [node_uid, disk]
      h = {}
      node_address = [node_uid, site_uid, 'grid5000.fr'].join('.')
      h['cluster'] = cluster_uid
      h['host'] = node_address
      h['network_address'] = ''
      h['available_upto'] = 0
      h['deploy'] = 'YES'
      h['production'] = get_production_property(node)
      h['maintenance'] = get_maintenance_property(node)
      h['disk'] = disk
      h['diskpath'] = device['by_path']
      h['cpuset'] = -1
      properties[key] = h
    end
  end
  properties
end

def get_oar_default_properties(site_uid, filename, options)
  oarnodes = get_oar_data(site_uid, filename, options)

  # Handle the two possible input format from oarnodes -Y:
  # given by a file, and from the OAR API
  if oarnodes.is_a?(Hash)
    oarnodes = oarnodes.map { |_k, v| v['type'] == 'default' ? [get_ids(v['host'])['node_uid'], v] : [nil, nil] }.to_h
    oarnodes.delete(nil)
  elsif oarnodes.is_a?(Array)
    oarnodes = oarnodes.select { |v| v['type'] == 'default' }.map { |v| [get_ids(v['host'])['node_uid'], v] }.to_h
  else
    raise 'Invalid input format for OAR properties'
  end
  return oarnodes
end

def get_oar_disk_properties(site_uid, filename, options)
  oarnodes = get_oar_data(site_uid, filename, options)

  # Handle the two possible input format from oarnodes -Y:
  # given by a file, and from the OAR API
  if oarnodes.is_a?(Hash)
    oarnodes = oarnodes.map { |_k, v|  v['type'] == 'disk' ? [[get_ids(v['host'])['node_uid'], v['disk']], v] : [nil, nil] }.to_h
    oarnodes.delete(nil)
  elsif oarnodes.is_a?(Array)
    oarnodes = oarnodes.select { |v| v['type'] == 'disk' }.map { |v| [[get_ids(v['host'])['node_uid'], v['disk']], v] }.to_h
  else
    raise 'Invalid input format for OAR properties'
  end
  return oarnodes
end

# Get all data from the OAR database
def get_oar_data(site_uid, filename, options)
  oarnodes = ''
  if filename && File.exist?(filename)
    # Read OAR properties from file
    puts "Reading OAR resources properties from file #{filename}" if options[:verbose]
    oarnodes = YAML.load(File.open(filename, 'rb') { |f| f.read })
  else

    if options[:api][:uri] and not options[:api][:uri].include? "api.grid5000.fr"
      api_uri = URI.parse(options[:api][:uri]+'/oarapi/resources/details.json?limit=999999')
    else
      api_uri = URI.parse('https://api.grid5000.fr/stable/sites/' + site_uid  + '/internal/oarapi/resources/details.json?limit=999999')
    end

    # Download the OAR properties from the OAR API (through G5K API)
    puts "Downloading resources properties from #{api_uri} ..." if options[:verbose]
    http = Net::HTTP.new(api_uri.host, api_uri.port)
    if api_uri.scheme == "https"
      http.use_ssl = true
    end
    request = Net::HTTP::Get.new(api_uri.request_uri, {'User-Agent' => 'reference-repository/gen/oar-properties'})

    # For outside g5k network access
    if options[:api][:user] && options[:api][:pwd]
      request.basic_auth(options[:api][:user], options[:api][:pwd])
    end

    response = http.request(request)
    raise "Failed to fetch resources properties from API: \n#{response.body}\n" unless response.code.to_i == 200
    puts '... done' if options[:verbose]

    oarnodes = JSON.parse(response.body)
    if filename
      puts "Saving OAR resources properties as #{filename}" if options[:verbose]
      File.write(filename, YAML.dump(oarnodes))
    end
  end

  # Adapt from the format of the OAR API
  oarnodes = oarnodes['items'] if oarnodes.key?('items')
  return oarnodes
end

def get_property_keys_internal(_type, type_properties)
  properties_keys = {}
  type_properties.each do |key, node_properties|
    # Differenciate between 'default' type (key = node_uid)
    # and 'disk' type (key = [node_uid, disk_id])
    node_uid, = key
    next if node_uid.nil?
    node_properties.each do |k, v|
      next if properties_keys.key?(k)
      next if NilClass === v
      # also skip detection if 'v == false' because it seems that if a varchar property
      # only as 'NO' values, it might be interpreted as a boolean
      # (see the ib property at nantes: ib: NO in the YAML instead of ib: 'NO')
      next if v == false
      properties_keys[k] = v.class
    end
  end
  return properties_keys
end

def diff_properties(type, properties_oar, properties_ref)
  properties_oar ||= {}
  properties_ref ||= {}

  if type == 'default'
    ignore_keys = ignore_keys()
    ignore_keys.each { |key| properties_oar.delete(key) }
    ignore_keys.each { |key| properties_ref.delete(key) }
  elsif type == 'disk'
    check_keys = %w(cluster host network_address available_upto deploy production maintenance disk diskpath cpuset)
    properties_oar.select! { |k, _v| check_keys.include?(k) }
    properties_ref.select! { |k, _v| check_keys.include?(k) }
  end

  # Ignore the 'state' property only if the node is not 'Dead' according to
  # the reference-repo.
  # Otherwise, we must enforce that the node state is also 'Dead' on the OAR server.
  # On the OAR server, the 'state' property can be modified by phoenix. We ignore that.
  if type == 'default' && properties_ref['state'] != 'Dead'
    properties_oar.delete('state')
    properties_ref.delete('state')
  elsif type == 'default' && properties_ref.size == 1
    # For dead nodes, when information is missing from the reference-repo, only enforce the 'state' property and ignore other differences.
    return Hashdiff.diff({'state' => properties_oar['state']}, {'state' => properties_ref['state']})
  end

  return Hashdiff.diff(properties_oar, properties_ref)
end

# These keys will not be created neither compared with the -d option
# ignore_default_keys is only applied to resources of type 'default'
def ignore_default_keys()
  # default OAR at resource creation:
  #  available_upto: '2147483647'
  #  besteffort: 'YES'
  #  core: ~
  #  cpu: ~
  #  cpuset: 0
  #  deploy: 'NO'
  #  desktop_computing: 'NO'
  #  drain: 'NO'
  #  expiry_date: 0
  #  finaud_decision: 'YES'
  #  host: ~
  #  last_available_upto: 0
  #  last_job_date: 0
  #  network_address: server
  #  next_finaud_decision: 'NO'
  #  next_state: UnChanged
  #  resource_id: 9
  #  scheduler_priority: 0
  #  state: Suspected
  #  state_num: 3
  #  suspended_jobs: 'NO'
  #  type: default
  ignore_default_keys = [
    "chassis",
    "slash_16",
    "slash_17",
    "slash_18",
    "slash_19",
    "slash_20",
    "slash_21",
    "slash_22",
    "available_upto",
    "besteffort",
    "chunks",
    "comment", # TODO
    "core", # This property was created by 'oar_resources_add'
    "cpu", # This property was created by 'oar_resources_add'
    "host", # This property was created by 'oar_resources_add'
    "gpudevice", # New property taken into account by the new generator
    "gpu_model", # New property taken into account by the new generator
    "gpu", # New property taken into account by the new generator
    "cpuset",
    "desktop_computing",
    "deploy",
    "drain",
    "expiry_date",
    "finaud_decision",
    "grub",
    "jobs", # This property exists when a job is running
    "last_available_upto",
    "last_job_date",
    "network_address", # TODO
    "next_finaud_decision",
    "next_state",
    "rconsole", # TODO
    "resource_id",
    "scheduler_priority",
    "state",
    "state_num",
    "subnet_address",
    "subnet_prefix",
    "suspended_jobs",
    "thread",
    "type", # TODO
    "vlan",
    "pdu",
    "id", # id from API (= resource_id from oarnodes)
    "api_timestamp", # from API
    "links", # from API
    "gpu",  # temporary hack, waiting for the new generator that will handle gpu
    "gpudevice",  # temporary hack, waiting for the new generator that will handle gpu
  ]
  return ignore_default_keys
end

# Properties of resources of type 'disk' to ignore (for example, when
# comparing resources of type 'default' with the -d option)
def ignore_disk_keys()
  ignore_disk_keys = [
    "disk",
    "diskpath"
  ]
  return ignore_disk_keys
end

def ignore_keys()
  return ignore_default_keys() + ignore_disk_keys()
end

def oarcmd_set_node_properties(host, default_properties)
  return '' if default_properties.size == 0
  command  = "echo; echo 'Setting properties for #{host}:'; echo\n"
  command += "oarnodesetting --sql \"host='#{host}' and type='default'\" -p "
  command += properties_internal(default_properties)
  return command + "\n\n"
end

def get_oar_resources_from_oar(options)
  properties = {}
  sites = options[:sites]
  diff = options[:diff]
  sites.each do |site_uid|
    filename = diff.is_a?(String) ? diff.gsub('%s', site_uid) : nil
    properties[site_uid] = {}
    properties[site_uid]['resources'] = get_oar_data(site_uid, filename, options)
  end
  # for debugging
  if ENV['FAKE_EMPTY_SITE']
    properties.keys.each do |site|
      properties[site]['resources'] = []
    end
  end
  return properties
end

# sudo exec
def run_commands_via_ssh(cmds, options, verbose=true)
  # The following is equivalent to : "cat cmds | bash"
  res = ""
  c = Net::SSH.start(options[:ssh][:host], options[:ssh][:user])
  c.open_channel { |channel|
    channel.exec('sudo bash') { |ch, success|
      # stdout
      channel.on_data { |ch2, data|
        if verbose
          puts data #if options[:verbose] # ssh cmd output
        end
        res += data
      }
      # stderr
      channel.on_extended_data do |ch2, type, data|
        if verbose
          puts data #if options[:verbose] # ssh cmd output
        end
        res += data
      end

      channel.send_data cmds
      channel.eof!
    }
  }
  c.loop
  return res
end

# Get the properties of each node
def get_oar_properties_from_the_ref_repo(global_hash, options)
  properties = {}
  sites = options[:sites]
  sites.each do |site_uid|
    properties[site_uid] = {}
    properties[site_uid]['default'] = get_ref_default_properties(site_uid, global_hash['sites'][site_uid])
    properties[site_uid]['disk'] = get_ref_disk_properties(site_uid, global_hash['sites'][site_uid])
  end
  return properties
end

def get_oar_properties_from_oar(options)
  properties = {}
  sites = options[:sites]
  diff = options[:diff]
  sites.each do |site_uid|
    filename = diff.is_a?(String) ? diff.gsub('%s', site_uid) : nil
    properties[site_uid] = {}
    properties[site_uid]['default'] = get_oar_default_properties(site_uid, filename, options)
    properties[site_uid]['disk'] = get_oar_disk_properties(site_uid, filename, options)
  end
  return properties
end

def do_diff(options, generated_hierarchy)

  global_hash = load_data_hierarchy
  properties = {}
  properties['ref'] = get_oar_properties_from_the_ref_repo(global_hash, options)
  properties['oar'] = get_oar_properties_from_oar(options)

  # Get the list of property keys from the reference-repo (['ref'])
  properties_keys = {
    'ref' => {},
    'oar' => {},
    'diff' => {}
  }

  options[:sites].each do |site_uid|
    properties_keys['ref'][site_uid] = get_property_keys(properties['ref'][site_uid])
  end
  ignore_default_keys = ignore_default_keys()

  # Diff
  if options[:diff]
    # Build the list of nodes that are listed in properties['oar'],
    # but does not exist in properties['ref']
    # We distinguish 'Dead' nodes and 'Alive'/'Absent'/etc. nodes
    missings_alive = []
    missings_dead = []
    properties['oar'].each do |site_uid, site_properties|
      site_properties['default'].each_filtered_node_uid(options[:clusters], options[:nodes]) do |node_uid, node_properties_oar|
        unless properties['ref'][site_uid]['default'][node_uid]
          node_properties_oar['state'] != 'Dead' ? missings_alive << node_uid : missings_dead << node_uid
        end
      end
    end

    if missings_alive.size > 0
      puts "*** Error: The following nodes exist in the OAR server but are missing in the reference-repo: #{missings_alive.join(', ')}.\n"
      ret = false unless options[:update] || options[:print]
    end

    skipped_nodes = []
    prev_diff = {}
    properties['diff'] = {}

    header = false
    properties['ref'].each do |site_uid, site_properties|
      properties['diff'][site_uid] = {}
      site_properties.each do |type, type_properties|
        properties['diff'][site_uid][type] = {}
        type_properties.each_filtered_node_uid(options[:clusters], options[:nodes]) do |key, properties_ref|
          # As an example, key can be equal to 'grimoire-1' for default resources or
          # ['grimoire-1', 1] for disk resources (disk n°1 of grimoire-1)
          node_uid, = key

          if properties_ref['state'] == 'Dead'
            skipped_nodes << node_uid
            next
          end

          properties_oar = properties['oar'][site_uid][type][key]

          diff = diff_properties(type, properties_oar, properties_ref) # Note: this deletes some properties from the input parameters
          diff_keys = diff.map { |hashdiff_array| hashdiff_array[1] }
          properties['diff'][site_uid][type][key] = properties_ref.select { |k, _v| diff_keys.include?(k) }

          # Verbose output
          if properties['oar'][site_uid][type][key].nil?
            info = ((type == 'default') ? ' new node !' : ' new disk !')
          else
            info = ''
          end

          case options[:verbose]
          when 1
            puts "#{key}:#{info}" if info != ''
            puts "#{key}:#{diff_keys}" if diff.size != 0
          when 2
            # Give more details
            if header == false
              puts "Output format: [ '-', 'key', 'value'] for missing, [ '+', 'key', 'value'] for added, ['~', 'key', 'old value', 'new value'] for changed"
              header = true
            end
            if diff.empty?
              puts "  #{key}: OK#{info}"
            elsif diff == prev_diff
              puts "  #{key}:#{info} same modifications as above"
            else
              puts "  #{key}:#{info}"
              diff.each { |d| puts "    #{d}" }
            end
            prev_diff = diff
          when 3
            # Even more details
            puts "#{key}:#{info}" if info != ''
            puts JSON.pretty_generate(key => { 'old values' => properties_oar, 'new values' => properties_ref })
          end
          if diff.size != 0
            ret = false unless options[:update] || options[:print]
          end
        end
      end

      # Get the list of property keys from the OAR scheduler (['oar'])
      properties_keys['oar'][site_uid] = get_property_keys(properties['oar'][site_uid])

      # Build the list of properties that must be created in the OAR server
      properties_keys['diff'][site_uid] = {}
      properties_keys['ref'][site_uid].each do |k, v_ref|
        v_oar = properties_keys['oar'][site_uid][k]
        properties_keys['diff'][site_uid][k] = v_ref unless v_oar
        if v_oar && v_oar != v_ref && v_ref != NilClass && v_oar != NilClass
          # Detect inconsistency between the type (String/Fixnum) of properties generated by this script and the existing values on the server.
          puts "Error: the OAR property '#{k}' is a '#{v_oar}' on the #{site_uid} server and this script uses '#{v_ref}' for this property."
          ret = false unless options[:update] || options[:print]
        end
      end

      puts "Properties that need to be created on the #{site_uid} server: #{properties_keys['diff'][site_uid].keys.to_a.delete_if { |e| ignore_default_keys.include?(e) }.join(', ')}" if options[:verbose] && properties_keys['diff'][site_uid].keys.to_a.delete_if { |e| ignore_default_keys.include?(e) }.size > 0

      # Detect unknown properties
      unknown_properties = properties_keys['oar'][site_uid].keys.to_set - properties_keys['ref'][site_uid].keys.to_set
      ignore_default_keys.each do |key|
        unknown_properties.delete(key)
      end

      if options[:verbose] && unknown_properties.size > 0
        puts "Properties existing on the #{site_uid} server but not managed/known by the generator: #{unknown_properties.to_a.join(', ')}."
        puts "Hint: you can delete properties with 'oarproperty -d <property>' or add them to the ignore list in lib/lib-oar-properties.rb."
        ret = false unless options[:update] || options[:print]
      end
      puts "Skipped retired nodes: #{skipped_nodes}" if skipped_nodes.any?


      # Check that CPUSETs on the OAR server are consistent with what would have been generated
      oar_resources = get_oar_resources_from_oar(options)

      fix_cmds = ""

      options[:clusters].each do |cluster|

        generated_rows_for_this_cluster = generated_hierarchy[:rows].select{|r| r[:cluster] == cluster}

        expected_servers_count = properties["ref"][site_uid]["default"]
                                     .map{|tuple2| tuple2[1]}
                                     .select{|x| x["cluster"] == cluster}
                                     .length

        site_resources = oar_resources[site_uid]["resources"]
        cluster_resources = site_resources.select{|x| x["cluster"] == cluster}
        default_cluster_resources = cluster_resources.select{|r| r["type"] == "default"}

        cpusets = default_cluster_resources.map{|x| x["cpuset"]}

        if cpusets.length > 0
          min_cpu_set = cpusets.min
          max_cpu_set = cpusets.max

          cluster_cpu_ids_offset = default_cluster_resources.map{|x| x["cpu"]}.min - 1
          cluster_core_ids_offset = default_cluster_resources.map{|x| x["core"]}.min - 1

          (min_cpu_set..max_cpu_set).each do |cpuset_index|

            default_cluster_resources_with_cpuset = default_cluster_resources.select{ |x| x["cpuset"] == cpuset_index }

            sorted_cpu_ids = default_cluster_resources_with_cpuset.map { |x| x["cpu"]}.sort_by {|x| x}

            # Check that the count of entries with this CPUSET matches the number of servers
            if default_cluster_resources_with_cpuset.length != expected_servers_count
              puts "ERROR: #{cluster}.#{site_uid}.grid5000.fr: expecting #{expected_servers_count} entries with cpuset=#{cpuset_index}, but #{default_cluster_resources_with_cpuset.length} found"
            end

            sorted_core_ids = default_cluster_resources_with_cpuset.map { |x| x["core"]}.sort_by {|x| x}

            # Check that the mapping (cpu, core) <-> "cpuset" is consistent
            if sorted_cpu_ids.length >= 1 and sorted_core_ids.length >= 1
              generated_rows_for_this_cluster.sort_by{|row| row[:core]}.each do |row|
                default_cluster_resources_with_cpuset.select{|y| y["cpu"] == cluster_cpu_ids_offset + row[:cpu] and y["core"] == cluster_core_ids_offset + row[:core] and y["cpuset"] != row[:cpuset] }.each do |y|
                  puts "ERROR: I computed that (cpu=#{cluster_cpu_ids_offset + row[:cpu]},core=#{cluster_core_ids_offset + row[:core]}) should be associated with CPUSET #{row[:cpuset]} on host #{row[:fqdn]}, however on server they are associated with CPUSET=#{y["cpuset"]}"
                  fix_cmds += %Q{
oarnodesetting --sql "resource_id='#{y["id"]}' AND type='default'" -p cpuset=#{row[:cpuset]}}
                end
              end
            end

            # Check GPUs associated with OAR ressources
            generated_rows_for_this_cluster.each do |row|
              corresponding_resource = default_cluster_resources_with_cpuset.select{|x| x["host"] == row[:fqdn] and x["cpuset"] == row[:cpuset]}
              if corresponding_resource.length > 0 and not row[:gpu].nil?
                if corresponding_resource[0]["gpudevice"].to_s != row[:gpudevice].to_s
                  puts "ERROR: I computed that GPU device of resource #{corresponding_resource[0]["id"]} should be #{row[:gpudevice]} instead of #{corresponding_resource[0]["gpudevice"]}"
                  fix_cmds += %Q{
oarnodesetting --sql "resource_id='#{corresponding_resource[0]["id"]}' AND type='default'" -p gpudevice=#{row[:gpudevice]}}
                end
                if corresponding_resource[0]["gpu"].to_s != row[:gpu].to_s
                  puts "ERROR: I computed that GPU ID of resource #{corresponding_resource[0]["id"]} should be #{row[:gpu]} instead of #{corresponding_resource[0]["gpu"]}"
                  fix_cmds += %Q{
oarnodesetting --sql "resource_id='#{corresponding_resource[0]["id"]}' AND type='default'" -p gpu=#{row[:gpu]}}
                end
              end
            end
          end

          # Check that OAR resources are associated with the right cpuset (thread)
          generated_rows_for_this_cluster.each do |row|
            corresponding_resource = default_cluster_resources.select{|r| r["id"] == row[:resource_id]}
            if corresponding_resource.length > 0
              if row[:cpu] != corresponding_resource[0]["cpu"]
                puts "Error: resource #{corresponding_resource[0]["id"]} is associated to CPU (#{corresponding_resource[0]["cpu"]}), while I computed that it should be associated to #{row[:cpu]}"
                fix_cmds += %Q{
oarnodesetting --sql "resource_id='#{corresponding_resource[0]["id"]}' AND type='default'" -p cpu=#{row[:cpu]}}
              end
              if row[:core] != corresponding_resource[0]["core"]
                puts "Error: resource #{corresponding_resource[0]["id"]} is associated to CORE (#{corresponding_resource[0]["core"]}), while I computed that it should be associated to #{row[:core]}"
                fix_cmds += %Q{
oarnodesetting --sql "resource_id='#{corresponding_resource[0]["id"]}' AND type='default'" -p core=#{row[:core]}}
              end
              if row[:cpuset] != corresponding_resource[0]["cpuset"]
                puts "Error: resource #{corresponding_resource[0]["id"]} is associated to CPUSET (#{corresponding_resource[0]["cpuset"]}), while I computed that it should be associated to #{row[:cpuset]}"
                fix_cmds += %Q{
oarnodesetting --sql "resource_id='#{corresponding_resource[0]["id"]}' AND type='default'" -p cpuset=#{row[:cpuset]}}
              end
            else
              puts "Error: could not find ressource with ID=#{row[:resource_id]}"
            end
          end
        end
      end

      if not fix_cmds.empty?
        puts ""
        puts "################################################"
        puts "# You may execute the following commands to fix "
        puts "# some resources of the OAR database"
        puts "################################################"
        puts fix_cmds
      end

    end # if options[:diff]
  end
end

############################################
# MAIN function
############################################

# This function is called from RAKE and is in charge of
#   - printing OAR commands to
#      > add a new cluster
#      > update and existing cluster
#   - execute these commands on an OAR server
def generate_oar_properties(options)

  options[:api] ||= {}
  conf = RefRepo::Utils.get_api_config
  options[:api][:user] = conf['username']
  options[:api][:pwd] = conf['password']
  options[:api][:uri] = conf['uri']
  options[:ssh] ||= {}
  options[:ssh][:user] ||= 'g5kadmin'
  options[:ssh][:host] ||= 'oar.%s.g5kadmin'
  options[:sites] = [options[:site]] # for compatibility with other generators

  # This function works as follow:
  # (1) Initialization
  #    (a) Load the local data contained in YAML input files
  #    (b) Handle the program arguments (detects which site and which clusters
  #        are targeted), and what action is requested
  #    (c) Fetch the OAR properties of the requested site
  # (2) Generate an OAR node hierarchy
  #    (a) Iterate over cluster > nodes > cpus > cores
  #    (b) [if applicable] detects the mapping GPU <-> CPU
  #    (c) associate to each core a cpuset
  #    (d) [if applicable] associate to each core a gpuset
  # (3) Do something with the generated hierarchy

  ############################################
  # Complete options with data from YAML files
  ############################################

  input_files_hierarchy = load_yaml_file_hierarchy

  site_name = options[:site]

  # # Get the list of property keys from the reference-repo (['ref'])
  # global_hash = load_data_hierarchy
  # properties_ref = get_oar_properties_from_the_ref_repo(global_hash, options)
  # property_keys = get_property_keys(properties_ref)

  # If no cluster is given, then the clusters are the cluster of the given site
  if not options.key? :clusters or options[:clusters].length == 0
    clusters = input_files_hierarchy['sites'][site_name]['clusters'].keys
    options[:clusters] = clusters
  else
    clusters = options[:clusters]
  end

  ############################################
  # Initialize variables
  ############################################

  oar_resources = get_oar_resources_from_oar(options)

  generated_hierarchy = {
      :rows => [],
      :nodes => []
  }

  will_soon_be_allocated_cpus = []
  will_soon_be_allocated_cores = []
  will_soon_be_allocated_gpus = []

  ############################################
  # Iterate over clusters
  ############################################

  global_hash = load_data_hierarchy
  site_properties = get_oar_properties_from_the_ref_repo(global_hash, {
      :sites => [site_name]
  })[site_name]

  site_resources = oar_resources[site_name]["resources"].select{|r| r["type"] == "default"}

  current_max_cpu_id = site_resources.length > 0 ? site_resources.map{|r| r["cpu"]}.max : 0
  current_max_core_id = site_resources.length > 0 ? site_resources.map{|r| r["core"]}.max : 0
  current_max_gpu_id = site_resources.length > 0 ? site_resources.map{|r| r["gpu"]}.select{|x| not x.nil?}.max : 0

  # Iterate over clusters
  clusters.each do |cluster_name|

    cpu_current_max_id = 0
    core_current_max_id = 0
    gpu_current_max_id = 0

    cluster_resources = site_resources.select{|r| r["cluster"] == cluster_name}

    cluster_description = input_files_hierarchy['sites'][site_name]['clusters'][cluster_name]
    first_node = cluster_description['nodes'].first[1]

    cluster_numa_description = nil

    # Look for information about NUMA from the input YAML file
    if first_node.key? "gpu_devices"
      cluster_numa_description = first_node["gpu_devices"]
    end

    node_count = cluster_description['nodes'].length
    cpu_count = first_node['architecture']['nb_procs']
    core_count = first_node['architecture']['nb_cores'] / cpu_count
    gpu_count = first_node.key?("gpu_devices") ? first_node["gpu_devices"].length : 0
    cpu_model = "#{first_node['processor']['model']} #{first_node['processor']['version']}"

    # Detect if the cluster is new, or if it is already known by OAR
    new_cluster = cluster_resources.select{|x| x["cluster"] == cluster_name}.length == 0

    if new_cluster
      cpu_ids = [*current_max_cpu_id+1..current_max_cpu_id+node_count*cpu_count]
      core_ids = [*current_max_core_id+1..current_max_core_id+node_count*cpu_count*core_count]
      gpu_ids = gpu_count > 0 ? [*current_max_gpu_id+1..current_max_gpu_id+node_count*gpu_count] : []
      resource_ids = core_ids.map{|r| -1}

      current_max_cpu_id = cpu_ids.max
      current_max_core_id = core_ids.max
      current_max_gpu_id = gpu_count > 0 ? gpu_ids.max : current_max_gpu_id
    else
      cpu_ids = cluster_resources.map{|r| r["cpu"]}.uniq.sort
      core_ids = cluster_resources.map{|r| r["core"]}.uniq.sort
      gpu_ids = cluster_resources.map{|r| r["gpu"]}.select{|x| not x.nil?}.uniq.sort
      resource_ids = cluster_resources.map{|r| r["id"]}.uniq.sort
    end

    # Try to fix a bad existing CPU configuration. There is two main cases:
    #  1) We detect too many cpus: it likely means than a cpu of another cluster has been mis-associated to
    #     this cluster. A simple fix is to sort CPUS of the cluster according to their number of occurence in
    #     the cluster's properties, and keep only the N CPUs that appears the most frequently, where N is equal
    #     to node_count * cpu_count
    #  2) We don't have enough cpus: it likely means that a same cpu has been associated to different properties,
    #     and that a "gap" should exist in cpu IDs (.i.e some cpu IDs are available). We fill the missing cpus
    #     with available cpus
    if cpu_ids.length > node_count * cpu_count
      cpu_ids = cluster_resources
                    .map{|r| r["cpu"]}
                    .uniq
                    .map{|cpu| {:count => cluster_resources.select{|r| r["cpu"] == cpu}.length, :cpu => cpu}}
                    .sort_by {|v| v[:count]}[-node_count*cpu_count..-1]
                    .map{|tuple2| tuple2[:cpu]}
                    .sort
    elsif cpu_ids.length < node_count * cpu_count
      missing_cpus_count = node_count * cpu_count - cpu_ids.length
      site_allocated_cpu_ids = site_resources.map{|r| r["cpu"]}.uniq
      unallocated_cpus = (1..current_max_cpu_id)
                             .select{|cpu_id| not site_allocated_cpu_ids.include?(cpu_id)}
                             .select{|cpu_id| not will_soon_be_allocated_cpus.include?(cpu_id)}
      will_soon_be_allocated_cpus += unallocated_cpus[0..missing_cpus_count]
      cpu_ids = (cpu_ids + unallocated_cpus[0..missing_cpus_count])
                    .uniq
                    .sort
    end

    # Try to fix a bad existing CORE configuration. There is two main cases:
    #  1) We detect too many cores: it likely means than a core of another cluster has been mis-associated to
    #     this cluster. A simple fix is to sort CORES of the cluster according to their number of occurence in
    #     the cluster's properties, and keep only the N cores that appears the most frequently, where N is equal
    #     to node_count * cpu_count * core_count
    #  2) We don't have enough cores: it likely means that a same core has been associated to different properties,
    #     and that a "gap" should exist in core IDs (.i.e some core IDs are available). We fill the missing cores
    #     with available cores
    if core_ids.length > node_count * cpu_count * core_count
      core_ids = cluster_resources
                    .map{|r| r["core"]}
                    .uniq
                    .map{|core| {:count => cluster_resources.select{|r| r["core"] == cpu}.length, :core => core}}
                    .sort_by {|v| v[:count]}[-node_count*cpu_count*core_count..-1]
                    .map{|tuple2| tuple2[:core]}
                    .sort
    elsif core_ids.length < node_count * cpu_count * core_count
      missing_cores_count = node_count * cpu_count - cpu_ids.length
      site_allocated_core_ids = site_resources.map{|r| r["core"]}.uniq
      unallocated_cores = (1..current_max_core_id)
                             .select{|core_id| not site_allocated_core_ids.include?(core_id)}
                             .select{|core_id| not will_soon_be_allocated_cores.include?(core_id)}
      will_soon_be_allocated_cores += unallocated_cores[0..missing_cores_count]
      core_ids = (core_ids + unallocated_cores[0..missing_cores_count])
                    .uniq
                    .sort
    end

    # Try to fix a bad existing GPU configuration. There is two main cases:
    #  1) We detect too many gpus: it likely means than a gpu of another cluster has been mis-associated to
    #     this cluster. A simple fix is to sort GPUs of the cluster according to their number of occurence in
    #     the cluster's properties, and keep only the N GPUs that appears the most frequently, where N is equal
    #     to node_count * cpu_count * gpu_count
    #  2) We don't have enough gpus: it likely means that a same gpu has been associated to different properties,
    #     and that a "gap" should exist in gpu IDs (.i.e some gpu IDs are available). We fill the missing gpus IDs
    #     with available gpus IDs
    if gpu_ids.length > node_count * gpu_count
      gpu_ids = cluster_resources
                     .map{|r| r["gpu"]}
                     .uniq
                     .map{|gpu| {:count => cluster_resources.select{|r| r["gpu"] == gpu}.length, :gpu => gpu}}
                     .sort_by {|v| v[:count]}[-node_count*gpu_count..-1]
                     .map{|tuple2| tuple2[:gpu]}
                     .sort
    elsif gpu_ids.length < node_count * gpu_count
      missing_gpus_count = node_count * gpu_count - gpu_ids.length
      site_allocated_gpus_ids = site_resources.map{|r| r["gpu"]}.uniq
      unallocated_gpus = (1..current_max_gpu_id)
                              .select{|gpu_id| not site_allocated_gpus_ids.include?(gpu_id)}
                              .select{|gpu_id| not will_soon_be_allocated_gpus.include?(gpu_id)}
      will_soon_be_allocated_gpus += unallocated_gpus[0..missing_gpus_count]
      gpu_ids = (gpu_ids + unallocated_gpus[0..missing_gpus_count])
                     .uniq
                     .sort
    end

    # Detect how cpusets are distributed
    cpuset_attribution_policy = 'round-robin'
    # cpuset_attribution_policy = 'continuous'
    if not cluster_numa_description.nil?
      if cluster_numa_description.key? 'cpu_distribution'
        cpuset_attribution_policy = cluster_numa_description['cpu_distribution']
      end
      if cluster_numa_description.key? 'gpu_distribution'
        gpuset_attribution_policy = cluster_numa_description['gpu_distribution']
      end
    end

    # Iterate over nodes
    (1..node_count).each do |node_num|
      name = "#{cluster_name}-#{node_num}"
      fqdn = "#{cluster_name}-#{node_num}.#{site_name}.grid5000.fr"
      node_description = cluster_description["nodes"][name]

      node_description_default_properties = site_properties["default"][name]

      # Detect GPU configuration of nodes
      if node_description.key? "gpu_devices"
        gpus = node_description["gpu_devices"]
      else
        gpus = []
      end

      # Assign an ID to each GPU of the node. It will be used for gpuset.
      # The "local_id" begins at 0
      gpu_idx = 0
      gpus.map do |v|
        v[1]['local_id'] = gpu_idx
        gpu_idx += 1
      end

      if cpuset_attribution_policy == 'continuous'
        cpuset = 0
      end

      generated_node_description = {
          :name => name,
          :fqdn => fqdn,
          :cluster_name => cluster_name,
          :site_name => site_name,
          :description => node_description,
          :oar_rows => [],
          :disks => [],
          :gpus => gpus,
          :default_description => node_description_default_properties
      }

      # Iterate over NUMA nodes (CPU)
      (1..cpu_count).each do |cpu_num|
        # IDs of NUMA start at 0
        numa_node = cpu_num - 1

        # Find GPUs associated with the current NUMA node
        numa_gpus = []
        if node_description.key? "gpu_devices"
            numa_gpus = node_description["gpu_devices"].map {|v| v[1]}.select {|v| v['cpu_affinity'] == numa_node}
        end

        # Iterate over cores
        (1..core_count).each do |core_num|
          row = {
              :cluster => cluster_name,
              :host => name,
              :cpu => cpu_ids[cpu_current_max_id],
              :core => core_ids[core_current_max_id],
              :cpuset => nil,
              :gpu => nil,
              :gpudevice => nil,
              :gpudevicepath => nil,
              :cpumodel => nil,
              :gpumodel => nil,
              :oar_properties => nil,
              :fqdn => fqdn,
              :resource_id => resource_ids[core_current_max_id],
          }

          # Define the cpuset
          if cpuset_attribution_policy == 'continuous'
            row[:cpuset] = cpuset
          else
            row[:cpuset] = (cpu_num - 1) + (core_num - 1) * cpu_count # smallest 'cpuset' is 0
          end

          row[:cpumodel] = cpu_model

          # Define the gpuset
          if not numa_gpus.empty?
            if gpuset_attribution_policy == 'continuous'
              gpu_idx = (core_num - 1) / (core_count / numa_gpus.length)
            else
              gpu_idx = (core_num - 1) % numa_gpus.length
            end

            selected_gpu = numa_gpus[gpu_idx]
            if selected_gpu.nil?
              next
            end

            row[:gpu] = gpu_ids[(node_num - 1) * gpu_count + selected_gpu['local_id']]
            row[:gpudevice] = selected_gpu['local_id']
            row[:gpudevicepath] = selected_gpu['device']
            row[:gpumodel] = selected_gpu['model']
          end

          core_current_max_id += 1

          if cpuset_attribution_policy == 'continuous'
            cpuset += 1
          end

          generated_hierarchy[:rows].push(row)
          generated_node_description[:oar_rows].push(row)
        end
        cpu_current_max_id += 1
      end

      # If relevant, increment the counter of GPUs
      if node_description.key? "gpu_devices"
        gpu_count = gpus.length
        gpu_current_max_id += gpu_count
      end

      generated_hierarchy[:nodes].push(generated_node_description)
    end
  end

  ############################################
  # Output generated information
  ############################################

  # DO=table
  if options.key? :table and options[:table]
    export_rows_as_formated_line(generated_hierarchy)
  end

  # DO=print
  if options.key? :print and options[:print]
    cmds = export_rows_as_oar_command(generated_hierarchy, site_name, site_properties)
    puts(cmds)
  end

  # Do=Diff
  if options.key? :diff and options[:diff]
    do_diff(options, generated_hierarchy)
  end

  # Do=update
  if options[:update]
    printf 'Apply changes to the OAR server ' + options[:ssh][:host].gsub('%s', site_name) + ' ? (y/N) '
    prompt = STDIN.gets.chomp
    cmds = export_rows_as_oar_command(generated_hierarchy, site_name, site_properties)
    run_commands_via_ssh(cmds, options) if prompt.downcase == 'y'
  end

  return 0
end
