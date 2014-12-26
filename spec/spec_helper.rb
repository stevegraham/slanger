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
require 'timecop'
require 'pry'
require 'webmock/rspec'
require 'slanger'

WebMock.disable!

module Slanger; end

def errback
  @errback ||= Proc.new { |e| fail 'cannot connect to slanger. your box might be too slow. try increasing sleep value in the before block' }
end

RSpec.configure do |config|
  config.formatter = 'documentation'
  config.color = true
  config.mock_framework = :mocha
  config.order = 'random'
  config.include SlangerHelperMethods
  config.fail_fast = true
  config.after(:each) { stop_slanger if @server_pid }
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
