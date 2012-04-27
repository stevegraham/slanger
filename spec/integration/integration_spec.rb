#encoding: utf-8
require 'spec/spec_helper'

describe 'Integration' do

  before(:each) do
    start_slanger
    wait_for_slanger
  end

  context "connecting with invalid credentials" do
    it "sends an error message" do
      messages = em_stream(key: 'bogus_key') do |websocket, messages|
        websocket.callback { EM.stop }
      end
      messages.should have_attributes count: 1, last_event: 'pusher:error',
        connection_established: false, id_present: false
      messages.first['data'] == 'Could not find app by key bogus_key'
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
