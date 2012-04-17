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
        msg['socket_id'] = @socket_id

        Channel.send_client_message msg
      elsif %w(subscribe ping pong authenticate).include? event
        send event, msg
      end

    rescue JSON::ParserError
      handle_error({ code: '5001', message: "Invalid JSON" })
    end

    def onclose
      @subscriptions.each { |c, s| Channel.unsubscribe c, s }
    end

    private

    def authenticate
      return send_connection_established if valid_app_key?

      handle_error({ code: '4001', message: "Could not find app by key #{app_key}" })
      @socket.close_websocket
    end

    def valid_app_key?
      Slanger::Config.app_key = @socket.request['path'].split(/\W/)[2]
    end

    def send_connection_established
      @socket_id = SecureRandom.uuid
      send_payload nil, 'pusher:connection_established', { socket_id: @socket_id }
    end

    def subscribe(msg)
      channel_id = msg['data']['channel']

      klass = if private_subscription? channel_id
                PrivateSubscription
              elsif presence_subscription? channel_id
                PresenceSubscription
              else
                Subscription
              end

      @subscriptions[channel_id] = klass.new(self).handle msg
    end

    def private_subscription? channel_id
      channel_id =~ /^private-/
    end

    def presence_subscription? channel_id
      channel_id =~ /^presence-/
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
