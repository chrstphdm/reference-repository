# Load a hierarchy of YAML file into a Ruby hash

require 'refrepo/hash/hash'

def load_yaml_file_hierarchy(directory = File.expand_path("../../input/grid5000/", File.dirname(__FILE__)))

  global_hash = {} # the global data structure
  
  Dir.chdir(directory) {
  
    # Recursively list the .yaml files.
    # The order in which the results are returned depends on the system (http://ruby-doc.org/core-2.2.3/Dir.html).
    # => List deepest files first as they have lowest priority when hash keys are duplicated.
    list_of_yaml_files = Dir['**/*.y*ml', '**/*.y*ml.erb'].sort_by { |x| -x.count('/') }
    
    list_of_yaml_files.each { |filename|
      begin
        # Load YAML
        if /\.y.*ml\.erb$/.match(filename)
          # For files with .erb.yaml extensions, process the template before loading the YAML.
          file_hash = YAML::load(ERB.new(File.read(filename)).result(binding))
        else
          file_hash = YAML::load_file(filename)
        end
      if not file_hash
        raise Exception.new("loaded hash is empty")
      end
      # YAML::Psych raises an exception if the file cannot be loaded.
      rescue StandardError => e
        puts "Error loading '#{filename}', #{e.message}"
      end

      # Inject the file content into the global_hash, at the right place
      path_hierarchy = File.dirname(filename).split('/')     # Split the file path (path relative to input/)
      path_hierarchy = [] if path_hierarchy == ['.']

      file_hash = Hash.from_array(path_hierarchy, file_hash) # Build the nested hash hierarchy according to the file path
      global_hash = global_hash.deep_merge(file_hash)        # Merge global_hash and file_hash. The value for entries with duplicate keys will be that of file_hash

      # Expand the hash. Done at each iteration for enforcing priorities between duplicate entries:
      # ie. keys to be expanded have lowest priority on existing entries but higher priority on the entries found in the next files
      global_hash.expand_square_brackets(file_hash)

    }

  }

#  pp global_hash

  # populate each node with its kavlan IPs
  add_kavlan_ips(global_hash)

  return global_hash

end

# FIXME missing clusters / interfaces:
# NO VLAN OFFSET: ["local", "nancy", "grimoire", "eth1"] / grimoire-8-eth1-kavlan-1.nancy.grid5000.fr
# NO VLAN OFFSET: ["routed", "nancy", "grimoire", "eth1"] / grimoire-8-eth1-kavlan-4.nancy.grid5000.fr
# NO VLAN OFFSET: ["global", "nancy", "grimoire", "eth1"] / grimoire-8-eth1-kavlan-11.nancy.grid5000.fr
# NO VLAN OFFSET: ["local", "nancy", "grimoire", "eth2"] / grimoire-8-eth2-kavlan-1.nancy.grid5000.fr
# NO VLAN OFFSET: ["routed", "nancy", "grimoire", "eth2"] / grimoire-8-eth2-kavlan-4.nancy.grid5000.fr
# NO VLAN OFFSET: ["global", "nancy", "grimoire", "eth2"] / grimoire-8-eth2-kavlan-11.nancy.grid5000.fr
# NO VLAN OFFSET: ["local", "nancy", "grimoire", "eth3"] / grimoire-8-eth3-kavlan-1.nancy.grid5000.fr
# NO VLAN OFFSET: ["routed", "nancy", "grimoire", "eth3"] / grimoire-8-eth3-kavlan-4.nancy.grid5000.fr
# NO VLAN OFFSET: ["global", "nancy", "grimoire", "eth3"] / grimoire-8-eth3-kavlan-11.nancy.grid5000.fr
# NO VLAN OFFSET: ["global", "nancy", "grisou", "eth1"] / grisou-43-eth1-kavlan-11.nancy.grid5000.fr
# NO VLAN OFFSET: ["global", "nancy", "grisou", "eth2"] / grisou-43-eth2-kavlan-11.nancy.grid5000.fr
# NO VLAN OFFSET: ["global", "nancy", "grisou", "eth3"] / grisou-43-eth3-kavlan-11.nancy.grid5000.fr
# NO VLAN OFFSET: ["global", "nancy", "grisou", "eth4"] / grisou-43-eth4-kavlan-11.nancy.grid5000.fr

def sorted_vlan_offsets
  offsets = load_yaml_file_hierarchy['vlans']['offsets'].split("\n").
    map { |l| l = l.split(/\s+/) ; (4..7).each { |e| l[e] = l[e].to_i } ; l }
  # for local VLANs, we include the site when we sort
  puts offsets.select { |l| l[0] == 'local' }.
   sort_by { |l| [l[0], l[1] ] + l[4..-1] }.
   map { |l| l.join(' ') }.
   join("\n")
  puts offsets.select { |l| l[0] != 'local' }.
   sort_by { |l| [l[0] ] + l[4..-1] }.
   map { |l| l.join(' ') }.
   join("\n")

end

# this was useful when doing the initial import
GET_FROM_DNS = false

$tried_resolv = {}
$allocated = {}
def add_kavlan_ips(h)
  vlan_base = h['vlans']['base']
  vlan_offset = h['vlans']['offsets'].split("\n").map { |l| l = l.split(/\s+/) ; [ l[0..3], l[4..-1].inject(0) { |a, b| (a << 8) + b.to_i } ] }.to_h
  h['sites'].each_pair do |site_uid, hs|
    p site_uid
    hs['clusters'].each_pair do |cluster_uid, hc|
      hc['nodes'].each_pair do |node_uid, hn|
        # raise "Old kavlan data in input/ for #{node_uid}" if hn.has_key?('kavlan') # FIXME uncomment after input/ is cleaned up
        node_id = node_uid.split('-')[1].to_i
        hn['kavlan'] = {}
        hn['network_adapters'].to_a.select { |i| i[1]['mountable'] and (i[1]['kavlan'] or not i[1].has_key?('kavlan')) and i[1]['interface'] == 'Ethernet' }.map { |e| e[0] }.each do |iface|
          hn['kavlan'][iface] = {}
          vlan_base.each do |vlan, v|
            type = v['type']
            base = IPAddress::IPv4::new(v['address']).to_u32
            k = [type, site_uid, cluster_uid, iface]
            if not vlan_offset.has_key?(k)
              puts "Missing VLAN offset for #{k}"
              if GET_FROM_DNS
                puts "Trying to get from DNS..."
                next if $tried_resolv[k]
                $tried_resolv[k] = true
                host = "#{node_uid}-#{iface}-kavlan-#{vlan}.#{site_uid}.grid5000.fr"
                begin
                  ip = IPSocket.getaddress(host)
                  puts "#{host} => #{ip} / base= #{IPAddress::IPv4::parse_u32(base)}"
                  offset = IPAddress::IPv4::new(ip).to_u32 - base - node_id
                  puts "NEW VLAN OFFSET: #{type} #{site_uid} #{cluster_uid} #{iface} #{IPAddress::IPv4::parse_u32(offset).octets.join(' ')}"
                rescue SocketError
                  puts "NO VLAN OFFSET: #{k} / #{host}"
                end
              end
              next
            end
            ip = IPAddress::IPv4::parse_u32(base + vlan_offset[k] + node_id)
            raise "IP already allocated: #{ip} (trying to add it to #{node_uid}-#{iface})" if $allocated[ip]
            $allocated[ip] = true
            hn['kavlan'][iface]["kavlan-#{vlan}"] = ip
          end
        end
      end
    end
  end
end
