class DomainEventCable < AsyncCable::Connection
  # Client example js:
  #
  #   var socket = new WebSocket("ws://localhost:4567/cable");
  #   socket.onopen = function(_event) { console.log("WebSocket connected"); };
  #   socket.onerror = function(error) { console.log("WebSocket error", error); };
  #   socket.onclose = function(event) { console.log('WebSocket closed", event.wasClean, event.code, event.reason); };
  #   socket.onmessage = function(event) { console.log("WebSocket data received", JSON.parse(event.data)); };
  #   socket.send( JSON.generate({ hello: 'world' }) );
  #   socket.close( 1000, 'client' );
  #

  identified_as :domain_event
  delegate :session, to: :request

  def on_open
    logger.debug { "#{to_s}#on_open user_id=#{session['user_id']}" }
    reject_unauthorized if current_user.nil?
    stream_for current_user.login
    logger.debug { "#{to_s}#on_open authorized login=#{current_user.login}" }
  end

  def on_data(data)
    logger.info { "#{to_s}#on_data data=#{data.inspect}" }
    if data[:type] == 'screenshot'
      take_screenshot(data)
    elsif data[:type] == 'ping'
      # ignore
    else
      transmit error: 'invalid type', type: data[:type]
    end
  end

  def on_close
    task = LibvirtAsync::Util.create_task do
      streams.each(&:cancel)
    end
    Async::Task.current.reactor << task.fiber
  end

  private

  def take_screenshot(data)
    vm = VirtualMachine.find_by id: data[:id]

    if vm.nil?
      transmit error: 'invalid id', type: 'screenshot', id: data[:id]
      return
    end

    file = Tempfile.new("screenshot_#{vm.adapter.domain.uuid}", nil, mode: File::Constants::BINARY)
    stream = LibvirtAsync::StreamRead.new(vm.hypervisor.connection, file)

    mime_type = vm.adapter.domain.screenshot(stream.stream, 0)
    logger.debug { "#{to_s}#take_screenshot initiated mime_type=#{mime_type}, file_path=#{file.path}" }

    stream.call do |success, reason, io|
      logger.debug { "#{to_s}#take_screenshot finish" }
      streams.delete(stream)
      on_stream_finish success, reason, io, domain_id: data[:id]
    end

    streams.push(stream)
  end

  def on_stream_finish(success, reason, file, domain_id:)
    file.close

    unless success
      transmit(error: reason, type: 'screenshot', id: domain_id)
      return
    end

    asset_path = "/screenshots/#{domain_id}.pnm"
    file_path = File.join(VirtualizationServer.config.root, 'public', asset_path)
    FileUtils.mv(file.path, file_path)
    transmit(file: asset_path, type: 'screenshot', id: domain_id)
  end

  def current_user
    return @current_user if defined?(@current_user)
    @current_user = User.find_by id: session['user_id']
  end

  def streams
    @streams ||= []
  end
end
