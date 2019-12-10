require 'singleton'
require 'forwardable'
require 'logger'

class AppLogger
  include Singleton
  extend Forwardable
  extend SingleForwardable

  class AppFormatter
    LOG_FORMAT = "%s, %s [%d/%s/%s] %s\n".freeze
    DEFAULT_DATETIME_FORMAT = "%H:%M:%S".freeze

    attr_accessor :datetime_format

    def initialize
      @datetime_format = nil
    end

    def call(severity, time, progname, message)
      LOG_FORMAT % [
          severity[0..0],
          format_datetime(time),
          Process.pid,
          "0x#{Thread.current.object_id.to_s(16)}",
          progname,
          format_message(message)
      ]
    end

    private

    def format_datetime(time)
      time.strftime(@datetime_format || DEFAULT_DATETIME_FORMAT)
    end

    def format_message(message)
      case message
      when ::String
        message
      when ::Exception
        "<#{message.class}>:#{message.message}\n#{(message.backtrace || []).join("\n")}"
      else
        message.inspect
      end
    end
  end

  LOGGER_METHODS = [
      :level,
      :level=,
      :progname,
      :progname=,
      :formatter,
      :formatter=,
      :debug,
      :info,
      :warn,
      :error,
      :fatal
  ].freeze

  FORMATTER_METHODS = [
      :datetime_format,
      :datetime_format=
  ].freeze

  single_delegate [*LOGGER_METHODS, *FORMATTER_METHODS, :setup_logger] => :instance

  instance_delegate LOGGER_METHODS => :logger
  instance_delegate FORMATTER_METHODS => :formatter

  def logger
    @logger ||= create_logger(STDOUT)
  end

  def setup_logger(io, options = {})
    @logger = create_logger(io, options)
  end

  private

  def create_logger(io, formatter: AppFormatter.new, progname: nil, level: Logger::Severity::DEBUG, datetime_format: nil)
    formatter.datetime_format = datetime_format unless datetime_format.nil?
    Logger.new(io, formatter: formatter, progname: progname, level: level)
  end
end
