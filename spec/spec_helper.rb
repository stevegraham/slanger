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
require 'webmock/rspec'

WebMock.disable!

module Slanger; end

def errback
  @errback ||= Proc.new { |e| fail 'cannot connect to slanger. your box might be too slow. try increasing sleep value in the before block' }
end

RSpec.configure do |config|
  config.mock_framework = :mocha
  config.include SlangerHelperMethods
  config.fail_fast = true
  config.after(:each) { stop_slanger }
  config.before :all do
    pusher_app1
  end
end
