require 'bundler/setup'

if ENV['COV']
  require 'simplecov'
  SimpleCov.start
end

if RUBY_VERSION < "2.1"
  puts "This script requires ruby >= 2.1"
  exit
end

$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), 'lib')))
require 'refrepo'

if Dir::exist?(ENV['HOME'] + '/.gpuppet/repo')
  PUPPET_ODIR = ENV['HOME'] + '/.gpuppet/repo'
else
  PUPPET_ODIR = '/tmp/puppet'
end

G5K_SITES = RefRepo::Utils::get_sites

desc "Import YAML files generated by g5k-checks to input/ dir -- parameters: SOURCEDIR=directory"
task "g5k-checks-import" do
  require 'refrepo/g5kchecks_importer'
  sourcedir = ENV['SOURCEDIR']
  if sourcedir.nil?
    puts "SOURCEDIR= needed. Exiting."
    exit(1)
  end
  g5kchecks_importer(sourcedir)
end


namespace :valid do

  desc "Check homogeneity of clusters -- parameters: [SITE={grenoble,..}] [CLUSTER={yeti,..}] [VERBOSE=1]"
  task "homogeneity" do
    require 'refrepo/valid/homogeneity'
    options = {}
    options[:sites] = ( ENV['SITE'] ? ENV['SITE'].split(',') : G5K_SITES )
    options[:clusters] = ( ENV['CLUSTER'] ? ENV['CLUSTER'].split(',') : [] )
    options[:verbose] = ENV['VERBOSE'].to_i if ENV['VERBOSE']

    ret = check_cluster_homogeneity(options)
    exit(ret)
  end

  desc "Check for duplicates fields in input -- parameters: [SITE={grenoble..}] [CLUSTER={yeti,...}] [VERBOSE=1]"
  task "duplicates" do
    require 'refrepo/valid/input/duplicates'
    options = {}
    options[:sites] = ( ENV['SITE'] ? ENV['SITE'].split(',') : G5K_SITES )
    options[:clusters] = ( ENV['CLUSTER'] ? ENV['CLUSTER'].split(',') : [] )
    options[:verbose] = ENV['VERBOSE'].to_i if ENV['VERBOSE']
    ret = yaml_input_find_duplicates(options)
    exit(ret)
  end

  desc "Check input data schema validity -- parameters: [SITE={grenoble,..}] [CLUSTER={yeti,..}]"
  task "schema" do
    require 'refrepo/valid/input/schema'
    options = {}
    options[:sites] = ( ENV['SITE'] ? ENV['SITE'].split(',') : G5K_SITES )
    options[:clusters] = ( ENV['CLUSTER'] ? ENV['CLUSTER'].split(',') : [] )
    ret = yaml_input_schema_validator(options)
    exit(ret)
  end

  desc "Check OAR properties -- parameters: [SITE={grenoble,...}] [CLUSTER={yeti,...}] [VERBOSE=1]"
  task "oar-properties" do
    require 'refrepo/valid/oar-properties'
    options = {}
    options[:sites] = ( ENV['SITE'] ? ENV['SITE'].split(',') : G5K_SITES )
    options[:clusters] = ( ENV['CLUSTER'] ? ENV['CLUSTER'].split(',') : [] )
    options[:verbose] = true if ENV['VERBOSE']
    ret = RefRepo::Valid::OarProperties::check(options)
    exit(ret)
  end

  desc "Check network description -- parameters: [SITE={grenoble,...}] [VERBOSE=1] [GENERATE_DOT=1]"
  task "network" do
    require 'refrepo/valid/network'
    options = {}
    options[:sites] = ( ENV['SITE'] ? ENV['SITE'].split(',') : G5K_SITES )
    options[:verbose] = true if ENV['VERBOSE']
    options[:dot] = true if ENV['GENERATE_DOT']
    ret = 2
    begin
      ret = check_network_description(options)
    rescue StandardError => e
      puts e
      puts e.backtrace
      ret = 3
    ensure
      exit(ret)
    end
  end
end

