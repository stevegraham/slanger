# Application class in plain old ruby objects.

require 'glamazon'

module Slanger
  class ApplicationPoro
    include Glamazon::Base
    include Application::Methods
    @@id_sequence = 0

    def initialize(attrs)
      super(attrs)
    end

    def self.new_id()
      app_id = @@id_sequence
      @@id_sequence += 1
      app_id
    end
  end
end
