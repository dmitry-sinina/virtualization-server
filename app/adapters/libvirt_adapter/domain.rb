require 'pp'
module LibvirtAdapter
  class Domain
    # https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainState
    STATES = {
      0 => "no state",
      1 => "running",
      2 => "blocked on resource",
      3 => "paused by user",
      4 => "being shut down",
      5 => "shut off",
      6 => "crashed",
      7 => "suspended by guest power management",
    }

    def self.all
      domains=[]
      ::Hypervisor.all.each do |hv|
        hv.connection.list_all_domains.map do |domain|
          p domain.methods.inspect
          domains.push new(domain,hv)
        end
      end

      return domains
    end

    def self.find_by(id:)
      domains=[]
      ::Hypervisor.all.each do |hv|
        vm = hv.connection.lookup_domain_by_uuid(id)
        unless vm.nil?
          return new(vm,hv)
        end
      end
    end

    # def self.create(attrs)
    #   factory = DomainFactory.new(memory: attrs[:memory], cpus: attrs[:cpus])
    #   domain  = CLIENT.define_domain_xml(factory.to_xml)
    #   new(domain)
    # end

    def initialize(domain,hypervisor)
      @domain = domain
      @hypervisor = hypervisor
    end

    # def start
    #   domain.create
    # rescue Libvirt::Error => exception
    #   case exception.libvirt_message
    #   when 'Requested operation is not valid: domain is already running'
    #     return domain
    #   end
    # end
    #
    # def shutdown
    #   domain.shutdown if running?
    # end
    #
    # def halt
    #   domain.destroy if running?
    # end
    #
    # def update
    #   raise NotImplementedError
    # end
    #
    # def destroy
    #   shutdown if running?
    #   domain.undefine
    # end

    def id
      domain.uuid
    end

    def name
      domain.name
    end

    def hostname
      domain.hostname
    end

    def hypervisor
      @hypervisor
    end

    def xml
      domain.xml_desc
    end

    def state
      STATES[domain.state.first]
    end

    def running?
      state == STATES[1]
    end

    def cpus
      if running?
        domain.max_vcpus
      else
        domain.vcpus.count
      end
    end

    def memory
      domain.max_memory
    end

    private

    attr_reader :domain
  end
end
