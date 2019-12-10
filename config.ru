require File.expand_path('../app', __FILE__)

warmup do
  puts 'warming up!'
  require 'lib/initialize_loop'
end

run VirtualizationServer::API
