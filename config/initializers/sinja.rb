require 'sinatra/jsonapi'

configure_jsonapi do |c|
  # To-one relationship roles
  c.default_has_one_roles = {
      pluck: :virtual_machine #,
      # pluck: :hypervisor
  }

  # To-many relationship roles
  c.default_has_many_roles = {
      fetch: :hypervisor
  }

  c.error_logger = ->(error_hash) { logger.error('sinja') { error_hash } }
  #c.json_error_generator = development? ? :pretty_generate : :generate
  c.json_error_generator = :pretty_generate

end
