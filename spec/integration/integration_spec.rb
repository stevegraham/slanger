#encoding: utf-8
require 'spec_helper'

describe 'Integration' do

  before(:each) { start_slanger }

  context "connecting with invalid credentials" do
    it "sends an error message" do
      messages = em_stream(key: 'bogus_key') do |websocket, messages|
        websocket.callback { EM.stop }
      end
      expect(messages).to have_attributes count: 1, last_event: 'pusher:error',
        connection_established: false, id_present: false
      messages.first['data'] == 'Could not find app by key bogus_key'
    end
  end

  context "connecting with valid credentials" do
    it "should succeed and include activity_timeout value in handshake" do
      messages = em_stream do |websocket, messages|
        websocket.callback { EM.stop }
      end
      expect(messages).to have_attributes activity_timeout: Slanger::Config.activity_timeout,
        connection_established: true, id_present: true
    end
  end

  context "connect with valid protocol version" do
    it "should connect successfuly" do
      messages = em_stream do |websocket, messages|
        websocket.callback { EM.stop }
      end
      expect(messages).to have_attributes connection_established: true, id_present: true
    end
  end

  context "connect with invalid protocol version" do
    it "should not connect successfuly with version bigger than supported" do
      messages = em_stream(protocol: "20") do |websocket, messages|
        websocket.callback { EM.stop }
      end
      expect(messages).to have_attributes connection_established: false, id_present: false,
        last_event: 'pusher:error'
    end

    it "should not connect successfuly without specified version" do
      messages = em_stream(protocol: nil) do |websocket, messages|
        websocket.callback { EM.stop }
      end
      expect(messages).to have_attributes connection_established: false, id_present: false,
        last_event: 'pusher:error'
    end
  end

  context "given invalid JSON as input" do
    it 'should not crash' do
      messages  = em_stream do |websocket, messages|
        websocket.callback do
          websocket.send("{ event: 'pusher:subscribe', data: { channel: 'MY_CHANNEL'} }23123")
          EM.next_tick { EM.stop }
        end
      end

      EM.run { new_websocket.tap { |u| u.stream { EM.next_tick { EM.stop } } }}
    end
  end
end
