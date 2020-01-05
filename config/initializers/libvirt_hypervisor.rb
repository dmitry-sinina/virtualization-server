require 'libvirt'
require 'libvirt_async'

libvirt_version, type_version = Libvirt::version()
puts "Libvirt version=#{libvirt_version} type=#{type_version}"

if ENV['LIBVIRT_DEBUG'].present?
  LibvirtAsync.use_logger!
  LibvirtAsync.logger.level = :debug
end

LibvirtAsync.register_implementations!

Hypervisor.load_storage VirtualizationServer.config.clusters

Hypervisor.all.each do |hv|
  puts "> Hypervisor #{hv.id} #{hv.name} #{hv.uri}"
  hv.virtual_machines.each do |vm|
    puts ">> VM #{vm.id} #{vm.name}"
  end
end
