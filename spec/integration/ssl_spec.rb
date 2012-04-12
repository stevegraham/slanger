require 'bundler/setup'

require 'active_support/json'
require 'active_support/core_ext/hash'
require 'eventmachine'
require 'em-http-request'
require 'pusher'
require 'thin'
require './spec/spec_helper'

describe 'Integration' do
  let(:errback) { Proc.new { fail 'cannot connect to slanger. your box might be too slow. try increasing sleep value in the before block' } }

  before(:each) do
    # Fork service. Our integration tests MUST block the main thread because we want to wait for i/o to finish.
    @server_pid = EM.fork_reactor do
      require File.expand_path(File.dirname(__FILE__) + '/../../slanger.rb')
      Thin::Logging.silent = true

      Slanger::Config.load host:             '0.0.0.0',
                           api_port:         '4567',
                           websocket_port:   '8080',
                           app_key:          '765ec374ae0a69f4ce44',
                           secret:           'your-pusher-secret',
                           cert_chain_file:  'spec/server.crt',
                           private_key_file: 'spec/server.key'

      Slanger::Service.run
    end
    # Give Slanger a chance to start
    sleep 0.6
  end

  after(:each) do
    # Ensure Slanger is properly stopped. No orphaned processes allowed!
    Process.kill 'SIGKILL', @server_pid
    Process.wait @server_pid
  end

  before :all do
    Pusher.tap do |p|
      p.host   = '0.0.0.0'
      p.port   = 4567
      p.app_id = 'your-pusher-app-id'
      p.secret = 'your-pusher-secret'
      p.key    = '765ec374ae0a69f4ce44'
    end
  end
  
  describe 'regular channels:' do
    it 'pushes messages to interested websocket connections' do
      messages = em_stream do |websocket, messages|
        websocket.callback do
          websocket.send({ event: 'pusher:subscribe', data: { channel: 'MY_CHANNEL'} }.to_json)
        end if messages.one?

        if messages.length < 3
          Pusher['MY_CHANNEL'].trigger_async 'an_event', { some: 'data' }
        else
          EM.stop
        end

     end

      messages.should have_attributes connection_established: true, id_present: true,
        last_event: 'an_event', last_data: { some: 'data' }.to_json
    end
  end
end