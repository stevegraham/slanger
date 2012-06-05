# Application class in plain old ruby objects.

require 'glamazon'

module Slanger
  class ApplicationPoro
    include Glamazon::Base
    include Application::Methods

    def initialize(attrs)
      super(attrs)
    end
  end
end

ApplicationImpl = Slanger::ApplicationPoro
