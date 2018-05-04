# coding: utf-8
require 'optparse'
require 'date'

require_relative '../lib/input_loader'
require_relative './wiki_generator'
require_relative './mw_utils'
require_relative '../input-validators/check-network-description'

# This class generates the network description of each site, in .dot
# and .png format
class SiteNetworkGenerator < WikiGenerator

  def initialize(page_name, site)
    super(page_name)
    @site = site
    name = "#{@site.capitalize}Network"
    @files = [
      {	'content-type' => 'text/plain',
        'filename' => "#{name}.dot",
        'path' => "./#{name}.dot",
        'comment' => "#{site.capitalize} network description" },
      { 'content-type' => 'image/png',
        'filename' => "#{name}.png",
        'path' => "./#{name}.png",
        'comment' => "#{site.capitalize} network description" }
    ]
  end

  def generate_content
    check_network_description({:sites => [@site], :dot => true})
  end
end

options = WikiGenerator::parse_options

if (options)
  ret = 2
  begin
    ret = true
    generators = options[:sites].map{ |site| SiteNetworkGenerator.new('Generated/' + site.capitalize + 'Network', site) }
    generators.each{ |generator|
      ret &= WikiGenerator::exec(generator, options)
    }
  rescue MediawikiApi::ApiError => e
    puts e, e.backtrace
    ret = 3
  rescue StandardError => e
    puts e, e.backtrace
    ret = 4
  ensure
    exit(ret)
  end
end
