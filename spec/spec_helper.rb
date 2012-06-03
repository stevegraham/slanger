require 'bundler/setup'

require 'active_support/json'
require 'active_support/core_ext/hash'
require 'eventmachine'
require 'em-http-request'
require 'pusher'
require 'thin'
require 'slanger_helper_methods'
require 'have_attributes'
require 'openssl'
require 'socket'

RSpec.configure do |config|
  config.include SlangerHelperMethods
  config.fail_fast = true
  config.after(:each) { stop_slanger }
  config.before :all do
    Pusher.tap do |p|
      p.host   = '0.0.0.0'
      p.port   = 4567
      p.app_id = 'your-pusher-app-id'
      p.secret = 'your-pusher-secret'
      p.key    = '765ec374ae0a69f4ce44'
    end
  end
end
