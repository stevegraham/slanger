Dir["#{File.dirname(__FILE__)}/../**/*.rb"].each { |f| require f }
require 'mocha'

RSpec.configure do |config|
  config.mock_with :mocha
end