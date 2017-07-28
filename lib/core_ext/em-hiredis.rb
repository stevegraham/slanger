module EventMachine
  module Hiredis
    class BaseClient
      # Silence ruby 2.4 warnings for method delegation
      # em-hiredis actully will accept all method names and send them to redis
      # as commands, so returning only true fine here
      def respond_to_missing?(_method_name, _include_private = false)
        true
      end
    end
  end
end
