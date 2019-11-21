class Configuration
  include Singleton

  attr_reader :hypervisors, :hypervisors_hash, :libvirt_rw

  def configure(cfg)
    @hypervisors = []
    @hypervisors_hash = {}
    @libvirt_rw = false

#    cfg=YAML.load_file(File.join(__dir__, 'cluster.yml'))
    cfg['hypervisors'].each do |hv|
      #add to array
      h=Hypervisor.new(hv["id"], hv["name"], hv["uri"])

      @hypervisors.push(h)
      #add to hash for fast lookup
      @hypervisors_hash[hv["id"]] = h
      h.run_io_thread
    end
  end

end