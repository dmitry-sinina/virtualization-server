
# fix websocket
Falcon::Adapters::Output.class_eval do
  def call(stream)
    @body.call(stream)
  end
end

# fix sinja. @see SinjaPatch
Falcon::Adapters::Input.class_eval do
  def empty?
    return @body.empty? if @body.respond_to?(:empty?)
    (@body&.size || 0) > 0
  end
end
