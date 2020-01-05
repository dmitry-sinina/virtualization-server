module VirtualizationServer
  class Config < Anyway::Config
    config_name :app # set load path config/app.yml

    attr_config :cookie_secret,
                :libvirt_domain_type,
                :clusters,
                :users,
                :root,
                libvirt_rw: false

    def load!
      raise RuntimeError, "Config #{config_path} does not exist" unless File.file?(config_path)
      load # will load config/app.yml
      validate_presence! :users, :clusters, :cookie_secret
    end

    private

    def validate_presence!(*names)
      names.each do |name|
        raise RuntimeError, "Key #{name} must be present at #{config_path}" if public_send(name).nil?
      end
    end

    def config_path
      @config_path ||= default_config_path(config_name)
    end
  end

  def environment
    ENV.fetch('RACK_ENV') { 'development' }
  end

  def config
    @config ||= Config.new
  end

  def configure
    yield config
  end

  module_function :config, :configure, :environment
end
