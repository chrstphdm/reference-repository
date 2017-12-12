#!/usr/bin/ruby -w

require 'yaml'
require 'pp'

Dir['input/grid5000/sites/*/clusters/*/nodes/*.yaml'].each do |f|
  d = YAML::load(IO::read(f))

  # remove bios.configuration
  #d.values.first['bios'].delete('configuration')

  # remove rate when it's 0
  d.values.first['network_adapters'].each_pair do |name, na|
    next if not na['rate']
    next if na['rate'] != 0
    na.delete('rate')
  end

  # remove information about OS, which is obsolete anyway
  d.values.first['operating_system'].delete('kernel')
  d.values.first['operating_system'].delete('name')
  d.values.first['operating_system'].delete('version')
  d.values.first['operating_system'].delete('release')

  fd = File::new(f, 'w')
  fd.puts("# Generated by g5k-checks (g5k-checks -m api)")
  fd.puts d.to_yaml
  fd.close
end



