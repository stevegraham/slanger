#encoding: utf-8
require 'spec/spec_helper'

describe 'Integration:' do

  before(:each) { start_slanger }

  describe 'channel' do
    it 'pushes messages to interested websocket connections' do
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

      messages.should have_attributes connection_established: true, id_present: true,
        last_event: 'an_event', last_data: { some: "Mit Raben Und Wölfen" }.to_json
    end

    it 'avoids sending duplicate events' do
      client2_messages  = []

      client1_messages = em_stream do |client1, client1_messages|
        # if this is the first message to client 1 set up another connection from the same client
        if client1_messages.one?
          client1.callback do
            client1.send({ event: 'pusher:subscribe', data: { channel: 'MY_CHANNEL'} }.to_json)
          end

          client2_messages = em_stream do |client2, client2_messages|
            case client2_messages.length
            when 1
              client2.callback { client2.send({ event: 'pusher:subscribe', data: { channel: 'MY_CHANNEL'} }.to_json) }
            when 2
              socket_id = client1_messages.first['data']['socket_id']
              Pusher['MY_CHANNEL'].trigger_async 'an_event', { some: 'data' }, socket_id
            when 3
              EM.stop
            end
          end
        end
      end

      client1_messages.should have_attributes count: 2

      client2_messages.should have_attributes last_event: 'an_event',
                                              last_data: { some: 'data' }.to_json
    end
  end
end
