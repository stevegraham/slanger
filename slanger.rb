require 'bundler/setup'

require 'eventmachine'
require 'em-hiredis'
require 'rack'

module Slanger; end

EM.run do
  File.tap do |f|
    Dir[f.expand_path(f.join(f.dirname(__FILE__),'lib', 'slanger', '*.rb'))].each do |file|
      Slanger.autoload File.basename(file, '.rb').classify, file
    end
  end
end
