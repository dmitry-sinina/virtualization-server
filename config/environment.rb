APP_ROOT = Pathname.new(__FILE__) + '../../'
$LOAD_PATH.unshift(APP_ROOT)

require 'dotenv'
Dotenv.load

require 'bundler'
Bundler.require(:default, ENV.fetch('RACK_ENV'))

require 'libvirt'

paths = [
  Dir['app/*.rb'],
  Dir['app/**/*.rb'],
  Dir['config/initializers/**/*.rb'],
]

paths.map(&:sort).flatten.each { |path| require(path) }

require "config/environments/#{ENV.fetch('RACK_ENV')}.rb"

require 'singleton'
require 'yaml'


class Configuration
  include Singleton

  attr_reader :hypervisors, :hypervisors_hash, :libvirt_rw

  def initialize
    @hypervisors = []
    @hypervisors_hash = {}
    @libvirt_rw = false

    cfg=YAML.load_file(File.join(__dir__, 'cluster.yml'))
    cfg['hypervisors'].each do |hv|
      #add to array
      @hypervisors.push(Hypervisor.new(hv["id"], hv["name"], hv["uri"]))
      #add to hash for fast lookup
      @hypervisors_hash[hv["id"]] = Hypervisor.new(hv["id"], hv["name"], hv["uri"])
    end
  end

end

p Configuration.instance




