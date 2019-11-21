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

p Libvirt::version()

cfg=YAML.load_file(File.join(__dir__, 'cluster.yml'))

Configuration.instance.configure(cfg)
#p Configuration.instance




