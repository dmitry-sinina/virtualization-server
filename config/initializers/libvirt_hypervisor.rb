require 'yaml'
require 'lib/app_logger'
require 'lib/hypervisor'
require 'lib/virt/runner'

AppLogger.setup_logger(STDOUT, level: Logger::Severity::DEBUG)
AppLogger.info { Libvirt::version() }

# VIRT_RUNNER = Virt::Runner.new.run
# clusters = YAML.load_file(File.join(__dir__, '..', 'cluster.yml'))
# Hypervisor.load_storage(clusters)
#
# Hypervisor.all.each do |hv|
#   puts "Hypervisor #{hv.id} #{hv.name} #{hv.uri}"
# end
