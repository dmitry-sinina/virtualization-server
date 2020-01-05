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

    include LibvirtAsync::WithDbg

    def self.all
      dbg { "#{name}.all" }
      domains=[]

      ::Hypervisor.all.each do |hypervisor|
        dbg { "#{name}.all hypervisor.id=#{hypervisor.id}" }
        hypervisor_domains = hypervisor.connection.list_all_domains
        dbg { "#{name}.all hypervisor.id=#{hypervisor.id} hypervisor_domains.size=#{hypervisor_domains.size}" }
        domains.concat hypervisor_domains.map { |domain| new(domain, hypervisor) }
      end

      dbg { "#{name}.all return domains.size=#{domains.size}" }
      domains
    end

    def self.find_by(id:)
      dbg { "#{name}.find_by id=#{id}" }

      ::Hypervisor.all.each do |hypervisor|
        dbg { "#{name}.find_by hypervisor.id=#{hypervisor.id}" }
        domain = hypervisor.connection.lookup_domain_by_uuid(id)
        if domain.nil?
          dbg { "#{name}.find_by not found hypervisor.id=#{hypervisor.id}" }
        else
          dbg { "#{name}.find_by found hypervisor.id=#{hypervisor.id} domain.name=#{domain.name}" }
          return new(domain, hypervisor)
        end
      end

      dbg { "#{name}.find_by not found id=#{id}" }
      nil
    end

    # def self.create(attrs)
    #   factory = DomainFactory.new(memory: attrs[:memory], cpus: attrs[:cpus])
    #   domain  = CLIENT.define_domain_xml(factory.to_xml)
    #   new(domain)
    # end

    attr_reader :domain

    def initialize(domain, hypervisor)
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
      dbg { "#{self.class}#state retrieving id=#{id}" }
      libvirt_state, _ = domain.state
      dbg { "#{self.class}#state retrieved id=#{id} libvirt_state=#{libvirt_state}" }
      STATES[libvirt_state]
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

    # @param filename [String] path where screenshot will be uploaded.
    # @yield on complete or error (args: success [Boolean], filename [String]).
    # @return [Proc] function that will cancel screenshot taking.
    def take_screenshot(filename, &block)
      tmp_filename = "#{filename}.tmp"

      dbg { "#{self.class}#screenshot id=#{id}" }
      stream = hypervisor.create_stream
      mime_type = domain.screenshot(stream, 0)
      file = File.open(tmp_filename, 'wb')
      dbg { "#{self.class}#screenshot initiated id=#{id} mime_type=#{mime_type} filename=#{tmp_filename}" }

      stream.event_add_callback(
          Libvirt::Stream::EVENT_READABLE,
          method(:screenshot_callback).to_proc,
          ScreenshotCallback.new(file, block, tmp_filename, filename)
      )
      dbg { "#{self.class}#screenshot callback added id=#{id}" }

      proc do
        dbg { "#{self.class}#screenshot cancel id=#{id}" }
        file.close
        stream.event_remove_callback
        stream.finish
      end
    rescue Libvirt::Error => e
      block.call(false, tmp_filename, "#{e.class} #{e.message}")
    end

    private

    # @param stream [Libvirt::Stream]
    # @param events [Integer]
    # @param opaque [ScreenshotCallback] file: File, callback: Proc, tmp_filename: String, filename: string.
    # def screenshot_callback(stream, events, opaque)
    def screenshot_callback(stream, events, opaque)
      dbg { "#{self.class}#screenshot_callback id=#{id} events=#{events}" }
      return unless (Libvirt::Stream::EVENT_READABLE & events) != 0

      code, data = stream.recv(1024)
      dbg { "#{self.class}#screenshot_callback recv id=#{id} code=#{code} size=#{data&.size}" }

      case code
      when 0
        dbg { "#{self.class}#screenshot_callback finished id=#{id}" }
        opaque.file.close
        stream.finish
        FileUtils.move(opaque.tmp_filename, opaque.filename)
        opaque.callback.call(true, opaque.filename, nil)
      when -1
        dbg { "#{self.class}#screenshot_callback error id=#{id}" }
        opaque.file.close
        stream.finish
        opaque.callback.call(false, nil, 'error code -1 received')
      when -2
        dbg { "#{self.class}#screenshot_callback is not ready id=#{id}" }
      else
        dbg { "#{self.class}#screenshot_callback ready id=#{id}" }
        opaque.file.write(data)
      end

    rescue Libvirt::Error => e
      dbg { "<#{e.class}>: #{e.message}\n #{e.backtrace.join("\n")}" }
      opaque.file.close
      stream.finish
      opaque.callback.call(false, nil, "#{e.class} #{e.message}")
    end

  end
end
