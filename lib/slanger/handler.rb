require 'active_support/json'
require 'active_support/core_ext/hash'
require 'securerandom'
require 'signature'
require 'fiber'

module Slanger
  class Handler
    def initialize(socket)
      @socket = socket
      authenticate
    end

    # Dispatches message handling to method with same name as the event name
    def onmessage(msg)
      msg = JSON.parse msg
      send msg['event'].gsub('pusher:', 'pusher_'), msg
    end

    # Unsubscribe this connection from the channel
    def onclose
      const   = @channel_id =~ /^presence-/ ? 'PresenceChannel' : 'Channel'
      channel = Slanger.const_get(const).find_by_channel_id(@channel_id)
      channel.try :unsubscribe, @subscription_id
    end

    private

    # Verify app key. Send connection_established message to connection if it checks out. Send error message and disconnect if invalid.
    def authenticate
      app_key = @socket.request['path'].split(/\W/)[2]
      if app_key == Slanger::Config.app_key
        @socket_id = SecureRandom.uuid
        @socket.send(payload 'pusher:connection_established', { socket_id: @socket_id })
      else
        @socket.send(payload 'pusher:error', { code: '4001', message: "Could not find app by key #{app_key}" })
        @socket.close_websocket
      end
    end

    # Dispatch to handler method if channel requires authentication, otherwise subscribe.
    def pusher_subscribe(msg)
      @channel_id = msg['data']['channel']
      if match = @channel_id.match(/^((private)|(presence))-/)
        send "handle_#{match.captures[0]}_subscription", msg
      else
        subscribe_channel
      end
    end

    def pusher_ping(msg)
      @socket.send(payload 'pusher:ping')
    end

    def pusher_pong msg; end

    def method_missing(sym, *args, &blk)
      if sym.to_s =~ /^pusher_/
        puts [sym, args].inspect
      else
        super
      end
    end

    # Add connection to channel subscribers
    def subscribe_channel
      channel = Slanger::Channel.find_or_create_by_channel_id(@channel_id)
      @subscription_id = channel.subscribe do |msg|
        msg       = JSON.parse(msg)
        socket_id = msg.delete 'socket_id'
        @socket.send msg.to_json unless socket_id == @socket_id
      end
    end

    # Validate authentication token for private channel and add connection to channel subscribers if it checks out
    def handle_private_subscription(msg)
      if msg['data']['auth'] && token(msg['data']['channel_data']) != msg['data']['auth'].split(':')[1]
        @socket.send(payload 'pusher:error', {
          message: "Invalid signature: Expected HMAC SHA256 hex digest of #{@socket_id}:#{msg['data']['channel']}, but got #{msg['data']['auth']}"
        })
      else
        subscribe_channel
      end
    end

    # Validate authentication token and check channel_data. Add connection to channel subscribers if it checks out
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
        callback = Proc.new {
          @socket.send(payload 'pusher_internal:subscription_succeeded', {
            presence: {
              count: channel.subscribers.size,
              ids:   channel.ids,
              hash:  channel.subscribers
            }
          })
        }
        @subscription_id = channel.subscribe(msg, callback) do |msg|
          msg       = JSON.parse(msg)
          socket_id = msg.delete 'socket_id'
          @socket.send msg.to_json unless socket_id == @socket_id
        end

      end
    end

    # Message helper method. Converts a hash into the Pusher JSON protocol
    def payload(event_name, payload = {})
      { channel: @channel_id, event: event_name, data: payload }.to_json
    end

    # HMAC token validation
    def token(params=nil)
      string_to_sign = [@socket_id, @channel_id, params].compact.join ':'
      HMAC::SHA256.hexdigest(Slanger::Config.secret, string_to_sign)
    end
  end
end
