require 'active_support/json'
require 'active_support/core_ext/hash'
require 'securerandom'
require 'signature'

module Slanger
  class Handler
    def initialize(socket, app_key)
      @socket, @app_key = socket, app_key
      authenticate
    end

    def onmessage(msg)
      msg = JSON.parse msg
      send msg['event'].gsub('pusher:', 'pusher_'), msg
    end

    def onclose
      channel = Slanger::Channel.find_by_channel_id(@channel_id) || Slanger::PresenceChannel.find_by_channel_id(@channel_id)
      channel.try :unsubscribe, @subscription_id
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
      if match = @channel_id.match(/^((private)|(presence))-/)
        send "handle_#{match.captures[0]}_subscription", msg
      else
        subscribe_channel
      end
    end

    def subscribe_channel
      channel = Slanger::Channel.find_or_create_by_channel_id(@channel_id)
      @subscription_id = channel.subscribe do |msg|
        msg       = JSON.parse(msg)
        socket_id = msg.delete 'socket_id'
        @socket.send msg.to_json unless socket_id == @socket_id
      end
    end

    def handle_private_subscription(msg)
      unless token == msg['data']['auth'].split(':')[1]
        @socket.send(payload 'pusher:error', {
          message: "Invalid signature: Expected HMAC SHA256 hex digest of #{@socket_id}:#{msg['data']['channel']}, but got #{msg['data']['auth']}"
        })
      else
        subscribe_channel
      end
    end

    def handle_presence_subscription(msg)
      if token(msg['data']['channel_data']) != msg['data']['auth'].split(':')[1]
        @socket.send(payload 'pusher:error', {
          message: "Invalid signature: Expected HMAC SHA256 hex digest of #{@socket_id}:#{msg['data']['channel']}, but got #{msg['data']['auth']}"
        })
      elsif !msg['data']['channel_data']
        @socket.send(payload 'pusher:error', {
          message: "presence-channel is a presence channel and subscription must include channel_data"
        })
      else
        channel = Slanger::PresenceChannel.find_or_create_by_channel_id(@channel_id)
        @subscription_id = channel.subscribe(msg) do |msg|
          msg       = JSON.parse(msg)
          socket_id = msg.delete 'socket_id'
          @socket.send msg.to_json unless socket_id == @socket_id
        end
        @socket.send(payload 'pusher_internal:subscription_succeeded', {
          presence: {
            count: channel.subscribers.size,
            ids:   channel.ids,
            hash:  channel.subscribers
          }
        })
      end
    end

    def payload(event_name, payload = {})
      { channel: @channel_id, event: event_name, data: payload }.to_json
    end

    def token(params=nil)
      string_to_sign = [@socket_id, @channel_id, params].compact.join ':'
      HMAC::SHA256.hexdigest(Slanger::Config.secret, string_to_sign)
    end
  end
end
