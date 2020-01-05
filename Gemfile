source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '2.6.0'

gem 'dotenv'
gem 'sinatra'

# https://bugzilla.redhat.com/show_bug.cgi?id=1787914
# Use patched version of gem until issue resolved.
#   $ gem install ./ruby-libvirt-0.7.2.pre.streamfix.gem
#   $ bundle install
#
gem 'ruby-libvirt', '0.7.2.pre.streamfix'

gem 'pry'
gem 'sinja'
gem 'jsonapi-serializers'
gem 'activesupport'

# Async libvirt event api implementation
# https://github.com/senid231/libvirt_async
gem 'libvirt_async', '~> 0.1'

# Async web server
# https://github.com/socketry/falcon
gem 'falcon'

# Async websocket implementation
# https://github.com/socketry/async-websocket
gem 'async-websocket'

gem 'async_cable'

# Ruby libraries and applications configuration on steroids!
# https://github.com/palkan/anyway_config
gem 'anyway_config', '2.0.0.pre'

# Contributed Rack Middleware and Utilities
gem 'rack-contrib'

group :development do
  gem 'byebug'
end

group :test do
  gem 'rspec'
  gem 'httparty'
  gem 'websocket-client-simple'
end

