require 'jsonapi-serializers'

class UserSerializer
  include JSONAPI::Serializer

  attribute :login

  def type
    'sessions'.freeze
  end
end
