# Handler class.
# Handles a client connected via a websocket connection.

require 'active_support/json'
require 'active_support/core_ext/hash'
require 'securerandom'
require 'signature'
require 'fiber'

module Slanger
  class Handler
    def initialize(socket)
      @socket        = socket
      @subscriptions = {}
      authenticate
    end

    # Dispatches message handling to method with same name as the event name
    def onmessage(msg)
      begin
        msg   = JSON.parse msg
      rescue JSON::ParserError
        Logger.error log_message("JSON Parse error on message: '" + msg + "'")
      end
      event = msg['event'].gsub('pusher:', 'pusher_')

      if event =~ /^pusher_/
        # Pusher event, call method if it exists.
        if respond_to? event, true
          send(event, msg)
        else
          Logger.error "Unknown pusher event: " + event
        end
      elsif event =~ /^client-/
        # Client event. Send it to the destination channel.
        msg['socket_id'] = @socket_id
        channel = find_channel msg['channel']
        channel.try :send_client_message, msg
      end
    end

    # Unsubscribe this connection from all the channels on close.
    def onclose
      @subscriptions.each do |channel_id, subscription_id|
        channel = find_channel channel_id
        channel.try :unsubscribe, subscription_id
      end
      Logger.debug log_message("Closed connection.")
    end

    private

    def find_channel(channel_id)
      if channel_id =~ /^presence-/
        @application.find_presence_channel(channel_id)
      else
        @application.find_channel(channel_id)
      end
    end

    # Verify app key. Send connection_established message to connection if it checks out. Send error message and disconnect if invalid.
    def authenticate
      app_key = @socket.request['path'].split(/\W/)[2]
      # Retrieve application
      @application = Applications.by_key(app_key)
      if @application.nil?
        # Application not found
        @socket.send(payload nil, 'pusher:error', { code: '4001', message: "Could not find app by key #{app_key}" })
        @socket.close_websocket
        Logger.error log_message("Application not found: " + app_key)
      else
        @socket_id = SecureRandom.uuid
        @socket.send(payload nil, 'pusher:connection_established', { socket_id: @socket_id })
        Logger.debug log_message("Connection established.")
      end
    end

    # Dispatch to handler method if channel requires authentication, otherwise subscribe.
    def pusher_subscribe(msg)
      channel_id = msg['data']['channel']
      subscription_id = if match = channel_id.match(/^((private)|(presence))-/)
        send "handle_#{match.captures[0]}_subscription", msg
      else
        subscribe_channel channel_id
      end
      @subscriptions[channel_id] = subscription_id
   end

    def pusher_ping(msg)
      @socket.send(payload nil, 'pusher:ping')
      Logger.debug log_message("Ping sent.")
    end

    def pusher_pong(msg)
      Logger.debug log_message("Pong received: " + msg.to_s)
    end

    #TODO: think about moving all subscription stuff into channel classes
    # Add connection to channel subscribers
    def subscribe_channel(channel_id)
      channel = @application.find_or_create_channel(channel_id)
      @socket.send(payload channel_id, 'pusher_internal:subscription_succeeded')
      # Subscribe to the channel and have the events received from it
      # sent to the client's socket.
      subscription_id = channel.subscribe do |msg|
        msg       = JSON.parse(msg)
        # Don't send the event if it was sent by the client
        socket_id = msg.delete 'socket_id'
        @socket.send msg.to_json unless socket_id == @socket_id
      end
      Logger.debug log_message("Subscribed to channel: " + channel_id + " subscriptions id: " + subscription_id)
      Logger.audit log_message("Subscribed to channel: " + channel_id + " subscriptions id: " + subscription_id)
    end

    # Validate authentication token for private channel and add connection to channel subscribers if it checks out
    def handle_private_subscription(msg)
      channel = msg['data']['channel']
      if msg['data']['auth'] && token(channel, msg['data']['channel_data']) != msg['data']['auth'].split(':')[1]
        @socket.send(payload nil, 'pusher:error', {
          message: "Invalid signature: Expected HMAC SHA256 hex digest of #{@socket_id}:#{channel}, but got #{msg['data']['auth']}"
        })
        Logger.error log_message("Invalid signature.")
      else
        subscribe_channel channel
      end
    end

    # Validate authentication token and check channel_data. Add connection to channel subscribers if it checks out
    def handle_presence_subscription(msg)
      channel_id = msg['data']['channel']
      if token(channel_id, msg['data']['channel_data']) != msg['data']['auth'].split(':')[1]
        @socket.send(payload nil, 'pusher:error', {
          message: "Invalid signature: Expected HMAC SHA256 hex digest of #{@socket_id}:#{msg['data']['channel']}, but got #{msg['data']['auth']}"
        })
        Logger.error log_message("channel_id: " + channel_id + " Invalid signature.")
      elsif !msg['data']['channel_data']
        @socket.send(payload nil, 'pusher:error', {
          message: "presence-channel is a presence channel and subscription must include channel_data"
        })
        Logger.error log_message("channel_id: " + channel_id + " Missing channel_data for subscription to the presence channel.")
      else
        channel = @application.find_or_create_presence_channel(channel_id)
        callback = Proc.new {
          @socket.send(payload channel_id, 'pusher_internal:subscription_succeeded', {
            presence: {
              count: channel.subscribers.size,
              ids:   channel.ids,
              hash:  channel.subscribers
            }
          })
          Logger.debug log_message("channel_id: " + channel_id + " Sent presence information.")
        }
        # Subscribe to channel, call callback when done to send a 
        # subscription_succeeded event to the client.
        channel.subscribe(msg, callback) do |msg|
          # Send channel messages to the client, unless it is the
          # sender of the event.
          msg       = JSON.parse(msg)
          socket_id = msg.delete 'socket_id'
          @socket.send msg.to_json unless socket_id == @socket_id
        end
      end
    end

    # Message helper method. Converts a hash into the Pusher JSON protocol
    def payload(channel_id, event_name, payload = {})
      { channel: channel_id, event: event_name, data: payload }.to_json
    end

    # HMAC token validation
    def token(channel_id, params=nil)
      string_to_sign = [@socket_id, channel_id, params].compact.join ':'
      HMAC::SHA256.hexdigest(@application.secret, string_to_sign)
    end

    def log_message(msg)
      peername = @socket.get_peername
      if peername.nil?
        "socket_id: " + @socket_id + " " + msg
      else
        port, ip = Socket.unpack_sockaddr_in(peername) 
        "Peer: " + ip + ":" + port.to_s + " socket_id: " + @socket_id + " " + msg 
      end
    end
  end
end
