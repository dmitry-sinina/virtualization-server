require 'active_support/all'
require 'sinatra/jsonapi'
require 'sinatra/custom_logger'
require_relative 'config/environment'

VirtualizationServer.config.root = File.absolute_path(__dir__)

module VirtualizationServer
  class API < Sinatra::Base
    helpers Sinatra::CustomLogger
    register Sinatra::JSONAPI

    configure do
      enable :logging

      logger =  Logger.new(STDOUT)
      logger.level = Logger::DEBUG if development?
      set :logger, logger
    end

    helpers do
      def authorize_current_user!
        raise Sinja::UnauthorizedError.new('unauthorized') if current_user.nil?
      end

      def current_user
        return env['current_user.rack.session'] if env.key?('current_user.rack.session')
        env['current_user.rack.session'] = find_current_user
      end

      def find_current_user
        user_id = request.session['user_id']
        return unless user_id
        User.find_by(id: user_id)
      end

      def clear_current_user
        env['current_user.rack.session'] = nil
      end
    end

    resource :sessions do
      helpers do
        def find(_id)
          current_user
        end
      end

      create do |attrs|
        user = User.authenticate(attrs)
        if user.nil?
          raise Sinja::UnprocessibleEntityError.new([[nil, 'login or password invalid']])
        end
        request.session['user_id'] = user.id
        next user.id, user
      end

      destroy do
        user_id = current_user.id
        request.session['user_id'] = nil
        clear_current_user
        next user_id
      end
    end

    resource :hypervisors do
      before do
        authorize_current_user!
      end

      helpers do
        def find(id)
          Hypervisor.find_by(id: id.to_i)
        end
      end

      index do
        Hypervisor.all
      end

      show do
        next resource
      end
    end #resource :hypervisors

    resource :virtual_machines, pkre: '/[\w-]+/' do
      before do
        authorize_current_user!
      end

      helpers do
        def find(id)
          VirtualMachine.find_by(id: id.to_s)
        end
      end

      index do
        VirtualMachine.all
      end

      show do
        next resource, include: %q[hypervisor]
      end

      has_one :hypervisor do
        pluck do
          resource.hypervisor
        end
      end

    end #resource :virtual_machines

    freeze_jsonapi

  end #class API
end #class VirtualizationServer
