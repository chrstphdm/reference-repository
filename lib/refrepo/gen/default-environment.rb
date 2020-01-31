# coding: utf-8

require 'refrepo/data_loader'
require 'net/scp'
require 'diffy'

G5K_CONF_DIR = '/etc/grid5000/'
REMOTE_FILE = G5K_CONF_DIR + 'default-env.json'

module RefRepo::Gen::DefaultEnv
  def self.gen(options)
    ret = true
    data_hierarchy = load_data_hierarchy

    options[:sites].each do |site|
      site_gen = DefaultEnvGen.new(data_hierarchy['sites'][site], site)
      if options[:update]
        site_gen.deploy_json
      elsif options[:print]
        puts "------------ Generated JSON for #{site} ------------"
        puts site_gen.gen_json
      elsif options[:diff]
        ret = site_gen.diff_json
      end
    end

    return ret
  end

  class DefaultEnvGen
    def initialize(data_site_hierarchy, site)
      @data_site_hierarchy = data_site_hierarchy
      @site = site
    end

    def diff_json
      # We do the diff only with one remote (the frontal) since we assume that
      # both OAR and frontal VM have the same data

      generated_json = gen_json
      remote_json = get_remote_json
      diff = Diffy::Diff.new(remote_json, generated_json, :context => 3)

      if diff.to_s.empty?
        puts "No differences found between generated JSON and remote JSON for site #{@site}"
        return true
      end

      puts "Differences between generated and current json content for site #{@site}:"
      puts '------------ PAGE DIFF BEGIN ------------'
      puts "#{diff.to_s(:text)}"
      puts '------------- PAGE DIFF END -------------'
      return false
    end

    def gen_json
      site_topo = Hash.new
      clusters = @data_site_hierarchy['clusters'].to_h

      clusters.each do |c, nodes|
        site_topo[c] = Hash.new
        site_topo[c]['nodes'] = Hash.new

        clusters[c]['nodes'].to_h.each do |node_name, node|
          site_topo[c]['nodes'][node_name] = Hash.new
          site_topo[c]['nodes'][node_name]['software'] = node['software']
        end
      end

      JSON.pretty_generate(site_topo)
    end

    def deploy_json
      generated_content = gen_json
      if generated_content == get_remote_json
        puts "No modification for site #{@site}, skipping"
      else
        Net::SCP.upload!("#{@site}.g5ka", "g5kadmin", StringIO.new(generated_content), REMOTE_FILE)
        Net::SCP.upload!("oar.#{@site}.g5ka", "g5kadmin", StringIO.new(generated_content), REMOTE_FILE)
      end
    end

    def get_remote_json
      begin
        Net::SCP.download!("#{@site}.g5ka", "g5kadmin", REMOTE_FILE)
      rescue Net::SCP::Error => e
        if e.message.match(/#{REMOTE_FILE}: no such file or directory/)
          return ''
        else
          raise
        end
      end
    end
  end
end
