require 'singleton'

module Jagan
  class LoggerSingleton
    extend Forwardable
    include Singleton

    def_delegators :logger, :add, :debug, :debug?, :error, :error?, :fatal, :fatal?, :info, :info?, :log, :unknown, :warn, :warn?
   
    def logger
      @logger ||= ::Logger.new(Config.log_file).tap do |log|
         log.level = Config.log_level
      end
    end 

    def audit_logger
      @audit_logger ||= ::Logger.new(Config.audit_log_file).tap do |log|
         log.level = ::Logger::INFO
      end
    end 

    def audit(msg)
      audit_logger.info(msg)
    end
  end

  Logger = LoggerSingleton.instance
end
