# Application class in plain old ruby objects.

require 'glamazon'

module Slanger
  class ApplicationPoro < Application
    include Glamazon::Base

    def initialize(attrs)
      super(attrs)
    end
  end
end

ApplicationImpl = Slanger::ApplicationPoro
