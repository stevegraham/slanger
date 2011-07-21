require 'eventmachine'
require 'em-hiredis'
require 'rack'

EM.run do
  File.tap do |f|
    Dir[f.expand_path(f.join(f.dirname(__FILE__),'lib', 'slanger', '*.rb'))].reverse_each { |file| require file }
  end
end