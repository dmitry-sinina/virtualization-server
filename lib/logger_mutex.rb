require 'reentrant_mutex'

class LoggerMutex
  attr_reader :mutex

  def initialize(class_name = nil)
    @class_name = class_name
    @mutex = ReentrantMutex.new
  end

  def synchronize
    dbg 'acquiring lock'
    @mutex.synchronize do
      dbg 'locked'
      yield
    end
    dbg 'unlocked'
  end

  private

  def dbg(msg)
    meth_name = caller.first.match(/`(.+)'/)[1]
    from_meth_name = caller.second.match(/`(.+)'/)[1]
    AppLogger.debug("0x#{object_id.to_s(16)}") { "#{self.class}::#{meth_name} (#{@class_name}##{from_meth_name}) #{msg}" }
  end
end
