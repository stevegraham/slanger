#encoding: utf-8
require 'spec/spec_helper'
  
describe 'Metrics:' do
  before(:each) { 
    cleanup_db
  }

  with_mongo_slanger do
    describe 'number of connections in work_data' do
      it 'should reflect number of clients' do
        nb_connections_while = nil

        messages = em_stream do |websocket, messages|
          case messages.length
          when 1
            if messages[0]['event'] == 'pusher:error'
              EM.stop
            end
            websocket.callback { websocket.send({ event: 'pusher:subscribe', data: { channel: 'MY_CHANNEL'} }.to_json) }
          when 2
            nb_connections_while = get_number_of_connections
            EM.stop
          end
        end
  
        nb_connections_while.should eq(1)
      end
  
      it 'should decrease after a client exit' do
        nb_connections_while = nil 
        nb_connections_after = nil
  
        messages = em_stream do |websocket, messages|
          case messages.length
          when 1
            if messages[0]['event'] == 'pusher:error'
              EM.stop
            end
            websocket.callback { websocket.send({ event: 'pusher:subscribe', data: { channel: 'MY_CHANNEL'} }.to_json) }
          when 2
            nb_connections_while = get_number_of_connections
            EM.stop
          end
        end
  
        # Give slanger the chance to run before checking the number of connections again
        sleep 2
        nb_connections_after = get_number_of_connections
  
        nb_connections_while.should eq(1)
        nb_connections_after.should eq(0)
      end
  
      it 'should be zero when slanger is killed' do
        nb_connections_while = nil 
        nb_connections_after = nil
  
        messages = em_stream do |websocket, messages|
          case messages.length
          when 1
            if messages[0]['event'] == 'pusher:error'
              EM.stop
            end
            websocket.callback { websocket.send({ event: 'pusher:subscribe', data: { channel: 'MY_CHANNEL'} }.to_json) }
          when 2
            nb_connections_while = get_number_of_connections
            kill_slanger
            timer = EventMachine::Timer.new(2) do
              # get number of connection before quitting. If slanger was still running it would be 1
              nb_connections_after = get_number_of_connections
              EM.stop
            end
          end
        end
  
        nb_connections_while.should eq(1)
        nb_connections_after.should eq(0)
      end
    end
  
    describe 'number of messages' do
      it 'should increase as messages are received' do
        nb_message = nil

        messages = em_stream do |websocket, messages|
          case messages.length
          when 1
            websocket.callback { websocket.send({ event: 'pusher:subscribe', data: { channel: 'MY_CHANNEL'} }.to_json) }
          when 2
            Pusher['MY_CHANNEL'].trigger_async 'an_event', { some: "Mit Raben Und Wölfen" }
          when 3
            EM.stop
          end
        end
        nb_messages = get_number_of_messages
  
        nb_messages.should eq(1)
      end
    end
  
    with_stale_metrics do
      describe 'slanger' do
        it 'should clean up old work data when starting' do
          nb_connections_before = get_number_of_connections
          # Give slanger time to start up
          sleep 2
          nb_connections_after = get_number_of_connections
  
          nb_connections_before.should eq(1)
          nb_connections_after.should eq(0)
        end
      end
    end
  end
end
