require 'bundler/setup'

require 'eventmachine'
require 'em-hiredis'
require 'rack'
require 'active_support/core_ext/string'

module Jagan; end

EM.run do
  File.tap do |f|
    Dir[f.expand_path(f.join(f.dirname(__FILE__),'lib', 'jagan', '*.rb'))].each do |file|
      Jagan.autoload File.basename(file, '.rb').classify, file
    end
  end
end
