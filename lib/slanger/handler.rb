require 'active_support/json'
require 'active_support/core_ext/hash'
require 'securerandom'

module Slanger
  class Handler
    def initialize(socket, app_key)
      @socket, @app_key = socket, app_key
      authenticate
    end

    def onmessage(msg)
      msg = JSON.parse msg
      send msg['event'].gsub(':', '_'), msg
    end

    def onclose
      channel = Slanger::Channel.find_by_channel_id(@channel_id).first
      channel.unsubcribe @subscription_id
    end

    private
    def authenticate
      app_key = @socket.request['path'].split(/\W/)[2]
      if app_key == @app_key
        @socket_id = SecureRandom.uuid
        @socket.send(payload 'pusher:connection_established', { socket_id: @socket_id })
      else
        @socket.send(payload 'pusher:error', { code: '4001', message: "Could not find app by key #{app_key}" })
        @socket.close_websocket
      end
    end

    def pusher_subscribe(msg)
      @channel_id = msg['data']['channel']
      channel = Slanger::Channel.find_or_create_by_channel_id(@channel_id).first
      @subscription_id = channel.subscribe { |msg| @socket.send msg }
    end

    def payload(event_name, payload = {})
      { event: event_name, data: payload }.to_json
    end
  end
end