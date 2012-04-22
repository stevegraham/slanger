#encoding: utf-8
require 'spec/spec_helper'

describe 'Integration' do

  before(:each) { start_slanger }

  describe 'private channels' do
    context 'with valid authentication credentials:' do
      it 'accepts the subscription request' do
        messages  = em_stream do |websocket, messages|
          if messages.length < 2
            private_channel websocket, messages.first
         else
            EM.stop
          end
        end

        messages.should have_attributes connection_established: true,
                                        count: 2,
                                        id_present: true,
                                        last_event: 'pusher_internal:subscription_succeeded'
      end
    end

    context 'with bogus authentication credentials:' do
      it 'sends back an error message' do
        messages  = em_stream do |websocket, messages|
          if messages.length < 2
            websocket.send({ event: 'pusher:subscribe',
                             data: { channel: 'private-channel',
                                     auth: 'bogus' } }.to_json)
          else
            EM.stop
          end
        end

        messages.should have_attributes connection_established: true, count: 2, id_present: true, last_event:
          'pusher:error'
        messages.last['data']['message'].=~(/^Invalid signature: Expected HMAC SHA256 hex digest of/).should be_true
      end
    end



    describe 'client events' do
      it "sends event to other channel subscribers" do
        client1_messages, client2_messages  = [], []

        em_thread do
          client1, client2 = new_websocket, new_websocket
          client2_messages, client1_messages = [], []

          client1.callback {}

          stream(client1, client1_messages) do |message|
            if client1_messages.length < 2
              private_channel client1, client1_messages.first
            elsif client1_messages.length == 3
              EM.stop
            end
          end

          client2.callback {}

          stream(client2, client2_messages) do |message|
            if client2_messages.length < 2
              private_channel client2, client2_messages.first
            else
              client2.send({ event: 'client-something', data: { some: 'stuff' }, channel: 'private-channel' }.to_json)
            end
          end
        end

        client1_messages.none? { |m| m['event'] == 'client-something' }
        client2_messages.one?  { |m| m['event'] == 'client-something' }
      end
    end
  end
 end