namespace :gen do
  desc "Run wiki generator -- parameters: NAME={hardware,site_hardware,...} SITE={global,grenoble,...} DO={diff,print,update}"
  task "wiki" do
    require 'refrepo/gen/wiki'
    options = {}
    options[:sites] = ( ENV['SITE'] ? ENV['SITE'].split(',') : ['global'] + G5K_SITES )
    if ENV['NAME']
      options[:generators] = ENV['NAME'].split(',')
    else
      puts "You must specify a generator name using NAME="
      exit(1)
    end
    options[:diff] = false
    options[:print] = false
    options[:update] = false
    if ENV['DO']
      ENV['DO'].split(',').each do |t|
        options[:diff] = true if t == 'diff'
        options[:print] = true if t == 'print'
        options[:update] = true if t == 'update'
      end
    else
      puts "You must specify something to do using DO="
      exit(1)
    end
    ret = RefRepo::Gen::Wiki::wikigen(options)
    exit(ret)
  end

  desc "Generate OAR properties -- parameters: SITE=grenoble CLUSTER={yeti,...} DO={print,table,update,diff} [VERBOSE={0,1,2,3}] [OAR_SERVER=192.168.37.10] [OAR_SERVER_USER=g5kadmin]"
  task "oar-properties" do
    # Manage oar-properties for a given set of Grid'5000 cluster. The task takes the following parameters
    # Params:
    # +SITE+:: Grid'5000 site (Nantes, Nancy, ...).
    # +CLUSTERS+:: a comma separated list of Grid'5000 clusters (econome, ecotype, ...). This argument is optional:
    #     if no clusters is provided, the script will be run on each cluster of the specified site.
    # +Do+:: specify the action to execute:
    #       - print: computes a mapping (server, cpu, core, gpu) for the given clusters, and shows OAR shell commands
    #         that would be run on an OAR server to converge to this mapping. This action try to reuse existing OAR
    #         resource's IDs, by fetching the current state of the OAR database via the OAR REST API (see the
    #         OAR_API_SERVER and OAR_API_PORT arguments).
    #       - table: show an ASCII table that illustrates the mapping (server, cpu, core, gpu) computed via action
    #         "print"
    #       - update: apply the commands of computed with the "print" task, to a given OAR server (see the OAR_SERVER
    #         and OAR_SERVER_USER arguments).
    #       - diff: Compare the mapping (server, cpu, core, gpu) computed with action "print", with the existing mapping
    #         fetched from the OAR REST API (see the OAR_API_SERVER, OAR_API_PORT).
    # +OAR_SERVER+:: IP address fo the OAR server that will serve as a target of the generator. The generator will
    #         connect via SSH to this server. By default, it targets the OAR server of the Grid'5000 site.
    # +OAR_SERVER_USER+:: SSH user that may be used to connect to the OAR server. By default, it targets the OAR server of the Grid'5000 site.
    # +OAR_API_SERVER+:: IP address fo the server that hosts the OAR API. The generator will use it to understand the
    #         existing (server, cpu, core, gpu) mapping.
    # +OAR_API_PORT+:: HTTP port used to connect to the REST API

    require 'refrepo/gen/oar-properties'
    options = {}

    if ENV['CLUSTER']
      options[:clusters] = ENV['CLUSTER'].split(',')
    end
    if ENV['SITE']
      options[:site] = ENV['SITE']
    else
      puts "You must specify a site."
      exit(1)
    end

    if not G5K_SITES.include?(options[:site])
      puts "Invalid site: #{options[:site]}"
      exit(1)
    end

    if ENV['OAR_SERVER']
      options[:ssh] ||= {}
      options[:ssh][:host] = ENV['OAR_SERVER']
    end
    if ENV['OAR_SERVER_USER']
      options[:ssh] ||= {}
      options[:ssh][:user] = ENV['OAR_SERVER_USER']
    end
    options[:print] = false
    options[:diff] = false
    options[:update] = false
    options[:table] = false
    if ENV['DO']
      ENV['DO'].split(',').each do |t|
        options[:table] = true if t == 'table'
        options[:print] = true if t == 'print'
        options[:update] = true if t == 'update'
        options[:diff] = true if t == 'diff'
      end
    else
      puts "You must specify something to do using DO="
      exit(1)
    end

    options[:verbose] = ENV['VERBOSE'].to_i if ENV['VERBOSE']

    ret = generate_oar_properties(options)
    exit(ret)
  end

  namespace :puppet do

    all_puppet_tasks = [:bindg5k, :conmang5k, :dhcpg5k, :kadeployg5k, :lanpowerg5k, :kavlang5k, :kwollectg5k, :network_monitoring, :'refapi-subset']

    all_puppet_tasks.each { |t|
      generated_desc = (t == :'refapi-subset') ? 'description' : 'configuration'
      desc "Generate #{t} #{generated_desc} -- parameters: [SITE={grenoble,...}] [OUTPUTDIR=(default: #{PUPPET_ODIR})] [CONFDIR=...] [VERBOSE=1]"
      task t do
        require "refrepo/gen/puppet/#{t}"
        options = {}
        options[:sites] = ( ENV['SITE'] ? ENV['SITE'].split(',') : G5K_SITES )
        options[:output_dir] = ENV['OUTPUTDIR'] || PUPPET_ODIR
        options[:verbose] = true if ENV['VERBOSE']
        options[:conf_dir] = ENV['CONFDIR'] if ENV['CONFDIR']
        send("generate_puppet_#{t}".gsub(/-/, '_'), options)

      end
    }

    desc "Launch all puppet generators"
    task :all => all_puppet_tasks

  end
end

namespace :version do
  desc 'Get bios, bmc and firmwares version -- parameters: MODEL={630,6420,...}'
  task :get do
    require 'refrepo/firmwares'

    model = ENV['MODEL']
    raise 'need MODEL=' if model.nil?

    model_filter = nodes_by_model(model)
    model_filter.sort_by{|node| node['uid'].to_s.split(/(\d+)/).map { |e| [e.to_i, e]}}.each do |node|
      version = Hash.new
      version['bios'] = node['bios']['version']
      version['bmc_version'] = node['bmc_version']
      version['network_adapters'] = get_firmware_version(node['network_adapters'])
      version['storage_devices'] = get_firmware_version(node['storage_devices'])
      puts "#{node['uid']} : #{version}"
    end
  end

  desc 'Build an HTML table with firmware versions'
  task :table do
    require 'refrepo/firmwares'
    gen_firmwares_tables
  end
end


desc "Creates JSON data from inputs"
task "reference-api" do
  require 'refrepo/gen/reference-api'
  generate_reference_api
end

desc "Output sorted VLAN offsets table (to update the input YAML after modification)"
task "sort-vlans-offsets" do
  sorted_vlan_offsets
end


#Hack rake: call only the first task and consider the rest as arguments to this task
currentTask = Rake.application.top_level_tasks.first
taskNames = Rake.application.tasks().map { |task| task.name() }
if (taskNames.include?(currentTask))
  Rake.application.instance_variable_set(:@top_level_tasks, [currentTask])
  ARGV.shift(ARGV.index(currentTask) + 1)
  $CMD_ARGS = ARGV.map{|arg| "'#{arg}'"}.join(' ')
else
  #Not running any task, maybe rake options, invalid, etc...
end
