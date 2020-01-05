class User
  include JSONAPI::Serializer

  class_attribute :_storage, instance_accessor: false

  class << self
    def load_storage(users)
      self._storage = users.map do |user|
        new id: user['id'], login: user['login'], password: user['password']
      end
    end

    def authenticate(login:, password:)
      user = _storage.detect { |user| user.login == login }
      user&.authenticate?(password) ? user : nil
    end

    def find_by(id:)
      _storage.detect { |user| user.id.to_s == id.to_s }
    end
  end

  attr_reader :id, :login

  def initialize(id:, login:, password:)
    @id = id
    @login = login
    @password = password
  end

  def authenticate?(password)
    @password == password
  end
end
