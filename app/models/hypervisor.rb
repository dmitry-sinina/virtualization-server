class Hypervisor
  include JSONAPI::Serializer

  attr_reader :id, :name, :uri, :connection, :version, :libversion, :hostname, :max_vcpus,
              :cpu_model, :cpus, :mhz, :numa_nodes, :cpu_sockets, :cpu_cores, :cpu_threads,
              :total_memory, :free_memory, :capabilities

  attr_reader :virtual_machines

  class_attribute :_storage, instance_accessor: false

  class << self
    def load_storage(clusters)
      dbg { "#{name}.load_storage #{clusters}" }
      self._storage = clusters.map do |cluster|
        Hypervisor.new(id: cluster['id'], name: cluster['name'], uri: cluster['uri'])
      end
      dbg { "#{name}.load_storage loaded size=#{_storage.size}" }
    end

    def all
      dbg { "#{name}.all" }
      result = _storage
      dbg { "#{name}.all found size=#{result.size}" }
      result
    end

    def find_by(id:)
      dbg { "#{name}.find_by id=#{id}" }
      result = _storage.detect { |hv| hv.id == id }
      dbg { "#{name}.find_by found id=#{result&.id}, name=#{result&.name}, uri=#{result&.uri}" }
      result
    end
  end

  def initialize(id:, name:, uri:)
    dbg { "#{self.class}#initialize id=#{id}, name=#{name}, uri=#{uri}" }

    @id = id
    @name = name
    @uri = uri

    #force connect to initialize events callbacks
    connection
    load_virtual_machines
  end

  def connection
    dbg { "#{self.class}#connection #{@connection.nil? ? 'absent' : 'present'}, id=#{id}, name=#{name}, uri=#{uri}" }
    @connection ||= _open_connection(true)
  end

  def to_json(_opts = nil)
    as_json.to_json
  end

  def as_json
    {
        id: @id,
        name: @name
    }
  end

  private

  def load_virtual_machines
    dbg { "#{self.class}#load_virtual_machines id=#{id}, name=#{name}, uri=#{uri}" }
    @virtual_machines = connection.list_all_domains.map { |vm| VirtualMachine.build(vm, self) }
    dbg { "#{self.class}#load_virtual_machines loaded size=#{virtual_machines.size} id=#{id}, name=#{name}, uri=#{uri}" }
  end

  def _open_connection(register_events = false)
    if VirtualizationServer.config.libvirt_rw
      dbg { "#{self.class}#_open_connection Opening RW connection to name=#{name} id=#{id}, uri=#{uri}" }
      c = Libvirt::open(uri)
    else
      dbg { "#{self.class}#_open_connection Opening RO connection to name=#{name} id=#{id}, uri=#{uri}" }
      c = Libvirt::open_read_only(uri)
    end

    dbg { "#{self.class}#_open_connection Connected name=#{name} id=#{id}, uri=#{uri}" }

    # c.keepalive = [10, 2]

    @version = c.version
    @libversion = c.libversion
    @hostname = c.hostname
    @max_vcpus = c.max_vcpus
    @capabilities = c.capabilities

    node_info = c.node_info
    @cpu_model = node_info.model
    @cpus = node_info.cpus
    @mhz = node_info.mhz
    @numa_nodes = node_info.nodes
    @cpu_sockets = node_info.sockets
    @cpu_cores = node_info.cores
    @cpu_threads = node_info.threads
    @total_memory = node_info.memory
    @free_memory = node_info.memory

    register_dom_event_callbacks(c)

    c
  end

  def register_dom_event_callbacks(c)
    c.domain_event_register_any(
        Libvirt::Connect::DOMAIN_EVENT_ID_REBOOT,
        method(:dom_event_callback_reboot).to_proc
    )

    c.domain_event_register_any(
        Libvirt::Connect::DOMAIN_EVENT_ID_LIFECYCLE,
        method(:dom_event_callback_lifecycle).to_proc
    )
  end

  def dom_event_callback_reboot(_conn, dom, _opaque)
    dbg { "#{self.class}#dom_event_callback_reboot id=#{id} dom.uuid=#{dom.uuid}" }
    DomainEventCable.broadcast(type: 'domain_reboot', id: dom.uuid)
  end

  def dom_event_callback_lifecycle(_conn, dom, event, detail, _opaque)
    dbg { "#{self.class}#dom_event_callback_reboot id=#{id} dom.uuid=#{dom.uuid}" }
    DomainEventCable.broadcast(type: 'domain_lifecycle', id: dom.uuid, event: event, detail: detail)
  end

  include LibvirtAsync::WithDbg
end
