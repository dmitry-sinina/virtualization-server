class VirtualMachine
  extend Forwardable

  attr_reader :id, :name, :cpus, :memory, :state, :hypervisor, :xml, :adapter

  ADAPTER_CLASS = LibvirtAdapter::Domain

  class_attribute :_hash, instance_writer: false, default: {}
  class_attribute :_cache, instance_writer: false, default: []

  class << self
    def build(domain, hv)
      vm = LibvirtAdapter::Domain.new(domain, hv)
      new(
          id: vm.id,
          name: vm.name,
          hypervisor: hv,
          state: vm.state,
          cpus: vm.cpus,
          memory: vm.memory,
          adapter: vm,
          xml: vm.xml
      )
    end

    def all
      Hypervisor.all.map(&:virtual_machines).flatten
    end

    def find_by(id:)
      all.detect { |domain| domain.id == id }
    end

    def create(attrs)
      vm = ADAPTER_CLASS.create(attrs)

      new(
          id: vm.id,
          name: vm.name,
          hypervisor: vm.hypervisor,
          state: vm.state,
          cpus: vm.cpus,
          memory: vm.memory,
          adapter: vm,
          xml: nil
      )
    end
  end

  def initialize(id:, name:, hypervisor:, state: nil, cpus:, memory:, adapter:, xml:)
    @id       = id
    @name     = name
    @hypervisor = hypervisor
    @state    = state
    @cpus     = cpus
    @memory   = memory
    @adapter  = adapter
    @xml = xml
  end

  def tags
    nil
  end

  # @param filename [String] path where screenshot will be uploaded.
  # @yield on complete or error (args: success [Boolean], filename [String]).
  # @return [Proc] function that will cancel screenshot taking.
  def take_screenshot(filename, &block)
    @adapter.take_screenshot(filename, &block)
  end
end
