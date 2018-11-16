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

if Dir::exists?(ENV['HOME'] + '/.gpuppet/repo')
  PUPPET_ODIR = ENV['HOME'] + '/.gpuppet/repo'
else
  PUPPET_ODIR = '/tmp/puppet'
end

G5K_SITES = RefRepo::Utils::get_sites

namespace :valid do

  desc "Check homogeneity of clusters -- parameters: SITE={grenoble,..} CLUSTER={yeti,..} VERBOSE=1"
  task "homogeneity" do
    require 'refrepo/valid/homogeneity'
    options = {}
    options[:sites] = ( ENV['SITE'] ? ENV['SITE'].split(',') : G5K_SITES )
    options[:clusters] = ( ENV['CLUSTER'] ? ENV['CLUSTER'].split(',') : [] )
    options[:verbose] = ENV['VERBOSE'].to_i if ENV['VERBOSE']

    ret = check_cluster_homogeneity(options)
    exit(ret)
  end

  desc "Check for duplicates fields in input -- parameters: SITE={grenoble..} CLUSTER={yeti,...} VERBOSE=1"
  task "duplicates" do
    require 'refrepo/valid/input/duplicates'
    options = {}
    options[:sites] = ( ENV['SITE'] ? ENV['SITE'].split(',') : G5K_SITES )
    options[:clusters] = ( ENV['CLUSTER'] ? ENV['CLUSTER'].split(',') : [] )
    options[:verbose] = ENV['VERBOSE'].to_i if ENV['VERBOSE']
    ret = yaml_input_find_duplicates(options)
    exit(ret)
  end

  desc "Check input data schema validity -- parameters: SITE={grenoble,..} CLUSTER={yeti,..}"
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

  desc "Check network description -- parameters: [SITE={grenoble,...}] [VERBOSE=1] GENERATE_DOT=1"
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

  desc "Generate OAR properties -- parameters: SITE={grenoble,...} CLUSTER={yeti,...} NODE={dahu-1,...} DO={print,exec,diff,check} VERBOSE={0,1,2,3}"
  task "oar-properties" do
    require 'refrepo/gen/oar-properties'
    options = {}
    options[:sites] = ( ENV['SITE'] ? ENV['SITE'].split(',') : G5K_SITES )
    if ENV['CLUSTER']
      options[:clusters] = ENV['CLUSTER'].split(',')
    end
    if ENV['NODE']
      options[:nodes] = ENV['NODE'].split(',')
    end
    options[:output] = false
    options[:diff] = false
    options[:exec] = false
    options[:check] = false
    if ENV['DO']
      ENV['DO'].split(',').each do |t|
        options[:diff] = true if t == 'diff'
        options[:output] = true if t == 'output'
        options[:exec] = true if t == 'update'
        if t == 'check'
          options[:diff] = true # check requires diff
          options[:check] = true
        end
      end
    else
      puts "You must specify something to do using DO="
      exit(1)
    end

    if ENV['VERBOSE']
      options[:verbose] = ENV['VERBOSE'].to_i
    else
      options[:verbose] = 0
    end

    ret = generate_oar_properties(options)
    exit(ret)
  end

namespace :puppet do

  all_puppet_tasks = [:bindg5k, :conmang5k, :dhcpg5k, :kadeployg5k, :lanpowerg5k, :kavlang5k]

  all_puppet_tasks.each { |t|
    desc "Generate #{t} configuration -- parameters: SITE={grenoble,...} OUTPUTDIR=[default: #{PUPPET_ODIR}] [CONFDIR=...] VERBOSE=1"
    task t do
      require "refrepo/gen/puppet/#{t}"
      options = {}
      options[:sites] = ( ENV['SITE'] ? ENV['SITE'].split(',') : G5K_SITES )
      options[:output_dir] = ENV['OUTPUTDIR'] || PUPPET_ODIR
      options[:verbose] = (ENV['VERBOSE'] != nil)
      options[:conf_dir] = ENV['CONFDIR'] if ENV['CONFDIR']
      send("generate_puppet_#{t}", options)

    end
  }

  desc "Launch all puppet generators"
  task :all => all_puppet_tasks

end


end

desc "Creates JSON data from inputs"
task "reference-api" do
  require 'refrepo/gen/reference-api'
  generate_reference_api
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
