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
      msg   = JSON.parse msg
      event = msg['event'].gsub('pusher:', '')

      if event =~ /^client-/
        # Client event. Send it to the destination channel.
        msg['socket_id'] = @socket_id

        Channel.from(msg['channel']).try :send_client_message, msg
      elsif %w(subscribe ping pong authenticate).include? event
        send event, msg
      end
    rescue JSON::ParserError
      handle_error({ code: '5001', message: "Invalid JSON" })

    rescue StandardError => e
      handle_error({ code: '5000', message: "Internal Server error: #{e.message}, #{e.backtrace}" })
    end

    def onclose
      @subscriptions.each { |c, s| Channel.unsubscribe c, s }
    end

    private

    # Verify app key. Send connection_established message to connection if it checks out. Send error message and disconnect if invalid.
    def authenticate
      app_key = @socket.request['path'].split(/\W/)[2]
      if app_key == Slanger::Config.app_key
        @socket_id = SecureRandom.uuid
        send_payload nil, 'pusher:connection_established', { socket_id: @socket_id }
      else
        handle_error({ code: '4001', message: "Could not find app by key #{app_key}" })
        @socket.close_websocket
      end
    end

    # Dispatch to handler method if channel requires authentication, otherwise subscribe.
    def subscribe(msg)
      channel_id = msg['data']['channel']

      klass, message =
        if channel_id =~ /^private-/
          [PrivateSubscription, msg]
        elsif channel_id =~ /^presence-/
          [PresenceSubscription, msg]
        else
          [Subscription, channel_id]
        end

      subscription_id = klass.new(self).handle message
      @subscriptions[channel_id] = subscription_id
    end

    def ping(msg)
      send_payload nil, 'pusher:ping'
    end

    def pong msg; end

    def send_payload *args
      @socket.send to_pusher_payload(*args)
    end

    def to_pusher_payload(channel_id, event_name, payload = {})
      { channel: channel_id, event: event_name, data: payload }.to_json
    end

    def handle_error(error)
      send_payload nil, 'pusher:error', error
    end
  end
end
