#encoding: utf-8
require 'spec/spec_helper'

describe 'Integration' do

  before(:each) { start_slanger }

  context "given invalid JSON as input" do
    it 'should not crash' do
      messages  = em_stream do |websocket, messages|
        websocket.callback do
          websocket.send("{ event: 'pusher:subscribe', data: { channel: 'MY_CHANNEL'} }23123")
          EM.next_tick { EM.stop }
        end if messages.one?

      end

      EM.run { new_websocket.tap { |u| u.stream { EM.next_tick { EM.stop } } }}
    end
  end
end
