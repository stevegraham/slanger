#encoding: utf-8
require 'spec_helper'

describe 'Integration' do

  before(:each) { start_slanger }

  describe 'private channels' do
    context 'with valid authentication credentials:' do
      it 'accepts the subscription request' do
        messages  = em_stream do |websocket, messages|
          case messages.length
          when 1
            private_channel websocket, messages.first
          else
            EM.stop
          end
        end

        expect(messages).to have_attributes connection_established: true,
          count: 2,
          id_present: true,
          last_event: 'pusher_internal:subscription_succeeded'
      end
    end

    context 'with bogus authentication credentials:' do
      it 'sends back an error message' do
        messages  = em_stream do |websocket, messages|
          case messages.length
          when 1
            websocket.send({ event: 'pusher:subscribe',
                             data: { channel: 'private-channel',
                                     auth: 'bogus' } }.to_json)
          else
            EM.stop
          end
        end

        expect(messages).to have_attributes connection_established: true, count: 2, id_present: true, last_event:
          'pusher:error'

        expect(JSON.parse(messages.last['data'])['message']).to match /^Invalid signature: Expected HMAC SHA256 hex digest of/
      end
    end

    describe 'client events' do
      it "sends event to other channel subscribers" do
        client1_messages, client2_messages  = [], []

        em_thread do
          client1, client2 = new_websocket, new_websocket
          client2_messages, client1_messages = [], []

          stream(client1, client1_messages) do |message|
            case client1_messages.length
            when 1
              private_channel client1, client1_messages.first
            when 3
              EM.next_tick { EM.stop }
            end
          end

          stream(client2, client2_messages) do |message|
            case client2_messages.length
            when 1
              private_channel client2, client2_messages.first
            when 2
              client2.send({ event: 'client-something', data: { some: 'stuff' }, channel: 'private-channel' }.to_json)
            end
          end
        end

        expect(client1_messages.one?  { |m| m['event'] == 'client-something' }).to eq(true)
        expect(client2_messages.none? { |m| m['event'] == 'client-something' }).to eq(true)
      end
    end
  end
end
