# https://github.com/rack/rack/issues/1148
# Variable request.body in most of cases is a Protocol::HTTP1::Body::Fixed,
# which is not Rewindable.
# rewind was needed in #deserialize_request_body because in #content?
# we were reading first 2 bytes to check if body present.
# but it has #empty? method for this.
#
module SinjaPatch
  def content?
    return request.body.size > 0 if request.body.respond_to?(:size)
    return !request.body.empty? if request.body.respond_to?(:empty?)
    raise StandardError "body #{request.body.class} does not respond to #size nor #empty?"
  end
end

# Fix issue with malformed json.
# Must be added after `Sinatra::JSONAPI`.
VirtualizationServer::API.prepend SinjaPatch

class Sinja::UnauthorizedError < Sinja::HttpError
  HTTP_STATUS = 401

  def initialize(*args)
    super(HTTP_STATUS, *args)
  end
end
