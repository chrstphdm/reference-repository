# coding: utf-8
require 'pp'
require_relative '../lib/input_loader'
require_relative './wiki_generator'
require_relative './mw_utils'
require_relative './site_hardware.rb'

class G5KHardwareGenerator < WikiGenerator

  def initialize(page_name)
    super(page_name)
  end

  def generate_content
    @global_hash = load_yaml_file_hierarchy(File.expand_path('../../input/grid5000/', File.dirname(__FILE__)))
    @site_uids = G5K::SITES
    
    @generated_content = "__NOEDITSECTION__\n"
    @generated_content += "\n= Clusters =\n"
    @generated_content += SiteHardwareGenerator.generate_all_clusters
    @generated_content += generate_totals
    @generated_content += MW.italic(MW.small("Generated from the Grid5000 APIs on " + Time.now.strftime("%Y-%m-%d")))
    @generated_content += MW::LINE_FEED
  end

  def generate_totals
    data = {
      'proc_families' => {},
      'proc_models' => {},
      'core_models' => {},
      'ram_size' => {},
      'net_interconnects' => {},
      'acc_families' => {},
      'acc_models' => {},
      'acc_cores' => {},
      'node_models' => {}
    }
    
    @global_hash['sites'].sort.each { |site_uid, site_hash|
      site_hash['clusters'].sort.each { |cluster_uid, cluster_hash|
        cluster_hash['nodes'].sort.each { |node_uid, node_hash|
          next if node_hash['status'] == 'retired'
          @node = node_uid
          
          # Processors
          model = node_hash['processor']['model']
          version = "#{model} #{node_hash['processor']['version']}"
          microarchitecture = node_hash['processor']['microarchitecture']

          cluster_procs = node_hash['architecture']['nb_procs']
          cluster_cores = node_hash['architecture']['nb_cores']

          key = [model]
          init(data, 'proc_families', key)
          data['proc_families'][key][site_uid] += cluster_procs

          key = [{text: microarchitecture || ' ', sort: get_date(microarchitecture) + ', ' + microarchitecture.to_s}, {text: version, sort: get_date(microarchitecture) + ', ' + version.to_s}]
          init(data, 'proc_models', key)
          data['proc_models'][key][site_uid] += cluster_procs

          init(data, 'core_models', key)
          data['core_models'][key][site_uid] += cluster_cores
          
          # RAM size
          ram_size = node_hash['main_memory']['ram_size']
          key = [{ text: G5K.get_size(ram_size), sort: (ram_size / 2**30).to_s.rjust(6, '0') + ' GB' }]
          init(data, 'ram_size', key)
          data['ram_size'][key][site_uid] += 1

          # HPC Networks
          interfaces = node_hash['network_adapters']
                       .select{ |k, v| v['enabled'] and (v['mounted'] or v['mountable']) and not v['management'] }
                       .map{ |k, v| [{text: v['interface'] + ' ' + G5K.get_rate(v['rate']), sort: ((v['rate'])/10**6).to_s.rjust(6, '0') + ' Gbps, ' + v['interface']}] }
                       .uniq

          net_interconnects = interfaces.inject(Hash.new(0)){ |h, v| h[v] += 1; h }
          net_interconnects.each { |k, v|
            init(data, 'net_interconnects', k)
            data['net_interconnects'][k][site_uid] += v
          }

          # Accelerators
          g = node_hash['gpu']
          m = node_hash['mic']        

          gpu_families = {}
          gpu_families[[g['gpu_vendor']]] = g['gpu_count'] if g and g['gpu']
          mic_families = {}
          mic_families[[m['mic_vendor']]] = m['mic_count'] if m and m['mic']
          gpu_families.merge(mic_families).each { |k, v|
            init(data, 'acc_families', k) 
            data['acc_families'][k][site_uid] += v
          }

          gpu_details = {}
          gpu_details[["#{g['gpu_vendor']} #{g['gpu_model']}"]] = [g['gpu_count'], g['gpu_cores']] if g and g['gpu']
          mic_details = {}
          mic_details[["#{m['mic_vendor']} #{m['mic_model']}"]] = [m['mic_count'], m['mic_cores']] if m and m['mic']
          
          gpu_details.merge(mic_details).each { |k, v|
            init(data, 'acc_models', k)
            data['acc_models'][k][site_uid] += v[0]

            init(data, 'acc_cores', k)
            data['acc_cores'][k][site_uid] += v[1]
          }

          # Nodes
          key = [cluster_hash['model']]
          init(data, 'node_models', key)
          data['node_models'][key][site_uid] += 1
        }
      }
    }

    # Table construction
    generated_content = "= Processors ="
    generated_content += "\n== Processors counts per families ==\n"
    sites = @site_uids.map{ |e| "[[#{e.capitalize}:Hardware|#{e.capitalize}]]" }
    table_options = 'class="wikitable sortable" style="text-align: center;"'
    table_columns = ['Processor family'] + sites + ['Processors total']
    generated_content += MW.generate_table(table_options, table_columns, get_table_data(data, 'proc_families'))
    generated_content += "\n== Processors counts per models ==\n"
    table_columns = ['Microarchitecture', 'Processor model'] + sites + ['Processors total']
    generated_content += MW.generate_table(table_options, table_columns, get_table_data(data, 'proc_models'))
    generated_content += "\n== Cores counts per models ==\n"
    table_columns =  ['Microarchitecture', 'Core model'] + sites + ['Cores total']
    generated_content += MW.generate_table(table_options, table_columns, get_table_data(data, 'core_models'))

    generated_content += "\n= RAM size per node =\n"
    table_columns = ['RAM size'] + sites + ['Nodes total']
    generated_content += MW.generate_table(table_options, table_columns, get_table_data(data, 'ram_size'))

    generated_content += "\n= Network interconnects =\n"
    table_columns = ['Interconnect'] + sites + ['Cards total']
    generated_content += MW.generate_table(table_options, table_columns, get_table_data(data, 'net_interconnects'))

    generated_content += "\n= Nodes with several Ethernet interfaces =\n"
    generated_content +=  generate_interfaces
    
    generated_content += "\n= Accelerators (GPU, Xeon Phi) ="
    generated_content += "\n== Accelerator families ==\n"
    table_columns = ['Accelerator family'] + sites + ['Accelerators total']
    generated_content += MW.generate_table(table_options, table_columns, get_table_data(data, 'acc_families'))
    table_columns = ['Accelerator model'] + sites + ['Accelerators total']
    generated_content += "\n== Accelerator models ==\n"
    generated_content += MW.generate_table(table_options, table_columns, get_table_data(data, 'acc_models'))
    generated_content += "\n== Accelerator cores ==\n"
    table_columns = ['Accelerator model'] + sites + ['Cores total']
    generated_content += MW.generate_table(table_options, table_columns, get_table_data(data, 'acc_cores'))
    
    generated_content += "\n= Nodes models =\n"
    table_columns = ['Nodes model'] + sites + ['Nodes total']
    generated_content += MW.generate_table(table_options, table_columns, get_table_data(data, 'node_models'))
  end

  def init(data, key1, key2)
    if not data[key1].key?(key2)
      data[key1][key2] = {}
      @site_uids.each { |s| data[key1][key2][s] = 0 }
    end
  end

  # This method generates a wiki table from data[key] values, sorted by key
  # values in first column.
  def get_table_data(data, key)
    raw_data = []
    table_data = []
    index = 0
    k0 = 0
    data[key].sort_by{
      # Sort the table by first column (= first elt of k)
      |k, v| k[0].kind_of?(Hash) ? k[0][:sort] : k[0]
    }.to_h.each { |k, v|
      k0 = k if index == 0
      index += 1
      elts = v.sort.to_h.values
      raw_data << elts
      table_data << k.map{ |e| e.kind_of?(Hash) ? "data-sort-value=\"#{e[:sort]}\"|#{e[:text]}" : "data-sort-value=\"#{index.to_s.rjust(3, '0')}\"|#{e}" } +
        elts.map{ |e| e.kind_of?(Hash) ? "data-sort-value=\"#{e[:sort]}\"|#{e[:text]}" : e }
        .map{ |e| e == 0 ? '' : e  } + ["'''#{elts.reduce(:+)}'''"]
    }
    elts = raw_data.transpose.map{ |e| e.reduce(:+)}
    table_data << {columns: ["'''Sites total'''"] +
                   [' '] * (k0.length - 1) +
                   (elts + [elts.reduce(:+)]).map{ |e| e == 0 ? '' : "'''#{e}'''" },
                   sort: false}
  end

  # See: https://en.wikipedia.org/wiki/List_of_Intel_Xeon_microprocessors
  # For a correct sort of the column, all dates must be in the same
  # format (same number of digits)
  def get_date(microarchitecture)
    release_dates = {
      'K8' => '2003',
      'K10' => '2007',
      'Clovertown' => '2006',
      'Harpertown' => '2007',
      'Dunnington' => '2008',
      'Lynnfield' => '2009',
      'Nehalem' => '2010',
      'Westmere' => '2011',
      'Sandy Bridge' => '2012',
      'Haswell' => '2013',
      'Broadwell' => '2015',
    }
    date = release_dates[microarchitecture.to_s]
    raise 'ERROR: microarchitecture not found' if date.nil?
    date
  end
  
  def generate_interfaces
    table_data = []
    @global_hash["sites"].each { |site_uid, site_hash|
      site_hash.fetch("clusters").each { |cluster_uid, cluster_hash|
        network_interfaces = {}
        cluster_hash.fetch('nodes').sort.each { |node_uid, node_hash|
          next if node_hash['status'] == 'retired'
          if node_hash['network_adapters']
            node_interfaces = node_hash['network_adapters'].select{ |k, v| v['interface'] == 'Ethernet' and v['enabled'] == true and (v['mounted'] == true or v['mountable'] == true) and v['management'] == false }

            interfaces = {}
            interfaces['10g_count'] = node_interfaces.select { |k, v| v['rate'] == 10_000_000_000 }.count
            interfaces['1g_count'] = node_interfaces.select { |k, v| v['rate'] == 1_000_000_000 }.count
            interfaces['details'] = node_interfaces.map{ |k, v| k + (v['name'].nil? ? '' : '/' + v['name'])  + ' (' + G5K.get_rate(v['rate']) + ')' }.sort.join(', ')
            queues = cluster_hash['queues'] - ['admin', 'default']
            interfaces['queues'] = (queues.nil? || (queues.empty? ? '' : queues[0] + G5K.pluralize(queues.count, ' queue')))
            add(network_interfaces, node_uid, interfaces) if node_interfaces.count > 1
          end
        }

        # One line for each group of nodes with the same interfaces
        network_interfaces.sort.to_h.each { |num, interfaces|
          table_data << [
            "[[#{site_uid.capitalize}:Network|#{site_uid.capitalize}]]",
            "[[#{site_uid.capitalize}:Hardware##{cluster_uid}" + (interfaces['queues'] == '' ? '' : "_.28#{queues.gsub(' ', '_')}.29") + "|#{cluster_uid}" + (network_interfaces.size==1 ? '' : '-' + G5K.nodeset(num)) + "]]",
            num.count,
            interfaces['10g_count'].zero? ? '' : interfaces['10g_count'],
            interfaces['1g_count'].zero? ? '' : interfaces['1g_count'],
            interfaces['details']
          ]
        }
      }
    }
    # Sort by site and cluster name
    table_data.sort_by! { |row|
      [row[0], row[1]]
    }

    table_options = 'class="wikitable sortable" style="text-align: center;"'
    table_columns = ["Site", "Cluster", "Nodes", "10G interfaces", "1G interfaces", "Interfaces (throughput)"]
    MW.generate_table(table_options, table_columns, table_data)    
  end

  # This methods adds the array interfaces to the hash
  # network_interfaces. If nodes 2,3,7 have the same interfaces, they
  # will be gathered in the same key and we will have
  # network_interfaces[[2,3,7]] = interfaces
  def add(network_interfaces, node_uid, interfaces)
    num1 = node_uid.split('-')[1].to_i
    if network_interfaces.has_value?(interfaces) == false
      network_interfaces[[num1]] = interfaces
    else
      num2 = network_interfaces.key(interfaces)
      network_interfaces.delete(num2)
      network_interfaces[num2.push(num1)] = interfaces
    end
  end  
end

generator = G5KHardwareGenerator.new("Hardware")

options = WikiGenerator::parse_options
if (options)
  ret = 2
  begin
    ret = WikiGenerator::exec(generator, options)
  rescue MediawikiApi::ApiError => e
    puts e, e.backtrace
    ret = 3
  rescue StandardError => e
    puts "Error with node: #{generator.instance_variable_get(:@node)}"
    puts e, e.backtrace
    ret = 4
  ensure
    exit(ret)
  end
end