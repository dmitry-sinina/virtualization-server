require 'libvirt'

class Hypervisor
  include JSONAPI::Serializer

  attr_reader :id, :name, :uri, :connection, :version, :libversion, :hostname, :max_vcpus,
              :cpu_model, :cpus, :mhz, :numa_nodes, :cpu_sockets, :cpu_cores, :cpu_threads,
              :total_memory, :free_memory, :capabilities

  class_attribute :_storage, instance_accessor: false

  class Storage
    attr_reader :hypervisors_hash, :libvirt_rw

    def initialize(cfg)
      @hypervisors_hash = {}
      @libvirt_rw = false

      cfg['hypervisors'].each do |hv|
        #add to hash for fast lookup
        @hypervisors_hash[hv["id"]] = Hypervisor.new(hv["id"], hv["name"], hv["uri"])
      end
    end

    def hypervisors
      @hypervisors_hash.values
    end
  end

  class << self
    def load_storage(config)
      dbg 'load_storage'
      self._storage = Hypervisor::Storage.new(config)
    end

    def all
      dbg 'all'
      return [] if _storage.nil?
      _storage.hypervisors
    end

    def find_by(id:)
      dbg "#{id}"
      return if _storage.nil?
      _storage.hypervisors_hash[id]
    end
  end

  def initialize(id, name, uri)
    dbg "#{id} #{name} #{uri}"

    @id = id
    @name = name
    @uri = uri

    #force connect to initialize events callbacks
    connection

  end

  def register_connection_event_callbacks(c)
    dbg "#{c}"
    c.domain_event_register_any(
        Libvirt::Connect::DOMAIN_EVENT_ID_REBOOT,
        method(:dom_event_callback_reboot).to_proc
    )
  end

  def connection
    dbg "connection #{@connection}"
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

  def dom_event_callback_reboot(conn, dom, opaque)
    dbg "#{id} #{conn}, dom #{dom}, opaque #{opaque}"
  end

  def _open_connection(register_events = false)
    if self.class._storage&.libvirt_rw
      dbg "#{id} Opening RW connection to #{name}"
      c = Libvirt::open(uri)
    else
      dbg "#{id} Opening RO connection to #{name}"
      c = Libvirt::open_read_only(uri)
    end

    dbg "#{id} connected"

    #~ c.keepalive = [10, 2]

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

    register_connection_event_callbacks(c) if register_events

    c
  end

  def dbg(msg)
    meth_name = caller.first.match(/`(.+)'/)[1]
    AppLogger.debug("0x#{object_id.to_s(16)}") { "#{self.class}##{meth_name} #{msg}" }
  end

  def self.dbg(msg)
    meth_name = caller.first.match(/`(.+)'/)[1]
    AppLogger.debug("0x#{object_id.to_s(16)}") { "#{name}.#{meth_name} #{msg}" }
  end
end
