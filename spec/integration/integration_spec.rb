require 'bundler/setup'

require 'active_support/json'
require 'active_support/core_ext/hash'
require 'eventmachine'
require 'em-http-request'
require 'pusher'
require 'thin'

describe 'Integration' do
  Thread.abort_on_exception = false
  before(:each) do
    # Fork service. Our integration tests MUST block the main thread because we want to wait for i/o to finish.
    @server_pid = EM.fork_reactor do
      require File.expand_path(File.dirname(__FILE__) + '/../../slanger.rb')
      Thin::Logging.silent = true
      Slanger::Service.run host: '0.0.0.0', api_port: '4567', websocket_port: '8080', app_key: '765ec374ae0a69f4ce44'
    end
    # Give Slanger a chance to start
    sleep 2
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

  it 'pushes messages to interested websocket connections' do
    messages  = []

    Thread.new do
      EM.run do
        websocket = EM::HttpRequest.new("ws://0.0.0.0:8080/app/#{Pusher.key}?client=js&version=1.8.5").
          get :timeout => 0

        websocket.stream do |message|
          messages << message
          if messages.length < 2
            Pusher['MY_CHANNEL'].trigger_async 'an_event', { some: 'data' }
          else
            EM.stop
          end
        end

        websocket.callback do
          websocket.send({ event: 'pusher:subscribe', data: { channel: 'MY_CHANNEL'} }.to_json)
        end

      end
    end.join

    # Slanger should send an object denoting connection was succesfully established
    JSON.parse(messages.first)['event'].should == 'pusher:connection_established'
    # Channel id should be in the payload
    JSON.parse(messages.first)['data']['socket_id'].should_not be_nil
    # Slanger should send out the message
    JSON.parse(messages.last)['event'].should == 'an_event'
    JSON.parse(messages.last)['data'].should == { some: 'data' }.to_json
  end

  it 'avoids duplicate events' do
    client1_messages, client2_messages  = [], []

    Thread.new do
      EM.run do
        client1 = EM::HttpRequest.new("ws://0.0.0.0:8080/app/#{Pusher.key}?client=js&version=1.8.5").
          get :timeout => 0

        client1.callback do
          client1.send({ event: 'pusher:subscribe', data: { channel: 'MY_CHANNEL'} }.to_json)
        end

        client1.stream do |message|
          client1_messages << message

          client2 = EM::HttpRequest.new("ws://0.0.0.0:8080/app/#{Pusher.key}?client=js&version=1.8.5").
            get :timeout => 0

          client2.callback do
            client2.send({ event: 'pusher:subscribe', data: { channel: 'MY_CHANNEL'} }.to_json)
          end

          client2.stream do |message|
            client2_messages << message
            if client2_messages.length < 2
              socket_id = JSON.parse(client1_messages.first)['data']['socket_id']
              Pusher['MY_CHANNEL'].trigger_async 'an_event', { some: 'data' }, socket_id
            else
              EM.stop
            end
          end
        end
      end
    end.join

    client1_messages.size.should == 1
    JSON.parse(client2_messages.last)['event'].should == 'an_event'
    JSON.parse(client2_messages.last)['data'].should == { some: 'data' }.to_json
  end
end
