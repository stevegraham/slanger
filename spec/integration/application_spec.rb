#encoding: utf-8
require 'spec/spec_helper'

describe 'Integration:' do

  describe 'applications' do
    it 'with channels with same names do not see each others messages' do
      start_slanger
      client2_messages  = []

      # TODO: this doesn't work, it prevents further tests from completing.

      #client1_messages = em_stream do |client1, client1_messages|
      #  # if this is the first message to client 1 set up another connection from the same client
      #  if client1_messages.one?
      #    client1.callback do
      #      client1.send({ event: 'pusher:subscribe', data: { channel: 'MY_CHANNEL'} }.to_json)
      #    end

      #    pusher_app2
      #    client2_messages = em_stream do |client2, client2_messages|
      #      case client2_messages.length
      #      when 1
      #        client2.callback { client2.send({ event: 'pusher:subscribe', data: { channel: 'MY_CHANNEL'} }.to_json) }
      #      when 2
      #        socket_id = client1_messages.first['data']['socket_id']
      #        Pusher['MY_CHANNEL'].trigger_async 'an_event', { some: 'data' }, socket_id
      #      when 3
      #        EM.stop
      #      end
      #    end
      #  end
      #end
      #pusher_app1

      #client1_messages.should have_attributes count: 2
      #
      #client2_messages.should have_attributes last_event: 'an_event',
      #                                        last_data: { some: 'data' }.to_json
    end
  end

  describe 'existing applications stored in mongodb' do
    it 'should be retrieved and usable by Slanger' do
      start_slanger_with_mongo
       
      messages = em_stream do |websocket, messages|
        case messages.length
        when 1
          if messages[0]['event'] == 'pusher:error'
            EM.stop
          end
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
  end
end
